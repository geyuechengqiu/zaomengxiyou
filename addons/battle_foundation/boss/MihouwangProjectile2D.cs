using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;

/// <summary>Detached Spine projectile or original out-and-return source frames.</summary>
[GlobalClass]
public partial class MihouwangProjectile2D : Node2D
{
    [Export] public Array<Texture2D> frames { get; set; } = new();
    [Export] public Array<Rect2> frame_rects { get; set; } = new();
    [Export] public float skill1_speed { get; set; } = 900;
    [Export] public float runattack_speed { get; set; } = 1100;
    [Export] public Vector2 spawn_offset { get; set; }
    // Original frame geometry is preserved at the default authored range;
    // moving/resizing the shared skill1 handle also adjusts this branch.
    [Export] public Rect2 legacy_range_reference { get; set; } = new(-216, -543, 432, 585);
    private Node2D _actor = null!, _native = null!;
    private Node _session = null!;
    private GodotObject _cast = null!;
    private Sprite2D _legacy = null!;
    private readonly List<Node2D> _sprites = new();
    private readonly System.Collections.Generic.Dictionary<ulong, (int count, double due)> _hits = new();
    private Dictionary _context = new();
    private Vector2 _origin;
    private Vector2 _visualScale;
    private Vector2 _legacyRangeOffset, _legacyRangeScale;
    private Rect2 _geometry;
    private double _started, _life, _age;
    private int _frame = -1, _facing;
    private float _speed;
    public bool active { get; private set; }
    public string variant { get; private set; } = "";
    public double age => _age;

    public override void _Ready()
    {
        TopLevel = true; _native = GetNode<Node2D>("Native"); _legacy = GetNode<Sprite2D>("Sprite2D");
        foreach (var child in _native.GetChildren()) if (child is Node2D sprite && sprite.IsClass("SpineSprite")) _sprites.Add(sprite);
        release();
    }

    public void launch(Node2D actor, Node session, GodotObject cast, Dictionary context, string kind, Rect2 sourceRect)
    {
        release(); _actor = actor; _session = session; _cast = cast; _context = context.Duplicate(true);
        variant = kind; _facing = context["attack_facing"].AsInt32();
        _origin = actor.GlobalPosition + new Vector2(spawn_offset.X * _facing, spawn_offset.Y);
        _visualScale = actor.GlobalScale.Abs();
        GlobalPosition = _origin; Scale = Vector2.One; _native.Scale = new Vector2(3 * _facing, 3) * _visualScale;
        _geometry = new(sourceRect.Position * 3, sourceRect.Size * 3);
        _legacyRangeOffset = _geometry.GetCenter() - legacy_range_reference.GetCenter();
        _legacyRangeOffset.X *= _facing;
        _legacyRangeScale = _geometry.Size / legacy_range_reference.Size;
        _legacyRangeOffset *= _visualScale;
        _geometry = new(_geometry.Position * _visualScale, _geometry.Size * _visualScale);
        if (_facing < 0) _geometry.Position = new(-_geometry.End.X, _geometry.Position.Y);
        _started = session.Get("clock").AsGodotObject().Get("elapsed").AsDouble();
        _speed = kind == "runattack" ? runattack_speed : skill1_speed;
        _life = kind == "zaomeng1" ? frames.Count / 30.0 : 0;
        _legacy.Visible = kind == "zaomeng1"; _native.Visible = !_legacy.Visible;
        foreach (var sprite in _sprites)
        {
            sprite.Visible = kind == sprite.Name.ToString() || (kind == "runattack" && sprite.Name == "runattack1");
            if (!sprite.Visible) continue;
            var data = sprite.Get("skeleton_data_res").AsGodotObject();
            _life = Math.Max(_life, data.Call("find_animation", "build").AsGodotObject().Call("get_duration").AsDouble());
            var skeleton = sprite.Call("get_skeleton").AsGodotObject();
            skeleton.Call("set_to_setup_pose"); skeleton.Call("set_skin", data.Call("find_skin", "default"));
            sprite.Call("get_animation_state").AsGodotObject().Call("set_animation", "build", false, 0);
            sprite.Call("update_skeleton", 0.0);
        }
        active = Visible = true;
        if (kind == "zaomeng1") SampleLegacy(0); else SampleNative(0, false);
    }

    public void advance_to(double now)
    {
        if (!active) return;
        if (!IsInstanceValid(_actor) || !_actor.Call("is_alive").AsBool()) { release(); return; }
        double until = Math.Clamp(now - _started, 0, _life);
        if (until <= _age + 1e-9) return;
        if (variant == "zaomeng1")
        {
            int frame = Math.Min(frames.Count - 1, (int)Math.Floor(until * 30 + 1e-6));
            for (int i = _frame + 1; i <= frame && active; ++i) { _age = i / 30.0; SampleLegacy(i); }
            _age = until;
        }
        else while (active && _age < until - 1e-9)
        {
            _age = Math.Min(until, _age + 1.0 / 60);
            SampleNative(_age, true);
        }
        if (until + 1e-7 >= _life) release();
    }

