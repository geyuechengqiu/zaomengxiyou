"""Native Mihouwang gameplay authoring, preserving edited skill/range assets.

XML supplies animation lengths and hit start markers, not complete game damage
boxes. The seeded rectangles/windows/balance below are editable project defaults.
"""
from pathlib import Path
import json, re

ROOT=Path(__file__).resolve().parents[1]
FOLDER=ROOT/'data/monsters/zaomeng1/mihou_king'
SKILLS={
    # action: start/end at 60Hz, world rectangle, multiplier, max hits, cooldown
    'attack1': (4,10,(-90, -235, 450, 215),1.5,1,2.0),
    'attack2': (4,12,(-110, -230, 470, 220),1.5,1,2.0),
    'attack3': (2,9,(-130, -235, 520, 225),1.5,1,2.0),
    'attack4': (22,34,(-260, -280, 800, 280),1.5,1,2.0),
    'skill1': (14,38,(-216, -543, 432, 585),2,1,3.0),
    'skill2': (12,40,(-280, -340, 850, 340),2,1,7.0),
    'skill3': (38,190,(-340, -330, 900, 330),1.5,6,10.0),
}

def write(path,text):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(text.rstrip()+'\n','utf8')

def ability(action):return 'mihouwang_'+action

def author(lengths):
    # First import migrates old aliases. Subsequent imports keep all authored
    # geometry, timings and visual AnimationPlayer adjustments intact.
    profile=FOLDER/'animation.tres'
    migrating='&"attack_1"' in profile.read_text('utf8')
    skills=FOLDER/'skills'
    for action,(start,end,rect,mult,hits,cd) in SKILLS.items():
        file=skills/(action+'.tres')
        if file.exists():continue
        x,y,w,h=rect
        write(file,f'''[gd_resource type="Resource" script_class="GameplayAbilityDefinition" format=3]
[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/gameplay_ability_definition.gd" id="definition"]
[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/features/gameplay_ability_feature.gd" id="feature"]
[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_attack_segment.gd" id="segment"]
[ext_resource type="Script" path="res://addons/battle_foundation/gas/battle_frame_timeline_feature.gd" id="timeline"]
[sub_resource type="Resource" id="Hit"]
script = ExtResource("segment")
segment_id = &"{action}"
action = &"{action}"
start_frame = {start}
end_frame = {end}
hit_rect = Rect2({x/3},{y/3},{w/3},{h/3})
damage_multiplier = {float(mult)}
maximum_hits = {hits}
hit_interval = {0.35 if hits>1 else 0.0}
knockback_speed = 220.0
knockback_duration = 0.2
hit_stun = 0.25
reaction_type = "knockback"
[sub_resource type="Resource" id="Timeline"]
script = ExtResource("timeline")
source_fps = 60.0
duration_frames = {round(lengths[action]*60)}
animation_action = &"{action}"
attack_segments = Array[ExtResource("segment")]([SubResource("Hit")])
commit_resources = true
can_use_in_air = {'true' if action=='jumpattack' else 'false'}
can_use_on_ground = {'false' if action=='jumpattack' else 'true'}
[resource]
script = ExtResource("definition")
ability_id = &"{ability(action)}"
ability_name = "猕猴王 · {action}"
features = Array[ExtResource("feature")]([SubResource("Timeline")])
''')
    ranges=FOLDER/'attack_ranges.tscn'
    if not ranges.exists():
        text='''[gd_scene format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/movement/BattleAttackRangeEditor2D.cs" id="editor"]
[ext_resource type="Script" path="res://addons/battle_foundation/movement/BattleEditableAttackRange2D.cs" id="range"]
'''
        for action in SKILLS:text+=f'[ext_resource type="Resource" path="res://data/monsters/zaomeng1/mihou_king/skills/{action}.tres" id="{action}"]\n'
        for action,(_,_,(_,_,w,h),*_) in SKILLS.items():
            text+=f'[sub_resource type="RectangleShape2D" id="{action}"]\nresource_local_to_scene = true\nsize = Vector2({w},{h})\n'
        text+='[node name="AttackRanges" type="Node2D"]\nscript = ExtResource("editor")\n'
        for action,(_,_,(x,y,w,h),*_) in SKILLS.items():
            text+=f'''[node name="{action}" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 0
monitoring = false
monitorable = false
script = ExtResource("range")
ability_id = &"{ability(action)}"
animation_action = &"{action}"
skill_definition = ExtResource("{action}")
[node name="CollisionShape2D" type="CollisionShape2D" parent="{action}"]
position = Vector2({x+w/2},{y+h/2})
shape = SubResource("{action}")
disabled = true
'''
        write(ranges,text)
    if migrating:
        text='''[gd_resource type="Resource" script_class="CharacterAnimationProfile" format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/animation/CharacterAnimationProfile.cs" id="script"]
[ext_resource type="SpineSkeletonDataResource" path="res://assets/monsters/zaomeng1/mihou_king/spinedata.tres" id="skeleton"]
[resource]
script = ExtResource("script")
skeleton_data = ExtResource("skeleton")
source_fps = 60.0
display_scale = 3.0
'''
        text+='animations = Dictionary[StringName, StringName]({'+', '.join(f'&"{a}": &"{a}"' for a in lengths)+'})\n'
        text+='looping_actions = Array[StringName]([&"idle", &"move", &"run", &"fall", &"swimming", &"ride"])\nsocket_bones = Dictionary[StringName, StringName]({&"root": &"root"})\n'
        write(profile,text)
        visual(lengths)
        definition=FOLDER/'definition.tres'
        write(definition,re.sub(r'ability_ids = .*','ability_ids = Array[StringName](['+', '.join(f'&"{ability(a)}"' for a in SKILLS)+'])',definition.read_text('utf8')))
        actions=FOLDER/'actions.tres'
        write(actions,actions.read_text('utf8').replace('zaomeng1_mihou_king_hit1',ability('attack1')).replace('hurt_lock_frames = 15','hurt_lock_frames = 14')+'\nsource_fps = 60.0\n')
        ai=FOLDER/'ai.tres'
        write(ai,ai.read_text('utf8').replace('zaomeng1_mihou_king_hit1',ability('attack1')))
        boss='''[gd_resource type="Resource" script_class="BattleBossProfile" format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/boss/BattleBossProfile.cs" id="profile"]
[ext_resource type="Script" path="res://addons/battle_foundation/boss/BattleBossSkillRule.cs" id="rule"]
'''
        for action,(_,_,(_,_,w,_),_,_,cd) in SKILLS.items():
            if action in ('jumpattack','runattack'):continue
            boss+=f'''[sub_resource type="Resource" id="{action}"]
script = ExtResource("rule")
ability_id = &"{ability(action)}"
cooldown_group = &"{action}"
group_cooldown = {cd}
attack_range = {w*.6}
vertical_range = 600.0
priority = {1 if action.startswith('skill') else 0}
'''
        boss+='[resource]\nscript = ExtResource("profile")\ndisplay_name = "弥猴王"\nskills = Array[ExtResource("rule")](['+', '.join(f'SubResource("{a}")' for a in SKILLS if a not in ('jumpattack','runattack'))+'])\n'
        write(FOLDER/'boss.tres',boss)
        scene=FOLDER/'monster.tscn';text=scene.read_text('utf8')
        text=re.sub(r'^\[ext_resource[^\n]*id="(?:guard|projectile)"[^\n]*\]\n','',text,flags=re.M)
        text=re.sub(r'\[node name="(?:Guard|Projectile)"[^\n]*\]\n[^\[]*','',text)
        if '[editable path="AnimationAdapter"]' not in text:text+='\n[editable path="AnimationAdapter"]\n[editable path="AnimationAdapter/AttackRanges"]\n'
        write(scene,text)
    manifest=ROOT/'data/levels/shuiliandong/manifest.json'
    data=json.loads(manifest.read_text('utf8'));entries=data['definitions']['skills']
    for key in list(entries):
        if key.startswith('zaomeng1_mihou_king_hit') or key in ('mihouwang_runattack','mihouwang_jumpattack'):del entries[key]
    for a in SKILLS:entries[ability(a)]=f'res://data/monsters/zaomeng1/mihou_king/skills/{a}.tres'
    write(manifest,json.dumps(data,ensure_ascii=False,indent=2))

