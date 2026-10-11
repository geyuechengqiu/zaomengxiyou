extends Node2D
class_name BattleSuperArmorEffect2D
## 原 ManEntity.createBaiTiEffect：霸体红黄描边，无双优先；独立轮廓不覆盖人物材质。
@export var enabled: bool = true
@export var source_path: NodePath = ^"../SpineVisual"
@export var capture_origin := Vector2(160, 240)
@export var source_fps: float = 30.0
var active: bool = false
var elapsed: float = 0.0
var current_color: Color = Color.RED
var _frames: int = 0
var _frame_time: float = 0.0
var _actor: BattleEntity2D
var _source: SpineSprite
var _adapter: SpineAnimationAdapter
var _skins: Array[StringName] = []
@onready var outline: Sprite2D = $Outline
@onready var viewport: SubViewport = $Capture
@onready var mirror: BattleSpinePoseMirror2D = $Capture/Body

func _ready() -> void:
	_adapter = get_parent() as SpineAnimationAdapter
	_actor = _adapter.get_parent() as BattleEntity2D
	_source = get_node(source_path) as SpineSprite
	_skins = _adapter.get_skin_names()
	_adapter.appearance_changed.connect(_on_appearance_changed)
	outline.texture = viewport.get_texture()
	# 每个实例独立材质；不改源Spine、无双或技能特效的材质/颜色。
	outline.material = outline.material.duplicate()
	outline.offset = -capture_origin
	outline.scale = Vector2.ONE * _adapter.profile.display_scale
	if _actor != null:
		_actor.attributes.vital_depleted.connect(_on_vital_depleted)
		_actor.statuses.status_applied.connect(_on_status_applied)
		_actor.statuses.status_removed.connect(_on_status_removed)

func _on_appearance_changed(skins: Array[StringName]) -> void:
	_skins = skins.duplicate()

func _on_status_applied(_id: StringName, _instance: GameplayStatusInstance) -> void:
	# 只刷新状态，时间仍来自战斗时钟。移除/开启无双也即时刷新优先级。
	advance_effect(0.0)

func _on_status_removed(_id: StringName) -> void:
	advance_effect(0.0)

func _on_vital_depleted(id: StringName) -> void:
	if id == &"health": clear_effect()

func advance_effect(delta: float) -> void:
	if _actor == null or _actor.reactions == null: return
	var show_outline := enabled and _actor.is_alive() and not _actor.is_spawning() and _source.visible and _actor.reactions.is_armored(_actor) and not _actor.statuses.has_status(&"normal_wushuang_visual")
	if not show_outline:
		if active: clear_effect()
		return
	if not active:
		active = true
		outline.visible = true
		_frames = 0
		_frame_time = 0.0
		elapsed = 0.0
		current_color = Color.RED
	elapsed += maxf(0.0, delta)
	_frame_time += maxf(0.0, delta)
	var frames := floori((_frame_time + 0.0000001) * source_fps)
	if frames > 0:
		_frame_time = maxf(0.0, _frame_time - frames / source_fps)
		_frames += frames
		current_color = original_color((_frames - 1) % 22)
	outline.material.set_shader_parameter("outline_color", current_color)
	mirror.capture(_source, capture_origin, _adapter.profile.display_scale, _skins)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

static func original_color(frame: int) -> Color:
	# ColorUtils.changeColorto(...,10)含两个端点，共11色；AS3 int中间赋值将255/10截断为25。
	# ColorFilterAnimation.advanceTime忽略传入delta，每个原游戏帧取一个颜色；0.3参数未使用。
	var index := posmod(frame, 22)
	var green := (255 if index == 10 else index * 25) if index < 11 else (0 if index == 21 else 255 - (index - 11) * 25)
	return Color8(255, green, 0)

func clear_effect() -> void:
	active = false
	elapsed = 0.0
	outline.visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
