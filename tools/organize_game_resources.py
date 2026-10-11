"""Consolidate character resources and remove obsolete demo dependencies (use --apply)."""
from pathlib import Path
import argparse, json, re, shutil

ROOT = Path(__file__).resolve().parents[1]
TEXT = {'.gd','.tscn','.tres','.json','.md','.py','.mjs','.ps1','.godot','.cfg','.import','.svg','.java','.txt'}
SKIP = {'.git','.godot','.cleanup-backup','.idea','__pycache__'}

#region Explicit paths, auditable removals and bounded native filesystem operations
def files():
    return [p for p in ROOT.rglob('*') if p.is_file() and not any(x in SKIP for x in p.relative_to(ROOT).parts)]

def safe(path):
    value = path.resolve()
    if not value.is_relative_to(ROOT): raise RuntimeError(f'Outside project: {value}')
    return value

def main(apply):
    moves = {
        'data/animation':'data/characters/sunwukong/animation',
        'data/skills/sunwukong':'data/characters/sunwukong/skills',
        'data/attribute/progression/sunwukong.tres':'data/characters/sunwukong/attributes/progression.tres',
        'data/protection/sunwukong.tres':'data/characters/sunwukong/protection.tres',
        'assets/skelton/char/sunwukong':'assets/characters/sunwukong/animation',
        'assets/audio/original/se2001V456':'assets/characters/sunwukong/audio',
        'data/controls/player_operations.tres':'data/characters/sunwukong/controls/input.tres',
        'data/attribute/progression/source_mapping.json':'data/characters/sunwukong/attributes/source_mapping.json',
        'data/battle2d/sunwukong.tres':'data/characters/sunwukong/definition.tres',
        'data/battle2d/sunwukong_2d.tscn':'data/characters/sunwukong/character.tscn',
        'data/battle2d/sunwukong_actions.tres':'data/characters/sunwukong/actions.tres',
        'data/battle2d/sunwukong_attributes.tres':'data/characters/sunwukong/attributes/base.tres',
        'data/battle2d/sunwukong_combo.tres':'data/characters/sunwukong/skills/combo.tres',
        'data/battle2d/attack_hitboxes_source.json':'data/characters/sunwukong/skills/attack_hitboxes_source.json',
        'data/battle2d/combo_source_mapping.json':'data/characters/sunwukong/skills/combo_source_mapping.json',
        'data/battle2d/context_attack_source_mapping.json':'data/characters/sunwukong/skills/context_attack_source_mapping.json',
        'data/battle2d/character-components.md':'data/characters/sunwukong/components.md',
        'data/battle2d/wukong-context-attacks.md':'data/characters/sunwukong/skills/context-attacks.md',
        'data/battle2d/original_reactions':'data/characters/sunwukong/skills/normal_attacks',
    }
    previous_file = ROOT/'docs/resource_organization.json'
    previous = json.loads(previous_file.read_text('utf8')) if previous_file.exists() else {}
    prior_moves = previous.get('moves',{})
    moves = {old:new for old,new in moves.items() if (ROOT/old).exists()}
    removed = set()
    for folder in ['tests/fixtures','data/battle','data/battle2d','addons/gameplay_abiltiy_system/examples']:
        for path in (ROOT/folder).rglob('*'):
            if not path.is_file(): continue
            rel = path.relative_to(ROOT).as_posix()
            if not any(rel==old or rel.startswith(old+'/') for old in moves): removed.add(rel)
    # These tools only generate historical demos; current exporters remain available.
    for name in ['build_single_attack_scene.mjs','build_skill_timeline_scene.mjs','verify_single_attack_scene.gd',
                 'benchmark_damage_numbers.gd','benchmark_damage_numbers.tscn','capture_wukong_context_attacks.gd',
                 'capture_wukong_context_attacks.tscn','capture_wushuang.gd']:
        if (ROOT/'tools'/name).exists(): removed.add('tools/'+name)
    # Remove verification suites tied to the retired demos, including scene/UID sidecars.
    for path in (ROOT/'tests/suites').glob('*.gd'):
        text = path.read_text('utf8')
        if 'tests/fixtures/' in text or 'res://data/battle/' in text or 'res://data/battle2d/manifest.json' in text:
            for sidecar in [path,path.with_suffix('.tscn'),Path(str(path)+'.uid')]:
                if sidecar.exists(): removed.add(sidecar.relative_to(ROOT).as_posix())
    for rel in list(removed):
        if (ROOT/(rel+'.uid')).exists(): removed.add(rel+'.uid')
    report = {'moves':dict(prior_moves,**moves),'removed':sorted(set(previous.get('removed',[]))|removed),'backup':'.cleanup-backup/resource-organization','retained_entry':'game/levels/biyujing.tscn'}
    print(json.dumps({'moves':len(moves),'removed_files':len(removed)},ensure_ascii=False))
    if not apply: return
    for path in files():
        rel = path.relative_to(ROOT).as_posix()
        if path.resolve()==Path(__file__).resolve() or rel in removed or path.suffix not in TEXT: continue
        original = path.read_text('utf8',errors='strict')
        updated = original
        for old,new in sorted(moves.items(),key=lambda entry:-len(entry[0])):
            updated = updated.replace(old,new)
        if original!=updated: path.write_text(updated,'utf8')
    backup = safe(ROOT/report['backup'])
    for rel in sorted(removed):
        source,target = safe(ROOT/rel),safe(backup/rel)
        if not source.exists(): continue
        target.parent.mkdir(parents=True,exist_ok=True)
        if source.is_dir() and target.is_dir():
            # Earlier individual moves may already have created a category directory.
            for path in list(source.rglob('*')):
                if not path.is_file(): continue
                dest = safe(target/path.relative_to(source))
                if dest.exists(): raise RuntimeError(f'Refusing overwrite: {dest}')
                dest.parent.mkdir(parents=True,exist_ok=True)
                shutil.move(safe(path),dest)
        else:
            if target.exists(): raise RuntimeError(f'Refusing overwrite: {target}')
            shutil.move(source,target)
    for old,new in sorted(moves.items(),key=lambda entry:-len(entry[0])):
        source,target = safe(ROOT/old),safe(ROOT/new)
        target.parent.mkdir(parents=True,exist_ok=True)
        if source.is_dir() and target.is_dir():
            for path in list(source.rglob('*')):
                if not path.is_file(): continue
                dest = safe(target/path.relative_to(source))
                if dest.exists(): raise RuntimeError(f'Refusing overwrite: {dest}')
                dest.parent.mkdir(parents=True,exist_ok=True)
                shutil.move(safe(path),dest)
        else:
            if target.exists(): raise RuntimeError(f'Refusing overwrite: {target}')
            shutil.move(source,target)
        if source.is_file(): raise RuntimeError('Move did not complete')
    # Empty directories alone are removed, never recursive deletion of computed paths.
    for path in sorted((p for p in ROOT.rglob('*') if p.is_dir() and not any(x in SKIP for x in p.relative_to(ROOT).parts)),key=lambda p:len(p.parts),reverse=True):
        if not any(path.iterdir()): safe(path).rmdir()
    safe(ROOT/'docs/resource_organization.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n','utf8')
    print('Applied resource organization; runtime path replacements and local backup completed')
#endregion

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply',action='store_true')
    main(parser.parse_args().apply)
