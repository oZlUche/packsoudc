# 方案：战斗单位只有一个来源 —— 信仰效果全部进编译器（105）

> 架构 thread，2026-10-02。起因：101 第 5 刀的「信仰 perk 回到编译期」被执行 thread 停下（`StatModifier` 的形状装不下四条按件干活的 perk），
> 作者在「架构方案执行」线程定了三条：① 火焰伤害加成就是一种普通增益（每层 +3%，祈祷按斐波那契给层数，暂定），增益来源可以是局内 / 局外 / 套装 / 信仰，与道具无关；
> ② 日神附魔用本局种子从武器里随机定 3 把；③ 这些都由编译器负责 —— 扩展编译器。本文只写方案，不实现；作者确认后交执行 thread。
> 依赖：103 的标准轴（已落地，`core/battle/stat_axes.gd`）、101 第 1 刀的 `AltarModule`（已落地）。

## 一、现状（执行 thread 已核对，这里只记结论）

```
RunState.compile_player():
    mods  = 套装 + 一局 buff 的 StatModifier         ← 给每一件参战道具，没有筛选
    rules = 套装 + 一局 buff 的 AbilityRule          ← 挂在单位上，不能指定给哪一件
    spec  = BattleCompiler.compile(board, 基线, mods, rules, 信力阶, 信力点)
    for perk in AltarModule.perks(): perk.modify_spec(spec, board, run)     ← 第二个来源：编译完再改
    spec.passives = BattlePassives.of(run)
```

`compile` 六步：收参战 uid → 基础值 → 包体 → 套装 → 信力按阶 → 邻接 → 打包 `CompiledItem`（`item.stats` 与 `stats[uid]` 同一对象）。
`StatValue` 把 `base` / 各乘区 / `flat` 分开存，`total()` 开打才合，乘区按分类**累加**，所以先加后加结果一样 —— 搬家不改数值的根据就是这一条。

16 条 perk 里 8 条动 spec。四条是整单位的（`low_hp_empower`、`overtime_regen` 挂单位规则；`food_shield`、`stat_mod(baseline)` 改基线；`undying` 已是 `spec.undying_sec`），
四条要**按件**：`enchant_weapons`（筛 `weapon` 且有规则的，按种子挑 `count` 把，单件挂「自己出手 → 附火」规则并改耐力消耗）、`food_double`（食物每条属性 `base ×2`，急速除外）、
`stat_mod(target=items, item_tag)`、`altar_sacrifice_hp`（按献祭次数给每件加急速）。`stat_mod(baseline)` 还要手工补 `spec.max_hp`。
火焰伤害加成现在是 `pray_percent × n^pray_curve` 塞进 `FireEnchant.bonus_percent`，只放大附魔那一下，和别的增益不是一个体系。

## 二、方案一句话

**`compile` 只吃一个 `CompileInput`，里面装齐这一场的全部外来加成（整单位的、按件的、轴的、结算旗子），编译器自己并；`core/run` 只负责把各来源翻译成 `CompileInput`，谁都不再碰编译结果。**
火焰伤害加成变成一条标准轴，祈祷只是往这条轴上加层。

## 三、编译器的新入参

### 3.1 `CompileInput`（`core/battle/compile_input.gd`，RefCounted）

```
baseline:     CombatantBaseline
faith_tiers:  Dictionary          # 原有：标签 → 阶
faith_points: Dictionary          # 原有：标签 → 点
mods:         Array[StatModifier] # 整单位：给每一件参战道具（套装、一局 buff —— 和现在一样）
rules:        Array[AbilityRule]  # 单位级规则（套装、一局 buff、low_hp_empower、overtime_regen）
baseline_mods: Array[StatModifier]# 施加到基线（food_shield 的护盾、stat_mod(baseline)）
scoped:       Array[ScopedMod]    # 按件（3.2）
axes:         Dictionary          # 标准轴 → 开战时的层数（3.3）
undying_sec:  float               # 结算旗子（max 合并）
seed:         int                 # 按件随机挑选用；调用方算好传进来，编译器不认识 RunState
```

