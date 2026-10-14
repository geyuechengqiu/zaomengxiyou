using Godot;
using Godot.Collections;
using System;
using Array = Godot.Collections.Array;

/// <summary>Tornado damage pulses and continuous attraction use the battle clock.</summary>
[GlobalClass]
public partial class MihouwangCombatController : Node, IBattleCombatStep
{
    [Export] public Array<Texture2D> skill_announcements { get; set; } = new();
    [Export(PropertyHint.Range, "0,1000,10")] public double attraction_distance { get; set; } = 260;
    [Export(PropertyHint.Range, "0.05,0.5,0.01")] public double attraction_duration { get; set; } = .3;
    [Export(PropertyHint.Range, "0,2,0.05")] public double announcement_lead_seconds { get; set; } = .2;
    private Node2D _actor = null!;
    private Node _animation = null!;
    private Node _bus = null!;
    private Callable _callback;
    private Callable _animationCallback;
    private int _request;
    private bool _startingProtection;
    private Node _tags = null!;
    private StringName _guardAbility = "", _guardAttack = "";
    private static readonly StringName NormalHit = "normal";
    private int _guardRequest;
    private BattleHitReactionProfile? _originalReaction, _guardReaction;
    public bool announcement_guard_active { get; private set; }
    public int protection_casts { get; private set; }
    public int announcements { get; private set; }

    public override void _Ready()
    {
        _actor = GetParent<Node2D>();
        _tags = GetNode("/root/TagManager");
        _animation = _actor.GetNode("AnimationAdapter");
        _animationCallback = Callable.From<StringName>(OnActionStarted);
        _animation.Connect("action_started", _animationCallback);
        _bus = GetNode("/root/CoreSystem").Get("event_bus").As<Node>();
        _callback = Callable.From<string, Array>(OnEvent);
        _bus.Connect("event_pushed", _callback);
        CallDeferred(nameof(refresh_ai_ranges));
    }

    // Per-actor rules follow the actual scene rectangles, including instance overrides.
    public void refresh_ai_ranges()
    {
        // A deferred refresh can outlive a despawn in the same frame.
        if (!IsInstanceValid(_actor) || _actor.IsQueuedForDeletion()) return;
        var ai = _actor.Get("ai_controller").As<Node>();
        if (!IsInstanceValid(ai)) return;
        var profile = (BattleBossProfile)ai.Get("boss_profile").As<Resource>().Duplicate(true);
        ai.Set("boss_profile", profile);
        foreach (var rule in profile.skills)
        {
            string action = rule.ability_id.ToString().Replace("mihouwang_", "");
            var instance = Ability(rule.ability_id);
            var timeline = instance.Call("get_feature", "BattleFrameTimelineFeature").As<Resource>();
            int announcementIndex = action switch { "skill1" => 0, "skill2" => 1, "skill3" => 2, _ => -1 };
            rule.announcement_lead_seconds = announcementIndex >= 0 ? announcement_lead_seconds : 0;
            if (announcementIndex >= 0 && announcementIndex < skill_announcements.Count)
                rule.announcement = skill_announcements[announcementIndex];
            Resource segment = timeline.HasMeta("projectile_segment")
                ? timeline.GetMeta("projectile_segment").As<Resource>()
                : timeline.Get("attack_segments").AsGodotArray()[0].As<Resource>();
            var rect = segment.Get("hit_rect").AsRect2();
            rule.attack_range = Math.Max(1, rect.End.X * 3 * Math.Abs(_actor.GlobalScale.X) + 80);
            rule.vertical_range = Math.Max(100, -rect.Position.Y * 3 * Math.Abs(_actor.GlobalScale.Y));
            if (action == "skill1")
            {
                rule.minimum_range = 300;
                rule.attack_range += 900; // One second of the detached native projectile.
                rule.vertical_range = 320;
            }
            else if (action == "skill2")
            {
                rule.minimum_range = 300;
                var dash = timeline.Get("motion_windows").AsGodotArray()[0].As<BattleSkillMotion>();
                rule.attack_range += dash.velocity.X * (dash.end_frame - dash.start_frame) / timeline.Get("source_fps").AsDouble();
                rule.vertical_range = 140;
            }
        }
    }

    private GodotObject Ability(StringName id) => _actor.Get("abilities").AsGodotObject().Call("get_ability_instance", id).AsGodotObject();

