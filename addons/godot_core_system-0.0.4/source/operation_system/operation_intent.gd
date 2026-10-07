extends InputEventAction
class_name CoreOperationIntent

#region 配置与运行状态
## 语义操作事件，不含键位；继承 InputEventAction 以兼容 CoreSystem.handle_input(InputEvent)。
## 此事件仅交给消费者，不再提交 Input.parse_input_event，避免二次映射。
var origin: StringName = &"native"
var payload: Dictionary = {}
enum Phase { PRESSED, HELD, RELEASED, CHANGED }
var phase: Phase = Phase.PRESSED
var sequence: int = 0
var input_time: float = 0.0
var held_seconds: float = 0.0
#endregion


#region 公共接口
func is_intent_pressed(intent: StringName) -> bool:
	return action == intent and pressed and payload.get("just_pressed", true)


func is_intent_released(intent: StringName) -> bool:
	return action == intent and not pressed

func is_intent_held(intent: StringName) -> bool:
	return action == intent and phase == Phase.HELD

func get_phase_name() -> String:
	return ["pressed", "held", "released", "changed"][phase]

func copy_intent() -> CoreOperationIntent:
	var result := CoreOperationIntent.new()
	result.action = action
	result.pressed = pressed
	result.strength = strength
	result.origin = origin
	result.device = device
	result.payload = payload.duplicate(true)
	result.phase = phase
	result.sequence = sequence
	result.input_time = input_time
	result.held_seconds = held_seconds
	return result
#endregion
