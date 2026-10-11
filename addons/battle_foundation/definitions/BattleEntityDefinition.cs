using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleEntityDefinition : Resource
{
    [Export] public StringName definition_id { get; set; } = "";
    [Export] public string display_name { get; set; } = "";
    [Export] public StringName faction_id { get; set; } = "neutral";
    [Export] public PackedScene? scene { get; set; } = null;
    [Export] public Resource? attribute_set { get; set; } = null;
    [Export] public BattleAttributeProgression? progression { get; set; } = null;
    [Export] public BattleFightPowerRules? fight_power_rules { get; set; } = null;
    [Export] public double fight_power_correction { get; set; } = 0.0;
    [Export(PropertyHint.Range, "1,10000")] public int initial_level { get; set; } = 1;
    [Export] public Array<Resource> vitals { get; set; } = new() {  };
    [Export] public Array<StringName> ability_ids { get; set; } = new() {  };
    [Export] public Array<StringName> initial_status_ids { get; set; } = new() {  };

    public override void _ValidateProperty(Dictionary property)
    {
        if (property["name"].AsString() == "scene")
            property["usage"] = property["usage"].AsInt64() | (long)PropertyUsageFlags.NeverDuplicate;
    }
}
