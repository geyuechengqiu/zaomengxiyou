// #region 脚本实现
// Mechanical copies of the existing five attacks. Does not rewrite stages 6–8.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.join(root, 'data/battle2d/hit_reaction');
const config = JSON.parse(fs.readFileSync(path.join(out, 'demo_attack_reactions.json'), 'utf8'));
for (let step = 1; step <= 5; step++) {
  let source = fs.readFileSync(path.join(root, `data/battle2d/attack${step}.tres`), 'utf8').replace(/ uid="[^"]+"/g, '');
  source = source.replace(/payload = \{([\s\S]*?)\r?\n\}/g, (match, body) => {
    const fields = Object.entries(config.steps[step-1]).map(([key,value]) => `"${key}": ${typeof value==='string' ? JSON.stringify(value) : value}`);
    return `payload = {${body.trimEnd()},\n${fields.join(',\n')}\n}`;
  });
  fs.writeFileSync(path.join(out, `attack${step}.tres`), source);
}
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'data/battle2d/original_damage/manifest.json'), 'utf8'));
manifest.definitions.statuses.normal_shield = 'res://data/damage/normal_shield.tres';
for (let step=1;step<=5;step++) manifest.definitions.skills[`sunwukong_attack${step}`] = `res://data/battle2d/hit_reaction/attack${step}.tres`;
fs.writeFileSync(path.join(out, 'manifest.json'), JSON.stringify(manifest,null,2)+'\n');
console.log('Built stage 9 five-combo resources and independent manifest');
// #endregion
