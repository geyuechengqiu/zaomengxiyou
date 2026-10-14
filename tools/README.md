# 开发工具

这些工具用于制作、验证或构建，不作为游戏关卡发布，正式导出排除 `tools/`。

| 位置 | 用途 |
| --- | --- |
| `csharp/` | 配套SDK/绑定准备、Debug构建、NativeAOT导出和二进制/运行验证 |
| `performance/` | 实际关卡出生成本、跳字微基准，以及战斗/HUD/动画GPU截图 |
| `editor/window_mode_helper/` | 独立编辑器设置辅助工程；父目录 `.gdignore` 隔离游戏导入 |
| `audit_project.py` | 只读路径、UID与场景分类审计，Python标准库，无额外依赖 |
| `verify_stage_eight.ps1` | 31套当前功能回归，隔离存档、Dummy音频、每套默认240秒超时 |
| `author_*`、`refine_*`、`build_*` | 场景与UI制作管线 |
| `author_map_presentation.py` | 花果山/水帘洞树冠材质、独立风摆资源与战斗时钟动画；两关离线导入自动调用 |
| `import_*`、`export_*`、`Export*.java` | 原版素材/配置解析与离线导出 |

离线管线保留原路径，避免破坏脚本之间的调用和来源记录。它们通常需要原始SWF、DragonBones、JPEXS或本地Python依赖；游戏运行不需要重新导入。查看每个脚本的源文件说明后使用，日志及输出缓存放入 `.cleanup-backup`。

```powershell
py tools/audit_project.py --report .cleanup-backup/project-audit.json
./tools/verify_stage_eight.ps1 -Godot '<配套 Godot.exe>'
```

GPU截图和微基准必须使用 `--audio-driver Dummy`，并将 `APPDATA`/`LOCALAPPDATA` 指向项目缓存内的独立测试目录；不要使用真实玩家存档。游戏的F5/F6、音量和静音设置不因此改变。
