# 当前功能验证

`suites/` 保存当前功能的验收脚本和入口。现有验证直接装配碧玉径、造1花果山/水帘洞、大地图、基础模板或功能组件，验证入口不作为正式游戏关卡发布。

```powershell
./tools/verify_stage_eight.ps1 -Godot 'D:/UserData/Downloads/godot/version/4.7.2 C#/godot-4.3-4.7.2-stable-mono.exe'
./tools/verify_stage_eight.ps1 -Godot '<Godot.exe>' -Suites spawn_performance,level_progression
```

默认 25 套：怪物出生与生命周期性能、琵琶回血与 Boss 登场、共享属性、原版战力、音频与补给、掉落和装备成长、战斗 HUD、原版战斗连击、无双表现、霸体彩色描边、原版二段跳、Spine 与模板、原版 UI、Boss 表现、镜头、地图视觉、Boss 实战、关卡推进、伤害数字池、花果山及其战斗、水帘洞及其战斗、大地图进度/角色存档、真实选关/通关按钮切换。每套使用独立 Godot 进程和用户目录，脚本/运行错误会使验证失败。日志保存到忽略的 `.cleanup-backup/stage8-<suite>.log`。

`shuiliandong` 检查18个计划/48次死亡、四种怪物Spine、镜头内出生、六只预算、延迟期间不误通关、唯一Boss音乐、最终出口随Gateway移动、掉落和节点清理。`shuiliandong_combat` 在真实地形上连续跑跳往返，实测猕猴王七种战斗技能、正反方向伤害、多段命中、真实AI、暂停和清理；移动/缩放场景判定框及父节点后真实结算同步改变，Boss实例和原资源彼此隔离。

`zaomeng_one_campaign` 检查造1十个地图点、最新可挑战关卡原版发光、直接选关及造5字体/按钮，只有最终出口确认才能顺序解锁；保存并恢复角色成长、装备唯一ID/强化和实际属性。`campaign_transitions` 用真实按钮执行大地图→花果山→胜利面板→大地图→水帘洞→重开→大地图。测试不修改真实玩家存档。四套也可通过 NativeAOT 验证包运行。

`huaguoshan` 使用 C# 装配预置花果山场景，检查实际全图移动、原三个怪物 Spine 动作与镜像、碧玉径属性、五区域十四计划、原计时转换、活怪上限6、延迟怪/名额等待期间锁定、33次死亡、掉落、节点清理、Boss斩败、最终通关点的隐藏/显示/动画推进及唯一最终胜利；同一场景可在 NativeAOT 验证包运行。使用真实渲染并传入 `--capture-huaguoshan` 可在 `.cleanup-backup` 保存出生点及最终出口画面。

`huaguoshan_combat` 在真实花果山坡地上以60/15FPS验证左右横向击退不带出持续上升速度、造1击飞正常落地；通过下＋跳跃意图验证单向平台穿透、跳跃次数保留、暂停与碰撞恢复；通过真实伤害验证小猴仇恨、追近和有效命中。另检查三种怪物移速缩放及正反方向技能命中、打空、一次结算、实际扣血、窗口清理与AI施放。

`fight_power` 检查原权重和职业修正、小数成长先加权后取整、统一快照、GM即时刷新、穿脱装备/词条/套装、临时Buff及生命/魔法排除、临时覆盖下的永久属性通知和同配置角色隔离。

`hit_combo` 验证原版数字/文字、真实GAS命中、多目标、召唤归属、重复事件防重、角色隔离、1.5秒超时与刷新、暂停/慢动作/命中停顿、最高连击、死亡/离场，以及背包空格和清空物品后的悬停/点击路径。GPU显示检查使用 [capture_hit_combo](../tools/performance/capture_hit_combo.gd)。

`spawn_performance` 检查预热、刷怪不解析大表、生命/保护值隔离、反馈池复用与重置、暂停和死亡节点释放。耗时另由 [出生微基准](../tools/performance/benchmark_monster_spawn.tscn) 测量，结果说明见 [性能文档](../docs/project-organization-performance.md)。

