# 阶段7三段技能验收数据

[manifest.json](manifest.json) 独立登记孙悟空、三段技能、可派生普攻、两只同配置木桩和属性验收Buff。所有实体、组件、输入和临时效果已在 [场景](../../../tests/fixtures/skill_timeline_demo.tscn) 中搭建。

在 [three_hit.tres](three_hit.tres) 编辑 Timeline → Attack Segments / Branch Windows / Motion Windows / Events，角色仅有一个攻击框。三段分别在30FPS的第4/12/20帧生效，倍率0.5/1/1.5，附伤0/3/5，击退60/120/180，末段浮空220；资源消耗和冷却复用现有 GAS Feature。全部是测试配置，原版五连击资源保持原有数值。

J 释放，Y 技能槽1，后摇再次J派生普攻，Esc菜单。详细字段、运行语义、类图、生命周期和验收见 [阶段7文档](../../../addons/battle_foundation/combat/skill-timeline.md)。构建工具仅用于离线重建此目录和场景，会覆盖编辑结果。
