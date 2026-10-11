// #region 模块导入
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
// #endregion

// #region 原版只读成长导入
const root = path.resolve(import.meta.dirname, '..');
const sourceRoot = process.argv[2];
if (!sourceRoot) throw new Error('Usage: node tools/import_attribute_progression.mjs <Speculum root>');
const sourceDir = path.join(sourceRoot, 'exports/zmhj_role_stats/原始配置');
const read = name => JSON.parse(fs.readFileSync(path.join(sourceDir, name), 'utf8'));
const role = read('Role.json')['2001'];
const experience = read('EXP.json');
const levels = Object.keys(experience).map(Number).sort((a, b) => a - b);
if (levels.some((level, index) => level !== index + 1)) throw new Error('EXP levels are not contiguous');
const write = (relative, contents) => { const target = path.join(root, relative); fs.mkdirSync(path.dirname(target), {recursive: true}); fs.writeFileSync(target, contents, 'utf8'); };
for (const [id, name, initial, minimum] of [['level', '等级', 1, 1], ['exp', '本级经验', 0, 0]]) {
  write(`data/attribute/${id}.tres`, `[gd_resource type="Resource" script_class="GameplayAttribute" format=3]\n[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/attributes/gameplay_attribute.gd" id="script"]\n[resource]\nscript = ExtResource("script")\nattribute_id = &"${id}"\nattribute_display_name = "${name}"\nmin_value = ${minimum}.0\nround_final_value = true\n`);
}
write('data/attribute/sets/progression_attributes.tres', `[gd_resource type="Resource" script_class="GameplayAttributeSet" format=3]
[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/attributes/gameplay_attribute_set.gd" id="script"]
[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/attributes/gameplay_attribute.gd" id="attr"]
[ext_resource type="Resource" path="res://data/attribute/level.tres" id="level"]
[ext_resource type="Resource" path="res://data/attribute/exp.tres" id="exp"]
[resource]
script = ExtResource("script")
attributes = Dictionary[ExtResource("attr"), float]({ExtResource("level"): 1.0, ExtResource("exp"): 0.0})
`);
const growth = Object.fromEntries(['hpMax', 'mpMax', 'atk', 'phyDef'].map(id => [id, role[id + 'Add']]));
write('data/characters/sunwukong/attributes/progression.tres', `[gd_resource type="Resource" script_class="BattleAttributeProgression" format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_attribute_progression.gd" id="script"]
[ext_resource type="Resource" path="res://data/attribute/sets/progression_attributes.tres" id="attributes"]
[resource]
script = ExtResource("script")
attribute_set = ExtResource("attributes")
growth_per_level = Dictionary[StringName, float]({${Object.entries(growth).map(([id, value]) => `&"${id}": ${value}`).join(', ')}})
experience_per_level = Array[float]([${levels.map(level => experience[level].upgradeEXP).join(', ')}])
maximum_level = ${levels.length}
`);
write('data/characters/sunwukong/attributes/source_mapping.json', JSON.stringify({runtime_character_id: '孙悟空', source_role_id: 2001, growth, experience_semantics: '本级经验，升级逐级扣除 upgradeEXP', maximum_level: levels.length, maximum_level_note: '导入 EXP 表覆盖范围；产品等级上限可单独配置，不推定 CommonConfig.levelMax', files: ['Role.json', 'EXP.json'].map(file => ({file, sha256: crypto.createHash('sha256').update(fs.readFileSync(path.join(sourceDir, file))).digest('hex')})), implementation: 'exports/zmhj_damage_formulas/sources/models/vo/UserVO.as:451-513', policies: {level_up: 'fill_base_growth_equipment_excluding_temporary', equipment: 'keep_current_clamp', temporary: 'keep_current_clamp', level_down: 'keep_current_clamp'}}, null, 2) + '\n');
console.log(`Imported 孙悟空 growth ${JSON.stringify(growth)} and ${levels.length} EXP rows`);
// #endregion
