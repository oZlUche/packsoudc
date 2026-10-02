# 101 · 方案：RunState / GameFlow 拆分与依赖方向（097 的 P2 + P4）

> 2026-10-01 ｜ 提议 · 作者已确认（RunModule 形状与六刀顺序，待定项按推荐），待执行 ｜ 对应架构文档 1、2、7、8 节

## 目标

- `RunState`（1359 行）和 `GameFlow`（1184 行）不再是每批需求都往里加字段的地方；新子系统像猎手 / 侵蚀那样**自带状态、自带存档、自己接线**。
- 依赖方向回到 2 节的图：`ui → core/run → core/battle | core/inventory | core/map`，不反向。

**不做大重构。** 每一刀都是一个独立 PR，现有测试全绿即可合；刀与刀之间可以插别的需求。

## 现状（已核实）

### RunState
- ~20 个 signal、~70 个 var（`run_state.gd:26-147`），`start()` 15 个参数（`:158-163`），`to_dict` 29 个键手写（`:1227-1263`），`from_dict` 逐字段（`:1283-1358`）。
- 内容分区：开局与走图（`:154-397`）、倒计时 / 保险箱 / 带入预算（`:400-526`）、buff（`:529-620`）、编译与战斗账（`:623-673`）、信仰级效果与神坛（`:676-786`）、角色 / 技能 / 战利品 / 合成 / 装备（`:788-1081`）、接线（`:1084-1223`）、存档（`:1226-1359`）。
- **已经做对的样板**：`HunterSystem`、`ErosionField`、`RunSkills`、`FaithPower` 各自 `to_dict / restore`，`RunState` 只持引用 + 一个 `xxx_saved` 中转（`:115-120, 813-815, 1294-1295, 1331`）。要拆的东西照这个样子拆就行。
- `NodeEvents` 用 **22 个 Callable 字段** 当隐式接口（`node_events.gd:52-114`），`_wire_events` 逐个赋值（`run_state.gd:1118-1184`）；没有类型、没法单独 mock、漏接一个只在运行时才知道。

### GameFlow
- 流程之外还管：存档位（`:88-172`）、成就与解锁（`:329-424`）、仓库出售 / 局外 buff 开关（`:522-565`）、保险箱 / 神坛 / 神罚（`:638-688`）、离开结算卖暂存区（`:694-715`）、内容装载（`:1077-1184`，100 第 4 步会收走）。`_adopt` 80 行接 20 个信号（`:924-1002`）。

### 依赖反向（P4）
| 方向 | 位置 | 说明 |
|---|---|---|
| core/run → ui | `game_flow.gd:83, 930` 写 `ItemTooltip.faith_probe` | 逻辑层直接给一个 UI 静态变量赋值 |
| core/text → ui | `text_template.gd:14-18` 引 `UiPalette` | 样式码颜色表放在逻辑层 |
| core/settings → ui | `game_settings.gd:34, 66-67` 引 `UiPalette` | 设置校验底色 id |
| core/battle → core/run | `compiler.gd:51` 调 `FaithState`；`run_state.gd:634` 编译完再 `FaithPerk.modify_spec` | 战斗层认识局内层；编译器不再是战斗单位唯一来源 |
| core/inventory → core/run | `item_database.gd:40-41` preload `core/run/faith/` | 道具库装载时派生赐福版 |
| core/battle 内核里的信仰特例 | `battle_sim.gd:30`（`draw_is_win`）、`combatant_runtime.gd:57, 286-335`、`damage_resolver.gd:70`（不死） | 按字符串 `spec.flags` 取值，写死在结算 |
| 注册表 | `effect_registry.gd:99-140` 登记 `FAITH_PERKS / EVENT_*`（局内层）| 一张表混三层 |

### UI 里的逻辑
- `setup_screen.gd:171-181, 537-555`：拆 `flow.meta.board` 进暂存区、回主菜单放回 —— 是局外规则，应在 `MetaState`。
- `shop_screen.gd:183-190`：付钱失败自己把货放回货架 —— 是 `ShopSession` 的回滚。
- `game_director.gd:188-390` 演示代码（`DEMO_SCREEN`）混在导演里，`:324` 直接写 `run.phase`。

## 方案

### 第 0 刀 · 扩展点：一局的子系统都是 `RunModule` 插件（作者 2026-10-01 的要求）

作者要的是「流程控制器将来能扩展、能加东西」。仓库里**已经有一个做对了的扩展点**：`RunMechanic`（`core/run/run_mechanic.gd`）—— 难度定义列出机制清单，开局与读档时 `RunState.install_mechanics()` 逐个 `install(run)`，机制自己把自己接进一局（侵蚀、猎手就是这么装的），`RunState` 不认识任何具体机制。问题只是：它现在只给「难度开的机制」用，保险箱、倒计时、神坛、合成这些「本体功能」没走它，所以每加一个都要改 `RunState`。

方案：把这个扩展点升级成一局的**统一插件模型**，本体功能和难度机制走同一条路。

```gdscript
## 一局的模块（RunState 的扩展点）。加一种玩法 = 一个子类 + 注册表一行 + 内容清单里一条，RunState 一行都不改
@abstract
class_name RunModule
extends Resource
@abstract func id() -> StringName                 # 存档里的键、mechanic_tags 的键
func install(run: RunState) -> void               # 开局 / 读档各一次，幂等：造自己的状态、接信号、往 run.hooks 挂回调
func to_dict() -> Dictionary: return {}           # 自己的状态；RunState 存成 modules[id]
func restore(d: Dictionary) -> void               # 读档：install 之前 RunState 把 modules[id] 交给它
func describe() -> String: return ""              # 开局屏 / 规则卡 / 编辑器
```

