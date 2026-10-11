using Godot;
using Godot.Collections;
using System;

[GlobalClass]
public partial class BattleDamageRules : RefCounted
{
    public Dictionary sources { get; set; } = new();
    public Array<Dictionary> shields { get; set; } = new();
    public Dictionary hooks { get; set; } = new();
    public Dictionary skill_levels { get; set; } = new();
    public void set_source(StringName id, Dictionary values) => sources[id] = values.Duplicate(true);
    public void remove_source(StringName id) { sources.Remove(id); RemoveShield(id); }
    // Explicit entry points avoid C# optional-argument ambiguity at the GDScript boundary.
    public double get_number(StringName key) => get_number_or(key, 0);
    public double get_number_or(StringName key, double fallback)
    {
        double sum = 0;
        bool found = false;
        foreach (var (_, entry) in sources)
        {
            var values = entry.AsGodotDictionary();
            if (!values.TryGetValue(key, out var value)) continue;
            sum += value.AsDouble(); found = true;
        }
        return found ? sum : fallback;
    }
    public bool has_flag(StringName key)
    {
        foreach (var (_, entry) in sources)
            if (entry.AsGodotDictionary().GetValueOrDefault(key, false).AsBool()) return true;
        return false;
    }
    private void RemoveShield(StringName id)
    {
        for (int index = shields.Count - 1; index >= 0; index--)
            if (shields[index]["source"].AsStringName() == id) shields.RemoveAt(index);
    }
    public void grant_shield(StringName source, double amount)
    {
        RemoveShield(source);
        if (amount > 0 && double.IsFinite(amount)) shields.Add(new Dictionary { ["source"] = source, ["remaining"] = amount });
    }
    public double absorb_normal(double amount)
    {
        double pending = Math.Max(0, amount);
        foreach (var row in shields)
        {
            double taken = Math.Min(pending, row["remaining"].AsDouble());
            row["remaining"] = row["remaining"].AsDouble() - taken;
            pending -= taken;
        }
        for (int index = shields.Count - 1; index >= 0; index--)
            if (shields[index]["remaining"].AsDouble() <= 0) shields.RemoveAt(index);
        return amount - pending;
    }
    public double get_shield_total()
    {
        double sum = 0;
        foreach (var row in shields) sum += row["remaining"].AsDouble();
        return sum;
    }
    public void run_hook(StringName stage, GodotObject info, Node target, Dictionary context)
    {
        if (!hooks.TryGetValue(stage, out var value)) return;
        foreach (var item in value.AsGodotArray().Duplicate())
        {
            var callback = item.AsCallable();
            if (callback.Equals(default(Callable))) continue;
            if (callback.Target != null && !IsInstanceValid(callback.Target)) continue;
            callback.Call(info, target, context);
        }
    }
    public void clear() { sources.Clear(); shields.Clear(); hooks.Clear(); skill_levels.Clear(); }
}
