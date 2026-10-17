# 182 方案：出生点在开局第三页挑定 —— 纸上三个入口、点一个才亮「出发」、另两个入口变搜索点、点节点微放大加居中提示

> 架构设计线程，2026-10-17。181 讨论稿的定稿：作者 15:26 选乙并给了细则。实现归「架构方案执行」，画面归「美术设计」。

## 0 作者原话（15:26）

「也可以，就是当玩家每次选择地图时种子已经在后台选好，我们直接让他们看到三个不同位置的出生点，玩家必须点击一次其中一个，然后【出发】才会亮起，接着直接视作从这个出生点开局。另外，当玩家选定开局后，将其他两个出生节点直接从地图上替换成普通的搜索节点。玩家在第三页点击节点时，可以以该节点和周围区域为偏移中心稍微放大，然后在屏幕正中央弹出提示窗，说明节点的类型」

## 1 现状（与改动有关的）

- 第三页（180 批一）：`_reroll_seed()` 进页时取种子；`ring_levels()` 已按「章 | 规模 | 种子」把真图 `map_source.resolve()` 生成一次并缓存环数；`MapPreview` 只画晕染底图与虚线圈，不画节点；`depart()` 把 `reveal_payload()`（圆心、半径、圈距、环数）经 `flow.map_reveal` 交给地图屏做拉近转场。
- 出生点：环形生成器在最外环按 `entry_min_gap` 挑出 `effective_entry_count()` 个入口（默认 3，两两隔开），节点类型 `&"spawn"`（`MapNodeTypes.STRUCTURAL` 之一），每个入口一条路线 `graph.routes[i]`（风格、终点 核心 / 撤离点、风险、收益、`zone_ids`）。
- 进图后 `RunState.phase = PICK_SPAWN`：地图屏 `frame_spawns` 拉远装下所有入口、灰罩、右侧路线卡；`pick_spawn(id)` 后转 ON_MAP。序章用 `ChapterDef.auto_spawn` 直接 `pick_spawn(entry_ids[0])`。

## 2 第三页挑出生点

1. **真图提前算好。** 选图 / 选规模时种子已定（现状），`ring_levels()` 的那次 `resolve()` 结果整个缓存下来（不只环数）：`_graph_cache[key] = MapGraph`，预览和出发都用它（见 §4 第 1 条）。
2. **预览画三个入口。** `MapPreview` 增加 `entries: Array[Dictionary]`（id、画布坐标 → 预览坐标、路线序号），用 `RingLayoutBase.positions(graph, rect)` 算位置：`rect` 取「圈距 = `ring_gap()`、圆心 = `center()`」的画布矩形，所以入口正好落在对应的虚线圈上。入口印记**屏幕空间定长**（不随圈距缩小），大图上也看得清；三个入口因生成器的 `entry_min_gap` 本来就分在圆周不同方位。其余节点一概不画（它们在入局转场里一环环长出，180 批三），纸上除了圈只有这三处印记，这就是引导。
3. **必须点一个。** 进第三页 `spawn_id = -1`，「出发」灰着（`can_depart()` 加一条「还没挑出生点」，按钮 `disabled`）；点中一个入口 → `spawn_id`，印记换选中态，「出发」亮。换图、换规模会换种子，`spawn_id` 清零、「出发」重新灰；换难度不动种子、不清选择。读上一局记忆（`last_map / last_scale`）后同样要重新点。
4. **点一个入口做两件事：**
   - **微放大。** 预览以「该节点及周围区域」为偏移中心放大：缩放 ×1.35，视中心从预览中心向该入口移 40 % 距离（Tween 0.25 s，EASE_OUT）；底图、圈、印记一起动（`MapPreview` 加 `view_zoom` / `view_center`，画圈与印记时套用；晕染遮罩不动）。再点同一个入口不再放大；点另一个入口平移过去；点空白处回到不放大（选择保留）。
   - **居中提示窗。** 屏幕正中弹一张纸签 `NodeHintCard`（420 宽，`PANEL_PARCHMENT` 浅底）：第一行类型名 + 字记（`MapNodeStyle` 的「生」与「出生」），第二行这一类节点的一句说明，第三行这个入口的路线（「风格 → 核心（打 BOSS）/ 撤离点（可以不打）　风险 x　收益 y」，现在路线卡的内容），底部一行小字「点别处可以换一个」。说明句来源：本章 `ChapterDef.tooltip_texts` 有就用（084 的节点浮窗文案），没有用新表 `MapNodeTypes.HINTS`（每类一句，玩家口吻）。点窗外任意处或再点同一入口关窗；换图 / 换规模关窗；出发时窗与放大状态一并作为转场起点（见 §4）。
5. **右栏不变**（便笺 + 难度块）。摘要里不加出生点行（作者 10:09 已把摘要删到只剩角色名）。

## 3 把提示窗做成通用件

