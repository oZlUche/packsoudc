# 192 · 方案：地图底图钉在画布上，和路网一起缩放平移（191 甲）

> 191 讨论稿 → 作者 2026-10-18 18:05「实施」。待定 1–4 全按推荐：甲、画布外是桌面纹理、美术重出两倍图、拖动软限制。
> 范例图 `/mnt/project-files/architecture/191/compare.png`。

## 1. 一句话

`MapView` 现在先在屏幕坐标把底图 cover 铺满，再切到画布坐标画路网（`ui/map/map_view.gd:526-541`）。改成：底图也在画布坐标里画 —— 进图时按底图 json 里的 `safe_area`（美术留给路网的淡色椭圆）算一次「图 → 画布」的缩放与位置，之后底图、装饰层、路、点共用同一个 `draw_set_transform(pan, 0, zoom)`。画布外先铺一层桌面；纸有投影。

## 2. 数据（`assets/maps/<id>.json`）

```json
{"id": "ruins", "tone": "light", "size": [1920, 1200], "safe_area": [192, 168, 1536, 864], ...}
```

- `safe_area` 从一句话改成四个数 `[x, y, w, h]`（图像素，**按 `size` 的逻辑尺寸**）：淡色椭圆的外接矩形。美术的 gen.py 写的是「中间约 80% × 72% 的椭圆」→ 默认 `[0.1W, 0.14H, 0.8W, 0.72H]`；json 没写数字（还是那句话、或缺）就按这个默认算，不报错。
- `size` 保持逻辑尺寸 1920 × 1200。贴图换成 3840 × 2400 后代码不改：所有几何都按 `size` 算，画的时候整张贴到目标矩形（`player_pawn` 的 @2x 先例）。
- `stretch: "cover"` 字段作废（不删，不读）。

## 3. `MapSkin`（`ui/map/map_skin.gd`）新增

```
static func logical_size(id) -> Vector2          # json.size；没写用贴图尺寸
static func safe_rect(id) -> Rect2               # §2
static func paper_rect(id, canvas: Rect2) -> Rect2
    # s = max(canvas.w / safe.w, canvas.h / safe.h)
    # origin = canvas.center − safe.center × s
    # 返回 Rect2(origin, logical_size × s)   ← 底图在画布坐标里占的矩形
```

`cover_region` 留给别处（设置页等还在用），`MapView` / `MapPreview` 不再调它。

## 4. `MapView`

### 4.1 画（`_draw`）

```
1. 桌面：draw_texture_rect(UiTheme.art_cached("map/desk"), Rect2(0, 0, size), tile = true)   ← 屏幕坐标、平铺；没图 draw_rect(UiPalette.bg())
2. draw_set_transform(pan, 0, zoom)
3. 纸影：draw_rect(paper.grow(2) 右下偏 (8, 10)，Color(0, 0, 0, 0.35))      ← 画布坐标，随缩放
4. 底图：draw_texture_rect(_skin_tex, paper)                                  ← 整张贴进 paper_rect，不裁
5. 装饰层：draw_texture_rect(_deco_tex, paper, false, Color(1,1,1,deco_alpha))
6. 往下照旧（环线 / 边 / 点 / 棋子……本来就在这个变换里）
```

`_paper: Rect2` 在 `skin` 或 `graph` 变时算一次（`MapSkin.paper_rect(skin, canvas_rect())`），没有底图是空矩形：没底图时跳过 1 的桌面与 3–5（只画 `UiPalette.bg()`，现状）。`skin_is_light` / `_ink` 不动。

### 4.2 缩放范围

- `zoom_min()`：有底图 = `min(safe_rect().w / paper.w, safe_rect().h / paper.h)`（整张纸刚好装进 166 的安全区），没底图 = 0.3（`ZOOM_MIN` 常量留着当下限）。`ZOOM_MAX` 2.5 不动。
- `fit()`（F 键「看全图」）：有底图缩到 `zoom_min()`、纸居中；没底图照旧按画布。`center()` 不用改：`paper_rect` 的中心就是画布中心（§3 的构造）。
- `zoom_at` / `open_at` / `frame_spawns` / `GameSettings.normalize_zoom` 的下限都换成 `zoom_min()`（`normalize_zoom` 是静态的、不知道底图，保留 0.3，视图再夹一次）。
- `start_zoom()`、`focus()`、`focus_pan()`、`follow_current()` 全在画布坐标，不改。

### 4.3 拖动软限制（待定 4 甲）

`_clamp_pan()`：纸在屏幕上的矩形 `R = paper × zoom + pan`，安全区中心 `c`；要求 `R.left ≤ c.x ≤ R.right`、`R.top ≤ c.y ≤ R.bottom`（纸的任何一边不能越过安全区中心线）。在中键拖动、`zoom_at`、跟镜头 tween 结束、`frame_spawns` 之后各夹一次；`focus_pan` 不用夹（节点都在画布里、画布在纸里，把节点摆到正中时纸边不可能越过中心）。`frame_spawns` 里「别让团的边出屏」那段用的 `c = canvas_rect().size`，有底图时换成 `paper` 的尺寸（夹的是纸，不是画布）。

