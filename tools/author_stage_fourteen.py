"""Author preplaced loot service and bag controls without rebuilding existing scenes."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]

#region Small idempotent scene changes preserve user-authored configuration
path = ROOT/'game/levels/biyujing.tscn'
text = path.read_text('utf8')
if 'id="loot_service"' not in text:
    pos = text.index('[node ')
    text = text[:pos]+'''[ext_resource type="Script" path="res://addons/battle_foundation/loot/battle_loot_manager_2d.gd" id="loot_service"]
[ext_resource type="JSON" path="res://data/loot/original_first_level.json" id="loot_rules"]
[ext_resource type="Texture2D" path="res://assets/ui/original/spirit_drop.png" id="soul_texture"]

'''+text[pos:]
    pos = text.index('[node name="Actors"')
    text = text[:pos]+'''[node name="Loot" type="Node2D" parent="BattleSession"]
z_index = 100
script = ExtResource("loot_service")
rules = ExtResource("loot_rules")
spirit_texture = ExtResource("soul_texture")

'''+text[pos:]
path.write_text(text, 'utf8')
for relative in ['data/battle2d/sunwukong_2d.tscn', 'data/templates/combatant_base.tscn']:
    path = ROOT/relative; text = path.read_text('utf8')
    if 'id="growth_rules"' not in text:
        pos = text.index('[sub_resource')
        text = text[:pos]+'[ext_resource type="JSON" path="res://data/inventory/growth_rules.json" id="growth_rules"]\n'+text[pos:]
        match = re.search(r'\[node name="Inventory"[^\n]+\]\n', text)
        script = text.index('\n', text.index('script = ', match.end()))+1
        text = text[:script]+'growth_rules = ExtResource("growth_rules")\n'+text[script:]

    # Godot needs the script assigned before its exported properties.
    text = text.replace('growth_rules = ExtResource("growth_rules")\nscript = ExtResource("component_Inventory")', 'script = ExtResource("component_Inventory")\ngrowth_rules = ExtResource("growth_rules")')
    path.write_text(text, 'utf8')
for path in list((ROOT/'data/monsters').glob('*/monster.tscn'))+[ROOT/'data/templates/monster_base.tscn']:
    text = path.read_text('utf8')
    text = re.sub(r'^hide_after_death = true\n', '', text, flags=re.M)
    root = re.search(r'\[node [^\n]+\]\n', text)
    end = text.index('[node ', root.end()) if '[node ' in text[root.end():] else len(text)
    section = text[root.end():end]
    script = re.search(r'^script = [^\n]+\n', section, re.M)
    pos = root.end() + script.end() if script else root.end()
    text = text[:pos]+'hide_after_death = true\n'+text[pos:]
    path.write_text(text, 'utf8')
path = ROOT/'data/ui/inventory.tscn'; text = path.read_text('utf8')
# 成长服务保留给独立面板；背包菜单只显示装备、出售、锁定。
text = re.sub(r'\[node name="(?:Enhance|Reroll)"[^\n]*parent="Context"\]\n.*?(?=\[node |\Z)', '', text, flags=re.S)
nickname = re.search(r'\[node name="Name" type="Label" parent="\."\]\n.*?(?=\[node |\Z)', text, re.S)
if nickname:
    block = nickname.group(0).replace('type="Label"', 'type="LineEdit"').replace('mouse_filter = 2', 'mouse_filter = 0')
    block = re.sub(r'^(?:horizontal_alignment|vertical_alignment) = .*\n', '', block, flags=re.M)
    block += 'max_length = 15\nalignment = 0\ntheme_override_styles/normal = SubResource("NicknameInput")\ntheme_override_styles/focus = SubResource("NicknameInput")\n'
    text = text[:nickname.start()] + block + text[nickname.end():]
    if 'id="NicknameInput"' not in text:
        pos = text.index('[node ')
        text = text[:pos] + '[sub_resource type="StyleBoxEmpty" id="NicknameInput"]\n' + text[pos:]
path.write_text(text.rstrip() + '\n', 'utf8')
print('Authored preplaced shared loot, nickname input and monster corpse cleanup')
#endregion
