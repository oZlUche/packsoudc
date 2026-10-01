# 100 · 方案：内容管线收口（097 的 P5）

> 2026-10-01 ｜ 提议 · 等作者确认后交执行 thread ｜ 对应架构文档 10 节（内容管线）

## 目标

四件事，按性价比排序：
1. 仓库里的 JSON 和 `.tres` **保证一致**（现在没人守）。
2. 五个编辑器存盘**只写一遍**。
3. 新增一种内容**只改一处**。
4. 运行时装载**收到一个内容库**，不再十几处各扫各的目录。

每一步都能独立交付、独立验证；不要求一次做完。

## 现状（已核实）

- 作者 JSON（`data/authoring/<kind>/`，198 份）与导入产出的 `.tres`（`data/<kind>/`，198 份）都进 git（`content_paths.gd:9-60`）。
- 仓库里的 JSON 已经是导出器格式：`tools/normalize_content.gd` 导入 → 导出 → 写回；`test_content_pipeline.gd:338-341` 守「二次导出逐字节相同」。**但没有任何检查守「JSON ⇄ .tres 一致」**：谁改了 JSON 忘了跑导入、或者编辑器只写成了一半（`content_editor.gd:552` 的「JSON 存了但资产写入失败」分支），仓库就带着两份对不上的内容，游戏读的是旧的 `.tres`。
- 导出器 `ContentExporter` 对**全部 21 种**都有 `export_xxx`（`content_exporter.gd:17-93`）—— 这是做一致性检查的现成工具。
- 新增一种内容要改四处：`ContentPaths.KINDS`（`:59`）、`ORDER`（`:86`）、`tools/import_content.gd:59-99` 的 `match kind`、`ContentImporter.Context` 的字典与 `register_*`（`content_importer.gd:17-135`）。
- 导入器文件头承诺「新增效果一行都不用改」（`content_importer.gd:9-12`），实际对事件 / 角色的构件子类写了 17 处 `is` 分支（`import_event :522-615`、`import_character :350-403`）。
- 五个编辑器各写一遍「`ContentExporter.save` JSON → 导入 → `ResourceSaver.save` .tres」：`content_editor.gd:545-552`、`event_editor.gd:592-596, 701-704`、`buff_editor.gd:487-491`、`set_editor.gd:431-435`、`map_editor.gd:508-513`。
- 运行时装载散在：`GameFlow.load_*`（`game_flow.gd:1079-1184`，8 个静态函数 + `_load_dir`）、`FaithDef.load_all`、`HunterSystem.load_all`、`RecipeDef.load_all`、`RunBuffs.load_all`、`EventPlacer.load_all`、`TagRegistry._ensure`、`DamageTypes`、`ItemDatabase.load_dir`、`EnemyDatabase.load_all`、`SetDatabase.load_dir`。`ItemDatabase.DEFAULT_DIR`、`SetDatabase.DEFAULT_DIR` 写死 `res://data/...`（值和 `ContentPaths` 相同，暂无害）。
- `KINDS` 登记了 `buffs`、`sets`，但 `data/authoring/buffs`、`data/buffs`、`data/sets` 都是空目录、`data/authoring/sets` 不存在；`buff_editor.gd:10`、`set_editor.gd:9` 仍指向它们；`SetDatabase.load_dir` 读的 `data/sets` 也是空的。
- `tools/test.sh:7` 默认 Godot 路径是 Windows 的 `/e/Godot/...exe`。

## 方案

### 第 1 步 · 一致性检查（最小、最值）

**原理**：仓库里的 JSON 已经是导出器格式，所以 **`ContentExporter.export_xxx(load(tres)) == JSON.parse(json)`** 就是「两份一致」。不用再跑一次导入。

- 新工具 `tools/check_content.gd`（`CliTool`）：遍历 `ContentPaths.ORDER`，每种目录下
  - JSON 有、`.tres` 没有 → 错（没导入）；
  - `.tres` 有、JSON 没有 → 错（孤儿资产，`ids()` 会把它当内容用）；
  - 两边都有 → 导出字典与 JSON 字典深比较，不等 → 错，打印第一处差异的键路径。
  - `data/maps` 的文本地图不在管线里，跳过。
