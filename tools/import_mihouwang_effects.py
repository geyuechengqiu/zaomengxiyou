"""Convert the supplied Mihouwang effect XMLs to Spine and bind saved timelines.

Native FPS and frame lengths are preserved. Initial attachment offsets use the
character hit markers; skill2's start is aligned with its 12..39 hidden frames,
skill3 starts with its complete 218-frame build sequence. Authoring is idempotent
and keeps manually edited effect transforms, tracks and attack rectangles.
"""
from pathlib import Path
import argparse, hashlib, json, math, plistlib, re, shutil
from import_mihouwang_spine import Legacy, rounded, bone_pose

ROOT=Path(__file__).resolve().parents[1]
ASSET=ROOT/'assets/effects/mihouwang'
FOLDER=ROOT/'data/monsters/zaomeng1/mihou_king'
BINDINGS={
    'attack1':('attack1',4), 'attack2':('attack2',4),
    'attack3':('attack3',2), 'attack4':('attack4',22),
    'jumpattack':('jumpattack',6), 'runattack':('runattack',11),
    'runattack1':('runattack',11), 'skill1':('skill1',14),
    'skill2':('skill2',12), 'skill3':('skill3',0),
}

def write(path,text):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(text.rstrip()+'\n','utf8')

def convert_effect(saved, output, name):
    legacy=Legacy(saved/(name+'.xml'))
    atlas=plistlib.load((saved/(name+'.plist')).open('rb'))
    legacy.regions={key.removesuffix('.png'):value for key,value in atlas['frames'].items()}
    leaves=legacy.collect(name);names=list(leaves);indices={n:i for i,n in enumerate(names)}
    attachments={}
    for path,displays in leaves.items():
        attachments[path]={}
        for region,display in displays.items():
            w,h=map(float,re.findall(r'-?\d+(?:\.\d+)?',legacy.regions[region]['sourceSize']))
            attachments[path][region]={'type':'region','path':region,'width':w,'height':h,
                'x':rounded(w/2-float(display.get('pX',0))),
                'y':rounded(float(display.get('pY',0))-h/2)}
    animations={};lengths={}
    for action,clip in legacy.clips[name].items():
        count=int(clip.get('dr'));lengths[action]=count/legacy.fps
        slots={n:{'attachment':[]} for n in names};bones={n:{} for n in names}
        previous={};orders=[];previous_order=None
        for tick in range(count):
            time=rounded(tick/legacy.fps);pose=legacy.pose(name,action,tick)
            active={p[0]:p for p in pose}
            order=[p[0] for p in pose]+[n for n in names if n not in active]
            if order!=previous_order:
                positions={n:i for i,n in enumerate(order)}
                orders.append({'time':time,'offsets':[{'slot':n,'offset':positions[n]-indices[n]} for n in names]})
                previous_order=order
            for path in names:
                leaf=active.get(path);attachment=leaf[1] if leaf else None
                if previous.get((path,'attachment'),object())!=attachment:
                    slots[path]['attachment'].append({'time':time,'name':attachment});previous[path,'attachment']=attachment
                if leaf:
                    for kind,value in bone_pose(leaf[3]).items():
                        if previous.get((path,kind))!=value:
                            bones[path].setdefault(kind,[]).append({'time':time,**value,'curve':'stepped'});previous[path,kind]=value
                    rgba=''.join(f'{max(0,min(255,round(v*255))):02x}' for v in leaf[4])
                    if previous.get((path,'rgba'))!=rgba:
                        slots[path].setdefault('rgba',[]).append({'time':time,'color':rgba,'curve':'stepped'});previous[path,'rgba']=rgba
        bones['root']={'translate':[{'time':count/legacy.fps,'x':0,'y':0}]}
        animations[action]={'slots':slots,'bones':bones,'drawOrder':orders}
    skeleton={'skeleton':{'spine':'4.3.00','fps':legacy.fps,'images':'./'},
        'bones':[{'name':'root'}]+[{'name':n,'parent':'root'} for n in names],
        'slots':[{'name':n,'bone':n} for n in names],
        'skins':[{'name':'default','attachments':attachments}],'animations':animations}
    write(output/'effect.spine-json',json.dumps(skeleton,ensure_ascii=False,separators=(',',':')))
    shutil.copyfile(saved/(name+'.png'),output/'atlas.png')
    width,height=map(int,re.findall(r'\d+',atlas['metadata']['size']))
    lines=['atlas.png',f'size:{width},{height}','filter:Linear,Linear','pma:false']
    for region,frame in legacy.regions.items():
        if frame['rotated']:raise ValueError('Unexpected rotated region: '+region)
        x,y,w,h=map(int,re.findall(r'-?\d+',frame['frame']))
        lines += [region,f'bounds:{x},{y},{w},{h}']
        original=list(map(int,re.findall(r'\d+',frame['sourceSize'])))
        rect=list(map(int,re.findall(r'-?\d+',frame['sourceColorRect'])))
        if original!=[w,h]:lines += [f'offsets:{rect[0]},{original[1]-rect[1]-h},{original[0]},{original[1]}']
    write(output/'effect.atlas','\n'.join(lines))
    path=output.relative_to(ROOT).as_posix()
    write(output/'spinedata.tres',f'''[gd_resource type="SpineSkeletonDataResource" format=3]
[ext_resource type="SpineAtlasResource" path="res://{path}/effect.atlas" id="atlas"]
[ext_resource type="SpineSkeletonFileResource" path="res://{path}/effect.spine-json" id="skeleton"]
[resource]
atlas_res = ExtResource("atlas")
skeleton_file_res = ExtResource("skeleton")
''')
    return {'fps':legacy.fps,'actions':lengths,'bones':len(names)+1,
            'nested_armatures':len(legacy.arms)-1,'regions':len(legacy.regions),
            'source_hashes':{ext:hashlib.sha256((saved/(name+'.'+ext)).read_bytes()).hexdigest() for ext in ('xml','plist','png')}}

