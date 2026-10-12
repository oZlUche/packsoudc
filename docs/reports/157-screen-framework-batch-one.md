# 方案：各屏构成第一批 —— 叠层共用石板框、战前对阵式、回放时间轴与三种反馈、战败结算、事件代价图标与收获行（157）

> 来源：156 讨论稿 + 作者 2026-10-12 的拍板（156 第 16 节）。
> 性质：架构 · 实施。这一批**不等美术**：每一处都是「有图画图、没图按现在的样子画」的钩子 + 布局 / 交互改动，图到了直接放进 `assets/`。
> 待定项默认按推荐。不新增 `add_theme_` 覆写（棘轮 134 / 134）：新样式一律走 `UiTheme` 变体或画布。

## 0. 这一批做什么、不做什么

| 做 | 不做（等图或等下一批） |
|---|---|
| 1 叠层共用一块「石板框」+ 悬浮窗底 + 三种光标 + 叠层淡入 | 地图屏羊皮纸、当前位置标记、侵蚀晕染、右列蜡封按钮（作者：优先级最低） |
| 2 战前对阵式：名牌 + 肖像钩子、读数去掉「几件」、中缝、天平 | 容器屏垫图与尘土揭示、商店货架 / 店主 / 秤、休息篝火、神坛环 |
| 3 回放：时间轴（可拖）、三种反馈、收尾战报 | 基地场景化（作者按推荐：不做） |
| 4 结算：战败时保险箱格子放大居中 | 道具图（作者：不急） |
| 5 事件屏：选项代价图标、结果页收获行可拖进棋盘 | |

## 1. 叠层共用的石板框、悬浮窗底、光标、淡入

### 1.1 石板框 `OverlayFrame`

现状：八个叠层屏（事件、战前、回放、容器、商店、保险箱、神坛、宝箱）都走 `GameScreen._centered_panel()` → `_panel()`，一块 `PanelContainer` + 主题的面板样式；外框长什么样散在主题里，标题、收起 / 关闭按钮各屏自己摆。

改法：
- 新建 `ui/widgets/overlay_frame.gd`（`OverlayFrame extends PanelContainer`）：**标题条**（左标题、右一到两个槽：收起 / 关闭 / 返回，各屏往槽里放自己的按钮）+ **内容区**。`_centered_panel()` 内部改成造它，签名不变，各屏一行不改就换上；各屏现在自己 `_label(标题)` 的那一行搬进标题条（八处小改）。
- 外观：`UiTheme` 新增变体 `PANEL_OVERLAY`（框）与 `LABEL_OVERLAY_TITLE`（标题条）。`_fill` 里：`res://assets/ui/frame_stone.png` **存在**就用 `StyleBoxTexture` 九宫格（边距从 `assets/ui/frame_stone.json` 读：`{"margin": [l, t, r, b], "title_height": 36}`），不存在就是现在的 `StyleBoxFlat`。这就是 121 说的「换 `_fill`」的第一步，只换一个变体。
- 宝箱屏整屏背景（154 作者定）不套框：它直接铺背景，只有退出按钮；`chest_screen` 不走 `_centered_panel`，不受影响。

### 1.2 悬浮窗底

`HoverTip` 的主面板与侧边词条小窗用同一变体 `PANEL_TOOLTIP`（现在用 `PANEL_DARK`）；`_fill` 同样「`assets/ui/tooltip_paper.png` 有则九宫格、无则平面」。节点悬浮窗（`NodeTooltip`）、buff 悬浮窗（回放）都是 `HoverTip`，一处改全改。

### 1.3 光标

新建 `ui/ui_cursor.gd`（`UiCursor`，静态）：`apply()` 在游戏启动（`GameDirector._ready`）调一次，对 `CURSOR_ARROW` / `CURSOR_DRAG` / `CURSOR_CAN_DROP` / `CURSOR_FORBIDDEN` 四种各查 `assets/ui/cursor_<name>.png`，有图 `Input.set_custom_mouse_cursor`，没图跳过（系统光标）。`DragLayer` 拖着时按能不能放设 `Input.set_default_cursor_shape`（可放 `CAN_DROP`、不可放 `FORBIDDEN`、松手还原）—— 这一条不需要图就有质感。`FloatingWindow` 标题栏已经设了 `CURSOR_MOVE`，不动。

