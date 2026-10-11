using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleWaveDefinition : Resource
{
    [Export] public StringName wave_id { get; set; } = "";
    [Export] public StringName region_id { get; set; } = "";
    [Export] public Array<StringName> plan_ids { get; set; } = new() {  };
    [Export] public Array<StringName> after_wave_ids { get; set; } = new() {  };
    [Export] public Array<StringName> required_conditions { get; set; } = new() {  };
}
