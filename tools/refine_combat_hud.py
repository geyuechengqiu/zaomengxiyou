"""Export original battle tools/timer; author nodes and per-monster protection profiles."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, subprocess, sys, xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parents[1]
BUTTONS = [('BagButton','backpack',626),('SkillButton','skill',633),('HeartButton','heartMedical',661),('MagicButton','magicWeapon',640),('PetButton','petHorse',647),('SettingsButton','systemSet',654)]

#region Offline source export and deterministic scene authoring
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--original-root',type=Path,default=Path('D:/UserData/Downloads/game/Speculum-4399-master'));parser.add_argument('--author-only',action='store_true');args=parser.parse_args()
    source='games/zmhj-g5/cache/assets/ui/mission_20260406_1.swf'
    out=ROOT/'.cleanup-backup/combat-hud-export'
    if not args.author_only:
        def export(symbols,folder,background=False):
            command=['java','-Djava.awt.headless=true','-Dfile.encoding=UTF-8','-cp',str(args.original_root/'out/swfutil/ffdec_lib_20.1.0/*'),str(ROOT/'tools/ExportOriginalBattleUI.java'),str(args.original_root/source),str(folder),symbols]
            if background:command.append('background')
            result=subprocess.run(command,capture_output=True,encoding='utf8',check=True)
            (folder/'inspection.txt').write_text(result.stdout,'utf8')
        export(','.join('#'+str(id) for _,_,id in BUTTONS),out/'buttons')
        export('battletime',out/'timer',True)
        for _,key,id in BUTTONS:
            frames=sorted((out/'buttons'/f'id-{id}').rglob('*.png'),key=lambda p:int(p.stem))
            for state,index in [('up',0),('over',2),('down',3)]:shutil.copyfile(frames[index],ROOT/f'assets/ui/original/battle_{key}_{state}.png')
        shutil.copyfile(next((out/'timer'/'battletime').rglob('*.png')),ROOT/'assets/ui/original/battle_timer.png')
        sys.path.insert(0,str(args.original_root));from backends.zmhj_config import load_config_archive
        config=load_config_archive(args.original_root/'games/zmhj-g5')
        monsters={name:config['Monster'][str(id)] for name,id in [('jianwu',10101),('yushoushi',10201),('revival_vessel',10501),('jushi_lingjun',10601)]}
        evidence={'source':source,'sha256':hashlib.sha256((args.original_root/source).read_bytes()).hexdigest(),'buttons':BUTTONS,'button_label_frames':{'up':0,'over':2,'down':3},'timer_position':[470,16.475],'monsters':monsters,'protect_skill':config['Skill']['1900010'],'buffs':{id:config['Buff'][id] for id in ['1000101','27000201','20000201']}}
        (ROOT/'data/protection/first_level_source.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n','utf8')
    author()

def author():
    evidence=json.loads((ROOT/'data/protection/first_level_source.json').read_text('utf8'))
    for name,row in evidence['monsters'].items():
        generic=int(row.get('protectSkill',0))==1900010
        maximum=int(row.get('protectPoint',0))
        text='[gd_resource type="Resource" script_class="BattleProtectionProfile" format=3]\n[ext_resource type="Script" path="res://addons/battle_foundation/definitions/BattleProtectionProfile.cs" id="script"]\n'
        if generic:text+='[ext_resource type="Resource" path="res://data/buffs/invulnerable.tres" id="status"]\n[ext_resource type="Resource" path="res://data/buffs/debuff_immunity.tres" id="immune"]\n'
        text+='[resource]\nscript = ExtResource("script")\n'+f'enabled = {str(maximum>0).lower()}\noriginal_boss_key = "Monster/{row["id"]}"\nmaximum_override = {maximum if maximum>0 else -1}\ninherit_original_display = false\nshow_protect = {str(bool(row.get("showProtect",0))).lower()}\nprotection_action_enabled = {str(generic).lower()}\n'
        if generic:
            atlas=ET.parse(ROOT/f'assets/monsters/{name}/atlas.xml').getroot()
            frames=sum(1 for frame in atlas if frame.get('name','')[:-4]=='protect')
            if not frames:frames=sum(1 for frame in atlas if frame.get('name','')[:-4]=='idle')
            # BuildAnimator缺失protect图片时沿用idle帧，保护动作单次，Buff独立持续两秒。
            text+=f'protect_seconds = {frames/30:.9f}\nprotection_status = ExtResource("status")\nprotection_statuses = Array[Resource]([ExtResource("immune")])\ncleanse_debuffs = true\nblocks_damage = true\nblocks_status = true\ninvulnerable_alpha = '+str(bool(row.get('wuDiAlpha',True))).lower()+'\n'
        text+=f'metadata/original_protect_skill_id = {int(row.get("protectSkill",0))}\n'
        (ROOT/f'data/monsters/{name}/protection.tres').write_text(text,'utf8')
        path=ROOT/f'data/monsters/{name}/monster.tscn';scene=path.read_text('utf8')
        if 'id="protect_profile"' not in scene:
            at=scene.index('[sub_resource');scene=scene[:at]+f'[ext_resource type="Resource" path="res://data/monsters/{name}/protection.tres" id="protect_profile"]\n'+scene[at:]
        if 'protection_profile =' not in scene:
            root=re.search(r'\[node[^\n]+\]\n(?:(?!\[node).)*?script = ExtResource\("entity"\)\n',scene,re.S)
            scene=scene[:root.end()]+'protection_profile = ExtResource("protect_profile")\n'+scene[root.end():]
        path.write_text(scene,'utf8')
    # The former green polygon is a placeholder, not the original invulnerability visual.
    path=ROOT/'data/monsters/jushi_lingjun/visual.tscn';visual=path.read_text('utf8')
    visual=re.sub(r'(tracks/\d+/path = NodePath\("Visual/ProtectGlow:visible"\).*?"values": \[)true(\])',r'\1false\2',visual,flags=re.S)
    visual=re.sub(r'(\[sub_resource type="Animation" id="Master_protect"\]\n.*?)(?=\n\[)',lambda match:match[0].replace('loop_mode = 1','loop_mode = 0').replace('PackedStringArray("protect_looped")','PackedStringArray("protect")'),visual,flags=re.S)
    path.write_text(visual,'utf8')
    path=ROOT/'data/monsters/jushi_lingjun/animation.tres'
    path.write_text(path.read_text('utf8').replace(', &"protect"]',']'),'utf8')
    path=ROOT/'data/ui/battle_hud.tscn';scene=path.read_text('utf8')
    scene=re.sub(r'\[ext_resource[^\n]+id="combat_[^"]+"\]\n','',scene)
    for name in ['BagButton','BattleTools','LevelTimer','ModulePanel']:
        scene=re.sub(r'\[node[^\n]*(?:name="'+name+r'"[^\n]*parent="\."|parent="'+name+r'(?:/[^"]*)?")[^\n]*\]\n.*?(?=\n\[|\Z)','',scene,flags=re.S)
    resources=[]
    def resource(id,asset,kind='Texture2D'):
        resources.append(f'[ext_resource type="{kind}" path="res://{asset}" id="combat_{id}"]\n');return f'ExtResource("combat_{id}")'
    def node(name,kind,parent,body):return f'[node name="{name}" type="{kind}" parent="{parent}"]\n'+body+'\n'
    def rect(x,y,w,h):return f'offset_left = {x}\noffset_top = {y}\noffset_right = {x+w}\noffset_bottom = {y+h}\n'
    font=resource('font','assets/ui/original/ui_font.ttf','FontFile')
    nodes=node('BattleTools','Control','.',rect(0,-78,940,78)+'anchor_top = 1.0\nanchor_bottom = 1.0\nmouse_filter = 2')
    for i,(name,key,id) in enumerate(BUTTONS):
        refs=[resource(key+state,f'assets/ui/original/battle_{key}_{state}.png') for state in ['up','over','down']]
        nodes+=node(name,'TextureButton','BattleTools',rect(285+63*i,16,55,59)+f'focus_mode = 0\ntexture_normal = {refs[0]}\ntexture_hover = {refs[1]}\ntexture_pressed = {refs[2]}\nmetadata/module = &"{key}"')
    timer=resource('timer','assets/ui/original/battle_timer.png')
    nodes+=node('LevelTimer','Control','.',rect(-139,0,278,33)+'anchor_left = 0.5\nanchor_right = 0.5\nmouse_filter = 2')
    nodes+=node('Background','TextureRect','LevelTimer',rect(0,0,278,32)+'mouse_filter = 2\nexpand_mode = 1\ntexture = '+timer)
    nodes+=node('Time','Label','LevelTimer',rect(90,0,98,33)+f'mouse_filter = 2\ntheme_override_fonts/font = {font}\ntheme_override_font_sizes/font_size = 24\ntheme_override_colors/font_color = Color(0.933333,1,1,1)\nhorizontal_alignment = 1\nvertical_alignment = 1\ntext = "00:00"')
    # Existing modules are presented through authored nodes; gameplay never creates controls.
    bg=resource('module_bg','assets/ui/original/warn_background.png')
    nodes+=node('ModulePanel','Control','.',rect(220,115,500,350)+'visible = false\nz_index = 40\nmouse_filter = 0')
    nodes+=node('Background','NinePatchRect','ModulePanel',rect(0,0,500,350)+f'mouse_filter = 2\ntexture = {bg}\npatch_margin_left = 20\npatch_margin_right = 20\npatch_margin_top = 20\npatch_margin_bottom = 20')
    for name,y,w,h,size in [('Title',18,420,32,24),('Text',65,440,255,18)]:
        nodes+=node(name,'Label','ModulePanel',rect(30,y,w,h)+f'mouse_filter = 2\ntheme_override_fonts/font = {font}\ntheme_override_font_sizes/font_size = {size}\ntheme_override_colors/font_color = Color(0.372549,0.117647,0.019608,1)\nautowrap_mode = 2')
    close=[resource('close'+str(i),f'assets/ui/original/bag_close_{i}.png') for i in range(3)]
    nodes+=node('Close','TextureButton','ModulePanel',rect(455,10,33,38)+f'focus_mode = 0\ntexture_normal = {close[0]}\ntexture_hover = {close[1]}\ntexture_pressed = {close[2]}')
    if 'id="pickup_feedback"' not in scene:
        resources.append('[ext_resource type="Script" path="res://addons/battle_foundation/ui/battle_pickup_feedback.gd" id="pickup_feedback"]\n')
    if '[node name="PickupEffects"' not in scene:
        nodes+=node('PickupEffects','Control','.','layout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\nmouse_filter = 2\nprocess_mode = 3\nz_index = 100\nscript = ExtResource("pickup_feedback")')
    at=scene.index('[sub_resource');scene=scene[:at]+''.join(resources)+scene[at:]
    scene+=nodes
    scene=re.sub(r'\n{3,}', '\n\n', scene)
    path.write_text(scene,'utf8')
    print('Authored original six battle tools, centered timer and four per-monster protection profiles')

if __name__=='__main__':main()
#endregion
