# 056 · M6-2 搜刮界面：渐进揭示、拖到棋盘、搜索点逐次装

> 阶段 6 · M6 ｜ 架构文档 6.2、8.3（v1.53）｜ 前一步：[055 M6 规划与 M6-1](055-m6-plan-and-scene-flow-skeleton.md)

6.2 写的是「看得见轮廓、看不清是什么」：每件先是剪影，进界面后一件一件亮出来，快速搜索一键推到底。M6-1 的战利品屏只有「全部拾取 / 不要了」，这一步把它做成 6.2 的样子，
搜索点也用同一套。

## 产出

| 文件 | 职责 |
|---|---|
| `ui/game/loot_view.gd` | `LootView`：`InventoryView` 的子类。uid → 已揭示的表；没亮的画剪影 + 噪点 + 「?」，抓不起来；`start_reveal()` 一个 Tween 按栏位顺序亮一批；`skip()`、`reveal_all()`、`mark_revealed()` |
| `ui/game/loot_screen.gd` | 战利品屏重写：左边 `LootView`，右边自己的棋盘与暂存区（`inventory_panel`），一层 `DragLayer` 盖三个容器；快速搜索 / 全部拾取 / 离开（剩下的不要了）；都拖走了自己关 |
| `ui/game/search_screen.gd` | 搜索屏重写：同一套布局，容器是会话的 `haul_box`；搜一次 → 新来的走时间线；遭遇 → 会话结束、流程放回放 |
| `ui/game/inventory_panel.gd` | `setup(run, font, drag)`：给了拖拽层就登记进去，不给自己造；`board_view` / `storage_view` 公开 |
| `core/run/search_session.gd` | `haul_box` 逐次装：每搜一次 `LootPacker.add` 一批；`haul()` 就是它；`haul_changed` 信号 |
| `core/loot/loot_packer.gd` | `add(board, ids, items, base_height)`：往已有容器里再摆；放不下换高一格的、东西原位搬过去（uid 不变）、至多两倍；装不下的报回来 |
| `core/run/game_flow.gd` | `seen_loot`：搜索屏里亮过的 uid，战利品屏不再重揭；拾取完清空 |
| `ui/game/game_director.gd` | 截图钩子多 `loot` / `search` 两屏 |
| `tests/test_search_session.gd` | `run_haul_box`：逐次装、拿走一件、换高的容器 uid 不变、`LootPacker.add` 加到两倍就停 |
| `tests/test_game_flow.gd` | `run_seen_loot`、`frame_loot_view`（没亮的抓不起来、栏位顺序、快速搜索、见过的不重揭、空容器直接算完）、导演的战利品屏先是剪影 |

## 几条决定

**揭没揭示是表现层的事。** 6.2 草稿写「每件物品有 `revealed: bool`」，做的时候没放进 `ItemInstance`：容器里的东西一开始就在那儿，
揭不揭示对任何系统都一样 —— 放进数据层只会让存档、掉落、结算都多背一个与它们无关的字段。`LootView` 自己记一张 uid → 已揭示的表。
唯一跨屏的状态（搜索屏里亮过的到了战利品屏不重揭）在 `GameFlow.seen_loot`，拾取完清空。

**噪点不用 shader。** 6.2 建议 `ShaderMaterial` 的 dissolve；现在是 `draw_rect` 撒一把按 uid 定死的小点，不闪、不用材质、截图里看得出是剪影。
接正式美术时再换成 shader，视图的接口不变。

**搜索点逐次装。** 原来 `haul()` 在结束时才把 `found` 一次打包；界面要一边搜一边亮、亮了就能拿走，容器得一直在。
`SearchSession` 现在开着就有一个 `haul_box`，每搜一次 `LootPacker.add` 一批；放不下就换一个高一格的容器（最多两倍，和 `pack` 同一条规矩），
原来的东西原位搬过去、uid 不变，`haul_changed` 让视图重绑。`haul()` 就是这个容器，拿走的不再算收获；`found` 仍记着找到过的全部。

**拿走 = 拖走。** 战利品屏与搜索屏都不再有「拿一件」的按钮：`DragLayer` 盖着容器、棋盘、暂存区三块，亮出来的直接拖过去，M1 的顶替、旋转、脱落全都在。
「全部拾取」保留（全亮、全进暂存区），「离开」= 剩下的不要了；都拖走了屏自己关。

**一层拖拽盖整屏。** `DragLayer` 按各视图的**全局矩形**找落点、拿本控件的鼠标坐标画残影，所以它得铺满整屏；`inventory_panel` 因此多了一个参数：
给了拖拽层就往里登记，不给才自己造一层。

## 验证

```
bash tools/test.sh
通过  6590 项断言，39 个套件，耗时 77 秒
```

- 搜索会话：开着就有空容器、大小按规则；搜一次找到的都在容器里、再搜累计；拿走一件 `haul()` 少一件而 `found` 照旧；
  三件放不进 2×1 换了更高的容器（至多两倍）、`haul_changed` 报的是现在的容器、第二次搜之后第一次的 uid 还在；`LootPacker.add` 2×1 加到 2×2 就停、装不下的两件报回来。
- 揭示：一开始一件都没亮、没亮的抓不起来；启动后时间线在跑；快速搜索全亮、每件发一次 `item_revealed`、一次 `reveal_finished`、顺序是栏位顺序；亮了就能抓；
  标了见过的不走时间线；空容器直接算完。
- 流程：搜着的时候 flow 什么都没记；离开后战利品屏里记下的 uid 都在待拾取里、件数对；拾取完清空。导演：战利品屏一开始是剪影，快速搜索全亮。
- 截图（`DEMO_SCREEN=loot` / `search`）：战利品屏两件剪影带噪点和「?」；搜索屏搜过一次、两件亮着，右边是棋盘与暂存区。

## 没做的

- 揭示顺序只有栏位顺序；6.2 提的「按距光标距离」没做。
- 单件间隔是常量占位，角色「搜索速度」等角色系统。
- 撤离确认与遗落提示、仓库里的东西带进下一局：M6-3。
