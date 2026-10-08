extends GameplayVital
class_name HealthVital
#region 类型与常量

## 生命值 Vital
## 处理伤害、治疗、死亡等逻辑

const DEATH_GROUP_NAME: String = "death"
#endregion
#region 配置与运行状态

## 是否存活
var is_alive: bool:
	get:
		return current_value > 0
#endregion
#region 生命周期与引擎回调

func _init(p_comp: GameplayAttributeComponent = null) -> void:
	# 设置 HealthVital 的默认值（在调用 super 之前设置）
	vital_id = &"health"
	display_name = "生命值"
	max_value_attribute = &"hpMax"  # 依赖原版最大生命属性作为上限
	#regen_rate_attribute = &"reHP"  # 可选：自动回复
#endregion
#region 信号

## 生命值恢复信号
signal health_restored()
## 生命值耗尽信号
signal health_depleted(instigator: Node)
## 接受伤害时发出（在计算减免之前）
signal damage_received(damage_info: DamageInfo)
## 受到伤害时发出（在计算减免之后）
signal damage_applied(damage_info: DamageInfo, final_damage: float)
#endregion
#region 公共接口

func modify_value(amount: float, is_regen: bool = false) -> void:
	if amount >= 0:
		heal(amount)
	else:
		_modify_value(amount, is_regen)

## 核心伤害应用接口
## [param] damage_info: DamageInfo 伤害信息
## [param] owner_entity: Node 拥有者实体
## [return] float 最终伤害值（用于 Cue 系统）
func apply_damage(damage_info: DamageInfo, owner_entity: Node) -> float:
	if damage_info.applied and damage_info.single_use:
		return damage_info.actual_hp_loss
	damage_info.applied = true
	damage_info.actual_hp_loss = 0.0
	damage_info.hp_before = current_value
	damage_info.hp_after = current_value
	if not is_alive or damage_info.is_dodged:
		return 0.0
	var notify_received := _notify_damage_received.bind(damage_info, owner_entity)
	if damage_info.application_resolver.is_valid():
		damage_info.application_resolver.call(damage_info, owner_entity, notify_received)
	else:
		notify_received.call()
	# 战斗宿主可明确配置霸体的受伤倍率；与是否进入硬直没有关系。
	var incoming_multiplier := maxf(0.0, float(damage_info.get_meta(&"battle_received_damage_multiplier", 1.0)))
	damage_info.final_damage *= incoming_multiplier
	damage_info.normal_damage *= incoming_multiplier
	damage_info.true_damage *= incoming_multiplier
	## 原版后置倍率及生命使用 Number；界面舍入不反写结算精度。
	damage_info.hp_before = current_value
	if is_finite(damage_info.final_damage) and damage_info.final_damage > 0.0:
		_modify_value(-damage_info.final_damage)
	damage_info.hp_after = current_value
	damage_info.actual_hp_loss = maxf(0.0, damage_info.hp_before - current_value)
	damage_info.record(&"health", {"before": damage_info.hp_before, "after": current_value, "actual_hp_loss": damage_info.actual_hp_loss})
	if damage_info.actual_hp_loss > 0.0:
		damage_applied.emit(damage_info, damage_info.actual_hp_loss)
		CoreSystem.event_bus.push_event("damage_applied", [{"entity": owner_entity, "damage_info": damage_info}], true)
		if not is_alive:
			_die(damage_info.instigator, owner_entity)
	return damage_info.actual_hp_loss

func _notify_damage_received(damage_info: DamageInfo, owner_entity: Node) -> void:
	damage_received.emit(damage_info)
	CoreSystem.event_bus.push_event("damage_received", [{"entity": owner_entity, "damage_info": damage_info}], true)

## 受到治疗
## [param] amount: float 要增加的生命值数量
func heal(amount: float) -> void:
	if not is_alive: return

	_modify_value(amount)

	# 发出治疗信号
	health_restored.emit()
#endregion
#region 内部实现

## 死亡处理
## [param] instigator: Node 造成死亡的实体
## [param] owner_entity: Node 拥有者实体
func _die(instigator: Node, owner_entity: Node) -> void:
	if is_instance_valid(owner_entity):
		owner_entity.add_to_group(DEATH_GROUP_NAME)
	# 发出死亡信号
	health_depleted.emit(instigator)
#endregion
