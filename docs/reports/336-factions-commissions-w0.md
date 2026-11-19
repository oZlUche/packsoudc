# 336 阵营与委托 W0：定义表、局外状态、声望与接取规则

> 日期：2026-11-19。作者 2026-11-19 20:24：查看[阵营与委托方案](../plans/2026-11-19-factions-and-commissions.md)，按理解落实并让执行线程执行。规格见[报告 335](335-factions-commissions-exec-spec.md) 第七节 W0。
> 基线：main `d17c969`（v6.56）。这一批不出界面，玩家看不到任何变化。

## 目标

335 第七节 W0：调用图核对；`factions`、`commissions` 两张定义表与导入校验；`MetaState` 新字段（旧档默认没有委托）；声望与接取规则的纯逻辑和测试。

## 一、调用图核对（委托以后要挂在哪）

| 链路 | 现在的入口 | 委托怎么接 |
|---|---|---|
| 红武来路 | `RedSources`（`enemy_kit.gd`、`run_state.gd`、`hunter_system.gd` 调） | 不改，只列回归：`tests/run/test_red_sources_281.gd` |
| 寂灭 | `JimiePath.plant`（`GameFlow.begin` 末尾）、`jimie_ready` 条件、`jimie_sacrifice` 后果 | 不改，只列回归：`test_jimie_trial_281.gd`、`test_jimie_altar_281.gd` |
| 托付 | 撤离确认框的【托付】（`map_screen._open_confirm` → `GameFlow.open_safe` → `SafeModule`，`closed` 信号） | W2 的「带回、托付算数」听 `SafeModule.closed` |
| 撤离点 | 走到撤离点发 `NodeEvents.extract_reached`；玩家按【撤离】开**确认框**（`map_screen._open_confirm`），不走 `extract_default` 事件 | **偏离 335**：「查验」「交信」做成确认框上的键（和【托付】并排），不加进 `extract_default.json`。节点规则里撤离点虽然挂着这个事件，但到点时 `NodeEvents` 走的是 `extract_reached`，不弹事件屏 |
| 结算 | `GameFlow._settle_run` → `RunResult.settle` → `MetaState.absorb`（`settled_runs` 挡重复）→ `MetaSave.write` 成功才删局档 | W1 在 `absorb` 同一次结算里调 `Commissions.merge_run`；重复结算时 `absorb` 返回 `duplicate`，委托也不并 |
| 铁匠铺 | 基地「打造」键 → `GameFlow.forge(id)` → `Smithy.forge`（静态，无信号） | W1 在 `GameFlow.forge` 打成后调 `Commissions.credit` |
| 存档版本 | `MetaState.SAVE_VERSION = 5`（319 刚升）；信仰重构没动局外版本 | 新加 `commissions` 键带默认值，按 098 的规矩**不升版本** |

## 二、产出

| 文件 | 职责 |
|---|---|
| `core/meta/commissions/faction_def.gd` | 一方：名字、先后、列不列出来（`listed`）、四级门槛、服务表、联系人 |
| `core/meta/commissions/commission_def.gd` | 一份委托：阵营、档位、声望、接取级数覆盖（`min_tier`）、前置、可做章节、步骤、酬金、互斥组、原话、委托人 |
| `core/meta/commissions/commission_stage.gd` | 一步：目标种类、次数、参数、完成地点（camp / field / carry）、托付算不算、任务道具、卡面一句 |
| `core/meta/commissions/commission_book.gd` | 局外状态：各方声望、署名、每份委托的进度与去重键、互斥归属、回执、线索；存读 |
| `core/meta/commissions/commissions.gd` | 规则：读定义、档位、能不能接、接 / 暂缓 / 放弃、记账、结案发奖、一局并进局外、整批校验 |
| `core/authoring/content_importer.gd`、`content_paths.gd` | 两种新内容进管线（排在 NPC 之后）和导入校验 |
| `core/meta/meta_state.gd` | `commissions` 字段，存读 |
| `data/authoring/factions/*.json`（5 份） | 五方；使团、猎盟 `listed: false` |
| `data/authoring/commissions/*.json`（3 份） | 三张原型单（任务信 W1 再加） |
| `tests/meta/test_commissions_336.gd` | 74 条断言 |
| `assets/fonts/*` | 新字 协 委 寄 盟 研 簿 署 酬 院 补进子集 |

