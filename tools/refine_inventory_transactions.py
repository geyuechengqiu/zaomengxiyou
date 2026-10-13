"""Author original sale UI and C# controller; preserve unrelated inventory scene nodes."""
from pathlib import Path
import re, shutil, json, argparse, subprocess
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'.cleanup-backup/inventory-export'
ASSETS=ROOT/'assets/ui/original'
parser=argparse.ArgumentParser()
parser.add_argument('--original-root',type=Path,help='Read-only original assets; omit to use cached exports')
args=parser.parse_args()
if args.original_root:
    source=args.original_root.resolve()
    for module,symbols,clean in [('material','sellCountPanel,addRemoveNum',True),('material','check_box,#144,#147,#513,#514',False),('backpack','#94',False)]:
        swf=next((source/'games/zmhj-g5/cache/assets/module').glob(module+'_*.swf'))
        result=subprocess.run(['java','-Djava.awt.headless=true','-Dfile.encoding=UTF-8','-cp',str(source/'out/swfutil/ffdec_lib_20.1.0/*'),str(ROOT/'tools/ExportOriginalBattleUI.java'),str(swf),str(OUT),symbols]+(['clean'] if clean else []),capture_output=True,encoding='utf8',check=True)
        OUT.mkdir(parents=True,exist_ok=True); (OUT/(module+('-clean' if clean else '-parts')+'.txt')).write_text(result.stdout,'utf8')
def copy(symbol,name,frame=0):
    files=sorted((OUT/symbol.replace('#','id-')).rglob('*.png'),key=lambda p:int(p.stem))
    shutil.copyfile(files[frame],ASSETS/(name+'.png'))
copy('sellCountPanel','item_sell_panel')
copy('addRemoveNum','item_sell_number')
for f in range(2):copy('check_box','item_sell_check_'+str(f),f)
for symbol,name in [('#144','item_sell_yes'),('#147','item_sell_no'),('#94','bag_title'),('#513','item_sell_less'),('#514','item_sell_more')]:
    for f in range(3):copy(symbol,name+'_'+str(f),f)
p=ROOT/'data/ui/inventory.tscn';text=p.read_text('utf8')
roots=['Confirm','BatchSell','PowerTooltip','TitleButton','TitleNotice','PresentationController']
for name in roots:
    text=re.sub(r'\[node[^\n]*(?:name="'+name+r'"[^\n]*parent="\."|parent="'+name+r'(?:/[^"]*)?")[^\n]*\]\n.*?(?=\n\[|\Z)','',text,flags=re.S)
text=re.sub(r'\[ext_resource[^\n]*id="transaction_[^"]+"\]\n','',text)
text=re.sub(r'\[sub_resource[^\n]*id="transaction_[^"]+"\]\n.*?(?=\n\[|\Z)','',text,flags=re.S)
resources=[]
def resource(name,path,kind='Texture2D'):
    resources.append(f'[ext_resource type="{kind}" path="res://{path}" id="transaction_{name}"]\n')
    return f'ExtResource("transaction_{name}")'
font='ExtResource("R1")'
bg=resource('panel','assets/ui/original/item_sell_panel.png')
number_bar=resource('number_bar','assets/ui/original/item_sell_number.png')
slot=resource('slot','assets/ui/original/slot_1.png')
tips='ExtResource("detail_tips")'
script=resource('controller','addons/battle_foundation/ui/InventoryPresentationController.cs','Script')
gray=resource('disabled_shader','assets/ui/shaders/quantity_disabled.gdshader','Shader')
materials=''
for name in ['Less','More']:
    materials+=f'[sub_resource type="ShaderMaterial" id="transaction_{name}"]\nresource_local_to_scene = true\nshader = {gray}\nshader_parameter/is_disabled = true\n'
