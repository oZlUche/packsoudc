# 010 · 邻接机制按语义重命名

对应架构文档 v0.6：4.2 编译阶段。**纯重命名与语义重整，行为不变。**

## 目标

两处命名问题，都会在后续造成实质困扰：

1. **`SocketProfile`「插槽」这个名字借错了。** 在《背包乱斗》里 socket 专指**宝石孔**，
   而宝石是另一套完全不同的机制。代码里已经有个叫 socket 的东西指别的，等真要做宝石时必然打架。
2. **星形／菱形是符号，不是语义。** 原作用这两个符号区分两类标记纯属任意选择。
   照搬过来之后，还得额外挂一个 `Direction` 字段说明「到底谁受益」，两个概念各表一半。

## 澄清：邻接标记 ≠ 宝石镶嵌

| | 邻接标记（已实现） | 宝石镶嵌（未实现） |
|---|---|---|
| 关系 | 物品 A **挨着** 物品 B | 宝石 **在** 物品 B **里面** |
| 占格 | 双方各占各的格子 | 宝石不占网格，占宿主的孔位 |
| 效果来源 | 由标记持有者的描述决定 | 由宿主类型决定（武器／护甲／散放三套） |
| 合成交互 | 无 | 宝石合成时距离无关，只看**宿主物品**是否相邻 |

宝石已登记进架构文档第 12 节的扩展接口表：`ItemDef.gem_slots` 记孔位数，
`ItemInstance.state.gems` 记这一件镶了什么（属于实例状态不是定义），
编译期在包体效果之后插一步。**`socket`／「镶嵌」这组词从此只归宝石。**

## 改动

### 命名

| 原 | 现 |
|---|---|
| `SocketProfile` | `AdjacencyProfile` |
| `core/battle/socket_profile.gd` | `core/battle/adjacency_profile.gd` |
| `ItemDef.sockets` | `ItemDef.adjacency` |
| `_apply_sockets` / `_resolve_socket` | `_apply_adjacency` / `_lit_neighbors` |
| 文档中的「插槽」 | 「邻接标记」 |

### 语义重整：两个概念合并成一个

原来是**两类标记**（星／菱）× **两种方向**（HOLDER／FILLER）的正交组合，
但实际只用到其中的对角线。现在直接按语义分两类：

```gdscript
@export_group("增益：我给邻居加成")
@export var grant_cells: Array[Vector2i]
@export var grant_filter: Array[StringName]
@export var grant_mods: Array[StatModifier]     # 每个符合条件的邻居各得一份

@export_group("受益：邻居给我加成")
@export var receive_cells: Array[Vector2i]
@export var receive_filter: Array[StringName]
@export var receive_mods: Array[StatModifier]   # 点亮几格就得几份
```

`Direction` 枚举与 `Kind` 枚举一并删除 —— 类别本身就带着方向，不需要再标一次。

编译器相应拆成两条清晰的分支，并抽出 `_lit_neighbors()` 复用去重逻辑：

```gdscript
if profile.has_grant():
    for other in _lit_neighbors(..., grant_cells, grant_filter):
        apply(grant_mods → other, 1)        # 邻居各得一份

if profile.has_receive():
    var lit := _lit_neighbors(..., receive_cells, receive_filter).size()
    apply(receive_mods → holder, lit)       # 自己得 lit 份
```

比原先「算出 fillers，再按 direction 分头施加」好读：读代码的人不必回头查
`direction` 是什么值才知道谁被加成。

### 保留不变

- 去重计数规则、随物品旋转的坐标变换、过滤器语义，全部照旧
- 「同一类标记的各格必须同质」仍是硬约束，越线需先改架构文档 4.2

## 验证

```bash
bash tools/test.sh
```

```
======================================================
通过  524 项断言，9 个套件，耗时 381 ms
======================================================
EXIT=0
```

**断言数与改名前完全一致（524），说明是纯重命名，行为没变。** 测试里的措辞也一并改了
（「星格」→「增益格／受益格」），但断言条件一条没动。

另外顺手订正了架构文档 3.1 里 `ItemDef` 的字段清单 —— 它还把 `combat` / `bag_mods`
注释着标「M2 追加」，而这些在报告 009 就已经实现了。

## 遗留

- `data/items/` 的示例资产仍未配 `combat` / `adjacency`，延续报告 009 的遗留。
- 宝石系统按报告 006 的结论仍然暂缓，本次只腾出命名空间。
- UI 尚未表现邻接标记。增益与受益需要两种一眼可辨的图形，具体用什么留给表现层，
  数据层不关心。

## 下一步

回到 **011 · BattleSim**：定点数冷却的确定性模拟循环，输出事件日志。
