extends Node2D
class_name BattleBossFeedback2D
#region 全场共享的Boss血条、播报、声音与镜头；不属于任何角色
@export var camera_path: NodePath = ^"../../../Camera2D"
@export var shake_strength: float = 3.0
@export var sound_enabled: bool = true
@export var bar_textures: Array[Texture2D] = []
@export var victory_sound: AudioStream
@export var defeat_sound: AudioStream
## 原版普通白色、困难金色、地狱粉红色；调试数值默认隐藏。
@export_enum("普通", "困难", "地狱") var difficulty: int = 0
@export var show_debug_values: bool = false
@export var resistance_add_textures: Array[Texture2D] = []
@export var resistance_remove_textures: Array[Texture2D] = []
const RESISTANCE_IDS: Array[StringName] = [&"lightResist", &"darkResist", &"waterResist", &"fireResist", &"woodResist", &"soilResist", &"windResist", &"rayResist"]
const RESISTANCE_NAMES: Array[String] = ["光抗", "暗抗", "水抗", "火抗", "木抗", "土抗", "风抗", "雷抗"]
@onready var bar: Control = $HUD/BossBar
@onready var fill: TextureProgressBar = $HUD/BossBar/Fill
@onready var next_fill: TextureRect = $HUD/BossBar/NextFill
@onready var name_label: Label = $HUD/BossBar/Name
@onready var health_label: Label = $HUD/BossBar/Health
@onready var count_label: Label = $HUD/BossBar/Count
@onready var protect: TextureProgressBar = $HUD/BossBar/Protection
@onready var protect_label: Label = $HUD/BossBar/ProtectionValue
@onready var resistance_slots: Control = $HUD/BossBar/Resistances
@onready var banner: Sprite2D = $HUD/Announcement
@onready var warning: Polygon2D = $Warning
@onready var music: AudioStreamPlayer = $Music
@onready var hit_audio: AudioStreamPlayer = $HitAudio
@onready var result_audio: AudioStreamPlayer = $ResultAudio
var _session: BattleSession
var _boss: WeakRef
var _request_id: int = -1
var _request_actor: StringName
var _announcement_started: bool = false
var banner_age: float = INF
var announcement_count: int = 0
var warning_remaining: float = 0.0
var _last_hp: int = -1
var _last_max: int = -1
var _last_score: int = -1
var _hp_from: float = 1.0
var _hp_to: float = 1.0
var _hp_age: float = 0.6
var _protect_from: float = 0
var _protect_to: float = 0
var _protect_age: float = 0.3
var _death_remaining: float = 1.0
var _shake_age: float = INF
var _shaking: bool = false
var _camera: Camera2D
var _camera_offset: Vector2
var _last_sound_tick: int = -1
var _header_snapshot: Array = []

func _ready() -> void:
	_session = get_parent().get_parent() as BattleSession
	assert(_session != null, "Boss公共表现必须归属BattlePresentation")
	bar.visible = false
	banner.visible = false
	warning.visible = false
	_camera = get_node_or_null(camera_path) as Camera2D
	if _camera != null: _camera_offset = _camera.offset
	CoreSystem.audio_manager.bind_scene_player(music,CoreSystem.AudioManager.AudioType.MUSIC)
	CoreSystem.audio_manager.bind_scene_player(hit_audio,CoreSystem.AudioManager.AudioType.SOUND_EFFECT)
	CoreSystem.audio_manager.bind_scene_player(result_audio,CoreSystem.AudioManager.AudioType.SOUND_EFFECT)
	music.finished.connect(_repeat_music)
	CoreSystem.event_bus.event_pushed.connect(_on_event)

func _exit_tree() -> void:
	clear_feedback()
	if CoreSystem.event_bus.event_pushed.is_connected(_on_event): CoreSystem.event_bus.event_pushed.disconnect(_on_event)
#endregion
#region 原版三条血量与0.6/0.3秒缓动
func bind_boss(actor: BattleEntity2D) -> void:
	_boss = weakref(actor)
	_last_hp = -1
	_last_max = -1
	_last_score = -1
	_header_snapshot.clear()
	_death_remaining = 1
	bar.visible = true
	_refresh_header(actor)
	if sound_enabled: music.play()
	_refresh_bar(actor, true)

