# 188 · 方案：背包界面四段文字删掉；信仰悬浮窗重排、定字色

> 作者 2026-10-17 17:29（四张截图）：「前四张截图的文本都删掉。信仰说明的悬浮窗需要重新排版和设计字体颜色」。四张截图依次是：① 操作提示两行（「左键拖动　双击快速置入　R 旋转……」「地上（不限件数）　不参战……」）；② 棋盘读数「参战 22 件（8 件会出手）　可用格 48（空 12）」；③ 「停上去看效果与信力怎么涨」；④ 「信仰：狩猎之神　狩猎之神 Lv.0　5 / 25」。
>
> 已转「架构方案执行」。样张（平面、真实尺寸）：https://claude.ai/artifact/JynVpkzKYwdJVqqyFwFiFW

## 1. 删四段文字（`ui/game/inventory_panel.gd`）

| # | 在哪 | 做法 |
|---|---|---|
| ① | `:81` `_hint`（操作提示）与 `:84` 地上那行 | 两个标签都不造。`_hint` 还被 `_on_displaced()`（`:220`）借来写「顶出来了 N 件」这类回话：改走 186 的提示行（`screen.say()`，没有地图屏的宿主就不说）。 |
| ② | `:67` `_readout`、`:213-216` | 不造。它里面的「套装：hunter_set 2/3」（内部文字清单二、17）一并消失；生命 / 预估 DPS 玩家在战前准备与名牌上看。 |
| ③ | `:212` 的后缀「停上去看效果与信力怎么涨」 | 随 ④ 一起删。 |
| ④ | `:58-66` `_faith_label` 整行 | 不造。信仰在顶端栏的徽记件（`ui/hud/widgets/faith_widget.gd`，32 px 徽记 + 「Lv.0　5 / 25」）上已经有同一个悬浮窗。背包叠层开着时顶端栏仍露着（叠层在栏下面），所以不另放悬浮目标；若美术改版后栏被盖住，再在背包面板左上放一枚 32 px 徽记当悬浮目标（待定 1）。 |

左列剩下：耐力消耗行（有自己的悬浮窗）、负重行。`_refresh_readout()` 里 ②③④ 相关的拼字删掉；`FaithState.dormant_uids` 的「N 件休眠」提示进信仰悬浮窗（§2 名字行右侧）。

## 2. 信仰悬浮窗（`core/run/faith/faith_tooltip.gd`）

### 2.1 现状

`FaithTooltip.describe()` 一口气写十几行：名字 + 神的括号注（「暴力与杀戮：力 / 冲撞」是设计注）、背景故事、「信力怎么涨：…」、「阈值：30、100、200、400　现在 45 点、第 1 阶，再 55 点到下一阶」、「献祭品（神坛）：带「bone」的道具 ×5；…」（原始标签）、「各级效果：」逐阶、「这个信仰的道具：」整张清单、末尾一段机制说明（内部文字清单二、10）。颜色是写死的十六进制（`#f0ad4e` 小标题、`#5cb85c` 已到阶、`#8b93a1` 灰），不走 169 的深浅模板；没有信仰时还写一段教学句。

### 2.2 新版式（宽 360，与道具窗同一套：名字行 / 分隔线 / 正文 / 虚线分节）

```
蛮神                              Lv.1     ← 19 号粗体，信仰色（faith）描边；等级 13 号 tip_meta，数字 val
信力 45 / 100                              ← 14 号 tip_meta，数字 val
▮▮▮▮▮▯▯▯▯▯                                 ← 6 px 细进度条，到下一阶的比例，信仰色；满阶不画
─────────────────────────
Lv.1  祭坛可赐福武器                        ← 已到的阶：15 号 tip_fg；阶号 13 号 tip_meta
Lv.1  生命低于三成时伤害提高
Lv.2  祭坛可献祭生命换信力                  ← 没到的阶：整行 tip_desc（暗）
Lv.3  对精英一击必杀
Lv.4  不死
┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈
信力来源                                   ← 节名 13 号 tip_meta
造成伤害的 20%（每场至多 30）              ← deeds 各一行，数值 val
失去体力
┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈
献祭                                       ← 神坛的倍率，一行排开，标签用中文名（Glossary.tag_name）
骨 ×5　血肉 ×5　武器 ×2　占 9 格以上 ×10
```

