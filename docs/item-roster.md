# 道具清单（首批内容计划）

这份清单是**打算做的内容**，不是已有内容。积木清单见
[`effect-catalog.md`](effect-catalog.md)：那里列的是能用什么，这里列的是用它们拼什么。

写它的用意有两个：一是给 M2 的收尾定个靶子，二是**用真实内容去压一遍效果系统** ——
凡是这里写得出、系统里做不到的，都在最后一节「写不出来的东西」列了账。

> 状态：截至架构 v1.5。`data/items/` 里现有 15 个资产**只有形状与标签，没有战斗数据**；
> 下表里标 ✓ 的就是它们，标 **新** 的还不存在。
> 所有数值都是**占位**，等可视化（021）能看见战斗之后再调。

---

## 约定

**稀有度**：0 常见 · 1 罕见 · 2 稀有 · 3 史诗 · 4 传说

**形状**是一张布尔矩阵，写成 0/1 数字串，1 为占格、0 为空。
表格单元格里用 `<br>` 代替换行：

| 写法 | 含义 |
|---|---|
| `1111` | 横条四格 |
| `11`<br>`10` | L 形三格 |
| `010`<br>`111`<br>`010` | 十字五格 |

代码侧同一记法：`ItemShape.from_bits("11\n10")`，`to_bits()` 导出回来。
导入器的 JSON 也用它，三方不必各写一套。

**规则**统一写成四段，缺省的段省略：

```
时机 · 频率 · 消耗 · 内容
```

**资源**三种，全部由 `max_*` 属性自动派生，不需要为任何一种改代码：

| 资源 | 谁用 | 来源 |
|---|---|---|
| `hp` 生命 | 所有人 | run 级基础值 + `max_hp` 类道具 |
| `stamina` 耐力 | 冷兵器与枪械 | `max_stamina` 类道具（**见最后一节的坑**） |
| `power` 电力 | 电子类道具 | 电池、能量核心 |
| `shield` 护盾 | 护盾发生器 | `max_shield`，扣血前先扣它（**尚未实现，见最后一节**） |

---

## 1 · 包体

包决定棋盘上有多少可用格，**包自己不参战**。`bag_mods` 施加给包内每件物品。

| id | 名称 | 形状 | 稀 | 准入 | 包体效果 | 有? |
|---|---|---|---|---|---|---|
| `bag_small` | 小背包 | `11`<br>`11` | 0 | — | — | ✓ |
| `bag_leather` | 皮革包 | `11`<br>`11`<br>`11` | 1 | — | — | ✓ |
| `bag_long` | 长条包 | `1111` | 1 | — | — | ✓ |
| `belt_potion` | 医疗腰带 | `1`<br>`1`<br>`1` | 2 | `consumable` | 包内物品 `haste` +15% | ✓ |
| `rig_chest` | 战术胸挂 | `111`<br>`111` | 2 | `weapon` | 包内物品 `damage` +10% | **新** |
| `case_hard` | 防爆箱 | `11`<br>`11` | 3 | — | 包内物品 `damage` +30%、`haste` −10% | **新** |

`belt_potion` 的显示名从「药水带」改为「医疗腰带」—— 现代搜刮题材里没有药水。
id 保持不变，改 id 会让存档失效。

## 2 · 武器

一律 `on_schedule`（自发出手）+ `cooldown`，消耗耐力。**耐力不足时跳过但冷却照走。**

| id | 名称 | 形状 | 稀 | 伤害 | 规则 | 有? |
|---|---|---|---|---|---|---|
| `knife` | 匕首 | `1` | 0 | 3 | `on_schedule · cooldown(0.6) · resource(stamina,3) · deal_damage + apply_status(流血,1)` | **新** |
| `pistol` | 手枪 | `11` | 1 | 6 | `on_schedule · cooldown(1.2) · resource(stamina,6) · deal_damage` | ✓ |
| `smg` | 冲锋枪 | `11`<br>`10` | 1 | 4 | `on_schedule · cooldown(0.5) · resource(stamina,4) · deal_damage` | **新** |
| | | | | | ＋`on_stacks_at_least(肾上腺素,2) · cooldown(2.0) · deal_damage(8)` | |
| `rifle` | 步枪 | `1`<br>`1`<br>`1` | 2 | 8 | `on_schedule · cooldown(0.8) · resource(stamina,5) · deal_damage` | ✓ |
| `shotgun` | 霰弹枪 | `11`<br>`11` | 2 | 20 | `on_schedule · cooldown(2.2) · resource(stamina,14) · deal_damage` | **新** |
| `sniper` | 狙击枪 | `1`<br>`1`<br>`1`<br>`1` | 3 | 30 | `on_schedule · cooldown(3.0) · resource(stamina,18) · deal_damage + apply_status(标记,1)` | ✓ |
| `crowbar` | 撬棍 | `11`<br>`10` | 1 | 14 | `on_schedule · cooldown(2.0) · resource(stamina,12) · deal_damage` | ✓ |

