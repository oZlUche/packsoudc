# 098 · 方案：存档版本迁移链（097 的 P3）

> 2026-10-01 ｜ 提议 · 等作者确认后实施 ｜ 对应架构文档 7.2

## 目标

让「改了存档字段」不再等于「玩家的局外进度作废」。局外档（仓库、图鉴、成就、解锁、战绩）是玩家最在意的；一局档可以宽松些。

## 现状（已核实）

| 文件 | 版本 | 不匹配时 |
|---|---|---|
| `MetaState.SAVE_VERSION = 2`（`core/meta/meta_state.gd:16`） | 严格相等（`:422`） | `from_dict` 返回 null |
| `RunState.SAVE_VERSION = 1`（`core/run/run_state.gd:1286`） | 严格相等 | 返回 null |
| `GameSettings`（`core/settings/game_settings.gd:54`） | 严格相等 | 返回 null |

两个真实风险：

1. **静默覆盖**：`GameFlow.use_slot`（`game_flow.gd:98-99`）读不到 meta 就 `MetaState.new()` 从零开始，之后任何一次 `finish_result` 存 meta 都会把旧文件**盖掉**。版本号一升、玩家打完一局，老进度就没了，中间没有任何提示。
2. **内容 id 改名没有兜底**：存档只写 id（3.1），`GridInventory.from_dict` 遇到找不到定义的道具是告警后丢弃；标签 / 信仰 / 道具改名（093 的 `faith:violence → faith:brute`、096 标签改名）会让仓库里的东西悄悄消失、图鉴计数对不上。

现在靠 `d.get(key, default)` 隐式兼容「加字段」，这一招对「改字段语义、改 id」无效。

## 方案

### 1. 迁移链：按版本逐级升

```gdscript
# core/meta/meta_migrations.gd（新，纯静态）
class_name MetaMigrations
## 每一步只认 n → n+1，输入输出都是 Dictionary，不碰对象；缺哪一级就报错不猜
const STEPS := { 1: "_v1_to_v2", 2: "_v2_to_v3" }
static func upgrade(d: Dictionary) -> Dictionary:
    var v := int(d.get("version", -1))
    while v < MetaState.SAVE_VERSION and STEPS.has(v):
        d = call(STEPS[v], d); v += 1; d["version"] = v
    return d       # 版本仍不等 → 调用方按「不认识」处理
```

- `MetaSave.from_text` 先 `upgrade` 再 `from_dict`；`from_dict` 继续严格相等，**迁移只在读文件这一层做**，内存里的对象永远只认当前版本。
- `RunSave` 同样一份 `RunMigrations`；一局档允许「不认识就作废」，但走同一条链，不写特例。
- 升版规矩：**改语义或 id 才升版，只加带默认值的字段不升版**（沿用现在的 `d.get`）。每升一版，`STEPS` 加一个函数，报告里写明。

### 2. 读不到不覆盖：先备份，再决定

- `MetaSave.from_text` 返回 null 时，`GameFlow.use_slot` **不再静默新建**：把原文件改名成 `meta.json.v<n>.bak`（`SaveSlots` 加 `backup(n, reason)`），再从零开始；主菜单 / 读取存档屏那一行写「这个存档位的局外进度来自旧版本，已备份」。
- 回滚靠备份文件：作者或玩家手动改回去即可，不做自动回滚。

### 3. 内容 id 改名表

- 新内容种类不值得；一份静态表就够：`core/authoring/id_aliases.gd`（`ITEMS / TAGS / FAITHS: { old: new }`），从 093、096 的两次改名开始填。
- `ItemDatabase.get_def(id)` 找不到时查一次别名；`TagRegistry` 同理。读档、仓库、图鉴、成就条件都自然受益，**不用改存档格式**。
- 导入器校验：别名表里的 new 必须存在，old 不得再被内容引用。

### 4. 测试

- `tests/test_save_migration.gd`：每个版本留一份**冻结的 JSON 样本**（`tests/fixtures/meta_v1.json`、`meta_v2.json`…，手工抄最小可读档），断言升到当前版本后 `from_dict` 不为 null、关键字段值正确。
- 升版时必须加新样本，否则链上有洞测试立刻红。
- 别名表：找不到的 id 经别名能读回；仓库里一件改过名的道具读档后还在。

## 关键决策

- **迁移在字典层，不在对象层**：对象只认当前版本，`from_dict` 不变，不会在 1359 行的 `RunState` 里再堆分支。
- **备份而不是自动修**：拿不准的不猜，但也不丢；玩家看得到一句话。
- **别名表放内容层**：改名是内容的事，不是存档的事，所以不进版本链。

## 改动范围（预估）

新增 3 个小文件（`meta_migrations.gd`、`run_migrations.gd`、`id_aliases.gd`）+ 测试与样本；改 `meta_save.gd`、`run_save.gd`、`save_slots.gd`（备份）、`game_flow.gd:98`（不静默新建）、`item_database.gd` / `tag_registry.gd`（查别名）、读取存档屏一行提示。不改存档格式，不升版本号。

## 遗留

- `GameSettings` 的版本不进链（设置丢了重设一次，代价小）。
- 自动回滚不做。

## 待作者定

1. 读不到 meta 时是「备份后从零开始」（推荐），还是「拒绝进入这个存档位、提示去换版本」？
2. 一局档是否也要迁移（推荐：走链但允许作废）。
3. 别名表要不要同时覆盖敌人 / 事件 id（推荐先只做道具、标签、信仰）。

## 给执行者的备注（架构线核实过的细节，2026-10-01）

- **Meta v1 → v2 是恒等**：v2 只是 `MetaState.keeps` 放行了带信仰的 1 格包（fc0bfc2），字典形状没变，第一步迁移函数原样返回即可；Run 链现在是空的。
- 迁移用 `match v:` 显式分派，别用 `Callable(Script, name)` 反射；`upgrade` 要 `duplicate(true)` 不改入参。
- 读文件层接入点：`MetaSave.from_text`（`core/meta/meta_save.gd:36-39`）、`RunSave.from_text`（`core/run/run_save.gd:44-46`）。
- 备份接入点：`GameFlow.use_slot`（`game_flow.gd:98-99`）读不到且文件存在 → `SaveSlots.backup(n, "meta")`（`DirAccess.rename_absolute` 到 `meta.json.<unix>.bak`）；`continue_run`（`:219`）对 `run.json` 同理，否则「继续」会一直撞墙。`SaveSlots.exists / remove` 不看 `.bak`。
- 提示文案：`UiText` 加 `slots.backed_up`，读取存档屏 `_hint` 与主菜单战绩行下各显示一次，`GameFlow` 加 `meta_backup / run_backup: String`。
- 别名接入点：`ItemDatabase.get_def`（找不到才查）、`TagRegistry.get_def`、`FaithPower.restore`（`faith_power.gd:104`，旧键并进新键）。093 的真实改名：`violence → brute`、`sunfire → sun`（`b4c23a2`），标签同前缀。`faith:brute` 不是登记过的 TagDef，别拿它测 TagRegistry 的别名。
- 测试样本：`tests/fixtures/meta_v1.json` 用 `knife`（存在）做仓库里的一件；`MetaState.to_dict` 的键见 `meta_state.gd:390-411`；新套件要登记进 `tests/run_tests.gd` 的 `SUITES`。新 `class_name` 记得跑 `tools/test.sh` 刷类缓存并把 `.godot/global_script_class_cache.cfg` 一起提交。
- 「新 id 必须存在、旧 id 不得再被内容引用」用测试守（扫 `ContentPaths.AUTHORING` 下的 JSON 找 `"violence"` 等字面量），不改导入器。
