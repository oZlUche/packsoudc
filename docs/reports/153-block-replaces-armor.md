# 方案：防护改名【格挡】（`block`）—— 盾牌专属的固定减伤，多面盾只取最高（153）

> 作者原话（2026-10-10，架构方案执行）：「ARMOR 属性应该换个名字，比如 BLOCK 格挡，作为盾牌的专属固定值减伤，且只取最高。具体逻辑为：每个盾牌会为持有者添加一层【格挡】buff，这个 buff 是固定值减伤，但只有格挡数值最高的那个生效（保留）。」
>
> 性质：架构 · 提议。本线程只写方案，不实现。待定项默认按推荐。
> 关联：106（防护轴、负值倒贴、直接伤害按来源）、137（buff 叠层只有可叠 / 不可叠两种）、146（buff 是库里的对象）、151（估算器按 `hits_taken` 给防护估值）、152（执行线程：buff 每层带标准轴 —— 弹开 / 久弹 / 标记三条 buff 与导入器对 `armor` mods 的提醒都留给本方案定）。

## 1. 现状（查过的）

`armor` 今天是一条**相加的单位级属性**，所有来源加在一起，再由伤害管线第 4 步减掉：

| 来源 | 在哪 | 现值 |
|---|---|---|
| 盾牌的 `combat.base_stats.armor` | 编译后在 `CombatantRuntime.from_spec` 里按件**求和**进单位表（`default_base` 为 0 的键都求和） | 塔盾 5、圆盾 5、技巧之神赐福的盾牌 15（一阶再 +4） |
| 防具（`armor` 标签） | 全是 `max_shield`，**没有一件给 armor** | 贴身甲 35、皮甲 30、板甲 50、高级贴身甲 50 |
| 三条 buff 的 `mods` | `_rebuild` 里按层加到单位表 | 弹开 +8（4 秒）、久弹 +4（8 秒）、标记 −3（8 秒）；弹开 / 久弹由赐福盾开战施加，标记由狙击枪 / 赐福长弓打中施加 |
| 标准轴 `armor` | 106 加的单位级 FLAT 轴，正名**格挡**、负名破绽，每层 ±1 | 内容里没有谁 `shift_axis(armor)` |
| 敌人基线 `base_stats.armor` | `EnemyDef` → `CombatantBaseline`，再乘档位表 `stat_scale.armor` | 蛮人 3、守卫 4（另有招牌圆盾 5 → 实际 9）、核心守护者 5；档位 ×1.25 / ×1.5 / ×1.75 |
| 信仰赐福按信力加 | 自然 / 大地之神的赐福（标签 `gear / armor / shield`）`scaled` 每份 armor +1，最多 5 份；技巧之神赐福盾 `active` +4 | 落到**那件道具**的属性上（编译第 4b 步） |

文案：`Glossary` 的属性名 `armor` 叫「防护」，词条「防护」「直接伤害」「中毒」「流血」都提到防护；帮助页 `direct_damage_and_armor`（「直接伤害与防护」）；物理伤害类型说明；毒刀配方 note；三条教程事件文字（`{item_stat:tower_shield:armor}`）；回放里的「甲挡 N」（`battle_view.gd:325`）与内部日志的「防护 N」。测试里 28 个文件、106 处提到 armor。

两点现状决定了方案的形状：**内容里 armor 本来就只有盾在给**（防具给的是护盾上限），所以「盾牌专属」不改一件道具；**buff 的 `mods` 是按定义不按实例的**（`BuffInstance` 只有层数，没有「这一份值多少」），而且同 id 只有一个实例（`find_buff`），所以「每面盾一层 buff、只取最高」不能直接用现有 buff 结构表达。

## 2. 规矩（作者定，本方案落成的形式）

