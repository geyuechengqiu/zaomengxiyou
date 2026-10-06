# CoreSystem 全部源码索引

覆盖当前插件全部 85 个 GDScript，含编辑器入口、配置、模块、策略与示例。由 [文档生成工具](../../../tools/generate_core_docs.mjs) 重建。实现说明见 [完整分析](implementation-analysis.md)。

列表提取声明，不代表所有接口已验证；公开方法包含 ready/dispose 等自定义生命周期，内部回调也单独列出。无全局 class_name 的文件通过 CoreSystem preload 常量或路径使用。

## examples/audio_demo

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [audio_demo.gd](../examples/audio_demo/audio_demo.gd) | `Node2D` | `audio_manager`<br>`AUDIO_PATHS` | — | `_ready()`<br>`_start_demo()`<br>`_input()` | — |

## examples/config_demo

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [config_demo.gd](../examples/config_demo/config_demo.gd) | `Node2D` | `status_label`<br>`config_tree`<br>`auto_save_label`<br>`demo_defaults`<br>`_config_manager`<br>`_logger` | — | `_ready()`<br>`_apply_demo_defaults()`<br>`_update_ui()`<br>`_on_modify_button_pressed()`<br>`_on_save_button_pressed()`<br>`_on_reset_button_pressed()`<br>`_on_config_loaded()`<br>`_on_config_saved()`<br>`_on_config_reset()`<br>`_log()` | — |

## examples/event_bus_demo

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [event_bus_demo.gd](../examples/event_bus_demo/event_bus_demo.gd) | `Node2D` | `event_bus` | — | `_ready()`<br>`_start_demo()`<br>`_on_player_move()`<br>`_on_player_move_high_priority()`<br>`_on_player_move_low_priority()`<br>`_on_player_attack_once()`<br>`_on_player_move_right()`<br>`_run_issue48_test()` | — |
| ↳ 内部类型 | `Issue48Listener : RefCounted`<br>`Issue48OtherListener : RefCounted` | 源码内含成员与方法 | — | — | — |

## examples/input_demo/basic

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [basic_demo.gd](../examples/input_demo/basic/basic_demo.gd) | `Node` | `input_manager`<br>`status_label`<br>`input_log` | — | `_ready()`<br>`_setup_input()`<br>`_process()`<br>`_on_action_triggered()`<br>`_on_clear_log_pressed()`<br>`_on_reset_config_pressed()`<br>`_on_sensitivity_value_changed()`<br>`_on_deadzone_value_changed()` | — |

## examples/input_demo/edge_debounce_issue50

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [issue50_edge_debounce_demo.gd](../examples/input_demo/edge_debounce_issue50/issue50_edge_debounce_demo.gd) | `Control` | `_log` | — | `_ready()`<br>`_append_log()`<br>`_run_same_frame_suite()`<br>`_run_spaced_edges_async()`<br>`_on_spaced_edges_pressed()`<br>`_on_same_frame_pressed()`<br>`_on_clear_pressed()` | — |

## examples/input_demo/event_processor

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [processor_demo.gd](../examples/input_demo/event_processor/processor_demo.gd) | `CanvasLayer` | `input_manager`<br>`status_label`<br>`event_log`<br>`priority_display`<br>`filter_settings` | — | `_ready()`<br>`_input()`<br>`_get_event_priority()`<br>`_should_filter_event()`<br>`_process_event()`<br>`_handle_system_event()`<br>`_handle_ui_event()`<br>`_handle_gameplay_event()`<br>`_handle_debug_event()`<br>`_log_event()`<br>`_log_message()`<br>`_update_priority_display()`<br>`_on_clear_log_pressed()`<br>`_on_system_events_toggled()`<br>`_on_ui_events_toggled()`<br>`_on_gameplay_events_toggled()`<br>`_on_debug_events_toggled()` | — |

## examples/input_demo/input_buffer

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [buffer_demo.gd](../examples/input_demo/input_buffer/buffer_demo.gd) | `CanvasLayer` | `input_manager`<br>`status_label`<br>`buffer_display`<br>`input_log`<br>`buffer_window_label`<br>`buffer_window`<br>`active_buffers` | — | `_ready()`<br>`_process()`<br>`_check_inputs()`<br>`_add_skill_buffer()`<br>`_on_skill_ready()`<br>`_execute_skill()`<br>`_create_skill_effect()`<br>`_update_buffer_display()`<br>`_update_status_display()`<br>`_log_input()`<br>`_on_clear_log_pressed()`<br>`_on_buffer_window_value_changed()`<br>`_on_reset_pressed()` | — |

## examples/input_demo/input_recorder

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [recorder_demo.gd](../examples/input_demo/input_recorder/recorder_demo.gd) | `CanvasLayer` | `input_manager`<br>`status_label`<br>`playback_display`<br>`character`<br>`ghost`<br>`record_indicator`<br>`initial_position`<br>`current_movement`<br>`is_moving`<br>`is_jumping`<br>`is_recording`<br>`is_playing`<br>`has_recorded_data` | — | `_ready()`<br>`_exit_tree()`<br>`_update_button_states()`<br>`_get_movement_input()`<br>`_move_character()`<br>`_update_character_color()`<br>`_update_character_label()`<br>`_process()`<br>`_handle_recording()`<br>`_handle_playback()`<br>`_reset_state()`<br>`_handle_error()`<br>`_on_error_dialog_confirmed()`<br>`_validate_state()`<br>`_on_start_record_pressed()`<br>`_on_stop_record_pressed()`<br>`_on_start_playback_pressed()`<br>`_on_stop_playback_pressed()`<br>`_on_save_recording_pressed()`<br>`_on_load_recording_pressed()`<br>`_on_reset_positions_pressed()`<br>`_unhandled_input()`<br>`_update_status_display()` | — |

