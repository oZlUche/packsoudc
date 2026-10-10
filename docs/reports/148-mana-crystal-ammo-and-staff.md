# 方案：魔晶石弹药 —— 法杖的受益格、晶石的耐久与前缀、三种元素

日期：2026-10-10　状态：架构 · 提议（待作者确认后交「架构方案执行」）

作者原话（2026-10-10）：

> 弹药系统，魔晶石不提供魔力。添加魔法杖武器，拥有基础伤害（当木棍挥舞），当魔晶石成为邻居时（魔法杖拥有受益格，可放入魔晶石），魔法杖在战斗中的伤害随魔晶石品质提升，魔晶石有一定使用次数（上限 3 次），每次战斗后 -1，道具名称的前缀部分发生变化（明亮的、闪烁的、黯淡的对应 1～3 次剩余耐久），耐久为 0 时变为【破碎的】。设计点 1：是引入一个新系统，给道具设计亚种，也就是前缀不同但本体相同的道具算一种，还是将不同版本的魔晶石分开设计成不同道具，每次替换？后者我担心道具数量膨胀。设计点 2：增加魔晶石的种类，对应不同属性伤害，目前可以先设计火焰 / 冰霜 / 闪电三种

---

## 0. 结论（一段话）

**设计点 1 选「同一件道具 + 实例状态」**：剩余次数记在 `ItemInstance.state.charges`（架构文档 12 节早就给「物品损坏」留了这一格），名字前缀由状态算，图鉴里一种晶石就是一条；不做前缀版本的分身道具 —— 那样三种元素 × 四个状态 = 十二件，而且替换实例会打乱格子与存档里的 uid。**设计点 2**：火焰 / 冰霜 / 闪电三种晶石各一件，伤害类型表加 `ice`、`lightning`（火已有）。机制上**不碰法力**：三种晶石都不再给 `max_mana`；法杖是普通武器（木棍级物理伤害）+ 受益格；晶石站在受益格上时把自己的「供给」交给法杖 —— 新加一对字段 `AdjacencyProfile.feed_mods / feed_rules`（供给方不画格子，只说「我站在别人的受益格上时给他什么」）：伤害加成 + 出手时把伤害转成本元素。每场战斗结束，棋盘上**点亮过的**晶石 `charges -1`；归零变【破碎的】，不再供给、卖价打折。

---

## 1. 现状

| 事实 | 出处 |
|---|---|
| 魔晶石 / 破碎的魔晶石是两件材料，各给 `max_mana` 30 / 10；法力的消费者只有无人机（`resource_key: mana`），电池与核心给 `max_mana` | `items/mana_crystal.json`、`mana_shard.json`、`drone.json`、`battery.json`、`core.json` |
| `mana_shard` 在拾荒者开局包里，六个测试引用它 | `loadouts/scavenger.json`；`tests/content/test_materials.gd` 等 |
| 邻接：受益格由**宿主**决定给自己几份 `receive_mods`（按点亮数），邻居是谁不影响数值；增益格则由**供给方**画格子给邻居。两边都要画格子才对得上 | `core/battle/compiler.gd:231-275`、`adjacency_profile.gd` |
| 108 / 132 的附加规则：`grant_rules`（供给方给邻居挂规则）与 `receive_rules`（宿主每点亮一格给自己挂一份），都走 `_attach`，深拷贝、以宿主身份跑 | `compiler.gd:192` |
| 伤害类型是内容：`damage_types/` 里有 physical / fire / poison / bleed / drain / reflect，火「目前与物理同性质」；`convert_damage_type.to` 能把一包伤害改类型 | `data/authoring/damage_types/`、`effects/convert_damage_type.gd` |
| `ItemInstance.state: Dictionary` 存档里已经有、读写往返，但**没有任何读者** | `item_instance.gd:33,83-110` |
| 名字一律 `Names.of(def)`，是定义级的；格子标签与悬浮窗各自调一次 | `ground_layer.gd:469`、`item_tooltip.gd:60` |
| 材料标签规矩：魔晶石与一切魔法相关都是【魔法】 | 2026-10-03 作者定 |

---

## 2. 方案

### 2.1 法杖与供给

