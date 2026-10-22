# 237 · 卡死 / 卡顿 / 内存：全项目代码与资源调用评估（附头号问题的修复）

> 代码审阅精简线程，2026-10-22。作者 10:33 原话：「关于卡死问题，我认为和内存占用有关：1. 当前本地战斗中的表现非常卡顿 2. 每次都是游戏彻底卡住无响应。我认为需要优化游戏的内存，让负责审阅代码的线程评估整个项目的代码和资源调用」。
> 症状（反馈线程）：序章第一张图，第三次搜索遇敌选【迎战】之后整个游戏无响应；Windows 控制台版；本地 main 77d46192（早于 PR #293），四份日志 0 条报错、只有 128 条 `Lambda capture was freed` 告警（#293 已修）。

## 〇 一句话

**卡死最可能不是内存「堆积」，而是每次重绘都重新造字体**：`UiPalette.cjk_font_bold()` 这一类函数每调一次就 `SystemFont.new()` + `FontVariation.new()`，而战斗面板、战前屏属性签等是在 `_draw` 里调它 —— Windows 上 `SystemFont` 一设 `font_names` 就去找微软雅黑并把整个字体文件（msyh.ttc ≈ 19 MB / msyhbd.ttc ≈ 16 MB）读进内存、解析一遍，再丢掉。战斗里两块面板每帧 6～12 次，战前屏每次整理背包 40 次上下：一帧几百毫秒到几秒，Windows 超过 5 秒不处理消息就把窗口标成「无响应」；同时每帧分配又释放一两百 MB，正是「越玩越卡、内存很大」的观感。云端 Linux 没有微软雅黑，回退字体不到 1 MB，所以此前怎么走序章都复现不出来。

本 PR 把这几个字体函数改成**只建一次、全局共用**（画出来一模一样），并带上两件量测工具。其余发现（真实但量级小的泄漏、贴图与逐帧开销、写盘、渲染后端）按「不改行为 / 改行为」分列在第四节，前者由本线程分批自行合并，后者交架构设计。

## 一、怎么查的

1. **三路只读静态审阅**（并行）：A 战斗路径（【迎战】→ 战前准备 → 开战 → 回放结束）的主线程阻塞点与每个循环的界；B 对象生命周期、信号 / lambda、RefCounted 环、静态缓存；C 美术 / 字体 / 贴图 / 音频 / 各界面 `_process` `_draw` 的逐帧开销。三份原文在 scratchpad（A-battle-path.md、B-memory-leaks.md、C-resources-frames.md），要点并入本文，file:line 都复核过。
2. **云端动态量测**：新工具 `tools/perf_probe.gd` 把整个游戏（`ui/game/game.tscn`）装进树，自动走序章：新的游戏 → 搜索 ×2 → 战斗 → 搜索 ×3 → 遇敌【迎战】→ 开战 → 回放看完 → 战利品 → 继续，逐帧记 `Performance` 监视器（帧时、`TIME_PROCESS`、对象 / 节点 / 孤儿 / 资源数、静态内存、纹理显存、绘制调用、`board.changed` / `storage.changed` 的连接数）到 csv，并给每个同步调用（开局、选事件、开战……）计时。跑了三轮：xvfb 1600×1000（软件渲染 llvmpipe）、xvfb 800×500 两局、headless（不渲染，只剩脚本与引擎）。`-- bench` 模式再把第一场回放逐条 `_apply` 计时、各种刷新按帧计时。
3. **字体微基准** `tools/perf_fonts.gd`：修复前的构造方式 ×50、修复后 ×50、一个 16 MB 的 TTC `load_dynamic_font` ×5、新字体对象首次排版描边画一行 vs 同一对象再画。

## 二、量到了什么（云端 Linux，Godot 4.7.1）

### 2.1 主线程同步卡顿（三轮一致，取 800×500 那轮）

| 调用 | 用时 | 说明 |
|---|---|---|
| 导演 `_ready`（装全部内容） | 779～1093 ms | 启动一次 |
| 「新的游戏」（开局） | 1105～1698 ms | `new_run`：建局、生图、存盘 |
| 事件「tut_search_1」选「搜索」 | 190～278 ms | 第一次开搜索屏 |
| 事件「tut_battle」选「进入战前准备」 | 165～213 ms | 第一次开战前屏 |
| 开战（模拟 + 写回放 + 建回放屏） | 217 / 235 ms（首战）、104 / 107 ms（遇敌战） | `BattleSim.run` 本身几 ms，大头是建回放屏 + 写三份日志 |
| 事件「tut_search_2_encounter」选「迎战」 | 78 ms | **就是作者卡住的那一步，云端没有问题** |
| 其余（走格、关搜索屏、拾取、继续） | 9～69 ms | |

