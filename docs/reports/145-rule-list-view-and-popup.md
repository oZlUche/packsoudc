# 方案：编辑器里的规则改成「列表视图 + 双击弹窗分页签」

日期：2026-10-09　状态：架构 · 提议（待作者确认后交「架构方案执行」）

作者原话（2026-10-09）：

> 关于编辑器，首先目前界面还是太杂乱，很难看清规则后面哪些是属于这个规则的，哪些是属于其他的，效仿 windows 的布设增加一个列表视图，每一行是个独立的规则，双击点开后再弹出一个窗口，里面的触发、消耗、效果全都是不同选项卡

---

## 0. 结论（一段话）

规则表（`Array[AbilityRule]`）在表单里**不再内联铺开**，改成一张**列表**（一行一条规则：时机 / 消耗 / 效果三列，文案用 142 的按字段生成），下面一排「新建 · 复制 · 删除 · 上移 · 下移」。**双击一行**（或按「编辑」）弹出一块**浮窗**，标题是这条规则，顶上一行实时预览，正文是**三个页签：触发 / 消耗 / 效果**，每页里还是现在的反射表单（扳机 + 节奏的类型下拉与字段；消耗卡片；效果卡片）。改动落在 `PropertyForm` 一处，所以道具 / buff / 套装 / 技能里凡是规则表都一起变整齐；其他对象数组（修饰、buff 的 on_apply 等）这次不动。

---

## 1. 现状：为什么看不清

1. 规则表走 `PropertyForm._array_section` 的「对象数组」分支（`ui/editor/property_form.gd:780-819`）：每条规则一张可折叠卡片，卡片里是 `_sub_form(rule)`，而 `AbilityRule` 自己又有 `trigger`（对象）、`cadence`（对象）、`costs`（对象数组）、`effects`（对象数组）—— 于是**一条规则展开是四层嵌套的卡片**：规则卡 → 扳机卡 / 节奏卡 / 消耗标题 + 卡片们 / 效果标题 + 卡片们。
2. 嵌套只靠缩进和一行 `_muted("[i] 类型名")` 区分，两条规则挨着时，第一条的最后一个效果卡和第二条的规则卡之间没有可见的边界，所以「这个效果是谁的」要数缩进才知道。
3. 道具的战斗档案（`CombatProfile.rules`）、邻接（`AdjacencyProfile.grant_rules / receive_rules`）、buff（`BuffDef.rules`）、套装档位（`SetTier.rules`）、技能（`RunSkill.rules`）、信力（`FaithBonus.rules`）、范围修饰（`ScopedMod.rules`）都是同一种表，问题在哪个编辑器里都一样。
4. 142 之后 `Glossary.rule_text(rule)` 已经能把一条规则写成一句「[时机] 每 N 秒最多一次，消耗，效果」（`core/text/glossary.gd:175`），列表的每一行正好用它的三段。

---

## 2. 方案

### 2.1 列表视图（表单里）

`_array_section` 加一个分支：元素类是 `AbilityRule` 时交给新的 `_rule_list(owner, key, arr)`，其余对象数组照旧。

- 标题照旧：「规则（N）」（`FieldText.label` + 条数）。
- 一张 `Tree`（`hide_root`，列标题可见，单选），四列：
  | 列 | 内容 | 来源 |
  |---|---|---|
  | # | 序号 | — |
  | 时机 | 扳机那句 + 节奏（「[开战时]」「每 2.0 秒」「… 每 3.0 秒最多一次」） | `Glossary.trigger_text` + `Cadence` |
  | 消耗 | 显式消耗用「，」连起来；没有就留空 | `Cost.describe()` |
  | 效果 | 效果句 | `Glossary.effects_text` |
  整行的悬浮说明是完整的 `rule_text`。
- 不合法的规则（`AbilityRule.is_valid()` 为假：缺扳机 / 缺节奏 / 没效果）序号前加「！」并整行用 `TreeItem.set_custom_color` 标成暗色；校验信息本来就在右栏状态区，列表只做提醒。
- 行高一行，列表最多显示 8 行，多了列表内滚动，所以规则再多也只占一块固定高度。
- 列表下一排小按钮（沿用 `_small_button`）：**新建**（`ContentSchema.make(&"AbilityRule")`，追加后直接弹窗打开）、**复制**（`duplicate(true)` 当前行，插在它后面）、**删除**、**上移**、**下移**、**编辑**（= 双击）。没选中行时复制 / 删除 / 上移 / 下移 / 编辑禁用。
- 双击一行（`Tree.item_activated`，也响应回车）→ 2.2 的弹窗。
- 改完顺序 / 删除后照旧 `owner.set(key, arr)` + `_emit()` + `rebuild()`。

### 2.2 弹窗：一条规则

新脚本 `ui/editor/rule_window.gd`（`class_name RuleWindow`），**继承 `FloatingWindow`**（`ui/game/floating_window.gd`）：同一张画布里能拖的面板，不是操作系统窗口，和游戏里的背包浮窗一个做法。

