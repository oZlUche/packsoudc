# 260 基地「战绩」改军功栏：最佳成绩与军功牌（架构方案）

作者 2026-10-27 13:13（附截图：基地家页顶端那块羊皮纸，「4 局　撤离 4　战败 0　累计总分 5414　单局最高 3168 / 钱 357　图鉴 40 / 153」）：「重新设计一下这里的排版并在后面加入美术要素，以一种军功栏之类的方式显示，用于展示玩家的最佳成绩」。

线框（平板、只定位置尺寸、每块标注它将来是什么古物）：https://claude.ai/artifact/EnyTizAa5BNZ8oRZtpdZQc ；文件 /mnt/project-files/architecture/260-records-board.html。

## 一、现状

- 位置：基地（`MetaScreen`）中列「家」页，`PANEL_HOME_BOX` 粗布框里一行 `meta.stats` 文字（`meta_screen.gd:187`），宽 460、字号 15；刚打完一局时上面多一行 `meta.just_run`。中列宽约 508（1600 宽时：左列 220 + 边距 24 × 2 + 列间 24 × 2 + 右半边 776），高约 950，**家页除了这两行什么都没有**。
- 数据（`MetaState`）：`runs / extractions / deaths / score（累计总分）/ best_value（单局最高价值）/ funds / codex（点亮数）/ boss_kills / battles_won / history（最近 20 局的 RunResult 字典）`。
- 违反现行规矩的地方：「钱 357」是文字（作者 10-24 14:49：钱 = 金币图标 + 数字，不写「钱」）；两行散文挤在一块纸上，没有层次；「最佳」只有一个数，不知道是哪一局、哪张图。

## 二、内容：军功栏上放什么

| 块 | 内容 | 来源 | 备注 |
|---|---|---|---|
| 最佳一局（主位） | 单局价值 **3168**；那一局的章节、结局（撤离 / 战败保险箱）、走了几步、赢了几场、角色 | `best_value` + 新增 `MetaState.best_run: Dictionary`（`absorb` 里 `value > best_value` 时记下 `RunResult.to_dict()` 的摘要） | `RunResult` 现在没记角色与难度，`to_dict` 加 `character_id / difficulty_id / ended_at`（history 是字典，加字段不升版）。老存档没有 `best_run` 就只显示数字 |
| 军功牌 × 4 | 撤离 N 次 / 击败核心 N 次 / 打赢 N 场 / 战败 N 次 | `extractions / boss_kills / battles_won / deaths` | 每枚按次数分阶（铜 / 银 / 金 / 鎏金 / 桂冠，沿 256 军功牌那五阶），阈值在数据里：撤离 1 / 5 / 15 / 30 / 60，核心 1 / 3 / 8 / 15 / 25，打赢 5 / 20 / 50 / 100 / 200；战败那枚不分阶、只记数（它不是功）。悬停浮窗：下一阶还差几次 |
| 累计账 | 局数 / 累计总分 / 图鉴 40 / 153 / 金币（图标）357 | `runs / score / codex.size() / funds` | 226 那种石账行，金币用 `CoinLabel` |
| 刚才这一局 | 现有 `meta.just_run` 那句 | `payload.result` | 只在刚打完一局进来时出现，放最上面的蜡板上 |

成就（`achievements` 页）不动：成就是「做到过什么」，军功栏是「做到多好」。

## 三、两版排法（A 推荐）

### A「军功架」—— 挂在墙上的木架，像军团的勋章架

从上到下（中列 508 宽，内边距 16）：标题木牌「战绩」56 高 → 蜡板「刚才这一局」60 高（没有就不占位）→ **青铜匾「最佳一局」150 高**（左侧桂冠 96 × 96，右侧大数 3168 + 两行小字：章节 · 结局 · 角色 / 第几局 · 几步 · 赢几场）→ **军功牌 2 × 2**（每格 240 × 140：圆牌 96 居左、右边大数 + 名目，牌面按阶换色）→ 石账四行（每行 40，左名目右数字，金币行用 CoinLabel）。总高约 760，剩下的留白给以后的东西（勋章多了就第三行）。