1. 属性 `armor` 改名 **`block`【格挡】**（英文 Block）。代码常量、事件载荷、日志、内容键、文案一起改；导入器认旧键 `armor` 并提醒改名（一个版本后删）。
2. **格挡只来自盾牌**：`combat.base_stats.block` 只允许出现在带 `shield` 标签的道具上（导入 error）；信仰赐福里作用于 `block` 的 mod 只能落在盾上（第 5 节）。
3. **每面盾是一层格挡**，层值 = 那面盾编译后的 `block`（含它自己的信力加成）。**只有最高的一层生效，其余保留**：最高那层没了（将来有「盾碎」之类）就轮到次高。
4. **格挡轴**（原 `armor` 轴）保留，仍是单位级 FLAT、每层 ±1，**加在生效的那层之上**：正名改叫**【加固】**（原来叫格挡，和属性本身撞名），负名仍是**【破绽】**，负值照 106 倒贴。
5. 伤害管线第 4 步不变：`amount -= block`，只减直接伤害。变的只是 `block` 怎么算出来。

### 格挡的算法

```
生效层  = max(0, max(各层的值))          # 盾牌各一层；敌人天生一层（第 4 节）
block   = 生效层 + 格挡轴层数（内容层 + 系统层，带符号）
```

- 两面塔盾（5 + 5）：以前 10，现在 **5**。带第二面盾是浪费 —— 这正是作者要的取舍（一面好盾胜过两面破盾）。
- 赐福盾 15 + 一阶 4 = 一层 **19**；开战的弹开改成格挡轴 +8（第 3 节）→ 四秒内 27，和今天一样。
- 守卫：天生 4、圆盾 5 → **5**（以前 9），档位 ×1.5 时天生 6 → 6。要不要补数见第 4 节。
- 标记 −3：以前 5 − 3 = 2，现在同样 2；没盾的敌人中了标记 −3 → 倒贴 3（106 不变）。

## 3. 怎么做

### 3.1 运行时：格挡层（`BlockLayer`）

- `CombatantSpec.block_layers: Array[BlockLayer]`，`BlockLayer { source_uid: int, label: String, value: int }`。编译第 6 步打包时，凡 `item.stats` 有 `block > 0` 的道具各出一层（label = 道具名）；第 8 步若基线有 `block > 0`，出一层 label「天生」。
- `CombatantRuntime.from_spec` 汇总单位表时**跳过 `block` 键**（它不再求和），把 `spec.block_layers` 存下；`_rebuild` 末尾（`_apply_axes` 之后）算 `_merged.block = max 层 + 轴`。`stat(BattleStats.BLOCK)` 的调用方（`DamageResolver`、面板、估算器）一行不改。
- `BuffDef.mods` **不许再作用于 `block`**（导入 error：「格挡只能来自盾牌；临时的加减用格挡轴」）。152 已让 buff 每层带标准轴，所以三条老 buff 直接改写：
  - 弹开：`axes: {block: +8}`，4 秒不可叠 → 显示「加固 ×8」；
  - 久弹：`axes: {block: +4}`，8 秒；
  - 标记：`axes: {block: −3}`，8 秒 → 显示「破绽 ×3」。
  三条还留在 buff 库里（146），是 buff 不是层。`warn_axis_candidate` 对 `block` 的 mods 不必再提醒 —— 它直接是 error。
- 轴表：`StatAxes.ARMOR` → `BLOCK`，`"stat": &"block"`，`pos: "加固"`，`neg: "破绽"`；`what` 表改「格挡（生效的那层之上的固定修正）」。`describe` 的词条与 `test_stat_axes` 的「撞名」自检跟着改。
- 导入器新增两条校验：`base_stats.block` 出现在非盾道具 → error；道具自己的规则里 `shift_axis(block, +n)`（正向）出现在非盾道具 → warn（「加固应来自盾牌」；buff 里的不查，查不了来源）。

### 3.2 内容键与迁移

- JSON 键 `armor` → `block`：9 处 `base_stats`（塔盾、圆盾、赐福盾；敌人蛮人 / 守卫 / 核心守护者）、3 处档位 `stat_scale`、3 条 buff（改成 `axes`）、3 处信仰 mods（第 5 节）、赐福盾一阶 mods。`.tres` 由导入重生成。
- 导入器别名：`base_stats.armor` / `stat_scale.armor` / `mods[].stat = armor` / `shift_axis.axis = armor` → 一律当 `block` 读并 warn「`armor` 已改名 `block`」。导出器只写 `block`。
- `TextTemplate` 的 `{item_stat:塔盾:armor}` 同样走别名，三条教程事件改成 `:block`。

### 3.3 显示：玩家看到的【格挡】

