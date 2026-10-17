# 186 · 方案：调试台对玩家隐藏 —— 拒绝原因与要紧提示另开「提示行」，日志与开发开关只留给开发包

> 来由：作者 2026-10-17 16:07「最后的文本描述也不需要，那个是内部说明，不该给玩家看，类似的情况我需要你调用查询线程对整个游戏进行一次检索，隐藏或者删掉那些文字」。「查询」线程的清单（`/mnt/project-files/audits/2026-10-17-internal-text-for-players.md` 一、2 / 一、3）指出地图屏与基地屏顶栏常驻的「调试台」箭头是结构性的一条，且藏之前要先给「走不了：…」这类拒绝原因另开出口。协调者 16:20 转来请出方案。
>
> 已转「架构方案执行」；清单里别的条目（小修）不在本篇里。

## 0. 结论

1. **一个开关**：`DevGate.on()` = 非导出包（`not OS.has_feature("template")`，和清单、`BattleArchive.default_on()` 一致），测试里可强制成玩家包。调试台箭头与抽屉、设置里的「调试」节、`GameSettings.debug_mode` 的效果，全部只在开关开着时存在；玩家包里**不造**，不是藏起来。
2. **玩家出口 = 地图上一行「提示行」**：顶端栏正下方居中一行墨字，来了就显示 3 秒淡出（要紧的 5 秒），最多叠两行。承接两类话：**拒绝**（走不了、撤不了、技能用不了、没有能再开的界面）和**要紧的局内提示**（倒计时只剩几步、撤离点关了、侵蚀预警 / 推进、附近有动静、保险箱关上了、到了撤离点）。全部改成玩家用语：不写点号、不写内部原因、不写步数成本。
3. **日志不给玩家**：抽屉里的事件日志（带点号、花费、内部说明）继续记，只在开发包里看得到；玩家需要知道的那几句另走提示行（§2.3 表），不是把日志搬出来。
4. **基地屏的调试台整个是开发物**（调试模式、局外 buff 开关、解锁占位开关、科技等级、最近几局）：玩家包里不造；「最近几局」玩家在结算屏已经看过，不另开出口。
5. 顺带：倒计时读数里的「撤离点 12 剩 N 步关闭」改「最近的撤离点剩 N 步关闭」（清单三、2，同一个对象，一起改）。

## 1. 现状

| 东西 | 在哪 | 玩家看到什么 |
|---|---|---|
| 调试台箭头（地图） | `ui/hud/hud_layout.gd:61` `BAR_RIGHT` 第四件 `dev_drawer`；`ui/game/map_screen.gd:891-893` | 顶栏右侧常驻箭头，点开 `DevDrawer`（`ui/game/dev_drawer.gd`，宽 420，盖在地图右侧） |
| 抽屉内容（地图） | `map_screen.gd:946-981` `_build_drawer()` | 「调试模式：开 / 关（设置里开关）」、**提示行 `_status`**、「地上 N 件」、「日志」、「下局种子」输入框、重放教程、摆读数 / 保存布局（写 `res://data/authoring/ui_layouts/map.json`）/ 重置 |
| 提示行 `_say()` | `map_screen.gd:1033`；调用点 :107、:121、:124、:135、:232、:396、:515-518、:613、:776、:977-980、:1245 | 开局「从出生点 3 出发（ring_outer）」、「走不了：从 12 走不到 37：不相邻，或那条路不能从这头走」、「撤不了：付不起（N 币）」、技能用不了的原因、「读数布局已保存」…… **全在抽屉里，抽屉收着时玩家什么都看不到** |
| 日志 `_note()` | `map_screen.gd:1042`；约 35 个调用点（:394-539、:779） | 「→ 12 搜索点（花 1 点）」「侵蚀预警：第 2 档还有 3 步就被侵蚀」「倒计时只剩 5 步！」「保险箱关上了：N 件送回基地」「附近有动静……」「离开点 12：地上的 … 留在了那里」…… 同上，玩家看不到 |
| 调试台（基地） | `ui/game/meta_screen.gd:188-288`、箭头 :288 | 「调试模式」按钮、开发 buff 开关、「局外解锁　占位：开关列表，将来由成长系统决定」+ 原始 id 开关（**能改存档解锁**）、科技等级数字框、「最近几局」带种子 |
| 设置「调试」节 | `ui/game/settings_screen.gd:82-85` | 「调试模式：地图上摆出只给开发看的东西（事件日志）…（150）」 |
| 调试模式默认 | `core/settings/game_settings.gd:36` `DEBUG_MODE_DEFAULT = true` | 新玩家默认开着；影响 `debug_only` 的读数件（`hud_host.gd:77`） |

关键事实：玩家需要的信息里，**只有拒绝原因和几句局内提示**是别处没有的；其余（种子、点号、花费、布局）本来就是开发读数。`refused` 信号的原因串在 `core/run/map_travel.gd:80`、`:186-195`，是写给开发看的（带点号、带报告号 8-1）。

## 2. 方案

### 2.1 开关：`DevGate`

