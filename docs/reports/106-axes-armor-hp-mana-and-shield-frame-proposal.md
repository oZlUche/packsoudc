# 方案：标准轴补三条（防护 / 生命上限 / 法力上限）+ 护盾画成生命条的外框（106）

> 架构 thread，2026-10-02。作者在架构线程答「哪些量该补成轴」时定的：
> ① 若「护甲」指**能抵消大部分伤害并被消耗的资源** → 做成额外资源条，呈现为生命条上的**粗白外框**，长度 = 护甲 / 生命上限，护甲 ≥ 生命上限时全覆盖；
> ② 若指**每次受到直接伤害（武器攻击）时抵消的部分** → 做成【减伤 / 易伤】，每层使受到的直接伤害 −1 / +1；
> ③ 生命上限 →【生长 / 衰颓】每层 +1 / −1；④ 法力上限 →【充盈 / 枯竭】每层 +1 / −1，最低 0（法力用法未定，先占位）。
> 本文只写方案，不实现；依赖 103 / 105 的标准轴（已落地）。

## 一、对上现有的词

仓库里这两样**都已经有**，只是名字和作者的「护甲」要对一下：

| 作者的说法 | 仓库里的东西 | 现状 |
|---|---|---|
| ① 可消耗的抵伤资源 | **护盾**：资源 `shield`，上限 `max_shield`（`BattleStats`），伤害先扣它；中毒 / 流血 / 流失**无视**护盾（`DamageTypes` 的 absorbable 列） | 面板里是独立的一条「shield」资源条（`CombatantPanel.ORDER = [hp, shield, stamina, mana]`） |
| ② 每次直接伤害固定抵消 | **防护**：属性 `armor`，`DamageResolver` 第 4 步 `amount -= min(armor, amount)`；只对 `armor_applies` 的类型（物理 / 火焰 / 反伤）生效，中毒 / 流血 / 流失无视 | 只能靠道具属性（塔盾 −4）或 `BuffDef` 的 mods 改；没有轴 |

所以：①是**显示**改动（护盾条 → 生命条外框），②③④是**三条新轴**。两件事互不依赖。

## 二、三条新轴

| 轴 | 属性 | 模式 | 步长 | 正名 / 负名 | 落点 |
|---|---|---|---|---|---|
| `armor` | `armor` | FLAT | 1 | 格挡 / 破绽（作者定，2026-10-02） | 单位：`_merged.armor += 层数`，`DamageResolver` 本来就读单位的 `armor`，不改 |
| `max_hp` | `max_hp` | FLAT | 1 | 生长 / 衰颓 | 单位：`_merged.max_hp += 层数` → `_sync_resource_maxes` 把 `hp` 的上限跟过去 |
| `max_mana` | `max_mana` | FLAT | 1 | 充盈 / 枯竭 | 单位：同上，`mana` 的上限跟过去；`ResourcePool.set_max` 已经 `max(0, …)`，「最低为 0」白给 |

三条都是**单位级 FLAT 轴，不落到每件道具**（`items` 不设）：防护、生命上限、法力上限本来就是角色的量。加三行表就够了，`_apply_axes` 的 FLAT 分支现成；`ORDER` 加三项（显示顺序：接在 `STAMINA_COST` 后）。

**上限变了当前值怎么办**（已有规矩，不新定）：`ResourcePool.set_max` —— 上限涨多少当前值涨多少（生长 +3 层 = 立刻多 3 点血可用），上限降则把当前值夹到新上限（衰颓压下来会直接掉血）。上限归零（枯竭把法力压到 0）资源就不可用，面板按 `cap <= 0` 不画那条。

**「直接伤害」按来源定**（作者定，第八节）：武器造成的是直接伤害、Buff 造成的是非直接，防护只对直接伤害生效。现有的 `armor_applies` 类型列在现有内容上结论相同，第八节把它换成按来源的 `direct` 标记。

