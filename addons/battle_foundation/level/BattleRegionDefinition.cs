using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleRegionDefinition : Resource
{
    [Export] public StringName region_id { get; set; } = "";
    [Export] public string display_name { get; set; } = "";
    [Export] public Rect2 bounds { get; set; } = default;
    [Export] public Rect2 entry_rect { get; set; } = default;
    [Export] public Rect2 exit_rect { get; set; } = default;
    [Export] public Array<StringName> wave_ids { get; set; } = new() {  };
    [Export] public Array<StringName> required_conditions { get; set; } = new() {  };
    [Export] public bool automatic_exit { get; set; } = true;
    [Export(PropertyHint.Range, "0.0,4096.0,1.0")] public double camera_transition_margin { get; set; } = 0.0;

    public Rect2 get_automatic_exit_rect() => exit_rect.GrowIndividual((float)camera_transition_margin, 0, 0, 0).Intersection(bounds);
}
