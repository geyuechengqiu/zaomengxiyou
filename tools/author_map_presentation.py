"""Author panorama materials and wind tracks; preserve this on offline re-import."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def author_presentation(scene_path: Path, sprite: str, anchor: float):
    text = scene_path.read_text(encoding='utf8')
    if 'id="canopy_shader"' in text:
        return
    first_node = text.index('[node ')
    first_subresource = text.find('[sub_resource ')
    if first_subresource >= 0:
        first_node = min(first_node, first_subresource)
    text = text[:first_node] + f'''[ext_resource type="Shader" path="res://assets/maps/tree_canopy.gdshader" id="canopy_shader"]
[sub_resource type="ShaderMaterial" id="CanopyMaterial"]
resource_local_to_scene = true
shader = ExtResource("canopy_shader")
shader_parameter/trunk_anchor_y = {anchor}
[sub_resource type="Animation" id="TreeWind"]
resource_name = "tree_wind"
length = 6.0
loop_mode = 1
tracks/0/type = "value"
tracks/0/path = NodePath("MiddleBackground/{sprite}:material:shader_parameter/wind_phase")
tracks/0/interp = 1
tracks/0/keys = {{
"times": PackedFloat32Array(0, 6),
"transitions": PackedFloat32Array(1, 1),
"update": 0,
"values": [0.0, 6.283185307179586]
}}
[sub_resource type="AnimationLibrary" id="TreeWindLibrary"]
_data = {{ &"tree_wind": SubResource("TreeWind") }}
''' + text[first_node:]
    start = text.index('[node ')
    end = text.index('\n', start)
    text = text[:end] + '\ntexture_filter = 4\nanimated_player_paths = Array[NodePath]([NodePath("TreeWind")])' + text[end:]
    start = text.index(f'[node name="{sprite}" ')
    end = text.index('\n', start)
    text = text[:end] + '\nmaterial = SubResource("CanopyMaterial")' + text[end:]
    text += '''
[node name="TreeWind" type="AnimationPlayer" parent="."]
libraries = { &"": SubResource("TreeWindLibrary") }
autoplay = "tree_wind"
'''
    scene_path.write_text(text, encoding='utf8')


if __name__ == '__main__':
    author_presentation(ROOT/'data/levels/huaguoshan/visual.tscn', 'Forest', 490.0)
    author_presentation(ROOT/'data/levels/shuiliandong/visual.tscn', 'Cave', 420.0)
