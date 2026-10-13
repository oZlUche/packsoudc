# 方案：「全部拾取」先塞包再塞件；放不下的落地动画从棋盘起飞、飞着也能抓（162）

> 作者原话（2026-10-12，架构设计）：「【全部拾取】的逻辑应该是先将战利品里的包塞进我方棋盘（放不下再抛出），然后尝试将道具塞入棋盘。还有，当道具放不下时的掉落，动画应该从棋盘处开始播放落下，且播放过程中的道具依旧可以被点击拖动。玩家手动拖出时同理」
> 性质：架构 · 实施。待定按推荐。关联 087（连包搬）、123（全拿先进棋盘）、128（地上）、134（落地动画）、159（没拿的落地）。

## 1. 现状

- 「全部拾取」（`container_screen.take_all` → `InventoryService.transfer_all_prefer(待拾取, 棋盘, 地上)`）的搬运顺序是 `_take_order`：**不是包的排前面**，按占格数从大到小，包排最后。于是先塞件、件塞不进（棋盘上包的空位不够）就落地，最后才轮到包 —— 和作者要的正好反过来。087 的「带东西的包连内容物一起搬」（`_transfer_bag`：内容物先各自进目标、包最后）仍在。
- 落地动画（134，`GroundLayer`）：起点看 `ItemStash.landing_from[uid]`：给了全局像素就从那里飞；`true` = 就地（只缩放 + 弹跳）；**没给**就从离落点最近的已登记面板边缘飞出、没面板从上方落下。「全部拾取」放不下的那几件没人写 `landing_from`，所以从面板边上飞出来，不是从它在棋盘上的那格。拖拽放手落地写的是 `true`（就地）；顶替顶出去的那件写了它在棋盘上的格子（`drag_layer.gd` 644 行）—— 作者要的正是这个写法。
- 半空中的不接鼠标（`uid_at_local` 跳过 `_landing` 里不在 `in_place` 的那件，0.28 秒）。

## 2. 改法

### 2.1 先包后件

- `InventoryService._take_order` 改成：**作为包生效的排最前**（大包先），然后其余件按占格数从大到小。`transfer_all_prefer` 不动：包先进棋盘（棋盘是 `requires_bag` 的，包落在裸格上），放不下的包落地（「放不下再抛出」）；接着件逐个进棋盘，这时棋盘上多了刚塞进去的包，能进的更多。
- 087 的连包搬保留但顺序配合：待拾取里带着东西的包，`_transfer_bag` 先把内容物各自塞进目标再塞包 —— 改成**先塞空包、再把内容物一件件按普通件的顺序塞**（内容物进了 `loose` 列表排进 2.1 的顺序里），这样内容物有机会进它原来那个包。塞不进的包连内容物一起到地上的逻辑不变（`_transfer_bag` 失败时回滚）。
- `fold_loot_into_search`（搜索里打赢）和 159 的落地不走这条，不动。
- 仓库的「一键置入」（109）同样是 `transfer_all_prefer`，顺序跟着变 —— 仓库不收包（`keeps`），包排前面只是立刻失败落回，无害。

### 2.2 落地动画从棋盘那格起飞

- `container_screen.take_all()`：调搬运**之前**，给待拾取里每件记起点 `flow.run.storage.landing_from[uid] = _loot_view.global_position + _loot_view.cell_origin_px(inst.origin)`（和 644 行顶出同一写法）；搬完把没落地的 uid 从 `landing_from` 里清掉（它们进了棋盘，不需要起点；留着会让下一次落地错位）。`GroundLayer._scan` 在地上 `changed` 时消费起点，`end_batch` 只发一次信号，时机对得上。
- 单件拖出棋盘到地上：作者说「同理」—— 现在是放手点就地落下（`true`），改成**从它在棋盘上原来那格飞到放手点**（起点 = 拖起时记下的 `grid_view.global_position + cell_origin_px(origin)`，拖拽层拖起时已经知道来处）。从地上拖到地上照旧就地。
- 放不下弹回地上的（拖拽层 `_can_shed` / 顶出）本来就从格子起飞，不动。

### 2.3 飞着也能抓

