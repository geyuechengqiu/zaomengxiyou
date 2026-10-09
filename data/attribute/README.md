# 上古天帝篇共享基础属性

本目录使用 GAS 原生 `GameplayAttribute`、`GameplayAttributeSet` 和 Vital 资源，为玩家、怪物、Boss、宠物、召唤物提供共用的属性定义。按本次范围只建立共享定义和通用属性集，不导入各实体的初始数值、等级成长或装备数据。

来源为本地 `Speculum-4399-master` 的 `exports/zmhj_role_stats/原始配置/Role.json`、`EXP.json`，以及 `UserVOBase.as`、`UserVO.as`、`RoleConfigVO.as`、`ManConfigVO.as`、`ResistType.as`、`BattleModelManager.as`。参照该仓库的 `exports/zmhj_damage_formulas/伤害计算公式.md` 和 `exports/zmhj_protection/机制说明.md` 核对语义。原字段、分类、单位和资源路径见 [来源映射](source_mapping.json)，资源自身的 metadata 也保存 source_field/category/unit。

## 属性清单

全部 28 个 attribute_id 与原版字段名完全一致，保留大小写，资源文件也采用原名，例如 atk.tres、phyDef.tres、hpMax.tres、critical.tres、lucky.tres。属性集、Vital 依赖、GAS 默认伤害策略和独立演示的对应基础属性已同步更新，运行时无需维护第二套 ID 别名。

所有定义均为 `GameplayAttribute`，不在定义上设置 `scalable_value`；实体数值由自己的属性集提供。默认无有限上限；常规属性下限为 0，八系抗性、有符号跳跃速度和保护阈值保留负数。所有 `is_percentage` 均为 false。

| 显示名 | GAS ID / 资源 | 原字段 | 单位与语义 |
| --- | --- | --- | --- |
| 攻击 | [atk](atk.tres) | atk | 攻击值；兼容 GAS 默认伤害策略 |
| 防御 | [phyDef](phyDef.tres) | phyDef | 物理防御值；兼容 GAS 默认伤害策略 |
| 最大生命 | [hpMax](hpMax.tres) | hpMax | HealthVital 上限 |
| 最大魔法 | [mpMax](mpMax.tres) | mpMax | ManaVital 上限 |
| 回血 | [reHP](reHP.tres) | reHP | 点/秒 |
| 回魔 | [reMP](reMP.tres) | reMP | 点/秒 |
| 命中 | [hit](hit.tres) | hit | 命中评分 |
| 闪避 | [dodge](dodge.tres) | dodge | 闪避评分 |
| 暴击 | [critical](critical.tres) | critical | 暴击概率换算评分 |
| 韧性 | [toughness](toughness.tres) | toughness | 抗暴击评分 |
| 幸运 | [lucky](lucky.tres) | lucky | 暴击伤害换算评分 |
| 守护 | [guardian](guardian.tres) | guardian | 暴击伤害防护评分 |
| 光抗 | [lightResist](lightResist.tres) | lightResist | 原始抗性值，可负 |
| 暗抗 | [darkResist](darkResist.tres) | darkResist | 原始抗性值，可负 |
| 水抗 | [waterResist](waterResist.tres) | waterResist | 原始抗性值，可负 |
| 火抗 | [fireResist](fireResist.tres) | fireResist | 原始抗性值，可负 |
| 木抗 | [woodResist](woodResist.tres) | woodResist | 原始抗性值，可负 |
| 土抗 | [soilResist](soilResist.tres) | soilResist | 原始抗性值，可负 |
| 风抗 | [windResist](windResist.tres) | windResist | 原始抗性值，可负 |
| 雷抗 | [rayResist](rayResist.tres) | rayResist | 原始抗性值，可负 |
| 行走速度 | [walkSpeed](walkSpeed.tres) | walkSpeed | 原版速度数值 |
| 奔跑速度 | [runSpeed](runSpeed.tres) | runSpeed | 原版速度数值 |
| 一段跳速度 | [jumpSpeed1](jumpSpeed1.tres) | jumpSpeed1 | 原版有符号竖直速度 |
| 二段跳速度 | [jumpSpeed2](jumpSpeed2.tres) | jumpSpeed2 | 原版有符号竖直速度 |
| 最大耐久 | [enduranceMax](enduranceMax.tres) | enduranceMax | endurance 上限 |
| 耐久恢复 | [reEndurance](reEndurance.tres) | reEndurance | 点/秒 |
| 耐久衰减 | [reduceEndurance](reduceEndurance.tres) | reduceEndurance | 正值表示每秒衰减量 |
| 保护触发阈值 | [protectPoint](protectPoint.tres) | protectPoint | 保护条触发阈值，负值禁用 |

## 通用属性集与初始值

| 属性集 | 数量 | 用途 |
| --- | --- | --- |
| [entity_base_attributes](sets/entity_base_attributes.tres) | 28 | 一次初始化完整共享属性，适合可战斗实体 |
| [core_attributes](sets/core_attributes.tres) | 12 | 生命/魔法、攻击/防御、恢复及六项战斗评分 |
| [resistance_attributes](sets/resistance_attributes.tres) | 8 | 八系抗性 |
| [movement_attributes](sets/movement_attributes.tres) | 4 | 行走、奔跑、一段跳、二段跳 |
| [protection_attributes](sets/protection_attributes.tres) | 4 | 原版耐久与保护阈值 |

