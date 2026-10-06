// #region 脚本实现
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export function generateSourceIndex() {
  const docs = path.dirname(fileURLToPath(import.meta.url));
  const root = path.dirname(docs);
  const walk = dir => fs.readdirSync(dir,{withFileTypes:true}).flatMap(entry => {
    const p=path.join(dir,entry.name);
    return entry.isDirectory()?walk(p):[path.relative(root,p).replaceAll('\\','/')];
  });
  const files=walk(root).filter(p=>!p.startsWith('docs/') && !p.endsWith('.uid') && !p.endsWith('.import')).sort();
  const scripts=files.filter(p=>p.endsWith('.gd'));
  const groups=Map.groupBy(scripts,p=>path.posix.dirname(p));
  const code = values => values.length?values.map(v=>`\`${v.replaceAll('|','&#124;')}\``).join('<br>'):'—';
  let out=`# 全部源码与资源索引\n\n由 [generate_source_index.mjs](generate_source_index.mjs) 从当前文件生成。本文列出全部 ${scripts.length} 个 GDScript 文件（含编辑器入口、示例和 UI），不是仅按关键词挑选核心类。实现行为与限制见 [插件 README](../README.md)；本索引只提取声明，不推断逻辑。\n\n公开方法指名称不以下划线开头的方法；导出字段包含多行 export 注解的声明，运行时内部字段需进入源码查看。无 class_name 的脚本以文件名标识；Autoload 名称由 plugin.gd 注册。\n\n`;
  for (const [group, entries] of groups) {
    out+=`## ${group}\n\n| 文件 / 类型 | 基类 | 导出配置 | 公开方法 | 信号 |\n| --- | --- | --- | --- | --- |\n`;
    for (const file of entries) {
      const source=fs.readFileSync(path.join(root,file),'utf8');
      const name=/^class_name\s+(\w+)/m.exec(source)?.[1]??path.posix.basename(file);
      const base=/^extends\s+([^\r\n]+)/m.exec(source)?.[1]??'—';
      const methods=[...source.matchAll(/^(?:@abstract\s+)?(?:static\s+)?func\s+([A-Za-z]\w*)\s*\(/gm)].map(m=>m[1]+'()');
      const signals=[...source.matchAll(/^signal\s+(\w+)/gm)].map(m=>m[1]);
      const exports=[];
      const lines=source.split(/\r?\n/);
      for(let i=0;i<lines.length;i++) {
        if(!/^@export(?:\s|_|$)/.test(lines[i]) || /^@export_(?:group|subgroup|category)/.test(lines[i])) continue;
        const m=/\bvar\s+(\w+)/.exec(lines[i])??/^(?:var\s+)(\w+)/.exec(lines[i+1]??'');
        if(m) exports.push(m[1]);
      }
      out+=`| [${name}](../${file}) | ${code([base])} | ${code(exports)} | ${code(methods)} | ${code(signals)} |\n`;
    }
    out+='\n';
  }
  out+='## 场景、配置、Shader 与素材\n\n| 文件 | 类型与用途所在模块 |\n| --- | --- |\n';
  const descriptions={tscn:'Godot 场景；示例或 UI 控件层级',tres:'Godot Resource；示例配置、主题或材质',gdshader:'Godot Shader；冷却遮罩或残影视觉',svg:'矢量图标素材',cfg:'编辑器插件配置'};
  for(const file of files.filter(p=>!p.endsWith('.gd') && p!=='README.md')) {
    const ext=path.posix.extname(file).slice(1);
    out+=`| [${file}](../${file}) | ${descriptions[ext]??ext} |\n`;
  }
  out+='\n## 文档生成\n\n[generate_diagrams.mjs](generate_diagrams.mjs) 为统一入口，[system_diagrams.mjs](system_diagrams.mjs) 保存模块图布局。运行一次统一入口即重建 19 个 SVG 与此索引；历史 drawio/png 不参与当前实现说明。\n';
  fs.writeFileSync(path.join(docs,'source-index.md'),out,'utf8');
  console.log(`Indexed ${scripts.length} GDScript files and ${files.length-scripts.length-1} scene/resource files.`);
}
// #endregion
