"""Reproducible, read-only ZMX5 skill UI and progression table export."""
from pathlib import Path
import hashlib, json, shutil, subprocess, sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve()
sys.path.insert(0, str(SOURCE))
from backends.zmhj_config import load_config_archive, find_config_archive
C = load_config_archive(SOURCE/'games/zmhj-g5')
OUT = ROOT/'.cleanup-backup/skill-panel-export'
ASSETS = ROOT/'assets/ui/skills'
ASSETS.mkdir(parents=True, exist_ok=True)
def write(path, content):
    p=ROOT/path; p.parent.mkdir(parents=True, exist_ok=True); p.write_text(content, encoding='utf8')
def export(module, symbols, clean=False):
    folder=OUT/(module+('-clean' if clean else '-parts'))
    swf=next((SOURCE/'games/zmhj-g5/cache/assets/module').glob(module+'_*.swf'))
    run=subprocess.run(['java','-Djava.awt.headless=true','-Dfile.encoding=UTF-8','-cp',str(SOURCE/'out/swfutil/ffdec_lib_20.1.0/*'),str(ROOT/'tools/ExportOriginalBattleUI.java'),str(swf),str(folder),symbols]+(['clean'] if clean else []),capture_output=True,encoding='utf8',check=True)
    folder.mkdir(parents=True,exist_ok=True); (folder/'layout.txt').write_text(run.stdout,encoding='utf8')
    return folder
def unlit_buttons():
    folder=OUT/'unlit'; swf=next((SOURCE/'games/zmhj-g5/cache/assets/module').glob('skill_*.swf'))
    subprocess.run(['java','-Djava.awt.headless=true','-Dfile.encoding=UTF-8','-cp',str(SOURCE/'out/swfutil/ffdec_lib_20.1.0/*'),str(ROOT/'tools/ExportOriginalBattleUI.java'),str(swf),str(folder),'#141','unlit'],stdout=subprocess.DEVNULL,check=True)
    return folder
def copy(folder, symbol, name, frame=0):
    files=sorted((folder/symbol.replace('#','id-')).rglob('*.png'), key=lambda p:int(p.stem))
    shutil.copyfile(files[frame],ASSETS/(name+'.png')); return 'res://assets/ui/skills/'+name+'.png'
clean=export('skill','mainPanel,item_skill,updageSkill',True)
parts=export('skill','mainSkill,specialSkill,#10,#84,#87,#107,#90,#97,#104,#29,#41,#49,#141,#44,#134,#115')
keyboard=export('keyboardSet','mainPanel',True)
keyparts=export('keyboardSet','#11,#26,#40,#42,#44')
frames=export('material','skill_main,skill_passive,skill_peerless,skill_prop')
shutil.copyfile(SOURCE/'games/zmhj-g5/cache/assets/icon/resist/fireResist.png',ASSETS/'fire_element.png')
for symbol,name in [('mainPanel','main'),('item_skill','row'),('updageSkill','upgrade')]: copy(clean,symbol,name)
for symbol,name in [('mainSkill','active_sections'),('specialSkill','special_sections')]: copy(parts,symbol,name)
copy(keyboard,'mainPanel','keyboard'); copy(keyparts,'#26','keyboard_title')
for symbol,name in [('#10','close'),('#84','active_tab'),('#87','special_tab'),('#107','secret_tab'),('#90','keyboard_button'),('#97','job'),('#104','reset'),('#29','help'),('#41','upgrade_button'),('#49','batch'),('#141','learn_button')]:
    for f in range(3): copy(parts,symbol,name+'_'+str(f),f)
for f in range(3,6): copy(parts,'#141','learn_button_'+str(f),f)
unlit=unlit_buttons()
for f in range(6):copy(unlit,'#141','learn_button_'+str(f),f)
for f in range(18):copy(parts,'#134','learn_glow_'+str(f),f)
for f in range(3):copy(parts,'#115','skill_more_'+str(f),f)
copy(parts,'#41','upgrade_button_3',3)
copy(parts,'#44','arrow')
for symbol,name in [('#40','items_tab'),('#42','monsters_tab'),('#44','emotes_tab')]:
    for f in range(3): copy(keyparts,symbol,name+'_'+str(f),f)
