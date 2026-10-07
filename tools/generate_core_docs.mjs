// #region 路径与 SVG 基础元素
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const plugin = path.join(project, 'addons/godot_core_system-0.0.4');
const docs = path.join(plugin, 'docs');
fs.mkdirSync(docs, { recursive: true });
const esc = s => String(s).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const text = (x, y, value, css = 'body') => `<text x="${x}" y="${y}" class="${css}">${esc(value)}</text>`;
const node = (name, file, type, ...lines) => ({ name, file, type, lines });
const W = 520, H = 240, cols = [60, 640, 1220];
function card(n, x, y) {
  const link = n.file ? `../${n.file}` : '';
  return `${link ? `<a href="${esc(link)}">` : ''}<g><rect x="${x}" y="${y}" width="${W}" height="${H}" rx="12" class="card"/>
    <path d="M${x} ${y + 83}H${x + W}" class="rule"/>
    ${text(x + 20, y + 28, '«' + n.type + '»', 'type')}${text(x + 20, y + 62, n.name, 'name')}
    ${n.lines.map((line, i) => text(x + 20, y + 119 + i * 30, line)).join('')}
    </g>${link ? '</a>' : ''}`;
}
function svg(title, subtitle, height, content) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="${height}" viewBox="0 0 1800 ${height}" role="img" aria-labelledby="title desc">
  <title id="title">${esc(title)}</title><desc id="desc">${esc(subtitle)}</desc>
  <defs><marker id="arrow" viewBox="0 0 12 12" refX="11" refY="6" markerWidth="11" markerHeight="11" orient="auto"><path d="M1 1L11 6L1 11" fill="none" stroke="#536b89" stroke-width="1.7"/></marker>
  <marker id="inherit" viewBox="0 0 14 14" refX="13" refY="7" markerWidth="13" markerHeight="13" orient="auto"><path d="M1 1L13 7L1 13Z" fill="#f9fbff" stroke="#536b89" stroke-width="1.5"/></marker></defs>
  <style>text{font-family:'Microsoft YaHei','Noto Sans CJK SC',sans-serif;fill:#30445d}.title{font-size:32px;font-weight:600}.subtitle{font-size:19px}.name{font-family:Consolas,monospace;font-size:23px}.type{font-size:17px}.body{font-size:19px}.label{font-size:17px;paint-order:stroke;stroke:#f9fbff;stroke-width:8px;stroke-linejoin:round}.note{font-size:20px}.card{fill:#edf4ff;stroke:#91a6c1;stroke-width:1.6}.rule{stroke:#cbd8e8;fill:none}.edge{fill:none;stroke:#536b89;stroke-width:2;marker-end:url(#arrow)}.bridge{stroke-dasharray:8 6}.inherit{marker-end:url(#inherit)}</style>
  <rect width="1800" height="${height}" fill="#f9fbff"/>
  ${text(50, 55, title, 'title')}${text(50, 95, subtitle, 'subtitle')}${content}</svg>`;
}
function save(name, value) { fs.writeFileSync(path.join(docs, name), value); }
function notes(y, lines) {
  return `<rect x="50" y="${y}" width="1700" height="${lines.length * 31 + 50}" rx="12" fill="#f0edff" stroke="#91a6c1"/>` +
    lines.map((line, i) => text(75, y + 38 + i * 31, line, 'note')).join('');
}
// #endregion

// #region 类图布局与关系
function classDiagram(file, title, rows, edges, footnotes) {
  const positions = new Map();
  rows.forEach((row, r) => row.forEach((n, col) => {
    if (n) positions.set(n.name, { ...n, x: cols[col], y: 200 + r * 350, col });
  }));
  let content = text(50, 143, '实线：持有 / 调用；空心三角：继承；虚线：调用者需实现的适配；点击类框可打开源码', 'subtitle');
  edges.forEach(([from, to, label, kind = 'edge'], index) => {
    const a = positions.get(from), b = positions.get(to);
    if (!a || !b) throw new Error(`Unknown relation: ${from} -> ${to}`);
    let d, lx, ly;
    if (a.y === b.y) {
      const right = a.x < b.x;
      const ax = a.x + (right ? W : 0), bx = b.x + (right ? 0 : W);
      d = `M${ax} ${a.y + 120}H${bx}`; lx = (ax + bx) / 2; ly = a.y + 92;
    } else if (a.col === b.col && Math.abs(a.y - b.y) === 350) {
      const down = b.y > a.y;
      const ay = a.y + (down ? H : 0), by = b.y + (down ? 0 : H);
      d = `M${a.x + W / 2} ${ay}V${by}`; lx = a.x + W / 2 + 12; ly = (ay + by) / 2;
    } else {
      const gutter = a.x - 12 - index % 3 * 12;
      const ay = a.y + H + 22 + index % 3 * 18, by = b.y + H + 27 + index % 3 * 18;
      d = `M${a.x + W / 2} ${a.y + H}V${ay}H${gutter}V${by}H${b.x + W / 2}V${b.y + H}`;
      lx = (gutter + b.x + W / 2) / 2; ly = by - 8;
    }
    content += `<path d="${d}" class="edge ${kind}"/>`;
    if (a.y === b.y) {
      // 相邻类之间只有 60px，关系说明折成短行，避免被卡片遮盖。
      const chunks = label.match(/.{1,3}/gu) ?? [];
      content += chunks.map((line, i) => `<text x="${lx}" y="${ly + i * 22}" class="label" text-anchor="middle">${esc(line)}</text>`).join('');
    } else content += text(lx, ly, label, 'label');
  });
  for (const n of positions.values()) content += card(n, n.x, n.y);
  const end = 200 + (rows.length - 1) * 350 + H + 100;
  content += notes(end, footnotes);
  save(file, svg(title, '基于当前导入源码；框中列出关键成员，完整接口见 source-index.md', end + footnotes.length * 31 + 90, content));
}
// #endregion

// #region CoreSystem 模块总图
const modules = [
  node('logger', 'source/logger/core_logger.gd', 'Node · CoreLogger', 'LogLevel / _log_colors / 文件输出', 'debug() / info() / warning() / error()'),
  node('resource_manager', 'source/resource_system/resource_manager.gd', 'Node · ResourceManager', '_resource_cache / _instance_pools', 'load_resource() / recycle_instance()'),
  node('config_manager', 'source/config_system/config_manager.gd', 'Node · ConfigManager', 'ConfigFile / _modified', 'get_value() / set_value() / save_config()'),
  node('event_bus', 'source/event_system/event_bus.gd', 'Node · CoreEventBus', '_event_metadata / 历史 / 订阅连接', 'subscribe() / push_event() / unsubscribe()'),
  node('input_manager', 'source/input_system/input_manager.gd', 'Node · InputManager', '状态 / 虚拟轴 / 缓冲 / 录制 / Handler', '_input() / _process() / action_triggered'),
  node('operation_manager', 'source/operation_system/operation_manager.gd', 'Node · CoreOperationManager', 'ID → 控制器 WeakRef', 'create_controller() / get_controller()'),
  node('audio_manager', 'source/audio_system/audio_manager.gd', 'Node · AudioManager', '播放器池 / 资源缓存 / 音量配置', 'play_music() / play_sound() / play_voice()'),
  node('scene_manager', 'source/scene_system/scene_manager.gd', 'Node · CoreSceneManager', '场景栈 / 遮罩 / Transition 策略', 'change_scene_async() / pop_scene_async()'),
  node('time_manager', 'source/time_system/time_manager.gd', 'Node · TimeManager', '_timers / 模块内缩放与暂停', 'create_timer() / set_time_scale()'),
  node('save_manager', 'source/save_system/save_manager.gd', 'Node · SaveManager', '格式策略 / 自动存档 / 待加载节点状态', 'create_save() / load_save()'),
  node('state_machine_manager', 'source/state_machine/state_machine_manager.gd', 'Node · StateMachineManager', 'SMRegistration / 三类驱动标志', 'register_state_machine()', 'transition_state_machine()'),
  node('entity_manager', 'source/entity_system/entity_manager.gd', 'Node · EntityManager', 'ID → 场景路径 / PackedScene', 'load_entity() / create_entity()', 'destroy_entity()'),
  node('trigger_manager', 'source/trigger_system/trigger_manager.gd', 'Node · TriggerManager', '事件/周期触发器 / 条件工厂', 'handle_event() / create_condition()'),
  node('tag_manager', 'source/tag_system/gameplay_tag_manager.gd', 'Node · GameplayTagManager', '标签树 / 容器 / 对象 WeakRef 索引', 'get_tag() / get_objects_with_tag()')
];
let architecture = `<a href="../source/core_system.gd"><rect x="50" y="145" width="1700" height="220" rx="12" fill="#e7f6f0" stroke="#91a6c1"/>
  ${text(80, 183, '«Autoload Node»', 'type')}${text(80, 221, 'CoreSystem', 'name')}
  ${text(80, 262, '_module_scripts: 模块脚本表     _modules: 实例表     _get_module() → _create_module() → add_child()')}
  ${text(80, 302, '@onready 属性在入口 ready 时初始化；getter 可再次按需查询；模块开关缺失时默认为启用')}
  ${text(80, 341, '工具常量：FrameSplitter / SingleThread / ModuleThread / RandomPicker / AsyncIOManager')}</a>`;
for (let col = 0; col < 3; col++) {
  const gutter = cols[col] - 25;
  const lastRow = Math.floor((modules.length - 1 - col) / 3);
  architecture += `<path d="M900 365V415H${gutter}V${480 + lastRow * 320 + 120}" class="rule"/>`;
}
modules.forEach((n, i) => {
  const col = i % 3, x = cols[col], y = 480 + Math.floor(i / 3) * 320;
  architecture += `<path d="M${x - 25} ${y + 120}H${x}" class="edge"/>` + card(n, x, y);
});
architecture += text(65, 450, '创建并持有以下 14 个 Node 子模块（类名通过 CoreSystem 的 preload 常量访问）', 'subtitle');
architecture += notes(2080, ['模块间依赖：音频 → 配置；场景/实体 → 资源；触发器 → 事件；存档 → 配置和格式策略。',
  '本插件的事件、标签、计时与 GAS 各自独立；模块初始化与设置 ID 边界见实现分析。']);
save('core-architecture.svg', svg('Godot Core System：入口与全部模块', '实线箭头：入口创建并持有模块；框中名称为公开属性，非全部都是全局 class_name', 2240, architecture));
// #endregion

// #region 输入与状态机类图
classDiagram('core-input-state.svg', '输入、操作意图与逻辑状态机', [
  [node('InputManager', 'source/input_system/input_manager.gd', 'Node', 'virtual_axis / input_buffer / input_state', '_input() / _process() / action_triggered'),
   node('InputVirtualAxis', 'source/input_system/features/input_virtual_axis.gd', 'RefCounted', 'x/y 正负动作、死区、灵敏度', 'update_axis() / get_axis_value()'),
   node('InputBuffer', 'source/input_system/features/input_buffer.gd', 'RefCounted', 'BufferData[] / 真实时间过期', 'add_buffer() / clear_buffer()')],
  [node('InputEventProcessor', 'source/input_system/features/input_event_processor.gd', 'RefCounted', 'Handler[] / Filter[]', 'process_event() / add_handler()'),
   node('InputRecorder', 'source/input_system/features/input_recorder.gd', 'RefCounted', 'InputRecord[] / recording / playing', 'get_playback_data() / 文件读写'),
   node('InputState', 'source/input_system/input_state.gd', 'RefCounted', '动作 → ActionState / 毫秒边沿防抖', 'update_action() / is_just_pressed()')],
  [node('InputConfig', 'source/input_system/config/input_config.gd', 'Resource', '动作/轴/设备映射 / 输入设置', 'config_changed / update_config()'),
   node('InputConfigAdapter', 'source/input_system/config/input_config_adapter.gd', 'RefCounted', 'ConfigManager 的 input 配置段', 'save_config() / reset_to_default()'),
   node('ConfigManager', 'source/config_system/config_manager.gd', 'Node', 'ConfigFile / _modified', 'get_section() / set_section()')],
  [node('CoreOperationManager', 'source/operation_system/operation_manager.gd', 'Node', '控制器 WeakRef 注册表', 'create_controller()', 'register_controller()'),
   node('CoreOperationController', 'source/operation_system/operation_controller.gd', 'Node', '按下 / 持有 / 释放 / 强度变化', 'UI 优先 / 双击 / 独立控制权'),
   node('CoreOperationProfile', 'source/operation_system/operation_profile.gd', 'Resource', '映射 / 默认键 / 缓存与长按窗口', '共享只读定义')],
  [node('StateMachineManager', 'source/state_machine/state_machine_manager.gd', 'Node', 'SMRegistration / 驱动标志', 'register_state_machine() / 注销'),
   node('BaseStateMachine', 'source/state_machine/base_state_machine.gd', 'RefCounted : BaseState', 'states / current_state / values', 'start() / transition_local() / stop()'),
   node('BaseState', 'source/state_machine/base_state.gd', 'RefCounted', 'agent / state_machine / is_active', 'enter() / exit() / update()')],
  [node('CoreOperationBindings', 'source/operation_system/operation_bindings.gd', 'Node', 'InputMap 安装 / 捕获 / 冲突 / 配置', 'start_remap() / set_binding()'),
   node('CoreOperationIntent', 'source/operation_system/operation_intent.gd', 'InputEventAction', 'phase / sequence / input_time', 'held_seconds / payload 快照'),
   node('CoreOperationBuffer', 'source/operation_system/operation_buffer.gd', 'RefCounted', 'PRESSED 有界 FIFO / 输入秒过期', 'peek() / consume(sequence)')]
], [
  ['InputManager','InputVirtualAxis','持有'], ['InputManager','InputEventProcessor','持有'],
  ['InputConfigAdapter','InputConfig','持有'], ['InputConfigAdapter','ConfigManager','配置读写'],
  ['CoreOperationManager','CoreOperationController','弱引用'], ['CoreOperationController','CoreOperationProfile','配置'],
  ['StateMachineManager','BaseStateMachine','驱动'], ['BaseStateMachine','BaseState','继承','inherit'],
  ['CoreOperationController','CoreOperationIntent','生成事件'],
  ['CoreOperationManager','CoreOperationBindings','持有'],
  ['CoreOperationController','CoreOperationBuffer','按下缓存'],
  ['CoreOperationIntent','BaseStateMachine','消费者转发','bridge']
], ['InputManager 轮询与 OperationController 语义意图是并列通道，没有自动连接。',
  '控制器由角色挂树；状态机由管理器或角色驱动，须避免重复 update。',
  '输入 Handler、配置适配器与层级切换的现有限制见实现分析。']);
// #endregion

// #region 存档与 IO 类图
classDiagram('core-persistence.svg', '存档、IO 策略与线程执行', [
  [node('SaveManager', 'source/save_system/save_manager.gd', 'Node', 'saveable Group / pending states', 'create_save() / load_save() / 自动存档'),
   node('SaveFormatStrategy', 'source/save_system/save_format_strategy/save_format_strategy.gd', 'RefCounted', '文件扩展名、路径与基础文件操作', 'save() / load_save() / load_metadata()'),
   node('ResourceSaveStrategy', 'source/save_system/save_format_strategy/resource_save_strategy.gd', 'SaveFormatStrategy', '.tres / GameStateData', 'ResourceSaver / ResourceLoader')],
  [node('JSONSaveStrategy', 'source/save_system/save_format_strategy/json_save_strategy.gd', 'AsyncIOStrategy', '.json / JSON', '创建异步 IO 组合'),
   node('AsyncIOStrategy', 'source/save_system/save_format_strategy/async_io_strategy.gd', 'SaveFormatStrategy', 'Variant 类型标记 / 对象转换', 'await io_completed / 按任务 ID 核对'),
   node('BinarySaveStrategy', 'source/save_system/save_format_strategy/binary_save_strategy.gd', 'AsyncIOStrategy', '.save / JSON → Gzip → XOR', 'set_encryption_key()')],
  [node('SerializationStrategy', 'source/utils/io_strategies/serialization/serialization_strategy.gd', 'RefCounted', 'JSONSerializationStrategy 实现', 'serialize() / deserialize()'),
   node('AsyncIOManager', 'source/utils/async_io_manager.gd', 'RefCounted', '线程任务 ID → 公开 ID', 'read_file_async() / write_file_async()'),
   node('CompressionStrategy', 'source/utils/io_strategies/compression/compression_strategy.gd', 'RefCounted', 'NoCompression / Gzip 实现', 'compress() / decompress()')],
  [node('EncryptionStrategy', 'source/utils/io_strategies/encryption/encryption_strategy.gd', 'RefCounted', 'NoEncryption / XOR 实现', 'encrypt() / decrypt()'),
   node('SingleThread', 'source/utils/threading/single_thread.gd', 'RefCounted', 'Thread / Mutex / Semaphore / FIFO', 'add_task(): int / task_completed'),
   node('ModuleThread', 'source/utils/threading/module_thread.gd', 'RefCounted', '名字 → SingleThread / 聚合信号', 'submit_task() / unload_thread()')],
  [node('GameStateData', 'source/save_system/game_state_data.gd', 'Resource', 'metadata / nodes_state', 'Resource 格式存档容器'),null,null]
], [
  ['SaveManager','SaveFormatStrategy','委托'], ['ResourceSaveStrategy','SaveFormatStrategy','继承','inherit'],
  ['AsyncIOStrategy','SaveFormatStrategy','继承','inherit'],
  ['JSONSaveStrategy','AsyncIOStrategy','继承','inherit'], ['BinarySaveStrategy','AsyncIOStrategy','继承','inherit'],
  ['AsyncIOStrategy','AsyncIOManager','持有'],
  ['AsyncIOManager','SerializationStrategy','策略'], ['AsyncIOManager','CompressionStrategy','策略'],
  ['AsyncIOManager','SingleThread','持有'], ['ModuleThread','SingleThread','管理'],
  ['ResourceSaveStrategy','GameStateData','构造保存数据']
], ['写入：Variant 转换 → JSON → 可选压缩 → 可选加密 → 工作线程写文件；读取顺序相反。',
  'EncryptionStrategy 与序列化/压缩策略并列，由 AsyncIOManager 调用；完整策略清单见源码索引。',
  '异步存档需串行 await；当前默认格式、类型转换及任务等待边界见实现分析。']);
// #endregion

// #region 与 GAS 联合接入图
classDiagram('core-gas-integration.svg', 'CoreSystem 与 GAS：现有链路及适配边界', [
  [node('OperationController', 'source/operation_system/operation_controller.gd', 'Core · Node', '输入来源 → 语义意图', 'UI 优先 / intent_emitted'),
   node('RoleAdapter', '../battle_foundation/input/battle_player_operations.gd', 'BattlePlayerOperations · 已接入', '公共意图 / ability_slots / 角色钩子', '战斗许可 / 缓存消费 / 控制权'),
   node('AbilityComponent', '../gameplay_abiltiy_system/scripts/components/gameplay_ability_component.gd', 'GAS · Node', '技能实例 → 行为树 → Effect', 'try_activate_ability()')],
  [node('GAS Event Publishers', '../gameplay_abiltiy_system/scripts/attributes/vitals/health_vital.gd', 'GAS · 已接入', '技能、状态、伤害与技能栏事件', 'push_event(name, [context], true)'),
   node('CoreEventBus', 'source/event_system/event_bus.gd', 'Core · Node', 'Array 参数 / 优先级 / 过滤', 'TriggerManager → GameplayTrigger'),
   node('GameplayStatusComponent', '../gameplay_abiltiy_system/scripts/components/gameplay_status_component.gd', 'GAS · 已接入', 'event_pushed → handle_event()', '入树订阅 / 离树退订')],
  [node('SaveManager', 'source/save_system/save_manager.gd', 'Core · Node', 'saveable 节点 / save() / load_data()', '配置、场景、实体与节点状态'),
   node('SaveableAdapter', '', '调用者需编写', '序列化基本值与稳定 ID', 'GAS 初始化之后重建运行状态'),
   node('Attributes / Vital / Status', '../gameplay_abiltiy_system/scripts/components/gameplay_status_component.gd', 'GAS · 组件协作', '属性修改 / 伤害结算 / 持续效果', 'Effect → 组件 → Cue / 事件')]
], [
  ['OperationController','RoleAdapter','接入'], ['RoleAdapter','AbilityComponent','调用'],
  ['GAS Event Publishers','CoreEventBus','同步推送'], ['CoreEventBus','GameplayStatusComponent','同步广播'],
  ['SaveManager','SaveableAdapter','协议','bridge'], ['SaveableAdapter','Attributes / Vital / Status','重建','bridge'],
  ['AbilityComponent','Attributes / Vital / Status','Effect 执行']
], ['事件直接使用 CoreEventBus；输入已由 BattlePlayerOperations 接入，存档仍需适配。',
  'Core 标签树与 GAS 引用计数标签独立；TimeManager 不自动缩放 GAS 冷却和状态。',
  'GAS 状态监听先于按名订阅的优先级回调；全局事件仍需宿主提供实体作用域。']);
// #endregion

// #region 全部脚本索引
const walk = dir => fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
  const full = path.join(dir, entry.name);
  return entry.isDirectory() ? (entry.name === 'docs' ? [] : walk(full)) : [full];
});
const scripts = walk(plugin).filter(file => file.endsWith('.gd')).sort();
const code = values => values.length ? values.map(s => '`' + s.replaceAll('|', '&#124;') + '`').join('<br>') : '—';
let index = `# CoreSystem 全部源码索引\n\n覆盖当前插件全部 ${scripts.length} 个 GDScript，含编辑器入口、配置、模块、策略与示例。由 [文档生成工具](../../../tools/generate_core_docs.mjs) 重建。实现说明见 [完整分析](implementation-analysis.md)。\n\n列表提取声明，不代表所有接口已验证；公开方法包含 ready/dispose 等自定义生命周期，内部回调也单独列出。无全局 class_name 的文件通过 CoreSystem preload 常量或路径使用。\n\n`;
for (const [dir, entries] of Map.groupBy(scripts, file => path.relative(plugin, path.dirname(file)).replaceAll('\\', '/'))) {
  index += `## ${dir || '插件入口'}\n\n| 脚本 / 类型 | 基类 | 配置与字段 | 公开方法 | 内部方法与回调 | 信号 |\n| --- | --- | --- | --- | --- | --- |\n`;
  for (const file of entries) {
    const source = fs.readFileSync(file, 'utf8');
    const relative = path.relative(plugin, file).replaceAll('\\', '/');
    const name = /^class_name\s+(\w+)/m.exec(source)?.[1] ?? path.basename(file);
    const base = /^extends\s+([^\r\n]+)/m.exec(source)?.[1] ?? '—';
    const fields = [...source.matchAll(/^(?:@\w+(?:\([^\n]*?\))?\s+)?var\s+(\w+)/gm)].map(m => m[1]);
    const methods = [...source.matchAll(/^(?:static\s+)?func\s+(\w+)\s*\(/gm)].map(m => m[1]);
    const signals = [...source.matchAll(/^signal\s+(\w+)/gm)].map(m => m[1]);
    index += `| [${name}](../${relative}) | ${code([base])} | ${code(fields)} | ${code(methods.filter(m => !m.startsWith('_')).map(m => m + '()'))} | ${code(methods.filter(m => m.startsWith('_')).map(m => m + '()'))} | ${code(signals)} |\n`;
    const inner = [...source.matchAll(/^class\s+(\w+)(?:\s+extends\s+(\w+))?/gm)].map(m => `${m[1]}${m[2] ? ' : ' + m[2] : ''}`);
    if (inner.length) index += `| ↳ 内部类型 | ${code(inner)} | 源码内含成员与方法 | — | — | — |\n`;
  }
  index += '\n';
}
index += '## 文档图\n\n- [全部模块结构](core-architecture.svg)\n- [输入、意图与状态机](core-input-state.svg)\n- [存档、IO 与线程](core-persistence.svg)\n- [与 GAS 的接入边界](core-gas-integration.svg)\n';
fs.writeFileSync(path.join(docs, 'source-index.md'), index);
console.log(`Generated 4 CoreSystem SVG diagrams and indexed ${scripts.length}/${scripts.length} scripts.`);
// #endregion
