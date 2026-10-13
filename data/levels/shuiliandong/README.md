# 水帘洞：造梦西游1第二关

F5 从造1大地图进入；花果山通关后解锁。编辑器也可打开 `game/levels/shuiliandong.tscn` 按 F6 直接调试。最终光效内按 W / ↑ 确认通关。使用项目配套 Spine 4.3 / Godot 4.7.2 C#，构建和发布沿用 NativeAOT 工作流。

来源为用户提供的 **zmISAV VTest** 修改版 `GameSence` 标签 `1-2`，不是未修改的官方初版。场景采用原森林、远山、草地、水面与五个单向平台，世界坐标为原素材的2倍。地形碰撞按草地图透明度连通区域提取，剔除图片中独立悬空平台，避免将透明的台下空间挤出成空气墙；悬空平台保留原单向碰撞。水面间隙预置 WaterSupport0/1，承托面位于世界Y=1302.3（比原坑底更高，贴近可见波峰），人物不会沉到贴图下面；水面层z_index=-11，位于草地层-10及角色后方。按当前布局要求，地形、草地、水面、玩家出生、出怪点及出口统一下移200世界单位（100逻辑像素）。取消额外重复石块地板层，仅保留原素材；镜头垂直边界保留0–1400，碰撞世界高度扩到1600。远山保持铺满画面。地图、玩家、角色组件、出生点、出口和 HUD 均预置于场景。

原配置含五区域、18个出生计划、48个敌人，单人同时存活上限6。计时采用原计数24/显示30的0.8换算，名额等待不会积累补发。区域横轴为0–1880、1880–3760、3760–5640、5640–7520、7520–9460。出生点依所属区域重新排布到实际镜头范围内，保留高度及左右顺序；原始坐标在节点 metadata 和 `original_source.json` 中。

| 本关怪物 | 属性来源 | 技能与外观 |
| --- | --- | --- |
| 花果山小猴 | 碧玉径剑舞 | 复用造1小猴原生 Spine 与 hit1，受击后追击 |
| 花果山山猴 | 碧玉径驭兽使 | 复用造1山猴原生 Spine 与 hit1 |
| 水帘洞大猩猩 | 碧玉径巨石灵君 | 普通怪模板，原 hit1，没有 Boss 控制器及保护 |
| 水帘洞弥猴王 | 上古天帝篇第二关九头雉鸡精（Monster/10802） | 用户提供的 mihouwang DragonBones 转 Spine，原始21动作、七种可编辑战斗技能 |

猕猴王属性独立于奖励适配：5级、生命1943、攻击44、防御8、回血2、移速150（2倍世界坐标下300，再应用造1移动缩放）、保护满值25000、风抗20、水抗20、火抗-20。配置证据为 `data/monsters/zaomeng1/mihou_king/stat_source.json`，包含原 Dungeon/2 到 Monster/10802 的关联及原 Monster 行。显示已替换为用户提供的外传 mihouwang 动画，保留21个源动作、60FPS及嵌套骨骼；技能采用素材原始60FPS动作时长，范围可在场景拖动编辑，详情见 `data/monsters/zaomeng1/mihou_king/README.md`。奖励来源独立配置，猕猴王采用同一第二关 Boss 的原掉落表。

小怪普攻统一1倍。弥猴王直接使用提供素材的 attack1–attack4、skill1–skill3 动作，采用各自原始60FPS时长；不再拉伸为造1 hit1/hit2/hit3，也不再使用旧造1弹道或旋转无敌。技能命中起始帧来自XML，攻击框、结束帧、倍率、重复命中、击退和冷却为可编辑的项目默认值，XML不包含完整原游戏战斗规则。

在 Boss visual.tscn 的 AttackRanges/<动作>/CollisionShape2D 拖动实际伤害矩形；skills/<动作>.tres 编辑命中窗口和结算参数，boss.tres 编辑AI施法距离/冷却。编辑框在运行时隐藏，判定与镜像仍由统一战斗系统处理，Boss实例之间相互独立。

关卡播放原造1 `bg1`；Boss 登场切换碧玉径 `boss_01`。普通大猩猩不触发 Boss 音乐。击杀奖励、装备/补给、灵魂飞行、背包和死亡清理由现有战斗插件处理。本关使用独立 `loot.json`：普通大猩猩与当前小怪相同，6经验、8灵魂，使用原小怪补给/装备/材料概率；猕猴王由 Dungeon/2 中 Monster/10802 对应 Drop/1002，76经验、65灵魂，当前悟空职业必定掉落物品110101002（封戾冠）。完整原行及映射保存在 `drop_source.json`。共享碧玉径、花果山掉落表保持独立。

必须完成参与通关的出生计划、全部目标及最终 Boss，才激活传送门；Boss 提前死亡、后续波次等待或中途返回均不能直接胜利。最终出口位于末区坡地 `FinalExit`；编辑器中可以预览其 `Gateway` 光效与判定框，移动父节点或 Gateway 子节点都会移动真实判定。`EditorPreview` 显示各区域范围和18个出生点。

配置入口：

- `map.tscn`：地形碰撞、玩家出生、`SpawnPoints`、`FinalExit` 与编辑预览。
- `visual.tscn`、`assets/maps/shuiliandong/`：原地图艺术、视差与统一下移布局。
- `definition.tres`、`regions/`、`waves/`、`plans/`：区域、计划依赖与通关规则。
- `manifest.json`、`audio.json`、`loot.json`：定义索引、音乐音效和本关掉落映射。
- `drop_source.json`：第二关 Boss 的原 Dungeon/Drop 配置证据。
- `original_source.json`、`original_attacks.json`：源配置及原攻击帧/判定导出。
- `data/monsters/zaomeng1/mihou_king/`：Boss 模板、属性、原始动作技能、可编辑范围与行为。
- `assets/monsters/zaomeng1/mihou_king/`：骨架、图集、原帧及弹道纹理。
- `game/levels/ZaomengOneLevelScene.cs`：两关共享的音乐、结果面板和选关存档桥接。

离线作者工具 `tools/import_shuiliandong.py` 复用花果山导出器，需要 Pillow、原 SWF 和预先导出的 `.cleanup-backup/shuiliandong-*` / `huaguoshan-monster-*` 缓存。`tools/ExportZaomengOneBoss.java` 提取 Monster4 逐帧攻击框。该工具会重写水帘洞生成资源，手动编辑后不要无条件重跑。`tools/export_shuiliandong_loot.py` 单独重建本关掉落配置；只导出当前样板角色悟空所需的物品定义，保留源掉落表的全部职业字段。普通游玩无需原 SWF、Python 或 Java。

验证命令：`tools/verify_stage_eight.ps1 -Godot '<配套引擎>' -Suites shuiliandong,shuiliandong_combat`。覆盖48次死亡、出生预算、延迟锁定、镜头内出生、独立 Boss、真实技能伤害、编辑范围生效、镜像/暂停/清理、连续跑跳地形往返及最终出口同步。相同两套场景可用 NativeAOT 验证包运行。
