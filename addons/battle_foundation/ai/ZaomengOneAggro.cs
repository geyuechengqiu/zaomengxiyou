using Godot;

/// <summary>Authored on passive monsters; real health loss latches their attacker.</summary>
public partial class ZaomengOneAggro : Node
{
    private GodotObject? _health;
    private Callable _damage;
    public override void _Ready()
    {
        _health = GetParent().Get("attributes").AsGodotObject().Call("get_vital", new StringName("health")).AsGodotObject();
        _damage = Callable.From<GodotObject, double>(OnDamage);
        _health.Connect("damage_applied", _damage);
    }
    private void OnDamage(GodotObject info, double loss)
    {
        var actor = GetParent();
        var source = info.Get("instigator").As<Node>();
        if (loss <= 0 || !IsInstanceValid(source) || !source.HasMethod("is_alive")) return;
        var session = actor.Get("session").AsGodotObject();
        if (!session.Get("factions").AsGodotObject().Call("is_hostile", actor.Get("faction_id"), source.Get("faction_id")).AsBool()) return;
        actor.SetMeta("zaomeng1_alerted", true);
        actor.SetMeta("zaomeng1_aggressor", source.Get("entity_id"));
        var controller = actor.Get("ai_controller").AsGodotObject();
        controller.Set("target", source);
        controller.Set("returning", false);
        controller.Set("decision_remaining", 0.0);
    }
    public override void _ExitTree()
    {
        if (IsInstanceValid(_health) && _health!.IsConnected("damage_applied", _damage)) _health.Disconnect("damage_applied", _damage);
        _health = null;
    }
}
