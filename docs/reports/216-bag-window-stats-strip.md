# 216 背包窗去字、收起换圆钮、底部数值栏（耐力 / DPS / 负重）—— 火漆签

作者 2026-10-20 12:38（美术设计线程）：「去掉顶部的文字，【收起】需要替换成 UI，下面关于耐力的消耗、dps 估算以及被删掉的负重，都要通过一种美术设计的排版显示（并且也显示在战利品、搜索界面的右边棋盘下方）」；14:44 从四种排版里选定 **丁 火漆签**；14:46 在架构设计：「已经决定了，等你」。排版规则与草稿：`/mnt/project-files/art/ui/stats_strip/README.md`（美术设计），精修图由 UI替换美术 出，交执行时换上。本篇是框架：数据从哪来、放哪、没图时怎么画。

## 1 现状

| 处 | 现在 |
|---|---|
| 背包浮窗 `FloatingWindow.setup("bag", "背包", toggle_bag, "收起（B）")`（地图屏 / 事件屏 / 休息屏三处） | 标题「背包」+ 11 号「按住标题拖动」+ 文字按钮「收起（B）」 |
| `InventoryPanel._build` | 棋盘下面两行字：`_stamina`「耐力消耗：中（每秒 5.0，回 6.0）　停上去看细节」（停上去 `StaminaEstimate.describe`）、`_weight`（`run.encumbrance_line()`，这一章不算负重就隐藏；超重整行变色） |
| 容器 / 搜索屏 `ContainerScreen` | `_inv.hide_stamina()`，没有 DPS；玩家棋盘位置按 `assets/ui/board/layout.json` 的设计像素摆，左边「全部拾取」是火漆签，右上圆钮 `btn_minimize` |
| DPS | 只在战前准备（`spec.rough_dps()`「约 x DPS」）与沙盒里有，背包窗没有 |

## 2 方案

### 2.1 新控件 `StatsStrip`（`ui/widgets/stats_strip.gd`）
- 三块签从左到右：**耐力 / DPS / 负重**，每块 = 火漆 + 大字 + 小字；宽度跟棋盘（`set_width(px)`，草稿 470），高约 34（以 UI 精修图为准）。
- 数据一个入口 `refresh(spec: CombatantSpec, run: RunState)`：
  - 耐力：大字 `StaminaEstimate.of(spec)["rating"]`（低 / 中 / 高 / 极高），小字「耗 x · 回 y」（每秒，一位小数）；档位色：低 `UiPalette.HEAL`、中墨、高 `STAMINA`、极高 `HP`。
  - DPS：大字 `spec.rough_dps()`（一位小数），小字「DPS」。和战前屏同一个数。
  - 负重：大字「当前 / 上限」，小字 `EncumbranceRules.name_of(level)`（轻装 / 吃力 / 超重…）；吃力 `STAMINA`、超重 `HP`。`run.encumbrance_line() == ""`（这一章不算负重）→ 这块不显示，另两块居中。
  - 三块各自停上去开 `HoverTip`：耐力沿用 `StaminaEstimate.describe(spec)`；DPS 列出手件与各自的 dps（`spec.active_items()`）；负重沿用 `encumbrance.effect_text(lv)`。
- 画法：签底 `UiTheme.art_cached("stats_strip/tag")` 九宫格、火漆 `stats_strip/seal_<stamina|damage|weight>`，图标 `耐力` = 效果图标「耐力回复」、DPS = 剑、负重 = `assets/ui/setup/icons/weight.png`；**没图时**画浅纸圆角矩形 + 左头一枚实心圆（橙 / 红 / 铁灰）+ 字，功能先通，UI 精修图到了只换 png 与 json（`inset`、字位）。tone light（浅纸墨字），注册进 `UiTheme` 的 art 表。
- 播报：每块文字变化不出声；数值栏不是按钮。

### 2.2 背包浮窗（三处共用 `FloatingWindow`）
- `setup()` 加参数 `chrome: StringName = &"text"`；背包传 `&"bare"`：**不放标题字、不放「按住标题拖动」**，标题行留着当拖动把手（高度同现在，画一条拉通的分隔线）；右上角换成 `IconButton.make_art("board", "btn_minimize", "－", "收起（B）", on_close)` 按 0.72 画（约 40 px），和战利品屏同一枚；热键 B 照旧由各屏管。其他浮窗（如果有）不变。
- `InventoryPanel._build`：去掉 `_stamina` / `_weight` 两个 Label，棋盘下面放 `StatsStrip`，`_refresh_readout` 改调 `strip.refresh(spec, run)`；`hide_stamina()` 删掉（容器屏现在要显示整条，见 2.3）。

### 2.3 容器 / 搜索屏
- 右边玩家棋盘下面放同一个 `StatsStrip`，和左边「全部拾取」**同一高度**；`_layout` 里按 `layout.json` 新键 `stats_strip`（设计像素 y 与宽，UI 精修时给；没键就贴在棋盘底下 +12）；面板加高约 34。
- 尸体 / 待拾取容器（只有「全部拾取」与最小化的那种）同样显示。

### 2.4 旧字
- 「耐力消耗：…　停上去看细节」「按住标题拖动」两句玩家文案删掉（`UiText` 里若有键一并删）；`notice` 不动。

## 3 待定（按推荐）

