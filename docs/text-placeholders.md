# 文本占位符、样式码与浮窗模板（开发手册材料）

> 084 起。事件文本、节点浮窗、道具说明共用一套：作者写 `{key}`，运行时由 [`core/text/text_template.gd`](../core/text/text_template.gd) 替换。
> **加一个键就在这里补一行**。

## 1. 占位符 `{key}`

写在事件的 `title` / `text` / 选项 `label`、节点浮窗模板里。上下文由 `TextTemplate.context_for(run, node, extra)` 造；
**不认识的键原样保留**（写错了一眼看得见，也不会吞掉别的花括号）。

| 键 | 值 | 备注 |
|---|---|---|
| `{char_name}` | 角色名 | 没按角色开局时是「你」 |
| `{char_id}` | 角色 id | |
| `{chapter_name}` | 章节名 | |
| `{seed}` | 这一局的种子 | |
| `{vitality}` / `{vitality_max}` | 体力 / 上限 | |
| `{money}` | 钱 | |
| `{actions}` | 已用行动点 | |
| `{board_count}` / `{storage_count}` | 棋盘上 / 地上几件 | |
| `{faith}` | 激活的信仰名 | 没有是「无」 |
| `{difficulty}` | 难度名 | 普通 = 「普通」 |
| `{battles_won}` / `{battles_lost}` | 打赢 / 打输几场 | |
| `{node_id}` | 这段文字说的那个点 | 事件所在的点、鼠标停着的点 |
| `{node_type}` | 点的类型名（战斗 / 搜索点……） | 随机点揭开后按揭成的 |
| `{node_danger}` | 危险等级 | |
| `{extract_fee}` | 这个撤离点的费用 | 不是撤离点时 0 |
| `{enemy_name}` | 对手名 | 点内容里有敌人时才有（下同） |
| `{enemy_strength}` | 对手档位 | |
| `{enemy_hp}` / `{enemy_dps}` | 对手生命 / 约多少 DPS | 与真打的是同一份编译 |
| `{enemy_items}` / `{enemy_count}` | 对手带的东西（名字、件数） | 含包 |
| `{battle_data}` | 一行摘要：名（档）生命 DPS 件数：清单 | 战斗点浮窗的默认写法 |
| `{loss_cost}` | 输一场普通战斗扣几点体力 | 节点规则的 `loss_cost.battle`（112） |
| `{faith_points}` / `{faith_tier}` | 激活信仰现在的信力 / 阶 | 没激活是 0（113） |
| `{search_floor_count}` / `{search_floor_text}` | 搜索点每次保底几件 / 逐件下限的说明（「一件绿及以上、两件任意」） | 只在搜索点浮窗的保底那一行里（127） |

### 1.0 带类型的占位符（112，作者定：颜色跟着类型走）

作者只写一个记号，颜色与粗体自动加上，**不用再手工包 `{c:…}`**。名字都读定义（跟语言、改名不漏）。

| 写法 | 换成 | 颜色 |
|---|---|---|
| `{char}` | 当前角色名（没角色 = 「你」） | `hp`（不加粗）。`{char_name}` 仍是不上色的裸值 |
| `{item:<道具 id>}` | 那件道具的名字 | 按稀有度（和悬浮窗里的名字同色）+ 粗体 |
| `{enemy:<敌人 id>}` | 敌人的名字 | `danger` + 粗体 |
| `{ui:<文字>}` | 按钮 / 屏名，原文（英文界面查 `TextTemplate.TERMS_EN`） | `good` + 粗体 |
| `{zone:<文字>}` | 界面区域：地上、仓库、棋盘 | `grant` + 粗体 |
| `{key:<键>}` | 按键 | `dim` + 粗体 |
| `{item_stat:<道具 id>:<字段>}` | 那件道具的数（见 1.1） | `fg` + 粗体 |
| `{faith:<信仰 id>}` | 信仰名（113） | `faith` + 粗体 |
| `{faith_threshold:<信仰>:<阶>}` | 第几阶的信力阈值 | `fg` + 粗体 |
| `{faith_deed:<信仰>:<行为类型>:<字段>}` | 行为构件的数（`{faith_deed:brute:damage:cap}`） | `fg` + 粗体 |
| `{faith_offer:<信仰>:<标签>:<字段>}` | 认这个标签的献祭规则的数（`{faith_offer:brute:bone:multiplier}`） | `fg` + 粗体 |
| `{faith_perk:<信仰>:<效果类型>:<字段>}` | 信仰级效果的数（`{faith_perk:brute:altar_bless:cost}`） | `fg` + 粗体 |

