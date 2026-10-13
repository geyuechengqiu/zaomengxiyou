using Godot;
using System;

/// <summary>Source-frame clocks scale only normal attacks; movement/vitals/cooldowns keep real combat time.</summary>
public partial class BattlePlaybackPolicy : Resource
{
    public static bool NormalAttack(string id) => id.StartsWith("sunwukong_attack", StringComparison.Ordinal)
        || id is "sunwukong_run_attack" or "sunwukong_jump_attack"
        || id.StartsWith("zaomeng1_", StringComparison.Ordinal) && id.EndsWith("_hit1", StringComparison.Ordinal);
    public double attack_rate(Node actor, StringName id)
    {
        if (!NormalAttack(id)) return 1;
        double rate = id.ToString().StartsWith("zaomeng1_", StringComparison.Ordinal) ? .8 :
            actor.Get("attributes").AsGodotObject().Call("get_value", new StringName("attackSpeed")).AsDouble();
        return double.IsFinite(rate) ? Math.Clamp(rate, .05, 10) : 1;
    }
    public double animation_delta(Node actor, double delta)
    {
        var cast = actor.Get("attack_instance").AsGodotObject();
        if (IsInstanceValid(cast) && cast.Get("active").AsBool()) return delta * attack_rate(actor, cast.Get("ability_id").AsStringName());
        var animation = actor.Get("animation").AsGodotObject();
        string action = animation.Call("get_current_action").AsString();
        if (action is not ("move" or "run")) return delta;
        var attrs = actor.Get("attributes").AsGodotObject();
        // Non-player actors retain their authored cadence unless they expose a reference speed.
        if (!attrs.Call("has_attribute", new StringName("baseRunSpeed")).AsBool()) return delta;
        double reference = attrs.Call("get_value", new StringName("baseRunSpeed")).AsDouble();
        double speed = attrs.Call("get_value", new StringName(action == "run" ? "runSpeed" : "walkSpeed")).AsDouble();
        speed *= actor.Get("motion").AsGodotObject().Get("movement_speed_scale").AsDouble();
        speed *= Math.Abs(actor.Get("move_axis").AsDouble());
        return delta * (reference > 0 && double.IsFinite(speed) ? Math.Clamp(Math.Abs(speed) / reference, 0, 10) : 1);
    }
}
