# 猕猴王 Spine 动画与七技能配置

使用提供的 DragonBones 2.2 动画，转换为原生 Spine 4.3，保留21个源动作、60FPS、嵌套骨架和原始姿态。战斗中只登记 attack1–4 和 skill1–3 共七个技能；runattack/jumpattack 等源动作仍可预览，但不再作为战斗技能登记。

源素材仍为60FPS；七个战斗时间轴现在按48FPS推进，动画同步以80%速度播放。非技能动作、独立子弹、冷却与战斗时钟保持各自原有速度。

| 动作/名称 | 原始总帧数 | 战斗判定/发射帧（48FPS） | 倍率 | 冷却 |
| --- | ---: | --- | ---: | ---: |
| attack1 | 19 | [4,10) | 1.5 | 2秒 |
| attack2 | 21 | [4,12) | 1.5 | 2秒 |
| attack3 | 14 | [2,9) | 1.5 | 2秒 |
| attack4 | 42 | [22,34) | 1.5 | 2秒 |
| skill1 狂风出击 | 51 | 第14帧发射 | 2 | 3秒 |
| skill2 疾风突袭 | 59 | [12,40)，同时冲刺 | 2 | 7秒 |
| skill3 飓风强袭 | 219 | 38/62/86/110/134/158帧，共六次 | 每次1.5 | 10秒 |

普攻和冲刺每目标每次施法只命中一次。旋风每0.5秒命中一次，并按目标相对实际矩形中心的位置产生吸附；每次最多在0.3秒内拉近260像素，接近中心时缩短位移，遵守目标霸体/保护/无敌及实体地形。可在人物实例的 CombatRules > Attraction Distance / Attraction Duration 调整强度。

疾风突袭使用现有时间轴运动窗口，速度3000世界像素/秒，减速后的冲刺持续28/48秒；实体碰撞可缩短实际距离，不能穿墙，AI按实际持续时间计算施法距离。狂风出击沿用50%原生粉紫旋风弹、50%造1原Boss2Bullet1：两种均为2倍攻击，造1保留出回轨迹和两次独立命中。六个子弹槽在场景中预置；出生位置/朝向快照，人物移动、转身或施法结束不牵动子弹。死亡/离场及时清理。

## 编辑技能范围和时序

主要编辑 `monster.tscn` 的 `AnimationAdapter/AttackRanges/<动作>/CollisionShape2D`。attack1–4 用户已保存的实例位置/大小保持原样。拖动矩形即可更改真实判定范围，尺寸为世界像素。也可编辑 `visual.tscn` / `attack_ranges.tscn` 默认模板；实例覆写优先。

原生 AnimationPlayer 保留原动作长度，拖动时间轴可预览姿态、伴随特效与判定框。AttackRanges 的 Show All Ranges / Show Only Hit Frames 控制显示，运行时隐藏编辑框且不增加物理检测Area。每个Boss使用独立技能副本，左右自动镜像。

`skills/<动作>.tres`：

- Features > Cooldown：实际 GAS 冷却，暂停/慢动作与战斗同步。
- Features > Timeline：Source FPS、总帧数、Animation Action、Action Rules。
- attack1–4 / skill2：Attack Segments > Hit，编辑 Start/End Frame、倍率、硬直等。
- skill1 / skill3：Timeline 的 metadata/projectile_segment 保存外部判定段，场景矩形同步覆盖该段。skill1 的 Events > ProjectileLaunch 控制发射帧；skill3 的六个 Pulse 事件控制旋风命中时机。
- skill2：Motion Windows > Dash 设置速度和起止帧，与伤害窗口同步修改。

`CombatRules` 的 C#组件在初始化时依据实际场景矩形计算该Boss的独立AI施法范围；近距离使用普攻/旋风，较远使用子弹或冲刺，并同时检查高度、GAS冷却与AI规则。`boss.tres` 可调权重/优先级；Group Cooldown 与技能实际冷却保持一致。

## 保护、霸体、抗性与播报

skill1–3 的 Action Rules.super_armor=true；仅当前动作有效，沿用独立霸体彩色描边，不修改人物材质、无双或技能特效。风抗20、水抗20、火抗-20保存在 `attributes.tres`，原Boss血条自动显示风/水正抗及火负抗图标。

保护条保留25000满值。`MihouwangCombatController` 收到真实 protection.triggered 事件时同步取消当前动作和预约、清除受击位移，跳过旋风现有冷却直接释放 skill3；重新开始10秒冷却。保护覆盖本次219/48秒旋风，重复受击不重复触发；死亡/离场沿用统一清理。

`assets/ui/boss/mihouwang/skill1.png`、`skill2.png`、`skill3.png` 是三个320×65播报图，使用提供的头像、造五原始技能切入模板轮廓和项目W12字体。人物实例 `CombatRules > Skill Announcements` 依次引用三图。AI先播报，等待0.2秒后开始动作；动作开始不重播。Announcement Lead Seconds 可调预警时间。手动/保护释放仍从真实 attack.started 播报，保留减速后的技能前摇；保护立即起手。暂停冻结等待，复用原SkillComing的滑入/停留/滑出时序。

三个技能从AI播报开始获得霸体，持续至动作结束；正常承受伤害，但普通/重击/击飞、击退和眩晕不能打断播报或技能。使用独立引用计数的霸体及控制免疫标签，沿用现有彩色描边。取消预约、技能结束、死亡、离场或关卡结束时清理自身标签并恢复受击配置，保留其他系统授予的霸体。

## 动画素材与转换

人物文件在 `assets/monsters/zaomeng1/mihou_king/`，特效在 `assets/effects/mihouwang/`。10组特效原24/60FPS保留；七组伴随特效由主AnimationPlayer采样，skill1/runattack/runattack1源特效位于预置弹道槽。非战斗源动作保留用于编辑预览。

`tools/import_mihouwang_spine.py` / `tools/import_mihouwang_effects.py` 重建保存的源动画；二次转换保留已编辑技能、判定框、主AnimationPlayer和Boss配置。`tools/author_mihouwang_announcements.py` 重新合成三图，已保存原头像和原模板，无需再次提供临时文件。三图共用头像容纳区(27,9)至(106,52)，按比例完整放入上下框线以内，并按模板透明轮廓裁切；source.json记录布局，重新生成不会恢复溢出。整关导入工具会重写地图，不应在手动编辑关卡后无条件重跑。

验证套件 `mihouwang_skills`：实际冷却、命中窗口/倍率、冲刺速度与镜像、旋风六次半秒伤害/双向吸附、保护打断并绕过冷却、霸体清理、抗性图标、播报与分距离AI。`shuiliandong_combat`：真实地形通行、实例矩形编辑后真实伤害变化、独立弹道及随机流。`mihouwang_animation`：原姿态、十组特效、FPS、seek/reset/尾帧/镜像和W12字体。
