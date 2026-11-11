# 303 常规事件补充 + 制作材料 + 难度调整：实施记录

> 作者 2026-11-11 14:18 / 14:18 指派（「读取 docs/plans 里最新的执行方案……确认正确后开始执行实装」「应当还包括材料和难度调整」）。
> 依据：[事件与 UI 方案](../plans/2026-11-11-events-and-ui-comprehension.md)、[材料与难度方案](../plans/2026-11-11-crafting-materials-and-difficulty.md)。执行线程：架构方案执行（二）。

## 目标与顺序

两份方案共用同一个主题奖励池（事件方案 §8.4，材料方案 §5.1 / §8 引用它），所以按下面的顺序分步合并，每步一个 PR、一行变更记录：

| 步 | 内容 | 方案出处 | 状态 |
|---|---|---|---|
| 1 | 主题奖励池：加权有放回、按事件实例冻结、按奖励定价、事件拿得走的统一、导入校验、抽样统计 | 事件 §8.4、§2.6 | v5.72（PR #564） |
| 2 | 材料供给审计工具与配方需求矩阵 | 材料 §6（A 批） | v5.77（PR #571） |
| 3 | 三件首批材料与来源 | 材料 §4.1、§5（B 批） | v5.77（PR #571） |
| 4 | 第一批八个事件 E01–E08、地图专属事件池、每局一次、旧事件安全修复 | 事件 §5、§7、§8.1–8.3 | 见第 4 步 |
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

- 第 5–6 步（第 2、3 步见下）。
- 开放问题（交接时就挂着）：同种子商店 / 搜索结果随代码变动。v5.65 已改用 `Ids.sort`；本机复核 `Array[StringName].sort()` 确实按指针排（`[&"zeta", &"alpha", &"mid"]` 排出来是 zeta、mid、alpha）。剩下的 `sort()` 调用还没逐个审完。

## 第 2 步：材料供给审计（A 批）

### 产出

| 文件 | 职责 |
|---|---|
| `core/run/calibration/material_supply_audit.gd` | `MaterialSupplyAudit`：外部来源表、可达性闭包、每张铁匠铺配方每一格的结论、材质 × 稀有度供给表、Markdown |
| `tools/audit_material_supply.gd` | 命令行外壳：`--out=…md`、`--json=…json`；有 `no_item` / `no_source` 的格退出 1 |
| `docs/reports/balance/2026-11-11-material-supply.md` | 第 3 步落地后的全库结果 |
| `tests/run/test_material_supply_303.gd` | 见「验证」 |

### 怎么算

- **资格**只用生产的 `SmithRecipeDef.material_fits`（材质格要 material 标签、材质对、稀有度够；魔晶石格认家族和档）。
- **外部来源**全用生产函数，按章（`free_mode`、`clockwork_hourglass`）分开：
  - 普通搜索：`SearchSession.candidates`，份额按 `rarity_weights` 算。
  - 材料节点：生成好的图里出现过的 `content.search_kind`，加上 `SearchSession.in_kind`。
  - 宝箱：去掉 treasure 排除（`include_treasure`）。
  - 局内商店：`ShopSession.candidates`。
  - 敌人携带：从真生成的图里数 `DropResolver.carried_ids`，不按身份标签猜。
  - 珍宝掉落：`treasure_chance > 0` 时的 `DropResolver.treasure_candidates`。
  - 事件奖励池：只算被事件 `give_pool_item` 真用到的池，按深度 1.0、难度 3 取候选上限。
  - 基地集市：固定摊满级的 `Market.catalogue`，加 `Market.loose_candidates`。
- **派生**：铁匠铺 / 砧的配方（含冶炼）和局内拖合配方。从外部来源出发做不动点闭包，算两遍：
  - 「不要门槛」：锁着的道具不算来源，要科技的配方不打。
  - 「全开」：都算。
- **每一格的结论**：

