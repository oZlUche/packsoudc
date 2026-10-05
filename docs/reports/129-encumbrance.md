# 129 方案：负重 —— 每件道具一个重量，角色各有负重上限，科技加上限，超重三级递进（减战斗属性 → 再减 → 走路翻倍）

> 架构 · 提议（2026-10-05）。作者补充（同日）：「不要直接降低伤害，可以降低耐力恢复、上限和急速」—— 减益只碰耐力回复、耐力上限、急速。作者：「增加负重系统，给道具设计重量（要符合它们的名称和占据空间），给不同角色设计不同的初始负重。增加可以提升负重上限的科技。设计多个递进的负重等级，负重达到某个阈值时触发，第一级小幅度降低战斗属性，第二级中幅度降低战斗属性，第三级将从节点移动花费的时间翻倍」。

## 一、现状（已核实）

- 道具没有重量这个概念：`ItemDef` 只有形状（占几格）、稀有度、价值、标签（`core/inventory/item_def.gd`）。「占空间」已经由棋盘格子限制，重量是**另一条轴**：一把板甲和一卷丝绸都占几格，但一个压死人一个轻飘飘。
- 角色（`CharacterDef`，`core/run/character_def.gd`）按角色变的有：战斗基线、体力上限、棋盘尺寸、初始包、带入件数 / 稀有度上限。再加一样「负重上限」就是第七样，顺手。
- 一局的可改机制走 `RunContext` 字段 + `RunEffect` 构件 + 读它的系统（`core/run/run_context.gd` 头注写明：「加一种可改的机制 = 这里多一个字段 + 一个 RunEffect 构件 + 那个系统去读」）。科技加上限正好是这条路：`tech_run_buff` → `RunBuffDef(scope META)` → `RunEffect`，119 之后配置在 `docs/techs.xlsx`。
- 战斗属性的减益走 `StatModifier`（乘区 / 固定值，`core/battle/stat_modifier.gd`），`RunState.compile_player` 已经把局外 / 一局 buff 的 `mods` 并进编译入参；常驻加成在战前 / 战斗屏的 buff 栏由 `BattlePassives.of(run)` 列出。负重减益就是**又一个来源**，不用新机制。
- 走一步花几点由 `MapNavigator.resolve_step` 从边的 `action_cost` 造成 `MoveIntent.action_cost`，`MapTravel.apply` 唯一一处 `clock.spend(intent.action_cost)`；地图屏的预览与日志读 `intent.action_cost`。翻倍只需在**花**的那一处乘一个倍率，并让预览读同一个数。
- 128 之后拖出背包 = 放在地上，地上的东西**不背着**，自然不算重量；保险箱（`SafeModule`）是节点里的箱子，也不算。所以**负重 = 作战棋盘上所有东西（包括包本身）的重量之和**，一句话说得清。

## 二、设计

### 2.1 重量：一个整数，单位叫「重」

`ItemDef.weight: int`（默认 0 = 按公式）。公式 = 格数 × 每格重，每格重按**材质类**取：

| 类 | 判定（按标签，从上到下取第一个命中） | 每格 |
|---|---|---|
| 重 | `heavy` | 3 |
| 金属 | `metal`（武器、甲、盾、矿石、锭、枪） | 2 |
| 轻 | `remedy` / `food` / `ammo` / `keepsake` / `sigil` / `treasure` / `relic`，以及布、皮、绳、草药、蜡这几件 | 半格一重，向上取整 |
| 一般 | 其余（木、骨、陶、皮包、无人机…） | 1 |

公式只是**默认值**，让以后新加的道具不填也有一个说得过去的数；本篇 101 件全部过了一遍，二十六件按名字手调（`weight` 字段写死）：原木、水晶簇、铁钉桶、能量核心、战锤、撬棍比公式重；弓、皮、挂毯、陶罐、瓷瓶、细软的东西比公式轻；一格的小东西（护符、骰子、碎片、宝石）一律 1。全表见附录 A。几个锚点：匕首 2、制式短剑 4、长剑 6、板甲 27、塔盾 18、圆盾 8、皮革包 3、口粮 1、铁矿石 6、橡木原木 6、丝绸卷 2。

