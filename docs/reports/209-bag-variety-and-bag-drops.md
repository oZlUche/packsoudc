# 209 包的种类、效果与稀有度；掉落改成「先掉东西，再按概率掉装东西的包」

> 架构设计 thread · 2026-10-19 · 提案（作者 21:30 夜间六条之三：「参考背包乱斗，给一些背包也设计效果，增加背包的种类，赋予不同稀有度，另外让高稀有度背包不再是固定掉落（战利品逻辑改为先计算有哪些战利品掉落了，然后再根据概率决定要掉落哪些包用来装载这些道具）」）。待定按推荐派执行；新包的图随本篇派美术。

## 0 一句话

包体效果的口子早就有（`ItemDef.bag_mods`：包里**整件**装着的东西各得一份加成，编译器 `_apply_bag_effects`；`bag_accept_tags` 限收什么），只是现有 5 个包都没写。本篇：**九个新包**（白 1 / 绿 4 / 蓝 3 / 紫 1，再加一个金的大行囊），每个一条效果；包体再加三个局内字段（里面的晶石不耗耐久 / 卖价倍率 / 负重倍率）。掉落改成两段：先照旧掷出掉哪些道具，再按**包池**掷「用哪些包装它们」—— 包池按稀有度加权、敌人自己背的包权重加倍、容量够装就停；敌人身上的包**不再必掉**。敌人开战时背的包也从包池里按档位抽，不再是写死的两三个皮革包。

## 1 现状（核过）

| 事 | 现在 | 用得上 |
|---|---|---|
| 包的定义 | `is_bag`、`bag_accept_tags`（任一命中）、`bag_mods: Array[StatModifier]`（给整件在包里的道具各一份）；`set_id`；包不算重（161，`ItemWeight` 一律 0） | 全在，加三个字段就够 |
| 现有包 | `bag_small` 2×2（没写稀有度）、`bag_long` 1×4 白、`bag_leather` 3×3 白、`belt_potion` 1×3 绿（只收 remedy / food）、`charm_earth`（护符兼包，不动） | 没有一个写 `bag_mods`；导入器对非包写 `bag_mods` 会 warn |
| 编译 | `_apply_bag_effects`：`bag_of(uid)`（整件落在一个包里才算）→ 包的 `bag_mods` 各施一份；横跨两包的两边都拿不到（3.2，有意） | 不改 |
| 悬浮窗 | `item_tooltip.gd:102` 已列 `bag_mods` | 加三个字段的文案 |
| 敌人背什么包 | `StrengthTier.bags` 写死（标准池：0 档 皮革 + 小包 … 3 档 三皮革两小包）；`EnemyDef.bags` 可覆盖（神射手两长条） | 改成从包池抽，`bags` 保留为覆盖 |
| 包怎么掉 | `DropRule.bags_always_drop = true`：身上的包必掉、不占保底；`corpse_of` → `_corpse_on_bags`：包按原位当背景、掉的东西回原位，摆不下走自由容器 | 这就是作者说的「固定掉落」 |
| 玩家从哪拿包 | 开局 `starting_bags`；敌人掉；搜索 `include_bags` 默认假；商店 `candidates` 直接排除包；宝箱不出包 | 高稀有度包现在**根本不出现** |
| 掉落掷骰 | `DropResolver.roll`：BOSS 保底、日神额外、携带品必掉、身上每件按稀有度掷、`guaranteed_drops`、`min_drops` 保底、珍宝 | 第一段原样保留 |

## 2 规则

### 2.1 包体字段（`ItemDef`，分组「包」）

| 字段 | 意思 | 谁读 |
|---|---|---|
| `bag_mods`（已有） | 包里整件的道具各得一份 | 编译器（已有） |
| `bag_wear_free: bool` | 里面的魔晶石供给一场不扣耐久 | `WearModule`：`board.bag_of(uid)` 的包 `bag_wear_free` 就跳过 |
| `bag_value_mult: float = 1` | 里面的东西卖价倍率 | `ItemValue.of_instance` 加一个带容器的入口 `of_in(inst, board)`；出售屏与悬浮窗的「值」用它 |
| `bag_weight_mult: float = 1` | 里面的东西负重倍率（129） | `ItemWeight.total(board)` 按 `bag_of` 乘；地上 / 仓库不算（本来就不算） |

- `bag_accept_tags` 不变（任一命中）。
- 导入器：三个字段写在非包上 → warn（和 `bag_mods` 同一句）。