### 2.2 逐帧

| 轮次 | 战斗回放帧时（中位 / p90） | 事件 / 地图 / 搜索屏 | 说明 |
|---|---|---|---|
| xvfb 1600×1000 | 52.8 / 61.1 ms | 29～43 ms | 软件光栅化，随像素数线性 |
| xvfb 800×500 | 22.2 / 26.1 ms | 16～23 ms | 同上，四分之一像素 |
| headless（不渲染） | 6.9 / 6.9 ms（帧循环下限） | 6.9 ms | 每 0.6 s（每次出手）一帧 30～60 ms 的尖峰，`TIME_PROCESS` 每秒峰值中位 42 ms |

- 绘制调用每帧 250～310，正常。
- bench 模式：逐条 `_apply` 35 条事件共 4.1 ms（伤害事件 0.37 ms / 条，弹字 0.1 ms / 个），面板 / 棋盘 `queue_redraw`、抖动、弹字按帧都量不出差别（都在软件渲染的 21 ms 噪声里）。**在 Linux 上战斗本身不贵**。

### 2.3 内存与对象

| 指标 | 开局前 | 一局（序章两场战斗后） | 说明 |
|---|---|---|---|
| 对象数 | 4 776 | 5 478～5 595；每走一个点约 +85～100，一局两场战斗 +61 | 搜索会话、事件页等小量泄漏，见 §3.5 |
| 节点数 | 57 | 150～330（随屏变）| 屏关了节点都释放，孤儿节点始终 0 |
| 静态内存 | 170 MB | 185～188 MB；每个搜索点约 +2 MB | |
| 纹理显存 | 47 MB | 60～84 MB（战前屏 +9 MB，1600×1000 下峰 84 MB） | |
| `board.changed` 连接数 | 3 | 3～7，随屏开关正确回落 | #293 之后没有死 lambda 堆积（日志 0 条告警） |
| 退出时 | — | `2695 ObjectDB instances were leaked`、`1876 resources still in use` | 一整份 RunState 环 + 内容库，见 §3.5 |

结论：**一局 30 分钟内没有能涨到卡死量级的东西**（内存 +20 MB 左右），和作者「内存占用」的直觉不符；但 Windows 上字体那条路径的内存是「每帧分配又释放一两百 MB」，任务管理器看起来确实像内存失控。

### 2.4 字体微基准（headless；云端回退字体是 DejaVuSans 750 KB）

```
修复前：新建 SystemFont+FontVariation ×50：295.24 ms（每次 5.905 ms）
修复后：UiPalette.cjk_font_bold() ×50：0.041 ms
load_dynamic_font(wqy-zenhei.ttc，16.0 MB) ×5：96.4 ms（每次 19.3 ms）
每次新字体对象排版 + 描边画一行 ×20：25.1 ms（每次 1.25 ms）
同一字体对象再画 ×20：0.26 ms（每次 0.013 ms）
```

- 回退字体只有 750 KB 的 Linux 上，一次构造已经 5.9 ms；换成 16 MB 的 TTC，光 `load_dynamic_font` 一次 19.3 ms（页缓存热、无杀软）。微软雅黑 19 MB，加 DirectWrite 枚举、杀软实时扫描，一次 20～60 ms 是合理估计。
- 新字体对象没有字形缓存：画一行描边字 1.25 ms，同一对象再画 0.013 ms —— 即使字体文件读得飞快，每次重绘换新对象也要把所有字形重新栅格化。

## 三、发现（按「能解释卡死 / 卡顿」的可能性排序）

### 3.1 ★★★ `_draw` 里每次重绘都新建系统字体（本 PR 已修）

