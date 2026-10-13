using Godot;
using Godot.Collections;

/// <summary>Inventory definitions for the map's character session; no combat drops or monster spawning.</summary>
public partial class WorldMapInventoryCatalog : Node
{
    [Export] public Json rules { get; set; } = null!;
    [Export] public Array<Resource> item_definitions { get; set; } = new();
    public GodotObject catalog { get; private set; } = null!;
    public override void _Ready()
    {
        catalog = GD.Load<GDScript>("res://addons/simple_inventory/src/core/original_item_catalog.gd").New().AsGodotObject();
        catalog.Call("configure", rules.Data.AsGodotDictionary()["items"]);
        var definitions = catalog.Get("definitions").AsGodotDictionary();
        foreach (var item in item_definitions) definitions[item.Get("item_id")] = item;
    }
    public override void _ExitTree() { catalog = null!; }
}
