# 插件效果演示

使用 Godot 4.7 或更新版本打开 `project.godot`，按 F6 运行所选示例，或按 F5 运行主场景 `examples/plugin_showcase.tscn`。

当前包含以下六套插件：

- `gameplay_abiltiy_system`：技能、行为树、属性、生命/法力、状态、标签、投射物、区域效果和 Cue。演示包含伤害、治疗、冷却、无敌过滤和状态叠加。
- `simple_inventory`：背包、装备槽、筛选、整理和道具提示。
- `panku_console`：交互控制台；演示环境支持 `demo.damage()`、`demo.heal()`、`demo.add_status()` 和 `demo.reset_demo()`。
- `zylann.debug_draw`：3D 线框、坐标轴及调试文字。
- `godot_core_system-0.0.4`：新增基础框架，包含 14 个模块：日志、资源、音频、事件、输入、操作意图、配置、场景、时间、存档、状态机、实体、触发器和标签。
- `battle_foundation`：基于 Core + GAS 的阶段一战斗基础，提供配置索引、实体运行 ID、阵营、随机流、固定物理时钟和原素材帧事件。

业务层的角色配置、属性加点、天赋、装备接入、业务伤害公式及 HUD 已从 `scripts/`、`data/`、`ui/` 移除。插件示例使用 `addons/gameplay_abiltiy_system/examples/example_data.gd` 中的独立数据，插件 UI 素材也放在插件内部。

效果修改接口改为插件内的 `GameplayEffectModifier`，保留技能筛选和上下文参数组合功能；不再依赖业务层的 `TalentEffectModifier`。技能系统的近战调试绘制会动态查找 `DebugDraw`，未启用它时跳过绘制。

技能系统、核心系统、战斗基础、背包及控制台已启用。项目配置包含运行所需的自动加载单例；`DebugDraw` 是单文件工具，通过自动加载启用。

验证主要功能：

```powershell
& '<Godot 可执行文件路径>' --headless --path . res://examples/verify_plugins.tscn
```

原有四个技能系统示例也可单独运行。清理前的插件、业务文件和项目配置保存在 `.cleanup-backup/before-plugin-cleanup-*.zip`，该目录通过 `.gdignore` 排除在 Godot 导入之外。

## 阶段 4：移动、跳跃、动作状态与五段普攻

已在现有 Battle Foundation 中增加独立运动控制器、状态权限表和连击运行实例，复用 Core 输入/事件与 GAS 属性/Vital/技能。完成待机、行走、奔跑、起跳、空中、落地、受击、死亡；支持重力、墙体、顶头、单向平台、二段跳和朝向限制。死亡优先于霸体与技能规则，动画完成只通知动作系统。

孙悟空普通攻击使用 `sunwukong_attack1` 至 `sunwukong_attack5`，保留原素材 30 FPS 的段时长、六次命中事件、伤害倍率，以及第四段前移和第二击反向偏移。连按 J 在当前段预约下一段，长按不自动连击；攻击锁行走与转向，可按 K 跳取消。第四段位移经过碰撞，不穿墙。

打开 [平台场景](examples/wukong_platform_demo.tscn) 按 F6，A/D 行走、Shift/同方向双击奔跑、K 二段跳、J 五段普攻。面板显示支撑、跳跃预算及连击预约；Esc 菜单会清预约。完整条件表、原版来源、扩展 API 和迁移边界见 [阶段四 README](addons/battle_foundation/movement/README.md)。

![运动与动作状态联合类图](addons/battle_foundation/docs/motion-state.svg)

![五段连击联合运行图](addons/battle_foundation/docs/combo-runtime.svg)

验收 [verify_stage_four.tscn](examples/verify_stage_four.tscn) 已通过 132 项真实碰撞、平台、跳跃、连击、打断、时钟和输入检查；133 项输入检查及 903 项动画检查与阶段一、属性、Core 事件回归均通过。原版完整击退、暴击/保护公式、持续 sensor 和特效仍待后续接入。

## 可扩展角色操作控制器

已复用 Core operation_manager 建立完整输入通道，并接入孙悟空平台场景。移动、跳跃、普攻、五个技能槽、法宝、无双、翅膀技能、奥义、道具、宠物与坐骑均使用语义意图；角色通过公共分支及专属钩子消费，按键改变不需要修改角色代码。

