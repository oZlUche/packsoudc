# 201 落地：道具图接进棋盘 —— 贴图按格子对位、旋转同一套变换、分批到图分批接

作者（2026-10-19 13:50）：「目前美术设计出来的素材可以拿来实装了」「记得让道具贴图和格子位置对应」。

本篇是落地方案：美术设计正在分批画 127 件道具的图（已交三批 56 件，第四批材料在画），把它们接进棋盘、拖拽残影、地面、图鉴，并把「贴图 ↔ 格子」的对应写成代码里的一条规则和一条测试，后面每批图到了只需拷文件，不改代码。187（格线默认不画）和 198 第二阶段（地面按贴图轮廓碰撞）在这里一起翻过去。

## 1 现状

### 1.1 美术交付

路径 `/mnt/project-files/art/items/drafts1/`：`gen.py` / `batch2.py` / `batch3.py` 生成 SVG（一格按 80 单位画），再渲染成 **`out/<id>.png`（60 px / 格，游戏 1:1）** 和 `out/@2x/<id>.png`（160 px / 格）。`items.json` 是从仓库 `data/authoring/items/*.json` 抄出来的 127 件 id / 形状 / 稀有度表。

我核对了 56 张 60 px 图（2026-10-19 13:55）：

| 检查 | 结果 |
|---|---|
| 文件名 = 道具 `id` | 56 / 56 都在 `data/authoring/items/` 里有定义 |
| 画布 = 形状 rot 0 包围盒 × 60 | 56 / 56 一致（1×1 → 60×60，2×4 → 120×240……） |
| 形状里没占的格（L、T、缺角）全透明 | 15 件异形全部为 0（弯刀有一个像素 alpha = 1，可忽略） |
| 画的方向 | rot 0，即 `ItemShape.cells_rotated(0)` 的样子（剑竖着、弓竖着） |

也就是说美术那边已经按「贴图和格子对应」在画：**画布就是格子的包围盒，每格 60 px，格外不落墨**。代码这边要做的是把这条规则接住，并在旋转、缩放时不弄丢它。

### 1.2 代码

- `ui/inventory/item_painter.gd`：`draw_item()` 画稀有度色块 + 外轮廓描边，`draw_label()` 在包围盒里写名字。六处调用：`inventory_view.gd:272/298`（包体、道具）、`drag_layer.gd:1024/1052`（残影、残影里包的内容物）、`ground_layer.gd:994`（地面）、`codex_tile.gd:75/99`（图鉴）、`loot_view.gd:256`（没亮的战利品剪影）。
- `ItemPainter.art_available()` 恒 false（187 预留）；`GameSettings.grid_on(art)` 的默认跟它走；`ItemSilhouette._art_image()` 返回 null（198 第二阶段预留，`from_image(img, rot, canvas)` 已经写好）。
- 旋转：`ItemShape._rotate_cw` 顺时针 `(x, y) → (-y, x)`，再平移到 min = (0, 0)。rot 0 的包围盒是紧的（min 就是 (0,0)），所以每转一步的平移量恰好是 `(H − 1, 0)`（H = 转前的高）。
- 图片加载：`EventImage.load_texture(path)`（导出包里走 `.import`，测试里兜底 `Image.load_from_file`）；`UiTheme.art_cached()` 只认 `assets/ui/`，道具图另放一处，缓存自己管（[[art-cached-in-draw]]：`_draw` 里每帧取的贴图必须缓存，否则画成白块）。
- 格子边长：棋盘、地面、残影都是 60（`InventoryView.CELL`）；图鉴 `codex_tile` 最大 40；**仓库** `warehouse_pages.cell_for()` 夹在 40～80（`CELL_MAX = 80`），窄仓库会把格子放大到 80 —— 60 px 的图在那里要放大 1.33 倍，会软。

## 2 对应规则（作者的要求，写进代码和测试）

### 2.1 资产

