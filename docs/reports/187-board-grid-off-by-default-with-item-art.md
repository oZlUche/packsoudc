# 187 · 方案：有了道具图之后，棋盘格子默认不画（设置里能打开），像《背包乱斗》

> 作者 2026-10-17 16:25：「在未来设计出道具图片后，默认将格子显示关闭（默认的意思是可以打开），类似背包乱斗」。
>
> 本篇是小方案：开关现在就做、默认值跟着「道具图到没到」走，道具图落地那一批只需翻一个常量。已转「架构方案执行」。

## 1. 现状

`ui/inventory/inventory_view.gd:182-289` `_draw()`：先整块 `COLOR_BG`，再逐格画格底（`COLOR_CELL` / 被挡 `COLOR_BLOCKED` / 包没盖到 `COLOR_UNUSABLE`），再画网格线（`COLOR_GRID`，1 px），再包体、物品、邻接标记、拖拽预览色块、被顶的描边，最后外框（`COLOR_BORDER`，2 px）。背包、棋盘、仓库、敌人棋盘、地面层（`ground_layer.gd`）、收获行（`harvest_row.gd`）都从 `ContainerView` / `InventoryView` 来。道具现在没有图，格里画的是名字（170 起名字要进悬浮窗、格里放图）。

## 2. 方案

### 2.1 一个设置、一个默认

- `GameSettings.show_grid: bool`，存读（键 `show_grid`，缺省读 `GameSettings.grid_default()`）。
- `grid_default()` = `not ItemPainter.art_available()`：**道具图包在 = 默认不画，不在 = 默认画**。`ItemPainter.art_available()` 现在恒为 false（没有图），道具图落地那一批把它接到图包的存在判断上（例如 `assets/items/manifest.json` 在不在），别的不用动。
- 设置屏「显示」节（172）加一个开关「棋盘格线」；改了立刻生效（所有开着的 `InventoryView` `queue_redraw`，和「换屏淡入」同一套刷新）。

### 2.2 关着时画什么、不画什么

| 元素 | 开（现在） | 关 |
|---|---|---|
| 整块底 `COLOR_BG` | 画 | 不画（棋盘所在的面板 / 石板凹槽就是底） |
| 格底三色（可用 / 被挡 / 包没盖到） | 画 | 不画 |
| 网格线 | 画 | 不画 |
| 包体（包覆盖的区域） | 画 | **画**：包是道具，有自己的图（没图时沿用现在的包体色块）—— 玩家靠包看出哪里能放 |
| 物品、邻接标记、装载槽标记 | 画 | 画 |
| 拖拽预览色块、被顶的描边 | 画 | 画 |
| 外框 2 px | 画 | 不画 |
| **拖着东西时** | — | 网格线与格底按 50 % 透明临时画出来，松手即隐（《背包乱斗》同款：落点要看得准） |

- 敌人棋盘（战前、回放）跟同一个开关。
- 仓库（基地、结算）跟同一个开关：仓库页数多、空格多，关着时只剩包体与道具，更像货架。
- 地面层本来不画格，不受影响；收获行同。

### 2.3 快捷键

不加。设置里一个开关够了；《背包乱斗》也只在设置里。

## 3. 改动清单（给执行）

- `core/settings/game_settings.gd`：`show_grid` + `grid_default()`；`to_dict` / `from_dict`。
- `ui/inventory/item_painter.gd`：`static func art_available() -> bool`（现在返回 false，带注释：道具图落地时接图包判断）。
- `ui/inventory/inventory_view.gd`：`_draw()` 按 `show_grid()` 分支（底、格底、线、外框四处）；`dragging` 为真时临时按 50 % 画线与格底；`show_grid()` 读 `GameSettings` 当前值（视图自己不存，宿主换设置后 `queue_redraw`）。
- `ui/game/settings_screen.gd`：「显示」节加「棋盘格线」开关；切换时广播（现有的设置变更通知）。
- 测试：
  1. `GameSettings.from_dict({})` 的 `show_grid` = `grid_default()`；`ItemPainter.art_available()` 为 false 时默认 true。
  2. `show_grid = false` 时 `InventoryView._draw` 不画格底与线（用 `RenderingServer` 画布项读指令数，或给视图加 `drawn_grid` 计数供测试读）；拖拽中画。
  3. 设置屏能找到「棋盘格线」开关，切换后 `flow.settings.show_grid` 翻转、存档读回一致。

## 4. 待定（默认按推荐）

1. **现在做还是等道具图** —— 推荐 **甲**：现在做开关与默认值逻辑，道具图那一批只翻 `art_available()`。乙：等图一起做（到时又是一包改动）。
2. **关着时包体还画不画** —— 推荐 **甲**：画（包决定哪里能放，不画玩家摸黑）。乙：也不画，只靠拖拽时的临时网格。
3. **拖拽时的临时网格** —— 推荐 **甲**：画（50 % 透明）。乙：不画，完全靠预览色块。