- **生命周期的钩子不写死在基类里**，模块在 `install` 里**订阅** `RunState` / `MapTravel` / `NodeEvents` 已有的信号（`moved / waited / battle_finished / phase_changed …`），和现在侵蚀、猎手、信力的接法一样（1.2 命令进信号出；逻辑层之间直接引用）。基类只保证「装、存、读、描述」四件事。
- **模块需要被别人调用的能力**（倒计时要拦撤离、保险箱要判还能不能开、神坛要给事件条件查信仰阶）走 `RunHooks`（第 3 刀）：模块在 `install` 里 `run.hooks.register(&"extract_closed", callable)`，`NodeEvents` 只认 `hooks`，不认模块。
- **哪些模块装**来自内容，三层叠加：章节 `ChapterDef.modules`（本体：倒计时、保险箱、神坛…，普通一局就是 `standard` 清单）+ 难度 `DifficultyDef.mechanics`（现有）+ 角色 / 事件临时加的（`run.install_module(m)`）。开局屏的规则卡（091）把 `describe()` 列出来。
- **存档**：`RunState.to_dict()["modules"] = {id: module.to_dict()}`；读档先把字典按 id 分给模块再 `install`。现有 `hunters / erosion / skills / faith_power` 四个键保持原键（098 规矩：格式不改不升版），`modules` 是新增键、带默认值。
- **注册表**：`RUN_MECHANICS` 改名 `RUN_MODULES`（保留旧键名的别名一行），导入器照旧按反射装参数。
- `RunMechanic` 变成 `RunModule` 的别名（`class_name RunMechanic extends RunModule`，一行），侵蚀 / 猎手不用改。

**这意味着将来加一个玩法（比如「天气」「阵营声望」「商队」）的全部工作是：** `core/run/modules/weather_module.gd` 一个文件 + 注册表一行 + 章节 JSON 里 `"modules": [{"type": "weather", ...}]` 一条 + 一个测试。`RunState`、`GameFlow`、`NodeEvents` 零改动；UI 要显示就订阅模块自己的信号。

### 第 1 刀 · `RunState` 现有的子系统搬成模块（P2）

每个搬出去的东西都是一个 `RunModule` 子类，持自己的字段与信号、`to_dict / restore`、在 `install` 里接线。`RunState` 只剩 `modules: Dictionary`，访问走 `run.module(&"safe")`（常用的给一个带类型的便捷取法）。按改动小到大：

| 顺序 | 模块 | 从 RunState 带走 | 行数估 |
|---|---|---|---|
| 1 | `SafeModule`（保险箱，092） | `safe / safe_locked / safe_closed / lock_safe / safe_open` | ~40 |
| 2 | `CountdownModule`（倒计时 + 带入预算，092 / 094） | `countdown_* / carry_* / closing_extract_id / extract_closed / _check_countdown`、6 个 `static *_for` | ~120 |
| 3 | `CraftingModule`（合成，084） | `recipes / craft_* / resolve_crafts / craft_done` | ~90 |
| 4 | `AltarModule`（神坛与信仰级效果，093 / 095） | `altar_* / faith_rituals / faith_stat_bonus / offer / bless_ids / _bless_step / faith_perks / item_blessed` | ~130 |
| 5 | `BuffModule`（buff，062） | `buff_defs / meta_buffs / map_buffs / *_map_buff / tick_map_buffs / buff_context` | ~90 |
| 6 | `NodeStorageModule`（按点暂存，088） | `node_storages / stored_at / _restore_storage / _drop_storage* / storage_dropped / storage_restored` | ~60 |

第一个（保险箱）是样板：做完它，`RunModule` 基类、`modules` 存档键、`ChapterDef.modules`、`standard` 清单、注册表、导入器都通了；后面五个只是照抄。每一刀的验收：`RunState` 行数下降、对应 `test_author_09x` / `test_run_state` 全绿、读档往返测试（051）全绿。六刀之后 `RunState` 约 600 行，只剩「骨架 + 容器 + hooks + 存档」。

**存档格式**：搬进模块的键原样保留在顶层（`safe`、`safe_locked`……）由模块自己读写，还是统一挪到 `modules[id]` 下？推荐**统一挪**，并在 098 的迁移链上加 Run v1 → v2 一步（把旧顶层键搬进 `modules`）—— 这正好是迁移链的第一个真实用例。

### 第 2 刀 · `start()` 收参数

- 100 第 4 步换掉 5 个内容参数（`items / enemies / sets / buff_defs / hunter_defs → content`）。
- 其余 9 个收成一个 `RunSetup`（`Resource` 或 `RefCounted`：`chapter / seed / kit / meta_buffs / character / layout / difficulty / scale / safe_size / carry_value`），开局屏和 `GameFlow.begin` 本来就是先把这些攒齐再调。`start(setup, content)` 两个参数。
- `from_dict` 签名同样收成 `(d, content)`。

### 第 3 刀 · `NodeEvents` 的回调收成接口

- 新类 `RunHooks`（`core/run/run_hooks.gd`，`RefCounted`）：把 22 个 Callable 收成**带类型的方法**，`RunState` 实现它（或持一个实现）：
  ```gdscript
  class_name RunHooks
  func player_spec() -> CombatantSpec
  func loot_context() -> LootContext
  func run_context() -> RunContext
  func grant_map_buff(id) -> bool / remove_map_buff / has_map_buff / has_buff_tag
  func bracket() -> int
  func request_extract() -> bool
  func relocate(intent) -> bool
  func safe_open() -> bool
  func faith_tier() -> int / active_faith_id() / bless_substitute(ids, a, b)
  func before_battle(me, enemy, type) -> void
  func fight_hunter / flee_hunter
  ```