现在 `compile(board, baseline, set_mods, set_rules, faith_tiers, faith_points)` 的六个参数就是前六个字段。保留一个薄的兼容签名给测试（内部造一个 `CompileInput`），正式调用方都走新签名。

### 3.2 `ScopedMod`：按件修饰，一个构件带几种能力（不是三个构件）

```
# core/battle/scoped_mod.gd   extends Resource
tags:          Array[StringName]   # 任一命中；空 = 不看标签
require_active: bool = false       # 只给有规则的（附魔：没规则的武器没法出手）
pick:          int = 0             # 0 = 全部命中件；>0 = 用 seed 从命中件里随机挑这么多件
mods:          Array[StatModifier] # 施加到每件命中
rules:         Array[AbilityRule]  # 挂到每件命中；规则里的 OnItemFired 在编译时绑成「只听自己」（填 source_uids = [本件 uid]、include_self）
base_scale:    float = 1.0         # 命中件所有属性的 base × 它（食物翻倍）
base_scale_except: Array[StringName] = []   # 不缩放的属性（急速）
```

为什么是一个构件：四条 perk 要的是「筛一批件、对它们做几件事」，筛法是公共的，做的事互相独立（空的就跳过）；拆成三个构件只是把同一套筛选抄三遍。
为什么 `Resource` + `@export`：现在只有 perk 程序化地造它，但作者第 ① 条说增益来源还有局内 / 局外 / 套装 —— `RunBuffDef` / `SetTier` 将来加一个 `scoped: Array[ScopedMod]` 字段就能在内容里写「这局所有武器 +10%」，
那时再在 `EffectRegistry` 登记种类 `scoped_mod`（10.4 的反射管线自动认得）。**这一轮不登记、不加内容字段**，只做战斗层的构件。

随机挑选（`pick > 0`）：命中件按 uid 升序，`RandomNumberGenerator.seed = hash(input.seed, 本条在 scoped 里的下标)`，Fisher-Yates 取前 `pick` 件。
同一个 `seed` 永远同一批 —— 作者第 ② 条「和本局种子挂钩」就是 `compile_player` 把 `hash(run_seed, "compile", clock.total)` 填进 `input.seed`（和现在 `enchant_weapons` 算种子的方式相同，只是算的地方从 perk 挪到调用方）。
`compile` 仍是纯函数：同样的棋盘 + 同样的 `CompileInput` 永远同样的结果；拖动预估时 `seed` 不变，所以预估和真打挑的是同三把。

### 3.3 `axes`：编译期的轴层数（作者第 ① 条的落点）

103 的标准轴是「战斗中会变的单位级增益」，现在只有战斗内的 `shift_axis` 能改它。本方案加一个入口：**开战时就带着层数**。

- `CompileInput.axes: {axis → stacks}`，`compile` 原样写进 `CombatantSpec.axes`；`CombatantRuntime.create` 把它种进 `axes[axis]`。
- 种进**系统层**（`[0, stacks]`）：它们是这一场的常驻加成（103 第 6 条：常驻不是 buff、不走净化），对手的净化不该把你祈祷攒的火焰洗掉；buff 栏按 103 的规矩画轴（正名 / 负名 × |层数|），来源写在常驻格的悬浮窗里。
- 来源汇到 `compile_player`：`AltarModule.axis_bonus`（祈祷攒的，见第四节）+ 将来 `RunBuffDef.axes` / `SetTier.axes` / 技能（这一轮只接神坛的；字段名先定下来，内容字段等有第一个用例再加，和 3.2 同一节奏）。
- 103 4e 的那句「编译期修饰不走轴」改成：**编译期的属性修饰（包体、邻接、套装、信力阶）不走轴；编译期的单位级增益走轴，作为开战初值**。两者的分界仍是「作用于某件 / 某几件」还是「作用于角色本身」—— 和 buff 栏的准则是同一条。

### 3.4 新的一条轴：火焰伤害

