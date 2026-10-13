"""Offline authoring of ZMX1 1-1 using original pixels and the Biyujing battle stack.

Reads cached FFDec exports; --export refreshes them from the supplied SWFs.
Generated resources are committed and edited normally in Godot, never built at startup.
"""
from pathlib import Path
import argparse, hashlib, json, math, re, shutil, subprocess
from PIL import Image
from convert_monsters_to_spine import build_visual, blocks, prop

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.cleanup-backup'
MAP = ROOT / 'data/levels/huaguoshan'
ASSETS = ROOT / 'assets/maps/huaguoshan'
EXIT_X = (9399.3 + 9583.3) / 2  # Center of the last descending slope.
EXIT_Y = (887.3 + 1051.3) / 2 + 6
SOURCE = Path('D:/UserData/Downloads/game/swf单机/这是正常flash游戏/造梦西游1')
REFERENCE = Path('D:/UserData/Downloads/game/Speculum-4399-master')
UNITS = {1: ('little_monkey', '花果山小猴', 'jianwu'),
         2: ('mountain_monkey', '花果山山猴', 'yushoushi'),
         3: ('gorilla', '花果山大猩猩', 'jushi_lingjun')}

def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf8')

def dump(path, data):
    write(path, json.dumps(data, ensure_ascii=False, indent=2) + '\n')

def export():
    cp = str(REFERENCE / 'out/swfutil/ffdec_lib_20.1.0/*')
    prefix = ['java', '-Djava.awt.headless=true', '-Dfile.encoding=UTF-8', '-cp', cp]
    for swf, output, symbols, log in [
        ('打开我开始玩.swf', 'huaguoshan-art', '#49,#177,#183,export.FloorBg', 'huaguoshan-map-export.log'),
        ('Monster_v1.swf', 'huaguoshan-monster-art', '#57,#60,#67,#73,#80,#83,#89,#92,#101,#108,#109,#118,#123,#125,#129,#132,#138', 'huaguoshan-monster-export.log')]:
        with (CACHE/log).open('w', encoding='utf8') as target:
            subprocess.run(prefix + ['tools/ExportOriginalBattleUI.java', str(SOURCE/swf), str(CACHE/output), symbols], cwd=ROOT, stdout=target, check=True)
    subprocess.run(prefix + ['tools/ExportFlashTimeline.java', str(SOURCE/'Monster_v1.swf'), str(CACHE/'huaguoshan-monsters.json'),
                   'export.monster.Monster1,export.monster.Monster2,export.monster.Monster3'], cwd=ROOT, check=True)
    subprocess.run(prefix + ['tools/ExportZaomengOneAttacks.java', str(SOURCE/'Monster_v1.swf'), str(CACHE/'huaguoshan-attacks.json'), str(SOURCE/'Role.swf')], cwd=ROOT, check=True)

def sprite_file(folder, symbol, frame=1):
    choices = list((CACHE/folder/('id-'+str(symbol) if isinstance(symbol, int) else symbol)).rglob(f'{frame}.png'))
    if not choices:
        choices = list((CACHE/folder/('id-'+str(symbol))).rglob('*.png'))
    if len(choices) != 1: raise ValueError(f'Expected one export for {symbol}/{frame}: {choices}')
    return choices[0]

