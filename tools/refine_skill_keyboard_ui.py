"""Author original keyboardSet/PropMessage/TipsManager presentation in skills.tscn."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def author():
    path = ROOT/'data/ui/skills.tscn'
    text = path.read_text('utf8')
    refs = []
    def resource(name, asset):
        asset = 'res://assets/ui/original/'+asset
        found = re.search(r'\[ext_resource type="Texture2D" path="'+re.escape(asset)+r'" id="([^"]+)"\]', text)
        key = found[1] if found else 'keyboard_detail_'+name
        if not found:
            refs.append(f'[ext_resource type="Texture2D" path="{asset}" id="{key}"]\n')
        return f'ExtResource("{key}")'
    slot = resource('slot', 'slot_0.png')
    pages = [resource('page'+str(i), 'bag_page_'+str(i)+'.png') for i in range(3)]
    tip = resource('tip', 'tips_background.png')
    blocks = re.split(r'(?=\[node )',text)
    out = [blocks[0]]
    for block in blocks[1:]:
        header = re.match(r'\[node name="([^"]+)" type="([^"]+)" parent="([^"]+)"\]',block)
        if not header:
            out.append(block); continue
        name, kind, parent = header.groups()
        if (name == 'Level' and re.fullmatch(r'Keyboard/Stock\d+',parent)) or (parent=='Keyboard' and name in ('Prev','Next','Page','Pages')) or parent.startswith('Keyboard/Pages'):
            continue
        if parent=='Tooltip':
            continue
        if parent=='Keyboard' and name=='Tip':
            block = '[node name="Tip" type="Label" parent="Keyboard"]\noffset_left = 93.0\noffset_top = 533.0\noffset_right = 847.0\noffset_bottom = 558.0\nmouse_filter = 2\ntheme_override_fonts/font = ExtResource("R1")\ntheme_override_font_sizes/font_size = 18\ntheme_override_colors/font_color = Color(0.372549,0.117647,0.019608,1)\ntext = "拖动技能或道具图标可携带至副本使用；每次可携带1种妖王助阵"\n'
        if re.fullmatch(r'Keyboard/Item\d+',parent):
            if name=='Background':
                block=re.sub(r'texture = [^\n]+','texture = '+slot,block)
            elif name=='Count':
                block=re.sub(r'offset_left = [^\n]+','offset_left = 0.0',block)
                block=re.sub(r'offset_top = [^\n]+','offset_top = 35.0',block)
                block=re.sub(r'offset_right = [^\n]+','offset_right = 50.0',block)
                block=re.sub(r'offset_bottom = [^\n]+','offset_bottom = 54.0',block)
                block=re.sub(r'font_size = \d+','font_size = 14',block)
                block=re.sub(r'^horizontal_alignment = .*\n','',block,flags=re.M)
                block+='horizontal_alignment = 2\n'
        if parent=='.' and name=='Tooltip':
            block=re.sub(r'offset_right = [^\n]+','offset_right = 290.0',block)
            block=re.sub(r'offset_bottom = [^\n]+','offset_bottom = 90.0',block)
            block=re.sub(r'theme_override_styles/panel = [^\n]+','theme_override_styles/panel = SubResource("SkillTooltipStyle")',block)
        out.append(block.rstrip()+'\n\n')
    text=''.join(out)
    text=re.sub(r'\[sub_resource type="StyleBoxTexture" id="SkillTooltipStyle"\]\n.*?(?=\[)', '',text,flags=re.S)
    style=f'[sub_resource type="StyleBoxTexture" id="SkillTooltipStyle"]\ntexture = {tip}\ntexture_margin_left = 25.0\ntexture_margin_top = 20.0\ntexture_margin_right = 25.0\ntexture_margin_bottom = 20.0\n\n'
    text=text.replace('[node name="SkillPanel"',style+'[node name="SkillPanel"',1)
    text=text.replace('[sub_resource ',''.join(refs)+'[sub_resource ',1)
    text+='[node name="Pages" type="Control" parent="Keyboard"]\nvisible = false\noffset_left = 580.0\noffset_top = 360.0\noffset_right = 830.0\noffset_bottom = 392.0\nmouse_filter = 2\n\n'
    for i in range(5):
        text+=f'[node name="Page{i}" type="TextureButton" parent="Keyboard/Pages"]\nvisible = false\noffset_right = 32.0\noffset_bottom = 32.0\nfocus_mode = 0\nignore_texture_size = true\nstretch_mode = 0\ntexture_normal = {pages[0]}\ntexture_hover = {pages[1]}\ntexture_pressed = {pages[2]}\n\n'
        text+=f'[node name="Text" type="Label" parent="Keyboard/Pages/Page{i}"]\noffset_top = 4.0\noffset_right = 32.0\noffset_bottom = 26.0\nmouse_filter = 2\ntheme_override_fonts/font = ExtResource("R1")\ntheme_override_font_sizes/font_size = 16\ntheme_override_colors/font_color = Color(0.372549,0.117647,0.019608,1)\nhorizontal_alignment = 1\ntext = "{i+1}"\n\n'
    for name,x,y,w,h,size,color in [('Name',20,15,250,26,18,'0,0,0,1'),('Stats',20,45,260,75,16,'0.372549,0.117647,0.019608,1'),('Text',20,50,260,20,16,'0.372549,0.117647,0.019608,1')]:
        text+=f'[node name="{name}" type="Label" parent="Tooltip"]\noffset_left = {float(x)}\noffset_top = {float(y)}\noffset_right = {float(x+w)}\noffset_bottom = {float(y+h)}\nmouse_filter = 2\ntheme_override_fonts/font = ExtResource("R1")\ntheme_override_font_sizes/font_size = {size}\ntheme_override_colors/font_color = Color({color})\ntext = ""\nautowrap_mode = 2\ntheme_override_constants/line_spacing = 4\n\n'
    path.write_text(text.rstrip()+'\n', 'utf8')

if __name__=='__main__':
    author()
    print('Authored original keyboard item grids, tab/page states, footer and skill tooltips')
