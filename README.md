# 造梦西游 · Godot / C# NativeAOT

使用带 **Spine 4.3** 的 **Godot 4.7.2 C#**、.NET 8 和 Windows x64 NativeAOT。编辑器使用 Debug 程序集，正式发布使用原生预编译。新增项目逻辑使用 C#；第三方插件保留原实现，已有 GDScript 通过明确的适配接口接入，完整 C# 迁移仍在进行。

## 启动与构建

```powershell
# 在项目根目录执行，准备与引擎匹配的绑定并编译 Debug
./tools/csharp/bootstrap.ps1

# 打开配套编辑器；也可直接使用根目录 open_editor.cmd
./tools/csharp/open_editor.ps1

# 正式 Windows NativeAOT 游戏及启动验证
./tools/csharp/export_native.ps1
./tools/csharp/verify_native_game.ps1
```

需要 .NET **SDK**，仅安装运行时无法构建。NativeAOT 还需要 Visual Studio C++ Build Tools、Windows SDK 及匹配引擎的 Spine/.NET 导出模板。本机引擎位于 `D:/UserData/Downloads/godot/version/4.7.2 C#/godot-4.3-4.7.2-stable-mono.exe`。其他机器可通过构建脚本的 `-Godot`、`-Dotnet` 参数指定工具链。[工具链、MSBuild 与迁移说明](docs/csharp-nativeaot.md)。

正式包输出至 `.cleanup-backup/export-nativeaot/`，分发时保留整个目录，包括 EXE、PCK 与原生库。缓存、SDK、构建输出、测试存档和截图不提交 Git。导出后运行 `bootstrap.ps1` 恢复编辑器 Debug 程序集，避免把原生导出 DLL 用于编辑器调试。

## 当前游戏

F5 从 [东胜神洲（七魔王）大地图](game/world_map/zaomeng1_world_map.tscn) 启动。大地图保留造1原地图与音乐，使用上古天帝篇的头像、下方功能栏和世界按钮。点击已制作且已解锁的关卡直接加载；只有最新解锁关卡发光，悬浮名称使用原版素材。世界按钮与未实现功能保留接口。碧玉径作为独立关卡保留，大地图不提供入口。

| 关卡 | 内容 | 编辑入口 |
| --- | --- | --- |
| 花果山 | 五区域、14个出生计划、33个目标，造1猴类怪物及大猩猩 Boss | [huaguoshan.tscn](game/levels/huaguoshan.tscn)、[配置说明](data/levels/huaguoshan/README.md) |
| 水帘洞 | 五区域、18个出生计划、48个目标，普通大猩猩与七技能猕猴王 | [shuiliandong.tscn](game/levels/shuiliandong.tscn)、[配置说明](data/levels/shuiliandong/README.md) |
| 碧玉径 | 五个连续区域、出生依赖、普通怪物及 Boss，独立验证关卡 | [biyujing.tscn](game/levels/biyujing.tscn)、[区域配置](data/levels/biyujing/progression/README.md) |

各关卡也可打开场景按 F6。逻辑视口为 **940×590**，战斗世界采用两倍素材坐标。最终出口确认通关后才解锁下一关，击败 Boss 本身不会直接解锁；完成两关后桃花源发光，但尚未制作，不能进入。[选关与角色存档](data/campaigns/zaomeng1/README.md)。

选关和造1重开均经过 [加载界面](docs/stage_loading.md)，完成资源读取、角色/怪物画面预热、地图初始化、存档恢复和反馈池准备后再恢复输入与时钟。进度、百分比和云彩同步缓动，标题仅显示“造梦西游Online”，右下角发行水印已移除。重复进关复用已加载资源与画面预热结果。

加载条默认0.8秒缓动，显示到100%并绘制完成后才进入战斗。花果山与水帘洞使用无损地图纹理、缩放采样和轻微树冠锐化，树木风摆跟随战斗时钟；水帘洞末区域镜头限制在原图覆盖内。地面物品按实际拾取贴图矩形与玩家身体相交判定，`BattleSession/Loot` 的 `pickup_radius` 设置额外拾取余量。

## 操作与主要功能

默认 A/D 或方向键移动，双击方向奔跑，K 跳跃，J 普攻，Y/U/I/O/L 为主动技能槽，空格无双，Q/E 为道具槽，B 背包，Esc 设置。在单向平台上按下＋跳跃可向下穿过。按键设置支持拖动装配、已占用槽交换、双击卸下及改键。

- 悟空未转职时使用四个已接入主动技能；火魔斩未学习，默认第五槽为空。技能升级、灵魂消耗、按键装配及重击被动生效；转职、秘技保留入口。[技能配置](data/characters/sunwukong/skills/README.md)。
- 背包支持原版字体与品质边框、装备比较、穿脱、锁定、自动按品质/类型排序、数量出售与多品质一键出售。锁定及穿戴装备不参与出售；编号首次生成，称号保留接口。[背包配置](data/inventory/panel-details.md)。
- 原版长期属性计算战力，一级裸装悟空为 **987**；战力悬浮框显示构成。临时 Buff、受伤和耗蓝不改变面板战力。[战力公式](addons/battle_foundation/attributes/fight-power.md)。
- 猕猴王使用用户提供的 DragonBones 转 Spine 动画、十组特效、四种普攻和狂风出击/疾风突袭/飓风强袭。技能判定范围可在场景中编辑；三技能为霸体，AI提前播报，旋风具有吸附效果。[Boss 目录](data/monsters/zaomeng1/mihou_king/)。
- 音量、音乐/音效静音、输入和菜单暂停通过统一接口管理；自动化测试传入 `--audio-driver Dummy`，不修改玩家音频偏好，F5/F6 和正式游戏正常使用存档设置。

