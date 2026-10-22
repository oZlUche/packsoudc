# 242 数值平衡怎么做：先假人扫表，再作者实玩，两层各管一半

作者 2026-10-22 15:44（架构设计线）：「关于数值方面的平衡，该怎么做？需要收集游玩数据吗？还是直接生成假人用随机配装统计胜率？」

本报告只回答「怎么做」并盘点现成工具；**没有派单**，作者点头后再发执行线。

## 〇 一句话

两样都要，但分工不同、先后有序：**先用假人把「离谱的数」压平**（便宜、一晚几万场、可复现），**再用作者自己的实玩定「手感」**（假人测不出节奏、取舍和爽点）。假人不要「随机配装」，要「流派配装」——随机凑出来的棋盘多半是废包，统计出的胜率只是噪声。另外一个现成的好消息：**实玩数据已经在自动记了**（见 §一），不用再加采集。

## 一 现成的工具（都能跑，只是没人喂数据）

| 层 | 工具 | 在哪 | 状态 |
|---|---|---|---|
| 道具 | 战斗力估算 vs 实测（151）：每件武器单独打不死的木桩量实际 DPS，和 `PowerEstimate` 估的战斗力并排；同流派套组里每件的组合贡献 | `core/authoring/power_bench.gd`，`tools/bench_battle.gd -- power`；系数表 `data/authoring/balance/power_weights.json`（全占位） | 能跑，没对过表 |
| 配装 vs 敌人 | 猎手校准（073）：木桩 × 猎手池每一档 → 胜率，并排「规则会给哪档 / 最接近五成的哪档」 | `core/run/calibration/hunter_bench.gd`，`tools/bench_hunters.gd` | 能跑，**缺木桩文件** `data/authoring/calibration/dummies.json`（目录都还没有） |
| 木桩 | 平均玩家木桩（073）：把实玩快照按步数分段，每段取离平均最近的一块真棋盘（medoid） | `core/run/calibration/dummy_builder.gd`，`tools/build_dummies.gd` | 能跑，没有快照就退回「开局装备当第〇段」 |
| 实玩记录 | 校准记录器（073）：正式游戏**每走一步**记一份玩家配置（种子 / 章节 / 角色 / 难度 / 步数 / 搜索数 / 体力 / 棋盘布局 / 基线 / buff） | `core/run/calibration/calibration_recorder.gd`；`ui/game/game_director.gd:101` 常开，`game_flow.gd step_to()` 每步写 | **一直在记**。作者机器上就是 `%APPDATA%\Godot\app_userdata\背包搜打撤\calibration\snapshots.jsonl` |
| 战斗记录 | 每场三份（117）：内部日志 / 人读 / 回放存档，含胜负与时长 | `user://battle_logs/`，只留最近 50 场 | 一直在记 |
| 对局记录 | 局外 `MetaState.history`：最近二十局的 `RunResult`（结果 / 步数 / 胜负场数 / 搜索 / 合成 / 总分） | `core/meta/meta_state.gd` | 一直在记，但只留二十局、会被挤掉 |
| 单场成本 | 两千场批量基准 | `tools/bench_battle.gd` | 能跑 |
| 回放 | 性能探针的回放（236） | `tools/perf_probe.gd -- bench` | 能跑 |

战斗模拟 `BattleSim.run` 按种子确定、无头可跑，所以假人统计不需要开窗口、不需要 exe。

**缺的只有三样**：① 木桩文件（从快照或流派生成）；② 把「木桩 × 普通敌人池各档」扫成一张表的工具（现在只有猎手池那一版）；③ 对局结果的长期记录（`history` 只留二十局）。

## 二 为什么不是「随机配装」

- 随机抽道具往往**摆不进棋盘**（形状、包的格子），能摆的也多半是「三把刀两个盾没有回复」这种废包；统计出来的胜率对应的是没人会玩的配置。
- 随机配装**没有协同**：流派标签（`burst` / `rapid` / `bleed`）、邻接、连结、信仰阶数全靠摆法，随机摆等于把这些机制的贡献全抹平，而这些正是要平衡的东西。
- 随机配装的「平均」没有意义：一堆废包取平均还是废包，073 当初就为这个选了 medoid 而不是随机。

所以假人要**按流派造**：和敌人同一条造法（`EnemyPlacer.build_content` 用档位表「件数 / 棋盘 / 倍率 / 稀有度上限」造敌人，211 的 `builds` 给了十八种敌人的流派），给玩家侧也造几套——每个流派一套、每个进度段一套。

## 三 第一层：假人扫表（执行线做工具，作者看表改数）

### 3.1 木桩从哪来

两条路并行、**同一个文件格式**（`dummies.json`，073 已定），后一条到了就替换前一条：

