# Boss行为、技能与公共表现

[原版居中血条、姓名/抗性图标、怪物出场与提前移镜](original-presentation.md)：F5已接入，使用原SWF贴图、字体及注册点；调试生命/保护数字默认隐藏。

F5运行 [碧玉径](../../../game/levels/biyujing.tscn)：孙悟空、五区域普通怪物、复苏容器、玉石琵琶精及最终出口构成完整战斗流程。角色控制和技能按键沿用现有配置。Boss不是独立伤害系统，仍使用Core操作意图和状态机、GAS技能实例/属性/Vital/Buff、原版伤害策略及BattleClock。

[类图与时序](../docs/boss.svg) · [巨石灵君配置入口](../../../data/monsters/jushi_lingjun/README.md) · [原始配置与来源哈希](../../../data/monsters/jushi_lingjun/original_boss.json)

## 定义与实例

| 类型 | 职责 |
| --- | --- |
| `BattleBossProfile` | 专属技能选择规则、阶段列表、血条数量、召唤上限、关卡条件；Resource不保存运行状态 |
| `BattleBossSkillRule` | 技能ID、优先级、随机权重、距离/高度/血量范围、阶段/机关前置条件、共享冷却组、播报与预警 |
| `BattleBossPhase` | 血量阈值、进入技能、前置条件、进入期无敌、场景事件 |
| `BattleBossController2D : BattleAIController2D` | 索敌和移动、提交Core意图、技能选择、阈值锁存、一次性阶段、召唤归属计数 |
| `BattleBossObjectDefinition` | 弹道/石墙的素材动作、偏移、速度、角度、逐帧攻击矩形、寿命、命中规则及伤害上下文 |
| `BattleBossObjectPool2D` | 场景预置对象的取用、时间推进和归还；不在释放技能时创建组件或视觉节点 |
| `BattleBossWorldObject2D` | 独立对象的飞行/成形、碰撞、命中记录和生命期 |
| `BattleBossFeedback2D` | 全场共享的Boss血条、保护条、技能横幅、可选预警、声音和镜头反馈 |

角色场景预置AIController、GAS、属性、运动、反应、保护、动画适配器和BossObjects。召唤怪及关卡刷怪实例化已制作好的完整怪物场景；技能对象池里的Sprite2D、AnimationPlayer、StaticBody2D和CollisionShape2D均可以在编辑器直接查看。

配置通过原有资源索引装配；冷却、选择记录、阶段锁存、召唤弱引用、对象年龄和命中记录属于各自实例。两只同配置Boss互不修改共享Resource。

## 原版玉石琵琶精

使用普通Monster/10601、Resource/11106、MAi/10009。等级3、生命1167、攻击30、减法防御5、保护满值25000；土抗10、火抗-10。语义技能ID为`jushi_lingjun_skill1/2/3`；数字ID只用于来源追溯和原版伤害查表。

| 技能 | 原ID | 30FPS素材时序 | 命中与后续 |
| --- | --- | --- | --- |
| 震颤之音 | 2001100 | 动作38帧；特效AB第15至32帧有效 | 一次近身伤害；按原targetMove与stiff击退/浮空 |
| 琵琶之伤 | 2001110 | 动作44帧；第24帧发射音符；贴身特效AB第19至27帧 | 5枚音符、20度间隔、原速度650/秒；每弹每目标一次；原默认倍率0.2 |
| 玉石之墙 | 2001120 | 动作30帧；第19帧生成；成形12帧后切15帧循环 | 成形后实体阻挡并持续5秒；原 `atkMax=0` 禁用接触命中，不造成伤害或硬直 |

攻击窗口使用左闭右开区间，因此技能1写`start_frame=15,end_frame=33`。素材保持30FPS语义，世界坐标换算2倍，镜像同时改变图像、偏移、攻击区域及飞行方向。石墙不随正常动作结束消失；音符的`linkParentState=true`使它随动作结束清理。取消技能会回收该次释放产生的全部对象，包括独立石墙。

