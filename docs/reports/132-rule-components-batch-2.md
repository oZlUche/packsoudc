# 132 方案：规则构件第二批（131 里「相对简单」的那些）+ 受益格挂规则

> 架构 · 提议（2026-10-05）。作者看过 131 后：「可以将相对简单的加上」；并问「增益槽和受益槽的扳机是否完善，以及能触发的效果和道具本身效果是同类还是独立的」—— 后一问的答案在 §一，顺手把受益格缺的那一行补进本批。

## 一、增益 / 受益格现在是什么（答问）

- **格子没有「扳机」**：点亮是**编译期静态**的 —— 开战前数「我的标记格被几件不同的物品占住」（去重计数，4.2），数完就定了；战斗中不会因为谁出手、谁受伤而变。它们是**摆放条件**，不是事件条件。
- 点亮之后能给的东西，和道具自己身上的**是同一套类**，不是另一套：
  - `grant_mods` / `receive_mods` 是 `StatModifier`，和道具 `combat.base_stats` 之上的加成、包体 `bag_mods`、buff 的 `mods` 一模一样，走 4.3 同一条公式；
  - `grant_rules`（108）是 `AbilityRule`，和道具 `combat.rules` 同一个类、同四层结构；区别只在**以谁的身份跑**：挂到邻居身上、以**邻居**为来源（`item_stat` 读邻居的、伤害算邻居打的、直接伤害），悬浮窗写「附加：… ← 来源」。
  - 第三条路 `on_item_fired(source = LINKED)`：道具**自己**的规则，只听与自己连结的邻居出手 —— 这是「配件自己的反应」（以配件为来源、显示在配件上），和附加是两个方向（108 的表）。
- **不完善的两处**：
  1. `receive_rules` 没有（108 当时「等有内容再加，形状一样」）：「旁边每有一件食物，我就多一条规则」现在写不出。本批补上（§二 7）。
  2. 点亮只按「有没有物品 + 标签过滤」，没有按**邻居状态**的条件（例如「邻居是武器且有规则」）。`ScopedMod.require_active` 有这个过滤，邻接没有；本批不加，等内容要。
- 格子的硬约束不动：同一类标记的各格同质（否则退化成二分匹配，4.2）。

## 二、第二批构件（每项一个脚本或一个字段，不动引擎主体）

| # | 构件 | 层 | 字段 | 语义 | 校验 |
|---|---|---|---|---|---|
| 1 | 导入器三条**警告** | — | — | `modify_damage / reflect_damage / low_hp_empower` 不在 `on_before_damage` 下；`per_stack` 写在道具规则（非 buff 规则）里；`on_schedule` 配 `always`（若现在已是 error 则保持） | 警告不拦 |
| 2 | `on_item_fired.source_tags: Array[StringName]` | 时机 | 任一命中 | 只听带某标签的件出手（`ranged` / `melee` / `weapon`…）；和 `source = LINKED` 可叠加（既连结又带标签） | 标签要登记过 |
| 3 | `on_status_removed` | 时机 | `buff_id`，`on_self`（默认 true） | 某状态**掉光**（最后一层被移除或到期）时；听 `STATUS_UNSTACKED` 且剩余为 0 的那一次 | 与 `on_status_applied` 成对；自环同样拦（掉光时又施加同一个不算环，允许） |
| 4 | `on_resource_below` 加 `direction`（BELOW / ABOVE）+ `full` | 时机 | `direction` 默认 BELOW；`percent = 100` 即「回满」 | 涨过阈值 / 回满；不另开类 | — |
| 5 | `on_damage.crit_only: bool` | 时机 | 默认 false | 只在这一包是暴击时（104 的 `crit` 旗已在伤害事件里） | 只对 DEALT 有意义，TAKEN 配它给警告 |
| 6 | `on_overtime` | 时机 | — | 加时开始那一瞬（103 的 `OvertimeRules` 立系统 buff 的时刻发一个事件） | — |
| 7 | `AdjacencyProfile.receive_rules: Array[AbilityRule]` | 邻接 | 同 `grant_rules` | 每点亮一个受益格，**本件**多挂一份规则（以本件为来源，`_attach(self, rule, 邻居 id)`）；`has_receive()` 改判「有格且（有加成或有规则）」 | 同附加规则的三条（只许 `on_item_fired`、不许 costs、要有频率）—— 等等：受益规则跑在本件身上，宿主出手就是自己出手，所以这里放宽为**任意时机**，只保留「不许 costs」 |
| 8 | `resource_condition` | 消耗 | `resource_key`，`on_self`，`min_percent / max_percent`（0～100，−1 = 不限），`absolute_min / absolute_max` | 出手时检查资源在某范围，**不扣** | 上下限至少填一个 |
| 9 | `axis_condition` | 消耗 | `axis`，`on_self`，`stacks`（可负，按绝对值比、同号） | 轴至少几层，不扣 | 轴要在 `StatAxes.TABLE` 里 |
| 10 | `axis_cost` | 消耗 | `axis`，`stacks` | 扣自己轴的层数（`shift_axis` 的消耗面；扣到负也允许，像「透支」） | — |
| 11 | `negate: bool` | 消耗 | 加在 `status_condition` / `resource_condition` / `axis_condition` 三个条件型上 | 取反：「对手**没有**流血时」 | 只有条件型有它；`status_stack` 等真扣的没有 |
| 12 | `deal_damage.percent_of` + `percent_of_target` | 效果 | `percent_of ∈ {"", max_hp, current_hp, missing_hp}`，`percent`（0～100），`percent_of_target`（默认 OPPONENT） | 按生命比例的伤害，**和 amount / damage_stat 相加**（处决 = 固定 + 比例） | `percent_of` 非空时 `percent > 0` |
| 13 | `deal_damage.per_target_stack` | 效果 | `buff_id` | 伤害乘以**目标身上**这个状态的层数（0 层 = 不打）；和 `per_stack`（来源层数）可同时写 | 130 放血刀可改成按消耗前的层数（执行时顺手改，不改也行） |
| 14 | `change_resource.percent_of_damage` | 效果 | 0～100 | 只在 `on_damage` 下有包：回（或扣）这一包**实际扣除量**的百分比；和 `amount` 相加 | 不在 `on_damage` 下 → 导入器警告（同 #1 那类） |
| 15 | `remove_status.all_debuffs / all_buffs` | 效果 | 两个 bool | 一次清光目标身上全部减益 / 增益（按 `is_debuff`；系统 buff 不清） | 填了就忽略 `buff_id` |
| 16 | `convert_damage_type` | 效果 | `to`（伤害类型 id） | 把正在结算的这一包改成另一种类型（`on_before_damage` 下，和 `modify_damage` 同族）；直接 / 非直接旗不变 | `to` 要存在；不许转成 poison / bleed（作者定它们只在 buff 里） |

