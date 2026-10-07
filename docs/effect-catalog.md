# 效果构件清单

当前可用的全部构件。制作道具与增益时从这里挑，**不需要写代码**；
需要写代码的只有「新增一种构件」，那时加一个脚本并在
[`core/battle/effect_registry.gd`](../core/battle/effect_registry.gd) 登记一行即可。

> 用这些构件拼出的**首批内容计划**见 [`item-roster.md`](item-roster.md)。
>
> 状态：截至架构 v1.10。`data/items/` 里的 15 个示例资产**尚未配置任何战斗数据**，
> 下面列的是可用构件，不是已有内容。

---

## 效果分三个作用域

所有效果同出一棵树，按**在哪个系统里起作用**分支。道具与套装共用同一套词汇。

```
Effect
  CombatEffect   战斗内     【依赖扳机】      → 第 1~4 节
  LootEffect     战利品     激活即生效        → 第 5 节
  MapEffect      地图       占位，M3 再填
```

**只有战斗这一支需要时机。** 战利品效果没有「什么时候发生」可言 ——
掉落计算阶段本身就是它的时机，所以它不配扳机，也没有频率与消耗。

道具自带的跨域效果（`ItemDef.effects`）**在棋盘上就算激活，不必凑套装**；
套装那份（`SetTier.effects`）要满足件数门槛。两者汇入同一个查询。

---

## 一条战斗规则的结构

```
时机 Trigger  →  频率 Cadence  →  消耗 Cost[]  →  内容 CombatEffect[]
什么时候        多久一次          满足才执行        做什么
```

一件物品可以有**多条规则**；一条规则可以有**多个效果**，它们按顺序执行并**共用同一次消耗**。

**消耗失败时跳过效果，但冷却照常推进。** 这是有意的：否则武器会在耐力回满的瞬间
立刻打出，耐力不足毫无代价。

---

## 1 · 时机 Trigger

| 类型名 | 类 | 含义 | 参数 |
|---|---|---|---|
| `on_schedule` | `OnSchedule` | **自发型**，不等事件，由频率层排出执行时刻 | — |
| `on_battle_start` | `OnBattleStart` | 开战瞬间 | — |
| `on_item_fired` | `OnItemFired` | 有物品出手时。**连带触发就是它** | `same_side` 听己方还是敌方；`source_uids` 限定来源（空=不限）；`include_self` 是否含自己（默认否，防自循环）；`source_tags` 只听带这些标签之一的件（132，可与 LINKED 叠加） |
| `on_resource_changed` | `OnResourceChanged` | 资源增减时 | `resource_key`（hp/stamina/mana…）；`direction`（ANY/INCREASE/DECREASE）；`same_side`；`reasons` 限定原因 |
| `on_resource_below` | `OnResourceBelow` | 资源**降到阈值以下**时 | `resource_key`；`percent` 按上限的百分比（0 则改用绝对值）；`absolute`；`on_self`；`direction`（BELOW / ABOVE，132）；`full` 回满（132） |
| `on_stacks_at_least` | `OnStacksAtLeast` | 身上有 **N 层**某增益减益时 | `buff_id`；`stacks`；`on_self` 看自己还是对手；`consume` **消耗型开关**，见下 |
| `on_damage` | `OnDamage` | 受到／造成某类伤害**之后** | `direction`（TAKEN/DEALT）；`damage_type` 空=不限；`min_amount` 按实际扣除量；`crit_only` 只在暴击时（132） |
| `on_before_damage` | `OnBeforeDamage` | 受到／造成某类伤害**之前**。减伤、免疫、反转唯一的接入点 | 同上；`min_amount` 按护盾吸收后的待结算量 |
| `on_status_applied` | `OnStatusApplied` | 某状态**被施加**、层数增加的那一瞬（130）；叠满后只刷新时长不算 | `buff_id`；`on_self`（默认 false = 对手身上）；`by_self`（默认 true = 只认本方施加的）。施加了几层进 `per_stack` |
| `on_status_removed` | `OnStatusRemoved` | 某状态**掉光**时（最后一层被移除或到期，132） | `buff_id`；`on_self`（默认 true） |
| `on_overtime` | `OnOvertime` | 加时开始那一瞬，整场一次（132） | — |
| `on_axis_at_least` | `OnAxisAtLeast` | 某条**标准轴**（4.3「标准轴」，103）到了 N 层时；和 `on_stacks_at_least` 同构，层数变化那一刻求值 | `axis`（见 `StatAxes`）；`stacks` 至少几层（可为负：−3 = 减速到 3 层及以上，按绝对值比、要求同号）；`on_self`；`layer` 数哪一层（TOTAL 合计 / CONTENT 内容层 / SYSTEM 系统层，自然 5 级「加时开始后」数的是系统层） |

