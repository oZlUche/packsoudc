# 274 按住修饰键整包拿起

作者 2026-11-04 15:01：「增加一个键，我考虑CTRL或者shift，按住时可以在棋盘中选中背包而非道具，这样可以直接拖动整个背包」。

## 〇 一句话

按住 Ctrl 时，棋盘上点到哪一格都按「覆盖这一格的包」算：左键拿起整包（内容物跟着走，现成的逻辑），右键开包的说明窗；松开 Ctrl 恢复原样。按住时鼠标悬在包里的道具上，整个包描一圈亮边，告诉玩家这一下拿的是包。

## 一、现状（读码）

| 项 | 现状 | 出处 |
|---|---|---|
| 点击判定 | 先取这一格的普通物品 `cell_uid`，没有才取 `bag_at` 的包 —— 所以装了东西的包只能点它露出来的空格才能拿 | `ui/inventory/inventory_view.gd:321–326` |
| 整包拖 | 拿起有内容物的包已经走 `detach_bag` / `attach_bag`，内容物跟着走，转向后挂不住的脱落到地上 | `drag_layer.gd:212`，帮助页「拖动与旋转」 |
| 修饰键 | 只有地图点击看 `shift_pressed`；Ctrl 没人用 | `ui/map/map_view.gd:563` |
| 右键 | 右键按在一件上 = 这一屏自己决定（说明窗 / 奉为主信仰）；同样先物品后包 | `inventory_view.gd:333`，`hover_tip.gd:1196` |

## 二、方案

- **键**：Ctrl（Mac 上 Cmd 同样算，`InputEventWithModifiers.is_command_or_control_pressed()`）。不用 Shift：地图点击已经用 Shift，且 Shift 在别的游戏里多半是「批量 / 加选」，以后快速出售若要 Shift 连选还留得住。
- **判定**：`InventoryView._gui_input` 与 `hover_tip` 取 uid 的地方，Ctrl 按着时跳过 `cell_uid` 直接取 `bag_at(c)`；那一格没有包就照旧取物品（自由容器、地面、包架不受影响 —— 它们没有「包覆盖」这层）。左键 = 拿起整包，右键 = 包的说明窗，双击 = 包的快速置入（和点包空白处一致）。
- **提示**：Ctrl 按下 / 松开时棋盘重画；悬停格被包覆盖且 Ctrl 按着 → 那个包的轮廓描一圈亮边（现有的选中 / 悬停描边样式，颜色用包的稀有度色），光标仍是手套。
- **勾选模式（268 快速出售）**：Ctrl 不改勾选对象（勾的还是道具）—— 包在棋盘上本来就不卖（待定 2）。
- **帮助页**「拖动与旋转」加一句：「按住 {key:Ctrl} 再点包里的道具，拿起的是整个包。」zh / en。

## 三、改动清单（执行）

1. `InventoryView._gui_input`：`var uid := inventory.bag_at(c) if mb.is_command_or_control_pressed() else inventory.cell_uid(c)`，为空再按原顺序兜底；`_input` 里 Ctrl 键按下 / 松开 → `queue_redraw`；悬停描包边。
2. `HoverTip` 取 uid 的那处同样看 Ctrl。
3. 帮助页 `drag_and_rotate.json` 加一句（zh / en）；`{key:Ctrl}` 若键名表没有就加。
4. 测试：Ctrl 按着点有物品的包格 → `grab_requested` 的 uid 是包；不按 → 是物品；自由容器 / 地面不变。

## 四、待定（没回音按推荐）

1. Ctrl 还是 Shift —— **推荐 Ctrl**（理由见上）。
2. 勾选模式下 Ctrl 是否改勾包 —— **推荐不改**。
3. 描边提示 —— **推荐做**（一行重画，不做的话按下去才知道拿的是什么）。