- `ui/ui_palette.gd` 原 317～360 行：`system_font()` 每次 `SystemFont.new()` 并设 `font_names = ["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "sans-serif"]`；`_wrap()` 每次 `FontVariation.new()`；`cjk_font / cjk_font_bold / title_font / display_font / numeral_font` 全部每次新建（`title_font` 里套 `cjk_font_bold`，`display_font` 套两层）。只有打包字体文件 `font_file()` 有缓存。
- Godot 的 `SystemFont.set_font_names()` 立刻 `_update_base_font()`：按名字顺序 `OS.get_system_font_path()`，命中就 `FontFile.load_dynamic_font(path)` —— **整个文件读进内存**并逐 face 解析。Windows 上第一个名字就命中 `C:\Windows\Fonts\msyh.ttc`（粗体 `msyhbd.ttc`）。
- 在 `_draw`（每次重绘都付一次）里的调用点：`ui/battle/combatant_panel.gd:714`（`_draw_art_bar`，每条资源条 1 次）、`:604,605`（`_draw_icon_chip`，每个带层数的 buff 图标 2 次）；`ui/widgets/stats_strip.gd:299-301`（`_draw_tag`，每张签 3～4 次，还套在 `fit_size` 的缩字循环里）；`stone_chip.gd:177`、`scroll_key.gd:187,216,225`、`ledger_rows.gd:41-51`、`header_tag.gd:58,88`、`price_tag.gd:39,57`、`icon_button.gd:148`、`bag_rack_view.gd:214`、`character_card.gd:196-197`、`stone_stepper.gd:34,45`。
- 重绘频率：`combatant_panel.gd:348-351 set_now()` 只要有限时 buff 就 `queue_redraw()`，而 `battle_view.gd:435-445 _process → _sync_overlays` **每帧**调两块面板的 `set_now`；每条事件的 `set_resource / set_stacks`、抖动 / 弹字 Tween 每步也重绘。战前屏：开屏两排签各 `refresh()`，之后每次 `board.changed`（整理一件）再来一遍 ——【迎战】之后开的正是战前屏。
- 建控件时新建并长期持有的（内存膨胀）：`stone_chip.gd:116`（设置屏 / 图鉴每个石签各抱一份 16 MB）、`tip_button.gd:35`、`notice_scroll.gd:66,75`、`overlay_frame.gd:129`、`ledger_view.gd:45-47`（3 份）、`map_view.gd:219`、`game_screen.gd:40` 等。设置屏一页二三十个石签 = 几百 MB。
- 估算（Windows）：战斗每帧 6～12 次 × (20～60 ms 读文件 + 1.25 ms 重栅格化) ≈ **0.15～0.7 s / 帧**；战前屏首帧 / 每次整理 ≈ 40 次 ≈ **1～2.5 s**；慢盘、杀软实时扫描、集显共享内存时更糟。云端 Linux：回退字体不存在或极小，几乎零开销 —— 与「云端不复现」一致。
- **修法（不改行为，本 PR）**：`UiPalette` 加 `_fonts` 静态字典，`system_font(bold)`、五个取字体函数各只建一次（`_font_for(key, make)`），`clear_font_cache()` 给夹具。全仓库没有任何调用点改这些 Font 的属性（都是挂到控件 / 主题上只读），`UiTheme._fill` 本来就把同一份字体共享给所有控件，所以画面一个像素都不变。副作用只有好的：系统回退字体的字形缓存也只剩一份。

### 3.2 ★★ Windows 控制台版的两个环境因素（请作者核实，见 §6）

1. **控制台 QuickEdit 选中态**：Windows 控制台里点一下 / 拖一下鼠标就进入「选择」模式（标题栏出现「选择 …」），这时**任何往控制台写字的进程都会被整个挂起**，直到按 Esc —— 表现正是「彻底无响应」且每次都能复现。游戏每场战斗、每个屏都会打印（日志、告警）。
2. 控制台版每条 `ERR_PRINT`（含 `Lambda capture was freed` 两行 + 回溯）都同步写控制台，Windows 控制台每行约 1 ms，128 条就是零点几秒；这一来源 #293 已修，但说明**控制台版自带「打印即卡」**，玩家版应当用非控制台导出或 `--log-file`。

### 3.3 ★ 渲染后端：2D 游戏跑在 Forward+ / D3D12 上