- 新建 `core/dev_gate.gd`（`class_name DevGate`）：
  - `static var force_player := false`（测试用）；
  - `static func on() -> bool: return not force_player and not OS.has_feature("template")`。
- `BattleArchive.default_on()` 改成调它（同一个判断，一处）。
- `GameSettings.debug_mode`：存读不变；读取处统一走 `GameSettings.debug_on()` = `DevGate.on() and debug_mode`。玩家包里永远 false，`debug_only` 的读数件（150 补 2）在玩家包里不造。`DEBUG_MODE_DEFAULT` 不动（开发默认开）。

### 2.2 调试台只在开发包里有

- **地图**：`HudWidgets` 加 `DEV_ONLY: Array[StringName] = [&"dev_drawer"]`；`HudHost.setup()` 遇到它且 `not DevGate.on()` → 跳过（和 `debug_only` 同一个分支位置，`hud_host.gd:77`）。`MapScreen._build_parts()` / `_build_drawer()`：`DevGate.on()` 为假时 `_drawer` 为 null，`_status`、`_log`、`_ground_line`、`_debug_line` 照样造（不进树；`_say` / `_note` 继续写它们，测试仍能读），`dev_drawer()` 返回 null，`toggle_dev_drawer()` 返回 false。布局文件里旧存的 `dev_drawer` 条目在玩家包里被跳过即可，`HudLayout.VERSION` 不用加。
- **基地**：`meta_screen.gd:188-288` 整段包进 `if DevGate.on():`；箭头不 `add_child`；`toggle_dev_drawer()` 返回 false。
- **设置**：「调试」节（:82-85）与「节点浮窗预览」（:47、:259）挪进 `:87` 的开发块（它已经按 `default_on()` 判断）。
- `DevDrawer` 本身不改。

### 2.3 玩家出口：提示行 `NoticeLine`

**样子**：新读数件 `ui/hud/widgets/notice_widget.gd`（id `&"notice"`），锚 `bar_center`、第 1 行（倒计时在第 0 行），宽 ≤ 640，16 号正文，颜色按地图纸的深浅取（UI 深浅规则：纸浅 → 墨字；诅咒深处的黑纸 → 亮字），字外 2 px 纸色描边保证压在线稿上也看得清。没有底板、没有图。来一句显示 3 秒再 0.4 秒淡出；标成「要紧」的 5 秒、用 `danger` 色；同时最多两行，新的在下，第三句来了最上面那句立刻淡掉。`mouse_filter = IGNORE`。默认布局进 `HudLayout.default_for("map")`（`VERSION` +1：默认布局改了）；摆读数时能挪。

**接口**：`HudHost.notice(text: String, urgent := false)`；`MapScreen.say(text)`（腰带已经在用）改成走它；新增 `MapScreen.warn(text)` = `urgent`。`_say()` 保留，只写抽屉里的开发提示行。

**谁走提示行（玩家用语，不写点号 / 花费 / 内部原因）**：

| 事 | 现在（抽屉） | 提示行写 | 要紧 |
|---|---|---|---|
| 想走不相邻的点（`travel.refused`） | 「走不了：从 12 走不到 37：不相邻，或那条路不能从这头走」 | 「那里走不过去」 | |
| 别的拒绝（意图过期、没有点、负步数） | 「走不了：意图过期：它以为在 12，人在 13」 | 「现在走不了」；原文 `push_warning` + 开发提示行 | |
| 等着开打 / 不在图上（`run_state.gd:235`） | 同上 | 「先把眼前的事做完」 | |
| 不在撤离点按撤离 | 「撤不了：不在撤离点上」 | 「这里不是撤离点」 | |
| 撤离点已关闭 | 「撤不了：这个撤离点已经关闭（倒计时过半）」 | 「这个撤离点已经关闭了」 | |
| 付不起 | 「撤不了：付不起（N 币）」 | 「钱不够：撤离要 N 币」（N 来自 `extract_fee`） | |
| 放大镜没东西 | 「这个点上没有可以再打开的界面」 | 「这里没有能再打开的东西」 | |
| 技能用不了（`flow.use_skill` 返回的原因） | 原因串 | 原样（这些串已是玩家用语：「没有能溜走的技能」等；执行时过一遍，带 id 的改掉） | |
| 旧档挑出生点 | 「先挑一个出生点（绿圈的「生」）」 | 「先在地图上挑一个出生点」 | |
| 倒计时只剩 N 步（`_on_moved` :539） | 日志红字 | 「倒计时只剩 N 步」 | 要紧 |
| 撤离点关闭（`countdown.notice`） | 「撤离点 12 关闭了：倒计时过半」 | 「有一个撤离点关闭了」 | 要紧 |
| 倒计时归零 | 日志 | 不走提示行（紧接着就是结算屏） | |
| 侵蚀预警 / 推进 / 全图 | 日志红字 | 「侵蚀快到了：还有 N 步」「外圈被侵蚀了」「全图都被侵蚀了，快撤」 | 要紧 |
| 附近有动静 / 被赶回 | 日志红字 | 「附近有动静……」「被赶了回来」 | 要紧 |
| 保险箱关上 | 日志紫字 | 「保险箱关上了：N 件送回基地」 | |
| 到了撤离点 | 日志 | 「到了撤离点：按「撤离」结束这一局」（付费的加「要 N 币」） | |
| 负重变级 | 日志 | 「负重变成「X」」 | |
| 神坛 `noted` | 日志黄字 | 原样（它的句子由信仰系统生成，清单二、10-13 另改） | |

