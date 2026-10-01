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

### 第 1 刀 · `RunState` 按子系统抽状态（P2）

每个子系统一个 `RefCounted`：持自己的字段与信号、`to_dict / restore`、一个 `wire(run)` 把需要的回调接上。`RunState` 只剩 `var xxx: Xxx` 一行 + 存档里一个键。按改动小到大：

| 顺序 | 抽出去 | 从 RunState 带走 | 行数估 |
|---|---|---|---|
| 1 | `RunSafe`（保险箱，092） | `safe / safe_locked / safe_closed / lock_safe / safe_open` | ~40 |
| 2 | `RunCountdown`（倒计时 + 带入预算，092 / 094） | `countdown_* / carry_* / closing_extract_id / extract_closed / _check_countdown`、6 个 `static *_for` | ~120 |
| 3 | `RunCrafting`（合成，084） | `recipes / craft_* / resolve_crafts / craft_done` | ~90 |
| 4 | `RunAltar`（神坛与信仰级效果，093 / 095） | `altar_* / faith_rituals / faith_stat_bonus / offer / bless_ids / _bless_step / faith_perks / item_blessed` | ~130 |
| 5 | `RunBuffState`（buff，062） | `buff_defs / meta_buffs / map_buffs / *_map_buff / tick_map_buffs / buff_context / install_mechanics` | ~90 |
| 6 | `NodeStorages`（按点暂存，088） | `node_storages / stored_at / _restore_storage / _drop_storage* / storage_dropped / storage_restored` | ~60 |

每一刀的验收：`RunState` 行数下降、对应 `test_author_09x` / `test_run_state` 全绿、读档往返测试（051）全绿。六刀之后 `RunState` 约 700 行，只剩「骨架 + 容器 + 接线 + 存档」。

**存档格式不变**：子系统的 `to_dict` 产出和现在同样的键（`safe`、`safe_locked`……），`RunState.to_dict` 用 `merge` 拼起来；`from_dict` 把整个 `d` 交给各子系统 `restore(d)` 自己取。版本号不升（098 的规矩）。

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

- **抽状态而不是抽行为**：每个子系统带走自己的字段、信号和存档，`RunState` 才真的变薄；只抽函数留字段等于没拆。
- **存档格式一个键不改**：拆分不是升版本的理由；098 的「改语义才升版」在这里要守住。
- **`RunHooks` 用类不用 Callable**：22 个 Callable 的问题不是多，是没类型；一个接口类让 `NodeEvents` 可以在测试里用假实现跑。
- **信仰回到编译期**：perk 改 spec 的后门关掉，战斗层只认 `CombatantSpec`；「不死」「平局算赢」是结算规则，可以留在内核，但按类型字段读。
- **顺序**：1 → 2 → 3 → 4 → 5 → 6。1、4、6 彼此独立，可并行给不同执行 thread；2 依赖 100 第 4 步；5 里编译器那两条依赖 1-4 完成（`RunAltar` 抽出来后 perk 才有自己的家）。

## 验证

- 每一刀：`tools/test.sh` 全绿；`wc -l core/run/run_state.gd core/run/game_flow.gd` 下降并写进该刀的报告；读档往返（`test_run_state`、`test_game_flow`）不变。
- 第 5 刀结束：`grep -rn "UiPalette\|ItemTooltip" core/` 为空；`grep -rn "core/run" core/battle core/inventory` 为空；`grep -n "spec.flags" core/battle` 为空。
- 第 3 刀：`NodeEvents` 用 `RunHooks.new()` 默认实现跑 `test_node_events` 全绿。

## 改动范围

全部在 `core/run`、`core/battle`、`core/text`、`ui/game` 的既有文件 + 约 10 个新的小文件。不改内容格式、不改存档格式。

## 待作者定

1. 六刀的顺序按上面来，还是你有更急的子系统想先抽？
2. 第 5 刀「perk 回到编译期」会改 14 种 `FaithPerk` 的接口（`modify_spec` → `compile_mods`），要不要和 P1（099）一起交给同一个执行 thread（都碰信仰）？推荐分开，099 先。
3. 演示代码搬去 `tools/`，截图工具 `capture_scene.gd` 跟着改，可以吗？