| 结论 | 意思 | 对应方案 §6.1 |
|---|---|---|
| `no_item` | 库里没有顶得上的道具 | 1 |
| `no_source` | 有道具，但全开也拿不到：断路，或只有自己产自己的环 | 2 |
| `gated` | 只有解锁成就或点科技后才拿得到 | 3 |
| `thin` | 不要门槛拿得到，但只有一种渠道 | 4 |
| `ok` | 不要门槛拿得到，至少两种渠道 | |

  方案 §6.1 的第 5 种（材料在仓库里但锁着）是存档状态，静态审计不管。
- 方案 §6.2 的随机供给实验（首次取得步数、路线机会、实际转化）归第 5 步（C 批）。

### 结果（第 3 步落地后）

- 铁匠铺配方 101 张，共 209 格：207 格 `ok`，2 格 `gated`，`thin`、`no_source`、`no_item` 都是 0。
- 两格 `gated` 都在 `anvil_imperial_sword` 上：
  - `mithril_sword` 要 `ach_extract_3` 解锁，扫 6 张图时只在敌人身上碰到过。只扫 2 张图时没碰到，会掉成 `no_source`。
  - `metal ≥ 4` 只有 `pale_shard` 一件顶得上，它要 `ach_boss` 解锁。来源是宝箱（宝箱规则去掉了 treasure 排除）。这回答了方案 §5.2 的疑问：灰白碎片已解锁时有合法来源，不是断供。
- 资格这一层基本都通，因为普通搜索的候选几乎覆盖全库。缺口在**频率**上，看材质 × 稀有度表（份额 = 这一档所有件在那条渠道里的合计份额）：

| 材质 · 档 | 第 3 步前 | 第 3 步后 |
|---|---|---|
| 木 · 绿 | 库里 0 件。木格门槛是绿，只能拿蓝的硬木板或铁木枝去顶 | 2 件。废墟林地 4.9%，沙漏遗骸 4.1%，普通搜索 1.5% |
| 石 · 绿 | 3 件，都是工艺品（磨刀石、花岗石臼、创口盐），只出在遗骸（12.8%），矿脉没有绿石 | 4 件。玄武岩在两图矿脉各 10.9% |
| 骨 · 蓝 | 遗骸 / 林地最高 5.1% | 不变 |
| 金属 · 蓝 | 遗骸 1.1% | 不变 |
| 魔晶石 · 橙 | 符文堆 0.8% | 不变 |

- 材质格里没有「只有搜索 / 节点这一条路、份额又低于 0.5%」的件。

## 第 3 步：三件首批材料（B 批）

| id | 名字 | 稀有度 · 材质 · 标签 | 形状 · 重量 · 价钱 | 来源（审计实测） |
|---|---|---|---|---|
| `straight_ash_branch` | 直纹梣木枝 / Straight-grained Ash Branch | 绿 · wood · material, nature, plant | 竖 1×2 · 3 · 24 | 废墟林地（`plant`）4.9%；两图普通搜索、局内商店、敌人携带；集市「材料」摊 2 级起。沙漏没有林地，所以沙漏的节点不出 |
| `seasoned_timber` | 风干木料 / Seasoned Timber | 绿 · wood · material, crafted, supply | 横 2×1 · 3 · 24 | 两图遗骸（`crafted`）4.1%；木材料池 `worked_wood` 权重 2，约 24%；普通搜索；集市「材料」「食物」摊 |
| `dense_basalt` | 致密玄武岩 / Dense Basalt | 绿 · stone · material, nature, mineral | 竖 1×2 · 5 · 24 | 两图矿脉（`mineral`）10.9%；普通搜索、局内商店、敌人携带；集市「材料」摊 |

