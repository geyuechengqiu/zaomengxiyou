using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleBossPhase : Resource
{
    [Export] public StringName phase_id { get; set; } = "";
    [Export(PropertyHint.Range, "0,1")] public double health_ratio { get; set; } = 0.5;
    [Export] public StringName entry_ability_id { get; set; } = "";
    [Export] public Array<StringName> required_conditions { get; set; } = new() {  };
    [Export] public bool invulnerable_during_entry { get; set; } = false;
    [Export] public StringName scene_event { get; set; } = "";
    [Export] public string display_name { get; set; } = "";

    public bool is_valid() => !phase_id.IsEmpty && double.IsFinite(health_ratio) && health_ratio > 0 && health_ratio < 1;
}
