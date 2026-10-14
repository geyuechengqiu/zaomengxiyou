using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

/// <summary>Persistent authored overlay; preload catalog resources before scene Ready.</summary>
public partial class StageLoadingScreen : CanvasLayer
{
    [Signal] public delegate void PhaseChangedEventHandler(string description, double progress);
    [Export(PropertyHint.Range, "0.3,2,0.05")] public double ProgressTweenSeconds { get; set; } = .8;
    public bool IsLoading { get; private set; }
    public static bool LoadingStage { get; private set; }
    public string LastError { get; private set; } = "";
    public double Progress { get; private set; }
    public double DisplayedProgress { get; private set; }
    public int WarmedVisualCount { get; private set; }
    public int ResourceLoads { get; private set; }
    public int VisualPreparations { get; private set; }
    private Tween? _progressTween;
    private Control _view = null!;
    private Label _description = null!, _percent = null!;
    private TextureProgressBar _bar = null!;
    private Control _cursor = null!;
    // Keep the C# wrappers alive while the shared native resource cache and
    // audio/Spine components still use them. Reuse each path across visits.
    private readonly System.Collections.Generic.Dictionary<string, Resource> _resources = new();
    private readonly HashSet<string> _preparedVisuals = new();
    private bool _previousPause;
    private bool _exiting;
    private Action<bool>? _completion;

    public override void _Ready()
    {
        _view = GetNode<Control>("Overlay");
        _description = _view.GetNode<Label>("Description");
        _percent = _view.GetNode<Label>("Percent");
        _bar = _view.GetNode<TextureProgressBar>("Fill");
        _cursor = _view.GetNode<Control>("Cursor");
        _view.GetNode<Button>("Dismiss").Pressed += DismissError;
        GetNode<UiModalManager>("/root/UiModalManager").RegisterBranch(_view);
    }

    public bool Begin(Dictionary level, Action<bool> completed)
    {
        if (IsLoading || _view == null || _view.Visible) return false;
        IsLoading = LoadingStage = true; LastError = ""; _previousPause = GetTree().Paused;
        _completion = completed;
        _view.GetNode<Control>("Dismiss").Hide();
        WarmedVisualCount = 0;
        _view.Show(); SetProgress("准备关卡加载…", 0);
        LoadLevel(level);
        return true;
    }

    private async void LoadLevel(Dictionary level)
    {
        bool success = false;
        try
        {
            // Show a rendered frame before starting any main-thread setup.
            await Present();
            string scenePath = level["scene"].AsString();
            string manifestPath = level.GetValueOrDefault("loading_manifest").AsString();
            string audioPath = level.GetValueOrDefault("loading_audio").AsString();
            if (manifestPath.Length == 0 || audioPath.Length == 0)
                throw new InvalidOperationException("关卡缺少加载清单或音频配置");
            await LoadGroup(new[] { manifestPath, audioPath }, "读取关卡配置…", 0, 5);
            var definitions = GD.Load<Json>(manifestPath).Data.AsGodotDictionary()["definitions"].AsGodotDictionary();
            await LoadGroup(Paths(definitions, "characters", "skills", "statuses", "equipment", "levels"), "加载角色、技能、装备和区域配置…", 5, 30);
            await LoadGroup(Paths(definitions, "monsters"), "加载怪物与Boss动画、技能和特效…", 30, 55);
            var sounds = new HashSet<string>();
            CollectAudio(GD.Load<Json>(audioPath).Data, sounds);
            await LoadGroup(sounds, "加载背景音乐和战斗音效…", 55, 70, true);
            await LoadGroup(new[] { scenePath }, "加载关卡地图、碰撞与界面资源…", 70, 85);
            await WarmVisuals(definitions);
            var packed = GD.Load<PackedScene>(scenePath)
                ?? throw new InvalidOperationException("关卡场景资源无效");
            SetProgress("初始化地图、角色存档、背包装备和战斗界面…", 88);
            await Present();
            // Ready runs behind the overlay. No physics, timer or player input
            // may run before catalog warm-up and campaign restoration finish.
            GetTree().Paused = true;
            Error error = GetTree().ChangeSceneToPacked(packed);
            if (error != Error.Ok) throw new InvalidOperationException($"关卡初始化失败：{error}");
            await ToSignal(GetTree(), SceneTree.SignalName.SceneChanged);
            CheckActive();
            if (GetTree().CurrentScene is not BattleLevelScene battle || !battle.IsNodeReady())
                throw new InvalidOperationException("关卡初始化未完成");
            SetProgress("准备摄像机、区域出怪和画面显示…", 96);
            await Present();
            // Deferred component/HUD initialization also belongs to loading.
            // The paused battle cannot produce hits, births or input meanwhile.
            await Present();
            SetProgress("加载完成，进入关卡", 100);
            if (_progressTween != null && _progressTween.IsRunning())
                await ToSignal(_progressTween, Tween.SignalName.Finished);
            CheckActive();
            // The final frame must visibly show a full bar before gameplay starts.
            ApplyDisplayedProgress(100);
            await Present();
            battle.session.Call("set_paused", false);
            battle.player.Get("operations").AsGodotObject().Set("enabled", battle.enable_player_controls);
            success = true;
        }
        catch (OperationCanceledException) when (_exiting) { }
        catch (Exception exception)
        {
            LastError = exception.Message;
            _progressTween?.Kill();
            _description.Text = "加载失败：" + LastError;
            _view.GetNode<Control>("Dismiss").Show();
        }
        finally
        {
            if (!_exiting)
            {
                ClearWarmup();
                GetTree().Paused = _previousPause;
                IsLoading = LoadingStage = false;
                if (success) _view.Hide();
                Complete(success);
            }
        }
    }

