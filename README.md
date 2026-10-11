# 造梦西游 · Godot 项目

此分支正在迁移为 **C# + NativeAOT**：项目逻辑和自维护插件使用 C#，第三方插件保留；编辑器使用 Debug，正式导出使用原生预编译。构建命令、迁移进度和导出模板要求见 [C# / NativeAOT](docs/csharp-nativeaot.md)。

已接入匹配的 Spine/.NET Windows 模板并运行 NativeAOT 关卡包。执行 `./tools/csharp/export_native.ps1` 生成正式包。当前31个脚本已迁移，完整C#迁移仍在进行；原生编译与原生运行验证均已完成。

正式入口为 [碧玉径](game/levels/biyujing.tscn)，按 F5 运行。需要带 **Spine 4.3 模块**的 Godot；本机引擎为 Godot 4.7.2。逻辑视口为原版 940×590，战斗世界使用 2 倍素材坐标。

当前关卡包含孙悟空、五个连续区域、32 个普通怪物、复苏容器和玉石琵琶精 Boss。地图、角色组件、出生点、出口、镜头和战斗 UI 均预置，怪物按原版波次与出生依赖生成。技能、属性、Buff、掉落、装备成长和表现通过现有插件协同。

已接入 [原版战斗连击及显示](addons/battle_foundation/combat/hit-combo.md)：按角色有效伤害结算累计，连续1.5秒未命中后结束；共享HUD使用原版数字与“连击”贴图，保留角色及本关最高连击。

## 目录与配置入口

背包战力现使用 [原版战力计算](addons/battle_foundation/attributes/fight-power.md)：十二项长期属性加权、最终取整，参考离线原版不另加职业修正，一级裸装悟空为987，不受临时Buff、受伤或耗蓝影响。

旧平台、木桩、技能、插件演示及专用脚本、旧版首关均已清理，保留正式关卡、功能组件、基础模板和当前功能验证。目录迁移同步了序列化引用、索引、工具与文档。[目录清单与性能说明](docs/project-organization-performance.md)。

| 目录 | 内容 |
| --- | --- |
| `game/levels/` | 正式可玩关卡 |
| [data/characters/sunwukong](data/characters/sunwukong/README.md) | 悟空定义、属性、输入、技能、角色和动画场景 |
| `assets/characters/sunwukong/animation/`、`audio/` | 悟空骨架、图片、攻击特效和动作音效 |
| [data/monsters](data/monsters/README.md)、`assets/monsters/` | 各怪物属性、AI、技能、Spine 和原版素材 |
| [data/templates](data/templates/README.md) | 新角色和怪物基础模板 |
| [data/levels/biyujing/progression](data/levels/biyujing/progression/README.md) | 最新地图、区域、出生计划及索引 |
| `data/attribute/`、`data/buffs/`、`data/damage/` | 共用属性、状态和伤害规则 |
| `data/inventory/`、`data/loot/`、`data/ui/` | 物品、成长、掉落与 UI |
| `addons/` | 插件实现与系统文档 |
| [tests](tests/README.md)、`tools/` | 当前验证、离线导出、编辑辅助及性能工具 |
| `docs/reference/zaomeng1/` | 造梦西游1分析、关卡配置和来源导出 |

角色使用 `孙悟空`、技能使用 `sunwukong_*` 语义 ID，原数字仅用于来源追溯。定义 Resource 保存配置，生命、冷却、状态、强化和随机属性保存在独立运行实例中。

## 操作和角色编辑

默认 A/D 或方向键移动，双击方向奔跑，K 跳跃，J 普攻，Y/U/I/O/L 为技能槽，空格无双，B 背包，Esc 设置。设置可改键，独立调整音乐/音效音量与静音；操作意图区分按下、按住和释放，菜单、失焦会处理控制权。

编辑 [character.tscn](data/characters/sunwukong/character.tscn) 的 `GameplayVitalAttributeComponent → Base Values` 修改悟空初始属性，等级使用 `Initial Level Override`。`atk`、`phyDef`、`hpMax`、`mpMax` 是攻击、防御和生命/魔法上限，当前值由 Vital 管理。基础值与成长分别位于 [base.tres](data/characters/sunwukong/attributes/base.tres)、[progression.tres](data/characters/sunwukong/attributes/progression.tres)。

`walkSpeed`、`runSpeed` 控制移速；跳跃实际读取 [actions.tres](data/characters/sunwukong/actions.tres) 的 `jump_velocity`、`second_jump_velocity` 和 `gravity`，负速度绝对值越大跳得越高。属性表的 `jumpSpeed1/2` 保留原配置，不作为当前运动入口。走下平台保留两次空中跳跃。技能位移读取自己的时间轴。[详细调参](data/characters/sunwukong/animation/sunwukong-config.md)。