- `GroundLayer.uid_at_local` 不再跳过半空中的：命中区用 `landing_pose(uid)` 的当前位置与缩放（`item_rect` 乘上 pose），抓到就 `_landing.erase(uid)`（动画停在被抓那一刻，拖拽层接手）。排队还没出现的（`hidden`）照旧不接。
- 双击同理（双击 = 抓两下）。
- 测试直接调 `advance_landing(0.1)` 后 `uid_at_local(半空中的位置)` 能命中。

### 2.4 测试

- `test_inventory_service`：待拾取 [件 A、件 B、皮革包]，棋盘上只有一个包且件 A 放不下 → 先塞包，包进了之后 A、B 都进；包放不下时包落地、件各自试；带东西的包：空包先进、内容物按序进原包。
- `test_ground_layer`：全部拾取后落地那件的起点 = 它在战利品视图里的格子；拖出棋盘的起点 = 原格；半空中可抓且抓了动画停。
- `test_node_screens`：「全部拾取」件数与落地件数在新顺序下的期望值。

## 3. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 手动拖出的起点 | A 从棋盘原格飞到放手点（「同理」）；B 保持就地（只弹跳） | **A** |
| 2 | 半空中被抓后 | A 动画停、拖拽层接手；B 先飞完再接 | **A**：作者原话 |
| 3 | 一串落下的错开（134 的 stagger） | A 保留；B 全部同时起飞 | **A** |

## 4. 改动范围

| 文件 | 改什么 |
|---|---|
| `core/inventory/inventory_service.gd`（`_take_order`、`_transfer_bag`） | 2.1 |
| `ui/game/container_screen.gd`（`take_all`）、`ui/inventory/drag_layer.gd`（拖出的起点） | 2.2 |
| `ui/inventory/ground_layer.gd`（`uid_at_local`、`item_rect` 按 pose） | 2.3 |
| `tests/inventory/test_inventory_service.gd`、`tests/ui/test_ground_layer.gd`、`tests/ui/test_node_screens.gd` | 2.4 |
| `docs/architecture.md` 3.4（地上）、6.1（战利品）那两段 | |

## 落地记录（2026-10-12）

待定按推荐。

- `InventoryService.transfer_all_prefer`：先搬包（大的先），带东西的包拆开（包进背包或暂存区，内容物进待放清单），再按格数从大到小放其余的；`_transfer_bag` 改成先收包、再收内容物，回滚倒序。`transfer_all` 照旧（包排最后）。
- 「全部拾取」开搬前给每件记 `ground.landing_from[uid]` = 它在战利品格子上那一格的左上角；没落地的再擦掉。
- 手动拖出：`DragLayer` 抓起时记原格左上角（`_src_px`），放到外面 / 地上时 `landing_from` 用它（不是从格子抓的照旧 `true`）。
- `GroundLayer.uid_at_local` / `grab_cell_at` 认飞行中的姿态（`_cell_under` 按缩放与位置反算），半空中能点能拖；抓了就停那一件的动画。
- 测试：`tests/inventory/test_take_all_162.gd`（包先进、半空可抓、落地从原格起飞），`test_ground_landing.gd` 补两条。

## 补充一（2026-10-13）：下坠速度跟密度走 —— 重的沉、轻的飘

> 作者原话：「物品掉落的动画太快了，最好做个跟密度（重量/格子数）挂钩的下坠速度」。性质：实施（小）。待定按推荐。关联 134（落地动画）、129 / 137 / 161（重量公式，包为 0）。

### 1. 现状

`ui/inventory/ground_layer.gd`：所有件一个节奏 —— `LAND_SEC = 0.28` 秒，前 75% 三次缓出落到落点、后 25% 弹 `LAND_BOUNCE = 6` 像素，起始放大 1.15、透明 0.6；排队间隔 0.04 秒。从棋盘飞到地上（162）也是 0.28 秒，跨半个屏幕就是一闪。

### 2. 改法

- **密度** = `ItemWeight.of(def) / def.cell_count()`（每格几重）。按 129 / 137 / 161 的公式天然分档：包 0、轻物（药 / 食物 / 弹药 / 饰物）0.5、普通（木骨皮布陶）1、石与晶 2、金属 3、重物 4；写死 `weight` 的件按实际比值走，连续取值。
- **时长**：`sec = clamp(0.95 − 0.15 × 密度, 0.35, 0.95)` → 包 0.95、轻物 0.88、普通 0.80、石 0.65、金属 0.50、重物 0.35。普通件比现在慢近三倍，重物也比现在慢一点但明显比别的快。
- **曲线按两档**（密度 ≥ 2 为「沉」，否则「飘」）：
  - 沉：位移二次**缓入**（像被重力拽下去，越落越快），落稳时弹 3 像素、一下即止；起始放大 1.05（重的不该看起来飘起来）。
  - 飘：位移三次缓出（现在的曲线），弹 6 像素；下落途中左右小幅摆 `±3 × sin(2π × p)` 像素（像纸片 / 布包荡下来）；包额外把摆幅放到 ±5。
