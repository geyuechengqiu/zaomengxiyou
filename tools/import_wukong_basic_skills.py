"""Import native Wukong basic skills, AB rectangles and authored visual tracks additively."""
#region 离线原版数据与Godot资源序列化
import hashlib
import json
import lzma
from pathlib import Path
import re
import sys

PROJECT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('D:/UserData/Downloads/game/Speculum-4399-master')
sys.dont_write_bytecode = True
sys.path.insert(0, str(SOURCE))
from backends.zmhj_config import _read_one, load_config_table, find_config_archive
from import_wukong_context_attacks import _native, _value

GAS = 'addons/gameplay_abiltiy_system/scripts'
BF = 'addons/battle_foundation'
FOLDER = 'data/characters/sunwukong/skills'
TABLE = json.loads((SOURCE/'exports/zmhj_role_stats/原始配置/Skill.json').read_text(encoding='utf-8-sig'))
BUFFS = json.loads((SOURCE/'exports/zmhj_role_stats/原始配置/Buff.json').read_text(encoding='utf-8-sig'))
COMMON = load_config_table(SOURCE/'games/zmhj-g5', 'Common')['1']
PHYSICS = dict(source_fps=30, nape_step=0.1, gravity=float(COMMON['gravity']), display_scale=2)
# 火眼固定注册点与人物使用同一个原始骨架原点；人物脚底校准不能只作用于身体。
_origin = re.search(r'skeleton_offset = Vector2\(([^,]+),\s*([^)]+)\)', (PROJECT/'data/characters/sunwukong/animation/sunwukong_profile.tres').read_text('utf8'))
BEAM_ORIGIN_OFFSET = [float(_origin[1]), float(_origin[2])] if _origin else [0.0, 0.0]
# TargetMove.x enters normalToBodyVelocity; Y is written directly to Nape's body.
BODY_TIME_SCALE = PHYSICS['source_fps'] * PHYSICS['nape_step']
REACTION_GRAVITY = PHYSICS['gravity'] * BODY_TIME_SCALE**2 * PHYSICS['display_scale']
IDS = {'skill1':1101010, 'skill2':1101020, 'skill3':1101030, 'skill4':1101040, 'skill4_1':1101041, 'skill8':1101080, 'skill8_slam':1101081}
SOURCE_FILES = ['exports/zmhj_role_stats/原始配置/Skill.json','exports/zmhj_role_stats/原始配置/Buff.json']
CONTROLLERS = ['out/zmhj-equip-skill-diag/prefabs/scripts/roles/Wk.as'] + [
    'exports/zmhj_character_state_control/sources/com/wdcgame/engine/'+p for p in [
        'entitys/controls/skill/SkillControl.as', 'entitys/controls/skill/Skill31Control.as',
        'entitys/controls/skill/Skill8Control.as', 'entitys/CharEntity.as', 'model/SkillConfigVO.as']]
SOURCE_FILES += ['exports/zmhj_role_stats/原始配置/Role.json',
                 'exports/character_2001_dragonbones/1_V427/skeleton.json',
                 'exports/zmhj_character_state_control/sources/com/wdcgame/engine/core/GameFrame.as',
                 'out/zmhj-equip-skill-diag/com/wdcgame/engine/nape/Nape.as',
                 find_config_archive(SOURCE/'games/zmhj-g5').relative_to(SOURCE).as_posix()] + CONTROLLERS
RECTS = {}
for package in ['skill1V427','skill8V427']:
    relative = f'games/zmhj-g5/cache/assets/man/2001/{package}.swf'
    SOURCE_FILES.append(relative)
    raw = (SOURCE/relative).read_bytes()
    data = _read_one(lzma.decompress(raw[4:], format=lzma.FORMAT_ALONE))
    for row in data['abs']:
        assert row.get('polyPoints') is None
        RECTS[row['name']] = [row[k] for k in ('x','y','width','height')]

def write(path, text):
    target = PROJECT/path
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(text,encoding='utf-8')

