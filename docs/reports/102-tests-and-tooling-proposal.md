# 102 · 方案：测试按模块归位、类缓存与 test.sh（097 的 P6 + P7）

> 2026-10-01 ｜ 提议 · 作者已确认 · **已落地**（见文末「落地」）｜ 对应架构文档 11.1、11 节的树

## 目标

- 改一个模块能找到它的测试、只跑它的测试。
- 新 `class_name` 不再靠「生成物进仓库 + 启动自检 + 每次 --import」三件套兜底。
- `tools/test.sh` 在作者的 Windows 和执行 thread 的 Linux 上都能直接跑。

都是小活，一份方案一起写；三件各自独立交付。

## 现状（已核实）

### 测试
- 71 个套件，`tests/run_tests.gd` 用 `SUITES` 列表登记，`run_*` 在 `_initialize` 跑、`frame_*` 在第一帧跑；`tools/test.sh` 全量跑一次 148 秒。
- `test_author_087 … 096` 十个文件 3359 行，按**报告编号**而不是按模块命名：087 一个文件 17 个 `t.begin`，混了稀有度、词条、商店、BOSS、buff 图标、存档位、望远镜、战败代价……（`test_author_087.gd:62-811`）。
- 用例标题是报告编号 + 长句（`"093 · 蛮神 4 级「不死 10 秒」…"`），搜不到模块名。
- `run_tests.gd` 没有按套件过滤的参数；想只跑一个套件得改 `SUITES`。
- 各套件的 `_content()` / `_cleanup()` 帮助函数各写一份（`test_author_087.gd:21-32`、`test_calibration.gd:9`、`test_author_095.gd:5-13`），100 第 4 步的 `ContentLibrary` 会解决一半。

### 类缓存（P7）
- `.godot/global_script_class_cache.cfg`（3057 行生成物）进了仓库（30b1085，`.gitignore` 放行）；`DevNav` 每次启动扫全部 `.gd` 找 `class_name` 做自检（`ui/dev_nav.gd:88-131`）；`test.sh` 每次先 `--import`；4be6145 又把 `PropertyForm` 改成 `preload` 绕开。四处都在治同一个症状：**拉了带新 `class_name` 的脚本、没重新导入，依赖它的脚本整体解析失败**。
- 生成物进仓库的代价：每次加类都要提交它；两个分支各加一个类就冲突；执行 thread 跑完 `test.sh` 工作区就脏。

### test.sh
- `tools/test.sh:7` 默认 `GODOT=/e/Godot/Godot_v4.7.1-stable_win64_console.exe`；Linux 上 `godot` 在 PATH 里也得手动 `GODOT=godot`。

## 方案

### A · 测试按模块归位（P6）

1. **命名规矩**（写进架构文档 12 节）：测试文件按**被测模块**命名，`tests/<层>/test_<模块>.gd`（`tests/inventory/`、`tests/battle/`、`tests/run/`、`tests/ui/`、`tests/authoring/`）；用例标题以模块名开头，报告编号放在括号里：`t.begin("保险箱 · 关上即锁（092）")`。新用例一律按这条写。
2. **`run_tests.gd` 加过滤**：`--script res://tests/run_tests.gd -- safe` 只跑文件名或 `t.begin` 标题含 `safe` 的套件；`tools/test.sh [pattern]` 透传。过滤靠 `OS.get_cmdline_user_args()`，一行。
3. **`SUITES` 改成扫目录**：`tests/**/test_*.gd` 自动发现，顺序按路径排序；需要先后关系的套件（现在没有）用文件名前缀排。新套件不再忘记登记。
4. **十个 `test_author_*` 分批搬**：不要求一次搬完，规矩是「**谁改到哪个模块，顺手把该模块的用例从 `test_author_*` 搬到模块文件**」。101 的第 1 刀每搬一个模块就把它的用例带走（保险箱 → `tests/run/test_safe.gd`，倒计时 → `test_countdown.gd`……），六刀之后 092 / 094 的文件基本空了就删。搬的时候**不改断言**，只改标题和位置。
5. **帮助函数收口**：`tests/test_case.gd` 旁加 `tests/support.gd`（`content()`、`temp_paths(prefix)`、`cleanup(paths)`），各套件改用；100 第 4 步落地后 `content()` 就是 `ContentLibrary.load_all()`。

