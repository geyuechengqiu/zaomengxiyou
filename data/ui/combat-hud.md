# 原版战斗入口、计时与怪物保护

正式入口为 `game/levels/biyujing.tscn`，940×590。共享控件预置于 `HUD/BattleHUD`，不挂载到玩家。

底部恢复原 `UIBattleLayer` 的六个主线入口：背包、技能、心法、法宝、灵宠、设置。图标和普通/悬浮/按下三态由 `mission_20260406_1.swf` 的626、633、661、640、647、654号符号导出；六个按钮宽55、间隔63、从x285开始，y528。技能槽与生命/魔法/经验条继续读取GAS及最终属性，改键后同步实际键名。

背包打开现有完整背包交互；设置打开实际按键重映射菜单。技能入口列出当前装备的GAS技能、按键和剩余冷却，法宝入口读取真实amulet槽，尚无灵宠时显示原提示“你还没有灵宠”。技能学习、心法养成、法宝养成和灵宠管理的完整原版窗口尚未移植；当前数据面板不冒充这些功能。后续模块可通过 `BattleOriginalHUD.module_requested` 接入。背包与数据面板互斥，B打开背包，Esc先关当前面板，再开设置。打开面板释放角色输入并暂停关卡；关闭最后一个面板才恢复。

顶部 `LevelTimer` 使用原1343号battletime背景和方正粗圆字体，在x470居中。时间读取 `BattleLevelInstance2D.elapsed`，沿用原 `GameFrame.time` 战斗时间语义显示MM:SS：整秒截断，暂停不增长，恢复连续，重新开始关卡归零，区域切换不重置。当前为本关正向计时，遵循既有战斗慢动作和停顿规则。

## 每种怪物自己的保护配置

| 实体 | 原保护满值 | 原保护技能 | 满值行为 |
| --- | ---: | ---: | --- |
| 剑舞 | 100000 | 0 | 清空分数和该目标技能次数，不施加无敌 |
| 驭兽使 | 100000 | 0 | 同上 |
| 复苏容器 | 100000 | 0 | 同上 |
| 巨石灵君（玉石琵琶精） | 25000 | 1900010 | 取消当前技能和对象，净化减益，单次保护动作，施加无敌和减益免疫 |

满值在 `data/monsters/<名字>/protection.tres` 编辑；当前分数、技能命中次数和计时保存在每实体独立的 `BattleProtectionSystem` 中，不写入共享Resource。累计使用原protectPoint、protectPointB、protectPointMax、模式修正和三秒无伤清零。普通怪物头顶不额外显示调试保护条；Boss保护条沿用原空底、填充和0.3秒插值。

巨石灵君沿用原 `BuildAnimator` 缺失动作回退：图集没有protect时使用30帧idle，30FPS播放一次，锁定一秒。Buff1000101“无敌”和27000201“免疫减益”分别由GAS持续两秒；20000201的即时净化移除负面实例并撤销属性修正。动作结束不提前删除Buff；单独减益免疫不阻止扣血。原wuDiAlpha开启时，无敌期间角色透明度为原值一半，结束、死亡或回收时恢复。未增加原版没有的绿色保护多边形。

悟空跑动攻击结束回idle（空中回jump），清除旧移动/奔跑快照和方向双击标记，持续按旧方向不立即重回run。重新按方向或奔跑键可继续移动。攻击、跳跃和技能缓存独立保留，受击和中断继续使用Core规则。

## 来源与重新生成

原源码依据：UIBattleLayer、ClickBattleBottomButton、TimeUtil、GameFrame、ManFrameControl、ManEntity.CheckProtect、BuildAnimator、BossBleed和SkillConfigVO.getMyBuff。原怪物/保护技能/Buff配置、UI符号与源SWF哈希在 `data/protection/first_level_source.json`。

```powershell
python tools/refine_combat_hud.py --original-root 'D:/UserData/Downloads/game/Speculum-4399-master'
# 只用已导出的资产重建：
python tools/refine_combat_hud.py --author-only
./tools/verify_stage_eight.ps1 -Godot 'D:/路径/Spine-Godot.exe' -Suites combat_hud,wukong_context_attacks,boss,original_battle_ui,monster_spine,hit_reaction
```

正式运行不依赖原游戏目录、Java或导出脚本。背包及怪物导入工具最后自动应用修正，避免重建恢复旧按钮或0.8秒临时保护。新验收见 `tests/suites/verify_combat_hud.tscn`。

本次验证：默认32组回归全部通过，包括新增42项战斗HUD/保护检查、90项真实跑攻/跳攻输入检查、231项原生Spine与模板检查和97项Boss检查。等级1悟空用实际五连击完成首关34个目标，剩余生命74；GPU检查通过，并更新了README战斗截图。最终编辑器资源导入和脚本解析无错误。