`on_item_fired` 的 `source` 值得单独说一句：填 `LINKED` 时**只听与本物品通过
增益／受益格连结的道具**。本作没有「主武器」的设定，「跟着某把枪一起触发」
只能靠摆放上的连结来表达 —— 配件贴到武器旁边，连结就成立了，这是玩家摆出来的，
不是在 .tres 里配出来的。

> 没有 `on_tick`。**模拟里没有帧** —— 帧是渲染概念，底层直接按时刻跳跃。

### 消耗型与激活型

`on_stacks_at_least` 的 `consume` 勾上即为**消耗型**：触发后扣掉那 N 层；
不勾就是**激活型**，层数只作为条件，不消耗。

实现上消耗型不是另一个类，而是由扳机**隐式追加**一条 `status_stack` 消耗。
作者只填一个勾选框，四层结构不变：

```
on_stacks_at_least(蓄力, 3, consume) + always + deal_damage
等价于
on_stacks_at_least(蓄力, 3)          + always + status_stack(蓄力, 3) + deal_damage
```

**扳机自己不扣层数**，因为 `matches()` 必须只读，而消耗要发生在其他消耗也付得起之后 ——
否则「攒够 3 层但耐力不够」会把 3 层白吃掉。脱糖成普通消耗后，
它自动享有消耗层「全部付得起才付」的原子性。

---

## 2 · 频率 Cadence

| 类型名 | 类 | 含义 | 参数 |
|---|---|---|---|
| `always` | `Always` | 每次命中都执行。事件型规则的默认搭配 | — |
| `cooldown` | `CooldownCadence` | 攒满一个周期的工作量后可执行 | `seconds` 基础冷却（**任意小数**）；`use_haste` 是否吃速度加成 |

冷却以**工作量**计而非时间：每秒推进 `haste` 点，攒满 `seconds` 点即就绪。
所以速度变化不会丢失已有进度，也没有任何累积误差。

冷却下限 0.01 秒，防止被改到 0 造成同一时刻无限触发。

---

## 3 · 消耗与条件 Cost

「耐力够不够」与「次数攒够没有」在**失败行为上完全一致**——都是跳过效果但不退还冷却，
所以归在同一层。`costs` 是列表，**AND 语义**：全部通过才逐个扣，不允许半付款。

| 类型名 | 类 | 含义 | 参数 |
|---|---|---|---|
| `resource` | `ResourceCost` | 消耗耐力／法力等 | `resource_key`；`amount` 面板值；`amount_stat` 改从属性取（走公式，可被增减） |
| `status_stack` | `StatusStackCost` | 消耗 N 层某增益 | `buff_id`；`stacks`；`on_self`（默认 true；130 起可扣对手身上的） |
| `charge` | `ChargeCost` | 攒够 N 次机会才放一发 | `n` |
| `uses` | `UsesCost` | 全场限用 N 次 | `max_uses`（默认 1） |
| `chance` | `ChanceCondition` | 按概率放行，走 battle 随机流 | `percent` 0..100 |
| `status_condition` | `StatusCondition` | 目标身上至少 N 层某状态才放行，**不扣层**（130） | `buff_id`；`on_self`（默认 false）；`stacks`（默认 1）；`negate` 取反（132） |
| `resource_condition` | `ResourceCondition` | 资源在某范围才放行，**不扣**（132） | `resource_key`；`on_self`；`min_percent` / `max_percent`（0..100，−1 不限）；`absolute_min` / `absolute_max`；`negate`。至少填一个界 |
| `axis_condition` | `AxisCondition` | 标准轴至少几层才放行，**不扣**（132） | `axis`；`on_self`；`stacks`（可负：按绝对值比、同号）；`negate` |
| `axis_cost` | `AxisCost` | 扣自己的轴层数，可透支到负（132） | `axis`；`stacks` |

