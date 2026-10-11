# 原版霸体描边

依据 `ManEntity.createBaiTiEffect`、`ColorFilterAnimation`、`ColorUtils.changeColorto`：红色 `FF0000` 与黄色 `FFFF00` 来回变化，GlowFilter 的宽高为5、强度为3。颜色每方向11个，包含两端；原版每30FPS帧推进一个颜色。构造器的0.3秒参数实际未参与计时，不能按它重新解释动画。

悟空和现有四种怪物的动画场景都预置 `SuperArmorEffect`，基础模板复用这些场景。描边读取统一受击控制器的霸体判断（常驻、动作规则、GAS标签、保护霸体），仅管理表现。开启无双时按原版隐藏霸体描边，保留无双红光与残影，且不撤销霸体战斗规则；无双结束时仍有效的霸体会恢复描边。

打开角色 `AnimationAdapter/SuperArmorEffect`：`Enabled` 对应原 `showBatiEff`；`Capture/Body` 的骨架必须与兄弟 `SpineVisual` 相同。新增 Spine 角色可运行 `tools/author_super_armor_effects.py <Speculum根目录>` 为现有场景保存预置节点；生成工具不会覆盖已编辑的描边节点。Boss 的捕获区域扩为512×512，普通角色为320×320。

描边由独立 ShaderMaterial 和 GPU 轮廓快照绘制，只采样角色的 Spine 节点，不改变源节点材质、调色、透明度或动画。悟空攻击特效、无双红光和残影不进入捕获；外侧描边不重复绘制身体。每个角色独占材质与姿态，图集只读共享；非霸体期间禁用视口更新。颜色及快照由战斗时钟驱动，暂停/慢动作/命中停顿一致，死亡/离场立即隐藏并停止渲染。

来源和 SHA256 见 `original_source.json`。功能验证：`tests/suites/verify_super_armor_visual.tscn`；GPU画面验证：`tools/performance/capture_super_armor.gd`。