- `NodeEvents.hooks: RunHooks`；原来的 Callable 字段删掉，`_wire_events` 从 60 行变成 `events.hooks = self`。沙盒 / 测试给一个 `RunHooks.new()`（全部默认实现）。
- 顺序放第 1 刀之后：子系统抽走后，`RunHooks` 里一半方法只是转发给子系统。

### 第 4 刀 · `GameFlow` 抽服务

| 抽出去 | 内容 | 持有方 |
|---|---|---|
| `SlotService`（或并进 `SaveSlots`） | `use_slot / continue_game / start_new_game / new_game_in / load_slot / delete_slot`，098 的备份 | `GameFlow.slots` |
| `Achievements` | `check_achievements / achievement_* / unlock_names / locked_item_ids / apply_item_locks / toggle_unlock_all / rules_card_*` | `GameFlow.achievements` |
| `MetaState` 自己 | `sell_item / sell_where / sell_ratio / stash_sale_preview / _sell_left_behind`、开局屏的 `_build_stash` 逻辑（`setup_screen.gd:171-181, 537-555` 搬进来成 `take_board_to_stash / return_stash`） | 已有 |
| `RunState` 自己 | `close_safe / close_altar / offer / smite / safe_size` 只是转发，`GameFlow` 留一行 | 已有 |

`_adopt` 的 20 个 `connect` 不动（它就是「导演要看的信号清单」），但改成一张 `[signal 名 → 处理函数]` 的表，加一个测试「`RunState` 的每个 signal 要么在表里、要么在白名单里」，防漏接。

### 第 5 刀 · 依赖方向（P4）

| 反向处 | 改法 |
|---|---|
| `ItemTooltip.faith_probe` | `GameFlow` 发 `signal run_changed(run)`，`GameDirector` 收到后给 `ItemTooltip` 设 probe；core 不再知道 `ItemTooltip` |
| `TextTemplate` 的 `COLORS` | 颜色名 → 颜色的表搬到 `ui/ui_palette.gd`（`UiPalette.STYLE_COLORS`），`TextTemplate` 只产出带颜色**名**的样式码，渲染时由 UI 查表 |
| `GameSettings.bg_theme` | 校验改成「字符串非空」，是否存在由 UI 侧 `UiPalette.has_bg_theme` 兜底 |
| `compiler.gd:51` 的 `FaithState` | 编译器多一个输入 `dormant: Dictionary`（uid → 休眠），由调用方（`RunState.compile_player`）用 `FaithState` 算好传进来；`FaithState` 搬到 `core/inventory/`（它只看容器和标签，本来就不认识神） |
| `run_state.gd:634` 编译后套 perk | `FaithPerk.modify_spec` 改成**编译期输入**：perk 产出 `StatModifier / AbilityRule / flags`，和套装、buff 一起作为 `mods / rules` 进 `BattleCompiler.compile`；编译器重新成为唯一来源 |
| `spec.flags` 字符串 | `CombatantSpec` 加带类型字段 `draw_is_win: bool`、`undying_sec: int`；「不死」保留在内核（它是结算规则，不是效果），但只读这两个字段 |
| `item_database.gd:40-41` | 赐福派生从 `ItemDatabase.load_dir` 挪到 `ContentLibrary.load_all`（100 第 4 步），`ItemDatabase` 只装目录 |
| `effect_registry.gd` | 拆成三张：`core/battle/effect_registry.gd`（战斗）、`core/run/run_registry.gd`（事件条件 / 后果、信仰行为 / perk、机制）、`core/loot/...`；`ContentImporter` 查表时按基类选表 |

### 第 6 刀 · UI 里的逻辑搬回去

- `shop_screen.gd:183-190` 的回滚 → `ShopSession.pay_or_return(uid)`。
- `game_director.gd:188-390` 演示代码 → `tools/demo_fill.gd`（`GameDirector` 只在有环境变量时 `load` 它）。
- `game_director.gd:324` 的 `run.phase =` → `RunState.force_extract()`（仅演示 / 测试用，标明）。

## 关键决策

- **扩展点只有一个，本体和难度机制走同一条路**：`RunMechanic` 已经证明「模块自己把自己接进一局」在这个仓库里行得通；把它扩成 `RunModule`，以后加玩法不改 `RunState`。
- **抽状态而不是抽行为**：每个模块带走自己的字段、信号和存档，`RunState` 才真的变薄；只抽函数留字段等于没拆。
- **存档：模块键统一挪到 `modules` 下，用 098 的迁移链升一版**；之后再加模块不再升版（新模块 = 新键、带默认值）。
- **`RunHooks` 用类不用 Callable**：22 个 Callable 的问题不是多，是没类型；一个接口类让 `NodeEvents` 可以在测试里用假实现跑。
- **信仰回到编译期**：perk 改 spec 的后门关掉，战斗层只认 `CombatantSpec`；「不死」「平局算赢」是结算规则，可以留在内核，但按类型字段读。
- **顺序**：0 → 1 → 2 → 3 → 4 → 5 → 6。0 和 1 的第一个模块一起做（样板）；1 的后五个、4、6 彼此独立，可并行给不同执行 thread；2 依赖 100 第 4 步；5 里编译器那两条依赖 1 完成（`AltarModule` 出来后 perk 才有自己的家）。

## 验证