- **不写**：神的括号注、背景故事、「阈值：…」串（阶号 + 进度条已经表达）、「这个信仰的道具」清单（每件道具自己的悬浮窗写它的信仰加成）、末尾机制说明。没有信仰时悬浮窗不开（顶端栏那格本来就是空槽）。
- 名字行右侧若有休眠道具：「N 件休眠」13 号 `warn` 色，放等级左边。
- 没有 `perks` 的信仰（狩猎、技巧、新教）跳过效果段，直接「信力来源」。
- 各行文字沿用现有 `perk.describe()` / `deed.describe()` / `offering.describe()`，但按内部文字清单二、12-13 改成玩家用语（原始标签 → `Glossary.tag_name`，公式 → 自然语言）；本篇不重写那些句子，只定版式与颜色。

### 2.3 颜色（都走 `text_colors.json`，深浅各一版）

| 什么 | 样式 |
|---|---|
| 神名 | `faith`（已有，dark `#c79bf2` / light `#5c3a8a`），描边（`UiTheme.outline`，170 同款） |
| 数值（等级、信力、倍率、百分比、上限） | `val`（185 新增） |
| 已到阶的效果、信力来源、献祭 | `tip_fg` |
| 没到阶的效果 | `tip_desc` |
| 阶号「Lv.n」、节名、信力行 | `tip_meta` |
| 「N 件休眠」 | `warn` |
| 进度条 | 槽 `#1a1512`，填充 `faith` |
| 原来写死的 `#f0ad4e` / `#5cb85c` / `#8b93a1` | 删除 |

进度条不是文字：`HoverTip.show_text()` 的 `extra` 参数现成（地图节点窗用它挂棋盘），信仰窗把一个 6 px 高的 `ProgressBar`（或自画 Control）当 `extra` 挂在名字行下面 —— 需要 `extra` 能插在正文中间而不是末尾：`show_text(bbcode, at, extra, terms, extra_after_head := true)`；或把进度条画成 BBCode 的 `[img]` 一条两色竖条（不如控件）。推荐控件（待定 2）。

## 3. 改动清单（给执行）

- `ui/game/inventory_panel.gd`：§1 四处；`_on_displaced` 改走 `screen.say()`（186 落地前先走 `_tip`？不，先什么都不说）。
- `core/run/faith/faith_tooltip.gd`：按 §2.2 重写 `describe(def, power, items)`：`items` 参数留着但不再列清单（调用点不动）；`head()` / `body()` 拆开给 `HoverTip` 的头 / 正文（170 的 `show_item` 分块版式，`set_item({"head","body"})` 现成，可直接复用）；返回 `{"head", "body", "progress": float}`。
- `ui/hud/widgets/faith_widget.gd:72`：改调 `tip.show_faith(FaithTooltip.describe_full(...))`（`HoverTip` 加 `show_faith(full)`：`set_item` + 名字行下挂进度条）。
- `data/authoring/ui/text_colors.json`：复用 `faith`、`val`、`warn`；不加新名。
- 字体：新字按 168 重裁。
- 测试：
  1. 背包叠层里找不到「左键拖动」「地上（不限件数）」「参战」「可用格」「停上去看」「信仰：」。
  2. `FaithTooltip.describe_full(brute, power@45)` 的 head 含「蛮神」「Lv.1」「45 / 100」，不含「阈值」「暴力与杀戮」「帝国」「这个信仰的道具」「休眠：只留通用效果」；body 的 Lv.2 行在 `[color=@tip_desc]` 里、Lv.1 行不在；`progress` ≈ 0.21（(45−30)/(100−30)）。
  3. 没有 perks 的狩猎之神：body 第一节是「信力来源」。
  4. 顶端栏徽记件悬停开窗，窗里有进度条控件；满阶（next_threshold < 0）不挂。
  5. BBCode 里没有写死的十六进制颜色（正则）。

