extends GameplayAbilityFeature
class_name BattleStatusActivationFeature
#region 无动作的GAS状态技能：可以与正在释放的动作并存
@export var status: GameplayStatusData

func _init() -> void:
	super("BattleStatusActivationFeature")

func can_activate(ability: GameplayAbilityInstance, _context: Dictionary) -> bool:
	var actor := ability.get_owner_entity() as BattleEntity2D
	return not ability.is_active and status != null and actor != null and actor.can_receive_status(status) and not actor.statuses.has_status(status.status_id)

func on_activate(ability: GameplayAbilityInstance, _context: Dictionary) -> void:
	var actor := ability.get_owner_entity() as BattleEntity2D
	actor.statuses.apply_status(status, actor)
	actor.publish_battle_event(&"battle.status_ability.activated", {"ability_id": ability.get_definition().ability_id, "status_id": status.status_id})

func update(ability: GameplayAbilityInstance, _delta: float) -> void:
	# GAS在on_activate之后设置is_active；随后统一完成，不占用攻击时间轴。
	if ability.is_active: ability.end_ability()
#endregion
