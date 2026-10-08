# 公共战斗表现

伤害跳字、怪物头顶血条、保护条、护盾/免疫文字和通用受击闪光由 `BattleSession/BattlePresentation` 统一管理。角色保存属性、动作、技能与自身动画；表现读取结算结果及目标位置，通过现有 Core 事件总线接入。

## 节点归属与编辑

普通无双的轮廓红光和人物残影绑定角色骨骼，预置于 `AnimationAdapter/WushuangEffect`，由 GAS 状态驱动；公共伤害数字与血条仍由本管理器统一处理。[无双实现、配置与快照池](../../../data/effects/wushuang/README.md)。

```text
BattleSession
├─ BattlePresentation                 预置 battle_presentation_2d.tscn
│  ├─ EntityViews
│  │  ├─ SunWukongFeedback             actor_path 绑定悟空
│  │  ├─ LeftDummyFeedback             actor_path 绑定左木桩
│  │  └─ RightDummyFeedback            actor_path 绑定右木桩
│  │     ├─ HealthBar / HealthLabel
│  │     ├─ ProtectionBar / ProtectionLabel
│  │     ├─ DamageLabel                护盾、免疫等补充反馈
│  │     └─ HitEffect / AnimationPlayer
│  └─ DamageNumbers : CanvasLayer      逻辑视口坐标，layer = 10
│     └─ Rows                         全场共享跳字对象池
└─ Actors
   ├─ SunWukong                       战斗组件与角色动画
   └─ LeftDummy / RightDummy           各自独立的战斗组件
```

打开 [单段攻击场景](../../../examples/single_attack_demo.tscn)、[时间轴场景](../../../examples/skill_timeline_demo.tscn) 或其原版伤害/受击派生场景，在 **BattleSession → BattlePresentation** 调整公共表现。基础关卡已经预置三个目标视图，启动时只绑定目标，不新增表现组件。动态出生目标使用管理器配置的 `feedback_scene` 实例化目标视图，数字按命中从共用池取出。

| 编辑位置 | 配置 |
| --- | --- |
| BattlePresentation | Feedback Scene：通用目标反馈模板；Number Scene：全场共用数字场景 |
| EntityViews / 目标反馈视图 | Actor Path：相对该视图的目标路径；Hit Effect Unit Scale、Bleed Offset：挂点比例及屏幕偏移 |
| EntityViews / 目标反馈视图 | Health Bar Enabled、Always Show Health Bar、Show Player Health Bar、Show Health Values：目标血条策略 |
| EntityViews / 目标反馈视图 / HitEffect | 通用受击特效的帧动画与局部挂点 |
| DamageNumbers / Rows | Max Cached Numbers：空闲缓存上限，默认 6000；Prewarm Count：预热数量，默认 0 |

目标视图跟随角色根的世界变换；血条和受击特效保留原版朝向与挂点规则。数字生成时将目标世界位置转换为逻辑视口位置，后续独立飞行。悟空各技能的攻击特效仍是角色动作时间轴的一部分，编辑入口为 `AnimationAdapter/AttackEffects`。

`actor.feedback` 保留为查询 `session.presentation.get_feedback(actor)` 的兼容接口；返回的视图属于 EntityViews，角色不保存或推进它。新逻辑可直接通过会话的公共入口查询。

## 联合运行与生命周期

1. GAS/Vital 完成伤害结算，战斗系统发布带 `battle_id` 和 `target_entity_id` 的 `battle.attack.hit`。
2. BattlePresentation 每场战斗只订阅一次事件，根据场次和目标分发到对应视图。属性快照更新该目标的血条，视图播放受击闪光，向共享池申请普通、暴击、真实伤害或闪避数字。
3. BattleSession 在所有实体完成本 tick 后，统一推进目标反馈和数字池一次。暂停、受击停顿及慢动作使用同一个 BattleClock delta；引擎普通帧不推进这些动画。
4. 目标离场立即解绑属性/生命信号、隐藏视图；动态视图释放。该目标已经生成的数字继续播放至 0.9 秒结束，并可被其他目标复用。
5. `clear_battle()` 清理本场战斗的视图绑定、活动数字及缓存；场景卸载注销事件订阅并释放节点。不同会话各自拥有独立池、随机流与反馈记录。

每个目标的生命、保护条、显示/隐藏计时、命中计数与受击动画独立。原版数字贴图、Tween 曲线、分类、表现随机流和逐次命中显示保持一致；所有目标共享缓存上限与活动数组，避免重复的逐角色数字推进。

## 新场景与新角色

使用 [battle_session.tscn](../runtime/battle_session.tscn) 创建会话，或在现有 BattleSession 下实例化 [battle_presentation_2d.tscn](battle_presentation_2d.tscn)。`BattleSystem.create_session()` 同样实例化这个预置会话场景。

静态关卡可以在 `EntityViews` 下预置 [combat_feedback_2d.tscn](combat_feedback_2d.tscn)，把 Actor Path 指向目标。例如本项目的视图路径为 `../../../Actors/SunWukong`；角色 ready 后由管理器绑定。动态生成的角色自动登记目标视图。新角色继续使用公共反馈模板与数字池，无需在角色树中追加公共表现节点。

## 验收

[verify_battle_presentation.tscn](../../../examples/verify_battle_presentation.tscn) 覆盖启动节点数不变、角色树无公共反馈、多个目标共享池、每 tick 一次、移动与屏幕坐标、暂停/停顿/慢动作、跨会话隔离、目标释放后数字完成、跨目标复用与场景清理。原版跳字、数字池、血条、原版伤害、受击及攻击样例继续使用既有验收验证原行为。