---

## 4 · 战斗效果 CombatEffect

| 类型名 | 类 | 含义 | 参数 |
|---|---|---|---|
所有战斗效果的 `target` 三选一：`OPPONENT` / `SELF` / `BOTH`。

| 类型名 | 类 | 含义 | 参数 |
|---|---|---|---|
| `deal_damage` | `DealDamage` | 造成伤害，按护甲减免 | `target`；`damage_type` 伤害类型（默认 `physical`）；`amount` 固定值；`damage_stat` 改从属性取（默认 `damage`）；`per_stack` 是否乘来源 buff 层数；`percent_of`（max_hp / current_hp / missing_hp）+ `percent` 按生命比例、与固定值相加，`percent_of_target` 按谁的生命（132）；`per_target_stack` 乘目标身上某状态的层数、0 层不打（132） |
| `change_resource` | `ChangeResource` | **增减**资源。治疗／回耐力／抽血／耗蓝共用 | `target`；`resource_key`；`amount` **正为获得、负为失去**；`amount_stat`；`per_stack`；`percent_of_damage` 受伤后按这一包实际扣除量的百分比（吸血，132） |
| `apply_status` | `ApplyStatus` | 施加增益／减益 | `target`；`buff`；`stacks`；`per_stack` |
| `remove_status` | `RemoveStatus` | 减少层数。净化、驱散、削减对手蓄力 | `target`；`buff_id`；`stacks`（**0 = 全部移除**）；`all_debuffs` / `all_buffs` 清光（系统 buff 不清，132） |
| `convert_status` | `ConvertStatus` | 把目标身上一种状态的全部层数换成另一种（130：中毒 → 剧毒）。系统 buff 不转；导入器拦 `to` 就是 `from` | `target`；`from`；`to`（buff）；`ratio`（默认 1.0，四舍五入、至少 1）；`keep_from`（默认 false） |
| `modify_damage` | `ModifyDamage` | 改写正在结算的那一包伤害。**只在受伤前阶段有效** | `flat` 固定增减；`percent` 百分比；`invert` 反转成治疗；`cancel` 完全免疫 |
| `reflect_damage` | `ReflectDamage` | 把这一包伤害按比例弹回施加方。**只在受伤前阶段有效** | `percent` 反弹待结算量的百分比；`flat` 额外固定值；`damage_type` 默认 `reflect` |
| `convert_damage_type` | `ConvertDamageType` | 把这一包换成另一种伤害类型。**只在受伤前阶段有效**；直接旗不变；不许换成 poison / bleed（132） | `to` |
| `shift_axis` | `ShiftAxis` | 改一条**标准轴**的层数（103）：「加速 2 层」是 +2、「减速 1 层」是 −1，直接相抵；层数永续、战斗结束清空。单位级的攻速、造成 / 受到伤害、回血、耐力回复都走它，不另开 buff（`blight_censer` 在用） | `target`；`axis`（见 `StatAxes`）；`delta` 带符号的层数；`per_stack` 是否乘来源 buff 的层数 |

### 伤害怎么结算

**一切血量的减少都走同一条五步管线**，武器命中、持续伤害、以血为代价的自伤
区别只在类型：

```
确认类型 → 护盾吸收 → 受伤前效果 → 计算受伤量 → 受伤后效果
```

`modify_damage` 在第三步生效，这是减伤／免疫／反转唯一的接入点。
**有条件的减伤靠消耗层表达**，不需要任何新机制：

