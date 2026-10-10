extends Node
#region 真实关卡、Core分类音量、原版资源和补给反馈
var scene: Node2D
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func node_count(node: Node) -> int:
	var result := 1
	for child in node.get_children(): result += node_count(child)
	return result

func _ready() -> void:
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	var authored := node_count(scene.get_node("BattleSession/BattlePresentation/Audio"))
	add_child(scene)
	scene.session.set_physics_process(false)
	scene.flow.stop()
	var audio: BattleAudio = scene.session.audio
	check(node_count(audio) == authored and audio._voices.size() == 32, "公共音频及32个音效播放器全部预置，不动态挂载角色")
	check(audio.current_music == "No_1-3" and audio.music.playing and audio.music.bus == &"Music", "首次进入碧玉径自动播放原版关卡循环音乐")
	_verify_assets(audio)
	_verify_actions(audio)
	_verify_supply()
	_verify_settings(audio)
	await _verify_core_music(audio)
	await _verify_lifecycle(audio)
	scene.free()
	await get_tree().process_frame
	if failures.is_empty(): print("PASS battle audio/supply: %d checks; original MP3/glyphs, semantic attacks, bounded authored voices, bus gain/mute/persistence, original music zones, pause, real supply recovery/cap/full, scope and cleanup" % checks)
	else:
		for message in failures: push_error(message)
	get_tree().quit(0 if failures.is_empty() else 1)

func _verify_assets(audio: BattleAudio) -> void:
	for row: Dictionary in audio.catalog.data.sources:
		var stream := load("res://" + String(row.file)) as AudioStreamMP3
		check(stream != null and stream.get_length() > 0, "原版MP3可解码：" + String(row.file))
	var library: BattleDamageNumberLibrary = load("res://data/effects/damage_number_textures.tres")
	check(library.get_group("bleedNumberAdd").size() == 10 and library.get_group("mpNumberAdd").size() == 10, "回血和回魔均使用完整原版数字贴图")

func _verify_actions(audio: BattleAudio) -> void:
	for action in [&"attack_1", &"attack_2", &"attack_3", &"attack_4", &"attack_5", &"run_attack", &"jump_attack", &"skill1", &"skill2", &"skill3", &"skill4", &"skill4_1", &"skill8"]:
		var before := audio.played_count
		scene.player.animation.play_action(action, true)
		var symbol: String = scene.player.animation.profile.animations[action]
		check(audio.played_count == before + 1 and audio.last_sound == audio.resolve_sound("se2001V456", symbol), "语义动作仅播放一次对应原版声音：" + String(action))
	var channel := audio._channels[scene.player.entity_id] as AudioStreamPlayer
	scene.player.animation.play_action(&"idle", true)
	check(not channel.playing, "持续技能取消后停止该动作声音，不残留火眼音效")
	var before := audio.played_count
	scene.player.animation.play_action(&"move", true)
	check(audio.played_count == before, "原资源无行走声音时保持原规则，不借用攻击音效")
	for _index in range(200): audio.play_common("hit")
	check(audio.get_node("Effects").get_child_count() == 32 and audio._voices.size() == 32, "大量命中只复用32个预置槽位，节点数不增长")
	for voice in audio._voices: voice.stop()
	var target := scene.session.spawn_entity_2d("monsters", &"剑舞", scene.player.global_position + Vector2(90,0)) as BattleEntity2D
	target.ai_controller.enabled = false
	target.attributes.set_base_value(&"hpMax",1000)
	target.attributes.get_vital(&"health").set_current_value(1000)
	before = audio.played_count
	var result: Dictionary = scene.player.resolve_attack_hit(target,{"damage_multiplier":1.0})
	check(float(result.get("actual_hp_loss",0)) > 0 and audio.played_count == before + 1 and audio.last_sound == audio.resolve_sound("hs","hit"), "真实GAS命中与结算同时通知时只播放一次公共命中声音")
	scene.session.despawn_entity(target.entity_id)
	before = audio.played_count
	scene.player.attributes.set_level(2)
	check(audio.played_count == before + 1 and audio.last_sound == audio.resolve_sound("hs","levlUp"), "升级通过统一属性入口播放原版升级声音")
	scene.player.attributes.set_level(1)