| 轴 | 属性 | 模式 | 步长 | 正名 / 负名 |
|---|---|---|---|---|
| `fire_damage` | （空：由伤害管线读） | 百分比 | 3% | 炽烈 / 熄火 |

落点在 `DamageResolver`：伤害包 `type == FIRE` 时，**攻方**的 `axis_factor(FIRE_DAMAGE)` 乘到原值上（第 1 步，防御之前；和 `DAMAGE_TAKEN` 在第 4 步乘守方对称）。
于是火焰附魔、灼烧、任何火焰来源都吃它 —— 这才是「火焰伤害加成」的字面意思；`FireEnchant.bonus_percent` 删掉。
加这一行表就够了：面板、词条、导入器校验都跟表走（4.3 标准轴的约定）。

## 四、祈祷：斐波那契层数（作者第 ① 条，暂定）

- `AltarModule` 加 `axis_bonus: Dictionary`（轴 → 累计层数），跟存档（v2 → v3，旧档没有就空），`stat_bonus` 旁边。
- `AltarPrayFirePerk` 改成：`axis = &"fire_damage"`，`gains: Array[int] = []`（第 n 次祈祷给几层；**空 = 斐波那契 1, 1, 2, 3, 5, 8…**，超出表长按最后一项），`max_times` 保留。
  `altar_apply`：`n = rituals["pray_fire"] += 1`；`axis_bonus[axis] += gain(n)`；日志「向日神祈祷（第 n 次）：炽烈 +k 层，现在 ×m（火焰伤害 +3m%）」—— 数全从字段来（104 第十节）。
- 层数与旧公式对照（默认步长 3%）：

| 祈祷次数 | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| 新：累计层数 | 1 | 2 | 4 | 7 | 12 | 20 |
| 新：火焰伤害 | +3% | +6% | +12% | +21% | +36% | +60% |
| 旧：10 × n^0.7 | +10% | +16% | +22% | +26% | +31% | +35% |

曲线从「越来越慢」变成「越来越快」，是作者有意的改动（暂定，和 104 一样留给测试调）；`gains` 填成 `[3, 2, 2, 1, 1]` 就能回到递减。
- `EnchantWeaponsPerk` 删 `pray_percent` / `pray_curve` / `fire_bonus()`；`sun.json` 与 `docs/gods.xlsx`「等级效果」日神 1 / 2 / 3 级三行同步（参数列、人话列），`gods.md` 镜像跟着。

## 五、perk 的新接口与八条的去向

`FaithPerk.modify_spec(spec, board, run)` → **`compile_into(input: CompileInput, board: GridInventory, run: RunState)`**：perk 只往 `input` 里放东西，不再见到 `CombatantSpec`。
`compile_player` 变成：

```
input = CompileInput.new()
input.baseline = effective_baseline(); input.faith_tiers / faith_points 同现在
input.mods / rules  ← 套装 + 一局 buff（同现在）
input.axes          ← AltarModule.axis_bonus
input.seed          = hash(run_seed, "compile", travel.clock.total)
for perk in AltarModule.perks(): perk.compile_into(input, board, self)
spec = BattleCompiler.compile(board, input)
spec.passives = BattlePassives.of(self)
```

