using Godot;
using Godot.Collections;

[Tool, GlobalClass]
public partial class BattleDamageNumberLibrary : Resource
{
    [Export] public Dictionary<string, Array> groups { get; set; } = new();
    public Array get_group(string id) => groups.TryGetValue(id, out var group) ? group : new Array();
}
