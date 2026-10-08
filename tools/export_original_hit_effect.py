"""从本地原版 mission2 图集只读导出普通受击特效，不执行 Flash。"""
#region 图集、注册点与来源导出
from io import BytesIO
from pathlib import Path
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET
import zlib

from PIL import Image

sys.dont_write_bytecode = True
source_root = Path(sys.argv[1]).resolve()
project = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(source_root))
from backends.zmhj_config import _Amf3Reader, _read_one, load_config_table

source_path = "games/zmhj-g5/cache/assets/ui/mission2_20250707_1.swf"
packed = (source_root / source_path).read_bytes()
reader = _Amf3Reader(packed)
header = reader.read()
atlases = {}
for _ in range(header["fn"]):
    entry = _read_one(zlib.decompress(reader.read(), -15))
    atlases.setdefault(entry["prefixName"], {})[entry["extension"]] = zlib.decompress(entry["data"])
assert reader.pos == len(packed), "Unread atlas data"
output = project / "assets/effects/hurt_effect_all"
output.mkdir(parents=True, exist_ok=True)
frames = []
for prefix, files in atlases.items():
    atlas = Image.open(BytesIO(files["png"])).convert("RGBA")
    pivot = (0.0, 0.0)
    for element in ET.fromstring(files["xml"]).findall("SubTexture"):
        data = dict(element.attrib)
        if "pivotX" in data:
            pivot = (float(data["pivotX"]), float(data.get("pivotY", 0)))
        if not re.fullmatch(r"hurtEffectAll\d{4}", data["name"]):
            continue
        assert data.get("rotated", "false") in ("false", "0")
        x, y, w, h = [int(data[key]) for key in ("x", "y", "width", "height")]
        fw, fh = int(data.get("frameWidth", w)), int(data.get("frameHeight", h))
        fx, fy = int(data.get("frameX", 0)), int(data.get("frameY", 0))
        assert fw > 0 and fh > 0 and min(x, y, w, h) >= 0
        assert x + w <= atlas.width and y + h <= atlas.height
        assert w - fx <= fw and h - fy <= fh
        # 最后一帧是原版透明占位帧，保留其时长，不能因 width=0 删除。
        image = Image.new("RGBA", (fw, fh))
        if w and h:
            image.paste(atlas.crop((x, y, x + w, y + h)), (-fx, -fy))
        name = data["name"] + ".png"
        image.save(output / name)
        frames.append({"name": data["name"], "file": name, "atlas": prefix,
                       "region": [x, y, w, h], "trim": [fx, fy, fw, fh],
                       "pivot": list(pivot), "empty": image.getchannel("A").getbbox() is None,
                       "sha256": hashlib.sha256((output / name).read_bytes()).hexdigest()})
frames.sort(key=lambda frame: frame["name"])
assert len(frames) == 11 and frames[-1]["empty"] and not any(f["empty"] for f in frames[:-1])
assert all(f["pivot"] == [72.0, 73.0] and f["trim"][2:] == [151, 150] for f in frames)

roles = load_config_table(source_root / "games/zmhj-g5", "Role")
role = roles.get("2001", roles.get(2001))
skills = load_config_table(source_root / "games/zmhj-g5", "Skill")
skill = skills.get("1001010", skills.get(1001010))
evidence_paths = ["games/zmhj-g5/game.json", "out/zmhj-equip-skill-diag/Game.as",
                  "out/zmhj-equip-skill-diag/viewers/component/HurtEffect.as",
                  "out/zmhj-equip-skill-diag/models/managers/ModelManager.as",
                  "out/zmhj-equip-skill-diag/prefabs/scripts/ManEntity.as",
                  "out/zmhj-equip-skill-diag/prefabs/controls/DamageControl.as",
                  "out/zmhj-equip-skill-diag/com/wdcgame/engine/model/SkillParam.as",
                  "out/zmhj-equip-skill-diag/com/wdcgame/engine/textures/TextureAtlas.as"]
evidence = [{"path": p, "sha256": hashlib.sha256((source_root / p).read_bytes()).hexdigest()}
            for p in evidence_paths]
manifest = {"source_project": "Speculum-4399-master", "source_path": source_path,
            "source_sha256": hashlib.sha256(packed).hexdigest(), "symbol": "hurtEffectAll",
            "fps": 30, "loop": False, "frame_count": len(frames),
            "duration": len(frames) / 30, "canvas": [151, 150], "pivot": [72, 73],
            "viewport": [940, 590], "source_role_id": "2001",
            "role_hit_offset": role["hitEffOffset"], "source_skill_id": "1001010",
            "skill_has_hit_effect": skill.get("hasHitEffect", True), "frames": frames, "evidence": evidence}
(output / "source_mapping.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
#endregion
#region 生成可编辑 AnimationPlayer 场景
lines = ['[gd_scene format=3]',
         '[ext_resource type="Script" path="res://addons/battle_foundation/presentation/battle_hit_effect_2d.gd" id="script"]']
for i, frame in enumerate(frames):
    lines.append(f'[ext_resource type="Texture2D" path="res://assets/effects/hurt_effect_all/{frame["file"]}" id="f{i}"]')
times = ", ".join(f"{i / 30:.10f}" for i in range(len(frames)))
textures = ", ".join(f'ExtResource("f{i}")' for i in range(len(frames)))
lines += ['[sub_resource type="Animation" id="hit"]', f'length = {len(frames) / 30:.10f}',
          'step = 0.0333333333', 'tracks/0/type = "value"',
          'tracks/0/path = NodePath("Sprite2D:texture")',
          f'tracks/0/keys = {{"times": PackedFloat32Array({times}), "transitions": PackedFloat32Array({", ".join(["1"] * len(frames))}), "update": 1, "values": [{textures}]}}',
          '[sub_resource type="AnimationLibrary" id="library"]', '_data = {&"hit": SubResource("hit")}',
          '[node name="HitEffect" type="Node2D"]', 'visible = false', 'position = Vector2(0, -120)',
          'z_index = 5', 'script = ExtResource("script")',
          '[node name="Sprite2D" type="Sprite2D" parent="."]', 'scale = Vector2(2, 2)',
          'texture = ExtResource("f0")', 'centered = false', 'offset = Vector2(-72, -73)',
          '[node name="AnimationPlayer" type="AnimationPlayer" parent="."]',
          'libraries/ = SubResource("library")', 'callback_mode_process = 2']
scene = project / "data/effects/hurt_effect_all.tscn"
scene.parent.mkdir(parents=True, exist_ok=True)
scene.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f'Exported {len(frames)} original frames, 30 fps, pivot (72,73), including transparent final frame')
#endregion
