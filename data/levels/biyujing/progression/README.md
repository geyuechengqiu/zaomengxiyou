# 碧玉径区域与刷怪配置

[原版Boss栏、怪物出场和清屏后提前移镜](../../../../addons/battle_foundation/boss/original-presentation.md)已接入F5首关，可在预置场景和区域配置调整。

五区域共用一张连续地图，已经接入原版背景、动态云层、地板及近景。地图与视觉均为可编辑继承场景；[复用模板与编辑说明](../../../../addons/battle_foundation/level/map-template.md)。

F5运行 [level_progression_demo.tscn](../../../../examples/level_progression_demo.tscn)。A/D移动、K二段跳、J普攻、Y/U/I/O/L技能、空格无双预览；Esc暂停/改键。完成当前区域全部出生计划与目标后，右侧门开启；最后击破复苏容器、击败玉石琵琶精，在地面出口标记处按W/↑确认通关。重开按钮重新载入场景和关卡实例。

系统实现、原版时序、各区关系、额外条件、事件和验收见 [关卡系统](../../../../addons/battle_foundation/level/README.md)。

镜头跟随配置见 [原版摄像机](../../../../addons/battle_foundation/camera/README.md)：演示场景的BattleSession/CameraRig可调整源帧率、首区与过区插值系数；CameraRig/PlayerCamera编辑Zoom。过区仍由同一关卡实例解锁，保留原画面后连续滚动。

## 在Inspector修改

| 位置 | 配置 |
| --- | --- |
| [definition.tres](definition.tres) | Regions、Waves、Spawn Plans；Condition IDs、Required Conditions、Required Boss Plan IDs |
| `regions/*.tres` | Bounds决定镜头边界；Entry Rect、Exit Rect为世界矩形；Wave IDs、Required Conditions、Automatic Exit |
| `waves/*.tres` | Plan IDs、After Wave IDs、Required Conditions |
| `plans/*.tres` | Monster IDs有序列表；Delay Seconds、Interval Seconds、After Created Plan IDs、After Dead Plan IDs、Spawn Point ID、Facing |
| `plans/*.tres` | Participates In Clear控制是否阻挡清屏；Is Boss及关卡的Required Boss Plan IDs控制最终Boss条件 |
| [map.tscn](map.tscn) 的 SpawnPoints | 拖动Marker2D改变出生位置；Random Position/Random Rect设置随机位置；ID与计划对应 |
| [visual.tscn](visual.tscn) | 远景、中景、云层、地板拼接与近景；预置AnimationPlayer可预览clouds，视差/透明度在对应层及Sprite的Inspector修改 |
| map.tscn的 Terrain | 原TMX矩形墙/地板和单向平台；直接编辑形状与坐标 |
| map.tscn的 Gates | 与区域对应的静态门、碰撞和标签。改边界时同步修改区域Bounds、Exit Rect及门位置 |
| 演示场景 BattleSession/LevelInstance | Player Path、Points Path、Gates Path、Camera Path绑定预置节点 |
| [manifest.json](manifest.json) | 定义索引。新增怪物/技能/关卡必须登记后才能出生 |

坐标已经换算为原版2倍世界坐标，不再次乘2。初始第一屏右界2368，地面顶1056；最后Gateway矩形为(10048,920,256,256)。Monster IDs用`剑舞`或`驭兽使`，角色技能用语义ID；原数字出生点仅写在元数据中便于追溯。

首次出生等待 `Delay Seconds + Interval Seconds`；调整第二波间隔时会同时影响首只和后续怪物。前置出生完毕与前置全部死亡是两个独立条件，可以组合。前置波次完成要求该波次所有参与计划出生完毕且目标死亡；配置循环会在加载时被拒绝。

## 添加关卡

1. 复制本目录的定义、区域、波次和计划资源，改为自己的语义ID。
2. 从基础地图/视觉模板创建继承场景，或复制现有map.tscn与visual.tscn，编辑整张地图的美术、地形和平台；预置人物、SpawnPoints与Gates。所有区域在同一坐标系，不切换地图场景。出生点/门ID需与计划/区域对应。
3. 将新地图实例放在BattleSession下，预置LevelInstance与BattlePresentation。演示脚本调用`register_scene_level(关卡ID,地图根节点)`；控制器初始化只绑定节点。
4. 编辑manifest登记怪物、技能和新关卡。每只生成的怪物实例化已有完整角色场景，复用GAS、AI、运动和死亡。
5. 使用已声明的条件ID接入机关、任务或护送；统一调用`set_condition`。不要在业务层用活怪数量直接开启出口。

## 离线导入

[import_stage_twelve_level.py](../../../../tools/import_stage_twelve_level.py)从本机原版仓库读取TMX及配置，重新生成本目录和容器/Boss的新资源，保存源文件哈希及原始对象。它不重建悟空或阶段11的小怪资源，但会覆盖本目录的手动编辑，日常调参直接保存资源即可。

```powershell
python tools/import_stage_twelve_level.py --original-root 'D:/UserData/Downloads/game/Speculum-4399-master'
python tools/import_stage_thirteen_boss.py --original-root 'D:/UserData/Downloads/game/Speculum-4399-master'
python tools/import_biyujing_map_visual.py --original-root 'D:/UserData/Downloads/game/Speculum-4399-master'
```

阶段12导入会重建Boss初始资源，需随后运行阶段13导入恢复三技能/专属行为与技能索引。当前Boss已接入原版播报、三层血条、保护、弹道和实体石墙，详见[Boss配置](../../../monsters/jushi_lingjun/README.md)。最后执行视觉导入，重新导出六张共享贴图、201帧云动画、视觉继承场景和来源记录，恢复模板接入。只导出地图美术时仅运行第三条命令。未导入可选补血罐与NPC互动；原始对象保留于 [original_source.json](original_source.json)。
