using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;

/// <summary>Stable original quality/type order; instance identity and ownership remain unchanged.</summary>
public partial class InventoryBagPolicy : Resource
{
    public static int Quality(GodotObject item)
    {
        int quality = item.Get("original_data").AsGodotDictionary().GetValueOrDefault("quality", 0).AsInt32();
        while (quality >= 10) quality /= 10;
        return Math.Clamp(quality, 0, 9);
    }
    private static int Part(GodotObject item) => item.Get("original_data").AsGodotDictionary().GetValueOrDefault("part", "").AsString() switch
    {
        "weapon" => 0, "helmet" => 1, "armor" => 2, "ornament" => 3, "wing" => 4, "amulet" => 5,
        "fashionWeapon" => 6, "fashionHelmet" => 7, "fashionArmor" => 8, _ => 9
    };
    public Godot.Collections.Array sort_items(Godot.Collections.Array source)
    {
        var items = new List<GodotObject>();
        foreach (var value in source) if (value.AsGodotObject() is {} item) items.Add(item);
        items.Sort((a,b) =>
        {
            int order = Quality(b).CompareTo(Quality(a));
            if (order == 0) order = Part(a).CompareTo(Part(b));
            if (order == 0) order = string.CompareOrdinal(a.Get("item_id").AsString(), b.Get("item_id").AsString());
            if (order == 0) order = a.Get("runtime_id").AsInt64().CompareTo(b.Get("runtime_id").AsInt64());
            return order;
        });
        var result = new Godot.Collections.Array(); foreach (var item in items) result.Add(item); return result;
    }
}
