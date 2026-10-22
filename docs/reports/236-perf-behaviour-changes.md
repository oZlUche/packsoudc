# 236 · 方案：237 性能评估里的六项行为 / 架构改动

> 架构设计线程，2026-10-22。来由：代码审阅精简的 [237 卡死 / 卡顿 / 内存评估](237-perf-freeze-assessment.md) §4.2 列了六项「改行为」的修法交架构设计评估排期。头号问题（`_draw` 里每次重绘新建 `SystemFont`）237 已在 v4.12 修掉，本文只管剩下六项。编号接 235，排在 237 前面是因为 237 先写出来了。本文只做方案，作者确认后交执行。

## 〇 一句话

六项里**四项可以直接做、不用作者看效果**（④ 放旧局解环、② 战斗日志写盘挪到工作线程、③ 叠层盖死底屏时停掉地图、⑤ 的一半：地图底图开 mipmap + 账单石碑换 1× 图 + 离开大图屏释放贴图），一单交执行。**两项要作者的眼睛**：① 渲染后端只能在作者机器上 A/B 之后改默认；⑤ 另一半（1920 级底图压成显存压缩格式）先压一张给美术 / 游戏测试对比再推广。**⑥ 开局与装内容的分帧放最后**：一局一次、一两秒，不是卡死，等前面做完、作者本机再量过才值得动。

## 一、核过的现状（v4.12）

| 项 | 代码事实 |
|---|---|
| ① 渲染后端 | `project.godot` 只设了 `rendering_device/driver.windows="d3d12"`，没设 `rendering/renderer/rendering_method`（默认 Forward+）。运行时着色器两个：`ui/ui_motion.gd` 内联裁切着色器（战旗展开，`canvas_item`）、`ui/map/map_preview.gd`。都是 `canvas_item` 着色器，`gl_compatibility` 下照跑 |
| ② 战斗日志 | `BattleArchive.default_on()` = `DevGate.on()`：**玩家版本来就默认关**（`GameSettings.battle_trace`，`GameFlow.apply_battle_trace()` 关着时 `trace_info` 为空、`NodeEvents` 连 `BattleTrace` 都不建）。237 §4.2 的「玩家向默认关」已经成立。贵的是开着时：`BattleTraceWriter.write` 在开战那一帧同步拼 `to_jsonl` + `to_text` + `replay.json` 三份、写盘、再 `prune` |
| ③ 地图 `_process` | `MapView._process` 每帧无条件 `queue_redraw()`（呼吸、虚线行进、跳步）；导演叠层时不藏底屏（`_switch_screen` 只给最小化的叠层设 `PROCESS_MODE_DISABLED`）。叠层十一种（`GameFlow.is_overlay`）：**盖死底图的** = 战斗（`battle/battle_bg` 1920 × 1200 整屏）、战前（同）、搜刮 / 宝箱（`chest/bg/*` 整屏）、铸炉（`forge/bg_*` 整屏）、休息营地（`rest/bg_*` 整屏）；**透出底图的** = 事件书（232）、商店帐篷（233，门帘油灯画在窗外）、神坛石碑、保险箱石板窗、百科弹窗，还有浮动的背包窗 |
| ④ 放旧局 | `GameFlow._reset_run()` 只把 `run = null`；`_adopt(state)` 直接覆盖。反向引用：9 个模块的 `_run`（`core/run/modules/*`）、`FaithPower.run`、`RunSkills.run`、`HunterSystem.run`、`ErosionField.run` / `ErosionContext.run`、`RunHooks._fns` 里模块注册的 self-lambda（`belt_use`、`safe_open`、`bless_substitute`、三条地图 buff、`player_spec`）。一整份局（模块、地图、道具实例）每开一局泄一份 |
| ⑤ 贴图 | 五张地图底图 3840 × 2400 各 36.9 MB 显存，`compress/mode=0`、无 mipmap、无 size_limit，走 `load()`（导入设置生效）。地图能缩放：`ZOOM_MIN 0.3`、`ZOOM_MAX 2.5`，开局按整张纸装进安全区（1600 宽时约 0.42 倍）；分辨率档最高 3840 × 2160。1920 × 1200 级底图 17 张各 9.2 MB（铸炉 4、营地 4、宝箱 5、开局 3、战斗 1），加两张 1920 × 1080（结算库房、基地）。`ui/result/ledger_stele.png` 1844 × 1268 是 **2× 图**（`ledger_stele.json` 的 `draw_size [922, 634]`），全画布都有半透明像素，裁不掉，该换 1×。`UiTheme._art_cache` 只进不出 |
| ⑥ 开局 / 装内容 | `GameDirector._ready` 同步装 15 类内容（`data/` 507 个 json、4.4 MB）0.8～1.1 s；「新的游戏」`new_run → begin_direct → begin()`（建局、生图、发包、`RunSave.write`）+ `show_intro` 1.1～1.7 s。都是云端 Linux 的数，Windows 上更长 |

