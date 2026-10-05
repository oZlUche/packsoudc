# 123 小修：战利品屏的【全部拾取】先往背包放，放不下的才进暂存区

> 架构 · 小修（2026-10-05）。作者：「战利品界面的【全部拾取】应当先尝试置入背包，放不下再放到暂存区，现在会全部置入暂存区」。

## 一、现状（已核实）

- `ui/game/container_screen.gd:161 take_all()`：先 `_loot.reveal_all()`，再 `InventoryService.transfer_all(_container, flow.run.storage)` —— **整份直接搬进暂存区**，按钮提示也写着「全部进暂存区」。`RunState.take_all_loot()` 同样只认暂存区。
- `InventoryService.transfer_all(from, to)` 的顺序已经是「非包在前、大件在前」，`transfer_auto(from, uid, to)` 会在目标里自动找位（棋盘放不下返回 false，不动原件）。暂存区是列表、不限大小，所以永远放得进。

## 二、改法

一个新方法，两处调用：

```
## 084 / 123：全拿走 —— 每件先试棋盘（自动找位、可旋转），放不下才进暂存区。返回 {board: n, storage: n}
static func InventoryService.transfer_all_prefer(from, first: ItemContainer, fallback: ItemContainer) -> Dictionary
```

- 顺序沿用 `transfer_all` 的排序（非包先、大件先：大件先摆更容易都摆下；包最后，因为包进棋盘会改变可放区域，先摆包反而容易把别的挤出去 —— 见待定 1）。
- 每件：`transfer_auto(from, uid, first)`，false 再 `transfer_auto(from, uid, fallback)`。
- `container_screen.take_all()` 与 `RunState.take_all_loot()` 都改成调它（`first = run.board`，`fallback = run.storage`）。按钮提示改成「先进背包，放不下的进暂存区」。
- 拿完后的提示沿用现有逻辑（暂存区有东西离开时按设置档位提醒，3.4）；这里不加新弹窗。

## 三、测试

`tests/run/test_take_all.gd`：
1. 棋盘空、战利品三件都放得下 → 全进棋盘，暂存区空。
2. 棋盘只剩一格、战利品一件 1 格 + 一件 4 格 → 1 格的进棋盘，4 格的进暂存区。
3. 带包的战利品：包放不进棋盘时进暂存区，包里的东西跟着包走（`_transfer_bag` 现有行为）。
4. 两次调用结果一致（顺序稳定），战利品容器清空、`loot_cleared` 发出。

## 四、改动点

| 文件 | 改动 |
|---|---|
| `core/inventory/inventory_service.gd` | 新 `transfer_all_prefer` |
| `core/run/run_state.gd` | `take_all_loot` 改走它 |
| `ui/game/container_screen.gd` | `take_all` 改走它；按钮提示 |
| `tests/run/test_take_all.gd` 新 | §三 |

## 五、待定（按推荐即执行）

| # | 问题 | 推荐 |
|---|---|---|
| 1 | 包先摆还是后摆 | **后摆**（沿用现有排序）；玩家想把包放进棋盘自己拖，自动流程不替他决定棋盘布局 |
| 2 | 搜索屏（同一个容器屏）的「全部拾取」是否同样改 | **同样改**，是同一个按钮 |
