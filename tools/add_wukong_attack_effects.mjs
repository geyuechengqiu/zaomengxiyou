// #region 工具依赖
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
// #endregion

// #region 原版配置与已编辑场景
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sourceRoot = process.argv[2];
if (!sourceRoot) throw new Error('Usage: node tools/add_wukong_attack_effects.mjs <Speculum-4399-master>');
const scenePath = path.join(root, 'data/animation/sunwukong_visual.tscn');
let scene = fs.readFileSync(scenePath, 'utf8').replace(/\r\n/g, '\n');
if (scene.includes('[node name="AttackEffects"')) {
  console.log('AttackEffects exists; preserve authored effect tracks and offsets.');
  process.exit(0);
}
const configPath = 'exports/zmhj_role_stats/原始配置/Skill.json';
const skeletonPath = 'exports/character_2001_all_attack_skill_effects_spine4323/original/attackV427/skeleton.json';
const skills = JSON.parse(fs.readFileSync(path.join(sourceRoot, configPath), 'utf8').replace(/^\uFEFF/, ''));
const original = JSON.parse(fs.readFileSync(path.join(sourceRoot, skeletonPath), 'utf8').replace(/^\uFEFF/, ''));
const fps = original.frameRate;
if (fps !== 30) throw new Error(`Unexpected source frame rate: ${fps}`);
const durations = Object.fromEntries(original.armature.flatMap(a => a.animation.map(c => [c.name, c.duration])));
const specs = [...Array.from({length: 5}, (_, i) => ({action: `attack_${i + 1}`, skill_id: `sunwukong_attack${i + 1}`, sourceId: String(1001010 + i * 10)})),
  {action: "run_attack", skill_id: "sunwukong_run_attack", sourceId: "1001060"},
  {action: "jump_attack", skill_id: "sunwukong_jump_attack", sourceId: "1001070"}];
