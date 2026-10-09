extends Control
class_name OriginalInventoryView
#region 预置四标签与25格；复用Simple Inventory运行数据和GAS属性通知
signal close_requested
@export var slot_textures: Array[Texture2D] = []
@export var tab_textures: Array[Texture2D] = []
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
const BAG_KEYS := ["equipment", "material", "consumable", "fashion"]
const PARTS := ["wing", "weapon", "helmet", "amulet", "armor", "ornament"]
const FASHION_PARTS := ["wing", "fashionWeapon", "fashionHelmet", "amulet", "fashionArmor", "fairy"]
const RESISTANCE_IDS := [&"lightResist", &"darkResist", &"waterResist", &"fireResist", &"woodResist", &"soilResist", &"windResist", &"rayResist"]
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
	$Sort.pressed.connect(func(): inventory.pack_items())
	$Context/Use.pressed.connect(_use_selected)
	$Context/Sell.pressed.connect(_sell_selected)
	$Context/Lock.pressed.connect(_lock_selected)
	$Context/Close.pressed.connect(func(): $Context.hide())
	$Confirm/Yes.pressed.connect(confirm_operation)
	$Confirm/No.pressed.connect(func(): $Confirm.hide())
	$Confirm/Less.pressed.connect(func(): $Confirm/Count.text = str(maxi(1,int($Confirm/Count.text)-1)))
	$Confirm/More.pressed.connect(func(): $Confirm/Count.text = str(mini(_selected.quantity,int($Confirm/Count.text)+1)) if _selected != null else "1")
	$Wardrobe.pressed.connect(func(): _fashion = not _fashion; refresh())
	$ResistanceButton.pressed.connect(func(): $Resistances.show())
	$Resistances/Close.pressed.connect(func(): $Resistances.hide())
	visibility_changed.connect(_on_visibility_changed)

func bind_actor(owner_actor: BattleEntity2D) -> void:
	actor = owner_actor
	inventory = actor.inventory as OriginalInventory
	assert(inventory != null, "原版背包视图需要角色中预置OriginalInventory")
	inventory.item_changed.connect(refresh)
	inventory.equip_changed.connect(func(_slot, _item): refresh())
	inventory.currency_changed.connect(func(_spirit): refresh())
	actor.attributes.snapshot_changed.connect(_on_attributes)
	actor.animation.appearance_changed.connect(func(skins: Array[StringName]): $RolePortrait.set_skins(skins))
	$RolePortrait.set_skins(actor.animation.get_skin_names())
	$RolePortrait.play_action(&"idle",true)
	refresh()

func _process(delta: float) -> void:
	if visible and actor != null: $RolePortrait.advance_animation(delta)

func _select_tab(index: int) -> void:
	tab = index
	page = 0
	$Context.hide()
	_hide_tip()
	refresh()

func refresh() -> void:
	if inventory == null: return
	_rows = inventory.get_bag_items(BAG_KEYS[tab])
	page = clampi(page, 0, inventory.get_page_count(BAG_KEYS[tab]) - 1)
	for index in range(4):
		var button := $Tabs.get_child(index) as TextureButton
		if tab_textures.size() >= 12: button.texture_normal = tab_textures[index * 3 + (2 if tab == index else 0)]
	for index in range(PARTS.size()):
		var equip := inventory.equip_slots[_part(index)][1] as Item
		_render_slot($Equipment.get_child(index), equip, false)
		$Equipment.get_child(index).get_node("Part").text = (["翅膀","幻兵","幻饰","法宝","幻衣","幻兽"] if _fashion else ["翅膀","武器","头盔","法宝","防具","饰品"])[index]
	for index in range(25):
		var absolute := index + page * 25
		var item := _rows[absolute] if absolute < _rows.size() else null
		_render_slot($Grid.get_child(index), item, absolute >= inventory.bag_capacities[BAG_KEYS[tab]])
	$Page.text = "%d / %d" % [page + 1, inventory.get_page_count(BAG_KEYS[tab])]
	$Capacity.text = "%d / %d" % [_rows.size(), inventory.bag_capacities[BAG_KEYS[tab]]]
	$Spirit.text = str(inventory.spirit)
	_on_attributes(actor.attributes.get_snapshot())

