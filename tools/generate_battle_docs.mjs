// #region SVG 绘制工具
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const docs = path.join(root, 'addons/battle_foundation/docs');
fs.mkdirSync(docs, {recursive:true});
const escape = text => String(text).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const text = (x,y,value,size=18,color='#334155') => `<text x="${x}" y="${y}" font-size="${size}" fill="${color}">${escape(value)}</text>`;
function svg(width,height,title,body) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img" aria-label="${escape(title)}"><defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0L10 5L0 10Z" fill="#64748b"/></marker></defs><style>text{font-family:"Microsoft YaHei","Noto Sans CJK SC",sans-serif}a{text-decoration:none}</style><rect width="100%" height="100%" fill="#f8fafc"/>${text(32,45,title,28,'#0f172a')}${body}</svg>\n`;
}
function box(x,y,w,h,title,lines,file,color='#dbeafe') {
  const card = `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="10" fill="white" stroke="#94a3b8"/><path d="M${x+10} ${y}H${x+w-10}Q${x+w} ${y} ${x+w} ${y+10}V${y+46}H${x}V${y+10}Q${x} ${y} ${x+10} ${y}" fill="${color}"/>${text(x+16,y+30,title,21,'#0f172a')}${lines.map((line,i)=>text(x+16,y+76+i*27,line,17)).join('')}`;
  return file ? `<a href="${escape(file)}">${card}</a>` : card;
}
const arrow = (d,label,x,y) => `<path d="${d}" fill="none" stroke="#64748b" stroke-width="2" marker-end="url(#arrow)"/>${text(x,y,label,15)}`;
// #endregion

// #region 系统联合类图
let architecture = text(32,77,'Core 提供基础服务，GAS 保存战斗实例；新增插件定义统一的入口与时间规则。',18);
architecture += box(30,105,440,175,'CoreSystem', ['ResourceManager：缓存加载','ConfigManager：用户选项','EventBus：同步事件与共享 DamageInfo'], '../../godot_core_system-0.0.4/source/core_system.gd','#e2e8f0');
architecture += box(530,105,440,175,'BattleCatalog', ['manifest：类别 + 定义 ID → 路径','类型、依赖、帧顺序校验','出口：独立的定义资源图'], '../runtime/battle_catalog.gd','#dcfce7');
architecture += box(1030,105,440,215,'Resource 定义', ['BattleEntityDefinition / EquipmentDefinition','BattleLevelDefinition / SpawnDefinition','GameplayAbilityDefinition / StatusData','BattleFrameEvent：原素材帧事件'], '../definitions/battle_entity_definition.gd','#dcfce7');
architecture += box(30,365,440,175,'BattleSystem', ['Autoload：会话 ID 分配','读取 Core 用户配置','create_session(parent, manifest, seed)'], '../runtime/battle_system.gd');
architecture += box(530,365,440,175,'BattleSession', ['场次 ID / 实体注册 / 关卡与装备实例','_physics_process → advance_physics','publish_event → Core EventBus'], '../runtime/battle_session.gd');
architecture += box(1030,365,440,175,'BattleClock', ['累计战斗时间 / 物理 tick / last_delta','暂停、慢动作、停顿与部分 tick','不重置技能、不补算暂停积压'], '../runtime/battle_clock.gd','#fef3c7');
architecture += box(30,640,440,150,'BattleFactions', ['实体运行阵营与双向/单向关系','同阵营友好，未登记组合中立'], '../runtime/battle_factions.gd');
architecture += box(530,640,440,190,'BattleEntity : CharacterBody3D', ['entity_id 与 definition_id 分开','三个 GAS 组件使用外部时钟','move_and_collide(velocity × delta)','退出撤销状态/技能并注销 ID'], '../runtime/battle_entity.gd');
architecture += box(1030,640,440,150,'BattleRandom', ['场次种子 + 命名随机流','combat / loot / spawn；快照与恢复'], '../runtime/battle_random.gd');
architecture += box(30,930,440,150,'BattleEquipmentState', ['instance_id / 当前 durability','独立定义及修改器子资源'], '../runtime/battle_equipment_state.gd');
architecture += box(530,930,440,175,'GAS 实例系统', ['属性与 Vital：当前值及恢复','技能黑板：剩余冷却、运行禁用状态','状态实例：持续时间、层数和 Feature'], '../../gameplay_abiltiy_system/scripts/components/gameplay_vital_attribute_component.gd','#e2e8f0');
architecture += box(1030,930,440,175,'BattleFrameTimelineFeature', ['source_fps / duration_frames / events','elapsed 与事件游标存于技能黑板','跨帧逐个发布 Core 原素材事件'], '../gas/battle_frame_timeline_feature.gd','#fef3c7');
architecture += arrow('M470 190H530','加载',478,180);
architecture += arrow('M1030 190H970','索引',978,180);
architecture += arrow('M470 445H530','创建',478,435);
architecture += arrow('M750 280V365','定义实例',766,333);
architecture += arrow('M1030 445H970','delta',981,435);
architecture += arrow('M750 540V640','固定物理调度',766,592);
architecture += arrow('M470 715H530','查询',478,705);
architecture += arrow('M970 715H1030','调用',981,705);
architecture += arrow('M750 830V930','持有并驱动',766,888);
architecture += arrow('M1030 1005H970','GAS Feature',970,898);
architecture += arrow('M530 510H490V900H250V930','创建装备实例',286,890);
fs.writeFileSync(path.join(docs,'architecture.svg'),svg(1500,1150,'阶段 1 · 定义、战斗实例与插件协作',architecture));
// #endregion

// #region 素材帧与物理更新
let timing = text(32,82,'示例：source_fps=30，固定物理更新=60 Hz；12 号素材帧的时间为 12 / 30 = 0.4 秒。');
const x = time => 170 + time * 1170;
timing += text(32,155,'战斗秒数',19);
timing += `<path d="M170 150H1340" stroke="#64748b" stroke-width="2"/>`;
for (let i=0;i<=5;i++) {
  timing += `<path d="M${x(i*.2)} 143V157" stroke="#64748b"/>` + text(x(i*.2)-12,183,(i*.2).toFixed(1),17);
}
timing += text(32,250,'素材 30 fps',19);
timing += text(32,350,'物理 60 Hz',19);
for (const [count,y] of [[30,245],[60,345]]) {
  timing += `<path d="M170 ${y}H1340" stroke="#64748b" stroke-width="2"/>`;
  for (let i=0;i<=count;i++) {
    const major = i % (count/5) === 0;
    timing += `<path d="M${x(i/count)} ${y-7}V${y+(major?14:7)}" stroke="#64748b"/>`;
    if (major) timing += text(x(i/count)-8,y+42,String(i),17);
  }
}
for (const frame of [12,18]) {
  timing += `<path d="M${x(frame/30)} 190V389" stroke="#2563eb" stroke-width="3" stroke-dasharray="5 5"/>`;
  timing += text(x(frame/30)+10,213,`帧 ${frame} / tick ${frame*2}`,17,'#1d4ed8');
}
timing += box(32,440,650,145,'暂停 / 受击停顿', ['模拟时间冻结，帧游标、冷却和 Buff 保持。','恢复只推进下一次 delta，不补算暂停时间。'], '../runtime/battle_clock.gd','#fef3c7');
timing += box(716,440,652,145,'慢动作 / 跨帧事件', ['0.5×：0.4 秒技能时间需要约 0.8 秒真实时间。','跨过多个素材事件时按帧号顺序逐个补发。'], '../gas/battle_frame_timeline_feature.gd','#dbeafe');
timing += text(32,625,'source_frame 从 0 开始；实际素材帧率由配置提供。combat_time 是实际处理时间，skill_time 是素材定义时间。',17);
fs.writeFileSync(path.join(docs,'time-rules.svg'),svg(1400,665,'阶段 1 · 素材帧与统一战斗时间',timing));
// #endregion

// #region 动画适配与战斗状态联合类图
let animation = text(32,80,'动作名称属于战斗接口；Spine 细节在适配层内部，生命与技能许可仍由战斗状态管理。');
animation += box(30,110,440,185,'BattleSession / BattleClock', ['固定物理 tick → 唯一 combat delta','暂停、慢动作、受击停顿统一处理','spawn_entity_2d：独立 GAS 与姿态'], '../runtime/battle_session.gd');
animation += box(530,110,440,185,'BattleActionProfile2D', ['普攻锁定 10 帧 / 受击锁定 8 帧','原版攻击区域：0,-200,130,300','平台样例重力、跳跃速度'], '../definitions/battle_action_profile_2d.gd','#dcfce7');
animation += box(1030,110,440,185,'CharacterAnimationProfile', ['战斗动作名 → 原版 Spine 动作名','30 fps / 循环 / 固定脚底偏移','基础皮肤 / 显示比例 / 骨骼挂点'], '../animation/character_animation_profile.gd','#dcfce7');
animation += box(30,390,440,210,'Core EventBus', ['battle.attack.impact：第 4 / 30 秒','battle.attack.hit：阵营 + 区域判定','battle.animation_completed：仅通知','同步伤害引用沿用 GAS/Core'], '../../godot_core_system-0.0.4/source/event_system/event_bus.gd','#e2e8f0');
animation += box(530,390,440,210,'BattleEntity2D', ['CharacterBody2D：脚底为原点','独立 BattleActionState2D','使用动作名称命令表现层','物理体不缩放，朝向不镜像物理体'], '../runtime/battle_entity_2d.gd');
animation += box(1030,390,440,210,'CharacterAnimationAdapter', ['play_action / set_facing / set_skins','set_equipment_skin / progress / socket','完成与循环通知，不决定战斗许可','抽象 Node2D，可换其他动画后端'], '../animation/character_animation_adapter.gd','#fef3c7');
animation += box(30,700,440,210,'GAS 运行实例', ['BattleGASBinding：共用 2D/3D 装配','属性 atk、phyDef、hpMax / Vital','sunwukong_attack1：30 fps / 10 帧','生命耗尽 → 立即进入 DEAD'], '../runtime/battle_gas_binding.gd');
animation += box(530,700,440,210,'BattleActionState2D', ['IDLE / MOVE / RUN / TAKEOFF / AIR / LAND','ATTACK / HURT：技能与规则时间锁定','DEAD：不可攻击，不被动画复活','grounded 由运动控制器决定'], '../runtime/battle_action_state_2d.gd','#fce7f3');
animation += box(1030,700,440,210,'SpineAnimationAdapter', ['独立 SpineSprite / TrackEntry / Skin','Manual：只消费 combat delta','原版附件注册点、槽位层序保留','共用只读 skel/atlas，不共用姿态'], '../animation/spine_animation_adapter.gd','#fef3c7');
animation += arrow('M250 295V345H750V390','驱动',510,336);
animation += arrow('M750 295V390','规则',766,345);
animation += arrow('M1250 295V390','映射',1266,345);
animation += arrow('M530 470H470','事件',479,459);
animation += arrow('M970 470H1030','动作命令',972,448);
animation += arrow('M1030 555H970','完成通知',972,578);
animation += arrow('M650 600V650H250V700','持有并推进',322,641);
animation += arrow('M750 600V700','持有',766,657);
animation += arrow('M1250 700V600','实现接口',1266,657);
animation += text(32,970,'换皮肤：构造实例专属组合皮肤 → 重新应用当前时刻姿态；不重启 TrackEntry，不移动角色，不写共享配置。',18);
fs.writeFileSync(path.join(docs,'animation-adapter.svg'),svg(1500,1010,'孙悟空 · 动画适配层与战斗状态联合类图',animation));
// #endregion

// #region 角色原点与镜像图
let registration = text(32,80,'原版骨架保持素材帧、附件偏移和层序；Root 固定在脚底，表现偏移与战斗判定分别配置。');
const figure = (ox, facing) => `<path d="M${ox-145} 485H${ox+145}" stroke="#64748b" stroke-width="2"/><rect x="${facing>0?ox:ox-260}" y="180" width="260" height="390" fill="#fef3c7" stroke="#f59e0b"/><rect x="${ox-22}" y="305" width="44" height="180" rx="22" fill="#dbeafe" stroke="#2563eb" stroke-width="2"/><path d="M${ox-14} 485H${ox+14}M${ox} 471V499" stroke="#10b981" stroke-width="3"/><path d="M${ox} 330L${ox+facing*120} 340" stroke="#64748b" stroke-width="8"/><circle cx="${ox+facing*120}" cy="340" r="6" fill="#f59e0b"/>${text(ox-68,525,'角色原点 (0,0)',18)}${text(ox-100,275,'物理体始终不翻转',18)}${text(ox-130,125,facing>0?'右向：x ≥ 0':'左向：x ≤ 0',24)}`;
registration += figure(320,1) + figure(1070,-1);
registration += box(30,615,650,175,'表现坐标', ['固定 skeleton_offset=(0,-4.2384)，display_scale=2','保留原 atlas trim 与附件 x/y，按原 drawOrder 显示','骨架 scale_x=±1；武器三个原骨骼挂点一起镜像'], '../animation/spine_animation_adapter.gd','#fef3c7');
registration += box(710,615,650,175,'战斗区域', ['右：Rect2(0,-200,130,300) × 2','左：Rect2(-130,-200,130,300) × 2','示意框高度压缩展示；实际尺寸 260 × 600 像素'], '../runtime/battle_entity_2d.gd');
registration += text(32,835,'攻击范围以角色脚底为原点；皮肤与武器长度不改变它。完成事件不决定地面状态、攻击许可或死亡状态。',18);
fs.writeFileSync(path.join(docs,'animation-registration.svg'),svg(1400,875,'孙悟空 · 脚底原点、装备挂点与攻击镜像',registration));
// #endregion
// #region 操作控制器联合类图
let operations = text(32,80,'Godot 输入 → 语义意图 → 战斗许可 → GAS 与动画；配置共享，控制器与缓存按实体独立。');
operations += box(30,115,440,210,'CoreOperationBindings', ['默认物理键 / 用户配置 / InputMap','捕获新键 / 冲突与保留键 / 保存','改键只影响输入层，角色不改代码','菜单暂停时 Always 运行'], '../../godot_core_system-0.0.4/source/operation_system/operation_bindings.gd','#e2e8f0');
operations += box(530,115,440,210,'CoreOperationController', ['原生 _unhandled_input：UI 优先','多来源强度 / 四阶段 / 长按 / 双击','控制权原因集合 / 来源释放隔离','未缩放 input_time / 精确消费'], '../../godot_core_system-0.0.4/source/operation_system/operation_controller.gd');
operations += box(1030,115,440,210,'CoreOperationProfile', ['语义意图 → 原生动作 / 轴规则','default_keys / reserved_keys','缓存 0.2 s / 长按 0.3 s','业务同方向双击 < 0.5 s'], '../../godot_core_system-0.0.4/source/operation_system/operation_profile.gd','#dcfce7');
operations += box(30,435,440,185,'BattleOperationMenu', ['模态 UI / Esc / 绑定设置','menu 原因与 remapping 独立','关闭菜单不会覆盖失焦控制权'], '../input/battle_operation_menu.gd','#e2e8f0');
operations += box(530,435,440,210,'BattlePlayerOperations', ['固定 tick 消费移动 / 跳跃 / 普攻','ability_slots：技能槽 → GAS ID','ACCEPTED / RETRY / UNAVAILABLE','公共操作后追加角色钩子'], '../input/battle_player_operations.gd');
operations += box(1030,435,440,210,'CoreOperationBuffer / Intent', ['按下快照 / sequence / 持有时长','有限队列 / 独立消费 / 过期','短按不丢，连按各保留一次','cancelled 释放只清理蓄力'], '../../godot_core_system-0.0.4/source/operation_system/operation_buffer.gd','#fef3c7');
operations += box(30,790,440,185,'BattleSession / BattleClock', ['先推进未缩放输入时间','再计算 combat delta 驱动动作','暂停立即同步控制权'], '../runtime/battle_session.gd','#fef3c7');
operations += box(530,790,440,210,'BattleEntity2D / ActionState', ['落地 / 受击 / 死亡决定许可','try_jump / try_attack / skill','生命与冷却仍属于运行实例','动作名称命令独立动画适配'], '../runtime/battle_entity_2d.gd');
operations += box(1030,790,440,210,'GAS / AnimationAdapter', ['GameplayAbilityComponent：技能','Vital / Status：生命与状态','Spine：动作、朝向、皮肤、进度','完成通知不授予战斗许可'], '../animation/character_animation_adapter.gd','#e2e8f0');
operations += arrow('M470 205H530','映射',478,195);
operations += arrow('M1030 205H970','定义',979,195);
operations += arrow('M250 435V325','改键',266,386);
operations += arrow('M750 325V435','意图',766,386);
operations += arrow('M470 527H530','占用',478,515);
operations += arrow('M1030 550H970','队列',979,537);
operations += arrow('M750 645V790','尝试执行 / 许可',766,728);
operations += arrow('M470 880H530','调度',478,868);
operations += arrow('M970 880H1030','调用',979,868);
operations += text(32,1060,'角色可继承 BattlePlayerOperations：专属按下、公共分支后置、held/released、cancelled 清理。',18);
fs.writeFileSync(path.join(docs,'player-operations.svg'),svg(1500,1100,'角色操作 · 输入、角色、技能与表现联合类图',operations));
// #endregion

// #region 输入时间与控制权流程
let control = text(32,80,'输入时间按真实物理秒推进；战斗执行按 combat delta 推进，窗口和规则分别管理。');
control += box(30,120,440,185,'输入 tick：unscaled delta', ['长按 / 双击 / 缓存过期','受击停顿仍识别，超时即丢弃','按下 → 缓存 → 等待许可'], '../../godot_core_system-0.0.4/source/operation_system/operation_controller.gd','#fef3c7');
control += box(530,120,440,185,'固定战斗 tick：combat delta', ['移动 / 跳跃 / 技能 / 动画','慢动作同步缩放，停顿不执行','许可未成立 → RETRY 留队列'], '../input/battle_player_operations.gd');
control += box(1030,120,440,185,'最终消费 / 过期', ['许可通过 → ACCEPTED 消费一次','未装配 → UNAVAILABLE 消费','超时不在恢复后补发攻击'], '../../godot_core_system-0.0.4/source/operation_system/operation_buffer.gd','#dcfce7');
control += arrow('M470 207H530','缓存',478,194);
control += arrow('M970 207H1030','结果',979,194);
control += box(30,420,440,210,'失去控制权', ['菜单 / 失焦 / 改键 / 控制者切换','暂停 / time_scale=0 / 死亡','立即清移动、奔跑、队列与双击','cancelled release 只取消蓄力'], '../../godot_core_system-0.0.4/source/operation_system/operation_controller.gd','#fee2e2');
control += box(530,420,440,210,'独立原因集合', ['每个入口添加自己的 reason','关闭菜单只移除菜单的 reason','仍失焦时继续阻断所有来源','恢复 API 立即同步，不等下 tick'], '../runtime/battle_session.gd','#e2e8f0');
control += box(1030,420,440,210,'重新接受输入', ['所有原因移除后才获得控制','旧持有键先松开再重新按下','UI 已消费按下不进入角色','UI 吞松键也不会卡住移动'], '../input/battle_operation_menu.gd','#dcfce7');
control += arrow('M470 512H530','撤回',478,500);
control += arrow('M970 512H1030','恢复',979,500);
control += text(32,716,'例：菜单打开 + 窗口失焦 → 关闭菜单仍无控制权 → 焦点恢复 → 松开旧键 → 新按下生效。',19);
control += text(32,756,'重映射：选择意图 → remapping 阻断 → 捕获新键 → 校验/保存/InputMap → 释放新键 → 返回角色。',18);
fs.writeFileSync(path.join(docs,'operation-control.svg'),svg(1500,800,'角色操作 · 输入缓存、战斗时间与控制权',control));
// #endregion
// #region 运动控制器与状态权限联合类图
let motion = text(32,80,'输入、支撑接触与技能许可决定动作状态；动画完成只通知，死亡由 GAS Vital 耗尽触发。');
motion += box(30,120,440,210,'BattleSession / BattleClock', ['固定物理 tick → combat delta','移动 / 技能 / 状态 / 动画同步缩放','暂停和停顿保持状态时间','Core：场次与实体事件'], '../runtime/battle_session.gd','#fef3c7');
motion += box(530,120,440,210,'BattleActionProfile2D : Resource', ['重力 / 跳跃 / 二跳 / 落地窗口','state_rules：移动、跳跃、转向','每种攻击允许类型与打断门槛','共享只读，引用连击定义'], '../definitions/battle_action_profile_2d.gd','#dcfce7');
motion += box(1030,120,440,210,'Core / BattlePlayerOperations', ['按下 / HELD / 松开 / 长按','行走与奔跑 → GAS 速度属性','request_attack：发动或预约','撤回控制同时撤回预约'], '../input/battle_player_operations.gd','#e2e8f0');
motion += box(30,435,440,235,'BattleMotionController2D', ['body: CharacterBody2D / velocity','move_and_collide + 法线滑移','grounded / wall / ceiling / landed','单向平台 / 边缘 / 最大 1/60 子步','跳跃预算：地面一次，空中一次'], '../runtime/battle_motion_controller_2d.gd');
motion += box(530,435,440,235,'BattleEntity2D : CharacterBody2D', ['独立持有 motion / state / combo','许可 → 速度与朝向 → 扫掠碰撞','原生 Spine → GAS → 状态 / 连击','技能位移仍经过墙体碰撞','伤害 → 打断判断 → HURT / DEAD'], '../runtime/battle_entity_2d.gd');
motion += box(1030,435,440,235,'BattleActionState2D', ['IDLE / MOVE / RUN / TAKEOFF','AIR / LAND / ATTACK / HURT / DEAD','elapsed / active_rules 技能覆盖','霸体 + 类型 + 优先级决定打断','DEAD 终态，技能不能覆盖许可'], '../runtime/battle_action_state_2d.gd','#fce7f3');
motion += box(30,785,440,200,'GAS Attributes / Vital / Tags', ['walkSpeed / runSpeed：实时读数','HealthVital：实际扣血及死亡','state.super_armor：抵挡普通硬直','重攻击仍需满足技能门槛'], '../../gameplay_abiltiy_system/scripts/components/gameplay_vital_attribute_component.gd','#fee2e2');
motion += box(530,785,440,200,'BattleComboState / GAS Ability', ['按段配置覆盖状态许可','地面跳取消：终止技能和预约','离开地面结束地面普攻','帧事件由技能实例时间线驱动'], '../runtime/battle_combo_state.gd','#dcfce7');
motion += box(1030,785,440,200,'CharacterAnimationAdapter', ['动作名称 / 朝向 / 皮肤 / 进度','jump_2 → 原生 jumpTwo','LAND → idle，无独立落地素材','完成通知不决定支撑或死亡'], '../animation/character_animation_adapter.gd','#fef3c7');
motion += arrow('M250 330V375H650V435','调度',332,366);
motion += arrow('M750 330V435','只读规则',766,389);
motion += arrow('M1250 330V375H850V435','操作命令',992,365);
motion += arrow('M530 525H470','速度',479,514);
motion += arrow('M470 592H530','支撑',479,580);
motion += arrow('M1030 545H970','权限',979,534);
motion += arrow('M250 785V725H640V670','伤害 / 速度',293,715);
motion += arrow('M750 785V670','技能规则',766,727);
motion += arrow('M860 670V725H1250V785','动作命令',995,715);
motion += text(32,1040,'转换条件：地面 + 方向 → MOVE/RUN；起跳 → TAKEOFF → AIR；实际支撑 → LAND；Vital=0 → DEAD。',18);
motion += text(32,1080,'ATTACK 由 GAS 完成/取消退出；HURT 由硬直窗口退出。每个实例独立计时、独立预算、独立预约。',18);
fs.writeFileSync(path.join(docs,'motion-state.svg'),svg(1500,1120,'阶段四 · 运动控制器、动作状态与插件联合类图',motion));
// #endregion

// #region 五段连击时间线与联合运行图
let combo = text(32,80,'原素材 30 FPS：总计 70 帧 / 2.333 秒，第四段两次判定；按下预约一段，长按不自动推进。');
const segments = [
  ['attack_1',10,'命中帧 4 · ×1.0'], ['attack_2',10,'命中帧 4 · ×1.0'],
  ['attack_3',12,'命中帧 2 · ×1.2'], ['attack_4',18,'命中帧 0、8 · 各 ×0.45'],
  ['attack_5',20,'命中帧 6 · ×2.0']
];
segments.forEach(([action,frames,hit],i) => {
  const x = 30+i*296;
  combo += box(x,120,256,185,action,[`sunwukong_attack${i+1}`,`${frames} 帧 / ${(frames/30).toFixed(3)} 秒`,hit],`../../../data/battle2d/attack${i+1}.tres`,i===3?'#fef3c7':'#dbeafe');
  if(i<4) combo += arrow(`M${x+256} 210H${x+296}`,'',0,0);
});
combo += text(32,354,'下一段必须满足：当前 GAS 已结束 + 已预约 + 存活 + 地面支撑；否则结束连击回运动状态。',18);
combo += box(30,415,440,210,'BattleComboDefinition : Resource', ['steps: BattleAttackStep2D[]','语义 ID / 原生动作 / 30 FPS 时长','每段跳取消 / 霸体 / 优先级','第 4 段：300 px/s × 前 16 帧'], '../definitions/battle_combo_definition.gd','#dcfce7');
combo += box(530,415,440,210,'BattleComboState : RefCounted', ['index / queued_next / cast_serial','当前段只预约下一段一次','每次 hit_index / 目标 ID 去重','取消同时清预约和命中集合'], '../runtime/battle_combo_state.gd');
combo += box(1030,415,440,210,'GameplayAbilityInstance', ['每段独立激活 / 黑板 / elapsed','BattleFrameTimelineFeature 游标','Core battle.attack.impact → 宿主','取消后不发未来事件'], '../../gameplay_abiltiy_system/scripts/abilities/gameplay_ability_instance.gd','#fef3c7');
combo += arrow('M470 510H530','读取',478,497);
combo += arrow('M970 510H1030','激活',979,497);
combo += box(30,755,440,210,'打断与控制权', ['普通受击：门槛与霸体判定','跳取消 / 离地：结束地面技能','菜单 / 失焦 / 暂停：撤销预约','死亡：清全部技能，强制 DEAD'], '../runtime/battle_entity_2d.gd','#fee2e2');
combo += box(530,755,440,210,'BattleEntity2D：镜像与命中', ['第 4 段第二击：反向 + (-17,-4)','局部偏移后按朝向整体镜像','阵营过滤 / 当前事件目标去重','技能位移经过扫掠，墙体阻挡'], '../runtime/battle_entity_2d.gd');
combo += box(1030,755,440,210,'GAS Vital / AnimationAdapter', ['DamageCalculator → HealthVital','attack_1…5：原生 Spine 动作','独立动画实例，与段时间同步','换装不修改时长、位置或规则'], '../animation/spine_animation_adapter.gd','#e2e8f0');
combo += arrow('M250 755V690H750V625','取消 / 清预约',340,679);
combo += arrow('M1250 625V690H750V755','素材帧事件',1017,680);
combo += arrow('M970 852H1030','调用',979,835);
combo += text(32,1020,'迁移边界：动作、时长、倍率、第四段位移与反向判定已接入；完整击退、特效、持续 sensor 后续接入。',18);
fs.writeFileSync(path.join(docs,'combo-runtime.svg'),svg(1500,1070,'孙悟空 · 五段普攻时间线与系统联合运行图',combo));
// #endregion
console.log('Generated 8 Battle Foundation SVG diagrams.');
