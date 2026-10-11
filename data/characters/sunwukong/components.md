# 角色场景与预置组件

角色组件统一保存在可复用的角色场景中。打开 [sunwukong_2d.tscn](character.tscn)，场景树中可以直接选择每个组件；战斗开始只初始化数据、绑定引用和登记到 Core，不再通过 `new()` / `add_child()` 补建角色组件。

```text
SunWukong : CharacterBody2D / BattleEntity2D
├─ CollisionShape2D                   身体物理碰撞
├─ AnimationAdapter                   预置 Spine / AnimationPlayer
│  ├─ AnimationPlayer                 身体、攻击特效与判定框时间轴
│  ├─ AttackHitbox / CollisionShape2D  所有技能共用的单一攻击框
│  └─ AttackEffects                   原版攻击特效
├─ Hurtbox / CollisionShape2D         独立受击区域
├─ GameplayVitalAttributeComponent   GAS 属性链与生命/魔法
├─ GameplayAbilityComponent          GAS 技能实例、消耗与冷却
├─ GameplayStatusComponent           GAS Buff 与事件响应
├─ DamageRules                       独立护盾、结算规则与角色回调
├─ ActionState                       Core 动作状态机绑定与权限查询
├─ MotionController                  重力、跳跃预算与扫掠碰撞
├─ ComboState                        段号、预约、起手方向与转身额度
├─ HitReactionController             硬直、击退、浮空与保护动作
├─ ProtectionSystem                  保护值、同技能命中累计与保护时间
├─ Inventory                         背包与装备槽
└─ PlayerOperations                  玩家操作意图与技能槽
   └─ OperationController            Core 输入、缓存、双击与改键
```

伤害跳字、血条、保护条和通用受击闪光由战斗会话的 **BattlePresentation** 管理，角色场景只保存自身组件。`actor.feedback` 是查询会话视图的兼容入口。节点归属、编辑位置与生命周期见 [公共战斗表现](../../../addons/battle_foundation/presentation/README.md)。

GAS 组件保留为角色根的直接子节点，符合已有 GAS 宿主接口及状态归属规则；主动画轨道、武器挂点和攻击框路径继续引用 AnimationAdapter 子树。

## 组件配置与运行数据

### 直接编辑悟空属性

1. 打开 [悟空角色场景](character.tscn)，选中 **GameplayVitalAttributeComponent**。
2. Inspector 展开 **Scene Attributes → Base Values**，直接修改原属性 ID 对应的数值。悟空已经预填 28 项基础属性和 `exp`，不用打开属性集资源。
3. **Initial Level Override** 修改初始等级；悟空默认 1，范围 1～220。其他角色默认 0，表示沿用角色定义的初始等级。
4. 保存场景，重新运行。修改在创建 Vital 和计算成长之前应用，出生生命/魔法以修改后的最终上限填满；面板与攻击使用同一 GAS 最终值。

| Base Values 的键 | 含义 |
| --- | --- |
| atk / phyDef | 一级攻击 / 防御 |
| hpMax / mpMax | 一级最大生命 / 最大魔法；当前生命、魔法仍由 Vital 独立管理 |
| critical / toughness | 暴击 / 韧性评分，按原版等级数据换算概率 |
| lucky / guardian | 幸运 / 守护评分 |
| hit / dodge | 命中 / 闪避评分 |
| walkSpeed / runSpeed | 行走 / 奔跑速度；跳跃参数仍在 Action Profile |
| reHP / reMP | 生命 / 魔法恢复速度 |
| exp | 初始当前等级经验，达到门槛后按原流程升级 |

抗性、耐久和保护等其他基础值同样可编辑。填写的值覆盖定义中的一级基础值，未填写的键沿用定义；删除某个键或清空字典可恢复该项或全部定义默认值。未知 ID、非有限数值、超出成长范围的等级会在角色初始化前报告配置错误。

这些是**一级基础值**。例如组件攻击设为 84、初始等级设为 3，仍叠加原版每级 5.25，最终攻击为 `round(84 + 5.25 × 2) = 95`；装备和 Buff 继续通过已有属性入口叠加，卸下后恢复组件基础与成长值。初始化只修改资源副本，不写回共享 `.tres`。运行时 GM 修改仍调用 `set_base_value()` / `set_level()`；场景配置在下次运行时生效。

在关卡中修改单个悟空，展开 **BattleSession → Actors → SunWukong → GameplayVitalAttributeComponent**。单段、时间轴、原版伤害及受击样例已开启角色的“可编辑子节点”；其他关卡可以右键角色实例启用该选项。关卡中的本地覆盖优先于基础角色场景。

