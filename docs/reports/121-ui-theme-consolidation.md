# 121 小修：把界面上散落的样式覆写收进一个 Godot `Theme`（换皮只换一处）

> 架构 · 小修（2026-10-03）。作者就「UI 逐步调还是整套换」定了方向：现在的界面当灰盒原型，**交互层留着逐步调、表现层将来整套换**；先做这一件铺路的事。

## 一、现状（已核实）

- 游戏界面全是代码搭的：`ui/` 59 个脚本，场景文件只有编辑器、沙盒、启动器和 `game.tscn` 这几个空壳。
- 颜色与字体来自 `UiPalette`（31 个常量 + `style_button(b, tier, size)` / `cjk_font()` / `bg()`），再由约 **300 处** `add_theme_*_override` 逐个控件贴上去。分布：编辑器一侧最多（`event_editor` 33、`buff_editor` 24、`content_editor` 21、`property_form` 17），游戏屏每个 9～14 处（`hover_tip` 14、`map_screen` 11、`battle_view` 11、`tech_panel` 9……）。
- 项目没有任何 `Theme` 资源，`project.godot` 没设默认主题，`game.tscn` 根节点也没挂。
- 背景底色是运行时设置（091，`GameSettings.bg_theme` → `UiPalette.apply`），字体是 `SystemFont` 挑系统 CJK 字体 —— 所以主题**不能是一份写死的 `.tres`**，得由代码按设置生成。

## 二、做法

### 2.1 一个代码生成的 `Theme`

`ui/ui_theme.gd`（`UiTheme`）：`static func build(settings: GameSettings) -> Theme`，把 `UiPalette` 的常量与 `cjk_font()` 填进一份 `Theme`：

| 主题里的项 | 来自 |
|---|---|
| 默认字体 / 字号 | `UiPalette.cjk_font()`、现在各处写的 14 / 16 |
| `Button` 三档：`ButtonPrimary` / `ButtonSecondary` / `ButtonDim`（**type variation**） | `style_button` 的三档 `_button_box` |
| `Label` 变体：`LabelTitle` / `LabelDim` / `LabelWarn` | 现在散落的 `font_color` 覆写里反复出现的那几种 |
| `PanelContainer` 变体：`PanelDark` / `PanelLine` | `PANEL` / `LINE` 的 `StyleBoxFlat` |
| `RichTextLabel` 默认色、`LineEdit` / `SpinBox` / `Tree` 的底与边 | 编辑器里反复贴的那几组 |

挂法：`GameFlow` 建根控件时 `root.theme = UiTheme.build(settings)`；背景色设置变了就重建一次再赋回去（`UiPalette.apply` 现在做的事挪进来）。启动器、沙盒根节点同样挂。

### 2.2 把覆写换成「选变体」

每处 `add_theme_*_override` 按三类处理：
- **是某个变体的** → 删覆写，写 `theme_type_variation = &"ButtonPrimary"`。`UiPalette.style_button` 退化成一行设变体，保留签名，调用方不改。
- **是画布绘制的颜色**（血条、格子、邻接标记、稀有度色、飘字）→ **不动**，这些不是 Theme 的事，继续读 `UiPalette` 常量。
- **真正一次性的特例** → 保留，但得在旁边注一句为什么。

先做游戏屏（`ui/game`、`ui/inventory`、`ui/battle`、`ui/launcher`），编辑器一侧（`ui/editor`、`ui/*_editor`）是开发工具，只挂主题、不逐处改。

### 2.3 挡住回潮

`tests/ui/test_theme.gd`：
1. `UiTheme.build` 出来的主题含上面列的全部变体；换一个 `bg_theme` 重建，`PanelDark` 的底色跟着变。
2. **棘轮**：扫 `ui/game`、`ui/inventory`、`ui/battle`、`ui/launcher*` 里 `add_theme_` 的出现次数，断言 ≤ 改完后的实际数（写死在测试里）；以后要加覆写就得先说服自己为什么不是变体。

## 三、将来整套换皮时

换的只是 `UiTheme.build` 的内容：改成加载美术给的 `.tres` Theme + 字体 + 贴图，屏幕脚本一行不动；按屏重做时新屏直接用变体名，不碰颜色值。`UiPalette` 留给画布绘制那一类。

## 四、改动点

| 文件 | 改动 |
|---|---|
| `ui/ui_theme.gd` 新 | `build(settings)` |
| `ui/ui_palette.gd` | `style_button` 改成设变体；`apply` 里重建主题 |
| `core/run/game_flow.gd`、`ui/launcher.gd`、两个沙盒 | 根节点挂主题 |
| `ui/game/*`、`ui/inventory/*`、`ui/battle/*` | 覆写 → 变体（预计删掉 100 处上下） |
| `tests/ui/test_theme.gd` 新 | §2.3 |
| `docs/architecture.md` 界面一节 | 一句：样式走 Theme 变体，画布色走 UiPalette |

## 五、待定（按推荐即执行）

| # | 问题 | 推荐 |
|---|---|---|
| 1 | 主题是代码生成还是 `.tres` 资源 | **代码生成**（背景色是运行时设置、字体是系统字体）；美术进场时再换成加载 `.tres` |
| 2 | 编辑器一侧要不要也逐处改 | **不改**，只挂主题；它们是开发工具 |
| 3 | 要不要棘轮测试 | **要**，不然三个月后又是 300 处 |
