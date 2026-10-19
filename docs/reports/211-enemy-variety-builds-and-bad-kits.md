# 211 敌人更多、流派更清楚：命名「套路」（`builds`）—— 成套的好组合，也有刻意的糟糕组合

> 架构设计 thread · 2026-10-19 · 提案（作者 21:30 夜间六条之五：「原本的敌人种类也要增加，并加上不同流派，增加道具组合，甚至可以是糟糕的组合（比如一下子就将耐力用光，或者根本不成套）」）。待定按推荐派执行。和 210 / 212 的新敌人并行（数据层互不依赖）。

## 0 一句话

现在敌人身上的东西是**抽**出来的（招牌 → 流派池 → 通用池 → 至少一件武器），所以每个敌人都「差不多合理」，既没有真正成套的狠角色，也没有真正拉胯的倒霉蛋。本篇给 `EnemyDef` 加 `builds`：几套**写死的道具组合**，各带权重与档位范围，组装时按概率先选一套当骨架，不够的件数再照旧抽补；套路可以标 `quality: "bad"`（低档才出、权重另算），数据里直接写「两把 12 耐力的重武器 + 55 耐力」这种一上来就喘不过气的组合，或者「弓没箭、符号没刀」的散件。再加八种人类敌人（刺客 / 猎人 / 巫医 / 盾卫 / 学徒法师 / 狂战士 / 拾破烂的 / 走私贩），流派键照旧是标签，不加代码。

## 1 现状（核过）

| 事 | 现在 | 用得上 |
|---|---|---|
| 敌人 | 10 种（拾荒者 / 神射手 / 屠夫 / 蛮兵 / 守卫 / 核心守卫 / 重击手 / 持符者 / 游兵 / 药师），`schools` 多数一两个键，`item_tags` 身份篓子，`signature` / `signature_by_strength`，`combos`（165 相邻组合） | 全保留 |
| 流派键 | 道具标签：rapid 8 件 / burst 5 / bleed 8 / poison 8 / ranged 3 / magic 4（晶石 + 法杖）/ shield 3 / heavy 2 | 「新流派 = 几件道具打标签 + 一个带标签的敌人」（`enemy_def.gd` 开头的话）仍成立；`magic` 能直接当流派键 |
| 组装 | `choose_items`：招牌 → `school_share`（默认 0.5）抽流派池 → 通用池 → `_unify_faith` → `_ensure_weapons(min_weapons 1)`；`build_content`：件数 = 档位 `item_count` 随机，包先摆，`_arrange` 按 `combos` / `auto_groups` 成组摆 | 套路插在「招牌之后、抽之前」 |
| 耐力 | 基线 50、每秒回 4；重武器 9～12 耐力一下（长剑 9、撬棍 / 战锤 12），轻的 3～5 | 「一下子用光」= 两件 12 的：第一轮 24，之后每 3 秒才攒够一下 —— 数据写得出来 |
| 预览 | 地图屏敌人浮窗 `EnemyKit.summary`（名字、生命、几件、都是什么），不写档位 / 流派（2026-10-17 作者定） | 套路名不给玩家看；玩家看见的是「两把战锤」自己判断 |
| 数据管线 | `EnemyDef` 是 Resource，`data/authoring/enemies/*.json` → `.tres`；嵌套数组走 `Array`（165 `combos` 的写法） | `builds` 同样写法 |

## 2 规则

### 2.1 `EnemyDef.builds`：命名套路

```json
"builds": [
  {"id": "twin_hammers", "weight": 2, "strength": [0, 1], "quality": "bad",
   "items": ["warhammer", "warhammer", "ration"],
   "note": "两把 12 耐力的锤：开场两下，然后每三秒一下"},
  {"id": "bow_no_arrows", "weight": 1, "strength": [0, 0], "quality": "bad",
   "items": ["longbow", "bandage", "bandage", "ration"],
   "note": "弓没箭：长弓本身能打，但 108 的箭矢加成一份也没有"},
  {"id": "shield_wall", "weight": 2, "strength": [1, 3],
   "items": ["round_shield", "shortsword", "armor", "salve"]}
]
```