### 1.4 叠层淡入

`GameDirector._switch_screen` 加叠层时 `modulate.a` 0 → 1 用 `Tween` 走 0.15 秒；撤叠层直接撤（退出不等）。底屏之间（主菜单 ↔ 开局 ↔ 地图 ↔ 结算 ↔ 局外）0.2 秒淡入，墨水扫过的 shader 等美术方案。`GameSettings` 加 `ui_fades: bool = true`（设置屏一个开关；测试与截图工具关掉）。

### 1.5 测试

- `test_theme`：变体表多三个（`PANEL_OVERLAY`、`LABEL_OVERLAY_TITLE`、`PANEL_TOOLTIP`），棘轮不涨。
- 新 `tests/ui/test_overlay_frame.gd`：八个叠层屏 `open` 后树里有且只有一个 `OverlayFrame`；标题条文字 = 各屏的标题；没有 `frame_stone.png` 时样式是 `StyleBoxFlat`，造一张临时图放进 `user://` 走不通（`res://` 才算），所以九宫格分支用一个注入点 `UiTheme.asset_root`（默认 `res://assets/ui/`，测试指到 `res://tests/fixtures/ui/`，里面放一张 4×4 的 png）。
- `ui_fades` 关着时 `_switch_screen` 不造 Tween（现有屏幕测试全部关着跑，时序不变）。

## 2. 战前准备：对阵式

现状（`prebattle_screen.gd`）：标题一行、左「对手的棋盘 名字」+ 读数行「生命 N　约 X DPS　N 件：名字……」、右「我的棋盘与地上」、底下「开战」+ 腰带件。

改法：
- **读数**（作者定）：`_enemy_line` 只剩「生命 N　约 X DPS」。件数与名字删掉，不另放别处。
- **名牌** `Nameplate`（`ui/widgets/nameplate.gd`）：一块横条 —— 左边**肖像槽**（64×64），中间名字（大）+ 副行（对手：「N 档」；自己：角色身份），右边徽记槽（32×32）。肖像：`assets/portraits/enemies/<enemy_id>.png` / `assets/portraits/characters/<character_id>.png`，**没图不画槽**（条变短，不留空洞）；徽记：先不画（敌人定义里没有阵营字段，不为这个加字段 —— 等世界观里的阵营落成数据再说）。
- **布局**：左右两列等宽，中间一道竖缝（画布 `draw_line` 两条细线 + 中点一个菱形，`UiPalette.LINE`）；名牌各在自己那列顶上，棋盘在下。
- **天平**（待定 1）：中缝顶端一根短横杆，按双方 `rough_dps × max_hp` 的比值倾斜（`atan(log(ratio))` 限 ±25°），不写数字；自己这边用同一份编译（`EnemyKit.board_of` 对敌人、`BattleCompiler` 对自己的棋盘，`prebattle_screen` 已经两边都编过）。棋盘变了（拖进拖出）就重算。
- 「开战」按钮居中、主档；腰带件在它左右。

测试：`test_prebattle_*` 里断言读数行**不含**「件」字；名牌没图时没有肖像槽；天平角度随棋盘清空变化方向正确（自己空棋盘 → 杆往对手那边沉）。

## 3. 战斗回放：时间轴、三种反馈、战报

现状（`battle_view.gd` / `combatant_panel.gd`）：双方面板（资源条 + buff 格 + 飘字）、缩小棋盘 + 冷却遮罩、日志框、「1×」倍速与「跳过」按钮；`seek(t)` 已经是纯游标。

### 3.1 时间轴 `ReplayTimeline`（`ui/battle/replay_timeline.gd`，画布）