for symbol in ['skill_main','skill_passive','skill_peerless','skill_prop']: copy(frames,symbol,symbol)
ids=[1101010,1101020,1101030,1101040,1101070,1101080,1301010,1201010]
rows=[]
for sid in ids:
    s=C['Skill'][str(sid)]; init=C['SkillInit'][str(sid)]; resource=C['Resource'][str(s['resourceId'])]
    icon=resource.get('icon2') or resource.get('icon3') or resource['icon1']
    shutil.copyfile(SOURCE/'games/zmhj-g5/cache/assets/icon'/icon,ASSETS/(str(sid)+'.png'))
    levels=[{ 'level':int(v['level']),'role_level':int(v['roleLev']),'spirit':int(v['consume_count']) } for k,v in C['SkillLev'].items() if k.startswith(str(sid)+'_')]
    levels.sort(key=lambda x:x['level'])
    rows.append(dict(id=sid,ability=('sunwukong_'+s['actionName']) if s['skillType']==1 else ('sunwukong_wushuang' if sid==1201010 else ''),name=s['name'],description=s.get('describe',''),upgrade_description=s.get('upgradeDescribe',''),type=s['skillType'],order=s['order'],grade=init['skillGrade'],available=sid in [1101010,1101020,1101030,1101040,1301010,1201010],initial_level=1 if sid in [1101010,1101020,1101030,1101040,1301010,1201010] else 0,icon='res://assets/ui/skills/'+str(sid)+'.png',mp=[float(x) for x in str(s.get('consumeMP','0')).split(';')],cooldown=[float(x) for x in str(s.get('cd','0')).split(';')],levels=levels))
write('data/characters/sunwukong/skills/panel_rules.json',json.dumps({'source':'上古天帝篇 Skill / SkillInit / SkillLev / Role2001; current role grade 0','skills':rows,'evidence':{'archive_sha256':hashlib.sha256(find_config_archive(SOURCE/'games/zmhj-g5').read_bytes()).hexdigest(),'ui':'skill_20260119_1.swf / keyboardSet_20260413_1.swf','passive':'BattleModelManager.as: source skill 1001050 + passive 1301010 => critRate=1'}},ensure_ascii=False,indent=2)+'\n')
# Authored scene: all controls, popup/modal, item cells and drag preview exist in the scene.
resources=[]; nodes=[]; resource_ids={}
def resource(path,kind='Texture2D'):
    if path not in resource_ids:
        rid='R'+str(len(resources)); resource_ids[path]=rid; resources.append(f'[ext_resource type="{kind}" path="{path}" id="{rid}"]')
    return 'ExtResource("'+resource_ids[path]+'")'
script=resource('res://addons/battle_foundation/ui/OriginalSkillPanel.cs','Script')
font=resource('res://assets/ui/original/ui_font.ttf','FontFile')
sub=[]
def node(name,kind,parent,rect,props='',mouse=2):
    x,y,w,h=rect
    nodes.append(f'[node name="{name}" type="{kind}" parent="{parent}"]\nlayout_mode = 0\noffset_left = {float(x)}\noffset_top = {float(y)}\noffset_right = {float(x+w)}\noffset_bottom = {float(y+h)}\nmouse_filter = {mouse}\n'+props)
def image(name,parent,rect,asset):
    node(name,'TextureRect',parent,rect,'texture = '+resource('res://assets/ui/skills/'+asset+'.png')+'\nexpand_mode = 1\nstretch_mode = 0\n')
def label(name,parent,rect,text='',size=16,color='Color(0.37, 0.12, 0.02, 1)',extra=''):
    node(name,'Label',parent,rect,f'theme_override_fonts/font = {font}\ntheme_override_font_sizes/font_size = {size}\ntheme_override_colors/font_color = {color}\ntext = {json.dumps(text,ensure_ascii=False)}\n'+extra)
def button(name,parent,rect,asset):
    node(name,'TextureButton',parent,rect,'ignore_texture_size = true\nstretch_mode = 0\n'+''.join(f'texture_{mode} = {resource("res://assets/ui/skills/"+asset+"_"+str(f)+".png")}\n' for mode,f in [('normal',0),('hover',1),('pressed',2)]),0)
def plain(name,parent,rect,text):
    node(name,'Button',parent,rect,f'text = {json.dumps(text,ensure_ascii=False)}\ntheme_override_fonts/font = {font}\ntheme_override_font_sizes/font_size = 15\n',0)
