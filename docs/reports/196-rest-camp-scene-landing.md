# 196 休息点整屏换成夜晚营地：落地报告（含 194 §4 铸炉屏换美术的去向）

> 2026-10-18 晚，架构设计。作者在「UI替换美术」线程定稿（21:24 提出四件造物、21:34「甲最好」、21:36 新手教程三档 + 背景改夜晚、21:40「ok」）。素材在 `/mnt/project-files/art/ui/rest/`（`README.md`、`out/`、`out/@2x/`、`out/layout.json`，预览 `final_compare.png`、`final_tutorial.png`）。
> 本篇把定稿翻成代码与数据改动，派「架构方案执行」。本线程不改代码。

## 0. 结论

休息点不再走通用事件屏（石板 + 左图右选项），而是一整屏夜晚营地：底图按章节换，四件造物各对应 `rest_default` 的一个选项，点造物 = 选那一项；右边路标 = 「继续赶路」。悬停亮铜圈 + 170 样式悬浮窗（名字 / 当前效果）。用过的造物换成用过的图；没有信仰时祭坛照摆、灰掉、不能点（**不再隐藏**）。歇完不再跳「休息区」结果屏，营地里篝火熄掉、底下冒一行「体力 +N」。新手教程三档摆位按事件里有哪几件造物自动选。

## 1. 现状（要替换的东西）

- 休息点踩上去 → `NodeEvents.handle` 挂起 `rest_default` → `GameDirector` 开 `EventScreen`（`ui/game/event_screen.gd`）：石板框，左栏配图，右栏五个按钮；条件没过且 `hide_when_locked` 的选项不画（神坛没信仰 / 用过的歇脚都这样藏）。
- 选「歇一会儿 / 扎营」→ `proceed` → `NodeEvents._proceed(rest)` 回体力、`rested.emit` → `GameFlow` 推一屏 `Screen.REST`（`ui/game/rest_screen.gd`，30 行：「歇了一会儿。体力 +N」+ 继续）。
- 「神坛」/「铸炉」→ `altar_opened` / `forge_opened` → 各自的屏；回来是地图。站在点上再开（`GameFlow.reopen_node`，`rest: true` 分支）= 重新 `handle` 这个点，再进事件屏。
- 新手教程：只有第三章地图 `data/maps/tutorial3.json` 有两个休息点，事件 `tut3_rest_1` / `tut3_rest_2`（神坛 + 歇一会儿 + 继续赶路，没有扎营、铸炉）。第一、二章地图没有休息点；`node_rules/prologue.json` 也没有 `events_by_type`。

## 2. 新屏 `RestCampScreen`（`ui/game/rest_camp_screen.gd`）

### 2.1 什么时候开它

`EventDef` 加一个字段 `scene: StringName`（空 = 通用事件屏；`"rest_camp"` = 营地屏）。`rest_default`、`tut3_rest_1`、`tut3_rest_2` 三份写 `"scene": "rest_camp"`。`GameDirector` 开 `Screen.EVENT` 时看 `def.scene`：是 `rest_camp` 就用 `RestCampScreen`，否则照旧 `EventScreen`。选项页 / 结果页的区分、`restore`、`reopen_node` 的 `rest: true` 分支都不用动 —— 营地屏就是这个事件的选项页。

不按节点类型判断而按事件字段：以后别的事件（营地遭遇、村落）也能借这一屏，休息点的事件编辑器里也看得见这一项。

### 2.2 选项 → 造物（不改数据结构）

一个选项是哪件造物，看它的后果：

| 后果里有 | 造物 | 图（未用 / 用过） | 名字 |
| --- | --- | --- | --- |
| 只有 `proceed` | 篝火 `fire` | `fire_lit` + 底下 `fire_light` / `fire_out` | 篝火 |
| `pass_time` + `proceed` | 帐篷 `tent` | `tent` / `tent_used` | 帐篷 |
| `open_altar` | 祭坛 `altar` | `altar` + 顶上徽章 / `altar_used` | 祭坛 |
| `open_forge` | 铁炉 `forge` | `forge_lit` / `forge_cold` | 铁炉 |
| 没有后果 | 路标 `sign` | `sign`（不压暗、永不变） | 继续赶路 |

对不上的选项（以后作者加的别的后果）退回画成屏下方一排普通按钮，不丢功能。`EventOption` 不加字段。

### 2.3 用过 / 锁住 = 换图，不藏

- 选项 `option_state(i)` 不 ok → 造物画「用过」那张、不响应点击，悬浮窗第二行写 `locked_reason`（「没有信仰」「这一份用过了」）。**营地屏忽略 `hide_when_locked`**（数据不改，通用事件屏仍照它藏）。这就是 README 里「没有信仰时祭坛照样摆着」那一条的落法。
- 篝火与帐篷共用 `rest_part_unused`：用了一个两个都不 ok → 两张都换成用过的；`fire_light` 只在篝火 ok 时画。
- 祭坛顶上的徽章：当前神明 `assets/ui/faith/<god>.png`，位置 = 祭坛原点 + `_altar_medal.offset`（0, −235），尺寸见 §7 待定 1；没有信仰不画徽章。

