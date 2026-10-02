# 104 · 方案：神明总表落地（删战争之神、技巧 / 狩猎新定位、四条新信力行为、献祭倍率、新标签、暴击属性）

> 2026-10-01 ｜ 提议 · 作者已确认要点（见「作者已定」），待执行 ｜ 对应 `docs/gods.xlsx`（信仰体系核心配置，作者版 78bb7df）、架构文档 4.3 / 4.6、报告 082 / 093 / 095 / 103

作者改完 `docs/gods.xlsx` 后给了三条：**① 信力公式与阈值都要在将来的测试里重新规划，写进方案；② 加暴击属性：基础暴击率 10%、基础暴击伤害 150%，所有加成一律加算；③ 新建缺的标签。** 本文把表里的每一处改动翻成代码与内容改动，交执行 thread。本 thread 不实现。

## 一、数值是占位，节奏靠测试定（作者第 ① 条）

- **gods.xlsx 里所有数（阈值、每种行为给几点、每场上限、献祭倍率、转化概率）都是占位**，按 093 七的节奏目标调：前两场战斗到 1 级、4～6 个战斗节点到 2 级、小图一般升不到最高级、中图最后升到最高级。
- 要能调，先得**看得见**。加一条量尺：`FaithPower.history: Array[Dictionary]`（每次 `credit` 记 `{step, node_type, event, gained, total, tier}`），进一局存档与 `RunResult`；结算屏的战绩页多一行「信力节奏：第 N 步到 1 阶、第 M 步到 2 阶」，开发模式下可导出 CSV（`user://faith_history_<seed>.csv`）。作者打几局就能对着表改数。
- 公式本身**不改**：献祭 = `2^稀有度 × 倍率`（`offering_rule.gd:43`，多条规则命中相加，`faith_def.gd:73-80`；自己神的赐福版 ×2）。我上一版 xlsx 表头写的「稀有度 × 倍率」是错的，已改回。倍率默认值按作者改的 `1`（`OfferingRule.multiplier` 默认 2.0 → 1.0；现有四位神的每条规则都显式写了倍率，不受影响）。
- 以后**改数只改 xlsx 再同步 JSON**：第七节的 `tools/gods_xlsx_to_json.py` 让这一步变成一条命令。

## 二、神明表的改动 → 内容文件

| 表里的改动 | 落地 |
|---|---|
| 删战争之神 | 删 `data/authoring/faiths/war.json` 与 `data/faiths/war.tres`；`tests/test_faith.gd:25-69`、`test_author_093.gd:49`、`test_faith_power.gd:89` 里用 `war` 当样本的改成 `skill`。没有道具带 `faith:war`，不需要别名 |
| 四位主神的神话定位 | 写进各自 JSON 的 `description`（蛮神：帝国诸神之一、地位不高、北境与边缘行省信；日神一族地位崇高；自然：信徒最广、祭祀最多、影响最大；大地：主神之一但信徒很少、种族低调），`god` 字段跟着改（自然加「变化」；大地改成「体积、空间」） |
| 技巧之神 | `god`：「技巧之神（尺度、变形、结构）」；`description`：锻造、战斗技巧与手艺之神，矮人、盗贼、工匠信奉，帝国祭祀 |
| 狩猎之神 | `god`：「狩猎之神（比较、差异、拆解）」；`description`：不被帝国祭祀，民间猎人信 |
| 新教 | `description` 加一句「概念暂不引入」 |
| **每位神的信物必然包含一枚 1 格护符** | 新 `items/charm_skill.json`「技巧之神的护符」、`items/charm_hunt.json`「狩猎之神的护符」：照 `charm_sun.json` 的样子（1 格、稀有度 3、值 200、`treasure / faith / faith:<id> / faith_anchor`），**暂无效果**；`MetaState.keeps` 的信仰包例外自动覆盖。盾牌与长弓保留原有按阶功能。这条规矩写进架构文档 3.8，导入器守：每个信仰至少一件 1 格、带 `faith_anchor` 的道具（新教除外，占位） |
| 技巧 / 狩猎的阈值「待定」 | JSON 里暂留 `[3, 8]`（占位，第一节的量尺出来再定），`description` 注明 |
| 胫骨大棒移除 1 阶功能 | 删 `tibia_violence.json` 的 `faith_bonuses`（保留 `faith:brute` 标签，它仍是蛮神的道具） |

## 三、四条新的信力行为（技巧 ×2、狩猎 ×2）