| perk | 现在 | 之后（往 `input` 放什么） |
|---|---|---|
| `low_hp_empower` | `spec.set_rules.append` | `input.rules.append(同一条规则)` |
| `overtime_regen` | 同上 | 同上 |
| `food_shield` | 数棋盘食物 → `apply_to(spec.baseline)` | 数棋盘食物（perk 读 board 没问题，它在 `core/run`）→ `input.baseline_mods.append(MAX_SHIELD flat)` |
| `stat_mod(baseline)` | `apply_to(spec.baseline)` + 手工补 `max_hp` | `input.baseline_mods.append_array(mods)`；补账消失（第六节） |
| `stat_mod(items, tag)` | 遍历 `spec.items` 筛标签 | `input.scoped.append(ScopedMod{tags=[tag], mods})` |
| `altar_sacrifice_hp` | 遍历 `spec.items` 加急速 ×n | `ScopedMod{mods=[HASTE +haste_percent×n]}`（无筛选 = 全部；或者直接 `input.mods`，等价） |
| `food_double` | 食物每属性 `base ×2` 除急速；`flags["food_double"]` | `ScopedMod{tags=[food], base_scale=factor, base_scale_except=[haste]}`；献祭食物回体力翻倍那半边不在战斗里，`AltarFoodVitalityPerk` 已经直接问 `altar.perk(&"food_double")`，不动（顺手把它写死的 `×2` 改成读 `factor`，104 第十节的规矩） |
| `enchant_weapons` | 筛武器 + 自己挑 + 挂规则 + 改耐力 | `ScopedMod{tags=[weapon], require_active=true, pick=count, rules=[附火规则], mods=[STAMINA_COST ×(1+p%)]}`；火焰加成不再填进 `FireEnchant` |
| `undying` | `spec.undying_sec = max` | `input.undying_sec = max` |

其余 8 条（神坛 / 掉落 / 踩点 / 战前 / 献祭后）不碰战斗，不变。`FaithPerk.battle_note` 不变（buff 栏的常驻格仍按 103 的准则）。

## 六、编译器的步序与「数值为何不变」

```
1  收参战 uid（同现在）
2  基础值                                   ← base 只在这里写
3  包体                                     ← 乘区 / flat
4  套装与一局 buff：input.mods → 每件        ← 乘区 / flat
4b 信力按阶（同现在）                        ← 乘区 / flat，攒 bonus_rules
5  邻接（同现在）                            ← 乘区 / flat，links
6  打包 CompiledItem（同现在，先不算 max_hp）
7  按件：for s in input.scoped（按下标顺序）：
     命中 = 筛 tags / require_active（看打包后的 rules 非空）→ pick 随机挑
     每件：mods.apply_to(item.stats)；base_scale 乘 base；rules 复制一份、绑成只听自己、append
8  整单位：input.baseline_mods → spec.baseline；input.rules → spec.set_rules；
     spec.axes = input.axes；spec.undying_sec = input.undying_sec
9  spec.max_hp = 基线生命 + Σ 每件生命        ← 最后算，所以 stat_mod(baseline) 不再补账
```

不变的理由，分三类：
- **乘区与 flat**（3 / 4 / 4b / 5 / 7 的 mods、8 的 baseline_mods）：`StatValue` 同乘区相加、乘区间按枚举顺序连乘、flat 最后加，全部可交换 —— 第 7 步放在 5 之后还是 3 之前，`total()` 一样。
- **`base`**：只有第 2 步写、第 7 步的 `base_scale` 乘，别处不碰；`×2` 对 base 做，与乘区 / flat 无关 —— 和现在 perk 在编译后乘 base 完全同一个数。
- **规则**：挂到哪一件、挂几条、字段一样，顺序只影响同一事件下的触发次序；附魔规则现在是 append 到 `item.rules` 末尾，第 7 步也是 append 到末尾，次序相同。
- **随机挑选**：同一个 seed、同一批候选（uid 升序）、同一种抽法 —— 把现在 `enchant_weapons` 里那段抽法原样搬进 `ScopedMod`，挑出来的就是同三把（验证里专门测）。

唯一有意的数值改动是火焰加成（第四节），验收里单列。

## 七、依赖方向与纯函数（1.3.1 的检查）

- `CompileInput` / `ScopedMod` / `StatAxes.FIRE_DAMAGE` 都在 `core/battle`，不认识 `core/run`；`core/run` 只是造它们。`tests/test_layering.gd` 不用加白名单。
- `compile` 不碰 `RunState`、不碰时钟、不自己造随机 —— 随机全由 `input.seed` 决定。文件头「必须是纯函数」那句照旧成立，补一句「包括按件随机挑选：同一 seed 同一结果」。
- `CombatantSpec` 多两个字段 `axes: Dictionary`（结算内核读，种进系统层）；`flags` 不回来。