`smg` 的第二条规则是**激活型** `on_stacks_at_least`：嗑了兴奋剂就多一路扫射，
层数留着不消耗。与下面 `railgun` 的消耗型正好成对，用来在内容里体现那个勾选框的差别。

`crowbar` 不吃弹匣加成（标签是 `tool` 不是 `weapon`），换来的是不需要任何配件就能打。

## 3 · 电子与供电

用 `power` 而不是耐力。这一整条线是「新增一种资源不改代码」的实证 ——
配一个 `max_power` 属性就有了 `power` 资源。

| id | 名称 | 形状 | 稀 | 属性 | 规则 | 有? |
|---|---|---|---|---|---|---|
| `battery` | 电池 | `1` | 0 | `max_power` +20 | 无规则，纯供电 | ✓ |
| `core` | 能量核心 | `010`<br>`111`<br>`010` | 3 | `max_power` +60 | 无规则，纯供电 | ✓ |
| `capacitor` | 电容器 | `1` | 2 | — | `on_schedule · cooldown(1.0) · resource(power,4) · apply_status(自己,蓄力,1)` | **新** |
| `drone` | 无人机 | `111`<br>`010` | 2 | — | `on_schedule · cooldown(2.5) · resource(power,10) · deal_damage(6)` | ✓ |
| | | | | | ＋`on_item_fired(己方) · always · charge(3) · deal_damage(5)` | |
| `railgun` | 电磁炮 | `1`<br>`1`<br>`1`<br>`1` | 4 | — | `on_stacks_at_least(蓄力,3,消耗) · always · resource(power,20) · deal_damage(50)` | **新** |
| `shield_gen` | 护盾发生器 | `11`<br>`11` | 3 | `max_shield` +30 | `on_schedule · cooldown(4.0) · resource(power,15) · change_resource(自己,shield,+15)` | **新** |

`core` 与 `battery` **有 `CombatProfile` 但没有 `rules`** —— 这是合法的「参战但不主动」，
`is_active()` 返回 false，它们只贡献属性。

`drone` 的第二条规则是**连带触发**：己方任何物品出手都算一次，攒够 3 次放一发。
`ChargeCost` 在这里是「每 3 次搭一发」的意思，不是冷却。

`railgun` 是全表唯一的 4 级：它自己不产蓄力，必须配 `capacitor`。
两件占 4+1 = 5 格换一发 50 点，这个取舍本身就是 build 的内容。

## 4 · 防护与反应

| id | 名称 | 形状 | 稀 | 属性 | 规则 | 有? |
|---|---|---|---|---|---|---|
| `ration` | 口粮 | `1` | 0 | `max_stamina` +40 | 无规则 | **新** |
| `armor` | 防弹衣 | `111`<br>`111` | 2 | `armor` +5、`max_hp` +20 | 无规则 | ✓ |
| `medkit` | 医疗包 | `11`<br>`11` | 1 | — | `on_resource_below(hp,40%) · always · uses(1) · change_resource(自己,hp,+35)` | ✓ |
| `painkiller` | 止痛药 | `1` | 1 | — | `on_resource_below(hp,25%) · always · uses(1) · remove_status(自己,流血,全部) + change_resource(自己,hp,+10)` | **新** |
| `stim` | 兴奋剂 | `1` | 2 | — | `on_battle_start · always · apply_status(自己,肾上腺素,3)` | ✓ |
| `plate_reactive` | 反应装甲 | `11`<br>`11` | 3 | `armor` +2 | `on_damage(受到,physical,≥12) · cooldown(3.0) · deal_damage(10)` | **新** |
| `bio_monitor` | 生命监测仪 | `11` | 2 | — | `on_resource_changed(hp,下降,自己) · cooldown(5.0) · apply_status(自己,强壮,1)` | **新** |

