# 方案：字色模板配置 —— 每个颜色名写深底版与浅底版，浅底一律暗字、深底一律亮字（169）

> 作者原话（2026-10-13，游戏反馈小修帖，带截图）：「设计一个模板配置文件，固定在亮色背景下指用暗色字体，在暗色背景下指用亮色字体，当前界面的颜色不适合亮橙色」。
> 性质：架构 · 实施。待定按推荐。关联 101（样式码 `{c:hp}`）、112（道具名按稀有度上色）、157 补（深浅字色，`ink_color` 自动压暗）、157 补充三 / 164（浅色大理石、家的布底）。小修已做止血：事件正文、地图规则卡、百科正文在浅底上过 `UiTheme.ink_bbcode`。

## 1. 现状与问题

- 颜色全是代码常量：`UiPalette.STYLE_COLORS`（fg / dim / hp / armor / stamina / mana / heal / grant / receive / warn / danger / good / faith）、`RESOURCE_COLORS`、`DAMAGE_COLORS`、`ItemPainter.RARITY_COLORS`、`Glossary.TERM_COLOR`，都是**为深底调的亮色**。
- 浅底上只有一招：`UiTheme.ink_color(c)` 把亮色**逐步压暗**到对纸的对比够 4.5（157 补）。压出来的颜色没人挑过 —— 亮橙压暗还是橙，截图里浅色大理石上的橙 / 绿 / 红就是这么来的。而且要每个调用点自己记得过一道 `ink_bbcode`，漏一处就是亮字压浅底。
- 作者要的是：**一份文件**，每个颜色名写两版，底是浅的就用暗版、底是深的就用亮版，颜色由作者挑，不靠算法压。

## 2. 改法

### 2.1 文件 `data/authoring/ui/text_colors.json`

```json
{
  "version": 1,
  "styles": {
    "fg":      {"dark": "#dfe3ea", "light": "#2e2219"},
    "dim":     {"dark": "#8b93a1", "light": "#5a4433"},
    "hp":      {"dark": "#d9534f", "light": "#8c2b22"},
    "armor":   {"dark": "#5bc0de", "light": "#1f5f7a"},
    "stamina": {"dark": "#f0ad4e", "light": "#7a4b10"},
    "mana":    {"dark": "#7a8cf0", "light": "#2f3f9a"},
    "heal":    {"dark": "#5cb85c", "light": "#2f6b2f"},
    "grant":   {"dark": "#6fb3f0", "light": "#1f4f8a"},
    "receive": {"dark": "#f0a85c", "light": "#7a4b10"},
    "warn":    {"dark": "#f0ad4e", "light": "#9a5a22"},
    "danger":  {"dark": "#d9534f", "light": "#8c2b22"},
    "good":    {"dark": "#5cb85c", "light": "#2f6b2f"},
    "faith":   {"dark": "#c79bf2", "light": "#5c3a8a"},
    "term":    {"dark": "#c9a0ff", "light": "#5c3a8a"},
    "crit":    {"dark": "#ffd23f", "light": "#8a6a00"}
  },
  "rarity": [
    {"dark": "…", "light": "…"}, …（六档，深版 = 现在 ItemPainter.RARITY_COLORS）
  ],
  "damage": {
    "physical": {"dark": "#ff8a7a", "light": "#8c2b22"},
    "fire":     {"dark": "#ff9d4d", "light": "#8a4a10"},
    "poison":   {"dark": "#8ed36b", "light": "#2f6b2f"},
    "bleed":    {"dark": "#e05c7a", "light": "#8c2b4a"},
    "reflect":  {"dark": "#c9a0ff", "light": "#5c3a8a"},
    "drain":    {"dark": "#9aa3b2", "light": "#4a4433"}
  }
}
```

