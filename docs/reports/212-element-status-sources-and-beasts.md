# 212 灼伤 / 寒冷 / 麻痹的新来源：魔兽器官；魔兽敌人（没有包，身上长着自己的「道具」）；一件道具两套逻辑（`wild`）

> 架构设计 thread · 2026-10-19 · 提案（作者 21:30 夜间六条之六：「灼伤、寒冷、麻痹也要引入，除了魔杖和附魔武器外，也可以加入一些魔兽器官拥有这些能力（火焰腺之类的），同时加入这些魔兽（魔兽没有背包，直接持有自己的皮、器官、爪子、牙齿、尾巴、腺体等东西作为道具，玩家获得这些道具并持有时效果将不一样，所以可能要写两套道具逻辑，直接加一套新的配置文件或者扩展现有的配置文件，你来取舍）」）。待定按推荐派执行；210 的机关敌人复用本篇的 `species` / `bagless` / `wild`。

## 0 一句话

三个状态都在（`scorch` 每层每秒 1 火、`chill` 武器冷却 ×(1+层×10%)、`numb` 耐力消耗 ×(1+层×10%)，175 补充四定的），差的只是**来源**：现在只有三颗魔晶石和锻造附魔会施加。本篇加六件魔兽器官（火焰腺 / 霜腺 / 电囊 / 兽牙 / 兽爪 / 兽尾）并给六件已有的兽材（生兽皮、狼心、蝰蛇毒腺、鹿角、巨兽獠牙根、上等毛皮）补战斗面；**取舍：扩展现有配置，不另开一套文件** —— `ItemDef` 加一块 `wild: CombatProfile`（魔兽自己持有时用它，玩家持有时用原来的 `combat` / `adjacency`），编译器挑档只多一个开关。魔兽是 `EnemyDef` 加两个字段（`species`、`bagless`）：棋盘不要求包，器官直接摆；死了照常掉（掉的就是玩家版）。首批五种魔兽。

## 1 现状（核过）

| 事 | 现在 | 用得上 |
|---|---|---|
| 三个状态 | `buffs/scorch.json`（on_schedule 1 s、每层 1 火伤，`element: fire`）、`chill.json`（`per_stack_percent 10`、`decay_halve_on weapon_fired`）、`numb.json`（`per_stack_percent 10`、`decay_halve_on stamina_paid`） | 不改 |
| 谁施加 | 只有 `fire_crystal` / `ice_crystal` / `lightning_crystal`（`feed_rules` 给法杖）和 `forge/effect.json`（附魔） | 要新来源 |
| 「邻居出手就施加」的口 | 108：`adjacency.grant_cells` + `grant_filter` + `grant_rules`（毒箭：`@on_item_fired → @apply_status_poison`，规则以邻居身份跑） | 器官给相邻武器挂状态就用它，一行数据 |
| 「打中后施加」的口 | 175 补充五：`ItemDef.applies: [{"buff", "stacks"}]` → 编译成 `on_damage DEALT landed_only → apply_status` | 器官自己在魔兽身上咬人时用它 |
| 道具的战斗面 | `ItemDef.combat: CombatProfile {base_stats, rules}`；编译器第 6 步按 `def.combat` 打包 | `wild` 就是第二份 `CombatProfile` |
| 编译输入 | `CompileInput`（105）：基线、信力、单位级 mods / rules、按件、轴、种子；`EnemyKit.spec_of` → `compile_board(board_of(content), baseline_of(def, tier))` | 加一个 `wild: bool`，`spec_of` 按 `def.species` 置真 |
| 敌人的包 | `EnemyPlacer.build_content`：`bag_ids` = `def.bags` 非空用它，否则档位的；`GridInventory(size, 0, not bag_ids.is_empty())`；`EnemyKit.board_of` 老内容没包就 `requires_bag false` 直接摆 | 「没有包」这条路**已经通**（084 之前的老路），只差一个显式开关 |
| 组装 | `choose_items`：招牌 → 流派池 → 通用池 → 同信仰 → `_ensure_weapons`（至少一件带 `weapon` 标签，否则换）；`item_tags` 是身份篓子 | 魔兽：招牌 = 它的器官，`item_tags` 只放 `beast_part`，`loadout` 覆盖 `min_weapons 0`（兽牙不是 `weapon`） |
| 已有兽材 | `beast_hide` 3×2、`wolf_heart` 1×1、`viper_gland` 1×1（已有 on_status_applied poison → 剧毒）、`antler` L 形、`beast_tusk_root` 1×2、`fine_fur` | 全是【自然】材料，补 `wild` 就能长在魔兽身上 |
| 标签 | material 类有 `flesh` / `bone` / `leather`；没有「兽材」「器官」词 | 加一个用途标签 `beast_part`【兽材】（209 的猎囊收它） |

