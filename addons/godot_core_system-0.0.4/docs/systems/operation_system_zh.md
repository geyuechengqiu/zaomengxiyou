# 操作意图系统：可扩展的角色操作控制器

本模块将 Godot 原生输入转换为游戏语义意图，是 `godot_core_system` 的可选模块，不依赖悟空、Spine 或特定角色状态机。上古天帝篇当前玩家操作作为接入示例。

```text
键盘 / 手柄 / 鼠标
  → Godot InputMap 原生动作
    → CoreOperationProfile 可配置映射
      → CoreOperationController 独立意图通道
        → intent_emitted → 状态机处理一次性意图
        → get_axis / is_pressed → 状态查询持续意图
AI / 触屏 / 网络代码
  → submit_intent / pulse_intent → 同一意图通道
```

插件只决定“用户想做什么”，状态决定“当前是否可以做、怎样做”。双击奔跑、二段跳次数、连击缓存、第四段翻转窗口、攻击位移和动画结束逻辑仍属于角色状态，不写入通用控制器。

## 1. 模块入口与组成

入口为 `CoreSystem.operation_manager`，作为现有 CoreSystem 插件的内部模块，不需要再启用一个独立 EditorPlugin。项目设置 `godot_core_system/module_enable/operation_manager` 在启动时控制模块是否启用，默认开启；禁用后该入口为 null，依赖此模块的玩家组件会报告初始化错误。

| 类型 | 职责 |
| --- | --- |
| `CoreOperationProfile` / `operation_profile.gd` | Resource，定义语义意图与原生动作/轴的映射，可保存成 `.tres` |
| `CoreOperationController` / `operation_controller.gd` | Node，接收原生输入、聚合来源、维护强度、生成语义事件 |
| `CoreOperationIntent` / `operation_intent.gd` | 一次意图事件，包含 ID、按下/松开、强度、设备、来源、负载 |
| `CoreOperationManager` / `operation_manager.gd` | 创建/查询/注册控制器，弱引用注册，不接管其场景生命周期 |

现有 `CoreSystem.input_manager` 保持不变。它仍提供重映射、输入缓冲、记录器等底层功能；操作模块不订阅其 `_input` 阶段的动作信号，避免 UI 消费前触发角色动作，也不自动复用它的事件过滤器。需要额外过滤时可在控制器适配方法中实现。

## 2. 创建可配置控制器

```gdscript
const Profile = preload("res://addons/godot_core_system-0.0.4/source/operation_system/operation_profile.gd")

func _ready() -> void:
    var profile = Profile.new()
    profile.bind_intent(&"move_left", [&"left"])
    profile.bind_intent(&"move_right", [&"right"])
    profile.bind_intent(&"jump", [&"jump"])
    profile.bind_intent(&"attack", [&"attack"])
    profile.bind_axis(&"move", &"move_left", &"move_right")
    var controls = CoreSystem.operation_manager.create_controller(
        StringName("player_%d" % get_instance_id()), profile
    )
    controls.intent_emitted.connect(_on_intent)
    add_child(controls)

func _on_intent(intent: InputEvent) -> void:
    if intent.is_intent_pressed(&"jump"):
        print("请求跳跃，而不是收到 K 键")
```

`create_controller()` 返回的节点需要由调用方 `add_child()`，应放在角色子树中。不要把所有控制器放在始终运行的全局单例下，以免角色暂停后输入仍在处理。

资源示例：[上古天帝篇 Profile](../../examples/operation_demo/shang_gu_tian_di_profile.tres)。也可在编辑器创建 `CoreOperationProfile` 资源并填写 `bindings`、`axes`。

`bindings` 的结构为 `意图名: [原生 InputMap 动作名...]`。一项意图可以对应多个动作，例如 `dodge: [keyboard_dodge, gamepad_dodge]`；动作须在项目 InputMap 中已定义。模块不改写按键绑定，A/D、手柄按键等仍由 Godot InputMap 配置。

`axes` 的结构为 `轴名: {"negative": 负向意图, "positive": 正向意图}`。`get_axis()` 返回正向强度减负向强度，范围 -1～1；摇杆输入使用动作强度，等强度反向抵消。

配置资源可以共享，但运行数据不共享。需要某个控制器单独修改绑定时，先 `profile.duplicate(true)` 再 `set_profile()`，不要修改共享 Resource。切换 Profile 会释放旧的持续意图。

## 3. 事件与持续状态

状态中只使用语义名称：

```gdscript
if intent.is_intent_pressed(&"attack"):
    # 是否进入地面攻击、跑攻或空攻，由当前状态决定。
    pass
var direction = controls.get_axis(&"move")
var holding_left = controls.is_pressed(&"move_left")
```

`is_intent_pressed()` 只在 0 → 非零时返回 true；摇杆强度 0.4 → 0.8 仍发送变化事件，但不重复触发跳跃/攻击。`is_intent_released()` 表示强度归零。

