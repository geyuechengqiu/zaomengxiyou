extends Resource
class_name BattleFrameEvent
#region 原素材帧事件
## 从 0 开始的原素材帧号；第 12 帧在 30 fps 下对应 0.4 秒。
@export var source_frame: int = 0
@export var event_id: StringName = &"skill.marker"
@export var payload: Dictionary = {}
#endregion
