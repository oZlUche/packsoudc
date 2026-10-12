# 方案：「全部拾取」先塞包再塞件；放不下的落地动画从棋盘起飞、飞着也能抓（162）

> 作者原话（2026-10-12，架构设计）：「【全部拾取】的逻辑应该是先将战利品里的包塞进我方棋盘（放不下再抛出），然后尝试将道具塞入棋盘。还有，当道具放不下时的掉落，动画应该从棋盘处开始播放落下，且播放过程中的道具依旧可以被点击拖动。玩家手动拖出时同理」
> 性质：架构 · 实施。待定按推荐。关联 087（连包搬）、123（全拿先进棋盘）、128（地上）、134（落地动画）、159（没拿的落地）。

## 1. 现状

- 「全部拾取」（`container_screen.take_all` → `InventoryService.transfer_all_prefer(待拾取, 棋盘, 地上)`）的搬运顺序是 `_take_order`：**不是包的排前面**，按占格数从大到小，包排最后。于是先塞件、件塞不进（棋盘上包的空位不够）就落地，最后才轮到包 —— 和作者要的正好反过来。087 的「带东西的包连内容物一起搬」（`_transfer_bag`：内容物先各自进目标、包最后）仍在。
- 落地动画（134，`GroundLayer`）：起点看 `ItemStash.landing_from[uid]`：给了全局像素就从那里飞；`true` = 就地（只缩放 + 弹跳）；**没给**就从离落点最近的已登记面板边缘飞出、没面板从上方落下。「全部拾取」放不下的那几件没人写 `landing_from`，所以从面板边上飞出来，不是从它在棋盘上的那格。拖拽放手落地写的是 `true`（就地）；顶替顶出去的那件写了它在棋盘上的格子（`drag_layer.gd` 644 行）—— 作者要的正是这个写法。
- 半空中的不接鼠标（`uid_at_local` 跳过 `_landing` 里不在 `in_place` 的那件，0.28 秒）。

## 2. 改法

### 2.1 先包后件

- `InventoryService._take_order` 改成：**作为包生效的排最前**（大包先），然后其余件按占格数从大到小。`transfer_all_prefer` 不动：包先进棋盘（棋盘是 `requires_bag` 的，包落在裸格上），放不下的包落地（「放不下再抛出」）；接着件逐个进棋盘，这时棋盘上多了刚塞进去的包，能进的更多。
- 087 的连包搬保留但顺序配合：待拾取里带着东西的包，`_transfer_bag` 先把内容物各自塞进目标再塞包 —— 改成**先塞空包、再把内容物一件件按普通件的顺序塞**（内容物进了 `loose` 列表排进 2.1 的顺序里），这样内容物有机会进它原来那个包。塞不进的包连内容物一起到地上的逻辑不变（`_transfer_bag` 失败时回滚）。
- `fold_loot_into_search`（搜索里打赢）和 159 的落地不走这条，不动。
- 仓库的「一键置入」（109）同样是 `transfer_all_prefer`，顺序跟着变 —— 仓库不收包（`keeps`），包排前面只是立刻失败落回，无害。

### 2.2 落地动画从棋盘那格起飞

- `container_screen.take_all()`：调搬运**之前**，给待拾取里每件记起点 `flow.run.storage.landing_from[uid] = _loot_view.global_position + _loot_view.cell_origin_px(inst.origin)`（和 644 行顶出同一写法）；搬完把没落地的 uid 从 `landing_from` 里清掉（它们进了棋盘，不需要起点；留着会让下一次落地错位）。`GroundLayer._scan` 在地上 `changed` 时消费起点，`end_batch` 只发一次信号，时机对得上。
- 单件拖出棋盘到地上：作者说「同理」—— 现在是放手点就地落下（`true`），改成**从它在棋盘上原来那格飞到放手点**（起点 = 拖起时记下的 `grid_view.global_position + cell_origin_px(origin)`，拖拽层拖起时已经知道来处）。从地上拖到地上照旧就地。
- 放不下弹回地上的（拖拽层 `_can_shed` / 顶出）本来就从格子起飞，不动。

### 2.3 飞着也能抓

- `GroundLayer.uid_at_local` 不再跳过半空中的：命中区用 `landing_pose(uid)` 的当前位置与缩放（`item_rect` 乘上 pose），抓到就 `_landing.erase(uid)`（动画停在被抓那一刻，拖拽层接手）。排队还没出现的（`hidden`）照旧不接。
- 双击同理（双击 = 抓两下）。
- 测试直接调 `advance_landing(0.1)` 后 `uid_at_local(半空中的位置)` 能命中。

### 2.4 测试

- `test_inventory_service`：待拾取 [件 A、件 B、皮革包]，棋盘上只有一个包且件 A 放不下 → 先塞包，包进了之后 A、B 都进；包放不下时包落地、件各自试；带东西的包：空包先进、内容物按序进原包。
- `test_ground_layer`：全部拾取后落地那件的起点 = 它在战利品视图里的格子；拖出棋盘的起点 = 原格；半空中可抓且抓了动画停。
- `test_node_screens`：「全部拾取」件数与落地件数在新顺序下的期望值。

## 3. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 手动拖出的起点 | A 从棋盘原格飞到放手点（「同理」）；B 保持就地（只弹跳） | **A** |
| 2 | 半空中被抓后 | A 动画停、拖拽层接手；B 先飞完再接 | **A**：作者原话 |
| 3 | 一串落下的错开（134 的 stagger） | A 保留；B 全部同时起飞 | **A** |

## 4. 改动范围

| 文件 | 改什么 |
|---|---|
| `core/inventory/inventory_service.gd`（`_take_order`、`_transfer_bag`） | 2.1 |
| `ui/game/container_screen.gd`（`take_all`）、`ui/inventory/drag_layer.gd`（拖出的起点） | 2.2 |
| `ui/inventory/ground_layer.gd`（`uid_at_local`、`item_rect` 按 pose） | 2.3 |
| `tests/inventory/test_inventory_service.gd`、`tests/ui/test_ground_layer.gd`、`tests/ui/test_node_screens.gd` | 2.4 |
| `docs/architecture.md` 3.4（地上）、6.1（战利品）那两段 | |
