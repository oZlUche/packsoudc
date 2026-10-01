# 097 · 架构体检：现状概况与主要问题

> 2026-10-01 ｜ 分析报告 · 无代码改动 ｜ 基线：`main` @ cf410d3（096 之后）｜ 测试：`tools/test.sh` 全绿（12116 项断言、71 个套件）

这是「架构设计」线的第一份报告：通读仓库、`docs/architecture.md`（v2.06，3637 行）和 96 份报告之后，把现状和问题列出来，供作者挑哪些先改。**本报告只提问题和建议，不做设计变更**；每一条要动手的，都另开报告、作者确认后再实施。

## 一、现状概况

### 1.1 规模

| 区域 | 文件数 | 说明 |
|---|---|---|
| `core/` | ~290 | 纯逻辑（`RefCounted` / `Resource`），**没有一个 `extends Node`**，1.1 节的自检指标仍然成立 |
| `ui/` | ~60 | 导演 + 十几个屏 + 五个编辑器 |
| `data/authoring/` + `data/` | 200 + 200 | 作者 JSON 与导入产出的 `.tres`，两份都进仓库 |
| `tests/` | 71 套件 | `tests/run_tests.gd` 用 `SUITES` 列表登记 |
| `docs/reports/` | 96 份 | 设计 → 确认 → 实施 → 报告的流程一直在执行 |

autoload 只有 `DevNav` 一个；`GameDirector` 是主场景根，不是 autoload。

### 1.2 分层（实际）

```
GameDirector (ui/game)            换屏、叠层 / 最小化、演示代码
  └ GameFlow (core/run, 1184 行)   场景流状态机 + 存档位 + 成就 + 出售 + 保险箱 / 神坛 + 内容装载
      └ RunState (core/run, 1359 行)  一局的全部状态：地图、棋盘 / 暂存区 / 保险箱、信仰、合成、倒计时、buff、猎手、技能、存档
          └ NodeEvents (793 行)     节点事件接线，靠 ~20 个注入的 Callable 回调 RunState
      └ MetaState                   跨局状态（仓库、图鉴、成就、解锁）
战斗：BattleCompiler(纯函数) → CombatantSpec → BattleSim(事件驱动, ScheduleHeap) → 事件日志 → BattleView 回放
内容：data/authoring/*.json → ContentImporter(1252 行, 反射 + 注册表) → data/*.tres → 各模块自扫目录装载
```

### 1.3 做得好的地方（值得守住）

- 逻辑与表现分离、命令进信号出、随机数分流（`RunRNG`）这三条总原则在代码里都兑现了；战斗模拟内没发现全局 `randf`，影响结果的字典遍历都先排了序（`compiler.gd:63,130`）。
- 效果系统四层（时机 / 频率 / 消耗 / 效果）+ 作用域分支（Combat / Loot / Run）+ 注册表，大部分新功能（侵蚀、猎手、buff、事件后果）确实是以「构件」加进来的。
- 读档之后接着走和没存过一样（051）这一条有测试守着。
- 文档量大且每一步都有报告，是这个仓库最大的资产。

## 二、主要问题（按严重度）

### P1 · 「在棋盘内拖一下信物就切信仰」是作者要的玩法，但眼下靠的是旁路

- `DragLayer` 拿起时直接调 `grid.remove(uid)`（`ui/inventory/drag_layer.gd:126`），`remove` 把 `container_id` 清成 0（`core/inventory/grid_inventory.gd:383`）。
- 放下 / 取消时再 `grid.place(...)`（`drag_layer.gd:448`、`:656`），`place` 判 `arrived := inst.container_id != id` 为真 → `place_seq += 1`、发 `placed`（`grid_inventory.gd:351-360`）。
- 而 `InventoryService.move` 是特意处理过的：同容器先把 `container_id` 设回本容器（`core/inventory/inventory_service.gd:34`）。**UI 绕过了服务层，所以文档 3.8「同容器内挪位置不算置入」在真实拖拽路径上不成立。**
- 作者（2026-10-01）确认：**棋盘内拖动信物切换信仰是想要的功能**，不是 bug。问题只剩「靠意外实现」：取消拖拽、Esc、放不回原位也会切；凡是挂在 `placed` 信号上的信力累计可能被刷（推断）；拖拽路径没有走 3.5 要求的原子移动 / 回滚（`drag_layer.gd:645,649` 的「已丢失」分支）。