### 2.4 悬停与点击

- 每件造物一个 `CampPiece`（`Control`，`_draw` 用 `UiTheme.art_cached`，**不许直接 load**），`_has_point` 按图的 alpha 判定（`BitMap.create_from_image_alpha` 一次、缓存），透明处点穿到底图。
- 悬停：脚下先画 `hover_ring`（原点对齐造物原点），同时 `HoverTip.show_text`（和地图点 `map_screen._update_tooltip` 同一个 `HoverTip`、同一套跟随与钉住）。文字两行：名字 / 当前效果（§3 的选项文字），锁住时第二行换 `locked_reason`。
- 点击 = `flow.choose_event(i)`。路标也是选项，点它 = 继续赶路。Esc = 继续赶路（和事件屏一致）；数字键 1–5 仍按选项序。
- 「整理背包（B）」保留：屏左下一枚小按钮 + B 键，开合同事件屏（`toggle_bag`），营地不加石板。

### 2.5 歇完不跳屏

选篝火 / 帐篷后 `rested` 仍然发；`GameFlow` 里 `rested` → 推 `Screen.REST` 改成：**营地屏开着就不推**，由营地屏接信号：篝火换 `fire_out`、暖光消失、篝火脚下冒一行「体力 +N，现在 x / y」（`UiTheme.rich_block`，深底白字，3 秒淡出）；然后 `run.events.handle(node)` 重新挂起（`reopen_node` 的 `rest: true` 分支做的事），营地重画成剩余状态。两份都用完（`settle_rest` 把点标 visited）→ 不再挂起，营地屏留在原地，只剩路标能点。`rest_screen.gd` 删除，`Screen.REST` 枚举保留一格不用（存档不记屏，删枚举值也行，交执行按方便）。

神坛 / 铸炉仍是它们自己的屏盖在上面；关掉后回到营地还是回地图见 §7 待定 2。

## 3. 数据：`rest_default` 与两份教程事件的文字

造物名字由 §2.2 定，选项文字只写**当前效果**（作者例：「篝火 / 回 1 点体力」「帐篷 / 倒计时 −2，回 3 点体力」）。通用事件屏不再给这三份事件画按钮，所以文字可以去掉动词：

| 选项 | 现在 | 改成 |
| --- | --- | --- |
| 篝火 | 歇一会儿（回 {rest_restore} 点体力） | 回 {rest_restore} 点体力 |
| 帐篷 | 扎营（倒计时 −{pass_time_actions}，回 {rest_total} 点体力） | 倒计时 −{pass_time_actions}，回 {rest_total} 点体力 |
| 祭坛 | 神坛（献祭或特殊操作，二选一） | 献祭或特殊操作，二选一 |
| 铁炉 | 铸炉（三件道具熔成一枚铸牌） | 三件道具熔成一枚铸牌 |
| 路标 | 继续赶路（不算用掉） | 不算用掉 |

`title` / `text` 不再显示（营地没有正文）；保留在 json 里给编辑器看。`help_pages/rest_point.json` 第一句改写：「休息点是一片营地：点篝火歇一会儿回体力，点帐篷扎营多扣倒计时、多回体力，有信仰时能点祭坛，铁炉能铸牌，右边的路标是继续赶路、不算用掉。」后半段不动。

**教程事件**：`tut3_rest_1` / `tut3_rest_2` 现在是篝火 + 祭坛，美术没有这一档摆位（只有篝火 / 篝火帐篷 / 篝火帐篷祭坛）。推荐给两份都加「扎营」选项（和 `rest_default` 同一条，`hide_when_locked` 照旧），落到 `tutorial_fire_tent_altar`；顺带新手就见过扎营。另两档 `tutorial_fire` / `tutorial_fire_tent` 现在没有事件用，留给以后第一、二章加休息点时（那时 `node_rules/prologue.json` 要补 `events_by_type.rest`，否则休息点没事件会走老路直接回体力）。

## 4. 摆位、缩放、底图