func _verify_supply() -> void:
	var player: BattleEntity2D = scene.player
	var loot: BattleLootManager2D = scene.session.loot
	var rows: BattleDamageNumberLayer2D = scene.session.presentation.number_rows
	rows.clear_numbers()
	var health := player.attributes.get_vital(&"health")
	var mana := player.attributes.get_vital(&"mana")
	health.set_current_value(health.get_max_value() - 3)
	loot.spawn_item(&"101014001", player.global_position, player)
	check(loot.pickup_drop(0, player), "真实拾取回血补给成功")
	var numbers := rows.get_active_numbers()
	check(numbers.size() == 1 and numbers[0].style == "heal" and numbers[0].number == 3, "绿色回血数字显示上限裁剪后的实际整数恢复值，仅生成一次")
	mana.set_current_value(mana.get_max_value() - 1)
	loot.spawn_item(&"101014003", player.global_position, player)
	check(loot.pickup_drop(0, player), "真实拾取回魔补给成功")
	numbers = rows.get_active_numbers()
	check(numbers.size() == 2 and numbers[1].style == "mana" and numbers[1].number == 1, "蓝色回魔数字使用独立原贴图，显示实际恢复值")
	var expected := player.get_canvas_transform() * (player.global_position + Vector2(0, -120)) + Vector2(0,-60)
	check(numbers[1].position.is_equal_approx(rows.make_canvas_position_local(expected)), "补给跳字沿用原人物注册点和逻辑视口，不受镜像或窗口缩放重复影响")
	var sounds: int = scene.session.audio.played_count
	loot.spawn_item(&"101014001", player.global_position, player)
	check(not loot.pickup_drop(0, player) and loot.drops.size() == 1 and rows.get_active_count() == 2 and scene.session.audio.played_count == sounds, "满值不拾取、不跳字、不播放拾取声音")
	loot.clear_loot()
	rows.advance_numbers(1.0)
	check(rows.get_active_count() == 0 and rows.get_pool_stats().cached >= 2, "补给跳字沿用Tween曲线并在结束后回收到公共池")