nodes.append('[node name="SkillPanel" type="Control"]\nvisible = false\nprocess_mode = 3\nz_index = 150\nlayout_mode = 0\noffset_right = 940.0\noffset_bottom = 590.0\nmouse_filter = 0\nscript = '+script+'\n')
node('Main','Control','.',(0,0,940,590))
image('Background','Main',(0,0,940,590),'main')
for name,rect,asset in [('Close',(896.45,18.35,33,38),'close'),('ActiveTab',(96.35,29.85,112,47),'active_tab'),('SpecialTab',(212.3,29.85,112,47),'special_tab'),('SecretTab',(328.25,29.85,112,47),'secret_tab'),('Keyboard',(741.3,19,100,36),'keyboard_button'),('Job',(478.6,14.35,72,60),'job'),('Reset',(547.95,14.35,72,60),'reset'),('Help',(851,18.35,37,37),'help')]: button(name,'Main',rect,asset)
image('ActiveSections','Main',(94,88.35,812.8,466.95),'active_sections')
image('SpecialSections','Main',(94,88.35,446.05,345),'special_sections')
node('Rows','Control','Main',(0,0,940,590))
for i,row in enumerate(rows):
    sid=row['id']; typ=row['type']; order=int(str(row['order'])[-1]); x=(126 if typ!=3 else 538); y=87+order*122
    if typ==1 and order>3:x=538;y=87+(order-4)*122
    path='Main/Rows/S'+str(sid)
    node('S'+str(sid),'Control','Main/Rows',(x,y,377,119),mouse=1)
    image('Background',path,(0,0,377,113),'row')
    image('Frame',path,(11,5,78,74),{1:'skill_main',2:'skill_passive',3:'skill_peerless'}[typ])
    image('Icon',path,(23,15,54,54),str(sid))
    if row['id'] in [1101020,1101030,1101040]: image('Element',path,(91,7,22,22),'fire_element')
    label('Name',path,(117,8,160,25),row['name'],18,'Color(0,0,0,1)')
    label('Level',path,(275,8,95,25),'',18,'Color(0.75,0,0,1)')
    label('Description',path,(104,38,265,75),row['description'],14,extra='autowrap_mode = 2\n')
    if typ==1:
        button('Upgrade',path,(18.55,80.5,64,26),'learn_button')
        # Independent 18-frame light, visible only on learnable unlearned skills.
        frame_id='Glow'+str(sid)
        glow_refs=[resource('res://assets/ui/skills/learn_glow_'+str(f)+'.png') for f in range(18)]
        sub.append(f'[sub_resource type="SpriteFrames" id="{frame_id}"]\nanimations = [{{"frames": ['+', '.join('{"duration": 1.0, "texture": '+ref+'}' for ref in glow_refs)+'], "loop": true, "name": &"default", "speed": 30.0}]\n')
        nodes.append(f'[node name="LearnGlow" type="AnimatedSprite2D" parent="{path}"]\nvisible = false\nposition = Vector2(9.05,71.2)\nsprite_frames = SubResource("{frame_id}")\nautoplay = "default"\ncentered = false\n')
        label('Locked',path,(8,85,90,28),'转职后解锁',12)
        button('Secrets',path,(343.2,7.75,22,22),'skill_more')