## 八、验证（给执行 thread）

1. **搬家前后逐件相等**（主验收）：改代码**之前**先录金样 —— 对每个信仰在最高阶、一张固定棋盘（四位主神各一张，含武器 / 食物 / 信物；蛮神的再带 2 次献祭生命上限）、
   固定 `run_seed` 与 `clock.total`，把 `compile_player()` 的结果写成 `tests/fixtures/compile_golden/<faith>.json`：`max_hp`、`undying_sec`、每件 `{uid, def_id, stats.snapshot(), rules 的 [trigger 类名, effects 类名…]}`、`set_rules` 同样。
   改完后同样输入再编一遍，逐字段相等。日神的金样在 0 次祈祷下录（火焰加成为 0，两边一致）。
2. **随机挑选可复现**：同 seed 两次编译挑同三把；换 seed 可能不同；棋盘上 ≤ 3 把武器时全挑；没规则的武器不在候选里。
3. **火焰轴**：祈祷 1 / 3 / 6 次 → `axis_bonus["fire_damage"]` = 1 / 4 / 20；开战 `CombatantRuntime.axis_system(FIRE_DAMAGE)` = 20；一下 10 点火焰伤害在 20 层下打出 16（×1.6）；物理伤害不变；灼烧也放大；对手净化之后层数不变；`gains=[3,2,2]` 时第 4 次给 2 层。
4. **食物翻倍**：食物道具 `damage.base` 翻倍、`haste.base` 不动、它的 flat / 乘区不动；献祭食物回体力仍翻倍（走 `faith_perk(&"food_double").factor`）。
5. **基线补账**：`stat_mod(baseline, MAX_HP +10)` 后 `spec.max_hp` 多 10，不多不少（原来靠手工补，现在靠第 9 步）。
6. 预估：拖动时重编译（`seed` 不变）挑的武器与开战一致（UI 层肉眼验一次）。
7. 层次：`tests/test_layering.gd` 绿；`grep -n "CombatantSpec" core/run/faith/perks/` 为空；`grep -n "modify_spec" core/` 为空。
8. 内容：`sun.json` 与 `docs/gods.xlsx` 对照（104 第七节的工具若已落地就跑它，否则人工对三行）；导入 / 导出往返绿；全套 `tools/test.sh` 绿。

## 九、改动范围与顺序（一个执行 thread，约一天半）

| 批 | 内容 | 文件 |
|---|---|---|
| ① 金样（先于一切） | 录四份 `compile_golden` | `tests/fixtures/compile_golden/*.json`、录制脚本（测试里一个 `record` 开关） |
| ② 战斗层构件 | `CompileInput`、`ScopedMod`、`compile` 新签名 + 第 7～9 步、`CombatantSpec.axes`、运行时种进系统层、`StatAxes.FIRE_DAMAGE`、`DamageResolver` 攻方火焰因子、`FireEnchant` 删 `bonus_percent` | `core/battle/compile_input.gd`（新）、`scoped_mod.gd`（新）、`compiler.gd`、`combatant_spec.gd`、`combatant_runtime.gd`、`stat_axes.gd`、`damage/damage_resolver.gd`、`effects/fire_enchant.gd` |
| ③ 一局层 | `compile_into` 接口与 8 条 perk、`compile_player`、`AltarModule.axis_bonus`（存档 v3 + 迁移）、祈祷改轴、`AltarFoodVitalityPerk` 读 `factor` | `core/run/faith/faith_perk.gd` + 8 个 perk、`core/run/run_state.gd`、`core/run/modules/altar_module.gd`、`core/run/run_migrations.gd` |
| ④ 内容与文档 | `sun.json` 三行、`gods.xlsx` / `gods.md`、`Glossary` 轴词条、架构文档 4.2（新步序）/ 4.3（轴初值、火焰轴）/ 1.3.1 表（perk 那行）/ 10.4、101 第 5 刀收尾一行、`docs/text-placeholders.md` 若日志句用了占位符 | `data/authoring/faiths/sun.json`、`docs/gods.xlsx`、`docs/gods.md`、`core/text/glossary.gd`、`docs/architecture.md`、`docs/reports/101-*.md` |
| ⑤ 验证 | 第八节 1～8 | `tests/battle/test_compile_input.gd`（新）、`tests/run/test_faith_perks.gd`（改）、`tests/test_save_migration.gd` |