def monster(kind, symbol, bounds):
    folder_name, unit_id, base = UNITS[kind]
    name = 'zaomeng1/' + folder_name
    folder = ROOT / 'data/monsters' / name
    asset = ROOT / 'assets/monsters' / name
    labels = {f['labels'][0]: f['placements'] for f in symbol['frames'] if f['labels']}
    placements = {action: next((p for p in values if p['instance'] == 'body'), None) for action, values in labels.items()}
    placements['afterHurt'] = placements.get('afterHurt') or placements['hurt']
    foot = 0
    frame_data = {}
    for action, p in placements.items():
        cid = p['character_id']
        files = sorted((CACHE/f'huaguoshan-monster-art/id-{cid}').rglob('*.png'), key=lambda p:int(p.stem))
        if not files: raise ValueError(f'Missing action body {cid}')
        frames = []
        for file in files:
            image = Image.open(file).convert('RGBA')
            crop = image.getbbox()
            if crop is None: raise ValueError(f'Empty body frame: {file}')
            frames.append((image.crop(crop), bounds[cid][0]/20 + p['x'] + crop[0], bounds[cid][2]/20 + p['y'] + crop[1]))
        frame_data[action] = frames
        if action == 'wait': foot = max(y+im.height for im,x,y in frames)
    aliases = {'idle':'wait', 'move':'walk', 'run':'walk', 'jump':'walk', 'jump_2':'walk', 'fall':'walk',
               'land':'wait', 'hurt':'hurt', 'recover':'afterHurt', 'protect':'afterHurt', 'death':'dead', 'attack_1':'hit1'}
    for index in (2, 3):
        if f'hit{index}' in frame_data: aliases[f'attack_{index}'] = f'hit{index}'
    # Pack deduplicated trimmed source pixels. One constant foot origin across every action.
    regions, attachments, animations, lengths, positions = {}, {}, {}, {}, {}
    atlas_size = 4096 if kind == 4 else 2048
    atlas = Image.new('RGBA', (atlas_size,atlas_size))
    x = y = row = 2
    for original, frames in frame_data.items():
        for index,(im,px,py) in enumerate(frames):
            digest = hashlib.sha256(im.tobytes()+str(im.size).encode()).hexdigest()
            if digest not in positions:
                if x+im.width+2 > atlas_size: x=2; y+=row+4; row=0
                if y+im.height+2 > atlas_size: raise ValueError('Atlas exceeds page size')
                region = 'region_' + str(len(regions))
                regions[region] = [x,y,im.width,im.height]
                atlas.paste(im,(x,y)); positions[digest] = region
                x+=im.width+4; row=max(row,im.height)
            attachment = original+'_'+str(index)
            attachments[attachment] = {'type':'region', 'path':positions[digest], 'x':px+im.width/2,
                                       'y':-(py-foot+im.height/2), 'width':im.width, 'height':im.height}
    for action, original in aliases.items():
        frames = frame_data[original]
        duration = len(frames)/30
        lengths[action] = duration
        animations[action] = {'slots':{'Body':{'attachment':[{'time':round(i/30,9), 'name':original+'_'+str(i)} for i in range(len(frames))]}},
                              'bones':{'root':{'translate':[{'time':duration, 'x':0, 'y':0}]}}}
    asset.mkdir(parents=True, exist_ok=True)
    atlas.crop((0,0,atlas_size,y+row+2)).save(asset/'atlas.png')
    write(asset/'monster.atlas', f'atlas.png\nsize:{atlas_size},{y+row+2}\nfilter:Linear,Linear\npma:false\n'+''.join(f'{n}\nbounds:{x},{y},{w},{h}\n' for n,(x,y,w,h) in regions.items()))
    # ZMX1's source bodies face left; normalize to the project's logical +X attack direction.
    dump(asset/'monster.spine-json', {'skeleton':{'spine':'4.3.00','fps':30,'images':'./'}, 'bones':[{'name':'root'},{'name':'Body','parent':'root','scaleX':-1}],
                                    'slots':[{'name':'Body','bone':'Body'}], 'skins':[{'name':'基础','attachments':{'Body':attachments}}], 'animations':animations})
    write(asset/'spinedata.tres', f'''[gd_resource type="SpineSkeletonDataResource" format=3]
[ext_resource type="SpineAtlasResource" path="res://assets/monsters/{name}/monster.atlas" id="atlas"]
[ext_resource type="SpineSkeletonFileResource" path="res://assets/monsters/{name}/monster.spine-json" id="skeleton"]
[resource]
atlas_res = ExtResource("atlas")
skeleton_file_res = ExtResource("skeleton")
''')
    looped = ['idle','move','run','fall']
    write(folder/'animation.tres', f'''[gd_resource type="Resource" script_class="CharacterAnimationProfile" format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/animation/CharacterAnimationProfile.cs" id="script"]
[ext_resource type="SpineSkeletonDataResource" path="res://assets/monsters/{name}/spinedata.tres" id="skeleton"]
[resource]
script = ExtResource("script")
skeleton_data = ExtResource("skeleton")
source_fps = 30.0
display_scale = 2.0
animations = Dictionary[StringName, StringName]({{{', '.join(f'&"{a}": &"{a}"' for a in aliases)}}})
looping_actions = Array[StringName]([{', '.join(f'&"{a}"' for a in looped)}])
socket_bones = Dictionary[StringName, StringName]({{&"root": &"root"}})
''')
    source = (ROOT/f'data/monsters/{base}/visual.tscn').read_text('utf8')
    source = source.replace(f'data/monsters/{base}/animation.tres', f'data/monsters/{name}/animation.tres')
    source = source.replace(f'data/monsters/{base}/skill.tres', f'data/monsters/{name}/skill.tres')
    source = re.sub(r'\[ext_resource[^\n]*id="skill[23]"[^\n]*\]\n', '', source)
    skill_key = 'skill1' if base == 'jushi_lingjun' else 'skill'
    source = re.sub(r'preview_abilities = .*', f'preview_abilities = Array[ExtResource("definition")]([ExtResource("{skill_key}")])', source)
    source = re.sub(r'\[ext_resource[^\n]*(?:id="spine"|id="armor_outline")[^\n]*\]\n', '', source)
    # The shared converter parses blank-line-delimited Godot blocks.
    source = source.replace('\n[', '\n\n[')
    nodes = {re.search(r'name="([^"]+)"',b).group(1):b for b in blocks(source,'node')}
    nodes.pop('ProtectGlow', None)
    build_visual(folder,name,source,{},lengths,looped,nodes)
    body_height = max(im.height for im,_,_ in frame_data['wait'])*2
    scene = (ROOT/f'data/monsters/{base}/monster.tscn').read_text('utf8').replace(f'data/monsters/{base}/visual.tscn', f'data/monsters/{name}/visual.tscn')
    scene = scene.replace(f'data/monsters/{base}/actions.tres', f'data/monsters/{name}/actions.tres').replace(f'data/monsters/{base}/ai.tres', f'data/monsters/{name}/ai.tres')
    scene = re.sub(r'(\[node name="MotionController"[^\n]*\]\nscript = [^\n]+)', r'\1\nmovement_speed_scale = 0.85', scene)
    if kind == 1:
        scene = re.sub(r'(?=\[(?:sub_resource|node))', '[ext_resource type="Script" path="res://addons/battle_foundation/ai/ZaomengOneAggro.cs" id="aggro"]\n', scene, count=1)
        scene += '\n[node name="Aggro" type="Node" parent="."]\nscript = ExtResource("aggro")\n'
    scene = re.sub(r'height = 220.0', f'height = {body_height}', scene).replace('Vector2(0, -110)',f'Vector2(0, {-body_height/2})')
    scene = re.sub(r'size = Vector2\([\d.]+, [\d.]+\)', f'size = Vector2({body_height*.8}, {body_height})',scene, count=1)
    scene = re.sub(r'position = Vector2\(0.0, -[\d.]+\)', f'position = Vector2(0, {-body_height/2})',scene,count=1)
    if base == 'jushi_lingjun':
        scene = scene.replace('data/monsters/jushi_lingjun/boss.tres', f'data/monsters/{name}/boss.tres')
        scene = re.sub(r'\[ext_resource[^\n]*id="(?:note|wall)"[^\n]*\]\n', '', scene)
        scene = re.sub(r'\[node name="(?:Note|Wall)\d+"[^\n]*\]\n', '', scene)
    write(folder/'monster.tscn', scene)
    definition = (ROOT/f'data/monsters/{base}/definition.tres').read_text('utf8')
    definition = re.sub(r'definition_id = &"[^"]+"',f'definition_id = &"{unit_id}"',definition)
    definition = re.sub(r'display_name = "[^"]+"',f'display_name = "{unit_id.removeprefix("花果山")}"',definition)
    definition = definition.replace(f'data/monsters/{base}/monster.tscn', f'data/monsters/{name}/monster.tscn')
    definition = re.sub(r'ability_ids = .*', f'ability_ids = Array[StringName]([&"zaomeng1_{folder_name}_hit1"])', definition)
    write(folder/'definition.tres', definition + f'\nmetadata/zaomeng1_enemy_type = {kind}\nmetadata/stat_source = "碧玉径/{base}"\n')
    dump(asset/'source.json', {'source':'Monster_v1.swf','symbol':symbol['names'][0], 'original_labels':labels, 'semantic_actions':aliases,
                             'foot_origin':foot,'actions':lengths,'attribute_source':f'data/monsters/{base}/attributes.tres','source_fps':24,'loaded_display_fps':30,'source_facing':-1,'logical_facing':1})

