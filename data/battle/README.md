# 阶段一业务定义

本目录是 [Battle Foundation 插件](../../addons/battle_foundation/README.md) 的业务资源，插件代码不依赖本目录。入口 [manifest.json](manifest.json) 建立角色、技能、怪物、装备、关卡及状态的 ID → 资源索引；配置以 `.tres` 保存，运行状态由战斗会话和 GAS 实例管理。

| 类别 | 示例资源 | 配置内容 |
| --- | --- | --- |
| 角色 | [sample_hero](characters/sample_hero.tres) | player 阵营；完整 28 项属性；生命 100、魔法 50、攻击 20、防御 5、回血 2、回魔 1；sample_attack |
| 怪物 | [sample_monster](monsters/sample_monster.tres) | enemy 阵营；完整 28 项属性；生命 60、攻击 10、防御 3；sample_attack |
| 技能 | [sample_attack](skills/sample_attack.tres) | GAS 定义；基础冷却 2 秒；示例素材 30 fps、30 帧；第 12/18 帧 Core 事件；行为树提交冷却并等待 |
| 状态 | [sample_guard](statuses/sample_guard.tres) | GAS 定义；持续 3 秒；刷新并叠加至 3 层；只对所属实体 damage_received 按每层 0.5 倍减伤 |
| 装备 | [sample_sword](equipment/sample_sword.tres) | 最大耐久 100；atk +5 的 GAS 修改器模板；阶段一未自动装备 |
| 关卡 | [sample_arena](levels/sample_arena.tres) | 在 -2/+2 位置生成角色和怪物 |
| 碰撞场景 | [sample_entity](scenes/sample_entity.tscn) | BattleEntity 宿主及 CapsuleShape3D；可与静态墙体碰撞 |

数值用于阶段一验收，并非原版实体数据。角色和怪物属性集分别见 [sample_hero](attributes/sample_hero.tres) 和 [sample_monster](attributes/sample_monster.tres)，全部引用 [data/attribute](../attribute/README.md) 原版 ID 定义；资源初始值只用于实例初始化，不保存当前生命、剩余冷却或状态层数。

添加业务定义时创建同类 `.tres`，在 manifest 对应类别登记 ID 和路径。实体中引用的技能和状态、关卡中引用的实体必须已经登记。外部业务通过 Catalog.instantiate_definition 或 Session.spawn_entity 等接口取得实例，不修改 `load()` 返回的共享资源。

在 Godot 中运行 [交互演示](../../tests/suites/verify_stage_one.tscn) 或 [自动验收](../../tests/suites/verify_stage_one.tscn)。完整时钟规则、事件字段、素材帧约定和脚本索引见插件 README。