决策适配原MAi的优先关系：琵琶技能优先、5秒共享组；技能1/3随机选择、共用10秒组；出手后1–2秒退步。寻路、活动范围、索敌和移动限制复用通用AI；这不是逐节点复制原Flash行为树。Inspector中的距离范围是当前2D接近策略参数。

原普通玉石琵琶精**没有血量阶段或召唤怪配置**，主线的`Phases`为空，三个原版技能不额外召唤。阶段与召唤作为其他Boss的通用能力，独立验收配置实际运行这些入口。

石墙的零命中上限参照原 `DamageControl.onHurt()`：计数达到 `skill.atkMax` 就立即返回；`SkillParam` 从技能定义继承该值，成形与后续实体阶段都未覆盖它。因此 `maximum_hits=0` 表示禁用命中，不能当作无限次数。对象仍更新动画、AB与实体碰撞，但跳过伤害、Buff、硬直和保护值结算，也不发布 `battle.attack.hit`。原 `atkInterval=0` 同样保留；对象定义允许零间隔，正数命中上限仍按每对象、每目标计数。

## 播报、动作和真实攻击

原`CharEntity`在开始动作前发送技能播报；普通玉石琵琶精的播报前置时间为0，不人为增加等待。技能2/3使用原PNG横幅，技能1没有伪造横幅。

```text
AI选择 → Core battle.boss.announced → Core ai_skill意图 → GAS技能实例
                                                 ↓
                                         AnimationPlayer开始动作
                                                 ↓
                              源第24帧/第19帧 → 音符/石墙 → 真实命中
```

横幅按原`SkillComing`轨迹：y=80；从x=-100、透明进入，7/30秒到x=350、不透明；2秒后用7/30秒移到x=627、透明，2+8/30秒隐藏。横幅可以晚于技能动作结束；取消、受控、死亡或离场会立即撤销对应播报。

其他Boss可配置`announcement_lead_seconds>0`和`warning_rect`：先播报预警，等待结束才创建技能实例。控制状态在等待期间取消请求，恢复控制后重新决策。不会把播报提前当作伤害或扣费。

Boss血条按原`BossBleed`普通分支分成三条，颜色/边框/保护条来自原SWF。生命遮罩采用0.6秒OutQuad，保护遮罩0.3秒OutQuad；保留原版条内X计数和保护条，生命/保护数字仅在显式开启调试时显示，保护改变时无需等待生命变化。公共Boss栏代替该Boss的头顶普通条。

## 阶段、召唤与场景条件

`Phases`按血量比例从高到低排列。达到阈值立即锁存，即使当前攻击尚未结束或随后回血，也保留待转换状态；动作/控制结束且前置条件满足后执行进入技能。同一`phase_id`只执行一次。跨越多个阈值时按配置顺序逐个进入。进入期无敌使用统一`damage_rules`来源`boss_phase`，完成、取消或死亡时移除。

技能选择也可以限制当前阶段、血量比例、距离、机关条件或当前没有召唤物。机关条件先在关卡`Condition IDs`声明，业务统一调用`level_instance.set_condition()`；阶段的`scene_event`通过Core发送，场景脚本可以据此改变地形或镜头边界。

召唤使用已有GAS帧事件，不另设Timer：

```gdscript
# 在技能Timeline的Events中添加BattleFrameEvent资源：
source_frame = 19
event_id = &"battle.boss.summon"
payload = {"monster_ids": [&"剑舞", &"驭兽使"], "spawn_offset": Vector2(-100,0)}
```

偏移使用世界坐标，X跟随Boss朝向。控制器验证battle_id、攻击实例ID和存活状态后生成怪物。`summon_total`记录成功生成；`summons.size()`为当前存活归属数；`summon_deaths`只记录真正生命耗尽，存活回收不伪造死亡，重复死亡通知不重复计数。Boss死亡/离场统一回收自己的召唤物和对象，不修改关卡其他出生计划。

需要召唤物参与出口条件时，在关卡声明额外条件并加入`Required Conditions`，然后在Boss配置填写`completion_condition`；只有Boss死亡且归属召唤全部清理后才置true。关卡仍检查全部必要出生计划，不能只依据Boss栏消失开启出口。