## examples/input_demo/input_state

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [combo_demo.gd](../examples/input_demo/input_state/combo_demo.gd) | `CanvasLayer` | `input_manager`<br>`status_label`<br>`combo_display`<br>`hold_indicator`<br>`input_log`<br>`combo_count`<br>`last_hit_time`<br>`current_hold_time` | — | `_ready()`<br>`_process()`<br>`_update_combo_system()`<br>`_update_hold_system()`<br>`_handle_punch()`<br>`_handle_kick()`<br>`_handle_special_move()`<br>`_reset_combo()`<br>`_update_combo_display()`<br>`_update_status_display()`<br>`_log_input()`<br>`_on_clear_log_pressed()`<br>`_on_reset_combo_pressed()` | — |

## examples/input_demo

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [settings_ui.gd](../examples/input_demo/settings_ui.gd) | `Control` | `jump_button`<br>`attack_button`<br>`sensitivity_slider`<br>`deadzone_slider`<br>`reset_button` | `update_button_text()`<br>`update_sensitivity()`<br>`update_deadzone()` | `_ready()` | `remap_requested`<br>`sensitivity_changed`<br>`deadzone_changed`<br>`reset_requested` |

## examples/input_demo/virtual_axis

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [axis_visualizer.gd](../examples/input_demo/virtual_axis/axis_visualizer.gd) | `Control` | `current_axis`<br>`axis_color`<br>`deadzone_color`<br>`background_color` | `update_axis()`<br>`set_deadzone()`<br>`set_sensitivity()` | `_ready()`<br>`_draw()` | — |
| [movement_demo.gd](../examples/input_demo/virtual_axis/movement_demo.gd) | `CanvasLayer` | `input_manager`<br>`character`<br>`axis_visualizer`<br>`status_label` | — | `_ready()`<br>`_setup_virtual_axis()`<br>`_physics_process()`<br>`_update_character_movement()`<br>`_update_axis_visualizer()`<br>`_update_status_display()`<br>`_on_sensitivity_value_changed()`<br>`_on_deadzone_value_changed()`<br>`_on_reset_pressed()` | — |

## examples/random_picker_demo

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [test_random_picker.gd](../examples/random_picker_demo/test_random_picker.gd) | `Node` | `_random_pool`<br>`default_items`<br>`picked_count` | — | `_ready()`<br>`_test_edge_cases()`<br>`_test_basic_functionality()`<br>`_test_dynamic_changes()`<br>`_test_stress_performance()`<br>`_create_test_pool()` | — |

## examples/save_demo

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [player.gd](../examples/save_demo/player.gd) | `Node` | `player_name`<br>`player_level`<br>`player_exp`<br>`player_position` | `save()`<br>`load_data()` | `_ready()` | — |
| [save_demo.gd](../examples/save_demo/save_demo.gd) | `Node2D` | `player`<br>`status_label`<br>`save_list`<br>`line_edit_name`<br>`line_edit_level`<br>`line_edit_exp`<br>`label`<br>`_test_issue51_button`<br>`_save_manager`<br>`_logger` | `save_game()`<br>`load_game()`<br>`delete()` | `_ready()`<br>`_update_save_list()`<br>`_update_player_display()`<br>`_on_name_text_changed()`<br>`_on_level_text_changed()`<br>`_on_exp_text_changed()`<br>`_on_create_button_pressed()`<br>`_on_load_button_pressed()`<br>`_on_delete_button_pressed()`<br>`_on_save_created()`<br>`_on_save_loaded()`<br>`_on_save_deleted()`<br>`_on_auto_save_created()`<br>`_on_auto_save_succeeded()`<br>`_on_test_issue51_pressed()` | — |

## examples/scene_demo

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [scene_demo.gd](../examples/scene_demo/scene_demo.gd) | `Node2D` | `scene_manager`<br>`status_label`<br>`buttons`<br>`preload_status`<br>`SCENE_PATHS`<br>`_preloaded_scenes` | — | `_ready()`<br>`_on_scene1_pressed()`<br>`_on_scene2_pressed()`<br>`_on_scene3_pressed()`<br>`_on_scene_loading_started()`<br>`_on_scene_changed()`<br>`_on_scene_loading_finished()`<br>`_on_scene_preloaded()` | — |

## examples/scene_demo/scene_push_stack_issue44

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [issue44_push_stack_demo.gd](../examples/scene_demo/scene_push_stack_issue44/issue44_push_stack_demo.gd) | `Control` | `_status` | — | `_ready()`<br>`_set_status()`<br>`_on_push_scene1_pressed()`<br>`_on_push_scene2_pressed()`<br>`_on_pop_pressed()` | — |

## examples/scene_demo/scenes

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [demo_scene.gd](../examples/scene_demo/scenes/demo_scene.gd) | `Control` | `scene_manager`<br>`label`<br>`source_label`<br>`_message`<br>`_source_scene` | `init_state()`<br>`save_state()`<br>`restore_state()` | `_on_back_button_pressed()` | — |

