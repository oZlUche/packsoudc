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

## 九 首跑结论（执行线，2026-10-22，v4.23）

三张表：[第〇层 估算 vs 实测](balance/2026-10-22-power.md)、[第一层 标准废墟池](balance/2026-10-22-standard_ruins.md)、[第一层 猎手池](balance/2026-10-22-hunters.md)（流派木桩 60 份，每格 300 场；表头的 git 哈希是这批改动提交前的那一版，数值 json 没动）。

1. **同段同档（★）随段一路往下掉**：标准废墟池五路的 ★ 格，段 0 在 66%～91%，段 1 在 35%～67%，段 2 在 9%～67%，段 3 在 6%～42%；猎手池同样（段 0 79%～100% → 段 3 12%～63%）。木桩的件数、稀有度跟着档涨，**生命不涨**（默认角色 55 一直到底），敌人的 `stat_scale.max_hp` 从 1.15 涨到 2.4、格挡也涨。真玩家有科技、buff、套装、护甲补，木桩没有，所以这一截里有一部分是木桩偏弱；但「同段同档」越往后越难打的方向是档位表的生命倍率给的，作者先看这一处。
2. **档 0 → 档 1 是个陡坎**：段 0 的木桩打档 1，除了 burst（85%）都在 14%～39%。档 1 敌人生命 ×1.5、稀有度上限 2，而段 0 的木桩只有 2～3 件。
3. **不单调的格子**（表尾自动列出）：bleed 从段 1 到段 2 在每一档都降（68→60、36→28、16→9）；burst、rapid 打档 3 时段 3 反而比段 2 低。bleed 那几行是因为段 2 起不限稀有度，流派池里抽到的多是不出伤害的件（印记、护腕、伤口盐），武器只有一把弱刀（DPS 9）——流派池的武器比例要看。burst / rapid 的反降落在胜率本来就低（≤ 34%）的格子里，三百场的波动加上段 3 换了一批道具，先不当问题。
4. **哪路偏强、哪路偏弱**：burst 前期最强（段 0 打档 1 85%，别的路 14%～39%；同段极差 71 个百分点），对上第〇层表 `warhammer` 实测 ÷ 估算 1.35、`mithril_sword` 1.56——锤子和秘银剑被估低了，商店价、掉落档都按低的算。bleed 整体最弱（四张表的「最低」多半是它；段 2 ★ 9%），第〇层表里 `scimitar` 0.90、`cleaver` 0.89，流派套组的「联动」全是负的。另一个离群值是 `poisoned_knife` 实测 ÷ 估算 2.26。
5. **仗打得很快**：平均时长 1.3～14 秒，多数 2～5 秒，离 600 秒时限很远，开打几秒就分出胜负。55 血对 30 DPS 本来就是两秒，这是木桩血少的结果；真实木桩来了再看一次。

**给作者的顺序建议**：先改第〇层（`power_weights.json` 里锤类、秘银、毒刀的系数），再看档位表的生命倍率与档 1 的件数，最后看 bleed 流派池的武器比例。真实木桩（作者打十局）来了，把木桩换成 `dummies.json` 重跑一遍，第 1 条那一截「木桩偏弱」就能分出来。

## 十 落地（v4.23）

§8.1 七项都在一个 PR 里。

- **流派木桩**：`core/run/calibration/archetype_builder.gd`（`ArchetypeBuilder`），工具 `tools/build_archetypes.gd -- [池] [难度] [输出]`，默认输出 `data/authoring/calibration/archetypes.json`（073 格式，键 `流派/段/种子`，每份多记 `archetype` / `bracket` / `seed` / `tier` / `bags` / `picked` / `left`）。和派工的两处出入：
  - 挑道具用敌人的 `EnemyPlacer.choose_items`，流派就是这一路的标签。盾、防具两路的流派池里没有武器，补一件（同稀有度上限里随机）。
  - 摆法不是 `LootPacker.pack`，因为它出的是不要包的自由容器，玩家没有这种棋盘。改成开局棋盘（marcus 8 × 6、皮包 + 小包，后两段多一个皮包），用和开局发 kit 同一条 `try_add` 贪心摆：包先摆，武器先摆，大的先摆。一件哪个包都装不下（长剑 1 × 4 进不了 3 × 3 的皮包），就从包池添一个装得下的最小的包；长边 4 的甲、塔盾用长条包并排铺满它的外框。60 份里还剩 2 份各差一件甲，原因是棋盘满了，这一件记在 `left` 里。
