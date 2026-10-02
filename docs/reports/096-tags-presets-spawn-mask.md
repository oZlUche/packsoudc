# 096 · 标签 / 伤害类型是内容（多语言）、开局预设套、挑出生点的遮罩、信仰词条白 / 灰、两处反馈

作者这一轮七条（按到达顺序）：

1. 道具的标签与属性（物理 / 火焰）也作为数据储存，要做到多语言（中英，可扩）。
2. 开局加一个遮罩：全图除出生点外变灰不可点，选了出生点再取消。
3. 开局预设装备的选项，默认两套（伤害高 / 防御高），可扩。
4. 减伤是否支持减不同属性的伤害？（问）
5. 预设装备也许可以在出生点挑：出生点自带一次随机搜索（稀有度不高、必有一两件武器）。（想法，等拍板）
6. 毒药瓶不是武器，不消耗耐力。
7. 搜索遇敌打赢后战利品被跳过、直接回到事件。（bug）
8. 信仰效果词条：激活时白、未激活灰。

## 目标

名字与说明**跟着内容走**（088 的原则：内容的名字在内容里，界面的文字在 UiText 里）：标签、伤害类型、属性键这三类此前都是 `Glossary` 里写死的中文表，现在前两类成了内容种类，第三类补了英文。开局屏多一栏预设套；地图屏挑出生点时蒙一层；悬浮窗的信仰加成按局里的状态上色；修两处反馈。

## 产出

### 一、标签与伤害类型是内容（多语言）

| 文件 | 职责 |
|---|---|
| `core/inventory/tag_def.gd` | **新** `TagDef`：`id / display_name / display_names / description / descriptions` |
| `core/inventory/tag_registry.gd` | **新** `TagRegistry`：静态表，第一次用到时从 `data/tags` 装回；`name_of(id, lang)`、`describe(id, lang)`、`ids()`、`register`、`reset` |
| `core/battle/damage/damage_type_def.gd` | `DamageTypeDef` 多 `display_names / description / descriptions` |
| `core/battle/damage/damage_types.gd` | 装回 `data/damage_types`，**同 id 覆盖内置**（名字、说明、三个性质都以数据为准，内置只是兜底）；`name_of` / `describe` / `load_dir` |
| `core/text/names.gd` | `Names.description_of(obj, lang)`：`descriptions[lang]` 没有回落 `description`（和 `Names.of` 同一条路） |
| `core/text/glossary.gd` | `TAG_NAMES / DAMAGE_TYPE_NAMES` 两张表**删了**：`tag_name` 走 `TagRegistry`（`faith:<id>` 写成「信仰：神名」）、`damage_type_name` 走 `DamageTypes`；`STAT_NAMES / CATEGORY_NAMES` 改成 zh / en 两列，`stat_name` 按 `UiText.lang`；新 `tag_terms(tags)`（登记了说明的标签 → 词条） |
| `core/authoring/content_paths.gd` | 种类 `tags`、`damage_types`（`data/authoring/tags`、`data/authoring/damage_types` → `data/tags`、`data/damage_types`），排在 `ORDER` 最前 |
| `core/authoring/content_importer.gd` | `import_tag`（id 不能空 / 带冒号或空格，得有名字）、`import_damage_type`（id、名字）；`Context.tags`；**道具带没登记的标签只警告**（`_validate_item_tags`，`faith:<id>` 不算）—— 随手加的词照样能用，登记了才有名字、别的语言和词条 |
| `core/authoring/content_exporter.gd`、`tools/import_content.gd`、`tools/normalize_content.gd` | 两个新种类的导入 / 导出 / 往返 |
| `core/authoring/field_text.gd` | 类名标签「标签」「伤害类型」；字段 `provokes`「招致反应」 |
| `ui/inventory/item_tooltip.gd` | 标签一行按名字写（之前是原词：`weapon、melee`）；包的准入 / 槽的过滤标签同；**标签的说明进词条侧窗** |
| `core/battle/effects/deal_damage.gd` | `describe()`「造成 火焰 伤害」用名字 |
| `ui/editor/property_form.gd` | 标签数组旁一个「加标签…」下拉（登记过 + 内容里用过的，显示「武器 (weapon)」，选一个追加到那一行）；`damage_type` 字段、指向一个标签的字段（`item_tag` / `weapon_tag` / `tag`）下拉 + 自定义；`_stat_picker` 抽成通用的 `_key_picker` |
| `data/authoring/tags/*.json`（39 份） | 道具里出现过的全部标签 + 信仰看重的 `flesh`：中 / 英名字、一句说明（中 / 英） |
| `data/authoring/damage_types/*.json`（6 份） | 物理 / 火焰 / 中毒 / 流血 / 反伤 / 流失：名字（中 / 英）、说明（中 / 英）、三个性质 |

加一种语言：每份 JSON 的 `display_names` / `descriptions` 加一个键（`"fr": "..."`），`UiText.LANGS` 加一项，别处不动。
加一个标签：道具上写就能用；想要名字就在 `data/authoring/tags` 加一份 JSON（导入器会提醒哪些没登记）。
加一种伤害类型：`data/authoring/damage_types` 加一份，结算代码一行不改（4.6 的承诺，现在连登记都是数据）。

### 二、挑出生点的遮罩

`ui/map/map_view.gd`：`spawn_mask`。开着时整张图盖一层底色（0.8），只把出生点重新画在上面（呼吸的绿环），顶上一行「挑一个出生点」；`node_at` 只命中出生点（别的点点不中、悬停不亮）。`ui/game/map_screen.gd` 在接线与阶段变化时按 `phase == PICK_SPAWN` 开关 —— 章节 `auto_spawn` 的（序章）从不出现。