`medkit` 与 `painkiller` 都用 `uses(1)` 全场限一次 —— 没有它，每次掉血都会回一口，
`on_resource_below` 会变成无限奶。这是消耗层的典型用法。

`plate_reactive` 只对**物理**且单次 ≥12 点的伤害反应，小刀凌迟触发不了。

## 5 · 配件（邻接标记）

邻接是「谁挨着谁」，**不是宝石镶嵌**。双方各占各的格子。
点亮规则是去重计数：一件物品最多填另一件的一个增益格。

| id | 名称 | 形状 | 稀 | 方向 | 标记格 | 过滤 | 加成 | 有? |
|---|---|---|---|---|---|---|---|---|
| `mag` | 弹匣 | `1` | 0 | 增益 | 上、下 | `weapon` | `damage` +20% | ✓ |
| `scope` | 瞄准镜 | `11` | 2 | 增益 | 下方两格 | `weapon` | `damage` +35% | **新** |
| `grip` | 战术握把 | `1` | 1 | 增益 | 四周 | `weapon` | `stamina_cost` −20% | **新** |
| `sniper` | 狙击枪 | — | — | **受益** | 下方一格 | `part` | 本枪 `damage` +25% | ✓ |

`sniper` 是全表唯一带**受益**标记的：它得架在支撑物上。
增益／受益是两个方向而不是两种符号 —— 弹匣主动给邻居加成，狙击枪主动向邻居要加成。

`grip` 减的是 `stamina_cost`，走的是和伤害完全一样的那条公式
（`基础值 × ∏(1+乘区) + 固定加值`），不需要任何特例。

## 6 · 增益模块

| id | 名称 | 形状 | 稀 | 规则 | 有? |
|---|---|---|---|---|---|
| `leech_mod` | 吸血模块 | `1` | 3 | `on_damage(造成,≥8) · always · change_resource(自己,hp,+2)` | **新** |
| `frag_pouch` | 破片袋 | `1` | 2 | `on_item_fired(己方) · always · chance(25%) · deal_damage(4)` | **新** |
| `overclock` | 超频模块 | `11` | 3 | `on_schedule · cooldown(5.0) · change_resource(自己,hp,−5) + apply_status(自己,肾上腺素,2)` | **新** |

`overclock` 是 `change_resource` **负数**的用处：以血换速。
原先叫 `RestoreResource` 的时候这件道具写不出来，只能传个负数假装在「恢复」。

`frag_pouch` 是全表唯一用 `chance` 的：概率走战斗随机流，因此同种子可复现。

## 7 · 战利品道具（不参战）

**没有扳机、没有冷却、不占战斗资源，放在棋盘上就生效。**
它们只写 `ItemDef.effects`，连 `CombatProfile` 都没有。

| id | 名称 | 形状 | 稀 | 效果 | 有? |
|---|---|---|---|---|---|
| `lucky_charm` | 幸运护符 | `1` | 2 | `extra_rolls(+1)` | **新** |
| `lockpick` | 开锁器 | `11` | 2 | `category_bias(tool, +20)` | **新** |
| `scanner` | 战术扫描仪 | `11` | 3 | `drop_owned_chance(+25%)` | **新** |
| `collector_tag` | 收藏家标签 | `1` | 3 | `rarity_bias(稀有度3, +25)` | **新** |

这一组存在的意义是压测 v1.5 那次重构：**单件道具带跨域效果，不必归属任何套装。**
重构之前这四件一件也写不出来。

`scanner` 提高的是「敌人掉落其**自身携带**道具」的概率 —— 与按掉落表随机生成不同，
它让玩家能盯着尸体上看得见的东西下手，搜刮从「开箱」变成「挑目标」。

## 8 · 套装

套装由**背包里凑齐的件数**激活，道具上记载的套装信息只是 UI 提示。

