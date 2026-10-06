# 131 审计：编辑器里的规则能不能「任意条件 × 任意效果」随意搭配？还有哪些条件与效果可做而未做

> 架构 · 审计（2026-10-05）。作者问：「就目前的编辑器而言，是否能添加任意条件后触发任意效果，进行随意搭配？还有哪些效果和条件可以但还没有实装？」本篇只答问，不改东西；想做的部分列成候选清单，作者点了再写方案。

## 一、结论先说

**能，结构上是「任意 × 任意」**。一条战斗规则 = 时机 × 频率 × 消耗（列表，AND）× 效果（列表，顺序执行、共用一次消耗）（4.4 四层）。编辑器的下拉框直接从 `EffectRegistry` 的四张表生成（`ui/editor/content_editor.gd`：「表单由反射生成，效果类型下拉框来自 EffectRegistry」），四层之间没有白名单，任一时机配任一效果、任一消耗都能填、能存、能导入。现在的库存：**10 种时机、2 种频率、6 种消耗、9 种效果**（130 落地后的 `core/battle/effect_registry.gd`）。

真正限制搭配的只有两样，都是**有意的**：

1. **导入器的校验**（`core/authoring/content_importer.gd`，编辑器实时跑的就是它）—— 十来条，全是「这么配没意义或会炸」：
   - 规则必须有时机、必须有频率；`on_schedule` 得配 `cooldown`（`always` 配自发型 = 同一时刻无限触发）。
   - 带武器标签的道具至少一条直接造成伤害的规则；不带武器标签的不许消耗耐力（耐力只归武器）。
   - `deal_damage` 的 poison / bleed 只许写在 buff 的规则里（作者定：毒与流血天生是 buff）。
   - 附加规则（108，`grant_rules`）只许 `on_item_fired`、不许有消耗、一般写 `always`。
   - `on_status_applied` 听 X 又施加 X 是自环，拦（130）；`convert_status` 的 `to` 不能是 `from`。
   - 可叠层 buff 不许填时长（作者定：可叠的永续）；只有一条属性增减的 buff 会被**提示**改用标准轴（警告不拦）。
   - 技能被动 / 难度 / buff 的 `effects` 只放掉落与一局规则的效果，战斗效果必须带时机写进 `rules`。
2. **几种效果只在特定时机下有事可做**，配错了**静默跳过**（不报错，因为同一条规则可能被别的时机复用）：`modify_damage`、`reflect_damage`、`low_hp_empower` 只在 `on_before_damage` 里拿得到伤害包；`per_stack` 只在 buff 自带的规则里读得到来源层数。这是本篇建议补的第一条（§三 1）。

所以「随意搭配」的答案是：**填得进、存得下、跑得起来；拦的只是明显错的；少数「配了也没用」的组合不提示。**

## 二、现在的条件与效果，按「问的是什么」分一遍

把「条件」拆开看，本作的条件有两层：**时机**（等一个事件）与**消耗**（事件来了之后再检查 / 扣东西）。

| 想表达的 | 现在怎么写 | 够不够 |
|---|---|---|
| 定时出手 | `on_schedule` + `cooldown` | 够 |
| 开战时 | `on_battle_start` | 够 |
| 某件出手时（自己 / 邻居 / 对手的） | `on_item_fired`（`same_side`、`source=ANY / LINKED`、`include_self`） | 缺「只听带某标签的件」（§三 3） |
| 资源变动 / 跌破阈值 | `on_resource_changed`（方向、原因）、`on_resource_below`（百分比或绝对值） | 缺「涨过阈值」「回满」（§三 2） |
| 攒到 N 层 / 轴到 N 层（可消耗） | `on_stacks_at_least`、`on_axis_at_least`（层数变化那一刻求值） | 够 |
| 受到 / 造成某类伤害前、后 | `on_before_damage` / `on_damage`（方向、类型、门槛） | 缺「暴击时」（§三 2） |
| 某状态被施加时 | `on_status_applied`（130） | 缺「某状态掉光时」（§三 2） |
| 概率、次数、充能、资源、层数（扣）、层数（不扣） | `chance` / `uses` / `charge` / `resource` / `status_stack` / `status_condition` | 缺「资源在某范围」「轴至少几层」当条件（§三 4） |
| 伤害、增减资源、施加 / 移除 / 转化状态、改轴、改这一包、反弹、低血增伤、火焰附魔 | 9 种效果 | 缺的见 §三 5 |

**没有的组合子**：条件只有 AND（消耗列表全过才付）。没有 OR、没有 NOT。要「A 或 B」现在写两条规则（各一次消耗）；要「没有 X 时」写不出来。这是结构上的空缺，不是漏了一个类（§三 6）。

## 三、可做而未做（按价值排，都是「加一个脚本 + 注册表一行」，不动引擎主体，除非注明）

### 1. 编辑器提示「配了也没用」（最便宜、最该先做）
导入器加三条**警告**：`modify_damage / reflect_damage / low_hp_empower` 不在 `on_before_damage` 下；`per_stack` 写在道具规则（不是 buff 规则）里；`on_schedule` 配 `always`（现在是错，确认一下是否真拦了）。不改引擎。