- 第 0 刀：一个测试「造一个假模块、写进章节清单、开局 → 装上、存档 → `modules[id]` 在、读档 → `restore` 收到同样的字典」；`grep -n "safe\|countdown\|altar\|craft" core/run/run_state.gd` 在第 1 刀结束时为空。
- 每一刀：`tools/test.sh` 全绿；`wc -l core/run/run_state.gd core/run/game_flow.gd` 下降并写进该刀的报告；读档往返（`test_run_state`、`test_game_flow`）不变。
- 第 5 刀结束：`grep -rn "UiPalette\|ItemTooltip" core/` 为空；`grep -rn "core/run" core/battle core/inventory` 为空；`grep -n "spec.flags" core/battle` 为空。
- 第 3 刀：`NodeEvents` 用 `RunHooks.new()` 默认实现跑 `test_node_events` 全绿。

## 改动范围

全部在 `core/run`、`core/battle`、`core/text`、`ui/game` 的既有文件 + 约 10 个新的小文件。不改内容格式、不改存档格式。

## 待作者定

0. 扩展点按「`RunModule` 插件 + 章节 / 难度清单」做，可以吗？（作者的要求就是这个，这里确认一下形状）
1. 六刀的顺序按上面来，还是你有更急的子系统想先抽？
2. 第 5 刀「perk 回到编译期」会改 14 种 `FaithPerk` 的接口（`modify_spec` → `compile_mods`），要不要和 P1（099）一起交给同一个执行 thread（都碰信仰）？推荐分开，099 先。
3. 演示代码搬去 `tools/`，截图工具 `capture_scene.gd` 跟着改，可以吗？

## 落地 · 第 0 刀 + 第 1 刀的第一个模块（2026-10-01，实现 thread）

作者定：形状就按 `RunModule` 插件 + 章节 / 难度清单；刀序照方案；第 5 刀的 perk 改接口排在 099 之后（099 已落地）；演示代码搬去 `tools/`（第 6 刀，还没做）。
这一刀交的是**扩展点本身 + 保险箱这个样板**。

| 改动 | 文件 |
|---|---|
| `RunModule`：装 / 存 / 读 / 说一句。生命周期**不写在基类里**，模块自己订阅已有信号 | `core/run/run_module.gd`（新） |
| `RunMechanic` 变成它的子类（侵蚀 / 猎手一行没改；`id()` 默认空 = 不进 `modules` 存档，它们各有老键） | `core/run/run_mechanic.gd` |
| `modules` / `module_inputs` / `modules_saved`；`install_modules`（章节清单 + 难度机制两层）、`install_module`（幂等）、`module`、`module_input`、`module_lines`；新信号 `leaving(node_id)`；`to_dict()["modules"]`；`from_dict` 末尾装本体模块 | `core/run/run_state.gd` |
| 默认清单（章节没列时用它）；每搬出一个子系统这里多一行 | `core/run/modules/run_modules.gd`（新） |
| 保险箱：容器、锁、`closed`、存档、「走开就关上」（接 `leaving`）、「锁上了不再开」（`NodeEvents.safe_open`）全在模块里 | `core/run/modules/safe_module.gd`（新） |
| 章节可以列模块（空 = 默认清单） | `core/run/chapter_def.gd` |
| 注册表 `RUN_MODULES`（+`safe`；`run_mechanic` 留作别名）、抽象基类 → 表、编辑器的中文标签 | `core/battle/effect_registry.gd`、`core/authoring/content_schema.gd`、`core/authoring/field_text.gd` |
| 一局存档升到 v2；迁移第一步把顶层 `safe` / `safe_locked` 搬进 `modules.safe` | `core/run/run_state.gd`、`core/run/run_migrations.gd` |
| 调用方改成走模块：结算、`GameFlow`（关保险箱 / 站着能再开 / 开局传 `module_inputs`）、地图屏那一句、保险箱屏 | `core/run/run_result.gd`、`core/run/game_flow.gd`、`ui/game/map_screen.gd`、`ui/game/safe_screen.gd` |
| 新套件：假模块走章节清单（装一次、拿到输入、收到 `leaving`、幂等、存进 `modules[id]`、读档 `restore` 收到同一份）、保险箱的行为与「没装 = 没有保险箱」、注册表与章节 JSON 往返；迁移测试加 Run v1 → v2 | `tests/test_run_modules.gd`（新）、`tests/test_save_migration.gd`、`tests/test_author_092.gd` 等 |

**和方案不同的两处**（都为了不改 `RunState` 却仍能把保险箱的「走开就关上」接出去）：

1. **多了一个 `RunState.leaving(node_id)` 信号**。方案说模块订阅已有信号，但「走开 = 关上」要在**真正动之前**发生（锁上会把保险箱点标成走过的）。
   接 `MapTravel.moved` 就晚了，会和「踩上另一个保险箱点」抢顺序。所以把原来 `step_to` / `relocate` 里那两行 `lock_safe()` 换成 `leaving.emit(...)` ——
   这是通用的生命周期信号，第 1 刀后面的 `NodeStorageModule`（走开就留下）正好也用它。
2. **`start()` 的 `p_safe_size` 换成 `p_module_inputs: Dictionary`**（参数个数没变）。保险箱几格来自局外规则，是运行时输入而不是内容；
   这样 `RunState` 里不剩任何「safe」字样。`GameFlow.begin` 传 `{&"safe": {"size": safe_size()}}`。刀 2 会把它并进 `RunSetup`。

**账**：`run_state.gd` 1359 → 1394 行（基类与清单那套接口先进来了，保险箱搬出去 −40；后面五个模块搬出去才会真降）。
`grep -n "safe" core/run/run_state.gd` 只剩地图生成那两行（`SafePlacer`，属于地图不属于子系统）。全套测试 74 套件 12309 项断言通过。

