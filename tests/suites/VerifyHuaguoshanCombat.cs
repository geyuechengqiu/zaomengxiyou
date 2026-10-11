using Godot;
using Godot.Collections;
using System;
using System.Threading.Tasks;

public partial class VerifyHuaguoshanCombat : Node
{
    private Huaguoshan _level = null!;
    private Node _session = null!;
    private CharacterBody2D _player = null!;
    private int _checks;
    private readonly System.Collections.Generic.List<string> _failures = new();
    private void Check(bool ok, string message) { ++_checks; if (!ok) _failures.Add(message); }
    public override async void _Ready()
    {
        try { await Run(); } catch (Exception error) { _failures.Add(error.ToString()); }
        finally { if (IsInstanceValid(_level)) _level.Free(); }
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        foreach (string failure in _failures) GD.PushError(failure);
        if (_failures.Count == 0) GD.Print($"PASS Huaguoshan combat: {_checks} checks; original hit1, hit/miss/mirror/dedup, slope impulses, true launch, drop-through, aggro and slower movement");
        GetTree().Quit(_failures.Count == 0 ? 0 : 1);
    }
    private async Task Tick(double delta = 1.0 / 60)
    {
        await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
        _session.Call("advance_physics", delta);
    }
    private async Task MotionTick(double delta)
    {
        await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
        ((BattleMotionController2D)_player.Get("motion").AsGodotObject()).advance(delta, 0, _player.Get("action_profile").As<Resource>(), 1);
    }
    private void Place(float x, float y)
    {
        _player.Position = new(x,y); _player.Velocity = Vector2.Zero;
        var motion = (BattleMotionController2D)_player.Get("motion").AsGodotObject();
        motion.clear_impulse(); motion.grounded = false;
    }
    private async Task Run()
    {
        _level = GD.Load<PackedScene>("res://game/levels/huaguoshan.tscn").Instantiate<Huaguoshan>();
        _level.enable_player_controls = false; AddChild(_level);
        _session = _level.session; _player = _level.player;
        _session.SetPhysicsProcess(false); _level.flow.Call("stop");
        foreach (var gate in _level.GetNode("BattleSession/Actors/Gates").GetChildren()) gate.Call("set_locked", false);
        var motion = (BattleMotionController2D)_player.Get("motion").AsGodotObject();
        foreach(double delta in new[] { 1.0/60, 1.0/15 })
        {
            Place(4129,690);
            for(int i=0;i<40;++i) await Tick();
            Check(motion.grounded && _player.Position.Y < 750, "可正常站在花果山单向平台");
            int budget = motion.jumps_used;
            var intent = GD.Load<GDScript>("res://addons/godot_core_system-0.0.4/source/operation_system/operation_intent.gd").New().AsGodotObject();
            intent.Set("action", new StringName("jump")); intent.Set("pressed", true);
            intent.Set("payload", new Dictionary { ["held_intents"] = new Godot.Collections.Array<StringName> { "move_down" } });
            Check(_player.Get("action_state").AsGodotObject().Call("handle_operation", intent, new Dictionary()).AsInt32() == 0, "下+跳跃意图受理穿过单向平台");
            Check(!motion.grounded && _player.Velocity.Y > 0 && motion.jumps_used == budget, "向下穿透不消耗空中跳跃");
            _session.Call("set_paused", true); Vector2 paused = _player.Position;
            await Tick(1); Check(_player.Position == paused && motion.dropped_platform_count > 0, "暂停不提前解除平台例外");
            _session.Call("set_paused", false);
            for(int i=0;i<(int)Math.Ceiling(1.2/delta);++i) await Tick(delta);
            Check(motion.grounded && _player.Position.Y > 1000 && motion.dropped_platform_count == 0, "穿过后落在下方实体地面并恢复碰撞");
            Place(4129,690);
            for(int i=0;i<40;++i) await Tick();
            Check(motion.grounded && _player.Position.Y < 750, "同一平台恢复后可以再次站立");
        }
        // Actual authored ramps, approached uphill in both directions at 60 and 15 FPS.
        foreach (double delta in new[] { 1.0/60, 1.0/15 })
        foreach (int direction in new[] { 1, -1 })
        {
            Place(direction > 0 ? 1940 : 2740, 980);
            for (int i=0;i<50;++i) await MotionTick(1.0/60);
            Check(motion.grounded, "斜坡入口真实着地");
            motion.apply_impulse(direction * 1800, 0.25, 0, -1, false);
            bool noBallisticLaunch = true; float rise = _player.Position.Y;
            for (int i=0;i<(int)Math.Ceiling(0.8/delta);++i)
            {
                await MotionTick(delta); rise = Math.Min(rise, _player.Position.Y);
                if (motion.grounded && _player.Velocity.Y < -0.01) noBallisticLaunch = false;
            }
            Check(noBallisticLaunch && rise > 800, $"纯横向击退不携带坡面向上弹道 {direction}/{delta}: {_player.Position}");
        }
        Place(800,980);
        for(int i=0;i<50;++i) await MotionTick(1.0/60);
        float floor = _player.Position.Y, top = floor;
        motion.apply_impulse(0, 0.5, 300, 2700, true);
        for(int i=0;i<50;++i) { await MotionTick(1.0/60); top=Math.Min(top,_player.Position.Y); }
        Check(floor-top > 10 && floor-top < 25 && motion.grounded, "原-5帧速度仍真实击飞并正常落地");
        var attributes = _player.Get("attributes").AsGodotObject();
        attributes.Call("set_base_value", new StringName("hpMax"), 100000.0);
        attributes.Call("get_vital", new StringName("health")).AsGodotObject().Call("set_current_value", 100000.0);
        _player.Set("super_armor", true);
        foreach (string unit in new[] { "little_monkey", "mountain_monkey", "gorilla" })
        {
            string id = unit == "little_monkey" ? "花果山小猴" : unit == "mountain_monkey" ? "花果山山猴" : "花果山大猩猩";
            var actor = _session.Call("spawn_entity_2d", "monsters", id, new Vector2(800,1037), new StringName(""), true).As<CharacterBody2D>();
            Check(IsInstanceValid(actor), id + "可独立生成");
            Check(Math.Abs(actor.Get("motion").As<BattleMotionController2D>().movement_speed_scale-0.85)<0.001, id + "移速降低15%，技能击退不缩放");
            actor.Get("ai_controller").AsGodotObject().Set("enabled", false);
            actor.Call("_finish_spawn_appearance");
            for(int i=0;i<40;++i) await Tick();
            foreach (int facing in new[] { 1, -1, 1 })
            {
                bool miss = facing == 1 && actor.HasMeta("verified_hit");
                actor.Position = new(800,1037); actor.Velocity = Vector2.Zero;
                Place(800 + facing * (miss ? 500 : 60),1037);
                actor.Get("animation").AsGodotObject().Call("set_facing", facing);
                for(int i=0;i<20;++i) await Tick();
                string skill = "zaomeng1_" + unit + "_hit1";
                Check(actor.Call("try_activate_skill", new StringName(skill), new Dictionary()).AsBool(), id + "原hit1起手");
                var cast = actor.Get("attack_instance").AsGodotObject();
                Check(IsInstanceValid(cast), "释放实例存在");
                double healthBefore = attributes.Call("get_vital_value", new StringName("health")).AsDouble();
                for(int i=0;i<70;++i) await Tick(i%2==0 ? 1.0/15 : 1.0/60);
                Check(cast.Get("hit_count").AsInt32() == (miss ? 0 : 1), id + "窗口命中次数与镜像/打空一致");
                double lost = healthBefore - attributes.Call("get_vital_value", new StringName("health")).AsDouble();
                Check(miss ? lost == 0 : lost > 0, id + "命中实际扣血/打空不扣血");
                Check(!cast.Get("active").AsBool() && cast.Get("windows").AsGodotDictionary().Count == 0, id + "释放结束清理旧窗口");
                if (facing < 0) actor.SetMeta("verified_hit", true);
            }
            var controller = actor.Get("ai_controller").AsGodotObject();
            if (unit == "little_monkey")
            {
                controller.Set("enabled", true);
                Place(actor.Position.X+60, actor.Position.Y);
                for(int i=0;i<150;++i) await Tick();
                Check(controller.Get("successful_casts").AsInt32()==0 && !actor.GetMeta("zaomeng1_alerted", false).AsBool(), "小猴自己播放攻击动画不会误触发受击仇恨");
                _session.Call("apply_secondary_damage", actor, _player, 1.0, new StringName("verification"), new Dictionary());
                Check(actor.GetMeta("zaomeng1_alerted", false).AsBool(), "真实扣血才激活小猴仇恨");
                Place(actor.Position.X+450, actor.Position.Y);
                float beforeGap = Math.Abs(actor.Position.X-_player.Position.X);
                for(int i=0;i<100;++i) await Tick();
                Check(Math.Abs(actor.Position.X-_player.Position.X)<beforeGap-100, "小猴受击后追踪攻击来源并主动靠近");
                double health = attributes.Call("get_vital_value", new StringName("health")).AsDouble();
                for(int i=0;i<240;++i) await Tick();
                Check(attributes.Call("get_vital_value", new StringName("health")).AsDouble()<health, "小猴继续接近有效攻击范围并实际命中");
            }
            controller.Set("enabled", true);
            int casts = 0;
            for (int i=0;i<480;++i)
            {
                Place(actor.Position.X + 60, actor.Position.Y);
                await Tick();
                if (actor.Get("attack_instance").AsGodotObject() is GodotObject attack && attack.Get("active").AsBool()) ++casts;
            }
            Check(casts > 0, id + "真实AI经同一动作入口释放hit1");
            _session.Call("despawn_entity", actor.Get("entity_id"));
            await Tick();
        }
    }
}
