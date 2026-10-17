# 180 方案：开局屏第二、三页重排 —— 配道具页减文案、地上物件不重叠；选地图页改为地图列表 + 难度加减 + 晕染展开，入局拉近过渡

> 架构设计线程，2026-10-17。只写方案，不实现。实现归「架构方案执行」，画面归「美术设计」。
> 样稿（平板线框，1600 × 1000，只定位置与尺寸）：https://claude.ai/artifact/AJ5wRKU116wZ4E2qvVs2Ss（第 4 版）。
> 上接 179（选角色页）；本篇覆盖 161 中第二、三页的结构，并修正 128 / 134 关于地上物件「允许重叠」的规定。

## 0 作者 2026-10-17 09:05 的指引（原话摘录，分项编号便于对照）

第二页
- A1 传达给美术：左侧栏要有皮革元素，右侧木质框架，背景是仓库图片。
- A2 删掉「已带」「带上」等字样，以及「往左边的行囊里拖，放得进的就是带的；带进去的从仓库拿走，撤离了回来，死了就没了」这种多余的说明。
- A3 掉落在棋盘外的道具不能重叠，相遇会弹开（先设计为半弹性碰撞）。

第三页
- B1 删掉「自由模式」和下面的说明，左侧列表全部删掉；序章是新手教程只出现一次，不该反复体验。
- B2 左侧改为地图选择（当前只有「魔法废墟」一张）；选中一张地图后在该条目下方展开次级列表，选择地图（规模）。
- B3 难度选择移到摘要下方：顶端「当前难度」，下方大字号数字单独一行，默认 0，继承上一局；数字下方加减两个按钮；每升一级在下方说明栏用红字显示这一级的挑战。
- B4 删掉种子选择，玩家不能调（调试台可用）。
- B5 告诉美术：选不同地图时，空白背景上以晕染的形式从中心展开一片区域；规模的圈数在这片区域里显示，不同规模视觉不同、符合直觉。
- B6 入局过程：视觉上拉近距离，圈变清晰并显出节点，背景浮现局内地图的装饰元素（石头、河流、树木等）。实现方式不限，结合引擎性能决定，要建议和思路。

先前已确认的方向：样稿只做平板线框；第三页纸底要和局内地图底色相近（四张底图平均色：帝国营地 #d2cbba、遗迹 #cebb96、北林 #c1c6b9、诅咒深处 #322828）。

## 1 现状（只列和改动有关的）

- `ui/game/setup_screen.gd`：三页 `PAGE_NAMES = ["选角色", "配道具", "选地图与难度"]`。`_build_kit_page()`：预设行、棋盘 `_board_host`、地上 `_stash_box`（一个 `GroundLayer`）、右侧 `_warehouse_box`（标题「仓库　%d 页，%d 件」+ 一句提示 + `WarehousePages`）。`_build_map_page()`：左 300「模式」列（`available_chapters()`，条目带「（难度 %d）」）、中 380 章节标题 + 说明 + 「地图规模」列（首项「默认（章节配置）」）+ 「难度」列 + 种子 `SpinBox` 与「随机」、右 340 摘要。`depart()` 把 `run_seed`、`scale_id`、`difficulty()` 一起交给 `flow.begin(...)`。
- 章节：三张序章都 `skip_setup: true`，且 `hidden_by_unlock` = 自己的 `grants_unlock`（打通即隐藏）；`free_mode`（显示名「自由模式」，`requires_unlock: prologue3_done`，`map_skin: imperial_camp`）带三档 `scales`：小型 4~5 环 36 步 / 中型 6~8 环 60 步 / 大型（占位）9~12 环 90 步。`GameFlow.new_run_target()`：教程没全通就直接开下一张教程、不走开局屏；全通后只剩自由模式。所以正常流程里第三页列表本来只有一项，但代码层面没有「教程永不进列表」的规定，B1 要把它写死。
- 难度：`DifficultyDef { id, display_name, description, level, requires_unlock, mechanics, effects, search_floors }`。数据只有 `normal`（level 0，「没有额外机制」）和 `ascension_1`（「进阶 1（占位）」，level 1，`requires_unlock: ascension_1`，侵蚀 + 猎手）。`available_difficulties()` 按 `requires_unlock` 过滤。`MetaState` 没有「上一局难度」字段，但有通用的 `flags: Dictionary`。
- 地上：`ItemStash.spots` 存归一化落点，文档明写「落点只是记个样子：不占格、不碰撞」；`next_free_spot()` 自动找空位时已经避开别人，重叠只来自玩家松手的位置和落地滑动。`GroundLayer` 有落地动画常量（`LAND_G`、`LAND_BOUNCE`、`LAND_IMPACT_*`）、`reserve()/reserved_rects()` 把面板当障碍把东西推开（`PUSH_GAP 6`）。节点地上和开局页地上是同一个 `GroundLayer`。
- 地图：`MapSource.resolve(run_seed, scale_id)` 按种子确定性生成；`RingLayoutBase.RING_STEP = 110`，`draw_backdrop()` 每环画一圈弧线；`MapView._draw()` 先把 `skin` 底图按 `MapSkin.cover_region` 铺满屏幕（不随缩放动），再 `draw_set_transform(pan, 0, zoom)` 画环、边、节点；`open_at()` → `start_zoom()` / `frame_spawns()` 定开局视角；`ZOOM_MIN 0.3`、`ZOOM_MAX 2.5`。`map_screen._adopt()` 设 `skin`、`graph`、`open_at`。
- 换屏：`GameDirector._switch_screen()` 后 `_fade_in(_base, BASE_FADE 0.2)`，受 `settings.ui_fades` 控制。
- 项目里目前没有任何着色器（`.gdshader` 为零）。

