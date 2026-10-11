"""Read-only original SWF export; authored HUD, atlas effects and inventory resources."""
from pathlib import Path
import hashlib, json, math, re, shutil, subprocess, sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'.cleanup-backup/python-packages'))
from PIL import Image
sys.dont_write_bytecode = True

#region Original exports and reproducible asset evidence
PROJECT = Path(__file__).resolve().parents[1]
ORIGINAL = Path(sys.argv[1]).resolve()
OUTPUT = PROJECT / '.cleanup-backup/battle-ui-export'
OUTPUT.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(ORIGINAL))
from backends.zmhj_config import load_config_archive,find_config_archive
config = load_config_archive(ORIGINAL/'games/zmhj-g5')
sources = set()
sources.add(find_config_archive(ORIGINAL/'games/zmhj-g5').relative_to(ORIGINAL).as_posix())

def write(path, text):
    target = PROJECT/path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding='utf8')

def dump(path, data):
    write(path, json.dumps(data, ensure_ascii=False, indent=2)+'\n')

def export(source, symbols, folder=OUTPUT, background=False):
    sources.add(source)
    args = ['java','-Djava.awt.headless=true','-Dfile.encoding=UTF-8','-cp',str(ORIGINAL/'out/swfutil/ffdec_lib_20.1.0/*'),str(PROJECT/'tools/ExportOriginalBattleUI.java'),str(ORIGINAL/source),str(folder),symbols]
    if background: args.append('background')
    result = subprocess.run(args, capture_output=True, encoding='utf8', check=True)
    (OUTPUT/(Path(source).stem+'-'+('bg' if background else 'parts')+'.txt')).write_text(result.stdout, encoding='utf8')

def images(symbol, folder=OUTPUT):
    files = list((folder/symbol.replace('#','id-')).rglob('*.png'))
    return sorted(files, key=lambda p:int(p.stem))

def copy(symbol, name, folder=OUTPUT, frame=0):
    target = PROJECT/'assets/ui/original'/name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(images(symbol, folder)[frame], target)
    return 'res://'+target.relative_to(PROJECT).as_posix()

def original_copy(relative, name):
    source='games/zmhj-g5/cache/assets/'+relative
    sources.add(source)
    target=PROJECT/'assets/ui/original'/name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ORIGINAL/source, target)
    return 'res://'+target.relative_to(PROJECT).as_posix()

MISSION='games/zmhj-g5/cache/assets/ui/mission_20260406_1.swf'
MATERIAL='games/zmhj-g5/cache/assets/module/material_20260831_1.swf'
BACKPACK='games/zmhj-g5/cache/assets/module/backpack_20260817_1.swf'
export(MISSION,'zs,goNextScreen_a,cdTime,#741,#849,#842,#710,#1326,#1330,#869,#875,#879,#161,#703,#707')
export(MISSION,'roleInfo1,roleSkill1', PROJECT/'.cleanup-backup/battle-ui-background', True)
export(MATERIAL,'min_body,lock,warn_background,tips_background,menu_background,menu_button_background')
export(BACKPACK,'bagPanel', PROJECT/'.cleanup-backup/battle-ui-background', True)
export(BACKPACK,'mainPanel,bodyPanel,#186,#189,#192,#195')
export(MATERIAL,'fonts',PROJECT/'.cleanup-backup/bag-fonts')
export(MATERIAL,'fight_number,button_num_bg,btn_prev,btn_next',PROJECT/'.cleanup-backup/bag-controls')
export(BACKPACK,'#312,#147',PROJECT/'.cleanup-backup/bag-controls')
export(BACKPACK,'bodyPanel',PROJECT/'.cleanup-backup/bag-body-clean',True)
export(BACKPACK,'#66',PROJECT/'.cleanup-backup/bag-exp-background')
copy('#66','bag_experience_background.png',PROJECT/'.cleanup-backup/bag-exp-background')
for frame in range(10): copy('fight_number',f'fight_digit_{frame}.png',PROJECT/'.cleanup-backup/bag-controls',frame)
subprocess.run([sys.executable, str(PROJECT/'tools/export_original_fight_power.py'), str(ORIGINAL)], check=True)
for symbol,name in [('roleInfo1','player_frame.png'),('roleSkill1','skill_frame.png'),('bagPanel','bag_panel.png')]: copy(symbol,name,PROJECT/'.cleanup-backup/battle-ui-background')
for symbol,name in [('mainPanel','bag_window.png'),('bodyPanel','body_panel.png'),('warn_background','warn_background.png'),('tips_background','tips_background.png'),('menu_background','menu_background.png'),('#161','bar_background.png'),('#869','hp_fill.png'),('#875','mp_fill.png'),('#879','exp_fill.png'),('#703','rage_background.png'),('#707','rage_fill.png'),('lock','lock.png')]: copy(symbol,name)
for index, id in enumerate([186,189,192,195]):
    for frame in range(3): copy('#'+str(id),f'tab_{index}_{frame}.png',frame=frame)
