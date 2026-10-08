"""只读渲染原版怪物血条，不执行 Flash/ActionScript。"""
#region 原始符号、位图与来源校验
from pathlib import Path
import base64
import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET

project = Path(__file__).resolve().parents[1]
source_root = Path(sys.argv[1]).resolve()
source_path = "games/zmhj-g5/cache/assets/ui/mission_20260406_1.swf"
source = source_root / source_path
output = project / "assets/ui/monster_health_bar"
mapping = json.loads((output / "source_mapping.json").read_text(encoding="utf-8"))
assert hashlib.sha256(source.read_bytes()).hexdigest() == mapping["source_sha256"], "Source changed: re-inspect symbols first"
dependencies = source_root / "out/swfutil/ffdec_lib_20.1.0"
assert (dependencies / "ffdec_lib.jar").is_file()
export = project / ".cleanup-backup/monster-health-bar-export"
export.mkdir(parents=True, exist_ok=True)
java = shutil.which("java")
assert java, "Install Java 17 or newer"
subprocess.run([java, "-Djava.awt.headless=true", "-Duser.home=" + str(export / "java-home"), "-cp", str(dependencies / "*"), str(project / "tools/ExportOriginalMonsterHealthBar.java"), str(source), str(export)], check=True)
for record in mapping["textures"]:
    tree = ET.parse(export / f"shapes/{record['shape_id']}.svg")
    image = tree.find(".//{http://www.w3.org/2000/svg}image")
    png = base64.b64decode(image.attrib["{http://www.w3.org/1999/xlink}href"].split(",")[1])
    assert png[:8] == b"\x89PNG\r\n\x1a\n"
    assert list(struct.unpack(">II", png[16:24])) == record["size"]
    assert hashlib.sha256(png).hexdigest() == record["sha256"], "Bitmap differs from verified original"
    (output / record["file"]).write_bytes(png)
print("PASS exported original monsterBleedBar background/fill, exact original bitmap bytes")
#endregion