def dump(path, data): write(path, json.dumps(data,ensure_ascii=False,indent=2)+'\n')
def ext(path, name): return f'[ext_resource type="Script" path="res://{path}" id="{name}"]\n'
def arr(values): return 'Array[float](['+', '.join(str(float(v)) for v in values)+'])'
def series(value): return str(value).split(';') if isinstance(value,str) else [value]
def sn(values): return 'Array[StringName](['+', '.join('&'+json.dumps(v,ensure_ascii=False) for v in values)+'])'
def rect(values): return 'Rect2('+', '.join(str(v) for v in values)+')'
def vec(values): return 'Vector2('+', '.join(str(v) for v in values)+')'
#endregion

#region GAS技能定义、原版霸体和受伤增减幅
STATUS_IDS = {}
for number in [6000101,6000201,6000301,6000501,19000101]:
    row = BUFFS[str(number)]
    name = f'sunwukong_buff_{number}'
    STATUS_IDS[name] = f'res://{FOLDER}/{name}.tres'
    text = '[gd_resource type="Resource" script_class="GameplayStatusData" format=3]\n'
    text += ext(f'{GAS}/status/gameplay_status_data.gd','status')+ext(f'{BF}/gas/battle_original_status_policy.gd','policy')
    if number == 19000101:
        text += ext(f'{BF}/gas/ge_battle_damage_rules.gd','effect')+ext(f'{GAS}/effects/gameplay_effect.gd','effect_type')
        text += '[sub_resource type="Resource" id="Reduction"]\nscript = ExtResource("effect")\nrules = {&"dmgRate": 50.0}\n'
    text += '[sub_resource type="Resource" id="Policy"]\nscript = ExtResource("policy")\nreplace_rule = 3\n'
    text += f'[resource]\nscript = ExtResource("status")\nstatus_id = &"{name}"\nstatus_display_name = "{row["describe"]}"\nduration = {row["totalTime"]}\nstacking_policy = SubResource("Policy")\n'
    text += f'tags = {sn(["status.buff"] + (["state.super_armor"] if row["type"] == 6 else []))}\n'
    if number == 19000101: text += 'apply_effects = Array[ExtResource("effect_type")]([SubResource("Reduction")])\n'
    text += f'metadata/original_buff_id = {number}\n'
    write(f'{FOLDER}/{name}.tres',text)