## 2 第二页「配道具」

### 2.1 文案删减（A2）

| 位置 | 现在 | 改为 |
| --- | --- | --- |
| 棋盘下读数 | 容量 / 背包 / 「已带 …」「带上 …」 / 负重 / 带入预算 | 只留两行：「负重　12 / 40　轻装」「带入预算　85 / 600」 |
| 仓库标题 | 「仓库　%d 页，%d 件」 | 「仓库　%d 页」 |
| 仓库提示句 | 「往左边的行囊里拖，放得进的就是带的；带进去的从仓库拿走，撤离了回来，死了就没了」 | 删除 |
| 第三页摘要 | 角色 / 带上 / 负重 / 模式 / 难度 | 角色 / 负重 / 地图（含规模）/ 难度 |

`bags_text()`、`caps_text()` 若无别处引用一并删；`carry_text()`、`encumbrance_text()` 保留。棋盘标题行保留「行囊　角色名」与「7 × 6 格」。

### 2.2 地上物件不重叠、相遇弹开（A3）

**规则**：地上（棋盘外、同一个 `GroundLayer` 内）的物件任何时刻投影不相交。两件相交时按半弹性碰撞分开；分开后的终点写回 `ItemStash.spots`，核心层状态仍是「落点」，规则层不变（不占格、不参与任何玩法）。

**模型**（放在 `GroundLayer`，纯画面层，不进 `core/`）：
- 每件一个轴对齐包围盒（现在的 `item_rect(uid)`），质量 `m = 格数 × 密度`（密度沿用 `LAND_SINK_DENSITY` 那套：背包轻、金属重）。
- 触发时机：落地结束（`_fall` 收尾）、玩家松手、`reserve()` 推开、以及 `_scan()` 发现读档后有重叠时。
- 解算：对相交的两件，沿重叠较小的轴分离；相对速度按恢复系数 **e = 0.5** 反弹（半弹性），速度按质量反比分配；被推到的件再和它的邻居做同样处理，迭代至多 8 轮或无重叠；每轮之后速度乘衰减 0.85，速度低于 20 px/s 视为静止。整体观感：一次有力的分开，之后很快贴住，不会在地上来回蹦。
- 墙与地面（作者 2026-10-17 09:26 补充）：`GroundLayer` 的边界、`reserved_rects()` 与落地的「地面」都是无限质量的障碍，但**吸收高额弹力**：撞墙 / 触地的恢复系数 **e_wall = 0.15**（物件之间仍是 0.5），且反弹速度封顶 `LAND_VMAX` 的一半，再快也只弹这么高。
- 后续弹起快速衰减：每次反弹后速度再乘 0.5（物件之间）或 0.3（墙 / 地面），第二跳不会超过第一跳的四分之一高度；连续两次反弹间隔小于 0.05 s 或速度低于 20 px/s 直接判静止贴住。落地动画现有的 `LAND_BOUNCE 6` / `LAND_BOUNCE_SEC 0.18` 就是这一下「第一跳」，不另加第二跳的专用参数。
- 动画：分离在 `_process` 里以速度推进（和现有落地动画同一条管线），`LAND_BOUNCE_SEC` 量级结束；结束时 `stash.set_spot()` 一次写回，`stash_changed` 不重复触发重排。
- 放不下（地面被填满）时退回 `next_free_spot()` 的网格扫描结果，不做无限推挤。

