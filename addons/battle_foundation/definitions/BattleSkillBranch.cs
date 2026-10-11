using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleSkillBranch : Resource
{
    [Export] public StringName operation { get; set; } = "attack";
    [Export] public StringName target_ability_id { get; set; } = "sunwukong_attack1";
    [Export] public int start_frame { get; set; } = 18;
    [Export] public int end_frame { get; set; } = 24;
    [Export] public int buffer_frames { get; set; } = 6;
    [Export] public int priority { get; set; } = 0;

    public bool is_valid(int duration_frames) => !operation.IsEmpty && !target_ability_id.IsEmpty && start_frame >= 0
        && end_frame > start_frame && end_frame <= duration_frames && buffer_frames >= 0;
}
