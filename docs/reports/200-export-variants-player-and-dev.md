# 200 导出两种版本：玩家版 / 开发版 —— 用导出预设而不是分支

作者问（2026-10-19 11:39）：「能否导出不同版本？比如一个没有控制台/编辑器的版本，还是说要单独建立一个分支？」

**结论：不要建分支。** 同一份代码、同一个 `export_presets.cfg` 里放两个预设就够了：代码按 `OS.has_feature()` 看自己在哪个版本里，预设决定模板（debug / release）、特性标签、控制台包装器、打包过滤。分支的做法会让两份代码越走越远，每个修复要合两遍；Godot 的导出预设就是为「一份代码、多种包」设计的。

## 1 现状

### 1.1 代码里已经有门，但有两把

| 门 | 判断 | 管什么 |
|---|---|---|
| `DevGate.on()`（core/dev_gate.gd:12，186） | `not force_player and not OS.has_feature("template")` | 调试台、设置里的调试节、地图 / 基地调试绘制、`GameSettings.dev_build()`、meta_screen 的开发开关 |
| `DevNav.keep_in()`（ui/dev_nav.gd:45，176 待定 3 选 A） | `OS.has_feature("editor") or OS.is_debug_build()` | F1 启动器 / 开发期导航（自动加载，不保留就 `queue_free`） |

两把门对导出包的回答不一致：

| 跑法 | `template` | `is_debug_build` | 调试台（DevGate） | 启动器（DevNav） |
|---|---|---|---|---|
| 编辑器 / 命令行 | 否 | 是 | 有 | 有 |
| 导出 · debug 模板 | 是 | 是 | **无** | **有** |
| 导出 · release 模板 | 是 | 否 | 无 | 无 |

也就是说**现在用 release 模板导出，出来的就已经是玩家版**：没有调试台、没有启动器、没有编辑器（编辑器本来就不会进导出包）。作者问的「没有控制台 / 编辑器的版本」今天就能导，只是没有一个明确叫「玩家版」的预设，而 debug 导出又是个「有启动器没调试台」的半吊子。

### 1.2 `export_presets.cfg` 只有一个预设

`[preset.0]` "Windows Desktop"：`runnable=true`、`custom_features=""`、`export_filter="all_resources"`、`include_filter="*.json, *.txt"`、`exclude_filter=""`、`export_path="build/packsoudc.exe"`、`script_export_mode=2`（176 §3.3 的二进制令牌，`tests/tools/test_startup_graph.gd:146` 对**每个**预设断言这一项）；`debug/export_console_wrapper=1`。

关于「控制台」要分清三样东西：

1. **Windows 控制台窗口 / `packsoudc.console.exe`**：由 `debug/export_console_wrapper` 决定。Godot 4 这一项是三选一：0 = 不出、1 = 只在 debug 导出时出、2 = debug 和 release 都出。现在是 1，所以 release 导出本来就没有 `.console.exe`，debug 导出会多一个。
2. **游戏里的调试台 / 开发工具**：`DevGate` 管，见 1.1。
3. **Godot 编辑器**：永远不在导出包里；作者说的「编辑器」我理解为游戏内的开发期工具（启动器、调试台、各 `ui/*_editor`），下面按这个理解写。

### 1.3 现在的包里带了不该带的东西

`export_filter="all_resources"` 会把项目里所有「资源」打进 pck，`include_filter` 再补上所有 json / txt。于是：

| 目录 | 体积 | 会不会进包 | 游戏运行时要不要 |
|---|---|---|---|
| `tests/` | 3.4 MB（.gd + 14 个 json/txt） | 进 | 不要。`ContentSnapshot.PATH` 指向 `tests/fixtures/content_snapshot.json`，但只有测试调它；`UiTheme.asset_root` 指到 `tests/fixtures/ui/` 也只在测试里 |
| `addons/godot_ai/` | 2.8 MB | 进 | 不要。编辑器插件，`project.godot` 没启用它，游戏代码不引用 |
| `docs/reports/images/` | 20 张 png | 进（被导入成贴图） | 不要 |
| `tools/` | 252 KB | 进 | **要留**：`ui/dev_nav.gd:35-36` `preload` 了 `tools/class_cache.gd` 和 `tools/import_check.gd`；`DevNav` 是自动加载，这两个文件不在包里它整个脚本都解析不了，开机就报错。`game_director.gd:313` 还会在设了 `DEMO_SCREEN` 时 `load("res://tools/demo_fill.gd")`（没设就不碰） |
| `data/` | 3.8 MB json | 进 | 要（作者数据） |