### 4.4 入局转场（180 §4）

不改：纸的「洞」是屏幕空间的遮罩，`pan0 = center − canvas_center × zoom0` 仍成立（预览的圈心 = 画布中心 = 纸的中心）。`deco_alpha` 的装饰层改用 §4.1 的 paper 矩形。

## 5. `MapPreview`（第三页，`ui/map/map_preview.gd:403`）

现在底图按整页 cover 铺，和局内不再一致（局内纸的大小由圈距决定）。改成和局内同一套：

```
zoom_p = ring_gap() / RingLayoutBase.RING_STEP            # 转场 t=0 的 zoom0，就是这个数
canvas = Rect2(0, 0, RingLayoutBase.canvas_side(levels))  # 新静态助手 = 2 × (levels × RING_STEP + MARGIN)
paper  = MapSkin.paper_rect(skin, canvas)
屏上 = to_view(center() + (paper.position − canvas.center) × zoom_p), paper.size × zoom_p × view_zoom
draw_texture_rect(_skin_tex, 屏上)
```

纸外面本来就是第三页的桌面纸 `setup/bg_map`，洞外又被墨化遮罩盖着，所以页面上看不出差别；差别在落地的一瞬间 —— 局内第一帧的纸和预览最后一帧的纸是同一张、同一大小。`view_shift` / 182 的微放大照旧经 `to_view`。

## 6. 美术（转「美术设计」）

1. 四张底图按 **3840 × 2400** 重出（gen.py 的 W、H 翻倍、线宽等比），文件名不变；json 里 `size` 仍 `[1920, 1200]`，并把 `safe_area` 写成四个数（每张自己量，默认 `[192, 168, 1536, 864]`）。`_deco.png` 若已有也同尺寸。
2. 桌面纹理 `assets/ui/map/desk.png`：512 × 512 可平铺、深色木桌（低对比，别抢纸），`desk.json` `{"tone": "dark"}`。
3. 纸边不另出：四张图已有「一圈纸边双线」；投影代码画。

图没到之前：底图还是 1920 的（放大会糊，可接受），桌面退回 `UiPalette.bg()`。

## 7. 改动清单（给执行）

- `ui/map/map_skin.gd`：`logical_size` / `safe_rect` / `paper_rect`；json 的 `safe_area` 数组。
- `ui/map/map_view.gd`：`_paper`、`_draw` 顺序（§4.1）、`zoom_min()`、`fit()`、`_clamp_pan()` 及四个调用点、`frame_spawns` 的夹边、装饰层矩形。
- `ui/map/ring_layout_base.gd`：`static func canvas_side(levels) -> float`，`canvas_size()` 改调它。
- `ui/map/map_preview.gd`：§5。
- `assets/maps/*.json`：`safe_area` 四个数（先按默认填）；`assets/ui/map/desk.*` 美术到了再加（含 `.import`）。
- `ui/game/map_screen.gd`：F 键照调 `fit()`，不改；`_remember_zoom` 不改。
- 测试 `tests/ui/test_map_backdrop_192.gd`（`test_map_skin` 里 `cover_region` 的三条留着）：
  1. `safe_rect`：json 四个数 → 原样；一句话 / 缺 → `[192, 168, 1536, 864]`。
  2. `paper_rect(ruins, 1000²)`：s = 1000 / 864 ≈ 1.157，纸 2222 × 1389、中心 (500, 500)。
  3. 有底图 `fit()` 后 `zoom == zoom_min()` 且纸的屏幕矩形在安全区内（容差 1 px）；没底图 `fit()` 行为同现在（`test_hud_150` / 166 的用例不红）。
  4. 滚轮围着 (x, y) 缩放：缩放前后 `to_canvas((x, y))` 相同（纸上那一点不动）。
  5. 中键往右拖 5000 px 后，纸左边 == 安全区中心 x（±1）；往下同理。
  6. `_paper` 随 `skin` / `graph` 更新；`skin = ""` 时为空矩形、`_draw` 不画桌面。
  7. 预览：`MapPreview` 在 `levels = 4`、`ring_gap = g` 时纸的屏幕矩形 == 把 `MapView` 放到 `zoom0 = g / 110`、`pan0` 时 `paper × zoom0 + pan0`（相对各自中心，容差 1 px）—— 转场不跳。
  8. 截图 1600 × 1000：看全图（纸 + 桌面）、进图、放大 2.0 各一张，对照 `architecture/191/compare.png` 下排。

## 8. 待定（默认按推荐）

1. **纸影** —— 推荐 **甲**：代码画一块偏 (8, 10)、35% 黑的矩形（随缩放）。乙：美术出带软边的投影九宫格。
2. **`safe_area` 默认值** —— 推荐 **甲**：按 gen.py 的 80% × 72%。乙：等美术量完再填。
3. **放大上限** —— 推荐 **甲**：2.5 不动，等两倍图。乙：两倍图到之前压到 1.5。
