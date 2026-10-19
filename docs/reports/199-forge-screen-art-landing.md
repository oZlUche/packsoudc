# 199 落地：铸炉屏换成铁炉近景（196 §5 的美术定稿接进代码）

> 2026-10-19，架构设计。作者在「UI替换美术」10:16 选乙（炉台版）、10:22「ok」定稿。美术交付在 `/mnt/project-files/art/ui/forge/`（`README.md`、`out/`、预览 `final_*.png`）。本篇只写接法，机制不变；派执行。

## 1. 现状

`ui/game/forge_screen.gd`（261 行）：`_centered_panel` 石板 + 标题条「铸炉」+ 一段说明 + 左列三个 4 × 4 槽（各带「【时机】」等文字标签、槽下三行小字 `_summaries`）+「出牌」1 × 1 + `_preview` / `_guess` / `_line` 三行 + 「铸」「返回」两个按钮 + 右侧 `_mount_bag` 背包面板。状态：`_forge_open()`（这个节点没铸过）决定按钮可用与「铸炉（已熄）」标题；三槽都满 `preview()` 非空时「铸」亮。测试 `tests/run/test_forge_175.gd`、`test_forge_194.gd` 直接调 `put_in / forge / take_token / to_map / preview_text / summary_text / guess_text`。

196 的营地屏已经有同一套「底图 cover + layout.json 坐标 + 切图原点」的接法（`rest_camp_screen.gd` 的 `layout()` / `_place()` / `CampPiece.layout_at`），本篇照抄。

## 2. 美术交付（搬进仓库）

| 来源 `art/ui/forge/out/` | 目的 `assets/ui/forge/` | 说明 |
| --- | --- | --- |
| `bg_lit.png`、`bg_cold.png` | 同名 + `bg_lit.json` / `bg_cold.json`（`{"tone": "dark"}`，[ui-tone-rule]） | 1920 × 1200 cover；没铸过 lit，铸过 cold |
| `handle_ready.png` / `handle_idle.png` / `handle_off.png` | 同名 | 风箱把手上的「铸」牌，200 × 128，原点 (100, 64)，摆在场景 (150, 250) |
| `sign_back.png` | 同名 | 「返回」路标，130 × 144，原点 (82, 130)，摆在场景 (92, 1192) |
| `layout.json` | 同名 | 坐标全在这里（场景像素，1920 × 1200）；`@2x/` 不搬 |

视口固定 1600 × 1000（172），cover 缩放恒为 0.8333：场景 72 px = 1 格（60），288 px 的坩埚口 = 4 × 4 槽，所以槽和格子像素对齐，不需要缩放 `InventoryView`。

## 3. 接法（`forge_screen.gd`）

- **底**：`_centered_panel` 换成 `_painted_screen("forge/bg_lit")`；`_refresh` 里 `not _forge_open()` 时 `_repaint("forge/bg_cold")`（回到 lit 不需要：熄了不会再亮）。
- **坐标换算**：`layout()` 读 `assets/ui/forge/layout.json`；`_place()` 同营地屏：`s = max(size / scene)`，`offset = (size - scene × s) / 2`，每个矩形 `Rect2(pos × s + offset, size × s)`；`resized` 连到 `_place()`。
- **标签**：【时机】【效果】【数值】【出牌】和标题「铸炉」都画在底图里 —— 删掉 `_label("【%s】")`、「出牌」、`_frame_title`；`_head` 不再是节点（`_head.text` 的两处状态改由底图 lit / cold 与把手三态表达；测试若断言 `_head.text`，改断言 `handle_state()`）。
- **三槽**：三个 `InventoryView` 直接 `add_child` 到画面内容区，位置 = `layout.slots[i]`（时机 / 效果 / 数值顺序与 `ForgeTable.SLOTS` 一致）；`show_adjacency = false` 不变。
- **出牌槽**：`layout.output`（72 × 72 → 一格）。
- **槽下三行小字**：`_summaries[i]`（`UiTheme.rich_block`）放到 `layout.captions[i]`（288 × 66 → 240 × 55），深底亮字（内容区 tone dark 自动取亮字）。
- **背包面板**：`_mount_bag` 的面板放到 `layout.bag`（672 × 480 → 560 × 400）左上对齐；9 × 6 格 + 一行说明正好装下。拖拽层、提示、`quick_target` 不变。
- **三行字**：`_preview`、`_guess`、`_line` 竖排放进 `layout.text`（672 × 120 → 560 × 100），字号 13 / 12 / 13 不变。
- **说明**：开头那段 `_wrapped(…, 12, DIM, 900)` 放进 `layout.slate`（560 × 250 → 467 × 208），宽随框、字号 12。
- **「铸」**：`_forge_btn` 改成 `TextureButton`（保留变量名，测试读 `_forge_btn.disabled`）：`texture_normal` 按状态换 —— `ready`（三槽满且 `_forge_open()`）、`idle`（没放满）、`off`（铸过了）；`disabled = state != ready`；位置 = `handle.pos − pieces.handle_*.origin`，再乘 s 加 offset；悬停 `modulate` 1.12，按下 1.0；新增 `handle_state() -> StringName` 给测试。
- **「返回」**：`TextureButton`，`sign_back`，位置同上法；`pressed → to_map`；`tooltip_text` 照旧；Esc 路径 `escape()` 不变。
- **铸完**：`forge()` 成功后 `_refresh` 自然走到 cold + off；出牌槽里的铸牌照旧可拖。
- 键盘 / 手柄焦点：把手与路标进焦点链（把手在前）。

