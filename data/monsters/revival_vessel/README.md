# 场景琵琶：持续回血与 Boss 登场

`复苏容器` 是现有索引 ID，原版 Monster/10501 的场景琵琶。修改 [ai.tres](ai.tres)、[skill.tres](skill.tres)、[healing_buff.tres](healing_buff.tres) 即可调整支援节拍、动作和回血规则。

原 Skill/2001000 没有伤害，`myBuff=50004`，Buff/5000401 的 `toWho=11` 表示施放时所有同阵营角色，包括琵琶自身；不是攻击框内的敌人。`BattleSupportAIPolicy2D` 按五秒技能冷却提交现有 Core 技能操作意图，无需玩家接近，不移动、不跳跃。技能仍经过动作许可、GAS 消耗/冷却提交和原 34 帧 Spine 动作，受到控制或出场未完成时不会施放。

Buff 持续十秒，每两秒结算 `int(目标最终最大生命 × 0.05 + 目标最终攻击 × 2 + 10)`；不在施加时立即治疗。重复施加使用原 `replaceRule=2`，不叠加多个回血周期。目标死亡/离场清理自己的 Buff；`destroyBySend=0`，琵琶死亡后其他单位已有的 Buff 持续到期。实际回复量受最大生命限制，并使用共享数字池显示整数回血跳字。

原 Buff/5004 的十四帧光效导出到 `assets/monsters/revival_vessel/buff`；[healing_visual.tscn](healing_visual.tscn) 保存注册点、两倍世界比例与 30 FPS 循环。公共反馈池预置此节点，显示期间读取 GAS 状态，暂停和慢动作使用 BattleClock；到期、死亡或复用反馈时停止并隐藏。

琵琶死亡动作和死亡技能第 25 帧的 Boss 出生计划保持现有关卡配置。普通 Boss/10601 的 `showAppear=0`，不添加小怪烟雾；原 `BattleTopLayer.showBoss` 另行触发屏幕 `BossComing`，现已接入公共 `BossFeedback/HUD/BossComing`，33 帧、30 FPS、1.1 秒。注册同一实例只播一次，新 Boss 可以再次播放，死亡、离场及清关停止旧动画。该提示不改变真实攻击时间或增加虚构前摇。

离线导出：`py -3.12 tools/import_pipa_and_boss_entrance.py D:/UserData/Downloads/game/Speculum-4399-master`。原素材 SHA-256、Buff 配置和帧数见 [original_healing.json](original_healing.json)。来源逻辑位于参考仓库 `BuffManager.createBuffs`、`ManEntity.updateBuffVo`、`viewers/component/BossComing.as`、`BattleTopLayer.showBoss`。

专项验收：`tools/verify_stage_eight.ps1 -Godot <Godot路径> -Suites pipa_support`。验证同阵营目标、无误伤、原整数公式、间隔/到期、暂停、回血跳字、表现池清理及完整 Boss 登场生命周期。
