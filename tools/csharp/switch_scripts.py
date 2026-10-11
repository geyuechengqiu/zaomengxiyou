"""Replace references only after the native implementation compiles.

Old scripts are archived under the ignored project cache; UIDs remain stable.
Run from this directory with the project root as the sole argument.
"""
from pathlib import Path
import json
import shutil
import sys

root = Path(sys.argv[1]).resolve()
mapping = json.loads((root / 'tools/csharp/migration-map.json').read_text(encoding='utf-8'))
archive = root / '.cleanup-backup/csharp-migration'
text_extensions = {'.tscn', '.tres', '.gd', '.godot', '.cfg', '.json', '.md', '.py', '.ps1'}
changed = 0
for file in root.rglob('*'):
    relative = file.relative_to(root)
    if not file.is_file() or file.suffix not in text_extensions or any(part.startswith('.') for part in relative.parts):
        continue
    if relative.as_posix() == 'tools/csharp/migration-map.json':
        continue
    content = file.read_text(encoding='utf-8-sig')
    replacement = content
    for source, target in mapping.items():
        replacement = replacement.replace('res://' + source, 'res://' + target)
    if file.suffix == '.gd' and 'addons/battle_foundation/combat/battle_damage_rules.gd' in mapping:
        import re
        replacement = re.sub(r'\.get_number\((&"[^"\n]+"),', r'.get_number_or(\1,', replacement)
    if replacement != content:
        file.write_text(replacement, encoding='utf-8')
        changed += 1
for source, target in mapping.items():
    old, new = root / source, root / target
    if root not in old.resolve().parents or root not in new.resolve().parents or not new.is_file():
        raise ValueError(f'Invalid migration paths: {source} -> {target}')
    if old.is_file():
        destination = archive / source
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(old, destination)
        old.unlink()
    uid = old.with_suffix(old.suffix + '.uid')
    if uid.is_file():
        shutil.copy2(uid, new.with_suffix(new.suffix + '.uid'))
        shutil.copy2(uid, (archive / source).with_suffix(old.suffix + '.uid'))
        uid.unlink()
print(f'Migrated {len(mapping)} script paths; updated {changed} reference files')
