# 全部源码与资源索引

由 [generate_source_index.mjs](generate_source_index.mjs) 从当前文件生成。本文列出全部 135 个 GDScript 文件（含编辑器入口、示例和 UI），不是仅按关键词挑选核心类。实现行为与限制见 [插件 README](../README.md)；本索引只提取声明，不推断逻辑。

公开方法指名称不以下划线开头的方法；导出字段包含多行 export 注解的声明，运行时内部字段需进入源码查看。无 class_name 的脚本以文件名标识；Autoload 名称由 plugin.gd 注册。

## examples

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |

## .

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [plugin.gd](../plugin.gd) | `EditorPlugin` | — | — | — |

## scripts/abilities/ability_nodes

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [AbilityNodeApplyCost](../scripts/abilities/ability_nodes/ability_node_apply_cost.gd) | `AbilityNodeBase` | `vital_id`<br>`cost_amount`<br>`allow_overdraft`<br>`check_only`<br>`vital_comp_name` | — | — |
| [AbilityNodeApplyEffect](../scripts/abilities/ability_nodes/ability_node_apply_effect.gd) | `AbilityNodeBase` | `effects`<br>`effect_key`<br>`use_instigator_as_fallback` | — | — |
| [AbilityNodeApplyStatus](../scripts/abilities/ability_nodes/ability_node_apply_status.gd) | `AbilityNodeBase` | `statuses` | — | — |
| [AbilityNodeBase](../scripts/abilities/ability_nodes/ability_node_base.gd) | `BTAction` | `target_key` | — | — |
| [AbilityNodeCommitCooldown](../scripts/abilities/ability_nodes/ability_node_commit_cooldown.gd) | `AbilityNodeBase` | `cooldown_feature_name` | — | — |
| [AbilityNodeCommitCost](../scripts/abilities/ability_nodes/ability_node_commit_cost.gd) | `AbilityNodeBase` | `cost_feature_name` | — | — |
| [AbilityNodeFaceTarget](../scripts/abilities/ability_nodes/ability_node_face_target.gd) | `AbilityNodeBase` | `target_position_key`<br>`instant`<br>`rotation_speed` | `angle_difference()` | — |
| [AbilityNodePlayAnimation](../scripts/abilities/ability_nodes/ability_node_play_animation.gd) | `AbilityNodeBase` | `cast_target_type`<br>`animation_name`<br>`animation_speed`<br>`play_animation_method` | — | — |
| [AbilityNodeRemoveStatus](../scripts/abilities/ability_nodes/ability_node_remove_status.gd) | `AbilityNodeBase` | `status_ids` | — | — |
| [AbilityNodeSpawnMagicField](../scripts/abilities/ability_nodes/ability_node_spawn_magic_field.gd) | `AbilityNodeBase` | `magic_field_data`<br>`position_key`<br>`attach_to_target` | — | — |
| [AbilityNodeSpawnProjectile](../scripts/abilities/ability_nodes/ability_node_spawn_projectile.gd) | `AbilityNodeBase` | `projectile_data`<br>`projectile_count`<br>`spread_angle`<br>`muzzle_attachment_point` | — | — |
| [AbilityNodeTargetSearch](../scripts/abilities/ability_nodes/ability_node_target_search.gd) | `AbilityNodeBase` | `strategy`<br>`input_target_key`<br>`write_to_key`<br>`fail_if_empty` | — | — |

## scripts/abilities/costs

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [AbilityCostBase](../scripts/abilities/costs/ability_cost_base.gd) | `Resource` | — | `can_pay()`<br>`try_pay()`<br>`get_cost_description()` | — |
| [VitalCost](../scripts/abilities/costs/vital_cost.gd) | `AbilityCostBase` | `vital_id`<br>`amount`<br>`allow_overdraft`<br>`vital_comp_name` | — | — |

