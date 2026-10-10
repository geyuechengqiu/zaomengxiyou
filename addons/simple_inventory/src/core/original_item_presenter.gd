extends RefCounted
class_name OriginalItemPresenter
#region 原版PropColor、ItemPart、BackpackTips的数据模型；不修改物品或GAS属性
const QUALITY_NAMES := ["普通", "优秀", "精良", "史诗", "传说", "神器", "上古", "圣器", "邪灵", "深渊"]
const QUALITY_COLORS := [16777215, 65280, 1991679, 12320978, 16187136, 15335424, 16741120, 15944573, 6579300, 9830412]
const ATTRIBUTE_NAMES := {&"hpMax":"生命", &"mpMax":"魔法", &"atk":"攻击", &"phyDef":"防御", &"reHP":"回血", &"reMP":"回魔", &"hit":"命中", &"dodge":"闪避", &"critical":"暴击", &"toughness":"韧性", &"lucky":"幸运", &"guardian":"守护", &"waterResist":"水抗", &"fireResist":"火抗", &"woodResist":"木抗", &"soilResist":"土抗", &"windResist":"风抗", &"rayResist":"雷抗", &"lightResist":"光抗", &"darkResist":"暗抗"}
const PART_NAMES := {"armor":"防具", "helmet":"头盔", "weapon":"武器", "ornament":"饰品", "amulet":"法宝", "wing":"翅膀", "fashionArmor":"幻衣", "fashionHelmet":"幻饰", "fashionWeapon":"幻兵", "fairy":"幻兽", "title":"称号"}
const RESISTANCES := {&"lightResist":"光", &"darkResist":"暗", &"waterResist":"水", &"fireResist":"火", &"woodResist":"木", &"soilResist":"土", &"windResist":"风", &"rayResist":"雷"}

static func escape(text: String) -> String:
	return text.replace("[", "\u0001").replace("]", "[rb]").replace("\u0001", "[lb]")

static func get_card(item: Item, inventory: OriginalInventory) -> Dictionary:
	var data := item.original_data
	# Original quality is encoded by the first decimal digit (not clamped to 0..6).
	var quality := clampi(str(int(data.get("quality", 0))).left(1).to_int(), 0, QUALITY_NAMES.size()-1)
	var rows: Array[Dictionary] = []
	var equipment := item is Equip
	var role := int(data.get("roleConditions", 0))
	var rules: Dictionary = inventory.presentation_rules.data if inventory.presentation_rules != null else {}
	var kind: String = String(PART_NAMES.get(String(data.get("part", "")), "装备")) + "·" + String(rules.get("roles", {}).get(str(role), "通用")) if equipment else String(data.get("nameType", "消耗品" if item.category == Item.ITEM_TYPE.CONSUMABLE else "材料"))
	var values: Dictionary = inventory.get_item_attribute_values(item)
	var enhancement := item.runtime.enhancement_level if item.runtime != null else 0
	for id in ATTRIBUTE_NAMES:
		var value := roundi(float(values.get(id, 0)))
		var added := floori(float(data.get(String(id) + "Add", 0)) * (enhancement % 6 if String(data.get("type", "")) == "fashion" else enhancement) + 0.5001) if String(data.get("part", "")) != "amulet" else 0
		var number := "%d+(%d)" % [value - added, added] if added != 0 else str(value)
		if value != 0: rows.append({"text":"%s: %s" % [ATTRIBUTE_NAMES[id], number], "color":"#5f1e05", "gem":false})
	var holes := String(data.get("hole", "-1"))
	if equipment and holes not in ["", "-1", "0"]:
		for hole in holes.split(";"):
			if hole != "": rows.append({"text":"未镶嵌宝石", "color":"#777777", "gem":true})
	var description := item.description.replace("<br>", "\n").replace("<br/>", "\n")
	if description not in ["", "-1"]: rows.append({"text":description, "color":"#5f1e05", "gem":false})
	if item.locked: rows.append({"text":"已锁定", "color":"#ff0000", "gem":false})
	var refinement_key := str(int(data.get("series", 0)) * 1000 + enhancement)
	var level_text := String(rules.get("refinement_names", {}).get(refinement_key, "未强化"))
	return {"name":"%s(+%d)" % [item.name, enhancement] if enhancement > 0 else item.name, "quality":QUALITY_NAMES[quality], "color":"#%06x" % QUALITY_COLORS[quality], "kind":kind, "equipment":equipment, "level":level_text, "rows":rows, "price":inventory.get_sell_price(item)}

static func get_resistance_text(snapshot: Dictionary) -> String:
	var lines: PackedStringArray = []
	for id in RESISTANCES:
		var value := float(snapshot.get(id, 0.0))
		if is_zero_approx(value): continue
		var rate := roundi(value / (value + 100.0) * 100.0) if value > 0.0 else roundi(absf(value))
		lines.append("%s属性抗性：%d（受到%s属性伤害%s：%d%%）" % [RESISTANCES[id], roundi(value), RESISTANCES[id], "减免" if value > 0.0 else "增加", rate])
	return "\n".join(lines) if not lines.is_empty() else "当前没有属性抗性"
#endregion
