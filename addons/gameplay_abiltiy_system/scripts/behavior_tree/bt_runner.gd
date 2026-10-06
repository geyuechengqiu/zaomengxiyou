extends Node
class_name BTRunner
#region 类型与常量

const NodeStatus := BTNode.Status
enum RunnerMode {
	IDLE,       # _process
	PHYSICS,    # _physics_process
	MANUAL,     # 仅外部调用
}
#endregion
#region 配置与运行状态

@export var tree_root: BTNode
@export var run_mode: RunnerMode = RunnerMode.PHYSICS
@export var active: bool = true:
	set(v):
		active = v
		_update_process_mode()

var _instance: BTInstance
#endregion
#region 信号

signal tree_finished(result: NodeStatus)
#endregion
#region 生命周期与引擎回调

func _ready() -> void:
	var agent = get_parent()
	if not tree_root:
		push_warning("BTRunner: No Tree Root assigned for " + agent.name)
		active = false
		return

	_instance = BTInstance.new(agent, tree_root)
	_instance.blackboard.set_var("runner_node", self)
	
	_update_process_mode()

func _process(delta: float) -> void:
	tick(delta)

func _physics_process(delta: float) -> void:
	tick(delta)
#endregion
#region 公共接口

func tick(delta: float) -> void:
	if not is_instance_valid(_instance):
		return
	
	var result = _instance.tick(delta)
	if result != NodeStatus.RUNNING:
		tree_finished.emit(result)

func reset() -> void:
	if not is_instance_valid(_instance):
		return
	_instance.reset()

func get_blackboard() -> BTBlackboard:
	return _instance.blackboard if is_instance_valid(_instance) else null
#endregion
#region 内部实现

func _update_process_mode() -> void:
	set_process(active and run_mode == RunnerMode.IDLE)
	set_physics_process(active and run_mode == RunnerMode.PHYSICS)
#endregion
