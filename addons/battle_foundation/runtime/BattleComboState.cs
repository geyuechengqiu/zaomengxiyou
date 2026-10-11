using Godot;

[GlobalClass]
public partial class BattleComboState : Node
{
    public BattleComboDefinition? definition { get; set; }
    public int index { get; set; } = -1;
    public bool queued_next { get; set; }
    public long cast_serial { get; set; }
    public int motion_facing { get; set; } = 1;
    public bool turn_used { get; set; }
    public bool is_active() => definition != null && index >= 0 && index < definition.steps.Count;
    public BattleAttackStep2D? get_step() => is_active() ? definition!.steps[index] : null;
    public void begin(int step_index, int facing = 1)
    {
        index = step_index; motion_facing = facing >= 0 ? 1 : -1;
        turn_used = false; queued_next = false; cast_serial++;
    }
    public bool queue_next()
    {
        if (!is_active() || index + 1 >= definition!.steps.Count || queued_next) return false;
        queued_next = true;
        return true;
    }
    public void cancel() { index = -1; queued_next = false; turn_used = false; motion_facing = 1; }
}
