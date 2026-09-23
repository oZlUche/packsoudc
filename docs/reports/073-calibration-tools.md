# 073 · 校准工具：每步记玩家配置、按段生成木桩、木桩对猎手各档的胜率表

> 069 第八节的第 4 步 ｜ 架构文档 8.5、11（v1.70）｜ 前一步：[072 角色技能接口](072-character-skills.md)

作者定的（069 第七节第 7 条）：游戏系统完整后进行多场测试，将每局的玩家分成三～五个时间段的装备配置，每个配置生成一个平均木桩，
再生成猎手敌人专属配置，通过不断和木桩对战保证 50% 胜率。

## 产出

| 文件 | 职责 |
|---|---|
| `core/run/calibration/calibration_recorder.gd` | `CalibrationRecorder`：一局里每走一步记一份玩家配置（步数、搜索次数、棋盘 layout、基线、角色、难度、buff）到 `user://calibration/snapshots.jsonl`，一行一份追加；读回、按快照摆回棋盘、编译成战斗单位 |
| `core/run/calibration/dummy_builder.gd` | `DummyBuilder`：按步数分段（段长是参数），每段算平均生命 / 预估 DPS，木桩 = 段里离平均最近的那份真实配置；存 / 读 `data/authoring/calibration/dummies.json`；没有快照时开局装备当第 0 段 |
| `core/run/calibration/hunter_bench.gd` | `HunterBench`：每段木桩 × 池里每个档位打 N 场 → 胜率；并排「规则会给哪一档（wanted）」与「最接近 50% 的哪一档（best）」；同种子可复现；打印表 |
| `tools/build_dummies.gd`、`tools/bench_hunters.gd` | 两个命令行入口 |
| `core/run/game_flow.gd`、`ui/game/game_director.gd` | `GameFlow.recorder`：装了就每步记；正式游戏默认装（测试与纯逻辑的 flow 不装） |
| `tests/test_calibration.gd` | 2 组 |

## 几条决定

**记的是原始数据，切段是后面的事。** 每一步都记（一行 JSON，很便宜），段长在工具里给：作者说的「3～5 个时间段」就是段长 = 一局总步数 ÷ 3～5，
以后想换切法不用重新跑对局。

**木桩是真实配置，平均的是读数。** 一堆道具清单没法平均，但一块真的棋盘能上场打。每段算平均生命与预估 DPS，挑离平均最近的那份（各按平均归一的欧氏距离）当木桩。
木桩只带棋盘与基线，不带套装与 buff 的加成 —— 它是「平均玩家」，不是「这个玩家」。

**校准工具只做统计，不改数。** 每段木桩对着池里每一档打几百场，打印每档的胜率；再算一下按现在的强度规则、这一段的探索度会给哪一档，
和最接近 50% 的那一档并排。差在哪一眼看出来，作者改猎手的强度规则（`steps_per_tier` 那几个数）或池的档位表。敌人按猎手指定的池与规则现造，和一局里一样。

**现在跑出来的表只是工具在动，不是数值。** 快照要等系统完整后多场测试攒（作者原话）。第一次跑的样子（开局装备当第 0 段、每档 40 场）：

```
第 0～4 步（3 份样本，生命 60，DPS 15.0）　wanted 档 1　best 档 2　　档 0：100%　档 1：78%　档 2：45%　档 3：3%
```

意思是：按现在的规则第 0 段会给 1 档猎手，玩家能赢 78%；要接近 50% 得给 2 档。这就是作者要看的那一行。

## 怎么用

```bash
# 玩几局（正式游戏会自动记到 user://calibration/snapshots.jsonl）
# 按 5 步一段生成木桩
"E:/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tools/build_dummies.gd -- user://calibration/snapshots.jsonl 5
# 猎手 hunter_1 对各段木桩每档打 500 场
"E:/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tools/bench_hunters.gd -- hunter_1 500
```

## 验证

```
bash tools/test.sh
通过  7477 项断言，50 个套件
```

- 记录：第 0 步的快照记了棋盘上的每一件与尺寸；按快照摆回来的棋盘逐件相同；编译出来的生命和一局里一样；走六步记六份、读回六份、最后一份的步数 = 行动点总数。
- 分段：段长 2 → 段号 = 步数 ÷ 2，段数 = 出现过的段号数，每段的步数范围对；木桩离平均最近（和段里每一份比）；存了读回段数一样；没有快照时每套开局装备一份、全在第 0 段。
- 校准：每段一行、每个档位一个胜率、胜率在 0～1、每档都打了；best 是离 50% 最近的档；wanted 是池里有的档；同种子逐字相同；表里有猎手 id 与 best 列。

## 没做的

- 真正的数值：等系统完整后多场测试攒快照（作者原话）。
- 「猎手敌人专属配置」：现在猎手从这一章的池里抽；作者要专属的就加一个池、在猎手定义里指定。
- 木桩不带套装 / buff 加成；要带就在快照里多记两项。
