using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleSpawnPlanDefinition : Resource
{
    [Export] public StringName plan_id { get; set; } = "";
    [Export] public StringName spawn_point_id { get; set; } = "";
    [Export] public Array<StringName> monster_ids { get; set; } = new() {  };
    [Export(PropertyHint.Range, "0,600")] public double delay_seconds { get; set; } = 0.0;
    [Export(PropertyHint.Range, "0,600")] public double interval_seconds { get; set; } = 0.0;
    [Export] public Array<StringName> after_created_plan_ids { get; set; } = new() {  };
    [Export] public Array<StringName> after_dead_plan_ids { get; set; } = new() {  };
    [Export] public Array<StringName> required_conditions { get; set; } = new() {  };
    [Export] public bool participates_in_clear { get; set; } = true;
    [Export] public bool is_boss { get; set; } = false;
    [Export(PropertyHint.Enum, "左:-1,右:1")] public int facing { get; set; } = 1;
}