## 4. 待定（默认按推荐）

1. **背包叠层里要不要留信仰悬浮目标** —— 推荐 **甲**：不留，用顶端栏徽记（叠层开着时栏露着）。乙：面板左上放 32 px 徽记。
2. **进度条做法** —— 推荐 **甲**：控件挂在名字行下（`show_faith`）。乙：BBCode 画一条（粗糙）。
3. **进度条的「到下一阶」比例** —— 推荐 **甲**：(p − 本阶阈值) / (下阶阈值 − 本阶阈值)。乙：p / 下阶阈值（刚升阶时条也接近满，误导）。

## 落地（2026-10-17，架构方案执行）

待定 1–3 都按推荐（甲）：背包里不留信仰悬浮目标（用顶端栏徽记）；进度条是控件，挂在名字行下；比例从本阶阈值算起。

- **背包面板**（`ui/game/inventory_panel.gd`）：操作提示、地上说明、参战 / 可用格读数、信仰行都不造；棋盘上面那行「作战棋盘　只有包里的东西参战　拖出棋盘 = 放在地上」是同一类玩法说明，也一起删了。剩棋盘、耐力消耗、负重。面板的回话（顶出来了、放不下、合成了、奉为主信仰）都走 `hint_sink`：地图屏接 `say()`（提示行），商店 / 容器 / 祭坛等照旧接自己的那行；没有宿主就不说（`last_hint` 留给测试）。
- **信仰窗**：`FaithTooltip.describe_full(def, power, board)` → `{head, sections, progress, text}`（没有信仰返回空字典，窗不开）；`describe()` 只返回连起来的文字。各段每行沿用 `perk.describe()` / `deed.describe()` / `offering.describe()`，数字过 `Glossary.val_numbers`。
- **`HoverTip.show_faith(full, at)`**：名字行（`set_status`）下插 `FaithBar`（6 px，槽 `#1a1512`、填 `UiPalette.FAITH`，满阶不挂），第一段进正文，后面每段前插一条虚线（`TipWindow.dashed`，与脚注虚线同款）；宽固定 360。换窗时 `_drop_extra` 一并摘掉。
- 顶端栏 `faith_widget` 改调 `show_faith`，休眠件数从 `run.board` 数。
- 献祭行沿用 `OfferingRule.describe()`（「骨制品（越稀有给得越多）」），没改成样张里的「骨 ×5」：倍率是内部系数，玩家用语那一版是作者 10-17 早些时候定的。

测试 `tests/ui/test_faith_tip_188.gd`；`test_author_087` 的信仰窗用例按新版式改写，`test_ground_landing` 读 `last_hint`。截图 `/mnt/project-files/screenshots/188/faith_tip.png`。

## 补充一（2026-10-18，作者看了落地版的反馈）

> 作者：「进度条做成分段式，一段代表一个等级，长度和需要的信力对应 / 一个等级的效果合并进一行 / 没激活的等级效果颜色要改成灰色 / 说明还要修改，以蛮神为例子：【祭坛可赐福武器】→【可以在祭坛赐福武器】　【生命值低于三成时伤害提高】→【生命值低于30%时，造成伤害提高X%】　祭坛可献祭生命换信力 → 可以在祭坛献祭生命上限换取能力　对精英一击必杀 → 可消耗信力或体力立即击败非首领敌人　不死 → 在战斗中，首次生命值归零时会持续战斗X秒 / 关于提到的X，让它和信力值挂钩，而不是固定，lv2的献祭生命上限，改成可以选择获得信力还是获得额外的全局增伤/加速buff / 另外，献祭要做成图标，【占9格以上】要替换成【大型道具】」
>
> 样张更新在同一个链接（下方第二排）。前三条是版式，后几条是蛮神四条效果的**机制改动**（X 随信力、二级可选、三级两种代价、非首领），要先改 `docs/gods.xlsx` 再生成 JSON（见 §A.6）。