**影响面**：同一个类，所以节点地上、结算地上也跟着不重叠，这是好事，不单独开关。128 / 134 文档里「允许重叠，后放的在上」改为「不重叠，相遇弹开（180）」；`ItemStash` 注释里「不碰撞」改为「核心层不碰撞，画面层保证不重叠」。

### 2.3 版面（样稿第 1 页）

左 行囊板 440 宽（标题行 + 棋盘 + 两行读数），中间空出给地上物件，右 仓库框 660 宽（页签 52 + 10 × 8 格），间距同 179 的 36。地上物件不另画面板，直接落在仓库背景画上（有 `reserved_rects()` 挡着面板）。

## 3 第三页「选地图与难度」

### 3.1 删（B1、B4）

- 删章节标题 `_chapter_title`、说明 `_desc`、「模式」列 `_choice_column`、「地图规模」列里的「默认（章节配置）」项、种子 `SpinBox` 与「随机」按钮。
- 序章永不进列表：第三页取 `available_chapters()` 后再去掉 `hidden_by_unlock != &""` 的章（即 `tutorial_chapters()`）。教程未通时 `new_run_target()` 已经不走开局屏，这里只是把规则写死，避免调试存档等边角情况下序章出现。
- 种子：进第三页时 `run_seed = randi()`，玩家看不到；现有调试抽屉已显示「种子 %d」，再加一个「下局种子」输入即可（只在调试抽屉里）。

### 3.2 左列：地图与规模（B2）

- 一级条目 = 非教程章节，按 `order` 排，显示 `display_name`。`free_mode.json` 的 `display_name` 改为「魔法废墟」（id 不变，不涉及存档对账）。
- 选中的条目下方展开二级列表 = 该章 `map_source.scale_options()`，每项「小型　4~5 环　36 步」（名字去掉括号里的环数，环数和步数作右侧小字）；「大型（占位）」改名「大型」。默认选第一档；没有 `scales` 的章不展开。
- 记住上次：`meta.flags["last_map"]`、`["last_scale"]`、`["last_difficulty"]` 三个键，`depart()` 时写，进第三页时读（找不到就回默认）。用现成的 `flags` 字典，不改存档格式，不动版本链。
- 将来第二张图加进来就是多一条一级条目；灰的「（将来的第二张图）」只在样稿里，实装不画。

### 3.3 中央：晕染展开的预览区（B5）

新建 `ui/map/map_preview.gd`（`MapPreview extends Control`），铺满第三页中栏（左列与右栏之间）。它不是 `MapView`，只负责三层：

1. **纸底**：整页背景是第三页的背景画 `setup/bg_map`（空白桌面 / 纸，色值取在四张底图平均色附近，建议 #d8d2c1 ± ，`tone: light`）。
2. **晕染区**：选中地图后，从中栏中心向外展开一片区域，区域里显示该章 `map_skin` 的底图（按 `MapSkin.cover_region` 以整页为准铺，和局内 `MapView` 铺法一致，所以入局时纸不会跳）。
3. **圈**：区域里画虚线圈，圈数 = 这一档规模下**真实生成的图**的环数：选中规模时调一次 `chapter.map_source.resolve(run_seed, scale_id)`，缓存结果；圈间距 = 晕染半径 ÷ 环数。入局 `flow.begin` 用同一个种子再生成一遍，确定性生成保证两张图一样（见 4.4）。

