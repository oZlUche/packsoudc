# 047 · M4-3 随机点与搜索点、M4-4 节点事件接线

> 阶段 5 · M4 ｜ 架构文档 5.4、5.6、6.2、6.5、7.1（v1.46）｜ 规划见[报告 045](045-m4-plan-and-enemy-pool.md)

M4 的后两步一起做完：踩到每种点发生什么，现在有人接了。数值一个都不写死，全在 `NodeRules` 里。

## 产出

| 文件 | 职责 |
|---|---|
| `core/run/node_rules.gd` | `NodeRules`：随机点变什么（权重）、搜索规则、战斗输了扣多少、休息回多少、常规事件的结果权重、战斗时限。章节按 id 引用 |
| `core/run/search_rules.gd` | `SearchRules`：至多搜几次、遭遇曲线（按次数，非递减）、每次找几件、稀有度权重及其随深度 / 危险的上偏、排除标签、容器大小 |
| `core/run/search_session.gd` | `SearchSession`：在一个搜索点上搜 —— 搜几次是玩家的旋钮，遭遇即止，进度记进节点内容 |
| `core/run/node_events.gd` | `NodeEvents`：`MapTravel.on_node_event` 的真正接收方。战斗 / 精英 / 核心打一场并结算，搜索开会话，随机先揭开，休息回体力，商店 / 撤离发信号，事件按权重出结果 |
| `core/loot/loot_packer.gd` | 把一堆道具 id 摆进一块棋盘（尸体容器、搜索收获共用；`DropResolver.corpse_of` 改用它） |
| `core/enemies/enemy_placer.gd` | 抽出 `place_one`：生成时 `fill` 逐点调它，随机点揭成战斗、搜索点遭遇时 `NodeEvents` 现调它 |
| `core/run/chapter_def.gd` | 加 `node_rules: StringName` |
| 内容管线 | 新种类 `node_rules`；`import_node_rules` + 校验；导出、命令行导入、normalize 各一分支 |
| `data/authoring/node_rules/standard.json` → `data/node_rules/standard.tres` | 第一章的规则（占位数值）；`chapter_01` 引用 |
| `ui/map/map_sandbox.gd` | 接上 `NodeEvents`：打了什么、掉了什么、搜到什么全进日志；搜索点多一行「搜一次 / 离开」；随机点揭开时报一句 |
| `tests/test_node_rules.gd`、`test_search_session.gd`、`test_node_events.gd` | 4 + 2 + 6 组 |

## 随机点（5.4）

`?` 生成时内容是空的 —— 5.10 说它是地图上唯一看不透的点。踩上去 `NodeEvents.reveal` 按 `random_weights`
抽一种类型记进 `content.resolved_type`，再当那种类型处理；是战斗就用 `EnemyPlacer.place_one` 现造敌人。
导入器只认 `battle / search / shop / rest / event` 五个键：**不会变成精英或 BOSS**（作者的表就是这么写的）。
随机数由节点的 `content_seed` 派生：同一局同一个点，揭开的永远一样，只是玩家事先看不见。

## 搜索点（6.2）

作者原话：「可以搜索至多 N 次找战利品，每搜一次遭遇敌人的概率上升；随时可以离开」。

- `max_searches` 次；第 k 次的遭遇概率是 `encounter_curve[k]`（导入器要求非递减：每搜一次该更险）。
- 每次找 `items_per_search` 件，候选是不带排除标签（默认 `treasure`：珍宝只从敌人身上掉）、不是包的道具，
  按稀有度权重抽，权重 × (1 + depth_gain × 深度 × 稀有度) × (1 + danger_gain × 危险 × 稀有度) —— 越深、越危险，越稀有。
- 遭遇的敌人**看不见**：掷中那一刻才由敌人池按 `search` 类型出人（条目的 `node_types` 过滤照样管用），
  打完这一场搜索到此为止。第一版定的是「遭遇即止」；要改成打赢了还能接着搜，改 `SearchSession.search` 一处。
- 随时 `leave()`。搜过几次记进 `node.content["searches"]`，读档接着搜剩下的次数。
- 收获摆进 `LootPacker` 的容器（6.1 同一套）。

## 节点事件（6.5，原 5.6 的钩子）

`NodeEvents.bind(travel)` 把自己挂成 `on_node_event`。每种结果一个信号，界面与转场（M6）只管接。

