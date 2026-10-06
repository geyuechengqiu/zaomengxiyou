# 插件效果演示

使用 Godot 4.7 或更新版本打开 `project.godot`，按 F6 运行所选示例，或按 F5 运行主场景 `examples/plugin_showcase.tscn`。

当前包含以下五套插件：

- `gameplay_abiltiy_system`：技能、行为树、属性、生命/法力、状态、标签、投射物、区域效果和 Cue。演示包含伤害、治疗、冷却、无敌过滤和状态叠加。
- `simple_inventory`：背包、装备槽、筛选、整理和道具提示。
- `panku_console`：交互控制台；演示环境支持 `demo.damage()`、`demo.heal()`、`demo.add_status()` 和 `demo.reset_demo()`。
- `zylann.debug_draw`：3D 线框、坐标轴及调试文字。
- `godot_core_system-0.0.4`：新增基础框架，包含 14 个模块：日志、资源、音频、事件、输入、操作意图、配置、场景、时间、存档、状态机、实体、触发器和标签。

业务层的角色配置、属性加点、天赋、装备接入、业务伤害公式及 HUD 已从 `scripts/`、`data/`、`ui/` 移除。插件示例使用 `addons/gameplay_abiltiy_system/examples/example_data.gd` 中的独立数据，插件 UI 素材也放在插件内部。

效果修改接口改为插件内的 `GameplayEffectModifier`，保留技能筛选和上下文参数组合功能；不再依赖业务层的 `TalentEffectModifier`。技能系统的近战调试绘制会动态查找 `DebugDraw`，未启用它时跳过绘制。

技能系统、核心系统、背包及控制台已启用。项目配置包含运行所需的自动加载单例；`DebugDraw` 是单文件工具，通过自动加载启用。

验证主要功能：

```powershell
& '<Godot 可执行文件路径>' --headless --path . res://examples/verify_plugins.tscn
```

原有四个技能系统示例也可单独运行。清理前的插件、业务文件和项目配置保存在 `.cleanup-backup/before-plugin-cleanup-*.zip`，该目录通过 `.gdignore` 排除在 Godot 导入之外。

## 新增 CoreSystem 插件分析

详细实现见 [CoreSystem 完整分析](addons/godot_core_system-0.0.4/docs/implementation-analysis.md)，涵盖全部模块、策略、工具与示例，以及初始化顺序、模块开关、事件负载、输入意图、状态切换、存档格式、对象池和资源清理。[全部脚本索引](addons/godot_core_system-0.0.4/docs/source-index.md) 列出每个脚本的接口与信号。

![CoreSystem 模块结构](addons/godot_core_system-0.0.4/docs/core-architecture.svg)

还有 [输入与状态机类图](addons/godot_core_system-0.0.4/docs/core-input-state.svg)、[存档与 IO 类图](addons/godot_core_system-0.0.4/docs/core-persistence.svg) 和 [与技能系统的联合接入图](addons/godot_core_system-0.0.4/docs/core-gas-integration.svg)。CoreSystem 与 GAS 分别维护事件和标签；当前没有自动桥接，TimeManager 的缩放也只影响自身计时器。分析文档明确区分现有实现与可接入设计，并说明输入处理、存档默认格式、模块开关等已有接口限制。

## 插件重复系统与取舍

重复功能的取舍见 [插件重复系统对比](docs/plugin-overlap-analysis.md)：逐项比较标签、事件、输入、时间、状态/行为树、触发器、装备属性、配置、日志、资源池和模块管理的实际优缺点，并给出保留与联合接入顺序。战斗数据以 GAS 为主，角色输入优先考虑 Core OperationController；状态机、控制台及调试绘制按用途协作。

## 脚本折叠分区

项目内所有 GDScript（包括五套插件及示例）使用 `#region` / `#endregion`，按类型、配置、信号、生命周期、公共接口与内部实现等实际结构折叠；原有分区保留。文档工具及 Shader 使用相应注释分区。分区只添加注释，不调整代码执行顺序；备份位于 `.cleanup-backup/script-regions-*.json`。

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
