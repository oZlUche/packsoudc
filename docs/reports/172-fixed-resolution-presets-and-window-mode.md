# 172 · 固定分辨率档位与窗口模式（主菜单设置 / Esc 暂停菜单设置）

> 作者 2026-10-14 15:23：「给游戏设计固定分辨率大小，市面主流的几种，可以在主菜单的设置和 esc 菜单设置里面调整」。性质：架构 · 实施。待定按推荐。关联 090（暂停菜单嵌设置屏）、109（偏好放 `GameSettings`）、128（地面坐标归一化）、154 补充一（改键表）、157（换屏淡入、光标材质——同一块设置屏）。

## 1. 现状

- `project.godot`：设计视口 **1600×1000**（16:10），`window/stretch/mode = canvas_items`、`aspect = expand`。没有任何窗口模式 / 分辨率设置，代码里**没有一处** `DisplayServer` / `get_window()` 调用——窗口大小就是引擎默认（视口尺寸），玩家能随手拖边框，界面跟着拉伸。
- 设置屏 `ui/game/settings_screen.gd` 一块石板上的若干节（战利品 / 地图 / 背景底色 / 老手 / 调试 / 开发）；主菜单的「设置」进它独立一屏，地图 Esc 暂停菜单的「设置」把同一屏**嵌进遮罩**（090：`SettingsScreen.back` 给了就「返回」回暂停菜单）。所以分辨率一节只做一处，两个入口都有。
- 偏好都在 `GameSettings`（`user://settings.json`，版本 1，未知键不读、缺键用默认）。

## 2. 方案

### 2.1 档位表（市面主流，两种宽高比）

常量 `WindowSetup.PRESETS: Array[Vector2i]`，按宽高比分两组，组内从小到大：

| 比例 | 档位 |
|---|---|
| 16:9 | 1280×720、1600×900、1920×1080、2560×1440、3840×2160 |
| 16:10 | 1280×800、1920×1200、2560×1600 |

- 设计视口仍是 1600×1000，`canvas_items + expand` 不动：换档只是换**窗口尺寸**，界面按高度等比缩放，16:9 的档位左右多露出一点场（现在拖窗口也是这样，布局全是锚点，128 的地面坐标已归一化）。
- **比屏幕大的档位不列**（`DisplayServer.screen_get_size()`，按窗口所在屏）。超宽屏（21:9）不列专档（待定 1）。
- 窗口**不可拖改**：`window/size/resizable = false`（这就是「固定」）；全屏时无所谓。

### 2.2 窗口模式

`GameSettings.window_mode: String`，`"windowed"` / `"fullscreen"`。全屏用 `Window.MODE_FULLSCREEN`（无边框铺满桌面，桌面分辨率，切 Alt-Tab 不黑屏），不用独占全屏。全屏时分辨率一行**灰掉**并注一句「全屏按桌面分辨率」；切回窗口时恢复上次选的档。

### 2.3 设置字段与归一化

```gdscript
## 172：窗口模式 "windowed" / "fullscreen"；分辨率是 PRESETS 里的一档（Vector2i）
var window_mode: String = "windowed"
var resolution: Vector2i = Vector2i.ZERO     # ZERO = 没定过，启动时按屏幕挑（2.4）
```

- 文件里写 `"resolution": [1920, 1080]`、`"window_mode": "windowed"`；`from_dict` 认不出的模式回 `"windowed"`，不在 `PRESETS` 里的尺寸回 `ZERO`（启动时重挑）。版本号不升（缺键用默认，和 109 一样）。
- 设置层只存；哪档能选、怎么套到窗口上是界面的事（101 第 5 刀的分工）。

### 2.4 套到窗口上：`ui/window_setup.gd`（新，`class_name WindowSetup`）

```gdscript
static func apply(settings: GameSettings, window: Window) -> void
static func pick_default(screen: Vector2i) -> Vector2i
static func fits(preset: Vector2i, screen: Vector2i) -> bool
static func available(screen: Vector2i) -> Array[Vector2i]
```

