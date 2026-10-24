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
