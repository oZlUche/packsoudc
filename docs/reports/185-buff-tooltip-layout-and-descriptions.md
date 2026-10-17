# 185 · 方案：效果悬浮窗重排 —— 字为什么「看不见」、只剩名字行与现在的合计、变量上色；血怒加到 +15% / +15%

> 作者 2026-10-17 15:42（附战斗屏截图，停在「标记」图标上）：「属性的悬浮窗文本排版有点怪，留了太多空，另外还有一些基础buff缺少说明，统一补充，给我看看你的方案，记得说明栏里要显示每层效果和当前总效果，并且要给变量用不同颜色的字体」。
>
> 看过样张后作者改口（15:58、16:03）：「去掉说明性文本，去掉【每层】这一行，去掉【当前X层/次】」「只要现共，以坚韧为例，应该改成【护甲上限+30】，中毒【每秒受到5点毒素伤害】」；16:04：「血怒不能叠层吗？那给的数字大方点好了（改成15伤害和15攻速）」；16:07：「菌血改为【恢复量减半，每次恢复获得等量的中毒】，燃血改为【恢复量归零，每秒受到N点火焰伤害】。最后的文本描述也不需要，那个是内部说明，不该给玩家看，类似的情况我需要你调用查询线程对整个游戏进行一次检索，隐藏或者删掉那些文字」。本篇按改口后的定稿写，**已转「架构方案执行」**；全游戏内部说明文字的检索由「查询」线程做（协调者 16:07 告知）。样张 v4（平面、真实尺寸）：https://claude.ai/artifact/XfzezPkZ1CdB6xvWwm8Rok

## 0. 结论

1. **「留了太多空」的主因不是排版，是字被染成了墨色**。战斗屏整块压在浅色大理石板（`OverlayFrame`，tone light）里，石板给自己挂了「墨字」小主题；效果悬浮窗 `HoverTip` 是 `BattleView` 的子节点，它那块深色皮革窗没有自己的主题，于是**继承了墨字**：标题「标记」、「减益」、「每层带【破绽】3 层（格挡 −3）」全是深字写在深皮革上，只有 103 用十六进制写死的例外色（`#e0b45c`「不可叠层」「持续 8.0 秒」）露了出来 —— 和截图完全一致。道具悬浮窗没中招，因为它的正文整段包了 `[color=@tip_fg]`。修法一行（§4）。
2. 次因：悬浮窗宽度写死 360（170 定稿是为武器那一行），一两行短字也撑满一格；文字窗改成**按内容收窄**（下限 220、上限 360），道具窗不动。
3. 新版式只有两段：**名字行**（名字 + ×层数 + 增益 / 减益 / 系统小字）→ **效果**（只写**现在的合计**：每层的量 × 当前层数；不可叠层的写效果本身）。不写解说句，不写每层的量（层数在名字行的 ×N 里），**不写规则行**：计时、减半、元素印、不可解除、不可叠层与时长这些是内部说明，作者定不给玩家看（16:07）。
4. 变量全部上色（§2.3）：数值一色（新样式 `val`，暖金）、伤害类型字沿用 175 的伤害色、状态关键词沿用元素关键词色并可钉开子窗、属性 / 轴名用正文色不另染。103 的例外色退役（没有规则行了）。
6. 菌血、燃血的效果句按作者原话：「恢复量减半，每次恢复获得等量的中毒」「恢复量归零，每秒受到 N 点火焰伤害」。
5. 顺带的数值改动（作者 16:04）：**血怒**从强攻 1 层 + 加速 1 层（+3% / +3%）改成 **5 层 + 5 层（+15% / +15%）**，仍不可叠层、持续 10 秒。

## 1. 现状与诊断

### 1.1 字看不见（主因）