## scripts/abilities/definitions

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [ActiveAbilityDefinition](../scripts/abilities/definitions/active_ability_definition.gd) | `GameplayAbilityDefinition` | `animation_name`<br>`animation_speed`<br>`pre_cast_delay`<br>`post_cast_delay`<br>`cooldown_duration`<br>`costs`<br>`effects`<br>`target_key`<br>`targeting_strategy`<br>`input_action` | `create_instance()` | — |
| [ComboAbilityDefinition](../scripts/abilities/definitions/combo_ability_definition.gd) | `GameplayAbilityDefinition` | `combo_steps`<br>`window_duration`<br>`costs`<br>`cooldown_duration`<br>`input_action` | `create_instance()` | — |
| [ProjectileAbilityDefinition](../scripts/abilities/definitions/projectile_ability_definition.gd) | `ActiveAbilityDefinition` | `projectile_data`<br>`projectile_count`<br>`spread_angle`<br>`muzzle_attachment_point`<br>`face_target`<br>`face_target_rotation_speed` | — | — |
| [SacrificeAbilityDefinition](../scripts/abilities/definitions/sacrifice_ability_definition.gd) | `ToggleAbilityDefinition` | `periodic_health_cost`<br>`periodic_health_vital_id`<br>`damage_radius`<br>`periodic_damage_multiplier`<br>`periodic_interval`<br>`area_targeting_strategy`<br>`periodic_damage_effect` | — | — |
| [ToggleAbilityDefinition](../scripts/abilities/definitions/toggle_ability_definition.gd) | `GameplayAbilityDefinition` | `animation_name`<br>`animation_speed`<br>`pre_cast_delay`<br>`post_cast_delay`<br>`cooldown_duration`<br>`costs`<br>`toggle_statuses`<br>`targeting_strategy`<br>`target_key`<br>`icon_when_active` | `create_instance()` | — |

## scripts/abilities/features

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [AbilityInputFeature](../scripts/abilities/features/ability_input_feature.gd) | `GameplayAbilityFeature` | `input_action` | `match_input()`<br>`get_key_text()` | — |
| [CooldownFeature](../scripts/abilities/features/cooldown_feature.gd) | `GameplayAbilityFeature` | `cooldown_duration` | `can_activate()`<br>`update()`<br>`start_cooldown()`<br>`get_cooldown_remaining()`<br>`get_cooldown_progress()` | — |
| [CostFeature](../scripts/abilities/features/cost_feature.gd) | `GameplayAbilityFeature` | `costs` | `can_activate()`<br>`try_pay()` | — |
| [DynamicIconFeature](../scripts/abilities/features/dynamic_icon_feature.gd) | `GameplayAbilityFeature` | `icon_map`<br>`icon_id_key` | `get_current_icon()` | — |
| [EffectModifierFeature](../scripts/abilities/features/effect_modifer_feature.gd) | `GameplayAbilityFeature` | — | `on_activate()` | — |
| [GameplayAbilityFeature](../scripts/abilities/features/gameplay_ability_feature.gd) | `Resource` | — | `initialize()`<br>`can_activate()`<br>`on_activate()`<br>`on_cancel()`<br>`on_completed()`<br>`update()`<br>`on_learned()`<br>`on_forgotten()`<br>`get_description()`<br>`get_animation_name()` | — |
| [PassiveStatusFeature](../scripts/abilities/features/passive_status_feature.gd) | `GameplayAbilityFeature` | `statuses` | `on_learned()`<br>`on_forgotten()` | — |
| [ProjectilePayloadModifierFeature](../scripts/abilities/features/projectile_payload_modifier_feature.gd) | `GameplayAbilityFeature` | — | `on_activate()` | — |
| [ToggleFeature](../scripts/abilities/features/toggle_feature.gd) | `GameplayAbilityFeature` | — | `can_activate()`<br>`on_activate()` | — |

## scripts/abilities

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [GameplayAbilityDefinition](../scripts/abilities/gameplay_ability_definition.gd) | `Resource` | `ability_id`<br>`ability_name`<br>`description`<br>`icon`<br>`disabled`<br>`tags`<br>`preview_strategy`<br>`smart_cast`<br>`features`<br>`execution_tree`<br>`blackboard_defaults` | `create_instance()` | — |
| [GameplayAbilityInstance](../scripts/abilities/gameplay_ability_instance.gd) | `RefCounted` | — | `get_definition()`<br>`get_owner_entity()`<br>`try_activate()`<br>`update()`<br>`end_ability()`<br>`can_activate()`<br>`add_feature()`<br>`remove_feature()`<br>`get_feature()`<br>`has_feature()`<br>`handle_learned()`<br>`handle_forgotten()`<br>`get_bt_instance()`<br>`get_blackboard()`<br>`set_blackboard_var()`<br>`get_blackboard_var()`<br>`clear_blackboard()`<br>`has_targeting()`<br>`should_smart_cast()`<br>`start_targeting()`<br>`update_targeting()`<br>`confirm_targeting()`<br>`cancel_targeting()`<br>`get_current_icon()` | `ability_completed`<br>`ability_data_changed` |

