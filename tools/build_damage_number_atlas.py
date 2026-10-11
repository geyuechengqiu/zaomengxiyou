"""Pack original full-size damage glyphs losslessly; preserve spacing and pixel data."""
#region 原图集拼接与AtlasTexture定义
from pathlib import Path
import hashlib
import json
from PIL import Image


def build(project: Path) -> None:
    folder = project / "assets/effects/damage_numbers"
    source = json.loads((folder / "source_mapping.json").read_text(encoding="utf-8"))
    atlas_width = 1024
    padding = 2
    x = y = padding
    row_height = 0
    unique = {}
    placements = []
    images = []
    for record in source["textures"]:
        image = Image.open(folder / record["file"]).convert("RGBA")
        key = (image.size, hashlib.sha256(image.tobytes()).hexdigest())
        if key not in unique:
            w, h = image.size
            if x + w + padding > atlas_width:
                x = padding
                y += row_height + 2 * padding
                row_height = 0
            unique[key] = [x, y, w, h]
            images.append((image, x, y))
            x += w + 2 * padding
            row_height = max(row_height, h)
        placements.append({"file": record["file"], "region": unique[key]})
    atlas_height = y + row_height + padding
    atlas = Image.new("RGBA", (atlas_width, atlas_height))
    for image, x, y in images:
        w, h = image.size
        # 两像素边缘扩展复制原边缘，防止线性过滤串色；没有缩放或裁掉透明边距。
        atlas.paste(image, (x, y))
        atlas.paste(image.crop((0, 0, 1, h)).resize((padding, h)), (x-padding, y))
        atlas.paste(image.crop((w-1, 0, w, h)).resize((padding, h)), (x+w, y))
        atlas.paste(atlas.crop((x-padding, y, x+w+padding, y+1)).resize((w+2*padding, padding)), (x-padding, y-padding))
        atlas.paste(atlas.crop((x-padding, y+h-1, x+w+padding, y+h)).resize((w+2*padding, padding)), (x-padding, y+h))
    for record, placement in zip(source["textures"], placements):
        x, y, w, h = placement["region"]
        assert atlas.crop((x, y, x+w, y+h)).tobytes() == Image.open(folder / record["file"]).convert("RGBA").tobytes()
    atlas.save(folder / "atlas.png")
    resource = ['[gd_resource type="Resource" script_class="BattleDamageNumberLibrary" format=3]',
                '[ext_resource type="Script" path="res://addons/battle_foundation/presentation/BattleDamageNumberLibrary.cs" id="script"]',
                '[ext_resource type="Texture2D" path="res://assets/effects/damage_numbers/atlas.png" id="atlas"]']
    groups = {}
    for index, (record, placement) in enumerate(zip(source["textures"], placements)):
        x, y, w, h = placement["region"]
        resource += [f'[sub_resource type="AtlasTexture" id="t{index}"]', 'atlas = ExtResource("atlas")', f'region = Rect2({x}, {y}, {w}, {h})', 'filter_clip = true']
        groups.setdefault(record["group"], []).append(f'SubResource("t{index}")')
    resource += ['[resource]', 'script = ExtResource("script")', 'groups = Dictionary[String, Array]({']
    resource += [f'"{group}": Array[Texture2D]([{", ".join(textures)}])' + (',' if i+1 < len(groups) else '') for i, (group, textures) in enumerate(groups.items())]
    resource.append('})')
    (project / "data/effects/damage_number_textures.tres").write_text("\n".join(resource) + "\n", encoding="utf-8")
    (folder / "atlas_mapping.json").write_text(json.dumps({"size": [atlas_width, atlas_height], "padding": padding, "unique_images": len(images), "aliases": len(placements), "sha256": hashlib.sha256((folder / "atlas.png").read_bytes()).hexdigest(), "regions": placements}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS damage-number atlas: {len(placements)} original textures, {len(images)} unique images, {atlas_width}x{atlas_height}, every region pixel-identical")
#endregion
#region 工具入口
if __name__ == "__main__":
    build(Path(__file__).resolve().parents[1])
#endregion