- `assets/items/<id>.png`：**画布 = `def.shape.size_rotated(0) × 60` 像素**，左上角对应 `cells_rotated(0)` 里 (0, 0) 那格；形状没占的格 alpha 必须是 0（留 8/255 的容差给抗锯齿）。
- `assets/items/manifest.json`：`{"cell": 60, "items": ["antidote_kit", …]}`，由脚本从目录生成（§3.1）。它就是 187 说的「图包在不在」的判断，也给测试一个要核对的清单。
- 不要求每件都有图：没在清单里的照旧画色块 + 名字。一批到一批接。

### 2.2 旋转：一张图，四个朝向，和格子同一套变换

`cells_rotated(k)` 是把 rot 0 的格子顺时针转 k 次、每次平移到 min = (0,0)。对紧包围盒 W×H 的画布做同样的事 —— 整张图绕左上角顺时针转 90°、再平移让画布回到左上角 —— 格 (x, y) 落到 (H−1−y, x)，和 `_rotate_cw` + 平移 `(H−1, 0)` 一样。所以**贴图只画 rot 0 一张，四个朝向用变换，每格的那块图永远跟着那一格**：

| rot | 旋转角 | 画布左上角相对 anchor 的偏移（格） |
|---|---|---|
| 0 | 0 | (0, 0) |
| 1 | 90° 顺时针 | (H, 0) |
| 2 | 180° | (W, H) |
| 3 | 270° | (0, W) |

W、H 取 `size_rotated(0)`。实现：`draw_set_transform_matrix(base * Transform2D(k × PI/2, anchor + off × cell))`，`draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(W, H) × cell), false, modulate)`，画完把变换设回 `base`。`base` 是调用方当前的变换（地面层落地动画已经在用 `draw_set_transform` 绕重心转缩，必须相乘而不是覆盖）。

### 2.3 缩放

画进 `Rect2(anchor, Vector2(W, H) × cell_px)`：cell_px ≠ 60 时整张等比缩，线性过滤。缩小没问题（图鉴 ≤ 40）；放大会软，仓库最大 80（§1.2）。所以 `@2x`（160 px / 格）也进仓库，放 `assets/items/@2x/<id>.png`，`art_of(def, cell_px)` 在 **cell_px > 60 时取 @2x**，否则取 60 的（160 → 60 是 2.7 倍缩小，没有 mipmap 会闪，不能只带 @2x）。@2x 的尺寸规则同 §2.1，乘 160。

### 2.4 测试守着

`tests/content/test_item_art_201.gd`：

1. `manifest.json` 里的每个 id 有 `ItemDef`，`assets/items/` 里的每张 png 在 manifest 里（两边对得上，少一张多一张都红）。
2. 每张图的尺寸 = `size_rotated(0) × 60`；`@2x/` 里同名的 = × 160，且 manifest 里的每个 id 两套都有。
3. 异形件：形状没占的格里 alpha ≤ 8（读 `Image`，逐格扫）。
4. 旋转对位：取一件 L 形（有图的，比如 `antler` / `longbow`），把 `Image` 用 `rotate_90(CLOCKWISE)` 转 k 次，「有墨的格」集合 == `cells_rotated(k)`。这一条把 §2.2 的推导钉在代码上，`ItemShape` 以后改旋转约定它就会红。
5. `ItemPainter.art_available()` == manifest 在不在；`test_board_grid_187.gd:11` 现有的 `not art_available()` 断言改成这一条。

**改形状 = 重画图**：173 的内容快照已经把形状变化拦成红测试（`IdAliases.RESHAPED`）；给 `ContentSnapshot.problems()` 的提示加一句「这件有图，改形状要通知美术重画」。

## 3 改动

### 3.1 资产与脚本

