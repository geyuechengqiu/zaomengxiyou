extends Node
class_name BattleAudio
#region 预置公共播放器、原版目录与会话隔离
@export var catalog: JSON
@onready var music: AudioStreamPlayer = $Music
var session: BattleSession
var current_music: String = ""
var played_count: int = 0
var last_sound: String = ""
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _streams: Dictionary = {}
var _actors: Dictionary = {}
var _callbacks: Dictionary = {}
var _channels: Dictionary = {}
var _zones_entered: Dictionary = {}
var _level_finished: bool = false
var _boss_music_owner: StringName = &""

func _ready() -> void:
	session = get_parent().get_parent() as BattleSession
	assert(session != null and catalog != null, "公共音频需要预置于BattlePresentation并绑定原版目录")
	CoreSystem.audio_manager.bind_scene_player(music, CoreSystem.AudioManager.AudioType.MUSIC)
	# 常用资源在关卡加载阶段缓存，首次命中或拾取不再触发磁盘加载。
	for path in catalog.data.packs.get("hs", {}).values(): _stream(String(path))
	for pack in catalog.data.level_music.values(): _stream(resolve_sound(String(pack), "music"))
	_stream(resolve_sound(String(catalog.data.boss_music), "music"))
	for child in $Effects.get_children():
		var player := child as AudioStreamPlayer
		assert(player != null)
		CoreSystem.audio_manager.bind_scene_player(player, CoreSystem.AudioManager.AudioType.SOUND_EFFECT)
		_voices.append(player)
	music.finished.connect(_repeat_music)
	CoreSystem.event_bus.event_pushed.connect(_on_event)

func register_actor(actor: BattleEntity2D) -> void:
	if actor.session != session or _actors.has(actor.entity_id): return
	var animation := actor.get_node(actor.animation_path) as CharacterAnimationAdapter
	var action_callback := _on_action.bind(actor.entity_id)
	var level_callback := _on_level_changed.bind(actor.entity_id)
	_actors[actor.entity_id] = weakref(actor)
	_callbacks[actor.entity_id] = [animation, action_callback, actor.attributes, level_callback]
	animation.action_started.connect(action_callback)
	actor.attributes.level_changed.connect(level_callback)
	if actor.ai_controller is BattleBossController2D: _boss_music_owner = actor.entity_id
	var pack := String(catalog.data.units.get(String(actor.definition_id), "")).get_file().get_basename()
	for action in animation.profile.animations.values(): _stream(resolve_sound(pack, String(action)))
	if actor.inventory is OriginalInventory:
		var growth_callback := _on_growth.bind(actor.entity_id)
		actor.inventory.growth_completed.connect(growth_callback)
		_callbacks[actor.entity_id].append_array([actor.inventory, growth_callback])

func remove_actor(id: StringName) -> void:
	if _callbacks.has(id):
		var callbacks: Array = _callbacks[id]
		if is_instance_valid(callbacks[0]) and callbacks[0].action_started.is_connected(callbacks[1]): callbacks[0].action_started.disconnect(callbacks[1])
		if is_instance_valid(callbacks[2]) and callbacks[2].level_changed.is_connected(callbacks[3]): callbacks[2].level_changed.disconnect(callbacks[3])
		if callbacks.size() == 6 and is_instance_valid(callbacks[4]) and callbacks[4].growth_completed.is_connected(callbacks[5]): callbacks[4].growth_completed.disconnect(callbacks[5])
		_callbacks.erase(id)
	_actors.erase(id)
	_stop_actor_channel(id)

func _actor(id: StringName) -> BattleEntity2D:
	return _actors[id].get_ref() as BattleEntity2D if _actors.has(id) else null
#endregion
#region 语义动作与公共战斗声音
func _on_action(action: StringName, id: StringName) -> void:
	_stop_actor_channel(id)
	var actor := _actor(id)
	if actor == null or _level_finished or session.is_simulation_blocked(): return
	var pack := String(catalog.data.units.get(String(actor.definition_id), "")).get_file().get_basename()
	var symbol := String(actor.animation.profile.animations.get(action, action))
	var path := resolve_sound(pack, symbol)
	if not path.is_empty():
		var player := play_effect(path)
		if player != null: _channels[id] = player

func _on_level_changed(previous: int, next: int, id: StringName) -> void:
	var actor := _actor(id)
	if actor != null and actor.faction_id == &"player" and next > previous:
		play_common("levlUp")

func _on_growth(_item: Item, operation: StringName, id: StringName) -> void:
	if _actor(id) != null and operation == &"enhance": play_common("strengthen")