- `layout.json` 原样复制到 `assets/ui/rest/layout.json`，切图 `out/*.png` 复制到 `assets/ui/rest/`（只收 1x；场景在 1600×1000 视口下缩到约 0.83，1x 够）。`bg_<章节>.json` 一起带过去（`tone: dark`、`size`、`stretch`）。
- 底图：id 跟宝箱皮肤走 —— `ChapterDef.chest_skin`（free_mode = imperial_camp、prologue_2 = north_woods、prologue_3 = cursed_depths），没有的章节用 `ruins`。`assets/ui/rest/bg_<id>.png`，cover 铺满（同 `chest_screen.gd` 73–87 的做法），tone 写到内容区的 meta 给字取色。
- 造物坐标：`variants.<档>.<造物> = [x, y]` 是 1920×1200 场景坐标里的落地中心；换算到屏幕 = 底图 cover 的同一个缩放 s 与偏移（`s = max(w/1920, h/1200)`，居中），造物按 s 缩放绘制，原点 `pieces.<图>.origin` 对齐落地中心。窗口改大小时重算（`chest_screen` 的 `_place` 同款）。
- 档位选择：事件里能对上的造物集合 → {篝火} = `tutorial_fire`，{篝火, 帐篷} = `tutorial_fire_tent`，{篝火, 帐篷, 祭坛} = `tutorial_fire_tent_altar`，其余（含铁炉）= `full`。集合不在表里 → `full`，没有的造物不画。
- 绘制顺序：底图 → `fire_light` → 造物按 y（落地中心）从小到大 → 徽章 → `hover_ring`（在悬停造物之前画一次，造物压在它上面）→ 「体力 +N」文字 → 悬浮窗。

## 5. 194 §4：铸炉屏换美术

休息点整屏定了夜晚营地，铸炉屏开在它上面，就该是「走到铁炉前」的近景，而不是另一块石板。给美术的出样方向（走「UI替换美术」线程，先出样再派执行）：

- 一屏近景：炉膛在上方中间（火光是整屏唯一暖色，呼应营地里的 `forge_lit`），炉前一方铁砧；三个槽是铁砧上的三个凹槽，从左到右【时机】【效果】【数值】，槽口刻字；出牌槽在铁砧右端一小块铁板上；「铸」是炉旁的风箱把手（能按时发亮），「返回」是左下角的小路标（和营地路标同款）。
- 现有 `forge_screen.gd` 的结构不动（`GridInventory` 4×4 三槽、1×1 出牌槽、194 §2 三行小字、`_forge_btn`）：换美术只换底与框 —— 底图 1920×1200 cover、三槽与出牌槽的位置由 json 给、小字写在槽下的石面上（深底白字）。
- 铸过了：炉膛变 `forge_cold` 的冷色，风箱把手灰掉。
- 待办 `/mnt/project-files/reference/待做-界面.md` 里休息点那一条划掉，铸炉屏改成「等美术出样」。

## 6. 改动清单与测试

**数据** `data/authoring/events/rest_default.json`、`tut3_rest_1.json`、`tut3_rest_2.json`：`scene: "rest_camp"`、选项文字按 §3、教程两份加扎营；`help_pages/rest_point.json` 第一句。
**资源** `assets/ui/rest/`：`layout.json`、15 张切图、4 张底图 + 4 份 json。
**代码**
- `core/run/events/event_def.gd`：`scene` 字段；导入器只认空或 `rest_camp`。
- `ui/game/rest_camp_screen.gd`（新）+ `CampPiece`；`ui/game/game_director.gd` 按 `def.scene` 选屏；`ui/event_editor` 的事件编辑器加「场景」下拉（空 / 营地）。
- `core/run/game_flow.gd` 1288：`rested` 不再推 `Screen.REST`，改为营地屏接；`ui/game/rest_screen.gd` 删除。
- 徽章与底图读取都走 `UiTheme.art_cached` / `EventImage.load_texture`。
**测试** `tests/run/test_rest_event_193.gd` 的两条选项文字断言改成新文字（「回 N 点体力」「倒计时 −2，回 N+1 点体力」）；新 `tests/ui/test_rest_camp_196.gd`：rest_default 落 `full`、tut3_rest 落 `tutorial_fire_tent_altar`；没信仰祭坛画 `altar_used` 且 `click` 不生效、悬浮窗第二行是锁住原因；点篝火后体力涨、篝火与帐篷都换用过的图、不推 `Screen.REST`、再点帐篷无效；点路标回地图且点不灰；`hide_when_locked` 的祭坛在通用事件屏仍藏（别的事件不受影响）；`_has_point` 透明处不命中。无头截图四章 + 教程档各一张到 `/mnt/project-files/screenshots/196/`。

## 7. 待定（默认按推荐）

1. 徽章尺寸：`layout.json` 写 78 px，现有徽章 32 px（@2x 64）。推荐 **A** 用 @2x 那张画 64 px（不放大糊），B 请美术补 96 px 一套。
2. 从神坛 / 铸炉屏返回：推荐 **A 回营地**（还有东西没用时；两份都用完回地图），B 照旧回地图。
3. 教程两份事件加「扎营」（§3）：推荐 **A 加**，B 请美术补「篝火 + 祭坛」一档摆位。
4. 「体力 +N」那一行：推荐 **A** 篝火脚下冒字 3 秒，B 不冒字只换图（HUD 心已经会跳）。

## 8. 派工

执行：§3、§4、§6 全部；测试与截图；合并后通知本地仓库同步。美术（经 UI替换美术）：§5 铸炉屏出样；§7.1 若选 B 补徽章。
