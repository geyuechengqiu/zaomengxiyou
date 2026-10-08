// #region 离线生成可编辑测试场景：运行时不调用此工具
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const write = (file, lines) => fs.writeFileSync(path.join(root, file), lines.join('\n') + '\n');
const ext = (type, file, id) => `[ext_resource type="${type}" path="res://${file}" id="${id}"]`;
const node = (name, type, parent, props = []) => [`[node name="${name}" type="${type}"${parent == null ? '' : ` parent="${parent}"`}]`, ...props];
const instance = (name, parent, id, props = []) => [`[node name="${name}" parent="${parent}" instance=ExtResource("${id}")]`, ...props];
// #endregion
// #region 全部预置的重映射菜单
const menu = ['[gd_scene format=3]', ext('Script','addons/battle_foundation/input/battle_operation_menu.gd','script'),
  '[sub_resource type="StyleBoxFlat" id="panel"]','bg_color = Color(0.09, 0.16, 0.23, 1)',
  'content_margin_left = 20.0','content_margin_right = 20.0','content_margin_top = 16.0','content_margin_bottom = 16.0',
  ...node('OperationMenu','Control',null,['process_mode = 3','visible = false','layout_mode = 3','anchors_preset = 15','anchor_right = 1.0','anchor_bottom = 1.0','grow_horizontal = 2','grow_vertical = 2','focus_mode = 2','script = ExtResource("script")']),
  ...node('Backdrop','ColorRect','.', ['layout_mode = 1','anchors_preset = 15','anchor_right = 1.0','anchor_bottom = 1.0','mouse_filter = 2','color = Color(0.02, 0.04, 0.07, 0.95)']),
  ...node('Margin','MarginContainer','.', ['layout_mode = 1','anchors_preset = 15','anchor_right = 1.0','anchor_bottom = 1.0','theme_override_constants/margin_left = 120','theme_override_constants/margin_right = 120','theme_override_constants/margin_top = 24','theme_override_constants/margin_bottom = 24']),
  ...node('Panel','PanelContainer','Margin',['layout_mode = 2','theme_override_styles/panel = SubResource("panel")']),
  ...node('Column','VBoxContainer','Margin/Panel',['layout_mode = 2','theme_override_constants/separation = 8']),
  ...node('Title','Label','Margin/Panel/Column',['layout_mode = 2','text = "操作设置 · 按键重映射"','theme_override_font_sizes/font_size = 24']),
  ...node('Status','Label','Margin/Panel/Column',['layout_mode = 2','custom_minimum_size = Vector2(0, 40)','autowrap_mode = 3','theme_override_font_sizes/font_size = 16','theme_override_colors/font_color = Color(1, 0.83, 0.55, 1)']),
  ...node('Scroll','ScrollContainer','Margin/Panel/Column',['layout_mode = 2','size_flags_vertical = 3']),
  ...node('Rows','VBoxContainer','Margin/Panel/Column/Scroll',['layout_mode = 2','size_flags_horizontal = 3','theme_override_constants/separation = 5'])];
const labels = {move_left:'左移',move_right:'右移',move_up:'上方向',move_down:'下方向',run:'奔跑',jump:'跳跃',attack:'普攻',skill_1:'技能槽 1',skill_2:'技能槽 2',skill_3:'技能槽 3',skill_4:'技能槽 4',skill_5:'技能槽 5',magic_weapon:'法宝',wushuang:'无双',wing_skill:'翅膀技能',ultimate:'奥义',item_1:'道具 1',item_2:'道具 2',pet_toggle:'宠物',mount_toggle:'坐骑'};
for(const [intent,label] of Object.entries(labels)) {
  const parent='Margin/Panel/Column/Scroll/Rows';
  menu.push(...node(intent,'HBoxContainer',parent,['layout_mode = 2',`metadata/intent = &"${intent}"`]),
    ...node('Name','Label',`${parent}/${intent}`,['layout_mode = 2','size_flags_horizontal = 3',`text = "${label}"`]),
    ...node('Binding','Button',`${parent}/${intent}`,['layout_mode = 2','custom_minimum_size = Vector2(220, 30)','text = "未绑定"']));
}
menu.push(...node('Buttons','HBoxContainer','Margin/Panel/Column',['layout_mode = 2','theme_override_constants/separation = 12']),
  ...node('Reset','Button','Margin/Panel/Column/Buttons',['layout_mode = 2','text = "恢复默认按键"']),
  ...node('Close','Button','Margin/Panel/Column/Buttons',['layout_mode = 2','text = "返回游戏 [Esc]"']));
