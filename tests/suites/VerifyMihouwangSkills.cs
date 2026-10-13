using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Array = Godot.Collections.Array;

public partial class VerifyMihouwangSkills : Node
{
    private Shuiliandong _level = null!;
    private Node _session = null!;
    private CharacterBody2D _boss = null!, _player = null!;
    private readonly List<string> _failures = new();
    private readonly List<Dictionary> _hits = new();
    private readonly List<(string Ability, long Tick)> _announced = new(), _started = new();
    private Node _bus = null!;
    private Callable _callback;
    private int _checks;
    private void Check(bool value, string message) { ++_checks; if (!value) _failures.Add(message); }
    private async Task Tick(int count = 1)
    {
        for (int i = 0; i < count; ++i)
        {
            await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
            _session.Call("advance_physics", 1.0 / 60);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
    }
    private GodotObject Ability(string action) => _boss.Get("abilities").AsGodotObject().Call("get_ability_instance", new StringName("mihouwang_" + action)).AsGodotObject();
    private Resource Timeline(string action) => Ability(action).Call("get_feature", "BattleFrameTimelineFeature").As<Resource>();
    private double HP => _player.Get("attributes").AsGodotObject().Call("get_vital_value", new StringName("health")).AsDouble();
    private bool Cast(string action, bool skip = false) => _boss.Call("try_activate_skill", new StringName("mihouwang_" + action), new Dictionary { ["skip_cooldown"] = skip }).AsBool();
    private async Task Reset(float distance = 200, int facing = 1)
    {
        _boss.Call("cancel_skill");
        _boss.GetNode<MihouwangProjectilePool2D>("Projectiles").clear_projectiles();
        _boss.Get("protection").AsGodotObject().Call("clear");
        foreach (var actor in new[] { _boss, _player })
        {
            actor.Velocity = Vector2.Zero;
            actor.Get("motion").As<BattleMotionController2D>().clear_impulse();
            actor.Get("action_state").AsGodotObject().Call("enter", 0, new Dictionary());
        }
        _boss.Position = new Vector2(800, 1234);
        _player.Position = new Vector2(800 + distance * facing, 1234);
        await Tick(20);
        _boss.Get("animation").AsGodotObject().Call("set_facing", facing);
        _hits.Clear();
    }
    private void OnEvent(string id, Array args)
    {
        if (id is not ("battle.attack.hit" or "battle.attack.started" or "battle.boss.announced") || args.Count != 1 || !IsInstanceValid(_boss)) return;
        var data = args[0].AsGodotDictionary();
        if (data.GetValueOrDefault("source_entity_id").AsStringName() != _boss.Get("entity_id").AsStringName()) return;
        long tick = _session.Get("clock").AsGodotObject().Get("physics_tick").AsInt64();
        if (id == "battle.boss.announced") _announced.Add((data["ability_id"].AsString(), tick));
        if (id == "battle.attack.started") _started.Add((data["ability_id"].AsString(), tick));
        if (id == "battle.attack.hit" && data.GetValueOrDefault("target_entity_id").AsStringName() == _player.Get("entity_id").AsStringName()) _hits.Add(data.Duplicate(true));
    }
    public override async void _Ready()
    {
        try { await Run(); } catch (Exception error) { _failures.Add(error.ToString()); }
        finally
        {
            if (IsInstanceValid(_bus) && _bus.IsConnected("event_pushed", _callback)) _bus.Disconnect("event_pushed", _callback);
            if (IsInstanceValid(_level)) _level.Free();
        }
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        foreach (var failure in _failures) GD.PushError(failure);
        if (_failures.Count == 0) GD.Print($"PASS Mihouwang seven skills: {_checks} checks; real cooldowns, damage windows, mirrored dash, 0.5s attraction, protection interruption, armor, icons and release cut-ins");
        GetTree().Quit(_failures.Count == 0 ? 0 : 1);
    }
    private async Task Run()
    {
        _level = GD.Load<PackedScene>("res://game/levels/shuiliandong.tscn").Instantiate<Shuiliandong>();
        _level.enable_player_controls = false; AddChild(_level);
        _session = _level.session; _player = _level.player;
        _session.SetPhysicsProcess(false); _level.flow.Call("stop");
        foreach (var gate in _level.GetNode("BattleSession/Actors/Gates").GetChildren()) gate.Call("set_locked", false);
        _player.Get("motion").As<BattleMotionController2D>().horizontal_bounds_active = false;
        var attrs = _player.Get("attributes").AsGodotObject();
        attrs.Call("set_base_value", new StringName("hpMax"), 1000000.0);
        attrs.Call("set_base_value", new StringName("reHP"), 0.0);
        attrs.Call("get_vital", new StringName("health")).AsGodotObject().Call("set_current_value", 1000000.0);
        _boss = _session.Call("spawn_entity_2d", "monsters", new StringName("水帘洞弥猴王"), new Vector2(800, 1234), new StringName(""), true).As<CharacterBody2D>();
        _boss.Call("_finish_spawn_appearance"); _boss.Get("ai_controller").AsGodotObject().Set("enabled", false);
        _bus = GetNode("/root/CoreSystem").Get("event_bus").As<Node>();
        _callback = Callable.From<string, Array>(OnEvent); _bus.Connect("event_pushed", _callback);
        await Tick(30);
        await VerifySlopes();
        if (System.Array.Exists(OS.GetCmdlineUserArgs(), arg => arg == "--slopes-only")) return;
        var definitions = _boss.Get("abilities").AsGodotObject().Call("get_all_ability_ids").AsGodotArray();
        Check(definitions.Count == 7, "只登记七个战斗技能");
        Check(!_boss.HasNode("AnimationAdapter/AttackRanges/runattack") && !_boss.HasNode("AnimationAdapter/AttackRanges/jumpattack"), "取消旧跑攻与跳攻判定句柄");
        var bossAttrs = _boss.Get("attributes").AsGodotObject();
        foreach (var pair in new[] { ("windResist", 20), ("waterResist", 20), ("fireResist", -20) }) Check(bossAttrs.Call("get_value", new StringName(pair.Item1)).AsDouble() == pair.Item2, "实际元素抗性：" + pair.Item1);
        var icons = _session.Get("presentation").As<Node>().GetNode("BossFeedback/HUD/BossBar/Resistances");
        string[] iconNames = { "waterResistAdd", "fireResistRemove", "windResistAdd" };
        for (int i = 0; i < iconNames.Length; ++i)
        {
            var icon = icons.GetChild<TextureRect>(i);
            Check(icon.Visible && icon.Texture.ResourcePath.EndsWith(iconNames[i] + ".png", StringComparison.Ordinal), "血条同步正确抗性图标：" + iconNames[i]);
        }
        var rules = _boss.GetNode<MihouwangCombatController>("CombatRules");
        Check(rules.skill_announcements.Count == 3, "预置三个原版模板播报");
        string[] actions = { "attack1", "attack2", "attack3", "attack4", "skill1", "skill2", "skill3" };
        int[] cooldowns = { 2, 2, 2, 2, 3, 7, 10 };
        int[] starts = { 4, 4, 2, 22, 14, 12, 38 };
        _player.Set("super_armor", true);
        for (int index = 0; index < actions.Length; ++index)
        {
            string action = actions[index];
            await Reset(action == "skill1" ? 650 : 200);
            var ability = Ability(action); var cooldown = ability.Call("get_feature", "CooldownFeature").As<Resource>();
            Check(cooldown.Get("cooldown_duration").AsDouble() == cooldowns[index], "技能冷却配置：" + action);
            double before = HP; int announcements = rules.announcements;
            Check(Cast(action), "实际技能激活：" + action);
            var cast = _boss.Get("attack_instance").AsGodotObject();
            int duration = (int)Math.Ceiling(Timeline(action).Get("duration_frames").AsInt32() * 60 / Timeline(action).Get("source_fps").AsDouble());
            int firstHit = (int)Math.Ceiling(starts[index] * 60 / Timeline(action).Get("source_fps").AsDouble());
            Check(_boss.GetNode<AnimationPlayer>("AnimationAdapter/AnimationPlayer").SpeedScale == .8f, "伤害与原动画同步减速至80%：" + action);
            await Tick(firstHit - 1);
            Check(HP == before, "前摇无伤害：" + action);
            await Tick(duration - firstHit + 2);
            // Detached native and old return projectiles may outlive their caster animation.
            if (action == "skill1") await Tick(100);
            Check(HP < before, "技能有效窗口实际扣血：" + action);
            Check(_hits.Count > 0 && _hits.TrueForAll(h => h["damage_multiplier"].AsDouble() == (index < 4 || index == 6 ? 1.5 : 2.0)), "所有命中使用指定倍率：" + action);
            if (index < 4 || index == 5) Check(_hits.Count == 1, "普攻及冲刺每次只命中一次：" + action);
            if (index == 6)
            {
                Check(_hits.Count == 6, "旋风完整释放六次命中");
                for (int i = 1; i < _hits.Count; ++i) Check(Math.Abs(_hits[i]["sample_time"].AsDouble() - _hits[i - 1]["sample_time"].AsDouble() - .5) < 1e-6, "旋风相邻伤害间隔严格0.5秒");
            }
            Check(!cast.Get("active").AsBool() && !_boss.Get("reactions").AsGodotObject().Call("is_armored", _boss).AsBool(), "施放结束清理动作霸体：" + action);
            if (index >= 4) Check(rules.announcements == announcements + 1, "释放时只播报一次：" + action);
            double remaining = cooldown.Call("get_cooldown_remaining", ability).AsDouble();
            if (remaining > 0)
            {
                Check(!Cast(action), "普通释放遵守实际GAS冷却：" + action);
                _session.Call("set_paused", true); await Tick(10);
                Check(cooldown.Call("get_cooldown_remaining", ability).AsDouble() == remaining, "暂停冻结冷却：" + action);
                _session.Call("set_paused", false);
                await Tick((int)Math.Ceiling(remaining * 60) + 2);
            }
            Check(Cast(action), "冷却结束可以重放：" + action); await Tick(); _boss.Call("cancel_skill");
        }
        // 3000px/s, fixed facing and exactly one sweep hit, in both directions.
        foreach (int facing in new[] { 1, -1 })
        {
            await Reset(250, facing);
            // Measure speed on the long flat bank; the first 800px location is a slope.
            _boss.Position = new Vector2(1800, 1229.2f);
            _player.Position = new Vector2(1800 + facing * 250, 1229.2f);
            _boss.Velocity = _player.Velocity = Vector2.Zero;
            await Tick(20);
            Check(Cast("skill2", true), "镜像冲刺起手");
            await Tick(15); float x = _boss.Position.X; await Tick(4);
            Check(Math.Abs((_boss.Position.X - x) * facing - 200) < 2, $"四帧冲刺位移200世界像素：朝向{facing}，实际{(_boss.Position.X-x)*facing}，位置{_boss.Position}");
            var current = _boss.Get("attack_instance").AsGodotObject();
            double time = current.Get("elapsed").AsDouble(); var position = _boss.Position;
            _session.Call("set_paused", true); await Tick(10);
            Check(_boss.Position == position && current.Get("elapsed").AsDouble() == time, "暂停冻结冲刺位移及时间轴");
            _session.Call("set_paused", false);
            double health = bossAttrs.Call("get_vital_value", new StringName("health")).AsDouble();
            _boss.Call("receive_damage", 1.0, _player, new StringName("normal"), 60, new Dictionary());
            Check(current.Get("active").AsBool() && bossAttrs.Call("get_vital_value", new StringName("health")).AsDouble() < health, "霸体允许伤害但阻止普通打断");
            await Tick(70);
        }
        _player.Set("super_armor", false);
        foreach (int side in new[] { 1, -1 })
        {
            await Reset(0);
            _boss.Position = new Vector2(1800, 1229.2f); _boss.Velocity = Vector2.Zero;
            await Tick(20);
            var segment = Timeline("skill3").GetMeta("projectile_segment").As<Resource>();
            float center = (_boss.GlobalTransform * (segment.Get("hit_rect").AsRect2().GetCenter() * 3)).X;
            _player.Position = new Vector2(center + side * 350, 1234);
            Check(Cast("skill3", true), "中心两侧吸附技能起手");
            await Tick(48); float initial = Math.Abs(_player.Position.X - center); await Tick(15);
            Check(Math.Abs(_player.Position.X - center) < initial - 150, "左右两侧0.25秒均向中心拉近超过150像素");
            Check(_hits.Count == 1, "半秒内不重复触发吸附伤害");
        }
        await Reset(0); _boss.Position = new Vector2(1800, 1229.2f); await Tick(20);
        float nearCenter = (_boss.GlobalTransform * (Timeline("skill3").GetMeta("projectile_segment").As<Resource>().Get("hit_rect").AsRect2().GetCenter() * 3)).X;
        _player.Position = new Vector2(nearCenter + 60, 1229.2f); _player.Velocity = Vector2.Zero;
        Cast("skill3", true); await Tick(70);
        Check(Math.Abs(_player.Position.X - nearCenter) < 1, "增强吸附在中心停止，不穿过旋风中心");
        // Force a full protection bar during another cast and while skill3 is cooling.
        await Tick(660); await Reset(); Check(Cast("skill3"), "保护前先进入旋风冷却"); await Tick(275);
        Check(!Cast("skill3"), "保护前正常释放被冷却挡住");
        Check(Cast("attack1", true), "保护前正在释放普攻");
        var oldCast = _boss.Get("attack_instance").AsGodotObject();
        int count = rules.protection_casts; int announced = rules.announcements;
        _boss.Get("protection").AsGodotObject().Call("register_hit", new Dictionary
            { ["protection_parameters"] = new Dictionary { ["protectPoint"] = 999999 } }, 1.0, 1943.0, 1.0);
        var protectCast = _boss.Get("attack_instance").AsGodotObject();
        Check(!oldCast.Get("active").AsBool() && protectCast.Get("active").AsBool() && protectCast.Get("ability_id").AsString() == "mihouwang_skill3", "保护立即打断旧技能并直接释放旋风");
        Check(rules.protection_casts == count + 1 && rules.announcements == announced + 1, "保护强制释放及播报各一次");
        Check(Ability("skill3").Call("get_feature", "CooldownFeature").As<Resource>().Call("get_cooldown_remaining", Ability("skill3")).AsDouble() > 9.9, "保护重新开始10秒冷却");
        await Tick(280);
        Check(!_boss.Get("protection").AsGodotObject().Get("active").AsBool() && !protectCast.Get("active").AsBool(), "保护及旋风均按实际时长清理");
        // Capture the actual HUD banners and actor effects using the normal battle path.
        if (System.Array.Exists(OS.GetCmdlineUserArgs(), arg => arg == "--capture-skills"))
        {
            foreach (string action in new[] { "skill1", "skill2", "skill3" })
            {
                _player.Set("super_armor", true); await Reset(300); Cast(action, true); await Tick(action == "skill3" ? 70 : 20);
                await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath("res://.cleanup-backup/mihouwang-" + action + "-seven.png"));
            }
        }
        _boss.Call("cancel_skill"); await Tick(660); await Reset();
        await VerifyAnnouncementArmor();
        // Use a fresh AI: the earlier disabled controller intentionally did not
        // advance its group clock while testing a forced protection cooldown.
        _session.Call("despawn_entity", _boss.Get("entity_id")); await Tick(2);
        _boss = _session.Call("spawn_entity_2d", "monsters", new StringName("水帘洞弥猴王"), new Vector2(1800, 1229.2f), new StringName(""), true).As<CharacterBody2D>();
        _boss.Call("_finish_spawn_appearance"); _boss.Get("ai_controller").AsGodotObject().Set("enabled", false);
        _player.Position = new Vector2(1950, 1229.2f); _player.Velocity = Vector2.Zero;
        await Tick(30);
        var ai = _boss.Get("ai_controller").AsGodotObject();
        _announced.Clear(); _started.Clear();
        ai.Set("home", _boss.Position); ai.Set("enabled", true);
        _player.Set("super_armor", true);
        for (int i = 0; i < 1800; ++i)
        {
            // Alternate near, projectile and dash ranges, following the actor's current position.
            _player.Position = new Vector2(_boss.Position.X + (i < 600 ? 150 : i < 1200 ? 650 : 1200), _boss.Position.Y);
            _player.Velocity = Vector2.Zero; await Tick();
        }
        var chosen = ai.Get("selected_skills").AsGodotArray();
        foreach (var action in new[] { "skill1", "skill2", "skill3" }) Check(chosen.Contains(new StringName("mihouwang_" + action)), "不同距离AI实际选择：" + action + "；" + chosen);
        foreach (string action in new[] { "mihouwang_skill1", "mihouwang_skill2", "mihouwang_skill3" })
        {
            var start = _started.Find(e => e.Ability == action);
            var announcement = _announced.FindLast(e => e.Ability == action && e.Tick < start.Tick);
            Check(start.Ability == action && start.Tick - announcement.Tick == 12, "AI技能播报提前0.2秒且不在施放时重播：" + action);
        }
        _boss.Call("cancel_skill");
        Check(_boss.GetNode<AnimationPlayer>("AnimationAdapter/AnimationPlayer").SpeedScale == 1, "技能结束恢复正常待机、移动播放速度");
        await StartAnnouncement("skill1");
        var deathRules = _boss.GetNode<MihouwangCombatController>("CombatRules");
        _boss.Call("receive_damage", 1000000.0, _player, new StringName("normal"), 60, new Dictionary());
        Check(!_boss.Call("is_alive").AsBool() && !deathRules.announcement_guard_active, "播报霸体不免疫致死伤害，死亡立即清理");
    }

