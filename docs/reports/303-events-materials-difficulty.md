# 303 常规事件补充 + 制作材料 + 难度调整：实施记录

> 作者 2026-11-11 14:18 / 14:18 指派（「读取 docs/plans 里最新的执行方案……确认正确后开始执行实装」「应当还包括材料和难度调整」）。
> 依据：[事件与 UI 方案](../plans/2026-11-11-events-and-ui-comprehension.md)、[材料与难度方案](../plans/2026-11-11-crafting-materials-and-difficulty.md)。执行线程：架构方案执行（二）。

## 目标与顺序

两份方案共用同一个主题奖励池（事件方案 §8.4，材料方案 §5.1 / §8 引用它），所以按下面的顺序分步合并，每步一个 PR、一行变更记录：

| 步 | 内容 | 方案出处 | 状态 |
|---|---|---|---|
| 1 | 主题奖励池：加权有放回、按事件实例冻结、按奖励定价、事件拿得走的统一、导入校验、抽样统计 | 事件 §8.4、§2.6 | 本节 |
| 2 | 材料供给审计工具与配方需求矩阵 | 材料 §6（A 批） | 未开始 |
| 3 | 三件首批材料与来源 | 材料 §4.1、§5（B 批） | 未开始 |
| 4 | 第一批八个事件 E01–E08、地图专属事件池、每局一次、旧事件安全修复 | 事件 §5、§7、§8.1–8.3 | 未开始 |
| 5 | 材料供给复测 M1 / M2 | 材料 §7.2（C 批） | 未开始 |
| 6 | 难度实验 D1–D5 候选表（正式值待作者定） | 材料 §7（D 批） | 未开始 |

第二批事件 E09–E12 照方案 §10.5 等 UI 专项复测之后再排。方案 §1 / §9 的机制审阅与 UI 走查归审阅、测试线程。

与方案不同的两处：新材料的说明文字按作者规则留空（方案给了草稿）；新材料先用开发占位图，正式图由美术线程出。

## 第 1 步：主题奖励池

### 产出

| 文件 | 职责 |
|---|---|
| `core/run/events/reward_pool.gd`、`reward_pool_entry.gd` | 新内容种类 `reward_pools`：每行 道具、基础权重、`deep_mult`、`hard_mult`、`min_depth`、`chapters`；`probabilities` / `draw`（有放回） |
| `core/run/events/outcomes/give_pool_item.gd` | 后果 `give_pool_item`（`pool`、`key`、`count`）：只发冻结好的那份；池里没合格候选时 `blocked_reason` 让选项灰掉 |
| `core/run/events/event_rewards.gd` | 冻结：`set_pending` 时把事件里每份 key 抽好写进 `node.content["rewards"]`；文字占位符 `{reward_name}` `{reward_names}` `{reward_price}`；按奖励定价 |
| `change_money.gd`、`can_afford.gd` | 新字段 `reward_key` + `reward_price_mult`：按那份冻结奖励的定价收钱 / 判够不够（同一笔） |
| `conditions/vitality_not_full.gd` | 新条件：体力没满（E04 满体力时恢复选项灰掉） |
| `event_condition.gd`、`event_outcome.gd`、`event_option.gd` | `describe_in(ctx)`（要看一局才说得准的原因）、`blocked_reason(ctx)`；`locked_reason` 先查条件再查后果 |
| `event_context.gd`、`has_item.gd`、`lose_item.gd` | §2.6：`EventContext.takeable` —— 锁定、独一、包（除非 `include_bags`）不被事件拿走；`has_item` 新字段 `takeable` 只数这一批；`lose_item` 只从这一批挑 |
| `say.gd`、`ui/game/event_screen.gd` | `say` 里的 `{reward_name}` 换成那件的 `{item:…}`；结果页的话过一遍占位符（祭坛「{item:knife}断了」以前原样露出记号） |
| `content_importer.gd`、`content_paths.gd` | 池的导入校验（空池、权重 ≤ 0、倍率为负 / 无穷、深度越界、找不到 / 包 / 金银 / 封存 / 独一的道具）；事件引用不存在的池、按奖励定价却没那份奖励、`lose_item` 前没有 takeable 的 `has_item` 都报错 |
| `core/run/calibration/reward_pool_stats.gd`、`tools/reward_pool_stats.gd` | 池 × 章节 × 深度 × 难度的理论概率与固定种子实抽对照、期望稀有度 / 定价 / 重量 / 格数 / 材料比例；有空格或偏离就退出 1 |
| `data/authoring/reward_pools/*.json`（11 个） | 第一批八个事件要用的池（见下表），数值是首轮测试建议值 |
| `data/authoring/events/event_altar.json` | 祭坛两个 `has_item` 开 `takeable`（锁定的不再被「献上最值钱的一件」拿走） |
| `tests/run/test_event_reward_pools.gd` | 见「验证」 |

