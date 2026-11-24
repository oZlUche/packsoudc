# 边境集市 · 原版构图重绘
从 [游戏原图](../../../../assets/ui/market/scene.png) 起稿。[意向与坐标](brief.md)　[逐轮评语](reviews.md)　[阶段总览](stages.jpg)

|阶段|画面|校核材料|
|---|---|---|
|01 构图|[场地设计](01-plan.jpg)|[原图缩览](01-original.jpg)|
|03 线稿|[结构与光源方位](03-structure.png)|[三视图与透视](views.jpg)|
|05 光影|[单通道黑白稿](05-values.png)|[本期三视图](views/05.jpg)|
|06 色块|[一级](06-color.png) · [分层源](06-color.ora)|[本期三视图](views/06.jpg)|
|07 材质|[二级](07-material.png) · [分层源](07-material.ora)|[本期三视图](views/07.jpg)|
|08 细节|[三级](08-details.png) · [分层源](08-details.ora)|[本期三视图](views/08.jpg)|
|09 终稿|[1920×1080](09-final.png) · [分层源](09-final.ora)|[本期三视图](views/09.jpg) · [门洞开关层](gate-check.jpg) · [游戏画幅](ui-preview.jpg)|

四层由同一场景分别渲染。关闭栅门、帐棚和货物，可见完整天空、远山和路面。基础层承接全场投影，移走整件家具时须用三维源重算投影。终稿的调色作用于每一层。第 09 期与 08 共用几何。游戏运行资源维持原版。

## 本地重建
在本目录运行。使用 Blender 4.3、Python 3、Pillow、NumPy、SciPy 和 Noto CJK 字体。参考例：

```sh
STAGE=3 blender -b -t 4 --python-exit-code 1 -P source/render.py
python source/boards.py 3
STAGE=5 blender -b -t 4 --python-exit-code 1 -P source/render.py
python source/clean.py build/05-light.png
python source/boards.py 5
for stage in 6 7 8; do
  STAGE="$stage" blender -b -t 4 --python-exit-code 1 -P source/render.py
  python source/clean.py build/"$stage"-land.png build/"$stage"-gate.png build/"$stage"-tents.png build/"$stage"-cargo.png
  python source/compose.py "$stage"
done
python source/compose.py 9
python source/view_boards.py
python source/boards.py gallery
```

[Blender 场景](market.blend) 包含相机、材质、几何和打包纹理。使用支持 OpenRaster 的绘图软件可开关各期图层。

[车把、帐篷、门与箱垛原尺寸局部](details.jpg)。使用 `python source/verify.py` 可重验门洞样区和末级色调变化。
