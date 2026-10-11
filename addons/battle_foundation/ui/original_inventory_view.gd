extends Control
class_name OriginalInventoryView
#region 预置四标签与25格；复用Simple Inventory运行数据和GAS属性通知
signal close_requested
@export var slot_textures: Array[Texture2D] = []
@export var tab_textures: Array[Texture2D] = []
@export var page_textures: Array[Texture2D] = []
@export var menu_textures: Array[Texture2D] = []
@export var fashion_textures: Array[Texture2D] = []
@export var player_name: String = "local"
var actor: BattleEntity2D
var inventory: OriginalInventory
var tab: int = 0
var page: int = 0
var _selected: Item
var _equipped: bool = false
var _rows: Array[Item] = []
var _confirmation: StringName = &"sell"
var _extension: Dictionary = {}
var _fashion: bool = false
var _popup_host: Control
var _uid_tween: Tween
var _uid_expanded: bool = false
const UID_OPEN_X := 43.1
const UID_CLOSED_X := -6.9
const BAG_KEYS := ["equipment", "material", "consumable", "fashion"]
const PARTS := ["wing", "weapon", "helmet", "amulet", "armor", "ornament"]
const FASHION_PARTS := ["wing", "fashionWeapon", "fashionHelmet", "amulet", "fashionArmor", "fairy"]
const ATTRIBUTES := [&"hpMax", &"mpMax", &"atk", &"phyDef", &"reHP", &"reMP", &"hit", &"dodge", &"critical", &"toughness", &"lucky", &"guardian"]

func _ready() -> void:
	$Close.pressed.connect(func(): close_requested.emit())
	for index in range(4):
		$Tabs.get_child(index).pressed.connect(_select_tab.bind(index))
	for index in range(PARTS.size()):
		$Equipment.get_child(index).gui_input.connect(_equipment_input.bind(index))
		$Equipment.get_child(index).mouse_entered.connect(_equipment_hover.bind(index))
		$Equipment.get_child(index).mouse_exited.connect(_hide_tip)
	for index in range(25):
		$Grid.get_child(index).gui_input.connect(_slot_input.bind(index))
		$Grid.get_child(index).mouse_entered.connect(_slot_hover.bind(index))
		$Grid.get_child(index).mouse_exited.connect(_hide_tip)
	$Previous.pressed.connect(func(): page = maxi(0, page - 1); refresh())
	$Next.pressed.connect(func(): page = mini(inventory.get_page_count(BAG_KEYS[tab]) - 1, page + 1); refresh())
	for button in $PageButtons.get_children():
		button.pressed.connect(func(): page = int(button.get_meta(&"page", 0)); refresh())
	$Sort.pressed.connect(func(): inventory.pack_items())
	$Context/Use.pressed.connect(_use_selected)
	$Context/Sell.pressed.connect(_sell_selected)
	$Context/Lock.pressed.connect(_lock_selected)
	$Name.text_changed.connect(_rename_player)
	$Name.text_submitted.connect(func(_text): $Name.release_focus())
	$Context/Close.pressed.connect(func(): $Context.hide())
	$Confirm/Yes.pressed.connect(confirm_operation)
	$Confirm/No.pressed.connect(func(): $Confirm.hide())
	$Confirm/Less.pressed.connect(func(): $Confirm/Count.text = str(maxi(1,int($Confirm/Count.text)-1)))
	$Confirm/More.pressed.connect(func(): $Confirm/Count.text = str(mini(_selected.quantity,int($Confirm/Count.text)+1)) if _selected != null else "1")
	$Wardrobe.pressed.connect(func(): inventory.request_wardrobe())
	$FashionToggle.pressed.connect(func(): inventory.set_show_fashion(not inventory.show_fashion))
	$ResistanceButton.mouse_entered.connect(_show_resistances)
	$ResistanceButton.mouse_exited.connect(func(): $Resistances.hide())
	$PlayerNumber/Icon.mouse_entered.connect(_expand_number)
	$PlayerNumber/Drawer/Copy.pressed.connect(_copy_number)
	visibility_changed.connect(_on_visibility_changed)