不走提示行、只进开发日志：每一步的「→ 12 搜索点（花 1 点）」、原地耗步、读数布局、信力阶数、离开 / 回到点的地上物、「?」点揭晓、进账、打了谁几秒、搜索结束、休息 +N、开局的章节 / 种子 / 点号那句、「用了技能」。

### 2.4 开局那句

`map_screen.gd:107`「从出生点 3 出发（ring_outer）」与 :518「章节　种子 N：在点 N 上…」是开发读数 → 只进开发提示行。玩家开局需要的引导由 182 / 184 的棋子与小旗承担，不再写字。

## 3. 改动清单（给执行）

- `core/dev_gate.gd` 新建；`core/battle/battle_archive.gd` `default_on()` 改调它；`core/settings/game_settings.gd` 加 `debug_on()`；`hud_host.gd:77`、`map_screen.gd:932-940`、`meta_screen.gd:384-393`、`settings_screen.gd:209-268` 读 `debug_on()`。
- `ui/hud/hud_widgets.gd`：`DEV_ONLY`；`KINDS` 加 `&"notice"`；`PART_TITLES` 加「提示」。`ui/hud/hud_host.gd`：`setup()` 跳过 `DEV_ONLY`；`notice(text, urgent)`。`ui/hud/hud_layout.gd`：默认布局加 `notice`（`bar_center`，line 1），`VERSION` +1。
- `ui/hud/widgets/notice_widget.gd` 新建（§2.3 样子）。
- `ui/game/map_screen.gd`：`_build_parts` / `_build_drawer` 按 `DevGate.on()`；`say()` / `warn()` 走 `_hud_host.notice`；§2.3 表里每个调用点改口（拒绝走 `say`，要紧的走 `warn`，日志照记）；`_on_moved` 的倒计时红字同时 `warn`。
- `core/run/map_travel.gd`：`refused` 的原因串改成玩家用语 + 一个机器可读的 `code`（`&"not_adjacent"` / `&"stale"` / `&"no_node"` / `&"busy"`），信号加参数 `refused(intent, why, code)`；地图屏按 `code` 选提示行的话，原串只 `push_warning`。`core/run/modules/countdown_module.gd:165` 的 `notice` 文案改「有一个撤离点关闭了」；`ui/hud/widgets/countdown_widget.gd:35` 改「最近的撤离点剩 N 步关闭」。
- `ui/game/meta_screen.gd:188-288`：整段 `if DevGate.on()`。
- `ui/game/settings_screen.gd`：调试节与节点浮窗预览挪进开发块。
- 文案：新句子全部走 `UiText` 键（中 / 英各一份），数字来自字段（`TextLint.STRICT`）。新字（「赶」「紧」等）按 168 重裁字体子集。
- 测试：
  1. `DevGate.force_player = true` 下开地图屏：`dev_drawer()` 为 null、顶栏右槽只有背包 / 放大镜 /（技能）、`hud().widget(&"notice")` 存在；基地屏 `toggle_dev_drawer()` 为 false、找不到 `DevDrawer`；设置屏找不到「调试模式」。
  2. 点不相邻的点 → `notice` 当前文字 = 「那里走不过去」，不含数字；抽屉提示行（`_status.text`）仍含原因（开发包）。
  3. 倒计时只剩 N 步 → `notice` 要紧、`danger` 色，5 秒后淡掉；两句叠加第三句时最老的消失。
  4. `tests/ui/test_hud_150.gd:36、55`、`test_base_drawer_139.gd` 在开发包下照旧通过（`force_player` 默认 false）。
  5. `HudLayout` 旧文件（无 `notice`）读入后默认布局补上它。

## 4. 待定（默认按推荐）

1. **提示行位置** —— 推荐 **甲**：顶端栏正下方居中（倒计时下面一行，眼睛本来就看那里）。乙：地图底部居中（离腰带近，但会压住南边的节点）。
2. **开发包里调试台还要不要** —— 推荐 **甲**：开发包原样保留（作者调试、摆读数都在用）。乙：也删，统一走设置里的开发块（改动大，收益小）。
3. **日志要不要给玩家一个「行记」面板** —— 推荐 **甲**：不给，要紧的话走提示行就够（作者 16:07 的取向是少字）。乙：放大镜旁加「行记」按钮开一个只读滚动面板，写玩家用语的历次事件（另提一篇）。
4. **`debug_mode` 默认值** —— 推荐 **甲**：不动（开发默认开），玩家包里由 `debug_on()` 压成 false。乙：默认改 false（`test_hud_150.gd:55` 要改）。
