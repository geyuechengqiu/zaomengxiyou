// #region Standalone SVG class and runtime diagram
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const escape = value => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
const out = ['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1060" viewBox="0 0 1600 1060"><defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0L10 5L0 10Z" fill="#566780"/></marker></defs><rect width="1600" height="1060" fill="#f5f7fb"/><g font-family="Microsoft YaHei,Segoe UI,sans-serif" fill="#182840">'];
function text(x,y,value,size=17,color='#182840') { out.push(`<text x="${x}" y="${y}" font-size="${size}" fill="${color}">${escape(value)}</text>`); }
function box(x,y,w,h,title,subtitle,rows,color) {
    out.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="10" fill="white" stroke="${color}" stroke-width="2"/><path d="M${x+10} ${y}H${x+w-10}Q${x+w} ${y} ${x+w} ${y+10}V${y+65}H${x}V${y+10}Q${x} ${y} ${x+10} ${y}Z" fill="${color}"/>`);
    text(x+14,y+26,title,18,'white');text(x+14,y+51,subtitle,16,'white');
    rows.forEach((row,i)=>text(x+14,y+92+i*26,row,16));
}
function line(d,label,x,y,dashed=false) {
    out.push(`<path d="${d}" fill="none" stroke="#566780" stroke-width="2" marker-end="url(#arrow)" ${dashed?'stroke-dasharray="6 5"':''}/>`);
    if(label) text(x,y,label,15,'#435575');
}
text(40,45,'阶段12 · 地图、出生计划、区域与通关',30);
text(40,77,'预置节点 + 独立实例 + Core/GAS/BattleClock；当前零活怪 ≠ 区域完成',19,'#53647d');
const cols=[40,425,810,1195], w=350;
box(cols[0],115,w,210,'关卡定义','BattleLevelDefinition',['regions / waves / spawn_plans','condition_ids / required_conditions','required_boss_plan_ids','get_progression_error()'], '#345b9a');
box(cols[1],115,w,210,'区域定义','BattleRegionDefinition',['bounds / entry_rect / exit_rect','wave_ids / required_conditions','automatic_exit','ScreenRange / monsterTrigger'], '#345b9a');
box(cols[2],115,w,210,'波次定义','BattleWaveDefinition',['region_id / plan_ids','after_wave_ids','required_conditions','前置完成 = 生成完毕且目标死亡'], '#345b9a');
box(cols[3],115,w,210,'出生计划定义','BattleSpawnPlanDefinition',['monster_ids / spawn_point_id','delay_seconds / interval_seconds','after_created / after_dead计划ID','participates_in_clear / is_boss'], '#345b9a');
for(let i=0;i<3;i++) line(`M${cols[i]+w} 220H${cols[i+1]}`, '',0,0);
const titles=['关卡实例（预置Node）','区域实例','波次实例','出生计划实例'];
const classes=['BattleLevelInstance2D','BattleRegionInstance','BattleWaveInstance','BattleSpawnPlanInstance'];
const rows=[['state / elapsed / current_region','conditions / death_count / owners','advance_level() / set_condition()','request_exit() / stop()'],['entered / entered_at','completed / exit_open / exited','额外条件与全部波次共同验收','出口打开后才能解锁下一区域'],['started / started_at','completed / completed_at','等待前置波次和启动条件','检查参与通关计划all_dead'],['created / next_due / targets','dead_targets（实体ID去重）','generation_complete_at','all_dead_at / all_dead_notified']];
for(let i=0;i<4;i++) {
    line(`M${cols[i]+175} 325V390`, '只读配置副本',cols[i]+200,366,true);
    box(cols[i],390,w,215,titles[i],classes[i],rows[i],'#25806d');
}
for(let i=0;i<3;i++) line(`M${cols[i]+w} 505H${cols[i+1]}`, '',0,0);
out.push('<rect x="40" y="640" width="1505" height="75" rx="9" fill="#fff0db" stroke="#daaa66"/>');
text(58,669,'区域完成 = 参与通关的全部出生计划生成完毕 + 相关目标全部死亡 + 区域额外条件满足',21);
text(58,699,'最终出口还检查关卡条件与Boss计划；先锁存完成/死亡/胜利状态，再发布Core事件，避免重复结算',18);
box(40,765,440,220,'原有Core插件','ResourceManager · EventBus · Operations',['定义目录与独立深复制','命名事件 + battle_id / sequence','move_up意图 → 最终出口确认','菜单/失焦控制权仍由Core管理'], '#635194');
box(530,765,480,220,'原有战斗插件','BattleSession · BattleClock',['combat delta → 实体 → 关卡调度','暂停 / 慢动作 / 停顿统一生效','spawn_entity_2d() / GAS/Vital/AI','clear_battle()先停止出生计划'], '#635194');
box(1060,765,485,220,'地图与实体（场景预置）','SpawnPoint2D · RegionGate2D · 怪物场景',['Marker2D坐标 / 独立随机流','StaticBody2D门 + Camera2D边界','怪物按时实例化完整预置场景','Vital/击杀 → 去重死亡统计'], '#635194');
line('M175 605V625H25V735H260V765','Core事件',182,730,true);
line('M650 765V750H10V618H350V605','唯一时钟',540,744);
line('M1365 765V735H1575V625H1440V605','出生/死亡',1370,730,true);
text(40,1032,'原版依据：MonsterBirthVO / ManCreateManager / No_1-1_V283.tmx / 容器死亡技能第25帧 / Gateway指定Boss死亡',17,'#53647d');
out.push('</g></svg>');
fs.writeFileSync(path.join(root,'addons/battle_foundation/docs/level-progression.svg'),out.join('\n')+'\n');
// #endregion