TextLint：`weight` 是数据不是文字，不受「不许裸数字」约束；悬浮窗上一行「重 {weight}」走占位符。

### 2.2 负重与上限

- **负重** `RunState.carry_weight() -> int`：棋盘上每件（含包）的 `ItemValue`-式求值 `ItemWeight.of(def)`（写死的用写死的，否则公式）求和。只读，不存档（和 120 一样派生）。
- **上限** `RunState.carry_capacity() -> int` = `CharacterDef.weight_capacity` + `RunContext.carry_capacity_bonus`。
- **角色初始上限**（按定位，三人差一截）：

| 角色 | 上限 | 理由 |
|---|---|---|
| 安德烈乌斯 | 28 | 擅长逃跑，轻装；标准初始包（两皮包 + 短剑 + 内甲 + 伤药 + 纱布 + 口粮）重 14，刚好半满 |
| 马库斯 | 34 | 军团士兵，背得多 |
| 布鲁图斯 | 40 | 擅长生存、坚韧，最能扛 |

参照：两个皮革包塞满金属货约 30；再捡一个长条包、一个小背包塞满约 50；一件板甲 27。所以安德烈乌斯开局就要掂量重货，布鲁图斯捡到第三个包才开始吃力。

### 2.3 三级递进

超重按**上限的倍数**分级（科技加了上限，三条线一起往外推）：

| 级 | 触发 | 效果（推荐值） |
|---|---|---|
| 零（轻装） | 负重 ≤ 上限 | 无 |
| 一（吃力） | 上限 < 负重 ≤ 上限 × 1.25 | 急速 −10%、耐力回复 −10% |
| 二（超重） | 上限 × 1.25 < 负重 ≤ 上限 × 1.5 | 急速 −25%、耐力回复 −25%、耐力上限 −20% |
| 三（寸步难行） | 负重 > 上限 × 1.5 | 二级的减益照旧，**每走一步的行动点 ×2**（走路与传送都翻倍；原地扎营 / 等待不翻倍） |

**不碰伤害**（作者定）：背得重的人出手慢、喘得急，但砍下去还是那一刀。急速走乘区（`StatModifier mult_category = HASTE, mult_percent = −10 / −25`），耐力回复与耐力上限走 `flat`（按角色基线的比例折成负数，执行时定具体值；不为它们新开乘区桶），和别的 buff 一样进 4.3 的公式。三级为什么还留着二级的减益：否则「再多背一点就只慢不弱」反而鼓励人冲进三级。

规则是数据：`core/run/encumbrance_rules.gd`（`EncumbranceRules` Resource，`data/authoring/encumbrance_rules/standard.json`，`ChapterDef.encumbrance_rules` 指它，空 = 不开负重；和 `node_rules` / `economy_rules` 同一条路）：

```json
{
  "id": "standard",
  "levels": [
    {"over": 1.0,  "display_name": "吃力",     "mods": [{"stat": "haste", "mult_category": 3, "mult_percent": -10}, {"stat": "regen_stamina", "flat": -0.1}], "travel_mult": 1},
    {"over": 1.25, "display_name": "超重",     "mods": [{"stat": "haste", "mult_category": 3, "mult_percent": -25}, {"stat": "regen_stamina", "flat": -0.25}, {"stat": "max_stamina", "flat": -0.2}], "travel_mult": 1},
    {"over": 1.5,  "display_name": "寸步难行", "mods": [同二级], "travel_mult": 2}
  ]
}
```

`over` = 超过上限的倍数（严格大于才算），级数 = 命中的最后一行。`regen_stamina` / `max_stamina` 的 `flat` 这里写的是**比例**（−0.1 = 基线的一成），执行时由 `EncumbranceRules.combat_mods(baseline)` 乘基线折成真正的 flat 值；若执行时觉得直接写绝对值更省事也行，但表里要能看出「一成 / 两成半 / 两成」这个意图。

