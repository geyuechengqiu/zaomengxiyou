using Godot;
using Godot.Collections;
using System;

/// <summary>Original hit1 AI. Resources stay immutable; clocks belong to each controller.</summary>
[GlobalClass]
public partial class ZaomengOneAIPolicy : Resource
{
    [Export] public bool passive_until_hit { get; set; }
    [Export] public double attack_period { get; set; } = 36.0 / 30.0;
    [Export] public double attack_chance { get; set; } = 0.5;
    public bool allow_attack(Node controller)
    {
        var actor = controller.Get("actor").AsGodotObject();
        var session = actor.Get("session").AsGodotObject();
        double now = session.Get("clock").AsGodotObject().Get("elapsed").AsDouble();
        double epoch = controller.GetMeta("zaomeng1_ai_epoch", now).AsDouble();
        if (!controller.HasMeta("zaomeng1_ai_epoch")) controller.SetMeta("zaomeng1_ai_epoch", epoch);
        int slot = (int)Math.Floor((now - epoch + 0.000001) / attack_period);
        int previous = controller.GetMeta("zaomeng1_ai_attempt", 0).AsInt32();
        if (slot <= previous) return false;
        controller.SetMeta("zaomeng1_ai_attempt", slot);
        return session.Get("random").AsGodotObject().Call("random_float", new StringName("ai")).AsDouble() < attack_chance;
    }
    public Dictionary decide(Node controller)
    {
        var actor = controller.Get("actor").As<Node2D>();
        var cfg = controller.Get("profile").AsGodotObject();
        var home = controller.Get("home").AsVector2();
        double delta = home.X - actor.GlobalPosition.X;
        if (controller.Get("returning").AsBool() || Math.Abs(delta) > cfg.Get("leash_radius").AsDouble())
        {
            bool returning = Math.Abs(delta) > cfg.Get("home_tolerance").AsDouble();
            controller.Set("returning", returning);
            controller.Set("target", default(Variant));
            return new() { ["state"] = "RETURN", ["axis"] = returning ? Math.Sign(delta) : 0 };
        }
        if (passive_until_hit)
        {
            if (!actor.GetMeta("zaomeng1_alerted", false).AsBool()) controller.Set("target", default(Variant));
            else
            {
                var source = actor.Get("session").AsGodotObject().Call("get_entity", actor.GetMeta("zaomeng1_aggressor", new StringName(""))).As<Node2D>();
                if (GodotObject.IsInstanceValid(source) && source!.Call("is_alive").AsBool()) controller.Set("target", source);
            }
        }
        var target = controller.Get("target").As<Node2D>();
        if (!GodotObject.IsInstanceValid(target))
        {
            int direction = controller.Get("patrol_direction").AsInt32();
            float goal = home.X + cfg.Get("patrol_radius").AsSingle() * direction;
            if (Math.Abs(goal - actor.GlobalPosition.X) <= cfg.Get("home_tolerance").AsDouble() || actor.Get("motion").AsGodotObject().Get("on_wall").AsBool())
                controller.Set("patrol_direction", -direction);
            return new() { ["state"] = "PATROL", ["axis"] = direction };
        }
        var offset = target.GlobalPosition - actor.GlobalPosition;
        double range = cfg.Get("attack_range").AsDouble();
        // A smaller modern hurtbox must not make the original AI stop outside hit1.
        if (!controller.HasMeta("zaomeng1_hit_reach"))
        {
            var ability = actor.Get("abilities").AsGodotObject().Call("get_ability_instance", cfg.Get("attack_skill_id")).AsGodotObject();
            var timeline = ability.Call("get_feature", "BattleFrameTimelineFeature").AsGodotObject();
            float reach = 0;
            foreach (var value in timeline.Get("attack_segments").AsGodotArray())
            {
                var segment = value.AsGodotObject();
                reach = Math.Max(reach, segment.Get("hit_rect").AsRect2().End.X);
                foreach (var rect in segment.Get("hit_rect_frames").AsGodotDictionary().Values) reach = Math.Max(reach, rect.AsRect2().End.X);
            }
            controller.SetMeta("zaomeng1_hit_reach", reach * actor.Get("attack_hitbox").AsGodotObject().Get("source_unit_scale").AsDouble());
        }
        float halfTarget = 0;
        foreach (var point in target.Get("hurtbox").AsGodotObject().Call("get_polygon_global").AsVector2Array())
            halfTarget = Math.Max(halfTarget, Math.Abs(point.X - target.GlobalPosition.X));
        range = Math.Min(range, Math.Max(24, controller.GetMeta("zaomeng1_hit_reach").AsDouble() + halfTarget - 12));
        if (Math.Abs(offset.Y) > range * 2) return new() { ["state"] = "PATROL", ["axis"] = controller.Get("patrol_direction") };
        if (Math.Abs(offset.X) > range) return new() { ["state"] = "CHASE", ["axis"] = Math.Sign(offset.X) };
        bool cast = allow_attack(controller) && controller.Call("skill_ready").AsBool();
        return new() { ["state"] = cast ? "ATTACK" : "COOLDOWN", ["axis"] = 0, ["facing"] = Math.Sign(offset.X), ["skill"] = cast ? cfg.Get("attack_skill_id") : new StringName("") };
    }
}
