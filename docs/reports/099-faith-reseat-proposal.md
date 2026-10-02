# 099 · 方案：在背包里切换信仰改成明确规则（097 的 P1）

> 2026-10-01 ｜ 提议 · 作者已选 A + B（待定项按推荐），交执行 thread ｜ 对应架构文档 3.5、3.8

## 目标

保留作者要的手感：**不进菜单，在背包里一下就切信仰**。把现在靠旁路实现的行为改成规则，顺便把拖拽路径补回 3.5 的原子移动。

## 现状（已核实）

- 拖拽层拿起 = `grid.remove(uid)`、放下 / 取消 = `grid.place(...)`（`ui/inventory/drag_layer.gd:126, 448, 656`）；`remove` 把 `container_id` 清 0（`grid_inventory.gd:383`），所以放回同一棋盘也算「从别的容器进来」：`place_seq` +1、发 `placed`（`:351-361`）。
- 后果一：棋盘内拖一下信物就切信仰 —— 作者要的。
- 后果二（**已确认，不是推断**）：`RunState._wire_faith_power` 把 `board.placed` 接到信力的 `place_item` 行为（`run_state.gd:1186`），`FaithPower.credit` 没有按件去重（`faith_power.gd:44-56`），`data/authoring/faiths/skill.json:15` 用了这个行为。**在棋盘上来回拖同一件道具就能刷信力。**
- 后果三：取消拖拽（右键 / Esc）、放不回原位也走同一条路，都会切。
- `InventoryService.move` 本来就处理了同容器（`inventory_service.gd:34`），只是拖拽层没用它。

## 方案

### A · 规则：棋盘内「落下」信物 = 重新置入；取消不算

1. `GridInventory` 加一个明确接口：

   ```gdscript
   ## 099：把这件已在本容器里的道具盖成最新置入（信仰切换用）。不发 placed（不算「置入」行为，信力不记）
   func reseat(uid: int) -> bool
   ```
   只改 `placed_seq`，不动格子、不发 `placed`；发 `changed` 让界面重画。

2. `DragLayer`：
   - 拿起时**不再真移除**：记 `_src_*`，调新的 `grid.lift(uid)` 把这件从占用表挪开但保留 `container_id` 和 `_items` 里的登记（界面用 `is_dragging()` 已经能区分「拿在手上」）。
     若改动面太大，退一步：拿起仍 `remove`，但**放回同容器前先 `inst.container_id = grid.id`**（和 `InventoryService.move` 同一行），这样 `place` 不算 arrived；然后只在「真正落到同一棋盘的另一处」时调 `reseat`。
   - 落到同一棋盘：`place` 成功后 `reseat(uid)` —— **只对信物**（`def.is_anchor()`）调，普通道具不盖序号（避免给以后「最后置入」的别的规则留坑）。
   - `cancel()` / `_restore()`：不调 `reseat`，不发 `placed`。
   - 跨容器：改走 `InventoryService.move / _move_bag`，`_restore` 的「已丢失」分支变成不可达（保留 `push_error` 兜底）。

3. 信力的 `place_item` 行为保持「从别的容器进来才算」的语义，刷点自然堵上。

### B · 右键信物「奉为主信仰」

- `InventoryView._gui_input`：右键落在信物上且没在拖 → 发 `item_context(self, uid)`；`InventoryPanel` 收到后调 `flow.reseat_anchor(uid)` → `run.board.reseat(uid)`。
- 不做弹出菜单，右键一下直接切；悬浮窗（`item_tooltip.gd`）在信物那行多一句「右键：奉为主信仰」，已是激活的写「当前信仰」。
- 开局屏的棋盘同一套（`setup_screen` 的 `InventoryPanel` 已复用）。

### C · 信仰栏

不做，等信仰道具多了再议。

## 关键决策

- `reseat` 不发 `placed`：**切换信仰 ≠ 置入道具**，信力的行为只认真正从别处来的。
- 只对信物 reseat：`placed_seq` 现在只有信仰在用，但它是通用字段，不给普通道具乱盖。
- 拖拽层改走服务层是顺手修 3.5 的债，和 A 一起做，否则 `_restore` 的旁路还在。

## 验证

- `tests/test_faith_reseat.gd`（新）：
  1. 棋盘上两件不同信仰的信物，拖 A 到同棋盘另一处 → 激活变 A；`FaithPower` 的 `place_item` 不加分。
  2. 拖 A 后取消 → 激活不变。
  3. 右键 B → 激活变 B。
  4. 从暂存区拖进来 → 仍然算置入、信力照记（现有行为不变）。
  5. 普通道具在棋盘内拖 → `placed_seq` 不变。
- 现有 `test_drag_layer`、`test_author_095`、`test_effect_system` 全绿。

## 改动范围

`grid_inventory.gd`（+`reseat`，可选 `lift`）、`drag_layer.gd`（拿起 / 落下 / 取消三处 + 跨容器改走服务）、`inventory_view.gd`（右键信号）、`inventory_panel.gd`、`game_flow.gd`（`reseat_anchor`）、`item_tooltip.gd` 一句提示、架构文档 3.5 / 3.8。

## 待作者定

1. 拿起时「不真移除」（`lift`）还是「移除但放回前设回 container_id」（改动小，推荐先这个）？
2. 右键是直接切，还是弹两项菜单（奉为主信仰 / 取消）？推荐直接切。

## 落地（2026-10-01，实现 thread）

作者选 A + B，两个待定项按推荐做：拿起仍 `remove`、**放回同容器前把 `inst.container_id` 设回该容器**（和 `InventoryService.move` 同一行）；右键直接切，不弹菜单。

| 改动 | 文件 |
|---|---|
| `reseat(uid)`：只盖 `placed_seq`，不发 `placed`，发 `changed` | `core/inventory/grid_inventory.gd` |
| 落回同容器不算 arrived；落下的**信物**才 `reseat`；取消 / `_restore` 不切；右键取消吃掉事件（免得被读成「奉为主信仰」） | `ui/inventory/drag_layer.gd` |
| 右键按在一件上发 `item_context`（左键照旧抓取 / 双击照旧快速置入） | `ui/inventory/container_view.gd`、`ui/inventory/inventory_view.gd` |
| `reseat_anchor(uid)`（只认信物） | `core/run/game_flow.gd`、`ui/game/inventory_panel.gd`、`ui/game/setup_screen.gd` |
| 信物那行写「右键：奉为主信仰」/「当前信仰」；面板与开局屏的操作提示各补一句 | `ui/inventory/item_tooltip.gd`、`ui/game/inventory_panel.gd`、`ui/game/setup_screen.gd` |
| 测试：reseat 的性质、棋盘内落下切信仰且信力不记（来回拖十次也不涨）、取消不切、凡物不盖序号、从暂存区进来照记、右键链路 | `tests/test_faith_reseat.gd` |

**没做的一条**：方案 A 第 2 条最后那句「跨容器改走 `InventoryService.move / _move_bag`」。它的前提是拿起时**不真移除**（`lift`）——
作者选了「移除 + 放回前设回 `container_id`」这条小改动，拖拽期间东西已经游离，`move(from, uid, ...)` 没有 `from` 可用。
`_restore` 的「已丢失」兜底分支因此还在（3.5 的这笔债留着）。要还它就得先做 `lift`，是单独一件事。
