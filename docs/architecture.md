# 背包搜打撤 — 架构设计文档

> 版本：v0.1 ｜ 引擎：Godot 4.7 (Forward+ / Jolt) ｜ 状态：设计阶段，尚无游戏代码

## 0. 游戏概述

一款 **roguelite + 背包构筑 + 自动战斗 + 搜刮撤离** 的混合玩法游戏。

核心循环：

```
进入地图 → 选择路线深入 → 遭遇战（自动战斗）→ 搜刮敌人掉落
   → 受背包格子限制做取舍 → 继续深入（更高风险/更高收益）或撤离
   → 撤离成功则战利品进入仓库；死亡则全部丢失
```

四大机制：

1. **异形格子背包**：物品占据不同形状/尺寸的格子，可旋转，跨容器拖拽。
   空间模型以《背包乱斗》为准：**棋盘 + 玩家自己放包体拼出可用区，没有装备栏**（见 3.2）
2. **自动战斗**：背包内物品编译成战斗能力，双方自动对轰，邻接关系影响数值
3. **肉鸽地图**：程序化生成的点线图，可插拔多种生成形态
4. **搜刮系统**：战后搜索敌人尸体，渐进式揭示掉落物（三角洲行动风格）

---

## 1. 架构总原则

### 1.1 逻辑与表现彻底分离

**所有游戏逻辑写成不继承 `Node` 的纯类**（`RefCounted` / `Resource`），场景树只负责渲染和输入。

`res://core/` 目录下任何文件 `grep "extends Node"` 都应该搜不到 —— 这是架构没跑偏的自检指标。

这一条决定了后续能否实现：

- 存档（状态可直接序列化，不依赖场景树）
- 战斗回放与倍速
- 批量模拟（一秒跑一万场战斗做数值平衡）
- 单元测试（不需要启动场景）

如果一开始把格子做成 `Control` 子节点、把战斗状态存在节点上，后面全部要重写。

### 1.2 命令进、信号出

UI 调用服务方法（`InventoryService.move(...)`），服务改完状态后发信号，UI 收到信号后**从状态完整重建视图**，不做增量猜测。

增量渲染是背包类游戏 bug 的主要来源（拖拽中断、跨容器失败回滚、旋转撤销等场景下增量状态极易与真实状态脱节）。

### 1.3 EventBus 只传 UI 通知

逻辑层之间用直接引用（`RunState.player_inventory`），**不要**让战斗结算、掉落生成靠全局信号串起来 —— 那样既没法单步调试，也没法脱离场景批量模拟。

`EventBus` 的唯一职责是：逻辑层 → 表现层的单向广播。

### 1.4 随机数分流

`RunRNG` 按用途开独立随机流：`map` / `loot` / `battle` / `shop` / `event`。

每个流的种子 = `hash(run_seed, stream_name, context_index)`。

否则改动战斗中的一次随机调用，整张地图都会变化，bug 无法复现。

---

## 2. 模块依赖与连接方式

```
                      ┌──────────────────────────────┐
                      │  GameDirector (autoload)      │  场景流状态机
                      │  RunState    (autoload)       │  当前 run 全部数据
                      │  EventBus    (autoload)       │  逻辑→UI 单向广播
                      └───────────────┬──────────────┘
                                      │ 持有
      ┌──────────────┬────────────────┼──────────────┬──────────────┐
      ▼              ▼                ▼              ▼              ▼
 GridInventory   MapGraph         BattleSim      LootRoller      RunRNG
  (纯逻辑)    + MapNavigator       (纯逻辑)       (纯逻辑)     (分流随机源)
      │         + MapGenerator*        │              │
      │           (可插拔)             │              │
      │              ▲                 │              │
      │        ActionClock ──► ErosionField           │
      │        (行动计数)      (侵蚀推进/惩罚)        │
      │              │                 │              │
      │ 快照 ──► CombatantSpec ────────┘  EventLog[]  │ 填充
      │                                        │      ▼
      │                                        │  GridInventory(尸体容器)
 ═════╪════════════════════════════════════════╪══════════╪════════════
      ▲              ▲                         ▲          ▲   只读 + 发命令
 InventoryView   MapView                  BattleView   SearchView
                (+ LayoutStrategy*)
 (Control 场景层：订阅信号，不持有游戏状态)
```

带 `*` 的是**策略接口**，存在多个实现，可在运行时按章节/配置切换。

---

## 3. M1 · 网格背包系统（地基，最先实现）

### 3.1 数据结构

```gdscript
# core/inventory/item_shape.gd —— 静态形状定义
class_name ItemShape extends Resource
@export var cells: Array[Vector2i] = [Vector2i(0,0)]   # 相对原点的占格
# 运行时预计算 4 个旋转：(x, y) -> (-y, x)，平移到 min = (0, 0) 后排序，
# 得到与书写方式无关的规范形式

# core/inventory/item_def.gd —— 静态定义，全局共享只读
class_name ItemDef extends Resource
@export var id: StringName
@export var shape: ItemShape
@export var rarity: int
@export var tags: Array[StringName]

# —— 包体 ——
@export var is_bag: bool = false               # 本物品是否是「包」
@export var bag_accept_tags: Array[StringName] # 包内准入标签，空 = 不限

@export var bag_mods: Array[StatModifier]      # 仅 is_bag 时生效，作用于内容物

# —— 战斗 ——
@export var combat: CombatProfile              # 冷却、基础属性、是否主动；空 = 不参战
@export var adjacency: AdjacencyProfile        # 邻接标记（增益／受益）；空 = 与邻居无互动

# core/inventory/item_instance.gd —— 运行时实例，可变
class_name ItemInstance extends RefCounted
var uid: int             # 全局自增唯一 id
var def: ItemDef
var rotation: int        # 0..3
var origin: Vector2i     # 在所属容器中的锚点
var container_id: int
var state: Dictionary    # 耐久 / 充能 / 随机词条 / locked
```

**`ItemDef`（共享只读）与 `ItemInstance`（运行时可变）必须分开。**
存档只写 `def.id` 字符串 + `state`，不写 Resource 路径 —— 否则改动资源路径会导致存档失效。

### 3.2 空间模型：棋盘 + 包体，不是固定网格

这是整个背包系统的核心规则，**照《背包乱斗》的结构来**，不要凭「背包构筑大概长这样」的印象设计。

#### 两种容器模式

| 模式 | `requires_bag` | 用途 | 规则 |
|---|---|---|---|
| **棋盘** | `true` | 玩家的作战背包 | 盘面固定（如 7x9），**开局全部不可用**；可用格来自玩家放上去的「包」 |
| **自由容器** | `false` | 暂存区、敌人尸体、商店货架 | 整片可用，物品直接摆放 |

两种模式共用同一个 `GridInventory` 实现，只差一个开关。

#### 棋盘上的两层占用

棋盘有两张互相独立的占用表：

```gdscript
var _bag_owner: PackedInt32Array   # 该格被哪个包覆盖，0 = 未覆盖
var _occ: PackedInt32Array         # 该格被哪件非包物品占据，0 = 空
```

一个格子可以「被包 B 覆盖」同时「被物品 I 占据」。放置规则由此分成两套：

- **放包**：每格须在盘内、未被其他包覆盖。包之间不能重叠，但包不需要被覆盖。
- **放普通物品**：每格须被**某个**包覆盖，它碰到的**每一个**包的 `bag_accept_tags` 都须接受此物品，且这些格上没有其他物品。

#### 可以跨包，但跨包的东西谁的都不是

一件东西可以横跨两个相邻的包，只要每一格都有包覆盖。早先禁止过，理由是「容纳关系必须无歧义」——
包的效果要知道给谁，拿起包要知道带走谁。这两件事现在这样回答：

- **`bag_of` 只认整件落在里面的。** 横跨两个包的物品不属于任何包，两边的包体加成都拿不到。
  跨包因此是**用加成换空间**的取舍，不是双份加成的漏洞。
- **拿起包只带走整件在里面的。** 跨包的那件带不走（另一半在别的包里）、也留不下
  （少了一半依托）—— 它被一并摘下，记着原来的全局位置：包原样放回它就回去，放到别处它就**脱落**进暂存区。

归属仍然无歧义，只是多了一种「谁的都不是」。

副作用是包的形状仍然有意义：一把 1x3 的步枪要么在某个包里找到连续三格，要么横跨两个包
放下但拿不到任何一个包的加成。

#### 包在自由容器里只是普通物品

一个包被当作战利品搜到时，它躺在尸体容器里就是件普通异形物品，不提供任何格子。**包只有放到棋盘上才作为包生效。** 这条规则省掉了「容器套容器」的递归，实现和心智负担都大幅下降。

#### 没有装备栏

武器、护甲、药水与其他一切物品一样占棋盘格子。**空间是唯一的约束** —— 一把 1x3 的步枪值不值得带，取决于它挤掉的三格能换来什么。任何品类的免费槽位都会把这个取舍取消掉，因此不设装备栏。

需要「只收某类物品」的语义时，用**包体**表达（比如只收药水的药水带），而不是用独立槽位。

### 3.3 GridInventory：一个类服务所有容器

```gdscript
class_name GridInventory extends RefCounted
signal changed

var id: int
var size: Vector2i
var requires_bag: bool = false      # true = 棋盘模式
var accept_tags: Array[StringName]  # 容器级准入，空 = 不限
var _occ: PackedInt32Array
var _bag_owner: PackedInt32Array
var _items: Dictionary              # uid -> ItemInstance
var _blocked: PackedByteArray       # 自由容器的非矩形支持

# 放置与移除
func can_place_item(inst, origin, rot) -> bool
func place(inst, origin, rot) -> bool
func remove(uid) -> ItemInstance          # 非空的包拒绝直接移除
func rotate_item(uid, steps) -> bool      # 非空的包请走 rotate_bag
func rotate_bag(uid, steps)               # 原地转包，返回脱落的实例；失败 null
func find_first_fit(def, allow_rotate) -> Dictionary
func try_add(inst, allow_rotate) -> bool

# 顶替式放置（3.3.1）
func terrain_allows(def, origin, rot) -> bool       # 只看地形，不看谁占着
func displaced_by(def, origin, rot, ignore) -> Array[int]
func place_displacing(inst, origin, rot)            # 成功返回被顶出的实例，失败 null

# 包与容纳关系
func is_covered(c: Vector2i) -> bool
func bag_at(c: Vector2i) -> int           # 覆盖该格的包 uid
func bag_of(uid: int) -> int              # 整件装着它的包；跨包的返回 EMPTY_UID
func bags_touching(uid: int) -> Array[int]  # 碰到的所有包
func straddlers_of(bag_uid: int) -> Array[int]  # 压在该包上但没整件落进来的
func contents_of(bag_uid: int) -> Array[int]
func detach_bag(bag_uid) -> Dictionary    # 连内容物一起摘下，记录相对偏移
func attach_bag(payload, origin, rot) -> bool   # 严格版：一件不能少，给「原样放回」用
func bag_fit_report(payload, origin, rot) -> Dictionary        # {ok, fallen}，不改状态
func attach_bag_shedding(payload, origin, rot) -> Dictionary   # 依附不上的脱落并交还

# 战斗编译期使用
func neighbors_of(uid) -> Array[int]      # 四邻相接的其他物品
```

玩家棋盘、敌人尸体、商店货架、仓库全部复用这一个类。不要为它们另写实现 —— 掉落系统几乎零成本，正是因为这里没有分叉。

**暂存区不在此列**，它是个列表容器（3.4）。两者的共同部分抽在 `ItemContainer` 里：

```gdscript
@abstract class_name ItemContainer extends RefCounted
signal changed
func begin_batch() / end_batch()                  # 变更合批
@abstract func get_item(uid) -> ItemInstance
@abstract func has_item(uid) -> bool
@abstract func items() -> Array
@abstract func item_count() -> int
@abstract func remove(uid) -> ItemInstance
@abstract func admit(inst) -> bool                # 「随便找个地方放下」
@abstract func can_admit(def) -> bool             # admit 会不会成功，不改状态
```

基类只收**变更通知**与**按 uid 取放**，空间语义一个字都不进来。
`can_admit` 是搬运的前置：先 remove 再发现目标收不下，就得把东西塞回源容器，
而「塞回原位」在空间容器里未必还办得到。先问后动，收不下时源容器连碰都不用碰。

**一切道具都能转，没有「不可旋转」这个设定。** 曾经有过一个 `can_rotate` 开关，
用来钉死某些装备的朝向 —— 删了。一件占两格的东西横着还是竖着，是玩家在棋盘上的
空间取舍，不是内容作者该替他做的决定；而一个永远为 true 的字段，
只会让每一处旋转路径都多一层没有意义的分支。

**包也能转，连同里面的东西。** 内容物记的是**本地坐标** —— 相对包原点、折回包 rot 0
坐标系的位置与朝向；包换个朝向，内容物按同一个变换跟着转。包怎么转它们就怎么转，
竖着的步枪跟着变横、左上角的方块转到右上角，整件在包里的东西**永远还在包里**，
一件不掉。这就是本地坐标与全局坐标的区别（`GridInventory.to_local` / `to_global`，
逆变换在 `ItemShape.untransform_point`）。

会脱落的只有**跨包的**那些（3.2）：它们不属于这个包，带不走；包一走又少了半边依托。
它们连同原来的全局位置一起被摘下 —— 包原样放回，它们就回到原处；放到别处或换了朝向，
原处的依托没了，它们**脱落**进暂存区。拖拽残影上把它们压暗描橙，放手前就看得见。

> 第一版曾让内容物**不**跟着转、留在原处、出了轮廓就脱落。实际一试，一个明明整件在包里
> 的东西转一下就掉出来 —— 那不是脱落，是旋转出错。改成本地坐标之后，脱落只剩跨包这一种，
> 语义正好对上「依附不上才脱落」。

实现上只有一条路径：`bag_fit_report` 回答「包放不放得下、哪几件会脱落」，
`attach_bag_shedding` 照报告执行；原地转（`rotate_bag`）就是「摘下来、换个朝向放回去」，
与拖拽中按 R 走的是同一段代码，两处不会给出不同的脱落结果。
`attach_bag` 保留为**一件不能少**的严格版，只给「原样放回」用。

脱落的东西没地方去（没有暂存区、或暂存区满了）时，整件事不成立，包连同内容物退回原处。
预览提前判红 —— 不给做不到的承诺。

#### 3.3.1 顶替式放置

压在别人身上放手，挡路的被**挤出来**交还给调用方。没有它，换装就得先把旧的拖走、
再把新的拖进来 —— 每一次微调都是两次操作，而微调正是这类游戏里做得最频繁的事。

关键是把两种「放不进去」分开：

| 情况 | 判据 | 表现 |
|---|---|---|
| 地形不允许 | 出界、禁用格、没被包覆盖、跨了两个包、标签不收 | 红，只能拒绝 |
| 地形允许但压着别人 | `terrain_allows` 为真而 `can_place` 为假 | 黄，会顶掉 |
| 干净落点 | `can_place` 为真 | 绿 |

两条路径**共用同一套地形判断**（`_terrain_ok`）。各写一份的话，顶替迟早绕过某条校验，
出现「直接拖进去不行、顶着别人反而进得去」这种玩家看不懂的事。

**包不参与顶替。** 包是棋盘的地基：往包上丢东西该落进包里，而不是把包连同一整袋内容物掀掉；
反过来拖一个包去顶掉另一个包，内容物也没有着落。两个方向都拒绝，
被顶的只可能是普通物品。

被顶出来的物品处于**游离态**，谁也不持有，调用方必须给它们找地方。表现层的规则是：

- **一件** → 直接拿在手上。那几乎总是接下来要挪的东西，顶掉它再去暂存区里翻出来纯属多余。
- **多于一件** → 全部进暂存区。手只有一只。
- **暂存区不存在或塞不下** → 整件事作废，容器原样不动，预览提前判红。

最后一条是硬要求：只塞进去一半、另一半留在手上，玩家根本追不过来。
所有失败路径都必须让容器毫发无损 —— 顶替这类操作，成功时一眼看得出对错，
出问题的永远是中途放弃的那条路，而界面上只表现为「这一下好像没反应」。

### 3.4 暂存区与作战区

#### 暂存区是个列表，不是一块地方

它由 `ItemStash` 实现，**没有坐标、没有占格、没有旋转**。异形物品进来只是一行，
3×1 的长条和 1×1 的钉子占一样的位置。界面上就画成一列可拖动的行。

把它做成网格容器，等于凭空发明一套「暂存区也要会整理」的玩法 ——
而那正是这个区域存在的目的所反对的：它是让玩家腾手的地方，不是第二个要动脑子的棋盘。
真正的空间取舍只该发生在棋盘上，那里才是 build。

`capacity` 为 0 表示不限，是留给数值设计的口子。该放几件现在没定，
所以默认不限 —— 不在代码里替设计拍板。

一条限制：**带内容物的包收不进列表**。列表装不下「包 + 各内容物的相对位置」，
放进去就等于把摆好的一袋东西打散。要收起来先掏空，
与「带东西的包不能旋转」（3.3）是同一条简化。

#### 暂存区里的道具 = 不存在

它是关卡内的一块临时摆放区（搜出道具、战后搜刮战利品时用来腾挪位置），
**进入下一关时连同里面的道具一起消失**。它不是第二个背包，也不是仓库。

因此凡是「棋盘之外」的东西，对任何系统都不可见：

| 系统 | 只看 |
|---|---|
| 战斗编译（4.2） | 棋盘上的非包物品 |
| 套装计数（9.1） | 棋盘上的非包物品 |
| 道具自带的跨域效果（9.2） | 棋盘上的物品 |

实现上没有特殊处理 —— 各系统一律只遍历棋盘容器，「暂存区不算数」是这条规则的**结果**，
不需要任何一处写 `if in_staging`。

唯一的例外在 UI：离开关卡前若暂存区里还有高稀有度道具，应当提示玩家可能遗落。
这是提示，不是挽留。

> **这条尚未定稿。** 另一种设计是暂存区在关卡之间保留、只在一局游戏结算时清空
> （「带不出去」而不是「立刻消失」）。两者的差别是玩家要在**每关**还是**每局**结束前
> 做取舍，节奏完全不同。目前按「进入下一关即消失」实现；
> 两种方案对代码的要求相同 —— 都只需要各系统坚持「只看棋盘」，
> 所以推迟决定不阻塞任何模块。

### 3.5 跨容器移动必须原子化

```gdscript
# core/inventory/inventory_service.gd
func move(from: GridInventory, uid: int, to: GridInventory,
          origin: Vector2i, rot: int) -> bool:
    var inst := from.remove(uid)
    if inst == null:
        return false
    if not to.place(inst, origin, rot):
        from.place(inst, inst.origin, inst.rotation)   # 回滚，必须有
        return false
    EventBus.container_changed.emit(from.id)
    EventBus.container_changed.emit(to.id)
    return true
```

漏掉回滚分支会导致"拖到非法位置物品消失"，这是此类系统最常见的严重 bug。

### 3.6 实现要点与 Godot 特定坑

1. **不要用 `GridContainer`** —— 它做不了跨格布局。用一个 `Control`（`InventoryView`）自己 `_draw()` 画网格线，物品作为子 `Control`，位置 = `cell_coord * CELL_PX`。

2. **不要用 Godot 内置的 `_get_drag_data` / `_can_drop_data`** —— 拖拽过程中无法响应旋转键，也无法做多格高亮预览。自己实现拖拽状态机：
   - 按下：记录 `dragging_uid`，从源容器 `remove`，创建 ghost
   - `_input`：更新 ghost 位置；R 键旋转；实时对目标容器 `can_place` 并高亮（合法绿 / 非法红）
   - 松开：调用 `InventoryService.move`，失败则放回原位
   - ghost 挂在独立 `CanvasLayer` 上，避免被父容器裁剪

3. **鼠标 → 格子的映射基于物品左上角，不是鼠标位置**：
   `origin = floor((mouse_pos - grab_offset) / CELL_PX)`
   否则大件物品手感极差。

4. **碰撞检测先用朴素双重循环**。10×8 网格不足 80 次判断，完全够用。等到实现"自动整理"的暴力搜索时再考虑位掩码优化，不要过早优化。

### 3.7 验收标准

能拖、能转、能跨容器、非法位置红色高亮、序列化成 JSON 再读回来状态完全一致。
此时它已经是一个可玩的"整理背包"沙盒，可以验证核心手感。

---

## 4. M2 · 自动战斗

### 4.1 核心决策：模拟与表现彻底分离

```
背包快照 ──compile()──► CombatantSpec ──BattleSim.run()──► EventLog[]
                                                              │
                                             BattleView 按时间轴回放
```

`BattleSim` 在**一帧内跑完整场战斗**，输出事件日志；`BattleView` 只是个播放器。

收益：

- 可瞬间模拟上万场战斗做数值平衡（做数值时会极大受益）
- 快进 / 倍速 / 暂停 / 回看零成本
- 结果确定性可复现，一个 seed 即可重现任何 bug
- 战斗逻辑完全可单元测试

#### 战斗中没有任何玩家操作

**玩家的操作只发生在战斗之外。战斗中除了观看与跳过，没有任何操作余地。**

这条把上面的分离从「一个划算的设计选择」变成了**唯一可能的实现**，并直接给出几个硬约束：

| 约束 | 后果 |
|---|---|
| 胜负在开战瞬间即完全确定 | 「跳过」就是把播放游标推到日志末尾，不需要「加速模拟」这种东西 |
| `BattleView` 只有播放控制 | 倍速、暂停、跳过；**不接收任何指向战场的输入** |
| 战斗期间背包 UI 一律禁用 | 不是「改了不生效」，而是根本改不了（见 4.5） |
| **`Effect.apply()` 必须同步完成** | 不得等待玩家输入，不存在「待玩家选择」的中间状态 |