现有 13 种 deed 都不认这四件事，各加一个构件（`core/run/faith/deeds/`，`EffectRegistry.FAITH_DEEDS` 一行），并给事件载荷补字段。deed 是共享的 `Resource`，**不能自己记状态**，「首次」一律由 `RunState` 算好放进载荷。

| 神 | 表里的行为 | 构件 | 载荷 / 接线 |
|---|---|---|---|
| 技巧 | 获得新的金属标签道具，格子 × 3 | `ItemAcquiredDeed {tag: metal, per_cell: true, amount: 3}` | **新事件 `item_acquired` {id, tags, cells, rarity, first_in_run}**。「获得」= 一件道具第一次出现在玩家的容器里（棋盘 / 暂存区 / 保险箱），来源不限（战利品拖进来、买、赐物、事件给、合成产出）。接法：`RunState` 记 `owned_uids: Dictionary`（进存档），在 `stepped` 与回到地图（`_set_phase` → MAP）时对照棋盘 + 暂存区 + 保险箱里的 uid，新出现的发一次 `item_acquired`。不逐个容器接信号，一处对账就够 |
| 技巧 | 每场战斗中每种不同名字的武器首次被触发 +10，每场上限 50 | `DistinctItemsFiredDeed {tag: weapon, amount: 10, cap: 50}` | `battle_summary` 的 `fired_items[]` 补 `id`（`run_state.gd:694-700` 现在只有 tags / cells / count）；deed 按 `id` 去重计数 |
| 狩猎 | 进入普通战斗 +5、精英 +20、BOSS +50 | `BattleDeed` 加 `by_type: Dictionary`（空 = 用 `amount`） | `battle_summary` 补 `node_type`（`battle_finished(node, …)` 有 node）。秒杀精英（蛮神 3 级）不跑模拟也发 `battle_finished`，照算 |
| 狩猎 | 每局首次把一种战利品置入背包，按稀有度给 2^稀有度 + 1 | `FirstPlaceDeed {tag: trophy, rarity_pow: true, plus: 1}` | `place_item` 载荷补 `tags, rarity, first_in_run`；`RunState` 记 `placed_ids`（按 def id，进存档）。`trophy` 标签已存在（战利品） |

四条都只在**激活该神**时记（`FaithPower.credit` 现有规矩），表的备注 1 已成立。

## 四、献祭：倍率、新标签、新匹配条件

- 倍率照表改 JSON：蛮神 5 / 10 / 5 / 2，日神四条 5，自然三条 5，大地 5（× 格子数）；技巧新增金属 5、防具 5、带暴击属性 8；狩猎新增血肉 / 骨头 5、战利品 10、皮革 5。
- **新标签 `leather`（皮革）**：`data/authoring/tags/leather.json`，照 `trophy.json` 的格式；现有皮甲类道具补这个标签（执行 thread 扫一遍 `items/`：皮甲、皮包、皮靴之类）。`metal / flesh / bone / trophy / gear / armor / shield` 都已有。
- **「带有暴击属性的道具」**：`OfferingRule` 加一个匹配条件 `has_stat: StringName`（道具 `combat.base_stats` 里**显式写了**这条属性才算；默认 10% 不算「带有」），技巧那条写 `has_stat: crit_chance`。导出 / 导入 / 编辑器下拉跟上。
- 备注 2（命中多条相加）代码已是这样，不改。

## 五、暴击属性（作者第 ② 条）

- 两条新属性 `BattleStats.CRIT_CHANCE`（基础 **0.10**）、`CRIT_DAMAGE`（基础 **1.50**）。`DEFAULT_BASE` 现在只会给 1.0，改成真的默认值表 `{haste: 1.0, crit_chance: 0.10, crit_damage: 1.5}`，`default_base()` 按表换算定点；`CombatProfile.seed_stats` 对没写的属性不再只补 haste，而是补表里每一条。
- **全部加算**：这两条属性只接受 `flat`，导入器对作用于它们的 `mult_category / mult_percent` 报错。战斗内的增减走 103 第 4e 的标准轴，加两条**固定值轴**：`crit_chance` 每层 +1%（正名「锐目」/ 负名「失准」）、`crit_damage` 每层 +5%（「致命」/「钝击」）；编译期加成（套装、信仰阶梯）仍是 `flat` 的 `StatModifier`。
- **判定在 `DealDamage.apply`**：只对**从属性取伤害**的那一包（`damage_stat != ""` 且属性有值）掷；固定值伤害（灼烧每层 2 点、`amount` 填死的）**不暴击**。掷一次 `ctx.rng().randi_range(1, 10000) <= crit_chance`（定点万分比），命中则 `raw = mul(raw, crit_damage)`，并在 `DamagePacket` 上立 `crit = true`。放在管线之前，所以护盾、减伤、护甲、加时倍率都看到的是暴击后的原始值。双方对称，敌人也会暴击。
- 日志：`damage` 事件载荷加 `crit`；回放飘字加大、换色（`UiPalette` 加一色），事件条写「暴击」；`Glossary` 的属性名表加两条。
- **确定性**：掷骰用战斗 RNG，同种子同结果；但它**多消费一次随机数**，现有依赖具体随机序列的断言（`test_damage_pipeline`、`test_effect_system` 里若有）要跟着改，猎手校准（094）要重跑。
- `StaminaEstimate` 不动；预估 DPS（`estimated_damage`）乘上期望值 `1 + crit_chance × (crit_damage − 1)`（默认 1.05），开局预估才和真打对得上。