def value_track(index,path,times,values,discrete=True):
    return f'''tracks/{index}/type = "value"
tracks/{index}/path = NodePath("{path}")
tracks/{index}/keys = {{"times": PackedFloat32Array({','.join(map(str,times))}), "transitions": PackedFloat32Array({','.join('1' for _ in times)}), "update": {1 if discrete else 0}, "values": [{','.join(values)}]}}
'''

def attach(data):
    scene=FOLDER/'visual.tscn';text=scene.read_text('utf8')
    if 'id="mihouwang_effects"' in text:return False
    # All transforms and tracks live in saved scenes; runtime creates no effects.
    ref='[ext_resource type="PackedScene" path="res://data/monsters/zaomeng1/mihou_king/effects.tscn" id="mihouwang_effects"]\n'
    pos=text.index('[sub_resource');text=text[:pos]+ref+text[pos:]
    source_lengths=json.loads((ROOT/'assets/monsters/zaomeng1/mihou_king/spine_conversion.json').read_text('utf8'))['source_actions']
    tails={}
    pattern=r'\[sub_resource type="Animation" id="Master_([^\"]+)"\]\n.*?(?=\n\[|\Z)'
    def bind(match):
        block=match.group();action=match[1]
        index=max(map(int,re.findall(r'tracks/(\d+)/type',block)),default=-1)+1
        duration=float(re.search(r'length = ([\d.]+)',block)[1])
        block+='\n'+value_track(index,'AttackEffects:preview_action',[0],[f'&"{action}"'])
        block+=value_track(index+1,'AttackEffects:preview_time',[0,duration],['0.0',str(duration)],False);index+=2
        for effect,item in data.items():
            if item['action']!=action:continue
            if item['action'] in ('skill1','runattack'):continue # Detached projectile scenes, not actor effects.
            start=item['start_frame']/60;end=start+item['actions']['build']
            times=[0,start,end] if start>0 else [0,end]
            visible=['false','true','false'] if start>0 else ['true','false']
            clips=['RESET','build','RESET'] if start>0 else ['build','RESET']
            path='AttackEffects/'+effect
            block+=value_track(index,path+':visible',times,visible)
            block+=f'''tracks/{index+1}/type = "animation"
tracks/{index+1}/path = NodePath("{path}/SpineAnimationTrack/AnimationPlayer")
tracks/{index+1}/keys = {{"times": PackedFloat32Array({','.join(map(str,times))}), "clips": PackedStringArray({','.join(json.dumps(c) for c in clips)})}}
'''
            index+=2;tails[action]=max(tails.get(action,0),math.ceil(end*60-1e-6)-round(source_lengths[action]*60))
        return block.rstrip()+'\n'
    text=re.sub(pattern,bind,text,flags=re.S)
    # Append before editable-path directives to keep Godot block ownership clear.
    marker='[editable path=';pos=text.find(marker)
    node='[node name="AttackEffects" parent="." instance=ExtResource("mihouwang_effects")]\n\n[editable path="AttackEffects"]\n'
    text=text[:pos]+node+'\n'+text[pos:] if pos>=0 else text+'\n'+node
    write(scene,text)
    for action,frames in tails.items():
        if frames<=0:continue
        file=FOLDER/'skills'/(action+'.tres');s=file.read_text('utf8')
        if 'effect_tail_frames = ' in s:continue
        s=s.replace('commit_resources = true',f'commit_resources = true\neffect_tail_frames = {frames}')
        write(file,s)
    return True

