"""Author editable original battle/backpack nodes; no startup component creation."""
from pathlib import Path
import hashlib, json, struct, sys, xml.etree.ElementTree as ET, zlib
PROJECT=Path(__file__).resolve().parents[1]
ORIGINAL=Path(sys.argv[1]).resolve()

#region Godot scene helpers, native original coordinates
def write(path,text):
    target=PROJECT/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(text,'utf8')

class Scene:
    def __init__(self):self.resources=[];self.nodes=[];self.index=0;self.button_styles=[]
    def resource(self,path,kind='Texture2D'):
        self.index+=1;id=f'R{self.index}';self.resources.append(f'[ext_resource type="{kind}" path="{path}" id="{id}"]\n');return f'ExtResource("{id}")'
    def node(self,name,kind,parent='.',properties=''):
        self.nodes.append(f'[node name="{name}" type="{kind}"'+(f' parent="{parent}"' if parent else '')+']\n'+properties+'\n')
    def rect(self,name,parent,x,y,w,h,texture,extra=''):
        ref=self.resource('res://assets/ui/original/'+texture)
        self.node(name,'TextureRect',parent,f'offset_left = {x}\noffset_top = {y}\noffset_right = {x+w}\noffset_bottom = {y+h}\nmouse_filter = 2\nexpand_mode = 1\ntexture = {ref}\n'+extra)
    def patch(self,name,parent,x,y,w,h,texture):
        ref=self.resource('res://assets/ui/original/'+texture)
        tw,th=struct.unpack('>II',(PROJECT/'assets/ui/original'/texture).read_bytes()[16:24])
        # 原Scale9Image默认中心矩形为图片宽/高的中间三分之一。
        left,top=tw//3,th//3
        self.node(name,'NinePatchRect',parent,f'offset_left = {x}\noffset_top = {y}\noffset_right = {x+w}\noffset_bottom = {y+h}\nmouse_filter = 2\ntexture = {ref}\npatch_margin_left = {left}\npatch_margin_top = {top}\npatch_margin_right = {tw-2*left}\npatch_margin_bottom = {th-2*top}\n')
    def label(self,name,parent,x,y,w,h,text='',size=14,color='Color(1,1,1,1)',align=0):
        self.node(name,'Label',parent,f'offset_left = {x}\noffset_top = {y}\noffset_right = {x+w}\noffset_bottom = {y+h}\nmouse_filter = 2\ntheme_override_fonts/font = {FONT}\ntheme_override_font_sizes/font_size = {size}\ntheme_override_colors/font_color = {color}\ntext = {json.dumps(text,ensure_ascii=False)}\nhorizontal_alignment = {align}\nvertical_alignment = 1')
    def button(self,name,parent,x,y,w,h,text):
        if not self.button_styles:
            for i in range(3):
                ref=self.resource(f'res://assets/ui/original/button_{i}.png');self.button_styles.append(f'Button{i}')
                self.resources.append(f'[sub_resource type="StyleBoxTexture" id="Button{i}"]\ntexture = {ref}\ntexture_margin_left = 7.0\ntexture_margin_right = 7.0\ntexture_margin_top = 7.0\ntexture_margin_bottom = 7.0\n')
        self.node(name,'Button',parent,f'offset_left = {x}\noffset_top = {y}\noffset_right = {x+w}\noffset_bottom = {y+h}\nfocus_mode = 0\ntheme_override_fonts/font = {FONT}\ntheme_override_font_sizes/font_size = 14\ntheme_override_styles/normal = SubResource("Button0")\ntheme_override_styles/hover = SubResource("Button1")\ntheme_override_styles/pressed = SubResource("Button2")\ntext = {json.dumps(text,ensure_ascii=False)}')
    def save(self,path):write(path,'[gd_scene format=3]\n'+''.join(r for r in self.resources if r.startswith('[ext_resource'))+''.join(r for r in self.resources if not r.startswith('[ext_resource'))+''.join(self.nodes))

def slot(s,name,parent,x,y,label=''):
    s.node(name,'Control',parent,f'offset_left = {x}\noffset_top = {y}\noffset_right = {x+60}\noffset_bottom = {y+60}\nmouse_filter = 0')
    path=parent+'/'+name if parent!='.' else name
    s.rect('Background',path,0,0,60,60,'slot_0.png')
    s.node('Icon','TextureRect',path,'offset_left = 5.0\noffset_top = 5.0\noffset_right = 55.0\noffset_bottom = 55.0\nmouse_filter = 2\nexpand_mode = 1')
    s.label('Count',path,1,39,54,19,size=14,align=2)
    s.rect('Lock',path,10,10,40,40,'lock.png','visible = false')
    if label:s.label('Part',path,0,61,60,19,label,size=12,color='Color(0.42,0.16,0.02,1)',align=1)