- `project.godot`：`rendering_device/driver.windows="d3d12"`，没有设 `rendering_method`（默认 Forward+）。这是纯 2D UI 游戏；D3D12 后端着色器 / 管线首次使用时同步编译（每个新着色器几十 ms 到秒级，无管线缓存更久），集显驱动质量参差。项目有两个运行时着色器：`ui/map/ink_reveal.gdshader`（入局转场）和 `ui/ui_motion.gd` 的内联裁切着色器（战前屏「开战」旗、战斗屏「继续」旗 —— 第一次就在战前 / 战斗屏用到）。
- 不是云端能验证的事。建议作者做一次 A/B：`packsoudc.exe --rendering-method gl_compatibility` 对比帧率与卡顿。若明显改善，改默认（行为 / 架构改动，交架构设计：Forward+ 的 2D 对本项目没有收益）。

### 3.4 逐帧与每次开屏的固定开销（都不是元凶，但该修）

| # | 问题 | 位置 | 代价 | 行为 |
|---|---|---|---|---|
| a | 地图视图 `_process` 整局常开、每帧无条件 `queue_redraw` → 整幅 `_draw`（平铺桌面、3840×2400 无 mipmap 底图、每节点几个 `draw_arc`、路径虚线、`_draw_tag` / `pawn_rect` 每帧 **读 JSON 文件**），被搜刮 / 战前 / 战斗叠层盖住时照跑 | `ui/map/map_view.gd:95,261-272,583-727,1070,1090`；导演不藏底屏 `game_director.gd:245-270` | CPU 每帧 1～3 ms + 2～4 次打开 pck 内文件；GPU 每帧采样一张 36.9 MB 的图 | JSON 缓存：不改行为；叠层下停底屏：要看叠层有没有透出底图（集市帐篷等画在窗外），交架构设计定 |
| b | `ItemSilhouette.of()` 查缓存之前先 `tex.get_image()`（GPU 回读 + 全管线同步），地上层每个鼠标事件每件道具 2～3 次（`_has_point → uid_at_local → hit / item_rect`） | `ui/inventory/item_silhouette.gd:32,56-58`；`ground_layer.gd:591,626,674-675,724-729,1674` | 独显 0.2～1 ms / 次，集显 / D3D12 一次可等一整帧；地上 5 件 → 每次移动鼠标十几次同步 | 不改行为：缓存命中就不回读 |
| c | `UiTheme.art()` 不缓存、`art_meta()` 每次读文件 + 解析 JSON；`tone_of / _art_box / has_slab`、`BoardFrame`、叠层石碑重绘各调几次 | `ui/ui_theme.gd:935-968,766-772,1038-1053` | 每次 0.05～0.5 ms，Windows 带杀软更慢；科技树点选 33 次文件访问 | 不改行为：按路径缓存 |
| d | `EventCostIcons.strip()` 每个事件选项按钮 `get_image()` 回读再拼图 | `ui/game/event_cost_icons.gd:66-84` | 每次开事件屏 1～9 次 GPU 同步 | 不改行为：按组合缓存 |
| e | 回放：`_log_event` 在没有播报条时仍先拼好整行 BBCode；`seek` 每个鼠标移动事件从 0 重放到 t；`_clock.text` 每帧改隐藏 Label | `ui/battle/battle_view.gd:648-689,323-338,441` | 小 | 不改行为 |
| f | 战前屏每次 `board.changed`：`compile_player` ×2 + `EnemyKit.spec_of` 重编敌人 + 两排签重绘 | `ui/game/prebattle_screen.gd:131,245-260`；`inventory_panel.gd:46` | 每拖一件几十 ms（字体修完后） | 不改行为：复用编译结果 |
| g | 地上层弹开解算 `advance_bumps` 不看可见性，被战斗屏盖住仍算到上限 6 s；大 delta 帧一次补几十步 | `ui/inventory/ground_layer.gd:938-952` | 有界 | 不改行为 |
| h | 开战同步写三份战斗日志（jsonl / txt / replay.json，`to_text` 逐条排版最贵），非导出包默认开 | `core/battle/battle_trace_writer.gd:14-39`；`battle_archive.gd:26` | 序章一场 ~0.1 s；打到 600 s 上限的长战 1～2 s、文件几 MB | 玩家向默认关 / 搬到工作线程 / txt 延后：行为改动 |
| i | 「新的游戏」1.1～1.7 s、装内容 0.8～1.1 s 同步 | `core/run/game_flow.gd new_run`、`game_director.gd _ready` | 一次性，Windows 上更长 | 以后再拆（分帧或后台线程）：行为改动 |

### 3.5 真实但量级小的泄漏（B 组）

