extends Node
#region 类型与常量

const BURN_STATUS = preload("res://addons/gameplay_abiltiy_system/examples/burn_status.tres")
#endregion
#region 配置与运行状态

@onready var status_comp: GameplayStatusComponent = %GameplayStatusComponent
#endregion
#region 生命周期与引擎回调

func _ready() -> void:
	preload("res://addons/gameplay_abiltiy_system/examples/example_data.gd").register_tags()
	await get_tree().process_frame
	# 应用并叠加燃烧
	var burn_status = BURN_STATUS.duplicate(true)
	status_comp.apply_status(burn_status, self, 1, {})
	status_comp.apply_status(burn_status, self, 1, {})
	var instance = status_comp.get_status(&"burn")
	assert(instance.stacks == 2, "状态应叠加到两层")
	print("燃烧层数:", instance.stacks)  # 期望 2

	# 按标签批量移除
	status_comp.remove_statuses_by_tags([&"status.burn"])
	assert(not status_comp.has_status(&"burn"))
	print("✅ 状态组件测试通过")
#endregion
