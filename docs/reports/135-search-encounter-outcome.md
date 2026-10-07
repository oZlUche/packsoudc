# 135 方案：搜索点遭遇战的胜负结果 —— 打输不扣体力、这个点不能再搜（改文案）；打赢先拿战利品再接着搜

- 日期：2026-10-07
- 提出：作者（架构设计线程）
- 性质：架构 · 提议（本线程只写方案，不实现、不跑测试）
- 作者原话：「将搜索节点的遭遇战结果改成：战败后不掉体力值，但无法搜取（修改文案），战胜后可以搜索战利品然后再继续搜取」

## 一、先说结论：机制已经是这样，差的是文案和一处死配置

查过现行代码（`core/run/node_events.gd`、`core/run/search_session.gd`、`data/authoring/events/search_*.json`、百科与教程文本），作者要的两条规则**都已经在仓库里**：

| 作者要的 | 现状 | 出处 |
|---|---|---|
| 打输不扣体力 | 已是。搜索里遭遇的那一场进战斗时显式传 `loss_cost = 0`，`_fight` 里 `cost == 0` 一分不扣、一局也不结束 | `node_events.gd:361/364/760/763`，`_fight` 的 else 分支；091 第十四节作者拍板，`tests/run/test_author_091.gd` 第 26 行起有用例 |
| 打输这个点不能再搜 | 已是。`_after_battle("search", won=false)`：收掉会话、之前翻到的收获交给「待拾取」、点标成用过、再弹「余波」事件 | `node_events.gd:452-470`，事件 `search_destroyed.json` |
| 打赢先拿战利品再接着搜 | 已是，而且 2026-10-07 刚修过一轮：打赢 → 回放 → 战利品屏 → 回到「再搜 / 走」；没拿完的战利品并进搜索收获箱、亮过的不重亮 | `_after_battle` 的 `won` 分支 → `session.resume()`；#61 `RunState.fold_loot_into_search` |

所以**作者看到的「掉体力」极可能来自两处过时文案**，而不是机制：

1. 教程事件 `tut_search_2.json` 第三段：「打输了会扣体力，体力归零这一局就结束了。」—— 这是 091 之前的规则，没跟着改。
2. 「余波」事件 `search_destroyed.json`：「打斗把这里翻了个底朝天，能翻的都毁了，没法再搜。**对方留下的东西倒还在。**」—— 这屏只在**打输**之后出现（打赢走的是另一条路），输了根本没有「对方留下的东西」，读起来像是打赢了。标题「余波」也没说清是「输了所以不能搜」。

另外一处**死配置**：`NodeRules.loss_cost.search = 1`（`core/run/node_rules.gd:24`、`data/authoring/node_rules/standard.json`）。搜索遭遇进战斗时永远显式传 0，这个表项谁也读不到，却让编辑者以为「搜索点输了扣 1」。

> 作者本地若还是旧版本，看到的流程也可能和上表不同：#61（战利品并进收获箱）是今天刚合的，先在「本地仓库同步」说一声「同步」再试一遍。

## 二、要改的（全是文案与配置，无逻辑改动）

### 1. 「余波」事件改成「被赶跑」

`data/authoring/events/search_destroyed.json`（id 不改，`SearchRules.destroyed_event` 还指着它）：

| 字段 | 现在 | 改成 |
|---|---|---|
| title | 余波 | 被赶跑了 |
| text | 打斗把这里翻了个底朝天，能翻的都毁了，没法再搜。对方留下的东西倒还在。 | 被打退了。对方守在那儿，这里不能再翻了。之前翻到的还在，走的时候带上。 |
| options[0].label | 继续 | 离开 |

「之前翻到的还在」对应现行行为：输了之后 `search_closed` 把会话里的收获交给待拾取（`run_state.gd:946 _offer_loot(haul)`），玩家照样能拿。若作者想改成「输了连之前翻到的也丢」，见第四节待定 1。

### 2. 教程文本 `tut_search_2.json`

第三段「打输了会扣体力，体力归零这一局就结束了。」改成：「打输了不扣体力，但这个点就不能再翻了。」

同步检查 `tut_search_2_encounter.json`、`tut2_search_2.json`、`tut3_search.json` 是否也提到扣体力（grep 结果：只有 `tut_search_2.json` 这一处）。

### 3. 百科 `help_pages/search_point.json`