def author_attacks():
    data = json.loads((CACHE/'huaguoshan-attacks.json').read_text('utf8'))
    hurt_seconds = data['player_hurt_frames'] / 30
    if hurt_seconds <= 0: raise ValueError('Original Role1 hurt duration missing')
    for unit in data['units']:
        kind = unit['kind']; name, unit_id, base = UNITS[kind]
        folder = ROOT/'data/monsters/zaomeng1'/name
        foot = json.loads((ROOT/'assets/monsters/zaomeng1'/name/'source.json').read_text('utf8'))['foot_origin']
        frames = unit['frames']; start = frames[0]['frame']; end = frames[-1]['frame']+1
        if [f['frame'] for f in frames] != list(range(start, end)): raise ValueError('Discontinuous original hit1 window')
        def rect(f):
            x,y,w,h = f['rect']
            return f'Rect2({-x-w:.6f}, {y-foot:.6f}, {w:.6f}, {h:.6f})'
        multiplier = 1.0
        aid = f'zaomeng1_{name}_hit1'
        write(folder/'skill.tres', f'''[gd_resource type="Resource" script_class="GameplayAbilityDefinition" format=3]
[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/gameplay_ability_definition.gd" id="definition"]
[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/features/gameplay_ability_feature.gd" id="feature"]
[ext_resource type="Script" path="res://addons/battle_foundation/gas/battle_frame_timeline_feature.gd" id="timeline"]
[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_attack_segment.gd" id="segment"]
[sub_resource type="Resource" id="Hit"]
script = ExtResource("segment")
segment_id = &"hit1"
start_frame = {start}
end_frame = {end}
action = &"attack_1"
hit_rect = {rect(frames[0])}
hit_rect_frames = Dictionary[int, Rect2]({{{', '.join(str(f['frame'])+': '+rect(f) for f in frames)}}})
damage_multiplier = {multiplier}
maximum_hits = 1
knockback_speed = {120.0 if kind == 1 else 360.0}
knockback_duration = {hurt_seconds}
launch_speed = 300.0
reset_vertical_velocity = true
reaction_gravity = 2700.0
hit_stun = {hurt_seconds}
reaction_type = "launch"
protection_parameters = {{"protectPoint": 3334, "protectPointB": 3334, "isProtectPointAdd": 1}}
[sub_resource type="Resource" id="Timeline"]
script = ExtResource("timeline")
source_fps = 30.0
duration_frames = {unit['duration_frames']}
animation_action = &"attack_1"
commit_resources = true
attack_segments = Array[ExtResource("segment")]([SubResource("Hit")])
[resource]
script = ExtResource("definition")
ability_id = &"{aid}"
ability_name = "{unit_id.removeprefix('花果山')} · hit1"
features = Array[ExtResource("feature")]([SubResource("Timeline")])
metadata/zaomeng1_base_power = { {1: 5, 2: 12, 3: 20}[kind] }
metadata/zaomeng1_attack_back_speed = Vector2({2 if kind==1 else 6}, -5)
metadata/zaomeng1_hit_max_count = 1
''')
        write(folder/'actions.tres', f'''[gd_resource type="Resource" script_class="BattleActionProfile2D" format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_action_profile_2d.gd" id="script"]
[resource]
script = ExtResource("script")
attack_skill_id = &"{aid}"
gravity = 2700.0
jump_velocity = -1200.0
second_jump_velocity = -1200.0
maximum_jumps = 1
hurt_lock_frames = 15
''')
        write(folder/'ai.tres', f'''[gd_resource type="Resource" script_class="BattleAIProfile2D" format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/ai/battle_ai_profile_2d.gd" id="profile"]
[ext_resource type="Script" path="res://addons/battle_foundation/ai/ZaomengOneAIPolicy.cs" id="policy"]
[ext_resource type="Script" path="res://addons/battle_foundation/ai/battle_ai_target_selector_2d.gd" id="selector"]
[sub_resource type="Resource" id="Policy"]
script = ExtResource("policy")
passive_until_hit = {'true' if kind == 1 else 'false'}
[sub_resource type="Resource" id="Selector"]
script = ExtResource("selector")
[resource]
script = ExtResource("profile")
policy = SubResource("Policy")
target_selector = SubResource("Selector")
attack_skill_id = &"{aid}"
detection_range = 600.0
vertical_range = {2*{1:80,2:110,3:150}[kind]}
leash_radius = 1800.0
attack_range = {2*{1:80,2:110,3:150}[kind]}
attack_vertical_range = {4*{1:80,2:110,3:150}[kind]}
patrol_radius = 300.0
retreat_chance = 0.0
jump_obstacles = false
''')
        if kind == 3:
            write(folder/'boss.tres', f'''[gd_resource type="Resource" script_class="BattleBossProfile" format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/boss/BattleBossProfile.cs" id="profile"]
[ext_resource type="Script" path="res://addons/battle_foundation/boss/BattleBossSkillRule.cs" id="rule"]
[ext_resource type="Script" path="res://addons/battle_foundation/ai/ZaomengOneAIPolicy.cs" id="policy"]
[sub_resource type="Resource" id="Policy"]
script = ExtResource("policy")
[sub_resource type="Resource" id="Hit1"]
script = ExtResource("rule")
ability_id = &"{aid}"
attack_range = 300.0
vertical_range = 600.0
group_cooldown = 0.0
[resource]
script = ExtResource("profile")
display_name = "大猩猩"
attack_decision_policy = SubResource("Policy")
skills = Array[ExtResource("rule")]([SubResource("Hit1")])
''')
    dump(MAP/'original_attacks.json', data)

