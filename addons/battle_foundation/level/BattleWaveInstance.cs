using Godot;

[GlobalClass]
public partial class BattleWaveInstance : RefCounted
{
    public BattleWaveDefinition definition { get; set; } = null!;
    public bool started { get; set; }
    public double started_at { get; set; } = double.PositiveInfinity;
    public bool completed { get; set; }
    public double completed_at { get; set; } = double.PositiveInfinity;
}
