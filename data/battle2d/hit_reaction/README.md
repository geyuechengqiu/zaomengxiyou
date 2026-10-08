# 阶段 9 测试预设

本目录 manifest 只给 [hit_reaction_demo.tscn](../../../examples/hit_reaction_demo.tscn) 使用；原五连击、单段、阶段7技能和阶段8伤害场景仍引用原来的 manifest。

attack1～5 保留原技能帧、矩形、伤害和第四段两次命中，在每次命中 payload 增加反应参数。以下是可编辑的验收值，不是原版 Flash 物理参数；保护增量仍读取原版技能表。

| 段 | 主要反应 | 硬直秒 | 水平运动 | 向上速度 |
| --- | --- | --- | --- | --- |
| 1 | 轻硬直 | 0.12 | 90 × 0.06秒 | 0 |
| 2 | 定距击退 | 0.18 | 8像素 / 0.08秒 | 0 |
| 3 | 较长硬直 | 0.22 | 100 × 0.08秒 | 0 |
| 4 | 击飞、落地倒地 | 0.25 | 100 × 0.1秒 | 320 |
| 5 | 更强击飞、落地倒地 | 0.3 | 220 × 0.16秒 | 520 |

速度单位为世界像素/秒。hit_stop_seconds 为 0.025～0.04 秒。相同目标连续命中会依据新段替换反应及冲量，但仍受目标抵抗、动作可打断种类/优先级、保护与无敌策略约束。

编辑 [demo_attack_reactions.json](demo_attack_reactions.json)，然后在项目根目录执行 `node tools/build_stage_nine_resources.mjs`，重建本目录五个攻击资源和 manifest。该脚本只读基础技能数据，不覆盖阶段6～8；手动编辑生成的 attack*.tres 会在下次重建时被覆盖。

[east_emperor_protection.tres](east_emperor_protection.tres) 与 [shang_yang_protection.tres](shang_yang_protection.tres) 各自引用原 Boss 满值，maximum_override 默认 -1。可以直接在 Godot Inspector 设置正整数覆盖，或改 original_boss_key 选择其他原版 Boss。场景的左上输入框仅运行时覆盖，重置/重新运行恢复资源配置。

角色 reaction_profile 控制抵抗、霸体伤害倍率和无敌阻止效果；木桩 [reaction_animations.tres](../dummy/reaction_animations.tres) 只管视觉，修改动画时长不自动改变硬直/倒地时长。完整实现和验收见 [阶段9说明](../../../addons/battle_foundation/combat/hit-reaction-protection.md)。
