"""One-time, deliberately restricted resource declaration migration.

Validation methods are handwritten C#. No GDScript interpreter is involved.
"""
from pathlib import Path
import json
import re
import sys

root = Path(sys.argv[1]).resolve()
types = {
    'float': 'double', 'int': 'int', 'bool': 'bool', 'String': 'string',
    'StringName': 'StringName', 'Rect2': 'Rect2', 'Vector2': 'Vector2', 'Vector3': 'Vector3',
    'Dictionary': 'Dictionary', 'GameplayAttributeSet': 'Resource?',
    'GameplayVital': 'Resource', 'GameplayAttributeModifier': 'Resource',
    'GameplayStatusData': 'Resource?', 'PackedScene': 'PackedScene?', 'Texture2D': 'Texture2D?',
    'Resource': 'Resource?', 'JSON': 'Json?',
}

methods = {
'BattleAttackStep2D': '''
    public bool is_turn_window_valid() => (turn_window_start_frame == -1 && turn_window_end_frame == -1)
        || (turn_window_start_frame >= 0 && turn_window_end_frame > turn_window_start_frame && turn_window_end_frame <= duration_frames);
    public bool contains_turn_time(double time) => turn_window_start_frame >= 0
        && time + 0.000000001 >= turn_window_start_frame / source_fps && time + 0.000000001 < turn_window_end_frame / source_fps;
    public double get_duration() => duration_frames / source_fps;
    public Dictionary get_rules() => new() {
        ["move"] = false, ["jump"] = allow_jump_cancel, ["turn"] = allow_turn,
        ["interrupt_priority"] = interrupt_priority, ["super_armor"] = super_armor
    };
''',
'BattleSkillMotion': '''
    public bool is_valid(int duration_frames) => start_frame >= 0 && end_frame > start_frame && end_frame <= duration_frames && velocity.IsFinite();
''',
'BattleSkillBranch': '''
    public bool is_valid(int duration_frames) => !operation.IsEmpty && !target_ability_id.IsEmpty && start_frame >= 0
        && end_frame > start_frame && end_frame <= duration_frames && buffer_frames >= 0;
''',
'BattleComboDefinition': '''
    public bool is_valid()
    {
        if (steps.Count == 0) return false;
        foreach (var step in steps)
            if (step == null || step.ability_id.IsEmpty || step.action.IsEmpty || step.duration_frames <= 0
                || !double.IsFinite(step.source_fps) || step.source_fps <= 0 || !step.is_turn_window_valid()) return false;
        return true;
    }
''',
'BattleAttributeProgression': '''
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
''',
'BattleEntityDefinition': '''
    public override void _ValidateProperty(Dictionary property)
    {
        if (property["name"].AsString() == "scene")
            property["usage"] = property["usage"].AsInt64() | (long)PropertyUsageFlags.NeverDuplicate;
    }
''',
'CharacterAnimationProfile': '''
    public override void _ValidateProperty(Dictionary property)
    {
        if (property["name"].AsString() == "skeleton_data")
            property["usage"] = property["usage"].AsInt64() | (long)PropertyUsageFlags.NeverDuplicate;
    }
''',
'BattleRegionDefinition': '''
    public Rect2 get_automatic_exit_rect() => exit_rect.GrowIndividual((float)camera_transition_margin, 0, 0, 0).Intersection(bounds);
''',
'BattleHitReactionProfile': '''
    public bool is_valid()
    {
        foreach (double value in new[] { armor_damage_multiplier, hit_landing_seconds, knockdown_seconds, getup_seconds })
            if (!double.IsFinite(value) || value < 0) return false;
        foreach (double value in new[] { knockback_resistance, launch_resistance, stun_resistance })
            if (!double.IsFinite(value) || value < 0 || value > 1) return false;
        return true;
    }
''',
'BattleProtectionProfile': '''
    public bool is_valid() => (maximum_override == -1 || maximum_override > 0)
        && double.IsFinite(multiplayer_bonus) && multiplayer_bonus >= 0
        && double.IsFinite(inactivity_reset_seconds) && inactivity_reset_seconds >= 0
        && double.IsFinite(protect_seconds) && protect_seconds >= 0;
''',
'BattleBossPhase': '''
    public bool is_valid() => !phase_id.IsEmpty && double.IsFinite(health_ratio) && health_ratio > 0 && health_ratio < 1;
''',
'BattleBossSkillRule': '''
    public bool is_valid()
    {
        foreach (double value in new[] { weight, group_cooldown, attack_range, vertical_range, minimum_range, announcement_lead_seconds })
            if (!double.IsFinite(value) || value < 0) return false;
        return !ability_id.IsEmpty && weight > 0 && attack_range > minimum_range && vertical_range > 0
            && minimum_health_ratio >= 0 && maximum_health_ratio <= 1 && minimum_health_ratio <= maximum_health_ratio
            && warning_rect.Position.IsFinite() && warning_rect.Size.IsFinite() && warning_rect.Size.X >= 0 && warning_rect.Size.Y >= 0;
    }
''',
'BattleBossProfile': '''
    public bool is_valid()
    {
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
''',
}

