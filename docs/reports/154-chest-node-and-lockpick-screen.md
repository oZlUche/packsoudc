# 方案：宝箱节点 + 长按开锁画面（154）

> 作者原话（2026-10-11，架构设计）：「给游戏加入一个新的节点类型，宝箱节点，进入后展示一个可互动画面，画面中央主体为一个放在地上的宝箱，背景根据地图不同会有不同变化，宝箱的纹路和材质根据稀有度和地图不同也会有变化。宝箱下方有一行字，文本为【点击宝箱开锁】，鼠标按下后宝箱锁孔处出现开锁动画，画面中央出现环形进度条，环形的中心正好是锁孔。玩家长按鼠标会让进度条逐渐走满（顺时针），越高级的宝箱时间越长，进度条增长途中会播放【尝试开锁】的动画，进度条满后动画消失，宝箱打开然后弹出搜索界面。根据以上形容让美术线程设计几张草稿，以确认理解了我的想法，在美术设计的同时开始为宝箱和动画界面的框架做准备」
>
> 性质：架构 · 提议。本线程只写方案，不实现。待定项默认按推荐。草稿由「美术设计」线程并行出；本方案是**框架**：美术没到之前用占位图形跑通全部交互。
> 关联：092（保险箱 —— 最近一次加节点类型，本方案照它的触点清单走）、084（搜索循环）、063（容器屏：搜索与战利品同一界面）、5.10（节点内容生成时定）、121（主题覆写配额已满）。

## 1. 现状（查过的）

- **节点类型只有一份名单** `MapNodeTypes.ALL`（12 种），编辑器下拉、配色表 `MapNodeStyle`、地图文字 `MapGridText.SYMBOL_TYPES`、浮窗 `NodeTooltip.DEFAULTS` / `category_of`、`NodeText`、`FieldText.TYPE_LABELS`、帮助页 `node_types` 都从它或各自的表取。092 加保险箱时的触点：`map_node_types.gd`、`map_grid_text.gd`（`K`）、`map_node_style.gd`（「箱」）、`node_text.gd`、`field_text.gd`、`node_tooltip.gd`、`node_events.gd`（`_proceed` 一个分支 + 一个信号）、`game_flow.gd`（`Screen` 枚举 + `arrival_payload`）、`game_director.gd`（屏 → 脚本表）、新屏 `ui/game/safe_screen.gd`、`tests/run/test_safe.gd`。
- **节点内容生成地图时就定**（5.10）：`MapNode.content` 是自由字典，随图存档；`content_seed` 给内容掷骰。
- **搜索**：`NodeEvents._open_search` 建 `SearchSession(node, rules.search, items, rng, depth)`，`search_shown` → `GameFlow` 推 `Screen.SEARCH` → `container_screen.gd`（左 `LootView` 渐进揭示、右棋盘与地上）。`SearchRules` 有 `max_searches / encounter_curve / items_per_search / rarity_weights / exclude_tags（默认排除 treasure）/ reveal_seconds / search_floors`。关屏走 `pause_search` → again / done 事件。
- **环形进度条已有现成画法**：`LootView._draw_progress` 用 `draw_arc` 从正上方顺时针画到 `_progress`。
- **地图没有「主题」概念**：`ChapterDef` 没有美术字段；`GameSettings.bg_theme` 是界面配色，不是地图主题。事件配图走 `EventImage.load_texture`（`res://assets/events/`，没扫过也能读）。
- 稀有度六档 `RARITY_NAMES` 普通 / 优良 / 稀有 / 史诗 / 传说 / 神话；`DropRule.treasure_*` 管珍宝掉落，搜索默认不出珍宝。
- 121：`add_theme_` 覆写 135 / 135，新屏只能用主题变体与 canvas 绘制。

## 2. 规矩（作者定，本方案落成的形式）

