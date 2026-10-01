# 103 · 方案：战斗规则七条（武器 / 耐力 / buff 永续 / 加时与衰竭 / 自然 5 级 / buff 栏 / 冷却动画）

> 2026-10-01 ｜ 提议 · 作者已确认（七个待定项见末尾「作者已定」），待执行 ｜ 对应架构文档 4.4（效果系统）、4.5（buff）、4.6（伤害管线）、4.7（模拟循环）、4.8（表现层）

作者给了七条战斗设计（2026-10-01）。本文逐条写清**现状**、**改法**、**要动哪里**、**和现有规矩的冲突**；数值与几处取舍留在末尾「待作者定」。
不含实现与测试，交执行 thread。

一句话概括改法：**四条是「规矩落到导入器与架构文档里」（1、2、3、6），两条是「新机制」（4、5 合为一件事：加时系统 + 自然 5 级改接加时），一条是回放层的新能力（7），排在前六条之后。**

## 现状（已核实）

| 条 | 现在的样子 | 出处 |
|---|---|---|
| 1 武器必造成伤害 | 内容层**已经满足**：17 件带 `weapon` 标签的道具都有 `deal_damage`。但没有任何检查守它；导入器只在敌人身份标签那里数「圈里有没有武器」（`content_importer.gd:835`） | `data/authoring/items/*.json` |
| 2 只有武器耗耐力 | 耐力消耗是规则上的一条 `ResourceCost`（`resource_key` 默认 `stamina`，`core/battle/costs/resource_cost.gd:8`），**和标签没有任何关系**；架构文档 4.4 明说「默认消耗按物品类型给……写在物品定义里，不硬编码」。内容里 17 件武器全有耐力消耗；**撬棍**（`crowbar`，标签 `sealed / tool / burst / metal`，不是武器）也有一条耐力消耗 —— 这是现有内容里唯一违反第 2 条的 | `crowbar.json`、架构文档 4.4 |
| 3 buff 默认永续可叠 | `BuffDef` 默认 `max_stacks = 0`（不限层）、`duration_sec = 0`（永续），**默认值已经是作者要的**；085 的规矩「可叠层一律永续，不许填时长」由 `validate_buff_duration` 守着（`content_importer.gd:153`），道具内联 buff 也查。会过期的只有 `max_stacks == 1` 的（标记 8 秒之类） | `core/battle/buff_def.gd:19-50` |
| 4 加时 / 衰竭 | 没有。战斗只有一个**时限**：`NodeRules.battle_time_limit`（默认 60 秒，`node_rules.gd:39`），到点谁都没倒就 `winner = -1` 平局（`battle_sim.gd:135-141`）；平局在一局里按输算（`node_events.gd:569` 的 `won := winner == 0`）。沙盒与猎手校准各自传 30 秒 / 自己的时限 | `core/battle/battle_sim.gd` |
| 5 自然 5 级 | `DrawIsWinPerk` 在战斗单位上立字符串旗 `spec.flags["draw_is_win"]`，`BattleSim.run` 收尾读旗把平局改成我方赢（`battle_sim.gd:30`）；097 的 P4 已点名这类旗是反向依赖，101 第 5 刀准备把它改成类型化字段 | `core/run/faith/perks/draw_is_win_perk.gd`、`nature.json:75` |
| 6 buff 栏显示一切 | 面板按日志里的 `status_stacked / unstacked` 事件记层数（`battle_view.gd:186-190`），**事件来自哪一方都收**，所以对手打在我身上的减益已经会显示。但图标 / 悬浮窗要查定义表，定义表是开战前从**双方道具与套装 / 信仰规则**里收集的（`Glossary.buffs_in_spec`，`glossary.gd:182`）—— 不在那里的 buff（将来的系统 buff、局外 buff 的规则施加的）会画成没有名字的格子。层数一律画成 `×n`，不可叠层的也画 `×1` | `ui/battle/combatant_panel.gd:189-210` |
| 7 冷却动画 | 回放层**不画棋盘**，只在面板右下写一行「▸ 最后出手的道具名」（`combatant_panel.gd:123, 213`）；`item_fired` 事件只带 `uid`（`rule_engine.gd:39, 97`），没有「下次就绪时刻」，回放层算不出冷却进度。倍速 = `_now += delta × SPEEDS[idx]`（1 / 2 / 4，`battle_view.gd:21, 145`），一切动画只要跟着 `_now` 走就自然受倍速影响 | `ui/battle/battle_view.gd` |

