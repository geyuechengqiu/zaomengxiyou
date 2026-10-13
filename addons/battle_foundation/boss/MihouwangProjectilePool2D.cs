using Godot;
using Godot.Collections;
using System.Collections.Generic;
using Array = Godot.Collections.Array;

/// <summary>One source-frame launch, one random choice, fixed scene-authored slots.</summary>
[GlobalClass]
public partial class MihouwangProjectilePool2D : Node2D
{
    [Export(PropertyHint.Range, "0,1,0.01")] public double skill1_native_probability { get; set; } = .5;
    private Node2D _actor = null!;
    private Node _bus = null!, _session = null!;
    private Callable _callback;
    private readonly List<MihouwangProjectile2D> _slots = new();
    private StringName _launchedAttack = "";
    public int spawn_count { get; private set; }
    public int native_skill1_count { get; private set; }
    public int original_skill1_count { get; private set; }
    public string last_variant { get; private set; } = "";

    public override void _Ready()
    {
        _actor = GetParent<Node2D>();
        foreach (var child in GetChildren()) if (child is MihouwangProjectile2D slot) _slots.Add(slot);
        _bus = GetNode("/root/CoreSystem").Get("event_bus").As<Node>();
        _callback = Callable.From<string, Array>(OnEvent);
        _bus.Connect("event_pushed", _callback);
        ProcessPriority = 100;
    }

    private void OnEvent(string id, Array args)
    {
        if (args.Count != 1 || (id != "battle.mihouwang.projectile" && id != "battle.entity_died" && id != "battle.attack.finished")) return;
        var data = args[0].AsGodotDictionary();
        if (data.GetValueOrDefault("source_entity_id").AsStringName() != _actor.Get("entity_id").AsStringName()) return;
        _session = _actor.Get("session").As<Node>();
        if (data.GetValueOrDefault("battle_id").AsStringName() != _session.Get("battle_id").AsStringName()) return;
        if (id == "battle.entity_died" || (id == "battle.attack.finished" && data.GetValueOrDefault("reason").AsString() == "despawned")) { clear_projectiles(); return; }
        if (id != "battle.mihouwang.projectile" || !_actor.Call("is_alive").AsBool()) return;
        var cast = _actor.Get("attack_instance").AsGodotObject();
        var attackId = data.GetValueOrDefault("attack_id").AsStringName();
        if (cast == null || !cast.Get("active").AsBool() || cast.Get("attack_id").AsStringName() != attackId || _launchedAttack == attackId) return;
        string action = data.GetValueOrDefault("projectile_action").AsString();
        if (action != "skill1" && action != "runattack") return;
        MihouwangProjectile2D? free = _slots.Find(slot => !slot.active);
        if (free == null) return; // Fixed pool never overwrites a live projectile.
        var timeline = cast.Get("timeline").As<Resource>();
        var segment = timeline.GetMeta("projectile_segment").As<Resource>();
        var context = segment.Call("get_payload").AsGodotDictionary().Duplicate(true);
        context.Merge(data, true);
        context["attack_facing"] = cast.Get("facing");
        context["defer_attack_feedback"] = true;
        bool original = action == "skill1" && _session.Get("random").AsGodotObject().Call("random_float", new StringName("mihouwang_projectile")).AsDouble() >= skill1_native_probability;
        _launchedAttack = attackId;
        last_variant = original ? "zaomeng1" : action;
        ++spawn_count;
        if (action == "skill1") { if (original) ++original_skill1_count; else ++native_skill1_count; }
        free.launch(_actor, _session, cast, context, last_variant, segment.Get("hit_rect").AsRect2());
    }

    public override void _Process(double delta)
    {
        if (_session == null) return;
        if (!IsInstanceValid(_actor) || !_actor.Call("is_alive").AsBool()) { clear_projectiles(); return; }
        if (_session.Call("is_simulation_blocked").AsBool()) return;
        double now = _session.Get("clock").AsGodotObject().Get("elapsed").AsDouble();
        foreach (var slot in _slots) if (slot.active) slot.advance_to(now);
    }

    public void clear_projectiles() { foreach (var slot in _slots) slot.release(); }

    public override void _ExitTree()
    {
        clear_projectiles();
        if (IsInstanceValid(_bus) && _bus.IsConnected("event_pushed", _callback)) _bus.Disconnect("event_pushed", _callback);
    }
}
