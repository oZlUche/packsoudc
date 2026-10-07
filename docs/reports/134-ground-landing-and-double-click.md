# 134 方案：东西落到地上时有个落地动画；地上的东西双击直接进包并打开背包（放不下就只开背包）

> 架构 · 提议（2026-10-07）。作者：「我希望的掉落在地上的时候增加一个掉落的动画效果，另外地上的道具双击可以直接进包并打开背包界面，如果背包放不下则只打开背包界面」。

## 一、现状（已核实）

- 128 已落地：地上是导演持有的一层 `GroundLayer`（`ui/inventory/ground_layer.gd`），画的是这一局的 `storage`（`ItemStash`，每件一个归一化落点 `spots`），`_draw` 按落点直接画，`stash.changed` 一来就整层重画 —— **没有任何过渡**：战利品放不下、包里顶出来、拖出背包放手，东西都是「啪」地出现在落点上。
- 东西进地上的路有四条，都走 `ItemStash.insert / admit`：① 拖拽放手（`DragLayer.drop_at`，带落点 = 放手点）；② 顶出 / 脱落（`DragLayer` 的 displaced，落点自动找）；③ 战利品 / 收获放不下、「全部拾取」的回退（`RunState._offer_loot`、`transfer_all_prefer`，落点自动找）；④ 读档 / 回到存过东西的节点（`NodeStorageModule` 按存的落点放回）。④ 不该有动画（不是「掉」，是「本来就在」）。
- 双击：`GroundLayer` 发 `item_double_clicked`，**只有背包面板在的时候才有人接**（`inventory_panel.attach_ground` → `quick_move`：放得下进棋盘，放不下提示一句）。地图屏上背包浮窗没开时，双击地上的东西**没有反应**；容器屏 / 战前 / 搜索屏面板常驻，双击已经能进包。所以作者要的差一半：地图屏没开背包时的双击，以及「放不下就只开背包」这个分支。

## 二、设计

### 2.1 落地动画：地上这一层自己做，谁放的都一样

- `GroundLayer` 记上一次 `changed` 时的 uid 集合；这次多出来的 uid = **刚落地的**，各给一段落地动画（`_landing: Dictionary uid → {t0, from_px}`），`_process` 推进、`_draw` 按进度插值，播完删掉；动画中不接鼠标抓取（避免抓到半空中的）。
- 动画：**从起点落到落点**，时长 0.28 秒，缓出 + 末尾一个小弹跳（落点处回弹 6 像素再落稳），同时从 1.15 倍缩到 1 倍、透明度 0.6 → 1。起点：
  - 调用方给了 `landing_from`（像素）就从那里落：拖拽放手 = 放手点就是落点，只做缩放 + 弹跳（不位移，否则像从别处飞来）；顶出 / 脱落 = 从被顶出那一格的屏幕位置落过来；
  - 没给（战利品放不下、全部拾取回退、合成产物装不下）= 从**最近的面板边缘**（`reserved_rects` 里离落点最近那块的边）落出来，没有面板就从落点上方 60 像素落下。
- 起点怎么传：`ItemStash.insert(inst, at, spot)` 不改签名，另加一个**不入存档、不入 to_dict** 的 `landing_from: Dictionary uid → Vector2`（像素，由界面层写、`GroundLayer` 读完即删）；`DragLayer` 放手 / 顶出时写它。核心层（`RunState`）不写 —— 它不认识像素，走「最近面板边缘」的默认。
- 读档、回到节点（`NodeStorageModule.restore`）、`set_stash` 换一片地：先把 uid 集合记成基线，**不播**。
- 多件同时落（全部拾取回退五件）：按插入顺序每件错开 40 毫秒，像一串掉下来；上限 10 件之后不再错开。
- 不加 `AnimationPlayer`、不加场景文件：和 `combatant_panel` 一样用 `create_tween` 或 `_process` 推进（推荐 `_process` + 自己插值，因为画在 `_draw` 里、不是节点位移）。

### 2.2 双击：进包 + 开背包；放不下 = 只开背包