**方案（待作者挑）**：
- A（推荐）：`GridInventory.reseat(uid)` 只盖 `placed_seq`；棋盘内真正落下信物时调它，取消 / 失败不调；`DragLayer` 改走 `InventoryService`，顺便补原子移动。
- B：信物上右键 / 双击「奉为主信仰」，调同一个 `reseat`；与 A 并存。
- C：棋盘上方信仰栏，点谁切谁；等信仰多了再做。

### P2 · 两个 god class：`RunState`（1359 行）与 `GameFlow`（1184 行）

- `RunState`：约 20 个 signal、约 70 个 var（`run_state.gd:49-147`），`start()` 15 个参数（`:158-163`），`from_dict` 逐字段手写（`:1283-1358`）。每批作者需求都往这里加字段，`to_dict/from_dict` 和 `_wire_events` 跟着膨胀。
- `GameFlow`：流程之外还管存档位（`:90-169`）、成就（`:332-367`）、出售（`:534-552`）、保险箱 / 神坛（`:638-689`）、内容装载（`:1079-1184`）；`_adopt` 80 行接 20 个信号（`:924-1002`）。
- `NodeEvents` 用 ~20 个 Callable 字段充当隐式接口（`node_events.gd:40-114`），接线散在 `RunState._wire_events`（`:1118`），既没类型也没法单独测。

**建议**：不做大重构，按「子系统各管自己的状态与序列化」逐个抽：先把 `Safe / Altar / Countdown / Crafting` 从 `RunState` 抽成各自带 `to_dict/from_dict` 的子状态；`GameFlow` 里的成就 / 出售 / 存档位分别成服务；`NodeEvents` 的回调收成一个明确的接口类。每一步都能靠现有测试守住。

### P3 · 存档没有迁移机制

- Run 版本 1、Meta 版本 2，都是**严格相等**，不等直接返回 null（`run_state.gd:1286`、`meta_state.gd:422`、`run_save.gd:44-46`，警告文案写着「迁移还没写」）。
- 现在靠 `d.get(key, default)` 隐式兼容新字段；一旦改了某个字段的语义或 id（比如 096 的标签改名、093 的 `faith:violence → faith:brute`），老档整份作废，而成就 / 图鉴这类跨局数据是玩家最在意的。

**建议**：Meta 先上「按版本号逐级 `migrate_vN_to_vN+1`」的链；Run 档可以继续「版本不等就作废」，但至少在读档屏上告诉玩家。

### P4 · 依赖方向有几处反了

- core → ui：`game_flow.gd:83,930` 直接写 `ItemTooltip.faith_probe`（`ui/inventory/item_tooltip.gd:15` 的静态变量）；`core/text/text_template.gd:14` 和 `core/settings/game_settings.gd:34,66` 引用 `UiPalette`。
- core/battle → core/run：`compiler.gd:51` 依赖 `FaithState`；`item_database.gd:40-41` 预加载 `core/run/faith/`；`effect_registry.gd:99-140` 登记着地图事件、信仰 perk 这些局内层的表。
- 信仰的几条规则绕过了通用框架：`spec.flags` 按字符串取值（`battle_sim.gd:30` 的 `draw_is_win`、`combatant_runtime.gd:57` 的 `undying_sec`）；「不死」写死在结算内核（`combatant_runtime.gd:286,297-335`、`damage_resolver.gd:70`）；编译完之后 `FaithPerk.modify_spec` 再改一次 spec（`run_state.gd:634`），编译器不再是战斗单位的唯一来源。

**建议**：`faith_probe` / 调色板这类改成 UI 侧订阅；战斗层对信仰只认「编译输入」（tiers / points / 休眠集合），perk 改成在编译期以 mod 形式进入；`flags` 改成带类型的字段或构件。

### P5 · 内容管线：双份数据无防漂移检查，导入器按种类堆特例

