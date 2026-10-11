"""Convert authored original frame clips to Spine 4.3 attachment timelines.

No inferred limb skeletons: retain original pixels, trim offsets and 30fps timing.
The saved Godot scene remains the editable semantic timeline and hitbox owner.
"""
from pathlib import Path
import argparse, hashlib, json, math, re, struct

ROOT = Path(__file__).resolve().parents[1]

#region Parse the source authored scene, retaining per-layer frame registration
def blocks(text, kind):
    return re.findall(r'\[' + kind + r'[^\n]*\]\n.*?(?=\n\[|\Z)', text, re.S)

def prop(block, name, default=None):
    match = re.search(r'^' + re.escape(name) + r' = (.*)$', block, re.M)
    return match.group(1) if match else default

def number_tuple(value):
    return [float(v) for v in value[value.index('(')+1:value.rindex(')')].split(',')]

def track_values(block):
    result = {}
    for index, path in re.findall(r'tracks/(\d+)/path = NodePath\("([^"]+)"\)', block):
        keys = prop(block, f'tracks/{index}/keys')
        times = number_tuple(re.search(r'"times": (PackedFloat32Array\([^)]*\))', keys).group(1))
        values = re.search(r'"values": \[(.*)\]', keys).group(1)
        values = re.findall(r'SubResource\("[^"]+"\)|Vector2\([^)]*\)|true|false|null', values)
        result[path] = list(zip(times, values))
    return result

def sample(keys, time, fallback):
    for key_time, value in reversed(keys):
        if key_time <= time + 1e-7:
            return value
    return fallback

def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf8')
#endregion

