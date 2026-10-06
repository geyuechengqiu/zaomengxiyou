class_name PankuModuleScreenCrtEffect extends PankuModule
#region 配置与运行状态

var crt_effect_enabled := false
var crt_effect_layer:CanvasLayer = null
#endregion
#region 公共接口

func toggle_crt_effect():
	crt_effect_enabled = !crt_effect_enabled
	if crt_effect_layer == null:
		crt_effect_layer = preload("./crt_effect_layer.tscn").instantiate()
		core.add_child(crt_effect_layer)
	crt_effect_layer.visible = crt_effect_enabled
#endregion
