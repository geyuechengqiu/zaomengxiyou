# 造梦西游1：所提供的 zmISAV VTest 版本

源目录：`D:\UserData\Downloads\game\swf单机\这是正常flash游戏\造梦西游1`。文件中的更新公告自称 **zmISAV VTest**，包含本地多存档、九周年活动、装备附加属性、修改特效与音乐、掉宝率调整等改动。因此这里记录的是这份实际文件，不将其配置视为未修改的官方初版。主 SWF 为 Flash AS3、版本34、940×590、30FPS。

## 文件和加载关系

`打开我开始玩.swf` 为入口，`GMain → loader.Aloader` 将 Role、Monster_v1、Monster2_v4、Monster3_v3、OtherMat_v5、backpack_v2、Music 七个 SWF 依次装入共同 ApplicationDomain。Role 负责角色，三份 Monster 包负责怪物，OtherMat 负责附加素材，backpack 负责背包，Music 负责声音。`美化包` 中的 Role/Music 是替换版本，分析主目录时未混用。文件名 `1` 尚未确认用途，不臆测为配置档；完整文件大小和 SHA256 见 [来源清单](source_manifest.json)。

## 关卡配置导出

[levels.json](levels.json) 包含每个实际关卡标签的出生点、出生总数、delay、interval、enemyType、stopPointIdx、StopPoint 的原始 idx/isBoss/betweenRandL、场景坐标和障碍。`runtime_stop_points`另记录PhysicsWorld重建停止点后按X排序生成的idx与实际宽度；原编辑器属性原样保留，不能直接用来绑定波次。数据来自 GameSence 显示列表和组件构造脚本，按原 `gotoAndStop(stage + "-" + level)` 选择标签首帧；[timeline.json](timeline.json) 另保留完整帧与显示对象，方便检查后续关键帧。没有将场景电影剪辑动画的每一帧误判为单独关卡。

| 关卡标签 | 场景帧 | 出生计划 | 计划怪物数 | 停止点 | 刺障碍 |
| --- | --- | --- | --- | --- | --- |
| 1-1 | 1 | 14 | 33 | 5 | 0 |
| 1-2 | 5 | 18 | 48 | 5 | 0 |
| 1-3 | 10 | 15 | 49 | 5 | 0 |
| 2-1 | 15 | 17 | 3037 | 5 | 35 |
| 2-2 | 20 | 20 | 66 | 5 | 35 |
| 2-3 | 25 | 22 | 61 | 5 | 39 |
| 3-1 | 30 | 16 | 67 | 5 | 0 |
| 3-2 | 35 | 24 | 69 | 5 | 0 |
| 3-3 | 40 | 16 | 73 | 5 | 0 |
| 4-1 | 45 | 3 | 61 | 2 | 0 |
| vs | 49 | 0 | 0 | 0 | 0 |
| 9-1 | 55 | 1 | 1 | 1 | 0 |

2-1的3037是源配置totalNum合计：该修改版在停止点4设置了三个999只计划及一个Boss，并非导出器将999改为普通波次。表内统计是出生计划配置总量，不保证实际一局必然生成这么多目标；移植时应结合Boss结束与出生队列清理规则。

11个PVE标签包括1-1～3-3、4-1和9-1，另有 `vs` 对战标签。9-1用于副本；`my.MainGame` 还将特定挑战入口转入9-1。名称没有从编号猜测，坐标也没有套用当前上古天地项目的2倍世界比例。不存在单独XML关卡文件：配置在SWF显示列表、GameSence组件属性与脚本中。

## 运行逻辑与移植注意

`GMain → my.MainGame.GameStart → export.GameSence → PhysicsWorld` 创建关卡、人物、物理世界和场景对象。StopPoint 首次触碰按 idx 启动对应出生计划；`MonsterAppearPoint` 先等待 delay，再按 interval 出生，单人模式上限6只活怪、双人模式8只活怪；9-1的逻辑要求前一目标死亡后再生成。计划生成完成会从出生队列移除，通关还要结合活怪和停止点检查，不能只检查当前没有怪物。

出生计时源码使用 `count / 24`，而此修改版显示时钟为30FPS：原delay/interval数值应保留，直接按秒移植会改变实际节奏（连续计数时原数值乘24/30得到实际墙钟时间，活动暂停和活怪上限等待还会影响计数）。PhysicsWorld不会直接使用编辑器StopPoint实例，而是读取位置、重新创建、按X排序，并在pWorldStart依次赋idx。停止点活动宽度默认1150，第一章改为1450，4-1与9-1改为940；例如9-1源码组件idx=4，但运行时唯一停止点idx=0，与出生计划stopPointIdx=0对应。原版角色和怪物规则、UI以及存档与当前上古天地并非同一系统，导出资料独立保存，不自动覆盖现有技能或关卡。

## 重新导出

在Godot项目目录运行：

```powershell
python tools/export_zaomeng_one.py --source "D:\UserData\Downloads\game\swf单机\这是正常flash游戏\造梦西游1" --reference-root "D:\UserData\Downloads\game\Speculum-4399-master"
```

工具只读原目录，导出到本目录。关键反编译脚本保存在 [sources](sources/)；没有运行Flash游戏代码，也没有修改原SWF。主版本及美化版本的校验值分别保留，可检测之后更换文件导致的配置差异。
