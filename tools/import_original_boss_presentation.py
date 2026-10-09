"""Read original mission HUD/appearance, keeping gameplay and authored map intact."""
from pathlib import Path
import hashlib, json, re, shutil, subprocess, sys
sys.dont_write_bytecode = True

#region Read-only export and reproducible original assets
PROJECT = Path(__file__).resolve().parents[1]
ORIGINAL = Path(sys.argv[1]).resolve()
SOURCE = 'games/zmhj-g5/cache/assets/ui/mission_20260406_1.swf'
OUTPUT = PROJECT / '.cleanup-backup/entrance-export'
FONT_SOURCE = 'games/zmhj-g5/cache/assets/ui/font_20260629_1.swf'
result = subprocess.run(['java','-Djava.awt.headless=true','-Dfile.encoding=UTF-8','-cp',str(ORIGINAL/'out/swfutil/ffdec_lib_20.1.0/*'),str(PROJECT/'tools/ExportOriginalEntranceUI.java'),str(ORIGINAL/SOURCE),str(OUTPUT),str(ORIGINAL/FONT_SOURCE)],check=True,capture_output=True,encoding='utf8')
OUTPUT.mkdir(parents=True,exist_ok=True)
(OUTPUT/'layout.txt').write_text(result.stdout,encoding='utf8')
print(result.stdout.splitlines()[0:3])
ui = PROJECT/'assets/ui/boss'
for font, name in [(55,'count'),(1333,'name')]: shutil.copyfile(OUTPUT/f'font-{font}.ttf',ui/f'{name}.ttf')
if not (OUTPUT/'boss-name.ttf').is_file(): raise RuntimeError('Original font library does not contain the Boss name')
shutil.copyfile(OUTPUT/'boss-name.ttf',ui/'name.ttf')
shutil.copyfile(OUTPUT/'protect-shapes/1326.png',ui/'protect_fill.png')
shutil.copyfile(OUTPUT/'protect-shapes/1330.png',ui/'protect_border.png')
resists = ['lightResist','darkResist','waterResist','fireResist','woodResist','soilResist','windResist','rayResist']
icons = ui/'resist'; icons.mkdir(parents=True,exist_ok=True)
for key in resists:
    for sign in ['Add','Remove']:
        shutil.copyfile(ORIGINAL/f'games/zmhj-g5/cache/assets/icon/resist/{key}{sign}.png',icons/f'{key}{sign}.png')
assets = PROJECT/'assets/effects/monster_appearance'; assets.mkdir(parents=True,exist_ok=True)
shutil.copyfile(OUTPUT/'appear1-atlas.png',assets/'appear1.png')
sources = [SOURCE,'out/zmhj-equip-skill-diag/prefabs/Monster1.as','out/zmhj-equip-skill-diag/com/wdcgame/engine/managers/ResourceManager.as','out/zmhj-equip-skill-diag/com/wdcgame/engine/animation/MovieClipAdvance.as','out/zmhj-equip-skill-diag/viewers/component/BossBleed.as','out/zmhj-equip-skill-diag/viewers/container/layers/BattleTopLayer.as','out/zmhj-equip-skill-diag/models/constants/ResistType.as']
manifest = {'sources':[{'path':p,'sha256':hashlib.sha256((ORIGINAL/p).read_bytes()).hexdigest()} for p in sources], 'boss_anchor':[470,36], 'frame_registration':[-129.2,13.8], 'name_registration':[-97,2], 'count_registration':[21.95,23.2], 'protect_registration':[-97.35,42.8], 'protect_container':[-97.35,47.3], 'resistance_order':resists, 'appearance':{'symbol':'appear1','frames':25,'fps':30,'duration':25/30,'registration':[-92.05,-140],'frame_size':[199,198],'atlas_cell':[203,202],'columns':5,'world_scale':2,'loop':False,'start_actor_after_completion':True}}
manifest['sources'].append({'path':FONT_SOURCE,'sha256':hashlib.sha256((ORIGINAL/FONT_SOURCE).read_bytes()).hexdigest()})
for key in resists:
    for sign in ['Add','Remove']:
        relative=f'games/zmhj-g5/cache/assets/icon/resist/{key}{sign}.png'
        manifest['sources'].append({'path':relative,'sha256':hashlib.sha256((ORIGINAL/relative).read_bytes()).hexdigest()})