在 [sunwukong_visual.tscn](data/characters/sunwukong/animation/sunwukong_visual.tscn) 的主 AnimationPlayer 编辑身体、武器、原版特效与唯一攻击框。五连击、跑攻、跳攻及第四段一次反向转身通过 Core 动作状态机执行；技能使用 GAS 时间轴，区分释放实例、攻击段和命中目标。[动画编辑](data/characters/sunwukong/animation/README.md)、[基础技能](data/characters/sunwukong/skills/README.md)。

## 战斗、背包与关卡

- 基础、成长、装备、临时和最终属性通过统一入口计算，面板与实际伤害同步。[属性系统](addons/battle_foundation/attributes/README.md)。
- 原版伤害保留命中、暴击、幸运、等级倍率、附伤、抗性、增减伤、真实伤害和护盾的顺序与结果字段。[公式移植](addons/battle_foundation/combat/original-damage.md)。
- GAS 管理 Buff/被动的叠层、刷新、周期、移除与统一触发，吸血依据实际扣血，反伤限制递归。[Buff/触发](addons/battle_foundation/combat/buffs-triggers.md)。
- 怪物使用原生 Spine 与可扩展 AI；Boss 复用通用能力，配置专属技能、阶段、播报及对象池。[普通 AI](addons/battle_foundation/ai/README.md)、[Boss](addons/battle_foundation/boss/README.md)。
- 五区域共用连续地图，通关同时检查出生计划、目标死亡与额外条件，等待后续波次时仍锁定。[关卡](addons/battle_foundation/level/README.md)、[地图模板](addons/battle_foundation/level/map-template.md)。
- 战斗区域左右镜头均锁定，清屏后恢复已开放区域内的双向跟随，进入新区时平滑过渡并再次锁定；使用 Phantom Camera 和原 30 FPS 的 0.2 插值。[镜头](addons/battle_foundation/camera/README.md)。
- 公共战斗 HUD、居中 Boss 栏、抗性/保护、原版出场、区域前进动画和斩败独立于角色。[UI](data/ui/README.md)、[Boss 表现](addons/battle_foundation/boss/original-presentation.md)。
- 背包支持昵称、原图标与品质边框、悬浮说明、装备对比、穿脱、实例成长、套装和外观通知；掉落统一结算灵魂/经验，补给满值不拾取，实际恢复显示绿/蓝跳字。[背包](addons/simple_inventory/README.md)、[掉落](data/loot/README.md)。
- 原伤害数字使用共享图集和对象池；原版动作、命中、拾取、升级、结果与关卡/Boss 音乐接入 Core，支持音量、静音和持久设置。[音频](addons/battle_foundation/audio/README.md)。

## 插件实现与类图

[Battle Foundation](addons/battle_foundation/README.md) 装配战斗；[GAS](addons/gameplay_abiltiy_system/README.md) 提供技能、属性、Vital、状态和 Effect；[Core](addons/godot_core_system-0.0.4/docs/implementation-analysis.md) 提供总线、状态机、输入、配置、资源和音频；[Inventory](addons/simple_inventory/README.md) 提供物品/装备与背包。Phantom Camera 管理跟随，Panku Console 与 DebugDraw 提供调试入口。

GAS 已统一接入 Core 事件总线。[系统重叠比较](docs/plugin-overlap-analysis.md)、[技能联合类图](addons/battle_foundation/docs/skill-timeline.svg)、[动画/状态类图](addons/battle_foundation/docs/animation-adapter.svg)、[关卡类图](addons/battle_foundation/docs/level-progression.svg)。各插件文档保留独立系统类图和详细实现说明。

## 性能与验证

保护原表约 2 MB，现于关卡加载时预热、只解析一次，刷怪共享只读规则；生命和保护值仍独立。受击视图默认预热 4 个、缓存上限 8 个空闲实例。死亡动作结束后释放怪物节点，先完成掉落和通关结算；Boss 斩败结束恢复材质后释放。隐藏调试面板不再每帧重建属性快照。[测量与配置](docs/project-organization-performance.md)。

```powershell
./tools/verify_stage_eight.ps1 -Godot '<带 Spine 的 Godot.exe>'
& '<Godot.exe>' --headless --path . res://tools/performance/benchmark_monster_spawn.tscn
```

默认执行当前 13 套验证，日志与截图保存在 Git/Godot 忽略的 `.cleanup-backup`。Windows 子窗口配置辅助工具位于 `tools/window_mode_helper/`。