`{item:}` `{enemy:}` `{item_stat:}` `{faith…:}` 的 id 导入时查：写错了导入失败（事件文本、章节规则卡）。标题与选项文字走纯文字（颜色剥掉、名字照换）。

**选项的门禁提示**（113）：选项的 `hint_when_hidden` 是一句模板。条件没过时，藏起来的选项（`hide_when_locked`）在事件屏底部灰字显示它，灰掉的选项用它替代条件的默认说明。教程用它说「为什么现在不行」。

`extra` 字典可覆盖 / 追加任何键；带 `enemy_content` 时按那份内容算对手的键（搜索遭遇的事件用）。

## 1.1 定义自身字段（104 第十节）

**说明文本里的数只能来自字段**：作者写 `{字段名}`，不写死。`description`（道具、信仰、角色、成就、难度、局内 buff、猎手）、
信仰的 `note`（献祭 / 等级效果 / 道具的按阶功能）、事件选项的 `label` 渲染时，上下文是**这个定义自己的数值字段**（`core/text/text_params.gd`，反射出来，内容类不用写）：

| 来源 | 键 | 例 |
|---|---|---|
| 数值字段（int / float） | 同名 | 成就 `{amount}`、局内 buff `{duration_steps}`、信仰道具按阶功能 `{per_points}` `{max_stacks}`、献祭 `{multiplier}` |
| 值是数的字典 | 字典的键 | 角色 `base_stats` → `{max_hp}` `{max_stamina}` |
| 数组里注册表里有名字的构件（事件结果 / 条件、局内效果、侵蚀……） | `<类型>_<字段>`，同类型取第一个 | `{change_money_amount}` `{spend_vitality_amount}` `{restore_vitality_amount}` `{pass_time_actions}` `{steps_within_min_steps}` `{vitality_max_bonus_amount}` `{luck_bonus_amount}` |
| 数组里其余对象（属性修饰 `mods`） | 第一个元素的字段，不加前缀 | `{amount}`（133 之前是 `{mult_percent}` / `{flat}`） |
| 单个子对象（道具的 `combat`） | 递归进去，不加前缀 | |

事件选项的键并进事件正文的上下文（第 1 节的键照样能用）。整数值的 float 显示成整数（`4.0` → `4`）。

**过滤器**：`{键|abs}` 取绝对值（「给他 {change_money_amount|abs} 币」，字段是 -10）、`{键|signed}` 带正负号（「伤害 {amount|signed}%」→「伤害 -10%」）。不认识的过滤器整个记号原样保留。

**别的道具的数**：`{item_stat:<道具 id>:<字段>}`（教程用：「塔盾每下减 {item_stat:tower_shield:armor}」）。从那件道具的定义里找，先 `combat` 再整份定义：
`stat` 是这个名字的属性修饰取它的 `amount`（`{item_stat:warding_charm:max_shield}`），否则取同名的数值字段或字典键（`base_stats` 的 `{item_stat:leather_armor:max_shield}`、伤害修正的 `flat`）。找不到原样保留。

**`note` 是补充，不覆盖**：信仰级效果、献祭、道具的按阶功能，界面上的主句一律由 `describe()` 按字段生成，`note` 接在后面，为空就没有。
主句已经说清楚的就不要写 `note`。阶统一写 `Lv.n`。

