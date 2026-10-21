# 232 · 方案：局内界面改非矩形 · 第一轮（事件窗 = 摊开的书、背包窗 = 背包、腰带 = 弯皮带、图例 = 燕尾旗）

> 架构设计线程，2026-10-21。来由：作者 18:42「我最喜欢乙的点在于它是第一个非矩形界面，以后也要作出这方面的尝试」→ 美术设计 19:14 清点局内十二处、19:20 出草图总表 → 作者 19:23 原话：「**可以直接用的：1，2，6，10**。3 的商店要考虑时代背景，古代风格或者魔幻风格，战斗的我更倾向于类似沙盘推演那样的边框，头脑风暴一下」。
> 四样正式图 19:47 到：`/mnt/project-files/art/ui/nonrect/`（总说明 `README.md` 末尾「第一轮正式图」，每样一个目录：脚本 + `out/` 1x 与 `@2x/` + json 摆位 + `mocks/`）。本文只做方案，不实施。商店（3）与战斗三屏边框（4）作者要先挑方向，美术设计出了方向稿，挑定后另开报告。

## 〇 一句话

四处窗 / 件换外皮，内容区照旧按矩形排：事件窗整张「书」图垫底、标题挪进右页；背包窗四件皮料（包身九宫格 + 翻盖 + 提手徽 + 两只侧环）垫在画布底下，石板底换空；腰带按格数取整张弯皮带、圆心改读表；图例的平底换九宫格燕尾旗。字、图标、格子全由代码画，图里不带字。凸出件画在矩形外，窗居中和夹边时把凸出量算进去。

## 一、现状（v3.82 核过）

| 处 | 代码 | 现在的皮 |
|---|---|---|
| 事件窗（搜索点、军团的交代、所有事件、结果页） | `ui/game/event_screen.gd` `_frame()`：`_centered_panel(PANEL_SIZE 1320×760, 0)` → `OverlayFrame`（石板 `slab_edge` 九宫格 + 标题条）；行里左 `EventImage.area(…, 640)`、右 `MarginContainer` 28 + 列（章节名 / 滚动正文 560 / 选项） | 白灰石板方窗，标题在板顶刻线上 |
| 背包窗 | `ui/game/bag_window.gd`（`FloatingWindow`）：`UiTheme.panel(self, 0, PANEL_WINDOW)` 石板底；`_canvas` 画两条分隔线（标题行下横线 + x 660 竖线）；`spec()` 读 `assets/ui/stats_strip/layout.json` 的 `bag_window`；`window_size()` 随棋盘长；收起钮 `[918, 13]`；`FloatingWindow._clamp` 按 `size` 夹在宿主里 | 石板方窗 |
| 腰带槽 | `ui/widgets/belt_slots.gd`：一排 72 圆、间 12；`slot_center(i)` 直线；`_draw` 贴 `belt_slot.png` 圆底 + 绿圆（`GRANT` 0.28）+ 图标 56 + 数量圆标；宿主 `ui/hud/widgets/belt_widget.gd` 是 `HudWidget`（`PANEL_HUD` 凹槽 / 栏里 `PANEL_BARE`） | 一排直圆槽坐在 HUD 凹槽上 |
| 图例 | `ui/hud/widgets/legend_widget.gd`：`_legend_theme()` 里一块 `StyleBoxFlat`（深色半透明、圆角 4、内边距 10 / 6），白字，`tone dark` | 深色圆角方块 |

美术设计在草稿副本里试画过 2、6、10（`satchel/ingame_try.diff`、`belt/ingame_try.diff`，截图 `satchel/mocks/bag_satchel_ingame.png`、`mocks/map_belt_legend_ingame.png`）：摆位核过了，但 diff 直接读 `/mnt/project-files` 的图、没走资源目录，**不能照抄**，只当摆位的证据。

## 二、改法

### 2.1 事件窗 → 摊开的书（`nonrect/book/`）

