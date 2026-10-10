"""Move the game entry and verification fixtures; defaults to a read-only plan."""
from pathlib import Path
import argparse, json, shutil, re
ROOT=Path(__file__).resolve().parents[1]

#region Audited, bounded workspace operations and reference updates
def organize(apply=False):
    entries={}
    for path in (ROOT/'examples').glob('*'):
        name=path.name
        if name.startswith('stage_one_demo.'):
            target=None
        elif name.startswith('level_progression_demo.'):
            target='game/levels/biyujing'+path.suffix
            if path.name.endswith('.gd.uid'):target='game/levels/biyujing.gd.uid'
        elif name.startswith('verify_'):
            target='tests/suites/'+name
        else:
            target='tests/fixtures/'+name
        entries[path.relative_to(ROOT).as_posix()]=target
    if not entries:
        print('Already organized; no examples folder remains');return
    print(json.dumps(entries,ensure_ascii=False,indent=2))
    if not apply:return
    backup=ROOT/'.cleanup-backup/project-layout'
    replacements={old:new for old,new in entries.items() if new}
    replacements['examples/stage_one_demo.tscn']='tests/suites/verify_stage_one.tscn'
    extensions={'.gd','.tscn','.tres','.json','.md','.py','.mjs','.ps1','.godot'}
    for path in ROOT.rglob('*'):
        if not path.is_file() or path.suffix not in extensions or any(part in ('.git','.godot','.cleanup-backup') for part in path.relative_to(ROOT).parts):continue
        if path==Path(__file__):continue
        text=path.read_text('utf8')
        updated=text.replace('res://examples/verify_','res://tests/suites/verify_')
        for old,new in replacements.items():updated=updated.replace(old,new)
        if updated!=text:path.write_text(updated,'utf8')
    for old,new in entries.items():
        source=(ROOT/old).resolve()
        target=(ROOT/new if new else backup/old).resolve()
        if not source.is_relative_to(ROOT) or not target.is_relative_to(ROOT):raise RuntimeError('Path outside project')
        if target.exists():raise RuntimeError(f'Refusing overwrite: {target}')
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.move(source,target)
    (ROOT/'examples').rmdir()
    report=ROOT/'docs/project_layout.json'
    report.write_text(json.dumps({'moves':entries,'removed':'stage_one_demo (unreferenced old demo; backed up outside Godot import)'},ensure_ascii=False,indent=2)+'\n','utf8')
    print('Moved game entry, suites and fixtures; removed unused stage-one demo; all explicit references updated')
#endregion

#region Unused vendor examples: verify references before moving to local backup

def archive_unused_plugin_examples(apply=False):
    folders=[ROOT/'addons/phantom_camera/examples',ROOT/'addons/godot_core_system-0.0.4/examples']
    folders=[p.resolve() for p in folders if p.exists()]
    if not folders: return
    candidates=[]
    for path in ROOT.rglob('*'):
        if not path.is_file() or path.suffix not in {'.gd','.tscn','.tres','.json','.godot','.cfg'}: continue
        if any(part in {'.git','.godot','.cleanup-backup'} for part in path.relative_to(ROOT).parts): continue
        if any(path.resolve().is_relative_to(folder) for folder in folders): continue
        candidates.append((path,path.read_text('utf8',errors='replace')))
    report=[]
    for folder in folders:
        prefix='res://'+folder.relative_to(ROOT).as_posix()+'/'
        names=[]
        for script in folder.rglob('*.gd'):
            names.extend(re.findall(r'^class_name\s+(\w+)',script.read_text('utf8'),re.M))
        for path,text in candidates:
            if prefix in text or any(re.search(r'\b'+re.escape(name)+r'\b',text) for name in names):
                raise RuntimeError(f'Cannot remove referenced plugin example: {path}')
        target=(ROOT/'.cleanup-backup/project-layout'/folder.relative_to(ROOT)).resolve()
        if not folder.is_relative_to(ROOT) or not target.is_relative_to(ROOT): raise RuntimeError('Path outside project')
        if target.exists(): raise RuntimeError(f'Refusing overwrite: {target}')
        report.append({'directory':folder.relative_to(ROOT).as_posix(),'files':sum(p.is_file() for p in folder.rglob('*')),'reason':'No serialized/script/class references outside example directory'})
        if apply:
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.move(folder,target)
    print(json.dumps(report,ensure_ascii=False,indent=2))
    if apply:
        file=ROOT/'docs/project_layout.json'
        data=json.loads(file.read_text('utf8')) if file.exists() else {}
        data['removed_plugin_examples']=report
        file.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n','utf8')
#endregion

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--apply',action='store_true')
    args=parser.parse_args()
    organize(args.apply)
    archive_unused_plugin_examples(args.apply)
