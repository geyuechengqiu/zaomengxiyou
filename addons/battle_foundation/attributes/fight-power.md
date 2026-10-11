# 原版战力

角色战力使用原 `PowerAttribute[1]` 和 `FightPowerManager.getFightPowerByItemVo` 的十二项权重。参考离线原版通过本地服务端 `backends/zmhj_api.py._calculate_power` 返回属性加权值，一级裸装悟空显示987，并未另加职业修正。原配置保留的 `Role[2001].powerCorrection = 190` 及 `BodyView.updateFight` 的悬浮解释不能证明服务端给总战力加了190。项目保留可选修正入口和原配置记录，悟空默认修正为0，与参考游戏一致。

```text
总战力 = Math.round(
    最大生命 × 1 + 最大魔法 × 2 + 攻击 × 12 + 防御 × 40
  + 命中 × 4 + 闪避 × 6 + 暴击 × 6 + 韧性 × 4
  + 幸运 × 6 + 守护 × 4 + 回血 × 180 + 回魔 × 360
)
```

评分直接参与加权，不转换为等级相关的概率。当前生命/魔法、经验、抗性和移动参数不作为直接战力项；等级通过原成长属性参与，装备的强化、随机词条和套装通过已生效的装备属性参与。只读取基础、`growth.*` 和 `equipment.*` 来源；持续加攻、无双等临时战斗Buff不改变长期战力。

原成长属性保留小数参与权重计算，最终再按 `floor(sum + 0.5)` 取整数。战斗面板仍显示整数。一级原版裸装悟空为 **987**；二级使用330生命、120魔法、31.25攻击、6.05防御，战力为 **1187**，不能先把攻击、防御取成31、6再加权，否则会误算为1182。81级原版裸装样例为16987。

原封煞甲34生命、2防御贡献114战力，原封魔棒6攻击、3暴击评分贡献90战力。穿脱装备和修改词条均实时重算，卸下后加成清空。此前场景误设回魔100，多出36000战力，已恢复原0；此前误加的190也已撤销。场景 `Base Values` 的自定义值仍参与计算，987对应一级裸装初始属性，不会强制覆盖编辑值。

## 配置与接入

- [fight_power_rules.tres](../../../data/attribute/fight_power_rules.tres) 引用原权重配置 [fight_power_weights.json](../../../data/ui/fight_power_weights.json)。配置保存原始归档和公式文件的SHA256、原角色属性、成长及修正值；通过 `tools/export_original_fight_power.py <Speculum根目录>` 重新读取源归档。
- 在角色 `BattleEntityDefinition` 中设置 `Fight Power Rules` 和 `Fight Power Correction`。悟空和通用角色模板使用原规则、修正默认0；明确移植服务端职业平衡修正时才启用，不把原Role字段自动相加。
- `BattleAttributeComponent.get_fight_power()` 返回总战力，`get_fight_power_breakdown()` 提供各项原始属性、权重贡献、属性战力和修正值；统一属性快照包含 `fightPower`。
- 背包只读取快照，不再用临时最终属性另算战力。基础小数变化或装备被临时覆盖时，即使整数最终属性不变，也会通过属性事务发出快照并刷新战力。

原联网背包使用 `scene.characterHandler.getPower` 的服务端结果。当前匹配参考离线服务端，只根据已移植的长期属性加权；未引入的账户成长系统没有额外加分。

验证入口：`tests/suites/verify_fight_power.tscn`。先检查未经测试覆写的真实开局回魔0、战力987，再覆盖成长、装备、Buff、取整、通知与实例隔离。