## 方案

### 第 1 条 · 带武器标签的道具必须造成伤害

规矩进导入器，和 085 的 buff 时长规矩同一个位置、同一种写法：

- `ContentImporter._validate_item_combat`（新，`import_item` 里调）：`def.tags.has(&"weapon")` → `combat.rules` 里至少一条规则的 `effects` 直接含 `DealDamage`，否则 `report.error("tags", "「%s」带武器标签却不造成伤害")`。
- **只认道具自己规则里的 `deal_damage`**，不认「施加一个会掉血的 buff」（灼烧之类）：那是「施毒」，不是「武器」。要让毒刃算武器，就给它一条直接伤害。
- 反向不限制：不带武器标签的道具也可以造成伤害（陷阱、毒药瓶）。

### 第 2 条 · 只有带武器标签的才消耗耐力

- 同一个校验函数里：任何规则的 `costs`（含扳机隐含的 `implied_costs()`）里有 `resource_key == stamina` 的 `ResourceCost` → 道具必须带 `weapon`，否则报错。角色技能、猎手定义、事件里目前没有耐力消耗（扫过 `data/authoring`，`"type": "resource"` 只出现在道具里），所以只查道具就够。
- **不要求武器一定耗耐力**：4.4 的「不耗耐力的武器只是 `costs` 为空的武器」保留（096 已经有「毒药瓶不耗耐力」这种作者决定）。作者若要「武器必耗耐力」，是另一条规矩，见待定 1。
- 内容：`crowbar` **加 `weapon` 标签**（作者定：按这件道具的本质，它是把钝器）。它已有 `deal_damage`（14 点、冷却出手、耗 12 耐力），加了标签后第 1、2 条都满足，不用再改规则。
- `StaminaEstimate`（084 的低 / 中 / 高）不用改：它本来就只数规则上的 `ResourceCost`。
- 架构文档 4.4「默认消耗按物品类型给」那一段改写成：**耐力是武器专属资源**；法力归法术书类，仍按物品定义给。

### 第 3 条 · buff 如无说明永续、可叠

代码默认值已经是这样，缺的是**把它写成规矩并让作者在设计数值时看得见**：

- 架构文档 4.5 开头加一段「默认永续、默认可叠；不可叠或会过期的必须在定义里**显式**写 `max_stacks: 1`（和可选的 `duration_sec`），导入器守着（085）」。
- `Glossary.describe_buff` 第一行现在写「增益　不限层　永续」—— 保留；**不可叠层**与**会过期**是例外，词条里把这两种标成例外颜色（和 096 的灰字一样处理），让作者 / 玩家一眼看出「这个不是默认」。
- 数值设计要考虑「不限层 + 永续」：导入器加一条**告警**（不是错误）：`max_stacks == 0` 且 `mods` 里有乘区百分比（`mult_percent != 0`）→ `report.warn("…不限层且按百分比乘，加时后会失控，确认上限")`。作者看着告警决定要不要填 `max_stacks`。
- 和第 4 条的关系：加时 buff 本身就是「不限层、永续、不可解除」，正是默认形态；衰竭同理。

### 第 4 条 · 加时（30 秒起受伤 +20%，每 5 秒再叠一层）与衰竭（60 秒起掉固定生命上限直到一方倒下）

**原则：不在 `BattleSim` 里写特例，用两个「系统 buff」表达**，和灼烧「挂在 buff 上的规则」一个思路（4.5）。模拟循环只多一种「系统时刻」。

#### 4a · 数值放哪

`NodeRules` 已经有 `battle_time_limit`（每章可配）。旁边加一个子资源：

```gdscript
# core/battle/overtime_rules.gd（新，Resource，纯数据）
class_name OvertimeRules
@export var starts_at_sec: float = 30.0        ## 加时从第几秒开始
@export var stack_every_sec: float = 5.0        ## 之后每隔几秒再叠一层
@export var damage_taken_percent: int = 20      ## 每层：受到的伤害 +N%
@export var decay_starts_at_sec: float = 60.0   ## 衰竭从第几秒开始
@export var decay_every_sec: float = 1.0        ## 每隔几秒掉一次
@export var decay_amount: float = 5.0           ## 每次掉多少生命上限（固定值，作者定）
```