**编译期也能给**：105 的 `axis_boost{axis, stacks}` 和 `CompileInput.axes` 对这三条同样有效（例：某神 2 级「开战生长 5 层」）。

## 三、护盾画成生命条的外框（作者①）

`CombatantPanel`（玩家 / 敌人 / 回放 / 沙盒共用）：

- `ORDER` 去掉 `shield`，不再有独立的护盾条。
- `_draw_bar("hp")` 之后，若 `shield > 0`：在生命条**外侧**画一圈粗白框（`FRAME_W = 3` px，`UiPalette.FG` 或专门的 `UiPalette.SHIELD_FRAME`），框的**长度** = `min(shield / max_hp, 1) × 条宽`，从左端起；护盾 ≥ 生命上限时整条框满。
  部分覆盖时画成开口的框：上、下、左三边到那个长度为止，右端一道竖边收口 —— 一眼能看出「护盾顶得住几成血」。
- 生命条文字改成 `hp 当前 / 上限　盾 n`（护盾为 0 不写）；`max_hp` 为 0 的假人不画框。
- 护盾被打掉 / 叠上去的飘字与事件不变（`RES_SHIELD` 的 `RESOURCE_CHANGED`），只是落点从独立条挪到外框。
- 教程文本里「板甲的护盾能接住它头两三锤」这类描述不受影响；`docs/text-placeholders.md` 不用改。

**注意**：这条和 103 第 6 条的 buff 栏无关，护盾是资源不是 buff；也不改任何数值 —— 金样不动。

## 四、名字

作者定：防护轴叫**【格挡 / 破绽】**，于是不和受伤轴的「易伤 / 坚韧」撞名，受伤轴不改。

## 五、词条与校验

- `StatAxes.describe` 的 `what` 表加三项：防护、生命上限、法力上限；`Glossary` 的属性词条「护甲」改叫「防护」（和 104 / 作者的用词一致）并补「法力上限」。
- 导入器的 `warn_axis_candidate`（103 4e：只有一条落在轴属性上的 mod、没规则的可叠层 buff → 提示改轴）会开始对 `armor / max_hp / max_mana` 的简单 `BuffDef` 报提示；执行时把现有命中的改成 `shift_axis`（预计只有测试夹具，内容里的塔盾 −4 是道具属性不是 buff，不受影响）。
- 表自检测试：三条新轴 `stat` 非空、FLAT、`items` 未设、名字不与别的轴重复（第四节的撞名就该由这条测试拦）。

## 六、验证

- `shift_axis(armor, +3)`（格挡 3 层）后一下 10 点武器伤害打出 7（原防护 0）；中毒每秒 5 点仍是 5；`−3` 层（破绽 3 层）时 10 点打出 13 —— 作者定**允许负值倒贴**：`DamageResolver` 第 4 步改成 `amount -= armor`（armor 为负就是加伤），只对 `direct` 的包。现有 `min(armor, amount)` 要改，否则负 armor 的 min 结果不对。测试两边各一条。
- `shift_axis(max_hp, +5)`：上限与当前值同时 +5；`−8`：上限 −8、当前值夹到新上限；上限归 0 的单位立刻倒下（`hp` 被夹到 0 → 现有的死亡判定）。写进测试，这是衰颓最狠的边界。
- `shift_axis(max_mana, −99)`：上限 0、当前 0，不出负数；面板不画法力条。
- 面板：护盾 0 / 一半 / 等于上限 / 两倍上限四种情况各截一张（沙盒），外框长度 0 / 半 / 满 / 满。
- 金样不变（本文不改编译）；全套 `tools/test.sh` 绿。

## 七、改动范围（半天）

