# 小改：编辑器里「方式」类字段做成下拉、按方式只显示对应的输入框（111）

> 架构 thread，2026-10-03。作者看着信仰加成（`FaithBonus`）的表单说：「这里应该做成下拉菜单，如果是 tier 则输入 1～5 的整数，如果是按信力加成则按照正整数来计算，active 就不显示输入框，不用多个框。」
> 本文只写方案，不实现。改的是**通用表单**（`PropertyForm`，10.4 的反射编辑器），信仰加成只是第一个用到的地方。

## 一、现状

`FaithBonus` 四个字段：`mode: String`（tier / active / scaled）、`tier`、`per_points`、`max_stacks`。表单按反射画：`mode` 是 `String` → 一个文本框，手打；三个整数各一个数字框，不管方式是什么都摆着（截图里就是这样）。导入器会拦非法值（`content_importer.gd:405-416`），但要等到校验才知道打错了。

`PropertyForm` 的原则（文件头）：**不认识任何具体效果**，只问 Godot 这个对象有哪些导出属性、什么类型。所以不能在表单里写「如果是 FaithBonus 就……」，要加两条**通用**规矩，让任何资源都能用。

## 二、方案：两条通用规矩

### 2.1 字符串字段带 `@export_enum` → 下拉

Godot 自带：`@export_enum("tier", "active", "scaled") var mode: String = "tier"`。属性的 `hint` 就是 `PROPERTY_HINT_ENUM`、`hint_string` 是 `"tier,active,scaled"`，**JSON 与存档一个字不变**（值还是字符串）。

`PropertyForm._row_for` 的 `TYPE_STRING` 分支加一条：`hint == PROPERTY_HINT_ENUM` → `OptionButton`，选项显示名走 `FieldText.enum_label`（091 已有枚举值的中文表，补三条：tier → 按阶、active → 激活即、scaled → 按信力）。`ContentSchema.enum_options` 现在只给 int 用，让它对 String 也返回这份列表（不带 `:数字` 的那种 `hint_string`）。

顺手：导入器那行写死的 `["tier", "active", "scaled"]` 改成从同一个 hint 读（`ContentSchema.enum_options`），以后加一种方式只改 `@export_enum`。

### 2.2 字段按别的字段显示 / 隐藏：`FIELD_WHEN`

资源上声明一张常量表，表单读它：

```gdscript
## 哪个字段在什么情况下才显示：字段 → {别的字段: 允许的值}。没列的永远显示
const FIELD_WHEN := {
	"tier": {"mode": ["tier"]},
	"per_points": {"mode": ["scaled"]},
	"max_stacks": {"mode": ["scaled"]},
}
```

- `ContentSchema.field_visible(owner, key) -> bool`：没有 `FIELD_WHEN` 或没列这个字段 → true；否则逐条比对 `owner.get(别的字段)`。
- `PropertyForm` 建每一行时记下 `key → 行控件`；任一字段改动后（已有的 `_emit` 路径上）对本对象的所有行重算一遍 `visible`。不重建表单，不丢焦点。
- **切换方式时把隐藏字段归默认**（`tier = 1`、`per_points = 50`、`max_stacks = 0`）：JSON 里不会留一个看不见的旧值；导出器写非默认值才写，所以文件也干净。
- 和 `skip`（别处专门编辑的字段）不同：`skip` 是「这表单不画」，`FIELD_WHEN` 是「画了但现在不显示」。

同一机制以后能管别的：`StatModifier` 的「乘区分类 / 倍率百分比」只在有乘区时显示、地图来源的 `preset_path` 只在 `mode = preset` 时显示……都只是在那个资源上加一张表。

### 2.3 数字范围：`@export_range`

- `tier`：`@export_range(1, 5)`。表单的 `_number` 现在固定 ±99999 且 `allow_greater / allow_lesser`，改成**有 `PROPERTY_HINT_RANGE` 就按它来**（min / max / step 从 `hint_string` 读，关掉越界）。导入器加一条：`tier > 这件道具所属信仰的 thresholds 数` → error（现在只查 ≥ 1；日神 4 道阈值，写 5 现在不会报）。
- `per_points`：`@export_range(1, 100000)`，正整数。
- `max_stacks`：`@export_range(0, 999)`，0 = 不限。

### 2.4 作者说「不用多个框」怎么落

| 方式 | 显示 |
|---|---|
| 按阶 tier | 一个框：第几阶（1～5） |
| 激活即 active | 没有框 |
| 按信力 scaled | 「每多少信力一份」一个框；**叠层上限**要不要保留见待定 1 |

## 三、改动范围（半天）

| 批 | 文件 |
|---|---|
| ① 表单 | `ui/editor/property_form.gd`（String 枚举下拉、`FIELD_WHEN` 显隐、`_number` 吃 range）、`core/authoring/content_schema.gd`（`enum_options` 支持 String、`field_visible`）、`core/authoring/field_text.gd`（三条枚举值中文） |
| ② 资源 | `core/battle/faith_bonus.gd`（`@export_enum`、`@export_range`、`FIELD_WHEN`） |
| ③ 校验 | `core/authoring/content_importer.gd`（方式列表改读 hint；tier 不超过信仰阈值数） |
| ④ 测试 | `tests/authoring/`：String 枚举字段的 `enum_options`；`field_visible` 三种方式各一组；切方式后隐藏字段归默认；tier 越过阈值数报错；现有 5 处 `faith_bonuses` 内容导入仍绿 |

## 待作者定（不挡执行，按推荐先做）

1. 按信力方式下，「叠层上限（0 = 不限）」这个框**保留**（推荐，描述句「每 50 信力一份，最多 6 份」靠它；内容里现在没人用，不碍事）还是删掉字段、按信力永远不封顶？
2. 阶的上限写死 5（作者说的 1～5）还是按各信仰的阈值数（日神现在 4）：**推荐表单写 5、导入器按该信仰实际阈值数再拦一次**。