def rdp(points, tolerance=2):
    if len(points)<3:return points
    a,b=points[0],points[-1]; dx=b[0]-a[0];dy=b[1]-a[1]
    distances=[abs(dy*(p[0]-a[0])-dx*(p[1]-a[1]))/max(math.hypot(dx,dy),1) for p in points]
    idx=max(range(len(points)),key=distances.__getitem__)
    return rdp(points[:idx+1],tolerance)[:-1]+rdp(points[idx:],tolerance) if distances[idx]>tolerance else [a,b]

def map_scene(level):
    ASSETS.mkdir(parents=True,exist_ok=True)
    for name, symbol in [('far','export.FloorBg'),('forest',49),('platform',177),('ground',183)]:
        shutil.copyfile(sprite_file('huaguoshan-art',symbol),ASSETS/f'{name}.png')
    visual = '[gd_scene format=3]\n[ext_resource type="PackedScene" path="res://addons/battle_foundation/level/battle_map_visual_template_2d.tscn" id="template"]\n'
    for name in ['far','forest','platform','ground']:
        visual += f'[ext_resource type="Texture2D" path="res://assets/maps/huaguoshan/{name}.png" id="{name}"]\n'
    visual += '''[node name="HuaguoshanVisual" instance=ExtResource("template")]
[node name="FarBackground" parent="." index="0"]
scroll_scale = Vector2(0.1295, 1)
[node name="Mountains" type="Sprite2D" parent="FarBackground"]
scale = Vector2(2, 2)
centered = false
texture = ExtResource("far")
[node name="MiddleBackground" parent="." index="1"]
scroll_scale = Vector2(1, 1)
[node name="Forest" type="Sprite2D" parent="MiddleBackground"]
position = Vector2(-60, 140)
scale = Vector2(2, 2)
centered = false
texture = ExtResource("forest")
[node name="Ground" type="Sprite2D" parent="GroundArtwork"]
position = Vector2(-16.7, 863.3)
scale = Vector2(2, 2)
centered = false
texture = ExtResource("ground")
'''
    for i,obj in enumerate(o for o in level['objects'] if o['character_id']==177):
        visual+=f'''[node name="Platform{i}" type="Sprite2D" parent="GroundArtwork"]
position = Vector2({(obj['x']+44209/20)*2}, {(obj['y']+3850/20)*2})
scale = Vector2(2,2)
centered = false
texture = ExtResource("platform")
'''
    write(MAP/'visual.tscn',visual)
    refs = '''[gd_scene format=3]
[ext_resource type="PackedScene" path="res://addons/battle_foundation/level/battle_map_template_2d.tscn" id="template"]
[ext_resource type="PackedScene" path="res://data/levels/huaguoshan/visual.tscn" id="visual"]
[ext_resource type="PackedScene" path="res://data/characters/sunwukong/character.tscn" id="player"]
[ext_resource type="Script" path="res://addons/battle_foundation/level/battle_spawn_point_2d.gd" id="point"]
[ext_resource type="Script" path="res://addons/battle_foundation/level/battle_region_gate_2d.gd" id="gate"]
[ext_resource type="PackedScene" path="res://data/ui/gateway.tscn" id="gateway"]
[ext_resource type="Script" path="res://addons/battle_foundation/level/BattleFinalExit2D.cs" id="exit_anchor"]
[sub_resource type="RectangleShape2D" id="GateShape"]
size = Vector2(20,1280)
[sub_resource type="RectangleShape2D" id="WallShape"]
size = Vector2(128,1280)
[sub_resource type="RectangleShape2D" id="PlatformShape"]
size = Vector2(484.05762,40)
'''
    preview_refs = '[ext_resource type="Script" path="res://addons/battle_foundation/level/BattleLevelPreview2D.cs" id="preview"]\n[ext_resource type="FontFile" path="res://assets/ui/original/ui_font.ttf" id="preview_font"]\n'
    preview_regions = [f'huaguoshan_region_{i+1}' for i in range(len(REGIONS))]
    preview_plans = ['huaguoshan_birth_'+re.search(r'\d+',p['instance']).group() for p in level['spawn_plans']]
    for category,names in [('regions',preview_regions),('plans',preview_plans)]:
        for name in names:
            preview_refs += f'[ext_resource type="Resource" path="res://data/levels/huaguoshan/{category}/{name}.tres" id="preview_{name}"]\n'
    refs = refs.replace('[sub_resource', preview_refs+'[sub_resource', 1)
    scene = '''[node name="Actors" instance=ExtResource("template")]
bounds = Rect2(0,0,9660,1216)
ground_y = 1037.1
[node name="HuaguoshanVisual" parent="Visuals" instance=ExtResource("visual")]
[node name="Ground" type="StaticBody2D" parent="Terrain"]
collision_mask = 2
[node name="CollisionPolygon2D" type="CollisionPolygon2D" parent="Terrain/Ground"]
'''
    image=Image.open(ASSETS/'ground.png').convert('RGBA')
    # Trace the actual grass contour, with the original flat-ground collision inset (7px).
    points=[]
    for x in range(0,image.width,2):
        ys=[y for y in range(image.height) if image.getpixel((x,y))[3]>128]
        if ys: points.append(((x-8.35)*2,(min(ys)+431.65+7)*2))
    # Ignore tiny grass-tooth pixels: collision slopes stay smooth like the original debug walls.
    points=rdp(points,15)
    points.append((9660,points[-1][1]))
    points += [(9660,1280),(points[0][0],1280)]
    # Authored textured underside closes transparent atlas edges and the viewport bottom.
    fill = [(x, y+4 if idx < len(points)-2 else y) for idx,(x,y) in enumerate(points)]
    visual = visual.replace('[node name="HuaguoshanVisual"', '[ext_resource type="Shader" path="res://assets/maps/huaguoshan/ground_continuation.gdshader" id="stone_shader"]\n[sub_resource type="ShaderMaterial" id="StoneMaterial"]\nshader = ExtResource("stone_shader")\n[node name="HuaguoshanVisual"', 1)
    fill_node = '[node name="GroundContinuation" type="Polygon2D" parent="GroundArtwork"]\nmaterial = SubResource("StoneMaterial")\ntexture = ExtResource("ground")\npolygon = PackedVector2Array('+','.join(f'{x:.2f},{y:.2f}' for x,y in fill)+')\n'
    visual = visual.replace('[node name="Ground" type="Sprite2D" parent="GroundArtwork"]', fill_node+'[node name="Ground" type="Sprite2D" parent="GroundArtwork"]', 1)
    write(MAP/'visual.tscn', visual)
    scene+='polygon = PackedVector2Array('+','.join(f'{x:.2f},{y:.2f}' for x,y in points)+')\n'
    for i,x in enumerate([-64,9724]):
        scene+=f'[node name="Wall{i}" type="StaticBody2D" parent="Terrain"]\nposition = Vector2({x},640)\ncollision_mask = 2\n[node name="CollisionShape2D" type="CollisionShape2D" parent="Terrain/Wall{i}"]\nshape = SubResource("WallShape")\n'
    for i,obj in enumerate(o for o in level['objects'] if o['character_id']==180):
        scene+=f'[node name="Platform{i}" type="StaticBody2D" parent="Terrain"]\nposition = Vector2({obj["x"]*2},{obj["y"]*2})\ncollision_mask = 2\n[node name="CollisionShape2D" type="CollisionShape2D" parent="Terrain/Platform{i}"]\nshape = SubResource("PlatformShape")\none_way_collision = true\n'
    scene+='[node name="SunWukong" parent="." instance=ExtResource("player")]\nposition = Vector2(256,984)\nscene_definition_id = &"孙悟空"\n'
    for plan in level['spawn_plans']:
        pid='huaguoshan_birth_'+re.search(r'\d+',plan['instance']).group()
        scene+=f'[node name="{pid}" type="Marker2D" parent="SpawnPoints"]\nposition = Vector2({SPAWN_X[pid]},{plan["y"]*2})\nscript = ExtResource("point")\nspawn_point_id = &"{pid}"\nmetadata/original_position = Vector2({plan["x"]*2},{plan["y"]*2})\n'
    for i,(left,right,entry) in enumerate(REGIONS):
        scene+=f'[node name="Gate{i+1}" type="StaticBody2D" parent="Gates"]\nposition = Vector2({right},608)\nscript = ExtResource("gate")\nregion_id = &"huaguoshan_region_{i+1}"\n[node name="CollisionShape2D" type="CollisionShape2D" parent="Gates/Gate{i+1}"]\nshape = SubResource("GateShape")\n'
        scene+=f'[node name="Barrier" type="Polygon2D" parent="Gates/Gate{i+1}"]\nvisible = false\npolygon = PackedVector2Array(-10,-640,10,-640,10,640,-10,640)\ncolor = Color(1,0.5,0.1,0)\n[node name="Label" type="Label" parent="Gates/Gate{i+1}"]\nvisible = false\n'
    exit_y = next(a[1]+(EXIT_X-a[0])/(b[0]-a[0])*(b[1]-a[1])+6 for a,b in zip(points,points[1:]) if a[0]<=EXIT_X<b[0])
    scene+=f'[node name="FinalExit" type="Marker2D" parent="."]\nposition = Vector2({EXIT_X},{exit_y:.2f})\nscript = ExtResource("exit_anchor")\n[node name="Gateway" parent="FinalExit" instance=ExtResource("gateway")]\n[node name="PlayerBirth" parent="." index="5"]\nposition = Vector2(256,984)\n'
    scene+='[node name="EditorPreview" type="Node2D" parent="."]\nscript = ExtResource("preview")\n'
    for field,names in [('regions',preview_regions),('plans',preview_plans)]:
        scene += field+' = Array[Resource](['+','.join(f'ExtResource("preview_{name}")' for name in names)+'])\n'
    scene+='label_font = ExtResource("preview_font")\n'
    write(MAP/'map.tscn',refs+scene)

