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

1. **异形格子背包**：物品占据不同形状/尺寸的格子，可旋转，跨容器拖拽
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
@export var cells: Array[Vector2i] = [Vector2i(0, 0)]   # 相对原点的占格
# 运行时预计算 4 个旋转：(x, y) -> (-y, x)，再平移到 min = (0, 0)

# core/inventory/item_def.gd —— 静态定义，全局共享只读
class_name ItemDef extends Resource
@export var id: StringName
@export var shape: ItemShape
@export var rarity: int
@export var can_rotate: bool = true
@export var combat: CombatProfile             # 冷却、伤害、触发方式
@export var adjacency: Array[AdjacencyRule]   # 邻接加成规则

# core/inventory/item_instance.gd —— 运行时实例，可变
class_name ItemInstance extends RefCounted
var uid: int             # 全局自增唯一 id
var def: ItemDef
var rotation: int        # 0..3
var origin: Vector2i     # 在所属容器中的左上锚点
var container_id: int
var state: Dictionary    # 耐久 / 充能 / 随机词条
```

**`ItemDef`（共享只读）与 `ItemInstance`（运行时可变）必须分开。**
存档只写 `def.id` 字符串 + `state`，不写 Resource 路径 —— 否则改动资源路径会导致存档失效。

### 3.2 GridInventory：一个类服务所有容器

```gdscript
class_name GridInventory extends RefCounted

var id: int
var size: Vector2i
var _occupancy: PackedInt32Array    # size.x * size.y，存 uid，0 表示空
var _items: Dictionary              # uid -> ItemInstance
var _blocked: PackedByteArray       # 支持非矩形容器（如 L 形背包）
var accept_tags: Array[StringName]  # 装备栏过滤用

func can_place(shape_cells: Array, origin: Vector2i, ignore_uid := 0) -> bool
func place(inst: ItemInstance, origin: Vector2i, rot: int) -> bool
func remove(uid: int) -> ItemInstance
func find_first_fit(shape: ItemShape, allow_rotate: bool) -> Dictionary
func neighbors_of(uid: int) -> Array[int]     # 4-邻域内的其他物品，战斗编译期用
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> GridInventory
```

**玩家背包、敌人尸体、商店货架、仓库、装备栏全部复用这一个类。**
装备栏 = 1×1 且带 `accept_tags` 过滤的容器。尸体 = 一个临时生成的容器。

这个复用是后续掉落系统几乎零成本的原因，不要为尸体/商店另写容器实现。

### 3.3 跨容器移动必须原子化

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

### 3.4 实现要点与 Godot 特定坑

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

### 3.5 验收标准

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

### 4.2 编译阶段（背包 → 战斗单位）

这是背包构筑类游戏的灵魂，必须独立成一个 pass：

```gdscript
# core/battle/compiler.gd
static func compile(inv: GridInventory) -> CombatantSpec:
    # 1. 收集所有 ItemInstance
    # 2. 构建邻接图：对每件物品求其占格 4-邻域中的其他物品 uid
    # 3. 分层结算 modifier：flat → percent → final_override
    #    （分层顺序必须一开始定死，后期修改会导致所有物品需重平衡）
    # 4. 产出 abilities: [{cooldown_ticks, trigger, effect, snapshot_stats}]
```

`compile` **必须是纯函数**：同样的背包永远编译出同样的 spec。
这样 UI 可以在玩家拖动物品时实时显示预计 DPS / 有效血量 —— 这是此类游戏的核心爽点。

### 4.3 模拟循环

```gdscript
const TICK_HZ := 20                     # 20Hz 逻辑帧，定步长

func run(a: CombatantSpec, b: CombatantSpec, rng) -> Array[BattleEvent]:
    var tick := 0
    while tick < MAX_TICKS and a.hp > 0 and b.hp > 0:
        _advance(a, b, log)             # 冷却累积 → 触发 → 结算
        _advance(b, a, log)
        _tick_dots_and_buffs(log)
        tick += 1
    return log