- `tools/test.sh` 加一步跑它（和 `check_scripts` 并列）；`tests/test_content_pipeline.gd` 加一个套件调同一段逻辑（放进 `core/authoring/content_check.gd` 让工具和测试共用）。
- 顺手：`buffs` / `sets` 两种**要么删出 `KINDS`**（编辑器跟着指向真正的目录），要么作者说清它们将来放什么；空目录现在是一致的，不算错。

### 第 2 步 · 编辑器存盘共用一个函数

- `core/authoring/content_writer.gd`：
  ```gdscript
  ## 作者数据落盘的唯一入口：校验 → 写 JSON → 产 .tres。有错一个都不写；JSON 写了 .tres 没写成返回明确的错，调用方提示跑导入
  static func save(kind: String, id: String, data: Dictionary, ctx: ContentImporter.Context) -> ImportReport
  ```
- 五个编辑器的存盘改成一行调用；`import_content.gd` 的落盘也走它（命令行与编辑器走同一条路，第 1 步的检查才有意义）。

### 第 3 步 · 新增种类一处登记

- `ContentPaths.KINDS` 从 `[作者目录, 资产目录]` 升成一条**种类描述**：
  ```gdscript
  "faiths": {"in": AUTHORING_FAITHS, "out": FAITHS, "importer": "import_faith", "exporter": "export_faith", "ctx": "faiths"},
  ```
  `ORDER` 由 `KINDS` 的声明顺序给（GDScript 字典保持插入顺序），删掉单独的 `ORDER`。
- `import_content.gd` 的 `match` 改成按描述调 `ContentImporter.call(spec.importer, ...)`；`Context` 的二十个字典收成 `_tables: Dictionary`（kind → {id → def}），`register(kind, def)` / `get(kind, id)` 两个方法替代 `register_*`，现有 `register_item` 之类留作薄包装，逐步删。
- `tools/check_content.gd`、`normalize_content.gd`、`export_content.gd` 都按描述表跑，不再各自写 `match`。

### 第 4 步 · `ContentLibrary`

- `core/authoring/content_library.gd`（`RefCounted`，**不是 autoload**，持有方是 `GameDirector` / 测试）：
  ```gdscript
  class_name ContentLibrary
  var items: ItemDatabase; var enemies: EnemyDatabase; var sets: SetDatabase
  var chapters: Array[ChapterDef]; var loadouts; var characters; var difficulties; var achievements
  var events: Dictionary; var hunters; var faiths; var recipes; var run_buffs; var meta_rules: MetaRules
  static func load_all() -> ContentLibrary        # 按 KINDS 顺序各装一遍；标签 / 伤害类型两张静态表也在这儿触发
  ```
- `GameFlow` 的 12 个内容字段换成 `var content: ContentLibrary`，静态 `load_*` 变薄包装后删除；`RunState.start()` 的 15 个参数里 `items / enemies / sets / buff_defs / hunter_defs` 五个换成 `content`（这也是 097 P2 拆 `start()` 的第一刀）。
- 测试里的 `_content()` 帮助函数（`test_author_087.gd:21-32` 等）换成 `ContentLibrary.load_all()`。

### 第 5 步 · 导入器特例回到构件

- 事件后果 / 条件、角色技能这些构件各自实现 `validate(report: ImportReport, ctx) -> void`，`import_event` / `import_character` 只调它，17 处 `is` 分支搬回各自的类。和效果系统「构件自己说明自己」一致，新增一个后果不再改导入器。

### 小修

- `tools/test.sh`：`GODOT` 未设时依次试 `godot`、`godot4`、`$PATH`，最后才用 Windows 默认路径。

## 关键决策

- **一致性检查用导出比对，不重跑导入**：导出器现成、便宜、每种都有；重跑导入会把「导入器变了」和「内容变了」混在一起。
- **先守一致，再改结构**：第 1 步落了，后面每一步都有它兜底。
- **`ContentLibrary` 不做 autoload**：1 节原则不变；它只是把「谁装内容」从 12 个字段收成 1 个对象。

## 验证