## 数据在哪里编辑

| 配置 | 位置 |
| --- | --- |
| 玩家初始生命、攻击、防御与移动属性 | [base.tres](data/characters/sunwukong/attributes/base.tres)；场景的 `GameplayVitalAttributeComponent → Base Values` 可覆盖 |
| 玩家等级成长 | [progression.tres](data/characters/sunwukong/attributes/progression.tres) |
| 攻速与基础奔跑参考速度 | `attackSpeed`、`baseRunSpeed`；普攻动画/命中时序随攻速变化，走跑动画按当前速度与参考速度之比播放 |
| 跳跃、重力、普攻动作 | [actions.tres](data/characters/sunwukong/actions.tres)、[动画编辑说明](data/characters/sunwukong/animation/README.md) |
| 悟空技能时间轴、MP/CD/倍率与学习要求 | [skills/](data/characters/sunwukong/skills/)、[panel_rules.json](data/characters/sunwukong/skills/panel_rules.json) |
| 怪物属性、AI、技能及掉落 | [data/monsters/](data/monsters/README.md)、[data/loot/](data/loot/README.md) |
| 猕猴王专属属性数值 | [mihouwang_attributes.tres](data/monsters/zaomeng1/mihou_king/mihouwang_attributes.tres)，与参考Boss资源独立 |
| 猕猴王各技能攻击矩形 | [attack_ranges.tscn](data/monsters/zaomeng1/mihou_king/attack_ranges.tscn)；出生实例、镜像与缩放同步使用这些矩形 |
| 区域、出怪与通关点预览 | `data/levels/<关卡>/map.tscn`；移动 `FinalExit/Gateway` 同时移动通关光效与判定 |
| 选关顺序、名称、加载清单 | [world_map.json](data/campaigns/zaomeng1/world_map.json) |
| 背包、技能和战斗 UI | [data/ui/](data/ui/README.md)；加载界面位于 [stage_loading_screen.tscn](game/loading/stage_loading_screen.tscn) |

定义资源保存只读配置，生命、冷却、装备强化和随机属性属于独立运行实例。已有玩家存档会恢复等级、装备及技能，测试属性时请使用隔离测试存档，避免误把读档结果当成初始配置。跳跃实际读取动作配置的 `jump_velocity`、`second_jump_velocity`、`gravity`，属性表 `jumpSpeed1/2` 不是当前运动入口。[详细调参](data/characters/sunwukong/animation/sunwukong-config.md)。

## 目录与维护边界

| 目录 | 职责 |
| --- | --- |
| `game/levels/` | 三个实际关卡与入口装配 |
| `game/world_map/`、`game/campaign/`、`game/loading/` | 地图、通关/存档、加载流程的 C# 业务 |
| `data/` | 可编辑角色、怪物、地图、技能、属性、物品、掉落与 UI；`templates/` 是可复用组件模板 |
| `assets/` | 图片、Spine、字体、音频与来源记录 |
| `addons/battle_foundation/` | 项目战斗整合与 C# 适配，保持第三方接口契约 |
| 其他 `addons/` | Core、GAS、Inventory、Phantom Camera、Panku、DebugDraw 等基础插件及其必需 UI |
| `tests/suites/` | 31个当前功能验证入口，不作为游戏关卡发布 |
| `tools/performance/` | 性能微基准与实际渲染截图工具 |
| `tools/editor/` | 独立编辑器设置辅助项目，通过 `.gdignore` 隔离游戏导入 |
| `tools/csharp/`、其余 `tools/` | 构建/导出、只读审计与离线素材导入/场景制作脚本 |
| `docs/` | 配置、架构、来源与维护记录 |

旧平台、木桩、技能和插件示例已清理；当前没有示例关卡。角色、怪物、UI、模板和第三方插件界面是实际运行或编辑依赖，不能按“非关卡场景”直接删除。[完整场景分类与整理说明](docs/project-organization-performance.md)。

## 性能与验证

实体列表仅在出生/移除时重建，正常战斗 tick 复用 C# 快照；公开查询仍返回独立数组。保护原表只解析一次，反馈和伤害数字采用对象池；死亡动作结束后释放实体。重复选关不重复加载资源或构造纯动画预热实例，大地图只在悬浮目标变化时更新材质/贴图，技能面板缓存贴图并避免重复绑定。

```powershell
# 资源路径、大小写、UID、示例与孤立 UID 审计（Python 3，无额外依赖）
py tools/audit_project.py --report .cleanup-backup/project-audit.json

# 全部31套静音回归；每套独立进程、隔离用户目录，默认超时240秒
./tools/verify_stage_eight.ps1 -Godot '<配套 Godot.exe>'

# 指定功能
./tools/verify_stage_eight.ps1 -Godot '<配套 Godot.exe>' -Suites spawn_performance,campaign_transitions

# 原生验证包
./tools/csharp/export_native.ps1 -Validation
./tools/csharp/verify_native_game.ps1 -Suites spawn_performance,campaign_transitions,original_skill_panel

# 实际出生微基准，静音且隔离存档后运行
& '<Godot.exe>' --headless --audio-driver Dummy --path . res://tools/performance/benchmark_monster_spawn.tscn
```

静态审计不替代运行测试。回归会检查脚本/运行错误，覆盖三关推进与实战、坡地击退/平台穿透、Boss、属性/战力、背包、技能、UI遮罩、存档及加载失败/取消。性能数据需在相同引擎、渲染模式和设备上比较；缓存次数减少不等于已测得帧率提升。[验证清单](tests/README.md)、[性能与整理记录](docs/project-organization-performance.md)。
