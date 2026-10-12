# 方案：腰带离开背包，常驻右下角、格子画成圆；第四张教学图讲随身道具（160）

> 作者原话（2026-10-12，架构设计）：「腰带不作为背包的一部分出现在界面里，而是放在右下角的位置，格子用圆形表示，未来在第四张地图里加入相关的教程，比如如何使用该类道具躲避战斗、强化自己或者恢复体力」。
> 性质：架构 · 实施（1 ～ 3 节）+ 内容备忘（4 节，不派发）。待定按推荐。关联 147（腰带）、150 补（腰带是读数组件）、157（石板框）。

## 1. 现状

腰带现在出现在**两处**：
- 背包浮窗（`InventoryPanel`）左上一条 `belt_view`（147：棋盘上方，双击就用）；
- 地图屏的读数组件 `belt` 组件（150 补 1：默认布局右上那一列里，一条 1 × N 的方格，自带拖拽层，双击用）。

战前准备屏另有一排「能在这儿用的」按钮（147，烟雾弹）。方格和背包格子同一个 `InventoryView` 画法。

## 2. 改法

### 2.1 只留一处：右下角的圆槽组件

- `InventoryPanel` **不再造 `belt_view`**（52 ～ 59 行、注册拖拽 / 悬浮那几处一并去掉）；随身道具双击进腰带那条（169 ～ 171 行）保留：目标仍是 `BeltModule.of(run).belt`，只是界面上进的是角落那条。
- `belt` 组件改画法：**一排圆槽**（`BeltWidget` 自己 `_draw`，不再内嵌 `InventoryView`）—— 每槽直径 56 px、间距 10、底一圈 `UiPalette.LINE`、空槽里一个淡的小圆点；有东西时道具画在圆里（`ItemPainter` 画一格的缩略：底色按稀有度淡洗、名字首字或以后的图标），槽数 = `belt.size.x`（默认三格，扩展槽跟着加）。
- **默认位置**：`HudLayout.default_for("map")` 把 `belt` 从右上那一列挪到 `bottom_right`（偏移 `(-8, -8)`，日志在它上面 `(-8, -80)`，日志只在调试模式）。仍是组件，作者在「摆读数」里照样能拖。`HudLayout.VERSION` +1（157 小修那条已经引入版本号，旧布局丢弃用默认）。
- **交互不变**：双击用（`GameFlow.use_belt`，用不了的原因写提示行 → 现在提示行在调试台，改成在槽上方飘一行 1.5 秒）；拖进 = 从地上 / 背包拖到某个圆上（圆的命中按圆心距 ≤ 半径）；拖出 = 落地。圆槽之间不分先后，拖到哪个圆进哪个槽，满了弹回。
- **其他屏**：战前准备那排按钮保留（它是「现在能用」的筛选，不是腰带本体）；事件屏、容器屏、商店屏叠在地图上时角落的腰带仍露着（读数层在叠层之下 —— 待定 1）。
- 157 的石板框到了之后，圆槽底换成 `assets/ui/belt_slot.png`（圆形九宫不适用，直接一张 56 px 圆底图，`has_image ? draw_texture : draw_circle`）。交付清单加这一张。

### 2.2 测试

- `test_hud_layout`：默认 map 布局 `belt` 锚在 `bottom_right`。
- `test_belt_widget`：三槽 → 三个圆的命中区；放一件 → 画在第 i 个圆；拖拽落点换算（圆心距）；双击用走 `use_belt`。
- `test_inventory_panel`：浮窗里没有 `belt_view`；随身道具双击进腰带仍成立。

## 3. 改动范围

| 文件 | 改什么 |
|---|---|
| `ui/hud/widgets/belt_widget.gd` | 圆槽画法、命中、拖拽落点 |
| `ui/hud/hud_layout.gd` | 默认位置 `bottom_right`，`VERSION` |
| `ui/game/inventory_panel.gd` | 去掉 `belt_view` |
| `ui/inventory/item_painter.gd` | 一格缩略画法（圆内） |
| `tests/ui/…` | 2.2 |
| `docs/architecture.md` 3.6（腰带） | |

## 4. 内容备忘：第四张教学图（不派发，等作者定章节内容时用）

作者的意图：序章四讲**随身道具**，三件事各一个节点 —— 
1. **躲避战斗**：踩上一个明显打不过的战斗点 → 战前准备 → 用烟雾弹脱身（147 的「走脱身那条路」）；
2. **强化自己**：一件开战前用的增益随身道具（现有 `BeltUse` 效果里要加一种「给一个 buff」—— `grant_run_buff` 已有地图 buff 的写法可复用）；
3. **恢复体力**：急救包（已有 `mend_vitality`）。

写法同序章一 ～ 三：预设图 `data/maps/tutorial4.json` + 章节 `prologue_4.json`（order 3，自由模式挪到 4）+ 教程事件 `tut4_*`。开局发烟雾弹、急救包与一件增益道具（`starting_items`）。这一节只记意图，章节文案与节点布局另开方案。

## 5. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 叠层屏（事件 / 容器 / 商店）开着时角落腰带 | A 露着、能用（事件里能回体力）；B 叠层开着时藏 | **A** |
| 2 | 圆槽直径 | A 56；B 48 | **A**：157 定的顶栏两倍档是 28 号字，56 和它成比例 |
| 3 | 用不了的原因怎么说 | A 槽上方飘一行；B 提示行（现在在调试台里） | **A** |

