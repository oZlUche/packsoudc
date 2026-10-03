# 方案：仓库扩建（第一项局外科技）与上交界面；整理改「先同类再大小」；仓库滚动条（110）

> 架构 thread，2026-10-03。作者原话：「倍速按推荐，整理先追求同类然后大小，另外增加一个滚动条，并给游戏的局外科技添加扩张仓库的选项：先做 1～6 级扩展，每次增加 3 行，前 3 级只用钱，第四次之后需要蓝色材料道具（生成一些没有战斗属性的道具），可以通过一个上交界面提供，上交界面需要多种道具的情况下可以分批满足，每次记录下提交的道具，全部提交后【升级】按钮亮起。」
> 本文只写方案，不实现。109 的一～四条已落地（PR #17），本文的一、二是对它的修改。

## 一、整理：先同类，再大小（改 `GridTidy._before`）

109 落地的排序是「占格多 → 稀有度高 → id → uid」。作者定改成**先同类**：

```
种类序 → 占格多 → 稀有度高 → def id → uid
```

「同类」按道具的**大类标签**定，一张固定顺序表（`GridTidy.KIND_ORDER`），取道具标签里第一个命中的：

| 序 | 大类 | 认哪些标签 |
|---|---|---|
| 1 | 武器 | `weapon` |
| 2 | 盾 / 防具 / 插件 | `shield`、`armor`、`gear`、`gear_plug` |
| 3 | 信仰 | `faith`、`keepsake`、`sigil` |
| 4 | 药剂 / 食物 | `remedy`、`food` |
| 5 | 弹药 / 工具 / 试剂 | `ammo`、`tool`、`reagent` |
| 6 | 材料 / 零件 / 宝石 | `material`、`part`、`gem` |
| 7 | 珍宝 / 其他 | `treasure`，以及没命中任何一类的 |

表是代码常量不是内容字段：它只影响摆放顺序，不影响任何数值，作者改顺序就改这一张表。同类内再按大小，所以一类里大件在前、小件补缝，视觉上一类一块。回滚、只发一次 `changed`、不盖 `placed_seq` 都照旧。

## 二、仓库滚动条

扩建后仓库最多 8 + 3 × 6 = **26 行**，一屏放不下。`warehouse_panel.gd` 与 `setup_screen.gd` 里的仓库 `InventoryView` 各包进一个 `ScrollContainer`（只竖向，`custom_minimum_size.y` 定为约 10 行格高，宽度跟格子），仓库面板那块带回来的棋盘不滚。

要盯的一处：`DragLayer` 是铺满面板盖在格子上的一层，拖拽命中用的是视图的全局矩形；视图被滚走一部分后，**落点换算要用视图当前的全局位置**（`get_global_rect`，不是建视图时记下的），且被裁掉的区域不该接受落点。局内暂存列表已有滚动，可以照它的写法。拖到滚动区边缘自动滚**不做**，鼠标滚轮够用。

## 三、仓库扩建 = 第一项局外科技

### 3.1 形状：科技是内容，不是写死的「仓库升级」

作者说的是「局外科技添加扩张仓库的选项」—— 仓库是第一项，以后还会有别的。所以做成**一张科技定义 + 一套通用的等级 / 上交状态**，仓库只是第一条内容：

```
data/authoring/techs/warehouse.json
{
  "id": "warehouse", "display_name": "仓库扩建",
  "effect": {"type": "warehouse_rows", "rows": 3},        # 每升一级做什么
  "tiers": [                                               # 下标 = 升到第几级（1～6）
    {"funds": 100},
    {"funds": 200},
    {"funds": 400},
    {"funds": 600,  "items": {"steel_ingot": 2}},
    {"funds": 900,  "items": {"steel_ingot": 3, "hardwood_plank": 2}},
    {"funds": 1300, "items": {"steel_ingot": 4, "hardwood_plank": 3, "rivet_box": 2}}
  ]
}
```