② 和 ③ 之间以 `CompileInput` 为界，可以两个人分头做；① 必须最先。

## 十、补：日神 3 级 = 开战带 5 层「省力」（作者补充，2026-10-02）

作者原话：日神的 3 级效果本质是「获得 5 层可叠加的 buff，后面战斗计算耐力消耗时的公式是 耐力 × 97%^层数」。
这和第三节 3.3 是同一件事 —— 一条**标准轴**，开战时带层数 —— 只差一点：97%^层数是**连乘**，103 的轴只有「百分比（1 + 层数 × 步长）」和「固定值」两种模式。

### 10.1 现状

`sun.json` 3 级：`enchant_weapons{count: 0, stamina_cost_percent: -20}` → 编译期给挑中的武器加一条 `STAMINA_COST` 的 EMPOWER 乘区 −20%，一次性、不分层、只落在那几把武器上。
作者要的：可叠层、连乘、作用于角色（所有耐力消耗），5 层 ≈ ×85.9%。

### 10.2 方案：轴表加第三种模式 `COMPOUND`，加一条轴 `stamina_cost`

| 轴 | 属性 | 模式 | 步长 | 正名 / 负名 |
|---|---|---|---|---|
| `stamina_cost` | `stamina_cost` | `COMPOUND` | 97（每层 ×97%） | 省力 / 费力 |

- **公式**：`终值 × (步长/100)^层数`。正层是增益（省），负层是减益（费：×(100/步长)^|层数|），相抵照旧（+5 层省力 − 2 层费力 = +3 层）。
- **定点实现**：不用 `pow`。`StatAxes.factor` 对 COMPOUND 做 |层数| 次 `StatMath.mul`（负层改做 `StatMath.div`），层数是小整数，循环几次就完，跨平台逐位一致（和 4.3「全程定点」一致）。
- **落点**：`_apply_axes` 里 COMPOUND 走和 PERCENT 同一条路（`_scale_final` 乘因子到单位与每件道具），只是因子算法不同 —— 所以耐力消耗的终值 = 道具级终值（含现有的 EMPOWER 乘区）× 0.97^n。**现有 `stamina_cost` 乘区不动**：它们在 4.3 的乘区里，轴在乘区之后，两者相乘。
- **层数记系统层**（105 作者已定：编译期带来的轴层数不被净化）。
- **4.3 冻结**的是道具级公式；标准轴本来就是「公式之后的最后一步」（v2.11），加一种因子算法不改道具级任何数。架构文档 4.3 标准轴一节加一行模式说明与这条轴。

### 10.3 给层数的构件：通用的 `AxisBoostPerk`

不在 `enchant_weapons` 上加字段。新 perk `axis_boost{axis, stacks}`，`compile_into`：`input.axes[axis] += stacks`。
它是通用的 ——「开战带 n 层 X」这类效果以后任何神都能用（和 3.3 的 `RunBuffDef.axes` 同一个入口）。
`sun.json` 3 级改成两条：`{"type": "enchant_weapons", "count": 0, "tier": 3}` + `{"type": "axis_boost", "axis": "stamina_cost", "stacks": 5, "tier": 3}`；
`EnchantWeaponsPerk.stamina_cost_percent` 删（没人再用）；`gods.xlsx`「等级效果」日神 3 级那行拆成两行同步。
`battle_note` 返回空：轴本来就在 buff 栏里，不再另画一格。

### 10.4 面板与词条

