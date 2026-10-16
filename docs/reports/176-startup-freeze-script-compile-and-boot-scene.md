# 176 · 启动卡住一段时间：量在哪、是不是架构太复杂、怎么改

> 作者 2026-10-16 13:20：「现在游戏启动时会卡住一段时间（无响应），是否因为架构设计太复杂了导致的？」性质：架构 · 诊断 + 实施（启动流程，不碰玩法）。承接 158（那次是「拉了新代码后第一次慢半分钟」，原因是起编辑器子进程重建类缓存，已落地）。待定按推荐。

## 1. 量到的（本机 headless，Godot 4.7.1，main 63f7b10）

| 段 | 耗时 | 怎么量 |
|---|---|---|
| 引擎自己起来（空脚本到 `_init`） | 0.12 s | `--script` 一个只 `quit()` 的脚本 |
| **载入 `game_director.gd` 及其引用到的全部脚本** | **≈ 2.0 s** | `load("res://ui/game/game_director.gd")` 前后计时 |
| `_ready` 里的内容加载（道具 / 敌人 / 事件 / 章节 / 百科 / 主题……） | ≈ 0.5 s | 逐步计时；最大一项 `ItemDatabase.load_dir` 0.28 s，`UiTheme.install` 0.04 s |
| 主场景 `game.tscn` 跑到第一帧退出 | ≈ 3.0 s | `--quit-after 1` 三次 2.8–3.4 s |
| 全量 `--import`（素材变了才跑） | 15 s | 158 已改成后台、只在缺素材时跑 |

代码量：`core/` + `ui/` 共 **706 个 .gd、6.8 万行、477 个 `class_name`**。`ui/` 2.6 万行、`core/run` 1.3 万、`core/battle` 0.8 万、`core/authoring`（导入 / 导出 / 表格工具）0.5 万、各编辑器 `ui/*_editor` 合计约 0.6 万。

## 2. 结论：和「架构复杂」有关，但不是玩法架构，是**脚本体量 + 全部在启动时编译**

- GDScript 没有预编译：每次启动，引擎把主场景脚本**引用到的每一个全局类**从源码解析、编译一遍，再碰它们引用的，直到整张图。`game_director.gd` 的图几乎就是整个项目（477 个全局类里绝大多数），所以第一帧之前要先编译 6 万多行 —— 本机 2 秒，Windows 上每个 `.gd` 的读取还要过杀毒软件，再加 D3D12 第一帧编译着色器管线（158 提过「每次启动都慢才是它」），**三到八秒的「无响应」是合理的**。窗口先出来再卡，也对得上：窗口由引擎建，之后才载主场景。
- 反应 / 铸炉 / 法杖这些机制本身**不是**原因：`core/battle` 整个只占八分之一，175 系列加的代码不到两千行；内容加载 0.5 秒也不是大头。规则引擎是按场战斗跑的，启动时一行都不执行。
- 真正「复杂」的是：**游戏进程把编辑器和导入器也编译了**。`ContentLibrary.context()` 引用 `ContentImporter`，游戏运行时根本不导入 json（读的是 `.tres`），但这一个引用把 `core/authoring` 五千行拖进了启动图；`DevNav` 自动加载是开发期导航，正式游戏也带着。
- 158 的「拉代码后半分钟」是另一条路，已经好了；这次是**每次**都卡的那两三秒（Windows 上更久）。

## 3. 改法（三件，按收益排）

### 3.1 启动屏 + 后台载主场景（把「无响应」变成「看得见的加载」）

- 新主场景 `ui/boot.tscn` + `ui/boot.gd`：**不引用任何全局类**（不写 `class_name`，不碰 `UiPalette` 等；字体用 `load()` 路径、底色写死），只画游戏名和一条进度，第一帧 0.2 秒内出来。
- `ResourceLoader.load_threaded_request("res://ui/game/game.tscn")`，每帧 `load_threaded_get_status` 更新进度，好了 `change_scene_to_packed`。脚本编译在后台线程，主线程照常刷新 —— 窗口不再「无响应」，总时长不变。
- `game_director._ready` 的内容加载 0.5 秒留在主线程（它改资源与全局状态，不值得多线程化）；进度条到 100% 后黑一下 0.5 秒可接受，想更平就把 `ItemDatabase.load_dir` 也挪进那个线程（待定 2）。
- 风险：4.x 的线程载脚本早期有过全局类解析问题，4.7 稳；测试里 headless 下 `load_threaded_request` 一样能跑。`run/main_scene` 改成 boot；`DevNav` 的 F1 回启动器逻辑不变。

### 3.2 把开发工具从游戏的启动图里摘出去

- `ContentLibrary.context()` 只给编辑器用：挪到 `core/authoring/authoring_context.gd`（编辑器 `load()` 它），`ContentLibrary` 不再写 `ContentImporter` 这个名字。导出器 / 表格工具同样检查，游戏侧不得静态引用 `core/authoring` 里除 `ContentPaths` / `ContentLibrary` 之外的类。
- `DevNav`（自动加载）：正式导出里不该有。`project.godot` 保留，但它自己首行 `if not OS.has_feature("editor") and not OS.is_debug_build(): queue_free(); return`，且**不在类成员里引用**启动器 / 编辑器类（用路径字符串 `load()`）。
- 加一条脚本测试 `tests/tools/test_startup_graph.gd`：从 `game_director.gd` 出发按 `class_name` 引用做可达性扫描（158 的 `tools/class_cache.gd` 已经会解析脚本头，复用它的扫描），断言 `ui/*_editor`、`core/authoring/content_importer.gd`、`content_exporter.gd` 不可达。预计砍掉启动图一成到两成。