## 二、逐项方案

### ① 渲染后端（等作者 A/B）

- 不盲改。作者本机跑一次 `packsoudc.exe --rendering-method gl_compatibility`（237 §6.3），对比战斗回放帧率、战旗展开第一次有没有顿一下、地图拖动。
- 若 GL 不差或更好：`project.godot` 加 `rendering/renderer/rendering_method="gl_compatibility"`（D3D12 那行留着不碍事，GL 下不读）。Windows 上默认原生 OpenGL 3.3、不行自动退 ANGLE（`rendering/gl_compatibility/fallback_to_angle` 默认开），不用再设。
- 若 GL 更差：不改，这项关闭。
- 不做「设置里切后端」：后端要重启才生效，一个藏在设置里的重启开关只会招 bug。
- 测试：无（`tools/test.sh` 是 headless）。游戏测试跑一遍 xvfb 走查确认两个着色器还在动。

### ② 战斗日志写盘（执行直接做）

- 玩家版已默认关，不动开关。改的是**开着时**（开发版、作者本机）：`BattleTraceWriter.write` 改成主线程只做 `trace.header` 和取文件名（`new_stem` 要读目录、也挪进去），三份文本的拼接与写盘、`prune` 整个丢给 `WorkerThreadPool.add_task`；`BattleTrace` 在开战后不再被改，线程里读它安全（`BattleResult` 同理；`info` 用 `duplicate(true)` 的那份）。
- `.txt` 不延后生成：`to_text` 在线程里就不碍事了，少一条「哪份文件没有」的规矩。
- 加 `BattleTraceWriter.flush()`（`wait_for_task_completion`），`test_117` 写完就 flush 再查文件；游戏退出（`NOTIFICATION_WM_CLOSE_REQUEST`）前也 flush 一次，免得最后一场只写了一半。
- 行为变化：日志文件晚几十到几百毫秒出现；回放浏览器打开时刚打完的那场可能还没落盘 → 浏览器 `list()` 前先 `flush()`。
- 测试：`test_117` 加「写在线程上、flush 后三份齐全、prune 照旧」。

### ③ 叠层盖死底屏时停掉地图（执行直接做）

- `GameScreen` 加 `covers_base() -> bool`，默认 false；战斗、战前、搜刮 / 宝箱、铸炉、休息营地五个返回 true（它们各自有整屏底图）。事件书、帐篷、石碑、石板窗、百科弹窗保持 false —— 它们透出地图，地图上的呼吸和虚线要照动。
- 导演：叠层淡入完成后，若 `covers_base()`，把 `_base.visible = false` 且 `process_mode = PROCESS_MODE_DISABLED`（和最小化叠层同一套）；撤叠层 / 换叠层前先恢复。231 的战前 → 战斗一镜到底：两屏都盖死，底屏在战前打开时就停了，战斗接管时不动。
- 停掉的不只是 `MapView._process`：整个地图屏（含它的读数层、地上层弹开解算 `advance_bumps`）都停，237 §3.4g 顺带解决。顶端栏在盖死的叠层上另有自己的读数层宿主（231 `hosts_in`），不受影响。
- 透出底图的叠层开着时，地图改成**隔帧重绘**（`_process` 里攒一帧）：窗后面的呼吸从 60 Hz 变 30 Hz，看不出，省一半。这一条是可选项，执行觉得多余就不做。
- 边界：地图跳步 `_hop` 在到点后才开叠层，停住时不会有半空的棋子；恢复时 `queue_redraw()` 一次。地图上的告示卷（226）挂在导演层不在底屏，照常。
- 测试：`test_director_covers_236`：开战斗叠层后底屏 `process_mode` 停、不可见；开事件书不停；撤掉后恢复；最小化 / 恢复不互相干扰。

