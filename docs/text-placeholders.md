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
| `{board_count}` / `{storage_count}` | 棋盘上 / 暂存区里几件 | |
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

`extra` 字典可覆盖 / 追加任何键；带 `enemy_content` 时按那份内容算对手的键（搜索遭遇的事件用）。

## 2. 样式码

翻成 RichTextLabel 的 BBCode。Godot 原生 BBCode（`[color=#…]`、`[b]`、`[i]`、`[url]`……）照样能写，样式码只是简写。

| 写法 | 效果 |
|---|---|
| `{c:名}…{/c}` | 变色。名：`fg` `dim` `hp` `shield` `stamina` `mana` `heal` `grant` `receive` `warn` `danger` `good`（见 `TextTemplate.COLORS`，取自 `UiPalette`） |
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

## 4.1 耐力消耗评估

整理面板读数下一行「耐力消耗：低 / 中 / 高 / 极高」，停上去看每秒平均消耗与回复（`StaminaEstimate`）。分档按 消耗 / 回复：< 0.6 低、< 1.0 中、< 1.6 高、其余极高。

## 4.2 双击

任何容器视图里双击一件 = 快速置入：暂存区 → 棋盘；棋盘 → 容器（战利品 / 收获箱，有的话）否则暂存区；容器 → 棋盘（没空间提示并进暂存区）。没亮出来的不动。

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
| `GameSettings` | `language` | 界面语言 `zh` / `en`（主菜单切）；界面文字走 `UiText.t(key)`，表在 `core/text/ui_text.gd`，现在覆盖主菜单与 buff 制作器 |
| `BuffDef` | `max_stacks` `duration_sec` | `max_stacks 0 = 不限层`（通常如此）、`1 = 不可叠层`；可叠层的永续、不许填时长（导入器拦）。Buff 制作器 `ui/buff_editor` 按这套规矩联动 |
| 档位表 `StrengthTier` / `EnemyDef` | `bags` | 这一档 / 这种敌人背的包，包不计入件数 |
| `SearchRules` | `again_event` `done_event` `encounter_event` `destroyed_event` | 搜索循环的默认事件 |
| `ChapterDef` | `auto_spawn` `skip_setup` `intro_event` | 开局站在出生点、不走开局屏、先过开场事件 |
| `ChapterDef` | `hidden_by_unlock` `vitality_bonus` `starting_items` `next_chapter` | 拿到某解锁后不再列（教程收起）；这一章多给的体力；这一章开局发的道具；撤离成功后直接进的下一章（序章串起来） |
| 事件后果 | `extract` | 从这个撤离点撤离（撤离点的对话里用）；付不起在结果页说 |
| 开局 | 地图规模 | 环形配置的 `scales`（小 / 中 / 大）在开局屏可选；`RunState.map_scale` 跟存档 |
| 节点 `layout` | `col` `row` | `line` 布局：列从左到右，行上下错开（岔路） |
| `recipes`（内容种类） | `inputs[2]` `output` `note` | 合成配方：两件拖到一起先配对（棋盘上画「合」），走到下一个点时合成，产物落在被压那件的位置、装不下进暂存区并提醒 |
| `ChapterDef` | `node_tooltips` `tooltip_mode` `tooltip_texts` | 节点浮窗 |
