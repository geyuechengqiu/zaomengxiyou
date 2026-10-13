# 项目目录与怪物生成优化

## 正式入口与资源分类

F5 入口为 [造1大地图](../game/world_map/zaomeng1_world_map.tscn)，顺序解锁花果山、水帘洞；地图按钮保留 [碧玉径](../game/levels/biyujing.tscn) 入口，BattleSystem 默认索引仍指向碧玉径五区域版本。旧平台、木桩、技能、插件演示和旧版首关场景已删除，专门依赖它们的验证/截图脚本同步移除。当前自动验证直接使用最新关卡、可复用模板或功能组件，不再加载演示场景。

| 目录 | 用途 |
| --- | --- |
| `game/levels/` | 正式可玩关卡和装配脚本 |
| `data/characters/sunwukong/` | 角色定义、属性、输入、技能和可编辑动画场景 |
| `assets/characters/sunwukong/` | 角色 Spine 骨架、图集、攻击特效和动作声音 |
| `data/monsters/<怪物>/`、`assets/monsters/<怪物>/` | 怪物实例模板、属性、AI、技能、Spine 和来源素材 |
| `data/levels/biyujing/progression/` | 最新地图、区域、出生点、波次和关卡索引 |
| `data/templates/` | 角色、怪物和战斗单位基础模板 |
| `data/attribute/`、`data/buffs/`、`data/damage/` | 共用属性、Buff 与伤害规则 |
| `data/ui/`、`data/inventory/`、`data/loot/` | 战斗/背包 UI、物品与成长、掉落规则 |
| `addons/` | 插件实现；业务资源由目录索引配置 |
| `tests/suites/`、`tools/` | 当前功能验证、离线导出、编辑辅助及性能工具 |

路径和清理清单见 [resource_organization.json](resource_organization.json)。删除文件的本地恢复副本位于 `.cleanup-backup/resource-organization`，目录被 Git 和 Godot 导入忽略，不参与运行和发布。资源的 ID、UID 和原始素材内容保留，序列化路径、索引、工具和文档链接同步更新。

## 已定位的开销

`BattleProtectionSystem.configure()` 原先在每只怪物初始化时重新读取并解析约 2 MB 的 `original_protection.json`，再深复制整套技能字典。对同一主关卡四类怪物各生成 12 次，初始 CPU 微基准的平均出生时间为剑舞 77.91 ms、驭兽使 73.96 ms、容器 75.73 ms、Boss 95.60 ms；资源定义复制只有约 0.4 ms。后续分段采样确认开销主要发生在实体 `_ready`。

现在保护原表按资源路径只解析一次，关卡加载阶段提前预热，刷怪时共享只读技能/别名数据。保护值、技能命中计数和无敌时间仍由各组件保存；每次结算只复制所使用的技能行，不会修改缓存。重新编辑原表后重启游戏即可载入新配置。

共享受击表现增加预热池：默认提前建立 4 个视图，最多缓存 8 个空闲视图。每个视图包含头顶血条、出场和命中特效；回收清理旧绑定、动画与显示状态，Boss 与普通怪之间复用会恢复原设置。缓存不限制同时存在的活动目标，超出空闲缓存上限的视图会释放。伤害数字继续使用已有的独立对象池。

怪物死亡后仍播放原死亡动作；结束后在当前战斗 tick 的尾部移出实体索引、注销音频/状态机/事件绑定、回收反馈并释放整个节点树。死亡、被动、掉落和出生依赖先完成结算。Boss 斩败的材质恢复完成前保留必要节点，避免特效引用失效。暂停不会消耗死亡动画时间。默认隐藏的调试面板不再每帧生成完整属性快照和格式化文本。

当前预热专项连续生成 20 个剑舞，CPU 出生耗时中位数 2.562 ms，最大 3.144 ms，保护原表共解析 1 次，反馈创建数保持 4。此结果来自本机带 Spine 的 Godot 4.7.2、headless CPU 采样，不能代替其他机器的 GPU/完整帧耗时。实际渲染数据由下面的工具另行记录。

同一 headless 模式、每类12次出生的最终对照（平均毫秒）：

| 怪物 | 优化前 | 优化后 |
| --- | ---: | ---: |
| 剑舞 | 77.91 | 3.12 |
| 驭兽使 | 73.96 | 2.87 |
| 复苏容器 | 75.73 | 3.01 |
| 巨石灵君 | 95.60 | 4.45 |

本机 NVIDIA RTX 5060 Laptop、D3D12 Forward+ 的实际渲染采样：剑舞/容器/驭兽使平均生成耗时 2.87/2.82/2.91 ms，Boss 3.88 ms，首次生成 2.87/2.96/3.07/4.04 ms。采样出生后的渲染帧平均 5.17 ms、P95 9.58 ms、最大 10.37 ms（上限120 FPS，基准关闭AI并手动清理目标，不代表所有战斗密度）。最新关卡画面检查通过，13套当前回归全部通过，包括34个目标的完整首关实战。

## 配置与复测

`BattlePresentation` 检查器可调 `Prewarm Feedback Count`、`Max Cached Feedback`。大规模战斗按峰值目标数量预热反馈；当前生成逻辑不复用整只怪物，避免复用已经销毁的 GAS、生命和动作状态。缓存原表和表现池已经消除了已测得的主要同步开销。

```powershell
./tools/verify_stage_eight.ps1 -Godot '<带 Spine 的 Godot.exe>'
& '<Godot.exe>' --headless --path . res://tools/performance/benchmark_monster_spawn.tscn
& '<Godot.exe>' --path . res://tools/performance/benchmark_monster_spawn.tscn -- --capture
```

专项验证覆盖缓存、状态隔离、反馈复用、暂停、真实死亡释放与 Boss/普通怪视图切换；完整首关验证继续检查全部 34 个目标、Boss 技能和通关。日志、性能数据和截图保存到忽略的 `.cleanup-backup`。
