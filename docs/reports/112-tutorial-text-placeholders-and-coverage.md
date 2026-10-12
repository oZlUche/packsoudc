# 教程序章文案回顾：占位符化（带色）与指引覆盖清单（112）

> 架构 thread，2026-10-03。作者：「回顾教程序章的文案和指引，不要使用纯文本而是插入特定占位符，比如 {char_name} 代表当前使用角色的名字，且文本颜色不同。做完后总结教程目前完成了哪些指引，欠缺哪些。」
> 范围：两张序章（`prologue` 6 点、`prologue_2` 9 点）的 29 条事件、两张图的节点浮窗、序章二的规则卡。本文是审稿 + 改法，不实现。

## 一、现状

- 占位符机制已有（`core/text/text_template.gd`，手册 `docs/text-placeholders.md`）：`{char_name}` 等 20 多个局内键、`{item_stat:id:字段}` 读别的道具的数、样式码 `{c:名}…{/c}` / `{b}`。
- 29 条教程事件里，**只有两条开场白用了 `{char_name}`**（手工包了 `{c:hp}`），4 条用了 `{item_stat}`。其余道具名、对手名、界面按钮名、点的类型全是**写死的纯文本**，没有颜色区分；英文模式下这些名字也不会跟着翻译（`Names.of` 管不到正文里的字）。
- 汉字数字还有 6 处（「三秒一下」「一下二十多点」「一下十二点」「六秒一次」「三天后」「输两场」）—— 104 的 lint 只拦阿拉伯数字，所以没报，但一样会过期。

## 二、改法：带类型的占位符，颜色跟着类型走

作者的要求是「占位符 + 颜色不同」。与其每处手工写 `{c:hp}{char_name}{/c}`，不如**占位符自带颜色**：类型决定颜色，作者只写一个记号。`TextTemplate` 加一张前缀表：

| 写法 | 换成 | 颜色 | 说明 |
|---|---|---|---|
| `{char}` | 当前角色名（没角色 = 「你」） | `hp`（和开场白现在一致） | `{char_name}` 保留为**不上色**的裸值，老文本不改也能用 |
| `{item:id}` | 那件道具的名字（`Names.of`，跟语言） | **按稀有度**（`ItemPainter.rarity_color`）+ 粗体 | 和悬浮窗里的名字同色，玩家一眼对得上 |
| `{enemy:id}` | 敌人定义的名字 | `danger` | 节点浮窗里对手名已是这个色 |
| `{ui:文字}` | 原文 | `good` + 粗体 | 按钮 / 屏名：`{ui:开战}` `{ui:搜索}` `{ui:战前准备}`；英文模式查 `UiText` |
| `{zone:名}` | 原文 | `grant` | 界面区域：暂存区、仓库、棋盘 |
| `{key:B}` | 按键 | `dim` 粗体 | 「按 {key:B} 开背包」 |
| `{item_stat:id:字段}` | （已有）数 | `fg` 粗体 | 现在不上色，顺手统一 |

- 渲染层：`TextTemplate.render` 认前缀 → 查值 → 包成 `[color=@名][b]…[/b][/color]`；`plain()` 照样剥掉。颜色名复用 `UiPalette.STYLE_COLORS`，稀有度色走 `ItemPainter`。
- 校验：导入器对 `{item:…}` / `{enemy:…}` 查 id 存在（和 `{item_stat}` 一样），写错当场报。
- 事件编辑器预览已经走 `render`，不用改。

## 三、逐条审稿（29 条事件 + 浮窗 + 规则卡）

列的是**要换成占位符的词**；没列的句子不动。

### 序章一（`prologue`）

| 事件 | 换 |
|---|---|
| `tut_intro` | `{c:hp}{char_name}{/c}` → `{char}`；「三天后」→ 不换（叙事，不是数值） |
| `tut_search_1` | 「搜索」→ `{ui:搜索}`；「暂存区」→ `{zone:暂存区}`（两处） |
| `tut_search_1_again` | 「制式短剑」→ `{item:shortsword}`；「伤药」→ `{item:salve}` |
| `tut_search_1_done` | 「皮甲」→ `{item:leather_armor}`；`{item_stat:leather_armor:max_shield}` 保留；「暂存区」→ `{zone:暂存区}` |
| `tut_battle` | 「暂存区」×2 → `{zone:暂存区}`；「开战」→ `{ui:开战}`；「战前准备」→ `{ui:战前准备}` |
| `tut_search_2` | 无 |
| `tut_search_2_again_1` | 「弯刀」→ `{item:scimitar}` |
| `tut_search_2_again_2` | 「纱布」「口粮」「圆盾」→ `{item:bandage}` `{item:ration}` `{item:round_shield}`；「暂存区」→ `{zone:暂存区}` |
| `tut_search_2_encounter` | 「蛮兵」→ `{enemy:brute}`；「战前准备」→ `{ui:战前准备}` |
| `tut_elite` | 「精英」保留（类型词）；「开战」→ `{ui:开战}` |
| `tut_extract` | 「仓库」→ `{zone:仓库}`；「暂存区」→ `{zone:暂存区}` |

