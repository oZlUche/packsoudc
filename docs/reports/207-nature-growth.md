# 207 自然系专属机制【生长】：种子 → 茎叶 → 绽放，扎根锁位、逐阶强化

> 架构设计 thread · 2026-10-19 · 提案（作者 21:30 夜间六条之一）。待定按推荐派执行。
> 作者原话：「自然系独有的【生长】，该道具进入棋盘后，经过 N 次倒计时，该道具会和背包固定（无法移出背包、无法移动位置），同时属性增加并有可能获得额外效果；再经过 M 次倒计时，该道具和背包都会固定（背包也无法移动无法被拿出），道具进一步强化；三个阶段对应【种子】【茎叶】【绽放】，但不固定，也可以是树木的成长阶段。」

## 0 一句话

道具定义上加一块 `growth`（几阶、每阶要走几步倒计时、每阶的名字 / 前缀 / 加成 / 规则 / 锁什么），计数记在实例 `state` 里（和魔晶石耐久同一条路），**全局倒计时每减一步就长一步**；到阶时道具扎根（拖不动、挪不走、整理跳过），再到阶时它所在的包也扎根；加成走编译器第 4b 步（和信仰加成同一处，休眠一起跳过）。只有带 `faith:nature` 的道具能长 —— 自然之神不是当前信仰就休眠不长、加成也停。首批三件种子。

## 1 现状（核过）

| 事 | 现在 | 用得上 |
|---|---|---|
| 实例级状态 | `ItemInstance.state: Dictionary`，存档 `to_dict` 原样带走；魔晶石的 `charges` 就记在这里（148） | 生长计数 `growth_ticks` / `growth_stage` 同样放这里，不加字段、不改存档格式 |
| 「倒计时」 | 作者的词 = 全局倒计时（092，`CountdownModule`）：走一步（边的 `action_cost`）减一，原地耗时也减；底层是 `MapTravel.clock: ActionClock`，每次 `spend` 发 `advanced(total, delta)` | 生长就订这个信号：`delta` 多少长多少 |
| 局内插件 | `RunModule`（101）：`WearModule` 订 `battle_finished` 扣耐久，自己不存东西 | 新 `GrowthModule` 同一个模子：订 `clock.advanced`，改 `state`，发 `grown(uid, stage)` |
| 休眠 | `FaithState.is_dormant(def, active)` / `dormant_uids(container)`：带 `faith:<id>` 的道具，不是当前信仰就休眠；编译器第 4b 步 `dormant.has(uid)` 就跳过信仰加成 | 「自然系独有」= 生长道具带 `faith:nature`；休眠的不长、阶段加成也不算 |
| 按件加成 | 编译器第 4b 步：`def.faith_bonuses` → `StatModifier.apply_to(stats[uid], times)` + 规则收进 `bonus_rules[uid]` | 阶段加成插在同一处，形状一样（mods + rules） |
| 名字 | `Names.of_item`：耐久前缀 + 附魔前缀 + 本名 | 加生长前缀：`生长前缀 + 耐久前缀 + 附魔前缀 + 本名` |
| 移动的口 | 玩家能动一件东西的路只有三条：`DragLayer` 按下（`grid.remove` / `detach_bag`）、`InventoryService.move / transfer_auto / transfer_all*`（双击、全部拾取、换屏倒包）、`GridTidy.tidy` | 三处各加一句 `locked` 判定；核心层 `GridInventory.remove` 不改（结算、存档、死亡清棋盘照旧） |
| 包 | `GridInventory.bag_of(uid)`、`contents_of(bag_uid)`、`detach_bag`、`rotate_dragged` | 「包也固定」= 包里有 ≥ 绽放阶的道具时，包不许被拿起、转动、顶替 |
| 道具图按实例变 | 没有：`ItemPainter.art_id_of(def)` 只认定义 | 和 208 共用一条「实例变体图」规则（`<id>@<变体>.png`），见 208 §2.3；没有变体图就画本图 |

## 2 规则

