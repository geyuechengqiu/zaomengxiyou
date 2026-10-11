using Godot;
using Godot.Collections;
using System;

[GlobalClass]
public partial class BattleFightPowerRules : Resource
{
    public static readonly StringName[] Attributes = ["hpMax", "mpMax", "atk", "phyDef", "hit", "dodge", "critical", "toughness", "lucky", "guardian", "reHP", "reMP"];
    [Export] public Json? source_config { get; set; }
    public Array<StringName> get_attribute_ids() => new(Attributes);
    public bool has_attribute(StringName id) => System.Array.IndexOf(Attributes, id) >= 0;

    public Dictionary get_breakdown(Dictionary attributes, double correction = 0)
    {
        var weights = source_config?.Data.AsGodotDictionary().GetValueOrDefault("weights").AsGodotDictionary() ?? new Dictionary();
        var contributions = new Dictionary();
        double first = 0, second = 0;
        for (int index = 0; index < Attributes.Length; index++)
        {
            var id = Attributes[index];
            double contribution = attributes.GetValueOrDefault(id, 0).AsDouble() * weights.GetValueOrDefault(id.ToString(), 0).AsDouble();
            contributions[id] = contribution;
            if (index < 6) first += contribution;
            else second += contribution;
        }
        double sum = first + second;
        return new Dictionary {
            ["attributes"] = attributes.Duplicate(), ["contributions"] = contributions, ["weighted_sum"] = sum,
            ["attribute_power"] = (long)Math.Floor(sum + 0.5), ["correction"] = correction,
            ["total"] = (long)Math.Floor(sum + correction + 0.5)
        };
    }
    public long calculate(Dictionary attributes, double correction = 0) => get_breakdown(attributes, correction)["total"].AsInt64();
}
