# 261 图鉴页改书架：图鉴 / 对局记录 / 特殊道具 / 成就各占一格，对局记录留 20 场可收藏（架构方案）

作者 2026-10-27 14:13：「将图鉴页面改成多行多区域的书架，一个区域点开是图鉴，另一个点开是对局记录。对局记录保留最后20场，可以收藏（收藏后不删除，占20场的位置之一），对局记录点开后可以看到详细信息，调试模式下包括地图种子」。

线框：https://claude.ai/artifact/JbS7sZ2cCvjuAkirC55UFg ；文件 /mnt/project-files/architecture/261-bookshelf.html。作者的话都是明示，待定按推荐直接派执行；线框给作者与 UI替换美术看位置尺寸。

## 一、现状

- 图鉴页（`meta_screen.gd` `_build_codex`）：中列吃满（`NO_SHELF_TABS`，1600 宽时约 1308 × 952），一个滚动网格列全部道具（`CodexTile` 96 × 112，稀有度排序），下面「特殊道具」一段；成就是另一页签。
- 对局记录：`MetaState.history`（最近 20 局 `RunResult.to_dict()`：outcome / reason / seed / chapter / steps / visited / battles_won / battles_lost / balance / value / items / safe / safe_value），**只在调试台抽屉里**列成几行文字（`meta_screen.gd:386`），玩家看不到；没有收藏、没有时间、没有角色与难度（260 已让执行把 `character_id / difficulty_id / ended_at` 加进 `to_dict`）。

## 二、书架（页签「图鉴」改名「书架」）

整页一座木书架，1308 × 952，**两层、每层三格**（格 400 × 400，格间 24，左右边 30）：

| 格 | 物件（点开什么） | 格里画什么 |
|---|---|---|
| 上左 | **图鉴** → 现在的图鉴网格（整块搬进窗） | 一摞厚册子，书脊写「图鉴」，旁边小牌「40 / 153」 |
| 上中 | **对局记录** → 记录列表窗 | 一捆卷轴插在陶罐里，小牌「20 场」 |
| 上右 | **特殊道具** → 现在图鉴页底下那一段（拿到过的点亮） | 一只小木匣 |
| 下左 | **成就** → 现在的成就页（整块搬进窗，页签删掉） | 一排小徽章挂在格里，小牌「完成 N / N」 |
| 下中、下右 | 空格 | 摆几件静物（油灯、墨水瓶），以后加东西的位置 |

每格是一个大按钮（整格可点，悬停微亮，226 的无裸字：格名与数字都在小牌上）。点开 = `OverlayFrame` 窗（stone 皮，1100 × 820，右上角关），窗里内容各自照旧。左列页签：仓库 / 出售 / 集市 / 铁匠铺 / 科技 / **书架**（图鉴、成就两个页签并成一个；`TAB_ICON_ART` 换一张书架剪影）。

## 三、对局记录

### 3.1 存

- `history` 每条加 `pinned: bool`、`run_no`（当时的 `runs`）、`ended_at`、`character / difficulty`（260 已加）。
- 进账（`absorb`）：新的一局 `push_front`；超过 20 条时**从尾部删最旧的未收藏那条**；收藏上限 19 —— 第 20 枚收藏按不下去（小牌「收藏已满」），这样永远有一个位置给最新一局。
- 老存档的条目缺 `pinned` 当 false，缺 `ended_at` 显示「——」。

### 3.2 列表窗（1100 × 820）

标题牌「对局记录」+ 右侧「N / 20　收藏 M / 19」。石账行（226 ledger rows），一行一局，从新到旧：

`★ | 第 7 局 | 10-27 13:05 | 魔法废墟 · 中型 · 普通 | 马库斯 | 撤离 | 值 3168 · 带出 357 | 28 步`

- 星 = 收藏开关（点一下切换，收藏的行星亮、排序不变 —— 按时间）。
- 结局：撤离 绿字 / 战败 红字（沿调试台那两色）；战败写原因（体力耗尽 / 核心失利）。
- 点行 → 详情窗。

### 3.3 详情窗（同尺寸，左上「← 记录」回列表）

碑额一行：第 N 局 · 日期时间 · 结局大字。下面两列石账：

| 左列 | 右列 |
|---|---|
| 章节 · 规模 · 难度 | 带出：N 件、值 X 币、金币 Y |
| 角色 | 保险箱：N 件、值 X |
| 步数 / 到过几个点 | 战斗：赢 A · 输 B · 精英 C · 核心 D |
| 搜索 N 次 · 制作 N 次 | 信仰：主神与到达的信力（`faith_history` 末值） |

带出的道具列一排缩略图（`CodexTile` 的小版，`items` 是 id 列表，画 def 图）。**调试模式**（`DevGate.on()` 且 `settings.debug_mode`）多一行：`种子 123456 · 地图 ring/medium/6 环`，旁边「复制」键（`DisplayServer.clipboard_set`）。

## 四、改动清单（给执行）

1. `core/meta/meta_state.gd`：`history` 条目 `pinned / run_no`；`absorb` 的裁剪规则改「删最旧的未收藏」；`pin_run(index, on) -> bool`（上限 19）；存读往返；`SAVE_VERSION` 不升。
2. `ui/game/meta_screen.gd`：`_build_codex` 改成书架页 `_build_shelf`（六格按钮，前四格各开一窗）；图鉴网格、特殊道具段、成就页搬进各自的窗（`OverlayFrame` stone，1100 × 820）；`TABS` 去掉 achievements，codex 改名 `meta.tab_shelf`「书架」；`NO_SHELF_TABS` 同步。
3. 新 `ui/game/run_records_window.gd`（列表 + 详情两页，同一窗内切换）；行用 226 的 ledger rows，星用 `TipButton` 或小石片。
4. `UiText` 新键：`shelf.codex / shelf.records / shelf.keepsakes / shelf.achievements / shelf.count_runs / records.title / records.pinned_full / records.col_* / records.outcome_* / records.detail_* / records.seed / records.copy_seed`，中英。
5. 美术（UI替换美术）：书架（两层六格，木架 + 背板）、格里的四件物件 + 两组静物、小牌；没图前执行用 `home/shelf.png` 九宫 + 现成木牌占位，物件位画现有图标（图鉴 / 成就页签的剪影放大）。
6. 测试 `test_run_records_261`：裁剪规则（21 条、全收藏 19 + 2 未收藏 → 删最旧未收藏；收藏第 20 枚被拒）；存读往返；详情窗在非调试下没有「种子」字样、调试下有；书架六格都在 1308 × 952 内；无裸字测试过；`test_meta_screen` 里页签断言改（无 achievements、codex → shelf）。

## 五、待定（默认按推荐）

1. 成就并进书架、页签删掉（推荐）；备选 成就留页签，下左格也放静物。
2. 收藏上限 19（推荐，永远留一个位置给最新一局）；备选 20（满了新局不入账，不推荐）。
3. 列表按时间排、收藏只亮星（推荐）；备选 收藏的排最前。
4. 窗 1100 × 820（推荐）；备选 整页切换不开窗。
5. 种子行只在调试模式（推荐，作者原话）；备选 永远显示。

## 六、测试

见 §四 6。
