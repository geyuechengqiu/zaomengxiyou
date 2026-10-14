using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Array = Godot.Collections.Array;

public partial class VerifyHuaguoshan : Node
{
    private Huaguoshan _level = null!;
    private Node _session = null!, _flow = null!, _bus = null!;
    private CharacterBody2D _player = null!;
    private int _checks, _spawned, _completed, _victories, _maximumLive;
    private readonly List<string> _failures = new();
    private readonly HashSet<string> _verifiedUnits = new();
    private Callable _callback;
    private bool _collect;

    public override async void _Ready()
    {
        try
        {
            await Run();
        }
        catch (Exception error) { _failures.Add(error.ToString()); }
        finally
        {
            if (IsInstanceValid(_bus) && _bus.IsConnected("event_pushed", _callback)) _bus.Disconnect("event_pushed", _callback);
            if (IsInstanceValid(_level)) _level.Free();
        }
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        foreach (string failure in _failures) GD.PushError(failure);
        if (_failures.Count == 0) GD.Print($"PASS Huaguoshan: {_checks} checks; original map/three Spine units/five regions/fourteen plans/33 deaths, six-monster budget, Biyujing stats, delayed births, camera gates, loot, music and Boss victory");
        GetTree().Quit(_failures.Count == 0 ? 0 : 1);
    }

    private void Check(bool ok, string message)
    {
        ++_checks;
        if (!ok) _failures.Add(message);
    }

    private GodotObject Attributes(GodotObject actor) => actor.Get("attributes").AsGodotObject();
    private Array Regions => _flow.Get("regions").AsGodotArray();
    private List<GodotObject> Living()
    {
        var result = new List<GodotObject>();
        foreach (var value in _session.Call("get_entities").AsGodotArray())
        {
            var actor = value.AsGodotObject();
            if (actor.Get("faction_id").AsStringName() == "enemy" && actor.Call("is_alive").AsBool()) result.Add(actor);
        }
        return result;
    }

    private async Task Step(int count = 1)
    {
        for (int i = 0; i < count; ++i)
        {
            await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
            _session.Call("advance_physics", 1.0 / 60.0);
            _maximumLive = Math.Max(_maximumLive, Living().Count);
        }
    }

    private void Move(float x, float y = 1037.1f)
    {
        _player.GlobalPosition = new Vector2(x, y);
        _player.Velocity = Vector2.Zero;
        _player.Get("motion").AsGodotObject().Call("clear_impulse");
        _player.Set("move_axis", 0.0);
    }

