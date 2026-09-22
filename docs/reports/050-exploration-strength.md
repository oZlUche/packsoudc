# 050 · 探索度：踩上去才造的敌人跟走了多远、搜了多少挂钩

> 阶段 5 · M4 补充 ｜ 架构文档 6.0、6.2（v1.48）｜ 前一步：[049](049-m4-review.md)

作者原话：

> 关于随机点和搜索点生成的敌人，需要有一套机制保证他们的强度是跟当前地图探索度（当前位置、总步数、搜索次数）挂钩的。

## 做了什么

| 文件 | 改动 |
|---|---|
| `core/enemies/strength_rule.gd` | 加「探索度」一组：`steps_per_tier` / `steps_max_bonus`、`searches_per_tier` / `searches_max_bonus`；`wanted()` 多一个 `exploration` 参数，`exploration_bonus()` 算加几档 |
| `core/enemies/enemy_placer.gd` | `wanted_strength` / `place_one` 透传 `exploration`；`fill`（生成时）不传 |
| `core/run/node_events.gd` | `exploration()` = `{steps: 行动点总数, searches: 本局累计搜索次数}`；随机点揭成战斗、搜索点遭遇现造敌人时传进去；累计搜索次数含正在搜的这一次 |
| `data/authoring/enemy_pools/standard_ruins.json` | 占位：每 12 步一档、最多 2 档；每 4 次搜索一档、最多 1 档 |
| `tests/test_enemy_pool.gd`、`tests/test_node_events.gd` | 探索度的算法；随机点与遭遇的敌人档位 = 规则 + 当时的探索度；生成时放好的敌人不变 |

## 三个输入各在哪

| 作者说的 | 落在 |
|---|---|
| 当前位置 | 原来就有：深度（tier 归一化）与危险等级 |
| 总步数 | `ActionClock.total`，每 `steps_per_tier` 步加一档，最多 `steps_max_bonus` |
| 搜索次数 | 本局累计（含正在搜的这一次），每 `searches_per_tier` 次加一档，最多 `searches_max_bonus` |

全是加法，和原来的深度 / 危险 / 类型 / 难度 / 规模一起夹进档位表。

## 一条边界

**只对踩上去才造的敌人生效。** 地图上看得见的敌人（战斗 / 精英 / 核心）生成时就定了档位，不随探索变 ——
5.10 的承诺是「看到的就是打到的」，走了三十步再回来打同一个点，敌人不能偷偷变强。
测试守着这条：生成时放好的敌人档位等于不带探索度的规则值。

## 验证

```
bash tools/test.sh
通过  6005 项断言，37 个套件
```

- 算法：不传不加；不够一档不加；每 N 一档；两项相加；各自封顶；都是 0 就不算。
- 随机点：在出生点与岔路口之间来回走到步数够了，再踩随机点（强制变战斗），现造的敌人档位 = 规则 + 探索度，不低于不算探索度的值，步数够了就更高（除非本来到顶）。
- 搜索遭遇：曲线拉满第一次就遭遇，敌人档位按「第 1 次搜索」算；会话结束后累计次数记下。
- 看得见的敌人不变。