(ui/'original_presentation.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
sys.path.insert(0,str(ORIGINAL))
from backends.zmhj_config import load_config_archive
config = load_config_archive(ORIGINAL/'games/zmhj-g5')
for path in (PROJECT/'data/monsters').glob('*/definition.tres'):
    text = path.read_text(encoding='utf8'); match=re.search(r'metadata/original_monster_id = (\d+)',text)
    if match:
        value=int(config['Monster'][match[1]].get('showAppear',0))
        text=re.sub(r'\nmetadata/original_show_appear = \d+','',text).rstrip()+f'\nmetadata/original_show_appear = {value}\n'
        if match[1]=='10601': text=re.sub(r'display_name = ".*?"','display_name = "玉石琵琶精"',text)
        path.write_text(text,encoding='utf8')
boss=PROJECT/'data/monsters/jushi_lingjun/boss.tres'
boss.write_text(boss.read_text(encoding='utf8').replace('display_name = "巨石灵君"','display_name = "玉石琵琶精"'),encoding='utf8')
#endregion

#region Editor-authored 25-frame entrance, fixed original registration
lines=['[gd_scene format=3]','[ext_resource type="Script" path="res://addons/battle_foundation/presentation/battle_monster_appearance_2d.gd" id="script"]','[ext_resource type="Texture2D" path="res://assets/effects/monster_appearance/appear1.png" id="atlas"]']
for index in range(25):
    lines += [f'[sub_resource type="AtlasTexture" id="Frame{index}"]','atlas = ExtResource("atlas")',f'region = Rect2({index%5*203+2}, {index//5*202+2}, 199, 198)','filter_clip = true']
lines += ['[sub_resource type="Animation" id="Appear"]','resource_name = "appear1"','length = 0.833333333','tracks/0/type = "value"','tracks/0/path = NodePath("Sprite2D:texture")','tracks/0/interp = 0', 'tracks/0/keys = {"times": PackedFloat32Array('+','.join(f'{i/30:.9f}' for i in range(25))+'), "transitions": PackedFloat32Array('+','.join('1' for i in range(25))+'), "update": 1, "values": ['+','.join(f'SubResource("Frame{i}")' for i in range(25))+']}', '[sub_resource type="AnimationLibrary" id="Library"]','_data = {&"appear1": SubResource("Appear")}','[node name="MonsterAppearance" type="Node2D"]','visible = false','z_index = 20','scale = Vector2(2,2)','script = ExtResource("script")','[node name="Sprite2D" type="Sprite2D" parent="."]','position = Vector2(-92.05,-140)','centered = false','texture = SubResource("Frame0")','[node name="AnimationPlayer" type="AnimationPlayer" parent="."]','callback_mode_process = 2','libraries/ = SubResource("Library")']
(PROJECT/'data/effects/monster_appearance.tscn').write_text('\n'.join(lines)+'\n',encoding='utf8')
print('Imported original centered Boss HUD fonts/icons and 25-frame appear1; actor showAppear values preserved')
#endregion

#region Native HUD layout at original MovieClip registration (not cropped PNG center)
path=PROJECT/'addons/battle_foundation/boss/battle_boss_feedback_2d.tscn'
text=path.read_text(encoding='utf8')
text=re.sub(r'^\[ext_resource .* id="(?:font_name|font_count|protect_border|resist_\w+)"\]\n','',text,flags=re.M)
text=text.replace('path="res://assets/ui/boss/protect.png"','path="res://assets/ui/boss/protect_fill.png"')
resources='[ext_resource type="FontFile" path="res://assets/ui/boss/name.ttf" id="font_name"]\n[ext_resource type="FontFile" path="res://assets/ui/boss/count.ttf" id="font_count"]\n'
for key in resists:
    for sign in ['Add','Remove']: resources+=f'[ext_resource type="Texture2D" path="res://assets/ui/boss/resist/{key}{sign}.png" id="resist_{key}{sign}"]\n'
resources+='[ext_resource type="Texture2D" path="res://assets/ui/boss/protect_border.png" id="protect_border"]\n'
text=text.replace('[node name="BossFeedback"',resources+'[node name="BossFeedback"',1)
text=re.sub(r'^resistance_(?:add|remove)_textures = .*\n','',text,flags=re.M)
for sign,prop in [('Add','add'),('Remove','remove')]:
    text=text.replace('script = ExtResource("script")', 'script = ExtResource("script")\nresistance_'+prop+'_textures = Array[Texture2D](['+', '.join(f'ExtResource("resist_{key}{sign}")' for key in resists)+'])',1)
begin=text.index('[node name="BossBar"');end=text.index('[node name="Announcement"')
hud='''[node name="BossBar" type="Control" parent="HUD"]
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_top = 36.0
offset_bottom = 96.0
grow_horizontal = 2
mouse_filter = 2
[node name="Frame" type="TextureRect" parent="HUD/BossBar"]
offset_left = -129.2
offset_top = 13.8
offset_right = 194.8
offset_bottom = 47.8
mouse_filter = 2
texture = ExtResource("frame")
[node name="NextFill" type="TextureRect" parent="HUD/BossBar"]
offset_left = -99.0
offset_top = 27.0
offset_right = 174.0
offset_bottom = 40.0
mouse_filter = 2
texture = ExtResource("bar2")
[node name="Fill" type="TextureProgressBar" parent="HUD/BossBar"]
offset_left = -99.0
offset_top = 27.0
offset_right = 174.0
offset_bottom = 40.0
mouse_filter = 2
max_value = 1.0
step = 0.001
value = 1.0
texture_progress = ExtResource("bar1")
[node name="Name" type="Label" parent="HUD/BossBar"]
offset_left = -97.0
offset_top = 2.0
offset_right = 166.0
offset_bottom = 26.2
mouse_filter = 2
theme_override_fonts/font = ExtResource("font_name")
theme_override_font_sizes/font_size = 18
theme_override_colors/font_outline_color = Color(0,0,0,1)
theme_override_constants/outline_size = 2
text = "玉石琵琶精"
[node name="Count" type="Label" parent="HUD/BossBar"]
offset_left = 18.45
offset_top = 21.2
offset_right = 50.45
offset_bottom = 43.95
mouse_filter = 2
theme_override_fonts/font = ExtResource("font_count")
theme_override_font_sizes/font_size = 16
theme_override_colors/font_outline_color = Color(0,0,0,1)
theme_override_constants/outline_size = 2
text = "X3"
horizontal_alignment = 1
[node name="Health" type="Label" parent="HUD/BossBar"]
visible = false
offset_left = -99.0
offset_top = 58.0
offset_right = 174.0
offset_bottom = 76.0
mouse_filter = 2
theme_override_font_sizes/font_size = 13
text = "1167 / 1167"
horizontal_alignment = 1
[node name="Protection" type="TextureProgressBar" parent="HUD/BossBar"]
offset_left = -97.35
offset_top = 42.8
offset_right = 165.65
offset_bottom = 51.8
mouse_filter = 2
max_value = 1.0
step = 0.001
texture_progress = ExtResource("protect")
texture_over = ExtResource("protect_border")
[node name="ProtectionValue" type="Label" parent="HUD/BossBar"]
visible = false
offset_left = -99.0
offset_top = 76.0
offset_right = 174.0
offset_bottom = 94.0
mouse_filter = 2
theme_override_font_sizes/font_size = 13
text = "保护 0 / 25000"
[node name="Resistances" type="Control" parent="HUD/BossBar"]
mouse_filter = 2
'''
for index in range(8): hud+=f'[node name="Slot{index+1}" type="TextureRect" parent="HUD/BossBar/Resistances"]\nvisible = false\nmouse_filter = 1\nexpand_mode = 1\n'
path.write_text(text[:begin]+hud+text[end:],encoding='utf8')
#endregion
