# 130 方案：流派倾向的道具 —— 流血 / 中毒两条线的联动件（触发、转化、阈值爆发、条件增伤），参照同类作品整合

> 架构 · 提议（2026-10-05）。作者：「关于目前的道具，增加一些流派倾向的东西，比如触发对手流血给自己增伤或者增速的道具，将中毒转化为剧毒（伤害更高）的道具，参考市面上已有的游戏，进行整合分析」。

## 一、现状（已核实）

- **流派是标签，不是菜单**（架构 3.8「不写流派」、6.0「流派是标签」）：`bleed` / `rapid` / `burst` 这些标签圈武器给敌人池组装用，玩家这边靠道具联动自然成形。本篇不改这条：新件只打标签（`bleed` / `poison` 内部标签，107 定了不弹窗），不在界面上写「流血流派」。
- **流血、中毒天生是 BuffDef**（作者 2026-10-03 定）：武器顶多施加它们；中毒每层每秒 2 点、流血每层每秒 1 点，都是永续可叠层、无视护盾、不招致反应（`damage_types/bleed.json`、`poison.json`）。现有带它们的件：弯刀、剁刀（流血）、涂毒匕首、毒药瓶、毒箭（中毒）。**没有一件**会「因为对手流血 / 中毒而得到什么」—— 这两条线现在只有起点，没有后手。
- 规则引擎（4.4 四层：时机 · 频率 · 消耗 · 内容）已有的口子：
  - 时机 `on_damage(造成, 类型=bleed)`：**显式**填类型就能监听持续伤害的每一跳（`damage_trigger.gd` 注释：「这是留给联动效果的口子」）；`on_stacks_at_least(buff, n, 对手, 消耗)`：对手攒到 n 层时触发、可消耗；`on_before_damage(造成)` + `modify_damage`：改写自己正要打出的这一包。
  - 内容 `apply_status` / `remove_status` / `shift_axis`（标准轴：加速 / 强攻 / 易伤 / 破绽…）/ `deal_damage` / `modify_damage`。
  - 消耗 `status_stack`（扣层）、`chance`（概率，不消耗东西的「条件」先例）、`charge` / `uses`。
  - 108 定的**武器附加**：`AdjacencyProfile.grant_rules`（毒箭挨着弓 → 弓每箭附毒）。
- **缺三个小构件**，没有它们作者点名的两种件写不出来或写得别扭：
  1. 时机「**某状态被施加时**」（对手刚被挂上流血的那一瞬）—— 现在只能用「攒到 n 层」或「每一跳」近似，前者只在过阈值那一刻触发一次，后者和「施加」是两回事。
  2. 内容「**转化状态**」（把对手身上全部中毒换成等量剧毒）—— `remove_status` + `apply_status(per_stack)` 拼不出来：`per_stack` 读的是**来源 buff** 的层数，不是对手身上另一个 buff 的层数。
  3. 消耗「**状态条件**」（对手身上有流血才触发，但不扣层）—— `status_stack` 会扣，`on_stacks_at_least` 只在层数变化那一刻求值，不能当「出手时检查」用。

## 二、参照作品怎么做（整合分析）

以下是对几类同题材作品公开机制的归纳（凭对这些游戏的了解整理，不是逐条查证的引文；用来找**模式**，不抄数值）：

| 模式 | 代表 | 要点 | 对本作的启发 |
|---|---|---|---|
| **A 施加即触发** | 《The Bazaar》（「当你施加中毒 / 灼烧时……」是整个物品池最常见的触发词）、《背包乱斗》的「每次施加 X 时」 | 状态本身是弱 DoT，真正的收益来自「施加这件事」被别的件监听：充能、加速、回血 | 作者点名的「触发对手流血给自己增速 / 增伤」正是它。需要时机 1 |
| **B 状态升阶 / 转化** | 《杀戮尖塔》催化剂（中毒 ×2 / ×3）、《暗黑破坏神 IV》剧毒灌注（把武器伤害转成中毒）、《流放之路》把点伤转毒 / 转流血的核心天赋 | 一件「转化件」让整条线的收益翻倍，是流派成形的那一刻；通常稀有度高、一件就够 | 作者点名的「中毒转化为剧毒」。需要内容 2，加一个新 buff【剧毒】 |
| **C 阈值爆发（吃层）** | 《背包乱斗》热度攒满点燃、《杀戮尖塔》「消耗全部中毒造成等量伤害」类卡、《Hades》判决叠满引爆 | 持续伤害慢，给一个「一口气兑现」的出口，让叠层有节奏感 | 流血线的爆发件：攒够 n 层放血。现有 `on_stacks_at_least(消耗)` 直接写 |
| **D 条件增伤** | 《暗黑地牢》「对流血目标 +X% 伤害」饰品、《暗黑破坏神 IV》「对流血敌人易伤」、《怪物火车》对带「厄运」目标加伤 | 普通攻击因为对手带状态而变强，让非 DoT 武器也愿意和 DoT 件搭 | 「对流血目标伤害 +n%」。需要消耗 3 |
| **E 二次效果** | 《背包乱斗》中毒附带失明 / 减速、《The Bazaar》灼烧附带减速 | DoT 每跳带一点别的减益，线的厚度来自并发 | 中毒的每一跳有机会给对手破绽（护甲轴 −1） |
| **F 跨线桥接** | 《流放之路》「流血的目标受到更多中毒伤害」、《暗黑破坏神 IV》流血 + 易伤 | 两条线之间搭一座桥，玩家混搭有理由 | 「对手被施加流血时附带一层中毒」 |
| **G 把 DoT 变成普通攻击的载体** | 《背包乱斗》毒匕首 / 毒箭、《The Bazaar》「你的武器附带中毒」 | 让任何武器都能进这条线，不必非拿那几把毒武器 | 108 的附加接口：毒箭已有，补「近战附毒」「远程附流血」两件 |

