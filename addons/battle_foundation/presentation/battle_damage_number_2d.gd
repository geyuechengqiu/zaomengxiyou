@tool
extends Node2D
class_name BattleDamageNumber2D
#region 数字外观与独立释放状态
const DURATION: float = 0.9
@export var number: int = 80:
	set(value):
		var next := maxi(0, value)
		if number == next:
			return
		number = next
		_refresh_glyphs()
@export_enum("normal", "critical", "true", "true_critical", "player", "dodge", "normal_double", "critical_double", "special", "kill", "heal", "mana") var style: String = "normal":
	set(value):
		if style == value:
			return
		style = value
		_refresh_glyphs()
@onready var glyphs: BattleDamageNumberGlyphs = $Glyphs
var elapsed: float = 0.0
var finished: bool = false
var recycle_callback: Callable
var pool_index: int = -1
var pool_generation: int = 0
var has_started: bool = false
var spawn_order: int = 0
var _phase: int = -1
#endregion
#region 原版连续 Quad.easeOut 补间
func _ready() -> void:
	_refresh_glyphs()
	if not Engine.is_editor_hint():
		_start_fly()

func _start_fly() -> void:
	has_started = true
	elapsed = 0.0
	finished = false
	_phase = -1
	glyphs.modulate = Color.WHITE
	visible = true
	_sample_fly(0.0)
	# 直接按战斗时钟采样Tween曲线，不为每条跳字分配Tween/Tweener对象。

func _sample_fly(time: float) -> void:
	var q: float
	if time <= 0.2:
		q = float(Tween.interpolate_value(0.0, 1.0, time, 0.2, Tween.TRANS_QUAD, Tween.EASE_OUT))
		glyphs.position = Vector2(-20, -100) * q
		glyphs.scale = Vector2.ONE * (0.8 + 0.2 * q)
		_phase = 0
	elif time <= 0.3:
		if _phase != 1:
			glyphs.position = Vector2(-20, -100)
			glyphs.scale = Vector2.ONE
		_phase = 1
	else:
		q = float(Tween.interpolate_value(0.0, 1.0, minf(time, DURATION) - 0.3, 0.6, Tween.TRANS_QUAD, Tween.EASE_OUT))
		glyphs.position = Vector2(-20, -100) + Vector2(20, 40) * q
		if _phase != 2:
			glyphs.scale = Vector2.ONE
		_phase = 2
		glyphs.modulate.a = 1.0 - 0.8 * q

func advance_number(delta: float) -> void:
	if finished or delta <= 0.0:
		return
	elapsed += delta
	_sample_fly(minf(elapsed, DURATION))
	if elapsed + 0.000000001 >= DURATION:
		# 浮点边界也确保末帧落在原版终点。
		glyphs.position = Vector2(0, -60)
		glyphs.scale = Vector2.ONE
		glyphs.modulate.a = 0.2
		finished = true
		visible = false
		if recycle_callback.is_valid():
			recycle_callback.call(self)
		else:
			queue_free()
#endregion
#region 数字外观与生命周期
func _refresh_glyphs() -> void:
	var display := glyphs
	if display == null:
		display = get_node_or_null(^"Glyphs") as BattleDamageNumberGlyphs
	if display != null:
		display.number = number
		display.style = style

#endregion