### ④ `RunState.dispose()`（执行直接做）

- `RunModule` 基类加非抽象 `dispose()`（默认 `_run = null`）；九个模块里接过外部信号的（倒计时接旅程、猎手 / 侵蚀接节点事件……）各自在 `dispose()` 里断开。`FaithPower / RunSkills / HunterSystem / ErosionField` 加同名方法清 `run`。
- `RunState.dispose()`：`hooks.clear()`（`RunHooks` 加 `clear()`）→ 每个模块 `dispose()` → `modules.clear()` → 四个系统 `dispose()` → `events = null`。只解环，不动存档、不发信号。
- 调用点：`GameFlow._reset_run()` 与 `_adopt()` 覆盖前各一次 —— 但**延后一帧**（`call_deferred`）：换屏的那一帧结算屏、`flow.result`、`last_battle` 还可能在读旧局；读档失败走打捞那条路时旧局还要留到打捞完。
- 行为变化：没有（玩家看不见）。退出时 `ObjectDB instances leaked` 从几千降到内容库那几百。
- 测试：`test_run_dispose_236`：`weakref(flow.run)` → 开新局、过一帧 → `get_ref() == null`；读档覆盖同理；dispose 后再 `to_dict()` 不会被调到（断言模块表空）。

### ⑤ 贴图（一半直接做，一半先试一张）

直接做：
- 五张地图底图 `.import` 开 `mipmaps/generate=true`，**不设 size_limit**：地图缩小到 0.4 倍画时现在是无 mipmap 的硬采样（闪、糊、每帧采 37 MB），开了就平滑；显存 36.9 → 49 MB，但只装当前一章那张。不限 2048 是因为最高缩放 2.5 倍、分辨率档到 4K，限了会软。
- `ledger_stele.png` 换 1×（922 × 634，由美术从源文件重导），9.4 → 2.3 MB；`ledger_stele.json` 的 `draw_size` 不变，`origin` 按 1× 改 `[-14, -14]`（现在的 −29 是 2× 下的边）。
- `UiTheme.release_art(prefix)`：按路径前缀从 `_art_cache` 踢出去。只释放整屏底图这一类（`forge/bg_`、`result/bg_`、`chest/bg/`、`rest/bg_`、`menu/bg_`、`battle/battle_bg`），各屏 `_exit_tree` 时释放自己的；小件不释放（重进屏再解码 9 MB 的 PNG 要几十毫秒，小件释放不值）。
- 不用加「离开主菜单释放字标」那种细账：主菜单一局只进一次。

先试一张：
- 1920 级底图 `compress/mode=2`（VRAM 压缩，桌面是 BC7，`compress/high_quality=true`）：9.2 → 2.3 MB 一张。平涂 + 墨线的画在 BC7 下大体看不出，但大面积渐变（营地夜色、铸炉火光）可能起块。先压 `rest/bg_ruins.png` 一张，美术 / 游戏测试 1:1 截图对比；过了再推到 17 张，不过就只开 mipmap 不压。

### ⑥ 开局与装内容分帧（最后，先量再做）

- 装内容 0.8～1.1 s 发生在第一帧之前：窗口开着却一片空白。改法是启动屏（`ui/boot.gd` 字标）先出第一帧，内容分几帧装（每个 `load_*` 之间 `await process_frame`），装完再亮按钮 —— 要给导演加一个 `content_ready` 门，所有用到 `flow.*` 内容的入口（主菜单的「继续」判定、读档）都等它。
- 「新的游戏」1.1～1.7 s：里面 `RunSave.write` 是整份存档的序列化 + 写盘，可以在交代屏亮出来之后延后一帧再写（有存档对账 173 的规矩，写之前的状态和写之后一致，只是晚一帧）；生图、发包的份额没量过。
- 排期理由：一局一次、不是卡死；真要做先让 `perf_probe` 把 `begin()` 拆步计时（生图 / 发包 / 存档 / 建屏各多少），看大头在哪再决定分帧还是后台线程。放在 ①～⑤ 之后、作者本机核过 237 §6 之后。

### ⑦ 启动预热（补，作者 12:40 的反馈）