- 标题：「规则 [n] · <拥有者 id>」；标题栏右边是「关闭」。
- 标题下一行：**实时预览** `Glossary.rule_text(rule)`，每次改动刷新 —— 作者改扳机时立刻看见句子怎么变。
- 正文是一个 `TabContainer`，三页：
  | 页签 | 内容 | 用现有的什么 |
  |---|---|---|
  | 触发 | 上：扳机（类型下拉 + 字段）；下：节奏（类型下拉 + 字段） | `_object_section(rule, "trigger")`、`_object_section(rule, "cadence")` |
  | 消耗（k） | 显式消耗卡片 + 添加；底部一行灰字「扳机隐含：耗耐力 N」（`trigger.implied_costs()`，只读） | `_array_section(rule, "costs")` |
  | 效果（k） | 效果卡片（类型下拉、↑↓删）+ 添加 | `_array_section(rule, "effects")` |
  页签名带条数，改动后刷新。
- 弹窗里的表单就是 `PropertyForm.create(rule, …)`，所以**改动直接写进规则对象**（和整个编辑器一样所见即所得），经 `changed` 信号传回上级表单 → 编辑器照常刷新校验、JSON、预估 DPS；列表那一行的文字在每次改动后重算。
- 关闭方式：「关闭」按钮、Esc、点浮窗外面。关了列表选中行不变。
- 同一时间只开一个弹窗：再双击另一行就换内容（位置不动）。位置按 `FloatingWindow` 的 key（`"rule_window"`）记住。
- 弹窗挂在哪：`AuthoringEditor` 建一层铺满整个编辑器的 `Control`（`mouse_filter = IGNORE`，只在弹窗开着时打开 `STOP` 当「点外面关闭」的接收层），通过 `PropertyForm.popup_layer` 交给表单，子表单像 `parent_target` 那样继承。**没有 `popup_layer` 的表单**（测试里裸建的、将来别处嵌的）退回现在的内联卡片，所以 `_array_section` 的旧分支不删。

### 2.3 范围

- 只改规则表（元素类是 `AbilityRule`）。四个编辑器里凡是规则表都变（道具的战斗与邻接两处、buff、套装档位、技能）；其他对象数组（`mods`、`on_apply`、`faith_bonuses`……）照旧内联 —— 它们都是一层的，看得清。
- 不改数据、不改导入器、不改 JSON；列表和弹窗只是同一份对象的另一种摆法。
- `Tree`、`TabContainer`、`RuleWindow` 的样子**全走主题默认 / 变体**：121 的棘轮现在是 **135 处，已顶满**（`tests/ui/test_theme.gd:9`），这次一处 `add_theme_` 也不能加；要调样式就在 `UiTheme` 里加变体。

---

## 3. 实施清单（给执行线程）

1. `ui/editor/property_form.gd`：`popup_layer: Control` 属性（`_sub_form` 继承）；`_array_section` 在元素类是 `AbilityRule` 且 `popup_layer != null` 时走 `_rule_list`；`_rule_list` 建 Tree + 按钮行；行文案的三段抽成 `Glossary` 的小函数（`trigger_text` 已有，补 `cadence_text` / `costs_text`，让 `rule_text` 也用它们，一份文案两处用）。
2. `ui/editor/rule_window.gd`：`setup_rule(rule, title, font, skip)`；三页签；预览行；`changed` 信号转发；Esc / 点外面关闭。
3. `ui/editor/authoring_editor.gd`：建 `_popup_layer`，交给 `PropertyForm.create` 之后设置（四个编辑器都从基类拿，不各写一遍）。
4. 测试（`tests/authoring/`）：
   - 带 `popup_layer` 的表单：规则表渲染成 Tree，行数 = 规则数，三列文案与 `Glossary` 一致；不合法的行带「！」。
   - 双击 / 「编辑」打开 `RuleWindow`，三个页签存在且名字带条数；在弹窗里加一个效果 → 原规则对象的 `effects` 多一项、上级表单发了 `changed`、列表那行文字更新。
   - 新建 / 复制 / 删除 / 上移下移改的是原数组。
   - 不带 `popup_layer` 的表单仍是内联卡片（现有 `test_editor_111` 那套不改）。
   - 121 棘轮不超。
5. `docs/reports/README.md` 落地记录。

---

## 4. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 节奏（多久一次）放哪一页 | A 和扳机同在「触发」页（上扳机下节奏）；B 单独第四页「节奏」 | **A**：节奏是「什么时候触发」的一部分，作者只点名了三页 |
| 2 | 列表用什么控件 | A `Tree` 四列（#、时机、消耗、效果），最像 Windows 的详细信息视图；B `ItemList` 一行一句 `rule_text` | **A**：三列对齐后「哪条规则消耗什么、做什么」一眼扫完 |
| 3 | 弹窗里的改动怎么生效 | A 即改即生效 + 「关闭」（和整个编辑器一致，反悔 = 不存盘）；B 改副本，「确定 / 取消」 | **A**：少一套复制 / 回写代码，也不会出现「弹窗里改了但忘了按确定」 |
| 4 | 新建规则默认内容 | A 空规则（列表标「！」），立刻弹窗让作者填；B 预填「自发 + 每 2 秒」 | **A**：不替作者猜扳机；弹窗第一页就是扳机下拉 |
