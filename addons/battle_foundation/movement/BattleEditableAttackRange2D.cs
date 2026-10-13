using Godot;

/// <summary>Scene-authored world-space rectangle; never a second physics damage area.</summary>
[Tool, GlobalClass]
public partial class BattleEditableAttackRange2D : Area2D
{
    [Export] public StringName ability_id { get; set; } = "";
    [Export] public StringName animation_action { get; set; } = "";
    [Export] public int hit_index { get; set; } = 1;
    // Inspect this resource to edit hit frames, multiplier, knockback and hit count.
    [Export] public Resource? skill_definition { get; set; }

    public Rect2 get_authored_rect()
        => RectForTransform(Transform);

    private Rect2 RectForTransform(Transform2D transform)
    {
        var collision = GetNode<CollisionShape2D>("CollisionShape2D");
        if (collision.Shape is not RectangleShape2D rectangle) return default;
        // All editor handles (node position, scale and shape size) participate.
        return (transform * collision.Transform) * new Rect2(-rectangle.Size / 2, rectangle.Size);
    }

    public bool apply_to_actor(Node actor, float sourceScale)
    {
        if (sourceScale <= 0 || !float.IsFinite(sourceScale)) return false;
        var abilities = actor.Get("abilities").AsGodotObject();
        if (abilities == null || !abilities.Call("has_ability", ability_id).AsBool()) return false;
        var instance = abilities.Call("get_ability_instance", ability_id).AsGodotObject();
        // Catalog supplies an isolated deep copy for every actor. Do not mutate
        // skill_definition (editor asset) or replace a running GAS feature.
        var definition = instance.Call("get_definition").As<Resource>();
        // Include transforms of AttackRanges and AnimationAdapter, so moving
        // their scene origins cannot leave damage geometry at an old position.
        var authored = actor is Node2D owner
            ? RectForTransform(owner.GlobalTransform.AffineInverse() * GlobalTransform)
            : get_authored_rect();
        if (!authored.Position.IsFinite() || !authored.Size.IsFinite() || authored.Size.X <= 0 || authored.Size.Y <= 0) return false;
        foreach (var value in definition.Get("features").AsGodotArray())
        {
            var feature = value.As<Resource>();
            if (!feature.HasMethod("uses_cast_timeline")) continue;
            // Detached projectiles keep damage configuration outside melee
            // timeline segments, while using the same scene-authored handle.
            if (feature.HasMeta("projectile_segment"))
            {
                var segment = feature.GetMeta("projectile_segment").As<Resource>();
                if (segment.Get("hit_index").AsInt32() != hit_index) continue;
                segment.Set("hit_rect", new Rect2(authored.Position / sourceScale, authored.Size / sourceScale));
                return true;
            }
            foreach (var segmentValue in feature.Get("attack_segments").AsGodotArray())
            {
                var segment = segmentValue.As<Resource>();
                if (segment.Get("hit_index").AsInt32() != hit_index) continue;
                segment.Set("hit_rect", new Rect2(authored.Position / sourceScale, authored.Size / sourceScale));
                segment.Get("hit_rect_frames").AsGodotDictionary().Clear();
                segment.Set("spawn_offset", Vector2.Zero);
                return true;
            }
        }
        return false;
    }

    public override void _Draw()
    {
        if (!Engine.IsEditorHint()) return;
        var rect = Transform.AffineInverse() * get_authored_rect();
        DrawRect(rect, new Color(1, 0.3f, 0.15f, 0.12f));
        DrawRect(rect, new Color(1, 0.55f, 0.1f, 0.9f), false, 2);
        DrawString(ThemeDB.FallbackFont, rect.Position + new Vector2(4, -6), animation_action.ToString(), fontSize: 18, modulate: Colors.Orange);
    }
}