- 消费：梣木枝和风干木料都顶 `anvil_hardwood_spear`、`anvil_ironwood_broadsword`、`anvil_longbow` 的木格（门槛绿）；玄武岩顶 `anvil_granite_maul` 的石格。
- 说明文字按作者规则留空；方案里给的草稿没有用。
- 图：先用开发占位；作者 2026-11-11 17:00 在美术设计选定三件都用 A，正式图 v5.81 换上（`assets/items/` 与 `@2x/`，进清单）。
- 价钱用默认推导（没写 `value`），三件都是 24，和磨刀石一样。铁木枝（蓝）60，橡木原木（白）15。材料本身不带战斗效果。
- 来源都靠已有的规则自然生效：节点按标签、搜索按候选、集市按摊的标签和级数上限。只改了木材料池一行，没有改节点、商店或保底规则。
- 和方案的出入：方案说风干木料走「散货摊」，但散货摊只卖战斗道具（`battle_tags`），不进材料。集市里卖材料的是「材料」摊（goods），2 级起会列出风干木料，所以没有为它改散货摊的规则。
- 字体：重新取子集，新加的字是 梣、玄、渠。
- 顺带修了一个旧问题，是加新件后暴露出来的：局内商店摆满时，「金银」那一格会被丢掉。这让 `bullion_slot_chance = 1` 不再是每家店都有，244 的测试在新候选下有一家店碰上了。现在金银摆不下时，从最小的普通货起逐件试，拿掉一件给它腾位置。包和金银不会被拿掉，腾不出来照旧丢（`ShopSession._make_room_for`）。另外，加了三件新候选，同种子的商店和搜索结果会再变一次。

### 验证

`tests/run/test_material_supply_303.gd` 共 25 条断言：

- 资格：
  - 巨兽獠牙根是 flesh，不顶骨格。
  - 没有 material 标签的石雕不顶石格。
  - 蓝石能顶绿门槛。
  - 火格只认火族、够档的魔晶石。
- 闭包，用合成的小库测：
  - 矿 → 锭 → 升级这条链能走通。
  - 只有自己产自己的环，结论是 `no_source`。
  - 要科技、料又锁着的格，结论是 `gated`。
  - 只有一条渠道的格，结论是 `thin`。
  - 库里没有顶得上的道具，结论是 `no_item`。
- 新材料：三件都是绿、说明为空，来源和上面的表一致，都有配方认。全库没有 `no_item` 格，也没有不要门槛的断路格。

### 遗留

- 方案 §6.2 的随机供给实验，以及 §6.3 里锁定、满包落地、读档这几种夹具，归第 5 步（C 批），要接真的搜索和库存流程。
- 第二批材料（层纹硬岩、老树心材）照方案 §4.2，等 C 批的数据再定。

## 第 4 步：第一批八个事件

### 产出

| 文件 | 职责 |
|---|---|
| `data/authoring/events/event_{supply_bundle,herbalist,stuck_cart,field_stretcher,refugee_weaver}.json` | 两图共用的 E01 / E02 / E03 / E04 / E07 |
| `data/authoring/events/event_{cracked_foundry,ward_recess}.json` | 废墟专属 E05 / E08 |
| `data/authoring/events/event_clock_oiler.json` | 沙漏专属 E06 |
| `core/run/chapter_def.gd`、`node_rules.gd`、`run_state.gd` | 章节新字段 `chapter_events`（`{"类型": {"事件 id": 权重}}`）：开局并进节点规则 `events_by_type` 的**副本**（`NodeRules.with_chapter_events`），共用的 standard 不动，不复制整份规则 |
| `node_rules.gd`、`event_placer.gd`、`node_events.gd` | 节点规则新字段 `event_max_per_map`：生成时、随机点揭开时、踩上去现配时都数图上已配的（`EventPlacer.used_counts`），到了上限的从同一张表里换别的抽，全满了不配（转场，不会出现不可交互的空点） |
| `data/authoring/node_rules/standard.json` | 事件表初始同权（cache / stranger 由 2 改 1），新加五个公共事件；八个新事件各上限 1 |
| `data/authoring/chapters/free_mode.json`、`clockwork_hourglass.json` | 废墟加 E05 / E08，沙漏加 E06 |
| `teleport.gd` | 挑不到落点时选项灰掉（「没有能落脚的地方」），裂隙不再先扣体力再什么也不发生 |
| `lose_item.gd`、`node_events.gd`、`ui/game/event_screen.gd` | 选项文字新占位符 `{lose_name}`：会被拿走的那一件（最值钱 / 最不值钱 / 指定 id；随机的不预告） |
| 旧事件 `event_cache` / `event_ambush` / `event_altar` / `event_rest_spot` / `event_rift` | 撬锁为什么费体力写进正文；伏击「上前查看（会遇敌）」；祭坛「献上……（{lose_name}）」「用匕首撬开石缝（匕首会断）」；歇脚处补一句环境；裂隙两个选项写出落点随机、倒计时与体力 |
| `core/run/calibration/event_distribution.gd`、`tools/event_distribution.gd` | 分布统计：两图各 N 个种子，各事件几张图有、一共几处、一张图最多；超上限或串图退出 1 |
| `assets/fonts/*` | 新文案的字重新子集 |
| `tests/run/test_events_303.gd` | 见「验证」 |

