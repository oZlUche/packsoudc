# 120 小修：读档先按科技等级表算出仓库容量等派生值，再往里核对装载物品；存档不再存科技算出来的数

> 架构 · 小修（2026-10-03）。作者：「科技效果带来的增益，比如仓库总容量，希望是在读取存档时先检查科技激活表再查询效果决定最后数值」，并定「仓库的容量应该放在检验并读取存档内仓库物品前，其余的同意」。
> 接 118 / 119：科技等级表（`MetaState.tech_levels`）是唯一的进度事实，派生值一律由它 + 科技定义算出。

## 一、现状（已核实）

- 读档顺序（`GameFlow.use_slot` → `SaveSlots.open` → `MetaSave.read / from_text` → `MetaState.from_dict`）：**先**按存档里记的尺寸建仓库、把物品放回去（`GridInventory.from_dict`，放不回的告警丢弃），再读 `tech_levels`，最后 `GameFlow.heal_techs()` → `TechService.heal` 对每项科技按级数**补**效果。和作者要的顺序正好相反：现在是「先装东西、后看科技」。
- `TechWarehouseRows.heal` 只补不缩（`warehouse_rows.gd:15`）；`TechSafeSize.heal` / `TechRunBuff.heal` 已经是按级数重算。
- `safe_bonus`、`tech_buffs` 既重算又写进存档（`meta_state.gd:484-485`），冗余。
- 仓库行数只有科技会长（093 的「锻炼」长的是局内棋盘 `run.board`），所以仓库尺寸可以完全由「规则基础尺寸 + 科技」决定，不必存。
- `MetaState.from_dict` 不知道科技定义（`tech_defs` 在 `GameFlow` 上），所以现在只能事后补。

## 二、读档的新顺序（`MetaState.from_dict`）

`from_dict(d, items, rules, tech_defs: Array = [])`，一路把 `tech_defs` 传进来（`SaveSlots.open`、`MetaSave.read / from_text` 各加一个参数，`GameFlow.use_slot` 传 `tech_defs`）：

1. **先读进度表**：`tech_levels`、`tech_deposits`（照旧）。
2. **再算派生值**：`TechService.derive(m, tech_defs)` 在一个还空着的 `MetaState` 上跑一遍 —— 仓库尺寸 = `rules.warehouse_size` + Σ 每级行数 × 级数，`safe_bonus`、`tech_buffs` 同理。此刻仓库还没有东西，长缩都不用顾忌。
3. **然后才装物品**：`GridInventory.from_dict(w, items, m.warehouse.size)` —— 新增可选参数 `size_override`，给了就按它建格子、**忽略存档里的 size**。逐件放回原位；原位越界或被占（仓库比上次小了）就 `try_add` 找个空位；还放不下 → 见待定 1（推荐临时加行放下，记开发日志，不丢玩家的东西）。
4. 其余字段照旧。

`tech_defs` 为空（没传，测试里直接读档）时退回老行为：按存档里的尺寸建仓库 —— 老测试与 v1 / v2 样本不受影响。

## 三、存档瘦身

- `to_dict` 去掉 `tech_buffs`、`safe_bonus`；`from_dict` 不再读它们（旧档里有就忽略）。新字段有默认值、去掉的字段不读，**不升存档版本**（098）。
- 仓库的 `size` 仍由 `GridInventory.to_dict` 写（容器通用格式），但读仓库时被 `size_override` 盖掉；只剩「没有科技定义时的兜底」一个用途。
- 存档里从此没有任何「科技算出来的数」：改 119 的配置表（每级行数、每级加成），所有玩家读档即生效。

## 四、`TechEffect`：`apply` + `heal` 合成一个 `derive`

两个方法本来就是同一件事的两种写法（增量施加 / 按级重算）。改成一个幂等的 `derive(meta, level)`：「已到 level 级，局外该是什么样，就把它变成那样」。

