# 插件重复系统：取舍与接入建议

基于本项目当前五套插件源码比较：Gameplay Ability System（下称 GAS）、Godot Core System（下称 Core）、Simple Inventory、Panku Console 与 DebugDraw。结论按实际能力、运行语义、已知缺陷和修改成本判断，没有运行性能基准，也不将插件功能数量当作质量评分。最初仅补充分析；随后 GAS 事件已迁移到 Core，本文事件部分及类图已更新为迁移后的实现，其它系统仍为取舍建议。

当前项目以 GAS 管战斗数据和效果，以 Core 补充基础服务；全部 GAS 总线事件已共享 CoreEventBus，并保留同步减伤。战斗标签的权威来源、角色输入入口和事件实体作用域仍需明确。调试、状态机、背包等功能多数可以协作。

## 重叠程度与结论

| 功能 | 涉及实现 | 实际重叠 | 当前项目建议 |
| --- | --- | --- | --- |
| 标签 | GAS TagManager / Core 标签树与容器 | 同一对象的标签保存与查询，语义不同 | 战斗统一用 GAS；Core 标签仅用于明确独立的对象分类 |
| 事件 | GAS 发布方与状态监听 / CoreEventBus | 已合并为一条 Core 总线 | 全部事件使用 `[Dictionary]` 同步发布；保留状态统一监听和退出清理 |
| 输入 | Core InputManager / OperationController / GAS AbilityInputFeature | 两个 Core 输入入口重叠，GAS 只匹配技能输入 | 角色入口优先 OperationController，技能匹配与快捷键显示保留 Feature |
| 时间 | Core TimeManager / GAS 冷却、持续时间、周期效果与 BT 等待 | 都计时，但所有权和时钟不同 | 保留 GAS 实例计时；统一暂停/缩放协议，不改成全局同名 Timer |
| 状态与流程 | BaseStateMachine / GAS BT 与 GameplayStatus | 部分流程控制重叠；逻辑状态与 Buff 不等价 | 状态机管角色，BT 管技能执行，Status 管增益/减益 |
| 触发 | Core GameplayTrigger / GAS 状态事件与周期 Feature | 事件/周期调度重叠 | Buff 用 GAS；关卡/任务规则用 Core Trigger |
| 属性 | Item.attributes / GAS 属性、修改器、Vital | 装备数值定义与数值运算有交集 | 背包保存物品；GAS 是角色最终值的权威来源 |
| 配置 | Core ConfigManager / PankuConfig | 都读写用户配置 | 游戏配置用 Core；控制台自己的配置保留 Panku |
| 日志 | CoreLogger / Panku native_logger | 记录与显示同一日志信息 | Core 产生日志，Panku 展示；避免同一消息重复写入 |
| 资源与节点池 | Core Resource/EntityManager / DebugDraw 池 / GAS 载具和 Cue | 缓存/创建/回收机制局部重叠 | 不让两个管理器共同拥有同一节点；暂不把 GAS 生命周期交给通用池 |
| 调试 UI | Panku / GAS 调试面板 / DebugDraw | 都提供调试，但观察对象不同 | 保留分工，避免同时显示重复内容即可 |
| 模块生命周期 | CoreSystem / PankuModuleManager / GAS Feature | 都登记和更新模块，挂载范围不同 | 各插件保留本地管理器，不再加一个全项目逐帧转发层 |

## 标签：战斗方面 GAS 更合适

源码：[GAS TagManager](../addons/gameplay_abiltiy_system/scripts/singletons/gameplay_tag_manager.gd)、[Core TagManager](../addons/godot_core_system-0.0.4/source/tag_system/gameplay_tag_manager.gd)、[CoreGameplayTag](../addons/godot_core_system-0.0.4/source/tag_system/gameplay_tag.gd)、[GameplayTagContainer](../addons/godot_core_system-0.0.4/source/tag_system/gameplay_tag_container.gd)。

GAS 用资源登记标签定义，用 Node 元数据保存引用计数，以 Group 支持查询，并有继承、互斥和查询缓存。Core 用点分路径自动创建树，用容器保存去重后的标签集合，以 WeakRef 索引查询拥有标签的对象。