`NodeRules.overtime: OvertimeRules`（没填用默认），导入器校验正数且 `decay_starts_at >= starts_at`。`BattleSim.run(a, b, rng, time_limit, overtime)` 多收一个参数；`node_events.gd:567` 从 `rules` 传；沙盒与猎手校准传默认（**校准必须带加时**，否则猎手强度表和真打对不上）。

#### 4b · 两个系统 buff

由 `OvertimeRules.buffs()` 在代码里造（不是内容文件 —— 100 已把 `buffs` 种类移出管线，而且这两个是规则不是内容）：

| id | 形态 | mods |
|---|---|---|
| `overtime`（鏖战） | 不限层、永续、`system = true` | 每层 `damage_taken` 乘区 +20% |
| `decay`（衰竭） | 不限层、永续、`system = true` | 每层 `max_hp` 固定 −`decay_amount` |

- `BuffDef` 加 `@export var system: bool = false`：**不可解除**（`RemoveStatus` / `StatusStackCost` 对它一律 0 层；`remove_buff_stacks` 在入口挡），面板画成第三种颜色，词条侧窗写「系统效果，不可解除」。
- `damage_taken` 是**新属性** `BattleStats.DAMAGE_TAKEN`（倍率，基准 1.0，走 4.3 乘区）。**作者定：放大的是角色受到的「最终伤害」** —— 伤害管线第 4 步算完百分比、固定增减、反转、护甲之后，在落到血量之前：`if amount > 0: amount = mul(amount, victim.stat(DAMAGE_TAKEN))`，然后才 `packet.final = amount`。所以护盾吸收（第 2 步）、减伤 / 免疫（第 3 步）、护甲都按原值算，**最后扛下来的那部分**乘倍率；治疗（反转、负数）不放大。`damage` 事件的 `amount` 带的是放大后的实际扣血，回放飘字自然对得上。顺带，`damage_taken` 以后也能给内容用（「易伤」减益就是一条作用于它的普通 mod），不是加时专用。
- 掉生命上限走现有的 `max_hp` mod：`CombatantRuntime._rebuild` 已把 buff 的 mods 并进 `max_hp`，`_sync_resource_maxes` → `ResourcePool.set_max` 会把当前血夹到新上限（`resource_pool.gd:69-86`）。**缺的一步**：上限掉到 0 不会判死 —— `set_max` 只发 `resource_changed`，没人调 `mark_dead`。加在 `CombatantRuntime._on_resource_changed`：`key == hp` 且 `reason == max_changed` 且当前血 ≤ 0 → `mark_dead()`，并由 `_rebuild` 的调用方发 `DIED`。这样蛮神的不死照常生效：`mark_dead` 自己判「有不死且没用过 → 进坚持期」（`combatant_runtime.gd:313-324`），坚持期到了再真倒下。

#### 4c · 模拟循环只加「系统时刻」

`_next_instant` 现在取「时间轮堆顶」与「最近的 buff 到期」的较小者（`battle_sim.gd:70-76`）；加第三个来源 `_next_system_instant(ctx)`：下一次加时叠层时刻、下一次衰竭时刻（按规则表算，纯函数）。`_resolve_instant` 顺序改成：回复结算 → 坚持期判定 → **系统时刻（给双方叠 `overtime` / `decay`，发 `status_stacked`）** → buff 到期 → 规则出手。放在到期之前，是因为「这一刻起的出手就该吃这一层」，和「到期的不再加成」是同一条边界原则。

#### 4d · 不再有平局

- 衰竭保证有限时间内必有人倒下（上限 / 每次掉的量 × 间隔 + 60 秒）。`battle_time_limit` 降级成**安全上限**（默认改成远大于衰竭所需，例如 600 秒），到了就 `push_warning` 并按 `_winner` 判。
- **同一刻双双倒下**（衰竭把两边的上限同时压到 0、或一下互杀）现在是 `-1`：改成有裁决：先比倒下前那一刻的当前血量（多者胜），再比这场造成的总伤害（`BattleResult` 已有日志可算），都相同判**玩家**（side 0）—— 见待定 4。`BattleResult.is_draw()` 保留但只在安全上限那条路上为真；`_winner` 的 `-1` 只剩这一种来源。
- 日志加两条事件 `OVERTIME_STARTED` / `DECAY_STARTED`（只发一次，给回放写一行「鏖战开始」「衰竭开始」用），叠层本身走普通的 `status_stacked`。

