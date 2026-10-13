# C# / NativeAOT 迁移

项目逻辑与自维护插件迁移到 C#；第三方 Core/GAS/Phantom Camera/Panku 等保留原实现。正式发布使用 NativeAOT，编辑器调试使用普通 C# 构建。后续新增项目逻辑使用 C#。

## 本机工具链

- 引擎：带 Spine 4.3 的 Godot 4.7.2 C#，`D:/UserData/Downloads/godot/version/4.7.2 C#/godot-4.3-4.7.2-stable-mono.exe`。
- 配套模板：同目录的 `spine-godot-templates-4.3-4.7.2-stable-mono.tpz`，已确认版本为 `4.7.2.stable.mono`。构建脚本只提取本项目需要的 Windows x64 模板，不修改全局模板。
- .NET 8 SDK 8.0.425 已安装到 `C:/Program Files/dotnet/sdk/8.0.425`；首次迁移使用的项目便携版仍保留。换电脑也需安装 .NET 8 SDK，只有运行时无法构建。
- Windows NativeAOT 需要 Visual Studio 的 C++ 桌面开发工具与 Windows SDK。本机已有 Build Tools。
- `bootstrap.ps1` 从指定引擎复制对应 NuGet 包，避免使用缺少 Spine API 的标准 GodotSharp 包。包、SDK、构建输出均不提交。

### 编辑器启动与 MSBuild

本机最初只有系统运行时，导致直接打开 Godot 出现 `.NET Sdk not found` 和 `Microsoft.Build` 缺失；现在已通过微软官方签名安装器安装系统 .NET 8 SDK 8.0.425，无需专用启动入口即可构建。安装前已打开的编辑器没有成功注册 MSBuild，需要退出后重新打开，再使用 F5/F6。

`open_editor.cmd` 或 `./tools/csharp/open_editor.ps1` 仍可作为便携 SDK 的启动入口：先构建，再为编辑器进程设置 PATH 和 DOTNET_ROOT，保留原有编辑器设置与存档。仅运行一次构建脚本不会改变其他编辑器进程的环境。

Godot 在初始化时从 PATH 查找 .NET CLI。`NuGet.Config` 固定项目缓存，使编辑器和命令行使用同一套 Spine 绑定。其他机器先运行一次 `bootstrap.ps1` 准备配套 NuGet 包；也可用 `open_editor.ps1 -Godot '<配套引擎>' -Dotnet '<.NET 8 SDK/dotnet.exe>'` 启动。仅有运行时时，脚本会明确报错。

```powershell
# 编辑器调试程序集
./tools/csharp/bootstrap.ps1

# NativeAOT 原生 DLL，并验证二进制格式和 JIT 状态
./tools/csharp/bootstrap.ps1 -PublishNative

# 正式 Windows x64 游戏：使用上述 Spine/.NET 配套模板
./tools/csharp/export_native.ps1
./tools/csharp/verify_native_game.ps1

# 包含验收场景的独立原生验证包
./tools/csharp/export_native.ps1 -Validation
./tools/csharp/verify_native_game.ps1 -Suites boss,loot_growth,level_progression,damage_number_pool
```

单独编译的 Windows 原生 DLL 输出到 `.cleanup-backup/nativeaot/win-x64/zaomengxiyou.dll`。完整游戏输出到 `.cleanup-backup/export-nativeaot/zaomengxiyou.exe`；验证包使用 `export-nativeaot-validation/`。分享游戏时需保留整个输出目录，包括 PCK 与 `data_zaomengxiyou_windows_x86_64/`。

`verify_native.ps1` 检查 x64 PE、无 CLR 头、Godot 初始化入口，并调用原生探针确认动态代码与 JIT 禁用。`verify_native_game.ps1` 启动实际导出 EXE，隔离存档、捕获错误并检查退出；主关卡运行 300 帧，指定验收场景检查其 PASS 标记。验证包通过 `-- --verify-suite=boss` 路由场景，正式包不启用此入口。不要用命令行场景覆盖测试正式模板：它的构建禁用了路径覆盖。

`Debug` 用于 Godot 编辑器/F5、脚本调试和热重载。`ExportDebug` / `ExportRelease` 设置 `PublishAot=true`、共享原生库、自包含、按速度优化；关闭动态加载，保留 GodotSharp 与游戏程序集，避免裁剪掉 Godot 反射发现的脚本、属性和信号。不要把导出原生 DLL 覆盖到编辑器 Debug DLL。

## 当前迁移进度

