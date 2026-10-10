"""Export shipped first-level loot, equipment growth tables and original pickup icons."""
from pathlib import Path
import json, sys, shutil, hashlib
ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = Path('D:/UserData/Downloads/game/Speculum-4399-master')
sys.path.insert(0, str(ORIGINAL))
from backends.zmhj_config import load_config_archive

#region Read-only definitions; do not invent server-only affix or success probabilities
config = load_config_archive(ORIGINAL/'games/zmhj-g5')
folder = ROOT/'data/loot'; folder.mkdir(parents=True, exist_ok=True)
def save(path, value):
    (ROOT/path).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', 'utf8')
level = config['Dungeon']['1']
mapping = dict(zip(level['monsterID'].split(';'), [x.split(',') for x in level['dropId'].split(';')]))
drops = {key:config['Drop'][key] for ids in mapping.values() for key in ids if key != '-1'}
ids = {'101005001', '101005002', '110101001', '110101002', '110101003'}
reset_sample = next(key for key in sorted(config['EquReset']) if key in config['Equipment'] and config['Equipment'][key].get('part') == 'weapon' and int(config['Equipment'][key].get('roleConditions', 0)) == 1 and int(config['Equipment'][key].get('isReset', 0)) != 0)
ids.add(reset_sample)
for row in drops.values():
    ids.update(str(row.get('itemId', '-1')).split(';'))
    ids.update(str(row.get('equip_1', '-1')).split(';'))
definitions = {}
for key in sorted(ids-{'-1'}):
    row = config.get('Equipment', {}).get(key) or config.get('Prop', {}).get(key)
    if row is None: raise ValueError('missing original item '+key)
    row = dict(row)
    resource = config['Resource'][str(row['resourceId'])]
    icon_path = resource.get('icon1') or resource.get('icon2')
    source = ORIGINAL/'games/zmhj-g5/cache/assets/icon'/icon_path
    if not source.exists(): raise FileNotFoundError(source)
    target = ROOT/'assets/ui/original'/('loot_'+key+'.png')
    shutil.copyfile(source, target)
    ui_source = ORIGINAL/'games/zmhj-g5/cache/assets/icon'/resource.get('icon2', icon_path)
    ui_target = ROOT/'assets/ui/original'/('loot_'+key+'_ui.png')
    shutil.copyfile(ui_source, ui_target)
    definitions[key] = {'data':row, 'icon':'res://assets/ui/original/'+ui_target.name, 'pickup_icon':'res://assets/ui/original/'+target.name,
                        'source_icon':icon_path, 'sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
    normal = resource.get('normal', '')
    prefixes = {'armor':'衣服/', 'helmet':'头盔/', 'weapon':'武器/'}
    definitions[key]['appearance_skins'] = {'孙悟空':prefixes[row['part']]+Path(normal).stem} if normal.startswith('2001/') and row.get('part') in prefixes else {}
spirit = ORIGINAL/'games/zmhj-g5/cache/assets/icon/prop/spirit_drop.png'
shutil.copyfile(spirit, ROOT/'assets/ui/original/spirit_drop.png')
save(Path('data/loot/original_first_level.json'), {'dungeon_id':1,'monster_drops':mapping,
     'drops':drops,'items':definitions,'spirit_resource':config['Resource']['58'],
     'sources':['Dungeon[1]','Drop','Equipment','Prop','Resource[58]']})
save(Path('data/inventory/growth_rules.json'), {'refine':config['EquRefine'], 'reset':config['EquReset'],
     'fashion_sets':config['FashionSuit'], 'items':definitions, 'reset_sample':reset_sample})
print('Exported first-level loot rules,', len(definitions), 'item icons, soul icon and original growth tables')
#endregion