**检查**：上面这些文字（剥掉 `{…}` 与 BBCode 之后）还含阿拉伯数字的是 **error**：`tools/import_content.gd` 导入失败，`tools/check_content.gd`（`tools/test.sh` 每次跑）退 1。
汉字数（「三秒一下」）不算。2026-10-02 作者定升为 error；开关是 `TextLint.STRICT`（`core/authoring/text_lint.gd`）。

## 2. 样式码

翻成 RichTextLabel 的 BBCode。Godot 原生 BBCode（`[color=#…]`、`[b]`、`[i]`、`[url]`……）照样能写，样式码只是简写。

| 写法 | 效果 |
|---|---|
| `{c:名}…{/c}` | 变色。名：`fg` `dim` `hp` `armor` `stamina` `mana` `heal` `grant` `receive` `warn` `danger` `good` `faith`；175 补 5.4 的伤害类型字 `fire` `frost` `thunder` `toxin` `true`（火焰 / 冰霜 / 闪电 / 毒素 / 流血伤害）与元素状态 `scorch` `chill` `shock` `poison` `bleed`（灼伤 / 寒冷 / 麻痹 / 中毒 / 流血）（见 `TextTemplate.STYLE_NAMES`，颜色在 `data/authoring/ui/text_colors.json`） |
| `{c:#ff8800}…{/c}` | 十六进制颜色 |
| `{b}…{/b}` | 粗体 |
| `{i}…{/i}` | 斜体 |

`TextTemplate.plain()` 把样式剥掉只留文字（Label、日志、按钮上用）。

## 3. 节点浮窗（鼠标停在地图节点上）

- **开关**：`ChapterDef.node_tooltips`（作者：第二章开放，默认关；序章、第一章都关）。设置屏「节点浮窗预览」（`GameSettings.node_tooltips_preview`）开了就不看章节，给开发期看效果。
- **内容切换**：`ChapterDef.tooltip_mode` = `"default"` 用内置模板；`"custom"` 用 `ChapterDef.tooltip_texts`（类别 → 模板，缺的类别退回内置）。
- **单点覆盖**：节点内容 `tooltip`（这个点专有的一句），最优先。
- **类别**（`NodeTooltip.category_of`）：`battle`（战斗 / 精英 / 核心，没用过的）、`visited`（任何用过的点）、`search`、`event`、`shop`、`rest`、`extract`、`random`、`spawn`、`other`。
- **内置模板**（`NodeTooltip.DEFAULTS`）：

| 类别 | 内置文字 |
|---|---|
| battle | `{c:danger}{enemy_name}{/c}（{enemy_strength} 档）` / 生命、DPS / 带着几件：清单；**下面画对手的棋盘** |
| visited | 这里已经没东西了。 |
| search | 这里有值得搜索的东西，但翻得越久越可能惊动附近的人。 |
| event | 这里可能会发生什么。 |
| shop / rest / extract / random / spawn | 一句说明 |

## 4. 道具悬浮窗（鼠标停在任何容器视图里的道具上）

`ItemTooltip.describe(inst, board)`：名（按稀有度上色）、稀有度、几格、值；标签；包的格数与包体加成；基础属性；每条规则「[时机] 效果……」；
**武器**（带 `weapon` 标签）多写冷却与约 DPS（在棋盘上按棋盘编译，否则单独编）；非武器的定时效果只写「（每 N 秒）」；
增益槽 / 受益槽的格数、过滤标签与加成；信力按阶的加成；套装 id。控件是 `HoverTip`，整理面板、容器屏、战前准备屏、地图都用它。

096：**标签、伤害类型、属性键都按当前语言显示名字** —— 标签与伤害类型是内容（`data/authoring/tags`、`damage_types`，`display_names` / `descriptions`），属性键在 `Glossary.STAT_NAMES`（zh / en）；没登记的显示原词。
信仰加成的词条在局里按状态上色：生效白、没生效灰（`ItemTooltip.faith_probe`），「信仰道具」那行写「现在已激活（Lv.n）/ 现在休眠 / 还没激活（要信物）」。