### A.1 分段进度条（`HoverTip.FaithBar`）

- 一条 8 px 高的条，**一段 = 一级**，段宽 ∝ 这一级要涨的信力（阈值差）：蛮神 30 / 100 / 200 / 400 → 四段宽 30 : 70 : 100 : 200。段之间 1 px 分隔线（`UiPalette.LINE`）。
- 填充从左往右到当前信力：已到的级整段信仰色，正在涨的级填到比例，没到的级只剩槽（`#1a1512`）。满阶 = 全满，**不再隐藏**（原来 `progress < 0` 不挂）。
- 最窄一段不低于 12 px（自然之神第一段 25 / 800 太细），超出的宽度从其余段按比例扣。
- 接口：`FaithBar.thresholds: Array[int]`、`points: int`，`FaithTooltip.describe_full` 返回里 `progress` 换成 `{"thresholds", "points"}`（键名 `bar`）。条上不写字；「信力 45 / 100」那行照旧（右边数仍是下一阈值，满阶写「满阶」）。

### A.2 每级一行、没到的灰

- 同一 `tier` 的效果合并进一行，句子之间用「；」：`Lv.1　可以在祭坛赐福武器；生命值低于 30% 时，造成伤害提高 10%`。
- 用 `[table=2]` 排：左列 `Lv.n`（13 号 `tip_meta`，固定宽），右列句子（15 号），这样折行后第二行对齐在句子下面而不是回到 Lv 下面。
- **没到的级整行 `dim`**（dark `#8b93a1` / light `#5a4433`），Lv 号也 `dim`；原来的 `tip_desc` 不够灰。已到的级照旧 `tip_fg` + 数字 `val`。
- 没到的级里出现的 X（见 A.3）按**到那一级时至少有的信力**算（`max(points, thresholds[tier-1])`），不按现在的信力：Lv.4 没到就不会显示「持续战斗 1 秒」这种刺眼的数。

### A.3 蛮神五句（`_summary()` 全按字段拼，数字来自字段）

