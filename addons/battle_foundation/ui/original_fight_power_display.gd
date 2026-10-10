extends Control
class_name OriginalFightPowerDisplay
#region 原版 NumberCom：fight_number 字形与 -3 像素间距
@export var digits: Array[Texture2D] = []
@export var number: int = 0:
	set(value):
		number = maxi(0, value)
		queue_redraw()

func _draw() -> void:
	if digits.size() != 10:
		return
	var cursor := Vector2.ZERO
	for character in str(number):
		var texture := digits[int(character)]
		draw_texture(texture, cursor)
		cursor.x += texture.get_width() - 3
#endregion