def progression(level):
    refs='[gd_resource type="Resource" script_class="BattleLevelDefinition" format=3]\n[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_level_definition.gd" id="script"]\n[ext_resource type="PackedScene" path="res://data/levels/huaguoshan/map.tscn" id="scene"]\n'
    for category,klass in [('regions','BattleRegionDefinition'),('waves','BattleWaveDefinition'),('plans','BattleSpawnPlanDefinition')]:
        refs+=f'[ext_resource type="Script" path="res://addons/battle_foundation/level/{klass}.cs" id="{category}_type"]\n'
    ids={'regions':[],'waves':[],'plans':[]}
    for i,(left,right,entry) in enumerate(REGIONS):
        rid=f'huaguoshan_region_{i+1}';wid=rid+'_wave';ids['regions'].append(rid);ids['waves'].append(wid)
        pidlist=[]
        for p in level['spawn_plans']:
            row=p['properties']
            if row['stopPointIdx']!=i:continue
            pid='huaguoshan_birth_'+re.search(r'\d+',p['instance']).group();pidlist.append(pid);ids['plans'].append(pid)
            write(MAP/f'plans/{pid}.tres',f'''[gd_resource type="Resource" script_class="BattleSpawnPlanDefinition" format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/level/BattleSpawnPlanDefinition.cs" id="script"]
[resource]
script = ExtResource("script")
plan_id = &"{pid}"
spawn_point_id = &"{pid}"
monster_ids = Array[StringName]([{','.join('&"'+UNITS[row['enemyType']][1]+'"' for _ in range(row['totalNum']))}])
delay_seconds = {row['delay']*.8}
interval_seconds = {row['interval']*.8}
facing = -1
is_boss = {'true' if row['enemyType']==3 else 'false'}
metadata/original_delay = {row['delay']}
metadata/original_interval = {row['interval']}
metadata/original_stop_point_idx = {i}
''')
        write(MAP/f'waves/{wid}.tres',f'[gd_resource type="Resource" script_class="BattleWaveDefinition" format=3]\n[ext_resource type="Script" path="res://addons/battle_foundation/level/BattleWaveDefinition.cs" id="script"]\n[resource]\nscript = ExtResource("script")\nwave_id = &"{wid}"\nregion_id = &"{rid}"\nplan_ids = Array[StringName]([{",".join(chr(38)+chr(34)+p+chr(34) for p in pidlist)}])\n')
        write(MAP/f'regions/{rid}.tres',f'''[gd_resource type="Resource" script_class="BattleRegionDefinition" format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/level/BattleRegionDefinition.cs" id="script"]
[resource]
script = ExtResource("script")
region_id = &"{rid}"
display_name = "花果山 · 区域{i+1}"
bounds = Rect2({left},0,{right-left},1216)
entry_rect = Rect2({entry},0,160,1216)
exit_rect = Rect2({EXIT_X-130 if i==4 else right-96},{EXIT_Y-240 if i==4 else 0},{260 if i==4 else 96},{260 if i==4 else 1216})
wave_ids = Array[StringName]([&"{wid}"])
automatic_exit = {'false' if i==4 else 'true'}
camera_transition_margin = 840.0
metadata/original_stop_x = {level['runtime_stop_points'][i]['x']}
''')
    for category,names in ids.items():
        for name in names:refs+=f'[ext_resource type="Resource" path="res://data/levels/huaguoshan/{category}/{name}.tres" id="{name}"]\n'
    refs+='[resource]\nscript = ExtResource("script")\ndefinition_id = &"花果山"\ndisplay_name = "造梦西游1 · 花果山"\nscene = ExtResource("scene")\n'
    for category,field in [('regions','regions'),('waves','waves'),('plans','spawn_plans')]:
        refs+=f'{field} = Array[ExtResource("{category}_type")]([{",".join("ExtResource("+chr(34)+n+chr(34)+")" for n in ids[category])}])\n'
    refs+='required_boss_plan_ids = Array[StringName]([&"huaguoshan_birth_13"])\nmetadata/original_stage = "1-1"\n'
    write(MAP/'definition.tres',refs)
    manifest=json.loads((ROOT/'data/levels/biyujing/progression/manifest.json').read_text('utf8'))
    manifest['definitions']['levels']={'花果山':'res://data/levels/huaguoshan/definition.tres'}
    manifest['definitions']['monsters']={id:f'res://data/monsters/zaomeng1/{name}/definition.tres' for name,id,_ in UNITS.values()}
    for name,_,_ in UNITS.values():
        manifest['definitions']['skills'][f'zaomeng1_{name}_hit1'] = f'res://data/monsters/zaomeng1/{name}/skill.tres'
    dump(MAP/'manifest.json',manifest)