| 效果 | 新句子（玩家看到的） | 机制改动 |
|---|---|---|
| `altar_bless` Lv.1 | 可以在祭坛赐福**武器** | 不改。「武器」= 这个信仰 `blessings[].tags` 的中文名（`Glossary.tag_name`，多个用「、」）；`FaithPerk` 加 `summary_for(def: FaithDef) -> String`（默认回 `_summary()`），`AltarBlessPerk` 重写它取 def 的赐福标签；`FaithTooltip` 改调 `summary_for(def)`。花多少信力只在神坛按钮上写。 |
| `low_hp_empower` Lv.1 | 生命值低于 **30%** 时，造成伤害提高 **X%** | **改成门槛式**：现在是满血 10% → 空血 50% 线性。改为生命 < `hp_percent`（30）时造成伤害 +X%，X = `base_percent` 10 + ⌊信力 / 50⌋ × 5，上限 `max_percent` 50（30 点 → 10%，100 → 20%，400 → 50%）。`LowHpEmpower` 效果加 `hp_percent`、`percent` 两个字段，`compile_into` 时算好 X 塞进去（开战时的信力定一场）。 |
| `altar_sacrifice_hp` Lv.2 | 可以在祭坛献祭生命上限换取能力 | **二选一**：`altar_options()` = `[&"faith", &"buff"]`，神坛上是现成的 OptionButton（大地改造此点同款）。每次 −`hp_cost` 5 生命上限（最少留 5）：选「信力」+`faith_gain` 20 信力（`add_points`）；选「能力」这局所有道具**造成伤害 +5%、急速 +5%**（`StatModifier` MULT 进 `input.mods`，按次数叠），不再给耐力上限。按钮文字：「献祭 5 生命上限 → +20 信力」/「献祭 5 生命上限 → 这局造成伤害 +5%、急速 +5%」。次数分开记 `rituals["sacrifice_hp_buff"]`；旧存档里的 `sacrifice_hp` 次数当成 buff 次数（给过的耐力上限留在 `stat_bonus` 里不动）。 |
| `smite` Lv.3 | 可消耗 **1** 体力或 **30** 信力立即击败非首领敌人 | `types` 改 `[battle, elite]`（核心 = 首领，不含）；加 `faith_cost` 30。战前准备屏两个按钮「立即击败（耗 1 体力）」「立即击败（耗 30 信力）」，不够的那个灰掉并写原因；`prebattle_label/apply` 改成 `prebattle_actions(run, type) -> Array[{option, label, why}]` + `prebattle_apply(run, option)`，`GameFlow.smite(option)` 跟着带参数。 |
| `undying` Lv.4 | 在战斗中，首次生命值归零时会持续战斗 **X** 秒 | X = `base_sec` 2 + ⌊信力 / 50⌋ × 1，上限 `max_sec` 20（400 点 → 10 秒，和原来一样；800 → 18）。`compile_into` 算好秒数再 `keep_undying`。 |

- 「X 随信力」统一走一个小工具 `FaithPerk.scaled(points, base, step, per, cap)`，三处共用；信力取 `run.faith_power.points_of(run.active_faith().id)`。信力花掉（赐福、三级秒杀）X 就跟着降，这是作者要的「挂钩」。
- 旧句子（「所有伤害 +10%～+50%，血越少越高」「神坛：花 40 信力赐福一件」……）全部替换；`battle_note` 走同一句（185 的 buff 窗里显示的就是它）。
- 其他神的句子这次不动；按同一口气改写另开补充（自然 / 日神 / 大地各 4～5 句）。

### A.4 献祭做成图标，「占 9 格以上」→「大型道具」

- 献祭段改成**一行图标**：每条规矩一枚 24 px 图标 + 下方 12 号名字，横排、间距 14 px；倍率不写（作者 10-17：不写公式；神坛拖上去就看到实际点数）。
- 图标来源：标签 → `assets/ui/tags/<tag>.png`（和徽记 `assets/ui/faith/<id>.png` 同一做法，`UiTheme.art_cached`）；多标签一条规矩（狩猎「血肉 / 骨制品」）画两枚挨着；体积条件 → `assets/ui/offerings/large.png`（大型道具）/ `medium.png`（中型道具，日神）；属性条件 → `assets/ui/offerings/crit.png`（技巧「带暴击属性」）。图没到位时退回文字（现状那行），不画白块。
- 文字层：`OfferingRule.describe()` 的 `min_cells` 分支改成「大型道具」（≥ 9 格 = 大及以上，作者定这个词），`exact_grade` 分支「中型道具」这类（`ItemVolume.grade_name(g) + "型道具"`）；神坛屏等别处凡是「X 体积及以上」的字一起换（grep `体积及以上`）。
- **交美术**（一并转「美术设计」）：标签图标 14 枚 —— 骨制品、血肉、武器、战利品、皮革、自然、食物、装备、防具、盾、金属、工艺、火、宝石；条件图标 3 枚 —— 大型道具、中型道具、暴击属性。24 px 显示、按 48 px 画；风格跟徽记。

### A.5 改动清单（给执行）