### 2.4 科技：「扛重」

`docs/techs.xlsx` 加一个节点（119 的表是唯一来源，执行时跑 `tools/techs_xlsx_to_json.gd` 再导入）：

| id | 名称 | 英文名 | 列 | 排序 | 前置 | 说明 | 效果构件 | 构件参数 | 每级说明模板 |
|---|---|---|---|---|---|---|---|---|---|
| `hauling` | 扛重 | Hauling | 1 | 2 | endurance | 背得更多再开始吃力。 | tech_run_buff | `{"effect": "carry_capacity_bonus"}` | 负重上限 {carry_capacity_bonus_amount\|signed} |

| 科技 id | 级 | 钱 | 材料 | 效果参数 |
|---|---|---|---|---|
| hauling | 1 | 300 | — | `{"amount": 6}` |
| hauling | 2 | 700 | beast_hide: 1；rope_coil: 2 | `{"amount": 12}` |
| hauling | 3 | 1200 | tanned_leather: 2；hardwood_plank: 1 | `{"amount": 20}` |

放在「耐久」下面、和「筋骨」「不屈」并排（第 1 列是身体那一列）。配套：`run_buffs` 里 `tech_hauling_1/2/3`（META，各一条 `carry_capacity_bonus`），新 `RunEffect` 构件 `core/run/effects/carry_capacity_bonus.gd`（`amount: int`，`ctx.carry_capacity_bonus += amount`，`describe` = 「负重上限 +n」），`RunRegistry.RUN_EFFECTS` 登记，`RunContext.carry_capacity_bonus: int = 0` 进 `snapshot()`。

### 2.5 接到战斗与走路

- **战斗**：`RunState.compile_player` 的 `mods` 再并上 `Encumbrance.combat_mods(run)`（当前级那一行的 `mods`）；`BattlePassives.of` 加一条「负重：{level_name}（{效果一句}）」，战前 / 战斗屏的 buff 栏就能看见为什么变弱了。拖动预估（`inventory_panel._refresh_readout` 走 `compile_player`）天然跟着变。
- **走路**：`MapTravel.action_cost_mult: int = 1`，`apply()` 里 `clock.spend(intent.action_cost * action_cost_mult, intent.kind)`；`RunState` 在棋盘 `changed` 与开局 / 读档后重算一次级数并写进去（`travel.action_cost_mult = rules.travel_mult_of(level)`）。地图屏预览与日志改读 `travel.cost_of(intent)`（= 乘过的数），玩家点之前就看见「花 2 点」。`wait()` 不乘。
- **级数**：`RunState.encumbrance_level() -> int`，`encumbrance_changed(level)` 信号（级数真变了才发；HUD 与地图屏听）。

### 2.6 界面

- 背包面板读数区加一行：「负重 {weight} / {capacity}　{level_name}」，超重时整行用警示色；拖动中实时变（`board.changed` 已连着 `_refresh_readout`）。
- 道具悬浮窗属性区加「重 {weight}」。
- 地图屏顶栏体力旁加一个小标：零级不画，一到三级画「吃力 / 超重 / 寸步难行」，三级额外注「走一步花双倍」。
- 开局屏（带入）照样算：带太多就直接显示级数，让玩家在出发前看见，不拦。
- 术语：`Glossary.TERMS` 加「负重」「吃力」「超重」「寸步难行」（弹）；百科「背包」类加一页 `encumbrance`（125 的格式，数字全走占位符 `{weight}` / `{capacity}`；阈值的倍数写成「上限的四分之一」「一半」）。

### 2.7 不改的

敌人没有负重（它们的棋盘不是背的）；仓库 / 保险箱 / 地上不算重；体力、搜索、掉落、商店不看负重；存档不加字段（重量与级数全派生）；现有道具的格子、价值、标签不动。

## 三、改动点

