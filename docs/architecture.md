# 背包搜打撤 — 架构设计文档

> 版本：v1.76 ｜ 引擎：Godot 4.7 (Forward+ / Jolt) ｜ 状态：M1～M6 落地，作者提议（058 / 059）按顺序实施中，第 7 阶段侵蚀未开始（现状见 [status.md](status.md)，变更记录见 16 节）

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
                      │  GameDirector (ui/game 场景根) │  持有 GameFlow —— 场景流状态机（纯逻辑，8 节）
                      │  RunState / MetaState (纯逻辑)│  一局 / 跨局的全部数据，flow 持有，不是 autoload
                      │  信号：逻辑 → UI 单向         │  没有 EventBus：每一屏订阅自己要的信号
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

它是**一个点上**的一块临时摆放区（搜出道具、战后搜刮战利品时用来腾挪位置），
**走出这个发生过事的点时连同里面的道具一起留在那里**（作者定案，058 第 3 条；实现见下）。它不是第二个背包，也不是仓库。

因此凡是「棋盘之外」的东西，对任何系统都不可见：

| 系统 | 只看 |
|---|---|
| 战斗编译（4.2） | 棋盘上的非包物品 |
| 套装计数（9.1） | 棋盘上的非包物品 |
| 道具自带的跨域效果（9.2） | 棋盘上的物品 |

实现上没有特殊处理 —— 各系统一律只遍历棋盘容器，「暂存区不算数」是这条规则的**结果**，
不需要任何一处写 `if in_staging`。

唯一的例外在 UI：离开前若暂存区里还有值得提的道具，应当提示玩家可能遗落。这是提示，不是挽留。

#### 何时清空：走出发生过事的点

「发生过事」= 踩上去时 `NodeEvents` 真的处理了什么：打了、搜了、开了店、休息了、出了事件（随机点揭开后按揭成的类型算）。
出生点、岔路、撤离点、只是路过的用过的点都不算 —— 在那些点上整理背包、被顶出来的东西不会一走就没。
`NodeEvents.last_handled_id` 记住最近一次发生过事的点，`RunState.step_to` 走出它时把暂存区清空（发 `storage_dropped`），
然后把它清回 -1：回头再路过一次不会又清一遍。走不成（不相邻）不清。跟着存档走。

提示按玩家设置的档位（`GameSettings.storage_warn_mode`，存 `user://settings.json`）：有东西就提 / 只提稀有度达到某档的 / 只提价值达到某数的 / 从不；
挑哪些出来提由 `StorageWarning.at_risk` 算，地图屏在走之前弹一块面板（照走 / 先整理背包 / 取消）。档位是数据里的一张表，加档位不改分支。

> 曾经的另一案是「整局保留、结算才清」（15 节第 7 项）。作者定的是按点清：暂存区是在一个点上腾出来的空间，节奏是每个点收拾一次。
> 两案对代码的要求相同 —— 各系统坚持「只看棋盘」，所以之前推迟决定没有阻塞任何模块。

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

判定标准：新增一种地图形态时，**只需新增一个 `MapGenerator` 子类和一个 `MapLayoutStrategy` 子类**，`MapGraph`、`MapNavigator`、`ActionClock`、`ErosionField`、`MapView` 主体、存档逻辑均不改动。**8-2 兑现**（报告 078）：沙漏与塔两个格阵模板就是这么加进来的，见 5.11。

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
@abstract class_name MapGenerator extends RefCounted

const MAX_ATTEMPTS := 32

var attempts_used: int        # 上一次 generate 用了几次。批量调参时看它的分布
var failure_tally: Dictionary # 规则 → 失败次数。「30 次里 28 次是不连通」直接指出该调哪个参数

## 子类只实现这一个：造一张图，造不出来返回 null。
## 【子类有义务为每个节点写入 tier 与 erosion_band】
@abstract func build(cfg: Resource, rng: RandomNumberGenerator) -> MapGraph

## 校验 + 换种子重试都由基类包办。base_seed 相同则结果相同
func generate(cfg: Resource, base_seed: int, attempts := MAX_ATTEMPTS) -> MapGraph

## 通用校验。子类重写时【必须先调 super】
func validate(graph: MapGraph, v: MapValidation) -> void

static func reachable_from(graph, from_ids) -> Dictionary   # BFS，单向边只顺着走
static func derive_seed(base: int, attempt: int) -> int     # 第 i 次尝试的种子

