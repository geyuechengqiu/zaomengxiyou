"""Read-only original SWF export; authored modal barriers, map chrome and settings."""
from pathlib import Path
import re, shutil, subprocess, sys, json, hashlib
ROOT=Path(__file__).resolve().parents[1]
REF=Path('D:/UserData/Downloads/game/Speculum-4399-master')
sys.path.insert(0,str(ROOT/'.cleanup-backup/python-packages'))
CACHE=ROOT/'.cleanup-backup'
ASSETS=ROOT/'assets/ui/original/settings'
CHROME=ROOT/'assets/ui/original/world_map'

def export(source, folder, symbols, mode=''):
    command=['java','-Djava.awt.headless=true','-Dfile.encoding=UTF-8','-cp',str(REF/'out/swfutil/ffdec_lib_20.1.0/*'),str(ROOT/'tools/ExportOriginalBattleUI.java'),str(source),str(folder),symbols]
    if mode: command.append(mode)
    result=subprocess.run(command,capture_output=True,encoding='utf8',check=True)
    (folder.parent/(folder.name+'-parts.log')).write_text(result.stdout,encoding='utf8')

def placements(log, symbol):
    text=log.split('SYMBOL '+symbol+'\n',1)[1].split('RENDER_BOUNDS',1)[0]
    pattern=r'^ depth=\d+ name=(\S+) matrix=.*?translate:(-?\d+),(-?\d+).*?\n  id=(\d+).*?bounds=\[RECT x=(-?\d+) to (-?\d+), y=(-?\d+) to (-?\d+)\]'
    return {name:(int(cid),(int(x)+int(x0))/20,(int(y)+int(y0))/20,(int(x1)-int(x0))/20,(int(y1)-int(y0))/20) for name,x,y,cid,x0,x1,y0,y1 in re.findall(pattern,text,re.M)}

class Scene:
    def __init__(self): self.refs=[]; self.sub=[]; self.nodes=[]; self.ids={}
    def resource(self,kind,path):
        if path not in self.ids:
            i='r'+str(len(self.ids));self.ids[path]=i;self.refs.append(f'[ext_resource type="{kind}" path="{path}" id="{i}"]\n')
        return f'ExtResource("{self.ids[path]}")'
    def node(self,name,kind,parent,box=None,extra='',root=False):
        t=f'[node name="{name}" type="{kind}"'+('' if root else f' parent="{parent}"')+']\n'
        if box:
            x,y,w,h=box;t+=f'offset_left = {x}\noffset_top = {y}\noffset_right = {x+w}\noffset_bottom = {y+h}\n'
        if kind in ('Control','TextureRect','Label'):t+='mouse_filter = 2\n'
        t+=extra+'\n';self.nodes.append(t)
    def image(self,name,parent,box,path):self.node(name,'TextureRect',parent,box,'texture = '+self.resource('Texture2D',path)+'\nexpand_mode = 1')
    def button(self,name,parent,box,paths,extra=''):
        props='focus_mode = 0\nignore_texture_size = true\nstretch_mode = 0\n'
        for state,path in zip(('normal','hover','pressed'),paths):props+=f'texture_{state} = {self.resource("Texture2D",path)}\n'
        self.node(name,'TextureButton',parent,box,props+extra)
    def modal(self,name,parent,extra=''):
        self.node(name,'Control',parent,(0,0,940,590),'visible = false\nmetadata/ui_modal = true\n'+extra)
        self.node('InputBarrier','Control',name if parent=='.' else parent+'/'+name,(0,0,940,590),'mouse_filter = 0')
    def label(self,name,parent,box,text,size=16,extra=''):
        self.node(name,'Label',parent,box,'text = '+json.dumps(text,ensure_ascii=False)+f'\ntheme_override_font_sizes/font_size = {size}\n'+extra)
    def write(self,path):path.write_text('[gd_scene format=3]\n'+''.join(self.refs)+''.join(self.sub)+''.join(self.nodes),encoding='utf8')