## scripts/abilities/targeting

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [AbilityPreviewStrategy](../scripts/abilities/targeting/ability_preview_strategy.gd) | `Resource` | `indicator_scene`<br>`max_range`<br>`snap_to_ground` | `create_indicator()`<br>`update_indicator()`<br>`cancel_targeting()`<br>`get_targeting_context()` | — |
| [TargetingStrategy](../scripts/abilities/targeting/targeting_strategy.gd) | `Resource` | `filters` | `resolve_targets()` | — |

## scripts/abilities/targeting/strategies

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [AreaTargetingStrategy](../scripts/abilities/targeting/strategies/area_targeting_strategy.gd) | `TargetingStrategy` | `hit_detector` | — | — |
| [GroundTargetingStrategy](../scripts/abilities/targeting/strategies/ground_targeting_strategy.gd) | `TargetingStrategy` | — | — | — |
| [HitDetectorTargetingStrategy](../scripts/abilities/targeting/strategies/hit_detector_targeting_strategy.gd) | `TargetingStrategy` | `hit_detector` | — | — |
| [SelfTargetingStrategy](../scripts/abilities/targeting/strategies/self_targeting_strategy.gd) | `TargetingStrategy` | — | — | — |
| [StrategyCircleArea](../scripts/abilities/targeting/strategies/strategy_circle_area.gd) | `AbilityPreviewStrategy` | — | `update_indicator()`<br>`get_targeting_context()` | — |
| [StrategyCursorChange](../scripts/abilities/targeting/strategies/strategy_cursor_change.gd) | `AbilityPreviewStrategy` | `cursor_texture`<br>`cursor_hotspot`<br>`default_cursor_texture`<br>`default_cursor_hotspot` | `create_indicator()`<br>`get_targeting_context()`<br>`cancel_targeting()`<br>`restore_default_cursor()` | — |
| [StrategyDirectional](../scripts/abilities/targeting/strategies/strategy_directional.gd) | `AbilityPreviewStrategy` | — | `update_indicator()`<br>`get_targeting_context()` | — |

## scripts/abilities/targeting/strategies/hit_detector

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [AreaHitDetector](../scripts/abilities/targeting/strategies/hit_detector/area_hit_detector.gd) | `HitDetectorBase` | `detection_radius`<br>`detection_shape`<br>`collision_mask`<br>`detection_position_source`<br>`max_results`<br>`use_world_position`<br>`exclude_caster` | — | — |
| [HitDetectorBase](../scripts/abilities/targeting/strategies/hit_detector/hit_detector_base.gd) | `Resource` | — | `get_targets()`<br>`is_valid()`<br>`get_description()` | — |
| [MeleeBoxHitDetector](../scripts/abilities/targeting/strategies/hit_detector/melee_box_hit_detector.gd) | `HitDetectorBase` | `box_extents`<br>`offset`<br>`collision_mask`<br>`debug_draw_enabled`<br>`debug_linger_frames`<br>`debug_box_color` | — | — |

## scripts/attributes

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [GameplayAttribute](../scripts/attributes/gameplay_attribute.gd) | `Resource` | `attribute_id`<br>`attribute_display_name`<br>`attribute_description`<br>`attribute_icon`<br>`min_value`<br>`max_value`<br>`is_hidden`<br>`is_percentage`<br>`scalable_value`<br>`round_final_value` | `get_id()` | — |
| [GameplayAttributeInstance](../scripts/attributes/gameplay_attribute_instance.gd) | `RefCounted` | — | `get_value()`<br>`set_scalable_value()`<br>`add_modifier()`<br>`remove_modifier()`<br>`remove_modifiers_by_source()` | `value_changed` |
| [GameplayAttributeModifier](../scripts/attributes/gameplay_attribute_modifier.gd) | `Resource` | `attribute_id`<br>`value`<br>`modifier_type` | — | — |
| [GameplayAttributeSet](../scripts/attributes/gameplay_attribute_set.gd) | `Resource` | `attributes`<br>`scalable_attributes` | `instantiate_attributes()`<br>`resolve_dependencies()`<br>`on_attribute_changed()` | — |