- **每件记自己的时长**：`_landing[uid]` 加 `"sec"`、`"profile"`（`advance_landing` / `landing_pose` 用件自己的 `sec`，不再读常量 `LAND_SEC`）；`GroundLayer.land_profile(def) -> Dictionary {sec, sink, bounce, sway}` 静态函数，常量表 `LAND_BASE_SEC = 0.95`、`LAND_SEC_PER_DENSITY = 0.15`、`LAND_SEC_MIN = 0.35`、`LAND_SINK_DENSITY = 2.0`。
- 排队间隔 `LAND_STAGGER` 不变；半空可抓（162）、就地落（134）照旧，只是时长按件。
- 拖拽放手就地落（`in_place`）也按件的时长，但没有位移只有缩放与弹，轻物不摆。

### 3. 测试

`tests/ui/test_ground_landing.gd`（或 162 的测试文件）：重物 `sec` 最短、包最长、普通件在中间；`advance_landing` 到各自 `sec` 才删；沉档中点位置比飘档中点更靠近起点（缓入 vs 缓出）；飘档中点 x 有偏移、沉档没有；`in_place` 不摆。

### 4. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 补 1 | 时长看什么 | A 只看密度（固定时长）；B 密度 + 飞行距离（远的加时，封顶 +0.3 秒） | **A**：可预期、好测；重物远飞快一点正像被扔出去 |
| 补 2 | 分档阈值 | A 密度 ≥ 2 算沉（石、金属、重物）；B ≥ 3（只金属与重物） | **A**：石头和晶体也该砸下去 |
| 补 3 | 数值放哪 | A `GroundLayer` 常量；B 进 `standard.json` 规则 | **A**：纯表现，不是规则 |

### 落地记录（补充一）

- `GroundLayer.land_profile(def) -> {sec, sink, bounce, sway, scale}`，常量 `LAND_BASE_SEC / LAND_SEC_PER_DENSITY / LAND_SEC_MIN / LAND_SINK_DENSITY`；沉的起手放大 `LAND_SCALE_SINK = 1.05`、弹 `LAND_BOUNCE_SINK = 3`，飘的摆幅 `LAND_SWAY = 3`、包 `LAND_SWAY_BAG = 5`。`LAND_SEC` 常量删掉，每件在 `_landing[uid]` 里记 `sec` 与 `profile`，`landing_sec(uid)` 给测试看。
- 摆按整段进度 `sin(2π × p)`，起点终点都是 0；就地落（`in_place`）不摆。
- 轻物的重量是向上取整的整数（`ItemWeight`），所以一格的药密度是 1、两格的才是 0.5 —— 按实际比值走，和方案「写死的按实际比值」一致。
- 测试：`tests/inventory/test_ground_landing.gd` 加 `run_density_profile`（各档时长、沉 / 飘中点、摆、各自时长到了才删、就地不摆）；老用例改读每件自己的时长。

## 补充二（2026-10-13）：拖出容器的东西竖直往下掉 —— 重力加速度 + 重心翻转，落在正下方的「地」上

> 作者原话：「关于物品拖出容器（棋盘、战利品、搜索容器）后，应该固定朝下方掉落，且有重心系统让掉落更加自然，也就是模拟重力加速度」。性质：架构 · 实施。待定按推荐。关联 128（地上 = 格子外整块屏幕，落点只是样子）、134（落地动画）、162 主体（从棋盘格起飞）、162 补充一（密度定快慢 —— 本补充把它的「时长公式」换成重力模型，沉 / 飘两档与左右小摆保留）。

### 1. 现状

- 地上的落点是「放哪就在哪」（128）：手动拖出 = 放手点；自动掉（战利品放不下、顶出、全部拾取）= `ItemStash.next_free_spot` 从左下角铺。
- 落地动画（134 / 162）是从起点到落点的**直线插值**，起点在棋盘格或面板边缘，落点可能在起点的任何方向 —— 东西会斜着飞、甚至往上飞。