最后一条是对**内容设计**的硬约束，需要在做道具编辑器时守住：任何效果都不能要求玩家做选择。
想表达「三选一」，只能用随机（走 `battle` 随机流）或确定性规则（如「选当前血量最低的目标」），
不能弹窗。

这也让效果系统省掉了一整套异步／挂起机制 —— 如果哪天要加玩家干预，那不是加一个效果，
而是推翻本节。

### 4.2 编译阶段（背包 → 战斗单位）

这是背包构筑类游戏的灵魂，必须独立成一个 pass：

```gdscript
# core/battle/compiler.gd
static func compile(board: GridInventory) -> CombatantSpec:
    # 1. 只遍历棋盘容器（暂存区的物品不参战，见 3.4）
    # 2. 包体效果：按 bag_of(uid) 聚合，把各包的效果施加给其内容物
    # 3. 邻接标记点亮：数每件物品的增益/受益格被几个【不同的】物品占住（见下）
    # 4. 按 4.3 的数值约定结算，得到每项属性的终值
    # 5. 产出 abilities: [{cooldown_ticks, trigger, effect, snapshot_stats}]
```

#### 邻接标记：增益与受益

物品**轮廓之外的相邻格**上会标出记号，这些标记格被别的物品占住即被点亮。

参照作品用星形与菱形区分两类标记，那只是两个任意符号。**本作直接按语义命名**，
省掉「标记类型」与「效果方向」两个概念的拆分：

| 类别 | 含义 | 例子 |
|---|---|---|
| **增益** `grant` | 我给站在这些格子上的邻居加成 | 「磨刀石让相邻的武器增伤」 |
| **受益** `receive` | 站在这些格子上的邻居给我加成 | 「旁边每有一份食物，我就触发更快」 |

UI 上用什么图形表示这两类，是表现层的事，数据层不关心。

> **这不是宝石镶嵌。** 邻接标记是「谁挨着谁」，双方各占各的格子；宝石是放进宿主物品
> 孔位、不占网格、按宿主类型给不同效果的另一套系统，尚未实现。
> **`socket` / 「镶嵌」这组词留给宝石**，不要用在邻接标记上。

**关键约束：一件物品最多只能填另一件的一个增益格、一个受益格。**
一个大件压住目标的 3 个标记格，也只算 1 个。

#### 这一步是去重计数，不是匹配

由上述约束可直接得出：

```
点亮数 = 占住标记格的【不同物品】数量，上限为标记格总数
```

这是个去重计数，**天然与遍历顺序无关**，不需要任何匹配算法，也不存在确定性隐患。

只有当同一类标记的各个格子**含义各不相同**（一号格管伤害、二号格管冷却）时，才需要决定
「谁分配到哪个格」，那时才退化成真正的二分匹配。**本作不采用这种设计** —— 同一类标记的
各格同质。这条是硬约束，内容设计时不要越线；真要越线，先回来改这一节。

#### 数据形态

```gdscript
# core/battle/adjacency_profile.gd
class_name AdjacencyProfile extends Resource

## 标记格相对本物品原点的偏移。【随物品一起旋转】，
## 且必须与形状共用同一套规范化平移量（见 ItemShape.transform_point）——
## 否则转一下物品，标记位置就和实际生效的格子错开。
@export var grant_cells: Array[Vector2i] = []
@export var grant_filter: Array[StringName] = []   # 为空 = 不限
@export var grant_mods: Array[StatModifier] = []   # 每个符合条件的邻居各得一份

@export var receive_cells: Array[Vector2i] = []
@export var receive_filter: Array[StringName] = []
@export var receive_mods: Array[StatModifier] = [] # 点亮几格就得几份
```

编译期三步，全部与顺序无关：

```
对每件物品 A：
  1. 把 A 的标记偏移按 A 的朝向变换，得到绝对格坐标
  2. 收集这些格上的物品 uid，去重，按 filter 过滤 → 点亮列表
  3. 增益 → 列表里每个邻居各得一份
     受益 → A 自己得「点亮数」份
全部记完后，再按 4.3 的数值约定统一结算。
```

`compile` **必须是纯函数**：同样的背包永远编译出同样的 spec。
这样 UI 可以在玩家拖动物品时实时显示预计 DPS / 有效血量 —— 这是此类游戏的核心爽点。

#### 角色自带的基线属性

编译结果 = **角色基线 + 道具**。基线是一张属性表（`CombatantBaseline`），不是一个数字：

```gdscript
const DEFAULT_STATS := {"max_hp": 25.0, "max_stamina": 50.0}
```

**为什么不是一个 `base_hp` 参数**：那样只表达得了生命。玩家开局捡到一把枪，
却因为身上没有任何 `max_stamina` 道具而一发都打不出 —— 界面上还看不出为什么。
资源种类本来就是可扩展的（配一个 `max_xxx` 就多一种），基线必须同样可扩展。

**这是角色系统的占位。** 现在全局只有一份默认值；将来不同角色有不同的初始生命、
耐力与其他资源上限，届时由角色定义提供一份 `CombatantBaseline` 即可，
编译器与战斗一行不改。

#### 连结关系

编译期顺带记下**谁和谁通过增益／受益格连在一起**，写进 `CompiledItem.linked_uids`。

本作**没有「主武器」的设定**，所以「跟着某件特定道具一起触发」只能靠摆放上的连结
来表达：把配件贴在武器的增益格旁边，它就听得见那把武器出手
（`OnItemFired` 的 `LINKED` 来源）。这与参照作品的菱形槽是同一个意思 ——
连结关系由玩家摆出来，不是在 .tres 里配出来的。

**连结是对称的。** 「我给你加成」和「你给我加成」都算连着；非对称会让内容作者踩坑：
把配件贴上去，却只有一边听得见对方。

在编译期算好而不是运行时查棋盘，是因为战斗中背包本就冻结（4.1），
这样战斗层完全不需要认识 `GridInventory`。

### 4.3 数值约定（写编译器之前必须冻结）

这一节的每一条都会被**所有物品的数值标定所依赖**。事后改动任何一条，全部已配好的
内容都要重新平衡。因此在写 `compiler.gd` 的第一行之前就要定死。

#### 结算公式

```
终值 = 基础值 × (1 + A 类加成之和) × (1 + B 类加成之和) × … + 固定加值之和
```

- **同一乘区内的加成相加**，不同乘区之间**相乘**
- **固定加值在所有乘法之后相加**，不参与任何百分比放大
- 基础值写在物品定义上

固定加值不吃乘区放大是一个有意的取舍：它让固定来源成为前期战力，并随着乘区堆叠自然
贬值，从而压住「百分比 × 固定值」双向叠乘造成的数值爆炸。内容设计时要清楚这一点 ——
后期想加强一件物品，加乘区比加固定值有效得多。

#### 乘区分类是可扩展枚举

```gdscript
enum Buff { EMPOWER, SHARP, FIRE, HASTE }   # 追加只能加在末尾
```

结算时**遍历枚举**逐个乘上 `(1 + 该区总和)`，不写死任何一类。新增一个乘区只需在枚举
末尾加一条，公式自动多乘一个括号，计算代码一行不改。

**为什么只能追加在末尾**：定点乘法带取整，乘法顺序会影响末位。枚举声明顺序即乘法顺序，
在末尾追加一个空乘区其因子为 1，结果逐位不变；在中间插入则会重排乘法顺序，让所有历史
数值和存档对不上。

#### 定点数与取整

全流程使用定点整数，`ONE = 10_000` 代表 1.0（四位小数），与时间、冷却同一套标度。

**刻意用十进制而不是 2 的幂。** `2^16` 那种写法来自 C／嵌入式，图的是乘除能编译成移位；
GDScript 里这个好处根本不存在，代价却是设计师写的每个十进制数都被舍入 ——
`0.1` 在 `2^16` 下是 `6554/65536`，三次累加不等于 `0.3`。换成十进制后这类误差整个消失。

**为什么是一万而不是一百万。** `mul(a, b)` 要算 `a * b`，两者都是「值 × ONE」，
所以约束是「两个值之积 < 2^63 / ONE²」：`ONE = 1e4` 时余量 `9.2e10`，
`ONE = 1e6` 时只剩 `9.2e6` —— 百万血乘十倍就溢出。
四位小数对冷却是 0.1 毫秒、对百分比是 0.01%，远够用。

- 乘法取整为**四舍五入**：`(a * b + ONE / 2) / ONE`，无偏且确定
- **只在最终应用伤害或显示给玩家时才转成整数**。中途反复取整会让「两个 +5%」不等于
  「一个 +10%」，玩家能算出来，会当成 bug
- 单个乘区的减益总和若低于 −100%，该乘区因子**钳到 0**，不允许出现负数因子

#### 上下限

冷却存在下限（快到一定程度不再变快），各乘区可各自设叠加层数上限。这些阈值写在
配置资源里，不硬编码。

#### 实现

`core/battle/stat_math.gd`（定点数与乘区枚举）与 `core/battle/stat_value.gd`
（一项属性的累积器）。**这套约定是可执行的，不是文字描述** —— 改公式必须先改测试。

### 4.4 效果系统：时机、频率、消耗、内容四者分离

**硬性要求：效果不得写死。** 触发时机、触发频率、消耗、连带触发、具体效果，各自可扩展，
新增任何一种都不应改动 `BattleSim` 或导入程序。

这条约束必须在写 `BattleSim` 之前落实。一旦模拟循环按「冷却到了就打一下」写出来，
「受击时触发」「连带触发」就没有接入点了。

#### GDScript 里的「接口」

GDScript 没有 Java／C# 意义上的接口与泛型，但 Godot 4.5+ 的 `@abstract` 足够表达这套结构，
已在 4.7.1 上实测：

| 能力 | 结论 |
|---|---|
| `@abstract class` 不可实例化 | 可用，且是**解析期**报错，不是运行时 |
| `@abstract func` 强制子类覆写 | 可用 |
| `Array[基类]` 装子类、多态派发 | 可用 |
| 运行时按脚本路径动态构造子类 | 可用 |

还有一个额外好处：`@export var xs: Array[基类]` 在检视器里会自动列出**所有非抽象子类**
供选择。内容制作因此不需要手写类型名。

#### 四层结构

```gdscript
## 一条完整规则：什么时候 · 多久一次 · 付什么代价 · 做什么
class_name AbilityRule extends Resource
@export var trigger: Trigger        ## 时机
@export var cadence: Cadence        ## 频率
@export var costs: Array[Cost]            ## 消耗（可为空）
@export var effects: Array[CombatEffect]  ## 内容
```

物品的 `CombatProfile` 持有 `Array[AbilityRule]`，而不是「冷却 + 伤害」两个字段。
一件物品可以有多条规则（平时按冷却出手、受击时额外反击、开局给自己加护盾）。

#### 一切皆事件

`BattleSim` 只负责推进时间、维护状态并广播事件，不知道任何具体效果。
**战斗中每一个可观测的步骤都是一个事件**，而不只是「出手」和「受伤」：

| 分组 | 事件 | 载荷要点 |
|---|---|---|
| 时间 | `battle_start` / `battle_end` / `tick` | tick 带帧号 |
| 出手 | `item_fired` | 来源 uid、命中的规则序号 |
| 效果 | `effect_resolved` | 效果类型、来源、目标、结果摘要 |
| 层数 | `status_stacked` / `status_unstacked` | 状态键、变化量、变化后层数 |
| 资源 | `resource_changed` | 资源键、增量、原因（见下） |
| 伤害 | `before_damage` | 结算前。**同步派发**，效果在此改写这一下，见 4.6 |
| 伤害 | `damage` | 结算后。伤害类型、原始值、护盾／护甲吸收量、实际扣除量、施加方 |
| 存亡 | `died` | 阵亡方 |

**生命与耐力不各开一套事件**，统一走 `resource_changed(key, delta, reason)`。
`key` 是资源键（`hp` / `stamina` / `mana` / …），`delta` 正负表示恢复与扣除，
`reason` 说明来由（`damage` / `heal` / `cost` / `regen` / …）。

这样「生命扣除」「耐力恢复」都是同一个事件的不同取值，新增一种资源不需要新增事件类型，
也不需要改 `BattleSim`。想只听生命下降的触发器，在 `matches()` 里判断
`key == hp and delta < 0` 即可。

**`damage` 是 `resource_changed` 之外的一条独立事件**，不是冗余：
`resource_changed` 不带伤害类型，也分不清「我打了人」与「我挨了打」
（两者都表现为某一方的 hp 下降）。事件里 `side` 是**承受方**、`source_side` 是**施加方**，
`OnDamage` 靠这两个字段区分方向。

**连带触发不是一种特殊机制**，而是一个订阅 `item_fired` 并判断来源是否落在自己
增益／受益格上的普通 `Trigger` 子类。这是把时机做成可扩展接口后自然得到的结果 ——
如果把「连带触发」单列成字段，就又写死了一种。

```gdscript
@abstract
class_name Trigger extends Resource
## 关心哪些事件
@abstract func subscribed_events() -> Array[StringName]
## 事件到来时是否算命中。【只读】
@abstract func matches(ctx: RuleContext, event: BattleEvent) -> bool
## 本时机隐含的消耗，由规则在求值时并入（见「消耗型与激活型」）
func implied_costs() -> Array[Cost]: return []
```

现有子类：

| 子类 | 命中条件 |
|---|---|
| `OnSchedule` | 自发型，不订阅事件，由频率层排出时刻 |
| `OnBattleStart` | 开场一次 |
| `OnItemFired` | 别的物品出手时（连带触发） |
| `OnResourceChanged` | 某种资源发生变化时 |
| `OnResourceBelow` | 资源降到上限的 N%（或绝对值 N）以下时 |
| `OnStacksAtLeast` | 自己／对手身上有 N 层某增益减益时 |
| `OnDamage` | 受到／造成某类伤害【之后】，且不低于 N 点时 |
| `OnBeforeDamage` | 受到／造成某类伤害【之前】。减伤、免疫、反转唯一的接入点，见 4.6 |

**没有 `OnTick`。** 「每帧检查一下冷却好没好」是固定步长模拟才需要的东西，
事件驱动直接算出下一次出手的精确时刻（见 4.7）。

#### 消耗型与激活型

「拥有 3 层蓄力时」这类状态扳机有两种用法：**激活型**只要求条件成立，
**消耗型**触发后要把那 3 层扣掉。二者只差一个勾选框，不该是两个类。

实现上，消耗型由扳机向规则**隐式追加**一条 `StatusStackCost`：

```gdscript
func implied_costs() -> Array[Cost]:        # OnStacksAtLeast
    if not consume: return []
    ...返回一条 StatusStackCost(buff_id, stacks)

func effective_costs() -> Array[Cost]:      # AbilityRule
    return costs + trigger.implied_costs()
```

**为什么不让扳机自己扣层数**：`matches()` 必须只读，而消耗必须发生在频率与
其他消耗都通过之后 —— 否则「攒够 3 层但耐力不够」会把 3 层白吃掉。
脱糖成一条普通 `Cost` 后，它自动享有消耗层「全部付得起才付」的原子性，
四层结构也没有被破坏。

#### 只广播有人听的事件

把每个步骤都做成事件，代价是绝大多数事件没有任何监听者。**进入战斗时先算出订阅并集，
只开启被订阅的事件**；未被订阅的事件连对象都不构造。

> v1.3 起这层已升级为**事件 → 规则索引**（`BattleContext._by_event`）：
> 既做开关，又直接给出订阅者列表，派发从 O(全部规则) 降为 O(订阅者)。
> 下面三条约束对索引同样成立，`refresh_event_mask()` 现名 `refresh_event_index()`。

```gdscript
# 编译期／开战前
var active: Dictionary = {}          # StringName -> true
for rule in all_rules_on_both_sides:
    for name in rule.trigger.subscribed_events():
        active[name] = true

# BattleSim 内部，发事件前先查
func _emit(name: StringName, payload_builder: Callable) -> void:
    if not _active.has(name):
        return                        # 连 payload 都不构造
    ...
```

三条约束，缺一不可：

1. **掩码取双方并集。** A 方发出的事件可能被 B 方的物品监听（「敌人回血时我获得强化」）。
   按单侧算掩码会漏事件。
2. **规则集变化时必须重算掩码。** 若某个效果能在战斗中授予新规则，新规则订阅的事件可能
   尚未开启，那条规则就会静默失效 —— 这是最难查的一类 bug。
   重建由 `CombatantRuntime` 在规则集变动时自动触发，不指望效果作者记得调
   —— 施加时漏调只是少触发，**移除时漏调会让已删除的规则继续派发**，后者是真 bug。
3. **掩码是纯优化，必须不可见。** 测试里同时跑「全开」与「掩码」两条路径，
   断言两者产出的事件日志与最终状态**逐条相同**。一旦掩码影响结果，说明它被误用成了
   游戏逻辑，必须立即修掉，而不是接受现状。

第 3 条尤其重要：性能优化混进语义是这类系统最常见的腐坏方式。

#### 频率与时机分开

命中不等于执行。`Cadence` 决定「这次命中要不要真的做」，采用**两阶段**：

```gdscript
@abstract
class_name Cadence extends Resource
## 这次命中能不能执行。只读，不得改状态
@abstract func can_fire(ctx: RuleContext, now: int) -> bool
## 确认执行，在此重置冷却／计数
@abstract func commit(ctx: RuleContext, now: int) -> void
```

注意：**消耗与条件都不属于这一层**，且刻意不与冷却原子，理由见下一小节。

初期子类：

| 子类 | 语义 |
|---|---|
| `CooldownCadence` | 攒满一个周期的工作量后可执行；配 `OnSchedule` 即自发出手，配事件触发器则是内置冷却 |
| `Always` | 每次命中都执行 |

频率层**只管调度，不设卡**。「攒够 3 次才放」「每场限一次」「按概率」全在消耗层，
理由见下。

把频率独立出来、再配上组合子，收益是**组合数为乘积而非加和**：
「每 3 次攻击附带一次爆发」= `OnItemFired` + `Always` + `ChargeCost(3)`；
「开局一次性爆发」= `OnBattleStart` + `Always`。
两者都不需要新写任何类。资源消耗不在这一层，见下。

#### 资源池

生命、耐力、法力不各写一套，统一为可扩展的资源池：

```gdscript
class_name ResourcePool extends RefCounted
## 键名 → {current, max}，全部定点
func change(key: StringName, delta: int, reason: StringName) -> int  ## 返回实际变化量
func current(key: StringName) -> int
func can_afford(key: StringName, amount: int) -> bool
```

每次变动发一条 `resource_changed`。**实际变化量可能小于请求量**（打到 0 封顶、
超过上限截断），事件里记的是实际值 —— 「受到 50 伤害」和「实际掉了 12 点血」是两回事，
监听者关心的通常是后者。

资源键与上限来自编译期的 `StatSet`（`max_hp`、`max_stamina` …），因此「装备增加耐力上限」
不需要特殊处理，就是一条普通的 `StatModifier`。

#### 消耗：第四层，且故意不与频率原子

四层，顺序固定：

```
时机 Trigger  →  频率 Cadence  →  消耗 Cost  →  内容 Effect
```

以武器为例：冷却到点后，检查当前耐力是否 ≥ **实际消耗**（面板消耗经 4.3 公式结算后的值）。
**不通过则跳过本次效果，但冷却照常清零。**

这与「先全体 `can_fire` 再 `commit`」的原子语义相反，是**有意为之**：

- 若消耗与冷却原子，耐力不足时冷却不走，武器会在耐力回满的那一瞬间立刻打出 ——
  等于耐力不足毫无代价，耐力管理不构成决策
- 现在的语义下，耐力不足实打实损失一次出手机会，玩家必须为「带几把耗耐力的武器」付出代价

**这条不是疏忽，不要「修」它。** Cadence 的两阶段仍然保留，用于多个频率条件之间的组合
—— 不原子的是**频率与消耗之间**这一道。

关于等待队列：考虑过「攒着，耐力够了再补打」，**否决**。多把武器排队时的优先级、
队列长度上限、队列里的武器要不要吃后来才生效的增益，每一条都得新立规则，
而收益只是让耐力不足不那么难受。真要保留可能性，把失败策略做成一个字段即可：

```gdscript
enum OnCostFailed { SKIP }   ## 目前只实现 SKIP，留位不留实现
```

不为一个尚未确定要不要的机制先建队列。

#### 消耗是列表，且不止是资源

非武器道具通常没有消耗，但**检查环节一律保留** —— 后期必然出现「消耗 N 层某增益才能触发」
的效果，而且可能同时消耗多种。

```gdscript
@abstract
class_name Cost extends Resource
@abstract func can_pay(ctx: BattleContext, source: int) -> bool
@abstract func pay(ctx: BattleContext, source: int) -> void
```

初期子类：`ResourceCost`（耐力／法力）、`StatusStackCost`（消耗 N 层某 buff）、
`ChargeCost`（攒够 N 次）、`UsesCost`（全场限 N 次）、`ChanceCondition`（按概率）。

**「耐力够不够」与「次数攒够没有」在失败行为上完全一致** —— 都是跳过效果但不退还冷却，
所以归在同一层。把后者放进频率层会出真问题：它挡住执行却不推进冷却，
调度器于是在同一时刻反复重试，时间再也推不动。

`costs` 本身就是列表且 AND 语义，因此**不需要 `AllOf` 之类的组合子**。
计数类用 `on_attempt` 钩子记账（`can_pay` 必须只读，而没放出去的那几次也得数）。

`AbilityRule.costs: Array[Cost]` 是 AND 语义：**全部 `can_pay` 通过，才逐个 `pay`**。
这一层内部仍然原子 —— 不允许出现「扣了耐力但层数不够」的半付款。

默认消耗按物品类型给：武器默认耗耐力，法术书类默认耗法力。**写在物品定义里，
不硬编码在代码中** —— 「不耗耐力的武器」只是一件 `costs` 为空的武器，不需要任何特例。