check_icons=[resource('check'+str(f),'assets/ui/original/item_sell_check_'+str(f)+'.png') for f in range(2)]
buttons={}
for name in ['item_sell_yes','item_sell_no','bag_title','item_sell_less','item_sell_more']:
    buttons[name]=[resource(name+str(i),'assets/ui/original/'+name+'_'+str(i)+'.png') for i in range(3)]
buttons['bag_sell_all']=[resource('sell_all'+str(i),'assets/ui/original/button_'+str(i)+'.png') for i in range(3)]
def node(name,kind,parent,rect,props='',mouse=2):
    x,y,w,h=rect
    return f'[node name="{name}" type="{kind}" parent="{parent}"]\noffset_left = {x}\noffset_top = {y}\noffset_right = {x+w}\noffset_bottom = {y+h}\nmouse_filter = {mouse}\n'+props+'\n'
def label(name,parent,rect,value='',size=16,extra=''):
    return node(name,'Label',parent,rect,f'theme_override_fonts/font = {font}\ntheme_override_font_sizes/font_size = {size}\ntheme_override_colors/font_color = Color(0.372549,0.117647,0.019608,1)\ntext = {json.dumps(value,ensure_ascii=False)}\n'+extra)
def image(name,parent,rect,texture):
    return node(name,'TextureRect',parent,rect,f'texture = {texture}\nexpand_mode = 1\n')
def button(name,parent,rect,asset):
    return node(name,'TextureButton',parent,rect,'focus_mode = 0\n'+''.join(f'texture_{state} = {ref}\n' for state,ref in zip(['normal','hover','pressed'],buttons[asset])),0)
