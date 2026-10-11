using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleAttackStep2D : Resource
{
    [Export] public StringName ability_id { get; set; } = "";
    [Export] public StringName action { get; set; } = "";
    [Export] public int duration_frames { get; set; } = 10;
    [Export] public double source_fps { get; set; } = 30.0;
    [Export] public bool allow_jump_cancel { get; set; } = true;
    [Export] public bool allow_turn { get; set; } = false;
    [Export] public int interrupt_priority { get; set; } = 30;
    [Export] public bool super_armor { get; set; } = false;
    [Export] public double root_motion_speed { get; set; } = 0.0;
    [Export] public int root_motion_frames { get; set; } = 0;
    [Export] public int turn_window_start_frame { get; set; } = -1;
    [Export] public int turn_window_end_frame { get; set; } = -1;

    public bool is_turn_window_valid() => (turn_window_start_frame == -1 && turn_window_end_frame == -1)
        || (turn_window_start_frame >= 0 && turn_window_end_frame > turn_window_start_frame && turn_window_end_frame <= duration_frames);
    public bool contains_turn_time(double time) => turn_window_start_frame >= 0
        && time + 0.000000001 >= turn_window_start_frame / source_fps && time + 0.000000001 < turn_window_end_frame / source_fps;
    public double get_duration() => duration_frames / source_fps;
    public Dictionary get_rules() => new() {
        ["move"] = false, ["jump"] = allow_jump_cancel, ["turn"] = allow_turn,
        ["interrupt_priority"] = interrupt_priority, ["super_armor"] = super_armor
    };
}