### 数值（首轮测试建议，不是定稿）

| 事件 | 代价与收益 |
|---|---|
| E01 补给 | 倒计时 −1 换食物补给池 ×1；或白拿绳布池 ×1 |
| E02 药摊 | 药品池预抽一件，按定价 ×1.0 收钱；或干草药束 ×2 换同一件 |
| E03 货车 | 体力 ≥ 2 时体力 −1 换金属货池 ×1（预览名字）；或白拿轻便材料池 ×1（都 ≤ 2 重） |
| E04 担架 | 倒计时 −2 回 1 体力；或付 15 回 1 体力；满体力两项都灰 |
| E05 铸槽 | 倒计时 −1 换金属材料池或木材料池 ×1 |
| E06 油槽 | 倒计时 −1 换机关零件池或固定件池 ×1 |
| E07 补衣人 | 熟皮革 ×1 换 16（定价 24、局内卖 7、基地卖 12）；亚麻布卷 ×1 换 10（定价 15、局内卖 4、基地卖 7）—— 高于出售、低于买入 |
| E08 凹龛 | 白拿加工材料池 ×1；或倒计时 −1 换金属旧物池 ×1 |

### 关键决策

- **地图专属池写在章节上**：两图共用 standard，原来没有章节覆盖能力。加一个薄字段 `chapter_events`，开局时并进规则副本，读档时同样重新并（规则不进存档）。
- **每张图一次 = 事件模板的出现上限**，和奖励池无关；上限只给新事件，旧七个照旧可以重复。
- **价钱不写「币」字**：选项按钮前的代价图标是金币（按奖励定价的付钱也算花钱，`EventCostIcons` 跟着改了）。
- **图**：普通事件本来就都没有图（只有寂灭两个事件有）。八个新事件照旧留空，缺图清单见「遗留」。

### 验证

- `bash tools/test.sh events_303`：136 项断言通过（导入、中英文、每个选项都有英文与不带条件的离开；两图各 40 个种子的上限、专属与信仰事件；随机点揭开时的上限；E04 满体力 / 没钱 / 付钱 / 坐下耗时 / 选过不能再选；E07 锁定 / 成交 / 关闭；E01 冻结、读档、结果那句；E03 体力不足；祭坛预告与锁定；裂隙没落点）。
- `godot --headless --path . --script res://tools/event_distribution.gd -- --n=100`（种子 1..100，只数生成时定进节点的）：

每章种子 1..100，只数生成时定进节点的事件（随机点揭开时现配的不算）。

#### free_mode：100 张图（开不出 0）

事件点共 553 个；有信仰事件的图 100 张。

| 事件 | 有它的图 | 一共几处 | 一张图最多 |
|---|---|---|---|
| event_altar | 25 | 28 | 2 |
| event_ambush | 23 | 25 | 2 |
| event_cache | 30 | 36 | 3 |
| event_cracked_foundry | 42 | 42 | 1 |
| event_field_stretcher | 28 | 28 | 1 |
| event_herbalist | 39 | 39 | 1 |
| event_marked_reward | 29 | 36 | 2 |
| event_refugee_weaver | 36 | 36 | 1 |
| event_rest_spot | 34 | 39 | 3 |
| event_rift | 21 | 24 | 2 |
| event_stranger | 31 | 32 | 2 |
| event_stuck_cart | 31 | 31 | 1 |
| event_supply_bundle | 29 | 29 | 1 |
| event_ward_recess | 28 | 28 | 1 |
| extract_default | 100 | 200 | 2 |
| faith_call | 100 | 100 | 1 |
| rest_default | 100 | 404 | 5 |
| search_default | 100 | 1502 | 20 |
| shop_default | 100 | 296 | 4 |