| # | 问题 | 推荐 |
|---|---|---|
| 3.1 | DPS 的悬浮窗列不列每件 | **列**（战前屏没有，这里补上最省事） |
| 3.2 | 不算负重的章 | **隐藏那块、另两块居中**（美术草稿同） |
| 3.3 | 数值栏点一下有没有动作 | **没有**（纯读数） |
| 3.4 | 没精修图时要不要先合 | **先合**（占位画法能用；精修图到了只换资源） |

## 4 测试
- `test_stats_strip_216`：`refresh` 后三块文字对（耐力档、DPS 与 `rough_dps` 一致、负重「当前 / 上限」）；不算负重的章第三块隐藏；文字里不含「停上去」「按住」。
- 背包浮窗：`bare` 模式树里没有标题 Label 与提示 Label，右上是 `IconButton`；B 键仍收起。
- 容器屏：玩家棋盘下有 `StatsStrip`，y 与「全部拾取」签同一行（±2 px）。

## 5 不做
- 排版本身（美术 + UI 线程定）；战前准备屏的读数行不动。

## 6 落地（v3.57，2026-10-20）

按 3.1～3.4 推荐落地（没有精修图先合，占位画）。和方案的差别：

1. **签宽固定，棋盘窄时整条按签宽**。精修稿的签底不拉伸（152 × 3 + 间距 = 480）；地图屏开局的棋盘只有六七列，比三张签窄，数值栏就按签宽，背包窗跟着撑宽一点，签不出框。
2. **字位、尺寸、配色先照精修稿 `layout.json` 的默认值写进代码**（`StatsStrip.DEFAULTS`），交图时 `assets/ui/stats_strip/layout.json` 一到就按它；档位色 json 里没给就按调色板压成纸上看得清的墨色。
3. **容器屏的数值栏摘出背包面板**（`InventoryPanel.detach_strip`），按「全部拾取」看得见那块的中线摆，上沿至少离棋盘格子 22（`layout.json` 的 `stats_strip.gap` 可改）；8 列背包 + 6 列容器的面板 526 → 556（+30）。
4. **背包窗的标题行**空着当把手，下面一条 `HSeparator` 当拉通的分隔线；别处用 `FloatingWindow` 的浮窗（编辑器规则窗）照旧 text 样式。
5. 精修图（UI替换美术 `art/ui/stats_strip/out/`）还没交：交来时拷 `tag.png`、`seal_stamina / dps / load.png`（+ `@2x`）和 `layout.json` 到 `assets/ui/stats_strip/` 即可，不改代码。

## 7 补充：精修图与背包窗一格 72（v3.59，2026-10-20）

UI替换美术交图（`art/ui/stats_strip/out/`），作者 2026-10-20 15:27 选乙（一格 72）：

1. **签底、三枚火漆、`layout.json`** 拷进 `assets/ui/stats_strip/`，`StatsStrip` 不改代码就换上精修图与配色。`@2x` 没拷：UI 切图只读 1x（棋盘美术那批同样没拷）。
2. **背包浮窗换成定尺寸的 `BagWindow`**（`ui/game/bag_window.gd`，继承 `FloatingWindow`），全按 `layout.json` 的 `bag_window` 摆（窗左上起的设计像素）：
   - 8×6 棋盘时窗 660×620，首次打开在精修稿的窗中心 (800, 510)；
   - 标题行 52 不写字、整行当把手，下面一条 1.2 px `#786e64` 分隔线，左右各缩 26；
   - 右上圆钮在 (594, 13)，按 0.72 画，停上去写「收起（B）」；
   - 棋盘格子左上在 (42, 82)，一格 72；道具图格子大于 60 就取 `@2x`，原有逻辑不用改；
   - 皮带外框 `frame_player_72.png` 九宫格，边距 54，比格子外扩 24；格缝按棋盘美术 `cell_seams`；
   - 数值栏在棋盘下 22，和棋盘一样宽，签在里面居中（8 列时等于精修稿的 +48）。
   地图、事件、休息三屏都改用它。`FloatingWindow` 去掉 216 加的 `bare` 样式，只剩带字的那种（编辑器规则窗用），把手改由 `_grip` 设，另加 `center_shift`。
3. **和精修稿的差别**：
   - 棋盘不是 8×6 时（开局角色 9 列，包也会撑大棋盘），窗按多出的格数 × 72 往右、往下长，左、右、下边距不变；圆钮跟着右移。
   - 顺手修了一个老毛病：`SlabStyle` 的板身、板边、`body_inset` 原来没有 `@export`，`UiTheme.panel(p, 边距, 石板变体)` 复制样式时两层贴图都丢了，窗会变成透明的。现在三项都导出，背包窗直接用内边距 0 的石板。
4. `InventoryPanel.cell_px` 在 `setup` 之前设，默认 60。别处（战前屏、容器屏）都不变。

## 8 补充：负重签总在（v3.61，2026-10-20）

作者 2026-10-20 16:20 看了 #223 的截图：「负重在吗？我怎么看最后的截图没有负重啊，没有的话要加上」。原因是截图那一章不算负重，按 3.2 负重签藏起来了。现在 3.2 作废，三张签总在。只改显示，负重规则不动：

| 这一章 | 大字 | 小字 | 悬浮窗 |
|---|---|---|---|
| 算负重 | 当前 / 上限 | 档名（配色同前） | 原来那行 + 档的效果 |
| 不算负重，有上限 | 当前 / 上限 | 空着 | 「负重 当前 / 上限」+「这一章不算负重」 |
| 没有上限（没角色、角色没配） | 只写当前重量 | 空着 | 同上 |

`refresh` 的 `run` 为 null 时（没有这一局）仍只排两张。