- 一条横杆，长度 = 整场时长（`BattleResult.log` 最后一条的时间）；每条伤害 / 击倒事件在杆上一个刻度（我方出手朝上、敌方朝下，颜色随 side）；游标 = 当前 `_now`。
- 拖动 / 点击 → `BattleView.seek(t)`（已有），拖着时暂停、松手按原状态继续；滚轮不管。
- 倍速与跳过两个按钮挪到杆的右端；「跳过并继续」（`battle_screen`）照旧。

### 3.2 三种反馈（作者定：只这三种）

| 反馈 | 触发事件 | 画法 |
|---|---|---|
| 出手 | `attack` / 规则触发（带 uid） | 出手方棋盘上那件格子亮一下：`CooldownOverlay` 已知道 uid 的格，加一个 0.15 秒的高亮层 |
| 挨打 | `damage` | 挨打方**面板**整体位移 3 px 抖 0.1 秒（`CombatantPanel.shake()`），飘字照旧 |
| buff 上身 | `buff_applied` 首层 | 那个 buff 格从 0.6 倍放大到 1 倍，0.12 秒（`CombatantPanel.pop(id)`） |

跳转（`seek` 补事件）时三种都抑制，和现在抑制飘字同一个开关。倍速 ≥ 4 时抖动与放大按倍速缩短，不叠加。

### 3.3 收尾战报

`_finish()` 时在时间轴下方放一块 `RICH_SMALL` 文本（不是新屏）：「N 秒 ｜ 我方造成 X、承受 Y ｜ 对手造成 … ｜ 打倒 / 被打倒」—— 数都从日志累加（`_on_damage` 已经逐条经过）。跳过也出。文本走占位符 / 不写阿拉伯数字的规矩只管玩家叙事文本，读数行照旧用数字（和现有读数一致）。

### 3.4 肖像槽

面板顶上接 2 节的 `Nameplate`（同一份控件）：战前与回放两屏的名牌位置一致，玩家不用重新找。

测试：时间轴刻度数 = 日志里伤害事件数；拖到 t 后 `BattleView` 的 `_now` = t 且面板数值与直接 `seek(t)` 一致；`seek` 期间 `shake` / `pop` 调用计数为 0；战报里的造成 / 承受和日志累加一致。

## 4. 结算：战败时保险箱放大居中

现状（`result_screen.gd`）：战败一行说明 + 保险箱格子一小块（092）。

改法：战败且 `safe_items` 非空时，保险箱格子**居中、格子按 60 px 画**（撤离时的小版照旧 36 px），上方一行「保险箱里的东西带出来了」（现有句子），下方「继续」；为空时保留现在的一句。撤离分支不动。测试：战败 + 有保险箱件 → `_safe_view` 在中列且格子尺寸 60；为空 → 没有 `_safe_view`。

## 5. 事件屏：代价图标、收获行

### 5.1 选项代价图标

现状：选项按钮只有文字；代价靠文字里的 `{change_money_amount|abs}` 这类占位符说。

改法：`EventOption` 已经能列出自己的条件与后果（`TextParams.of(opt)`），`event_screen` 在按钮文字**前**画一排小格（画布，不加子控件、不加覆写）：耗体力 ♥、花钱 ¤、交出道具 ▣、耗行动点 ⌛、要信仰 ✦ —— 每种一个 16 px 的格，图标文件 `assets/ui/cost_<kind>.png` 有图用图、没图画这个字符。只画「会花掉什么」，不画「会得到什么」（得到的是读完才知道的乐趣）。哪些后果算代价（`core/run/events/outcomes/` 现有类）：`spend_vitality`、`change_money`（负数）、`lose_item`、`pass_time`（耗行动点，画 ⌛）；信仰条件（`conditions/` 里要信仰的那条）画 ✦。列表写进 `EventCostIcons.KINDS`，新后果类加进来就有图标。

### 5.2 结果页收获行