func _stop_actor_channel(id: StringName) -> void:
	if _channels.has(id):
		var player := _channels[id] as AudioStreamPlayer
		if is_instance_valid(player): player.stop()
		_channels.erase(id)

func resolve_sound(pack: String, symbol: String) -> String:
	return String(catalog.data.packs.get(pack, {}).get(symbol, ""))

func _stream(path: String) -> AudioStream:
	if path.is_empty(): return null
	if not _streams.has(path): _streams[path] = load(path) as AudioStream
	return _streams[path] as AudioStream

func play_common(symbol: String) -> AudioStreamPlayer:
	return play_effect(resolve_sound("hs", symbol))

func play_effect(path: String) -> AudioStreamPlayer:
	var stream := _stream(path)
	if stream == null or _voices.is_empty(): return null
	var player: AudioStreamPlayer
	for candidate in _voices:
		if not candidate.playing: player = candidate; break
	if player == null:
		player = _voices[_next_voice]
		_next_voice = (_next_voice + 1) % _voices.size()
	# 槽位复用后旧角色不能停止新声音。
	for id in _channels.keys():
		if _channels[id] == player: _channels.erase(id)
	player.stop()
	player.stream = stream
	player.volume_db = 0.0
	player.stream_paused = false
	player.play()
	played_count += 1
	last_sound = path
	return player

func _on_event(event_id: String, payload: Array) -> void:
	if payload.size() != 1 or not payload[0] is Dictionary or payload[0].get("battle_id") != session.battle_id: return
	var data: Dictionary = payload[0]
	if event_id == "battle.level_started":
		_level_finished = false
		_zones_entered.clear()
		play_music(String(catalog.data.level_music.get(String(data.level_id), "")))
	elif event_id == "battle.loot.picked_up": play_common("pickup")
	elif event_id == "battle.attack.hit" or (event_id == "battle.damage.settled" and not data.get("defer_attack_feedback", false)):
		if not data.get("is_dodged", false) and not data.get("is_immune", false) and float(data.get("actual_hp_loss", 0)) + float(data.get("shield_absorbed", 0)) > 0:
			play_common("hit")
	elif event_id in ["battle.level.victory", "battle.level.failed"]:
		if _level_finished: return
		_level_finished = true
		music.stop()
		current_music = ""
		for player in _voices: player.stop()
		_channels.clear()
		play_common("win" if event_id == "battle.level.victory" else "lose")
	elif event_id == "battle.entity_died":
		var dead_id: StringName = data.get("source_entity_id", &"")
		_stop_actor_channel(dead_id)
		if dead_id == _boss_music_owner:
			music.stop()
			current_music = ""
	elif event_id == "battle.audio.effect":
		play_effect(resolve_sound(String(data.get("pack", "hs")), String(data.get("symbol", ""))))
#endregion
#region 地图音乐触发区、暂停及离场
func play_music(pack: String) -> void:
	if pack == current_music and music.playing: return
	var stream := _stream(resolve_sound(pack, "music"))
	if stream == null: return
	music.stop()
	music.stream = stream
	music.volume_db = 0.0
	music.stream_paused = false
	current_music = pack
	music.play()

func _repeat_music() -> void:
	if not _level_finished and not current_music.is_empty(): music.play()

func advance_audio() -> void:
	var blocked := session.is_simulation_blocked()
	music.stream_paused = blocked
	for player in _voices: player.stream_paused = blocked
	if blocked or _level_finished: return
	var zones: Array = catalog.data.music_zones.get(String(session.current_level_id), [])
	for index in range(zones.size()):
		if _zones_entered.has(index): continue
		var values: Array = zones[index].rect
		var rect := Rect2(values[0], values[1], values[2], values[3])
		for ref: WeakRef in _actors.values():
			var actor := ref.get_ref() as BattleEntity2D
			if actor != null and actor.faction_id == &"player" and actor.is_alive() and rect.intersects(actor.get_body_rect_global()):
				_zones_entered[index] = true
				play_music(String(zones[index].music))
				break

func clear_audio() -> void:
	music.stop()
	current_music = ""
	for player in _voices: player.stop()
	for id in _actors.keys(): remove_actor(id)
	_zones_entered.clear()
	_streams.clear()
	_level_finished = true
	_boss_music_owner = &""

func _exit_tree() -> void:
	clear_audio()
	if CoreSystem.event_bus.event_pushed.is_connected(_on_event): CoreSystem.event_bus.event_pushed.disconnect(_on_event)
#endregion