实际消耗走 4.3 公式结算，所以「减少耐力消耗 20%」就是一条作用于 `stamina_cost` 的
普通 `StatModifier`，与增伤减伤同一套机制。

#### 多规则、多效果都是列表

两层都是列表，任何道具与武器都可以有多条：

```gdscript
ItemDef.combat.rules: Array[AbilityRule]   ## 一件物品多条规则
AbilityRule.effects:  Array[Effect]        ## 一条规则多个效果
```

一条规则内的多个效果按声明顺序依次执行，共用同一次消耗 —— 「付一次耐力，
同时造成伤害并施加灼烧」是一条规则两个效果，不是两条规则。

#### 效果

战斗效果是效果树的一支（完整的三支见 9.2）：

```gdscript
@abstract
class_name CombatEffect extends Effect
enum Target { OPPONENT, SELF, BOTH }
func scope() -> StringName: return EffectScope.COMBAT
@abstract func apply(ctx: RuleContext) -> void
```

现有子类：`DealDamage`、`ChangeResource`（增减资源，正负同一条）、
`ApplyStatus`、`RemoveStatus`、`ModifyDamage` 与 `ReflectDamage`
（后两者只在受伤前阶段有效，见 4.6）。
计划中：`FireItem`（让另一件物品出手）、`GrantRule`（战斗中授予新规则，注意上文约束 2）。

`RuleContext` 是效果访问战场的唯一入口：读写双方状态与资源池、取随机数、写事件日志、
按来源物品取属性。效果不持有 `BattleSim` 的引用，也不知道模拟循环怎么跑 ——
这样模拟循环重构时效果无需改动。

#### 确定性

规则的求值顺序必须稳定：**按 `source_uid` 升序遍历物品，同一物品内按 `rules` 声明顺序**。
`ChanceCondition` 等一切随机走 `RunRNG` 的 `battle` 流（见 1.4），不得使用全局 `randf`。

事件在同一逻辑帧内**按发生顺序排队、逐条派发**，不允许递归立即派发 ——
否则「A 触发 B、B 又触发 A」会变成栈溢出而不是可控的连锁。派发深度设上限，
超限则丢弃并记一条警告事件，便于内容出问题时定位而不是直接崩。

### 4.5 战斗内增益系统

**战斗中一切属性变化都由 buff 承载，包括资源上限。**
「强壮」提供额外生命上限，「病弱」降低生命上限 —— 不为上限另开一套机制。

buff 仅在本场战斗内存在，**战斗结束全部清空**。因此**参战属性在进入战斗时只读取一次**，
这也正是 4.1「编译期快照，战斗中不回头读背包」的直接后果。

#### 两套修饰，边界必须清楚

|  | 编译期修饰 | 战斗内 buff |
|---|---|---|
| 来源 | 包体效果、邻接标记、套装 | 战斗中由效果施加 |
| 结算时机 | 开战前编译一次 | 战斗中动态增减 |
| 生命周期 | 随背包布局变化 | 随本场战斗，结束清空 |
| 载体 | `StatModifier` | `BuffDef.mods`，同样是 `StatModifier` |

两者复用同一种 `StatModifier`，但**不是同一个系统**：编译期修饰决定「初始属性」，
buff 在其之上叠加。

由此产生的后果不需要向玩家解释，因为**战斗中根本不开放操作**（见 4.1）：
背包 UI 在战斗期间一律禁用，而不是「允许改但不生效」。
让一个会造成困惑的操作直接做不到，好过做得到却要解释。

#### 运行时属性 = 编译快照 + 活跃 buff

```gdscript
class_name CombatantRuntime extends RefCounted
var base: StatSet                     ## 编译产物，全程不可变
var buffs: Array[BuffInstance]        ## 本场战斗内的增益，结束即弃
var resources: ResourcePool

## 按 4.3 公式把 base 与所有 buff 的 mods 合并
func stat(key: StringName) -> int
```

按属性键设脏标记，只在 buff 增减时失效，不每次访问都重算。

#### 上限变动时当前值同量增加（已定）

- **上限增加时，当前值同量增加**。吃到「强壮」立刻多出一截血，反馈即时。
- **上限降低时，当前值按新上限截断**。

反过来（加上限不加当前值）会让「强壮」在满血时毫无即时反馈，玩家会怀疑没生效。

实现落在 `ResourcePool` 内部：上限变化本身是一次 `resource_changed`，
由此连带产生的当前值变化再发一条，`reason` 记为 `max_changed`，
这样监听「生命恢复」的效果不会把上限变动误当成治疗。

#### BuffDef

```gdscript
class_name BuffDef extends Resource
@export var id: StringName
@export var display_name: String
@export var is_debuff: bool = false        ## 仅影响 UI 配色与「净化」类效果的筛选
@export var max_stacks: int = 0            ## 0 = 不限
@export var duration_ticks: int = 0        ## 0 = 持续到本场战斗结束
@export var on_restack: RestackMode        ## 叠层时是否刷新时长
@export var mods: Array[StatModifier]      ## 每层一份，走 4.3 公式
@export var rules: Array[AbilityRule]      ## 复合效果的关键，见下
@export var on_apply: Array[Effect]
@export var on_expire: Array[Effect]
```

`rules` 是「复合效果 buff」成立的关键：**buff 自己也能带触发规则**。

「灼烧：每层每秒造成 2 点伤害」＝ 一条挂在 buff 上的
`OnSchedule` + `Cooldown(1s)` + `DealDamage(SELF, 2 × 层数)`。
目标是 `SELF`：debuff 挂在受害者身上，规则就在受害者的运行时上跑。
`BattleSim` 里**不需要为灼烧写任何特例**，它和物品的规则走完全相同的四层流程。

buff 带的规则同样参与事件掩码的订阅并集计算（见上文约束 2：施加 buff 会改变规则集，
必须重算掩码）。

#### buff 也走内容管线

与道具同一条路径（第 10 节）：

```
data/authoring/buffs/*.json  →  tools/import_buffs.gd  →  data/buffs/*.tres
```

导入器复用同一套注册表解析 `mods` / `rules` / `effects`，因此 buff 编辑器几乎不额外
增加代码。新增一种 buff 不写代码；新增一种**效果**才需要加脚本并登记一行。

#### 资源回复：按时间懒结算

资源按 `regen_xxx` 属性自动回复，**没有定时器，也没有每秒一次的事件** ——
事件驱动的模拟里没有「每秒」这回事，硬造一个每秒事件等于把帧又请回来了。

做法是**懒结算**：推进器每到一个时刻，按「距上次结算过了多久 × 当刻速率」一次性补上。

```gdscript
func settle_regen(now: int) -> void:      # CombatantRuntime
    for key in resources.keys():
        var rate := stat(BattleStats.regen_of_resource(key), 0)
        if rate > 0:
            resources.settle_regen(key, rate, now)
```

三条性质：

- **线性，所以勤结算不会算多。** `settle(t1)` 之后再 `settle(t2)` 与直接 `settle(t2)` 等价。
- **勤结算反而更准。** 速率被 buff 改变的那一刻正好是一个时刻点，
  在那里结算，前后两段就各按各的速率算。
- **结算要排在 buff 到期之前。** 到期之前的那一段时间里 buff 还在，
  速率就该按它算；反过来会让最后一段用上 buff 消失后的速率。

`regen_xxx` 就是一条普通属性，和 `max_xxx` 对称。所以
**「某某 buff 让耐力回得更快」不需要任何新机制** —— 一条作用于 `regen_stamina` 的
`StatModifier` 就够了，走的是和增伤同一条 4.3 公式（同乘区相加、跨乘区相乘）。

### 4.6 伤害结算管线

**一切血量的减少都走同一条管线** —— 武器命中、持续伤害、以血为代价的自伤，
区别只在伤害类型。这样减伤、护盾、免疫、反转只需要实现一次。

五步，顺序不可调换：

```
1. 确认类型      这一下能不能被护盾吸收、吃不吃护甲、要不要通知
2. 护盾吸收      能吸收则先扣护盾；中毒之类绕过
3. 受伤前效果    【同步派发】效果在这里改写伤害包：减伤、反转、免疫
4. 计算受伤量    百分比 → 固定增减 → 反转 → 护甲，然后落到血量
5. 受伤后效果    发 damage 事件；流失类不通知默认监听
```

#### 为什么要有第 3 步

护甲那种**无条件**减伤写成一个属性就够了。但这些写不进任何固定字段：

- 消耗 2 层格挡，减免 10 点
- 喝了解毒剂时，中毒伤害反转成治疗
- 全场一次，完全免疫一击

它们都有**前置条件**，而前置条件在本作里只有一种表达方式：消耗层。
所以受伤前效果必须是一条**带扳机、带消耗的普通规则**，只不过它作用的对象
是「正在结算的这一包伤害」：

```
消耗 2 层格挡减免 10 点
  on_before_damage(受到) · always · status_stack(格挡,2) · modify_damage(flat = -10)
解毒剂
  on_before_damage(受到, poison) · always · uses(1) · modify_damage(invert)
```

它因此白拿了消耗层的原子性：**层数不够就不减伤，也不会白吃掉那几层。**

#### 伤害包

```gdscript
class_name DamagePacket extends RefCounted
var type: StringName        ## 伤害类型
var raw: int                ## 原始值
var absorbed: int           ## 被护盾吸收
var flat: int               ## 受伤前效果的固定增减
var percent: int            ## 受伤前效果的百分比增减（多条【相加】）
var inverted: bool          ## 反转：伤害变治疗
var cancelled: bool
var armor: int              ## 实际被护甲挡掉的
var final: int              ## 最终结算量，正为扣血、负为回血
```

它是一本**可变账本**，在管线里被逐步改写。受伤前效果通过
`RuleContext.damage()` 拿到它 —— 放在上下文上而不是事件载荷里，
因为效果拿到的只有上下文，事件在时机层就被消费掉了。

#### 受伤前是同步派发的

普通事件一律入队，靠 `drain()` 逐条处理，连锁才不会变成栈溢出。
`before_damage` 是唯一的例外：**它必须在伤害算出来之前改到包，排队就晚了。**

代价是允许有限重入（受伤前效果自己也可能造成伤害，比如荆棘反弹），
因此有 `MAX_DAMAGE_DEPTH = 4` 兜底。两件互相反伤的道具会无限对轰，
截断并记一条 `dispatch_overflow` 比栈溢出可控。

`before_damage` **不进回放日志**：它没有可观测的结果，结果体现在随后那条 `damage` 上。

#### 伤害类型

类型只是一个标签，**它的行为全写在 `DamageTypeDef` 里**，不写在结算代码的 if 里：

| 字段 | 含义 |
|---|---|
| `shield_absorbable` | 能否被护盾吸收 |
| `armor_applies` | 吃不吃护甲减免 |
| `provokes` | 这一下会不会**招致反应** —— 反伤、吸血、格挡这类由挨打／打人触发的规则 |

内置六种：

| 类型 | 护盾 | 护甲 | 招致反应 | 用途 |
|---|---|---|---|---|
| `physical` | ✓ | ✓ | ✓ | 常规 |
| `fire` | ✓ | ✓ | ✓ | 元素线的起点 |
| `poison` | ✗ | ✗ | **✗** | 中毒：持续伤害，绕过防御 |
| `bleed` | ✗ | ✗ | **✗** | 流血：持续伤害，伤在内里，甲挡不住 |
| `reflect` | ✓ | ✓ | **✗** | 反伤：反弹专用 |
| `drain` | ✗ | ✗ | **✗** | 流失：代价、超频、献祭 |

新增一种（腐蚀、真实、精神…）＝ 加一份 `DamageTypeDef` 并登记，结算管线一行不改。

**伤害类型与乘区正交，刻意不做映射。** 绑在一起就写不出「强化影响全部伤害」——
那是一个乘区作用于所有类型；反过来「火焰抗性」是按类型减伤，与乘区无关。

#### 只有直接攻击招致反应

`provokes` 这一列是**无限反伤的真正解药**。间接伤害一律不招致反应：

| 为什么 | |
|---|---|
| `poison` / `bleed` | 持续伤害每秒跳一次。若能招致反伤，一个中毒 buff 就把反伤刷成了主要输出，而玩家根本没在攻击 |
| `reflect` | A 反 B、B 再反 A —— 两件反伤道具会互相引燃 |
| `drain` | 能招致吸血的话，割自己一刀就成了正收益 |

**这不是靠递归上限挡住的。** `MAX_DAMAGE_DEPTH = 4` 是兜底，
用来在内容把会招致反应的类型配进反弹效果时给出可定位的告警；
靠它截断意味着对轰仍然发生了四轮，只是没打穿栈而已。
「反伤不该引发反伤」是**语义**，必须写在类型上，这样对轰在第一层就终止。

反弹请用 `ReflectDamage` 而不是手写 `DealDamage`：它按伤害包的待结算量计算反弹量
（`DealDamage` 读不到那个数），并且**默认就用对了 `reflect` 类型**。

逃生口照旧：扳机里**显式**填下类型名就听得见。「中毒时净化」「流失时回一口气」
靠的就是这个 —— 作者写下类型名，就表示他知道自己在监听什么。

#### 流失：走管线，但不招致反应

`ChangeResource` 扣**血量**时不直接改资源，而是造一包 `drain` 伤害走管线。
这样「以血换速」的超频模块同样吃得到减伤与免疫 —— 而那正是玩家最想用减伤
去抵消的一类代价。

但流失**不该点亮反伤与吸血**，否则割自己一刀就成了正收益。
做法不是「不发事件」，而是在扳机那一侧过滤：

> `DamageTrigger` 的 `damage_type` 留空时，只认 `provokes` 为真的类型；
> **显式填成 `drain` 就照样听得见。**

不发事件的话，「流失时触发」这类联动就永远没有接入点，而那正是要留的口子。

#### 护盾

`shield` 是一种普通资源，由 `max_shield` 属性自动派生 —— 和其他资源一样，
配一个属性就有了，不需要改代码。它只是在管线第 2 步被优先扣除。

### 4.7 模拟循环：事件驱动，没有帧

**帧是渲染概念，模拟里不该有。** 模拟直接算出每次出手与每个 buff 到期的精确时刻，
在时刻之间跳跃。

```gdscript
while 双方存活 and now < 时限:
    next = min(所有自发规则的下次出手时刻, 所有 buff 的到期时刻)
    if next 不存在: break            # 谁也打不死谁，判平局
    now = next
    结算这一刻：先到期，后出手       # 正好此刻到期的增益不该再为这一刻加成
```

三个好处：

- **零累积误差。** 固定步长要把 `dt` 反复相加，而任何除不尽的步长都会稳定跑偏
  （`1.0 / 20` 在定点下就除不尽）。事件驱动只在离散时刻改写状态，
  冷却 0.37 秒就是精确的 0.37 秒。
- **快。** 60 秒的战斗只处理几百个时刻，而不是 1200 帧 × 全部规则。批量刷平衡才跑得动。
- **分辨率不受步长限制。** 出手间隔可以是任意小数，不再被 20Hz 网格吸附。

#### 冷却按「工作量」计，不按时间

进度累积的是工作量：每秒推进 `haste` 点，攒满 `period` 点即就绪。

这样速度变化不会丢失已有进度 —— 变速前把进度结算到当下，之后按新速率外推剩余时间。
若改为记录绝对的「就绪时刻」，一次急速加成会把整段已走过的冷却也一并缩短，
玩家会看到冷却条诡异地跳。

#### 同刻并列的顺序必须固定

一刻之内可能有多件事。顺序：**先处理 buff 到期，再处理出手**；
出手之间按 `(side, source_uid, 规则序号)` 取最小。

**每条规则在同一时刻只尝试一次。** 就绪却拒绝执行（蓄力没攒够、耐力不足）的规则不会
重置冷却，下一轮还会被选中 —— 不记账就会原地空转，时间再也推不动。

#### 数值仍用定点整数

浮点累积会漂移，导致回放与原始模拟不一致；纯整数又表达不了 Heat / Cold 的 ±2% 比例叠乘。
因此时间与数值全程使用定点整数（1.0 = 10_000，十进制四位小数），详见 4.3。

标度取十进制的直接收益：设计师写的 `0.1`、`0.37`、`2%` 全部精确可表示，
`0.1 × 3` 恰好等于 `0.3`。只有 `1/3` 这类本就无法用有限小数表示的值才会舍入。

### 4.8 表现层

`BattleView` 持有 `log` 与播放游标，`_process(delta)` 推进播放时间、消费到期事件、
更新血条、抛跳字、往事件条写一行。

**它只认事件，不认识 [BattleSim]、[CombatantRuntime] 或棋盘。** 因此：

- 快进、倍速、跳过、跳转都只是**移动游标**，不可能改变任何结果；
- `seek(t)` 就是「从头再快放一遍到那一刻」—— 没有内部状态要倒推，
  所以它不可能和正常播放不一致；
- 同一套面板将来也能放录像、放别人的战斗。

回放起点取自 `BattleResult.initial`（开战瞬间的快照），而不是让表现层自己去编译一遍棋盘 ——
那等于让它认识编译器，1.1 的分离就破了。

#### 日志要自足

表现层需要什么，日志就得带什么：

| 载荷 | 为什么非带不可 |
|---|---|
| `resource_changed` 的 `current` / `max` | 只给增量的话，表现层得自己累加；漏掉一次上限变动（强壮之类）血条的分母就永久失真 |
| `damage` 的 `absorbed` / `armor` | 「这一下为什么只掉 5 点」是看回放时最想知道的事 |
| `BattleResult.initial` | 回放的起点 |

反过来，**不进日志**的也有讲究：`before_damage` 不进（它没有可观测结果，
结果体现在随后那条 `damage` 上），物品名不进（名字是表现层的事，
塞进日志只会让每条事件都背着一串用不上的字符串 —— 表现层拿 uid 自己查表）。

#### 单位换算集中在一层

日志载荷是**定点**，而 `ResourcePool.snapshot()` 已经取过整。
两边混着往面板送，血条会显示 `0 / 0` 却画成满格，而且只在其中一条路径上出错。
换算一律在 `BattleView` 做完，面板只收显示值。

#### 沙盒

`ui/battle/battle_sandbox.tscn` 是 M2 的验收场景：左边摆背包、右边看回放。
拖动一件装备就重新编译，**预估 DPS 与套装进度实时跟着变** ——
这个实时预览之所以成立，是因为编译是纯函数（4.2）。

战斗中的物品图标直接复用 `InventoryView` 的渲染组件，视觉一致性免费获得。

#### 邻接标记必须画在棋盘上

增益格／受益格画成**四个角括号**，叠在标记指向的那一格上：增益贴着格边、受益缩在里面，
两类同时落在一格也分得清。不用整圈描边，那会和物品自己的稀有度描边撞车。

**点亮状态一并画出来** —— 这一格确实站着一个符合过滤条件的邻居时填色加粗，
否则只留细线。只画位置不画点亮，等于让玩家对着说明书心算，
而摆位正是这类游戏的全部乐趣所在。

点亮判据与编译器的 `_lit_neighbors` 一致，标记格的绝对坐标由
`ItemInstance.absolute_cells()` 统一算 —— 两边各写一遍的话，迟早出现
「界面画在这一格、实际生效在那一格」这种最难查的错。

不参战的容器（暂存区、战利品、货架）**不画**：那里的「点亮」什么也不代表，只会误导。

---

## 5. M3 · 地图系统（可插拔生成器）

> **施工顺序见 [报告 027](reports/027-m3-plan.md)**：本节是设计正本，
> 那份文档只把它拆成六个可验收的步骤，两边不一致时以本节为准。

### 5.1 设计前提

**地图形态会随章节变化。** 第一章使用同心环形地图，后续章节将使用完全不同的拓扑（分层 DAG、网格区域、开放六边形等）。

因此地图系统必须从第一天就做成可替换结构，**任何一处都不能把"环形"写死**：

| 层 | 职责 | 是否随地图形态变化 |
|---|---|---|
| `MapGraph` | 拓扑无关的点线数据容器 | **否**，所有形态共用 |
| `MapGenerator`（抽象） | 生成拓扑 + 布局元数据 + 分档标记 | **是**，每种形态一个实现 |
| `MapNavigator` | 移动合法性判定、路径查找、行动消耗 | **否** |
| `ActionClock` | 行动计数 | **否**，run 级通用设施 |
| `ErosionField` | 侵蚀推进与惩罚结算 | **否**，只认节点的 `erosion_band` |
| `MapLayoutStrategy` | 布局元数据 → 屏幕坐标与画线方式 | **是**，每种形态一个实现 |

判定标准：新增一种地图形态时，**只需新增一个 `MapGenerator` 子类和一个 `MapLayoutStrategy` 子类**，`MapGraph`、`MapNavigator`、`ActionClock`、`ErosionField`、`MapView` 主体、存档逻辑均不改动。

### 5.2 拓扑无关的数据层