## 2 规则

### 2.1 一件道具两套逻辑：`ItemDef.wild`

- `wild: CombatProfile`（分组「魔兽持有」）：魔兽（`species != human`）自己持有这件时，**用它代替 `combat`**；`adjacency` / `applies` / `faith_bonuses` 在魔兽身上**不生效**（魔兽没有邻接、没有信仰）。null = 魔兽持有时和玩家一样（护板这种两边一样的就不写）。
- `wild_applies: Array[ElementApply]`：魔兽持有时的「打中后施加」（火焰腺咬人附灼伤）。写法同 `applies`。
- 编译器：`CompileInput.wild: bool`；第 6 步打包 `profile := def.wild if inp.wild and def.wild != null else def.combat`；`inp.wild` 为真时跳过第 4b（信仰）、第 5 步邻接只给 `social` 里非魔兽… 简化为：**魔兽棋盘不跑邻接、不跑信仰、不跑 `applies`，跑 `wild_applies`**。预览（地图屏敌人浮窗）和真打同一份 `spec_of`，所以一致。
- `EnemyKit.spec_of`：`CompileInput.of(baseline_of(…))` 后 `inp.wild = def.species != &"human"`，改调 `compile(board, inp)`。
- 悬浮窗：玩家看自己背包里的器官，只写玩家面；看敌人棋盘（战前 / 回放）写 `wild` 面，前面加一行「魔兽的器官」。`Glossary` 不另开。

### 2.2 魔兽：`EnemyDef.species` 与 `bagless`

- `species: StringName = &"human"`（`beast` / `construct`，210 用后者）；`bagless: bool = false`。
- `bagless` 为真：`build_content` 不摆包、棋盘 `requires_bag false`，道具直接摆（老路）；`board_of` 不变（本来按有没有包判）。
- 掉落：第一段照旧（器官各掷）；209 的第二段「掉包」对 `bagless` 敌人**不掷**（狼不会掉皮革包）；尸体容器自由摆（209 §2.4 的「散在包外」就是全部）。
- 流派：魔兽的 `schools` 写元素标签（`fire` / `ice`…，`element` 类已有 `fire` / `poison` / `bleed`；`ice` / `lightning` 按 171 的大类补注册为 element 标签），`item_tags: ["beast_part"]`，`loadout` 覆盖 `{"min_weapons": 0, "common_tags": [], "school_share": 1.0, "single_faith": false}` —— 补件只从带它元素标签的兽材里抽。
- 信仰：魔兽不信神（`single_faith false`），它身上的东西没有 `faith` 标签。
- 地图屏浮窗摘要（`EnemyKit.summary`）照旧；名字前不加「魔兽」字样 —— 名字本身是「焰狼」。

### 2.3 器官与兽材（玩家面 / 魔兽面）

六件新器官 + 六件已有兽材补 `wild`。全部【自然】（`nature`），加 `beast_part`；元素器官另带元素标签（是流派键，不是来源 —— 火焰腺不是【魔法】）。玩家面的「相邻武器施加」用 108 的 `grant_rules`（出手即施加，和毒箭同），魔兽面用 `wild` + `wild_applies`。数值是起点。

