extends Control
#region 配置与运行状态

@onready var trect:TextureRect = $TextureRect

var _module:PankuModule
var expr:String
#endregion
#region 生命周期与引擎回调

func _physics_process(delta: float) -> void:
	if Engine.get_physics_frames() % 10 != 1:
		return
	var result = _module.core.gd_exprenv.execute(expr)["result"]
	if result is Texture2D:
		trect.texture = ImageTexture.create_from_image(result.get_image())
#endregion