```

**避坑：用整数 tick 计数，不要用 float 累积冷却。**
浮点累积在长战斗中会产生精度漂移，导致回放与原始模拟不一致。
加速（haste）表现为"每逻辑帧累积 N 个 cooldown tick"，保持完全确定性。

### 4.4 表现层

`BattleView` 持有 `log` 与播放游标，`_process(delta)` 推进播放时间、消费到期事件、播放动画与跳字。

战斗中的物品图标直接复用 `InventoryView` 的渲染组件，视觉一致性免费获得。

---

## 5. M3 · 地图系统（可插拔生成器）

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
var type: StringName        # "battle"/"elite"/"shop"/"rest"/"event"/"extract"/"core"
var tier: int               # 难度/奖励档位，数值越高越难越肥
var erosion_band: int       # 侵蚀分档，数值越小越早被侵蚀（见 5.7）
var seed: int               # 该节点内容生成用的独立种子
var state: int              # State.UNVISITED / State.VISITED
var layout: Dictionary      # 布局载荷，由生成器写入、由布局策略解读
                            #   环形图: {ring:int, angle:float, radius:float}
                            #   分层图: {floor:int, col:int}

# core/map/map_edge.gd
class_name MapEdge extends RefCounted
var from_id: int
var to_id: int
var directed: bool          # 环形图全部为 false；保留字段供未来的单向形态使用
var kind: StringName        # "radial"/"tangential"/...，供布局策略决定画法
var action_cost: int = 1    # 通过该边消耗的行动点，默认 1

# core/map/map_graph.gd —— 拓扑无关
class_name MapGraph extends RefCounted
var layout_kind: StringName     # "ring"/"layered"/...，决定用哪个布局策略
var layout_meta: Dictionary     # 全局布局参数（环数、半径步长等）
var nodes: Dictionary           # id -> MapNode
var edges: Array[MapEdge]
var entry_ids: Array[int]
var goal_ids: Array[int]
func edges_of(id: int) -> Array[MapEdge]
func neighbors(id: int) -> Array[int]
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> MapGraph
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

- 以一个**核心点**为圆心，向外排布多层**同心环**
- 每个环上分布若干**节点**（可访问地点），节点之间由**线**连接：
  - **切向边（tangential）**：同环相邻节点之间的弧线
  - **径向边（radial）**：相邻两环之间的连线
- **越靠近中心，难度越高、奖励越高**
- **移动是自由的，可以走回头路。** 所有边双向可通行；节点内容一次性消耗，已访问节点仅可穿行，不再产生事件
- 约束玩家的不是拓扑，而是**时间**：每次移动消耗行动点；高难度下地图会从外向内逐层被侵蚀，在侵蚀区内移动会受到损失

玩家从最外环某个入口进入，自由深入或折返。深入 = 更肥的战利品 + 更危险的敌人；折返 = 消耗行动点，而行动点正在把出口推向腐烂。

#### 配置

```gdscript
# core/map/generators/ring_map_config.gd
class_name RingMapConfig extends Resource
@export var ring_count: int = 5                     # 不含核心的环数
@export var nodes_outer: int = 18                   # 最外环节点数
@export var nodes_inner: int = 6                    # 最内环节点数（线性插值）
@export var radius_step: float = 110.0
@export var angle_jitter: float = 0.35              # 相对格位角宽的抖动比例
@export var radius_jitter: float = 12.0
@export var tangential_chance: float = 0.55         # 同环相邻连弧概率
@export var radial_per_node: Vector2i = Vector2i(1, 2)  # 每节点向内连边数量范围
@export var entry_count: int = 3                    # 最外环入口数量
@export var type_weights_by_tier: Array[Dictionary] # 每档的节点类型权重表
```

#### 生成步骤

```
1. 核心节点：ring = 0，单点，type = "core"，tier = ring_count，erosion_band = ring_count

