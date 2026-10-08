@tool
extends EditorPlugin
## 在无插件辅助工程中自动退出：反复显示/隐藏弹窗，不开启原生子窗口。

func _enter_tree() -> void:
	# 只在显式验证时启动，普通配置进程不会打开弹窗。
	if "--verify-window-mode" in OS.get_cmdline_user_args():
		call_deferred("_verify")

func _verify() -> void:
	if not Engine.is_editor_hint():
		push_error("Run this verification in the editor.")
		get_tree().quit(1)
		return
	await get_tree().create_timer(1.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	var editor_window := EditorInterface.get_base_control().get_window()
	if not editor_window.gui_embed_subwindows:
		push_error("Expected an editor using embedded subwindows.")
		get_tree().quit(1)
		return
	if EditorInterface.is_multi_window_enabled():
		push_error("Editor multi-window mode is still enabled.")
		get_tree().quit(1)
		return
	var popup := PopupPanel.new()
	# Window 默认可见，必须在进入树之前隐藏，避免提前尝试创建窗口。
	popup.visible = false
	var label := Label.new()
	label.text = "Single-window popup verification"
	popup.add_child(label)
	editor_window.add_child(popup)
	for iteration in range(30):
		popup.popup_centered(Vector2i(320, 80))
		await get_tree().process_frame
		if not popup.is_embedded() or not popup.visible:
			push_error("Popup did not use the embedded window path.")
			get_tree().quit(1)
			return
		popup.hide()
		await get_tree().process_frame
	popup.queue_free()
	await get_tree().process_frame
	print("PASS editor single-window: 30 popup show/hide cycles; no native subwindows")
	get_tree().quit(0)
