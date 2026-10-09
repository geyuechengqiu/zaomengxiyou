"""Read-only original map art export; author continuous visual layers and reuse the map template."""
from pathlib import Path
import argparse, csv, hashlib, json, re, shutil, struct, subprocess, xml.etree.ElementTree as ET

#region Original-source provenance and scene helpers
PROJECT = Path(__file__).resolve().parents[1]
BASE = 'data/levels/biyujing/progression'
ASSETS = 'assets/maps/biyujing'

def write(name, text):
    path = PROJECT/name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf8')

def png_size(path): return struct.unpack('>II', path.read_bytes()[16:24])
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def properties(element): return {p.get('name'):p.get('value',p.text or '') for p in element.findall('properties/property')}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--original-root',type=Path,default=Path('D:/UserData/Downloads/game/Speculum-4399-master'))
    original=parser.parse_args().original_root
    export=PROJECT/'.cleanup-backup/biyujing-map-export'
    source=original/'games/zmhj-g5/cache/assets/map/No_1-1_V283.swf'
    tmx=original/'games/zmhj-g5/cache/assets/map/No_1-1_V283.tmx'
    subprocess.run(['java','-Djava.awt.headless=true','-Dfile.encoding=UTF-8','-cp',str(original/'out/swfutil/ffdec_lib_20.1.0/*'),str(PROJECT/'tools/ExportOriginalMapImages.java'),str(source),str(export)],check=True)
    images=list(csv.DictReader((export/'images.tsv').open(encoding='utf8'),delimiter='\t'))
    symbols=list(csv.DictReader((export/'symbols.tsv').open(encoding='utf8'),delimiter='\t'))
    cloud_rows=list(csv.DictReader((export/'cloud_timeline.tsv').open(encoding='utf8'),delimiter='\t'))
    cloud_frames=int(next(r['frames'] for r in symbols if '中景01' in r['classes'].split(';')))
    mapping={'远景':'far','中景02':'middle','中景01':'clouds','前景01':'ground_repeat','前景02':'ground_end','近景':'near'}
    textures={}; registrations={}; assets=[]
    for name,slug in mapping.items():
        if name=='中景01':
            row=next(r for r in symbols if name in r['classes'].split(';'))
            assert {r['character'] for r in cloud_rows}=={'10'}, 'Unexpected original cloud child symbol'
            file=export/'8.png'
            registration=[-png_size(file)[0]/2,-png_size(file)[1]/2]
        else:
            row=next(r for r in images if name in r['classes'].split(';'))
            file=export/(row['id']+'.png')
            registration=[0,0]
        destination=PROJECT/ASSETS/(slug+'.png');destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(file,destination)
        textures[name]=slug;registrations[name]=registration
        assets.append({'symbol':name,'character_id':int(row['id']),'file':slug+'.png','size':png_size(destination),'registration':registration,'sha256':digest(destination)})
    scene='[gd_scene format=3]\n[ext_resource type="PackedScene" path="res://addons/battle_foundation/level/battle_map_visual_template_2d.tscn" id="template"]\n[ext_resource type="Script" path="res://addons/battle_foundation/level/battle_map_occluder_2d.gd" id="occluder"]\n'
    for name,slug in textures.items(): scene+=f'[ext_resource type="Texture2D" path="res://{ASSETS}/{slug}.png" id="{slug}"]\n'
    scene+='[sub_resource type="Animation" id="CloudAnimation"]\nlength = '+str(cloud_frames/30)+'\nloop_mode = 1\n'
    depths=sorted({int(r['depth']) for r in cloud_rows})
    for track,depth in enumerate(depths):
        rows=[r for r in cloud_rows if int(r['depth'])==depth]
        assert len(rows)==cloud_frames and all(r['rotation_0']=='0' and r['rotation_1']=='0' and r['alpha']=='1.0' for r in rows)
        scene+=f'tracks/{track}/type = "value"\ntracks/{track}/path = NodePath("Cloud_{depth}:position")\ntracks/{track}/interp = 0\ntracks/{track}/keys = {{"times": PackedFloat32Array('+', '.join(f'{int(r["frame"])/30:.9f}' for r in rows)+'), "transitions": PackedFloat32Array('+', '.join('1' for r in rows)+'), "update": 1, "values": ['+', '.join('Vector2('+str(float(r['x'])*2)+','+str(float(r['y'])*2)+')' for r in rows)+']}\n'
    scene+='[sub_resource type="AnimationLibrary" id="CloudLibrary"]\n_data = {&"clouds": SubResource("CloudAnimation")}\n'
    scene+='[node name="BiyujingVisual" instance=ExtResource("template")]\nanimated_player_paths = Array[NodePath]([NodePath("FixedMiddle/CloudMotion/AnimationPlayer")])\n'
    tree=ET.parse(tmx).getroot();layers=[];instance_count=0
    for index,layer in enumerate(tree.findall('imagelayer')):
        name=layer.get('name');props=properties(layer);slug=textures[name]
        group={'远景':'FarBackground','中景02':'MiddleBackground','中景01':'FixedMiddle','前景01':'GroundArtwork','前景02':'GroundArtwork','近景':'ForegroundOccluders'}[name]
        repeat=int(props.get('repeat',1)); offset=[float(layer.get('offsetx',0)),float(layer.get('offsety',0))]
        size=next(a['size'] for a in assets if a['symbol']==name)
        layers.append({'name':name,'offset':offset,'properties':props,'actual_texture_size':size,'registration':registrations[name],'repeat':repeat})
        if name=='中景01':
            scene+='[node name="CloudMotion" type="Node2D" parent="FixedMiddle"]\nposition = Vector2(0,'+str(offset[1]*2)+')\n'
            for depth in depths:
                row=next(r for r in cloud_rows if int(r['depth'])==depth)
                scene+=f'[node name="Cloud_{depth}" type="Sprite2D" parent="FixedMiddle/CloudMotion"]\nposition = Vector2({float(row["x"])*2},{float(row["y"])*2})\nscale = Vector2({int(row["scale_x"])/65536*2},{int(row["scale_y"])/65536*2})\ntexture = ExtResource("clouds")\n'
                instance_count+=1
            scene+='[node name="AnimationPlayer" type="AnimationPlayer" parent="FixedMiddle/CloudMotion"]\ncallback_mode_process = 2\nlibraries/ = SubResource("CloudLibrary")\nautoplay = "clouds"\n'
            continue
        for number in range(repeat):
            x=(offset[0]+registrations[name][0]+number*size[0])*2
            y=(offset[1]+registrations[name][1])*2
            scene+=f'[node name="{slug}_{index}_{number}" type="Sprite2D" parent="{group}"]\nposition = Vector2({x},{y})\nscale = Vector2(2,2)\ncentered = false\ntexture = ExtResource("{slug}")\n'
            if group=='ForegroundOccluders':scene+='script = ExtResource("occluder")\nbarrier_alpha = '+props.get('barrierAlpha','1')+'\n'
            instance_count+=1
    write(BASE+'/visual.tscn',scene)
    # Keep physics, entity paths, spawn plans and Boss definitions intact.
    path=PROJECT/BASE/'map.tscn';data=path.read_text(encoding='utf8')
    if 'id="map_template"' not in data:
        at=data.index('[sub_resource')
        data=data[:at]+'[ext_resource type="PackedScene" path="res://addons/battle_foundation/level/battle_map_template_2d.tscn" id="map_template"]\n'+data[at:]
    if 'id="visuals"' not in data:
        at=data.index('[sub_resource')
        data=data[:at]+'[ext_resource type="PackedScene" path="res://'+BASE+'/visual.tscn" id="visuals"]\n'+data[at:]
    data=data.replace('[node name="Actors" type="Node2D"]','[node name="Actors" instance=ExtResource("map_template")]')
    if '[node name="BiyujingVisual"' not in data:
        data=data.replace('[node name="Actors" instance=ExtResource("map_template")]','[node name="Actors" instance=ExtResource("map_template")]\n[node name="BiyujingVisual" parent="Visuals" instance=ExtResource("visuals")]')
    for name in ['Terrain','SpawnPoints','Gates']:data=data.replace(f'[node name="{name}" type="Node2D" parent="."]\n','')
    data=re.sub(r'\[node name="Visual" type="Polygon2D" parent="Terrain/[^"\n]+"\]\n.*?(?=\[node|\Z)','',data,flags=re.S)
    birth=next(o for o in tree.findall('.//object') if o.get('type')=='birth')
    birth_node=f'[node name="PlayerBirth" parent="."]\nposition = Vector2({float(birth.get("x"))*2}, {float(birth.get("y"))*2})\n'
    data=re.sub(r'\[node name="PlayerBirth" parent="\."\]\n.*?(?=\[node|\Z)','',data,flags=re.S)
    data+=birth_node
    write(BASE+'/map.tscn',data)
    # Main scene no longer draws the temporary green mountains/background.
    main=PROJECT/'examples/level_progression_demo.tscn';data=main.read_text(encoding='utf8')
    data=re.sub(r'\[node name="Background".*?(?=\[node name="Camera2D")','',data,flags=re.S)
    write('examples/level_progression_demo.tscn',data)
    sources=['games/zmhj-g5/cache/assets/map/No_1-1_V283.swf','games/zmhj-g5/cache/assets/map/No_1-1_V283.tmx','out/zmhj-equip-skill-diag/com/wdcgame/tile/TMXTileMap.as','out/zmhj-equip-skill-diag/com/wdcgame/tile/display/TMXLayer.as','out/zmhj-equip-skill-diag/com/wdcgame/tile/utils/TMXResource.as','out/zmhj-equip-skill-diag/viewers/container/BattleMapBase.as','out/zmhj-equip-skill-diag/com/wdcgame/engine/animation/MovieClipAdvance.as','out/zmhj-equip-skill-diag/com/wdcgame/engine/core/GameFrame.as']
    evidence={'sources':[{'path':s,'sha256':digest(original/s)} for s in sources],'textures':assets,'layers':layers,'cloud_animation':{'source_frames':cloud_frames,'source_fps':30,'symbol_id':11,'child_symbol_id':10,'bitmap_id':8,'frames':cloud_rows},'authored_sprites':instance_count,'world_bounds':[0,0,10944,1216],'unit_scale':2,'scroll_scale_rule':'Godot scroll_scale = 1 - original speedX; isFixedX -> scroll_scale.x=0','depth_order':'layer1 -> layer2 -> layer3 -> actors -> layer4','continuous_map':True}
    write(ASSETS+'/original_source.json',json.dumps(evidence,ensure_ascii=False,indent=2)+'\n')
    provenance_path=PROJECT/BASE/'original_source.json'
    provenance=json.loads(provenance_path.read_text(encoding='utf8'))
    provenance['map_visual_source']='res://'+ASSETS+'/original_source.json'
    provenance['omissions']=[note for note in provenance['omissions'] if 'original map SWF art not ported' not in note and 'Boss combat currently' not in note]
    provenance['boss_implementation']='Stage 13 original three skills and dedicated controller: data/monsters/jushi_lingjun/README.md'
    write(BASE+'/original_source.json',json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
    print(f'Imported original Biyujing: {len(assets)} textures, {len(layers)} TMX layers, {instance_count} authored sprites, one continuous five-region map')

if __name__=='__main__':main()
#endregion
