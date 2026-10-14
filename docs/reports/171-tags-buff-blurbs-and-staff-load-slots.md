# 方案：标签分大类与标签制作器、buff 解说字段、增益 / 受益句由字段生成、法杖装载槽（171）

> 作者原话（2026-10-14，第 6–9 条，全文见附录）。性质：架构 · 实施。待定按推荐。关联 107（标签 `tip` / `internal`）、108（附加规则）、122（材料来源标签）、132（受益规则）、148（魔晶石供给与耐久）、152（buff 轴）、170（悬浮窗版面）。

## 1. buff 解说字段（第 7 条）

- `BuffDef` 加 `has_blurb: bool = false`（是否有专属解说）与 `blurb: String`（解说文本，`blurbs: Dictionary` 多语言，和 `display_names` 同款）。`FIELD_WHEN`（111）：`has_blurb` 为真才显示 `blurb`。
- 用法：悬浮窗里提到这个 buff 的地方，`has_blurb` 真就写 `blurb`，假就只写名字（171 §3）。`Glossary.describe_buff`（按定义生成的说明）保留给子悬浮窗（170 §3）。
- 导入器：`has_blurb` 真而 `blurb` 空 → 警告。

## 2. 标签分大类、标签制作器、道具标签改下拉（第 8 条）

- `TagDef` 加 `category: StringName`，五类（待定 1）：

| 类 | 现有标签归入 |
|---|---|
| `purpose` 用途 | weapon 武器、armor 防具、shield 盾、gear 装备、gear_plug 防具插件、part 零件、ammo、remedy 药剂、food、tool、treasure 珍宝、keepsake、relic、reagent、trophy、supply 建材、material 材料、crystal 晶石、melee / ranged / staff / gun、faith_anchor 信物 |
| `element` 属性 | fire 火焰、poison 毒、bleed 流血、blessed 赐福、enchanted 附魔、sealed 封印（冰霜 / 闪电现在没有，加时放这里） |
| `material` 材料 | metal 金属、bone 骨制品、leather 皮革、stone 石材、gem 宝石、flesh 血肉、wood 木制（新） |
| `origin` 归属 | imperial 帝国、barbarian 蛮族、faith 信仰、sigil 符号、`faith:<id>`（生成，不入表） |
| `source` 来源 | nature 自然、crafted 工艺、magic 魔法（122 的「恰好一个」规则不变） |
| `internal` 内部 | rapid / burst / heavy（107：只给敌人配装用，不露出）、node_tooltips |

- **标签制作器**：内容编辑器加「标签」一页（`TagDef` 已是内容，`data/authoring/tags/*.json`）：id、名字、多语言、说明、类别下拉、`tip`、`internal`。新标签只能从这里建。
- **道具编辑器的标签栏**改成下拉添加：按类别分组的菜单，选一个加一个，每个已选标签后面一个 ×；不能手打。`bow` 这种没登记的标签（现在道具里在用）→ 补一条 `TagDef`（归 purpose）。
- 导入器：道具 `tags` 里有没登记的 id → **报错**（现在只是漏过）；每件材料的 `source` 类恰好一个（122 规则换到类别上判）。
- 悬浮窗副行（170 §2）按类别顺序排：用途 → 属性 → 材料 → 归属；`source` 类不列（和材料类合写会重复）。
- `TagRegistry.by_category(cat)`、`category_of(id)`；`check_content` 校验每条 `TagDef` 有类别。

## 3. 增益 / 受益句由字段生成（第 6 条）

目标格式（作者例）：**【增益图标】武器增伤 10%**。三段都从字段来：

| 段 | 来源 | 规则 |
|---|---|---|
| 条件 | `grant_filter`（命中其一 = OR）→「XX、YY」；新字段 `grant_filter_all`（全部命中 = AND）→「XXYY」连写 | 两个都空写「邻居」；都有写「XXYY、ZZ」按 AND 组在前 |
| 效果名 | `grant_mods` 里的属性 → 句式名（`Glossary.STAT_NAMES` 加 `sentence` 键：damage 乘算 →「增伤」、max_armor →「护甲」、attack_speed →「加速」……）；`grant_rules` 施加的 buff → `BuffDef.has_blurb ? blurb : 名字` | 基础轴的 buff（152 `axes`）直接用名字 |
| 数值 | 乘算 →「10%」；加算 →「+5」；复杂效果 / 非基础轴（固定减伤等）→ 写固定数字或按 `blurb` | `mod_text` 加 `sentence := true` 分支 |

