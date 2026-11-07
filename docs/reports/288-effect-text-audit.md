# 288 效果说明文本普查：每条玩家看得见的效果 / 状态 / 反应 / 伤害类型说明对照代码

> 作者 2026-11-07 15:00（游戏反馈小修线程，经协调转来）：「检查其他效果的说明文本与实际机制匹配」。起因：流血每跳减半没写清（那一条小修自己改）。直接指派：普查结果本篇，修改按推荐派执行。

## 〇 一句话

把 `buffs / damage_types / reactions / belt_skills / faiths` 五个数据目录、词条表（`glossary.gd`）、悬浮窗句式（`item_tooltip.gd` + `ui_text.gd`）和写了具体数字的帮助页逐条对照代码：**17 条不符**（10 条确定、7 条疑似或暂无内容触发），其余几十条一致。最该修的是**负重三档的阈值**（文字写「超过上限 / 1.25× / 1.5×」，数据是 1.2 / 1.6 / 2.2）、**寸步难行「倒计时 −2」其实是 ×2**、**流血没标减益**（不只文字错：清增益会把对手的流血洗掉、净化清不掉）。全部是改文字或改一个数据字段，只有第 8 条是设计问题要作者定。

## 一、不符项一览（细节见 §四）

| # | 置信 | 在哪 | 文字说 | 代码做 | 改法 |
|---|---|---|---|---|---|
| 1 | 确定 | 词条 吃力 / 超重 / 寸步难行 / 负重；帮助页 encumbrance | 超过上限 / 1.25× / 1.5× | 1.2× / 1.6× / 2.2×（严格大于） | 改文字为 1.2 / 1.6 / 2.2；帮助页改成「两成 / 六成 / 一倍二」，最好占位符从数据读 |
| 2 | 确定 | 词条 寸步难行；`run.load_step_cost` | 走一步倒计时 −2 | 行动点 ×2（传送 3 步扣 6） | 「倒计时翻倍」；键改「走一步倒计时 ×%d」 |
| 3 | 确定 | `buffs/bleed.json` | 悬浮窗写「增益」 | 缺 `is_debuff`：清增益洗掉流血、净化清不掉 | 补 `"is_debuff": true`（数据修复） |
| 4 | 确定 | 帮助页 shop | 回定价的一半 | `shop_sell_ratio` 0.3 | 「回定价的三成（带回基地五成）」 |
| 5 | 确定 | 帮助页 vitality | 安德烈乌斯首次战败免罚 | 没有任何 `free_losses`；他现在是「求饶」 | 改成求饶那句 |
| 6 | 确定 | `perk.gift_summary`（大地三阶赐物） | 事件-饰品 / BOSS-珍宝 | event: 饰物 + 素材；core: 贵重品；elite 含盾 | 按 `by_type` 生成，不写死 |
| 7 | 确定 | 词条 负重 | 包本身也算 | 包一律 0 | 「包本身不算重」 |
| 8 | 确定 | 帮助页 direct_damage_and_block | 持续伤害不触发回应规则 | 扳机只看伤害类型 `provokes`：灼伤 / 燃血的火焰跳会点亮「受伤时」 | **待定 1**：改文字，或改代码让 buff 来源一律不 provoke |
| 9 | 疑似 | `gloss.next_fire_cooldown`（寒冷） | 下一次出手的冷却 +N% | 只对 `weapon` 标签 | 「武器下一次出手的冷却 +N%」 |
| 10 | 疑似 | reactions fire_bleed / poison_bleed；`gloss.time_per_stack` | 每层持续一秒 | N 层每秒 N 点撑 N 秒（层数不掉） | 「N 层就每秒 N 点、持续 N 秒，再反应加层加秒」 |
| 11 | 疑似 | damage_types drain | 不触发受伤时的效果 | 还无视护甲 | 补「无视护甲」 |
| 12 | 疑似 | reactions fire_poison 爆燃 | 再叠一半层数的灼伤 | 向下取整，1 层不叠 | 补「（向下取整）」 |
| 13 | 疑似 | 词条 耐力 | 等回够再动 | 不够就跳过这一次、冷却重走 | 改句 |
| 14 | 疑似 | 帮助页 buffs_and_stacks | 举例「中毒换剧毒」 | 没有任何内容用 `convert_status` | 删例子或改成电解 |
| 15 | 疑似（无内容触发） | `ConvertStatus.describe` | 「毒素转为剧毒」 | 用了伤害类型名 | 改用 `Glossary.status_name` |
| 16 | 疑似（无内容触发） | `ChangeResource / ShiftAxis / ApplyStatus.describe` | 不写 `per_stack / percent_of_damage` | 一旦内容用上就写成「回复 0 点」 | 补句式 |
| 17 | 已知 | 词条 流血 / 生成文字 | 没写每跳减半 | `rule_engine.gd:31` | 小修在改，不重复 |