for frame in range(11): copy('min_body',f'slot_{frame}.png',frame=frame)
for frame in range(3): copy('menu_button_background',f'button_{frame}.png',frame=frame)
original_copy('icon/head/2001_1.png','sunwukong_head.png')
original_copy('icon/role/createBody2001.png','sunwukong_body.png')
shutil.copyfile(images('#1326')[0],PROJECT/'assets/ui/boss/protect_background.png')
shutil.copyfile(images('#1330')[0],PROJECT/'assets/ui/boss/protect_fill.png')
#endregion

#region Compact source-frame atlases retain original registration and empty tail frames
def atlas(symbol, registration, trim=True):
    rows=[]; unique={}; cells=[]
    for file in images(symbol):
        im=Image.open(file).convert('RGBA'); box=im.getbbox() if trim else (0,0,im.width,im.height)
        crop=im.crop(box) if box else Image.new('RGBA',(1,1))
        key=(crop.size,hashlib.sha256(crop.tobytes()).hexdigest())
        if key not in unique:
            unique[key]=len(cells); cells.append(crop)
        rows.append({'cell':unique[key], 'position':[registration[0]+(box[0] if box else 0),registration[1]+(box[1] if box else 0)]})
    x=y=2; row_height=0; rects=[]
    for cell in cells:
        if x+cell.width+2>2048: x=2;y+=row_height+4;row_height=0
        rects.append([x,y,cell.width,cell.height]);x+=cell.width+4;row_height=max(row_height,cell.height)
    height=y+row_height+2
    if height>8192: raise RuntimeError('Atlas exceeds supported texture dimensions')
    sheet=Image.new('RGBA',(2048,height))
    for cell,rect in zip(cells,rects): sheet.paste(cell,rect[:2])
    path=PROJECT/'assets/ui/original'/f'{symbol}.png';sheet.save(path)
    resources=f'[ext_resource type="Texture2D" path="res://assets/ui/original/{symbol}.png" id="atlas"]\n'
    for index,rect in enumerate(rects): resources+=f'[sub_resource type="AtlasTexture" id="Frame{index}"]\natlas = ExtResource("atlas")\nregion = Rect2({", ".join(map(str,rect))})\nfilter_clip = true\n'
    return resources,rows

def track(index, path, values, fps=30):
    times=', '.join(f'{i/fps:.9f}' for i in range(len(values)))
    return f'tracks/{index}/type = "value"\ntracks/{index}/path = NodePath("{path}")\ntracks/{index}/interp = 0\ntracks/{index}/keys = {{"times": PackedFloat32Array({times}), "transitions": PackedFloat32Array({", ".join("1" for _ in values)}), "update": 1, "values": [{", ".join(values)}]}}\n'

def effect_scene(symbol, registration, script, target, loop=False):
    resources, rows=atlas(symbol,registration)
    text='[gd_scene format=3]\n'+f'[ext_resource type="Script" path="{script}" id="script"]\n'+resources
    text+=f'[sub_resource type="Animation" id="Clip"]\nlength = {len(rows)/30:.9f}\nloop_mode = {1 if loop else 0}\n'
    text+=track(0,'Sprite2D:texture',[f'SubResource("Frame{r["cell"]}")' for r in rows])
    text+=track(1,'Sprite2D:position',[f'Vector2({r["position"][0]}, {r["position"][1]})' for r in rows])
    text+=f'[sub_resource type="AnimationLibrary" id="Library"]\n_data = {{&"{symbol}": SubResource("Clip")}}\n[node name="{symbol}" type="Node2D"]\nvisible = false\nscript = ExtResource("script")\nclip = &"{symbol}"\n[node name="Sprite2D" type="Sprite2D" parent="."]\ncentered = false\n[node name="AnimationPlayer" type="AnimationPlayer" parent="."]\ncallback_mode_process = 2\nlibraries/ = SubResource("Library")\n'
    write(target,text)
    return len(rows)

# mcXPA frame2 replaces idle710 with looping flame741 at(1,-19), and space849.
for id,name in [(741,'wushuang_full'),(849,'wushuang_prompt')]:
    folder=OUTPUT/name;folder.mkdir(exist_ok=True)
    for file in images('#'+str(id)): shutil.copyfile(file,folder/file.name)
