"""Read-only export of the user-supplied zmISAV VTest Flash build."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]

#region Source export and literal component configuration; never execute game scripts
def literal(text):
    if text in ('true','false','null'): return json.loads(text)
    if re.fullmatch(r'-?\d+(?:\.\d+)?',text): return float(text) if '.' in text else int(text)
    if text.startswith('"'): return json.loads(text)
    return {'expression':text}

def export(source, reference):
    out = ROOT/'docs/reference/zaomeng1'
    out.mkdir(parents=True,exist_ok=True)
    cache = ROOT/'.cleanup-backup/zaomeng1-scripts'
    cp = str(reference/'out/swfutil/ffdec_lib_20.1.0/*')
    def java(tool,*args):
        subprocess.run(['java','-Djava.awt.headless=true','-Dfile.encoding=UTF-8','-cp',cp,str(ROOT/'tools'/tool),*map(str,args)],check=True)
    java('ExportFlashScripts.java',source/'打开我开始玩.swf',cache)
    timeline_path=out/'timeline.json'
    java('ExportFlashTimeline.java',source/'打开我开始玩.swf',timeline_path,'export.GameSence,bgClips')
    timeline=json.loads(timeline_path.read_text('utf8'))
    script=(cache/'export/GameSence.as').read_text('utf8')
    rules=[]
    pattern=r'internal function (__setProp_[^(]+)\(param1:int\)(.*?)(?=\n      (?:internal|private|public) function|\Z)'
    for function,body in re.findall(pattern,script,re.S):
        interval=re.search(r'param1 >= (\d+) && param1 <= (\d+)',body)
        if not interval: continue
        properties={}
        instance=None
        for instance_id,key,value in re.findall(r'this\.(__id\d+_)\.(\w+) = ([^;]+);',body):
            instance=instance_id;properties[key]=literal(value.strip())
        if instance and properties:
            rules.append({'function':function,'instance':instance,'first_frame':int(interval[1]),'last_frame':int(interval[2]),'properties':properties})
    scene=next(s for s in timeline['symbols'] if 'export.GameSence' in s['names'])
    backgrounds=next(s for s in timeline['symbols'] if 'bgClips' in s['names'])
    background_by_label={label:f for f in backgrounds['frames'] for label in f['labels']}
    levels=[]
    for frame in scene['frames']:
        for label in frame['labels']:
            objects=[]
            for placement in frame['placements']:
                data=dict(placement,properties={})
                for rule in rules:
                    if rule['instance']==data['instance'] and rule['first_frame']<=frame['frame']<=rule['last_frame']:
                        data['properties'].update(rule['properties'])
                objects.append(data)
            levels.append({'id':label,'scene_frame':frame['frame'],'mode':'pvp' if label=='vs' else 'pve','objects':objects,
                'spawn_plans':[p for p in objects if any(c.endswith('MonsterAppearPoint') for c in p['classes'])],
                'stop_points':[p for p in objects if any(c.endswith('StopPoint') for c in p['classes'])],
                'hazards':[p for p in objects if any(c.endswith('Thron') for c in p['classes'])],
                'background':background_by_label.get(label)})
    # PhysicsWorld recreates StopPoint objects, sorts by X and assigns indices;
    # authored component idx/betweenRandL are source evidence, not runtime rules.
    for level in levels:
        stage=int(level['id'].split('-')[0]) if level['id']!='vs' else None
        width=1450 if stage==1 else (940 if level['id'] in ('4-1','9-1') else 1150)
        level['runtime_stop_points']=[{'source_instance':point['instance'],'x':point['x'],'y':point['y'],'idx':index,'betweenRandL':width,'isBoss':False}
            for index,point in enumerate(sorted(level['stop_points'],key=lambda point:point['x']))]
        for plan in level['spawn_plans']:
            idx=plan['properties']['stopPointIdx']
            if idx not in {point['idx'] for point in level['runtime_stop_points']}:
                raise ValueError(f"Unknown runtime StopPoint: {level['id']} / {plan['instance']}")
    bundle={'game':'造梦西游1','build':'zmISAV VTest (user-supplied modification)','viewport':[940,590],'display_fps':timeline['fps'],
        'spawn_counter_divisor':24,'maximum_live_monsters':8,'maximum_live_monsters_by_game_mode':{'1':6,'2':8},'coordinates':'SWF placement twips / 20; original Y-down pixels',
        'levels':levels,'component_rules':rules}
    (out/'levels.json').write_text(json.dumps(bundle,ensure_ascii=False,indent=2)+'\n','utf8')
    evidence=['export/GameSence.as','base/MonsterAppearPoint.as','export/StopPoint.as','config/Config.as','loader/Aloader.as','my/MainGame.as','PhysicsWorlds/PhysicsWorld.as','storage/MemoryClass.as','user/User.as']
    for relative in evidence:
        path=cache/relative
        if path.exists():
            dest=out/'sources'/relative;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,dest)
    files=[{'path':p.relative_to(source).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(source.rglob('*')) if p.is_file()]
    (out/'source_manifest.json').write_text(json.dumps({'source_directory':str(source),'files':files},ensure_ascii=False,indent=2)+'\n','utf8')
    table='\n'.join(f'| {level["id"]} | {level["scene_frame"]} | {len(level["spawn_plans"])} | {sum(int(p["properties"].get("totalNum",0)) for p in level["spawn_plans"])} | {len(level["stop_points"])} | {len(level["hazards"])} |' for level in levels)
    readme=f'''# 造梦西游1：所提供的 zmISAV VTest 版本

源目录：`{source}`。文件中的更新公告自称 **zmISAV VTest**，包含本地多存档、九周年活动、装备附加属性、修改特效与音乐、掉宝率调整等改动。因此这里记录的是这份实际文件，不将其配置视为未修改的官方初版。主 SWF 为 Flash AS3、版本34、940×590、30FPS。

## 文件和加载关系

`打开我开始玩.swf` 为入口，`GMain → loader.Aloader` 将 Role、Monster_v1、Monster2_v4、Monster3_v3、OtherMat_v5、backpack_v2、Music 七个 SWF 依次装入共同 ApplicationDomain。Role 负责角色，三份 Monster 包负责怪物，OtherMat 负责附加素材，backpack 负责背包，Music 负责声音。`美化包` 中的 Role/Music 是替换版本，分析主目录时未混用。文件名 `1` 尚未确认用途，不臆测为配置档；完整文件大小和 SHA256 见 [来源清单](source_manifest.json)。

## 关卡配置导出

[levels.json](levels.json) 包含每个实际关卡标签的出生点、出生总数、delay、interval、enemyType、stopPointIdx、StopPoint 的原始 idx/isBoss/betweenRandL、场景坐标和障碍。`runtime_stop_points`另记录PhysicsWorld重建停止点后按X排序生成的idx与实际宽度；原编辑器属性原样保留，不能直接用来绑定波次。数据来自 GameSence 显示列表和组件构造脚本，按原 `gotoAndStop(stage + "-" + level)` 选择标签首帧；[timeline.json](timeline.json) 另保留完整帧与显示对象，方便检查后续关键帧。没有将场景电影剪辑动画的每一帧误判为单独关卡。

| 关卡标签 | 场景帧 | 出生计划 | 计划怪物数 | 停止点 | 刺障碍 |
| --- | --- | --- | --- | --- | --- |
{table}

2-1的3037是源配置totalNum合计：该修改版在停止点4设置了三个999只计划及一个Boss，并非导出器将999改为普通波次。表内统计是出生计划配置总量，不保证实际一局必然生成这么多目标；移植时应结合Boss结束与出生队列清理规则。

11个PVE标签包括1-1～3-3、4-1和9-1，另有 `vs` 对战标签。9-1用于副本；`my.MainGame` 还将特定挑战入口转入9-1。名称没有从编号猜测，坐标也没有套用当前上古天地项目的2倍世界比例。不存在单独XML关卡文件：配置在SWF显示列表、GameSence组件属性与脚本中。

## 运行逻辑与移植注意

`GMain → my.MainGame.GameStart → export.GameSence → PhysicsWorld` 创建关卡、人物、物理世界和场景对象。StopPoint 首次触碰按 idx 启动对应出生计划；`MonsterAppearPoint` 先等待 delay，再按 interval 出生，单人模式上限6只活怪、双人模式8只活怪；9-1的逻辑要求前一目标死亡后再生成。计划生成完成会从出生队列移除，通关还要结合活怪和停止点检查，不能只检查当前没有怪物。

出生计时源码使用 `count / 24`，而此修改版显示时钟为30FPS：原delay/interval数值应保留，直接按秒移植会改变实际节奏（连续计数时原数值乘24/30得到实际墙钟时间，活动暂停和活怪上限等待还会影响计数）。PhysicsWorld不会直接使用编辑器StopPoint实例，而是读取位置、重新创建、按X排序，并在pWorldStart依次赋idx。停止点活动宽度默认1150，第一章改为1450，4-1与9-1改为940；例如9-1源码组件idx=4，但运行时唯一停止点idx=0，与出生计划stopPointIdx=0对应。原版角色和怪物规则、UI以及存档与当前上古天地并非同一系统，导出资料独立保存，不自动覆盖现有技能或关卡。

## 重新导出

在Godot项目目录运行：

```powershell
python tools/export_zaomeng_one.py --source "{source}" --reference-root "{reference}"
```

工具只读原目录，导出到本目录。关键反编译脚本保存在 [sources](sources/)；没有运行Flash游戏代码，也没有修改原SWF。主版本及美化版本的校验值分别保留，可检测之后更换文件导致的配置差异。
'''
    (out/'README.md').write_text(readme,'utf8')
    print(f'Exported {len(levels)} labels and {len(rules)} component property ranges to {out}')
#endregion

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--reference-root',type=Path,required=True)
    args=parser.parse_args();export(args.source.resolve(),args.reference_root.resolve())