**下一刀**：第 1 刀余下的五个模块（照抄这个样板）；第 2 刀等 100 第 4 步（`ContentLibrary`）。

## 落地 · 第 1 刀：余下五个子系统（2026-10-01，实现 thread）

照样板又搬了五个，`core/run/modules/` 现在是一局的全部玩法子系统：

| 模块 | 从 `RunState` 带走 | 自己接的信号 |
|---|---|---|
| `NodeStorageModule`（087） | `node_storages` / `stored_at` / 两个信号 / 存档 | `leaving`（留下）、`arrived`（拿回） |
| `CountdownModule`（092 / 094） | `countdown_*` / `carry_in_value` / `closing_extract_id` / `extract_closed` / 六个 `*_for` 算式 / `countdown_notice` | `stepped`（归零就 `run.fail`） |
| `CraftingModule`（084 / 087） | `recipes` / `craft_*` / `resolve_crafts` / `craft_done` | `arrived`（`first_time` 才合） |
| `BuffModule`（062） | `map_buffs` / `*_map_buff` / `tick_map_buffs` / `buffs_changed` | `stepped`（任何花行动点的方式） |
| `AltarModule`（093 / 095） | `altar_*` / `faith_rituals` / `faith_stat_bonus` / `offer` / `faith_perks` / `bless_ids` / `_bless_step` / `altar_changed` / `item_blessed` | `NodeEvents.altar_opened`、`leaving`、`stepped`、`MapTravel.moved` |

为此 `RunState` 多了两个**通用**生命周期信号和一个方法（都不认识任何具体模块，和第 0 刀的 `leaving` 一样）：
`arrived(node_id, first_time)`（到了一个点，在这个点的事发生之前）、`stepped(node_id, reason)`（花掉了行动点，这一步该发生的事都发生完了；
`reason` = `&"step"` / `&"relocate"` / `&"wait"`）、`fail(reason)`（这一局当场失败；倒计时归零用它）。

**和方案不同的三处**：

1. **`BuffModule` 只搬走「一局里拿到的 buff」**，`buff_defs` / `meta_buffs` / `active_buff_defs()` / `buff_context()` 留在 `RunState`。
   原因是开局顺序：`start()` 要先用 `buff_context()` 算体力上限与开局钱，再造旅程与节点事件，**最后**才装得上模块（模块要接的信号那时才存在）。
   把 `buff_context` 搬进模块就会出现「算的时候模块还没装」。要彻底搬得先给模块分两段生命周期（或者第 2 刀的 `RunSetup` 把开局顺序重排），不该在这一刀里偷偷改。
2. **`start()` 去掉 `p_carry_value`**（15 → 14 → 13 个参数）：带入价值和保险箱格数一样是运行时输入，走 `module_inputs[&"countdown"]["carry_value"]`。
3. **原地耗时（`waited`）现在也走一步 buff 表**，和原来一致；但 buff 的走表从「这一步的事之前」挪到了「这一步的事都发生完」（跟着 `stepped`）。
   一步之内的先后，对「还剩几步」的判断没有影响。

**账**：`run_state.gd` 1359 → **962** 行（signal 20 → 13，存档顶层键 29 → 22）。
`grep -n "safe\|countdown\|altar\|craft\|map_buff\|node_storage" core/run/run_state.gd` 只剩三处 `AltarModule.of(self)`（编译单位、战利品、基线要问信仰级效果）
和地图生成的 `SafePlacer`。一局存档的 v1 → v2 现在搬六样：`safe` / `safe_locked` / `node_storages` / `carry_in_value` / `faith_rituals` / `faith_stat_bonus` / `altar_used` / `buffs.map`。
新套件 `test_run_modules.run_module_roster`：六个模块都在默认清单里、都登记在注册表、都有中文名、都在 `modules[id]` 下存了一份、顶层不再有它们的旧键、读档都拿得回去。
全套测试 74 套件 **12356** 项断言通过。

**下一刀**：第 2 刀（`start()` 收参数）等 100 第 4 步的 `ContentLibrary`；第 3 刀（`RunHooks`）、第 4 刀（`GameFlow` 抽服务）、第 6 刀（UI 里的逻辑搬回去）彼此独立。


## 落地 · 第 3 刀：`NodeEvents` 的回调收成 `RunHooks`（2026-10-01，实现 thread）

`NodeEvents` 上 16 个裸 `Callable` 字段、`EventContext` 上 7 个，全收进一个 `RunHooks`（`core/run/run_hooks.gd`，142 行）：
一张名字登记表 `NAMES`（名字 → 这一条由谁接）加 17 个**带类型的方法**，每条的默认值写在方法里。

| 原来 | 现在 |
|---|---|
| `events.player_spec = compile_player` 等 13 处赋值 | `hooks.register(&"player_spec", compile_player)`，调用方写 `hooks.player_spec()`，拿到的一定是 `CombatantSpec` |
| `if safe_open.is_valid() and not safe_open.call():` | `if not hooks.safe_open():`（没装保险箱模块 = 能开） |
| `ctx.faith_tier` / `ctx.active_faith` / `ctx.bracket` / 四个地图 buff 回调 | `ctx.hooks`，外加 `ctx.faith_tier_now()` / `ctx.active_faith_id()` 两个取法 |
| 名字或参数写错 = 运行时静默报错、断言成片消失 | `register` 的名字不在 `NAMES` 里当场 `push_error`；签名由方法定 |