### 2.2 包的目录（现有 5 + 新 9）

稀有度六档 白 0 / 绿 1 / 蓝 2 / 紫 3 / 金 4 / 红 5（087）。现有三个白包补上 `rarity: 0`（`bag_small` 现在没写）。

| id | 名 | 形 | 稀有度 | 材质 | 只收 | 效果 |
|---|---|---|---|---|---|---|
| `bag_small` | 小背包 | 2×2 | 0 | cloth | — | 无（改 rarity 0） |
| `bag_long` | 长条包 | 1×4 | 0 | cloth | — | 无 |
| `bag_leather` | 皮革包 | 3×3 | 0 | leather | — | 无 |
| `sack`（新） | 粗麻袋 | 2×3 | 0 | cloth | — | 无（白包多一个形状） |
| `belt_potion` | 药水带 | 1×3 | 1 | leather | remedy / food | 补一条：里面的东西 `haste` +10% |
| `fanny_pack`（新） | 腰包 | 1×2 | 1 | leather | — | 里面的东西 `regen_stamina` +0.5 |
| `quiver`（新） | 箭囊 | 1×3 | 1 | leather | ammo / bow / ranged | 里面的东西 `crit_chance` +0.05 |
| `tool_roll`（新） | 工具卷 | 1×3 | 1 | cloth | tool / part | 里面的东西 `haste` +10% |
| `herb_pouch`（新） | 药草囊 | 2×2 | 1 | cloth | herb / remedy / food | 里面的东西 `regen_hp` +0.5 |
| `studded_satchel`（新） | 铆钉挎包 | 2×2 | 2 | leather + metal | — | 里面的东西 `max_armor` +2 |
| `rune_pouch`（新） | 符文囊 | 2×2 | 2 | cloth + magic | crystal / magic / staff | `bag_wear_free`：里面的魔晶石不耗耐久（208） |
| `hunting_bag`（新） | 猎囊 | 2×3 | 2 | leather | flesh / bone / leather / trophy | 里面的东西 `damage` +2（212 的魔兽器官住这儿） |
| `treasure_satchel`（新） | 百宝囊 | 3×2 | 3 | leather + gem | — | `bag_value_mult` 1.25、`bag_weight_mult` 0.5 |
| `war_pack`（新） | 军用行囊 | 4×3 | 4 | leather + metal | — | 里面的东西 `damage` +1；**大就是效果**（12 格） |

- 数值是起点；执行照 `PowerWeights` 核一遍，原则：包的效果值 ≈ 同稀有度一件饰品的一半（空间本身已经是价值）。
- 所有包 `value` 走 `ItemValue` 公式（稀有度 × 格数），不手写。
- 美术：9 张新图 + @2x（画布 = 形状 × 60 / 160，201 规则），随本篇派 美术设计。先用剪影落地。

### 2.3 包池（新内容种类 `bag_pools/*.json`，`BagPool`）

```json
{"id": "standard", "display_name": "标准包池",
 "entries": [
   {"bag": "bag_small", "weight": 6}, {"bag": "bag_long", "weight": 4}, {"bag": "bag_leather", "weight": 6}, {"bag": "sack", "weight": 4},
   {"bag": "belt_potion", "weight": 2}, {"bag": "fanny_pack", "weight": 2}, {"bag": "quiver", "weight": 1.5}, {"bag": "tool_roll", "weight": 1.5}, {"bag": "herb_pouch", "weight": 2},
   {"bag": "studded_satchel", "weight": 1}, {"bag": "rune_pouch", "weight": 0.8}, {"bag": "hunting_bag", "weight": 1},
   {"bag": "treasure_satchel", "weight": 0.4}, {"bag": "war_pack", "weight": 0.15}
 ],
 "fill_target": 0.8, "max_bags": 3, "extra_bag_chance": 0.5, "own_bag_weight_mult": 2.0}
```

- 章节 `ChapterDef.bag_pool`（默认 `standard`）；敌人池的档位 `StrengthTier.bag_count: Vector2i`（默认 [1, 2]）+ `rarity_cap` 一起限制抽什么包；`StrengthTier.bags` 仍可写死（序章、神射手走它）。
- 开战时敌人背的包：`EnemyPlacer.build_content` 从池里按权重抽 `bag_count` 个，稀有度 ≤ 档位 `rarity_cap`（−1 不限），同一个包可重复；摆不下的少一个。神射手这种有 `EnemyDef.bags` 的照旧。
- 包池是**单独一个种类**而不是塞进掉落规则：敌人开战背的包和死后掉的包同一张表，一个数改两处生效。

