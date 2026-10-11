using Godot;
using System;

/// <summary>Floor tangents affect displacement, never ballistic Y velocity.</summary>
[GlobalClass]
public partial class BattleMotionController2D : Node
{
    public CharacterBody2D body { get; set; } = null!;
    public bool grounded { get; set; }
    public bool on_wall { get; set; }
    public bool on_ceiling { get; set; }
    public bool just_landed { get; set; }
    public int jumps_used { get; set; }
    public int jump_count { get; set; }
    public int landing_serial { get; set; }
    public int jump_serial { get; set; }
    public double impulse_speed { get; set; }
    public double impulse_remaining { get; set; }
    public double reaction_gravity { get; set; } = -1;
    public bool horizontal_bounds_active { get; set; }
    public Vector2 horizontal_bounds { get; set; }
    [Export] public NodePath body_shape_path { get; set; } = "../CollisionShape2D";
    [Export(PropertyHint.Range, "0.1,2,0.05")] public double movement_speed_scale { get; set; } = 1;
    private readonly System.Collections.Generic.List<(PhysicsBody2D Platform, Rect2 Rect)> _dropped = new();
    public int dropped_platform_count => _dropped.Count;

    private static CollisionShape2D? OneWayShape(PhysicsBody2D platform)
    {
        CollisionShape2D? support = null;
        foreach (uint owner in platform.GetShapeOwners())
        {
            if (platform.IsShapeOwnerDisabled(owner)) continue;
            if (platform.ShapeOwnerGetOwner(owner) is not CollisionShape2D shape || !shape.OneWayCollision) return null;
            support = shape;
        }
        return support;
    }
    public bool try_drop_through(Resource profile)
    {
        var action = body.Get("action_state").AsGodotObject();
        if (!grounded || !body.Call("is_alive").AsBool() || body.Call("is_spawning").AsBool()
            || body.Get("session").AsGodotObject().Call("is_simulation_blocked").AsBool()
            || !action.Call("can_jump", true, profile).AsBool()) return false;
        var collision = body.MoveAndCollide(Vector2.Down * Math.Max(6, profile.Get("floor_snap_distance").AsSingle()), true);
        if (collision?.GetCollider() is not PhysicsBody2D platform || OneWayShape(platform) is not CollisionShape2D support) return false;
        var ownShape = GetNode<CollisionShape2D>(body_shape_path);
        using var query = new PhysicsShapeQueryParameters2D
        {
            Shape = ownShape.Shape,
            Transform = ownShape.GlobalTransform.Translated(Vector2.Down * 6),
            CollisionMask = body.CollisionMask,
            Exclude = new Godot.Collections.Array<Rid> { body.GetRid() }
        };
        float feet = (ownShape.GlobalTransform * ownShape.Shape.GetRect()).End.Y;
        Ignore(platform, support);
        // Ignore only coplanar supports at the seam, retaining platforms underneath.
        foreach (var row in body.GetWorld2D().DirectSpaceState.IntersectShape(query))
        {
            if (row["collider"].AsGodotObject() is not PhysicsBody2D neighbour || OneWayShape(neighbour) is not CollisionShape2D shape) continue;
            if (Math.Abs((shape.GlobalTransform * shape.Shape.GetRect()).Position.Y - feet) <= 12) Ignore(neighbour, shape);
        }
        grounded = just_landed = false;
        body.Velocity = new(body.Velocity.X, Math.Max(100, body.Velocity.Y));
        body.Call("_cancel_abilities");
        action.Set("grounded", false);
        action.Call("enter", 2); // Ordinary falling state; no extra jump consumed.
        body.Call("publish_battle_event", new StringName("battle.motion.drop_through"), new Godot.Collections.Dictionary { ["support_count"] = _dropped.Count });
        return true;
    }
    private void Ignore(PhysicsBody2D platform, CollisionShape2D shape)
    {
        foreach (var row in _dropped) if (row.Platform == platform) return;
        body.AddCollisionExceptionWith(platform);
        _dropped.Add((platform, shape.GlobalTransform * shape.Shape.GetRect()));
    }
    private void RestoreSupports()
    {
        if (_dropped.Count == 0) return;
        var shape = GetNode<CollisionShape2D>(body_shape_path);
        var rect = shape.GlobalTransform * shape.Shape.GetRect();
        for (int i = _dropped.Count - 1; i >= 0; --i)
        {
            var row = _dropped[i];
            if (!IsInstanceValid(row.Platform)) { _dropped.RemoveAt(i); continue; }
            if (rect.Position.Y > row.Rect.End.Y + 2 || rect.End.Y < row.Rect.Position.Y - 2)
            {
                body.RemoveCollisionExceptionWith(row.Platform);
                _dropped.RemoveAt(i);
            }
        }
    }
    public override void _ExitTree()
    {
        if (IsInstanceValid(body)) foreach (var row in _dropped)
            if (IsInstanceValid(row.Platform)) body.RemoveCollisionExceptionWith(row.Platform);
        _dropped.Clear();
    }