晕染半径按规模：小型 0.55、中型 0.75、大型 0.95（× 中栏较短边的一半）。于是小型是一团、圈少而疏；大型几乎铺满、圈多而密。这就是「不同规模不同视觉、符合直觉」的来源，美术在此之上定线型（见 §5）。

**晕染的实现（推荐 A）**：一个全屏 `ColorRect`（纸色）挂 `ShaderMaterial`，着色器 `ink_reveal.gdshader`：

```
uniform vec2 center;      // 屏幕归一化坐标
uniform float radius;     // 0 = 全纸，1 = 全露
uniform float softness;   // 边缘羽化宽度，建议 0.08
uniform sampler2D noise;  // FastNoiseLite 的 NoiseTexture2D，引擎内生成，不要美术
uniform float noise_amp;  // 建议 0.12
alpha = 1 - smoothstep(radius - softness, radius + softness, dist + (noise - 0.5) * noise_amp)
```

底图和圈画在它下面，纸色盖在上面、中间挖洞。半径从 0 到目标值 Tween 0.6 s（ease out），切换地图时半径先回 0.3 再长到新值（0.25 s + 0.5 s），噪声坐标随时间缓慢漂移 0.02/s 让边缘像墨在晕。成本：一个全屏片元，几行算术，任何机器都忽略不计；这会是项目第一个着色器，Godot 4.7 原生支持，无额外依赖。

**备选 B（零着色器）**：美术给一张「纸色带洞」的大图（2048²，中央软边透明洞），`draw_texture_rect` 按半径缩放盖在底图上，图外四周补纸色矩形。能做，但洞外缩放时边缘羽化宽度跟着变、超大半径时四条补边容易露缝，只在作者明确不要着色器时用。

### 3.4 右栏：摘要 + 当前难度（B3）

右栏 340 宽：上「出发摘要」（角色 / 负重 / 地图 · 规模 / 难度），下「当前难度」块：

- 标题「当前难度」15 号；数字一行，`UiTheme.make_display` 72 号，居中；下方「−」「＋」两个 56 × 44 按钮；再下是红字说明栏（`UiPalette.HP` 色，和样稿里的红一致，美术可换成朱砂 #8E2A22）。
- **难度阶梯**：`DifficultyDef.level` 已有，按 level 排序就是阶梯，0 = `normal`。「＋」到不了尚未解锁的一级（`requires_unlock` 不满足就灰掉并停在当前最大值），「−」到 0。
- **红字内容**：`DifficultyDef` 加字段 `challenge: String`（这一级**新增**的挑战，一句话，玩家口吻，无阿拉伯数字除惯例外）。显示 1..N 级的 `challenge` 各一行、累积列出；0 级说明栏为空（不写「没有额外机制」，留白即可）。`description` 保留给图鉴 / 调试。
- 机制是否累积：**数据上不累积**，每一级的 def 自己列齐该级生效的全部 `mechanics` / `effects`（现状如此，作者改数值时一目了然）；**文案上累积显示**。这样不改 `RunState.start` 和任何结算代码。
- 默认值 = `meta.flags["last_difficulty"]`，钳到已解锁最大值；首局 0。
- 数字用阿拉伯数字（作者原话「数字」，单字大号最清楚）；若作者更愿意和回放倍速、仓库页签一致用罗马数字，换一个格式函数即可（待定 3）。

## 4 入局过渡：从第三页拉近到局内地图（B6）

### 4.1 目标画面

出发瞬间屏上是：纸底 + 中央一团底图 + 若干虚线圈，没有节点。约一秒半后是局内地图屏：底图铺满、圈上长出节点和边、装饰层（石头 / 河流 / 树木）浮现、HUD 条最后出现。中间不黑屏、不交叉淡入，纸从头到尾是同一张。

### 4.2 推荐做法：同一张画布接力（在 `MapView` 里做，不加第二个视口）

`setup_screen.depart()` 在 `payload` 里多带一包 `reveal`：