地上双击的处理按「谁在最上面」分两种，`GroundLayer.item_double_clicked` 不改：

| 场景 | 现在 | 改成 |
|---|---|---|
| 背包面板在（容器屏、战前、搜索、地图上背包浮窗开着） | `quick_move`：放得下进棋盘，放不下提示 | 不变 |
| 地图屏，背包浮窗**没开** | 没人接，没反应 | `map_screen` 接：先 `InventoryService.transfer_auto(storage, uid, board)`，**无论成败都 `toggle_bag()` 打开背包**；放下了 → 背包里看见它（棋盘视图新建时就是进包后的状态）；放不下 → 背包开着、东西还在地上、面板提示「背包里没有空间放「X」」（复用 `quick_move` 的那句） |

细节：
- 接法：`map_screen` 在 `_ready` / 成为栈顶时 `ground.item_double_clicked.connect(_on_ground_double)`，处理函数先判 `bag_open()`（开着就不抢，交给面板，128 的「只有最上面那块接」规矩不变）。
- 进包后那一件在棋盘上的位置由 `transfer_auto` 定（和现在双击一样，找第一个放得下的位置）。
- 开背包的那一瞬东西已经不在地上，所以不播落地动画；反过来「放不下、只开背包」时，背包浮窗一出现会把地上的东西推开（128 的 `reserve`），被推开的那件**不是**新落地的，不播动画（uid 集合没变）。
- 其它地上有东西但没有面板的屏（事件屏、休息屏、商店、神坛 —— `GROUND_SCREENS` 里地可见的那些）：双击同样「进包 + 开背包」，**只要那一屏有背包按钮**；没有背包按钮的屏（结算）不接。推荐实现成 `GameScreen` 的一个可选钩子 `open_bag()`，地图屏实现它，别的屏有按钮的也实现，导演在栈顶变化时把地的双击转给栈顶屏的 `open_bag` 路。

## 三、改动点

| 文件 | 改动 |
|---|---|
| `ui/inventory/ground_layer.gd` | uid 集合基线、`_landing`、`_process` / `_draw` 插值、动画中不接抓取、起点规则（§2.1） |
| `core/inventory/item_stash.gd` | `landing_from`（运行时字典，不存档） |
| `ui/inventory/drag_layer.gd` | 放手 / 顶出时写 `landing_from` |
| `ui/game/map_screen.gd`（及有背包按钮的屏）、`ui/game/game_director.gd`、`ui/game/game_screen.gd` | `_on_ground_double`：转移 + `toggle_bag()`；`open_bag()` 钩子；导演按栈顶转发（§2.2） |
| `ui/game/inventory_panel.gd` | 「放不下」那句提示抽成可复用的函数 |
| `tests/ui/test_ground_landing.gd` 新（若 UI 测试目录存在；否则进 `tests/inventory/`） | 新插入的 uid 进 `_landing`、播完删掉；`set_stash` / 回节点不播；`landing_from` 读完即删且不进 `to_dict`；地图屏双击：放得下 → 板上有、地上无、背包开；放不下 → 地上仍有、背包开、提示那句；背包开着时地图屏不抢 |
| `docs/architecture.md` 3.4 | 一句「落地有动画，只是样子」 |

## 四、待定（都按推荐）

| # | 问题 | 推荐 | 备选 |
|---|---|---|---|
| 1 | 拖拽放手要不要动画 | **只缩放 + 弹跳，不位移**（放手点就是落点） | 不播 |
| 2 | 核心层放进来的（战利品放不下等）从哪落 | **最近的面板边缘**，没面板从上方落 | 一律从上方落 |
| 3 | 双击放不下时提示在哪 | **背包面板里的提示行**（复用现有那句） | 地上飘一行字 |
| 4 | 没背包按钮的屏（结算）双击 | **不接** | 也开背包（结算屏没有背包） |
| 5 | 动画中能不能抓 | **不能**（0.28 秒，几乎感觉不到） | 能，抓了就打断 |
