# 原版保护数据

[original_protection.json](original_protection.json) 由本地客户端导出的 Boss 与技能表转换，不用统一常数替代 Boss 配置。含 1308 条 Boss、6411 条完整 Skill 记录、项目五连击能力 ID → 原技能 ID 映射及三个来源文件的 SHA256。

来源为 [机制说明](D:/UserData/Downloads/game/Speculum-4399-master/exports/zmhj_protection/机制说明.md)、同目录 Boss保护条满值.json、全部技能保护值.json。原版代码入口为 BattleModelManager.calProtectPoint、ManEntity.CheckProtect、BossBleed 进度显示和 DamageControl 伤害流程。原导出目录只读，不在本项目中修改。

| 配置键 | Boss | 基础满值 | 原版显示 |
| --- | --- | --- | --- |
| Monster/10001 | 东皇太一 | 25000 | true |
| Monster/11103 | 商羊 | 35000 | true |
| ChapterRole/209000001 | 九天玄女 | 50000 | false |

基础满值与技能的 protectPointMax 是不同概念：前者是触发阈值，后者是一次命中递增值的上限。Max 为 null/0 表示未设限。

重新导入，在项目根目录执行：

```powershell
node tools/export_original_protection.mjs 'D:/UserData/Downloads/game/Speculum-4399-master/exports/zmhj_protection'
```

输出路径固定为本项目 data/protection/original_protection.json；只改导入数据，不改场景资源或用户设置。脚本保留整数、空 Max、Boss 表名，生成来源哈希便于追溯。

运行读取由 [BattleProtectionSystem](../../addons/battle_foundation/combat/battle_protection_system.gd) 完成，当前条/累计次数存放在每实体独立系统中。永久编辑满值请修改目标 BattleProtectionProfile.maximum_override；不要改运行中的 JSON 或将所有 Boss 改成同一数值。公式、模式、计数合并及保护动作边界见 [阶段9说明](../../addons/battle_foundation/combat/hit-reaction-protection.md)。