#### clockwork_hourglass：100 张图（开不出 0）

事件点共 477 个；有信仰事件的图 99 张。

| 事件 | 有它的图 | 一共几处 | 一张图最多 |
|---|---|---|---|
| event_altar | 28 | 32 | 2 |
| event_ambush | 20 | 22 | 2 |
| event_cache | 14 | 15 | 2 |
| event_clock_oiler | 22 | 22 | 1 |
| event_clock_room | 100 | 100 | 1 |
| event_field_stretcher | 17 | 17 | 1 |
| event_herbalist | 18 | 18 | 1 |
| event_marked_reward | 22 | 22 | 1 |
| event_refugee_weaver | 20 | 20 | 1 |
| event_rest_spot | 23 | 25 | 2 |
| event_rift | 19 | 24 | 2 |
| event_stranger | 24 | 25 | 2 |
| event_stuck_cart | 15 | 15 | 1 |
| event_supply_bundle | 21 | 21 | 1 |
| extract_default | 100 | 400 | 4 |
| faith_call | 99 | 99 | 1 |
| rest_default | 100 | 200 | 2 |
| search_default | 100 | 630 | 10 |
| shop_default | 100 | 200 | 2 |


沙漏有一张图没有信仰事件（种子 1..100 里的一张），这是信仰组只在事件点里挑、那张图事件点被别的占满的老情况，和这次无关；新事件没有一张图超过 1 处，也没有串图。

### 遗留

- 缺图：八个新事件和旧七个事件都没有插图。方案 §8.3 建议 5–6 张共享场景图（补给、行商 / 医工、废墟工坊、机关检修、人际援助、伏击），要请美术线程出。
- 方案 §7 的 stranger / marked_reward：`marked` 本身什么都不改，只是给「熟面孔」开门；文案没有承诺一定会再见，没改。
- 第二批 E09–E12 照方案等 UI 复测。

## 第 5 步：难度候选实验第一轮（D 批：D1 / D2 / D3）

只出候选表，**不改任何资产**；正式值等作者定。原始表在 `docs/reports/balance/difficulty/2026-11-11/`。

### 产出

- `core/run/calibration/balance_mutation.gd`（`BalanceMutation`）：实验副本里的改数。`foe` 按敌人 id 把它自己的基线属性（默认 → 敌人 → 档位倍率 → 节点内容覆盖之后的值）再乘一个倍率，写进节点内容的 `base_stats`，不动共用的档位表（档位表一动就是整池）；`hp` 让双方编译好的最大生命同乘。
- `BalanceExperiment.run` 认 `ctx.mutation` 和 `ctx.only_enemies`（覆盖测试只跑点名的敌人）。敌人实例的摘要照原件算，所以基线和改数打的是同一批敌人、同一套种子。
- `core/run/calibration/difficulty_candidates.gd` + `tools/difficulty_candidates.gd -- --exp=D1|D3`：基线和每个改数各跑一遍，按 case_id 逐场配对，算胜率差、时长差（配对自助法 95% 区间），按（段, 档）分格，同阶段的再按流派分。
- 测试 `tests/run/test_difficulty_candidates_303.gd`。

### D1 brute 局部（覆盖测试，只跑 brute，每格 100 场）

同阶段（段 = 档）的胜率变化，单位百分点，括号里是 95% 区间：