## 4.1 耐力消耗评估

整理面板读数下一行「耐力消耗：低 / 中 / 高 / 极高」，停上去看每秒平均消耗与回复（`StaminaEstimate`）。分档按 消耗 / 回复：< 0.6 低、< 1.0 中、< 1.6 高、其余极高。

## 4.2 双击

任何容器视图里双击一件 = 快速置入：地上 → 棋盘；棋盘 → 容器（战利品 / 收获箱，有的话）否则地上；容器 → 棋盘（没空间提示并到地上）。没亮出来的不动。

## 5. 相关的数据键（节点内容 / 敌人内容 / 章节）

| 在哪 | 键 | 意思 |
|---|---|---|
| 节点内容 | `search_max` `search_curve` `search_finds` | 搜索覆盖（083） |
| 节点内容 | `search_again_events[k]` `search_done_event` `search_encounter_event` `search_destroyed_event` | 搜索循环各屏的事件（084，缺的按 `SearchRules` 的 `again_event` 等） |
| 节点内容 | `encounter` | 写死的遭遇（敌人内容） |
| 节点内容 | `tooltip` | 这个点的浮窗文字 |
| 敌人内容 | `enemy` `strength` `board` `items[{id, at, rot}]` | 谁、几档、棋盘、身上的东西。**有包就和玩家一样**：`board_of` 开 `requires_bag`，包先摆、道具只能在包上（可跨两个包） |
| 敌人内容 | `guaranteed_drops` | 打赢必掉，**只认身上有的** |
| 敌人内容 | `base_stats` | 这个点的敌人自己的基线（覆盖敌人定义与档位倍率之后的数；教程敌人靠它不跟全局涨） |
| `DropRule` | `min_drops` `bags_always_drop` | 打赢至少掉几件身上有的、**包不算在名额里**（标准规则 1）；敌人的包必掉（默认开） |
| `GameSettings` | `loot_auto_close` | 拿走最后一件后自动关战利品 / 容器屏（默认关） |
| 所有内容定义 | `display_names` | 别的语言的名字 `{"en": …}`，界面走 `Names.of`（088）；`display_name` 是中文原文 |
| `ItemDef` | `description` | 一句说明（悬浮窗第二行、图鉴） |
| `ItemDef` 标签 | `keepsake` | 特殊道具：不进背包、不能生成、拿到只是通知 + 图鉴点亮；能力由别的标签说明（`node_tooltips` → 节点浮窗） |
| `ChapterDef` | `rules` | 本图规则卡（≤ 3 条）：第一次进图弹，暂停菜单再看（091） |
| `ItemDef` | `requires_unlock` | 成就给的解锁 id；没解锁不进池、图鉴灰着写途径（091） |
| `EventDef` / `EventOption` | `titles` `texts` / `labels` | 事件标题 / 正文 / 选项的别的语言（091）；当前语言没写回落原文 |
| 事件条件 / 后果 | `has_flag`（flag / min_value / absent）、`set_flag`（flag / value / add / clear） | 局外旗标（091）：剧情推进、见过谁，跟局外存档 |
| `AchievementDef` | `kind` `amount` `target` `grants` `description` `hidden` `order` | 成就（091）：条件种类与数 / 对象、完成给的解锁 id、解锁途径文字、隐藏、先后 |
| `ChapterDef` | `starting_keepsakes` | 这一章开局发的特殊道具（序章二：望远镜），记在局外 |
| `NodeRules` | `loss_cost.hunter` | 输给猎手扣的体力（088，1） |
| 节点内容 / `HunterDef` | `loss_cost` | 这一场输了的代价：不写按规则表（核心必死）；0 无代价、-2 必死、大于 0 扣那么多（088，进入战斗的函数也能直接传） |
| `EnemyDef` | `item_tags` `signature_by_strength` | 身份标签（只从带任一这些标签的道具里抽）；档位 → 那一档起必带的招牌（088） |
| `RunState` | `node_storages` | 各点留着的地上（离开留下、回来取回，跟存档；088） |
| `ItemDef` | `dormant_keeps_combat` | 信仰道具休眠时保不保留自己的战斗定义（通用效果：盾的减伤、武器的攻击力；默认 true）；没有 combat 的护符休眠即彻底失效（087） |
| `DropRule` | `boss_rarity` | 击败核心点 BOSS 保底掉一件这个稀有度的（4 = 金；-1 不保底），不看它身上有没有（087） |
| `NodeRules` | `boss_extracts` | BOSS 倒下、收完战利品直接撤离结算（087，默认开） |
| `EconomyRules` | `shop_sell_ratio` | 卖给店里回定价的几成（087，一半）；`shop_slots` 个栏位每格一块 ≥ 3×4 的小棋盘 |
| 稀有度 | 0 白 / 1 绿 / 2 蓝 / 3 紫 / 4 金 / 5 红 | 087 作者定；按稀有度下标的表（掉落率、商店权重、揭示耗时）都是六档，超出按最后一档 |
| `ChapterDef` | `step_limit` `closing_extract` `safes` | 全局倒计时（行动点，0 = 没有；归零 = 行动失败 `time_out`）；过半关掉离出生点最近的免费撤离点（`node.content.closes_at`）；这一章几个保险箱点（092） |
| `NodeRules` | `event_groups` | 成组限量的事件（093）：`{组: {max_per_map, early, chance, events: {id: 权重}}}`；「触发信仰」每图最多一位神、偏前期、必出现（chance 1.0） |
| `FaithDef` | `deeds[].multiplier / cap`、`thresholds`、`offerings[]`、`perks[].tier` | 信仰流派（093）：行为倍率与每场上限、各级阈值、献祭规矩（标签 / 格子数 / 体积档 / 倍率 / 乘格子数）、各级效果与它们的数（`low_hp_empower.min/max_percent`、`enchant_weapons.fixed/percent/pray_percent/pray_curve`、`altar_sacrifice_hp.hp_cost/stamina_gain/haste_percent`、`food_shield.base/per_rarity`、`gift_on_enter.by_type`……） |
| `MetaRules` | `safe_size` | 保险箱几格（092，初始 3×3；放进去的视为已带出，战败也带得出；**关上或走开就锁**，不能再改） |
| `FaithDef` | `blessings[]` `convert_chance` `convert_per_tier` | 赐福模板（095：条件 / 前缀 / 稀有度 +1 / 价值 ×1.5 / 功能与生效方式）；包内每步转化概率 0.03 + 每级 0.01 |
| `DropRule` / `SearchRules` | `bless_chance` `bless_chance_active` | 掉落 / 搜索的普通道具换成赐福版的概率（没激活 0.05 随机一位神 / 激活 0.2 只换那位） |
| `FaithBonus` | `mode` `per_points` `max_stacks` | 信仰道具功能的生效方式：tier / active / scaled（每 N 信力一份，最多 M） |
| `ChapterDef` / `MapScaleProfile` | `carry_budget` `carry_over_cost` | 带入预算（094）：从仓库带进一局的总价值预算（小 600 / 中 900 / 大 1200，章节兜底 600），每超 50 价值倒计时 −1 |
| `MapScaleProfile` | `step_limit` | 这个规模档的全局倒计时（092：小 36 / 中 60 / 大 90；0 = 用章节的） |
| 节点类型 | `safe`（符号 K） | 保险箱点：不算用过，每次踩上都开保险箱屏（092） |
| `MetaRules` | `sell_ratio` | 基地「出售」页卖掉仓库道具回定价的几成（091，0.5；`ItemValue.of × 比例` 向下取整）；一键出售按稀有度档筛 |
| `GameSettings` | `bg_theme` | 背景底色（091）：`UiPalette.BG_THEMES` 的 id（graphite 石墨默认 / dark / slate / dusk / moss / mist），设置屏挑，所有屏与编辑器跟着 |
| `GameSettings` | `language` | 界面语言 `zh` / `en`（主菜单切）；界面文字走 `UiText.t(key)`，表在 `core/text/ui_text.gd`，现在覆盖主菜单与 buff 制作器 |
| `BuffDef` | `max_stacks` `duration_sec` | `max_stacks 0 = 不限层`（通常如此）、`1 = 不可叠层`；可叠层的永续、不许填时长（导入器拦）。Buff 制作器 `ui/buff_editor` 按这套规矩联动 |
| 档位表 `StrengthTier` / `EnemyDef` | `bags` | 这一档 / 这种敌人背的包，包不计入件数 |
| `SearchRules` | `again_event` `done_event` `encounter_event` `destroyed_event` | 搜索循环的默认事件 |
| `ChapterDef` | `auto_spawn` `skip_setup` `intro_event` | 开局站在出生点、不走开局屏、先过开场事件 |
| `ChapterDef` | `hidden_by_unlock` `vitality_bonus` `starting_items` `next_chapter` | 拿到某解锁后不再列（教程收起）；这一章多给的体力；这一章开局发的道具；撤离成功后直接进的下一章（序章串起来） |
| 事件后果 | `extract` | 从这个撤离点撤离（撤离点的对话里用）；付不起在结果页说 |
| 开局 | 地图规模 | 环形配置的 `scales`（小 / 中 / 大）在开局屏可选；`RunState.map_scale` 跟存档 |
| 节点 `layout` | `col` `row` | `line` 布局：列从左到右，行上下错开（岔路） |
| `recipes`（内容种类） | `inputs[2]` `output` `note` | 合成配方：一局里把一件**拖到**棋盘上另一件上面（114 作者定），两件有配方就立刻合成，产物落在被压那件的位置、装不下到地上并提醒 |
| `ChapterDef` | `node_tooltips` `tooltip_mode` `tooltip_texts` | 节点浮窗 |