- 图：`event_book.png` 一整张 1400 × 874，**不切九宫格**（面板 1320 × 760 是定值）。`event_book.json`：`panel_at [40, 34]`（图左上 = 面板左上 + (−40, −34)），`spine_x 680`，`image_rect [14, 44, 640, 672]`、`text_rect [704, 44, 560, 672]`（面板坐标），`title_h 52`，tone light。
- `OverlayFrame` 加第三种皮：`OverlayFrame.whole(texture, offset: Vector2, content_margin: Rect2)` —— 面板本身 `StyleBoxEmpty`，一个 `TextureRect`（`MOUSE_FILTER_IGNORE`）放在最底、位置 `offset`，大小 = 图原大；标题条隐藏（和铜面板一样 `title_bar.visible = false`，`set_title` 照旧能调）。`_centered_panel(size, margin, skin)` 的 `bronze: bool` 改成 `skin: StringName`（`&"slab"` / `&"bronze"` / `&"book"`），`_bronze_panel` 不变。
- 事件屏 `_frame()`：行改成**绝对摆位**（`Control` 画布，不再 `HBoxContainer`）：插图 `EventImage.area` 放 `image_rect`（640 × 672，图上已压版画双线，所以 `EventImage` 自己那圈边不画 —— 加参数 `framed := false`）；右页 `text_rect` 里一列：顶上 `title_h 52` 一行标题（`UiTheme.make_label` serif_bold 26 墨色居中，这就是 `_frame_title` 返回的标签 —— 书皮时 `OverlayFrame.set_title` 把字写到这里而不是标题条），花饰线在图里，正文从 `title_h + 22` 起，`ScrollContainer` 到底，选项列在最下（现在的顺序不变：章节名 → 正文 → 选项 → 藏起来的提示）。
- 书是浅底（tone light）：面板 `set_meta(&"tone", TONE_LIGHT)`，字取墨色版；`EventImage` 没图时的深底占位改成书页上一块淡墨框（浅底上不要黑块）。
- 居中：`_full_center` 照旧按 1320 × 760 居中（图比面板大，往四周出 40 / 34、底下红丝带再多 46），`center.offset_top = bar_height` 不变；1600 × 1000 下底边 = 34 + 120 + 760 + 80 = 994 < 1000，丝带不出屏；更矮的视口丝带被裁掉也无妨（只是装饰）。
- 结果页（`_open_result`）和「军团的交代」（218）走同一个 `_frame`，自动跟着换；结果页的「收获」行（`HarvestRow`）在右页选项上方，照旧。

### 2.2 背包窗 → 背包（`nonrect/satchel/`）

全按 `satchel.json`（坐标从 BagWindow 窗左上起，W、H = `window_size()`，窗随棋盘长时 W、H 跟着变）：

| 件 | 文件 | 怎么摆 |
|---|---|---|
| 包身 | `bag_body.png` 1044 × 670，九宫格 margin [72, 70, 72, 90]，STRETCH | 左上 (−30, −18)，大小 (W + 60, H + 50)；内衬浅帆布 = 窗 x 8..W−8、y 30..H−6 |
| 翻盖 | `bag_flap.png` 1064 × 110，只左右分段（margin 112 / 0 / 112 / 0） | 左上 (−40, −46)，宽 W + 80，高不变；盖住标题行（窗 y −34..46），**整块翻盖就是拖动把手** |
| 提手徽 | `bag_crest.png` 300 × 168 定大小 | 左上 (W/2 − 150, −100)；提手拱到窗顶上 90 |
| 侧环 | `bag_tab.png` 56 × 80 | 左 (−50, 92)；右同图水平翻转 (W − 6, 92) |

- 窗底 `PANEL_WINDOW` → `StyleBoxEmpty`；新加 `_back: Control`（`MOUSE_FILTER_IGNORE`）放在 `_canvas` **下面**一层装这四件（竖分隔线、棋盘、右栏都在 `_canvas` 里，画在皮上面）。叠放顺序：包身 → 侧环 → 翻盖 → 提手徽。
- `_draw_divider` 删横线（翻盖下沿就是分隔），竖线照旧。
- 收起钮：`layout.json` `minimize.topleft_rel_window` 改 `[914, −6]`（挪到翻盖上），随窗宽右移照旧。
- `FloatingWindow` 加 `outset: Rect2`（左 50、上 100、右 50、下 32，从 json `outset` 读）：`_clamp` 用 `position − outset.position` 和 `size + outset.size` 夹，提手和侧环不被屏幕边裁掉；拖动把手区域 = 翻盖矩形（`_grip` 的那块 `Control` 改成翻盖的大小位置）。
- 四件图进 `assets/ui/bag/`（1x；`@2x` 不拷，同 216 的规矩），`satchel.json` 进 `assets/ui/bag/layout.json`；`spec()` 多读一份。tone light 不变。
- 背包窗教程（218 补充一 `control_rect`）五个目标的矩形不变。

### 2.3 腰带 → 弯皮带挂皮袋（`nonrect/belt/`）

