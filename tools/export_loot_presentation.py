"""Read original mission2 AMF atlas; export ground quality backgrounds and source pivots."""
from pathlib import Path
from io import BytesIO
import hashlib, json, re, sys, zlib
import xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'.cleanup-backup/python-packages'))
sys.path.insert(0, 'D:/UserData/Downloads/game/Speculum-4399-master')
from PIL import Image
from backends.zmhj_config import _Amf3Reader, _read_one

#region Exact atlas frames; qualitybg is a quality selector, not a looping animation
original = Path('D:/UserData/Downloads/game/Speculum-4399-master')
source_path = 'games/zmhj-g5/cache/assets/ui/mission2_20250707_1.swf'
packed = (original/source_path).read_bytes()
reader = _Amf3Reader(packed)
header = reader.read()
atlases = {}
for _ in range(header['fn']):
    entry = _read_one(zlib.decompress(reader.read(), -15))
    atlases.setdefault(entry['prefixName'], {})[entry['extension']] = zlib.decompress(entry['data'])
assert reader.pos == len(packed)
output = ROOT/'assets/effects/loot_quality'; output.mkdir(parents=True, exist_ok=True)
frames = []
for prefix, files in atlases.items():
    atlas = Image.open(BytesIO(files['png'])).convert('RGBA')
    pivot = (0.0, 0.0)
    for node in ET.fromstring(files['xml']).findall('SubTexture'):
        attrs = dict(node.attrib)
        if 'pivotX' in attrs: pivot = (float(attrs['pivotX']), float(attrs.get('pivotY', 0)))
        match = re.fullmatch(r'qualitybg(\d{4})', attrs['name'])
        if not match: continue
        assert attrs.get('rotated', 'false') in ('false', '0')
        x,y,w,h = [int(attrs[k]) for k in ('x','y','width','height')]
        fw,fh = int(attrs.get('frameWidth', w)),int(attrs.get('frameHeight', h))
        fx,fy = int(attrs.get('frameX', 0)),int(attrs.get('frameY', 0))
        assert min(x,y,w,h) >= 0 and x+w <= atlas.width and y+h <= atlas.height
        image = Image.new('RGBA', (fw,fh))
        if w and h: image.paste(atlas.crop((x,y,x+w,y+h)), (-fx,-fy))
        name = attrs['name']+'.png'; image.save(output/name)
        frames.append({'index':int(match[1]), 'file':name, 'pivot':list(pivot), 'canvas':[fw,fh], 'region':[x,y,w,h], 'trim':[fx,fy], 'atlas':prefix, 'sha256':hashlib.sha256((output/name).read_bytes()).hexdigest()})
frames.sort(key=lambda frame:frame['index'])
assert frames and [frame['index'] for frame in frames] == list(range(len(frames)))
(output/'source_mapping.json').write_text(json.dumps({'source':source_path,'source_sha256':hashlib.sha256(packed).hexdigest(),'frames':frames,'logic':['DropDownEntity.Awake: qualitybg[quality] behind icon1','FlyItemEntity.FlyTo: distance/200, Cubic.easeOut, collinear midpoint','UIBattleLayer.getBagPos: btn_bb.localToGlobal(27,29)']}, ensure_ascii=False, indent=2)+'\n', 'utf8')
path = ROOT/'game/levels/biyujing.tscn'; text = path.read_text('utf8')
text = re.sub(r'^\[ext_resource[^\n]*id="loot_glow_\d+"\]\n', '', text, flags=re.M)
text = re.sub(r'^(?:quality_glows|quality_glow_pivots) = .*\n', '', text, flags=re.M)
pos = text.index('[node ')
resources = ''.join(f'[ext_resource type="Texture2D" path="res://assets/effects/loot_quality/{frame["file"]}" id="loot_glow_{i}"]\n' for i,frame in enumerate(frames))
text = text[:pos]+resources+text[pos:]
pos = text.index('spirit_texture = ExtResource("soul_texture")')+len('spirit_texture = ExtResource("soul_texture")')
refs = ', '.join(f'ExtResource("loot_glow_{i}")' for i in range(len(frames)))
pivots = ', '.join(f'Vector2({-f["pivot"][0]}, {-f["pivot"][1]})' for f in frames)
text = text[:pos]+f'\nquality_glows = Array[Texture2D]([{refs}])\nquality_glow_pivots = Array[Vector2]([{pivots}])'+text[pos:]
path.write_text(text, 'utf8')
print('Exported', len(frames), 'original quality backgrounds with source pivots')
#endregion
