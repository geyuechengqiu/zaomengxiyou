"""Offline authoring: ZMX1 1-2, original geography/Spine actions/waves, C5 attributes."""
from pathlib import Path
import json, re, shutil, math
from PIL import Image
import import_huaguoshan as h

ROOT, CACHE = h.ROOT, h.CACHE
MAP = ROOT/'data/levels/shuiliandong'
ASSETS = ROOT/'assets/maps/shuiliandong'
WORLD_OFFSET_Y = 200.0  # Move the complete playable terrain down 100 UI pixels.
WATER_SURFACE_Y = 1102.3  # Original visible wave crest + 8 world units.
UNITS = {**h.UNITS, 3:('gorilla_normal','水帘洞大猩猩','jushi_lingjun'),
         4:('mihou_king','水帘洞弥猴王','jushi_lingjun')}
write, dump = h.write, h.dump

def monsters():
    folder=ROOT/'data/monsters/zaomeng1/gorilla_normal'
    original=ROOT/'data/monsters/zaomeng1/gorilla'
    scene=(original/'monster.tscn').read_text('utf8')
    scene=scene.replace('boss/battle_boss_controller_2d.gd','ai/battle_ai_controller_2d.gd')
    scene=re.sub(r'^.*(?:id="boss_profile"|id="object_pool"|boss_profile =|id="protect_profile"|protection_profile =).*$\n?', '',scene,flags=re.M)
    scene=scene.split('[node name="BossObjects"')[0]
    write(folder/'monster.tscn',scene)
    definition=(original/'definition.tres').read_text('utf8').replace('花果山大猩猩','水帘洞大猩猩').replace('gorilla/monster.tscn','gorilla_normal/monster.tscn').replace('metadata/original_monster_id = 10601','metadata/original_monster_id = 10101')
    write(folder/'definition.tres',definition)
    symbols=json.loads((CACHE/'shuiliandong-monsters.json').read_text('utf8'))['symbols']
    bounds={int(c):[int(x0),int(x1),int(y0),int(y1)] for c,x0,x1,y0,y1 in re.findall(r'RENDER_BOUNDS #(\d+) \[RECT x=(-?\d+) to (-?\d+), y=(-?\d+) to (-?\d+)\]',(CACHE/'shuiliandong-bodies.log').read_text('utf8'))}
    h.UNITS[4]=UNITS[4]
    h.monster(4,next(s for s in symbols if 'export.monster.Monster4' in s['names']),bounds)
    folder=ROOT/'data/monsters/zaomeng1/mihou_king'
    scene=(folder/'monster.tscn').read_text('utf8')
    scene=scene.replace('[sub_resource type="CapsuleShape2D"', '[ext_resource type="PackedScene" path="res://data/monsters/zaomeng1/mihou_king/projectile.tscn" id="projectile"]\n[sub_resource type="CapsuleShape2D"',1)
    scene=scene.replace('[sub_resource type="CapsuleShape2D"','[ext_resource type="Script" path="res://addons/battle_foundation/boss/ZaomengOneBossGuard.cs" id="guard"]\n[sub_resource type="CapsuleShape2D"',1)
    scene+='\n[node name="Projectile" parent="." instance=ExtResource("projectile")]\n[node name="Guard" type="Node" parent="."]\nscript = ExtResource("guard")\n'
    scene=scene.replace('res://data/monsters/jushi_lingjun/protection.tres','res://data/monsters/zaomeng1/mihou_king/protection.tres')
    write(folder/'monster.tscn',scene)
    definition=(folder/'definition.tres').read_text('utf8').replace('display_name = "水帘洞弥猴王"','display_name = "弥猴王"')
    definition=definition.replace('res://data/monsters/jushi_lingjun/attributes.tres','res://data/monsters/zaomeng1/mihou_king/mihouwang_attributes.tres').replace('initial_level = 3','initial_level = 5').replace('metadata/stat_source = "碧玉径/jushi_lingjun"','metadata/stat_source = "上古天帝篇/Dungeon/2/Monster/10802"')
    definition=definition.replace('metadata/original_monster_id = 10601','metadata/original_monster_id = 10802')
    definition=re.sub(r'ability_ids = .*','ability_ids = Array[StringName]([&"zaomeng1_mihou_king_hit1", &"zaomeng1_mihou_king_hit2", &"zaomeng1_mihou_king_hit3"])',definition)
    write(folder/'definition.tres',definition)
    source=json.loads((folder/'stat_source.json').read_text('utf8'))['Monster']
    attributes=(ROOT/'data/monsters/jushi_lingjun/attributes.tres').read_text('utf8')
    fields={'hp':'hpMax','mp':'mpMax','def':'phyDef','rehp':'reHP','remp':'reMP','walk':'walkSpeed','run':'walkSpeed'}
    def attribute(match):
        key=match[1];value=float(source.get(fields.get(key,key),0))
        if key in ('walk','run'):value*=2
        return f'ExtResource("{key}"): {value}'
    attributes=re.sub(r'ExtResource\("([^\"]+)"\): -?[\d.]+',attribute,attributes)
    write(folder/'attributes.tres',attributes)
    # Seed a dedicated numeric resource once; later imports preserve manual tuning.
    dedicated=folder/'mihouwang_attributes.tres'
    if not dedicated.exists():
        independent=re.sub(r' uid="uid://[^\"]+"','',attributes)
        independent=independent.replace('[resource]','[resource]\nresource_name = "猕猴王专属属性"')
        write(dedicated,independent)
    protection=(ROOT/'data/monsters/jushi_lingjun/protection.tres').read_text('utf8').replace('Monster/10601','Monster/10802').replace('metadata/original_protect_skill_id = 1900010','metadata/original_protect_skill_id = 2002001')
    write(folder/'protection.tres',protection)