- 第 1 步：故意改一份 JSON 不导入 → `check_content` 红；删一份 JSON 留 `.tres` → 红；恢复 → 绿。全量 198 份当前应为绿（若不绿，先修内容再合）。
- 第 2 步：`test_content_editor`、`test_event_editor`、`test_buff_editor`、`test_set_editor`、`test_map_editor` 全绿；编辑器存一次后 `check_content` 绿。
- 第 3 步：`test_content_pipeline` 全绿；新增一种假内容只改 `KINDS` 一条就能导入（测试里做）。
- 第 4 步：`test_game_flow`、`test_run_state`、全部 `test_author_*` 全绿；`grep "static func load_" core/run/game_flow.gd` 为空。

## 改动范围

第 1 步：2 个新文件 + `test.sh` 一行。第 2 步：1 个新文件 + 5 个编辑器各 10 行。第 3 步：`content_paths.gd`、`content_importer.gd` 的 `Context`、3 个工具。第 4 步：1 个新文件 + `game_flow.gd`、`game_director.gd`、`run_state.gd` 签名 + 测试帮助函数。第 5 步：事件 / 角色构件各加 `validate`。

## 待作者定

1. `buffs` / `sets` 两种是删掉，还是留着给将来？（推荐删，现在读到的都是空目录）
2. 第 4 步顺手改 `RunState.start()` 签名（5 个参数换 1 个），还是等 P2 一起？（推荐顺手，正好是 P2 的第一刀）
3. 五步一次交给一个执行 thread，还是第 1 步先单独上？（推荐先上第 1 步）

## 落地（2026-10-01，实现 thread）· 只做了第 1 步

作者定：**先只上第 1 步**；`buffs` / `sets` 删；第 4 步时顺手改 `start()` 签名（那一步还没做）。

| 改动 | 文件 |
|---|---|
| 一致性检查的逻辑（导出比对、**深比较**；缺资产 / 孤儿资产 / 值不同各报一条，带键路径） | `core/authoring/content_check.gd`（新） |
| 命令行：一致退 0、对不上退 1 | `tools/check_content.gd`（新） |
| `tools/test.sh` 每次跑它；`GODOT` 未设时先在 PATH 里找 `godot` / `godot4` | `tools/test.sh` |
| 测试调同一段逻辑，并守「每种内容都在这道检查里」 | `tests/test_content_pipeline.gd`（`run_assets_match_json`） |
| `buffs` / `sets` 从 `KINDS` / `ORDER` 去掉，搬进新的 `EDITOR_ONLY_KINDS`；路径统一走 `dirs_of`（两张表都查） | `core/authoring/content_paths.gd`、`core/authoring/content_check.gd` |
| 10.1 写这道检查与两种内容的去留；v2.09 | `docs/architecture.md` |

**比方案多想了一处**：原方案写「导出字典与 JSON 字典深比较」，但一开始按逐字节比的时候有 8 份报红（事件 / 敌人 / 敌人池 / 节点规则 / 章节）——
差的全是**字典字段的键顺序**（`max_hp` 与 `armor` 谁先、事件配额的顺序），值一模一样。那不是「内容对不上」，所以按方案深比较，
键顺序与 `2` / `2.0` 都不算差异。当前 19 种全绿。

**验证**（照方案）：改一份 JSON 不导入 → 红并指出 `display_name：JSON 是「改过的小刀」，资产是「匕首」`；把一份 `.tres` 挪走 → 红报「没有对应的资产」；恢复 → 绿。

**两种内容的去留，比方案多一笔**：直接把两行从 `KINDS` 删掉会**弄坏两个编辑器** —— 它们的存盘走
`ContentPaths.authoring_file("buffs", id)`，而那个函数查的就是 `KINDS`（全套测试里 buff 制作器与套装编辑器的 14 项断言当场红）。
所以两行搬进了 `ContentPaths.EDITOR_ONLY_KINDS`：不进批量导入、不进这道检查，但路径仍然只在 `ContentPaths` 一处算（10.1 的原则不破）。
**留意**：真用这两个编辑器存了第一份独立内容，批量导入与检查还是不会管它（编辑器自己写 JSON + `.tres`）——
那时把那一行搬回 `KINDS`（`ORDER` 里排在 `items` 之前）就自动纳管。