## examples/state_machine

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [example.gd](../examples/state_machine/example.gd) | `Node` | `state_machine_manager`<br>`state_label` | `update_state_display()` | `_ready()`<br>`_unhandled_input()`<br>`_process()` | — |
| [ExampleGameStateMachine](../examples/state_machine/example_game_state_machine.gd) | `BaseStateMachine` | — | — | `_ready()` | — |
| ↳ 内部类型 | `MenuState : BaseState`<br>`GameplayState : BaseStateMachine`<br>`PauseState : BaseState` | 源码内含成员与方法 | — | — | — |

## examples/tag_demo

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [tag_character.gd](../examples/tag_demo/tag_character.gd) | `Node2D` | `tag_container` | `add_tag()`<br>`remove_tag()`<br>`has_tag()`<br>`get_tags()` | — | — |
| [tag_demo.gd](../examples/tag_demo/tag_demo.gd) | `Node2D` | `tag_manager`<br>`status_label`<br>`player`<br>`enemy` | — | `_ready()`<br>`_on_player_move_button_pressed()`<br>`_on_player_attack_button_pressed()`<br>`_on_buff_button_pressed()`<br>`_on_query_button_pressed()`<br>`_update_status()`<br>`_update_buff_display()` | — |

## examples/time_demo

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [time_demo.gd](../examples/time_demo/time_demo.gd) | `Node2D` | `time_manager`<br>`game_time_label`<br>`timer_label`<br>`status_label` | — | `_ready()`<br>`_process()`<br>`_on_speed_button_pressed()`<br>`_on_pause_button_pressed()`<br>`_on_reset_button_pressed()`<br>`_on_time_scale_changed()`<br>`_on_timer_completed()`<br>`_on_time_state_changed()` | — |

## examples/trigger_demo

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [trigger_demo.gd](../examples/trigger_demo/trigger_demo.gd) | `Node2D` | `trigger_manager`<br>`player`<br>`status_label` | — | `_ready()`<br>`_on_area_2d_body_entered()`<br>`_on_area_2d_body_exited()`<br>`_on_button_pressed()`<br>`_on_enter_area()`<br>`_on_button_clicked()`<br>`_on_periodic_trigger()`<br>`_physics_process()` | — |

## 插件入口

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [plugin.gd](../plugin.gd) | `EditorPlugin` | `SYSTEM_PATH` | — | `_enter_tree()`<br>`_disable_plugin()`<br>`_add_project_settings()`<br>`_remove_project_settings()`<br>`_add_setting_dict()`<br>`_remove_setting_dict()`<br>`_add_setting()`<br>`_ensure_project_settings_category()` | — |
| [setting.gd](../setting.gd) | `RefCounted` | — | `get_setting_value()` | — | — |

## source/audio_system

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [audio_manager.gd](../source/audio_system/audio_manager.gd) | `Node` | `audio_node_root`<br>`_audio_players`<br>`_current_music`<br>`_audio_cache`<br>`_volumes`<br>`_master_volume`<br>`_config_manager`<br>`_logger` | `preload_audio()`<br>`play_music()`<br>`play_sound()`<br>`play_voice()`<br>`set_master_volume()`<br>`set_volume()`<br>`get_volume()`<br>`get_master_volume()`<br>`stop_all()`<br>`get_audio_type_from_bus_name()` | `_ready()`<br>`_get_audio_resource()`<br>`_get_audio_player()`<br>`_fade_out_music()`<br>`_fade_in_music()`<br>`_setup_audio_buses()`<br>`_on_music_finished()`<br>`_is_audio_loop()` | — |

## source/config_system

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [config_manager.gd](../source/config_system/config_manager.gd) | `Node` | `config_path`<br>`auto_save`<br>`_config_file`<br>`_modified`<br>`_logger` | `load_config()`<br>`save_config()`<br>`reset_config()`<br>`set_value()`<br>`get_value()`<br>`get_section()`<br>`set_section()`<br>`get_sections()`<br>`has_section()`<br>`has_key()`<br>`is_modified()` | `_init()`<br>`_is_value_modified()` | `config_loaded`<br>`config_saved`<br>`config_reset` |

## source

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [core_system.gd](../source/core_system.gd) | `Node` | `logger`<br>`resource_manager`<br>`audio_manager`<br>`event_bus`<br>`input_manager`<br>`config_manager`<br>`scene_manager`<br>`time_manager`<br>`save_manager`<br>`state_machine_manager`<br>`entity_manager`<br>`trigger_manager`<br>`tag_manager`<br>`operation_manager`<br>`_modules`<br>`_module_scripts` | `is_module_enabled()` | `_create_module()`<br>`_get_module()` | — |

## source/entity_system

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [entity_manager.gd](../source/entity_system/entity_manager.gd) | `Node` | `_entity_resource_cache`<br>`_entity_path_map`<br>`_resource_manager` | `get_entity_scene()`<br>`load_entity()`<br>`unload_entity()`<br>`create_entity()`<br>`update_entity()`<br>`destroy_entity()`<br>`clear_entities()` | `_ready()` | `entity_loaded`<br>`entity_unloaded`<br>`entity_created`<br>`entity_destroyed` |

