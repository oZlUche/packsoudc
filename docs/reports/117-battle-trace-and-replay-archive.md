# 117 · 方案：战斗内部日志（逐条、带时间）与战斗回放存档

> 架构设计线程，2026-10-03。作者原话：「我希望添加一个战斗 log 以及回放功能。log 用于检查和内部阅读，不需要展示给玩家，因此要尽可能详细并带有时间 tag」。
> 本文只做方案，不实施。

## 一、现状（已核实）

- 战斗是**确定性**模拟（`BattleSim`，4.7）：开战瞬间一次算完，产出 `BattleResult { winner, duration, log: Array[BattleEvent], initial, final, buffs, passives }`。`BattleEvent` 自带定点时刻 `time`、归属方 `side`、`payload`。
- **回放已经有**：`BattleView` 照 `result.log` 重演（倍速、跳过、拖动），右边有一栏给玩家看的文字日志（`_log_event`）。但它只在打完那一刻能看，**结果不落盘**，关掉就没了。
- 日志里**只有 `VIEW_EVENTS`**（`BattleContext.emit`：既不是回放要的、也没人听的事件连对象都不建）。`before_damage` 同步派发、不进日志；规则**为什么**出手 / 没出手、消耗付了多少、伤害管线里每一级乘区、暴击掷了多少、随机数取了什么，都没有记录。查数值问题时只能靠沙盒重现。
- `BattleSim.run(me, enemy, rng, limit, overtime)` 由 `NodeEvents._fight` / 猎手 / 沙盒 / 基准调；随机源 `_rng_for(node, "battle")` = `hash(content_seed:battle)`，**同一个点同一局必然同一场**。

作者要的两件事因此拆成：**A 内部日志**（新东西：逐条、全量、带时间，写文件）与 **B 回放存档**（把已有的回放从「只在当场」变成「随时翻」）。

## 二、A · 内部日志 `BattleTrace`

### 2.1 记什么

一个可选的记录器 `core/battle/battle_trace.gd`，挂在 `BattleContext.trace`（默认 null，**关着时一行判断、零开销**）。开着时记这些，每条 `{seq, t（定点秒）, side, kind, data}`：

| kind | 什么时候 | data |
|---|---|---|
| `event` | `BattleContext.emit` 里**每一条**，不看 `VIEW_EVENTS` 也不看有没有人听；`dispatch_before_damage` 的同步派发也记 | 事件名、payload 原样 |
| `rule_fire` / `rule_skip` | `RuleEngine` 每次判一条规则：出手了（规则 id、道具 uid、触发名、下次就绪时刻）/ 没出手（原因：消耗不够、条件不成立、目标没了） | 规则与道具、原因、消耗的资源与余量 |
| `damage_pipeline` | `DamageResolver` 结算一包伤害：原始值 → 各乘区（增伤 / 物理 / 元素 / 急速不算）→ 暴击（掷出 / 阈值）→ 防护 → 护盾吸收 → 实际扣血 | 每一级的数 |
| `rng` | `ctx.rng` 每次取数：把 `RandomNumberGenerator` 包一层 `TracedRng`（同接口），记用途与值 | 用途（暴击 / 概率效果）、值 |
| `buff` | 叠层、到期、清除，带剩余时长与层数 | id、层、到期时刻 |
| `schedule` | 时间轮弹出一个时刻（4.7 的「跳到下一个时刻」） | 时刻、这一刻有几条规则 |
| `snapshot` | 开战、结束、以及每 5 秒（定点）一次 `ctx.snapshot()` | 双方资源与 buff |

时间 tag：每条的 `t` 是模拟内的定点秒（打印成 `12.340s`），文件头写一次**现实时间**（`Time.get_datetime_string_from_system()`），因为整场是一瞬算完的，逐条记现实时间没有意义。

### 2.2 怎么写

`core/battle/battle_trace_writer.gd`：

- 目录 `user://battle_logs/`，文件名 `<yyyymmdd-hhmmss>_<run_seed>_n<node>_<chapter>_<对手id>.{jsonl,txt}`，两份：`.jsonl` 一行一条给程序读；`.txt` 人读，一行一条，例：
  `[ 3.200s] S0 fire   knife#3 → deal_damage 5 → crit(0.07<0.10) ×1.5 → armor −2 → S1 hp 40→34`
  `[ 3.200s] S1 skip   cleaver#7 耐力不足（3/8）`
- 文件头（两种格式都有）：现实时间、`run_seed`、章节、点 id、敌人内容、双方的**道具名表**（uid → 名字）与棋盘布局（`GridInventory.to_dict`）、`initial` 快照、随机种子、时限与加时规则。
- 只留最近 **50** 场（按文件名排，多的删），避免越玩越大。