    private async Task Run()
    {
        _level = GD.Load<PackedScene>("res://game/levels/huaguoshan.tscn").Instantiate<Huaguoshan>();
        _level.enable_player_controls = false;
        int terrain = _level.GetNode("BattleSession/Actors/Terrain").GetChildCount();
        AddChild(_level);
        _session = _level.session; _flow = _level.flow; _player = _level.player;
        _session.SetPhysicsProcess(false);
        _bus = GetNode("/root/CoreSystem").Get("event_bus").As<Node>();
        _callback = Callable.From<string, Array>(OnEvent);
        _bus.Connect("event_pushed", _callback);
        _collect = true;
        var definition = _flow.Get("definition").AsGodotObject();
        Check(definition.Call("get_progression_error").AsString() == "", "花果山定义图有效");
        Check(Regions.Count == 5 && _flow.Get("plans").AsGodotDictionary().Count == 14, "原始五区域十四出生计划");
        Check(_level.GetNode("BattleSession/Actors/Terrain").GetChildCount() == terrain, "地图与组件预置");
        Check(_level.GetNode("BattleSession/Actors/SpawnPoints").GetChildCount() == 14, "原出生点全部预置");
        Check(_session.Get("audio").AsGodotObject().Get("current_music").AsString() == "zaomeng1_huaguoshan", "播放源 Music.swf/bg1: " + _session.Get("audio").AsGodotObject().Get("current_music"));
        var gateway = _level.GetNode("BattleSession/Actors/FinalExit/Gateway");
        Check(!gateway.Get("active").AsBool() && !((Node2D)gateway).Visible, "Boss未死时隐藏出口");
        MapPresentationChecks.Verify(_session, _level.GetNode<Node2D>("BattleSession/Actors/Visuals/HuaguoshanVisual"), "MiddleBackground/Forest", Check);
        var plans = definition.Get("spawn_plans").AsGodotArray();
        int planned = 0;
        foreach (var p in plans) planned += p.AsGodotObject().Get("monster_ids").AsGodotArray().Count;
        Check(planned == 33, "原计划33个敌人");
        await Step(45);
        Check(_player.Get("motion").AsGodotObject().Get("grounded").AsBool() && Math.Abs(_player.Position.Y - 1037.1) < 10, $"出生后稳定落在原草地 position={_player.Position}, velocity={_player.Velocity}");
        if (System.Array.Exists(OS.GetCmdlineUserArgs(), arg => arg == "--capture-huaguoshan"))
        {
            await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath("res://.cleanup-backup/huaguoshan-preview.png"));
        }
        // Traverse actual terrain independently of arena progression, then restart the same authored flow.
        _flow.Call("stop");
        foreach (var gate in _level.GetNode("BattleSession/Actors/Gates").GetChildren()) gate.Call("set_locked", false);
        int walkTicks = 0;
        while (_player.Position.X < 9400 && walkTicks++ < 2600)
        {
            _player.Set("move_axis", 1.0);
            if (_player.Get("motion").AsGodotObject().Get("on_wall").AsBool()) _player.Call("try_jump");
            await Step(1);
            if (_player.Position.Y > 1250) break;
        }
        Check(_player.Position.X >= 9400 && _player.Position.Y < 1150, $"实际移动可穿越完整坡地与平台区 {_player.Position}");
        Move(128,984);
        Check(_flow.Call("start", definition).AsBool(), "同一预置地图重启刷怪流程");
        await Step(45);
        Attributes(_player).Call("set_base_value", new StringName("hpMax"), 100000.0);
        Attributes(_player).Call("get_vital", new StringName("health")).AsGodotObject().Call("set_current_value", 100000.0);
        _player.Set("super_armor", true);
        var first = Regions[0].AsGodotObject().Get("definition").AsGodotObject().Get("entry_rect").AsRect2();
        Move(first.GetCenter().X);
        await Step(1);
        Check(Regions[0].AsGodotObject().Get("entered").AsBool() && Living().Count == 0 && !Regions[0].AsGodotObject().Get("exit_open").AsBool(), "延迟出生期间锁门");
        Check(_session.Get("camera_rig").AsGodotObject().Get("combat_locked").AsBool(), "未出生的计划同样锁镜头");
        Check(_player.Get("motion").AsGodotObject().Get("horizontal_bounds_active").AsBool(), "战斗限制玩家左右出界");
        await Step(140);
        Check(Living().Count == 0, "首只等待原delay+interval乘24/30");
        await Step(12);
        Check(Living().Count == 1, "首只准时出生");
        for (int regionIndex = 0; regionIndex < 5; ++regionIndex)
        {
            var region = Regions[regionIndex].AsGodotObject();
            if (regionIndex > 0)
            {
                var entry = region.Get("definition").AsGodotObject().Get("entry_rect").AsRect2();
                Move(entry.GetCenter().X);
                await Step(1);
            }
            if (regionIndex == 1)
            {
                await Step(700);
                Check(Living().Count == 6, "满6只暂停出生，保留待生成计划");
                Check(!region.Get("exit_open").AsBool(), "等待名额的后续怪物不提前通关");
            }
            int timeout = 0;
            while (!region.Get("completed").AsBool() && timeout++ < 2200)
            {
                foreach (var actor in Living())
                {
                    if (_session.Call("is_simulation_blocked").AsBool()) break;
                    Kill(actor);
                }
                await Step(1);
            }
            Check(region.Get("completed").AsBool() && region.Get("exit_open").AsBool(), $"区域{regionIndex + 1}全部计划与死亡完成后开门");
            Check(! _player.Get("motion").AsGodotObject().Get("horizontal_bounds_active").AsBool(), "清屏解除玩家活动限制");
            if (regionIndex < 4)
            {
                Move(region.Get("definition").AsGodotObject().Get("exit_rect").AsRect2().GetCenter().X);
                Check(_flow.Call("request_exit", _player, false).AsBool(), "进入下一区域");
            }
        }
        Check(_spawned == 33 && _flow.Get("death_count").AsInt32() == 33 && _completed == 5, "33目标与五区域仅统计一次");
        Check(_maximumLive <= 6 && _verifiedUnits.Count == 3, "三种怪物实际出生，始终不超活怪上限");
        await Step(420);
        Check(gateway.Get("active").AsBool() && ((Node2D)gateway).Visible, "最终清屏显示预置通关点");
        double gatewayTime = gateway.GetNode<AnimationPlayer>("AnimationPlayer").CurrentAnimationPosition;
        await Step(10);
        Check(Math.Abs(gateway.GetNode<AnimationPlayer>("AnimationPlayer").CurrentAnimationPosition-gatewayTime)>0.01, "出口循环动画按战斗时间推进");
        var anchor = _level.GetNode<BattleFinalExit2D>("BattleSession/Actors/FinalExit");
        var exit = anchor.get_exit_rect();
        var originalPosition = anchor.Position;
        anchor.Position += new Vector2(-350, 0);
        Move(exit.GetCenter().X, exit.GetCenter().Y);
        Check(!_flow.Call("request_exit", _player, false).AsBool(), "移动通关光效后旧位置不再触发胜利");
        Check(anchor.get_exit_rect().HasPoint(anchor.GlobalPosition), "通关触发区域跟随光效锚点");
        anchor.Position = originalPosition;
        if (System.Array.Exists(OS.GetCmdlineUserArgs(), arg => arg == "--capture-huaguoshan"))
        {
            Move(anchor.Position.X, anchor.Position.Y - 80);
            await Step(90);
            await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath("res://.cleanup-backup/huaguoshan-exit-preview.png"));
        }
        Move(exit.GetCenter().X, 880);
        Check(_flow.Call("request_exit", _player, false).AsBool(), "Boss斩败结束后可进入出口");
        Check(!_flow.Call("request_exit", _player, false).AsBool() && _victories == 1, "最终胜利只执行一次");
        Check(_session.Get("loot").AsGodotObject().Get("awarded").AsGodotDictionary().Count == 33, "全部死亡接入既有掉落结算");
        Check(Living().Count == 0 && _session.Call("get_entities").AsGodotArray().Count <= 1, "死亡动画结束后释放怪物节点");
    }

    private void Kill(GodotObject actor)
    {
        actor.Call("_finish_spawn_appearance");
        var damage = _session.Call("apply_secondary_damage", actor, _player, 1000000.0, new StringName("verification"), new Godot.Collections.Dictionary()).AsGodotObject();
        Check(damage.Get("actual_hp_loss").AsDouble() > 0 && !actor.Call("is_alive").AsBool(), "沿共享伤害入口扣血与死亡");
    }

    private void OnEvent(string id, Array payload)
    {
        if (!_collect || payload.Count != 1 || payload[0].VariantType != Variant.Type.Dictionary) return;
        var data = payload[0].AsGodotDictionary();
        if (data.GetValueOrDefault("battle_id").AsStringName() != _session.Get("battle_id").AsStringName()) return;
        if (id == "battle.region.completed") ++_completed;
        if (id == "battle.level.victory") ++_victories;
        if (id != "battle.spawn_plan.spawned") return;
        ++_spawned;
        var actor = _session.Call("get_entity", data["entity_id"]).AsGodotObject();
        if (actor.Get("definition_id").AsStringName() == "花果山大猩猩")
        {
            var audio = _session.Get("audio").AsGodotObject();
            Check(audio.Get("current_music").AsString() == "boss_01" && audio.Get("music").As<AudioStreamPlayer>().Playing,
                "大猩猩登场切换并播放碧玉径原版Boss音乐");
        }
        var region = Regions[_flow.Get("current_region_index").AsInt32()].AsGodotObject().Get("definition").AsGodotObject().Get("bounds").AsRect2();
        var birth = ((Node2D)actor).GlobalPosition;
        Check(birth.X >= region.Position.X + 180 && birth.X <= region.Position.X + 1880 - 180, "怪物出生在战斗视口安全范围 " + birth);
        var visible = _session.Get("camera_rig").AsGodotObject().Call("get_combat_horizontal_bounds").AsVector2();
        Check(birth.X >= visible.X && birth.X <= visible.Y, "出生时镜头已覆盖怪物 " + birth + "/" + visible);
        actor.Get("ai_controller").AsGodotObject().Set("enabled", false);
        string unit = actor.Get("definition_id").AsString();
        if (!_verifiedUnits.Add(unit)) return;
        actor.Call("_finish_spawn_appearance");
        string baseName = unit switch { "花果山小猴" => "jianwu", "花果山山猴" => "yushoushi", _ => "jushi_lingjun" };
        var original = GD.Load<BattleEntityDefinition>($"res://data/monsters/{baseName}/definition.tres");
        var snapshot = Attributes(actor).Call("get_snapshot").AsGodotDictionary();
        var originalValues = original.attribute_set!.Get("attributes").AsGodotDictionary();
        foreach (var key in originalValues.Keys)
        {
            string attribute = key.AsGodotObject().Get("attribute_id").AsString();
            if (attribute is "hpMax" or "atk" or "phyDef")
                Check(snapshot.GetValueOrDefault(attribute).AsDouble() == originalValues[key].AsDouble(), unit + "复用碧玉径" + attribute);
        }
        var visual = actor.Get("animation").AsGodotObject();
        foreach (var action in visual.Get("profile").AsGodotObject().Get("animations").AsGodotDictionary().Keys)
        {
            Check(visual.Call("play_action", action, true).AsBool(), unit + " Spine动作" + action);
            visual.Call("advance_animation", 0.016);
            Check(visual.Call("get_slot_attachment_name", new StringName("Body")).AsString() != "", unit + "身体帧存在");
            visual.Call("set_facing", 1);
            var normal = visual.Call("get_visual_bounds_global").AsRect2();
            visual.Call("set_facing", -1);
            var flipped = visual.Call("get_visual_bounds_global").AsRect2();
            float center = ((Node2D)actor).GlobalPosition.X;
            Check(Math.Abs(normal.Position.X + flipped.End.X - center*2) < 0.05f, unit + "动画与攻击方向同步镜像 " + action + " " + normal + "/" + flipped + " center=" + center);
            visual.Call("set_facing", 1);
        }
        visual.Call("play_action", new StringName("idle"), true);
    }
}