### 2. 时机（Trigger）
| 候选 | 意思 | 代表用法 |
|---|---|---|
| `on_status_removed` | 某状态**掉光**（最后一层被移除 / 到期）时，`on_self` | 「中毒结束时引爆一次」「护符结界破了回一口血」；和 `on_status_applied` 成对，事件在 `CombatantRuntime` 移除层数处发 |
| `on_resource_above` / `on_resource_full` | 资源涨过阈值 / 回满 | 「耐力满了多打一发」「护盾满了反弹」；`on_resource_below` 的镜像，一个字段 `direction` 就能合并 |
| `on_crit` | 自己的直接伤害暴击时（104 的暴击在伤害管线里有旗子） | 「暴击时加一层嗜血」；暴击流派的起点 |
| `on_item_fired` 加 `source_tags` | 只听带某标签的件（`weapon` / `ranged` / `melee`） | 「每当远程武器出手」—— 现在只能 ANY 或贴邻；补这个字段，不加类 |
| `on_overtime` | 加时开始时（103 的系统 buff 已经有这个时刻） | 「加时前打不完就自爆」；拖长战斗的反制件 |
| `on_battle_end`（**不建议**） | 战斗结束 | 战斗内已没有可做的事；跨域的「战后回血」属一局层，走 `RunHooks`，不是战斗时机 |

### 3. `on_item_fired` 的来源筛法
同上表第四行，单列出来是因为它是**最常被问到的**：「跟着某类武器」。现在只有「全部」「贴邻」「uid」。补 `source_tags: Array[StringName]`（任一命中）。

### 4. 消耗 / 条件（Cost）
| 候选 | 意思 | 代表用法 |
|---|---|---|
| `resource_condition` | 资源在某范围（百分比或绝对值，`on_self`），**不扣** | 「生命高于七成时伤害 +20%」「对手耐力见底时必暴」；`on_resource_below` 是时机（变化那一刻），这个是**出手时检查** |
| `axis_condition` | 某条轴至少 / 至多几层，不扣 | 「加速到五层后每次出手附带流血」 |
| `axis_cost` | 扣轴的层数 | 「消耗三层强攻打一记重击」；`shift_axis` 的消耗面 |
| `not`（**结构**） | 把一条条件取反 | 「对手**没有**流血时先挂上」；最省的做法：给 `status_condition` / `resource_condition` / `axis_condition` 各加一个 `negate` 勾，不做通用组合子 |
| `or`（**不建议**） | 任一通过 | 写两条规则就是 OR；引入组合子要改消耗层「全付得起才付」的原子性 |

### 5. 效果（CombatEffect）
| 候选 | 意思 | 代表用法 / 为什么现在写不出 |
|---|---|---|
| `deal_damage` 加 `percent_of`（`max_hp` / `current_hp` / `missing_hp`，看谁的） | 按生命比例的伤害 | 「处决：对手生命低于三成时造成其最大生命一成的伤害」；现在只有固定值 / 属性值 |
| `deal_damage` 加 `per_target_stack` | 按**目标身上**某状态的层数乘 | 「每层流血多打两点」—— `per_stack` 只读来源 buff 的层数（130 放血刀因此只能固定 18） |
| `lifesteal`（或 `change_resource` 加 `percent_of_damage`） | 回这一包伤害的若干成 | 吸血现在是固定值（目录「吸血」示例 +4）；按比例要能读到 `ctx.damage()`，所以是 `on_damage` 下的新效果 |
| `remove_status` 加 `all_debuffs` / `all_buffs` | 一次清光一类 | 净化现在只能按 id 清一种；`is_debuff` 已经有，筛起来是一行 |
| `convert_damage_type` | 把正在结算的这一包改成另一种类型 | 「你的物理伤害变成火焰」（D4 灌注的另一半）；`on_before_damage` 下，和 `modify_damage` 同族 |
| `reset_cooldown` / `advance_cooldown` | 把某件（自己 / 贴邻 / 带标签的）的冷却清零或推进 N 秒 | 「暴击时下一发立刻就绪」；要给 `CooldownClock` 开一个按 uid 的入口，**动引擎一处** |
| `refire` | 让一件（自己 / 贴邻）立刻再出手一次（付不付消耗可选） | 「连击」「反击时用武器打回去」；比 `reset_cooldown` 直接，但要防自环（导入器拦 `include_self`） |
| `set_resource` | 把资源设成某值 / 某比例 | 「耐力清零换一次大招」；`change_resource` 只会加减 |
| `disable_item` / 「沉默」 | 让对手某类件若干秒不出手 | 控制流派的起点；**没有的机制**：规则没有「禁用」状态，要在 `RuleRuntime` 加一个暂停旗，是本表里改动最大的一项 |
| `grant_rule_temp`（**不建议**） | 临时给自己挂一条规则 | `apply_status` 的 buff 自带 `rules` 已经是它 |
| `spread` / 群体（**不适用**） | 施加给所有敌人 | 本作一对一 |

### 6. 结构性的（改动大，单独成方案才做）
- **条件组合子**（OR / NOT 通用）：改四层模型里「消耗 = AND 列表」的约定；上面用 `negate` 勾解决八成需求，先不做。
- **按件的时机筛选**（「贴邻的那把弓暴击时」）：`on_item_fired.source` 的 LINKED 思路推广到所有时机，等真有内容要它。
- **战斗外的条件 / 效果**（一局层）：事件层已有 12 种条件、14 种后果（`RunRegistry.EVENT_CONDITIONS / EVENT_OUTCOMES`），与战斗规则是两套；道具跨域效果走 `Effect` 树按作用域分支（9.2）。「道具在地图上触发」这类要新作用域，见架构 14 的预留。

## 四、建议的顺序

1. §三 1（导入器三条警告）—— 半天。
2. `on_item_fired.source_tags`、`resource_condition`、`deal_damage.per_target_stack` + `percent_of`、`remove_status.all_debuffs`、`on_status_removed` —— 各一个脚本或一个字段，一起一份方案；这五样加上 130 的三件，流派内容基本就不再被构件卡住。
3. `on_crit`、`lifesteal`、`convert_damage_type`、`axis_condition / axis_cost`、`negate` —— 等有具体道具点名再做。
4. `reset_cooldown / refire / disable_item` —— 动引擎，各自成方案。