原迁移清单包含 **32 个脚本**，并切换实际资源/场景引用；新增造1关卡与大地图也直接使用 C#：

- 运行数据：时钟、随机流、阵营、装备状态、普攻连招状态。
- 角色运动：`BattleMotionController2D` 统一管理跳跃、击退、碰撞与边界；坡面只修正位移，不将横向击退投影为持续的向上速度。
- 战斗规则：原版战力、连击统计、伤害规则及护盾/回调容器。
- 资源定义：动画配置、Boss 阶段/技能/行为配置、实体、成长、装备、普攻、攻击步骤、事件、反应、保护、派生、位移、出生点，以及区域/波次/出生计划。
- 区域、波次与出生计划的运行实例，伤害数字素材库，碧玉径入口。
- 造1花果山/水帘洞入口、统一关卡结果桥接、大地图 UI、顺序通关与跨关角色/装备存档，以及弥猴王专属技能选择、原免疫与逐帧弹道。

另有 C# 第三方生命周期适配、跨语言 Variant 边界、原生编译探针及验证包入口。旧脚本备份到忽略的 `.cleanup-backup/csharp-migration`；脚本 UID 保持不变。完整映射见 `tools/csharp/migration-map.json`。

其余项目逻辑与自维护插件仍在迁移中。现有关卡仍通过第三方脚本接口调用部分旧组件；不能将这一状态视为全项目 C# 迁移完成。

正式入口为造1大地图。新增原生验证套件：`shuiliandong`、`shuiliandong_combat`、`zaomeng_one_campaign`、`campaign_transitions`，检查完整波次、原三技能、地形往返、原卷轴 UI、磁盘存档及真实按钮跨场景路径。验证包和正式包都从此地图进入；正式包仍不包含测试路由。

跨语言接口使用 GodotObject.Get/Call、StringName、Variant 与显式参数；不使用 C# `dynamic`。Godot C# 方法的可选参数不会生成跨语言默认参数元数据，GDScript 调用需要显式传参。C# 常量/枚举通过明确查询接口或固定契约接入，避免依赖 GDScript 的静态类常量发现。

C# 不能直接继承 GDScript 基类。继承第三方 GAS、状态机和背包类型的自维护组件需要转换为组合/适配结构，保持第三方插件既有类型契约，不能仅更换文件后缀。

## 原生发布回归与兼容处理

已实际编译和运行 Windows x64 NativeAOT 游戏。验证不使用放大悟空属性、关闭怪物 AI 或替换伤害公式：初始等级1、生命275、攻击26，真实五连击击败34个目标并完成五区域及 Boss 通关。

导出包完成19组回归、1651项检查，涵盖战力、掉落成长、技能/Buff、Spine、UI、音频、镜头、地图、出生依赖、保护及500条跳字突发。C# Debug 构建与脚本图也已验证。正式包额外检查主关卡启动与干净退出。

花果山与运动控制器迁移后，Windows x64 NativeAOT 验证包已完成21组回归。新增套件覆盖造1 hit1 的真实命中/打空/镜像/扣血、AI施放、60/15FPS坡地击退、原击飞正常落地，以及花果山全部33个目标出生时位于镜头内。碧玉径仍以初始悟空和真实五连击通关；验收输入按原普攻矩形的实际可达范围尝试攻击，避免旧的230像素经验阈值漏掉可命中目标。

已修复实际导出才能暴露的问题：

- Panku 使用 `ResourceLoader.exists` 判断脚本资源，适配导出后的 `.gdc` 重映射，避免默认配置缺失造成无限回调。插件其余实现保持原状。
- Buff 明确保存 `natural_duration.tres` 持续时间策略；导出资源定制会丢失隐式 Resource 默认值。Boss 无敌、琵琶回血、无双及其他限时状态均按配置结束。
- 保护组件初始化在 `assert` 外执行，避免 Release 去掉断言后漏掉初始化。
- `CoreLifetime` 在退出时关闭第三方存档工作线程，解除线程回调保留的资源引用；导出运行检查不再报告泄漏。

引擎绑定中的反射/委托序列化仍会产生裁剪/AOT 警告，保留警告。上述验证覆盖现有功能，不证明新增的第三方反射路径也已兼容；第三方更新或新增跨语言接口后需要重新运行原生验证。

参考：[Godot 原生 AOT 发布说明](https://godotengine.org/article/platform-state-in-csharp-for-godot-4-2/)、[Microsoft NativeAOT 文档](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/)。