作者说的「buff」是玩家看到的东西，不必是 `BuffDef`：

- 回放面板（`CombatantPanel`）加一格**常驻格「格挡 N」**（和「鏖战 ×n」同一类，`BLOCK_CHIP`），N = 当前生效的 `block`；没有任何层也没有轴层时不画。悬浮窗列各层与修正：「塔盾 五 ← 生效」「圆盾 五（备用）」「天生 三」「加固 ×8（弹开）」。层来自 `BattleResult` 里的开战快照（`snapshot` 加 `block_layers`），修正来自已有的 `axis_shifted` 事件。
- 现有的格挡轴格（`axis:block`）**并进这一格**：轴层数不再单独画一格，只在悬浮窗里列出；破绽（负）时常驻格用减益色。
- 战斗日志「甲挡 N」→「格挡 N」；内部日志「防护」→「格挡」；`DamagePacket.armor` → `block`，事件载荷 `"armor"` → `"block"`。
- 背包侧栏 / 开战前的套件摘要若读 `stat(ARMOR)`，跟着常量改名即可，语义自动变成「只取最高」。

### 3.4 文案（玩家可见文本用占位符，不用阿拉伯数字）

- `Glossary` 属性名：`block` → 「格挡」/ Block；词条「防护」改名「格挡」：「只有盾牌给格挡。每次受到**直接伤害**（武器造成的）固定减少这个数，减到零为止；带几面盾只算最高的一面；破绽为负时反而多挨。buff 造成的灼烧、中毒、流血不算直接伤害，格挡挡不住。」「直接伤害」「中毒」「流血」三条里的「防护」改「格挡」。`LOUD_TERMS` 里的「防护」换成「格挡」。
- 帮助页 `direct_damage_and_armor`（id 不动）：标题「直接伤害与格挡」，正文把防护改格挡并加一句「几面盾只算最高的一面」；`physical.json` 说明、毒刀配方 note、`tut_search_2_again_1` 事件文字同样替换。
- `docs/architecture.md`：4.3 轴表那行（`block`，加固 / 破绽）、4.6 第 4 步、`DamagePacket` 字段注释、词条表；补一段「格挡层：盾牌各一层，只取最高」。

### 3.5 估算器（151）

`PowerContext.stat_value(BLOCK)` 仍按 `amount × hits_taken` 给单件盾估值（单看一面盾不变）。参考套件的组合值表会自然显示第二面盾值零 —— 不用改公式。`power_weights.json` 的键名若含 `armor` 一并改名。

### 3.6 测试

改名 + 语义变化涉及：`test_damage_pipeline`（护甲章节与 106 两节）、`test_overtime`、`test_stat_axes`（名字、撞名）、`test_effect_system:730`（「加法属性跨物品求和」改成「两面盾只取最高」）、`test_author_087`（赐福盾休眠仍给自己的格挡）、`test_author_091` / `096`、`test_keyword_tips`、`test_text_fields`、`test_enemy_pool`；新加：两面盾取最高、最高层移除后次高顶上（用基线 + 盾两层验）、轴修正加在生效层上、破绽倒贴不变、非盾道具写 `block` 报错、`armor` 别名提醒。

## 4. 敌人的天生格挡（待定 1）

作者只说了盾牌。敌人没有「道具规则」的约束，三个敌人的 `base_stats.armor` 是调过的数：

- **A（推荐）**：基线 `block` 算作一层「天生」，参与取最高，仍乘档位 `stat_scale`。守卫从 9 掉到 5：**建议把守卫的基线 4 删掉**（它的减伤本来就该来自招牌圆盾），蛮人 3、核心守护者 5 不动。
- B：敌人基线不许有 `block`，三个敌人改成加血或加护盾。改三份数据再调平衡，没必要。

## 5. 信仰赐福（待定 2）

自然 / 大地之神的赐福覆盖 `gear / armor / shield` 三类，按信力每份 +1 防护：

- **A（推荐）**：拆成两条赐福项。盾（`shield`）：每份 `block +1`（加在那面盾的层上，仍是盾给的）；防具与装备（`gear / armor`）：每份 `max_shield +4`（数值待调）。导入器：赐福项的 mods 作用于 `block` 时，它的标签必须只含 `shield`。
- B：整条改成 `max_shield`，盾也不再按信力加格挡。盾的信仰成长没了，不取。