| 套装 | 计数 | 成员 | 档位 | 效果 |
|---|---|---|---|---|
| `scav_kit` 拾荒者 | 按定义 | `lockpick` `lucky_charm` `scanner` `collector_tag` | 2 件 | `extra_rolls(+1)` |
| | | | 3 件 | `drop_owned_chance(+20%)` |
| `assault_kit` 突击 | 按定义 | `rifle` `mag` `armor` `rig_chest` `grip` | 2 件 | `damage` +15%（mods） |
| | | | 4 件 | `on_battle_start · always · apply_status(自己,肾上腺素,2)`（rules） |
| `tesla_kit` 特斯拉 | 按定义 | `battery` `core` `capacitor` `drone` `railgun` `shield_gen` | 2 件 | `max_power` +25（mods） |
| | | | 4 件 | `on_schedule · cooldown(3.0) · change_resource(自己,power,+10)`（rules） |

三个套装各压一条路径：`scav_kit` 只有跨域 `effects`、`assault_kit` 有 `mods` 也有 `rules`、
`tesla_kit` 的 4 件档是套装自己的周期性规则（不属于任何物品，来源 uid 为 0）。

档位**累加**：4 件套同时享有 2 件档与 4 件档。

## 9 · 增益与减益

战斗内的一切属性变化都由 buff 承载，**包括资源上限**。仅限本场战斗，结束清空。

| id | 名称 | 上限 | 时长 | 每层效果 | 施加者 |
|---|---|---|---|---|---|
| `charge` | 蓄力 | 5 | 永续 | 无（纯计数） | `capacitor` |
| `edge` | 锋锐 | 5 | 8s | `damage` SHARP +10% | （留给后续武器） |
| `adrenaline` | 肾上腺素 | 3 | 10s | `haste` HASTE +12% | `stim` `overclock` `assault_kit` |
| `fortify` | 强壮 | 3 | 永续 | `max_hp` +15 | `bio_monitor` |
| `burn` | 灼烧 | 10 | 5s | 规则：`on_schedule · cooldown(1.0) · deal_damage(自己,2,每层)` | （留给火系武器） |
| `bleed` | 流血 | 5 | 6s | 规则：`on_schedule · cooldown(1.0) · deal_damage(自己,1,每层)` | `knife` |
| `marked` | 标记 | 1 | 8s | `armor` −3 | `sniper` |
| `overheat` | 过热 | 3 | 4s | `haste` −15% | （留给后续） |

`burn` 与 `bleed` 是**带规则的 buff**：规则挂在受害者身上、在受害者的 runtime 上跑，
所以目标是「自己」。`BattleSim` 里没有为持续伤害写任何一行特例。

`fortify` 加的是 `max_hp`，上限增加时当前值同量增加，所以吃到立刻多一截血。

---

## 覆盖矩阵

这份清单是照着积木表拼的，每一块至少有一件道具用到。空着的格子就是**没有内容验证过**的地方。

| 积木 | 由谁用到 |
|---|---|
| **时机** | |
| `on_schedule` | 全部武器、`drone` `capacitor` `shield_gen` `overclock` |
| `on_battle_start` | `stim`、`assault_kit` 4 件档 |
| `on_item_fired` | `drone` 第二条、`frag_pouch` |
| `on_resource_changed` | `bio_monitor` |
| `on_resource_below` | `medkit` `painkiller` |
| `on_stacks_at_least`（激活型） | `smg` 第二条 |
| `on_stacks_at_least`（消耗型） | `railgun` |
| `on_damage`（受到） | `plate_reactive` |
| `on_damage`（造成） | `leech_mod` |
| **频率** | |
| `always` | 事件型规则的默认搭配 |
| `cooldown` | 全部武器；`plate_reactive` `bio_monitor` 用它当闸门 |
| **消耗** | |
| `resource` | 全部武器（耐力）、电子线（电力） |
| `status_stack` | `railgun`（由扳机隐式追加，作者没手写） |
| `charge` | `drone` 第二条 |
| `uses` | `medkit` `painkiller` |
| `chance` | `frag_pouch` |
| **战斗效果** | |
| `deal_damage` | 全部武器 |
| `change_resource`（正） | `medkit` `painkiller` `leech_mod` `shield_gen` |
| `change_resource`（负） | `overclock` |
| `apply_status` | `knife` `sniper` `stim` `capacitor` `bio_monitor` |
| `remove_status` | `painkiller` |
| `Target.BOTH` | **无** —— 缺一件范围伤害道具 |
| `damage_type` ≠ physical | **无** —— 缺整条元素线 |
| **战利品效果** | |
| `extra_rolls` | `lucky_charm`、`scav_kit` 2 件档 |
| `rarity_bias` | `collector_tag` |
| `category_bias` | `lockpick` |
| `drop_owned_chance` | `scanner`、`scav_kit` 3 件档 |
| **其他** | |
| 邻接 · 增益 | `mag` `scope` `grip` |
| 邻接 · 受益 | `sniper` |
| 包体 `bag_mods` | `belt_potion` `rig_chest` `case_hard` |
| 包内准入标签 | `belt_potion`（消耗品）、`rig_chest`（武器） |
| 套装 `mods` | `assault_kit` `tesla_kit` |
| 套装 `rules` | `assault_kit` `tesla_kit` |
| 套装跨域 `effects` | `scav_kit` |
| 属性 `cooldown` 覆盖 | **无** —— 没有道具需要覆盖 `CooldownCadence.seconds`，可能这个属性键是多余的 |

