"""Offline export of Dungeon[1] ordinary fighters and authored AnimationPlayer scenes."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path

#region Paths and Godot text serialization
PROJECT = Path(__file__).resolve().parents[1]

def write(path: str, content: str):
    target = PROJECT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding='utf-8')

def dump(path, value):
    write(path, json.dumps(value, ensure_ascii=False, indent=2) + '\n')

def vec(values):
    return 'Vector2(' + ', '.join(str(v) for v in values) + ')'

def rect(row):
    return 'Rect2(' + ', '.join(str(float(row[k])) for k in ('x','y','width','height')) + ')'

def track(index, path, times, values):
    return f'''tracks/{index}/type = "value"
tracks/{index}/path = NodePath("{path}")
tracks/{index}/interp = 0
tracks/{index}/keys = {{"times": PackedFloat32Array({', '.join(f'{t:.9f}' for t in times)}), "transitions": PackedFloat32Array({', '.join('1' for _ in times)}), "update": 1, "values": [{', '.join(values)}]}}
'''
#endregion

#region Original AMF atlas, pivots, AB geometry, and editor-authored animation library
def export_atlas(source, name, read_amf, read_one):
    raw = source.read_bytes()
    reader = read_amf(raw)
    header = reader.read()
    entries = [read_one(zlib.decompress(reader.read(), -15)) for _ in range(header['fn'])]
    assert reader.pos == len(raw)
    png = next(zlib.decompress(e['data']) for e in entries if e['extension'] == 'png')
    xml = next(zlib.decompress(e['data']) for e in entries if e['extension'] == 'xml')
    ab = next(zlib.decompress(e['data']) for e in entries if e['extension'] == 'ab')
    folder = PROJECT / 'assets/monsters' / name
    folder.mkdir(parents=True, exist_ok=True)
    (folder/'atlas.png').write_bytes(png)
    # Original XML kept as evidence; raw SWF stays in the reference repository.
    (folder/'atlas.xml').write_text(ET.tostring(ET.fromstring(xml), encoding='unicode'), encoding='utf-8')
    (folder/'attack_bounds.xml').write_text(ET.tostring(ET.fromstring(ab), encoding='unicode'), encoding='utf-8')
    rows = []
    actions = {}
    pivot = (0.0, 0.0)
    sub = []
    for element in ET.fromstring(xml):
        row = dict(element.attrib)
        action, number = row['name'][:-4], int(row['name'][-4:])
        if 'pivotX' in row:
            pivot = float(row['pivotX']), float(row['pivotY'])
        row['pivot'] = pivot
        row['index'] = len(rows)
        rows.append(row)
        actions.setdefault(action, []).append(row)
        x,y,w,h = [int(float(row[k])) for k in ('x','y','width','height')]
        if w <= 0 or h <= 0:
            row['texture'] = 'null'
            continue
        frame_enabled = float(row.get('frameWidth',0)) > 0 and float(row.get('frameHeight',0)) > 0
        fx,fy = [float(row.get(k,0)) if frame_enabled else 0 for k in ('frameX','frameY')]
        # ManResourceVO._fill=false allocates width-frameX / height-frameY.
        # Do not clip to frameWidth: 11102 deliberately exceeds those dimensions.
        assert fx <= 0 and fy <= 0
        rid = 'Frame_' + str(row['index'])
        row['texture'] = f'SubResource("{rid}")'
        sub.append(f'''[sub_resource type="AtlasTexture" id="{rid}"]
atlas = ExtResource("atlas")
region = Rect2({x}, {y}, {w}, {h})
margin = Rect2({-fx}, {-fy}, {-fx}, {-fy})
filter_clip = true
''')
    for action, frames in actions.items():
        assert [int(r['name'][-4:]) for r in frames] == list(range(len(frames))), action
    aliases = {'idle':'idle', 'move':'walk', 'run':'walk', 'jump':'idle', 'jump_2':'idle', 'fall':'idle', 'land':'idle', 'hurt':'hurtStand', 'death':'dead', 'attack_1':'skill1'}
    for action, source_action in aliases.items():
        frames = actions[source_action]
        times = [i / 30 for i in range(len(frames))]
        sub.append(f'[sub_resource type="Animation" id="Anim_{action}"]\nlength = {len(frames)/30:.9f}\nloop_mode = {1 if action in ("idle","move","run") else 0}\n')
        ti = 0
        for node, native in [('Body', source_action), ('Effect1', 'skill1_1'), ('Effect2', 'skill1_2')]:
            visible = action == 'attack_1' and native in actions if node != 'Body' else True
            sequence = actions.get(native, []) if visible else []
            sub.append(track(ti, 'Visual/'+node+':visible', [0], ['true' if visible else 'false'])); ti += 1
            if sequence:
                sub.append(track(ti, 'Visual/'+node+':texture', [i/30 for i in range(len(sequence))], [r['texture'] for r in sequence])); ti += 1
                sub.append(track(ti, 'Visual/'+node+':position', [i/30 for i in range(len(sequence))], [vec([-r['pivot'][0], -r['pivot'][1]]) for r in sequence])); ti += 1
    sub.append('[sub_resource type="AnimationLibrary" id="Library"]\n_data = {' + ', '.join(f'&"{a}": SubResource("Anim_{a}")' for a in aliases) + '}\n')
    text = '''[gd_scene format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/animation/animation_player_adapter_2d.gd" id="adapter"]
[ext_resource type="Resource" path="res://data/monsters/NAME/animation.tres" id="profile"]
[ext_resource type="Texture2D" path="res://assets/monsters/NAME/atlas.png" id="atlas"]
[ext_resource type="Script" path="res://addons/battle_foundation/movement/battle_hitbox_2d.gd" id="hitbox"]
[ext_resource type="Resource" path="res://data/monsters/NAME/skill.tres" id="skill"]
[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/gameplay_ability_definition.gd" id="definition"]
'''.replace('NAME',name) + '\n'.join(sub)
    text += '''[sub_resource type="RectangleShape2D" id="HitShape"]
resource_local_to_scene = true
size = Vector2(1, 1)
[node name="AnimationAdapter" type="Node2D"]
script = ExtResource("adapter")
profile = ExtResource("profile")
[node name="Visual" type="Node2D" parent="."]
scale = Vector2(2, 2)
'''
    for node in ['Body','Effect1','Effect2']:
        initial = actions['idle'][0]
        text += f'''[node name="{node}" type="Sprite2D" parent="Visual"]
visible = {'true' if node=='Body' else 'false'}
centered = false
'''
        if node == 'Body':
            text += f'texture = {initial["texture"]}\nposition = {vec([-initial["pivot"][0], -initial["pivot"][1]])}\n'
    text += '''[node name="AnimationPlayer" type="AnimationPlayer" parent="."]
libraries/ = SubResource("Library")
[node name="AttackHitbox" type="Area2D" parent="."]
visible = false
collision_layer = 0
collision_mask = 0
monitoring = false
monitorable = false
script = ExtResource("hitbox")
preview_abilities = Array[ExtResource("definition")]([ExtResource("skill")])
[node name="CollisionShape2D" type="CollisionShape2D" parent="AttackHitbox"]
shape = SubResource("HitShape")
disabled = true
'''
    write(f'data/monsters/{name}/visual.tscn',text)
    write(f'data/monsters/{name}/animation.tres', '''[gd_resource type="Resource" script_class="CharacterAnimationProfile" format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/animation/character_animation_profile.gd" id="script"]
[resource]
script = ExtResource("script")
source_fps = 30.0
display_scale = 2.0
''')
    bounds = {}
    for e in ET.fromstring(ab):
        if float(e.get('width',0)) > 0 and float(e.get('height',0)) > 0:
            action, frame = e.get('name')[3:-4], int(e.get('name')[-4:])
            bounds.setdefault(action, []).append(dict(e.attrib, source_frame=frame))
    return {'sha256':hashlib.sha256(raw).hexdigest(),'animations':{a:len(f) for a,f in actions.items()},'attack_bounds':bounds}
#endregion

#region Original definitions and shared GAS/Core scene components
def export_monster(name, cfg, skill, atlas, gravity=1980.0):
    base = f'data/monsters/{name}'
    shared_attributes = (PROJECT/'data/battle2d/dummy/attributes.tres').read_text(encoding='utf-8')
    values = {'hp':cfg['hpMax'],'mp':0,'atk':cfg['atk'],'def':cfg['phyDef'],'walk':cfg['walkSpeed']*2,'run':cfg['walkSpeed']*2,'rehp':cfg['reHP']}
    for key, value in values.items():
        shared_attributes = re.sub(r'ExtResource\("'+key+r'"\): [\d.]+',f'ExtResource("{key}"): {float(value)}',shared_attributes)
    write(base+'/attributes.tres',shared_attributes)
    write(base+'/actions.tres',f'''[gd_resource type="Resource" script_class="BattleActionProfile2D" format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_action_profile_2d.gd" id="script"]
[resource]
script = ExtResource("script")
attack_skill_id = &"{name}_skill1"
gravity = {gravity}
jump_velocity = -620.0
second_jump_velocity = -620.0
maximum_jumps = {0 if name == 'revival_vessel' else 1}
hurt_lock_frames = 9
''')
    ranged = name == 'yushoushi'
    write(base+'/ai.tres',f'''[gd_resource type="Resource" script_class="BattleAIProfile2D" format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/ai/battle_ai_profile_2d.gd" id="profile"]
[ext_resource type="Script" path="res://addons/battle_foundation/ai/battle_basic_ai_policy_2d.gd" id="policy"]
[ext_resource type="Script" path="res://addons/battle_foundation/ai/battle_ai_target_selector_2d.gd" id="selector"]
[sub_resource type="Resource" id="Policy"]
script = ExtResource("policy")
combat_style = "{'ranged' if ranged else 'melee'}"
[sub_resource type="Resource" id="Selector"]
script = ExtResource("selector")
[resource]
script = ExtResource("profile")
policy = SubResource("Policy")
target_selector = SubResource("Selector")
attack_skill_id = &"{name}_skill1"
attack_range = {400 if ranged else 180}.0
attack_vertical_range = 150.0
minimum_attack_distance = {180 if ranged else 0}.0
retreat_chance = {1.0 if ranged else 0.5}
retreat_minimum = 1.0
retreat_maximum = {1.0 if ranged else 2.0}
original_ai_id = {cfg['aiId']}
''')
    skill_text = '''[gd_resource type="Resource" script_class="GameplayAbilityDefinition" format=3]
[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/gameplay_ability_definition.gd" id="definition"]
[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/features/gameplay_ability_feature.gd" id="feature"]
[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/features/cooldown_feature.gd" id="cooldown"]
[ext_resource type="Script" path="res://addons/battle_foundation/gas/battle_frame_timeline_feature.gd" id="timeline"]
[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_attack_segment.gd" id="segment"]
[sub_resource type="Resource" id="Cooldown"]
script = ExtResource("cooldown")
cooldown_duration = 5.0
'''
    segments = []
    for index, (action, frames) in enumerate(atlas['attack_bounds'].items(),1):
        assert all(b['source_frame']==frames[0]['source_frame']+i for i,b in enumerate(frames))
        segments.append(f'SubResource("Segment{index}")')
        skill_text += f'''[sub_resource type="Resource" id="Segment{index}"]
script = ExtResource("segment")
segment_id = &"{action}"
hit_index = {index}
start_frame = {frames[0]['source_frame']}
end_frame = {frames[-1]['source_frame']+1}
action = &"attack_1"
hit_rect = {rect(frames[0])}
hit_rect_frames = Dictionary[int, Rect2]({{{', '.join(str(f['source_frame'])+': '+rect(f) for f in frames)}}})
hit_stun = {0.5 if ranged else (0.2 if index==1 else 0.5)}
protection_skill_id = "{skill['id']}"
knockback_mode = "displacement"
knockback_distance = {(-50 if ranged else (25 if index==1 else 125))*2}.0
knockback_duration = 0.1
reaction_type = "knockback"
'''
    skill_text += f'''[sub_resource type="Resource" id="Timeline"]
script = ExtResource("timeline")
duration_frames = {atlas['animations']['skill1']}
animation_action = &"attack_1"
commit_resources = true
attack_segments = Array[ExtResource("segment")]([{', '.join(segments)}])
[resource]
script = ExtResource("definition")
ability_id = &"{name}_skill1"
ability_name = "{skill['name']}"
features = Array[ExtResource("feature")]([SubResource("Cooldown"), SubResource("Timeline")])
metadata/original_skill_id = {skill['id']}
metadata/original_skill_cd = {skill['cd']}.0
metadata/original_ai_attack_wait = 5.0
'''
    write(base+'/skill.tres',skill_text)
    # Reuse the existing serialized component set, replacing presentation/input only.
    scene = (PROJECT/'data/battle2d/sunwukong_2d.tscn').read_text(encoding='utf-8')
    scene = scene.replace('res://data/animation/sunwukong_visual.tscn',f'res://{base}/visual.tscn').replace('res://data/battle2d/sunwukong_actions.tres',f'res://{base}/actions.tres').replace('[node name="SunWukong"','[node name="Monster"')
    scene = re.sub(r'\[node name="PlayerOperations"[\s\S]*$', '', scene)
    # Definition holds attributes; empty component overrides remain directly editable.
    scene = re.sub(r'base_values = Dictionary\[StringName, float\]\(\{[\s\S]*?\}\)\ninitial_level_override = 1', 'initial_level_override = 0', scene)
    scene = re.sub(r'\[ext_resource[^\n]* id="(?:player_operations|operation_controller|operation_profile)"\]\n', '', scene)
    scene = scene.replace('radius = 22.0\nheight = 180.0','radius = 22.0\nheight = 220.0').replace('position = Vector2(0, -90)\nshape = SubResource("body")','position = Vector2(0, -110)\nshape = SubResource("body")')
    x,y,w,h = [float(v)*2 for v in cfg['bodyRec'].split(';')]
    scene = scene.replace('size = Vector2(44, 180)',f'size = {vec([w,h])}').replace('position = Vector2(0, -90)\nshape = SubResource("hurt")',f'position = {vec([x+w/2,y+h/2])}\nshape = SubResource("hurt")')
    exts = f'''[ext_resource type="Script" path="res://addons/battle_foundation/ai/battle_ai_controller_2d.gd" id="ai"]
[ext_resource type="Resource" path="res://{base}/ai.tres" id="ai_profile"]
'''
    scene = scene.replace('[sub_resource type="CapsuleShape2D"',exts+'\n[sub_resource type="CapsuleShape2D"',1)
    scene += '''[node name="AIController" type="Node" parent="."]
script = ExtResource("ai")
profile = ExtResource("ai_profile")
'''
    write(base+'/monster.tscn',scene)
    entity = (PROJECT/'data/battle2d/dummy/wooden_dummy.tres').read_text(encoding='utf-8')
    entity = entity.replace('data/battle2d/dummy/attributes.tres',base+'/attributes.tres').replace('data/battle2d/dummy/wooden_dummy.tscn',base+'/monster.tscn').replace('&"木桩"',f'&"{cfg["name"].split("-")[-1]}"').replace('战斗验收木桩',cfg['name'])
    entity += f'initial_level = {cfg["level"]}\nability_ids = Array[StringName]([&"{name}_skill1"])\nmetadata/original_monster_id = {cfg["id"]}\nmetadata/original_resource_id = {cfg["resourceId"]}\nmetadata/original_show_appear = {int(cfg.get("showAppear",0))}\n'
    write(base+'/definition.tres',entity)
#endregion

#region Export entry and source evidence
def export_level():
    manifest = json.loads((PROJECT/'data/battle2d/buffs/manifest.json').read_text(encoding='utf-8'))
    for action in ['attack1', 'attack2', 'attack3', 'attack4', 'attack5', 'run_attack', 'jump_attack']:
        manifest['definitions']['skills']['sunwukong_'+action] = f'res://data/battle2d/original_reactions/{action}.tres'
    manifest['definitions']['monsters'] = {'剑舞':'res://data/monsters/jianwu/definition.tres', '驭兽使':'res://data/monsters/yushoushi/definition.tres'}
    manifest['definitions']['skills'].update({n+'_skill1':f'res://data/monsters/{n}/skill.tres' for n in ['jianwu','yushoushi']})
    manifest['definitions']['levels'] = {'碧玉径':'res://data/levels/biyujing/definition.tres'}
    dump('data/levels/biyujing/manifest.json',manifest)
    write('data/levels/biyujing/definition.tres','''[gd_resource type="Resource" script_class="BattleLevelDefinition" format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_level_definition.gd" id="script"]
[ext_resource type="PackedScene" path="res://data/levels/biyujing/actors.tscn" id="scene"]
[resource]
script = ExtResource("script")
definition_id = &"碧玉径"
display_name = "碧玉径 · 第一关普通小怪"
scene = ExtResource("scene")
metadata/original_dungeon_id = 1
metadata/original_map = "No_1-1_V283"
metadata/original_width = 5472
metadata/original_height = 600
metadata/ordinary_monster_counts = {"剑舞": 16, "驭兽使": 16}
''')
    actors = '''[gd_scene format=3]
[ext_resource type="PackedScene" path="res://data/battle2d/sunwukong_2d.tscn" id="player"]
[ext_resource type="PackedScene" path="res://data/monsters/jianwu/monster.tscn" id="jianwu"]
[ext_resource type="PackedScene" path="res://data/monsters/yushoushi/monster.tscn" id="yushoushi"]
[sub_resource type="RectangleShape2D" id="ground"]
size = Vector2(10944, 400)
[sub_resource type="RectangleShape2D" id="wall"]
size = Vector2(40, 700)
[sub_resource type="RectangleShape2D" id="obstacle"]
size = Vector2(90, 55)
[node name="Actors" type="Node2D"]
[node name="Terrain" type="Node2D" parent="."]
[node name="Ground" type="StaticBody2D" parent="Terrain"]
position = Vector2(5472, 850)
collision_mask = 2
[node name="CollisionShape2D" type="CollisionShape2D" parent="Terrain/Ground"]
shape = SubResource("ground")
[node name="Surface" type="Polygon2D" parent="Terrain/Ground"]
polygon = PackedVector2Array(-5472,-200, 5472,-200, 5472,200, -5472,200)
color = Color(0.15, 0.3, 0.22, 1)
[node name="Grass" type="Polygon2D" parent="Terrain/Ground"]
polygon = PackedVector2Array(-5472,-200, 5472,-200, 5472,-188, -5472,-188)
color = Color(0.45, 0.72, 0.41, 1)
'''
    for i,x in enumerate([0,10944]):
        actors += f'''[node name="Wall{i}" type="StaticBody2D" parent="Terrain"]
position = Vector2({x}, 300)
collision_mask = 2
[node name="CollisionShape2D" type="CollisionShape2D" parent="Terrain/Wall{i}"]
shape = SubResource("wall")
'''
    for i,x in enumerate([3000,6000,8500]):
        actors += f'''[node name="Obstacle{i}" type="StaticBody2D" parent="Terrain"]
position = Vector2({x}, 622.5)
collision_mask = 2
[node name="CollisionShape2D" type="CollisionShape2D" parent="Terrain/Obstacle{i}"]
shape = SubResource("obstacle")
[node name="Rock" type="Polygon2D" parent="Terrain/Obstacle{i}"]
polygon = PackedVector2Array(-45,27.5, -45,-27.5, 45,-27.5, 45,27.5)
color = Color(0.35, 0.4, 0.3, 1)
'''
    actors += '''[node name="SunWukong" parent="." instance=ExtResource("player")]
position = Vector2(650, 650)
scene_definition_id = &"孙悟空"
'''
    names = ['SunWukong']
    for index in range(16):
        for name,ident,offset in [('Sword','剑舞',0),('Beast','驭兽使',260)]:
            node = f'{name}{index+1:02d}'; names.append(node)
            actors += f'''[node name="{node}" parent="." instance=ExtResource("{'jianwu' if name=='Sword' else 'yushoushi'}")]
position = Vector2({1050+index*600+offset}, 650)
scene_definition_id = &"{ident}"
scene_category = "monsters"
'''
    write('data/levels/biyujing/actors.tscn',actors)
    scene = '''[gd_scene format=3]
[ext_resource type="Script" path="res://tests/fixtures/first_level_demo.gd" id="script"]
[ext_resource type="Script" path="res://addons/battle_foundation/runtime/battle_session.gd" id="session"]
[ext_resource type="PackedScene" path="res://data/levels/biyujing/actors.tscn" id="actors"]
[ext_resource type="Resource" path="res://data/damage/original_strategy.tres" id="damage"]
[ext_resource type="PackedScene" path="res://addons/battle_foundation/presentation/battle_presentation_2d.tscn" id="presentation"]
[ext_resource type="PackedScene" path="res://addons/battle_foundation/presentation/combat_feedback_2d.tscn" id="feedback"]
[ext_resource type="PackedScene" path="res://addons/battle_foundation/input/battle_operation_menu.tscn" id="menu"]
[node name="FirstLevelDemo" type="Node2D"]
process_mode = 3
script = ExtResource("script")
[node name="Background" type="CanvasLayer" parent="."]
layer = -5
[node name="Sky" type="ColorRect" parent="Background"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
color = Color(0.1, 0.2, 0.22, 1)
[node name="Mountains" type="Polygon2D" parent="."]
z_index = -1
color = Color(0.17, 0.32, 0.3, 1)
polygon = PackedVector2Array(0,650, 350,180, 800,650, 1300,90, 1700,650, 2300,160, 2800,650, 3200,110, 3800,650, 4300,130, 4900,650, 5500,160, 6100,650, 6700,140, 7200,650, 7700,110, 8500,650, 9000,100, 9600,650, 10400,150, 11000,650)
[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(940, 480)
zoom = Vector2(0.5, 0.5)
[node name="BattleSession" type="Node3D" parent="."]
script = ExtResource("session")
scene_manifest_path = "res://data/levels/biyujing/manifest.json"
scene_seed = 11001
damage_strategy = ExtResource("damage")
[node name="BattlePresentation" parent="BattleSession" instance=ExtResource("presentation")]
'''
    for name in names:
        scene += f'''[node name="{name}Feedback" parent="BattleSession/BattlePresentation/EntityViews" instance=ExtResource("feedback")]
actor_path = NodePath("../../../Actors/{name}")
'''
    scene += '''[node name="Actors" parent="BattleSession" instance=ExtResource("actors")]
[node name="HUD" type="CanvasLayer" parent="."]
layer = 20
[node name="Panel" type="PanelContainer" parent="HUD"]
offset_left = 14.0
offset_top = 12.0
offset_right = 926.0
offset_bottom = 112.0
[node name="Column" type="VBoxContainer" parent="HUD/Panel"]
layout_mode = 2
[node name="Title" type="Label" parent="HUD/Panel/Column"]
layout_mode = 2
theme_override_font_sizes/font_size = 22
text = "阶段11 · 碧玉径小怪：剑舞 / 驭兽使"
[node name="Info" type="Label" parent="HUD/Panel/Column"]
layout_mode = 2
text = "小怪按原版属性战斗；AI提交意图，由Core动作状态机执行。"
[node name="Buttons" type="HBoxContainer" parent="HUD/Panel/Column"]
layout_mode = 2
[node name="Restart" type="Button" parent="HUD/Panel/Column/Buttons"]
layout_mode = 2
focus_mode = 0
text = "重开关卡"
[node name="Stun" type="Button" parent="HUD/Panel/Column/Buttons"]
layout_mode = 2
focus_mode = 0
text = "眩晕附近小怪"
[node name="Slow" type="Button" parent="HUD/Panel/Column/Buttons"]
layout_mode = 2
focus_mode = 0
text = "减速附近小怪"
[node name="Help" type="Label" parent="HUD"]
offset_left = 14.0
offset_top = 540.0
offset_right = 926.0
offset_bottom = 578.0
theme_override_font_sizes/font_size = 17
text = "A/D移动 · K跳跃 · J五连击（跑/跳攻击）· Esc暂停/改键\n16剑舞+16驭兽使，向右前进；地形为可编辑验收地图。"
[node name="OperationMenu" parent="HUD" instance=ExtResource("menu")]
'''
    write('tests/fixtures/first_level_demo.tscn',scene)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--original-root',type=Path,default=Path('D:/UserData/Downloads/game/Speculum-4399-master'))
    args = parser.parse_args()
    sys.path.insert(0,str(args.original_root))
    from backends.zmhj_config import load_config_archive, _Amf3Reader, _read_one
    data = load_config_archive(args.original_root/'games/zmhj-g5')
    original = {'dungeon':data['Dungeon']['1'], 'monsters':{}, 'skills':{}, 'ai':{},'assets':{}, 'other_entities':{mid:data['Monster'][mid] for mid in data['Dungeon']['1']['monsterID'].split(';') if mid not in ['10101','10201']}}
    def no_parents(v):
        if isinstance(v,dict): return {k:no_parents(w) for k,w in v.items() if k!='parent'}
        if isinstance(v,list): return [no_parents(w) for w in v]
        return v
    for name, mid in [('jianwu','10101'),('yushoushi','10201')]:
        cfg = data['Monster'][mid]; skill = data['Skill'][str(cfg['skill1'])]
        source = args.original_root/'games/zmhj-g5/cache/assets/man'/data['Resource'][str(cfg['resourceId'])]['normal']
        atlas = export_atlas(source,name,_Amf3Reader,_read_one)
        original['monsters'][name]=cfg; original['skills'][name]=skill
        original['ai'][name]=no_parents(data['MAi'][str(cfg['aiId'])]); original['assets'][name]=dict(atlas, source=source.relative_to(args.original_root).as_posix())
        # Nape integrates 0.1 seconds at 30 source frames/sec; world scale is 2.
        # AI obstacle jump speed is platform tuning, not a Monster table field.
        gravity = float(data['Common']['1']['gravity']) * (30 * 0.1)**2 * 2
        export_monster(name,cfg,skill,atlas,gravity)
    behavior = ET.fromstring(data['Behavior'])
    original['behaviors'] = [{c.tag:c.text for c in record} for record in behavior if record.findtext('id') in ['1041','2041','111005','207001002','234','201','205']]
    dump('data/monsters/original_first_level.json',original)
    # Extend the original strategy tables, preserving all existing skill mappings.
    table_path = PROJECT/'data/damage/original_skills.json'
    mapping_path = PROJECT/'data/damage/skill_mapping.json'
    table = json.loads(table_path.read_text(encoding='utf-8'))
    mapping = json.loads(mapping_path.read_text(encoding='utf-8'))
    for name, skill in original['skills'].items():
        table[str(skill['id'])] = dict(skill, source_skill_id=skill['id'])
        mapping[name+'_skill1'] = skill['id']
    dump('data/damage/original_skills.json',table)
    dump('data/damage/skill_mapping.json',mapping)
    export_level()
    print('Original fighters exported:', {k:v['animations'] for k,v in original['assets'].items()})

    from convert_monsters_to_spine import convert
    for monster_name in ('jianwu', 'yushoushi', 'revival_vessel'):
        convert(monster_name)
    if (PROJECT/'data/protection/first_level_source.json').exists():
        from refine_combat_hud import author
        author()

if __name__ == '__main__':
    main()
#endregion