这些是中性模板，初始值只有最大生命为 1、保护阈值为 -1，其余为 0。1 点生命便于 HealthVital 初始化为存活，-1 禁用保护阈值；它们不是原版某个角色的数值。不需要魔法的实体可保留 mpMax=0，静态实体可保留速度为 0；不需要完整集合时只组合所需分类集。

完整集和分类集是两种初始化方式：不要把完整集与包含相同 ID 的分类集同时传入，GAS 会拒绝重复注册，不能把第二个属性集当作覆盖层。另新增 [progression_attributes](sets/progression_attributes.tres)，保存面板与通知使用的 level / exp；level 由组件 current_level 统一同步，禁止装备和 Buff 修改。四项成长由 [孙悟空成长资源](progression/sunwukong.tres) 形成 growth.level 修改器。身份、阵营、AI、霸体/无敌标志和动作配置不在数值属性中重复存储。

## Vital 接入与实体隔离

[health.tres](vitals/health.tres) 是 HealthVital 模板，绑定 hpMax / reHP；[mana.tres](vitals/mana.tres) 是 ManaVital 模板，绑定 mpMax / reMP。当前生命和魔法由这两个 Vital 保存；当前 endurance 和保护累计值属于业务运行状态，本次只定义其相关配置，没有添加耐久 Vital 或保护逻辑。

```gdscript
const BASE_ATTRIBUTES = preload("res://data/attribute/sets/entity_base_attributes.tres")
const HEALTH = preload("res://data/attribute/vitals/health.tres")
const MANA = preload("res://data/attribute/vitals/mana.tres")

func initialize_entity(component: GameplayVitalAttributeComponent) -> void:
	# 本例数值仅演示接入，不是原版角色配置。
	var initial_values := {
		&"hpMax": 100.0, &"mpMax": 80.0,
		&"atk": 20.0, &"phyDef": 5.0,
	}
	var entity_set := BASE_ATTRIBUTES.duplicate(true) as GameplayAttributeSet
	for definition: GameplayAttribute in entity_set.attributes:
		if initial_values.has(definition.attribute_id):
			entity_set.attributes[definition] = initial_values[definition.attribute_id]
	component.initialize([entity_set], [HEALTH, MANA])
```

在 initialize 之前配置实体初始值，生命/魔法会按对应上限初始化。初始化后仅改上限不会自动补满当前值。装备和 Buff 通过 `GameplayAttributeModifier` 修改实例，移除时按 source_id 清理；避免修改共享模板来改变一个实体。组件创建的属性和 Vital 实例各自独立。

## 与原版公式的边界

暴击、韧性、幸运、守护、命中、闪避是评分，需要结合双方等级与 EXP 表换算，不能导入 crit_rate 或把 1000 点显示成 100000%。幸运用于暴击伤害，不能直接当作掉宝率。本次没有建立重复的概率属性或等级换算器。

八系抗性同样保留原始值：原客户端正抗性按 `r / (r + 100)` 换算，负抗性按 `r / 100` 换算；因此 20 不是直接减伤 20%，-20 也必须保留。移动和跳跃未擅自换算到 Godot 世界单位，尤其原版向上跳跃的负速度应由业务控制器转换。

GAS 现有 SimpleDamageLogic 只执行攻击减防御和上下文倍率；上述评分、抗性、移动和保护资源都已能存储并接受修改器，完整原版命闪、暴击、元素结算及保护行为仍需业务策略接入。资源存在不表示这些效果已自动进入伤害公式。

## 验证

完整计算链、统一接口、原版生命规则及插件联合类图见 [属性链说明](../../addons/battle_foundation/attributes/README.md)。原28个通用定义保持原集合，等级和经验作为另2个定义组合使用。生命、魔法、攻击、防御最终取整，成长中间值保留小数。Role / EXP 的 SHA256 和导入口径见 [成长来源映射](progression/source_mapping.json)。重新导入：`node tools/import_attribute_progression.mjs <Speculum-4399-master路径>`；不覆盖动画编辑内容。

```powershell
& '<Godot 可执行文件路径>' --headless --path . res://examples/verify_base_attributes.tscn
```

[验证脚本](../../examples/verify_base_attributes.gd) 检查 28 个定义、5 个属性集、2 个 Vital 模板的加载、唯一 ID、原版 ID 与文件名、评分与负值、上限/恢复、来源修改器、多实体隔离及默认伤害策略读取 atk / phyDef，失败返回非零退出码。

孙悟空属性集另加入原Common的 `xpMax=10000`，当前无双值保存在独立 `rage` Vital（入场0），与角色经验 `exp` 分开。预置WushuangController与GAS状态实现获取/消耗/原版增益，详见 [普通无双规则](../effects/wushuang/README.md)。