两处明确的空缺：**元素伤害线**（火／电／毒 + 对应抗性）和**范围伤害**。
两者都不缺机制，只缺内容 —— `damage_type` 和 `Target.BOTH` 现在就能用。
我倾向于留到第一章内容定稿时再补，免得现在编一套元素名词，回头全改。

---

## 写不出来的东西

拿真实内容压了一遍，有四处是现在**做不到**的。按要不要先修排序：

### 1. 没有基础耐力，捡到枪也打不出（要先修）

`BattleCompiler.BASE_HP = 25` 是 run 级基础生命，但**耐力没有对应的基础值**。
所以 `max_stamina` 只能来自道具 —— 玩家开局捡到一把手枪、没捡到口粮，
那把枪一发都打不出来，界面上还看不出为什么。

这不是内容能绕过的，我在表里加 `ration` 口粮也只是掩盖。
建议加一个 `BASE_STAMINA`，与 `BASE_HP` 并列。**动手前先确认你要不要这条基线** ——
也可能你就是想让「耐力来源」成为一个要占格子的取舍，那这条坑就是设计的一部分。

### 2. `OnItemFired.source_uids` 在 .tres 里填不了（要先修）

连带触发现在靠 `source_uids: Array[int]` 限定来源，但 uid 是**实例运行时**分配的，
制作 .tres 的时候根本不存在。所以「只在主武器出手时触发」这条最典型的连带触发，
目前只能写成「己方任何物品出手时」。

表里 `drone` 和 `frag_pouch` 都因此放宽成了「己方任何物品」。
修法是加 `source_tags: Array[StringName]`（按标签筛）或 `source_def_ids` —— 都不难，
但要改扳机，所以我没有顺手做。

### 3. `shield` 资源没有「先扣护盾」的语义（可以等）

`max_shield` 能配出来，资源池也会自动派生 `shield`，但 `DealDamage` 只扣 `hp`。
`shield_gen` 现在充其量是个数字，挡不住任何伤害。

要么给 `DealDamage` 加一层「先扣护盾再扣血」，要么做成一个吸收型 buff。
我倾向后者 —— 护盾是战斗内的临时状态，本来就该由 buff 承载，
而且那样「魔法护盾只挡元素伤害」之类的变体不用改效果代码。

### 4. 掉落效果没有消费方（按计划等 M4）

第 7 节那四件道具能配、能测，`LootContext` 会被正确改写，但没人读它 ——
掉落系统是 M4。这是计划内的，列在这里只是别忘了它们暂时不产生实际效果。

---

## 下一步

这份清单**先不落地成 .tres**。原因是 021 的可视化还没做，现在批量配数值等于蒙着眼睛调；
等能看见血条和伤害数字了，再一边看一边填才有意义。

顺序建议：

1. 021 极简战斗可视化（血条 + 伤害数字回放、沙盒实时 DPS 与套装进度）
2. 回头修上面第 1、2 条（基础耐力、连带触发的可配来源）
3. 第 10 节的导入器，把这张表变成 JSON
4. 用导入器批量生成本表全部资产，边看边调数值
