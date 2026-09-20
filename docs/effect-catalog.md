# 效果积木清单

当前可用的全部构件。制作道具与增益时从这里挑，**不需要写代码**；
需要写代码的只有「新增一种积木」，那时加一个脚本并在
[`core/battle/effect_registry.gd`](../core/battle/effect_registry.gd) 登记一行即可。

> 状态：截至架构 v1.2。`data/items/` 里的 15 个示例资产**尚未配置任何战斗数据**，
> 下面列的是可用积木，不是已有内容。

---

## 一条规则的结构

```
时机 Trigger  →  频率 Cadence  →  消耗 Cost[]  →  内容 Effect[]
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
| `on_item_fired` | `OnItemFired` | 有物品出手时。**连带触发就是它** | `same_side` 听己方还是敌方；`source_uids` 限定来源（空=不限）；`include_self` 是否含自己（默认否，防自循环） |
| `on_resource_changed` | `OnResourceChanged` | 资源增减时 | `resource_key`（hp/stamina/mana…）；`direction`（ANY/INCREASE/DECREASE）；`same_side`；`reasons` 限定原因 |

> 没有 `on_tick`。**模拟里没有帧** —— 帧是渲染概念，底层直接按时刻跳跃。

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
| `status_stack` | `StatusStackCost` | 消耗 N 层某增益 | `buff_id`；`stacks` |
| `charge` | `ChargeCost` | 攒够 N 次机会才放一发 | `n` |
| `uses` | `UsesCost` | 全场限用 N 次 | `max_uses`（默认 1） |
| `chance` | `ChanceCondition` | 按概率放行，走 battle 随机流 | `percent` 0..100 |

---

## 4 · 内容 Effect

| 类型名 | 类 | 含义 | 参数 |
|---|---|---|---|
| `deal_damage` | `DealDamage` | 造成伤害，按护甲减免 | `target`（OPPONENT/SELF）；`amount` 固定值；`damage_stat` 改从属性取（默认 `damage`）；`per_stack` 是否乘来源 buff 层数 |
| `restore_resource` | `RestoreResource` | 恢复资源（治疗／回耐力／回法力共用） | `target`；`resource_key`；`amount`；`amount_stat`；`per_stack` |
| `apply_status` | `ApplyStatus` | 施加增益／减益 | `target`；`buff`；`stacks` |

---

## 5 · 属性键

| 键 | 含义 | 粒度 |
|---|---|---|
| `damage` | 单次伤害 | 单件物品 |
| `cooldown` | 冷却秒数，覆盖 `CooldownCadence.seconds` | 单件物品 |
| `haste` | 速度倍率，基础 1.0，越大越快 | 单件物品 |
| `stamina_cost` / `mana_cost` | 消耗面板值 | 单件物品 |
| `max_hp` / `max_stamina` / `max_mana` | 资源上限 | 整个单位 |
| `armor` | 减伤 | 整个单位 |

**属性按物品保留粒度。** 「磨刀石只给旁边那把武器加伤害」靠的就是这一点，
不能把所有物品的属性并成一份单位级表。

**资源由 `max_*` 自动派生**：配一个 `max_shield` 属性就有了 `shield` 资源，不用改代码。

---

## 6 · 乘区（buff 分类）

结算公式：`终值 = 基础值 × (1 + A区之和) × (1 + B区之和) × … + 固定加值之和`

同区相加、跨区相乘、固定加值在所有乘法之后且不吃百分比放大。

| 乘区 | 定位 |
|---|---|
| `EMPOWER` | 通用增伤 |
| `SHARP` | 物理系 |
| `FIRE` | 元素系 |
| `HASTE` | 作用于速度 |

> 这四个是开发期占位，正式内容确定后替换。**只能在末尾追加，可以重命名，不能重排** ——
> 枚举顺序即乘法顺序，中间插入会让所有已配数值和存档对不上。

---

## 7 · 增益 BuffDef

| 字段 | 含义 |
|---|---|
| `id` / `display_name` / `is_debuff` | 标识与 UI |
| `max_stacks` | 层数上限，0 = 不限 |
| `duration_sec` | 持续秒数（**任意小数**），0 = 到战斗结束 |
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
