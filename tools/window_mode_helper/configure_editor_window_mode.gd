extends SceneTree
## 通过 Godot 自身保存当前版本的编辑器设置，不手工重写整个设置文件。
## 仅由启动脚本在用户关闭编辑器后执行；辅助工程没有游戏插件或自动加载。

const SINGLE_WINDOW_SETTING := "interface/editor/display/single_window_mode"

func _initialize() -> void:
	call_deferred("_configure")

func _configure() -> void:
	if not Engine.is_editor_hint():
		push_error("Run with --headless --editor --single-window --script.")
		quit(1)
		return
	# 初始化尚未结束便退出会中断 UID 扫描，导致插件清理时出现资源错误。
	await create_timer(1.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var settings := EditorInterface.get_editor_settings()
	var path := settings.resource_path
	if path.is_empty():
		push_error("Editor settings have no save path; nothing changed.")
		quit(1)
		return
	# 保留首次设置前的备份；重复运行不会覆盖该备份。
	var backup := path + ".before-single-window.bak"
	if FileAccess.file_exists(path) and not FileAccess.file_exists(backup):
		var backup_error := DirAccess.copy_absolute(path, backup)
		if backup_error != OK:
			push_error("Cannot back up editor settings: %s" % error_string(backup_error))
			quit(1)
			return
	settings.set_setting(SINGLE_WINDOW_SETTING, true)
	var save_error := ResourceSaver.save(settings, path)
	if save_error != OK:
		push_error("Cannot save editor settings: %s" % error_string(save_error))
		quit(1)
		return
	print("PASS single-window setting saved: %s; backup: %s" % [path, backup])
	quit(0)
