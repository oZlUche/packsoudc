# 240 跳过序章改成开场一问（2026-10-22）

作者 13:43：「关于跳过序章的选项，改为放在游戏一开始时，第一个事件（说明）结束后，紧接着跳出一个弹窗问玩家是否要接受教程，玩家选择【不需要】即自动跳过」。作者定了入口和两个按钮的字，本篇定弹窗长什么样、「不需要」之后去哪、主菜单那条怎么处理；待定按推荐，直接派执行。

## 〇 一句话

**主菜单的「跳过序章」拿掉；新存档开进序章一、读完开场事件「废墟边缘」点「出发」之后，地图上立刻弹一张羊皮纸小卡「要带你走一遍吗？」，【需要】关卡继续教程，【不需要】= 221 G 的那一套（三章解锁 + 望远镜 + 两枚护符 + 开局套）立刻生效、这一局悄悄结束、直接到开局屏选图。** 一份存档只问一次。

## 一、现状（v4.16）

- 221 G：主菜单「新的游戏」下面一行「跳过序章」，点两次确认（`MainMenu.skip_prologue` → `GameFlow.start_new_game_skipping` → `new_game_in(n, true)` → `skip_prologue()` 再 `new_run()`）；位满了经存档位屏带 `skip_prologue` 载荷。`skip_prologue()`（`game_flow.gd:207`）= 发开局套、三章 `grants_unlock`、`starting_keepsakes`（望远镜）、`SKIP_PROLOGUE_ITEMS` 两枚护符、存盘。
- 序章一：`prologue.json` `skip_setup` + `intro_event: tut_intro`；`begin_direct()` 开局后 `show_intro()` 把「废墟边缘」挂成待选事件，书页弹出；唯一选项「出发」→ `choose_event(0)` → `_flush()` 回地图，教练接着走。
- 现成的弹窗：`MapScreen.show_rules`（226 批四）—— `_shade` 压暗 + `_modal_panel` + 羊皮纸 `PANEL_PARCHMENT` + `ScrollKey.primary`。

## 二、方案（推荐甲）

| | 弹窗 | 评 |
|---|---|---|
| **甲 羊皮纸小卡（推荐）** | 书页合上、回到地图的同一帧，`MapScreen.show_tutorial_ask()`：压暗 + 规则卡同款羊皮纸，一行标题、两三行正文、两把石刻键【需要】【不需要】并排 | 和作者说的「跳出一个弹窗」一致；规则卡的壳子现成，不用新画 |
| 乙 再翻一页书 | `tut_intro` 的「出发」接 `next_event: tut_ask`，问句做成第二个事件 | 全是数据、顺手有英文；但读起来是「书又翻了一页」，不是弹窗，而且「不需要」要新增一种事件后果 |

细节（甲）：
- **何时弹**：`GameFlow.choose_event` 里，选完的是 `run.chapter.intro_event`、这一章是 `tutorial_chapters()[0]`、局外旗标 `tutorial_asked` 没立 → `_flush()` 之后 `tutorial_ask.emit()`（新信号）；`MapScreen` 接到就弹卡。读档回来不补问（旗标没立的旧存档也只在这一刻问；以后开新档才会碰到）。
- **文案**（交代人口吻，中英都写进 `UiText`，不用数字）：标题 `tut_ask.title`「要带你走一遍吗？」/ Want a walkthrough?；正文 `tut_ask.body`「序章三张图手把手教你搜、打、撤。老手可以直接去自由模式，开局那套和两枚护符照样在仓库里等你。」/ "The three prologue runs teach you to search, fight and get out. If you know the drill, head straight for free mode: the starter kit and both charms will be waiting in your storeroom." 键 `tut_ask.yes`【需要】/ Yes、`tut_ask.no`【不需要】/ No need。
- **【需要】**：`meta.set_flag(&"tutorial_asked")`、存盘、关卡；教练照旧（卡在教练之上，教练第一步等卡关了再走 —— 执行看 `Coach` 是不是已经在等叠层）。
- **【不需要】**：`GameFlow.decline_tutorial()`：`set_flag(&"tutorial_asked")` → `skip_prologue()`（原函数不动）→ 这一局**悄悄结束**：不进结算、不计死亡 / 场次（`_reset_run()` + `run_changed.emit(null)`，和 `to_main_menu` 的前两句一样）→ `new_run()`：教程此时已全通，落到开局屏（`Screen.SETUP`）选自由模式。218 的出发交代照旧在第一次「出发」前弹。
- **主菜单**：「跳过序章」那一行、`_skip_armed` / `disarm_skip` / `SKIP_ARM_SEC`、`start_new_game_skipping`、存档位屏的 `skip_prologue` 载荷、`menu.skip_prologue*` 两个键都删（221 G 的入口整个搬家）。`skip_prologue()` 本体留着给【不需要】用。
- **只问一次**：旗标 `tutorial_asked` 跟局外存档；序章二、三不问；新的游戏（新档）再问。

