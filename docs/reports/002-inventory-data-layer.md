# 002 · 背包数据层

对应架构文档：3.1 节「数据结构」。属于第 10 节实施顺序的**阶段 1** 第一部分。

## 目标

实现异形格子背包的数据基础：形状定义与四向旋转、物品静态定义、运行时实例、以及支撑存档反序列化的定义索引。同时搭起无头测试通道，让后续每一步都能在命令行验证。

## 产出

| 文件 | 职责 |
|---|---|
| `core/inventory/item_shape.gd` | `ItemShape`：异形占格与四向旋转，带规范化与缓存 |
| `core/inventory/item_def.gd` | `ItemDef`：物品静态定义，全局共享只读 |
| `core/inventory/item_instance.gd` | `ItemInstance`：运行时实例，含序列化往返 |
| `core/inventory/item_database.gd` | `ItemDatabase`：按 id 索引定义，供反序列化与掉落使用 |
| `tests/test_case.gd` | 极简断言收集器 |
| `tests/test_item_shape.gd` | `ItemShape` 套件 |
| `tests/test_item_instance.gd` | 实例／定义／数据库套件 |
| `tests/run_tests.gd` | 无头测试入口，退出码 0／1 |

全部为纯 `Resource` 与 `RefCounted`，`core/` 下没有任何 `Node` 依赖，符合架构总原则 1.1。

## 关键决策

### 1. 旋转后做「规范化」，而不只是旋转

每个旋转的结果都会平移到 `min = (0, 0)` 并按字典序排序，得到与书写方式无关的唯一表示。

这带来两个直接好处：同一形状的不同写法（平移过的、乱序写的）可以用 `==` 直接比较；`distinct_rotation_count()` 得以用简单的数组去重实现，无需几何判断。

代价是 `cells` 的书写顺序不被保留。目前没有任何地方依赖书写顺序，可以接受。

### 2. `cells_rotated()` 返回内部缓存，不做防御性拷贝

拖拽期间每帧都要对候选位置做碰撞检测，每次都 `duplicate()` 一个数组是纯浪费。因此返回值直接是缓存引用，并在文档注释里写明**调用方不得修改**。

这是有意用「约定」换性能的地方，需要在 code review 时留意。

### 3. 缓存失效靠 `cells` 的 setter

`_rot_cache` 的声明必须在 `cells` 之前 —— 资源加载时会调用 `cells` 的 setter，若 `_rot_cache` 此时尚未初始化，清空操作会落空。这个顺序依赖已在代码注释里标明，不要重排。

测试中有一条专门覆盖「改写 `cells` 后缓存失效并重算」。

### 4. uid 用静态自增计数器，读档时抬高水位

`ItemInstance._next_uid` 是进程内静态变量，配 `reset_uid_counter()`（开新局）与 `reserve_uid_above()`（读档后保证不撞号，由 `from_dict` 自动调用）。

考虑过做成实例化的 `UidPool` 由 `RunState` 持有并序列化，那样没有全局状态、更干净。最终选静态计数器，因为它省掉了「每个创建物品的地方都要拿到 pool」的传递成本，而正确性由上述两个显式方法保证，测试已覆盖读档不撞号的情形。若将来出现多局并存（如后台模拟）的需求，这里需要改成实例化。

### 5. `can_rotate = false` 在数据层就钉死朝向

不可旋转的物品在 `create()` 时旋转被归零，`rotated_step()` 恒返回 0，`cells_rotated()` 强制取 rot0。UI 层因此不需要重复判断，也就不可能出现「UI 忘了判断导致产生非法朝向」的分叉。

### 6. 不连通形状在数据层视为合法

`#.#` 这种中间断开的形状 `is_valid()` 返回 true。要不要有这种物品是内容设计的事，数据层不替设计做决定。

### 7. 序列化只写 def id 字符串

`to_dict()` 输出 `{"def": "bar", ...}`，不写资源路径。测试里有一条直接断言这一点，防止将来有人图省事改成存 `resource_path`。

未知 id 在 `from_dict` 时返回 `null` 并告警，而不是崩溃 —— 内容删改后旧存档仍能加载，只是丢掉那件物品。

## 验证

首次运行需要先做一次导入，否则 `class_name` 全局名未注册，脚本会报 `Identifier "TestCase" not declared`：

```bash
"/e/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
```

之后每次跑测试：

```bash
"/e/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tests/run_tests.gd
```

实际输出：

```
======================================================
通过  55 项断言，2 个套件，耗时 70 ms
======================================================
EXIT=0
```

输出中会夹带 3 条 `WARNING`（重复 id、无效定义、未知 def id）。**这是预期的**，它们正是负向用例触发的告警路径，不是问题。

### 过程中被测试抓到的一个错误

初版测试断言「竖条 rot3 包围盒为 1x3」，实际为 3x1。rot3 是顺时针 270°，竖条会变成横的 —— 是断言写错而非实现错误，已修正，并补了 rot2 的用例把四个朝向覆盖完整。

## 遗留

- `ItemDef` 尚无战斗相关字段（冷却、伤害、邻接加成），属于 M2 范畴。Godot 对 `.tres` 中缺失的新属性取默认值，届时直接追加导出属性即可，不会破坏已有资产。
- `data/items/` 与 `data/shapes/` 仍为空，尚无 `.tres` 资产。`ItemDatabase.load_dir()` 已实现但还没有真实数据可加载，测试用代码构造的定义覆盖。
- `ItemDatabase.load_dir()` 处理了导出后 `.res` 与 `.remap` 的情形，但未在真实导出包中验证过。
- uid 静态计数器不支持多局并存，见上文决策 4。

## 下一步

**003 · GridInventory 容器核心**：占用表、`can_place` / `place` / `remove`、`find_first_fit`、`neighbors_of`、序列化往返，对应架构文档 3.2 节。
