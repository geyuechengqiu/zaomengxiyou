using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleAttributeProgression : Resource
{
    [Export] public Resource? attribute_set { get; set; } = null;
    [Export] public Dictionary<StringName, double> growth_per_level { get; set; } = new();
    [Export] public Array<double> experience_per_level { get; set; } = new() {  };
    [Export(PropertyHint.Range, "1,10000")] public int maximum_level { get; set; } = 1;

    public double get_required_experience(int level) => level >= maximum_level || level < 1 || level > experience_per_level.Count ? 0 : experience_per_level[level - 1];
    public bool is_configuration_valid(Dictionary attributes)
    {
        if (maximum_level < 1) return false;
        foreach (var (id, growth) in growth_per_level)
            if (!attributes.ContainsKey(id) || id == "level" || id == "exp" || !double.IsFinite(growth)) return false;
        if (experience_per_level.Count == 0) return true;
        if (experience_per_level.Count < maximum_level - 1) return false;
        for (int level = 1; level < maximum_level; level++)
            if (!double.IsFinite(get_required_experience(level)) || get_required_experience(level) <= 0) return false;
        return true;
    }
}