- `tools/sync_item_art.sh <源目录>`：把 `<源目录>/*.png` 拷到 `assets/items/`、`<源目录>/@2x/*.png` 拷到 `assets/items/@2x/`，重写 `manifest.json`（id 按字母序；只收两套都有的 id，缺一套的报出来不收）。云端源目录是 `/mnt/project-files/art/items/drafts1/out`；作者本机就给它美术导出的目录。拷完 `godot --headless --import` 一次生成 `.import`，和别的美术一样提交 `.import` 文件。
- 这一次先接 56 件；以后每批：美术把 png 放进 `out/`、知会执行 → 执行跑脚本 → 测试 → PR。不改代码。

### 3.2 `ItemPainter`

- `art_available()` := `FileAccess.file_exists("res://assets/items/manifest.json")`（json 走 `include_filter`，导出包里也在）。
- `art_of(def, cell_px := 60.0) -> Texture2D`：按 id 取 `assets/items/<id>.png`，cell_px > 60 取 `@2x/<id>.png`；`EventImage.load_texture`，**静态字典缓存**（键 = 路径；没有的也记一个 null，别每帧探文件）。
- `draw_art(canvas, def, rot, anchor, cell, modulate := Color.WHITE, base := Transform2D.IDENTITY) -> bool`：按 §2.2 画；没图返回 false，调用方回落到 `draw_item` + `draw_label`。
- `draw_item` / `draw_label` 保留（没图的、包体没图的、剪影都还用）。

### 3.3 六处调用

| 处 | 有图时 | 没图时 |
|---|---|---|
| `inventory_view.gd` 道具 | `draw_art`；不写名字（170：名字在悬浮窗）；休眠的信仰道具 modulate 到 55 % 灰并仍写小字「休眠」 | 照旧 |
| `inventory_view.gd` 包体 | 包有图就 `draw_art`（包是道具，187 §2），上面照常压内容物；没图画包灰 | 照旧 |
| `drag_layer.gd` 残影 | `draw_art`，modulate alpha 0.85；残影里包的内容物同理 0.9 | 照旧 |
| `ground_layer.gd` | `draw_art`，`base` = 落地动画的变换；不写名字；198 的轮廓描边自动改走贴图（§3.4） | 照旧 |
| `codex_tile.gd` | 点亮：`draw_art`；没点亮：`draw_art` modulate `Color(0.22, 0.24, 0.28)`（暗影，还看得出形）；异体叠影照旧用色块（错位 5 px 的叠影用图会花） | 照旧 |
| `loot_view.gd` 剪影 | **不用图**：087 的剪影就是不让看出是什么，贴图轮廓会泄露；照旧色块 + 噪点 + 「?」（待定 2） | 照旧 |

高亮框、角标、元素标记、格位标记都画在道具之上，不动。

### 3.4 顺带翻过去的两件

- **187**：`art_available()` 变真 → 没动过「棋盘格线」开关的玩家默认不画格子（三态 GRID_AUTO 本来就为此而设）。
- **198 第二阶段**：`ItemSilhouette._art_image(def)` := `ItemPainter.art_of(def)` 的 `get_image()`（CompressedTexture2D 和 ImageTexture 都行，`from_image` 自己会 decompress）。有图的道具在地上按透明通道的轮廓碰撞、描边；没图的照旧按格子。随后请作者在地上看几件（弯刀、弓）决定 198 待定 2（自由角度躺倒）要不要做。

## 4 待定

1. **现在就翻还是等 127 件齐** —— 推荐 **现在翻**（作者说的是「可以拿来实装了」）：56 件有图、71 件色块，过渡期混着；每批到了只拷文件。
2. **没亮的战利品剪影用不用贴图轮廓** —— 推荐 **不用**（087：剪影不能泄露身份）。
3. **图鉴没点亮的画法** —— 推荐暗影 modulate（§3.3）；备选照旧色块。
4. **`@2x` 进不进仓库** —— 推荐 **进**：仓库格子最大 80，没有 @2x 那里会软；两套都走同一条尺寸测试。备选：仓库 `CELL_MAX` 降到 60，只带一套图。

## 5 给美术的两条（随本篇知会）