    private async Task<GodotObject> StartAnnouncement(string action)
    {
        _session.Call("despawn_entity", _boss.Get("entity_id")); await Tick(2);
        _boss = _session.Call("spawn_entity_2d", "monsters", new StringName("水帘洞弥猴王"), new Vector2(1800, 1229.2f), new StringName(""), true).As<CharacterBody2D>();
        _boss.Call("_finish_spawn_appearance");
        var ai = _boss.Get("ai_controller").AsGodotObject(); ai.Set("enabled", false);
        _player.Position = new Vector2(action == "skill3" ? 1950 : 2450, 1229.2f); _player.Velocity = Vector2.Zero;
        await Tick(30);
        var profile = (BattleBossProfile)ai.Get("boss_profile").As<Resource>().Duplicate(true);
        var only = new Godot.Collections.Array<BattleBossSkillRule>();
        foreach (var rule in profile.skills) if (rule.ability_id == "mihouwang_" + action) only.Add(rule);
        profile.skills = only; ai.Set("boss_profile", profile);
        ai.Set("home", _boss.Position); ai.Set("decision_remaining", 0.0); ai.Set("enabled", true);
        await Tick();
        Check(ai.Get("pending_rule").AsGodotObject() != null && _boss.GetNode<MihouwangCombatController>("CombatRules").announcement_guard_active, "真实AI播报开始立即霸体：" + action);
        return ai;
    }

