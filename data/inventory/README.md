# 原版物品定义与角色背包

人物比例、编号滑出、原版动态光效、抗性悬浮、装备对比和点击菜单的修正与编辑入口见 [背包面板细节](panel-details.md)。后续报错修复已实际运行背包交互回归和关卡启动检查。

物品定义保存在业务目录，角色预置 `Inventory` 节点使用 `OriginalInventory`。角色 Initial Items 填 [110101001.tres](110101001.tres)、[110101002.tres](110101002.tres)、[110101003.tres](110101003.tres)；Original Rules 填 [original_rules.json](original_rules.json)。定义不保存本次游戏的数量、锁定或装备变化；插件入库时复制成独立运行实例。

三件装备分别为封煞甲、封戾冠和封魔棒，ID 保留原物品索引，角色和技能继续使用项目的语义 ID。`original_data` 保存完整原 Equipment 记录；起始预置装备使用原区间最小值，阶段14掉落与允许洗练的装备使用原区间随机生成独立实例，已接入强化成本、词条/附加属性、套装与灵魂/经验奖励。[阶段14配置与运行说明](../loot/README.md)。

## 新增装备

1. 复制现有 `BattleInventoryEquipment` 资源，修改 Item ID、Name、Description、Icon 与 Original Data。原数据至少填写 type、part、quality、price、isSell、userLevel、roleConditions、isCanChangeInBattle。
2. Battle Definition 使用 `BattleEquipmentDefinition`，设置唯一 definition_id 和 slot_id。Attribute Modifiers 使用 GAS 的 GameplayAttributeModifier；原属性 ID 如 hpMax、mpMax、atk、phyDef、critical，不要直接修改角色最终值或当前生命。
3. Appearance Skin 填角色已有皮肤，例如 `武器/weapon1`、`头盔/helmet1`、`衣服/armor1`；留空使用基础外观。不存在的皮肤不替换当前外观，新角色应提供自己的动画适配器皮肤映射。
4. 将定义添加到角色 Inventory 的 Initial Items，或奖励逻辑调用 `inventory.add_item(definition)`。界面和属性通过 item_changed/equip_changed 自动刷新。卸下由同一入口撤销加成。

普通装备 part 支持 wing、weapon、helmet、amulet、armor、ornament；幻装支持 fashionWeapon、fashionHelmet、fashionArmor、fairy，另外保留 title 槽。基础 UI 展示普通六位及可切换的幻装位；标题系统和复杂装备特效尚未接入。

## 恢复道具与扩容

使用普通 Item，设置分类、max_stack 与 quantity，original_data 的 isUse=1；attributeT1..3 为 hp/mp、attributeV1..3 为恢复整数，可经 Vital 恢复生命/魔法。材料进入普通道具页，消耗品进入消耗品页，type=fashion 进入时装页。使用结果不生效时不会扣数量；复杂原道具效果需要接入对应 GAS Effect 或服务模块。

扩容规则来自原 OpenPack，四类分别使用 packType1..4。插件按目标格数累计成本，默认仙织革 ID101018001；不是无条件改容量。每类最大500格、每页25格，出售折扣0.2也来自原 Common。运行数据目前保存在本地会话，没有新增跨会话存档。

背包布局、原源码依据、已实现范围和验证入口见 [战斗 UI 说明](../ui/README.md)。