1. 新节点类型 **`chest`【宝箱】**：踩上进宝箱屏；没开锁就离开不算用过（和保险箱一样可以回来）；开了锁、搜索会话结束才算用过。
2. 宝箱**生成地图时定好**稀有度与皮肤（5.10）：`node.content.chest = {"rarity": 0–5, "skin": "<皮肤 id>"}`。稀有度按节点档位掷（第 3.2 节），皮肤由章节定。
3. 开锁是**长按**：鼠标在宝箱上按下 → 锁孔处播「开锁」动画、以锁孔为圆心的环形进度条从正上方顺时针走；按住不放进度走满，时长按稀有度查表；走满 → 动画消失、宝箱播开启动画 → 弹出搜索界面（现有容器屏）。松手未满进度回退（待定 1）。
4. 宝箱的收获走**现有搜索会话**：一次翻找、不遭遇、允许珍宝、稀有度下限随宝箱稀有度（第 3.3 节）。
5. 画面三层数据驱动：**背景按皮肤**、**宝箱贴图按皮肤 × 稀有度**、**锁孔位置与动画按皮肤**，全在 `chest_skins/<id>.json` 里；没图时画占位（深底 + 方块宝箱 + 圆锁孔），交互一样能跑。

## 3. 怎么做

### 3.1 节点类型（照 092 的触点）

| 处 | 改什么 |
|---|---|
| `MapNodeTypes.ALL` | 加 `&"chest"`（非结构性） |
| `MapGridText.SYMBOL_TYPES` | `"C": &"chest"` |
| `MapNodeStyle` | `&"chest": {"glyph": "宝", "color": 金棕}`（颜色与搜索的黄区分，美术线程定终值） |
| `NodeText` / `FieldText.TYPE_LABELS` | 「宝箱」 |
| `NodeTooltip.DEFAULTS["chest"]` + `category_of` | 「上锁的宝箱：长按开锁，越好的箱子越费时。」用过 → `visited` |
| 帮助页 `node_types` | 加一句宝箱 |
| `NodeRules.random_weights` | `standard` 加 `"chest": 1`（随机点可能揭出宝箱）；序章不加 |
| 环地图模板 `type_weights` | 自由模式加 `chest: 1`；序章预设图不放；`RingTypeAssigner` 不需要配额规则 |
| `NodeEvents._proceed` | `&"chest"`：`last_handled_id = node.id`；`chest_shown.emit(node)`（没开锁）或直接 `_open_chest(node)`（存档里已开锁） |
| `GameFlow` | `Screen.CHEST`；`arrival_payload`：站在未开锁的宝箱上回屏时再给宝箱屏；已开锁且会话在 → 现有 `Screen.SEARCH` 分支 |
| `GameDirector.SCREENS` | `Screen.CHEST → res://ui/game/chest_screen.gd` |

### 3.2 宝箱规则 `ChestRules`（挂在 `NodeRules.chest`，内容数据）

```
ChestRules {
  rarity_by_tier: Array[Array[float]]   # 每个节点档位一行六个权重；越深越肥。默认三行：
                                        # 0 档 [60,30,10,0,0,0]，1 档 [20,40,30,10,0,0]，2 档 [0,20,40,30,10,0]
  danger_bonus: int = 1                 # 高危区（danger 2）稀有度 +1 后夹到 5
  hold_seconds: Array[float] = [1.5, 2.2, 3.0, 4.0, 5.5, 7.0]   # 六档的长按时长
  release_decay: float = 2.0            # 松手后进度回退速度（倍）；0 = 立即归零
  items_by_rarity: Array[Vector2i] = [(2,3),(3,4),(3,4),(4,5),(4,6),(5,6)]
  floor_by_rarity: Array[int] = [0,0,1,2,3,4]   # 搜出的东西至少这个稀有度（宝箱稀有度 − 1，前两档 0）
  include_treasure: bool = true
  haul_board: Vector2i = (6, 4)
}
```