func _render_slot(slot: Control, item: Item, locked_slot: bool) -> void:
	var quality := clampi(int(item.original_data.get("quality", 0)), 0, 6) if item != null else 0
	if quality < slot_textures.size(): slot.get_node("Background").texture = slot_textures[quality]
	slot.get_node("Icon").texture = item.icon if item != null else null
	slot.get_node("Count").text = str(item.quantity) if item != null and item.quantity > 1 else ""
	slot.get_node("Lock").visible = locked_slot or (item != null and item.locked)
	slot.set_meta(&"item", item)
	slot.set_meta(&"locked_slot", locked_slot)

func _on_attributes(snapshot: Dictionary) -> void:
	$Level.text = str(int(snapshot.level))
	$Experience.text = "%d/%d" % [int(snapshot.get(&"exp",0)),int(snapshot.expNext)]
	for index in range(ATTRIBUTES.size()):
		$Attributes.get_child(index).text = str(roundi(float(snapshot.get(ATTRIBUTES[index], 0))))
	for index in range(RESISTANCE_IDS.size()):
		$Resistances/Values.get_child(index).text = "%s：%d" % [["光抗","暗抗","水抗","火抗","木抗","土抗","风抗","雷抗"][index],roundi(float(snapshot.get(RESISTANCE_IDS[index],0)))]

func _part(index: int) -> String:
	return FASHION_PARTS[index] if _fashion else PARTS[index]
#endregion
#region 原版点击菜单、装备/卸下、使用/出售与锁定；都不绕过插件数据入口
func _slot_input(event: InputEvent, index: int) -> void:
	var slot := $Grid.get_child(index) as Control
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		accept_event()
		if slot.get_meta(&"locked_slot", false):
			_confirm_extension(index+page*25+1)
			return
		_open_context(slot.get_meta(&"item") as Item, false)

func _equipment_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		_open_context(inventory.equip_slots[_part(index)][1] as Item, true)

func _open_context(item: Item, equipped: bool) -> void:
	$Context.hide()
	if item == null: return
	_selected = item
	_equipped = equipped
	$Context/Use.text = "卸下" if equipped else ("装备" if item is Equip else "使用")
	$Context/Use.disabled = not equipped and not item is Equip and int(item.original_data.get("isUse", 0)) == 0
	$Context/Sell.disabled = equipped or item.locked or int(item.original_data.get("isSell", 1)) == 0
	$Context/Lock.text = "解锁" if item.locked else "锁定"
	$Context/Lock.disabled = not item is Equip
	$Context.position = _clamp_popup(get_local_mouse_position(), $Context.size)
	$Context.show()
	_hide_tip()

func _use_selected() -> void:
	if _equipped: inventory.unequip_item(_selected as Equip)
	else: inventory.use_item(_selected)
	$Context.hide()
	refresh()

func _sell_selected() -> void:
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
	else: _show_item_tip(slot.get_meta(&"item") as Item)

func _equipment_hover(index: int) -> void:
	_show_item_tip(inventory.equip_slots[_part(index)][1] as Item)

func _show_item_tip(item: Item) -> void:
	if item == null: return
	var content := "%s\n%s" % [item.name, item.description]
	if item is BattleInventoryEquipment and item.battle_definition != null:
		for modifier in item.battle_definition.attribute_modifiers:
			var names := {&"atk": "攻击", &"phyDef": "防御", &"hpMax": "生命", &"mpMax": "魔法", &"critical": "暴击", &"lucky": "幸运", &"guardian": "守护", &"reHP": "回血", &"reMP": "回魔"}
			content += "\n%s %+d" % [names.get(modifier.attribute_id, String(modifier.attribute_id)), roundi(modifier.value)]
	if item.locked: content += "\n已锁定"
	_show_tip(content)

func _show_tip(content: String) -> void:
	if $Context.visible: return
	$Tooltip/Text.text = content
	$Tooltip.position = _clamp_popup(get_local_mouse_position() + Vector2(15, 15), $Tooltip.size)
	$Tooltip.show()

func _clamp_popup(point: Vector2, dimensions: Vector2) -> Vector2:
	return point.clamp(Vector2.ZERO, Vector2(940, 590) - dimensions)

func _hide_tip() -> void:
	$Tooltip.hide()

func _on_visibility_changed() -> void:
	$Context.hide()
	$Confirm.hide()
	$Resistances.hide()
	_hide_tip()
	if visible: refresh()
#endregion