## 六、与现有规矩的对照

| 处 | 对照 |
|---|---|
| 4.3「固定加值在所有乘法之后相加」 | 暴击属性只有 flat，公式不变；暴击倍率乘在 `DealDamage` 产出的原始值上，不是属性公式的一部分 |
| 4.6 管线五步 | 暴击在第 1 步之前（造包时），管线零改动 |
| 103 第 4e 标准轴 | 两条新轴只是轴表加两行 |
| 085 可叠层永续 | 轴层数永续，一致 |
| 099 `place_item` 只认从别处进来 | `first_in_run` 以此为基础再去重，不改 099 |
| 095 赐福模板 | 技巧 / 狩猎没有赐福模板，不变；护符能被 `convert_chance` 转化吗 —— 护符没有 `combat`，不在任何模板的圈里，不会 |
| 082 占位神 2 阶 [3, 8] | 技巧 / 狩猎沿用，标占位 |

## 七、工具：xlsx → JSON（第一节的前提）

- `tools/gods_xlsx_to_json.py`（Python 3 + openpyxl，作者本机跑；Godot 读不了 xlsx）：读 `docs/gods.xlsx` 的「神明总表 / 信力行为 / 献祭 / 等级效果 / 信物与赐福」，按「类型 / 参数（JSON）」两列生成 `data/authoring/faiths/<id>.json`（`thresholds / deeds / offerings / perks / blessings / description / god`），**只覆盖这些字段**，其余字段原样保留；然后作者照常跑 `tools/import_content.gd`。
- 反向检查进 `tools/check_content.gd`（100 第 1 步的那道）：JSON 与 xlsx 对不上就红 —— 这样表才守得住「核心配置」。xlsx 的「人话」列不参与比对。
- xlsx 里「参数」为空的行（技巧 / 狩猎的四条新行为）由执行 thread 按第三节填好 `type` 与参数，这是表里现在缺的。

## 八、验证

- 导入：七份信仰 JSON 全绿；每个信仰（新教除外）至少一枚 1 格护符，缺一报错；`has_stat` 条件导出 → 导入往返。
- deed 测试（`tests/test_faith_power.gd` 加四组）：拿到一件 4 格金属道具 +12，再拿同一件不再给（对账只发一次）；一场里两把同名匕首与一把短剑出手 → +20，六把不同的 → 封顶 50；进精英战 +20，输了也给；首次置入稀有度 3 的战利品 +9，再置入同种不给，读档后仍记得。
- 暴击：`crit_chance = 0` 永不暴击、`= 1` 必暴击、默认 10% 在 1000 次里落在 7%～13%；暴击包 `raw` ×1.5；灼烧不暴击；`damage` 事件带 `crit`；同种子两次模拟逐事件相同。
- 献祭：技巧之神对显式写了 `crit_chance` 的道具按 8 倍算、对默认暴击的不算；一件骨制武器献给蛮神 = 2^稀有度 × (5 + 2)。
- 信力节奏：打一局后 `RunResult.faith_history` 非空、结算屏那一行能显示；CSV 能导。
- 全套 `tools/test.sh` 绿；`check_content` 绿（xlsx ⇄ JSON）。

## 九、改动范围与顺序