## scripts/attributes/vitals

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [GameplayVital](../scripts/attributes/vitals/gameplay_vital.gd) | `Resource` | `vital_id`<br>`display_name`<br>`max_value_attribute`<br>`regen_rate_attribute` | `initialize()`<br>`create_instance()`<br>`process_regen()`<br>`modify_value()`<br>`get_max_value()`<br>`get_percent()`<br>`set_current_value()` | `value_changed`<br>`depleted`<br>`full` |
| [HealthVital](../scripts/attributes/vitals/health_vital.gd) | `GameplayVital` | — | `modify_value()`<br>`apply_damage()`<br>`heal()` | `health_restored`<br>`health_depleted`<br>`damage_received`<br>`damage_applied` |
| [ManaVital](../scripts/attributes/vitals/mana_vital.gd) | `GameplayVital` | — | `try_spend_mana()` | — |

## scripts/behavior_tree/actions

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [BTAction](../scripts/behavior_tree/actions/bt_action.gd) | `BTNode` | — | — | — |
| [BTCheckVar](../scripts/behavior_tree/actions/bt_check_var.gd) | `BTAction` | `key`<br>`value`<br>`check_exist_only` | — | — |
| [BTLog](../scripts/behavior_tree/actions/bt_log.gd) | `BTAction` | `message`<br>`blackboard_key`<br>`level` | — | — |
| [BTModifyInt](../scripts/behavior_tree/actions/bt_modify_int.gd) | `BTAction` | `variable_key`<br>`value`<br>`operation` | — | — |
| [BTSetVar](../scripts/behavior_tree/actions/bt_set_var.gd) | `BTAction` | `variable_key`<br>`value` | — | — |
| [BTWait](../scripts/behavior_tree/actions/bt_wait.gd) | `BTAction` | `duration`<br>`duration_key` | — | — |
| [BTWaitSignal](../scripts/behavior_tree/actions/bt_wait_signal.gd) | `BTAction` | `signal_key`<br>`timeout`<br>`consume_signal` | `on_blackboard_change()` | — |

## scripts/behavior_tree

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [BTBlackboard](../scripts/behavior_tree/bt_blackboard.gd) | `RefCounted` | — | `set_var()`<br>`get_var()`<br>`has_var()`<br>`erase_var()`<br>`clear()`<br>`get_all_vars()`<br>`set_node_data()`<br>`get_node_data()`<br>`erase_node_data()`<br>`get_all_node_data()` | `value_changed`<br>`value_cleared` |
| [BTInstance](../scripts/behavior_tree/bt_instance.gd) | `RefCounted` | — | `tick()`<br>`reset_tree()`<br>`set_node_status()`<br>`get_node_status()`<br>`has_node_status()`<br>`erase_node_status()`<br>`clear_node_status()`<br>`record_node_execution()`<br>`register_observer()`<br>`unregister_observer()`<br>`evaluate_interruption()`<br>`get_execution_history()` | — |
| [BTNode](../scripts/behavior_tree/bt_node.gd) | `Resource` | `node_id` | `tick()`<br>`reset()` | — |
| [BTRunner](../scripts/behavior_tree/bt_runner.gd) | `Node` | `tree_root`<br>`run_mode`<br>`active` | `tick()`<br>`reset()`<br>`get_blackboard()` | `tree_finished` |

## scripts/behavior_tree/composites

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [BTComposite](../scripts/behavior_tree/composites/bt_composite.gd) | `BTNode` | `children` | `reset()` | — |
| [BTSelector](../scripts/behavior_tree/composites/bt_selector.gd) | `BTComposite` | — | — | — |
| [BTSequence](../scripts/behavior_tree/composites/bt_sequence.gd) | `BTComposite` | — | — | — |
| [BTSwitch](../scripts/behavior_tree/composites/bt_switch.gd) | `BTComposite` | `variable_key` | — | — |

## scripts/behavior_tree/decorators

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [BTCheckVarDecorator](../scripts/behavior_tree/decorators/bt_check_var_decorator.gd) | `BTObserver` | `key`<br>`value`<br>`check_exist_only` | `is_relevant()`<br>`check_condition()` | — |
| [BTDecorator](../scripts/behavior_tree/decorators/bt_decorator.gd) | `BTNode` | `child` | `reset()` | — |
| [BTInverter](../scripts/behavior_tree/decorators/bt_inverter.gd) | `BTDecorator` | — | — | — |
| [BTObserver](../scripts/behavior_tree/decorators/bt_observer.gd) | `BTDecorator` | `abort_type` | `is_relevant()`<br>`check_condition()`<br>`on_blackboard_change()` | — |
| [BTRepeatPeriodic](../scripts/behavior_tree/decorators/bt_repeat_periodic.gd) | `BTDecorator` | `period`<br>`period_key`<br>`execute_immediately`<br>`return_success_on_failure` | — | — |
| [BTRepeatUntilFailure](../scripts/behavior_tree/decorators/bt_repeat_until_failure.gd) | `BTDecorator` | `return_success` | — | — |