- `items`：**除招牌以外**的骨架（招牌照 `signature_at` 另算，先占位）。可重复。认不得的 id 导入 error。
- `strength: [min, max]`：这套只在这个档位区间出现。
- `weight`：同档可用的套路之间按权重抽。
- `quality`：`"good"`（默认）/ `"bad"`。`bad` 的权重再乘池里的 `bad_build_mult`（`EnemyLoadout.bad_build_mult: float = 0.5`，高档 `strength ≥ 2` 时再 ×0.5 —— 深处的敌人少犯傻）。
- `note`：给作者 / 测试看的一句话，不进游戏。
- 选不选套路：`EnemyLoadout.build_chance: float = 0.6`（池级默认，敌人 `loadout` 可覆盖）。掷中就选一套；没掷中、或没有本档可用的套路 → 老路全抽。
- 套路选中后：`items` 先放进 picks（受 `rarity_cap` 约束：超上限的件**保留**，因为套路是设计者写的；但导入器 warn 一句），然后 `count − picks.size()` 的余数照旧抽（流派池 / 通用池）；`_unify_faith` 与 `_ensure_weapons` 照旧跑 —— 但 **`quality: bad` 的套路跳过 `_ensure_weapons`**（「根本不成套」就是要没武器也能出现；它只会出在 0～1 档，玩家打一个背着纱布的拾破烂的不冤）。
- 套路里的件一样参与 `combos` / `auto_groups` 的成组摆放（`bow_no_arrows` 没有箭就没得配，摆成散件）。
- 内容里记一笔 `content.build = id`（存档带着；回放 / 测试能看），不进玩家可见的摘要。

### 2.2 新敌人八种（人类，照旧有包、有携带品、掉包走 209）

| id | 名 | 本色档 | 基线 | 流派 | 身份标签 | 招牌 | 套路（节选） |
|---|---|---|---|---|---|---|---|
| `assassin` | 刺客 | 1 | max_hp 30、regen_stamina 5 | rapid / bleed | rapid / bleed / melee / remedy | `knife` | 好：`knife`×2 + `bloodletter` + `bloodlust_bracer`（1～3 档）；坏：`knife`×4（0 档，四把 3 耐力的刀把 50 耐力一瞬间刷完、然后空挥） |
| `tracker` | 猎人 | 1 | max_hp 34 | ranged / bleed | ranged / ammo / bleed / remedy / trophy | 0 档 `shortbow` / 1 档 `longbow` | 好：弓 + `serrated_arrows`×2 + `antler`；坏：`bow_no_arrows` |
| `witch_doctor` | 巫医 | 2 | max_hp 40 | poison | poison / reagent / remedy / tool / herb | `poisoned_knife` | 好：`poisoned_knife` + `viper_gland` + `envenomed_gauntlet` + `antidote_satchel`；坏：`poison_vial`×3 + `bandage`（只有毒药瓶没有刀 —— 瓶子自己会扔但很慢） |
| `shield_wall` | 盾卫 | 2 | max_hp 50、block 2 | rapid / shield | imperial / shield / armor / melee / rapid | `round_shield` | 好：`round_shield` + `shortsword` + `armor` + `salve`；坏：`tower_shield` + `round_shield` + `ration`（两面盾只取最高一层、没武器 —— `quality bad` 跳过保底武器） |
| `apprentice_mage` | 学徒法师 | 2 | max_hp 32、max_mana 30 | magic | magic / crystal / staff / remedy | `magic_staff` | 好：法杖 + 两颗不同晶石（相邻装载格）；坏：法杖 + `fire_crystal`×2 不挨着法杖（`combos` 不写、`auto_groups` 不配 —— 用 `"loose": true` 标这套不成组） |
| `berserker` | 狂战士 | 1 | max_hp 60、max_stamina 55 | burst | barbarian / burst / melee / gear | `scimitar` | 坏：`twin_hammers`（`warhammer`×2，12 耐力一下）；好：`warhammer` + `leather_armor` + `salted_meat`×2 |
| `ragpicker` | 拾破烂的 | 0 | max_hp 24 | — | material / tool / remedy / food | — | 坏：`bandage`×2 + `ration` + `smoked_fish`（没武器；`min_weapons` 被 bad 跳过）；好：`cleaver` + `ration` |
| `smuggler` | 走私贩 | 1 | max_hp 36 | rapid | rapid / melee / tool / treasure | `knife` | 好：`knife` + `spyglass`…（126 的携带品 `count_by_strength` 对他 ×2：`EnemyDef.carry_mult: float = 2.0`，掉的值钱货多） |

