# 020 · 统一效果树与状态条件型扳机

**阶段**：2 · M2　　**架构文档**：v1.5（第 9.2 / 9.3 / 9.4 节重写，3.4 澄清）
**测试**：740 项断言 / 12 个套件，全绿

---

## 起因

上一步（报告 019）把套装做成了独立系统，但留下一棵多余的树：套装效果是
`SetEffect`，战斗效果是 `Effect`，两者互不相识。

问题不在重复本身，而在它锁死了一类完全合理的内容：

> 「这把刀让敌人多掉一件东西。」

战利品效果只存在于 `LootSetEffect`，而 `LootSetEffect` 只能挂在套装档位上。
想让单件道具带一个掉落加成，写不出来 —— 除非为它造一个只有一件的套装，
那显然是在跟自己的数据结构较劲。

---

## 改动一：效果收归一棵树

```
Effect                                    core/effects/effect.gd
  CombatEffect   战斗内，【依赖扳机】      DealDamage / ApplyStatus / RemoveStatus / ChangeResource
  LootEffect     战利品，激活即生效        RarityBias / CategoryBias / ExtraRolls / DropOwnedChance
  MapEffect      地图，占位
```

基类**只声明 `scope()`，不声明执行方法**：

```gdscript
@abstract
class_name Effect extends Resource
@abstract func scope() -> StringName
func describe() -> String
```

一开始我想给它一个统一的 `apply(ctx)`。但战斗效果要 `RuleContext`（有出手方、来源物品、
随机流），掉落效果要 `LootContext`（有掉落次数、权重表），强行统一只能退化成
`apply(ctx: Variant)`，各分支进门先转型 —— 那是把编译期检查换成了运行时崩溃。
基类只承诺「我属于哪个作用域」，这一点两边都做得到。

道具与套装因此成了**两个入口，而不是两套词汇**：

| 来源 | 字段 | 激活条件 |
|---|---|---|
| 道具 | `ItemDef.effects` | **在棋盘上即可**，不必凑套装 |
| 套装 | `SetTier.effects` | 满足件数门槛 |

两者汇入同一个查询：

```gdscript
tracker.effects_in_scope(EffectScope.LOOT)   # 道具的 + 已激活套装的
```

`SetScope` 随之更名 `EffectScope` —— 作用域从来不是套装专有的。

## 改动二：SetTier 摊平成三份

```gdscript
class_name SetTier extends Resource
@export var pieces: int
@export var mods: Array[StatModifier]   ## 编译期属性修饰
@export var rules: Array[AbilityRule]   ## 战斗规则（需要扳机）
@export var effects: Array[Effect]      ## 非战斗作用域
```

原先是一个 `Array[SetEffect]`，靠 `CombatSetEffect` 包着 `mods` 和 `rules`。
既然效果树统一了，那层包装就没有意义 —— 而且它把三种生命周期完全不同的东西
（编译期一次性并入 / 扳机驱动 / 别的系统的别的阶段）塞进了一个列表，
消费方还是得按类型分拣，只是把分拣从编辑期挪到了运行时。

编译器接口随之变化：

```gdscript
# 之前
BattleCompiler.compile(board, base_hp, tracker.effects_in_scope(SetScope.COMBAT))
# 现在
BattleCompiler.compile(board, base_hp, tracker.combat_mods(), tracker.combat_rules())
```

**战斗效果不从 `effects_in_scope()` 出。** 它需要扳机，只能以 `AbilityRule` 的形式存在。
测试里明确断言了这一点（`effects_in_scope(COMBAT).size() == 0`），
免得以后有人以为那里漏了东西。

## 改动三：三个状态条件型扳机

| 扳机 | 命中条件 |
|---|---|
| `OnStacksAtLeast` | 自己／对手身上有 N 层某增益减益时 |
| `OnResourceBelow` | 资源降到上限的 N%（或绝对值 N）以下时 |
| `OnDamage` | 受到／造成某类伤害，且不低于 N 点时 |

### 消耗型与激活型只差一个勾选框

「拥有 3 层蓄力时」有两种用法：**激活型**只要条件成立，**消耗型**触发后要扣掉那 3 层。
这不该是两个类。

做法是让扳机向规则**隐式追加**一条消耗：

```gdscript
func implied_costs() -> Array[Cost]:        # OnStacksAtLeast
    if not consume: return []
    ...返回 StatusStackCost(buff_id, stacks)

func effective_costs() -> Array[Cost]:      # AbilityRule
    return costs + trigger.implied_costs()
```

**为什么不让扳机自己扣层数**，是这一步里唯一需要想清楚的地方：