def entry_scene():
    old=ROOT/'game/levels/biyujing.tscn'
    source=old.read_text('utf8')
    # Idempotent: once extracted, preserve hand edits to the common scene.
    if 'battle_level_base.tscn' not in source:
        base=re.sub(r' uid="[^"]+"','',source)
        base=re.sub(r'\[ext_resource[^\n]*id="map"[^\n]*\]\n','',base)
        base=re.sub(r'\[node name="Actors" parent="BattleSession"[^\n]*\]\n\n','',base)
        base=base.replace('game/levels/Biyujing.cs','game/levels/BattleLevelScene.cs')
        write(ROOT/'data/templates/battle_level_base.tscn',base)
        write(old,'''[gd_scene format=3 uid="uid://b1kn8kng4btf2"]
[ext_resource type="PackedScene" path="res://data/templates/battle_level_base.tscn" id="base"]
[ext_resource type="Script" path="res://game/levels/Biyujing.cs" id="script"]
[ext_resource type="PackedScene" path="res://data/levels/biyujing/progression/map.tscn" id="map"]
[node name="LevelProgressionDemo" instance=ExtResource("base")]
script = ExtResource("script")
[node name="Actors" parent="BattleSession" instance=ExtResource("map")]
''')
    write(ROOT/'game/levels/huaguoshan.tscn','''[gd_scene format=3]
[ext_resource type="PackedScene" path="res://data/templates/battle_level_base.tscn" id="base"]
[ext_resource type="Script" path="res://game/levels/Huaguoshan.cs" id="script"]
[ext_resource type="PackedScene" path="res://data/levels/huaguoshan/map.tscn" id="map"]
[ext_resource type="Script" path="res://addons/battle_foundation/level/BattleSpawnBudget.cs" id="budget"]
[ext_resource type="JSON" path="res://data/levels/huaguoshan/audio.json" id="audio"]
[node name="Huaguoshan" instance=ExtResource("base")]
script = ExtResource("script")
level_id = &"花果山"
audio_catalog = ExtResource("audio")
[node name="BattleSession" parent="." index="1"]
scene_manifest_path = "res://data/levels/huaguoshan/manifest.json"
scene_seed = 101
[node name="SpawnBudget" type="Node" parent="BattleSession/LevelInstance"]
script = ExtResource("budget")
maximum_live_monsters = 6
[node name="Actors" parent="BattleSession" instance=ExtResource("map")]
[editable path="BattleSession/Actors"]
''')

