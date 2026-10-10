extends Node
signal settings_changed
#region 类型与常量

## 音频类型枚举
enum AudioType {
	MUSIC,				## 背景音乐
	SOUND_EFFECT,		## 音效
	VOICE,				## 语音
	AMBIENT,			## 环境音
}
# 配置键名常量 (推荐)
const MASTER_VOLUME_KEY = "master_volume"
const MUSIC_VOLUME_KEY = "music_volume"
const SFX_VOLUME_KEY = "sfx_volume"
const VOICE_VOLUME_KEY = "voice_volume"
const AMBIENT_VOLUME_KEY = "ambient_volume"

# 将类型映射到配置键 (可选，但有助于一致性)
const TYPE_TO_CONFIG_KEY = {
	AudioType.MUSIC: MUSIC_VOLUME_KEY,
	AudioType.SOUND_EFFECT: SFX_VOLUME_KEY,
	AudioType.VOICE: VOICE_VOLUME_KEY,
	AudioType.AMBIENT: AMBIENT_VOLUME_KEY,
}
## 音频通道配置
const DEFAULT_BUSES = {
	AudioType.MUSIC: "Music",			## 背景音乐通道
	AudioType.SOUND_EFFECT: "SFX",		## 音效通道
	AudioType.VOICE: "Voice",			## 语音通道
	AudioType.AMBIENT: "Ambient",		## 环境音通道
}
#endregion
#region 配置与运行状态

## 音频节点根节点
var audio_node_root: Node = null

## 音频播放器池
var _audio_players: Dictionary = {}
## 当前播放的音乐
var _current_music: AudioStreamPlayer = null
## 音频资源缓存
var _audio_cache: Dictionary = {}
## 音量设置
var _volumes: Dictionary = {}
## 主音量设置
var _master_volume: float = 1.0
var _muted: Dictionary = {}
var _master_muted: bool = false
var _music_tweens: Dictionary = {}
const MAX_PLAYERS := {AudioType.MUSIC: 2, AudioType.SOUND_EFFECT: 32, AudioType.VOICE: 16, AudioType.AMBIENT: 8}

var _config_manager : CoreSystem.ConfigManager = CoreSystem.config_manager
var _logger : CoreSystem.CoreLogger = CoreSystem.logger
#endregion
#region 生命周期与引擎回调

func _ready() -> void:
	# 设置默认值
	audio_node_root = self
	_setup_audio_buses()
	
	# 从配置加载主音量 (使用统一定义的 Key)
	_master_volume = _config_manager.get_value("audio", MASTER_VOLUME_KEY, 1.0)
	set_master_volume(_master_volume) # 应用加载的值 (仅应用到AudioServer和内部变量)

	# 从配置加载分类音量 (使用统一定义的 Key)
	for type in AudioType.values():
		var config_key = TYPE_TO_CONFIG_KEY.get(type)
		if config_key:
			_volumes[type] = _config_manager.get_value("audio", config_key, 1.0)
			set_volume(type, _volumes[type]) # 应用加载的值 (仅应用到AudioServer和内部变量)
		_audio_players[type] = []
		set_muted(type, bool(_config_manager.get_value("audio", DEFAULT_BUSES[type].to_lower() + "_muted", false)))
	set_master_muted(bool(_config_manager.get_value("audio", "master_muted", false)))
#endregion
#region 公共接口

## 角色/关卡场景预置播放器接入Core音量总线；节点仍由原场景管理。
## 不写入全局工厂池，不修改播放器的设计音量，不影响其他战斗会话。
func bind_scene_player(player: AudioStreamPlayer, type: AudioType) -> bool:
	if not is_instance_valid(player) or not DEFAULT_BUSES.has(type):
		return false
	var bus: String = DEFAULT_BUSES[type]
	if AudioServer.get_bus_index(bus) < 0:
		return false
	player.bus = bus
	return true

## 预加载音频资源
## [param path] 音频路径
## [param type] 音频类型
func preload_audio(path: String, type: AudioType) -> void:
	if not _audio_cache.has(path):
		var audio_resource = load(path)
		if audio_resource:
			_audio_cache[path] = {
				"resource": audio_resource,
				"type": type
			}

