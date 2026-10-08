extends BattleAIPolicy2D
class_name BattleBasicAIPolicy2D
#region 近战、远程及固定炮台的通用规则
@export_enum("melee", "ranged", "stationary") var combat_style: String = "melee"

func decide(controller: BattleAIController2D) -> Dictionary:
	var actor := controller.actor
	var cfg := controller.profile
	var home_delta := controller.home.x - actor.global_position.x
	if controller.returning or absf(home_delta) > cfg.leash_radius:
		controller.returning = absf(home_delta) > cfg.home_tolerance
		controller.target = null
		return {"state": &"RETURN", "axis": controller.movement_to(controller.home.x) if controller.returning else 0.0}
	if not is_instance_valid(controller.target):
		if cfg.patrol_radius <= 0.0 or combat_style == "stationary":
			return {"state": &"IDLE", "axis": 0.0}
		var goal := controller.home.x + cfg.patrol_radius * controller.patrol_direction
		if absf(goal - actor.global_position.x) <= cfg.home_tolerance or actor.motion.on_wall:
			controller.patrol_direction *= -1
			controller.patrol_remaining = cfg.patrol_wait
		if controller.patrol_remaining > 0.0:
			return {"state": &"PATROL_WAIT", "axis": 0.0}
		return {"state": &"PATROL", "axis": controller.movement_to(goal)}
	var offset := controller.target.global_position - actor.global_position
	var direction := signf(offset.x)
	var hp_ratio := actor.attributes.get_vital_value(&"health") / maxf(1.0, actor.attributes.get_value(&"hpMax"))
	if cfg.flee_health_ratio > 0.0 and hp_ratio <= cfg.flee_health_ratio and absf(offset.x) < cfg.maximum_retreat_distance:
		return {"state": &"FLEE", "axis": -direction}
	if controller.retreat_remaining > 0.0 and absf(offset.x) < cfg.maximum_retreat_distance:
		return {"state": &"RETREAT", "axis": -direction}
	if combat_style == "ranged" and absf(offset.x) < cfg.minimum_attack_distance:
		return {"state": &"RETREAT", "axis": -direction}
	if absf(offset.x) <= cfg.attack_range and absf(offset.y) <= cfg.attack_vertical_range:
		return {"state": &"ATTACK" if controller.skill_ready() else &"COOLDOWN", "axis": 0.0, "facing": int(direction), "skill": cfg.attack_skill_id if controller.skill_ready() else &""}
	return {"state": &"CHASE", "axis": direction if combat_style != "stationary" else 0.0, "jump": cfg.jump_obstacles and actor.motion.grounded and (actor.motion.on_wall or offset.y < -cfg.attack_vertical_range)}
#endregion