| 踩到 | 发生 | 数从哪来 |
|---|---|---|
| battle / elite / core | `BattleSim` 打一场（玩家单位由 `player_spec` 那一刻编译）。赢：`DropResolver` 掷、装尸体容器、`loot_ready`；输：扣体力、`defeated` 看归零；core 输了直接 `defeated(boss_lost)`，不扣。**不论输赢点都用过**（7.1） | `loss_cost[类型]`、`battle_time_limit` |
| search | 开 `SearchSession`；结束（搜满 / 离开 / 遭遇）时 `search_closed(haul)`，遭遇先就地打一场；结束才算用过 | `search` |
| random | 先 `reveal`，再按揭开的类型走 | `random_weights` |
| rest | `vitality.restore` | `rest_restore` |
| event | 按权重出 item / restore / story（占位），记进 `content.outcome` | `event_weights`、`event_restore`、`event_item_rarity_cap` |
| shop / extract | 只发信号（买卖、撤离是 M6 的事） | — |
| junction / spawn | 只标用过 | — |

平局按输算：打不死也没打过。没有玩家单位、或点里没有敌人（这一章没有敌人池）：点只是走过。

## 关键决策

- **规则是数据。** 7.1 早就说体力不知道任何数值；现在「输一场扣多少」「歇一会儿回多少」「随机点变什么」在 `NodeRules` 里，
  校验把作者的规矩写死在导入器里（随机点不变精英、core 不配扣体力、遭遇曲线不递减）。
- **`NodeEvents` 只接逻辑，不画。** 每种结果一个信号，沙盒接了就能看；M6 换成真界面时逻辑一行不改。
- **随机数从节点种子派生**，每种用途一个标签（reveal / enemy / battle / loot / search / ambush:k / event）：
  同一局同一个点结果一样，改动一种用途的抽法不影响别的。
- **`place_one` 抽出来**，生成时与踩上去时走同一段挑人与组装 —— 随机点揭成的战斗、搜索点的遭遇，和地图上看得见的敌人是同一套档位与过滤。
- **搜索点的敌人不预先造。** 5.10 说搜索的风险在于看不见；预先造了存进内容里，存档一看就知道 —— 所以到遭遇那一刻才造。

## 验证

```
bash tools/test.sh
通过  5862 项断言，36 个套件，耗时 244 秒（机器上还开着两个 Godot 编辑器；新套件单独跑 3 秒）
```

沙盒的帧测试跟着改了一处：踩到搜索点时点还没用过，得先离开。

- 节点规则：往返逐字节相同；随机点配精英、core 配扣体力、遭遇曲线递减或 > 1、没有搜索规则、认不得的事件结果、负回复、打错字段名 → 全错；
  仓库文件导得进、是导出器格式、资产一致；第一章引用得到、指向不存在的规则 → 错；两千次抽样各类型占比与权重差在 5 个百分点内、只出现表里的类型、权重全 0 退回 battle。
- 搜索：候选不带排除标签、不是包、稀有度上限收窄；五十次件数都在范围内；最内的平均稀有度高于最外；同种子同结果；
  搜满即止、每次发 `searched`、进度记进内容、读档只剩剩下的次数、随时走且不重复发；曲线全 1 第一次就遭遇即止、全 0 永不遭遇、0.3 一千次落在 240～360；收获全在容器里。
- 节点事件：一万血两把枪赢了 → 有掉落、全是敌人背的、不扣体力、用过的点不再打；一血空手输了 → 扣 `loss_cost.battle`、精英扣 `loss_cost.elite`、点照样变空白；
  core 输了 → `boss_lost` 且不扣；只剩一格输一场 → `vitality_depleted`；同种子同结果。休息回规则里的数（封顶）、商店 / 撤离发信号、岔路口只标用过。
  十二个种子的事件结果都在清单里、restore 回 `event_restore`、item 给至多一件且稀有度不超上限。十六个随机点变出至少三种、变成的就是规则按种子抽的、
  是战斗就现造敌人并打了、再揭一次不变。搜索点：开会话、搜满或遭遇结束、遭遇就地打、收获在容器里、结束才用过、随时走；曲线拉满第一次就遭遇。
  没有玩家 / 点里没敌人 → 只是走过。

## 没做的

- 界面：搜索是两个按钮和日志，尸体容器与收获没有画出来（6.2 的渐进揭示是表现层，M6）。
- 商店里卖什么、撤离动作、真正的玩家棋盘（沙盒用一块固定棋盘）：M5 / M6。
- 「遭遇后打赢了能不能接着搜」现在是不能；作者定了再改。
- 常规事件只有三种占位结果；剧情、多选项事件是内容工作。
