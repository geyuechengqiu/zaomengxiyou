# 原版普通受击特效 hurtEffectAll

素材直接提取自本地 Speculum-4399-master 的 `games/zmhj-g5/cache/assets/ui/mission2_20250707_1.swf`，保留原始 RGBA 像素、帧序和注册点。此文件实际上是 AMF3 图集容器；导出过程只读解包，不执行 ActionScript。

11 帧 / 30 FPS / 单次播放 / 151×150 / pivot=(72,73)。原第 0、1 帧等成对重复帧按原序保留，最后一帧是透明占位帧；总时长 11/30 秒。每帧 region、trim、pivot、透明标记和 PNG SHA-256，以及原图集与源码哈希，见 [source_mapping.json](source_mapping.json)。

可编辑动画场景：[hurt_effect_all.tscn](../../../data/effects/hurt_effect_all.tscn)。Sprite2D centered=false、offset=(-72,-73)，AnimationPlayer texture 轨道逐帧切换 PNG；战斗时钟驱动，命中时播放并在结束后隐藏。完整接入、挂点/比例规则与场景操作见 [单段战斗 README](../../../addons/battle_foundation/combat/README.md)。

导出命令（Python 环境需要 Pillow，并使用原版项目的解包模块）：

```powershell
python tools/export_original_hit_effect.py '<Speculum-4399-master 本地路径>'
```

工具同时生成本目录 PNG、来源记录及动画场景。项目运行只加载已导出的本地资源，不需要原版项目目录或 Python。