## source/event_system

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [event_bus.gd](../source/event_system/event_bus.gd) | `Node` | `_event_history`<br>`_event_metadata`<br>`enable_history`<br>`max_history_length`<br>`debug_mode` | `push_event()`<br>`subscribe()`<br>`subscribe_unique_script()`<br>`unsubscribe()`<br>`subscribe_once()`<br>`unsubscribe_all()`<br>`clear_subscriptions()`<br>`get_subscriber_count()`<br>`get_event_history()`<br>`clear_event_history()`<br>`get_subscription_counts()` | `_record_event()`<br>`_get_all_signals()`<br>`_get_object_id()`<br>`_sort_connections_by_priority()`<br>`_schedule_deferred_call()`<br>`_do_deferred_call()` | `event_pushed`<br>`event_handled` |

## source/input_system/config

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [InputConfig](../source/input_system/config/input_config.gd) | `Resource` | `_config` | `reset_to_default()`<br>`update_config()`<br>`get_config()`<br>`get_action_mappings()`<br>`set_action_mapping()`<br>`remove_action_mapping()`<br>`get_axis_mappings()`<br>`set_axis_mapping()`<br>`remove_axis_mapping()`<br>`get_device_mappings()`<br>`set_device_mapping()`<br>`remove_device_mapping()`<br>`get_input_settings()`<br>`update_input_settings()`<br>`get_deadzone()`<br>`set_deadzone()`<br>`get_axis_sensitivity()`<br>`set_axis_sensitivity()`<br>`is_vibration_enabled()`<br>`set_vibration_enabled()`<br>`get_vibration_strength()`<br>`set_vibration_strength()` | `_init()` | `config_changed` |
| [InputConfigAdapter](../source/input_system/config/input_config_adapter.gd) | `RefCounted` | `_config_manager`<br>`_input_config` | `get_input_config()`<br>`save_config()`<br>`reset_to_default()`<br>`get_action_mappings()`<br>`set_action_mapping()`<br>`remove_action_mapping()`<br>`get_axis_mappings()`<br>`set_axis_mapping()`<br>`remove_axis_mapping()`<br>`get_device_mappings()`<br>`set_device_mapping()`<br>`remove_device_mapping()`<br>`get_input_settings()`<br>`update_input_settings()`<br>`get_deadzone()`<br>`set_deadzone()`<br>`get_axis_sensitivity()`<br>`set_axis_sensitivity()`<br>`is_vibration_enabled()`<br>`set_vibration_enabled()`<br>`get_vibration_strength()`<br>`set_vibration_strength()` | `_init()`<br>`_on_config_loaded()`<br>`_on_config_saved()`<br>`_on_input_config_changed()` | `config_updated` |

## source/input_system/features

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [InputBuffer](../source/input_system/features/input_buffer.gd) | `RefCounted` | `_buffers`<br>`_default_buffer_duration` | `set_buffer_duration()`<br>`get_buffer_duration()`<br>`add_buffer()`<br>`has_buffer()`<br>`get_buffer_strength()`<br>`clear_buffer()`<br>`clear_all_buffers()`<br>`clean_expired_buffers()`<br>`get_all_buffers()` | — | — |
| ↳ 内部类型 | `BufferData` | 源码内含成员与方法 | — | — | — |
| [InputEventProcessor](../source/input_system/features/input_event_processor.gd) | `RefCounted` | `_handlers`<br>`_filters` | `add_handler()`<br>`remove_handler()`<br>`clear_handlers()`<br>`process_event()`<br>`add_filter()`<br>`remove_filter()`<br>`clear_filters()` | `_init()` | — |
| ↳ 内部类型 | `InputEventHandler`<br>`KeyboardEventHandler : InputEventHandler`<br>`MouseEventHandler : InputEventHandler`<br>`JoypadEventHandler : InputEventHandler`<br>`TouchEventHandler : InputEventHandler`<br>`InputFilter`<br>`KeyFilter : InputFilter`<br>`ActionFilter : InputFilter`<br>`KeyRemapHandler : InputEventHandler`<br>`KeyComboHandler : InputEventHandler`<br>`GestureHandler : InputEventHandler` | 源码内含成员与方法 | — | — | — |
| [InputRecorder](../source/input_system/features/input_recorder.gd) | `RefCounted` | `is_recording`<br>`is_playing`<br>`record_start_time`<br>`playback_start_time`<br>`_current_playback_index`<br>`_records`<br>`_max_records` | `start_recording()`<br>`stop_recording()`<br>`start_playback()`<br>`stop_playback()`<br>`record_input()`<br>`clear_records()`<br>`set_max_records()`<br>`get_record_count()`<br>`get_record_duration()`<br>`get_records_in_timeframe()`<br>`get_all_records()`<br>`get_last_record()`<br>`get_playback_data()`<br>`is_playback_finished()`<br>`get_total_duration()`<br>`get_playback_progress()`<br>`has_records()`<br>`get_last_record_timestamp()`<br>`get_current_playback_index()`<br>`reset_playback()`<br>`reset()`<br>`save_records_to_file()`<br>`load_records_from_file()` | — | — |
| ↳ 内部类型 | `InputRecord` | 源码内含成员与方法 | — | — | — |
| [InputVirtualAxis](../source/input_system/features/input_virtual_axis.gd) | `RefCounted` | `_axis_mappings`<br>`_sensitivity`<br>`_deadzone` | `register_axis()`<br>`unregister_axis()`<br>`clear_axis()`<br>`update_axis()`<br>`get_axis_value()`<br>`get_axis_mapping()`<br>`get_axis_mappings()`<br>`set_axis_mapping()`<br>`get_registered_axes()`<br>`set_sensitivity()`<br>`get_sensitivity()`<br>`set_deadzone()`<br>`get_deadzone()` | `_calculate_axis_value()`<br>`_get_axis_value()`<br>`_set_axis_value()` | `axis_changed` |
| ↳ 内部类型 | `AxisMapping` | 源码内含成员与方法 | — | — | — |

