// #region 脚本实现
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { generateSystemDiagrams } from './system_diagrams.mjs';
import { generateSourceIndex } from './generate_source_index.mjs';

// Source-controlled SVGs; no package installation or external rendering service.
const directory = path.dirname(fileURLToPath(import.meta.url));
const escape = value => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const colors = { config: '#eaf3ff', runtime: '#e9f8f2', effect: '#fff3df', service: '#f1edff' };
function text(x, y, value, css = 'body', anchor = 'start') {
  return `<text x="${x}" y="${y}" class="${css}" text-anchor="${anchor}">${escape(value)}</text>`;
}
function diagram(name, width, height, title, subtitle, body) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img" aria-labelledby="title description">
<title id="title">${escape(title)}</title><desc id="description">${escape(subtitle)}</desc>
<defs>
  <marker id="arrow" viewBox="0 0 10 10" refX="10" refY="5" markerWidth="9" markerHeight="9" orient="auto-start-reverse"><path d="M0 0L10 5L0 10" fill="none" stroke="#52637a" stroke-width="1.4"/></marker>
  <marker id="inherit" viewBox="0 0 16 16" refX="16" refY="8" markerWidth="13" markerHeight="13" orient="auto"><path d="M0 0L16 8L0 16Z" fill="white" stroke="#52637a" stroke-width="1.4"/></marker>
  <marker id="owned" viewBox="-9 -7 18 14" refX="0" refY="0" markerWidth="13" markerHeight="11" orient="auto"><path d="M-8 0L0 -6L8 0L0 6Z" fill="#52637a" stroke="#52637a"/></marker>
  <marker id="shared" viewBox="-9 -7 18 14" refX="0" refY="0" markerWidth="13" markerHeight="11" orient="auto"><path d="M-8 0L0 -6L8 0L0 6Z" fill="white" stroke="#52637a"/></marker>