具体例子：两个 Buff 都添加 `state.invulnerable`。GAS 的计数从 0 → 1 → 2，第一个 Buff 结束后为 1，角色仍无敌；Core 容器第二次 add 被去重，第一次 remove 就会移除标签。这里 GAS 的语义更符合多来源战斗效果。GAS 目前是计数而非完整的“来源 ID → 标签”账本，调用者仍须保证添加与移除配对；属性修改器的 source_id 不能直接等同于标签来源记录。

继承也不同：GAS 按显式资源父关系查询“拥有子标签是否满足父标签”；Core 的非精确 matches 同时向两个方向匹配，所以拥有 `state` 也可能满足 `state.stunned`。Core 更便于对象分类和查找，直接拿来做技能禁用条件容易放宽判定。GAS 则需要先登记资源，配置成本更高，强制互斥移除和关系变化后的缓存一致性也有边界。

**取舍：角色的免疫、控制、阵营、技能条件先使用 GAS 标签。需要 Core 查询世界分类对象时，可保留单独的分类容器；同一战斗标签不要同时维护两份。** 后续若统一，需要保留引用计数、明确单向继承、处理缓存失效及拥有者生命周期。

## 事件：已统一使用 Core，保留 GAS 战斗同步链路

源码：[HealthVital](../addons/gameplay_abiltiy_system/scripts/attributes/vitals/health_vital.gd)、[GameplayStatusComponent](../addons/gameplay_abiltiy_system/scripts/components/gameplay_status_component.gd)、[CoreEventBus](../addons/godot_core_system-0.0.4/source/event_system/event_bus.gd)、[事件回归验证](../examples/verify_core_events.gd)。

原 GAS 总线只有统一的同步 Dictionary 广播，功能简单。迁移后旧脚本、UID、自动加载及插件注册全部移除；技能、状态、生命值和技能栏全部 10 处发布直接调用 `CoreSystem.event_bus.push_event(name, [context], true)`。Core 的按名订阅回调获得一个 Dictionary，无需转发或同时维护两条总线。

状态组件使用 Core 的 `event_pushed(name, payload)` 接受单 Dictionary 负载，不限定事件名字，因此宿主自定义事件和自定义 StatusFeature 保持可用。入树订阅、离树退订、再入树恢复，每个组件只连接一次。状态监听先于 Core 按名订阅的优先级回调执行，不参与其优先级排序；实例仍把字段合并进自身上下文缓存。

关键顺序：HealthVital 本地受伤前信号 → Core 同步推送 → GAS 状态监听修改 DamageInfo → Core 按名同步订阅者修改同一个对象 → HealthVital 读取 final_damage 并扣血。回归测试以两次 0.5 减伤验证 20 点只扣 5 点，并验证完全减伤、死亡及全部事件进入 Core 订阅/历史。GAS 发布始终显式使用 immediate=true；BT/属性/组件本地信号维持原接口。

Core 的优先级、过滤、once 和历史适合通用服务，但现有元数据键只区分对象和方法，不完整区分 bind Callable；once 在回调后断开，递归推送仍可能重复；延迟 handled 只表示调度结束。迁移不依赖这些边界行为，也未修改它们。事件底层仍广播，伤害上下文已增加 entity 目标字段；新增 Battle Foundation 宿主开启状态事件过滤，普通 GAS 场景默认保留广播语义。

## 输入：OperationController 的角色输入设计更好

源码：[InputManager](../addons/godot_core_system-0.0.4/source/input_system/input_manager.gd)、[InputEventProcessor](../addons/godot_core_system-0.0.4/source/input_system/features/input_event_processor.gd)、[OperationController](../addons/godot_core_system-0.0.4/source/operation_system/operation_controller.gd)、[AbilityInputFeature](../addons/gameplay_abiltiy_system/scripts/abilities/features/ability_input_feature.gd)。

Core InputManager 的强项是输入状态、二维虚拟轴、缓冲和录制工具。它全局轮询 InputMap，并在 `_input()` 接事件；PROCESS_MODE_ALWAYS 在暂停时仍更新。当前默认 Handler 全返回 false，而 InputManager 遇 false 就提前返回，所以事件驱动的 action_triggered、缓冲与录制路径默认不能按预期运行；轮询路径仍存在。声明的 Filter 列表也未进入执行，InputConfigAdapter 还调用不存在的 is_loaded()。

OperationController 按角色独立，使用 `_unhandled_input()` 接受新按下，给 UI 优先处理机会；`_input()` 只清理已有来源的释放。它按设备/键来源聚合强度，多个来源不会因松开其中一个而全部清零；支持虚拟意图、AI/网络/触屏接入，以及失焦/暂停/退出时清理。优势是作用域和生命周期设计，尚不代表所有设备场景都已经测试。

