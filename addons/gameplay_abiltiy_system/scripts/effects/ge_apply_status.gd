extends GameplayEffect
class_name GE_ApplyStatus
#region 配置与运行状态

## 应用状态效果
## 为目标应用一个状态（Buff/Debuff）

@export var status_data: GameplayStatusData = null  ## 状态数据
@export var stacks: int = 1  ## 层数
#endregion
#region 内部实现

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	var definition: GameplayStatusData = context.get("status_data", status_data)
	var initial_stacks: int = context.get("status_stacks", stacks)
	
	if not is_instance_valid(definition):
		push_error("GE_ApplyStatus: status_data is not set!")
		return
	
	var status_comp : GameplayStatusComponent = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
	if not status_comp:
		push_error("GE_ApplyStatus: Target %s has no GameplayStatusComponent!" % target.name)
		return
	
	# 应用状态
	var status_context := context.duplicate()
	# 所有权分组只用于被动技能直接持有的状态；衍生Buff仍按原版group合并。
	status_context.erase("status_owner_source")
	status_comp.apply_status(definition, instigator, initial_stacks, status_context)

func _get_description() -> String:
	if not is_instance_valid(status_data):
		return "Apply status to target\n"
	return "Apply status %s to target\n" % [status_data.status_display_name]
#endregion
