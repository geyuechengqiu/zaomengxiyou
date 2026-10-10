# 悟空普通无双：红光与残影

打开 [五技能演示](../../../tests/fixtures/wukong_skills_demo.tscn) 按 F6，或按 F5 运行第一关；通过战斗命中获取无双值，满10000后按空格释放，Esc菜单可改键。持续15秒，期间按上限/15×战斗delta消耗且不再获取；重复按下不刷新。释放时保留正在进行的攻击与技能；地面受击硬直按原 `onStiffComplete` 解除，眩晕由控制状态裁决。

## 战斗获取、增益与UI

[combat_rules.json](combat_rules.json) 保存原Common/Skill/Buff值及源码入口。原技能ID仅用于追溯，业务仍使用 `孙悟空/sunwukong_attack1` 等名称。

| 动作 | 每次有效命中获取 | 同次释放上限 |
| --- | ---: | ---: |
| 普攻1 / 2 / 3 / 4 / 5 | 111 / 111 / 133 / 50 / 222 | 111 / 111 / 133 / 200 / 222 |
| 跑攻 / 跳攻 | 133 / 144 | 133 / 144 |
| 升龙斩 / 烈焰闪 | 533 / 666 | 533 / 666 |
| 火眼金睛 / 烈焰风暴 / 火魔斩 | 186 / 133 / 222 | 932 / 666 / 1332 |
| 风暴重劈 / 火魔斩重劈 | 666 / 666 | 666 / 666 |

获取从统一 `resolve_attack_hit` 进入，闪避和打空不获取；护盾挡住扣血的有效命中仍可获取。上限跨攻击段和目标共享，`rage_awarded` 属于本次 `BattleAttackInstance`，取消与下次释放不会污染共用技能定义。DOT和反伤的扣血不会被重新算成一次普攻。`xpRatio`通过现有伤害规则来源修正获取量，使用无双期间忽略获取。

受击入口严格沿用此仓库的 `checkHurtManData/calXP`：只有该命中的攻击技能还有怒气预算才执行calXP；按角色曾越过的最低整数生命百分比记录，不因治疗重复领取。同份源码的calXP内部updateXP一次，调用者对返回值再updateXP一次，所以每个新越过的百分比获得 `Common.hpToXP(5)×2`。当前第一关怪物技能addXP/addXPMax均为0，该分支不会凭空给玩家受击怒气。保留这份源码行为，未改成“所有受击都加怒”。死亡与退出清零。

| 原版Buff | 时长 | 实现 |
| --- | --- | --- |
| 6000601 | 1秒 | 起手霸体，仅限制普通受击打断，不等于无敌 |
| 21000101 | 15秒 | 行走/奔跑速度+30%，GAS乘法修正与减速等来源相加 |
| 23000101 | 15秒 | atkDmgRate+30，进入原版增减伤步骤；有目标减伤时按原公式计算 |
| 8000201 | 15秒 | 增加“释放时最终暴击属性×0.2+72”，按原type8快照；不是直接+20%暴击率 |

暴击率仍按等级分母、敌人韧性及原版流程计算。Buff到期、手动移除、死亡或离场均从原来源撤销；普通无双未增加魔法恢复、回血或整段无敌。

满值UI使用mission中mcXPA的15帧火焰741和6帧空格提示849，30FPS循环；两个AnimationPlayer均预置且可在编辑器检查。未满/使用时回到710空盘。原关卡ID≤3显示空格引导，Core改键后显示实际键名。怒气遮罩位于右锚点208，负向矩形伸向左侧，TextureProgressBar用RIGHT_TO_LEFT；填充渐变与圆盘图片不镜像。涨值与扣减都按原1秒Quad.easeOut重定向，UI独立时间在暂停时仍会完成已开始的缓动；战斗怒气及Buff暂停/停顿/慢动作统一受BattleClock控制。

[实际满值画面](../../../addons/battle_foundation/docs/wushuang-full-ui.png) 与 [使用中画面](../../../addons/battle_foundation/docs/wushuang-active-ui.png)。

## 原版依据

本地 `Speculum-4399-master` 的 `ManEntity.createWuShuanEffect/createWuShuanEffect2`、`WuShuanImage`、自定义 `Tween`、`Role.json` 和 `UserVO` 提供原始规则，文件路径及 SHA-256 见 [original_source.json](original_source.json)。

| 参数 | 原版与当前实现 |
| --- | --- |
| 悟空颜色 | Role 2001 的 `xpColor=0xFF3000`；业务角色仍叫 `孙悟空` |
| 辉光 | `GlowFilter(color,1,width,width,1,2)`；30 FPS下 step 从0递增到30，再递减到-1，width 为 `10+step`，每62源帧循环 |
| 残影采样 | 每0.2秒；当时人物姿态、皮肤、武器、朝向和世界位置冻结 |
| 原始快照 | 默认240×240，脚底注册点(120,180) |
| 残影消散 | 1秒，原版自定义 Tween 为 alpha 1→0 的线性插值 |
| 时长 | UserVO 默认15秒，可被配置覆盖；当前 GAS 状态 Duration 为15 |
| 显示比例 | 在原素材坐标捕获，再以角色 display_scale（悟空2）显示；镜头0.5还原屏幕尺寸 |