def boss_attacks():
    folder=ROOT/'data/monsters/zaomeng1/mihou_king'
    raw=json.loads((CACHE/'shuiliandong-attacks.json').read_text('utf8'))
    foot=json.loads((ROOT/'assets/monsters/zaomeng1/mihou_king/source.json').read_text('utf8'))['foot_origin']
    refs='''[gd_resource type="Resource" script_class="GameplayAbilityDefinition" format=3]
[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/gameplay_ability_definition.gd" id="definition"]
[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/features/gameplay_ability_feature.gd" id="feature"]
[ext_resource type="Script" path="res://addons/battle_foundation/gas/battle_frame_timeline_feature.gd" id="timeline"]
[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_attack_segment.gd" id="segment"]
[ext_resource type="Script" path="res://addons/battle_foundation/definitions/BattleFrameEvent.cs" id="event"]
'''
    def rect(r):
        x,y,w,hh=r
        return f'Rect2({-x-w:.6f},{y-foot:.6f},{w:.6f},{hh:.6f})'
    for index in (1,2,3):
        action=f'hit{index}'; data=raw[action]; text=refs; segments=[]
        resets=[2] if index==1 else [4,10,15,19,24,29,34,40,45,51,57,64] if index==2 else []
        for si,start in enumerate(resets):
            end=resets[si+1] if si+1<len(resets) else data['duration_frames']
            rows=[f for f in data['frames'] if start<=f['frame']<end]
            if not rows:continue
            # Keep separate original attack IDs; geometry changes within one ID never add hits.
            sid=f'Hit{si}';segments.append(sid)
            text+=f'''[sub_resource type="Resource" id="{sid}"]
script = ExtResource("segment")
segment_id = &"{action}_{si}"
hit_index = {si+1}
start_frame = {start}
end_frame = {end}
action = &"attack_{index}"
hit_rect = {rect(rows[0]['rect'])}
hit_rect_frames = Dictionary[int, Rect2]({{{','.join(str(f['frame'])+': '+rect(f['rect']) for f in rows)}}})
damage_multiplier = {1.0 if index==1 else 20/30}
maximum_hits = {2 if index==1 else 1}
hit_interval = {4/30 if index==1 else 0.0}
knockback_speed = {360.0 if index==1 else 120.0}
knockback_duration = 0.5
launch_speed = {300.0 if index==1 else 420.0}
reset_vertical_velocity = true
reaction_gravity = 2700.0
hit_stun = 0.5
reaction_type = "launch"
protection_parameters = {{"protectPoint": 3334, "protectPointB": 3334, "isProtectPointAdd": 1}}
'''
        if index==3:
            text+='''[sub_resource type="Resource" id="Projectile"]
script = ExtResource("event")
source_frame = 3
event_id = &"battle.zaomeng1.projectile"
'''
        text+=f'''[sub_resource type="Resource" id="Timeline"]
script = ExtResource("timeline")
source_fps = 30.0
duration_frames = {data['duration_frames']}
animation_action = &"attack_{index}"
commit_resources = true
action_rules = {{"move": false, "jump": false, "turn": false{', "invulnerable": true' if index==2 else ''}}}
attack_segments = Array[ExtResource("segment")]([{','.join('SubResource("'+s+'")' for s in segments)}])
'''
        if index==3:text+='events = Array[ExtResource("event")]([SubResource("Projectile")])\n'
        text+=f'''[resource]
script = ExtResource("definition")
ability_id = &"zaomeng1_mihou_king_{action}"
ability_name = "弥猴王 · {action}"
features = Array[ExtResource("feature")]([SubResource("Timeline")])
metadata/zaomeng1_base_power = {30 if index==1 else 20}
'''
        write(folder/('skill.tres' if index==1 else f'skill{index}.tres'),text)
    write(folder/'actions.tres',(ROOT/'data/monsters/zaomeng1/gorilla/actions.tres').read_text('utf8').replace('zaomeng1_gorilla_hit1','zaomeng1_mihou_king_hit1'))
    ai=(ROOT/'data/monsters/zaomeng1/gorilla/ai.tres').read_text('utf8').replace('zaomeng1_gorilla_hit1','zaomeng1_mihou_king_hit1')
    ai=ai.replace('detection_range = 600.0','detection_range = 1880.0')
    write(folder/'ai.tres',ai)
    text='''[gd_resource type="Resource" script_class="BattleBossProfile" format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/boss/BattleBossProfile.cs" id="profile"]
[ext_resource type="Script" path="res://addons/battle_foundation/boss/BattleBossSkillRule.cs" id="rule"]
[ext_resource type="Script" path="res://addons/battle_foundation/ai/ZaomengOneBossPolicy.cs" id="policy"]
[sub_resource type="Resource" id="Policy"]
script = ExtResource("policy")
'''
    for i,rng,minrng,cd,priority in [(1,300,0,0,0),(2,300,0,260/30,2),(3,1880,300.01,180/30,1)]:
        text+=f'''[sub_resource type="Resource" id="Hit{i}"]
script = ExtResource("rule")
ability_id = &"zaomeng1_mihou_king_hit{i}"
attack_range = {rng}.0
minimum_range = {float(minrng)}
vertical_range = 600.0
cooldown_group = &"hit{i}"
group_cooldown = {float(cd)}
priority = {priority}
'''
    text+='''[resource]
script = ExtResource("profile")
display_name = "弥猴王"
attack_decision_policy = SubResource("Policy")
skills = Array[ExtResource("rule")]([SubResource("Hit1"),SubResource("Hit2"),SubResource("Hit3")])
'''
    write(folder/'boss.tres',text)
    dump(MAP/'original_attacks.json',raw)
    # Tight per-frame pixel bounds match BaseObject.beMagicAttack's visual overlap fallback.
    asset=ROOT/'assets/monsters/zaomeng1/mihou_king'
    clips=sorted((CACHE/'shuiliandong-monster-art/Boss2Bullet1').rglob('*.png'),key=lambda p:int(p.stem))
    atlas=Image.new('RGBA',(2048,2048));x=y=row=2;regions=[];geometry=[]
    for file in clips:
        image=Image.open(file).convert('RGBA');crop=image.getbbox()
        if not crop: raise ValueError('Empty original projectile frame')
        im=image.crop(crop)
        if x+im.width+2>2048:x=2;y+=row+4;row=0
        atlas.paste(im,(x,y));regions.append((x,y,im.width,im.height));row=max(row,im.height);x+=im.width+4
        # SWF root origin [-598,-66.9], source faces left; preserve the upright Y axis.
        geometry.append([-(-598+crop[0]+im.width),-66.9+crop[1]-foot,im.width,im.height])
    atlas.crop((0,0,2048,y+row+2)).save(asset/'projectile.png')
    text='''[gd_scene format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/boss/ZaomengOneBossProjectile.cs" id="script"]
[ext_resource type="Texture2D" path="res://assets/monsters/zaomeng1/mihou_king/projectile.png" id="atlas"]
'''
    for i,r in enumerate(regions):text+=f'[sub_resource type="AtlasTexture" id="Frame{i}"]\natlas = ExtResource("atlas")\nregion = Rect2({",".join(map(str,r))})\n'
    text+='[node name="Projectile" type="Node2D"]\nscript = ExtResource("script")\n'
    text+='frames = Array[Texture2D](['+','.join(f'SubResource("Frame{i}")' for i in range(len(regions)))+'])\n'
    text+='frame_rects = Array[Rect2](['+','.join('Rect2('+','.join(map(str,r))+')' for r in geometry)+'])\n'
    text+='[node name="Sprite2D" type="Sprite2D" parent="."]\ncentered = false\nflip_h = true\n'
    write(folder/'projectile.tscn',text)

