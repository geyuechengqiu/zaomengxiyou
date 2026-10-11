using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleSpawnPlanInstance : RefCounted
{
    public BattleSpawnPlanDefinition definition { get; set; } = null!;
    public bool started { get; set; }
    public int created { get; set; }
    public double next_due { get; set; } = double.PositiveInfinity;
    public double generation_complete_at { get; set; } = double.PositiveInfinity;
    public double all_dead_at { get; set; } = double.PositiveInfinity;
    public Dictionary targets { get; set; } = new();
    public Dictionary dead_targets { get; set; } = new();
    public bool all_dead_notified { get; set; }
    public bool generation_complete() => started && created == definition.monster_ids.Count;
    public bool all_dead() => generation_complete() && dead_targets.Count == definition.monster_ids.Count;
}
