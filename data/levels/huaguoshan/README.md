# 花果山：造梦西游1第一关

打开 `game/levels/huaguoshan.tscn`，按 F6 游玩；F5 仍运行碧玉径。使用项目配套的 Godot 4.7.2 C# / Spine 4.3 引擎，先运行 `tools/csharp/bootstrap.ps1` 构建。操作、背包、设置和技能与碧玉径相同，最终出口处按 W / ↑ 通关。

地图使用用户提供的造梦西游1 **zmISAV VTest** 文件中的 `1-1`：山景、森林、草地、坡地和三个空中平台。不是未经修改的官方初版素材。原像素位置乘2进入现有940×590视口、0.5镜头缩放的世界；所有区域在一张连续地图中。草地轮廓转换为预置的平滑碰撞多边形，最右侧支撑延伸至物理边界。地图节点、UI、角色组件和出生点全部保存于场景中。

保留原五区域、14个出生计划和33个敌人。原计数器使用 `count/24`、主显示30FPS，因此资源中的 `delay_seconds/interval_seconds` 为原配置乘0.8；首只等待 delay+interval。原单人活怪上限6通过预置 C# `BattleSpawnBudget` 管理，名额不足时保留计划并顺延下一次出生，不积累瞬间补发。区域清理继续同时检查计划生成完毕、关联目标死亡及关卡条件。

五区域在世界横轴上连续排列：0–1880、1880–3760、3760–5640、5640–7520、7520–9660。前四区宽度与战斗视口一致，末区先锁定左侧视口，清屏后可走到最终出口。出生点按所属区域重新排布，保留同区出生点的左右顺序，必要时压缩间距，距视口两边至少180世界像素；高度保留原配置。原始位置保存在出生点 metadata/original_position 和 `original_source.json`。清屏后沿用双向跟随、前进动画与平滑切区。实际边界、触发区、出口和切区提前距离可直接编辑 `regions/*.tres`。

| 造梦西游1外观 | 本项目定义 ID | 属性来源 | 普攻倍率 | 造1击退速度 |
| --- | --- | --- | --- | --- |
| Monster1，小猴 | 花果山小猴 | 碧玉径剑舞 | 1.0 | [2,-5] |
| Monster2，山猴 | 花果山山猴 | 碧玉径驭兽使 | 1.0 | [6,-5] |
| Monster3，大猩猩 Boss | 花果山大猩猩 | 碧玉径巨石灵君 | 1.0 | [6,-5] |

属性直接引用碧玉径对应的属性资源、初始等级、保护规则与掉落来源 ID，运行实例仍独立复制，不污染碧玉径或同类怪物。三个怪物仅使用造1原 `hit1`，分别持续24/12/17帧；半开命中窗口为[13,24)、[2,9)、[4,17)，主显示30FPS。逐帧判定矩形由 Monster_v1.swf 中 body.stick 的完整变换导出，脚底注册点及朝向与 Spine 一致。同一次攻击对同一目标最多结算一次。按用户约定，保留碧玉径攻击属性，三种普攻统一1倍；原固定攻击值5/12/20仅保存在 metadata/zaomeng1_base_power 供溯源。

花果山三种怪物的预置 MotionController 使用 `movement_speed_scale = 0.85`，移动速度降低15%，不缩放击退和击飞。小猴预置 `ZaomengOneAggro` 监听真实生命损失，记录攻击来源并唤醒追击；自己的攻击动画不会激活仇恨。AI 根据实际攻击框与目标受击框靠近，避免停在有效攻击距离以外。

单向平台上按 S / ↓ 加跳跃键（默认 K）可向下穿透，保留空中跳跃次数；角色完全穿过后恢复平台碰撞。实体地面不受影响。地图底部用原石纹延伸到物理边界；最终传送门位于公共地图约定的 `FinalExit/Gateway`，高度跟随出口坡面，最终区域完成后显示并循环播放。