- 深版 = 现在代码里的值（行为不变）；浅版是**起稿**，取暗褐、赭、深蓝那一路（浅色大理石上像墨），作者直接改文件。橙在浅底上统一走赭 / 棕（`stamina / receive / warn`），不再出现亮橙。
- 规则写死在文件格式里：每个名字**必须**两版都有；缺一个文件整份不用，回代码默认（和布局文件一样的容错）。
- 资源条颜色（`RESOURCE_COLORS`）直接复用 `styles` 里同名的（hp / armor / stamina / mana），不另列。

### 2.2 代码

- `UiPalette.text_colors`（静态，启动时 `load_text_colors()` 读一次；文件不在或坏了用代码常量拼出同样结构，`problems` 记下来给校验）。
- 取色统一一个入口：`UiPalette.style_color(name: String, tone: StringName) -> Color`、`rarity_color(r, tone)`、`damage_color(type, tone)`、`resource_color(key, tone)`；`tone` 只有 `UiTheme.TONE_DARK / TONE_LIGHT`。
- `resolve_styles(bbcode, tone := TONE_DARK)`：按 `tone` 换色；`{c:#hex}` 这种**写死的十六进制**浅底时仍走 `ink_color` 兜底（待定 3）。`ink_bbcode` 留着只管十六进制，不再碰样式码。
- **底是深是浅由容器说**：`UiTheme.apply_tone(control, variation)` 现在只换字色，改成同时 `control.set_meta("tone", tone)`；新 `UiTheme.tone_at(control) -> StringName` 往上找第一个带 `tone` 元数据的祖先（没有 = 深）。富文本块（`UiTheme.rich_block`）进树后 `_ready` 里 `text = UiPalette.resolve_styles(raw, UiTheme.tone_at(self))` —— 原始 bbcode 存在 `rich.set_meta("raw", …)`，换底（地图底图切换、设置换主题）时 `refresh_tones()` 重算。小修止血加的那几处 `ink_bbcode` 调用去掉，统一走这一道。
- `UiTheme.INK / INK_SOFT / INK_WARN` 改成读 `styles.fg.light / dim.light / warn.light`（代码常量留作文件不在时的默认），`LABEL_*` 浅底变体跟着文件走。
- `ItemPainter`（棋盘格上的道具名按稀有度上色）：格子有自己的深底，照旧用深版；悬浮窗 / 正文里 `{item:id}` 的名字按所在底取版（待定 4）。
- `MapView` 的 `_skin_light` 分支改调 `style_color(name, tone)`，`ink_color` 不再在这条路上。
- 调试：启动器加一页「配色」—— 两列（深底 / 浅底）把 `styles / rarity / damage` 全列出来写样字，改文件后按 F5 重读（`load_text_colors()` 可重入）。作者调色不用开游戏翻到那一屏。

### 2.3 校验与测试

- `tools/check_content.gd`：文件能读、`version` 对、`TextTemplate.STYLE_NAMES` 里每个名字 + `term / crit` 都在、稀有度六档、`damage_types/` 里每种类型都有；**对比度**：每个浅版对 `UiTheme.PAPER` ≥ `MIN_CONTRAST`（4.5），每个深版对 `UiPalette.PANEL` ≥ 4.5，不够的列出名字和差多少。另外扫内容里写死的 `{c:#…}`，列成警告（建议换成名字）。
- `tests/ui/test_text_colors_169.gd`：读文件；`style_color("stamina", light)` ≠ 深版且对纸对比够；`resolve_styles` 两种 tone 产出不同十六进制；`tone_at` 沿祖先找到 `PANEL_TOOLTIP` 的浅；文件缺一版 → 整份回默认并有 problem；富文本块在浅底框里进树后文本里没有深版颜色。
- `test_screens_157` 里「压成墨水版后对比够」那组改成读文件的浅版；UI 棘轮不涨。