- `ui/inventory/hover_tip.gd`：`FaithBar` 分段（A.1）；`show_faith` 第一段用 `[table=2]`（A.2），献祭段用 `[img=24]`（A.4）。
- `core/run/faith/faith_tooltip.gd`：按 tier 分组合并、`dim`、`summary_for(def)`、锁住级的 X 按阈值算、献祭段图标 / 文字回退。
- `core/run/faith/faith_perk.gd`：`summary_for(def)`、`scaled(...)`、`prebattle_actions(run, type)`、`prebattle_apply(run, option)`。
- `core/run/faith/perks/`：`altar_bless`（赐福标签名）、`low_hp_empower`（门槛 + X）、`altar_sacrifice_hp`（二选一 + 增伤 / 急速）、`smite`（两种代价、非首领）、`undying`（X 秒）。`core/battle/effects/low_hp_empower.gd` 门槛式；`estimated_value` 跟着改（低血时间占比 × percent）。
- `ui/game/prebattle_screen.gd:78-85`、`core/run/game_flow.gd:889` `smite(option)`；`ui/game/altar_screen.gd` 选项按钮文字用 `altar_option_label(option)`（新钩子，默认回 `String(option)`）。
- `core/run/faith/offering_rule.gd` 的「大型道具」措辞；`ItemVolume` 加 `size_label(g)`。
- **数据**：`docs/gods.xlsx` 等级效果页先改（蛮神 1 级参数 `hp_percent/base_percent/step/per/max_percent`、2 级 `faith_gain/damage_percent/haste_percent`、3 级 `types: [battle, elite]` `faith_cost`、4 级 `base_sec/step/per_sec/max_sec`），再 `tools/gods_xlsx_to_json.gd` → `tools/import_content.gd`，否则 `check_content` 红；`gods.md` 镜像重生成。存档：`rituals` 键沿用，`bash tools/snapshot_content.sh`。
- 字体：新字（「击败」「持续」「首领」「能力」「换取」「型」等）按 168 重裁。
- 测试：
  1. `FaithBar` 四段宽度比 30:70:100:200（容差 1 px），45 点时第一段满、第二段 15/70；满阶全满且仍挂着。
  2. 蛮神 45 点：第一段只有 4 行（Lv.1～Lv.4 各一行），Lv.1 行同时含「赐福武器」「30%」「10%」，Lv.2～4 行在 `[color=@dim]` 里；Lv.4 行写「10 秒」（按 400 算）不是「2 秒」。
  3. 400 点时 Lv.1 行「50%」；花 40 信力赐福后降到 360 → 「45%」（⌊360/50⌋×5+10 = 45）。
  4. `LowHpEmpower`：生命 29% 时伤害 ×1.10（45 点），31% 时不加。
  5. 神坛二级：选「信力」+20 点；选「能力」后编译出的单位每件道具 `damage` MULT +5、`haste` MULT +5；再做一次 +10。
  6. 战前准备屏在普通战斗点也有两个按钮；信力 29 时信力按钮灰且 `why` 非空；体力 1 时体力按钮灰（现在就是 `<= cost` 不许）。
  7. 献祭段：有图时含 `[img=24]res://assets/ui/tags/bone.png`，无图时含「骨制品」；文字里没有「9 格」「体积及以上」，有「大型道具」。
  8. `check_content` 过（表与 JSON 一致）。

### A.6 待定（默认按推荐）

1. **二级「能力」是一个 buff 还是增伤 / 加速二选一** —— 推荐 **甲**：一个 buff，增伤 +5% 和急速 +5% 一起给（作者原话「全局增伤/加速buff」）。乙：选项变三个（信力 / 增伤 / 加速），各 +10%。
2. **X 的台阶** —— 推荐 **甲**：每 50 信力一阶（表里 `step` 可调）。乙：连续线性（每点 +0.1%），数字会很零碎。
3. **献祭段写不写倍率** —— 推荐 **甲**：不写（作者 10-17）。乙：图标右下角小字「×5」。
4. **三级信力代价** —— 推荐 **甲**：30 信力（和一级赐福的 40 一个量级，普通战斗点也能用）。乙：50。
