"""Offline Boss skills/atlas/announcement/audio import; does not rebuild Wukong or the map."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, struct, subprocess, sys, xml.etree.ElementTree as ET, zlib
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
BASE = 'data/monsters/jushi_lingjun'

#region Resource and original-source helpers
def write(name, text):
    p = PROJECT/name; p.parent.mkdir(parents=True, exist_ok=True); p.write_text(text, encoding='utf-8')
def dump(name, value): write(name, json.dumps(value, ensure_ascii=False, indent=2)+'\n')
def clean(value):
    if isinstance(value, dict): return {k:clean(v) for k,v in value.items() if k != 'parent'}
    if isinstance(value, list): return [clean(v) for v in value]
    return value
def g(value):
    if isinstance(value, bool): return str(value).lower()
    if isinstance(value, str): return json.dumps(value, ensure_ascii=False)
    if isinstance(value, dict): return '{'+', '.join(g(str(k))+': '+g(v) for k,v in value.items())+'}'
    if isinstance(value, list): return '['+', '.join(g(v) for v in value)+']'
    return str(value)
def rect(row): return 'Rect2('+', '.join(row.get(k,'0') for k in ['x','y','width','height'])+')'
def source_hash(original, relative): return {'path':relative, 'sha256':hashlib.sha256((original/relative).read_bytes()).hexdigest()}
def sound_tags(path):
    raw=path.read_bytes(); data=raw[8:] if raw[:3]==b'FWS' else zlib.decompress(raw[8:]); bits=data[0]>>3
    pos=(5+4*bits+7)//8+4; tags=[]
    while pos+2<=len(data):
        header=struct.unpack_from('<H',data,pos)[0];pos+=2;length=header&63;code=header>>6
        if length==63:length=struct.unpack_from('<I',data,pos)[0];pos+=4
        tags.append((code,data[pos:pos+length]));pos+=length
        if code==0:break
    names={}; sounds={}
    for code, body in tags:
        if code in (56,76):
            offset=2
            for _ in range(struct.unpack_from('<H',body)[0]):
                id=struct.unpack_from('<H',body,offset)[0];offset+=2;end=body.index(0,offset);names[id]=body[offset:end].decode();offset=end+1
        if code==14 and body[2]>>4==2: sounds[struct.unpack_from('<H',body)[0]]=body[9:]
    return {names.get(id,str(id)):audio for id,audio in sounds.items()}
#endregion

#region Complete editor-authored animation libraries and independent world objects
def atlas_resources():
    actions={}; resources=[]; pivot=(0,0)
    for index, row in enumerate(ET.parse(PROJECT/'assets/monsters/jushi_lingjun/atlas.xml').getroot()):
        row=dict(row.attrib)
        if 'pivotX' in row:pivot=(float(row['pivotX']),float(row['pivotY']))
        row['pivot']=pivot;rid='Frame_'+str(index)
        w,h=float(row['width']),float(row['height']);row['texture']='null'
        if w>0 and h>0:
            fx,fy=float(row.get('frameX',0)),float(row.get('frameY',0));row['texture']='SubResource("'+rid+'")'
            resources.append(f'[sub_resource type="AtlasTexture" id="{rid}"]\natlas = ExtResource("atlas")\nregion = {rect(row)}\nmargin = Rect2({-fx}, {-fy}, {-fx}, {-fy})\nfilter_clip = true\n')
        actions.setdefault(row['name'][:-4],[]).append(row)
    return actions,resources
def track(index,path,times,values):
    return f'tracks/{index}/type = "value"\ntracks/{index}/path = NodePath("{path}")\ntracks/{index}/interp = 0\ntracks/{index}/keys = {{"times": PackedFloat32Array('+', '.join(f'{t:.9f}' for t in times)+'), "transitions": PackedFloat32Array('+', '.join('1' for _ in times)+'), "update": 1, "values": ['+', '.join(values)+']}\n'
def sequence_tracks(index,node,frames,loop=False):
    times=[i/30 for i in range(len(frames))]
    return track(index,node+':texture',times,[r['texture'] for r in frames])+track(index+1,node+':position',times,[f'Vector2({-r["pivot"][0]}, {-r["pivot"][1]})' for r in frames])
def animations(actions,resources):
    clips={'idle':'idle','move':'walk','run':'walk','jump':'idle','jump_2':'idle','fall':'idle','land':'idle','hurt':'hurtStand','death':'dead','attack_1':'skill1','attack_2':'skill2','attack_3':'skill3','protect':'idle'}
    text='[gd_scene format=3]\n[ext_resource type="Script" path="res://addons/battle_foundation/animation/animation_player_adapter_2d.gd" id="adapter"]\n[ext_resource type="Resource" path="res://'+BASE+'/animation.tres" id="profile"]\n[ext_resource type="Texture2D" path="res://assets/monsters/jushi_lingjun/atlas.png" id="atlas"]\n[ext_resource type="Script" path="res://addons/battle_foundation/movement/battle_hitbox_2d.gd" id="hitbox"]\n[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/gameplay_ability_definition.gd" id="definition"]\n'
    for i,file in [(1,'skill'),(2,'skill2'),(3,'skill3')]:text+=f'[ext_resource type="Resource" path="res://{BASE}/{file}.tres" id="skill{i}"]\n'
    text+='\n'.join(resources)
    for action,native in clips.items():
        frames=actions[native];text+=f'[sub_resource type="Animation" id="Anim_{action}"]\nlength = {len(frames)/30:.9f}\nloop_mode = {1 if action in ["idle","move","run","protect"] else 0}\n'
        text+=sequence_tracks(0,'Visual/Body',frames)
        index=2
        for slot,fx in [(1,'skill1_1'),(2,'skill2_2')]:
            enabled=native=='skill'+str(slot)
            text+=track(index,f'Visual/Effect{slot}:visible',[0],['true' if enabled else 'false']);index+=1
            if enabled:text+=sequence_tracks(index,f'Visual/Effect{slot}',actions[fx]);index+=2
        text+=track(index,'Visual/ProtectGlow:visible',[0],['true' if action=='protect' else 'false'])
    text+='[sub_resource type="AnimationLibrary" id="Library"]\n_data = {'+', '.join('&"'+a+'": SubResource("Anim_'+a+'")' for a in clips)+'}\n[sub_resource type="RectangleShape2D" id="HitShape"]\nresource_local_to_scene = true\nsize = Vector2(1,1)\n'
    first=actions['idle'][0]
    text+='[node name="AnimationAdapter" type="Node2D"]\nscript = ExtResource("adapter")\nprofile = ExtResource("profile")\n[node name="Visual" type="Node2D" parent="."]\nscale = Vector2(2,2)\n'
    text+=f'[node name="Body" type="Sprite2D" parent="Visual"]\ncentered = false\ntexture = {first["texture"]}\nposition = Vector2({-first["pivot"][0]}, {-first["pivot"][1]})\n'
    for slot in [1,2]:text+=f'[node name="Effect{slot}" type="Sprite2D" parent="Visual"]\nvisible = false\ncentered = false\n'
    text+='[node name="ProtectGlow" type="Polygon2D" parent="Visual"]\nvisible = false\nz_index = -1\npolygon = PackedVector2Array(-100,-95, -70,-175, 0,-205, 70,-175, 100,-95, 70,-20, 0,10, -70,-20)\ncolor = Color(1,0.88,0.45,0.35)\n[node name="AnimationPlayer" type="AnimationPlayer" parent="."]\nlibraries/ = SubResource("Library")\n[node name="AttackHitbox" type="Area2D" parent="."]\nvisible = false\ncollision_layer = 0\ncollision_mask = 0\nmonitoring = false\nmonitorable = false\nscript = ExtResource("hitbox")\npreview_abilities = Array[ExtResource("definition")]([ExtResource("skill1"),ExtResource("skill2"),ExtResource("skill3")])\n[node name="CollisionShape2D" type="CollisionShape2D" parent="AttackHitbox"]\nshape = SubResource("HitShape")\ndisabled = true\n'
    write(BASE+'/visual.tscn',text)
    for name,clips in [('note',['skill2_1']),('wall',['skill3_1','skill3_2'])]:
        text='[gd_scene format=3]\n[ext_resource type="Script" path="res://addons/battle_foundation/boss/battle_boss_world_object_2d.gd" id="script"]\n[ext_resource type="Resource" path="res://'+BASE+'/'+name+'.tres" id="definition"]\n[ext_resource type="Texture2D" path="res://assets/monsters/jushi_lingjun/atlas.png" id="atlas"]\n'+'\n'.join(resources)
        for clip in clips:
            frames=actions[clip];text+=f'[sub_resource type="Animation" id="{clip}"]\nlength = {len(frames)/30:.9f}\nloop_mode = {1 if clip in ["skill2_1","skill3_2"] else 0}\n'+sequence_tracks(0,'Sprite2D',frames)
        text+='[sub_resource type="AnimationLibrary" id="Library"]\n_data = {'+', '.join('&"'+a+'": SubResource("'+a+'")' for a in clips)+'}\n[sub_resource type="RectangleShape2D" id="Shape"]\nresource_local_to_scene = true\nsize = Vector2(132,354)\n'
        text+='[node name="'+name.title()+'" type="Node2D"]\nvisible = false\nscript = ExtResource("script")\ndefinition = ExtResource("definition")\n[node name="Sprite2D" type="Sprite2D" parent="."]\ncentered = false\nscale = Vector2(2,2)\n[node name="AnimationPlayer" type="AnimationPlayer" parent="."]\nlibraries/ = SubResource("Library")\n[node name="Obstacle" type="StaticBody2D" parent="."]\ncollision_layer = 1\ncollision_mask = 2\n[node name="CollisionShape2D" type="CollisionShape2D" parent="Obstacle"]\nposition = Vector2(0,-137)\nshape = SubResource("Shape")\ndisabled = true\n'
        write(BASE+'/'+name+'.tscn',text)
#endregion

#region Original three GAS skills, reactions, behavior and resource indexing
def import_definitions(original,config,actions):
    ab={}
    for row in ET.parse(PROJECT/'assets/monsters/jushi_lingjun/attack_bounds.xml').getroot():
        if float(row.get('width','0'))>0:ab.setdefault(row.get('name')[3:-4],[]).append(dict(row.attrib,frame=int(row.get('name')[-4:])))
    skill_ids=[2001100,2001110,2001120]; titles=['震颤之音','琵琶之伤','玉石之墙']
    for number,id in enumerate(skill_ids,1):
        cfg=config['Skill'][str(id)];segment_action='skill1_1' if number==1 else 'skill2_2'
        text='[gd_resource type="Resource" script_class="GameplayAbilityDefinition" format=3]\n[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/gameplay_ability_definition.gd" id="definition"]\n[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/features/gameplay_ability_feature.gd" id="feature"]\n[ext_resource type="Script" path="res://addons/gameplay_abiltiy_system/scripts/abilities/features/cooldown_feature.gd" id="cooldown"]\n[ext_resource type="Script" path="res://addons/battle_foundation/gas/battle_frame_timeline_feature.gd" id="timeline"]\n[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_attack_segment.gd" id="segment"]\n[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_frame_event.gd" id="event"]\n[sub_resource type="Resource" id="Cooldown"]\nscript = ExtResource("cooldown")\ncooldown_duration = '+('5.0' if number==2 else '10.0')+'\n'
        if number<=2:
            rows=ab[segment_action];part=cfg['param']['s'][0 if number==1 else 1];movement=part.get('targetMove') or cfg.get('targetMove','0;0');x,y=map(float,movement.split(';'));stiff=float(part.get('stiff',cfg.get('stiff',0)))
            text+='[sub_resource type="Resource" id="Segment"]\nscript = ExtResource("segment")\nsegment_id = &"'+segment_action+'"\nhit_index = 1\nstart_frame = '+str(rows[0]['frame'])+'\nend_frame = '+str(rows[-1]['frame']+1)+'\naction = &"attack_'+str(number)+'"\nhit_rect = '+rect(rows[0])+'\nhit_rect_frames = Dictionary[int, Rect2]({'+', '.join(str(r['frame'])+': '+rect(r) for r in rows)+'})\nhit_stun = '+str(stiff)+'\nknockback_speed = '+str(x*2)+'\nknockback_duration = '+str(stiff if stiff>0 else 1)+'\nlaunch_speed = '+str(y*6)+'\nreset_vertical_velocity = true\nreaction_gravity = 1980.0\nprotection_skill_id = "'+str(id)+'"\n'
        if number>=2:
            frame=24 if number==2 else 19
            text+='[sub_resource type="Resource" id="ObjectEvent"]\nscript = ExtResource("event")\nsource_frame = '+str(frame)+'\nevent_id = &"battle.boss.objects"\npayload = {"object_id": &"'+('pipa_notes' if number==2 else 'jade_wall')+'"}\n'
        text+='[sub_resource type="Resource" id="Timeline"]\nscript = ExtResource("timeline")\nduration_frames = '+str(len(actions['skill'+str(number)]))+'\nanimation_action = &"attack_'+str(number)+'"\ncommit_resources = true\naction_rules = {"move": false, "jump": false, "turn": false, "super_armor": true}\n'
        if number<=2:text+='attack_segments = Array[ExtResource("segment")]([SubResource("Segment")])\n'
        if number>=2:text+='events = Array[ExtResource("event")]([SubResource("ObjectEvent")])\n'
        text+='[resource]\nscript = ExtResource("definition")\nability_id = &"jushi_lingjun_skill'+str(number)+'"\nability_name = '+g(titles[number-1])+'\nfeatures = Array[ExtResource("feature")]([SubResource("Cooldown"),SubResource("Timeline")])\nmetadata/original_skill_id = '+str(id)+'\n'
        write(BASE+('/skill.tres' if number==1 else '/skill'+str(number)+'.tres'),text)
    def object_config(name,part,skill,kind,animation,continuation=''):
        text='[gd_resource type="Resource" script_class="BattleBossObjectDefinition" format=3]\n[ext_resource type="Script" path="res://addons/battle_foundation/boss/battle_boss_object_definition.gd" id="script"]\n[resource]\nscript = ExtResource("script")\n'
        vals={'object_id': '&"'+('pipa_notes' if name=='note' else 'jade_wall')+'"','kind':g(kind),'animation':'&"'+animation+'"','continuation_animation':'&"'+continuation+'"','formation_seconds':str(len(actions[animation])/30 if continuation else 0),'lifetime':str(len(actions[animation])/30+5 if continuation else part['shootTime']),'speed':str(part['shootSpeed']),'spawn_offset':f'Vector2({part["x"]},{part["y"]})','angles':'Array[float](['+(', '.join(str((i-2)*20) for i in range(5)) if name=='note' else '0.0')+'])','linked_to_action':g(part.get('linkParentState',False)),'through_targets':g(part['shootThrough']),'maximum_hits':str(part.get('atkMax',skill['atkMax'])),'hit_interval':str(part.get('atkInterval',0.1)),'damage_context':g({'protection_skill_id':str(skill['id']),'hit_stun':part.get('stiff',skill.get('stiff',0)),'reaction_gravity':1980,'reset_vertical_velocity':True,'knockback_speed':80 if name=='note' else 0,'launch_speed':360 if name=='note' else 0,'knockback_duration':0.5 if name=='note' else 0.3,'reaction_type':'launch' if name=='note' else 'hurt'})}
        for key,value in vals.items():text+=key+' = '+value+'\n'
        for key,clip in [('hit_rects',animation),('continuation_rects',continuation)]:
            if clip:text+=key+' = Dictionary[int, Rect2]({'+', '.join(str(r['frame'])+': '+rect(r) for r in ab[clip])+'})\n'
        write(BASE+'/'+name+'.tres',text)
    object_config('note',config['Skill']['2001110']['param']['s'][0],config['Skill']['2001110'],'projectile','skill2_1')
    object_config('wall',config['Skill']['2001120']['param']['s'][0],config['Skill']['2001120'],'wall','skill3_1','skill3_2')
    text='[gd_resource type="Resource" script_class="BattleBossProfile" format=3]\n[ext_resource type="Script" path="res://addons/battle_foundation/boss/battle_boss_profile.gd" id="profile"]\n[ext_resource type="Script" path="res://addons/battle_foundation/boss/battle_boss_skill_rule.gd" id="rule"]\n'
    for num,id in [(2,2001110),(3,2001120)]:text+=f'[ext_resource type="Texture2D" path="res://assets/ui/boss/{id}.png" id="banner{num}"]\n'
    for num in [1,2,3]:
        text+=f'[sub_resource type="Resource" id="Rule{num}"]\nscript = ExtResource("rule")\nability_id = &"jushi_lingjun_skill{num}"\npriority = {1 if num==2 else 0}\ncooldown_group = &"'+('pipa' if num==2 else 'alternate')+'"\ngroup_cooldown = '+('5.0' if num==2 else '10.0')+'\nattack_range = '+str({1:300,2:1000,3:700}[num])+'\n'
        if num>=2:text+=f'announcement = ExtResource("banner{num}")\n'
    text+='[resource]\nscript = ExtResource("profile")\ndisplay_name = "玉石琵琶精"\nskills = Array[ExtResource("rule")]([SubResource("Rule1"),SubResource("Rule2"),SubResource("Rule3")])\n'
    write(BASE+'/boss.tres',text)
    write(BASE+'/protection.tres','[gd_resource type="Resource" script_class="BattleProtectionProfile" format=3]\n[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_protection_profile.gd" id="script"]\n[resource]\nscript = ExtResource("script")\noriginal_boss_key = "Monster/10601"\nprotect_seconds = 0.8\nblocks_damage = true\nblocks_status = true\n')
    definition=(PROJECT/BASE/'definition.tres').read_text(encoding='utf8');definition=re.sub(r'ability_ids = .*','ability_ids = Array[StringName]([&"jushi_lingjun_skill1",&"jushi_lingjun_skill2",&"jushi_lingjun_skill3"])',definition);write(BASE+'/definition.tres',definition)
    monster=(PROJECT/BASE/'monster.tscn').read_text(encoding='utf8')
    monster=monster.replace('res://addons/battle_foundation/ai/battle_ai_controller_2d.gd','res://addons/battle_foundation/boss/battle_boss_controller_2d.gd')
    if 'id="boss_profile"' not in monster:
        pos=monster.index('[sub_resource');monster=monster[:pos]+f'[ext_resource type="Resource" path="res://{BASE}/boss.tres" id="boss_profile"]\n[ext_resource type="Resource" path="res://{BASE}/protection.tres" id="protect_profile"]\n[ext_resource type="Script" path="res://addons/battle_foundation/boss/battle_boss_object_pool_2d.gd" id="object_pool"]\n[ext_resource type="PackedScene" path="res://{BASE}/note.tscn" id="note"]\n[ext_resource type="PackedScene" path="res://{BASE}/wall.tscn" id="wall"]\n'+monster[pos:]
        monster=monster.replace('action_profile = ExtResource("actions")','action_profile = ExtResource("actions")\nprotection_profile = ExtResource("protect_profile")')
        monster=monster.replace('profile = ExtResource("ai_profile")','profile = ExtResource("ai_profile")\nboss_profile = ExtResource("boss_profile")')
        monster+='[node name="BossObjects" type="Node2D" parent="."]\nscript = ExtResource("object_pool")\n'
        for i in range(5):monster+=f'[node name="Note{i+1}" parent="BossObjects" instance=ExtResource("note")]\n'
        for i in range(3):monster+=f'[node name="Wall{i+1}" parent="BossObjects" instance=ExtResource("wall")]\n'
    write(BASE+'/monster.tscn',monster)
    attributes=(PROJECT/BASE/'attributes.tres').read_text(encoding='utf8')
    for key,value in [('soilResist',10),('fireResist',-10)]:attributes=re.sub(r'ExtResource\("'+key+r'"\): [-\d.]+',f'ExtResource("{key}"): {float(value)}',attributes)
    write(BASE+'/attributes.tres',attributes)
    for file in ['data/levels/biyujing/progression/manifest.json']:
        manifest=json.loads((PROJECT/file).read_text(encoding='utf8'))
        for num in [2,3]:manifest['definitions']['skills']['jushi_lingjun_skill'+str(num)]=f'res://{BASE}/skill{num}.tres'
        dump(file,manifest)
    mapping=json.loads((PROJECT/'data/damage/skill_mapping.json').read_text(encoding='utf8'));table=json.loads((PROJECT/'data/damage/original_skills.json').read_text(encoding='utf8'))
    for i,id in enumerate(skill_ids,1):mapping['jushi_lingjun_skill'+str(i)]=id;table[str(id)]=dict(config['Skill'][str(id)],source_skill_id=id)
    dump('data/damage/skill_mapping.json',mapping);dump('data/damage/original_skills.json',table)
    return ab
#endregion

#region Offline import entry and evidence
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--original-root',type=Path,required=True);args=parser.parse_args();original=args.original_root
    sys.path.insert(0,str(original));from backends.zmhj_config import load_config_archive
    config=load_config_archive(original/'games/zmhj-g5');actions,resources=atlas_resources()
    ui=PROJECT/'assets/ui/boss';ui.mkdir(parents=True,exist_ok=True)
    for id in [2001110,2001120]:shutil.copyfile(original/f'games/zmhj-g5/cache/assets/icon/skill/dialog/{id}.png',ui/f'{id}.png')
    exported=PROJECT/'.cleanup-backup/boss-ui-export'
    subprocess.run(['java', '-Djava.awt.headless=true', '-cp', str(original/'out/swfutil/ffdec_lib_20.1.0/*'), str(PROJECT/'tools/ExportOriginalBossUI.java'), str(original/'games/zmhj-g5/cache/assets/ui/mission_20260406_1.swf'), str(exported)], check=True)
    for name in ['boosBleedBar','bossbar1','bossbar2','bossbar3','bossComing','protect','frame']:
        images=sorted((exported/name).rglob('*.png'))
        if not images:raise RuntimeError('Missing exported Boss UI: '+name)
        shutil.copyfile(images[0],ui/(name+'.png'))
    audio=PROJECT/'assets/audio/boss';audio.mkdir(parents=True,exist_ok=True)
    tracks=sound_tags(original/'games/zmhj-g5/cache/assets/music/bg/boss_01.swf')
    sound_evidence=[]
    for name,content in tracks.items():
        (audio/'boss_01.mp3').write_bytes(content);sound_evidence.append({'name':name,'file':'boss_01.mp3','sha256':hashlib.sha256(content).hexdigest()});break
    common=sound_tags(original/'games/zmhj-g5/cache/assets/music/hs.swf')
    for key in ['hit','win','lose']:
        if key in common:
            (audio/(key+'.mp3')).write_bytes(common[key]);sound_evidence.append({'name':key,'file':key+'.mp3','sha256':hashlib.sha256(common[key]).hexdigest()})
    ab=import_definitions(original,config,actions);animations(actions,resources)
    behavior=ET.fromstring(config['Behavior']);needed={'111005','111010','2041','2042','2043','207001002','6'}
    sources=[source_hash(original,p) for p in ['games/zmhj-g5/cache/assets/man/11106/1_V226.swf','games/zmhj-g5/cache/assets/ui/mission_20260406_1.swf','games/zmhj-g5/cache/assets/music/bg/boss_01.swf','games/zmhj-g5/cache/assets/music/hs.swf','games/zmhj-g5/cache/assets/icon/skill/dialog/2001110.png','games/zmhj-g5/cache/assets/icon/skill/dialog/2001120.png','out/zmhj-equip-skill-diag/viewers/component/SkillComing.as','out/zmhj-equip-skill-diag/viewers/component/BossBleed.as','out/zmhj-equip-skill-diag/com/wdcgame/engine/entitys/AIHpProtectControl.as']]
    dump(BASE+'/original_boss.json',{'sources':sources,'monster':config['Monster']['10601'],'resource':config['Resource']['11106'],'skills':{k:config['Skill'][k] for k in ['2001100','2001110','2001120','1900010']},'ai':clean(config['MAi']['10009']),'behavior':[{y.tag:y.text for y in x} for x in behavior if x.findtext('id') in needed],'animations':{k:len(v) for k,v in actions.items()},'bounds':ab,'sounds':sound_evidence,'scope':{'hp_phases':False,'monster_summoning':False,'ordinary_boss':True}})
    print('Imported original 3 Boss skills, 5 notes, delayed physical wall, authored animations, announcement icons, Boss UI and audio')
if __name__=='__main__': main()
#endregion
