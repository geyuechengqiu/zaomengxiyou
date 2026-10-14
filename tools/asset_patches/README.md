# 孙悟空超分碎图修补

`sunwukong_base_belt.png` 是 imagegen 修复后的 124×32、直通透明 PNG。
修补内容是去掉超分产生的灰色条纹，恢复普通腰带的平滑深灰表面。
打包时沿用原碎图的透明轮廓；骨架、图集区域和挂点不变。

`upscale_spine_atlas.py assemble` 通过 `base/zb/yf_20` 查找共享碎图，
同时应用到 `base`、`armor0` 和 `armor0_0` 的图集和可编辑图片。
此文件夹不作为游戏资源导入，修补结果已经打入角色的 `wukong.png`。