```gdscript
# core/map/map_node.gd
class_name MapNode extends RefCounted

enum State { UNVISITED, VISITED }   # 仅表示内容是否已消耗，与可否通行无关

var id: int
var type: StringName        # 节点的事件类型，见 5.4「节点类型」。中途撤离点是其中一种
var danger: int             # 危险等级：0 常规 / 1 中危 / 2 高危。敌人更难、奖励更高（见 5.5）
var zone: int               # 所属危险区域的编号，0 = 常规区（见 5.4）
var tier: int               # 难度/奖励档位，数值越高越难越肥
var erosion_band: int       # 侵蚀分档，数值越小越早被侵蚀（见 5.7）
var content_seed: int       # 该节点内容生成用的独立种子（不叫 seed：会遮住 GDScript 的全局函数）
var content: Dictionary     # 节点里有什么，**生成地图时就定好**，不是踩上去才掷骰（5.10）
                            #   battle / elite / core: {enemy_id, ...}  玩家在地图上就能看敌人
                            #   random: {}  —— 唯一踩上去才知道的类型，这正是它叫「随机」的意思
var state: int              # State.UNVISITED / State.VISITED
var layout: Dictionary      # 布局载荷，由生成器写入、由布局策略解读。**只记次序，不记坐标**
                            #   环形图: {ring:int, order:int}   环序 + 环内的循环次序
                            #   分层图: {floor:int, col:int}
                            #   角度、半径、像素位置一律由布局策略算（5.9），数据层不知道

# core/map/map_edge.gd
class_name MapEdge extends RefCounted
var from_id: int
var to_id: int
var directed: bool          # 环形图全部为 false；保留字段供未来的单向形态使用
var kind: StringName        # "radial"/"tangential"/...，供布局策略决定画法
var action_cost: int = 1    # 通过该边消耗的行动点，默认 1
var layout: Dictionary      # 边的布局载荷（例：一条跨过中间几层的路记下跨了几层），数据层不解读
func other(id) -> int                  # 从这一头看过去对面是谁
func passable_from(id) -> bool         # 单向路只能顺着走

# core/map/map_graph.gd —— 拓扑无关
class_name MapGraph extends RefCounted
var layout_kind: StringName     # "ring"/"layered"/...，决定用哪个布局策略
var layout_meta: Dictionary     # 全局布局参数（环数、半径步长等）
var nodes: Dictionary           # id -> MapNode
var edges: Array[MapEdge]
var entry_ids: Array[int]
var goal_ids: Array[int]
var zones: Dictionary           # zone_id -> {"node_ids": Array[int], "gate_id": int}
                                #   高危区：与外界只有一条边相连的一片节点
var routes: Array[Dictionary]   # 每个出生点一条：{entry_id, style, node_ids, ends_at, risk, reward}
                                #   开局让玩家挑出生点时，展示的就是这一份（5.4.2）。
                                #   拓扑无关 —— 路线只是一串节点 id 加几个标签
func add_node(node) -> bool / add_edge(edge) -> bool   # id 重复、两端不存在、自环一律拒绝
func node_ids() -> Array[int]             # 升序。一切遍历走它，与加入顺序无关
func edges_of(id: int) -> Array[MapEdge]  # 挨着的全部路，不论方向
func neighbors(id: int) -> Array[int]     # 一步能到的点，单向路只算顺着的一头
func edge_between(a, b) -> MapEdge
func to_dict() -> Dictionary              # 确定性：节点按 id 升序，同一张图永远同样的字节
static func from_dict(d: Dictionary) -> MapGraph
static func normalize(v) -> Variant       # JSON 读回来的 3.0 还原成 3，否则存一次读一次字节就变
```

两条硬约束：

1. `MapGraph` 里**不允许出现任何 `ring` / `angle` / `floor` 字段**，这些只能存在于 `layout` 字典中。
2. `erosion_band` 与 `tier` **是两个独立字段，即使第一章里它们数值相等也不要合并**。侵蚀方向不必永远等于难度方向 —— 未来完全可能出现"核心苏醒、侵蚀由内向外扩散"的章节，那时两者正好相反。合并字段会把这种可能性堵死。

### 5.3 生成器抽象

```gdscript
# core/map/map_generator.gd
class_name MapGenerator extends RefCounted

## 由子类实现：根据配置与随机流生成一张完整地图
## 子类有义务为每个节点写入 tier 与 erosion_band
func generate(cfg: Resource, rng: RandomNumberGenerator) -> MapGraph:
    push_error("abstract")
    return null

## 通用校验：入口可达目标、无孤立节点、无孤立子图
func validate(graph: MapGraph) -> bool
```

生成失败时的统一策略：**换种子重新生成（最多 N 次）**，而不是写复杂的保证性算法。
后者的实现与维护成本远高于前者，且更容易出现难以察觉的分布偏差。

章节通过 Resource 声明自己用哪个生成器：

```gdscript
# data/chapters/chapter_01.tres
class_name ChapterDef extends Resource
@export var display_name: String
@export var generator_id: StringName        # "ring"
@export var generator_config: Resource      # RingMapConfig
@export var erosion: ErosionSchedule        # 可为 null = 该难度不启用侵蚀
@export var enemy_pool: Array[EnemyDef]
@export var loot_tables: Array[LootTable]
```

`MapGeneratorRegistry` 负责 `generator_id -> MapGenerator` 的映射，新增形态只需注册一行。

### 5.4 第一章：同心环形地图（RingMapGenerator）

#### 形态描述

- 以一个**核心点**为圆心，向外排布多层**同心环**，环数与每个环的类型由配置决定
- 每个环上分布若干**节点**（可访问地点），节点之间由**线**连接：
  - **切向边（tangential）**：同环相邻节点之间的弧线
  - **径向边（radial）**：相邻两环之间的连线
- **越靠近中心，难度越高、奖励越高**
- **移动是自由的，可以走回头路。** 所有边双向可通行；节点内容一次性消耗，已访问节点仅可穿行
- 约束玩家的不是拓扑，而是**时间**：每次移动消耗行动点；高难度下地图会从外向内逐层被侵蚀

**因为可以走回头路，死路不是问题。** 生成器不需要保证「每个节点都有向内的边」
或「入口到核心的最短路够长」之类的东西 —— 走进一条死胡同再走出来，
代价是行动点，而行动点正是这一章的压力所在。生成器只需保证**整张图连通**。

#### 节点类型

| 类型 | 符号 | 含义 | 性质 |
|---|---|---|---|
| `battle` | `A` | 普通战斗 | 普通 |
| `elite` | `E` | 精英战斗 | **必须型** |
| `event` | `Q` | 常规事件：奖励道具、恢复，或剧情。目前占位 | 普通 |
| `random` | `?` | 随机：进入时在 A / S / R / V / Q 里按概率挑一种。**不会**变成精英或 BOSS | 普通 |
| `search` | `V` | 搜索点：可以搜索至多 N 次找战利品，每搜一次遭遇敌人的概率上升；随时可以离开。第三种选项占位 | 普通 |
| `shop` | `S` | 商店 | **必须型** |
| `rest` | `R` | 休息区 | **必须型** |
| `extract` | （待定） | 中途撤离点 | 覆盖型，见下 |
| `junction` | — | 岔路口：路上的一个拐点，没有事件 | 手绘地图才有，见 5.4.1 |
| `core` | `B` | 章节 BOSS，最终撤离点，固定一个 | — |

符号来自作者的地图配置表 v0.1。`1` 是 v0 遗留的「缺省事件点」，解析时按 `?` 处理。

**必须型**指配置里要求「每 N 环至少一个」的类型。它们不能只靠权重抽取碰运气 ——
连续五环没有休息区，玩家撑不到核心；但也不能每环都有，那就没有取舍了。

**中途撤离点是覆盖上去的**：每 N 环挑一个**非必须型**节点，把它的类型**改成** `extract`。
那个位置原本的事件没了，换成一个出口 —— 不是「打完这场就能走」，是「这里就是出口」。
不覆盖必须型，否则休息区或商店会被出口吃掉。

> 第一版写成了「叠加属性」（一个战斗点同时是撤离点）。用户纠正：是覆盖，不是重叠。

#### 配置

```gdscript
# core/map/generators/ring_map_config.gd
class_name RingMapConfig extends Resource
## 由外向内，下标 0 = 最外环。环数 = rings.size()
@export var rings: Array[RingSpec]

## —— 路线（5.4.2）——
## 每条入口→核心的路线各有一种风格；入口数 = entry_count，风格按本列表轮流分配
@export var routes: Array[RouteStyle]
@export var entry_count: int = 3
## 向内走时，下一环的候选槽位在当前次序比例的 ± 多少个槽位之内
@export var route_drift: int = 2
## 几环之后才允许路线合流。太早合流，风格就没意义了
@export var converge_after_ring: int = 2
## 类型 → 风险分：走这一步期望损失多少体力（7.1）。
## 搜索点填的是**基准搜索次数**（reference_searches）下的值 —— 它的风险与收益都随搜索次数上升，
## 搜几次是玩家的事，生成器只按基准次数给路线定档
@export var type_risk: Dictionary = {
	"battle": 0.3, "elite": 0.8, "search": 0.15, "random": 0.3,
	"event": 0.05, "shop": 0.0, "rest": 0.0, "extract": 0.0, "junction": 0.0,
}
## 类型 → 收益分：走这一步期望拿到多少价值（6.4 的道具价值，或等值的金钱/恢复）
@export var type_reward: Dictionary = {
	"battle": 1.0, "elite": 3.0, "search": 1.6, "random": 1.0,
	"event": 0.6, "shop": 0.0, "rest": 0.2, "extract": 0.0, "junction": 0.0,
}
## 给路线定档时假设玩家在每个搜索点搜几次。实际搜几次由玩家决定，见 5.4.2
@export var reference_searches: int = 1
## danger 0 / 1 / 2 对风险与收益的倍率（分开给：高危区可以「险得多、肥得更多」）
@export var danger_risk_multiplier: Array[float] = [1.0, 1.3, 1.7]
@export var danger_reward_multiplier: Array[float] = [1.0, 1.4, 2.0]
## 各路线「收益 / 风险」之比的允许差。见 5.4.2：风格不同，性价比相当，谁也不白占便宜
@export var ev_tolerance: float = 0.2
## 相邻路线之间每隔几环要有一个换乘点（一条把两条路线连起来的边）。见 5.4.2「取舍」
@export var pivot_every_rings: int = 2

## —— 覆盖（5.4.2）——
## 类型 → 每个节点到最近该类型节点的步数上限。例：{"rest": 4, "shop": 6}
## 取代早先「每 N 环至少一个」：玩家走的是路径不是环，按环数保证等于没保证
@export var coverage: Dictionary = {"rest": 4, "shop": 6}
## danger 高于此值的区域里不放休息区与商店 —— 高危区是岔出去的诱惑，不该能在里面喘气
@export var no_haven_in_danger_above: int = 1

## —— 类型规则 ——
## 不许相邻的类型对。例：[["shop", "shop"], ["rest", "rest"]]
@export var no_adjacent: Array = []
## 每 N 环一个中途撤离点，覆盖一个非必须型节点
@export var extract_every_rings: int = 2

## —— 高危区、边、槽位（同前）——
@export var danger_zones: Array[DangerZoneSpec]
@export var tangential_break_chance: float = 0.35
@export var radial_links: Vector2i = Vector2i(1, 2)
@export var arc_per_slot: float = 60.0
@export var min_slots: int = 6
## 只用来算每环槽位数，**不是渲染距离**（5.9）
@export var radius_step: float = 110.0

# core/map/generators/ring_spec.gd —— 一个环
class_name RingSpec extends Resource
## 环的类型，内容层用它选敌人池、掉落表与美术。拓扑层不解读，只写进 layout
@export var kind: StringName
## 角度槽位数。0 = 按半径算（5.4 步骤 3）
@export var slots: int = 0
## 真有节点的槽位数。少于 slots 时空槽连成 1～2 段空白区。0 = 全部
@export var node_count: int = 0
## 类型 → [min, max]：这一环每种类型至少几个、至多几个。没列的类型不限
@export var quota: Dictionary = {}
## 类型 → 权重：配额之外的节点按它抽
@export var type_weights: Dictionary

# core/map/generators/route_style.gd —— 一种路线风格
class_name RouteStyle extends Resource
@export var id: StringName                    # "combat" / "search" / "mixed"
## 该路线独占的节点里各类型的份额（比例，不必加到 1）
## 偏战斗：{"battle": 5, "elite": 1, "event": 1}
## 偏搜索：{"search": 4, "event": 2, "battle": 1}
@export var mix: Dictionary
## 这条路线的风险分总和该落在哪个区间（相对全图平均：偏搜索 [0.4, 0.7]，偏战斗 [1.2, 1.6]）
@export var risk_band: Vector2 = Vector2(0.8, 1.2)
## 同上，收益分。低风险配低收益、高风险配高收益 —— 两个区间一起决定风格
@export var reward_band: Vector2 = Vector2(0.8, 1.2)
## 路线的尽头："core" 打 BOSS，"extract" 在核心之前的一个撤离点结束 ——
## 偏搜索的路线可以不打最终敌人，搜够了就走
@export var ends_at: StringName = &"core"
## 每隔几环在路线上放一个中途撤离点（0 = 不放）。偏战斗的路线要靠它「战损过高就撤」
@export var bailout_every_rings: int = 0

# core/map/generators/danger_zone_spec.gd —— 一片高危区（同前）
class_name DangerZoneSpec extends Resource
@export var ring_range: Vector2i = Vector2i(1, 3)
@export var size: Vector2i = Vector2i(4, 6)
@export var min_elites: int = 1
@export var min_search: int = 2
@export var gate_prefers_elite: bool = true
```

#### 生成步骤：骨架先行

路线不是从生成好的图里事后找出来的，是**先铺路线，再往路线周围长出地图**。
否则「偏战斗的路线」只能靠事后给一条碰巧存在的路径贴标签，贴不贴得上看运气。

```
1. 读配置：环数 = rings.size()，每环的 kind / slots / node_count / quota / type_weights

2. 核心节点：ring = 0，type = "core"，tier = 环数，erosion_band = 环数

3. 逐环生成节点（r = 1..环数，r = 1 为最内环，对应 rings[环数 - r]）：
   槽位数：spec.slots > 0 就用它；否则按半径算 ——
       slots = max(min_slots, round(TAU * r * radius_step / arc_per_slot))
   同心环越靠里周长越短，槽位数随之减少，每个槽位的弧长大致相等。
   在 slots 个槽位里挑出 node_count 个：空槽连成 1～2 段空白区，其余各放一个节点
     tier = 环数 - r      erosion_band = 环数 - r      layout = {ring, order, kind}
   不算角度、不算半径 —— 点画在哪儿是渲染的事（5.9）

4. 路线骨架：
   a. 最外环按次序均匀挑 entry_count 个**出生点**；第 i 条路线的风格 = routes[i % routes.size()]。
      出生点与路线一一对应，开局由玩家挑一个（5.4.2「出生点」）
   b. 每条路线从入口逐环向内走到核心：
        下一环候选 = 次序比例最接近当前节点的槽位 ± route_drift 个
        在 converge_after_ring 之前，不选已被别的路线占用的节点；之后允许合流
        选中的节点与连接它们的径向边进骨架，标 protected
      ends_at = "extract" 的路线走到核心前一环为止，末端节点定为 extract
   c. 换乘点：相邻两条路线每 pivot_every_rings 环至少有一条边把它们连起来
      （同环切向边或相邻环径向边），进骨架并标 protected。没有换乘点，
      「搜到好东西转去打」「打不动了转去撤」都做不到，风格就成了开局定终身
   d. 骨架的性质：每条路线是一条入口→尽头的简单路径。全图连通由此天然成立，
      不必事后修

5. 节点类型（优先级从高到低；后面的修正不许破坏前面的）：
   a. 路线风格：只被一条路线经过的骨架节点，按该风格的 mix 比例分配类型；
      被多条路线共用的节点算 mixed
   b. 非骨架节点按所在环的 type_weights 抽
   c. 环配额：每环每类落进 quota 的 [min, max]。超了改成权重次高的可替换类型，
      缺了从本环的非固定节点里改
   d. 覆盖修正：对 coverage 里每一种类型（rest / shop），BFS 算每个节点到最近该类型节点
      的步数；有超过上限的，就在「能覆盖最多超标节点」的候选里挑一个改成该类型，
      直到全部达标。候选 = 非固定、danger ≤ no_haven_in_danger_above 的节点
   e. 邻接规则：no_adjacent 里的类型对不相邻，违反的换成权重次高的
   f. 撤离点覆盖：先按各路线的 bailout_every_rings 在路线上放；再按全图的
      extract_every_rings 补，挑非必须型节点改成 extract
   g. 路线风险/收益校准（5.4.2）：算每条路线的风险分与收益分（type_risk / type_reward ×
      danger 倍率，沿路线求和）；不在其风格 risk_band / reward_band 内的，在独占节点里
      换类型拉回来；再看各路线的「收益 / 风险」之比，差超过 ev_tolerance 的同样调；
      循环到达标为止，超过上限换种子
   固定节点 = core、extract、高危区里为满足 min_elites / min_search 改出来的

6. 高危区（每条 DangerZoneSpec 一片）：在 ring_range 内挑起点、沿相邻节点扩张凑够 size，
   **避开骨架节点** —— 高危区是岔出去的诱惑，不能横在必经之路上；
   区内补足 elite / search；指定 gate；写 zone 与 danger = 2

7. 候选边：同环相邻槽位 → tangential（不跨空白区）；相邻环次序最近的 → radial，每节点 radial_links 条

8. 高危区隔离：删掉所有跨越区域边界的候选边，只留 gate 那一条

9. 断边：每条 tangential 候选边以 tangential_break_chance 断开。**骨架边不可断**。
   区内的边也可断 —— 区内断成死胡同没关系，走回头路就是

10. 校验（失败换种子重生成，上限 32 次；用尽则报错返回 null，不降级产出坏图）：
    - 全图连通：每个节点都从至少一个入口可达
    - 骨架完整：每条路线仍是入口→核心的一条路径
    - 覆盖：每个节点距最近 rest ≤ coverage.rest、距最近 shop ≤ coverage.shop
    - 环配额成立
    - 每个高危区：区内连通，与区外恰好一条边，不含骨架节点
    - 每条路线的风险分与收益分落在其风格的区间内；各路线收益/风险之比的差 ≤ ev_tolerance
    - 相邻路线每 pivot_every_rings 环至少一个换乘点
    - ends_at = "extract" 的路线末端是 extract
    - 每 extract_every_rings 环至少一个 extract
```

一个环生成出来**可以断成两段、三段，甚至有一整段空白**：切向边按概率断、空白区本来就没节点，
再加上高危区隔离，一环之内的几段各自靠径向边连到别的环。这是参照示意图想要的样子 ——
「每环都可以互通」指的是**每一段都从别处到得了**，不是环自己首尾相连。

**校验里没有「每个 erosion_band 内部连通」。** 侵蚀绝不封路（5.7），
被侵蚀的节点照样能走，只是有代价 —— 所以幸存区被切成几片不会困住玩家，
只是从一片到另一片要穿过侵蚀区多付一点。那正是侵蚀该有的压力，不是要避免的坏图。

**高危区的意义**是把「诱惑」做成拓扑：一片单入口的区域，里面有精英守着、
有好几个搜索点。进去就得从同一条路出来，行动点花两遍。玩家看得见入口，
看得见里面有什么类型的点，然后自己决定值不值。

#### 5.4.1 手绘地图：网格脚本格式

除了随机生成，一张图也可以**手写**。格式来自作者在电子表格里画的 `地图配置v0.xlsx`，
正式形态是纯文本（`data/authoring/maps/*.txt`），分两段、行列逐格对齐：
`[map]` 是符号层，`[danger]` 是危险层。一行一个表格行，一格一个字符，空格写 `.`。
电子表格只是顺手的编辑器，仓库里存的是文本；`tools/map_xlsx_to_text.py` 负责转。

```
1-1-1.1-1-1-1.1-1---1-1-1.1--1-1-10
.|.....|..........|............|
.1-1-1-1-1...1-1-1-1..2-2-2-2..|0
...|.........|....|.....|......|
...1-1----1--1....1-1---1.1-1--1-0
....|.....|........|.......|
....1-1-1-------1--1-1..1-1-1-0
        ⋮
...............E
```

| 符号 | 意义 |
|---|---|
| 偶数行 | 一个环，自上而下 = 自外向内；行内一格一个槽位 |
| 奇数行 | 环与环之间的连接层 |
| `A` `E` `S` `R` `V` `Q` `?` | 节点，字母就是类型（见「节点类型」表） |
| `B` | 章节 BOSS，最终撤离点，地图终点 |
| `1` | v0 遗留的缺省点，按 `?` 处理 |
| `-` | 同环通路，连左右两格。连着的 `-` 只是延长：`1----1` 是**一条**跨过四个空槽的弧，中间没有节点 |
| `\|` | 异环通路，连同列的上一行与下一行。落在 `-` 上就是**岔路口**：一条径向边接在一段弧的中间；上下连着多个 `\|` 就是**跨环路径**，一步跨过一个环 |
| `0` | 行末占位。左边是 `1` → 这一环首尾**不**相连；左边是 `-` → 首尾相连成闭环 |
| `.` | 什么都没有 |

翻成图（`MapGridText.parse`）：

- 每个字母是一个节点，字母就是类型。`-` 连成的段是一条切向边，两端是段两头的节点。
- **危险区域用底色标**，转成文本时落到 `[danger]` 层：`.` 常规、`1` 中危、`2` 高危。
  底色刷在 `-` 上也没关系，只有节点那一格算数。同一等级、相连的一片节点是一个区域（`zone`）。
  表格里刷个底色比记数字容易 —— 这就是为什么不用数字标区域。
- `\|` 落在节点上：径向边。落在 `-` 上：在那个位置插一个 `junction` 节点，
  把那段弧一分为二，径向边接在 junction 上。junction 没有事件，只是路上的一个拐点 ——
  走过它照样花行动点。
- 连续的 `\|`：一条径向边，跨过中间那些环，`layout` 里记跨了几环，布局按长度画。
- **列位置与空格数不代表距离。** 同一行里两个点隔着几个 `.` 或几个 `-`，
  只说明它们之间是否相连、中间有没有别的点，不说明画出来隔多远。
  解析只记每个点的环序（行）与环内次序（列的先后），角度由布局解（5.9）。
  `|` 说的「同列」也只是「这两个点相连」—— 画的时候会把它们对到同一个角度上，
  而不是反过来靠画得对齐来表示相连。

