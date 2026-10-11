"""Export the original Pipa Buff AMF and mission bossComing clip, without changing source files."""
from pathlib import Path
import hashlib, json, re, subprocess, sys, zlib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.cleanup-backup/python-packages'))
from PIL import Image

#region Read original assets and author AnimationPlayer clips
def author(folder, texture, frames, loop=False, scale=1):
    refs = '[gd_scene format=3]\n[ext_resource type="Script" path="res://addons/battle_foundation/presentation/battle_original_effect_clip_2d.gd" id="script"]\n'
    refs += f'[ext_resource type="Texture2D" path="res://{texture}" id="atlas"]\n'
    values, positions = [], []
    for i, (rect, pos) in enumerate(frames):
        if rect is None:
            values.append('null')
        else:
            refs += f'[sub_resource type="AtlasTexture" id="Frame{i}"]\natlas = ExtResource("atlas")\nregion = Rect2({", ".join(map(str, rect))})\nfilter_clip = true\n'
            values.append(f'SubResource("Frame{i}")')
        positions.append(f'Vector2({pos[0]}, {pos[1]})')
    duration = len(frames)/30
    refs += f'[sub_resource type="Animation" id="Clip"]\nlength = {duration}\nloop_mode = {1 if loop else 0}\n'
    for i, (field, keys) in enumerate([('texture', values), ('position', positions)]):
        refs += f'tracks/{i}/type = "value"\ntracks/{i}/path = NodePath("Sprite2D:{field}")\ntracks/{i}/keys = {{"times": PackedFloat32Array({", ".join(str(n/30) for n in range(len(frames)))}), "transitions": PackedFloat32Array({", ".join("1" for _ in frames)}), "update": 1, "values": [{", ".join(keys)}]}}\n'
    refs += '[sub_resource type="AnimationLibrary" id="Library"]\n_data = {&"play": SubResource("Clip")}\n'
    refs += f'[node name="OriginalEffect" type="Node2D"]\nvisible = false\nscale = Vector2({scale}, {scale})\nscript = ExtResource("script")\n[node name="Sprite2D" type="Sprite2D" parent="."]\ncentered = false\n[node name="AnimationPlayer" type="AnimationPlayer" parent="."]\nlibraries/ = SubResource("Library")\n'
    target = ROOT / folder
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(refs, encoding='utf8')
    return duration

def main(original):
    sys.path.insert(0, str(original))
    from backends.zmhj_config import _Amf3Reader, _read_one
    source = original/'games/zmhj-g5/cache/assets/buff/5004.swf'
    reader = _Amf3Reader(source.read_bytes())
    header = reader.read()
    entries = [_read_one(zlib.decompress(reader.read(), -15)) for _ in range(header['fn'])]
    folder = ROOT/'assets/monsters/revival_vessel/buff'
    folder.mkdir(parents=True, exist_ok=True)
    data = {e['extension']: zlib.decompress(e['data']) for e in entries}
    (folder/'5004.png').write_bytes(data['png'])
    (folder/'5004.xml').write_bytes(data['xml'])
    rows = ET.fromstring(data['xml'])
    frames = []
    pivot = (0,0)
    for row in rows:
        a = row.attrib
        if 'pivotX' in a: pivot = (float(a['pivotX']), float(a['pivotY']))
        x,y,w,h = [float(a[k]) for k in ('x','y','width','height')]
        fx,fy = [float(a.get(k,0)) if float(a.get('frameWidth',0)) > 0 else 0 for k in ('frameX','frameY')]
        frames.append(([x,y,w,h] if w > 0 and h > 0 else None, (-pivot[0]-fx,-pivot[1]-fy)))
    buff_seconds = author('data/monsters/revival_vessel/healing_visual.tscn', 'assets/monsters/revival_vessel/buff/5004.png', frames, True, 2)
    mission = original/'games/zmhj-g5/cache/assets/ui/mission_20260406_1.swf'
    output = ROOT/'.cleanup-backup/pipa-boss-export'
    result = subprocess.run(['java','-Djava.awt.headless=true','-Dfile.encoding=UTF-8','-cp',str(original/'out/swfutil/ffdec_lib_20.1.0/*'), str(ROOT/'tools/ExportOriginalBattleUI.java'),str(mission),str(output),'bossComing'], capture_output=True,encoding='utf8',check=True)
    output.mkdir(parents=True,exist_ok=True)
    (output/'layout.txt').write_text(result.stdout,encoding='utf8')
    match = re.search(r'bounds=\[RECT x=(-?\d+) to (-?\d+), y=(-?\d+) to (-?\d+)\]', result.stdout)
    if not match: raise RuntimeError('bossComing registration not found')
    origin = (int(match[1])/20,int(match[3])/20)
    images = sorted((output/'bossComing').rglob('*.png'),key=lambda p:int(p.stem))
    if not images: raise RuntimeError('bossComing export empty')
    packed, crops, cursor_x, cursor_y, shelf_h = [], [], 0, 0, 0
    for path in images:
        im = Image.open(path).convert('RGBA'); box = im.getbbox()
        if box is None:
            packed.append((None, origin)); continue
        crop = im.crop(box); w,h = crop.size
        if cursor_x+w > 2048:
            cursor_y += shelf_h+2; cursor_x=0; shelf_h=0
        packed.append(([cursor_x,cursor_y,w,h], (origin[0]+box[0],origin[1]+box[1])))
        crops.append((crop,(cursor_x,cursor_y)))
        cursor_x += w+2; shelf_h=max(shelf_h,h)
    atlas = Image.new('RGBA',(2048,cursor_y+shelf_h+2))
    for crop, pos in crops: atlas.paste(crop,pos)
    target = ROOT/'assets/ui/boss/boss_coming.png'; atlas.save(target)
    seconds = author('data/effects/boss_coming.tscn','assets/ui/boss/boss_coming.png', packed)
    evidence = {'fps':30,'buff_frames':len(frames),'buff_loop_seconds':buff_seconds,'boss_frames':len(packed),'boss_seconds':seconds,'boss_origin':origin,'sources':[{'path':str(p.relative_to(original)).replace('\\','/'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in [source,mission]],'buff':json.loads((original/'exports/zmhj_role_stats/原始配置/Buff.json').read_text('utf8'))['5000401']}
    (ROOT/'data/monsters/revival_vessel/original_healing.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps({k:v for k,v in evidence.items() if k not in ['sources','buff']},ensure_ascii=False))
#endregion
if __name__ == '__main__': main(Path(sys.argv[1]).resolve())