- 老的十种各补一两套套路（屠夫：`cleaver` + `bloodletter` + `wound_salt`；蛮兵坏套：`tibia_violence` + `warhammer`；神射手好套：弓 + 箭 + 箭…），数据活，不列全。
- 进池：`standard_ruins` 加八条（拾破烂的 / 走私贩 `kinds outskirts`，巫医 / 盾卫 `ruins` 起，学徒法师 `depths` 起）；`hunters` 池加刺客、猎人。
- 流派键不新增标签：rapid / bleed / poison / ranged / burst / magic / shield 都已有。

### 2.3 `combos` 的小补：`loose`

- 套路里 `"loose": true` → 这套的件**不做**自动成组（`auto_groups` 跳过），摆成散件 —— 「学徒把晶石放错了地方」就是它。

### 2.4 携带品倍率

- `EnemyDef.carry_mult: float = 1.0`：126 的 `count_by_strength` 乘它再取整（走私贩 2.0、210 的机关 0 由 `species` 另管）。

## 3 改动

| 文件 | 改什么 |
|---|---|
| `core/enemies/enemy_build.gd`（新，Resource） | id / weight / strength(Vector2i) / quality / items / loose / note |
| `core/enemies/enemy_def.gd` | `builds: Array[EnemyBuild]`、`carry_mult`；`builds_at(strength) -> Array[EnemyBuild]` |
| `core/enemies/enemy_loadout.gd` | `build_chance`、`bad_build_mult` |
| `core/enemies/enemy_placer.gd` | `choose_items`：招牌之后掷套路、骨架入 picks、余数照抽、bad 跳过 `_ensure_weapons`；`build_content` 记 `content.build`、`loose` 不成组、`carry_mult` |
| `core/authoring/content_importer.gd`、`content_exporter.gd`、`field_text.gd` | 新字段；校验 id 存在、区间合法、超 rarity_cap warn |
| `data/authoring/enemies/`：8 新 + 10 旧补 `builds` | §2.2 |
| `data/authoring/enemy_pools/standard_ruins.json`、`hunters.json` | 加条目 |
| `core/authoring/id_aliases.gd` + snapshot | 新敌人 |
| `docs/architecture.md` 6.0 | 套路一段 |
| `tests/enemies/test_builds_211.gd`（新） | §5 |

## 4 待定（按推荐派执行）

| # | 问题 | 推荐 |
|---|---|---|
| 4.1 | 套路出现概率 | **0.6**（池级），敌人可覆盖 |
| 4.2 | 坏套路的权重 | **×0.5**，`strength ≥ 2` 再 ×0.5 |
| 4.3 | 坏套路要不要保底武器 | **不要**（这是「根本不成套」的意思） |
| 4.4 | 套路名给不给玩家看 | **不给**（2026-10-17 作者定内部读数不给玩家；玩家看件数与名字自己判断） |
| 4.5 | 超出 `rarity_cap` 的套路件 | **保留 + 导入 warn** |

## 5 测试

1. 导入：`builds` 里认不得的 id → error；`strength [2, 1]` → error；超 cap → warn；`quality` 写错 → error。
2. 选套路：`build_chance 1.0`、`twin_hammers` 唯一可用 → picks 以两把战锤开头；`build_chance 0` → 老路；1 档可用两套按权重（统计 400 次，坏套约为好套的一半）。
3. 坏套路不补武器：`ragpicker` 的纱布套路 → 没有 `weapon` 标签的件；好套路照旧有。
4. `loose`：学徒的坏套路 → `auto_groups` 为空、晶石不在法杖装载格上；好套路 → 两颗晶石在装载格上（`EnemyPlacer` 现有的成组逻辑）。
5. 余数照抽：套路 3 件、档位件数 5 → 另两件来自流派 / 通用池、受 cap。
6. 耐力：模拟 `twin_hammers` 一场 10 秒，`ITEM_SKIPPED`（103 第 7 条，付不起没出手）≥ 2 条 —— 真的喘不过气。
7. 内容：`content.build == "twin_hammers"`；存档往返保留；老内容没有 `build` 键照旧。
8. `carry_mult`：走私贩携带品件数约为同档拾荒者的两倍（固定种子）。

## 6 不做

- 不做敌人 AI / 行为差异：套路只改背的东西。
- 不做玩家可见的「流派」字样。
- 不做按章节切换套路表（池级 `build_chance` 够了）。
