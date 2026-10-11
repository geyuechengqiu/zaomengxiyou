using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleSpawnDefinition : Resource
{
    [Export(PropertyHint.Enum, "characters,monsters")] public string category { get; set; } = "monsters";
    [Export] public StringName entity_definition_id { get; set; } = "";
    [Export] public StringName faction_override { get; set; } = "";
    [Export] public Vector3 position { get; set; } = Vector3.Zero;
}
