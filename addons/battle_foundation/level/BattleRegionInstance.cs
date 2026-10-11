using Godot;

[GlobalClass]
public partial class BattleRegionInstance : RefCounted
{
    public BattleRegionDefinition definition { get; set; } = null!;
    public bool entered { get; set; }
    public double entered_at { get; set; } = double.PositiveInfinity;
    public bool completed { get; set; }
    public bool exit_open { get; set; }
    public bool exited { get; set; }
}