多出来的约 6 MB 对 62 MB 的美术不算大，但 `tests/` 里的脚本会被编译进包（176 做过启动图扫描，就是为了别让没用的脚本拖启动）。

## 2 方案

### 2.1 两个预设，一份 cfg

| | 玩家版 `[preset.0]` | 开发版 `[preset.1]` |
|---|---|---|
| `name` | `"玩家版"` | `"开发版"` |
| `runnable` | `true`（编辑器右上角「运行导出」用它） | `false` |
| 模板 | **release**（`godot --headless --export-release "玩家版"`） | **debug**（`--export-debug "开发版"`） |
| `custom_features` | `""` | `"dev"` |
| `debug/export_console_wrapper` | `0`（明确：不出 `.console.exe`） | `1`（debug 导出带控制台窗口，看 `print` / 报错） |
| `exclude_filter` | `"tests/*, addons/godot_ai/*, docs/*"` | 同左（开发版也不需要测试和文档；测试从编辑器 / 命令行跑） |
| `export_path` | `"build/packsoudc.exe"` | `"build/dev/packsoudc.exe"` |
| `script_export_mode` | `2` | `2`（测试对每个预设都查） |
| 其余 `[preset.N.options]` | 照抄现在的 | 照抄现在的 |

`tools/` 两边都不排除（1.3 的 preload 原因）。想排也行：把 `dev_nav.gd` 那两个 `preload` 改成 `keep_in` 判断之后再 `load()`，然后玩家版加 `tools/*` —— 省 252 KB，不值当，列为待定 1。

### 2.2 一把门：`DevGate` 认 `dev` 特性

```gdscript
static func on() -> bool:
	if force_player:
		return false
	return not OS.has_feature("template") or OS.has_feature("dev")
```

- 编辑器 / 命令行：开（和现在一样）。
- 玩家版（release，无 `dev`）：关。
- 开发版（debug + `dev`）：开 —— 调试台、设置调试节、meta_screen 开发开关在导出的开发版里都回来了，1.1 那个半吊子消失。
- `DevNav.keep_in(editor, debug)` 改成读 `DevGate.on()`（保留一个带参数的形态给现有测试用，或者把测试改成拨 `DevGate.force_player`）。效果：开发版有启动器，玩家版没有，和 176 待定 3 的本意一致；唯一变化是「debug 模板但没 `dev` 特性」的包也没有启动器了，这种包我们不出。
- 其余四处 `OS.has_feature("template")` **不动**，它们问的不是「开发还是玩家」而是「在不在导出包里」：`hud_layout.gd:115`（布局存 user:// 还是存仓库 —— 导出包里 res:// 不可写）、`dev_nav.gd:174`（导出包的类缓存永远是对的）、`meta_screen.gd:306/358`（这两处其实是开发开关，顺手改成 `DevGate.on()`，186 的「一把门」就彻底了）。

### 2.3 怎么导

编辑器：项目 → 导出 → 选「玩家版」或「开发版」→ 导出项目（玩家版记得勾 release，开发版勾 debug）。命令行（作者机器上的 Godot 可执行文件）：

```
godot --headless --export-release "玩家版" build/packsoudc.exe
godot --headless --export-debug  "开发版" build/dev/packsoudc.exe
```

两条命令可以放进一个 `tools/export.bat` / `tools/export.sh`，待定 2。

## 3 改动清单