---

## 补充一（2026-10-12）：随身道具不再是道具 —— 「可堆叠的一次性技能」

> 作者原话：「类似烟雾弹这些特殊道具不该视作道具的一种，所以不进仓库不进图鉴没有负重，你可以将它们视为【可堆叠的一次性技能】，所以不会出现在敌人背包里，只能通过事件、商店随机刷新和局外科技以及角色能力获得」。

### 补 1. 现状（147）

烟雾弹、急救包是带 `belt` 标签的**普通道具定义**（`ItemDef.belt_use`），走道具库：有实例、有形状、能落地、能进仓库（`MetaState.keeps` 不排它）、进图鉴的道具页、搜索点 / 掉落 / 商店按普通道具进池（147 的 2.3 节就是这么定的）；只有敌人组装（`enemy_placer.gd` 396 行）和作战棋盘（`reject_tags`）不收它。负重本来就不算（它不上棋盘）。

### 补 2. 改法：搬出道具库，腰带存「id → 几个」

- **新内容种类** `data/authoring/belt_skills/*.json` → `data/belt_skills/*.tres`（`BeltSkillDef`：`id`、`display_name(s)`、`description`、`icon` 钩子、`when`（能在哪用，147 的那组）、`effects`（147 的 `BeltEffect` 原样）、`stack_max`（默认不限，由格数限种类数）、`price`（商店用，占位）。`smoke_bomb`、`aid_pack` 从 `items` 搬过去；`ItemDef.belt_use` 与 `belt` 标签删掉（导入器里那三条校验跟着搬）。道具库里没有它们之后，搜索 / 掉落 / 商店 / 珍宝 / 携带规则 / 入场赠礼那些 `items.ids()` 循环**一个都不用改** —— 这是选「搬出去」而不是「到处加 `is_belt` 过滤」的原因。
- **腰带的存法**：`BeltModule.belt` 从 1 × N 的 `GridInventory` 改成 `Dictionary`（id → 数量），`slot_count()` 限的是**种类数**；`use(id)` 用掉一个，数到零那格空出来。存档存这份字典（`to_dict / restore`）。`belt_use` hook 的参数从 uid 改成 id；`GameFlow.use_belt(id)`。
- **不进仓库、不进图鉴、没有负重、不在敌人包里、不落地**：都由「不是道具」自然成立。撤离时腰带里剩的**作废**（待定 补 1）。
- **来源**（四条，别的路都没有）：
  1. 事件：选项效果新加 `grant_belt {id, count}`（和现有给道具的效果并列），序章四的教程点用它发；
  2. 商店：货架之外一排「随身」（`EconomyRules.belt_stock`：候选 id 与权重，每次刷新抽 1 ～ 2 种，和货架一起刷），买了直接 +1 到腰带（没有拖拽）；
  3. 局外科技：新效果 `tech_belt_grant {id, count}`，每局开局发（和 `starting_items` 同一时机，走 `BeltModule.install`）；
  4. 角色能力：`RunSkill` 被动 `starting_belt {id, count}`，章节也可以配 `starting_belt`（序章四开局发烟雾弹 + 急救包 + 增益件）。
- **界面**（改写本方案 2.1）：圆槽里画图标（没图画名字首字），右下角一个小圆标写数量；**没有拖进拖出**（不落地、不进包），点一下 / 双击用；战前准备那排按钮在名字后面带数量。`InventoryPanel` 的「随身道具双击进腰带」那条随之删掉。

### 补 3. 测试

- `test_belt_module`：发三个烟雾弹占一格、用一个剩两个、用到零格子空；格数限种类；存档来回；`grant_belt` / `starting_belt` / 科技发放各一条。
- `test_shop`：「随身」排按权重刷新、买了进腰带不进棋盘。
- 道具库里没有 `belt` 标签的定义；图鉴道具页、仓库 `keeps`、搜索与商店候选里都不出现烟雾弹。

### 补 4. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 补 1 | 撤离时腰带里剩的 | A 作废；B 带回下一局 | **A**：作者定了不进仓库，带回等于另一个仓库 |
| 补 2 | 图鉴 | A 完全不列；B 另开一页「随身技能」 | **A**：按作者原话；真要教玩家，教程点与商店说明已够 |
| 补 3 | 一格能堆几个 | A 不限；B `stack_max` 默认 5 | **A** |

### 补 5. 改动范围（在本方案 3 节之上）

| 文件 | 改什么 |
|---|---|
| `core/inventory/belt_skill_def.gd`（新）、`core/authoring/content_importer.gd`、`data/authoring/belt_skills/`（新，两份搬过去） | 补 2 |
| `core/run/modules/belt_module.gd`、`core/run/run_hooks.gd`、`core/run/game_flow.gd`（`use_belt`） | 字典存法、按 id 用 |
| `core/run/shop_session.gd`、`core/run/economy_rules.gd`、事件效果、科技效果、`RunSkill` 被动 | 四条来源 |
| `ui/hud/widgets/belt_widget.gd`、`ui/game/shop_screen.gd`、`ui/game/prebattle_screen.gd`、`ui/game/inventory_panel.gd` | 补 2 界面 |
| `docs/architecture.md` 3.6（腰带）、147 的落地记录加一行 | |