| 批 | 内容 | 文件 |
|---|---|---|
| ① 轴 | 三行表、`ORDER`、`describe` 的 `what`、改名「脆弱」、表自检 | `core/battle/stat_axes.gd`、`core/text/glossary.gd`、`tests/battle/test_stat_axes.gd` |
| ② 负防护 | `DamageResolver` 第 4 步允许 `armor < 0` 加伤（只对 `armor_applies` 类型），`packet.armor` 记负值 | `core/battle/damage/damage_resolver.gd` + 测试 |
| ③ 外框 | `ORDER` 去 `shield`、`_draw_bar` 后画框、文字 | `ui/battle/combatant_panel.gd`、`ui/ui_palette.gd`（若加 `SHIELD_FRAME`） |
| ④ 文档 | 架构 4.3 轴表（三条 + 改名）、4.8 面板一句、103 第 6 条备注、`docs/text-placeholders.md` 若词条有变 | `docs/architecture.md`、`docs/reports/103-*.md` |

## 八、直接伤害 / 非直接伤害的定义（作者定，2026-10-02）

作者原话：区分直接伤害和非直接伤害的主要方式就是看是否由【武器】造成 —— 来源是武器就一定是直接伤害；来源是 Buff（Buff 的来源可能多种多样）就是非直接伤害；除非另行说明，直接伤害默认一定受影响。

这是一条**按来源**、不是按伤害类型的规矩，比现在 `DamageTypes` 那张「护甲列」更根本。落法：

- `DamagePacket` 加 `direct: bool`。造伤害的效果（`DealDamage`、`FireEnchant`、反伤等）在 `create` 时填：规则属于某件道具（`ctx.source_uid() != 0`，也就是道具出手触发的）→ `direct = true`；规则来自 buff（`ctx.source_buff() != null`，灼烧 / 中毒 / 流血的每秒掉血、buff 到期的爆发）→ `direct = false`；套装 / 单位级规则（`source_uid == 0` 且不是 buff）→ `false`（它们不是武器）。
- **防护（格挡 / 破绽）只对 `direct` 的包生效**：`DamageResolver` 第 4 步的条件从 `td.armor_applies` 改成 `packet.direct`。`DamageTypes` 的护甲列删掉（现在那列和新规矩在现有内容上结论相同：物理 / 火焰来自武器出手、中毒 / 流血 / 流失来自 buff，所以没有数值回归；金样不动，伤害测试照跑）。
- 护盾的「可吸收」列**不动**：作者这次只说了直接伤害与防护的关系；中毒 / 流血穿盾仍按类型表。
- 「除非另行说明」的口子：效果上留一个 `@export var direct_override: int = -1`（−1 按来源默认，0 / 1 强制），导入器照反射认得；现有内容不填。
- `BattleEvent.DAMAGE` 的载荷加 `direct`，词条与日志能写「直接 / 非直接」；`Glossary` 的「防护」词条改成「每次受到**直接伤害**（武器造成的）固定减少这个数，减到 0 为止；破绽为负时反而多挨」。
- 架构 4.3 补一句这条定义；103 第 6 条、105 的火焰轴不受影响（火焰轴按类型放大，和直接 / 非直接是两个维度）。

改动范围加一批：`damage_packet.gd`、`damage_resolver.gd`、`damage_types.gd`（删护甲列）、`effects/deal_damage.gd`、`effects/fire_enchant.gd`、反伤效果、`battle_event` 载荷、`glossary.gd`、测试（武器出手 → 吃防护；buff 每秒掉血 → 不吃；`direct_override` 两个方向）。

## 作者已定（2026-10-02）

| 项 | 决定 |
|---|---|
| 可消耗抵伤资源（护盾） | 资源条，画成生命条的粗白外框，长度 = 护盾 / 生命上限，≥ 上限全覆盖 |
| 每次直接伤害固定抵消（防护） | 轴【格挡 / 破绽】，每层 −1 / +1；负防护倒贴（破绽 3 层 = 直接伤害 +3） |
| 直接 / 非直接伤害 | 看来源：武器造成 = 直接；Buff 造成 = 非直接；除非另行说明，直接伤害一定受防护影响（第八节） |
| 生命上限 | 轴【生长 / 衰颓】，每层 +1 / −1 |
| 法力上限 | 轴【充盈 / 枯竭】，每层 +1 / −1，最低 0；法力用法未定，占位 |