支持按下/持续持有/松开/强度变化、一次长按阈值、同帧短按缓存、连按逐次消费、原版 0.5 秒内同方向双击、按键重映射与配置持久化。输入使用未缩放时间，实际战斗使用 BattleClock；UI 优先消费，菜单/失焦/暂停/改键/控制者切换分别占用控制权，取消释放不会发动技能。

在 [平台场景](examples/wukong_platform_demo.tscn) 按 F6 运行，Esc 打开操作设置；默认 K 二段跳、J 五段普攻、H 法宝、空格无双。其余操作已提供完整意图和技能槽/角色扩展入口，未配置时报告 UNAVAILABLE。详见 [操作控制器 README](addons/battle_foundation/input/README.md) 与 [业务输入定义](data/controls/README.md)。

![操作与战斗联合类图](addons/battle_foundation/docs/player-operations.svg)

[控制权与输入时间图](addons/battle_foundation/docs/operation-control.svg) 解释缓存、暂停及失焦恢复。自动验收运行 `res://examples/verify_player_operations.tscn`，覆盖 133 项真实输入/UI/GAS/平台及重映射检查；原有动画、战斗基础、属性和 Core 事件回归均保留。

## 孙悟空：独立动画适配与横版平台

已接入现有 `assets/skelton/char/sunwukong` Spine 资源，提供动作名称播放、朝向、组合皮肤/装备、播放进度和骨骼挂点。待机、移动、跳跃、受击、死亡、普攻及奔跑/下降保留原版 30 fps 时长。战斗状态独立管理攻击许可、受击锁定和死亡，动画完成通过 Core 发送通知。

打开 [wukong_platform_demo.tscn](examples/wukong_platform_demo.tscn)，使用现有带 Spine 模块的 Godot 引擎按 F6 运行：A/D 移动，K 跳跃，J 攻击，Esc 设置按键，F1 受击，F2 死亡，F4 重生，1/2 换套装/武器，F9/F10/F11 暂停/慢动作/停顿。场景包含左右靶子、平台和墙体；绿色十字为脚底，金色点为可见武器挂点，攻击时显示镜像判定框。

完整设计、SVG 类图、原点/镜像图、API、操作和验收见 [动画适配层 README](addons/battle_foundation/animation/README.md)；角色 `孙悟空` / 技能 `sunwukong_attack1` 的业务资源与原版来源见 [data/battle2d](data/battle2d/README.md)。

![动画与战斗状态联合类图](addons/battle_foundation/docs/animation-adapter.svg)

```powershell
& '<带 Spine 模块的 Godot 路径>' --headless --path . res://examples/verify_wukong_animation.tscn
```

验收覆盖原生动作、全部 206 个皮肤的时长/进度/位置保持、左右第 4 帧攻击、状态与动画分离、统一时钟和真实平台碰撞。二段跳与五段连击已由阶段四接入；平台运动参数用于测试，原版完整运动单位、技能特效和装备数值加成后续接入。

## 阶段 1：项目基础、配置与战斗时钟

新增 [Battle Foundation 插件与接入文档](addons/battle_foundation/README.md)，复用 Core 的配置/资源/事件模块和 GAS 的属性/Vital/技能/状态实例。业务 [data/battle](data/battle/README.md) 分别保存角色、技能、怪物、装备、关卡及状态定义；当前生命、冷却、Buff、装备耐久和关卡实体集合均保存在独立运行实例。新增插件已启用并注册 BattleSystem，属性仍使用原版 ID。

![阶段一插件结构](addons/battle_foundation/docs/architecture.svg)

运行 [stage_one_demo.tscn](examples/stage_one_demo.tscn)（F6）可查看两个同配置角色的独立生命/冷却/状态，操作暂停、恢复、0.5× 慢动作与受击停顿。移动和碰撞使用 60 Hz 固定物理更新；GAS 统一接收战斗 delta。素材帧使用可配置真实帧率，示例 30 fps 的第 12 帧在技能时间 0.4 秒触发，跨过多个事件时依次补发。

```powershell
& '<Godot 可执行文件路径>' --headless --path . res://examples/verify_stage_one.tscn
```

[验收脚本](examples/verify_stage_one.gd) 覆盖双实体隔离、索引校验、Core 战斗事件、实体 ID/阵营、随机流/快照、素材帧、BTWait 战斗时间、实际固定物理调度与碰撞、暂停连续恢复、慢动作和受击停顿，失败返回非零退出码。样例配置用于接口验收，未冒充原版实体数值。

## 业务共享基础属性

