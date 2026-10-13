"""Export original dynamic bag layers and author preplaced popup/identity nodes.

This is an asset/scene authoring command. It never launches Godot or test scenes.
"""
from pathlib import Path
import argparse, hashlib, json, math, re, shutil, subprocess, sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'.cleanup-backup/python-packages'))
from PIL import Image

#region Read-only original SWF exports; shared frame resources
def export(original, relative, symbols, folder, background=False):
    command=['java','-Djava.awt.headless=true','-Dfile.encoding=UTF-8','-cp',str(original/'out/swfutil/ffdec_lib_20.1.0/*'),str(ROOT/'tools/ExportOriginalBattleUI.java'),str(original/relative),str(folder),symbols]
    if background: command.append('background')
    result=subprocess.run(command, capture_output=True, encoding='utf8', check=True)
    folder.mkdir(parents=True, exist_ok=True)
    (folder/'inspection.txt').write_text(result.stdout, 'utf8')
    return result.stdout

def images(folder,symbol):
    return sorted((folder/symbol.replace('#','id-')).rglob('*.png'), key=lambda p:int(p.stem))

def copy(folder,symbol,name,index=0):
    shutil.copyfile(images(folder,symbol)[index], ROOT/'assets/ui/original'/name)

def glow_scene(files):
    frames=[Image.open(f).convert('RGBA') for f in files]
    w,h=frames[0].size
    cols=max(1,2048//(w+2)); atlas=Image.new('RGBA',(cols*(w+2),math.ceil(len(frames)/cols)*(h+2)))
    resources='[ext_resource type="Texture2D" path="res://assets/ui/original/bag_portrait_glow.png" id="atlas"]\n'
    for i,frame in enumerate(frames):
        x=(i%cols)*(w+2);y=(i//cols)*(h+2);atlas.paste(frame,(x,y))
        resources+=f'[sub_resource type="AtlasTexture" id="Frame{i}"]\natlas = ExtResource("atlas")\nregion = Rect2({x},{y},{w},{h})\nfilter_clip = true\n'
    atlas.save(ROOT/'assets/ui/original/bag_portrait_glow.png')
    times=', '.join(f'{i/30:.9f}' for i in range(len(frames)))
    values=', '.join(f'SubResource("Frame{i}")' for i in range(len(frames)))
    text='[gd_scene format=3]\n[ext_resource type="Script" path="res://addons/battle_foundation/ui/original_ui_animation_2d.gd" id="script"]\n'+resources
    text+=f'[sub_resource type="Animation" id="Glow"]\nlength = {len(frames)/30:.9f}\nloop_mode = 1\ntracks/0/type = "value"\ntracks/0/path = NodePath("Sprite2D:texture")\ntracks/0/interp = 0\ntracks/0/keys = {{"times": PackedFloat32Array({times}), "transitions": PackedFloat32Array({", ".join("1" for _ in frames)}), "update": 1, "values": [{values}]}}\n'
    text+='[sub_resource type="AnimationLibrary" id="Library"]\n_data = {&"bag_glow": SubResource("Glow")}\n[node name="PortraitGlow" type="Node2D"]\nscript = ExtResource("script")\nclip = &"bag_glow"\n[node name="Sprite2D" type="Sprite2D" parent="."]\ncentered = false\ntexture = SubResource("Frame0")\n[node name="AnimationPlayer" type="AnimationPlayer" parent="."]\ncallback_mode_process = 2\nlibraries/ = SubResource("Library")\n'
    (ROOT/'data/ui/inventory_portrait_glow.tscn').write_text(text,'utf8')
#endregion

#region Deterministic scene patches preserve unrelated authored UI
def author():
    path=ROOT/'data/ui/inventory.tscn';text=path.read_text('utf8')
    resources=[]
    def resource(id,asset,kind='Texture2D'):
        resources.append(f'[ext_resource type="{kind}" path="res://{asset}" id="detail_{id}"]\n')
        return f'ExtResource("detail_{id}")'
    def block(name,parent='.'):
        return re.search(r'\[node name="'+re.escape(name)+r'"[^\n]*parent="'+re.escape(parent)+r'"[^\n]*\]\n.*?(?=\n\[|\Z)',text,re.S)
    def props(name,values,parent='.'):
        nonlocal text
        m=block(name,parent)
        if not m:raise ValueError(f'Missing {parent}/{name}')
        b=m.group(0)
        for key,value in values.items():
            if re.search(r'^'+re.escape(key)+r' = ',b,re.M):b=re.sub(r'^'+re.escape(key)+r' = .*$',lambda _:f'{key} = {value}',b,flags=re.M)
            else:b+=f'{key} = {value}\n'
        text=text[:m.start()]+b+text[m.end():]
    # Replace only nodes this refinement owns; no runtime construction.
    roots=['PortraitGlow','PlayerNumber','ComparisonTooltip','FashionToggle']
    text=re.sub(r'\[ext_resource[^\n]*id="detail_[^"]+"\]\n','',text)
    text=re.sub(r'^menu_textures = .*\n','',text,flags=re.M)
    text=re.sub(r'^fashion_textures = .*\n','',text,flags=re.M)
    text=re.sub(r'\[node name="Caption"[^\n]*parent="Context/(?:Use|Sell|Lock)"[^\n]*\]\n.*?(?=\n\[|\Z)','',text,flags=re.S)
    for name in roots:
        text=re.sub(r'\[node[^\n]*(?:name="'+name+r'"[^\n]*parent="\."|parent="'+name+r'(?:/[^"]*)?")[^\n]*\]\n.*?(?=\n\[|\Z)','',text,flags=re.S)
    for name in ['Tooltip','Resistances']:
        text=re.sub(r'\[node[^\n]*(?:name="'+name+r'"[^\n]*parent="\."|parent="'+name+r'(?:/[^"]*)?")[^\n]*\]\n.*?(?=\n\[|\Z)','',text,flags=re.S)
    font='ExtResource("R1")'
    def node(name,kind,parent,body=''):
        return f'[node name="{name}" type="{kind}" parent="{parent}"]\n'+body+'\n'
    def rect(x,y,w,h):return f'offset_left = {x}\noffset_top = {y}\noffset_right = {x+w}\noffset_bottom = {y+h}\n'
    def label(name,parent,x,y,w,h,value,size=16,color='Color(0.372549,0.117647,0.019608,1)'):
        return node(name,'Label',parent,rect(x,y,w,h)+'mouse_filter = 2\n'+f'theme_override_fonts/font = {font}\ntheme_override_font_sizes/font_size = {size}\ntheme_override_colors/font_color = {color}\ntext = '+json.dumps(value,ensure_ascii=False))
    props('BodyPanel',{'texture':resource('body','assets/ui/original/body_panel_static.png'),'offset_left':'128.95','offset_top':'77.6','offset_right':'478.95','offset_bottom':'527.6'})
    props('RolePortrait',{'scale':'Vector2(0.5, 0.5)','position':'Vector2(270, 280)'})
    glow=resource('glow','data/ui/inventory_portrait_glow.tscn','PackedScene')
    portrait=block('RolePortrait');text=text[:portrait.start()]+f'[node name="PortraitGlow" parent="." instance={glow}]\nposition = Vector2(165,158.35)\n'+text[portrait.start():]
    # Dynamic numbered drawer, masked by its preplaced parent.
    uidicon=resource('uid_icon','assets/ui/original/bag_uid_icon.png')
    uidbg=resource('uid_bg','assets/ui/original/bag_uid_background.png')
    copyrefs=[resource(f'copy{i}',f'assets/ui/original/bag_uid_copy_{i}.png') for i in range(3)]
    nodes=node('PlayerNumber','Control','.',rect(131.6,121.05,211.1,32)+'z_index = 5\nmouse_filter = 1\nclip_contents = true')
    nodes+=node('Drawer','Control','PlayerNumber',rect(-6.9,0,168,30)+'visible = false\nmouse_filter = 1')
    nodes+=node('Background','TextureRect','PlayerNumber/Drawer',rect(0,0,168,30)+f'mouse_filter = 2\ntexture = {uidbg}\nexpand_mode = 1')
    nodes+=label('Value','PlayerNumber/Drawer',12,4,110,23,'',16)
    nodes+=node('Copy','TextureButton','PlayerNumber/Drawer',rect(120.35,2.9,44,26)+f'focus_mode = 0\ntexture_normal = {copyrefs[0]}\ntexture_hover = {copyrefs[1]}\ntexture_pressed = {copyrefs[2]}')
    nodes+=node('Icon','TextureRect','PlayerNumber',rect(0,1,55,31)+f'mouse_filter = 0\ntexture = {uidicon}\nexpand_mode = 1')
    # Fashion switch is independent of the wardrobe module button.
    fashion=[resource(f'fashion{i}',f'assets/ui/original/bag_fashion_{i}.png') for i in range(6)]
    nodes+=node('FashionToggle','TextureButton','.',rect(407.35,122.6,72.5,24)+f'visible = false\nfocus_mode = 0\ntexture_normal = {fashion[0]}\ntexture_hover = {fashion[2]}\ntexture_pressed = {fashion[1]}')
    props('Wardrobe',{'ignore_texture_size':'true','stretch_mode':'0'})
    menus=[resource(f'menu{i}',f'assets/ui/original/bag_menu_text_{i}.png') for i in range(1,26)]
    # Godot applies scene properties in order: script exports must follow script.
    page_property=re.search(r'^page_textures = .*\n',text,re.M)
    page_line=page_property.group(0) if page_property else ''
    text=re.sub(r'^page_textures = .*\n','',text,flags=re.M)
    exported=page_line+'menu_textures = Array[Texture2D](['+', '.join(menus)+'])\n'+'fashion_textures = Array[Texture2D](['+', '.join(fashion)+'])\n'
    text=text.replace('script = ExtResource("R2")\n','script = ExtResource("R2")\n'+exported,1)
    props('Context',{'z_index':'30','offset_right':'130.0','offset_bottom':'174.0'})
    # Scale9Image defaults to thirds of the original 115x88 menu bitmap.
    props('Background',{'layout_mode':'1','anchors_preset':'15','anchor_right':'1.0','anchor_bottom':'1.0','offset_right':'0.0','offset_bottom':'0.0','patch_margin_left':'38','patch_margin_right':'39','patch_margin_top':'29','patch_margin_bottom':'30'},'Context')
    for i,name in enumerate(['Use','Sell','Lock']):
        props(name,{'offset_left':'15','offset_top':str(24+i*47),'offset_right':'115','offset_bottom':str(60+i*47),'text':'""','theme_override_styles/disabled':'SubResource("Button0")'},'Context')
        nodes+=node('Caption','TextureRect',f'Context/{name}',rect(0,0,100,36)+'mouse_filter = 2\nexpand_mode = 1\nstretch_mode = 5')
    props('Close',{'visible':'false'},'Context')
    tooltip=resource('tooltip','data/ui/inventory_item_tooltip.tscn','PackedScene')
    nodes+=f'[node name="Tooltip" parent="." instance={tooltip}]\nvisible = false\nz_index = 25\n[node name="ComparisonTooltip" parent="." instance={tooltip}]\nvisible = false\nz_index = 25\n'
    tips=resource('tips','assets/ui/original/tips_background.png')
    nodes+=node('Resistances','Control','.',rect(0,0,420,90)+'visible = false\nz_index = 26\nmouse_filter = 2')
    nodes+=node('Background','NinePatchRect','Resistances','layout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\nmouse_filter = 2\n'+f'texture = {tips}\npatch_margin_left = 45\npatch_margin_right = 29\npatch_margin_top = 30\npatch_margin_bottom = 29')
    nodes+=label('Text','Resistances',12,12,396,200,'',16)
    # Legacy scene regenerators can still run safely before this refinement.
    text+=nodes
    index=text.index('[sub_resource');text=text[:index]+''.join(resources)+text[index:]
    path.write_text(text,'utf8')
    # Reusable popup scene with only authored nodes.
    tip='[gd_scene format=3]\n[ext_resource type="Script" path="res://addons/battle_foundation/ui/original_inventory_tooltip.gd" id="script"]\n[ext_resource type="FontFile" path="res://assets/ui/original/ui_font.ttf" id="R1"]\n'
    for id,name in [('bg','tips_background'),('quality','tips_quality'),('type','tips_type'),('level','tips_level'),('equipped','zbz_icon')]:tip+=f'[ext_resource type="Texture2D" path="res://assets/ui/original/{name}.png" id="{id}"]\n'
    tip+='[node name="ItemTooltip" type="Control"]\noffset_right = 260\noffset_bottom = 300\nmouse_filter = 2\nscript = ExtResource("script")\n'
    # BasicTips explicitly uses Rectangle(45,30,1,1) on the 75x60 bitmap.
    tip+=node('Background','NinePatchRect','.','layout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\nmouse_filter = 2\ntexture = ExtResource("bg")\npatch_margin_left = 45\npatch_margin_right = 29\npatch_margin_top = 30\npatch_margin_bottom = 29')
    tip+=label('Name','.',20,15,215,24,'',18,'Color(1,1,1,1)')+'theme_override_colors/font_outline_color = Color(0,0,0,1)\ntheme_override_constants/outline_size = 2\ntheme_override_colors/font_shadow_color = Color(0,0,0,0.35)\ntheme_override_constants/shadow_offset_x = 0\ntheme_override_constants/shadow_offset_y = 0\ntheme_override_constants/shadow_outline_size = 1\n'
    for id,y in [('quality',40),('type',65),('level',90)]:
        tip+=node(id.capitalize()+'Row','TextureRect','.',rect(13,y,234,23)+f'mouse_filter = 2\ntexture = ExtResource("{id}")\nexpand_mode = 1')
        tip+=label(id.capitalize(),'.',70,y,174,23,'',16,'Color(1,1,1,1)')
    tip+=node('Body','RichTextLabel','.',rect(20,113,220,130)+f'mouse_filter = 2\nbbcode_enabled = true\nscroll_active = false\ntheme_override_fonts/normal_font = {font}\ntheme_override_font_sizes/normal_font_size = 16\ntheme_override_constants/line_separation = 3\ntheme_override_colors/default_color = Color(0.372549,0.117647,0.019608,1)')
    tip+=label('Price','.',20,260,220,25,'',16)
    tip+=node('Equipped','TextureRect','.',rect(235,10,17,42)+'mouse_filter = 2\ntexture = ExtResource("equipped")\nexpand_mode = 1\nstretch_mode = 5')
    (ROOT/'data/ui/inventory_item_tooltip.tscn').write_text(tip,'utf8')
    actor_path=ROOT/'data/characters/sunwukong/character.tscn';actor=actor_path.read_text('utf8')
    if 'id="inventory_presentation_rules"' not in actor:
        index=actor.index('[sub_resource');actor=actor[:index]+'[ext_resource type="JSON" path="res://data/inventory/presentation_rules.json" id="inventory_presentation_rules"]\n'+actor[index:]
    node_match=re.search(r'\[node name="Inventory"[^\n]*\]\n.*?(?=\n\[|\Z)',actor,re.S)
    b=node_match.group(0)
    if 'presentation_rules =' not in b:b+='presentation_rules = ExtResource("inventory_presentation_rules")\n'
    actor=actor[:node_match.start()]+b+actor[node_match.end():];actor_path.write_text(actor,'utf8')
#endregion

#region Offline authoring entry; never runs checks or the game
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--original-root',type=Path,default=Path('D:/UserData/Downloads/game/Speculum-4399-master'));parser.add_argument('--author-only',action='store_true');args=parser.parse_args()
    original=args.original_root
    if not args.author_only:
        source='games/zmhj-g5/cache/assets/module/backpack_20260817_1.swf'; material='games/zmhj-g5/cache/assets/module/material_20260831_1.swf'
        out=ROOT/'.cleanup-backup/bag-details'
        export(original,source,'#57,#159,#162,#158,#140',out/'parts')
        stdout=export(original,source,'bodyPanel',out/'static',True)
        # Restore the original absolute registration, never stretch the remaining art.
        bounds=re.search(r'RENDER_BOUNDS bodyPanel \[RECT x=(-?\d+) to (-?\d+), y=(-?\d+) to (-?\d+)\]',stdout)
        image=Image.open(images(out/'static','bodyPanel')[0]).convert('RGBA')
        canvas=Image.new('RGBA',(350,450))
        canvas.paste(image,(round(int(bounds[1])/20-128.95),round(int(bounds[3])/20-77.6)))
        canvas.save(ROOT/'assets/ui/original/body_panel_static.png')
        glow_scene(images(out/'parts','#57'))
        for symbol,name in [('#159','bag_uid_background.png'),('#162','bag_uid_icon.png')]:copy(out/'parts',symbol,name)
        for i in range(3):copy(out/'parts','#158',f'bag_uid_copy_{i}.png',i)
        for i in range(6):copy(out/'parts','#140',f'bag_fashion_{i}.png',i)
        export(original,material,'tips_quality,tips_type,tips_level,tips_stone_bg,zbz_icon,menu_button_text',out/'tips')
        for name in ['tips_quality','tips_type','tips_level','tips_stone_bg','zbz_icon']:copy(out/'tips',name,name+'.png')
        for i in range(25):copy(out/'tips','menu_button_text',f'bag_menu_text_{i+1}.png',i)
        sys.path.insert(0,str(original));from backends.zmhj_config import load_config_archive
        config=load_config_archive(original/'games/zmhj-g5')
        rules={'roles':{'0':'通用','1':'悟空','2':'唐僧','3':'八戒','4':'沙僧','5':'白龙','11':'灵宠'},'refinement_names':{str(k):v['refineName'] for k,v in config['EquRefine'].items()}}
        (ROOT/'data/inventory/presentation_rules.json').write_text(json.dumps(rules,ensure_ascii=False,indent=2)+'\n','utf8')
        evidence={'sources':[{'path':p,'sha256':hashlib.sha256((original/p).read_bytes()).hexdigest()} for p in [source,material]],'glow_frames':len(images(out/'parts','#57')),'fps':30,'portrait_position':[270,280],'portrait_outer_scale':0.5,'glow_registration':[165,158.35],'uid_open_seconds':0.5,'uid_close_seconds':0.2,'scope':'Backpack presentation; wardrobe module remains a separate plugin signal.'}
        (ROOT/'assets/ui/original/inventory_details_source.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n','utf8')
    author()
    print('Authored original portrait/glow/UID/fashion switch, item comparisons, resistance hover and context skins; no tests run')

if __name__=='__main__':main()
#endregion