### B · 类缓存不进仓库（P7）

根因：Godot 的全局类表只在导入时刷新，而仓库里大量脚本用 `class_name` 互相引用。两条路：

- **B1（推荐）**：**缓存出仓库，改成启动前自动导入**。`.gitignore` 恢复 `.godot/*` 全部忽略；`tools/run_game.sh / .bat` 已经先 `--import` 再起游戏（1b517f7），这就是正道；编辑器里打开项目本身就会导入。`DevNav` 的自检留着但只在**编辑器外**跑（`OS.has_feature("editor")` 为假时），提示改成「跑 tools/run_game」。`test.sh` 的 `--import` 不变。
  代价：作者从 git 拉完直接在编辑器里按 F5 之前，编辑器会先导一次（通常几秒），和现在一样。
- **B2（备选）**：缓存留在仓库，但 `test.sh` 跑完 `git checkout -- .godot/global_script_class_cache.cfg`，避免执行 thread 的脏工作区；冲突照旧。

两条都做不到的事：让「拉了新脚本不导入就跑」能活 —— 这是引擎的工作方式，不值得再绕。4be6145 那种 `preload` 绕法以后不再新增（架构文档 13 节写一句）。

### C · `tools/test.sh`

- `GODOT` 未设时依次找：`$PATH` 里的 `godot4`、`godot`、再 Windows 默认路径；都找不到才报 127。三行。
- `timeout 480` 在 macOS 没有 `timeout`，用 `command -v timeout` 判一下，没有就不包。
- 支持 `tools/test.sh <pattern>` 透传给 A-2。

## 关键决策

- **按模块命名、按责任搬**：不开一个「搬测试」的专项，搬运跟着 101 的刀走，避免一次性大 PR 和合并冲突。
- **缓存出仓库**：生成物进仓库是在用版本控制当分发渠道，根因在流程（没导入就跑），改流程不改仓库。
- **过滤与自动发现**是让「只跑一个模块」成为日常，否则按模块归位的收益出不来。

## 验证

- A：`tools/test.sh safe` 只跑保险箱套件、几秒内结束；全量 `tools/test.sh` 套件数不变（搬运不丢用例：搬前后 `通过 N 项断言` 的 N 相同）。
- B1：干净 clone → `tools/run_game.sh` 直接进主菜单无灰屏；`git status` 在跑完 `test.sh` 后干净。
- C：Linux 执行 thread 不设 `GODOT` 直接 `tools/test.sh` 通过。

## 改动范围

A：`tests/run_tests.gd`、`tools/test.sh`、新 `tests/support.gd`、架构文档 12 节一段；搬运随 101。B1：`.gitignore` 两行、`ui/dev_nav.gd` 一个判断、删缓存文件。C：`tools/test.sh` 十行。

## 待作者定

1. 类缓存走 B1（出仓库，推荐）还是 B2（留着，测试后还原）？
2. 测试目录分层（`tests/run/`、`tests/battle/` …）可以吗？还是平铺只改文件名？（推荐分层）
3. `test_author_*` 跟着 101 的刀顺手搬（推荐），还是单开一个执行 thread 一次搬完？

---

## 落地（2026-10-01）

作者确认：类缓存走 B1、测试目录分层、搬运跟着 101 的刀，其余按推荐。A / B1 / C 一次做完，
全套测试 **12353 项断言、76 个套件通过**。

### A · 测试按层归位