## scripts/components

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [GameplayAbilityComponent](../scripts/components/gameplay_ability_component.gd) | `Node` | `_initial_abilities`<br>`externally_driven` | `advance_simulation()`<br>`initialize()`<br>`match_input()`<br>`learn_ability()`<br>`forget_ability()`<br>`disable_ability()`<br>`enable_ability()`<br>`get_ability_instance()`<br>`get_all_ability_instances()`<br>`can_activate_ability()`<br>`try_activate_ability()`<br>`cancel_ability()`<br>`get_current_casting_ability()`<br>`get_all_ability_ids()`<br>`has_ability()`<br>`request_ability_preview()`<br>`cancel_ability_preview()`<br>`has_targeting_ability()`<br>`get_current_targeting_ability()` | `ability_learned`<br>`ability_forgotten`<br>`ability_activated`<br>`ability_completed` |
| [GameplayAttributeComponent](../scripts/components/gameplay_attribute_component.gd) | `Node` | `_active_sets` | `initialize()`<br>`get_value()`<br>`get_attribute()`<br>`set_base_value()`<br>`has_attribute()`<br>`add_modifier()`<br>`remove_modifier()`<br>`remove_modifiers_by_source()`<br>`get_level()`<br>`set_level()`<br>`begin_update()`<br>`end_update()` | `attribute_value_changed`<br>`level_changed`<br>`attributes_recalculated` |
| [GameplayStatusComponent](../scripts/components/gameplay_status_component.gd) | `Node` | `externally_driven`<br>`filter_events_by_owner` | `advance_simulation()`<br>`apply_status()`<br>`remove_instance()`<br>`remove_status()`<br>`clear_statuses()`<br>`remove_statuses_by_tags()`<br>`get_active_statuses()`<br>`get_status()`<br>`has_status()`<br>`get_random_status()`<br>`handle_event()` | `status_applied`<br>`status_removed`<br>`status_stacked` |
| [GameplayVitalAttributeComponent](../scripts/components/gameplay_vital_attribute_component.gd) | `GameplayAttributeComponent` | `_vitals`<br>`externally_driven` | `advance_simulation()`<br>`initialize()`<br>`has_vital()`<br>`get_vital()`<br>`get_vital_value()`<br>`has_sufficient_vital()`<br>`get_vital_percent()`<br>`modify_vital()` | `vital_value_changed`<br>`vital_depleted` |

## scripts/cues

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [CueAttachedParticle](../scripts/cues/cue_attached_particle.gd) | `GameplayCueBase` | `particle_scene`<br>`attach_to_target`<br>`allow_duplicate` | — | — |
| [CueParticle](../scripts/cues/cue_particle.gd) | `GameplayCueBase` | `particle_scene`<br>`scale_randomness` | — | — |
| [CueTrail](../scripts/cues/cue_trail.gd) | `GameplayCueBase` | `emit_interval`<br>`duration`<br>`ghost_material`<br>`auto_find_all_meshes`<br>`target_mesh_paths`<br>`ghost_color`<br>`ghost_scale` | `update()` | — |
| [GameplayCue](../scripts/cues/gameplay_cue.gd) | `Resource` | `cues` | — | — |
| [GameplayCueBase](../scripts/cues/gameplay_cue_base.gd) | `Resource` | `attachment_point`<br>`offset` | `execute()`<br>`stop()`<br>`update()` | — |

## scripts/damage

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [DamageInfo](../scripts/damage/damage_info.gd) | `RefCounted` | — | `scale_damage()`<br>`record()`<br>`to_dictionary()` | — |
| [DamageLogicStrategy](../scripts/damage/damage_logic_strategy.gd) | `Resource` | — | `calculate()`<br>`calculate_result()`<br>`resolves_invulnerability()` | — |
| [SimpleDamageLogic](../scripts/damage/simple_damage_logic.gd) | `DamageLogicStrategy` | `attack_attribute`<br>`defense_attribute`<br>`crit_rate_attribute`<br>`crit_multiplier` | `calculate()` | — |

