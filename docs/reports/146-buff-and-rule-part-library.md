# 方案：buff 与规则构件（扳机 / 节奏 / 消耗与检查 / 效果）变成可存、可选的库

日期：2026-10-09　状态：架构 · 提议（待作者确认后交「架构方案执行」）　承接：145（规则列表 + 弹窗）

作者原话（2026-10-09）：

> 首先，buff 应当是个结构体或者抽象类的实现对象，可以新建 buff 并储存，消耗、触发时机同理。所以，当选择消耗、触发时机、检查、效果等等时，出现下拉菜单，里面储存了现有的所有同类对象，可供选择。所以需要增添独立的 buff 编辑器，提供多种选择

---

## 0. 结论（一段话）

两件事。**一，buff 成为真正的独立内容**：`data/authoring/buffs/<id>.json` 一份一个，进导入管线、排在道具之前；道具里写 `"buff": "bleed"` 按 id 引用（导入器这条路早就留着，只是一份文件都没有）；现有道具里内联的 19 份 buff（10 个 id，流血、中毒各重复 5 份）用一次性工具抽成文件、道具改成引用；buff 制作器本来就有，这样一改它的列表就不再是空的。**二，扳机 / 节奏 / 消耗（含检查）/ 效果也能存进库**：新内容种类「规则构件」`data/authoring/rule_parts/<id>.json`，一份就是一个带 id 和名字的构件对象；规则里的 `trigger` / `cadence` / `costs[i]` / `effects[i]` 可以写成 `"@<id>"` 引用它，导入时**复制一份**进规则（运行时一行不改）。编辑器里凡是选类型的下拉（145 弹窗三页里的、buff 制作器里的）分成两组：「新建一个：<各类型>」与「用库里的：<各构件>」；`apply_status` 的 buff 字段变成下拉列出库里的 buff；指向 buff id 的字段（`remove_status.buff_id`、`status_condition` 等）下拉列出已知 id。库自己由新的「构件编辑器」维护（列表分四页：扳机 / 节奏 / 消耗与检查 / 效果，每条一张表单 + 一句预览）。

---

## 1. 现状

| 事实 | 出处 |
|---|---|
| `ApplyStatus.buff` 是一个 `BuffDef` 对象，道具 JSON 里整份内联 | `core/battle/effects/apply_status.gd:8`；如 `items/blessed_longbow.json` 的 `"buff": {…}` |
| 导入器**已经**接受 `"buff": "<id>"`，到 `ctx.buffs` 里查；查不到报「找不到增益」 | `content_importer.gd:1797-1802` |
| 但 `buffs` 种类在 `EDITOR_ONLY_KINDS`，目录不存在、不在 `ORDER` 里，所以 `ctx.buffs` 永远是空的，引用那条路**一次也没用过** | `content_paths.gd:101-107`；100 的决定（当时一份独立 buff 都没有） |
| 道具库里内联了 19 份 buff，10 个 id；`bleed`、`poison` 各 5 份、`marked` 2 份，同 id 的内容完全相同（脚本扫过） | `data/authoring/items/*.json` |
| buff 制作器存在（085 / 141），列表来自 `buffs` 目录 → 空 | `ui/buff_editor/buff_editor.gd`，`AuthoringEditor._rescan` |
| 百科的 buff 页靠扫全部道具里内联的 buff 凑出来 | `core/text/encyclopedia.gd:129 _all_buffs` |
| 扳机 12 种、节奏 2 种、消耗与检查 9 种（`*Condition` 就是作者说的「检查」）、效果 11 种，都只有**类型**注册表，没有**实例**库；每条规则现场填 | `core/battle/triggers/`、`cadences/`、`costs/`、`effects/`；`ContentSchema.ABSTRACT_ROOTS` |

所以「选的时候下拉里有现成的」今天只对**类型**成立，对**填好数值的对象**不成立；重复的「每 2 秒」「造成物理伤害」「施加流血」每件道具都重新填一遍。

---

## 2. 方案一：buff 成为独立内容

