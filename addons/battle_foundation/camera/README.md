# 原版跟随与Phantom Camera接入

F5运行碧玉径。Camera2D的跟随由预置PhantomCameraHost和PhantomCamera2D应用，`BattleCameraRig2D`负责把原版Camera2的目标、插值和区域约束转换为插件跟随锚点。演示脚本不再直接写入镜头X坐标。

## 原版规则与瞬移原因

原版`Camera2.as`先取得玩家位置，将画面中心对准玩家，再按当前ScreenRange裁剪。地图608源像素高、画面590源像素高，因此垂直滚动范围只有18源像素；当前世界坐标×2，对应镜头中心Y为590～626。地面跟随时可见顶部为36世界像素，跳跃到较高处时可以回到顶部0。

首次普通跟随`_moveSpeed=1`。`BattleMapBase.GotoNextScreen()`默认调用`camera.gotoNextScreen(0.2)`，后续每个源帧使用`lerp(旧位置,目标位置,0.2)`。这个系数在过区完成后仍然保留；原代码没有在结束过渡时恢复1。

原版过区的`_goingNext / _lasetX`采用只向右推进的左边界。按当前操作要求，镜头改为在已开放区域内双向跟随：首次定位记录地图左边界，后续切区保留已开放的左边界，右边界随当前区域解锁。过渡中与过渡完成后，回头都会按当前人物位置平滑跟随，可以返回已清区域；不再冻结横向插值或记录人物最远位置。自动出口仍仅在向右移动且通关条件满足时触发，回头不会重复切区。垂直跟随保留原规则。

旧演示每个渲染帧直接赋值`camera.position.x = player.global_position.x`，Camera2D的限界把画面暂时截在旧区域。解锁右边界时底层镜头位置已经在玩家处，画面立即跳到该位置。新实现保留独立跟随进度，只更新目标及边界，Phantom Host负责将每个战斗tick的结果写入Camera。

原版相邻源帧的插值换算为任意delta：

```gdscript
alpha = 1.0 - pow(1.0 - source_weight, source_fps * combat_delta)
center = center.lerp(clamped_target, alpha)
```

在固定目标下，30FPS系数严格为0.2，60FPS单步约0.105573；两个60FPS步与一个30FPS步等价，低帧率不会延长或加速同一目标的过渡。移动目标在当前物理tick采样，保留Godot固定物理更新，不把每个物理tick误当一个30FPS源帧。

源文件、原始TMX、关键入口与SHA-256见 [original_source.json](original_source.json)。

## 预置节点及更新顺序

```text
LevelProgressionDemo
├─ Camera2D
│  └─ PhantomCameraHost       BattlePhantomCameraHost，Manual
└─ BattleSession
   ├─ CameraRig              BattleCameraRig2D
   │  ├─ FollowTarget        Marker2D，保存本次平滑后的跟随位置
   │  └─ PlayerCamera        PhantomCamera2D，Glued，Zoom=0.5
   ├─ Actors                 连续地图及角色
   └─ LevelInstance          区域、出生与出口条件
```

[battle_camera_rig_2d.tscn](battle_camera_rig_2d.tscn)是可复用组件场景，主关卡已经实例化；所有镜头组件、虚拟镜头和锚点预置，运行时不创建。Phantom Camera插件及Manager已在project.godot启用，编辑器Updater设置为Off。

