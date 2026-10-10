"""Export cached original MP3 sounds offline; never execute Flash or alter source assets."""
from pathlib import Path
import hashlib, json, re, sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = Path('D:/UserData/Downloads/game/Speculum-4399-master')
sys.dont_write_bytecode = True
sys.path.insert(0, str(ORIGINAL))
from backends.zmhj_config import load_config_archive
from import_stage_thirteen_boss import sound_tags

#region Exact original DefineSound payloads and named SymbolClass bindings
def main():
    config = load_config_archive(ORIGINAL / 'games/zmhj-g5')
    folder = ROOT / 'assets/audio/original'
    folder.mkdir(parents=True, exist_ok=True)
    packs, evidence = {}, []
    for source in sorted((ORIGINAL / 'games/zmhj-g5/cache/assets/music').rglob('*.swf')):
        group = source.stem
        streams = sound_tags(source)
        pack = {}
        for name, content in streams.items():
            safe_name = re.sub(r'[^\w.-]', '_', name)
            target = folder / group / (safe_name + '.mp3')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
            pack[name] = 'res://' + target.relative_to(ROOT).as_posix()
            evidence.append({'source': source.relative_to(ORIGINAL).as_posix(), 'symbol': name,
                             'file': target.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(content).hexdigest(),
                             'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest()})
        packs[group] = pack
        print(group, ', '.join(pack))
    units = {}
    units['孙悟空'] = config['Resource'][str(config['Role']['2001']['resourceId'])]['sound'] if '2001' in config.get('Role', {}) else 'se2001V456.swf'
    for name, original_id in [('jianwu','10101'), ('yushoushi','10201'), ('revival_vessel','10501'), ('jushi_lingjun','10601')]:
        row = config.get('Monster', {}).get(original_id, {})
        resource = config.get('Resource', {}).get(str(row.get('resourceId', '')), {})
        definition = (ROOT / 'data/monsters' / name / 'definition.tres').read_text('utf8')
        definition_id = re.search(r'definition_id = &"([^"]+)"', definition).group(1)
        units[definition_id] = resource.get('sound', '')
        print(name, original_id, resource.get('sound', ''), resource.get('normal', ''))
    zones = []
    for node in ET.parse(ORIGINAL / 'games/zmhj-g5/cache/assets/map/No_1-1_V283.tmx').getroot().iter('object'):
        if node.get('type') != 'BgMusic': continue
        properties = {p.get('name'):p.get('value') for p in node.findall('properties/property')}
        zones.append({'music':Path(properties['url']).stem,
                      'rect':[float(node.get(k,'0'))*2 for k in ('x','y','width','height')],
                      'monster_ids':properties.get('monsterIds',properties.get('mids',''))})
    result = {'packs': packs, 'units': units, 'sources': evidence,
              'level_music': {'碧玉径': 'No_1-3'}, 'music_zones': {'碧玉径':zones}, 'boss_music': 'boss_01'}
    target = ROOT / 'data/audio/original_audio.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', 'utf8')
    print('Exported', len(evidence), 'unchanged original MP3 streams')

if __name__ == '__main__':
    main()
#endregion
