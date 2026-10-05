# 133 方案：去掉四个乘区 —— `StatModifier` 只剩「乘算 / 加算 + 一个数」，编辑器下面一行提示

> 架构 · 提议（2026-10-05）。作者：「现在的属性加成的 mult category 不应该有四项了吧？尤其是 sharp element 和 haste，这些本该是独立的 BuffDef 而非一种增益生效方式，比如添加护盾或防护时不可能加 haste。将多余的三项去掉后，再添加一行提示文字用于告诉编辑者这项 buffDef 是乘算还是加算，是扩大还是减少，这样百分比和固定值也可以用一个变量来表达。」

## 一、现状（已核实）

- `StatMath.Buff { EMPOWER, SHARP, ELEMENT, HASTE }` 是 4.3 公式里「同区相加、跨区相乘」的四个乘区；代码注释自己就写着「**这里的分类是开发期占位，正式内容确定后替换**」。
- 作者说得对：它们混了两件事。**乘区**本该只回答「加成怎么叠」，而 SHARP（物理系）/ ELEMENT（元素）/ HASTE（急速）回答的是「加成是什么」—— 那是 `stat` 字段（`damage` / `haste` / `armor`…）和标准轴（`attack_speed`、`fire_damage`…）已经在回答的问题。于是出现「给 `max_shield` 的加成填哪个乘区」这种没有答案的问题（内容里 `armor` 填了 EMPOWER、`haste` 填了 HASTE、`stamina_cost` 填了 EMPOWER —— 填法全凭手感）。
- 一条 `StatModifier` 现在有三个数：`mult_category`、`mult_percent`、`flat`，一条可以同时乘又加。内容里 **17 处**乘区引用（11 个 JSON：EMPOWER 9、HASTE 5、SHARP 3），没有一条同时填了乘和加。
- 跨区相乘真正起作用的场合只有「同一属性吃到两个不同乘区」：现有内容里是**弓 + 箭矢（SHARP +20%）+ 力量的符号（EMPOWER +15%）**这一种组合，跨区 1.38 对同区 1.35，差 2%。
- 4.3 的「追加只能加在末尾」整段是为多乘区的乘法顺序写的；乘区只剩一个，这条约束连同它的理由一起消失。
- 标准轴（`StatAxes`，单位级）**不在本篇范围**：它是公式之后的另一层，有自己的百分比 / 固定值 / 连乘三种模式，作者这次说的是道具级的 `StatModifier`。

## 二、设计

### 2.1 公式：一个乘区

```
终值 = 基础值 × max(0, 1 + Σ乘算) + Σ加算
```

所有乘算**相加**后乘一次（这正是现在「同区相加」的规矩，只是区只剩一个）；加算在乘法之后相加、不吃放大（不变）；乘算之和低于 −100% 钳到 0（不变）。然后才是标准轴那一层（不变）。

### 2.2 `StatModifier`：三个字段

```gdscript
@export var stat: StringName = &"damage"
@export_enum("乘算", "加算") var mode: int = Mode.ADD     # enum Mode { ADD, MULT }
@export var amount: float = 0.0      # 乘算 = 百分数（25 = +25%，-10 = -10%）；加算 = 固定值
```

- 「扩大还是缩小」就是 `amount` 的符号，不另设字段。
- 一条只做一件事：要「+20% 且 +3」写两条（内容里没有这种条，不用迁）。
- `apply_to(target, times)`：MULT → `value.add_percent(amount × times)`；ADD → `value.add_flat(amount × times)`。
- `describe()`：乘算「伤害 +25%」、加算「耐力上限 +15」，缩小时带负号；不再带乘区名（`Glossary.CATEGORY_NAMES` 删）。

### 2.3 编辑器：字段下面一行提示

`PropertyForm` 加一个约定：资源若声明 `func editor_hint() -> String`，表单在它的字段下面画一行灰字，任何字段改了就重算（和 111 的 `FIELD_WHEN` 同一处接）。`StatModifier.editor_hint()` 按当前值生成：

| 填法 | 提示 |
|---|---|
| 乘算 +25 伤害 | 乘算 · 扩大：伤害 终值 ×（1 + 25%）；和别的乘算先相加再乘，加算在乘完之后 |
| 乘算 −10 急速 | 乘算 · 缩小：急速 终值 ×（1 − 10%）；乘算之和低于 −100% 按 0 算 |
| 加算 +8 护盾上限 | 加算 · 扩大：护盾上限 终值 +8；在所有乘算之后加，不吃百分比 |
| 加算 −2 防护 | 加算 · 缩小：防护 终值 −2 |
| 乘算 填在 `crit_chance` | 暴击只收加算（104）—— 导入会报错 |

