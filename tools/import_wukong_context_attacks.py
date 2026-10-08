"""Append original run/jump attacks without replacing authored combo or visual tracks."""
#region 原版配置与素材数据
import hashlib
import json
import lzma
from pathlib import Path
import re
import sys


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main(source: Path):
    project = Path(__file__).resolve().parents[1]
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(source))
    from backends.zmhj_config import _read_one
    config_path = "exports/zmhj_role_stats/原始配置/Skill.json"
    config = json.loads((source / config_path).read_text(encoding="utf-8-sig"))
    swf_path = "games/zmhj-g5/cache/assets/man/2001/attackV427.swf"
    packed = (source / swf_path).read_bytes()
    collision = _read_one(lzma.decompress(packed[4:], format=lzma.FORMAT_ALONE))
    rects = {a['name']: [a[k] for k in ('x', 'y', 'width', 'height')] for a in collision['abs'] if a.get('polyPoints') is None}
    skeleton_path = "exports/character_2001_wukong_placeholders/dragonbones56/1_V427/1_V427_ske.json"
    skeleton = json.loads((source / skeleton_path).read_text(encoding="utf-8-sig"))
    frames = {a['name']: a['duration'] for a in skeleton['armature'][0]['animation']}
    records = []
    for label, source_id, native, trigger, end in [('run', 1001060, 'runAttack', 3, 12), ('jump', 1001070, 'jumpAttack', 5, 12)]:
        skill = config[str(source_id)]
        id = f"sunwukong_{label}_attack"
        action = f"{label}_attack"
        rect = rects[f'ab_{native}0000']
        _write_skill(project, label, id, action, native, skill, frames[native], trigger, end, rect)
        records.append({'id': id, 'action': action, 'source_skill_id': source_id, 'source_action': native, 'duration_frames': frames[native], 'hit_start_frame': trigger, 'hit_end_frame': end, 'damage_multiplier': skill['skillDefault'], 'hit_rect': rect, 'original_definition': skill})
        _append_visual(project, action, native, frames[native], trigger, end)
    mapping = {'source_fps': 30, 'steps': records, 'turn_window': {'action': 'attack_4', 'frames': [8, 16], 'policy': 'project-defined half-open window; one reverse pressed edge per cast, motion keeps startup direction'}, 'sources': [{'path': path, 'sha256': hashlib.sha256((source / path).read_bytes()).hexdigest()} for path in [config_path, swf_path, skeleton_path]]}
    write_json(project / 'data/battle2d/context_attack_source_mapping.json', mapping)
    profile = project / 'data/animation/sunwukong_profile.tres'
    text = profile.read_text(encoding='utf-8')
    if '&"run_attack"' not in text:
        text = text.replace('&"attack_5": &"attack5"}', '&"attack_5": &"attack5", &"run_attack": &"runAttack", &"jump_attack": &"jumpAttack"}')
        profile.write_text(text, encoding='utf-8')
    actor = project / 'data/battle2d/sunwukong.tres'
    text = actor.read_text(encoding='utf-8')
    if '&"sunwukong_run_attack"' not in text:
        text = text.replace('&"sunwukong_attack5"]', '&"sunwukong_attack5", &"sunwukong_run_attack", &"sunwukong_jump_attack"]')
        actor.write_text(text, encoding='utf-8')
    for relative in ['data/battle2d/manifest.json', 'data/battle2d/original_damage/manifest.json', 'data/battle2d/hit_reaction/manifest.json']:
        file = project / relative
        manifest = json.loads(file.read_text(encoding='utf-8-sig'))
        for row in records:
            manifest['definitions']['skills'][row['id']] = f"res://data/battle2d/{row['action']}.tres"
        write_json(file, manifest)
    file = project / 'data/damage/skill_mapping.json'
    damage_mapping = json.loads(file.read_text(encoding='utf-8-sig'))
    damage_mapping.update({r['id']: r['source_skill_id'] for r in records})
    write_json(file, damage_mapping)
    print('PASS imported native run/jump animations, effects, original ABRects, GAS timelines and catalogs')
#endregion
#region 两个独立GAS攻击定义

