# 方案：仓库扩建从「加行」改成「加页」—— 每页独立一块格子，左侧竖排选项卡切换（163）

> 作者原话（2026-10-12，架构设计）：「关于仓库科技，目前改成不要新增行，而是新增页，每一页横向排列但彼此独立，不共享空间。」→ 「算了，不要横排，改成竖排选项卡切换每页」。
> 性质：架构 · 实施。待定按推荐。关联 058（仓库）、109（整理 / 快速置入）、110 / 118 / 119 / 120（科技与派生）、139（格子按宽放大）、161（开局第二页也用仓库）。

## 1. 现状

- 仓库是**一块** `GridInventory`（`MetaState.warehouse`，`MetaRules.warehouse_size` 10 × 8），科技「仓库扩建」六级，每级 `+3 行`（`TechWarehouseRows.derive` → `resize_rows`），满级 10 × 26。读档按 120：先按科技等级派生行数，再装东西。
- 用到它的地方全靠 `GridInventory` / `ItemContainer` 的接口：发放（`grant`）、带回置入（`store_all` / 双击快速置入）、开局带入与放回（`setup_screen` 的 `carry_in / store`，`take_back`）、一键出售（`_sellable`）、科技上交（`tech_panel` 的收起式仓库视图）、主菜单计数、图鉴点亮。
- 界面：`warehouse_panel.gd` 一块 `InventoryView` 套 `ScrollBox`（钉死四行 —— 已转小修），139 按面板宽放大格子（封顶 80）。

## 2. 改法

### 2.1 核心：`Warehouse` 多页容器

- 新类 `core/meta/warehouse.gd`（`class_name Warehouse extends ItemContainer`）：`pages: Array[GridInventory]`（每页都是 `warehouse_size()` 那么大、`id = WAREHOUSE_ID + 页号`、同一个 `accept_filter`），对外还是一个容器：
  - `admit(inst)` / `try_add`：按页序找第一页放得下的（待定 1）；`can_admit(def)` = 过滤器；`get_item / remove / items / item_count` 跨页；`begin_batch / end_batch / changed` 转发（任一页变了就发）。
  - `page(i)`、`page_count()`、`page_of(uid)`；`set_page_count(n)`：多了在后面加空页，少了只删**末尾的空页**（碰到有东西的页停下并告警，和 120 的缩行一样）。
  - `to_dict()`：`{"pages": [每页 GridInventory.to_dict()]}`；`from_dict(d, items, page_size, page_count)`：老档（单块 `{"size", "items"…}`）按页切：行 0 ～ 7 的东西落第一页原位，更下面的各件按页序 `try_add` 重摆；新档逐页读，超出页数的页里的东西也 `try_add` 到现有页（科技等级被改小时）。不升存档版本（看字段形状分新旧）。
- `MetaState.warehouse` 的类型改成 `Warehouse`；调用处的 `transfer_auto(..., warehouse)`、`try_add`、`get_item`、`items()` 都不用改（接口同名）。`_sellable`、`grant`、`take_back`、`store_all` 跨页自然成立。
- 科技：`TechWarehouseRows` 改名 `TechWarehousePages`（`warehouse_pages`，`pages: int = 1` 每级加几页，待定 4）；`derive` = `warehouse.set_page_count(1 + pages × level)`；`describe_level` 写「仓库共 N 页」。`docs/techs.xlsx` 节点表那一行的效果构件改成 `warehouse_pages`，重新生成 `techs/warehouse.json`；说明文字改成「仓库多一页，各页独立」。
- 页数派生仍在装东西之前（120 的顺序不变）。

### 2.2 界面：左侧竖排选项卡 + 一页一块格子

- 新组件 `ui/game/warehouse_pages.gd`（`WarehousePages`，`HBoxContainer`）：左一列竖排选项卡（`VBoxContainer` 里一列按钮，`UiTheme.mark` 标选中，不加 `add_theme_`），右边一块 `InventoryView` 显示当前页（切页只换 `inventory`，视图与拖拽登记不重建）。选项卡文字用中文数字「一」「二」「三」……（不写阿拉伯数字）；每页标签下一行小字写「几件」。**未解锁的页**也列出来、灰色加一把小锁，悬停写「仓库扩建到第 N 级解锁」—— 玩家能看到还能扩多少。
- 三处共用它：基地屏仓库页（`warehouse_panel.gd`，替换那一块 `InventoryView + ScrollBox`；带回来的棋盘仍在左边）、科技页的收起式仓库（`tech_panel.gd`）、开局屏第二页（161）。
- 拖拽：当前页视图登记进 `DragLayer`；拖着东西**停在某个选项卡上 0.4 秒**切到那页（待定 2），放手就落在那页；没停够就按原页算。双击快速置入（109）：带回来的棋盘 → 仓库按 2.1 的页序落、落到哪页视图跳到哪页；仓库 → 棋盘不变。
- 「整理」（109）只整理**当前页**；「一键置入」按页序（和 `admit` 一致）；「一键出售」跨页（现有逻辑）。
- 139 的按宽放大：一页固定 10 列，算法不变，纵向 8 行在 80 px 时 640 px，基地屏放得下，不再需要滚动框（小修那条「裁成四行」在这一改之后自然没了，先后顺序由执行定）。
- 主菜单的「仓库 N 件」与图鉴不受影响。

### 2.3 测试

- `test_warehouse`：三页各 10 × 8；`try_add` 按页序落、第一页满了落第二页；`get_item / remove` 跨页；`set_page_count` 只删空页；存档来回；老档单块 10 × 14 读成两页（行 8 以下的东西重摆）；科技等级 6 → 七页。
- `test_tech_service`：`warehouse_pages` 派生页数；降级只删空页。
- `test_warehouse_panel`：切页换视图、双击置入落到的页被选中、未解锁页不可选；拖拽悬停切页。
- `test_meta_state`：`store_all` / `grant` / `_sellable` 跨页件数正确。
- UI 棘轮不涨。

## 3. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 自动放（置入 / 发放 / 放回）落哪页 | A 按页序第一页有空就放；B 当前看的页优先 | **A**：可复现、测试好写；视图跳到落下的那页，玩家不会找不到 |
| 2 | 拖着东西停在选项卡上切页 | A 做（0.4 秒）；B 不做，只能放当前页 | **A**：跨页挪东西没有别的路 |
| 3 | 页的名字 | A 一、二、三……；B 可改名 | **A** |
| 4 | 每级加几页 | A 一页（满级七页 560 格，比现在 260 格多一倍多）；B 一页但只剩三级 | **A**：页数是数据，作者随时改 xlsx |

## 4. 改动范围

| 文件 | 改什么 |
|---|---|
| `core/meta/warehouse.gd`（新）、`core/meta/meta_state.gd`、`core/meta/techs/warehouse_pages.gd`（改名自 `warehouse_rows.gd`）、`core/run/run_registry.gd`（登记名） | 2.1 |
| `docs/techs.xlsx`、`tools/techs_xlsx_to_json.gd`、`data/authoring/techs/warehouse.json`（重新生成） | 2.1 |
| `ui/game/warehouse_pages.gd`（新）、`ui/game/warehouse_panel.gd`、`ui/game/tech_panel.gd`、`ui/game/setup_screen.gd`（161 第二页） | 2.2 |
| `tests/meta/test_warehouse.gd`（新）、`tests/meta/test_tech_service.gd`、`tests/ui/test_warehouse_panel.gd`、`tests/meta/test_meta_state.gd` | 2.3 |
| `docs/architecture.md` 8 节（仓库）、110 / 120 那两段 | |
