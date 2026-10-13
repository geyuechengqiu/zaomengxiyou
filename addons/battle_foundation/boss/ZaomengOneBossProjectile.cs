using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using Array = Godot.Collections.Array;

/// <summary>Original Boss2Bullet1: authored source frames, upright horizontal mirroring,
/// hit-ID reset at frame 39, and lifetime independent of the casting animation.</summary>
public partial class ZaomengOneBossProjectile : Node2D
{
    [Export] public Array<Texture2D> frames { get; set; } = new();
    [Export] public Array<Rect2> frame_rects { get; set; } = new();
    private Node2D _actor = null!;
    private Node _session = null!, _bus = null!;
    private Sprite2D _sprite = null!;
    private Callable _callback;
    private double _started;
    private int _lastFrame = -1, _facing;
    private StringName _attackId = "";
    private readonly HashSet<ulong> _hits = new();
    public bool active { get; private set; }
    public int spawn_count { get; private set; }

    public override void _Ready()
    {
        _actor = GetParent<Node2D>(); _sprite = GetNode<Sprite2D>("Sprite2D");
        TopLevel = true; Visible = false;
        _bus = GetNode("/root/CoreSystem").Get("event_bus").As<Node>();
        _callback = Callable.From<string, Array>(OnEvent);
        _bus.Connect("event_pushed", _callback);
    }

    private void OnEvent(string id, Array args)
    {
        if (id != "battle.zaomeng1.projectile" || args.Count != 1) return;
        var data = args[0].AsGodotDictionary();
        if (data.GetValueOrDefault("source_entity_id").AsStringName() != _actor.Get("entity_id").AsStringName()) return;
        _session = _actor.Get("session").As<Node>();
        if (data.GetValueOrDefault("battle_id").AsStringName() != _session.Get("battle_id").AsStringName()) return;
        var cast = _actor.Get("attack_instance").AsGodotObject();
        _attackId = cast.Get("attack_id").AsStringName(); _facing = cast.Get("facing").AsInt32();
        GlobalPosition = _actor.GlobalPosition; Scale = new Vector2(2 * _facing, 2);
        _started = _session.Get("clock").AsGodotObject().Get("elapsed").AsDouble();
        _lastFrame = -1; _hits.Clear(); active = Visible = true; ++spawn_count;
        SampleFrame(0);
    }

    public override void _Process(double delta)
    {
        if (!active) return;
        if (!_actor.Call("is_alive").AsBool() || _session.Call("is_simulation_blocked").AsBool())
        {
            if (!_actor.Call("is_alive").AsBool()) active = Visible = false;
            return;
        }
        double age = _session.Get("clock").AsGodotObject().Get("elapsed").AsDouble() - _started;
        int current = Math.Min(frames.Count - 1, (int)Math.Floor(age * 30 + 0.000001));
        for (int i = _lastFrame + 1; i <= current; ++i) SampleFrame(i);
        if (age + 0.000001 >= frames.Count / 30.0) active = Visible = false;
    }

    private void SampleFrame(int index)
    {
        if (index >= frames.Count || index >= frame_rects.Count) return;
        _lastFrame = index;
        if (index == 38) _hits.Clear(); // Original newAttackId() on frame39.
        _sprite.Texture = frames[index]; _sprite.Position = frame_rects[index].Position;
        Rect2 bounds = GlobalTransform * frame_rects[index];
        foreach (var value in _session.Call("get_entities").AsGodotArray())
        {
            var target = value.As<Node2D>();
            if (target == _actor || !target.Call("is_alive").AsBool() || _hits.Contains(target.GetInstanceId())) continue;
            if (!_session.Get("factions").AsGodotObject().Call("is_hostile", _actor.Get("faction_id"), target.Get("faction_id")).AsBool()) continue;
            var points = target.Get("hurtbox").AsGodotObject().Call("get_polygon_global").AsVector2Array();
            if (points.Length == 0) continue;
            Rect2 targetBounds = new(points[0], Vector2.Zero);
            foreach (var p in points) targetBounds = targetBounds.Expand(p);
            if (!bounds.Intersects(targetBounds)) continue;
            _hits.Add(target.GetInstanceId());
            _actor.Call("resolve_attack_hit", target, new Dictionary
            {
                ["ability_id"] = "zaomeng1_mihou_king_hit3", ["attack_id"] = _attackId,
                ["segment_id"] = index < 38 ? "projectile_out" : "projectile_return",
                ["hit_index"] = index < 38 ? 1 : 2, ["attack_facing"] = _facing,
                ["damage_multiplier"] = 20.0 / 30, ["knockback_speed"] = 900.0,
                ["knockback_duration"] = 0.5, ["launch_speed"] = 0.0,
                ["reset_vertical_velocity"] = true, ["reaction_gravity"] = 2700.0,
                ["reaction_type"] = "knockback", ["hit_stun"] = 0.5,
                ["damage_kind"] = "magic", ["maximum_hits"] = 1,
                ["protection_parameters"] = new Dictionary { ["protectPoint"] = 3334, ["protectPointB"] = 3334, ["isProtectPointAdd"] = 1 }
            });
        }
    }

    public override void _ExitTree()
    {
        if (IsInstanceValid(_bus) && _bus.IsConnected("event_pushed", _callback)) _bus.Disconnect("event_pushed", _callback);
    }
}