## scripts/effects

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [GameplayEffect](../scripts/effects/gameplay_effect.gd) | `Resource` | `filters`<br>`reapply_on_stack`<br>`sub_effects`<br>`target_required_tags`<br>`target_blocked_tags`<br>`cue` | `apply()`<br>`remove()` | — |
| [GameplayEffectModifier](../scripts/effects/gameplay_effect_modifier.gd) | `Resource` | `ability_id`<br>`damage_multiplier`<br>`heal_multiplier`<br>`duration_multiplier`<br>`duration_add`<br>`range_multiplier` | `affects_ability()`<br>`apply_to_context()` | — |
| [GameplayTriggerGuard](../scripts/effects/gameplay_trigger_guard.gd) | `RefCounted` | — | `enter()`<br>`leave()` | — |
| [GE_ApplyDamage](../scripts/effects/ge_apply_damage.gd) | `GameplayEffect` | `damage_multiplier`<br>`invulnerable_block_tag`<br>`damage_strategy`<br>`vital_comp_name`<br>`vital_id` | — | — |
| [GE_ApplyStatus](../scripts/effects/ge_apply_status.gd) | `GameplayEffect` | `status_data`<br>`stacks` | — | — |
| [GE_AttributeModifier](../scripts/effects/ge_attribute_modifier.gd) | `GameplayEffect` | `modifiers`<br>`source_id`<br>`attribute_component_name` | — | — |
| [GE_DispelStatus](../scripts/effects/ge_dispel_status.gd) | `GameplayEffect` | `tags_to_remove` | — | — |
| [GE_ModifyIncomingDamage](../scripts/effects/ge_modify_incoming_damage.gd) | `GameplayEffect` | `damage_multiplier` | — | — |
| [GE_ModifyVital](../scripts/effects/ge_modify_vital.gd) | `GameplayEffect` | `vital_id`<br>`amount`<br>`vital_comp_name` | — | — |
| [GE_SingleFrameMotion](../scripts/effects/ge_single_frame_motion.gd) | `GameplayEffect` | `direction_type`<br>`distance`<br>`ignore_gravity` | — | — |
| [GE_SpawnMagicField](../scripts/effects/ge_spawn_magic_field.gd) | `GameplayEffect` | `magic_field_data`<br>`position_key`<br>`attach_to_target`<br>`target_key` | — | — |
| [GE_StatusTransform](../scripts/effects/ge_status_transform.gd) | `GameplayEffect` | `match_tags`<br>`require_all_tags`<br>`remove_matched_statuses`<br>`statuses_to_apply` | — | — |

## scripts/entites

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [MagicFieldBase](../scripts/entites/magic_field_base.gd) | `Area3D` | — | `destroy()` | — |
| [MagicFieldData](../scripts/entites/magic_field_data.gd) | `Resource` | `duration`<br>`periodic_trigger_interval`<br>`target_selection_mode`<br>`target_count`<br>`targeting_strategy`<br>`magic_field_scene`<br>`payload_statuses` | `apply_to_magic_field()` | — |
| [ProjectileBase](../scripts/entites/projectile_base.gd) | `Area3D` | — | `initialize_velocity()`<br>`set_source_context()`<br>`destroy()` | `impact_triggered`<br>`timeout_triggered` |
| [ProjectileData](../scripts/entites/projectile_data.gd) | `Resource` | `speed`<br>`max_lifetime`<br>`homing_acceleration`<br>`piercing`<br>`max_pierce_count`<br>`movement_strategy`<br>`impact_strategy`<br>`projectile_scene`<br>`payload_statuses` | `apply_to_projectile()` | — |

## scripts/entites/projectile_strategy

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [HomingMovementStrategy](../scripts/entites/projectile_strategy/homing_movement_strategy.gd) | `ProjectileMovementStrategy` | — | — | — |
| [LinearMovementStrategy](../scripts/entites/projectile_strategy/linear_movement_strategy.gd) | `ProjectileMovementStrategy` | — | — | — |
| [ProjectileImpactStrategy](../scripts/entites/projectile_strategy/projectile_impact_strategy.gd) | `Resource` | — | `on_impact()` | — |
| [ProjectileMovementStrategy](../scripts/entites/projectile_strategy/projectile_movement_strategy.gd) | `Resource` | — | `process_movement()` | — |

## scripts/filters

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [FilterTargetByTags](../scripts/filters/filter_target_by_tags.gd) | `GameplayFilterData` | `required_tags`<br>`blocked_tags`<br>`include_inherited` | — | — |
| [GameplayFilterData](../scripts/filters/gameplay_filter.gd) | `Resource` | — | `check()` | — |

