extends Node
#region 信号
#Monitor built-in logs

signal error_msg_received(msg:String)
signal warning_msg_received(msg:String)
signal info_msg_received(msg:String)
#endregion
#region 类型与常量

const UPDATE_INTERVAL := 0.1
const ERROR_MSG_PREFIX := "USER ERROR: "
const WARNING_MSG_PREFIX := "USER WARNING: "
#Any logs with three spaces at the beginning will be ignored.
const IGNORE_PREFIX := "   " 
#endregion
#region 配置与运行状态

var godot_log:FileAccess
#endregion
#region 生命周期与引擎回调

func _ready():
	var file_logging_enabled = ProjectSettings.get("debug/file_logging/enable_file_logging") or ProjectSettings.get("debug/file_logging/enable_file_logging.pc")
	if !file_logging_enabled:
		push_warning("You have to enable file logging in order to use engine log monitor!")
		return
	
	var log_path = ProjectSettings.get("debug/file_logging/log_path")
	# Respect a command-line log destination when running standalone demos/tests.
	var arguments := OS.get_cmdline_args()
	var log_argument := arguments.find("--log-file")
	if log_argument >= 0 and log_argument + 1 < arguments.size():
		log_path = arguments[log_argument + 1]
	godot_log = FileAccess.open(log_path, FileAccess.READ)
	if godot_log == null:
		return

	create_tween().set_loops(
	).tween_callback(_read_data
	).set_delay(UPDATE_INTERVAL)
#endregion
#region 内部实现


func _read_data():
	while godot_log.get_position() < godot_log.get_length():
		var new_line = godot_log.get_line()
		if new_line.begins_with(IGNORE_PREFIX):
			continue
		if new_line.begins_with(ERROR_MSG_PREFIX):
			error_msg_received.emit(new_line.trim_prefix(ERROR_MSG_PREFIX))
		elif new_line.begins_with(WARNING_MSG_PREFIX):
			warning_msg_received.emit(new_line.trim_prefix(WARNING_MSG_PREFIX))
		else:
			info_msg_received.emit(new_line)
#endregion