- 新武器 `magic_staff`【魔法杖】：标签 `weapon`, `melee`, `staff`, `magic`（【魔法】）；形状 1 × 3（143 的异形规矩照用）；`combat.base_stats` 木棍级物理伤害与冷却（占位数值）；`adjacency.receive_cells` 两格（杖头两侧），`receive_filter: ["crystal"]`，`receive_mods` **留空**（数值由晶石决定）。
- `AdjacencyProfile` 加「供给」一组：`feed_mods: Array[StatModifier]`、`feed_rules: Array[AbilityRule]`、`feed_filter: Array[StringName]`（宿主要命中的标签；空 = 任何宿主）。语义：**本件站在别人的受益格上、且对方命中 `feed_filter` 时，把这些交给对方**；供给方不画格子。编译器受益那一步（`compiler.gd:260`）对每个 provider 多做两件事：`feed_mods` 施加到宿主的 stats（1 份）、`feed_rules` 按 108 的 `_attach(holder, rule, provider.def.id)` 挂到宿主上。悬浮窗照 108 写「附加：… ← 火焰魔晶石」。
- 为什么不用 `grant_cells`：增益格要供给方画格子，晶石形状 1 × 2 旋转四向，格子得画一圈才能保证对上杖头；而且「谁的受益格我站上了」本来就是宿主说了算。供给是「受益格的反面」，补上这一面之后邻接三件事就齐了：我给邻居（grant）、邻居给我（receive）、**我站上谁的受益格就给谁**（feed）。
- 导入校验：`feed_rules` 同附加规则（只许 `on_item_fired`、不许 costs、要有频率）；有 `feed_*` 的道具必须有 `crystal` 之类能被 `receive_filter` 命中的标签（否则永远用不上，报警告）。

### 2.2 三种晶石

| id | 名字 | 标签 | 供给 |
|---|---|---|---|
| `fire_crystal` | 火焰魔晶石 | `part`, `material`, `magic`, `gem`, `crystal` | `feed_mods`：伤害 +X；`feed_rules`：出手时 `convert_damage_type → fire` |
| `ice_crystal` | 冰霜魔晶石 | 同上 | 伤害 +X；转 `ice` |
| `lightning_crystal` | 闪电魔晶石 | 同上 | 伤害 +X；转 `lightning` |

- `damage_types/ice.json`、`lightning.json` 新增，说明照火的写法「目前与物理同性质，元素线」—— 抗性 / 元素反应留给以后，这次只是**类型标签**，让回放与悬浮窗能写「造成冰霜伤害」。
- 形状沿用 1 × 2，稀有度 1，值占位；`feed_filter: ["staff"]`（只喂法杖；以后法书 / 魔枪加标签即可）。
- 「品质」：这一批三件都是一档。更高品质以后按**新道具**加（「精炼的火焰魔晶石」稀有度 2、`feed_mods` 更大）—— 品质是定义级的差别，耐久是实例级的，两件事分开（见待定 2）。
- 老的 `mana_crystal` / `mana_shard`：删掉。`mana_shard` 的「破碎的魔晶石」概念被状态取代；拾荒者开局包里那一格换成一件 `fire_crystal`（开局就能搭法杖）或去掉（见待定 3）；六个引用它的测试换成别的材料 id。法力经济（电池 / 核心 / 无人机）不动，它们是【工艺】线。

### 2.3 耐久与前缀