def copy_frames(folder,symbol,target,name,start=0):
    files=sorted((folder/symbol.replace('#','id-')).rglob('*.png'),key=lambda p:int(p.stem))
    target.mkdir(parents=True,exist_ok=True)
    paths=[]
    for i,p in enumerate(files[start:start+3]):
        dest=target/f'{name}_{i}.png';shutil.copyfile(p,dest);paths.append('res://'+dest.relative_to(ROOT).as_posix())
    return paths or []

def settings():
    src=REF/'games/zmhj-g5/cache/assets/module/systemSet_20260413_1.swf'
    parts=placements((CACHE/'settings-layout.log').read_text('utf8'),'mainPanel')
    symbols=','.join('#'+str(v[0]) for v in parts.values())+',#36,#39,#31,#10,#114,#118,#121,#124,#127,#130,#133,#143,#52,#55,#57,#66,#73,#77,#91,showSet,moreSet'
    export(src,CACHE/'settings-parts',symbols)
    s=Scene(); theme=s.resource('Theme','res://data/ui/campaign_theme.tres');script=s.resource('Script','res://addons/battle_foundation/ui/OriginalSettingsPanel.cs')
    s.node('OperationMenu','Control','.',(0,0,940,590),f'visible = false\nprocess_mode = 3\nscript = {script}\ntheme = {theme}\nmetadata/ui_modal = true',True)
    s.node('InputBarrier','Control','.',(0,0,940,590),'mouse_filter = 0')
    s.node('Shade','ColorRect','.',(0,0,940,590),'mouse_filter = 2\ncolor = Color(0,0,0,0.25)')
    s.sub.append('[sub_resource type="StyleBoxEmpty" id="Empty"]\n')
    for page,symbol in [('Main','mainPanel'),('Sound','soundSet'),('Display','showSet'),('More','moreSet')]:
        s.node(page,'Control','.',(0,0,940,590),'visible = '+('true' if page=='Main' else 'false'))
        folder=CACHE/'settings-export' if page in ('Main','Sound') else CACHE/'settings-parts'
        if page not in ('More','Display'):s.image('Background',page,(0,0,940,590),copy_frames(folder,symbol,ASSETS,page.lower())[0])
        elif page=='Display':
            bg=copy_frames(CACHE/'settings-parts','#52',ASSETS,'display_frame')[0]
            s.node('Background','NinePatchRect','Display',(303.85,60,359,455),'mouse_filter = 2\ntexture = '+s.resource('Texture2D',bg)+'\npatch_margin_left = 50\npatch_margin_right = 50\npatch_margin_top = 60\npatch_margin_bottom = 35')
            s.image('Title','Display',(356.85,76.5,253,32),copy_frames(CACHE/'settings-parts','#55',ASSETS,'display_title')[0])
        else:
            bg=copy_frames(CACHE/'settings-parts','#114',ASSETS,'more_frame')[0]
            s.node('Background','NinePatchRect','More',(290.5,8,359,574),'mouse_filter = 2\ntexture = '+s.resource('Texture2D',bg)+'\npatch_margin_left = 50\npatch_margin_right = 50\npatch_margin_top = 70\npatch_margin_bottom = 40')
    names={'btn_close':'Close','btn_jxyx':'Resume','btn_zctz':'Retry','btn_fhdt':'Map','btn_sysz':'Sound','btn_xxsz':'More','btn_xssz':'Display','btn_yxbz':'Help','btn_fhzcd':'Home'}
    for original,name in names.items():
        cid,x,y,w,h=parts[original];s.button(name,'Main',(x,y,w,h),copy_frames(CACHE/'settings-parts','#'+str(cid),ASSETS,'button_'+name.lower()))
    close=copy_frames(CACHE/'settings-parts','#22',ASSETS,'close')
    for page,box in [('Sound',(654.4,128.75,33,38)),('Display',(612.05,64.2,33,38)),('More',(618,10,33,38))]:s.button('Close',page,box,close)
    # Original slider track and circular thumb; source sound rows at y=280/340/399.
    track=copy_frames(CACHE/'settings-parts','#36',ASSETS,'slider_track')[0]
    knob=copy_frames(CACHE/'settings-parts','#39',ASSETS,'slider_knob')[0]
    s.sub.extend([f'[sub_resource type="StyleBoxTexture" id="SliderTrack"]\ntexture = {s.resource("Texture2D",track)}\ncontent_margin_top = 7.0\ncontent_margin_bottom = 7.0\ntexture_margin_left = 7.0\ntexture_margin_right = 7.0\n',f'[sub_resource type="StyleBoxTexture" id="SliderFill"]\ntexture = {s.resource("Texture2D",track)}\ncontent_margin_top = 7.0\ncontent_margin_bottom = 7.0\ntexture_margin_left = 7.0\ntexture_margin_right = 7.0\nmodulate_color = Color(0.25,0.75,0.78,1)\n'])
    checks=[f'res://assets/ui/original/item_sell_check_{i}.png' for i in range(2)]
    s.button('MasterMute','Sound',(419.15,205.05,24,24),(checks[0],checks[0],checks[1]),'toggle_mode = true')
    for name,y in [('Hit',279.75),('Skill',340),('Music',398.85)]:
        s.node(name,'Control','Sound',(0,0,940,590))
        s.node('Volume','HSlider','Sound/'+name,(419,y-12,196,24),'max_value = 100.0\nvalue = 100.0\nstep = 1.0\nfocus_mode = 0\ntheme_override_styles/slider = SubResource("SliderTrack")\ntheme_override_styles/grabber_area = SubResource("SliderFill")\ntheme_override_styles/grabber_area_highlight = SubResource("SliderFill")\ntheme_override_icons/grabber = '+s.resource('Texture2D',knob)+'\ntheme_override_icons/grabber_highlight = '+s.resource('Texture2D',knob))
        s.button('Mute','Sound/'+name,(624,y-12,24,24),(checks[0],checks[0],checks[1]),'toggle_mode = true\ntooltip_text = "静音"')
        s.label('Value','Sound/'+name,(595,y+10,48,18),'100%',12,'visible = false')
    # Existing independent master/SFX API remains available to legacy integrations.
    s.node('Margin','Control','.',None,'visible = false');s.node('Panel','Control','Margin');s.node('Column','Control','Margin/Panel')
    s.nodes.append('[node name="AudioSettings" parent="Margin/Panel/Column" instance='+s.resource('PackedScene','res://addons/battle_foundation/audio/battle_audio_settings.tscn')+']\n')
    s.node('Options','ScrollContainer','More',(337.5,61,283,476),'horizontal_scroll_mode = 0')
    s.node('Content','Control','More/Options',None,'custom_minimum_size = Vector2(265,572)')
    for i,(feature,cid) in enumerate([('pause',118),('quality',121),('fireworks',124),('pickup',130),('news',127),('emoji',133)]):
        s.image('Row'+str(i),'More/Options/Content',(0,i*95.4,265,94),copy_frames(CACHE/'settings-parts','#'+str(cid),ASSETS,'more_'+feature)[0])
        for j in range(3 if feature=='quality' else 2):
            s.node('Option'+str(i)+'_'+str(j),'Button','More/Options/Content',(17+j*84,i*95.4+42,81,44),'metadata/feature = &"'+feature+'_'+str(j)+'"\nfocus_mode = 0\n'+''.join('theme_override_styles/'+state+' = SubResource("Empty")\n' for state in ['normal','hover','pressed','focus']))
    s.button('Password','More/Options/Content',(72,574,142,36),copy_frames(CACHE/'settings-parts','#143',ASSETS,'password'),'metadata/feature = &"password"')
    s.nodes=[x.replace('Vector2(265,572)','Vector2(265,620)') for x in s.nodes]
    s.node('Options','Control','Display',(0,0,940,590))
    s.image('PlayerCount','Display/Options',(353.85,126,259,51),copy_frames(CACHE/'settings-parts','#77',ASSETS,'display_count')[0])
    for name,cid,x in [('Less',66,500.7),('More',73,580.45)]:
        s.button(name,'Display/Options',(x,139.55,24,24),copy_frames(CACHE/'settings-parts','#'+str(cid),ASSETS,'display_'+name.lower()),'metadata/feature = &"players"')
    row=copy_frames(CACHE/'settings-parts','#57',ASSETS,'display_row')[0]
    toggle=copy_frames(CACHE/'settings-parts','#31',ASSETS,'display_toggle')
    for i,feature in enumerate(['teammates','disciples','friends','others','pvp','pets']):
        y=177+i*51
        s.image('Row'+str(i),'Display/Options',(353.85,y,259,51),row)
        label=copy_frames(CACHE/'settings-parts','#91',ASSETS,'display_'+feature,start=i+1)[0]
        s.image('Name'+str(i),'Display/Options',(362.85,y+14.95,132,22),label)
        s.button('Option'+str(i),'Display/Options',(503.55,y+16,79.25,25.15),toggle,'metadata/feature = &"'+feature+'"')
    s.modal('Notice','.')
    s.node('Panel','Panel','Notice',(300,200,340,170));s.label('Text','Notice/Panel',(20,22,300,55),'该功能暂未开放',18,'horizontal_alignment = 1')
    s.node('OK','Button','Notice',(425,310,90,32),'text = "确定"\nfocus_mode = 0')
    s.write(ROOT/'addons/battle_foundation/input/battle_operation_menu.tscn')

