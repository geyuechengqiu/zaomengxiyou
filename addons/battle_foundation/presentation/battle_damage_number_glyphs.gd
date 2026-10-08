@tool
extends Node2D
class_name BattleDamageNumberGlyphs
#region 可编辑数字与原版排列
@export var library: BattleDamageNumberLibrary
const STYLES := {
	&"normal": ["bleedNumber", ""], &"critical": ["baojiNumber", "baoji"],
	&"true": ["real_bleedNumber", ""], &"true_critical": ["real_baojiNumber", "real_baoji"],
	&"player": ["playerBleedNumber", ""], &"dodge": ["sb", ""],
	&"normal_double": ["bleedNumber2", ""], &"critical_double": ["baojiNumber2", "baoji2"],
	&"special": ["baoDuBleedNumber", ""], &"kill": ["miaosa", ""], &"heal": ["bleedNumberAdd", ""]
}
@export var number: int = 80:
	set(value):
		var next := maxi(0, value)
		if number == next:
			return
		number = next
		queue_redraw()
@export_enum("normal", "critical", "true", "true_critical", "player", "dodge", "normal_double", "critical_double", "special", "kill", "heal") var style: String = "normal":
	set(value):
		if style == value:
			return
		style = value
		queue_redraw()

func _draw() -> void:
	if library == null:
		return
	var names: Array = STYLES.get(StringName(style), STYLES[&"normal"])
	var digits: Array = library.get_group(names[0])
	if digits.is_empty():
		return
	# 原版 Image 是 Bitmap，使用完整位图左上角，未应用 Texture.pivot。
	if style in ["dodge", "kill"]:
		draw_texture(digits[0], Vector2.ZERO)
		return
	var text := str(number)
	var width := 0.0
	for character in text:
		width += (digits[int(character)] as Texture2D).get_width() - 2.0
	var marker: Texture2D = null
	if not String(names[1]).is_empty():
		marker = library.get_group(names[1])[0] as Texture2D
		width += marker.get_width()
	var x := -width / 2.0
	if marker != null:
		# NewBaoJiNumber.rePos 的原式；不自行修正其非对称排列。
		draw_texture(marker, Vector2(x - marker.get_width(), 0.0))
	for character in text:
		var texture := digits[int(character)] as Texture2D
		draw_texture(texture, Vector2(x, 0.0))
		x += texture.get_width() - 2.0
#endregion