## 二、改动清单（执行）

1. 文字：第 1、2、4、5、7、9、10、11、12、13、14 条按「改法」列改（词条 `glossary.gd`、`ui_text.gd` 键、帮助页 json、reactions / damage_types 的 `description`，中英都改）。帮助页与词条里的负重阈值改成占位符从 `EncumbranceRules` 读，以后调数不再错。
2. 数据：`bleed.json` + `bleed.tres` 补 `is_debuff`；补一条测试「流血是减益：`all_debuffs` 能清、`all_buffs` 不动」。
3. 生成文字：第 6 条 `perk.gift_summary` 按 `by_type` 拼；第 15、16 条 `describe()` 补全。
4. 第 8 条等作者（待定 1）；没回音按推荐改文字。
5. 测试：现有的 `tests/content` 文案测试跟着改；新加「负重阈值文字 = 数据」「卖价帮助页 = `shop_sell_ratio`」两条对照测试，防止再漂。
6. 执行顺带核对 §四 第三节「不算错但值得知道」三条要不要写进帮助页（推荐不写，奥卡姆）。

## 三、待定（没回音按推荐）

| # | 事 | 推荐 |
|---|---|---|
| 1 | 第 8 条：灼伤 / 燃血的火焰跳点亮「受伤时」规则 | 改文字说清（「灼伤的火焰跳照样算受伤时」）；改代码让 buff 伤害一律不 provoke 会动平衡，要作者点头 |
| 2 | 阈值写死还是占位符 | 占位符从数据读 |
| 3 | §四 第三节三条要不要进帮助页 | 不写 |

## 四、普查全文（含 file:line、核对一致清单）


范围：`data/authoring/{buffs,damage_types,reactions,belt_skills,faiths}`、`core/text/glossary.gd` 的固定词条与 buff 生成文字、`ui/inventory/item_tooltip.gd` + `core/text/ui_text.gd` 的句式模板、`data/authoring/help_pages` 里写了具体数字 / 规则的页。只读代码，没有改动。

「流血每跳减半但词条没写」（`glossary.gd:56` / `Glossary.buff_effect_lines` 不出减半行）另有人修，这里只记一笔，不重复算。

置信度：**确定** = 文字与代码直接矛盾，代码路径读清楚了；**疑似** = 文字含糊 / 漏说，或只在特定内容下才显出矛盾。

---

### 一、不符项（按严重度排）

#### 1. 负重三级的阈值：词条、帮助页都写错了　【确定】
- 文字：
  - `core/text/glossary.gd:37` 「吃力：负重超过上限：急速 −10%、耐力回复 −10%。」
  - `core/text/glossary.gd:38` 「超重：负重超过上限的 1.25 倍：……」
  - `core/text/glossary.gd:39` 「寸步难行：负重超过上限的 1.5 倍：……」
  - `core/text/glossary.gd:36` 「负重：……超过角色的负重上限就开始吃力。」
  - `data/authoring/help_pages/encumbrance.json:9` 「超过上限就进入吃力……再超出上限的四分之一是超重……超出上限一半就寸步难行」
