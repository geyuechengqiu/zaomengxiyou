extends MarginContainer
class_name AbilityButton
#region 配置与运行状态

@onready var button: Button = %Button
@onready var icon: TextureRect = %Icon
@onready var cooldown_overlay: ColorRect = %CooldownOverlay
@onready var key_label: Label = %KeyLabel

var _instance: GameplayAbilityInstance
var _cooldown_mat: ShaderMaterial
var _cd_feature : CooldownFeature
#endregion
#region 信号

signal pressed(ability_instance: GameplayAbilityInstance)
#endregion
#region 生命周期与引擎回调

func _ready() -> void:
	# 获取 Shader 材质实例，避免多个按钮共享同一个材质导致进度同步
	if is_instance_valid(cooldown_overlay):
		_cooldown_mat = cooldown_overlay.material as ShaderMaterial
	button.pressed.connect(_on_button_pressed)

func _process(delta: float) -> void:
	if not is_instance_valid(_instance): return

	# 4. 更新冷却 Shader
	# 假设技能有一个 CooldownFeature
	if is_instance_valid(_cd_feature):
		# 计算比例 (1.0 = 刚开始冷却, 0.0 = 冷却结束)
		var ratio = _cd_feature.get_cooldown_progress(_instance)
		_cooldown_mat.set_shader_parameter("value", ratio)
#endregion
#region 公共接口
		
## 初始化按钮
func setup(ability_instance: GameplayAbilityInstance) -> void:
	_instance = ability_instance

	# 1. 初始图标设置 (支持动态图标特性)
	_update_icon()

	# 2. 监听数据变化 (如图标变化)
	if not _instance.ability_data_changed.is_connected(_on_data_changed):
		_instance.ability_data_changed.connect(_on_data_changed)

	# 3. 初始化快捷键显示 (从 Feature 获取)
	_update_key_text()

	_cd_feature = _instance.get_feature("CooldownFeature")
	if not is_instance_valid(_cd_feature):
		cooldown_overlay.hide()
#endregion
#region 内部实现

func _update_icon() -> void:
	if is_instance_valid(icon):
		icon.texture = _instance.get_current_icon()

func _update_key_text() -> void:
	if not is_instance_valid(key_label): return

	key_label.text = ""
	# 获取 AbilityInputFeature
	var input_feature = _instance.get_feature("AbilityInputFeature")
	if is_instance_valid(input_feature):
		key_label.text = input_feature.get_key_text()
#endregion
#region 信号回调

func _on_data_changed(_ability) -> void:
	_update_icon()

func _on_button_pressed() -> void:
	if not is_instance_valid(_instance): return
	pressed.emit(_instance)
#endregion