func bind_actor(owner_actor: BattleEntity2D) -> void:
	actor = owner_actor
	$Name.text = player_name
	var character := actor.session.catalog.instantiate_definition("characters", actor.definition_id) as BattleEntityDefinition
	$RoleName.text = character.display_name if character != null else String(actor.definition_id)
	inventory = actor.inventory as OriginalInventory
	assert(inventory != null, "原版背包视图需要角色中预置OriginalInventory")
	$Name.text = inventory.display_name
	inventory.display_name_changed.connect(_on_display_name_changed)
	$PlayerNumber/Drawer/Value.text = inventory.player_number if not inventory.player_number.is_empty() else "未设置"
	$PlayerNumber/Drawer/Copy.disabled = inventory.player_number.is_empty()
	inventory.item_changed.connect(refresh)
	inventory.equip_changed.connect(func(_slot, _item): refresh())
	inventory.currency_changed.connect(func(_spirit): refresh())
	actor.attributes.snapshot_changed.connect(_on_attributes)
	actor.animation.appearance_changed.connect(func(skins: Array[StringName]): $RolePortrait.set_skins(skins))
	$RolePortrait.set_skins(actor.animation.get_skin_names())
	$RolePortrait.play_action(&"idle",true)
	refresh()

func _process(delta: float) -> void:
	if not visible or actor == null: return
	$RolePortrait.advance_animation(delta)
	$PortraitGlow.advance_effect(delta)
	var mouse := get_local_mouse_position()
	if _uid_expanded and not Rect2($PlayerNumber.position, $PlayerNumber.size).has_point(mouse): _collapse_number()
	if $Context.visible and is_instance_valid(_popup_host):
		if not Rect2($Context.position, $Context.size).has_point(mouse) and not _host_rect(_popup_host).has_point(mouse): $Context.hide()
	if $Tooltip.visible: _layout_item_tips()
	if $Resistances.visible: _layout_resistances()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and event.pressed and not _host_rect($Name).has_point(get_local_mouse_position()):
		$Name.release_focus()
	if event is InputEventMouseButton and event.pressed and $Context.visible:
		var point := get_local_mouse_position()
		if not Rect2($Context.position, $Context.size).has_point(point) and (not is_instance_valid(_popup_host) or not _host_rect(_popup_host).has_point(point)): $Context.hide()

func _select_tab(index: int) -> void:
	tab = index
	page = 0
	$Context.hide()
	$Confirm.hide()
	_hide_tip()
	refresh()

func refresh() -> void:
	if inventory == null: return
	_rows = inventory.get_bag_items(BAG_KEYS[tab])
	page = clampi(page, 0, inventory.get_page_count(BAG_KEYS[tab]) - 1)
	for index in range(4):
		var button := $Tabs.get_child(index) as TextureButton
		if tab_textures.size() >= 12: button.texture_normal = tab_textures[index * 3 + (2 if tab == index else 0)]
	# 原BodyView.checkFashion：普通装备页展示普通槽位；时装页展示幻装槽位。
	$Wardrobe.visible = tab == 0
	$FashionToggle.visible = tab == 3
	if fashion_textures.size() >= 6:
		var base := 3 if inventory.show_fashion else 0
		$FashionToggle.texture_normal = fashion_textures[base]
		$FashionToggle.texture_hover = fashion_textures[base+2]
		$FashionToggle.texture_pressed = fashion_textures[base+1]
	if tab != 3: _fashion = false
	else: _fashion = true
	for index in range(PARTS.size()):
		var equip := inventory.equip_slots[_part(index)][1] as Item
		_render_slot($Equipment.get_child(index), equip, false)
		$Equipment.get_child(index).get_node("Part").text = (["翅膀","幻兵","幻饰","法宝","幻衣","幻兽"] if _fashion else ["翅膀","武器","头盔","法宝","防具","饰品"])[index]
		$Equipment.get_child(index).get_node("Part").visible = equip == null
	for index in range(25):
		var absolute := index + page * 25
		var item := _rows[absolute] if absolute < _rows.size() else null
		_render_slot($Grid.get_child(index), item, absolute >= inventory.bag_capacities[BAG_KEYS[tab]])
	$Page.text = "%d / %d" % [page + 1, inventory.get_page_count(BAG_KEYS[tab])]
	_refresh_page_buttons()
	$Capacity.text = "%d / %d" % [_rows.size(), inventory.bag_capacities[BAG_KEYS[tab]]]
	$Spirit.text = str(inventory.spirit)
	_on_attributes(actor.attributes.get_snapshot())
	if $Context.visible and inventory.get_owned_item(_selected) == null: $Context.hide()
	# 装备/出售后不要让先前悬浮卡继续显示过期属性。
	if $Tooltip.visible: _hide_tip()

