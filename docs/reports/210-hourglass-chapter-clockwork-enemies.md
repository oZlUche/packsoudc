# 210 沙漏地图实装为第二张图：章节「机关沙漏」+ 机关敌人系列（天生格挡 = 固定减伤）

> 架构设计 thread · 2026-10-19 · 提案（作者 21:30 夜间六条之四：「实装沙漏地图，作为地图列表的第二选项；主题为机关敌人，增加新系列的敌人，以拥有固定减伤为特性（设计成被动技能或者特殊道具，参考第六条）」）。待定按推荐派执行。依赖 212 的 `species` / `bagless` / `wild`（212 先落或一起落）。底图与宝箱皮肤随本篇派美术。

## 0 一句话

沙漏生成器（`hourglass`，078）早就能出图、过校验、有布局、编辑器里可选，只是**没有一章用它**。本篇加一章 `clockwork_hourglass`「机关沙漏」：开局屏第二张（`order 4`，魔法废墟之后，序章三通关解锁），横置沙漏、出生在左、两个撤离点 + 一个核心在右；一个新敌人池 `clockwork`：五种机关（`species: construct`、没有包，身上是齿轮臂、蒸汽阀、铆接护板这类零件）+ 两种人（钟表匠学徒、守钟人，背包和掉包都靠他们）。「固定减伤」= **天生格挡**（`base_stats.block`，153 的格挡层「天生」那一层，直接减直接伤害）+ 零件里的护板（`shield` 标签，玩家拿到就是一面小盾）；机关不流血不中毒。

## 1 现状（核过）

| 事 | 现在 | 用得上 |
|---|---|---|
| 生成器 | `MapGeneratorRegistry`：`ring` / `grid_script` / `hourglass` / `tower`；`HourglassMapConfig`（width / half_rows / neck_rows / neck_lanes / fill / entry_count / exit_count / with_core / forward_reach / 断边概率 / `danger_by_row` / `rules: LatticeTypeRules`）；`LatticeMapGenerator` 铺点连边分档定类校验；`LatticeMapLayout` 横排；`tests/map/test_lattice_maps.gd` 五组绿 | 全在，只差一章引用 |
| 章节 | `ChapterDef.map_source`（`generator_id` + `generator_config`，导入器校验配置类对得上）；开局屏 `map_chapters()` 列 `hidden_by_unlock` 为空的章按 `order`；`free_mode` order 3、`requires_unlock prologue3_done` | 新章 order 4、同一把锁 |
| 规模档 | `MapSource.scale_options()` 只认有 `scales` 的配置（环形）；别的返回空，开局屏不画规模按钮，`ring_levels` 返回 0 | 沙漏没有规模档，一张图一种大小（待定 4.2） |
| 敌人池按图过滤 | `EnemyPoolEntry.fits`：`min_danger`、`node_types`、`kinds`（读 `node.layout.kind`，**格阵的点没有 kind**） | 新池只用 `node_types` + `min_danger`；档位靠深度（`depths_of` BFS，格阵照样算） |
| 固定减伤 | `block`（153）：盾牌专属，每面盾一层只取最高；**基线里的 `block` 是「天生」一层**（蛮兵 3、核心守卫 5）；`DamageResolver` 第 4 步直接减；非盾道具写 `block` 导入 error | 机关用基线 `block` 做「被动」，护板带 `shield` 标签做「道具」，两条都不改规则 |
| 状态免疫 | 没有；`CombatantRuntime.apply_buff` 直接叠 | 加一个免疫表（见 §2.4） |
| 已有零件 | `brass_gear` 黄铜齿轮（材料 工艺 金属）、`battery` 电池（`sealed` + `part`，max_mana 20）、`armor_plate` 防弹装甲（`sealed` `gear_plug`，给相邻护甲 +5 护甲上限） | 齿轮直接当掉落材料；电池 / 装甲是 `sealed`（枪械线的），不混 |
| 美术 | 底图 `assets/maps/<id>.png + .json`（`tone`、`safe_area`），现有 ruins / north_woods / cursed_depths / imperial_camp；宝箱皮肤同名四套 | 新底图 `clockwork`、宝箱皮肤先用 `imperial_camp` |

## 2 规则

### 2.1 章节 `clockwork_hourglass`「机关沙漏」