**反过来也要能写**（`MapGridText.render`）：随机生成出来的图导成同一种文本。
这给了三样东西 —— 生成结果人眼可读、可以手改一张生成图再喂回去、
测试里用文本做金样比对而不是比对一堆坐标。

手绘图走的是同一套 `MapGenerator` 接口（`generator_id = "grid_script"`），
`MapGraph` / `MapNavigator` / 布局 / 存档一个字不改 —— 5.1 说的可插拔在这里第一次兑现，
而且是在第一章就兑现，不用等第二章。

**v0.1 比 v0 多的**：节点类型用字母细分了；高危 / 中危用底色标，数字不再身兼两职；
终点从 `E` 改叫 `B`，`E` 让给精英。**还没有的**：中途撤离点的符号；环的长度仍是手画的
（随机生成器负责按半径算，手绘图不需要）。

#### 5.4.2 路线、配额与覆盖

三条设计，对应作者提的三点。

**一、每环各类点按规则分布，不只靠权重。**

权重只能说「大概是这个比例」，说不了「这一环至少一个休息区、至多一个商店」。
`RingSpec.quota` 给每种类型一个 `[min, max]`，权重只负责填配额之外的空位。
再加一张全局的 `no_adjacent`（哪些类型不许挨着）。三样东西都是数据，
「同环 shop 不超过一个」这种规则写进配置，不写进生成器。

**二、休息区与商店按「步数覆盖」放，不按环放。**

早先的规则是「每 N 环至少一个」。作者指出问题所在：**玩家走的不是整个环，是一段路径和一片区域。**
一环上有休息区，但它在环的另一头，对走这一段的玩家等于没有。

改成覆盖约束：`coverage = {"rest": 4, "shop": 6}` 意思是**任何节点距最近的休息区不超过 4 步、
距最近的商店不超过 6 步**。步数是图上的最短路，不管环。这是玩家真正体验到的那个量 ——
「我还要走几步才能歇」。

修正是贪心的集合覆盖：找出所有超标节点，在候选里挑一个能覆盖最多超标节点的改成休息区，
重复到没有超标。死胡同也在覆盖范围内 —— 一条五步长的死胡同末端离休息区超过 4 步，
就得在这条胡同里放一个。高危区里不放（`no_haven_in_danger_above`）：那是岔出去的诱惑，
能在里面喘气就不是诱惑了。

**三、路线在生成之初就有，风格不同，取舍不同。**

`routes` 列出几种风格，入口按风格轮流分配。路线先铺、地图后长（步骤 4）。
风格通过 `mix` 落到该路线**独占**的节点上；几条路线合流之后的共用节点算混合。

作者给的两种基本风格，连同各自的**退路**：

| 风格 | 风险 | 收益 | 尽头 | 中途的选择 |
|---|---|---|---|---|
| 偏搜索 | 低 | 低 | 核心前的一个**撤离点**，可以不打最终敌人 | 搜到强力道具 → 换乘到战斗路线，去打 |
| 偏战斗 | 高 | 高 | 核心，打 BOSS | 战损过高（体力见底，7.1）→ 在路上的**中途撤离点**走人 |

所以路线之间不是「难度相同」，而是**风险与收益各在自己的档位上，且性价比相当**。
每种风格有 `risk_band` 与 `reward_band`；步骤 5g 把每条路线的风险分、收益分各自拉进区间，
再让各路线的「收益 / 风险」之比差不超过 `ev_tolerance` —— 低风险低收益与高风险高收益
都不白占便宜，选哪条取决于玩家想赌多大，不取决于哪条数学上更划算。

> 第一版写的是「难度相同」，因为作者早先说「保证整体难度不变」。作者随后补了取舍：
> 整体不变的是**性价比**，不是风险本身 —— 一条低风险的路线如果也低收益，
> 整体就没变松。改成两个分数、一个比值。

两个分数怎么算：`type_risk` 是「走这一步期望损失多少体力」，`type_reward` 是「期望拿到多少价值」
（6.4 的道具价值，或等值的金钱与恢复），沿路线求和，各乘 danger 的倍率。
**搜索点是玩家手里的旋钮。** 它的风险和收益都随搜索次数上升：多搜一次，多一份战利品，
遭遇敌人的概率也高一截。所以一个搜索点没有固定的风险分 —— 搜一次就走和搜到底，是两个点。
生成器给路线定档时只能取一个基准（`reference_searches`，默认搜一次），
**实际的风险收益由玩家每到一个搜索点时自己拧**。

这正是偏搜索路线「低风险低收益」的准确含义：**基准档低，上限由玩家决定。**
同一条搜索路线，谨慎的玩家每处搜一次安全走完，贪心的玩家每处搜到底、
收益逼近战斗路线而风险也一样 —— 路线给的是起点，不是结果。
生成器不该、也没法替玩家把这个变量定死。

**退路是拓扑，不是提示。** 「搜到好东西转去打」「打不动了转去撤」要真的做得到：

- 相邻路线每 `pivot_every_rings` 环至少一个**换乘点**（一条连接两条路线的边，进骨架受保护）。
  没有换乘点，风格就成了开局定终身，那不是取舍，是抽签。
- 偏搜索路线 `ends_at = "extract"`：末端是撤离点，在核心之前一环结束。想打 BOSS 就换乘。
- 偏战斗路线 `bailout_every_rings`：每隔几环在路线上覆盖一个撤离点。
  撤离点仍然覆盖非必须型节点（不吃掉休息区与商店）。

tier 不进公式 —— 各路线各环各过一次，对称。高危区不在路线上，它的风险与收益都不计入：
那是玩家自己选的加码。

**出生点。** 每个出生点对应一条路线，开局由玩家挑。挑的依据就是 `graph.routes` 里那一份：
风格、尽头（打 BOSS 还是撤离点）、风险与收益的档位 —— 以及沿途的敌人（5.10，
敌人的属性与背包在地图上看得见）。所以「偏战斗还是偏搜索」不是生成器抽签替玩家定的，
是玩家看过地图之后自己选的；选了也不锁死，换乘点还在。

**手绘地图怎么办。** 手绘图没有显式路线，解析后按「入口到核心的最短路」推几条出来，
只用于 HUD 与校验告警（覆盖不达标、路线分差太大都告警不拒绝）。作者画的图作者负责。

### 5.5 难度与奖励的径向递进

`tier = ring_count - ring`，核心 tier 最高。tier 驱动三件事：

| 受影响系统 | 规则 |
|---|---|
| 敌人强度 | `EnemyDef` 按 tier 段位筛选 + 属性按 tier 缩放 |
| 掉落质量 | `LootTable` 的稀有度曲线与掉落件数随 tier 上移 |
| 节点类型分布 | 低 tier（外环）多普通战斗与撤离点；高 tier（内环）多精英、宝藏，撤离点稀少 |

**`danger` 叠在 tier 之上**：同一环里，中危区（1）的敌人略难、奖励略高，高危区（2）更难、更高。
两者是独立的输入 —— tier 由环决定，danger 由区域决定，内容层选敌人池与掉落表时两个都看。
一个外环的高危区，可能比一个内环的常规点更难，这正是它存在的意义：
危险不只随深度递增，也会横着摆在你面前让你绕或者闯。

随机生成器只造高危区（`DangerZoneSpec`，单入口）；中危区目前只在手绘图里出现，
要不要随机生成、按什么规则，等有了第一版手感再说。

节点类型的硬约束（5.4 步骤 5 与校验）：

- 核心节点固定为 `core`（章节 Boss）
- 休息区与商店满足**步数覆盖**（`coverage`），不是「每 N 环一个」
- 每环每类落在 `quota` 的 `[min, max]` 内
- 高危区内满足 `min_elites` / `min_search`
- 各路线的风险分与收益分落在其风格区间内，收益/风险之比差不超过 `ev_tolerance`

「同一环 shop 不超过一个」「不出现连续两个 elite」这类规则**不写进生成器**：
前者是 `quota`，后者是 `no_adjacent` —— 都在配置里。后者要不要加还两说，
它与高危区的意图（精英扎堆守着一片区域）正好相反。

### 5.6 移动规则与行动计数

#### 移动规则

| 规则 | 说明 |
|---|---|
| 边双向通行 | 径向边与切向边均 `directed = false`，可自由折返 |
| 节点内容一次性消耗 | 首次进入触发事件（战斗 / 商店 / 休息 …），结束后 `state = VISITED`。**战斗输了也一样** —— 节点变空白，没有战利品，扣体力（7.1） |
| 已访问节点仅可穿行 | 可以再次经过、可以停留，但**不再产生任何事件或掉落** |
| 移动消耗行动点 | 每通过一条边消耗 `edge.action_cost`（默认 1） |
| 节点事件可额外消耗 | 由节点类型决定：搜刮 +1、休息 +2、商店 +0 等 |

`MapNavigator` 相应简化，只负责单步合法性判定与只读图查询：

```gdscript
# core/map/map_navigator.gd —— 拓扑无关
## 当前节点可移动到的目标：仅限相邻节点
func available_moves(graph: MapGraph, current_id: int) -> Array[int]:
    var out: Array[int] = []
    for e in graph.edges_of(current_id):
        if e.directed and e.from_id != current_id:
            continue                      # 保留给未来的单向地图形态
        out.append(e.to_id if e.from_id == current_id else e.from_id)
    return out

## 只读图查询：BFS 步数表。不驱动移动，仅供 HUD 显示与生成期校验使用
func distance_map(graph: MapGraph, from_id: int) -> Dictionary   # id -> 步数
```

#### 不做自动寻路

**玩家只能一步一步移动到相邻节点，不提供"点击远处节点自动走过去"。**

这是有意的设计取舍，不是实现上的简化：

- **每一步都必须是一次独立决策。** 自动寻路会把"要不要再多走这一步"打包进一次点击，而这个问题正是侵蚀机制施压的着力点。取消自动寻路，压力才落在每一步上。
- 顺带消除了一整类漏洞 —— 自动寻路必须逐步结算行动点与侵蚀判定，否则玩家能用一次长移动免费穿越危险区。不做自动寻路，这个坑根本不存在。

`distance_map` 予以保留，但**只用于只读查询**：HUD 显示"距最近撤离点还有 N 步"、生成期校验最短路径长度。任何情况下都不得用它驱动移动。

#### 行动计数

行动计数是 **run 级通用设施**，不属于地图模块 —— 未来的事件、战斗、商店都可能消耗行动点。因此放在 `core/run/` 而不是 `core/map/`。

```gdscript
# core/run/action_clock.gd
class_name ActionClock extends RefCounted
signal advanced(total: int, delta: int)

var total: int = 0

func spend(n: int) -> void:
    total += n
    advanced.emit(total, n)
```

**关键实现约束：一次移动 = 一次原子结算，且顺序不可调换。**

```
玩家点击相邻节点
  → MapNavigator 校验合法性
  → ActionClock.spend(intent.action_cost)
  → ErosionField.on_action()          ← 侵蚀可能恰在此刻推进一层
  → 结算目的地所在区域的侵蚀惩罚
  → 若目的地 UNVISITED 则触发其事件（事件自身可能再次 spend）
```

**侵蚀推进必须早于目的地惩罚结算。** 顺序反了，玩家走进一个刚好在这一步被侵蚀的节点却不受任何惩罚，预警倒计时的最后一步就失去意义。

#### 为未来的移动机制预留接口

传送、定点移动等属于**扩展机制**，第一章不实现，但底层不能把"一次移动 = 走一条边"这个假设写死。因此所有移动统一经过一个意图对象：

```gdscript
# core/run/move_intent.gd
class_name MoveIntent extends RefCounted
var kind: StringName                   # "step"（底层唯一实现）
                                       # 未来："teleport" / "waypoint" / ...
var to_id: int
var action_cost: int                   # 由解析器给出，不假定等于 1
var passes_through: Array[int] = []    # 途经节点，供沿途惩罚结算；"step" 为空
```

底层只实现 `kind == "step"`。关键在于 **`ActionClock` 与 `ErosionField` 挂在 `MoveIntent` 的结算结果上，而不是挂在"走过一条边"这个动作上**。将来加入传送或定点移动时，只需新增一种意图的解析方式，行动计数、侵蚀结算、存档与 HUD 全都不用改。

### 5.7 侵蚀系统（ErosionField）

#### 机制

在高难度下，地图从**最外环开始逐层向内被侵蚀**。被侵蚀区域仍可通行，但在其中移动会受到损失。这把"可以走回头路"从一个无代价的自由，变成一个持续加压的风险决策。

#### 拓扑无关的实现

`ErosionField` **只认 `MapNode.erosion_band`，完全不知道"环"的存在**。任何未来的地图形态只要给节点标好 band，就能直接复用整套侵蚀系统。

```gdscript
# data/chapters/erosion/*.tres
class_name ErosionSchedule extends Resource
@export var enabled: bool = false                # 低难度直接关闭
@export var first_at_action: int = 18            # 第一次侵蚀发生在第几个行动点
@export var interval_actions: int = 12           # 之后每隔多少行动推进一层
@export var warn_lead_actions: int = 4           # 预警提前量，必须 > 0
@export var damage_per_move: int = 8             # 在侵蚀区每次移动的基础损失
@export var damage_growth_per_band: float = 1.5  # 侵蚀越深，惩罚越重
@export var item_risk_after_bands: int = 2       # 深度侵蚀后开始损坏背包物品
@export var item_risk_chance: float = 0.25

# core/run/erosion_field.gd
class_name ErosionField extends RefCounted
signal warned(next_band: int, actions_left: int)
signal advanced(eroded_bands: int)

var schedule: ErosionSchedule
var eroded_bands: int = -1        # -1 = 尚未开始；0 = 最外一档已侵蚀
var next_at_action: int

func on_action(clock: ActionClock, graph: MapGraph) -> void
func is_eroded(node: MapNode) -> bool:
    return node.erosion_band <= eroded_bands
func move_penalty(node: MapNode) -> Dictionary    # {hp_damage:int, item_risk:float}
```

#### 三条硬性设计约束

1. **必须预警。** 侵蚀推进前 `warn_lead_actions` 步，UI 要给出明确倒计时并高亮即将被侵蚀的区域。没有预警的时间压力是随机惩罚，不是策略难度。
2. **侵蚀绝不封路。** 被侵蚀节点永远保持可通行，只是有代价。一旦封路就会出现玩家被困、局面无解的情况。这是不可妥协的约束 —— 任何"侵蚀区不可进入"的提案都要拒绝。
3. **惩罚随停留深度递增，而非固定值。** 用 `damage_growth_per_band` 让早已侵蚀的区域比刚侵蚀的更痛。否则玩家会发现"冲进去再冲出来"代价恒定且低廉，压迫感消失。

#### 损失的形式（待确认）

推荐分层设计：

- **浅层侵蚀**：在侵蚀区内每次移动扣**体力**（7.1）。体力是小整数，扣法待定（累计步数满 N 扣 1，或直接扣 1）
- **深层侵蚀**（该节点所在 band 被侵蚀超过 `item_risk_after_bands` 层之后）：额外以 `item_risk_chance` 概率随机损坏或摧毁背包中一件物品

第二条与背包核心机制强绑定 —— **你刚抢到的战利品正在你手里烂掉**，这是逼玩家尽早撤离的最有力压力，也让"多搜一个点"的贪心有了具体代价。

> run 级的持久资源已经定了：**体力**（7.1），跨战斗保留、休息区恢复。侵蚀的浅层惩罚扣它。
> 具体扣法（累计还是直接）是参数，`ErosionField` 的接口与调用方不受影响。

#### 终局

当最内层 band（核心所在）也被侵蚀后，全图进入侵蚀状态，此时触发**强制结算**：持续高额损失直到玩家撤离或死亡。这让侵蚀成为本局的硬时限，而不是一个可以无限拖延的软惩罚。

### 5.8 撤离点的放置

早先版本中"不可走回头路"与"搜打撤"存在冲突（不能向外走，如何撤离）。
**新的移动与侵蚀规则彻底解决了这个矛盾**，撤离点因此回到最符合玩法直觉的位置：

- **中途撤离点每 N 环一个**，覆盖掉一个非必须型节点（类型改成 `extract`）
- 核心（章节 Boss）击破后直接结算离场，视为一种特殊撤离

这形成第一章的核心张力：

```
奖励方向：外 ───────────────► 内   （越深越肥）
撤离方向：内 ◄─────────────── 外   （出口在外面）
侵蚀方向：外 ───────────────► 内   （出口正在腐烂）
折返成本：行动点                    （回头要花时间，而时间就是侵蚀）
```

玩家的每一步都在回答同一个问题：**再深入一个节点，值不值得？** 这正是"搜打撤"的题眼。

### 5.9 渲染层

```gdscript
# ui/map/map_layout_strategy.gd
class_name MapLayoutStrategy extends RefCounted
func node_position(node: MapNode, meta: Dictionary, view_size: Vector2) -> Vector2
func draw_edge(canvas: CanvasItem, edge: MapEdge, a: MapNode, b: MapNode, meta: Dictionary) -> void

# ui/map/layouts/ring_layout.gd
#   solve(graph)  → 给每个节点算出 angle；只做一次，结果缓存
#   node_position：极坐标 → 屏幕坐标，center + Vector2(cos(a), sin(a)) * radius(ring)
#   draw_edge：
#     kind == "tangential" → 沿圆弧采样 N 个点用 draw_polyline 画弧
#                            （不要画直线，直线会破坏同心环的视觉语言）
#     kind == "radial"     → 直线，沿半径方向
```

#### 环形布局：角度是解出来的，不是配出来的

数据层只有「第几环、环上第几个、和谁相连」。角度由布局策略求解，目标只有一条：

**异环通路永远垂直于切线** —— 一条径向边的两端在同一个角度上，画出来是一根笔直的、
指向圆心的线。切向弧之间隔多远则是自由的，按需要拉开或挤紧。

求解：

```
1. 径向连通分量：把所有径向边（含跨环的）做并查集，同一分量的节点必须共用一个角度
2. 从最外环开始：最外环按环内次序均匀铺满 TAU
3. 逐环向内：
   - 有径向分量已经定了角度的节点 → 直接取该角度
   - 其余节点 → 在环内次序上前后两个已定节点之间均匀插值
   - 一个节点接着多个不同角度的外环节点（岔路在这里合流）→ 取圆周均值，并告警：
     这种图没法让每条径向边都垂直，作者该知道
4. 校验：每一环按次序看角度是否单调递增（循环意义下）。不单调说明作者画的 `|`
   在次序上交叉了，告警并按插值结果画 —— 不拒绝，画出来让人看见哪里拧了
```

**为什么不让生成器写角度**：手绘图的列位置本来就不是距离（5.4.1），随机生成器也没理由
替渲染做决定。两个生成器只产出次序，同一个求解器画它们 —— 布局只写一次。
抖动（让图不那么规整）是求解器的参数，不是生成器的。

`MapView` 根据 `graph.layout_kind` 从注册表取对应策略，其余逻辑（节点按钮、路径预览、点击导航、镜头平移缩放）完全共享。

必须呈现的视觉状态：

| 状态 | 表现 |
|---|---|
| `UNVISITED` | 正常亮度，按类型显示图标 |
| `VISITED` | 图标去饱和变灰，但**保持可点击、连线保持清晰** —— 必须与"不可通行"有明显区分 |
| 当前节点 | 高亮描边 + 呼吸动画 |
| 已侵蚀区域 | 红紫色 overlay + 噪点 shader，band 边界做渐变过渡 |
| 预警中的区域 | 边界闪烁 + 倒计时标签 |
| 核心点 | 红色，始终可见，作为玩家的方向锚点 |

常驻 HUD：**当前行动数 ／ 距下次侵蚀还有 N 步 ／ 已侵蚀层数 ／ 距最近撤离点还有 N 步**。

最后一项用 `distance_map` 计算，是纯只读查询。它是玩家判断"再深入一个节点值不值"的唯一依据，**不能省** —— 没有它，折返决策会退化成盲赌。

**单步预览**：因为不做自动寻路，预览只需覆盖相邻节点。悬停相邻节点时显示这一步的**行动点消耗**、**进入后的侵蚀损失**，以及这一步是否会跨过侵蚀预警线。

### 5.10 敌人在地图上看得见

**玩家在地图上就能查看每个战斗点的敌人：属性与背包。** 规划路线靠的就是这个 ——
「这条路上第三个点是个带反伤甲的精英，我这套流血 build 打不动，绕」。
没有它，路线选择退化成看图标猜。

由此得出两条结构上的要求：

**一、节点内容在生成地图时就定好**（`MapNode.content`），不是踩上去才掷骰。
战斗点、精英点、BOSS 的敌人是谁，地图一生成就确定；存档里跟着图走。
`random`（`?`）是唯一的例外 —— 踩上去才知道是什么，这正是它叫「随机」的意思，
也是地图上唯一看不透的点。搜索点里搜着搜着遭遇的敌人同样看不见，那是搜索的风险所在。

**二、敌人就是一个背包。** 敌人的定义 = 一块摆好道具的棋盘 + 一份基线属性，
和玩家走**同一个** `BattleCompiler`。于是：

- 预览的属性（生命、预估 DPS、参战件数）与真打出来的一致 —— 编译是纯函数（4.2），
  战斗沙盒里玩家自己那一栏读数就是这么来的，给敌人用不用多写一行
- 预览的背包就是敌人真正的背包，玩家看得见每件道具、每个邻接标记，
  能像读自己的 build 一样读敌人的 build
- 敌人的道具就是掉落的来源：打赢了搜的就是这个背包（6.1 的尸体容器）。
  地图上看到敌人背着一件传说品，就知道这一仗值不值得打

现在 `battle_sandbox.gd` 里的训练假人是手搓的 `CombatantSpec`，那是 M2 的权宜；
真正的敌人内容（`EnemyDef`：棋盘布局 + 基线）属于 M4，走内容管线。