- `RunState` 每局泄一整份：9 个模块 `var _run: RunState` ↔ `RunState.modules`，`faith_power / skills / hunters / erosion` 反指，self-lambda 存进自己的 `hooks`；`_reset_run / _adopt` 只放指针。拖着内容库、全部 MapNode、ItemInstance、模块 Resource。每开局 / 读档 +1，一份 1～3k 对象、几 MB。（测试退出 10 万实例 / 1500 资源的大头就是它乘以上百局。）
- `NodeEvents` 自环：`game_flow.gd:1338-1347,1376-1385` 的 lambda 捕获局部 `ev`，连接挂在 `ev` 自己的信号上。
- `SearchSession` 每个搜索点 / 宝箱泄一个：`node_events.gd:697-707,827-830` 的 `s := session` 被 `encounter_builder` 与 `ended` 回调捕获。拖着 `haul_box` 与没拿走的道具。一局 5～15 个。
- `GameFlow.seen_loot` 只增不清。
- 核过没问题的：UI → 核心信号的 lambda（#293 之后全是 self-lambda / 方法 Callable）、导演的屏节点生命周期、37 处 Tween / Timer、所有静态缓存（按内容 id 有界）。
- 修法都不改行为：`RunState.dispose()` 在放旧局前解环（动 9 个模块，交架构设计）；`ev.` 改 `run.events.`、`ended.connect(_on_search_ended.bind(node))` 用 `current_search`、`_reset_run` 里 `seen_loot.clear()`（本线程第二批）。

### 3.6 贴图与显存（C 组，实测）

- 884 张 PNG，磁盘 84.8 MB，解码后 502 MB；`.import` 全部 `compress/mode=0`（无损、RGBA8 进显存）、`size_limit=0`，只有 35 张头像生成 mipmap。
- 大图：5 张地图底图 3840×2400 各 **36.9 MB 显存**（地图屏是整局底屏，常驻；在 1600×1000 下按 0.4～0.5 倍画，无 mipmap 缩小采样）；1920×1200 底图（铸炉 ×2、战斗、开局 ×3、宝箱 ×5、营地 ×4）各 9.2 MB；`ui/result/ledger_stele.png` 1844×1268 = 9.35 MB 显存但 PNG 只有 20 KB（几乎全透明，该裁）；主菜单字标 5.5 MB 常驻。
- `UiTheme._art_cache` 永不清理（上限 = 全部素材），去过铸炉 / 结算后 ~200 MB 显存。对独显不是问题，共享显存的集显勉强。
- 修法：地图 `mipmaps/generate=true` + `process/size_limit=2048`（缩小更平滑、1:1 放大略软 —— 表现会变）；1920 级底图可选 VRAM 压缩；`release_art(prefix)` 离开铸炉 / 结算 / 主菜单时释放；裁 `ledger_stele.png`。均交架构设计 / 美术。

### 3.7 核过没有的东西

- 战斗路径上**没有能永远卡死的代码**：无 `await`、无人动 `paused`，`BattleSim` 主循环（`DEFAULT_TIME_LIMIT 600 s`、每瞬 64 步、`max_chain 256`、冷却 `MIN_PERIOD 0.01 s`、鏖战间隔 ≥ 0.001 s）与掉落 / 打包 / 地上解算的每个 `while` 都有界（A 组 §5 逐个列了界与会破坏它的输入，只有 NaN 一类数据层不可能出现的值）。231 过场的 Tween / 教程气泡 / `_maybe_coach` 轮询两条路都能回到播放。
- 音频：8 个播放器轮用、流按路径缓存（43 个 OGG 共 0.41 MB）、限频；无阻塞点。
- 主题只建一次；着色器两个、材质随动画释放。

## 四、修法清单

### 4.1 不改行为（本线程自行合并）

