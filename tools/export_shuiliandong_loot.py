"""Offline export: ordinary gorilla uses current mobs; Boss uses Dungeon/2 loot.

No global first-level rules are changed. Source drop rows and probabilities are
preserved, and only their referenced item definitions/icons are added locally.
"""
from pathlib import Path
import hashlib, json, shutil, sys

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = Path('D:/UserData/Downloads/game/Speculum-4399-master')
sys.path.insert(0, str(REFERENCE))
from backends.zmhj_config import load_config_archive

def main():
    config=load_config_archive(REFERENCE/'games/zmhj-g5')
    rules=json.loads((ROOT/'data/loot/original_first_level.json').read_text('utf8'))
    dungeon=config['Dungeon']['2']
    mapping=dict(zip(dungeon['monsterID'].split(';'),[ids.split(',') for ids in dungeon['dropId'].split(';')]))
    boss_drops=mapping['10802']
    rules['dungeon_id']=2
    rules['monster_drops']['10802']=boss_drops
    for key in boss_drops:rules['drops'][key]=config['Drop'][key]
    added={}
    for drop in boss_drops:
        row=rules['drops'][drop]
        ids=set(str(row.get('itemId','-1')).split(';'))
        # The playable sample character is Wukong (role condition 1), as in the
        # shared first-level catalogue. Keep all source probability fields,
        # while exporting only the playable role's required item resources.
        ids.update(str(row.get('equip_1','-1')).split(';'))
        for key in sorted(ids-{'-1'}):
            if key in rules['items']:continue
            data=config['Equipment'].get(key) or config['Prop'].get(key)
            if data is None:raise ValueError('Missing original item '+key)
            resource=config['Resource'][str(data['resourceId'])]
            icon=resource.get('icon2') or resource.get('icon1')
            source=REFERENCE/'games/zmhj-g5/cache/assets/icon'/icon
            target=ROOT/'assets/ui/original'/f'loot_{key}_ui.png'
            shutil.copyfile(source,target)
            path='res://assets/ui/original/'+target.name
            appearance={};normal=resource.get('normal','')
            prefixes={'armor':'衣服/','helmet':'头盔/','weapon':'武器/'}
            if normal.startswith('2001/') and data.get('part') in prefixes:
                appearance={'孙悟空':prefixes[data['part']]+Path(normal).stem}
            rules['items'][key]={'data':data,'icon':path,'pickup_icon':path,'source_icon':icon,
                                 'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'appearance_skins':appearance}
            added[key]=rules['items'][key]
    rules['sources']+=['Dungeon[2].monsterID/dropId -> Monster[10802] -> Drop[1002]']
    out=ROOT/'data/levels/shuiliandong'
    (out/'loot.json').write_text(json.dumps(rules,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    evidence={'source':'cg1_20260921_1.swf','Dungeon':{key:dungeon[key] for key in ('id','mapURL','monsterID','dropId')},
              'boss_monster_id':10802,'boss_drop_ids':boss_drops,'Drop':{key:config['Drop'][key] for key in boss_drops},
              'ordinary_gorilla_drop_ids':rules['monster_drops']['10101'],'added_items':added}
    (out/'drop_source.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print('Water-level loot: Boss',boss_drops,'76 EXP / 65 soul; added',len(added),'item definitions.')

if __name__=='__main__':main()
