// Offline, deterministic import. Reads original exports; never modifies the source repo.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = path.resolve(process.argv[2] ?? 'D:/UserData/Downloads/game/Speculum-4399-master/exports/zmhj_protection');
const read = name => JSON.parse(fs.readFileSync(path.join(source, name), 'utf8').replace(/^\uFEFF/, ''));
const bosses = {};
for (const row of read('Boss保护条满值.json')) {
  const key = `${row['配置表']}/${row.BossID}`;
  if (bosses[key]) throw Error(`Duplicate Boss: ${key}`);
  bosses[key] = { name: row['名称'], protectPoint: row['保护条基础满值'], showProtect: row['显示Boss保护条'], protectSkillId: row['保护动作技能ID'], useProtectAsArmor: row['护甲模式'] };
}
const skills = {};
for (const row of read('全部技能保护值.json')) {
  const result = { name: row['技能名称'] };
  for (const key of ['protectPoint', 'protectPointB', 'protectPointMax', 'isProtectPointAdd', 'pvpProtectPoint', 'pvpProtectPointB', 'pvpProtectPointMax', 'addXpBySkillId']) {
    result[key] = row[key] ?? (key.endsWith('Max') ? null : 0);
  }
  skills[String(row['技能ID'])] = result;
}
const mapping = JSON.parse(fs.readFileSync(path.join(projectRoot, 'data/battle2d/combo_source_mapping.json'), 'utf8'));
const ability_ids = Object.fromEntries(mapping.steps.map(row => [row.id, String(row.source_skill_id)]));
const provenance = ['Boss保护条满值.json', '全部技能保护值.json', '机制说明.md'].map(name => ({path: `exports/zmhj_protection/${name}`, sha256: crypto.createHash('sha256').update(fs.readFileSync(path.join(source,name))).digest('hex')}));
const out = path.join(projectRoot, 'data/protection');
fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, 'original_protection.json'), JSON.stringify({version:1, bosses, skills, ability_ids, provenance}, null, 2)+'\n');
console.log(`Imported ${Object.keys(bosses).length} Boss definitions and ${Object.keys(skills).length} protection skill definitions`);