## source/input_system

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [input_manager.gd](../source/input_system/input_manager.gd) | `Node` | `virtual_axis`<br>`input_buffer`<br>`input_recorder`<br>`input_state`<br>`event_processor`<br>`config_manager` | — | `_ready()`<br>`_process()`<br>`_input()`<br>`_setup_input_handling()`<br>`_update_input_state()`<br>`_process_action_input()`<br>`_on_axis_changed()` | `action_triggered`<br>`axis_changed`<br>`remap_completed` |
| [InputState](../source/input_system/input_state.gd) | `RefCounted` | `_action_states`<br>`edge_debounce_ms` | `update_action()`<br>`get_action_state()`<br>`is_pressed()`<br>`is_just_pressed()`<br>`is_just_released()`<br>`get_strength()`<br>`get_press_time()`<br>`get_last_press_time()`<br>`get_last_release_time()`<br>`reset_action()`<br>`get_all_states()` | — | — |
| ↳ 内部类型 | `ActionState` | 源码内含成员与方法 | — | — | — |

## source/logger

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [core_logger.gd](../source/logger/core_logger.gd) | `Node` | `default_log_colors`<br>`_current_level`<br>`_enable_file_logging`<br>`_log_file_path`<br>`_log_file`<br>`_log_colors` | `set_level()`<br>`set_color()`<br>`set_colors()`<br>`reset_colors()`<br>`get_colors()`<br>`enable_file_logging()`<br>`debug()`<br>`info()`<br>`warning()`<br>`error()`<br>`fatal()`<br>`print_stack()` | `_init()`<br>`_log()`<br>`_setup_file_logging()` | — |

## source/operation_system

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [CoreOperationController](../source/operation_system/operation_controller.gd) | `Node` | `profile`<br>`device_filter`<br>`native_input_enabled`<br>`controller_id`<br>`_strengths`<br>`_sources` | `process_native_event()`<br>`get_strength()`<br>`is_pressed()`<br>`get_axis()`<br>`submit_intent()`<br>`pulse_intent()`<br>`set_profile()`<br>`clear_native_sources()`<br>`reset()` | `_unhandled_input()`<br>`_input()`<br>`_process_native()`<br>`_event_source()`<br>`_set_source()`<br>`_emit_intent()`<br>`_notification()`<br>`_exit_tree()` | `intent_emitted` |
| [CoreOperationIntent](../source/operation_system/operation_intent.gd) | `InputEventAction` | `origin`<br>`payload` | `is_intent_pressed()`<br>`is_intent_released()` | — | — |
| [CoreOperationManager](../source/operation_system/operation_manager.gd) | `Node` | `_controllers` | `create_controller()`<br>`register_controller()`<br>`get_controller()` | `_unregister_controller()` | — |
| [CoreOperationProfile](../source/operation_system/operation_profile.gd) | `Resource` | `bindings`<br>`axes` | `bind_intent()`<br>`bind_axis()`<br>`get_actions()` | — | — |

## source/resource_system

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [resource_manager.gd](../source/resource_system/resource_manager.gd) | `Node` | `_resource_cache`<br>`_instance_pools`<br>`_lazy_load_interval`<br>`_lazy_load_time`<br>`_loading_count`<br>`_logger` | `load_resource()`<br>`get_cached_resource()`<br>`clear_resource_cache()`<br>`get_instance()`<br>`recycle_instance()`<br>`get_instance_count()`<br>`clear_instance_pool()`<br>`set_lazy_load_interval()` | `_process()`<br>`_lazy_load()` | `resource_loaded`<br>`resource_unloaded` |

## source/save_system

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [game_state_data.gd](../source/save_system/game_state_data.gd) | `Resource` | `metadata`<br>`nodes_state` | — | `_init()` | — |
| [save_manager.gd](../source/save_system/save_manager.gd) | `Node` | `save_directory`<br>`save_group`<br>`default_format`<br>`auto_save_enabled`<br>`auto_save_interval`<br>`auto_save_prefix`<br>`max_auto_saves`<br>`_current_save_id`<br>`_auto_save_timer`<br>`_encryption_key`<br>`_save_strategy`<br>`_pending_node_states`<br>`_strategies`<br>`_logger` | `register_saveable_node()`<br>`set_save_format()`<br>`create_save()`<br>`load_save()`<br>`delete_save()`<br>`create_auto_save()`<br>`get_save_list()`<br>`register_save_format_strategy()` | `_init()`<br>`_process()`<br>`_get_auto_save_id()`<br>`_set_save_format()`<br>`_get_encryption_key()`<br>`_generate_default_key()`<br>`_is_valid_save_file()`<br>`_get_save_id_from_file()`<br>`_ensure_save_directory_exists()`<br>`_get_save_path()`<br>`_clean_old_auto_saves()`<br>`_get_timestamp()`<br>`_generate_save_id()`<br>`_collect_node_states()`<br>`_apply_node_states()` | `save_created`<br>`save_loaded`<br>`save_deleted`<br>`auto_save_started`<br>`auto_save_succeeded`<br>`auto_save_failed` |

