# 方案：序章三「祭坛」—— 教信仰全套（信物激活、信力、献祭、特殊操作、切换）（113）

> 架构 thread，2026-10-03。作者定教程只做序章三张图：一教拿取 / 自动战斗 / 搜索 / 输了扣体力（已有 `prologue`），二教浮窗预览 / 岔路 / 对症带装备（已有 `prologue_2`），三教「遇到信仰事件，通过信物激活信仰、信力系统、神坛的献祭、特殊行为、如何切换信仰等」。
> 本文是序章三的设计：地图、节点、事件文案（按 112 的占位符写）、要补的机制。不实现。

## 一、能直接用的东西

| 要教的 | 现成机制 |
|---|---|
| 信仰事件 | `faith_call` 事件组（随机四神）；教程写死 `tut3_faith_call` → 发【蛮神的护符】（`give_item charm_brute`） |
| 激活 | 棋盘上**最后置入的信物**激活（3.8）；护符是 1 格 `faith_anchor` |
| 信力 | `FaithPower`：蛮神的行为 = 造成 / 受到伤害 × 0.2（每场封顶 30）、失去体力 × 50；阈值 30 / 100 / 200 / 400；地图 HUD 有「信力（蛮神）n，第 k 阶」一行 |
| 神坛 | 休息点的「神坛」选项（`rest_default` 的 `open_altar`，`faith_active` 条件控制显示）→ `AltarScreen`：献祭或特殊操作**二选一** |
| 献祭 | `FaithDef.offerings`：蛮神收骨制品 × 5、血肉 × 5、武器 × 2、≥ 9 格 × 10；点数 = 道具价值 × 倍率 |
| 特殊操作 | 蛮神 1 阶「祈求赐福」（40 信力）、2 阶「献祭生命上限换耐力与急速」 |
| 切换 | 把另一位神的信物重新落下 / 右键信物（099）；休眠的信仰道具文字变灰（107） |
| 门禁 | 事件条件 `faith_active{min_tier}`、`has_item{item, tag, where}`、`rest_part_unused` |

所以序章三**不需要新系统**，要的是一张图、十来条事件、两件小道具、几个占位符、一个条件参数。

## 二、地图：一条线 + 一个小岔，9 个点

`data/maps/tutorial3.json`，角色仍是布鲁图斯（他本来就是蛮族，接蛮神顺），`starting_items: ["shortsword"]`，`vitality_bonus: 2`，`skip_setup / auto_spawn / allow_carry_in: false` 与前两章一致。

| # | 类型 | 内容 | 教什么 |
|---|---|---|---|
| 0 | 出生 | `tut3_intro` | 第三次进来；这片废墟里有人在拜神 |
| 1 | 事件 | `tut3_faith_call`（写死蛮神） | **信物**：拿到护符 → 放进包里 = 激活；HUD 多出信力一行 |
| 2 | 战斗（劫匪，弱） | `tut3_battle_1`，选项门禁 `faith_active` | **信力怎么涨**：打完看信力 +（伤害 × 0.2）；输了扣体力也给 × 50 |
| 3 | 搜索（搜 3 次，固定出货） | `tut3_search`：两件骨制小物 + 【胫骨大棒】 | **祭品**：骨制品是蛮神爱的（× 5）；胫骨大棒带 `faith:brute` 但不是信物（休眠 / 激活的区别先埋一句） |
| 4 | 休息（神坛 A） | `tut3_rest_1` | **献祭**：把骨制品献上 → 过 1 阶（30）→ 1 阶效果「低血增伤」亮起、浮窗变亮；神坛这一次用掉 |
| 5 | 事件 | `tut3_faith_call_sun`（写死日神，发【日神的护符】） | **切换与休眠**：放进日神护符 → 激活变成日神，蛮神那几行灰了、信力一行换成日神 0；右键蛮神护符切回。两位神的信力各记各的 |
| 6 | 战斗（蛮兵） | `tut3_battle_2`，门禁 `faith_active{faith: brute}` | 带着 1 阶打一场：血低时伤害涨；信力攒到 100 上下 |
| 7 | 休息（神坛 B） | `tut3_rest_2` | **特殊操作与二选一**：到 2 阶了 → 神坛上有「祈求赐福（40 信力）」和「献祭生命上限」两个按钮，选一个这次就关；献祭也不能再做 |
| 8 | 撤离 | `tut3_extract` | 三张序章都过了；护符随包带回仓库，下一局带进去就是从这位神开始 |

- 6 → 7 之间信力要稳到 ≥ 100：战斗 1 封顶 30 + 献祭（两件骨制品）+ 战斗 2 封顶 30。献祭点数只看稀有度与倍率（`OfferingRule.value`），余量靠两场敌人的血量定（116：劫匪 60 血、蛮兵 150 血）。
- 不教 3 阶「秒杀精英」和 4 阶「不死」：阈值 200 / 400 一张教学图攒不到，`tut3_extract` 一句话预告即可。
- 规则卡（`rules`）三条：「{item:charm_brute} 放进包里就是信蛮神；最后放下的那枚信物说了算」「神坛上献祭和特殊操作二选一，用了这个点就关」「换神不花钱：放下另一枚信物，或右键它」。

