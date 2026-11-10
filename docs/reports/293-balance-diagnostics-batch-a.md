# 293 · 平衡检测方案 2026-11-10 批次 A：数据契约、审计与战斗诊断包

> 2026-11-10 ｜ 架构方案执行 ｜ 依据：[平衡检测、统计与胜负感知](../plans/2026-11-10-balance-diagnostics-and-statistics.md) §4～§5（作者 2026-11-10 11:20「这次执行完后读取最新方案再执行」）
> 落地：v5.49（PR #528）。批次 B（逐场统计）、C（胜负感知诊断）另起报告。本批没有改任何战斗或经济规则。

## 一、开工基线

| 项 | 值 |
|---|---|
| HEAD | `fec70117`（main，v5.48 合并后） |
| 引擎 | Godot 4.7.1.stable.official.a13da4feb |
| 工作区 | 干净 |

## 二、产出

### 2.1 公共实验元数据与记录的标识（§4.1）

| 新增 | 做什么 |
|---|---|
| `core/run/calibration/experiment_manifest.gd`（`ExperimentManifest`） | `make()` 生成实验的 `manifest.json` 字段：`schema_version`、`experiment_id`、`source`、`build_id`、`engine_version`、`content_hash`（目录内容摘要，路径和内容一起算）、`suite_hash`（键排序后的摘要）、`seed_manifest`、`config`、`started_at`；`stamp()` 给每一行记录打上 `schema` / `source` / `build` |
| `core/run/calibration/build_info.gd`（`BuildInfo`） | 构建标识：先读 `res://build_id.txt`，再读 `.git/HEAD`（只认提交号，带 `+wip?` 表示看不出工作区改动），都没有就用游戏版本号。玩家包运行时不依赖 Git |
| `tools/stamp_build.sh` | 写 `build_id.txt`：`git:<提交号前 12 位>`，工作区有改动再接 `+dirty:<改动摘要>`。文件不进仓库 |
| `RunState.run_id` | 开局生成、进存档，读档接着打还是同一个；同种子新开一局是新的。老存档读档时补一个，之前的记录照旧没有 |
| 记录行 | 快照、对局结果、每场系数假设都带 `schema: 2`、`source`、`build`、`run_id`；系数假设和诊断包再带 `battle_id` = 局标识 + 这一场的战斗种子 |
| 来源 | `human` / `author` / `auto` / `synthetic` / `test`。测试入口把来源标成 `test`；自动走查用命令行 `-- --calib-source=auto` 或环境变量 `PACKSDC_CALIB_SOURCE` |

### 2.2 数据审计（§4.2）

`core/run/calibration/data_audit.gd`（`DataAudit`）+ `tools/audit_balance_data.gd`：

```
godot --headless --path . --script res://tools/audit_balance_data.gd -- [目录=user://calibration] [输出目录]
    [--build=…] [--chapter=…] [--character=…] [--source=…] [--allow-mixed] [--strict]
```

- **逐行检查**：坏行、未知格式、完全重复（同一份导出了两次）、同标识不同内容、缺必需字段、非有限数、坏种子、读不出的道具（改过名的按别名认）、按记的落点摆不回去的棋盘。
- **记录链**：有快照没结果的局、有结果没快照的局、同一局步数倒退。
- **分组**：按构建分组、按来源计数。混了构建默认算严重，加 `--allow-mixed` 降为警告；老格式的行照读，复现程度标 `unknown`。
- **对账**：每个文件都满足「总行 = 坏行 + 重复 + 排除 + 筛掉 + 有效」，报告里有一列「对得上」。
- **输出**：`audit.json`、`audit.md`。
- **退出码**：0 通过（警告写在报告里）；1 用法或读写错误；2 加了 `--strict` 且有严重问题。工具自己崩了也是 2，但这时不会写出 `audit.json`。

**跑本机的校准目录**（测试和自动走查写的，不是真人）：快照 3476 行里有 3429 行完全重复，是全量测试每次写一样的行；14 行引用了已经不在的道具；全部是老格式、来源 unknown。这正是加来源标签要解决的问题：从这版起，测试写的行都标成 `test`。

### 2.3 战斗诊断包与复现（§5）

