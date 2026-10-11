using Godot;

[GlobalClass]
public partial class BattleEquipmentState : RefCounted
{
    public StringName instance_id { get; set; } = "";
    public BattleEquipmentDefinition? definition { get; set; }
    public double durability { get; set; }
    public void initialize(StringName id, BattleEquipmentDefinition data)
    {
        instance_id = id; definition = data; durability = data.max_durability;
    }
}
