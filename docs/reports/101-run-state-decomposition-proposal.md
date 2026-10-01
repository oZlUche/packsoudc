# 101 · 方案：RunState / GameFlow 拆分与依赖方向（097 的 P2 + P4）

> 2026-10-01 ｜ 提议 · 等作者确认后交执行 thread ｜ 对应架构文档 1、2、7、8 节

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

**下一刀**：第 1 刀的倒计时 / 合成 / 神坛 / buff / 按点暂存五个模块（照抄这个样板）；第 2 刀等 100 第 4 步（`ContentLibrary`）。