原击退按每秒30帧、世界比例2换算：横向120/360/360，向上300，重力2700；硬直使用原 Role1/hurt 的15帧、0.5秒。原技能源与导出结果保存于 `original_attacks.json` 和技能 metadata。造1 AI 小猴受击后追击，山猴主动追击，大猩猩仅使用近战hit1；每36帧一次攻击尝试，概率50%，时间与尝试记录属于各控制器。Boss名、头顶显示使用“大猩猩”，不展示琵琶精专用技能标题图片。Boss血条、保护、斩败、掉落与通关复用公共插件。

三个怪物保留原动作像素并转换为 Spine 4.3 附件时间轴，不猜造骨骼；身体使用固定脚底注册点，原左向图像统一成项目 +X 朝向。AnimationPlayer、攻击框和霸体效果仍在 `data/monsters/zaomeng1/*/visual.tscn` 中可编辑。背景音乐是 `Music.swf` 中原 `bg1` MP3，使用已有音频插件与独立音乐/音效音量设置。

配置入口：

打开 `game/levels/huaguoshan.tscn` 的2D编辑器，地图已启用可编辑子节点。`BattleSession/Actors/FinalExit` 默认位于最终下坡中央，编辑器中会预览原传送门循环动画；拖动该节点同时移动光效和运行时通关判定，不必另改区域资源。检查器的 `activation_size` / `activation_offset` 控制黄色框的范围，`preview_animation` 可暂停预览。运行时仍在最终区域清理完毕后才显示光效。

`BattleSession/Actors/EditorPreview` 显示蓝色战斗区域边界、绿色进入触发区、橙色出生点及怪物数量/首只等待/间隔时间；随机出生点显示其采样范围。可通过 `show_regions`、`show_entry_areas`、`show_birth_points` 独立开关。预览读取实际区域和出生计划资源，并随 `SpawnPoints` 子节点移动更新；拖动对应出生点即可调整真实刷怪位置。区域边界和进入范围在该预览节点的 `regions` 资源中编辑。辅助图形和循环刷新仅在编辑器运行。

- `map.tscn`：地面、平台、玩家、出生点、区域出口和最终传送门。
- `visual.tscn`：背景、视差与原素材位置；`assets/maps/huaguoshan/` 保存原图。
- `definition.tres`、`regions/`、`waves/`、`plans/`：区域与生成规则。
- `manifest.json`：语义 ID 与定义资源索引。
- `audio.json`：本关音乐及怪物音效映射，保留公共音效。
- `original_source.json`：原始配置、坐标转换、属性映射与 SWF SHA256。
- `original_attacks.json`：原hit1帧数及逐帧stick矩形，原悟空hurt帧数。
- `data/monsters/zaomeng1/*/skill.tres`、`actions.tres`、`ai.tres`：技能时间轴、击退、动作规则和独立AI配置；大猩猩的 `boss.tres` 保存唯一hit1规则。
- `data/templates/battle_level_base.tscn`、`game/levels/BattleLevelScene.cs`：两关共用的预置会话、战斗 HUD、输入和菜单入口。

离线重新导出：安装 Python 的 Pillow 依赖后，在项目目录执行 `python tools/import_huaguoshan.py --export`。需要参考仓库的 FFDec Java依赖以及 README 所述原目录；只读 SWF，不运行 Flash 游戏。此命令会重写花果山生成资源，手动编辑前保留版本记录。普通游玩无需 Python、Java或SWF。

验证：`tools/verify_stage_eight.ps1 -Godot '<配套引擎>' -Suites huaguoshan,huaguoshan_combat`。C#套件检查真实全图移动、动作帧及镜像、碧玉径属性、延迟出生、上限、出生时镜头可见、33次死亡、掉落、Boss结束、出口唯一胜利与节点释放；战斗套件在60/15FPS检查真实坡地横向击退、原击飞、正反方向命中/打空/去重/扣血和AI真实释放。NativeAOT使用验证预设导出后，执行 `tools/csharp/verify_native_game.ps1 -Suites huaguoshan,huaguoshan_combat`。