`NodeHintCard` 不只给第三页：它就是「说明某一类节点」的卡，将来地图屏首次遇到新类型节点也能用它（084 节点浮窗的居中版）。本方案只接第三页。

## 4 出发与入局

1. **直接从这个出生点开局。** `flow.begin(...)` 加参数 `spawn_id: int = -1`：`RunState.start` 之后、交给地图屏之前，`spawn_id >= 0` 就 `pick_spawn(spawn_id)`，和 `auto_spawn` 同一条路；新的一局再也不进 `PICK_SPAWN`。`begin` 里的图仍按同一种子再生成一次（确定性，180 批三已量过只多一次生成）；若执行愿意，`begin` 加可选 `pregen: MapGraph` 直接用第三页缓存的那张，`spawn_id` 必须在 `pregen.entry_ids` 里。
2. **另两个入口变普通搜索点。** `MapGraph.demote_entries(keep_id)`：`entry_ids = [keep_id]`；其余入口节点 `type = &"search"`，`layout` 里的 ring / slot 不动，边不动；`routes` 只留 `entry_id == keep_id` 的那条（放到下标 0，路线色跟着），别的路线的 `zone_ids` 不再有效 → 危险区按现有逻辑重算或直接删掉（`danger` 字段保留，入口本来就 0）。搜索点的内容现在是到访时由 `NodeEvents._search_event()` 按节点深度现做的，所以降级后不需要补内容；执行核对一遍 `search_floors`（127）按深度取时对最外环成立。`pick_spawn()` 内部做这件事（`auto_spawn` 的序章也一并受益：其余入口不再是死的「生」点）。
3. **转场起点 = 第三页此刻的样子。** `reveal_payload()` 多带 `view_zoom`、`view_center`、`spawn_id`、入口印记的屏幕坐标；地图屏转场从这个（可能已微放大、已偏移的）视角起，拉近终点改为**所选出生点**（`focus(spawn_id)` + `start_zoom()`，不再 `frame_spawns`）；`node_front` 仍按离出生环几环排序（现状），最先长出来的就是出生点周围。纸化开、装饰层、HUD 的时序不变。入口印记在转场前 0.2 s 淡出，让位给真正的节点图标。
4. **地图屏的 PICK_SPAWN 路径。** 新局不再进入；旧存档停在 PICK_SPAWN 的仍走老路（灰罩、路线卡）一版，`SAVE_VERSION` 不动；下一次大版本再删（待定 2）。调试抽屉里「重新挑出生点」若有也随之去掉。

## 5 交给美术设计

1. 入口印记：**小旗**（作者 15:36 定），常态 / 悬停 / 选中三态，屏幕尺寸约 40 px，三个入口同图；选中态可加一圈朱砂。
2. 提示窗 `NodeHintCard` 的纸签底（可复用羊皮纸条九宫格）与一枚小钉 / 蜡封。
3. 不需要新的转场素材。

## 6 改动清单（给执行）

- `ui/game/setup_screen.gd`：`_graph_cache`；`spawn_id` 与 `can_depart()`；入口点击 / 换图清零；`reveal_payload()` 扩字段；`depart()` 传 `spawn_id`；关窗时机。
- `ui/map/map_preview.gd`：`entries`、`view_zoom` / `view_center`、印记绘制与命中、`zoom_to(entry)` / `zoom_reset()`。
- 新 `ui/game/node_hint_card.gd`；`core/map/map_node_types.gd` 加 `HINTS`。
- `core/map/map_graph.gd` 加 `demote_entries()`；`core/run/run_state.gd` 的 `pick_spawn()` 调它；`core/run/game_flow.gd` 的 `begin()` 加 `spawn_id`（可选 `pregen`）。
- `ui/game/map_screen.gd`：转场起点读新字段、终点 `focus(spawn_id)`；PICK_SPAWN 路径只给旧档。
- 测试：第三页未挑时出发被拒、挑后可出发、换图清零；入口位置与真图一致；`demote_entries` 后 `entry_ids` 只剩一个、其余为 `search`、routes 只剩一条；`begin(spawn_id)` 后 `phase == ON_MAP` 且 `current_id == spawn_id`；提示窗开关；转场终点落在出生点。181 讨论稿归档为「已被 182 吸收」。

## 7 待定（默认按推荐）

1. 预览是否把其余节点淡淡画出来：**推荐不画**，只画三个入口（其余留给转场「长出来」，和 180 的叙事一致）。
2. 旧存档的 PICK_SPAWN 路径：**推荐保留一版再删**。
3. 微放大倍数与偏移：**推荐 ×1.35、偏移 40 %**；作者试玩后可调。
4. 换难度是否换种子：**推荐不换**（难度不改图，换了反而要重挑）。
5. `begin` 是否复用第三页缓存的图（`pregen`）：**推荐先不加**，与 180 批三一致；大图生成超过 50 ms 再加。