- **扫表**：`core/run/calibration/balance_matrix.gd`（`BalanceMatrix`），工具 `tools/bench_matrix.gd -- [木桩] [池] [难度] [每格场数] [种子] [输出]`。时限与加时按 `standard` 节点规则。第 i 场的敌人只看（种子, 档, i），五路同格打的是同一串敌人。四张表之外，表尾多一节「单调性检查」，列出反着走超过 5 个百分点的格子。
- **对局记录**：`CalibrationRecorder.record_run(result, run)` 在 `_settle_run` 里调，只记一次，写到 `user://calibration/runs.jsonl`。快照多一个 `version` 字段。
- **版本号**：`project.godot` 的 `config/version="0.1.0"`。两份导出预设的 `product_version` 填 `0.1.0.0`，因为 Windows 的版本号要四段（引擎有「Invalid product version」这条检查；没在本机实际导出验证）。界面上不显示。
- **导出平衡数据**：设置「老手」区「全部解锁」下面一颗平的小按钮，说明写在悬浮窗里，玩家版也有。实现在 `DataExport`：zip 里放 `calibration/…`、`battle_logs/…`，目录是空的也留一个目录项。文件放桌面，取不到桌面就放 user:// 并打开那个文件夹。成功和失败的提示分别走 `say` / `warn`。
- **日志上限**：`BattleArchive.KEEP` 200。
- **顺手两处**：`EnemyPlacer._bag_fits` 改成公开的 `bag_fits`，木桩工具要用。`tools/bench_hunters.gd` 的默认难度从Ⅰ改成Ⅲ，因为 241 之后猎手在Ⅲ，原来的默认值取不到段位表。
- **测试**：`tests/battle/test_balance_242.gd` 五项，按 §8.3：五路 × 四段都摆得进、编得过、带武器；一格 10 场跑通、四张表都在；`runs.jsonl` 一局一行、带版本号；zip 里两个目录都在；滚动删到 200。

**一处要作者知道**：战斗日志在玩家版**默认是关的**（`BattleArchive.default_on()` = `DevGate.on()`），开关在只有开发包才有的「开发」区里。所以别人用玩家版导出的 zip 里，`battle_logs/` 是空的，只有校准记录（快照 + 对局结果）。木桩、扫表用的是校准记录，不受影响。要不要让玩家版也记战斗日志，归架构线定；这次没动。

## 十一 补充二：玩家版也记战斗日志（架构线定，2026-10-22 19:30）

§十 末尾那一处：玩家版的 `BattleArchive.default_on()` 跟着 `DevGate.on()`，别人导出的 zip 里 `battle_logs/` 是空的。**定：玩家版也记**，`default_on()` 恒为真。

- 为什么：对局记录只有「这一局赢了几场」，看不出「段 2 的真玩家打档 2 的某个敌人赢没赢、几秒」——而这正是和 §九 的木桩表对表要用的那一格。战斗日志一场三份几十 KB，上限两百场不到十 MB；写在工作线程上（236），玩家感觉不到。
- 不变：117 的「游戏里没有入口、不给玩家看」照旧——打开日志文件夹的按钮和开关仍只在开发区；玩家只通过「导出平衡数据」把它带走。
- 派执行线：`default_on()` 返回 `true`（函数留着，开发区开关照旧能关）；`tests/battle` 里有断言默认关的那条改过来；README 行照旧。