# Frames are zero based original source frames. Dash/spin lifetime from type5,
# ray lifetime from type31, fire8 switches AB at 28; zero AB is never a hit.
SPECS = {
    'skill1':dict(duration=12,segments=[('skill1',3,10,1,1.0,0,0)]),
    'skill2':dict(duration=15,segments=[('skill2',0,15,1,1.0,0,0)],gravity=0,motion=800),
    # User extension: double the cast duration and per-target cap; keep startup/cadence/recovery.
    'skill3':dict(duration=74,segments=[('skill3',5,72,10,0.2,57,-43)]),
    'skill4':dict(duration=30,segments=[('skill4',0,30,5,0.2,0,0)],gravity=0),
    'skill4_1':dict(duration=18,segments=[('skill4_1',7,18,1,0.1,0,0)]),
    'skill8':dict(duration=43,segments=[('effect_8',0,28,5,0.18,0,0),('effect_8_1',28,43,1,1.0,0,0)]),
    'skill8_slam':dict(duration=1,segments=[]),
}
SKILLS = {}
for action,original_id in IDS.items():
    original = TABLE[str(original_id)]
    ability = 'sunwukong_'+action
    SKILLS[ability] = f'res://{FOLDER}/{action}.tres'
    spec = SPECS[action]
    text = '[gd_resource type="Resource" script_class="GameplayAbilityDefinition" format=3]\n'
    for path,name in [(f'{GAS}/abilities/gameplay_ability_definition.gd','definition'),(f'{GAS}/abilities/features/gameplay_ability_feature.gd','feature'),(f'{GAS}/abilities/features/cost_feature.gd','cost'),(f'{GAS}/abilities/costs/ability_cost_base.gd','cost_type'),(f'{BF}/gas/battle_skill_mana_cost.gd','mana'),(f'{BF}/gas/battle_skill_cooldown_feature.gd','cooldown'),(f'{BF}/gas/battle_frame_timeline_feature.gd','timeline'),(f'{BF}/definitions/battle_attack_segment.gd','segment'),(f'{BF}/definitions/battle_skill_branch.gd','branch'),(f'{BF}/definitions/battle_skill_motion.gd','motion')]: text += ext(path,name)
    amounts = series(original['consumeMP'])
    cds = series(original['cd']) if action not in ['skill4_1','skill8_slam'] else [0,0]
    text += f'[sub_resource type="Resource" id="Mana"]\nscript = ExtResource("mana")\nskill_id = &"{ability}"\namounts = {arr(amounts)}\n'
    text += '[sub_resource type="Resource" id="Cost"]\nscript = ExtResource("cost")\ncosts = Array[ExtResource("cost_type")]([SubResource("Mana")])\n'
    text += f'[sub_resource type="Resource" id="Cooldown"]\nscript = ExtResource("cooldown")\ncooldown_duration = {float(cds[1])}\ndurations = {arr(cds)}\n'
    segments = []
    for index,(asset,start,end,maximum,interval,x,y) in enumerate(spec['segments'],1):
        segment = f'Hit{index}'; segments.append(segment)
        row = original['param']['s'][index-1] if action=='skill8' else original['param']['s'][0 if action!='skill3' else 1]
        damage = TABLE['1101081'] if action=='skill8' and index==2 else original
        values = RECTS[f'ab_{asset}{start:04d}' if action=='skill8' else f'ab_{asset}0000'][:]
        if action=='skill3':
            values[2] = 1200 # Skill31Control.ray() replaces only AB.width.
            x += BEAM_ORIGIN_OFFSET[0]; y += BEAM_ORIGIN_OFFSET[1]
        else:
            values[0] *= row.get('scaleX',1); values[2] *= row.get('scaleX',1)
            values[1] *= row.get('scaleY',1); values[3] *= row.get('scaleY',1)
        text += f'[sub_resource type="Resource" id="{segment}"]\nscript = ExtResource("segment")\nsegment_id = &"{action}_hit_{index}"\nhit_index = {index}\nstart_frame = {start}\nend_frame = {end}\naction = &"{action}"\nhit_rect = {rect(values)}\nspawn_offset = {vec([x,y])}\ndamage_multiplier = {damage["skillDefault"]}\nhit_interval = {interval}\nmaximum_hits = {maximum}\nhit_stun = {row["stiff"]}\nprotection_skill_id = "{damage["id"]}"\n'
        if action=='skill8' and index==2: text += 'sub_skill_id = &"sunwukong_skill8_slam"\n'
        if row.get('targetMove'):
            sx,sy = map(float,row['targetMove'].split(';'))
            move_time = float(row.get('targetMoveTime',0))
            if move_time <= 0: move_time = float(row['stiff']) if float(row['stiff']) > 0 else 1.0
            text += f'knockback_speed = {sx*2}\nknockback_duration = {move_time}\nlaunch_speed = {max(0,sy)*BODY_TIME_SCALE*2}\nreset_vertical_velocity = true\nreaction_gravity = {REACTION_GRAVITY}\n'
            if row.get('attackedMoveDir')==2: text += 'knockback_direction = "away_from_attacker"\n'
    if action=='skill2':
        dash_speed = float(original['param']['s'][0]['shootSpeed']) * PHYSICS['display_scale']
        text += f'[sub_resource type="Resource" id="Dash"]\nscript = ExtResource("motion")\nstart_frame = 0\nend_frame = 15\nvelocity = Vector2({dash_speed}, 0)\n'
    if action=='skill4': text += '[sub_resource type="Resource" id="FollowUp"]\nscript = ExtResource("branch")\noperation = &"skill_4"\ntarget_ability_id = &"sunwukong_skill4_1"\nstart_frame = 0\nend_frame = 30\nbuffer_frames = 6\n'
    text += f'[sub_resource type="Resource" id="Timeline"]\nscript = ExtResource("timeline")\nduration_frames = {spec["duration"]}\nanimation_action = &"{action if action!="skill8_slam" else "skill8"}"\ncommit_resources = true\ncan_use_in_air = {str(bool(original.get("canUseInSKy"))).lower()}\n'
    text += 'interrupt_actions = '+sn(['attack_'+str(i) for i in range(1,6)]+(['skill2'] if action=='skill1' else []))+'\n'
    if original.get('myBuff'):
        status_ids = [f'sunwukong_buff_{int(b)*100+1}' for b in str(original['myBuff']).split(';')]
        text += 'initial_status_ids = '+sn(status_ids)+'\n'
    text += 'action_rules = {"move": false, "jump": false, "turn": false'+(', "gravity_scale": 0.0' if spec.get('gravity')==0 else '')+'}\n'
    if segments: text += 'attack_segments = Array[ExtResource("segment")](['+', '.join(f'SubResource("{s}")' for s in segments)+'])\n'
    if action=='skill2': text += 'motion_windows = Array[ExtResource("motion")]([SubResource("Dash")])\n'
    if action=='skill4': text += 'branch_windows = Array[ExtResource("branch")]([SubResource("FollowUp")])\n'
    if action=='skill8': text += 'effect_tail_frames = 3\n'
    if action=='skill3': text += 'cancel_on_input_release = true\naim_segment_index = 1\naim_effect_paths = Array[NodePath]([NodePath("AttackEffects/SkillPrimary")])\naim_head_bone = &"mz_头2"\naim_tip_path = NodePath("AttackEffects/BeamEnd")\naim_length = 1200.0\n'
    text += f'[resource]\nscript = ExtResource("definition")\nability_id = &"{ability}"\nability_name = "{original["name"]}"\nfeatures = Array[ExtResource("feature")]([SubResource("Cost"), SubResource("Cooldown"), SubResource("Timeline")])\nmetadata/original_skill_id = {original_id}\n'
    write(f'{FOLDER}/{action}.tres',text)