func _render_slot(slot: Control, item: Item, locked_slot: bool) -> void:
	# PropBody.addProp使用quality+2源帧；数组0为空格，1才是普通品质。
	var quality := clampi(str(int(item.original_data.get("quality", 0))).left(1).to_int(), 0, 9) if item != null else -1
	var background := mini(quality + 1, slot_textures.size() - 1)
	if background >= 0: slot.get_node("Background").texture = slot_textures[background]
	slot.get_node("Icon").texture = item.icon if item != null else null
	slot.get_node("Count").text = str(item.quantity) if item != null and item.quantity > 1 else ""
	slot.get_node("Lock").visible = locked_slot or (item != null and item.locked)
	slot.set_meta(&"item", item)
	slot.set_meta(&"locked_slot", locked_slot)

func _on_attributes(snapshot: Dictionary) -> void:
	# 战力由属性组件统一计算；UI不使用临时战斗属性另算一遍。
	$FightPower.number = int(snapshot.get(&"fightPower", 0))
	$Level.text = "Lv.%d" % int(snapshot.level)
	$Experience.text = "%d/%d" % [int(snapshot.get(&"exp",0)),int(snapshot.expNext)]
	$ExperienceFill.value = clampf(float(snapshot.get(&"exp", 0)) / maxf(1.0, float(snapshot.expNext)), 0.0, 1.0)
	for index in range(ATTRIBUTES.size()):
		$Attributes.get_child(index).text = str(roundi(float(snapshot.get(ATTRIBUTES[index], 0))))
	if $Resistances.visible: _show_resistances()

func _part(index: int) -> String:
	return FASHION_PARTS[index] if _fashion else PARTS[index]

func _refresh_page_buttons() -> void:
	var total := inventory.get_page_count(BAG_KEYS[tab])
	var count := mini(8, total)
	var first := clampi(page - 3, 0, maxi(0, total - count))
	var left := 668.0 - 40.0 * count / 2.0
	$Previous.visible = total > 8
	$Next.visible = total > 8
	$Previous.position.x = left - 24.0
	$Next.position.x = left + 35.0 * count
	for index in range($PageButtons.get_child_count()):
		var button := $PageButtons.get_child(index) as TextureButton
		button.visible = total > 1 and index < count
		button.position = Vector2(left + 35.0 * index, 445)
		button.set_meta(&"page", first + index)
		button.get_node("Text").text = str(first + index + 1)
		if page_textures.size() == 3:
			button.texture_normal = page_textures[2 if page == first + index else 0]
#endregion
#region 原版点击菜单、装备/卸下、使用/出售与锁定；都不绕过插件数据入口
func _slot_input(event: InputEvent, index: int) -> void:
	if $Confirm.visible: return
	var slot := $Grid.get_child(index) as Control
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		accept_event()
		if slot.get_meta(&"locked_slot", false):
			_confirm_extension(index+page*25+1)
			return
		_open_context(slot.get_meta(&"item") as Item if slot.has_meta(&"item") else null, false, slot)

func _equipment_input(event: InputEvent, index: int) -> void:
	if $Confirm.visible: return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		accept_event()
		_open_context(inventory.equip_slots[_part(index)][1] as Item, true, $Equipment.get_child(index))