```
消耗 2 层格挡减免 10 点
  on_before_damage(受到) · always · status_stack(格挡,2) · modify_damage(flat = -10)
```

层数不够时不减伤，也**不会白吃掉那几层** —— 消耗层的原子性白拿。

内置六种伤害类型，性质写在 `DamageTypeDef` 里而不是结算代码的 if 里：

| 类型 | 护盾 | 护甲 | 招致反应 | 用途 |
|---|---|---|---|---|
| `physical` | ✓ | ✓ | ✓ | 常规 |
| `fire` | ✓ | ✓ | ✓ | 元素线的起点 |
| `poison` | ✗ | ✗ | **✗** | 中毒：持续伤害 |
| `bleed` | ✗ | ✗ | **✗** | 流血：持续伤害 |
| `reflect` | ✓ | ✓ | **✗** | 反伤：反弹专用 |
| `drain` | ✗ | ✗ | **✗** | 流失：代价、超频、献祭 |

新增一种（腐蚀、真实、精神…）＝ 加一份 `DamageTypeDef` 并登记，管线一行不改。

**「招致反应」那一列是无限反伤的解药。** 只有直接攻击会点亮反伤、吸血、格挡；
中毒和流血每秒跳一次，能招致反伤的话一个 debuff 就把反伤刷成了主要输出；
反伤自己若能招致反伤，两件反伤道具会互相引燃。

反弹一律用 `reflect_damage`，**别手写 `deal_damage`** —— 前者读得到伤害包的待结算量，
而且默认就用对了 `reflect` 类型。

**流失**：`change_resource` 扣血量时不直接改资源，而是造一包 `drain` 走管线 ——
这样「以血换速」的超频模块同样吃得到减伤与免疫。

**逃生口**：扳机里**显式**填下类型名就听得见。「中毒时净化」「流失时回一口气」
靠的就是这个 —— 写下类型名即表示作者知道自己在监听什么。

**伤害类型不是乘区**：`damage_type` 与乘算是两个正交维度，刻意不做映射（133 之前的乘区分类已取消）。
绑在一起就写不出「强化影响全部伤害」—— 那是一个乘区作用于所有类型；
反过来「火焰抗性」是按类型减伤，与乘区无关。

---

## 5 · 战利品效果 LootEffect

**不依赖扳机，也没有频率与消耗。** 只要处于激活状态，进入战利品计算阶段就生效。

| 类型名 | 类 | 含义 | 参数 |
|---|---|---|---|
| `extra_rolls` | `ExtraRolls` | 增加掉落次数 | `rolls` |
| `rarity_bias` | `RarityBias` | 偏向某个稀有度 | `rarity`；`amount` 权重偏移 |
| `category_bias` | `CategoryBias` | 偏向某类道具 | `tag`；`amount` |
| `drop_owned_chance` | `DropOwnedChance` | 提高「敌人掉落其自身携带道具」的概率 | `percent` 0..100 |

> 掉落系统（M4）尚未实现，这里定的是接口：效果写进 `LootContext`，
> M4 接上真正的掉落表即可。现在就能配、能测。

`drop_owned_chance` 与按掉落表随机生成不同 —— 它让玩家能定向抢夺**看得见的**东西，
搜刮环节因此从「开箱」变成「挑目标」。

---

## 6 · 属性键

| 键 | 含义 | 粒度 |
|---|---|---|
| `damage` | 单次伤害 | 单件物品 |
| `cooldown` | 冷却秒数，覆盖 `CooldownCadence.seconds` | 单件物品 |
| `haste` | 速度倍率，基础 1.0，越大越快 | 单件物品 |
| `stamina_cost` / `mana_cost` | 消耗面板值 | 单件物品 |
| `max_hp` / `max_stamina` / `max_mana` / `max_shield` | 资源上限 | 整个单位 |
| `regen_hp` / `regen_stamina` / … | 资源每秒回复量 | 整个单位 |
| `armor` | 防护（固定减伤；旧称「护甲」） | 整个单位 |