新增 [data/attribute](data/attribute/README.md)，依据 Speculum-4399-master 中的上古天帝篇本地配置和客户端源码创建 28 个 GAS 属性定义、5 个通用属性集及生命/魔法 Vital 模板。覆盖攻击、防御、生命/魔法上限、回血/回魔、命闪暴韧幸守、八系抗性、移动/跳跃及耐久/保护阈值。暴击和幸运保留评分语义，抗性和跳跃保留合法负数；共享模板使用中性初始值，各实体的具体数值与成长由业务另行配置。

全部 28 个属性 ID 和资源文件名采用原版字段名，例如 `atk`、`phyDef`、`hpMax`、`mpMax`、`critical`、`lucky`；属性集、Vital 依赖和 GAS 默认读数接口已同步。使用 `res://data/attribute/sets/entity_base_attributes.tres` 初始化完整属性，或按需组合分类集。接入方式、原字段映射和公式边界见目录 README；运行 `res://examples/verify_base_attributes.tscn` 验证资源、Vital 联动、修改器和实体隔离。插件自身的示例仍使用插件内部数据。

## 新增 CoreSystem 插件分析

详细实现见 [CoreSystem 完整分析](addons/godot_core_system-0.0.4/docs/implementation-analysis.md)，涵盖全部模块、策略、工具与示例，以及初始化顺序、模块开关、事件负载、输入意图、状态切换、存档格式、对象池和资源清理。[全部脚本索引](addons/godot_core_system-0.0.4/docs/source-index.md) 列出每个脚本的接口与信号。

![CoreSystem 模块结构](addons/godot_core_system-0.0.4/docs/core-architecture.svg)

还有 [输入与状态机类图](addons/godot_core_system-0.0.4/docs/core-input-state.svg)、[存档与 IO 类图](addons/godot_core_system-0.0.4/docs/core-persistence.svg) 和 [与技能系统的联合接入图](addons/godot_core_system-0.0.4/docs/core-gas-integration.svg)。GAS 全部总线事件已直接使用 `CoreSystem.event_bus`，旧事件单例已移除；两套标签仍独立，TimeManager 的缩放也只影响自身计时器。输入、存档等接入方案及现有接口限制见分析文档。

## GAS 事件迁移到 CoreSystem

启用 CoreSystem 插件及其 `event_bus` 模块；项目将 CoreSystem 排在 GAS 自动加载服务之前。技能学习/遗忘/激活/完成/取消、状态添加/移除、受伤前/后和技能栏点击共 10 类事件，统一通过 `CoreSystem.event_bus.push_event(name, [context], true)` 同步发布。Core 按名订阅的回调收到一个 Dictionary，事件名和原有字段保持一致。

状态组件在入树时连接 Core 的 `event_pushed(name, payload)`，离树时退订，再次入树恢复；只处理含单个 Dictionary 的负载，因此保留任意自定义事件名。状态处理发生在 Core 按名订阅的优先级回调之前；两者都在 `push_event()` 返回前完成，减伤继续修改同一个 DamageInfo，再由 HealthVital 扣血。本次保留原有全局广播语义，宿主仍应明确目标过滤；组件、属性和黑板的本地信号继续按原接口工作。

```powershell
# 验证 GAS 全部资源及事件迁移：失败返回非零退出码
& '<Godot 可执行文件路径>' --headless --path . res://examples/verify_core_events.tscn
```

[事件回归场景](examples/verify_core_events.tscn) 检查全部 10 类事件、Core 按名订阅与历史、同步和完全减伤、死亡、自定义事件、多个组件的退订/重入、技能冷却、状态叠加/标签以及背包装备。测试脚本见 [verify_core_events.gd](examples/verify_core_events.gd)。

## 插件重复系统与取舍

重复功能的取舍见 [插件重复系统对比](docs/plugin-overlap-analysis.md)：逐项比较标签、事件、输入、时间、状态/行为树、触发器、装备属性、配置、日志、资源池和模块管理的实际优缺点，并给出保留与联合接入顺序。战斗数据以 GAS 为主，角色输入优先考虑 Core OperationController；状态机、控制台及调试绘制按用途协作。

## 脚本折叠分区

项目内所有 GDScript（包括六套插件及示例）使用 `#region` / `#endregion`，按类型、配置、信号、生命周期、公共接口与内部实现等实际结构折叠；原有分区保留。文档工具及 Shader 使用相应注释分区。分区只添加注释，不调整代码执行顺序；备份位于 `.cleanup-backup/script-regions-*.json`。