| 批 | 内容 | 文件 |
|---|---|---|
| ① 内容与标签（半天） | 删 war、文案、两枚护符、胫骨大棒、倍率、`leather`、测试样本换 id | `data/authoring/faiths/*`、`items/charm_skill.json`（新）、`items/charm_hunt.json`（新）、`items/tibia_violence.json`、`tags/leather.json`（新）+ 皮革道具补标签、三个测试 |
| ② 四条行为 + 量尺（一天） | 四个 deed、载荷补字段、`owned_uids / placed_ids`、`FaithPower.history`、结算屏一行、CSV | `core/run/faith/deeds/{item_acquired,distinct_items_fired,first_place}_deed.gd`（新）、`battle_deed.gd`、`core/run/run_state.gd`（接线、对账、`battle_summary`）、`faith_power.gd`、`run_result.gd`、结算屏、`effect_registry.gd` |
| ③ 暴击（一天） | 两属性、默认值表、掷骰、包旗、事件、飘字、两条轴、导入器加算校验、预估 | `battle_stats.gd`、`combat_profile.gd`、`effects/deal_damage.gd`、`damage/damage_packet.gd`、`damage_resolver.gd`（`_notify` 带 `crit`）、`stat_axes.gd`（103 落地后）、`content_importer.gd`、`combatant_panel.gd`、`glossary.gd`、`compiled_item.gd`（预估） |
| ④ 献祭匹配 + 工具（半天） | `has_stat`、xlsx → JSON 脚本、`check_content` 对照 | `offering_rule.gd`、`content_exporter.gd` / 导入器、`tools/gods_xlsx_to_json.py`（新）、`core/authoring/content_check.gd` |

③ 依赖 103 的 4e（轴表）落地；其余三批不依赖 103，可以先上。

## 十、说明文本里的数字：只能读字段，不许写死（作者第 ④ 条，2026-10-02）

作者问：各种说明文本里的数字，是文本的一部分还是读的字段？不是读字段的改成变量。全仓扫了一遍（`describe()`、`note`、`description`、事件 `text` / `label`、`UiText` / `Glossary` / `FieldText`、浮窗），结论分两半。

### 现状

**代码侧已经是读字段。** 134 处 `describe()`（deed / perk / cost / effect / cadence / trigger / `OfferingRule` / `FaithBonus.gate_text` / `Glossary.mods_text` / `describe_buff` / `stamina_estimate`）全部用 `%d`、`%.0f` 从字段拼句；GD 里没有写死数字的玩家文案。仅有的几处数字是语义常量（`"0 = 不限"`）、导入器报错，和 `map_scale_profile.gd:83` 的标签「小型（4~5 环）」——它与同一行的 `Vector2i(4, 5)` 重复，顺手改成拼。

**内容侧（JSON）有三十多处写死，全在「人话」字段。**

| 类 | 处 | 例子 | 字段 |
|---|---|---|---|
| 信仰 `note`（献祭 / 等级效果 / 赐福） | 17 | `"骨制品（稀有度 × 3）"`、`"开战时所有武器火焰附魔，武器耐力消耗 −20%"`、`"伤害 +10%"`、`"每 50 信力伤害 +1（最多 6 份）"`、`"2 级：耐力消耗 −10%"` | `multiplier`、`stamina_cost_percent`、`mult_percent`、`per_points / max_stacks / flat`、`tier` |
| 道具 `faith_bonuses[].note` | 3 | `blessed_longbow` `"第一阶：伤害 +4"`、`"第二阶：伤害再 +15%"` | `mods[].flat / mult_percent` |
| `description` | 8 | 角色 `"生命 50"`、局内 buff `"走 5 步之内伤害 -10%"`、成就 `"图鉴点亮 10 种"` / `"价值 300 币"`、难度 `"体力上限 -1"` | `max_hp`、`duration_steps / mult_percent`、`amount`、`effects[0].amount` |
| 事件选项 `label` | 4 | `"给他 10 币"`、`"扎营（多耗 2 个行动点，多回 1 点体力）"`、`"撬开（体力 -1）"`、`"需要步数 ≥ 4"` | `outcomes[].amount / actions`、`requires[].min_steps` |
| 事件 `text`（教程） | 5 | 「塔盾每下减 4」「皮甲 3 点护甲」「护身符每秒 8 点护盾」 | 别的道具的字段：`tower_shield` flat −4、`leather_armor` armor 3、`warding_charm` |

两个加重的问题：

