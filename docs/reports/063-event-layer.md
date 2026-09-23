# 063 · 事件层：每个点先过事件屏、选项的条件与后果构件、容器屏合一

> 058 / 059 顺序里的第 4 项 ｜ 架构文档 6.5、8、10.1、11（v1.61）｜ 前一步：[062 buff 骨架](062-run-buffs-skeleton.md)

作者定的（059 第 1 / 2 条与第六节）：所有节点打开后都先跳转事件界面，没有前置剧情的战斗点略过（转场）；搜索点和标准事件点配有文字、图像、选项，
选项决定后续；搜索和战利品是同一个界面，「要不要搜」是事件；事件在生成地图时定好、可被覆盖替换；战斗事件暂无绕开的选项但结构开放。

## 产出

| 文件 | 职责 |
|---|---|
| `core/run/events/event_def.gd`、`event_option.gd` | `EventDef`：标题、正文、图像路径（占位）、选项；`EventOption`：字、条件、后果、锁住时藏不藏。新内容种类 `events` |
| `core/run/events/event_condition.gd`、`event_outcome.gd`、`event_context.gd` | 条件（只读）与后果（做一件事或立旗）的抽象基类；上下文：体力、钱、道具库、规则、深度、地图 buff 的四个回调、旗子、账 |
| `core/run/events/conditions/`（4 个）、`outcomes/`（12 个） | 构件，登记在 `EffectRegistry.EVENT_CONDITIONS` / `EVENT_OUTCOMES`；`ContentSchema.ABSTRACT_ROOTS` 认得两个基类 |
| `core/run/events/event_placer.gd` | 生成时按 `NodeRules.events_by_type` 与 `content_seed` 把事件写进 `node.content["event"]`；已有的不覆盖；`load_all` |
| `core/run/node_rules.gd` | `events_by_type`（类型 → {id: 权重}）、`event_pick_for`；导入器对着事件表校验 |
| `core/run/node_events.gd` | `handle` 变两段：有事件先 `pending` + `event_pending`；`choose(i)` 执行后果、按旗子走；`option_state`、`pending_event` / `pending_node`；随机点揭开后再配；**定义表空 = 老路** |
| `core/run/run_state.gd` | `event_defs`（持有方给，赋值就转给 NodeEvents）；开局 `EventPlacer.fill`；地图 buff 的回调接给 NodeEvents；`pending` 跟着存档 |
| `core/run/game_flow.gd` | `event_pending` 排队；`event_resolved` 有内容时结果页插队首；`choose_event(i)`；队列空了还有等着选的就显示；读档回来 `_flush` |
| `ui/game/event_screen.gd` | 选项页（标题、图像占位、正文、选项按钮，锁住的灰掉写原因）与结果页（做了什么、继续）；`proceed` 选第一个能选的 |
| `ui/game/container_screen.gd` | 战利品屏与搜索屏合一：装待拾取或搜索会话，会话就多「再搜一次」和风险行；`loot_screen` / `search_screen` 删了 |
| `data/authoring/events/`（6 个）、`node_rules/standard.json` | 搜索点默认事件（搜索 / 离开）、上锁的箱子、陌生人（给 10 币得标记）、熟面孔（有标记才开的选项）、歇脚处、动静（开战 / 绕开得虚弱）；节点规则配上 |
| `tests/test_event_layer.gd` | 5 组 |

## 几条决定

**没有事件定义就是老路。** 事件层改的是所有节点的处理路径，059 说过风险在这里。做法：`NodeEvents.event_defs` 空表时 `_event_for` 一律返回 null，
每个点踩上去直接发生 —— 和 062 之前完全一样。持有方（`GameFlow` / 导演）装了定义表才有事件层。于是现有 43 个套件里 42 个一条没改：
沙盒、合成图的 `test_node_events`、`test_run_state`、走到撤离点的那几条，都在老路上跑；事件层自己一个套件 5 组。