| id | 名 | 形 | 稀有度 | 玩家持有 | 魔兽持有（`wild`） |
|---|---|---|---|---|---|
| `fire_gland`（新） | 火焰腺 | 1×1 | 2 | 增益格上下各一（`grant_cells [[0,-1],[0,1]]`，`grant_filter ["weapon"]`）：邻居每次出手施加 1 层灼伤 | on_schedule 1.5 s、耐力 4：4 火伤，`wild_applies` 灼伤 1 |
| `frost_gland`（新） | 霜腺 | 1×1 | 2 | 同上，施加 1 层寒冷 | on_schedule 2 s、耐力 4：3 冰伤，寒冷 1 |
| `shock_sac`（新） | 电囊 | 1×1 | 2 | 同上，施加 1 层麻痹 | on_schedule 1.2 s、耐力 3：2 雷伤，麻痹 1 |
| `beast_fang`（新） | 兽牙 | 1×1 | 1 | 增益格两侧：相邻近战武器 `damage` +1；材料（骨） | on_schedule 1.6 s、耐力 4：6 物理 |
| `beast_claw`（新） | 兽爪 | 1×2 | 2 | 增益格两侧：相邻武器 `crit_chance` +0.05 | on_schedule 1.2 s、耐力 4：4 物理，`wild_applies` 流血 1 |
| `beast_tail`（新） | 兽尾 | 1×2 | 1 | 材料（皮）、`trophy` | on_schedule 3 s、耐力 6：8 物理（横扫） |
| `beast_hide`（已有） | 生兽皮 | 3×2 | 1 | 不变（材料） | `base_stats {"max_hp": 15}` |
| `fine_fur`（已有） | 上等毛皮 | — | — | 不变 | `base_stats {"max_armor": 6}` |
| `wolf_heart`（已有） | 狼心 | 1×1 | 2 | 不变 | `base_stats {"regen_hp": 1}` |
| `viper_gland`（已有） | 蝰蛇毒腺 | 1×1 | 3 | 不变（中毒时附剧毒） | on_schedule 2 s、耐力 3：3 毒伤，`wild_applies` 中毒 2 |
| `antler`（已有） | 鹿角 | L | 1 | 不变 | on_schedule 2.4 s、耐力 5：9 物理 |
| `beast_tusk_root`（已有） | 巨兽獠牙根 | 1×2 | 2 | 不变 | on_schedule 2.8 s、耐力 6：14 物理 |

- 宏：`@apply_status_scorch` / `@apply_status_chill` / `@apply_status_numb`（照 `@apply_status_poison` 的样子登记在导入器宏表）。
- 玩家从哪拿：魔兽掉（第一段按稀有度掷，器官稀有度 1～2 掉率 0.45～0.3）；搜索池照常（`reagent`）；商店照常。
- 美术：6 张新图 + @2x；兽材已有图不动。随本篇派 美术设计。

### 2.4 首批五种魔兽（`species: beast`、`bagless: true`）

| id | 名 | 本色档 | 基线 | 招牌（必带） | 流派键 | 棋盘 |
|---|---|---|---|---|---|---|
| `flame_wolf` | 焰狼 | 1 | max_hp 36、regen_stamina 5 | `beast_fang` ×2、`fire_gland`、`beast_hide` | fire | 4×3 |
| `frost_toad` | 霜蟾 | 1 | max_hp 44 | `frost_gland` ×2、`beast_hide` | ice | 4×3 |
| `shock_eel` | 电鳗 | 2 | max_hp 40、regen_stamina 6 | `shock_sac` ×2、`beast_tail` | lightning | 5×3 |
| `pit_viper` | 坑蝰 | 1 | max_hp 30 | `viper_gland`、`beast_fang` ×2 | poison | 4×3 |
| `cave_bear` | 穴熊 | 3 | max_hp 90、block 2（天生） | `beast_claw` ×2、`beast_hide` ×2、`beast_tusk_root` | bleed | 6×4 |

- 招牌写满了件数，档位 `item_count` 多出来的从同元素兽材里补（如焰狼 2 档多一颗 `fire_gland`）；`stat_scale` 照档位乘。
- 进池：`standard_ruins` 加五条（`kinds: ["outskirts", "ruins"]` 给前三，熊 `depths` 起，权重各 1～1.5）；猎手池不放（猎手是人）。
- 携带品（126）：`carry_rules` 对魔兽**不掷**（魔兽不揣金器）—— `build_content` 里 `species != human` 跳过 carry。

### 2.5 和已有系统的接口

- 反应（175）：灼伤 / 寒冷 / 麻痹是元素印，魔兽咬出来的印和法杖打出来的同一张反应表 —— 焰狼 + 玩家的毒 = 爆燃，这是本篇的「流派」收益。
- 狩猎之神（`hunt`）的事迹：看 `deeds` 里有没有「击败魔兽」一类 —— 没有就不加（不在本篇）。
- 图鉴：器官按玩家面写；魔兽进「敌人」页（图鉴有敌人页的话，照人类敌人）。

## 3 改动

