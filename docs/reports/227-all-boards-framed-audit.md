# 227 全游戏棋盘清查：每一块棋盘都要有外框和格线

作者 2026-10-21 17:25（美术设计线）：「商店界面的棋盘也要显示（包括格子），所有的棋盘都要显示（包括格子）」。这是第二次说（第一次 15:19 在 UI替换美术，224 §七末、记忆 `boards-always-framed-and-gridded`）。上一次只把 187 的格线开关删了、给仓库画了棕底；**外框**没有跟上：现在全游戏只有搜刮屏、背包窗、结算第二页、开局屏这几处的棋盘有美术框，别的棋盘还是深底 + 一圈 2 px 线。

## 〇 一句话

棋盘视图（`InventoryView`）现在有三种画法，哪种由各屏自己决定、默认是最差的那种，所以每新开一屏就漏一次。改成 **外框 + 格缝是视图的默认**：所有 `InventoryView.new()` 都走 `BoardFrame.wrap(view, kind)`，不写 kind 也有框有缝；再加一条守门测试，以后漏框就红。

## 一、现状（核过 `ui/inventory/inventory_view.gd` 262–300、385）

| 画法 | 触发 | 效果 | 现在谁在用 |
|---|---|---|---|
| **格缝** `seams` | 屏自己把 `layout.json` 的 `cell_seams` 塞给视图，外框另由屏放一张 `NinePatchRect`（`container_screen._nine(kind)`） | 浅灰内垫（画在框图里）+ 深线亮线格缝 | 搜刮 / 战利品屏两块、背包窗、结算第二页带回的棋盘 |
| **底样式** `ground` | 屏塞 `GROUND_WAREHOUSE` | 棕底、浅格线在道具下面、外圈深色细边 | 仓库分页（基地、开局、结算） |
| **默认** | 什么都不设 | 深底 `COLOR_BG` + 1 px `COLOR_GRID` 格线 + 2 px 边；放在石板 / 青铜 / 粗布上像一块黑砖，格线在深底上几乎看不见 | **其余全部**（下表） |

外框图只有六种（`assets/ui/board/`，九宫格 margin 70 / boss 74 / player 54，`cells_offset` 40 / 44 / 24）：`frame_search` 藤编、`frame_chest_iron` / `_gold`、`frame_corpse` 生皮、`frame_boss` 黑铁、`frame_player` 皮带。青铜三屏的深色变体 `frame_<kind>_dark` 在 UI替换美术手里（`art/ui/bronze3/`），随青铜三屏落。

## 二、逐块清单

| 屏 | 位置 | 棋盘 | 现在 | 目标 |
|---|---|---|---|---|
| 商店 | `shop_screen.gd` 61 `_mount_bag` | 玩家棋盘 | 默认 | 皮带框 `player` + 格缝 |
| 商店 | 43 `_sell_view` | 出售区 | 默认 | 小件框 `plain` + 格缝 |
| 商店 | 215 每个货位一块 `InventoryView` | 货架（每件一格盘） | 默认，紧贴物品，下面一行裸价签 | 每个货位套 `plain` 框 + 格缝；价签换美术挂牌（226） |
| 神坛 | `altar_screen.gd` 63 | 玩家棋盘 | 默认 | `player` + 格缝 |
| 神坛 | 41 `_table_view` | 祭品台 | 默认 | `plain` + 格缝 |
| 铸炉 | `forge_screen.gd` 108 | 玩家棋盘 | 默认 | `player` + 格缝 |
| 铸炉 | 65 四个槽、81 出牌槽 | 槽 | 默认，坐在底图的槛上 | `plain` + 格缝（槽很小，框用 `plain` 的窄边） |
| 保险箱 | `safe_screen.gd` 42 | 玩家棋盘 | 默认 | `player` + 格缝 |
| 保险箱 | 28 `_view` | 保险箱 3×3 | 默认 | `plain` + 格缝（将来可换铁箍小框） |
| 科技页 | `tech_panel.gd` 101 `_zone_view` | 上交区 | 默认 | `plain` + 格缝 |
| 开局屏 | `setup_screen.gd` 1296 `_board_view` | 第二页玩家棋盘 | 皮框 `PANEL_PACK_LEATHER` 在外、视图里面是默认深底格 | 保留皮框，视图改格缝（和背包窗一致） |
| 开局屏 | 1371 `_preview_view` | 第一页棋盘预览 | 默认 | `player` + 格缝 |
| 开局屏 | 462 `_stash_view` | 地上 | 默认 | `plain` + 格缝 |
| 开局屏 | 288 仓库分页 | 仓库 | 棕底 + 木框 | 保留 |
| 战前 | `prebattle_screen.gd` 51 `_enemy_view` / 73 玩家 | 敌方 / 玩家 | 默认（青铜三屏方案里已定 `frame_<kind>_dark`） | 随青铜三屏落：敌方 `corpse_dark`（敌人按种类 / 强度换框是待做，先统一生皮），玩家 `player_dark` |
| 战斗 | `battle_view.gd` 727 两块缩小棋盘 | 双方 | 默认，缩放 `BOARD_SCALE` | 随青铜三屏落，同上 |
| 搜刮 / 战利品 | `container_screen.gd` | 两块 | 已有框 + 格缝 | 保留 |
| 背包窗 | `bag_window.gd` 78 | 玩家 | 已有框 + 格缝 | 保留 |
| 地图 | `map_screen.gd` 697 悬浮窗里的敌人棋盘 | 敌方预览 | 默认，在纸签上 | `corpse` + 格缝，缩小一档（纸签里放得下） |
| 结算 | `result_screen.gd` 206 `_safe_view` | 保险箱带出 | 默认 | `plain` + 格缝 |
| 结算 | `warehouse_panel.gd` 137 带回棋盘 / 83 仓库 | 两块 | 已有皮带框 + 格缝 / 棕底 | 保留 |
| 基地 | `meta_screen.gd` 147 仓库 | 仓库 | 棕底 + 木架 `PANEL_SHELF` | 保留 |
| 基地 | 仓库页带回棋盘（`warehouse_panel`） | 带回 | 皮带框 + 格缝 | 保留 |

