using Godot;
using Godot.Collections;
using Array = Godot.Collections.Array;

/// <summary>Monster4's setYourFather(76), limited to its hit2 cast.</summary>
public partial class ZaomengOneBossGuard : Node
{
    private Node _actor = null!, _tags = null!, _bus = null!;
    private Callable _callback;
    private bool _guarded;
    public override void _Ready()
    {
        _actor = GetParent(); _tags = GetNode("/root/TagManager");
        _bus = GetNode("/root/CoreSystem").Get("event_bus").As<Node>();
        _callback = Callable.From<string, Array>(OnEvent); _bus.Connect("event_pushed", _callback);
    }
    private void OnEvent(string id, Array args)
    {
        if (args.Count != 1 || args[0].VariantType != Variant.Type.Dictionary) return;
        var data = args[0].AsGodotDictionary();
        if (data.GetValueOrDefault("source_entity_id").AsStringName() != _actor.Get("entity_id").AsStringName()) return;
        if (data.GetValueOrDefault("battle_id").AsStringName() != _actor.Get("session").AsGodotObject().Get("battle_id").AsStringName()) return;
        if (id == "battle.boss.action_started" && data.GetValueOrDefault("ability_id").AsString() == "zaomeng1_mihou_king_hit2") SetGuard(true);
    }
    public override void _Process(double delta)
    {
        if (!_guarded) return;
        var cast = _actor.Get("attack_instance").AsGodotObject();
        if (!_actor.Call("is_alive").AsBool() || !IsInstanceValid(cast) || !cast.Get("active").AsBool() || cast.Get("ability_id").AsString() != "zaomeng1_mihou_king_hit2") SetGuard(false);
    }
    private void SetGuard(bool enabled)
    {
        if (_guarded == enabled) return;
        _guarded = enabled; _tags.Call(enabled ? "add_tag" : "remove_tag", _actor, new StringName("state.invulnerable"));
    }
    public override void _ExitTree()
    {
        if (_guarded && IsInstanceValid(_tags) && IsInstanceValid(_actor)) SetGuard(false);
        if (IsInstanceValid(_bus) && _bus.IsConnected("event_pushed", _callback)) _bus.Disconnect("event_pushed", _callback);
    }
}