### 序章二（`prologue_2`）

| 事件 | 换 |
|---|---|
| `tut2_intro` | `{c:hp}{char_name}{/c}` → `{char}`；「匕首」→ `{item:knife}`；`{c:good}【望远镜】{/c}` → `{item:spyglass}` |
| `tut2_search_1` | 无 |
| `tut2_search_1_again` | `{b}塔盾{/b}` → `{item:tower_shield}`；「一锤子二十多点」→ `{item_stat:warhammer:damage}` 点 |
| `tut2_search_1_done` | `{b}板甲{/b}` → `{item:plate_cuirass}`；「暂存区」→ `{zone:暂存区}` |
| `tut2_search_2_again_1` | `{b}毒药瓶{/b}` → `{item:poison_vial}`；「匕首」「涂毒匕首」→ `{item:knife}` `{item:poisoned_knife}`；「六秒一次」→ 每 `{item_stat:poison_vial:seconds}` 秒一次（`seconds` 是规则节奏字段，`_item_stat` 要能找到 `rules[0].cadence.seconds`，现在的查找只看数值字段 / 字典 / `stat` 修饰，**要补一条**）；「暂存区」→ `{zone:暂存区}` |
| `tut2_search_2_again_2` | `{b}长剑{/b}` → `{item:longsword}`；「一下十二点」→ `{item_stat:longsword:damage}` 点；「匕首」→ `{item:knife}` |
| `tut2_search_2_done` | `{b}长条包{/b}` → `{item:bag_long}`；「长剑」「匕首」「毒药」→ `{item:longsword}` `{item:knife}` `{item:poison_vial}` |
| `tut2_battle_swarm` | 「匕首」→ `{item:knife}`；「塔盾」「板甲」→ `{item:…}` |
| `tut2_battle_heavy` | 「战锤」→ `{item:warhammer}`；「三秒一下，一下二十多点」→ `{item_stat:warhammer:seconds}` 秒一下、一下 `{item_stat:warhammer:damage}` 点；「板甲」「塔盾」→ `{item:…}` |
| `tut2_battle_ward` | 「护身符」→ `{item:warding_charm}`；「涂毒匕首」→ `{item:poisoned_knife}` |
| `tut2_battle_cure` | 「长剑」→ `{item:longsword}`；对手名 → 标题用 `{enemy:apothecary}`（标题也过 `render`，`title_for` 要确认） |
| `tut2_lesson` | 「输两场」→ 体力 `{vitality}` 点、输一场扣 `{loss_cost}`（新键，取 `node_rules.loss_cost.battle`） |
| `tut2_extract` | 「仓库」→ `{zone:仓库}` |

### 节点浮窗与规则卡

- `tutorial2.json` 四个战斗点的 `tooltip` 已用 `{battle_data}` + `{c:dim}`，不动。
- `prologue_2.rules`（规则卡两条）写死「护具」「毒药瓶」「匕首」：规则卡现在**不过 `render`**（`map_screen.gd:232` 直接取字符串），改成过一遍，再把名字换成 `{item:…}`。

### 事件标题

`tut2_battle_*` 四条标题是对手名（游兵 / 重击手 / 持符者 / 药师），改 `{enemy:id}` 后与敌人定义同源，改名不漏。

## 四、指引覆盖清单

### 已覆盖（两张序章）

| 主题 | 在哪教 |
|---|---|
| 地图怎么走、三角标、相邻一步 | `tut_intro` |
| 搜索循环：搜几次、越搜越危险、揭示、关掉回事件 | `tut_search_1` `tut_search_2` |
| 暂存区 = 这个点的临时区、留在点上、回来能拿、撤离不带 | `tut_search_1` `_done` `tut_battle` `tut_extract` `tut2_search_1_done` |
| 包放不下要取舍 | `tut_search_2_again_2` `tut2_search_1` `tut2_search_2_done` |
| 战前准备屏：对手棋盘 / 自己棋盘、只有包里的参战、自动战斗、开战即定 | `tut_battle` |
| 邻接会互相加成（一句带过） | `tut_battle` |
| 精英更硬、输了扣更多体力 | `tut_elite` |
| 遭遇 = 就地打、赢了掉落 | `tut_search_2` `_encounter` |
| 体力：输了扣、归零结束 | `tut_search_2` `tut2_lesson` |
| 撤离：结束一局、包里的回仓库 | `tut_extract` `tut2_extract` |
| 望远镜 / 节点浮窗：看对手再选路 | `tut2_intro` |
| 防护（固定减伤）vs 一次性护盾，对快手 / 重击 | `tut2_search_1_again` `_done` 四场战斗 |
| 合成：挨着放、走到下一点自动合、放不下进暂存区 | `tut2_search_2_again_1`（114：改为「拖到上面立刻合」，并提前到序章一） |
| 毒无视防护与护盾；解毒反制；叠盾怕毒 | `tut2_battle_ward` `_cure` |
| 「没有万能装备，先看对手」 | `tut2_lesson` |
| 下一局是随机局：挑角色 / 规模 / 带东西 | `tut2_extract` |

