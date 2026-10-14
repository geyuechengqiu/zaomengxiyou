using Godot;
using System;
using System.Collections.Generic;

/// <summary>Retain shared UI wrappers across native scene teardown and GC.</summary>
internal static class BattleUiTextureCache
{
    // Only fixed skill, slot and page assets enter this cache. Gameplay instances
    // never do. Godot disposes tracked resources when the process shuts down.
    private static readonly Dictionary<string, Texture2D> Textures = new(StringComparer.Ordinal);

    public static Texture2D Get(string path)
    {
        if (!Textures.TryGetValue(path, out var texture))
        {
            texture = GD.Load<Texture2D>(path)
                ?? throw new InvalidOperationException("UI texture is missing: " + path);
            Textures.Add(path, texture);
        }
        return texture;
    }
}