const mapping = specs.map(({action, skill_id, sourceId}) => {
  return {action, skill_id, source_id: sourceId,
    events: skills[sourceId].param.s.filter(e => e.type === 1).map(e => ({
      animation: e.shootAssetLink, frame: e.shootFrame, duration_frames: durations[e.shootAssetLink],
      offset: [e.x ?? 0, e.y ?? 0], scale: [e.scaleX ?? 1, e.scaleY ?? 1],
      follow_parent: e.followParent, link_parent_state: e.linkParentState, z_sort: e.zSort
    }))};
});
// #endregion
// #region 序列化轨道，仅追加特效，不重建角色动画与攻击框
const valueTrack = (index, target, times, values, mode = 1) => `tracks/${index}/type = "value"
tracks/${index}/imported = false
tracks/${index}/enabled = true
tracks/${index}/path = NodePath("${target}")
tracks/${index}/interp = 1
tracks/${index}/loop_wrap = true
tracks/${index}/keys = {
"times": PackedFloat32Array(${times.join(', ')}),
"transitions": PackedFloat32Array(${times.map(() => 1).join(', ')}),
"update": ${mode},
"values": [${values.join(', ')}]
}
`;
const nativeTrack = (index, target, times, clips) => `tracks/${index}/type = "animation"
tracks/${index}/imported = false
tracks/${index}/enabled = true
tracks/${index}/path = NodePath("${target}")
tracks/${index}/interp = 1
tracks/${index}/loop_wrap = true
tracks/${index}/keys = {
"clips": PackedStringArray(${clips.map(JSON.stringify).join(', ')}),
"times": PackedFloat32Array(${times.join(', ')})
}
`;
const playerPath = name => `AttackEffects/${name}/SpineAnimationTrack/AnimationPlayer`;
const masterNode = scene.match(/\[node name="AnimationPlayer" type="AnimationPlayer" parent="\."[^\n]*\]([\s\S]*?)(?=\n\[|$)/)?.[1];
const masterLibraryId = masterNode?.match(/(?:libraries\/|&"":)\s*(?:=\s*)?SubResource\("([^"]+)"\)/)?.[1];
const escapedId = masterLibraryId?.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const masterLibrary = escapedId && scene.match(new RegExp(`\\[sub_resource type="AnimationLibrary" id="${escapedId}"\\]([\\s\\S]*?)(?=\\n\\[)`))?.[1];
if (!masterLibrary) throw new Error('Cannot locate authored master library; scene left unchanged.');
const masterIds = new Set([...masterLibrary.matchAll(/SubResource\("([^"]+)"\)/g)].map(m => m[1]));
scene = scene.replace(/(\[sub_resource type="Animation"[^\n]+\]\n)([\s\S]*?)(?=\n\[|$)/g, (all, header, body) => {
  const action = body.match(/^resource_name = "([^"]+)"/m)?.[1];
  if (!masterIds.has(header.match(/id="([^"]+)"/)[1])) return all;
  let index = Math.max(...[...body.matchAll(/tracks\/(\d+)\/type/g)].map(m => Number(m[1]))) + 1;
  const length = Number(body.match(/^length = ([^\n]+)/m)?.[1] ?? 1);
  const events = mapping.find(m => m.action === action)?.events ?? [];
  for (const [slot, name] of ['Primary', 'Secondary'].entries()) {
    const event = events[slot];
    let times = [0], visible = ['false'], clips = ['RESET'];
    if (event) {
      const start = event.frame / fps;
      const end = Math.min(length, start + event.duration_frames / fps);
      if (start === 0) { visible[0] = 'true'; clips[0] = event.animation; }
      else { times.push(start); visible.push('true'); clips.push(event.animation); }
      times.push(end); visible.push('false'); clips.push('RESET');
    }
    body += valueTrack(index++, `AttackEffects/${name}:visible`, times, visible);
    body += nativeTrack(index++, playerPath(name), times, clips);
  }
  body += valueTrack(index++, 'AttackEffects:preview_action', [0], [`&"${action}"`]);
  body += valueTrack(index++, 'AttackEffects:preview_time', [0, length], ['0.0', String(length)], 0);
  return header + body;
});
let resources = '';
for (const name of ['RESET', 'attack1', 'attack2', 'attack3', 'attack4', 'attack5', 'runAttack', 'jumpAttack']) {
  resources += `[sub_resource type="Animation" id="AttackEffect_${name}"]
resource_name = "${name}"
length = ${name === 'RESET' ? 0.001 : durations[name] / fps}
${valueTrack(0, '.:animation_name', [0], [JSON.stringify(name === 'RESET' ? '' : name)])}${valueTrack(1, '.:loop', [0], ['false'])}
`;
}
resources += `[sub_resource type="AnimationLibrary" id="AttackEffectLibrary"]
_data = {
${['RESET', 'attack1', 'attack2', 'attack3', 'attack4', 'attack5', 'runAttack', 'jumpAttack'].map(n => `&"${n}": SubResource("AttackEffect_${n}")`).join(',\n')}
}

`;
const firstSub = scene.indexOf('[sub_resource');
scene = scene.slice(0, firstSub) + `[ext_resource type="SpineSkeletonDataResource" path="res://assets/skelton/char/sunwukong/effects/skill_wukong_data.tres" id="attack_effect_data"]\n[ext_resource type="Script" path="res://addons/battle_foundation/animation/spine_animation_effects_2d.gd" id="attack_effect_preview"]\n\n` + scene.slice(firstSub);
scene = scene.replace('[node name="AnimationAdapter"', resources + '[node name="AnimationAdapter"');
scene += `
[node name="AttackEffects" type="Node2D" parent="."]
z_index = 1
scale = Vector2(2, 2)
script = ExtResource("attack_effect_preview")
`;
for (const [slot, name] of ['Primary', 'Secondary'].entries()) {
  const event = mapping[3].events[slot];
  scene += `
[node name="${name}" type="SpineSprite" parent="AttackEffects"]
visible = false
position = Vector2(${event.offset.join(', ')})
scale = Vector2(${event.scale.join(', ')})
skeleton_data_res = ExtResource("attack_effect_data")
preview_animation = "${slot === 0 ? 'attack1' : 'attack4'}"
preview_frame = false
preview_time = 0.0

[node name="SpineAnimationTrack" type="SpineAnimationTrack" parent="AttackEffects/${name}"]
track_index = 0
mix_duration = 0.0

[node name="AnimationPlayer" type="AnimationPlayer" parent="AttackEffects/${name}/SpineAnimationTrack"]
libraries/ = SubResource("AttackEffectLibrary")
`;
}
fs.writeFileSync(scenePath, scene);
fs.writeFileSync(path.join(root, 'data/animation/sunwukong_attack_effects_source.json'), JSON.stringify({
  source_fps: fps, config: configPath, skeleton: skeletonPath,
  skeleton_sha256: crypto.createHash('sha256').update(fs.readFileSync(path.join(sourceRoot, skeletonPath))).digest('hex'),
  source_controller: 'out/zmhj-equip-skill-diag/com/wdcgame/engine/entitys/controls/skill/SkillControl.as',
  asset: 'res://assets/skelton/char/sunwukong/effects/skill_wukong_data.tres',
  display_scale: 2, actions: mapping
}, null, 2) + '\n');
console.log('Added eight original VFX events to seven authored attacks; other tracks and jump_2 preserved.');
// #endregion
