# 第一关普通怪物配置

普通玉石琵琶精现已接入阶段13三技能、独立对象池与原版公共Boss表现；[Boss配置与扩展步骤](jushi_lingjun/README.md)、[插件实现](../../addons/battle_foundation/boss/README.md)。F5可完整经过普通怪物、容器和Boss后确认通关。

F5入口已切换到 [阶段12区域关卡](../../game/levels/biyujing.tscn)，按原版出生计划生成怪物并推进出口。下述32只预置小怪场景仍用于独立AI测试，F6运行。[区域/刷怪/通关配置](../levels/biyujing/progression/README.md)。

F6 运行 `tests/fixtures/first_level_demo.tscn`；A/D 移动、K 跳跃、J 普攻/跑攻/跳攻，Esc 暂停和改键。场景中的按钮可以对附近小怪施加眩晕或减速，用于观察 AI 是否遵守动作权限。伤害跳字、原版血条与受击特效全部由 `BattleSession/BattlePresentation` 管理。

## 实际原版身份

原版 `Dungeon[1]` 为 **碧玉径**，地图 `No_1-1_V283`，5472×600。`monsterID` 与 `monsterNum` 按下表配对；原配置与 AI 树、技能参数、图集 SHA256、AB 帧保存在 [original_first_level.json](original_first_level.json)。业务身份使用中文名称，技能使用语义 ID；原数字 ID 仅作来源元数据。

| 原怪物ID | 名称 | 数量 | 本阶段处理 |
| --- | --- | --- | --- |
| 10101 | 第01关-剑舞 | 16 | 通用近战小怪实例 |
| 10201 | 第01关-驭兽使 | 16 | 通用远程小怪实例 |
| 10401 | 第01关-场景大剑 | 1 | 场景机关，保留原配置依据 |
| 10501 | 第01关-场景琵琶 | 1 | 固定机关，保留原配置依据 |
| 10601 | 玉石琵琶精 | 1 | Boss，留待Boss阶段 |
| 11301 | 小飞龙-蓝瓶 | 6 | 补给实体，留待关卡掉落阶段 |

两类普通小怪均为等级2、生命199、攻击9、防御2；原版 walkSpeed=100，以已有2倍战斗坐标换算为200像素/秒。悟空保留当前组件中的等级1、生命275、攻击26，行走/跑步按相同比例换算为420/600世界像素/秒，仍可直接修改属性组件。地图宽度也按2倍坐标设置为10944，镜头缩放0.5，显示940×590。当前地形和32只怪物的位置为编辑器预置验收布局，没有声称复刻原地图/刷怪波次/机关/Boss。

第一关悟空五连击、跑攻、跳攻的受击参数使用 [原版逐段资源](../characters/sunwukong/skills/normal_attacks/README.md)，不再引用阶段9临时验收配置。普攻3按原版向攻击者拉回，第四段两击分别覆盖速度与时长；横向速度不累计、到期停止，左右镜像与低帧率均做实际位移验收。基础技能保留各自原版击退、击飞与吸附参数，没有使用统一缩小系数。

## 每类怪物的编辑入口

| 文件/节点 | 修改内容 |
| --- | --- |
| `jianwu/definition.tres`、`yushoushi/definition.tres` | 身份、阵营、初始等级、属性集、技能列表 |
| 各目录 `attributes.tres` | 该类怪物共享基础数值；实例不修改资源 |
| `monster.tscn → GameplayVitalAttributeComponent` | 单个场景的 `Base Values` 与 `Initial Level Override`，优先于定义 |
| `monster.tscn → AIController → Profile` / `ai.tres` | 行为策略、攻击技能、检测范围、活动范围、巡逻、逃离、跳跃、目标选择 |
| `actions.tres` | 重力、跳跃速度、跳跃次数、受击锁定、状态移动/转向/打断权限 |
| `skill.tres` | GAS冷却、动作时长、攻击段、原版判定、击退与硬直 |
| `visual.tscn → AnimationPlayer` | 原版图集的待机、移动、受伤、死亡、攻击身体与特效时间轴 |
| `monster.tscn → CollisionShape2D` / `Hurtbox` | 移动物理体 / 受击框，彼此独立 |
| `visual.tscn → AttackHitbox` | 唯一攻击框；选择 `Preview Action`、`Preview Time` 读取技能的逐帧判定 |
| `data/levels/biyujing/actors.tscn` | 编辑已有出生位置、地形以及场景中的属性/AI覆盖 |

`Detection Range` 是索敌水平距离，`Vertical Range` 是索敌高度差；`Leash Radius` 是距离出生点的最大活动半径，目标离开范围或自身越界时返回出生点；`Attack Range` 是发起攻击的距离，与真正命中框分开。当前近战为180、远程为400战斗像素。远程额外允许配置最小距离180，过近先退步。这些活动范围、巡逻等待与跳障参数属于移植平台的可调整策略，并非全部来自原版数值。

`Policy → Combat Style` 支持 melee、ranged、stationary；每只怪的目标、巡逻方向、退步计时、决策节拍都在 AIController，资源仅保存配置。`Flee Health Ratio=0` 关闭低生命逃离，设置0.25则在25%及以下尝试远离目标；`Maximum Retreat Distance` 限制退步距离。`Target Selector` 可选最近、最低当前生命、最高攻击，`Preferred Definition` 可优先指定角色定义；仍须满足敌对、存活、检测范围与活动边界。