def bank_polygons():
    """Use connected lower banks, excluding detached platforms in ground art.

    The PNG also includes a floating island over x=2760..3120. Taking the first
    opaque pixel in each column extrudes its transparent underside into a wall.
    Separate alpha components before tracing; the island already has its own
    original one-way Obstacle1 collision.
    """
    image=Image.open(ASSETS/'ground.png').convert('RGBA');w,height=image.size
    mask=bytearray(image.getchannel('A').point(lambda a:255 if a>128 else 0).tobytes())
    columns={}
    for start in range(len(mask)):
        if not mask[start]:continue
        pending=[start];mask[start]=0;area=0;bottom=0;component={}
        while pending:
            pixel=pending.pop();y,x=divmod(pixel,w);area+=1;bottom=max(bottom,y)
            component[x]=min(component.get(x,y),y)
            neighbours=([pixel-1] if x else [])+([pixel+1] if x<w-1 else [])+([pixel-w] if y else [])+([pixel+w] if y<height-1 else [])
            for neighbour in neighbours:
                if mask[neighbour]:mask[neighbour]=0;pending.append(neighbour)
        if area>5000 and bottom>height*.6:
            for x,y in component.items():columns[x]=min(columns.get(x,y),y)
    groups=[];current=[]
    for x in range(0,w,2):
        if x in columns:current.append(((x-18)*2,(columns[x]+346.6+7)*2))
        elif current:groups.append(current);current=[]
    if current:groups.append(current)
    return [h.rdp(points,12) for points in groups if points[-1][0]-points[0][0]>=60]

