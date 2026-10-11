using Godot;
using Godot.Collections;

[GlobalClass]
public partial class CharacterAnimationProfile : Resource
{
    [Export] public Resource? skeleton_data { get; set; } = null;
    [Export] public double source_fps { get; set; } = 30.0;
    [Export] public Dictionary<StringName, StringName> animations { get; set; } = new();
    [Export] public Array<StringName> looping_actions { get; set; } = new() {  };
    [Export] public StringName base_skin { get; set; } = "基础";
    [Export] public double display_scale { get; set; } = 2.0;
    [Export] public Vector2 skeleton_offset { get; set; } = Vector2.Zero;
    [Export] public Dictionary<StringName, StringName> socket_bones { get; set; } = new();
    [Export] public Dictionary<StringName, StringName> socket_slots { get; set; } = new();
    [Export] public Dictionary<StringName, Vector2> socket_offsets { get; set; } = new();

    public override void _ValidateProperty(Dictionary property)
    {
        if (property["name"].AsString() == "skeleton_data")
            property["usage"] = property["usage"].AsInt64() | (long)PropertyUsageFlags.NeverDuplicate;
    }
}