- buff 栏：按 103 画轴 ——「省力 ×5」；悬浮窗 `StatAxes.describe` 加 COMPOUND 分支：「耐力消耗：每层 ×97%（正为省力、负为费力，相抵）／现在 +5 层 → ×85.9%」。数从表与层数算，不写死（104 第十节）。
- `Glossary` 的属性词条给 `stamina_cost` 补一条「耐力消耗」（现在没有）。
- 导入器：`ShiftAxis.axis` / `axis_boost.axis` 必须在 `StatAxes.TABLE`（现有校验）；表的自检测试加：COMPOUND 轴 `step` 必须在 (0, 100) 之间开区间，否则因子不收敛。

### 10.5 验证与金样

- `StatAxes.factor(STAMINA_COST, 5)` = `from_float(0.97^5)` ±1（定点误差）；`factor(…, -2)` = 1/0.97²；`factor(…, 0)` = ONE。
- 一件耐力消耗 10 的武器，开战带 5 层省力：出手扣 8.59（取整按现有规矩）；另有 −20% EMPOWER 乘区时扣 6.87（0.8 × 0.859）。
- 对手净化不动它；`shift_axis(stamina_cost, -2)` 之后显示「省力 ×3」。
- **第八节的日神金样要有意重录**：3 级不再给武器加 −20% 乘区，改成 `spec.axes = {stamina_cost: 5}`；重录的说明写进金样文件头，其余三份不动。

### 10.6 改动范围（并进第九节的 ②③④⑤ 四批，约加半天）

| 批 | 加什么 | 文件 |
|---|---|---|
| ② 战斗层 | `Mode.COMPOUND`、`STAMINA_COST` 轴、`factor` 的连乘分支、`describe` 分支、`_apply_axes` 走 PERCENT 同路 | `core/battle/stat_axes.gd`、`combatant_runtime.gd` |
| ③ 一局层 | `AxisBoostPerk`（新）+ `RunRegistry.FAITH_PERKS` 一行；删 `stamina_cost_percent` | `core/run/faith/perks/axis_boost_perk.gd`（新）、`run_registry.gd`、`enchant_weapons_perk.gd` |
| ④ 内容与文档 | `sun.json` 3 级两条、`gods.xlsx` / `gods.md`、`Glossary` 词条、架构 4.3 一行、`field_text` 中文名 | `data/authoring/faiths/sun.json`、`docs/gods.xlsx`、`docs/gods.md`、`core/text/glossary.gd`、`docs/architecture.md`、`core/authoring/field_text.gd` |
| ⑤ 验证 | 10.5 四条 + 表自检 + 重录日神金样 | `tests/battle/test_stat_axes.gd`、`tests/fixtures/compile_golden/sun.json` |

## 作者已定（2026-10-02，「架构方案执行」线程）

| 项 | 决定 |
|---|---|
| 火焰伤害加成 | 是普通增益，每层 +3%，和伤害 / 攻速加成同一体系；来源是祈祷而不是道具 |
| 祈祷给的层数 | 按斐波那契顺序增长（暂定，可调） |
| 增益来源 | 局内、局外、套装、信仰都可以是来源，与道具无关 |
| 日神附魔挑武器 | 和本局种子挂钩，随机定 3 把 |
| 谁负责 | 全部由编译器负责；先出方案再执行 |
| 编译期的轴层数（2026-10-02，按推荐） | 记系统层：常驻加成，对手净化洗不掉 |
| 火焰轴的范围（2026-10-02，按推荐） | 放大所有火焰伤害（附魔、灼烧、任何火焰来源） |
| 斐波那契的写法（2026-10-02，按推荐） | perk 字段 `gains` 为空时的默认；表里要改曲线再填数列 |
| 日神 3 级（2026-10-02，补） | 开战获得 5 层可叠加 buff，耐力消耗 × 97%^层数（第十节：`stamina_cost` 轴，COMPOUND 模式） |

## 待作者定（第十节，不挡执行，按推荐先做）

1. 「省力」作用于**角色全部耐力消耗**（推荐：你说的是角色身上的 buff，所有道具的耐力消耗都 ×0.97^n）还是只作用于武器（旧 3 级的范围）？
2. 轴的名字「省力 / 费力」可以吗？只影响显示，随时能改。