func _verify_settings(audio: BattleAudio) -> void:
	var manager := CoreSystem.audio_manager
	var saved_master := manager.get_master_volume()
	var saved_master_mute := manager.is_master_muted()
	var saved_music := manager.get_volume(CoreSystem.AudioManager.AudioType.MUSIC)
	var saved_sfx := manager.get_volume(CoreSystem.AudioManager.AudioType.SOUND_EFFECT)
	var saved_music_mute := manager.is_muted(CoreSystem.AudioManager.AudioType.MUSIC)
	var saved_sfx_mute := manager.is_muted(CoreSystem.AudioManager.AudioType.SOUND_EFFECT)
	scene.original_hud.open_module(&"systemSet")
	check(scene.menu.visible and scene.session.clock.paused and not scene.player.operations.controller.has_control(), "点击原版设置按钮打开菜单并暂停、释放角色控制权")
	var panel := scene.menu.get_node("Margin/Panel/Column/AudioSettings") as BattleAudioSettings
	(panel.get_node("Music/Volume") as HSlider).value = 50
	check(is_equal_approx(manager.get_volume(CoreSystem.AudioManager.AudioType.MUSIC),0.5) and is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")),linear_to_db(0.5)), "音乐滑条即时改变当前音乐总线")
	(panel.get_node("Effects/Volume") as HSlider).value = 25
	check(is_equal_approx(manager.get_volume(CoreSystem.AudioManager.AudioType.SOUND_EFFECT),0.25) and is_equal_approx(manager.get_volume(CoreSystem.AudioManager.AudioType.MUSIC),0.5), "音效滑条与背景音乐相互独立")
	(panel.get_node("Music/Mute") as CheckButton).button_pressed = true
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "仅音乐静音，音效仍可播放")
	(panel.get_node("Music/Mute") as CheckButton).button_pressed = false
	check(is_equal_approx(manager.get_volume(CoreSystem.AudioManager.AudioType.MUSIC),0.5) and not manager.is_muted(CoreSystem.AudioManager.AudioType.MUSIC), "取消静音恢复原音量，无需重新调整滑条")
	manager.set_master_volume(0.8)
	manager.set_muted(CoreSystem.AudioManager.AudioType.SOUND_EFFECT,true)
	scene.menu.set_open(false)
	var config := ConfigFile.new()
	check(config.load(CoreSystem.config_manager.config_path) == OK and config.get_value("audio","sfx_muted",false) and is_equal_approx(float(config.get_value("audio","music_volume",1.0)),0.5), "关闭设置保存独立音量和静音偏好")
	var fresh_manager := CoreSystem.AudioManager.new()
	add_child(fresh_manager)
	check(is_equal_approx(fresh_manager.get_volume(CoreSystem.AudioManager.AudioType.MUSIC),0.5) and fresh_manager.is_muted(CoreSystem.AudioManager.AudioType.SOUND_EFFECT) and is_equal_approx(fresh_manager.get_master_volume(),0.8), "重新初始化插件时恢复保存的音乐、音效静音和主音量")
	fresh_manager.free()
	manager.set_muted(CoreSystem.AudioManager.AudioType.SOUND_EFFECT,false)
	var voice := manager.play_sound(audio.resolve_sound("hs","hit"),0.5)
	check(voice != null and is_equal_approx(voice.volume_db,linear_to_db(0.5)) and is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")),linear_to_db(0.25)), "Core工厂播放不重复乘分类音量：声音0.5与总线0.25各应用一次")
	manager.stop_all()
	manager.set_master_volume(saved_master)
	manager.set_master_muted(saved_master_mute)
	manager.set_volume(CoreSystem.AudioManager.AudioType.MUSIC,saved_music)
	manager.set_volume(CoreSystem.AudioManager.AudioType.SOUND_EFFECT,saved_sfx)
	manager.set_muted(CoreSystem.AudioManager.AudioType.MUSIC,saved_music_mute)
	manager.set_muted(CoreSystem.AudioManager.AudioType.SOUND_EFFECT,saved_sfx_mute)
	manager.save_preferences()
	check(not scene.session.clock.paused, "关闭设置恢复战斗")

func _verify_core_music(audio: BattleAudio) -> void:
	var manager := CoreSystem.audio_manager
	manager.play_music(audio.resolve_sound("No_1-3","music"),0.1)
	manager.play_music(audio.resolve_sound("boss_01","music"),0.1)
	manager.play_music(audio.resolve_sound("No_1-3","music"),0.1)
	var final_music := manager._current_music
	await get_tree().create_timer(0.4).timeout
	check(final_music.playing and is_equal_approx(final_music.volume_db,0) and manager._audio_players[CoreSystem.AudioManager.AudioType.MUSIC].size() <= 2, "连续切歌取消旧补间，最终曲目不会被旧淡出停止；分类音量只施加于总线")
	var fixture := (load(audio.resolve_sound("No_1-3","music")) as AudioStreamMP3).duplicate() as AudioStreamMP3
	fixture.loop = true
	manager._audio_cache["test://audio-loop"] = {"resource":fixture,"type":CoreSystem.AudioManager.AudioType.MUSIC}
	manager.play_music("test://audio-loop",0,false)
	check(manager._current_music.stream != fixture and not manager._current_music.stream.loop and fixture.loop, "关闭循环只复制本次流，不污染共用资源")
	manager._audio_cache.erase("test://audio-loop")
	manager.stop_all()

func _verify_lifecycle(audio: BattleAudio) -> void:
	scene.player.position = Vector2(10300,1056)
	audio.advance_audio()
	check(audio.current_music == "boss_01" and audio.music.playing, "进入原TMX音乐触发范围才切换原版Boss音乐")
	scene.session.set_paused(true)
	audio.advance_audio()
	check(audio.music.stream_paused, "菜单暂停保留背景音乐播放进度")
	scene.session.set_paused(false)
	audio.advance_audio()
	check(not audio.music.stream_paused and audio.current_music == "boss_01", "恢复后继续当前音乐，不从头重播")
	var other := load("res://game/levels/biyujing.tscn").instantiate() as Node2D
	other.enable_player_controls = false
	add_child(other)
	other.session.set_physics_process(false)
	other.flow.stop()
	var before := audio.played_count
	other.session.publish_event(&"battle.loot.picked_up",other.player,null,{"is_supply":true,"restored_amount":0})
	check(audio.played_count == before and audio.current_music == "boss_01", "另一会话拾取不触发本场音效或切换本场音乐")
	other.free()
	await get_tree().process_frame
	check(audio.music.playing and audio.current_music == "boss_01", "另一关卡离场只清理自己的播放器")
	var boss := scene.session.spawn_entity_2d("monsters", &"巨石灵君", Vector2(10400,1056)) as BattleEntity2D
	boss.ai_controller.enabled = false
	boss.attributes.get_vital(&"health").set_current_value(0)
	check(not audio.music.playing and audio.current_music.is_empty(), "Boss死亡立即停止Boss音乐，不等待出口胜利事件")
	scene.session.publish_event(&"battle.level.victory")
	before = audio.played_count
	scene.session.publish_event(&"battle.level.victory")
	check(not audio.music.playing and audio.last_sound == audio.resolve_sound("hs","win") and audio.played_count == before, "通关停止背景音乐并只播放一次原版胜利声音")
	scene.session.clear_battle()
	check(audio._actors.is_empty() and audio._channels.is_empty() and not audio.music.playing, "离场清理绑定与公共播放，不残留关卡音频")
#endregion
