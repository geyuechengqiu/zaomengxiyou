extends HBoxContainer
#region 配置与运行状态

@export var label:Label
#endregion
#region 生命周期与引擎回调

func _ready():
	$PankuButton.pressed.connect(
		func():
			Panku.notify(label.text)
	)
#endregion
