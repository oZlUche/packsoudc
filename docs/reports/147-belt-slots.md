# 方案：腰带槽（随身消耗品槽）—— 烟雾弹与急救包

日期：2026-10-10　状态：架构 · 提议（待作者确认后交「架构方案执行」）

作者原话（2026-10-10）：

> 类似杀戮尖塔的药水槽，也就是额外模块，默认槽位 3 个（可扩展），一些特殊道具不进包而是进入这个槽位，道具目前设想的有：烟雾弹（开战前使用，避战，视为战败但不扣血，不能在 BOSS 战使用）、治疗包（战斗外使用，恢复一点体力）。

---

## 0. 结论（一段话）

新加一个一局内的玩法模块「腰带」（`BeltModule`，走 101 的 `RunModule` 插件模型，`RunState` 零改动）：一条 1 × N 的格子容器，默认 3 格、由 `RunContext.belt_slots` 决定（科技 / 角色 / buff 以后都能加）；只收带【随身】标签（`belt`）的道具，这类道具**不能放上棋盘**（不参战、不占背包），地上与仓库照旧什么都收。随身道具是第一种**主动使用**的道具：`ItemDef.belt_use` 写「什么时候能用、用了做什么」，点一下就消耗。首批两件：**烟雾弹**（战前准备屏上用，这一场不打：点算用过、没有战利品、不扣体力 —— 和 136 的「脱身」是同一条路 `skip_pending_battle`；核心点用不了）、**急救包**（地图上任何时候用，体力 +1）。界面：地图屏的物品栏上方一条腰带，战前准备屏上也露出来（烟雾弹就在那儿点）。

---

## 1. 现状与可借的东西

| 事实 | 出处 |
|---|---|
| 一局的玩法子系统都是 `RunModule` 插件（保险箱、暂存、合成、buff、神坛、倒计时），加一种 = 一个子类 + 注册表一行 + `FieldText` 标签 + 章节 JSON 列一条 | `core/run/modules/`，101 |
| 容器基类 `ItemContainer`，`GridInventory.new(size, id, requires_bag)` 可以造任意尺寸的格子，`accepts(def)` 决定收不收 | `core/inventory/grid_inventory.gd:40,84` |
| 「这一场不打、点算用过、没有战利品、不扣体力、核心点不许」已经有：`NodeEvents.skip_pending_battle` + `SlipSkill.blocked_reason` | `core/run/node_events.gd:542`、`core/run/skills/slip_skill.gd` |
| 体力恢复：`Vitality.restore(amount, reason)` | `core/run/vitality.gd:81` |
| **今天没有任何「主动使用一件道具」的动作**：道具的 `effects` 是激活即生效的被动效果，药剂（治愈药剂、绷带）都是战斗内规则 | `core/inventory/item_def.gd:116`、`items/healing_draught.json` |
| 现有 `medkit`【医疗包】是 `sealed` + `remedy` 的战斗道具，与这次的「急救包」不是一件东西 | `items/medkit.json` |
| 架构文档 12 节预留：新作用域的效果走 `Effect` 子树 | `docs/architecture.md` 扩展表 |

---

## 2. 方案

### 2.1 模块与容器

- `core/run/modules/belt_module.gd`：`BeltModule extends RunModule`，`id = &"belt"`。`install` 时造 `belt: GridInventory`（`Vector2i(slots, 1)`，`requires_bag = false`，`only_tags = [&"belt"]`）；`slots = run.hooks.run_context().belt_slots`（默认 3；`RunContext` 加字段，新的 `RunEffect` `BeltSlotsBonus` 给科技 / 角色 / 局外 buff 用 —— 这就是「可扩展」）。槽数变大时扩列，变小只在空格上缩。
- `GridInventory` 加两个过滤：`only_tags`（只收命中的）与 `reject_tags`（命中就不收），都进 `accepts`。棋盘 `reject_tags = [&"belt"]`；暂存区（地上）与仓库不设 —— 128 的规矩「地上什么都收」不变，随身道具也能带回家、下一局再带进来（带入时进腰带，不占棋盘）。
- 存档：`to_dict()["modules"]["belt"] = {"slots", "items": belt.to_dict()}`；没有这一节的老档 = 空腰带（无版本升级）。
- 章节 JSON 的 `modules` 列上 `belt`；`RunModules.standard()` 也加。

### 2.2 主动使用

- `ItemDef.belt_use: BeltUse`（新资源，可为空；有它的道具导入器要求带 `belt` 标签、`combat == null`、形状 1 格）：
  - `when: enum { MAP, PREBATTLE, ANY }` —— 地图上 / 战前准备屏 / 都行。
  - `effects: Array[BeltEffect]`，新的抽象 `BeltEffect extends Effect`（新作用域，`EffectRegistry.BELT_EFFECTS` 登记），`apply(run: RunState) -> String`（返回空串 = 用了；非空 = 为什么现在不能用，界面灰字显示）。
  - 首批两个效果：`SmokeEscape`（`run.events.pending_battle` 为空或是核心点 → 不能用；否则 `skip_pending_battle()`）、`RestoreVitality(amount = 1)`（体力满了 → 不能用）。
- 使用入口：`BeltModule.use(uid) -> String`：查 `when` 与每个效果的可用性，都行就逐个 `apply`、从腰带移走、发 `used(def_id)` 信号；`RunHooks` 登记 `belt_use`，界面只认 hook。
- 不算行动点、不算一步（和吃药一样是即时动作）。

### 2.3 道具