## scripts/singletons

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [damage_calculator.gd](../scripts/singletons/damage_calculator.gd) | `Node` | — | `set_strategy()`<br>`calculate_final_damage()`<br>`calculate_damage()`<br>`resolve_strategy()` | — |
| [gameplay_ability_system.gd](../scripts/singletons/gameplay_ability_system.gd) | `Node` | `smart_cast` | `get_component_by_interface()` | — |
| [gameplay_cue_manager.gd](../scripts/singletons/gameplay_cue_manager.gd) | `Node` | — | `execute_cue()`<br>`stop_cue()` | — |
| [gameplay_tag_manager.gd](../scripts/singletons/gameplay_tag_manager.gd) | `Node` | — | `initialize()`<br>`register_tag()`<br>`register_tags()`<br>`register_tags_from_directory()`<br>`unregister_tag()`<br>`add_tag()`<br>`remove_tag()`<br>`force_remove_tag()`<br>`clear_all_tags()`<br>`add_tags()`<br>`remove_tags()`<br>`clear_query_cache()`<br>`has_tag()`<br>`has_any_tag()`<br>`has_all_tags()`<br>`get_tag_count()`<br>`get_all_tags()`<br>`get_tag_inheritance_chain()`<br>`get_tag_exclusions()`<br>`get_tag_resource()`<br>`get_all_tag_resources()`<br>`is_tag_registered()`<br>`validate_tag()`<br>`validate_tag_list()`<br>`tag_inherits_from()`<br>`print_debug_status()` | `tag_added`<br>`tag_removed` |

## scripts/status/duration

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [DurationNaturalTime](../scripts/status/duration/duration_natural_time.gd) | `StatusDurationPolicy` | — | — | — |
| [StatusDurationPolicy](../scripts/status/duration/status_duration_policy.gd) | `Resource` | — | `initialize()`<br>`update()`<br>`refresh()`<br>`accumulate()`<br>`handle_event()` | — |

## scripts/status/features

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [FeatureEventListener](../scripts/status/features/feature_event_listener.gd) | `StatusFeature` | `trigger_on_events`<br>`event_triggered_effects` | `can_trigger_on_event()`<br>`has_event_listening()` | — |
| [FeaturePeriodicEffects](../scripts/status/features/feature_periodic_effects.gd) | `StatusFeature` | `period`<br>`trigger_on_apply`<br>`periodic_effects` | — | — |
| [StatusFeature](../scripts/status/features/status_feature.gd) | `Resource` | `feature_name` | `apply_feature()`<br>`update_feature()`<br>`remove_feature()`<br>`handle_event()`<br>`can_trigger_on_event()`<br>`has_event_listening()` | — |

## scripts/status

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [GameplayStatusData](../scripts/status/gameplay_status_data.gd) | `Resource` | `status_id`<br>`status_display_name`<br>`status_description`<br>`duration`<br>`duration_policy`<br>`icon`<br>`tags`<br>`apply_effects`<br>`remove_effects`<br>`features`<br>`stacking_policy`<br>`max_stacks`<br>`stacking_group`<br>`remove_on_death`<br>`initial_update_delta`<br>`priority`<br>`cue` | `can_trigger_on_event()`<br>`has_event_listening()` | — |
| [GameplayStatusInstance](../scripts/status/gameplay_status_instance.gd) | `RefCounted` | — | `apply()`<br>`remove()`<br>`update()`<br>`add_stack()`<br>`handle_event()`<br>`refresh_duration()`<br>`accumulate_duration()`<br>`apply_effects()`<br>`apply_effects_to()`<br>`get_feature_storage()`<br>`has_event_listening()` | `status_completed` |

## scripts/status/stacking

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [StackingAccumulateDuration](../scripts/status/stacking/stacking_accumulate_duration.gd) | `StatusStackingPolicy` | — | — | — |
| [StackingIntensity](../scripts/status/stacking/stacking_intensity.gd) | `StatusStackingPolicy` | — | — | — |
| [StackingRefreshAndStack](../scripts/status/stacking/stacking_refresh_and_stack.gd) | `StatusStackingPolicy` | — | — | — |
| [StackingRefreshDuration](../scripts/status/stacking/stacking_refresh_duration.gd) | `StatusStackingPolicy` | — | — | — |
| [StatusStackingPolicy](../scripts/status/stacking/status_stacking_policy.gd) | `Resource` | — | `allows_parallel_instances()`<br>`handle_stacking()` | — |