#endregion

#region Original 5x5 bag, four tabs, same-window popup controls and confirmation
s=Scene();FONT=s.resource('res://addons/simple_inventory/assets/fonts/SourceHanSansSC-Regular-2.otf','FontFile')
script=s.resource('res://addons/battle_foundation/ui/original_inventory_view.gd','Script')
slot_refs=[s.resource(f'res://assets/ui/original/slot_{i}.png') for i in range(11)]
tab_refs=[s.resource(f'res://assets/ui/original/tab_{i}_{j}.png') for i in range(4) for j in range(3)]
s.node('Inventory','Control','',f'visible = false\noffset_right = 940.0\noffset_bottom = 590.0\nmouse_filter = 0\nscript = {script}\nslot_textures = Array[Texture2D]([{", ".join(slot_refs)}])\ntab_textures = Array[Texture2D]([{", ".join(tab_refs)}])')
s.rect('Window','.',0,0,940,590,'bag_window.png')
s.rect('BodyPanel','.',-72.05,77.6,552,451,'body_panel.png')
s.rect('BagPanel','.',475.6,109.6,334,412,'bag_panel.png')
portrait=s.resource('res://data/animation/sunwukong_visual.tscn','PackedScene')
s.nodes.append(f'[node name="RolePortrait" parent="." instance={portrait}]\nposition = Vector2(270,280)\nscale = Vector2(0.7,0.7)\n')
s.label('Name','.',189,84,133,25,'孙悟空',size=18,color='Color(0.42,0.16,0.02,1)')
s.label('Level','.',129,299,57,28,'1',size=20,color='Color(1,1,0.2,1)',align=1)
s.nodes[-1]+='\nz_index = 1\ntheme_override_colors/font_outline_color = Color(0.37,0.12,0.02,1)\ntheme_override_constants/outline_size = 2\n'
s.label('Experience','.',247,304,163,20,'0/110',size=13,color='Color(0.42,0.16,0.02,1)',align=1)
s.button('Wardrobe','.',407,122,73,24,'衣橱')
s.button('ResistanceButton','.',416,501,44,22,'抗性')
s.node('Attributes','Control','.')
for i in range(12):
    s.label(f'Value{i}','Attributes',188+(i%2)*168.8,335+(i//2)*27,106,22,size=14,color='Color(0.42,0.16,0.02,1)',align=2)
s.node('Equipment','Control','.')
for i,(x,y,name) in enumerate([(129,165,'翅膀'),(345,165,'武器'),(409,165,'头盔'),(129,236,'法宝'),(345,236,'防具'),(409,236,'饰品')]):slot(s,f'Part{i}','Equipment',x,y,name)
s.node('Tabs','Control','.')
for i,x in enumerate([479.6,560.9,642.2,723.6]):
    s.node(f'Tab{i}','TextureButton','Tabs',f'offset_left = {x}\noffset_top = 77.6\noffset_right = {x+80}\noffset_bottom = 109.6\nfocus_mode = 0\ntexture_normal = {tab_refs[i*3]}\ntexture_hover = {tab_refs[i*3+1]}\ntexture_pressed = {tab_refs[i*3+2]}')
s.node('Grid','Control','.')
for i in range(25):slot(s,f'Slot{i}','Grid',483+(i%5)*65,118+(i//5)*65)
s.button('Previous','.',638,444,28,26,'‹');s.label('Page','.',668,444,98,26,'1 / 2',color='Color(0.42,0.16,0.02,1)',align=1);s.button('Next','.',770,444,28,26,'›')
s.button('Sort','.',700,478,98,34,'整理')
s.label('Capacity','.',486,446,130,22,'0 / 25',size=13,color='Color(0.42,0.16,0.02,1)')
s.label('Spirit','.',539,486,147,22,'0',size=16,color='Color(0.37,0.12,0.02,1)')
s.button('Close','.',799.2,28.5,33,38,'×')
s.node('Context','Control','.', 'visible = false\noffset_right = 128.0\noffset_bottom = 150.0\nmouse_filter = 0')
s.patch('Background','Context',0,0,128,150,'menu_background.png')
for i,(name,label) in enumerate([('Use','装备'),('Sell','出售'),('Lock','锁定'),('Close','关闭')]):s.button(name,'Context',4,4+i*36,120,32,label)
s.node('Tooltip','Control','.', 'visible = false\noffset_right = 290.0\noffset_bottom = 220.0\nmouse_filter = 2')
s.patch('Background','Tooltip',0,0,290,220,'tips_background.png')
s.label('Text','Tooltip',12,12,264,194,size=15,color='Color(0.372549,0.117647,0.019608,1)')
s.node('Confirm','Control','.', 'visible = false\noffset_left = 320.0\noffset_top = 205.0\noffset_right = 620.0\noffset_bottom = 385.0\nmouse_filter = 0')
s.patch('Background','Confirm',0,0,300,180,'warn_background.png')
s.label('Text','Confirm',20,20,260,80,'确认出售？',size=18,color='Color(0.372549,0.117647,0.019608,1)',align=1)
s.button('Less','Confirm',70,97,28,24,'−');s.label('Count','Confirm',100,97,100,24,'1',size=16,color='Color(0.372549,0.117647,0.019608,1)',align=1);s.button('More','Confirm',204,97,28,24,'+')
s.button('Yes','Confirm',42,133,88,34,'确定');s.button('No','Confirm',170,133,88,34,'取消')
s.node('Resistances','Control','.', 'visible = false\noffset_left = 310.0\noffset_top = 160.0\noffset_right = 630.0\noffset_bottom = 435.0\nmouse_filter = 0')
s.patch('Background','Resistances',0,0,320,275,'tips_background.png')
s.label('Title','Resistances',18,12,250,28,'五行与元素抗性',size=18,color='Color(0.372549,0.117647,0.019608,1)')
s.node('Values','Control','Resistances')
for i in range(8):s.label(f'Value{i}','Resistances/Values',24+(i%2)*144,54+(i//2)*40,128,32,size=16,color='Color(0.372549,0.117647,0.019608,1)')
s.button('Close','Resistances',110,228,100,32,'关闭')
s.save('data/ui/inventory.tscn')
#endregion

#region Player HUD, five skill slots, true source-frame cooldown and warning skin
s=Scene();FONT=s.resource('res://assets/ui/boss/count.ttf','FontFile')
font_ui=s.resource('res://addons/simple_inventory/assets/fonts/SourceHanSansSC-Regular-2.otf','FontFile')
script=s.resource('res://addons/battle_foundation/ui/battle_original_hud.gd','Script')
gray_shader=s.resource('res://addons/battle_foundation/ui/original_icon_gray.gdshader','Shader')
s.resources.append(f'[sub_resource type="ShaderMaterial" id="DisabledIcon"]\nshader = {gray_shader}\n')
inventory=s.resource('res://data/ui/inventory.tscn','PackedScene')
cd=s.resource('res://data/ui/skill_cooldown_frames.tres','SpriteFrames')
s.node('BattleHUD','Control','',f'layout_mode = 3\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\nmouse_filter = 2\nscript = {script}\ndisabled_icon_material = SubResource("DisabledIcon")')
s.node('Player','Control','.', 'mouse_filter = 2')
s.rect('Frame','Player',0,0,247,87,'player_frame.png')
for name,y,tex in [('HP',20,'hp_fill.png'),('MP',34,'mp_fill.png'),('EXP',48,'exp_fill.png')]:
    under=s.resource('res://assets/ui/original/bar_background.png');fill=s.resource('res://assets/ui/original/'+tex)
    s.node(name,'TextureProgressBar','Player',f'offset_left = 76.0\noffset_top = {y}\noffset_right = 225.0\noffset_bottom = {y+13}\nmouse_filter = 2\nmax_value = 1.0\nstep = 0.001\ntexture_under = {under}\ntexture_progress = {fill}\ntexture_progress_offset = Vector2(1,1)')
s.rect('Head','Player',8,10,60,60,'sunwukong_head.png', 'stretch_mode = 5')
shader=s.resource('res://addons/battle_foundation/ui/portrait_circle.gdshader','Shader')
s.resources.append(f'[sub_resource type="ShaderMaterial" id="PortraitMask"]\nshader = {shader}\n')
s.nodes[-1]+='material = SubResource("PortraitMask")\n'
for name,y in [('HP',21),('MP',34),('EXP',48)]:
    s.label(name+'Title','Player',82,y-2,25,15,name,size=10)
    s.label(name+'Text','Player',105,y-2,109,15,'0/0',size=10,align=1)
s.label('Level','Player',3.5,65,23,23,'1',size=14,align=1)
s.node('StatusIcons','Control','Player','mouse_filter = 2')
for i in range(16):
    name=f'Status{i}';parent='Player/StatusIcons'
    s.node(name,'Control',parent,f'visible = false\noffset_left = {75+32*i}\noffset_top = 60.0\noffset_right = {103+32*i}\noffset_bottom = 88.0\nmouse_filter = 1')
    s.node('Icon','TextureRect',parent+'/'+name,'offset_right = 28.0\noffset_bottom = 28.0\nmouse_filter = 2\nexpand_mode = 1')
    s.label('Count',parent+'/'+name,0,10,28,16,size=14,align=2)
    s.nodes[-1]+='\ntheme_override_colors/font_outline_color = Color(0,0,0,1)\ntheme_override_constants/outline_size = 2\n'
s.node('Skills','Control','.', 'anchor_top = 1.0\nanchor_bottom = 1.0\noffset_top = -70.0\noffset_bottom = -70.0\nmouse_filter = 2')
s.rect('Frame','Skills',0,-77,284,146,'skill_frame.png')
under=s.resource('res://assets/ui/original/rage_background.png');fill=s.resource('res://assets/ui/original/rage_fill.png')
s.node('Rage','TextureProgressBar','Skills',f'offset_left = 61.0\noffset_top = 56.0\noffset_right = 270.0\noffset_bottom = 67.0\nmouse_filter = 2\nmax_value = 1.0\nstep = 0.001\ntexture_under = {under}\ntexture_progress = {fill}\nfill_mode = 1')
s.rect('WushuangBase','Skills',0.75,10.85,55,55,'wushuang_base.png')
s.rect('WushuangIdle','Skills',3,12,57,57,'wushuang_idle.png')
full=s.resource('res://data/ui/wushuang_full.tscn','PackedScene')
prompt=s.resource('res://data/ui/wushuang_prompt.tscn','PackedScene')
s.nodes.append(f'[node name="WushuangFull" parent="Skills" instance={full}]\nposition = Vector2(32,21)\n')
s.nodes.append(f'[node name="WushuangPrompt" parent="Skills" instance={prompt}]\nposition = Vector2(5.25,39.35)\n')
s.node('Slots','Control','Skills' ,'mouse_filter = 2')
for i,action in enumerate([1,2,3,4,8]):
    name=f'Slot{i}';parent='Skills/Slots';x=84+i*41
    s.node(name,'Control',parent,f'offset_left = {x-18}\noffset_top = 18.95\noffset_right = {x+18}\noffset_bottom = 54.95\nmouse_filter = 1')
    s.rect('Icon',parent+'/'+name,0,0,36,36,f'skill_{action}.png')
    s.node('Cooldown','AnimatedSprite2D',parent+'/'+name,f'visible = false\nposition = Vector2(-8.35,-7.7)\ncentered = false\nsprite_frames = {cd}\nanimation = &"cooldown"')
    s.label('Key',parent+'/'+name,18,17,18,20,'',size=14,align=2)
    s.nodes[-1]+='\ntheme_override_colors/font_outline_color = Color(0,0,0,1)\ntheme_override_constants/outline_size = 2\n'
for i in range(2):
    s.label(f'ItemKey{i}','Skills',24,-60+40*i,16,20,'Q' if i==0 else 'E',size=14)
    s.nodes[-1]+='\ntheme_override_colors/font_outline_color = Color(0,0,0,1)\ntheme_override_constants/outline_size = 2\n'
FONT=font_ui;s.label('WushuangKey','Skills',0,22,62,20,'空格',size=12,align=1)
s.nodes[-1]+='\nvisible = false\n'
s.button('BagButton','.',824,520,88,38,'背包 B')
s.node('SkillTooltip','Control','.', 'visible = false\noffset_right = 290.0\noffset_bottom = 110.0\nmouse_filter = 2')
s.patch('Background','SkillTooltip',0,0,290,110,'tips_background.png')
s.label('Text','SkillTooltip',12,10,266,90,'',size=16,color='Color(0.372549,0.117647,0.019608,1)')
s.nodes.append(f'[node name="Inventory" parent="." instance={inventory}]\n')
# CreateComponent最多11条待淡出提示；另11条预置槽覆盖正在淡出的提示。
s.node('Notifications','Control','.', 'mouse_filter = 2')
for i in range(22):
    name=f'Notice{i}';parent='Notifications'
    s.node(name,'Control',parent,'visible = false\nmouse_filter = 2')
    s.patch('Background',parent+'/'+name,300,267.5,340,55,'warn_background.png')
    s.label('Text',parent+'/'+name,314,276,312,36,'',size=20,color='Color(0.372549,0.117647,0.019608,1)',align=1)
# 原前进提示预置到共享HUD中心；与普通文字提示队列独立。
next_screen=s.resource('res://data/ui/next_screen.tscn','PackedScene')
s.node('NextScreen','Control','.', 'layout_mode = 1\nanchors_preset = 8\nanchor_left = 0.5\nanchor_top = 0.5\nanchor_right = 0.5\nanchor_bottom = 0.5\ngrow_horizontal = 2\ngrow_vertical = 2\nmouse_filter = 2')
s.nodes.append(f'[node name="Animation" parent="NextScreen" instance={next_screen}]\n')
s.save('data/ui/battle_hud.tscn')
#endregion

#region Original Gateway bitmap/XML asset converted offline to authored AnimationPlayer
sys.path.insert(0,str(ORIGINAL))
from backends.zmhj_config import _Amf3Reader,_read_one
source=ORIGINAL/'games/zmhj-g5/cache/assets/item/1001/1.swf';reader=_Amf3Reader(source.read_bytes());header=reader.read()
entries=[_read_one(zlib.decompress(reader.read(),-15)) for _ in range(header['fn'])]
png=next(zlib.decompress(e['data']) for e in entries if e['extension']=='png');xml=next(zlib.decompress(e['data']) for e in entries if e['extension']=='xml')
folder=PROJECT/'assets/ui/original';(folder/'gateway.png').write_bytes(png);(folder/'gateway.xml').write_text(ET.tostring(ET.fromstring(xml),encoding='unicode'),'utf8')
rows=[dict(e.attrib) for e in ET.fromstring(xml) if e.get('name','').startswith('idle')];pivot=[0.,0.]
text='[gd_scene format=3]\n[ext_resource type="Script" path="res://addons/battle_foundation/ui/original_ui_animation_2d.gd" id="script"]\n[ext_resource type="Texture2D" path="res://assets/ui/original/gateway.png" id="atlas"]\n'
positions=[]
for i,r in enumerate(rows):
    if 'pivotX' in r:pivot=[float(r['pivotX']),float(r['pivotY'])]
    fx=-float(r.get('frameX',0));fy=-float(r.get('frameY',0))
    positions.append(f'Vector2({-pivot[0]}, {-pivot[1]})')
    text+=f'[sub_resource type="AtlasTexture" id="Frame{i}"]\natlas = ExtResource("atlas")\nregion = Rect2({r["x"]},{r["y"]},{r["width"]},{r["height"]})\nmargin = Rect2({fx},{fy},{fx},{fy})\nfilter_clip = true\n'
text+=f'[sub_resource type="Animation" id="Idle"]\nlength = {len(rows)/30:.9f}\nloop_mode = 1\n'
def track(n,path,values):
    return f'tracks/{n}/type = "value"\ntracks/{n}/path = NodePath("{path}")\ntracks/{n}/interp = 0\ntracks/{n}/keys = {{"times": PackedFloat32Array({", ".join(f"{i/30:.9f}" for i in range(len(values)))}), "transitions": PackedFloat32Array({", ".join("1" for _ in values)}), "update": 1, "values": [{", ".join(values)}]}}\n'
text+=track(0,'Sprite2D:texture',[f'SubResource("Frame{i}")' for i in range(len(rows))])+track(1,'Sprite2D:position',positions)
text+='[sub_resource type="AnimationLibrary" id="Library"]\n_data = {&"idle": SubResource("Idle")}\n[node name="Gateway" type="Node2D"]\nvisible = false\nscale = Vector2(2,2)\nscript = ExtResource("script")\nclip = &"idle"\n[node name="Sprite2D" type="Sprite2D" parent="."]\ncentered = false\n[node name="AnimationPlayer" type="AnimationPlayer" parent="."]\ncallback_mode_process = 2\nlibraries/ = SubResource("Library")\n'
write('data/ui/gateway.tscn',text)
manifest_path=PROJECT/'assets/ui/original/source_mapping.json'
manifest=json.loads(manifest_path.read_text('utf8'))
source_paths={entry['path'] for entry in manifest['sources']}
for relative in [source.relative_to(ORIGINAL).as_posix(),'out/zmhj-equip-skill-diag/org/moon/TipsManager.as','out/zmhj-equip-skill-diag/modules/abc/TextAttrManager.as','out/zmhj-equip-skill-diag/org/moon/utils/Scale9Image.as']:
    if relative not in source_paths:manifest['sources'].append({'path':relative,'sha256':hashlib.sha256((ORIGINAL/relative).read_bytes()).hexdigest()})
manifest['sources'].sort(key=lambda entry:entry['path'])
manifest.update({'gateway':{'source':source.relative_to(ORIGINAL).as_posix(),'frames':len(rows),'fps':30,'world_scale':2,'first_pivot':[float(rows[0]['pivotX']),float(rows[0]['pivotY'])]},'notification':{'wait_seconds':1.5,'fade_seconds':1,'rise_pixels':100,'curve':'QuadOut','pending_limit':11,'preauthored_slots':22,'common_text_color':'#5F1E05'},'bag_max_capacity':500,'sell_discount':0.2})
write('assets/ui/original/source_mapping.json',json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(f'Authored battle HUD, 25 editable bag slots, equipment/actions/tooltips and original {len(rows)}-frame Gateway')
#endregion

#region Attach preauthored scenes and inventory data to the existing playable level
import re
path=PROJECT/'game/levels/biyujing.tscn';text=path.read_text('utf8')
if 'id="original_hud"' not in text:
    text=text.replace('[node name="LevelProgressionDemo"','[ext_resource type="PackedScene" path="res://data/ui/battle_hud.tscn" id="original_hud"]\n[node name="LevelProgressionDemo"',1)
    text+='[node name="BattleHUD" parent="HUD" instance=ExtResource("original_hud")]\n'
text=text.replace('[node name="Panel" type="PanelContainer" parent="HUD"]\n','[node name="Panel" type="PanelContainer" parent="HUD"]\nvisible = false\n')
text=text.replace('[node name="Help" type="Label" parent="HUD"]\n','[node name="Help" type="Label" parent="HUD"]\nvisible = false\n')
text=re.sub(r'(visible = false\n)+','visible = false\n',text)
path.write_text(text,'utf8')
path=PROJECT/'data/battle2d/sunwukong_2d.tscn';text=path.read_text('utf8')
text=re.sub(r'\[ext_resource type="Script"(?: uid="[^"]+")? path="res://addons/simple_inventory/src/core/C_Inventory.gd" id="component_Inventory"\]', '[ext_resource type="Script" path="res://addons/simple_inventory/src/core/original_inventory.gd" id="component_Inventory"]',text)
if 'id="bag_weapon"' not in text:
    refs=''.join(f'[ext_resource type="Resource" path="res://data/inventory/{id}.tres" id="bag_{part}"]\n' for id,part in [('110101001','armor'),('110101002','helmet'),('110101003','weapon')])
    pos=text.index('[sub_resource');text=text[:pos]+refs+text[pos:]
    text=text.replace('script = ExtResource("component_Inventory")','script = ExtResource("component_Inventory")\ninitial_items = Array[Item]([ExtResource("bag_armor"), ExtResource("bag_helmet"), ExtResource("bag_weapon")])')
if 'id="original_bag_rules"' not in text:
    pos=text.index('[sub_resource');text=text[:pos]+'[ext_resource type="JSON" path="res://data/inventory/original_rules.json" id="original_bag_rules"]\n'+text[pos:]
    text=text.replace('script = ExtResource("component_Inventory")','script = ExtResource("component_Inventory")\noriginal_rules = ExtResource("original_bag_rules")')
path.write_text(text,'utf8')
path=PROJECT/'data/levels/biyujing/progression/map.tscn';text=path.read_text('utf8')
if 'id="gateway_visual"' not in text:
    pos=text.index('[sub_resource');text=text[:pos]+'[ext_resource type="PackedScene" path="res://data/ui/gateway.tscn" id="gateway_visual"]\n'+text[pos:]
    text+='[node name="Gateway" parent="FinalExit" instance=ExtResource("gateway_visual")]\n'
text=text.replace('[node name="Label" type="Label" parent="FinalExit"]\n','[node name="Label" type="Label" parent="FinalExit"]\nvisible = false\n')
text=re.sub(r'(\[node name="Label" type="Label" parent="Gates/Gate[1-5]"\]\n)', r'\1visible = false\n',text)
text=re.sub(r'(visible = false\n)+','visible = false\n',text)
path.write_text(text,'utf8')
#endregion

# Final authored typography and original button states.
from refine_original_inventory_ui import refine
refine()
if (PROJECT/'data/protection/first_level_source.json').exists():
    from refine_combat_hud import author
    author()
