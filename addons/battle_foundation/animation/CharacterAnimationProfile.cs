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
    [Export(PropertyHint.Range, "0.01,16,0.01,or_greater")] public double skeleton_geometry_scale { get; set; } = 1.0;
    [Export] public Vector2 skeleton_offset { get; set; } = Vector2.Zero;
    [Export] public Dictionary<StringName, StringName> socket_bones { get; set; } = new();
    [Export] public Dictionary<StringName, StringName> socket_slots { get; set; } = new();
    [Export] public Dictionary<StringName, Vector2> socket_offsets { get; set; } = new();

    // display_scale remains the original gameplay/effect unit conversion.
    // Only the enlarged SpineSprite uses this compensated rendering scale.
    public double get_visual_scale() => display_scale / skeleton_geometry_scale;

    // Spatially enlarged skeleton exports have larger positions but unchanged
    // bone basis vectors. Preserve the public socket transform in game units.
    public Transform2D compensate_socket_transform(Transform2D transform) =>
        new(transform.X * (float)skeleton_geometry_scale,
            transform.Y * (float)skeleton_geometry_scale, transform.Origin);

    public override void _ValidateProperty(Dictionary property)
    {
        if (property["name"].AsString() == "skeleton_data")
            property["usage"] = property["usage"].AsInt64() | (long)PropertyUsageFlags.NeverDuplicate;
    }
}