def modal_barriers():
    roots={ROOT/'data/ui/inventory.tscn':['.','Confirm','BatchSell','TitleNotice'],ROOT/'data/ui/skills.tscn':['.','Keyboard','Upgrade','Notice'],ROOT/'data/ui/battle_hud.tscn':['ModulePanel']}
    for path,targets in roots.items():
        t=path.read_text('utf8');blocks=re.split(r'(?=\[node )',t);out=[]
        for block in blocks:
            match=re.match(r'\[node name="([^"]+)"[^\n]*',block)
            if not match:out.append(block);continue
            head=match.group(0);name=match.group(1)
            root='parent=' not in head
            address='.' if root else name if 'parent="."' in head else None
            if address not in targets:out.append(block);continue
            if 'metadata/ui_modal' not in block:block=block.rstrip()+'\nmetadata/ui_modal = true\n'
            out.append(block)
            if f'parent="{address}"' in t and f'name="ModalBarrier" type="Control" parent="{address}"' in t:continue
            # Panel positions stay unchanged; barrier covers the viewport outside them.
            def value(field):
                m=re.search(r'^'+field+r' = ([\d.-]+)',block,re.M);return float(m.group(1)) if m else 0
            x,y=(-value('offset_left'),-value('offset_top')) if address=='ModulePanel' else (0,0)
            out.append(f'[node name="ModalBarrier" type="Control" parent="{address}"]\noffset_left = {x}\noffset_top = {y}\noffset_right = {x+940}\noffset_bottom = {y+590}\nmouse_filter = 0\n')
        path.write_text(''.join(out).rstrip()+'\n',encoding='utf8')

