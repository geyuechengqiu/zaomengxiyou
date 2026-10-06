extends Control
#region 配置与运行状态

@export var tag_btn:Button
@export var rm_btn:Button

var tag_text:String
var tag_number:int = 0
#endregion
#region 公共接口

func check(message:String):
	if message.contains(tag_text):
		tag_number += 1
	tag_btn.text = "%s (%d)" % [tag_text, tag_number]
#endregion
