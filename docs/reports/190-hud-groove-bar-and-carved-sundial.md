# 190 · 落地：顶端栏一条长槽 + 刻在槽底的半圆日晷（189 定案）

> 189 讨论稿 → 美术样张 → 作者 2026-10-18 定案：「乙的整体风格，但是倒计时要换成日晷样式」「去掉数字倒计时，而是设计成鼠标移动上去时出现悬浮窗」「日晷记住要刻上去的，而不是额外的部件」「重点是当前时刻，颜色要足够深」，10:46 看了 G 版「可以」。
>
> 美术定稿：`/mnt/project-files/art/ui/hud/v2/`（README.md、`out/` 1×、`out/@2x/`、`dial.json`、样张 `preview_G.png`）。本篇只写怎么落进代码；美术的像素不改。

## 1. 要变成什么样

- 栏底还是现在的大理石长板（`slab_bar`）。板上铺**一条贯通的浅槽**（`hud_groove.png` 九宫格 160 × 88，边距 [40, 0, 40, 0]：两端铜包角不拉伸，中段横向拉；槽身占 y 12–68，左右各留 14）。
- 栏里每件读数**不再各自画凹槽**：心、币、徽记、按钮直接坐在槽底上，字是墨色（槽 tone light）。相邻两件之间一枚铜点（`hud_dot.png` 10 × 10，竖直居中于槽，y 40）。
- 倒计时 = **刻在槽底的半圆日晷**（104 × 52，晷心 (52, 46)，半径 40，放在栏正中、晷心 y 63）：渗色扇面（代码画）→ `dial_face.png`（刻线、半圆弧、底线）→ `dial_shadow_<阶段>.png`（深色实心刻凿楔形影子，绕晷心转）→ `dial_hub.png`（晷心小太阳）。**栏上没有任何数字。**
- 鼠标停在日晷上弹悬浮窗（170 的深色皮面加铜框）：标题「倒计时」；「还剩 **N** 步（共 M 步）」，N 随阶段变色；有限时撤离点时再一行「最近的撤离点还剩 **N** 步关闭」（关了写「最近的撤离点已关闭」）。

## 2. 美术文件进仓库

| 美术的 | 仓库里 | 读法 |
|---|---|---|
| `out/hud_groove.png` + `.json` | `assets/ui/hud/groove.png` + `groove.json`（`{"margin": [40,0,40,0], "band": [12, 68], "tone": "light"}`，`band` 是我加的：槽身的竖向范围） | `UiTheme.art_cached("hud/groove")` + `art_meta` |
| `out/hud_dot.png` | `assets/ui/hud/dot.png` | `art_cached` |
| `out/dial_face.png` / `dial_hub.png` / `dial_shadow_{calm,half,low}.png` | `assets/ui/hud/dial/{face,hub,shadow_calm,shadow_half,shadow_low}.png` | `art_cached("hud/dial/face")` … |
| `out/dial.json` | `assets/ui/hud/dial/dial.json`（原样：pivot、radius、stages.wash、wash_opacity） | `UiTheme.art_meta("hud/dial/dial")` |
| `out/@2x/*` | 先不进仓库（现在没有 HiDPI 通路），留在 project-files | — |

贴图走 `UiTheme.art_cached`（自画必须用它，不然白块）。`.import` 由编辑器生成一次提交。

## 3. 代码改动

### 3.1 栏（`ui/hud/widgets/hud_bar.gd`、`ui/hud/hud_host.gd`）

- `hud_bar` 加一个 `NinePatchRect` 子节点 `_groove`（`mouse_filter` IGNORE，patch 边距读 `groove.json`，`Rect2(GROOVE_SIDE 14, 0, size.x − 28, size.y)`，整张 88 高贴满栏高；栏高不是 88 时按比例缩 band）。没有 `hud/groove` 图 → 不建，栏里的件退回现在的凹槽底（§3.2）。
- 铜点：`hud_bar._draw()` 画。宿主排完（`arranged`）后，栏把同一槽同一行里**相邻两件**之间的中点各画一枚 `dot`（y = band 中线）；右槽的图标按钮（`HudPartWidget`）之间不画，整组左边画一枚（样张如此）。`HudHost` 栏内行距 `GAP 6` → `BAR_GAP 24`（给铜点留位），只对 `in_bar` 的组生效。
- `HudHost._bar_margins()`：有槽图时返回 `band`（12 / 88 − 68 = 20），没有照旧读 `slab_bar` 的上下边距 —— 栏里的组从此在**槽身**里竖向居中（现在是在板面 8–62 里居中，会和槽差 5 px）。
- `HudWidget` 加 `bar_nudge() -> Vector2`（默认零）：排进栏时在居中之后再挪这么多；日晷返回 `(0, 3)`，晷心正好落在 y 63。

### 3.2 栏里的件去底（`ui/hud/hud_widget.gd`）

- `HudWidget.in_bar: bool`，宿主排进 `bar_*` 槽时置 true、拖出栏时置 false（`arrange()` / `drop()` 里设）。
- `in_bar and 栏有槽图` → `theme_type_variation = UiTheme.PANEL_BARE` + `apply_tone(PANEL_HUD_BAR)`（浅底墨字）；否则 `PANEL_HUD`（现在的刻槽，深底亮字）。`set_tier` / `refresh` 不动。
- 字色：`LabelHud*` 变体按 tone 取色已经通；货币、信仰的数字在样张里是墨色，和 `apply_tone` 一致。

### 3.3 日晷（`ui/hud/widgets/countdown_widget.gd` 重写）