GAS AbilityInputFeature 只做输入匹配和快捷键显示，不是完整输入管理器，也不自行监听场景树输入。它可以被上层入口使用。使用语义意图时，应以意图 ID 映射技能 ID；InputFeature 可继续承担按键显示，避免在多个入口重复发动同一技能。

**取舍：角色操作优先用 OperationController；输入缓冲、录制等工具按需接入。现有 InputManager 应修正事件协议后再作为正式角色入口。** 不同时从全局 `_input()`、意图信号和快捷栏回调对同一次操作发动技能。

## 时间：统一时钟规则，保留局部计时所有权

源码：[TimeManager](../addons/godot_core_system-0.0.4/source/time_system/time_manager.gd)、[CooldownFeature](../addons/gameplay_abiltiy_system/scripts/abilities/features/cooldown_feature.gd)、[GameplayAbilityInstance](../addons/gameplay_abiltiy_system/scripts/abilities/gameplay_ability_instance.gd)、[FeaturePeriodicEffects](../addons/gameplay_abiltiy_system/scripts/status/features/feature_periodic_effects.gd)。

Core TimeManager 适合命名计时器、模块内时间缩放和暂停；GAS 在技能或状态实例中保存冷却、持续时间与周期计时，随所属实例更新。实例计时更符合“两个角色学了同一技能，却分别处于不同冷却”的语义，用一个全局 `skill_q` Timer 替换会冲突；即使给全局 ID 增加角色前缀，也要重新管理取消与清理。

两者都有限制：Core 循环计时器把 elapsed 归零，丢弃周期余量；GAS 周期效果每帧至多执行一次。Core 的 time_scale 不控制 Engine、SceneTree 或 GAS；GAS 黑板在新激活时 clear，Feature 的持久数据与本轮执行数据共用黑板，需要避免重置不该重置的计时。BTWait 已改为累计传入 delta，可与其它 GAS 实例计时一起接受战斗时钟控制。

**取舍：战斗冷却和 Buff 持续时间保留 GAS；通用通知可用 Core Timer。** 阶段一已通过 [Battle Foundation](../addons/battle_foundation/README.md) 定义暂停、慢动作和受击停顿规则，并向 GAS 提供一致的固定物理 delta。缩放问题不能通过简单删除一套计时器解决。

## 状态机、行为树、Status：分别适合不同问题

源码：[BaseStateMachine](../addons/godot_core_system-0.0.4/source/state_machine/base_state_machine.gd)、[StateMachineManager](../addons/godot_core_system-0.0.4/source/state_machine/state_machine_manager.gd)、[BTNode](../addons/gameplay_abiltiy_system/scripts/behavior_tree/bt_node.gd)、[BTRunner](../addons/gameplay_abiltiy_system/scripts/behavior_tree/bt_runner.gd)、[GameplayStatusInstance](../addons/gameplay_abiltiy_system/scripts/status/gameplay_status_instance.gd)。

Core 状态机擅长角色“待机、移动、受击”等互斥逻辑，以及嵌套 enter/exit。GAS 行为树擅长“选目标 → 前摇 → 扣消耗 → 执行效果 → 等下一段输入”的组合流程。GAS Status 管多个同时存在的增益/减益、叠层、持续时间、属性修改和 Cue。

用状态机实现一套复杂技能容易增加阶段状态和跳转；用行为树处理简单互斥角色状态则增加树结构复杂度。Status 允许多个实例共存，不能直接等同于一台只保存一个 current_state 的机器。

两边也有需修复的生命周期边界：状态机集中驱动和角色自己 update 不应同时开启；注册机需随拥有者注销。GAS BTRunner.reset 当前调用 BTInstance 不存在的 reset()，结束后也未自动停掉 runner；观察者中断能力不应仅凭节点名称推断已经完整。不能凭这个问题判定整个 GAS 技能树应改成状态机。

**取舍：角色逻辑用状态机、技能内部编排用 BT、增益/减益用 Status。** 高频移动更新更适合由角色自身驱动逻辑机；全局流程机可由 StateMachineManager 驱动。两者负责不同范围，只连接意图和技能接口。

