// #region 路径与文件扫描
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const checkOnly = process.argv.includes('--check');
const extensions = new Set(['.gd', '.mjs', '.js', '.ps1', '.gdshader']);
const excluded = new Set(['.godot', '.cleanup-backup', '.git', 'node_modules']);
const walk = dir => fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
  const file = path.join(dir, entry.name);
  return entry.isDirectory() ? (excluded.has(entry.name) ? [] : walk(file)) : [file];
});
const files = walk(root).filter(file => extensions.has(path.extname(file))).sort();
const digest = value => crypto.createHash('sha256').update(value).digest('hex');
// #endregion

// #region GDScript 词法状态与原有分区
// 只在字符串、括号及显式续行外识别顶层声明，防止改动多行字面量。
function scanLines(lines) {
  let quote = '', depth = 0, continued = false, regions = 0;
  return lines.map(raw => {
    const line = raw.replace(/\r?\n$/, '');
    const safe = !quote && depth === 0 && !continued;
    const marker = !quote && /^\s*#(end)?region\b/.exec(line);
    const existingDepth = regions;
    if (marker) regions += marker[1] ? -1 : 1;
    if (regions < 0) throw new Error('Unmatched existing #endregion');
    const info = { safe, existingDepth, marker: Boolean(marker) };
    continued = false;
    for (let i = 0; i < line.length;) {
      if (quote) {
        if (line[i] === '\\') { i += 2; continue; }
        if (line.startsWith(quote, i)) { i += quote.length; quote = ''; }
        else i++;
      } else if (line[i] === '#') break;
      else if (line[i] === '"' || line[i] === "'") {
        quote = line.startsWith(line[i].repeat(3), i) ? line[i].repeat(3) : line[i];
        i += quote.length;
      } else {
        if ('([{'.includes(line[i])) depth++;
        if (')]}'.includes(line[i])) depth--;
        if (line[i] === '\\' && !line.slice(i + 1).trim()) continued = true;
        i++;
      }
    }
    // 普通字符串不会合法跨行；三引号字面量保留跨行状态。
    if (quote.length === 1 && !continued) quote = '';
    info.finalRegions = regions;
    return info;
  });
}

function category(line) {
  const method = /^(?:@abstract\s+)?(?:static\s+)?func\s+(\w+)/.exec(line);
  if (method) {
    const name = method[1];
    if (/^_(init|ready|enter_tree|exit_tree|process|physics_process|input|unhandled_input|gui_input|notification|get|set|get_property_list|draw|enable_plugin|disable_plugin)$/.test(name)) return '生命周期与引擎回调';
    if (name.startsWith('_on_')) return '信号回调';
    return name.startsWith('_') ? '内部实现' : '公共接口';
  }
  if (/^class\s/.test(line)) return '内部类型';
  if (/^signal\s/.test(line)) return '信号';
  if (/^(?:const|enum)\b/.test(line)) return '类型与常量';
  if (/^(?:var\s|@(?:export\w*|onready)\b)/.test(line)) return '配置与运行状态';
  return null;
}
// #endregion

