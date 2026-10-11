# 玩家操作定义

[悟空操作定义](../characters/sunwukong/controls/input.tres) 是 CoreOperationProfile 定义，保存语义意图到 InputMap 动作的映射、默认物理键、轴规则和输入时间窗口。当前按住状态、控制权、缓存与序列保存在每个 CoreOperationController；重映射写入用户配置，不修改本资源。新角色可以配置自己的操作资源，复用相同控制器。

角色只识别 `attack`、`jump`、`skill_1`、`magic_weapon`、`wushuang` 等名称。技能槽通过 BattlePlayerOperations.ability_slots 对应真实 GAS 技能 ID；孙悟空普攻由连击配置指定为 `sunwukong_attack1` 至 `sunwukong_attack5`。输入按下调用 `request_attack()` 发动或预约一段，HELD 不自动连击；菜单与失焦撤回预约。运动、二段跳与状态规则见 [阶段四 README](../../addons/battle_foundation/movement/README.md)。

默认主键位参照上古天帝篇 UserVO / ManFrameControl，追加方向键别名和 Shift 奔跑。双击窗口参照 KeyVO 的小于 0.5 秒；当前同方向双击政策与原版跨方向奔跑状态有区别。来源脚本和 SHA-256 见 [source_mapping.json](source_mapping.json)。

完整行为、默认键表、控制权、菜单、角色扩展接口与验收见 [操作控制器 README](../../addons/battle_foundation/input/README.md)。在平台场景按 Esc 修改绑定；默认 K 跳跃、空格无双、H 法宝。