    private void SampleNative(double time, bool collide)
    {
        Vector2 before = GlobalPosition;
        Vector2 after = _origin + new Vector2((float)(time * _speed) * _facing, 0);
        bool blocked = false;
        if (collide && before != after)
        {
            using var ray = PhysicsRayQueryParameters2D.Create(before + _geometry.GetCenter(), after + _geometry.GetCenter(), 1,
                new Array<Rid> { ((CollisionObject2D)_actor).GetRid() });
            var hit = GetWorld2D().DirectSpaceState.IntersectRay(ray);
            if (hit.Count > 0) { after = hit["position"].AsVector2() - _geometry.GetCenter(); blocked = true; }
        }
        GlobalPosition = after;
        foreach (var sprite in _sprites)
        {
            if (!sprite.Visible) continue;
            var state = sprite.Call("get_animation_state").AsGodotObject();
            var entry = state.Call("get_track", 0).AsGodotObject();
            if (entry != null) entry.Call("set_track_time", time);
            sprite.Call("update_skeleton", 0.0);
        }
        if (collide) SampleTargets(before + _geometry.GetCenter(), after + _geometry.GetCenter(), _geometry.Size, false);
        if (blocked) release();
    }

    private void SampleLegacy(int index)
    {
        var previous = _frame < 0 ? frame_rects[index] : frame_rects[_frame];
        _frame = index;
        if (index == 38) _hits.Clear(); // Original outgoing/returning hit-ID boundary.
        _legacy.Texture = frames[index]; _legacy.Scale = new Vector2(2 * _facing, 2) * _visualScale;
        var rect = frame_rects[index]; _legacy.Position = new Vector2(rect.Position.X * 2 * _facing, rect.Position.Y * 2) * _visualScale;
        var transform = new Transform2D(0, new Vector2(2 * _facing, 2) * _visualScale, 0, _origin);
        var before = transform * previous; var after = transform * rect;
        before = new(before.GetCenter() + _legacyRangeOffset - before.Size * _legacyRangeScale / 2, before.Size * _legacyRangeScale);
        after = new(after.GetCenter() + _legacyRangeOffset - after.Size * _legacyRangeScale / 2, after.Size * _legacyRangeScale);
        SampleTargets(before.GetCenter(), after.GetCenter(), after.Size, true);
    }

    private void SampleTargets(Vector2 from, Vector2 to, Vector2 size, bool legacy)
    {
        foreach (var value in _session.Call("get_entities").AsGodotArray())
        {
            if (!active || !_actor.Call("is_alive").AsBool()) break;
            var target = value.As<Node2D>();
            if (target == _actor || target.IsQueuedForDeletion() || !target.Call("is_alive").AsBool() || target.Call("is_spawning").AsBool()) continue;
            if (!_session.Get("factions").AsGodotObject().Call("is_hostile", _actor.Get("faction_id"), target.Get("faction_id")).AsBool()) continue;
            ulong id = target.GetInstanceId(); _hits.TryGetValue(id, out var record);
            int max = legacy ? 1 : _context.GetValueOrDefault("maximum_hits", 1).AsInt32();
            double interval = legacy ? 0 : _context.GetValueOrDefault("hit_interval", 0.0).AsDouble();
            if (record.count >= max || (record.count > 0 && (interval <= 0 || _age + 1e-7 < record.due))) continue;
            var points = target.Get("hurtbox").AsGodotObject().Call("get_polygon_global").AsVector2Array();
            if (points.Length == 0) continue;
            Rect2 bounds = new(points[0], Vector2.Zero); foreach (var point in points) bounds = bounds.Expand(point);
            if (!Crosses(new(bounds.Position - size / 2, bounds.Size + size), from, to)) continue;
            _hits[id] = (record.count + 1, _age + interval);
            var context = _context.Duplicate(true);
            context["sample_time"] = context["skill_time"].AsDouble() + _age;
            context["target_hit_count"] = record.count + 1;
            if (legacy)
            {
                context["knockback_speed"] = 900.0; context["knockback_duration"] = .5;
                context["hit_stun"] = .5; context["reset_vertical_velocity"] = true;
                context["reaction_gravity"] = 2700.0; context["reaction_type"] = "knockback";
                context["damage_kind"] = "magic"; context["hit_index"] = _frame < 38 ? 1 : 2;
                context["segment_id"] = _frame < 38 ? "projectile_out" : "projectile_return";
                context["protection_parameters"] = new Dictionary { ["protectPoint"] = 3334, ["protectPointB"] = 3334, ["isProtectPointAdd"] = 1 };
            }
            _cast.Set("hit_count", _cast.Get("hit_count").AsInt32() + 1);
            _actor.Call("resolve_attack_hit", target, context);
        }
    }

    private static bool Crosses(Rect2 rect, Vector2 from, Vector2 to)
    {
        float low = 0, high = 1;
        for (int axis = 0; axis < 2; ++axis)
        {
            float diff = to[axis] - from[axis];
            if (Mathf.IsZeroApprox(diff)) { if (from[axis] < rect.Position[axis] || from[axis] > rect.End[axis]) return false; }
            else
            {
                float a = (rect.Position[axis] - from[axis]) / diff, b = (rect.End[axis] - from[axis]) / diff;
                low = Math.Max(low, Math.Min(a, b)); high = Math.Min(high, Math.Max(a, b)); if (low > high) return false;
            }
        }
        return true;
    }

    public void release()
    {
        active = Visible = false; _age = 0; _frame = -1; _hits.Clear(); _context.Clear();
        foreach (var sprite in _sprites) { sprite.Visible = false; sprite.Call("get_animation_state").AsGodotObject().Call("clear_track", 0); }
    }
}
