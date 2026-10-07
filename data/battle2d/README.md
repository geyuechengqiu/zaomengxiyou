# 孙悟空 2D 动画接入数据

阶段 6 增加 [single_attack/manifest.json](single_attack/manifest.json)，以相同业务 ID 复用悟空场景、动画和成长，仅配置第一段技能及 [木桩](dummy/wooden_dummy.tres)。单段技能额外设置 2 个素材帧的临时命中窗口，原五连击资源保持默认瞬时查询。运行 [单段场景](../../examples/single_attack_demo.tscn)，实现与验收见 [战斗闭环 README](../../addons/battle_foundation/combat/README.md)。

这组业务定义使用角色 ID `孙悟空`、普攻技能 ID `sunwukong_attack1` 至 `sunwukong_attack5`，独立于阶段一的接口样例。运行时加载本目录 manifest，不需要 Speculum-4399-master 项目或外部 JSON。

已接入 [属性计算链](../../addons/battle_foundation/attributes/README.md)：角色定义引用孙悟空成长与 EXP 资源；平台面板增加等级/经验、生命/魔法、攻击/防御和 GM、经验、穿脱装备、Buff 按钮。新增 equipment/attribute_test_weapon.tres、statuses/attribute_test_buff.tres 和 attribute_test_monster.tres 用于插件联合及同类怪物隔离验收，均明确标注测试数值。

| 文件 | 用途 |
| --- | --- |
| [manifest.json](manifest.json) | Core/BattleCatalog 的角色、技能定义索引 |
| [sunwukong.tres](sunwukong.tres) | 角色定义：业务 ID、属性集、Health/Mana 模板、普攻 ID、独立场景 |
| [sunwukong_attributes.tres](sunwukong_attributes.tres) | 共用 28 个原版属性定义，Role 2001 初始值 |
| [sunwukong_2d.tscn](sunwukong_2d.tscn) | CharacterBody2D、脚底碰撞体和动画适配节点 |
| [sunwukong_actions.tres](sunwukong_actions.tres) | 战斗锁定、状态权限与平台运动参数 |
| [attack1.tres](attack1.tres) | GAS 普攻：10 帧 / 30 fps，第 4 帧 Core 攻击事件，原版冷却 0 |
| [attack2.tres](attack2.tres)、[attack3.tres](attack3.tres)、[attack4.tres](attack4.tres)、[attack5.tres](attack5.tres) | 其余四段 GAS 技能：原版段时长、命中帧与伤害倍率，第四段双判定 |
| [sunwukong_combo.tres](sunwukong_combo.tres) | 五段语义 ID、动作、许可、优先级与第四段技能位移窗口 |
| [combo_source_mapping.json](combo_source_mapping.json) | 五段原版源码/配置来源、SHA-256、碰撞框与偏移、迁移边界 |
| [attack_hitboxes_source.json](attack_hitboxes_source.json) | 原版 attackV427.swf 中五组 ABRect 只读提取快照与素材哈希 |
| [source_mapping.json](source_mapping.json) | 业务 ID 与原版来源 ID、文件路径、SHA-256、动作帧数、注册点和原资源哈希 |
| [../animation/sunwukong_profile.tres](../animation/sunwukong_profile.tres) | 表现层动作映射、骨架、固定脚底偏移、皮肤和骨骼挂点 |
| [../animation/sunwukong_visual.tscn](../animation/sunwukong_visual.tscn) | 主 AnimationPlayer、原生子播放器与一个由技能数据更新的攻击判定框 |

动画在独立表现场景编辑；攻击范围修改技能时间线事件的 hit_rect、hit_scale_x/y 和 hit_offset。所有技能复用一个 CollisionShape2D，预览及实际命中从技能定义更新几何，步骤见 [可视化编辑说明](../animation/README.md)。

初始攻击 26、防御 5、最大生命 275、最大法力 100、步行 210、奔跑 300、水抗 -20、火抗 20、跳跃属性 -178、保护阈值 50000，均来自原版 Role.json 的 2001 条目。原版编号只用于溯源，保存在 source_mapping.json 的 source_character_id/source_skill_id；运行时配置和调用使用上述业务 ID。原表没有的耐久属性使用 0；成长与 EXP 已接入独立属性计算链。当前生命、技能计时、姿态和外观不写回定义。

```gdscript
var session := BattleSystem.create_session(self, "res://data/battle2d/manifest.json", 2001)
var actor := session.spawn_entity_2d("characters", &"孙悟空", Vector2(350, 650))
actor.animation.set_facing(-1)
actor.animation.set_skins([&"套装/2", &"武器/weapon2"])
# 等待真实物理碰撞落地，再走 actor.try_attack() / try_jump()。
```

攻击范围使用原素材 `attackV427.swf` 的 `ab_attack10000` 至 `ab_attack50000`，而 `Skill.atkRange=0;-200;130;300` 属于选敌范围。原版 SkillControl 仅对正 scaleX/scaleY 缩放碰撞框，负显示缩放不翻转它；先添加技能局部偏移，再按朝向整体镜像，最后按 2 倍转换场景单位。五段共六次素材帧事件默认各查询一次独立受击区域，每次命中在攻击实例中对同个目标去重；阶段 6 单段配置支持持续窗口，但原版 sensor 的整个生命周期尚未迁移。1/2 快捷键只切换外观；属性入口已支持成长、装备与 Buff，见属性链说明。

平台样例的重力和跳跃使用 Godot 像素/秒参数；原版 -178 的运动单位来自旧引擎，不能直接作为本场景跳跃速度。完整接口、规则分离、挂点、皮肤组合和操作说明见 [动画适配层 README](../../addons/battle_foundation/animation/README.md)。

五段连击、二段跳、运动与状态条件表见 [阶段四 README](../../addons/battle_foundation/movement/README.md)。场景入口：[wukong_platform_demo.tscn](../../examples/wukong_platform_demo.tscn)。验收入口：[verify_wukong_animation.tscn](../../examples/verify_wukong_animation.tscn)、[verify_stage_four.tscn](../../examples/verify_stage_four.tscn)。均使用现有带 Spine 模块的 Godot 引擎。