    private void OnActionStarted(StringName action)
    {
        var abilities = _actor.Get("abilities").AsGodotObject();
        var id = new StringName("mihouwang_" + action);
        var player = _animation.Call("get_animation_player").As<AnimationPlayer>();
        // World movement, cooldowns and detached projectiles keep the combat clock.
        player.SpeedScale = abilities != null && abilities.Call("has_ability", id).AsBool()
            ? Ability(id).Call("get_feature", "BattleFrameTimelineFeature").As<Resource>().Get("source_fps").AsSingle() / 60 : 1;
    }

    private void OnEvent(string id, Array args)
    {
        if (id is not ("battle.attack.started" or "battle.attack.finished" or "battle.protection.triggered" or "battle.mihouwang.tornado" or "battle.boss.announced" or "battle.boss.announcement_cancelled" or "battle.entity_died" or "battle.entity_despawned" or "battle.level.victory" or "battle.level.failed") || args.Count != 1) return;
        var data = args[0].AsGodotDictionary();
        var session = _actor.Get("session").As<Node>();
        if (session == null || data.GetValueOrDefault("battle_id").AsStringName() != session.Get("battle_id").AsStringName()) return;
        if (id is "battle.level.victory" or "battle.level.failed"
            || id == "battle.entity_despawned" && data.GetValueOrDefault("target_entity_id").AsStringName() == _actor.Get("entity_id").AsStringName())
        { EndGuard(); return; }
        if (data.GetValueOrDefault("source_entity_id").AsStringName() != _actor.Get("entity_id").AsStringName()) return;
        if (id == "battle.entity_died") { EndGuard(); return; }
        if (id == "battle.boss.announcement_cancelled")
        { if (data.GetValueOrDefault("request_id").AsInt32() == _guardRequest) EndGuard(); return; }
        if (id == "battle.attack.finished")
        { if (data.GetValueOrDefault("attack_id").AsStringName() == _guardAttack) EndGuard(); return; }
        if (!_actor.Call("is_alive").AsBool()) return;
        if (id == "battle.boss.announced")
        {
            ++announcements;
            var selected = data.GetValueOrDefault("ability_id").AsStringName();
            if (IsSpecial(selected) && data.GetValueOrDefault("lead_seconds").AsDouble() > 0)
                BeginGuard(selected, data.GetValueOrDefault("request_id").AsInt32());
            return;
        }
        if (id == "battle.protection.triggered") { StartProtection(); return; }
        if (id == "battle.mihouwang.tornado") { Pulse(session, data); return; }
        string ability = data.GetValueOrDefault("ability_id").AsString();
        int index = ability switch { "mihouwang_skill1" => 0, "mihouwang_skill2" => 1, "mihouwang_skill3" => 2, _ => -1 };
        if (index < 0) EndGuard();
        else
        {
            BeginGuard(new StringName(ability), _guardAbility == ability ? _guardRequest : 0);
            _guardAttack = data.GetValueOrDefault("attack_id").AsStringName();
        }
        if (index < 0 || index >= skill_announcements.Count) return;
        // AI has already announced before the windup; do not restart its banner.
        var pending = _actor.Get("ai_controller").As<Node>().Get("pending_rule").As<BattleBossSkillRule>();
        if (pending != null && pending.ability_id == ability) return;
        // Release events also cover manually activated and protection-triggered skills.
        // Negative request IDs cannot collide with the AI's positive request serials.
        var payload = new Dictionary
        {
            ["request_id"] = --_request, ["ability_id"] = ability,
            ["announcement"] = skill_announcements[index], ["lead_seconds"] = 0.0,
            ["warning_rect"] = new Rect2(), ["origin"] = _actor.GlobalPosition,
            ["facing"] = _actor.Get("animation").AsGodotObject().Call("get_facing")
        };
        _actor.Call("publish_battle_event", new StringName("battle.boss.announced"), payload);
        _actor.Call("publish_battle_event", new StringName("battle.boss.action_started"), payload);
    }

    private static bool IsSpecial(StringName ability) => ability == "mihouwang_skill1" || ability == "mihouwang_skill2" || ability == "mihouwang_skill3";