### 第 5 条 · 自然 5 级：加时阶段大量回血

- **删** `DrawIsWinPerk` 与 `spec.flags["draw_is_win"]`（101 第 5 刀的名单上少一条旗）。
- 新的 `OvertimeRegenPerk`（`core/run/faith/perks/overtime_regen_perk.gd`）：`modify_spec` 往 `spec.set_rules` 追加一条规则（和 `LowHpEmpowerPerk` 同一做法，`low_hp_empower_perk.gd:20`）：
  - 时机 `OnStacksAtLeast(buff_id = overtime, stacks = 1, on_self = true)`（现成扳机，`on_stacks_at_least.gd`）
  - 频率 `Always`，内容 `ApplyStatus(SELF, 回春 buff)`；「回春」`max_stacks = 1`、永续、mods `regen_hp` 固定 +`amount`（`amount` 由 perk 的字段给，`nature.json` 填）。
  - 它是**普通 buff**（不是 system），所以会出现在 buff 栏（第 6 条），也能被对手净化 —— 这是信仰效果而不是系统规则，该可解除。
- `nature.json:75` 改成 `{"type": "overtime_regen", "tier": 5, "amount": N}`；`EffectRegistry` 的 perk 表换名。
- 「大量」是多少见待定 5。回血走 `regen_hp` 属性，4.5 说过「不用新机制」，这里也一样。

### 第 6 条 · 所有 buff 都进 buff 栏并显示层数

现在的缺口只有一个：**定义表靠开战前猜**。改成**日志自足**（4.8 的原则）：

- `BattleContext` 记 `seen_buffs: Dictionary`（id → `BuffDef`），`CombatantRuntime.apply_buff` 每次上身登记一笔；`BattleResult.buffs = ctx.seen_buffs`。
- `BattleScreen` / 沙盒不再调 `Glossary.buffs_in_spec` 拼表，直接 `view.set_buff_defs(result.buffs)`。**凡是真的上过身的 buff，定义必然在表里**，不管来自自己、对手、信仰规则、局外 buff 的规则还是系统 —— 不需要再列举来源。`buffs_in_spec` 留给开局屏的预估用。
- 面板：`system` buff 第三种配色；不可叠层（`max_stacks == 1`）不画 `×1`，其余照画 `×n`；排序：系统 → 减益 → 增益，各组内按上身先后。
- **作者定的准则：影响战斗的就显示，不影响的不显示。** 据此，编译期并进属性的几种**外来加成**也要进栏，它们确实改了这场的数值，只是不是 `BuffDef`：
  - 信仰阶梯加成（`faith_bonuses`，`compiler.gd:87-99`）→ 一枚「信仰：某神 N 阶」常驻格，层数 = 达到的阶；
  - 套装档位（`set_mods`，`compiler.gd:79`）→ 一枚「套装名 N 件」常驻格，层数 = 档位；
  - 局外 buff / 一局 buff 的 `mods`（`RunBuffDef`）与角色技能的被动 → 各一枚，层数 1。
  - 做法：编译器在 `CombatantSpec` 上多一张 `passives: Array[PassiveNote]`（`{id, name, stacks, mods, note}`，纯数据），`BattleResult.initial` 带上；面板画成**第四组「常驻」**，灰底、不随事件变、悬浮窗列出它的 mods（`Glossary.mods_text`）。它们不是 buff，不走净化、不进 `seen_buffs`，只是显示。
  - **不进栏**的：包体加成（`bag_mods`）与邻接增益（`grant_mods / receive_mods`）—— 它们是棋盘摆法本身，4.8 已规定画在棋盘的格子上（角括号 + 点亮），再进栏就是同一件事画两遍。这一条是我的判断，作者若认为「摆法也算影响战斗」就把它们也做成常驻格，代码路径相同。

### 第 7 条 · 每件道具按冷却的旋转遮罩动画（受倍速影响）

排在前六条之后。能做成**只靠日志**的动画，不让回放层认识模拟：

