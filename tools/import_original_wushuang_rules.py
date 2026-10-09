"""Export original Common/Skill/Buff Wushuang rules without changing source resources."""
from pathlib import Path
import json, sys
#region 原版配置只读，业务ID沿用技能映射
PROJECT = Path(__file__).resolve().parents[1]
ORIGINAL = Path(sys.argv[1]).resolve()
sys.path.insert(0, str(ORIGINAL))
from backends.zmhj_config import load_config_archive
config = load_config_archive(ORIGINAL / 'games/zmhj-g5')
mapping = json.loads((PROJECT / 'data/damage/skill_mapping.json').read_text(encoding='utf8'))
rows = {}
for name, original_id in mapping.items():
    skill = config['Skill'].get(str(original_id), {})
    rows[name] = {'original_skill_id': original_id, 'addXP': skill.get('addXP', 0), 'addXPMax': skill.get('addXPMax', 0), 'atkMax': skill.get('atkMax', 1)}
rules = {
    'xpMax': config['Common']['1']['xpMax'], 'hpToXP': config['Common']['1']['hpToXP'],
    'duration': 15, 'victimAwardCalls': 2, 'skills': rows,
    'buffs': {id: config['Buff'][id] for id in ['6000601','21000101','23000101','8000201']},
    'sources': [
        'out/zmhj-equip-skill-diag/models/managers/BattleModelManager.as:checkHurtManData/calXP',
        'out/zmhj-equip-skill-diag/models/vo/UserVO.as:doInAdvanceTime',
        'out/zmhj-equip-skill-diag/com/wdcgame/engine/model/UserVOBase.as:updateXP',
        'out/zmhj-equip-skill-diag/viewers/container/uis/RoleSkillView.as:updateXPPer',
        'Common/Role/Skill/Buff in cg1 configuration archive'
    ]
}
target = PROJECT / 'data/effects/wushuang/combat_rules.json'
target.write_text(json.dumps(rules, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
print('Exported original Wushuang rage budgets, Common limits and four Buff source rows')
#endregion