1. `ContentPaths`：`buffs` 从 `EDITOR_ONLY_KINDS` 搬回 `KINDS`，`ORDER` 里排在 `items` 之前（100 当年就写明：有第一份独立内容就搬回去）。`sets` 不动。
2. 导入：`import_buff` 照旧登记进 `ctx.buffs`；道具里 `"buff": "bleed"` 走现有的字符串分支。**内联仍然允许**（只被一件道具用的 buff 不必单开文件），但两种写法都要过同一套校验（时长规矩、轴候选提醒）。
3. 导出：`ContentExporter` 导出 `apply_status` 时，若 `buff.id` 在库里**且内容与库里那份一致**，写 `"buff": "<id>"`；否则整份内联。「一致」用 `ContentCheck` 已有的深比较。这样编辑器存盘、一致性检查、导出器三处说法相同。
4. 一次性迁移工具 `tools/extract_buffs.gd`：扫全部道具，同 id 的内联 buff 内容一致 → 写一份 `buffs/<id>.json`，道具改成引用；内容不一致 → 不动，列出来让作者定（现在没有这种情况）。跑完 `import_content`，`.tres` 跟上。
5. 百科 `_all_buffs`：库里的全部 + 道具里仍内联的；「来自哪些道具」照算。
6. buff 制作器：列表自动有了 10 条；`rules` 表单走 145 的列表 + 弹窗；新增一个按钮「从道具里抽出」不做 —— 迁移工具一次管完，以后新 buff 直接在制作器里建。
7. 指向 buff id 的字段（`RemoveStatus.buff_id`、`StatusCondition.buff_id`、`OnStatusApplied` / `OnStatusRemoved` 的 id、`StatusStackCost`……）：`PropertyForm` 加一条「buff id 字段」识别（字段名 `buff_id`，或 `FieldText` 里登记），用现有的 `_key_picker` 列出库里的 id + 道具里内联的 id，也能手填。

## 3. 方案二：规则构件库

### 3.1 数据

- 新种类 `rule_parts`：`data/authoring/rule_parts/<id>.json` ↔ `data/rule_parts/<id>.tres`，资源类 `RulePartDef { id, display_name, display_names, part: Resource }`，`part` 是 Trigger / Cadence / Cost / CombatEffect 之一（JSON 里照常 `"part": {"type": "on_status_applied", …}`）。一个种类四类对象，列表按类分组即可，不开四个目录。
- 规则里引用：字段值写字符串 `"@<id>"`（`"trigger": "@bleed_applied"`、`"effects": ["@physical_hit", {"type": "apply_status", "buff": "bleed"}]`）。`@` 前缀与 buff 的裸 id 区分开，一眼看出是构件引用。
- 导入顺序：`buffs` → `rule_parts` → `items` …。构件里的 `apply_status` 可以按 id 引用库 buff；**buff 自己的规则不能引用构件**（否则循环），导入器报「buff 的规则请内联」。
- 导入：遇到 `"@id"` 到 `ctx.rule_parts` 查，**`duplicate(true)` 一份**放进规则，并 `set_meta("part_ref", id)`；类不匹配（把扳机填进 effects）报错。运行时拿到的还是普通对象，`BattleSim` / `CombatantRuntime` 一行不改。改库里一个构件、重新导入，所有引用它的规则一起变 —— 这就是库的意义。
- 导出：对象带 `part_ref` 且内容仍与库里一致 → 写 `"@id"`；被改过 → 整份内联（相当于「断开」）。

### 3.2 编辑器

- **类型下拉（`PropertyForm._adder`、`_object_section` 的「添加」）**分两组：先「新建：」各类型，再分隔线，再「库：」该基类下的全部构件（显示名 + 预览句 `Glossary` 的 `trigger_text` / `cadence_text` / `Cost.describe` / `effects_text`）。选库项 = 复制 + 打 `part_ref`。
- **带 `part_ref` 的卡片**：标题改成「来自库：<名字>」，字段**只读**（表单灰掉），右边两个小按钮：「断开」（去掉 meta，字段可编辑，存盘后内联）、「去库里改」（打开构件编辑器定位到它）。不做「改了自动断开」—— 作者要明确知道自己改的是这一件还是整库。
- **`apply_status.buff`**：从「添加 / 清除 + 子表单」改成下拉：库里的全部 buff + 「内联…」（建一个空 `BuffDef` 子表单，老写法）。选了库 buff 的字段只读，旁边「去 buff 制作器」。
- **构件编辑器**（新，`ui/part_editor/part_editor.gd`，继承 `AuthoringEditor`，`_kind = "rule_parts"`）：左列表按类分四页（扳机 / 节奏 / 消耗与检查 / 效果，144 的分组行做法）+ 搜索；中间：id、名字、类型下拉、字段表单（`PropertyForm`，`part` 用现有 `_object_section`）、顶上一句预览；右边校验与 JSON（基类都有）。再加一个只读的「谁在用」列表（扫道具 / buff 的 `part_ref`），删构件前看得见影响。
- 145 的 `RuleWindow` 三页不改结构，只是里面的下拉多了「库：」一组。
- 启动器多一个入口「构件编辑器」。
- 全部走主题默认 / 变体：121 棘轮已顶满 135，不得新增 `add_theme_`。