</defs>
<style>
  text{font-family:'Microsoft YaHei','Noto Sans CJK SC',Arial,sans-serif;fill:#243449}
  .title{font-size:34px;font-weight:700}.subtitle{font-size:20px;fill:#53657c}
  .name{font-family:Consolas,'Microsoft YaHei',monospace;font-size:22px;font-weight:700}
  .type{font-size:16px;fill:#596c84}.body{font-family:Consolas,'Microsoft YaHei',monospace;font-size:18px}
  .label{font-size:17px;paint-order:stroke;stroke:#fbfcff;stroke-width:6px;stroke-linejoin:round}
  .note{font-size:19px;fill:#52637a}.step{font-size:22px;font-weight:700}
  .edge{fill:none;stroke:#52637a;stroke-width:2}.dependency{stroke-dasharray:8 6}
</style>
<rect width="${width}" height="${height}" fill="#fbfcff"/>
${text(50, 60, title, 'title')}${text(50, 98, subtitle, 'subtitle')}
${body}
</svg>
`;
  fs.writeFileSync(path.join(directory, name), svg, 'utf8');
}
function card(x, y, width, height, name, stereotype, fields, methods, color, source = '') {
  const content = `<g><rect x="${x}" y="${y}" width="${width}" height="${height}" rx="10" fill="white" stroke="#8191a8" stroke-width="1.5"/>
<path d="M${x+10} ${y}H${x+width-10}Q${x+width} ${y} ${x+width} ${y+10}V${y+76}H${x}V${y+10}Q${x} ${y} ${x+10} ${y}Z" fill="${colors[color]}"/>
${text(x+20, y+25, stereotype, 'type')}${text(x+20, y+58, name, 'name')}
<path d="M${x} ${y+76}H${x+width}" stroke="#c4cdd9"/>
${fields.map((field,i)=>text(x+20,y+107+i*27,field)).join('')}
<path d="M${x} ${y+93+fields.length*27}H${x+width}" stroke="#e0e5ee"/>
${methods.map((method,i)=>text(x+20,y+120+fields.length*27+i*27,method)).join('')}</g>`;
  return source ? `<a href="../scripts/${escape(source)}"><title>${escape(source)}</title>${content}</a>` : content;
}
function edge(d, kind = 'association', label = '', x = 0, y = 0) {
  let markers = ' marker-end="url(#arrow)"';
  if (kind === 'inherit') markers = ' marker-end="url(#inherit)"';
  if (kind === 'owned' || kind === 'shared') markers = ` marker-start="url(#${kind})"`;
  if (kind === 'plain') markers = '';
  return `<path d="${d}" class="edge ${kind === 'dependency' ? 'dependency' : ''}"${markers}/>${label ? text(x,y,label,'label') : ''}`;
}
function legend(y) {
  return edge(`M50 ${y}H120`,'inherit')+text(135,y+6,'继承（箭头指向基类）','note')
    +edge(`M480 ${y}H550`,'owned')+text(565,y+6,'拥有运行时对象','note')
    +edge(`M850 ${y}H920`,'shared')+text(935,y+6,'引用 / 聚合共享配置','note')
    +edge(`M1340 ${y}H1410`,'dependency')+text(1425,y+6,'调用 / 创建依赖','note');
}
const classCard = (x,y,name,kind,fields,methods,color,source,height=230) => card(x,y,480,height,name,kind,fields,methods,color,source);

let core = legend(145);
core += classCard(50,200,'GameplayAbilityComponent','«Node» 技能容器',['_learned_abilities: Dictionary','_current_casting_ability: Instance'],['learn_ability(definition)','try_activate_ability(id, context)'],'runtime','components/gameplay_ability_component.gd');
core += classCard(650,200,'GameplayAbilityDefinition','«Resource» 静态技能配置',['execution_tree: BTNode','features: Array'],['create_instance(owner): Instance'],'config','abilities/gameplay_ability_definition.gd');
core += classCard(1250,200,'GameplayAbilityFeature','«abstract Resource» 技能扩展',['feature_name: String'],['can_activate / on_activate','update / on_learned / on_forgotten'],'config','abilities/features/gameplay_ability_feature.gd');
core += classCard(50,580,'GameplayAbilityInstance','«RefCounted» 每个实体的技能状态',['_definition / _features','_bt_instance / _blackboard'],['try_activate(context)','update(delta) / end_ability()'],'runtime','abilities/gameplay_ability_instance.gd');
core += classCard(650,580,'BTInstance','«RefCounted» 行为树执行状态',['tree_root: BTNode','blackboard: BTBlackboard'],['tick(delta)','reset_tree()'],'runtime','behavior_tree/bt_instance.gd');
core += classCard(1250,580,'BTNode','«abstract Resource» 行为树节点',['node_id: StringName','Status: RUNNING / SUCCESS / FAILURE'],['tick(instance, delta)','reset(instance)'],'config','behavior_tree/bt_node.gd');
core += classCard(50,960,'BTBlackboard','«RefCounted» 共享执行数据',['_data / _node_memory: Dictionary'],['get_var(key, default)','set_var(key, value)'],'runtime','behavior_tree/bt_blackboard.gd');
core += classCard(650,960,'AbilityNodeBase','«abstract Resource» 技能动作节点',['target_key: String'],['_get_context(instance)','_get_target_list(instance, fallback)'],'config','abilities/ability_nodes/ability_node_base.gd');
core += classCard(1250,960,'AbilityNodeApplyEffect','«Resource» 效果执行动作',['target_key / effect_key','effects: Array[GameplayEffect]'],['_tick(): 克隆并逐个 apply()'],'effect','abilities/ability_nodes/ability_node_apply_effect.gd');
core += classCard(1250,1300,'GameplayEffect','«abstract Resource» 逻辑操作',['filters / sub_effects / cue'],['apply() / remove() / _apply()'],'effect','effects/gameplay_effect.gd',180);
core += edge('M530 270H650','dependency','学习配置',550,253);
core += edge('M1130 270H1250','shared','features 0..*',1137,253);
core += edge('M290 430V580','owned','实例 0..*',305,505);
core += edge('M890 430V490H420V580','dependency','create_instance()',595,477);
core += edge('M530 680H650','owned','0..1',560,663);
core += edge('M1130 680H1250','shared','tree_root 1',1138,663);
core += edge('M1040 430V515H1490V580','shared','execution_tree 0..1',1270,502);
core += edge('M290 810V960','owned','blackboard 1',305,888);
core += edge('M890 810V870H440V960','shared','使用同一黑板',585,856);
core += edge('M890 960V900H1400V810','inherit','经 BTAction 继承',1060,885);
core += edge('M1250 1045H1130','inherit');
core += edge('M1490 1190V1300','shared','effects 0..*',1505,1245);
core += `<rect x="50" y="1290" width="1080" height="190" rx="10" fill="#f0f4fa"/>
${text(75,1328,'阅读方式','step')}
${text(75,1365,'Resource 保存配置；RefCounted 保存一次技能 / 状态的执行数据。','note')}
${text(75,1400,'BTInstance 复用技能的 BTBlackboard；效果执行时 duplicate(true)。','note')}
${text(75,1435,'节点继承仅展示主路径；模板、策略及 Feature 子类详见 README。','note')}`;
diagram('ability-core.svg',1800,1530,'技能核心类图','基于当前源码 · 展示容器、配置、实例、行为树与效果入口 · 点击类框可定位源码',core);

let effects = legend(145);
effects += classCard(50,220,'GameplayFilterData','«abstract Resource» 目标准入',[],['check(target, instigator, context)'],'config','filters/gameplay_filter.gd',190);
effects += classCard(650,220,'GameplayEffect','«abstract Resource» 效果模板',['filters / sub_effects: Array','required_tags / blocked_tags / cue'],['apply(): 准入 → 逻辑 → Cue → 子效果','remove(): _remove() → 子效果'],'effect','effects/gameplay_effect.gd',250);
effects += classCard(1250,220,'GameplayCue','«Resource» 表现组合',['cues: Array[GameplayCueBase]'],['由 GameplayCueManager 执行'],'config','cues/gameplay_cue.gd',190);
effects += classCard(50,600,'GE_ApplyDamage','«Resource» 伤害操作',['damage_multiplier / damage_strategy','vital_id = health'],['_apply(): 计算并提交 DamageInfo'],'effect','effects/ge_apply_damage.gd');
effects += classCard(650,600,'GE_ApplyStatus','«Resource» 状态操作',['status_data: GameplayStatusData','stacks: int'],['_apply(): status_comp.apply_status()'],'effect','effects/ge_apply_status.gd');
effects += classCard(1250,600,'GE_AttributeModifier','«Resource» 属性操作',['modifiers: Array[AttributeModifier]','source_id: StringName'],['_apply() / _remove()'],'effect','effects/ge_attribute_modifier.gd');
effects += classCard(50,960,'HealthVital','«Resource» 运行时生命值',['current_value / is_alive'],['apply_damage(info, owner)','damage_received / damage_applied'],'runtime','attributes/vitals/health_vital.gd',210);
effects += classCard(650,960,'GameplayStatusComponent','«Node» 活跃状态容器',['_active_statuses: Dictionary'],['apply_status() / remove_status()','_process(delta) / handle_event()'],'runtime','components/gameplay_status_component.gd',210);
effects += classCard(1250,960,'GameplayAttributeComponent','«Node» 属性与修改器',['_attributes: Dictionary'],['add_modifier(mod)','remove_modifiers_by_source(id)'],'runtime','components/gameplay_attribute_component.gd',210);
effects += classCard(50,1300,'DamageCalculator','«autoload Node» 策略调度',['_strategy: DamageLogicStrategy'],['calculate_final_damage(...)'],'service','singletons/damage_calculator.gd',210);
effects += classCard(650,1300,'GameplayStatusInstance','«RefCounted» 状态生命周期',['status_data / stacks / context'],['apply() / update() / remove()','apply_effects(): 克隆后调用效果'],'runtime','status/gameplay_status_instance.gd',210);
effects += classCard(1250,1300,'GameplayStatusData','«Resource» 状态定义',['apply_effects / remove_effects','features / duration / stacking_policy'],['duration_policy / tags / cue'],'config','status/gameplay_status_data.gd',210);
effects += edge('M650 290H530','shared','filters 0..*',540,271);
effects += edge('M1130 290H1250','shared','cue 0..1',1150,271);
effects += edge('M1130 420H1180V510H1060V470','shared','sub_effects 0..*（递归）',1210,480);
effects += edge('M290 600V550H1490V600','plain');
effects += edge('M890 600V470','inherit','继承效果基类',910,532);
effects += edge('M290 830V960','dependency','经 Vital 组件定位',305,900);
effects += edge('M890 830V960','dependency','apply_status()',910,900);
effects += edge('M1490 830V960','dependency','添加 / 按来源移除',1510,900);
effects += edge('M50 710H25V1245H290V1300','dependency','计算伤害',90,1230);
effects += edge('M890 1170V1300','owned','活跃实例 0..*',910,1240);
effects += edge('M1130 1380H1250','shared','数据 1',1160,1360);
effects += `<rect x="50" y="1560" width="1680" height="125" rx="10" fill="#f0f4fa"/>
${text(75,1598,'状态扩展：StatusFeature → FeaturePeriodicEffects / FeatureEventListener','note')}
${text(75,1632,'持续时间与堆叠分别交给 StatusDurationPolicy、StatusStackingPolicy。','note')}
${text(75,1666,'Cue、事件总线与标签管理器均为独立服务；图中仅展开三种典型效果。','note')}`;
diagram('effect-status.svg',1800,1730,'效果与状态类图','效果负责一次逻辑操作；状态保存持续数据并重复调度效果 · 所有具体 GE_* 子类见 README',effects);

function step(x,y,width,height,title,lines,color='runtime') {
  return `<rect x="${x}" y="${y}" width="${width}" height="${height}" rx="12" fill="${colors[color]}" stroke="#8191a8" stroke-width="1.5"/>
${text(x+22,y+36,title,'step')}${lines.map((line,i)=>text(x+22,y+70+i*29,line,'note')).join('')}`;
}
let flow = text(50,148,'左：一次效果调用　　右：持续状态与周期触发','note');
flow += step(80,200,730,130,'1  技能激活 / 周期 / 命中触发',['AbilityNodeApplyEffect / GameplayStatusInstance','duplicate(true) → effect.apply(target, instigator, context)']);
flow += step(80,390,730,160,'2  GameplayEffect._check_filters()',['逐个 filter.check()；阻止标签任意命中则拒绝','必需标签必须全部满足；任一步失败直接 return'],'effect');
flow += step(80,610,730,160,'3  子类 _apply()',['伤害：策略计算 → DamageInfo → HealthVital.apply_damage','治疗 / 属性 / 状态 / 魔法场 / 位移等操作'],'effect');
flow += step(80,830,730,130,'4  执行可选 Cue',['GameplayCueManager.execute_cue(cue, target, context)','读取逻辑写入的 final_damage 等数据'],'config');
flow += step(80,1020,730,130,'5  子效果逐个递归执行',['子效果也 duplicate(true)，再进入自己的 apply()','子效果与父效果共享当前 context'],'effect');
flow += step(980,200,740,160,'A  GE_ApplyStatus / 直接 apply_status()',['优先级检查 → 堆叠策略 → 创建状态实例','同 ID 堆叠被处理时不创建新实例，返回 null'],'effect');
flow += step(980,430,740,160,'B  GameplayStatusInstance.apply()',['缓存 context，注入 stacks / source_id，执行 apply_effects','初始化 Feature、持续时间、状态标签和独立 Cue']);
flow += step(980,660,740,190,'C  GameplayStatusComponent._process(delta)',['先更新 duration_policy；到期即安排移除','未到期则更新 FeaturePeriodicEffects 等 Feature','周期或事件效果仍进入左侧的完整 apply() 流程']);
flow += step(980,950,740,200,'D  remove_status() → instance.remove()',['应用 remove_effects，再 remove 原 apply_effects','移除 Feature 存储、状态标签，停止状态 Cue','发出 status_completed / status_removed 信号']);
for (const [a,b] of [[330,390],[550,610],[770,830],[960,1020]]) flow += edge(`M445 ${a}V${b}`);
for (const [a,b] of [[360,430],[590,660],[850,950]]) flow += edge(`M1350 ${a}V${b}`);
flow += '<circle cx="865" cy="443" r="19" fill="#fde8e8" stroke="#bc6972"/>' + text(865,451,'×','step','middle');
flow += edge('M810 470H865V462','dependency','拒绝',841,408);
flow += edge('M980 745H930V265H810','dependency','触发效果',842,635);
flow += `<rect x="80" y="1220" width="1640" height="170" rx="12" fill="#f0f4fa"/>
${text(105,1260,'顺序与生命周期要点','step')}
${text(105,1298,'apply() 不返回执行结果；子类提前 return 后，基类仍可能继续播放 Cue 和执行子效果。','note')}
${text(105,1333,'remove() 默认不撤销伤害或治疗，也不自动停止效果 Cue；状态 Cue 由状态实例单独清理。','note')}
${text(105,1368,'duration = 0 提前完成；空 status_id 不入活跃表；叠加时 add_stack() 会重新应用 apply_effects。','note')}`;
diagram('effect-runtime.svg',1800,1440,'效果运行流程','调用顺序与实际实现一致；细节及当前限制见 README · 虚线表示条件退出或跨系统调用',flow);

generateSystemDiagrams({ diagram, text, card, edge, legend, step });
generateSourceIndex();
console.log('Generated 19 SVG diagrams (core, modules, integration and runtime).');
// #endregion