## 4. 测试

- `test_forge_175.gd` / `test_forge_194.gd`：功能断言不动；`_head.text` 的断言改成 `handle_state()`（`&"idle"` → 放满 `&"ready"` → 铸后 `&"off"`）与底图名（`painted_art() == "forge/bg_cold"`，若没有这个读法就加一个）。
- 新增几条：`layout.json` 读得出且三槽矩形宽 = 4 × CELL（在 1600 × 1000 下）；三槽 / 出牌 / 背包面板的 `global_rect` 落在 layout 给的矩形内（误差 1 px）；把手三态贴图存在；熄后 `_repaint` 到 cold。
- 快照 / 资源：`assets/ui/forge/*.png` 加 `.import`（跟 `assets/ui/rest/` 一样），`bg_*.json` 走 [authoring-json-canonical]。

## 5. 其它

- `/mnt/project-files/reference/待做-界面.md` 的铸炉一条改成「已定稿（199），执行落地中」。
- `docs/architecture.md` 铸炉一节加一句：铸炉屏是整屏画（`assets/ui/forge/`），坐标来自 `layout.json`。

## 6. 落地（2026-10-19，架构方案执行）

已落地：素材（只收 1x，加 `bg_lit.json` / `bg_cold.json`，tone dark）进 `assets/ui/forge/`；`forge_screen.gd` 按 §3 换底换框，公开动作（`put_in / forge / take_back / take_token / to_map / preview_text / summary_text / guess_text`）不变；新读法 `handle_state()`（`&"idle" / &"ready" / &"off"`）、`backdrop_state()`（`&"lit" / &"cold"`）、`spot_rect(名)`、`slot_view(i)`。`test_forge_175` 的铸炉屏一条加了：没铸过 lit + idle、三槽满 ready、铸后 cold + off；时机槽按 layout 摆；三个 4 × 4 格子都在槽口里；背包不出屏；底图里画了的标签代码不再写。截图 `/mnt/project-files/screenshots/196/forge_idle.png`、`forge_ready.png`、`forge_done.png`（1600 × 1000）。

和 §3 不一样的地方：

1. **缩放不是 cover，是按宽铺满、竖直居中**（`s = 宽 / 1920`）。1600 × 1000 下和 cover 完全一样（0.8333）。但项目是 `aspect = expand`，窗口比 16 : 10 窄（4 : 3、全屏到方屏）时逻辑尺寸会变高，cover 就按高放大、左右裁掉 —— 左下路标和右边背包都贴着画边，一裁就出屏（测试窗口 1600 × 1600 下背包右沿到了 2064）。现在窄屏上下留暗边，宽屏裁上下的天和地。底图也跟着同一个变换画（自己的 `TextureRect`，没用 `_painted_screen`，它是 cover）。
2. **格子不缩放，在槽口里居中**：槽口 288 × s ≥ 240，`InventoryView` 照 60 像素一格放中间；1600 × 1000 下正好贴满。
3. **说明石板字号 15**（不是 12）：按美术预览的字大小，12 号在那块板上太小；板面从石板外框往里缩 (28, 36)（底图像素）。
4. **试算那一行空着时藏起来**，不占一行（铸完以后「铸好了」和「铸成」之间原来空一行）。
5. **槽下小字会越过石带**：效果槽那三行里「做什么：施加 2 层流血（前缀「嗜血的」）」在 240 宽里折成两行，一共四行，底下一行压到铁砧正面（也是深底，看得清）。小字登记成占地（`_reserve_ground`），地上的东西不会压着它。要严丝合缝得改字（缩短前缀那半句）或把石带画高，先不动。
6. 键盘焦点：把手先于路标加进树，焦点链就是这个顺序；没另加别的焦点逻辑。悬停提亮 1.12。