// #region 分区生成与完整性验证
function addGDScriptRegions(source) {
  const bom = source.startsWith('\uFEFF') ? '\uFEFF' : '';
  const body = source.slice(bom.length);
  const lines = body.match(/[^\n]*\n|[^\n]+$/g) ?? [];
  const info = scanLines(lines);
  if (info.at(-1)?.finalRegions) throw new Error('Unclosed existing region');
  const eol = body.includes('\r\n') ? '\r\n' : '\n';
  const events = [];
  for (let i = 0; i < lines.length; i++) {
    if (info[i].marker) { events.push({ at: i, label: null }); continue; }
    if (!info[i].safe || info[i].existingDepth || /^\s/.test(lines[i])) continue;
    const label = category(lines[i]);
    if (!label) continue;
    // 文档注释和独立方法注解与声明一并折叠。
    let at = i;
    while (at > 0 && info[at - 1].safe && !info[at - 1].marker && !info[at - 1].existingDepth &&
      /^(?:\s*$|#|@abstract\s*$)/.test(lines[at - 1])) at--;
    events.push({ at, label });
  }
  const insertions = new Map();
  const insert = (at, value) => insertions.set(at, (insertions.get(at) ?? '') + value);
  let active = null;
  for (const event of events) {
    if (event.label === active) continue;
    if (active) insert(event.at, '#endregion' + eol);
    if (event.label) insert(event.at, '#region ' + event.label + eol);
    active = event.label;
  }
  if (active) insert(lines.length, (body.endsWith('\n') ? '' : eol) + '#endregion' + eol);
  if (!events.some(event => event.label) && !info.some(line => line.marker)) {
    insert(0, '#region 脚本定义' + eol);
    insert(lines.length, (body.endsWith('\n') ? '' : eol) + '#endregion' + eol);
  }
  return bom + lines.map((line, i) => (insertions.get(i) ?? '') + line).join('') + (insertions.get(lines.length) ?? '');
}

function stripRegions(source, extension) {
  const marker = extension === '.gd' ? /^\s*#(?:end)?region\b/ :
    extension === '.ps1' ? /^\s*#(?:end)?region\b/i : /^\s*\/\/\s*#(?:end)?region\b/;
  return source.split(/(?<=\n)/).filter(line => !marker.test(line)).join('');
}

function verify(source, extension, file) {
  const marker = extension === '.gd' ? /^\s*#(end)?region\b/ :
    extension === '.ps1' ? /^\s*#(end)?region\b/i : /^\s*\/\/\s*#(end)?region\b/;
  const lines = source.replace(/^\uFEFF/, '').split(/\r?\n/);
  const states = extension === '.gd' ? scanLines(lines) : null;
  let depth = 0, count = 0;
  lines.forEach((line, i) => {
    const match = marker.exec(line);
    if (!match || (states && !states[i].marker)) return;
    depth += match[1] ? -1 : 1;
    if (!match[1]) count++;
    if (depth < 0) throw new Error(`${file}: unmatched region at ${i + 1}`);
  });
  if (depth || !count) throw new Error(`${file}: missing/unclosed regions`);
  return count;
}
// #endregion

// #region 执行与备份
const originals = {};
const changes = [];
let regionCount = 0;
for (const file of files) {
  const original = fs.readFileSync(file, 'utf8');
  const extension = path.extname(file);
  let result = original;
  if (!checkOnly) {
    if (extension === '.gd') result = addGDScriptRegions(original);
    else if (!/^(?:\s*\/\/\s*|\s*)#region\b/m.test(original)) {
      const prefix = extension === '.ps1' ? '#' : '// #';
      const eol = original.includes('\r\n') ? '\r\n' : '\n';
      result = `${prefix}region 脚本实现${eol}${original}${original.endsWith('\n') ? '' : eol}${prefix}endregion${eol}`;
    }
    // 逐文件检查，除 region 注释和无终止换行文件的最后换行外，全部字符必须一致。
    if (digest(stripRegions(original, extension).trimEnd()) !== digest(stripRegions(result, extension).trimEnd())) {
      throw new Error(`${file}: unexpected content change`);
    }
  }
  regionCount += verify(result, extension, file);
  if (original !== result) {
    const relative = path.relative(root, file).replaceAll('\\', '/');
    originals[relative] = Buffer.from(original, 'utf8').toString('base64');
    changes.push({ file, result });
  }
}
// 在全部文件验证成功后才写入，保留每轮实际修改前的完整源码。
if (changes.length) {
  const backupDir = path.join(root, '.cleanup-backup');
  fs.mkdirSync(backupDir, { recursive: true });
  fs.writeFileSync(path.join(backupDir, `script-regions-${Date.now()}.json`), JSON.stringify(originals));
  changes.forEach(({ file, result }) => {
    // 同目录先写临时文件再替换，原文件在 rename 前保持完整。
    const temporary = file + '.regions-tmp';
    fs.writeFileSync(temporary, result);
    fs.renameSync(temporary, file);
  });
}
console.log(`${checkOnly ? 'Validated' : 'Processed'} ${files.length} scripts; ${changes.length} changed; ${regionCount} balanced regions.`);
// #endregion