## source/save_system/save_format_strategy

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [async_io_strategy.gd](../source/save_system/save_format_strategy/async_io_strategy.gd) | `"./save_format_strategy.gd"` | `_io_manager`<br>`_encryption_key` | `set_encryption_key()`<br>`save()`<br>`load_save()`<br>`load_metadata()`<br>`is_upper_case()` | `_init()`<br>`_process_dictionary()`<br>`_process_array()`<br>`_process_data_for_save()`<br>`_process_variant_for_save()`<br>`_process_dictionary_for_save()`<br>`_process_array_for_save()`<br>`_process_object_for_save()`<br>`_process_data_for_load()`<br>`_process_variant_for_load()`<br>`_process_dictionary_for_load()`<br>`_process_typed_dictionary_for_load()`<br>`_process_array_for_load()`<br>`_process_typed_array_for_load()`<br>`_process_object_for_load()` | — |
| [binary_save_strategy.gd](../source/save_system/save_format_strategy/binary_save_strategy.gd) | `"./async_io_strategy.gd"` | — | `is_valid_save_file()`<br>`get_save_id_from_file()`<br>`get_save_path()` | `_init()` | — |
| [json_save_strategy.gd](../source/save_system/save_format_strategy/json_save_strategy.gd) | `"./async_io_strategy.gd"` | — | `is_valid_save_file()`<br>`get_save_id_from_file()`<br>`get_save_path()` | `_init()` | — |
| [resource_save_strategy.gd](../source/save_system/save_format_strategy/resource_save_strategy.gd) | `"./save_format_strategy.gd"` | — | `is_valid_save_file()`<br>`get_save_id_from_file()`<br>`get_save_path()`<br>`save()`<br>`load_save()`<br>`load_metadata()` | — | — |
| [save_format_strategy.gd](../source/save_system/save_format_strategy/save_format_strategy.gd) | `RefCounted` | — | `is_valid_save_file()`<br>`get_save_id_from_file()`<br>`get_save_path()`<br>`save()`<br>`load_save()`<br>`load_metadata()`<br>`delete_file()`<br>`list_files()` | — | — |

## source/scene_system

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [SceneBase](../source/scene_system/scene_base.gd) | `Node` | — | `init_state()`<br>`save_state()`<br>`restore_state()` | — | — |
| [scene_manager.gd](../source/scene_system/scene_manager.gd) | `Node` | `_current_scene`<br>`_transition_layer`<br>`_transition_rect`<br>`_scene_stack`<br>`_is_switching`<br>`_transitions`<br>`_custom_transitions`<br>`_resource_manager`<br>`_logger`<br>`_preloaded_scenes` | `preload_scene()`<br>`clear_scene_stack()`<br>`change_scene_async()`<br>`pop_scene_async()`<br>`add_sub_scene()`<br>`get_current_scene()`<br>`clear_preloaded_scenes()`<br>`register_transition()` | `_ready()`<br>`_exit_tree()`<br>`_start_transition()`<br>`_end_transition()`<br>`_cleanup_transition()`<br>`_setup_transition_layer()`<br>`_on_viewport_size_changed()`<br>`_setup_default_transitions()`<br>`_do_scene_switch()`<br>`_on_resource_loaded()`<br>`_update_new_scene_camera()` | `scene_loading_started`<br>`scene_loading_finished`<br>`scene_changed`<br>`scene_preloaded` |

## source/scene_system/transitions

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [BaseTransition](../source/scene_system/transitions/base_transition.gd) | `Resource` | `_transition_rect` | `init()`<br>`start()`<br>`end()` | `_reset_state()`<br>`_do_start()`<br>`_do_end()`<br>`_notification()` | — |
| [DissolveTransition](../source/scene_system/transitions/dissolve_transition.gd) | `BaseTransition` | — | — | `_do_start()`<br>`_do_end()` | — |
| [FadeTransition](../source/scene_system/transitions/fade_transition.gd) | `BaseTransition` | — | — | `_do_start()`<br>`_do_end()` | — |
| [SlideTransition](../source/scene_system/transitions/slide_transition.gd) | `BaseTransition` | — | — | `_do_start()`<br>`_do_end()` | — |

## source/state_machine

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [BaseState](../source/state_machine/base_state.gd) | `RefCounted` | `state_id`<br>`state_machine`<br>`agent`<br>`is_active`<br>`_is_ready`<br>`is_debug`<br>`_logger` | `ready()`<br>`dispose()`<br>`enter()`<br>`exit()`<br>`update()`<br>`physics_update()`<br>`handle_input()`<br>`transition_to()`<br>`switch_to()`<br>`get_variable()`<br>`set_variable()`<br>`has_variable()` | `_ready()`<br>`_dispose()`<br>`_enter()`<br>`_exit()`<br>`_update()`<br>`_physics_update()`<br>`_handle_input()`<br>`_debug()`<br>`_agent_setter()` | `state_entered`<br>`state_exited` |
| [BaseStateMachine](../source/state_machine/base_state_machine.gd) | `BaseState` | `current_state`<br>`states`<br>`values`<br>`previous_state` | `enter()`<br>`update()`<br>`physics_update()`<br>`handle_input()`<br>`exit()`<br>`ready()`<br>`dispose()`<br>`start()`<br>`stop()`<br>`pause()`<br>`resume()`<br>`add_state()`<br>`remove_state()`<br>`has_state()`<br>`transition_local()`<br>`transition_to()`<br>`switch()`<br>`get_variable()`<br>`set_variable()`<br>`has_variable()`<br>`erase_variable()`<br>`get_current_state_name()` | `_agent_setter()` | `state_changed` |
| [state_machine_manager.gd](../source/state_machine/state_machine_manager.gd) | `Node` | `_registrations` | `register_state_machine()`<br>`set_registration_drive_flags()`<br>`unregister_state_machine()`<br>`get_state_machine()`<br>`start_state_machine()`<br>`transition_state_machine()`<br>`stop_state_machine()`<br>`get_all_state_machines()`<br>`get_all_state_machine_ids()`<br>`clear_state_machines()`<br>`is_active()`<br>`get_current_state()` | `_process()`<br>`_physics_process()`<br>`_input()`<br>`_get_current_state_linked_tree()`<br>`_recursive_get_active_state_id()` | `state_machine_registered`<br>`state_machine_unregistered`<br>`state_machine_started`<br>`state_machine_stopped` |
| ↳ 内部类型 | `SMRegistration` | 源码内含成员与方法 | — | — | — |