- 日志补信息：`item_fired` 事件加 `ready_at`（定点，下一次就绪时刻 —— `CooldownCadence.commit` 刚算出来，`rule_engine.gd:97` 发事件时从 `rt.state[READY_AT]` 取）。耐力不够被跳过的那次（冷却已走、效果没出，`rule_engine.gd:84-91`）也发一条 `item_skipped {uid, ready_at}`，否则遮罩会在那一刻断掉。开战那一刻每件道具的首个 `ready_at` 写进 `BattleResult.initial`（`BattleContext.create` 排堆时已知）。
- 回放层画棋盘：`BattleView.set_boards(side, GridInventory)` 只读展示（4.8 本来就说「战斗中的物品图标直接复用 `InventoryView`」，现在只有沙盒做了）。每个棋盘上盖一层 `CooldownOverlay`（`Control`，`_draw`）：对每件带出手规则的道具，按 `(now − fired_at) / (ready_at − fired_at)` 画一个**扇形遮罩**（`draw_colored_polygon` 的扇形，顺时针从 12 点起，覆盖格子区域 = `InventoryView` 给的像素矩形），就绪时消失。一件道具多条冷却规则时取最长的那条。
- **倍速**：进度一律从 `BattleView._now` 算，`_process` 里 `queue_redraw` —— 不用 `Tween` / `AnimationPlayer`（它们走真实时间，调倍速或 `seek` 就对不上）。`seek` 到任意时刻画面正确，因为进度是时刻的纯函数。
- 把「进度」抽成 `CooldownClock.progress(fired_at, ready_at, now) -> float` 一个静态函数，测试它而不测画法。

## 关键决策

- **规矩进导入器、不进运行时**（1、2、3）：和 085 的时长规矩一样，内容一导入就知道违规，战斗代码零特例。
- **加时与衰竭是 buff，不是模拟器里的 if**（4）：复用 4.3 公式、4.5 叠层、面板、词条，`BattleSim` 只多一种「系统时刻」；数值进 `NodeRules`，每章可调。
- **`damage_taken` 是通用属性**（4）：加时只是它的第一个用户。
- **自然 5 级变成一条普通规则**（5）：少一面字符串旗，和 101 第 5 刀方向一致。
- **buff 定义表由日志给**（6）：靠「上过身就登记」而不是靠列举来源，第 6 条才能是「所有」。
- **动画只看时刻**（7）：进度 = 时刻的纯函数，倍速与跳转免费正确。

## 与现有规矩的冲突（已对过）

| 冲突 | 处理 |
|---|---|
| 架构文档 4.4「默认消耗按物品类型给，不硬编码」 vs 第 2 条 | 不是硬编码，是**内容规矩**（导入器校验）；运行时仍只认规则上的 `costs`。文档那段改写 |
| 085「可叠层的 buff 永续」 | 不冲突，加时 / 衰竭 / 回春都符合；第 3 条只是把默认值写成明文 |
| 093 自然 5 级「平局算胜」、`test_author_093.gd:266-275` 的三条断言 | 整条替换：测试改成「加时开始后回春上身、回血速率变了」 |
| `CombatantSpec.flags` 的 `draw_is_win`（097 P4 / 101 第 5 刀） | 删掉；`undying_sec` 仍按 101 改类型化字段 |
| `NodeRules.battle_time_limit`（架构文档 2568 行「打不死判平局，平局按输算」） | 语义改为安全上限，文档同步 |
| 猎手校准（`hunter_bench.gd:27`）与沙盒（`battle_sandbox.gd:283` 传 30 秒） | 都改成传规则表（含加时），校准数据会变，094 / 093 的强度表要重跑一次 |
| 「倒下的不再受伤也不再被治」（087，`damage_resolver.gd:29`） | 衰竭不走伤害管线，不受影响；坚持期里上限继续掉也无妨（血已是 0） |
| 4.8「物品名不进日志」 | `ready_at` 是数值不是名字，符合「表现层需要什么日志就带什么」 |

## 验证（给执行 thread）

- 导入器：`tests/test_content_pipeline.gd` 加：武器无 `deal_damage` → 错；非武器带耐力消耗 → 错；不限层 + 乘区百分比 → 告警。全量内容导入零错误（`crowbar` 改完之后）。
- `tests/test_overtime.gd`（新）：双方木桩互殴 —— 29.9 秒 0 层、30 秒 1 层、35 秒 2 层；同一包伤害在 1 层下 ×1.2、2 层 ×1.4（定点精确）；护盾先吸原始值；治疗不被放大；60 秒起每秒上限 −N、当前血跟着夹；上限到 0 发 `DIED`；蛮神不死：到 0 进坚持期、到期才倒；净化对 `overtime` 无效；双双倒下按裁决出赢家、`winner != -1`；安全上限才会 `is_draw()`。
- 自然 5 级：`test_author_093` 那三条换成「加时开始 → 回春上身 → `regen_hp` 变大 → 血回升」。
- buff 栏：跑全部内容（每件道具对每个敌人各打一场）—— 日志里每个 `status_stacked` 的 id 都在 `result.buffs` 里；面板对 `max_stacks == 1` 不画 `×1`。
- 动画：`CooldownClock.progress` 的边界（未出手 = 0、就绪 = 1、`seek` 回退单调）；`item_fired / item_skipped` 都带 `ready_at`。
- 全套 `tools/test.sh` 绿；`tools/bench_battle.gd` 的事件数会涨（每秒多两条衰竭事件），记一下新基线。