| 新增 | 做什么 |
|---|---|
| `core/battle/battle_input_codec.gd`（`BattleInputCodec`） | `CombatantSpec` 和普通值来回换。只编结算内核读的：生命、属性（基础 / 加算 / 乘算）、规则（按实例去重，内置子资源深拷贝，外部的 buff 等按路径引用）、标签、连结、装载、威力系数、轴层数、免疫、只吃哪种伤害、坚持秒数、套装规则 |
| `core/battle/battle_diag_pack.gd`（`BattleDiagPack`） | 一场的诊断包（`.diag.tres`）：双方输入、开打前随机数的种子和**状态**、时限、加时规则、元数据，以及当时结果的摘要（胜方、时长、最终资源、逐条规范化事件和它们的摘要）。`rerun()` 只调 `BattleSim`；`compare()` 报第一处不同 |
| `core/battle/battle_diagnostics.gd`（`BattleDiagnostics`） | 开关默认关：命令行 `-- --diag-capture` 或 `PACKSDC_DIAG=1` 才抓。落在 `user://diagnostics/battles`，只留最近 200 份；`pin()` 复制到 `user://diagnostics/pinned`，不清理。写盘失败只记警告、计数，不影响对局 |
| 正式入口 | `NodeEvents._fight` 在 `hooks.before_battle` 之后、`BattleSim.run` 之前抓（信仰、局外加成都已经并进去） |
| `tools/reproduce_battle.gd` | 按包重跑并比对。退出码：0 一致；1 不一致（打印第一处不同）；3 包坏了、缺资源或不是诊断包（回放存档 `.replay.json` 也在这里拒绝：它不带双方编译结果）；4 构建对不上（加 `--allow-build-mismatch` 照跑，结论只作参考） |
| 导出平衡数据 | zip 里多一个 `diagnostics/` 目录 |

**开销**（60 场，当前木桩对 `standard_ruins` 各档，时限 600 秒）：

| 项 | 平均 |
|---|---:|
| 模拟一场 | 2.82 ms |
| 抓包 | 0.72 ms |
| 写盘 | 1.52 ms |
| 一份包 | 27 KB |

只在开发或诊断模式下抓；按 200 份上限算，目录最多约 5.5 MB。60 场全部读回重跑一致。

## 三、验证

| 项 | 命令 | 结果 |
|---|---|---|
| 新套件 · 审计 | `run_tests.gd -- data_audit` | 68 项通过。夹具（`tests/fixtures/audit/`）覆盖坏 JSON、重复导出、同种子不同局、老格式、未知格式、缺字段、非有限数、坏种子、不认得的道具、摆不回去的棋盘、同标识不同内容、两个构建混合；干净夹具严格模式通过；空目录严格拒绝 |
| 新套件 · 诊断包 | `run_tests.gd -- diag_pack` | 50 项通过：普通武器、状态伤害、信仰（蛮神护符 3 阶）、局外加成（伤害 +20%、攻速轴）、品质与耐久（品质 2 的法杖 + 火晶石）、特殊角色（坚持 3 秒、免疫中毒）六场存盘读回重跑逐条一致；抓的是深拷贝；不存在的包、规则表空位、格式不认得都报出来；滚动清理只删最旧的、不动固定导出；正式一局开着诊断打一场落一份包，胜负一致、战斗标识 = 局标识 + 种子、重跑不改这一局 |
| 复现工具 | `reproduce_battle.gd` 对样例包、改了构建号的包、截断的包 | 退出码 0 / 4 / 3 |
| 全量测试 | `bash tools/test.sh` | 39,433 项断言 / 296 个套件通过，406 s，EXIT=0；0 条 `SCRIPT ERROR`，0 条未登记的 `ERROR:` |
| 静态警告 | `bash tools/warnings.sh` | 0 条 |

## 四、交接

| 类 | 内容 |
|---|---|
| 已实现工具 | 实验元数据、构建标识、局 / 战斗标识、来源标签；数据审计；战斗诊断包、复现工具 |
| 已执行实验 | 审计跑了本机校准目录；诊断包开销和 60 场回读重跑 |
| 推测 | 无 |
| 真人验证 | 无（本机没有真人数据） |
| 没做 | 玩家包里的构建号：要让导出包带上 `build_id.txt`，导出设置的「非资源文件」要加 `build_id.txt`，并在导出前跑 `tools/stamp_build.sh`。`export_presets.cfg` 在作者本地、没进仓库，这一步得作者做；不做的话玩家包退回游戏版本号 |
| 下一步 | 批次 B：逐场记录与失败账、分位数与区间、扫表按真实的点抽敌人（报告 292 #1）、参考配装合法性检测 |
