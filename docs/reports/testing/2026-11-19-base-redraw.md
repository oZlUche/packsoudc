# 基地五处场景与操作界面验收

基线为美术分支的 `03eccc20`。对比使用同一份基地存档，存款 520、仓内 25 件物品，两个版本的市场货品、配方和战绩数据一致。玩家视口为 1280 × 800。五个场景对应左侧四个主入口，其中市场、铁匠都归在后勤。

## 玩家视角

| 位置 | 实机检查 |
|---|---|
| [出征](../../../handoff/art-review/game-station-expedition.jpg) | 军功碑坐在左侧石台，右侧军令露出开始探索按钮，门外道路和整理行装的军士都在视口内。币额可切换数字记法。 |
| [仓库](../../../handoff/art-review/game-station-warehouse.jpg) | 验证空背包时工具面板随内容收起；库存格、整理、快速出售和分页仍可用。 |
| [书架](../../../handoff/art-review/game-station-shelf.jpg) | 六格陈列沿用原互动位置，五个入口各有图签，图鉴、科技、成就按进度分档。 |
| [市场](../../../handoff/art-review/game-station-market.jpg) | 鼠标切换两种摊位，核对货物、价格与经营状态。[另一种摊位](../../../handoff/art-review/game-station-market-fixed.jpg) |
| [铁匠](../../../handoff/art-review/game-station-smithy.jpg) | 打开刀剑分类、选短剑，检查配方、材料、工钱和锻造键。 |

[出征、仓库、书架同档对照](../../../handoff/art-review/station-home-comparison.jpg) · [市场、铁匠同档对照](../../../handoff/art-review/station-logistics-comparison.jpg)

## 验证方法

Godot 4.7.1，Linux，Compatibility 渲染器。使用玩家模式打开基地，依次按两次 Tab 和一次 Enter 进入仓库，再用鼠标走书架、后勤、两种摊位、铁匠、刀剑、短剑配方、出征的路径。中文中字号、中文大字号和英文大字号均完成这条路径。中、英文大字号下另逐一点击书架的图鉴、战利记录、特殊道具、成就和科技，均打开对应页面并返回书架。交易扣款与锻造产出由自动化套件复核。

下列 16 组定向测试共通过 1,243 项断言。可用 Godot 项目入口 `--headless --script res://tests/run_tests.gd -- <套件名>` 逐个复跑。

| 范围 | 套件 |
|---|---|
| 基地与字体 | base_five_264、base_home_164、base_drawer_139、cursor_press_271、fonts_168 |
| 仓库与军功记录 | base_warehouse_178、warehouse_163、sell_tools_268、records_board_260、run_records_261 |
| 后勤交易与锻造 | logistics_262、base_shops_ui_251、base_market_251、market_stalls_270、smithy_251、smith_counts_310 |

回归覆盖各页背景映射、旧入口别名、缺图回退，以及关闭界面动效时中途切页能立即显示目标背景。字体检查发现新代码注释用到了字集外的“簿”，已改用“账册”并重新验证。

导出玩家版 PCK 后，用独立 Godot 进程从玩家入口打开基地并切换五页。每页均加载各自的 1920 × 1080 纹理。项目脚本检查加载 1,070 个脚本，无解析错误。

部分布局测例产生手工调整锚点的提示。截图驱动和部分套件退出时，Godot 报告尚有纹理或对象占用；这些信息出现在操作路径结束后。本轮覆盖基地定向流程，未做长时间内存趋势或全游戏通关测试。