| 批 | 改动 | 对应 |
|---|---|---|
| 本 PR | `UiPalette` 字体只建一次（§3.1）；`tools/perf_probe.gd`、`tools/perf_fonts.gd` 两件量测工具 | 头号问题 |
| 第二批 | `ItemSilhouette.of()` 缓存命中不回读、`art_available()` 存布尔（3.4b）；`UiTheme.art_meta()` 缓存、`tone_of / _art_box / has_slab` 走 `art_cached`（3.4c）；`map_view` 的 `_draw_tag / pawn_rect` 不再每帧读 JSON（3.4a 的一半）；`EventCostIcons.strip()` 按组合缓存（3.4d）；回放 `_log_event` 早退、`seek` 增量、`_clock.text` 按需（3.4e）；战前屏 `_refresh` 复用编译结果（3.4f）；`advance_bumps` 不可见时跳过（3.4g）；`NodeEvents` / `SearchSession` 的 lambda 环、`seen_loot.clear()`（3.5）；`combatant_panel.gd:129` 无用的 `set_process(true)`、`tech_tree_view._process` 按可见门控 | 每项都是缓存或早退，画面与规则不变，全量测试过了就合 |

### 4.2 行为 / 架构改动（交架构设计）

1. 渲染后端：A/B 之后决定是否把默认改成 `gl_compatibility`（§3.3）。
2. 战斗日志写盘：玩家向默认关、或搬到工作线程、`.txt` 延后生成（3.4h）。
3. 叠层盖住底屏时停掉地图 `_process`（3.4a）—— 要先确认哪些叠层透出底图。
4. `RunState.dispose()`：放旧局时解开模块 / 信仰 / 技能 / 猎手的反向引用（3.5）。
5. 贴图导入：地图 mipmap + 2048 上限、1920 级底图 VRAM 压缩、`release_art`、裁账单石碑（3.6）。
6. 开局与装内容的 1～2 秒同步（3.4i）：分帧或后台线程。

## 五、本 PR 的产出

| 文件 | 内容 |
|---|---|
| `ui/ui_palette.gd` | `_fonts` 静态缓存：`system_font(bold)` 两份、`cjk_font / cjk_font_bold / title_font / display_font / numeral_font` 各一份（`_font_for`）；`clear_font_cache()` |
| `tools/perf_probe.gd` | 自动走序章并逐帧记监视器、同步调用计时、`-- bench` 回放基准；用法 `godot --path . --script res://tools/perf_probe.gd -- 输出.csv 局数 [bench]`（Linux 用 `xvfb-run`，或 `--headless` 只量脚本） |
| `tools/perf_fonts.gd` | 字体构造成本微基准（§2.4） |
| 本报告、`docs/reports/README.md`、`docs/architecture.md` 版本表 | |

## 六、请作者在本地做的核实（按顺序，每条都很快）

1. **同步到本 PR 之后再走一遍**：序章第三次搜索遇敌【迎战】→ 战前准备 → 开战 → 回放。看战斗还卡不卡、战前屏整理背包还顿不顿。
2. **控制台窗口**：复现时看控制台标题栏有没有「选择」字样；有就按一下 Esc。日常建议用非控制台版，或加 `--log-file user://game.log` 把输出改到文件。
3. **渲染后端 A/B**：`packsoudc.exe --rendering-method gl_compatibility` 跑一局对比。
4. 若 1 之后仍卡：在本地跑 `godot --path . --script res://tools/perf_probe.gd -- probe.csv 1`（可以让「本地仓库同步」线程代跑），把末尾的「同步调用」表和「屏」表贴回来 —— 它会直接指出哪一步、哪一屏的帧时爆了；再配合任务管理器的「提交大小」和 Process Monitor 过滤 `msyh*.ttc`。

## 七、验证

- 全量测试：`bash tools/test.sh` —— 见 PR 描述（本 PR 不改任何规则，只是字体对象复用；画字的测试 `test_stats_strip_216`、`test_stone_chips`、`test_english_ui_221` 等都过）。
- 量测：§2 的三轮 perf_probe 与字体微基准；修复后 `cjk_font_bold()` 一次 0.8 µs（修复前 5.9 ms，Linux 小回退字体）。
- 云端量不到 Windows 的字体文件读取，这一条的最终确认靠 §6.1。

## 八、遗留

- `perf_probe` 在序章精英点的事件页上走不下去（它只会选「迎战 / 离开 / 第一项」），所以没量到撤离 / 结算 / 局外屏；要量那几屏得教它看懂精英事件的选项。
- `TIME_PROCESS` 监视器是「上一秒的峰值」而不是逐帧值，csv 里看逐帧请用 `delta_ms`（上限 133 ms，更长的帧被引擎夹住）。
- headless 下每次出手一帧 30～60 ms 的尖峰没有归因（xvfb 下量不出），字体修完后再看一眼。