## 三、事件文案（按 112 的占位符写）

只列正文要点与门禁，执行时按这个写 JSON；数一律走字段。

- **tut3_intro**：`{char}` 第三次被送进来。这一带的废墟里有人拜神，拜对了神，神会在战斗里帮你。先往前走。
- **tut3_faith_call**（标题「蛮神的低语」）：沿用 `faith_call_brute` 的叙事，加一段指引：这是一枚**信物**（`{item:charm_brute}`，`{item_stat:charm_brute:cells}` 格）。`{b}放进包里{/b}就算信了 `{faith:brute}`；信了之后，地图左上多一行「信力」。选项「接过护符」→ `give_item`；没有「不拿」选项（教程不给跳过）。
- **tut3_battle_1**：对手是 `{enemy:raider}`。信力是这样涨的：`{faith:brute}` 看的是打出去和挨到的伤害（每点 × `{faith_deed:brute:damage:multiplier}`，一场最多 `{faith_deed:brute:damage:cap}`），还有失去体力（每点 × `{faith_deed:brute:vitality_lost:multiplier}`）—— 输了也不白输。选项「进入战前准备」条件 `faith_active`；不满足时显示的那条选项写「先把 `{item:charm_brute}` 放进包里」（事件选项的 `conditions` 不满足就隐藏，所以要**两条选项**：一条带条件的真选项，一条无条件、无后果的提示选项，后者仅在前者隐藏时有意义 —— 见第四节「门禁的反向提示」）。
- **tut3_search**：这里埋着蛮族的东西。搜三次：`{item:bone_dice}`、`{item:bone_charm_bits}`、`{item:tibia_violence}`。again 事件各一句：骨制品是 `{faith:brute}` 爱的祭品（献祭时 × `{faith_offer:brute:bone:multiplier}`）；胫骨大棒带着蛮神的印记但**不是信物**，放进包里不会换神，只在信蛮神时有额外效果。done：前面是休息点，有神坛。
- **tut3_rest_1**：复用 `rest_default` 的四个选项，但事件正文是教程版：神坛上两件事二选一 —— 献祭（把东西毁了换信力）或特殊操作（阶到了才有）。现在先献祭：把两件骨制品拖上祭品台，看信力过 `{faith_threshold:brute:1}` → 第 1 阶：`{faith_perk:brute:low_hp_empower}`（低血增伤）亮了。提示：胫骨大棒也能献（× `{faith_offer:brute:weapon:multiplier}`），但留着打更划算，自己定。
- **tut3_faith_call_sun**（标题「日神的低语」）：另一座祭坛，`{item:charm_sun}`。拿了放进包里 → 现在信的是 `{faith:sun}`：蛮神那几行灰了（休眠），信力一行换成日神 0 —— 两边的信力各自记着，不会丢。{b}右键{/b} `{item:charm_brute}`（或拖起来放回去）切回蛮神。换神没有代价。选项「接过」→ `give_item charm_sun`。
- **tut3_battle_2**：`{enemy:brute}`。选项「进入战前准备」条件 `faith_active{faith: brute}`；反向提示「你现在信的是日神，右键蛮神的护符切回来再打」。正文：血掉到一半以下时，伤害会涨（1 阶效果），注意回放里的数字。
- **tut3_rest_2**：到 `{faith_threshold:brute:2}` 了 → 神坛上现在有两个特殊操作：「祈求赐福」花 `{faith_perk:brute:altar_bless:cost}` 信力，把棋盘上一件武器换成蛮神赐福版（激活即伤害 +…，按字段）；「献祭生命上限」每次 −`{faith_perk:brute:altar_sacrifice_hp:hp}` 生命上限换 +… 耐力上限与急速。**选一个**，这个神坛就关了，献祭也不能再做 —— 这就是二选一。
- **tut3_extract**：三张序章都过了。`{item:charm_brute}`、`{item:charm_sun}` 跟着包回仓库，下一局带哪枚进去就从哪位神开始；再往上的阶（`{faith_threshold:brute:3}` / `{faith_threshold:brute:4}`）有秒杀精英和不死，正式局里攒。

## 四、要补的机制与内容

### 4.1 占位符（接 112 的前缀表）

| 写法 | 值 | 颜色 |
|---|---|---|
| `{faith:id}` | 信仰名 | 新色 `faith`（取信仰浮窗现在的色） |
| `{faith_points}` / `{faith_tier}` | 当前激活信仰的信力 / 阶 | fg 粗 |
| `{faith_threshold:id:n}` | 第 n 阶的阈值 | fg 粗 |
| `{faith_deed:id:type:字段}` / `{faith_offer:id:tag:字段}` / `{faith_perk:id:type:字段}` | 信仰定义里行为 / 献祭 / 效果构件的数（和 `{item_stat}` 同一套反射查找，只是起点换成 `FaithDef`） | fg 粗 |

统一成一个 `{faith_stat:id:路径}` 也行，三个名字只是好读；执行者定，手册补行。

### 4.2 条件 `faith_active` 加 `faith: StringName`

现在只有 `min_tier`。加 `faith`（空 = 任一），`tut3_battle_2` 要用。顺手给 `has_item` 不动（已够用）。

### 4.3 门禁的反向提示

事件选项条件不满足是**隐藏**。教程要的是「不满足时告诉玩家为什么」，两种做法：

- **推荐**：`EventOption` 加 `hint_when_hidden: String`（模板）—— 隐藏的选项在事件屏底部灰字显示这句。一个字段，所有教程门禁通用，正式局也有用（「钱不够」）。
- 备选：写两条选项（一条有条件、一条反向条件 `faith_inactive`）。多一种条件类型，文案也要写两遍，不推荐。

### 4.4 内容

| 项 | 文件 |
|---|---|
| 章节 `prologue_3.json`：`order 2`、`requires_unlock prologue2_done`、`grants_unlock prologue3_done`、`hidden_by_unlock prologue3_done`、`intro_event tut3_intro`、`node_rules prologue`、`economy_rules prologue`、`rules` 三条 | `data/authoring/chapters/` |
| `chapter_01.requires_unlock` → `prologue3_done`；`tut2_extract` 正文「接下来是随机的一局」改成「还有最后一张：祭坛」 | `chapters/chapter_01.json`、`events/tut2_extract.json` |
| 地图 `tutorial3.json`（第二节 9 点；搜索点固定出货 `search_finds`；休息点 `content.event` 指教程版事件） | `data/maps/` |
| 事件 `tut3_*` 11 条 | `data/authoring/events/` |
| 两件骨制小物（`bone_dice` 骨骰子、`bone_charm_bits` 碎骨串，1 格，`bone` + `material`，无规则，`value` 写死保证献祭点数够） | `data/authoring/items/` |
| 规则卡过 `render`（112 已列） | — |

### 4.5 测试（`tests/run/test_prologue3.gd`，照 `test_tutorial2.gd` 的写法）

脚本跑完整张图：拿护符 → 放包 → 激活蛮神且 HUD 行出现；不放包时战斗 1 的真选项隐藏、提示在；打完信力 > 0；搜索三件到手；神坛 A 献祭两件后 tier ≥ 1、神坛关；拿日神护符放包 → 激活日神、蛮神池子点数不变；右键切回；战斗 2 后 tier ≥ 2（**数值断言**，不够就调 `value`）；神坛 B 两个特殊操作都列出、做一个后另一个与献祭都不可用；撤离给 `prologue3_done`；`new_run_target` 教程顺序 1 → 2 → 3；`chapter_01` 要 `prologue3_done`。

## 五、对照作者的清单

| 作者要教的 | 在哪 |
|---|---|
| 遇到信仰事件 | 点 1、点 5 |
| 通过信物激活信仰 | 点 1 + 战斗 1 门禁 |
| 信力系统 | 战斗 1 正文 + HUD；神坛 A 看阶变 |
| 神坛的献祭系统 | 点 4 |
| 特殊行为系统 | 点 7（两种可选，二选一） |
| 如何切换信仰 | 点 5（放下另一枚 / 右键），战斗 2 门禁逼一次切回 |
| 休眠（顺带） | 点 3 胫骨大棒、点 5 变灰 |
| 赐福（顺带） | 点 7「祈求赐福」 |

112 第四节里其余的欠缺（耐力、邻接格、商店、保险箱、倒计时、基地、回放操作）**不进序章**：作者定只做三张，这些交给第一章的规则卡与首次出现时的一次性提示（另立小方案，或直接当小修）。

## 六、改动范围（两到三天）

| 批 | 文件 |
|---|---|
| ① 机制 | `core/text/text_template.gd`（信仰占位符）、`core/run/events/conditions/faith_active.gd`（`faith`）、`core/run/events/event_option.gd` + `ui/game/event_screen.gd`（`hint_when_hidden`）、`docs/text-placeholders.md` |
| ② 内容 | 章节、地图、11 条事件、2 件骨制小物、`chapter_01` 解锁、`tut2_extract` 一句、规则卡 |
| ③ 测试 | `tests/run/test_prologue3.gd`；`test_game_flow` 的教程顺序断言加第三张 |

## 待作者定（不挡执行，按推荐先做）

1. 第二位神用日神（推荐：护符现成、和蛮神反差大）还是自然 / 大地？
2. 门禁反向提示用 `hint_when_hidden` 字段（推荐）还是双选项？
3. 骨制小物是新道具（推荐，2 件、无战斗属性）还是复用现有物件改标签？
4. 序章三要不要给玩家输一场的机会教「失去体力也给信力」：推荐不强求，正文说一句即可。