原版伤害及受击样例的组件中预置 `atk = 100`，平台与基础角色为 26；伤害样例启动和切换样例时恢复组件配置，不再把攻击强行写成 100。暴击测试模式仍临时使用验收评分，返回普通模式后恢复组件评分。

[verify_scene_attributes.tscn](../../../tests/README.md) 覆盖 Inspector 字段、保存/重新加载、初始等级成长、Vital 填满、实例与资源隔离、面板与实际扣血一致，以及伤害样例切换保留组件配置。

| 编辑位置 | 作用 |
| --- | --- |
| 角色根的 Action Profile | 运动速度规则、重力、跳跃、动作许可、五连击、跑攻与跳攻入口 |
| 角色根的 Reaction Profile / Protection Profile | 受击响应、霸体/无敌策略及保护满值与时间 |
| GameplayVitalAttributeComponent | Scene Attributes → Base Values / Initial Level Override；以角色定义为默认，组件配置优先，运行时 GAS 属性与 Vital 独立 |
| GameplayAbilityComponent | 已学习技能由角色定义 ability_ids 初始化，技能资源可在 data/battle2d 编辑 |
| GameplayStatusComponent | 状态容器；externally_driven 与 filter_events_by_owner 在角色场景中启用 |
| Inventory | 背包容量、装备槽；角色初始化后自动接入统一属性入口 |
| PlayerOperations | 操作配置、设备、技能槽，以及 enabled 控制权开关 |
| PlayerOperations/OperationController | Core 控制器预置节点，使用统一战斗输入驱动 |

ActionState、MotionController、ComboState、HitReactionController、ProtectionSystem 已改为 Node，由场景树管理生命周期。它们不自行逐帧更新，仍由 BattleSession 的战斗时钟驱动。ActionState 内的 Core `BaseStateMachine` / `BaseState` 保留插件运行对象模型；DamageRules 节点持有每实例的 `BattleDamageRules` 数据。属性实例、生命/魔法、技能施放、Buff、护盾和命中记录按实体或施放创建独立运行数据，避免修改共享配置。

查询当前战斗状态使用 `actor.action_state.get_state_name()`；Node 的 `get_name()` 读取场景节点名 `ActionState`。

## 玩家与目标控制权

悟空基础场景的 PlayerOperations 默认 `enabled = false`。放置多个相同角色时，各自具有完整组件与独立状态；只对玩家实例启用操作。单段、原版伤害、受击与时间轴样例在场景中覆盖为 true，平台样例绑定已有节点并按 enable_player_controls 设置控制权。

单段攻击和时间轴角色场景继承基础悟空组件，测试关卡只覆盖动作配置、技能槽和控制权。[木桩场景](../../templates/monster_base.tscn) 预置相同的 GAS 与动作组件，使用自己的动画与规则；[3D 基础实体](../../levels/biyujing/progression/README.md) 预置 GAS 和伤害规则节点。插件综合演示的 DemoTarget 也已预置 GAS 和背包节点。

## 新角色接入与校验

1. 复制悟空或木桩场景，保留上面的必需组件节点和脚本。替换身体碰撞、受击区域、动画适配器及角色动作配置。
2. 在 `BattleEntityDefinition.scene` 中指定角色 PackedScene，再配置属性、Vital 和技能 ID。
3. 玩家角色保留 PlayerOperations / OperationController，在玩家实例开启 enabled；非玩家角色可使用木桩模板，按 AI 需求提交操作意图。
4. 组件初始化通过 `BattleGASBinding.attach()` 绑定现有节点。会话在生成或注册之前调用 `get_component_configuration_error()` 校验，缺少组件或类型错误会明确返回错误；缺少角色场景不会再生成空实体替代。

角色退出或重生时，技能/Buff 清理、Core 动作机和操作控制器注销，组件节点随角色释放。未入树的临时场景实例也会在释放时清理动作机的 RefCounted 引用关系。

## 验收

[verify_character_components.tscn](../../../tests/README.md) 通过 95 项检查，覆盖入树前完整组件、继承场景、绑定前后节点身份不变、组件不重复生成、玩家/目标控制权、同类角色数据隔离、缺失节点校验与离树/未入树释放。现有五连击、跑攻跳攻、碰撞、改键、属性、伤害、受击与保护验证继续通过。

```powershell
& '<Spine-Godot.exe>' --headless --path . res://tests/suites/verify_character_components.tscn
```