1. **`note` 非空时直接覆盖 `describe()`**（`FaithPerk.describe` 只返回 `note`；`OfferingRule.describe` 先看 `note`），于是字段一改、文本不跟。已经有对不上的现成例子：蛮神献祭 note 写「稀有度 × 3」而代码是 2^稀有度 × 3（第一节已指出）；日神赐福 note 写「2 级」而 `gate_text` 说「第 2 阶」。
2. **同一个数显示两遍**：`item_tooltip.gd:106` 把 `gate_text` + `mods_text` 和 `note` 一起拼，玩家看到「信力每 50 信力一份，最多 6 份：攻击 +1　每 50 信力伤害 +1（最多 6 份）」。

`extract_default.json` 的 `"费用：{extract_fee} 币"` 是正确示范：数字来自 `TextTemplate` 的上下文。gods.xlsx 的「效果（人话）」列同样是写死的，但它不进游戏（第七节：不参与比对），见下面 C。

### 改法

原则一句话：**一个数只有一个来源 = 字段；文本要么由 `describe()` 生成，要么是带 `{key}` 占位符的模板。**

**A. `note` 从「覆盖」改成「补充 + 模板」**

- `FaithPerk` / `OfferingRule` / `FaithBonus` 的显示永远先由字段生成主句（`FaithBonus` 补一个 `describe()` = `gate_text() + mods_text + rule_text`，`faith_tooltip` 与 `item_tooltip` 都改用它，不再各拼一遍）；`note` 只是后面追加的一段补充，为空就没有。
- `note` 过 `TextTemplate.render(note, params())`：三个基类各加 `params() -> Dictionary`，默认把自己的 @export 数值字段放进去（`per_points`、`max_stacks`、`multiplier`、`stamina_cost_percent`……子类不用写）。作者要自己措辞时写 `"每 {per_points} 信力伤害 +{flat}"`，数仍来自字段。
- 现有 17 + 3 处 `note`：绝大多数直接删，`describe()` 已能生成等价句；生成得不够好的改 `describe()`，不写 `note`。
- 导入器加一道**警告**：`note` / `description` / 事件 `label` / `text` 剥掉 `{…}` 之后仍含阿拉伯数字 → `report.warn`（汉字数「三秒一下」不碰）。`check_content` 把警告列出来，`tools/test.sh` 先放行；清零之后再升为 error（待作者定，见下）。
- 阶的叫法统一：`gate_text` 的「第 %d 阶」、`faith_tooltip` 的「Lv.%d」、xlsx 的「级」三种并存，推荐全部用「Lv.%d」。

**B. `description` 与事件文本过 `TextTemplate`，上下文带上定义自己的字段**

- `TextTemplate.render` 现在只有 `event_screen` 与 `node_tooltip` 用。扩到六个消费点：`item_tooltip.gd:53`（道具 `description`）、`faith_tooltip.gd:16`（信仰）、`setup_screen.gd:617`（角色）、`meta_screen.gd:331 / 487`（成就、难度）、`map_screen.gd:705`（局内 buff）、`hunter_system.gd:308`（猎手）。
- 新约定：内容定义类有 `text_ctx() -> Dictionary` 返回自己的数值字段，渲染时作为 `context_for(run, node, extra)` 的 `extra` 传入（局外屏 `run` 为 null）。首批：`CharacterDef`（`max_hp`、`bags`）、`AchievementDef`（`amount`）、`RunBuffDef`（`duration_steps`、第一条 mod 的 `mult_percent` / `flat`）、`DifficultyDef`（`vitality_delta`）、事件选项（`outcomes[0]` 的 `amount / actions / vitality`、`requires[0].min_steps`，键名 `cost_*` / `need_*`）。
- 教程文本引用**别的道具**的数：加一个通用键 `{item_stat:tower_shield:damage_taken_flat}`，`TextTemplate` 从 `ItemDatabase` 取编译后的值；只给教程用。不想引入跨引用就把那三段改成不写数（「固定减几点伤害」），二选一，推荐前者。
- 八处 `description` 与九处事件文本按上面改写；键全部记进 `docs/text-placeholders.md`，加「定义自身字段」一节。

**C. gods.xlsx 的「效果（人话）」列变成生成列**

- `tools/check_content.gd` 加一个导出模式：把每条 deed / offering / perk / blessing 的 `describe()` 输出写成 `docs/gods_text.json`；`tools/gods_xlsx_to_json.py --render` 读它回填到 xlsx 的该列。表里的人话从此由字段生成，作者只改参数列。放在 ④ 批之后，不急。

### 落到改动范围

新增一批 **⑤ 文本读字段（一天）**，不依赖其余四批，但**建议排在 ① 之前**：① 要改同一批信仰 JSON 的文案，照新规矩写一次就够。

