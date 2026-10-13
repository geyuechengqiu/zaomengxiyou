using Godot;
using System;

[GlobalClass]
public partial class ZaomengOneBossPolicy : Resource
{
    // Monster4: distant projectile immediately when ready; close attacks every
    // 24 source frames. Mutable timing lives on this particular controller.
    public bool allow_attack(Node controller)
    {
        var actor = controller.Get("actor").As<Node2D>();
        var target = controller.Get("target").As<Node2D>();
        if (!GodotObject.IsInstanceValid(target)) return false;
        if (Math.Abs(target.Position.X - actor.Position.X) > 300) return true;
        double now = controller.Get("elapsed").AsDouble();
        double due = controller.GetMeta("zaomeng1_close_attack_due", 0.0).AsDouble();
        if (now + 0.000001 < due) return false;
        controller.SetMeta("zaomeng1_close_attack_due", now + 24.0 / 30.0);
        return true;
    }
}