    public void set_horizontal_bounds(double left, double right)
    {
        var shape = GetNodeOrNull<CollisionShape2D>(body_shape_path);
        if (shape?.Shape != null && !shape.Disabled)
        {
            var rect = shape.GlobalTransform * shape.Shape.GetRect();
            left -= rect.Position.X - body.GlobalPosition.X;
            right -= rect.End.X - body.GlobalPosition.X;
        }
        if (left > right) left = right = (left + right) * 0.5;
        horizontal_bounds = new((float)left, (float)right);
        horizontal_bounds_active = true;
        constrain_horizontal_position();
    }
    public void clear_horizontal_bounds() => horizontal_bounds_active = false;
    public void constrain_horizontal_position()
    {
        if (!horizontal_bounds_active) return;
        var position = body.GlobalPosition;
        position.X = Mathf.Clamp(position.X, horizontal_bounds.X, horizontal_bounds.Y);
        if (position != body.GlobalPosition) body.GlobalPosition = position;
        bool left = position.X <= horizontal_bounds.X, right = position.X >= horizontal_bounds.Y;
        if ((left && body.Velocity.X < 0) || (right && body.Velocity.X > 0)) body.Velocity = new(0, body.Velocity.Y);
        if ((left && impulse_speed < 0) || (right && impulse_speed > 0)) impulse_speed = impulse_remaining = 0;
    }
    private Vector2 Limit(Vector2 displacement)
    {
        if (!horizontal_bounds_active) return displacement;
        constrain_horizontal_position();
        float x = Mathf.Clamp(body.GlobalPosition.X + displacement.X, horizontal_bounds.X, horizontal_bounds.Y) - body.GlobalPosition.X;
        if (!Mathf.IsEqualApprox(x, displacement.X))
        {
            on_wall = true;
            if (body.Velocity.X * displacement.X > 0) body.Velocity = new(0, body.Velocity.Y);
            if (impulse_speed * displacement.X > 0) impulse_speed = impulse_remaining = 0;
        }
        return new(x, displacement.Y);
    }
    public bool can_jump(int maximum_jumps) => maximum_jumps > 0 && (grounded || jumps_used < maximum_jumps);
    public bool jump(Resource profile)
    {
        if (!can_jump(profile.Get("maximum_jumps").AsInt32())) return false;
        jumps_used = grounded ? 1 : jumps_used + 1;
        jump_count = jumps_used;
        ++jump_serial;
        grounded = just_landed = false;
        body.Velocity = new(body.Velocity.X, profile.Get(jumps_used == 1 ? "jump_velocity" : "second_jump_velocity").AsSingle());
        return true;
    }
    public void apply_impulse(double horizontal, double duration, double launch, double gravity, bool reset_vertical)
    {
        impulse_speed = horizontal;
        impulse_remaining = duration;
        if (launch > 0 || reset_vertical)
        {
            body.Velocity = new(body.Velocity.X, (float)-launch);
            reaction_gravity = gravity;
        }
        if (launch > 0) { grounded = false; jumps_used = Math.Max(jumps_used, 1); }
    }
    public void clear_impulse() { impulse_speed = impulse_remaining = 0; reaction_gravity = -1; }
    private void Sweep(Vector2 displacement, float floorCos)
    {
        var remaining = displacement;
        for (int i = 0; i < 6; ++i)
        {
            var collision = body.MoveAndCollide(Limit(remaining));
            if (collision == null) break;
            var normal = collision.GetNormal();
            if (normal.Dot(Vector2.Up) >= floorCos)
            {
                grounded = true;
                // Sliding on a slope must not launch the body when its impulse ends.
                body.Velocity = new(body.Velocity.X, 0);
                remaining = collision.GetRemainder().Slide(normal);
            }
            else if (normal.Dot(Vector2.Down) > 0.7f)
            {
                on_ceiling = true;
                body.Velocity = new(body.Velocity.X, Math.Max(0, body.Velocity.Y));
                remaining = new(collision.GetRemainder().X, 0);
            }
            else
            {
                on_wall = true;
                body.Velocity = new(0, body.Velocity.Y);
                remaining = new(0, collision.GetRemainder().Y);
            }
            if (remaining.IsZeroApprox()) break;
        }
    }
    private void Land(bool wasGrounded)
    {
        if (grounded && !wasGrounded) { just_landed = true; ++landing_serial; jumps_used = 0; }
        if (grounded) reaction_gravity = -1;
    }
    public void sweep_skill_displacement(Vector2 displacement, Resource profile)
    {
        if (displacement.IsZeroApprox()) return;
        bool wasGrounded = grounded;
        float floorCos = MathF.Cos(profile.Get("maximum_floor_angle").AsSingle());
        if (displacement.Y < 0) grounded = false;
        Sweep(displacement, floorCos);
        if (grounded)
        {
            var support = body.MoveAndCollide(Vector2.Down * profile.Get("floor_snap_distance").AsSingle(), true);
            if (support == null || support.GetNormal().Dot(Vector2.Up) < floorCos) grounded = false;
        }
        Land(wasGrounded);
    }
    public void advance(double delta, double horizontal_speed, Resource profile, double gravity_scale)
    {
        if (delta <= 0) return;
        horizontal_speed *= movement_speed_scale;
        just_landed = on_wall = on_ceiling = false;
        int count = Math.Max(1, (int)Math.Ceiling(delta * 60));
        double dt = delta / count;
        float floorCos = MathF.Cos(profile.Get("maximum_floor_angle").AsSingle());
        double gravity = profile.Get("gravity").AsDouble();
        float maxFall = profile.Get("maximum_fall_speed").AsSingle();
        float snapDistance = profile.Get("floor_snap_distance").AsSingle();
        for (int tick = 0; tick < count; ++tick)
        {
            RestoreSupports();
            bool wasGrounded = grounded;
            grounded = false;
            double impulseDelta = Math.Min(dt, impulse_remaining);
            float x = (float)(horizontal_speed + impulse_speed * impulseDelta / dt);
            impulse_remaining = Math.Max(0, impulse_remaining - dt);
            double effectiveGravity = reaction_gravity >= 0 ? reaction_gravity : gravity;
            body.Velocity = new(x, Math.Min((float)(body.Velocity.Y + effectiveGravity * gravity_scale * dt), maxFall));
            Sweep(body.Velocity * (float)dt, floorCos);
            if (!grounded && wasGrounded && body.Velocity.Y >= 0)
            {
                var support = body.MoveAndCollide(Vector2.Down * snapDistance, true);
                if (support != null && support.GetNormal().Dot(Vector2.Up) >= floorCos)
                {
                    body.MoveAndCollide(support.GetTravel());
                    grounded = true;
                    body.Velocity = new(body.Velocity.X, 0);
                }
            }
            Land(wasGrounded);
            RestoreSupports();
        }
    }
}
