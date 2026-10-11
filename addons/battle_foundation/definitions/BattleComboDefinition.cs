using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleComboDefinition : Resource
{
    [Export] public Array<BattleAttackStep2D> steps { get; set; } = new() {  };

    public bool is_valid()
    {
        if (steps.Count == 0) return false;
        foreach (var step in steps)
            if (step == null || step.ability_id.IsEmpty || step.action.IsEmpty || step.duration_frames <= 0
                || !double.IsFinite(step.source_fps) || step.source_fps <= 0 || !step.is_turn_window_valid()) return false;
        return true;
    }
}