### 怪物跳跃高度

剑舞、驭兽使与玉石琵琶精在各自 `actions.tres` 明确配置 `Gravity=1980`、`Jump Velocity=-620`、`Maximum Jumps=1`；复苏容器为固定对象，`Maximum Jumps=0`。原版 `Common.gravity=110`，Nape 每原素材帧积分0.1秒、素材30FPS，世界坐标放大2倍，所以 Godot 重力为 `110 × (30 × 0.1)² × 2 = 1980`。主动起跳现在与原版受击浮空使用相同的重力，避免示例默认1500造成跳高和滞空时间偏大。

AI越障的起跳速度仍为平台移植调校值，普通怪物配置表没有独立 `jumpSpeed1` 字段，不将它标为原版数值。理论上升高度 `Jump Velocity² / (2 × Gravity)` 约97世界像素，镜头缩放0.5时约49屏幕像素；固定60Hz积分实测略低。速度负值绝对值越大跳得越高，重力越大越快落地。后续调整整类怪物请修改对应 `actions.tres`；单只实例需要不同高度时，将其 `Action Profile` 设为唯一再修改。悟空的运动参数单独配置。

## 添加新怪物

1. 复制其中一类目录，改 `definition.tres` 中的语义身份、场景路径、基础属性和技能ID；将新身份和技能加入正在使用的 manifest。
2. 保留预置的 Attribute、Ability、Status、DamageRules、ActionState、MotionController、ComboState、HitReactionController、ProtectionSystem、AIController 节点。怪物不需要 PlayerOperations；动作、伤害与Buff入口不另建一套。
3. 在新 `ai.tres` 选择/创建 Policy 与 TargetSelector，填写对应攻击技能。修改共享 AI 配置影响整类怪物；修改单只前请在 Inspector 将资源设为“唯一”。运行时临时改配置先深复制，运行时计时不要写回资源。
4. 将新动作映射到 `idle/move/run/hurt/death/attack_1` 等语义动作，预置 AnimationPlayer；攻击/受击框独立，左右朝向只通过适配器镜像。
5. 预置怪物实例到关卡 `Actors`，设置 `Scene Definition Id` 与 `Scene Category=monsters`；`Scene Session Path` 默认为 `../..`，如改变层级则修改此路径。公共表现中预置对应反馈视图，绑定 `actor_path`，避免启动时新增反馈节点。

复杂行为继承 `BattleAIPolicy2D.decide(controller)` 返回 `state/axis/facing/jump/skill`，或者继承 `BattleAITargetSelector2D.score_target`。例如不同怪物使用保距射击、低血逃离、固定炮台或优先攻击召唤物，不需要复制战斗实体或更改角色规则。运行时所需状态应放在独占的 AIController 子类字段，而非共享 Policy 资源。

## 原素材与重新导出

四种现有关卡怪物已使用 `SpineAnimationAdapter`：剑舞、驭兽使、复苏容器及玉石琵琶精。原 PNG 图集、图集 XML 与 AB XML 保留为离线来源；游戏运行直接加载 `monster.atlas`、`monster.spine-json` 和 `spinedata.tres`，不解析XML。

原版是整帧图片，没有肢体骨骼数据；转换使用 Spine 4.3 附件时间轴，Body/Effect1/Effect2 独立槽位保存原层序、裁边偏移与每帧注册点，动作切换显式清除旧特效。每个实例独立 SpineSprite 姿态，图集和骨架定义只读共享。原版30FPS时长保持不变，不用插值变形替代像素轮廓。

`visual.tscn` 内预置 SpineSprite、SpineAnimationTrack、原生播放器、语义 AnimationPlayer 与单一 AttackHitbox。编辑器选择语义动作可以预览身体、特效和命中框；攻击规则仍来自 GAS Timeline 的 AB 判定。Boss石墙、弹道和出生特效是独立场景对象，继续使用原逐帧对象动画，不作为怪物人物骨架。

新增人物优先从 [角色/怪物模板](../templates/README.md) 继承。测试用木桩是SVG夹具，不是关卡怪物。

```powershell
python tools/convert_monsters_to_spine.py
```

该工具默认保留已经转换的可编辑场景；`--force` 从 `source_visual.txt` 重新生成，会覆盖手工编辑。转换证据和动作时长位于每种怪物素材目录的 `spine_conversion.json`。普通怪物与Boss导入器现在会自动执行转换。

```powershell
python tools/export_stage_eleven_monsters.py --original-root D:/UserData/Downloads/game/Speculum-4399-master
```

此工具会重建导入的 visual、怪物/技能配置和验收关卡布局。手工调整这些生成文件前可复制成新角色目录；不要在有未保存自定义修改时重新生成。原 `TextureAtlas.fromTexture(_fill=false)` 使用 width−frameX/height−frameY 填充，SpriteRender 再应用 pivot；导入保留该注册点和透明边，不按错误的 frameWidth 裁剪兽使的技能帧。

实现和验收命令见 [AI插件说明](../../addons/battle_foundation/ai/README.md)。

![现有四种怪物的Spine原生攻击渲染](../../addons/battle_foundation/docs/monster-spine-attack.png)