## 三、改动范围

- `core/run/game_flow.gd`：`signal tutorial_ask`；`choose_event` 末尾判定发信号；新 `decline_tutorial()`、`accept_tutorial()`；删 `start_new_game_skipping` 与 `new_game_in` / `_start_new` 的 `skip` 参数。
- `ui/game/map_screen.gd`：`show_tutorial_ask()` / `close_tutorial_ask()`，壳子照 `show_rules`；两把键 `ScrollKey.primary`（需要）+ `ScrollKey.make`（不需要）。
- `ui/game/main_menu.gd`、`ui/game/slots_screen.gd`：删跳过入口与载荷。
- `core/text/ui_text.gd`：删 `menu.skip_prologue` / `menu.skip_prologue_confirm`，加 `tut_ask.*` 四键（中英）。
- 测试：`tests/ui/test_skip_prologue_221.gd` 改成走新入口（开新档 → 过开场事件 → 收到 `tutorial_ask` → `decline_tutorial()` → 三章解锁、望远镜、两枚护符、仓库有开局套、`run == null`、落在开局屏；`accept_tutorial()` → 旗标立、局还在；第二次开场不再问）；`test_main_menu_197` 去掉跳过那行的断言；226 裸露文字守门测试：卡上的字都在羊皮纸 / 键上，不用豁免。
- 不动数据（事件 json 不改）。

## 四、派工

执行一单，直接做。

## 五、落地（执行，2026-10-22，v4.21）

按甲做。`GameFlow`：新信号 `tutorial_ask`；`choose_event` 选的是当前章 `intro_event`、这一章是第一张教程、局外旗标 `TUTORIAL_ASKED`（`tutorial_asked`）没立 → `_flush()` 回到地图后发信号；`accept_tutorial()` 立旗标存盘；`decline_tutorial()` 立旗标 → `skip_prologue()`（本体不动）→ 删局内存档（不然「继续」会回到序章一）→ `_reset_run()` + `run_changed.emit(null)` → `new_run()` 落开局屏。不进结算、不记场次。删了 `start_new_game_skipping`、`new_game_in` / `_start_new` 的跳过参数、存档位屏的 `skip_prologue` 载荷、主菜单那一行与武装 / 确认、`menu.skip_prologue*` 两个键。

`MapScreen.show_tutorial_ask()`：规则卡同款（压暗 + 铜框标题「要带你走一遍吗？」+ 羊皮纸正文），【需要】`ScrollKey.primary`、【不需要】`ScrollKey.make` 并排。卡开着时点地图、开背包、重开、教练都不动；Esc 不替玩家选。【需要】关卡后接着放教练。

测试：`test_skip_prologue_221` 改成走开场一问（字中英齐、旧键删了；【不需要】→ 三解锁 + 望远镜 + 两枚信物 + 开局套、局收掉、没有局内存档、场次不变、落开局屏、重读还在；【需要】→ 旗标立、局还在、Esc 不关卡、同一存档再开不再问）；`test_main_menu_197` 次档不再有「跳过序章」。截图：`/mnt/project-files/art/ui/tutorial_ask240/`（ask_zh、ask_en、after_decline）。
