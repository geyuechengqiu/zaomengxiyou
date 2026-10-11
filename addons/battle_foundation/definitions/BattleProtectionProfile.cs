using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BattleProtectionProfile : Resource
{
    [Export] public bool enabled { get; set; } = true;
    [Export] public bool show_protect { get; set; } = true;
    [Export] public bool inherit_original_display { get; set; } = true;
    [Export] public string original_boss_key { get; set; } = "Monster/10001";
    [Export] public int maximum_override { get; set; } = -1;
    [Export(PropertyHint.File, "*.json")] public string original_data_path { get; set; } = "res://data/protection/original_protection.json";
    [Export] public bool multiplayer_enemy { get; set; } = false;
    [Export(PropertyHint.Range, "0.0,10.0")] public double multiplayer_bonus { get; set; } = 0.8;
    [Export] public bool use_as_armor { get; set; } = false;
    [Export] public double inactivity_reset_seconds { get; set; } = 3.0;
    [Export] public double protect_seconds { get; set; } = 0.8;
    [Export] public bool protection_action_enabled { get; set; } = true;
    [Export] public StringName protect_ability_id { get; set; } = "";
    [Export] public bool blocks_damage { get; set; } = false;
    [Export] public bool blocks_reaction { get; set; } = true;
    [Export] public bool blocks_displacement { get; set; } = true;
    [Export] public bool blocks_status { get; set; } = false;
    [Export] public bool counts_while_active { get; set; } = false;
    [Export] public Resource? protection_status { get; set; } = null;
    [Export] public Array<Resource> protection_statuses { get; set; } = new() {  };
    [Export] public bool cleanse_debuffs { get; set; } = false;
    [Export] public bool invulnerable_alpha { get; set; } = false;

    public bool is_valid() => (maximum_override == -1 || maximum_override > 0)
        && double.IsFinite(multiplayer_bonus) && multiplayer_bonus >= 0
        && double.IsFinite(inactivity_reset_seconds) && inactivity_reset_seconds >= 0
        && double.IsFinite(protect_seconds) && protect_seconds >= 0;
}
