extends SceneTree
#region 原生GPU检查全部关卡怪物，不改正式场景结构
var visuals: Array[Node2D] = []
func _initialize() -> void:
 call_deferred("capture")
func capture() -> void:
 if DisplayServer.get_name() == "headless": quit(1); return
 root.size = Vector2i(940,590)
 var names := ["jianwu", "yushoushi", "revival_vessel", "jushi_lingjun"]
 for index in range(names.size()):
  var visual = load("res://data/monsters/%s/visual.tscn" % names[index]).instantiate()
  root.add_child(visual)
  visual.position = Vector2(235 + index%2*470, 285 + index/2*290)
  visual.play_action(&"idle", true)
  visual.advance_animation(0.2)
  visuals.append(visual)
 await shot("idle")
 for visual in visuals:
  visual.play_action(&"attack_1", true)
  visual.advance_animation(visual.get_action_duration(&"attack_1")*0.5)
 await shot("attack")
 for visual in visuals:
  visual.play_action(&"idle", true)
  visual.set_facing(-1)
 await shot("flipped-clean")
 print("PASS GPU: four monster Spine bodies/effects, idle, attacks and mirrored cleanup captured")
 quit()
func shot(name: String) -> void:
 for index in range(3):
  await process_frame
  await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://.cleanup-backup/monster-spine-%s.png" % name)
#endregion
