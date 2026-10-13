"""Author exact preload SWF parts; keep the subtitle outside an AtlasTexture region.
Export #14,#16,#19,#21,#30 with ExportOriginalBattleUI.java first.
Fonts/percent/progress are real Godot nodes. The checked-in clean background
supplies only the publisher area through publisher_cleanup.gdshader; keep it
when re-exporting the original SWF parts.
"""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
assets = root / 'assets/ui/original/loading'
assets.mkdir(parents=True, exist_ok=True)
for number, name in [(14, 'background'), (16, 'track'), (19, 'fill'), (21, 'cursor'), (30, 'logo')]:
    shutil.copyfile(root / f'.cleanup-backup/loading-parts/id-{number}/{number}.png', assets / f'{name}.png')

text = '''[gd_scene format=3]
[ext_resource type="Script" path="res://game/loading/StageLoadingScreen.cs" id="script"]
[ext_resource type="Texture2D" path="res://assets/ui/original/loading/background.png" id="background"]
[ext_resource type="Texture2D" path="res://assets/ui/original/loading/background_clean.png" id="clean_background"]
[ext_resource type="Shader" path="res://assets/ui/original/loading/publisher_cleanup.gdshader" id="publisher_cleanup"]
[ext_resource type="Texture2D" path="res://assets/ui/original/loading/track.png" id="track"]
[ext_resource type="Texture2D" path="res://assets/ui/original/loading/fill.png" id="fill"]
[ext_resource type="Texture2D" path="res://assets/ui/original/loading/cursor.png" id="cursor"]
[ext_resource type="Texture2D" path="res://assets/ui/original/loading/logo.png" id="logo"]
[ext_resource type="FontFile" path="res://assets/ui/original/ui_font.ttf" id="font"]
[sub_resource type="World2D" id="warmup_world"]
[sub_resource type="ShaderMaterial" id="clean_background_material"]
shader = ExtResource("publisher_cleanup")
shader_parameter/clean_background = ExtResource("clean_background")
[sub_resource type="AtlasTexture" id="title"]
atlas = ExtResource("logo")
region = Rect2(0, 0, 301, 146)
[sub_resource type="StyleBoxFlat" id="button"]
bg_color = Color(1, 0.77, 0.3, 1)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.65, 0.38, 0.12, 1)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_left = 8
corner_radius_bottom_right = 8
[node name="StageLoadingScreen" type="CanvasLayer"]
layer = 100
process_mode = 3
script = ExtResource("script")
[node name="Overlay" type="Control" parent="."]
visible = false
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 0
metadata/ui_modal = true
[node name="Background" type="TextureRect" parent="Overlay"]
material = SubResource("clean_background_material")
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
texture = ExtResource("background")
expand_mode = 1
mouse_filter = 2
[node name="Title" type="TextureRect" parent="Overlay"]
offset_left = 316.8
offset_top = 77.6
offset_right = 617.8
offset_bottom = 223.6
texture = SubResource("title")
mouse_filter = 2
[node name="Track" type="TextureRect" parent="Overlay"]
offset_left = 113.9
offset_top = 306.15
offset_right = 834.9
offset_bottom = 361.15
texture = ExtResource("track")
mouse_filter = 2
[node name="Fill" type="TextureProgressBar" parent="Overlay"]
offset_left = 203.9
offset_top = 322.15
offset_right = 750.9
offset_bottom = 339.15
texture_progress = ExtResource("fill")
mouse_filter = 2
[node name="Cursor" type="TextureRect" parent="Overlay"]
offset_left = 155.9
offset_top = 314.15
offset_right = 220.9
offset_bottom = 347.15
texture = ExtResource("cursor")
mouse_filter = 2
metadata/progress_anchor = Vector2(48, 16.5)
[node name="Percent" type="Label" parent="Overlay"]
offset_left = 163.9
offset_top = 275.0
offset_right = 243.9
offset_bottom = 301.0
theme_override_fonts/font = ExtResource("font")
theme_override_font_sizes/font_size = 16
theme_override_colors/font_color = Color(0.37, 0.12, 0.02, 1)
text = "0%"
horizontal_alignment = 1
mouse_filter = 2
[node name="Description" type="Label" parent="Overlay"]
offset_left = 110.0
offset_top = 360.0
offset_right = 830.0
offset_bottom = 416.0
theme_override_fonts/font = ExtResource("font")
theme_override_font_sizes/font_size = 16
theme_override_colors/font_color = Color(0.37, 0.12, 0.02, 1)
text = "准备关卡加载…"
horizontal_alignment = 1
vertical_alignment = 1
autowrap_mode = 2
mouse_filter = 2
[node name="Dismiss" type="Button" parent="Overlay"]
visible = false
offset_left = 390.0
offset_top = 439.0
offset_right = 550.0
offset_bottom = 479.0
theme_override_fonts/font = ExtResource("font")
theme_override_font_sizes/font_size = 20
theme_override_colors/font_color = Color(0.37, 0.12, 0.02, 1)
theme_override_styles/normal = SubResource("button")
theme_override_styles/hover = SubResource("button")
theme_override_styles/pressed = SubResource("button")
text = "返回大地图"
[node name="WarmupViewport" type="SubViewport" parent="."]
size = Vector2i(640, 384)
world_2d = SubResource("warmup_world")
transparent_bg = true
render_target_update_mode = 0
[node name="Visuals" type="Node2D" parent="WarmupViewport"]
'''
(root / 'game/loading/stage_loading_screen.tscn').write_text(text, encoding='utf-8')