**能看多远**：底层规则是全图可见。战争迷雾、侦察范围之类属于扩展机制，不实现，
接缝留在 `MapView` 的「这个节点的内容给不给看」一处判断上。

---

## 6. M4 · 搜刮与掉落

### 6.1 掉落生成

```gdscript
# data/loot/*.tres
class_name LootTable extends Resource
@export var entries: Array[LootEntry]     # {item_def, weight, min_tier, rarity}
@export var roll_count: Vector2i          # 掉落件数范围
```

流程：`敌人 tier + 节点 tier → 加权抽 N 件 → 装入尸体容器`。

**尸体容器就是一个 `GridInventory`**，尺寸由敌人档位决定（小兵 4×4、精英 6×6、Boss 8×8）。
装填使用 `find_first_fit` + 随机旋转；装不下的物品丢弃或容器扩容。

这里完全复用 M1 的代码，零额外成本 —— 这正是 3.2 节强调容器复用的原因。

### 6.2 渐进揭示的搜索 UI

三角洲行动式搜刮的手感核心是**"看得见轮廓、看不清是什么"**：

- 每件物品有 `revealed: bool`
- 未揭示：显示灰色剪影 + 噪点 shader
- 进入搜索界面后启动揭示时间线，按栏位顺序或按距光标距离依次揭示
- 单件间隔 0.15~0.4 秒，受角色"搜索速度"属性影响
- 提供"快速搜索 / 全部拾取"按钮

实现建议：**用一个 `Tween` 驱动 `reveal_progress` 浮点值，配合 `ShaderMaterial` 的 dissolve 参数**，比为每件物品挂一个 `Timer` 干净得多。跳过按钮直接 `tween.custom_step(BIG)` 推到终点。

### 6.3 真正的张力来源

紧张感不来自揭示动画本身，而来自**约束**：

- 搜索有时间压力（倒计时 / 会刷新的增援）
- 背包装不下所有东西，且异形格子让"能不能装下"本身成为谜题

玩家被迫做"丢掉这个占 6 格的大件，换那个占 2 格的稀有品"的决策。
**这个取舍就是异形格子系统存在的意义，必须设计进搜刮环节**，否则背包系统退化为纯装饰。

### 6.4 道具的价值

道具有两种用处：**提供战斗力**，以及**本身值钱**。两者独立 —— 一件东西可以只占其一。

`ItemDef.value` 为 0 时按 `ItemValue.of()` 算：**稀有度 × 尺寸**，越稀有每格越贵，越大总价越高。
填正数则覆盖，留给「小而贵」（一枚戒指）与「大而贱」（一卷破布）的特例。
`ItemValue.BASE_PER_CELL` 是占位表，经济系统定数时改它，形状（越稀有越贵）不变。

价值用在三处：

- **撤离结算**：背出去的东西按价值计分，进 meta 成长（15 节第 4 项）
- **买卖**：商店的买价卖价以它为基
- **侵蚀损坏**（5.7 深层惩罚）：损失的是价值，所以「背着一件占 6 格的传说品在侵蚀区里绕路」才真的疼

它也是 5.4.2 里 `type_reward` 的单位：一步的收益分 = 期望拿到的价值。
偏搜索路线「低收益」的意思，是期望价值低、方差大 —— 搜到一件传说品能把整局翻过来，
所以才有「搜到强力道具一转战斗」这条退路。

**战斗力与价值的张力**：一件大而贵的东西占着棋盘却不出力，背它出去还是换成两把刀，
就是搜刮路线上每一次整理背包时要答的题。

---

## 7. M5 · 运行状态与存档

```gdscript
# autoload/run_state.gd
var run_seed: int
var rng: RunRNG                  # 分流随机源
var chapter: ChapterDef
var map: MapGraph
var current_node_id: int
var action_clock: ActionClock    # 行动计数（run 级）
var erosion: ErosionField        # 侵蚀状态，低难度下 schedule.enabled = false
var vitality: int                # 体力（7.1）：战斗失败扣它，归零才战败
var max_vitality: int
var board: GridInventory         # 作战棋盘，requires_bag = true，只有这里的物品参战
var storage: GridInventory       # 暂存区，requires_bag = false，保留但不参战
var gold: int
var meta_stash: GridInventory    # 跨 run 持久仓库
```

### 7.1 体力与战败

**战斗输了不等于一局结束。** 输一场扣**体力**：普通战斗 −1，精英 −2。体力归零才战败。

体力是 run 级的小整数，与战斗内的生命、耐力（4.3）**不是一回事**：战斗内的资源每场重置，
体力跨战斗保留。它是「这一局还剩几条命」，也是 5.4.2 里「战损过高选择提前撤离」的那个「战损」——
偏战斗路线上的玩家看着体力从 5 掉到 2，就该考虑下一个撤离点了。

| 事 | 体力 |
|---|---|
| 普通战斗失败 | −1 |
| 精英战斗失败 | −2 |
| 章节 BOSS 失败 | **直接战败**，不论还剩多少体力 |
| 休息区 | +1（待定） |
| 侵蚀浅层惩罚 | 扣，扣法待定（5.7） |
| 归零 | 战败，`DeathResult` |

**输了节点也变空白。** 战斗不论输赢，节点都消耗掉（`VISITED`）：赢了有战利品，
输了什么都没有还扣体力。没有「再打一次」—— 所以每一场打不打是一次性的决定，
而 5.10 让玩家在做这个决定之前看得见对手。

> 我原先暂定的是「节点保留、可以重打」，作者纠正。重打会让体力变成可以反复兑换尝试次数的货币，
> 「用体力磨过去」成为最优解；一次性消耗则让地图上的每个敌人都是一道只答一次的题。

**BOSS 是例外：输了直接战败。** 别的战斗输了节点变空白、人还能走；核心变空白了这一局就没有终点，
所以打 BOSS 是一次押上整局的决定 —— 这也让偏搜索路线「尽头是撤离点、可以不打 BOSS」
成了一条真正的退路，而不只是少打一场。

`type_risk`（5.4）就是按这张表定的：一步的风险分 = 输的概率 × 扣的体力。

存档 = `RunState.to_dict()` → JSON 写入 `user://`。
所有逻辑类实现 `to_dict()` / `static from_dict()`。因为逻辑层不继承 `Node`，这件事会非常顺畅。

**存档从第一天就必须写版本号**（`{"version": 1, ...}`），后续加字段才有迁移余地。

---

## 8. M6 · 场景流

```
MainMenu → RunSetup(选初始背包) → MapView
                                    ⇅
              ┌─────────────────────┴──────────────────┐
         BattleView → SearchView → (回 MapView)    Shop / Event / Rest
                                    ⇅
              ExtractResult / DeathResult → MetaProgress → MainMenu
```

`GameDirector` 用显式状态机管理。

**场景切换用 `add_child` / `queue_free` 手动管理，不要用 `change_scene_to_file`** ——
需要在 BattleView 之上叠加 SearchView，同时保留 MapView 的状态与镜头位置。

---

## 9. 套装与跨域效果

**套装是由道具触发的独立系统，不是编译期的一步。**

道具身上显示的套装信息**纯粹是 UI 提示**（按激活状态做暗／亮切换），不参与任何结算。
真正的效果写在套装定义上，由背包层持续维护激活状态。

### 9.1 激活发生在背包层，不是战斗层

物品一拖进棋盘，[SetTracker] 立刻重新计数；达到档位即激活，并发出
`activation_changed` 供 UI 实时刷新。**不必等到进入战斗**。

这不只是为了 UI 及时。更要紧的是：套装效果的作用域**超出战斗** ——
「提升战胜后的战利品掉落」根本不在编译期能处理的范围内。

```
拖入／取出棋盘
      │ GridInventory.changed
      ▼
SetTracker.recount()  →  activation_changed  →  UI 暗／亮切换
      │
      │ effects_in_scope(scope)
      ├──► BattleCompiler   取 combat：属性加成与规则
      └──► 掉落系统（M4）    取 loot：额外掉落、稀有度偏移
```

**只数棋盘上的。** 暂存区的物品不参战，也不该凑套装，与 3.4 的参战规则一致。
**包不算部件** —— 它是承载物，即便标了 `set_id` 也不计入。

### 9.2 一棵效果树，道具与套装共用

早先套装效果（`SetEffect`）与战斗效果（`Effect`）是两棵独立的树，结果是同一个概念存在两遍，
而且战利品效果被锁死在套装上 —— 「这把刀让敌人多掉一件东西」这种完全合理的单件道具
反而写不出来。现在统一成一棵，**按作用域分支**：

```gdscript
@abstract
class_name Effect extends Resource
@abstract func scope() -> StringName        ## EffectScope.COMBAT / LOOT / MAP
func describe() -> String                   ## 给 UI 与编辑器的一行说明
```

```
Effect
  CombatEffect   战斗内，【依赖扳机】       DealDamage / ApplyStatus / RemoveStatus / ChangeResource
  LootEffect     战利品，激活即生效         RarityBias / CategoryBias / ExtraRolls / DropOwnedChance
  MapEffect      地图，占位（M3 再填）
```

基类**只声明作用域，不声明执行方法**。各分支的调用签名本就不同
（战斗要 `RuleContext`，掉落要 `LootContext`），强行统一只会得到一个没人能用的签名。

| 分支 | 何时生效 | 由谁调用 |
|---|---|---|
| `CombatEffect` | 扳机命中且消耗付清后 | `RuleEngine` |
| `LootEffect` | 进入战利品计算阶段，**只要处于激活状态** | M4 掉落系统 |
| `MapEffect` | 待定 | M3 地图系统 |

**只有战斗这一支依赖扳机。** 掉落效果不需要时机 —— 它没有「什么时候发生」可言，
掉落计算阶段本身就是它的时机。硬给它配一个 `Trigger` 只会多出一个永远填 `Always` 的字段。

#### 道具与套装是两个入口，不是两套词汇

```gdscript
class_name ItemDef extends Resource
@export var effects: Array[Effect]     ## 道具自带的跨域效果
@export var combat: CombatProfile      ## 战斗规则（含扳机）走这里
```

道具自带的跨域效果**不需要凑套装，在棋盘上就算激活**；套装的那份要满足件数门槛。
两者最终汇入同一个查询：

```gdscript
tracker.effects_in_scope(EffectScope.LOOT)   # 道具的 + 已激活套装的
```

各系统只查自己那一档，彼此不需要认识对方。**新增一个作用域 = 加一个 `Effect` 子树 +
对应系统去查询**，不改基类，也不动其他系统。

#### 伤害类型不绑定乘区

`DealDamage.damage_type`（`physical` / `fire` / …）与 `StatMath.Buff` 乘区分类
（`EMPOWER` / `SHARP` / `FIRE` / …）是**两个正交的维度**，刻意不做映射。

绑在一起看似省事，但立刻会写不出「强化影响全部伤害」这种最常见的加成 ——
那是一个乘区作用于所有类型。反过来，「火焰抗性」是按类型减伤，与乘区无关。
让内容作者各填各的，比替他们建立一个总要开后门的对应表更诚实。

`damage_type` 的唯一用处是给伤害事件打标签，供 `OnDamage` 和未来的抗性系统筛选。

### 9.3 数据形态

```gdscript
class_name ItemSetDef extends Resource
@export var id: StringName
@export var display_name: String
@export var count_mode: CountMode          ## INSTANCES / DISTINCT_DEFS
@export var tiers: Array[SetTier]          ## 按 pieces 升序

class_name SetTier extends Resource
@export var pieces: int                    ## 达到几件时生效
@export var mods: Array[StatModifier]      ## 编译期属性修饰，按物品施加
@export var rules: Array[AbilityRule]      ## 战斗规则（需要扳机）
@export var effects: Array[Effect]         ## 非战斗作用域，激活即生效
```

**三个列表分开，而不是并成一个 `Array[Effect]`**，是因为它们的生命周期确实不同：
`mods` 在编译期一次性并入、`rules` 由扳机驱动、`effects` 在别的系统的别的阶段被查询。
并成一个列表后消费方还是得按类型分拣，只是把分拣从编辑期挪到了运行时。

`ItemDef.set_id` 只是归属标记 —— 道具上记载的套装信息是**纯 UI 提示**
（可暗／亮切换显示是否激活），真正的激活由 9.1 的计数决定。

| `count_mode` | 语义 |
|---|---|
| `INSTANCES` | 每件实例算一件（带两把同样的剑 = 2 件） |
| `DISTINCT_DEFS` | 同一定义只算一次（逼玩家集齐不同部件） |

档位**累加**而非互斥：4 件套同时享有 2 件档与 4 件档。想要互斥就把高档数值写成增量，
不为此增加机制。

### 9.4 战斗作用域的并入

编译器**不认识 `SetTracker`，也不自己数件数** —— 计数与激活是背包层的事，
物品一拖进棋盘就已经算好了（UI 要实时显示暗／亮）。它只接收两份筛好的列表：

```gdscript
BattleCompiler.compile(board, base_hp, tracker.combat_mods(), tracker.combat_rules())
```

- `mods` 按物品施加，作用于棋盘上的**全部**参战物品
- `rules` 挂到 `CombatantSpec.set_rules`，**不属于任何物品**，来源 uid 为 0，
  取属性时退回单位级

**战斗效果不从 `effects_in_scope()` 出。** 它需要扳机，因此只能以 `AbilityRule` 的形式
存在；那个查询返回的是「激活即生效」的那一类。

**想改单位级属性（生命上限之类）不要写在 `mods` 里** —— mods 是按物品施加的，
逐件放大再求和不等于整体放大。改用一条
`OnBattleStart + Always + ApplyStatus(某 buff)` 的规则，让 buff 去改单位属性。

### 9.5 单位级属性的聚合规则

单位级属性表由各物品属性求和而来，但**乘法单位元类属性不能跨物品累加**：
haste 每件都是 1.0，逐件相加会得出「N 件物品 = N 倍速度」。

判据是 `BattleStats.default_base(key) != 0` —— 有非零单位元的属性跳过累加。
同理，这类属性在缺席时返回自己的单位元而不是调用方传的 fallback，
否则漏传一处就会把速度当成 0，冷却随之被放大上万倍。

---

## 10. 内容制作管线

道具是本作内容量最大的部分，必须能**不写代码**地增删改。本节定义从制作到入库的整条路径。

### 10.1 两层：作者数据与引擎资产

```
data/authoring/items/*.json     道具源数据
data/authoring/buffs/*.json     增益源数据
data/authoring/sets/*.json      套装源数据
        │  tools/import_items.gd / import_buffs.gd   校验 + 生成
        ▼
data/items/*.tres   data/shapes/*.tres
data/buffs/*.tres   data/sets/*.tres
```

**源数据用 JSON 而不是直接编辑 `.tres`**：`.tres` 的数组与子资源字面量手写极易出错，
且改动的 diff 不可读；JSON 可以人写、可以脚本批量生成、评审时看得懂。

`.tres` 是生成物，但**仍然入库** —— 否则每次 clone 都要先跑一遍导入才能打开工程。
导入器需具备幂等性：源数据未改时重复运行不产生 diff。

### 10.2 导入器不认识任何具体效果

这是整条管线的关键约束。导入器只做三件事：读 JSON、按**注册表**解析类型名、写 `.tres`。

```gdscript
# core/battle/effect_registry.gd
## 类型名 → 脚本路径。新增一种效果＝加一个脚本 + 在这里登记一行，
## 导入器、BattleSim、编辑器三方都不需要改。
const EFFECTS := {
    &"deal_damage": "res://core/battle/effects/deal_damage.gd",
    &"heal":        "res://core/battle/effects/heal.gd",
    ...
}
const TRIGGERS := { ... }
const CADENCES := { ... }
```

JSON 里写类型名与参数，导入器按注册表构造对应 Resource 并逐字段赋值：

```json
{
  "id": "rifle",
  "display_name": "步枪",
  "shape": ["1", "1", "1"],
  "rarity": 2,
  "tags": ["weapon"],
  "set_id": "scavenger",
  "combat": {
    "rules": [
      {
        "trigger": {"type": "on_schedule"},
        "cadence": {"type": "cooldown", "seconds": 2.0},
        "effects": [{"type": "deal_damage", "amount": 10.0}]
      },
      {
        "trigger": {"type": "on_damage", "direction": "TAKEN"},
        "cadence": {"type": "always"},
        "costs": [{"type": "charge", "n": 3}],
        "effects": [{"type": "deal_damage", "amount": 4.0}]
      }
    ]
  },
  "adjacency": {
    "grant": {
      "cells": [[1, 0]],
      "filter": ["weapon"],
      "mods": [{"stat": "damage", "category": "SHARP", "percent": 25}]
    }
  }
}
```

形状是一张**布尔矩阵**：每行一个由 `0`（空）与 `1`（占格）组成的数字串，
在文本编辑器里直接看得见形状。单行字符串也可以，用 `\n` 分行：

```json
"shape": ["11", "10"]          // L 形三格
"shape": "11\n10"              // 同上，等价写法
"shape": ["010", "111", "010"] // 十字五格
```

代码侧对应 `ItemShape.from_bits()` 与 `to_bits()`，两边同一种记法，
导入器不需要做任何转换。旧的 `#` 写法 `from_ascii()` 仍然接受，但新内容一律用 0/1。

### 10.3 校验必须比引擎严格

导入器是内容质量的唯一关口，宁可啰嗦：

- id 唯一、与文件名一致、非空
- 形状非空、无重复格
- 引用的 `set_id`、乘区名、属性键、类型名都存在
- 邻接标记格不与自身轮廓重叠（重叠说明作者搞错了坐标系）
- `AbilityRule` 三项齐全；`CooldownCadence` 的秒数为正
- 数值落在合理区间（区间写在配置里，越界只警告不阻断）

**校验失败一律拒绝生成**，不产出半成品资产。导入器以退出码区分成功／失败，
可直接接进 `tools/test.sh` 之后的流水线。

### 10.4 反射是这条管线的地基

导入器、导出器、编辑器**三方都不认识任何一种具体效果**。它们只会两件事：

1. 问 Godot「这个类有哪些导出属性、各是什么类型」（`get_property_list()`，
   类型化数组还能用 `get_typed_script()` 问出元素类）；
2. 碰到抽象基类（`Trigger` / `Cadence` / `Cost` / `Effect`）时，
   按 JSON 里的 `type` 去 `EffectRegistry` 查。

于是**新增一种效果 = 加一个脚本 + 注册表登记一行**，整条工具链自动认得：
命令行导入器接受它、导出器倒得出来、编辑器的下拉框自动多一项。
`ContentSchema` 是这层反射的唯一出口。

只有三处例外，都是「JSON 写法与资源结构本来就不同构」，各自在代码里注明了理由：

| 例外 | 为什么 |
|---|---|
| 形状写成 0/1 数字串 | 硬要作者写 `{"cells": [[0,0],[1,0]]}` 是把人当解析器用 |
| 增益可按 id 引用 | 也允许内联 —— 只被一件道具用到的 buff 没必要单开文件 |
| 裸 int 枚举登记表 | 乘区要能用 -1 表示「不加乘区」，声明成枚举类型反而别扭 |

#### 两个坑，都写进注释了

**Godot 给的枚举名不是源码里的名字。** `@export var target: Target` 的
`hint_string` 是 `Opponent:0,Self:1,Both:2` —— 引擎为了检视器好看，
把 `OPPONENT` 美化成了 `Opponent`。作者数据该用源码里的写法，
所以两边都归一化成 SCREAMING_SNAKE 再比。

**导出形状要返回普通 `Array` 而不是 `split()` 给的 `PackedStringArray`。**
后者过一趟 JSON 会变成 `Array`，在内存里直接回灌导入器时却不是 ——
于是「导出→导入」在内存里失败、经过 JSON 反而成功，最难查的那种不一致。

#### 往返测试

`导出 → 导入 → 再导出` 必须逐字节相同。这条测试比任何断言都能守住
「不认识具体效果」这个性质：**新增一种效果如果没走通用路径（比如有人在导入器里
写了个 if），往返立刻就崩。** 测试同时拿 `data/items` 下的真实资产过一遍 ——
手写的测试数据总是碰巧合规，真资产才会暴露漏掉的字段。

### 10.5 可视化编辑器

`ui/editor/content_editor.tscn`，给开发者与 MOD 作者。
左边选道具，中间改属性，右边画形状、看校验、看 JSON。

**它不是另一条通路，只是同一条通路的另一个入口**：存盘存的是
`data/authoring/items/<id>.json`，和命令行导入器吃的是同一种文件。
手写与 GUI 两条路产出的数据完全等价，不存在「GUI 能表达而 JSON 不能」的分裂。

**保存同时产出 JSON 与 `.tres`**，不需要再手动跑一次导入器。产出资产走的就是
导入器那条路（先导出成 JSON、再导入回来），所以界面存出来的和命令行存出来的
逐字节相同 —— 「省一步」不能以「两条路产出不同资产」为代价。
命令行导入器仍然需要：手改 JSON、批量重建、CI 都走它。

目录常量集中在 `ContentPaths`，只有一处定义。三方各写一份的话，
某天改了目录就会出现「编辑器存到 A、导入器读 B」这种谁都不报错、
但内容就是不生效的情况。

三件事让它对 MOD 作者成立：

- **表单由反射生成**（`PropertyForm`），效果类型下拉框来自注册表。
  新增一种效果，下拉框自动多一项，编辑器一行不用改。
- **实时校验走的就是导入器本身**，不是另写一份规则 ——
  那样界面和命令行迟早给出不同答案，而作者会相信先看到的那个。
- **JSON 预览始终可见，且能直接改了套用**。界面覆盖不到的角落不该把人挡在外面。

**切走不丢改动**：改到一半想去看另一件道具长什么样，回来改动还在。
草稿只在内存里（关掉就没了），列表上用一个点标出哪些还没存。
「改回原样」会自动撤掉标记 —— 否则看一眼就被标成改过，标记也就没意义了。

