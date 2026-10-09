// #region Standalone Boss class and material-frame timeline
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const esc = s => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
const out = ['<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1240" viewBox="0 0 1800 1240"><defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0L10 5L0 10Z" fill="#566780"/></marker></defs><rect width="1800" height="1240" fill="#f5f7fb"/><g font-family="Microsoft YaHei,Segoe UI,sans-serif" fill="#182840">'];
function text(x,y,s,size=17,color='#182840') { out.push(`<text x="${x}" y="${y}" font-size="${size}" fill="${color}">${esc(s)}</text>`); }
function box(x,y,title,subtitle,rows,color='#345b9a',h=225) {
    out.push(`<rect x="${x}" y="${y}" width="400" height="${h}" rx="10" fill="white" stroke="${color}" stroke-width="2"/><rect x="${x}" y="${y}" width="400" height="65" rx="10" fill="${color}"/>`);
    text(x+14,y+27,title,19,'white'); text(x+14,y+51,subtitle,16,'white');
    rows.forEach((row,i)=>text(x+14,y+93+i*27,row,17));
}
function arrow(d,label,x,y,dashed=false) {
    out.push(`<path d="${d}" fill="none" stroke="#566780" stroke-width="2" marker-end="url(#arrow)" ${dashed?'stroke-dasharray="6 5"':''}/>`);
    if(label) text(x,y,label,16,'#435575');
}
text(40,48,'阶段13 · Boss技能、阶段与播报',32);
text(40,81,'通用怪物 + 专属配置；复用Core/GAS，定义与运行实例分离，节点和对象池在场景中预置',20,'#53647d');
box(40,120,'Boss行为定义','BattleBossProfile : Resource',['skills / phases（原Boss为空）','health_bar_count / maximum_summons','intro_seconds / completion_condition','is_valid()：唯一ID、阈值顺序']);
box(480,120,'技能选择规则','BattleBossSkillRule : Resource',['ability_id / priority / weight','cooldown_group / group_cooldown','距离 / 血量 / 阶段 / 前置条件','announcement / lead / warning_rect']);
box(920,120,'血量阶段定义','BattleBossPhase : Resource',['phase_id / health_ratio','entry_ability_id / required_conditions','invulnerable_during_entry','scene_event（Core场景动作）']);
box(1360,120,'弹道与石墙定义','BattleBossObjectDefinition : Resource',['源动作 / 逐帧AB / 生成位置 / 速度','formation_seconds / lifetime','angles / linked_to_action','最大次数 / 间隔 / 伤害上下文']);
arrow('M440 230H480','拥有',445,215);
arrow('M240 120V103H1120V120','拥有阶段列表',816,98);
box(40,430,'Boss行为实例','BattleBossController2D : BattleAIController2D',['索敌/追击/退步 → Core操作意图','独立冷却组、播报请求、阶段锁存','summons / summon_total / deaths','阈值达到 + 前置满足 → 一次转换','死亡/取消/离场 → 统一回收'], '#25806d',265);
box(480,430,'通用角色与技能释放','BattleEntity2D + GAS/BattleAttackInstance',['Core状态机校验 ai_skill 意图','GAS冷却/费用 + 素材帧Timeline','AnimationPlayer播放原动作','resolve_attack_hit()共享伤害入口','每次释放ID → 标记/取消事件'], '#25806d',265);
box(920,430,'场景对象池与独立对象','BattleBossObjectPool2D / WorldObject2D',['预置5音符 + 3石墙（玉石琵琶精）','对象/目标独立次数与下次命中时间','30FPS子步 + 连续扫掠 + 地形阻挡','石墙成形后启用StaticBody碰撞','正常结束遵循联动；取消清理全部'], '#25806d',265);
box(1360,430,'全场公共Boss表现','BattleBossFeedback2D : Node2D',['原Boss血条/保护条：0.6/0.3秒','原横幅轨迹与可选前置预警','Core音量总线 / 原BGM及命中声','可编辑镜头反馈、结束归还偏移','不挂在悟空；不决定战斗规则'], '#25806d',265);
arrow('M240 345V430','只读配置',255,389,true);
arrow('M680 345V390H260V430','选择规则',483,382,true);
arrow('M1120 345V407H280V430','阶段配置',904,402,true);
arrow('M1560 345V383H1140V430','对象定义',1375,373,true);
arrow('M440 545H480','意图',444,530); arrow('M880 545H920','帧事件',877,530); arrow('M1320 545H1360','Core',1317,530);
out.push('<rect x="40" y="733" width="1720" height="60" rx="9" fill="#fff0db" stroke="#daaa66"/>');
text(60,770,'播报时间 ≠ 命中时间：原Boss播报与动作同刻开始，真实攻击由30FPS素材帧与独立对象决定',23);
const baseX=680, scale=1000/6;
text(40,830,'原版玉石琵琶精：三技能时序（秒）',23);
for(let sec=0;sec<=6;sec++) {
    const x=baseX+sec*scale;
    out.push(`<path d="M${x} 850V1170" stroke="#d9e1ed"/>`);
    text(x-5,871,String(sec),16,'#53647d');
}
function band(y,start,end,color,label) {
    const x=baseX+start*scale;
    out.push(`<rect x="${x}" y="${y}" width="${(end-start)*scale}" height="18" rx="3" fill="${color}"/>`);
    text(x+5,y-7,label,15,color);
}
text(40,910,'震颤之音 · 38帧动作 · 第15–32帧近身一次命中',18);
band(910,0,38/30,'#8097b6','动作'); band(945,15/30,33/30,'#bb5c43','AB有效');
text(40,1010,'琵琶之伤 · 44帧动作 · 第24帧发射5枚音符',18);
band(1010,0,44/30,'#8097b6','动作');band(1045,24/30,44/30,'#bb5c43','音符：父动作结束回收');
text(40,1110,'玉石之墙 · 第19帧生成 · 12帧成形 + 5秒实体',18);
band(1110,19/30,31/30,'#d8a33a','成形');band(1146,31/30,31/30+5,'#25806d','实体碰撞与持续命中，独立于30帧动作');
text(40,1210,'唯一BattleClock → AI/GAS/对象/表现；Core事件 → 属性/Vital/Buff/受击/关卡出口；阶段与召唤通用能力单独验收',20,'#53647d');
out.push('</g></svg>');
fs.writeFileSync(path.join(root,'addons/battle_foundation/docs/boss.svg'),out.join('\n')+'\n');
// #endregion
