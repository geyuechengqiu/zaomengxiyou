// #region 本地原版配置输入
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = process.argv[2];
if (!source) throw new Error('Usage: node tools/import_wukong_combo.mjs <Speculum-4399-master>');
const read = name => JSON.parse(fs.readFileSync(path.join(source, name), 'utf8'));
const skills = read('exports/zmhj_role_stats/原始配置/Skill.json');
const skeleton = read('exports/character_2001_wukong_placeholders/dragonbones56/1_V427/1_V427_ske.json');
const frames = Object.fromEntries(skeleton.armature[0].animation.map(a=>[a.name,a.duration]));
const folder = path.join(root,'data/battle2d');
const previousCombo = fs.existsSync(path.join(folder,'sunwukong_combo.tres')) ? fs.readFileSync(path.join(folder,'sunwukong_combo.tres'),'utf8') : '';
const previousStep4 = previousCombo.match(/\[sub_resource[^\n]*id="Step4"[^\n]*\]([\s\S]*?)(?=\n\[|$)/)?.[1] ?? '';
const step4Number = (name, fallback) => Number(previousStep4.match(new RegExp(`^${name} = ([^\\n]+)`, 'm'))?.[1] ?? fallback);
const motionSpeed = step4Number('root_motion_speed', 300);
const motionFrames = step4Number('root_motion_frames', 16);
const turnStart = step4Number('turn_window_start_frame', 8);
const turnEnd = step4Number('turn_window_end_frame', 16);
const hitboxes = readProject('data/characters/sunwukong/skills/attack_hitboxes_source.json');
if (crypto.createHash('sha256').update(fs.readFileSync(path.join(source,hitboxes.source_path))).digest('hex') !== hitboxes.sha256)
  throw new Error('Attack asset changed: regenerate attack_hitboxes_source.json with tools/extract_wukong_hitboxes.py');
// #endregion
// #region 独立技能与只读连击段
const stepExt = '[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_attack_step_2d.gd" id="step"]';
let combo = `[gd_resource type="Resource" script_class="BattleComboDefinition" format=3]\n[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_combo_definition.gd" id="script"]\n${stepExt}\n`;
const manifest=readProject('data/battle2d/manifest.json');
const sourceSteps=[];
for(let i=1;i<=5;i++) {
  const original=skills[String(1001000+i*10)];
  const id=`sunwukong_attack${i}`, action=`attack_${i}`, duration=frames[original.actionName];
  const impacts=original.param.s.filter(e=>e.type===1 && e.hasDamage).sort((a,b)=>a.shootFrame-b.shootFrame);
  const hitbox=hitboxes.rectangles.find(e=>e.name===`ab_attack${i}0000`);
  if (!hitbox) throw new Error(`Missing native ABRect for attack${i}`);
  let skill=`[gd_resource type="Resource" script_class="GameplayAbilityDefinition" format=3]\n[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/gameplay_ability_definition.gd" id="definition"]\n[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/features/gameplay_ability_feature.gd" id="feature_type"]\n[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/features/cooldown_feature.gd" id="cooldown"]\n[ext_resource type="Script" path="res://addons/battle_foundation/gas/battle_frame_timeline_feature.gd" id="timeline"]\n[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_frame_event.gd" id="event"]\n\n[sub_resource type="Resource" id="Cooldown"]\nscript = ExtResource("cooldown")\ncooldown_duration = 0.0\n`;
  impacts.forEach((event,index)=>{
    skill+=`\n[sub_resource type="Resource" id="Impact${index}"]\nscript = ExtResource("event")\nsource_frame = ${event.shootFrame}\nevent_id = &"battle.attack.impact"\npayload = {"action": &"${action}", "combo_step": ${i}, "hit_index": ${index+1}, "damage_multiplier": ${original.skillDefault}, "hit_rect": Rect2(${hitbox.rect.join(', ')}), "hit_scale_x": ${event.scaleX??1}, "hit_scale_y": ${event.scaleY??1}, "hit_offset": Vector2(${event.x??0}, ${event.y??0})}\n`;
  });
  skill+=`\n[sub_resource type="Resource" id="Timeline"]\nscript = ExtResource("timeline")\nsource_fps = 30.0\nduration_frames = ${duration}\nevents = Array[ExtResource("event")]([${impacts.map((e,index)=>`SubResource("Impact${index}")`).join(', ')}])\n\n[resource]\nscript = ExtResource("definition")\nability_id = &"${id}"\nability_name = "${original.name}"\nfeatures = Array[ExtResource("feature_type")]([SubResource("Cooldown"), SubResource("Timeline")])\n`;
  fs.writeFileSync(path.join(folder,`attack${i}.tres`),skill);
  combo+=`\n[sub_resource type="Resource" id="Step${i}"]\nscript = ExtResource("step")\nability_id = &"${id}"\naction = &"${action}"\nduration_frames = ${duration}\nsource_fps = 30.0\nallow_jump_cancel = ${original.breakByActionNames?.split(';').includes('jumpNormal')?'true':'false'}\n`;
  if(i===4)combo+=`root_motion_speed = ${motionSpeed}\nroot_motion_frames = ${motionFrames}\nturn_window_start_frame = ${turnStart}\nturn_window_end_frame = ${turnEnd}\n`;
  manifest.definitions.skills[id]=`res://data/battle2d/attack${i}.tres`;
  sourceSteps.push({id,source_skill_id:original.id,action,source_action:original.actionName,duration_frames:duration,impact_frames:impacts.map(e=>e.shootFrame),damage_multiplier:original.skillDefault,can_walk:original.canWalk,jump_cancel:original.breakByActionNames,hitbox,impact_definitions:impacts});
}
combo+=`\n[resource]\nscript = ExtResource("script")\nsteps = Array[ExtResource("step")]([${[1,2,3,4,5].map(i=>`SubResource("Step${i}")`).join(', ')}])\n`;
fs.writeFileSync(path.join(folder,'sunwukong_combo.tres'),combo);
fs.writeFileSync(path.join(folder,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
// #endregion
// #region 来源记录
const files=['exports/zmhj_role_stats/原始配置/Skill.json','exports/character_2001_wukong_placeholders/dragonbones56/1_V427/1_V427_ske.json','out/zmhj-equip-skill-diag/com/wdcgame/engine/entitys/CharEntity.as',hitboxes.source_path,'out/zmhj-equip-skill-diag/com/wdcgame/engine/entitys/controls/skill/SkillControl.as','out/zmhj-equip-skill-diag/com/wdcgame/engine/model/ManResourceVO.as'];
fs.writeFileSync(path.join(folder,'combo_source_mapping.json'),JSON.stringify({source_project:'Speculum-4399-master',source_fps:30,steps:sourceSteps,chain_policy:'press during current segment queues one next segment; no hold auto-repeat; completion gates segment transition',movement_policy:`player input blocked; attack4 uses configured ${motionSpeed} world units/sec for ${motionFrames}/30 sec; startup motion facing is independent of one-shot turn in [${turnStart},${turnEnd})`,landing_policy:'explicit one-frame battle state using existing idle visual; original skeleton has no separate landing clip',jump_policy:'two jumps; jumpTwo uses original 8-frame animation; platform velocities are Godot calibration values',sources:files.map(file=>({path:file,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(source,file))).digest('hex')}))},null,2)+'\n');
function readProject(file){return JSON.parse(fs.readFileSync(path.join(root,file),'utf8'));}
console.log('Imported 5 Wukong combo abilities, 6 impact markers and source audit.');
// #endregion