- 代码：`data/authoring/encumbrance_rules/standard.json:6/24/46` `over` = **1.2 / 1.6 / 2.2**（`data/encumbrance_rules/standard.tres` 同值）；`core/run/encumbrance_rules.gd:17 level_of()` 是 `weight > capacity × over`（严格大于）。即负重要到上限的 **1.2 倍**才吃力、**1.6 倍**超重、**2.2 倍**寸步难行；刚超上限什么都不发生。
- 建议改写：
  - 吃力：「负重超过上限的 1.2 倍：急速 −10%、耐力回复 −10%。」
  - 超重：「负重超过上限的 1.6 倍：急速 −25%、耐力回复 −25%、耐力上限 −20%。」
  - 寸步难行：「负重超过上限的 2.2 倍：超重的减益照旧，地图上每走一步（传送也算）倒计时翻倍；原地等待不翻倍。」
  - 负重词条末句：「超过上限的 1.2 倍就开始吃力。」
  - 帮助页：「超过上限两成就进入吃力……超过上限六成是超重……超过上限一倍二就寸步难行」（或把阈值做成占位符从数据读）。
- 备注：减益的数值本身（−10% / −25% / −20%）是对的：`regen_stamina −0.1`、`max_stamina −0.2` 按 `EncumbranceLevel` 的约定是基线比例（`encumbrance_rules.gd combat_mods` 乘基线）。

#### 2. 寸步难行的走路代价：「倒计时 −2」vs 代码是「×2」　【确定】
- 文字：`core/text/glossary.gd:39` 「……每走一步（传送也算）倒计时 −2」；`core/text/ui_text.gd:918` `run.load_step_cost` 「走一步倒计时 −%d」（填进去的是 `travel_mult` = 2，HUD 上显示「走一步倒计时 −2」）。
- 代码：`core/run/map_travel.gd:168` `action_cost × action_cost_mult`，`core/run/run_state.gd:757` 把 `travel_mult`（2）写进去。一步路扣 2，三步的传送扣 6，不是固定 −2。帮助页 `encumbrance.json` 写的「倒计时扣双倍」才是对的。
- 建议改写：词条「……每走一步（传送也算）倒计时翻倍；原地等待不翻倍。」；`run.load_step_cost` 改成「走一步倒计时 ×%d」。

#### 3. 流血（buff）没标减益：悬浮窗写「增益」，净化 / 清增益把它当增益处理　【确定】
- 文字：`Glossary.buff_kind()`（`glossary.gd:397`）按 `is_debuff` 写「增益 / 减益」；流血的名字行会写「流血　增益」。
- 代码 / 数据：`data/authoring/buffs/bleed.json` 没有 `"is_debuff": true`（`data/buffs/bleed.tres` 同样缺），而中毒 / 灼伤 / 寒冷 / 麻痹 / 剧毒 / 燃血 / 菌血都有。后果不止文字：`core/battle/effects/remove_status.gd` 的 `all_debuffs` 清不掉流血、`all_buffs` 反而会把对手身上的流血洗掉；`ChangeResource` 等不受影响。
- 建议：给 `bleed.json` 补 `"is_debuff": true`（这是数据修复，不是改文字）。

#### 4. 商店卖价：帮助页「回定价的一半」，数据是三成　【确定】
- 文字：`data/authoring/help_pages/shop.json:9` 「把自己的东西拖进出售区就是卖，回定价的一半。」
- 代码：`data/authoring/economy_rules/standard.json:12` / `prologue.json:11` `shop_sell_ratio: 0.3`；`core/run/economy_rules.gd:32` 注释「251（作者 2026-10-24）：数据里写三成，带回基地五成」。
- 建议改写：「……回定价的三成（带回基地卖是五成）。」

#### 5. 体力页：「安德烈乌斯首次战败于敌人时免罚」已经不存在　【确定】
- 文字：`data/authoring/help_pages/vitality.json:8` 「安德烈乌斯首次战败于敌人时免罚」
- 代码：免罚走 `RunContext.free_losses`（`core/run/node_events.gd:770`），但 `data/authoring` 里没有任何内容给 `free_losses`（`grep` 为空）；`data/authoring/characters/andreus.json` 的技能是「偷袭」+「求饶」（256 改成用金币和道具抵体力）。`characters.json` 帮助页写的求饶是对的，体力页是旧文字。
- 建议改写：「安德烈乌斯打输了能用金币和道具求饶抵掉体力损失（核心点不能）」。