技巧之神赐福盾一阶的 `armor +4` 直接改 `block +4`（它是盾，层值 15 → 19）。

## 6. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 敌人基线的格挡 | A 算一层「天生」，守卫删基线 4；B 敌人不许有基线格挡 | **A** |
| 2 | 自然 / 大地赐福的每份 +1 | A 拆成盾加格挡、防具加护盾上限；B 全改护盾上限 | **A** |
| 3 | 轴正名 | A 加固；B 别的名字 | **A**（和属性名「格挡」不撞） |
| 4 | 加固在没有任何格挡层时 | A 照加（没盾也减；内容里只有盾在给加固，靠导入 warn 守）；B 没层时正向轴无效 | **A**：规则一条，106 的倒贴也不用特判 |
| 5 | 弹开 / 久弹 / 标记 | A 改成带轴的 buff（152 的形式），数不变；B 新加「临时格挡层」效果 | **A**：弹开 8 低于赐福盾自己的 19，当层会白给，当修正才是今天的手感 |

## 7. 改动范围

| 文件 | 改什么 |
|---|---|
| `core/battle/battle_stats.gd`、`stat_axes.gd` | `ARMOR` → `BLOCK`（`&"block"`），轴 pos 加固 |
| `core/battle/combatant_spec.gd`、新 `block_layer.gd` | `block_layers` |
| `core/battle/compiler.gd` | 第 6 / 8 步收层 |
| `core/battle/combatant_runtime.gd` | 汇总跳过 `block`；`_rebuild` 末尾算最高层 + 轴；快照带层 |
| `core/battle/damage/damage_packet.gd`、`damage_resolver.gd`、`battle_trace.gd` | 字段与载荷改名 |
| `core/authoring/content_importer.gd`、`content_exporter.gd`、`content_check.gd` | 别名 + 三条校验（非盾 `block`、buff mods 作用 `block`、非盾正向加固）|
| `core/text/glossary.gd`、`text_template.gd` | 名字、词条、别名 |
| `ui/battle/combatant_panel.gd`、`battle_view.gd` | 格挡常驻格 + 悬浮窗；日志 |
| 数据：3 盾、3 敌人、2 档位表、3 buff、3 信仰、帮助页、物理类型、配方、4 事件 | 键改名、buff 改轴、赐福拆项 |
| `docs/architecture.md`、README 落地记录 | |
| 测试见 3.6 | |

约束提醒：测试 121 的 `add_theme_` 配额已满（135 / 135），新常驻格复用轴格的画法，不新增主题覆写。

## 8. 落地记录（2026-10-10）

五项待定都按推荐落地，和方案的差别：

- **没加 `CombatantSpec.block_layers` / `BlockLayer` 类**：层在 `CombatantRuntime.from_spec` 里直接从各件的 `stats.block` 收（`{uid, id, value}`，天生的 uid 0、id `innate`），编译器不用改。快照 `snapshot.block_layers` 带给回放面板。
- **预设图也有格挡**：`data/maps/prologue.json`、`tutorial2.json` 的教程敌人在节点内容里写死了 `base_stats.armor`（2、3、12、3），不走导入器。键改成 `block`；`EnemyKit.baseline_of` 读到旧键 `armor` 也当 `block`（玩家旧存档里的节点内容）。持符者天生 12 是一层，它没有盾，所以数不变（序章二的克制测试照过）。
- 校验：非盾 `base_stats.block`、非盾 `faith_bonuses` 碰 `block` → error；buff 的 mods 改 `block` → error（指向 `axes`）；非盾自己的规则给自己正向加固 → warn；赐福给格挡的那一条标签必须只有 `shield`。旧键 `armor`（基础属性、档位表、修饰的 stat、轴字段）当 `block` 读并 warn。
- 估算器的权重 `armor_per_point` 改名 `block_per_point`（数不变）。
- 测试：新增 `tests/battle/test_block_153.gd`（层与取最高、伤害管线、导入、内容、回放面板）；老测试里的 `armor` 键与「跨件求和」的断言改成格挡与「取最高」。