`BuffDef.mods` 是「每层一份」，提示末尾在 buff 里多一句「每层一份」。

### 2.4 兼容与迁移

- **导入器**读旧键：`mult_percent ≠ 0` → `mode = MULT, amount = mult_percent`；`flat ≠ 0` → `mode = ADD, amount = flat`；两者都非零 → error「一条只能乘或加，拆成两条」（现有内容没有）；`mult_category` 出现 → warn「乘区已取消，忽略」。旧的 `FIRE` 别名提示一并删。
- `tools/normalize_content.gd` 跑一遍把 11 个 JSON 重写成新格式（仓库里的作者数据应当就是导出器格式，测试逐字节比）。
- **存档**不受影响（`StatModifier` 不进存档，战斗每场重编译）。
- **金样**（`tests/fixtures/compile_golden`）：弓 + 箭 + 符号那组会从 1.38 变 1.35，按规矩**有意重录**，记录在 `test_compile_golden.gd` 头注。
- 代码里直接造乘区的四处改写：`altar_sacrifice_hp_perk.gd`（HASTE）、`encumbrance_rules.gd`（HASTE，129）、`tools/gen_sample_combat.gd`、`content_schema.gd`（枚举表 `StatMath.Buff` → `StatModifier.Mode`）。
- `StatValue`：`_mult: PackedInt32Array` → `percent: int`；`add_mult(category, amount)` / `mult_of(category)` 删，`add_percent(percent)` 改成不带乘区参数；`total()` 少一层循环；`_to_string` 跟着改。`StatMath` 删 `Buff` 枚举、`categories()`、`category_count()`、`category_name()`；定点数部分不动。
- 测试：约 15 个测试文件引用 `StatMath.Buff` / `mult_category`，机械替换；`test_stat_math.gd` 补「两条乘算相加而不是相乘」「乘算之和 −120% 钳 0」「加算不吃乘算」三条；`test_content_pipeline.gd` 补旧键迁移与「一条两样」报错。

### 2.5 不动的

标准轴（`StatAxes`）、`shift_axis`、`on_axis_at_least`、轴的三种模式；`BuffDef` 的层数 / 时长规矩；暴击「只收加算」（现在改成「`mode` 必须是 ADD」）；`ScopedMod.mods`、`bag_mods`、`grant_mods` / `receive_mods`、套装档位的 `mods` —— 它们装的都是 `StatModifier`，字段一换全体跟着换。

## 三、改动点

| 文件 | 改动 |
|---|---|
| `core/battle/stat_math.gd`、`stat_value.gd`、`stat_modifier.gd` | §2.1、§2.2、§2.4 |
| `ui/editor/property_form.gd` | `editor_hint()` 约定（§2.3） |
| `core/authoring/content_importer.gd`、`content_schema.gd`、`content_exporter.gd`、`tools/normalize_content.gd` + 11 个 JSON | 旧键迁移、枚举表、重写 |
| `core/text/glossary.gd` | 删 `CATEGORY_NAMES`，`describe_buff` 按 §2.2 |
| `core/run/faith/perks/altar_sacrifice_hp_perk.gd`、`core/run/encumbrance_rules.gd`、`tools/gen_sample_combat.gd` | 改写造 mod 的地方 |
| `tests/battle/test_stat_math.gd` 等约 15 个测试、`tests/fixtures/compile_golden/*` 重录 | §2.4 |
| `docs/architecture.md` 4.3（公式、删「乘区分类是可扩展枚举」与「只能追加在末尾」两段、109 的 FIRE→ELEMENT 变更记录加一句「133 取消」）、`docs/effect-catalog.md` §7 | 文档 |

## 四、待定（都按推荐）

| # | 问题 | 推荐 | 备选 |
|---|---|---|---|
| 1 | 乘算之间怎么叠 | **相加后乘一次**（现在同区的规矩；没有顺序问题；叠得慢，压数值爆炸） | 逐条相乘（1.25 × 1.10）：更「乘算」，但叠层 buff 会指数增长，4.3 压爆炸的理由就没了 |
| 2 | `amount` 的类型 | **一个 `float`**（乘算当百分数、加算当固定值），作者要的「一个变量」 | 两个字段各自保留类型 |
| 3 | 提示怎么画 | **字段下一行灰字，实时重算** | 悬浮窗（要停上去才看见） |
| 4 | 要不要保留「将来可能再加乘区」的口子 | **不保留**：要「独立的叠法」用轴（轴有三种模式），不再开乘区 | 留一个单元素枚举 |
| 5 | 金样 | **重录并记录**（弓 + 箭 + 符号 1.38 → 1.35 是预期） | 把箭矢的 +20% 调成 +23% 保持原数（没必要） |