### 2.4 掉落：两段

1. **先掉东西**：`DropResolver.roll` 原样（BOSS 保底、日神、携带品、按稀有度掷、`guaranteed_drops`、`min_drops`、珍宝），但 `bags_always_drop` 默认改 **false**，身上的包**不参与**第一段（既不掷、不计保底）。`guaranteed_drops` 里写了包的仍必掉（序章教程「遭遇的敌人必掉一个包」）。
2. **再掉包**（`DropResolver.roll_bags(dropped_cells, content, pool, tier_cap, rng)`）：
   - 要装的格数 `need = Σ 掉落道具的格数 / fill_target`；
   - 候选 = 池里稀有度 ≤ `tier_cap`（敌人档位的 `rarity_cap`；BOSS 不限）的包；**敌人自己背着的包**权重 × `own_bag_weight_mult`（看见它背什么，多半就掉什么）；
   - 第一个包必抽；之后每个包按 `extra_bag_chance` 决定还抽不抽，直到容量 ≥ `need` 或到 `max_bags`；
   - 掉的东西一件没有（可能：全没掷中且 `min_drops` 0）→ 不掉包。
3. **摆尸体**（`corpse_of`）：掉下来的包先摆（是敌人自己的包就按原位，不是就找位）；掉的东西**优先装进包里**（原位还在包里就回原位，否则 `try_add` 进包覆盖的格）；装不下的散在包外的格上（尸体容器不要求在包里，老规矩）；再放不下才加高（`LootPacker.add`）。
   - 结果：玩家看到的尸体 = 几个包 + 包里的东西 + 零散几件，和现在的视觉一致，只是包不再是敌人那两个。

### 2.5 商店与搜索

- 商店：`EconomyRules.shop_bag_slot_chance: float = 0.3` —— 刷新时按它决定要不要把一个槽位换成包（从章节包池按权重抽，稀有度随深度 `shop_rarity_weights` 同一张表）。售价照 `ItemValue`。
- 搜索：`include_bags` 仍假（搜出包来里面没东西也不像话）。
- 宝箱：不出包。

## 3 改动

| 文件 | 改什么 |
|---|---|
| `core/inventory/item_def.gd` | `bag_wear_free` / `bag_value_mult` / `bag_weight_mult` |
| `core/inventory/item_value.gd`、`item_weight.gd` | 带容器的入口；出售屏、悬浮窗、负重读数改用 |
| `core/run/modules/wear_module.gd` | `bag_wear_free` 跳过 |
| `core/loot/bag_pool.gd`（新）+ `data/authoring/bag_pools/standard.json`（新） | §2.3；导入 / 导出 / 快照 / `ContentSchema` 登记（照 `carry_rules` 的路：`content_importer.gd:31 / 93 / 220`） |
| `core/run/chapter_def.gd` | `bag_pool: StringName = &"standard"`；`RunState` 解析 |
| `core/enemies/strength_tier.gd`、`enemy_placer.gd` | `bag_count`；从池抽包 |
| `core/loot/drop_rule.gd`、`drop_resolver.gd` | `bags_always_drop` 默认假；`roll_bags`；`corpse_of` 三步摆法 |
| `core/run/economy_rules.gd`、`shop_session.gd` | 包槽位 |
| `ui/inventory/item_tooltip.gd` | 三个字段的句子（「里面的魔晶石不耗耐久」「里面的东西卖价 +25%」「里面的东西负重减半」） |
| `data/authoring/items/`：9 个新包 + 4 个旧包补字段 | §2.2 |
| `data/authoring/enemy_pools/*.json`、`drop_rules/standard.json`、`chapters/*.json` | 档位 `bags` → `bag_count`（序章池保留 `bags`）；`bags_always_drop` 显式写假；章节 `bag_pool` |
| `core/authoring/id_aliases.gd` + snapshot | 新道具 |
| `docs/architecture.md` 3.2（包体效果一段）、6.1（两段掉落） | — |
| `tests/loot/test_bag_drops_209.gd`（新）、`tests/inventory/test_bag_effects_209.gd`（新） | §5 |

## 4 待定（按推荐派执行）