## source/tag_system

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [CoreGameplayTag](../source/tag_system/gameplay_tag.gd) | `RefCounted` | `name`<br>`parent`<br>`children` | `create()`<br>`add_child()`<br>`remove_child()`<br>`get_full_path()`<br>`get_all_children()`<br>`matches()` | — | — |
| [GameplayTagContainer](../source/tag_system/gameplay_tag_container.gd) | `Resource` | `_tags`<br>`_tag_manager` | `add_tag()`<br>`remove_tag()`<br>`has_tag()`<br>`has_all_tags()`<br>`has_any_tags()`<br>`get_tags()`<br>`get_all_tags()` | — | `tag_added`<br>`tag_removed` |
| [gameplay_tag_manager.gd](../source/tag_system/gameplay_tag_manager.gd) | `Node` | `_registered_tags`<br>`_tag_to_objects`<br>`_object_to_tags`<br>`_cleanup_timer` | `get_tag()`<br>`get_matching_tags()`<br>`create_tag_container()`<br>`create_tag_container_from_strings()`<br>`get_objects_with_tag()`<br>`get_objects_with_all_tags()`<br>`get_objects_with_any_tags()` | `_ready()`<br>`_exit_tree()`<br>`_register_tag_from_path()`<br>`_on_container_tag_added()`<br>`_on_container_tag_removed()`<br>`_on_cleanup_timer_timeout()`<br>`_cleanup_invalid_refs()` | — |

## source/time_system

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [time_manager.gd](../source/time_system/time_manager.gd) | `Node` | `_time_scale`<br>`_paused`<br>`_timers`<br>`_game_time` | `set_time_scale()`<br>`get_time_scale()`<br>`set_paused()`<br>`is_paused()`<br>`get_game_time()`<br>`create_timer()`<br>`pause_timer()`<br>`resume_timer()`<br>`reset_timer()`<br>`remove_timer()`<br>`get_timer_remaining()`<br>`has_timer()`<br>`clear_all_timers()` | `_process()` | `time_scale_changed`<br>`timer_completed`<br>`time_state_changed` |
| ↳ 内部类型 | `GameTimer` | 源码内含成员与方法 | — | — | — |

## source/trigger_system/conditions

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [CompositeTriggerCondition](../source/trigger_system/conditions/composite_trigger_condition.gd) | `TriggerCondition` | `conditions`<br>`operator` | `evaluate()` | `_init()` | — |
| [EventTypeTriggerCondition](../source/trigger_system/conditions/event_type_trigger_condition.gd) | `TriggerCondition` | `event_type` | `evaluate()` | `_init()` | — |
| [StateTriggerCondition](../source/trigger_system/conditions/state_trigger_condition.gd) | `TriggerCondition` | `state_name`<br>`required_state` | `evaluate()` | `_init()` | — |

## source/trigger_system

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [GameplayTrigger](../source/trigger_system/gameplay_trigger.gd) | `Resource` | `trigger_type`<br>`conditions`<br>`persistent`<br>`max_triggers`<br>`trigger_count`<br>`trigger_event`<br>`period`<br>`trigger_chance`<br>`_time_since_last_tirgger`<br>`_is_active`<br>`_context`<br>`_trigger_manager` | `activate()`<br>`deactivate()`<br>`update()`<br>`should_trigger()`<br>`execute()`<br>`reset()` | `_init()`<br>`_try_trigger()` | `triggered` |
| [TriggerCondition](../source/trigger_system/trigger_confition.gd) | `Resource` | — | `evaluate()` | `_init()` | — |
| [trigger_manager.gd](../source/trigger_system/trigger_manager.gd) | `Node` | `_event_triggers`<br>`_periodic_triggers`<br>`_condition_types`<br>`_event_bus`<br>`subscribe_event_bus` | `handle_event()`<br>`register_event_trigger()`<br>`unregister_event_trigger()`<br>`register_periodic_trigger()`<br>`unregister_periodic_trigger()`<br>`register_condition_type()`<br>`unregister_condition_type()`<br>`create_condition()` | `_process()`<br>`_on_trigger_triggered()`<br>`_on_event_bus_trigger()` | `triggered` |