- **流派木桩**（马上能有）：新工具 `tools/build_archetypes.gd`——流派 × 进度段。流派取道具库现有的三个战斗标签 + 「盾」「防具」两种防御偏向，共五路；进度段用猎手的段位表（241 后是 0 / 5 / 10 / 20 步）；每段的件数、稀有度上限按 `standard_ruins` 的档位表取对应档——也就是「假设玩家和同段敌人一样富」。摆法用 `LootPacker.pack` 贪心塞棋盘（开局 8×6，后段加一个包）。每路每段再抖三份（换种子）防止一块棋盘的偶然性。
- **真实木桩**（作者打十局后）：`tools/build_dummies.gd` 吃 `snapshots.jsonl`，每段一块真棋盘。十局 × 三十几步 ≈ 三百份快照，每段几十份，够取 medoid。

### 3.2 扫什么

新工具 `tools/bench_matrix.gd`（猎手版的推广）：木桩 × 敌人池每一档 × 难度 → 每格 N 场（默认 300），输出 markdown 表到 `docs/reports/balance/<日期>.md`，四张表：

| 表 | 每格 | 看什么 |
|---|---|---|
| 胜率 | 赢的比例 | 同段对同档应落在目标带；随档单调下降、随段单调上升；不单调 = 档位表或道具数有洞 |
| 时长 | 平均 `BattleResult.duration` | 太短 = 一方秒杀；贴着时限 = 没人打得动（`fight_sec` 占位 12 秒、时限见 `node_rules`） |
| 余血 | 赢时剩的生命比例 | 赢得太轻松 = 数虚；配合胜率看「险胜」还是「碾压」 |
| 五路对比 | 同段五个流派胜率的极差 | 极差大 = 某流派道具偏强 / 偏弱，回到第〇层（151 表）找那一类 |

### 3.3 目标带（建议，作者可改）

| 对手 | 目标胜率（同段同档木桩） | 理由 |
|---|---|---|
| 普通敌人 | 七成上下 | 一局要打五六场还要撤得出去；全五成等于撤离率不到一成 |
| 精英 | 五成上下 | 收益高，该有风险 |
| 猎手 | 五成（作者 073 定） | 追杀本来就是「跑不掉才打」 |
| 首领 | 四成（同段满配木桩） | 一局的终点，多数人第一次打不过才有「下次更强」 |

目标带的具体数留作者定；工具只打印，不改数（073 原则）。

### 3.4 第〇层先过一遍

扫表之前先跑一次 `bench_battle.gd -- power`：哪一类效果「估算 ÷ 实测」偏得多，先改 `power_weights.json` 对应系数。这层不改道具数，只让 151 的估算靠谱——商店定价、掉落档位、敌人倍率都靠它。

### 3.5 调数循环

跑表 → 作者改 json（敌人 / 档位表 / 道具）→ 再跑表 → 单调、落带为止。每轮几分钟（三百场一格、五路 × 四段 × 四档 ≈ 二万四千场，`bench_battle` 量过单场成本，一晚绰绰有余）。表进 `docs/reports/balance/`，每轮一份，改了什么写在表头，方便回看。

## 四 第二层：作者实玩（定手感，假人替不了）

假人测不出的：一局的节奏（三十六步够不够）、体力压力、钱够不够逛商店、侵蚀疼不疼、哪一步开始觉得「稳了」、首领是不是「值得再来一局」。这些要靠人打，而且**数据已经在记**：

1. 作者照常打十局左右（不用特意配装，照平时的打法就是「平均玩家」）。
2. 把 `%APPDATA%\Godot\app_userdata\背包搜打撤\calibration\snapshots.jsonl` 和 `battle_logs\` 交出来——「本地仓库同步」线能从作者机器上直接拷到 `/mnt/project-files/calibration/`，不用手传。
3. `build_dummies.gd` 生成真实木桩，替换流派木桩，§三 的表再跑一遍：真人的包比流派包「杂」，胜率一般会低一截，这一截就是要留给玩家成长的空间。
4. 对局层看三个数：撤离率、平均存活步数、撤离时总分——来自 `MetaState.history`。

**小改一处**（归第二层，执行线顺手）：对局结束时把 `RunResult.to_dict()` 追加写进 `user://calibration/runs.jsonl`，不再受 `HISTORY_MAX` 二十局限制；`CalibrationRecorder` 加一个 `record_run()` 即可，十几行。

## 五 第三层：玩家数据（现在不做）

发出去之后才有意义。现在没有玩家、没有上传管道，而且**本地文件已经是「可寄回」的格式**（快照 / 战斗日志 / 对局记录三份 jsonl），真到那一步只需要一个「导出平衡数据」按钮打包这个目录，不需要联网遥测。238 的发布工程那一条到时一起做。

## 六 顺序与分工

