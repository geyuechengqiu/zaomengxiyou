# 玉石琵琶精配置

本次已修复石墙/音符负注册点的缩放：场景为 `Visual(scale=2)/Sprite2D`，AnimationPlayer 控制子 Sprite 的原帧和位置；不要再单独给 Sprite 设置2倍缩放。Boss 死亡播放共享原版斩败，完成计划后开启原36帧发光出口；播报不再被已开始动作的取消清掉。[修复依据与 UI 编辑位置](../../ui/README.md)。

原Monster/10601名称已修正为“玉石琵琶精”，显示同步原版；原有定义ID`巨石灵君`及`jushi_lingjun`文件路径作为兼容索引保留。[居中血条、原抗性图标与出场说明](../../../addons/battle_foundation/boss/original-presentation.md)。

主线F5运行 [碧玉径](../../../examples/level_progression_demo.tscn)。末区击破复苏容器后，按原死亡技能第25帧延迟生成Boss；击败Boss并完成区域后，在地面出口按W/↑确认通关。

[系统实现、时序与验收](../../../addons/battle_foundation/boss/README.md) · [独立SVG类图](../../../addons/battle_foundation/docs/boss.svg) · [原版证据](original_boss.json)

## 常用编辑入口

| 文件或节点 | 如何修改 |
| --- | --- |
| [attributes.tres](attributes.tres) | 初始生命/魔法上限、攻击、防御、等级、抗性；沿用GAS属性链与Vital，不直接改共享运行资源 |
| [monster.tscn](monster.tscn) 的 Attributes | 场景默认属性与覆盖入口，方式与现有角色属性组件一致 |
| monster.tscn 的 AIController → Profile | 通用索敌、活动范围、决策间隔、退步与移动策略 |
| [boss.tres](boss.tres) / AIController → Boss Profile | 三套技能权重/优先级、距离、共享CD；Phases、Maximum Summons、Intro Seconds和Completion Condition |
| [skill.tres](skill.tres)、[skill2.tres](skill2.tres)、[skill3.tres](skill3.tres) | GAS冷却、Timeline动作/源帧率、攻击段、霸体、帧事件；真实伤害仍查原版技能表 |
| [visual.tscn](visual.tscn) 的 AnimationPlayer | 待机、走路、受击、死亡、attack_1/2/3、技能1/2特效及保护提示，可直接编辑预览 |
| visual.tscn 的 AttackHitbox | 单一人物攻击框，预览技能配置中的逐帧矩形；不要追加每段独立攻击框 |
| [note.tres](note.tres) / [note.tscn](note.tscn) | 音符速度、五个角度、生成位置、存活时间/父状态联动/命中次数；编辑器预览循环动作 |
| [wall.tres](wall.tres) / [wall.tscn](wall.tscn) | 成形/循环动画、逐帧AB、成形时间、总寿命、命中间隔、实体碰撞位置/大小 |
| monster.tscn 的 BossObjects | 预置5枚音符和3座石墙的完整节点池；改技能并发量时对应增加容量 |
| [protection.tres](protection.tres) | 保护持续0.8秒及阻止伤害/状态规则；保护满值25000来自原怪物定义 |
| 公共 BattlePresentation/BossFeedback | Boss栏、技能播报、Core音量总线、背景音乐/声音、镜头震动；场景不挂在悟空下 |

世界距离已换算2倍；素材帧号保持30FPS。音符速度650原像素/秒由对象运行层换算为1300世界像素/秒，`spawn_offset`同样只在对象层换算一次；Boss规则里的attack_range和召唤事件spawn_offset直接使用世界单位。石墙总寿命5.4秒包含12/30秒成形及5秒实体阶段。

普通玉石琵琶精原版没有阶段和召唤配置；`boss.tres`保持Phases为空。若设计自己的Boss，可在Inspector添加BattleBossPhase资源：设置唯一phase_id、0到1之间的health_ratio、entry_ability_id和required_conditions；按阈值从高到低排列，阶段技能必须已登记在怪物definition的ability_ids中。

前置预警填写某条技能规则的Announcement Lead Seconds与Warning Rect，后者为世界矩形，跟随朝向镜像。原Boss规则前置为0，实际命中由技能素材帧独立决定。

## 添加其他Boss

1. 复制整个角色目录，修改definition ID、场景/资源引用和语义技能ID；属性/运动/动作配置按新角色设置。
2. 保留通用角色组件，AIController使用BattleBossController2D并指定自己的AI Profile与Boss Profile；每项技能及阶段进入技能需在definition登记。
3. 用GAS Timeline定义素材动作、攻击段和`battle.boss.objects`或`battle.boss.summon`事件。复用现有伤害、Buff和受击结算，不在专属AI里直接改目标生命。
4. 弹道/召唤特效场景提前制作，在BossObjects下预置所需对象数量并填写独立ObjectDefinition；普通怪召唤直接复用已有完整怪物场景。
5. 在所用关卡manifest登记新怪物、技能和场景，在出生计划的Monster IDs配置语义怪物ID；需要额外通关条件时先声明关卡条件。
6. 专属场景动作通过phase.scene_event及Core事件处理；确实超出规则配置时再继承BossController扩展决策，继续通过Core意图/GAS执行动作。

公共Boss栏当前展示最近登记的一只Boss，主线验收为单Boss。多个Boss的技能/属性/保护/召唤状态独立；多Boss同时展示需要另行配置多套UI栏。