#### 6. 大地之神三阶「赐物」的说明是写死的，和数据对不上　【确定】
- 文字：`core/text/ui_text.gd:870` `perk.gift_summary` 「战斗-武器 / 精英-防具 / 事件-饰品 / 撤离点-随机 / BOSS-珍宝」
- 代码：`core/run/faith/perks/gift_on_enter_perk.gd:6` `by_type`（`data/authoring/faiths/earth.json` 同）：`elite: [armor, shield]`、`event: [trinket, material]`、`extract: []`（= 任何非包道具）、`core: [valuable]`。「珍宝」是 `treasure` 标签，核心给的是 `valuable`（贵重品）；事件还会给素材；精英也可能给盾。`god_earth.json` 帮助页写的「战斗给武器、精英给防具、事件给饰物或素材、核心给贵重品」是对的，perk 一句错。
- 建议改写：「头一回踩上一个点就得一件对应类型的道具（战斗-武器 / 精英-防具或盾 / 事件-饰物或素材 / 撤离点-随机 / 核心-贵重品）」（最好按 `by_type` 生成）。

#### 7. 「负重」词条：「包本身也算」vs 代码「包不算重」　【确定】
- 文字：`core/text/glossary.gd:36` 「作战棋盘上所有东西（包本身也算）的重量之和」
- 代码：`core/inventory/item_weight.gd:12/28/37` 「161（作者定）：包不算重 —— 作为包的道具一律 0」；帮助页 `encumbrance.json` / `bags.json` 也写「包本身不算重」。
- 建议改写：「作战棋盘上所有东西的重量之和，包本身不算重；地上、保险箱、仓库里的不算。」

#### 8. 「直接伤害与格挡」帮助页：「持续伤害不会触发回应规则」—— 灼伤 / 燃血的火焰跳会触发「受伤时」　【确定】
- 文字：`data/authoring/help_pages/direct_damage_and_block.json:9` 「只有直接攻击会触发反伤、吸血这类回应规则，持续伤害不会」
- 代码：扳机过滤看的是伤害**类型**的 `provokes`（`core/battle/triggers/damage_trigger.gd:58`），不看直接 / 非直接。毒素、流血、反伤、流失 `provokes=false`，但灼伤 / 燃血打的是 `fire`（`core/battle/damage/damage_types.gd:94` `provokes=true`）。所以挨打方「受到攻击时」（`on_damage` TAKEN、不限类型，例：`data/authoring/items/thorn_seed.json` 绽放阶）会被每一跳灼伤点亮。反伤不会对轰（`reflect_damage.gd` 看 `source_side` 是自己就不弹）、攻击方的吸血不会（包的 `source_side` 是挨打方自己，`deal_damage.gd:95`），但「受伤时 X」这类确实会。
- 建议改写：「反伤、吸血只认直接攻击；中毒、流血、反伤、流失这几类不触发受伤规则，灼伤的火焰跳照样算『受伤时』。」（或改代码让 buff 来源的包一律不 provoke —— 那是设计决定。）

#### 9. 寒冷的效果行「下一次出手的冷却 +N%」：只对武器　【疑似】
- 文字：`core/text/ui_text.gd:900` `gloss.next_fire_cooldown` 「下一次出手的冷却 +%s%%」；帮助页 `elements_and_reactions.json` 「冰是寒冷，冷却变长」。
- 代码：`core/battle/cadences/cooldown_cadence.gd:56-63` `chilled()` 只对带 `weapon` 标签的道具规则生效（`tags_of(uid).has(&"weapon")`），别的按冷却出手的道具（护符、药）不受影响、也不消耗层数；并且减半发生在 `commit`，耐力付不起那一下也照样消耗寒冷。
- 建议改写：「武器下一次出手的冷却 +N%」。