## 播放音乐
## [param path] 音频路径
## [param fade_duration] 淡出持续时间
## [param loop] 是否循环 如果音频导入时设置为循环播放，则将一直循环，哪怕loop参数设置为false
func play_music(path: String, fade_duration: float = 1.0, loop: bool = true) -> void:
	if _current_music and _current_music.playing:
		_fade_out_music(fade_duration)
	
	# 断开旧音乐的finished信号连接
	if _current_music and _current_music.is_connected("finished", _on_music_finished):
		_current_music.disconnect("finished", _on_music_finished)
	
	var audio_resource = _get_audio_resource(path)
	if audio_resource:
		_current_music = _get_audio_player(AudioType.MUSIC)
		_current_music.stream = audio_resource
		_current_music.bus = DEFAULT_BUSES[AudioType.MUSIC]
		_current_music.volume_db = 0.0
		# 循环开关属于本次播放实例，不修改缓存及其他实例共用的流。
		if _is_audio_loop(audio_resource) and not loop:
			_current_music.stream = audio_resource.duplicate()
			if _current_music.stream is AudioStreamWAV: _current_music.stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
			else: _current_music.stream.loop = false
		_current_music.play()
		
		# 连接循环信号
		if loop:
			_current_music.connect("finished", _on_music_finished)
		
		if fade_duration > 0:
			_fade_in_music(fade_duration)

## 播放音效
## [param path] 音频路径
## [param volume] 音量
## [return] 音频播放器
func play_sound(path: String, volume: float = 1.0) -> AudioStreamPlayer:
	var audio_resource = _get_audio_resource(path)
	if audio_resource:
		var player = _get_audio_player(AudioType.SOUND_EFFECT)
		player.stream = audio_resource
		player.bus = DEFAULT_BUSES[AudioType.SOUND_EFFECT]
		player.volume_db = linear_to_db(clampf(volume, 0.0, 1.0)) if volume > 0 else -80.0
		player.play()
		return player
	return null

## 播放语音
## [param path] 音频路径
## [param volume] 音量
## [return] 音频播放器
func play_voice(path: String, volume: float = 1.0) -> AudioStreamPlayer:
	var audio_resource = _get_audio_resource(path)
	if audio_resource:
		var player = _get_audio_player(AudioType.VOICE)
		player.stream = audio_resource
		player.bus = DEFAULT_BUSES[AudioType.VOICE]
		player.volume_db = linear_to_db(clampf(volume, 0.0, 1.0)) if volume > 0 else -80.0
		player.play()
		return player
	return null

## 设置主音量
## [param volume] 音量
func set_master_volume(volume: float) -> bool:
	var bus_name : String = "Master"
	_master_volume = clamp(volume, 0.0, 1.0)
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(_master_volume) if _master_volume > 0 else -80.0)
		_config_manager.set_value("audio", MASTER_VOLUME_KEY, _master_volume)
		settings_changed.emit()
		return true
	_logger.error("AudioManager: 未找到名为 '%s' 的主音频总线!" % bus_name)
	return false

## 设置音量
## [param type] 音频类型
## [param volume] 音量
func set_volume(type: AudioType, volume: float) -> bool:
	if not DEFAULT_BUSES.has(type): return false
	_volumes[type] = clamp(volume, 0.0, 1.0)
	var bus_name : String = DEFAULT_BUSES[type]
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(_volumes[type]) if _volumes[type] > 0 else -80.0)
		_config_manager.set_value("audio", TYPE_TO_CONFIG_KEY[type], _volumes[type])
		settings_changed.emit()
		return true
	_logger.error("AudioManager: 未找到名为 '%s' 的音频总线!" % bus_name)
	return false

## 获取音量
## [param type] 音频类型
## [return] 音量
func get_volume(type: AudioType) -> float:
	return float(_volumes.get(type, 1.0))

## 静音与音量分开保存；取消静音恢复原滑条数值，并立即影响正在播放的声音。
func set_muted(type: AudioType, muted: bool) -> bool:
	if not DEFAULT_BUSES.has(type): return false
	var bus_index := AudioServer.get_bus_index(DEFAULT_BUSES[type])
	if bus_index < 0: return false
	_muted[type] = muted
	AudioServer.set_bus_mute(bus_index, muted)
	_config_manager.set_value("audio", DEFAULT_BUSES[type].to_lower() + "_muted", muted)
	settings_changed.emit()
	return true

func is_muted(type: AudioType) -> bool:
	return bool(_muted.get(type, false))

