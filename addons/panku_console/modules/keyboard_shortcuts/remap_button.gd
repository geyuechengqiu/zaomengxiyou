extends Button
#region 信号

signal key_event_changed(new_event:InputEventKey)
#endregion
#region 配置与运行状态

var key_event:InputEventKey:
	set(v):
		key_event = v
		var key_name = "unassigned"
		if key_event:
			key_name = "Key " + OS.get_keycode_string(key_event.keycode)
		text = key_name
		key_event_changed.emit(v)
#endregion
#region 生命周期与引擎回调

func _ready():
	set_process_unhandled_key_input(false)
	toggled.connect(
		func(button_pressed:bool):
			set_process_unhandled_key_input(button_pressed)
			if button_pressed:
				text = "Waiting..."
			else:
				release_focus()
	)
#endregion
#region 内部实现

func _unhandled_key_input(event):
	key_event = event
	button_pressed = false
#endregion
