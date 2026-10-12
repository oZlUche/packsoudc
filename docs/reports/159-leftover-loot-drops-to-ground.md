# 方案：离开时没拿的战利品落到地上，不再消失（159）

> 作者原话（2026-10-12，架构设计）：「我希望不论是搜索点还是战利品环节，玩家没拿的东西在离开时默认丢到地上。这点我感觉以前提过，是所有地图都没有，还是序章独有的bug？」
> 性质：架构 · 实施。待定按推荐。

## 1. 现状：所有地图都一样，是 084 定的规则，不是序章的 bug

- 084 定的循环：战利品屏 / 搜索屏「收起」只是回地图，没拿的留在这个点上，「回到这个点」能再开；**走了才没** —— `RunState.step_to` → `_abandon_sessions()` → `_drop_pending_loot()` → `discard_loot()`，待拾取容器整个丢掉；搜索会话 `leave()` 时收获箱里没拿的也交到待拾取、随后一起丢。
- 地上（`RunState.storage`）是另一回事：地上的东西**跟着点走**（走了留在点上，回来「留在这里的 N 件回到了地上」），不会消失。
- 序章的两个提醒事件（`tut_search_1_done`、`tut2_search_1_done`）是**序章地图内容里配的教程事件**（`node.content.search_done_event`），讲的正是「地上的会留在这个点上、撤离不带走」；普通地图没配这些事件，所以不弹。节点性质没有不同。

## 2. 改法：丢掉 → 落到地上

把 `_drop_pending_loot()` 的「丢掉」改成「倒到地上」：

- `RunState._drop_pending_loot()`：`pending_loot` 里每件 `storage.admit(inst)`（和 `fold_loot_into_search` 收尾那段同一个写法），然后 `pending_loot = null`、`loot_cleared.emit()`。包也倒（包里的东西先倒出来，空包再倒，和 `fold_loot_into_search` 一致）。
- 搜索会话：`SearchSession.leave()` 现在把没拿的交到待拾取 → 同一条路落地。遭遇那一次（`&"encounter"` 结束）照旧：那一次什么都翻不到。
- 「走了」的三个时机不变：走开（`step_to`）、撤离、失败都走 `_abandon_sessions()`。撤离与失败时倒到地上也没意义但无害 —— 结算屏本来就按「地上不带出」算（092 的一键出售按地上剩的算，倒进去的也一并卖掉，这正好是作者要的「没拿的默认当地上」）。
- 地上的东西跟着点：倒进去之后和原来地上的东西一样，走了留在这个点、回来再拿。
- 文案：战利品屏「收起」的提示「剩下的留在这里，走了就没（Esc）」改成「剩下的留在这里；走了会落到这个点的地上」；序章两条提醒事件的正文里「撤离不带走」保留、「走了就丢在这里」改成「走了会留在这个点的地上」（`tut_search_2_again_2`）。
- `discard_loot()` 保留给 BOSS 战利品屏的「收起 = 直接撤离」那条路（那里是明确不要了）。

## 3. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 搜索点没亮出来（没揭示）的那几件 | A 也落地（既然已经生成了）；B 只落亮出来的，没亮的算没搜到 | **B**：没揭示 = 玩家不知道有，落地等于白送；而且下次「回到这个点」再搜还能亮它 |
| 2 | 落地时地上放不下（地上是无限容器？） | 地上 `storage` 现在不限格 → 不存在 | — |

## 4. 改动范围

| 文件 | 改什么 |
|---|---|
| `core/run/run_state.gd`（`_drop_pending_loot`） | 2 节 |
| `core/run/search_session.gd`（`leave()` 只交亮出来的，待定 1 按 B） | |
| `ui/game/container_screen.gd`（提示文案）、`data/authoring/events/tut_search_2_again_2.json` 等三条教程事件文案 | |
| `tests/run/test_loot_*`：走开后待拾取的件数 = 地上增加的件数；BOSS 收起仍丢；搜索未揭示的不落地 | |
| `docs/architecture.md` 6.2 / 084 那段 | |

## 落地记录（2026-10-12）

待定 1 按推荐 B（搜索没亮的不落）。

- `RunState._drop_pending_loot(skip)`：待拾取倒进地上（包先倒空再放空包，和 `fold_loot_into_search` 一样）；`skip` 里的 uid 不落。
- 「没亮过」在核心里没有：揭示是界面的事，记在 `GameFlow.seen_loot`。`RunState.loot_seen: Callable` 由 `GameFlow._adopt` 接上；`_abandon_sessions` 在**关会话之前**先记下开着的搜索收获箱里没亮过的（关的时候收获箱整箱交出去、`GameFlow` 会把它们都记成见过）。没接（纯核心）= 都算亮过。
- 战利品屏「收起」的提示改成「剩下的留在这里；走了会落到这个点的地上（Esc）」；序章教程只有 `tut_search_2_again_2` 一条说了「走的时候会丢在这里」，改成「走了会留在这个点的地上（回来还能拿，撤离不带走）」；另两条（`tut_search_1_done`、`tut2_search_1_done`）本来就是「留在这个点上」，不用改。
- `discard_loot()` 照旧留给 BOSS 收起与拿空关屏。
- 测试：`tests/run/test_loot_drop_159.gd`（走开后原来那个点的地上 = 原有 + 落下的件数；skip 的不落；开着的搜索只记没亮过的、没接 = 都算亮过；`discard_loot` 不落地）。