write('addons/battle_foundation/input/battle_operation_menu.tscn',menu);
// #endregion
// #region 940×590、静态世界、角色与全部运行组件
const scene = ['[gd_scene format=3]',ext('Script','examples/single_attack_demo.gd','script'),
  ext('Script','addons/battle_foundation/runtime/battle_session.gd','session'),
  ext('PackedScene','data/battle2d/single_attack/sunwukong_2d.tscn','wukong'),
  ext('PackedScene','data/battle2d/dummy/wooden_dummy.tscn','dummy'),
  ext('Script','addons/battle_foundation/runtime/battle_attribute_component.gd','attributes'),
  ext('Script','addons/gameplay_abiltiy_system/scripts/components/gameplay_ability_component.gd','abilities'),
  ext('Script','addons/gameplay_abiltiy_system/scripts/components/gameplay_status_component.gd','statuses'),
  ext('Script','addons/battle_foundation/input/battle_player_operations.gd','operations'),
  ext('Script','addons/godot_core_system-0.0.4/source/operation_system/operation_controller.gd','controller'),
  ext('Resource','data/controls/player_operations.tres','controls'),
  ext('PackedScene','addons/battle_foundation/input/battle_operation_menu.tscn','menu'),
  '[sub_resource type="RectangleShape2D" id="ground"]','size = Vector2(2800, 400)',
  '[sub_resource type="RectangleShape2D" id="wall"]','size = Vector2(30, 400)',
  '[sub_resource type="RectangleShape2D" id="platform"]','size = Vector2(260, 20)',
  '[sub_resource type="StyleBoxFlat" id="panel"]','bg_color = Color(0.035, 0.075, 0.10, 0.94)',
  'content_margin_left = 14.0','content_margin_right = 14.0','content_margin_top = 10.0','content_margin_bottom = 10.0',
  ...node('SingleAttackDemo','Node2D',null,['process_mode = 3','script = ExtResource("script")']),
  ...node('Background','CanvasLayer','.', ['layer = -5']),
  ...node('Sky','ColorRect','Background',['anchors_preset = 15','anchor_right = 1.0','anchor_bottom = 1.0','mouse_filter = 2','color = Color(0.045, 0.09, 0.14, 1)']),
  ...node('Camera2D','Camera2D','.', ['position = Vector2(400, 450)','zoom = Vector2(0.5, 0.5)']),
  ...node('BattleSession','Node3D','.', ['script = ExtResource("session")','scene_manifest_path = "res://data/battle2d/single_attack/manifest.json"','scene_seed = 6001']),
  ...node('Terrain','Node2D','BattleSession')];
for(let i=0;i<6;i++) {
  const x=-700+i*420;
  scene.push(...node(`Mountain${i+1}`,'Polygon2D','BattleSession/Terrain',[`polygon = PackedVector2Array(${x}, 650, ${x+230}, 40, ${x+530}, 650)`,'color = Color(0.075, 0.16, 0.21, 1)']));
}
scene.push(...node('Ground','StaticBody2D','BattleSession/Terrain',['position = Vector2(400, 850)','collision_layer = 1','collision_mask = 2']),
  ...node('CollisionShape2D','CollisionShape2D','BattleSession/Terrain/Ground',['shape = SubResource("ground")']),
  ...node('Surface','Polygon2D','BattleSession/Terrain/Ground',['polygon = PackedVector2Array(-1400,-200,1400,-200,1400,200,-1400,200)','color = Color(0.14,0.27,0.28,1)']),
  ...node('Edge','Polygon2D','BattleSession/Terrain/Ground',['polygon = PackedVector2Array(-1400,-200,1400,-200,1400,-190,-1400,-190)','color = Color(0.40,0.73,0.62,1)']));
