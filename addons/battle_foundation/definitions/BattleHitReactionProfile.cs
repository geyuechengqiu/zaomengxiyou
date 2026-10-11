using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleHitReactionProfile : Resource
{
    [Export] public Array<StringName> armor_blocks_kinds { get; set; } = new() { "normal" };
    [Export(PropertyHint.Range, "0.0,10.0")] public double armor_damage_multiplier { get; set; } = 1.0;
    [Export] public bool armor_blocks_displacement { get; set; } = true;
    [Export] public bool invulnerable_blocks_reaction { get; set; } = true;
    [Export] public bool invulnerable_blocks_displacement { get; set; } = true;
    [Export] public bool invulnerable_blocks_status { get; set; } = true;
    [Export] public bool invulnerable_blocks_protection { get; set; } = true;
    [Export] public bool invulnerable_blocks_hit_stop { get; set; } = true;
    [Export] public bool react_on_zero_damage { get; set; } = true;
    [Export(PropertyHint.Range, "0.0,1.0")] public double knockback_resistance { get; set; } = 0.0;
    [Export(PropertyHint.Range, "0.0,1.0")] public double launch_resistance { get; set; } = 0.0;
    [Export(PropertyHint.Range, "0.0,1.0")] public double stun_resistance { get; set; } = 0.0;
    [Export(PropertyHint.Range, "0.0,5.0")] public double hit_landing_seconds { get; set; } = 0.1;
    [Export(PropertyHint.Range, "0.0,10.0")] public double knockdown_seconds { get; set; } = 0.65;
    [Export(PropertyHint.Range, "0.0,5.0")] public double getup_seconds { get; set; } = 0.35;
    [Export] public bool getup_invulnerable { get; set; } = false;

    public bool is_valid()
    {
        foreach (double value in new[] { armor_damage_multiplier, hit_landing_seconds, knockdown_seconds, getup_seconds })
            if (!double.IsFinite(value) || value < 0) return false;
        foreach (double value in new[] { knockback_resistance, launch_resistance, stun_resistance })
            if (!double.IsFinite(value) || value < 0 || value > 1) return false;
        return true;
    }
}