**整合结论**：一条线要成形，至少要有「起点（施加）→ 后手（A / E）→ 兑现（B 或 C）→ 外援（D / G）」四段。流血线现有起点三件、后手零；中毒线起点三件、后手零。所以本篇每条线补一件 A、一件 B 或 C、一件 D 或 G，再加一件 E、一件 F，共**十件**；不做第三条线（灼烧已归日神信仰）。

## 三、三个新构件

| 构件 | 层 | 字段 | 语义 |
|---|---|---|---|
| `on_status_applied` | 时机 | `buff_id`，`on_self`（默认 false = 对手身上），`by_self`（默认 true = 只听本方施加的） | 目标身上刚被施加了这个 buff（层数增加那一瞬，刷新时长不算）。`by_self` 让「对手自己中毒了」不算到你头上。来源层数（施加了几层）进 `RuleContext.source_stacks()`，供 `per_stack` |
| `convert_status` | 内容 | `target`，`from`，`to: BuffDef`，`ratio`（默认 1.0，换算层数四舍五入、至少 1），`keep_from`（默认 false） | 把目标身上 `from` 的全部层数换成 `to` × ratio。系统 buff（103）不可转 |
| `status_condition` | 消耗 | `buff_id`，`on_self`（默认 false），`stacks`（默认 1） | 目标身上至少这么多层才通过；**不扣层**。和 `chance` 一样是「条件型消耗」 |

三个都是「加一个脚本 + `RunRegistry` 登记一行」（10.2），导入器与编辑器自动认得。校验：`convert_status.to` 不许是 `from` 自己；`on_status_applied` 不许和 `apply_status` 同一个 buff 形成自环（A 件施加 X 又监听 X）—— 导入器拦。

新 buff【**剧毒**】（`virulent`，is_debuff，永续可叠，每层每秒 **5** 点毒伤，即中毒的两倍半）：定义照中毒的写法内嵌在用到它的道具里（现在 buff 都是内嵌、同 id 合并）。

## 四、十件道具

数值全是占位（和 079 一样等校准）；价值走公式；稀有度按「起点 1 / 后手 2 / 转化 3」。描述走占位符、不写裸数字。

### 流血线

| id | 名 | 形状 | 稀 | 标签 | 模式 | 规则 |
|---|---|---|---|---|---|---|
| `bloodlust_bracer` | 嗜血护腕 | 1 | 2 | part leather bleed | A（增速） | `on_status_applied(bleed, 对手) · always · apply_status(自己, 嗜血 1)`；【嗜血】可叠、上限 6 层、每层急速 +4% |
| `bloodhound_sigil` | 猎血者的符号 | 1 | 2 | part sigil bleed | A（增伤） | `on_status_applied(bleed, 对手) · always · apply_status(自己, 血勇 1)`；【血勇】上限 5 层、每层强化 +5% |
| `bloodletter` | 放血刀 | 1<br>1 | 2 | weapon melee bleed metal | 起点 + C | 伤害 6、冷却 1.1 秒、耐力 5：`deal_damage + apply_status(流血 1)`；第二条：`on_stacks_at_least(流血, 6, 对手, 消耗) · always · deal_damage(physical 18, 不吃属性)` —— 攒够六层放血一刀 |
| `serrated_arrows` | 锯齿箭 | 1 | 1 | ammo bleed nature | G | 邻接：增益格在上方、只给 `ranged`，`grant_rules`：`on_item_fired · always · apply_status(流血 1)`（镜像毒箭） |
| `wound_salt` | 创口盐 | 1 | 1 | reagent material crafted bleed | D | `on_before_damage(造成, physical) · always · status_condition(对手 流血 ≥ 1) · modify_damage(percent +20)` —— 对流血目标普攻更痛 |

### 中毒线

