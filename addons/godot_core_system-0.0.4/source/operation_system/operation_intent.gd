extends InputEventAction
class_name CoreOperationIntent

#region 配置与运行状态
## 语义操作事件，不含键位；继承 InputEventAction 以兼容 CoreSystem.handle_input(InputEvent)。
## 此事件仅交给消费者，不再提交 Input.parse_input_event，避免二次映射。
var origin: StringName = &"native"
var payload: Dictionary = {}
#endregion


#region 公共接口
func is_intent_pressed(intent: StringName) -> bool:
	return action == intent and pressed and payload.get("just_pressed", true)


func is_intent_released(intent: StringName) -> bool:
	return action == intent and not pressed
#endregion