    private void BeginGuard(StringName ability, int request)
    {
        if (announcement_guard_active && _guardAbility == ability) return;
        EndGuard();
        _originalReaction = _actor.Get("reaction_profile").As<BattleHitReactionProfile>();
        _guardReaction = (BattleHitReactionProfile)_originalReaction.Duplicate(true);
        foreach (StringName kind in new StringName[] { "normal", "heavy", "launch" })
            if (!_guardReaction.armor_blocks_kinds.Contains(kind)) _guardReaction.armor_blocks_kinds.Add(kind);
        _guardReaction.armor_blocks_displacement = true;
        _actor.Set("reaction_profile", _guardReaction);
        _guardAbility = ability; _guardRequest = request; announcement_guard_active = true;
        // Own one reference of each tag; never remove armor granted by other systems.
        _tags.Call("add_tag", _actor, new StringName("state.super_armor"));
        _tags.Call("add_tag", _actor, new StringName("state.debuff_immune"));
    }

    private void EndGuard()
    {
        if (!announcement_guard_active) return;
        announcement_guard_active = false;
        if (IsInstanceValid(_actor))
        {
            if (_originalReaction != null && _actor.Get("reaction_profile").AsGodotObject() == _guardReaction)
                _actor.Set("reaction_profile", _originalReaction);
            if (IsInstanceValid(_tags))
            {
                _tags.Call("remove_tag", _actor, new StringName("state.super_armor"));
                _tags.Call("remove_tag", _actor, new StringName("state.debuff_immune"));
            }
        }
        _guardAbility = _guardAttack = ""; _guardRequest = 0;
        _originalReaction = _guardReaction = null;
    }

    private void StartProtection()
    {
        if (_startingProtection) return;
        _startingProtection = true;
        try
        {
            EndGuard();
            _actor.Call("cancel_skill", new StringName("protection"));
            _actor.Get("motion").As<BattleMotionController2D>().clear_impulse();
            var ai = _actor.Get("ai_controller").As<Node>();
            ai.Set("pending_rule", default(Variant)); ai.Set("lead_remaining", 0.0);
            _actor.Get("action_state").AsGodotObject().Call("enter", 0, new Dictionary());
            var id = new StringName("mihouwang_skill3");
            // Protection must work during its own cooldown and after aerial knockback.
            if (!_actor.Call("try_activate_skill", id, new Dictionary
                { ["protection"] = true, ["skip_cooldown"] = true, ["derived_from"] = "protection" }).AsBool()) return;
            var instance = Ability(id);
            instance.Call("get_feature", "CooldownFeature").As<Resource>().Call("start_cooldown", instance);
            var deadlines = ai.Get("group_deadlines").AsGodotDictionary();
            deadlines[new StringName("skill3")] = ai.Get("elapsed").AsDouble() + 10;
            var protection = _actor.Get("protection").AsGodotObject();
            protection.Set("active", true);
            var timeline = instance.Call("get_feature", "BattleFrameTimelineFeature").As<Resource>();
            protection.Set("active_remaining", timeline.Get("duration_frames").AsDouble() / timeline.Get("source_fps").AsDouble());
            ++protection_casts;
        }
        finally { _startingProtection = false; }
    }

    private void Pulse(Node session, Dictionary marker)
    {
        var cast = _actor.Get("attack_instance").AsGodotObject();
        if (cast == null || !cast.Get("active").AsBool() || cast.Get("attack_id").AsStringName() != marker.GetValueOrDefault("attack_id").AsStringName()) return;
        var segment = cast.Get("timeline").As<Resource>().GetMeta("projectile_segment").As<Resource>();
        var context = segment.Call("get_payload").AsGodotDictionary();
        context.Merge(marker, true);
        int facing = cast.Get("facing").AsInt32();
        var rect = TornadoRect(cast, segment);
        foreach (var value in session.Call("get_entities").AsGodotArray())
        {
            if (!cast.Get("active").AsBool() || !_actor.Call("is_alive").AsBool() || session.Call("is_simulation_blocked").AsBool()) break;
            var target = value.As<Node2D>();
            if (target == _actor || target.IsQueuedForDeletion() || !target.Call("is_alive").AsBool() || target.Call("is_spawning").AsBool()) continue;
            if (!session.Get("factions").AsGodotObject().Call("is_hostile", _actor.Get("faction_id"), target.Get("faction_id")).AsBool()) continue;
            if (!InTornado(target, rect)) continue;
            double sample = marker["skill_time"].AsDouble();
            var hit = context.Duplicate(true); hit["sample_time"] = sample;
            if (!cast.Call("register_hit", 1, target.Get("entity_id"), hit).AsBool()) continue;
            hit["attack_facing"] = facing;
            // Damage/stun keep their half-second cadence. Attraction below is
            // independent, so a hit cannot add a lingering knockback impulse.
            hit["knockback_speed"] = 0.0;
            hit["knockback_distance"] = 0.0;
            hit["knockback_duration"] = 0.0;
            _actor.Call("resolve_attack_hit", target, hit);
        }
    }

