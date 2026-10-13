"""Compose source-ZMX1 geography with the existing original-ZMX5 UI assets."""
import json,re,shutil
import import_huaguoshan as h
ROOT,CACHE,write,dump=h.ROOT,h.CACHE,h.write,h.dump
ASSETS=ROOT/'assets/ui/zaomeng1/world_map'

def node(name,kind,parent,box,extra=''):
    x,y,w,hh=box
    return f'[node name="{name}" type="{kind}" parent="{parent}"]\noffset_left = {float(x)}\noffset_top = {float(y)}\noffset_right = {float(x+w)}\noffset_bottom = {float(y+hh)}\n'+extra+'\n'

def main():
    ASSETS.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(h.sprite_file('zaomeng1-map-parts',184),ASSETS/'background.png')
    shutil.copyfile(next((CACHE/'map-city-ui/main').rglob('1.png')),ASSETS/'scene_selection.png')
    for i in range(1,4):
        path=next((CACHE/'map-city-ui/id-71').rglob(f'{i}.png'))
        shutil.copyfile(path,ASSETS/f'back_{i-1}.png')
    entries=json.loads((CACHE/'zaomeng1-worldmap.json').read_text('utf8'))['symbols'][0]['frames'][0]['placements']
    bounds={}
    for log in ('zaomeng1-map-parts.log','zaomeng1-map-more.log'):
        for cid,x0,x1,y0,y1 in re.findall(r'RENDER_BOUNDS #(\d+) \[RECT x=(-?\d+) to (-?\d+), y=(-?\d+) to (-?\d+)\]',(CACHE/log).read_text('utf8')):bounds[int(cid)]=[int(x0)/20,int(y0)/20,(int(x1)-int(x0))/20,(int(y1)-int(y0))/20]
    stages=[next(p for p in entries if p['instance']==f's{s}_{l}') for s,l in [(1,1),(1,2),(1,3),(2,1),(2,2),(2,3),(3,1),(3,2),(3,3),(4,1)]]
    levels=[]
    for p in stages:
        lid=p['instance'][1:].replace('_','-');implemented={'1-1':('花果山','huaguoshan',33),'1-2':('水帘洞','shuiliandong',48)}
        name,scene,count=implemented.get(lid,(f'关卡 {lid}','',0))
        levels.append({'id':lid,'name':name,'scene':f'res://game/levels/{scene}.tscn' if scene else '',
                       'description':f'击败本关敌人与Boss，进入传送门后按 W / ↑ 通关。\n{count}个敌人 · 五个连续区域' if scene else '此关卡暂未开放。',
                       'source_symbol_id':p['character_id'],'position':[p['x'],p['y']]})
        for i in (1,2,3):shutil.copyfile(h.sprite_file('zaomeng1-map-parts',p['character_id'],i),ASSETS/f'stage_{lid}_{i-1}.png')
    dump(ROOT/'data/campaigns/zaomeng1/world_map.json',{'version':1,'display_name':'东胜神洲（七魔王）','geography_source':'OtherMat_v5.swf/export.SelectPLace','ui_source':'造梦西游5 scene0/selectcity/common UI','levels':levels})
    theme='''[gd_resource type="Theme" format=3]
[ext_resource type="FontFile" path="res://assets/ui/original/ui_font.ttf" id="font"]
[ext_resource type="Texture2D" path="res://assets/ui/original/button_0.png" id="button"]
[ext_resource type="Texture2D" path="res://assets/ui/original/button_1.png" id="hover"]
[ext_resource type="Texture2D" path="res://assets/ui/original/button_2.png" id="pressed"]
[ext_resource type="Texture2D" path="res://assets/ui/original/tips_background.png" id="panel"]
'''
    for state,texture in [('Normal','button'),('Hover','hover'),('Pressed','pressed')]:theme+=f'[sub_resource type="StyleBoxTexture" id="{state}"]\ntexture = ExtResource("{texture}")\ntexture_margin_left = 16.0\ntexture_margin_right = 16.0\ncontent_margin_left = 18.0\ncontent_margin_right = 18.0\n'
    theme+='''[sub_resource type="StyleBoxTexture" id="Panel"]
texture = ExtResource("panel")
texture_margin_left = 12.0
texture_margin_top = 12.0
texture_margin_right = 12.0
texture_margin_bottom = 12.0
[resource]
default_font = ExtResource("font")
default_font_size = 18
Button/colors/font_color = Color(0.32,0.15,0.02,1)
Button/colors/font_hover_color = Color(0.42,0.12,0.01,1)
Button/colors/font_pressed_color = Color(0.32,0.15,0.02,1)
Button/colors/font_disabled_color = Color(0.4,0.32,0.22,1)
Button/font_sizes/font_size = 20
Button/styles/normal = SubResource("Normal")
Button/styles/hover = SubResource("Hover")
Button/styles/pressed = SubResource("Pressed")
Button/styles/disabled = SubResource("Normal")
Panel/styles/panel = SubResource("Panel")
Label/colors/font_color = Color(0.32,0.12,0.035,1)
'''
    write(ROOT/'data/ui/campaign_theme.tres',theme)
    refs='''[gd_scene format=3]
[ext_resource type="Script" path="res://game/world_map/ZaomengOneWorldMap.cs" id="script"]
[ext_resource type="Theme" path="res://data/ui/campaign_theme.tres" id="theme"]
[ext_resource type="Texture2D" path="res://assets/ui/zaomeng1/world_map/background.png" id="background"]
[ext_resource type="AudioStream" path="res://assets/audio/zaomeng1/world_map.mp3" id="music"]
[ext_resource type="Texture2D" path="res://assets/ui/zaomeng1/world_map/scene_selection.png" id="selection"]
'''
    for i in range(3):refs+=f'[ext_resource type="Texture2D" path="res://assets/ui/zaomeng1/world_map/back_{i}.png" id="back{i}"]\n'
    for p in stages:
        lid=p['instance'][1:].replace('_','-')
        for i in range(3):refs+=f'[ext_resource type="Texture2D" path="res://assets/ui/zaomeng1/world_map/stage_{lid}_{i}.png" id="{p["instance"]}_{i}"]\n'
    refs+='[sub_resource type="StyleBoxEmpty" id="EmptyPanel"]\n'
    scene='''[node name="ZaomengOneWorldMap" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme = ExtResource("theme")
script = ExtResource("script")
'''
    scene+=node('Background','TextureRect','.',(0,0,940,590),'mouse_filter = 2\ntexture = ExtResource("background")\nexpand_mode = 1')
    scene+=node('Stages','Control','.',(0,0,940,590),'mouse_filter = 2')
    for p in stages:
        cid=p['character_id'];lid=p['instance'][1:].replace('_','-');x0,y0,w,hh=bounds[cid]
        sy=p.get('scale_y',1)
        x,y=p['x']+x0,p['y']+y0*sy
        hh*=sy
        name='Stage_'+lid.replace('-','_')
        scene+=node(name,'TextureButton','Stages',(x,y,w,hh),f'focus_mode = 0\nmetadata/latest_texture = ExtResource("{p["instance"]}_2")\ntexture_normal = ExtResource("{p["instance"]}_0")\ntexture_hover = ExtResource("{p["instance"]}_1")\ntexture_pressed = ExtResource("{p["instance"]}_1")\nignore_texture_size = true\nstretch_mode = 0')
        scene+=node('State','Label','Stages/'+name,(0,hh-15,w,20),'mouse_filter = 2\ntheme_override_colors/font_color = Color(1,0.9,0.52,1)\ntheme_override_colors/font_outline_color = Color(0.17,0.08,0.025,1)\ntheme_override_constants/outline_size = 3\ntheme_override_font_sizes/font_size = 14\nhorizontal_alignment = 1')
    scene+=node('Back','TextureButton','.',(863.9,7.95,64,60),'texture_normal = ExtResource("back0")\ntexture_hover = ExtResource("back1")\ntexture_pressed = ExtResource("back2")\nfocus_mode = 0\ntooltip_text = "返回最近挑战的关卡"')
    scene+=node('Progress','Label','.',(18,555,620,28),'mouse_filter = 2\ntheme_override_colors/font_color = Color(1,0.9,0.56,1)\ntheme_override_colors/font_outline_color = Color(0.1,0.13,0.06,1)\ntheme_override_constants/outline_size = 4')
    scene+=node('Biyujing','Button','.',(782,542,142,40),'text = "碧玉径"\nfocus_mode = 0')
    scene+='[node name="Music" type="AudioStreamPlayer" parent="."]\nstream = ExtResource("music")\nbus = &"Music"\n'
    write(ROOT/'game/world_map/zaomeng1_world_map.tscn',refs+scene)
    result='''[gd_scene format=3]
[ext_resource type="Theme" path="res://data/ui/campaign_theme.tres" id="theme"]
[node name="CampaignResult" type="Control"]
mouse_filter = 2
theme = ExtResource("theme")
'''
    result+=node('Overlay','Control','.',(0,0,940,590),'visible = false')
    result+=node('Shade','ColorRect','Overlay',(0,0,940,590),'color = Color(0,0,0,0.45)')
    result+=node('Panel','Panel','Overlay',(290,150,360,280))
    result+=node('Title','Label','Overlay/Panel',(20,20,320,44),'text = "关卡通关"\ntheme_override_font_sizes/font_size = 30\nhorizontal_alignment = 1')
    result+=node('Details','Label','Overlay/Panel',(30,88,300,95),'horizontal_alignment = 1\nautowrap_mode = 3')
    result+=node('Return','Button','Overlay/Panel',(30,208,140,44),'text = "大地图"\nfocus_mode = 0')
    result+=node('Retry','Button','Overlay/Panel',(190,208,140,44),'text = "再次挑战"\nfocus_mode = 0')
    write(ROOT/'data/ui/campaign_result.tscn',result)
    # Keep all manual flower-level scene transforms.
    path=ROOT/'game/levels/huaguoshan.tscn';text=path.read_text('utf8')
    if 'campaign_result.tscn' not in text:
        text=text.replace('[node name="Huaguoshan"','[ext_resource type="PackedScene" path="res://data/ui/campaign_result.tscn" id="campaign_result"]\n\n[node name="Huaguoshan"',1)
        text=text.replace('[editable path="BattleSession/Actors"]','[node name="CampaignResult" parent="HUD" instance=ExtResource("campaign_result")]\n\n[editable path="BattleSession/Actors"]')
        write(path,text)
    write(ROOT/'game/levels/Huaguoshan.cs','public partial class Huaguoshan : ZaomengOneLevelScene\n{\n    protected override string CampaignId => "1-1";\n    public Huaguoshan() => level_id = "花果山";\n}\n')
    print('Authored source world map, 10 stages, original ZMX5 UI, shared campaign result panel.')

if __name__=='__main__':main()