1. `matches()` 必须只读 —— 它会被多次询问，改状态就不可重放了；
2. 更要紧的是顺序。消耗必须发生在**所有**条件都通过之后。若扳机先扣了层数，
   然后耐力检查失败，那 3 层就白吃了。

脱糖成一条普通 `Cost` 之后，它自动享有消耗层「全部付得起才付」的原子性，
四层结构（时机 · 频率 · 消耗 · 内容）也没有被破坏。作者那边看到的只是一个勾选框。

测试专门覆盖了这条：给规则再挂一条付不起的 `ResourceCost`，断言 3 层原封不动。

### 伤害是一条独立事件

`OnDamage` 订阅新的 `damage` 事件，而不是 `resource_changed`。后者不带伤害类型，
也分不清「我打了人」与「我挨了打」—— 两者都表现为某一方的 hp 下降。
事件里 `side` 是承受方、`source_side` 是施加方。

## 改动四：ChangeResource 取代 RestoreResource

原名只有正向语义，要减少就得传负数，**命名撒谎**。治疗、回耐力、抽血、耗蓝
现在共用一条 `ChangeResource`，`amount` 正为获得、负为失去。
同时补上 `RemoveStatus`（`stacks = 0` 表示全部移除），净化与驱散终于写得出来。

`CombatEffect.Target` 也补齐了 `BOTH`。

---

## 两处定案

### 伤害类型不绑定乘区

`damage_type`（`physical` / `fire` / …）与 `StatMath.Buff` 乘区分类
（`EMPOWER` / `SHARP` / `FIRE` / …）是两个正交维度，刻意不做映射。

绑在一起看着省事，但立刻写不出「强化影响全部伤害」—— 那是一个乘区作用于所有类型。
反过来「火焰抗性」是按类型减伤，与乘区无关。让内容作者各填各的，
比替他们建一个总要开后门的对应表更诚实。

### 暂存区里的道具 = 不存在

澄清了 3.4。暂存区是**关卡内**的临时摆放区（搜出道具、战后搜刮时腾挪位置用），
进入下一关时连同里面的道具一起消失。它不是第二个背包，也不是仓库。

实现上不需要任何一处写 `if in_staging` —— 各系统一律只遍历棋盘容器，
「暂存区不算数」是这条规则的**结果**：

| 系统 | 只看 |
|---|---|
| 战斗编译 | 棋盘上的非包物品 |
| 套装计数 | 棋盘上的非包物品 |
| 道具跨域效果 | 棋盘上的物品 |

唯一例外在 UI：离开关卡前若暂存区里还有高稀有度道具，应当提示玩家可能遗落。

清空时机尚未定稿（进入下一关即消失 vs 留到一局结算），已列入待确认第 7 项。
两案对代码的要求相同，推迟决定不阻塞任何模块。

---

## 遗留

**`SET_PIECES` 定向加成被移除。** 原先 `CombatSetEffect.target` 可以选「只加给套装部件」
还是「加给全部物品」；摊平之后 `SetTier.mods` 一律施加给棋盘上的全部参战物品。

没有为它保留特例，是因为「只给某一类物品加成」的通用解法应该是给 `StatModifier`
加一个标签过滤（顺带也能服务包体效果与邻接加成），而不是为套装单开一个枚举。
等真有内容需要时再加那个通用能力。测试里已把这条写成显式断言，不会被悄悄改掉。

其余未动：`LootEffect` 有数据、有测试，但消费方要等 M4；`MapEffect` 仍是空壳；
`data/items/` 的 15 个示例资产依旧没有战斗数据。

---

## 验证

```
通过  740 项断言，12 个套件，耗时 694 ms
```

新增套件 `tests/test_effect_tree.gd`（34 项断言），覆盖：

- `ChangeResource` 正负同一条路径；`RemoveStatus` 部分移除 / 全清 / 空操作
- `Target.BOTH` 同时打到双方
- `OnDamage`：类型匹配、类型不匹配、低于点数门槛、不限类型、`DEALT` 方向的吸血
  （并断言自伤不算「造成伤害」）
- `OnStacksAtLeast`：激活型不吃层数、消耗型扣层数、层数不够不触发、
  **另一条消耗付不起时层数不被白吃**
- `OnResourceBelow`：比例阈值与绝对值阈值，且回血不自激

写这套测试时撞到一个容易误判的地方，已写进代码注释：**一次派发里，被命中的规则会把
自己的效果全部执行完（资源当场就改了），它们发出的事件排在队列尾，之后才轮到派发。**
所以「同一条规则里先打两下」与「打一下、对方反应、再打一下」不是一回事 ——
凡是要观察反应的用例都得把两下拆进不同的战斗。

`tests/test_sets.gd` 相应重写，新增「道具自带的跨域效果」一组，
断言单件道具在棋盘上即生效、拿下即失效，不需要凑套装。