| 证据 | 位置 |
|---|---|
| 战斗屏把 `BattleView` 放进 `_centered_panel()` → `OverlayFrame`（一整块大理石板） | `ui/game/battle_screen.gd:15-28`、`ui/game/game_screen.gd:272-280` |
| 石板按自己的深浅挂字色：`UiTheme.apply_tone(area, PANEL_OVERLAY)`；大理石 tone light → 挂上 `text_theme(light)`，里面 `RichTextLabel.default_color = INK` | `ui/game/game_screen.gd:199`、`ui/ui_theme.gd:540-556` |
| `HoverTip` 直接 `add_child` 在 `BattleView` 下 | `ui/battle/battle_view.gd:687` |
| `TipWindow._init` 只调 `UiTheme.panel(self, -1, PANEL_TOOLTIP)`；皮革是深底，`set_tone(dark)` 对深底**不挂主题**（`text_theme(dark)` 返回 null），于是 `theme` 为空、一路继承到石板的墨字 | `ui/inventory/hover_tip.gd:57-58`、`ui/ui_theme.gd:584-588` |
| buff 悬浮窗的正文没包颜色：`"[b]%s[/b]\n%s"`，靠 `default_color` | `ui/battle/battle_view.gd:160-164` |
| 道具悬浮窗整段 `[color=@tip_fg]`，所以正常 | `ui/inventory/item_tooltip.gd:234` |
| 名牌早就撞过同一个坑，自己挂了 `bright_text_theme()` 解决 | `ui/widgets/nameplate.gd:29` |

截图里能看见的恰好只有 `_exception()` 染的两段（`core/text/glossary.gd:258-262`），是这个诊断的直接印证。沙盒、回放浏览器里的同一个 `BattleView` 不在石板里，所以那边看着是对的 —— 这也是为什么一直没人发现。

### 1.2 宽度写死（次因）

`HoverTip.MAX_WIDTH = 360`（`hover_tip.gd:16`）直接作为 `rich_block(width)` 的 `custom_minimum_size.x`。富文本只会按内容长高，不会按内容收窄；「不可叠层　持续 8.0 秒」一行十几个字也占满 360，右边一大片空。

### 1.3 文案是「每层带什么」的字段清单

`Glossary.describe_buff()`（`glossary.gd:205-255`）逐字段拼：第一行「减益　不可叠层　持续 8.0 秒」，之后每层的轴 / 属性 / 规则、上身 / 到期、计时、减半、按类型易伤、元素印、截治疗、恢复叠层。中毒读出来是「减益　不限层　永续 / [每 1.0 秒] 对自己造成 1 点毒素伤害（每层） / 毒元素的印：……」：没有**现在一共多少**（面板知道层数 `CombatantPanel.stacks()`，悬浮窗不用）；默认事实「增益　不限层　永续」也占一行；数值、层数、时长都是正文色，只有 103 的例外色和 175 的「X伤害」带色。

## 2. 方案

### 2.1 版式（两段，宽 220–360 按内容收窄，内边距沿用 14）

```
┌────────────────────────────┐
│ 中毒 ×5                减益 │  ← 名字 19 号粗体、状态色、描边（170 同款）；×层数 19 号粗体，数字 val 色；增益/减益 13 号 tip_meta 右对齐
│ ────────────────────────── │  ← 170 的分隔线
│ 每秒受到 5 点毒素伤害          │  ← 15 号正文；数值 val 色；「毒素伤害」毒伤害色
└────────────────────────────┘
```

- **名字行**：`Names.of(def)`，颜色 `Glossary.status_style(def)`（元素状态用元素关键词色，其余 `term`）；系统状态（衰竭、鏖战）用 `CombatantPanel.SYSTEM_COLOR`。可叠层的写 `×N`（N = `panel.stacks()[id]`）；不可叠层不写。右端小字「增益」/「减益」/「系统」。
- **效果段**：每条效果一行，写**这个状态现在的合计**（每层的量 × N，§2.2 表）；不可叠层的（N 恒为 1）就是效果本身。没有层数的场合（图鉴、道具子窗、编辑器预览）N 按 1 算，名字行不写 ×N。合计只是**这个状态自己**的；同一条轴若还有别的来源，总数看轴格（`axis:*`）的悬浮窗。
- **没有规则行**：叠层 / 时长 / 计时 / 减半 / 元素印 / 「系统效果，不可解除」/ 「其中 N 层不可解除」这些机制说明都不写（作者 16:07：内部说明，不该给玩家看）。它们仍由 `Glossary.buff_rule_lines(def)` 生成，只给**作者工具**用（buff 制作器预览、`check_content` 的词条报告），玩家看到的窗不拼它。103 的例外色随之退役。

