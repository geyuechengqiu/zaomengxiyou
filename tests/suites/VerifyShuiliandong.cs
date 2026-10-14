using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Array = Godot.Collections.Array;

public partial class VerifyShuiliandong : Node
{
    private Shuiliandong _level = null!;
    private Node _session = null!, _flow = null!, _bus = null!;
    private CharacterBody2D _player = null!;
    private readonly List<string> _failures = new();
    private readonly HashSet<string> _units = new();
    private Callable _callback;
    private int _checks, _spawned, _maximumLive, _bosses, _victories, _bossRewards, _gorillaRewards;
    private bool _checking;
    private double _configuredBossHp;
    private void Check(bool ok, string text) { ++_checks; if (!ok) _failures.Add(text); }
    private List<Node2D> Living()
    {
        var result = new List<Node2D>();
        foreach (var value in _session.Call("get_entities").AsGodotArray())
        {
            var actor = value.As<Node2D>();
            if (actor.Get("faction_id").AsString() == "enemy" && actor.Call("is_alive").AsBool()) result.Add(actor);
        }
        return result;
    }
    private async Task Step(int frames = 1)
    {
        for (int i = 0; i < frames; ++i)
        {
            await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
            _session.Call("advance_physics", 1.0 / 60);
            _maximumLive = Math.Max(_maximumLive, Living().Count);
        }
    }
    private void Move(float x, float y = 1150)
    {
        _player.Position = new(x,y); _player.Velocity = Vector2.Zero;
        _player.Get("motion").AsGodotObject().Call("clear_impulse"); _player.Set("move_axis", 0.0);
    }
    public override async void _Ready()
    {
        try { await Run(); }
        catch (Exception error) { _failures.Add(error.ToString()); }
        finally
        {
            if (IsInstanceValid(_bus) && _bus.IsConnected("event_pushed", _callback)) _bus.Disconnect("event_pushed", _callback);
            if (IsInstanceValid(_level)) _level.Free();
        }
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        foreach (var error in _failures) GD.PushError(error);
        if (_failures.Count == 0) GD.Print($"PASS Shuiliandong: {_checks} checks; 5 regions/18 plans/48 deaths, native Mihouwang animations and authored skills, native map/terrain, six-monster budget, music and final exit");
        GetTree().Quit(_failures.Count == 0 ? 0 : 1);
    }
    private async Task Run()
    {
        var bossDefinition=GD.Load<BattleEntityDefinition>("res://data/monsters/zaomeng1/mihou_king/definition.tres");
        var dedicated=bossDefinition.attribute_set!;
        var reference=GD.Load<Resource>("res://data/monsters/zaomeng1/mihou_king/attributes.tres");
        var otherBoss=GD.Load<Resource>("res://data/monsters/jushi_lingjun/attributes.tres");
        Check(dedicated.ResourcePath=="res://data/monsters/zaomeng1/mihou_king/mihouwang_attributes.tres" && dedicated!=reference && dedicated!=otherBoss,"猕猴王定义引用独立专属属性资源");
        var values=dedicated.Get("attributes").AsGodotDictionary();
        var original=reference.Get("attributes").AsGodotDictionary();
        bool equal=values.Count==original.Count;
        foreach(var entry in values) equal &= original.TryGetValue(entry.Key,out var value) && value.AsDouble()==entry.Value.AsDouble();
        Check(equal,"专属副本保留全部现有数值与抗性");
        var hpKey=Variant.From(GD.Load<Resource>("res://data/attribute/hpMax.tres"));
        double hp=values[hpKey].AsDouble(), referenceHp=original[hpKey].AsDouble();
        _configuredBossHp = hp;
        var otherValues=otherBoss.Get("attributes").AsGodotDictionary();
        double otherHp=otherValues[hpKey].AsDouble();
        try
        {
            values[hpKey]=hp+100;
            Check(original[hpKey].AsDouble()==referenceHp && otherValues[hpKey].AsDouble()==otherHp,"修改猕猴王专属表不污染旧快照或其他Boss");
        }
        finally { values[hpKey]=hp; }
        _level = GD.Load<PackedScene>("res://game/levels/shuiliandong.tscn").Instantiate<Shuiliandong>();
        _level.enable_player_controls = false; AddChild(_level);
        _session = _level.session; _flow = _level.flow; _player = _level.player;
        _session.SetPhysicsProcess(false);
        _bus = GetNode("/root/CoreSystem").Get("event_bus").As<Node>();
        _callback = Callable.From<string, Array>(OnEvent); _bus.Connect("event_pushed", _callback); _checking = true;
        var definition = _flow.Get("definition").AsGodotObject();
        var regions = _flow.Get("regions").AsGodotArray();
        Check(definition.Call("get_progression_error").AsString() == "", "有效区域/计划依赖图");
        Check(regions.Count == 5 && _flow.Get("plans").AsGodotDictionary().Count == 18, "水帘洞原版5区域18出生计划");
        Check(_level.GetNode("BattleSession/Actors/SpawnPoints").GetChildCount() == 18, "出生点预置并可预览");
        var map = _level.GetNode<Node2D>("BattleSession/Actors");
        MapPresentationChecks.Verify(_session, map.GetNode<Node2D>("Visuals/ShuiliandongVisual"), "MiddleBackground/Cave", Check);
        var groundArt = map.GetNode<Sprite2D>("Visuals/ShuiliandongVisual/GroundArtwork/Ground");
        float artRight = groundArt.GlobalPosition.X + groundArt.Texture.GetWidth() * groundArt.GlobalScale.X;
        float mapRight = map.Get("world_bounds").AsRect2().End.X;
        var lastBounds = regions[4].AsGodotObject().Get("definition").AsGodotObject().Get("bounds").AsRect2();
        Check(mapRight == 9400 && lastBounds.End.X == mapRight && mapRight < artRight - 4, "末区域、地图和镜头右限界位于原地板纹理覆盖内，留出采样余量");
        Check(map.GetNode<Node2D>("Terrain").Position.Y==200 && map.GetNode<Node2D>("SpawnPoints").Position.Y==200 && map.GetNode<Node2D>("Visuals/ShuiliandongVisual/GroundArtwork").Position.Y==200,"地形、原图和出怪点同步下移");
        var finalPosition=map.GetNode<Node2D>("FinalExit").Position;
        Check(map.GetNode<Node2D>("PlayerBirth").Position.Y==1200 && finalPosition.X>7520 && finalPosition.X<9460 && finalPosition.Y>1000 && finalPosition.Y<1300,"玩家出生同步下移，编辑器可调整的通关锚点位于末区域地形");
        foreach(var child in map.GetNode("Visuals/ShuiliandongVisual/GroundArtwork").GetChildren()) Check(!child.Name.ToString().StartsWith("BankContinuation"),"移除新增重复地板层");
        int total = 0;
        foreach (var p in definition.Get("spawn_plans").AsGodotArray()) total += p.AsGodotObject().Get("monster_ids").AsGodotArray().Count;
        Check(total == 48, "原版48敌人");
        Check(_session.Get("audio").AsGodotObject().Get("current_music").AsString() == "zaomeng1_shuiliandong", "源bg1关卡BGM");
        await Step(45);
        Check(_player.Get("motion").AsGodotObject().Get("grounded").AsBool(), "出生落在草地");
        if (System.Array.Exists(OS.GetCmdlineUserArgs(), a => a == "--capture-shuiliandong"))
        {
            await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath("res://.cleanup-backup/shuiliandong-preview.png"));
        }
        _player.Get("attributes").AsGodotObject().Call("set_base_value", new StringName("hpMax"), 1000000.0);
        _player.Get("attributes").AsGodotObject().Call("get_vital", new StringName("health")).AsGodotObject().Call("set_current_value", 1000000.0);
        _player.Set("super_armor", true);
        for (int r = 0; r < 5; ++r)
        {
            var region = regions[r].AsGodotObject(); var entry = region.Get("definition").AsGodotObject().Get("entry_rect").AsRect2();
            Move(entry.GetCenter().X); await Step(1);
            Check(region.Get("entered").AsBool() && !region.Get("exit_open").AsBool(), "延迟怪物存在时区域出口锁定");
            if (r == 1)
            {
                await Step(700); Check(Living().Count == 6 && !region.Get("completed").AsBool(), "多计划遵守6只存活上限，待出生不提前完成");
            }
            int ticks = 0;
            while (!region.Get("completed").AsBool() && ticks++ < 2200)
            {
                foreach (var actor in Living())
                {
                    actor.Call("_finish_spawn_appearance");
                    actor.Get("ai_controller").AsGodotObject().Set("enabled", false);
                    var damage = _session.Call("apply_secondary_damage", actor, _player, 10000000.0, new StringName("verification"), new Dictionary()).AsGodotObject();
                    Check(damage.Get("actual_hp_loss").AsDouble() > 0, "公共伤害与死亡结算");
                }
                await Step();
            }
            Check(region.Get("completed").AsBool() && region.Get("exit_open").AsBool(), $"第{r+1}区域清理完整出生计划后开启");
            if (r < 4)
            {
                Move(region.Get("definition").AsGodotObject().Get("exit_rect").AsRect2().GetCenter().X);
                Check(_flow.Call("request_exit", _player, false).AsBool(), "正常转入下一区域");
            }
        }
        Check(_spawned == 48 && _flow.Get("death_count").AsInt32() == 48 && _bosses == 1 && _units.Count == 4, "48次死亡、4种怪物、仅一个Boss");
        Check(_maximumLive <= 6, "每时刻最多6只敌人");
        await Step(420);
        var anchor = _level.GetNode<BattleFinalExit2D>("BattleSession/Actors/FinalExit");
        var gateway = anchor.GetNode<Node2D>("Gateway");
        Check(gateway.Get("active").AsBool(), "Boss和延迟计划全部结束显示出口");
        Rect2 old = anchor.get_exit_rect(); gateway.Position += new Vector2(500,0);
        Move(old.GetCenter().X,old.GetCenter().Y);
        Check(!_flow.Call("request_exit", _player, false).AsBool(), "移动Gateway子节点后原判定失效");
        Rect2 current = anchor.get_exit_rect(); Check(current.Position.X == old.Position.X+500 && current.Size==old.Size, "光效移动时判定同步，素材2倍缩放不使判定加倍");
        Move(current.GetCenter().X,current.GetCenter().Y);
        Check(_flow.Call("request_exit", _player, false).AsBool(), "在新的通关位置确认胜利");
        Check(!_flow.Call("request_exit", _player, false).AsBool() && _victories == 1, "胜利只触发一次");
        Check(_session.Get("loot").AsGodotObject().Get("awarded").AsGodotDictionary().Count == 48, "经验灵魂掉落统一发奖");
        Check(_bossRewards==1 && _gorillaRewards>0,"关卡内实际击杀结算新的Boss和普通大猩猩掉落");
        Check(_session.Call("get_entities").AsGodotArray().Count == 1, "死亡节点按时清理");
        Move(9340, 1200); await Step(120);
        var camera = _level.GetNode<Camera2D>("Camera2D");
        float viewRight = camera.GetScreenCenterPosition().X + camera.GetViewportRect().Size.X / camera.Zoom.X / 2;
        Check(viewRight <= mapRight + .01f && viewRight < artRight - 4, "清屏后走到最右侧，实际镜头仍不会露出地图终末边缘");
        if (System.Array.Exists(OS.GetCmdlineUserArgs(), a => a == "--capture-shuiliandong"))
        {
            await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            using var image = GetViewport().GetTexture().GetImage();
            image.SavePng(ProjectSettings.GlobalizePath("res://.cleanup-backup/shuiliandong-end.png"));
        }
    }
    private void OnEvent(string id, Array args)
    {
        if (!_checking || args.Count != 1 || args[0].VariantType != Variant.Type.Dictionary) return;
        var data = args[0].AsGodotDictionary();
        if (data.GetValueOrDefault("battle_id").AsStringName() != _session.Get("battle_id").AsStringName()) return;
        if (id == "battle.level.victory") ++_victories;
        if (id == "battle.boss.registered") ++_bosses;
        if (id == "battle.loot.rewarded")
        {
            var dead=_session.Call("get_entity",data["target_entity_id"]).As<Node>();
            string kind=dead.Get("definition_id").AsString();
            if(kind=="水帘洞大猩猩")
            {
                ++_gorillaRewards;
                Check(data["experience"].AsInt32()==6 && data["spirit"].AsInt32()==8,"普通大猩猩实际奖励与小怪相同");
                Check(!data["items"].AsGodotArray().Contains(new StringName("110101001")),"普通大猩猩不掉Boss装备");
            }
            else if(kind=="水帘洞弥猴王")
            {
                ++_bossRewards;
                Check(data["experience"].AsInt32()==76 && data["spirit"].AsInt32()==65,"猕猴王使用第二关Boss经验76和灵魂65");
                var items=data["items"].AsGodotArray();
                Check(items.Count==1 && items.Contains(new StringName("110101002")),"猕猴王掉落原第二关悟空职业装备");
            }
        }
        if (id != "battle.spawn_plan.spawned") return;
        ++_spawned;
        var actor = _session.Call("get_entity", data["entity_id"]).As<Node2D>();
        var bounds = _session.Get("camera_rig").AsGodotObject().Call("get_combat_horizontal_bounds").AsVector2();
        Check(actor.Position.X >= bounds.X && actor.Position.X <= bounds.Y, "实际镜头内出生");
        actor.Get("ai_controller").AsGodotObject().Set("enabled", false);
        string uid = actor.Get("definition_id").AsString(); if (!_units.Add(uid)) return;
        if (uid == "水帘洞弥猴王")
        {
            var attrs = actor.Get("attributes").AsGodotObject();
            Check(attrs.Get("current_level").AsInt32()==5 && attrs.Call("get_value",new StringName("hpMax")).AsDouble()==_configuredBossHp && attrs.Call("get_value",new StringName("atk")).AsDouble()==44 && attrs.Call("get_value",new StringName("phyDef")).AsDouble()==8,"猕猴王读取专属属性资源的生命配置及初始等级、攻击、防御");
            Check(attrs.Call("get_value",new StringName("reHP")).AsDouble()==2 && attrs.Call("get_value",new StringName("runSpeed")).AsDouble()==300 && attrs.Call("get_value",new StringName("fireResist")).AsDouble()==-20 && attrs.Call("get_value",new StringName("soilResist")).AsDouble()==0,"Boss回血移速采用第二关，抗性使用指定风水20/火-20");
            Check(actor.Get("protection").AsGodotObject().Get("maximum").AsInt32()==25000,"Boss保护满值25000");
            Check(_session.Get("audio").AsGodotObject().Get("current_music").AsString() == "boss_01", "Boss登场使用碧玉径音乐");
            Check(actor.Get("abilities").AsGodotObject().Call("has_ability", new StringName("mihouwang_skill3")).AsBool(), "弥猴王原始动作技能");
        }
        else
        {
            Check(!actor.Get("ai_controller").AsGodotObject().HasMethod("cleanup_boss"), "水帘洞普通怪不使用Boss控制器");
            if(uid=="水帘洞大猩猩")
            {
                var protection=actor.Get("protection").AsGodotObject();
                for(int i=0;i<20;++i) protection.Call("register_hit",new Dictionary{{"protection_parameters",new Dictionary{{"protectPoint",999999}}}},1.0,1167.0,1.0);
                Check(protection.Get("trigger_count").AsInt32()==0 && !protection.Get("active").AsBool() && !protection.Get("show_protect").AsBool(),"普通大猩猩连续受击不累积/触发保护");
            }
        }
        var animation = actor.Get("animation").AsGodotObject();
        foreach (var action in animation.Get("profile").AsGodotObject().Get("animations").AsGodotDictionary().Keys)
        {
            Check(animation.Call("play_action", action, true).AsBool(), "原始Spine动作存在："+uid+"/"+action);
            animation.Call("advance_animation", 0.016);
            bool visibleAttachment=false;
            foreach(var slot in animation.Call("get_draw_order").AsGodotArray())
                visibleAttachment|=animation.Call("get_slot_attachment_name",slot).AsString().Length>0;
            Check(visibleAttachment, "动画包含可见身体/骨骼附件");
        }
        animation.Call("play_action", new StringName("idle"), true);
    }
}