    private Rect2 TornadoRect(GodotObject cast, Resource segment)
    {
        var source = segment.Get("hit_rect").AsRect2();
        var rect = new Rect2(source.Position * 3, source.Size * 3);
        if (cast.Get("facing").AsInt32() < 0) rect.Position = new Vector2(-rect.End.X, rect.Position.Y);
        return _actor.GlobalTransform * rect;
    }

    private static bool InTornado(Node2D target, Rect2 rect)
    {
        var points = target.Get("hurtbox").AsGodotObject().Call("get_polygon_global").AsVector2Array();
        if (points.Length == 0) return false;
        var bounds = new Rect2(points[0], Vector2.Zero);
        foreach (var point in points) bounds = bounds.Expand(point);
        return rect.Intersects(bounds);
    }

    public void advance_combat(double delta)
    {
        if (delta <= 0 || attraction_distance <= 0 || attraction_duration <= 0 || !_actor.Call("is_alive").AsBool()) return;
        var session = _actor.Get("session").As<Node>();
        if (session == null || session.Call("is_simulation_blocked").AsBool()) return;
        var cast = _actor.Get("attack_instance").AsGodotObject();
        if (cast == null || !cast.Get("active").AsBool() || cast.Get("ability_id").AsStringName() != "mihouwang_skill3") return;
        var timeline = cast.Get("timeline").As<Resource>();
        var segment = timeline.GetMeta("projectile_segment").As<Resource>();
        double fps = timeline.Get("source_fps").AsDouble(), elapsed = cast.Get("elapsed").AsDouble();
        double actionDelta = _actor.Call("get_action_delta", cast.Get("ability_id"), delta).AsDouble();
        // Only the portion inside the authored [start_frame, end_frame) window.
        double used = Math.Min(elapsed, segment.Get("end_frame").AsDouble() / fps)
            - Math.Max(elapsed - actionDelta, segment.Get("start_frame").AsDouble() / fps);
        if (used <= 0) return;
        var rect = TornadoRect(cast, segment);
        foreach (var value in session.Call("get_entities").AsGodotArray())
        {
            var target = value.As<Node2D>();
            if (target == _actor || target.IsQueuedForDeletion() || !target.Call("is_alive").AsBool() || target.Call("is_spawning").AsBool()) continue;
            if (!session.Get("factions").AsGodotObject().Call("is_hostile", _actor.Get("faction_id"), target.Get("faction_id")).AsBool()
                || !InTornado(target, rect)) continue;
            var reactions = target.Get("reactions").AsGodotObject();
            var policy = reactions.Call("get_policy", target).AsGodotDictionary();
            var profile = target.Get("reaction_profile").As<BattleHitReactionProfile>();
            if (!policy["displacement"].AsBool()
                || reactions.Call("is_armored", target).AsBool() && profile.armor_blocks_displacement && profile.armor_blocks_kinds.Contains(NormalHit)) continue;
            double distance = rect.GetCenter().X - target.GlobalPosition.X;
            double step = attraction_distance / attraction_duration * used * (1 - profile.knockback_resistance);
            float x = (float)(Math.Sign(distance) * Math.Min(Math.Abs(distance), step));
            // A swept displacement respects walls, ground slopes and one-way
            // platforms. It leaves no force to continue after exiting the area.
            target.Get("motion").As<BattleMotionController2D>().sweep_skill_displacement(new Vector2(x, 0), target.Get("action_profile").As<Resource>());
        }
    }

    public override void _ExitTree()
    {
        EndGuard();
        if (IsInstanceValid(_bus) && _bus.IsConnected("event_pushed", _callback)) _bus.Disconnect("event_pushed", _callback);
        if (IsInstanceValid(_animation) && _animation.IsConnected("action_started", _animationCallback)) _animation.Disconnect("action_started", _animationCallback);
    }
}