#endregion

#region 追加保存的AnimationPlayer动作，不覆盖已有角色轨道
visual_path = PROJECT/'data/characters/sunwukong/animation/sunwukong_visual.tscn'
visual = visual_path.read_text(encoding='utf-8')
primary_library = re.search(r'\[node name="AnimationPlayer"[^\n]*parent="AttackEffects/Primary/SpineAnimationTrack"[^\n]*\][\s\S]*?libraries/ = SubResource\("([^\"]+)"\)', visual)[1]

def append_master(action,duration,body,effects):
    global visual
    if f'id="SkillMaster_{action}"' in visual: return
    text = f'[sub_resource type="Animation" id="SkillMaster_{action}"]\nresource_name = "{action}"\nlength = {duration/30}\n'
    index = 0
    def value(path,times,values,continuous=False):
        nonlocal text,index
        text += _value(index,path,times,values,continuous); index += 1
    def native(path,times,clips):
        nonlocal text,index
        text += _native(index,path,times,clips); index += 1
    native('SpineVisual/SpineAnimationTrack/SpineVisual Track 0',[0],[body])
    value('AttackHitbox:preview_action',[0],[f'&"{action}"'])
    value('AttackHitbox:preview_time',[0,duration/30],['0.0',str(duration/30)],True)
    for old in ['Primary','Secondary']:
        value(f'AttackEffects/{old}:visible',[0],['false'])
        native(f'AttackEffects/{old}/SpineAnimationTrack/AnimationPlayer',[0],['RESET'])
    for name in ['SkillPrimary','SkillSecondary','BeamEnd']:
        settings = effects.get(name)
        if not settings:
            value(f'AttackEffects/{name}:visible',[0],['false'])
            native(f'AttackEffects/{name}/SpineAnimationTrack/AnimationPlayer',[0],['RESET'])
            continue
        clip,start,end,position,scale = settings
        # At frame0 no duplicate times; RESET at end guarantees backward seek/cancel cleanliness.
        times = ([0,start/30] if start else [0])+[end/30]
        values = (['false','true'] if start else ['true'])+['false']
        clips = (['RESET',clip] if start else [clip])+['RESET']
        value(f'AttackEffects/{name}:visible',times,values)
        native(f'AttackEffects/{name}/SpineAnimationTrack/AnimationPlayer',times,clips)
        value(f'AttackEffects/{name}:position',[0],[vec(position)])
        value(f'AttackEffects/{name}:scale',[0],[vec(scale)])
        value(f'AttackEffects/{name}:rotation',[0],['0.0'])
    value('AttackEffects:preview_action',[0],[f'&"{action}"'])
    value('AttackEffects:preview_time',[0,duration/30],['0.0',str(duration/30)],True)
    library = next(m for m in re.finditer(r'\[sub_resource type="AnimationLibrary"[^\n]*\]\n[\s\S]*?(?=\n\[)',visual) if '&"attack_1"' in m.group())
    block = library.group().replace('_data = {',f'_data = {{\n&"{action}": SubResource("SkillMaster_{action}"),')
    visual = visual[:library.start()]+text+'\n'+block+visual[library.end():]
    at = visual.index('[sub_resource')
    visual = visual[:at]+f'[ext_resource type="Resource" path="res://{FOLDER}/{action}.tres" id="basic_{action}"]\n\n'+visual[at:]
    visual = re.sub(r'(preview_abilities = [^\n]*)(\]\))',lambda m:m[1]+f', ExtResource("basic_{action}")'+m[2],visual)