## 保护、时间、取消和声音

三个原版技能具有动作霸体，使用已有Core动作规则，允许扣血但阻止普通受击打断。保护满25000使用现有`BattleProtectionMeter`进入最高优先级之一的PROTECT，取消当前攻击和对象，临时阻止伤害/控制/受击位移，再恢复AI。此处保护时间0.8秒沿用现有插件可编辑预设；原素材没有独立保护动作，当前用待机和金色保护提示，尚未完整移植1900010的原Buff组合/视觉。该差异不会被当作已验证的原版时长。

所有决策、前置播报、阶段、对象动画、寿命、命中间隔、血条缓动和镜头反馈只消费BattleClock的combat delta。暂停/受击停顿时冻结，慢动作同比例变慢。声音播放器随暂停冻结。对象以不超过1/30秒的子步推进，弹道对地形和目标连续扫掠；一次大delta跨过生成与结束时先补完有效飞行命中，再清理联动对象，避免低帧率漏伤害。

Boss BGM来自`boss_01.swf`；命中、胜负声音来自原`hs.swf`。Resource/11106没有Boss专属声音字段，因此不把悟空音效误接到Boss。播放器在公共表现中预置，通过Core新入口`audio_manager.bind_scene_player()`接入Music/SFX总线及原有音量设置；同tick的密集命中只播放一次声音。石墙/保护触发轻微镜头反馈，当前强度3像素可编辑，该强度为展示配置。

`clear_battle()`、死亡、取消、换场景均断开Core/Vital订阅、移除阶段规则、关闭对象碰撞、清空命中记录并恢复镜头偏移。不使用后台Timer或独立事件总线。

## 验收与重新导出

[verify_boss.gd](../../../tests/suites/verify_boss.gd)检查真实原AB、普通/扇形/持续伤害、镜像、石墙阻挡、低帧率、前置播报、暂停/控制、机关条件、阶段只触发一次、GAS帧事件召唤、计数/取消/回收、保护/血条/Core音量总线及实例隔离。最后从实际初始悟空出发，仅用Core移动和普攻意图打通五区域：34个目标、Boss实际扣血1199、剩余生命55。

2026-10-09验证：Boss72项检查、完整29套回归全部通过；D3D12/NVIDIA实际渲染确认原版横幅、人物技能/音符/实体墙/保护与跳字显示。镜头仅在反馈期间修改偏移，避免未触发震动时无穷大计时进入正弦运算，导致世界和跳字坐标异常。文档本地链接、源文件/音频哈希、SVG语法与实际浏览器渲染也已检查。

```powershell
& '<带Spine模块的Godot.exe>' --headless --path . res://tests/suites/verify_boss.tscn
& './tools/verify_stage_eight.ps1' -Godot '<带Spine模块的Godot.exe>'
# GPU检查不要使用--headless；PNG写入忽略目录.cleanup-backup。
& '<带Spine模块的Godot.exe>' --path . --script res://tools/capture_boss.gd
```

原素材再导出需要本机原版仓库、Python、Java及该仓库的FFDec库。若重建阶段12数据，随后再运行阶段13导入，恢复三套Boss技能与索引。导入会覆盖巨石灵君生成资源，日常编辑资源无需重新导入。

```powershell
python tools/import_stage_twelve_level.py --original-root 'D:/UserData/Downloads/game/Speculum-4399-master'
python tools/import_stage_thirteen_boss.py --original-root 'D:/UserData/Downloads/game/Speculum-4399-master'
python tools/import_original_boss_presentation.py 'D:/UserData/Downloads/game/Speculum-4399-master'
node tools/generate_boss_diagram.mjs
```

首关已经使用原版地图美术与原TMX碰撞，所有区域位于同一张 [连续地图](../level/map-template.md)。NPC、补给和容器治疗行为尚未纳入首个可玩关卡。玩家和Boss死亡、失败重开、五区域战斗及最终出口流程已实现。