### 2.1 数据：`ItemDef.growth: GrowthProfile`

```json
"growth": {
  "stages": [
    {"name": "茎叶", "prefix": "抽芽的", "after": 4, "lock": "item",
     "mods": [{"stat": "damage", "amount": 2}], "rules": []},
    {"name": "绽放", "prefix": "盛放的", "after": 6, "lock": "bag",
     "mods": [{"stat": "damage", "amount": 4}], "rules": [ … ],
     "bonus_pool": [ … ], "bonus_count": 1}
  ],
  "stage0_name": "种子",
  "reset_on_leave": true
}
```

- `stages` 按序；`after` 是**从上一阶起**再走几步（作者的 N、M）。阶数不限于两阶（树：树苗 → 小树 → 大树）。
- `name` 只给悬浮窗（「生长：茎叶，再 3 步绽放」）；`prefix` 进名字。英文 `names_by_lang` / `prefixes_by_lang` 同耐久的写法。
- `mods` / `rules`：**取当前阶的那一份**（不累加，表里写终值，作者改数时一眼看全）。`rules` 与信仰加成的 `rules` 同约束（无 costs）。
- `bonus_pool` + `bonus_count`：「有可能获得额外效果」—— 到阶时从池里按 `hash(run_seed, uid, "growth", stage)` 抽 `bonus_count` 条规则，抽到的 id 记进 `state.growth_bonus`（存档带走，重开不变）。池空 = 没有随机项。
- `lock`：`"none"` / `"item"`（这件拖不动、挪不走、不参与整理、不被顶替）/ `"bag"`（上一条 + 它所在的包：拿不起、转不动、不被顶替；包里**别的**东西照旧能动）。
- `reset_on_leave`（默认真）：道具离开作战棋盘（进地上 / 卖掉 / 进仓库）计数清零、阶段归零；假 = 带着阶段走（树苗挪盆）。

### 2.2 谁能长

- 导入器：`growth` 只许出现在带 `faith` + `faith:nature` 的道具上，否则 error「生长是自然之神的东西」。别的神将来要类似机制另起词。
- 休眠（自然不是当前信仰）：**不长、不退**，阶段加成不算，锁**保持**（扎了根的拔不出来 —— 换神的代价，作者 099 的信仰切换规则不另开口子）。
- 只数作战棋盘（`RunState.board`）里、在包里的（`bag_of != EMPTY`）。地上、仓库、容器屏里的不长。

### 2.3 什么时候长

- `GrowthModule`（`RunModule`，`ID = &"growth"`）订 `run.travel.clock.advanced(total, delta)`：对棋盘上每件有 `growth` 的、不休眠的道具 `state.growth_ticks += delta`；够了就升阶（一次 `delta` 最多升一阶，剩余不结转），发 `grown(uid, stage)`；`board.changed.emit()` 重画。
- 战斗不长（作者的词是倒计时不是冷却）；休息点「原地耗时」减倒计时也长 —— 和倒计时一个口径，玩家一看就懂。
- 没有倒计时的章（序章 `step_limit` 0）：`ActionClock` 照样在走，一样长。

### 2.4 锁怎么兑现

| 口 | 改法 |
|---|---|
| `ItemInstance.locked()` / `GridInventory.lock_of(uid)` | 实例读 `def.growth.stages[stage-1].lock`；棋盘给一个 `is_locked(uid)`（这件 `item` 或 `bag` 锁）与 `bag_locked(bag_uid)`（包里任一件到了 `bag` 锁） |
| `DragLayer` 按下 | `is_locked` 的不拿起，`warn(UiText 「已扎根，拔不出来」)`；拿包时 `bag_locked` 同理；`rotate_dragged` 对锁住的包不转（包只有在手上才转，所以拿不起就够了） |
| `GridInventory.displaced_by` | 锁住的件、锁住的包不进顶替名单（顶替它 = 放不下） |
| `InventoryService.move / transfer_auto / transfer_all / transfer_all_prefer / _take_bag_apart` | 源是锁住的件 → 返回假 / 跳过；双击快速移动走的也是这里 |
| `GridTidy.tidy` | 锁住的件与锁住的包原地不动，其余绕着排 |
| 撤离结算、行动失败、换屏倒包 | **不改**：核心层 `remove` 照旧；进了仓库 `reset_on_leave` 清零 |
| 卖出 | 卖出屏按锁住的不列（锁了就是不能移出） |

