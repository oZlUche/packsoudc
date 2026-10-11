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

## 落地记录（2026-10-11，五项待定全按推荐）

- **节点**：`chest` 进了类型表、样式（「宝」）、地图文字 `C`、名字、浮窗（默认一句「上锁的宝箱：长按开锁，越好的箱子越费时。」）、帮助页「节点类型」。随机点能揭出（`RANDOM_ALLOWED`、`standard.json` 的 `random_weights.chest = 1`）；自由模式各环和环模板的 `type_weights` 加 `chest: 1`，没进 `type_risk / type_reward`（按 0 算）。
- **稀有度**：`ChestPlacer.roll` 在 `EventPlacer.fill` 之后跑，只用 `content_seed`，已经定了的不动；随机点揭成宝箱时 `NodeEvents.reveal` 补同一步，`_arrive_chest` 再兜一次（预设图、手改的点）。
- **开锁后**：`NodeEvents.open_chest` 复制一份 `SearchRules`：`max_searches = 1`、`encounter_curve = [0]`、件数按 `items_by_rarity` 掷定后上下限都设成它、`exclude_tags` 去掉 `treasure`、`haul_board` 用宝箱的、`search_floor` 每件都是下限。原规则不动。赐福替换照旧。关搜索屏（`pause_search`）对宝箱直接拿完走人，不出「再搜 / 走」。
- **与方案的出入**：
  - 方案里的 `arrival_payload` 实际叫 `_reopen_entry`，站在没开锁的宝箱上能「回到这个点」。
  - `ChestSkinDef` 的进度环写成两个平的字段 `ring_radius / ring_width`（不是 `ring: {radius, width}`），`lock_offset` 是 `Vector2`；JSON 示例按这个写。
  - `FrameStrip` 放在 `ui/widgets/frame_strip.gd`，`UiDraw` 放在 `ui/ui_draw.gd`。
- **画面**：`ui/game/chest_screen.gd`。整屏背景（有图铺满裁切，没图深底），上面一行「{稀有度}宝箱」，中央 `ChestView` 画宝箱，下面一行字（没按「点击宝箱开锁」、按着「尝试开锁」、开了清空），左下「回地图」。
  - 占位：地上的影子、木箱身和盖、包边颜色随稀有度（越稀有竖向包边越多）、锁片和圆锁孔；按着时锁孔里一根拨片来回转、箱子轻抖；进度环圆心就是锁孔，从正上方顺时针走。开了画掀开的盖、一团光和「开」，0.45 秒后弹出搜索界面。有序列帧就播序列帧。
  - 输入：鼠标左键在宝箱上按下才算；松手在哪儿都算松手；空格按住同样（回地图按钮不抢焦点）。两路都松了才算松手。Esc：按着先松手，没按着回地图。开锁不走步。
  - **鼠标按着移出宝箱**：照 154 §3.4 仍算按着。美术草稿写的是「移出 = 松手」，和方案冲突，所以留了开关 `ChestScreen.MOUSE_OUT_RELEASES`（默认 false），作者定了改成 true 即可。
  - 搜索屏标题对宝箱写「{稀有度}宝箱　点 N」。
- **皮肤**：新内容种类 `chest_skins`（在 `chapters` 之前导入），`data/authoring/chest_skins/ruins.json` 只有 id 与名字，图全空，全部占位。导入器对写了却找不到的图只提醒。章节 `chest_skin` 默认 `ruins`，不认识的 id 提醒。美术交付后在 ruins.json 里填路径即可，不用改代码。
- **121 棘轮**：没加 `add_theme_`，图形全在画布上。
- **测试**：`tests/run/test_chest_154.gd`（类型登记、规则与稀有度、生成、`LockHold` 数学、开锁后的会话与存档中途读回、开锁画面整屏按住到弹出搜索）。
- **连带**：自由模式加了宝箱权重，同一个种子的图变了，编译金样四份的 uid 整体挪了 7（数值没动），按 143 的先例重录；随机点用例补上「揭成宝箱」一支（没开锁不算用过）。

## 补充一（2026-10-11）：键盘【确认键】也能按住开锁；移出不算松手定案

> 作者原话（美术设计线程，看过草稿后）：「中途松手会退，但是鼠标移出宝箱不会退，之后考虑做一个键盘的【确认键】也可以按住开启的功能，这部分交给设计」「背景和宝箱是分开的两张图，两个元素」。

### 定案的两条