2. 逐环生成节点（r = 1..ring_count）：
   N_r = lerp(nodes_inner, nodes_outer, r / ring_count)  取整
   第 i 个节点：
     angle        = TAU * i / N_r + rng.randf_range(-j, j) * (TAU / N_r)
     radius       = r * radius_step + rng.randf_range(-rj, rj)
     tier         = ring_count - r      # 越内层 tier 越高
     erosion_band = ring_count - r      # 最外环 band = 0，最先被侵蚀
     layout       = {ring = r, angle = angle, radius = radius}

3. 径向边（无向）：
   对每个 ring r 的节点，在 ring r-1 中按角度距离取最近的 k 个
   （k 从 radial_per_node 随机），连 directed = false 的边，kind = "radial"

4. 切向边（无向）：
   对每对角度相邻节点，以 tangential_chance 连边，kind = "tangential"

5. 入口：最外环中按角度均匀挑 entry_count 个节点写入 entry_ids

6. 节点类型分配：按 tier 查 type_weights_by_tier 加权抽取，再应用硬约束（见 5.5）

7. 校验（失败则换种子重生成）：
   - 全图连通，每个入口都能到达核心
   - 每个节点至少有一条径向边（不存在只能同环打转的死区）
   - 每个入口到核心的最短路径长度 >= ring_count（不存在直通捷径）
   - 每个 erosion_band 内部连通（侵蚀推进时不会把幸存区切成互不相通的碎片）