| # | 问题 | 推荐 |
|---|---|---|
| 4.1 | 敌人自己的包要不要在第二段里有优势 | **权重 ×2**（看见背什么多半掉什么，又不是必掉） |
| 4.2 | 掉的东西装不进掉的包 | **散在包外**（尸体容器不要求在包里；不多掷包） |
| 4.3 | 商店卖包 | **卖**，一个槽 30% |
| 4.4 | 搜索 / 宝箱出包 | **不出** |
| 4.5 | `war_pack` 金色是否太大 | **4×3 留着**：金包的效果就是空间；放不进棋盘是玩家的取舍 |
| 4.6 | `rune_pouch` 不耗耐久会不会太强 | **先这样**：它是蓝的、2×2 只装两颗晶石（1×2 各一），等数据 |

## 5 测试

1. 包体：`studded_satchel` 里一件护甲编译 `max_armor` +2，横跨两包的不加；`rune_pouch` 里的晶石打一场不扣，外面的扣；`treasure_satchel` 里 `ItemValue.of_in` ×1.25、`ItemWeight.total` 减半。
2. 包池：导入校验（bag 必须 `is_bag`、权重 > 0、章节引用存在）；`roll_bags`：掉 10 格东西、`fill_target` 0.8 → 抽到容量 ≥ 13 停；掉 0 件不掉包；`own_bag_weight_mult` 2 → 固定种子下敌人自己的包更常出现（统计 200 次）。
3. 两段：`bags_always_drop` 假 → 身上的包不进 `dropped`；`guaranteed_drops` 里的包仍掉。
4. 尸体：三步摆法 —— 东西优先在包里；装不下散在外；`LootView` 包仍当背景亮着。
5. 敌人开战：标准池 2 档 `bag_count [2, 3]`、`rarity_cap 2` → 抽到的包稀有度 ≤ 2；神射手仍是两长条 + 皮革 + 小包。
6. 商店：`shop_bag_slot_chance` 1.0 → 必有一个包槽，0 → 没有。
7. 老档：内容里 `tier.bags` 没了但节点内容已记着包的 id → `board_of` 照旧（内容记的是实例，不读档位）。

## 6 不做

- 不做「包的套装」「包升级」。
- 不做 `bag_rules`（给内容物挂规则）：这批效果 mods + 三个字段够用；哪个包要规则再加（编译器 `_attach` 一行）。
- 不动 088 的包替换 / 包进地上规则。
- 不做包的稀有度底色之外的新画法。

## 7 落地（v3.53，架构方案执行）

按推荐做完，测试见 `tests/inventory/test_bag_effects_209.gd`、`tests/loot/test_bag_drops_209.gd`。和方案不一样的地方：

1. **敌人开战的包多两步**：只抽「至少收得下一件已抽道具」的包；抽完先保证有一个包装得下最大的那件（按包围盒长边），再按格数 / `fill_target` 补，最多补 2 个（`EnemyPlacer.BAG_TOPUP`）。不这样，随机抽到的小包或限定标签的包（箭囊、符文囊）会让敌人的招牌道具摆不上棋盘。包按大小从大到小排。摆完若招牌或唯一的武器没摆上，就重抽一套包（最多 6 次，`EnemyPlacer.BAG_ROLLS`），取差得最少的那套：只看外框不够，秘银剑这类十字形要跨两个包才摆得下。
2. **4.2 掉的东西装不进掉的包**：没有散在包外，而是整具尸体退回老路（`LootPacker.board_of` 摆成自由容器）。要求放在包里的棋盘装不了包外的东西，散在外要另开一种尸体容器，不值得。
3. **`bag_value_mult` 只管撤离结算和悬浮窗**：商店卖出走卖货箱，那里没有包，不乘。
4. **序章单独一份掉落规则** `drop_rules/prologue`（标准规则的副本，`bags_always_drop` 开着），三张序章图用它、`bag_pool` 留空，教程里的掉落和以前一样。
5. **稀有度按表改了**：长包、皮包 1 → 0；药水腰带 2 → 1，并加急速（`bag_mods` haste ×10）。
6. 档位 `bag_count`：标准遗迹与机关池四档 `[1,2] / [2,2] / [2,3] / [3,4]`。有显式 `bags` 的敌人（神射手）照旧用自己的。
7. **材质标签只留一个**：铆钉挎包、百宝囊、军用行囊表里写的是「皮革 + 金属 / 宝石」，但 195 规定可生成的道具恰好一个材质标签，三个都只留【皮革】。
8. 新包的图交给 美术设计，没图时照旧画占位。