形状用能点的网格编辑：形状本来就是一张布尔矩阵，让作者去数坐标是在为难人。
**邻接标记格画在同一张网格上**，切换「占格／增益格／受益格」三层 ——
「加成的是上下相邻那一格」是一条相对偏移，脱离形状就看不出来。
标记格在轮廓之外、偏移可以是负数，所以网格四周留了边距，边距按已有标记自动撑开
（装不下就等于看不见，而看不见比画错更糟：作者会以为没配）。

顺带还有编译期的**预估 DPS**，因为编译是纯函数（4.2），这条读数和真打出来的一致。


**左侧按标签分类**，页签竖排。页签集合从 `data/authoring/items/*.json` 的 `tags`
里长出来，不是写死的枚举 —— MOD 作者加一个标签，这里自己就多一页。

列表的行号对应的是**筛过之后**的那一份（`_shown`），不是全集（`_ids`）。
两者混用的表现是「点第三行打开了第五件」，而且只有加了筛选之后才错。

### 10.6 启动选择器

`ui/launcher.tscn` 是项目主场景，列出三个开发期入口：背包沙盒、战斗沙盒、道具编辑器。
在此之前主场景写死成其中一个，另外两个只能在 Godot 里手动挑（F6）。

它只负责切场景，不碰任何游戏状态。真正的场景流（进关、战斗、结算）是 M6 的事，
到时候它会退化成一个调试入口，或者直接删掉。

**回来的路由 `DevNav` autoload 提供**：任意场景右上角一个按钮，快捷键 F1。
做成 autoload 而不是让每个场景自己加按钮 —— 后者漏装的表现是
「F6 直接跑进去就出不来，只能关掉重开」，而那时没有人替它装。

不用 Esc 当返回键：拖拽中的取消是 Esc，编辑器的输入框也可能吃掉它，
而「手一滑回到主界面」在编辑器里意味着草稿全没。

场景可以实现 `has_unsaved_changes() -> bool` 来要一次确认。用鸭子类型而不是
让场景继承什么东西：这一层是开发期脚手架，不该为了一个提示在正经场景的类型里留下痕迹。

### 10.7 与测试的关系

`tests/test_item_assets.gd` 已有的「校验磁盘上的真实资产」思路继续保留并扩充：
导入器保证生成时正确，资产测试保证**入库后**仍然正确（防止有人手改 `.tres`）。

---

## 11. 目录结构

```
res://
  core/                          # 纯逻辑，零 Node 依赖，可单测
    authoring/                     # 内容管线（第 10 节），JSON ⇄ 资源
      content_schema.gd            # 反射工具：属性表、枚举、造对象
      content_importer.gd  content_exporter.gd
      import_report.gd             # 带定位路径的诊断
    inventory/
      item_container.gd          # 容器基类：变更通知 + 按 uid 取放
      grid_inventory.gd          # 空间容器
      item_stash.gd              # 列表容器（暂存区）
      item_shape.gd  item_def.gd  item_instance.gd
      inventory_service.gd
    battle/
      battle_sim.gd  compiler.gd  battle_context.gd
      combatant_spec.gd  battle_event.gd  ability.gd
      stat_math.gd  stat_value.gd  stat_set.gd  stat_modifier.gd
      adjacency_profile.gd  combat_profile.gd  ability_rule.gd
      effect_registry.gd           # 类型名 → 脚本路径，新增效果只登记一行
      combat_effect.gd             # Effect 的战斗分支，依赖扳机
      combatant_baseline.gd        # 角色自带的基线属性，角色系统的占位
      damage/                      # 伤害结算管线（4.6）
        damage_type_def.gd  damage_types.gd
        damage_packet.gd  damage_resolver.gd
      triggers/                    # Trigger 子类，每种时机一个文件
      cadences/                    # Cadence 子类，每种频率一个文件
      costs/                       # Cost 子类：资源、层数、充能、次数、概率
      effects/                     # CombatEffect 子类，每种效果一个文件
    map/
      map_graph.gd  map_node.gd  map_edge.gd
      map_generator.gd           # 抽象基类
      map_generator_registry.gd
      map_navigator.gd
      generators/
        ring_map_generator.gd    # 第一章
        ring_map_config.gd
        (未来：layered_map_generator.gd 等)
    effects/                       # 效果树的根（第 9.2 节），三个作用域的公共祖先
      effect.gd  effect_scope.gd
    loot/
      loot_roller.gd  loot_table.gd
      loot_effect.gd  loot_context.gd
      effects/                     # LootEffect 子类
    sets/                          # 套装系统（第 9 节），跨战斗与掉落
      item_set_def.gd  set_tier.gd  set_database.gd
      set_tracker.gd             # 背包层的计数与激活
    run/
      action_clock.gd            # 行动计数
      move_intent.gd             # 移动意图，扩展机制的接入点
      erosion_field.gd           # 侵蚀推进与惩罚结算
      erosion_schedule.gd
    rng.gd
  data/
    authoring/                     # 人写的源数据，导入器的输入（第 10 节）
      items/*.json   buffs/*.json   sets/*.json
    items/*.tres   buffs/*.tres   sets/*.tres    # 导入器产出，形状内嵌
    loot_tables/*.tres  enemies/*.tres
    chapters/chapter_01.tres
  ui/
    ui_palette.gd                  # 配色与 CJK 字体，各界面共用
    inventory/   map/   battle/   search/
    editor/                        # 道具编辑器（10.5），给开发者与 MOD 作者
      content_editor.gd  property_form.gd  shape_editor.gd
    map/layouts/ring_layout.gd   # 布局策略实现
  autoload/
    game_director.gd  run_state.gd  event_bus.gd
  tests/
```

---

## 12. 实施顺序

| 阶段 | 内容 | 产出 | 状态 |
|---|---|---|---|
| **1** | M1 网格背包 + 拖拽 + 序列化 | 可玩的整理沙盒，核心手感可验证 | 完成 |
| **2** | M2 编译 + 效果系统 + 模拟 + 极简可视化 | 两个背包能打起来，可批量跑平衡 | 完成 |
| **3** | 内容制作管线（第 10 节） | 不写代码就能造道具，数值可迭代 | 完成 |
| **4** | M3 环形地图生成 + 单步导航 + 渲染 + 行动计数 | run 的骨架成立 | 进行中：M3-1 数据层完成（报告 030），计划见 027 |
| **5** | M4 掉落 + 搜刮揭示 + 撤离 | **循环闭合，第一个可玩 Demo** | |
| **6** | M5 存档 + M6 场景流打磨 | 可对外试玩 | |
| **7** | 侵蚀系统 + 难度档位开关 | 时间压力成立，可开始调节奏 | |
| **8** | 内容扩充（物品 / 敌人 / 事件 / 新章节地图形态 / 扩展移动机制） | 此后 90% 的时间 | |

**内容制作管线紧跟在 M2 之后**：战斗系统一旦能跑，瓶颈立刻从「有没有机制」变成
「有没有内容可调」。此时手写 `.tres` 会成为迭代速度的天花板，而管线本身依赖 M2
定下的效果系统结构（第 4.4 节），早做也没有稳定的目标可对。

**侵蚀系统排到循环闭合之后**：地图 + 行动计数本身就能跑通一整局，侵蚀是叠加在上面的
压力层。先让无压力版本可玩、可调，再加时间压力，才分得清节奏问题来自地图结构还是
侵蚀参数。

**先把 M1 做到能跑，再动其他模块。**
常见失败模式是先做地图（因为最容易看到画面），结果背包系统定型后地图与战斗全部要改。

---

## 13. 已知风险

1. **异形物品的拖拽手感调优被严重低估** —— 抓取偏移、旋转轴心、吸附容差需要反复迭代，预留充足时间。
2. **邻接加成的结算顺序**必须在实现前定死分层规则，后期修改将导致全部物品数值重平衡。
3. **地图形态硬编码风险** —— 任何时候在 `MapGraph` / `MapNavigator` / `MapView` 主体里看到 `ring` / `angle` 字样，就是在给第二章挖坑，立即重构进 `layout` 字典或布局策略。
4. **侵蚀节奏的数值调校是第一章最难平衡的部分。** `first_at_action` / `interval_actions` 与地图规模强耦合，改环数或节点密度就必须重调。建议写一个“给定策略下的行动点消耗”模拟脚本（用贪心 AI 走图），批量跑出行动点分布再反推侵蚀时间表，不要靠手感拍数字。
5. **扩展机制的预留缝容易被无意堵死。** 凡是在 `ActionClock` / `ErosionField` / 存档 / HUD 里直接写死 `+1`、或绕开 `MoveIntent` 直接读 `edge` 的地方，都是在给传送与定点移动挖坑。见第 14 节。
6. `godot_ai` 插件注册了 autoload `_mcp_game_helper`，**正式导出前必须摘除**，避免打进发布包。
7. 使用 Godot 4.7（较新版本），自定义 Resource 的 `@export var x: Array[Vector2i]` 在编辑器内联编辑时偶有异常。`.tres` 出现数据丢失时优先排查泛型数组导出问题。

---

## 14. 扩展机制的预留接口

已知会在后续加入、但**当前不实现**的机制。本节只记录它们将挂在哪条接缝上，用途是防止底层把路堵死。

原则：**留缝，不留实现。**

| 扩展机制 | 接入点 | 底层必须避免的假设 |
|---|---|---|
| 传送 / 定点移动 | `MoveIntent.kind` 新增类型 | 不假定"一次移动 = 走一条边"，不假定行动消耗恒为 1 |
| 新的地图形态 | `MapGenerator` + `MapLayoutStrategy` 子类 | `MapGraph` / `MapNavigator` / `MapView` 主体不出现 `ring` / `angle` |
| 侵蚀方向变体（如由内向外） | 生成器对 `erosion_band` 的标注方式 | 不把 `erosion_band` 与 `tier` 合并成一个字段 |
| 非矩形 / 可扩容背包 | `GridInventory._blocked` 与 `size` | 不假定容器是满矩形、尺寸不变 |
| 物品损坏与随机词条 | `ItemInstance.state` 字典 | 不把运行时可变状态写进 `ItemDef` |
| 宝石镶嵌 | `ItemDef.gem_slots` + `ItemInstance.state.gems`，编译期在包体效果之后插一步 | 宝石不占网格，效果随宿主类型（武器／护甲／散放）而变；`socket` 一词留给它，不要用在邻接标记上 |
| 效果的新作用域（地图、商店、撤离…） | `Effect` 子树 + 该系统调 `tracker.effects_in_scope()` | 一棵树按作用域分支；各系统只查自己那一档，互不认识。道具与套装共用同一套词汇 |
| 新的消耗种类（层数、充能、耐久…） | `Cost` 子类 + 注册表登记 | `costs` 是列表且 AND 语义；消耗与冷却**故意不原子**，失败跳过效果但冷却照走 |
| 新的资源种类（法力、护盾值…） | `ResourcePool` 的新键 + `max_*` 属性键 | 不为每种资源单开事件，统一走 `resource_changed(key, delta, reason)` |
| 新的触发时机／频率／效果 | `Trigger`／`Cadence`／`Effect` 子类 + `effect_registry` 登记一行 | 不在 `BattleSim` 或导入器里出现任何具体效果名；连带触发是 `OnItemFired` 子类，不是特例字段 |
| 合成配方 | 新增 `RecipeBook` + 回合边界的结算钩子 | 匹配的是**相对偏移模式**而非「挨着」；`state` 预留 `locked` 标志 |
| 有内容物的包可旋转 | `GridInventory.rotate_item` 的包分支 | 现在直接拒绝；放开时内容物需同步做坐标变换 |

**这张表的用法是防御性的**：实现底层时对照检查有没有踩到右列，而不是现在就去实现左列。

---

## 15. 待确认事项

| # | 事项 | 当前假设 | 若改变的影响面 |
|---|---|---|---|
| 1 | ~~run 内是否存在持久生命值~~ 已定：**体力**（7.1），战斗失败扣 1 / 2，归零战败 | 初始值、休息回复量 —— 两个数待定。输了节点也变空白、BOSS 失败直接战败，已定 | 纯数值与一条规则，不影响接口 |
| 2 | 侵蚀损失的具体形式 | 浅层扣生命值，深层额外损坏背包物品 | 同上，只改效果实现与参数 |
| 3 | 节点事件的额外行动消耗 | 搜刮 +1 ／ 休息 +2 ／ 商店 +0 | 仅影响节奏调参 |
| 4 | 撤离后的保留规则 | 背包内容全额进入仓库，死亡全失 | 影响 meta 成长曲线，不影响任何模块接口 |
| 5 | 棋盘尺寸与开局可用格数 | 暂定 7x9，开局由一个小包提供约 12 格 | 纯数值，不影响结构 |
| 6 | 合成配方是否纳入第一章 | 暂缓，先跑通包体系统与战斗 | 独立子系统，可后加 |
| 7 | 暂存区的清空时机（见 3.4） | 进入下一关即消失，连同里面的道具 | 另一案是留到一局结算时才清空。只改 UI 提示与清空时点；各系统「只看棋盘」的约定两案通用 |
| 8 | 各角色的基线数值（见 4.2） | 全局一份：生命 25、耐力 50 | 角色系统落地后由角色定义提供 `CombatantBaseline`，编译器与战斗不改 |
| 9 | 元素类型各自的性质 | 目前只有 `fire` 占位，性质同物理 | 加一份 `DamageTypeDef` 即可，结算管线不改 |
| 10 | ~~耐力等资源是否回复~~ | **已定：按时间自动回复，懒结算**（见 4.5） | 速率是 `regen_xxx` 属性，因此自动吃 buff。当前数值是占位：基线 4/秒，口粮 +2/秒 |

这几项都被刻意隔离在参数层或单个类的内部，**推迟决定不会阻塞任何模块的开工**。

---

## 16. 变更记录

