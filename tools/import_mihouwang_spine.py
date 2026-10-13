"""Convert the supplied DragonBones 2.2 XML/PLIST to native Spine 4.3.

Flatten nested armatures into independent animated bones (not baked pictures).
Sample legacy tween/pivot/skew/color/z-order at the source's 60 Hz. Runtime
requires only the generated Spine assets, never DragonBones or external paths.
Format reference: https://en.esotericsoftware.com/spine-json-format
"""
from pathlib import Path
import argparse, bisect, copy, hashlib, json, math, plistlib, re, shutil
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT/'assets/monsters/zaomeng1/mihou_king'
FOLDER = ROOT/'data/monsters/zaomeng1/mihou_king'
IDENTITY = (1., 0., 0., 1., 0., 0.)


def num(node, key, default=0.):
    return float(node.get(key, default))


def multiply(p, q):
    a,b,c,d,x,y = p; e,f,g,h,u,v = q
    return a*e+c*f,b*e+d*f,a*g+c*h,b*g+d*h,a*u+c*v+x,b*u+d*v+y


def matrix(frame):
    kx,ky = math.radians(num(frame,'kX')),math.radians(num(frame,'kY'))
    sx,sy = num(frame,'cX',1),num(frame,'cY',1)
    a,b,c,d = sx*math.cos(ky),sx*math.sin(ky),-sy*math.sin(kx),sy*math.cos(kx)
    # Both bone pivots and display pivots exist in this legacy Flash exporter.
    px,py = num(frame,'pX'),num(frame,'pY')
    return a,b,c,d,num(frame,'x')-a*px-c*py,num(frame,'y')-b*px-d*py


def easing(progress, value):
    if value > 1:
        eased = .5*(1-math.cos(progress*math.pi)); value -= 1
    elif value > 0:
        eased = 1-(1-progress)**2
    else:
        eased = progress*progress; value = -value
    return progress+(eased-progress)*value


