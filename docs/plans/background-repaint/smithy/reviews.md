# 铁匠铺 · 制作与独立审图记录

[原始背景](01-original.png) 在基地后勤页由 meta_screen.gd 通过 smithy/scene 选取。smithy_panel.gd 与 smithy/layout.json 另外绘制分类木牌、物品格和锻造铁砧。[场景说明](brief.md) 与 [场地平面](01-plan.png) 记录本次取舍。

## 本次修订 · 炉前铁砧与成品调色

| 阶段 | 本次检查 |
|---|---|
| 01 场地与视图 | 砧面初稿高 1.40 m，退回重建。现高 0.994 m，中心 (−4.28, −1.40)，木墩直径约 0.91 m。底座周沿 12 个测点中 11 个落在同一块铺石，另一点跨过约 12 mm 深的拼缝。 |
| 03 结构 | 一版临时模型叠了两套砧，独立考官辨出双尖角，58/100，退回。清除旧工位后重新渲染，另一位考官给 82/100。砧身、砧脚、木墩均可分辨；炉台与砧腰仍需靠明度拉开。[结构稿](03-structure.png) |
| 05 黑白 | 初评 6/10，指出炉膛噪点、近火亮度衰减及右架暗部。单砧版本局部去噪，按炉火贡献调整内壁与台沿；复审 82/100。砧座右后投影与桶架底缘成立，右侧细钳在缩图下仍弱。[黑白稿](05-values.png) · [配方界面](ui-values.jpg) |
| 06 一级色块 | 8/10。灰蓝地面与暖墙能区分空间，珊瑚色墙裙横线仍较突出。[色块](06-color.png) |
| 07 二级材质 | 7.5/10。铺地石、拱券、木墩和铁件可分，墙砖拼缝较齐。[材质](07-materials.png) |
| 08 三级细节 | 7/10。木墩补箍钉与端面干裂，锤头保留磨亮面。右侧细工具在缩图中略有重叠。[细节](08-details.png) |
| 09 调色与终审 | 7.5/10，作为配方页背景通过。暖调突出火焰和砧身，石、砖和木的冷暖差异有所收窄。[调色对照](before-after.jpg) · [成品](09-final.png) · [配方界面](ui-preview.jpg) |

所有评分与盲审使用无会话历史的子代理。06 至 09 的艺术评价由同一名新考官按阶段逐图给出，最终来源判断使用另一名考官。盲审提问为“能否确认这张图为AI生成的？有哪些不符合常理的纰漏？”考官回答无法由画面确认，指出烟道顶端像封板、烟罩黑灰比炉口上沿显眼，以及木柴截面规则。模型中的烟道贯穿顶板，正面镜头隐藏了通孔。烟垢分布、木柴外形仍带有简化痕迹。[剖面](flue-section.jpg)

**回退。** 06 至 08 各自保留六个图层，由底向上为建筑与地坪、环境受光、炉体与挂具、桶与备料、铁砧投影、铁砧工位。09 在此基础上增加一层成品调色，关闭它就能逐像素还原 08。调色层按当前构图烘焙；改动物体后，可导出修改后的底稿，再运行 `python grade.py 输入.png 输出.png` 复现同一映射。三维源稿保留几何与灯光，最终显示调色在图像合成阶段完成。[成品 ORA](09-final.ora) · [模型](smithy.blend) · [调色脚本](grade.py)

**实机核验。** Godot 4.6.3，1280 × 800，基地后勤页打开铁匠铺并选中「制式短剑」。炉口下方可见完整砧角、砧面与木墩，导航和配方框均未遮挡工位。此次验证覆盖该视口与配方。[实机截图](ui-preview.jpg)

**调色核验。** 同一构图的 08 与 09 按显示编码 RGB 计算亮度分量 Y′（Rec.709 权重）。平均 Y′ 从 0.590 降至 0.521，P90 与 P10 之差从 0.425 增至 0.537，平均红蓝通道差从 0.156 增至 0.239。白平衡向暖色移动，炉芯保留亮部。[阶段总览](stages.jpg) · [三视图](views/README.md)

## 首次交付的审查记录