| 段 = 档 | 基线胜率 | brute 生命 −10% | brute 格挡 −10% |
|---|---|---|---|
| 0 | 67% | +4.4（+3.2～+5.9） | +3.3（+2.3～+4.6） |
| 1 | 40% | +4.9（+3.6～+6.4） | +0.9（+0.2～+1.7） |
| 2 | 27% | +5.6（+4.0～+7.0） | +0.8（+0.2～+1.3） |
| 3 | 21% | +2.6（+1.7～+3.7） | +0.3（+0.0～+0.8） |

- brute 难打主要是**生命**，不是格挡：格挡 −10% 在档 1 以上几乎不动。
- 盾流对档 3 的 brute 是 10%，两种改法都只到 11%，盾流的短板不在 brute 的生命 / 格挡上。照方案禁区，档 3 的真伤身份不动。
- 候选：想让 brute 好打一点就用「只改 brute 的基础生命 −10%」（同阶段 +3～+6 个百分点，战斗短 0.1～0.4 秒）；格挡这一项不建议动。

### D3 节奏拉长（频率测试，20 张真实地图上的战斗点，每格 100 场）

双方最大生命同乘（道具加的生命也一起乘，比方案写的「基础生命」更宽一点）：

| 段 = 档 | 基线胜率 / 时长中位 | ×1.15 胜率差 / 时长差 | ×1.30 胜率差 / 时长差 |
|---|---|---|---|
| 0 | 90% / 3.2 秒 | +1.7 / +0.63 秒 | +2.4 / +1.17 秒 |
| 1 | 74% / 2.8 秒 | −1.1 / +0.41 秒 | +1.1 / +0.80 秒 |
| 2 | 61% / 2.4 秒 | −1.7 / +0.47 秒 | +0.8 / +0.87 秒 |
| 3 | 42% / 2.8 秒 | +2.0 / +0.76 秒 | +6.4 / +1.55 秒 |

- ×1.15 平均只多 0.4～0.8 秒，胜负基本不动（区间都跨 0 或在 ±2 以内）。
- ×1.30 多 0.8～1.6 秒；段 3 玩家胜率 +6.4（42% → 49%），后期偏向玩家，因为生命多了以后玩家的持续手段更吃香。
- 方案说「若只增加等待而无决策反馈，弃用」：模拟器只看得到时长，看不到有没有决策反馈，这一条要游戏测试线程在真机上看。候选按代价排：×1.15（几乎只拉长时间）→ ×1.30（拉长并且后期变容易）。

### D2 猎手 hunter_1（假节点抽样，每档 100 场，108 份木桩，每个步数段 27 份）

| 步数段 | wanted 档 | best = wanted | best 比 wanted 高 | best 比 wanted 低 | wanted 档胜率中位（四分位） | 高一档胜率中位 |
|---|---|---|---|---|---|---|
| 0～4 | 0 | 0 | 27 | 0 | 100%（98～100%） | 54% |
| 5～9 | 1 | 14 | 13 | 0 | 81%（71～86%） | 25% |
| 10～19 | 2 | 17 | 10 | 0 | 78%（62～94%） | 1% |
| 20～ | 3 | 17 | 0 | 10 | 30%（7～67%） | — |

- 第 0～4 步的猎手几乎必输（玩家 100% 赢），27 份木桩最接近五成的都是档 1（中位 54%）。候选：这一段换成档 1。
- 5～19 步换高一档会从八成直接掉到两成甚至 1%，离散档跳得太远。要靠近五成就得在档之间加一个小幅缩放；方案说先比相邻档，这一轮的结论就是相邻档不合适。
- 20 步以后是三成，四分位 7～67%，流派之间差得很大；不能凭一个总数调。
- 100 场只是初筛；方案要求候选复核用 400 场和几份不同的合法配装，下一轮做。

### 没做的、限制

- D4（处决武器按靶子生命阶段）、D5（同件品质 0 / 1 / 2 与取得成本）要另外的场景：D4 要能把靶子定在指定的生命阶段，D5 要给木桩换同件不同品质。下一轮做。
- 木桩照方案沿用 108 份；报告 297 里丢核心件的 8 份没有单独分组，这一轮的总数里包含它们。
- 都是模拟器结果，没有屏幕观看时长；节奏类结论要游戏测试线程复核。
