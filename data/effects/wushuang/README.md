# 悟空普通无双：红光与残影

打开 [五技能演示](../../../examples/wukong_skills_demo.tscn) 按 F6，或按 F5 运行第一关；空格触发普通无双表现，Esc 菜单可改键。当前直接施加15秒表现状态，重复按下不刷新。尚未接入原版怒气蓄满条件、消耗条和无双属性加成。本次实现角色视觉，释放时不替换正在进行的攻击、不改变攻击或跳跃许可。

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

`CoreOperationController → BattlePlayerOperations → Core动作机 → sunwukong_wushuang → BattleStatusActivationFeature → GAS normal_wushuang_visual → BattleWushuangEffect2D`。

角色的 [AnimationAdapter](../../animation/sunwukong_visual.tscn) 已预置 [WushuangEffect场景](sunwukong_wushuang.tscn)：一个实时红光捕获视口，以及六组 `Sprite2D/Capture/Body` 残影槽。身体前面的静态节点顺序让红光与残影在人物后、地形前绘制，避免负层级被背景遮挡。复用时调整已有槽的绘制顺序，最新残影盖住旧残影，保留原版序号递增的层序语义。六个槽循环复用，默认最多五个存活残影；不在启动或采样时添加节点、创建 Tween，也不做生产环境的 CPU 图片回读。

[BattleSpinePoseMirror2D](../../../addons/battle_foundation/animation/spine_pose_mirror_2d.gd) 共用只读骨架与图集，独占姿态及复合皮肤。捕获已解算骨骼世界变换、槽位附件、颜色和 deform，保留原动画 drawOrder；换装不会释放仍被旧残影使用的独立皮肤。SubViewport 只在捕获时 `UPDATE_ONCE`；旧残影的纹理和骨骼不继续刷新。

[BattleWushuangEffect2D](../../../addons/battle_foundation/presentation/battle_wushuang_effect_2d.gd) 在角色每次战斗更新完成后接收一次 combat delta。暂停、受击停顿冻结生成和消散；慢动作统一影响持续时间、脉动和透明度。自然结束立即撤销红光，已有残影继续消散；死亡和离场立即清空。低帧率补算未过期样本的年龄和世界位置，过期样本跳过；同一大 delta 内多个样本使用本次已解算姿态，不重建历史子帧姿态。

实时红光用320×320捕获，提供模糊边缘余量；残影仍采用原版240×240，超出区域的附件可能裁切。运行成本有界，但视口与模糊着色仍有 GPU 成本，不能据此保证任意数量角色的性能。

## 调整与新增角色

- 角色 `AnimationAdapter/WushuangEffect`：`Glow Color`、`Spawn Interval`、`Ghost Lifetime`、`Source FPS`、`Glow Base Width`、`Glow Maximum Step`。
- [表现状态](../../buffs/normal_wushuang_visual.tres)：`Duration`；持续时间由 GAS 管理。
- [无双技能](../../skills/sunwukong/wushuang.tres)：表现状态引用；角色 `ability_slots.wushuang` 绑定语义技能 ID。
- 改采样间隔或寿命时，手动增减预置残影槽，至少 `ceil(寿命/间隔)+1`；运行时会检查槽数。
- 新角色复制无双场景，替换七个 Body 的 Spine 数据资源，设置其 `xpColor` 和角色比例，保留脚底对齐、独立皮肤和静态节点结构。将状态、技能加入所用 manifest，再绑定角色无双槽。

当前预览入口复用 GAS，不占用攻击实例。将来接入怒气系统时，在无双技能增加怒气资格与消耗，并装配原版 Buff；红光和残影仍监听同一个状态，无需修改角色攻击代码。

## 验证

[自动验收](../../../examples/verify_wushuang.gd) 覆盖真实输入和改键、攻击中激活、姿态/换装/朝向冻结、固定池、实例隔离、低帧率、暂停/慢动作/停顿、30源帧辉光边界、到期/死亡/离场清理。

```powershell
& '<带 Spine 模块的 Godot.exe>' --headless --path . res://examples/verify_wushuang.tscn
& '<带 Spine 模块的 Godot.exe>' --path . --script res://tools/capture_wushuang.gd
```

第二条使用真实 GPU 渲染比较无双开/关后的画面，验证红光和残影确实出现在场景里，并保存双向奔跑及攻击图片到忽略目录 `.cleanup-backup`。CPU回读仅用于该验收工具。回归入口见 [verify_stage_eight.ps1](../../../tools/verify_stage_eight.ps1)。