### 欠缺（正式局会遇到、序章没教）

| 主题 | 现状 | 建议 |
|---|---|---|
| **耐力**：武器出手耗耐力、口粮加耐力、整理面板的「耐力消耗」档 | 一字未提；口粮只当「包装不下的东西」 | 序章一搜到口粮时一句：它加 `{item_stat:ration:max_stamina}` 耐力，出手快的武器很吃耐力 |
| **邻接增益 / 受益格** | 「挨着放会互相加成」一句，没示范 | 序章一的箭 / 弓或盾 + 剑摆一次，浮窗里看格子亮 |
| **信仰 / 信物 / 神坛 / 献祭 / 休眠** | 完全没有 | 这是第一章的核心系统；需要第三张教学图或第一章前几点的引导事件 |
| **商店 / 钱 / 卖东西** | 序章经济规则没有付费撤离，图上没商店 | 序章二加一个商店点，或第一章首个商店弹一次说明 |
| **保险箱点、付费撤离、全局倒计时、过半关免费撤离点** | 没有 | 第一章进图规则卡（已有机制）承担 |
| **猎手（地图上移动的敌人）** | 没有 | 进阶难度才有，放难度说明 |
| **休息点 / 事件点** | 序章二有一个事件点但只是讲课 | 第一章首个休息点弹说明 |
| **基地：仓库 / 出售 / 图鉴 / 成就 / 局外 buff / 科技（110）** | `tut2_extract` 一句「包里的东西带回仓库」 | 第一次进基地弹一张引导卡（局外旗标 `seen_base` 控制一次） |
| **开局屏：挑章节 / 角色 / 带入** | `tut2_extract` 一句预告 | 第一次进开局屏的提示条 |
| **战斗回放的操作：倍速 / 跳过 / 日志** | 没有 | 第一场战斗回放屏顶一行提示（109 倍速已跨局记住） |
| **buff 层 / 轴（加速、灼烧、格挡）在面板上的样子** | 没有 | 第一章里第一次出现带 buff 的对手时浮窗说明即可 |
| **双击快速置入、R 旋转、右键取消** | 只在整理面板底部一行灰字 | 序章一第一次开包时高亮那一行；或 `tut_search_1` 加 `{key:R}` 旋转一句 |

### 机制上的欠缺（和文案无关，但影响「指引」成立）

- 教程**全是文字，没有门禁**：`tut_battle` 让玩家把武器放进包里，但按「进入战前准备」时没检查；玩家空手开打会直接输。建议给事件选项加条件 `board_has_tag: weapon`（事件条件已有 `has_flag` 这类框架），不满足时选项灰并提示。
- 没有「指向界面元素」的能力（箭头 / 高亮）。先不做，占位符上色是最便宜的替代。

## 五、改动范围

| 批 | 内容 | 文件 |
|---|---|---|
| ① 机制 | 前缀占位符 `{char}` `{item:}` `{enemy:}` `{ui:}` `{zone:}` `{key:}` + 自动上色；`_item_stat` 能读 `rules[].cadence.seconds`；新键 `{loss_cost}`；规则卡过 `render`；导入器查 id | `core/text/text_template.gd`、`core/authoring/content_importer.gd`、`ui/game/map_screen.gd`、`docs/text-placeholders.md` |
| ② 内容 | 第三节逐条改 29 条事件 + 规则卡 | `data/authoring/events/tut*.json`、`chapters/prologue_2.json` |
| ③ 测试 | 每种前缀一条渲染断言（颜色、粗体、plain 剥干净）；`{item:不存在}` 导入报错；序章事件全部 render 后不含 `{`（没漏键） | `tests/ui/test_text_and_tooltips.gd`、`tests/authoring/` |

第四节「欠缺」的补课：作者定教程只做三张序章，信仰全套由第三张教（113）；其余欠缺交第一章规则卡与首次出现的一次性提示。

## 待作者定（不挡执行，按推荐先做）

1. 占位符自带颜色（推荐）还是继续手工 `{c:…}` 包？
2. 道具名按稀有度上色（推荐，和悬浮窗一致）还是统一一种「道具色」？
3. 教程选项加门禁（没放武器不让开战）：推荐这次顺手加 `board_has_tag` 条件。