1. **鼠标按着移出宝箱不算松手**（作者定）。落地时留的开关 `ChestScreen.MOUSE_OUT_RELEASES` 删掉，连同那一支 `motion` 判断；测试补一条「按着移出仍在走」。
2. **背景与宝箱是两张图**：皮肤表已经是 `background` 与 `closed[] / open[]` 分开的字段，不改；写进 `docs/architecture.md` 的皮肤一节一句，防止美术交付合成图。

### 确认键

现状：工程里没有 `[input]` 动作，键全是写死的（宝箱屏 `KEY_SPACE`、事件屏 / 地图 `KEY_B`、各处 `KEY_ESCAPE`）。确认键是第一个「玩家可能想改」的键，所以走 Godot 的 `InputMap`：

- `project.godot` 加 `[input]` 动作 **`confirm`**，默认绑 回车、小键盘回车、空格（空格留着，老手感不变）；顺手加 **`cancel`** 绑 Esc，但这一步只定义，不改现有的 `KEY_ESCAPE` 判断（那是另一次清理）。
- `ChestScreen._input` 的 `KEY_SPACE` 判断改成 `event.is_action("confirm")`（`InputEventKey` 的 pressed / released 都走它，`echo` 照旧忽略）；鼠标与键盘两路「都松了才算松手」的逻辑不变。
- 文字行：没按时「点击宝箱开锁」改成「点击宝箱或按住确认键开锁」？**不改**：作者给的是定稿文案，键盘提示放浮窗 / 帮助页「节点类型」一句「也可以按住确认键」。
- **改键**（待定 1）：`GameSettings.key_bindings: Dictionary`（动作 → 键码数组），启动时 `InputMap.action_erase_events + action_add_event` 覆盖默认；设置屏加一行「确认键」：点一下进入监听、按任意键写入、Esc 取消、「恢复默认」。本补充推荐**先做数据与启动覆盖、不做设置屏那一行**，等下一个要改键的动作出现再一起做界面。
- 其他屏以后用确认键做「默认选项 / 继续」（事件屏的第一个选项、战利品屏的收起）不在本补充里，但动作名已经留好。

### 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 改键界面 | A 先只做 `GameSettings.key_bindings` + 启动覆盖，设置屏以后加；B 这次把设置屏的改键行一起做 | **A**：一个键不值一套监听 UI |
| 2 | 手柄 | A 这次不绑；B `confirm` 顺手绑手柄 A 键 | **A**：游戏没有任何手柄支持，单绑一个键没意义 |

### 改动范围

`project.godot`（`[input]`）、`ui/game/chest_screen.gd`（删开关、换动作）、`core/settings/game_settings.gd`（`key_bindings` 存取与启动覆盖，默认空）、`ui/game/game_director.gd` 或启动处调用覆盖、帮助页 `node_types`、`tests/run/test_chest_154.gd`（移出仍走、确认键按住等同鼠标、`key_bindings` 覆盖后动作认新键）。

### 补充一落地记录（2026-10-11，两项待定全按推荐）

- `project.godot` 加 `[input]`：`confirm` 绑回车、小键盘回车、空格（按键码，不按物理键）；`cancel` 绑 Esc，只定义。
- 宝箱屏：按住开锁的键改成 `confirm` 动作（按下 / 松开都认，忽略连发）；`MOUSE_OUT_RELEASES` 和移出那一支删掉，没用了的 `chest_rect_global` 也删了。
- 改键：`GameSettings.key_bindings`（动作 → 键码数组），读的时候键名（`"Enter"`）换成键码，认不出来的键、空动作、不是数组的都扔掉。套到 InputMap 的是界面层的 `InputKeys.apply`（`ui/input_keys.gd`，`core/` 不认识它）：先 `load_from_project_settings` 回到默认，再把改过的动作整组替换；只认 `confirm / cancel`。导演 `_ready` 在配色之后调。没有设置屏那一行，手柄不绑。
- 帮助页「节点类型」：宝箱一句后面加「也可以按住确认键，默认空格或回车」。屏上那行字照作者定稿不改。
- 架构文档 5.4 补一段宝箱皮肤：背景和宝箱是两张图、两个元素。
- 测试：`test_chest_154.gd` 加确认键与改键一组（默认键、改成 F / G 整组替换、没改的留默认、存取往返、坏数据、回到默认）；开锁屏那组改成真的发按键事件（回车按下 / 松开、别的键不算、空格与鼠标一起按只松一路还按着），并补「按着移出宝箱接着走」。