class Legacy:
    def __init__(self, path):
        self.root = ET.parse(path).getroot()
        self.fps = int(self.root.get('frameRate'))
        self.arms = {a.get('name'):a for a in self.root.findall('./armatures/armature')}
        self.clips = {a.get('name'):{m.get('name'):m for m in a} for a in self.root.findall('./animations/animation')}
        self.tracks = {}
        for arm, clips in self.clips.items():
            for name, clip in clips.items():
                for track in clip:
                    starts=[];cursor=0
                    for frame in track:
                        starts.append(cursor);cursor+=int(frame.get('dr','1'))
                    self.tracks[arm,name,track.get('name')]=(track,starts,cursor)

    def sample(self, arm, clip, bone, tick):
        value = self.tracks.get((arm,clip,bone.get('name')))
        if value is None:
            return None,0
        track,starts,total = value
        tick=tick/num(track,'sc',1)+num(track,'dl')*total
        tick=max(0,min(tick,total-1e-8))
        i=bisect.bisect_right(starts,tick)-1;current=track[i]
        frame=dict(current.attrib)
        if i+1<len(track) and num(current,'dI')>=0:
            following=track[i+1]
            tween=num(current,'twE',float('nan'))
            if math.isfinite(tween) and num(following,'dI')>=0:
                p=easing((tick-starts[i])/int(current.get('dr','1')),tween)
                for key in ('x','y','kX','kY','cX','cY','pX','pY'):
                    default=1 if key in ('cX','cY') else 0
                    a,b=num(current,key,default),num(following,key,default)
                    if key in ('kX','kY'):b=a+(b-a+180)%360-180
                    frame[key]=str(a+(b-a)*p)
        color=current.find('colorTransform')
        frame['rgba']=tuple(num(color,k,100)/100 if color is not None else 1 for k in ('rM','gM','bM','aM'))
        # A nested armature keeps playing across transform keys. Restart only
        # when its display changes or a new explicit mov action is authored.
        anchor=0
        for j in range(i+1):
            if j==0 or track[j].get('dI')!=track[j-1].get('dI') or track[j].get('mov'):
                anchor=starts[j]
            if track[j].get('mov'):frame['mov']=track[j].get('mov')
        return frame,tick-anchor

    def pose(self, arm, clip, tick, parent=IDENTITY, prefix='', parent_color=(1,1,1,1)):
        layers=[]
        for bone in self.arms[arm]:
            frame,elapsed=self.sample(arm,clip,bone,tick)
            if frame is None or num(frame,'dI')<0:continue
            displays=list(bone);di=int(num(frame,'dI'))
            if di>=len(displays):raise ValueError(f'Bad display {arm}/{bone.get("name")}/{di}')
            display=displays[di];name=display.get('name')
            world=multiply(parent,matrix(frame));path=prefix+bone.get('name')
            rgba=tuple(a*b for a,b in zip(parent_color,frame['rgba']))
            if display.get('isArmature')=='1':
                childclip=frame.get('mov','idle')
                if childclip not in self.clips[name]:raise ValueError(f'Missing nested clip {name}/{childclip}')
                duration=int(self.clips[name][childclip].get('dr'))
                children=self.pose(name,childclip,elapsed%duration,world,path+'__'+name+'__',rgba)
                layers.append((num(frame,'z'),children))
            elif name in self.regions:
                layers.append((num(frame,'z'),[(path,name,display,world,rgba)]))
            elif bone.get('name') not in ('collision','attack'):
                raise ValueError(f'Missing atlas region {name}')
        return [leaf for _, leaves in sorted(layers,key=lambda a:a[0]) for leaf in leaves]

    def collect(self, arm, prefix=''):
        result={}
        for b in self.arms[arm]:
            path=prefix+b.get('name')
            for d in b:
                if d.get('isArmature')=='1':result.update(self.collect(d.get('name'),path+'__'+d.get('name')+'__'))
                elif d.get('name') in self.regions:
                    result.setdefault(path,{})[d.get('name')]=d
        return result


def rounded(value):
    return round(value,6)


def bone_pose(world):
    a,b,c,d,x,y=world
    rotation=math.degrees(math.atan2(-b,a))
    shear=(math.degrees(math.atan2(d,-c))-rotation-90+180)%360-180
    return {'translate':{'x':rounded(x),'y':rounded(-y)},
            'rotate':{'value':rounded(rotation)},
            'scale':{'x':rounded(math.hypot(a,b)),'y':rounded(math.hypot(c,d))},
            'shear':{'x':0,'y':rounded(shear)}}