轴格（`axis:*`）套同一版式：名字行「强攻 ×3」、效果「造成的伤害 +9%」；系统层那句「其中 N 层来自系统规则」不写。「格挡 N」格：名字行「格挡 12」+ 各层列表（153，生效那层标出来）—— 那是数值来源，不是机制说明，留着。

### 2.2 合计怎么从字段折算

| 字段 | 效果一行（N = 当前层数） | 例 |
|---|---|---|
| `axes`（`BuffAxis`） | 轴名 + `StatAxes.effect_text(axis, stacks × N)`（连乘轴 `STAMINA_COST` 由它自己算幂，不手乘） | 血怒：「造成的伤害 +15%」「攻速 +15%」 |
| `mods`（`StatModifier`） | 量 × N 再走 `Glossary.mod_text` | 坚韧 ×2：「护甲上限 +30」 |
| `rules` 里按层的 `deal_damage`（`per_stack`） | 「每秒受到 N×量 点X伤害」（`rule_text` 的「对自己造成」在悬浮窗语境改口「受到」） | 中毒 ×5：「每秒受到 5 点毒素伤害」 |
| `per_stack_percent` + `decay_halve_on = weapon_fired` | 「下一次出手的冷却 +10%×N」 | 寒冷 ×3：「下一次出手的冷却 +30%」 |
| `per_stack_percent` + `stamina_paid` | 「下一次付耐力多付 10%×N」 | 麻痹 ×2：「下一次付耐力多付 20%」 |
| `damage_taken_by_type` | 「受到的毒素伤害 +25%×N」 | 剧毒 ×2：「受到的毒素伤害 +50%」 |
| `heal_cut`（不按层） | 50 →「恢复量减半」，100 →「恢复量归零」，其余「恢复量少 N%」 | 菌血、燃血 |
| `heal_echo`（不按层） | `per_point` 为 1 →「每次恢复获得等量的中毒」，否则「每次恢复按 N 倍获得中毒」 | 菌血 |
| `seconds_per_stack`、`element`、`decay_halve_on`、`stackable`、`duration_sec`、`system`、保底层 | **不写**（内部说明，只进 `buff_rule_lines` 给作者工具） | — |
| `on_apply` / `on_expire` | 「上身时：…」「到期时：…」（目前没有状态用到） | — |
| 衰竭（系统，`OvertimeRules.decay_buff`） | 「生命上限 −N×量」 | 衰竭 ×3 |
| 鏖战（系统，轴格的系统层） | 「受到的最终伤害 +20%×次数」 | 鏖战 ×2：「受到的最终伤害 +40%」 |

同一个状态几条效果就几行，顺序：规则伤害 → 轴 → 属性 → 截治疗 / 恢复叠层 → 按类型易伤 → 出手 / 付耐力。`describe_buff(def, stacks := 1)` 保留做总装（名字行 + 效果）；`Glossary` 拆出 `buff_head(def, stacks)`、`buff_effect_lines(def, stacks)`、`buff_rule_lines(def)`（作者工具专用）、`val(text)`（§4）。

### 2.3 颜色规则（都走 `text_colors.json`，深浅各一版）

| 什么 | 样式 | 备注 |
|---|---|---|
| 数值：+15%、5 点、8 秒、「×5」里的 5 | **新样式 `val`**：dark `#f3c969` / light `#6b4e00` | 暖金，和铜框同族；作者说的「变量」就是它们 |
| 「X伤害」 | 175 的伤害色（`Glossary.DAMAGE_STYLES`，`mark_rich` 已经在做） | 整段「毒素伤害」一色 |
| 状态关键词（菌血句里的「中毒」） | 175 的元素关键词色 + 下划线 | 钉住后可开子窗（170 机制现成，`terms` 从 `Glossary.buffs_in_*` 收） |
| 名字 | `status_style(def)`；系统状态 `SYSTEM_COLOR` | 描边（`UiTheme.outline`） |
| 属性 / 轴名（造成的伤害、攻速、格挡、护甲上限） | 正文 `tip_fg` | 不另染，免得一行五种色 |
| 增益 / 减益 / 系统小字 | `tip_meta` | |
| 103 例外色 `#e0b45c` | 退役 | 没有规则行了 |