### 2.5 加成怎么算

- 编译器第 4b 步旁边加一段：`def.growth != null and not dormant.has(uid)` → 取 `inst.state.growth_stage`（编译输入里要有实例 state；`compile_board` 读的是 `board.get_item(uid)`，实例在手，不加参数），当前阶的 `mods` 施加、`rules` 与抽中的 `bonus` 规则并进 `bonus_rules[uid]`。
- 悬浮窗：一行「生长：茎叶（4/4）→ 再 6 步绽放」，当前阶加成按 `faith_bonuses` 的写法列；锁了写「已扎根」。
- 名字前缀见 §1。

### 2.6 首批三件（自然之神的种子，`faith` + `faith:nature` + `nature` + `herb`/`wood`）

数值是起点，执行按 `PowerWeights` 核一遍价值；都是 1×1 或 1×2，白 / 绿 / 蓝一件各一。

| id | 名 | 稀有度 | 种子 | 茎叶（after 4，锁件） | 绽放（after 6，锁包） |
|---|---|---|---|---|---|
| `thorn_seed` | 荆棘种子 1×1 | 1 | 无效果 | 「荆棘」：受到直接伤害时反伤 1（`on_damage TAKEN → damage reflect 1`） | 反伤 3，且反伤命中施加 1 层流血；bonus_pool：{+10% 耐力回复 / 相邻武器 +1 伤害} 抽一 |
| `ironwood_sapling` | 铁木苗 1×2 | 2 | 无效果 | 增益格两侧（`grant_cells` 左右）武器 +2 伤害 | +4 伤害且 +5% 暴击；bonus_pool：{自己 +6 护甲上限 / 相邻武器耐力消耗 −1} 抽一 |
| `moonherb_seed` | 月光草籽 1×1 | 3 | 无效果 | `regen_hp` +1 | `regen_hp` +2，开战时清掉自己一层减益（`on_battle_start → remove_status` 任一减益 1 层） |

- 怎么拿到：进搜索池与商店（稀有度照常），自然之神祭坛赐福不碰；猎手池不放。价值 `ItemValue` 公式照常。
- 美术：三件各一张本图 + 两张阶段变体图（`thorn_seed@s1.png`、`thorn_seed@s2.png`，变体图规则在 208 §2.3），先用本图落地，变体图后补不改代码。

## 3 改动

| 文件 | 改什么 |
|---|---|
| `core/inventory/growth_profile.gd`（新） | `GrowthStage`（name / prefix / after / lock / mods / rules / bonus_pool / bonus_count）与 `GrowthProfile`（stages / stage0_name / reset_on_leave） |
| `core/inventory/item_def.gd` | `@export var growth: GrowthProfile`（分组「生长」） |
| `core/inventory/item_instance.gd` | `growth_stage()`、`growth_ticks()`、`lock_kind()`（读 state） |
| `core/inventory/grid_inventory.gd` | `is_locked(uid)`、`bag_locked(bag_uid)`；`displaced_by` 跳过锁住的 |
| `core/inventory/inventory_service.gd`、`grid_tidy.gd` | 锁住的不动 |
| `core/run/modules/growth_module.gd`（新）+ `run_modules.gd` 登记 | 订 `clock.advanced`；升阶、抽 bonus、`reset_on_leave`（订 `board.changed`，不在棋盘里的清零） |
| `core/battle/compiler.gd` | 第 4b 步旁加阶段加成 |
| `core/text/names.gd` | 生长前缀 |
| `core/authoring/content_importer.gd`、`field_text.gd`、`content_exporter.gd` | 新字段导入 / 校验（只许自然信仰道具；`after ≥ 1`；lock 枚举）/ 导出 |
| `ui/inventory/drag_layer.gd` | 锁住的不拿起 + 提示（`UiText` 键 `notice.rooted`） |
| `ui/inventory/item_tooltip.gd` | 生长一行 |
| `ui/inventory/item_painter.gd` | 实例变体图（与 208 共用，谁先落谁写） |
| `data/authoring/items/thorn_seed.json` 等三件 | §2.6 |
| `core/authoring/id_aliases.gd` + `tools/snapshot_content.sh` | 新道具照 173 的规矩 |
| `docs/architecture.md` 3.9（新小节） | 生长与锁 |
| `tests/run/test_growth_207.gd`（新） | §5 |

