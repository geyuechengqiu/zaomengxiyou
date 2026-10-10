# 伤害跳字高并发性能

2026-10-08 使用项目实际 `damage_number.tscn`、原版14组数字贴图、CombatFeedback生成入口和GPU渲染测试。原实现每次命中实例化/释放节点、创建4个属性Tweener与一个间隔；独立PNG导致大量纹理切换。已改为共享图集、节点复用和直接采样相同的Tween曲线。

公共表现迁移后，所有目标共用 `BattleSession/BattlePresentation/DamageNumbers/Rows` 的有界缓存与活动数组，BattleSession 每个 tick 统一推进一次，单个目标离场不会打断已经发出的数字。原版图集、0.9 秒 Tween 曲线与逐次命中显示保持一致。[公共管理器配置](../../addons/battle_foundation/presentation/README.md)。以下 GPU 数据为迁移前对象池重构的基准，并非本次迁移重新测量。

## 测试条件与结果

Godot 4.7.2 自定义Spine构建，Ryzen 9 8940HX，RTX 5060 Laptop GPU，D3D12 Forward+，940×590视口，关闭垂直同步和帧率上限。测试场景继承伤害样例，禁用玩家操作和自动战斗推进，保留原场景的角色、地图、反馈绘制。混合11种样式与1～5位数字，每轮48帧；不包含大量怪物AI、弹道或完整战斗逻辑。

表中的更新与渲染阶段从更新开始到 `frame_post_draw`；完整帧另计到下一次 `process_frame`。旧基准没有记录完整帧，所以不能把阶段耗时直接换算成整场游戏FPS。生成耗时单独列出，不包括在后续稳定显示帧中。P95表示95%的样本低于该值，不代表最坏帧。

| 同时显示数量 | 再次生成ms：旧→新 | 整个场景绘制调用：旧→新 | 更新与渲染P95 ms：旧→新 | 新完整帧P95 ms |
| --- | --- | --- | --- | --- |
| 100 | 2.08 → 0.70 | 488 → 78 | 1.32 → 1.61 | 1.70 |
| 500 | 9.24 → 3.23 | 2168 → 78 | 2.94 → 2.57 | 2.60 |
| 1000 | 18.51 → 6.41 | 4225 → 78 | 5.34 → 3.45 | 3.49 |
| 2000 | 43.76 → 13.73 | 8377 → 78 | 10.99 → 7.61 | 7.65 |
| 5000 | 101.97 → 33.19 | 20766 → 79 | 27.90 → 17.79 | 17.88 |

“再次生成”测量同一规模第二轮，新的对象池已热；原实现每轮仍需重新实例化。首轮从100逐步扩大到5000，新增规模之外已有缓存，不能把其内存增量当作完整5000条的总内存。

| 持续负载 | 新实际可见峰值 | 旧阶段P95 ms | 新阶段P95 ms | 新完整帧P95 ms |
| --- | --- | --- | --- | --- |
| 每秒1200条，240帧 | 1060 | 8.41 | 4.49 | 4.53 |
| 每秒3600条，240帧 | 3180 | 21.77 | 12.49 | 12.59 |

持续测试每帧分别生成20/60条，并以1/60战斗秒推进；“每秒”指战斗模拟秒，未用墙钟限帧。旧计数含当前帧已隐藏、等待释放的节点，新计数只含有效实例；生成速率和0.9秒寿命一致。

当前约3180条同时显示的压力样例完整帧P95为12.59ms，低于60FPS的16.67ms预算。5000条稳定显示P95约17.88ms、热池单帧生成约33.19ms，仍超出预算；不能保证无限数量或5000条同帧骤增不卡顿。后续完整战斗还会消耗帧预算，应在目标设备复测。没有通过减少数字数量、合并命中、缩短动画或降低更新频率隐藏开销。

原始数据：[重构前](../../addons/battle_foundation/docs/damage-number-stress-baseline.json)、[当前](../../addons/battle_foundation/docs/damage-number-stress-current.json)。

## 重构实现