for(const [name,x] of [['LeftWall',-420],['RightWall',1300]]) {
  scene.push(...node(name,'StaticBody2D','BattleSession/Terrain',[`position = Vector2(${x},450)`,'collision_layer = 1','collision_mask = 2']),
    ...node('CollisionShape2D','CollisionShape2D',`BattleSession/Terrain/${name}`,['shape = SubResource("wall")']),
    ...node('Visual','Polygon2D',`BattleSession/Terrain/${name}`,['polygon = PackedVector2Array(-15,-200,15,-200,15,200,-15,200)','color = Color(0.25,0.36,0.35,1)']));
}
scene.push(...node('Platform','StaticBody2D','BattleSession/Terrain',['position = Vector2(950, 540)','collision_layer = 1','collision_mask = 2']),
  ...node('CollisionShape2D','CollisionShape2D','BattleSession/Terrain/Platform',['shape = SubResource("platform")','one_way_collision = true']),
  ...node('Visual','Polygon2D','BattleSession/Terrain/Platform',['polygon = PackedVector2Array(-130,-10,130,-10,130,10,-130,10)','color = Color(0.62,0.52,0.30,1)']),
  ...node('Actors','Node2D','BattleSession'));
for(const [name,type,id,x,category] of [['SunWukong','wukong','孙悟空',400,'characters'],['LeftDummy','dummy','木桩',110,'monsters'],['RightDummy','dummy','木桩',690,'monsters']]) {
  const parent=`BattleSession/Actors/${name}`;
  scene.push(...instance(name,'BattleSession/Actors',type,[`position = Vector2(${x},650)`,`scene_definition_id = &"${id}"`,`scene_category = "${category}"`]),
    ...node('GameplayVitalAttributeComponent','Node',parent,['script = ExtResource("attributes")','externally_driven = true']),
    ...node('GameplayAbilityComponent','Node',parent,['script = ExtResource("abilities")','externally_driven = true']),
    ...node('GameplayStatusComponent','Node',parent,['script = ExtResource("statuses")','externally_driven = true','filter_events_by_owner = true']));
  if(type==='wukong') scene.push(...node('PlayerOperations','Node',parent,['script = ExtResource("operations")','operation_profile = ExtResource("controls")','controller_path = NodePath("OperationController")']),
    ...node('OperationController','Node',`${parent}/PlayerOperations`,['script = ExtResource("controller")','profile = ExtResource("controls")','externally_driven = true']));
}
scene.push(...node('HUD','CanvasLayer','.', ['layer = 10']),
  ...node('Panel','PanelContainer','HUD',['offset_left = 16.0','offset_top = 12.0','offset_right = 924.0','offset_bottom = 158.0','theme_override_styles/panel = SubResource("panel")']),
  ...node('Column','VBoxContainer','HUD/Panel',['layout_mode = 2','theme_override_constants/separation = 6']),
  ...node('Title','Label','HUD/Panel/Column',['layout_mode = 2','text = "孙悟空 · 单段普攻测试"','theme_override_font_sizes/font_size = 23']),
  ...node('Info','Label','HUD/Panel/Column',['layout_mode = 2','theme_override_font_sizes/font_size = 15']),
  ...node('Message','Label','HUD/Panel/Column',['layout_mode = 2','theme_override_colors/font_color = Color(1,0.83,0.55,1)','theme_override_font_sizes/font_size = 15']),
  ...node('Buttons','HBoxContainer','HUD/Panel/Column',['layout_mode = 2','theme_override_constants/separation = 8']));
for(const [name,label] of [['Attack','攻击 [J]'],['Flip','翻转'],['Near','靠近'],['Far','远离 / 打空'],['Power','攻击 26 / 200'],['Reset','重置场景'],['Pause','暂停 / 恢复']]) {
  scene.push(...node(name,'Button','HUD/Panel/Column/Buttons',['layout_mode = 2','focus_mode = 0',`text = "${label}"`,'theme_override_font_sizes/font_size = 15']));
}
scene.push(...node('Help','Label','HUD',['offset_left = 24.0','offset_top = 506.0','offset_right = 916.0','offset_bottom = 566.0','mouse_filter = 2','theme_override_font_sizes/font_size = 17','theme_override_colors/font_color = Color(0.78,0.86,0.82,1)',
  'text = "A / D 移动 · K 二段跳 · J 单段普攻 · Esc 菜单 / 改键\n黄色：技能攻击范围；蓝色：编辑器受击框；原版受击特效为 30 FPS。"']),
  ...node('MenuLayer','CanvasLayer','.', ['layer = 30']),
  ...instance('OperationMenu','MenuLayer','menu'));
write('examples/single_attack_demo.tscn',scene);
console.log('Built scene-authored combat arena and menu for the original 940×590 viewport.');
// #endregion