for action,spec in SPECS.items():
    if action=='skill8_slam': continue
    duration = spec['duration'] + (3 if action == 'skill8' else 0)
    effects = {}
    body = action+('_looped' if action in ['skill2','skill4'] else '')
    # AttackEffects already applies display_scale=2 once; children use source-local units.
    if action=='skill1': effects['SkillPrimary']=('skill1',3,10,[0,0],[1,1])
    if action=='skill2': effects['SkillPrimary']=('skill2_looped',0,15,[0,0],[1,1])
    if action=='skill3':
        ox, oy = BEAM_ORIGIN_OFFSET
        beam_start, beam_end = spec['segments'][0][1:3]
        effects['SkillPrimary']=('skill3_looped',beam_start,beam_end,[57+ox,-43+oy],[1200/68,1])
        effects['SkillSecondary']=('skill3_1_looped',beam_start,beam_end,[ox,3+oy],[1,1])
        effects['BeamEnd']=('skill3_2_looped',beam_start,beam_end,[1257+ox,-43+oy],[1,1])
    if action=='skill4': effects['SkillPrimary']=('skill4_looped',0,30,[0,0],[1.2,1])
    if action=='skill4_1': effects['SkillPrimary']=('skill4_1',7,18,[0,0],[1,1])
    if action=='skill8':
        effects['SkillPrimary']=('effect_8',0,46,[0,0],[1,1])
        effects['SkillSecondary']=('effect_8_1',0,46,[0,0],[1,1])
    append_master(action,duration,body,effects)

if '[node name="SkillPrimary"' not in visual:
    for name in ['SkillPrimary','SkillSecondary','BeamEnd']:
        visual += f'\n[node name="{name}" type="SpineSprite" parent="AttackEffects"]\nvisible = false\nscale = Vector2(1, 1)\nskeleton_data_res = ExtResource("attack_effect_data")\nupdate_mode = 2\npreview_skin = "Default"\n\n[node name="SpineAnimationTrack" type="SpineAnimationTrack" parent="AttackEffects/{name}"]\ntrack_index = 0\nmix_duration = 0.0\n\n[node name="AnimationPlayer" type="AnimationPlayer" parent="AttackEffects/{name}/SpineAnimationTrack"]\ncallback_mode_process = 2\nlibraries/ = SubResource("{primary_library}")\n'
