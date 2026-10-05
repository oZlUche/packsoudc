# 126 方案：敌人身上随机携带非战斗道具（零到若干件，越值钱越少见），出现与掉落两套独立的概率

> 架构 · 提议（2026-10-05）。作者：「给敌人增加身上会携带的非战斗道具，随机出现（0~N 件），价值越高出现几率越低，和掉落率独立」。

## 一、现状（已核实）

- 敌人背什么在**生成地图时**由 `EnemyPlacer.build_content` 定：件数 `StrengthTier.item_count`，招牌 → 流派 → 通用（`EnemyLoadout.common_tags`），全部摆进它的包（088：道具全在包里），放不下的跳过；写进 `MapNode.content.items`。
- 现在非战斗道具只能靠 `item_tags` 里的 `material` 偶然被当「通用」抽到（拾荒者有），和战斗道具抢同一份 `item_count`，没有单独的概率，也不看价值。
- 掉落（`DropResolver`）：敌人每件各掷一次，概率按稀有度；包必掉；至少掉一件。战前准备屏能看到敌人整块棋盘，所以**玩家在开打前就看得见它背着什么**。

## 二、设计

### 2.1 携带规则是数据：`CarryRule`（新内容种类 `carry_rules`，章节按 id 引用，像 `drop_rules`）

| 字段 | 默认 | 意思 |
|---|---|---|
| `tags` | `["material"]` | 从带这些标签、**没有战斗档**（`combat == null`）、未封存、不带 `treasure` 的道具里抽 |
| `count_by_strength` | `[[0,1],[0,2],[0,3],[1,4]]` | 档位 → 件数区间 [min, max]，均匀抽；超出表长按最后一档。0～N 由此来 |
| `value_power` | `1.0` | 每件的抽取权重 = `1 / ItemValue.of(def) ^ value_power`。1 = 价值翻倍、几率减半；越大越偏向便宜货 |
| `rarity_cap_bonus` | `1` | 允许比档位的 `rarity_cap` 高这么多（外环小兵偶尔也背一卷丝绸，才有「这个人值得打」） |
| `allow_repeat` | `true` | 同一件可重复 |

### 2.2 放哪、怎么放

`build_content` 在战斗道具摆完**之后**再摆携带品：同一块棋盘 / 同一些包，小件先摆，放不下的跳过（计入 `dropped` 回报）。不加棋盘、不加包 —— 背得多的敌人本来就该是高档位、大棋盘的。内容里每件多一个键 `"carried": true`，别的地方照旧读 `items`。

### 2.3 和掉落独立

出现由 `CarryRule` 定，掉不掉由 `DropRule` 定，两套各自的掷骰、各自的数。推荐**携带品必掉**（`DropRule.carried_always_drop`，默认 true，和 `bags_always_drop` 同一处判）：它们是「这个敌人身上的钱」，战前看见了才有「为了它多打一场」的决定；要是掷骰再丢一半，看见等于白看。不占 `min_drops` 名额。

### 2.4 战前准备屏

不改布局：携带品本来就在棋盘上，悬浮窗照常显示价值。`EnemyKit.summary` 那一行加「携带 n 件」即可。

## 三、数值（占位）

- 外环（档位 0）0～1 件、废墟 1 件上下、核心 1～4 件。
- `value_power = 1`：以 122 的材料为池，铜矿石（5）与丝绸卷（225）的权重比 45 : 1；按现有二十八件算，一次抽到稀有度 ≥ 2 的概率约 7%。要更吝啬把 `value_power` 调到 1.5。

## 四、改动点

| 文件 | 改动 |
|---|---|
| `core/enemies/carry_rule.gd` 新 | §2.1 |
| `data/authoring/carry_rules/standard.json` 新；`ContentPaths.KINDS / ORDER`（`drop_rules` 之后）、`ContentCheck.KINDS`、`ContentImporter` 校验（件数非负、`value_power > 0`） | 内容种类 |
| `core/run/chapter_def.gd` | `carry_rule: StringName`（空 = 不带） |
| `core/enemies/enemy_placer.gd` | `build_content` 加「携带」一步，`carried: true` |
| `core/enemies/enemy_kit.gd` | `summary` 加件数 |
| `core/loot/drop_rule.gd` / `drop_resolver.gd` | `carried_always_drop` |
| `data/authoring/chapters/free_mode.json` | 引用 `standard`；三张序章不引用（教程敌人身上的东西是设计好的） |
| `tests/enemies/test_carry.gd` 新 | 同一种子两次生成携带相同；件数落在区间；池里只有无战斗档的材料；权重按价值递减（大样本：便宜货出现次数显著多）；放不下的计入 dropped；打赢后携带品全在尸体容器里 |

## 五、待定（按推荐即执行）

| # | 问题 | 推荐 |
|---|---|---|
| 1 | 携带品掉不掉也掷骰，还是必掉 | **必掉**（§2.3），不然战前看见的信息没用 |
| 2 | 池按 `material` 标签还是单列一个 `valuable` 标签 | **按 `material` + 无战斗档**，不再加标签；将来要排除某件加 `exclude_tags` |
| 3 | 权重按价值还是按稀有度 | **按价值**（作者原话），尺寸大的自然更少见 |
| 4 | 序章要不要带 | **不带** |
