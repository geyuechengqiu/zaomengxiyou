"""只读解包原版攻击素材的 ABRects，供连击资源导入与来源审计。"""
#region 原版 AMF3 解包与独立碰撞数据快照
import hashlib
import json
import lzma
from pathlib import Path
import sys

sys.dont_write_bytecode = True
source = Path(sys.argv[1]).resolve()
sys.path.insert(0, str(source))
from backends.zmhj_config import _read_one

relative = 'games/zmhj-g5/cache/assets/man/2001/attackV427.swf'
packed = (source / relative).read_bytes()
data = _read_one(lzma.decompress(packed[4:], format=lzma.FORMAT_ALONE))
rects = []
for item in data['abs']:
    if item['name'] in [f'ab_attack{i}0000' for i in range(1, 6)]:
        assert item.get('polyPoints') is None
        rects.append({'name': item['name'], 'rect': [item[k] for k in ('x', 'y', 'width', 'height')]})
assert len(rects) == 5
snapshot = {
    'source_path': relative,
    'sha256': hashlib.sha256(packed).hexdigest(),
    'rectangles': rects,
    'coordinate_policy': 'source foot origin; positive scale changes geometry; negative display scale does not mirror ABRect; parent direction mirrors rect and offset',
}
target = Path(__file__).resolve().parents[1] / 'data/battle2d/attack_hitboxes_source.json'
target.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Extracted {len(rects)} original ABRects -> {target}')
#endregion
