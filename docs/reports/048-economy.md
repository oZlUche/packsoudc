# 048 · M4-5 经济：战斗奖励、商店、付费撤离点

> 阶段 5 · M4 ｜ 架构文档 6.6（v1.47）｜ 规划见[报告 045](045-m4-plan-and-enemy-pool.md)

作者的设想原话：

> 玩家打赢战斗后同样会获得一定货币，数量根据敌人的强度和所在深度，以及不同难度，商店售卖随机稀有度道具且可以刷新，
> 都需要消耗货币，另外，将一个中途撤离点设置为付费的，具体费用暂时用 50 占位。

## 产出

| 文件 | 职责 |
|---|---|
| `core/run/economy_rules.gd` | `EconomyRules`：开局多少钱；打赢 = (基础 + 每档 × 档位) × (1 + 深度增益 × 深度) × (1 + 难度增益 × 难度)；商店格数、稀有度权重及其随深度上偏、售价倍数、排除标签、刷新费与涨幅；付费撤离点几个、收多少。章节按 id 引用 |
| `core/run/wallet.gd` | `Wallet`：进账、花钱、够不够、信号、存档。不知道任何数值 |
| `core/run/shop_session.gd` | `ShopSession`：货架、买、刷新、走；货架由节点种子 + 刷新次数决定 |
| `core/run/paid_extracts.gd` | `PaidExtracts.mark`：生成之后把最深的几个撤离点标成付费；`fee_of` |
| `core/run/node_events.gd` | 打赢进账（`rewarded`）；商店开会话（`shop_opened(node, session)` / `shop_closed`），走了才算用过；`extract_reached(node, fee)`；`extract_fee` / `pay_extract_fee` 给 M6 的撤离动作用 |
| `core/run/chapter_def.gd` | 加 `economy_rules: StringName` |
| 内容管线 | 新种类 `economy_rules`；`import_economy_rules` + 校验；导出、命令行导入、normalize 各一分支 |
| `data/authoring/economy_rules/standard.json` → `data/economy_rules/standard.tres` | 第一章的规则（占位数值，撤离费 50）；`chapter_01` 引用 |
| `ui/map/map_sandbox.gd` | HUD 多「货币」；生成后报哪个撤离点收费；进账进日志；商店一行按钮（每件一个、刷新、离开）；到付费撤离点说付不付得起；悬停战斗点多「打赢 +x 币」 |
| `tests/test_economy.gd` | 6 组；`test_node_events` 跟着改两处 |

## 怎么算

**打赢进账**（`EconomyRules.battle_reward`）：

```
(reward_base + reward_per_strength × 档位) × (1 + reward_depth_gain × 深度) × (1 + reward_difficulty_gain × 难度)，四舍五入
```

档位是节点内容里记的 `strength`（6.0：同一个拾荒者在深处是更高的档位，钱也跟着多），深度按 tier 归一化到 0～1，
难度是章节的。输了、平了不给。作者说的三个因素各占一项，档位是加法、深度与难度是乘法 —— 深处的精英才值钱，浅处的杂兵不因为难度高就翻倍。

**商店**（`ShopSession`）：

- 货架 `shop_slots` 格，候选是不是包、不带排除标签（珍宝只从敌人身上掉）的道具，按稀有度权重抽、不重复；
  权重 × (1 + shop_depth_gain × 深度 × 稀有度)：越深的店越容易见到好东西。
- 价 = `ItemValue.of(def)`（6.4：稀有度 × 尺寸，或作者填的值）× `shop_price_mult`。
- 买了那一格就空了；刷新花 `shop_refresh_cost + shop_refresh_step × 已刷次数`，换一整批、卖掉的格子清零。
- **货架不用存**：第 n 次刷新的货架由 `hash(content_seed, n)` 决定，存档只记 `content.shop = {refreshes, sold}`，读档重摆出来一样。
- 走了才算用过（5.6 的规矩：VISITED = 内容已消耗）。买到的东西交给谁装是 M5 的事，只发 `bought(def, price)`。

**付费撤离点**（`PaidExtracts`）：生成之后的一遍，生成器不认识钱。撤离点按 tier 降序、id 升序排，前 `paid_extracts` 个
标 `content.fee = extract_fee` —— 离核心最近的出口最值钱。核心不是中途撤离点，不收。到点时 `extract_reached(node, fee)`
报费用；撤离动作本身是 M6 的事，它先调 `pay_extract_fee(node)`：免费直接过，付不起返回 false、一分不动。

## 关键决策

- **钱包不知道数值**，与体力同一种做法（7.1）：赢一场给多少、一件卖多少、撤离收多少，全从 `EconomyRules` 拿。
  不够就一分不动 —— 没有「透支一部分」这回事，商店与撤离点的判断才干净。
- **商店是节点上的会话**，和搜索点一样：开门、买、刷新、走；`NodeEvents.current_shop` 记着，沙盒里点别的点先关门。
- **哪个撤离点收费是规则**（最深的），**几个、多少钱是数据**。要改成随机挑，改 `PaidExtracts.mark` 一处。
- **没有钱包的旅程不算钱**：`NodeEvents.wallet` 为 null 时照样打、照样掉落，只是不进账、商店是空的 —— 测试与旧沙盒都还能跑。

## 验证

```
bash tools/test.sh
通过  5981 项断言，37 个套件，耗时 87 秒
```

- 钱包：进账、负数按 0、花光、不够一分不动、花 0 永远可以、只有真变了才发信号、存档往返。
- 奖励：最外档位 0 = 基础；档位加法；最内乘 (1 + 深度增益)；难度乘 (1 + 难度增益 × 难度)；三者一起按公式；档位 / 深度 / 难度高的不少给；负输入按 0。
- 付费撤离点：合成图标最深的、同深按 id、费用来自规则、没标的免费、核心不收；要三个标三个、要的比有的多有几个标几个、0 不收、没图不炸；
  第一章真图正好一个、是 tier 最高的撤离点、费用跟着图存。
- 商店：摆满 `shop_slots` 格、都能上架、不重复、不卖包与珍宝、价 = 价值 × 倍数；买了扣标价、发 `bought`、同一格买不了第二次、卖掉记进内容；
  没钱买不了刷不了、一分不动；刷新扣费、越刷越贵、满架、货换了、次数记进内容；同种子同货、读档接着来；最内的货架比最外好；关门只发一次。
- 管线：往返逐字节相同；负费用、0 格、0 倍数、负增益、负个数、没有一档能上架、打错字段名 → 全错；仓库文件导得进、是导出器格式、资产一致；第一章引用得到、指向不存在的 → 错。
- 接进节点事件：打赢进账 = 规则按档位、深度、难度算的；商店开会话、店里点没用过、买最便宜的扣标价、走了才用过；
  免费撤离点 fee 0 直接过，付费的带着费用、没钱付不了、钱够扣正好；没钱包照样打赢但不进账。

## 没做的

- 卖东西给商店：作者没提；`ItemValue` 就是卖价的基础，要的时候加 `sell_ratio` 一个字段。
- 买到的道具没处放、撤离动作本身：M5（玩家棋盘）/ M6（场景流）。
- 商店里的道具没有「只此一件」以外的库存概念；事件点的 item 结果和商店是两回事。