- 地图生成后一步 `ChestPlacer.roll(graph, rules, rng)`（和 `SafePlacer` 并列）：对每个 `chest` 点按 `tier` 行掷稀有度、加 `danger_bonus`，写进 `content.chest.rarity`；`skin` 写章节的 `chest_skin`。随机点揭出宝箱时在 `reveal` 里补同一步。
- 存档：都在 `content` 里，随图走，不加迁移。

### 3.3 开锁后的收获：复用搜索会话

`NodeEvents._open_chest(node)`：按 `rules.search` 复制一份 `SearchRules`，覆盖 `max_searches = 1`、`encounter_curve = [0]`、`items_per_search = items_by_rarity[r]`、`exclude_tags` 去掉 `treasure`（`include_treasure`）、`haul_board`；`session.search_floor = [floor_by_rarity[r]]`；建会话后立刻 `session.search()`，`search_shown.emit` → 现有容器屏，标题「宝箱　{稀有度名}」。关屏：`pause_search` 对宝箱不走 again / done 事件，直接 `session.leave()` → `_visited(node)`。遭遇相关代码不触发（曲线为 0）。

### 3.4 宝箱屏 `ChestScreen extends GameScreen`（`ui/game/chest_screen.gd`）

布局：全屏背景（皮肤 `background`，`EventImage.area` 的铺满裁切）；中央 `ChestView`（canvas 控件）；其下一行文字 `点击宝箱开锁`（`LabelTitle` 变体）；左下「回地图」。有图用图，没图占位。

状态机 `LockHold`（纯逻辑类 `core/run/lock_hold.gd`，可测）：

```
IDLE      ── 鼠标左键在宝箱命中区按下 ──▶ HOLDING
HOLDING   ── 每帧 progress += delta / hold_seconds[r]；按住中播「尝试开锁」动画、锁孔处播「开锁」动画
          ── 松手（未满）──▶ RELEASING：progress −= delta × release_decay / hold_seconds[r]，归零回 IDLE；再按下回 HOLDING
          ── progress ≥ 1 ──▶ UNLOCKED
UNLOCKED  ── 动画全停、环消失、播宝箱开启动画（皮肤 `open_frames`，没图就换「开」占位）──▶ 结束后 flow.open_chest(node)
```

- 文字行：IDLE「点击宝箱开锁」；HOLDING「尝试开锁」（和动画同名，动画没到就先用这一行代替）；UNLOCKED 清空。
- 环形进度条：`draw_arc` 圆心 = 宝箱贴图左上 + 皮肤 `lock_offset`（占位时 = 箱体中下），半径 / 粗细来自皮肤 `ring`；底环暗色、进度环亮色，从 −90° 顺时针（和 `LootView._draw_progress` 同一写法，抽成 `UiDraw.ring(canvas, center, radius, progress, …)` 两处共用）。
- 命中区 = 宝箱贴图矩形；鼠标移出仍按着算继续按（不打断）。键盘：空格按住等同（无障碍，顺手）。
- 开锁期间不走时间、不扣行动点（宝箱不是「等待」）。Esc / 回地图：IDLE 或 RELEASING 时可离开，节点不消耗；HOLDING 中 Esc 先松手。
- 不新增 `add_theme_` 覆写：文字用变体，图形全部 canvas。

### 3.5 皮肤数据 `chest_skins/<id>.json`（新内容种类 `chest_skins`，进 `ContentPaths.KINDS`）

```json
{
  "id": "ruins",
  "display_name": "废墟",
  "background": "res://assets/chests/ruins/bg.png",
  "closed": ["…/chest_0.png", "…/chest_1.png", "…/chest_2.png", "…/chest_3.png", "…/chest_4.png", "…/chest_5.png"],
  "open":   ["…/open_0.png", …],
  "lock_offset": [128, 96],
  "ring": {"radius": 56, "width": 6},
  "unlock_frames": ["…/pick_0.png", "…/pick_1.png", "…/pick_2.png"], "unlock_fps": 8,
  "trying_frames": ["…/try_0.png", …], "trying_fps": 6,
  "open_frames": ["…/opening_0.png", …], "open_fps": 10
}
```