- `TechDef`（`core/meta/tech_def.gd`，Resource）：`id / display_name / effect / tiers: Array[TechTier]`；`TechTier{funds: int, items: Dictionary}`。走 100 的内容管线（JSON → 导入 → `.tres`，`EffectRegistry` 登记 `tech_effect` 一类，`FieldText` 中文名），编辑器自动有页。
- 效果种类现在只有 `warehouse_rows`（调 `GridInventory.grow_rows(n)`，093 大地之神锻炼已有，**仓库里的东西原地不动**）。将来「保险箱加格」「出发多带钱」各是一种效果，加一个类不动框架。
- **数值是占位**：钱与件数作者定；前 3 级只要钱、第 4 级起要材料是作者定的结构。

### 3.2 状态：`MetaState` 加两个字典，存档升到 v3

```gdscript
## 科技等级：id → 已到第几级（没有 = 0）
var tech_levels: Dictionary = {}
## 上交中的材料：id → {item_id → 已交件数}。升级成功后清这一项
var tech_deposits: Dictionary = {}
```

- `SAVE_VERSION` 2 → 3，`MetaMigrations._v2_to_v3` 只补两个空字典。
- 仓库尺寸本来就随 `GridInventory.to_dict()["size"]` 存，所以升过级的仓库读回来就是大的。读档时多一道自检：期望行数 = `rules.warehouse_size.y + 3 × tech_levels["warehouse"]`，比它小就 `grow_rows` 补齐（只补不缩）—— 防止将来改基础尺寸或手改存档时对不上。
- **上交即消耗**：提交的那件从仓库移除、计数 +1，立刻存盘；没有「取回」。作者原话「每次记录下提交的道具」，分批跨多局都认。
- 钱在**按下【升级】时**一次扣（不是逐步交）：前 3 级就是「钱够了按钮亮」，和后面统一。

### 3.3 逻辑层：`core/meta/tech_service.gd`（纯逻辑，测试直接打）

| 方法 | 做什么 |
|---|---|
| `level(meta, id) -> int` | 当前级 |
| `next_tier(meta, def) -> TechTier` | 下一级要什么；满级返回 null |
| `needed(meta, def) -> Dictionary` | `item_id → 还差几件`（需要 − 已交，最低 0） |
| `can_submit(meta, def, item_def) -> bool` | 这件是不是下一级还差的材料 |
| `submit(meta, def, uid) -> bool` | 从仓库移除、`tech_deposits` 计数 +1、`changed` |
| `ready(meta, def) -> bool` | 材料全齐 **且** `funds ≥ tier.funds` |
| `upgrade(meta, def) -> bool` | `ready` 才动：扣钱、清这项 deposits、`tech_levels[id] += 1`、施加效果（`warehouse_rows` → `grow_rows`）、`changed` |

`GameFlow` 一行转发 + 存盘，和 `store_all` 一样。

### 3.4 上交界面：基地加「科技」页签

基地现在四个页签（仓库 / 图鉴 / 成就 / 出售），加第五个 **「科技」**。页面布局照抄出售页（左仓库格子、右操作区），因为交互一样是「从仓库里挑东西给出去」：

- 左：仓库格子（同一个 `InventoryView`，带滚动）。
- 右：每项科技一张卡（现在只有仓库扩建）：
  - 标题行「仓库扩建　Lv 2 / 6　下一级：+3 行」；满级写「已满级」。
  - 需求行：「钱　1300 / 持有 860」（够了绿、不够灰）；每种材料一行「钢锭　已交 2 / 需要 4」，齐了打勾。
  - **【升级】**按钮：`ready` 才亮，按下 `upgrade`，卡片刷新、仓库格子当场多 3 行。
- 交材料的两条路，和出售页一致：**双击**仓库里的一件 → 若 `can_submit` 就交，否则提示「下一级不需要「X」」；**拖**进右侧的「上交区」同理。交错了不能退 —— 提示文字里写明「上交即消耗」。
- 出售页的双击仍是卖，不受影响（页签不同）。

### 3.5 材料道具：蓝色、没有战斗属性