## 3. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 文件格式 | A json（`data/authoring/ui/text_colors.json`，手改）；B xlsx 生成 | **A**：二十来个名字，两列颜色，json 一眼看完；xlsx 那套留给几十行的表 |
| 2 | 底的深浅怎么传到文字 | A 每个调用点传 `tone`；B 容器打 `tone` 元数据，文字往上找（调用点不传） | **B**：A 就是现在的「每处记得过一道」，还会漏；B 漏不了，调用点也不用改 |
| 3 | 内容里写死的 `{c:#hex}` | A 浅底时 `ink_color` 兜底 + 校验警告；B 禁止，校验报错 | **A**：先不卡内容；警告列出来，作者愿意就换成名字 |
| 4 | 棋盘格上的道具名（稀有度色） | A 格子自带深底，照旧深版；B 跟所在屏的底 | **A**：格子的底不随屏变 |

## 4. 改动范围

| 文件 | 改什么 |
|---|---|
| `data/authoring/ui/text_colors.json`（新） | 2.1 |
| `ui/ui_palette.gd`（`load_text_colors`、`style_color / rarity_color / damage_color / resource_color(…, tone)`、`resolve_styles(…, tone)`） | 2.2 |
| `ui/ui_theme.gd`（`apply_tone` 打元数据、`tone_at`、`rich_block` 进树按底换色、`INK*` 读文件、`ink_bbcode` 只管十六进制） | 2.2 |
| `ui/inventory/hover_tip.gd`、`ui/game/event_screen.gd`、`ui/game/map_screen.gd`（规则卡）、`ui/game/encyclopedia_screen.gd`、`ui/map/map_view.gd`、`ui/inventory/item_painter.gd` | 去掉各自的 `ink_bbcode` / `ink_color`，走统一入口 |
| `ui/launcher.gd`（配色页） | 2.2 |
| `tools/check_content.gd`、`tests/ui/test_text_colors_169.gd`（新）、`tests/ui/test_screens_157.gd` | 2.3 |
| `docs/architecture.md` 8.8（深浅字色）改写 | |

## 落地记录

- 待定全按推荐：1 A（json 手改）、2 B（容器打 `tone` 元数据，文字往上找）、3 A（写死的十六进制浅底时兜底压暗，校验只警告）、4 A（棋盘格上的道具名照旧深版）。
- 统一入口是 `UiPalette.toned(bbcode, tone)`：颜色名按模板取版；浅底上写死的十六进制先查「深版 → 浅版」表（同一个深版写了两种浅版的，比如体力 / 警示都是 `#f0ad4e`，先登记的算），已经是浅版的不动，别的才走 `ink_color`。所以还在传十六进制的老调用点（道具悬浮窗里的增益 / 受益槽、术语链接）不用改也拿到作者挑的浅版。
- 比方案多一处：`UiTheme.label` 覆写过语义色（生命红、治疗绿……）的**标签**也按所在的底换版（进树时、`refresh_tones` 时），不只富文本。地图图例自己是深底，补了 `tone = dark`。
- 浅版起稿按方案；方案没写的几条：稀有度浅版（墨、深绿、深蓝、深紫 `#6a2f8a`、暗金 `#725600`、深红）；暴击浅版 `#8a6a00` 在纸上只有 4.39，改成 `#725600`；`ice` / `lightning` 两种伤害类型原来没有颜色（用前景色），模板里深版照旧前景、浅版墨。
- **深版对比**：生命 / 危险红 `#d9534f` 对深面板 4.40、神话红 `#d9453f` 4.04，不到 4.5。方案要深版 = 原值（行为不变），所以深版不够只列警告、不让校验红；作者想调亮就改文件。
- 小修帖止血的三处（事件正文、地图规则卡、百科正文）改成直接把带颜色名的 BBCode 交给富文本块；`slab_bbcode` 删了，`ink_bbcode` 留作 `toned` 的转发。地图浮窗的文字也不再先按深底换色。
- 启动器「配色」页：深底（面板色）与浅底（纸色）两列，每条一行样字 + 十六进制 + 对比度（不够标红），F5 重读文件。