| id | 名 | 形状 | 稀 | 标签 | 模式 | 规则 |
|---|---|---|---|---|---|---|
| `viper_gland` | 蝰蛇毒腺 | 1 | 3 | reagent material nature poison | B（转化） | `on_status_applied(poison, 对手, 本方施加) · always · convert_status(对手, poison → 剧毒, ratio 1)` —— 你施加的中毒立刻变剧毒，对手自己带的不管 |
| `envenomed_gauntlet` | 毒匠手套 | 1 | 2 | part leather poison | G | 邻接：四邻、只给 `melee`，`grant_rules`：`on_item_fired · always · apply_status(中毒 1)` —— 任何近战武器进毒线 |
| `blight_censer` | 腐蚀香炉 | 1<br>1 | 2 | part metal poison | E | `on_damage(造成, poison) · always · chance(20) · shift_axis(对手, armor, −1)` —— 毒跳有两成机会给对手一层破绽 |
| `bitter_root` | 苦艮根 | 1 | 1 | remedy nature | 防守 | `on_before_damage(受到, poison) · always · modify_damage(percent −50)` —— 吃毒减半；给打毒敌人的反制，也让毒线玩家敢用会反噬的件 |

### 桥

| id | 名 | 形状 | 稀 | 标签 | 模式 | 规则 |
|---|---|---|---|---|---|---|
| `festering_blade` | 溃烂之刃 | 1<br>1<br>1 | 3 | weapon melee bleed poison metal | F | 伤害 9、冷却 1.4 秒、耐力 7：`deal_damage + apply_status(流血 1)`；第二条：`on_status_applied(bleed, 对手) · always · apply_status(中毒 1)` —— 流血喂中毒，两条线的桥 |

### 配套

- **敌人池**：`poison` 补成敌人流派标签（6.0：每个流派至少一件带它的道具 —— 已有三件）；蛮兵 / 屠夫的流派里可以挑一件 A 件进去，让玩家在敌人身上先见到联动。
- **术语**（`Glossary.TERMS` 与 buff 词条自动生成）：剧毒、嗜血、血勇三个 buff 由 `describe_buff` 按定义生成，不手写；「施加时」作为时机词加进 TERMS（和「开战时」并列，不弹）。
- **百科**（125 的「战斗」类）：「持续伤害」页末补一段「流血与中毒的后手」，点到施加触发、转化、阈值放血、条件增伤四种玩法，不列具体件。
- **搜索 / 商店 / 掉落**：按标签与稀有度自然进池，不单独配；`viper_gland` 与 `festering_blade` 是 r3，走 127 的进阶保底才稳定见到，这正好让转化件保持稀有。
- **流派不写在界面上**：悬浮窗只写规则（「对手被施加{buff:流血}时，自己获得一层{buff:嗜血}」），`bleed` / `poison` 标签不弹窗（107）。

## 五、改动点

| 文件 | 改动 |
|---|---|
| `core/battle/triggers/on_status_applied.gd` 新、`core/battle/effects/convert_status.gd` 新、`core/battle/costs/status_condition.gd` 新、`RunRegistry` 三行 | §三 |
| `core/battle/combatant_runtime.gd` / `battle_sim.gd` | 施加状态时发 `status_applied` 事件（带 buff_id、目标、来源、层数增量），时长刷新不发 |
| `tools/import_content.gd` 校验 | `convert_status` 自转、`on_status_applied` 自环 |
| `data/authoring/items/`（10 件） | §四 |
| `data/authoring/enemies/*.json` | `poison` 流派；一两件 A 件进蛮族的流派池 |
| `core/text/glossary.gd`、`data/authoring/help_pages/dot*.json` | 「施加时」时机词；百科补段 |
| `docs/architecture.md` 4.4 构件表、6.0 流派表、`docs/effect-catalog.md` | 登记三个构件、一个流派 |
| `tests/battle/test_status_synergy.gd` 新 | 施加触发只响应本方施加、刷新不触发；转化后中毒归零剧毒等量、系统 buff 不转、ratio 取整；条件消耗不扣层；放血刀攒六层扣六层打一刀；锯齿箭 / 毒匠手套只给邻格的对应武器挂规则（108 的附加路径）；苦艮根只减毒伤；导入校验两条拦得住 |

## 六、待定（都按推荐）

| # | 问题 | 推荐 | 备选 |
|---|---|---|---|
| 1 | 转化怎么做 | **反应式**：`on_status_applied` + `convert_status`（四层模型内，不改编译器；悬浮窗能看见这条规则） | 编译期重定向（CompileInput 加「本方施加 X 时改施加 Y」表）：省一次事件，但是第二套机制 |
| 2 | 剧毒的强度 | **每层每秒 5 点**（中毒 2 的两倍半；转化件 r3 一件就是线的顶） | 4 点（两倍） |
| 3 | A 件的增益形式 | **自己的 buff**（嗜血 / 血勇，有层数上限） | 标准轴 `shift_axis(加速 / 强攻)`：没有上限，和流血的无限叠层一起会失控 |
| 4 | 放血刀的爆发 | **固定 18 点、不吃属性**（像灼烧那种固定伤） | 按消耗层数 × 3（需要 `deal_damage` 多一个「按消耗的层数」字段，本篇不加） |
| 5 | 要不要第三条线 | **不要**：灼烧归日神信仰（093），再开一条会和信仰抢位置 | 加「灼烧」A 件一件 |