# Native looped clips were generated with loop flag alone. Save loop_mode too so
# editor seek and manual pose sampling repeat short native cycles over a long cast.
for match in list(re.finditer(r'\[sub_resource type="Animation"[^\n]*\]\n[\s\S]*?(?=\n\[)',visual))[::-1]:
    block = match.group()
    if re.search(r'resource_name = "(skill2|skill3|skill3_1|skill3_2|skill4)_looped"',block) and 'loop_mode =' not in block:
        visual = visual[:match.start()]+block.replace('length =','loop_mode = 1\nlength =',1)+visual[match.end():]
visual_path.write_text(visual,encoding='utf-8')
profile_path = PROJECT/'data/characters/sunwukong/animation/sunwukong_profile.tres'
profile = profile_path.read_text(encoding='utf-8')
if '&"skill8"' not in profile:
    profile = profile.replace('&"jump_attack": &"jumpAttack"}', '&"jump_attack": &"jumpAttack", '+', '.join(f'&"{a}": &"{a}"' for a in SPECS if a!='skill8_slam')+'}')
    profile_path.write_text(profile,encoding='utf-8')
#endregion

#region 统一角色、槽位、所有引用目录及可审计快照
file = PROJECT/'data/characters/sunwukong/definition.tres'
text = file.read_text(encoding='utf-8')
if '&"sunwukong_skill1"' not in text:
    text = re.sub(r'(ability_ids = [^\n]*)(\]\))',lambda m:m[1]+', '+', '.join('&"'+id+'"' for id in SKILLS)+m[2],text)
    file.write_text(text,encoding='utf-8')
file = PROJECT/'data/characters/sunwukong/character.tscn'
text = file.read_text(encoding='utf-8')
slot_text = 'ability_slots = Dictionary[StringName, StringName]({'+', '.join(f'&"skill_{slot}": &"sunwukong_skill{skill}"' for slot,skill in [(1,1),(2,2),(3,3),(4,4),(5,8)])+'})\n'
if 'sunwukong_skill1' not in text: text=text.replace('controller_path = NodePath("OperationController")\n', 'controller_path = NodePath("OperationController")\n'+slot_text)
file.write_text(text,encoding='utf-8')
for file in (PROJECT/'data').rglob('manifest.json'):
    try: manifest=json.loads(file.read_text(encoding='utf-8-sig'))
    except ValueError: continue
    definitions=manifest.get('definitions',{})
    if 'res://data/characters/sunwukong/definition.tres' not in definitions.get('characters',{}).values(): continue
    definitions['skills'].update(SKILLS)
    definitions.setdefault('statuses',{}).update(STATUS_IDS)
    dump(file.relative_to(PROJECT),manifest)
mapping=json.loads((PROJECT/'data/damage/skill_mapping.json').read_text(encoding='utf-8-sig'))
mapping.update({'sunwukong_'+a:n for a,n in IDS.items()})
dump('data/damage/skill_mapping.json',mapping)
damage_table=json.loads((PROJECT/'data/damage/original_skills.json').read_text(encoding='utf-8-sig'))
for number in IDS.values(): damage_table[str(number)]={**TABLE[str(number)],'source_skill_id':number}
dump('data/damage/original_skills.json',damage_table)
dump(FOLDER+'/original_source.json',dict(source_fps=30,physics=PHYSICS,skills={a:TABLE[str(n)] for a,n in IDS.items()},buffs={str(n):BUFFS[str(n)] for n in [6000101,6000201,6000301,6000501,19000101]},rectangles=RECTS,timelines=SPECS,sources=[dict(path=p,sha256=hashlib.sha256((SOURCE/p).read_bytes()).hexdigest()) for p in SOURCE_FILES],controllers=CONTROLLERS,fire8_motion='The original body and effect animation bake the visual ascent/descent; do not add a second physical jump.'))
print('PASS imported five Wukong skills, follow-up/slam, native AB, MP/CD level tables, buffs and authored AnimationPlayer tracks')
#endregion
