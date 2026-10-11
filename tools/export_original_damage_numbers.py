"""Copy verified original glyphs and author a runtime scene and shared atlas, without running Flash."""
#region 原版素材校验与可重现导出
from pathlib import Path
from io import BytesIO
import hashlib
import json
import shutil
import sys
import zlib

from PIL import Image

sys.dont_write_bytecode = True
source_root = Path(sys.argv[1]).resolve()
project = Path(__file__).resolve().parents[1]
source_export = source_root / "exports/zmhj_damage_number_images"
manifest = json.loads((source_export / "manifest.json").read_text(encoding="utf-8"))
packed = (source_root / manifest["source"]).read_bytes()
assert hashlib.sha256(packed).hexdigest() == manifest["source_sha256"]
sys.path.insert(0, str(source_root))
from backends.zmhj_config import _Amf3Reader, _read_one

reader = _Amf3Reader(packed)
header = reader.read()
atlases = {}
for _ in range(header["fn"]):
    entry = _read_one(zlib.decompress(reader.read(), -15))
    if entry["extension"] == "png":
        atlases[entry["prefixName"]] = Image.open(BytesIO(zlib.decompress(entry["data"]))).convert("RGBA")
assert reader.pos == len(packed)
output = project / "assets/effects/damage_numbers"
output.mkdir(parents=True, exist_ok=True)
groups = {}
records = []
resource = ['[gd_resource type="Resource" script_class="BattleDamageNumberLibrary" format=3]',
            '[ext_resource type="Script" path="res://addons/battle_foundation/presentation/BattleDamageNumberLibrary.cs" id="script"]']
for index, row in enumerate(manifest["textures"]):
    relative = Path(row["group"]) / (row["name"] + ".png")
    original = source_export / row["files"]["restored"]
    with Image.open(original) as image:
        assert list(image.size) == row["restored_size"] and image.getchannel("A").getbbox()
        fields = row["atlas_fields"]
        x, y, w, h = [int(fields[key]) for key in ["x", "y", "width", "height"]]
        expected = Image.new("RGBA", tuple(row["restored_size"]))
        expected.paste(atlases[row["source_atlas"]].crop((x, y, x + w, y + h)),
                       (-int(fields.get("frameX", 0)), -int(fields.get("frameY", 0))))
        assert image.convert("RGBA").tobytes() == expected.tobytes(), row["name"] + " differs from original atlas pixels"
    destination = output / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(original, destination)
    resource.append(f'[ext_resource type="Texture2D" path="res://assets/effects/damage_numbers/{relative.as_posix()}" id="t{index}"]')
    groups.setdefault(row["group"], []).append(f'ExtResource("t{index}")')
    records.append({**row, "file": relative.as_posix(), "sha256": hashlib.sha256(destination.read_bytes()).hexdigest()})
resource += ['[resource]', 'script = ExtResource("script")', 'groups = Dictionary[String, Array]({']
resource += [f'"{group}": Array[Texture2D]([{", ".join(textures)}])' + (',' if i + 1 < len(groups) else '')
             for i, (group, textures) in enumerate(groups.items())]
resource.append('})')
(project / "data/effects/damage_number_textures.tres").write_text("\n".join(resource) + "\n", encoding="utf-8")
sources = ["viewers/component/NewBleedNumber.as", "viewers/component/NewBaoJiNumber.as",
           "viewers/component/NewRealBaoJiNumber.as", "viewers/component/NewSanbiNumber.as",
           "viewers/container/layers/BattleTopLayer.as", "prefabs/controls/DamageControl.as",
           "com/wdcgame/engine/display/Image.as"]
evidence = [{"path": "out/zmhj-equip-skill-diag/" + path,
             "sha256": hashlib.sha256((source_root / "out/zmhj-equip-skill-diag" / path).read_bytes()).hexdigest()}
            for path in sources]
mapping = {"source": manifest["source"], "source_sha256": manifest["source_sha256"],
           "glyph_count": len(records), "groups": manifest["groups"], "textures": records,
           "evidence": evidence, "fps": 30, "duration": 0.9, "rotation": 0,
           "spacing": -2, "image_anchor": "Bitmap top-left; Texture.pivot unused by original Image",
           "normal_offset": {"x": [0, 0], "y": [-60, -60]},
           "dodge_offset": {"x": [0, 20], "y": [-80, -60]},
           "default_bleed_offset_screen": [0, -60],
           "true_extra_offset_screen": {"x": [-60, 60], "y": [-40, -10]}}
(output / "source_mapping.json").write_text(json.dumps(mapping, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
#endregion
#region Tween跳字运行场景
# 导出只生成贴图库与Tween运行场景，不创建采样动画或预览播放器。
scene = ['[gd_scene format=3]',
         '[ext_resource type="Script" path="res://addons/battle_foundation/presentation/battle_damage_number_2d.gd" id="script"]',
         '[ext_resource type="Script" path="res://addons/battle_foundation/presentation/battle_damage_number_glyphs.gd" id="glyphs"]',
         '[ext_resource type="Resource" path="res://data/effects/damage_number_textures.tres" id="library_resource"]',
         '[node name="DamageNumber" type="Node2D"]', 'script = ExtResource("script")',
         '[node name="Glyphs" type="Node2D" parent="."]', 'script = ExtResource("glyphs")', 'library = ExtResource("library_resource")']
(project / "data/effects/damage_number.tscn").write_text("\n".join(scene) + "\n", encoding="utf-8")
from build_damage_number_atlas import build
from export_supply_numbers import export as export_supply_numbers
export_supply_numbers()
build(project)
print(f'Exported {len(records)} verified original glyphs in {len(groups)} groups; Tween-only damage-number scene')
#endregion
