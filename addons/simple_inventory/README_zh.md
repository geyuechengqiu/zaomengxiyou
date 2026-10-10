# GodotGear

本项目增加 `OriginalInventory extends C_Inventory`，用于复刻上古天地篇四类独立容量、25格分页、品质排序、锁定出售、原消耗扩容和原子换装。角色场景直接预置该节点；物品定义与带UID的实例状态分开，数量、强化和词条不污染共享资源。`equipment_changed` 统一通知现有GAS属性入口，`appearance_changed` 通知角色皮肤；旧 `equip_changed` 保留兼容。阶段14已加入原成本强化/洗练、套装门槛、地面拾取、灵魂和经验奖励。[物品配置](../../data/inventory/README.md)、[成长与掉落配置](../../data/loot/README.md)、[原版 UI、规则与范围](../../data/ui/README.md)。OriginalInventory 的恢复道具/角色条件桥接使用 Battle Foundation；通用 C_Inventory 不依赖该桥接。

一个轻量级、灵活的 Godot 4.x 背包系统插件

![Godot v4.x](https://img.shields.io/badge/Godot-v4.x-blue)
![MIT License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-0.0.1-orange)

[English](README.md) | 简体中文

## 概述

GodotGear 是一个为 Godot 4.x 开发的用户友好的背包系统插件，为游戏中的物品、装备和背包管理提供了坚实的基础。它的设计既简单易用，又足够灵活，可以适应各种不同类型的游戏。

## 特性

- 🎮 简单易用的背包组件系统
- 📦 灵活的物品管理
- ⚔️ 内置装备系统
- 🎨 可自定义的UI组件
- 🔌 基于插件架构，易于集成
- 📚 完善的API文档
- 🛠️ MIT许可证 - 可自由用于个人和商业项目

## 快速开始

1. 将 `addons/simple_inventory` 文件夹复制到你的 Godot 项目的 `addons` 目录中
2. 在项目设置中启用插件（Project Settings -> Plugins）
3. 将 `C_Inventory` 组件添加到场景中的任意节点
4. 开始使用背包系统！

## 基本用法

```gdscript
# 添加背包组件到节点
@onready var inventory = $C_Inventory

# 创建并添加物品
var item = Item.new()
inventory.add_item(item)

# 移除物品
inventory.remove_item(0)  # 移除槽位0的物品
```

## 文档

### 造梦西游原版背包适配

`OriginalInventory` 在通用组件之上管理四类背包、独占物品实例、装备交换与事务验证。面板通过 `get_context_actions` 读取菜单规则，通过 `get_comparison_item` 查找同部位装备。`OriginalItemPresenter` 整理原品质、类型、强化名称、GAS装备数值、孔位与售价，并提供原版抗性解释公式。数据与界面节点分开，面板不直接修改物品或最终属性。

业务角色在预置 `Inventory` 填写 `Display Name`、`Player Number`、`Presentation Rules`。`operation_completed` 与 `operation_rejected` 接公共提示；`wardrobe_requested` 接独立衣柜模块；`set_show_fashion` 通过 `appearance_changed` 同步外观，保留装备属性。配置和源码依据见 [背包面板细节](../../data/inventory/panel-details.md)。

详细文档和示例请访问我们的 [Wiki](https://github.com/Liweimin0512/GodotGear/wiki) *（即将推出）*

## 贡献

欢迎贡献！你可以：

- 报告问题
- 提出新功能建议
- 提交代码
- 改进文档

## 许可证

本项目采用双重许可：

1. **源代码**：源代码采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

2. **素材资源**：所有素材资源（包括但不限于 `assets` 目录中的图片、音效和其他媒体文件）**不**适用于 MIT 许可证。这些资源的所有权利均由其各自的所有者保留。未经版权所有者的明确许可，你不得使用、复制、修改、合并、发布、分发、再许可或销售这些资源。

## 致谢

由 old_lee 创建和维护

---

为 Godot 社区用 ❤️ 制作