### 三、开局预设套

| 文件 | 职责 |
|---|---|
| `core/run/loadout_def.gd` | `preset: bool`（开局屏可选的预设套）、`display_names`、`descriptions` |
| `core/authoring/content_importer.gd` | 预设套**不用带包**（角色的初始包装它）；非预设仍要 |
| `core/run/game_flow.gd` | `presets()`（`preset == true` 的）、`default_loadout()`（第一套非预设：老路 / 仓库空的第一套）；开发工具里三处 `loadouts[0]` 改走它 |
| `ui/game/setup_screen.gd` | 角色之下一栏「预设装备」：不带 / 每套一个按钮（悬停看说明）。`choose_preset(i)`：拿掉原来那套，新的免费放进初始包（放不下的在状态栏说）；`preset_items()`；预设的**不算带入**（`carried()` 排掉 → 不占预算、不受件数上限）、拖不进仓库 / 暂存区（`_allow_drop`、`carry_out`）、换角色重摆跟着；说明栏写预设的一句；读数写「预设套 n 件（不算预算）」；出发时整块棋盘照旧成 layout 带走 |
| `data/authoring/loadouts/preset_offense.json` | **强攻**（Assault）：长剑、剁刀、匕首、伤药 —— 7 格，伤害高甲薄 |
| `data/authoring/loadouts/preset_defense.json` | **坚守**（Bulwark）：圆盾、皮甲、匕首、伤药 —— 10 格，护甲 7 |

两套都按三个角色的初始包能装下来配（马库斯是 2×3 + 2×2 = 10 格，坚守刚好）。再加一套：`loadouts` 里加一份 `preset: true` 的 JSON。

### 四、信仰加成词条白 / 灰

`ui/inventory/item_tooltip.gd`：静态探针 `faith_probe`（局里由 `GameFlow._adopt` 接上、`to_main_menu` 摘掉），返回 `{active, tier, points}`。每条信仰加成（现在按 `gate_text` 写「信力激活即 / 第 2 阶 / 每 50 信力一份」）：这件的神正激活着且 `times_for(tier, points) > 0` → 白，否则灰；「信仰道具」那行追加状态 ——「现在已激活（Lv.n）」/「现在休眠」/「还没激活（要信物）」。局外（基地、沙盒）没有探针，原色。

### 五、两处反馈

- **毒药瓶**：规则里的 `costs`（耐力 2）删了。它不是武器，每 4 秒下一层毒，不花耐力。
- **搜索遇敌打赢 → 战利品被跳过**：根因在 `GameFlow` 的 `event_pending` 接线 —— 084 为了「余波」事件（说刚发生的事）把排在队尾的战利品前面插事件；打赢后「再搜 / 走」那一屏也被这条规则插到了战利品前面，回放一完就回到事件。现在 pending 带 `search_stage` 的不插队：回放 → 战利品 → 事件屏，战利品一件没丢（之前也没丢，只是顺序让人以为跳过了）。

### 六、第 4 条的答案：减伤支持按伤害类型

**支持，走规则**：`on_before_damage` 扳机有 `damage_type` 过滤，配 `modify_damage`（固定 / 百分比 / 反转 / 免疫）就是「只减某种伤害」—— 解毒剂「中毒伤害反转成治疗」就是这么写的。**不支持的是属性形式**：护甲（`armor`）是唯一的无条件减伤属性，不分类型。
要「火抗 20%」这种能被 buff / 套装 / 邻接加的属性，建议加一组 `resist_<type>` 属性（百分比，`DamageResolver` 第 4 步在护甲前按类型查一次），数据里各类型一个键、编辑器下拉自动出现。一行结算 + 一个属性名约定，等作者一句。

### 七、第 5 条：出生点自带一次搜索（想法）

两条路：**替代**（预设套不要了，出生点搜一次给底线）或**并存**（预设套是确定的底线、出生点搜索是随机的加餐）。我的判断在回复里；这一步没动代码。实现成本不高：`SearchRules` 已有稀有度权重与件数，差一个「保底 n 件带某标签」（`DropRule.rarity_guarantee` 的标签版）与在 `pick_spawn` 之后开一次只属于出生点的会话。

## 测试

`tests/test_author_096.gd`（7 个用例）：标签数据（装回数、中英名、说明、没登记、`faith:<id>`、词条、属性名英文、`description_of`）；伤害类型数据（覆盖内置、性质来自数据、`deal_damage` 说明、英文）；导入器（标签 / 伤害类型校验、没登记只警告、预设套不用包）；悬浮窗标签按名字 + 标签词条；信仰加成白 / 灰（五种状态）；毒药瓶无消耗；搜索遭遇打赢先看战利品；编辑器三种下拉（帧测试）；开局屏预设套 + 地图遮罩（帧测试：两套、不算带入、拖不进仓库、强攻 DPS > 坚守 / 坚守护甲 > 强攻、换套 / 换角色、出发带走；遮罩下只有出生点点得中、挑完撤掉）。
`tests/test_text_and_tooltips.gd` 的「写了标签」改成按名字。

## 留给作者

- 39 个标签与 6 种伤害类型的中 / 英名字与说明是我写的占位，尤其英文；`rapid / burst` 我按打法写成「快攻 / 重击」。
- 两套预设的清单（强攻 7 格 / 坚守 10 格）与「预设不算预算」是我的取舍；要算进预算只需 `carried()` 不排掉它。
- 第 4 条的 `resist_<type>` 属性、第 5 条的出生点搜索，等一句。
- 词条侧窗、`Glossary.TERMS` 固定词条、`mod_text` 的「、」与「（无效果）」仍是中文；界面文字逐屏换 `UiText` 是 15 节的待办。
