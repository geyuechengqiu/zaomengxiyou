# 孙悟空配置入口

孙悟空的定义、角色场景、属性、输入绑定、动画和技能集中在本目录；对应原始图片、Spine 骨架、特效和声音放在 `assets/characters/sunwukong/`。运行身份保持 `孙悟空`，技能身份保持 `sunwukong_*`，资源目录改动不改变存档和技能 ID。

| 文件或目录 | 编辑内容 |
| --- | --- |
| [definition.tres](definition.tres) | 名称、阵营、属性集、成长、Vital、已学技能和角色场景 |
| [character.tscn](character.tscn) | 角色和预置组件；`GameplayVitalAttributeComponent → Base Values` 覆盖本角色初始属性 |
| [attributes/base.tres](attributes/base.tres) | 属性定义的一级基础值；场景 Base Values 优先于这里 |
| [attributes/progression.tres](attributes/progression.tres) | 每级成长、经验需求和最高等级 |
| [actions.tres](actions.tres) | 重力、默认一/二跳速度、动作权限、跑攻/跳攻和连招 |
| [controls/input.tres](controls/input.tres) | 操作意图、按键和技能槽绑定；游戏设置可重映射 |
| [animation/sunwukong_visual.tscn](animation/sunwukong_visual.tscn) | 身体、武器、特效和单一攻击框；AnimationPlayer 可视化编辑 |
| [animation/sunwukong_profile.tres](animation/sunwukong_profile.tres) | 原动作映射、素材帧率、脚底校准、显示缩放和挂点 |
| [skills/normal_attacks](skills/normal_attacks/) | 五连击、跑攻、跳攻的原帧事件和判定框 |
| [skills/README.md](skills/README.md) | 转职前技能、火魔斩、火眼按住释放和无双的配置说明 |

角色实例的 `Base Values` 中 `walkSpeed`、`runSpeed` 是世界单位/秒。跳跃实际读取 `actions.tres` 的 `jump_velocity`、`second_jump_velocity`，负值绝对值越大跳得越高；`gravity` 改变下落速度和最高跳跃高度。属性表的 `jumpSpeed1/2` 保留原版配置，不控制当前跳跃。技能位移由技能时间轴配置，不等同于普通跑速。[详细调参说明](animation/sunwukong-config.md)。

创建新角色时，从 [character_base.tscn](../../templates/character_base.tscn) 与 [character_definition.tres](../../templates/character_definition.tres) 复制基础模板到 `data/characters/<角色名>/`，给角色分配独立 ID、动画和技能定义，然后加入关卡索引。[模板说明](../../templates/README.md)。
