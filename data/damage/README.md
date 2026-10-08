# 原版伤害定义数据

- [original_levels.json](original_levels.json)：原版220级EXP分母，保留原精度。
- [original_skills.json](original_skills.json)：6411条技能伤害参数；原字段名，空缺参数不擅自当作有效配置。`custom`解析JSON静态`s`区，用于当前通用专属入口；动态等级区需要未来对应角色规则接入。
- [skill_mapping.json](skill_mapping.json)：人类可读普攻ID与来源技能编号映射，不改变业务ID。
- [original_strategy.tres](original_strategy.tres)：业务会话选择的GAS伤害策略，只读配置路径。
- [normal_shield.tres](normal_shield.tres)：100点、8秒普通盾，真实伤害不消耗该盾，按原版流程保留盾后补1。
- [provenance.json](provenance.json)：原始文件哈希、导入数量和精度规则。

完整公式、结算顺序、字段解释、角色扩展和验收见 [阶段8说明](../../addons/battle_foundation/combat/original-damage.md)。
