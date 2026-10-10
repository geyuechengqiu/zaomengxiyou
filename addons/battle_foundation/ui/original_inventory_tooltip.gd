extends Control
class_name OriginalInventoryTooltip
#region 预置原版260像素装备/道具卡；尺寸随真实内容变化
signal geometry_changed
const FONT_SIZE := 16
const LINE_HEIGHT := 23.0

func show_item(item: Item, inventory: OriginalInventory, equipped: bool = false) -> void:
	var card := OriginalItemPresenter.get_card(item, inventory)
	$Name.text = card.name
	$Name.add_theme_color_override("font_color", Color(card.color))
	$Quality.text = card.quality
	$Quality.add_theme_color_override("font_color", Color(card.color))
	$Type.text = card.kind
	$Level.text = card.level
	$Level.visible = card.equipment
	$LevelRow.visible = card.equipment
	$Equipped.visible = equipped
	var font: Font = $Name.get_theme_font("font")
	var text := ""
	var line_count := 0
	for row: Dictionary in card.rows:
		var value: String = row.text
		if row.gem: value = "未镶嵌宝石"
		var prefix := "[img=20x20]res://assets/ui/original/tips_stone_bg.png[/img] " if row.gem else ""
		text += "[color=%s]%s%s[/color]\n" % [row.color, prefix, OriginalItemPresenter.escape(value)]
		for line in value.split("\n"):
			line_count += maxi(1, ceili(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x / (200.0 if row.gem else 220.0)))
	$Body.text = text.trim_suffix("\n")
	$Price.text = "价值: %d灵魂" % card.price
	$Price.visible = int(card.price) > 0
	var body_y := 113.0 if card.equipment else 88.0
	var body_height := maxi(1, line_count) * LINE_HEIGHT
	size = Vector2(260, minf(590.0, maxf(160.0, body_y + body_height + (65.0 if $Price.visible else 30.0))))
	$Body.position.y = body_y
	$Body.size = Vector2(220, size.y - body_y - (60.0 if $Price.visible else 20.0))
	$Price.position.y = size.y - 45
	show()
	geometry_changed.emit()
#endregion