原版图像与对应评语保存在 [首版交付](https://github.com/oZlUche/packsoudc/tree/d1eefd3a/docs/plans/background-repaint/smithy)。以下链接指向该次交付的原版文件。

每位考官使用新会话，只接收当阶段的图片、用途与题目。下表按实际版本记录。正视、侧视、俯视及成品镜头分别交代承托、占地和画面遮挡。

| 步骤 | 审查与处置 | 留档 |
|---|---|---|
| 01 方案 | 选择左炉、右料、中央操作界面的室内场地。以米制坐标标明炉床和水桶位置，由文字方案补足原画遮住的炉膛和壁龛进深。 | [占位与机位](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/views/01-views.jpg) |
| 03 结构 | 首评 82/100，要求交代烟道穿顶和挂点。补天花穿孔、耐火圈与挂钉。另一位考官在灰模发现吊柄仍有缝，建议补砧或确认前景。核实游戏已绘制铁砧，补吊眼、钳轴与止脱端。独立复核 8.5/10，通过。 | [结构](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/03-structure.png) · [三视图](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/views/03-views.jpg) |
| 05 光影 | 首评 6.5/10，暂缓铺色。增强炉床照到炉沿的暖反射，补画外庭院的低侧光，提亮中央暗柱。第二位考官 7/10，要求看清跨面投影。加入画外廊柱，检查它在墙脚与地面的投影，并实拍游戏前景；新版复核 8/10，通过。右侧柴架暗部略粘。 | [黑白稿](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/05-values.png) · [分光对照](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/light-study.jpg) · [实际界面](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/ui-values.jpg) · [三视图](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/views/05-views.jpg) |
| 06 一级细化 | 首评 7/10，退回调整炉前工作地面和冷暖关系。补深灰耐火铺面与桶箍，调整日光和炉沿反光；复核 8/10，通过。对炉子分层时让较近的天花充当遮挡，避免烟囱顶端被错误贴在天花前方。 | [色块](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/06-color.png) · [可编辑源稿](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/06-color.ora) · [三视图](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/views/06-views.jpg) |
| 07 二级材质 | 初评 74/100，要求烟罩烟熏、木铁粗糙度和火口噪点再处理。分别生成并投射矿物笔触、烟熏颜料两幅底色，纹理打包入模型。在烟罩上沿烟道方向布置烟垢；材质复核 78/100，准予细化。进一步压低了柴端过亮的环纹。 | [材质稿](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/07-materials.png) · [四层源稿](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/07-materials.ora) · [三视图](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/views/07-views.jpg) |
| 08 三级细化 | 保留高频使用处的磨损。铲脚和炉口下方有稀疏煤屑及同向扫灰；炉沿擦亮处打断连续高光，木柴端头有局部开裂。独立评分 8.5/10，可进终审。中央两跨未加道具。 | [细节稿](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/08-details.png) · [可编辑源](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/08-details.ora) · [末阶段三视图](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/views/08-views.jpg) |
| 09 终审 | 独立终审 88/100，通过。无等宽描边，留白支持实际配方页。保留意见为火焰核心偏白、炉前暖反射较弱，远看墙上两个铁环的用途不够直观。 | [成品](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/09-final.png) · [实机界面](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/ui-preview.jpg) · [各步骤一览](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/stages.jpg) |

**来源与常理盲审。** 新会话只收到中性文件名的成品及问题“能否确认这张图为AI生成的？有哪些不符合常理的纰漏？”结论是无法仅凭图像确认来源。疑点一是烟道顶端像盖板；成品可见其防火圈，内部排烟路径在交付模型中补通，沿四段中心线检测均无实体遮挡。疑点二是中央工作区缺铁砧；实际配方页在这里叠加铁砧面板，左炉口仍从导航下方露出。[烟道侧剖](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/flue-section.jpg) · [彩色实机图](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/ui-preview.jpg)

**首版的回退与编辑。** 第 06、07、08 步各有四个独立图层，从底到顶为完整建筑与地坪、炉火与道具对建筑的受光影响、炉体和工具、冷却桶与备料。需要单看空室时关闭上三层。三份 ORA 均已按 stack.xml 的层序重新合成并与同阶段 PNG 做全幅逐像素比对。第 09 步与通过的第 08 步像素相同，复用其分层源。三维模型保存机位、灯光和实体，内嵌所用的绘制纹理；编辑时可检查炉顶剖面或换机位。[可编辑模型](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/smithy.blend) · [三视图与透视稿索引](https://github.com/oZlUche/packsoudc/blob/d1eefd3a/docs/plans/background-repaint/smithy/views/README.md)

**界面验证范围。** Godot 4.6.3 在 1280 × 800 运行时打开后勤铁匠铺并选中制式短剑。测试中临时载入待审背景，导航、物品列表、铁砧、价格和按钮均由实际游戏渲染。验证针对这一界面状态及尺寸。