### 3.3 导出版用二进制脚本

- `export_presets.cfg` 的 GDScript 导出模式改 **二进制令牌（压缩）**：导出包里脚本不再是源码文本，解析快数倍，发给别人的版本启动明显快。开发期从编辑器跑不受益，这就是为什么 3.1 仍然要做。
- 顺带 158 没动的那条：渲染器。2D 游戏用 Forward+ / D3D12 没有收益，每次启动多一段管线编译；改 `gl_compatibility` 一行设置即可，但要作者先在自己机器上试（待定 1）。

## 4. 作者可以两分钟做的对照（帮我们定渲染器那条）

1. 用命令行加 `--rendering-method gl_compatibility` 启动一次、再加 `--rendering-driver vulkan` 启动一次，和现在比卡顿长短。短了一半以上 → 待定 1 选 A。
2. 看卡顿是在**窗口出现之前**（引擎 / 显卡驱动）还是**窗口出来之后白屏不响应**（脚本编译 + 内容加载 = 本文第 2 节）。按现在的量法，大头应在后者。

## 5. 测试

boot 场景不引用全局类（扫描断言）；`load_threaded_request` 在 headless 完成并切到 game.tscn；启动图可达性测试；导出预设里脚本模式为二进制令牌（读 cfg 断言）；现有全套测试照跑（主场景换了，`tests/run_tests.gd` 不依赖 main_scene）。

## 6. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 渲染器 | A 改 `gl_compatibility`（2D 够用、启动快、老机器兼容）；B 留 Forward+ / D3D12 | **A**，但等作者第 4 节对照后再定 —— 这条换了会影响所有画面（抗锯齿、HDR 不可用），不该我替作者拍 |
| 2 | 内容加载也进后台线程 | A 只线程化场景与脚本载入；B 连 `ItemDatabase.load_dir` 一起 | **A**：0.5 秒不值得引入多线程改资源的风险 |
| 3 | DevNav 在正式版 | A 自卸载；B 保留（F1 回启动器） | **A**：玩家不该按出启动器 |

## 7. 改动范围

`ui/boot.tscn` / `ui/boot.gd`（新）、`project.godot`（main_scene、可选渲染器）、`core/authoring/content_library.gd`（摘掉 context）+ `authoring_context.gd`（新）、编辑器几处改 `load()`、`ui/dev_nav.gd`（自卸载 + 去静态引用）、`export_presets.cfg`、`tests/tools/test_startup_graph.gd`（新）、`docs/architecture.md` 启动一节。

## 8. 落地记录（v3.12，3.1–3.3；待定 2A、3A，待定 1 未动）

- **启动屏**：`ui/boot.tscn` + `ui/boot.gd`，`run/main_scene` 换成它。画游戏名（朱雀仿宋）、一条进度和「载入中……」，载失败改写「载入失败，请重启游戏」。`start()` 发 `load_threaded_request`，`_process` 每帧 `poll()`，载好下一帧 `change_scene_to_packed`；`auto_switch` 关掉只载不切（测试用）。本机虚拟屏实测：第 3 帧（0.3 秒）启动屏已出来，之后主线程一直在刷新，软件渲染下约 4.7 秒切到主菜单。截图 `/mnt/project-files/screenshots/176/boot-screen.png`。
- **启动图**：`ContentLibrary.context()` 挪到 `core/authoring/authoring_context.gd`（无 `class_name`，七个编辑器与三个测试 `preload` 它）。按测试的扫法，游戏启动时静态碰得到的脚本从 300 个（约 4.1 万行）降到 263 个（约 3.6 万行）：导入器、导出器、`techs_table` / `xlsx_reader` / `text_lint` / `content_check` / `power_estimate` / `import_report` 都出去了。剩在图里的 `core/authoring` 文件（`content_paths`、`content_schema`、`content_registries`、`field_text`、`id_aliases`、`content_library`）是游戏运行真用的。编辑器与启动器本来就不在图里（DevNav 按路径换场景）。
- **按量更正第 1 节**：「477 个全局类几乎都在启动图里」偏高 —— 按静态引用扫，启动图是 300 个脚本（全项目 706），2 秒的编译量在这 300 个里。
- **DevNav**：`keep_in(editor, debug)`；release 导出时 `_ready` 先停处理再 `queue_free()`。编辑器版 Godot 直接跑、debug 导出照旧在（F1、类缓存自救都不变）。
- **导出预设**：仓库原来没有 `export_presets.cfg`，新建一份 Windows Desktop 预设，`script_export_mode=2`（二进制令牌，压缩），导出到 `build/`（已在 .gitignore），`include_filter` 带上运行时读的 `*.json, *.txt`。作者本机若有自己的预设，以这份为准合并 `script_export_mode` 即可。
- **测试** `tests/tools/test_startup_graph.gd`：启动屏的图只有它自己；游戏图碰不到编辑器、启动器、导入器、导出器与表格工具（附引用链），编辑器那头碰得到导入器（证明扫法没漏）；启动屏后台载好 `game.tscn`、进度到 1；导出预设脚本模式；`DevNav.keep_in`。

> 作者 2026-10-16 14:09 对照后：「感觉区别不大」—— 渲染器换成 Compatibility 没有明显缩短卡顿。待定 1 定为 **B**（渲染器不动），卡顿按第 2 节归因于脚本编译与内容加载，3.1–3.3 照做。
