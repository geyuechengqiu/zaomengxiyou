# 战斗音频与声音设置

F5运行碧玉径：点击底部「设置」或按Esc，分别调整总音量、背景音乐、音效；各行有独立静音开关。取消静音保留原滑条值，修改即时作用于正在播放的声音。拖动结束、点击静音和关闭菜单会保存到Core ConfigManager的`user://config.cfg`，重启后恢复。

## 插件接入与节点

复用现有`godot_core_system-0.0.4`的AudioManager和ConfigManager。公共音频预置于`BattleSession/BattlePresentation/Audio`，包含一个Music和32个音效播放器；不挂在悟空或怪物节点，不在战斗中创建音频组件。播放器通过`bind_scene_player()`绑定Music/SFX总线，所有角色与UI使用同一组设置。

悟空语义动作的`action_started`信号经动画配置映射到原音效名，覆盖五连击、跑攻、跳攻、嗜血、烈焰闪、火眼金睛、火魔斩及后续动作。原`ManEntity.toAttack()`在动作起手调用`playSound(action)`，当前也只在动作开始播放一次，持续按住和动画渲染帧不重复播放。取消火眼、切换动作、死亡或离场会停止该角色持有的声音槽位；槽位复用后旧角色不能误停其他声音。

命中、拾取补给/物品、升级、强化成功和胜负使用原`hs.swf`公共声音。命中与结算事件沿用`defer_attack_feedback`，一次命中只播放一次；闪避、免疫、满值补给和拾取失败不发出成功声音。原怪物Resource配置没有专属声音包，攻击命中仍播放公共hit，不借用悟空的技能声音。

普通关卡使用原TMX指定的`No_1-3`；进入原Boss音乐触发范围（世界坐标X=10200～11200）才切换`boss_01`，不会因提前解锁镜头而早播。音乐自然结束后循环，Boss死亡停止Boss音乐；最终胜负音乐/音效只结算一次。暂停保留进度，恢复继续，离场只停止本会话播放器。原BossFeedback中的旧音乐/命中/结果播放器仅供无公共音频组件的兼容场景使用，主关卡不会双重播放。

## 资源与扩展

`assets/audio/original/`导出本地缓存的203段原MP3，保留原SWF DefineSound字节，没有重新录制或转码；`data/audio/original_audio.json`记录包名、导出符号、SHA256、角色包及地图触发范围。约6.8MB音频本体，导出包含缓存的其他角色声音，便于后续接入。

增加角色时在目录`units`中配置角色定义ID对应的原声音包，例如`孙悟空 → se2001V456.swf`；动画profile的语义动作映射到该包中的符号。增加关卡时配置`level_music`和`music_zones`。扩展时间轴也可发出本会话`battle.audio.effect`事件，payload填`pack`和`symbol`。不要在物理更新中逐帧发同一个声音事件。

常用公共声音、当前角色动作和关卡/Boss音乐在加载时缓存。32个场景音效槽位满时复用槽位，节点数不随命中增加；未来调整上限可直接编辑`battle_audio.tscn`的Effects节点。音量只在总线计算一次，各播放器保持设计音量。

Core插件同时修复了分类音量重复衰减、快速切歌旧淡出误停新曲目、导入资源循环开关污染和无界工厂池；工厂池上限Music/SFX/Voice/Ambient为2/32/16/8。场景播放与工厂播放互不清理，统一共享总线设置。

## 补给跳字

拾取成功事件携带`restored_vital`及`restored_amount`，后者是Vital实际回复值，已按上限裁剪并显示整数。公共BattlePresentation在原角色注册点生成回血/回魔数字：绿字`bleedNumberAdd`、蓝字`mpNumberAdd`。满值时保留补给，不显示虚假恢复值。补给不入背包，也不弹出问题提示。

原`CommandModelManager.showAddHpNumber/showAddMpNumber → BattleTopLayer.showAddHp/showAddMp`同样将恢复数字放到人物脚底上方60源单位，再追加bleedOffset。这里复用现有共享图集、跳字节点池与0.9秒Quad.easeOut曲线，不创建AnimationPlayer或逐条Tween对象。

## 导出与验证

```powershell
python tools/export_battle_audio.py
python tools/export_supply_numbers.py
& tools/verify_stage_eight.ps1 -Godot '<带Spine模块的Godot.exe>' -Suites audio,loot_growth,damage_numbers,damage_number_pool,combat_hud,player_operations,boss
```

`verify_audio`检查所有原MP3解码、动作音效、200次连续命中仍只有32槽、独立音量/静音与保存恢复、快速切歌、共享流隔离、原音乐触发区、真实补给拾取、实际恢复值、暂停、多会话及离场。`tools/capture_audio_supply.gd`使用真实GPU检查回血/回魔画面及设置布局。

2026-10-10验证：audio250项、loot_growth68项、damage_numbers79项、damage_number_pool154项、combat_hud42项、player_operations145项、boss97项，共835项检查通过；另通过plugins、core_events、stage_one，共10套回归。原生GPU确认绿色/蓝色恢复数字实际显示，声音设置位于战斗HUD上方，按钮不被遮挡；日志无脚本或运行错误。