#region Exact frame attachments, reusable atlas regions and complete slot reset
def convert(name, force=False):
    folder = ROOT / 'data/monsters' / name
    visual = folder / 'visual.tscn'
    text = visual.read_text('utf8')
    backup = ROOT / 'assets/monsters' / name / 'source_visual.txt'
    if 'animation_player_adapter_2d.gd' not in text:
        if not force:
            print(f'{name}: already Spine; preserved edited visual')
            return
        text = backup.read_text('utf8')
    else:
        write(backup, text)
    resources = {re.search(r'id="([^"]+)"', b).group(1): b for b in blocks(text, 'sub_resource')}
    clips = {key[5:]: value for key, value in resources.items() if key.startswith('Anim_')}
    nodes = {re.search(r'name="([^"]+)"', b).group(1): b for b in blocks(text, 'node')}
    layers = [n for n in ('Body', 'Effect1', 'Effect2') if n in nodes]
    attachments = {layer: {} for layer in layers}
    regions, animations, lengths = {}, {}, {}
    for action, clip in clips.items():
        duration = float(prop(clip, 'length'))
        lengths[action] = duration
        tracks = track_values(clip)
        slot_tracks = {}
        for layer in layers:
            timeline = []
            previous = object()
            for tick in range(round(duration * 30)):
                time = tick / 30
                visible = sample(tracks.get(f'Visual/{layer}:visible', []), time, prop(nodes[layer], 'visible', 'true')) == 'true'
                texture = sample(tracks.get(f'Visual/{layer}:texture', []), time, prop(nodes[layer], 'texture', 'null'))
                attachment_name = None
                if visible and texture != 'null':
                    rid = re.search(r'"([^"]+)"', texture).group(1)
                    resource = resources[rid]
                    x, y, w, h = number_tuple(prop(resource, 'region'))
                    mx, my, _, _ = number_tuple(prop(resource, 'margin', 'Rect2(0,0,0,0)'))
                    px, py = number_tuple(sample(tracks.get(f'Visual/{layer}:position', []), time, prop(nodes[layer], 'position', 'Vector2(0,0)')))
                    region_name = 'region_' + '_'.join(str(int(v)) for v in (x,y,w,h))
                    regions[region_name] = [int(v) for v in (x,y,w,h)]
                    center = (px + mx + w/2, -(py + my + h/2))
                    attachment_name = rid + '_' + hashlib.sha256(str(center).encode()).hexdigest()[:8]
                    attachments[layer][attachment_name] = {'type': 'region', 'path': region_name, 'x': center[0], 'y': center[1], 'width': w, 'height': h}
                if attachment_name != previous:
                    timeline.append({'time': round(time,9), 'name': attachment_name})
                    previous = attachment_name
            slot_tracks[layer] = {'attachment': timeline}
        # An explicit endpoint keeps the last image for its full original frame.
        animations[action] = {'slots': slot_tracks, 'bones': {'root': {'translate': [{'time': duration, 'x': 0, 'y': 0}]}}}
    asset = ROOT / 'assets/monsters' / name
    image = asset / 'atlas.png'
    width, height = struct.unpack('>II', image.read_bytes()[16:24])
    atlas = f'atlas.png\nsize:{width},{height}\nfilter:Linear,Linear\npma:false\n'
    for region, (x,y,w,h) in regions.items():
        atlas += f'{region}\nbounds:{x},{y},{w},{h}\n'
    write(asset/'monster.atlas', atlas)
    skeleton = {'skeleton': {'spine': '4.3.00', 'fps': 30, 'images': './'}, 'bones': [{'name':'root'}] + [{'name':layer,'parent':'root'} for layer in layers],
        'slots': [{'name':layer,'bone':layer} for layer in layers], 'skins': [{'name':'基础','attachments':attachments}], 'animations': animations}
    write(asset/'monster.spine-json', json.dumps(skeleton, ensure_ascii=False, separators=(',',':'))+'\n')
    write(asset/'spinedata.tres', f'''[gd_resource type="SpineSkeletonDataResource" format=3]
[ext_resource type="SpineAtlasResource" path="res://assets/monsters/{name}/monster.atlas" id="atlas"]
[ext_resource type="SpineSkeletonFileResource" path="res://assets/monsters/{name}/monster.spine-json" id="skeleton"]
[resource]
atlas_res = ExtResource("atlas")
skeleton_file_res = ExtResource("skeleton")
''')
    # BuildAnimator的保护动作只播放一次；不能继承旧临时场景的循环标记。
    looped = [a for a,c in clips.items() if a != 'protect' and prop(c, 'loop_mode','0') != '0']
    write(folder/'animation.tres', f'''[gd_resource type="Resource" script_class="CharacterAnimationProfile" format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/animation/CharacterAnimationProfile.cs" id="script"]
[ext_resource type="SpineSkeletonDataResource" path="res://assets/monsters/{name}/spinedata.tres" id="skeleton"]
[resource]
script = ExtResource("script")
skeleton_data = ExtResource("skeleton")
source_fps = 30.0
display_scale = 2.0
animations = Dictionary[StringName, StringName]({{{', '.join(f'&"{a}": &"{a}"' for a in clips)}}})
looping_actions = Array[StringName]([{', '.join(f'&"{a}"' for a in looped)}])
socket_bones = Dictionary[StringName, StringName]({{&"root": &"root"}})
''')
    build_visual(folder, name, text, clips, lengths, looped, nodes)
    write(asset/'spine_conversion.json', json.dumps({'source_scene_sha256':hashlib.sha256(text.encode()).hexdigest(), 'source_atlas_sha256':hashlib.sha256(image.read_bytes()).hexdigest(), 'format':'Spine 4.3 attachment timelines', 'fps':30,'actions':lengths,'layers':layers,'regions':len(regions)}, ensure_ascii=False,indent=2)+'\n')
    print(f'{name}: {len(clips)} Spine actions, {len(regions)} atlas regions')
#endregion