- JSON 与 `.tres` 都进仓库（`content_paths.gd:9-60`），但没有「导入结果 ≡ 仓库里的 .tres」的检查；往返测试（`test_content_pipeline.gd:249`）只管导出 → 导入。
- 导入器文件头说「新增效果一行都不用改」（`content_importer.gd:9-12`），实际 `import_event`（`:522-615`）、`import_character`（`:350-403`）对子类逐个 `is` 分支。新增一个内容种类要改 `KINDS`、`ORDER`、`import_content.gd` 的 match、`Context.register_*` 四处。
- 运行时装载分散在 10 多处各自扫目录（`game_flow.gd:1081-1146`、`hunter_system.gd:452`、`faith_def.gd:119`、`recipe_def.gd:31`、`run_buffs.gd:58`、`event_placer.gd:93`、`tag_registry.gd:16`、`damage_types.gd:42`），`item_database.gd:8`、`enemy_database.gd:6-7` 直接写死路径。
- 五个编辑器各写一遍「写 JSON → 导入 → 存 .tres」。
- `ContentPaths` 登记了 `buffs`、`sets` 目录（`:17-18,42-43`）但目录不存在，`buff_editor.gd:10`、`set_editor.gd:9` 仍指着它们。

**建议**：加一条 CI 式测试「全量导入后与仓库 .tres 逐字节一致」；装载收口到一个 `ContentLibrary`；编辑器存盘共用一个函数。

### P6 · 测试按报告编号命名

`test_author_087 … 096` 共 3359 行；087 一个文件混了稀有度、商店、Boss、望远镜等 17 个用例。按模块找不到对应测试，改一个模块要跑全部 148 秒。**建议**：新用例按模块放，老的分批搬，`run_tests.gd` 支持按套件名过滤。

### P7 · 类缓存脆弱

`.godot/global_script_class_cache.cfg`（3057 行生成物）进了仓库（30b1085），`DevNav` 启动自检、`test.sh` 先 `--import`、4be6145 改 preload 绕开——都是在治标。生成物进仓库会带来合并冲突（推断）。`test.sh:7` 默认 Godot 路径还是 Windows 的 `/e/Godot/...exe`。

### P8 · 文档与代码漂移（架构文档正文）

- §1.3 讲 `EventBus`，§2 和代码都说没有 EventBus。
- §7 `RunState` 字段表缺 safe / altar / faith / hunters 等；§8 `Screen` 枚举少 SLOTS / SAFE / ALTAR（`game_flow.gd:13`）；有两个 §8.4；§8.1 和 §7.3 对占位角色说法相反。
- §3.8 正文说「带 faith 的道具里序号最大那件激活」，代码只认 `faith_anchor` 信物（`faith_state.gd:18`）；§4.2 少了 `faith_points` 参数（`compiler.gd:36`）。这两条只在变更记录提过，正文没改。
- 存档位（089）在架构文档里没有章节。

**建议**：架构文档改成「正文永远是现状」，变更记录只留一句指向报告；这条我可以直接做，不涉及设计。

### 小问题

- `ItemInstance._next_uid` 全局静态、`RunState.start` 重置为 1（`item_instance.gd:10`、`run_state.gd:179`），局内 / 局外共用，是否会和仓库 uid 撞号未验证。
- `low_hp_empower.gd:16-17` 战斗中途用 `clampf/roundi`，违反 4.3「全程定点」。
- `GameDirector` 读了两次 meta（`game_director.gd:54`、`game_flow.gd:98`）；`:188-390` 是演示逻辑混在导演里；`game_director.gd:324` 直接写 `run.phase`。
- `setup_screen.gd:171-181,537-555`、`shop_screen.gd:183-190` 在 UI 里拆拼棋盘 / 自己写回滚。

## 三、建议的处理顺序

1. **P1** 作者已定要保留切换手感；写 A + B 的方案报告，确认后实施。
2. **P8** 文档对齐（无风险，我直接做）。
3. **P3** Meta 存档迁移链（在下一次改字段语义之前做）。
4. **P5** 导入一致性测试 + `ContentLibrary` 收口。
5. **P2 / P4** 分多步小拆，每批作者需求顺手抽一块，不单独立项大重构。
6. **P6 / P7** 随手治理。

哪几条要动手，作者点名后我按「先写方案报告 → 确认 → 实施」走。