事件的 `action` 是**语义意图 ID**，不是原生 InputMap 动作名。`pressed`、`strength` 表示聚合后的状态；`origin` 为 `native`、`ai`、`network` 或自定义来源；`device` 是原生设备 ID，虚拟来源为 -1；`payload` 可携带技能 ID、目标等业务数据，控制器会补充 `just_pressed`。

意图事件继承 `InputEventAction`，是为了复用现有 `BaseStateMachine.handle_input(InputEvent)`，并不代表还在分发键盘事件。**不要把生成的意图再次传给 `Input.parse_input_event()`**，否则可能重新映射并形成循环。

同一意图的不同按键、设备及虚拟来源分别记录，取最大强度。一个来源松开，不会清除另一个仍有效的来源。键盘 echo 和重复的同强度事件不会产生重复按下。

## 4. AI、触屏或网络输入

```gdscript
# 持续向右，随后停止；origin 标识独立来源。
controls.submit_intent(&"move_right", 1.0, &"ai")
controls.submit_intent(&"move_right", 0.0, &"ai")

# 一次跳跃请求，内部依次发出按下与松开。
controls.pulse_intent(&"jump", &"touch")

# 无需 InputMap 中存在 cast_spell，可直接扩展业务意图。
controls.pulse_intent(&"cast_spell", &"network", {"skill": 7})
```

`submit_intent()` 更新该意图、该 origin 的强度。`pulse_intent()` 适合当前未持有的按钮意图；已有其他来源持续持有同意图时不会强行生成第二次按下。多触点/多网络实体应使用不同 origin。

要彻底由 AI 控制，设置 `native_input_enabled = false`。关闭原生来源只清除原生来源的持有值，不清除虚拟来源。网络输入接口只是接入点，不包含联网、同步、预测或安全校验。

## 5. 继承扩展适配器

继承 `CoreOperationController`，可覆盖 `process_native_event(event)` 追加过滤/翻译，也可不接收原生输入，直接从触屏按钮、AI 或其他组件调用 `submit_intent()`。

自定义实例通过 `CoreSystem.operation_manager.register_controller(id, custom_controller)` 注册，再加入角色子树。ID 不能重复，一个实例只能注册一次。管理器只保存 WeakRef，节点退出场景树时注销，调用方负责释放节点。

添加新操作通常只需：

1. 在 InputMap 增加按键动作（虚拟来源可跳过）。
2. 在 Profile 增加如 `dodge`、`interact`、`cast_spell` 的语义映射。
3. 在合适的业务状态中消费该意图。

无需修改 manager/controller。只在需要新输入设备协议时编写适配器。

## 6. UI、设备、暂停与生命周期

- 新按下只在 `_unhandled_input` 接受，UI 消费的按下不会进入意图通道，物理帧也不绕过 UI 去读全局 `Input`。
- `_input` 仅清理已持有来源的松开，不接受按下；松开即使被 UI 消费也不会卡键。
- `device_filter = -1` 接受全部设备，非负值只接受对应 Godot `InputEvent.device`。多个角色默认仍可使用同一套按键，独立控制需要不同映射或设备过滤。
- 失焦和节点暂停清空意图。禁用/暂停角色子树会停止原生控制器回调；当前示例消费者也检查 `can_process()`，不会让外部 AI 信号在暂停时切动作。
- 直接调用虚拟输入接口会更新通道数据，不受原生事件回调开关约束；其是否驱动游戏由消费者控制。
- 退出角色时先断开消费者信号，再注销状态机并释放父子引用，控制器退出时自行清空状态和注销。

## 7. 当前玩家接入与测试

玩家的 `StateMachine` 组件持有 `operations`，根状态机共享变量 `operations` 指向同一个通道。叶子通过 `_controls()` 查询；分组通过语义事件选择攻击/跳跃。所有动作状态不再调用全局 `Input` 或识别玩家的原生动作名。

组件 Inspector 中可指定 `operation_profile`、`input_device`；Profile 留空时从玩家旧的四项 `*_action` 配置构建兼容映射。指定 Profile 后这四项旧配置不再参与映射。

现有项目的 `test_state_machine.tscn` 已指定 `res://controls/test_operation_profile.tres`，测试场景直接继承该配置，不再依赖旧字段回退。该资源设置 `resource_local_to_scene = true`，每个角色实例得到独立配置。可在角色的 StateMachine 子节点 Inspector 中编辑/替换 Profile。

回归入口：`res://tests/test_operation_intents.tscn`，运行参数 `--headless --path . --fixed-fps 60 --quit-after 4000`，成功标记 `OPERATION_INTENT_TESTS_PASSED`。覆盖语义轴、摇杆变向/回中、多绑定聚合、强度边沿、UI 吞按下/松开、设备与实例隔离、自定义负载、失焦、Profile 切换、扩展注册与清理，以及实际角色的虚拟行走、跳跃、空攻、奔跑和连击。