#### 10. 燃血 / 菌血「每层持续一秒」读起来像逐层掉，实际是「N 层一起撑 N 秒」　【疑似】
- 文字：`data/authoring/reactions/fire_bleed.json:7` 「每秒受到层数等量的火焰伤害，每层持续一秒，再反应就延长」；`poison_bleed.json:7` 同句式；悬浮窗时间行 `ui_text.gd:907` 「每层 %d 秒」。
- 代码：`core/battle/buff_instance.gd:48 add_stacks` 把 `seconds_left += 层数 × seconds_per_stack`；`core/battle/effects/status_decay.gd:11` 每秒只减 `seconds_left`，**层数不变**，归零整个移除。`buff_def.gd` 注释原话：「燃血 3 层在第 1、2、3 秒各打 3 点，第 3 秒那一跳之后消失」。文字容易被读成 3 → 2 → 1。
- 建议改写：「N 层就每秒受到 N 点火焰伤害、持续 N 秒，再反应就加层加秒。」

#### 11. 流失（drain）说明漏了「无视护甲」　【疑似】
- 文字：`data/authoring/damage_types/drain.json:7` 「以血为代价时扣的血：不会触发受伤时的效果。」
- 代码：同文件 `"armor_absorbable": false`；`core/battle/effects/change_resource.gd` 注释还说「走完整管线（因此减伤、反转、免疫照样生效）」—— 护甲那一步按数据跳过。
- 建议改写：「以血为代价时扣的血：无视护甲，不会触发受伤时的效果。」

#### 12. 爆燃「再叠一半层数的灼伤」：向下取整，N = 1 时不叠　【疑似】
- 文字：`data/authoring/reactions/fire_poison.json:7`
- 代码：`core/battle/reactions/reaction_def.gd value_of()` `KIND_HALF` = `n / 2` 整除；`effects_for()` 算出 0 的效果整条不跑。
- 建议改写：「……再叠一半层数（向下取整）的【灼伤】。」

#### 13. 「耐力」词条「不够就出不了手，等回够再动」　【疑似】
- 文字：`core/text/glossary.gd:32`（tip 关着，但百科的属性页照用这段）
- 代码：`core/battle/rule_engine.gd` 冷却先 commit 再查消耗；付不起就跳过这一次，**冷却照常重走**，不是回够耐力立刻出手。`stamina_and_cooldown.json` 帮助页写对了。
- 建议改写：「出手要花的资源，每秒按回复速度补回；冷却到点时不够就跳过这一次，冷却重走。」

#### 14. 「buff 与叠层」帮助页举的例子有一条没有对应内容　【疑似】
- 文字：`data/authoring/help_pages/buffs_and_stacks.json:9` 「有的把对手身上的中毒整个换成更凶的剧毒」
- 代码 / 数据：`convert_status` 效果存在，但 `data/authoring` 里没有任何道具 / 敌人 / 生长 / 铸炉内容用它（`grep convert_status` 为空）；剧毒现在只从「电解」反应来。其余三个例子（施加时得增益、攒够层数消耗、对手带流血时更痛）都有道具（`bloodletter`、`battle_axe` 等）。
- 建议：删掉这一句，或改成「雷碰毒的电解让对手的中毒更凶（剧毒）」。

#### 15. `ConvertStatus.describe()` 用伤害类型名写状态名　【疑似（目前无内容触发）】
- 文字：`core/battle/effects/convert_status.gd:30` `DamageTypes.name_of(from)` → 「毒素转为剧毒」；别处状态都用 `Glossary.status_name()` → 「中毒」。
- 建议：改用 `Glossary.status_name(from)`。

#### 16. `ChangeResource` / `ShiftAxis` / `ApplyStatus` 的 `describe()` 不写 `per_stack`、`amount_stat`、`percent_of_damage`　【疑似（目前无内容触发）】
- `change_resource.gd:68` 只写 `amount`；有 `percent_of_damage`（吸血）会写成「回复 0 点生命」；`apply_status.gd:56`、`shift_axis.gd:62` 的 `per_stack` 不出现在句子里。现有内容（`data/authoring` 全目录）没有在 buff 之外用这些字段，所以玩家现在看不到错句；buff 内的 `per_stack` 由 `Glossary._self_damage_text` 另写。

