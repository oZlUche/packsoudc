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

## 补充一（2026-10-12）：回放屏去掉文字播报，双方棋盘放大

> 作者原话（截图：回放里棋盘缩成一小块、下面一屏「6.00 游兵（0 档）受到 3 / 我 受到 3……」）：「去掉文字播报，剩下的空间用来显示两边的道具，放大棋盘」。

- **去掉播报**：`BattleView._ticker`（`RichTextLabel`，`_log_line` 往里写）不再加进回放屏。`_log_event` 照旧跑 —— 它累加的数给 3.3 节的收尾战报用。`BattleView` 加 `show_ticker: bool = false`：回放浏览器（`ui/battle/replay_browser.gd`，开发工具）设 true 保留日志；正式游戏（`battle_screen`）用默认 false。
- **棋盘放大**：`BattleView.BOARD_SCALE` 0.5 → **1.0**（格子回到 60 px，和战前准备一样大）。双方各一列：面板（资源条 + buff 格）在上、棋盘在下，两列各占一半。宽度：最宽 9 格 × 60 = 540，两列 + 16 间距 = 1096，`battle_screen` 的 `custom_minimum_size`（1160 × 780）放得下；高：6 格 × 60 = 360 + 面板约 150 + 表头 + 控制条 ≈ 620，也放得下。`BOARD_SCALE` 常量留着（回放浏览器里多场并排时仍可缩）。
- **播报留下的空间**归棋盘；3.1 节的时间轴放在控制条那一行，不另占高度。
- 3.3 节的收尾战报（一行汇总）保留 —— 它不是逐条播报；作者若也不要，去掉就是（待定 5）。
- 测试：`test_battle_view*` 里断言正式路径下树里没有 `_ticker`、`show_ticker = true` 时有；棋盘 `scale == Vector2.ONE`。

| # | 待定 | 推荐 |
|---|---|---|
| 5 | 收尾战报一行要不要 | **要**（不是播报，是结果） |

## 补充二（2026-10-12）：没图也先留框 —— 肖像框与名牌的占位样式；石板框转美术

> 作者原话：「我没有看到可以放置肖像的画框和特殊样式的名牌，是还没做吗？没有美术资源也先预留一个框先」；「我希望将当前整体框架（纯色背景）用石板的样式替换，将这个转交给美术」。

157 正文 2 节写的是「没图不画槽」，落地也是这么做的（`Nameplate.setup` 的 `face` 为 null 就不加肖像块）—— 作者要反过来：**框永远在，图来了填进去**。

- **肖像框**：`Nameplate` 永远画一块 64×64 的肖像位。没图时画**占位框**（画布：`UiPalette.LINE` 描边的方框 + 里面一个半身剪影轮廓 `draw_polyline`，暗底）；有图时图填进框里，框线仍画在外面（美术的肖像图不含框）。
- **名牌样式**：名牌本身一块**石板底**（`UiTheme` 新变体 `PANEL_NAMEPLATE`：`assets/ui/nameplate_stone.png` 九宫格有图用图、无图 `StyleBoxFlat` 深底细边），名字用 `LABEL_TITLE`，副行 `LABEL_DIM`；左肖像位、右留一个 32×32 的徽记位（也画占位框，阵营数据有了再填）。
- 战前与回放两屏同一份控件（3.4 节），一起变。
- 测试：`test_nameplate`：没图 → 树里有肖像位且 `portrait == null`、名牌最小尺寸含 64 px 肖像位；有图 → `portrait` 非空。
- **转美术设计**（经协调）：157 第 7 节的清单加 `nameplate_stone.png`、`portrait_frame.png`（肖像框线，透明中心）；整体「石板框」（`frame_stone.png` + `frame_stone.json` 边距）、悬浮窗底、光标、代价图标照清单。美术方向 A（墨线平涂、石板面板）。
