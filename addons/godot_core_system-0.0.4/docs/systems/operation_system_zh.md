# 操作意图系统

CoreSystem 的可选 operation_manager 模块将 Godot 输入变成角色操作名称。按下、持有、松开、强度变化、缓存、双击、改键和控制权均已实现；角色决定意图能否执行。模块不依赖 Spine、悟空或 GAS，业务接入使用 Battle Foundation。

完整键表、角色扩展、原版来源、SVG 类图和验收见 [角色操作控制器文档](../../../battle_foundation/input/README.md)。当前入口是 [孙悟空平台](../../../../game/levels/biyujing.tscn)，按 Esc 打开设置。

## 组成

| 类型 | 实现职责 |
| --- | --- |
| CoreOperationProfile | Resource：bindings、axes、default_keys、reserved_keys、buffered_intents、窗口/容量；共享只读 |
| CoreOperationManager | Node：WeakRef 注册、创建控制器、持有绑定服务、改键时 reset 受影响控制器 |
| CoreOperationController | Node：来源强度、阶段、长按、双击、控制权原因集合和输入时钟 |
| CoreOperationIntent | InputEventAction：phase、sequence、input_time、held_seconds、origin、device、payload 快照 |
| CoreOperationBuffer | RefCounted：按下缓存、TTL/FIFO/容量、sequence 精确消费 |
| CoreOperationBindings | Node：安装默认 InputMap、捕获/校验绑定、冲突检测、用户配置保存和恢复 |

旧 InputManager 与此通道并列，不自动连线。旧 KeyRemapHandler、InputBuffer 和配置适配器的限制见 [实现分析](../implementation-analysis.md)；新通道使用自己的可消费队列与绑定服务。

## 创建与消费

    var profile := CoreOperationProfile.new()
    profile.bind_intent(&"attack", [&"my_player.attack"])
    profile.default_keys = {&"my_player.attack": ["J"]}
    profile.buffered_intents = [&"attack"]
    var controls := CoreSystem.operation_manager.create_controller(&"player/input", profile)
    add_child(controls)
    controls.intent_emitted.connect(func(intent): print(intent.action, intent.get_phase_name()))

create_controller 不自动 add_child；控制器放到拥有者子树，退出自动注销。自定义适配器可继承 CoreOperationController 并 register_controller。项目设置 godot_core_system/module_enable/operation_manager 默认开启，业务还需要 Core 配置服务。

action 是操作名称。PRESSED 在聚合强度从零变非零时产生；HELD 每输入 tick 产生，long_press_started 只越过阈值一次；RELEASED 带持有时长；CHANGED 表示强度变化。is_intent_pressed 不把 HELD/CHANGED 当新按下。不要再将意图交给 Input.parse_input_event。

原生新按下在 _unhandled_input 接受，UI 优先；_input 只记录来源/清理释放。OS echo 被忽略；多物理来源按最大强度聚合，摇杆正负精确匹配。get_axis 默认正减负，可选 opposites=last_pressed；get_double_tap_direction 返回第二次持有期间的双击方向。

peek_buffered_intents 返回独立按下快照，角色通过许可后 consume_buffered_intent(sequence)。RETRY 保留，容量满丢最旧项，过期按 input_time；松键不丢短按，reset 清队列。不按 action 一次删除全部连按。

## 时间、改键与控制权

默认 _physics_process 推进未缩放输入时间；统一会话设置 externally_driven=true 并每 tick advance_input(unscaled_delta)，避免双驱动。输入时间与战斗慢动作/停顿分开，暂停撤回控制，停顿期间缓存继续过期。

    controls.set_control_blocked(&"menu", true)
    controls.set_control_blocked(&"menu", false)
    CoreSystem.operation_manager.bindings.start_remap(controls, &"attack")
    CoreSystem.operation_manager.bindings.set_binding(&"my_player.attack", new_key_event)

menu、focus_lost、ownership、remapping 等原因可以同时存在，移除一个不会覆盖另一个。撤回时立即 reset，发 cancelled 释放，清缓存/双击；恢复后旧持有键先松开再按。submit_intent/pulse_intent 同样经过控制权门；native_input_enabled=false 只撤销原生来源，保留虚拟来源。

绑定服务 Always 运行，Esc 取消，冲突不覆盖其他操作。键盘/鼠标/手柄描述保存到 Core ConfigManager 的 operation_bindings 段；默认安装、恢复与改键不修改 Profile。保存失败保持原映射。保留键由 Profile 声明。

## 业务与验收

BattlePlayerOperations 先执行公共移动、跳跃、普攻和技能槽，再调用角色钩子。战斗状态、生命、落地和 GAS 冷却负责许可，控制器不越过规则。阶段和消费结果通过 Core 战斗事件公开。

运行 res://tests/suites/verify_player_operations.tscn，成功打印 PASS，失败返回 1；覆盖实际 Godot 分发、UI 消费、改键保存/重载、失焦、暂停、双击、多来源、缓存、角色扩展和真实角色/GAS/平台。原有动画与战斗验收保留。