### 3.3 首批构件（迁移工具一并抽，作者可改）

迁移工具第二步：扫全部规则，**完全相同**的扳机 / 节奏 / 消耗 / 效果出现 ≥ 3 次的，抽成构件并把原处改成 `"@id"`（id 用类型 + 关键参数生成，名字留占位让作者改）。预计命中：「每 N 秒」几种节奏、`always`、「造成物理伤害」、「施加流血 / 中毒」、「耗耐力 N」。只出现一两次的不抽。工具输出清单，作者确认后再提交。

---

## 4. 实施清单（给执行线程）

1. `core/battle/rule_part_def.gd`；`ContentPaths`（buffs 搬回、新增 rule_parts、ORDER）；`ContentRegistries` 若需登记。
2. 导入器：`import_rule_part`、`"@id"` 解析 + `part_ref` + 类检查 + buff 规则禁用构件；导出器：buff 引用与构件引用的回写；`ContentCheck.KINDS` / `export_of` 两种新内容。
3. `tools/extract_buffs.gd`（含 3.3 的构件抽取，两步可分开跑）；跑完提交数据与 `.tres`。
4. 百科 `_all_buffs`；`Glossary.buffs_in_item` 仍对内联有效。
5. `PropertyForm`：下拉分组、`part_ref` 只读卡片 + 断开 / 去库里改、`apply_status.buff` 下拉、buff id 字段的 `_key_picker`。
6. `ui/part_editor/`、启动器入口、`tests/ui/test_theme` 的编辑器目录清单加上它。
7. 测试（`tests/authoring/`）：buff 引用导入 / 导出往返一致；内联 buff 仍可导；`"@id"` 复制进规则且带 `part_ref`、类不匹配报错、buff 规则引用构件报错、改过的构件导出成内联；迁移工具对现有数据跑完后导入全绿、`ContentCheck` 一致、战斗数值对比迁移前后相同（抽几件带 buff 的道具算 `estimated_dps`）；编辑器下拉列出库项、选中后字段只读、断开后可改；121 棘轮不超。
8. `docs/architecture.md` 4.5（buff 是内容）、10.4（编辑器清单）；`docs/reports/README.md` 落地记录。

---

## 5. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 用了库构件的卡片改动怎么算 | A 字段只读 + 「断开」按钮，断开后才能改；B 可直接改，改了自动变成内联 | **A**：改的是「这一件」还是「整库」要作者自己说，不能靴子一踩就断 |
| 2 | 构件库的存法 | A 一个种类 `rule_parts`，四类对象混放，列表按类分页；B 四个种类四个目录 | **A**：少三套管线登记，分页已经够看 |
| 3 | 构件编辑器放哪 | A 新的独立编辑器「构件编辑器」；B 并进 buff 制作器当几个页签 | **A**：buff 制作器有自己的字段（叠层 / 时长），混在一起又杂了；作者也点名要独立 |
| 4 | buff 自己的规则能不能用库构件 | A 不能（导入顺序 buff → 构件 → 道具，无循环）；B 能，导入器做两遍解析 | **A**：buff 内部的规则（每秒掉血）本来就不共用 |
| 5 | 迁移抽构件的门槛 | A 完全相同且出现 ≥ 3 次才抽；B 只抽 buff，构件全由作者手建 | **A**：先有几十个现成的，下拉才有东西可选 |
