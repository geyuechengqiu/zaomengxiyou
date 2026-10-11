using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleSkillMotion : Resource
{
    [Export] public int start_frame { get; set; } = 0;
    [Export] public int end_frame { get; set; } = 4;
    [Export] public Vector2 velocity { get; set; } = Vector2.Zero;

    public bool is_valid(int duration_frames) => start_frame >= 0 && end_frame > start_frame && end_frame <= duration_frames && velocity.IsFinite();
}
