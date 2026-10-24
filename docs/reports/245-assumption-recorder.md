# 245 实战里记下系数表的「假设」：系数文件不动，先量真的数

作者 2026-10-24 08:06（架构设计线）：「关于权重配置，先保留当前文件，给游戏内添加可以记录这些数据并导出的功能。」

## 〇 一句话

`power_weights.json` 里三十项有一半是「假设」：一场打几秒、一秒挨几下、暴击率、邻居出手频率、低血时间占比、平均层数、对手 DPS……这些在真实战斗里**都能直接量出来**。做一个「假设实测记录器」：每打完一场真仗，从战斗日志算一遍这些量，追加一行到 `user://calibration/assumptions.jsonl`，随「导出平衡数据」带走；再给一个命令行工具把许多场汇成一张「系数 → 现在的值 → 实测中位数 → 场数」的表。**不改系数文件**，作者看表再定。

## 一 量什么（系数 → 实测定义）

| 系数 | 实测怎么算（每场一个数） | 来源 |
|---|---|---|
| `fight_sec` | 这一场的时长（秒） | `BattleResult.duration` |
| `horizon_sec` | 同上（两项共用一个量，作者定取哪个分位） | 同上 |
| `hit_rate` | 玩家挨的直接攻击次数 ÷ 时长 | `DAMAGE` 事件 `direct`、受害方 = 玩家 |
| `crit_rate` | 玩家打出的暴击 ÷ 直接攻击次数 | `DAMAGE` 事件 `crit` |
| `opponent_dps` | 敌方造成的 `hp_lost` 合计 ÷ 时长 | `DAMAGE` 事件 |
| `neighbor_hz` | 玩家侧每件会出手的件的 `RULE_FIRE` 次数 ÷ 时长，取件的平均 | `RULE_FIRE` 事件 |
| `low_hp_share` | 玩家生命低于三成的时间 ÷ 时长（按 `DAMAGE` 事件重放血线） | `DAMAGE` 事件 + 开场 `initial` |
| `assumed_stacks` | 玩家施加的可叠层 buff（流血 / 中毒……）在场时的平均层数 | buff 层数事件 |
| `status_applied_rate` / `status_removed_rate` | buff 施加 / 移除次数 ÷ 时长，玩家侧 | buff 事件 |
| `stamina_regen` / `stamina_max` | 玩家基线上的值（直接抄，便于对表） | `initial` |
| `assumed_hp` | 敌方开场生命 | `initial` |
| `persist_share` | 不可叠层 buff 平均在场时长 ÷ 时长 | buff 事件 |
| `threshold_share` / `condition_factor` | 这两项是「条件成立比例」，没有统一的量法，**不记**，表里标「无法实测」 | — |

每行还带：`version`、`seed`、`enemy`、`tier`、`steps`、`winner`、`character`、`difficulty`，好按段位 / 敌人筛。

## 二 放在哪、怎么出去

- 新类 `core/run/calibration/assumption_stats.gd`（`AssumptionStats.of(result, head) -> Dictionary`），纯函数、无头可测。
- 挂在 `BattleTraceWriter` 写完一场之后（它手里就有 `BattleResult` 与 `info`），追加到 `user://calibration/assumptions.jsonl`；玩家版照记（和校准记录器一样，不走开发开关）。
- `DataExport` 不用改：`calibration/` 整个目录已经在 zip 里。
- 工具 `tools/assumptions_report.gd -- [jsonl 路径] [输出 md]`：读全部行，按系数列出「现在的值（`PowerWeights.load_from`）/ 实测中位数 / 四分位 / 场数」，另给一张按段位分的小表；输出 markdown 到 `docs/reports/balance/<日期>-assumptions.md`。**不写回** `power_weights.json`。
- 顺手：`bench_matrix` 跑假人时也能喂同一个函数，木桩表旁边多一张「假设实测」——木桩和真人的差距一眼看出。

## 三 不做

- 不加游戏内界面：作者要的是「记录并导出」，导出按钮已有。
- 不改任何系数；表里给中位数，是改是不改作者定。
- `threshold_share` / `condition_factor` 不量。

## 四 测试

一场固定种子的 `BattleSim` 结果 → `AssumptionStats.of` 的时长、受击次数、暴击率、对手 DPS 和日志里数出来的一致；写一行、读回一行；报告工具对三行样本能出表。放 `tests/battle/test_balance_242.gd` 旁边。

## 五 落地（v4.27）

- `core/run/calibration/assumption_stats.gd`（`AssumptionStats`）：`of(result, head, ver)` 一场一行；`append` / `read_rows`；`table` / `bracket_table` / `markdown` 出表（`quantile` 线性插值）。量不出来的项不写键（没挨打没有暴击率、没上过可叠层 buff 没有平均层数……），汇总时跳过。
- 几处量法按日志里实际有的事件定（报告 §一 的说法对上）：
  - `neighbor_hz`：用回放日志的 `item_fired`（`RULE_FIRE` 只在内部日志里），我方 uid 非零的件各自「次数 ÷ 时长」取平均；
  - `low_hp_share`：按我方 `resource_changed`（hp，带变化后的当前值与上限）重放血线，低于三成的时间 ÷ 时长；
  - `assumed_stacks`：对手身上可叠层 buff 的「层数 × 秒 ÷ 在场秒」；`persist_share`：我方身上不可叠层 buff 平均在场时长 ÷ 时长；
  - `status_applied_rate` / `status_removed_rate`：我方身上 `status_stacked`（层数增加）/ `status_unstacked`（层数减少）次数 ÷ 时长；
  - `stamina_regen` 抄我方基线（日志头新带 `stamina_regen`），`stamina_max` 与 `assumed_hp` 读开场快照。
- 挂法：`BattleTraceWriter.write` 加参数 `after`（回调；战斗层不许认识 `core/run` 的类，101 第 5 刀），工作线程写完三份文件后调它；回调由 `AssumptionStats.recorder(路径)` 造，量一行追加。路径由 `GameFlow.apply_battle_trace` 放进 `trace_info`：**只有装了校准记录器的真实对局**（`GameDirector`）才给（`CalibrationRecorder.assumptions_path`），测试里的对局不往玩家目录写。日志头新带 `tier`、`steps`、`character`、`difficulty`、`stamina_regen`。
- 工具 `tools/assumptions_report.gd -- [jsonl] [输出 md]`，默认读 `user://calibration/assumptions.jsonl`、写 `docs/reports/balance/<日期>-assumptions.md`；段位按每行的难度查段位表。
- `BalanceMatrix.cell` 每场也量一行（木桩带段号与流派），`bench_matrix` 的输出末尾多一节「假设实测（木桩）」。
- 测试 `tests/battle/test_assumptions_245.gd`（45 项）。