#### 17. 已知：流血词条与生成文字都没写「每跳减半」（另有人修）
- `core/text/glossary.gd:56`、`Glossary.buff_effect_lines()`（`glossary.gd:424`，减半只进作者工具的 `buff_rule_lines`）；代码 `core/battle/rule_engine.gd:31`。帮助页 `elements_and_reactions.json` 已写对。

---

### 二、核对过、与代码一致的文字

- **data/authoring/buffs**（说明全部由 `Glossary.buff_effect_lines` 按字段生成）：blood_rage（每层 +5 强攻 / +5 加速、10 秒、不叠）、chill（每层冷却 +10%、出手后减半）、deflect（格挡 +8、4 秒）、deflect_long（格挡 +4、8 秒）、fungal_blood（恢复减半、回几点叠几层中毒、每层 1 秒）、hardy_guard（护甲上限 +15，上限涨当前同涨 `resource_pool.gd:65`）、marked（格挡 −3、8 秒、减益）、numb（每层下一次付耐力 +10%、付完减半，任何耐力消耗都算 `resource_cost.gd:28-42`）、poison（每层每秒 1 毒素、永续）、scorch（每层每秒 1 火焰、永续）、scorched_blood（治疗归零 + 每层每秒 1 火焰，见第 10 条）、virulent（受到的毒素伤害每层 +25%）、ward（护甲上限 +8）。bleed 见第 3 / 17 条。
- **data/authoring/damage_types**：bleed（真实 · 物理，跳过加成 / 护甲 / 受伤前 / 格挡 / 受伤轴 `damage_resolver.gd`）、fire（吃攻方火焰轴，含灼伤跳）、ice、lightning、physical、poison（无视护甲、不招致反应）、reflect（不招致反应）。drain 见第 11 条。
- **data/authoring/reactions**：fire_ice 淬裂（每层 −5 护甲）、fire_lightning 过载（自己 +N 加速）、ice_bleed 冻疮（N 层流血保底，减半 / 移除 / 反应都压不下去）、ice_lightning 超导（对手 +N 易伤）、ice_poison 凝毒（N 层中毒保底）、lightning_bleed 激荡（+N 锐目，按武器里最高暴击率到 100% 溢到致命 `shift_axis.gd room()`）、lightning_poison 电解（+N 剧毒）、fire_poison 爆燃（3N 火伤 + N/2 灼伤，见第 12 条）、fire_bleed / poison_bleed（见第 10 条）。N = min(已有, 新来)、两边各扣 N、不连锁 —— 与 `elements_and_reactions.json` 一致。
- **data/authoring/belt_skills**：aid_pack、smoke_bomb（说明是口语，具体规则在 `bonus.smoke` / `bonus.smoke_core`，与 `belt_skills.json` 帮助页一致）。
- **data/authoring/faiths**（信力来源、献祭、赐福、神赐的生成句）：brute（伤害 ×0.2 封顶 30、失体力；赐福激活 +10% 伤害、每 50 信力 +1 伤害最多 6 份；低血增伤 10%+5%/50 信力封顶 50、献祭 5 上限留 5、击败耗 1 体力 / 30 信力、不死 2+1 秒/50 信力封顶 20）、earth（中体积出手、踩点 20/1、耐力上限 +20、锻炼不限次、改造不限次）、hunt、nature（回血 +1/秒、献祭食物每件 +1 最多 3、食物护甲 2+2×稀有度、食物 ×2、加时回春 +8/秒）、skill、sun（附魔 30% 至少 3 + 1 层灼伤、随机 3 把 / 三阶全部、祈祷每层 +3% 火焰、三阶 5 层灵巧、四阶额外掉落 紫/金/红 = 稀有度 3/4/5）、church。`god_*.json` 帮助页与以上一致。
- **core/text/glossary.gd 固定词条**：自发、开战时、出手时、受伤时、层数够时、施加时（只认自己施加、刷新不算）、资源低于时、冷却、耗耐力、信力、地上、急速、格挡（只盾、取最高、加固 / 破绽倒贴、不挡 buff 伤）、护甲（中毒流血无视）、直接伤害、永续、叠层（可叠就不封顶）、合成、增益槽、受益槽、装载槽（后放的那把优先）、中毒。负重 / 吃力 / 超重 / 寸步难行 / 耐力 / 流血见上。
- **ui/inventory/item_tooltip.gd 句式**：武器句「每 X 秒造成 Y 点伤害，消耗 Z 耐力」（X 已除急速、Y 含暴击期望 —— 作者定，`deal_damage.gd:157`）；品质：伤害 / 格挡 / 护甲 ×(1+0.1q) 向下取整、暴击率 +5 点/档、规则里施加层数 / 轴层数 / 写死点数 / 下一下加伤 +1/档（`compiler.gd:213-259`），悬浮窗用编译副本写最终值（`item_tooltip.gd:145-158`、`spec_for` 给副本带品质）；`applies` 简写的层数不随品质涨，文字与代码一致（都不涨）；增益 / 受益句（`adjacency_text.gd`）、装载行、轮读句、耐久行、生长行、军功行与对应代码一致。
- **help_pages 里写了数的**：countdown_and_closing（过半关最近的免费撤离点 `paid_extracts.gd:52`）、encumbrance 的减益内容（阈值除外）、armor、buffs_and_stacks 的上限涨跌（`resource_pool.gd:65-80`）、elements_and_reactions（含流血减半、机关免疫毒 / 血）、stamina_and_cooldown、haste（冷却下限 0.01 秒、快照语义）、multipliers（乘算和低于 −1 钳 0 `stat_value.gd:55`）、auto_battle（加时 / 衰竭、双倒判定 `battle_sim.gd:210`）、crystals_and_load、grant_receive_slots（一件邻居只点一格 `compiler.gd:588-604`、跨包不吃包加成 `compiler.gd:319`）、characters（偷袭三成 `assault_skill.gd:7`、操练两成、每休息点补 1 次）、vitality 的不屈（最少扣一点）、hunters（掉落 ×1.5）、tech_tree、special_rites、belt_skills。
- **run_buffs / techs / tags** 的说明：数值走占位符从字段取，没有写死的数；标签说明（盾 / 防具 / 法杖 / 晶石 / 饰物等）与机制一致。