declarations_only = {'BattleFrameEvent', 'BattleSpawnDefinition', 'BattleEquipmentDefinition', 'BattleWaveDefinition', 'BattleSpawnPlanDefinition'}
selected = set(methods) | declarations_only

def cs_type(name):
    if name.startswith('Array['):
        return 'Array<' + cs_type(name[6:-1]).rstrip('?') + '>'
    if name.startswith('Dictionary['):
        return 'Dictionary<' + ', '.join(cs_type(part.strip()).rstrip('?') for part in name[11:-1].split(',')) + '>'
    return types.get(name, name + '?')

def initializer(value, kind):
    if value is None:
        if kind.endswith('?'): return 'null'
        if kind == 'StringName' or kind == 'string': return '""'
        return 'default'
    if value == '{}': return 'new()'
    if value.startswith('['): return 'new() { ' + value[1:-1].replace('&"', '"') + ' }'
    value = value.replace('&"', '"').replace('Vector2.ZERO', 'Vector2.Zero').replace('Vector3.ZERO', 'Vector3.Zero')
    if value.startswith('Vector2(') or value.startswith('Vector3(') or value.startswith('Rect2('): value = 'new ' + value
    return value

mapping_path = root / 'tools/csharp/migration-map.json'
mapping = json.loads(mapping_path.read_text(encoding='utf-8'))
for source in (root / 'addons/battle_foundation').rglob('*.gd'):
    text = source.read_text(encoding='utf-8-sig')
    matched = re.search(r'^class_name (\w+)$', text, re.M)
    if not matched or matched[1] not in selected: continue
    classname = matched[1]
    if not re.search(r'^extends Resource$', text, re.M): raise ValueError(classname)
    fields = []
    for line in text.splitlines():
        if not line.startswith('@export'): continue
        found = re.fullmatch(r'(@export(?:_\w+\([^\n]*?\))?) var (\w+): ([\w\[\], ]+)(?: = (.*))?', line)
        if not found:
            inferred = re.fullmatch(r'@export_file\((.*)\) var (\w+) := (".*")', line)
            if inferred: found = None; annotation, name, kind, default = '@export_file(' + inferred[1] + ')', inferred[2], 'string', inferred[3]
            else: raise ValueError(f'Unsupported resource field: {line}')
        else:
            annotation, name, gd_kind, default = found.groups()
            kind = cs_type(gd_kind)
        attribute = '[Export]'
        hint = re.match(r'@export_(range|enum|file)\((.*)\)', annotation)
        if hint:
            hint_type = {'range': 'Range', 'enum': 'Enum', 'file': 'File'}[hint[1]]
            hint_text = ','.join(json.loads('[' + hint[2] + ']')) if hint[1] == 'enum' else hint[2].replace('"', '').replace(' ', '')
            attribute = f'[Export(PropertyHint.{hint_type}, {json.dumps(hint_text, ensure_ascii=False)})]'
        fields.append(f'    {attribute} public {kind} {name} {{ get; set; }} = {initializer(default, kind)};')
    output = 'using Godot;\nusing Godot.Collections;\n\n' + ('[Tool]\n' if text.startswith('@tool') else '')
    output += f'[GlobalClass]\npublic partial class {classname} : Resource\n{{\n' + '\n'.join(fields) + '\n' + methods.get(classname, '') + '}\n'
    target = source.with_name(classname + '.cs')
    target.write_text(output, encoding='utf-8')
    mapping[source.relative_to(root).as_posix()] = target.relative_to(root).as_posix()
mapping_path.write_text(json.dumps(mapping, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
print(f'Authored C# definitions; {len(mapping)} entries await/complete cutover')
