@tool
extends Node2D
class_name BattleHitComboView
#region 原版四位右对齐数字和静态连击标志；场景预置，不生成临时节点
@export var digit_textures: Array[Texture2D] = []
var displayed_count: int = 0
var _tracker: BattleHitComboTracker
var _owner_id: StringName

func bind_tracker(tracker: BattleHitComboTracker, owner_id: StringName) -> void:
	if is_instance_valid(_tracker) and _tracker.combo_changed.is_connected(_on_combo_changed):
		_tracker.combo_changed.disconnect(_on_combo_changed)
	_tracker = tracker
	_owner_id = owner_id
	if _tracker != null:
		_tracker.register_role(owner_id)
		_tracker.combo_changed.connect(_on_combo_changed)
		set_count(_tracker.get_count(owner_id))
	else:
		set_count(0)

func _on_combo_changed(owner_id: StringName, count: int, _maximum: int) -> void:
	if owner_id == _owner_id: set_count(count)

func set_count(count: int) -> void:
	displayed_count = maxi(0, count)
	visible = count > 0
	# 原版最多四位；超出时安全显示9999，运行计数/最高连击不截断。
	var digits := str(mini(displayed_count, 9999))
	for index in range(4):
		var glyph := get_node("Digit%d" % index) as Sprite2D
		var digit_index := digits.length() - 1 - index
		glyph.visible = count > 0 and digit_index >= 0
		if glyph.visible and digit_textures.size() == 10:
			glyph.texture = digit_textures[digits.substr(digit_index, 1).to_int()]
#endregion