- 六张 `closed` 对应六档稀有度（纹路 / 材质随稀有度）；皮肤随地图（章节）。缺的键 / 缺的图 → 占位，不报错，导入器只 warn「图不存在」。
- `ChapterDef.chest_skin: StringName`（默认 `ruins`）；序章三章与自由模式先都填 `ruins`。
- `FrameStrip`（`ui/widgets/frame_strip.gd`）：一组贴图 + fps，`advance(delta)` 给当前帧；三段动画都用它。
- 美术线程的交付清单就是这张表：一张背景、六张闭箱、六张开箱、锁孔坐标、三段序列帧（可先只给闭箱与锁孔）。

### 3.6 测试

- `test_chest_154.gd`：类型进了全部表（照 `test_safe` 那组断言：`MapNodeTypes.has`、样式、地图文字 `C`、浮窗类别、`FieldText`）；生成图后每个宝箱点都有 `content.chest.rarity ∈ 0–5` 且档位高的权重行生效；`LockHold` 推进 / 回退 / 走满的数学（纯逻辑，不开屏）；`_open_chest` 建的会话只能搜一次、不遭遇、能出珍宝、下限正确；未开锁离开节点不消耗、会话结束消耗；存档中途读回仍在宝箱屏或搜索屏。
- `ContentCheck` 新种类 `chest_skins` 进管线；皮肤缺图只 warn。
- 121 配额不变（135）。

## 4. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 松手未满 | A 二倍速回退（再按接着走）；B 立即归零 | **A**：手滑不至于全白费，又不能点一下歇一下 |
| 2 | 宝箱屏期间的输入 | A 只鼠标左键 + 空格；B 加触摸 | **A**：桌面优先 |
| 3 | 收获的下限 | A 宝箱稀有度 − 1（前两档 0）；B 等于宝箱稀有度 | **A**：史诗箱必出稀有以上，但不保证史诗，留给 `rarity_weights` |
| 4 | 随机点能否揭出宝箱 | A 能（标准权重 1）；B 不能，只有图上明摆的 | **A**：随机点的乐趣就是可能更好 |
| 5 | 宝箱屏要不要进 150 的布局文件 | A 不进，它是独立屏不是地图读数；B 进 | **A** |

## 5. 改动范围

| 文件 | 改什么 |
|---|---|
| `core/map/map_node_types.gd`、`map_grid_text.gd`、`ui/map/map_node_style.gd`、`core/text/node_text.gd`、`core/authoring/field_text.gd`、`core/run/node_tooltip.gd`、帮助页 `node_types.json` | 类型登记 |
| 新 `core/run/chest_rules.gd`、`chest_placer.gd`、`lock_hold.gd` | 规则、掷稀有度、长按状态机 |
| `core/run/node_rules.gd`（`chest`）、`node_rules/standard.json`、环模板权重 | 数据 |
| `core/run/node_events.gd`（`chest_shown`、`_open_chest`、`pause_search` 宝箱分支）、`game_flow.gd`（`Screen.CHEST`、`open_chest`、`arrival_payload`）、`ui/game/game_director.gd` | 接线 |
| 新 `ui/game/chest_screen.gd`、`ui/widgets/frame_strip.gd`、`UiDraw.ring`（从 `LootView` 抽出） | 画面 |
| 新内容种类 `chest_skins`（`ContentPaths`、`ContentCheck`、导入 / 导出、`ContentSchema`）、`data/authoring/chest_skins/ruins.json`、`ChapterDef.chest_skin` | 皮肤 |
| `docs/architecture.md` 5.4 类型表、`docs/text-placeholders.md`（如加 `{chest_rarity}`） | 文档 |
| `tests/run/test_chest_154.gd` | 见 3.6 |