copy('#710','wushuang_idle.png');copy('#842','wushuang_base.png')
effect_scene('wushuang_full',[-53.5,-63],'res://addons/battle_foundation/ui/original_ui_animation_2d.gd','data/ui/wushuang_full.tscn',True)
effect_scene('wushuang_prompt',[0,0],'res://addons/battle_foundation/ui/original_ui_animation_2d.gd','data/ui/wushuang_prompt.tscn',True)
effect_scene('zs',[-329.3,-224.55],'res://addons/battle_foundation/ui/original_ui_animation_2d.gd','data/ui/boss_execution.tscn')
effect_scene('goNextScreen_a',[0,-15],'res://addons/battle_foundation/ui/original_ui_animation_2d.gd','data/ui/next_screen.tscn')
cd_resources, cd_rows=atlas('cdTime',[-26.35,-25.7],trim=False)
write('data/ui/skill_cooldown_frames.tres','[gd_resource type="SpriteFrames" format=3]\n'+cd_resources+'[resource]\nanimations = [{"name": &"cooldown", "speed": 30.0, "loop": false, "frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("Frame'+str(r['cell'])+'")}' for r in cd_rows)+']}]\n')
#endregion

#region Skill icons and initial original bag definitions; no fabricated equipment bonuses
mapping=json.loads((PROJECT/'data/damage/skill_mapping.json').read_text('utf8'))
skill_rows=[]
for action in [1,2,3,4,8]:
    ability=f'sunwukong_skill{action}';skill=config['Skill'][str(mapping[ability])];resource=config['Resource'][str(skill['resourceId'])]
    path=original_copy('icon/'+resource['icon3'],f'skill_{action}.png')
    skill_rows.append({'ability_id':ability,'name':skill['name'],'icon':path,'source_skill_id':mapping[ability]})
dump('data/ui/sunwukong_skills.json',skill_rows)
# RoleInfoViewer只展示Resource.icon2存在的Buff，不用占位图冒充状态。
status_rows=[]
for status_id,row in json.loads((PROJECT/'data/buffs/original_config.json').read_text('utf8')).items():
    resource=config['Resource'].get(str(int(row.get('resourceId',0))),{})
    relative=resource.get('icon2','')
    if not relative:continue
    path=original_copy('icon/'+relative,f'buff_{status_id}.png')
    definition=PROJECT/f'data/buffs/{status_id}.tres';text=definition.read_text('utf8')
    if 'id="original_hud_icon"' not in text:
        pos=text.index('[sub_resource');text=text[:pos]+f'[ext_resource type="Texture2D" path="{path}" id="original_hud_icon"]\n'+text[pos:]
        text=text.replace('[resource]\n','[resource]\nicon = ExtResource("original_hud_icon")\nmetadata/original_fold = '+str(bool(row.get('fold',False))).lower()+'\n',1)
        definition.write_text(text,'utf8')
    status_rows.append({'status_id':status_id,'original_buff_id':row['id'],'resource_id':row['resourceId'],'icon':path,'fold':bool(row.get('fold',False))})
dump('data/ui/status_icons.json',status_rows)
item_rows=[]
equip_ids=['110101001','110101002','110101003']
for id in equip_ids:
    data=config['Equipment'][id];resource=config['Resource'][str(data['resourceId'])]
    icon_key=next(k for k in ['icon2','icon1','icon3'] if k in resource)
    icon=original_copy('icon/'+resource[icon_key],f'item_{id}.png')
    modifiers=[]
    for key in ['hpMax','mpMax','atk','phyDef','reHP','reMP','hit','dodge','critical','toughness','lucky','guardian']:
        value=float(str(data.get(key,'0')).split(';')[0])
        if value: modifiers.append((key,value))
    text='[gd_resource type="Resource" format=3]\n[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_inventory_equipment.gd" id="item"]\n[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_equipment_definition.gd" id="equip"]\n[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/attributes/gameplay_attribute_modifier.gd" id="modifier"]\n'+f'[ext_resource type="Texture2D" path="{icon}" id="icon"]\n'
    for i,(key,value) in enumerate(modifiers):text+=f'[sub_resource type="Resource" id="Mod{i}"]\nscript = ExtResource("modifier")\nattribute_id = &"{key}"\nvalue = {value}\n'
    slot={'armor':'armor','helmet':'helmet','weapon':'weapon'}[data['part']]
    text+='[sub_resource type="Resource" id="Equipment"]\nscript = ExtResource("equip")\n'+f'definition_id = &"{id}"\ndisplay_name = {json.dumps(data["name"],ensure_ascii=False)}\nslot_id = &"{slot}"\n'
    text+='attribute_modifiers = Array[ExtResource("modifier")](['+', '.join(f'SubResource("Mod{i}")' for i in range(len(modifiers)))+'])\n'
    text+='[resource]\nscript = ExtResource("item")\n'+f'item_id = &"{id}"\nname = {json.dumps(data["name"],ensure_ascii=False)}\ndescription = {json.dumps(data["describe"],ensure_ascii=False)}\nicon = ExtResource("icon")\ncategory = 2\nequip_type = { {"armor":0,"helmet":2,"weapon":6}[data["part"]] }\nbattle_definition = SubResource("Equipment")\n'
    prefix={'armor':'衣服','helmet':'头盔','weapon':'武器'}[data['part']]
    text+=f'appearance_skin = &"{prefix}/{Path(resource["normal"]).stem}"\n'
    text+='original_data = '+json.dumps(data,ensure_ascii=False).replace('null','null')+'\n'
    # JSON booleans/null are also valid Godot Variant dictionary literals.
    write(f'data/inventory/{id}.tres',text);item_rows.append({'id':id,'definition':f'res://data/inventory/{id}.tres','source':data})