- 包（`bag_small` / `bag_leather` / `bag_long`）在棋盘上是底层，内容物压在上面画：包的图里面要平、淡，别有抢眼的内部细节。
- 形状以 `data/authoring/items/*.json` 为准；改了形状的道具会在 173 快照里红出来，那件要重画。

## 6 不做

- 不改 `ItemShape`、不改存档、不改 `.import` 参数（默认无损、不生成 mipmap）。
- 不给道具图加描边 / 稀有度色框：稀有度已经画进图里（美术 §稀有度规则）。

## 7 落地（2026-10-19，架构方案执行）

待定 1–4 按推荐：现在就翻、剪影不用图、图鉴暗影、@2x 进仓库。

- **素材**：首批是 **86 件**，比方案写的 56 件多，因为美术第四批（材料 30 件）在派单前后已经放进 `out/`，一起接了。`tools/sync_item_art.sh <源目录>` 用纯 bash 写（作者机器上不一定有 python），做三件事：拷 png；按字母序重写 `manifest.json`，只收两套都有的 id，缺一套的会报出来；用 `$GODOT` 跑一次 `--import`，没设就找 PATH 里的 godot，再不行用 `run_game.bat` 那个路径。`.import` 都是默认参数（无损、不生成 mipmap）。
- **`ItemPainter`**：
  - `art_available()` 看清单在不在；`art_ids()` 读清单，结果缓存。
  - `art_of(def, cell_px)` 只认清单里的 id，`cell_px > 60` 时取 `@2x`，按路径静态缓存，没有的也缓存成 null。
  - `draw_art(canvas, def, rot, anchor, cell, modulate, base)` 按 `base * art_transform(...)` 画，画完把变换设回 `base`。
  - `art_transform()` 单独拆出来给测试用：它就是 §2.2 那张偏移表。
  - 另有 `clear_art_cache()`。
- **调用处**（§3.3 六处之外，多接了两处）：
  - `harvest_row.gd`（收成那一排）有图也画图。
  - `drag_layer` 里「跨包被留下的」那几件（straddlers）有图时：图按 45 % 透明画，橙色描边照旧（用 `draw_item` 画一个透明底）。
  - 包体有图就画图、不写名字。目前三只包都还没画，所以仍是包灰。
  - 休眠的信仰道具：图乘 `Color(0.55, 0.55, 0.55)`，上面写小字「休眠」，用的是 `COLOR_TEXT`。
  - 地面：落地动画的变换在 `base = Transform2D(angle, (k, k), 0, pivot)` 里重算一份，透明度放进 modulate。198 沿轮廓描边照旧，颜色是稀有度色或高亮色。
- **198 第二阶段**：`ItemSilhouette._art_image(def)` 现在返回 `ItemPainter.art_of(def).get_image()`（60 px 那一套）。有图的道具在地上按透明通道的轮廓碰撞、描边。
- **173**：`ContentSnapshot.problems()` 在形状变了的提示后面加一句：有图（看 png 在不在）就提示「改形状要通知美术重画」。
- **测试**：
  - `tests/content/test_item_art_201.gd` 共 15 条，覆盖 §2.4 的 1–5，另加 `art_transform` 的逐格对位：鹿角、长弓、弯刀、匕首、甲片，四个朝向，每格中心都落到 `ItemShape` 顺时针规则算出的那一格。
  - 「有墨的格 = 占格」只钉了鹿角、长弓：有些件的某一格可能没画到墨，全量钉会误报。
  - `test_board_grid_187.gd` 里假设「没图」的断言改成跟着 `art_available()` 走：有图时默认不画格、开关先切到「开」。
- **截图**：`/mnt/project-files/screenshots/201/`
  - `board_grid.png` / `board_nogrid.png`：鹿角四个朝向、长弓竖横、弯刀转 90°、木头转 90°，图都落在各自的格子里。
  - `ground.png`：地上按图描边。

