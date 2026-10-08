"""离线导出阶段10基础Buff与组合被动；运行游戏不依赖原版目录。"""
# region 读取原版配置与构建GAS资源
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--source", type=Path, default=Path("D:/UserData/Downloads/game/Speculum-4399-master"))
args = parser.parse_args()
source_file = args.source / "exports/zmhj_role_stats/原始配置/Buff.json"
original = json.loads(source_file.read_text(encoding="utf-8"))
directory = ROOT / "data/buffs"
directory.mkdir(parents=True, exist_ok=True)
GAS = "addons/gameplay_abiltiy_system/scripts"
BATTLE = "addons/battle_foundation/gas"
IDS = {"attack_up": 8030701, "slow": 21004401, "stun": 2000201, "poison": 5019101,
       "shield": 26002408, "invulnerable": 1000101, "super_armor": 6000301,
       "reflection": 15000101, "lifesteal": 81101001}

def ext(path, name):
    return f'[ext_resource type="Script" path="res://{path}" id="{name}"]'

def write(name, content):
    (directory / f"{name}.tres").write_text(content + "\n", encoding="utf-8")

def number(row, key):
    return row.get(key) or 0

def basic(name, row):
    lines = ['[gd_resource type="Resource" script_class="GameplayStatusData" format=3]',
             ext(f"{GAS}/status/gameplay_status_data.gd", "status"),
             ext(f"{GAS}/effects/gameplay_effect.gd", "effect_type"),
             ext(f"{GAS}/status/features/status_feature.gd", "feature_type"),
             ext(f"{BATTLE}/battle_original_status_policy.gd", "policy")]
    effects, features = [], []
    if name == "attack_up":
        lines += [ext(f"{BATTLE}/ge_original_buff_attribute.gd", "effect"),
                  '[sub_resource type="Resource" id="effect"]', 'script = ExtResource("effect")',
                  'attribute_id = &"atk"', f'ratio = {number(row, "attributeV1")}', f'fixed_bonus = {number(row, "attributeV3")}']
        effects = ["effect"]
    elif name == "slow":
        lines += [ext(f"{GAS}/effects/ge_attribute_modifier.gd", "effect"),
                  ext(f"{GAS}/attributes/gameplay_attribute_modifier.gd", "modifier")]
        for key in ["walkSpeed", "runSpeed"]:
            lines += [f'[sub_resource type="Resource" id="{key}"]', 'script = ExtResource("modifier")',
                      f'attribute_id = &"{key}"', f'value = {number(row, "attributeV1")}', 'modifier_type = 1']
        lines += ['[sub_resource type="Resource" id="effect"]', 'script = ExtResource("effect")',
                  'modifiers = Array[ExtResource("modifier")]([SubResource("walkSpeed"), SubResource("runSpeed")])']
        effects = ["effect"]
    elif name == "poison":
        lines += [ext(f"{BATTLE}/ge_original_periodic_vital.gd", "effect"),
                  ext(f"{GAS}/status/features/feature_periodic_effects.gd", "periodic"),
                  '[sub_resource type="Resource" id="effect"]', 'script = ExtResource("effect")',
                  f'health_ratio = {number(row, "attributeV1")}', f'attack_ratio = {number(row, "attributeV2")}', f'fixed_delta = {number(row, "attributeV3")}',
                  '[sub_resource type="Resource" id="periodic"]', 'script = ExtResource("periodic")',
                  'feature_name = "poison_tick"', f'period = {number(row, "interval")}',
                  'periodic_effects = Array[ExtResource("effect_type")]([SubResource("effect")])']
        features = ["periodic"]
    elif name == "shield":
        lines += [ext(f"{BATTLE}/ge_original_shield.gd", "effect"),
                  '[sub_resource type="Resource" id="effect"]', 'script = ExtResource("effect")',
                  f'health_ratio = {number(row, "attributeV1")}', f'attack_ratio = {number(row, "attributeV2")}', f'fixed_amount = {number(row, "attributeV3")}']
        effects = ["effect"]
    elif name == "lifesteal":
        lines += [ext(f"{BATTLE}/ge_battle_damage_rules.gd", "effect"),
                  '[sub_resource type="Resource" id="effect"]', 'script = ExtResource("effect")',
                  f'rules = {{&"lifeStealRatio": {number(row, "attributeV1")}, &"lifeStealCap": {number(row, "attributeV2")}}}']
        effects = ["effect"]
    elif name == "reflection":
        lines += [ext(f"{BATTLE}/ge_battle_reflect_damage.gd", "effect"),
                  ext(f"{BATTLE}/battle_trigger_feature.gd", "trigger"),
                  '[sub_resource type="Resource" id="effect"]', 'script = ExtResource("effect")', f'ratio = {number(row, "attributeV1")}',
                  '[sub_resource type="Resource" id="trigger"]', 'script = ExtResource("trigger")',
                  'feature_name = "original_reflection"', 'trigger_on_events = Array[StringName]([&"battle.damage.received"])',
                  'owner_role = 1', 'effect_target = 1', 'effects = Array[ExtResource("effect_type")]([SubResource("effect")])']
        features = ["trigger"]
    tags = ["status.debuff" if row.get("isDebuff") else "status.buff"]
    tags += {"stun": ["state.stunned"], "invulnerable": ["state.invulnerable"], "super_armor": ["state.super_armor"]}.get(name, [])
    lines += ['[sub_resource type="Resource" id="policy"]', 'script = ExtResource("policy")', f'replace_rule = {row["replaceRule"]}',
              '[resource]', 'script = ExtResource("status")', f'status_id = &"{name}"', f'status_display_name = "{row["name"]}"',
              f'duration = {row["totalTime"]}', 'stacking_policy = SubResource("policy")', f'max_stacks = {max(1, row.get("stackMax", 0))}',
              f'stacking_group = &"original.{row["group"]}/{row.get("attributeT") or ""}"',
              'tags = Array[StringName]([' + ', '.join(f'&"{tag}"' for tag in tags) + '])',
              f'metadata/original_buff_id = {row["id"]}', f'metadata/original_type = {row["type"]}']
    if name == "poison" and row.get("isImmediate"):
        lines.append('initial_update_delta = 0.03333333333333333')
    if effects:
        lines.append('apply_effects = Array[ExtResource("effect_type")]([' + ', '.join(f'SubResource("{x}")' for x in effects) + '])')
    if features:
        lines.append('features = Array[ExtResource("feature_type")]([' + ', '.join(f'SubResource("{x}")' for x in features) + '])')
    write(name, "\n".join(lines))