```json
{"id": "clockwork_hourglass", "display_name": "机关沙漏", "display_names": {"en": "Clockwork Hourglass"},
 "order": 4, "requires_unlock": "prologue3_done",
 "map_source": {"generator_id": "hourglass", "generator_config": {"type": "HourglassMapConfig",
   "width": 5, "half_rows": 4, "neck_rows": 2, "neck_lanes": 2, "fill": 0.75, "entry_count": 2,
   "exit_count": 2, "with_core": true, "forward_reach": 1, "lateral_span": 1,
   "forward_break_chance": 0.3, "lateral_break_chance": 0.35,
   "danger_by_row": [0, 0, 1, 1, 2, 2, 1, 1, 1, 0],
   "rules": {"type_weights": {"battle": 3, "search": 3, "event": 2, "random": 2, "elite": 1, "chest": 1},
             "quota": {"shop": [0, 1], "rest": [0, 1], "elite": [0, 2]}, "coverage": {"rest": 4, "shop": 6},
             "no_haven_in_danger_above": 1, "extract_rows": []}}},
 "enemy_pool": "clockwork", "drop_rule": "standard", "carry_rule": "standard", "bag_pool": "standard",
 "encumbrance_rules": "standard", "node_rules": "standard", "economy_rules": "standard",
 "step_limit": 40, "safes": 1, "carry_budget": 600,
 "chest_skin": "imperial_camp", "map_skin": "clockwork",
 "rules": ["横置的沙漏：从左边进去，穿过中间两条窄道到对侧；撤离点只在最右一列，中途没有。",
           "这里的敌人是机关：天生格挡，直接伤害先减一截；流血和中毒对它们无效，火、冰、雷照常。",
           "机关身上掉零件：齿轮臂、蒸汽阀、铆接护板。护板拿回来就是一面小盾。"]}
```

- 十层（4 + 2 + 4），颈部两层只有两条线段，危险等级颈部 2。`with_core true`：对侧正中一个核心（BOSS 大钟），两侧各一个撤离点（`exit_count 2` 对称，不和正中撞）。
- 全局倒计时 40 步（十层横穿约 12～16 步，留搜索与绕路的余量）；带入预算 600 同自由模式。
- 不写 `scales`；开局屏那页没有规模按钮（待定 4.2）。
- 规则卡三条（导入器上限 3）。

### 2.2 敌人池 `clockwork`

```json
{"id": "clockwork", "display_name": "机关池",
 "entries": [
   {"enemy": "clockwork_sentry", "weight": 3},
   {"enemy": "steam_turret", "weight": 2, "node_types": ["battle", "elite"]},
   {"enemy": "gear_golem", "weight": 2, "min_danger": 1},
   {"enemy": "pendulum_warden", "weight": 2, "node_types": ["elite"], "min_danger": 1},
   {"enemy": "great_clock", "weight": 1, "node_types": ["core"]},
   {"enemy": "tinker_apprentice", "weight": 2},
   {"enemy": "clock_keeper", "weight": 1.5, "min_danger": 1}
 ],
 "tiers": [同 standard_ruins 的四档；人类档位 bag_count 照 209，机关 bagless 不看],
 "strength_rule": {"type_bonus": {"elite": 1, "core": 1}, "steps_per_tier": 10, "searches_per_tier": 4},
 "loadout": {"common_tags": ["gear", "remedy", "food", "part", "tool"]},
 "combat_types": ["battle", "elite", "core"]}
```

### 2.3 机关系列（`species: construct`、`bagless: true`、`item_tags: ["clockwork"]`、`loadout` 覆盖 `min_weapons 0 / common_tags [] / single_faith false`）

「固定减伤」两条路同时用：基线 `block`（被动，天生一层）+ 护板零件（道具，`shield` 标签一层）。153 规则：几层只取最高，所以护板比天生高时顶替、不相加 —— 玩家打穿护板（拿走 / 它碎了）机关就回到天生那一层。

| id | 名 | 本色档 | 基线 | 招牌 | 流派键 | 棋盘 |
|---|---|---|---|---|---|---|
| `clockwork_sentry` | 发条哨兵 | 0 | max_hp 30、block 2 | `gear_arm`、`brass_plating` | clockwork | 4×3 |
| `steam_turret` | 蒸汽炮台 | 1 | max_hp 34、block 3、regen_stamina 6 | `steam_vent` ×2、`brass_plating` | fire | 4×3 |
| `gear_golem` | 齿轮傀儡 | 2 | max_hp 70、block 4 | `gear_arm` ×2、`brass_plating` ×2、`mainspring` | clockwork | 6×4 |
| `pendulum_warden` | 钟摆卫士 | 3 | max_hp 80、block 5 | `pendulum_blade`、`brass_plating` ×2、`mainspring` | burst | 6×4 |
| `great_clock` | 大钟（核心） | 3 | max_hp 140、block 6 | `pendulum_blade` ×2、`steam_vent` ×2、`brass_plating` ×3、`mainspring` ×2 | burst / fire | 8×5 |

人类两种（有包、掉包、有携带品，207 / 209 / 211 的规则对他们全生效）：

