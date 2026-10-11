using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleEquipmentDefinition : Resource
{
    [Export] public StringName definition_id { get; set; } = "";
    [Export] public string display_name { get; set; } = "";
    [Export] public StringName slot_id { get; set; } = "weapon";
    [Export] public double max_durability { get; set; } = 100.0;
    [Export] public Array<Resource> attribute_modifiers { get; set; } = new() {  };
}