def map_scene(level):
    ASSETS.mkdir(parents=True,exist_ok=True)
    for name,cid in [('cave',51),('ground',227),('platform',218),('water',225)]:
        shutil.copyfile(h.sprite_file('shuiliandong-art',cid),ASSETS/f'{name}.png')
    visual='[gd_scene format=3]\n[ext_resource type="PackedScene" path="res://addons/battle_foundation/level/battle_map_visual_template_2d.tscn" id="template"]\n'
    for name in ['cave','ground','platform','water']:visual+=f'[ext_resource type="Texture2D" path="res://assets/maps/shuiliandong/{name}.png" id="{name}"]\n'
    visual+='[ext_resource type="Texture2D" path="res://assets/maps/huaguoshan/far.png" id="far"]\n'
    visual+='''[node name="ShuiliandongVisual" instance=ExtResource("template")]
[node name="FarBackground" parent="." index="0"]
scroll_scale = Vector2(0.1295,1)
[node name="Mountains" type="Sprite2D" parent="FarBackground"]
scale = Vector2(2,2)
centered = false
texture = ExtResource("far")
[node name="MiddleBackground" parent="." index="1"]
scroll_scale = Vector2(1,1)
[node name="Cave" type="Sprite2D" parent="MiddleBackground"]
position = Vector2(-490, 12)
scale = Vector2(2,2)
centered = false
texture = ExtResource("cave")
[node name="Ground" type="Sprite2D" parent="GroundArtwork"]
position = Vector2(-36,693.2)
scale = Vector2(2,2)
centered = false
texture = ExtResource("ground")
'''
    for i,obj in enumerate(o for o in level['objects'] if o['character_id'] in (218,225)):
        water=obj['character_id']==225;origin=(-1850.85,-42) if water else (3169.35,359.1)
        name='water' if water else 'platform'
        visual+=f'[node name="Artwork{i}" type="Sprite2D" parent="{"ForegroundOccluders" if water else "GroundArtwork"}"]\nposition = Vector2({(obj["x"]+origin[0])*2},{(obj["y"]+origin[1])*2})\nscale = Vector2(2,2)\ncentered = false\ntexture = ExtResource("{name}")\n'
    write(MAP/'visual.tscn',visual)
    refs='''[gd_scene format=3]
[ext_resource type="PackedScene" path="res://addons/battle_foundation/level/battle_map_template_2d.tscn" id="template"]
[ext_resource type="PackedScene" path="res://data/levels/shuiliandong/visual.tscn" id="visual"]
[ext_resource type="PackedScene" path="res://data/characters/sunwukong/character.tscn" id="player"]
[ext_resource type="Script" path="res://addons/battle_foundation/level/battle_spawn_point_2d.gd" id="point"]
[ext_resource type="Script" path="res://addons/battle_foundation/level/battle_region_gate_2d.gd" id="gate"]
[ext_resource type="PackedScene" path="res://data/ui/gateway.tscn" id="gateway"]
[ext_resource type="Script" path="res://addons/battle_foundation/level/BattleFinalExit2D.cs" id="exit_anchor"]
[ext_resource type="Script" path="res://addons/battle_foundation/level/BattleLevelPreview2D.cs" id="preview"]
[ext_resource type="FontFile" path="res://assets/ui/original/ui_font.ttf" id="preview_font"]
'''
    region_ids=[f'shuiliandong_region_{i+1}' for i in range(5)]
    plan_ids=['shuiliandong_birth_'+re.search(r'\d+',p['instance']).group() for p in level['spawn_plans']]
    for category,names in [('regions',region_ids),('plans',plan_ids)]:
        for name in names:refs+=f'[ext_resource type="Resource" path="res://data/levels/shuiliandong/{category}/{name}.tres" id="{name}"]\n'
    refs+='[sub_resource type="RectangleShape2D" id="Gate"]\nsize = Vector2(20,1600)\n'
    scene='''[node name="Actors" instance=ExtResource("template")]
world_bounds = Rect2(0,0,9400,1400)
ground_y = 1034.8
[node name="ShuiliandongVisual" parent="Visuals" instance=ExtResource("visual")]
'''
    # Solid grass contours preserve the original gaps and slopes, rather than a
    # giant rectangle across the water. Lower pit floors come from source walls.
    groups=bank_polygons()
    for i,points in enumerate(groups):
        points=points+[(points[-1][0],1500),(points[0][0],1500)]
        scene+=f'[node name="Bank{i}" type="StaticBody2D" parent="Terrain"]\ncollision_mask = 2\n[node name="CollisionPolygon2D" type="CollisionPolygon2D" parent="Terrain/Bank{i}"]\npolygon = PackedVector2Array('+','.join(f'{x:.2f},{y:.2f}' for x,y in points)+')\n'
    for i,(bank,next_bank) in enumerate(zip(groups,groups[1:])):
        left,right=bank[-1][0],next_bank[0][0];height=1500-WATER_SURFACE_Y
        refs+=f'[sub_resource type="RectangleShape2D" id="Water{i}"]\nsize = Vector2({right-left},{height})\n'
        scene+=f'[node name="WaterSupport{i}" type="StaticBody2D" parent="Terrain"]\nposition = Vector2({(left+right)/2},{WATER_SURFACE_Y+height/2})\ncollision_mask = 2\n[node name="CollisionShape2D" type="CollisionShape2D" parent="Terrain/WaterSupport{i}"]\nshape = SubResource("Water{i}")\n'
    for i,obj in enumerate(o for o in level['objects'] if o['character_id'] in (180,184)):
        if obj['character_id']==184 and obj['y']<550 and obj['x'] not in (28,4708.3):continue
        cid=obj['character_id'];w=(300 if cid==180 else 296)*2*obj['scale_x'];height=(20 if cid==180 else 66)*2*obj['scale_y']
        refs+=f'[sub_resource type="RectangleShape2D" id="Shape{i}"]\nsize = Vector2({w},{height})\n'
        scene+=f'[node name="Obstacle{i}" type="StaticBody2D" parent="Terrain"]\nposition = Vector2({obj["x"]*2},{obj["y"]*2})\ncollision_mask = 2\n[node name="CollisionShape2D" type="CollisionShape2D" parent="Terrain/Obstacle{i}"]\nshape = SubResource("Shape{i}")\n'
        if cid==180:scene+='one_way_collision = true\n'
    scene+='[node name="SunWukong" parent="." instance=ExtResource("player")]\nposition = Vector2(256,1000)\nscene_definition_id = &"孙悟空"\n'
    for p in level['spawn_plans']:
        pid='shuiliandong_birth_'+re.search(r'\d+',p['instance']).group()
        scene+=f'[node name="{pid}" type="Marker2D" parent="SpawnPoints"]\nposition = Vector2({h.SPAWN_X[pid]},{p["y"]*2})\nscript = ExtResource("point")\nspawn_point_id = &"{pid}"\nmetadata/original_position = Vector2({p["x"]*2},{p["y"]*2})\n'
    for i,(_,right,_) in enumerate(h.REGIONS):
        scene+=f'[node name="Gate{i+1}" type="StaticBody2D" parent="Gates"]\nposition = Vector2({right},700)\nscript = ExtResource("gate")\nregion_id = &"shuiliandong_region_{i+1}"\n[node name="CollisionShape2D" type="CollisionShape2D" parent="Gates/Gate{i+1}"]\nshape = SubResource("Gate")\n[node name="Barrier" type="Polygon2D" parent="Gates/Gate{i+1}"]\nvisible = false\n[node name="Label" type="Label" parent="Gates/Gate{i+1}"]\nvisible = false\n'
    scene+='''[node name="FinalExit" type="Marker2D" parent="."]
position = Vector2(8460.4,915)
script = ExtResource("exit_anchor")
[node name="Gateway" parent="FinalExit" instance=ExtResource("gateway")]
[node name="PlayerBirth" parent="." index="5"]
position = Vector2(256,1000)
[node name="EditorPreview" type="Node2D" parent="."]
script = ExtResource("preview")
'''
    for field,names in [('regions',region_ids),('plans',plan_ids)]:scene+=field+' = Array[Resource](['+','.join(f'ExtResource("{n}")' for n in names)+'])\n'
    scene+='label_font = ExtResource("preview_font")\n'
    # Keep the camera's original vertical limits: translating those as well
    # would cancel the requested downward framing. All gameplay anchors move
    # together; the Actors root stays at zero because spawn positions are world
    # coordinates passed into the shared session.
    scene=scene.replace('world_bounds = Rect2(0,0,9400,1400)',f'world_bounds = Rect2(0,0,9400,{1400+WORLD_OFFSET_Y})')
    scene=scene.replace('ground_y = 1034.8',f'ground_y = {1034.8+WORLD_OFFSET_Y}')
    scene=scene.replace('[node name="ShuiliandongVisual"',f'metadata/world_offset_y = {WORLD_OFFSET_Y}\n[node name="Terrain" parent="." index="1"]\nposition = Vector2(0,{WORLD_OFFSET_Y})\n[node name="SpawnPoints" parent="." index="2"]\nposition = Vector2(0,{WORLD_OFFSET_Y})\n[node name="Gates" parent="." index="3"]\nposition = Vector2(0,{WORLD_OFFSET_Y})\n[node name="ShuiliandongVisual"',1)
    scene=scene.replace('Vector2(256,1000)',f'Vector2(256,{1000+WORLD_OFFSET_Y})').replace('Vector2(8460.4,915)',f'Vector2(8460.4,{915+WORLD_OFFSET_Y})')
    visual=visual.replace('position = Vector2(-490, 12)',f'position = Vector2(-490, {12+WORLD_OFFSET_Y})')
    visual+=f'[node name="GroundArtwork" parent="." index="3"]\nposition = Vector2(0,{WORLD_OFFSET_Y})\n[node name="ForegroundOccluders" parent="." index="4"]\nposition = Vector2(0,{WORLD_OFFSET_Y})\nz_index = -11\n'
    write(MAP/'map.tscn',refs+scene)
    write(MAP/'visual.tscn',visual)
    from author_map_presentation import author_presentation
    author_presentation(MAP/'visual.tscn', 'Cave', 420.0)