### 2. 改法

#### 2.1 落点：正下方的「地」

- **地** = 这一列往下第一个支撑：某个登记面板（`reserve`）的上沿，或屏幕底（`1.0 − SPOT_MARGIN`）。`GroundLayer.floor_under(x_range, from_y) -> float`：在件的横向范围内扫 `reserved_rects()`，取 `from_y` 以下最高的面板上沿；没有就屏幕底。
- **起点**（作者补，2026-10-13：「掉落动画的初始位置应该是鼠标松开时道具的位置，而不是原本棋盘内的位置」）：手动拖出 = **松手那一刻残影的位置**（`DragLayer` 的 `ghost_anchor`，整个 Vector2，不只是 x）；自动掉（战利品放不下、顶出、全部拾取）= 那件在源容器里格子的位置（162 主体）。162 主体里「手动拖出也从原格起飞」那一条（`drag_layer.gd` 写 `landing_from = _src_px`）**作废**，手动拖出改写松手点。
- **落点** = 起点的 x + 地 − 件高。横向超出屏幕夹回去。
- 所有进地上的路径都走同一处：`GroundLayer` 在 `_on_changed` 里发现新 uid 时，若 `landing_from` 给了起点像素，就 `stash.set_spot(uid, spot_below(from_px, inst, rot_rest))` 覆盖核心层给的落点（核心层不认识像素，照旧给 `next_free_spot`，只是会被界面层改掉）。`DragLayer.drop_at` 不再自己算 `spot_for_drop`，只写 `landing_from = 放手点` 后 `insert`。
- 面板关掉（`unreserve`）时，**支撑在它上沿的件再掉一次**（记 `_support[uid] = panel`；没支撑的不动）。128 的「面板关了也不挪回」改成这一条 —— 只往下掉，不往回挪。
- 地上件之间照旧不碰撞、允许重叠（128 3.4）：落在别的件上面就是压在上面，不堆叠（待定 4）。

#### 2.2 下落：重力 + 末速度

- 状态机：`_landing[uid] = {from, to, y, vy, t, rot_from, rot_to, profile}`，每帧 `vy += g × dt`，`y += vy × dt`，到 `to.y` 触地。`g = LAND_G × 屏高`（`LAND_G = 2.0` 每秒平方，1080 屏约两千像素，掉半屏约零点七秒；待定 3）。
- 密度（162 补充一）决定**末速度与弹跳**，不改 g：沉（密度 ≥ 2）`v_max = ∞`、触地弹 `clamp(v_impact × 0.004, 2, 6)` 像素一下即止；飘（< 2）`v_max = 0.5 × 屏高 / 秒`、弹 6 像素、左右小摆 ±3（包 ±5，`v_max = 0.35 × 屏高 / 秒`）。排队间隔 `LAND_STAGGER` 不变。
- 起点就在地上（放手点已经贴着地）：只有重心翻转与缩放弹跳，没有位移。
- 缩放 / 透明：沉 1.05 → 1、飘 1.15 → 1，透明 0.6 → 1 照 134。半空可抓（162 主体）照旧，抓住即停。

#### 2.3 重心翻转

- **重心** = 占格中心的平均（每格一样重；写死 `weight` 的件也按格算，重心是形状的事）：`ItemShape.center_of_mass(rot) -> Vector2`（格单位）。
- **落稳朝向** `rot_rest`：四个朝向里**重心离底边最近**的那个（重心 y 到底边的距离 ÷ 件高最小）；并列取横向更宽的；再并列取当前朝向。长条躺平、L 形长边朝下、T 形横杠朝下、方块不转。
- 下落途中从当前朝向转到 `rot_rest`（走最短的一边，缓入 —— 越落转得越快，触地时正好转到位），绕重心转（`draw_set_transform` 以重心为轴，落点 x 按「重心 x 不变」反推包围盒左上角）。触地后 `inst.rotation = rot_rest`、`set_spot` 写最终落点；再拖起来就是这个朝向（和现在一样，地上记朝向）。
- 待定 2 选 B 时跳过本节，只竖直落。

### 3. 测试

