# 验证目录

`suites/` 保存自动验收脚本及入口场景；`fixtures/` 保存验收依赖的预置平台、木桩、技能和插件测试场景。正式游戏入口是 [game/levels/biyujing.tscn](../game/levels/biyujing.tscn)，project.godot已指向它。

未引用的旧阶段1演示移除；仍被检查使用的场景从examples迁入fixtures，保留原UID并同步资源引用。未引用的Core/摄像机示例移出项目；GAS验证依赖的示例和使用中的配置保留。完整路径变更记录在 [docs/project_layout.json](../docs/project_layout.json)。

```powershell
./tools/verify_stage_eight.ps1 -Godot 'D:/UserData/Downloads/godot/version/godot-4.3-4.7.2-stable.exe'
```

全套包括Spine模板、背包、输入、属性、Buff、技能、AI、Boss、关卡、镜头、UI、音频、补给跳字和伤害展示。`audio`专项覆盖原资源、实际动作/命中/拾取、总线与静音保存、切歌、循环、暂停及多会话；可用-Suites选择必要检查。每套独立Godot进程和user目录，失败退出并输出日志；日志和GPU截图保存在忽略的.cleanup-backup，不作为正式素材。