- 作者同步到 v4.14 重新导出后：头两次走到【迎战】仍「卡死」几秒后恢复，之后一切正常；GL 兼容模式下相同。→ 不是后端（① 关闭，不改默认），是**第一次走到战前 / 战斗要付的冷启动账**：系统字体第一次建（Windows 读 msyh.ttc / msyhbd.ttc 各十几 MB，现在只建一次但仍在第一次 `_draw` 里付）、战旗裁切着色器第一次编译（`UiMotion._clip`）、1920 级战前 / 战斗底图第一次解码。Windows 五秒不响应即标「无响应」。
- 修法：`GameDirector` 在启动屏字标亮出来之后、主菜单可点之前做一轮 `warm_up()`：`UiPalette.cjk_font() / cjk_font_bold() / title_font() / display_font() / numeral_font()` 各调一次并各画一个字到一张离屏 `Image`（让字体真的加载并栅格化一个字形）；`UiMotion.warm()` 建一次裁切 `ShaderMaterial` 挂到一个 1 像素的隐藏 `Control` 上过一帧（触发编译）；`UiTheme.art_cached` 预读 `battle/battle_bg`、战前底图、`chest/bg/*` 当前章的那张。分两三帧做（每帧一类），总共一两百毫秒，藏在字标淡入里。
- 和 ⑤ 的 `release_art` 不冲突：预热读进来的底图在离开对应屏时照旧释放，下次进屏再读一次（几十毫秒，不是秒级）。
- 测试：`test_warm_up_236`：预热后 `UiPalette._fonts` 五个键都在、`UiMotion` 的着色器非空、三张底图在缓存里；headless 下预热不报错。

## 三、排期

| 批 | 内容 | 谁 | 前提 |
|---|---|---|---|
| 甲 | ④ dispose、② 写盘上线程、③ 盖死即停（含可选隔帧）、⑤ 地图 mipmap + 石碑 1× + `release_art`、⑦ 启动预热 | 执行 | 作者点头即做；石碑 1× 图找美术设计要 |
| 乙 | ⑤ 1920 级底图压一张试 | 执行压、美术 / 游戏测试看 | 甲之后 —— 甲 v4.16 落地后 2026-10-22 13:30 已派执行（`rest/bg_ruins` 一张，压前后 1:1 截图交美术设计看）；13:34 美术设计看过：渐变不起块、细线不糊，架构定推到全部 17 张；代价是安装包多约 40 MB（BC7 块不再无损压缩，一张 0.48 → 3.1 MB），显存一张 9.2 → 3.1 MB。宝箱底图预读不做（启动时没有「当前章」，且和离屏释放相反） |
| 丙 | ~~① 改默认后端~~ 关闭：作者 12:22 A/B，GL 下同样卡，不是后端 | — | — |
| 丁 | ⑥ 分帧 | 执行 | ①～⑤ 落地、作者本机复测后仍嫌慢，先拆步计时 |

## 四、待作者定（没回音按推荐）

1. 甲批四项直接做（推荐）。
2. ~~① 渲染后端 A/B~~ —— 作者 12:22 已试：GL 下一样，不改。
3. ⑤ 1920 级底图压缩：先试一张（推荐）/ 不压。
4. ⑥ 分帧：先放着（推荐）/ 现在就做。

## 五、派工

- **执行**：甲批一单，作者 2026-10-22 12:52「发吧」确认，已派；乙、丙、丁按 §三 的前提。
- **代码审阅精简**：没有新活；237 §4.1 第二批照旧自行合并。甲批和它的第二批都动 `map_view` / `ground_layer`，谁后合谁解冲突。
- **美术设计**：石碑 1× 导出一张（`ledger_stele` 源文件按 922 × 634 出）。 224 补充三已让美术设计重出去线的石板（1x + @2x 都在 out/v2/），执行按 ⑤ 直接用 1x 那张即可，不用再另要。

## 六、甲批落地（执行，2026-10-22，v4.16）