- 多条效果用「、」连：「武器增伤 10%、加速 5%」。
- 受益句同法：「【受益图标】挨着盾时 护甲 +5」（条件 = `receive_filter`，主语是自己）。
- 供给句（晶石）：「【装载图标】装进法杖：每 X 秒 Y 火焰伤害，剩 N 次」。
- 旧的「增益槽 ×N：给站在那儿的邻居…」整句删；槽数不写（格子上的图标已经说明）。

## 4. 受益槽与法杖装载槽（第 9 条）

- 两种受益语义分开：
  - **受益槽**（现有 `receive_cells / receive_filter / receive_mods / receive_rules`）：「站上来的邻居符合条件 → 本件得加成」，句子见 §3。
  - **装载槽**：新字段 `load_cells: Array[Vector2i]`（`load_filter` 默认 `crystal`）。148 的供给（`feed_*`）只认装载槽，不再认受益槽；魔法杖的 `receive_cells` 改成 `load_cells`。
- **一颗晶石只给一把法杖**：编译时每颗晶石找出它站上的所有法杖的装载槽，只给 `placed_seq` 最大的那把（**后来者优先**，8-4 的置入序号现成）；同一把法杖的多个装载槽被同一颗晶石占住只算**一份**（148 已是「一份，不按格数乘」，保留）。被别的法杖抢走的那把，装载槽按空算。
- **悬浮窗**：法杖的装载槽 = N 条词条位（N = `load_cells.size()`），空槽不显示；装了晶石的槽各一行「【装载】火焰魔晶石　每 X 秒 Y 火焰伤害　剩 N 次」（X / Y 按这把杖编译后的实际值，N = 晶石的 `charges`）。同一颗晶石占两个槽只出一行。晶石自己的悬浮窗加一行「装在：魔法杖」/「闲置」/「被另一把法杖占用」。
- 格子上：装载槽画 `load.png`，受益槽画 `receive.png`，增益槽画 `grant.png`（170 §4），点亮 / 未点亮两态。

## 5. 测试

- `test_buff_def`：`has_blurb` / `blurb` 存读；导入警告。
- `test_tag_registry`：每条有类别、`by_category`、未登记标签报错、材料来源恰好一个；`bow` 已登记。
- `test_adjacency_sentence`：「武器增伤 10%」「武器弓、弩增伤 10%」（OR）「帝国武器增伤 10%」（AND）、buff 名 / blurb 分支、受益句。
- `test_staff_load`：晶石跨两把法杖只给后放的；同一把两槽一份；被抢的那把按空；悬浮窗行数 = 装了的晶石数；晶石悬浮窗三种状态。
- 金样（编译结果）：魔法杖现有用例不变。

## 6. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 「魔法」归哪类 | A 来源类（自然 / 工艺 / 魔法，122 的「恰好一个」规则原样）；B 按原话归「归属」类（和帝国、蛮族并列） | **A**：122 规则是作者 2026-10-03 定的，B 会让「恰好一个」跨两类判；要 B 也行，规则改成跨类 |
| 2 | AND 条件的写法 | A 新字段 `grant_filter_all`；B 在 `grant_filter` 里用 `"a+b"` 字符串 | **A**：编辑器下拉选，不写语法 |
| 3 | 「后来者」指谁 | A 后放下的**法杖**抢到晶石；B 后放下的晶石选法杖（晶石只有一个，没得选）→ 等价于 A | **A** |
| 4 | 旧存档里法杖的 `receive_cells` | A 导入器把 `staff` 标签的受益格迁成装载格；B 手改 json | **A** |

## 7. 改动范围