- 图：`belt_1.png` … `belt_6.png` 按格数取**整张**（1 格 154 × 151 … 6 格 594 × 181）；`belt.json` 的 `layouts[n]` 给图大小和每格圆心（`centers`，不再一排直的；盘半径 32）。
- `BeltSlots`：`_on_changed` 时取 `layouts[n]`，有 → `custom_minimum_size` = 图大小、`slot_center(i)` 返回 `centers[i]`；`_draw` 先 `draw_texture` 整张，然后**不画** `belt_slot.png` 圆底和绿圆（袋面压花圆就是槽），图标 56、数量圆标、空槽小点、双击 / 悬停范围（半径 36）都以 `centers` 为心；没图标时画名字头一个字用墨色 `#2e2219`。格数 > 6 或图缺 → 退回现在的一排直圆槽（整段 fallback 保留，测试两条路都走）。
- 宿主 `BeltWidget`：不要 HUD 凹槽底 —— `theme_type_variation = PANEL_BARE` 且 190 的「栏里 / 栏外换底」对它跳过（`_grooved_variation()` 覆盖返回 `PANEL_BARE`）。右下角偏移照旧 `BELT_OFFSET`（−8, −8）。
- 图进 `assets/ui/belt/`（六张 + `layout.json`），旧 `belt_slot.png` 留给 fallback。

### 2.4 图例 → 燕尾旗（`nonrect/pennant/`）

- `LegendWidget._legend_theme()`：`StyleBoxFlat` → `StyleBoxTexture`（`legend_pennant.png` 158 × 300，`texture_margin [44, 52, 44, 58]`，`content_margin [30, 54, 26, 50]`，中段 STRETCH）；`custom_minimum_size.x = 158`，英文长名往宽撑；字白、图标按类型色照旧，tone dark 不变。钉子、绳、横杆都在图里，控件左上 = 图左上。
- 图进 `assets/ui/hud/legend_pennant.png`（+ json）。`BG / PAD_X / PAD_Y` 三个常量删。

### 2.5 共同规矩

- 图都走 `UiTheme.art_cached` / `EventImage.load_texture`（`_draw` 里取图只能用 `art_cached`，记忆 art-cached-in-draw），不从 `/mnt` 读。
- 1x 进 `assets/`，`@2x` 不拷（216 规矩）。`manifest` 不涉及（这几张不是道具图）。
- 每块仍要声明 tone（书、背包 light；旗 dark；皮带件 `PANEL_BARE` light）。
- 凸出件在矩形外：居中 / 夹边 / 教程指认都按内容矩形，只在 `_clamp` 加 outset。
- 英文：图里没字，不用 `_en` 版。

## 三、改动点与测试

- 改：`ui/widgets/overlay_frame.gd`（`whole` 皮）、`ui/game/game_screen.gd`（`_centered_panel` 的 `skin`）、`ui/game/event_screen.gd`（绝对摆位、标题进右页）、`ui/game/event_image.gd`（`framed` 参数、浅底占位）、`ui/game/floating_window.gd`（`outset`、把手矩形）、`ui/game/bag_window.gd`（`_back` 四件、横线删、收起钮）、`ui/widgets/belt_slots.gd`（`layouts`）、`ui/hud/widgets/belt_widget.gd`（`PANEL_BARE`）、`ui/hud/widgets/legend_widget.gd`（`StyleBoxTexture`）；新资源 `assets/ui/event/event_book.png` + json、`assets/ui/bag/`、`assets/ui/belt/`、`assets/ui/hud/legend_pennant.png`。
- 测试：`test_screens_157`（事件屏标题现在在右页标签上，`overlay_frame().title()` 照旧返回字）、`test_belt_slots_160`（1–6 格 `slot_center` = 表里的圆心；7 格退回直线；双击命中半径 36）、`test_hud_150 / 189`（腰带件 `PANEL_BARE`、图例最窄 158）、`test_map_screen_166`（图例行数不变）、新 `test_bag_window_232`（四件位置随 W 变、`_clamp` 含 outset、横线不画）、`test_event_book_232`（`image_rect / text_rect` 摆位、选项仍在右页底）。add_theme 计数器：新图都在 `ui/widgets` / `ui/hud` / `ui/game` 之外不涉及 `ui/inventory`。
- 截图复核：事件窗（搜索点 + 军团的交代 + 结果页带收获行）、背包窗 9 × 6 与 8 × 6 两种宽、腰带 1 / 3 / 6 格、图例中英，交 游戏测试 走一遍。

## 四、待作者定（没回音按推荐）

1. 事件窗「军团的交代」（218）也换成书 —— **推荐换**（它走同一个 `_frame`，交代也是读给你听的）；还是交代保留石板。
2. 背包窗翻盖整块当把手（拖动区变大，**推荐**）—— 还是只有标题行那 52 高。
3. 腰带超过 6 格退回直圆槽（**推荐**，现在最多 6）—— 还是让美术补 7、8 格的图。

## 五、派工

- **执行**：四样一单，按 §二 做；排在 230（悬浮窗按钮）之后、226 批二之前。落地后截图交游戏测试。
- **美术设计**：商店（3）与战斗三屏边框（4）的方向稿等作者挑；挑定后另开报告。
