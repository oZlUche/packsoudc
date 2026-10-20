# 213 开局第三页的预览支持格阵（沙漏）：底图对准、层线、入口印记、入局转场

作者 2026-10-20 06:14（看完 207–212 的过夜汇总）：「开局预览在地图列表里切换时会跟着变，就这么做」。即 210 §8.9 留下的那一条：沙漏这一张在开局第三页也要画出来、在纸上挑出生点、带转场进图，而不是只铺一张底图、进图后再挑。

## 1 现状（代码读出来的）

| 处 | 现在 | 对沙漏的后果 |
|---|---|---|
| `SetupScreen.ring_levels()` | `RingLayoutBase.level_count`，别的布局 0 | `show_map(skin, 0, "")`：`levels 0`、`ring_gap 0` |
| `MapPreview._draw` | `levels 0` 时底图按整个窗口 cover 铺（192 以前的老铺法），不画圈 | 底图位置和局内第一帧对不上；没有形状 |
| `MapPreview.set_entries` | 只在 `lay is RingLayoutBase` 时填入口 | 不画入口印记，`needs_spawn()` 假，「出发」直接亮 |
| `SetupScreen.reveal_payload` | `levels <= 0 or ring_gap() <= 0` → `{}` | 不转场，直接切屏 |
| `MapScreen.reveal_allowed` | 只认 `RingLayoutBase` | 即便有载荷也不走 |
| `MapView._grow_map / reveal_origin_ring / level_count` | 只认 `RingLayoutBase` | 转场里点不会一层层长 |
| 地图屏挑出生点 | `RunState.Phase.PICK_SPAWN` + `frame_spawns`（096） | 现在沙漏就走这条老路 |

沙漏图本身的几何都有：`LatticeMapLayout`（078）给 `canvas_size` / `positions` / `draw_backdrop`，`layout_meta` 带 `rows / cols / cells / straight_rows / orientation`，`ROW_STEP == RingLayoutBase.RING_STEP == 110`（「两种形态一把尺」）。入口在第 0 层（横置沙漏 = 最左一列），`entry_count` 个；格阵图没有 `routes`。

## 2 方案

原则：`MapPreview` 不再以「环」为中心记状态，而是记**这张图的布局 + 画布 + 预览缩放 `zoom0`**（预览像素 ÷ 画布像素）。同心环的所有数值走原式（圈距 = `zoom0 × RING_STEP`），180 / 182 / 192 的几何与测试不动。

### 2.1 `MapPreview` 通用化

- 新入口 `show_graph(skin_id, graph: MapGraph, scale_id, animate)`：`_layout = MapLayout.for_graph(graph)`，`_graph = graph`，`canvas = Rect2(Vector2.ZERO, _layout.canvas_size(graph))`。
  - `RingLayoutBase`：`levels = level_count(graph)`，`target_frac` 按规模（现状 `RADIUS_BY_SCALE`），`zoom0 = target_radius() / levels / RING_STEP`（就是现在的 `ring_gap / RING_STEP`）。
  - `LatticeMapLayout`：`levels = rows_of(graph)`；没有规模档，`target_frac = RADIUS_BY_SCALE[large]`（0.95）；`zoom0 = FIT × 2 × target_radius() / max(canvas.x, canvas.y)`，`FIT = 0.9`：画布长边占化开直径九成，横置沙漏左右两端（入口与终点）都落在墨化那片里。
  - 其他布局（`grid_script` / `line` / 没登记）：照现状只铺底图、不画线不画入口（`levels 0`）。
  - 老 `show_map(skin, levels, scale)` 留着做同心环的薄封装（测试在用），内部走同一套状态。
- `ring_gap()` 的语义改成「预览里一层多少像素」= `zoom0 × RING_STEP`。同心环数值不变；沙漏因为 `ROW_STEP == RING_STEP`，`reveal_payload` 的 `ring_gap` 和地图屏 `zoom0 = ring_gap / RING_STEP` 对两种形态都算对。
- `paper_on_screen()`：`MapSkin.paper_rect(skin, canvas)` 按 `zoom0` 放到预览中心（原式里的 `canvas_side(levels)` 换成通用 `canvas`）。192 的「第三页和局内第一帧同一张纸、同一大小」对沙漏同样成立 —— `clockwork.json` 的 `safe_area` 已按横置画布对准（210）。
- **层线代替虚线圈**：`LatticeMapLayout` 每一层画一条虚线，从 `cells[r]` 的最小列到最大列、两端各放 `0.4 × COL_STEP`（和 `draw_backdrop` 的衬底同一根线），线型用 `_ring_style` 大型那套（`ring_style(&"large")`）。横置沙漏十条竖虚线由长到短再到长，纸上一眼是蝴蝶结；塔是横线。`straight_rows` 照旧不画线（衬底的规则）。
- 入口印记：`set_entries(graph)` 对 `LatticeMapLayout` 也填，`rel = (pos[id] − canvas.center) / RING_STEP`，单位和同心环一致，`entry_base() = center + rel × ring_gap()` 不改。`route = -1`（格阵没有路线），提示窗（182）没有路线那一行，`_route_text` 已经处理空。`mark_alpha` 的墨边判定、`zoom_to` 微放大、`entry_at` 点击都沿用。
- 画布中心对预览中心：横置沙漏是宽图，化开那片还是圆，上下留白是纸的底图，没问题（和 192 一样纸本来就大于画布）。