**谁接**：骨架（`RunState._wire_events`）接自己的十条（`player_spec` / `loot_context` / `run_context` / `has_buff_tag` / `bracket` /
`relocate` / `request_extract` / `faith_tier` / `active_faith_id` / `before_battle`）；模块与机制在自己的 `install` 里接自己的
（`SafeModule.safe_open`、`BuffModule` 的三条地图 buff、`AltarModule.bless_substitute`、`HunterSystem` 的迎战 / 逃跑）。
**`NodeEvents` 与 `EventContext` 都不再认识任何模块** —— 第 0 刀解决了「加玩法不改 `RunState`」，这一刀解决了另一半「不改 `NodeEvents`」。

**和方案不同的两处**：

1. 方案写的是「`RunState` 实现 `RunHooks`（或持一个实现）」。那样做模块挂的能力又得由 `RunState` 转发给模块（`safe_open` → `SafeModule.of(self).is_open()`），
   `RunState` 就重新认识每个模块了，和第 0 刀的目标相反。所以改成**一张注册表**：骨架和模块平等地往里 `register`，`RunState` 一条模块的能力都不转发。
2. 方案的清单里没有 `EventContext` 的那 7 个，但它们是同一件事的另一半（`ctx.faith_tier` 和 `events.faith_tier` 接的是同一个方法），
   不一起收就等于把 hooks 又拆回 Callable。一并收了。`EventContext.erosion_depth` 没动 —— 那是节点从 `travel.erosion` 现接的，不是一局的能力。

**账**：`node_events.gd` 793 → 763 行（23 个字段声明 → 1 个 `hooks`），`event_context.gd` 少 7 个字段、多 2 个取法，
`run_state.gd` 962 → 967（`register` 比赋值多了名字那一截，换来的是写错当场报错）。
新套件 `tests/run/test_run_hooks.gd`（103 项断言）：每个登记的名字都有同名方法、没人接时的默认值逐条、
接一个无效 `Callable` = 取消、名字写错接不上也不误接到别条、一局里骨架与各模块各接了什么、以及那 23 个裸字段真的从两个类上消失了（防回头）。
全套测试 **77 个套件、12456 项断言通过**。

**下一刀**：第 4 刀（`GameFlow` 抽服务）、第 6 刀（UI 里的逻辑搬回去）彼此独立；第 2 刀仍等 100 第 4 步的 `ContentLibrary`。

## 落地 · 第 4 刀：`GameFlow` 抽服务（2026-10-01，实现 thread）

`GameFlow` 的本职是「现在该显示哪一屏、给它什么」加「存盘」。能脱离屏与存盘说清的规则都搬出去了，
flow 只留一行转发 —— **界面与测试的调用处一个都没改**（`flow.check_achievements()` / `flow.locked_item_ids()` 照旧）。

| 服务 | 带走的 | flow 还留着 |
|---|---|---|
| `Achievements`（`core/meta/achievements.gd`，107 行） | `check` / `of_id` / `granting` / `unlock_names` / `unlocked` / `locked_item_ids` / `apply_item_locks` / `rules_card_pending` / `mark_rules_seen`。纯逻辑：看局外与内容算结果 | `_sync_achievements()` 把局外 / 内容 / 「全部解锁」开关同步过去，按返回值决定要不要 `save_meta()`；`toggle_unlock_all` 还在 flow（它动的是 `GameSettings`） |
| `SaveSlots.open(n, items, rules)` | 切位要做的文件层的事：建目录、算两条路径、读局外、**读不出来先备份再从零开始**（098 的规矩这下和 `backup` 放在一起了） | `use_slot` 只管当前位、设置里记哪一位、这一局怎么办（20 行 → 10 行） |
| `MetaState`（已有的类） | `left_behind_preview` / `sell_left_behind`（092 暂存区一键出售）、`take_board_to_stash` / `return_stash`（090 带回来的棋盘 ⇄ 开局屏那一栏） | 结算屏调 `stash_sale_preview()` 照旧；开局屏少了 20 行容器搬运代码 |

**和方案不同的三处**：

1. **没有做 `SlotService`**，而是把那段逻辑并进了已有的 `SaveSlots`（方案里写的是「`SlotService`（或并进 `SaveSlots`）」，选了后者）：
   能脱离 flow 说清的只有文件层那一半（建目录、读、备份），余下的 `continue_game` / `start_new_game` / `new_game_in` / `load_slot`
   全是「接下来显示哪一屏、这一局怎么办」—— 那就是 flow 的本职，搬出去只会变成一个拿着 flow 反向调用的壳。
2. **`_adopt` 的 20 个 `connect` 没有改成一张表**。它们接的对象各不相同（`NodeEvents`、`RunState`、模块、会话），
   而且每个闭包都带着自己的排队规则（哪一屏插队、哪一屏并掉）—— 塞进一张 `[signal → 处理函数]` 的表只会让这些规则更难读。
   方案真正要的是**防漏接**，所以直接做了那个测试（下面一条），表没做。
3. **`GameFlow` 行数只从 1226 降到 1190**：抽出去的逻辑换成了同样数量的转发行。这一刀的收益不在行数，
   在于那三块逻辑现在**不造一个 `GameFlow` 就能测**（新套件里就是这么测的），以及 098 / 090 / 092 的规矩回到了它们本来该在的类上。

**不许漏接**（新套件 `tests/run/test_flow_wiring.gd`，99 项断言）：读 `run_state.gd` / `node_events.gd` / `core/run/modules/*.gd` 里声明的每个 signal，
要求 `core/` 或 `ui/` 的源码里有人 `connect` 它，否则红。「发了没人听」的表现是某个屏永远不弹、某句提示永远不出现，
而编译与别的测试都不会红 —— 这是加了信号忘接线时唯一会响的铃。白名单现在只有一条：`NodeEvents.shop_closed`（flow 走会话自己的 `closed` 往下走）。
同一套件还各测了三个服务：成就（新档没有成就 → 刷满数字一枚枚达成 → 不重复给 → 「全部解锁」开着不计 → 规则卡看过就不再弹）、
切位（空位 / 好档读得出 / 坏档先备份再交出 null、老文件改名走了不会被盖、备份不算存档）、
卖与挪（预览只算不卖、真卖只卖一次、没撤离出来的不卖、棋盘 ⇄ 暂存那一栏按原位放回）。

