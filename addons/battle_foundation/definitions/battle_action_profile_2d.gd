extends Resource
class_name BattleActionProfile2D
#region 战斗规则配置
## 以下锁定时间属于战斗规则；不从动画播放进度判断技能许可。
@export var attack_skill_id: StringName = &"sunwukong_attack1"
## 留空时不启用对应上下文攻击；仅在本角色的配置中绑定技能。
@export var run_attack_skill_id: StringName = &""
@export var jump_attack_skill_id: StringName = &""
@export var source_fps: float = 30.0
@export var attack_lock_frames: int = 10
@export var hurt_lock_frames: int = 8
## 攻击范围在 GAS 技能命中事件中配置；角色场景只保留一个 BattleHitbox2D。
## 平台样例运动参数；原版 jumpSpeed 不能直接当作 Godot 像素/秒。
@export var gravity: float = 1500.0
@export var jump_velocity: float = -620.0
@export var maximum_fall_speed: float = 900.0
@export var second_jump_velocity: float = -620.0
@export var maximum_jumps: int = 2
@export var takeoff_frames: int = 2
@export var landing_frames: int = 1
@export var floor_snap_distance: float = 3.0
@export var maximum_floor_angle: float = PI / 4.0
@export var combo: BattleComboDefinition
## 技能可以覆盖权限；死亡的最高优先级不允许覆盖。
@export var state_rules: Dictionary = {
	&"IDLE": {"move": true, "jump": true, "turn": true, "interrupt_priority": 0},
	&"MOVE": {"move": true, "jump": true, "turn": true, "interrupt_priority": 0},
	&"RUN": {"move": true, "jump": true, "turn": true, "interrupt_priority": 0},
	&"TAKEOFF": {"move": true, "jump": false, "turn": true, "interrupt_priority": 10},
	&"JUMP": {"move": true, "jump": true, "turn": true, "interrupt_priority": 10},
	&"LAND": {"move": true, "jump": true, "turn": true, "interrupt_priority": 10},
	&"RUN_ATTACK": {"move": false, "jump": false, "turn": false, "interrupt_priority": 30},
	&"JUMP_ATTACK": {"move": true, "jump": false, "turn": false, "interrupt_priority": 30},
	&"ATTACK": {"move": false, "jump": false, "turn": false, "interrupt_priority": 30},
	&"HURT": {"move": false, "jump": false, "turn": false, "interrupt_priority": 60},
	&"LAUNCHED": {"move": false, "jump": false, "turn": false, "interrupt_priority": 60},
	&"AIR_HURT": {"move": false, "jump": false, "turn": false, "interrupt_priority": 60},
	&"HIT_LAND": {"move": false, "jump": false, "turn": false, "interrupt_priority": 60},
	&"KNOCKDOWN": {"move": false, "jump": false, "turn": false, "interrupt_priority": 60},
	&"GETUP": {"move": false, "jump": false, "turn": false, "interrupt_priority": 60},
	&"PROTECT": {"move": false, "jump": false, "turn": false, "interrupt_priority": 1000},
	&"DEAD": {"move": false, "jump": false, "turn": false, "interrupt_priority": 1000}
}
#endregion