### 第一批的池（首轮建议值，不是定稿）

| 池 | 候选（基础权重；深处 / 高难度加权的标了） |
|---|---|
| food_supply 食物补给 | 口粮 4、熏鱼 3、腌肉干 2（深 ×2）、行军军粮 1（深 ×3，≥0.3，难 ×1.2） |
| wrapping_material 绳布 | 麻绳卷 4、亚麻布卷 3、羊毛呢 2（深 ×1.5） |
| medicine 药品 | 纱布 4、伤药 3、绷带卷 3、解毒包 2、浓缩伤药 1 / 止血敷料 1（深 ×2，≥0.3，难 ×1.2） |
| metal_cargo 金属货 | 铜锭 4、铁矿石 3、铁钉桶 2、钢锭 1（深 ×3，≥0.3）、银锭 0.5（深 ×3，≥0.5） |
| light_salvage 轻便材料 | 麻绳卷 3、亚麻布卷 3、木棍 3、松脂块 2、羊毛呢 1（全部重量 ≤ 2） |
| metal_salvage 金属材料 | 铜矿石 4、铁矿石 3、铁钉桶 2、铜锭 1、钢锭 0.5（深 ×3，≥0.4） |
| worked_wood 木材料 | 木棍 3、硬木板 1（深 ×2）；第 3 步加风干木料 |
| mechanism_parts 机关零件 | 齿轮臂 4、黄铜齿轮 2、主发条 2（深 ×2）、蒸汽阀 1（深 ×2，≥0.3） |
| mechanism_fasteners 固定件 | 铁钉桶 4、铆钉盒 2、钢锭 1（深 ×2，≥0.3） |
| workshop_supplies 加工材料 | 磨刀石 4、燧石 3、松脂块 2、蜂蜡块 2 |
| metal_curios 金属旧物 | 铜油灯 4、鎏金酒杯 1（深 ×3，≥0.3） |

### 关键决策

- **冻结时机 = 事件挂起时**（方案「事件实例生成有效奖励上下文时预抽」）。随机数只由节点 `content_seed` 与 key 派生，和战斗、搜索的随机流隔开；冻结记录带池 id、深度、难度档，之后深度 / 难度变了也不改。
- **池放进内容管线**（和包池同一套），不塞进节点规则：校验、编辑、导出都现成；排在道具之后、事件之前。
- **没有合格候选 = 选项灰掉**，不是报错也不先扣代价；导入时一个池没有「深度 0、不限章节」的行就警告。
- **§2.6 统一成一批**：不改 `ItemPick`（侵蚀也用它），在 `lose_item` 里过滤；`has_item` 的 `takeable` 默认关，教程的「棋盘上得有武器」门禁不受锁定影响。

### 验证

- `bash tools/test.sh reward_pool`：47 项断言通过。覆盖：单候选抽 50 次足额且全是它；权重 = 基础 × 深度 × 难度（3 : 6 : 1 的算例）；章节、最浅深度、道具库筛候选；同种子同结果、抽 2000 次后概率不变；真实药品池抽 10,000 次全部落在理论 ±4 个标准差 内、配置摘要不变；冻结后读档同一件、重新挂起不重抽；钱买扣预览的价、给预览的那件、结果那句换上那件；材料换给同一份，锁着的一束不算数、解锁后能换；空池选项灰掉写原因、选了不耗时间；锁定的钢斧不被「最值钱」拿走，包默认不拿；导入器九种错都报。
- `godot --headless --path . --script res://tools/reward_pool_stats.gd -- --n=10000`：11 个池 × 2 章 × 3 深度 × 4 难度 = 264 格，无空格、无偏离。
- 全量测试与静态警告见变更记录那一行。

### 遗留

- 第 2–6 步。
- 开放问题（交接时就挂着）：同种子商店 / 搜索结果随代码变动。v5.65 已改用 `Ids.sort`；本机复核 `Array[StringName].sort()` 确实按指针排（`[&"zeta", &"alpha", &"mid"]` 排出来是 zeta、mid、alpha）。剩下的 `sort()` 调用还没逐个审完。