| 目录 | 套件 | 装的是 |
|---|---|---|
| `tests/inventory/` | 12 | 背包、格子、拖拽 |
| `tests/battle/` | 8 | 编译、效果、伤害、数值 |
| `tests/map/` | 10 | 图生成、导航、形态 |
| `tests/run/` | 35 | 一局：流程、模块、存档、经济、事件、信仰 |
| `tests/meta/` | 1 | 跨局 |
| `tests/ui/` | 3 | 屏与控件（帧测试） |
| `tests/authoring/` | 7 | 内容管线与各编辑器 |

- `map/` 与 `meta/` 是方案里五个目录之外加的：地图逻辑十个套件、跨局一个，都塞进 `run/`
  会让它接近五十个，按层分的意义就没了。
- 跟着 101 这几刀搬的：保险箱 → `tests/run/test_safe.gd`、倒计时与带入预算 →
  `test_countdown.gd`、神坛与信仰级效果 → `test_altar.gd`、赐福（095）→ `test_blessings.gd`、
  按点暂存 → `test_node_storage.gd`。`test_author_094.gd` 整个搬空删掉，`test_author_092.gd`
  只剩「离开结算屏时一键出售暂存区」那一条。剩下的 `test_author_087 / 088 / 089 / 090 / 091 /
  093 / 096` 等后面的刀碰到对应模块时顺手带走。
- 搬运不改断言：搬前搬后都是 12353 项，套件 74 → 76。
- 公共代码：`tests/support.gd`（`content()` / `temp_paths()` / `cleanup()`）、
  `tests/run/flow_support.gd`（建 flow、走到某点、结一步）。**刻意不叫 `test_*`**，否则会被收集。

### A-3 自动发现（比方案多做了一点）

`run_tests.gd` 的 `SUITES` 清单整个删掉，改成 `DirAccess` 递归扫 `res://tests` 下的
`test_*.gd`、按路径排序加载（`discover()` / `matches()` / `pattern_of_args()` 都是静态的，
可被测试直接调）。加一个套件不用再登记 —— 原来忘了登记的表现是「写了测试但从来没跑过」。

### C · 过滤与可移植

- `bash tools/test.sh safe` → 只跑路径或 `t.begin` 标题里含 `safe` 的套件，并打印
  「只跑含「safe」的套件：1 个」。实测 1 个套件 1087 ms，全套约 5 分钟。
- 过滤只影响单元测试那一步；后面 `check_scripts` / `check_content` 两步全项目检查照常跑
  （和过滤无关，也快）。
- `GODOT` 未设时在 `PATH` 里找 `godot` / `godot4` / `Godot`；没有 `timeout` 就不包超时。

### B1 · 类缓存出仓库

- `.gitignore` 收整个 `.godot/`，`git rm --cached .godot/global_script_class_cache.cfg`。
- `DevNav._check_class_cache()` 在 `Engine.is_editor_hint()` 或 `OS.has_feature("editor")`
  时直接返回 —— 编辑器里缓存必然是新的，提示只会是误报；提示文字改成指向
  `tools/run_game` 或「在编辑器里打开一次」。
- **作者的疑问「编辑器打开时也能正常读取吗」**：能。编辑器打开项目时自己扫脚本重建这份缓存，
  它本来就是编辑器的产物；仓库里有没有这个文件对编辑器没影响。三条用得到它的路都有人管：
  编辑器自己重建、`tools/test.sh` 每次先 `--import`、不开编辑器直接跑游戏走
  `tools/run_game.sh` / `.bat`（也先 `--import`）。
- `tests/ui/test_dev_nav.gd` 的那条断言从「缓存文件在仓库里」改成「`.gitignore` 收了 `.godot/`
  且没有放行行」。

### 文档

架构文档 v2.12：新增 **11.1「测试怎么摆、怎么跑」**（命名规矩、自动发现、过滤、类缓存 B1
推翻 v2.04），11 节的树改成分层目录。方案里写的是「架构文档 12 节一段」，但 12 节是实施顺序表、
测试那一段原本并不在那里，所以写在目录结构后面作 11.1。`status.md`：类缓存那段改写，
套件数 70 → 76、断言 11985 → 12353。
