"""Author existing character/monster scenes with the shared, preplaced armor outline."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parent.parent


def attach(path: Path, enabled: bool = True):
    text = path.read_text(encoding="utf-8")
    if 'name="SuperArmorEffect"' in text:
        return
    body = re.search(r'\[node name="SpineVisual"[^\]]*\][^\[]*skeleton_data_res = ExtResource\("([^"]+)"\)', text)
    if body is None:
        raise ValueError(f"No authored SpineVisual in {path}")
    reference = '[ext_resource type="PackedScene" path="res://data/effects/super_armor/outline.tscn" id="armor_outline"]\n'
    text = text.replace('[sub_resource ', reference + '[sub_resource ', 1)
    nodes = '[node name="SuperArmorEffect" parent="." instance=ExtResource("armor_outline")]\n'
    if not enabled:
        nodes += 'enabled = false\n'
    if path.parent.name == 'jushi_lingjun':
        nodes += 'capture_origin = Vector2(256, 384)\n[node name="Capture" parent="SuperArmorEffect" index="1"]\nsize = Vector2i(512, 512)\n'
    nodes += f'[node name="Body" parent="SuperArmorEffect/Capture" index="0"]\nskeleton_data_res = ExtResource("{body[1]}")\n'
    text = text.replace('[node name="SpineVisual"', nodes + '[node name="SpineVisual"', 1)
    text += '\n[editable path="SuperArmorEffect"]\n'
    # Godot 4.7 may save computed load_steps; recalculate when present.
    count = 1 + len(re.findall(r'^\[(?:ext|sub)_resource ', text, re.M))
    text = re.sub(r'load_steps=\d+', f'load_steps={count}', text, count=1)
    path.write_text(text, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference', type=Path)
    args = parser.parse_args()
    sys.path.insert(0, str(args.reference))
    from backends.zmhj_config import load_config_table
    game = args.reference / 'games/zmhj-g5'
    roles = load_config_table(game, 'Role')
    monsters = load_config_table(game, 'Monster')
    files = ['prefabs/scripts/ManEntity.as', 'com/wdcgame/filters/ColorFilterAnimation.as', 'com/wdcgame/utils/ColorUtils.as']
    source = args.reference / 'out/zmhj-equip-skill-diag'
    evidence = {"logic": {name: hashlib.sha256((source / name).read_bytes()).hexdigest() for name in files},
                "colors": ["ff0000", "ffff00"], "blur": [5, 5], "strength": 3,
                "source_fps": 30, "colors_per_direction": 11, "cycle_frames": 22,
                "priority": "wushuang > super_armor; death removes both",
                "note": "ColorFilterAnimation ignores its 0.3 parameter and delta; changeColorto uses truncated integer steps and includes both endpoints.",
                "show_bati_effect": {}}
    paths = [ROOT / 'data/characters/sunwukong/animation/sunwukong_visual.tscn']
    paths += sorted((ROOT / 'data/monsters').glob('*/visual.tscn'))
    for path in paths:
        definition = path.parent.parent / 'definition.tres' if path.parent.name == 'animation' else path.parent / 'definition.tres'
        if path.parent.name == 'animation':
            config = roles['2001']
            name = 'sunwukong'
        else:
            monster_id = re.search(r'metadata/original_monster_id = (\d+)', definition.read_text(encoding='utf-8'))[1]
            config = monsters[monster_id]
            name = path.parent.name
        enabled = config.get('showBatiEff') is not False
        evidence['show_bati_effect'][name] = enabled
        attach(path, enabled)
    (ROOT / 'data/effects/super_armor/original_source.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Authored armor outlines for {len(paths)} saved visuals; source flags={evidence["show_bati_effect"]}')


if __name__ == '__main__':
    main()