### 2.3 开关

`GameSettings.battle_trace: bool`，**默认开**（在编辑器 / 非导出包里；导出包默认关，`OS.has_feature("template")`）。设置屏「开发」区一行开关 + 「打开日志文件夹」按钮（`OS.shell_open(ProjectSettings.globalize_path("user://battle_logs"))`）。玩家看不到日志内容，这是作者说的「内部阅读」。

`BattleSim.run(...)` 加一个可选参数 `trace: BattleTrace = null`；`NodeEvents._fight`、猎手、沙盒都传。基准 `bench_battle` 不传（量的是干净的单场成本）。

## 三、B · 回放存档 `BattleRecord`

### 3.1 存什么

`BattleView` 重演只需要 `result.log + initial + buffs + 名字表 + 棋盘`，不需要双方的编译结果。所以存档就是这些的 JSON（`BattleEvent` 本来就是 name / time / side / payload 字典，直接序列化）：

```
user://battle_logs/<同名>.replay.json
{ "version": 1, "when": "...", "run_seed", "chapter", "node", "enemy_content",
  "names": {"0": {uid: 名}, "1": {...}}, "boards": {"0": GridInventory.to_dict, "1": ...},
  "result": { "winner", "duration", "initial", "final", "buffs": [buff id…], "log": [事件…] } }
```

`BattleResult.to_dict / from_dict`、`BattleEvent.to_dict / from_dict` 新加；buff 定义按 id 从 `GameFlow.buff_defs` 回查。**不存 `CombatantSpec`**（规则树序列化是另一件大事，重算一场也不是作者这次要的；日志 `.jsonl` 里已经有全部过程）。

### 3.2 哪里看

- **开发工具**（`ui/launcher.tscn`）加「战斗回放」：`ui/battle/replay_browser.gd` —— 左边列 `user://battle_logs/*.replay.json`（新的在上，一行写：时间、章节、点、对手、胜负、时长），点一场右边 `BattleView.play(result, names)` + `set_board`，和真打时一样能倍速 / 拖动；底下两个按钮「打开日志文件夹」「打开这场的 .txt」。
- 游戏内**不加入口**（作者定不给玩家看）；结算屏不变。
- 命令行：`tools/replay_log.gd`（`CliTool` 子类）：`--script res://tools/replay_log.gd -- <file.jsonl>` 把 `.jsonl` 按 `.txt` 的格式打到标准输出（给 AI 线程在无窗口环境读日志用）；带 `--summary` 只打双方总伤害、每件道具出手次数、暴击率、buff 总层数。

## 四、改动点

| 层 | 改 |
|---|---|
| `core/battle` | `BattleTrace`、`TracedRng`、`BattleTraceWriter`；`BattleContext.trace` + `emit` / `dispatch_before_damage` 各一行；`RuleEngine` 出手 / 跳过各一行；`DamageResolver` 管线一行；`BuffInstance` 叠 / 到期一行；`BattleSim.run` 可选参数与快照节拍；`BattleResult` / `BattleEvent` 的 `to_dict / from_dict` |
| `core/run` | `NodeEvents._fight` 与猎手：建 trace、跑完写 `.jsonl/.txt/.replay.json`、滚动删旧；`BattleArchive`（列目录、读一场、删旧）放 `core/battle/battle_archive.gd` |
| `core/settings` | `GameSettings.battle_trace`（默认按上面） |
| `ui` | 设置屏开发区一行 + 按钮；`replay_browser`；沙盒也传 trace |
| `tools` | `replay_log.gd` |
| 测试 | `tests/battle/test_battle_trace.gd`：开 trace 时 `before_damage` 与 `rule_skip` 都在、关着时 `ctx.log` 逐条不变（掩码不变式照旧）；`BattleResult` JSON 来回等价（`log` 逐条 name / time / side / payload 相同）；存 50 场滚动；`replay_browser` 读一份样例回放、`play` 后游标走到末尾；`replay_log` 对样例输出含「S0」「S1」两方 |
| 文档 | 架构文档 4.8 加「内部日志与回放存档」一段；`status.md` 命令行清单加 `replay_log` |

## 五、待定（按推荐即执行）

| # | 事 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 日志默认开关 | 编辑器 / 非导出包默认开 / 一律默认关 | **非导出包默认开**（作者本地跑就有日志，不用记得去开） |
| 2 | 留多少场 | 50 / 不限 | **50**（一场几百 KB，够查最近一天） |
| 3 | 要不要存双方编译结果以便重算 | 存 / 不存 | **不存**（回放用不上；日志里有全部过程；真要重算有种子 + 沙盒） |
| 4 | 回放入口 | 只在开发工具 / 结算屏也加 | **只在开发工具**（作者定不给玩家看） |