| 构件 | `derive(meta, level)` |
|---|---|
| `warehouse_rows` | `meta.warehouse.resize_rows(meta.warehouse_size().y + rows × level)`：比现在大就 `grow_rows`；比现在小就 `shrink_rows`（新方法，从底往上只删**空行**，碰到有东西的那一行停下并记日志）。读档时仓库是空的，所以总能缩到位 |
| `tech_safe_size` | `safe_bonus = Vector2i(cols, rows) × level` |
| `tech_run_buff` | 去掉本科技所有 buff，`level > 0` 时加第 `level` 条 |

- `TechService.upgrade`：等级 +1 后调 `derive(meta, 新等级)`，不再调 `apply`。
- `TechService.heal` 改名 `derive(meta, defs)`：对每项科技调 `effect.derive`，再清不属于任何科技的 `tech_buffs`（118 那段照留）。读档（§二第 2 步）、升级后、`GameFlow.use_slot` 新建空档时各调一次。`GameFlow.heal_techs` 改名 `derive_techs`。

## 五、测试（`tests/meta/test_tech.gd` / `test_tech_tree.gd` 改、加）

1. 存档里仓库 size 是基础尺寸、`tech_levels.warehouse = 2`、物品在第 0 行：读档后仓库 = 基础 + 6 行，物品还在原位（**先算容量再装东西**）。
2. 存档里仓库比科技算出的大、底下几行有一件东西：读档后那件东西被 `try_add` 挪进范围内，仓库尺寸 = 算出的值；一件也不丢。
3. 装不下（仓库塞满、又缩了行）：按待定 1 的推荐，临时加行放下并有日志；`item_count` 不变。
4. `to_dict` 里没有 `tech_buffs` / `safe_bonus`；带这两个字段的旧档读回来结果一样（派生值来自等级表）。
5. v2 样本（`meta_v2.json`）仍读得回来、钱与仓库那件还在（现有断言）。
6. `shrink_rows`：底下两行空、第三行有东西 → 只缩两行。
7. 现有 `run_migration_and_heal` 的「比期望大：不缩」断言改为「比期望大且多出的行是空的：缩回期望值」。

## 六、改动点

| 文件 | 改动 |
|---|---|
| `core/meta/meta_state.gd` | `from_dict` 加 `tech_defs` 参数、按 §二 的顺序；`to_dict` 去两个字段 |
| `core/meta/meta_save.gd`、`core/run/save_slots.gd` | 透传 `tech_defs` |
| `core/inventory/grid_inventory.gd` | `from_dict(d, db, size_override := Vector2i.ZERO)`，越界 / 被占的物品 `try_add`；新 `shrink_rows(n)`、`resize_rows(want)` |
| `core/meta/tech_effect.gd` 与三个子类 | `apply` + `heal` → `derive(meta, level)` |
| `core/meta/tech_service.gd` | `upgrade` 调 `derive`；`heal` → `derive(meta, defs)` |
| `core/run/game_flow.gd` | `use_slot` 传 `tech_defs`；`heal_techs` → `derive_techs` |
| `tests/meta/test_tech.gd`、`test_tech_tree.gd` | §五 |
| `docs/architecture.md` 3.8 存档一节 | 一句：科技派生值不入档，读档先算容量再装仓库 |

不改：存档版本、`TechDef / TechTier`、科技页界面、119 的配置表。

## 七、待定（按推荐即执行）

| # | 问题 | 推荐 |
|---|---|---|
| 1 | 读档时仓库缩了、`try_add` 也放不下的物品怎么办 | **临时加行放下**（只加到刚好够），`push_warning` 记一句；不丢东西、不进「待取回」之类的新概念。下次升级仓库科技时 `derive` 的缩行会把空出来的行收回 |
| 2 | `apply` / `heal` 要不要真的合成 `derive` | **合**，少一半代码、升级与读档走同一条路，不会再出现「升级给了、读档没给」的不一致 |
| 3 | 没传 `tech_defs` 时仓库尺寸怎么定 | **用存档里的 size**（兜底），老测试与样本不动 |