| 文件 | 改什么 |
|---|---|
| `core/inventory/item_def.gd` | `wild: CombatProfile`、`wild_applies: Array[ElementApply]` |
| `core/battle/compile_input.gd`、`compiler.gd` | `wild` 开关；魔兽棋盘跳信仰 / 邻接 / applies，用 `wild` + `wild_applies` |
| `core/enemies/enemy_def.gd` | `species`、`bagless` |
| `core/enemies/enemy_kit.gd` | `spec_of` 置 `wild`；`summary` 不变 |
| `core/enemies/enemy_placer.gd` | `bagless` 不摆包；魔兽不掷携带品 |
| `core/loot/drop_resolver.gd` | 209 的 `roll_bags` 对 `bagless` 不掷（和 209 一起落，谁先落谁留口） |
| `core/authoring/content_importer.gd` | 三个宏；`wild` 校验（规则不许 costs 以外的东西同 combat）；`species` 枚举；`beast_part` 标签注册；`ice` / `lightning` 标签补为 element 类 |
| `data/authoring/tags/beast_part.json`（新）、`ice.json` / `lightning.json`（新，element 类） | — |
| `data/authoring/items/`：6 新 + 6 补 `wild` | §2.3 |
| `data/authoring/enemies/`：5 新 | §2.4 |
| `data/authoring/enemy_pools/standard_ruins.json` | 加五条 |
| `ui/inventory/item_tooltip.gd` | 看敌人棋盘时写 `wild` 面 |
| `core/authoring/id_aliases.gd` + snapshot | 新道具 / 新敌人 |
| `docs/architecture.md` 4.2（两套逻辑一段）、6.0（魔兽一段） | — |
| `tests/battle/test_wild_profile_212.gd`、`tests/enemies/test_beasts_212.gd`（新） | §5 |

## 4 待定（按推荐派执行）

| # | 问题 | 推荐 |
|---|---|---|
| 4.1 | 两套逻辑：同一个定义加 `wild`，还是另一套 `*_wild` 道具 | **同一个定义**（图鉴 / 掉落 / 快照 / IdAliases 都只有一件；掉下来不用换 id） |
| 4.2 | 魔兽棋盘要不要跑邻接 | **不跑**（器官挨着也不加成；魔兽的强弱全在 `wild` 数值和件数） |
| 4.3 | 魔兽掉不掉包（209） | **不掉** |
| 4.4 | 器官的玩家面：出手即施加（108 `grant_rules`）还是打中才施加 | **出手即施加**（和毒箭一致；`grant_rules` 只认 `on_item_fired`） |
| 4.5 | 魔兽的耐力 | **照人**（基线 50 / 回 4，个别写 `regen_stamina`）：耗尽耐力的节奏对魔兽同样成立，211 的「糟糕组合」也靠它 |
| 4.6 | 火焰腺归【自然】还是【魔法】 | **自然**（它是器官；「魔法相关」指晶石这类） |

## 5 测试

1. 编译：同一块棋盘放 `fire_gland` + 匕首，`wild false` → 匕首带「出手施加灼伤」附加规则、腺体自己不出手；`wild true` → 腺体自己 on_schedule 出手 4 火伤 + 灼伤，匕首没有附加。
2. `wild` 为真时信仰加成、`applies`、邻接都不算（放一件赐福盾 + 晶石法杖对照）。
3. 魔兽组装：`flame_wolf` 1 档 → 棋盘 `requires_bag` 假、没有包、招牌四件都在、`_ensure_weapons` 不替换；2 档多出来的件来自带 `fire` 的兽材。
4. 掉落：焰狼死 → 第一段按稀有度掷器官；`roll_bags` 不调（spy）；尸体容器自由摆。
5. 携带品：魔兽内容里没有 `carried: true`。
6. 导入：`wild` 写在 `is_bag` 上 → warn；`species` 写错 → error；三个宏展开正确。
7. 反应：焰狼咬玩家（灼伤 2 层）+ 玩家中毒 → 玩家身上触发爆燃（现有 `test_reactions_175` 的方式）。
8. 悬浮窗：战前准备屏看焰狼的 `fire_gland` → 文案含「魔兽的器官」与 wild 面。

## 6 不做

- 不做魔兽专属行为（逃跑、群体）；它就是一块没有包的棋盘。
- 不做「驯服」「魔兽图鉴页」。
- 不改三个状态的数值（175 补充四定的）。
- 不动锻造附魔的施加。
