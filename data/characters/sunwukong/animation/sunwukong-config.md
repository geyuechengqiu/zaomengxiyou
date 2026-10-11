# 孙悟空攻击特效与运动配置

转职前四技能与火魔斩的按键、MP/CD、技能等级、攻击段、射线、特效轨道和原版来源见 [基础技能配置](../skills/README.md)。本页继续说明五连击特效与跳跃/移动参数。

角色运行组件已预置到物理角色场景，动画适配器与判定框仍在 visual 子树中编辑；详见 [角色组件说明](../components.md)。

跑攻、跳攻与第四段一次转身已接入，操作、配置、来源与实际渲染见 [上下文攻击说明](../skills/context-attacks.md)。

## 五段普攻特效

[sunwukong_visual.tscn](sunwukong_visual.tscn) 已预置现有 `wukong_skills.skel` 的五段普攻特效，使用 [skill_wukong_data.tres](../../../../assets/characters/sunwukong/animation/effects/skill_wukong_data.tres)。角色主 AnimationPlayer 同时控制身体、特效和单一判定框预览；游戏启动时复用场景中的节点。

原版配置来自 `Speculum-4399-master/exports/zmhj_role_stats/原始配置/Skill.json` 的 1001010～1001050，以及原 `attackV427` DragonBones 动画。业务技能仍使用 `sunwukong_attack1`～`sunwukong_attack5`；原数字编号仅用于来源追溯。详细参数见 [来源映射](sunwukong_attack_effects_source.json)。

| 主动作 | 特效动作 | 原版触发帧（30 FPS） | 素材时长（帧） | 原素材偏移 | 原素材缩放 |
| --- | --- | --- | --- | --- | --- |
| attack_1 | attack1 | 4 | 8 | (0, 0) | (1, 1) |
| attack_2 | attack2 | 4 | 7 | (0, 0) | (1, 1) |
| attack_3 | attack3 | 2 | 10 | (0, 0) | (1, 1) |
| attack_4 第一次 | attack4 | 0 | 8 | (0, 0) | (1, 1) |
| attack_4 第二次 | attack4 | 8 | 8 | (-17, -4) | (-1, 1) |
| attack_5 | attack5 | 6 | 9 | (0, 0) | (1, 1) |
| run_attack | runAttack | 3 | 9 | (0, 0) | (1, 1) |
| jump_attack | jumpAttack | 5 | 7 | (0, 0) | (1, 1) |

触发时间为 `原版帧号 / 30`。特效放在角色脚底原点，使用 `AttackEffects` 的 2 倍素材单位转换，层序为角色前方 `z_index = 1`。第二次第四段特效由独立 Secondary 节点播放：右朝向时世界偏移为 (-34, -8)，左朝向为 (34, -8)，原始 `scaleX = -1` 也随容器一起镜像。

原版 `followParent = true`、`linkParentState = true`：特效跟随角色位置与朝向，素材播放完毕或角色离开当前动作时结束。因此第一段特效虽有 8 帧素材，若角色的攻击动作先结束，特效也随之结束。跳取消、受击、死亡、下一段连招都会清理旧特效；重新释放从新的前摇开始。

运行时身体与特效由同一 BattleClock 推进，暂停、慢动作和受击停顿同步生效。低帧率跨过触发帧后，以当前动作时间减去触发时间设置 Spine 局部进度。特效只负责表现，伤害仍由现有 GAS 技能时间轴和统一 AttackHitbox 结算。

合并特效骨架的七个攻击动画分别键控自己的槽位；停止轨道不会恢复已显示的附件。因此运行时与编辑器对特效每次采样前恢复 Setup Pose，再应用当前动画，清除上一段的棍影附件、颜色、骨骼与变形状态。验收同时比较连续连招与全新实例的附件和绘制范围，避免轨道已停止但旧图仍残留。

## 在编辑器调整特效