## source/utils

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [async_io_manager.gd](../source/utils/async_io_manager.gd) | `RefCounted` | `_task_counter`<br>`_task_id_map`<br>`_io_thread`<br>`_serializer`<br>`_compressor`<br>`_encryptor`<br>`_logger` | `set_serialization_strategy()`<br>`set_compression_strategy()`<br>`set_encryption_strategy()`<br>`read_file_async()`<br>`write_file_async()`<br>`delete_file_async()`<br>`list_files_async()` | `_init()`<br>`_notification()`<br>`_initialize_thread()`<br>`_connect_signals()`<br>`_shutdown()`<br>`_execute_read_operation()`<br>`_execute_write_operation()`<br>`_execute_delete_operation()`<br>`_get_file_list()`<br>`_process_data_for_write()`<br>`_process_data_for_read()`<br>`_generate_task_id()`<br>`_on_task_completed()` | `io_completed` |
| [FileDirHandler](../source/utils/file_dir_handler.gd) | `Node` | — | `get_object_script_dir()` | — | — |
| [frame_splitter.gd](../source/utils/frame_splitter.gd) | `RefCounted` | `items_pre_frame`<br>`max_ms_pre_frame`<br>`_frame_start_time`<br>`_frame_items`<br>`_current_items_per_frame` | `process_array()`<br>`process_range()`<br>`process_iterator()`<br>`process_custom()` | `_init()`<br>`_begin_frame()`<br>`_should_end_frame()`<br>`_update_items_per_frame()`<br>`_wait_next_frame()` | `progress_changed`<br>`completed` |
| [random_picker.gd](../source/utils/random_picker.gd) | `RefCounted` | `_remove_after_pick`<br>`_item_pool`<br>`_logger`<br>`_alias`<br>`_prob`<br>`_total_weight` | `add_item()`<br>`add_items()`<br>`remove_item()`<br>`remove_items()`<br>`update_item_weight()`<br>`update_items_weights()`<br>`get_item_weight()`<br>`get_items_weights()`<br>`get_random_item()`<br>`rebuild_alias_table()`<br>`clear()`<br>`get_remaining_count()`<br>`get_all_items()`<br>`is_empty()`<br>`has_item()`<br>`remove_duplicates()`<br>`convert_to_unified_format()` | `_init()`<br>`_build_alias_table()` | `item_picked`<br>`pool_emptied` |

## source/utils/io_strategies/compression

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [compression_strategy.gd](../source/utils/io_strategies/compression/compression_strategy.gd) | `RefCounted` | — | `compress()`<br>`decompress()` | — | — |
| [GzipCompressionStrategy](../source/utils/io_strategies/compression/gzip_compression_strategy.gd) | `"./compression_strategy.gd"` | — | `compress()`<br>`decompress()` | `_estimate_gzip_uncompressed_size()` | — |
| [no_compression_strategy.gd](../source/utils/io_strategies/compression/no_compression_strategy.gd) | `"./compression_strategy.gd"` | — | `compress()`<br>`decompress()` | — | — |

## source/utils/io_strategies/encryption

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [encryption_strategy.gd](../source/utils/io_strategies/encryption/encryption_strategy.gd) | `RefCounted` | — | `encrypt()`<br>`decrypt()` | — | — |
| [no_encryption_strategy.gd](../source/utils/io_strategies/encryption/no_encryption_strategy.gd) | `"./encryption_strategy.gd"` | — | `encrypt()`<br>`decrypt()` | — | — |
| [xor_encryption_strategy.gd](../source/utils/io_strategies/encryption/xor_encryption_strategy.gd) | `"./encryption_strategy.gd"` | `_logger` | `encrypt()`<br>`decrypt()` | — | — |

## source/utils/io_strategies/serialization

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [json_serialization_strategy.gd](../source/utils/io_strategies/serialization/json_serialization_strategy.gd) | `"./serialization_strategy.gd"` | — | `serialize()`<br>`deserialize()` | — | — |
| [serialization_strategy.gd](../source/utils/io_strategies/serialization/serialization_strategy.gd) | `RefCounted` | — | `serialize()`<br>`deserialize()` | — | — |

## source/utils/threading

| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |
| --- | --- | --- | --- | --- | --- |
| [module_thread.gd](../source/utils/threading/module_thread.gd) | `RefCounted` | `_threads`<br>`_mutex`<br>`_logger` | `submit_task()`<br>`create_thread()`<br>`has_thread()`<br>`unload_thread()`<br>`clear_threads()` | `_notification()`<br>`_ensure_thread_exists_internal()`<br>`_connect_thread_signals()`<br>`_disconnect_thread_signals()`<br>`_on_single_thread_task_completed()`<br>`_on_single_thread_finished()` | `task_completed_on_thread`<br>`all_tasks_finished_on_thread` |
| [single_thread.gd](../source/utils/threading/single_thread.gd) | `RefCounted` | `_thread`<br>`_mutex`<br>`_semaphore`<br>`_is_running`<br>`_task_queue`<br>`_task_id_counter` | `add_task()`<br>`get_pending_task_count()`<br>`stop()` | `_init()`<br>`_notification()`<br>`_thread_function()`<br>`_emit_task_completed()` | `task_completed`<br>`thread_finished` |

## 文档图

- [全部模块结构](core-architecture.svg)
- [输入、意图与状态机](core-input-state.svg)
- [存档、IO 与线程](core-persistence.svg)
- [与 GAS 的接入边界](core-gas-integration.svg)