优点：都是现成的件 —— 木牌 = 226 header_stone 类、匾 = 256 军功牌同族、账行 = 226 ledger rows；矩形为主、好排版。

### B「军功碑」—— 一座石碑，非矩形（作者 10-21：多试非矩形）

碑身 440 宽居中、碑顶山墙 +70 嵌桂冠、碑座比碑身每边宽 20（沿 233 神坛青石碑的拆法：body 九宫 + 顶 + 座，内容区仍是矩形）。碑文从上到下：**最佳一局**刻在碑额（大数 + 两行小字）→ 四枚圆牌竖排在左、名目与数字在右（像一道履历铭文）→ 碑脚一行小字是累计账（局数 · 总分 · 图鉴 · 金币）。刚才这一局用一块蜡板**挂在碑旁**（碑太窄，不进碑文）。

优点：一眼是军功碑，非矩形；缺点：碑身窄，四行账挤在碑脚，数字多了得缩字。

两版的数据与分阶一样，只是容器不同；作者挑定后 美术设计 出样（木架 / 青铜匾 / 五阶圆牌 / 石碑）给作者看，执行先用 `UiTheme` 现成的面板占位落地。

## 四、改动清单（给执行，作者挑定后）

1. `core/run/run_result.gd`：`character_id / difficulty_id / ended_at` 三个字段进 `to_dict / from_dict`。`core/meta/meta_state.gd`：`best_run: Dictionary` + `absorb` 更新 + 存读；`SAVE_VERSION` 不升（缺省空字典）。
2. 新部件 `ui/game/records_board.gd`（`RecordsBoard`）：吃 `MetaState` + `ItemDb` 总数，按 A 或 B 排；军功牌 `MedalPlate`（圆牌 + 数 + 名目 + 阶色，悬停浮窗「下一阶还差 N」）；分阶阈值在 `data/authoring/meta_rules/standard.json` 新键 `medal_tiers`。
3. `meta_screen.gd` 家页：`meta.stats` 那一行删掉，换 `RecordsBoard`；`meta.just_run` 搬到蜡板。`UiText` 新键：`records.title / records.best / records.medal_extract / records.medal_core / records.medal_wins / records.medal_deaths / records.next_tier / records.runs / records.score / records.codex`，中英。
4. 美术：四枚五阶圆牌归 美术设计（道具类）；木架 / 标题木牌 / 青铜匾 / 蜡板，或 B 的碑顶 / 碑身 / 碑座这些面板件归 UI替换美术（作者 13:00 起 UI 类活归它）；`layout.json` 写突出部分（B 的山墙 / 碑座）；没图前用 `PANEL_HOME_BOX` + 256 的 `legion_phalera@sN` 占位。
5. 测试：`test_records_board_260`：空档（全 0）、满档（大数）两种都在 508 × 952 内；三档字号（258）都放得下，放不下的数字 `TextFit`；无裸字测试（226）过；`best_run` 存读往返；分阶阈值从数据读。

## 五、待定（默认按推荐）

1. A 军功架（推荐）；B 军功碑。
2. 分阶阈值如上（推荐）；备选 全部按 256 的 0 / 3 / 8 / 15 / 25。
3. 战败牌不分阶（推荐）；备选 也分阶（「百战」的意思）。
4. 最佳一局的「最佳」= 单局价值（现有 `best_value`，推荐）；备选 单局总分（价值 + 保险箱）。
5. 成就页不动（推荐）；备选 把成就徽章也挂进军功架第三行。

## 六、测试

见 §四 5。

## 七、作者定稿（2026-10-27 14:13）

作者：「尝试军功碑方案，最后对局不再显示」。定 **B 军功碑**；蜡板（刚才这一局）整块删掉，`meta.just_run` 不再出现。其余待定按推荐。14:16 派执行（排在 259 之后）；圆牌样稿派 美术设计，碑顶 / 碑身 / 碑座样稿派 UI替换美术。同一条消息里的「图鉴页改书架 + 对局记录」另立 261。