#region Saved native and semantic AnimationPlayers; preserve shared hitbox and glow
def build_visual(folder, name, source, clips, lengths, looped, nodes):
    refs = '\n'.join(blocks(source, 'ext_resource'))
    refs = refs.replace('animation_player_adapter_2d.gd','spine_animation_adapter.gd')
    refs = re.sub(r'\[ext_resource type="Texture2D"[^\n]*\]\n?', '', refs)
    refs += f'\n[ext_resource type="SpineSkeletonDataResource" path="res://assets/monsters/{name}/spinedata.tres" id="spine"]\n'
    text = '[gd_scene format=3]\n'+refs
    native_ids, master_ids = [], []
    for action, duration in lengths.items():
        for loop in (False, True):
            clip_name = action + ('_looped' if loop else '')
            native_ids.append(f'&"{clip_name}": SubResource("Native_{clip_name}")')
            text += f'[sub_resource type="Animation" id="Native_{clip_name}"]\nlength = {duration}\n'
            for index, (path,value) in enumerate([('.:animation_name',json.dumps(action)),('.:loop','true' if loop else 'false')]):
                text += f'tracks/{index}/type = "value"\ntracks/{index}/path = NodePath("{path}")\ntracks/{index}/keys = {{"times": PackedFloat32Array(0), "transitions": PackedFloat32Array(1), "update": 1, "values": [{value}]}}\n'
        master_ids.append(f'&"{action}": SubResource("Master_{action}")')
        text += f'[sub_resource type="Animation" id="Master_{action}"]\nlength = {duration}\nloop_mode = {1 if action in looped else 0}\n'
        text += f'tracks/0/type = "animation"\ntracks/0/path = NodePath("SpineVisual/SpineAnimationTrack/SpineVisual Track 0")\ntracks/0/keys = {{"times": PackedFloat32Array(0), "clips": PackedStringArray("{action + ("_looped" if action in looped else "")}")}}\n'
        text += f'tracks/1/type = "value"\ntracks/1/path = NodePath("AttackHitbox:preview_action")\ntracks/1/keys = {{"times": PackedFloat32Array(0), "transitions": PackedFloat32Array(1), "update": 1, "values": [&"{action}"]}}\n'
        text += f'tracks/2/type = "value"\ntracks/2/path = NodePath("AttackHitbox:preview_time")\ntracks/2/keys = {{"times": PackedFloat32Array(0,{duration}), "transitions": PackedFloat32Array(1,1), "update": 0, "values": [0.0,{duration}]}}\n'
        if 'ProtectGlow' in nodes:
            glow = sample(track_values(clips[action]).get('Visual/ProtectGlow:visible',[]),0,'false')
            if name == 'jushi_lingjun': glow = 'false'
            text += f'tracks/3/type = "value"\ntracks/3/path = NodePath("Visual/ProtectGlow:visible")\ntracks/3/keys = {{"times": PackedFloat32Array(0), "transitions": PackedFloat32Array(1), "update": 1, "values": [{glow}]}}\n'
    text += '[sub_resource type="AnimationLibrary" id="NativeLibrary"]\n_data = {'+', '.join(native_ids)+'}\n'
    text += '[sub_resource type="AnimationLibrary" id="MasterLibrary"]\n_data = {'+', '.join(master_ids)+'}\n'
    text += '\n'.join(b for b in blocks(source, 'sub_resource') if 'type="RectangleShape2D"' in b)+'\n'
    text += '''[node name="AnimationAdapter" type="Node2D"]
script = ExtResource("adapter")
profile = ExtResource("profile")
[node name="SpineVisual" type="SpineSprite" parent="."]
scale = Vector2(2,2)
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
'''
    if 'ProtectGlow' in nodes:
        text += '[node name="Visual" type="Node2D" parent="."]\nscale = Vector2(2,2)\n'+nodes['ProtectGlow']+'\n'
    text += nodes['AttackHitbox']+'\n'
    text += next(b for b in blocks(source,'node') if 'parent="AttackHitbox"' in b)+'\n'
    write(folder/'visual.tscn', text.rstrip()+'\n')
    from author_super_armor_effects import attach
    attach(folder/'visual.tscn')
#endregion

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--force', action='store_true', help='Rebuild from saved source scene; overwrites edited Spine visual')
    args = parser.parse_args()
    for name in ('jianwu','yushoushi','revival_vessel','jushi_lingjun'):
        convert(name, args.force)