第二段「打输了这个点被余波摧毁、不能再搜，但这一场不扣体力。敌人的战利品和之前没拿的收获并成一份。」改成：
「打赢了先拿对方的战利品，没拿完的并进这个点的收获箱，然后接着搜；打输了不扣体力，但这个点不能再搜，之前翻到的还能带走。」
（后半句同时把 #61 的新行为写进百科 —— 原句「并成一份」已经不准。）

`help_pages/battle_and_prebattle.json` 末段「打输了扣体力，输赢都算用过这个点」后面补一句：「搜索中遭遇的那一场例外：打输不扣体力，打赢了还能接着搜。」

### 4. 战前准备屏的类型名

`ui/game/prebattle_screen.gd:125` 搜索遭遇显示「搜索中遭遇」。建议改成「搜索中遭遇（输了不扣体力）」，让玩家在开战前就知道这场的代价 —— 这是作者「修改文案」里最有用的一处，因为现在没有任何界面在开战前告诉玩家这一点。若战前屏已有单独的「战败代价」读数（没查到），则改那一行即可。

### 5. 去掉死配置

- `core/run/node_rules.gd:24` 的 `loss_cost` 默认表去掉 `"search": 1`；
- `data/authoring/node_rules/standard.json` 同步去掉；
- `NodeRules.loss_cost_of(&"search")` 之后返回 0，和实际行为一致；`loss_cost_for` 的注释（`node_events.gd:47-48`）加一句「搜索遭遇固定 0，不看表」。
- 编辑器里若 `loss_cost` 的键是从固定列表选的，把 `search` 从列表里拿掉（查 `ui/editor` 里 `loss_cost` 的出处）。

### 6. 地图侧栏的日志

`ui/game/map_screen.gd:478` 搜索结束的日志直接打印 reason 的英文（「搜索结束（encounter）」）。改成按 reason 映射：`encounter` → 「被赶跑，这个点不能再搜」、`exhausted` → 「搜完了」、其他 → 「离开」。小事，顺手。

## 三、不改的

- 胜负逻辑、`loss_cost = 0` 的传法、`fold_loot_into_search`、存档里的 `pending_battle.loss_cost`（审查 B1）全部不动。
- 打输之后这个点标成用过（`_visited`）不动 —— 这就是「无法搜取」。
- 事件 id `search_destroyed`、`SearchRules.destroyed_event` 字段名不改（改名要动存档与地图规则 JSON，不值）。

## 四、待定（都按推荐做）

1. **打输之后之前翻到的收获留不留。** 推荐：**留**（现状）。理由：091 作者拍板时是「不扣体力」，惩罚只有「不能再搜」；再把已经亮过的收获收走，等于又加一层惩罚，而且收获箱里的东西玩家已经看见、可能已经拖进包了，只收没拖的会显得随机。若作者要更狠的版本，改法是 `_after_battle` 输的分支不 emit `search_closed` 的 haul（传空容器），一行。
2. **「被赶跑」屏要不要给一个「再打一次」选项。** 推荐：**不给**。战斗点的规矩是「输赢都算用过、没有再打一次」（百科原话），搜索点跟着走。
3. **战前准备屏的类型名加不加「输了不扣体力」。** 推荐：**加**（第二节第 4 条）。

## 五、测试

- `tests/run/test_author_091.gd` 已覆盖机制（输不扣体力、点用过、赢接着搜），不动。
- 新加一条文本断言放进同一文件：加载 `search_destroyed` 事件，断言 text 不含「对方留下」；加载 `tut_search_2`，断言不含「扣体力」；`NodeRules.new().loss_cost_of(&"search") == 0`。防止以后改文案时又回退。

## 六、给执行线程的清单

1. 改 `search_destroyed.json` / `tut_search_2.json` / `help_pages/search_point.json` / `help_pages/battle_and_prebattle.json` 文案（第二节 1～3）；
2. `prebattle_screen.gd` 搜索遭遇的类型名（第二节 4）；
3. `node_rules.gd` + `standard.json` 去掉 `search` 的 loss_cost，注释与编辑器列表跟着（第二节 5）；
4. `map_screen.gd` 搜索结束日志按 reason 映射（第二节 6）；
5. 第五节的文本断言；
6. 百科页若有多语言字典（`text` 可能是语言表），每种语言都改。
