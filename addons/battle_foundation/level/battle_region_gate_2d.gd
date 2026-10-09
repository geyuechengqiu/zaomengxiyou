extends StaticBody2D
class_name BattleRegionGate2D
#region 预置出口碰撞与编辑器可见门
@export var region_id: StringName
var locked: bool = true
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var barrier: Polygon2D = $Barrier

func set_locked(value: bool) -> void:
	locked = value
	# 不经Area2D物理回调改变形状；由战斗时钟更新，下一次移动查询前生效。
	shape.disabled = not value
	barrier.visible = value
	$Label.text = "区域未完成" if value else "出口已开启"
	$Label.modulate = Color("ffab73") if value else Color("9fe6b1")
#endregion