数值怎么染：生成函数拼数字时统一经 `Glossary.val(text)` → `[color=@val]…[/color]`。不改 `StatAxes.effect_text` 的签名；它返回的「造成的伤害 +15%」里的数字由一个小正则在 `Glossary` 一层补色（数字、正负号、% 和「点 / 秒 / 层」前的那个数）。

## 3. 十六个状态按新版式读出来（×N 取常见层数）

| 名字行 | 效果 |
|---|---|
| 中毒 ×5　减益 | 每秒受到 5 点毒素伤害 |
| 流血 ×4　减益 | 每秒受到 4 点流血伤害 |
| 灼伤 ×3　减益 | 每秒受到 3 点火焰伤害 |
| 寒冷 ×3　减益 | 下一次出手的冷却 +30% |
| 麻痹 ×2　减益 | 下一次付耐力多付 20% |
| 剧毒 ×2　减益 | 受到的毒素伤害 +50% |
| 菌血 ×4　减益 | 恢复量减半，每次恢复获得等量的中毒 |
| 燃血 ×3　减益 | 恢复量归零，每秒受到 3 点火焰伤害 |
| 血怒　增益 | 造成的伤害 +15% ／ 攻速 +15% |
| 弹开　增益 | 格挡 +8 |
| 久弹　增益 | 格挡 +4 |
| 标记　减益 | 格挡 −3 |
| 坚韧 ×2　增益 | 护甲上限 +30 |
| 护符结界 ×1　增益 | 护甲上限 +8 |
| 衰竭 ×3　系统 | 生命上限 −3×量 |
| 鏖战 ×2　系统 | 受到的最终伤害 +40% |

名字「坚韧」和「受到伤害」轴负层的名字「坚韧」同字（`StatAxes.TABLE DAMAGE_TAKEN.neg`），老问题，这里不动。

## 4. 改动清单（给执行）

**数据**
- `data/authoring/buffs/blood_rage.json`：`axes` 改 `[{"axis": "damage_dealt", "stacks": 5}, {"axis": "attack_speed", "stacks": 5}]`（+15% / +15%）；`stackable false`、`duration_sec 10` 不动。引用血怒的道具增益句由字段生成，会自己跟着变；`bash tools/snapshot_content.sh` 刷快照（173）。
- `data/authoring/ui/text_colors.json`：`styles` 加 `"val": {"dark": "#f3c969", "light": "#6b4e00"}`；`TextTemplate.STYLE_NAMES` 与 `UiPalette.EXTRA_STYLES` 登记。

**文案生成（`core/text/glossary.gd`）**
- 拆出：`buff_head(def, stacks)`（名字行 BBCode）、`buff_effect_lines(def, stacks) -> Array[String]`（§2.2 的合计）、`buff_rule_lines(def) -> Array[String]`（机制说明，**只给 buff 制作器预览与 check_content 报告**，玩家窗不拼）、`val(text)`（数值上色）。
- `describe_buff(def, stacks := 1)` 保留，重新总装两段（名字行 + 效果）。图鉴（`encyclopedia.gd:105`）与道具子窗（`item_tooltip.gd:224`）不传层数，按 1 层。
- `EXCEPTION_COLOR` / `_exception()` 删除。
- `rule_text` 里按层对自己的伤害在悬浮窗语境改口「每秒受到 N 点X伤害」（原句「[每 1.0 秒] 对自己造成 1 点毒素伤害（每层）」留给道具增益句，那边是作者视角）。
- `heal_cut` / `heal_echo` 的句子按 §2.2：「恢复量减半」「恢复量归零」「每次恢复获得等量的中毒」。
- `ui/buff_editor/buff_editor.gd:297` 的 `axes_text()` 现在取 `describe_buff().split("\n")[1]`，版式一改就取错 —— 改成直接调 `buff_effect_lines(def, 1)`。

**界面**
- `ui/inventory/hover_tip.gd`：
  - `TipWindow._init` 末尾 `theme = UiTheme.bright_text_theme()`（名牌同款）—— 皮革窗嵌在浅石板里也不继承墨字。这是 1.1 的修法，一行。
  - 按内容收窄：`show_text()` 用 360 排一遍，`_refit()` 里读 `body.get_content_width()`，`custom_minimum_size.x = clamp(内容宽 + 1, 220, 360)` 再 `reset_size()`；`show_item()` 不收窄（170 定稿 360）。
