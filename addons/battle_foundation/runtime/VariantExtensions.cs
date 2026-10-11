using Godot;
using Godot.Collections;

// Third-party scripts continue to own their implementation. This boundary keeps
// Variant conversions in one place instead of spreading dynamic calls through rules.
internal static class VariantExtensions
{
    public static Variant GetValueOrDefault(this Dictionary dictionary, Variant key, Variant fallback = default)
        => dictionary.TryGetValue(key, out var value) ? value : fallback;
    public static T? ObjectProperty<[MustBeVariant] T>(this GodotObject owner, StringName name) where T : GodotObject
        => owner.Get(name).As<T>();
}
