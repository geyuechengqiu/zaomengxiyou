# 角色与怪物基础模板

[combatant_base.tscn](combatant_base.tscn) 是组件结构基类，不作为独立可运行人物。它预置CharacterBody2D碰撞、Hurtbox、GAS属性/Vital、技能、状态、DamageRules、Core动作状态机、运动、连招、受击、保护和背包组件；实例初始化只绑定，不补建节点。

[character_base.tscn](character_base.tscn) 继承公共组件，预置悟空Spine表现、玩家操作意图/Core控制器、无双组件和悟空动作配置。[monster_base.tscn](monster_base.tscn) 继承公共组件，预置剑舞Spine表现与可配置通用AI。这些是新角色起点，默认人物大小/AI不代表所有角色；编辑碰撞与受击框适配你的素材。

## 新角色或怪物

角色定义模板已引用原版战力规则。新角色的 `Fight Power Correction` 默认0，悟空也为0，匹配参考离线原版；仅明确需要职业平衡修正时再设置。规则和配置入口见 [原版战力](../../addons/battle_foundation/attributes/fight-power.md)。

角色和怪物模板的 Spine 动画场景均带预置 `SuperArmorEffect`，自动读取统一霸体规则；新增角色需把 `Capture/Body` 设为对应 Spine 数据。描边设置和原版视觉优先级见 [霸体表现](../effects/super_armor/README.md)。

1. 在Godot创建“新建继承场景”，选择character_base或monster_base，保存到新实体的data目录；不要修改模板影响其他派生场景。
2. 保留组件节点。替换AnimationAdapter为你保存的Spine视觉场景，配置语义动作idle/move/run/jump/fall/land/hurt/death与攻击动作；骨架、两个AnimationPlayer、SpineAnimationTrack、单一AttackHitbox全部预置。动画完成只通知动作系统。
3. 将模板 [character_definition.tres](character_definition.tres) 或 [monster_definition.tres](monster_definition.tres) 复制到新目录，修改唯一语义definition_id、display_name、faction_id和scene路径。复制/新建attribute_set、成长表和技能定义，避免编辑共享定义改变其他种类。通过GAS组件Base Values设置场景覆盖，或在定义属性集中设置同种实体默认属性；Initial Level Override为0时使用定义等级。
4. 替换action_profile，配置碰撞大小、重力、走跑速度、跳跃速度、二段跳、动作限制和连招。角色操作槽改成自己的ability_id；怪物AI Profile配置索敌、活动范围、攻击策略和技能请求。Boss可将AI脚本替换为BattleBossController2D并预置BossObjects池。
5. 在实际关卡manifest的characters/monsters登记definition_id→定义资源，登记引用的skills/statuses；出生计划填相同语义ID。ID采用角色名或语义技能名，不使用原数字作为业务ID。
6. 场景预置实体可填写Scene Definition Id和指向BattleSession的路径；动态刷怪通过BattleSession.spawn_entity_2d加载已登记场景。运行生命、技能冷却、Buff和AI决策各实例独立，不修改共享定义。

模板保留悟空/剑舞现有资源作为可播放默认示范，不额外登记到生产manifest。全局伤害跳字、血条展示、Boss栏、声音和关卡UI由BattleSession的公共表现层管理，不挂在玩家模板下。

## 验证

```powershell
./tools/verify_stage_eight.ps1 -Godot '<Spine Godot可执行文件>' -Suites monster_spine,character_components,monster_ai
```

检查四种原生Spine的43个语义动作、原时长、镜像/注册点、特效清空以及两个同配置模板的组件和生命隔离。模板需要BattleSession和定义进行初始化，单独F6打开模板不提供完整战斗会话。