- `ui/battle/battle_view.gd`：`buff_tip()` 改成 `Glossary.describe_buff(def, panel.stacks()[id])`，**不再**追加「系统效果，不可解除」「其中 N 层不可解除」；鏖战、轴格、格挡格套同一版式（§2.1 末段），`StatAxes.describe()` 的「每层 ±…（正为…负为…）」「其中 N 层来自系统规则」两句也不给玩家。
- `ui/battle/battle_view.gd:135`：`show_text(bbcode, at, null, terms)` 把 `Glossary.buffs_in_*` 收来的状态词条传进去，关键词才能钉开子窗。

**字体**：新词「受到」「现」等若不在子集里，按 168 规矩跑 `tools/font_charset.py` 重裁（`assets/fonts/README.md`）。

**测试**
- 改：`tests/ui/test_reactions_ui_175.gd:78-94`（断言按新文案：「火元素的印」留；「受到的毒素伤害每层 +25%」→ `describe_buff(virulent, 2)` 含「受到的毒素伤害 +50%」；菌血「每次恢复生命少 50%」→「回血只回一半」）、`tests/ui/test_keyword_tips.gd:71`、`tests/battle/test_buff_axes_152.gd`（血怒 5 层）、`tests/battle/test_overtime.gd`、`tests/authoring/test_content_pipeline.gd` 里引用 `describe_buff` 的地方。
- 新：
  1. 深底窗嵌浅石板：把 `HoverTip` 挂到一个 `apply_tone(PANEL_OVERLAY)`（light）的容器下，`show_text("标记")` 后 `body.get_theme_color("default_color")` 不是 `INK`。
  2. `describe_buff(poison, 5)` 含「每秒受到 5 点」且不含「每层」「当前」「元素的印」；`describe_buff(blood_rage, 1)` 含「+15%」两处、不含「不可叠层」「持续」；`describe_buff(hardy_guard, 2)` 含「护甲上限 +30」；菌血含「恢复量减半，每次恢复获得等量的中毒」，燃血含「恢复量归零」。
  3. 玩家窗（`buff_tip`）对任何状态都不含「减半」「计 」「不可解除」「元素的印」；`buff_rule_lines(scorched_blood)` 仍含「每层持续」（作者工具用）。
  4. 短文案的窗宽 < 360、长文案 = 360。
  5. 所有数值都在 `[color=@val]` 里（正则扫一遍 BBCode，裸数字为零）。

## 5. 待定（默认按推荐）

1. **数值色** —— 推荐 **甲**：新样式 `val` 暖金 `#f3c969`（和铜框同族、和 175 的五种元素色都拉得开）。乙：直接用现有 `crit`（`#ffd23f`，更黄、更亮，但「暴击」已经占着它的语义）。
2. **限时状态（血怒 10 秒、标记 8 秒……）剩余时间** —— 推荐 **甲**：窗里不写（作者定规则行全去），以后要的话做成图标上的计时环，另提。乙：效果下面补一行「还剩 N 秒」（又是一行说明）。
3. **窗宽** —— 推荐 **甲**：文字窗按内容收窄 220–360，道具窗固定 360。乙：全部固定 300（短字仍留空、武器行要折）。
4. **图鉴 / 道具子窗里的层数** —— 推荐 **甲**：按 1 层写（「每秒受到 1 点毒素伤害」），名字行不写 ×N。乙：写「每层」字样（作者在战斗窗里刚去掉，图鉴再加回来不一致）。

## 6. 样张与经过

- v1（15:52）：四段（名字 / 解说句 / 每层 + 当前 N 层 / 规则行）。作者：去掉解说句、去掉「每层」与「当前 X 层」。
- v2（16:00）：每条效果一行「每层的量，现共合计」。作者：只要合计。
- v3（16:06）：只写合计。作者：菌血 / 燃血改措辞；规则行是内部说明，去掉；类似文字全游戏检索（→「查询」线程）。
- v4（16:10，定稿）：https://claude.ai/artifact/XfzezPkZ1CdB6xvWwm8Rok —— 八个窗：标记、坚韧 ×2、中毒 ×5、寒冷 ×3、血怒、菌血 ×4、鏖战 ×2、燃血 ×3，只有名字行与效果，左上角是现状对照。