| 步 | 谁 | 做什么 | 产出 |
|---|---|---|---|
| ① | 执行线 | `build_archetypes.gd` + `bench_matrix.gd` + `record_run()`；跑一次第〇层和第一层 | `docs/reports/balance/` 第一张表 + 151 的估算 vs 实测表 |
| ② | 作者 | 看表改 json（§3.5 循环，一两轮） | 「离谱的数」压平 |
| ③ | 作者 | 照常打十局；同步线拷出快照与战斗日志 | 真实木桩 |
| ④ | 执行线 | 真实木桩再扫一遍；对局三个数 | 第二张表 |
| ⑤ | 作者 | 定节奏 / 体力 / 钱的数（`node_rules` / `economy_rules` / `chapters`） | status.md 的占位清单逐行销掉 |

status.md「占位数值清单」里，①② 管 `enemies` / `enemy_pools` / `items` / `power_weights`；④⑤ 管 `node_rules` / `economy_rules` / `drop_rules` / `chapters` / `characters`。

## 七 不做的

- 不做随机配装假人（§二）。
- 不做整局无头机器人跑「撤离率」：`/mnt/project-files/testing/playtest.gd` 能整局打，但它的取舍是脚本定的，撤离率反映的是脚本不是玩家；对局层的数只认作者实玩。
- 不做联网遥测（§五）。
- 不在这份报告里定任何数：目标带是建议，数由作者定、工具只打印。

## 八 补充一：别人的玩家版也在记；派工（作者 18:48「发」）

作者 18:47 问：「如果我将玩家版exe发给其他人，他们的游玩记录能否也被储存，如果交给我是否也可以用作配置」——**能**。记录器在 `GameDirector` 装配里、不走开发开关，玩家版每走一步照记；jsonl 一行一份，几个人的文件首尾相接当一份读即可。三处要补（已并入这次派工）：战斗日志只留五十场；快照没有版本号，几版混着会偏；别人翻 AppData 不方便。

### 8.1 派给执行线的一批（一次做完、一个 PR）

| 项 | 做什么 | 定下的细节 |
|---|---|---|
| ① 流派木桩 | `tools/build_archetypes.gd` | 五路（`burst` / `rapid` / `bleed` / 盾偏向 / 防具偏向）× 猎手段位 0 / 5 / 10 / 20 步；每段件数、稀有度上限取 `standard_ruins` 对应档；`LootPacker.pack` 贪心摆进开局棋盘（后两段加一个包）；每路每段三个种子；输出 `dummies.json`（073 格式，段号 → 木桩），默认写 `res://data/authoring/calibration/archetypes.json`，不占 `dummies.json`（留给真实木桩） |
| ② 扫表 | `tools/bench_matrix.gd` | 参数：木桩文件、池 id（默认 `standard_ruins`）、难度、每格场数（默认 300）、种子；复用 `HunterBench.win_rate` 的造敌路径（`EnemyPlacer.pick/build_content` → `EnemyKit.spec_of` → `BattleSim.run`）；输出 markdown 到 `docs/reports/balance/<日期>-<池>.md`：胜率 / 平均时长 / 赢时余血 / 同段五路极差四张表，表头写参数与 git 短哈希。只打印，不改数 |
| ③ 对局记录 | `CalibrationRecorder.record_run(result, version)` | `_settle_run()` 记完账后追加一行 `RunResult.to_dict()` + `version` + `character` + `difficulty` 到 `user://calibration/runs.jsonl`；每步快照也加 `version` 字段 |
| ④ 版本号 | `project.godot` `config/version`、`export_presets.cfg` 两个 `product_version` | 填 `0.1.0`（238 提过一直是空）；`version` 字段读 `ProjectSettings.get_setting("application/config/version")`；主菜单角落不显示（没要求，别加字） |
| ⑤ 导出按钮 | 设置页「老手」区（117 的打开日志文件夹按钮旁） | 「导出平衡数据」：`ZIPPacker` 把 `user://calibration/` + `user://battle_logs/` 打成 `背包搜打撤-数据-<日期>.zip` 放到桌面（`OS.get_system_dir(SYSTEM_DIR_DESKTOP)`，取不到就放 user:// 并打开文件夹）；按钮样式平的（230 规则）；说明进悬浮窗；键 `settings.export_data` / `settings.export_data_desc` 中英；完成提示走 `say`。玩家版可见 |
| ⑥ 战斗日志上限 | `BattleArchive.KEEP` | 50 → 200（三份一场约几十 KB，两百场不到十 MB） |
| ⑦ 第〇层、第一层各跑一次 | `bench_battle.gd -- power` + `bench_matrix.gd` 对 ① 的木桩 | 两张表进 `docs/reports/balance/`，第一张表的几行结论写进本报告 §九（哪里不单调、哪路偏强） |

### 8.2 不做

- 不改任何数值 json；表给作者看。
- 不加联网上传。
- 收回来的多人数据怎么合：拿到文件再说（`cat` 即可），不做合并工具。

### 8.3 测试

① 五路 × 四段都能摆进棋盘、`DummyBuilder.compile` 编得过；② 一格 10 场跑通、markdown 四张表都有；③ `runs.jsonl` 一局一行、带版本；⑤ zip 里两个目录都在；⑥ 滚动删到 200。`tests/battle/test_calibration.gd` 旁边加。
