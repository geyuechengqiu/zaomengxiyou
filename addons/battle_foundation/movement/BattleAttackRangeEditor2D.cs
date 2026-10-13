using Godot;

/// <summary>Filters the editable skill rectangles while the native animation is previewed.</summary>
[Tool, GlobalClass]
public partial class BattleAttackRangeEditor2D : Node2D
{
    [Export] public StringName preview_action { get; set; } = "attack1";
    [Export] public double preview_time { get; set; }
    [Export] public bool show_all_ranges { get; set; }
    [Export] public bool show_only_hit_frames { get; set; }

    public override void _Ready()
    {
        SetProcess(Engine.IsEditorHint());
        if (Engine.IsEditorHint()) return;
        Visible = false;
        var actor = GetParent().GetParent();
        // A standalone visual preview has no battle owner.
        if (actor == null || !actor.HasMethod("initialize_battle")) return;
        if (!apply_to_actor(actor)) GD.PushError("AttackRanges: one or more authored rectangles could not bind to the actor's skills.");
    }

    public bool apply_to_actor(Node actor)
    {
        var profile = GetParent().Get("profile").As<Resource>();
        float scale = profile.Get("display_scale").AsSingle();
        bool result = true;
        foreach (var child in GetChildren())
            if (child is BattleEditableAttackRange2D range)
                result &= range.apply_to_actor(actor, scale);
        return result;
    }

    public override void _Process(double delta)
    {
        if (!Engine.IsEditorHint()) return;
        foreach (var child in GetChildren())
        {
            if (child is not BattleEditableAttackRange2D range) continue;
            bool visible = show_all_ranges || range.animation_action == preview_action;
            if (visible && show_only_hit_frames && !show_all_ranges && range.skill_definition != null)
            {
                visible = false;
                foreach (var value in range.skill_definition.Get("features").AsGodotArray())
                {
                    var feature = value.As<Resource>();
                    if (!feature.HasMethod("uses_cast_timeline")) continue;
                    double frame = preview_time * feature.Get("source_fps").AsDouble();
                    if (feature.HasMeta("projectile_segment"))
                    {
                        var projectile = feature.GetMeta("projectile_segment").As<Resource>();
                        visible |= projectile.Get("hit_index").AsInt32() == range.hit_index &&
                            frame >= projectile.Get("start_frame").AsInt32() && frame < projectile.Get("end_frame").AsInt32();
                    }
                    foreach (var segmentValue in feature.Get("attack_segments").AsGodotArray())
                    {
                        var segment = segmentValue.As<Resource>();
                        visible |= segment.Get("hit_index").AsInt32() == range.hit_index &&
                            frame >= segment.Get("start_frame").AsInt32() && frame < segment.Get("end_frame").AsInt32();
                    }
                }
            }
            range.Visible = visible;
            if (visible) range.QueueRedraw();
        }
    }
}
