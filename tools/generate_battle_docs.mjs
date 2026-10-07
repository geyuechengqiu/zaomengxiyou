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

// #region 属性链与现有插件联合类图
let attributePipeline = text(32,82,'最终属性由 GAS 计算；成长、装备与临时属性按来源管理，当前生命/魔法独立存在 Vital。');
attributePipeline += box(30,115,440,205,'BattleEntityDefinition', ['attribute_set：一级基础值','progression / initial_level','BattleGASBinding：2D / 3D 共用装配'], '../definitions/battle_entity_definition.gd','#dcfce7');
attributePipeline += box(530,115,440,205,'BattleAttributeProgression', ['growth_per_level：原版 Add 增量','experience_per_level：EXP 升级表','maximum_level：可配置等级上限'], '../definitions/battle_attribute_progression.gd','#dcfce7');
attributePipeline += box(1030,115,440,205,'BattleEquipmentDefinition', ['attribute_modifiers：只读修改器模板','BattleInventoryEquipment : Equip','槽位与耐久状态独立管理'], '../definitions/battle_inventory_equipment.gd','#dcfce7');
attributePipeline += box(30,415,440,235,'GAS 属性组件与实例', ['GameplayAttributeInstance：最终缓存','(base + ΣADD) × (1 + ΣMULTIPLY)','OVERRIDE / 最终取整 / 范围限制','begin_update / end_update：嵌套事务'], '../../gameplay_abiltiy_system/scripts/components/gameplay_attribute_component.gd');
attributePipeline += box(530,415,440,235,'BattleAttributeComponent', ['继承 GameplayVitalAttributeComponent','基础 → growth.level → equipment.<slot>','临时 status.<instance> → GAS final','等级、经验、换装、Buff 共用入口'], '../runtime/battle_attribute_component.gd','#fef3c7');
attributePipeline += box(1030,415,440,235,'GAS Status / Effect', ['GE_AttributeModifier：克隆模板','Status：叠层、时钟、到期与移除','同来源撤销，叠层不残留旧修改器','临时值不修改共享配置'], '../../gameplay_abiltiy_system/scripts/status/gameplay_status_instance.gd');
attributePipeline += box(30,790,440,220,'HealthVital / ManaVital', ['当前 hp / mp 与 hpMax / mpMax 分开','升级补基础+成长+装备上限','换装 / Buff 保留当前值并截断','可选保留比例 / 回满 / 补差额'], '../../gameplay_abiltiy_system/scripts/attributes/vitals/gameplay_vital.gd');
attributePipeline += box(530,790,440,220,'完整快照、面板与战斗', ['snapshot_changed：Vital同步后通知','Core：battle.attributes.changed','面板 / 下一次攻击读取相同 get_value','get_breakdown：解释属性来源'], '../../../examples/wukong_platform_demo.gd','#e2e8f0');
attributePipeline += box(1030,790,440,220,'Simple Inventory · C_Inventory', ['equip_changed(slot, item)','bind_inventory：连接 / 初次同步','换装备：同槽来源原子替换','卸装：删除该槽全部加成'], '../../simple_inventory/src/core/C_Inventory.gd');
attributePipeline += arrow('M250 320V360H630V415','独占 GAS 实例',282,350);
attributePipeline += arrow('M750 320V415','等级 / 经验',766,388);
attributePipeline += arrow('M1250 320V360H870V415','装备模板',1040,350);
attributePipeline += arrow('M530 505H470','继承 / 计算',405,400);
attributePipeline += arrow('M1030 535H970','修改器来源',1000,400);
attributePipeline += arrow('M250 650V790','属性上限变化',267,725);
attributePipeline += arrow('M750 650V790','最终值 / 完整通知',766,725);
attributePipeline += arrow('M470 897H530','当前值',478,885);
attributePipeline += arrow('M1250 790V705H915V650','槽位变化 → 替换来源',1035,693);
attributePipeline += text(32,1050,'配置只读；每个实体的属性、修改器、经验、Vital 和状态独立。卸装与状态到期按来源清理。',18);
fs.writeFileSync(path.join(docs,'attribute-pipeline.svg'),svg(1500,1090,'基础、成长、装备、临时与最终属性 · 插件联合类图',attributePipeline));
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
animation += box(530,110,440,185,'BattleActionProfile2D', ['普攻锁定 10 帧 / 受击锁定 8 帧','状态许可 / 霸体与打断条件','平台样例重力、跳跃速度'], '../definitions/battle_action_profile_2d.gd','#dcfce7');
animation += box(1030,110,440,185,'CharacterAnimationProfile', ['战斗动作名 → 原版 Spine 动作名','30 fps / 循环 / 固定脚底偏移','基础皮肤 / 显示比例 / 骨骼挂点'], '../animation/character_animation_profile.gd','#dcfce7');
animation += box(30,390,440,210,'Core EventBus', ['battle.attack.impact：第 4 / 30 秒','battle.attack.hit：阵营 + 区域判定','battle.animation_completed：仅通知','同步伤害引用沿用 GAS/Core'], '../../godot_core_system-0.0.4/source/event_system/event_bus.gd','#e2e8f0');
animation += box(530,390,440,210,'BattleEntity2D', ['CharacterBody2D：脚底为原点','独立 BattleActionState2D','使用动作名称命令表现层','物理体不缩放，朝向不镜像物理体'], '../runtime/battle_entity_2d.gd');
animation += box(1030,390,440,210,'CharacterAnimationAdapter', ['play_action / set_facing / set_skins','set_equipment_skin / progress / socket','完成与循环通知，不决定战斗许可','抽象 Node2D，可换其他动画后端'], '../animation/character_animation_adapter.gd','#fef3c7');
animation += box(30,700,440,210,'GAS 运行实例', ['BattleGASBinding：共用 2D/3D 装配','属性 atk、phyDef、hpMax / Vital','sunwukong_attack1：30 fps / 10 帧','生命耗尽 → 立即进入 DEAD'], '../runtime/battle_gas_binding.gd');
animation += box(530,700,440,210,'BattleActionState2D', ['IDLE / MOVE / RUN / TAKEOFF / AIR / LAND','ATTACK / HURT：技能与规则时间锁定','DEAD：不可攻击，不被动画复活','grounded 由运动控制器决定'], '../runtime/battle_action_state_2d.gd','#fce7f3');
animation += box(1030,700,440,210,'SpineAnimationAdapter', ['预置主 AnimationPlayer → 原生子播放器','Manual：只消费 combat delta','主时间轴驱动 Spine 姿态与完成通知','共用只读动画库，不共用播放状态'], '../animation/spine_animation_adapter.gd','#fef3c7');
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
const figure = (ox, facing) => `<path d="M${ox-145} 485H${ox+145}" stroke="#64748b" stroke-width="2"/><rect x="${ox+(facing>0?-228:-306)}" y="275.1" width="534" height="199.9" fill="#fef3c7" stroke="#f59e0b"/><rect x="${ox-22}" y="305" width="44" height="180" rx="22" fill="#dbeafe" stroke="#2563eb" stroke-width="2"/><path d="M${ox-14} 485H${ox+14}M${ox} 471V499" stroke="#10b981" stroke-width="3"/><path d="M${ox} 330L${ox+facing*120} 340" stroke="#64748b" stroke-width="8"/><circle cx="${ox+facing*120}" cy="340" r="6" fill="#f59e0b"/>${text(ox-68,525,'角色原点 (0,0)',18)}${text(ox-100,260,'物理体始终不翻转',18)}${text(ox-130,125,facing>0?'右向：完整 ABRect':'左向：完整镜像',24)}`;
registration += figure(320,1) + figure(1070,-1);
registration += box(30,615,650,175,'表现坐标', ['固定 skeleton_offset=(0,-4.2384)，display_scale=2','保留原 atlas trim 与附件 x/y，按原 drawOrder 显示','骨架 scale_x=±1；武器三个原骨骼挂点一起镜像'], '../animation/spine_animation_adapter.gd','#fef3c7');
registration += box(710,615,650,175,'战斗区域：第一段原版 ABRect', ['右：Rect2(-114,-104.95,267,99.95) × 2','左：Rect2(-153,-104.95,267,99.95) × 2','实际尺寸 534 × 199.9；包含脚底两侧'], '../runtime/battle_entity_2d.gd');
registration += text(32,835,'攻击范围以角色脚底为原点；皮肤与武器长度不改变它。完成事件不决定地面状态、攻击许可或死亡状态。',18);
fs.writeFileSync(path.join(docs,'animation-registration.svg'),svg(1400,875,'孙悟空 · 脚底原点、装备挂点与攻击镜像',registration));
// #endregion
// #region 操作控制器联合类图
let operations = text(32,80,'Godot 输入 → 语义意图 → 战斗许可 → GAS 与动画；配置共享，控制器与缓存按实体独立。');
operations += box(30,115,440,210,'CoreOperationBindings', ['默认物理键 / 用户配置 / InputMap','捕获新键 / 冲突与保留键 / 保存','改键只影响输入层，角色不改代码','菜单暂停时 Always 运行'], '../../godot_core_system-0.0.4/source/operation_system/operation_bindings.gd','#e2e8f0');
operations += box(530,115,440,210,'CoreOperationController', ['原生 _unhandled_input：UI 优先','多来源强度 / 四阶段 / 长按 / 双击','控制权原因集合 / 来源释放隔离','未缩放 input_time / 精确消费'], '../../godot_core_system-0.0.4/source/operation_system/operation_controller.gd');
operations += box(1030,115,440,210,'CoreOperationProfile', ['语义意图 → 原生动作 / 轴规则','default_keys / reserved_keys','缓存 0.2 s / 长按 0.3 s','业务同方向双击 < 0.5 s'], '../../godot_core_system-0.0.4/source/operation_system/operation_profile.gd','#dcfce7');
operations += box(30,435,440,185,'BattleOperationMenu', ['模态 UI / Esc / 绑定设置','menu 原因与 remapping 独立','关闭菜单不会覆盖失焦控制权'], '../input/battle_operation_menu.gd','#e2e8f0');
operations += box(530,435,440,210,'BattlePlayerOperations', ['按序分发按下 / 持有 / 松开 / 变化','聚合轴快照 / 技能槽 → GAS ID','交给 Core 当前叶子处理与判许可','公共操作后追加角色钩子'], '../input/battle_player_operations.gd');
operations += box(1030,435,440,210,'CoreOperationBuffer / Intent', ['按下快照 / sequence / 持有时长','有限队列 / 独立消费 / 过期','短按不丢，连按各保留一次','cancelled 释放只清理蓄力'], '../../godot_core_system-0.0.4/source/operation_system/operation_buffer.gd','#fef3c7');
operations += box(30,790,440,185,'BattleSession / BattleClock', ['先推进未缩放输入时间','再计算 combat delta 驱动动作','暂停立即同步控制权'], '../runtime/battle_session.gd','#fef3c7');
operations += box(530,790,440,210,'Core 当前动作叶子 / 实体', ['handle_operation：四阶段语义','当前叶子许可 → 实体执行命令','方向释放 → IDLE / idle 动画','攻击中释放只清意图，不解除锁定'], '../runtime/battle_action_leaf_state_2d.gd');
operations += box(1030,790,440,210,'GAS / AnimationAdapter', ['GameplayAbilityComponent：技能','Vital / Status：生命与状态','Spine：动作、朝向、皮肤、进度','完成通知不授予战斗许可'], '../animation/character_animation_adapter.gd','#e2e8f0');
operations += arrow('M470 205H530','映射',478,195);
operations += arrow('M1030 205H970','定义',979,195);
operations += arrow('M250 435V325','改键',266,386);
operations += arrow('M750 325V435','意图',766,386);
operations += arrow('M470 527H530','占用',478,515);
operations += arrow('M1030 550H970','队列',979,537);
operations += arrow('M750 645V790','handle_operation',766,728);
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
motion += box(1030,435,440,235,'Core 动作机 / 状态入口', ['BaseStateMachine + 9 个 BaseState','BattleActionState2D 委托当前叶子','叶子 elapsed / active_rules 覆盖','霸体 + 类型 + 优先级决定打断','DEAD 终态，Core 跳转也受守卫'], '../runtime/battle_action_state_machine_2d.gd','#fce7f3');
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
combo += box(530,415,440,210,'BattleComboState : RefCounted', ['index / queued_next / cast_serial','当前段只预约下一段一次','仅负责连击推进与预约','命中集合交给 BattleAttackInstance'], '../runtime/battle_combo_state.gd');
combo += box(1030,415,440,210,'GameplayAbilityInstance', ['每段独立激活 / 黑板 / elapsed','BattleFrameTimelineFeature 游标','Core battle.attack.impact → 宿主','取消后不发未来事件'], '../../gameplay_abiltiy_system/scripts/abilities/gameplay_ability_instance.gd','#fef3c7');
combo += arrow('M470 510H530','读取',478,497);
combo += arrow('M970 510H1030','激活',979,497);
combo += box(30,755,440,210,'打断与控制权', ['普通受击：门槛与霸体判定','跳取消 / 离地：结束地面技能','菜单 / 失焦 / 暂停：撤销预约','死亡：清全部技能，强制 DEAD'], '../runtime/battle_entity_2d.gd','#fee2e2');
combo += box(530,755,440,210,'BattleEntity2D：镜像与命中', ['所有技能复用一个 BattleHitbox2D','从实例技能读取 hit_rect / 偏移','每击更新形状，再按朝向整体镜像','阵营过滤 / 同击目标去重'], '../runtime/battle_entity_2d.gd');
combo += box(1030,755,440,210,'GAS Vital / AnimationAdapter', ['DamageCalculator → HealthVital','attack_1…5：原生 Spine 动作','独立动画实例，与段时间同步','换装不修改时长、位置或规则'], '../animation/spine_animation_adapter.gd','#e2e8f0');
combo += arrow('M250 755V690H750V625','取消 / 清预约',340,679);
combo += arrow('M1250 625V690H750V755','素材帧事件',1017,680);
combo += arrow('M970 852H1030','调用',979,835);
combo += text(32,1020,'迁移边界：动作、时长、倍率、第四段位移与 ABRect 已接入；原版完整击退、特效与 sensor 流程仍待迁移。',18);
fs.writeFileSync(path.join(docs,'combo-runtime.svg'),svg(1500,1070,'孙悟空 · 五段普攻时间线与系统联合运行图',combo));
// #endregion
// #region Core 动作状态机继承与生命周期类图
let states = text(32,80,'状态与时间以 Core 当前叶子为准：注册供查询，唯一战斗时钟驱动，销毁显式注销并断开所属关系。');
states += box(30,120,440,220,'Core StateMachineManager', ['注册 ID：场次 + 实体运行 ID','update / physics / input = false','get_state_machine / get_current_state','unregister → stop → dispose','被拒绝的启动不发 started'], '../../godot_core_system-0.0.4/source/state_machine/state_machine_manager.gd','#e2e8f0');
states += box(530,120,440,220,'BattleActionStateMachine2D', ['extends BaseStateMachine / 9 叶子','move_axis / running：语义运行数据','handle_operation → 当前叶子','transition_local：死亡终态守卫','dispose：清叶子、agent 与变量'], '../runtime/battle_action_state_machine_2d.gd','#fce7f3');
states += box(1030,120,440,220,'Core BaseStateMachine', ['current_state / previous_state / states','start / stop / transition_local','physics_update → 当前叶子','state_changed(from, to)','Core 负责退出、进入与历史'], '../../godot_core_system-0.0.4/source/state_machine/base_state_machine.gd','#e2e8f0');
states += box(30,460,440,220,'BattleActionState2D', ['语义兼容入口，不另存状态/计时','current / elapsed → Core 当前叶子','enter(kind, rules) → Core 跳转','advance → machine.physics_update','bind / dispose：注册生命周期'], '../runtime/battle_action_state_2d.gd');
states += box(530,460,440,220,'BattleActionLeafState2D', ['extends BaseState / kind / elapsed','handle_operation：四阶段意图','按下发动 / 松开清方向 → IDLE','进入复制规则 / 退出清覆盖','物理条件表与移动/跳跃/打断许可'], '../runtime/battle_action_leaf_state_2d.gd','#fce7f3');
states += box(1030,460,440,220,'Core BaseState', ['state_machine / agent / is_active','enter → _enter → state_entered','exit → _exit → state_exited','physics_update → _physics_update','叶子 transition_to → 所属机器'], '../../godot_core_system-0.0.4/source/state_machine/base_state.gd','#e2e8f0');
states += box(30,805,440,200,'时钟 / 操作意图', ['战斗时钟统一推进运动与 GAS','Core 控制器 → 适配 → 当前叶子','按聚合轴判断移动，释放回待机','撤回控制同步清方向及预约'], '../input/battle_player_operations.gd','#fef3c7');
states += box(530,805,440,200,'BattleEntity2D', ['每个实体拥有独立动作机','Core 状态改变 → 战斗事件通知','重生 / 离树 → 注销动作机','RefCounted 叶子所属引用断开'], '../runtime/battle_entity_2d.gd');
states += box(1030,805,440,200,'GAS 技能 / 独立动画适配', ['连击每段重入 Core ATTACK','GAS 时长结束才推进下一段','伤害与霸体 → HURT / DEAD','动画完成只通知，不授予许可'], '../animation/character_animation_adapter.gd','#dcfce7');
states += arrow('M470 225H530','登记',479,213);
states += arrow('M970 225H1030','继承',979,213);
states += arrow('M250 460V400H650V340','持有',375,390);
states += arrow('M750 340V460','持有叶子',766,405);
states += arrow('M970 565H1030','继承',979,553);
states += arrow('M250 805V680','推进',266,746);
states += arrow('M750 805V735H250V680','命令 / 清理',376,725);
states += arrow('M1250 805V735H850V680','GAS 规则',985,725);
states += text(32,1060,'Core 名称：IDLE / MOVE / RUN / TAKEOFF / AIR / LAND / ATTACK / HURT / DEAD；旧枚举 JUMP 对应 AIR。',18);
states += text(32,1100,'死亡守卫涵盖：语义入口、Core 管理器、叶子跳转及 stop/start；重生创建新机器和新叶子。',18);
fs.writeFileSync(path.join(docs,'action-state-machine.svg'),svg(1500,1140,'孙悟空 · Core 状态机接入、继承与生命周期类图',states));
// #endregion
// #region 原版攻击范围与坐标转换
const nativeHitboxes=JSON.parse(fs.readFileSync(path.join(root,'data/battle2d/attack_hitboxes_source.json'),'utf8'));
let ranges=text(32,80,'原单位横向投影，脚底 X=0；纵向数据列于每行下方。游戏场景按 2 倍转换。');
ranges += '<path d="M450 112V625" stroke="#059669" stroke-width="2" stroke-dasharray="6 5"/>';
ranges += text(459,125,'脚底原点',16,'#059669');
nativeHitboxes.rectangles.forEach((entry,i)=>{
  const [rx,ry,rw,rh]=entry.rect, y=160+i*95;
  ranges += text(32,y+30,`attack_${i+1}`,21,'#0f172a');
  ranges += `<rect x="${450+rx*1.2}" y="${y}" width="${rw*1.2}" height="42" rx="5" fill="${i===3?'#fef3c7':'#dbeafe'}" stroke="#64748b"/>`;
  ranges += text(450+rx*1.2,y-8,String(rx),16);
  ranges += text(450+(rx+rw)*1.2-12,y-8,String(Number((rx+rw).toFixed(2))),16);
  ranges += text(195,y+67,`ABRect(${rx}, ${ry}, ${rw}, ${rh})`,17);
});
ranges += box(935,140,535,205,'原版碰撞数据链', ['attackV427.swf：abs / ABConfigs','getAbRects(shootAssetLink)','SkillControl.reBuilBodyBox → sensor','AI atkRange 不参与伤害矩形'], '../../../data/battle2d/attack_hitboxes_source.json','#dcfce7');
ranges += box(935,405,535,205,'第四段第二击', ['ABRect 与第一击相同','显示 scaleX=-1 不反转碰撞框','局部偏移 (-17,-4)，再按朝向镜像','跟随角色位置，保留技能位移'], '../../../data/battle2d/attack4.tres','#fef3c7');
ranges += box(30,685,690,175,'技能数据驱动统一框', ['每击：hit_rect → 正缩放 → 偏移 → 素材比例','更新同一个 CollisionShape2D → 镜像 → 世界变换','修改技能判定数据，预览与伤害范围一起更新'], '../movement/battle_hitbox_2d.gd');
ranges += box(780,685,690,175,'命中边界与当前运行方式', ['每段、每击、左右方向都验证前后边界与框外','独立受击区域 → 攻击实例去重 → GAS / Vital','五连击默认瞬时查询；单段验收支持持续窗口'], '../../../examples/verify_stage_four.gd','#e2e8f0');
fs.writeFileSync(path.join(docs,'attack-ranges.svg'),svg(1500,900,'孙悟空 · 五段原版 ABRect 与命中坐标',ranges));
// #endregion
// #region AnimationPlayer 与编辑器攻击框联合类图
let authoring = text(32,80,'所有技能复用一个场景判定框；编辑器与战斗均读取技能数据，许可继续由 Core/GAS 决定。');
authoring += box(30,115,440,215,'sunwukong_visual.tscn', ['静态 SpineSprite / 原生轨道 / 两个播放器','一个 AttackHitbox + CollisionShape2D','十四个语义动作，素材时长保持','CharacterBody2D 实例化表现场景'], '../../../data/animation/sunwukong_visual.tscn','#dcfce7');
authoring += box(530,115,440,215,'主 AnimationPlayer', ['idle / move / run / attack_1…5 / …','TYPE_ANIMATION → 原生子播放器','预览 action / time 属性轨道','编辑器拖动 ↔ Spine 原素材姿态'], '../../../data/animation/sunwukong_visual.tscn','#fef3c7');
authoring += box(1030,115,440,215,'SpineAnimationTrack', ['SpineSprite 的直接子节点','预置子 AnimationPlayer，复用原生 clip','44 个素材动作及循环版本','保留槽位、附件、皮肤与层序'], '../animation/spine_animation_adapter.gd','#fef3c7');
authoring += box(30,465,440,215,'BattleClock / Core 状态机', ['唯一 combat delta：暂停、慢动作、停顿','许可、死亡、打断与落地由状态决定','通过动作名称命令适配器','动画完成只通知'], '../runtime/battle_action_state_machine_2d.gd');
authoring += box(530,465,440,215,'SpineAnimationAdapter', ['获取场景节点，不 new/add_child','play / advance / playback_position','主时间同步 Spine，手动模式','朝向与换装不重置播放器时间'], '../animation/spine_animation_adapter.gd');
authoring += box(1030,465,440,215,'GAS 技能定义 / 帧事件', ['ability_id + hit_index → 命中 payload','hit_rect / hit_scale_x,y / hit_offset','source_frame / fps → 预览当前命中','修改技能数据，复用同一形状'], '../../../data/battle2d/attack4.tres','#fce7f3');
authoring += box(30,815,440,215,'GAS → Core impact → Entity2D', ['素材帧决定判定时机与命中序号','读取实例技能 → 配置唯一形状','攻击实例 → 独立受击区域 / 去重','DamageCalculator → HealthVital'], '../runtime/battle_entity_2d.gd');
authoring += box(530,815,440,215,'BattleHitbox2D : Area2D', ['唯一 CollisionShape2D / RectangleShape2D','技能矩形 → 正缩放 → 偏移 → 比例','右向局部框 → 镜像 → 世界多边形','无效数据清空，不沿用上一击范围'], '../movement/battle_hitbox_2d.gd','#fce7f3');
authoring += box(1030,815,440,215,'实例隔离与新角色', ['矩形 Local To Scene：按实例复制','技能实例定义独立，预览引用只读','新角色只配一个框和技能数据','调整范围无需改公共角色代码'], '../../../data/animation/README.md','#dcfce7');
authoring += arrow('M470 220H530','预置',478,210);
authoring += arrow('M970 220H1030','clip',982,210);
authoring += arrow('M750 465V330','控制',766,405);
authoring += arrow('M470 565H530','命令',482,553);
authoring += arrow('M900 330V380H1250V465','预览轨道',1040,372);
authoring += arrow('M1250 680V740H750V815','读取并更新',884,730);
authoring += arrow('M470 915H530','查询',482,903);
authoring += arrow('M970 915H1030','隔离',982,903);
authoring += text(32,1080,'每个实体始终只有一个攻击框：素材矩形、缩放和偏移读取技能数据；第四段双击仍各自去重，同一形状更新。',18);
fs.writeFileSync(path.join(docs,'animation-authoring.svg'),svg(1500,1120,'孙悟空 · 可视化动画与攻击判定框',authoring));
// #endregion
// #region 单段攻击与最小战斗闭环联合类图
let singleAttack = text(32,82,'Core 操作与状态 → GAS 素材帧 → 单一攻击框 × 独立受击区域 → Vital 扣血 → 反馈 → 待机。');
singleAttack += box(30,120,440,200,'Core 输入与动作状态机', ['OperationController → attack 意图','BattlePlayerOperations → 当前叶子','许可 / ATTACK / HURT / DEAD','菜单释放输入并占用控制权'], '../input/battle_player_operations.gd','#dcfce7');
singleAttack += box(530,120,440,200,'BattleEntity2D : CharacterBody2D', ['组合运动 / 状态 / 技能 / 动画','每次施放创建独立攻击实例','验证场次 / 实体 / 技能 / 攻击编号','统一受击查询和伤害入口'], '../runtime/battle_entity_2d.gd');
singleAttack += box(1030,120,440,200,'GAS 技能 / FrameTimeline', ['实例黑板：elapsed / next_event','30 fps：第 4 帧发布 impact','事件附加当前 attack_id','第 10 帧结束实例技能'], '../gas/battle_frame_timeline_feature.gd','#fef3c7');
singleAttack += box(30,415,440,210,'BattleAttackInstance : RefCounted', ['attack_id / ability_id / attacker WeakRef','attacker_id / 起手阵营 / elapsed','windows[hit_index] / window_end','每击目标集合：先登记再扣血'], '../runtime/battle_attack_instance.gd','#fce7f3');
singleAttack += box(530,415,440,210,'BattleHitbox2D : Area2D', ['唯一 CollisionShape2D，读取技能数据','hit_rect → 正缩放 → 偏移 → 比例','以脚底镜像 → 世界多边形','窗口未结束：每个战斗 tick 查询'], '../movement/battle_hitbox_2d.gd','#fce7f3');
singleAttack += box(1030,415,440,210,'BattleHurtbox2D : Area2D', ['独立可编辑 RectangleShape2D','vulnerable / get_polygon_global()','多边形相交；不参与物理阻挡','实例局部资源，不改共享模板'], '../movement/battle_hurtbox_2d.gd','#fce7f3');
singleAttack += box(30,740,440,210,'GAS 伤害 / HealthVital', ['DamageCalculator 读取当前最终属性','临时公式：max(1, atk-phyDef) × 倍率','DamageInfo → apply_damage','生命耗尽 → Core DEAD / 取消攻击'], '../../gameplay_abiltiy_system/scripts/attributes/vitals/health_vital.gd','#fef3c7');
singleAttack += box(530,740,440,210,'BattleCombatFeedback2D', ['snapshot_changed → 当前 / 最大生命','Core battle.attack.hit → 实际扣血','生命条 / 伤害飘字 / 击杀标签','combat delta 驱动上浮与淡出'], '../presentation/battle_combat_feedback_2d.gd','#e2e8f0');
singleAttack += box(1030,740,440,210,'CharacterAnimationAdapter', ['悟空：原有 Spine / AnimationPlayer','木桩：AnimationPlayerAdapter2D','hurt / death：场景预置动画','动画完成只通知，不裁决战斗规则'], '../animation/animation_player_adapter_2d.gd','#e2e8f0');
singleAttack += box(30,1060,440,185,'BattleClock / 生命周期', ['暂停 / 停顿冻结，慢动作统一缩放','打断 / 死亡 / 替换 / 退出关闭攻击','attack.finished 每个实例只通知一次','旧编号事件不能伤害新一次施放'], '../runtime/battle_clock.gd','#dcfce7');
singleAttack += box(530,1060,440,185,'移动物理体：独立责任', ['CharacterBody2D + CapsuleShape2D','只负责地面 / 墙 / 平台 / 运动','攻击框和受击框物理层均为 0','木桩物理宽 44，受击宽 90'], '../../../data/battle2d/dummy/wooden_dummy.tscn','#dcfce7');
singleAttack += box(1030,1060,440,185,'单段场景与验收', ['J 短按 / 长按：一次第一段攻击','命中 / 打空 / 击杀 / 左右镜像','途中进入 / 去重 / 暂停 / 菜单','独立 manifest；不修改原五连击'], '../../../examples/verify_single_attack.tscn','#dcfce7');
singleAttack += arrow('M470 220H530','意图',482,205);
singleAttack += arrow('M970 220H1030','激活',982,205);
singleAttack += arrow('M750 320V365H250V415','创建 / 管理',550,355);
singleAttack += arrow('M1250 320V365H900V415','素材帧事件',1010,355);
singleAttack += arrow('M470 520H530','去重',482,505);
singleAttack += arrow('M970 520H1030','相交',982,505);
singleAttack += arrow('M750 625V685H250V740','敌对 / 存活 / 新命中',480,675);
singleAttack += arrow('M470 845H530','通知',482,830);
singleAttack += arrow('M970 845H1030','表现',982,830);
singleAttack += text(32,1300,'时间线：起手 0 → 命中 [4/30, 6/30) 秒 → 收招 → 10/30 秒结束 / 待机；同一窗口同一目标只结算一次。',18);
singleAttack += text(32,1334,'2 帧持续窗口是阶段 6 的临时配置；未配置窗口的原五连击保持瞬时查询，原版完整 sensor 流程尚待迁移。',18);
fs.writeFileSync(path.join(docs,'single-attack-runtime.svg'),svg(1500,1380,'阶段 6 · 单段攻击、受击区域与反馈联合类图',singleAttack));
// #endregion
console.log(`Generated ${fs.readdirSync(docs).filter(file => file.endsWith('.svg')).length} Battle Foundation SVG diagrams.`);