dump('data/inventory/original_items.json',item_rows)
common=config['Common']['1']
dump('data/inventory/original_rules.json',{'max_capacity':int(common['packMaxNum']),'sell_discount':float(common['sellDiscount']),'initial_capacities':{'equipment':common['equPackageNum'],'material':common['propPackageNum'],'consumable':common['consumePropPackageNum'],'fashion':common['fashionPackageNum']},'open_pack':{k:v for k,v in config['OpenPack'].items() if int(v['packType']) in [1,2,3,4]},'item_names':{'101018001':config['Prop']['101018001']['name']}})
for row in skill_rows:
    action=row['ability_id'].replace('sunwukong_','')
    path=PROJECT/f'data/characters/sunwukong/skills/{action}.tres';text=path.read_text('utf8')
    if 'id="original_icon"' not in text:
        pos=text.index('[sub_resource');text=text[:pos]+f'[ext_resource type="Texture2D" path="{row["icon"]}" id="original_icon"]\n'+text[pos:]
        text=text.replace(f'ability_name = "{row["name"]}"',f'ability_name = "{row["name"]}"\nicon = ExtResource("original_icon")')
    path.write_text(text,'utf8')
evidence=['viewers/container/uis/RoleInfoViewer.as','viewers/container/uis/RoleSkillView.as','viewers/component/SkillComing.as','viewers/container/BattleMapBase.as','controllers/battle/StageClearCmd.as','com/wdcgame/net/SimulateServerFrame.as','modules/backpack/view/BagView.as','modules/backpack/view/BagMediator.as','modules/backpack/view/BodyView.as','models/vo/players/BagVO.as','org/moon/AutoWarnBar.as','modules/utils/CreateComponent.as','modules/utils/Unify.as','controllers/item/SellItemCmd.as']
for path in evidence:sources.add('out/zmhj-equip-skill-diag/'+path)
sources.add('out/zmhj-equip-skill-diag/com/wdcgame/display/components/BuffEffectEntity.as')
sources.add('out/zmhj-equip-skill-diag/com/wdcgame/filters/Filter.as')
dump('assets/ui/original/source_mapping.json',{'sources':[{'path':p,'sha256':hashlib.sha256((ORIGINAL/p).read_bytes()).hexdigest()} for p in sorted(sources)],'fps':30,'viewport':[940,590],'execution_frames':59,'cooldown_frames':103,'next_screen_frames':60,'wushuang_full_frames':15,'wushuang_prompt_frames':6,'wushuang_mask_anchor':[208,5.5],'wushuang_mask_scale_duration':1,'player_info_origin':[0,0],'skill_bar_origin':[0,520],'bag_grid_origin':[483,118],'bag_page_size':25,'bag_grid_columns':5,'bag_grid_gap':5,'tabs':['equipment','material','consumable','fashion'],'sort':['quality_desc','id_asc']})
print('Exported original HUD, 59-frame execution, 60-frame next-screen indicator, 103-frame cooldown, bag skins and source definitions')
#endregion

#region Correct authored world-object scaling and protection texture roles
for name in ['wall','note']:
    path=PROJECT/f'data/monsters/jushi_lingjun/{name}.tscn'
    text=path.read_text('utf8')
    if '[node name="Visual"' not in text:
        text=text.replace('NodePath("Sprite2D:', 'NodePath("Visual/Sprite2D:')
        text=text.replace('[node name="Sprite2D" type="Sprite2D" parent="."]\ncentered = false\nscale = Vector2(2,2)', '[node name="Visual" type="Node2D" parent="."]\nscale = Vector2(2,2)\n[node name="Sprite2D" type="Sprite2D" parent="Visual"]\ncentered = false')
        path.write_text(text,'utf8')
path=PROJECT/'addons/battle_foundation/boss/battle_boss_feedback_2d.tscn'
text=path.read_text('utf8').replace('path="res://assets/ui/boss/protect_border.png"','path="res://assets/ui/boss/protect_background.png"').replace('texture_over = ExtResource("protect_border")','texture_under = ExtResource("protect_border")')
path.write_text(text,'utf8')
#endregion