def attributes():
    for id,label,value,unit in [('attackSpeed','攻击速度',1,'倍率'),('baseRunSpeed','基础奔跑速度',600,'场景单位/秒')]:
        (ROOT/f'data/attribute/{id}.tres').write_text(f'[gd_resource type="Resource" script_class="GameplayAttribute" format=3]\n[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/attributes/gameplay_attribute.gd" id="script"]\n[resource]\nscript = ExtResource("script")\nattribute_id = &"{id}"\nattribute_display_name = "{label}"\nmin_value = 0.05\nmetadata/category = "movement"\nmetadata/unit = "{unit}"\n',encoding='utf8')
        path=ROOT/'data/characters/sunwukong/attributes/base.tres';t=path.read_text('utf8')
        if 'id="'+id+'"' not in t:t=t.replace('[resource]',f'[ext_resource type="Resource" path="res://data/attribute/{id}.tres" id="{id}"]\n[resource]').replace('attributes = {','attributes = {\nExtResource("'+id+f'"): {float(value)},')
        path.write_text(t,encoding='utf8')
        path=ROOT/'data/characters/sunwukong/character.tscn';t=path.read_text('utf8')
        if '&"'+id+'"' not in t:t=t.replace('base_values = Dictionary[StringName, float]({','base_values = Dictionary[StringName, float]({\n&"'+id+f'": {float(value)},')
        path.write_text(t,encoding='utf8')

