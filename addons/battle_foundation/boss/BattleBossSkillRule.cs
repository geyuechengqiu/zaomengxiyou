using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleBossSkillRule : Resource
{
    [Export] public StringName ability_id { get; set; } = "";
    [Export] public int priority { get; set; } = 0;
    [Export] public double weight { get; set; } = 1.0;
    [Export] public StringName cooldown_group { get; set; } = "";
    [Export] public double group_cooldown { get; set; } = 0.0;
    [Export] public double attack_range { get; set; } = 600.0;
    [Export] public double vertical_range { get; set; } = 400.0;
    [Export] public double minimum_range { get; set; } = 0.0;
    [Export(PropertyHint.Range, "0,1")] public double minimum_health_ratio { get; set; } = 0.0;
    [Export(PropertyHint.Range, "0,1")] public double maximum_health_ratio { get; set; } = 1.0;
    [Export] public Array<StringName> phase_ids { get; set; } = new() {  };
    [Export] public Array<StringName> required_conditions { get; set; } = new() {  };
    [Export] public bool requires_no_summons { get; set; } = false;
    [Export] public Texture2D? announcement { get; set; } = null;
    [Export] public double announcement_lead_seconds { get; set; } = 0.0;
    [Export] public Rect2 warning_rect { get; set; } = default;

    public bool is_valid()
    {
        foreach (double value in new[] { weight, group_cooldown, attack_range, vertical_range, minimum_range, announcement_lead_seconds })
            if (!double.IsFinite(value) || value < 0) return false;
        return !ability_id.IsEmpty && weight > 0 && attack_range > minimum_range && vertical_range > 0
            && minimum_health_ratio >= 0 && maximum_health_ratio <= 1 && minimum_health_ratio <= maximum_health_ratio
            && warning_rect.Position.IsFinite() && warning_rect.Size.IsFinite() && warning_rect.Size.X >= 0 && warning_rect.Size.Y >= 0;
    }
}
