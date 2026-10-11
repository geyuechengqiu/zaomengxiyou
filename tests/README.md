# 当前功能验证

`suites/` 保存当前功能的验收脚本和入口。旧演示及依赖它们的验证已清理，现有验证直接装配 [最新碧玉径](../game/levels/biyujing.tscn)、基础模板或独立功能组件，验证入口不作为游戏关卡发布。

```powershell
./tools/verify_stage_eight.ps1 -Godot 'D:/UserData/Downloads/godot/version/godot-4.3-4.7.2-stable.exe'
./tools/verify_stage_eight.ps1 -Godot '<Godot.exe>' -Suites spawn_performance,level_progression
```

默认 21 套：怪物出生与生命周期性能、琵琶回血与 Boss 登场、共享属性、原版战力、音频与补给、掉落和装备成长、战斗 HUD、原版战斗连击、无双表现、霸体彩色描边、原版二段跳、Spine 与模板、原版 UI、Boss 表现、镜头、地图视觉、Boss 实战、关卡推进、伤害数字池、花果山及花果山战斗。每套使用独立 Godot 进程和用户目录，脚本/运行错误会使验证失败。日志保存到忽略的 `.cleanup-backup/stage8-<suite>.log`。

`huaguoshan` 使用 C# 装配预置花果山场景，检查实际全图移动、原三个怪物 Spine 动作与镜像、碧玉径属性、五区域十四计划、原计时转换、活怪上限6、延迟怪/名额等待期间锁定、33次死亡、掉落、节点清理、Boss斩败、最终通关点的隐藏/显示/动画推进及唯一最终胜利；同一场景可在 NativeAOT 验证包运行。使用真实渲染并传入 `--capture-huaguoshan` 可在 `.cleanup-backup` 保存出生点及最终出口画面。

`huaguoshan_combat` 在真实花果山坡地上以60/15FPS验证左右横向击退不带出持续上升速度、造1击飞正常落地；通过下＋跳跃意图验证单向平台穿透、跳跃次数保留、暂停与碰撞恢复；通过真实伤害验证小猴仇恨、追近和有效命中。另检查三种怪物移速缩放及正反方向技能命中、打空、一次结算、实际扣血、窗口清理与AI施放。

`fight_power` 检查原权重和职业修正、小数成长先加权后取整、统一快照、GM即时刷新、穿脱装备/词条/套装、临时Buff及生命/魔法排除、临时覆盖下的永久属性通知和同配置角色隔离。

`hit_combo` 验证原版数字/文字、真实GAS命中、多目标、召唤归属、重复事件防重、角色隔离、1.5秒超时与刷新、暂停/慢动作/命中停顿、最高连击、死亡/离场，以及背包空格和清空物品后的悬停/点击路径。GPU显示检查使用 [capture_hit_combo](../tools/performance/capture_hit_combo.gd)。

`spawn_performance` 检查预热、刷怪不解析大表、生命/保护值隔离、反馈池复用与重置、暂停和死亡节点释放。耗时另由 [出生微基准](../tools/performance/benchmark_monster_spawn.tscn) 测量，结果说明见 [性能文档](../docs/project-organization-performance.md)。

`wushuang_visual` 检查待机/原地转向/返回旧位置不叠加人物重影、移动拖尾、原版采样及消散时间、暂停/慢动作/低帧率、固定节点池和结束/死亡清理。真实 GPU 画面对照使用 [capture_wushuang_overlap](../tools/performance/capture_wushuang_overlap.gd)，截图保存在 `.cleanup-backup/wushuang-after-*.png`。

`super_armor_visual` 验证原红黄22帧描边、GAS/动作/保护霸体、换装和镜像、独立材质、暂停/慢动作、无双优先及死亡清理。GPU检查使用 [capture_super_armor](../tools/performance/capture_super_armor.gd)，同时直接验证真实初始背包987战力。

`double_jump` 检查原8帧/30FPS循环二段跳、上升期间持续翻身、真正下落时切换动作、落地重置预算、暂停、不同更新率与大delta的原生姿态/时间一致性。真实 GPU 检查使用 [capture_double_jump](../tools/performance/capture_double_jump.gd)。
