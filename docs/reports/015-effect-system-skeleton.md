# 015 · 效果系统骨架

对应架构文档 v1.0：4.4 效果系统、4.5 战斗内增益系统。**M2 第二步，开始动代码。**

## 目标

把四层效果系统、资源池与 buff 系统实现出来，并把 `CombatProfile` 里写死的
「是否主动 + 冷却秒数」拆掉。

## 产出

| 文件 | 职责 |
|---|---|
| `battle_event.gd` | 事件名与 reason 常量；`VIEW_EVENTS` 区分回放事件 |
| `resource_pool.gd` | 生命／耐力／法力统一容器，上限联动 |
| `trigger.gd` / `cadence.gd` / `cost.gd` / `effect.gd` | 四层抽象基类 |
| `ability_rule.gd` | 时机 · 频率 · 消耗 · 内容 |
| `buff_def.gd` / `buff_instance.gd` | buff 定义与实例 |
| `combatant_runtime.gd` | 编译快照 + 活跃 buff，资源自动派生 |
| `rule_runtime.gd` / `rule_context.gd` / `battle_context.gd` | 规则状态、求值上下文、事件总线 |
| `rule_engine.gd` | 四层求值与派发 |
| `effect_registry.gd` | 类型名 → 脚本路径 |
| `triggers/` ×4、`cadences/` ×6、`costs/` ×2、`effects/` ×3 | 初期子类 |
| `compiled_item.gd` / `combatant_spec.gd` / `combat_profile.gd` | 改造 |
| `tests/test_effect_system.gd` | 新套件，68 项断言 |

`Ability` 改名 `CompiledItem` —— 它承载的已不止「一个能力」，一件物品可以有多条规则。
`CombatantSpec.abilities` 相应改为 `items`，`item_stats` 字典并入 `stats_of(uid)`。

## CombatProfile 的去硬编码

```gdscript
# 改造前
@export var is_active: bool
@export var cooldown_sec: float
@export var base_stats: Dictionary

# 改造后
@export var base_stats: Dictionary
@export var rules: Array[AbilityRule]
```

「是否主动」由 `rules` 是否为空决定；冷却成了 `CooldownCadence` 的参数。
按冷却自动出手只是 `OnTick + CooldownCadence + DealDamage` 这一种组合，不再享有特权。

## 实现中发现并修掉的五个问题

### 1. 属性差点被抹平成单位级（最严重）

初版 `CombatantRuntime.from_spec` 把所有物品的属性加总成一份单位级属性表。
那样「磨刀石只给旁边那把武器加伤害」会**彻底失效** —— 而这正是这个品类的核心。

改为按物品保留粒度：`item_base: uid -> StatSet`，buff 再逐个叠加上去。

由此分出两种取值：伤害／冷却／消耗这类**属于单件物品**的走 `item_stat(uid, key)`，
生命上限／护甲这类**属于整个单位**的走 `stat(key)`。测试里钉了一条：
同一单位下两把剑的伤害必须不同。

### 2. 每帧时长不能写成 `ONE / hz`

`65536 / 20 = 3276.8` 被整数除法截断成 `3276`，20 帧只走 `0.9997` 秒，
冷却永远差一点，而且误差随战斗时长累积。

改用「累计时刻之差」`StatMath.tick_delta(i, hz)`，把余数精确摊到各帧，20 帧之和恰好为 `ONE`。
这个 bug 由测试直接抓出：7 条断言全部差一帧。

### 3. 日志与派发必须分开，否则掩码根本无法验证

报告 012 定的不变式是「掩码开／关两条路径产出逐条相同」。但如果被掩码挡掉的事件
连日志都不进，两条路径的日志天生就不一样，这条不变式**永远不可能成立**。

改为：`BattleEvent.VIEW_EVENTS` 定义回放需要的事件，**日志只收这些且与掩码无关**；
掩码只决定要不要派发给规则。`tick` 不是回放事件，因此无人订阅时连对象都不构造。

这一点在写测试时才暴露 —— 设计文档里没写清楚。已是实现里的显式注释。

### 4. `can_fire` 必须只读，但 `EveryNth` 要数没执行的次数

`Cadence.can_fire` 契约是只读，可「每 3 次执行一次」必须把没执行的那两次也数上。

加了 `Cadence.on_match(ctx)` 钩子：时机命中后立刻调用，无论最终是否执行。
计数在这里累加，`commit` 时清零。

### 5. 资源事件的回调造成引用环

`BattleContext.create` 里用 lambda 捕获 ctx 去连 `resources.changed`，
形成 `ctx → sides → resources → 信号 → lambda → ctx` 的环。`RefCounted` 永不释放，
表现为退出时 `25 resources still in use at exit`。

改为 `CombatantRuntime.bind_context()` 持 `weakref(ctx)`，信号连到自身方法。

## 验证

```bash
bash tools/test.sh
```

```
======================================================
通过  595 项断言，10 个套件，耗时 2209 ms
======================================================
EXIT=0
```

新套件覆盖：

- **资源池**：实际变化量而非请求量（打到 0 封顶时「请求 999 实际只扣 70」）、
  上限增加时当前值同量增加、上限降低时截断、联动事件 `reason = max_changed` 而非 heal
- **运行时**：资源由 `max_*` 自动派生、buff 每层一份、`max_stacks` 封顶、层数归零移除、
  时长过期、**按物品粒度的属性**
- **四层求值**：冷却按时触发、开局触发、`EveryNth` 把没执行的次数也计入
- **消耗语义**（本步重点）：付不起时效果被跳过；随后补满耐力**不会立刻出手**，
  证明失败那次冷却确实已消耗；消耗层内部原子 —— 层数不够时耐力也不许扣
- **事件掩码**：掩码开与全开的最终状态与日志**逐条相同**；无人订阅且非回放的事件不入队；
  回放事件无人订阅也照记；**施加带 rules 的 buff 后掩码已重算**（否则灼烧静默失效）
- **连带触发**：只是订阅 `item_fired` 的普通触发器，不是特例
- **派发保护**：自我循环被上限挡住并记 `DISPATCH_OVERFLOW`，不会栈溢出

### 一处测试自身的建模错误

灼烧初版让 buff 的伤害效果打 `OPPONENT`，结果打到了施法者身上。
正确模型是：debuff 挂在受害者身上，它的规则就在受害者的 runtime 上跑，目标应为 `SELF`。
实现无需改动，测试已修正并补了 `_self_damage` 辅助函数说明这一点。

## 遗留

- **`BattleSim` 尚未实现**。测试里有个 20 行的最小等价物（推进帧 → 广播 tick → 排空队列），
  下一步把它做成正式的模拟循环。
- 套装效果（4.6）尚未实现，编译器里还没有这一步。
- `OnItemFired.source_uids` 目前需手工填写，将来应由编译期从邻接标记自动推导，
  从而表达「我的增益格上的物品出手时我也跟着出手」。
- `ChanceCadence` 在 `can_fire` 里掷骰，因此即便最终没执行随机流也已推进。
  结果仍确定，但 `AllOf` 里各环的顺序会影响随机序列，代码注释已标明不要随意重排。
- 状态效果（Heat / Cold / Stun）尚未建模；`ApplyStatus` 已能施加任意 buff，
  这些只是内容层面的 buff 定义，不需要新代码。
- 示例资产仍未配 `combat`，延续报告 009 的遗留。

## 下一步

**016 · BattleSim**：正式的确定性模拟循环 —— 定步长推进、buff 时长、胜负判定、
输出完整事件日志。有了它就能跑批量平衡模拟。