```
reveal = { center: Vector2(屏幕像素), radius: float(像素), ring_gap: float(每环像素), levels: int }
```

`map_screen.open(payload)` 读到它就走过渡，否则照旧。`MapView` 加三个只在过渡中用的属性：`reveal_radius`（像素，-1 = 不蒙纸）、`node_front`（float，环序号，小于它的环的节点与边才画、画到几分就按差值定 alpha）、`deco_alpha`（0..1）。`GameDirector` 见 payload 带 `reveal` 就跳过 `_fade_in`（否则淡入和晕染叠在一起）。

时间线（总长约 1.4 s，全部是对 `MapView` 属性的 Tween，没有物理、没有额外节点）：

| 时间 | 动作 | 说明 |
| --- | --- | --- |
| 0 | 对齐起点 | `zoom0 = ring_gap / RING_STEP`，`pan0` 使画布中心落在 `center`；这样 `MapView` 第一帧画出的圈和第三页上的圈完全重合。`zoom0` 可能低于 `ZOOM_MIN`（大型 12 环时约 0.29），过渡期间不钳，`ZOOM_MIN` 只约束玩家操作 |
| 0 – 0.5 s | `reveal_radius` → 覆盖全屏 | 同一个着色器盖在 `MapView` 上（`MapScreen` 里的全屏 `ColorRect`），纸边缘化开 |
| 0.2 – 1.0 s | `zoom`、`pan` → 目标 | 目标值先按现有 `open_at()` 算好（调用后立刻读回 `zoom`/`pan`，再把 `zoom`/`pan` 设回起点开始 Tween），ease in-out |
| 0.5 – 1.2 s | `node_front` 0 → levels + 1 | 节点和边从出生点所在环开始、一环一环浮现（排序键 = \|环号 − 出生环\|），alpha 随差值 0..1 |
| 0.6 – 1.3 s | `deco_alpha` 0 → 1 | 装饰层 `<skin>_deco.png`（透明底、与底图同尺寸、同 `cover_region`）在圈下方、底图上方叠出 |
| 1.2 s | HUD 条、日志淡入 | 用现有 `OVERLAY_FADE` |
| 1.4 s | 结束 | 清 `reveal_radius = -1`、`node_front = INF`、`deco_alpha = 1`，再放规则卡 / 教练（`rules_card_pending`、`_maybe_coach` 从这里起） |

任意点击 / 按键直接跳到结束状态（`tween.kill()` 后设终值）。`settings.ui_fades` 关着就不做过渡，一帧到位。读档回到地图屏、从战斗 / 节点返回不带 `reveal`，不受影响。

### 4.3 为什么不用别的

- **双视口交叉淡入**（第三页和地图屏各渲染到 `SubViewport` 再混合）：多一倍绘制与一张全屏纹理，而且只能「淡」，做不出圈变清晰、节点长出来的几何连续感。
- **`Camera2D` 推近**：`MapView` 自带 `zoom`/`pan`，再叠相机就是两套变换互相打架。
- **第三页做成地图屏的一个模式**（上次讨论过）：把开局选择状态塞进地图屏，`depart()`/`flow.begin` 的边界会糊掉；现在的方案保留「两个屏、一张纸、一包 `reveal`」，耦合只有一个字典。

### 4.4 预生成与性能

- 第三页每次选规模 `resolve()` 一次（切换时才算，不在每帧）；`flow.begin` 内 `RunState.start` 用同一个种子再生成一遍。生成器按种子确定性，两次结果相同，零接线。执行时量一下 `resolve()` 耗时：大型 12 环若超过 50 ms，再给 `flow.begin` 加可选的 `pregen: MapGraph` 参数复用，否则不加。
- 过渡期内的绘制和平时地图屏一样多，只多一张装饰纹理和一次全屏片元；节点 alpha 是现有 `_draw_node` 里乘一个系数。没有新的每帧分配。
- 装饰层不是前置条件：美术没交 `_deco.png` 之前 `MapSkin.deco(id)` 返回 null，`deco_alpha` 那一行自动跳过，其余过渡照常。

## 5 交给美术设计的清单