## 改动范围

| 条 | 文件 |
|---|---|
| 1、2 | `core/authoring/content_importer.gd`（`_validate_item_combat`）、`data/authoring/items/crowbar.json`、架构文档 4.4 |
| 3 | 架构文档 4.5、`core/text/glossary.gd`（例外配色）、导入器一条告警 |
| 4 | `core/battle/overtime_rules.gd`（新）、`core/run/node_rules.gd`、`core/battle/battle_stats.gd`（`DAMAGE_TAKEN`）、`core/battle/buff_def.gd`（`system`）、`core/battle/damage/damage_resolver.gd`（一行）、`core/battle/combatant_runtime.gd`（上限归零判死、`remove_buff_stacks` 挡系统 buff）、`core/battle/battle_sim.gd`（系统时刻、裁决、安全上限）、`core/battle/battle_event.gd`（两条事件）、`core/run/node_events.gd:567`、`core/run/calibration/hunter_bench.gd`、`ui/battle/battle_sandbox.gd`、导入器校验 |
| 5 | 删 `draw_is_win_perk.gd`，新 `overtime_regen_perk.gd`，`EffectRegistry`，`data/authoring/faiths/nature.json`，`test_author_093.gd` |
| 6 | `core/battle/battle_context.gd`（`seen_buffs`）、`battle_result.gd`（`buffs`）、`combatant_runtime.gd`（登记）、`core/battle/compiler.gd` + `combatant_spec.gd`（`passives`）、`ui/game/battle_screen.gd`、`ui/battle/battle_sandbox.gd`、`ui/battle/combatant_panel.gd`（配色 / `×1` / 排序 / 常驻组） |
| 7 | `core/battle/rule_engine.gd`（`ready_at`、`item_skipped`）、`battle_context.gd`（初始 `ready_at`）、`ui/battle/battle_view.gd`（`set_boards`）、`ui/battle/cooldown_overlay.gd`（新）、`core/battle/cooldown_clock.gd`（新）、`ui/game/battle_screen.gd`（把双方棋盘交给回放） |

建议拆成三批交执行：**①** 1、2、3（导入器 + 文档，半天量）；**②** 4、5、6（新机制，一起做，因为 5 依赖 4 的 `overtime` buff、6 的日志自足是 4 的系统 buff 能显示的前提）；**③** 7。

## 作者已定（2026-10-01）

| 待定项 | 作者的决定 | 落在哪 |
|---|---|---|
| 1 武器是否必须耗耐力 | 「我的描述是严谨的」：规矩就是**只有带武器标签的才会耗耐力**，不加「武器必耗」这一条 | 第 2 条按原文写，导入器只查反向 |
| 2 `crowbar` | **加武器标签**（按道具本质，它是钝器） | 第 2 条「内容」一行 |
| 3 +20% 在哪一步 | 放大的是角色（玩家 / 敌人）受到的**最终伤害** —— 护盾、减伤、护甲都算完之后 | 4b |
| 4 双双倒下的裁决 | 可以：先比血量，再比总伤害，再判玩家胜 | 4d |
| 5 数值 | 按推荐（衰竭每 1 秒掉 5 点上限、回春 `regen_hp` +8 / 秒），**保留可调**：都在 `OvertimeRules` / `nature.json` 的字段里，不写死 | 4a、第 5 条 |
| 6 哪些进 buff 栏 | 准则只有一条：**影响战斗的就显示，不影响的不显示** | 第 6 条「常驻」组 |
| 7 战斗屏画棋盘 | 要 | 第 7 条 |

执行顺序照「改动范围」末尾的三批：① 1、2、3 → ② 4、5、6 → ③ 7。