**账**：`game_flow.gd` 1226 → 1190 行，`setup_screen.gd` 少 20 行，新增 `achievements.gd` 107 行、`save_slots.gd` +18、`meta_state.gd` +56。
全套测试 **78 个套件、12555 项断言通过**。

**下一刀**：第 6 刀（UI 里的逻辑搬回 core、演示数据进 `tools/demo_fill.gd`）；第 5 刀（依赖方向：perk 改编译期）独立；第 2 刀仍等 100 第 4 步的 `ContentLibrary`。

## 落地 · 第 6 刀：UI 里的逻辑搬回去（2026-10-01，实现 thread）

方案列的三条全做了。

1. **商店屏的回滚** → `ShopSession.pay_or_return(格, uid, 容器)`。
   「拖走了就结账，结不成（钱不够 / 已卖 / 店关了）把东西从玩家那边拿回来、原样放回那一格」是一局的规则，
   原来写在 `shop_screen.gd` 的拖拽回调里（9 行，手写两条容器分支）。现在界面只剩一句
   `if not _session.pay_or_return(slot, uid, [board, storage]): _say("金币不足…")`。
   顺手补了测试 `test_economy.run_shop_rollback`（15 项断言）—— 这条规则此前只有界面里有、**一条测试都没有**：
   钱够就结账、钱不够原样回架上且钱不动、那一格不算卖出、东西在暂存区里也找得回来。
2. **导演里的演示代码** → `tools/demo_fill.gd`（`class_name DemoFill`，221 行）。
   `game_director.gd` **390 → 196 行**：导演只剩一句「`DEMO_SCREEN` 非空才 `load` 它、调一次 `fill(self, flow)`」，
   所以这段代码不在正式游戏的任何路径上。它干的事（代码里造假难度、替玩家点选项、一路走到撤离点、把叠层全看完）
   本来就是截图工具的事，不该让导演带着。搬家只换了取屏的方式：`_base` / `_overlay` 改成导演已有的 `base()` / `overlay()`。
3. **导演直接写 `run.phase` / `run.end_reason`** → `RunState.force_extract()`（文档注释里标明**只给演示与测试用**，
   正式游戏走 `try_extract` / `extract_after_boss`）。`grep -rn "\.phase = " ui/ tools/` 现在是空的。

**验证**：全套测试 **80 个套件、12684 项断言通过**。另外实跑了截图那条路（`tools/capture_scene.gd` + 探针脚本）：
`DEMO_SCREEN=map / result / meta / search / erosion` 五种各跑一次，流程分别停在 `MAP` / `RESULT` / `META` / `SEARCH` / `MAP`，
和搬家前一致（截图本身在 headless 下存不出图，那是这个工具一直以来的限制，它自己的文件头就写着）。

**账**：`game_director.gd` 390 → 196 行，`shop_screen.gd` 少 6 行，`shop_session.gd` +21，`run_state.gd` +11，新 `tools/demo_fill.gd` 221 行。

**余下的刀**：第 2 刀（`start()` 收成 `RunSetup`）等 100 第 4 步的 `ContentLibrary`；第 5 刀（依赖方向：`ItemTooltip.faith_probe`、
`TextTemplate` 的颜色表、perk 改编译期输入、`spec.flags` 改带类型字段、注册表拆三张）还没动 —— 它是这几刀里唯一会改战斗层接口的，
建议单独一刀做完再合。

## 落地 · 第 5 刀：依赖方向（2026-10-02，实现 thread）

方案列了八条，**做了六条**，两条没做（理由在最后，都不是「忘了」）。架构文档新增 1.3.1、改 10.4，版本 v2.18。