| id | 名 | 本色档 | 基线 | 身份标签 | 招牌 | 流派 |
|---|---|---|---|---|---|---|
| `tinker_apprentice` | 钟表匠学徒 | 1 | max_hp 32 | tool / part / gun / rapid / remedy | `pistol`、`tool_roll`（包，209） | rapid |
| `clock_keeper` | 守钟人 | 2 | max_hp 48、block 2 | imperial / shield / melee / rapid / remedy | `shortsword`、`brass_plating` | rapid |

### 2.4 机关零件（【工艺】`crafted` + `metal` + `clockwork`，`part`；玩家面 / 机关面）

| id | 名 | 形 | 稀有度 | 玩家持有 | 机关持有 |
|---|---|---|---|---|---|
| `gear_arm`（新） | 齿轮臂 | 1×2 | 1 | 材料；增益格两侧：相邻武器 `haste` +10% | `wild`：on_schedule 2 s、耐力 5：10 物理 |
| `steam_vent`（新） | 蒸汽阀 | 1×1 | 2 | 增益格上下：相邻武器出手施加 1 层灼伤（和 212 火焰腺同形，工艺版） | `wild`：on_schedule 1.5 s、耐力 4：3 火伤，`wild_applies` 灼伤 1 |
| `brass_plating`（新） | 铆接护板 | 1×2 | 1 | **盾**：`shield` + `heavy`，`base_stats {"block": 2}`，重 | 同玩家面（不写 `wild`）：给机关一层格挡 2（比天生低就备用） |
| `mainspring`（新） | 主发条 | 1×1 | 2 | `part`：`base_stats {"max_stamina": 10}` | `wild`：`base_stats {"regen_stamina": 2}` |
| `pendulum_blade`（新） | 钟摆刃 | 1×3 | 2 | 武器 `melee` / `burst` / `heavy`：on_schedule 2.6 s、耐力 9：20 物理 | 同玩家面 |
| `brass_gear`（已有） | 黄铜齿轮 | 1×1 | 2 | 不变（材料） | 机关的携带品替身：`build_content` 对 construct 不掷 `carry_rules`，改为招牌之外**必带 1～2 个齿轮**（`EnemyDef.loot_filler: ["brass_gear"]`，计入件数、`carried: true` 必掉） |

### 2.5 机关的免疫（`EnemyDef.immune_buffs`）

- `immune_buffs: Array[StringName]`（机关：`["bleed", "poison", "fungal_blood", "scorched_blood"]`）→ `CombatantSpec.immune_buffs` → `CombatantRuntime.apply_buff` 开头：在表里就返回 0（`BattleEvent.STATUS_STACKED` 不发；追踪记一条 `immune`）。
- 反应表（175）照常：免疫的印不存在，相关反应自然不发生。
- 悬浮窗 / 战前准备屏敌人面板：一行「免疫：流血、中毒」。

### 2.6 其它

- 侵蚀：`erosion_reversed false`（从出生那侧开始），撤离点在对侧所以越拖越只能往前 —— 沙漏的张力就在这。
- 猎手（069 / 071）：这一章先不放猎手（`hunters` 池按 `kinds` 过滤，格阵没有 kind；要放另议）。
- 美术：底图 `assets/maps/clockwork.png + .json`（深色调、齿轮 / 钟面纹样，中间横向留白给横排的路网，`safe_area` 按横置给）；宝箱皮肤先借 `imperial_camp`；五件新零件图 + @2x。随本篇派 美术设计。

## 3 改动

| 文件 | 改什么 |
|---|---|
| `data/authoring/chapters/clockwork_hourglass.json`（新） | §2.1 |
| `data/authoring/enemy_pools/clockwork.json`（新） | §2.2 |
| `data/authoring/enemies/`：7 新 | §2.3 |
| `data/authoring/items/`：5 新零件 | §2.4 |
| `data/authoring/tags/clockwork.json`（新，origin 类【机关】） | — |
| `core/enemies/enemy_def.gd` | `immune_buffs`、`loot_filler`（212 的 `species` / `bagless` 一起） |
| `core/enemies/enemy_placer.gd` | construct 不掷携带品，改 `loot_filler` 必带 1～2 |
| `core/battle/combatant_spec.gd`、`compile_input.gd`、`compiler.gd`、`combatant_runtime.gd` | 免疫表一路传到 `apply_buff` |
| `core/enemies/enemy_kit.gd` | `baseline_of` 不变；`spec_of` 带免疫表 |
| `ui/battle/combatant_panel.gd` / 战前准备屏敌人面板 | 「免疫：…」一行 |
| `ui/game/setup_screen.gd` | 没有规模档的章：那一页规模按钮区隐藏（现在可能画个空容器，执行核一下） |
| `assets/maps/clockwork.json`（占位：`tone dark`，先指向 `ruins.png` 直到美术交图） | — |
| `core/authoring/id_aliases.gd` + snapshot | 新道具 / 敌人 / 章节 |
| `docs/architecture.md` 5.11（加「第一次用上」一句）、6.0（机关） | — |
| `tests/map/test_hourglass_chapter_210.gd`、`tests/enemies/test_clockwork_210.gd`（新） | §5 |