- [图集工具](../../tools/build_damage_number_atlas.py) 将115个别名对应的95张独立图合并为1024×162图集；全尺寸、透明边距和原排版不变，每个区域与PNG逐字节比较。图集边缘扩展与 `filter_clip` 防止串色，全部别名继续保留。导出原版素材时自动重建图集。
- [跳字容器](../../addons/battle_foundation/presentation/battle_damage_number_layer_2d.gd) 管理有界空闲池与紧凑活动数组。到期隐藏并回收，超出空闲上限释放；缓存节点不参与动画推进，也不绘制。倒序更新与交换删除避免复制子节点列表及逐条删除数组元素。
- [动画脚本](../../addons/battle_foundation/presentation/battle_damage_number_2d.gd) 使用 `Tween.interpolate_value` 直接采样原Quad.easeOut，消除每条命中的Tween/Tweener分配。不按SceneTree时间推进，只接收BattleClock的delta；停顿、暂停和慢动作保持一致。停留段不反复写相同属性，后半段不重复写固定缩放。
- 复用前重置数值、样式、出生点、时间、缩放、旋转、透明度及完成标记。按新的出生序号设置Canvas绘制顺序；树新增/删除后在绘制前恢复顺序，旧节点复用仍覆盖较早数字。
- 更换跳字PackedScene时清理旧缓存，旧活动实例完成后释放，不进入新场景的池。卸载反馈场景会释放活动节点和缓存。

这仍是原版Tween动画曲线，不加入AnimationPlayer节点或预览。参考 [Tween插值API](https://docs.godotengine.org/en/stable/classes/class_tween.html#class-tween-method-interpolate-value)、[AtlasTexture](https://docs.godotengine.org/en/stable/classes/class_atlastexture.html)。

## 编辑与预热

在 [combat_feedback_2d.tscn](../../addons/battle_foundation/presentation/combat_feedback_2d.tscn) 选中 `DamageNumbers/Rows`：

| 配置/API | 用途 |
| --- | --- |
| `prewarm_count`，默认0 | 可在加载阶段初始化预计峰值数量，提前完成实例化、入树和ready；默认0保持测试场景启动时的预置节点结构 |
| `max_cached_numbers`，默认6000 | 每个反馈层的空闲缓存上限，不限制显示中的数量；根据内存预算下调 |
| `prewarm(number_scene, count)` | 在关卡加载或过场时预热，避免第一次大量命中的分配峰值；不要在攻击窗口内调用 |
| `get_active_count()` / `get_active_numbers()` | 查询可见有效跳字；后者按出生顺序返回副本，用于面板/调试，避免在每帧热路径调用 |
| `get_pool_stats()` | 返回active/cached/created/reused/limit，检查是否反复分配与缓存规模 |
| `clear_numbers()` | 同时清理活动与缓存，例如切换战斗 |

空闲池以峰值分配量换取后续稳定性，不会自动缩回最小容量。预热只能减少首次分配开销，不能消除单帧生成几千条时的排版与绘制命令建立开销。不要用容器子节点数代表当前跳字数量，隐藏缓存仍是子节点。

## 动画与生命周期验证

[对象池回归](../../tests/suites/verify_damage_number_pool.tscn) 144项，配合原跳字78项、原版反馈36项、单段攻击64项、伤害计算90项、技能时间轴117项和木桩37项，共666项。覆盖独立时钟、暂停、低帧率跨段、复用重置、500条突发、缓存上限、代际切换、卸载、共享图集、八种伤害样例与左右五连击。

非30FPS采样点逐项验证原位置、缩放、透明度，0.9秒寿命与原版随机规则不变。GPU额外验证复用和新节点混合时的重叠顺序。100条混合样式冷/热池截图完全一致；对比重构前截图，940×590中723个边缘像素有差异，RGB通道最大差5/255，来自图集采样与浮点插值；不宣称GPU输出逐像素相同，源贴图逐像素一致。

```powershell
& ./tools/verify_stage_eight.ps1 -Godot '<支持Spine的Godot>' -Suites damage_number_pool,damage_numbers,original_feedback,single_attack,original_damage,skill_timeline,wooden_dummy
& '<支持Spine的Godot>' --path . --max-fps 0 res://tools/benchmark_damage_numbers.tscn -- --report-name=current
& '<支持Spine的Godot>' --headless --path . res://tools/benchmark_feedback_animation.tscn
```

GPU基准将报告和冷/热截图写到 `.cleanup-backup/damage-number-stress-current.*`。最后一条是当前真实跳字的CPU微基准，不包含GPU绘制，不应当作FPS测试。