| 文件 | 改什么 |
|---|---|
| `core/battle/buff_def.gd`、`ui/buff_editor/buff_editor.gd`、`core/authoring/content_importer.gd` | §1 |
| `core/inventory/tag_def.gd`、`tag_registry.gd`、`data/authoring/tags/*.json`（加 `category`，补 `bow`、`wood`）、`ui/editor/content_editor.gd`（标签页 + 道具标签下拉）、导入器 | §2 |
| `core/battle/adjacency_profile.gd`（`grant_filter_all`、`load_cells / load_filter`）、`core/text/glossary.gd`（`sentence` 名、`mod_text(sentence)`）、`ui/inventory/item_tooltip.gd`（句子生成）、`data/authoring/items/magic_staff.json` | §3 / §4 |
| `core/battle/compiler.gd`（晶石归属、一份）、`ui/inventory/inventory_view.gd`（三种格子图标） | §4 |
| `tests/…` 见 §5；`docs/architecture.md` 4.2（邻接：增益 / 受益 / 装载三类） | |

## 附录：作者原话（2026-10-14，第 6–9 条）

> 6. 以蛮神的护符为例，替换成以下格式：【增益图标】武器增伤10%。注意【武器】【增伤】【10%】都是由字段转化过来的，【武器】代表标签条件字段，如果存在OR条件则写作【XX、YY】，如果存在AND条件则写作【XXYY】，【增伤】是buff字段，作为基础轴可以直接将名字拿来用，如果buff是非基础效果，则需要在buff制作器里面加上buff说明字段，用于显示在说明里（如果留空则只显示buff名字），【10%】则是基础轴buff才有的数值简单转换，如果是复杂效果或其他类型轴（比如固定减伤）则显示为固定数字，具体情况具体分析。
> 7. 关于buff，记得给不同buff加上【是否有专属解说】的Boolean字段，以及对应的解说文本字段。
> 8. 标签同理，现在标签不是道具随便加的，而是要先通过标签制作器生成，道具的标签一栏改为通过下拉菜单添加。标签要分大类，【武器、防具、饰品】用途一类，【火焰、冰霜、闪电】属性一类，【木制、骨制、金属、血肉】等材料一类，【帝国、蛮族、魔法】等归属一类。
> 9. 关于受益槽，同样用图标替换，同时魔法杖和其他受益槽运行逻辑不同，其他受益槽的效果一般是"如果受益槽里面的道具符合某个标准，则当前道具获得加成"，魔法杖的受益槽可称之为装载槽，可替换为N个词条（N=装载槽数量），为空时不显示，装载槽拥有魔晶石时出现对应词条，显示魔晶石造成的伤害和剩余使用次数，另外做好规划，同一颗魔晶石一次只能给一把法杖使用（后来者优先），且即使魔晶石占据了一把法杖的多个装载槽，也只能生效一次。

## 落地记录

- v2.99 落地 §1–§5，待定全按推荐：1 A（来源类 = 工艺 / 自然 / 魔法）、2 A（新字段 `grant_filter_all`）、3 A（后放下的法杖抢到晶石）、4 A（导入器把带 `staff` 标签、只有受益格的老 JSON 迁成装载格，并提醒重存一次）。
- 标签：每个标签 JSON 加了 `category`；补登记 `bow`（弓，用途）、`wood`（木制，材料）；`node_tooltips` 归内部。道具上没登记的标签导入**报错**（`faith:<id>` 除外）。
- 标签制作器在启动器里（「构件编辑器」前）；存一条标签立刻登记，道具编辑器的下拉马上能选。道具的标签栏只剩标签块（每块带 ×）+ 按大类分组的下拉。
- buff 的 `has_blurb / blurb / blurbs`：勾了才显示解说栏；勾了没写导入提醒；别的语言没写用中文。
- 句子：AND 和 OR 同时有时，AND 组连写在前、紧接 OR 组（「武器弓、枪械增伤 10%」）；条件都空写「邻居」。乘算写「增伤 10%」、加算写「护甲 +5」（伤害的加算仍叫「伤害 +3」）。受益句「挨着盾时 护甲 +5」，不止一个受益格写「每挨着一件盾」。
- 装载：`load_cells / load_filter`（`load_filter` 空 = 默认只装魔晶石，这样导出器不会往每件道具写一遍）。归属由 `BattleCompiler.load_assignments` 统一算，编译、敌人摆放、棋盘图标、悬浮窗都用它：晶石压着几把法杖的装载槽时给 `placed_seq` 最大的那把，同一把的几个槽只算一份，被抢走的那把按空。
- 晶石悬浮窗写三态：「装在：X」/「装在：X（另一把法杖的装载槽也压着它：后放的优先）」/「闲置」。法杖装了几颗写几行，空槽不写。