现状：结果页把给的道具写成一行行字；东西本身已经落到**地上**（`EventContext` → `RunState` 收到地上）。

改法：结果页最下方一条**「收获」容器视图**：`ContainerView` 只画 `detail.items` 对应的那几件（按 uid，从地上层取），**从这里能直接拖进棋盘**（结果页自动打开背包浮窗，`toggle_bag` 已有；拖拽层登记这块视图）。拖走一件，收获行少一件；没拖的留在地上（现状）。文字行里的道具名删掉，其它行（体力、钱、buff）不动。

测试：结果页 `detail.items` 两件 → 收获行两件、地上两件；拖一件进棋盘 → 收获行一件、棋盘一件、地上一件。

## 6. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 战前天平 | A 做（倾斜杆，不写数） B 不做 | **A**：零数据成本，一眼看强弱 |
| 2 | 石板框九宫格的边距 | A 随图的 JSON  B 常量 | **A**：美术改图不改代码 |
| 3 | 时间轴能不能拖 | A 能拖  B 只显示 | **A**：`seek` 现成 |
| 4 | 代价图标没图时 | A 画字符  B 不画 | **A** |

## 7. 改动范围

| 文件 | 改什么 |
|---|---|
| `ui/widgets/overlay_frame.gd`（新）、`ui/game/game_screen.gd`（`_centered_panel` 造框）、八个叠层屏的标题行 | 1.1 |
| `ui/ui_theme.gd`（`PANEL_OVERLAY`、`LABEL_OVERLAY_TITLE`、`PANEL_TOOLTIP`，`asset_root`，九宫格分支）、`ui/inventory/hover_tip.gd` | 1.1 / 1.2 |
| `ui/ui_cursor.gd`（新）、`ui/inventory/drag_layer.gd`、`ui/game/game_director.gd`（光标、淡入）、`core/settings/game_settings.gd`（`ui_fades`）、设置屏一行 | 1.3 / 1.4 |
| `ui/widgets/nameplate.gd`（新）、`ui/game/prebattle_screen.gd` | 2 |
| `ui/battle/replay_timeline.gd`（新）、`ui/battle/battle_view.gd`、`ui/battle/combatant_panel.gd`（`shake` / `pop`）、`ui/battle/cooldown_overlay.gd`（出手高亮） | 3 |
| `ui/game/result_screen.gd` | 4 |
| `ui/game/event_screen.gd`、`ui/game/event_cost_icons.gd`（新） | 5 |
| `assets/ui/`（新目录，先空；美术交付清单：`frame_stone.png` + json、`tooltip_paper.png`、`cursor_{arrow,drag,can_drop,forbidden}.png`、`cost_{vitality,money,item,time,faith}.png`）、`assets/portraits/{enemies,characters}/` | 钩子 |
| `tests/ui/test_theme.gd`、`tests/ui/test_overlay_frame.gd`（新）、战前 / 回放 / 结算 / 事件的现有测试加断言 | |
| `docs/architecture.md` 8 节（叠层框、淡入、光标）、README 落地记录 | |

## 落地记录（2026-10-12）

四项待定按推荐（天平做、九宫格边距随 json、时间轴能拖、代价图标没图画字符）。美术同日交付了第 7 节清单里的图（`/mnt/project-files/art/ui/`），一并放进 `assets/ui/`。