| 版本 | 日期 | 内容 |
|---|---|---|
| v0.1 | 2026-09-20 | 初版：六大模块设计；地图系统确定为可插拔生成器架构，第一章采用同心环形地图 |
| v0.2 | 2026-09-20 | 地图移动规则改为可自由折返（已访问节点仅可穿行、不再触发事件）；新增行动计数 `ActionClock` 与由外向内的侵蚀系统 `ErosionField`；撤离点回归外环与中环 |
| v0.3 | 2026-09-20 | 取消自动寻路，移动一律单步；新增 `MoveIntent` 作为未来传送／定点移动的接入点；新增第 12 节「扩展机制的预留接口」与第 13 节「待确认事项」 |
| v0.4 | 2026-09-20 | 依《背包乱斗》真实机制修正空间模型（详见报告 006）：移除装备栏；背包改为「棋盘 + 玩家放置包体」双层占用；新增暂存区（保留但不参战）；编译期邻接改为带约束的确定性插槽配对；冷却改用定点数以支持 ±2% 比例叠乘 |
| v0.5 | 2026-09-20 | 修正 4.2：插槽点亮是**去重计数**而非二分匹配（v0.4 写复杂了）；补充插槽的数据形态与两种效果方向；新增 4.3「数值约定」，确定结算公式为「基础值 × ∏(1+乘区) + 固定加值」、乘区为可扩展枚举且只能末尾追加、全流程定点数四舍五入 |
| v1.29 | 2026-09-21 | **章节 BOSS 失败直接战败**（7.1）：别的战斗输了节点变空白人还能走，核心变空白这一局就没有终点，所以打 BOSS 是押上整局的决定 —— 偏搜索路线「可以不打 BOSS」因此是真退路。**M3-1 地图数据层落地**（报告 030）：5.2 与实现对齐 —— `seed` 改名 `content_seed`（会遮住全局函数），`MapEdge` 加 `layout` 与 `other` / `passable_from`，`MapGraph` 补构建与查询方法；序列化确定（节点按 id 升序），`normalize` 把 JSON 读回来的整数值浮点还原，保证过一遍 JSON 字节不变 |
| v1.28 | 2026-09-21 | 作者再补四条。**一**、战斗输了节点也变空白（7.1 / 5.6）：我原先暂定「节点保留可重打」，纠正 —— 重打会让体力变成兑换尝试次数的货币；一次性消耗让每个敌人都是只答一次的题。**二**、搜索点的风险与收益都随搜索次数上升，搜几次是留给玩家的旋钮（5.4.2）：生成器只按 `reference_searches` 给路线定档，「低风险低收益」的准确含义是基准档低、上限由玩家拧。**三**、敌人在地图上看得见属性与背包（新增 5.10）：节点内容在生成地图时就定好（`MapNode.content`），`random` 是唯一看不透的点；**敌人就是一个背包**，与玩家走同一个 `BattleCompiler`，预览读数与真打一致，背包即掉落来源。**四**、多个出生点供玩家挑，每个对应一条路线：`MapGraph.routes` 记下每条路线的风格、尽头与风险收益档位，开局展示；风格由玩家看图自选而不是生成器抽签 |
| v1.27 | 2026-09-21 | 作者补三条底层机制。**一**、路线风格是取舍不是等难（5.4.2 重写）：偏搜索低风险低收益、尽头是撤离点可以不打 BOSS、搜到好东西可换乘去打；偏战斗高风险高收益、路上有中途撤离点、战损过高就撤。「整体不变」的是性价比 —— 每条路线的风险分、收益分各落在风格区间，各路线收益/风险之比相当；退路做成拓扑：相邻路线每 N 环一个受保护的换乘点。**二**、战斗失败不直接战败，扣**体力**（7.1）：普通 −1、精英 −2，归零才战败；体力是 run 级小整数，跨战斗保留，与战斗内资源无关；15 节第 1 项由此定案，侵蚀浅层惩罚改为扣体力。**三**、道具既提供战斗力也有本身的价值（6.4）：`ItemDef.value`，0 = 按稀有度 × 尺寸算（`ItemValue.of`），用于撤离结算、买卖、侵蚀损坏；它是路线收益分的单位 |
| v1.26 | 2026-09-21 | 地图生成按作者三点重做（5.4 / 5.4.2 / 5.5）。**一**、每环各类点按规则分布：`RingSpec.quota` 给每类 `[min, max]`，权重只填配额外的空位，`no_adjacent` 管不许挨着的类型对。**二**、休息区与商店改按**步数覆盖**放：作者指出玩家走的是一段路径不是整个环，「每 N 环一个」等于没保证；改为「任何节点距最近休息区 ≤ K」，图上最短路，贪心集合覆盖修正，死胡同也算，高危区里不放。`required_every` 删。**三**、路线在生成之初就有：**骨架先行** —— 先从入口逐环向内铺 `entry_count` 条路线（各配一种 `RouteStyle`，合流有最早环数），再往周围长出地图；风格通过 `mix` 落到路线独占节点上。「整体难度不变」定义为**难度分**相等：Σ `type_score × danger_multiplier`，搜索点按期望遭遇数计分而不是 0 —— 偏搜索的路线拿的是更多战利品和更大方差，不是更少的战斗。骨架节点与边受保护，高危区避开骨架，断边不断骨架 |
| v1.25 | 2026-09-21 | 读作者的 `地图配置v0.1.xlsx`（报告 029）。节点类型用字母细分：`A` 战斗、`E` 精英、`S` 商店、`R` 休息、`V` 搜索、`Q` 事件、`?` 随机（在 A/S/R/V/Q 里挑，不会变成精英）、`B` 章节 BOSS；`1` 按 `?` 处理。**危险区域用底色标**：红 = 高危、黄 = 中危，落到文本的第二层 `[danger]`；节点新增 `danger` 字段（0/1/2），**叠在 tier 之上**，两者是内容层选敌人池与掉落表的独立输入。加 `tools/map_xlsx_to_text.py` 把表格转成两层文本。搜索点与常规事件的机制描述照作者原话记入 5.4 |
| v1.24 | 2026-09-21 | **数据层只记连接与次序，不记坐标**（5.2 / 5.4 / 5.4.1 / 5.9）。作者点明：配置表里同行点之间的空格与通路长度不代表渲染距离；异环通路要在渲染时靠调整每个点的角度做到**永远垂直于切线**。于是 `layout` 载荷从 `{ring, angle, radius}` 改为 `{ring, order}`，生成器（随机与手绘）都不再算角度，抖动参数移出生成器配置；5.9 新增环形布局求解：径向边做并查集共用角度，从外环向内逐环定角、其余节点在次序上插值，岔路合流处取均值并告警。两个生成器只产出次序，同一个求解器画它们 —— 布局只写一次 |
| v1.23 | 2026-09-21 | 读作者的 `地图配置v0.xlsx`，把它定为**手绘地图的网格脚本格式**（5.4.1）：偶数行是环、奇数行是连接层，`-` 连成的段是一条弧（中间可以跨过空槽）、`\|` 落在弧上是岔路口（插一个无事件的 `junction` 节点）、连续 `\|` 是跨环路径、行末 `0` 左边是 `-` 则首尾闭合。走同一套 `MapGenerator` 接口（`grid_script`），可插拔在第一章就兑现；并要求能反向导出，生成图人眼可读、可手改、测试用文本做金样。作者补的三条：**环越靠里越短**，槽位数按 `TAU·r·radius_step / arc_per_slot` 算（5.4 步骤 3）；节点类型待细分（建议一位数字一种类型，高危区改用底色标）；**中途撤离点是覆盖不是叠加** —— 第一版写成了 `is_extract` 属性，改回类型 `extract`，每 N 环挑一个非必须型节点把类型改掉 |
| v1.22 | 2026-09-21 | **包的内容物改用本地坐标，并允许跨包**（3.2 / 3.3）。第一版转包让内容物留在原处、出了轮廓就脱落 —— 实际一试，一件整件在包里的东西转一下就掉出来，那是旋转出错不是脱落。改为内容物记「相对包原点、折回包 rot 0 坐标系」的本地坐标，包换朝向时按同一变换跟着转，整件在包里的永远还在包里。会脱落的只剩**跨包的**：一件东西现在可以横跨两个包（每格有包覆盖即可，碰到的每个包都得接受），但它谁的内容物都不是、两边加成都拿不到 —— 用加成换空间的取舍；包一动它少了半边依托，原样放回它回原处，放到别处它脱落。早先「必须整件在一个包里」的理由（归属无歧义）由「跨包的谁的都不是」替代。另按示意图补 5.4：环由 slots 与 node_count 决定，空槽连成一段空白区；切向边不跨空白；**一环可以断成几段**，「每环互通」指每一段都从别处到得了 |
| v1.21 | 2026-09-21 | **两件。**（一）包也能转（3.3）：转过之后内容物不跟着转，落在新轮廓外的脱落进暂存区。早先禁止转包是因为「内容物跟着转」边界情况多，但那条路真正的问题是转一下包会改掉包里每件东西的朝向、搅乱玩家摆好的布局；脱落是局部的、残影上看得见的、放手前可撤回的。原地转与拖拽中按 R 走同一段代码。（二）地图生成逻辑按用户给的规则重写（5.4 / 5.5 / 5.8）：环由配置逐个声明（`RingSpec`：类型、节点数、事件权重）；`rest` / `shop` / `elite` 为**必须型**，每 N 环至少一个；**中途撤离点是叠在普通节点上的属性**，不是一种节点；至少一片**高危区** —— 一片相连的节点，有精英有多个搜索点，与外界只有一条边；然后按规则断同环边、连相邻环。**因为可以走回头路，死路不是问题**，校验只要求全图连通，删掉了「每节点至少一条径向边」「入口到核心最短路够长」「每个 band 内部连通」三条 —— 最后一条是因为侵蚀不封路，幸存区被切碎困不住人 |
| v1.20 | 2026-09-21 | **删掉 `ItemDef.can_rotate`**。它本意是「钉死某些装备的朝向」，但一件占两格的东西横着还是竖着，是玩家在棋盘上的空间取舍，不是内容作者该替他做的决定 —— 而一个实际上永远为 true 的字段，代价是每一处旋转路径都多一层没有意义的分支（`GridInventory` 里有三处一模一样的 `effective_rot`，`ItemInstance` 里还有三处）。唯一保留的旋转限制是运行时的「有内容物的包不能旋转」，它是**状态**的限制，不是道具的属性 |
| v1.19 | 2026-09-21 | 两件开发期便利。**任意场景按 F1 回启动选择器**：做成 `DevNav` autoload 而不是让每个场景自己加按钮 —— 后者漏装的表现是「F6 直接跑进去就出不来，只能关掉重开」，而那时没有人替它装。不用 Esc 当返回键：拖拽中的取消是 Esc，编辑器的输入框也可能吃掉它，手一滑回主界面在编辑器里意味着草稿全没。场景可以实现 `has_unsaved_changes()` 要一次确认（鸭子类型，不让开发期脚手架在正经场景的类型里留痕迹）。**编辑器左侧加按标签分类的竖排页签**，页签从内容里长出来而不是写死的枚举 —— MOD 作者加一个标签就自己多一页。为此把「列表里显示哪些」从 `_ids` 拆成 `_shown`：ItemList 的行号对应的是筛过的那一份，两者混用的表现是「点第三行打开了第五件」，而且只有加了筛选之后才错 |
| v1.18 | 2026-09-21 | **暂存区改成列表容器**（3.4）。它此前和棋盘共用 `GridInventory`，于是往里放东西也要摆位置、也会「摆不下」—— 等于凭空发明一套「暂存区也要会整理」的玩法，而那正是这个区域存在的目的所反对的：它是让玩家腾手的地方，不是第二个要动脑子的棋盘。新增 `ItemStash`（无坐标无占格，`capacity` 为 0 表示不限）与 `StashView`（一列可拖动的行，显示稀有度、名字、占格数 —— 占格数留着是因为那是放回棋盘时唯一关心的信息）。为此把两类容器的共同部分抽成 `ItemContainer`，`admit` / `can_admit` 让跨容器搬运不必了解目标的空间规则；视图侧同样抽出 `ContainerView`，拖拽层因此只需在落点那一处分叉。限制一条：带内容物的包收不进列表，列表装不下「包 + 内容物的相对位置」，要收起来先掏空 |
| v1.17 | 2026-09-21 | 补上背包摆放的三件缺口。**一、邻接标记从来没画在棋盘上过** —— 只有编辑器画，游戏里是全黑的，弹匣的增益格配了也看不见，玩家无从判断摆位对不对。现在画成角括号并区分点亮状态（4.8）。**二、加顶替式放置**（3.3.1）：压着别人放手会把人挤出来，一件直接上手、多件进暂存区、没地方安置就整件事作废；落点预览相应分成绿／黄／红三档。**三、战斗沙盒补上暂存区**，此前只有 M1 沙盒有，导致「把不想要的东西拿下来」在战斗场景里根本做不到。另把战斗沙盒的开局布局从 `try_add` 改成指定坐标：弹匣的增益格朝上，自动装填很容易把它摆在第一排，标记指向棋盘外既不点亮也画不出来，演示场景必须让机制自己显形 |
| v1.16 | 2026-09-21 | 删除 `data/shapes/`：导入器产出的资产把形状**内嵌**在物品里，那个目录已经没人读了，只剩被取代的 bootstrap 脚本还在写。同时给 `gen_sample_items` 与 `gen_sample_combat` 上锁 —— 它们按代码里写死的表重写资产，作者数据目录一旦有内容就会把编辑器里配的东西不声不响冲掉，现在遇到已有作者数据直接拒绝运行。另把编辑器测试改成**只断言机制、不断言内容**：原先写死「弹匣有两个增益格」，作者调一下数值测试就红一次 —— 红得毫无信息量，最后只会被无视。改为断言「画板读到的与定义一致」这类不变式 |
| v1.15 | 2026-09-21 | 编辑器加**草稿缓存**：切到别的道具再切回来，未保存的改动还在。对着一件改到一半、想去看另一件的形状，回来发现全没了 —— 这种事发生一次作者就再也不敢点列表。草稿只在内存里，列表上用点标出，改回原样会自动撤掉标记。为此给测试跑器加了**第二阶段**：`frame_*(t, root)` 在第一帧跑，因为 `_ready` 要进入帧循环才派发，在 `_initialize` 里 add_child 之后立刻用控件全是 null。绝大多数用例不需要场景树，所以分两档而不是全挪到帧里 |
| v1.14 | 2026-09-21 | 编辑器保存时**同时产出 JSON 与 .tres**，不必再手动跑导入器 —— 忘了跑的表现是「改了没生效」而界面一切正常，最容易让人怀疑人生。产出资产走的就是导入器那条路（导出成 JSON 再导入回来），实测与命令行产物**逐字节相同**。目录常量收进 `ContentPaths`，编辑器与两个命令行工具共用一份。校验新增一条：**标记格压在物品自己的格子上时警告** —— 编译器点亮邻居时会跳过 holder 自己，所以那种格子永远点不亮，既不报错也不生效，是最难自查的一类配置（照真实内容发现的）。另把 `test_item_assets` 的件数断言从精确值改为下限：写死意味着每加一件道具测试就红一次，而加道具恰恰是最频繁的操作，何况内容现在 MOD 作者也会动 |
| v1.13 | 2026-09-21 | 编辑器的形状画板升级为**三层**：占格、增益格、受益格画在同一张网格上。此前标记格只能在表单里按 `x,y; x,y` 手敲坐标 —— 而「加成的是上下相邻那一格」是条相对偏移，脱离形状根本看不出来。标记格在轮廓之外、偏移可为负，所以网格四周留边距并按已有标记自动撑开。`PropertyForm` 的跳过表改为**按类名**索引并向子表单传递，好让 `adjacency.grant_cells` 这种嵌在子对象里的字段也能从表单里摘掉 —— 两处能改同一个值迟早对不上。另新增 `ui/launcher.tscn` 作为主场景（第 10.6 节），三个开发期入口列在一起，不必再记场景路径 |
| v1.12 | 2026-09-21 | 新增 `tools/cli_tool.gd`，`--script` 跑的脚本一律继承它。起因是一个临时探针脚本跑了两分钟没回来。实测确认两条 GDScript 行为：运行时错误**只中断出错的那一层函数**，调用方继续往下走；而若出错的正好是 `_initialize`，末尾的 `quit()` 就永远执行不到，无头进程一直空转 —— CI 里表现为超时，比一条报错难查得多。`tests/run_tests.gd` 早就踩过并加了 `_process` 兜底，但每个工具各写一份迟早漏掉：收进基类时七个工具里六个没有。崩溃判据也纠正了一次 —— 「在 run() 后面放一句已完成标记」判断不出 run() 有没有崩（由第一条行为，那句照样执行到），改成「run() 自己有没有走到 finish()」 |
| v1.11 | 2026-09-21 | **内容管线落地**（第 10 节重写 10.4／10.5）：JSON ⇄ .tres 双向，命令行 `import_content` / `export_content`，外加给 MOD 作者的可视化编辑器 `ui/editor/content_editor.tscn`。核心是**三方都不认识具体效果** —— 靠 `get_property_list()` 与类型化数组的 `get_typed_script()` 问出类型，碰到抽象基类才按 `type` 去注册表查。于是新增一种效果＝加脚本 + 登记一行，导入器、导出器、编辑器的下拉框全线自动认得。用**往返测试**守住这条性质（导出→导入→再导出逐字节相同，并拿真实资产过一遍）。踩到两个坑并记进文档：Godot 的枚举 `hint_string` 给的是美化名 `Opponent` 而非源码里的 `OPPONENT`，以及导出形状必须返回普通 Array 而不是 PackedStringArray（否则内存里往返失败、过 JSON 反而成功）。另新增 `tools/check_scripts.gd` 并接入 test.sh：单元测试只加载 run_tests 够得着的脚本，`ui/` 与 `tools/` 改接口时最容易漏 —— 这一步已经吃过两次亏，其中 `ContentSchema` 因一条「从 Variant 推断类型」的警告静默加载失败，测试只表现为一堆莫名其妙的断言不过 |
| v1.10 | 2026-09-21 | 资源新增**按时间自动回复**（4.5）：速率写成 `regen_xxx` 属性，与 `max_xxx` 对称。**懒结算** —— 没有定时器也没有每秒事件，推进器每到一个时刻按「距上次结算过了多久 × 当刻速率」一次性补上；线性累积所以勤结算不会算多，而且速率变化恰好发生在时刻点上，勤结算反而更准。结算排在 buff 到期之前，否则最后一段会用上 buff 消失后的速率。因为速率只是一条普通属性，**「buff 影响回复量」不需要任何新机制**，一条 StatModifier 即可。此前完全没有回复：沙盒里两把武器约 9 秒抽干耐力，之后整场站着不动 —— 这个缺口是有了血条才看见的，待确认第 10 项就此定案 |
| v1.9 | 2026-09-21 | 补完 4.8 表现层：`BattleView` 只消费事件日志，快进／倍速／跳过／跳转都只是移动游标。为此让**日志自足** —— `resource_changed` 带上变化后的 `current`/`max`（只给增量的话，漏掉一次上限变动血条的分母就永久失真），`damage` 带上 `absorbed`/`armor`，`BattleResult` 新增 `initial` 开战快照作为回放起点（否则表现层得自己去编译棋盘，1.1 的分离就破了）。反过来 `before_damage` 不进日志、物品名也不进（名字是表现层的事，拿 uid 查表即可）。踩到一个坑并记进文档：日志载荷是定点而快照已取整，混着送会让血条显示 0/0 却画成满格 —— 换算统一在 `BattleView` 一层做完。新增 `ui/battle/battle_sandbox.tscn` 作为 M2 验收场景，并给 13 件示例道具补上占位战斗数据（过渡方案，导入器落地后由 JSON 取代）。沙盒随即暴露出待确认第 10 项：**耐力不回复**，两把武器约 9 秒抽干后整场哑火 |
| v1.8 | 2026-09-21 | 伤害类型新增 `provokes`（原 `notifies` 改名并扩义）：**只有直接攻击才招致反伤、吸血、格挡这类反应**，中毒、流血、反伤、流失一律不招致。此前防止反伤对轰只靠 `MAX_DAMAGE_DEPTH = 4` 这个递归上限，那是兜底不是解决 —— 撞上限意味着对轰仍然打了四轮。把「反伤不引发反伤」写成类型的语义之后，对轰在第一层就终止，上限退回它该待的位置（内容配错时给一条可定位的告警）。新增类型 `bleed` 与 `reflect`，新增效果 `ReflectDamage`：按伤害包的待结算量计算反弹（`DealDamage` 读不到那个数），且默认就用对类型，作者不必记得填。逃生口不变 —— 扳机里显式写下类型名照样听得见 |
| v1.7 | 2026-09-21 | **伤害结算拆成五步管线**（新增 4.6，原 4.6/4.7 顺延）：确认类型 → 护盾吸收 → 受伤前效果 → 计算受伤量 → 受伤后效果。此前减伤只有「护甲」一个固定数，而「消耗 2 层格挡减免 10 点」「解毒剂让中毒反转成治疗」都有**前置条件**，塞不进任何固定字段 —— 它们必须是带扳机、带消耗的普通规则，作用对象是正在结算的那包伤害（`DamagePacket`）。受伤前是**唯一同步派发**的事件（排队就赶不上本次结算），因此有 4 层嵌套上限兜底。伤害类型的行为写进 `DamageTypeDef`（能否被护盾吸收／吃不吃护甲／是否通知），新增一种不改结算代码。**扣血量一律走管线**，包括超频这类以血为代价的机制，类型为 `drain`（流失）—— 它不点亮反伤与吸血（否则割自己一刀成了正收益），但**显式监听 `drain` 的扳机照样听得见**，这是留给未来联动的口子。另两项：`base_hp` 升级为 `CombatantBaseline` 属性表（**耐力有了基线**，此前玩家捡到枪可能一发打不出；同时是角色系统的占位），编译期记录增益槽的**连结关系**供 `OnItemFired` 的 `LINKED` 来源使用（本作没有主武器设定，「跟着某件道具触发」只能靠摆放连结表达） |
| v1.6 | 2026-09-20 | 形状的正式记法定为 **0/1 布尔矩阵**（`1` 占格、`0` 空），文档表格里写成带换行的数字串、单元格内用 `<br>`。形状本来就是一张布尔矩阵，0/1 是它所见即所得的写法；`##/#.` 那种压扁成一行的形式要读的人在脑子里还原二维结构。新增 `ItemShape.from_bits()` / `to_bits()`，文档表格、导入器 JSON、测试三方共用同一记法，导入器不必做任何转换；`from_ascii()` 同时接受 `1` 与 `#`，旧写法不破。另修 10.2 的 JSON 示例：`on_tick` 与 `every_nth` 早已不存在（v1.1 分别由 `on_schedule` 与 `charge` 消耗取代），示例一直没跟上 |
| v1.5 | 2026-09-20 | **效果收归一棵树**：`SetEffect` 与 `Effect` 两棵独立的树合并为 `Effect`，按作用域分支成 `CombatEffect` / `LootEffect` / `MapEffect`（第 9.2 节重写）。原先同一个概念存在两遍，且战利品效果被锁死在套装上 —— 单件道具想「让敌人多掉一件东西」写不出来；现在 `ItemDef.effects` 与 `SetTier.effects` 共用同一套词汇，道具的那份在棋盘上就算激活，不必凑套装。`SetTier` 随之摊平为 `mods` / `rules` / `effects` 三份（生命周期不同，并成一个列表只是把分拣挪到运行时），编译器改收 `combat_mods()` + `combat_rules()`。新增 `RemoveStatus` 与 `ChangeResource`（后者取代 `RestoreResource`：原名只有正向语义，减少要靠传负数，命名撒谎）。新增三个状态条件型扳机 `OnStacksAtLeast` / `OnResourceBelow` / `OnDamage`；其中**消耗型与激活型只差一个勾选框**，消耗型由扳机隐式追加一条 `StatusStackCost` 而非自己扣层数 —— `matches()` 必须只读，且消耗要发生在所有条件通过之后，否则「攒够 3 层但耐力不够」会把 3 层白吃掉。**伤害类型不绑定乘区分类**（两个正交维度，绑一起就写不出「强化影响全部伤害」）。另澄清 3.4：**暂存区里的道具 = 不存在**，它是关卡内的临时摆放区，进入下一关即连同道具消失；清空时机列入待确认第 7 项 |
| v1.4 | 2026-09-20 | 套装由「编译期的一步」升格为**独立的背包层系统**（新增第 9 节，原 4.6 删除，其后各节顺延）：物品拖入棋盘即计数激活并发信号供 UI 实时暗／亮切换，不必等到战斗。效果**按作用域分类**（`SetEffect.scope()`）——`CombatSetEffect` 由编译器取用，`LootSetEffect` 留给 M4 掉落系统；把跨域效果塞进同一接口会逼着掉落系统去理解 `StatModifier`。另修两处：单位级属性聚合时**乘法单位元类属性不得跨物品累加**（否则 N 件物品 = N 倍速度），且这类属性缺席时返回自身单位元而非调用方 fallback（漏传一处就把速度当成 0） |
| v1.3 | 2026-09-20 | 事件掩码升级为**事件→规则索引**（`_by_event`），派发从 O(全部规则) 降为 O(订阅者)，并省掉大量一次性 `RuleContext` 分配；原掩码是它的退化版，已合并。索引重建改由 `CombatantRuntime` 在规则集变动时自动触发 —— 施加时漏调只是少触发，移除时漏调会让已删除的规则继续派发，后者是真 bug。另修正：`_resolve_instant` 开头调 `flush_all`，否则事件型规则的冷却只在触发时结算，期间发生的变速会被错误地套用到整段区间 |
| v1.2 | 2026-09-20 | 定点标度由 `65536` (2^16) 改为十进制 `10_000`（四位小数）。2 的幂来自 C／嵌入式惯例，图的是乘除能编译成移位，而 GDScript 里这个好处根本不存在；代价却是设计师写的每个十进制数都被舍入（`0.1` 在 2^16 下是 `6554/65536`，三次累加不等于 `0.3`）。改后该类误差消失。取一万而非一百万，是因为 `mul()` 的约束是「两个值之积 < 2^63 / ONE²」：`ONE = 1e4` 时余量 `9.2e10`，`ONE = 1e6` 时只剩 `9.2e6` —— 百万血乘十倍就溢出 |
| v1.1 | 2026-09-20 | **模拟改为事件驱动，彻底去掉帧**：直接算出每次出手与 buff 到期的精确时刻并在其间跳跃，零累积误差、可跑批量平衡、出手间隔可为任意小数；`OnTick` 由 `OnSchedule` 取代。冷却按「工作量」累积而非绝对就绪时刻，变速不丢进度。频率层收窄为纯调度（`Always` / `CooldownCadence`），「攒够 N 次」「全场限用」「按概率」移入消耗层 —— 它们与耐力不足的失败行为一致，留在频率层会让调度器在同一时刻空转；`costs` 列表本身即 AND 组合子，删去 `AllOf`。另新增 `docs/effect-catalog.md` 汇总全部可用构件 |
| v1.0 | 2026-09-20 | 定案两条：资源上限增加时**当前值同量增加**（降低则截断），连带变化以 `reason = max_changed` 区分于治疗；**战斗中没有任何玩家操作**（仅观看与跳过），由此 4.1 的模拟／表现分离从设计选择变为必然结论，并确立四条硬约束 —— 胜负开战即定、`BattleView` 不接收战场输入、战斗期间背包 UI 禁用而非「改了不生效」、`Effect.apply()` 必须同步完成不得等待玩家输入 |
| v0.9 | 2026-09-20 | 效果系统由三层扩为**四层**，新增独立的**消耗层** `Cost`：`costs` 为列表且 AND 语义，支持消耗资源与 buff 层数；**消耗与冷却刻意不原子** —— 付不起则跳过效果但冷却照常清零，否则耐力不足毫无代价；明确否决等待队列。新增 4.5「战斗内增益系统」：战斗中一切属性变化（含资源上限）均由 buff 承载，buff 仅限本场战斗、结束清空，参战属性只在开战时读取一次；buff 可携带 `rules`，故灼烧之类无需在 `BattleSim` 写特例；buff 走同一条内容管线 |
| v0.8 | 2026-09-20 | 细化 4.4：战斗每个步骤（出手／效果结算／状态叠减层／资源增减）均为事件；生命与耐力统一为**资源池** `resource_changed(key, delta, reason)`，新增资源种类不新增事件类型；**开战前按订阅并集算事件掩码，只广播有人听的事件**，并明确三条约束（取双方并集／规则集变化须重算／必须与全开路径逐条一致）；`Cadence` 改为 `can_fire`＋`commit` 两阶段并引入 `AllOf` 组合子，使「冷却＋耐力消耗」原子成立；事件排队派发、设深度上限，禁止递归立即派发 |
| v0.7 | 2026-09-20 | 新增 4.4「效果系统」：时机（`Trigger`）／频率（`Cadence`）／内容（`Effect`）三者分离，一切皆事件，连带触发不再是特例；新增 4.5「套装效果」；新增第 9 节「内容制作管线」（JSON 源数据 + 注册表驱动的导入器）；实施顺序重排：内容管线紧跟 M2，侵蚀系统推迟到循环闭合之后 |
| v0.6 | 2026-09-20 | 邻接机制按语义重命名：`SocketProfile` → `AdjacencyProfile`，星形／菱形两类标记改为**增益 grant／受益 receive**，原先分开的「标记类型」与「效果方向」合并为一个概念；`socket`／「镶嵌」一词腾出来留给尚未实现的宝石系统，并在第 12 节登记其接入点 |
