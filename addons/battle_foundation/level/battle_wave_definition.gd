extends Resource
class_name BattleWaveDefinition
#region 波次只读定义
@export var wave_id: StringName
@export var region_id: StringName
@export var plan_ids: Array[StringName] = []
## 前置波次完成包括出生完毕和参与通关目标全部死亡。
@export var after_wave_ids: Array[StringName] = []
@export var required_conditions: Array[StringName] = []
#endregion