```
const SIZE := Vector2(104, 52)          # dial.json 没写尺寸，按 face 图
var _meta := UiTheme.art_meta("hud/dial/dial")   # pivot [52,46] radius 40 stages wash_opacity
```

- 不用 `StyleBoxFlat`、不写字：`_text.visible = false`，`theme_type_variation = PANEL_BARE`。`text_of()` 返回「倒计时」只为 `has_content` / 显隐（和 `hud_bar` 一样），没有倒计时的章仍返回空串。最小尺寸 = `SIZE × scale`，`scale` = 1（LARGE / DOUBLE）或 0.5（SMALL）。
- 几何：`used = 1 − left / limit`；`angle = 180° − 180° × used`（180° = 左端、0° = 右端，影子从左往右扫）；影子图朝正上（90°），所以 `rotation = deg_to_rad(90 − angle)`（Godot y 朝下，正角顺时针）。
- 阶段 `stage() -> StringName`：`calm` 剩余 > 1/2；`half` ≤ 1/2；`low` < 1/4 **或 left ≤ 5**（沿用现在 `color()` 的五步规矩）。`color()` 留着（calm → FG、half → STAMINA、low → HP），测试与别处不改。
- `_draw()`（先 `super()` 画摆读数的虚线框）：
  1. 扇面：`draw_colored_polygon` 从 180° 扫到 `angle`，半径 40，圆心 pivot，颜色 `stages[stage].wash` × `wash_opacity 0.16`（`Color(wash, 0.16)`）；
  2. `face`：`draw_texture_rect(face, Rect2(0, 0, SIZE))`；
  3. 影子：`draw_set_transform(pivot, rotation, Vector2.ONE)` → `draw_texture_rect(shadow_<stage>, Rect2(−pivot, SIZE))` → `draw_set_transform(Vector2.ZERO)`（影子图和 face 同画布、同轴点）；
  4. `hub`。
  缺任何一张 → 退回现在的文字版（原 `text_of` 的「倒计时 N / M」+ 边框色），不画白块。
- 刷新：`watch()` 照旧 `[run.stepped, run.phase_changed]`；`refresh()` 末尾 `queue_redraw()`，悬浮窗开着就 `tip.update_text(tooltip_bbcode())`（185 补充一的接口）。
- 悬浮窗：`_idle_mouse_filter()` STOP（信仰件同款）；`mouse_entered` → `screen._tip.show_item({"head": 「倒计时」（NAME_SIZE，tip_fg）, "body": tooltip_bbcode()}, global_position + (0, size.y))`，`mouse_exited` → `release()`。
  ```
  tooltip_bbcode():
    还剩 [N] 步（共 [M] 步）        N：calm → @val，half → @stamina，low → @hp；M → @val
    最近的撤离点还剩 [K] 步关闭      K 同 N 的颜色；K = left − PaidExtracts.closes_at(node)；关了：「最近的撤离点已关闭」（@dim）；没有限时撤离点不写
  ```
  美术 README 里的 `#e0a85c` / `#ff7a5c` 只是参照，BBCode 里不写十六进制（188 的规矩），走 `stamina` / `hp` 样式。
- `title()` 仍「倒计时」；`tooltip_text()` 给测试读。

### 3.4 布局

默认布局不变（倒计时仍 `bar_center` / `large`），`HudLayout.VERSION` 不动。拖出栏的日晷自己带 `PANEL_HUD` 刻槽底（§3.2），大小不变。

### 3.5 没动的

186 的提示行、调试台箭头、腰带、图例；`CountdownModule`；地图上撤离点的关闭标记（仍由地图屏画）。

## 4. 测试（`tests/ui/test_hud_189.gd`，`test_hud_150` 第 193 行改读 `stage()`）

1. 栏：有槽图时 `hud_bar` 下有 `NinePatchRect`，宽 = 栏宽 − 28、高 = 栏高；左槽三件之间 2 枚铜点、右槽组左边 1 枚（数 `_dots.size()`）；栏里相邻两件间距 ≥ 24。
2. 栏里的 `wallet` 的 `panel` 样式是 `PANEL_BARE` 的、字色是墨；摆读数拖出栏后回 `PANEL_HUD`。
3. 栏内组竖向居中在 band（12–68）里：`vitality` 中线 ≈ 40 ± 1；日晷晷心 y ≈ 63 ± 1。
4. 日晷：`stage()` 77/90 → calm、40/90 → half、15/90 → low、left 5（90）→ low；`angle` 77/90 ≈ 154°；没有 `Label` 可见、`text()` 不含数字。
5. 悬浮窗：悬停后 `tip.text()` 含「还剩 40 步（共 90 步）」「最近的撤离点还剩 12 步关闭」，撤离点关了含「已关闭」，没有限时撤离点只有一行；走一步后开着的窗文字跟着变；BBCode 无十六进制。
6. 缺 `hud/dial/face` 时退回文字版且不报错；缺 `hud/groove` 时栏里的件仍是 `PANEL_HUD`。
7. 截图 1600 × 1000 对照 `preview_G.png`（`/mnt/project-files/screenshots/189/`）。

## 5. 待定（默认按推荐）

1. **小档日晷** —— 推荐 **甲**：同一套图缩到 0.5（52 × 26）。乙：小档仍画文字版。
2. **铜点规则** —— 推荐 **甲**：同槽相邻两件之间 + 右槽图标组左边一枚（照样张）。乙：只在两件之间，右槽不加。
3. **槽身范围** —— 推荐 **甲**：`groove.json` 写 `band`，宿主按它居中。乙：改 `slab_bar.json` 的上下边距成 12 / 20（会动所有读 `slab_bar` 的地方）。