作者定：**稀有度 2（稀有，蓝）**、没有规则、不是包、不参战（没规则本来就不出手，也不进敌人配装 —— 敌人只挑带规则的武器出手，材料顶多当战利品被背着）。先三种，1 格或 2 格，名字占位：

| id | 名 | 形状 | 标签 |
|---|---|---|---|
| `steel_ingot` | 钢锭 | 1×1 | `material`、`metal`、`supply`（新） |
| `hardwood_plank` | 硬木板 | 2×1 | `material`、`nature`、`supply` |
| `rivet_box` | 铆钉盒 | 1×1 | `material`、`metal`、`supply` |

- 新标签 **`supply`【建材】**（`tip = false`，说明「拿回基地用来扩建的东西」）：让上交页、商店排除、将来别的科技都能按它筛，不用列 id。现有的 `material`（魔晶石等）是合成材料，语义不同，不混用。
- **怎么来**：和别的道具一样进掉落（`drop_rules` 按稀有度 2 的概率），商店**不卖**（`economy_rules.shop_exclude_tags` 加 `supply`，不然前 3 级攒的钱直接买材料，第 4 级起的门槛就没了）。出售价按 `ItemValue` 的稀有度 2 算，玩家卖掉也行，那是他的选择。
- 它们会被 `keeps` 收进仓库、占格 —— 这正是「先扩仓库才装得下建材」的小张力，不另开材料栏。

## 四、改动范围（约两天）

| 批 | 内容 | 文件 |
|---|---|---|
| ① 整理 | `KIND_ORDER` + `_before` 改序；测试改断言 | `core/inventory/grid_tidy.gd`、`tests/inventory/test_grid_tidy.gd` |
| ② 滚动 | 仓库视图包 `ScrollContainer`；`DragLayer` 落点用当前全局矩形 | `ui/game/warehouse_panel.gd`、`ui/game/setup_screen.gd`、`ui/inventory/drag_layer.gd` |
| ③ 内容 | `TechDef / TechTier`、导入与登记、`techs/warehouse.json`、三件建材 + `supply` 标签、商店排除 | `core/meta/tech_def.gd`、`core/authoring/content_importer.gd`、`core/battle/effect_registry.gd`（或 `RunRegistry`）、`core/authoring/field_text.gd`、`data/authoring/techs/`、`items/`、`tags/supply.json`、`economy_rules/*.json` |
| ④ 状态 | `tech_levels / tech_deposits`、v3 迁移、读档补行 | `core/meta/meta_state.gd`、`core/meta/meta_migrations.gd` |
| ⑤ 逻辑 | `TechService` 七个方法；`GameFlow` 转发 | `core/meta/tech_service.gd`、`core/run/game_flow.gd` |
| ⑥ 界面 | 「科技」页签与卡片、上交区、双击 | `ui/game/meta_screen.gd`（页签表那行 + 一页）、`ui/game/tech_panel.gd`（新） |
| ⑦ 测试 | 升 1～3 级只扣钱、仓库每级 +3 行且原物不动；第 4 级交 1 件后存档读回仍记着、交齐 + 钱够才 `ready`、`upgrade` 后 deposits 清空；不需要的件 `can_submit` 假；v2 存档迁到 v3；读档行数不足自动补；满级 `next_tier` 为 null；页签 smoke | `tests/meta/test_tech.gd`（新）、`tests/meta/test_meta_migrations.gd`、`tests/ui/` |

## 待作者定（作者 2026-10-03 放行：方案完毕即执行，五项按推荐）

1. 科技做成通用 `TechDef`（仓库是第一条内容）：**推荐**；否则写死一项以后再拆。
2. 各级的钱与件数：表里是占位，**按占位先做**，数值随时改 JSON。
3. 建材是否可在商店买：**推荐不卖**（不然第 4 级起的材料门槛形同虚设）。
4. 上交后能否取回：**推荐不能**（作者原话是「记录下提交的道具」，按消耗处理）。
5. 同类顺序表（武器 → 防具 → 信仰 → 药剂 → 弹药 / 工具 → 材料 → 珍宝）：**推荐如上**，想换顺序改一张表。