1. 打开 `sunwukong_visual.tscn`，选择根节点下的 **AnimationPlayer**。
2. 选择 `attack_1`～`attack_5`、`run_attack` 或 `jump_attack`，拖动时间轴预览身体、棍影特效及判定框。
3. 调整 `AttackEffects/Primary`、`Secondary` 的 Animation 类型轨道关键帧，即可修改播放时间；`visible` 轨道控制显示窗口。结束处的 `RESET` 关键帧负责清理原生播放轨道，随触发时间一起调整。
4. 调整 `AttackEffects` 的 Scale 修改整个特效的素材比例；调整 Primary / Secondary 的 Position、Scale 修改局部注册点与镜像。身体的 `SpineVisual` 位置用于脚底校准，特效使用角色根原点。
5. 修改伤害范围和命中帧，应编辑 [attack1.tres](../skills/normal_attacks/attack1.tres)～[attack5.tres](../skills/normal_attacks/attack5.tres) 的 GAS 时间轴。表现时间与命中时间是两类配置；需要同步变化时同时调整。

`AttackEffects:preview_action` / `preview_time` 是编辑器快照轨道，跟随主动作与时间，用于精确同步 Spine 和向后拖动时的可见性，添加新动作时一并保留。游戏中此预览脚本停止处理，身体与特效仍只消费战斗时钟。针对[原生 SpineAnimationTrack 的关键帧容差采样](https://github.com/EsotericSoftware/spine-runtimes/blob/4.3/spine-godot/spine_godot/SpineAnimationTrack.cpp)，预览会在骨架应用前校正局部时间，避免结束关键帧附近提前跳回第0帧。

日常编辑直接保存场景。[追加工具](../../../../tools/add_wukong_attack_effects.mjs) 仅给尚未接入特效的初始 visual 添加轨道，已存在 AttackEffects 时保留用户编辑。如果显式强制重建初始 visual，需要再运行追加工具接回特效；不要用强制重建覆盖日常编辑。

## 调整移动、跳跃与动作规则

在 Godot 文件系统中打开资源，直接在 Inspector 修改；资源中的默认字段也可在 Inspector 展开编辑。

| 想调整的行为 | 资源 | 字段与当前值 |
| --- | --- | --- |
| 行走速度 | [角色场景](../character.tscn) 的 GameplayVitalAttributeComponent | Scene Attributes → Base Values → `walkSpeed` = 420 世界像素/秒，对应原版210 |
| 奔跑速度 | 同上 | Base Values → `runSpeed` = 600 世界像素/秒，对应原版300；同方向双击进入奔跑 |
| 第一跳速度 | [sunwukong_actions.tres](../actions.tres) | `jump_velocity` = -1000 |
| 第二跳速度 | 同上 | `second_jump_velocity` = -1000 |
| 跳跃次数 | 同上 | `maximum_jumps` = 2；改成 1 为单跳 |
| 重力 | 同上 | `gravity` = 2000 |
| 最大下落速度 | 同上 | `maximum_fall_speed` = 900 |
| 起跳 / 落地状态时间 | 同上 | `takeoff_frames` = 2，`landing_frames` = 1，按 source_fps = 30 换算 |
| 贴地距离 / 最大坡度 | 同上 | `floor_snap_distance` = 3，`maximum_floor_angle` = PI/4（45°） |
| 受击硬直 | 同上 | `hurt_lock_frames` = 8；技能命中数据可以提供自己的硬直时长 |
| 攻击时移动、跳跃、转向许可 | 同上与连击各段 | `state_rules` 及各段动作规则；由 Core 状态机判断 |
| 第四段攻击的向前位移 | [sunwukong_combo.tres](../skills/combo.tres) | Step4 的 `root_motion_speed`、`root_motion_frames`；原导入速度为300，当前已调为100，持续16帧，以资源为准 |
| 第四段反向转身窗口 | [sunwukong_combo.tres](../skills/combo.tres) | Step4 的 `turn_window_start_frame` = 8、`turn_window_end_frame` = 16，半开窗口内新按反方向仅转身一次 |
| 跑攻冲刺速度 | [run_attack.tres](../skills/normal_attacks/run_attack.tres) | Timeline 的 motion_windows → Dash → velocity.x = 480，按起手朝向镜像；常规 runSpeed 不覆盖攻击冲刺 |
| 按键、双击窗口、输入缓存 | [操作配置说明](../../../controls/README.md) | Core 操作定义；游戏中 Esc 菜单可重映射 |

速度单位为世界像素/秒，重力为世界像素/秒²。Godot 的 Y 轴向下，所以跳跃速度为负；绝对值越大，跳得越高。其他参数不变时，提高重力会更快下落并降低跳高；无碰撞、无二跳时近似跳高为 `jump_velocity² / (2 × gravity)`。例如 -620、1500 对应约 128 世界像素；-820 对应约 224 世界像素。

**属性表中的 `jumpSpeed1` / `jumpSpeed2` 保存原版 -178 数据，当前平台运动控制器实际读取动作配置的 `jump_velocity` / `second_jump_velocity`。调跳跃请改动作配置。**组件编辑步骤见 [角色属性配置](../components.md#直接编辑悟空属性)。组件填写的基础值优先于原属性集资源；删除对应键可恢复定义默认值。行走和奔跑实际读取 GAS 最终属性，Buff、装备或临时加成也会影响速度。角色显示比例与 Camera2D Zoom 只影响看到的尺寸，不代替运动参数。

平台展示与 F5 原版伤害场景使用 `sunwukong_actions.tres`。单段攻击样例覆盖为 [single_attack/actions.tres](../actions.tres)，其两次跳跃速度目前为 **-820**；三段时间轴样例使用 [skill_timeline/actions.tres](../actions.tres)。改配置前选中具体场景的 SunWukong，确认 **Action Profile** 指向哪个资源。同一资源的修改会影响所有引用它的场景；为某场景单独调参时复制资源并替换该引用。

当前地图、人物与怪物统一使用原版2倍世界坐标；第一关镜头缩放0.5，因此奔跑600世界像素/秒显示为300像素/秒。移动控制器直接读取最终属性，不再额外乘比例。填写场景属性时应使用世界速度，不能再次填写原版300，否则会慢一半。场景 Base Values 优先于 `sunwukong_attributes.tres`，这两处默认值已同步。

运行时增益和 GM 修改应走实例入口，例如 `player.attributes.set_base_value(&"walkSpeed", 520.0)`；不要改共享属性定义资源。修改保存资源后重新运行场景，使实体重新载入配置。

## 普通无双表现配置

在角色 `AnimationAdapter/WushuangEffect` 修改 `Glow Color`（默认 `#FF3000`）、`Spawn Interval`（0.2秒）和 `Ghost Lifetime`（1秒）。默认持续时间在 [normal_wushuang_visual.tres](../../../buffs/normal_wushuang_visual.tres) 的 Duration；空格映射仍通过 Esc 操作菜单调整。若延长残影寿命或缩短采样间隔，需要在 [无双场景](../../../effects/wushuang/sunwukong_wushuang.tscn) 手动增加预置快照槽，使槽数至少为 `ceil(寿命/间隔)+1`。具体来源、层序和新角色接入见 [无双说明](../../../effects/wushuang/README.md)。

## 验收

使用带 Spine 模块的 Godot：

```powershell
& '<Spine-Godot.exe>' --headless --path . res://tests/suites/verify_wukong_attack_effects.tscn
& '<Spine-Godot.exe>' --headless --editor --single-window --path . --script tools/verify_editor_wukong_attack_effects.gd
```

运行时检查五段普攻六个事件及跑攻/跳攻两个事件的触发、结束和局部播放进度、低帧率、双向镜像、实例隔离、动作切换及真实战斗暂停/慢动作/停顿/跳取消；编辑器检查时间轴前后拖动与切换动作。五段伤害、原版跳字和运动碰撞的既有验收继续保留。
