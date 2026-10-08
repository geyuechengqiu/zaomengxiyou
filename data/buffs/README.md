# 原版 Buff 与组合被动资源

九个真实原版定义和五个验收组合被动。详细算法、生命周期、触发配置、原版适用边界见 [阶段10说明](../../addons/battle_foundation/combat/buffs-triggers.md)。[测试场景](../../examples/buff_demo.tscn) 是当前 F5 入口。

| 资源 | 用途 |
| --- | --- |
| attack_up.tres | type8 原版当前攻击20%增量 |
| slow.tres / stun.tres | 减速50% / 1.5秒Core眩晕 |
| poison.tres | type5 最大生命2%持续伤害 |
| shield.tres | type262 普通护盾258 |
| invulnerable.tres / super_armor.tres | 多份独立无敌 / 霸体 |
| reflection.tres / lifesteal.tres | 原版最终伤害反伤35% / 盾前吸血与技能倍率上限 |
| passive_cast_attack.tres | 验收：技能释放加攻 |
| passive_hit_poison.tres | 验收：有效命中施加毒伤 |
| passive_received_attack.tres | 验收：实际受击加攻 |
| passive_low_health_shield.tres | 验收：生命向下跨过30%施加盾 |
| passive_kill_heal.tres | 验收：击杀回复25 |
| original_config.json / source_mapping.json | 原版完整配置行、语义ID对应、源文件SHA256 |
| sources/ | 本阶段算法所依据的原版源码节选及行号；只作核对，不参与运行 |

新资源使用 GameplayStatusData。默认定义时长-1代表永久，0代表瞬时；可配置叠层上限、stacking_group、stacking_policy、remove_on_death、apply_effects、features、remove_effects、tags。属性持续效果设置 reapply_on_stack，瞬时治疗/伤害保持false。编辑原版attack_up的ratio、shield的fixed_amount、poison的health_ratio/period即可调整效果；修改影响新施加实例，已有实例持有独立定义图。

给新角色/怪物增加永久被动：定义的 initial_status_ids 添加相应ID，或技能 PassiveStatusFeature 配置状态。需要注册到角色使用的manifest：本场景使用 [buffs/manifest.json](../battle2d/buffs/manifest.json)，其他场景需登记相同定义。组件按status实例来源撤销，不修改角色基础数据。

导出工具 [export_stage_ten_buffs.py](../../tools/export_stage_ten_buffs.py) 支持 --source 指定原版目录。已有手工编辑会在同名原版资源重导出时恢复为原始数据；自定义效果应使用新ID，避免覆盖。原版数字ID仅保存metadata，游戏业务使用attack_up/poison等语义ID。
