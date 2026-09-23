# 062 · buff 骨架：局外 buff 与地图 buff、效果树的 RUN 分支

> 058 / 059 顺序里的第 3 项 ｜ 架构文档 6.1、8.2、9.2、10.1（v1.60）｜ 前一步：[061 仓库格子化](061-warehouse-grid-codex-and-store.md)

作者要的（059 第 3 条与第六节）：局外 buff 由局外选项决定、可以修改各种机制、保留最大灵活性；地图 buff 一般是强化或弱化，或者一个标记，
用于在特定节点导向分支剧情；先占位，做一个简单的基础 buff 测试功能；局外选项目前做成开关列表；地图 buff 的时限做成字段。

## 产出

| 文件 | 职责 |
|---|---|
| `core/effects/effect_scope.gd`、`run_effect.gd` | 效果树第四个分支 `RunEffect`（作用域 `RUN`）：不依赖扳机，往 [RunContext] 里加数 |
| `core/run/run_context.gd` | 一局的规则被 buff 改成了什么样：体力上限、开局钱、多搜几次、商店价倍数、幸运。没有 buff 时全是 0 / 1 |
| `core/run/effects/*.gd` | 五个构件：`vitality_max_bonus` / `starting_funds_bonus` / `extra_searches` / `shop_price_mult` / `luck_bonus`，登记在 `EffectRegistry.RUN_EFFECTS` |
| `core/run/run_buff_def.gd` | `RunBuffDef`：scope（META / MAP）、`duration_steps`（0 = 整局）、`tags`（标记）、`mods` / `rules` / `effects`（和套装档位同一种分法）。新内容种类 `run_buffs` |
| `core/run/run_buffs.gd` | 一组激活的 buff 合起来：算上下文、收战斗属性与规则、往掉落上下文里加、查标记、从资产目录装全部 |
| `core/run/run_state.gd` | `meta_buffs`（开局那一刻定下来）、`map_buffs`（每条 id + 还剩几步）；开局按上下文改体力上限与钱；`compile_player` 并进 buff 的属性与规则；掉落上下文带幸运、施加 buff 与**道具 / 套装的战利品效果**；`grant_map_buff` / `remove` / `has_map_buff` / `has_buff_tag` / `tick_map_buffs`（每走一步）；跟着存档 |
| `core/run/node_events.gd`、`search_session.gd`、`shop_session.gd` | 会话开的时候拿上下文：搜索点多搜几次（`extra_searches`）、商店打折（`price_mult`） |
| `core/meta/meta_state.gd` | `active_buffs`（id 列表，跟着存档）、`toggle_buff` |
| `core/run/game_flow.gd`、`ui/game/game_director.gd` | 装全部 buff 定义；开局把局外的激活列表给 RunState；读档回来补定义表；`toggle_meta_buff` 改了就存 |
| `ui/game/meta_screen.gd`、`map_screen.gd` | 局外屏「局外 buff」开关列表（占位）；地图 HUD 一行 buff 栏（占位：名字、还剩几步） |
| `data/authoring/run_buffs/` | 四个测试用的：坚韧（体力上限 +1）、幸运（幸运 +1）、被盯上了（纯标记）、虚弱（5 步内伤害 −10%） |
| `tests/test_run_buffs.gd` | 4 组 |

## 几条决定

**「修改各种机制」= 效果树多一个分支，不是一张固定字段表。** 9.2 的效果树按作用域分支、各系统只查自己那一档；buff 能改的东西就写成第四个分支 `RunEffect`，
往 `RunContext` 里加数，`RunState` 与各会话在对应的点读自己关心的那一项。加一种可改的机制 = `RunContext` 多一个字段 + 一个构件 + 那个系统去读，
不改基类、不改导入器、不改 buff 的定义。战斗属性与规则走套装那条老路（`mods` / `rules` 并进编译），掉落走 `LootEffect` —— 一个 buff 三样都能带。

**两种 buff 是同一套定义、不同的生命周期。** 局外的由 `MetaState.active_buffs` 说了算，开局那一刻记进这一局（`RunState.meta_buffs`）并跟着存档 ——
中途改了局外的选项不影响进行中的一局；一局里的由事件的后果给（`grant_map_buff`），有时限的每走一步少一步、到 0 就没了，整局的写 0。

**标记就是什么都不带的 buff。** 作者说地图 buff 可以只是一个标记，用于导向分支：`tags` 一列就够，`has_buff_tag` 给将来事件选项的条件查。导入器对「什么都不改也没标记」的 buff 告警。

**顺手接上了两处早就留好的缝。** 6.1 的 `MetaDropBonus` / `MapDropBonus` 是返回 0 的占位；现在 buff 的 `LootEffect` 直接施加到掉落上下文上，幸运也从 buff 来。
另外发现 9.2 说的「掉落系统取 `tracker.effects_in_scope(LOOT)`」在一局里一直没接（沙盒与 RunState 的掉落上下文只带难度），这次在 `RunState._loot_context` 里接上了：
道具与套装的战利品效果现在真的影响掉落。两个占位来源类留着（沙盒的预览还用它们），下一步清理。

**局外选项先是开关列表。** 作者说将来有任务系统、局外科技，还要考虑 buff 栏的 UI；现在局外屏一列开关、地图 HUD 一行字，都是占位，`active_buffs` 谁来改不写死。

## 验证

```
bash tools/test.sh
通过  6798 项断言，42 个套件，耗时 74 秒
```

- 管线：带 RunEffect、标记、时限的 buff 往返逐字节相同；战斗效果放 `effects` 里报错并提示写进 `rules`；时限不能为负；什么都不改也没标记告警；四个作者文件是不动点、资产在、`load_all` 全装回、作用域按文件。
- 开局与掉落：坚韧的加成从定义里读，开局体力上限多了它；不认识的、地图作用域的不算局外 buff；掉落上下文里的幸运 = buff 给的，同一件东西的掉落率多了幸运 × `luck_bonus`。
- 地图 buff：局外的、不认识的给不了；给标记后 `has_map_buff` / `has_buff_tag` 查得到；时限从定义里来；发 `buffs_changed`；虚弱时预估 DPS 更低；存档带着两种 buff、读回来上下文一样；
  走满时限没了、整局的还在、再给只是刷新不重复。
- 会话：搜索上限 1 + 多搜 1 = 2 次；商店五折每一格更便宜货不变；踩上真的搜索点，会话拿到了 buff 给的次数。
- 流程：局外屏开坚韧就存、下一局体力上限多了；存档继续回来定义表补上、buff 还在；关了下一局没有。

## 没做的

- 局外 buff 的来源（任务、科技）、buff 栏的正式 UI。
- 事件的后果「给一个地图 buff」和选项条件「有没有某个标记」：事件层（下一项）接。
- `MetaDropBonus` / `MapDropBonus` 两个占位类的清理。