def main():
    level=json.loads((ROOT/'docs/reference/zaomeng1/levels.json').read_text('utf8'))['levels'][1]
    from export_shuiliandong_loot import main as export_loot
    export_loot()
    h.REGIONS=[(i*1880,(i+1)*1880,240 if i==0 else i*1880+120) for i in range(5)]
    h.SPAWN_X={};h.MAP=MAP;h.UNITS=UNITS
    for i,(left,right,_) in enumerate(h.REGIONS):
        plans=[p for p in level['spawn_plans'] if p['properties']['stopPointIdx']==i]
        lo=min(p['x']*2 for p in plans);hi=max(p['x']*2 for p in plans);scale=min(1,1520/(hi-lo)) if hi>lo else 1
        for p in plans:
            pid='shuiliandong_birth_'+re.search(r'\d+',p['instance']).group()
            h.SPAWN_X[pid]=round(left+(940 if hi>lo else 1260)+(p['x']*2-(lo+hi)/2)*scale,4)
    # Reuse the independent source-plan authoring, then translate its identifiers.
    h.progression(level)
    for file in list(MAP.rglob('*.tres'))+[MAP/'manifest.json']:
        text=file.read_text('utf8').replace('huaguoshan','shuiliandong').replace('花果山','水帘洞')
        text=text.replace('is_boss = true','is_boss = false')
        if file.parent.name=='plans' and 'monster_ids = Array[StringName]([&"水帘洞弥猴王"]' in text:text=text.replace('is_boss = false','is_boss = true')
        text=text.replace('1216','1400').replace('required_boss_plan_ids = Array[StringName]([&"shuiliandong_birth_13"])','required_boss_plan_ids = Array[StringName]([&"shuiliandong_birth_5"])').replace('metadata/original_stage = "1-1"','metadata/original_stage = "1-2"')
        if file.parent.name=='regions':
            text=re.sub(r'((?:entry_rect|exit_rect) = Rect2\([^\n]+,)1400\)',lambda m:m[1]+str(1400+WORLD_OFFSET_Y)+')',text)
        target=file.with_name(file.name.replace('huaguoshan','shuiliandong'))
        write(target,text)
        if target!=file:file.unlink()
    manifest=json.loads((MAP/'manifest.json').read_text('utf8'))
    manifest['definitions']['monsters']={uid:f'res://data/monsters/zaomeng1/{name}/definition.tres' for name,uid,_ in UNITS.values()}
    # Small monkeys and mountain monkeys reuse the same source-native templates.
    for kind in (1,2):
        name,uid,_=UNITS[kind];manifest['definitions']['monsters'].pop(uid);manifest['definitions']['monsters'][uid]=f'res://data/monsters/zaomeng1/{name}/definition.tres'
    for file in (MAP/'plans').glob('*.tres'):
        text=file.read_text('utf8').replace('水帘洞小猴','花果山小猴').replace('水帘洞山猴','花果山山猴');write(file,text)
    for uid in ('水帘洞小猴','水帘洞山猴'):manifest['definitions']['monsters'].pop(uid,None)
    for k in (1,2):name,uid,_=h.UNITS[k];manifest['definitions']['monsters'][uid]=f'res://data/monsters/zaomeng1/{name}/definition.tres'
    manifest['definitions']['skills'].pop('zaomeng1_gorilla_normal_hit1',None)
    manifest['definitions']['skills']['zaomeng1_gorilla_hit1']='res://data/monsters/zaomeng1/gorilla/skill.tres'
    for i in (1,2,3):manifest['definitions']['skills'][f'zaomeng1_mihou_king_hit{i}']=f'res://data/monsters/zaomeng1/mihou_king/skill{"" if i==1 else i}.tres'
    dump(MAP/'manifest.json',manifest)
    monsters()
    # Apply native DragonBones actions/skills last; never restore legacy Boss4
    # attack timing or projectile rules after the supplied animation is imported.
    from import_mihouwang_spine import convert
    convert()
    map_scene(level)
    from import_stage_thirteen_boss import sound_tags
    sounds=sound_tags(h.SOURCE/'Music.swf');audio=json.loads((ROOT/'data/levels/huaguoshan/audio.json').read_text('utf8'))
    (ROOT/'assets/audio/zaomeng1/shuiliandong.mp3').write_bytes(sounds['bg1'])
    audio['packs']['zaomeng1_shuiliandong']={'music':'res://assets/audio/zaomeng1/shuiliandong.mp3'}
    audio['level_music']={'水帘洞':'zaomeng1_shuiliandong'};audio['music_zones']={'水帘洞':[]}
    for kind in (3,4):audio['units'][UNITS[kind][1]]=audio['units']['巨石灵君']
    dump(MAP/'audio.json',audio)
    source='''[gd_scene format=3]
[ext_resource type="PackedScene" path="res://data/templates/battle_level_base.tscn" id="base"]
[ext_resource type="Script" path="res://game/levels/Shuiliandong.cs" id="script"]
[ext_resource type="PackedScene" path="res://data/levels/shuiliandong/map.tscn" id="map"]
[ext_resource type="PackedScene" path="res://data/ui/campaign_result.tscn" id="result"]
[ext_resource type="Script" path="res://addons/battle_foundation/level/BattleSpawnBudget.cs" id="budget"]
[ext_resource type="JSON" path="res://data/levels/shuiliandong/audio.json" id="audio"]
[ext_resource type="JSON" path="res://data/levels/shuiliandong/loot.json" id="loot"]
[node name="Shuiliandong" instance=ExtResource("base")]
script = ExtResource("script")
level_id = &"水帘洞"
audio_catalog = ExtResource("audio")
[node name="BattleSession" parent="." index="1"]
scene_manifest_path = "res://data/levels/shuiliandong/manifest.json"
scene_seed = 102
[node name="Loot" parent="BattleSession" index="3"]
rules = ExtResource("loot")
[node name="SpawnBudget" type="Node" parent="BattleSession/LevelInstance"]
script = ExtResource("budget")
maximum_live_monsters = 6
[node name="Actors" parent="BattleSession" instance=ExtResource("map")]
[node name="CampaignResult" parent="HUD" instance=ExtResource("result")]
[editable path="BattleSession/Actors"]
'''
    write(ROOT/'game/levels/shuiliandong.tscn',source)
    dump(MAP/'original_source.json',{'source_build':'zmISAV VTest','source_level':level,'world_scale':2,'world_offset_y':WORLD_OFFSET_Y,'boss_stat_source':'上古天帝篇/Dungeon/2/Monster/10802','spawn_seconds_multiplier':.8,'maximum_live_monsters':6,'stat_mapping':{**UNITS,4:('mihou_king','水帘洞弥猴王','上古天帝篇/Dungeon/2/Monster/10802')},'spawn_world_x':h.SPAWN_X,'boss_original_name':'彌猴王'})
    print('Authored Shuiliandong: 5 regions, 18 plans, 48 enemies, original Boss4 Spine/3 attacks/projectile.')

if __name__=='__main__':main()