**不在本批**（131 说要各自成方案 / 动引擎）：`reset_cooldown`、`refire`、`disable_item`、通用 OR / NOT 组合子、按件的时机筛选推广。

## 三、改动点

| 文件 | 改动 |
|---|---|
| `core/battle/triggers/on_status_removed.gd` 新、`on_overtime.gd` 新；`on_item_fired.gd`、`on_resource_below.gd`、`on_damage.gd` 加字段 | #2～6 |
| `core/battle/costs/resource_condition.gd`、`axis_condition.gd`、`axis_cost.gd` 新；`status_condition.gd` 加 `negate` | #8～11 |
| `core/battle/effects/deal_damage.gd`、`change_resource.gd`、`remove_status.gd` 加字段；`convert_damage_type.gd` 新 | #12～16 |
| `core/battle/effect_registry.gd` | 登记 6 行 |
| `core/battle/overtime_rules.gd` / `battle_sim.gd` | 加时开始发 `OVERTIME` 事件（#6） |
| `core/battle/adjacency_profile.gd`、`compiler.gd _apply_adjacency` | `receive_rules`（#7） |
| `core/authoring/content_importer.gd` | #1 三条警告；#2～16 各自的校验；附加规则校验按 #7 分两档（grant 严、receive 宽） |
| `docs/effect-catalog.md`、`docs/architecture.md` 4.2 / 4.4 | 登记 |
| `tests/battle/test_components_batch_2.gd` 新 | 每项一两条：标签筛听得对；掉光触发一次、刷新不触发；回满触发；暴击旗；加时事件；受益格挂的规则以本件为来源、点亮几格挂几份；三种条件不扣层 / 不扣资源；`negate`；比例伤害与固定相加、`missing_hp`；按目标层数乘、0 层不打；按比例吸血只在有包时；清全部减益不动系统 buff；类型转换后直接旗不变、转毒 / 血被拦 |

## 四、待定（都按推荐）

| # | 问题 | 推荐 | 备选 |
|---|---|---|---|
| 1 | 涨过阈值 / 回满 | **并进 `on_resource_below`**（加 `direction`），类名不动、旧内容不改 | 另开 `on_resource_above` |
| 2 | 暴击时 | **`on_damage.crit_only`** 一个勾 | 独立 `on_crit` 类 |
| 3 | 受益格规则的校验 | **放宽到任意时机**（跑在本件身上）、仍不许 costs | 和 grant 一样只许 `on_item_fired` |
| 4 | `negate` 的范围 | **只给三个条件型** | 给全部消耗（扣类取反没有意义） |
| 5 | 130 放血刀要不要改用 #13 | **改**（「每层三点」比固定十八更像放血） | 不动 |