- `export_presets.cfg`：`[preset.0]` 改名「玩家版」+ 控制台包装器 0 + 排除过滤；新增 `[preset.1]`「开发版」（整段复制 options，改 1.3 / 2.1 表里的几项）。
- `core/dev_gate.gd`：`on()` 加 `OS.has_feature("dev")`，文件头注释补「开发版导出带 `dev` 特性」。
- `ui/dev_nav.gd`：`_ready` 改走 `DevGate.on()`；`keep_in` 的测试相应调整。
- `ui/game/meta_screen.gd:306/358`：两处 `not OS.has_feature("template")` → `DevGate.on()`。
- 测试：`tests/tools/test_startup_graph.gd` 现有断言对两个预设都成立即可；加一条读 cfg 的断言：玩家版 `custom_features` 不含 `dev`、`exclude_filter` 含 `tests/*`；开发版含 `dev`。`DevGate` 的测试加 `force_player` 优先于一切的用例（已有就不加）。
- `docs/architecture.md`（若有导出 / 开发工具一节）补一句两个预设的说明。

## 4 待定

1. **玩家版要不要连 `tools/*` 也排除**（要改 `dev_nav.gd` 两处 preload 为 `load()`）。推荐：不排除，252 KB 不值得多一处可能开机报错的地方。
2. **要不要加 `tools/export.sh` / `.bat`** 把两条导出命令固定下来。推荐：加一个 `.bat`（作者在 Windows 上导），内容就是 2.3 的两行加 `mkdir build\dev`。
3. **开发版的 `exclude_filter` 是否和玩家版一样**。推荐：一样；谁要跑测试都从编辑器或 `tools/test.sh` 跑，不会拿导出包跑。

## 5 不做的

- 不加密、不内嵌 pck、不做 Linux / Mac 预设 —— 作者没问，和这题无关。
- 不新建分支、不加编译开关宏。GDScript 没有预处理器，`OS.has_feature()` 就是它的 `#ifdef`。

## 6 落地（2026-10-19，架构方案执行）

按 §3 改动清单与 §4 推荐全做：

- `export_presets.cfg`：`[preset.0]`「玩家版」（runnable、`custom_features=""`、`debug/export_console_wrapper=0`、`exclude_filter="tests/*, addons/godot_ai/*, docs/*"`、`build/packsoudc.exe`）；`[preset.1]`「开发版」（`runnable=false`、`custom_features="dev"`、包装器 1、同样的排除、`build/dev/packsoudc.exe`）。options 段整段照抄，两个都是 `script_export_mode=2`。`tools/` 不排除。
- `core/dev_gate.gd`：`on()` = `not force_player and (not template or dev)`。
- `ui/dev_nav.gd`：`keep_in()` 改成无参数、直接返回 `DevGate.on()`，`_ready` 走它。**和方案的差别**：`dev_nav.gd` 有规矩「不许按类名引用任何全局类」（115：类缓存坏着它也得能解析），所以没写 `DevGate.on()`，而是 `const DevGateScript := preload("res://core/dev_gate.gd")` 按路径拿同一个脚本；`force_player` 是同一个静态变量，测试拨它两边一起变。
- `ui/game/meta_screen.gd` 两处开发开关 → `DevGate.on()`；`tests/ui/test_base_drawer_139.gd` 里照抄的那一处判断也跟着改。`hud_layout.gd:115`、`dev_nav.gd` 类缓存自检的 `template` 判断没动。
- `tools/export.bat`：先 `chcp 65001`（预设名是中文，cmd 默认代码页会把参数读坏），`mkdir build\dev`，再 `--export-release "玩家版"`、`--export-debug "开发版"`；`GODOT` 变量默认值同 `run_game.bat`。需要先装 4.7.1 导出模板。
- 测试：`tests/tools/test_startup_graph.gd` 的导出一节加 8 条 —— 两个预设都在；玩家版不带 `dev`、开发版带；两者都排除 `tests/*`、都不排除 `tools/`；玩家版包装器 0；「运行导出」用玩家版；`keep_in()` 开发包留、`force_player` 时撤。
- 没验证的：云端没有导出模板，两条导出命令没实际跑过；作者在本机导一次、看玩家版没有 F1 启动器和调试台、开发版都有即可。

