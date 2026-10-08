// #region 阶段7离线资源与预置场景生成
import fs from 'node:fs';
import path from 'node:path';
const root = path.resolve(import.meta.dirname, '..');
const directory = path.join(root, 'data/battle2d/skill_timeline');
fs.mkdirSync(directory, { recursive: true });
const write = (name, text) => fs.writeFileSync(path.join(directory, name), text + '\n');
const script = (file, id) => `[ext_resource type="Script" path="res://${file}" id="${id}"]`;
let skill = `[gd_resource type="Resource" script_class="GameplayAbilityDefinition" format=3]
${script('addons/gameplay_abiltiy_system/scripts/abilities/gameplay_ability_definition.gd', 'definition')}
${script('addons/gameplay_abiltiy_system/scripts/abilities/features/gameplay_ability_feature.gd', 'feature')}
${script('addons/battle_foundation/gas/battle_frame_timeline_feature.gd', 'timeline')}
${script('addons/battle_foundation/definitions/battle_attack_segment.gd', 'segment')}
${script('addons/battle_foundation/definitions/battle_skill_branch.gd', 'branch')}
${script('addons/battle_foundation/definitions/battle_skill_motion.gd', 'motion')}
${script('addons/battle_foundation/definitions/battle_frame_event.gd', 'event')}
${script('addons/gameplay_abiltiy_system/scripts/abilities/features/cost_feature.gd', 'cost')}
${script('addons/gameplay_abiltiy_system/scripts/abilities/costs/ability_cost_base.gd', 'cost_type')}
${script('addons/gameplay_abiltiy_system/scripts/abilities/costs/vital_cost.gd', 'vital_cost')}
${script('addons/gameplay_abiltiy_system/scripts/abilities/features/cooldown_feature.gd', 'cooldown')}
`;
const multipliers = [0.5, 1.0, 1.5], fixed = [0, 3, 5], speeds = [60, 120, 180];
for (let i = 0; i < 3; i++) skill += `
[sub_resource type="Resource" id="hit${i + 1}"]
script = ExtResource("segment")
segment_id = &"hit_${i + 1}"
hit_index = ${i + 1}
start_frame = ${4 + i * 8}
end_frame = ${6 + i * 8}
action = &"attack_${i + 1}"
damage_multiplier = ${multipliers[i]}
fixed_damage = ${fixed[i]}
knockback_speed = ${speeds[i]}
knockback_duration = ${0.08 + i * 0.04}
launch_speed = ${i === 2 ? 220 : 0}
hit_stun = ${[0.12, 0.2, 0.3][i]}
protection_value = ${10 * (i + 1)}
`;
for (let i = 0; i < 3; i++) skill += `
[sub_resource type="Resource" id="animation${i + 1}"]
script = ExtResource("event")
source_frame = ${i * 8}
event_id = &"battle.skill.animation"
payload = {"action": &"attack_${i + 1}"}
`;
skill += `
[sub_resource type="Resource" id="effect"]
script = ExtResource("event")
source_frame = 2
event_id = &"battle.skill.object"
payload = {"object_path": NodePath("SkillTrail"), "spawn_offset": Vector2(65, -110), "lifetime": 0.5}
[sub_resource type="Resource" id="later_effect"]
script = ExtResource("event")
source_frame = 26
event_id = &"battle.skill.object"
payload = {"object_path": NodePath("SkillTrail"), "spawn_offset": Vector2(95, -110), "lifetime": 0.5}
[sub_resource type="Resource" id="branch"]
script = ExtResource("branch")
start_frame = 28
end_frame = 38
buffer_frames = 8
target_ability_id = &"sunwukong_attack1"
[sub_resource type="Resource" id="motion"]
script = ExtResource("motion")
start_frame = 0
end_frame = 3
velocity = Vector2(90, 0)
[sub_resource type="Resource" id="mana"]
script = ExtResource("vital_cost")
amount = 10.0
[sub_resource type="Resource" id="cost"]
script = ExtResource("cost")
costs = Array[ExtResource("cost_type")]([SubResource("mana")])
[sub_resource type="Resource" id="timeline"]
script = ExtResource("timeline")
duration_frames = 40
commit_resources = true
animation_action = &"attack_1"
attack_segments = Array[ExtResource("segment")]([SubResource("hit1"), SubResource("hit2"), SubResource("hit3")])
events = Array[ExtResource("event")]([SubResource("animation1"), SubResource("effect"), SubResource("animation2"), SubResource("animation3"), SubResource("later_effect")])
branch_windows = Array[ExtResource("branch")]([SubResource("branch")])
motion_windows = Array[ExtResource("motion")]([SubResource("motion")])
[sub_resource type="Resource" id="cooldown"]
script = ExtResource("cooldown")
cooldown_duration = 0.8
[resource]
script = ExtResource("definition")
ability_id = &"sunwukong_timeline_attack"
ability_name = "悟空三段时间轴验收技能（测试数值）"
features = Array[ExtResource("feature")]([SubResource("cost"), SubResource("timeline"), SubResource("cooldown")])`;
write('three_hit.tres', skill);
write('actions.tres', `[gd_resource type="Resource" script_class="BattleActionProfile2D" format=3]
${script('addons/battle_foundation/definitions/battle_action_profile_2d.gd', 'script')}
[resource]
script = ExtResource("script")
attack_skill_id = &"sunwukong_timeline_attack"`);
write('sunwukong_2d.tscn', `[gd_scene format=3]
[ext_resource type="PackedScene" path="res://data/battle2d/single_attack/sunwukong_2d.tscn" id="base"]
[ext_resource type="Resource" path="res://data/battle2d/skill_timeline/actions.tres" id="actions"]
[ext_resource type="Resource" path="res://data/battle2d/skill_timeline/three_hit.tres" id="skill"]
${script('addons/gameplay_abiltiy_system/scripts/abilities/gameplay_ability_definition.gd', 'ability_type')}
${script('addons/battle_foundation/presentation/battle_timeline_object_2d.gd', 'object')}
[node name="SunWukongTimeline" instance=ExtResource("base")]
action_profile = ExtResource("actions")
[node name="AttackHitbox" parent="AnimationAdapter" index="4"]
preview_abilities = Array[ExtResource("ability_type")]([ExtResource("skill")])
[node name="SkillTrail" type="Node2D" parent="."]
visible = false
script = ExtResource("object")
[node name="Trail" type="Polygon2D" parent="SkillTrail"]
polygon = PackedVector2Array(-36, -18, 36, -6, 52, 0, 36, 6, -36, 18, -14, 0)
color = Color(1, 0.8, 0.3, 0.7)
[editable path="AnimationAdapter"]`);
let character = fs.readFileSync(path.join(root, 'data/battle2d/single_attack/sunwukong.tres'), 'utf8');
character = character.replace('single_attack/sunwukong_2d.tscn', 'skill_timeline/sunwukong_2d.tscn').replace('[&"sunwukong_attack1"]', '[&"sunwukong_timeline_attack", &"sunwukong_attack1"]');
write('sunwukong.tres', character.trim());
let attributes = fs.readFileSync(path.join(root, 'data/battle2d/dummy/attributes.tres'), 'utf8').replace(': 70.0', ': 500.0');
write('dummy_attributes.tres', attributes.trim());
let dummy = fs.readFileSync(path.join(root, 'data/battle2d/dummy/wooden_dummy.tres'), 'utf8').replace('dummy/attributes.tres', 'skill_timeline/dummy_attributes.tres');
write('dummy.tres', dummy.trim());
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'data/battle2d/single_attack/manifest.json'), 'utf8'));
manifest.definitions.characters['孙悟空'] = 'res://data/battle2d/skill_timeline/sunwukong.tres';
manifest.definitions.skills.sunwukong_timeline_attack = 'res://data/battle2d/skill_timeline/three_hit.tres';
manifest.definitions.monsters['木桩'] = 'res://data/battle2d/skill_timeline/dummy.tres';
manifest.definitions.statuses.attribute_test_buff = 'res://data/battle2d/statuses/attribute_test_buff.tres';
write('manifest.json', JSON.stringify(manifest, null, 2));
// 生成独立场景；GAS、控制器与运行组件继承自角色场景。
let scene = fs.readFileSync(path.join(root, 'examples/single_attack_demo.tscn'), 'utf8')
  .replace(/ uid="uid:\/\/[^\"]+"/g, '')
  .replace('res://examples/single_attack_demo.gd', 'res://examples/skill_timeline_demo.gd')
  .replace('res://data/battle2d/single_attack/sunwukong_2d.tscn', 'res://data/battle2d/skill_timeline/sunwukong_2d.tscn')
  .replace('SingleAttackDemo', 'SkillTimelineDemo')
  .replace('res://data/battle2d/single_attack/manifest.json', 'res://data/battle2d/skill_timeline/manifest.json')
  .replace('scene_seed = 6001', 'scene_seed = 7001')
  .replace('孙悟空 · 单段普攻测试', '阶段7 · 技能时间轴、派生与三段攻击')
  .replace('攻击 [J]', '三段攻击 J')
  .replace(/text = "A \/ D 移动[^\"]*"/, 'text = "A / D 移动 · K 跳跃 · J 三段攻击 · 再按 J 后摇派生 · Esc 菜单\n三段：0.5× / 1×+3 / 1.5×+5 · 不同击退，末段浮空 · 消耗10魔法"')
  .replace('[node name="PlayerOperations" parent="BattleSession/Actors/SunWukong"]', '[node name="PlayerOperations" parent="BattleSession/Actors/SunWukong"]\nability_slots = {&"skill_1": &"sunwukong_timeline_attack"}');
scene += '\n[node name="Cancel" type="Button" parent="HUD/Panel/Column/Buttons"]\nlayout_mode = 2\nfocus_mode = 0\ntext = "取消技能"\n';
fs.writeFileSync(path.join(root, 'examples/skill_timeline_demo.tscn'), scene);
console.log('Generated authored stage 7 resources and scene.');
// #endregion