## 4 待定（按推荐派执行）

| # | 问题 | 推荐 |
|---|---|---|
| 4.1 | 对侧放不放核心（BOSS） | **放**（`with_core true`）：有 BOSS 才有 087 的保底金色和「打赢直接撤离」；两个撤离点仍在，不想打也能走 |
| 4.2 | 沙漏要不要规模档 | **不要**：一张图一种大小，少一页按钮；要大图再加 `HourglassMapConfig.scales` |
| 4.3 | 机关免疫流血 / 中毒 | **免疫**（主题；火 / 冰 / 雷照常所以法杖线有用） |
| 4.4 | 固定减伤走天生格挡还是新属性 | **天生格挡**（153 已有、规则清楚、玩家认得「格 N」） |
| 4.5 | 这一章放猎手 | **先不放** |
| 4.6 | 宝箱皮肤 | 先借 `imperial_camp`，美术有空再画 |

## 5 测试

1. 章节导入：`generator_id hourglass` + `HourglassMapConfig` 过校验；`map_chapters()` 里它排第二（order 4）；`prologue3_done` 没解锁时锁着。
2. 生成：固定三个种子各生成一次，`layout_kind hourglass`、10 层、核心在最后一层正中、两个撤离点在最后一层、`goal_from_all` 过；节点 `danger` 按 `danger_by_row`。
3. 池：`fits` 不看 kind；`core` 点只出 `great_clock`；`elite` 出钟摆卫士或炮台；深度越深 `wanted_strength` 越高。
4. 机关：`clockwork_sentry` 棋盘无包、`requires_bag` 假；基线 `block 2` 成一层「天生」；带 `brass_plating` 时 `block_layers` 两层、生效的是高的那层；拿掉护板后回到 2。
5. 免疫：对傀儡 `apply_buff(bleed)` 返回 0、不发 STATUS_STACKED；`apply_buff(scorch)` 正常；燃血（`scorched_blood`）不叠。
6. 零件：玩家拿 `brass_plating` 编译出一层格挡 2、`ItemWeight` 按 heavy；`gear_arm` 玩家面相邻武器 haste +10%、机关面自己出手。
7. 掉落：哨兵死 → 第一段掷零件，`brass_gear` 必掉（carried），`roll_bags` 不调；学徒死 → 照 209 掷包。
8. 开局屏：选到这一章时规模按钮区不显示、步数读数 40。

## 6 不做

- 不做塔（`tower`）那一章 —— 等作者要。
- 不做机关专属行为（充能、过热）；`mainspring` 就是回耐力。
- 不做新的减伤属性。
- 不动 078 的生成器与校验。

## 8 落地（2026-10-19，v3.52）

按 §2 / §3 落了，待定全按推荐。差异：

1. **钟表匠学徒的招牌换成匕首**：`pistol` 是封存的枪械线（导入器拦），`tool_roll` 是 209 的包（招牌不许放包）。身份标签去掉 `gun`、加 `clockwork`（能背齿轮臂 / 主发条）。209 落地后学徒照 209 掷包。
2. **钟摆刃伤害 20 → 30**：20 点 / 2.6 秒的战斗力估算只够稀有度 0（151 导入警告），提到 30 才配得上稀有度 2；仍低于战锤。
3. **章节没写 `bag_pool`**：这个字段是 209 的，209 落地时补上。
4. **底图已经是美术的定稿**：`/mnt/project-files/art/maps/clockwork.png + .json` 已经交了（`tone dark`，横向 `safe_area`），直接拷进 `assets/maps/`，没有用占位。
5. **免疫在 `ApplyStatus.give` 最前面先问一句**：免疫的印不会走进反应表，所以「身上有灼伤、中毒打上来」不会引发爆燃；`apply_buff` 自己也拦（燃血这类反应直接挂的状态），追踪记一笔 `immune`。
6. **掉落测试只测了「齿轮必带、没有别的携带品」**：`roll_bags` 是 209 的，「机关不掷包」在 209 落地时补。
7. 开局屏：没有规模档的章本来就不画规模按钮（`scale_options_of` 返回空），不用改代码。
8. 五件零件的图：美术设计的草稿在 `art/items/drafts1/out/`，没有进 `assets/items/manifest.json`。定稿后按 201 拷文件即可，不用改代码。
9. **开局屏第三页的预览还是同心环的那套**：入口印记（182）只会画同心环，沙漏这一张在第三页只铺底图、不画入口，「出发」不灰；进图后在地图屏上挑左边的出生点（地图屏原来那条挑出生点的路）。要在第三页也挑，得给 `MapPreview` 加格阵布局，另议。
