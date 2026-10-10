"""Append original blue MP recovery glyphs to the existing shared damage-number atlas."""
from pathlib import Path
from io import BytesIO
import hashlib, json, re, sys, zlib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / '.cleanup-backup/python-packages'))
sys.path.insert(0, 'D:/UserData/Downloads/game/Speculum-4399-master')
from PIL import Image
from backends.zmhj_config import _Amf3Reader, _read_one

#region Original MP frames, trim registration and lossless atlas update
def export():
    folder = ROOT / 'assets/effects/damage_numbers'
    mapping_path = folder / 'source_mapping.json'
    mapping = json.loads(mapping_path.read_text('utf8'))
    packed = (Path('D:/UserData/Downloads/game/Speculum-4399-master') / mapping['source']).read_bytes()
    assert hashlib.sha256(packed).hexdigest() == mapping['source_sha256']
    reader = _Amf3Reader(packed)
    header = reader.read()
    atlases = {}
    for _ in range(header['fn']):
        entry = _read_one(zlib.decompress(reader.read(), -15))
        atlases.setdefault(entry['prefixName'], {})[entry['extension']] = zlib.decompress(entry['data'])
    rows = []
    for prefix, files in atlases.items():
        atlas = Image.open(BytesIO(files['png'])).convert('RGBA')
        for node in ET.fromstring(files['xml']).findall('SubTexture'):
            fields = dict(node.attrib)
            match = re.fullmatch(r'mpNumberAdd(\d{4})', fields['name'])
            if not match: continue
            x,y,w,h = [int(fields[k]) for k in ('x','y','width','height')]
            fw,fh = int(fields.get('frameWidth',w)),int(fields.get('frameHeight',h))
            image = Image.new('RGBA',(fw,fh))
            image.paste(atlas.crop((x,y,x+w,y+h)),(-int(fields.get('frameX',0)),-int(fields.get('frameY',0))))
            relative = 'mpNumberAdd/' + fields['name'] + '.png'
            target = folder / relative
            target.parent.mkdir(parents=True,exist_ok=True)
            image.save(target)
            rows.append({'group':'mpNumberAdd','name':fields['name'],'file':relative,'atlas_fields':fields,
                         'source_atlas':prefix,'restored_size':[fw,fh],'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
    rows.sort(key=lambda row:row['name'])
    assert len(rows) == 10
    mapping['textures'] = [row for row in mapping['textures'] if row['group'] != 'mpNumberAdd'] + rows
    mapping['groups']['mpNumberAdd'] = {'label':'魔法恢复','count':10}
    mapping['glyph_count'] = len(mapping['textures'])
    mapping_path.write_text(json.dumps(mapping,ensure_ascii=False,indent=2)+'\n','utf8')
    print('Exported 10 original MP recovery glyphs')

if __name__ == '__main__':
    export()
    from build_damage_number_atlas import build
    build(ROOT)
#endregion