- **④ 放旧局**：`RunModule` 基类收了 `_run` 和 `dispose()`（九个模块不再各写一份 `_run`）；`FaithPower / RunSkills / HunterSystem / ErosionField` 各加 `dispose()`；`RunHooks.clear()`；`RunState.dispose()` 撤 hook → 模块 `dispose` → 清模块表 → 四个系统 `dispose` → 把局与旅程 / 时钟 / 节点事件 / 棋盘 / 仓 / 钱 / 体力 / 待拾取身上所有信号的连接断掉（`_wire_events` 的 lambda 都抓着局）。`GameFlow._drop_run` 在 `_reset_run` 与 `_adopt`（换的不是同一局时）里把旧局的 `dispose` 延到下一帧。`events` 不置空（换屏那一帧的旧屏退出时可能还摸它）。测试 `test_run_dispose_236`：dispose 后弱引用为空；对照组不 dispose 放不掉。
- **② 战斗日志**：`BattleTraceWriter.write` 主线程只定文件头和文件名，拼三份文本、写盘、`prune` 交 `WorkerThreadPool`；下一场开写前、`BattleArchive.list()`（回放浏览器）前、关窗（`NOTIFICATION_WM_CLOSE_REQUEST`）前 `flush()`。`test_battle_trace` 查文件前 flush，并断言最后一场是交给了线程。
- **③ 盖死即停 —— 和方案不一样的地方**：方案把战斗、战前、搜刮列为「整屏底图」，但 226 之后这三屏是**居中的铜面板 + 半透明压暗**，地图从四周透出来（截图核过）；藏掉底屏会露出空底，所以它们 `covers_base()` 仍是 false。真正盖死的是**铸炉、休息营地、宝箱**三屏（自带不透明整屏底），只这三个返回 true。导演 `_sync_base()`：盖死的叠层淡入完（`modulate.a` 到 1）才把地图屏 `visible = false`、`PROCESS_MODE_DISABLED`，撤掉 / 换掉 / 收起时恢复。透出地图的叠层开着时地图隔帧重绘（`MapView.throttled`，60 → 30 Hz）—— 战斗、战前、搜刮走的是这一条。测试 `test_director_covers_236`。
- **⑤ 贴图**：五张地图底图 `.import` 开 `mipmaps/generate`（不设 size_limit），`MapView.texture_filter = LINEAR_WITH_MIPMAPS` 才用得上；`result/ledger_stele.png` 换美术设计 224 补充三重出的 1× 图（922 × 634），`origin [-29, -29]` 与 `draw_size` 不动（两者本来就是 1× 设计坐标，美术那份 json 也是这个数，方案里「改 −14」不用改）。`UiTheme.release_art(prefix)` / `art_is_cached(name)`：铸炉屏退出放 `forge/bg_`、战斗屏退出放 `battle/battle_bg`；其余整屏底图（营地、宝箱、主菜单、库房）走的是 `UiTheme.art()` / `load()`，没进 `_art_cache`，节点放掉就跟着放，不用另放。
- **⑦ 启动预热**：`GameDirector.warm_up()` 在 `_ready` 末尾跑，主菜单亮起来的三帧里各做一类：五种字体 + 两种系统字体各量一次字、挂一块看不见的 2 × 2 小块把字按 16 / 22 / 24 号画一遍（字形进缓存）；同一块挂上裁切材质（`UiMotion.warm`）让着色器编译；`art_cached(battle/battle_bg)` 预读斗技场底图，然后放掉那一小块。**宝箱底图没预热**：它在 `assets/chest/bg/`，不在 `art_cached` 的根下，而且宝箱不在「第一次迎战卡」那条路上。测试 `test_warm_up_236`。

## 七、乙批落地（执行，2026-10-22，v4.18）

- 先试 `rest/bg_ruins` 一张（BC7 高质量 + mipmap），1920 × 1080 同机位压前 / 压后与 2× 局部在 `/mnt/project-files/art/ui/rest/bc7_trial/`：整图平均差 < 1/255、最大 14/255，美术设计看过夜空渐变、星点、细墨线与月牙边都没问题；架构设计同意安装包多约 40 MB（每张导入后 3.1 MB，原来无损 0.48 MB 左右）换显存每张 9.2 → 3.1 MB（含 mipmap）。
- 推到 17 张：`rest/bg_*` 4、`forge/bg_*` 4（含英文版）、`assets/chest/bg/*` 5、`setup/bg_*` 3、`battle/battle_bg` 1，`.import` 改 `compress/mode=2`、`high_quality=true`、`mipmaps/generate=true`。主菜单三张（2112 × 1320）、基地与结算库房（1920 × 1080）没在这 17 张里，照旧无损。
- 读回像素的地方只有营地小件的点击遮罩（`rest_camp_screen._mask`，本来就先 `decompress()`），不读底图，压了不受影响。宝箱底图预读不做（架构设计同意）。