第二页（A1）
1. 行囊板：皮革质感的面板底（1 张九宫格或整块 440 × 700 级别），承载棋盘与两行读数；`tone: dark`（皮革深，读数用浅字）或 `light` 由美术定，需在 json 写明。
2. 仓库框：木质边框（九宫格），内含页签 52 宽与 10 × 8 格；页签为挂牌。
3. 第二页背景 `setup/bg_kit`：仓库内景，1920 × 1200，覆盖裁切；中下部留空给地上物件，不要抢眼的细节。

第三页（B5、B6）
4. 第三页背景 `setup/bg_map`：空白桌面上铺一张空白地图纸，纸面大、无纹样，色值 #d8d2c1 附近（和四张底图平均色同一族），`tone: light`。
5. 晕染边缘：推荐方案 A 不需要美术出图（噪声由引擎生成）；若选方案 B，需一张 2048² 纸色带软洞的图。
6. 圈的线型：虚线墨圈，小型粗而疏、大型细而密（程序给间距，美术给线宽 / 虚线段长的两档参数即可）。
7. 每张地图底图拆两层：`<skin>.png` 保留为纯纸面（去掉石头、河流、树木），新增 `<skin>_deco.png` 透明底同尺寸只含装饰物。先做自由模式用的那张（见待定 1），其余三张随后。
8. 难度红字颜色：样稿用现有 `UiPalette.HP`，美术可指定朱砂 #8E2A22 一类的墨红。
9. 179 的补充：大厅背景画只在第一页用；第二、三页各自用上面的 3、4。

## 6 改动清单（给执行）

- `ui/game/setup_screen.gd`：§2.1 文案；§3.1 删项；§3.2 地图 / 规模两级列表；§3.4 难度块；`depart()` 写 `flags` 与带 `reveal`；进第三页 `run_seed = randi()`。
- `ui/inventory/ground_layer.gd`：§2.2 碰撞解算；`docs/reports/128`、`134`、`core/inventory/item_stash.gd` 注释改口。
- 新 `ui/map/map_preview.gd`、新 `assets/shaders/ink_reveal.gdshader`（或放 `ui/map/`）；`ui/map/map_skin.gd` 加 `deco(id)`；`ui/map/map_view.gd` 加 `reveal_radius` / `node_front` / `deco_alpha` 与绘制分支；`ui/game/map_screen.gd` 的 `open()` 读 `reveal` 跑时间线；`ui/game/game_director.gd` 带 `reveal` 时跳过淡入。
- `core/run/difficulty_def.gd` 加 `challenge`；`data/authoring/difficulties/*.json` 补 `challenge`（`ascension_1` 的 display_name 改「进阶一」，去「（占位）」）；`data/authoring/chapters/free_mode.json` 的 `display_name` 改「魔法废墟」、大型去「（占位）」。
- 调试抽屉加「下局种子」。
- 测试：第三页列表不含 `hidden_by_unlock` 章；难度加减钳位与 `flags` 读写；地上两件重叠落地后不相交；`reveal` 起点 `zoom0` 与 `ring_gap` 一致（纯算术，可测）。改显示名不动 id，快照测试不需要 `IdAliases`。

分批：**批一** §2.1 + §3（预览区先用方案 A 着色器，无美术也能跑，纸色用平色）；**批二** §2.2 碰撞；**批三** §4 过渡 + `MapSkin.deco`（装饰层到了即生效）。

## 7 待定（默认按推荐）

1. 「魔法废墟」用哪张底图：现在 `free_mode.map_skin = imperial_camp`。**推荐改 `ruins`**，名实相符，`imperial_camp` 留给将来第二张图。
2. 地上碰撞是否也用于节点地上与结算地上：**推荐用**（同一个类，不重叠对哪里都是改进）。
3. 难度数字：**推荐阿拉伯数字**；备选罗马数字与倍速 / 页签一致。
4. 晕染实现：**推荐方案 A（着色器）**；方案 B 零着色器但边缘质量和大半径补边都差。
5. 过渡时长：**推荐 1.4 s 总长**，可点击跳过；作者试玩后若嫌慢，整体乘 0.7。

## 落地记录

### 批一（v3.19，2026-10-17）：文案删减 + 第三页结构 + 晕染预览

