extends HBoxContainer
class_name AbilityBar
#region 配置与运行状态

@export var button_scene: PackedScene

var _component: GameplayAbilityComponent
# 记录 ID 到 按钮节点的映射，方便移除
var _buttons: Dictionary = {}
#endregion
#region 公共接口

## 外部初始化调用 (通常由 Player 或 UI Manager 调用)
func setup(comp: GameplayAbilityComponent) -> void:
	_component = comp
	# 连接信号
	_component.ability_learned.connect(_on_ability_learned)
	_component.ability_forgotten.connect(_on_ability_forgotten)

	# 初始化已有的技能 (防止 UI 初始化晚于技能学习)
	for instance in _component.get_all_ability_instances().values():
		_on_ability_learned(instance)
#endregion
#region 信号回调

func _on_ability_learned(instance: GameplayAbilityInstance) -> void:
	var id = instance.get_definition().ability_id

	# 防止重复添加
	if _buttons.has(id): return

	# 实例化按钮
	if not is_instance_valid(button_scene):
		push_error("button scene is not valid!")
		return
	var btn := button_scene.instantiate() as AbilityButton
	add_child(btn)

	btn.pressed.connect(_on_btn_pressed.bind(btn))

	# 注入数据
	btn.setup(instance)
	_buttons[id] = btn

func _on_ability_forgotten(ability_id: StringName) -> void:
	if not _buttons.has(ability_id): return
	var btn : AbilityButton = _buttons[ability_id]
	btn.pressed.disconnect(_on_btn_pressed.bind(btn))
	btn.queue_free()
	_buttons.erase(ability_id)

func _on_btn_pressed(ability: GameplayAbilityInstance, btn: AbilityButton) -> void:
	if not is_instance_valid(_component):
		return
	
	if not is_instance_valid(ability):
		return
	
	var ability_id := ability.get_definition().ability_id
	CoreSystem.event_bus.push_event("ability_button_pressed", [{"ability_id": ability_id}], true)
#endregion
