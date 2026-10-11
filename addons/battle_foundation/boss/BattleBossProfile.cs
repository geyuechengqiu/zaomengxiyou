using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleBossProfile : Resource
{
    [Export] public string display_name { get; set; } = "";
    [Export] public Array<BattleBossSkillRule> skills { get; set; } = new() {  };
    [Export] public Array<BattleBossPhase> phases { get; set; } = new() {  };
    [Export] public int health_bar_count { get; set; } = 3;
    [Export] public int maximum_summons { get; set; } = 8;
    [Export] public StringName completion_condition { get; set; } = "";
    [Export] public double intro_seconds { get; set; } = 0.0;
    [Export] public Resource? attack_decision_policy { get; set; }

    public bool is_valid()
    {
        if (attack_decision_policy != null && !attack_decision_policy.HasMethod("allow_attack")) return false;
        if (skills.Count == 0 || health_bar_count < 1 || maximum_summons < 0 || !double.IsFinite(intro_seconds) || intro_seconds < 0) return false;
        var seen = new System.Collections.Generic.HashSet<StringName>();
        foreach (var rule in skills)
            if (rule == null || !rule.is_valid() || !seen.Add(rule.ability_id)) return false;
        seen.Clear();
        double previous = 1;
        foreach (var phase in phases)
        {
            if (phase == null || !phase.is_valid() || !seen.Add(phase.phase_id) || phase.health_ratio >= previous) return false;
            previous = phase.health_ratio;
        }
        return true;
    }
}