def world():
    parts=placements((CACHE/'world-tool-layout.log').read_text('utf8'),'mainPanel')
    keep=['btn_sc','btn_bb','btn_jn','btn_xf','btn_qh','btn_rw','btn_fb','btn_lc','btn_cb','fairy','formations','halo','createTeam','btn_zc','btn_sz','btn_yj','btn_qz','btn_sj','btn_vip']
    src=REF/'games/zmhj-g5/cache/assets/module/toolScene_20260921_1.swf'
    export(src,CACHE/'world-chrome-parts',','.join('#'+str(parts[k][0]) for k in keep)+',#1039')
    CHROME.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(CACHE/'world-chrome-parts/id-1039/1039.png',CHROME/'world_name_frame.png')
    t=(ROOT/'game/world_map/zaomeng1_world_map.tscn').read_text('utf8')
    # Remove old status/progress text and auxiliary chapter/back entries.
    blocks=re.split(r'(?=\[node )',t);blocks=[b for b in blocks if not re.match(r'\[node name="(State|Progress|Biyujing|Back|Chrome|CharacterSession|HUD|Settings|Notice|Glow|MapNameFrame|MapName)"',b) and not re.search(r'parent="(?:Chrome|CharacterSession|Notice)(?:/[^\"]*)?"',b)]
    t=''.join(blocks)
    t=re.sub(r'^metadata/latest_texture = .*\n','',t,flags=re.M)
    t=re.sub(r'^\[ext_resource .*id="(?:s\d_\d_2|back\d|selection)"\]\n','',t,flags=re.M)
    t=re.sub(r'^\[ext_resource .*id="(?:r\d+|glow_shader|world_name_frame)"\]\n','',t,flags=re.M)
    t=re.sub(r'\[sub_resource type="ShaderMaterial" id="Glow_[^\"]+"\]\n.*?(?=\[)', '', t,flags=re.S)
    t=re.sub(r'\[sub_resource type="StyleBoxFlat" id="CurrentMapFrame"\]\n.*?(?=\[)', '', t,flags=re.S)
    s=Scene();s.refs.append('[ext_resource type="Shader" path="res://assets/ui/shaders/map_icon_glow.gdshader" id="glow_shader"]\n')
    s.node('MapNameFrame','NinePatchRect','.',(747.65,.35,192,90),'mouse_filter = 2\ntexture = '+s.resource('Texture2D','res://assets/ui/original/world_map/world_name_frame.png')+'\npatch_margin_left = 12\npatch_margin_right = 75')
    s.label('MapName','.',(753,0,185,23),'东胜神洲（七魔王）',14,'horizontal_alignment = 1\nvertical_alignment = 1\ntheme_override_colors/font_color = Color(1,0.96,0.76,1)\ntheme_override_colors/font_outline_color = Color(0.13,0.26,0.22,1)\ntheme_override_constants/outline_size = 1')
    s.node('Chrome','Control','.',(0,0,940,590))
    for k in keep:
        cid,x,y,w,h=parts[k];s.button(k,'Chrome',(x,y,w,h),copy_frames(CACHE/'world-chrome-parts','#'+str(cid),CHROME,k,3 if k=='btn_zc' else 0),'metadata/feature = &"'+k+'"')
    copy_frames(CACHE/'world-avatar','role_head_panel',CHROME,'avatar_frame')
    # A real, paused character session gives bag/skills the same inventory and saves as levels.
    s.nodes.append('[node name="CharacterSession" type="Node3D" parent="."]\nscript = '+s.resource('Script','res://addons/battle_foundation/runtime/battle_session.gd')+'\nscene_manifest_path = "res://data/levels/biyujing/progression/manifest.json"\nscene_seed = 12001\n')
    s.nodes.append('[node name="HitComboTracker" type="Node" parent="CharacterSession"]\nscript = '+s.resource('Script','res://addons/battle_foundation/combat/BattleHitComboTracker.cs')+'\n')
    items=json.loads((ROOT/'data/loot/original_first_level.json').read_text('utf8'))['items']
    items.update(json.loads((ROOT/'data/levels/shuiliandong/loot.json').read_text('utf8'))['items'])
    (ROOT/'data/campaigns/zaomeng1/inventory_catalog.json').write_text(json.dumps({'items':items},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    definitions=[s.resource('Resource','res://'+p.relative_to(ROOT).as_posix()) for p in sorted((ROOT/'data/inventory').glob('*.tres')) if 'item_id =' in p.read_text('utf8')]
    s.nodes.append('[node name="Loot" type="Node" parent="CharacterSession"]\nscript = '+s.resource('Script','res://game/world_map/WorldMapInventoryCatalog.cs')+'\nrules = '+s.resource('JSON','res://data/campaigns/zaomeng1/inventory_catalog.json')+'\nitem_definitions = Array[Resource](['+', '.join(definitions)+'])\n')
    s.nodes.append('[node name="SunWukong" parent="CharacterSession" instance='+s.resource('PackedScene','res://data/characters/sunwukong/character.tscn')+']\nvisible = false\nscene_definition_id = &"孙悟空"\nscene_session_path = NodePath("..")\n')
    s.nodes.append('[node name="HUD" parent="." instance='+s.resource('PackedScene','res://data/ui/battle_hud.tscn')+']\n')
    s.nodes.append('[node name="Settings" parent="." instance='+s.resource('PackedScene','res://addons/battle_foundation/input/battle_operation_menu.tscn')+']\n')
    s.modal('Notice','.')
    s.node('Panel','Panel','Notice',(290,220,360,160),'theme = '+s.resource('Theme','res://data/ui/campaign_theme.tres'))
    s.label('Text','Notice/Panel',(20,18,320,64),'该功能暂未开放',18,'horizontal_alignment = 1')
    s.node('OK','Button','Notice',(420,315,100,36),'text = "确定"\ntheme = '+s.resource('Theme','res://data/ui/campaign_theme.tres'))
    # Godot-generated halo only; no original frontier texture is referenced.
    for stage in re.findall(r'\[node name="(Stage_[^"]+)" type="TextureButton" parent="Stages"\]',t):
        m=re.search(r'\[node name="'+stage+r'"[^\n]*\]\n(.*?)(?=\[node|$)',t,re.S)
        normal=re.search(r'texture_normal = (ExtResource\([^\n]+)',m.group(1)).group(1)
        width=float(re.search(r'offset_right = ([-\d.]+)',m.group(1)).group(1))-float(re.search(r'offset_left = ([-\d.]+)',m.group(1)).group(1))
        height=float(re.search(r'offset_bottom = ([-\d.]+)',m.group(1)).group(1))-float(re.search(r'offset_top = ([-\d.]+)',m.group(1)).group(1))
        s.sub.append(f'[sub_resource type="ShaderMaterial" id="Glow_{stage}"]\nshader = ExtResource("glow_shader")\n')
        s.node('Glow','TextureRect','Stages/'+stage,(-12,-12,width+24,height+24),f'visible = false\ntexture = {normal}\nexpand_mode = 1\nmaterial = SubResource("Glow_{stage}")')
    idx=t.index('[sub_resource') if '[sub_resource' in t else t.index('[node')
    t=t[:idx]+''.join(s.refs)+''.join(s.sub)+t[idx:]+''.join(s.nodes)
    (ROOT/'game/world_map/zaomeng1_world_map.tscn').write_text(t.rstrip()+'\n',encoding='utf8')

if __name__=='__main__':
    export(REF/'games/zmhj-g5/cache/assets/module/systemSet_20260413_1.swf',CACHE/'settings-export','mainPanel,soundSet,showSet,moreSet','clean')
    shutil.copyfile(CACHE/'settings-export-parts.log',CACHE/'settings-layout.log')
    export(REF/'games/zmhj-g5/cache/assets/module/toolScene_20260921_1.swf',CACHE/'world-chrome','mainPanel','clean')
    shutil.copyfile(CACHE/'world-chrome-parts.log',CACHE/'world-tool-layout.log')
    export(REF/'games/zmhj-g5/cache/assets/module/material_20260831_1.swf',CACHE/'world-avatar','role_head_panel,role_circle_head','clean')
    settings();modal_barriers();attributes();world()