## 4 待定（按推荐派执行）

| # | 问题 | 推荐 |
|---|---|---|
| 4.1 | 「倒计时」= 全局倒计时的步数，还是每场战斗一次？ | **步数**（作者在 092 / 150 / 189 里的「倒计时」都指它；休息原地耗时也算） |
| 4.2 | 离开棋盘要不要清零 | **清零**（`reset_on_leave` 默认真；想做「挪盆不死」的树另写假） |
| 4.3 | 休眠时阶段保留还是倒退 | **保留**，锁也保留 |
| 4.4 | 锁住的包里别的东西能不能动 | **能**（只有包本身和扎根的那件动不了） |
| 4.5 | 卖出屏对锁住的件 | **不列**（移不出去） |
| 4.6 | 首批三件的数值 | 执行按 `PowerWeights` 核价值，白 / 绿 / 蓝的绽放档约等于同稀有度的一件饰品 |

## 5 测试

1. 表：`growth` 写在非自然信仰道具上 → error；`after` 0 → error；lock 写错 → error；导出往返一致。
2. 长：棋盘里一颗种子，`clock.spend(4)` → 茎叶、`is_locked` 真；再 `spend(6)` → 绽放、`bag_locked(bag)` 真；地上的一颗 `spend(10)` 不动。
3. 休眠：当前信仰换成日神，`spend(10)` 不长；换回自然继续长；休眠期间编译不带阶段加成。
4. 锁：`InventoryService.move` 锁住的件 → 假；`transfer_all` 跳过它、别的照搬；`GridTidy.tidy` 后它原位；`displaced_by` 不含它；锁住的包 `detach_bag` 不被 DragLayer 调（UI 测试：按下不发 `drag_started`）。
5. 加成：茎叶编译 damage +2，绽放 +4（不是 +6）；`bonus_pool` 两次同种子同 uid 抽到同一条。
6. 清零：绽放的种子 `remove` 进地上再放回 → 阶段 0、不锁。
7. 存档往返：`growth_ticks` / `growth_stage` / `growth_bonus` 原样；老档没记 → 0。
8. 名字：「盛放的荆棘种子」；带耐久的（没有这种组合）前缀顺序测一下占位即可。

## 6 不做

- 不做「生长消耗资源」（浇水、喂食）：倒计时就是代价。
- 不做别的神的同类机制；词留给 `growth`。
- 不做阶段切换动画与音效（挂点在 `grown` 信号上，以后一行）。
- 不动 099 的信仰切换规则。

## 7 落地（架构方案执行 · 2026-10-19）

§4 待定全部按推荐：倒计时 = 全局倒计时的步数；离开棋盘清零；休眠保留阶段与锁；锁住的包里别的东西能动；卖出不另列（扎了根的拖不出去，卖不了）；数值见下。

**和方案不一样的地方**

