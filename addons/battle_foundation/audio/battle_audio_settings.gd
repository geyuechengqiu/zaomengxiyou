extends VBoxContainer
class_name BattleAudioSettings
#region Core音量总线与独立静音；滑条只改变本分类
const TYPES := {"Master": -1, "Music": CoreSystem.AudioManager.AudioType.MUSIC, "Effects": CoreSystem.AudioManager.AudioType.SOUND_EFFECT}
var _refreshing: bool = false

func _ready() -> void:
	for row_name in TYPES:
		var row := get_node(NodePath(row_name))
		(row.get_node("Volume") as HSlider).value_changed.connect(_on_volume.bind(row_name))
		(row.get_node("Volume") as HSlider).drag_ended.connect(func(_changed): CoreSystem.audio_manager.save_preferences())
		(row.get_node("Mute") as CheckButton).toggled.connect(_on_mute.bind(row_name))
	CoreSystem.audio_manager.settings_changed.connect(refresh)
	refresh()

func refresh() -> void:
	_refreshing = true
	var audio := CoreSystem.audio_manager
	for row_name in TYPES:
		var row := get_node(NodePath(row_name))
		var type: int = TYPES[row_name]
		var volume: float = audio.get_master_volume() if type == -1 else audio.get_volume(type)
		(row.get_node("Volume") as HSlider).set_value_no_signal(roundi(volume * 100))
		(row.get_node("Value") as Label).text = "%d%%" % roundi(volume * 100)
		(row.get_node("Mute") as CheckButton).set_pressed_no_signal(audio.is_master_muted() if type == -1 else audio.is_muted(type))
	_refreshing = false

func _on_volume(value: float, row_name: String) -> void:
	if _refreshing: return
	var type: int = TYPES[row_name]
	if type == -1: CoreSystem.audio_manager.set_master_volume(value / 100.0)
	else: CoreSystem.audio_manager.set_volume(type, value / 100.0)

func _on_mute(muted: bool, row_name: String) -> void:
	if _refreshing: return
	var type: int = TYPES[row_name]
	if type == -1: CoreSystem.audio_manager.set_master_muted(muted)
	else: CoreSystem.audio_manager.set_muted(type, muted)
	CoreSystem.audio_manager.save_preferences()

func _exit_tree() -> void:
	if CoreSystem.audio_manager.settings_changed.is_connected(refresh): CoreSystem.audio_manager.settings_changed.disconnect(refresh)
#endregion