func _open_context(item: Item, equipped: bool, host: Control) -> void:
	$Context.hide()
	_hide_tip()
	if item == null or inventory.get_owned_item(item) == null: return
	if equipped:
		# 已装备格直接卸下，容量/角色/战斗限制仍由插件统一检查。
		inventory.unequip_item(item as Equip)
		refresh()
		return
	_selected = item
	_equipped = equipped
	_popup_host = host
	var actions := inventory.get_context_actions(item, equipped)
	for name in ["Use", "Sell", "Lock", "Close"]: $Context.get_node(name).hide()
	for index in range(actions.size()):
		var entry: Dictionary = actions[index]
		var button := $Context.get_node({&"use":"Use", &"sell":"Sell", &"lock":"Lock"}[entry.id]) as Button
		button.show()
		button.position = Vector2(15, 24 + 47 * index)
		button.size = Vector2(100, 36)
		button.disabled = not entry.enabled
		var caption := button.get_node_or_null("Caption") as TextureRect
		if caption != null:
			caption.texture = menu_textures[int(entry.frame)-1] if int(entry.frame) > 0 and menu_textures.size() >= int(entry.frame) else null
			caption.modulate.a = 0.4 if button.disabled else 1.0
		button.text = "" if caption != null and caption.texture != null else entry.text
	$Context.size = Vector2(130, 24 + 47 * (actions.size()-1) + 36 + 20)
	$Context.position = _clamp_popup(_host_rect(host).get_center(), $Context.size)
	$Context.show()

func _use_selected() -> void:
	if _equipped: inventory.unequip_item(_selected as Equip)
	else: inventory.use_item(_selected)
	$Context.hide()
	refresh()

func _sell_selected() -> void:
	if _selected == null or inventory.get_owned_item(_selected) == null: return
	# 原版出售需确认；第一次进入预置确认栏，第二次确认才扣数量。
	$Confirm.show()
	_confirmation = &"sell"
	$Confirm/Text.text = "出售%s\n单价：%d灵魂" % [_selected.name,inventory.get_sell_price(_selected)]
	$Confirm/Count.text = str(_selected.quantity)
	for name in ["Less","Count","More"]: $Confirm.get_node(name).show()
	$Context.hide()

func confirm_operation() -> void:
	if _confirmation == &"extend": inventory.extend_bag(_extension.bag,_extension.capacity)
	elif _selected != null: inventory.sell_item(_selected, int($Confirm/Count.text))
	$Confirm.hide()
	refresh()

func _confirm_extension(capacity: int) -> void:
	_extension = inventory.get_extension_quote(BAG_KEYS[tab],capacity)
	if _extension.is_empty(): inventory.operation_rejected.emit("背包格无法解锁"); return
	_confirmation = &"extend"
	var text := "解锁%d至%d格" % [inventory.bag_capacities[BAG_KEYS[tab]]+1,capacity]
	for id in _extension.costs:
		text += "\n消耗%d个%s" % [_extension.costs[id],inventory.original_rules.data.item_names.get(String(id),String(id))]
	$Confirm/Text.text = text
	for name in ["Less","Count","More"]: $Confirm.get_node(name).hide()
	$Confirm.show()

func _lock_selected() -> void:
	inventory.toggle_lock(_selected)
	$Context.hide()
	refresh()

func _slot_hover(index: int) -> void:
	var slot := $Grid.get_child(index) as Control
	if slot.get_meta(&"locked_slot", false): _show_tip("此背包格尚未解锁")
	else: _show_item_tip(slot.get_meta(&"item") as Item if slot.has_meta(&"item") else null, slot, false)

func _equipment_hover(index: int) -> void:
	if inventory == null: return
	_show_item_tip(inventory.equip_slots[_part(index)][1] as Item, $Equipment.get_child(index), true)

func _show_item_tip(item: Item, host: Control, equipped: bool) -> void:
	_hide_tip()
	if item == null or $Context.visible or $Confirm.visible: return
	_popup_host = host
	$Tooltip.show_item(item, inventory, equipped)
	var other := inventory.get_comparison_item(item) if not equipped else null
	if other != null: $ComparisonTooltip.show_item(other, inventory, true)
	_layout_item_tips()

