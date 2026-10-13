# 地图、设置与动作速度

- 玩家属性在 `data/characters/sunwukong/character.tscn` 的 Attributes / Base Values 编辑。`attackSpeed` 默认为 1.0（100%），`baseRunSpeed` 默认为 600。实际移动属性仍是 `walkSpeed` / `runSpeed`；速度状态的 `movement_speed_scale` 也参与移动动画比例。普通攻击的动画、源帧命中判定与动作位移同步缩放，冷却、重力、恢复和视觉状态仍使用各自的战斗时钟。
- `BattlePlaybackPolicy.cs` 将造1小猴、山猴和大猩猩的 hit1 源帧时钟统一设为 0.8。猕猴王使用其独立技能时序，不重复减速。
- 地图节点及图标位置在 `game/world_map/zaomeng1_world_map.tscn` 编辑；最新解锁关卡的 Glow 使用 `assets/ui/shaders/map_icon_glow.gdshader`，与关卡是否制作完成分别判断。第三关桃花源尚未制作，因此可以发光，但不能进入。
- 地图名称从 `data/campaigns/zaomeng1/world_map.json` 的 `display_name` 读取，当前为“东胜神洲（七魔王）”，显示在世界按钮上方。世界图标使用原版 toolScene 的 1072 素材第 4–6 帧，名称牌与圆形底座使用原版 1039 连接框（`world_name_frame.png`）；NinePatch 只延展名称区域，保留底座和连接装饰比例。点击仍调用现有未开放接口。关卡悬浮使用造1原版第 2 帧的高亮和描边名称，移除了额外黑色文字提示框；禁用关卡也可悬浮查看名称，但保持原点击限制。
- 地图背包和技能绑定预置的 CharacterSession。`WorldMapInventoryCatalog` 合并现有关卡的物品定义，换装、升级及昵称变更保存到同一角色存档。
- 设置场景为 `addons/battle_foundation/input/battle_operation_menu.tscn`，逻辑为 `OriginalSettingsPanel.cs`。原版继续游戏、重试、返回地图和声音设置已接入；未开放的显示、详细设置等按钮发出 `FeatureRequested` 信号。主城、世界及其他地图未开放入口保持可点击接口。
- 音乐沿用 Core 音频插件的 Music 总线；打击和技能音效分别走 BattleHit / BattleSkill，两者发送到 SFX，总音量及总静音仍有效。独立混音保存在 `user://battle-audio-mix.cfg`。
- 模态场景通过 `metadata/ui_modal = true` 注册到 `UiModalManager`，预置 ModalBarrier / InputBarrier 负责全屏鼠标拦截；显示时同步调整输入场景顺序。原版技能键盘、装备出售、批量出售、称号接口和设置分页均保持各自的遮罩。
- 离线重新提取原版 UI：运行 `tools/refine_world_settings_ui.py`，再执行 Godot 编辑器资源导入。它只读取原 SWF，不修改原游戏。新增回归为 `world_settings_speed`，包括真实鼠标按下/松开、解锁高亮、混音和实际攻速时间轴。
- 自动化测试脚本显式使用 `--audio-driver Dummy`，不会播放实际声音，也不修改玩家的静音偏好。GUI 截图测试同样传入该参数。编辑器 F5/F6 正常运行仍使用原音频驱动和设置。
- 本次验证：Debug 的 30 组回归全部通过；NativeAOT 的地图/设置/速度、Boss、背包、技能、音频、花果山战斗、水帘洞战斗和跨关卡存档 8 组回归通过。正式 NativeAOT 包运行 300 帧并正常退出。测试使用隔离存档，不重置玩家进度。图形编辑器退出时仍存在原有的 3 个 ObjectDB / 2 个资源释放提示，第三方 PhantomCamera 保留原有的 4 条编译警告。
