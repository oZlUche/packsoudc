# 268 方案：出售并入集市 —— 后勤只剩 集市 / 铁匠铺，一键出售挂到集市的「收货」木牌上

作者 2026-10-30 14:16：「我考虑将集市和出售合并，因为出售占单独一个页面没有意义，你觉得呢」。

## 〇 一句话

同意。出售页今天只剩两样别处没有的东西：**一键出售**（两个下拉 + 大木牌键）和**包架上卖包**；逐件卖早就在仓库页右键里了。把一键出售做成集市右柱上的一块「收货」小木牌，卖包改成仓库页包架右键，出售页和它的小键就可以删掉。线框：https://claude.ai/artifact/1YKiLQn76H69UrYSetwveN（源文件 [268-sell-into-market.html](/mnt/project-files/architecture/268-sell-into-market.html)）。

## 一、现状（读码）

| 哪里 | 能卖什么 | 怎么卖 | 代码 |
|---|---|---|---|
| 后勤 → 出售页 | 仓库里的件（右列仓库露着） | 双击一件；或 档下拉 + 标签下拉 + 【一键出售】（按钮第二行「会卖 N 件，得 N 币」，跳过锁定 / 收藏） | `MetaScreen._build_sell` / `sell_filtered` / `SELL_FILTERS`；右列 `_on_shelf_double_clicked` |
| 后勤 → 出售页 | 包架上的包 | 双击 / 右键「出售 N 币」 | `sell_bag`、`BagRackView.actions_for` |
| 仓库页 | 仓库里的件 | 右键「出售 N 币」「出售同类」（230） | `WarehousePanel.warehouse_actions` |
| 仓库页 工具列（264） | —— | 筛选牌 = 标签下拉 + 稀有度下拉（和出售页同两档）+ 清除；账牌 | `WarehouseTools` |
| 集市页 | 买 | 整屏换景（264 §三），右列仓库收起（`FULL_TABS`） | `MarketPanel` |

所以出售页的「页」没有独立价值：它的筛选和仓库页筛选牌是同一对下拉，它的逐件卖和仓库页右键是同一件事。独有的只有一键出售和卖包。

## 二、三种落法

### A　集市「收货」木牌（推荐）

- 集市页右柱、钱牌正下方挂一块小木牌 **「收货」**（`PANEL_HOME_PLAQUE_SMALL`，228 × 240 设计像素，标题走 `HeaderTag.hanging`）：标签下拉 / 档下拉 / 【一键出售】两行字（第二行预览，沿用 `sell_preview`）。点下去 = `sell_filtered()`，钱牌读数跳，告示卷轴说「卖了 N 件，得 N 币」（文案全是现成的）。
- 逐件卖：仓库页右键照旧；**包架**在仓库页加右键「出售 N 币」（双击仍是置入），`sell_bag` 搬过去。
- 后勤手风琴只剩 **集市 / 铁匠铺** 两颗小键；`show_tab("sell")` 当别名落到集市（旧存档 / 旧测试不炸）；`_build_sell`、`meta.tab_sell` 删掉。
- 为什么推荐：集市本来就是「商人」，买和卖一处；整屏换景不动（B 会把它缩一半）；仓库页工具列仍是「看」的工具，不混进「卖」。

### B　集市露出仓库

集市从 `FULL_TABS` 里拿掉，右列仓库露出来，像旧出售页那样双击就卖；集市舞台按中列宽整块缩（1300 → 约 700，货格 83 → 45 像素）。不推荐：刚做的整屏换景变成半屏小摊。

### C　卖货进仓库页

筛选牌下面加一颗【卖掉筛中的】键（第二行预览），集市不动，后勤同样只剩两颗键。代码最省（一对下拉同时管看和卖），但在仓库里对着空气卖东西没有商人，且仓库页同时承担 置入 / 锁定 / 出售，操作密度偏高。

## 三、A 的改动清单（执行）

1. `MetaScreen`：`SUB_TABS.logistics` 去掉 `sell`；`_build_sell`、`_sell_pick` / `_sell_tag_pick` / `_sell_rack` / `_sell_btn` 搬进新的 `SellPlate`（`ui/widgets/sell_plate.gd`，`setup(flow)`，暴露 `rarity_pick()` / `tag_pick()` / `button()` / `preview_text()` 给测试）；`show_tab("sell")` 别名 → `"market"`；`_on_shelf_double_clicked` 的 `"sell"` 分支删。
2. `MarketPanel`：舞台右柱钱牌下挂 `SellPlate`，位置写进 `assets/ui/market/layout.json` 新键 `sell`（`{x, y, w, h}`，底图像素，随整页缩放；缺键就落钱牌下 24 像素）。
3. `WarehousePanel`：包架 `actions_for` 加 `ItemActions.sell(inst, price, sell_bag)`（包不进「出售同类」）。
4. 文案：`meta.tab_sell` 删；新 `market.sell_title`「收货 / Buying」。
5. 测试：`test_logistics_262`（小键 2 颗）、`test_base_warehouse_178` / `test_stone_chips` / `test_boards_framed_227` / `test_english_ui_221` / `test_no_bare_text_226` / `test_favorites_265` 里走 `show_tab("sell")` 的改成在集市页找 `SellPlate`；新测：收货牌一键出售后钱牌读数与仓库件数对、跳过锁定与收藏、包架右键能卖。
6. 美术：收货牌用现成小木牌，不需要新图；要是作者想要「商人柜台」的专门画，另派 UI替换美术。

## 四、待定（没回音按推荐）

1. 收货牌挂哪：**右柱钱牌下**（推荐）/ 左柱便条下。
2. 卖包：**仓库页包架右键**（推荐）/ 以后不能卖包。
3. 档下拉顺序：**沿用出售页**（白 → 金 → 全部）（推荐）/ 跟筛选牌（全部在前）。