**属性按物品保留粒度。** 「磨刀石只给旁边那把武器加伤害」靠的就是这一点，
不能把所有物品的属性并成一份单位级表。

**资源由 `max_*` 自动派生**：配一个 `max_shield` 属性就有了 `shield` 资源，不用改代码。
`shield` 另有一条特殊待遇 —— 伤害管线第二步会优先扣它（能不能扣由伤害类型决定）。

**回复也是属性**：配一个 `regen_stamina` 就有了每秒回耐力，**按时间懒结算**，
没有定时器。因为它只是普通属性，「某某 buff 让耐力回得更快」就是一条作用于它的
`StatModifier`，不需要任何新机制。

**还有一份不属于任何道具的基线**（`CombatantBaseline`）：默认生命 25、耐力 50、
耐力回复 4/秒。
没有它，玩家捡到一把枪却可能因为身上没有 `max_stamina` 道具而一发都打不出。
这同时是角色系统的占位 —— 将来不同角色带不同的基线。

---

## 7 · 属性修饰（乘算 / 加算）

结算公式（133 起只有一个乘区）：`终值 = 基础值 × max(0, 1 + 乘算之和) + 加算之和`

所有乘算先相加再乘一次；加算在乘法之后、不吃百分比放大。

一条 `StatModifier`：

| 字段 | 含义 |
|---|---|
| `stat` | 作用的属性键 |
| `mode` | `ADD` 加算（默认，固定值）/ `MULT` 乘算（百分数） |
| `amount` | 乘算：25 = +25%、−10 = −10%；加算：固定值。正数扩大、负数缩小 |

编辑器在每条修饰下画一行灰字说明它怎么生效。暴击率 / 暴击伤害只收加算（104）。

> 133 之前有四个乘区（`EMPOWER / SHARP / ELEMENT / HASTE`），按枚举顺序连乘。已取消：锋利、元素、急速这类是独立的 buff / 属性，不是增益的生效方式。
> 旧键 `mult_category / mult_percent / flat` 导入时自动迁移（`mult_category` 提醒忽略，又乘又加的报错要求拆成两条）。

---

## 8 · 增益 BuffDef

| 字段 | 含义 |
|---|---|
| `id` / `display_name` / `is_debuff` | 标识与 UI |
| `max_stacks` | 层数上限，0 = 不限 |
| `duration_sec` | 作者定的规矩：**可叠层的 buff（`max_stacks != 1`）永续，不填时长（导入器拦）**—— 中毒 / 流血 / 结界叠上就一直在，直到被清除或战斗结束；**不可叠层的（`max_stacks == 1`，往往是「满足 X 条件时获得 ABC」那种复杂的）才可以过期**，0 = 也永续，秒数可任意小数 |
| `refresh_on_restack` | 叠层时是否刷新时长 |
| `mods` | 属性加成，**每层一份** |
| `rules` | **buff 自己也能带规则** —— 复合效果靠它 |
| `on_apply` / `on_expire` | 施加与到期时的效果 |

战斗内一切属性变化都由 buff 承载，**包括资源上限**。buff 仅限本场战斗，结束清空。

---

## 组合示例

### 普通武器

```
时机 on_schedule
频率 cooldown(2.0)
消耗 resource(stamina, 10)
内容 deal_damage(damage_stat = damage)
```

耐力不足时这一下打空，但冷却照走。

### 法术书

```
时机 on_schedule
频率 cooldown(3.5)
消耗 resource(mana, 20)
内容 deal_damage(30) + apply_status(灼烧, 2 层)
```

一次消耗，两个效果。

### 蓄力重击

```
时机 on_schedule
频率 cooldown(0.5)
消耗 charge(3) + resource(stamina, 15)
内容 deal_damage(damage_stat = damage)
```

每 0.5 秒攒一次，攒够 3 次且耐力足够才打出。

### 反击

```
时机 on_resource_changed(hp, DECREASE, 自己)
频率 cooldown(2.0)          ← 这里冷却当闸门用，不是调度器
内容 deal_damage(5)
```