def visual(lengths):
    # Scene is generated only on migration. Subsequent conversions preserve edits.
    text='''[gd_scene format=3 uid="uid://djancibxvvy6d"]
[ext_resource type="Script" path="res://addons/battle_foundation/animation/spine_animation_adapter.gd" id="adapter"]
[ext_resource type="Resource" path="res://data/monsters/zaomeng1/mihou_king/animation.tres" id="profile"]
[ext_resource type="SpineSkeletonDataResource" path="res://assets/monsters/zaomeng1/mihou_king/spinedata.tres" id="spine"]
[ext_resource type="Script" path="res://addons/battle_foundation/movement/battle_hitbox_2d.gd" id="hitbox"]
[ext_resource type="PackedScene" path="res://data/monsters/zaomeng1/mihou_king/attack_ranges.tscn" id="ranges"]
'''
    loops={'idle','move','run','fall','swimming','ride'}
    for action,duration in lengths.items():
        for loop in (False,True):
            clip=action+('_looped' if loop else '')
            text+=f'[sub_resource type="Animation" id="Native_{clip}"]\nlength = {duration}\n'
            for i,(path,value) in enumerate([('.:animation_name',json.dumps(action)),('.:loop','true' if loop else 'false')]):
                text+=f'tracks/{i}/type = "value"\ntracks/{i}/path = NodePath("{path}")\ntracks/{i}/keys = {{"times": PackedFloat32Array(0), "transitions": PackedFloat32Array(1), "update": 1, "values": [{value}]}}\n'
        text+=f'''[sub_resource type="Animation" id="Master_{action}"]
length = {duration}
loop_mode = {1 if action in loops else 0}
tracks/0/type = "animation"
tracks/0/path = NodePath("SpineVisual/SpineAnimationTrack/SpineVisual Track 0")
tracks/0/keys = {{"times": PackedFloat32Array(0), "clips": PackedStringArray("{action+('_looped' if action in loops else '')}")}}
tracks/1/type = "value"
tracks/1/path = NodePath("AttackRanges:preview_action")
tracks/1/keys = {{"times": PackedFloat32Array(0), "transitions": PackedFloat32Array(1), "update": 1, "values": [&"{action}"]}}
tracks/2/type = "value"
tracks/2/path = NodePath("AttackRanges:preview_time")
tracks/2/keys = {{"times": PackedFloat32Array(0,{duration}), "transitions": PackedFloat32Array(1,1), "update": 0, "values": [0.0,{duration}]}}
'''
    text+='[sub_resource type="AnimationLibrary" id="NativeLibrary"]\n_data = {'+', '.join(f'&"{a}{s}": SubResource("Native_{a}{s}")' for a in lengths for s in ('','_looped'))+'}\n'
    text+='[sub_resource type="AnimationLibrary" id="MasterLibrary"]\n_data = {'+', '.join(f'&"{a}": SubResource("Master_{a}")' for a in lengths)+'}\n'
    text+='''[sub_resource type="RectangleShape2D" id="HitShape"]
resource_local_to_scene = true
size = Vector2(1,1)
[node name="AnimationAdapter" type="Node2D"]
script = ExtResource("adapter")
profile = ExtResource("profile")
[node name="SpineVisual" type="SpineSprite" parent="."]
scale = Vector2(3,3)
skeleton_data_res = ExtResource("spine")
preview_skin = "基础"
preview_animation = "idle"
preview_frame = false
[node name="SpineAnimationTrack" type="SpineAnimationTrack" parent="SpineVisual"]
mix_duration = 0.0
[node name="SpineVisual Track 0" type="AnimationPlayer" parent="SpineVisual/SpineAnimationTrack"]
libraries/ = SubResource("NativeLibrary")
[node name="AnimationPlayer" type="AnimationPlayer" parent="."]
libraries/ = SubResource("MasterLibrary")
[node name="AttackHitbox" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 0
monitoring = false
monitorable = false
script = ExtResource("hitbox")
[node name="CollisionShape2D" type="CollisionShape2D" parent="AttackHitbox"]
shape = SubResource("HitShape")
disabled = true
[node name="AttackRanges" parent="." instance=ExtResource("ranges")]
[editable path="AttackRanges"]
'''
    write(FOLDER/'visual.tscn',text)
    from author_super_armor_effects import attach
    attach(FOLDER/'visual.tscn')