def _write_skill(project, label, id, action, native, original, duration, start, end, rect):
    path = project / f'data/battle2d/{action}.tres'
    if path.exists():
        return  # Preserve subsequent Inspector edits.
    script = lambda name: f'res://addons/battle_foundation/{name}.gd'
    text = '[gd_resource type="Resource" script_class="GameplayAbilityDefinition" format=3]\n'
    for type, url, key in [('Script','res://addons/gameplay_abiltiy_system/scripts/abilities/gameplay_ability_definition.gd','definition'),('Script','res://addons/gameplay_abiltiy_system/scripts/abilities/features/gameplay_ability_feature.gd','feature'),('Script',script('gas/battle_frame_timeline_feature'),'timeline'),('Script',script('definitions/battle_attack_segment'),'segment'),('Script',script('definitions/battle_skill_motion'),'motion')]:
        text += f'[ext_resource type="{type}" path="{url}" id="{key}"]\n'
    text += f'\n[sub_resource type="Resource" id="Hit"]\nscript = ExtResource("segment")\nsegment_id = &"{action}_hit"\nstart_frame = {start}\nend_frame = {end}\naction = &"{action}"\nhit_rect = Rect2({", ".join(map(str,rect))})\ndamage_multiplier = {original["skillDefault"]}\nhit_stun = {0.4 if label == "run" else 0.3}\nprotection_skill_id = "{original["id"]}"\n'
    if label == 'run':
        text += '\n[sub_resource type="Resource" id="Dash"]\nscript = ExtResource("motion")\nstart_frame = 0\nend_frame = 12\nvelocity = Vector2(480, 0)\n'
    text += f'\n[sub_resource type="Resource" id="Timeline"]\nscript = ExtResource("timeline")\nsource_fps = 30.0\nduration_frames = {duration}\nanimation_action = &"{action}"\nattack_segments = Array[ExtResource("segment")]([SubResource("Hit")])\n'
    if label == 'run':
        text += 'motion_windows = Array[ExtResource("motion")]([SubResource("Dash")])\n'
    text += f'action_rules = {{"move": {"true" if label == "jump" else "false"}, "jump": false, "turn": false, "interrupt_priority": 30}}\n\n[resource]\nscript = ExtResource("definition")\nability_id = &"{id}"\nability_name = "悟空{ "跑攻" if label == "run" else "跳攻" }"\nfeatures = Array[ExtResource("feature")]([SubResource("Timeline")])\n'
    path.write_text(text, encoding='utf-8')
#endregion
#region 仅追加语义动画与编辑器预览索引

def _value(index, target, times, values, continuous=False):
    return f'tracks/{index}/type = "value"\ntracks/{index}/path = NodePath("{target}")\ntracks/{index}/interp = 1\ntracks/{index}/keys = {{"times": PackedFloat32Array({", ".join(map(str,times))}), "transitions": PackedFloat32Array({", ".join("1" for t in times)}), "update": {0 if continuous else 1}, "values": [{", ".join(values)}]}}\n'


def _native(index, target, times, clips):
    return f'tracks/{index}/type = "animation"\ntracks/{index}/path = NodePath("{target}")\ntracks/{index}/keys = {{"times": PackedFloat32Array({", ".join(map(str,times))}), "clips": PackedStringArray({", ".join(json.dumps(c) for c in clips)})}}\n'


def _append_visual(project, action, native, frames, trigger, end):
    file = project / 'data/animation/sunwukong_visual.tscn'
    text = file.read_text(encoding='utf-8')
    if f'resource_name = "{action}"' in text:
        return
    duration = frames / 30.0
    animation_id = f'Context_{action}'
    clip = f'[sub_resource type="Animation" id="{animation_id}"]\nresource_name = "{action}"\nlength = {duration}\n'
    clip += _native(0, 'SpineVisual/SpineAnimationTrack/SpineVisual Track 0', [0], [native])
    clip += _value(1, 'AttackHitbox:preview_action', [0], [f'&"{action}"'])
    clip += _value(2, 'AttackHitbox:preview_time', [0,duration], ['0.0',str(duration)], True)
    clip += _value(3, 'AttackEffects/Primary:visible', [0,trigger/30.0,end/30.0], ['false','true','false'])
    clip += _native(4, 'AttackEffects/Primary/SpineAnimationTrack/AnimationPlayer', [0,trigger/30.0,end/30.0], ['RESET',native,'RESET'])
    clip += _value(5, 'AttackEffects/Secondary:visible', [0], ['false'])
    clip += _native(6, 'AttackEffects/Secondary/SpineAnimationTrack/AnimationPlayer', [0], ['RESET'])
    clip += _value(7, 'AttackEffects:preview_action', [0], [f'&"{action}"'])
    clip += _value(8, 'AttackEffects:preview_time', [0,duration], ['0.0',str(duration)], True)
    # Find master library by semantic attack_1 binding; do not touch native/effect libraries.
    libraries = list(re.finditer(r'\[sub_resource type="AnimationLibrary"[^\n]*\]\n[\s\S]*?(?=\n\[)', text))
    library = next(m for m in libraries if '&"attack_1"' in m.group())
    block = library.group().replace('_data = {', f'_data = {{\n&"{action}": SubResource("{animation_id}"),')
    text = text[:library.start()] + clip + '\n' + block + text[library.end():]
    ext_id = f'skill_{action}'
    ext = f'[ext_resource type="Resource" path="res://data/battle2d/{action}.tres" id="{ext_id}"]\n'
    at = text.index('[sub_resource')
    text = text[:at] + ext + '\n' + text[at:]
    text = re.sub(r'(preview_abilities = [^\n]*)(\]\))', lambda m: m[1]+f', ExtResource("{ext_id}")'+m[2], text)
    file.write_text(text, encoding='utf-8')
#endregion
#region 命令行入口
if __name__ == '__main__':
    main(Path(sys.argv[1]).resolve())
#endregion