| 节 | 落在哪 | 和方案的出入 |
|---|---|---|
| 1.1 石板框 | `ui/widgets/overlay_frame.gd`（`OverlayFrame`：标题条 + 右侧槽 + 内容区）；`GameScreen._centered_panel` 造它、返回内容区，`_frame_title(text)` 写标题；`UiTheme.PANEL_OVERLAY` / `LABEL_OVERLAY_TITLE`，`asset_root`、`art()` / `art_meta()` / `frame_title_height()` | 用 `_centered_panel` 的是九屏（方案数的八屏里宝箱屏不用它，另有休息、百科），九屏的标题都搬进了标题条。商店的长说明拆成标题「商店　点 N」+ 原处一行灰字。槽先空着（收起 / 关闭按钮没挪，各屏原样）|
| 1.2 悬浮窗底 | `HoverTip` 主面板与侧边词条小窗都走 `PANEL_TOOLTIP` | 词条小窗原来是术语色的边（棘轮里一处特例），现在和主面板同一块底，棘轮 −1。**美术给的 `tooltip_paper.png` 没放进 `assets/ui/`**：纸是亮色，而悬浮窗正文和各种着色（稀有度、术语、伤害类型）都是按深底配的浅色字，直接换上看不清。要用纸得先把悬浮窗的字色整套换成墨色，单列一项 |
| 1.3 光标 | `ui/ui_cursor.gd`（`UiCursor.apply()` 在导演 `_ready` 调；热点 (2, 2)）；`DragLayer` 拿起 = 拖动、对准了按 `drop_ok_at` 切可放 / 不可放、放下还原 | — |
| 1.4 淡入 | `GameDirector._fade_in`（叠层 0.15 秒、底屏 0.2 秒）；`GameSettings.ui_fades` + 设置屏「换屏淡入」开关；`GameDirector.fades_allowed` 由 `run_tests.gd` 与 `capture_scene.gd` 关掉 | — |
| 2 战前对阵式 | `ui/widgets/nameplate.gd`（`Nameplate`，肖像 `assets/portraits/{enemies,characters}/<id>.png`，没图不画槽）；`ui/widgets/balance_seam.gd`（`BalanceSeam`，中缝 + 天平，`tilt_of` 限 ±25°）；`prebattle_screen.gd` 改成两列等宽 + 中缝，读数只剩「生命 N　约 X DPS」 | 自己的名牌副行写「我方」（136 去掉了身份层，没有「角色身份」可写）。「开战」居中，腰带件在它左边、信仰 / 技能给的动作在右边，原因一行挪到按钮下面 |
| 3 回放 | `ui/battle/replay_timeline.gd`（`ReplayTimeline`：伤害与倒下的刻度，我方打出的朝上；点 / 拖 = `seek`，拖着停、松手按原状态接着放）；`CombatantPanel.shake()` / `pop(id)`；`CooldownOverlay.flash(uid, at)`（出手与带 uid 的规则触发）；`BattleView.report_of` 收尾战报；回放面板顶上接同一份名牌 | 跳过（`skip_to_end`）也和跳转一样抑制飘字与三种反馈。拖到头算「看完」，标题的胜负只写一次 |
| 4 战败结算 | `result_screen.gd`：战败且有保险箱件 → 那一格居中、格子 60、说明 16 号 | 撤离分支不动（现在的格子本来就是 60，方案里写的「36」是笔误，照旧不改）|
| 5.1 代价图标 | `ui/game/event_cost_icons.gd`（`EventCostIcons.KINDS`：体力 / 花钱 / 交出道具 / 耗行动点 / 要信仰）；拼成一条图挂在选项按钮的 `icon` 上，没图的格子在按钮上画字符，悬浮提示写「代价：……」 | `KINDS` 里放的是类，GDScript 的常量不收类，写成 `static var` |
| 5.2 收获行 | `RunState` 把事件给的东西收到地上时把 uid 记回 `detail.item_uids`；`ui/inventory/harvest_row.gd`（`HarvestRow`：背后的容器就是地上，按 uid 摆成一排）；事件结果页有收获时自动开背包、和背包共用一层拖拽；双击 = 进包 | 收获行只拿不放（拖回收获行 = 放回地上原处）。认不出是哪几件（老存档的结果页）时照旧写「得到：……」一行 |

测试：新套件 `tests/ui/test_screens_157.gd`（83 项：主题有图 / 没图、光标四张、淡入设置、代价图标、天平、战前与回放整条走一遍、六个叠层各一块框、战败结算、收获行）。`test_theme` 的变体表多了三个，棘轮 134 → 133。