```powershell
# 检查所有脚本的分区完整性
node tools/add_script_regions.mjs --check
# 补充以后新引入脚本的分区
node tools/add_script_regions.mjs
# 重建 CoreSystem 文档图与源码索引
node tools/generate_core_docs.mjs
```

## 技能系统全部模块与联合运行

技能系统采用“配置 → 实例 → 行为树 → 效果”的执行结构。`GameplayAbilityComponent` 创建并逐帧更新 `GameplayAbilityInstance`；行为树动作选目标、提交冷却/消耗、克隆并应用 `GameplayEffect`。`GameplayStatusInstance` 负责持续时间、叠加和周期/事件触发，`GameplayCue` 负责表现。

![技能核心类图](addons/gameplay_abiltiy_system/docs/ability-core.svg)

效果按“过滤器 → 阻止/必需标签 → 子类逻辑 → Cue → 递归子效果”的顺序执行。过滤失败立即结束；状态的周期效果也会重新进入这条流程。效果执行使用深复制的模板，但同次调用中的上下文字典仍被共享。

![效果与状态类图](addons/gameplay_abiltiy_system/docs/effect-status.svg)

![效果运行流程](addons/gameplay_abiltiy_system/docs/effect-runtime.svg)

完整分析见 [技能系统插件 README](addons/gameplay_abiltiy_system/README.md)；它覆盖插件全部模块及当前实现限制，而不只覆盖技能组件。[全部源码与资源索引](addons/gameplay_abiltiy_system/docs/source-index.md) 列出每个脚本的基类、导出字段、公开方法及信号，也包括 UI、示例、场景、Shader 和素材。

| 系统 | 独立类图 |
| --- | --- |
| 技能定义与全部模板 | [定义类图](addons/gameplay_abiltiy_system/docs/ability-definitions.svg) |
| 技能 Feature、冷却与消耗 | [Feature 类图](addons/gameplay_abiltiy_system/docs/ability-features.svg) |
| 行为树与全部基础节点 | [行为树类图](addons/gameplay_abiltiy_system/docs/behavior-tree.svg) |
| 全部技能动作节点 | [动作类图](addons/gameplay_abiltiy_system/docs/ability-actions.svg) |
| 属性、等级成长与修改器 | [属性类图](addons/gameplay_abiltiy_system/docs/attribute-system.svg) |
| Vital、生命/法力与伤害策略 | [Vital 类图](addons/gameplay_abiltiy_system/docs/vital-system.svg) |
| 状态、周期/事件 Feature 与策略 | [状态类图](addons/gameplay_abiltiy_system/docs/status-system.svg) |
| 全部 Effect 与上下文修改器 | [Effect 类图](addons/gameplay_abiltiy_system/docs/effect-system.svg) |
| 目标、预览、命中检测 | [目标类图](addons/gameplay_abiltiy_system/docs/targeting-system.svg) |
| 投射物与策略 | [投射物类图](addons/gameplay_abiltiy_system/docs/projectile-system.svg) |
| 魔法场与区域载荷 | [魔法场类图](addons/gameplay_abiltiy_system/docs/magic-field-system.svg) |
| 标签、过滤器、事件与自动加载 | [服务类图](addons/gameplay_abiltiy_system/docs/services-system.svg) |
| Cue 与视觉组件 | [Cue 类图](addons/gameplay_abiltiy_system/docs/cue-system.svg) |
| UI 与调试面板 | [UI 类图](addons/gameplay_abiltiy_system/docs/ui-system.svg) |

Vital 组件继承属性组件，属性信号影响 Vital 上限；状态的进入、周期和事件效果统一进入 Effect。投射物/魔法场命中后施加状态，伤害 Effect 通过策略读取属性，再交给 HealthVital 同步触发减伤事件并扣值；状态移除会按来源清理修改器、标签及自己的 Cue。

![各系统联合结构](addons/gameplay_abiltiy_system/docs/systems-integration.svg)

![各系统联合运行](addons/gameplay_abiltiy_system/docs/systems-runtime.svg)

联合流程图用可配置的“防御增益 → 攻击 → 事件减伤 → 到期清理”数值例子解释交互。当前“燃烧演示”只演示叠加、标签和计时；配置周期效果后才会产生持续伤害。README 同时指出事件目标隔离、消耗返回值、魔法场初始化/清理等未完整实现的路径。

在项目根目录重建全部 19 张 SVG 和源码索引：

```powershell
node addons/gameplay_abiltiy_system/docs/generate_diagrams.mjs
```