## scripts/tags

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [GameplayTag](../scripts/tags/gameplay_tag.gd) | `Resource` | `id`<br>`display_name`<br>`description`<br>`icon`<br>`border_color`<br>`parent_tag_id`<br>`mutually_exclusive_tags` | — | — |

## scripts/utilties

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [ScalableValue](../scripts/utilties/scalable_value.gd) | `Resource` | `fixed_value`<br>`use_level_scaling`<br>`growth_curve`<br>`base_level` | `get_value_at_level()`<br>`get_base_value()`<br>`get_max_value()` | — |

## ui

| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |
| --- | --- | --- | --- | --- |
| [AbilityBar](../ui/ability_bar.gd) | `HBoxContainer` | `button_scene` | `setup()` | — |
| [AbilityButton](../ui/ability_button.gd) | `MarginContainer` | — | `setup()` | `pressed` |
| [BTDebugPanel](../ui/bt_debug_panel.gd) | `Window` | `toggle_action`<br>`ability_comp_name` | `toggle_visibility()` | — |
| [StatusDebugPanel](../ui/status_debug_panel.gd) | `MarginContainer` | `STATUS_ICON_PREFAB`<br>`status_resource_dir`<br>`status_resource_suffix`<br>`toggle_action` | `toggle_visibility()` | — |
| [StatusIcon](../ui/status_icon.gd) | `MarginContainer` | — | `setup()`<br>`update_stack_display()` | — |
| [tag_debug_panel.gd](../ui/tag_debug_panel.gd) | `MarginContainer` | `toggle_action`<br>`TAG_DISPLAY_ITEM_SCENE` | `toggle_visibility()` | — |
| [tag_display_item.gd](../ui/tag_display_item.gd) | `MarginContainer` | — | `setup()` | — |

## 场景、配置、Shader 与素材

| 文件 | 类型与用途所在模块 |
| --- | --- |
| [.idea/.gitignore](../.idea/.gitignore) |  |
| [.idea/encodings.xml](../.idea/encodings.xml) | xml |
| [.idea/indexLayout.xml](../.idea/indexLayout.xml) | xml |
| [.idea/projectSettingsUpdater.xml](../.idea/projectSettingsUpdater.xml) | xml |
| [.idea/workspace.xml](../.idea/workspace.xml) | xml |
| [assets/circular_progress.tres](../assets/circular_progress.tres) | Godot Resource；示例配置、主题或材质 |
| [assets/effect_icon.svg](../assets/effect_icon.svg) | 矢量图标素材 |
| [assets/theme.tres](../assets/theme.tres) | Godot Resource；示例配置、主题或材质 |
| [plugin.cfg](../plugin.cfg) | 编辑器插件配置 |
| [shaders/circular_progress.gdshader](../shaders/circular_progress.gdshader) | Godot Shader；冷却遮罩或残影视觉 |
| [shaders/ghost_trail.gdshader](../shaders/ghost_trail.gdshader) | Godot Shader；冷却遮罩或残影视觉 |
| [ui/ability_bar.tscn](../ui/ability_bar.tscn) | Godot 场景；示例或 UI 控件层级 |
| [ui/ability_button.tscn](../ui/ability_button.tscn) | Godot 场景；示例或 UI 控件层级 |
| [ui/bt_debug_panel.tscn](../ui/bt_debug_panel.tscn) | Godot 场景；示例或 UI 控件层级 |
| [ui/status_debug_panel.tscn](../ui/status_debug_panel.tscn) | Godot 场景；示例或 UI 控件层级 |
| [ui/status_icon.tscn](../ui/status_icon.tscn) | Godot 场景；示例或 UI 控件层级 |
| [ui/tag_debug_panel.tscn](../ui/tag_debug_panel.tscn) | Godot 场景；示例或 UI 控件层级 |
| [ui/tag_display_item.tscn](../ui/tag_display_item.tscn) | Godot 场景；示例或 UI 控件层级 |

## 文档生成

[generate_diagrams.mjs](generate_diagrams.mjs) 为统一入口，[system_diagrams.mjs](system_diagrams.mjs) 保存模块图布局。运行一次统一入口即重建 19 个 SVG 与此索引；历史 drawio/png 不参与当前实现说明。

旧独立演示已从项目清理；当前功能直接在碧玉径和模板上验证，见 [当前验证目录](../../../tests/README.md)。