- `ItemDef.wear: WearProfile`（新资源，可为空）：`max_charges = 3`、`drain = AFTER_BATTLE_WHEN_LIT`（这次只有这一种）、`prefixes = ["黯淡的", "闪烁的", "明亮的"]`（下标 = 剩余次数 − 1）、`broken_prefix = "破碎的"`，加 `display_names` 式的多语言表。三种晶石都写同一份（146 落地后就是一个库构件 / 内联皆可）。
- `ItemInstance.create` 时若 `def.wear != null`，`state.charges = max_charges`；`charges(): int`、`is_broken(): bool` 两个读法；存档走现有的 `state`。
- **扣次数**：新模块 `WearModule`（走 101 插件模型，章节 `modules` 列上）订阅 `events.battle_finished`；拿这一场玩家的 `CombatantSpec`，对棋盘上每件 `wear != null` 且在这一场**点亮过**（`spec` 里它和某个参战件有 `links`，即站在了别人的受益格上 / 别人站在它的增益格上）的实例 `charges -= 1`，不低于 0；没点亮的不掉（没用就不耗）。秒杀（蛮神 3 级）不算一场，不扣。
- **破碎**：`is_broken()` 时编译器跳过它的 `feed_*`（供给没了，法杖回到木棍）；`ItemValue.of` 对破碎实例按折扣算（占位：四分之一）；图鉴与悬浮窗写「破碎：不再供给」。能不能修复这次不做（以后可以是神坛 / 配方）。
- **名字**：新的 `ItemNames.of(inst)`：`def.wear != null` 时 `prefix + Names.of(def)`，否则就是 `Names.of(def)`。格子标签、悬浮窗标题、地上、仓库、出售页、战斗回放的名字表都改调它（`Names.of(def)` 留给只有定义的地方：图鉴、编辑器、商店货架）。
- 图鉴：一条「火焰魔晶石」，词条里写耐久规矩；不列四个前缀版本。

### 2.4 为什么不做分身道具

分身道具（`fire_crystal_bright / _flicker / _dim / _broken`）的代价：三元素 × 四态 = 十二件；每场打完要在格子里**替换实例**（uid 变，存档、拖拽、链接表都要跟着换）；图鉴、商店、掉落池、配方都得过滤掉非完整态。状态方案一件就是一件，架构文档 12 节本来就把「物品损坏」指向 `ItemInstance.state`。唯一要补的是「名字看实例」这一处，2.3 已列。

---

## 3. 实施清单（给执行线程）

1. `AdjacencyProfile.feed_mods / feed_rules / feed_filter` + 编译器受益步 + 导入校验 + 悬浮窗来源文字；`docs/architecture.md` 4.2 补「供给」第三面。
2. `damage_types/ice.json`、`lightning.json`。
3. `WearProfile`、`ItemInstance.charges / is_broken`、`ItemNames.of(inst)` 及调用点替换；`ItemValue` 折扣。
4. `WearModule`（订阅 `battle_finished`，按 `links` 判点亮）；`RunModules.standard()` 与章节 JSON。
5. 道具：`magic_staff`、三种晶石；`tags/crystal.json`、`tags/staff.json`；删 `mana_crystal` / `mana_shard`，改拾荒者开局包与六个测试。
6. 测试：法杖独自 = 木棍伤害；挨着火晶石 = 伤害 +X 且回放里是火焰伤害；两格各一颗晶石 = 两份；破碎晶石不供给；打一场点亮过的 −1、没点亮的不动、秒杀不扣；名字前缀四态；存档往返保留 charges；老档没有 charges 的实例按满算；`ContentCheck` 一致。
7. README 落地记录；`docs/architecture.md` 12 节「物品损坏」那一行改成「已实现：WearProfile」。

---

## 4. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 耐久怎么扣 | A 每场结束，**点亮过**的晶石 −1；B 棋盘上所有晶石一律 −1 | **A**：没装上法杖的晶石是材料，不该坏 |
| 2 | 伤害加成随什么变 | A 随晶石的品质（定义级，更高品质以后是新道具），耐久只决定还供不供；B 随剩余次数（明亮 > 闪烁 > 黯淡） | **A**：作者原话「随品质提升」；B 会让每打一场法杖变弱，手感差 |
| 3 | 老的 `mana_crystal` / `mana_shard` | A 删掉，拾荒者开局包改放一颗火焰魔晶石；B 保留当普通材料（改名、去掉 max_mana） | **A**：作者说晶石不提供魔力、破碎是状态，留着两件只会混 |
| 4 | 破碎晶石 | A 留在格子里、卖价打折、不可修复；B 直接消失 | **A**：玩家看得见「用完了」，也能卖掉；修复留给以后 |
| 5 | 元素的实际差别 | A 这次只加类型标签（与物理同性质）；B 顺带加敌人抗性 | **A**：先把弹药机制立住，抗性是另一张表 |
