using Godot;
using System;

public partial class ZaomengOneWorldMap : Control
{
    [Signal] public delegate void FeatureRequestedEventHandler(StringName feature);
    private ZaomengOneCampaign _campaign = null!;
    private Node _character = null!, _session = null!;
    private Control _hud = null!;
    private bool _saveQueued;
    private readonly System.Collections.Generic.List<(TextureButton Button, Texture2D Hover, bool Latest, bool Open)> _stages = new();
    private Vector2 _pointer;
    private TextureButton? _hovered;
    private bool _hoverInitialized;
    public override void _Ready()
    {
        _campaign = GetNode<ZaomengOneCampaign>("/root/ZaomengOneCampaign");
        _pointer = GetGlobalMousePosition();
        GetNode<UiModalManager>("/root/UiModalManager").RegisterBranch(this);
        var theme = GD.Load<Theme>("res://data/ui/campaign_theme.tres");
        Theme = theme;
        string latest = _campaign.Levels[Math.Clamp(_campaign.unlocked_index,0,_campaign.Levels.Count-1)]["id"].AsString();
        foreach (var row in _campaign.Levels)
        {
            string id = row["id"].AsString();
            var button = GetNode<TextureButton>("Stages/Stage_" + id.Replace('-', '_'));
            bool open = _campaign.IsUnlocked(id);
            button.Disabled = !_campaign.CanEnter(id);
            button.GetNode<Control>("Glow").Visible = id == latest;
            button.TextureDisabled = button.TextureNormal;
            // Locked/unimplemented buttons keep their click rules while showing
            // the original hover frame and its baked outlined stage name.
            _stages.Add((button, button.TextureHover, id == latest, open));
            button.Modulate = open ? Colors.White : new Color(0.48f, 0.48f, 0.48f, 0.8f);
            button.TooltipText = "";
            button.Pressed += () => SelectLevel(id);
        }
        InitializeChrome();
        var modules = GetNode("/root/Panku").Get("module_manager").AsGodotObject();
        modules.Call("get_module", "native_logger").AsGodotObject().Call("set_overlay_display_mode", 1);
        // Reuse the installed audio manager and independent music/SFX preferences.
        var music = GetNode<AudioStreamPlayer>("Music");
        GetNode("/root/CoreSystem").Get("audio_manager").AsGodotObject().Call("bind_scene_player", music, 0);
        music.Finished += OnMusicFinished;
        music.Play();
        NativeVerification.Schedule(this);
    }
    public bool SelectLevel(string id) => _campaign.Enter(id);
    public override void _Input(InputEvent input)
    {
        if (input is InputEventMouse mouse)
        {
            _pointer = GetCanvasTransform().AffineInverse() * mouse.Position;
            RefreshStageHover();
        }
    }
    public override void _Process(double delta)
        => RefreshStageHover();
    private void RefreshStageHover()
    {
        // Resolve one hovered stage, including disabled stage previews. Explicitly
        // reset the other textures so blocked GUI/mouse-exit events cannot leave
        // an earlier stage's baked outline on screen.
        TextureButton? selected = null;
        if (UiModalManager.Top == null)
            foreach (var stage in _stages)
                if (stage.Open && stage.Button.GetGlobalRect().HasPoint(_pointer)) selected = stage.Button;
        if (_hoverInitialized && selected == _hovered) return;
        _hoverInitialized = true;
        _hovered = selected;
        foreach (var stage in _stages)
        {
            bool hovered = stage.Button == selected;
            stage.Button.TextureHover = hovered ? stage.Hover : stage.Button.TextureNormal;
            stage.Button.TexturePressed = stage.Button.TextureHover;
            stage.Button.TextureDisabled = stage.Button.TextureHover;
            stage.Button.GetNode<Control>("Glow").Visible = stage.Latest && selected == null;
        }
    }
    private void InitializeChrome()
    {
        GetNode<Label>("MapName").Text = _campaign.MapName;
        _session = GetNode("CharacterSession"); _character = _session.GetNode("SunWukong");
        _session.Call("set_paused", true);
        _character.Get("operations").AsGodotObject().Set("enabled", false);
        var skills = _character.GetNode<BattleSkillLoadout>("SkillLoadout"); skills.Initialize();
        _campaign.RestoreCharacter(_character, _session);
        _hud = GetNode<Control>("HUD"); _hud.Call("bind_actor", _character);
        _hud.GetNode<OriginalSkillPanel>("SkillPanel").Bind(skills);
        foreach (string part in new[] { "BattleTools", "Skills", "LevelTimer", "NextScreen", "HitCombo" }) _hud.GetNode<CanvasItem>(part).Hide();
        foreach (var node in _hud.GetNode("Player").GetChildren())
            if (node is CanvasItem item && node.Name != "Frame" && node.Name != "Head" && node.Name != "Level") item.Hide();
        var frame = _hud.GetNode<TextureRect>("Player/Frame");
        frame.Texture = GD.Load<Texture2D>("res://assets/ui/original/world_map/avatar_frame_0.png"); frame.Position=Vector2.Zero; frame.Size = new(76,84.6f);
        _hud.GetNode<Control>("Player").Position = new(2,3);
        var head=_hud.GetNode<Control>("Player/Head"); head.Position=new(5.55f,8.7f); head.Size=new(64.4f,64.4f);
        var level=_hud.GetNode<Label>("Player/Level"); level.Position=new(1,61); level.Size=new(24,21); level.AddThemeFontSizeOverride("font_size",14);
        var settings = GetNode<OriginalSettingsPanel>("Settings");
        _hud.Connect("settings_requested",Callable.From(() => settings.set_open(true)));
        var routes = new System.Collections.Generic.Dictionary<string,string> { ["btn_bb"]="backpack",["btn_jn"]="skill",["btn_xf"]="heartMedical",["btn_fb"]="magicWeapon",["btn_lc"]="petHorse",["btn_sz"]="systemSet" };
        foreach (var node in GetNode("Chrome").GetChildren())
            if (node is BaseButton button)
            {
                string feature = button.Name;
                button.Pressed += () =>
                {
                    if (routes.TryGetValue(feature,out var route)) _hud.Call("open_module",new StringName(route));
                    else { EmitSignal(SignalName.FeatureRequested,new StringName(feature)); GetNode<Label>("Notice/Panel/Text").Text = "该功能暂未开放"; GetNode<Control>("Notice").Show(); }
                };
            }
        GetNode<BaseButton>("Notice/OK").Pressed += () => GetNode<Control>("Notice").Hide();
        var bag = _character.Get("inventory").AsGodotObject();
        bag.Connect("item_changed", Callable.From(SaveCharacter));
        bag.Connect("currency_changed", Callable.From<long>(_ => SaveCharacter()));
        bag.Connect("display_name_changed", Callable.From<string>(_ => SaveCharacter()));
        skills.Changed += SaveCharacter;
    }
    private void SaveCharacter()
    {
        if (_saveQueued || GetParent() != GetTree().Root) return;
        _saveQueued = true;
        Callable.From(() => { _saveQueued=false; if (IsInsideTree() && IsInstanceValid(_character)) _campaign.CaptureCharacter(_character); }).CallDeferred();
    }
    private void OnMusicFinished()
    {
        if (IsInsideTree()) GetNode<AudioStreamPlayer>("Music").Play();
    }
    public override void _ExitTree()
    {
        var music = GetNode<AudioStreamPlayer>("Music");
        music.Finished -= OnMusicFinished;
        music.Stop();
        // Release the authored stream before the native audio server shuts down.
        music.Stream = null;
        // This Spine engine queues playback removal on its mixer thread. Allow
        // that thread to drain the stopped stream before scene/engine teardown;
        // the wait is bounded and occurs only when leaving the map.
        int drainMs = (int)Math.Ceiling(Math.Clamp(AudioServer.GetTimeToNextMix(), 0, 0.05) * 1000) + 30;
        OS.DelayMsec(drainMs);
    }
}