- **第二页**：仓库标题「仓库　N 页」，「往左边的包里拖……」与地上那句长说明删掉；棋盘标题「行囊　名字　7 × 6 格」，操作说明那行一并去掉；棋盘下读数只两行（`encumbrance_text()`、`carry_text()`：「带入预算　420 / 600」，超了接「超出 150 → 倒计时 −3（36 → 33）」，不再写「已带」）。预估 DPS、带了哪几件、预设几件都不在读数里了。§2.3 的版面（皮革行囊板、木质仓库框、地上不另画面板）等美术图到了再接。
- **第三页**：左 `_map_list`（`map_chapters()` = `available_chapters()` 去掉 `hidden_by_unlock` 的教程章）——选中的图下面缩进一列规模，按钮写「小型」，右边小字 `scale_note()`「4~5 环　36 步」（`MapSource.scale_options()` 多给 `rings`）；没有「默认（章节配置）」，默认第一档（`choose_scale(&"")` 仍可回章节默认配置，界面不列，测试按默认配置找种子时用）。中 `MapPreview`（`ui/map/map_preview.gd` + `ui/map/ink_reveal.gdshader`，方案 A，项目第一个着色器）：底图按整个窗口铺满裁边、虚线圈数 = `ring_levels()`（按种子真生成一次、按「章 | 规模 | 种子」缓存，只在第三页算），半径 0.55 / 0.75 / 0.95，线宽随环数变细；首次 0.6 s 化开、换图先收到 0.3 再 0.5 s 长回，`ui_fades` 关着一步到位。右：出发摘要（角色 / 负重 / 地图 · 规模 / 难度）+「当前难度」：数字 72 号（**和方案不同**：用正文字体，标题字体的「1」是一笔刷痕认不出），「−」「＋」56 × 44，在 `available_difficulties()` 里走、到头变灰；红字 `challenge_text()` 列 1..当前级的 `DifficultyDef.challenge`。
- **种子**：第三页没有种子框；进第三页 `_reroll_seed()`，`GameFlow.next_run_seed`（地图屏调试台「下局种子」，-1 = 现取）指定了就用它，出发后还原。
- **记住上次**：出发写局外旗标 `last_map`（order + 1）、`last_scale`（规模下标 + 1）、`last_difficulty`（档位）——**和方案不同**：旗标读档时只认整数，所以不存 id；进开局屏 `_restore_last()` 读回，找不到回默认。
- **数据**：`free_mode` 显示名「魔法废墟」（英文 Magic Ruins，id 不变）、底图改 `ruins`（等于默认值，json 里那行去掉）、三档规模名「小型 / 中型 / 大型」；`ascension_1` 显示名「进阶一」，加 `challenge`。
- **测试**：新 `tests/ui/test_setup_180.gd`；按章节默认配置找种子的几处测试出发前 `choose_scale(&"")`；161 / 096 / 开局屏 / 倒计时 / 序章三 / 底图 / 难度的断言按新文案改。截图 `/mnt/project-files/screenshots/180/`。

### 批二（v3.20，2026-10-17）：地上道具不重叠、相遇弹开