    private async Task WarmVisuals(Dictionary definitions)
    {
        var scenes = new System.Collections.Generic.Dictionary<string, PackedScene>();
        var visited = new HashSet<string>();
        foreach (string path in Paths(definitions, "characters", "monsters"))
            if (_resources[path] is BattleEntityDefinition unit && unit.scene != null)
                CollectVisuals(unit.scene, scenes, visited);
        var viewport = GetNode<SubViewport>("WarmupViewport");
        var host = viewport.GetNode<Node2D>("Visuals");
        int done = 0;
        foreach (var scene in scenes.Values)
        {
            SetProgress("预热角色、怪物与技能特效画面…", 85 + 2.0 * done / Math.Max(1, scenes.Count));
            if (_preparedVisuals.Contains(scene.ResourcePath))
            {
                ++WarmedVisualCount; ++done;
                continue;
            }
            await Present();
            var visual = scene.Instantiate<Node2D>();
            host.AddChild(visual); visual.Position = new(320, 300);
            try
            {
                // Isolated animation adapter: no battle entities, AI, damage,
                // drops, random draws, spawn counters or audio callbacks.
                var profile = visual.Get("profile").AsGodotObject();
                var actions = profile.Get("animations").AsGodotDictionary();
                foreach (var entry in actions)
                {
                    visual.Call("play_action", entry.Key, true);
                    var player = visual.Call("get_animation_player").As<AnimationPlayer>();
                    double length = player.GetAnimation(entry.Key.AsStringName()).Length;
                    visual.Call("advance_animation", Math.Min(length * .5, .4));
                    viewport.RenderTargetUpdateMode = SubViewport.UpdateMode.Once;
                    await Present();
                }
                ++WarmedVisualCount;
                ++VisualPreparations;
                _preparedVisuals.Add(scene.ResourcePath);
            }
            finally { if (IsInstanceValid(visual)) visual.Free(); }
            ++done;
        }
        viewport.RenderTargetUpdateMode = SubViewport.UpdateMode.Disabled;
    }

    private static void CollectVisuals(PackedScene packed,
        System.Collections.Generic.Dictionary<string, PackedScene> visuals, HashSet<string> visited)
    {
        if (!visited.Add(packed.ResourcePath)) return;
        void Inspect(SceneState state)
        {
            if (state.GetBaseSceneState() is SceneState inherited) Inspect(inherited);
            for (int i = 0; i < state.GetNodeCount(); ++i)
            {
                var child = state.GetNodeInstance(i);
                if (child == null) continue;
                if (state.GetNodeName(i) == "AnimationAdapter") visuals[child.ResourcePath] = child;
                else CollectVisuals(child, visuals, visited);
            }
        }
        Inspect(packed.GetState());
    }

    private void ClearWarmup()
    {
        var viewport = GetNode<SubViewport>("WarmupViewport");
        viewport.RenderTargetUpdateMode = SubViewport.UpdateMode.Disabled;
        foreach (var child in viewport.GetNode("Visuals").GetChildren()) child.Free();
    }

    private async Task LoadGroup(IEnumerable<string> paths, string description, double start, double end, bool threaded = false)
    {
        SetProgress(description, start); await Present();
        var pending = new HashSet<string>(paths);
        pending.RemoveWhere(path => _resources.ContainsKey(path));
        if (pending.Count == 0) { SetProgress(description, end); return; }
        foreach (string path in pending)
            if (!ResourceLoader.Exists(path)) throw new InvalidOperationException("资源不存在：" + path);
        // Custom Spine/.NET scripted resources construct managed defaults while
        // loading. Keep that work on the main thread; yield between real loads.
        // Plain audio resources can safely use the engine's threaded loader.
        if (!threaded)
        {
            int done = 0;
            foreach (string path in pending)
            {
                _resources[path] = GD.Load<Resource>(path)
                    ?? throw new InvalidOperationException("资源加载失败：" + path);
                ++ResourceLoads;
                SetProgress(description, start + (end - start) * ++done / pending.Count);
                if (done % 4 == 0) await Present();
            }
            SetProgress(description, end); return;
        }
        var requests = new List<string>(pending);
        foreach (string path in requests)
        {
            Error error = ResourceLoader.LoadThreadedRequest(path);
            if (error != Error.Ok) throw new InvalidOperationException($"无法加载资源：{path} ({error})");
        }
        int count = pending.Count, loaded = 0;
        using var progress = new Godot.Collections.Array();
        while (pending.Count > 0)
        {
            double partial = 0;
            foreach (string path in requests)
            {
                if (!pending.Contains(path)) continue;
                progress.Clear();
                var status = ResourceLoader.LoadThreadedGetStatus(path, progress);
                if (status == ResourceLoader.ThreadLoadStatus.Loaded)
                {
                    _resources[path] = ResourceLoader.LoadThreadedGet(path); pending.Remove(path); ++loaded;
                    ++ResourceLoads;
                }
                else if (status is ResourceLoader.ThreadLoadStatus.Failed or ResourceLoader.ThreadLoadStatus.InvalidResource)
                    throw new InvalidOperationException("资源加载失败：" + path);
                else if (progress.Count > 0) partial += progress[0].AsDouble();
            }
            SetProgress(description, start + (end - start) * (loaded + partial) / count);
            if (pending.Count > 0)
            {
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
                CheckActive();
            }
        }
        SetProgress(description, end);
    }

