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
