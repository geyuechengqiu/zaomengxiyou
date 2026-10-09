"""Import original Biyujing TMX plans/screens into editor-authored Godot resources."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import sys
import xml.etree.ElementTree as ET
sys.dont_write_bytecode = True

#region Resource serialization and original configuration
PROJECT = Path(__file__).resolve().parents[1]

def write(path, text):
    target = PROJECT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding='utf-8')

def dump(path, value):
    write(path, json.dumps(value, ensure_ascii=False, indent=2) + '\n')

def props(obj):
    return {p.get('name'): p.get('value', p.text or '') for p in obj.findall('properties/property')}

def names(values):
    return 'Array[StringName]([' + ', '.join('&"'+v+'"' for v in values) + '])'

def rect(obj):
    return 'Rect2(' + ', '.join(str(float(obj.get(k, 0))*2) for k in ['x','y','width','height']) + ')'

def resource(path, cls, script, fields):
    write(path, '[gd_resource type="Resource" script_class="'+cls+'" format=3]\n'
        '[ext_resource type="Script" path="res://addons/battle_foundation/level/'+script+'.gd" id="script"]\n'
        '[resource]\nscript = ExtResource("script")\n' + fields)

def import_boss_assets(original, config):
    spec = importlib.util.spec_from_file_location('stage11', PROJECT/'tools/export_stage_eleven_monsters.py')
    exporter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(exporter)
    from backends.zmhj_config import _Amf3Reader, _read_one
    evidence = {}
    for slug, mid, display in [('revival_vessel','10501','复苏容器'), ('jushi_lingjun','10601','巨石灵君')]:
        cfg = config['Monster'][mid]
        skill = config['Skill'][str(cfg['skill1'])]
        source = original/'games/zmhj-g5/cache/assets/man'/config['Resource'][str(cfg['resourceId'])]['normal']
        atlas = exporter.export_atlas(source, slug, _Amf3Reader, _read_one)
        atlas['attack_bounds'] = {k:v for k,v in atlas['attack_bounds'].items() if k.startswith('skill1')}
        exporter.export_monster(slug, dict(cfg, name=display), skill, atlas)
        if mid == '10601':
            definition = PROJECT/f'data/monsters/{slug}/definition.tres'
            text = re.sub(r'^display_name = .*$', 'display_name = '+json.dumps(cfg['name'],ensure_ascii=False),definition.read_text(encoding='utf8'),flags=re.M)
            definition.write_text(text,encoding='utf8')
        scene_path = PROJECT/f'data/monsters/{slug}/monster.tscn'
        scene = scene_path.read_text(encoding='utf-8')
        # New templates must not borrow the source character/resource UIDs.
        scene = re.sub(r'\suid="[^"]+"', '', scene)
        if slug == 'revival_vessel':
            scene = scene.replace('script = ExtResource("ai")\n', 'script = ExtResource("ai")\nenabled = false\n')
            scene = scene.replace('script = ExtResource("entity")\n', 'script = ExtResource("entity")\nsuper_armor = true\n')
        scene_path.write_text(scene, encoding='utf-8')
        evidence[slug] = {'configuration': cfg, 'primary_skill': skill, 'atlas': atlas, 'source': source.relative_to(original).as_posix()}
        table_path = PROJECT/'data/damage/original_skills.json'
        table = json.loads(table_path.read_text(encoding='utf-8'))
        table[str(skill['id'])] = dict(skill, source_skill_id=skill['id'])
        dump('data/damage/original_skills.json', table)
        mapping = json.loads((PROJECT/'data/damage/skill_mapping.json').read_text(encoding='utf-8'))
        mapping[slug+'_skill1'] = skill['id']
        dump('data/damage/skill_mapping.json', mapping)
    return evidence
#endregion

#region Original screen/plan graph and authored map
def build(original):
    sys.path.insert(0, str(original))
    from backends.zmhj_config import load_config_archive
    config = load_config_archive(original/'games/zmhj-g5')
    tmx = original/'games/zmhj-g5/cache/assets/map/No_1-1_V283.tmx'
    root = ET.parse(tmx).getroot()
    objects = root.findall('objectgroup/object')
    births = {int(props(o)['id']): o for o in objects if o.get('type') == 'manCreater'}
    screens = sorted([o for o in objects if o.get('type') == 'ScreenRange'], key=lambda o: int(props(o)['screen']))
    triggers = {int(props(o)['screen']): o for o in objects if o.get('type') == 'monsterTrigger' and int(props(o)['screen']) > 0}
    asset_evidence = import_boss_assets(original, config)
    base = 'data/levels/biyujing/progression'
    birth_regions = {int(n): screen for screen, trigger in triggers.items() for n in props(trigger)['points'].split(';') if n}
    point_ids = {n: 'screen%d_birth%d' % (birth_regions[n], n) for n in range(1,17)}
    point_ids[17] = 'revival_vessel_birth'
    region_ids = ['biyujing_region_'+str(i) for i in range(1,6)]
    plans = []
    waves = []
    regions = []
    for number, obj in sorted(births.items()):
        if number not in point_ids: continue
        p = props(obj)
        monster = {'10101':'剑舞', '10201':'驭兽使', '10501':'复苏容器'}[p['mIds']]
        plan_id = point_ids[number]
        fields = f'plan_id = &"{plan_id}"\nspawn_point_id = &"{plan_id}"\n'
        fields += 'monster_ids = ' + names([monster]*int(p['mNums'])) + '\n'
        fields += f'delay_seconds = {float(p.get("delayTime",0))}\ninterval_seconds = {float(p.get("interval",0))}\nfacing = {int(float(p.get("direction",1)))}\n'
        fields += 'after_created_plan_ids = '+names([point_ids[int(p['createAfterPoint'])]] if int(p.get('createAfterPoint',0)) else [])+'\n'
        fields += 'after_dead_plan_ids = '+names([point_ids[int(v)] for v in p.get('createAfterPointDeadAll','').split(';') if v])+'\n'
        resource(f'{base}/plans/{plan_id}.tres','BattleSpawnPlanDefinition','battle_spawn_plan_definition',fields+f'metadata/original_birth_id = {number}\n')
        plans.append(plan_id)
    boss_id = 'jushi_lingjun_birth'
    resource(f'{base}/plans/{boss_id}.tres','BattleSpawnPlanDefinition','battle_spawn_plan_definition',
        f'plan_id = &"{boss_id}"\nspawn_point_id = &"revival_vessel_birth"\nmonster_ids = {names(["巨石灵君"])}\n'
        f'after_dead_plan_ids = {names(["revival_vessel_birth"])}\ndelay_seconds = {25/30:.9f}\nis_boss = true\nfacing = -1\nmetadata/original_death_skill_id = 2001001\nmetadata/original_source_frame = 25\n')
    plans.append(boss_id)
    for index, obj in enumerate(screens):
        screen = index+1
        region_id = region_ids[index]
        groups = ([[1,3],[2,4]] if screen==1 else [[5,7],[6,8]] if screen==2 else [[9,11],[10,12]] if screen==3 else [[13,15]] if screen==4 else [[14,16,17]])
        region_waves = []
        for wi, group in enumerate(groups):
            wave_id = f'{region_id}_wave_{wi+1}'
            members = [point_ids[n] for n in group]
            fields = f'wave_id = &"{wave_id}"\nregion_id = &"{region_id}"\nplan_ids = {names(members)}\n'
            if wi > 0: fields += f'after_wave_ids = {names([region_waves[-1]])}\n'
            resource(f'{base}/waves/{wave_id}.tres','BattleWaveDefinition','battle_wave_definition',fields)
            waves.append(wave_id)
            region_waves.append(wave_id)
        if screen==5:
            wave_id=f'{region_id}_boss'
            resource(f'{base}/waves/{wave_id}.tres','BattleWaveDefinition','battle_wave_definition',
                f'wave_id = &"{wave_id}"\nregion_id = &"{region_id}"\nplan_ids = {names([boss_id])}\n')
            waves.append(wave_id)
            region_waves.append(wave_id)
        end=(float(obj.get('x'))+float(obj.get('width')))*2
        if screen==5:
            gateway=next(o for o in objects if o.get('type')=='Gateway')
            exit_rect=rect(gateway)
        else: exit_rect=f'Rect2({end-96}, 0, 96, 1216)'
        fields=f'region_id = &"{region_id}"\ndisplay_name = "碧玉径 · 区域{screen}"\nbounds = {rect(obj)}\nentry_rect = {rect(triggers[screen])}\nexit_rect = {exit_rect}\nwave_ids = {names(region_waves)}\nautomatic_exit = {"false" if screen==5 else "true"}\ncamera_transition_margin = {844.0 if screen != 5 else 0.0}\nmetadata/original_screen = {screen}\n'
        resource(f'{base}/regions/{region_id}.tres','BattleRegionDefinition','battle_region_definition',fields)
        regions.append(region_id)
    definition='[gd_resource type="Resource" script_class="BattleLevelDefinition" format=3]\n'
    definition+='[ext_resource type="Script" path="res://addons/battle_foundation/definitions/battle_level_definition.gd" id="script"]\n'
    definition+='[ext_resource type="PackedScene" path="res://'+base+'/map.tscn" id="scene"]\n'
    for kind,cls,ids in [('regions','BattleRegionDefinition',regions),('waves','BattleWaveDefinition',waves),('plans','BattleSpawnPlanDefinition',plans)]:
        definition+=f'[ext_resource type="Script" path="res://addons/battle_foundation/level/{ {"regions":"battle_region_definition","waves":"battle_wave_definition","plans":"battle_spawn_plan_definition"}[kind] }.gd" id="{kind}_type"]\n'
        for ident in ids: definition+=f'[ext_resource type="Resource" path="res://{base}/{kind}/{ident}.tres" id="{ident}"]\n'
    definition+='[resource]\nscript = ExtResource("script")\ndefinition_id = &"碧玉径"\ndisplay_name = "碧玉径 · 原版区域与出生计划"\nscene = ExtResource("scene")\n'
    for field,kind,ids in [('regions','regions',regions),('waves','waves',waves),('spawn_plans','plans',plans)]:
        definition+=f'{field} = Array[ExtResource("{kind}_type")](['+', '.join('ExtResource("'+i+'")' for i in ids)+'])\n'
    definition+=f'required_boss_plan_ids = {names([boss_id])}\n'
    write(base+'/definition.tres',definition)
    manifest=json.loads((PROJECT/'data/levels/biyujing/manifest.json').read_text(encoding='utf-8'))
    manifest['definitions']['levels']['碧玉径']='res://'+base+'/definition.tres'
    for name,slug in [('复苏容器','revival_vessel'),('巨石灵君','jushi_lingjun')]:
        manifest['definitions']['monsters'][name]=f'res://data/monsters/{slug}/definition.tres'
        manifest['definitions']['skills'][slug+'_skill1']=f'res://data/monsters/{slug}/skill.tres'
    dump(base+'/manifest.json',manifest)
    build_map(base,objects,screens,point_ids,births)
    sources=['games/zmhj-g5/cache/assets/map/No_1-1_V283.tmx','out/zmhj-equip-skill-diag/com/wdcgame/engine/model/MonsterBirthVO.as','out/zmhj-equip-skill-diag/com/wdcgame/engine/managers/ManCreateManager.as','out/zmhj-equip-skill-diag/com/wdcgame/engine/managers/TriggerMonsterVO.as','out/zmhj-equip-skill-diag/prefabs/scripts/GatewayEntity.as']
    dump(base+'/original_source.json',{'original_repository':str(original),'sources':[{'path':p,'sha256':hashlib.sha256((original/p).read_bytes()).hexdigest()} for p in sources],
        'objects':[{**o.attrib,'properties':props(o)} for o in objects], 'dungeon':config['Dungeon']['1'], 'boss_assets':asset_evidence,
        'container_death_skill':config['Skill']['2001001'], 'unit_scale':2,
        'omissions':['Optional healing pots (includeScreen=false) and NPC interaction are audited, not imported.', 'Boss combat currently reuses common AI and primary skill only; dedicated Boss phases not ported.', 'TMX collision rectangles/platforms/screens/plans are imported; original map SWF art not ported.']})
    print('Imported original Biyujing:',len(regions),'regions,',len(waves),'waves,',len(plans),'plans; 32 ordinary fighters + vessel + Boss')

def build_map(base,objects,screens,point_ids,births):
    scene='''[gd_scene format=3]
[ext_resource type="PackedScene" path="res://data/battle2d/sunwukong_2d.tscn" id="player"]
[ext_resource type="Script" path="res://addons/battle_foundation/level/battle_spawn_point_2d.gd" id="point"]
[ext_resource type="Script" path="res://addons/battle_foundation/level/battle_region_gate_2d.gd" id="gate"]
[ext_resource type="PackedScene" path="res://addons/battle_foundation/level/battle_map_template_2d.tscn" id="map_template"]
'''
    visual_exists=(PROJECT/(base+'/visual.tscn')).exists()
    if visual_exists:scene+=f'[ext_resource type="PackedScene" path="res://{base}/visual.tscn" id="visuals"]\n'
    ground=[o for o in objects if o.get('type') in ['ground','floor']]
    for i,o in enumerate(ground):
        scene+=f'[sub_resource type="RectangleShape2D" id="ground{i}"]\nsize = Vector2({float(o.get("width"))*2}, {float(o.get("height"))*2})\n'
    scene+='[sub_resource type="RectangleShape2D" id="gate_shape"]\nsize = Vector2(20, 1280)\n'
    scene+='[node name="Actors" instance=ExtResource("map_template")]\n'
    if visual_exists:scene+='[node name="BiyujingVisual" parent="Visuals" instance=ExtResource("visuals")]\n'
    for i,o in enumerate(ground):
        x,y,w,h=[float(o.get(k))*2 for k in ['x','y','width','height']]
        node=f'Terrain/Ground{i}'
        scene+=f'[node name="Ground{i}" type="StaticBody2D" parent="Terrain"]\nposition = Vector2({x+w/2}, {y+h/2})\ncollision_mask = 2\n'
        scene+=f'[node name="CollisionShape2D" type="CollisionShape2D" parent="{node}"]\nshape = SubResource("ground{i}")\n'
        if o.get('type')=='floor':scene+='one_way_collision = true\n'
    birth=next(o for o in objects if o.get('type')=='birth')
    scene+=f'[node name="SunWukong" parent="." instance=ExtResource("player")]\nposition = Vector2({float(birth.get("x"))*2}, {float(birth.get("y"))*2})\nscene_definition_id = &"孙悟空"\n'
    scene+=f'[node name="PlayerBirth" parent="."]\nposition = Vector2({float(birth.get("x"))*2}, {float(birth.get("y"))*2})\n'
    for n,ident in point_ids.items():
        o=births[n]
        scene+=f'[node name="{ident}" type="Marker2D" parent="SpawnPoints"]\nposition = Vector2({float(o.get("x"))*2}, {float(o.get("y"))*2})\nscript = ExtResource("point")\nspawn_point_id = &"{ident}"\n'
    for i,o in enumerate(screens):
        end=(float(o.get('x'))+float(o.get('width')))*2
        scene+=f'[node name="Gate{i+1}" type="StaticBody2D" parent="Gates"]\nposition = Vector2({end-10}, 576)\ncollision_layer = 1\ncollision_mask = 2\nscript = ExtResource("gate")\nregion_id = &"biyujing_region_{i+1}"\n'
        scene+=f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Gates/Gate{i+1}"]\nshape = SubResource("gate_shape")\n'
        scene+=f'[node name="Barrier" type="Polygon2D" parent="Gates/Gate{i+1}"]\npolygon = PackedVector2Array(-10,-640, 10,-640, 10,640, -10,640)\ncolor = Color(0.9, 0.35, 0.18, 0.7)\n'
        scene+=f'[node name="Label" type="Label" parent="Gates/Gate{i+1}"]\nposition = Vector2(-230,-450)\ntext = "区域未完成"\ntheme_override_font_sizes/font_size = 30\n'
    scene+='[node name="FinalExit" type="Marker2D" parent="."]\nposition = Vector2(10176, 1056)\n[node name="Label" type="Label" parent="FinalExit"]\nposition = Vector2(-120,-150)\ntext = "出口：开启后按W / ↑"\ntheme_override_font_sizes/font_size = 26\n'
    write(base+'/map.tscn',scene)
#endregion

#region Offline entry
if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--original-root',type=Path,default=Path('D:/UserData/Downloads/game/Speculum-4399-master'))
    build(parser.parse_args().original_root)
#endregion