- **解算**放在 `GroundLayer`（纯画面层）：`wake_bumps()` 在落地结束、`_scan()`（读档 / 程序摆放）、`settle()`（面板推开）、换尺寸之后检查，有相交就把地上不在落的每件变成一个物体（包围盒 = `item_rect`，质量 = `ItemWeight.of`，至少 0.5），`advance_bumps(delta)` 以 1/120 s 小步推进（`_process` 里和落地动画一起跑），测试用 `settle_bumps()` 一口气算完、`overlapping_pairs()` 看相交。
- **一对物件**：沿重叠较小的轴分开；迎面来的按 e = 0.5 反弹（按质量反比分）、之后速度 ×0.5；还相交就把分开的相对速度补到「重叠 ÷ 0.1 s」（封顶 900 px/s），外加每小步直接推开重叠的 5 %。重的挪得少。
- **墙与地面**（作者 09:26）：屏边、地面（`size.y × (1 − SPOT_MARGIN)`，起手已经更低的按它自己的底）、登记的面板都推不动；撞上 e = 0.15、反弹速度封顶 `LAND_VMAX × 屏高 × 0.5`、撞完 ×0.3；两次反弹隔不到 0.05 s 直接贴住。起手就压着的面板不当墙（那是 `settle` 的事，免得一推推出屏）。
- **衰减**：每 1/60 s ×0.85，低于 20 px/s 算静止；都静了且不再相交就收尾，一次 `set_spot` 写回。实测两件 2 格的横向压 90 像素，约 0.2 s 分开、0.4 s 内贴住。
- **兜底**：1 s 还相交的（地上挤满了）退回 `ItemStash.next_free_spot()`；扫也扫不出空处时记下这一批，地上的东西没变就不再反复弹。
- **没做**：没有重力（地上的东西被推高了就停在那儿，不往下掉）；落地途中的不参与碰撞，落稳才算。
- **测试**：新 `tests/inventory/test_ground_bump_180.gd`（横向分开、重的挪得少、很快贴住、写回；撞墙限速、不出屏；掉在别人身上落稳后弹开；二十件压一堆最后两两不相交；读档的重叠也弹开）。

### 批三（v3.21，2026-10-17）：入局拉近转场 + 装饰层接口

- **接力**：出发时 `SetupScreen.reveal_payload()` = {center（预览圆心，全局像素）, radius（此刻化开半径）, ring_gap, levels}，写进 `GameFlow.map_reveal`；`begin` 交给地图屏 payload 的 `reveal` 并清掉（**和方案不同**：方案写 `depart()` 直接塞 payload，但 payload 是 `begin` 里 `_go` 发的，所以经 flow 转一手）。`GameDirector` 见 `reveal` 不叠 `_fade_in`。
- **时间线**（`MapScreen.apply_reveal(t)`，一条 1.4 s 的 `tween_method`）：0–0.5 s 纸化开；0.2–1.0 s 镜头从 `zoom0 = ring_gap / RING_STEP`、画布中心在预览圆心拉到平时进图的视角（缩放按倍数插值、smoothstep；**终点每帧现算** `reveal_target()`，因为读数层排版后平时的视角会变）；0.5–1.2 s `node_front` 0 → 环数 + 1；0.6–1.3 s `deco_alpha`；1.2–1.35 s 读数层与底下两行出来；结束 `finish_reveal()` 才放规则卡 / 教程。任意点击、按键直接到头。
- **纸**（**和方案不同**：`reveal_radius` 不在 `MapView` 上）：`MapScreen` 在地图视图上面盖一块全屏的「纸」—— 第三页的背景画（`setup/bg_map`，有就铺）或底色，挂同一个 `ink_reveal.gdshader`，新增 `invert`：圆里透明、圆外显出。这样着色器只画一块矩形，不受 `MapView` 内部 `draw_set_transform` 的影响。
- **节点长出来**：离出生环 k 环的点长到 clamp(node_front − k, 0, 1)，**按比例从圆心放大**（不是改 alpha：节点十几种颜色，放大更省也更像「长出来」）；边、路口、危险圈按两端较小的那个系数透明；传送点虚线长全再画；猎手标记、侵蚀圈转场里不画；挑出生点的遮罩在最后一环长全之后盖上来（新开一局一定是挑出生点阶段）。
- **装饰层**：`MapSkin.deco(id)` 读 `<id>_deco.png`（同目录、同铺法），`MapView` 画在底图上、圈下面，透明度 `deco_alpha`。美术交图即生效，不用改代码。
- **不转场**：设置里「换屏淡入」关着、跑测试（`GameDirector.fades_allowed`）、不是同心环布局、不经第三页（读档、从节点 / 战斗回来）。
- **没做**：`flow.begin` 的 `pregen` 复用没加（第三页按种子只算一次，`begin` 再算一次，出发时只多一次生成）。
- **测试**：`test_setup_180.gd` 加入局转场（起点圈重合、纸从预览半径起、半程、点一下到头、规则卡在后、淡入关着不转场）与装饰层读取。截图 `/mnt/project-files/screenshots/180/b3_*.png`。