共 **22 块**，其中 **14 块还是默认画法**；青铜三屏那 4 块已在路上，剩 10 块是这次要补的。

## 三、做法：框和缝成为默认

1. **`BoardFrame`**（新，`ui/inventory/board_frame.gd`）：一个 `Control`，里面一张九宫格 `NinePatchRect` + 一个 `InventoryView`；按 `layout.json` 的 `pieces[kind]` 取图、margin、`cells_offset`，自己算内边距，视图尺寸变了跟着变（搜刮屏 `_nine` / `frame_pad` 那套搬进来，搜刮屏改用它）。`static func wrap(view: InventoryView, kind: String = "") -> BoardFrame`；`kind` 空 = 视图是棋盘模式（`requires_bag`）就 `player`，否则 `plain`。缩放（战斗屏 `BOARD_SCALE`、地图纸签）在 `BoardFrame` 上做，不在视图上。
2. **格缝默认**：`InventoryView.seams` 空时不再画深底格，而是用 `ContainerScreenScript.board_layout().cell_seams`（读一次缓存）；`ground` 仍优先（仓库）。深底格那条路只留给 `BoardFrame` 之外、读不到 `layout.json` 的异常情况。
3. **框的种类**：`player` 皮带 / `search` `chest_iron` `chest_gold` `corpse` `boss`（搜刮屏照旧按 `frame_kind_of` 选）/ **新 `plain`**（小件框：浅灰缝线内垫 + 一圈窄石边或细皮边，margin 约 40、`cells_offset` 约 16，给出售区、祭品台、槽、保险箱、上交区、地上、货位用）/ `warehouse` = 棕底不加框（仓库已有木框 / 木架）。青铜屏用 `_dark` 变体，`BoardFrame.wrap(view, "player", true)` 第三个参数选深色。
4. **商店货位**：每个货位一块 `plain` 框；价签换 226 的挂牌，挂在框的下沿正中。
5. **`InventoryPanel`**：`board_view` 默认就裹在 `BoardFrame("player")` 里（`detach_strip` 等照旧），搜刮屏、背包窗不再各自放 `_nine("player")`。

## 四、守门测试 `test_boards_framed_227`

- **运行时**：headless 把每个屏开一遍（沿用 226 守门测试的那套遍历），凡 `InventoryView`：(a) 祖先里必须有 `BoardFrame`，或 `ground` 非空；(b) `seams` 非空或 `ground` 非空。缺一报屏名 + 节点路径。
- **静态**：`grep` 全仓 `InventoryView.new()`，只允许出现在 `BoardFrame.wrap` 的调用参数里和 `BoardFrame` / 沙盒 / 测试内部；别处出现就红（和 `TextLint` 同一类的源码检查）。

## 五、要美术设计出的图

一张 **`frame_plain`** 小件框（浅灰缝线内垫同 `cell_seams.base`，一圈窄边；九宫格 margin ≈ 40，`cells_offset` ≈ 16，透明出血同其它框），加一张深色变体 `frame_plain_dark` 给青铜屏（铸炉的槽、战前若有）。敌人按种类 / 强度换框仍是待做（`/mnt/project-files/reference/待做-界面.md`），这次先统一生皮。

## 六、派工

执行：排在 226 批二之后（和 226 的「签」一起动屏最省）。顺序：`BoardFrame` + 格缝默认 → 十块补框（图没到前 `plain` 用 `player` 代） → 搜刮屏 / 背包窗 / `InventoryPanel` 改走 `BoardFrame` → 守门测试。青铜三屏那四块由 UI替换美术的方案落，落时也走 `BoardFrame`（深色变体）。