func _repeat_music() -> void:
	var actor := _boss.get_ref() as BattleEntity2D if _boss != null else null
	if sound_enabled and is_instance_valid(actor) and actor.is_alive(): music.play()

func _refresh_bar(actor: BattleEntity2D, immediate: bool = false) -> void:
	_refresh_header(actor)
	health_label.visible = show_debug_values
	var hp := maxi(0, roundi(actor.attributes.get_vital_value(&"health")))
	var maximum := maxi(1, roundi(actor.attributes.get_value(&"hpMax")))
	var count: int = actor.ai_controller.boss_profile.health_bar_count
	var per := float(maximum)/count
	var remaining := ceili(hp/per)
	var ratio := (hp-(remaining-1)*per)/per if remaining > 0 else 0.0
	if hp != _last_hp or maximum != _last_max:
		var previous_bars := ceili(maxi(0,_last_hp)/(float(maxi(1,_last_max))/count))
		if immediate or previous_bars != remaining: fill.value = 1.0 if remaining > 0 else 0.0
		_hp_from = fill.value
		_hp_to = ratio
		_hp_age = 0.6 if immediate else 0.0
		_last_hp = hp
		_last_max = maximum
		var index := clampi(count-remaining,0,count-1)
		if not bar_textures.is_empty():
			fill.texture_progress = bar_textures[index%bar_textures.size()]
			next_fill.texture = bar_textures[(index+1)%bar_textures.size()]
		next_fill.visible = remaining > 1
		count_label.text = "X%d" % remaining
		health_label.text = "%d / %d" % [hp,maximum]
	var protection := actor.protection
	protect.visible = protection.show_protect
	protect_label.visible = show_debug_values and protection.show_protect
	if protection.show_protect and (protection.score != _last_score or immediate):
		_protect_from = protect.value
		_protect_to = clampf(float(protection.score)/maxi(1,protection.maximum),0,1)
		_protect_age = 0.3 if immediate else 0.0
		_last_score = protection.score
	protect_label.text = "保护中" if protection.active else "保护 %d / %d" % [protection.score, protection.maximum]

func _refresh_header(actor: BattleEntity2D) -> void:
	var values: Array = [actor.ai_controller.boss_profile.display_name, difficulty]
	for id in RESISTANCE_IDS: values.append(roundi(actor.attributes.get_value(id)))
	if values == _header_snapshot: return
	_header_snapshot = values
	name_label.text = values[0]
	name_label.modulate = [Color.WHITE, Color.hex(0xffe00dff), Color.hex(0xf700eeff)][clampi(difficulty, 0, 2)]
	var font := name_label.get_theme_font(&"font")
	var width := font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	name_label.size.x = width + 4
	var slot_index := 0
	for index in range(RESISTANCE_IDS.size()):
		var value: int = values[index+2]
		if value == 0: continue
		var slot := resistance_slots.get_child(slot_index) as TextureRect
		var textures := resistance_add_textures if value > 0 else resistance_remove_textures
		slot.texture = textures[index] if index < textures.size() else null
		slot.visible = slot.texture != null
		if slot.texture != null:
			# BossBleed/IconBase：名称文本宽度+26，居中注册，间隔30像素。
			slot.size = slot.texture.get_size()
			slot.position = Vector2(-97 + width + 26 + slot_index*30, 12.1) - slot.size/2
			slot.tooltip_text = "%s %+d" % [RESISTANCE_NAMES[index], value]
		slot_index += 1
	for index in range(slot_index, resistance_slots.get_child_count()): resistance_slots.get_child(index).visible = false

func advance_feedback(delta: float) -> void:
	var actor := _boss.get_ref() as BattleEntity2D if _boss != null else null
	if is_instance_valid(actor):
		_refresh_bar(actor)
		if not actor.is_alive():
			_death_remaining = maxf(0, _death_remaining-delta)
			if _death_remaining <= 0: bar.visible = false
	else: bar.visible = false
	if delta <= 0: return
	_hp_age = minf(0.6,_hp_age+delta)
	_protect_age = minf(0.3,_protect_age+delta)
	fill.value = lerpf(_hp_from,_hp_to,1-pow(1-_hp_age/0.6,2))
	protect.value = lerpf(_protect_from,_protect_to,1-pow(1-_protect_age/0.3,2))
	if banner.visible:
		banner_age += delta
		var t := clampf(banner_age/(7.0/30.0),0,1)
		banner.position = Vector2(lerpf(-100,350,t),80)
		banner.modulate.a = t
		if banner_age >= 2:
			t = clampf((banner_age-2)/(7.0/30.0),0,1)
			banner.position.x = lerpf(350,627,t)
			banner.modulate.a = 1-t
		if banner_age >= 2+8.0/30.0: banner.visible = false
	warning_remaining = maxf(0, warning_remaining-delta)
	warning.visible = warning_remaining > 0
	if _shaking and is_instance_valid(_camera):
		_shake_age += delta
		var strength := shake_strength*maxf(0,1-_shake_age/0.18)
		_camera.offset = _camera_offset+Vector2(sin(_shake_age*170),cos(_shake_age*143))*strength
		if _shake_age >= 0.18:
			_camera.offset = _camera_offset
			_shaking = false