def convert(source=None):
    saved=ASSET/'dragonbones_source'
    if source:
        source=Path(source)
        saved.mkdir(parents=True,exist_ok=True)
        for ext in ('xml','plist','png'):shutil.copyfile(source.with_suffix('.'+ext),saved/('mihouwang.'+ext))
    legacy=Legacy(saved/'mihouwang.xml')
    atlas=plistlib.load((saved/'mihouwang.plist').open('rb'))
    legacy.regions={name.removesuffix('.png'):frame for name,frame in atlas['frames'].items()}
    leaves=legacy.collect('mihouwang');names=list(leaves);indices={name:i for i,name in enumerate(names)}
    attachments={}
    for path,displays in leaves.items():
        attachments[path]={}
        for name,display in displays.items():
            w,h=map(float,re.findall(r'-?\d+(?:\.\d+)?',legacy.regions[name]['sourceSize']))
            attachments[path][name]={'type':'region','path':name,'width':w,'height':h,
                'x':rounded(w/2-num(display,'pX')),'y':rounded(num(display,'pY')-h/2)}
    animations={}; source_lengths={}
    for name,clip in legacy.clips['mihouwang'].items():
        count=int(clip.get('dr'));source_lengths[name]=count/legacy.fps
        slots={n:{'attachment':[]} for n in names};bones={n:{} for n in names}
        previous={};orders=[];previous_order=None
        for tick in range(count):
            time=rounded(tick/legacy.fps);pose=legacy.pose('mihouwang',name,tick)
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
        animations[name]={'slots':slots,'bones':bones,'drawOrder':orders}
    # Native attacks retain their source names and timing. Only common actor
    # states need semantic aliases; no ZMX1 Boss4 attack retiming remains.
    mappings={'move':'run','jump_2':'doublejump','fall':'jumpdown','land':'ground',
              'recover':'ground','protect':'passiveskill1','death':'dead'}
    lengths=dict(source_lengths)
    for alias,source_name in mappings.items():
        length=source_lengths[source_name]
        factor=length/source_lengths[source_name]
        animations[alias]=copy.deepcopy(animations[source_name])
        def retime(value):
            if isinstance(value,dict):
                for k,v in value.items():
                    if k=='time':value[k]=rounded(v*factor)
                    else:retime(v)
            elif isinstance(value,list):
                for v in value:retime(v)
        retime(animations[alias]);lengths[alias]=length
    lengths['idle']=source_lengths['idle'];lengths['run']=source_lengths['run'];lengths['jump']=source_lengths['jump'];lengths['hurt']=source_lengths['hurt']
    # Source character is ~90px tall. Match its world height to the established
    # 270-unit Boss capsule without moving the root/feet or attack areas.
    display_scale=3.0
    skeleton={'skeleton':{'spine':'4.3.00','fps':legacy.fps,'images':'./'},
        'bones':[{'name':'root'}]+[{'name':n,'parent':'root'} for n in names],
        'slots':[{'name':n,'bone':n} for n in names],
        'skins':[{'name':'基础','attachments':attachments}],'animations':animations}
    (ASSET/'monster.spine-json').write_text(json.dumps(skeleton,ensure_ascii=False,separators=(',',':'))+'\n','utf8')
    shutil.copyfile(saved/'mihouwang.png',ASSET/'atlas.png')
    size=atlas['metadata']['size'];w,h=map(int,re.findall(r'\d+',size))
    lines=['atlas.png',f'size:{w},{h}','filter:Linear,Linear','pma:false']
    for name,frame in legacy.regions.items():
        if frame['rotated']:raise ValueError('Unexpected rotated source region')
        x,y,w,h=map(int,re.findall(r'-?\d+',frame['frame']))
        lines+=[name,f'bounds:{x},{y},{w},{h}']
        original=list(map(int,re.findall(r'\d+',frame['sourceSize'])))
        rect=list(map(int,re.findall(r'-?\d+',frame['sourceColorRect'])))
        if original!=[w,h]:lines+=[f'offsets:{rect[0]},{original[1]-rect[1]-h},{original[0]},{original[1]}']
    (ASSET/'monster.atlas').write_text('\n'.join(lines)+'\n','utf8')
    metadata={'format':'Spine 4.3 sampled skeletal transforms','source':'DragonBones 2.2 mihouwang',
              'fps':legacy.fps,'source_actions':source_lengths,'gameplay_aliases':mappings,
              'gameplay_attack_durations':{n:l for n,l in lengths.items() if n.startswith(('attack','skill')) or n in ('runattack','jumpattack')},
              'bones':len(names)+1,'regions':len(legacy.regions),'nested_armatures':3,'display_scale':display_scale,
              'source_hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in saved.iterdir() if p.suffix in ('.xml','.plist','.png')}}
    (ASSET/'spine_conversion.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n','utf8')
    from author_mihouwang_skills import author
    author(lengths)
    from import_mihouwang_effects import author as author_effects
    author_effects()
    print(f'Converted {len(source_lengths)} original clips + {len(mappings)} aliases, {len(names)+1} bones, 3 nested armatures, {len(legacy.regions)} regions')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',help='Path to the supplied XML; copies XML/PLIST/PNG for reproducible authoring')
    convert(parser.parse_args().source)