---

### 三、附：不算错、但值得知道
- 麻痹 / 寒冷的减半在 `commit` / `pay` 时发生：武器冷却到点但耐力不够，寒冷层数照样减半、冷却照样被拉长。
- 剧毒的按类型易伤在 `damage_resolver.gd` 第 4 步里 `not pure` 分支下 —— 对真实伤害（流血）不生效，和「受到的毒素伤害」文字不冲突。
- 回血（`regen_hp`）吃燃血 / 菌血的截断（`combatant_runtime.gd:290`），但不叠菌血的中毒（只有 `heal()` 入口叠）；文字「每次恢复生命……叠几层中毒」可以理解为不含每秒回血。

## 五、落地记录

| 时间 | 事 | 出处 |
|---|---|---|
| 2026-11-07 15:00 | 作者原话见顶部（小修线程转来）；普查五个数据目录 + 词条 + 句式 + 帮助页，17 条不符；写成本篇，待定按推荐派执行 | 架构设计线程 |
| 2026-11-07 | **v5.37 落地**（PR #PRNUM）：17 条全改（第 17 条小修已改）；三条待定都按推荐（第 8 条只改文字、阈值走占位符 `{load:…}` 从 standard 负重规则读、§四.三 不写进帮助页）。顺带一条：商店帮助页写「包不上架」，其实 `shop_bag_slot_chance` 0.3 会摆包，一并改了。新加测试 `test_effect_text_288`：负重文字 = 数据、流血所有内嵌副本是减益、卖价帮助页 = `shop_sell_ratio` / `sell_ratio`、赐物按 by_type、生成句补全 | 架构方案执行 |