func _show_tip(content: String) -> void:
	if $Context.visible: return
	_hide_tip()
	$Resistances/Text.text = content
	_size_simple_tip()
	$Resistances.show()
	_layout_resistances()

func _show_resistances() -> void:
	if actor == null or $Context.visible or $Confirm.visible: return
	_hide_tip()
	$Resistances/Text.text = OriginalItemPresenter.get_resistance_text(actor.attributes.get_snapshot())
	_size_simple_tip()
	$Resistances.show()
	_layout_resistances()

func _size_simple_tip() -> void:
	var font: Font = $Resistances/Text.get_theme_font("font")
	var lines := String($Resistances/Text.text).split("\n")
	var width := 0.0
	for line in lines: width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	$Resistances.size = Vector2(clampf(width + 24, 75, 916), maxf(60, lines.size()*24+24))
	$Resistances/Text.size = $Resistances.size - Vector2(24,24)

func _layout_resistances() -> void:
	$Resistances.position = _clamp_popup(get_local_mouse_position()+Vector2(15,15), $Resistances.size)

func _layout_item_tips() -> void:
	var pair: bool = $ComparisonTooltip.visible
	var total_size := Vector2(517.0 if pair else 260.0, maxf($Tooltip.size.y, $ComparisonTooltip.size.y if pair else 0.0))
	var start := _clamp_popup(get_local_mouse_position()+Vector2(15,15), total_size)
	$ComparisonTooltip.position = start
	$Tooltip.position = start + Vector2(257,0) if pair else start

func _host_rect(host: Control) -> Rect2:
	return Rect2(get_global_transform().affine_inverse() * host.global_position, host.size)

func _clamp_popup(point: Vector2, dimensions: Vector2) -> Vector2:
	return point.clamp(Vector2.ZERO, (Vector2(940, 590) - dimensions).max(Vector2.ZERO))

func _hide_tip() -> void:
	$Tooltip.hide()
	$ComparisonTooltip.hide()
	$Resistances.hide()

#region 昵称输入，按Unicode字符限制长度；身份ID与角色定义不变
func _rename_player(value: String) -> void:
	if inventory != null: inventory.set_display_name(value)

func _on_display_name_changed(value: String) -> void:
	if $Name.text != value: $Name.text = value
#endregion

#region 编号悬浮抽屉，复制真实业务配置编号
func _expand_number() -> void:
	_uid_expanded = true
	if _uid_tween != null: _uid_tween.kill()
	$PlayerNumber/Drawer.show()
	_uid_tween = create_tween().set_parallel(true)
	_uid_tween.tween_property($PlayerNumber/Drawer, "position:x", UID_OPEN_X, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_uid_tween.tween_property($PlayerNumber/Drawer, "modulate:a", 1.0, 0.5)

func _collapse_number() -> void:
	_uid_expanded = false
	if _uid_tween != null: _uid_tween.kill()
	_uid_tween = create_tween().set_parallel(true)
	_uid_tween.tween_property($PlayerNumber/Drawer, "position:x", UID_CLOSED_X, 0.2)
	_uid_tween.tween_property($PlayerNumber/Drawer, "modulate:a", 0.0, 0.2)
	_uid_tween.chain().tween_callback(func(): $PlayerNumber/Drawer.hide())

func _copy_number() -> void:
	if inventory == null or inventory.player_number.is_empty(): return
	DisplayServer.clipboard_set(inventory.player_number)
	inventory.operation_completed.emit("编号已复制")
#endregion

func _on_visibility_changed() -> void:
	$Context.hide()
	$Confirm.hide()
	$Resistances.hide()
	_hide_tip()
	if _uid_tween != null: _uid_tween.kill()
	_uid_expanded = false
	$PlayerNumber/Drawer.hide()
	$PlayerNumber/Drawer.position.x = UID_CLOSED_X
	$PlayerNumber/Drawer.modulate.a = 0.0
	if visible:
		refresh()
		$PortraitGlow.play_effect()
	else:
		$PortraitGlow.stop_effect()
		$Name.release_focus()
#endregion
