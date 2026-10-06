extends VBoxContainer
#region 配置与运行状态

var console:PankuConsole

@export var input_area:Node
@export var repl:Node
#endregion
#region 生命周期与引擎回调

func _ready() -> void:
	repl.output_result.connect(console.notify)
	repl.output_error.connect(console.notify)
	input_area.submitted.connect(
		func(_s): hide()
	)
#endregion
