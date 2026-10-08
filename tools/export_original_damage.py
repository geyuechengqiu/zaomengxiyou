"""Offline import of original EXP and skill parameters; never changes the source repo."""
# region Source and export
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def export(source: Path) -> None:
    out = ROOT / 'data' / 'damage'
    out.mkdir(parents=True, exist_ok=True)
    sources = ['等级换算参数.json', '技能伤害配置.json', '伤害计算公式.md',
        'sources/models/managers/BattleModelManager.as',
        'sources/prefabs/controls/DamageControl.as', 'sources/models/vo/UserVO.as',
        'sources/com/wdcgame/engine/model/SkillConfigVO.as',
        'sources/com/wdcgame/engine/model/SkillParam.as',
        'sources/com/wdcgame/utils/MathUtils.as']
    levels = json.loads((source / sources[0]).read_text(encoding='utf-8-sig'))
    skills = json.loads((source / sources[1]).read_text(encoding='utf-8-sig'))
    def normalize(row):
        result = {}
        for key, value in row.items():
            name = key.split('(')[-1].rstrip(')') if '(' in key else ('level' if key == '等级ID' else 'source_skill_id')
            if value is not None:
                if name == 'custom' and isinstance(value, str):
                    value = json.loads(value)
                    # Skill config's static custom section (s); other sections remain metadata.
                    if isinstance(value, dict) and 's' in value:
                        value = value['s']
                result[name] = value
        return result
    write(out / 'original_levels.json', {str(row['等级ID']): normalize(row) for row in levels})
    write(out / 'original_skills.json', {str(row['技能ID']): normalize(row) for row in skills})
    mapping = json.loads((ROOT / 'data/battle2d/combo_source_mapping.json').read_text(encoding='utf-8-sig'))
    context_path = ROOT / 'data/battle2d/context_attack_source_mapping.json'
    context_steps = json.loads(context_path.read_text(encoding='utf-8-sig'))['steps'] if context_path.exists() else []
    write(out / 'skill_mapping.json', {row['id']: row['source_skill_id'] for row in mapping['steps'] + context_steps})
    write(out / 'provenance.json', {'level_count': len(levels), 'skill_count': len(skills),
        'sources': [{'path': 'exports/zmhj_damage_formulas/' + name,
            'sha256': hashlib.sha256((source / name).read_bytes()).hexdigest()} for name in sources],
        'policy': 'Original numeric precision retained; business skill IDs remain human readable.'})
    print(f'Imported {len(levels)} EXP levels and {len(skills)} skill definitions')

def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    export(parser.parse_args().source.resolve())
# endregion