BattleSession在实体、战斗反馈与区域更新后，调用`camera_rig.advance_camera(combat_delta)`。菜单暂停、SceneTree暂停、慢动作及受击停顿沿用BattleClock；死亡和离场停止跟随。Host设为Manual，活动PCam关闭自身自动_process，由Host手动推进。渲染帧不再次推进跟随。[Phantom Camera手动更新接口](https://phantom-camera.dev/core-nodes/phantom-camera-host)

当前虚拟镜头使用Glued跟随已经完成原版插值的锚点，不再叠加插件SmoothDamp或Camera2D默认平滑。初次加载可以定位；正常过区不会调用teleport_position或更换虚拟镜头。

Camera2D与PhantomCamera2D的左硬限界始终使用已开放地图的左边界，避免切区瞬移，也允许回头跟随。右边界仅解锁至当前区域末端，未通关区域仍不可提前显示。刷怪、门和通关规则继续由LevelInstance决定；镜头返回已清区域不会回退或重复关卡进度。

`BattlePhantomCameraHost`继承原插件Host，限定候选镜头必须位于自己CameraRig下，并将原插件全局限界通知转换为当前活动PCam的边界。这样多个同配置会话不互相抢镜头，也不会被其他镜头广播的边界影响；切换时保持严格关卡限界。未改动第三方插件源代码。

地图视差仍读取实际canvas可见位置，因此原远景、宫殿、云层及近景跟随已经平滑后的镜头。现有Boss震屏仍由公共表现组件按战斗delta更新Camera.offset，跟随只管理transform和zoom；两者不会重复计算位移。

## Inspector配置

| 位置 | 参数 |
| --- | --- |
| `BattleSession/CameraRig` | Player Path、Camera Path、Host Path绑定当前场景的预置节点 |
| CameraRig | Source FPS=30；Initial Follow Weight=1；Region Follow Weight=0.2，越小过区及后续跟随越缓 |
| `CameraRig/PlayerCamera` | Zoom=0.5、Priority=10、Follow Mode=Glued；Follow Target绑定FollowTarget |
| `Camera2D/PhantomCameraHost` | Phantom Root Path指向当前CameraRig；Interpolation Mode保持Manual |
| `LevelInstance` | Camera Rig Path指向预置CameraRig；原Camera Path保留给未使用插件的旧场景 |
| `regions/*.tres` | Bounds定义当前区域镜头范围，使用整张连续地图的世界坐标 |
| 区域的 Camera Transition Margin | 清屏后自动过区判定向左提前多少世界像素；当前844，合计右侧半屏940世界像素。最终出口为0且不自动切区 |

添加新关卡时实例化CameraRig，在Camera2D下预置此Host，调整节点路径；LevelInstance负责初始定位及过区通知。不要同时让其他脚本修改Camera.position、启用默认位置平滑，或让Host再次自动计时。

清屏后提前范围、原版Boss血条和出场流程见[联动说明](../boss/original-presentation.md)。第一波全死但后续延迟计划未完成时，提前范围仍不生效。

## 验收

[verify_camera_follow.tscn](../../../tests/suites/verify_camera_follow.tscn)使用实际主关卡和原插件验证源帧样例、切区画面连续、过渡中回头与完成后返回已清区域、地图左右边界、五区初始定位、上下跟随、15/30/60/120FPS与低帧率、暂停/慢动作/停顿、原地图视差、多会话隔离、死亡和清理。

[verify_level_progression.gd](../../../tests/suites/verify_level_progression.gd)另在实际自动出口资格满足时检查新镜头位置及渲染中心，不仅直接调用镜头组件。[capture_camera_follow.gd](../../../tools/capture_camera_follow.gd)使用实际D3D12、物理跑步和自动过区，保存过区前、进入、过渡及过区后的画面。

```powershell
& './tools/verify_stage_eight.ps1' -Godot '<带Spine模块的Godot.exe>' -Suites camera_follow,level_progression,map_visual,boss
```

2026-10-09实测：镜头56项、真实关卡186项与地图83项检查通过，默认29套回归全部通过。D3D12真实跑步过区检查通过，60Hz进入新区时最大单步约10世界像素（5画面像素），随后连续推进；没有立即跳到玩家或新区左边界。原始悟空的完整关卡/Boss战斗验收保持通过。

2026-10-10反向跟随修复：镜头60项、真实关卡192项、地图83项、Boss表现41项，共376项回归检查通过，日志无脚本或运行错误。覆盖真实清怪自动过区后回头、过渡完成后返回已清区域，以及未通关区域右边界仍锁定。
