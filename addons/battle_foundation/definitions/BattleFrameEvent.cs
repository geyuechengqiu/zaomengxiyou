using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleFrameEvent : Resource
{
    [Export] public int source_frame { get; set; } = 0;
    [Export] public StringName event_id { get; set; } = "skill.marker";
    [Export] public Dictionary payload { get; set; } = new();
}
