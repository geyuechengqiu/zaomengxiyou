# 悟空造型训练木桩

木桩是参考项目孙悟空外观重绘的原创 SVG：大头猴脸、棕帽金箍、黄色护衣、红腰带和背棍；木纹、腹部靶心及固定底座保留训练目标的辨识度。它不是从原版导出的角色素材，受伤摇摆也不是原版逐帧动画。原版受击闪光和数字跳字仍由现有 CombatFeedback 独立播放。

## 资源与编辑

| 文件 | 用途 |
| --- | --- |
| [wooden_dummy.svg](wooden_dummy.svg) | 完整外观，100×180，可使用矢量编辑器修改 |
| [wooden_dummy_hurt_face.svg](wooden_dummy_hurt_face.svg) | 受伤五官覆盖层，与本体使用相同画布和注册点 |
| [wooden_dummy.tscn](wooden_dummy.tscn) | 预置身体、底座、表情与 AnimationPlayer 的角色场景 |
| [wooden_dummy.tres](wooden_dummy.tres) | 实体定义，继续复用 GAS 属性、HealthVital 与战斗状态 |

打开 `wooden_dummy.tscn`，选择 `AnimationAdapter/AnimationPlayer`，在动画面板选择 `hurt` 并播放或拖动时间轴即可预览。`idle` 为默认姿态，`RESET` 用于编辑器还原，`death` 为倒下动作。全部节点和动画都保存在场景内。

SVG 的脚底参考线为 Y=180，场景实体根节点为脚底原点。原图 Y=164 是底座上缘：`Visual/Base` 裁切 Y=164～180；`Visual/Body/Sprite` 裁切 Y=0～164，绕 `Body.position=(0,-16)` 摇摆。表情覆盖层使用相同裁切与位置，因此压缩、旋转及镜像时始终跟随猴脸。修改外观时保持两张 SVG 的画布尺寸和五官注册点，保留底座分界；如需改变尺寸，同步调整裁切、身体枢轴及物理/受击形状。

## 受伤时间轴

`hurt` 是 30 FPS、8 帧（约 0.267 秒）的单次动画，动画轨道只修改 `Visual/Body` 的位置、旋转、缩放和颜色，以及 `HurtFace` 的透明度。

| 素材帧 | 动作 |
| --- | --- |
| 0 | 短暂暖色闪烁，显示受伤五官 |
| 1 | 倾斜约 7.5°，向右偏移 3 像素并上提 2 像素，高度压缩至 92% |
| 3 | 向另一侧回弹，轻微伸长 |
| 5 | 小幅余摆，颜色与五官逐渐恢复 |
| 8 | 恢复原位置、角度、缩放、颜色，隐藏受伤五官 |

可直接编辑这些关键帧调整受伤力度和节奏。`idle` 与 `RESET` 显式恢复所有受伤属性，避免短硬直提前切换后留下姿态。底座保持固定；朝向由父节点 `Visual.scale.x` 管理，身体动画不覆盖它。伤害与物理碰撞不会随视觉摇摆变形。

## 与战斗系统联合

攻击命中后 GAS/HealthVital 处理 HP，独立反应控制器按效果策略、目标抵抗与 Core 打断规则判断是否进入 HURT，再由动画适配器播放 `hurt`。扣血不必硬直，零扣血也可以受击。连续有效命中使用 `play_action(&"hurt", true)` 从第 0 帧重新播放。战斗时钟统一推进动作，暂停、慢动作和受击停顿都保持同步。

HURT 的退出由动作状态规则决定，默认硬直使用 `BattleActionProfile2D.hurt_lock_frames / source_fps`，并可被技能事件的 `hit_stun` 覆盖；修改视觉动作时长不会自动修改硬直。动画完成只发送通知。生命耗尽进入 DEAD 并立即播放 `death`，不会因 `hurt` 结束恢复待机。

运行 [原版伤害样例](../../../examples/original_damage_demo.tscn) 可检查悟空五连击下的木桩受伤。单段和技能时间轴样例同样复用此场景。自动验证入口为 [verify_wooden_dummy.tscn](../../../examples/verify_wooden_dummy.tscn)，覆盖重复受伤、朝向、时钟、碰撞独立、同类实例隔离、五连击和死亡优先级。

## 阶段 9：击飞、倒地与保护动画

新增预置 AnimationLibrary [reaction_animations.tres](reaction_animations.tres)，在木桩 AnimationPlayer 的 `reaction` 库中可直接拖动预览：`launched`、`air_hurt`、`hit_land`、`knockdown`、`getup`、`protect`。动作分别表现浮空倾斜、下落受伤、接地压缩、倒下、起身及青色保护脉冲，继续只修改 Body/HurtFace，底座和物理形状不受动画轨道影响。

AnimationPlayerAdapter 对外仍使用不含库名的语义动作；Core 状态决定动作和退出时间。落地0.1秒、倒地0.65秒、起身0.35秒可在角色 reaction_profile 调整，动画长短不自动改变这些规则。运行 [阶段9演示](../../../examples/hit_reaction_demo.tscn)，详细配置见 [受击与保护说明](../../../addons/battle_foundation/combat/hit-reaction-protection.md)。
