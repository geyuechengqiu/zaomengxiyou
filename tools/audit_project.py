"""Check tracked Godot references and classify scenes without modifying resources."""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import posixpath
from collections import Counter
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_EXTENSIONS = {'.tscn', '.tres', '.gd', '.cs', '.godot', '.cfg', '.json', '.import'}
SERIALIZED_EXTENSIONS = {'.tscn', '.tres', '.godot'}
PATH = re.compile(r'res://([^\s"\'<>\[\]]+)')
UID = re.compile(r'uid://[a-z0-9]+')
EXT_RESOURCE = re.compile(r'\[ext_resource\b([^\]]+)\]')
EXAMPLE = re.compile(r'(^|/)(examples?|demos?|samples?)(/|$)|(^|/)(example|demo|sample)[_-]', re.I)
LINK = re.compile(r'\]\(([^\s)]+)(?:\s+"[^"]*")?\)')


def tracked_files() -> list[str]:
    # Include new authored files before committing, but honor all cache ignores.
    result = subprocess.run(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'],
                            cwd=ROOT, check=True, capture_output=True)
    return sorted(set(result.stdout.decode('utf-8').strip('\0').split('\0')))


def category(path: str) -> str:
    if path.startswith('game/levels/'):
        return 'levels'
    if path.startswith('game/'):
        return 'game_ui'
    if path.startswith('tests/'):
        return 'validation'
    if path.startswith('tools/'):
        return 'performance_tools'
    if path.startswith('data/templates/'):
        return 'reusable_templates'
    if EXAMPLE.search(path):
        return 'examples'
    return 'components'


def audit() -> dict:
    files = [path for path in tracked_files() if (ROOT / path).is_file()]
    names = set(files)
    folded = {path.casefold(): path for path in files}
    texts = {}
    uids: dict[str, set[str]] = {}
    errors: list[dict] = []
    references = 0
    for path in files:
        if Path(path).suffix not in RESOURCE_EXTENSIONS | {'.uid'}:
            continue
        text = (ROOT / path).read_text(encoding='utf-8-sig')
        texts[path] = text
        # Only definitions identify an owner; ext_resource UIDs are references.
        if path.endswith('.uid'):
            owner, found = path[:-4], UID.search(text)
            if owner not in names:
                errors.append({'kind': 'orphan_script_uid', 'source': path, 'target': owner})
        else:
            owner = path[:-7] if path.endswith('.import') else path
            found = re.search(r'\buid\s*=\s*"(uid://[a-z0-9]+)"', text[:text.find('\n\n') if '\n\n' in text else 512])
        if found:
            uid = found.group(0) if path.endswith('.uid') else found.group(1)
            uids.setdefault(uid, set()).add(owner)
    for source, text in texts.items():
        if Path(source).suffix not in SERIALIZED_EXTENSIONS:
            continue
        for ref in sorted(set(PATH.findall(text))):
            references += 1
            # Helpers can be independent Godot projects with their own res:// root.
            project_root = Path(source).parent if source.endswith('/project.godot') else Path('.')
            target = (project_root / ref).as_posix()
            if target in names:
                continue
            kind = 'path_case_mismatch' if target.casefold() in folded else 'missing_resource'
            errors.append({'kind': kind, 'source': source, 'target': target,
                           **({'actual': folded[target.casefold()]} if kind == 'path_case_mismatch' else {})})
        if source.endswith(('.tscn', '.tres')):
            for block in EXT_RESOURCE.findall(text):
                uid, path = UID.search(block), PATH.search(block)
                if uid and path and uid.group(0) in uids and path.group(1) not in uids[uid.group(0)]:
                    errors.append({'kind': 'uid_path_mismatch', 'source': source,
                                   'target': path.group(1), 'uid': uid.group(0)})
        if source.endswith('.godot'):
            for uid in UID.findall(text):
                if uid not in uids:
                    errors.append({'kind': 'unresolved_autoload_uid', 'source': source, 'target': uid})
    for uid, owners in uids.items():
        if len(owners) > 1:
            errors.append({'kind': 'duplicate_uid', 'uid': uid, 'owners': sorted(owners)})
    for source in files:
        if not source.endswith('.md') or source.startswith('docs/reference/'):
            continue
        if source != 'README.md' and not source.startswith(('data/', 'game/', 'docs/', 'tests/', 'tools/', 'addons/battle_foundation/')):
            continue
        for link in LINK.findall((ROOT / source).read_text(encoding='utf-8-sig')):
            target = unquote(link.split('#', 1)[0].split('?', 1)[0])
            if not target or ':' in target:
                continue
            target = posixpath.normpath(posixpath.join(posixpath.dirname(source), target))
            if target.startswith('../'):
                continue
            if not (ROOT / target).exists():
                errors.append({'kind': 'missing_document_link', 'source': source, 'target': target})
    scenes = {path: category(path) for path in files if path.endswith('.tscn')}
    examples = sorted(path for path in files if EXAMPLE.search(path))
    return {'files': len(files), 'serialized_references': references,
            'scene_counts': dict(sorted(Counter(scenes.values()).items())),
            'scenes': scenes, 'example_files': examples, 'errors': errors}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, help='Optional JSON report, normally in .cleanup-backup')
    args = parser.parse_args()
    report = audit()
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for error in report['errors']:
        print(json.dumps(error, ensure_ascii=False))
    print(f"{'FAIL' if report['errors'] else 'PASS'} project audit: {report['files']} files, "
          f"{report['serialized_references']} references, {sum(report['scene_counts'].values())} scenes; "
          f"{len(report['errors'])} errors, {len(report['example_files'])} example files")
    return int(bool(report['errors']))


if __name__ == '__main__':
    raise SystemExit(main())