| 方案 | 落地 | 为什么 |
|---|---|---|
| `bonus_pool` 是规则池，抽中的 id 记进 `growth_bonus` | 池子里每条是 `GrowthBonus`（mods + rules + note），记的是**下标** | 规则没有 id；额外效果也可能只是加属性 |
| `GridInventory.displaced_by` 跳过锁住的 | `displaced_by` 不改；`place_displacing` 与 `DragLayer._displaceable` 见到锁住的就整件作废 | `displaced_by` 还给合成 / 附魔认「压着谁」用，跳过会让预览说谎 |
| `GridTidy.tidy` 绕开锁住的 | 不改 | 它本来就不碰棋盘模式的格子（只整理仓库） |
| 锁在任何棋盘上都算 | 只有一局的作战棋盘锁（`GridInventory.growth_locks`，`GrowthModule` 装的时候开，不进存档） | 基地带回来的棋盘要能一键放进仓库 |
| 带回基地清零（隐含） | `MetaState._adopt` 调 `GrowthProfile.on_leave` | 带回来的那一下不经过一局的棋盘信号 |
| 铁木苗：增益格两侧武器 +2 伤害 | 改成自己给护甲：小树 `max_armor` +8，大树 +18 且 `max_hp` +10 | 阶段加成只作用于这件自己（同信仰加成）；按阶改邻接要另开一套，先不做 |
| 荆棘种子绽放：反伤命中施加流血 | 反伤 3 + 挨到实打实的一下时给对手 1 层流血（冷却 3 秒） | 反伤是伤害包，挂不上「命中后」；用受击时机等价 |
| 月光草籽绽放：开战清一层减益 | 每 5 秒拔掉身上每种减益各一层 | 开战那一刻身上没有减益，原写法永远不起作用 |
| 阶段名「种子」 | 铁木苗写「树苗 → 小树 → 大树」，另两件「种子 → 茎叶 → 绽放」 | 作者原话：也可以是树木的成长阶段 |

**首批三件**（都带 `faith` + `faith:nature` + `nature`，进搜索 / 商店池照常，赐福不派生——它们本身就是信仰道具）

| id | 稀有度 | 第一阶（4 步，扎根） | 第二阶（再 6 步，连包扎根） | 额外效果池（抽 1） |
|---|---|---|---|---|
| `thorn_seed` 荆棘种子 1×1 | 1 | 受直接伤害反伤 1 | 反伤 3；受击给对手 1 层流血（3 秒一次） | 耐力回复 +0.5 / 生命 +12 |
| `ironwood_sapling` 铁木苗 1×2 | 2 | 护甲上限 +8 | 护甲上限 +18、生命 +10 | 护甲上限 +8 / 生命回复 +1 |
| `moonherb_seed` 月光草籽 1×1 | 3 | 生命回复 +1 | 生命回复 +2；每 5 秒拔每种减益一层 | 生命 +15 / 耐力回复 +0.5 |

**改动**：`core/inventory/growth_profile.gd` / `growth_stage.gd` / `growth_bonus.gd`（新）、`item_def.gd`（`growth`）、`item_instance.gd`（整数化）、
`grid_inventory.gd`（`growth_locks`、`is_locked`、`bag_locked`、`any_locked`；`place_displacing` 不顶锁住的）、`inventory_service.gd`（三处）、
`core/run/modules/growth_module.gd`（新，`RunModules.standard` 与 `RunRegistry` 登记）、`compiler.gd`（4b'）、`names.gd`（前缀）、`content_importer.gd`（`_validate_growth`、规则组）、
`field_text.gd`（字段 / 类 / 枚举中文名）、`meta_state.gd`（带回清零）、`ui_text.gd`（`notice.rooted`）、`drag_layer.gd`（按下 / 换包 / 顶替 + `grab_refused`）、
`inventory_panel.gd`（提示 + 双击）、`item_tooltip.gd`（`growth_lines`）；三件道具 JSON + .tres、内容快照、字体子集（新字）；`docs/architecture.md` 3.9；测试 `tests/run/test_growth_207.gd`（4 组）。

**没做**：阶段变体图（等 208 的实例变体图规则与美术的 `@s1/@s2`）、升阶动画与音效（挂 `GrowthModule.grown`）、猎手池没有特意排除（没核过猎手的装备会不会抽到种子）。
