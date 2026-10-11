"""Export shipped PowerAttribute[1], Role.powerCorrection and exact provenance."""
import argparse
import hashlib
import json
from pathlib import Path
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("reference", type=Path)
    args = parser.parse_args()
    sys.path.insert(0, str(args.reference.resolve()))
    from backends.zmhj_config import load_config_table, find_config_archive
    game = args.reference / "games/zmhj-g5"
    archive = find_config_archive(game)
    weights = load_config_table(game, "PowerAttribute")["1"]
    role = load_config_table(game, "Role")["2001"]
    fields = ["hpMax", "mpMax", "atk", "phyDef", "hit", "dodge", "critical", "toughness", "lucky", "guardian", "reHP", "reMP"]
    methods = ["com/ywxgame/models/manager/FightPowerManager.as", "modules/backpack/view/BodyView.as"]
    root = args.reference / "out/zmhj-equip-skill-diag"
    evidence = {
        "source": "PowerAttribute[1]; FightPowerManager.getFightPowerByItemVo; BodyView.updateFight; Tips[684]",
        "archive": str(archive.resolve()), "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
        "logic": {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in methods},
        "weights": {field: weights[field] for field in fields},
        "roles": {"孙悟空": {"source_role_id": 2001, "powerCorrection": role["powerCorrection"],
                              "base_attributes": {field: role.get(field) or 0 for field in fields},
                              "growth_per_level": {field: role[field + "Add"] for field in fields[:4]}}},
        "original_tip": load_config_table(game, "Tips")["684"]["contentText"],
    }
    destination = Path(__file__).resolve().parent.parent / "data/ui/fight_power_weights.json"
    destination.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Exported original PowerAttribute[1] and Sun Wukong powerCorrection=" + str(role["powerCorrection"]))


if __name__ == "__main__":
    main()