def author(source=None):
    saved=ASSET/'dragonbones_source'
    if source:
        saved.mkdir(parents=True,exist_ok=True);write(saved/'.gdignore','')
        for file in Path(source).iterdir():
            if file.suffix.lower() in ('.xml','.plist','.png'):shutil.copyfile(file,saved/file.name)
    if not saved.exists():return
    data={}
    for effect,(action,start) in BINDINGS.items():
        output=ASSET/effect;output.mkdir(parents=True,exist_ok=True)
        info=convert_effect(saved,output,'mihouwang_'+effect)
        data[effect]={**info,'action':action,'start_frame':start,'placement':'projectile' if action in ('skill1','runattack') else 'actor'}
    # Only first attachment authors scene transforms/keys; later asset imports
    # preserve the user's modifications in effects.tscn and visual.tscn.
    file=FOLDER/'effects.tscn'
    if not file.exists():
        attached_data={key:value for key,value in data.items() if value['placement']=='actor'}
        text='''[gd_scene format=3]
[ext_resource type="Script" path="res://addons/battle_foundation/animation/BattleSpineEffectPreview2D.cs" id="preview"]
'''
        for effect in attached_data:text+=f'[ext_resource type="SpineSkeletonDataResource" path="res://assets/effects/mihouwang/{effect}/spinedata.tres" id="{effect}"]\n'
        for effect,item in attached_data.items():
            duration=item['actions']['build']
            for clip,animation_name in [('build','build'),('RESET','')]:
                text+=f'[sub_resource type="Animation" id="{effect}_{clip}"]\nlength = {duration if clip=="build" else 0.001}\n'
                text+=value_track(0,'.:animation_name',[0],[json.dumps(animation_name)])+value_track(1,'.:loop',[0],['false'])
            text+=f'[sub_resource type="AnimationLibrary" id="{effect}"]\n_data = {{&"build": SubResource("{effect}_build"), &"RESET": SubResource("{effect}_RESET")}}\n'
        text+='''[node name="AttackEffects" type="Node2D"]
process_priority = 100
z_index = 1
scale = Vector2(3,3)
script = ExtResource("preview")
'''
        for effect in attached_data:
            text+=f'''[node name="{effect}" type="SpineSprite" parent="."]
visible = false
skeleton_data_res = ExtResource("{effect}")
update_mode = 2
preview_skin = "default"
preview_animation = "-- Empty --"
preview_frame = false
[node name="SpineAnimationTrack" type="SpineAnimationTrack" parent="{effect}"]
mix_duration = 0.0
[node name="AnimationPlayer" type="AnimationPlayer" parent="{effect}/SpineAnimationTrack"]
callback_mode_process = 2
libraries/ = SubResource("{effect}")
'''
        write(file,text)
    attached=attach(data)
    write(ASSET/'conversion.json',json.dumps({'format':'Spine 4.3','effects':data,
        'binding_basis':'Initial offsets from character hit markers; skill2 hidden12..39 and skill3 complete build0..218. Saved AnimationPlayer tracks are editable.'},ensure_ascii=False,indent=2))
    print(f'Converted {len(data)} native effects, 24/60 FPS preserved, scene attachment={attached}')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path)
    author(parser.parse_args().source)
