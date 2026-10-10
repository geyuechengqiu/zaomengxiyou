"""Refine authored bag controls using exported original font and button skins."""
from pathlib import Path
import json, re, shutil, struct
ROOT=Path(__file__).resolve().parents[1]

#region Saved scene patches; repeatable after the base UI scene generator
def refine():
    assets=ROOT/'assets/ui/original'
    font_source=ROOT/'.cleanup-backup/bag-fonts/font_1.ttf'
    if font_source.exists(): shutil.copyfile(font_source, assets/'ui_font.ttf')
    body_source=next((ROOT/'.cleanup-backup/bag-body-clean/bodyPanel').rglob('*.png'),None)
    if body_source: shutil.copyfile(body_source,assets/'body_panel_clean.png')
    textures={}
    for symbol,output in [('id-312','close'),('id-147','wardrobe'),('button_num_bg','page'),('btn_prev','previous'),('btn_next','next')]:
        files=sorted((ROOT/'.cleanup-backup/bag-controls'/symbol).rglob('*.png'),key=lambda p:int(p.stem))
        for index in range(3):
            name=f'bag_{output}_{index}.png'
            if files: shutil.copyfile(files[index],assets/name)
            if not (assets/name).exists(): raise FileNotFoundError(assets/name)
            textures[(output,index)]=name
    path=ROOT/'data/ui/inventory.tscn'
    text=path.read_text('utf8')
    # Remove only nodes/resources authored by this refinement, enabling safe repeats.
    text=re.sub(r'\[ext_resource[^\n]*id="(?:bag_(?:close|wardrobe|previous|next)_\d|page_skin_\d|body_clean|experience_fill|exp_bg|fight_display|fight_digit_\d)"\]\n','',text)
    text=re.sub(r'\[node name="(?:ExperienceBackground|ExperienceFill|RoleName|PageButtons|FightPower)"[^\n]*\]\n.*?(?=\n\[|\Z)','',text,flags=re.S)
    text=re.sub(r'\[node[^\n]*parent="PageButtons(?:/Page\d)?"[^\n]*\]\n.*?(?=\n\[|\Z)','',text,flags=re.S)
    text=re.sub(r'^page_textures = .*\n','',text,flags=re.M)
    text=re.sub(r'^theme_override_colors/font_(?:color|hover_color|pressed_color) = Color\(0.372549,0.117647,0.019608,1\)\n','',text,flags=re.M)
    text=text.replace('res://addons/simple_inventory/assets/fonts/SourceHanSansSC-Regular-2.otf','res://assets/ui/original/ui_font.ttf')
    additions=[]
    def resource(name,filename):
        additions.append(f'[ext_resource type="Texture2D" path="res://assets/ui/original/{filename}" id="{name}"]\n')
        return f'ExtResource("{name}")'
    def node(name,parent='.'):
        return re.search(r'\[node name="'+name+r'"[^\n]* parent="'+re.escape(parent)+r'"[^\n]*\]\n.*?(?=\n\[|\Z)',text,re.S)
    def replace_node(name,block,parent='.'):
        nonlocal text
        match=node(name,parent)
        if not match: raise ValueError(f'Missing {parent}/{name}')
        text=text[:match.start()]+block.rstrip()+'\n'+text[match.end():]
    def properties(name,values,parent='.'):
        match=node(name,parent);block=match.group(0)
        for key,value in values.items():
            line=f'{key} = {value}'
            if re.search(r'^'+re.escape(key)+r' = ',block,re.M):
                block=re.sub(r'^'+re.escape(key)+r' = .*$',lambda m:line,block,flags=re.M)
            else: block+='\n'+line+'\n'
        replace_node(name,block,parent)
    def button(name,x,y,w,h,kind):
        refs=[resource(f'bag_{kind}_{i}',textures[(kind,i)]) for i in range(3)]
        replace_node(name,f'''[node name="{name}" type="TextureButton" parent="."]
offset_left = {x}
offset_top = {y}
offset_right = {x+w}
offset_bottom = {y+h}
focus_mode = 0
texture_normal = {refs[0]}
texture_hover = {refs[1]}
texture_pressed = {refs[2]}
''')
    button('Close',799.2,28.5,33,38,'close')
    button('Wardrobe',415.75,113,43,46,'wardrobe')
    button('Previous',500,443,24,30,'previous')
    button('Next',808,443,24,30,'next')
    # Resist text and rounded brown button are already present in bodyPanel.
    replace_node('ResistanceButton','''[node name="ResistanceButton" type="Button" parent="."]
offset_left = 415.75
offset_top = 501.8
offset_right = 459.75
offset_bottom = 523.8
flat = true
focus_mode = 0
''')
    properties('BodyPanel',{'texture':resource('body_clean','body_panel_clean.png'),'offset_left':'128.95','offset_top':'77.6','offset_right':'478.95','offset_bottom':'527.6'})
    properties('Level',{'text':'"Lv.1"','offset_left':'129','offset_top':'299','offset_right':'186','offset_bottom':'327'})
    properties('Page',{'visible':'false'})
    properties('Capacity',{'visible':'false'})
    # Flash TextAttrManager: centered 111px cells, x178/x347, y334 + row*27.
    for index in range(12):
        x=178+(index%2)*169;y=334+(index//2)*27
        properties(f'Value{index}',{'offset_left':str(x),'offset_top':str(y),'offset_right':str(x+111),'offset_bottom':str(y+20),'horizontal_alignment':'1'},'Attributes')
    for index in range(6):
        properties('Part',{'offset_left':'12','offset_top':'19','offset_right':'48','offset_bottom':'41','theme_override_font_sizes/font_size':'14','theme_override_colors/font_color':'Color(0.894,0.808,0.753,1)'},f'Equipment/Part{index}')
    # Labels and popup text use the original common color, not white default button text.
    text=re.sub(r'(\[node [^\n]*type="Button"[^\n]*\]\n)',r'\1theme_override_colors/font_color = Color(0.372549,0.117647,0.019608,1)\ntheme_override_colors/font_hover_color = Color(0.372549,0.117647,0.019608,1)\ntheme_override_colors/font_pressed_color = Color(0.372549,0.117647,0.019608,1)\n',text)
    page_refs=[resource(f'page_skin_{i}',textures[('page',i)]) for i in range(3)]
    root_match=re.search(r'(\[node name="Inventory"[^\n]*\]\n)',text)
    text=text[:root_match.end()]+f'page_textures = Array[Texture2D]([{", ".join(page_refs)}])\n'+text[root_match.end():]
    font_id=re.search(r'\[ext_resource type="FontFile"[^\n]*id="([^"]+)"',text).group(1)
    exp_ref=resource('experience_fill','exp_fill.png')
    exp_bg=resource('exp_bg','bag_experience_background.png')
    nodes=f'''[node name="ExperienceBackground" type="TextureRect" parent="."]
offset_left = 187.1
offset_top = 303.85
offset_right = 467.1
offset_bottom = 323.85
mouse_filter = 2
texture = {exp_bg}
[node name="ExperienceFill" type="TextureProgressBar" parent="."]
offset_left = 194.45
offset_top = 306.2
offset_right = 460.45
offset_bottom = 322.2
mouse_filter = 2
max_value = 1.0
step = 0.0
texture_progress = {exp_ref}
nine_patch_stretch = true
[node name="RoleName" type="Label" parent="."]
offset_left = 374.75
offset_top = 82.6
offset_right = 438.75
offset_bottom = 106.6
mouse_filter = 2
theme_override_fonts/font = ExtResource("{font_id}")
theme_override_font_sizes/font_size = 16
theme_override_colors/font_color = Color(1,0.86,0.63,1)
theme_override_colors/font_outline_color = Color(0.37,0.12,0.02,1)
theme_override_constants/outline_size = 2
horizontal_alignment = 1
text = "孙悟空"
[node name="PageButtons" type="Control" parent="."]
mouse_filter = 2
'''
    for index in range(8):
        nodes+=f'''[node name="Page{index}" type="TextureButton" parent="PageButtons"]
visible = false
focus_mode = 0
texture_normal = {page_refs[0]}
texture_hover = {page_refs[1]}
texture_pressed = {page_refs[2]}
[node name="Text" type="Label" parent="PageButtons/Page{index}"]
offset_top = 4.0
offset_right = 31.0
offset_bottom = 24.0
mouse_filter = 2
theme_override_fonts/font = ExtResource("{font_id}")
theme_override_font_sizes/font_size = 16
theme_override_colors/font_color = Color(0.372549,0.117647,0.019608,1)
horizontal_alignment = 1
text = "{index+1}"
'''
    # Keep fill above the body panel and below the live experience text.
    fill,rest=nodes.split('[node name="RoleName"',1)
    experience=node('Experience')
    text=text[:experience.start()]+fill+text[experience.start():]
    text+='[node name="RoleName"'+rest
    fight_script='ExtResource("fight_display")'
    additions.append('[ext_resource type="Script" path="res://addons/battle_foundation/ui/original_fight_power_display.gd" id="fight_display"]\n')
    digits=[resource(f'fight_digit_{i}',f'fight_digit_{i}.png') for i in range(10)]
    text+=f'\n[node name="FightPower" type="Control" parent="."]\noffset_left = 251.0\noffset_top = 499.0\noffset_right = 415.0\noffset_bottom = 527.0\nmouse_filter = 2\nscript = {fight_script}\ndigits = Array[Texture2D]([{", ".join(digits)}])\n'
    first_sub=text.index('[sub_resource')
    text=text[:first_sub]+''.join(additions)+text[first_sub:]
    path.write_text(text,'utf8')
    print('Authored original bag font, close/wardrobe skins, empty equipment labels, EXP and circular pages')
    # Preserve detailed dynamic overlays after rebuilding the base inventory UI.
    if (assets/'body_panel_static.png').exists():
        from refine_inventory_details import author
        author()
#endregion

if __name__=='__main__':refine()