## 三、关键决策

1. **四级名字五方相同**，放字表（W1 加），不在每份阵营里重复写。
2. **《两条回路》原型期陌生可接**：它是调查单（+2，按档位要熟面），可军团的入门单 W2 才有，不提前放开就走不通第四节的循环。用 `min_tier: 0` 覆盖，W2 补齐入门单时删掉这一行。
3. **接取 = 追踪**：接着的（不算暂缓）就是出征带进去的那至多两份，不另设「追踪」开关。暂缓不占位、进度保留；放弃清进度，能重接。
4. **去重键 = 委托 id | 第几步 | 那一处**（节点 id 或实例 uid），记在这份委托身上。读档重进、同一节点反复进都只记一次。
5. **模板封顶**：模板给的声望只补到熟面（2），已经 ≥2 就给 0，完成次数照记。
6. **带回类**：本人撤离成功才算；写明 `entrust_ok` 的，托付成功也算；都没成写一条「重做」回执，这一步不退，已完成的步骤保留。现场交付的失败也算（和配方发现同一条路）。
7. **不升存档版本**：老档没有 `commissions` 键 = 全空。

## 四、数值（候选，W4 再校）

| 委托 | 档位 | 声望 | 酬金 |
|---|---|---|---|
| 两条回路 | 调查 | +2 | 60 金币 |
| 照抄也要做得出 | 入门 | +1 | 40 金币（只补劳动，成品归玩家） |
| 无人署名的信 | 入门 | +1 | 30 金币 |

## 五、候选文本（待作者过目）

方案里加了引号的原话原样用：《两条回路》「去的时候路都好走。替我看看，回来还能走哪条。」

下面都是候选：

| 位置 | 中文 | English |
|---|---|---|
| 两条回路 · 英文名 | — | Two Ways Back |
| 两条回路 · 原话英文 | — | Every road is easy on the way in. Find out which ones still lead back. |
| 两条回路 · 委托人 | 军需官 | Quartermaster |
| 两条回路 · 做什么 | 在两处不同的撤离点各查验一次 | Inspect two different extraction points. |
| 照抄也要做得出 · 英文名 | — | Copy It, Then Make It |
| 照抄也要做得出 · 委托人 | 考据所研究员 | Archive researcher |
| 照抄也要做得出 · 做什么 | 在铁匠铺照选定的配方打造一次 | Forge the chosen recipe once at the smithy. |
| 无人署名的信 · 英文名 | — | The Unsigned Letter |
| 无人署名的信 · 委托人 | 不留名的寄信人 | An unnamed sender |
| 无人署名的信 · 做什么 | 把信交给免费撤离点的接应员 | Hand the letter to the contact at a free extraction point. |
| 五方英文名 | — | Legion Recovery Corps / Mages' Society Frontier Archive / Grey Lamp Mutual Aid / Senate Frontier Envoys / Northern Hunters' League |

## 六、验证

- `bash tools/test.sh 336`：通过 74 项断言。覆盖：五方顺序与只列三方；原型单导入与整批校验；导入报错（不认识的目标、目标不许的完成地点、现场步骤写托付、门槛乱序、找不到阵营、档位与空步骤、前置成环、跨方前置）；四级与代言要署名；两个位、暂缓、放弃、前置、互斥、要选配方；同一处只记一次、分步、结案的声望 / 酬金 / 回执、模板封顶、署名与互斥归属；现场失败也算、带回失败写重做、托付成功才算、并两次不重复；存读往返、v4 老档读进来委托全空且图鉴不变。
- 全量 `bash tools/test.sh`：通过 41627 项断言、341 个套件；`bash tools/warnings.sh`：0 条。

## 七、遗留与下一步

- W1：任务信道具与 `commission` 标签、`CommissionModule`、撤离确认框的「查验」「交信」、委托簿页签、任务卡、局内小牌、结算段落（占位美术），打造记账，教程没完与切片档案不显示。做完请作者试玩。