```

### 5.5 难度与奖励的径向递进

`tier = ring_count - ring`，核心 tier 最高。tier 驱动三件事：

| 受影响系统 | 规则 |
|---|---|
| 敌人强度 | `EnemyDef` 按 tier 段位筛选 + 属性按 tier 缩放 |
| 掉落质量 | `LootTable` 的稀有度曲线与掉落件数随 tier 上移 |
| 节点类型分布 | 低 tier（外环）多普通战斗与撤离点；高 tier（内环）多精英、宝藏，撤离点稀少 |

节点类型的硬约束（加权抽取后做一次修正 pass）：

- 最外环入口节点强制为 `battle`（保证开局节奏一致）
- 核心节点固定为 `core`（章节 Boss）
- 同一环上 `shop` 不超过 1 个，`rest` 不超过 2 个
- 相邻节点不出现两个连续 `elite`
- **撤离点密度随 tier 递减**：外环每环 2~3 个，中环 1~2 个，内环 0~1 个（详见 5.8）

### 5.6 移动规则与行动计数

#### 移动规则

| 规则 | 说明 |
|---|---|
| 边双向通行 | 径向边与切向边均 `directed = false`，可自由折返 |
| 节点内容一次性消耗 | 首次进入触发事件（战斗 / 商店 / 休息 …），结束后 `state = VISITED` |
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

- **浅层侵蚀**：在侵蚀区内每次移动扣除 run 内持久生命值
- **深层侵蚀**（该节点所在 band 被侵蚀超过 `item_risk_after_bands` 层之后）：额外以 `item_risk_chance` 概率随机损坏或摧毁背包中一件物品

第二条与背包核心机制强绑定 —— **你刚抢到的战利品正在你手里烂掉**，这是逼玩家尽早撤离的最有力压力，也让"多搜一个点"的贪心有了具体代价。

> **待确认**：上述方案假设 run 内存在持久生命值（跨战斗保留、可由休息点恢复）。
> 若最终决定不设持久生命值，改为**只损坏物品**即可，`ErosionField` 的接口与所有调用方均无需改动。

#### 终局

当最内层 band（核心所在）也被侵蚀后，全图进入侵蚀状态，此时触发**强制结算**：持续高额损失直到玩家撤离或死亡。这让侵蚀成为本局的硬时限，而不是一个可以无限拖延的软惩罚。

### 5.8 撤离点的放置

早先版本中"不可走回头路"与"搜打撤"存在冲突（不能向外走，如何撤离）。
**新的移动与侵蚀规则彻底解决了这个矛盾**，撤离点因此回到最符合玩法直觉的位置：

- **撤离点集中分布在外环与中环**，内环稀少或没有
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
#   node_position：极坐标 → 屏幕坐标，center + Vector2(cos(a), sin(a)) * radius
#   draw_edge：
#     kind == "tangential" → 沿圆弧采样 N 个点用 draw_polyline 画弧
#                            （不要画直线，直线会破坏同心环的视觉语言）
#     kind == "radial"     → 直线，或带轻微向外弯曲的二次贝塞尔
```

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
var hp: int                      # run 内持久生命值（见 5.7 待确认项）
var max_hp: int
var player: GridInventory        # 背包
var equipment: GridInventory     # 装备栏
var gold: int
var meta_stash: GridInventory    # 跨 run 持久仓库
```

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

## 9. 目录结构

```
res://
  core/                          # 纯逻辑，零 Node 依赖，可单测
    inventory/
      grid_inventory.gd
      item_shape.gd  item_def.gd  item_instance.gd
      inventory_service.gd
    battle/
      battle_sim.gd  compiler.gd
      combatant_spec.gd  battle_event.gd
    map/
      map_graph.gd  map_node.gd  map_edge.gd
      map_generator.gd           # 抽象基类
      map_generator_registry.gd
      map_navigator.gd
      generators/
        ring_map_generator.gd    # 第一章
        ring_map_config.gd
        (未来：layered_map_generator.gd 等)
    loot/
      loot_roller.gd  loot_table.gd
    run/
      action_clock.gd            # 行动计数
      move_intent.gd             # 移动意图，扩展机制的接入点
      erosion_field.gd           # 侵蚀推进与惩罚结算
      erosion_schedule.gd
    rng.gd
  data/                          # Resource 资产
    items/*.tres      shapes/*.tres
    loot_tables/*.tres  enemies/*.tres
    chapters/chapter_01.tres
  ui/
    inventory/   map/   battle/   search/
    map/layouts/ring_layout.gd   # 布局策略实现
  autoload/
    game_director.gd  run_state.gd  event_bus.gd
  tests/
```

---

## 10. 实施顺序

| 阶段 | 内容 | 产出 |
|---|---|---|
| **1** | M1 网格背包 + 拖拽 + 序列化 | 可玩的整理沙盒，核心手感可验证 |
| **2** | M2 编译 + 模拟 + 极简可视化（血条 + 跳字） | 两个背包能打起来，可批量跑平衡 |
| **3** | M3 环形地图生成 + 单步导航 + 渲染 + 行动计数 | run 的骨架成立 |
| **4** | 侵蚀系统 + 难度档位开关 | 时间压力成立，可开始调节奏 |
| **5** | M4 掉落 + 搜刮揭示 + 撤离 | **循环闭合，第一个可玩 Demo** |
| **6** | M5 存档 + M6 场景流打磨 | 可对外试玩 |
| **7** | 内容扩充（物品 / 敌人 / 事件 / 新章节地图形态 / 扩展移动机制） | 此后 90% 的时间 |

阶段 3 与 4 拆开的理由：地图 + 行动计数本身就能跑通一整局，侵蚀是叠加在上面的压力层。先让无压力版本可玩，再加侵蚀，才能判断出节奏问题到底来自地图结构还是来自侵蚀参数。

**先把 M1 做到能跑，再动其他模块。**
常见失败模式是先做地图（因为最容易看到画面），结果背包系统定型后地图与战斗全部要改。

---

## 11. 已知风险

1. **异形物品的拖拽手感调优被严重低估** —— 抓取偏移、旋转轴心、吸附容差需要反复迭代，预留充足时间。
2. **邻接加成的结算顺序**必须在实现前定死分层规则，后期修改将导致全部物品数值重平衡。
3. **地图形态硬编码风险** —— 任何时候在 `MapGraph` / `MapNavigator` / `MapView` 主体里看到 `ring` / `angle` 字样，就是在给第二章挖坑，立即重构进 `layout` 字典或布局策略。
4. **侵蚀节奏的数值调校是第一章最难平衡的部分。** `first_at_action` / `interval_actions` 与地图规模强耦合，改环数或节点密度就必须重调。建议写一个“给定策略下的行动点消耗”模拟脚本（用贪心 AI 走图），批量跑出行动点分布再反推侵蚀时间表，不要靠手感拍数字。
5. **扩展机制的预留缝容易被无意堵死。** 凡是在 `ActionClock` / `ErosionField` / 存档 / HUD 里直接写死 `+1`、或绕开 `MoveIntent` 直接读 `edge` 的地方，都是在给传送与定点移动挖坑。见第 12 节。
6. `godot_ai` 插件注册了 autoload `_mcp_game_helper`，**正式导出前必须摘除**，避免打进发布包。
7. 使用 Godot 4.7（较新版本），自定义 Resource 的 `@export var x: Array[Vector2i]` 在编辑器内联编辑时偶有异常。`.tres` 出现数据丢失时优先排查泛型数组导出问题。

---

## 12. 扩展机制的预留接口

已知会在后续加入、但**当前不实现**的机制。本节只记录它们将挂在哪条接缝上，用途是防止底层把路堵死。

原则：**留缝，不留实现。**

| 扩展机制 | 接入点 | 底层必须避免的假设 |
|---|---|---|
| 传送 / 定点移动 | `MoveIntent.kind` 新增类型 | 不假定"一次移动 = 走一条边"，不假定行动消耗恒为 1 |
| 新的地图形态 | `MapGenerator` + `MapLayoutStrategy` 子类 | `MapGraph` / `MapNavigator` / `MapView` 主体不出现 `ring` / `angle` |
| 侵蚀方向变体（如由内向外） | 生成器对 `erosion_band` 的标注方式 | 不把 `erosion_band` 与 `tier` 合并成一个字段 |
| 非矩形 / 可扩容背包 | `GridInventory._blocked` 与 `size` | 不假定容器是满矩形、尺寸不变 |
| 物品损坏与随机词条 | `ItemInstance.state` 字典 | 不把运行时可变状态写进 `ItemDef` |

**这张表的用法是防御性的**：实现底层时对照检查有没有踩到右列，而不是现在就去实现左列。

---

## 13. 待确认事项

| # | 事项 | 当前假设 | 若改变的影响面 |
|---|---|---|---|
| 1 | run 内是否存在持久生命值 | 存在，跨战斗保留、可由休息点恢复 | 若不设，侵蚀浅层惩罚改为只损坏物品；`ErosionField` 接口与调用方不变 |
| 2 | 侵蚀损失的具体形式 | 浅层扣生命值，深层额外损坏背包物品 | 同上，只改效果实现与参数 |
| 3 | 节点事件的额外行动消耗 | 搜刮 +1 ／ 休息 +2 ／ 商店 +0 | 仅影响节奏调参 |
| 4 | 撤离后的保留规则 | 背包内容全额进入仓库，死亡全失 | 影响 meta 成长曲线，不影响任何模块接口 |

这几项都被刻意隔离在参数层或单个类的内部，**推迟决定不会阻塞任何模块的开工**。

---

## 14. 变更记录

| 版本 | 日期 | 内容 |
|---|---|---|
| v0.1 | 2026-09-20 | 初版：六大模块设计；地图系统确定为可插拔生成器架构，第一章采用同心环形地图 |
| v0.2 | 2026-09-20 | 地图移动规则改为可自由折返（已访问节点仅可穿行、不再触发事件）；新增行动计数 `ActionClock` 与由外向内的侵蚀系统 `ErosionField`；撤离点回归外环与中环 |
| v0.3 | 2026-09-20 | 取消自动寻路，移动一律单步；新增 `MoveIntent` 作为未来传送／定点移动的接入点；新增第 12 节「扩展机制的预留接口」与第 13 节「待确认事项」 |