| 方案的那一条 | 落地 |
|---|---|
| `ItemTooltip.faith_probe` | `GameFlow` 新增 `signal run_changed(state)`（开局 / 读档发这一局，回主菜单发 `null`）与 `faith_status()`（只交数据）。`GameDirector._on_run_changed` 才去设 `ItemTooltip.faith_probe`。`core/run/game_flow.gd` 里 `ItemTooltip` 一个字都没有了 |
| `TextTemplate` 的 `COLORS` | 文本层只产出带颜色**名**的样式码：`{c:hp}` → `[color=@hp]`（认得的名字见 `TextTemplate.STYLE_NAMES`，`{c:#ff8800}` 照旧直通）。表搬到 `UiPalette.STYLE_COLORS`，`UiPalette.resolve_styles()` 在给 `RichTextLabel` 之前换成十六进制 —— 两处调用点（事件屏的正文、地图屏的节点浮窗）。名字对不上就原样留着：一眼看得见，也不会崩 |
| `GameSettings.bg_theme` | 设置层只存字符串（默认空 = 用界面的默认），认不认得这个 id 由 `UiPalette.apply` 兜底成默认那档；设置屏的打勾按**生效的那一档**算，不按存的字符串 |
| `compiler.gd` 的 `FaithState` | `FaithState` 搬到 `core/inventory/faith_state.gd`，标签词汇（`faith:` 前缀、标签 ⇄ id）抽成 `core/inventory/faith_tags.gd`（`FaithDef.TAG_PREFIX` / `id_of_tag` 变成转发，调用处一个没改）。**没有**给编译器加 `dormant` 入参 —— 见下 |
| `spec.flags` 字符串 | `CombatantSpec.flags` 整个去掉，换成带类型的 `undying_sec: float`。`draw_is_win` 没有加：103 用加时 + 衰竭替掉了「平局算赢」，这面旗子已经没有主人，加一个空字段只是死代码。另外发现 `FoodDoublePerk` 往 `flags["food_double"]` 写的那一份**没有任何人读**（献祭食物回体力翻倍是 `AltarFoodVitalityPerk` 自己查这条 perk 在不在），顺手删了 |
| `effect_registry.gd` | 拆三张：`EffectRegistry`（`core/battle`：扳机 / 频率 / 消耗 / 战斗效果）、`LootRegistry`（`core/loot`）、`RunRegistry`（`core/run`：一局的规则与模块、事件的条件与后果、局内技能、信力行为与信仰级效果、猎手、侵蚀）。查法三家共用 `core/effects/registry_lookup.gd`；内容管线要的全表由 `core/authoring/content_registries.gd` 合（种类名全局唯一，撞键报错）。导入器 / 导出器 / 校验 / 编辑器只认 `ContentRegistries`，`core/battle` 不再出现 `res://core/run/` |
| 另外（方案没列） | 事件文本的 `{node_type}`、神罚与改造的日志原来问 `MapNodeStyle`（`ui/map`）要点的名字。名字是文字，搬进 `core/text/node_text.gd`（`NodeText.LABELS`）；`MapNodeStyle.STYLES` 只留长相，它的 `label` 从 `NodeText` 取，调用方照旧读 `label` |

**守这条方向的测试**：新套件 `tests/test_layering.gd`（12 项断言）。它按源码查两件事 ——
`core/` 里不许出现 `ui/` 的类名或 `res://ui/` 的路径；`core/battle`、`core/inventory`、`core/sets` 里不许出现 `core/run` 的类名或路径。
注释（`#` / `##`）里的类名不算（那只是指路），词边界也看（`FaithTags` 不会被当成 `FaithTag`）。
这类错误编译不红、测试也不红，所以必须有人按源码查；例外写进套件里的两张白名单并写原因（现在只有一条，就是下面那条尾巴）。
套件自己还有三条**自检**，确认这张网真的在查东西 —— 否则「全绿」可能只是什么都没查。

另外两个新用例：`test_flow_wiring.run_run_changed_signal`（信号发没发、带的是不是这一局、回主菜单带 `null`、
`faith_status` 和这一局对得上）与 `test_content_pipeline.run_registries_split`（三张各自只装自己那层、合起来 = 三张之和、
校验表认得的每一种在注册表里都有）。

**没做的第一条：perk 回到编译期**（方案：`FaithPerk.modify_spec` → 产出 `StatModifier / AbilityRule / flags`，和套装、buff 一起进 `BattleCompiler.compile`）。
八条里只有这一条我没动，原因是方案给的形状**装不下现在的 perk**，而硬塞会动战斗数值：

- 能直接变成「整个单位的 `mods` / `rules`」的只有四条（`low_hp_empower`、`overtime_regen`、`food_shield`、`stat_mod` 的 `target=baseline`）。
- 另外四条要的是**按件**的活：`enchant_weapons` 要在编译完的武器里按种子随机挑 n 把、只挑 `is_active()` 的，给每把单独挂规则并改它的耐力消耗；
  `food_double` 要把食物道具的**每一条属性**的 `base` ×2（除急速）；`stat_mod` 的 `target=items` 要按标签筛；`altar_sacrifice_hp` 要给每件加急速。
  这些都得先有编译结果才知道作用在谁身上，`StatModifier` 也表达不了「所有属性的 base ×2」。
- 要收进编译器，就得给编译器**新开一类入参**：带筛选条件（标签 / uid / 随机挑几件）的「按件修饰」，外加一个「按件缩放」构件。这是给战斗层加一个新的扩展点。
- 更要紧的是**时序**：perk 现在跑在整条编译之后（含第 5 步把属性结算成 `abilities`），搬进编译器就会落在结算**之前**，
  乘区的叠法与结算顺序都会变 —— 这不是重构，是改数值。

所以这一条我按规矩停下来，不偷偷改设计：它值得单独一份方案（新入参长什么样、按件修饰在五步里插在哪、哪些数要对齐、怎么证明搬家前后每件道具的终值一致），
作者点头再做。其余七条互不依赖，先落地了。

**没做的第二条：赐福派生进 `ContentLibrary`**（`item_database.gd:40-41`）。这条依赖 100 第 4 步的 `ContentLibrary`，它还没落地。
`ItemDatabase` 现在仍 `preload` 两个 `core/run/faith/` 的脚本来派生赐福版 —— 这是 `core/inventory` 里**唯一**剩下的反向依赖，
已经写进 `test_layering` 的白名单（带原因与去向），100 第 4 步落地时跟着挪、顺手把白名单清空。

**验证**：全套测试 **82 个套件、12880 项断言通过**。
`grep -rn "UiPalette\|ItemTooltip" core/` 只剩文档注释里的指路（`[ItemTooltip]`），没有代码；
`grep -rn "res://core/run/" core/battle core/inventory core/sets` 只剩 `item_database.gd` 那两行（白名单那条）；
`grep -rn "spec.flags" core/` 只剩一句解释它去哪了的注释。

**余下的刀**：第 2 刀（`start()` 收成 `RunSetup`）等 100 第 4 步的 `ContentLibrary`；第 5 刀的「perk 回编译期」等那份单独的方案。
