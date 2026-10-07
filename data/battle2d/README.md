# 孙悟空 2D 动画接入数据

这组业务定义使用角色 ID `孙悟空`、普攻技能 ID `sunwukong_attack1` 至 `sunwukong_attack5`，独立于阶段一的接口样例。运行时加载本目录 manifest，不需要 Speculum-4399-master 项目或外部 JSON。

| 文件 | 用途 |
| --- | --- |
| [manifest.json](manifest.json) | Core/BattleCatalog 的角色、技能定义索引 |
| [sunwukong.tres](sunwukong.tres) | 角色定义：业务 ID、属性集、Health/Mana 模板、普攻 ID、独立场景 |
| [sunwukong_attributes.tres](sunwukong_attributes.tres) | 共用 28 个原版属性定义，Role 2001 初始值 |
| [sunwukong_2d.tscn](sunwukong_2d.tscn) | CharacterBody2D、脚底碰撞体和动画适配节点 |
| [sunwukong_actions.tres](sunwukong_actions.tres) | 战斗锁定、攻击框与平台样例运动参数 |
| [attack1.tres](attack1.tres) | GAS 普攻：10 帧 / 30 fps，第 4 帧 Core 攻击事件，原版冷却 0 |
| [attack2.tres](attack2.tres)、[attack3.tres](attack3.tres)、[attack4.tres](attack4.tres)、[attack5.tres](attack5.tres) | 其余四段 GAS 技能：原版段时长、命中帧与伤害倍率，第四段双判定 |
| [sunwukong_combo.tres](sunwukong_combo.tres) | 五段语义 ID、动作、许可、优先级与第四段技能位移窗口 |
| [combo_source_mapping.json](combo_source_mapping.json) | 五段原版源码/配置来源、SHA-256、反向偏移与迁移边界 |
| [source_mapping.json](source_mapping.json) | 业务 ID 与原版来源 ID、文件路径、SHA-256、动作帧数、注册点和原资源哈希 |
| [../animation/sunwukong_profile.tres](../animation/sunwukong_profile.tres) | 表现层动作映射、骨架、固定脚底偏移、皮肤和骨骼挂点 |

初始攻击 26、防御 5、最大生命 275、最大法力 100、步行 210、奔跑 300、水抗 -20、火抗 20、跳跃属性 -178、保护阈值 50000，均来自原版 Role.json 的 2001 条目。原版编号只用于溯源，保存在 source_mapping.json 的 source_character_id/source_skill_id；运行时配置和调用使用上述业务 ID。原表没有的耐久属性使用 0；成长字段暂不接入。当前生命、技能计时、姿态和外观不写回定义。

```gdscript
var session := BattleSystem.create_session(self, "res://data/battle2d/manifest.json", 2001)
var actor := session.spawn_entity_2d("characters", &"孙悟空", Vector2(350, 650))
actor.animation.set_facing(-1)
actor.animation.set_skins([&"套装/2", &"武器/weapon2"])
# 等待真实物理碰撞落地，再走 actor.try_attack() / try_jump()。
```

原版攻击范围保留 `0;-200;130;300` 的脚底局部语义，样例按 2 倍源单位转换；朝左时整体镜像局部范围。五段共六次素材帧事件各进行一次矩形命中查询；第四段第二击先反向并添加 `(-17,-4)` 偏移，再按朝向镜像。每次命中对同个目标去重，原版持续 sensor 的整个碰撞生命周期尚未迁移。装备切换目前只换外观，生命/属性仍是基础角色值。

平台样例的重力和跳跃使用 Godot 像素/秒参数；原版 -178 的运动单位来自旧引擎，不能直接作为本场景跳跃速度。完整接口、规则分离、挂点、皮肤组合和操作说明见 [动画适配层 README](../../addons/battle_foundation/animation/README.md)。

五段连击、二段跳、运动与状态条件表见 [阶段四 README](../../addons/battle_foundation/movement/README.md)。场景入口：[wukong_platform_demo.tscn](../../examples/wukong_platform_demo.tscn)。验收入口：[verify_wukong_animation.tscn](../../examples/verify_wukong_animation.tscn)、[verify_stage_four.tscn](../../examples/verify_stage_four.tscn)。均使用现有带 Spine 模块的 Godot 引擎。
