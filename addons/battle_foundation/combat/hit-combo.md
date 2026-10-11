# 原版战斗连击

`BattleHitComboTracker` 预置于碧玉径的 `BattleSession/HitComboTracker`，`BattleHitComboView` 预置于共享 `HUD/BattleHUD/HitCombo`。角色五段普攻的派生由原 `ComboState` 管理；这里统计角色连续命中的次数，技能、多段攻击和多个目标均通过同一个结算入口增加计数。

## 悟空规则及原版依据

依据反编译 `viewers/container/layers/BattleTopLayer.as::showHitCombox`、`viewers/component/HitCombox.as` 和 `DamageControl.as` 的 `NF_ENTITY_HIT` 路径：

- 命中普通伤害非零时，每个目标的独立结算增加一次。闪避、免疫、普通伤害为零及纯真实附伤不增加；怪物自己的命中不计入玩家。
- 连击刷新后，连续 **1.5 秒战斗时间** 没有新命中则结束并隐藏，下次命中从 1 开始。玩家普通受击不清空连击。暂停和命中停顿冻结计时，慢动作按战斗时钟缩放。
- 单独保存角色最高连击 `get_maximum(entity_id)` 和本关最高连击 `maximum_combo`。结束当前连击不丢失最高记录；角色死亡清理当前连击，离开关卡清理所有记录及归属。
- 宠物或召唤物可通过 `session.hit_combo.set_hit_owner(source_entity_id, owner_entity_id)` 把命中计入主人；注册的角色实例互相独立。

当前接入的是普通悟空的超时规则。原版部分吕岳角色配合被动 `1303110` 使用每1.5秒保留65%连击、最多四轮衰减和红蓝进度条，该专属被动没有加入当前悟空规则。

只订阅 Core 的 `battle.damage.settled`；不同时累计 `battle.attack.hit` 和 `battle.hit.effective`。会话递增的 `damage_id` 用于拒绝重复/旧广播，只保存回调重入导致的尚未闭合序号间隙，外层结算完成立即释放，正常结算不积累命中集合。有效命中回调先结算次生伤害时也不会漏计外层攻击。持续伤害和反伤等次生结算通过 `damage_kind` 排除。

## 原版显示与编辑

[hit_combo.tscn](../../../data/ui/hit_combo.tscn) 使用原 `mission2_20250707_1.swf` AMF3归档内 `hitComboNum0000..0009` 与 `hitCombo0000` 的原像素。在940×590 HUD中位置为 **(640,150)**，四个数字槽从右到左位于 x=144/96/48/0，间距48，文字位于x=192；数字及文字保留原尺寸和注册点。原版普通连击使用静态贴图，不额外增加飘移、缩放或闪烁动画。

这五个 Sprite2D 均为场景预置节点，每次计数变化只更新纹理/可见性，不创建 Tween、AnimationPlayer、Label 或临时实例。超四位时安全显示9999，实际计数和最高记录不截断。可在编辑器调整整个 `HitCombo` 节点的位置；规则的 `Timeout Seconds` 默认保留原版1.5秒。

资源位于 `assets/ui/original/hit_combo/`，`source_mapping.json` 保存源路径、SHA256和每个裁剪框。导出工具为 `tools/export_original_hit_combo.py`，仅使用Python标准库解包及无损裁剪，不依赖Pillow，也不修改原版归档。

`battle.hit_combo.changed` 事件提供 `owner_id/count/maximum/level_maximum`，供后续成就和结算使用。HUD通过 tracker 的 `combo_changed` 信号读取当前玩家结果，不反向修改战斗规则。

## 修复与验证

Godot 的 `set_meta("item", null)` 会移除元数据，而 `get_meta("item", null)` 在缺失键时仍会报错。背包悬停和点击现在先 `has_meta` 再读取，空格子关闭旧提示和菜单。

`tests/suites/verify_hit_combo.tscn` 验证真实GAS伤害、多目标、召唤归属、重复广播、两个角色隔离、1.5秒刷新/超时、暂停/慢动作/停顿、最高记录、死亡/离场，以及已占用格子清空后的连续悬停与点击。GPU画面检查使用 `tools/performance/capture_hit_combo.gd`，截图仅保存在忽略的 `.cleanup-backup`。