| id | 名字 | 标签 | 形状 | 稀有度 / 值 | 用法 |
|---|---|---|---|---|---|
| `smoke_bomb` | 烟雾弹 | `belt`, `tool`, `craft`（【工艺】） | 1 | 1 / 占位 | 战前准备屏：这一场不打，按「脱身」收尾（搜索遭遇按打输收会话但不弹「被赶跑」）；核心点不能用 |
| `aid_pack` | 急救包 | `belt`, `remedy`, `craft` | 1 | 1 / 占位 | 地图上任何时候：体力 +1；满了不能用 |

来源：搜索点 / 掉落 / 商店按普通道具进池（`drop_rules` 不用改）；建议商店常备一件烟雾弹（价格占位）。文本全占位，不写阿拉伯数字。

### 2.4 界面

- 地图屏的物品栏（`InventoryPanel`）棋盘上方加一条「腰带」`InventoryView`（1 × N），注册进 `DragLayer`（拖进拖出、地上双击随身道具优先进腰带）；点一下 / 双击一件 → `belt_use`，不能用的悬浮窗里灰字写原因。
- 战前准备屏（`prebattle_screen.gd`）在「开打」「脱身」旁边列出腰带里 `when` 含 PREBATTLE 的道具（烟雾弹），点了就走 `belt_use`，和脱身一样回地图。
- 腰带与棋盘都走主题变体，不新增 `add_theme_`（121 棘轮已顶满）。

---

## 3. 实施清单（给执行线程）

1. `GridInventory.only_tags / reject_tags`；棋盘建时 `reject_tags = [belt]`（`RunState.start` 与读档两处）。
2. `BeltEffect` 基类 + `SmokeEscape` / `RestoreVitality`；`BeltUse`；`EffectRegistry.BELT_EFFECTS`；`FieldText` 标签；导入器校验（标签 / 无 combat / 1 格 / `when` 合法）。
3. `BeltModule`（`install / to_dict / restore / describe / use`）、`RunHooks.belt_use`、`RunContext.belt_slots` + `BeltSlotsBonus`；`RunModules.standard()` 与章节 JSON。
4. 两件道具 JSON、`tags/belt.json`（【随身】）、导入 `.tres`。
5. 界面：`InventoryPanel` 腰带行、`PrebattleScreen` 的随身按钮；`ItemTooltip` 写「随身：<用法说明>」。
6. 测试（`tests/run/`）：随身道具进不了棋盘、进得了地上与腰带；腰带满了不收；烟雾弹在普通战 / 搜索遭遇 / 核心点三种情形；急救包满体力不可用、否则 +1 并消耗；存档往返；`belt_slots` 改 4 后扩列；老档无 belt 节读出空腰带。
7. `docs/architecture.md` 新小节「腰带」（挂在一局的模块清单下）；README 落地记录。

---

## 4. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 随身道具能不能进仓库、跨局带入 | A 能（当普通道具存，带入时落在腰带）；B 不能，一局用不完就丢 | **A**：和「地上什么都收」一致，少一条例外 |
| 2 | 烟雾弹对搜索遭遇 | A 与脱身相同：收会话、收获照交、不弹「被赶跑」；B 只对节点战有效 | **A**：复用一条路，少一套分支 |
| 3 | 用随身道具算不算行动点 | A 不算；B 算一步 | **A**：作者说的是「使用」，不是「休息」 |
| 4 | 腰带在哪些屏露出 | A 地图屏物品栏 + 战前准备屏；B 只在地图屏 | **A**：烟雾弹的使用时机就在战前准备屏 |

---

## 落地记录（2026-10-10，四项待定全按推荐）

- **模块与容器**：`BeltModule`（`core/run/modules/belt_module.gd`，容器 id 5），默认 3 格，`RunContext.belt_slots_bonus` 往上加（新 `RunEffect` `belt_slots_bonus`）。扩格用新加的 `GridInventory.resize_cols`，缩格只缩右边的空列。`only_tags / reject_tags` 有值时才写进存档。
- **棋盘**：`RunState.start` 与 `from_dict` 都给作战棋盘设 `reject_tags = [belt]`。开局屏的棋盘不设，随身道具可以摆在那儿带进来；进局时作战棋盘不收，先落在地上，腰带装上时（只在新开局）挪进腰带，满了的留在地上。撤离时腰带里的进 `RunResult.carried`。
- **效果**：`BeltEffect` 放在 `core/effects`（和 `RunEffect` 同层，`BeltUse` 在 `core/inventory` 引用它不违反分层），登记在 `RunRegistry.BELT_EFFECTS`（种类 `belt_effect`）。回体力的叫 `mend_vitality`（类 `MendVitality`），因为 `restore_vitality` 已经是事件后果。烟雾弹的 `smoke_escape` 判断和脱身一样，核心点提示「核心的战斗躲不开」。
- **入口**：`RunHooks.belt_use(uid)`，`GameFlow.use_belt(uid)`（烟雾弹用掉、开打的那一场没了就往下走）。
- **界面**：整理面板棋盘上方一行腰带，双击是「用」，地上双击随身道具先进腰带。战前准备屏在「开战 / 溜走」那排列出能在这里用的随身道具，用不了时按钮灰着、写原因。用不了的原因写在提示行和按钮上，没有写进悬浮窗。悬浮窗多一行「随身：……用：……」。没有新增 `add_theme_`。
- **道具**：`smoke_bomb`（烟雾弹，`belt` / `tool` / `crafted`）、`aid_pack`（急救包，`belt` / `remedy` / `crafted`）、标签 `belt`【随身】。都按普通道具进搜索 / 掉落 / 商店池，商店没有单独常备。
- **测试**：`tests/run/test_belt_147.gd`（容器、开局带入、用法、存档往返与老档、撤离、导入校验）。
