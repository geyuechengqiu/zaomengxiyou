# 战斗、伤害与技能生命周期

实际入口为 [碧玉径](../../../game/levels/biyujing.tscn)、[花果山](../../../game/levels/huaguoshan.tscn)、[水帘洞](../../../game/levels/shuiliandong.tscn)。F5打开造1大地图，关卡本身可按F6。旧单段攻击/木桩演示及其独立索引已删除，当前文档和验证使用真实角色、怪物与关卡。

## 运行结构

| 实现 | 职责 |
| --- | --- |
| [BattleSession](../runtime/battle_session.gd) | 唯一战斗时间入口、实体索引、事件、出生/死亡和战斗结算 |
| [BattleEntityIteration](../runtime/BattleEntityIteration.cs) | 成员变化时重建有序快照，正常tick复用；保持重入、离场及死亡清理语义 |
| [BattleEntity2D](../runtime/battle_entity_2d.gd) | 组合动作、输入、属性、GAS、攻击实例及目标结算 |
| [BattleAttackInstance](../runtime/battle_attack_instance.gd) | 每次施放独立编号、攻击段、命中集合、对象回收与取消 |
| [BattleFrameTimelineFeature](../gas/battle_frame_timeline_feature.gd) | 使用素材帧时钟推进攻击窗口、派生、事件和位移 |
| [BattleHitbox2D](../movement/battle_hitbox_2d.gd) | 唯一攻击框，按场景配置、缩放与朝向生成世界几何 |
| [BattleHurtbox2D](../movement/battle_hurtbox_2d.gd) | 目标受击资格和几何 |
| [BattleMotionController2D](../runtime/BattleMotionController2D.cs) | 坡面、跳跃、击退、边界和单向平台穿透 |
| [BattlePresentation2D](../presentation/battle_presentation_2d.gd) | 公共反馈、音频、Boss/UI、伤害数字池与时钟 |

Core负责操作意图、动作状态机和事件总线；GAS负责技能学习/施放、消耗/冷却、Attribute/Vital、Status/Effect及DamageInfo。角色和UI不通过动画完成事件自行扣血，也不创建第二套伤害或Buff系统。

实体配置来自关卡清单及独立Resource定义。生命、冷却、攻击编号、强化、随机值和状态属于运行实例，不能写回资源默认值。普攻、技能、Boss和投射物共用伤害/受击规则；每个命中段保留独立的命中次数与下一命中时间。

## 配置入口

- [原版伤害顺序与公式](original-damage.md)：命中、暴击、幸运、等级、附伤、抗性、增减伤、真实伤害、护盾和结果字段。
- [技能时间轴与派生](skill-timeline.md)：素材帧、段窗口、多次命中、操作缓存、位移和取消协议。
- [受击、击退与保护](hit-reaction-protection.md)：动作和GAS保护规则；坡面不把横向击退转为持续上升速度。
- [Buff与被动](buffs-triggers.md)：叠层、刷新、周期、移除、吸血与反伤递归限制。
- [原版战斗连击](hit-combo.md)：按有效伤害累计，1.5秒无命中后结束，与普攻派生段数分离。
- [悟空实际技能](../../../data/characters/sunwukong/skills/README.md)、[关卡索引](../../../data/levels/biyujing/progression/manifest.json)。

GAS组合子效果使用Resource数组，执行/移除时验证其为GameplayEffect。这样避免空的自类型数组在退出时保留脚本；无效子项被忽略，合法子效果继续克隆并按原协议执行。堆叠刷新遍历同一容器，不改变直接伤害/治疗和可撤销持续效果的区别。

## 验证

```powershell
./tools/verify_stage_eight.ps1 -Godot '<配套 Godot.exe>' -Suites boss,loot_growth,original_skill_panel,mihouwang_skills,huaguoshan_combat
```

完整验证目录见 [tests/README.md](../../../tests/README.md)。覆盖真实技能施放/取消、倍率、MP/CD、派生、保护、上下坡击退、单向平台、暂停、死亡和资源隔离。三关使用预置角色/地图/组件；出生、掉落和表现池仍按实际战斗流程运行，不采用已退役的演示夹具数据。