Flash 的 GlowFilter 由 Godot shader 的5×5 Gaussian采样近似，颜色、脉动步进和残影时序按原版保留，不宣称两个渲染器逐像素相同。原版截图对象是整个 GameObject；当前快照包含人物身体、套装、武器与程序化头部姿态，攻击特效仍由自己的时间轴播放，未复制独立特效节点。

## 实现与生命周期

`CoreOperationController → BattlePlayerOperations → Core动作机 → sunwukong_wushuang → BattleWushuangActivationFeature → BattleWushuangController → GAS rage Vital / normal_wushuang_visual → BattleWushuangEffect2D`。

角色的 [AnimationAdapter](../../animation/sunwukong_visual.tscn) 已预置 [WushuangEffect场景](sunwukong_wushuang.tscn)：一个实时红光捕获视口，以及六组 `Sprite2D/Capture/Body` 残影槽。身体前面的静态节点顺序让红光与残影在人物后、地形前绘制，避免负层级被背景遮挡。复用时调整已有槽的绘制顺序，最新残影盖住旧残影，保留原版序号递增的层序语义。六个槽循环复用，默认最多五个存活残影；不在启动或采样时添加节点、创建 Tween，也不做生产环境的 CPU 图片回读。

[BattleSpinePoseMirror2D](../../../addons/battle_foundation/animation/spine_pose_mirror_2d.gd) 共用只读骨架与图集，独占姿态及复合皮肤。捕获已解算骨骼世界变换、槽位附件、颜色和 deform，保留原动画 drawOrder；换装不会释放仍被旧残影使用的独立皮肤。SubViewport 只在捕获时 `UPDATE_ONCE`；旧残影的纹理和骨骼不继续刷新。

[BattleWushuangEffect2D](../../../addons/battle_foundation/presentation/battle_wushuang_effect_2d.gd) 在角色每次战斗更新完成后接收一次 combat delta。暂停、受击停顿冻结生成和消散；慢动作统一影响持续时间、脉动和透明度。自然结束立即撤销红光，已有残影继续消散；死亡和离场立即清空。低帧率补算未过期样本的年龄和世界位置，过期样本跳过；同一大 delta 内多个样本使用本次已解算姿态，不重建历史子帧姿态。

实时红光用320×320捕获，提供模糊边缘余量；残影仍采用原版240×240，超出区域的附件可能裁切。运行成本有界，但视口与模糊着色仍有 GPU 成本，不能据此保证任意数量角色的性能。

## 调整与新增角色

- 角色 `AnimationAdapter/WushuangEffect`：`Glow Color`、`Spawn Interval`、`Ghost Lifetime`、`Source FPS`、`Glow Base Width`、`Glow Maximum Step`。
- [无双状态](../../buffs/normal_wushuang_visual.tres)：`Duration` 与三个原版GAS效果；控制器依据同一Duration计算消耗。
- [无双技能](../../skills/sunwukong/wushuang.tres)：表现状态引用；角色 `ability_slots.wushuang` 绑定语义技能 ID。
- 改采样间隔或寿命时，手动增减预置残影槽，至少 `ceil(寿命/间隔)+1`；运行时会检查槽数。
- 新角色复制无双场景，替换七个 Body 的 Spine 数据资源，设置其 `xpColor` 和角色比例，保留脚底对齐、独立皮肤和静态节点结构。将状态、技能加入所用 manifest，再绑定角色无双槽。

当前释放入口复用GAS无动作状态技能，不占用攻击实例；角色预置 WushuangController，技能资格判断、怒气消耗、Buff清理与角色视觉分别管理。新增角色在属性集加入xpMax，实体定义加入rage Vital，场景预置控制器并装配对应无双技能/表现资源；原技能获取表位于combat_rules.json。

## 验证

[自动验收](../../../tests/suites/verify_wushuang.gd) 覆盖真实输入和改键、攻击中激活、姿态/换装/朝向冻结、固定池、实例隔离、低帧率、暂停/慢动作/停顿、30源帧辉光边界、到期/死亡/离场清理。

```powershell
& '<带 Spine 模块的 Godot.exe>' --headless --path . res://tests/suites/verify_wushuang.tscn
& '<带 Spine 模块的 Godot.exe>' --path . --script res://tools/capture_wushuang.gd
```

第二条使用真实 GPU 渲染比较无双开/关后的画面，验证红光和残影确实出现在场景里，并保存双向奔跑及攻击图片到忽略目录 `.cleanup-backup`。CPU回读仅用于该验收工具。回归入口见 [verify_stage_eight.ps1](../../../tools/verify_stage_eight.ps1)。

原配置表可用 `py -3.12 tools/import_original_wushuang_rules.py <Speculum仓库路径>` 重新导出；UI素材用 `import_original_battle_ui.py` 和 `build_original_ui_scenes.py` 离线生成。运行时不读取原SWF或XML。