`tests/ui/test_ground_landing.gd`（或 162 的测试）：
- 放手在屏幕中间 → 起点 = 松手时残影位置（不是原格）、落点 x = 放手 x、y = 屏底 − 件高；放手在登记面板正上方 → 落在面板上沿；面板 `unreserve` 后那件再掉到屏底。
- `landing_from` 给了起点的自动掉（战利品放不下）落在源格正下方，不再在左下角铺。
- 重力：同一高度金属比包先触地；`vy` 单调增到触地（沉）/ 封顶在 `v_max`（飘）。
- 重心：`center_of_mass` 对 T 形、L 形、长条的结果；`rot_rest` 长条 → 横、L → 长边在下、方块不变；触地后 `inst.rotation == rot_rest`。
- 半空抓取停止动画、`landing_pose` 返回当前 y 与角度。UI 棘轮不涨。

### 4. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 补 1 | 落在面板上沿还是绕开面板 | A 落在面板上沿当桌面，面板关了再掉一次；B 落到面板下面的地，横向推开 | **A**：「往下掉」只有一个方向，B 又回到斜着飞 |
| 补 2 | 重心翻转 | A 转到重心最低的朝向；B 不转，只竖直落 | **A**：作者要的「重心系统」就是这个；B 留作性能或观感不好时的退路 |
| 补 3 | 重力大小 | A 固定像素（每秒平方两千四百）；B 按屏高（`LAND_G = 2.0` 屏高 / 秒²） | **B**：各分辨率一个节奏 |
| 补 4 | 地上件相互堆叠 | A 不堆，允许重叠（128 现规则）；B 落在下面的件上 | **A**：堆叠就把地上做成了第二个要整理的棋盘，128 明确反对 |

### 5. 改动范围

| 文件 | 改什么 |
|---|---|
| `ui/inventory/ground_layer.gd`（`floor_under`、`spot_below`、`_support`、重力状态机、`landing_pose` 带角度、`unreserve` 再掉） | 2.1 / 2.2 |
| `core/inventory/item_shape.gd`（`center_of_mass`、`rest_rotation`） | 2.3 |
| `ui/inventory/drag_layer.gd`（`drop_at` 改写 `landing_from` 后 `insert`，不算 `spot_for_drop`） | 2.1 |
| `ui/inventory/container_view.gd` / `InventoryView` 画单件时支持绕重心的角度（只地上层用） | 2.3 |
| `tests/ui/test_ground_landing.gd`、`tests/inventory/test_item_shape.gd` | 3 |
| `docs/architecture.md` 地上那一节（128 / 134 的落点与动画描述） | |

### 落地记录（补充二）

- 待定全按推荐：补 1 A（落在面板上沿，关了再掉）、补 2 A（转到重心最低的朝向）、补 3 B（`LAND_G = 2.0` 屏高 / 秒²）、补 4 A（不堆叠）。
- 落点与朝向在发现新件那一拍就写成终态（`set_spot`、`inst.rotation = rest`），存档里不会存半空的样子；动画只画「起手朝向的格子绕重心转 + 重心沿重力落下」。方案写的是「触地后写」，效果一样，少一种中间态。
- 下落不是逐帧积分，是按时间直接算（`_fall_progress`：先 ½gt²，到末速度后匀速），所以同一件不管帧率怎样，触地时刻都一样，测试也好卡点。`landing_sec` = 触地时刻 + 弹一下（0.18 秒）。
- 补充一的「时长公式」退了：`land_profile` 只给沉 / 飘、末速度、弹、摆、起手放大。贴着地（落差不到 1 像素）或就地放下的按 `LAND_PLACE_SEC` 0.2 秒做缩放与翻转，再弹一下。
- 地上单击一下（拿起、没挪、没转、又放下）仍算就地落下，不往下掉 —— 否则紧跟的双击会落空（反馈修过的那条）。挪了 4 像素以上才算拖出去。
- 拖出去时转过（R）的朝向现在会带到地上（以前地上照旧用拿起前的朝向），落下途中再按重心转。
- 没写起点的（核心层自己找空处的）从落点正上方 60 像素竖直落下；「从最近的面板边缘斜着飞出来」那条删了。
- 测试：`tests/inventory/test_ground_landing.gd`（`run_gravity_profile`、`frame_fall_onto_panels`、`run_rest_rotation`、`run_fall_turns_to_rest`，拖出那条改成从松手处起落）。