`wushuang_visual` 检查待机/原地转向/返回旧位置不叠加人物重影、移动拖尾、原版采样及消散时间、暂停/慢动作/低帧率、固定节点池和结束/死亡清理。真实 GPU 画面对照使用 [capture_wushuang_overlap](../tools/performance/capture_wushuang_overlap.gd)，截图保存在 `.cleanup-backup/wushuang-after-*.png`。

`super_armor_visual` 验证原红黄22帧描边、GAS/动作/保护霸体、换装和镜像、独立材质、暂停/慢动作、无双优先及死亡清理。GPU检查使用 [capture_super_armor](../tools/performance/capture_super_armor.gd)，同时直接验证真实初始背包987战力。

`mihouwang_animation` 验证用户提供的 DragonBones 转 Spine 后21个源动作、60FPS、嵌套动画、可见骨架姿态、游戏动作实际推进、技能时长、比例与镜像、霸体共用新骨架及Boss姓名W12字体。传入 `--capture-mihouwang` 可保存原生GPU源动作/游戏动作预览。

`double_jump` 检查原8帧/30FPS循环二段跳、上升期间持续翻身、真正下落时切换动作、落地重置预算、暂停、不同更新率与大delta的原生姿态/时间一致性。真实 GPU 检查使用 [capture_double_jump](../tools/performance/capture_double_jump.gd)。

猕猴王特效：mihouwang_animation 同时验证十组外部特效的24/60FPS、原始build时长、绑定帧、实际原生附件、镜像、向后seek、主体隐藏片段、尾帧与受击清理；shuiliandong_combat 验证实战尾帧不延长伤害及暂停冻结特效时钟。

猕猴王发射技能：shuiliandong_combat覆盖skill1远程伤害、发射前无近战伤害、施法后独立飞行、原弹往返命中、编辑范围对两个分支生效、暂停、固定六槽、64次真实施法与独立随机流逐次一致。

`mihouwang_skills` 检查七技能实际冷却及暂停、指定倍率、80%动画与命中时序同步、3000冲刺及镜像、旋风0.5秒六次命中/加强双向吸附/中心停止、保护触发立即中断与绕过冷却、血条抗性图标、三技能AI提前0.2秒播报及分距离选择、双向坡面待机/施法稳定及上下坡持续接地。真实AI预警还验证即时霸体描边、受伤但不硬直/击退/击飞、眩晕拒绝、暂停冻结、霸体延续至动作结束、取消/死亡/离场清理及其他霸体来源保留。加 `--capture-skills` 可生成真实游戏三张效果截图。


`original_skill_panel` 验证原版技能/按键模板、当前阶段火魔斩未学习、等级/灵魂不足的原子拒绝、实际MP/CD/伤害升级、每0.5秒连续升级及取消、技能移动/双击卸下/冷却限制、真实按键捕获与火眼换槽后松键取消、Q键补给使用、重击末击暴击、跨关存档与旧配置清理。鼠标回归包含悬浮框和拖动图标层级、同帧快速拖放、已占用槽原子交换、缩放/偏移坐标、跨类型拒绝、拖出取消、右键/Esc/失焦取消、单击选择装配、Q/E道具换槽，以及按键、二段分支和HUD同步。传入 `--skill-panel-capture` 保存面板、悬浮框和拖动过程的GPU截图至项目缓存；运行时使用 `--audio-driver Dummy`。

`inventory_presentation` 验证原版出售布局、可输入数量及上下限、取消/部分出售、品质和类型排序、锁定单次切换及确认复查、多品质一键出售/穿戴与补给排除、编号首次生成与跨关保持、装备锁定读档、真实战力悬浮明细、称号预留接口及关闭清理。传入 `--inventory-capture` 保存出售、品质选择、战力明细和装备提示的 GPU 截图。技能回归同时检查原方正粗圆字体对应的布局、未转职技能完全隐藏、原两标签和按学习条件显示光效。

按键设置表现回归还检查：库存技能图标不显示额外等级数字；被动/无双提示只显示名称与描述，主动技能保留原版等级、冷却、魔法三行；提示框使用原版九宫格边框并随内容调整高度；关卡道具标签选中态、底部原版说明、空格/品质边框及堆叠数量；单页不显示页码，超过16种道具时实际点击圆形页码并将第二页道具拖入E槽。`--skill-panel-capture` 额外保存 `keyboard-passive-tooltip` 截图。
