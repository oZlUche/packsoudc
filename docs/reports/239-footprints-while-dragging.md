# 239 拿起道具时显出所有道具的占格（2026-10-22）

作者 13:40：「我认为需要加一个拿起道具时，显示棋盘内所有道具占据的格子，换句话说就是让道具的格子重新显示，同时也显示拿着的道具的格子」。作者明说要加，本篇直接派执行；待定按推荐。

## 〇 一句话

**拖拽一开始，每块棋盘上每件道具的占格逐格描出来（稀有度色的细框 + 淡淡一层色），手里那件在残影上也逐格描；放下或取消就全部消失。** 空格不动（格缝本来就常开）。

## 一、为什么现在看不出

- 201 之后道具画的是图，图**不必填满占格**（作者 10-19 定的：边角格只要一点点）；格缝画在道具下面（`InventoryView._draw` 先 `_draw_seams` 再画道具），所以一件 L 形或长条的东西，图外的那几格被盖住了也看不出是它的。
- 拿起一件要找地方放时，最需要知道的恰是「哪些格已经被占了、占到哪」。现在只有落点那一片染绿 / 黄 / 红（`set_preview`），别的道具的边界全靠猜。
- 手里那件：残影画图（`DragLayer._draw`），同样看不出它占几格、转到了哪。193 §4 只在棋盘外画它的增益 / 受益格位，不是占格。

## 二、方案（推荐甲）

| | 画法 | 评 |
|---|---|---|
| **甲 逐格描框（推荐）** | 每个占格画一个向内缩 3 px 的小方框：1.5 px 稀有度色线 + 同色 16 % 的淡填；包只描 `COLOR_BAG_EDGE` 灰框不填（内容物压在上面要看得见） | 一眼数得出几格，L 形的拐角也清楚；和「所有棋盘有格」的规矩同一语言 |
| 乙 只描外轮廓 | 用 `ItemPainter.draw_item` 的轮廓画法，不逐格 | 像道具剪影，看不出「格子」—— 作者要的是格 |
| 丙 压暗非占格 | 空格压一层暗，占格原样 | 反过来了：拿起时要看的是空格在哪 |

细节（甲）：
- **何时**：`DragLayer` 拿起（`_on_grab_requested` 与 `grab_free` 两条路）时 `get_tree().call_group(InventoryView.GROUP, "set_footprints", true)`；`_end_drag` 时 false。用组而不是 `_views` 名单：战前的敌人棋盘、商店货架这些没登记到拖拽层的视图也一起显。
- **画在哪一层**：`InventoryView._draw` 里道具（含包）都画完、邻接标记之前；这样框压在图上、标记和落点预览仍在最上。被顶的橙框（`COLOR_VICTIM`，2 px）照旧最后画，比稀有度框粗、看得出区别。
- **手里那件**：`DragLayer._draw` 画完残影的图之后，同一套逐格框（稀有度色）画在残影上，棋盘内外都画；落点预览的整片染色在视图层，残影在上面压着，不冲突。摆好的一袋（`_payload` 非空）：包描灰框，内容物各描自己的稀有度框。
- **休眠 / 锁住 / 次数点**：不变，框画在它们之上也不碍（都在格角）。
- **颜色**：`ItemPainter.rarity_color(def)`；浅底棋盘（储物间木板、账单石板旁的保险箱）同一套颜色够显。
- **不做**：地上（`GroundLayer`，不是棋盘）、没在拖的时候、悬停时。

## 三、改动范围

- `ui/inventory/inventory_view.gd`：`var footprints := false` + `set_footprints(on)`（变了才 `queue_redraw`）；`_draw` 加一段 `_draw_footprints()`；抽一个 `static func footprint_cells(inst) -> Array[Rect2]`（按 `item.cells()` + `cell_origin_px`）给视图和残影共用。`ContainerView` 不动（用组调用，不是虚方法）。
- `ui/inventory/drag_layer.gd`：两处拿起 → 组调用 true；`_end_drag` → false；`_draw` 残影后画手里那件的逐格框（含袋装内容物）。
- 测试 `tests/ui/test_footprints_239.gd`：拿起后组里每块 `InventoryView.footprints` 为真、放下 / 取消后为假；`footprint_cells` 对一件 L 形返回 3 个矩形、对包返回「只描不填」的标记。
- 不动数据、不动美术。

## 四、派工

执行一单，直接做。

## 五、落地（执行，2026-10-22，v4.20）

按甲做。`InventoryView`：`footprints` + `set_footprints(on)`（变了才重画）；静态 `footprint_cells(cells, anchor, px)`（向内缩 `FOOTPRINT_INSET` 3 px）、`footprint_hollow(def)`（`is_bag` 且不带信仰 = 包，只描灰框）、`draw_footprint(...)`（1.5 px 稀有度色线 + 16 % 同色淡填），视图与残影共用；`_draw_footprints()` 在道具画完之后、邻接标记之前：棋盘上当底层的包描灰框，其余各件按稀有度（自由容器里的包也只描灰框）。`DragLayer`：`_on_grab_requested` 与 `grab_free` 上手时、`_end_drag` 收尾时 `_show_footprints(on)` 按 `InventoryView.GROUP` 组调用（战前敌人棋盘这类没登记的视图一起显）；`_draw` 在残影图之后逐格描手里那件，摆好的一袋描灰框，袋里各件描自己的稀有度框。地上（`GroundLayer`）不画。

测试 `tests/ui/test_footprints_239.gd`：L 形三格三个框、按锚点与格宽、包只描不填；拿起 → 登记与没登记的棋盘都开、放下 / 取消 / 游离上手（`grab_free`）开关对。截图：`/mnt/project-files/art/ui/footprints239/pre_drag.png`（战前拿起一件：两块棋盘逐格描，残影上手里那件也描）。