### 2.2 `SetupScreen`

- `_sync_preview`：`_preview.show_graph(c.map_skin, preview_graph(c, scale_id), scale_id, animate)`；`ring_levels()` 改成读 `_preview.levels` 的薄封装或删掉（测试 180 用到，留）。`set_entries` 的 `auto_spawn` 条件不变。
- `needs_spawn()` 对沙漏自然成立：纸上有入口没挑 → 「出发」灰；挑了才能走。`_restore_last` / 换图 `_forget_spawn` 照旧。
- `reveal_payload()` 不改：`levels > 0`、`ring_gap > 0` 对沙漏成立就带载荷。

### 2.3 地图屏 / `MapView` 的转场

- `MapScreen.reveal_allowed`：`MapLayout.for_graph(graph)` 是 `RingLayoutBase` **或** `LatticeMapLayout`。`zoom0 = ring_gap / RING_STEP`、`pan0 = center − canvas.center × zoom0` 是通用式。
- `MapLayout` 加一个默认方法 `level_of(graph) -> Dictionary`（id → 层，默认空）：`RingLayoutBase` 返回 `levels_of`，`LatticeMapLayout` 返回每个点的 `row`。`MapView.level_count()` 改成按 `level_of` 的最大值 + 1（同心环结果同前），`_grow_map` / `reveal_origin_ring` 用 `level_of` 而不是 `is RingLayoutBase`。横置沙漏于是从出生那一列起一列一列长出来，`_draw_spawn_mask` 的「最后一层长全再盖遮罩」也对。
- `frame_spawns` 不动。

### 2.4 美术

不需要新图：`clockwork` 底图已有且 `safe_area` 对准画布；层线用 `setup/rings.json` 大型那套；入口印记还是 `setup/spawn_flag_*`。

## 3 改动面

| 文件 | 改什么 |
|---|---|
| `ui/map/map_preview.gd` | `show_graph`、`_layout / _graph / canvas / zoom0`、`ring_gap` 改式、`paper_on_screen` 通用、`_draw` 画层线、`set_entries` 支持格阵；`show_map` 变薄封装 |
| `ui/map/map_layout.gd` | 默认 `level_of(graph) -> Dictionary`（空） |
| `ui/map/ring_layout_base.gd` | `level_of = levels_of` |
| `ui/map/lattice_map_layout.gd` | `level_of` 按 `row`；一个静态 `row_span(graph, r) -> [lo, hi]` 给预览和衬底共用 |
| `ui/game/setup_screen.gd` | `_sync_preview` 改调 `show_graph`；`ring_levels` 薄封装 |
| `ui/game/map_screen.gd` | `reveal_allowed` 认两种布局 |
| `ui/map/map_view.gd` | `level_count / _grow_map / reveal_origin_ring` 走 `level_of` |
| 测试 | 新 `tests/ui/test_setup_preview_213.gd`；180 / 182 / 192 不动必须绿 |

不碰：核心层、生成器、存档、章节数据。

## 4 待定（按推荐派执行）

| # | 问题 | 推荐 |
|---|---|---|
| 4.1 | 沙漏预览化开半径 | **大型档 0.95**（没有规模档，宽图要地方） |
| 4.2 | 纸上的形状 | **每层一条虚线**（和虚线圈同一种语言；局内衬底的淡点太碎、全部节点违背 182 的「别的节点一概不画」） |
| 4.3 | 转场长出顺序 | **按层，从出生那一列起**（同 180 的「一环环长出来」） |
| 4.4 | `grid_script` / `line` 形态 | **照旧只铺底图**（没有章在用） |
| 4.5 | `FIT` | **0.9** |

## 5 测试

新 `tests/ui/test_setup_preview_213.gd`（挂进 180 那组的驱动）：
1. 第三页切到「机关沙漏」：`pv.levels == rows`（10）；`pv.entry_ids() == g.entry_ids`（`entry_count` 个，都在第 0 层）；每个入口 `mark_alpha > 0.5`（在墨化那片里）；`needs_spawn()` 真、`can_depart()` 非空。
2. `pv.paper_on_screen()` 与「局内第一帧 `zoom0 = ring_gap / RING_STEP` 下的纸」吻合（照 192 的 `frame_preview_matches_reveal` 写一遍）。
3. 挑一个入口 → `reveal_payload()` 非空（`ring_gap > 0`、`spawn_at` 有）→ 出发 → `map.revealing()` 真、`run.map.entry_ids == [pick]`、`run.phase == ON_MAP`。
4. 转场中点 `apply_reveal(t)`：出生那一列的点先长（`_grow_map` 里层差 0 的先到 1）。
5. 回归：切回「魔法废墟」后 `levels / ring_gap / paper_on_screen / entry_base` 与 180 / 182 / 192 的断言一致（老测试直接跑）。

## 6 不做

- 沙漏的规模档（210 待定 4.2 维持）。
- 第三页画全部节点或局内那种淡点衬底。
- 地图屏挑出生点的老路留着（`auto_spawn` 假且第三页没铺开的情况，比如调试台直接开局）。
