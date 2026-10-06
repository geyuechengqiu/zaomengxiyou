// #region 脚本实现
// Module diagrams use the same native SVG primitives as generate_diagrams.mjs.
// Class names, members and relationships are curated from the .gd source.
export function generateSystemDiagrams({ diagram, text, card, edge, legend, step }) {
  const X = [50, 650, 1250], Y = row => 210 + row * 380, W = 480, H = 250;
  const c = (name, source, fields, methods, kind = 'Resource', color = 'config') => ({ name, source, fields, methods, kind, color });
  function module(file, title, rows, relations, notes) {
    const nodes = new Map();
    let boxes = '', lines = legend(145);
    rows.forEach((row, r) => row.forEach((node, col) => {
      if (!node) return;
      nodes.set(node.name, { x:X[col], y:Y(r), col, row:r });
      boxes += card(X[col],Y(r),W,H,node.name,`«${node.kind}»`,node.fields,node.methods,node.color,node.source);
    }));
    for (const [relationIndex, relation] of relations.entries()) {
      const [from,to,kind,label=''] = relation;
      const a=nodes.get(from), b=nodes.get(to);
      if (!a || !b) throw new Error(`Missing diagram node: ${from} / ${to}`);
      let d, lx, ly, labelLines = null;
      if (a.row === b.row) {
        const right=a.col<b.col, ax=a.x+(right?W:0), bx=b.x+(right?0:W);
        d=`M${ax} ${a.y+125}H${bx}`; lx=(ax+bx)/2; ly=a.y+108;
        // Keep association labels inside the narrow horizontal gutter.
        labelLines=[];
        let line='', width=0;
        for(const ch of label) {
          const advance=ch.codePointAt(0)<128?9:17;
          if(width+advance>102 && line) { labelLines.push(line); line=''; width=0; }
          line+=ch; width+=advance;
        }
        if(line) labelLines.push(line);
      } else if (a.col === b.col && Math.abs(a.row-b.row)===1) {
        const down=a.row<b.row, ay=a.y+(down?H:0), by=b.y+(down?0:H);
        d=`M${a.x+240} ${ay}V${by}`; lx=a.x+255; ly=Math.min(ay,by)+60;
      } else {
        // Route around cards using row gaps and a column gutter.
        const gutter=a.col===2?1748+(relationIndex%4)*9:a.x+W+20+(relationIndex%4)*20;
        const ay=a.y+H+20+(relationIndex%3)*22, by=b.y+H+25+(relationIndex%4)*20;
        d=`M${a.x+240} ${a.y+H}V${ay}H${gutter}V${by}H${b.x+240}V${b.y+H}`;
        lx=Math.min(gutter,b.x+240)+15; ly=by-10;
      }
      if(labelLines) {
        lines+=edge(d,kind);
        labelLines.forEach((line,i)=>lines+=text(lx,ly-(labelLines.length-1-i)*22,line,'label','middle'));
      } else {
        lines+=edge(d,kind,label,lx,ly);
      }
    }
    const noteY=Y(rows.length-1)+H+110;
    const noteBox=step(50,noteY,1680,85+notes.length*29,'实现要点',notes,'service');
    diagram(file,1800,noteY+115+notes.length*29,title,
      '当前源码类图 · 框内列出关键成员；«类型 : 基类»补充未连线的继承关系 · 点击类框可打开源码',lines+boxes+noteBox);
  }

  module('ability-actions.svg','全部技能动作节点：行为树与运行系统的连接点',[
    [null,c('AbilityNodeBase','abilities/ability_nodes/ability_node_base.gd',['target_key = targets'],['_get_context() / _get_target_list()','_get_first_target() / _validate_context()'],'abstract Resource : BTAction'),null],
    [c('AbilityNodeTargetSearch','abilities/ability_nodes/ability_node_target_search.gd',['strategy / input_target_key','write_to_key / fail_if_empty'],['策略查询 → 写黑板目标列表'],'Resource : AbilityNodeBase'),
     c('AbilityNodeCommitCooldown','abilities/ability_nodes/ability_node_commit_cooldown.gd',['cooldown_feature_name'],['取 Feature → start_cooldown()'],'Resource : AbilityNodeBase'),
     c('AbilityNodeCommitCost','abilities/ability_nodes/ability_node_commit_cost.gd',['cost_feature_name'],['调用 try_pay()，未传递失败结果'],'Resource : AbilityNodeBase')],
    [c('AbilityNodeApplyEffect','abilities/ability_nodes/ability_node_apply_effect.gd',['effects / effect_key'],['逐目标克隆并 apply()'],'Resource : AbilityNodeBase','effect'),
     c('AbilityNodeApplyStatus','abilities/ability_nodes/ability_node_apply_status.gd',['statuses: Dictionary'],['逐目标 apply_status()'],'Resource : AbilityNodeBase'),
     c('AbilityNodeRemoveStatus','abilities/ability_nodes/ability_node_remove_status.gd',['status_ids: Array'],['按 ID 清理；空目标回退施法者'],'Resource : AbilityNodeBase')],
    [c('AbilityNodeSpawnProjectile','abilities/ability_nodes/ability_node_spawn_projectile.gd',['projectile_data / count / spread'],['散射 / 数据注入 / 弹头替换'],'Resource : AbilityNodeBase'),
     c('AbilityNodeSpawnMagicField','abilities/ability_nodes/ability_node_spawn_magic_field.gd',['magic_field_data / position_key'],['位置回退 / 挂载 / 数据注入'],'Resource : AbilityNodeBase'),
     c('AbilityNodeFaceTarget','abilities/ability_nodes/ability_node_face_target.gd',['instant / rotation_speed'],['转向视觉节点；插值时 RUNNING'],'Resource : AbilityNodeBase')],
    [c('AbilityNodeApplyCost','abilities/ability_nodes/ability_node_apply_cost.gd',['vital_id / cost_amount','allow_overdraft / check_only'],['首目标 Vital 检查与直接扣值'],'Resource : AbilityNodeBase'),
     c('AbilityNodePlayAnimation','abilities/ability_nodes/ability_node_play_animation.gd',['animation_name / speed / method'],['_enter(): 调宿主动画方法','_tick(): 立即 SUCCESS'],'Resource : AbilityNodeBase'),null]
  ],[
    ['AbilityNodeCommitCooldown','AbilityNodeBase','inherit','所有动作继承此基类']
  ],['基类读取黑板 context 与目标键；目标既可以是单个 Node，也可以是数组。',
      '动作按各自规则返回 SUCCESS / FAILURE / RUNNING；Effect.apply 返回 void，二者不共享成功协议。',
      '空目标回退仅在各动作明确启用时生效；冷却、费用与已产生效果没有自动事务回滚。']);

  module('attribute-system.svg','属性系统：定义、实例、成长与修改器',[
    [c('GameplayAttributeComponent','components/gameplay_attribute_component.gd',['_active_sets / _attributes','current_level: int'],['initialize() / get_value()','add_modifier() / set_base_value()'],'Node','runtime'),
     c('GameplayAttributeSet','attributes/gameplay_attribute_set.gd',['attributes: Dictionary','scalable_attributes: Dictionary'],['instantiate_attributes()','on_attribute_changed() / 依赖钩子']),
     c('GameplayAttribute','attributes/gameplay_attribute.gd',['attribute_id / min_value / max_value','scalable_value: ScalableValue'],['get_id()'])],
    [c('GameplayAttributeInstance','attributes/gameplay_attribute_instance.gd',['base_value / _cached_final_value','_modifiers / _modifiers_by_source_id'],['get_value() / _recalculate_value()','value_changed(old, new)'],'RefCounted','runtime'),
     c('GameplayAttributeModifier','attributes/gameplay_attribute_modifier.gd',['attribute_id / value / source_id','ADD / MULTIPLY / OVERRIDE'],['由实例添加、删除和来源索引管理']),
     c('ScalableValue','utilties/scalable_value.gd',['fixed_value / use_level_scaling','growth_curve: Curve / base_level'],['get_value_at_level(level)'])],
    [null,null,c('Curve','',['成长曲线；引擎内置 Resource'],['sample(max(0, level-base_level))'],'Godot Resource')]
  ],[
    ['GameplayAttributeComponent','GameplayAttributeSet','shared','配置集合 0..*'],
    ['GameplayAttributeSet','GameplayAttribute','shared','定义键 0..*'],
    ['GameplayAttributeComponent','GameplayAttributeInstance','owned','按属性 ID 保存实例'],
    ['GameplayAttributeInstance','GameplayAttributeModifier','owned','修改器 0..*'],
    ['GameplayAttribute','ScalableValue','shared','可选成长配置'],
    ['ScalableValue','Curve','shared','growth_curve 0..1']
  ],['无 OVERRIDE 时：clamp((base + ΣADD) × (1 + ΣMULTIPLY), min, max)。多个 OVERRIDE 取首个。',
      '变更时立即重算并按差异发信号；随后读取使用缓存。来源 ID 支持状态移除时批量清理。',
      'AttributeSet 的依赖钩子目前为空；衍生属性关系需通过子类显式实现。']);

  module('vital-system.svg','Vital 与伤害：可消耗资源及结算接口',[
    [c('GameplayAttributeComponent','components/gameplay_attribute_component.gd',['_attributes: Dictionary'],['get_value() / attribute_value_changed'],'Node','runtime'),
     c('GameplayVital','attributes/vitals/gameplay_vital.gd',['vital_id / current_value','max_value_attribute','regen_rate_attribute'],['create_instance() / modify_value()','process_regen() / value_changed'],'Resource','runtime'),
     c('DamageCalculator','singletons/damage_calculator.gd',['_strategy: DamageLogicStrategy'],['calculate_final_damage() / set_strategy()'],'autoload Node','service')],
    [c('GameplayVitalAttributeComponent','components/gameplay_vital_attribute_component.gd',['_vitals: Array / _active_vitals','继承属性容器与等级接口'],['initialize() / modify_vital()','get_vital() / has_sufficient_vital()'],'Node : AttributeComponent','runtime'),
     c('HealthVital','attributes/vitals/health_vital.gd',['health / max_health / is_alive: bool','damage_received / damage_applied'],['apply_damage(info, owner) / heal()','health_depleted(instigator)'],'Resource : GameplayVital','runtime'),
     c('DamageLogicStrategy','damage/damage_logic_strategy.gd',[],['calculate(target, instigator, context)','抽象结算接口'],'abstract Resource')],
    [c('ManaVital','attributes/vitals/mana_vital.gd',['mana / max_mana'],['try_spend_mana(amount)'],'Resource : GameplayVital','runtime'),
     c('DamageInfo','damage/damage_info.gd',['instigator / source_component','base_damage / final_damage / is_crit'],['可被同步受伤事件原地修改'],'RefCounted','runtime'),
     c('SimpleDamageLogic','damage/simple_damage_logic.gd',['phy_attack / defense 属性键'],['calculate(): max(1, attack-defense)','读取伤害倍率上下文'],'Resource : DamageLogicStrategy')]
  ],[
    ['GameplayVitalAttributeComponent','GameplayAttributeComponent','inherit'],
    ['GameplayVitalAttributeComponent','HealthVital','owned','活跃 Vital 0..*'],
    ['HealthVital','GameplayVital','inherit'],
    ['DamageCalculator','DamageLogicStrategy','shared','默认 / 覆盖策略'],
    ['SimpleDamageLogic','DamageLogicStrategy','inherit'],
    ['HealthVital','DamageInfo','dependency','提交可变伤害数据']
  ],['先创建属性，再复制 Vital；初始 current = max。上限增加不补满，上限减少会截断当前值。',
      'Health 的事件伤害链与直接扣值不同；普通治疗不能复活。组件对资源不足的负数修改整体拒绝。',
      '恢复速率需显式配置属性键；Mana、Health 模板中的默认恢复键均未开启。']);

  module('status-system.svg','状态系统：容器、生命周期、Feature 与策略',[
    [c('GameplayStatusComponent','components/gameplay_status_component.gd',['_active_statuses: Dictionary','_has_event_listening_statuses: bool'],['apply_status() / remove_status()','_process() / handle_event()'],'Node','runtime'),
     c('GameplayStatusInstance','status/gameplay_status_instance.gd',['stacks / remaining_duration','_cached_context / _feature_storage'],['apply() / update() / remove()','add_stack() / apply_effects()'],'RefCounted','runtime'),
     c('GameplayStatusData','status/gameplay_status_data.gd',['apply_effects / remove_effects / tags','features / duration / max_stacks'],['duration_policy / stacking_policy'])],
    [c('StatusDurationPolicy','status/duration/status_duration_policy.gd',[],['initialize() / update() / refresh()','accumulate() / handle_event()'],'abstract Resource'),
     c('StatusFeature','status/features/status_feature.gd',[],['apply_feature() / update_feature()','remove_feature() / handle_event()']),
     c('StatusStackingPolicy','status/stacking/status_stacking_policy.gd',[],['handle_stacking(old, new, stacks, ctx)'],'abstract Resource')],
    [c('DurationNaturalTime','status/duration/duration_natural_time.gd',['remaining_duration > 0 才递减','负时长视为永久'],['到期返回 true'],'Resource : StatusDurationPolicy'),
     c('FeaturePeriodicEffects','status/features/feature_periodic_effects.gd',['period / periodic_effects','timer 存在状态实例中'],['每次更新最多触发一次'],'Resource : StatusFeature'),
     c('StackingRefreshDuration','status/stacking/stacking_refresh_duration.gd',[],['仅刷新持续时间'],'Resource : StatusStackingPolicy')],
    [c('StackingIntensity','status/stacking/stacking_intensity.gd',[],['add_stack(new, true)'],'Resource : StatusStackingPolicy'),
     c('FeatureEventListener','status/features/feature_event_listener.gd',['trigger_on_events','event_triggered_effects'],['事件匹配 → instance.apply_effects()'],'Resource : StatusFeature'),
     c('StackingRefreshAndStack','status/stacking/stacking_refresh_and_stack.gd',[],['refresh() → add_stack(new, false)'],'Resource : StatusStackingPolicy')],
    [null,null,c('StackingAccumulateDuration','status/stacking/stacking_accumulate_duration.gd',[],['仅累加时间，不增加层数'],'Resource : StatusStackingPolicy')]
  ],[
    ['GameplayStatusComponent','GameplayStatusInstance','owned','按状态 ID 保存'],
    ['GameplayStatusInstance','GameplayStatusData','shared','status_data 1'],
    ['GameplayStatusInstance','StatusFeature','shared','features 0..*'],
    ['GameplayStatusData','StatusStackingPolicy','shared','堆叠策略 0..1'],
    ['GameplayStatusInstance','StatusDurationPolicy','owned','持续时间策略副本'],
    ['DurationNaturalTime','StatusDurationPolicy','inherit'],
    ['FeaturePeriodicEffects','StatusFeature','inherit'],
    ['StackingRefreshDuration','StatusStackingPolicy','inherit'],
    ['FeatureEventListener','StatusFeature','inherit']
  ],['状态实例持有模板引用、独立持续时间策略副本和 Feature 私有存储；效果执行时逐个深复制。',
      '优先级：高替换、低拒绝、相等交给堆叠策略。叠层会先清旧效果，再按新层数重施效果。',
      '到期先移出活跃表，再执行移除效果、清理修改器 / Feature / 标签 / 状态 Cue。']);

  const effectChildren=[
    c('GE_ApplyDamage','effects/ge_apply_damage.gd',['damage_multiplier / damage_strategy'],['计算 → DamageInfo → HealthVital'],'Resource : GameplayEffect','effect'),
    c('GE_ModifyVital','effects/ge_modify_vital.gd',['vital_id / amount'],['modify_vital(amount × stacks)'],'Resource : GameplayEffect','effect'),
    c('GE_AttributeModifier','effects/ge_attribute_modifier.gd',['modifiers / source_id'],['克隆添加 / 按来源删除'],'Resource : GameplayEffect','effect'),
    c('GE_ApplyStatus','effects/ge_apply_status.gd',['status_data / stacks'],['调用状态容器 apply_status()'],'Resource : GameplayEffect','effect'),
    c('GE_DispelStatus','effects/ge_dispel_status.gd',['tags_to_remove'],['按标签移除状态'],'Resource : GameplayEffect','effect'),
    c('GE_StatusTransform','effects/ge_status_transform.gd',['match_tags / statuses_to_apply'],['匹配目标标签 → 移除 / 施加状态'],'Resource : GameplayEffect','effect'),
    c('GE_ModifyIncomingDamage','effects/ge_modify_incoming_damage.gd',['damage_multiplier'],['原地修改 DamageInfo.final_damage'],'Resource : GameplayEffect','effect'),
    c('GE_SpawnMagicField','effects/ge_spawn_magic_field.gd',['magic_field_data / position_key'],['生成场景并注入施法者与数据'],'Resource : GameplayEffect','effect'),
    c('GE_SingleFrameMotion','effects/ge_single_frame_motion.gd',['direction_type / distance'],['CharacterBody3D 单帧位移'],'Resource : GameplayEffect','effect')
  ];
  module('effect-system.svg','Effect 系统：统一入口与全部九种具体效果',[
    [c('GameplayFilterData','filters/gameplay_filter.gd',[],['check() / _check()'],'abstract Resource'),
     c('GameplayEffect','effects/gameplay_effect.gd',['filters / sub_effects','target_required_tags / blocked_tags / cue'],['apply(): 准入 → _apply → Cue → 子效果','remove(): _remove → 子效果'],'abstract Resource','effect'),
     c('GameplayCue','cues/gameplay_cue.gd',['cues: Array[GameplayCueBase]'],['通过管理器执行表现'])],
    effectChildren.slice(0,3),effectChildren.slice(3,6),effectChildren.slice(6,9),
    [c('EffectModifierFeature','abilities/features/effect_modifer_feature.gd',['effect_modifiers: Array'],['on_activate(): 修改 context'],'Resource : GameplayAbilityFeature'),
     c('GameplayEffectModifier','effects/gameplay_effect_modifier.gd',['damage / heal / duration / range 倍率','duration_add / ability_id'],['affects_ability() / apply_to_context()']),null]
  ],[
    ['GameplayEffect','GameplayFilterData','shared','filters 0..*'],
    ['GameplayEffect','GameplayCue','shared','cue 0..1'],
    ['GE_ModifyVital','GameplayEffect','inherit','本图全部 GE_* 继承此基类'],
    ['EffectModifierFeature','GameplayEffectModifier','shared','context 修改器 0..*']
  ],['效果不持有逐帧计时；持续时间属于状态、行为树或载具。准入失败跳过整个 apply 链。',
      'apply 返回 void；子类提前返回不会阻止基类后续 Cue / 子效果。remove 仅有子类明确实现时才能撤销。',
      'GameplayEffectModifier 是独立 Resource，不是 GE 子类；它写上下文键，由具体消费者决定是否生效。']);

  module('ability-definitions.svg','技能定义系统：五种模板如何构造执行树',[
    [c('GameplayAbilityDefinition','abilities/gameplay_ability_definition.gd',['ability_id / execution_tree / features','preview_strategy / blackboard_defaults'],['create_instance(owner)']),
     c('GameplayAbilityInstance','abilities/gameplay_ability_instance.gd',['_definition / _features / _blackboard'],['try_activate() / update() / end_ability()'],'RefCounted','runtime'),
     c('BTNode','behavior_tree/bt_node.gd',['Resource 组成静态执行图'],['tick(instance, delta)'],'abstract Resource')],
    [c('ActiveAbilityDefinition','abilities/definitions/active_ability_definition.gd',['effects / costs / targeting_strategy','pre_cast_delay / post_cast_delay'],['_build_default_behavior_tree()','_inject_features_to_instance()'],'Resource : AbilityDefinition'),
     c('ComboAbilityDefinition','abilities/definitions/combo_ability_definition.gd',['combo_steps: Array[ActiveDefinition]','window_duration / costs / cooldown'],['_build_combo_tree()','BTSwitch + BTWaitSignal + Repeat'],'Resource : AbilityDefinition'),
     c('ToggleAbilityDefinition','abilities/definitions/toggle_ability_definition.gd',['toggle_statuses / icon_when_active','costs / cooldown / targeting_strategy'],['turn_on / keep_on / turn_off 分支'],'Resource : AbilityDefinition')],
    [c('ProjectileAbilityDefinition','abilities/definitions/projectile_ability_definition.gd',['projectile_data / count / spread'],['_build_effect_nodes(): 转身 → 发射'],'Resource : ActiveAbilityDefinition'),null,
     c('SacrificeAbilityDefinition','abilities/definitions/sacrifice_ability_definition.gd',['periodic_health_cost / interval','area_targeting_strategy / damage_effect'],['保持分支：扣血 → 区域目标 → 效果'],'Resource : ToggleAbilityDefinition')]
  ],[
    ['GameplayAbilityDefinition','GameplayAbilityInstance','dependency','工厂创建实例'],
    ['GameplayAbilityInstance','BTNode','shared','BTInstance 引用树根'],
    ['ActiveAbilityDefinition','GameplayAbilityDefinition','inherit'],
    ['ProjectileAbilityDefinition','ActiveAbilityDefinition','inherit'],
    ['SacrificeAbilityDefinition','ToggleAbilityDefinition','inherit']
  ],['模板优先使用显式 execution_tree，否则缓存默认树。节点资源共享，执行进度存于 BTInstance / Blackboard。',
      '主动技能先提交冷却 / 消耗再效果；连击整体付费并等待后续输入；切换技能开启加状态、关闭移除状态。',
      '组合模板仅生成节点和注入 Feature，不替代下层系统的成功检查或清理机制。']);

  module('ability-features.svg','技能 Feature、冷却与消耗系统',[
    [c('GameplayAbilityInstance','abilities/gameplay_ability_instance.gd',['_features: Dictionary','_blackboard: BTBlackboard'],['add_feature() / can_activate()','update() / handle_learned()'],'RefCounted','runtime'),
     c('GameplayAbilityFeature','abilities/features/gameplay_ability_feature.gd',['feature_name'],['initialize / activate / update / complete','learned / forgotten / _get_data'],'abstract Resource'),
     c('BTBlackboard','behavior_tree/bt_blackboard.gd',['FeatureName_key → Variant'],['set_var() / get_var()'],'RefCounted','runtime')],
    [c('CooldownFeature','abilities/features/cooldown_feature.gd',['cooldown_duration'],['can_activate() / start_cooldown()','update() / get_cooldown_progress()'],'Resource : AbilityFeature'),
     c('CostFeature','abilities/features/cost_feature.gd',['costs: Array[AbilityCostBase]'],['can_activate() / try_pay()'],'Resource : AbilityFeature'),
     c('AbilityInputFeature','abilities/features/ability_input_feature.gd',['input_action'],['match_input() / get_key_text()'],'Resource : AbilityFeature')],
    [c('ToggleFeature','abilities/features/toggle_feature.gd',['toggle_action / skip_cost / skip_cd'],['can_activate() / on_activate()'],'Resource : AbilityFeature'),
     c('AbilityCostBase','abilities/costs/ability_cost_base.gd',[],['can_pay() / try_pay()','_can_pay() / _try_pay()'],'abstract Resource'),
     c('DynamicIconFeature','abilities/features/dynamic_icon_feature.gd',['icon_map / icon_id_key'],['get_current_icon()'],'Resource : AbilityFeature')],
    [c('PassiveStatusFeature','abilities/features/passive_status_feature.gd',['statuses: Dictionary'],['on_learned() / on_forgotten()'],'Resource : AbilityFeature'),
     c('VitalCost','abilities/costs/vital_cost.gd',['vital_id / amount / allow_overdraft','_vital_comp 缓存组件引用'],['_can_pay() / _try_pay()'],'Resource : AbilityCostBase'),
     c('EffectModifierFeature','abilities/features/effect_modifer_feature.gd',['effect_modifiers'],['on_activate(): apply_to_context()'],'Resource : AbilityFeature')],
    [c('ProjectilePayloadModifierFeature','abilities/features/projectile_payload_modifier_feature.gd',['payload_status_replacements'],['on_activate(): 写弹头替换映射'],'Resource : AbilityFeature'),null,null]
  ],[
    ['GameplayAbilityInstance','GameplayAbilityFeature','shared','Feature 0..*'],
    ['GameplayAbilityFeature','BTBlackboard','dependency','按 Feature 名隔离私有键'],
    ['CostFeature','GameplayAbilityFeature','inherit'],
    ['CostFeature','AbilityCostBase','shared','costs 0..*'],
    ['VitalCost','AbilityCostBase','inherit']
  ],['Feature 的状态主要保存在实例黑板；配置 Feature 可能直接共享。所有技能每帧更新 Feature，包括未激活技能。',
      '冷却 / 消耗不是 on_activate 自动提交，而由对应 AbilityNodeCommit* 节点调用。',
      'VitalCost 缓存可变组件引用；多个实体共享同一消耗器时需关注缓存绑定。']);

  module('behavior-tree.svg','行为树系统：配置图与每个执行实例的状态',[
    [c('BTRunner','behavior_tree/bt_runner.gd',['tree_root / run_mode / active'],['tick() / tree_finished','独立运行入口，技能不经 Runner'],'Node','runtime'),
     c('BTInstance','behavior_tree/bt_instance.gd',['tree_root / blackboard / _node_status','_observers / execution_history'],['tick() / reset_tree()','evaluate_interruption()'],'RefCounted','runtime'),
     c('BTBlackboard','behavior_tree/bt_blackboard.gd',['_data / _node_memory'],['set_var() / value_changed','get_node_data() / clear()'],'RefCounted','runtime')],
    [c('BTComposite','behavior_tree/composites/bt_composite.gd',['children: Array[BTNode]'],['reset(): 清理并递归子节点'],'abstract Resource : BTNode'),
     c('BTNode','behavior_tree/bt_node.gd',['node_id / SUCCESS-FAILURE-RUNNING'],['tick(): enter → tick → exit','reset() / _get_storage()'],'abstract Resource'),
     c('BTDecorator','behavior_tree/decorators/bt_decorator.gd',['child: BTNode'],['_tick_decorator() / reset()'],'Resource : BTNode')],
    [c('BTSequence','behavior_tree/composites/bt_sequence.gd',['当前子节点索引存在 Blackboard'],['依次成功；失败短路；RUNNING 续跑'],'Resource : BTComposite'),
     c('BTAction','behavior_tree/actions/bt_action.gd',[],['动作扩展基类'],'abstract Resource : BTNode'),
     c('BTObserver','behavior_tree/decorators/bt_observer.gd',['abort_type: NONE / SELF / LOWER'],['check_condition() / is_relevant()','on_blackboard_change()'],'Resource : BTDecorator')],
    [c('BTSelector','behavior_tree/composites/bt_selector.gd',[],['首个成功；全部失败返回 FAILURE'],'Resource : BTComposite'),
     c('BTWaitSignal','behavior_tree/actions/bt_wait_signal.gd',['signal_key / timeout / consume_signal'],['监听黑板值变化；超时失败'],'Resource : BTAction'),
     c('BTCheckVarDecorator','behavior_tree/decorators/bt_check_var_decorator.gd',['key / value / check_exist_only'],['检查变量并观察相关键'],'Resource : BTObserver')],
    [c('BTSwitch','behavior_tree/composites/bt_switch.gd',['variable_key: String'],['黑板索引选择 children[index]'],'Resource : BTComposite'),
     c('BTWait','behavior_tree/actions/bt_wait.gd',['duration / duration_key'],['按真实毫秒时钟等待'],'Resource : BTAction'),
     c('BTRepeatPeriodic','behavior_tree/decorators/bt_repeat_periodic.gd',['period / return_success_on_failure'],['成功后等待再重跑'],'Resource : BTDecorator')],
    [c('BTSetVar','behavior_tree/actions/bt_set_var.gd',['variable_key / value'],['写变量；null 则删除键'],'Resource : BTAction'),
     c('BTCheckVar','behavior_tree/actions/bt_check_var.gd',['key / value / check_exist_only'],['变量不存在则 FAILURE'],'Resource : BTAction'),
     c('BTRepeatUntilFailure','behavior_tree/decorators/bt_repeat_until_failure.gd',['return_success'],['重复成功子树，失败时结束'],'Resource : BTDecorator')],
    [c('BTModifyInt','behavior_tree/actions/bt_modify_int.gd',['variable_key / value / operation'],['整数 SET / ADD / SUBTRACT'],'Resource : BTAction'),
     c('BTLog','behavior_tree/actions/bt_log.gd',['message / blackboard_key / level'],['输出日志后 SUCCESS'],'Resource : BTAction'),
     c('BTInverter','behavior_tree/decorators/bt_inverter.gd',[],['交换成功 / 失败；保留 RUNNING'],'Resource : BTDecorator')]
  ],[
    ['BTRunner','BTInstance','owned','独立实例'],['BTInstance','BTBlackboard','shared','可传入已有黑板'],
    ['BTInstance','BTNode','shared','tree_root 1'],['BTComposite','BTNode','inherit'],['BTDecorator','BTNode','inherit'],
    ['BTAction','BTNode','inherit'],['BTSequence','BTComposite','inherit'],['BTObserver','BTDecorator','inherit'],
    ['BTWaitSignal','BTAction','inherit'],['BTCheckVarDecorator','BTObserver','inherit']
  ],['节点资源共享；每个实例独立保存节点状态、节点私有存储、观察者和最多 100 条执行历史。',
      'BTWaitSignal 监听 Blackboard，不是 AbilityEventBus；重复输入通过黑板 true / false 切换送达。',
      '观察者优先级判断和 active_nodes 维护未完整实现；Runner.reset() 调用不存在的 Instance.reset()。']);

  module('targeting-system.svg','目标选择、命中查询与施法预览',[
    [c('AbilityNodeTargetSearch','abilities/ability_nodes/ability_node_target_search.gd',['input_target_key / write_to_key','strategy / fail_if_empty'],['_tick(): 查询并写入黑板'],'Resource : AbilityNodeBase'),
     c('TargetingStrategy','abilities/targeting/targeting_strategy.gd',['filters: Array[GameplayFilterData]'],['resolve_targets(): 原始目标 → 过滤','_resolve_targets(): abstract'],'abstract Resource'),
     c('GameplayFilterData','filters/gameplay_filter.gd',[],['check() / _check()'],'abstract Resource')],
    [c('SelfTargetingStrategy','abilities/targeting/strategies/self_targeting_strategy.gd',[],['返回 instigator'],'Resource : TargetingStrategy'),
     c('HitDetectorTargetingStrategy','abilities/targeting/strategies/hit_detector_targeting_strategy.gd',['hit_detector: HitDetectorBase'],['委托命中检测器'],'Resource : TargetingStrategy'),
     c('AreaTargetingStrategy','abilities/targeting/strategies/area_targeting_strategy.gd',['hit_detector: AreaHitDetector'],['配置优先，否则从 context 取检测器'],'Resource : TargetingStrategy')],
    [c('GroundTargetingStrategy','abilities/targeting/strategies/ground_targeting_strategy.gd',[],['context.hit_detector 路径已实现','纯 target_position 分支仍为 pass'],'Resource : TargetingStrategy'),
     c('HitDetectorBase','abilities/targeting/strategies/hit_detector/hit_detector_base.gd',[],['get_targets(caster, context)','_get_targets(): abstract'],'abstract Resource'),
     c('AbilityPreviewStrategy','abilities/targeting/ability_preview_strategy.gd',['indicator_scene / max_range'],['create_indicator() / update_indicator()','cancel_targeting()','get_targeting_context()'])],
    [c('AreaHitDetector','abilities/targeting/strategies/hit_detector/area_hit_detector.gd',['radius / mask / position_source'],['intersect_shape() → 父实体去重'],'Resource : HitDetectorBase'),
     c('MeleeBoxHitDetector','abilities/targeting/strategies/hit_detector/melee_box_hit_detector.gd',['box_extents / offset / mask'],['朝向盒查询；可选 DebugDraw'],'Resource : HitDetectorBase'),
     c('StrategyCircleArea','abilities/targeting/strategies/strategy_circle_area.gd',[],['显示范围夹紧后的落点'],'Resource : AbilityPreviewStrategy')],
    [c('StrategyDirectional','abilities/targeting/strategies/strategy_directional.gd',[],['指示朝向；输出 target_direction'],'Resource : AbilityPreviewStrategy'),null,
     c('StrategyCursorChange','abilities/targeting/strategies/strategy_cursor_change.gd',['cursor_texture / default_cursor'],['切换并恢复鼠标光标'],'Resource : AbilityPreviewStrategy')]
  ],[
    ['AbilityNodeTargetSearch','TargetingStrategy','shared','strategy 1'],['TargetingStrategy','GameplayFilterData','shared','filters 0..*'],
    ['HitDetectorTargetingStrategy','TargetingStrategy','inherit'],['HitDetectorTargetingStrategy','HitDetectorBase','shared','detector 0..1'],
    ['MeleeBoxHitDetector','HitDetectorBase','inherit'],['StrategyCircleArea','AbilityPreviewStrategy','inherit']
  ],['Preview 输出坐标 / 方向；TargetingStrategy 输出 Node 列表，二者通过上下文衔接而不是相互继承。',
      '区域检测和近战盒将 collider.get_parent() 当实体；区域去重，近战盒当前不去重。',
      'AreaHitDetector 默认检测位置是施法者；地面 / 命中 / 魔法场位置必须配置位置来源。']);

  module('projectile-system.svg','投射物系统：移动策略、命中策略与状态弹头',[
    [c('AbilityNodeSpawnProjectile','abilities/ability_nodes/ability_node_spawn_projectile.gd',['projectile_data / count / spread','muzzle_attachment_point'],['_spawn_projectile() / payload 替换'],'Resource : AbilityNodeBase'),
     c('ProjectileData','entites/projectile_data.gd',['scene / speed / lifetime / piercing','movement / impact / payload_statuses'],['apply_to_projectile()']),
     c('ProjectileBase','entites/projectile_base.gd',['velocity / instigator / target_reference','_source_context / pierce_count'],['_physics_process() / _handle_impact()','_deliver_payload() / destroy()'],'Area3D','runtime')],
    [c('ProjectileMovementStrategy','entites/projectile_strategy/projectile_movement_strategy.gd',[],['process_movement(): Vector3'],'abstract Resource'),
     c('ProjectileImpactStrategy','entites/projectile_strategy/projectile_impact_strategy.gd',[],['on_impact(): bool 是否消耗投射物'],'abstract Resource'),
     c('GameplayStatusComponent','components/gameplay_status_component.gd',['命中实体必须具备状态组件'],['apply_status(payload, instigator)'],'Node','runtime')],
    [c('LinearMovementStrategy','entites/projectile_strategy/linear_movement_strategy.gd',[],['保持现有 velocity'],'Resource : MovementStrategy'),
     c('HomingMovementStrategy','entites/projectile_strategy/homing_movement_strategy.gd',[],['朝 target_reference 插值方向'],'Resource : MovementStrategy'),null]
  ],[
    ['AbilityNodeSpawnProjectile','ProjectileData','shared','data 1'],['ProjectileData','ProjectileBase','dependency','配置场景实例'],
    ['ProjectileData','ProjectileMovementStrategy','shared','移动策略配置'],
    ['ProjectileData','ProjectileImpactStrategy','shared','命中策略配置'],
    ['ProjectileBase','GameplayStatusComponent','dependency','命中施加 payload'],
    ['LinearMovementStrategy','ProjectileMovementStrategy','inherit'],
    ['HomingMovementStrategy','ProjectileMovementStrategy','inherit']
  ],['载具场景实例化后，数据复制移动 / 命中策略和 payload；每个投射物缓存激活上下文的浅副本。',
      '默认命中：排除施法者 → 施加状态 → 穿透计数 → 发信号 → 按需销毁；自定义 Impact 完全接管命中操作。',
      '追踪目标从 context.targets 读取，查询节点写的是黑板 targets；需要显式桥接这两处。']);

  module('magic-field-system.svg','魔法场系统：区域载具、目标选择与状态清理',[
    [c('AbilityNodeSpawnMagicField','abilities/ability_nodes/ability_node_spawn_magic_field.gd',['magic_field_data / position_key','attach_to_target'],['_get_spawn_position() / _spawn()'],'Resource : AbilityNodeBase'),
     c('MagicFieldData','entites/magic_field_data.gd',['scene / duration / periodic_interval','selection_mode / count / payload'],['apply_to_magic_field()']),
     c('GE_SpawnMagicField','effects/ge_spawn_magic_field.gd',['magic_field_data / position_key'],['_apply(): 从上下文位置生成场景'],'Resource : GameplayEffect','effect')],
    [c('TargetingStrategy','abilities/targeting/targeting_strategy.gd',['可选区域查询与过滤策略'],['resolve_targets()'],'abstract Resource'),
     c('MagicFieldBase','entites/magic_field_base.gd',['instigator / payload_statuses','_targets_in_area / _periodic_timer'],['_on_body_entered() / destroy()','_on_periodic_trigger()','_remove_payload_from_target()'],'Area3D','runtime'),
     c('GameplayStatusComponent','components/gameplay_status_component.gd',['活跃状态表'],['apply_status() / remove_status(id)'],'Node','runtime')],
    [null,c('Timer','',['引擎周期 Timer / 场寿命 Timer'],['timeout → 选目标或销毁'],'Godot Node','runtime'),null]
  ],[
    ['AbilityNodeSpawnMagicField','MagicFieldData','shared','场数据'],['GE_SpawnMagicField','MagicFieldData','shared','场数据'],
    ['MagicFieldData','MagicFieldBase','dependency','赋值载具字段'],
    ['MagicFieldBase','TargetingStrategy','shared','可选策略'],
    ['MagicFieldBase','GameplayStatusComponent','dependency','施加 / 移除状态'],['MagicFieldBase','Timer','owned','周期计时器']
  ],['周期模式：Timer → ALL / RANDOM / NEAREST 选目标 → 施加状态；无策略时重叠 body 要在 Entities 分组。',
      '非周期进入路径没有登记 _targets_in_area；周期刷新返回 null 会覆盖清理 ID；清理行为存在缺口。',
      '场内上下文重新构造，未继承整个技能 context；生成后寿命由场的 Timer 负责。']);

  module('services-system.svg','自动加载服务、标签、过滤与同步事件',[
    [c('GameplayAbilitySystem','singletons/gameplay_ability_system.gd',['smart_cast: bool'],['get_component_by_interface()'],'autoload Node','service'),
     c('AbilityEventBus','singletons/ability_event_bus.gd',[],['trigger_game_event()','game_event_occurred(type, context)'],'autoload Node','service'),
     c('TagManager','singletons/gameplay_tag_manager.gd',['_tag_db / relation caches','_query_cache / entity meta counts'],['register / add / remove / force_remove','has_tag / any / all / inherited'],'autoload Node','service')],
    [c('GameplayStatusComponent','components/gameplay_status_component.gd',['订阅全局广播'],['handle_event(): 转交状态实例'],'Node','runtime'),
     c('GameplayTag','tags/gameplay_tag.gd',['id / parent_tag_id','mutually_exclusive_tags / UI 字段'],['单继承关系与互斥配置']),
     c('FilterTargetByTags','filters/filter_target_by_tags.gd',['required_tags / blocked_tags','include_inherited'],['_check(): ALL required / ANY blocked'],'Resource : GameplayFilterData')],
    [c('GameplayFilterData','filters/gameplay_filter.gd',[],['check() / abstract _check()'],'abstract Resource'),
     c('DamageCalculator','singletons/damage_calculator.gd',['_strategy: DamageLogicStrategy'],['calculate_final_damage()'],'autoload Node','service'),
     c('GameplayCueManager','singletons/gameplay_cue_manager.gd',['_persistent_cues: Array'],['execute_cue() / stop_cue()','_process(): 更新每个 Cue 组件'],'autoload Node','service')]
  ],[
    ['AbilityEventBus','GameplayStatusComponent','dependency','同步广播；无实体过滤'],
    ['TagManager','GameplayTag','shared','定义库 0..*'],['FilterTargetByTags','TagManager','dependency','查询标签'],
    ['FilterTargetByTags','GameplayFilterData','inherit']
  ],['插件启用 / 禁用时注册 / 移除这五个 Autoload。GameplayAbilitySystem 是组件查询服务，不是统一调度器。',
      '标签存于目标 Node 的 meta 引用计数及 tag_* 分组；查询默认包含父标签，不自动给父标签增加计数。',
      '事件总线同步 emit，不排队、不复制字典、不划分实体作用域；伤害事件传递同一个 DamageInfo 引用。']);

  module('cue-system.svg','Cue 表现系统：组合、管理与三种视觉组件',[
    [c('GameplayCueManager','singletons/gameplay_cue_manager.gd',['_persistent_cues: Array'],['execute_cue() / stop_cue()','_process(): update(delta)'],'autoload Node','service'),
     c('GameplayCue','cues/gameplay_cue.gd',['cues: Array[GameplayCueBase]'],['组合表现组件']),
     c('GameplayCueBase','cues/gameplay_cue_base.gd',['attachment_point / offset'],['execute() / update() / stop()','_execute(): abstract'],'abstract Resource')],
    [c('CueParticle','cues/cue_particle.gd',['particle_scene / scale_randomness'],['放到当前场景；finished 时释放'],'Resource : GameplayCueBase'),
     c('CueAttachedParticle','cues/cue_attached_particle.gd',['particle_scene / allow_duplicate','_attached_particles[target]'],['挂点附着 / setup_from_context','stop(target): 清除挂载粒子'],'Resource : GameplayCueBase'),
     c('CueTrail','cues/cue_trail.gd',['emit_interval / duration / material','_active_trails / mesh_paths'],['update(): 创建残影并 Tween 淡出','stop(): 停止新残影'],'Resource : GameplayCueBase')],
    [c('GameplayEffect','effects/gameplay_effect.gd',['cue: GameplayCue'],['逻辑执行后播放 Cue'],'abstract Resource','effect'),
     c('GameplayStatusInstance','status/gameplay_status_instance.gd',['_cue_instance: GameplayCue'],['复制 Cue；状态移除时 stop'],'RefCounted','runtime'),null]
  ],[
    ['GameplayCueManager','GameplayCue','dependency','执行组合'],['GameplayCue','GameplayCueBase','shared','组件 0..*'],
    ['CueTrail','GameplayCueBase','inherit'],['GameplayStatusInstance','GameplayCue','shared','独立状态 Cue 副本'],
    ['GameplayEffect','GameplayCue','shared','效果表现配置']
  ],['逻辑和值变化来自 Effect；Cue 只创建 / 更新视觉节点，不计算伤害或状态持续时间。',
      '挂点接口必须返回 Node3D；管理器无坐标回退。状态 Cue 使用空 context，效果 Cue 使用执行 context。',
      '所有 Cue 组件都会加入持续列表；效果 remove 不会自动 stop Cue，长期运行需关注生命周期。']);

  module('ui-system.svg','UI 与调试：读取运行状态及提交操作请求',[
    [c('AbilityBar','../ui/ability_bar.gd',['button_scene / _buttons'],['setup(comp) / 学习遗忘同步','按按钮广播 ability_button_pressed'],'HBoxContainer','runtime'),
     c('AbilityButton','../ui/ability_button.gd',['_instance / _cd_feature / material'],['setup(instance) / 动态图标','_process(): 冷却 Shader'],'MarginContainer','runtime'),
     c('GameplayAbilityInstance','abilities/gameplay_ability_instance.gd',['黑板 / Feature / Definition'],['ability_data_changed','get_current_icon()'],'RefCounted','runtime')],
    [c('StatusDebugPanel','../ui/status_debug_panel.gd',['状态目录 / 当前实体'],['加载状态 / 添加 / 移除','订阅 status_applied / removed'],'MarginContainer','runtime'),
     c('StatusIcon','../ui/status_icon.gd',['状态实例引用'],['显示层数 / 剩余时间 Tooltip'],'MarginContainer','runtime'),
     c('BTDebugPanel','../ui/bt_debug_panel.gd',['选择的技能实例 / 树视图'],['显示树状态 / 黑板 / 执行历史'],'Window','runtime')],
    [c('tag_debug_panel.gd','../ui/tag_debug_panel.gd',['当前实体 / 标签输入'],['add / remove / force_remove / clear'],'MarginContainer 无 class_name','runtime'),
     c('tag_display_item.gd','../ui/tag_display_item.gd',['标签资源 / 引用计数'],['setup(): 标签显示与 Tooltip'],'MarginContainer 无 class_name','runtime'),null]
  ],[
    ['AbilityBar','AbilityButton','owned','按钮 0..*'],['AbilityButton','GameplayAbilityInstance','shared','读取实例'],
    ['StatusDebugPanel','StatusIcon','owned','状态图标 0..*'],
    ['tag_debug_panel.gd','tag_display_item.gd','owned','标签行 0..*']
  ],['UI 的 setup 由宿主调用；AbilityBar 只发按钮事件，宿主需把事件接到激活 / 预览和目标上下文。',
      '调试面板通过 Entities 分组发现对象；状态 / 标签操作修改真实运行状态。',
      'circular_progress Shader 显示技能冷却；ghost_trail Shader 配合残影 Tween 控制透明度。']);

  let joint=legend(145);
  const box=(x,y,name,fields,methods,color,source,kind='Node')=>card(x,y,480,250,name,`«${kind}»`,fields,methods,color,source);
  joint+=box(50,220,'GameplayAbilityComponent',['技能实例 / Feature / BT 黑板'],['激活检查 → 行为树 tick'],'runtime','components/gameplay_ability_component.gd');
  joint+=box(650,220,'GameplayVitalAttributeComponent',['继承 GameplayAttributeComponent','属性实例 + Health / Mana 实例'],['数值计算 / 消耗 / 恢复'],'runtime','components/gameplay_vital_attribute_component.gd');
  joint+=box(1250,220,'GameplayStatusComponent',['活跃状态实例 / 策略 / Feature'],['堆叠 / 计时 / 事件 / 到期清理'],'runtime','components/gameplay_status_component.gd');
  joint+=box(50,660,'AbilityNodeBase',['选目标 / 冷却 / 消耗 / 发射节点'],['通过上下文和黑板调用下层系统'],'config','abilities/ability_nodes/ability_node_base.gd','abstract Resource');
  joint+=box(650,660,'GameplayEffect',['九种具体操作 / 子效果 / 过滤'],['准入 → 逻辑 → Cue → 子效果'],'effect','effects/gameplay_effect.gd','abstract Resource');
  joint+=box(1250,660,'GameplayStatusInstance',['apply / remove / 周期 / 事件效果','来源 ID 管理属性修改器'],['apply_effects(): 克隆并调用 Effect'],'runtime','status/gameplay_status_instance.gd','RefCounted');
  joint+=box(50,1100,'ProjectileBase / MagicFieldBase',['两个独立 Area3D 载具','payload = 状态定义 → 层数'],['命中 / Timer → 施加状态'],'runtime','','Area3D');
  joint+=box(650,1100,'HealthVital',['DamageInfo / current_value'],['同步受伤事件 → 扣值 → 死亡'],'runtime','attributes/vitals/health_vital.gd','Resource');
  joint+=box(1250,1100,'GameplayCueManager',['GameplayCue → 视觉组件'],['挂点定位 / execute / update / stop'],'service','singletons/gameplay_cue_manager.gd','autoload Node');
  joint+=edge('M290 470V660','dependency','实例驱动行为树',310,565);
  joint+=edge('M890 660V470','dependency','效果经组件读写属性 / Vital',910,565);
  joint+=edge('M1490 470V660','owned','活跃状态 0..*',1510,565);
  joint+=edge('M530 785H650','dependency','apply()',555,765);
  joint+=edge('M1250 785H1130','dependency','重复执行',1145,765);
  joint+=edge('M290 910V1100','dependency','生成载具',310,1000);
  joint+=edge('M890 910V1100','dependency','GE_ApplyDamage',910,1000);
  joint+=edge('M1490 910V1100','dependency','状态自身 Cue',1510,1000);
  joint+=edge('M50 1225H25V595H1490V660','dependency','payload 进入状态实例',530,578);
  joint+=edge('M1130 825H1190V1040H1340V1100','dependency','效果 Cue',1210,1023);
  joint+=step(50,1450,1680,235,'跨系统桥梁与宿主接口',[
    '宿主实体持有顶部三个组件；Vital 已继承属性容器。GameplayAbilitySystem 按 getter / get_component / 节点名查询。',
    'TagManager：状态添加标签；目标策略、过滤器和 Effect 查询标签。AbilityEventBus：同步通知状态 Feature 和宿主。',
    'DamageCalculator：Effect 使用伤害策略读取属性；HealthVital 在扣血前让事件状态修改同一个 DamageInfo。',
    'UI / 输入 / 预览位于入口；按钮与预览本身不会自动释放技能，宿主提供目标、动画、挂点及场景。',
    '清理链：状态 remove → Effect.remove → 按 source_id 撤销修改器 → 属性信号 → Vital 上限刷新。'
  ],'service');
  diagram('systems-integration.svg',1800,1740,'插件各系统的联合结构','实线与虚线展示实际持有 / 调用关系；该图展开组件、动作、效果、状态、数值与载具主链',joint);

  let run='';
  const laneX=[60,500,940,1380];
  const laneNames=['宿主 / 技能 / 行为树','Effect / 载具入口','状态 / 标签 / 事件','属性 / Vital / 表现'];
  laneNames.forEach((name,i)=>{
    run+=`<rect x="${laneX[i]}" y="145" width="400" height="1535" rx="12" fill="${i%2?'#f3f6fb':'#eaf0f7'}"/>`;
    run+=text(laneX[i]+200,185,name,'step','middle');
  });
  const s=(lane,y,title,lines,color='runtime')=>step(laneX[lane]+15,y,370,140,title,lines,color);
  run+=s(0,235,'1  输入与激活',['宿主提交目标 / 位置','Feature 检查；树开始运行']);
  run+=s(1,235,'2  行为树提交操作',['冷却 / 消耗 / 查询 / 效果','顺序由具体 execution_tree 定义'],'effect');
  run+=s(2,455,'3  配置持续增益',['GE_ApplyStatus → 状态实例','进入效果 / 策略 / 标签'],'config');
  run+=s(3,455,'4  进入效果改变属性',['防御修改器 +10，原值 5 → 15','按 source_id 记录；重算发信号']);
  run+=s(0,675,'5  后续攻击或命中',['技能直接应用伤害效果','或投射物 payload → 状态效果']);
  run+=s(1,675,'6  统一 Effect 准入',['过滤器与标签检查通过','读取属性；候选伤害 30−15=15'],'effect');
  run+=s(3,895,'7  HealthVital 受伤事件',['DamageInfo.final_damage = 15','同步 damage_received 广播']);
  run+=s(2,895,'8  可选事件减伤状态',['FeatureEventListener 匹配事件','修改同一伤害对象：15×0.5=7.5'],'config');
  run+=s(3,1115,'9  结算与表现',['读取变更后伤害：100 → 92.5','damage_applied；Effect 再播放 Cue']);
  run+=s(2,1335,'10  周期或持续时间到期',['周期 Feature 重新调用 Effect','到期则 remove_status()']);
  run+=s(3,1335,'11  清理与数值联动',['移除来源修改器：防御 15 → 5','属性信号刷新 Vital 上限；停 Cue']);
  run+=edge('M445 305H515');
  run+=edge('M700 375V415H1140V455','dependency','施加状态分支',780,403);
  run+=edge('M1325 525H1395');
  run+=edge('M445 745H515');
  run+=edge('M700 815V855H1580V895','dependency','计算后提交',805,843);
  run+=edge('M1395 965H1325','dependency');
  run+=edge('M1140 1035V1075H1580V1115','dependency','回读 final_damage',1150,1063);
  run+=edge('M1325 1405H1395');
  run+=edge('M955 1405H910V775H885','dependency','周期：重新进入 Effect',610,1378);
  run+=text(80,1570,'数值例子为可配置场景，非当前燃烧示例的默认效果；四条泳道按时间向下阅读。','note');
  run+=text(80,1608,'事件状态分支需要匹配实体作用域；当前全局总线未隔离目标，多个实体监听时可能串扰。','note');
  run+=text(80,1646,'图中“提交操作”概括共同阶段；主动模板的实际冷却、消耗、查询顺序见 README。','note');
  diagram('systems-runtime.svg',1840,1730,'各系统联合运行：增益、攻击、事件减伤与清理','条件分支以虚线连接；数值示例展示共享属性 / DamageInfo 和状态生命周期如何影响最终效果',run);
}
// #endregion