| 内容 | 文件 |
|---|---|
| `params()` / `describe()` / `text_ctx()` 约定、`note` 变补充、`TextTemplate` 扩消费点与 `{item_stat:…}` | `core/run/faith/faith_perk.gd`、`offering_rule.gd`、`core/battle/faith_bonus.gd`、`core/run/faith/faith_tooltip.gd`、`ui/inventory/item_tooltip.gd`、`core/text/text_template.gd`、六个消费点、`character_def / achievement_def / run_buff_def / difficulty_def / event_def` |
| 导入器警告 + `check_content` 列出 | `core/authoring/content_importer.gd`、`core/authoring/content_check.gd` |
| 清理内容 | 四份信仰 JSON 的 20 处 `note`、`blessed_longbow / blessed_shield`、8 处 `description`、9 处事件文本、`map_scale_profile.gd:83`、`docs/text-placeholders.md` |

验证加一条：`check_content` 对整个 `data/authoring` 零「文本含裸数字」警告；改任一字段（如 `per_points` 50 → 40）后浮窗文字随之变化，不需要改文案。

## 作者已定（2026-10-01）

| 项 | 决定 |
|---|---|
| 信力公式与阈值 | 都是占位，将来按测试重新规划；本文第一节给量尺 |
| 暴击 | 新属性；基础暴击率 10%、基础暴击伤害 150%，所有加成加算 |
| 标签 | 缺的新建（`leather`） |
| 战争之神 | 删 |
| 技巧 / 狩猎 | 新定位（见第二节），各加一枚空白 1 格护符，效果以后再加，阈值待定 |
| 新教 | 概念暂不引入，只占位 |
| 胫骨大棒 | 移除 1 阶功能 |
| xlsx ⇄ JSON 对照工具 | 可以做 |
| 说明文本里的数字（2026-10-02） | 不读字段的全部改成变量；本文第十节 |
| 裸数字检查（2026-10-02，按推荐） | 导入器先 warning 一轮，`check_content` 列出；清零后升为 error |
| 教程文本引用别的道具的数（2026-10-02，按推荐） | 加通用键 `{item_stat:<道具 id>:<属性>}`，记进 docs/text-placeholders.md |

## 待作者定（不挡执行，按推荐先做）

1. 技巧「获得**新的**金属道具」：每拿到一件都给（推荐，`first_in_run` 不用），还是同一种道具一局只给一次？
2. 暴击对持续伤害（灼烧、中毒）：不暴击（推荐，它们是固定值）；要让它们也暴击就把判定挪到 `DamageResolver` 第 1 步。
3. 两条暴击轴的步长：暴击率 +1% / 层、暴击伤害 +5% / 层（推荐起点）。
4. 技巧 / 狩猎的占位阈值先用 [3, 8] 还是照四位主神的量级先填一组（例如 [25, 80]）？推荐照主神量级填，省得第一轮测试先撞见 3 点就升级。

## 落地记录（2026-10-01，执行 thread）

四批都做了（103 的轴表已在 main）。「待作者定」四项按推荐：金属道具每拿到一件都给（`first_kind_only` 默认关）、持续伤害不暴击、两条轴 1% / 5% 一层、技巧 / 狩猎占位阈值填 [25, 80]（表里同步改了）。与方案不同的地方：

- **xlsx → JSON 工具用 GDScript 写**（`tools/gods_xlsx_to_json.gd`，不是 Python）：对照检查在 Godot 里跑，得读得了 xlsx（`XlsxReader`），生成与对照共用一份逻辑（`GodsTable`），作者本机也不用装 openpyxl。赐福模板不在工具管的范围里 —— 表里那一栏是人话，没有 JSON 列。
- **`CombatProfile.seed_stats` 没改**：`StatSet` 缺键时自己按 `BattleStats.DEFAULT_BASE` 取默认值，效果一样，道具的属性表里也不会凭空多出两行。
- **获得的对账**放在「离开一个点」（`step_to` / `relocate` 清暂存区之前），没有用方案里说的 `stepped`（代码里没有这个信号）。
- 表里补了：技巧 / 狩猎四条行为的 `type` 与参数、技巧「带有暴击属性」的条件 `has_stat: crit_chance`、新教的 `event_choice` 一行（不然生成的新教没有行为）、自然 5 级改成 `overtime_regen {"stacks": 8}`、删了等级效果表里战争之神的两行、「信物与赐福」加两枚护符、胫骨大棒标「已移除」。