node('Keyboard','Control','.',(0,0,940,590),'visible = false\n')
image('Background','Keyboard',(0,0,940,590),'keyboard')
image('Title','Keyboard',(378.55,25,180,28),'keyboard_title')
button('Close','Keyboard',(833.6,16,33,38),'close')
for i,a in enumerate(['items','monsters','emotes']): button(a+'Tab','Keyboard',(580.4+i*80.2,62.75,86.3,32),a+'_tab')
label('Tip','Keyboard',(127,191,423,30),'拖动技能至下方格子装配，双击主动技能或道具卸下',12,extra='autowrap_mode = 2\n')
for row in rows:
    if not row['available']:continue
    sid=row['id'];typ=row['type'];i=int(str(row['order'])[-1]);pos=(127+(i%4)*83,71+(i//4)*79) if typ==1 else ((127,236) if typ==2 else (127,325))
    path='Keyboard/Stock'+str(sid)
    node('Stock'+str(sid),'Control','Keyboard',(*pos,78,74),mouse=0)
    image('Background',path,(0,0,78,74),{1:'skill_main',2:'skill_passive',3:'skill_peerless'}[typ]);image('Icon',path,(12,10,54,54),str(sid)); label('Level',path,(49,51,27,20),'',12,'Color(1,1,1,1)')
for group,count,start in [('active',5,94),('passive',1,503),('peerless',1,593),('item',2,684)]:
    for i in range(count):
        path='Keyboard/'+group+str(i);node(group+str(i),'Control','Keyboard',(start+i*78,442,78,74),mouse=0)
        image('Background',path,(0,0,78,74),'skill_'+('main' if group=='active' else ('prop' if group=='item' else ('passive' if group=='passive' else 'peerless'))))
        node('Icon','TextureRect',path,(12,10,54,54),'expand_mode = 1\nstretch_mode = 0\n')
        label('Key',path,(0,67,78,22),'',14,'Color(1,1,1,1)','horizontal_alignment = 1\ntheme_override_colors/font_outline_color = Color(0,0,0,1)\ntheme_override_constants/outline_size = 2\n')
for i in range(16):
    path='Keyboard/Item'+str(i);node('Item'+str(i),'Control','Keyboard',(581+(i%4)*59,101+(i//4)*59,54,54),mouse=0)
    image('Background',path,(0,0,54,54),'skill_main');node('Icon','TextureRect',path,(5,5,44,44),'expand_mode = 1\nstretch_mode = 0\n');label('Count',path,(25,33,27,20),'',12,'Color(1,1,1,1)')
plain('Prev','Keyboard',(652,354,28,25),'‹');plain('Next','Keyboard',(746,354,28,25),'›');label('Page','Keyboard',(682,354,60,25),'1/1',14,extra='horizontal_alignment = 1\n')
node('Upgrade','Control','.',(0,0,940,590),'visible = false\n',0)
image('Background','Upgrade',(0,0,940,590),'upgrade')
button('Close','Upgrade',(691.15,41.5,33,38),'close')
node('Icon','TextureRect','Upgrade',(431,120,78,78),'expand_mode = 1\nstretch_mode = 0\n')
for name,rect,size,color in [('Name',(300,223,340,27),20,'Color(0,0,0,1)'),('Requirements',(230,252,480,27),18,'Color(0.75,0,0,1)'),('Cost',(230,278,480,27),18,'Color(0.75,0,0,1)'),('Description',(230,304,480,52),16,'Color(0.37,0.12,0.02,1)'),('Growth',(250,369,440,22),16,'Color(0.37,0.12,0.02,1)'),('MP',(275,390,390,25),16,'Color(0.37,0.12,0.02,1)'),('Cooldown',(275,414,390,25),16,'Color(0.37,0.12,0.02,1)'),('Spirit',(237,505,330,26),16,'Color(0.37,0.12,0.02,1)')]:label(name,'Upgrade',rect,'',size,color,'horizontal_alignment = 1\nautowrap_mode = 2\n')
button('Submit','Upgrade',(420,450.1,100,36),'upgrade_button');button('Batch','Upgrade',(558.85,450.1,100,36),'batch')
popup=resource('res://assets/ui/original/tips_background.png')
style='[sub_resource type="StyleBoxTexture" id="popup"]\ntexture = '+popup+'\ntexture_margin_left = 8.0\ntexture_margin_top = 8.0\ntexture_margin_right = 8.0\ntexture_margin_bottom = 8.0\n'
node('Notice','Control','.',(0,0,940,590),'visible = false\n',0)
node('Dim','ColorRect','Notice',(0,0,940,590),'color = Color(0,0,0,0.3)\n')
node('Panel','Panel','Notice',(265,240,410,100),'theme_override_styles/panel = SubResource("popup")\n')
label('Text','Notice',(280,252,380,52),'',17,extra='autowrap_mode = 2\nhorizontal_alignment = 1\n');plain('OK','Notice',(430,308,80,27),'确定')
node('Tooltip','Panel','.',(0,0,320,140),'z_as_relative = false\nz_index = 151\nvisible = false\ntheme_override_styles/panel = SubResource("popup")\n');label('Text','Tooltip',(12,10,296,120),'',15,extra='autowrap_mode = 2\n')
node('DragIcon','TextureRect','.',(0,0,44,44),'z_as_relative = false\nz_index = 152\nvisible = false\nexpand_mode = 1\nstretch_mode = 0\n')
write('data/ui/skills.tscn','[gd_scene format=3]\n'+'\n'.join(resources)+'\n\n'+''.join(sub)+style+'\n'+'\n'.join(nodes)+'\n')
from refine_skill_keyboard_ui import author
author()
print('Exported original skill/keyboard scenes, exact upgrade tables, icons and source evidence')