def audio():
    from import_stage_thirteen_boss import sound_tags
    sounds=sound_tags(SOURCE/'Music.swf')
    data=json.loads((ROOT/'data/audio/original_audio.json').read_text('utf8'))
    target=ROOT/'assets/audio/zaomeng1/huaguoshan.mp3'
    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(sounds['bg1'])
    data['packs']['zaomeng1_huaguoshan']={'music':'res://assets/audio/zaomeng1/huaguoshan.mp3'}
    data['level_music']={'花果山':'zaomeng1_huaguoshan'};data['music_zones']={'花果山':[]}
    for _,id,base in UNITS.values():
        old={'jianwu':'剑舞','yushoushi':'驭兽使','jushi_lingjun':'巨石灵君'}[base]
        data['units'][id]=data['units'][old]
    dump(MAP/'audio.json',data)
    dump(ROOT/'assets/audio/zaomeng1/source.json', {'source':'Music.swf','symbol':'bg1','sha256':hashlib.sha256(sounds['bg1']).hexdigest()})

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--export',action='store_true');args=parser.parse_args()
    if args.export:export()
    level=json.loads((ROOT/'docs/reference/zaomeng1/levels.json').read_text('utf8'))['levels'][0]
    global REGIONS, SPAWN_X
    # 940px viewport / 0.5 zoom = 1880 world pixels. Keep one combat screen per region;
    # the final region additionally opens the original gateway after its fight.
    REGIONS=[(i*1880, 9660 if i==4 else (i+1)*1880, 240 if i==0 else i*1880+120) for i in range(5)]
    SPAWN_X={}
    for i,(left,right,entry) in enumerate(REGIONS):
        plans=[p for p in level['spawn_plans'] if p['properties']['stopPointIdx']==i]
        lo=min(p['x']*2 for p in plans); hi=max(p['x']*2 for p in plans)
        scale=min(1.0,1520/(hi-lo)) if hi>lo else 1.0
        center=left+940 if hi>lo else left+1260
        for p in plans:
            pid='huaguoshan_birth_'+re.search(r'\d+',p['instance']).group()
            SPAWN_X[pid]=round(center+(p['x']*2-(lo+hi)/2)*scale,4)
    bounds={}
    for log in CACHE.glob('huaguoshan-*-export.log'):
        for cid,x0,x1,y0,y1 in re.findall(r'RENDER_BOUNDS #(\d+) \[RECT x=(-?\d+) to (-?\d+), y=(-?\d+) to (-?\d+)\]',log.read_text('utf8')):
            bounds[int(cid)]=[int(x0),int(x1),int(y0),int(y1)]
    symbols=json.loads((CACHE/'huaguoshan-monsters.json').read_text('utf8'))['symbols']
    for kind in UNITS:
        monster(kind,next(s for s in symbols if s['names']==[f'export.monster.Monster{kind}']),bounds)
    author_attacks();map_scene(level);progression(level);audio();entry_scene()
    dump(MAP/'original_source.json', {'source_build':'zmISAV VTest','source_level':level,'world_scale':2,
         'main_swf_sha256':hashlib.sha256((SOURCE/'打开我开始玩.swf').read_bytes()).hexdigest(),
         'monster_swf_sha256':hashlib.sha256((SOURCE/'Monster_v1.swf').read_bytes()).hexdigest(),
         'spawn_seconds_multiplier':24/30,'maximum_live_monsters':6,'stat_mapping':UNITS,
         'spawn_world_x':SPAWN_X,'arena_adaptation':'Five consecutive 1880px combat views, 180px spawn margin; horizontal order retained, over-wide groups compressed; final gateway available after combat.'})
    print('Authored Huaguoshan: five regions, fourteen plans, thirty-three enemies, three Spine units.')

if __name__=='__main__':main()
