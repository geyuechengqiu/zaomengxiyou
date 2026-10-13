using Godot;
using Godot.Collections;
using System;
using Array = Godot.Collections.Array;

public partial class BattleLevelScene : Node2D
{
    [Export] public StringName level_id { get; set; } = "碧玉径";
    [Export] public Json? audio_catalog { get; set; }
    [Export] public bool enable_player_controls { get; set; } = true;
    public Node session { get; private set; } = null!;
    public CharacterBody2D player { get; private set; } = null!;
    public Node flow { get; private set; } = null!;
    public Control menu { get; private set; } = null!;
    public Camera2D camera { get; private set; } = null!;
    public Label info { get; private set; } = null!;
    public Label message { get; private set; } = null!;
    public Control original_hud { get; private set; } = null!;
    private Node _eventBus = null!;
    private Callable _eventCallback;
    private Callable _menuCallback;
    private Control Inventory => original_hud.Get("inventory_view").As<Control>();
    private Node Operations => player.Get("operations").As<Node>();

    public override void _EnterTree()
    {
        if (StageLoadingScreen.LoadingStage)
        {
            GetNode("BattleSession").Get("clock").AsGodotObject().Set("paused", true);
            // Allocate common feedback and number rows behind the loading screen,
            // before their Ready methods, rather than on the first crowded hit.
            GetNode("BattleSession/BattlePresentation").Set("prewarm_feedback_count", 8);
            GetNode("BattleSession/BattlePresentation/DamageNumbers/Rows").Set("prewarm_count", 128);
        }
        // Configure before the audio component's Ready/prewarm. Nested overrides
        // inside inherited PackedScenes are otherwise lost by binary scene export.
        if (audio_catalog != null)
            GetNode("BattleSession/BattlePresentation/Audio").Set("catalog", audio_catalog);
    }

    public override void _Ready()
    {
        session = GetNode("BattleSession");
        player = GetNode<CharacterBody2D>("BattleSession/Actors/SunWukong");
        flow = GetNode("BattleSession/LevelInstance");
        menu = GetNode<Control>("HUD/OperationMenu");
        camera = GetNode<Camera2D>("Camera2D");
        info = GetNode<Label>("HUD/Panel/Column/Info");
        message = GetNode<Label>("HUD/Panel/Column/Message");
        original_hud = GetNode<Control>("HUD/BattleHUD");
        GetNode<UiModalManager>("/root/UiModalManager").RegisterBranch(original_hud);
        Operations.Set("enabled", enable_player_controls && !StageLoadingScreen.LoadingStage);
        menu.Call("bind_controller", Operations.Get("controller"));
        if (!session.Call("register_scene_level", level_id, GetNode("BattleSession/Actors")).AsBool())
            throw new InvalidOperationException(session.Get("last_error").AsString());
        var skills = player.GetNode<BattleSkillLoadout>("SkillLoadout");
        skills.Initialize();
        original_hud.Call("bind_actor", player);
        original_hud.GetNode<OriginalSkillPanel>("SkillPanel").Bind(skills);
        _menuCallback = Callable.From<bool>(RefreshMenuPause);
        original_hud.Connect("inventory_changed", _menuCallback);
        original_hud.Connect("module_changed", _menuCallback);
        original_hud.Connect("settings_requested", Callable.From(() => menu.Call("set_open", true)));
        menu.Connect("menu_changed", _menuCallback);
        GetNode<Button>("HUD/Restart").Pressed += RestartLevel;
        _eventBus = GetNode("/root/CoreSystem").Get("event_bus").As<Node>();
        _eventCallback = Callable.From<string, Array>(OnBattleEvent);
        _eventBus.Connect("event_pushed", _eventCallback);
        var modules = GetNode("/root/Panku").Get("module_manager").AsGodotObject();
        // Vendor console's enum: ShowIfShellVisible = 1; keep its implementation intact.
        modules.Call("get_module", "native_logger").AsGodotObject().Call("set_overlay_display_mode", 1);
        NativeVerification.Schedule(this);
    }

    public override void _Process(double delta)
    {
        if (!info.IsVisibleInTree() || !IsInstanceValid(player)) return;
        var regions = flow.Get("regions").AsGodotArray();
        if (regions.Count == 0) return;
        int index = flow.Get("current_region_index").AsInt32();
        var region = regions[index].AsGodotObject();
        var attributes = player.Get("attributes").AsGodotObject().Call("get_snapshot").AsGodotDictionary();
        info.Text = $"孙悟空 · 等级{attributes["level"].AsInt64()} · 生命{attributes["hp"].AsInt64()}/{attributes["hpMax"].AsInt64()} · 魔法{attributes["mp"].AsInt64()}/{attributes["mpMax"].AsInt64()} · {level_id} {index + 1}/{regions.Count}";
        // Level state is a third-party-compatible integer contract during migration.
        int state = flow.Get("state").AsInt32();
        if (state == 2) message.Text = $"{level_id}通关！";
        else if (state == 3) message.Text = !player.Call("is_alive").AsBool() ? "悟空倒下了，点击重开。" : "关卡已结束，点击重开。";
        else if (region.Get("exit_open").AsBool())
            message.Text = index < regions.Count - 1 ? "出口已开启：向右进入下一区域。" : "Boss已击败，站到出口标记处按W / ↑确认通关。";
        else message.Text = "击败区域内的敌人，继续向右前进。";
    }

    protected virtual void RestartLevel() => GetTree().ReloadCurrentScene();
    private void RefreshMenuPause(bool open) => session.Call("set_paused", menu.Visible || Inventory.Visible || original_hud.Call("is_module_open").AsBool());

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is not InputEventKey { Pressed: true, Echo: false } key) return;
        if (key.Keycode == Key.B && !menu.Visible)
            original_hud.Call("set_inventory_open", !Inventory.Visible);
        else if (key.Keycode == Key.Escape)
        {
            if (Inventory.Visible) original_hud.Call("set_inventory_open", false);
            else if (original_hud.Call("is_module_open").AsBool()) original_hud.Call("set_module_open", false);
            else menu.Call("set_open", !menu.Visible);
        }
        else return;
        GetViewport().SetInputAsHandled();
    }

    private void OnBattleEvent(string id, Array payload)
    {
        if (payload.Count != 1 || payload[0].VariantType != Variant.Type.Dictionary) return;
        var data = payload[0].AsGodotDictionary();
        if (data.GetValueOrDefault("battle_id").AsStringName() != session.Get("battle_id").AsStringName()) return;
        if (id is "battle.level.victory" or "battle.level.failed")
            Operations.Call("set_control_blocked", new StringName("level_finished"), true);
    }

    public override void _ExitTree()
    {
        if (IsInstanceValid(_eventBus) && _eventBus.IsConnected("event_pushed", _eventCallback))
            _eventBus.Disconnect("event_pushed", _eventCallback);
    }
}