    private async Task VerifyAnnouncementArmor()
    {
        var tags = GetNode("/root/TagManager");
        foreach (string action in new[] { "skill1", "skill2", "skill3" })
        {
            var ai = await StartAnnouncement(action);
            var rules = _boss.GetNode<MihouwangCombatController>("CombatRules");
            var motion = _boss.Get("motion").As<BattleMotionController2D>();
            var attrs = _boss.Get("attributes").AsGodotObject();
            Check(_boss.GetNode("AnimationAdapter/SuperArmorEffect").Get("active").AsBool(), "播报期间立即显示独立霸体描边：" + action);
            foreach (string kind in new[] { "normal", "heavy", "launch" })
            {
                double hp = attrs.Call("get_vital_value", new StringName("health")).AsDouble();
                _boss.Call("receive_damage", 1.0, _player, new StringName(kind), 100, new Dictionary
                { ["reaction_type"] = "knockback", ["hit_stun"] = 1.0, ["knockback_speed"] = 1000.0, ["knockback_duration"] = .2, ["launch_speed"] = 700.0 });
                Check(attrs.Call("get_vital_value", new StringName("health")).AsDouble() < hp && ai.Get("pending_rule").AsGodotObject() != null
                    && motion.impulse_remaining == 0 && _boss.Velocity.Y >= 0, "播报期间受伤但不硬直/击退/击飞：" + action + "/" + kind);
            }
            Check(_boss.Call("apply_status_definition", new StringName("stun"), _player).AsGodotObject() == null, "眩晕无法打断播报：" + action);
            double lead = ai.Get("lead_remaining").AsDouble();
            _session.Call("set_paused", true); await Tick(5);
            Check(ai.Get("lead_remaining").AsDouble() == lead && rules.announcement_guard_active, "暂停保留预警霸体并冻结0.2秒等待");
            _session.Call("set_paused", false); await Tick(11);
            Check(ai.Get("pending_rule").AsGodotObject() != null, "0.2秒到达前不提前释放：" + action);
            await Tick();
            Check(_boss.Get("attack_instance").AsGodotObject().Get("active").AsBool() && rules.announcement_guard_active, "播报霸体无缝延续到技能动作：" + action);
            ai.Set("enabled", false);
            // Another armor source must survive removal of the owned cast guard.
            tags.Call("add_tag", _boss, new StringName("state.super_armor"));
            await Tick((int)Math.Ceiling(Timeline(action).Get("duration_frames").AsDouble() * 60 / Timeline(action).Get("source_fps").AsDouble()) + 2);
            Check(!rules.announcement_guard_active && tags.Call("has_tag", _boss, new StringName("state.super_armor")).AsBool()
                && !tags.Call("has_tag", _boss, new StringName("state.debuff_immune")).AsBool(), "动作结束清理自身保护，保留其他霸体来源：" + action);
            tags.Call("remove_tag", _boss, new StringName("state.super_armor"));
            Check(!_boss.Get("reactions").AsGodotObject().Call("is_armored", _boss).AsBool()
                && !_boss.Get("reaction_profile").As<BattleHitReactionProfile>().armor_blocks_kinds.Contains("launch"), "恢复普通受击配置且无残留霸体：" + action);
        }
        var cancelled = await StartAnnouncement("skill1");
        cancelled.Set("enabled", false); await Tick();
        Check(!_boss.GetNode<MihouwangCombatController>("CombatRules").announcement_guard_active && !tags.Call("has_tag", _boss, new StringName("state.super_armor")).AsBool(), "取消AI预约立即清理播报霸体");
        await StartAnnouncement("skill2");
        var exiting = _boss.GetNode<MihouwangCombatController>("CombatRules");
        _session.Call("despawn_entity", _boss.Get("entity_id"));
        Check(!exiting.announcement_guard_active && !tags.Call("has_tag", _boss, new StringName("state.super_armor")).AsBool(), "播报时离场立即清理霸体");
        // Keep a valid actor for the next standard AI selection checks.
        _boss = _session.Call("spawn_entity_2d", "monsters", new StringName("水帘洞弥猴王"), new Vector2(1800, 1229.2f), new StringName(""), true).As<CharacterBody2D>();
        _boss.Call("_finish_spawn_appearance"); _boss.Get("ai_controller").AsGodotObject().Set("enabled", false);
    }