## 6. 词条（悬浮窗侧边的小窗，087）

道具说明里指向名词的地方**只写名词**，每个名词在悬浮窗侧边有一块小窗写具体效果。逻辑在 `core/text/glossary.gd`（[Glossary]），画在 [HoverTip]，两者分开 —— 换正式渲染时保留这套「主文字 + 侧边词条」。

| 词条来源 | 怎么来 | 例 |
|---|---|---|
| 固定词条 `Glossary.TERMS` | 关键词 → 解释，手写 | 自发、开战时、冷却、急速、护甲、护盾、耐力、耗耐力、永续、叠层、休眠、信力、合成、增益槽、受益槽、中毒、流血 |
| 标签词条（096） | 登记了 `description` 的标签（`TagRegistry.describe`），按当前语言 | 武器 → 「会出手造成伤害的道具；包里每一件武器都各自出手。」 |
| buff 词条 | 这件道具会施加的 `BuffDef`（自己的规则、信力加成、buff 自带规则里再施加的），说明由 `describe_buff` 按定义生成 | 血怒 → 「增益　不可叠层　持续 10.0 秒 / 增伤 +10%」 |

- `ItemTooltip.describe_full(inst, board)` → `{text, terms}`；主文字里的词条标成紫色下划线（`Glossary.mark`）。
- `ApplyStatus.describe()` 只写「施加中毒」「获得血怒」；永续 / 层数 / 时长在词条里。
- 战斗屏的 buff 图标（名字第一个字）悬浮时也用 `describe_buff`。
- 属性修饰的中文统一走 `Glossary.mod_text`：「伤害 +10%」「护甲 +4」「急速 +20%（急速）」。