| 文件 | 改动 |
|---|---|
| `core/inventory/item_def.gd`、`core/inventory/item_weight.gd` 新 | `weight` 字段；`ItemWeight.of(def)`（写死 / 公式） |
| `data/authoring/items/*.json`（26 件） | 附录 A 加粗那些写 `weight` |
| `core/run/character_def.gd`、`data/authoring/characters/*.json` | `weight_capacity`：28 / 34 / 40 |
| `core/run/encumbrance_rules.gd` 新、`data/authoring/encumbrance_rules/standard.json` 新、`ContentCheck.KINDS` / `ContentPaths` 登记、`ChapterDef.encumbrance_rules` | §2.3 |
| `core/run/run_context.gd`、`core/run/effects/carry_capacity_bonus.gd` 新、`core/run/run_registry.gd` | `carry_capacity_bonus` |
| `docs/techs.xlsx`、`data/authoring/techs/hauling.json`（生成）、`data/authoring/run_buffs/tech_hauling_*.json` | §2.4 |
| `core/run/run_state.gd` | `carry_weight / carry_capacity / encumbrance_level`、`encumbrance_changed`、编译并入减益、改 `travel.action_cost_mult` |
| `core/run/battle_passives.gd` | 负重一条 |
| `core/run/map_travel.gd`、`ui/game/map_screen.gd` | `action_cost_mult`、`cost_of(intent)`、预览 / 日志、顶栏小标 |
| `ui/game/inventory_panel.gd`、`ui/inventory/item_tooltip.gd`、`ui/game/setup_screen.gd` | 读数行、「重」、开局屏 |
| `core/text/glossary.gd`、`data/authoring/help_pages/encumbrance.json` | 术语、百科 |
| `docs/architecture.md` 7.x | 一节「负重」 |
| `tests/run/test_encumbrance.gd` 新 | 公式与写死值、三人上限、级数边界（恰等于上限 = 零级）、科技加上限后级数变化、编译后急速 / 耐力回复 / 耐力上限确实按级减、伤害不变、三级走一步扣双倍而等待不翻倍、地上 / 保险箱不算重、存档读回级数一致 |

## 四、待定（都按推荐）

| # | 问题 | 推荐 | 备选 |
|---|---|---|---|
| 1 | 阈值怎么定 | **上限的倍数**（1 / 1.25 / 1.5），科技一加三条线一起动 | 绝对值（上限 +0 / +8 / +16）：科技只推第一级 |
| 2 | 三级要不要保留二级的战斗减益 | **保留**，否则「再多背一点只慢不喘」 | 只翻倍不减属性（作者原话只说翻倍） |
| 3 | 包本身算不算重 | **算**（皮革包 3、长条包 2、小背包 2）：包是背着的 | 不算，只算包里的东西 |
| 4 | 传送（传送点）要不要翻倍 | **翻倍**（它也是走一步，花的也是行动点） | 只翻普通步 |
| 5 | 三人上限 | **28 / 34 / 40**（安德烈乌斯 / 马库斯 / 布鲁图斯） | 全部 34，差异留给科技 |

## 附录 A：101 件的重量

公式列 = §2.1 的默认值；定稿列加粗的是手调写进 `weight` 的，其余不填（用公式）。

