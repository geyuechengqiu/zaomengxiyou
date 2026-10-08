"""Add original SkillParam reactions to copies of the authored combo resources."""
import argparse
import hashlib
import json
import re
from pathlib import Path

# region 原配置与独立战斗资源
PROJECT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--original-root', type=Path, required=True)
    args = parser.parse_args()
    relative = 'exports/zmhj_role_stats/原始配置/Skill.json'
    source = args.original_root / relative
    skills = json.loads(source.read_text(encoding='utf-8-sig'))
    output = PROJECT / 'data/battle2d/original_reactions'
    output.mkdir(exist_ok=True)
    records = []
    for index, name in enumerate(['attack1', 'attack2', 'attack3', 'attack4', 'attack5', 'run_attack', 'jump_attack'], 1):
        original = skills[str(1001000 + index * 10)]
        impacts = sorted((p for p in original['param']['s'] if p['type'] == 1 and p.get('hasDamage', True)), key=lambda p: p['shootFrame'])
        reactions = []
        for impact in impacts:
            # SkillParam.buildFromObject: empty targetMove inherits the parent skill.
            movement = impact.get('targetMove') or original.get('targetMove')
            stiff = float(impact.get('stiff', original.get('stiff', 0)))
            duration = float(impact.get('targetMoveTime', 0))
            if duration <= 0:
                duration = stiff if stiff > 0 else 1.0
            x, y = map(float, movement.split(';'))
            reaction = {'hit_stun': stiff, 'knockback_speed': x * 2, 'knockback_duration': duration,
                        'launch_speed': y * 6, 'reset_vertical_velocity': True, 'reaction_gravity': 1980.0}
            reactions.append(reaction)
        text = (PROJECT / f'data/battle2d/{name}.tres').read_text(encoding='utf-8')
        if index <= 5:
            pending = iter(reactions)
            def add_payload(match):
                values = next(pending)
                fields = ',\n'.join(f'"{k}": {str(v).lower()}' for k, v in values.items())
                return 'payload = {' + match[1].rstrip() + ',\n' + fields + '\n}'
            text, count = re.subn(r'payload = \{(.*?)\n\}', add_payload, text, flags=re.S)
            if count != len(reactions):
                raise ValueError(f'{name}: expected {len(reactions)} impact markers, got {count}')
        else:
            values = reactions[0]
            text = re.sub(r'^hit_stun = [^\n]*', '\n'.join(f'{k} = {str(v).lower()}' for k, v in values.items()), text, count=1, flags=re.M)
        # New copies must not reuse the source resource's UID.
        text = re.sub(r' uid="[^"]+"', '', text, count=1)
        (output / f'{name}.tres').write_text(text, encoding='utf-8')
        records.append({'action': name, 'source_skill_id': original['id'], 'skill_target_move': original.get('targetMove'),
                        'impacts': impacts, 'world_reactions': reactions})
    record = {'source': relative, 'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
              'display_scale': 2, 'source_fps': 30, 'nape_delta': 0.1, 'nape_gravity': 110, 'steps': records}
    (output / 'source.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Imported 7 original Wukong reactions; authored source resources unchanged.')
# endregion

# region 命令行入口
if __name__ == '__main__':
    main()
# endregion