func _start_shake() -> void:
	if not is_instance_valid(_camera) or shake_strength <= 0: return
	if not _shaking: _camera_offset = _camera.offset
	_shake_age = 0
	_shaking = true
#endregion
#region Core事件与可选预警；播报不决定真实命中
func _on_event(id: String, payload: Array) -> void:
	if payload.size() != 1 or not payload[0] is Dictionary or payload[0].get("battle_id") != _session.battle_id: return
	var data: Dictionary = payload[0]
	if id == "battle.boss.registered":
		var actor := _session.get_entity(data.source_entity_id) as BattleEntity2D
		if actor != null: bind_boss(actor)
	elif id == "battle.boss.announced":
		_request_id = data.request_id
		_request_actor = data.source_entity_id
		_announcement_started = false
		banner.texture = data.get("announcement") as Texture2D
		banner_age = 0
		banner.position = Vector2(-100,80)
		banner.modulate.a = 0
		banner.visible = banner.texture != null
		announcement_count += 1
		var rect: Rect2 = data.get("warning_rect",Rect2())
		warning_remaining = float(data.lead_seconds)
		if rect.size.x > 0 and rect.size.y > 0:
			var origin: Vector2 = data.origin
			var points := PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
			for index in range(points.size()): points[index] = origin+Vector2(points[index].x*int(data.facing),points[index].y)
			warning.polygon = points
			warning.visible = warning_remaining > 0
	elif id == "battle.boss.action_started" and data.source_entity_id == _request_actor and data.request_id == _request_id:
		_announcement_started = true
	elif id == "battle.boss.announcement_cancelled" and data.source_entity_id == _request_actor and data.request_id == _request_id:
		# 原版SkillComing由独立UI时间轴播放；动作被打断不删除已开始的播报。
		if not _announcement_started: banner.visible = false
		warning.visible = false
		warning_remaining = 0
	elif id == "battle.boss.objects_spawned" and data.object_id == &"jade_wall": _start_shake()
	elif id == "battle.protection.triggered": _start_shake()
	elif id == "battle.attack.hit" and sound_enabled and data.get("actual_hp_loss",0) > 0 and _last_sound_tick != _session.clock.physics_tick:
		_last_sound_tick = _session.clock.physics_tick
		hit_audio.play()
	elif id in ["battle.level.victory","battle.level.failed"]:
		banner.visible = false
		warning.visible = false
		music.stop()
		if sound_enabled:
			result_audio.stream = victory_sound if id == "battle.level.victory" else defeat_sound
			result_audio.play()
	elif id == "battle.entity.killed" or id == "battle.entity_despawned":
		var boss := _boss.get_ref() as BattleEntity2D if _boss != null else null
		if boss != null and data.target_entity_id == boss.entity_id:
			banner.visible = false
			warning.visible = false
			music.stop()

func synchronize_pause(blocked: bool) -> void:
	music.stream_paused = blocked
	hit_audio.stream_paused = blocked
	result_audio.stream_paused = blocked

func clear_feedback() -> void:
	_boss = null
	if is_instance_valid(bar): bar.visible = false
	if is_instance_valid(banner): banner.visible = false
	if is_instance_valid(warning): warning.visible = false
	if is_instance_valid(music): music.stop()
	if is_instance_valid(hit_audio): hit_audio.stop()
	if is_instance_valid(result_audio): result_audio.stop()
	if _shaking and is_instance_valid(_camera): _camera.offset = _camera_offset
	_shaking = false
	_shake_age = INF
#endregion