| id | 名称 | 格数 | 类 | 公式 | 定稿 |
|---|---|---|---|---|---|
| `antidote_kit` | 解毒包 | 1 | 轻 | 1 | 1 |
| `antidote_satchel` | 解毒药囊 | 1 | 轻 | 1 | 1 |
| `antler` | 鹿角 | 3 | 一般 | 3 | 3 |
| `armor` | 防弹衣 | 4 | 一般 | 4 | **8** |
| `armor_plate` | 防弹装甲 | 1 | 金属 | 2 | 2 |
| `arrows` | 箭矢 | 1 | 轻 | 1 | 1 |
| `bag_leather` | 皮革包 | 6 | 一般 | 6 | **3** |
| `bag_long` | 长条包 | 4 | 一般 | 4 | **2** |
| `bag_small` | 小背包 | 4 | 一般 | 4 | **2** |
| `bandage` | 纱布 | 1 | 轻 | 1 | 1 |
| `bandage_roll` | 绷带卷 | 1 | 轻 | 1 | 1 |
| `barbarian_necklace` | 蛮族的项链 | 1 | 一般 | 1 | 1 |
| `battery` | 电池 | 1 | 一般 | 1 | 1 |
| `beast_hide` | 生兽皮 | 6 | 轻 | 3 | **4** |
| `beeswax` | 蜂蜡块 | 1 | 轻 | 1 | 1 |
| `belt_potion` | 药水带 | 3 | 一般 | 3 | **1** |
| `blessed_longbow` | 狩猎之神赐福的长弓 | 4 | 轻 | 2 | **4** |
| `blessed_shield` | 技巧之神赐福的盾牌 | 4 | 轻 | 2 | 2 |
| `bone_charm_bits` | 碎骨串 | 1 | 一般 | 1 | 1 |
| `bone_dice` | 骨骰子 | 1 | 一般 | 1 | 1 |
| `brass_gear` | 黄铜齿轮 | 1 | 金属 | 2 | 2 |
| `charm_brute` | 蛮神的护符 | 1 | 轻 | 1 | 1 |
| `charm_earth` | 大地之神的护符 | 1 | 轻 | 1 | 1 |
| `charm_hunt` | 狩猎之神的护符 | 1 | 轻 | 1 | 1 |
| `charm_nature` | 自然之神的护符 | 1 | 轻 | 1 | 1 |
| `charm_skill` | 技巧之神的护符 | 1 | 轻 | 1 | 1 |
| `charm_sun` | 日神的护符 | 1 | 轻 | 1 | 1 |
| `clay_pot` | 陶罐 | 4 | 一般 | 4 | 4 |
| `cleaver` | 剁刀 | 2 | 金属 | 4 | 4 |
| `copper_ingot` | 铜锭 | 1 | 金属 | 2 | **3** |
| `copper_ore` | 铜矿石 | 1 | 金属 | 2 | 2 |
| `core` | 能量核心 | 5 | 一般 | 5 | **8** |
| `crowbar` | 撬棍 | 3 | 金属 | 6 | 6 |
| `douxing` | 都行 | 4 | 轻 | 2 | 2 |
| `dried_herbs` | 干草药束 | 1 | 轻 | 1 | 1 |
| `drone` | 无人机 | 4 | 一般 | 4 | 4 |
| `field_rations` | 行军军粮 | 2 | 轻 | 1 | 1 |
| `fine_fur` | 细毛皮 | 2 | 轻 | 1 | 1 |
| `flint` | 燧石 | 1 | 一般 | 1 | 1 |
| `gambeson` | 贴身内甲 | 1 | 一般 | 1 | 1 |
| `gilded_goblet` | 鎏金酒杯 | 1 | 金属 | 2 | 2 |
| `glazed_vase` | 彩釉瓷瓶 | 2 | 一般 | 2 | 2 |
| `hardwood_plank` | 硬木板 | 2 | 一般 | 2 | **4** |
| `healing_draught` | 治愈药剂 | 2 | 轻 | 1 | 1 |
| `heart_of_guoguo` | 果果之心 | 1 | 轻 | 1 | 1 |
| `high_tier_armor` | 高级防弹衣 | 9 | 一般 | 9 | **18** |
| `iron_ore` | 铁矿石 | 2 | 金属 | 4 | **6** |
| `ironwood_branch` | 铁木枝 | 2 | 一般 | 2 | **4** |
| `knife` | 匕首 | 1 | 金属 | 2 | 2 |
| `leather_armor` | 皮甲 | 4 | 一般 | 4 | 4 |
| `linen_bolt` | 亚麻布卷 | 3 | 轻 | 2 | 2 |
| `longbow` | 长弓 | 4 | 一般 | 4 | 4 |
| `longsword` | 长剑 | 3 | 金属 | 6 | 6 |
| `mag` | 弹匣 | 1 | 金属 | 2 | 2 |
| `mana_crystal` | 魔晶石 | 2 | 一般 | 2 | 2 |
| `mana_shard` | 破碎的魔晶石 | 1 | 一般 | 1 | 1 |
| `medkit` | 医疗包 | 4 | 轻 | 2 | **3** |
| `mithril_sword` | 秘银附魔长剑 | 3 | 金属 | 6 | 6 |
| `nail_keg` | 铁钉桶 | 4 | 金属 | 8 | **12** |
| `oak_log` | 橡木原木 | 3 | 一般 | 3 | **6** |
| `oil_lamp` | 铜油灯 | 2 | 金属 | 4 | **3** |
| `pale_shard` | 灰白色的金属碎片 | 1 | 轻 | 1 | 1 |
| `panacea` | 万灵药 | 2 | 轻 | 1 | 1 |
| `pistol` | 手枪 | 2 | 金属 | 4 | 4 |
| `plate_cuirass` | 板甲 | 9 | 重 | 27 | 27 |
| `poison_arrows` | 毒箭 | 1 | 轻 | 1 | 1 |
| `poison_vial` | 毒药瓶 | 1 | 一般 | 1 | 1 |
| `poisoned_knife` | 涂毒匕首 | 1 | 金属 | 2 | 2 |
| `quartz_cluster` | 水晶簇 | 4 | 一般 | 4 | **6** |
| `ration` | 口粮 | 1 | 轻 | 1 | 1 |
| `raw_amber` | 琥珀原石 | 1 | 一般 | 1 | 1 |
| `raw_salt` | 粗盐块 | 1 | 一般 | 1 | **2** |
| `rifle` | 步枪 | 3 | 金属 | 6 | 6 |
| `rivet_box` | 铆钉盒 | 1 | 金属 | 2 | **3** |
| `rope_coil` | 麻绳卷 | 1 | 轻 | 1 | 1 |
| `round_shield` | 圆盾 | 4 | 金属 | 8 | 8 |
| `salted_meat` | 腌肉干 | 1 | 轻 | 1 | 1 |
| `salve` | 伤药 | 1 | 轻 | 1 | 1 |
| `scimitar` | 弯刀 | 3 | 金属 | 6 | 6 |
| `shortbow` | 短弓 | 3 | 一般 | 3 | 3 |
| `shortsword` | 制式短剑 | 2 | 金属 | 4 | 4 |
| `shotgun` | 霰弹枪 | 3 | 金属 | 6 | 6 |
| `silk_bolt` | 丝绸卷 | 3 | 轻 | 2 | 2 |
| `silver_ingot` | 银锭 | 1 | 金属 | 2 | **3** |
| `silver_ore` | 银矿石 | 1 | 金属 | 2 | 2 |
| `smg` | 冲锋枪 | 2 | 金属 | 4 | 4 |
| `sniper` | 狙击枪 | 4 | 金属 | 8 | 8 |
| `spyglass` | 望远镜 | 1 | 轻 | 1 | 1 |
| `steel_ingot` | 钢锭 | 1 | 金属 | 2 | **3** |
| `stim` | 兴奋剂 | 1 | 轻 | 1 | 1 |
| `strength_sigil` | 力量的符号 | 1 | 轻 | 1 | 1 |
| `strong_salve` | 浓缩伤药 | 1 | 轻 | 1 | 1 |
| `styptic_dressing` | 止血敷料 | 2 | 轻 | 1 | 1 |
| `tanned_leather` | 熟皮革 | 2 | 轻 | 1 | 1 |
| `tapestry` | 挂毯 | 6 | 轻 | 3 | **4** |
| `tibia_violence` | 胫骨大棒 | 4 | 一般 | 4 | **6** |
| `tower_shield` | 塔盾 | 6 | 重 | 18 | 18 |
| `warding_charm` | 护身符 | 1 | 轻 | 1 | 1 |
| `warhammer` | 战锤 | 3 | 金属 | 6 | **9** |
| `warped_obsidian` | 异化黑曜石 | 1 | 轻 | 1 | **2** |
| `wool_cloth` | 羊毛呢 | 2 | 轻 | 1 | 1 |

<!-- 101 items -->