# core/map/map_validation.gd
class_name MapValidation extends RefCounted
func fail(rule: StringName, message: String) -> void   # rule 是聚合用的键
func ok() -> bool / rules() -> Array / tally() -> Dictionary / to_text() -> String
```

**子类只实现「造一张图」，校验与重试由基类包办** —— 每种形态不必各写一遍
「失败了换个种子再来」。

通用校验（与形态无关的那几条）：至少一个节点、每条边两端都在、每个节点有类型、
出生点与终点非空且存在、没有一条边都不挨着的孤立节点、**全图连通**（每个节点从某个
出生点走得到）、终点可达。**死胡同是合法的** —— 玩家可以走回头路，死路不是问题，
这条最容易被顺手加进校验。环形图的配额、覆盖、路线那些是 `RingMapGenerator` 自己的规矩。

生成失败时的统一策略：**换种子重新生成（最多 32 次）**，而不是写复杂的保证性算法。
后者的实现与维护成本远高于前者，且更容易出现难以察觉的分布偏差 ——
「总能生成出合法图」的算法，往往是靠悄悄偏袒某几种形状做到的。
用尽则 `push_error` 并返回 null，**绝不降级产出一张坏图**。

失败原因按 `rule` 键**跨尝试聚合**：重试几十次之后，「30 次里 28 次是全图不连通」
远比最后一次的细节有用，它直接指出该调哪个参数。每次尝试的种子由
`derive_seed(base, i)` 单独算得出来，所以「种子 12345 的第 7 次尝试」可以直接复现，
不必把前六次重放一遍。

章节通过 Resource 声明自己用哪个生成器：

```gdscript
# core/run/chapter_def.gd → data/chapters/chapter_01.tres
class_name ChapterDef extends Resource
@export var id: StringName
@export var display_name: String
@export var map_source: MapSource           # 随机生成（generator_id + config）或载入预设，见 5.3.1
@export var enemy_pool: StringName          # 敌人池的 id（6.0，M4-1）。按 id 引用：几章共用一个池、只改难度是常态
@export var difficulty: int                 # 章节难度，0 起。敌人池按它抬档位，掉落规则按它加掉落率；侵蚀将来也看它
@export var drop_rule: StringName           # 掉落规则的 id（6.1，M4-2）
@export var node_rules: StringName          # 节点规则的 id（6.2 / 6.5，M4-3 / M4-4）
@export var economy_rules: StringName       # 经济规则的 id（6.6，M4-5）
# 之后各加一个字段，导入器、导出器、编辑器一行不改（敌人池、掉落 / 节点 / 经济规则就是这么加进来的）：
# @export var erosion: ErosionSchedule      # 第 7 阶段；可为 null = 该难度不启用侵蚀
```

章节是**作者数据，走内容管线**（10 节）：`data/authoring/chapters/*.json` → `data/chapters/*.tres`。
导入器不认识它，反射填字段。管线为此补了三样通用的东西：`Vector2`；字典里整数值的浮点两头都写成整数
（JSON 没有整数，不这样「导出→导入→再导出」的文本就变了）；字段声明成引擎基类（`generator_config: Resource`）
时 JSON 里带 `type` 说造哪个 `class_name` 过的类，导出器反过来在类型不等于声明时写上它。
章节的校验比引擎严格：生成器得登记过、配置得是那个生成器要的类、预设文件得在。
地图编辑器里能把当前的生成器 + 配置存回一章（作者数据与资产一起写），也能从一章载入。

`MapGeneratorRegistry` 负责 `generator_id -> MapGenerator` 的映射，新增形态只需注册一行。

#### 5.3.1 地图来源：随机生成还是载入预设

一局游戏的地图不一定是现场算出来的。对局 / 章节配置里放一个 `MapSource`，
开局调 `resolve(run_seed)` 拿图 —— **调用方不必知道这张图是算的还是读的**。

```gdscript
# core/map/map_source.gd
class_name MapSource extends Resource
enum Mode { RANDOM, PRESET }
@export var mode: Mode = Mode.RANDOM
# —— RANDOM ——
@export var generator_id: StringName = &"ring"
@export var generator_config: Resource
# —— PRESET ——
@export_file("*.json") var preset_path: String
## 预设定死的是【地形】（点、路、类型）；节点里刷出什么由 content_seed 决定。
## true = 每局按对局种子重掷（同一张图每次打法不同）；false = 连内容也原样照搬
@export var reroll_content_seeds: bool = true

func resolve(run_seed: int) -> MapGraph      # 失败返回 null，原因在 last_error
```

**预设文件就是 `MapGraph.to_dict()` 的 JSON**（`data/maps/*.json`，`MapPreset.save / load_graph`），
不另发明格式：生成出来的图与手改过的图在这里没有区别。

载入预设时**只问通用校验**（连得上、有出生点、到得了终点；`MapGenerator.validate_common`，
静态的，因为那时手上没有生成器）。形态自己的规矩 —— 环形图的高危区单入口、换乘点、
出生点间隔 —— 是**给生成器的约束，不是给作者的**：手绘的图有权不守。

**地图编辑器**（`ui/map_editor/`）走的是「先按参数随机生成 → 手动改 → 存成预设」：

- 它**不认识任何具体的生成器**。左侧参数表单是把 `MapGenerator.default_config()` 给的配置
  用 `PropertyForm` 反射出来的（和道具编辑器同一个表单）；画法问 `MapLayout`
  （`layout_kind → 布局`，和生成器注册表同一个套路）。新增一种形态 = 登记一行生成器 + 一行布局，
  编辑器一行不改。
- 改图动作：选点、改类型 / 危险等级 / 所属高危区、设为出生点 / 终点、连边 / 断边、
  在布局给出的空位上加点、删点。`graph.zones` 每次从节点的 `zone` 字段重建，两处不会对不上。
- 校验分两档显示：**通用规矩**（红）不过就不能当预设用；**形态规矩**（黄）只是提醒。
- 删点**不动路线标注** —— 删掉中间一个之后怎么接是作者的决定；校验会说「路线断了」，
  作者要么修图，要么点「清空路线标注」。
- `MapLayout` 的环形实现是最朴素的一版（角度 = 槽位 / 槽位数）。「径向边永远垂直于切线」
  要靠求解每个点的角度（5.9），仍是 M3-6 的事。

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
| `extract` | `X`（暂定） | 中途撤离点 | 覆盖型，见下。符号是解析器先占的位，等作者在表里定 |
| `junction` | — | 岔路口：路上的一个拐点，没有事件 | 手绘地图才有，见 5.4.1 |
| `core` | `B` | 章节 BOSS，最终撤离点，固定一个 | — |
| `spawn` | `P`（暂定） | 出生点，图上写「生」。是一种节点，不只是一个标记：不参与 mix、配额与校准，风险收益都是 0 | 结构性 |

符号来自作者的地图配置表 v0.1。`1` 是 v0 遗留的「缺省事件点」，解析时按 `?` 处理。

**必须型**指配置里要求「每 N 环至少一个」的类型。它们不能只靠权重抽取碰运气 ——
连续五环没有休息区，玩家撑不到核心；但也不能每环都有，那就没有取舍了。

**中途撤离点是覆盖上去的**：挑一个**非必须型**节点，把它的类型**改成** `extract`。
那个位置原本的事件没了，换成一个出口 —— 不是「打完这场就能走」，是「这里就是出口」。
不覆盖必须型，否则休息区或商店会被出口吃掉；不开在高危区里。

**只落在撤离环间**（`RingMapConfig.middle_rings`：正中间的那一两环 —— 4 环是第 2、3 环，5 环第 3 环，
6 环第 3、4 环，7 环第 4 环，8 环第 4、5 环；大型的两道还没定，占位）。以前是「每 N 环一个」，
结果外侧那个窗口挑离已有撤离点最远的候选，总落在最外环、出生点旁边，开局一步就能撤。
放的时候先让**相邻的两条路线共用一个**：合流后共用的点、换乘点、换乘弧上的点，三条路线两两共享；
一对都放不下时环间里至少放一个。去撤离点的路线在核心前一环收尾，那个撤离点是例外。

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
## 出生点之间在最外环上至少隔几个槽位（环形距离）。放不下是配置错误，生成器会直说
@export var entry_min_gap: int = 2
## 向内走时，下一环的候选槽位在当前次序比例的 ± 多少个槽位之内
@export var route_drift: int = 1
## 单条路径的长度上限：一条边两端最多差几环 / 几个槽位。
## 槽位偏移：同环 = 相邻槽位；跨环 = 把里面那个点按比例投到外面那环上
## （外环的槽位更细，拿它当尺子），正对着的那个 ± 这么多。
## 两个值写进 graph.layout_meta，校验与编辑器从图上读
@export var edge_max_ring_offset: int = 1
@export var edge_max_slot_offset: int = 1
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
## 换乘几次由规模模板定（MapScaleProfile.pivots，5.4.3），均分在路线上。这里只管窗口：
## 离安排的那一环几环之内，两条路线的点恰好相邻就直接连起来当换乘。见 5.4.2「取舍」
@export var pivot_window: int = 1

## 路线有多长：步数 = 环数 × 它。多出来的步数是同环横着走，随机撒在各环上（一环可以走好几步）
@export var route_length_factor: float = 1.5
## 中环（= 撤离环间）比按半径算的多几个槽位：规模模板要的节点数按六到七成填充定，多出来的落在这里
@export var mid_ring_extra_slots: int = 3

## —— 覆盖（5.4.2）——
## 类型 → 每个节点到最近该类型节点的步数上限。例：{"rest": 4, "shop": 6}
## 喘气处先按路线上的步数放（MapScaleProfile.haven_at：中型 1/3 与 2/3，小型都在一半），这里是之后的补漏
@export var coverage: Dictionary = {"rest": 4, "shop": 6}
## danger 高于此值的区域里不放休息区与商店 —— 高危区是岔出去的诱惑，不该能在里面喘气
@export var no_haven_in_danger_above: int = 1

## —— 类型规则 ——
## 不许相邻的类型对。例：[["shop", "shop"], ["rest", "rest"]]
@export var no_adjacent: Array = []
## 撤离点两两之间的最短路至少几步。-1 = 用规模模板的值（MapScaleProfile.extract_gap）
## 中途撤离点落在哪几环不是配置，是环数的函数：middle_rings() / extract_band()
@export var extract_min_distance: int = -1

## —— 高危区、边、槽位（同前）——
@export var zone_spec: DangerZoneSpec        # 高危区怎么长出来；null = 不要高危区
@export var zone_count: int = -1            # 要几片；-1 = 在规模允许的范围里随机
@export var zone_soft_cap: int = -1         # 每片长到几个点就停；-1 = 用规模允许的最大值
@export var scales: Array[MapScaleProfile]  # 规模模板，见 5.4.3
@export var tangential_break_chance: float = 0.35
@export var radial_links: Vector2i = Vector2i(1, 2)
## 与 radius_step【只有比值有意义】—— 两个都不是渲染尺寸，合起来只回答「第 r 环几个槽位」
@export var arc_per_slot: float = 60.0
@export var min_slots: int = 6
## 只用来算每环槽位数，**不是渲染距离**（5.9）。
## 默认值配 arc_per_slot 得到「最内环 6 个槽位、第五环 16 个」这样的密度
@export var radius_step: float = 30.0

# core/map/generators/ring_spec.gd —— 一个环
class_name RingSpec extends Resource
## 环的类型，内容层用它选敌人池、掉落表与美术。拓扑层不解读，只写进 layout
@export var kind: StringName
## 角度槽位数。0 = 按半径算（5.4 步骤 3）
@export var slots: int = 0
## 真有节点的槽位数。少于 slots 时点匀着散在一圈上，隔得超过 tangential_span_max 的地方就是空白区。
## 规模模板要的节点数落在这里（5.4.3）。0 = 全部
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
## 偏搜索的路线可以不打最终敌人，搜够了就走。
## 中途撤离点不按路线配（以前的 bailout_every_rings 在 6 环图上只开出「第 2 环」一个窗口，
## 而那里离偏搜索路线的收尾撤离点不到间距，一个都放不出来）：它们在撤离环间，两条路线共用
@export var ends_at: StringName = &"core"

# core/map/generators/danger_zone_spec.gd —— 一片高危区怎么【长出来】（生成规则）
class_name DangerZoneSpec extends Resource
## （一张图上有几片、每片多大，不在这里 —— 那随地图规模变，见 5.4.3 的 MapScaleProfile）
## 路线走过几成之后才开始检索周围空间、可能岔出高危区。0.5 = 半程
@export var start_after_progress: float = 0.5
## 过了半程每走一环岔出来的概率；到最后一个能岔的环还没岔就直接岔
@export var spawn_chance: float = 0.5
@export var min_elites: int = 1      # M3-3c
@export var min_search: int = 2      # M3-3c

# core/map/zone_rules.gd —— 一片高危区长成什么样才【算数】（图自身的性质，进校验）
# 写进 graph.layout_meta.zone_rules：校验与编辑器从图上读，手绘的图一样要守
class_name ZoneRules extends Resource
@export var min_size: int = 3        # 至少三个相连的点，可以跨环
@export var max_size: int = 9
## 出入口上限随规模放宽：3~4 个点至多 2 个，5~6 至多 3 个，7~9 至多 4 个。
## 出入口是【区内连着区外的那个点】，不是边：一个点身上通向区外的路再多也只算一个口 ——
## 玩家站在那个点上，出去就是出去了。至少 1 个（吸收了路线节点的小区可能 2 个）
@export var max_gates_by_size: Dictionary = {"4": 2, "6": 3, "9": 4}
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
   在 slots 个槽位里挑出 node_count 个（由内向外挑）：按 slots / node_count 的步长匀着放、随机转一个角度，
   每个位置再在一步之内挪到「内环有点正对着」的槽位上（边长上限之内），这样它才有向内的边可连。
   空槽散在点与点之间；隔得超过 tangential_span_max 的地方弧断开，那就是空白区 ——
   空白区是稀疏的结果，不是先挖再填（v1.21～v1.39 是「空槽连成 1～2 段弧」，规模模板把节点数压下来之后
   那样会把点挤成一团）
     tier = 环数 - r      erosion_band = 环数 - r      layout = {ring, order, kind}
   每环的槽位数记进 graph.layout_meta.ring_slots ——【从节点上推不出来】：
   末尾几个槽位空着时，max(order) + 1 比真实槽位数小
   不算角度、不算半径 —— 点画在哪儿是渲染的事（5.9）

4. 路线骨架：
   a. 最外环挑 entry_count 个**出生点**，两两环形距离 ≥ entry_min_gap 个槽位：
      大致均分、在余量内抖动、避开空白区；一个起点排不下就换下一个起点。
      出生点数 × 间隔 > 槽位数 → 配置错误，build_note 直说。
      第 i 条路线的风格 = routes[i % routes.size()]（i 按槽位升序，下标相邻即角度相邻）。
      出生点与路线一一对应，开局由玩家挑一个（5.4.2「出生点」）
   b. **全部路线同步向内生长**：一环一环地推，每一环上所有路线一起落子 ——
      不是一条走到底再走下一条。落子之前各条路线的位置都在手上，剩余空间当场算得出：
        每条的候选 = 向内一环里【边长上限之内】且偏移 ≤ route_drift 的点；
        正对空白区一个都够不着时，**先沿当前这环横着挪**到最近的、能向内走的点
        （挪过的点与弧也进骨架）—— 不拉一条长边跳过空白区
        **候选最少的路线先挑**（先让选择多的挑，可能正好占掉别人唯一的落点）
        converge_after_ring 之前，与这一环上已落的子保持间距 ≥ entry_min_gap × 本环槽位 / 最外环槽位
        （至少 1）；挤不开先退到「不重合」，再退到合流 —— 总好过整张图作废
        选中的节点与连接它们的径向边进骨架，标 protected
      ends_at = "extract" 的路线走到核心前一环为止，末端节点定为 extract
   c. 换乘：次数来自规模模板（小型 1 次，中型 1~2 次，大型 2 次以上），沿路线均分出「安排的环」。
      **相邻直连优先**：每推进一环，相邻两条路线刚落的子如果恰好是相邻槽位，而此刻在某次换乘的
      窗口里（安排的那一环 ± pivot_window，不必严格踩在那一环上）、这一次又还没换乘过 ——
      直接把这两个点连起来，记为已换乘（落在同一个点上也算）。记在 layout_meta.pivot_links。
      **换乘弧兜底**：窗口里始终没碰上相邻的，才在安排的那一环上把两条路线之间较短的那段弧
      整条保护起来；短的那段被空白区或高危区挡住就走长的那段。
      没有换乘，「搜到好东西转去打」「打不动了转去撤」都做不到，风格就成了开局定终身
   c'. **路不许交叉**（见下「不交叉」）：骨架落子、高危区每长一步、候选边、补边，全都走同一个 _link
   d. **路线是生成规则，不是合格条件。** 它们决定地图怎么长出来，留在 graph.routes 里
      只是标注（开局给玩家挑出生点时看的）；校验一条都不查 —— 手改过的图、手绘的图
      可以没有路线，或者对不上

5. 节点类型（`RingTypeAssigner`，拓扑齐了之后单独一步；优先级从高到低，后面的修正不许破坏前面的）：
   0. 出生点固定为 spawn；高危区先凑够 min_elites / min_search：精英只放非路线的成员上、优先放出入口，
      **被吸收的路线节点不当必须型**（036）；去撤离点的路线，末端定为 extract（末端就是出生点自己时不改；
      生成器不让高危区从路线尽头岔出、也不吸收它，所以末端不会先被区占走）。
      然后**喘气处按路线上的步数放**：每条路线出生点与尽头之间的那些点，走到 haven_at 里说的几分之几处
      放休息区、几分之几处放商店（中型 1/3 与 2/3，小型两个都在一半，撞上就挨着放）；
      落点放不了就往两边挪一格。不看环 —— 以前按环深算门槛，路线一环一步时才等价。
      这些都是固定节点
   a. 路线风格：只被一条路线经过的骨架节点，先把 RouteStyle.min_share 保底的份额留出来
      （偏搜索 `{"search": 0.8}`：搜索点至少占八成，分母不算出生点、撤离点、喘气处这些固定点），
      剩下的按 mix 比例分配（最大余数法，再打乱）；后面每一步要把这类节点换走时都先问份额守不守得住；
      被多条路线共用的节点算 mixed，走所在环的权重
   b. 其余节点按所在环的 type_weights 抽。高危区里去掉喘气型（coverage 里列的那几种），
      被吸收的路线节点去掉必须型
   c. 环配额：每环每类落进 quota 的 [min, max]。超了改成权重次高的可替换类型，
      缺了从本环的非固定节点里改
   d. 覆盖修正：对 coverage 里每一种类型（rest / shop），BFS 算每个节点到最近该类型节点
      的步数；有超过上限的，就在「能覆盖最多超标节点」的候选里挑一个改成该类型，
      直到全部达标。候选 = 非固定、danger ≤ no_haven_in_danger_above、**不是已经是必须型的**节点 ——
      放商店时把休息区盖掉，覆盖就白做了。**高危区里的点不算超标**：那里本来就不放喘气的地方，
      进去就是知道没得歇
   e. 邻接规则：no_adjacent 里的类型对不相邻，违反的换成权重次高的
   f. 撤离点覆盖：只在**撤离环间**（正中间的一两环）。先让相邻的两条路线共用一个 ——
      候选是两条路都经过的点、它们之间相邻直连的换乘点、换乘弧上的点（生成器把换乘记在
      layout_meta.pivot_links / pivot_arcs 里，带着是哪两条路线的）；每对挑离已有撤离点最远的；
      一对都放不下时环间里至少放一个。挑非必须型、非喘气型、不在高危区里的节点改成 extract。
      两个撤离点之间的最短路至少 extract_gap 步（5.4.3）
   g. 路线风险/收益校准（5.4.2）—— **尽力而为，不进校验**：算每条路线的风险分与收益分
      （type_risk / type_reward × danger 倍率，沿路线求和；搜索点 × reference_searches）；
      总违规量 = 各路线偏出自己 risk_band / reward_band 多少 + 性价比离散超出 ev_tolerance 多少
      + 一点点偏离 mix 的惩罚；每轮在独占节点里挑「改一个类型能降得最多」的那一处改，
      直到没有违规、没有改善、或 40 轮用尽。换出去的只能是非必须型、非喘气型；换进来的可以是精英，
      但只限 mix 里列了它的路线 —— 不然偏战斗的路线抬不上去，校准只能把别的路线往下压，压出一堆事件点
   最后把每条路线的分数记进 routes[i].risk_x100 / reward_x100（百分之一为单位的整数：
   自由字典过 JSON 时整数值的浮点会被还原成整数，11.0 存一次读一次就变了 11）；
   类型规则写进 layout_meta.type_rules，校验从图上读。
   固定节点 = core、extract、高危区里为满足 min_elites / min_search 改出来的

6. 高危区**在步骤 4b 里和路线一起长**，不是事后在图上圈一块（细节见 5.5「高危区」）：
   每推进一环，各条路线落子之后 →（a）已经岔出来的高危区各长一个点；
   （b）过了半程（start_after_progress）的，按 spawn_chance 从某条路线刚落子的点上岔出一片新的：
   挑一个挨着它的空点当第一个点，要求那个点旁边还有空点（「周围空间充足」），
   **视作新起点并立刻再长一步** —— 一片高危区生下来就至少两个点。
   路线走完后高危区接着长，直到软上限或周围没地方。
   路线与高危区实时抢地方：高危区不占路线节点与出生点，路线也不走已被占走的点。
   收尾：只长到两个点的，把它岔出来的那个路线节点也划进去凑成三个 —— 那个点原本的路线边
   就成了出入口，哪怕这让一片三个点的小区有两个口也没关系。
   「岔出点不能是必须存在点（唯一的休息区 / 精英）」这一步节点还没有类型，留了口子
   （_is_mandatory_node）；约束实际落在 M3-3c：被吸收的路线节点不许分配成必须型

7. 候选边：同环挨着的两个点 → tangential，中间可以隔至多 tangential_span_max 个空槽（5.4.1 的 `1----1`），
   隔得更远就是空白区、弧断开；向内一环里【边长上限之内】最近的 radial_links 个 → radial。
   正对着空白区的点因此可以**没有**向内的边，它靠同环的弧连到别处

7b. 高危区生长树：区是沿「空间相邻」长的，候选边却是另一套规则建的，
    两者对不上时区内根本没边相连。所以生长时走过的每一步都记下来，在这里补成真的边并保护 ——
    区内别的边照样可断，但生长树断了区就散成几片。岔出来的那条边同样补上并保护：
    它是天然的第一个出入口

8. 高危区隔离：跨区边界的边只留几条当出入口，其余删掉。留几条 = 1 到「这个规模允许的上限」
   之间随机；已受保护的跨界边（岔出来的那条、被吸收的路线节点原本的路线边）必须留；
   再添的话**挑区内那一头离已有出入口最远的**（只沿区内的路数步数）——
   多个口挤在一起和一个口没区别；剩下的候选都和已有的口在同一个点上就不添了

8b. 补向内的边：区外的点如果向内的边全通进了高危区，隔离时就一并删光了。
    在边长上限之内给它重连一条通向【区外】内环点的边；够不着就算了，交给同环的弧

8c. 救孤点：隔离之后一条边都不剩的点（邻居全在高危区里）。旁边有区外的点就连过去；
    真被围死了就划进那片区（没超 max_size 的话）—— 只能穿过高危区才到得了的点，本来就是它的一部分

9. 断边：每条 tangential 候选边以 tangential_break_chance 断开。**骨架边不可断，也不许断出孤岛**：
   边有了长度上限之后，连通性不能再指望「每个点都有向内的径向边」兜底，
   所以每断一条之前先看两头还连不连得上，连不上就留着。
   区内的边也可断 —— 区内断成死胡同没关系，走回头路就是

10. 校验（失败换种子重生成，上限 32 次；用尽则报错返回 null，不降级产出坏图）：
    - 全图连通：每个节点都从至少一个入口可达
    - 【槽位数】随环单调不增。看的是槽位不是节点数 —— 外环挖了一段空白之后，
      它的节点可以比内环还少，那是合法的
    - 单条路径的长度上限：每条边的环位偏移 ≤ edge_max_ring_offset、槽位偏移 ≤ edge_max_slot_offset
    - （**路线不查**：骨架完整、换乘点、路线风险收益都是生成规则，生成器自己保证或尽力，
      不是一张图合不合格的条件）
    - 【必须有】的高危区（required 且环数够 min_rings）得岔出来。没岔出来算这一次尝试失败，
      不是悄悄少一片；【可选】的就跳过，记进 layout_meta.zones_skipped
    - 出生点两两间隔 ≥ entry_min_gap
    - 覆盖：高危区外的每个节点距最近 rest ≤ coverage.rest、距最近 shop ≤ coverage.shop
    - 环配额成立；喘气型不在 danger > no_haven_in_danger_above 的区域里；no_adjacent 成立；
      高危区里 elite ≥ min_elites、search ≥ min_search
      （以上规则从 layout_meta.type_rules 读，手绘图没有这一项就一条不查）
    - 每个高危区（ZoneRules，从图上读）：点数在 [min_size, max_size]、区内连通、
      出入口【节点】数在 1 ～ max_gates_for(点数) 之间
    - 撤离环间里至少一个 extract，环间之外只有核心前一环有（`extract_band`）；撤离点两两之间最短路 ≥ extract_gap
    - 节点总数落在规模模板给这个环数的范围里；**每环 节点/槽位 ≤ fill_cap（< 1），内环也不填满**
    - 出生点都是 spawn、spawn 都是出生点
```

一个环生成出来**可以断成两段、三段，甚至有一整段空白**：切向边按概率断、空白区本来就没节点，
再加上高危区隔离，一环之内的几段各自靠径向边连到别的环。这是参照示意图想要的样子 ——
「每环都可以互通」指的是**每一段都从别处到得了**，不是环自己首尾相连。

**校验里没有「每个 erosion_band 内部连通」。** 侵蚀绝不封路（5.7），
被侵蚀的节点照样能走，只是有代价 —— 所以幸存区被切成几片不会困住玩家，
只是从一片到另一片要穿过侵蚀区多付一点。那正是侵蚀该有的压力，不是要避免的坏图。

**高危区的意义**是把「诱惑」做成拓扑：一片只靠少数几个出入口与外界相连的区域，
里面有精英守着、有好几个搜索点。玩家看得见入口，看得见里面有什么类型的点，
然后自己决定值不值。定义与生长方式见 5.5「高危区」。

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

**实现落地后补的几条**（报告 037）：

- 岔路口自己就是一格 `-`，所以它和**紧挨着**的点之间不需要再隔一格 `-`：`A-V` 的 `-` 上落了 `|`，
  就是 A—岔—V 三个点连成一串。作者两张图的第一行第二格就是这样，漏了这条整张图是散的。
- 没有 `[map]` 段头的是 v0 老格式：`E` 是终点、`2` 是「高危的缺省点」。有段头的按节点类型表来。
  同一种类型的另一种写法记在 `layout.symbol` 里，导出时原样写回。
- `|` 出现在环行里（不是连接层）= 这条径向边从这一环**穿过去**。
- 底色刷在 `-` 上没有意义，但原稿存进 `layout_meta.danger_rows`，导出时节点那一格以节点为准、
  其余照原稿 —— 否则往返对不上。
- 出生点的符号暂定 `P`（解析成 `spawn`）。一个都没画时按占位规则：最外环上每一段弧的第一个点。
- 解析出来的图 `layout_kind = "grid_script"`，与生成器 id 同名 —— 编辑器靠它找到校验者与布局。
- **`[links]` 段**：随机生成的图导出时，两端不同列的径向边画不成 `|`，逐条列在这里
  （`行,列~行,列`），解析时照样连上。手绘的图用不到它。所以导出是**不丢信息的**，
  但同心环图的文本读起来没有手绘图直观 —— 大半的径向边都在 `[links]` 里。

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

- 相邻路线之间有**换乘**（次数随规模，5.4.3）：两条路线的点相邻就直接连一条边，碰不上才拉换乘弧。
  没有换乘点，风格就成了开局定终身，那不是取舍，是抽签。
- 偏搜索路线 `ends_at = "extract"`：末端是撤离点，在核心之前一环结束。想打 BOSS 就换乘。
- 中途撤离点在**撤离环间**（正中间的一两环），放在两条路线共用的地方 —— 换乘点、换乘弧、合流点 ——
  偏战斗的路线走到半程，出口就在换乘的地方。撤离点仍然覆盖非必须型节点（不吃掉休息区与商店）。
- 路线的长度 = 环数 × `route_length_factor`（1.5）：多出来的步数是同环横着走，随机撒在各环上。
  路线长一点，沿路才放得下休息区、商店与撤离点。

tier 不进公式 —— 各路线各环各过一次，对称。高危区不在路线上，它的风险与收益都不计入：
那是玩家自己选的加码。

**出生点。** 每个出生点对应一条路线，开局由玩家挑。挑的依据就是 `graph.routes` 里那一份：
风格、尽头（打 BOSS 还是撤离点）、风险与收益的档位 —— 以及沿途的敌人（5.10，
敌人的属性与背包在地图上看得见）。所以「偏战斗还是偏搜索」不是生成器抽签替玩家定的，
是玩家看过地图之后自己选的；选了也不锁死，换乘点还在。

**手绘地图怎么办。** 手绘图没有显式路线，解析后按「入口到核心的最短路」推几条出来，
只用于 HUD 与校验告警（覆盖不达标、路线分差太大都告警不拒绝）。作者画的图作者负责。

#### 不交叉

两条路在图上交叉，玩家看到的是一个十字，分不清那是路口还是两条互不相干的路叠在一起。
所以**生成时不许交叉**，校验也查（`edge_crossing`，环形图自己的规矩）。
只有一种交叉说得清：**四个点两两相连** —— 那是一个四岔路口（渲染见 5.9）。

斜着走一步（环偏移与槽位偏移都不为 0）时，拦在中间的只可能是另一条对角线 q–u：
q 是出发点同环、朝目的点那一侧的邻居，u 是目的点同环、朝出发点那一侧的邻居。
q、u 都在且相连，就按顺序试（`RingMapGenerator._link`）：

1. q、u 各自的路都不到 3 条 → 把四个点连满，成一个四岔路口（六条边全部受保护，少一条就又成了交叉）；
2. 否则轮流看 q、u 谁的路不到 4 条 → **借道**：出发点–x、x–目的点两条路代替那条斜路；
3. 都不行 → 连不上，调用方换别的落点。

高危区的路不许借道也不许凑四岔（借来的点不在区里，区就断了），所以高危区**每长一步当场建路**，
会交叉的那一步不走、换个方向 —— 区是沿着真的路长出来的，不是先圈地再补路。

交叉按几何算（第 r 环半径 r，角度 = 槽位 / 槽位数，线段相交）。第一版只比「外环上的先后与内环上的先后
是否相反」，环上正对面的两条路先后本身是含糊的，被大量误判成交叉。
收尾有一步 `_fix_crossings`：隔离高危区、断边可能拆掉四岔的某条边，剩下两条对角线成了真交叉，拆掉一条。
另有 `_reconnect_islands`：候选边因为让路少连了几条，偶尔让一小撮点脱离主图，从主图一轮一轮接回去。

#### 5.4.3 规模模板

出发点数量、高危区数量、高危区规模都**可以挑，但各有上限，上限随地图规模变**。
这些上限是数据（`MapScaleProfile`），加一种规模是加一条记录，不是改生成器。

```gdscript
# core/map/generators/map_scale_profile.gd
class_name MapScaleProfile extends Resource
@export var id: StringName
@export var display_name: String
@export var rings: Vector2i           # 这种规模覆盖的环数 [min, max]
@export var entries: Vector2i         # 出发点数量 [min, max]
@export var zones: Vector2i           # 高危区数量 [min, max]；min 必须有，多出来的长不成就算了
@export var zones_per_route: int = 1  # 每条路线身上最多岔出几片
@export var zone_size: Vector2i       # 高危区软上限的可选范围；不指定时用 max
@export var pivots: Vector2i          # 相邻路线之间换乘几次 [min, max]；图越大机会越多
@export var placeholder: bool         # true = 数值还没定，只是占位；界面上会标出来
```

| 规模 | 环数 | 节点数 | 出发点 | 高危区 | 每条路线 | 高危区规模 | 换乘 | 撤离点间距 | |
|---|---|---|---|---|---|---|---|---|---|
| 小型 | 4~5 | 4 环 25~30、5 环 35~40 | 2~3 | **有且只有 1 片** | ≤ 1 | 3~4 | 1 次 | 3 步 | 高危区、换乘、节点数是作者给的。间距 3：撤离环间离收尾撤离点只有一两环，4 会把整条环间排除 |
| 中型 | 6~8 | 6 环 45~50、7 环 58~66、8 环 74~84 | 3~4 | 1~3 片 | ≤ 1 | 3~6 | 1~2 次 | 4 步 | 6 环的节点数、片数、换乘是作者给的，其余是我填的 |
| 大型 | 9~12 | 9 环 86~100 … 12 环 149~174 | 3~4 | 1~4 片 | ≤ 1 | 3~9 | 2~3 次 | 5 步 | **占位**。按六成填充推的 |

**节点数由规模决定，是范围不是定数；槽位数不动。** 槽位是几何（环的长度按半径算，5.4 步骤 3；
**中环 = 撤离环间再加 `mid_ring_extra_slots`（3）个**，内环只有 `min_slots` 个槽位放不下，多出来的落在中环），
节点数是内容：模板按环数给范围（`nodes_by_rings`），**每一局在范围里抽一个总数**，各环按配置里的基准比例分
（`counts_for_total`：作者把某一环写密一点，缩放之后它还是密的）。配置里写的 `node_count` 是范围中点：
二分一个填充系数，让各环 `fill_count(slots, 系数)` 的总和正好是中点；
`fill_count` 把每环夹在 `[min_slots - 1, floor(slots × fill_cap)]` 里 —— **`fill_cap` 严格小于 1，
内环也不填满，环上总有空位**。范围对着槽位数定，填充率六到七成：4 环 40 个槽位放 25~30、6 环 75 个放 45~50、
8 环 122 个放 74~84。太满没有空白区，太空路线找不到落点。
图上的点数写进 `type_rules.node_range`、填充率写进 `layout_meta.fill_cap`，都进校验。

新建的环（换规模、换环数）从 `RingMapConfig.ring_template` 抄 `quota` 与 `type_weights`。
没有它，换一次规模之后每环的权重表是空的，非路线的节点就只剩战斗 —— 编辑器里正是这样暴露的。

> 第一版做成了缩槽位（6 环 14/11/9/6/6/6），作者指正：不是降低槽位，是降低最后生成的节点数。
> 槽位少了环就「变短」，那是改几何；节点少了是环上稀疏，两者画出来不一样。

**撤离点之间的最短路至少 `extract_gap` 步**（`RingMapConfig.extract_min_distance` 可以覆盖，-1 = 用模板的）。
挨得太近的两个出口等于一个。放撤离点时挑离已有撤离点最远的候选。
间距得对着撤离环间的位置定：小型图的环间离收尾撤离点（核心前一环）只有一两环，间距 4 会把整条环间排除掉。

**喘气处放在路线的几分之几处**（`haven_at`）：中型休息区 1/3、商店 2/3；小型两个都在一半，位置撞上就挨着放。
按路线上的步数算，不看环。

`RingMapConfig.scale()` 按环数匹配；一档都不匹配（三环的测试图）= 不设上限、没有高危区。
`entry_count` / `zone_count` / `zone_soft_cap` 是作者或玩家挑的值，用之前都会被夹进这一档的范围
（`effective_entry_count()` 等）；后两个填 -1 表示「交给生成器」。

必须有的那几片（`zones.x`）没凑齐 → 这一次尝试作废；想多要但没长成的 → 记进
`layout_meta.zones_skipped`。每条路线身上岔出了哪几片记在路线标注的 `zone_ids` 里 ——
开局挑出生点时，这是玩家想知道的事。两片高危区之间不直接开口（那条边两边各算一个出入口）。

**编辑器从规模选起**：左栏最上面是规模下拉 + 环数 / 出发点 / 高危区数量 / 高危区规模四个旋钮，
范围来自当前这一档模板；换规模时几个值自动夹进新范围。编辑器靠鸭子类型认这件事
（配置有 `apply_scale` 就有这块面板），不支持规模的生成器（手绘地图）这块就是空的。
下面照旧是反射出来的全部参数。这一版只做到「灵活、兼容」：规模模板本身也在全部参数里，可以直接改。

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

随机生成器只造高危区；中危区目前只在手绘图里出现，
要不要随机生成、按什么规则，等有了第一版手感再说。

#### 高危区

**长成什么样才算数**（`ZoneRules`，图自身的性质，进校验，手绘的图也要守）：

1. 至少 3 个相连的点，可以跨越多层环；上限 9 个。
2. 出入口的上限随规模放宽：3~4 个点至多 2 个，5~6 至多 3 个，7~9 至多 4 个。
   出入口 = 跨越区域边界的一条路；`graph.zones[id].gate_ids` 记的是它们在区内的那一头。
3. 有多个出入口时，尽可能让它们在区内相距最远（这条是生成时尽力，不进校验）。

**怎么长出来**（`DangerZoneSpec`，生成规则，不进校验）：高危区的生成同样视为一个起点的生长。
某条路线走过半程、旁边空间充足时，从那个路线节点上岔出一个新起点并立刻推算一次（于是至少两个点），
之后与各条路线同一个节拍生长，直到软上限（由地图规模决定，见 5.4.3；小型 4~5 环地图是 4 个点）
或周围没有空间。若此时只有两个点，就把原本连接它的那个路线节点也变成高危区 ——
即使这让 3 个点的小区有两个出入口。

早先的定义（v1.21 起）是「单入口、避开骨架、落在指定环范围内」。单入口让大一点的区变成
纯粹的死胡同，进出都走同一条路、行动点花两遍，规模一大就没人愿意进；
事后圈地则要和换乘弧抢位置，四环图上平均要重试五次。现在这两件事都没了：
640 张图（4~8 环各 128 个种子）全部第一次尝试就成。

节点类型的硬约束（5.4 步骤 5 与校验）：

- 核心节点固定为 `core`（章节 Boss）
- 休息区与商店满足**步数覆盖**（`coverage`），不是「每 N 环一个」
- 每环每类落在 `quota` 的 `[min, max]` 内
- 高危区内满足 `min_elites` / `min_search`
- 撤离环间里至少一个撤离点，环间之外只有核心前一环有

各路线的风险分与收益分落在其风格区间内、收益/风险之比差不超过 `ev_tolerance` ——
这些是**路线**的事，生成时尽力（5.4 步骤 5g），不进校验（035）。

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

这五步落在 **`core/run/map_travel.gd`（`MapTravel`）** 一处：`step_to(to_id)` 造一个 step 意图交给
`apply(intent)`，`apply` 是唯一会改地图状态的入口 —— 将来传送、定点移动造好自己的意图之后也走它，
顺序、计数、惩罚、事件一处都不用改。侵蚀与节点事件都是**鸭子类型的钩子**，`MapTravel` 不认识它们的类：

- `erosion`：有 `on_action(clock, graph)` 与 `move_penalty(node) -> {hp_damage, item_risk}` 就行；
  浅层惩罚扣在 `vitality` 上（7.1）。第 7 阶段之前是 null，但**顺序现在就定死**，测试用一个假钩子记调用次序守着。
- `on_node_event: Callable(node)`：设了它，节点什么时候算「用过」由它说（战斗打完才 `mark_visited`）；
  没设，到点即标 `VISITED` —— M4 之前的占位。
- 出生点开局就算踩过了（`start_at`），它不该再触发一次事件。走不了的一律发 `refused(intent, why)`，
  原因说得出：不相邻、意图过期（它以为人在别处）、还不认识的移动方式（`teleport` 不是当 `step` 走）。
- 存档：`{current, history, clock}`；图另存。

**侵蚀推进必须早于目的地惩罚结算。** 顺序反了，玩家走进一个刚好在这一步被侵蚀的节点却不受任何惩罚，预警倒计时的最后一步就失去意义。

#### 为未来的移动机制预留接口

传送、定点移动等属于**扩展机制**，底层不能把"一次移动 = 走一条边"这个假设写死。**传送点在 8-1 落地**（报告 076）：`MapEdge.kind == "portal"` 的边解析成 `MoveIntent.TELEPORT`，花边上说的行动点、不经过途中；生成器按 `RingMapConfig.portal_count / portal_cost / portal_min_steps` 连，校验 / 求解 / 路口都先剔掉它（它不是路），编辑器能手连。因此所有移动统一经过一个意图对象：

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

**落地于 075（第 7 阶段）：是某档进阶难度开的机制（8.4），普通难度没有。** 在高难度下，地图从**最外环开始逐层向内被侵蚀**。被侵蚀区域仍可通行，但在其中移动会受到损失。这把"可以走回头路"从一个无代价的自由，变成一个持续加压的风险决策。

#### 拓扑无关的实现

`ErosionField`（`core/run/erosion/erosion_field.gd`）**只认 `MapNode.erosion_band`，完全不知道"环"的存在**。任何未来的地图形态只要给节点标好 band，就能直接复用整套侵蚀系统。

**落地的形状（075）**：时间表在难度清单里的 `ErosionMechanic`（第几个行动点开始、每隔几个推进一层、预警提前量、效果清单），一局里的状态在 `ErosionField`
（侵蚀了几档、下一次在第几个行动点，跟存档）。**效果是构件** `ErosionEffect`（登记表 `EROSION_EFFECTS`：扣体力、损坏一件、丢钱……），
作者要求每种效果都能开关、能调，所以基类自带四道门：`enabled`、`from_depth`（被侵蚀至少几层才生效）、`only_total`（仅终局）、`chance`（每次结算的概率），
`applies(ctx)` 一处判，子类只写 `apply`。下面的代码是当初的设想，字段名与落地的一一对应：

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

#### 损失的形式（已落地：效果构件，作者按门配）

推荐分层设计（占位数据 `ascension_1` 就是这么配的）：

- **浅层侵蚀**：在侵蚀区内每次移动扣**体力**（7.1），扣多少由 `ErosionSchedule` 给 —— 和别处一样，`Vitality` 不知道数
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

**画布与视口分开。** 布局按**固定环距**（`RING_STEP` = 110 像素）算出画布大小，不随视口缩放 ——
六环的图就是比四环大一圈，而不是六环挤在四环的地方。看不全靠 `MapView` 的拖动（中键）与缩放
（滚轮，围着鼠标缩；`fit()` 缩到刚好放下、只缩不放；`1` 回原比例）。坐标分两套：布局给的是画布坐标，
所有命中测试与信号都用它；屏幕坐标只在输入处理里出现一次。

**岔路口**（`core/map/map_junctions.gd`，纯拓扑）：四个点两两相连画成**四岔路口**，三个点两两相连画成
**三岔路口** —— 中心一个小点，向每个成员伸一条腿，被路口占用的边不再单独画线。
数据层照旧只记「谁和谁相连」，这只是画法。顺序：**先四岔后三岔**（一条边只归一个路口，四岔占过的边三岔不再用），
同一档里**由内向外**（tier 高的先）。路口在所有单条的边之后画。
编辑器里有开关可以关掉，核对数据时每条边一条线。


```gdscript
# ui/map/map_layout.gd —— 布局策略的根，按 graph.layout_kind 从 LAYOUTS 表取
class_name MapLayout extends RefCounted
func canvas_size(graph) -> Vector2                  # 固定间距算出来的画布，不随视口缩
func positions(graph, rect) -> Dictionary           # id → 画布坐标
func draw_edge(canvas, graph, edge, a, b, color, width)   # 默认直线
func warnings(graph) -> Array[String]

# ui/map/ring_layout_base.gd —— 同心环这一族（随机生成的、手绘的）共用：
#   子类只回答 levels_of / fractions_of / level_count（层 = 0 圆心，圈上的位置 0～1），
#   角度交给 RingAngleSolver，按 graph.version 缓存 —— 图没变就不重解
#   draw_edge：同层 → 沿圆弧采样用 draw_polyline 画弧（画直线会破坏同心环的视觉语言）；
#              跨层 → 直线，求解之后它本来就是径向的
# ui/map/ring_angle_solver.gd —— 见下
# ui/map/ring_map_layout.gd / grid_map_layout.gd —— 只翻译 ring/order、row/col
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

> 已落地（报告 044），**解法换成了松弛**而不是上面写的逐层贪心：最外层按位置钉死，里面每个有径向边的点
> 反复取径向邻居角度的圆周均值（四百轮），每轮之后按圈上的次序整理一遍（同层的点不许越过彼此、
> 不许挤到一起，挤到一起的两个各让一半）。一条链就整条垂直；一个点接着两个外层点就落在它们中间并告警。
> 逐层贪心在随机生成的图上会把整层的点顺着推到一边（每个点向内连一两条，「一点接着两个外层点」是常态，
> 均值一层层叠下去，图就歪了）。求解器的输入是形态无关的「层 + 圈上的位置」，同心环图与手绘图各自翻译。
> **两种图的目标不一样**：手绘图的 `|` 就该竖直，`anchor` = 0，简单的链解得精确；随机生成的图每个点向内
> 连一两条 ±1 槽位的斜边是本意（5.4「不交叉」），硬拉直会把点挤成一团，所以每个点留三成半的力往名义位置拉
> （`anchor` = 0.35），只把径向边往竖直方向带一带 —— 十二个种子平均总偏差降到名义的七成，从不更歪。
> 没有随机，解两次逐位相同。抖动还没加。

`MapView` 根据 `graph.layout_kind` 从注册表取对应策略，其余逻辑（节点按钮、路径预览、点击导航、镜头平移缩放）完全共享。

必须呈现的视觉状态：

| 状态 | 表现 |
|---|---|
| `UNVISITED` | 正常亮度，按类型显示图标 |
| `VISITED` | 图标去饱和变灰，但**保持可点击、连线保持清晰** —— 必须与"不可通行"有明显区分（已做） |
| 当前节点 | 高亮描边 + 呼吸动画（已做）；这一步能走到的点画一圈提示 |
| 已侵蚀区域 | 红紫色 overlay + 噪点 shader，band 边界做渐变过渡 |
| 预警中的区域 | 边界闪烁 + 倒计时标签 |
| 核心点 | 红色，始终可见，作为玩家的方向锚点（已做，永远不灰） |
| 有内容可看 | 节点左上一个小点，`random` 与结构性节点（出生点 / 撤离点 / 核心）没有 —— `random` 是地图上唯一看不透的点（标记位，内容归 M4） |

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

M4-1 落地的形态（6.0）：`EnemyDef` **不带固定棋盘** —— 棋盘按「通用道具 + 流派道具」的规则在生成地图时组装，
件数由强度档位定，结果写进 `MapNode.content`（敌人 id、档位、棋盘尺寸、每件道具的位置与朝向）。
`EnemyKit.spec_of(content)` 把它重建成棋盘再编译，沙盒悬停看到的生命 / DPS / 件数就是这么来的；
`EnemyKit.board_of(content)` 重建出来的棋盘直接是 6.1 的尸体容器。
`battle_sandbox.gd` 里的训练假人仍是手搓的 `CombatantSpec`，是 M2 的权宜。

**能看多远**：底层规则是全图可见。战争迷雾、侦察范围之类属于扩展机制，不实现，
接缝留在 `MapView` 的「这个节点的内容给不给看」一处判断上（沙盒里是 `enemy_preview(id)` 这一个方法）。

### 5.11 格阵形态：沙漏与塔（8-2，报告 078）

第二章的两个底层模板，作者定的：**横置的沙漏**（`hourglass`，像蝴蝶结：左右两块对称的长方形、中间收紧成两条平行线段；出生在左，**撤离点在对侧**，核心不是必须的，中途没有撤离点）与**等腰三角形的塔**（`tower`：横向的层，**登上一层就不能向下**，同层自由横走、纵向单向）。
两者都是**分层格阵**：从出生那一层一层层走向终点那一层，每层若干格；差别只在形状（每层有哪些格、哪几层不许横着走）。
所以形状单独描述（`LatticeShape`：每层的格、直上层、终点那一层放什么 `goals`（格 → 类型，核心不是必须）、横着画还是竖着画 `orientation`；由配置算出、不进管线），铺点 / 连边 / 断边 / 定类型 / 校验只在 `LatticeMapGenerator` 里写一遍，
两个模板各自只回答「形状长什么样」（`HourglassMapConfig` / `TowerMapConfig` → `shape()`）。这是 5.1「可插拔」的第二次兑现、第一次真的换形状：
数据层、导航、旅程、侵蚀、`MapView` 主体、存档一个字没改；注册表（`MapGeneratorRegistry`、`MapLayout.LAYOUTS`）各加两行，编辑器的下拉就有了。

- **铺点**：每层按填充率挑格子；第 0 层、最后一层、直上层、直上层两头的层全填（两头那层不对着线段的点靠横边走到线段口）。
- **连边 / 断边**：层间列差 ≤ `forward_reach` 的先连上（直上层进出只许列差 0），同层邻格连横边；按概率断，守住「每个点向上至少一条、向下至少一条」，
  受保护的横边不断 —— 全图连通与「单向也到得了终点」都由这条不变式给出。
- **分档**：`tier` = 层号；侵蚀分档默认也是层号，`erosion_reversed` 从终点那头侵蚀；`danger_by_row` 按层给危险等级（没有片状高危区的生长）。
- **类型**（`LatticeTypeAssigner` / `LatticeTypeRules`）：spawn / core 固定 → 中途撤离点落在 `extract_rows`、两两够远 → 权重 → 每层配额 → 覆盖 → 不许相邻。
  规则写进 `layout_meta.type_rules`，校验从图上读。**没有路线**（格阵的路线是玩家走出来的），所以没有风格与校准。
- **校验**：点在格子里、边只连相邻层或同层邻格、直上层不横连、分档 = 层号、方向和「不回头」对得上；**单向的图每个点都走得到终点**（`goal_from_all`）是合格条件。
- **不回头**（塔的定义，作者定的）：`one_way` 默认开着，层间的路单向（`MapEdge.directed`，从 `one_way_from_floor` 起），同层照旧；导航与旅程早就认单向边。
  回不去的楼层怎么侵蚀、撤离点怎么放，还没有作者的话，先按通用的。
- **布局** `LatticeMapLayout`：按 `orientation` 竖着叠（塔：出生在底、终点在顶）或横着排（沙漏：出生在左、对侧在右）；格是绝对列；空格子画淡点可加点；单向的路带箭头；层距和环距一样宽（猎手的绝对距离一把尺）。

---

## 6. M4 · 节点内容：敌人、搜刮与掉落

M4 分四步（报告 045）：敌人池（6.0）→ 掉落与尸体容器（6.1）→ 随机点与搜索点（6.2 / 6.3）→ 节点事件接线（7.1）。

### 6.0 敌人池

作者的要求：敌人类型要丰富（高伤低频、低伤高频、混伤、流血……），有强度档位（受道具数量影响），
敌人池持有一张配置表（名称、强度、流派标签可多个），按地图类型 / 难度 / 规模配置，道具按「通用 + 流派」组装。

```gdscript
# core/enemies/ —— 作者数据，走内容管线（10 节）
class_name EnemyDef extends Resource            # data/authoring/enemies/*.json
@export var id: StringName
@export var display_name: String
@export var strength: int                         # 本色档位：池按「想要的档位」在容差内挑本色接近的
@export var schools: Array[StringName]            # 流派标签，可多个。混伤 = 同时带两个流派，不是第四种流派
@export var base_stats: Dictionary                # 基线覆盖（max_hp、armor…），没写的用 CombatantBaseline 默认
@export var signature: Array[StringName]          # 招牌道具，一定背着（屠夫总带着刀）
@export var loadout: EnemyLoadout                 # 覆盖池的默认组装规则；null = 用池的
@export var board: Vector2i                       # 覆盖档位表的棋盘；零 = 用档位表的

class_name EnemyPool extends Resource             # data/authoring/enemy_pools/*.json，章节按 id 引用
@export var entries: Array[EnemyPoolEntry]        # {enemy, weight, kinds, node_types, min_danger}
@export var tiers: Array[StrengthTier]            # 档位表：{strength, item_count, board, stat_scale, rarity_cap}
@export var strength_rule: StrengthRule           # 节点 → 想要几档
@export var loadout: EnemyLoadout                 # 默认组装规则：{common_tags, school_share, min_school, rarity_cap, allow_repeat}
@export var combat_types: Array[StringName]       # 哪些节点类型放敌人：battle / elite / core（random 不在：踩上去才知道）
```

**流派是标签。** 道具按 `ItemDef.tags` 里带没带流派名归到流派里（`burst` 狙击枪 / 撬棍 / 霰弹枪，
`rapid` 手枪 / 步枪 / 冲锋枪 / 匕首，`bleed` 匕首 / 剁刀）。新增一种流派 = 给几件道具打标签 + 写一个带这个标签的敌人。
导入器要求每个流派至少有一件道具带它。

**强度 = 档位 = 道具数量。** 档位表每行：背几件、棋盘多大、基线乘多少、稀有度上限（外环小兵不背传说品）。
敌人定义只写本色档位；实际用哪档组装记在节点内容里 —— 同一个拾荒者在外环背两件、在高危区里背五件。

**哪个点该多强，全是加法**（`StrengthRule.wanted`）：
`by_depth`（最外 → 最内，按 tier 在全图里的位置插值，形态无关）+ `danger × danger_bonus`（5.5）
+ `type_bonus[类型]`（精英、核心）+ `difficulty × difficulty_bonus`（`ChapterDef.difficulty`）+ `by_scale[规模 id]`，
夹进档位表的范围。地图类型的过滤在条目的 `kinds`：环的种类（`RingSpec.kind`，生成器写进节点 `layout.kind`）。

**探索度**（作者：随机点与搜索点造出来的敌人要跟当前位置、总步数、搜索次数挂钩）：`StrengthRule` 多一组
`steps_per_tier` / `steps_max_bonus` / `searches_per_tier` / `searches_max_bonus` —— 总步数每 N 步加一档、本局累计搜索次数
（含正在搜的这一次）每 N 次加一档，各有上限。**只对踩上去才造的敌人生效**（`NodeEvents.exploration()` 传进去）：
地图上看得见的敌人生成时就定了，不随探索变 —— 看到的就是打到的。当前位置本来就在深度与危险里。

**放敌人是生成之后的第二遍**（`EnemyPlacer.fill`），生成器不认识敌人。对每个 `combat_types` 里的点：
算档位 → `fits(node)` 过滤 + 容差内取（没有就取最近）→ 按权重抽 → 组装：招牌先占位，`school_share` 的份额从流派池抽
（至少 `min_school` 件），其余从通用池抽（带 `common_tags` 且不带本敌人流派标签），大件先摆，放不下换一件从小到大补。
随机数只用节点的 `content_seed`：同图同点永远同一个敌人。

内容字典跟着图存：`{"enemy", "strength", "board": [w, h], "items": [{"id", "at": [x, y], "rot"}]}`。
`EnemyKit` 把它重建成棋盘、走 `BattleCompiler` 编译（预览 = 编译，5.10）、给一行摘要。

导入顺序：items → enemies（招牌道具、流派标签对着道具查）→ enemy_pools（条目对着敌人查）→ chapters（池按 id 查）。
「对着别的东西查」的校验只在批量导入时生效 —— 单独导一个敌人时上下文是空的，无从判断。

### 6.1 掉落规则（M4-2）

作者的设想：敌人的每件道具都有一定概率掉落，稀有度越高基础掉落率越低，受难度（正面）、幸运值（增益 / 减益）、
局外 buff（占位）、地图 buff（占位）修正；每个敌人都有概率掉一件自身未持有的高稀有度「珍宝」（红、金两档，珍宝类型未细定）。

```gdscript
# core/loot/drop_rule.gd —— data/authoring/drop_rules/*.json，章节按 id 引用（ChapterDef.drop_rule）
class_name DropRule extends Resource
@export var base_chance: Array[float]        # 稀有度 → 基础掉落率，非递增（导入器校验：越稀有越难掉）
@export var difficulty_bonus: float          # 难度每 +1 加多少（只做正面加成）
@export var luck_bonus: float                # 幸运每一点加多少，幸运可负
@export var treasure_chance: float           # 每次尝试掉一件珍宝的概率；尝试次数 = LootContext.rolls
@export var treasure_weights: Dictionary     # 珍宝稀有度 → 权重，{"3": 3, "4": 1}：金、红
@export var treasure_tag: StringName         # 哪些道具算珍宝（占位：`treasure`）
@export var treasure_modified: bool          # 珍宝概率也吃修正
```

**每件各掷一次**（`DropResolver.owned_chance`）：`base_chance[稀有度] + difficulty × difficulty_bonus + luck × luck_bonus
+ drop_owned_chance（道具 / 套装的战利品效果）+ Σ 来源`，夹进 0～1。修正全是加法、同一个单位，调一个数看得清另一个。

**珍宝**：`rolls` 次尝试，每次按 `treasure_chance` 掷；中了按权重（+ `rarity_bias`）抽稀有度，在「带珍宝标签、这个稀有度、
敌人**没有**」的道具里抽一件（`category_bias` 加权）。哪一档都没有（珍宝还没定义）就记一笔，不掉、不报错。

**修正的来源**是接口不是字段（`DropBonusSource`：`owned_bonus(ctx, def)` / `treasure_bonus(ctx)`），
`LootContext.sources` 装它们。**062 之后局外 / 地图 buff 不走这条缝**：buff 的 `LootEffect` 直接施加到掉落上下文上、幸运从 buff 的 `RunEffect` 来（`RunState._loot_context`，
道具与套装的战利品效果也在那里施加）。`MetaDropBonus`（局外）与 `MapDropBonus`（地图）是两个占位实现，只剩沙盒的预览还用，待清理；现在都加 0，
`DropResolver` 现在就调它们 —— 接上的那天规则与测试一行不改。难度与幸运是 `LootContext` 自带的两个数，谁填是 run 层的事。

M2 定下的四个量各有归宿：`rolls` = 珍宝尝试次数，`rarity_bias` = 珍宝稀有度权重偏移，`category_bias` = 珍宝候选加权，
`drop_owned_chance` = 自身道具概率加成。

**尸体容器就是一个 `GridInventory`**（`DropResolver.corpse_of`）：大小照敌人的棋盘（6.0 档位表给的），
掉下来的 + 珍宝 `try_add` 进去，塞不下就加高。这里完全复用 M1 的代码，零额外成本 —— 这正是 3.2 节强调容器复用的原因。

### 6.2 搜索点与随机点（M4-3）

规则在 `NodeRules`（章节按 id 引用，`ChapterDef.node_rules`）里，导入器把作者的规矩写成校验：

```gdscript
# core/run/node_rules.gd —— data/authoring/node_rules/*.json
class_name NodeRules extends Resource
@export var random_weights: Dictionary      # 随机点变什么：只认 battle / search / shop / rest / event，不会变成精英或 BOSS（5.4）
@export var search: SearchRules             # 见下
@export var loss_cost: Dictionary           # 战斗输了扣多少体力：类型 → 数。core 不在这里：BOSS 输了直接战败（7.1）
@export var rest_restore: int               # 休息区回多少
@export var event_weights: Dictionary       # 常规事件的结果：item / restore / story（占位）
@export var battle_time_limit: float        # 打不死判平局，平局按输算

class_name SearchRules extends Resource
@export var max_searches: int               # 至多搜几次
@export var encounter_curve: Array[float]   # 第 k 次的遭遇概率，非递减：每搜一次该更险
@export var items_per_search: Vector2i      # 每次找几件
@export var rarity_weights: Array[float]    # 稀有度权重，× (1 + depth_gain × 深度 × 稀有度) × (1 + danger_gain × 危险 × 稀有度)
@export var exclude_tags: Array[StringName] # 搜不出来的（珍宝只从敌人身上掉）
@export var haul_board: Vector2i            # 收获摆进多大的容器
```

**随机点**（`?`）生成时内容是空的，踩上去 `NodeEvents.reveal` 按权重抽一种类型记进 `content.resolved_type`，
再当那种类型处理；是战斗就用 `EnemyPlacer.place_one` 现造敌人。随机数由节点 `content_seed` 派生：同一局同一个点揭开的一样，只是事先看不见。

**搜索点**是 `SearchSession`：搜几次是玩家的旋钮（5.4.2）。每搜一次先找几件（稀有度随深度与危险上偏），
再按曲线掷遭遇 —— 中了才由敌人池按 `search` 类型出人（搜索点的敌人**看不见**，5.10：不预先造，存档里也没有），
打完这一场搜索到此为止；没中可以继续，搜满或随时 `leave()`。搜过几次记进 `node.content["searches"]`，读档接着搜。
遭遇的敌人与随机点揭成的战斗一样按**探索度**抬档（6.0：总步数、累计搜索次数）：走得越远、搜得越多，撞上的越强。
收获摆进 `LootPacker` 的容器，与尸体容器同一套（6.1）。

#### 渐进揭示的搜刮界面（表现层，M6-2）

三角洲行动式搜刮的手感核心是**"看得见轮廓、看不清是什么"**。落地在 `LootView`（`ui/game/loot_view.gd`，一个 `InventoryView` 的子类）：

- **揭没揭示是表现层的事**：容器里的东西一开始就在那儿（`GridInventory`），揭不揭示都一样，所以 `revealed` 不在 core 里，是视图自己的一张表（uid → 已揭示）
- 未揭示：灰色剪影 + 噪点（噪点按 uid 定死，不闪）+ 一个「?」
- **一件一件来**（058 第 5 条，报告 068）：`start_reveal()` 后视图只有「当前」和「进度」两个量，当前这件按它的稀有度耗时
  （`SearchRules.reveal_seconds`，每档几秒，占位 [0.3, 0.5, 0.8, 1.2, 2.0]，导入器要求非递减；**和体积无关，没有角色倍率**），
  到点亮出来，再按栏位顺序（先上后下、先左后右）挑下一件；「下一件」每次问的时候现算 —— 作者说的「长度为 2 的搜索列表」。
  时间由 `advance(delta)` 推进（`_process` 每帧调，测试直接调）
- **没亮的能拖，但只能在容器里挪**：视图照发 `grab_requested`（除了正在搜的那件 —— 它锁住），拖拽层的第二道门 `DragLayer.drop_filter`
  由容器屏给「亮了随便放，没亮的只许放回这个容器」；挪一挪就换了「下一件」是谁。没有按光标距离的规则
- 当前那件画进度环、下一件画小标（占位画法）；「快速搜索」`skip()` 把没亮的全亮；「全部拾取」先全亮再全进暂存区

**战利品屏与搜索屏共用它。** 战利品屏（尸体容器 / 搜索收获）左边是 `LootView`，右边是自己的棋盘与暂存区，同一层 `DragLayer` 盖着三个容器 ——
亮出来的直接拖到棋盘或暂存区，剩下的离开时不要了；都拖走了屏自己关。搜索屏每搜一次把找到的摆进 `SearchSession.haul_box`
（`LootPacker.add`：放不下就换一个高一格的容器、东西原位搬过去、uid 不变，`haul_changed` 让视图重绑），只对新来的走时间线；
搜索屏里已经亮过的，到了战利品屏不再重新揭示（`GameFlow.seen_loot` 记着 uid，拾取完清空）。

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

### 6.5 节点事件（M4-4）

`NodeEvents` 是 5.6 那个 `MapTravel.on_node_event` 钩子的真正接收方（`bind(travel)`）。
它只接「节点类型 → 发生什么」的逻辑，每种结果一个信号，界面与转场（M6）只管接；数值全从 `NodeRules` 来（7.1）。

| 踩到 | 发生 |
|---|---|
| battle / elite / core | `BattleSim` 打一场，玩家单位由 `player_spec` 在开战那一刻编译（4.2 是纯函数）。赢：`DropResolver` 掷、装尸体容器、`loot_ready`；输：扣 `loss_cost[类型]`，归零 `defeated(vitality_depleted)`；core 输了直接 `defeated(boss_lost)`，不扣。**不论输赢点都用过** |
| search | 配了事件（默认 `search_default`：搜索 / 离开）先过事件屏；选「搜索」开 `SearchSession`，结束（搜满 / 离开 / 遭遇）时 `search_closed(haul)`；遭遇先就地打一场；结束才算用过 |
| random | 先 `reveal`，再按揭开的类型走（揭成什么就按什么类型配事件） |
| rest | `vitality.restore(rest_restore)` |
| event | 配了事件先过事件屏，选项的后果决定发生什么（下面）；没配的按 `event_weights` 出 item / restore / story（占位老路） |
| shop / extract | 只发信号：买卖、撤离是 M6 的事 |
| junction / spawn | 只标用过 |

平局按输算。没有玩家单位、或点里没有敌人：点只是走过。随机数从节点 `content_seed` 派生，每种用途一个标签
（reveal / enemy / battle / loot / search / ambush:k / event），改一种用途的抽法不影响别的。

#### 事件层（063）：每个点先过事件屏

作者定的（059）：所有节点打开后都先跳转事件界面；没有前置剧情的战斗点事件被略过，变成转场；搜索点和标准事件点配有文字、图像、选项，选项决定后续；
事件在生成地图时定好但可以被覆盖或替换；战斗事件暂无「绕开」的选项但结构开放。

**事件是内容。** `EventDef`（内容种类 `events`）：标题、正文、图像路径（占位）、选项；每个选项若干**条件**（`EventCondition`，只读：`has_buff_tag` / `has_map_buff` /
`can_afford` / `vitality_at_least` / `steps_within` / `bracket_within` / `erosion_depth_within` / `has_item` / `node_type_is`（8-3））与若干**后果**（`EventOutcome`：`give_item` / `give_random_item` / `restore_vitality` / `spend_vitality` / `change_money` /
`grant_map_buff` / `remove_map_buff` / `start_battle` / `open_search` / `open_shop` / `next_event` / `say` / `hunter_fight` / `hunter_flee`（071）/ `teleport` / `change_node_type` / `proceed` / `pass_time` / `lose_item`（8-3））。两种都是构件、走注册表（`EffectRegistry` 的两张新表），
加一种不改导入器。条件没过的选项灰掉并写原因（或按 `hide_when_locked` 不显示）。

**节点怎么拿到事件。** `NodeRules.events_by_type`：类型 → {事件 id: 权重}。生成地图时 `EventPlacer.fill` 按节点 `content_seed` 抽一个写进 `node.content["event"]`，
已经有的不覆盖（作者数据、别的系统替换过的都算数）；随机点揭开时按揭成的类型再抽。取的时候先看内容里的，没有再按表抽 —— 旧存档没这个键也照样走。
没列的类型（多数是战斗）没有事件 = 转场。**没有事件定义（持有方没给 `event_defs`）= 老路**，每个点踩上去直接发生；沙盒与老测试就在老路上。

**踩上去分两段。** `NodeEvents.handle`：取事件，有就记进 `pending`、发 `event_pending`、停下等；`choose(i)` 条件过了依次执行后果，发 `event_resolved(node, 选项, detail)`，
然后按后果立的旗子走：接下一个事件（再发 `event_pending`）/ 开搜索 / 开店 / 开战（点自己有敌人就打它，没有就现造）/ 点用过。`pending` 跟着存档，读档回来还在这一屏。
`GameFlow` 把 `event_pending` 排进队（事件屏），`event_resolved` 有内容时把结果页插到队首（先看「你翻出了什么」，再看接下来打的那一场）；
队列空了还有等着选的事件就显示它。搜索屏与战利品屏合成一个**容器屏**（`ui/game/container_screen.gd`）：装的是待拾取还是搜索会话由 payload 决定。

**构件按内容需要加（8-3，报告 077）。** 条件看得见的一局状态进了 `EventContext`：地图、步数、棋盘与暂存区、段位与侵蚀深度（两个回调，持有方接；没接 = -1，条件永远不满足）。
后果里**传送**只挑目的地（最近 / 最远 / 随机 / 内容里指定的 id，按类型与步数区间筛）、立旗，挪人在 `choose` 的最后：这个点的事都完了才造一个 `MoveIntent.teleport` 交给持有方的 `relocate`
（`RunState.relocate`：关会话、清暂存区、`travel.apply`、猎手回合 —— 和走一步一样的壳），落地那个点头一回踩上就触发它的事；`MapTravel` 对 teleport 不再查边（信任解析方）。
**原地耗时**走 `MapTravel.wait`（计数 → 侵蚀推进 → 脚下结算，不挪人），在判战败之前。**改类型**写 `resolved_type`（和随机点揭开同一个记号），同一选项里后面的「照常发生」「开战」按新类型走。
**照常发生**（`proceed`）让休息 / 商店点也能先过事件屏而数值还在 `NodeRules`；`rest_default` / `shop_default` 挂在 `events_by_type`。导入器拦撞车的组合：传送 + 搜索 / 开店 / 接下一个（会话断了）、传送 + 给道具（离开时暂存区清空）。

### 6.6 经济（M4-5）

作者的设想：打赢战斗获得货币，数量按敌人强度、所在深度与难度；商店售卖随机稀有度道具且可以刷新，都花货币；
一个中途撤离点是付费的，费用暂用 50 占位。

```gdscript
# core/run/economy_rules.gd —— data/authoring/economy_rules/*.json，章节按 id 引用（ChapterDef.economy_rules）
class_name EconomyRules extends Resource
@export var starting_balance: int
@export var reward_base: int                  # 打赢 = (base + per_strength × 档位) × (1 + depth_gain × 深度) × (1 + difficulty_gain × 难度)
@export var reward_per_strength: int
@export var reward_depth_gain: float
@export var reward_difficulty_gain: float
@export var shop_slots: int                   # 货架几格
@export var shop_rarity_weights: Array[float] # 上架的稀有度权重，× (1 + shop_depth_gain × 深度 × 稀有度)
@export var shop_price_mult: float            # 售价 = 道具价值（6.4）× 倍数
@export var shop_refresh_cost: int            # 刷新一次；每刷一次涨 shop_refresh_step
@export var paid_extracts: int                # 几个中途撤离点收费（最深的那几个）
@export var extract_fee: int                  # 收多少（50 占位）
```

- **`Wallet`**（`core/run/wallet.gd`）和 `Vitality` 一个做法：不知道任何数值，只管进账、花钱、够不够、发信号；不够就一分不动。
  它就是 7 节 `RunState` 里那个 `gold`。
- **打赢进账**在 `NodeEvents._fight` 里：档位来自节点内容的 `strength`（6.0），深度按 tier 归一化，难度是章节的。输了、平了不给。
- **商店**是 `ShopSession`：货架由节点 `content_seed` 与刷新次数决定（第 n 次刷新摆的永远是那几件），所以存档只记
  `content.shop = {refreshes, sold}`；候选不含包与珍宝，按稀有度权重抽、不重复；价 = `ItemValue.of` × 倍数；买了就没了；
  刷新花钱且越刷越贵；走了才算用过。买到的东西交给谁装是 M5 的事，这里只发 `bought`。
- **付费撤离点**由 `PaidExtracts.mark(graph, rules)` 在生成之后标（生成器不认识钱）：挑最深的 `paid_extracts` 个撤离点，
  费用记进 `content.fee` 跟着图存；核心不是中途撤离点，不收。`NodeEvents.extract_reached(node, fee)` 报费用，
  撤离动作（M6）先调 `pay_extract_fee(node)`：免费直接过，付不起 false、一分不动。
偏搜索路线「低收益」的意思，是期望价值低、方差大 —— 搜到一件传说品能把整局翻过来，
所以才有「搜到强力道具一转战斗」这条退路。

**战斗力与价值的张力**：一件大而贵的东西占着棋盘却不出力，背它出去还是换成两把刀，
就是搜刮路线上每一次整理背包时要答的题。

---

## 7. M5 · 运行状态与存档

M4 结束时地图、旅程、体力、钱、节点事件各自都能跑，只差一个装它们的壳。`RunState`（`core/run/run_state.gd`）就是那个壳，
**纯 `RefCounted`，不是 autoload**（1 节：核心逻辑层没有全局状态）；M6 的 `GameDirector` 持有它、给界面看。

```gdscript
class_name RunState extends RefCounted
const SAVE_VERSION := 1
enum Phase { PICK_SPAWN, ON_MAP, DEFEATED, EXTRACTED }
signal phase_changed(phase, reason)
signal loot_pending(container)         # 尸体容器 / 搜索收获等着拾取

var run_seed: int
var chapter: ChapterDef
var rng: RunRNG                  # 分流随机源（1.4），run 级的随机走它；节点内容按各自的 content_seed
var map: MapGraph                # 节点内容（敌人、搜索进度、货架进度、付费撤离点）都在图里
var travel: MapTravel            # 人在哪、走过哪、行动计数
var vitality: Vitality           # 体力（7.1）
var wallet: Wallet               # 货币（6.6）
var board: GridInventory         # 作战棋盘，requires_bag = true，只有包里的东西参战
var storage: ItemStash           # 暂存区：一个列表，保留但不参战（3.4）
var events: NodeEvents           # 踩到点发生什么（6.5）
var tracker: SetTracker          # 套装激活（9 节），绑在棋盘上
var pending_loot: GridInventory  # 等着拾取的容器；take_loot / take_all_loot / discard_loot
# erosion: ErosionField          # 第 7 阶段
# meta_stash                     # 跨 run 的东西不在一局里（15 节）
```

**开局**（`RunState.start(chapter, seed, items, enemies, sets, kit)`）：生成地图 → 放敌人 → 标付费撤离点 → 造棋盘
（包放棋盘，其余先进包、放不下进暂存区）→ 把节点事件接到旅程上。`pick_spawn` 进 `ON_MAP`，`step_to` 先关掉开着的
店 / 搜索再走（随时可以离开），`try_extract` 在撤离点上付费撤离进 `EXTRACTED`，`defeated` 进 `DEFEATED`。

**接线**：打赢的尸体容器、搜到的收获落到 `pending_loot`（还没处理又来一份就并进去，一件不丢）；买到的、事件给的直接进暂存区；
`equip` / `unequip` 在暂存区与棋盘之间搬。玩家的战斗单位在开战那一刻从棋盘编译（`compile_player`，套装效果从 tracker 取）。

### 7.1 体力与战败

**战斗输了不等于一局结束。** 输一场扣**体力**，归零才战败。

体力是 run 级的小整数，与战斗内的生命、耐力（4.3）**不是一回事**：战斗内的资源每场重置，
体力跨战斗保留。它是「这一局还剩几条命」，也是 5.4.2 里「战损过高选择提前撤离」的那个「战损」——
偏战斗路线上的玩家看着体力一格格往下掉，就该考虑下一个撤离点了。

```gdscript
# core/run/vitality.gd
class_name Vitality extends RefCounted
signal changed(current, maximum, delta, reason)   # delta 是【实际】变化量
signal depleted(reason)                           # 归零。战败由监听者判定

const PLACEHOLDER_MAX := 5        # 占位，等角色系统

var current: int
var maximum: int

func _init(p_max := PLACEHOLDER_MAX, p_current := -1)
func change(delta: int, reason) -> int     # 唯一真正动手的方法，返回实际变化量
func spend(amount: int, reason) -> int     # 扣，返回实际扣掉的
func restore(amount: int, reason) -> int   # 回，返回实际回复的
func set_max(new_max: int, reason) -> void # 涨上限当前值同量涨，与 ResourcePool 一致
func is_depleted() -> bool / is_full() -> bool / ratio() -> float
func to_dict() / static from_dict()
```

**本类不知道任何数值。** 扣多少、回多少一律由调用方传进来：

```gdscript
vitality.spend(cost, &"battle_lost")   # 输一场，cost 来自节点内容
vitality.restore(amount, &"rest")      # 歇一会儿，amount 来自休息区的配置
```

| 事 | 谁定这个数 |
|---|---|
| 普通 / 精英战斗失败扣多少 | 节点内容（`MapNode.content`）与章节配置 |
| 休息区回多少 | 同上。**不写死** —— 不同休息区、不同角色都可能给不同的数 |
| 侵蚀浅层惩罚扣多少 | `ErosionSchedule`（5.7） |
| 初始与上限 | 角色定义（见下）。角色系统落地前用 `PLACEHOLDER_MAX` |
| 章节 BOSS 失败 | **直接战败**，不论还剩多少体力 —— 这是规则不是数值，归调用方判 |
| 归零 | 战败，`DeathResult` |

数值写进本类的话，调一次就要改一次代码；而且不同角色、不同章节还想给不同的数，
到那时改起来就是把同一个常量从三个地方各挖一遍。

**`Vitality` 也不知道「战败」是什么**，更不知道 BOSS 输了要直接战败 ——
它只在归零时发 `depleted`，由 `GameDirector` 判定结局。BOSS 那条例外同样在调用方：
战斗结算时看一眼「这个节点是不是 core」，是就直接走 `DeathResult`，连 `spend` 都不用调。

#### 角色系统的接入点

不同角色会有不同的初始体力与上限。`Vitality` 从构造参数拿这个数，所以**角色系统落地时
本类与所有调用方一行不改** —— 只是 `RunState` 构造它时从角色定义读，而不是用
`PLACEHOLDER_MAX`。

这与 [`CombatantBaseline`](#42-编译阶段背包--战斗单位)（战斗侧的角色占位）是同一种做法：
结构先立住，数值等内容定稿。两者将来会一起挂到同一份角色定义上 ——
战斗基线管「开局多少血多少耐力」，体力管「这一局还剩几条命」。当初**刻意不建** `CharacterDef`：只有两个占位点，建了也是空壳，
等真的有第三样东西要按角色变时再说 —— 第三样是带入限制（058 第 2 条），**067 建了**：`CharacterDef`（内容种类 `characters`）定棋盘尺寸、体力上限、
基线覆盖项、初始包、带入上限，`RunState.start` 给了角色就按它来；`Vitality`、`CombatantBaseline`、编译器一行没改。

**输了节点也变空白。** 战斗不论输赢，节点都消耗掉（`VISITED`）：赢了有战利品，
输了什么都没有还扣体力。没有「再打一次」—— 所以每一场打不打是一次性的决定，
而 5.10 让玩家在做这个决定之前看得见对手。

> 我原先暂定的是「节点保留、可以重打」，作者纠正。重打会让体力变成可以反复兑换尝试次数的货币，
> 「用体力磨过去」成为最优解；一次性消耗则让地图上的每个敌人都是一道只答一次的题。

**BOSS 是例外：输了直接战败。** 别的战斗输了节点变空白、人还能走；核心变空白了这一局就没有终点，
所以打 BOSS 是一次押上整局的决定 —— 这也让偏搜索路线「尽头是撤离点、可以不打 BOSS」
成了一条真正的退路，而不只是少打一场。

`type_risk`（5.4）就是按这张表定的：一步的风险分 = 输的概率 × 扣的体力。

### 7.2 存档

存档 = `RunState.to_dict()` → JSON 写入 `user://`（`RunSave`）。所有逻辑类实现 `to_dict()` / `static from_dict()`，
因为逻辑层不继承 `Node`，这件事非常顺畅：地图（含每个点的内容与用没用过）、旅程、体力、钱、棋盘、暂存区、随机流的序号、
累计搜索次数、待拾取的容器、阶段。**内容库不进存档**，只写 id（章节、道具、敌人），读档时由调用方给；
开着的店 / 搜索会话不存 —— 存档那一刻视为离开了那个点，货架与搜索进度本来就在图里。

**存档从第一天就写版本号**（`{"version": 1, ...}`），读到不认识的版本不猜、返回 null，后续加字段才有迁移余地。
读档之后接着走，和没存过的那份走同样的路结果一样（测试守着这条；新建道具的 uid 从存档里最大的接着编，那不算状态）。

---

## 8. M6 · 场景流

```
MainMenu → SetupScreen(挑一章、挑角色、从仓库往初始包里拖、种子) → MapScreen
                                                      ⇅ 叠层（地图与镜头留着）
              ┌───────────────────────────────────────┴────────────────────────────┐
         EventScreen（先过事件，063）→ BattleScreen（回放）→ ContainerScreen（战利品 / 搜索）    ShopScreen / RestScreen
                                                      ⇅
              ResultScreen（撤离 / 战败结算）→ MetaScreen（仓库与战绩）→ MainMenu
```

**状态机是纯逻辑的 `GameFlow`（`core/run/game_flow.gd`），导演 `GameDirector`（`ui/game/game_director.gd`）只是它的皮。**
flow 只说「现在该显示哪一屏、给它什么」（`screen_changed(screen, payload)`），不认识任何 Node；测试直接驱动它，一屏都不用画。
导演是 `ui/game/game.tscn` 的根（项目的主场景），持有 flow 与内容库，听信号换屏。**不是 autoload**：核心逻辑层没有全局状态（1 节），
一局的状态在 `flow.run`（`RunState`，7 节）里，跨局的在 `flow.meta`（`MetaState`，8.2）里。

**屏分两层。** 底屏（主菜单、开局、地图、结算、局外）互相替换；叠层（战斗回放、战利品、搜索、商店、事件、休息）叠在地图上，
`add_child` / `queue_free` 手动管，**不用 `change_scene_to_file`** —— 地图和镜头都留着。每一屏是一个 `GameScreen`（`ui/game/game_screen.gd`）：
导演造它、给它 flow 与字体、`open(payload)`；屏只把 flow 的状态画出来、把玩家的动作转成 flow 的方法（1.2 命令进、信号出），不认识导演。

**节点事件排成队。** 事件是同步发生的：`step_to` 一步之内可能连着来「打了一场 → 掉了东西 → 进账」，各自一个信号。flow 把它们排成队，
走完这一步按顺序一屏一屏给玩家看；叠层看完了 `resume()` 看下一个，队空了回地图；一局结束了（战败 / 撤离）最后一定是结算屏 ——
结束之后队里只有那一场的回放还值得看，其余（战利品、会话）跳过。搜索 / 商店会话结束由 flow 自己接着往下走（`session.ended` / `closed`），屏不必管。

```gdscript
class_name GameFlow extends RefCounted
enum Screen { MAIN_MENU, SETUP, MAP, BATTLE, LOOT, SEARCH, SHOP, EVENT, REST, RESULT, META }
signal screen_changed(screen, payload)
signal run_started(state) / run_ended(result)
func to_main_menu() / new_run() / show_meta()
func begin(chapter, loadout, seed, from_warehouse, character, layout) -> RunState   # SETUP → MAP；老路给 loadout，角色路给 character + layout
func continue_run() -> bool / save() / save_and_quit()
func pick_spawn(id) / step_to(id) / extract()       # 走完 / 撤完看队里下一个
func resume() / take_loot(uid) / take_all_loot() / discard_loot()
func finish_result()                                 # 进 meta（只一次）、存 meta、删这一局的存档 → META
static func load_chapters() / load_loadouts() / load_characters()
func grant_first_kit()                               # 仓库空的第一局发第一套（MetaRules.first_kit）
```

### 8.1 开局：角色、初始包、从仓库带入

**角色**（`CharacterDef`，`core/run/character_def.gd`，内容种类 `characters`，报告 067）定开一局时按角色变的那几样：战斗基线的覆盖项（没写的沿用 4.2 的默认）、
体力上限、棋盘尺寸、初始包、带入的件数 / 稀有度上限（-1 = 不限，作者：改成字段、默认不限）、**被动技能** `skills`（一局规则的效果构件，和局外 buff 同一套：
侦察 / 潜行 / 逃跑三个构件往 `RunContext` 加数，猎手系统读；主动技能以后走事件层，报告 072）。**没有搜索速度**（作者：搜索在战斗外、不是实时的）。
现在两个占位角色 `default`、`scout`。

**开局屏**：左边挑章、挑角色、定种子；中间是这个角色的棋盘，初始包已经摆好；右边是仓库的格子（8.2）；同一层拖拽。
**从仓库往包里拖，放得进的就是带的** —— 带入的真正限制是初始包的空间，没有第二套规则去数格子。拖上棋盘那一刻东西就离开了仓库；
出发时把棋盘记成 layout（一件一行：定义、落点、朝向），`RunState.start(..., character, layout)` 按它原样摆回一局的棋盘并存 meta；「回主菜单」放回仓库。
**包不能带入**：局外不收包（`MetaState.keeps`），仓库的格子把同一条规则接成准入回调（`GridInventory.accept_filter`），初始包拖不进去。
上限出发时查（`CharacterDef.carry_problem`），超了拦下说原因。读档只写角色 id，`GameFlow._adopt` 按 id 找回基线。

**仓库空的第一局**：`MetaRules.first_kit` 指一套开局装备，开局屏打开时仓库空着就把它的非包道具发进仓库（`GameFlow.grant_first_kit`）。
作者说正式游戏由新手教程关发第一套（第 8 阶段），这是那之前的配置占位。

`LoadoutDef`（`core/run/loadout_def.gd`，内容种类 `loadouts`）于是只剩两件事：第一套的清单，和没有角色定义时的老路（`begin(chapter, loadout, seed)`：
清单里的包先上棋盘，其余按顺序往包里放、放不下进暂存区，`RunState._give_kit`）。校验：每件得存在，至少一个包。现有三套占位。

### 8.2 结算与局外

`RunResult.settle(state)` 从结束了的一局里算一份账（只读）：撤离 = 棋盘上的全部（含包）按价值（6.4）计、剩多少钱；
暂存区里的记成「遗落」只提一句（3.4：暂存区里的道具 = 不存在）；战败 = 什么都没有。行动点、踩过几个点、打赢 / 打输几场（`RunState.tally`，跟着存档）。

`MetaState`（`core/meta/meta_state.gd`）是跨局的状态（作者定的形态，058 第 4 / 6 / 7 条，报告 061）：

- **仓库是一块格子**（`GridInventory`，不要求包：所有格子默认可用），大小是 `MetaRules.warehouse_size`（内容种类 `meta_rules`，占位 10×8；作者：仓库也是局外成长的一部分，成长系统改这个数）。
- **撤离不直接进仓库。** 棋盘原样带回来（`MetaState.board`：一块和棋盘一样大、不要求包的格子，非包道具按原位置 —— 作者说的「包统一替换成最大的默认背景包」），
  玩家在结算屏 / 局外屏拖或**一键置入**（按栏位顺序逐件放，放不下就停在那一件提示）；带回来的棋盘没清空之前 `GameFlow.can_begin()` 拒绝开新局。
- **图鉴**（`codex`）：道具 id → 累计带出件数，同一次带出多件各计一次，点亮 = 计数 > 0（本来就幂等）；不代表物品被储存，将来的制作系统读它。
- **包只计图鉴**：什么能存进局外由 `MetaState.keeps(def)` 一处说了算（现在：不是包）。「包」只是当前的承载媒介，将来可能删掉，那时删这一个分支。
- 钱、累计价值、几局几撤几败、最近几局。**保留规则只在 `absorb()` 一个方法里**（15 节第 4 项）：撤离 = 图鉴每件计一次、非包道具带回棋盘、钱全带出；战败 = 全失。
- 局外有自己的 uid 空间：每局的 uid 从 1 重编，进来时重新编号。

一局结束时（`GameFlow._settle_run`，进结算屏之前）就 `absorb`、存 meta、删这一局的存档；结算屏拿到的已经是记完账的局外。
`MetaSave` 与 `RunSave` 同一套做法：`user://meta.json`，版本号 2（v1 是开发期的，作废），只写 id；仓库大小以存档里的为准（成长过的不该被规则缩回去）。
**buff**（059 第 3 条，062）：局外的与一局里的是同一套定义 `RunBuffDef`（内容种类 `run_buffs`：scope、时限步数、标记、`mods` / `rules` / `effects`），
效果树多了 `RunEffect` 分支（9.2），往 `RunContext` 里加数（体力上限、开局钱、多搜几次、商店价、幸运），各系统在对应的点读。
局外的由 `MetaState.active_buffs` 决定（占位：局外屏的开关列表；将来任务、局外科技），开局那一刻记进这一局；一局里的由事件后果给（`RunState.grant_map_buff`），
有时限的每走一步少一步，只带 `tags` 的就是标记，事件选项的条件查 `has_buff_tag`。

仓库里的东西能**带进下一局**（开局屏勾上；`GameFlow.begin(..., from_warehouse)` 从仓库拿走、立刻存 meta —— 撤离了它们回来、死了就是真没了，
这就是搜打撤的循环）；卖掉、局外货币怎么花还没定。撤离前有一道确认（地图屏）：付多少钱、棋盘上多少件会背出去、暂存区里多少件带不出去（3.4 的提示，不是挽留）。

### 8.3 M6 分三步

| 步 | 做什么 | 状态 |
|---|---|---|
| M6-1 骨架 | `GameFlow`、`LoadoutDef` 走管线、`RunResult` / `MetaState` / `MetaSave`、导演与全部屏的最小版、主场景换成正式游戏 | 完成（055） |
| M6-2 搜刮界面 | 6.2 的渐进揭示（剪影 → 逐件揭示、快速搜索）、从战利品容器拖到棋盘 / 暂存区、搜索点的收获同一套 | 完成（056） |
| M6-3 打磨 | 撤离确认与遗落提示、仓库里的东西带进下一局、商店屏的道具行、局外屏「再来一局」、截图验收 | 完成（057） |

---

### 8.4 进阶难度：机制清单（069 / 070）

作者：像杀戮尖塔的进阶，但不只提升数值，要加入机制。于是一档难度是一份**清单**（`DifficultyDef`，内容种类 `difficulties`）：
开哪些机制（`RunMechanic` 构件，各带参数，登记在 `EffectRegistry.RUN_MECHANICS`）、顺带哪些数值修饰（`RunEffect` / `LootEffect`，和局外 buff 同一套构件，
`RunState.buff_context()` 一起算）。机制自己把自己接进一局（`install(run)`：侵蚀接 `MapTravel.erosion`，猎手接 `RunState.hunters`），
开局与读档各调一次，必须幂等；`RunState` 不认识任何具体机制。**没有难度定义 = 普通 = 现在的一切。**
难度是局外解锁的特殊选项：`requires_unlock` 指一个解锁 id，`MetaState.unlocks` 记着（占位开关在局外屏，将来是成长系统），开局屏只列能选的。
侵蚀由此改口：不是每一局都有，是某档难度开的机制；`ErosionMechanic` 的本体在 075（5.7）。
`ChapterDef.difficulty`（这一章本身多难）与进阶难度是两回事。侵蚀本体见 5.7（075）。

### 8.5 猎手：伪 PVP（069 / 071）

作者：地图上出现移动的单位，不和节点互动，距离够近就主动靠近并攻击（或远离，多种行动逻辑），强度按探索度实时变、胜率对参考玩家调到 50%。
落地为难度清单里的一个机制 `HunterMechanic`（几个、第几步出现、出现距离、度量）+ 内容种类 `hunters`（`HunterDef`，一个等级一份：可视性、感知、速度、开打距离、
领地半径、行动逻辑构件、战败后果构件、掉落倍数、逃跑、敌人池与强度规则）。`HunterSystem` 挂在 `run.hunters`：玩家一步的末尾动一回合 ——
出现（离玩家与彼此最远）→ 每个按行动逻辑在自己领地里走几小步（不进别人的领地）→ 进感知范围提示一次 → 够得着就**开打前先过事件屏**
（合成的 `EventDef`「迎战 / 逃跑」，登记在 `NodeEvents.extra_defs`，`pending` 多一个 `hunter` 字段跟存档）。玩家正忙时不打扰，空下来 `poke_hunters` 再问。
迎战：**按玩家当时的段位定档**（段位只看步数：难度里猎手机制的 `bracket_steps` 划段，猎手定义的 `strength_by_bracket` 每段几档；表空退回探索度的强度规则，074）从猎手专属池（`enemy_pools/hunters`，占位）现造敌人（`EnemyPlacer`），打赢它死、掉落率乘 `drop_mult`；打输按定义里的后果构件依次执行
（扣体力 / 没事 / 必杀 / 消失 / 退走并歇 / 赶回上一个点并驻守）。逃跑按成功率掷，没逃掉扣体力照打。距离度量 `MapMetric`：`steps` 或 `absolute`（地图屏注入按环距归一的坐标）。
随机数走 `RunRNG` 的 `hunters` 流。`RunContext` 多三个字段（侦察距离、感知倍率、逃跑加成），角色的被动技能（072）、局外 buff、难度修饰都能往里加数。
**校准**（073）：正式游戏每走一步记一份玩家配置（`CalibrationRecorder` → `user://calibration/snapshots.jsonl`），`tools/build_dummies.gd` 按难度的段位表分段（或固定段长）、每段挑离平均读数最近的真实配置当木桩，
`tools/bench_hunters.gd` 让木桩对猎手池里每一档打几百场，打印胜率并排「猎手表里这一段的档 / 最接近 50% 的哪一档」—— 工具只做统计，作者对着表改强度规则。数值等系统完整后多场测试。

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
  RunEffect      一局的规则，激活即生效     VitalityMaxBonus / StartingFundsBonus / ExtraSearches / ShopPriceMult / LuckBonus（062，buff 携带）
```

基类**只声明作用域，不声明执行方法**。各分支的调用签名本就不同
（战斗要 `RuleContext`，掉落要 `LootContext`），强行统一只会得到一个没人能用的签名。

| 分支 | 何时生效 | 由谁调用 |
|---|---|---|
| `CombatEffect` | 扳机命中且消耗付清后 | `RuleEngine` |
| `LootEffect` | 进入战利品计算阶段，**只要处于激活状态** | M4 掉落系统 |
| `MapEffect` | 待定 | M3 地图系统 |
| `RunEffect` | 一局在对应的点算 `RunContext` 时（开局、开搜索、开商店、掷掉落），**只要 buff 激活** | `RunState` / `NodeEvents`（062） |

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
data/authoring/items/*.json         道具源数据
data/authoring/buffs/*.json         增益源数据
data/authoring/sets/*.json          套装源数据
data/authoring/loadouts/*.json      开局装备（8.1：第一套的清单、老路）
data/authoring/characters/*.json    角色（8.1）：基线覆盖、体力、棋盘、初始包、带入上限
data/authoring/difficulties/*.json  进阶难度（8.4）：机制清单 + 数值修饰 + 解锁要求
data/authoring/run_buffs/*.json     buff：局外的 / 一局里的（8.2、9.2）
data/authoring/events/*.json        事件：文字、选项、条件与后果（6.5 事件层）
data/authoring/enemies/*.json       敌人（6.0）
data/authoring/enemy_pools/*.json   敌人池（6.0）
data/authoring/hunters/*.json       猎手（8.5）：一个等级一份
data/authoring/drop_rules/*.json    掉落规则（6.1）
data/authoring/node_rules/*.json    节点规则（6.2 / 6.5）
data/authoring/economy_rules/*.json 经济规则（6.6）
data/authoring/meta_rules/*.json    局外规则：仓库多大、第一套（8.2 / 8.1）
data/authoring/chapters/*.json      章节（5.3）
        │  tools/import_content.gd   校验 + 生成（顺序：buffs → sets → run_buffs → items → loadouts → characters → difficulties → events → enemies → enemy_pools → hunters → drop_rules → node_rules → economy_rules → meta_rules → chapters）
        │  tools/normalize_content.gd 把作者数据重写成导出器的格式（导入 → 导出 → 不同就写回）
        ▼
data/items/*.tres   data/buffs/*.tres   data/sets/*.tres   data/run_buffs/*.tres   data/loadouts/*.tres   data/characters/*.tres   data/difficulties/*.tres   data/events/*.tres
data/enemies/*.tres data/enemy_pools/*.tres   data/hunters/*.tres   data/drop_rules/*.tres   data/node_rules/*.tres   data/economy_rules/*.tres   data/meta_rules/*.tres   data/chapters/*.tres
```

目录常量只在 `ContentPaths` 一处：种类 → [作者数据目录, 资产目录]，`ORDER` 就是导入顺序（后者按 id 引用前者）。

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

**事件编辑器**（`ui/event_editor/event_editor.tscn`，报告 064）是同一套做法对着事件（6.5）的第二个入口：左边事件列表，中间 id、标题、多行正文、配图、选项表单，
右边预览、校验、挂进节点规则、JSON。选项、条件、后果的表单由 `PropertyForm` 反射生成，「添加」下拉从注册表来，加一种构件编辑器不改；
标题、正文、配图在表单之外有专门控件（表单里跳过这三个字段，免得两处能改同一个值）。配图用系统文件对话框挑，复制到 `assets/events/<id>.<ext>`，
路径写进 `image`；`EventImage.load_texture` 先问 ResourceLoader、拿不到按原始文件读，事件屏与预览共用，作者导完图立刻看得见。
预览照着事件屏画，每个选项底下一行写它的条件与后果（构件的 `describe`）。「挂进节点规则」把权重写进某份 `NodeRules.events_by_type`，
这一步也是导回来校验再按导出器的格式写（没保存过的事件挂不上）。没做成 Godot 之外的独立程序：构件种类、字段、校验、id 表全在注册表与导入器里，
独立程序要么复制一份要么不校验；要给不开 Godot 的作者用，导出预设把项目导成 exe 即可。

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

仓库里真实的树（2026-09-23，210 个脚本）。`core/` 纯逻辑、零 Node 依赖、可单测；`ui/` 只接线与绘制；`tools/` 命令行；`tests/` 一键全跑。

```
res://
  core/
    authoring/      content_schema  content_importer  content_exporter  content_paths  import_report
    inventory/      item_container  grid_inventory  item_stash  item_shape  item_def  item_instance
                    item_database  item_value  inventory_service
    battle/         compiler  combatant_spec  combatant_baseline  combatant_runtime  compiled_item
                    battle_sim  battle_context  battle_event  battle_result  schedule_heap
                    rule_engine  rule_runtime  rule_context  ability_rule  trigger  cadence  cost  combat_effect
                    stat_math  stat_value  stat_set  stat_modifier  battle_stats  resource_pool
                    adjacency_profile  combat_profile  buff_def  buff_instance  effect_registry
      damage/       damage_type_def  damage_types  damage_packet  damage_resolver
      triggers/     on_schedule  on_battle_start  on_damage  on_before_damage  on_item_fired
                    on_resource_below  on_resource_changed  on_stacks_at_least  damage_trigger
      cadences/     always  cooldown_cadence
      costs/        resource_cost  charge_cost  status_stack_cost  uses_cost  chance_condition
      effects/      deal_damage  modify_damage  reflect_damage  apply_status  remove_status  change_resource
    effects/        effect  effect_scope  run_effect           # 效果树的根（9.2）；RUN 分支的基类
    sets/           item_set_def  set_tier  set_database  set_tracker
    loot/           loot_effect  loot_context  drop_rule  drop_resolver  drop_bonus_source
                    meta_drop_bonus  map_drop_bonus  loot_packer
      effects/      extra_rolls  rarity_bias  category_bias  drop_owned_chance
    map/            map_graph  map_node  map_edge  map_node_types  map_generator  map_generator_registry
                    map_validation  map_navigator  map_source  map_preset  map_grid_text  map_junctions
                    zone_rules  map_effect
      generators/   ring_map_generator  ring_map_config  ring_spec  route_style  danger_zone_spec
                    map_scale_profile  ring_type_assigner  grid_script_generator  grid_script_config
    enemies/        enemy_def  enemy_pool  enemy_pool_entry  strength_tier  strength_rule  enemy_loadout
                    enemy_placer  enemy_kit  enemy_database
    run/            chapter_def  run_state  run_save  run_rng  map_travel  move_intent  action_clock
                    vitality  wallet  node_events  node_rules  search_rules  search_session
                    shop_session  economy_rules  paid_extracts  loadout_def  game_flow  run_result
                    storage_warning  run_buff_def  run_buffs  run_context
      events/       event_def  event_option  event_condition  event_outcome  event_context  event_placer   # 事件层（6.5）
        conditions/ has_buff_tag  has_map_buff  can_afford  vitality_at_least
        outcomes/   give_item  give_random_item  restore_vitality  spend_vitality  change_money  grant_map_buff
                    remove_map_buff  start_battle  open_search  open_shop  next_event  say
      effects/      vitality_max_bonus  starting_funds_bonus  extra_searches  shop_price_mult  luck_bonus   # RunEffect 构件（062）
    meta/           meta_state  meta_save  meta_rules              # 跨局（8.2）：仓库格子、带回来的棋盘、图鉴、局外 buff
    settings/       game_settings                                  # 玩家设置（3.4 的提醒档位）
  data/
    authoring/      items/  loadouts/  characters/  difficulties/  enemies/  enemy_pools/  hunters/  hunters/  drop_rules/  node_rules/  economy_rules/  meta_rules/  chapters/  maps/
    items/  loadouts/  characters/  difficulties/  enemies/  enemy_pools/  drop_rules/  node_rules/  economy_rules/  meta_rules/  chapters/     # 导入器产出，也进 git
  ui/
    launcher  dev_nav  ui_palette
    game/           game_director  game_screen  main_menu  setup_screen  map_screen  inventory_panel   # 正式游戏（8 节），game.tscn 是主场景
                    battle_screen  container_screen（战利品 / 搜索合一）  shop_screen  event_screen  rest_screen  result_screen  meta_screen
                    settings_screen  warehouse_panel  loot_view  event_image
    inventory/      inventory_sandbox  inventory_view  container_view  stash_view  drag_layer  item_painter
    battle/         battle_sandbox  battle_view  combatant_panel
    editor/         content_editor  property_form  shape_editor
    event_editor/   event_editor      # 事件编辑器（10.5，报告 064）
    map/            map_view  map_layout  ring_layout_base  ring_map_layout  grid_map_layout
                    ring_angle_solver  map_node_style
    map_editor/     map_editor
  tools/            import_content  export_content  normalize_content  check_scripts  map_stats  build_dummies  bench_hunters
                    gen_sample_items  gen_sample_combat  gen_sample_chapter  bench_battle  capture_scene  cli_tool
  tests/            run_tests  test_case  test_*（44 个套件）
```

还没有的（设计里提过、待后面的阶段）：6.2 的渐进揭示（M6-2，`ui/game/loot_screen` 现在是最小版）、
`core/run/erosion_field` / `erosion_schedule`（第 7 阶段）。`RunState`、`GameFlow` 按 1 节的约定是纯 `RefCounted`，不是 autoload；
`GameDirector` 是主场景的根，也不是 autoload。

---

## 12. 实施顺序

| 阶段 | 内容 | 产出 | 状态 |
|---|---|---|---|
| **1** | M1 网格背包 + 拖拽 + 序列化 | 可玩的整理沙盒，核心手感可验证 | 完成 |
| **2** | M2 编译 + 效果系统 + 模拟 + 极简可视化 | 两个背包能打起来，可批量跑平衡 | 完成 |
| **3** | 内容制作管线（第 10 节） | 不写代码就能造道具，数值可迭代 | 完成 |
| **4** | M3 环形地图生成 + 单步导航 + 渲染 + 行动计数 | run 的骨架成立 | 完成（030～044；作者七条 052、设想 053） | 进行中：M3-1（030）、M3-2（032）、M3-3（033）、编辑器与地图来源（034）、高危区（036）、M3-3b 与规模模板（037）完成，M3-3c（039）、M3-4（042）、M3-5（043）、M3-6 渲染与沙盒（044）完成 —— **M3 全部落地**，计划见 027 |
| **5** | M4 节点内容：敌人池 + 掉落 + 随机点与搜索点 + 节点事件 + 经济 | **循环闭合，第一个可玩 Demo**（沙盒里） | 完成（045～050）；搜刮揭示的界面与撤离动作归 M6 |
| **6** | M5 存档 + M6 场景流打磨 | 可对外试玩 | 完成：M5（051）、M6（055～057，8.3）—— 正式游戏从主菜单一条线玩到仓库 |
| **7** | 进阶难度（机制清单）+ 猎手 + 侵蚀本体 | 难度骨架 ✅（070）、猎手 ✅（071～074）、侵蚀本体 ✅（075） | 完成 |
| **8** | 内容扩充（物品 / 敌人 / 事件 / 新章节地图形态 / 扩展移动机制） | 此后 90% 的时间 | 进行中：规划与 8-1 传送点 ✅（076）、8-3 事件构件 ✅（077）、8-2 沙漏与塔 ✅（078） |

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
| 1 | ~~run 内是否存在持久生命值~~ 已定：**体力**（7.1），战斗失败扣 1 / 2，归零战败 | 数值一概不写死：扣多少回多少由调用方传给 `Vitality`，初始与上限等角色系统（7.1） | 无 —— 接口已经把数值挡在外面了 |
| 2 | 侵蚀损失的具体形式 | 浅层扣生命值，深层额外损坏背包物品 | 同上，只改效果实现与参数 |
| 3 | 节点事件的额外行动消耗 | 搜刮 +1 ／ 休息 +2 ／ 商店 +0。**未做**：现在一律只按边的 `action_cost`；加的话在 `NodeEvents` 里对 `travel.clock.spend` | 仅影响节奏调参 |
| 4 | 撤离后的保留规则 | **作者已定（058 / 061）**：撤离时棋盘原样带回局外，玩家在结算屏拖或一键置入仓库（放不下就停）、没清空开不了新局；图鉴每件计一次；包只计图鉴；钱带出；战败全失。局外货币怎么花、卖东西未定 | 影响 meta 成长曲线，不影响任何模块接口 |
| 5 | ~~棋盘尺寸与开局可用格数~~ 已收进角色（067）：`CharacterDef.board_size` 与 `starting_bags`，占位角色 8×6、两个 2×3 的包 | 纯数值，改 `characters/default.json` | 无 |
| 6 | 合成配方是否纳入第一章 | 暂缓，先跑通包体系统与战斗 | 独立子系统，可后加 |
| 7 | ~~暂存区的清空时机~~ 已定并实施（060）：**走出发生过事的点时清**，走之前按设置档位提示（3.4） | 出生点、岔路、路过的点不清；档位与阈值是 `GameSettings` 里的数据 | 商店 / 事件 / 休息屏还没有背包按钮（事件层重做那三屏时一起加） |
| 8 | ~~各角色的基线数值（见 4.2）~~ 已收进角色（067）：`CharacterDef.base_stats` 覆盖 4.2 的默认，占位角色生命 60；体力上限 `vitality_max` | 数值在 `characters/*.json`；编译器与战斗不改 | 无 |
| 9 | 元素类型各自的性质 | 目前只有 `fire` 占位，性质同物理 | 加一份 `DamageTypeDef` 即可，结算管线不改 |
| 10 | ~~耐力等资源是否回复~~ | **已定：按时间自动回复，懒结算**（见 4.5） | 速率是 `regen_xxx` 属性，因此自动吃 buff。当前数值是占位：基线 4/秒，口粮 +2/秒 |

| 11 | 作者的提议（[058](reports/058-author-five-proposals.md)、[059](reports/059-event-layer-and-buffs-proposal.md)）：暂存区在离开发生过事的点时清空、分层提示；仓库格子化（随局外成长）与图鉴；结算屏保留棋盘 + 一键置入；开局预选（带入的限制就是初始包的空间，包只出不进）；搜索揭示按稀有度计时、未搜的只能在容器内挪位；**事件层**（每个节点先过事件屏，选项带条件与后果构件）；**局外 buff 与地图 buff**（同一套构件，效果树加 RUN 分支） | 三轮问答后已定大半，**未实施**；顺序：暂存区 → 仓库与结算与图鉴 → buff 骨架 → 事件层（含容器屏合一）→ 开局预选 → 搜索揭示 → 外框（可选） | 问题已全部有答案（058 第六节、059 第六节），按 059 第四节的顺序实施，每项一份报告 |

这几项都被刻意隔离在参数层或单个类的内部，**推迟决定不会阻塞任何模块的开工**。

更完整的「留给作者定的」清单（含 M4 各报告与 053 的设想）在 [status.md](status.md)。

---

## 16. 变更记录

| 版本 | 日期 | 内容 |
|---|---|---|
| v0.1 | 2026-09-20 | 初版：六大模块设计；地图系统确定为可插拔生成器架构，第一章采用同心环形地图 |
| v0.2 | 2026-09-20 | 地图移动规则改为可自由折返（已访问节点仅可穿行、不再触发事件）；新增行动计数 `ActionClock` 与由外向内的侵蚀系统 `ErosionField`；撤离点回归外环与中环 |
| v0.3 | 2026-09-20 | 取消自动寻路，移动一律单步；新增 `MoveIntent` 作为未来传送／定点移动的接入点；新增第 12 节「扩展机制的预留接口」与第 13 节「待确认事项」 |
| v0.4 | 2026-09-20 | 依《背包乱斗》真实机制修正空间模型（详见报告 006）：移除装备栏；背包改为「棋盘 + 玩家放置包体」双层占用；新增暂存区（保留但不参战）；编译期邻接改为带约束的确定性插槽配对；冷却改用定点数以支持 ±2% 比例叠乘 |
| v0.5 | 2026-09-20 | 修正 4.2：插槽点亮是**去重计数**而非二分匹配（v0.4 写复杂了）；补充插槽的数据形态与两种效果方向；新增 4.3「数值约定」，确定结算公式为「基础值 × ∏(1+乘区) + 固定加值」、乘区为可扩展枚举且只能末尾追加、全流程定点数四舍五入 |
| v1.76 | 2026-09-24 | **078 补：作者对两个模板的定义**（5.11）。塔：横向的层、登上一层就不能向下 → `one_way` 从占位变成默认开着；沙漏：横置（`LatticeShape.orientation`，布局换轴）、撤离点在对侧那一列（`exit_count`，就是终点）、核心不是必须（`with_core`）、中途没有撤离点；形状的终点改成 `goals`（格 → 类型），校验按形状查终点类型、对侧撤离点不算中途 |
| v1.75 | 2026-09-24 | **8-2 第二章的两个底层模板：沙漏与塔**（报告 078；5.1、5.11 新、12）。分层格阵：`LatticeShape` 描述形状，`LatticeMapGenerator` 铺点 / 连边 / 断边 / 校验只写一遍，`LatticeTypeRules` + `LatticeTypeAssigner` 定类型（撤离点按层、每层配额、覆盖、不许相邻，规则进图）；`HourglassMapConfig` / `TowerMapConfig` 各自算形状；`LatticeMapLayout`（行列、箭头、空格子）；注册表各加两行，编辑器可选；「不回头」= 层间单向边（占位，语义等作者）；`PropertyForm` 支持整数数组；截图工具 `DEMO_GENERATOR` / `DEMO_SEED` / `DEMO_CONFIG` |
| v1.74 | 2026-09-24 | **8-3 事件构件**（报告 077；6.5、5.6、12）。五种条件（步数 / 段位 / 侵蚀深度 / 有某道具 / 点是什么）、五种后果（传送 / 改类型 / 照常发生 / 原地耗时 / 失去道具）；`EventContext` 加地图、步数、容器、段位与侵蚀深度回调；`NodeEvents.choose` 末尾挪人（`relocate` → `RunState.relocate`）、`type_changed` / `waited` 信号；`MapTravel` 对 teleport 不查边、新入口 `wait`；导入器拦撞车组合；休息 / 商店默认事件、裂隙与祭坛样例；结果页多认四样 |
| v1.73 | 2026-09-24 | **第 8 阶段规划与 8-1 传送点**（报告 076；5.6、12）。切成 8-1 传送点、8-2 第二章形态、8-3 事件构件、8-4 道具与敌人、8-5 局外成长；8-1：`MoveIntent.TELEPORT`、`MapEdge.PORTAL`、导航解析、`MapTravel` 认 teleport、生成器配置与 `_add_portals`、校验先摘下传送点、求解与路口剔除、紫色虚线、编辑器传送模式 |
| v1.72 | 2026-09-24 | **侵蚀本体**（报告 075，069 第 5 步 = 第 7 阶段；5.7、8.4、12）。`ErosionField`（逐层向内、预警、结算、存档）+ `ErosionMechanic`（时间表 + 效果清单）+ `ErosionEffect` 构件（扣体力 / 损坏一件 / 丢钱，基类四道门：开关、起始层、仅终局、概率 —— 作者要求都不写死）；`MapTravel._settle_penalty` 交给 `settle`；导入器把「必须预警」写成校验；地图垫色与红环、HUD 一句、日志。第 7 阶段完成 |
| v1.71 | 2026-09-24 | **猎手专属池与段位**（报告 074，069 第九节；8.5）。段位只看步数：`HunterMechanic.bracket_steps` 划段，`HunterDef.strength_by_bracket` 每段几档（表空退回强度规则）；`HunterSystem.bracket()` / `strength_for()`；猎手专属池 `enemy_pools/hunters` 占位；木桩按同一张段位表分段（`DummyBuilder.build_by_brackets`），胜率表 wanted = 猎手表里这一段的档 |
| v1.70 | 2026-09-23 | **校准工具**（报告 073，069 第 4 步；8.5、11）。`core/run/calibration`：`CalibrationRecorder`（每步记玩家配置，正式游戏默认装）、`DummyBuilder`（按段长分段、木桩 = 段里离平均读数最近的真实配置、没快照时开局装备当第 0 段）、`HunterBench`（木桩 × 池里每档打 N 场 → 胜率，并排 wanted / best，同种子可复现）；两个命令行入口。只做统计不改数；数值等多场测试 |
| v1.69 | 2026-09-23 | **角色技能接口**（报告 072，069 第 3 步；8.1、8.5）。`CharacterDef.skills`（一局规则的效果构件）编进 `RunState.buff_context()`，三个构件侦察 / 潜行 / 逃跑（取大 / 相乘 / 相加）登记在 `RUN_EFFECTS`，猎手系统 071 已读的三个字段由此有了来源；`RunState.character` 定义读档找回；第二个占位角色「侦察兵」 |
| v1.68 | 2026-09-23 | **猎手核心**（报告 071，069 第 2 步；新增 8.5、10.1、11）。内容种类 `hunters`（`HunterDef` 一个等级一份）；行动逻辑与战败后果各一张注册表（5 + 6 个构件）；`MapMetric`（steps / absolute）；`HunterSystem`（出现于最远点、领地互斥、按步回合、感知提示、开打前合成事件屏「迎战 / 逃跑」、探索度现造敌人、掉落倍数、存档、`hunters` 随机流）；`HunterMechanic` 是难度清单里的机制；`NodeEvents.extra_defs` + `fight_hunter` / `flee_hunter`；`RunContext` 三个技能接口字段；地图上红环标记 |
| v1.67 | 2026-09-23 | **进阶难度骨架**（报告 070，069 第 1 步；新增 8.4、10.1、11、12）。难度是机制清单：`DifficultyDef`（内容种类 `difficulties`：`mechanics: Array[RunMechanic]`、`effects`、`requires_unlock`），`RunMechanic` 是效果树之外的新抽象根（`install(run)` 幂等、登记表 `RUN_MECHANICS`），`ErosionMechanic` 空壳占位；`RunState.difficulty_id` 跟存档、`install_mechanics()`、修饰进 `buff_context`；`MetaState.unlocks` + 局外屏占位开关；开局屏「难度」一栏只列能选的。没有难度定义 = 普通；侵蚀改口为高难度才开的机制 |
| v1.66 | 2026-09-23 | **搜索揭示重做**（报告 068，058 / 059 顺序里的第 6 项；6.2）。揭示从「一批一条 Tween」改成**一件一件来**：当前按稀有度计时（`SearchRules.reveal_seconds`，每档几秒、非递减、和体积无关、没有角色倍率），到点亮出来，按栏位顺序挑下一件，只知道当前与下一件；`LootView.advance(delta)` 推进、`current_uid` / `next_uid` / `progress`；没亮的能拖但只能在容器里挪（`DragLayer.drop_filter` 第二道门，容器屏给规则）、正在搜的锁住；去掉光标距离 |
| v1.65 | 2026-09-23 | **开局预选与 `CharacterDef`**（报告 067，058 / 059 顺序里的第 5 项；7.1、8、8.1、10.1、11、15 节第 5 / 8 项收掉）。新内容种类 `characters`：基线覆盖项、体力上限、棋盘尺寸、初始包、带入上限（-1 = 不限，没有搜索速度）；`RunState.start(..., character, layout)` 按角色开、开局屏摆好的棋盘原样进一局、存档记角色 id；开局屏重写：中间角色的棋盘（初始包摆好）、右边仓库格子、**从仓库往包里拖，放得进的就是带的**；包进不了仓库（`GridInventory.accept_filter` 接 `MetaState.keeps`）；`MetaRules.first_kit` 仓库空的第一局发第一套（教程关之前的占位）；没有角色定义 = 老路 |
| v1.64 | 2026-09-23 | **删地图沙盒**（报告 066，作者拍板）。它砍到只剩生成就是地图编辑器的子集，「走」正式游戏的地图屏已完整；`ui/map/map_sandbox` 与它的帧测试删除，启动选择器剩两个沙盒、三个编辑器。以后单独试地图机制在正式游戏里加「开发者开局」 |
| v1.63 | 2026-09-23 | **事件屏改版**（报告 065，作者要求）。`event_screen` 选项页与结果页共用两栏大框（1320×760）：左栏 640 宽整块是图（铺满、按比例裁，没图就深底色占位），右栏标题、可滚正文、贴底的整行选项，锁住的原因写在按钮底下；结果页沿用该点事件的配图。编辑器预览同样两栏 |
| v1.62 | 2026-09-23 | **事件编辑器**（报告 064，作者要求；10.5、11）。`ui/event_editor`：写文字、导入配图（复制到 `assets/events/<id>.<ext>`，`EventImage` 拿不到资源就按原始文件读，事件屏共用）、选项与条件 / 后果由 `PropertyForm` 反射生成、预览照事件屏画、挂进 `NodeRules.events_by_type`；校验与产出都走导入器（JSON + `.tres`），草稿缓存照道具编辑器。按性价比做在项目里而不是独立 exe：注册表、校验、id 表一行都不用复制，要独立就用导出预设 |
| v1.61 | 2026-09-23 | **事件层与容器屏合一**（报告 063，058 / 059 顺序里的第 4 项；6.5 新增「事件层」、8 节流程图、10.1、11）。事件是内容（新种类 `events`：文字、图像占位、选项；选项的条件与后果是构件、走注册表两张新表）；`NodeRules.events_by_type` 按类型配，`EventPlacer` 生成时按 `content_seed` 定进节点、已有的不覆盖、随机点揭开后再配；`NodeEvents.handle` 变两段（`pending` / `event_pending` / `choose`），后果的旗子决定接下一个 / 开搜索 / 开店 / 开战 / 用过；等着选的跟着存档；**没有事件定义 = 老路**，现有套件一条不改；搜索点的「要不要搜」是默认事件 `search_default`；`GameFlow` 排事件屏、结果页插队首、队空了显示等着选的；战利品屏与搜索屏合成 `container_screen`；六个作者文件当内容占位 |
| v1.60 | 2026-09-23 | **buff 骨架**（报告 062，058 / 059 顺序里的第 3 项；9.2、8.2、6.1、10.1）。效果树第四个分支 `RunEffect`（作用域 RUN）往 `RunContext` 里加数，五个构件（体力上限、开局钱、多搜几次、商店价、幸运）登记在注册表；`RunBuffDef`（内容种类 `run_buffs`）局外 / 一局同一套定义、`mods` / `rules` / `effects` 与套装档位同一种分法、`tags` 当标记、`duration_steps` 时限；`MetaState.active_buffs`（占位开关列表）开局记进 `RunState.meta_buffs`，`map_buffs` 每步递减；掉落上下文改由 `RunState._loot_context` 造：幸运从 buff 来，**道具 / 套装的战利品效果第一次真的接进一局**（9.2 说的那条查询此前没接） |
| v1.59 | 2026-09-23 | **仓库格子化、结算屏一键置入、图鉴**（报告 061，058 / 059 顺序里的第 2 项；8.2 重写，15 节第 4 项定案）。仓库是不要求包的格子，大小是 `MetaRules.warehouse_size`（新内容种类 `meta_rules`，随局外成长）；撤离不直接进仓库 —— 棋盘原样带回（`MetaState.board`，非包道具按原位置、包换成默认背景），结算屏 / 局外屏共用的仓库面板拖或一键置入，放不下就停在那一件提示，没清空 `can_begin()` 拒绝开新局；图鉴 `codex` 累计件数、点亮一次、包也计；`MetaState.keeps(def)` 一处决定什么能存进局外；一局结束时（进结算屏之前）就 absorb、存 meta；`MetaSave` 版本 2，仓库大小以存档为准 |
| v1.58 | 2026-09-23 | **暂存区按点清空**（报告 060，058 / 059 顺序里的第一项；3.4 定稿，15 节第 7 项收掉）。「发生过事的点」= 踩上去时 `NodeEvents` 真的处理了什么，`last_handled_id` 记着、跟着存档；`RunState.step_to` 走出它时清暂存区、发 `storage_dropped`、清回 -1；出生点、岔路、路过的点、走不成的都不清。提醒档位是 `GameSettings`（`user://settings.json`，有就提 / 稀有度 / 价值 / 从不，表 + 阈值），`StorageWarning.at_risk` 挑要提的，地图屏走之前弹面板（照走 / 先整理背包 / 取消）；新增设置屏 |
| v1.57 | 2026-09-23 | **059 设想：事件层、统一容器屏、局外 buff 与地图 buff**（未实施）。每个节点踩上去先过事件屏（没配事件的战斗点是转场），选项带条件与后果构件，搜索点「要不要搜」是事件、搜索与战利品是同一个容器屏；buff 是同一套构件、两种生命周期（局外 / 一局），效果树加 `RunEffect`（RUN 作用域）分支，标记型地图 buff 供事件分支查；暂存区改为**离开发生过事的点时清**（058 第五节）。顺序重排；15 节第 11 项更新 |
| v1.56 | 2026-09-23 | **058 第二轮：作者八条回应**，设计修订：搜索速度不做属性；暂存区每走一步清空；图鉴累计件数、点亮一次；带入的限制就是初始包的空间、包只出不进；仓库大小随局外成长；撤离后保留棋盘、结算屏「一键置入」放不下就停下提示；顺序改为 3 → 4 格子化 → 7 结算置入 → 4 图鉴 → 2 开局预选 → 5 搜索 → 1 外框；15 节第 11 项更新 |
| v1.55 | 2026-09-23 | **作者五条提议整理与评估**（报告 058，未实施）。节点层（现状已是叠层，建议加共用外框）；开局预选：角色占位 + 从仓库带入的限制（3×3 格子按形状、3 件、稀有度上限，都是数据），建议此时建 `CharacterDef` 收掉 15 节第 5 / 8 项；暂存区改为**按节点清空**（15 节第 7 项由作者定案，待实施），离开前按设置档位提示；仓库格子化 + 包另存列表（分流规则只写一处，将来可删）+ 图鉴（带出过就点亮、记累计次数）；搜索揭示改为「当前一件 + 下一件」、耗时随稀有度、未搜的可在容器内挪位、去掉光标距离。性价比与矛盾、建议顺序（3 → 2 → 5 → 4 图鉴 → 1 → 4 格子化）与六个待拍板问题见报告 |
| v1.54 | 2026-09-23 | **M6-3 打磨，M6 完结**（报告 057；8.2、8.3、12 节）。仓库里的东西带进下一局：开局屏勾上，`GameFlow.begin(..., from_warehouse)` 从仓库拿走并立刻存 meta —— 撤离了回来、死了就没了，搜打撤的循环由此闭合。撤离前一道确认（付多少钱、棋盘上多少件背出去、暂存区里多少件带不出去 —— 3.4 的提示不是挽留）。商店屏每件一行（稀有度色、格数、价）；局外屏「再来一局」。12 节阶段 6 标完成 |
| v1.53 | 2026-09-23 | **M6-2 搜刮界面**（报告 056；6.2 的「渐进揭示」一节改成落地的样子）。`LootView` 是 `InventoryView` 的子类：揭没揭示是视图自己的表（**表现层的事，不进 core**：容器里的东西一开始就在，揭不揭示都一样），没亮的画剪影 + 噪点、抓不起来；一个 `Tween` 驱动一批的进度，按栏位顺序亮；快速搜索推到终点。战利品屏与搜索屏共用它，同一层 `DragLayer` 盖着容器、棋盘、暂存区，亮出来的直接拖走。搜索会话改成**逐次装**：`SearchSession.haul_box` 每搜一次装一批（`LootPacker.add`：放不下换高一格的容器、东西原位搬过去、uid 不变），`haul()` 就是它，拿走的不再算收获；搜索屏里亮过的到了战利品屏不再重揭（`GameFlow.seen_loot`） |
| v1.52 | 2026-09-23 | **M6-1 场景流骨架**（报告 055；8 节重写，新增 8.1～8.3）。状态机是纯逻辑的 `GameFlow`（`core/run`），导演 `GameDirector` 只是它的皮、是主场景 `ui/game/game.tscn` 的根 —— **不是 autoload**（2 节的图改过来：设计稿里 GameDirector / RunState / EventBus 三个 autoload 一个都没有，核心逻辑层没有全局状态）。屏分底屏与叠层，叠层 `add_child` / `queue_free` 叠在地图上；节点事件同步发生、一步之内可能连着几个，flow 排成队一屏一屏看，结束了最后一定是结算。开局装备 `LoadoutDef` 走内容管线（`loadouts`，排在道具之后；校验至少一个包）；结算 `RunResult` 只算棋盘上的（3.4）；局外 `MetaState` / `MetaSave`，保留规则只在 `absorb()` 一处（撤离全进仓库、钱带出；战败全失 —— 15 节第 4 项的假设，等作者定）；仓库有自己的 uid 空间。`RunState.tally` 计胜负、`NodeEvents.last_battle` 给回放查名字 |
| v1.51 | 2026-09-23 | **现状整理**（报告 054）。并入平行的地图分支（作者七条 / 设想改号 052 / 053）；头一行的版本与状态、11 节目录结构换成真实的树、12 节阶段 4～6 标完成、15 节第 3 / 5 条更新；新增活文档 `docs/status.md` |
| v1.50 | 2026-09-23 | **作者七条**（报告 052；与 M4/M5 并行做的，合并时报告改号 045 → 052）。（一）路线长度 = 环数 × `route_length_factor`（1.5），多出来的步数同环横着走、随机撒在各环上；落点先挑下一环还有落点的。（二）中途撤离点只在**撤离环间**（`middle_rings`：正中间的一两环；大型两道占位），放在两条路线共用处（合流点 / 换乘点 / 换乘弧，`pivot_links` / `pivot_arcs` 带路线下标），三条路线两两共享；删 `extract_every_rings`、`bailout_every_rings`；校验 `extract_band`。（三）路线尽头不当高危区岔出点、不被吸收 —— 以前「只长到两个点就吸收岔出点」会把偏搜索路线的收尾撤离点吃掉。（四）高危区出入口数的是**区内连着区外的点**，不是边；隔离按点留口。（五）节点数是范围不是定数：`MapScaleProfile.nodes_by_rings` 按环数给范围、每局抽总数、各环按基准比例分（`counts_for_total`）；中环加 `mid_ring_extra_slots`（3）个槽位，填充率六七成；小型撤离间距改 3。（六）喘气处按路线步数放（`haven_at`：中型 1/3、2/3，小型都在一半）；删 `haven_after_progress` 与 `haven_early`。（七）切向弧的圆心：以前从两端反推、挑离原点近的，原点是画布左上角，下半张图的弧全反着凸 —— 圆心就是画布中心，`draw_edge` 接 rect |
| v1.49 | 2026-09-23 | **M5 运行状态与存档**（报告 051）。7 节重写：`RunState`（纯 RefCounted 的壳：开局生成 → 放敌人 → 付费撤离点 → 棋盘与暂存区 → 节点事件接线；`pick_spawn` / `step_to` / `try_extract`；战利品进 `pending_loot`、买的与事件给的进暂存区、`equip` / `unequip`；玩家开战时从棋盘编译）、`RunRNG`（1.4 的分流随机源，序号跟着存档）、`RunSave`（带版本号的 JSON，内容库不进存档，开着的会话视为离开）。地图沙盒改成 `RunState` 的一层皮：存档 / 读档 / 撤离三个按钮，拾取自动进暂存区 |
| v1.48 | 2026-09-23 | **探索度**（报告 050）。作者要求随机点与搜索点造出来的敌人跟当前位置、总步数、搜索次数挂钩：`StrengthRule` 加探索度一组（步数每 N 步、累计搜索每 N 次各加一档、各有上限），`NodeEvents.exploration()` 只在踩上去才造敌人时传入；生成时放好的敌人不变（看到的就是打到的） |
| v1.47 | 2026-09-23 | **M4-5 经济**（报告 048）。新增 6.6：`EconomyRules`（打赢 = (基础 + 每档) × 深度 × 难度；商店格数、稀有度权重随深度上偏、价 = 价值 × 倍数、刷新费越刷越贵；付费撤离点几个、收多少 —— 50 占位）；`Wallet`（不知道任何数值，不够一分不动）；`ShopSession`（货架由节点种子 + 刷新次数定，存档只记刷新与卖掉的格子）；`PaidExtracts.mark`（生成之后标最深的撤离点，费用跟着图存）；`NodeEvents` 加 `rewarded` / `shop_opened(session)` / `shop_closed` / `extract_reached(node, fee)` / `pay_extract_fee`。沙盒：货币进 HUD、商店按钮、付费撤离点提示、预览里「打赢 +x 币」 |
| v1.46 | 2026-09-22 | **M4-3 随机点与搜索点、M4-4 节点事件接线**（报告 047）。6.2 重写 + 新增 6.5：`NodeRules`（随机点权重只认 A/S/R/V/Q、搜索规则、`loss_cost`、`rest_restore`、事件结果权重、战斗时限；章节按 id 引用）、`SearchRules`（次数、非递减的遭遇曲线、件数、稀有度权重随深度与危险上偏）、`SearchSession`（搜几次玩家定，遭遇即止，进度记进内容，遭遇的敌人到那一刻才造）、`NodeEvents`（`on_node_event` 的接收方：打一场、掉落、扣体力、core 输了直接战败、休息、事件、商店 / 撤离信号；随机数从节点种子按用途派生）、`LootPacker`（尸体容器与收获共用）、`EnemyPlacer.place_one`。沙盒接上事件与搜索按钮 |
| v1.45 | 2026-09-22 | **M4-2 掉落规则**（报告 046）。6.1 重写：`DropRule`（按稀有度的基础掉落率表、非递增校验；难度 / 幸运每级加多少；珍宝概率、稀有度权重、珍宝标签占位）；`DropResolver`（每件各掷、珍宝掉自身没有的、期望件数、尸体容器 = `GridInventory`）；`LootContext` 加难度、幸运与 `sources`，M2 的四个量各有归宿；`DropBonusSource` 接口 + `MetaDropBonus` / `MapDropBonus` 两个占位实现。`ChapterDef.drop_rule`；管线新种类 `drop_rules`。沙盒悬停战斗点多一句「预计掉 x 件，珍宝 y%」 |
| v1.44 | 2026-09-22 | **M4-1 敌人池**（报告 045，含 M4 四步规划）。新增 6.0：`EnemyDef`（本色档位、流派标签可多个、基线覆盖、招牌道具）、`EnemyPool`（配置表：条目按环种类 / 节点类型 / 危险过滤、档位表 = 件数 + 棋盘 + 倍率 + 稀有度上限、`StrengthRule` 全加法：深度 + 危险 + 类型 + 难度 + 规模、默认组装规则「通用 + 流派」）、`EnemyPlacer`（生成之后的第二遍，只用节点 `content_seed`；大件先摆、放不下换小的补）、`EnemyKit`（内容 → 棋盘 → `BattleCompiler`，预览 = 编译）。`ChapterDef` 加 `enemy_pool`（按 id）与 `difficulty`；内容管线加 `enemies`、`enemy_pools` 两种；`tools/normalize_content.gd`。流派是标签：混伤 = 两个流派。沙盒悬停战斗点见敌人一行摘要 |
| v1.43 | 2026-09-22 | **M3-6 渲染与地图沙盒**（报告 044）。角度求解器 `RingAngleSolver`（形态无关：层 + 圈上的位置；由外向内、圆周均值 + 告警、单调校验、无随机），`RingLayoutBase` 让随机生成的与手绘的图共用它，按 `MapGraph.version` 缓存；切向边画弧；`MapView` 加 VISITED 去饱和、当前点呼吸、可达提示、路线加粗、悬停信号；核心改红。`ui/map/map_sandbox`：从 `chapter_01` 开局，挑出生点（路线卡 + 悬停加粗）、一步一步走、HUD（行动点 / 距最近撤离点 / 休息区 / 核心 / 体力）、单步预览、换种子。启动选择器第五个入口 |
| v1.42 | 2026-09-22 | **M3-5 章节定义走内容管线**（报告 043）。`ChapterDef`（id、display_name、map_source；侵蚀、敌人池、掉落表到时候各加一个字段）；`ContentPaths` 加 `chapters`、排最后；`import_chapter` + 严格校验。管线补的通用能力：`Vector2`、字典里整数值的浮点两头写成整数、声明成引擎基类的字段靠 `type` 造类。`data/authoring/chapters/chapter_01.json`（由 `RingMapConfig.sample(6)` 倒出）→ `data/chapters/chapter_01.tres`。地图编辑器加「章节」栏：载入 / 存回 |
| v1.41 | 2026-09-22 | **M3-4 行动计数与单步移动落地**（报告 042）：`ActionClock`、`MoveIntent`、`MapNavigator`（只读、无多步入口，测试守着公开方法清单）、`MapTravel`（五步结算顺序一处落地，侵蚀与节点事件是鸭子类型钩子，假钩子记次序）。渲染：画布按固定环距算、不随视口缩，`MapView` 加拖动与缩放 —— 作者说图看着太挤 |
| v1.40 | 2026-09-22 | **作者六条**（报告 041）。（一）节点数仍随环数增长：规模模板的 `nodes` 范围按环数插值。（二）每环 节点/槽位 ≤ `fill_cap`（0.9，严格 < 1）：内环也不填满；`RingSpec.node_count = 0` 从「填满」改成「填到上限」。（三）出生点是一种节点 `spawn`，图上写「生」，网格符号暂定 `P`；固定、不参与 mix / 配额 / 校准；校验 `spawn`。（四）休息区与商店只在路径走过 `haven_after_progress`（1/3）之后才出现，按环深算；前一段的点不算进覆盖；校验 `haven_early`。（五）`RouteStyle.min_share`：偏搜索的路线搜索点至少八成，分配时先保底、换走前先问；搜索点的收益从 1.1 降到 0.6，不然八成搜索的路线性价比太高、校准会把别的路线也换成搜索点去追；档位跟着改。（六）非路线节点只剩战斗的根子是 `apply_scale` 新建的环没有权重表 —— 加 `ring_template`。校准只在事件点之间换，`MapNodeTypes.STRUCTURAL`（core / spawn / extract / junction）不动 |
| v1.39 | 2026-09-22 | **作者三条数值反馈**（报告 040）。（一）节点数由规模模板决定：`MapScaleProfile.nodes`，中型 45~50（原先 6 环 64 个）。**槽位不动，减的是每环真有节点的槽位数**（第一版缩了槽位，作者指正）：点匀着散在一圈上、由内向外挑并尽量对上内环的点，空白区是稀疏的结果；同环的弧可以跨过至多 `tangential_span_max`（3）个空槽，再远就断开。（二）普通战斗比例降：每环权重 battle 3 / search 3 / event 3 / random 2 / elite 1（原 5/3/2/1/1），mixed 风格的 mix 改成三者均等。（三）撤离点之间最短路至少 `extract_gap` 步（模板：小 4、中 4、大 5；`extract_min_distance` 可覆盖），进校验 `extract_spacing`；`extract_every_rings` 改 4、combat 的 `bailout_every_rings` 改 4 —— 窗口跨度小于间距时相邻窗口放不下两个出口，只能靠重试碰。顺带：合流之前挤不开改成这次作废，不再退到「合流」（那就是提前合流）；横着挪不再挪到别的路线上 |
| v1.38 | 2026-09-22 | **M3-3c 类型分配落地**（报告 039）。`RingTypeAssigner` 按 5.4 步骤 5 的 0→g 填类型，与拓扑分开。图自身的规矩（配额、覆盖、喘气型不进高危区、不许相邻、高危区内容、每 N 环一个撤离点）进校验，规则写进 `layout_meta.type_rules` 从图上读；路线的 mix 与风险收益档位**只在生成时尽力**（035）。实现里定下的几条：覆盖不算高危区里的点；覆盖修正与撤离点都不盖掉已经是必须型的节点（第一版放商店时把休息区盖掉了，覆盖白做）；校准换进来的精英只限 mix 里列了它的路线；分数记成 `risk_x100` 整数（浮点过 JSON 会变）。`mandatory_types` 进配置；`type_risk` 的搜索点值是每搜一次的，定档时乘 `reference_searches`。批量统计多了路线表（落进档位几成、性价比离散、每种风格的类型构成、覆盖最远步数） |
| v1.37 | 2026-09-22 | **编辑器试用反馈七条**（报告 038）。（一）`RingSpec` 的 `slots` / `node_count` 在建环时写成实数，不再留 0（0 仍是合法的「自动」）—— 编辑器里看到一排 0、图上却十几个点，只会让人以为数据没对上。（二）**路不许交叉**：新增「不交叉」小节；骨架、高危区、候选边、补边全走 `_link`，斜路碰上另一条对角线时按「凑四岔 → 借道 → 放弃」处理；校验加 `edge_crossing`；交叉按几何算。高危区改成**每长一步当场建路**。（三）（四）5.9 加岔路口画法：四点互连画四岔、三点互连画三岔，先四后三、由内向外、最后画（`MapJunctions`）。（六）换乘改成**相邻直连优先、换乘弧兜底**，窗口 `pivot_window`；`pivot_every_rings` 删除。（七）换乘次数进规模模板 `MapScaleProfile.pivots`：小型 1、中型 1~2、大型 2~3（占位）。新增 `_reconnect_islands`、换乘弧短的一段不通走长的一段 |
| v1.36 | 2026-09-21 | **M3-3b 手绘地图落地 + 规模模板**（报告 037）。（一）`MapGridText.parse / render` 与 `GridScriptGenerator`（注册为 `grid_script`）：作者的两张图往返逐字节相同、过通用校验与 `ZoneRules`；5.4.1 补了七条实现细则（岔路口紧挨着点、v0 老格式、穿环的 `\|`、`danger_rows` 原稿、出生点占位规则、`[links]` 段）。`ZoneRules.validate` 抽成静态，环形与手绘共用，只管 danger ≥ 2 的区域。计划里「生成图导出再解析 `to_dict()` 一致」改为**拓扑等价** —— 两种形态的 layout 载荷与 id 编法本来就不同。（二）新增 5.4.3 `MapScaleProfile`：出发点 / 高危区数量 / 高危区规模的上限随规模变，是数据不是代码；小型有且只有一片高危区，中型 1~3 片且每条路线至多一片，大型占位。`danger_zones` 数组换成 `zone_spec` + `zone_count` + `zone_soft_cap`；`DangerZoneSpec` 的 `min_rings` / `required` / `soft_cap_by_rings` 删除（都归规模模板管）。路线标注多了 `zone_ids`。编辑器左栏从规模选起 |
| v1.35 | 2026-09-21 | **高危区重新定义**（报告 036，作者给的新定义）。**长成什么样**（`ZoneRules`，进校验，写进 `layout_meta.zone_rules`）：至少 3 个相连的点、可跨环、上限 9；出入口上限随规模放宽（3~4 → 2，5~6 → 3，7~9 → 4）；多个出入口尽量在区内相距最远。`zones[id].gate_id` 改为 `gate_ids`。**怎么长出来**（`DangerZoneSpec`，生成规则）：高危区也是一个「起点」，路线过半程且旁边有空地时从路线节点上岔出来、立刻再长一步，之后与路线同节拍生长到软上限（由环数决定，4~5 环是 4 个点）或没地方；只长到两个点的把岔出点也划进去。`ring_range` / `size` / `gate_prefers_elite` 删除，`min_rings` 默认 5 → 4（作者举的例子里 4~5 环的小图有高危区）。「换乘弧与高危区互相挤占」那段作废 —— 高危区不再事后圈地。新增步骤 8c 救孤点。同环的槽位偏移改用整数算（浮点投影在 25 个槽位的环上会把相邻槽位量成 1.0000001）。640 张图全部第一次尝试生成成功 |
| v1.34 | 2026-09-21 | **路线是生成规则，不是合格条件；单条路径有长度上限**（报告 035，作者指正）。（一）校验里与路线有关的全部拿掉：骨架完整、换乘点、高危区不含骨架节点，以及计划中的路线风险收益区间 —— 它们是生成器怎么长图的规则，留在 `graph.routes` 里只是标注；编辑器里那几条彩色粗线就是它，加了图例与开关。（二）新增 `edge_max_ring_offset` / `edge_max_slot_offset`（默认各 1），写进 `layout_meta`；跨环的槽位偏移用**外环**的槽位量（内环六个槽位时一格 60°，拿它量等于没限制）。`route_drift` 默认 2 → 1 并受上限约束，早先「按环长缩放」的做法作废。（三）由此连带：正对空白区的点可以没有向内的边；路线撞上空白区时**沿当前环横着挪**而不是拉长边跳过去；断边改为**不许断出孤岛**（断之前查连通），因为「每个点都有向内的径向边」不再成立 |
| v1.33 | 2026-09-21 | **地图编辑器、地图来源、生成器四处改动**（报告 034）。（一）新增 5.3.1：`MapSource`（`RANDOM` 现场生成 / `PRESET` 载入 `data/maps/*.json`，预设可按对局种子重掷内容种子）；预设载入只问通用校验（`validate_common` 抽成静态），形态规矩是给生成器的不是给作者的。**地图编辑器**先生成再手改再存预设，不认识任何具体生成器：参数表单靠 `default_config()` + `PropertyForm` 反射，画法靠 `MapLayout` 注册表。（二）`DangerZoneSpec` 加 `min_rings`（默认 5，环数不够这一片根本不长、不算缺）与 `required`（false = 长不起来就跳过并记数）。（三）**路线改为同步生长**：所有路线一环一环一起落子，候选最少的先挑，间距与漂移量都以最外环槽位为单位按环长等比缩小；出生点之间至少隔 `entry_min_gap` 个槽位。（四）批量统计（`tools/map_stats.gd`）按规则汇总失败原因，揪出三个**被重试掩盖的算法缺陷**：高危区按空间相邻生长但区内未必有边（补生长树）、隔离会删光区外点的向内边（补边）、gate 边会被断边断掉（保护）。修完后 5 环平均尝试 2.89 → 1.50，剩下的失败全是 `zone_missing` 这一条配置层面的 |
| v1.32 | 2026-09-21 | **M3-3 环形生成器的拓扑与骨架落地**（报告 033）。实现暴露出三处设计要补：（一）每环的**槽位数记进 `layout_meta.ring_slots`** —— 末尾槽位空着时从节点上推不出来；（二）「环越靠里越短」这条校验看的是**槽位数不是节点数**，外环挖了空白之后节点可以比内环少，那是合法的（第一版写成节点数，`sample(3)` 当场红了）；（三）**换乘弧与高危区会互相挤占**：换乘把整段弧保护起来，相邻路线两两换乘基本会占满一个环，而高危区必须避开受保护节点，所以它得落在两个换乘环之间。另外「高危区长不起来」从「悄悄少一片」改成**这一次尝试作废** —— 缺了设计好的高危区也是降级的图。`radius_step` 默认值 110 → 30：它与 `arc_per_slot` 只有比值有意义，原值会算出第五环 57 个槽位。节点类型这一步全填 `battle`，留给 M3-3c |
| v1.31 | 2026-09-21 | **M3-2 生成器抽象落地**（5.3 与实现对齐，报告 032）。子类只实现 `build`「造一张图」，**校验与换种子重试由基类包办**；`generate(cfg, base_seed)` 同种子同结果，每次尝试的种子由 `derive_seed(base, i)` 单独算得出来，「第 7 次尝试」可单独复现。新增 `MapValidation`：失败带一个 `rule` 键，**跨尝试按规则聚合** —— 重试几十次后「30 次里 28 次是不连通」比最后一次的细节有用得多。通用校验只管与形态无关的那几条，其中**死胡同是合法的**（可以走回头路，死路不是问题），这条最容易被顺手加进校验。`MapGeneratorRegistry` 照 `EffectRegistry` 的样子来，表先空着，测试检查「登记的每一条都指向真实存在且确实是 MapGenerator 子类的脚本」|
| v1.30 | 2026-09-21 | **体力落地为 `core/run/vitality.gd`，且不知道任何数值**（7.1 重写）。作者要求休息回复量不要写死，只给体力留一个公用方法。于是 `change` / `spend` / `restore` / `set_max` 全由调用方传数，返回**实际**变化量（打到 0 封顶、超上限截断时请求量与实际量不是一回事）；归零发 `depleted`，战败由监听者判 —— 本类不知道「战败」，也不知道 BOSS 输了要直接战败，那是调用方看一眼节点类型的事。**角色系统只留占位不建**：`PLACEHOLDER_MAX` 一个常量，将来 `RunState` 改从角色定义读，本类与调用方一行不改；与 `CombatantBaseline` 是同一种占位，刻意不建 `CharacterDef` —— 只有两个占位点，建了也是空壳 |
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