孙悟空现已按此方式接入：BattleActionStateMachine2D 继承 Core BaseStateMachine，九个独立 BaseState 叶子执行动作转换与权限判断；StateMachineManager 负责登记/查询/注销，三个默认驱动标志关闭，由 BattleSession 的 combat delta 唯一推进。五段攻击仍由 GAS 技能实例计时，Buff 仍由 GAS Status 管理。生命周期、死亡守卫和清理见 [接入文档](../addons/battle_foundation/movement/README.md#动作状态接入-core-插件状态机)。

## 触发器：Buff 用 GAS，通用规则用 Core

源码：[GameplayTrigger](../addons/godot_core_system-0.0.4/source/trigger_system/gameplay_trigger.gd)、[TriggerManager](../addons/godot_core_system-0.0.4/source/trigger_system/trigger_manager.gd)、[FeatureEventListener](../addons/gameplay_abiltiy_system/scripts/status/features/feature_event_listener.gd)、[FeaturePeriodicEffects](../addons/gameplay_abiltiy_system/scripts/status/features/feature_periodic_effects.gd)。

Core Trigger 的强项是概率、次数、组合条件和立即/事件/周期模式；可用于关卡刷怪、任务规则。GAS 的事件/周期 Feature 直接持有所属 Status，天然连接 Effect、层数、来源、到期与清理，适合燃烧、护盾和受伤触发效果。

Core Trigger 不负责属性来源清理、Buff 优先级和层数。相反，GAS Feature 没有通用条件工厂和次数概率组合。将一次燃烧同时交给 Core 周期 Trigger 与 GAS 周期 Feature 会重复造成伤害；需要选一个调度者。

当前 Core 注销最后一个事件触发器后仍保留空事件键，再激活可能不重新订阅；CompositeTriggerCondition 的配置子条件构造未使用类型工厂。GAS 的全局状态事件仍有实体隔离问题。**战斗被动优先使用 GAS 状态 Feature；Core Trigger 用于战斗之外或显式带 actor/target 的规则。**

## 装备属性：Inventory 保存数据，GAS 负责结算

源码：[Item](../addons/simple_inventory/src/core/Item.gd)、[C_Inventory](../addons/simple_inventory/src/core/C_Inventory.gd)、[GameplayAttributeInstance](../addons/gameplay_abiltiy_system/scripts/attributes/gameplay_attribute_instance.gd)、[GameplayAttributeModifier](../addons/gameplay_abiltiy_system/scripts/attributes/gameplay_attribute_modifier.gd)。

Item.attributes 是物品的 `Dictionary[String, float]`；它没有最终值计算、等级曲线、上下限、修改器移除或 Vital。背包只发 equip_changed，当前没有自动把装备数值送到 GAS。因此 Simple Inventory 并没有另一套完整的角色属性系统。

GAS 支持 ADD、MULTIPLY、OVERRIDE，按 `(base + ΣADD) × (1 + ΣMULTIPLY)` 计算，更新缓存并发变化信号；修改器可按 source_id 批量移除。这个能力明显更适合战斗数值，但直接改 modifier.value 不会自动令缓存失效，单个移除与来源索引的一致性也需注意。

**取舍：装备槽变化时由适配器移除旧槽来源修改器，再按 Item.attributes 添加新的 GAS 修改器。** 来源 ID 使用槽/实例标识，例如 `equip.weapon`；物品字符串键与 GAS 属性 ID 显式映射。不要另算一个 inventory_attack 并与 GAS.attack 长期同步。拆卸装备、同类装备替换和重复事件都应保持可重复执行的一致结果。

## 配置、日志与调试：各保留适合的范围

源码：[ConfigManager](../addons/godot_core_system-0.0.4/source/config_system/config_manager.gd)、[PankuConfig](../addons/panku_console/common/config.gd)、[CoreLogger](../addons/godot_core_system-0.0.4/source/logger/core_logger.gd)、[Panku 日志监视器](../addons/panku_console/modules/native_logger/godot_log_monitor.gd)、[DebugDraw](../addons/zylann.debug_draw/debug_draw.gd)。

配置方面，Core 使用常驻 ConfigFile、分段键值与 modified 标记，显式保存便于批量操作；auto_save 设置当前不实际触发自动落盘。Panku 每次从配置文件读取 Dictionary，设置后整份写回，适合控制台自身选项，格式和默认值协议被其模块依赖。**游戏配置优先 Core，Panku 设置保留插件内部管理。** 将它们强行合并，收益小于迁移和上游更新成本。

日志方面，CoreLogger 是生产者：分级、颜色、上下文、可选文件；Panku 是交互窗口及引擎日志读取展示。**结构化记录选 Core，查看和执行命令选 Panku。** Core 文件日志重新打开使用 WRITE，会截断历史；Panku 监视器依赖引擎文件日志，按前缀分类，需要确认当前引擎输出格式。避免同一条消息经过直接展示和文件监视又出现两次。

调试方面，Panku 看表达式、变量与控制台，GAS 面板看技能树/标签/状态，DebugDraw 看世界坐标的命中盒、线与坐标轴。DebugDraw 的几何池、帧级存活和暂停时显示，与 GAS Cue 的游戏表现用途不同。GAS 近战检测当前已经动态调用 DebugDraw，不需要另造几何调试服务。**三者互补；重复窗口按调试场景关闭即可。**

## 资源、对象池与模块管理：通用化收益尚不足

源码：[ResourceManager](../addons/godot_core_system-0.0.4/source/resource_system/resource_manager.gd)、[EntityManager](../addons/godot_core_system-0.0.4/source/entity_system/entity_manager.gd)、[ProjectileBase](../addons/gameplay_abiltiy_system/scripts/entites/projectile_base.gd)、[MagicFieldBase](../addons/gameplay_abiltiy_system/scripts/entites/magic_field_base.gd)、[CueManager](../addons/gameplay_abiltiy_system/scripts/singletons/gameplay_cue_manager.gd)、[PankuModuleManager](../addons/panku_console/common/module_manager.gd)。

Core 的通用资源缓存、懒加载与节点池在接口上更广；GAS 的投射物、魔法场与 Cue 负责命中、载荷、持续时间和游戏状态清理；DebugDraw 的池专为几何和材质复用。缓存资源不等于管理活跃对象生命周期，也不意味着能安全接管状态清理。

Core 当前 clear_instance_pool 只清引用，未逐个释放脱树 Node；unload_entity 没有卸载实现；destroy_entity 先调实例 destroy，再回池，如果 destroy 会 queue_free，则池中会留下待释放节点。GAS 自身也有魔法场初始化顺序和状态清理、Cue 引用保存的边界，所以不能把“已能生成效果”当作通用回收协议完整。

**取舍：当前保留 GAS 的创建/销毁路径与 DebugDraw 专用池。** Core 如承担通用池，先定义 acquire/configure/release/reset/dispose 协议，并明确谁负责 Timer、信号、目标引用、状态来源和 Cue。仅在压测证明有创建/销毁瓶颈后，把经过验证的投射物迁入池；不把同一节点登记进两个池。

CoreSystem 的服务模块、Panku 的控制台模块、GAS 的 Feature 虽都有注册和逐帧更新，但分别属于项目服务、工具环境和技能实例。**保留各插件自己的生命周期管理。** Core 全部默认 @onready 创建，启用开关与依赖需梳理；其 state_machine/gameplay_tag_manager 设置键与入口 state_machine_manager/tag_manager 不同，关闭重叠模块前要先修正或使用入口实际读取的键，不能只勾上游开关就认为已卸载。

## 面向本项目的调整顺序

1. 先修战斗正确性：状态事件增加明确受伤目标作用域、明确减伤同步阶段；验证同标签多来源添加/移除配对。
2. 再统一角色输入：一个 OperationController 接入角色/技能；保留 GAS 快捷键显示，修正或停用重复的 Core InputManager 事件入口。
3. 装备通过 equip_changed 适配到 GAS 修改器，维持一份角色最终属性。
4. 统一暂停与时间缩放约定；冷却、Buff 与周期效果继续由实例拥有。
5. 游戏配置/日志按需使用 Core，Panku 与 DebugDraw 保持调试职责；不提前迁移节点池。
6. 明确未使用的 Core 服务，再处理模块开关和依赖，减少启动模块及重复更新。以上是建议，不是本次已经完成的运行时改造。

Core 的存档、音频、线程和随机工具在 GAS 中没有对应完整实现，属于新增能力，不应因为没有重复就推断其已完全可用。各插件当前更完整的实现说明见 [Core 分析](../addons/godot_core_system-0.0.4/docs/implementation-analysis.md) 和 [GAS 分析](../addons/gameplay_abiltiy_system/README.md)。