    private async Task VerifySlopes()
    {
        _player.Position = new Vector2(2100, 1229.2f);
        var motion = _boss.Get("motion").As<BattleMotionController2D>();
        foreach (float x in new[] { 740f, 1300f })
        {
            _boss.Position = new Vector2(x, 900); _boss.Velocity = Vector2.Zero;
            motion.grounded = false; await Tick(90);
            var start = _boss.Position; int serial = motion.landing_serial, airborne = 0;
            for (int i = 0; i < 120; ++i) { await Tick(); if (!motion.grounded) ++airborne; }
            GD.Print($"SLOPE idle x={x}: {start} -> {_boss.Position}, landings={motion.landing_serial-serial}, airborne={airborne}");
            Check(_boss.Position.DistanceTo(start) < .5f && airborne == 0 && motion.landing_serial == serial, "斜坡静止不滑动、不反复切换落地动画：" + x);
            Cast("skill3", true); await Tick(190);
            Check(_boss.Position.DistanceTo(start) < .5f && motion.grounded && motion.landing_serial == serial, "斜坡施放旋风保持身体与判定框稳定：" + x);
            _boss.Call("cancel_skill"); _boss.Get("protection").AsGodotObject().Call("clear");
        }
        var profile = _boss.Get("action_profile").As<Resource>();
        foreach (int facing in new[] { 1, -1 })
        {
            _boss.Position = new Vector2(facing == 1 ? 610 : 1460, 900); _boss.Velocity = Vector2.Zero;
            motion.grounded = false; await Tick(90);
            int airborne = 0, serial = motion.landing_serial;
            for (int i = 0; i < 260; ++i)
            {
                motion.advance(1.0 / 60, facing * 255, profile, 1);
                if (!motion.grounded) ++airborne;
            }
            GD.Print($"SLOPE traverse facing={facing}: {_boss.Position}, landings={motion.landing_serial-serial}, airborne={airborne}");
            Check(airborne == 0 && motion.landing_serial == serial, "双向上下坡保持接地、不反复落地：" + facing);
        }
        await Reset();
    }
}
