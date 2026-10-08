// #region SVG helpers
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const e = s => String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
const text = (x,y,s,size=18) => `<text x="${x}" y="${y}" font-size="${size}" fill="#334155">${e(s)}</text>`;
function box(x,y,title,lines,href,color='#dbeafe') {
  return `<a href="${href}"><rect x="${x}" y="${y}" width="440" height="215" rx="10" fill="white" stroke="#94a3b8"/><rect x="${x}" y="${y}" width="440" height="46" rx="10" fill="${color}"/>${text(x+16,y+31,title,21)}${lines.map((s,i)=>text(x+16,y+77+i*29,s,17)).join('')}</a>`;
}
const arrow = (d,label,x,y) => `<path d="${d}" fill="none" stroke="#64748b" stroke-width="2" marker-end="url(#arrow)"/>${text(x,y,label,15)}`;
// #endregion
// #region Damage classes and original processing order
let body = text(32,80,'GAS 负责属性、状态与 Vital，Core 分发同步事件；原版策略只读定义，每次命中共享一个结果。');
body += box(30,120,'只读原版定义数据', ['220级 EXP 双等级换算参数','6411条技能倍率、附伤与专属参数','业务ID → 来源ID，配置不保存当前值','固定随机输入与来源SHA256'], '../../../data/damage/README.md','#dcfce7');
body += box(530,120,'BattleSession / BattleRandom', ['damage_strategy：场景显式指定','场次种子 / combat 流 / 状态快照','命中 → 暴击 → 浮动随机消费','时间轴取消与命中去重继续生效'], '../runtime/battle_session.gd','#dcfce7');
body += box(1030,120,'时间轴与释放实例', ['BattleFrameTimelineFeature','攻击段倍率、子技能、附伤','BattleAttackInstance 命中记录','释放实例 / 段 / 目标 / 下次命中时间'], '../runtime/battle_attack_instance.gd','#dcfce7');
body += box(30,440,'GAS 最终属性', ['基础 → 成长 → 装备 → 临时 → 最终','当前生命独立于最大生命','atk / phyDef / 六种概率评分','light … ray 八种元素抗性'], '../runtime/battle_attribute_component.gd');
body += box(530,440,'BattleOriginalDamageStrategy', ['继承 GAS DamageLogicStrategy','calculate_result → DamageInfo','原版截断点、分量与阶段追踪','应用阶段按原顺序处理规则与回调'], '../combat/battle_original_damage_strategy.gd','#fef3c7');
body += box(1030,440,'BattleDamageRules', ['每只实体独立的 RefCounted','GAS Effect 按来源施加 / 撤销','普通护盾 FIFO；真实分量穿盾','概率Buff、增减伤、角色阶段钩子'], '../combat/battle_damage_rules.gd');
body += box(30,760,'DamageCalculator / DamageInfo', ['计算伤害 / 普通与真实分量','盾吸收 / 生命前后 / 实际扣血','闪避 / 暴击 / 格挡 / 免疫','计算器生成的命中结果只应用一次'], '../../gameplay_abiltiy_system/scripts/damage/damage_info.gd');
body += box(530,760,'HealthVital.apply_damage', ['同步 damage_received / GAS Buff','策略后置流程 → 普通盾 → 扣血','死亡、damage_applied 与实际扣血','过量伤害和显示伤害分别保存'], '../../gameplay_abiltiy_system/scripts/attributes/vitals/health_vital.gd','#fef3c7');
body += box(1030,760,'Core 事件与战斗反馈', ['battle.attack.hit：同一结果对象','飘字 / 生命面板 / 被动入口','整数显示，概率与倍率显示百分比','毫秒显示；内部保持原版 Number'], '../presentation/battle_combat_feedback_2d.gd');
body += arrow('M250 335V392H685V440','只读参数',290,382);
body += arrow('M750 335V440','场次策略 / 随机',765,395);
body += arrow('M1250 335V395H815V440','单次命中',1020,383);
body += arrow('M470 530H530','读取',479,518);
body += arrow('M1030 530H970','规则',979,518);
body += arrow('M660 655V705H250V760','计算结果',285,694);
body += arrow('M470 858H530','应用',479,845);
body += arrow('M750 760V655','后置结算',765,725);
body += arrow('M970 858H1030','通知',979,845);
body += `<rect x="30" y="1050" width="1440" height="155" rx="10" fill="#e2e8f0"/>`;
body += text(48,1082,'原版关键顺序（每个箭头对应 trace 的一个阶段）',21);
body += text(48,1116,'命中 → 暴击 → 物理截断 → 暴击截断 → 抗性截断 → 真实拆分 → 增减伤 → Buff / 吸血',18);
body += text(48,1150,'实体附伤 / 生命比例 → 转移 / 无伤 → 普通盾 → 格挡 / 追加 → 盾后补1 → 分摊 / 最终 / 免疫 → 生命',18);
body += text(48,1184,'验收：普通80 / 暴击160 / 火抗40 / 附伤127；计算80−吸收50=扣血30，剩余5时实际只扣5。',17);
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1500" height="1240" viewBox="0 0 1500 1240" role="img" aria-label="阶段8原版伤害联合类图"><defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0L10 5L0 10Z" fill="#64748b"/></marker></defs><style>text{font-family:"Microsoft YaHei","Noto Sans CJK SC",sans-serif}a{text-decoration:none}</style><rect width="100%" height="100%" fill="#f8fafc"/>${text(32,45,'阶段8 · 原版伤害计算与现有插件联合运行',28)}${body}</svg>\n`;
fs.writeFileSync(path.join(root,'addons/battle_foundation/docs/original-damage.svg'),svg);
console.log('Generated original-damage.svg');
// #endregion