### 连带触发

```
时机 on_item_fired(己方, source_uids = [主武器 uid])
频率 always
内容 deal_damage(6)
```

不需要任何特殊机制，就是一条订阅出手事件的普通规则。

### 蓄力消耗型

```
时机 on_stacks_at_least(蓄力, 3, consume = true)
频率 always
内容 deal_damage(damage_stat = damage)
```

攒到 3 层的那一刻打出并清空这 3 层。消耗没写在 `costs` 里 —— 扳机自己带进来的。

### 濒死回血

```
时机 on_resource_below(hp, percent = 30)
频率 always
消耗 uses(1)                ← 全场限一次，否则每次掉血都回
内容 change_resource(SELF, hp, +40)
```

### 火焰反击

```
时机 on_damage(TAKEN, damage_type = fire, min_amount = 15)
频率 cooldown(2.0)          ← 这里冷却当闸门用，不是调度器
内容 deal_damage(OPPONENT, 8)
```

只对火焰、且单次不低于 15 点的伤害反应。

### 吸血

```
时机 on_damage(DEALT)
频率 always
内容 change_resource(SELF, hp, +4)
```

打到自己不算「造成伤害」，所以自伤类效果不会触发它。

### 净化

```
时机 on_stacks_at_least(中毒, 5)
频率 always
内容 remove_status(SELF, 中毒, stacks = 0)   ← 0 = 全清
```

### 格挡（有条件的减伤）

```
时机 on_before_damage(受到)
频率 always
消耗 status_stack(格挡, 2)
内容 modify_damage(flat = -10)
```

层数不够就全额挨打，且那 1 层不会被白吃掉。

### 解毒剂（反转伤害）

```
时机 on_before_damage(受到, poison)
频率 always
消耗 uses(1)
内容 modify_damage(invert)
```

全场一次，把一发中毒变成等量治疗。

### 破片袋（只跟着邻居那把枪）

```
时机 on_item_fired(己方, source = LINKED)
频率 always
消耗 chance(25%)
内容 deal_damage(4)
```

贴在武器的增益格旁边才听得见它 —— 换个位置就失联，摆放本身是内容。

### 荆棘（反伤）

```
时机 on_before_damage(受到)
频率 always
内容 reflect_damage(percent = 30)
```

弹回去的那一下是 `reflect` 类型，不会再点燃对方的反伤。
反弹量按**护盾吸收之后**的待结算量算 —— 护盾扛住的部分不算数。

### 战利品道具（不进战斗）

```
ItemDef 幸运护符
  effects: [ drop_owned_chance(+25%), extra_rolls(+2) ]
```

没有扳机、没有冷却，**放在棋盘上就生效**。也不需要归属任何套装。

### 灼烧（复合效果 buff）

```
BuffDef 灼烧
  duration_sec 5.0
  max_stacks   10
  rules: [ on_schedule + cooldown(1.0) + deal_damage(SELF, 2, per_stack) ]
```

挂在受害者身上，规则在受害者的 runtime 上跑，所以目标是 `SELF`。
`BattleSim` 里**没有为灼烧写任何一行特例**。

### 强壮（改上限的 buff）

```
BuffDef 强壮
  mods: [ max_hp +20 每层 ]
```

上限增加时当前值同量增加，所以吃到立刻多一截血。

---

## 精度

时间与数值全程用定点整数，**1.0 = 10000，即四位小数**。

标度刻意取十进制而非 2 的幂：你写的 `0.1`、`0.37`、`2%` 全部**精确可表示**，
`0.1 × 3` 恰好等于 `0.3`。四位小数意味着冷却精确到 0.1 毫秒、百分比精确到 0.01%。

只有 `1/3` 这类本就无法用有限小数表示的值才会舍入到第五位。

**道具默认规则（属性与说明）**：`armor` 标签（盔甲）的基础效果是提供**护盾**（`max_shield`）；
`shield` 标签（盾牌）的基础效果是提供**防护**（`armor` 属性，固定减伤）。「护甲」一词已改名「防护」。