nodes=node('Confirm','Control','.',(0,0,940,590),'visible = false\nz_index = 40\n',0)
nodes+=node('Shade','ColorRect','Confirm',(0,0,940,590),'color = Color(0,0,0,0.25)\n',0)
nodes+=image('Background','Confirm',(0,0,940,590),bg)
nodes+=label('Title','Confirm',(340,149,260,27),'',20,'visible = false\nhorizontal_alignment = 1\n')
nodes+=node('Text','RichTextLabel','Confirm',(207,202,518,43),'bbcode_enabled = true\nscroll_active = false\ntheme_override_fonts/normal_font = ExtResource("R1")\ntheme_override_font_sizes/normal_font_size = 20\ntheme_override_colors/default_color = Color(0.372549,0.117647,0.019608,1)\n')
nodes+=image('Slot','Confirm',(433,250,58,58),slot)
nodes+=node('Icon','TextureRect','Confirm',(437,254,50,50),'expand_mode = 1\nstretch_mode = 5\n')
nodes+=image('NumberBar','Confirm',(394.55,336,127.3,25),number_bar)
nodes+=node('Count','LineEdit','Confirm',(472,337,44,23),'text = "1"\nalignment = 0\nmax_length = 9\nselect_all_on_focus = true\ntheme_override_styles/normal = SubResource("NicknameInput")\ntheme_override_styles/focus = SubResource("NicknameInput")\ntheme_override_fonts/font = ExtResource("R1")\ntheme_override_font_sizes/font_size = 16\ntheme_override_colors/font_color = Color(0.372549,0.117647,0.019608,1)\n',0)
nodes+=button('Less','Confirm',(440,336,24,24),'item_sell_less')
nodes+='material = SubResource("transaction_Less")\n'
nodes+=button('More','Confirm',(524.75,336,24,24),'item_sell_more')
nodes+='material = SubResource("transaction_More")\n'
nodes+=button('Yes','Confirm',(340.15,389.6,100,36),'item_sell_yes')
nodes+=button('No','Confirm',(485.35,389.6,100,36),'item_sell_no')
nodes+=node('BatchSell','Control','.',(0,0,940,590),'visible = false\nz_index = 40\n',0)
nodes+=node('Shade','ColorRect','BatchSell',(0,0,940,590),'color = Color(0,0,0,0.25)\n',0)
nodes+=image('Background','BatchSell',(0,0,940,590),bg)
nodes+=label('Description','BatchSell',(230,189,480,28),'请选择要出售的装备品质（可多选）',18,'horizontal_alignment = 1\n')
nodes+=node('Qualities','Control','BatchSell',(230,222,480,68))
names=['普通','优秀','精良','史诗','传说','神器','上古','圣器','邪灵','深渊']
colors=[f'#{c:06x}' for c in [16777215,65280,1991679,12320978,16187136,15335424,16741120,15944573,6579300,9830412]]
for i,name in enumerate(names):
    c=int(colors[i][1:],16); color=f'Color({(c>>16)/255},{((c>>8)&255)/255},{(c&255)/255},1)'
    nodes+=node('Q'+str(i),'CheckBox','BatchSell/Qualities',(i%5*94,i//5*33,94,32),f'text = "{name}"\nfocus_mode = 0\nflat = true\ntheme_override_icons/unchecked = {check_icons[0]}\ntheme_override_icons/checked = {check_icons[1]}\ntheme_override_fonts/font = ExtResource("R1")\ntheme_override_font_sizes/font_size = 14\ntheme_override_colors/font_color = {color}\ntheme_override_colors/font_outline_color = Color(0.2,0.1,0.05,1)\ntheme_override_constants/outline_size = 2\n',0)
nodes+=label('Summary','BatchSell',(240,298,460,80),'',16,'horizontal_alignment = 1\n')
nodes+=button('Yes','BatchSell',(340.15,389.6,100,36),'item_sell_yes')
nodes+=button('No','BatchSell',(485.35,389.6,100,36),'item_sell_no')
nodes+=node('PowerTooltip','Control','.',(0,0,375,98),'visible = false\nz_index = 26\n')
nodes+=node('Background','NinePatchRect','PowerTooltip',(0,0,375,98),f'texture = {tips}\npatch_margin_left = 45\npatch_margin_top = 30\npatch_margin_right = 29\npatch_margin_bottom = 29\n')
nodes+=label('Text','PowerTooltip',(12,10,353,80),'',14)
nodes+=button('TitleButton','.',(314.75,122,26,26),'bag_title')
nodes+=node('TitleNotice','Control','.',(0,0,940,590),'visible = false\nz_index = 40\n',0)
nodes+=node('Shade','ColorRect','TitleNotice',(0,0,940,590),'color = Color(0,0,0,0.25)\n',0)
nodes+=node('Background','NinePatchRect','TitleNotice',(275,205,390,170),f'texture = {tips}\npatch_margin_left = 45\npatch_margin_top = 30\npatch_margin_right = 29\npatch_margin_bottom = 29\n')
nodes+=label('Text','TitleNotice',(305,230,330,75),'称号\n称号入口已预留，暂未开放',18,'horizontal_alignment = 1\n')
nodes+=button('OK','TitleNotice',(420,320,100,36),'item_sell_yes')
nodes+=f'[node name="PresentationController" type="Node" parent="."]\nscript = {script}\n'
# Replace sorting button with the source button, preserving its public node path.
text=re.sub(r'\[node name="Caption"[^\n]*parent="Sort"[^\n]*\]\n.*?(?=\n\[|\Z)','',text,flags=re.S)
text=re.sub(r'\[node name="Sort"[^\n]*\]\n.*?(?=\n\[|\Z)',button('Sort','.',(699.6,478,102.3,36),'bag_sell_all').rstrip(),text,flags=re.S)
nodes+=label('Caption','Sort',(0,2,102.3,32),'一键出售',17,'horizontal_alignment = 1\nvertical_alignment = 1\n')
pos=text.index('[sub_resource') if '[sub_resource' in text else text.index('[node')
text=text[:pos]+''.join(resources)+materials+text[pos:]+nodes
p.write_text(text.rstrip()+'\n','utf8')
print('Authored original transactions and identity/title/power nodes')