func set_master_muted(muted: bool) -> void:
	_master_muted = muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
	_config_manager.set_value("audio", "master_muted", muted)
	settings_changed.emit()

func is_master_muted() -> bool:
	return _master_muted

func save_preferences() -> bool:
	return _config_manager.save_config()

## 获取主音量
## [return] 主音量
func get_master_volume() -> float:
	return _master_volume

## 停止所有音频
func stop_all() -> void:
	for tween: Tween in _music_tweens.values(): tween.kill()
	_music_tweens.clear()
	if _current_music:
		_current_music.stop()
	
	for type in _audio_players:
		for player in _audio_players[type]:
			player.stop()

## 根据总线名称获取音频类型
## [param bus_name] 音频总线名称 (例如 "Music", "SFX")
## [return] AudioType 枚举值，如果找不到则返回 null
func get_audio_type_from_bus_name(bus_name: String) -> AudioType:
	for type in DEFAULT_BUSES:
		if DEFAULT_BUSES[type] == bus_name:
			return type
	_logger.error("AudioManager: 未找到名为 '%s' 的音频总线!" % bus_name)
	return AudioType.SOUND_EFFECT
#endregion
#region 内部实现

## 获取音频资源
## [param path] 音频路径
## [return] 音频资源
func _get_audio_resource(path: String) -> AudioStream:
	if _audio_cache.has(path):
		return _audio_cache[path].resource
	
	var audio_resource = load(path)
	if audio_resource:
		_audio_cache[path] = {
			"resource": audio_resource,
			"type": AudioType.SOUND_EFFECT
		}
		return audio_resource
	return null

## 获取音频播放器
## [param type] 音频类型
## [return] 音频播放器
func _get_audio_player(type: AudioType) -> AudioStreamPlayer:
	# 查找空闲的播放器
	for player in _audio_players[type]:
		if not player.playing:
			return player
	# 高频音效只复用有界池；优先替换最早创建的忙碌播放器。
	if _audio_players[type].size() >= int(MAX_PLAYERS[type]):
		var oldest := _audio_players[type].pop_front() as AudioStreamPlayer
		if _music_tweens.has(oldest):
			(_music_tweens[oldest] as Tween).kill()
			_music_tweens.erase(oldest)
		oldest.stop()
		_audio_players[type].append(oldest)
		return oldest
	
	# 创建新的播放器
	var new_player = AudioStreamPlayer.new()
	audio_node_root.add_child(new_player)
	_audio_players[type].append(new_player)
	return new_player

## 淡出音乐
## [param duration] 淡出持续时间
func _fade_out_music(duration: float) -> void:
	if _current_music:
		var player := _current_music
		if _music_tweens.has(player): (_music_tweens[player] as Tween).kill()
		if duration <= 0.0:
			player.stop()
			_music_tweens.erase(player)
			return
		var tween = audio_node_root.create_tween()
		_music_tweens[player] = tween
		tween.tween_property(player, "volume_db", -80.0, duration)
		tween.tween_callback(func(): player.stop(); _music_tweens.erase(player))

## 淡入音乐
## [param duration] 淡入持续时间
func _fade_in_music(duration: float) -> void:
	if _current_music:
		var player := _current_music
		if _music_tweens.has(player): (_music_tweens[player] as Tween).kill()
		player.volume_db = -80.0
		var tween = audio_node_root.create_tween()
		_music_tweens[player] = tween
		tween.tween_property(player, "volume_db", 0.0, duration)
		tween.tween_callback(func(): _music_tweens.erase(player))

## 设置音频扬声器
func _setup_audio_buses():
	# var audio_bus_layout = AudioServer.get_bus_layout()
	
	for type in DEFAULT_BUSES:
		var bus_name = DEFAULT_BUSES[type]
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var bus_idx = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(bus_idx, bus_name)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(1.0))
#endregion
#region 信号回调

## 音乐播放完毕回调
func _on_music_finished() -> void:
	if _current_music:
		_current_music.play()
#endregion
#region 内部实现

## 判断音频是否循环
func _is_audio_loop(audio:AudioStream)->bool:
	if audio == null:
		return false
	
	if audio is AudioStreamWAV:
		return audio.loop_mode != AudioStreamWAV.LoopMode.LOOP_DISABLED
	elif audio is AudioStreamMP3 or audio is AudioStreamOggVorbis or audio is AudioStreamPlaylist:
		return audio.loop
	
	return false
#endregion
