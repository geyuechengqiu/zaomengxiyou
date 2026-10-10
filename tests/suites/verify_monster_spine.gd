extends Node
#region Spine 动作与预置角色/怪物模板验收
var checks := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures.append(message)

func _ready() -> void:
 var session := BattleSystem.create_session(self, "res://data/levels/biyujing/progression/manifest.json", 42)
 session.set_physics_process(false)
 for name in ["jianwu", "yushoushi", "revival_vessel", "jushi_lingjun"]:
  var visual := load("res://data/monsters/%s/visual.tscn" % name).instantiate() as SpineAnimationAdapter
  add_child(visual)
  check(visual != null and visual.last_error.is_empty(), name + " Spine初始化")
  var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/monsters/%s/spine_conversion.json" % name))
  for action in visual.profile.animations:
   check(visual.play_action(action, true), name + "/" + String(action) + "动作")
   var duration := visual.get_action_duration(action)
   check(is_equal_approx(duration, float(manifest.actions[String(action)])), name + "原版时长")
   visual.advance_animation(duration * 0.5)
   check(not visual.get_slot_attachment_name(&"Body").is_empty(), name + "动作中身体附件")
   var before := visual.get_visual_bounds_global()
   visual.set_facing(-1)
   var after := visual.get_visual_bounds_global()
   check(absf(before.size.x-after.size.x) < 0.01 and absf(before.position.x + after.end.x) < 0.01, name + "左右镜像注册点 " + str(before) + " / " + str(after))
   visual.set_facing(1)
   visual.play_action(&"idle", true)
   check(visual.get_slot_attachment_name(&"Effect1").is_empty() and visual.get_slot_attachment_name(&"Effect2").is_empty(), name + "动作切回待机清空特效")
  visual.free()
 for template in ["character", "monster"]:
  var saved := load("res://data/templates/%s_definition.tres" % template) as BattleEntityDefinition
  var actors: Array[BattleEntity2D] = []
  for index in range(2):
   var definition := saved.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as BattleEntityDefinition
   var actor := definition.scene.instantiate() as BattleEntity2D
   var count := actor.get_child_count()
   actor.initialize_battle(session, StringName("template/%s/%d" % [template,index]), definition)
   session.add_child(actor)
   if actor.ai_controller != null: actor.ai_controller.enabled = false
   actors.append(actor)
   check(actor.get_child_count() == count, template + "模板组件没有动态补建")
   check(actor.animation is SpineAnimationAdapter and actor.animation.play_action(&"idle",true), template + "模板Spine可播放")
  var health := actors[1].attributes.get_vital_value(&"health")
  actors[0].attributes.modify_vital(&"health", -1)
  check(actors[1].attributes.get_vital_value(&"health") == health, template + "模板生命隔离")
  check(actors[0].abilities != actors[1].abilities and actors[0].action_state != actors[1].action_state and actors[0].statuses != actors[1].statuses, template + "能力状态隔离")
  for actor in actors: actor.free()
 session.free()
 if failures.is_empty():
  print("PASS monster Spine/templates: %d checks; four native skeletons, all semantic actions, original timing, attachment cleanup, facing and authored component/vital isolation" % checks)
  get_tree().quit()
 else:
  for failure in failures: push_error(failure)
  get_tree().quit(1)
#endregion
