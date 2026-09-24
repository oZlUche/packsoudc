# 074 · 猎手专属池与段位：段位只看步数，猎手按段位定档，木桩按段位分段

> 069 第九节 ｜ 架构文档 8.5（v1.71）｜ 前一步：[073 校准工具](073-calibration-tools.md)

作者：加一个猎手专属池占位；猎手的实际配置会根据玩家当前属于的段位变化，段位只受步数影响。

## 产出

| 文件 | 职责 |
|---|---|
| `data/authoring/enemy_pools/hunters.json` | 猎手专属池（占位）：五种敌人、四档，条目不限节点种类；`hunter_1` / `hunter_2` 指定它 |
| `core/run/mechanics/hunter_mechanic.gd` | `bracket_steps`（第 k 段从第几步开始，占位 [0, 5, 10, 20]）、`bracket_of(steps)`；导入器：第一项 0、非递减 |
| `core/run/hunters/hunter_def.gd` | `strength_by_bracket`（下标 = 段位，值 = 档位，超表按最后一档；空 = 退回规则）、`strength_for_bracket()`；导入器：非负 |
| `core/run/hunters/hunter_system.gd` | `bracket()`（只看步数）、`strength_for(def, pool, node)`：段位表优先，表空退回强度规则；开打时用它 |
| `core/run/calibration/dummy_builder.gd` | `build_by_brackets(snaps, items, thresholds)`：木桩按同一张段位表分段（最后一段开区间） |
| `core/run/calibration/hunter_bench.gd` | `run(..., brackets)`：wanted = 猎手表里这一段的档；表打印开区间为 ∞ |
| `tools/build_dummies.gd`、`bench_hunters.gd` | 第二 / 第五个参数给难度 id 就用它的段位表 |
| `tests/test_hunters.gd`、`test_calibration.gd` | 各加 1 组 |

## 几条决定

**段位是玩家的属性，只看步数，表在难度里。** 猎手机制的 `bracket_steps` 划段；同一难度下所有猎手、木桩、校准表用同一张。
猎手定义里只写「每一段几档」。作者说的「猎手的实际配置随段位变」就是这张表：段位一变，开打时从池里抽的档位跟着变，敌人的棋盘、道具、属性按档位表来。

**探索度那条路留着当退路。** 表空的猎手（或没有段位表的老难度）退回 071 的强度规则。作者内容都配了表，退路只在测试和旧数据上走。

**校准对着同一张表。** 木桩按段位分段，胜率表的 wanted 就是「这一段猎手表里的档」，best 是最接近 50% 的档 —— 两列对不上就改猎手的表，一段一格。
第一次跑（开局装备当第 0 段、每档 40 场）：wanted 档 0，best 档 2 —— 说明第 0 段的表值该从 0 调到 2，作者定。

## 验证

```
bash tools/test.sh
通过  7508 项断言，50 个套件
```

- 段位：步数 → 段位按表；第一项不是 0 / 递减 / 档位负数都报错；作者猎手指定了专属池且资产在、配了段位档位表、超表按最后一档、表空 -1。
- 一局里：走 1 步第 0 段、档位 = 表[0]；走 2 步（段位表 [0, 2]）第 1 段、档位 = 表[1]；表空退回规则给池里有的档；现造的敌人来自专属池。
- 校准：按 [0, 5, 10] 分成三段、范围对、最后一段开区间、样本数对；胜率表每段 wanted = 猎手表里那一档；开区间打印成 ∞。