- `apply`：`DisplayServer.get_name() == "headless"` 直接返回（测试、导入进程不碰窗口）。全屏 → `window.mode = MODE_FULLSCREEN`。窗口 → `mode = MODE_WINDOWED`、`unresizable = true`、`size = resolution`，然后**居中**到所在屏（`screen_get_position + (screen_get_size − size) / 2`）。`resolution == ZERO` 时先 `pick_default` 并写回设置、存盘。
- `pick_default(screen)`：取 `PRESETS` 里**面积最大、且宽高都 ≤ 屏幕的九成**的那档（留出标题栏与任务栏）；一档都放不下（屏幕比 1280×720 还小）就用屏幕尺寸本身（不进列表，设置里显示成「随屏幕」）。例：1920×1080 屏 → 1600×900；2560×1440 屏 → 1920×1200（面积最大且放得下）；1366×768 屏 → 1280×720。
- 调用点：`game_director._ready` 读完设置、`UiCursor.apply` 之后加一行 `WindowSetup.apply(flow.settings, get_window())`；设置屏改一下就再调一次（当场生效 + 存盘，和这块屏其他项一样）。开发启动器（`ui/launcher.gd`）和编辑器场景不调——它们不是玩家看的。

### 2.5 设置屏新一节「显示」（放在最上面）

- 「窗口」一行两个按钮：**窗口** / **全屏**（`toggle_mode`，同光标材质那行的做法）。
- 「分辨率」两行按钮，行首小字标比例（`16:9` / `16:10`），每档一个按钮，文字就是 `宽×高`（分辨率数字是行业写法，不套「玩家文案不写阿拉伯数字」的规矩）。只画 `available(screen)` 里的档；当前档按下。全屏时整块 `disabled`，底下一行注「全屏按桌面分辨率」。
- 改动当场套用（`WindowSetup.apply`）并存盘。嵌在暂停菜单里时同样生效：遮罩与石板都是全矩形锚点，窗口一变自己重排；地图的 `map_zoom` 不动（128 的归一化坐标保证地上的东西还在屏里）。
- 快捷键：新动作 `toggle_fullscreen`，默认 **F11**，`InputKeys.ACTIONS` 收进去（154 补充一的改键表就能改它）；按一下切模式并写设置（待定 2）。

### 2.6 `project.godot`

```
window/size/viewport_width=1600
window/size/viewport_height=1000
window/size/resizable=false
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

不写 `window_width_override`：启动尺寸由 `WindowSetup.apply` 按设置定，首帧前就套上（`_ready` 里），不会先闪一下 1600×1000。

## 3. 测试

- `GameSettings`：`[1920,1080]` 读回 `Vector2i(1920,1080)`；`[1234,567]` 回 `ZERO`；`"window_mode": "exclusive"` 回 `"windowed"`；写出再读回一致；旧文件没这两个键 → 默认。
- `WindowSetup.pick_default`：1920×1080 → 1600×900；2560×1440 → 1920×1200；1366×768 → 1280×720；1024×600 → 1024×600（随屏幕）。`available(1920×1080)` 不含 2560 以上任何一档；`available(3840×2160)` 全列。
- 设置屏：窗口模式切到全屏后分辨率按钮全 `disabled`；切回后恢复按下状态；每个按钮文字形如 `1920×1080`。headless 下 `apply` 不报错不动窗口（现有全套测试照跑）。

## 4. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 超宽屏（21:9，如 2560×1080、3440×1440） | A 不列专档，超宽屏玩家用 16:9 档或全屏（全屏时左右多露场）；B 列两档 | **A**：布局没按 21:9 校过，先不开 |
| 2 | 全屏快捷键 | A 加 `toggle_fullscreen`（F11，可改键）；B 只在设置里切 | **A**：PC 玩家的习惯 |
| 3 | 首次启动默认 | A 窗口，按 2.4 自动挑一档；B 全屏 | **A**：开发期截图、对照方便，发布前想改成 B 只改一处默认值 |
| 4 | 全屏种类 | A `MODE_FULLSCREEN`（无边框铺满）；B 独占全屏 | **A**：切窗口不黑屏，2D 游戏独占没收益 |

## 5. 改动范围

`project.godot`（resizable、新动作 `toggle_fullscreen`）、`core/settings/game_settings.gd`（两个字段 + 归一化）、`ui/window_setup.gd`（新）、`ui/input_keys.gd`（ACTIONS 加一项）、`ui/game/game_director.gd`（启动时套用、F11）、`ui/game/settings_screen.gd`（「显示」一节）、测试 `tests/settings/test_window_setup.gd`（新）、`docs/architecture.md` 设置一节补两句。不碰任何布局代码。