for name, original_id in IDS.items():
    basic(name, original[str(original_id)])
# endregion
# region 组合被动：验证统一触发入口，不冒充已移植的原角色技能
for name, event, role, recipient, child in [
    ("passive_cast_attack", "battle.skill.cast", 0, 0, "attack_up"),
    ("passive_hit_poison", "battle.hit.effective", 0, 2, "poison"),
    ("passive_received_attack", "battle.damage.received", 1, 0, "attack_up"),
    ("passive_low_health_shield", "battle.health.changed", 1, 0, "shield"),
    ("passive_kill_heal", "battle.entity.killed", 0, 0, None)]:
    lines = ['[gd_resource type="Resource" script_class="GameplayStatusData" format=3]',
             ext(f"{GAS}/status/gameplay_status_data.gd", "status"), ext(f"{GAS}/effects/gameplay_effect.gd", "effect_type"),
             ext(f"{GAS}/status/features/status_feature.gd", "feature_type"), ext(f"{BATTLE}/battle_trigger_feature.gd", "trigger")]
    if child:
        lines += [ext(f"{GAS}/effects/ge_apply_status.gd", "effect"),
                  f'[ext_resource type="Resource" path="res://data/buffs/{child}.tres" id="child"]',
                  '[sub_resource type="Resource" id="effect"]', 'script = ExtResource("effect")', 'status_data = ExtResource("child")']
    else:
        lines += [ext(f"{GAS}/effects/ge_modify_vital.gd", "effect"), '[sub_resource type="Resource" id="effect"]',
                  'script = ExtResource("effect")', 'vital_id = &"health"', 'amount = 25.0']
    lines += ['[sub_resource type="Resource" id="trigger"]', 'script = ExtResource("trigger")', f'feature_name = "{name}_trigger"',
              f'trigger_on_events = Array[StringName]([&"{event}"])', f'owner_role = {role}', f'effect_target = {recipient}',
              'effects = Array[ExtResource("effect_type")]([SubResource("effect")])', 'cooldown = 1.0']
    if name == "passive_low_health_shield":
        lines.append('health_threshold = 0.3')
    lines += ['[resource]', 'script = ExtResource("status")', f'status_id = &"{name}"', f'status_display_name = "组合被动验收：{name}"',
              'duration = -1.0', 'features = Array[ExtResource("feature_type")]([SubResource("trigger")])', 'metadata/test_composition = true']
    write(name, "\n".join(lines))

manifest = json.loads((ROOT / "data/battle2d/hit_reaction/manifest.json").read_text(encoding="utf-8"))
for file in directory.glob("*.tres"):
    manifest["definitions"]["statuses"][file.stem] = f"res://data/buffs/{file.name}"
target = ROOT / "data/battle2d/buffs"
target.mkdir(parents=True, exist_ok=True)
(target / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
(directory / "original_config.json").write_text(json.dumps({name: original[str(id)] for name, id in IDS.items()}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
mapping = {"source": str(source_file), "sha256": hashlib.sha256(source_file.read_bytes()).hexdigest(), "statuses": IDS, "scope": "PvE common types 1/2/5/6/8/15/21/81/262; composition passives are test resources"}
(directory / "source_mapping.json").write_text(json.dumps(mapping, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
# region 保留可独立核对的原版证据，不将原游戏作为运行依赖
sources = directory / "sources"
sources.mkdir(exist_ok=True)
evidence = ["# 阶段10原版源码证据", "", "以下为只读节选；行号针对原仓库完整文件，不能作为独立脚本运行。", ""]
for relative, ranges in [
    ("exports/zmhj_character_state_control/sources/com/wdcgame/engine/model/buff/BuffManager.as", [(267, 284), (453, 519), (626, 689)]),
    ("exports/zmhj_character_state_control/sources/com/wdcgame/engine/model/buff/BuffVO.as", [(122, 191)]),
    ("out/zmhj-equip-skill-diag/prefabs/scripts/ManEntity.as", [(2365, 2385), (2846, 2872), (3371, 3443), (3621, 3648)]),
    ("exports/zmhj_damage_formulas/sources/prefabs/controls/DamageControl.as", [(914, 940), (1756, 1800)]),
    ("out/zmhj-equip-skill-diag/com/wdcgame/engine/model/UserVOBase.as", [(612, 629)])]:
    source = args.source / relative
    lines = source.read_text(encoding="utf-8").splitlines()
    evidence += [f"## {relative}", "", f"SHA256: `{hashlib.sha256(source.read_bytes()).hexdigest()}`", ""]
    for start, end in ranges:
        evidence += [f"原文件第 {start}–{end} 行：", "", "```actionscript", *lines[start-1:end], "```", ""]
(sources / "original-buff-evidence.md").write_text("\n".join(evidence), encoding="utf-8")
# endregion
print(f"Exported {len(IDS)} original Buff configurations and 5 composition passives.")
# endregion