    private static IEnumerable<string> Paths(Dictionary definitions, params string[] categories)
    {
        var paths = new HashSet<string>();
        foreach (string category in categories)
            if (definitions.TryGetValue(category, out var entries))
                foreach (var entry in entries.AsGodotDictionary()) paths.Add(entry.Value.AsString());
        return paths;
    }

    private static void CollectAudio(Variant value, HashSet<string> paths)
    {
        if (value.VariantType == Variant.Type.Dictionary)
            foreach (var entry in value.AsGodotDictionary()) CollectAudio(entry.Value, paths);
        else if (value.VariantType == Variant.Type.Array)
            foreach (var entry in value.AsGodotArray()) CollectAudio(entry, paths);
        else if (value.VariantType == Variant.Type.String)
        {
            string path = value.AsString();
            if (path.StartsWith("res://", StringComparison.Ordinal) &&
                (path.EndsWith(".mp3", StringComparison.Ordinal) || path.EndsWith(".ogg", StringComparison.Ordinal) || path.EndsWith(".wav", StringComparison.Ordinal))) paths.Add(path);
        }
    }

    private async Task Present()
    {
        CheckActive();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        CheckActive();
        if (DisplayServer.GetName() != "headless")
            await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        CheckActive();
    }

    private void CheckActive()
    {
        if (_exiting || !IsInsideTree()) throw new OperationCanceledException();
    }

    private void Complete(bool success)
    {
        var completed = _completion;
        _completion = null;
        completed?.Invoke(success);
    }

    public override void _ExitTree()
    {
        _exiting = true;
        _progressTween?.Kill();
        if (IsLoading)
        {
            GetTree().Paused = _previousPause;
            IsLoading = LoadingStage = false;
            Complete(false);
        }
        ClearWarmup();
        _resources.Clear(); _preparedVisuals.Clear();
    }
    private void SetProgress(string text, double progress)
    {
        double previousTarget = Progress;
        Progress = Math.Max(Progress, progress);
        if (progress == 0) Progress = 0;
        _description.Text = text;
        if (progress == 0)
        {
            _progressTween?.Kill();
            ApplyDisplayedProgress(0);
        }
        else if (Progress > previousTarget && Progress > DisplayedProgress)
        {
            _progressTween?.Kill();
            _progressTween = CreateTween().SetPauseMode(Tween.TweenPauseMode.Process);
            _progressTween.TweenMethod(Callable.From<double>(ApplyDisplayedProgress), DisplayedProgress, Progress, Math.Clamp(ProgressTweenSeconds, .3, 2))
                .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.Out);
        }
        EmitSignal(SignalName.PhaseChanged, text, Progress);
    }
    private void ApplyDisplayedProgress(double value)
    {
        DisplayedProgress = value; _bar.Value = value;
        float ratio = (float)((_bar.Value - _bar.MinValue) / (_bar.MaxValue - _bar.MinValue));
        var end = _bar.Position + new Vector2(_bar.Size.X * ratio, _bar.Size.Y * .5f);
        // Anchor the cloud head, rather than the trailing wisp, to the fill endpoint.
        _cursor.Position = end - _cursor.GetMeta("progress_anchor", _cursor.Size * .5f).AsVector2();
        _percent.Position = new(end.X - _percent.Size.X * .5f, _percent.Position.Y); _percent.Text = $"{Math.Floor(value)}%";
    }
    public void DismissError()
    {
        if (!IsLoading && _view != null)
        {
            _view.Hide();
            if (GetTree().CurrentScene is BattleLevelScene)
                GetNode<ZaomengOneCampaign>("/root/ZaomengOneCampaign").ReturnToMap();
        }
    }
    public override void _Input(InputEvent @event)
    {
        if (_view != null && _view.Visible && @event is InputEventKey or InputEventJoypadButton or InputEventJoypadMotion)
            GetViewport().SetInputAsHandled();
    }
}
