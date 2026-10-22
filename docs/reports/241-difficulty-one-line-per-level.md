# 241 难度拆级：每级一行字（2026-10-22）

作者 14:03（游戏反馈小修线，附开局屏难度纸卷截图）：「检查一下文本，试着将每级难度的内容拆解成只有一行字可以描述的内容」。小修已在那边发了决定卡（推荐拆成三级），本篇把拆法、解锁链、数值落到可派的程度；待定按推荐。

## 〇 一句话

**进阶一现在把三样东西（体力上限 −1、侵蚀、猎手）塞在一级、一句 36 字的话里，纸卷一行只装得下十个字。拆成三级，每级只管一样、只写一行：Ⅰ「体力上限少一点」、Ⅱ「越深侵蚀越重」、Ⅲ「猎手循迹追来」；Ⅰ 照旧由「满载而归」解锁，Ⅱ、Ⅲ 各由上一级撤离一次解锁。数值一个不改。**

## 一、现状（v4.18）

- 难度只有 `normal` 和 `ascension_1`（`data/authoring/difficulties/`）。进阶一 `level 1`，`requires_unlock ascension_1`（成就「满载而归」`big_haul` 发），一个 json 里三样：`effects` 体力上限 −1；`mechanics.erosion`（每层深度扣体力 1、第二层起 25 % 概率损坏道具、扣钱关着）；`mechanics.hunters`（追猎者 `hunter_1`，段位表 [0, 5, 10, 20]）。
- 纸卷（180 补三 `ChallengeScroll`）：纸宽 264，数字列 48 + 点 14 + 内边距 28，正文一行 **174 px ≈ 十个 16 号汉字**；每级一行「Ⅰ. 文字」，自动换行，所以现在那句 36 字折成四行。一局只挂**一个** `DifficultyDef`（`RunState.difficulty`），纸上列的是「所有 ≤ 当前级」的行（`SetupScreen.challenge_lines`），机制只来自选中的那一个 —— 级与级之间**不**自动叠加。
- 127 搜索保底按 `difficulty.level` 取行，表有四行（0–3），超出取末行再 +1，三级够用。

## 二、拆法（推荐甲）

| | 做法 | 评 |
|---|---|---|
| **甲 拆三级，每级一样（推荐）** | Ⅰ 体力上限 −1；Ⅱ = Ⅰ + 侵蚀；Ⅲ = Ⅱ + 猎手。三个 json，各自带齐到自己这一级的全部机制（一局只挂一个 def，所以数据要写全），`challenge` 只写**自己这一级新增的那一行** | 一级一行一样东西，纸上三行各说各的；玩家能一级一级试；数值不动 |
| 乙 只缩短文字 | 进阶一还是三样，`challenge` 改成「体力少、侵蚀重、有猎手」一行 | 一行塞三样还是看不懂每样是什么，而且以后加第二级还得再拆 |

### 每级一行（中 ≤ 十字，英 ≤ 二十字母，都不折行）

| 级 | id | 一行（zh） | 一行（en） | 新增 | 解锁 |
|---|---|---|---|---|---|
| Ⅰ | `ascension_1`（不改 id，旧存档的「进阶一」还认） | 体力上限少一点 | Less max Vitality | `vitality_max_bonus −1` | 成就「满载而归」（照旧） |
| Ⅱ | `ascension_2` | 越深侵蚀越重 | Erosion grows deeper | + `erosion`（原数） | 在 Ⅰ 撤离一次 |
| Ⅲ | `ascension_3` | 猎手循迹追来 | Hunters track you | + `hunters`（追猎者，段位表原数） | 在 Ⅱ 撤离一次 |

`display_name` 进阶一 / 二 / 三（Ascension I / II / III）；`description`（百科 / 调试用的长句）各写全自己含的所有机制。顺序从轻到重：少一点体力只是开局紧一点；侵蚀是持续压力；猎手是会追上来打你的那种。

### 解锁链

照章节的样子给 `DifficultyDef` 加 `grants_unlock`：**在这一级成功撤离**（`GameFlow.extract` 里 `run.chapter.grants_unlock` 旁边那一行）就 `meta.grant_unlock`。Ⅰ 发 `ascension_2`，Ⅱ 发 `ascension_3`。不新加成就种类（`AchievementDef.KINDS` 里没有「在某难度撤离」，为这个加一种不值）；「满载而归」照旧发 `ascension_1`。

### 不改

- 数值：体力 −1、侵蚀三条、段位表、搜索保底行，一个不动。
- 纸卷、难度块、翻页计数器：一行字短了就自然一行，代码不动。
- 旧存档：局外的 `ascension_1` 解锁照旧有效；**局中存档**若挂着旧的进阶一，读回来按新 Ⅰ 算（少了侵蚀与猎手），开发期可接受，不做迁移。

## 三、改动范围

- `data/authoring/difficulties/ascension_1.json` 改、`ascension_2.json` / `ascension_3.json` 新增（`level` 1 / 2 / 3，中英 `challenge` 与 `description`）；`bash tools/snapshot_content.sh`。
- `core/run/difficulty_def.gd` + `grants_unlock`（导入器认字段）；`core/run/game_flow.gd` `extract()` 撤离成功时发它。
- 测试：`test_setup_180` 的梯子断言按三级走一遍（解锁三级后 「＋」加到 Ⅲ 停；纸上三行各一行高 `ROW_MIN_H`）；新 `test_difficulty_ladder_241`：Ⅰ 撤离 → `ascension_2` 解锁、Ⅱ 撤离 → `ascension_3`；`run_v4` 夹具的 `ascension_1` 照旧读得出。
- 百科「难度」页若写了进阶一的三样，改成三级各一行。

## 四、派工

执行一单。小修线的决定卡若作者改选「只缩短文字」（乙），这单撤回，小修自己改一句话即可。