**事件是内容，条件与后果是构件。** 和效果树同一种做法：两个抽象基类、两张注册表，`ContentSchema` 认得基类就能按 JSON 里的 `type` 造。
加一种条件或后果 = 一个子类、登记一行；导入器不改。现在 4 种条件（标记、地图 buff、钱、体力）、12 种后果（给指定 / 随机道具、回 / 扣体力、钱、给 / 去 buff、开战、开搜索、开店、接下一个、说一句）。

**生成时定进节点，取的时候先看内容。** `EventPlacer.fill` 在开局时按 `content_seed` 抽、写进 `node.content["event"]`，已有的不覆盖 —— 作者数据、预设、别的系统替换过的都算数；
`NodeEvents` 取事件先看内容里的，没有再按表抽，所以旧存档没这个键也照样走。随机点生成时没法配（不知道会揭成什么），揭开时按揭成的类型再抽。

**踩上去分两段，旗子决定后续。** 后果不直接开战、开搜索 —— 它们在上下文里立旗（`start_battle` / `open_search` / `open_shop` / `next_event`），
`choose` 执行完全部后果再按旗子走现在的 `_fight` / `_open_search` / `_open_shop`：老路的代码一行没动。「接下一个」再发一次 `event_pending`，点要到最后一个选完才算用过。
战斗事件里现在没有「绕开」的选项（作者：初始想法不能绕开）；结构上任何类型的事件都可以带任何选项，以后加就是加一行 JSON。

**结果页插队首。** 选了之后如果后果做了什么（给了东西、回了体力、给了 buff、说了话），`GameFlow` 把结果页插到队列最前面：先看「你翻出了什么」，
再看接下来打的那一场；什么都没发生就不打扰，直接往下。搜索点选「搜索」进容器屏，容器屏就是 M6-2 的战利品屏加一个「再搜一次」。

**内容里的搜索点默认事件只有两项。** 「搜索 / 离开」，作者之后给具体的搜索点配别的文字和第三个选项就是加一份 JSON、在 `events_by_type` 里换个 id。

## 验证

```
bash tools/test.sh
通过  7001 项断言，43 个套件，耗时 84 秒
```

- 管线：带条件与后果的事件往返逐字节相同；没有选项、给不存在的道具、给局外 buff、选项没字都报错；六个作者文件是不动点、资产在、`load_all` 全装回；
  节点规则里引用的事件都存在，引用不存在的报错。
- 铺放：搜索点配了 `search_default`、事件点配的在表里、战斗 / 休息 / 商店 / 撤离 / 随机点没配（转场）；同种子同事件；替换过的不被铺回去；随机点揭开后按揭成的类型抽。
- 两段：走上搜索点先发 `event_pending`、还没搜也没用过、两个选项都能选、没有的选不了；「离开」点用过了没开会话、`detail` 空、选过了再选不了；「搜索」开了会话。
  自定义事件各一局：给两个医疗包进暂存区、体力 +1、点用过；给标记；没标记「认出」锁住并说原因、太贵锁住、付 10 按钱够不够并真扣钱；有标记能认出且标记用掉；
  接下一个（两次 `event_pending`、第二个没选完点不算用过、选完才用过）；开战打了一场；等着选的跟着存档、读回来能选。
- 流程：踩上去 → 事件屏带着定义；「离开」直接回地图；「搜索」→ 容器屏带着会话、离开后回地图；做了事的先看结果页（带着回了 1 点体力和那句话）再回地图；
  在事件屏上存档、读回来还在事件屏、还是那个事件。
- 导演：事件屏叠在地图上（选项页）、地图还在底下；`proceed` 选了「搜索」→ 容器屏（搜索会话）；离开看完回地图。
- 截图（`DEMO_SCREEN=event` / `search`）：搜索点的事件屏（标题、图像占位、正文、两个选项）；选「搜索」之后的容器屏。

## 没做的

- 事件的图像：路径占位，有文件就画，没有就一块底色。
- 商店、休息点还没配事件（表里没列 = 转场），也没有背包按钮（060 说过要加）。
- 地图沙盒仍在老路上（不装事件定义）。
- 常规事件的六份内容是占位文字，等作者写。
