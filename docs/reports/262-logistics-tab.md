# 262 后勤页：集市、铁匠铺默认就有，和出售并成一页；科技改成解锁高级配方与高级货物

作者（2026-10-27 14:19，游戏反馈小修线）：「铁匠铺和集市应该是默认就有的，和【出售】合并成一页，标签重命名为【后勤】，科技用于解锁高级配方和高级货物」。

## 一、现状

- 左列七个页签：仓库 / 出售 / 集市 / 铁匠铺 / 科技 / 图鉴 / 成就（`ui/game/meta_screen.gd` `TABS`）。261 落地后图鉴、成就并成「书架」，还剩六个。
- 集市、铁匠铺是科技开的：`tech_facility` 构件把科技级数写进 `MetaState.facility_levels`，0 级**不露页签**（`_sync_facility_tabs` / `FACILITY_TABS`），`market_panel` 0 级画空棚 + 「在科技页点出集市就有了」，`smithy_panel` 0 级招牌写「铁匠铺（未开）」。
- 科技「集市」三级 600 / 1200 + 硬木板 2 / 2000 + 钢锭 2 + 钉桶 1，级数 = 4 / 6 / 8 格、素材白 / 绿 / 蓝、三级多一格空包（`data/authoring/base_rules/market.json`）；前置「讨价」。科技「铁匠铺」三级 500 / 1000 + 钢锭 2 / 1800 + 硬木板 2 + 铆钉盒 2，级数 = 能打绿 / 蓝 / 紫的配方；前置「行囊」。「秘银冶炼」「法杖工艺」前置「铁匠铺」1 级（252）。
- 二十张配方里 `level` 1 的十张（短剑、砍刀、长剑、短弓、棉甲、皮甲、圆盾、战锤、银锭、魔法杖），2 级六张，3 级四张；法杖线另吃「法杖工艺」级数，秘银线吃「秘银冶炼」。
- 页面：集市、铁匠铺是 1300 × 950 底图的整页（右列仓库收起，`FULL_TABS`）；出售页是中列的筛选 + 包架，右列仓库露着（双击卖）。

要改的三件事：铺子不用点就有；三页并成「后勤」一页；两项科技从「开铺子」改成「铺子升级」。

## 二、方案

### 2.1 铺子默认就有（1 级）

- `MetaState.facility_level(id)` 改成 **1 + 科技写进来的级数**（`BASE_FACILITY_LEVEL = 1`）；`Market.level` / `Smithy.level` 不动，所有「0 级」分支删掉：`_sync_facility_tabs`、`FACILITY_TABS`、集市空棚签、铁匠铺「未开」招牌、文案 `market.locked` / `market.locked_tip` / `smithy.locked` / `smithy.locked_tip`。
- `GameFlow.after_run_market` 不再判级数，每局回来必换货；`ensure_market` 照旧（老档第一次进基地没货就上一次）。
- 开局就能干的：集市 4 格（白素材 + 绿及以下的药、食物、弹药）；铁匠铺打十张绿配方（魔法杖还要「法杖工艺」1 级，见 §四 2）。基地的钱开局是 0，第一局回来才有得买 —— 不改。

### 2.2 两项科技改义：「高级货物」「高级配方」

id 不改（`market` / `smithy`，存档、测试、树的位置都不用动），改名、改说明、砍掉第一级：

| id | 名 | 英文 | 级 | 钱 | 材料 | 效果 |
|---|---|---|---|---|---|---|
| `market` | 高级货物 | Finer Goods | 1 | 1200 | hardwood_plank ×2 | 集市 → 2 级：6 格，素材到绿 |
| | | | 2 | 2000 | steel_ingot ×2，nail_keg ×1 | 集市 → 3 级：8 格，素材到蓝，另一格空包 |
| `smithy` | 高级配方 | Advanced Recipes | 1 | 1000 | steel_ingot ×2 | 铁匠铺 → 2 级：会打蓝配方 |
| | | | 2 | 1800 | hardwood_plank ×2，rivet_box ×2 | 铁匠铺 → 3 级：会打紫配方 |

- 说明一句不写数字（112）：「集市进更好的货：级数越高，货格越多、素材档次越高」「铁匠铺接更难的活：级数越高，打得出的配方档次越高」。
- `TechFacility.describe_level(k)` 说的是铺子第 k + 1 级（`Market.describe_level(rules, k + 1)` / `Smithy.describe_level(k + 1)`），面板「效果」区照旧逐级列。
- 前置不动：高级货物 ← 讨价；高级配方 ← 行囊；秘银冶炼、法杖工艺 ← 高级配方 1 级（树形不变，不用重排）。
- 源是 `docs/techs.xlsx`（节点页改两行名字 / 说明，等级页删 `market 1`、`smithy 1` 两行，后面的级号减一），跑 `tools/techs_xlsx_to_json.gd` 再 `import_content.gd`，`docs/techs.md` 随之重生成。
- 老档：`tech_levels.market` / `smithy` 原来的 L 直接沿用（新义下铺子级 = L + 1，点过 1 级的人白得一级，不退钱不扣级），只把 3 压到 2（新的级数上限）；`MetaMigrations` 加 v3 → v4 做这一步，`SAVE_VERSION` 4。

### 2.3 「后勤」一页

左列页签：仓库 / **后勤** / 科技 / 书架（261）—— 从七个减到四个。「后勤」里三个分页：集市、铁匠铺、出售，页面本身一个像素不动（集市、铁匠铺照旧整页，出售照旧露右列仓库）。分页怎么切，两种摆法（线框 [262-logistics.html](/mnt/project-files/architecture/262-logistics.html)）：

- **A 左列折叠（推荐）**：「后勤」页签选中时，它底下滑出三颗缩进的小键（集市 / 铁匠铺 / 出售，170 × 44，现成木牌键皮 `BUTTON_HOME` 小号字，选中的按下），别的页签选中时收回。中列、右列和现在完全一样，底图不缩；左列最多 4 × 56 + 3 × 44 + 空，1000 高绰绰有余。零新美术。
- **B 中列顶上一排挂牌**：三块挂牌木签（`BUTTON_SETUP_TAB`，和仓库分页、开局、结算一款，高 60）横在中列顶上，集市 / 铁匠铺底图按「包含」缩到 1300 × 890（约 ×0.94），出售页从挂牌下面起。左列干净，但两张整页底图各缩 6%。

两种都是：进「后勤」落上次看的分页（本次会话内记，第一次是集市）；再点一次选中的「后勤」回家（164 的规矩不变）；分页切到出售时右列显出来、切回集市 / 铁匠铺收起（`show_tab` 里按「页签 + 分页」算 `_right.visible`）。

- `show_tab("market" / "smithy" / "sell")` 留作别名 = 切到后勤 + 那个分页（结算屏、测试、`_on_shelf_double_clicked` 的 `"sell"` 分支都不用改；`tab()` 对别名返回 `"logistics"`，新加 `sub_tab()` 返回分页名）。
- 文案：`meta.tab_logistics`「后勤」/ Logistics；分页名复用 `market.title`、`smithy.title`、`meta.tab_sell`。
- 页签图标 `home/tabs/tab_logistics`（36 × 36 墨色剪影，现成页签同款）→ 美术设计出样；没图前只有字（代码本来就容错）。A 的三颗小键、B 的挂牌都用现成皮，不要新图。

## 三、不做的

- 集市、铁匠铺、出售三页的内部排版、买卖规矩、换货规矩、价钱（251 §二 ～ §四）一律不动。
- 不把「出售」做进集市的摊位里（那要重画 1300 × 950 底图；作者要是想要，另开一轮给 UI替换美术）。
- 不动秘银冶炼、法杖工艺的级数与价钱。

## 四、待定（默认按推荐）

1. 分页切法：**A 左列折叠**（推荐）/ B 中列挂牌。
2. 「法杖工艺」「秘银冶炼」的前置：**照旧要「高级配方」1 级**（推荐，树不动；魔法杖这张绿配方因此要两项科技才会打）/ 改成无前置（两节点变根，树要重排一行）。
3. 老档的 `market` / `smithy` 级数：**沿用、3 压 2**（推荐，白得一级）/ 减一（退回「还没升」，600 / 500 的钱不退）。
4. 「后勤」默认分页：**上次看的，首次集市**（推荐）/ 固定集市。

## 五、改动清单（给执行）

1. `core/meta/meta_state.gd`：`BASE_FACILITY_LEVEL := 1`，`facility_level()` 加 1；`SAVE_VERSION` 4；`core/meta/meta_migrations.gd` `_v3_to_v4` 把 `tech_levels` 的 `market` / `smithy` 压到 2。
2. `core/meta/techs/tech_facility.gd` `describe_level(k)` 说 k + 1 级；`docs/techs.xlsx` 两节点改名、改说明、删第一级 → 跑工具重生成 `data/authoring/techs/market.json`、`smithy.json`、`docs/techs.md`，再 `import_content.gd`。
3. `core/run/game_flow.gd` `after_run_market` 去掉级数判断。
4. `ui/game/market_panel.gd` / `smithy_panel.gd`：删 0 级分支（空棚签、「未开」招牌）；`core/text/ui_text.gd` 删四条 `*.locked*`，加 `meta.tab_logistics`。
5. `ui/game/meta_screen.gd`：`TABS` 改四个（warehouse / logistics / tech / shelf，与 261 合着改，谁先落谁先改）；删 `FACILITY_TABS`、`_sync_facility_tabs`；`SUB_TABS := ["market", "smithy", "sell"]`，`_sub: String`，左列折叠小键（A）；`show_tab` 接别名、按分页算 `_right.visible`；`sub_tab()` 给测试看。`NO_SHELF_TABS` / `FULL_TABS` 改按分页算。
6. 测试：`test_base_market_251`、`test_smithy_251`、`test_meta_full_tabs_251`、`test_recipe_techs_252` 里「0 级没页签 / 没货 / 未开」的断言改成「没点科技也是 1 级、有货、会打绿配方」；新 `test_logistics_262`：没点科技 `facility_level` = 1，`market` 点 1 级 = 6 格；v3 档 `market 3` 升到 v4 变 2；页签四个、后勤下三颗小键只在选中时可见；切 sell 右列显、切 market 收；`show_tab("smithy")` 别名落到后勤 / smithy；无裸字；三档字号左列放得下。
7. 美术设计：页签图标 `tab_logistics` 剪影出样（和现有六枚同款）。

## 六、测试

见 §五 6。全量 + 三档（`PACKSDC_TEXT_SIZE`），基地页截图走查三个分页。

## 七、补（2026-10-27 16:40）：页签只剩三个

261 补充一（作者 16:37）把科技并进书架，所以左列页签是 **仓库 / 后勤 / 书架** 三个，§2.3、§五 5 里的「科技」页签不再单列；其余不变。

## 八、落地记录（2026-10-27，v4.64，PR #368）

执行按 §五 落了，四项待定全按推荐（A 左列折叠；前置不动；老档沿用、3 压 2；默认落上次看的分页）。`MetaState.facility_level` 没点科技是 1，`facility_levels` 里存的就是铺子级（1 + 科技级）；存档 v4，`_v3_to_v4` 把两项科技的 3 压到 2，冻结样本 `tests/fixtures/meta_v3.json`；`techs.xlsx` 已改名「高级货物」「高级配方」、各砍第一级、重生成 JSON；`show_tab` 留 market / smithy / sell 三个别名，`tab()` 返回 "logistics"，`sub_tab()` 返回分页。同一 PR 还合了商店钱袋 A 与测试线报的 v4.63 三处小修。全套 34064 项断言通过，截图 `/mnt/project-files/art/ui/logistics262/landed/`。页签图标：作者 16:39 选 **C 货车**（美术设计 `art/ui/logistics262/out/`，已交执行）。

**补充二（16:45，架构定）**：科技树第 0 列的段头签本来就叫「后勤 / Logistics」（`tech.col_0`），现在和页签同名；那一列是仓库扩建 / 保险箱 / 行囊 / 高级配方 / 秘银冶炼，改叫 **「营造 / Works」**，只改这一条文案，派执行顺手带。

**§七 / 补充二落地（v4.66，PR #370）**：左列只剩 仓库 / 后勤 / 书架，`tech.col_0` 改「营造 / Works」。262 到此全部落地。

**作者确认（2026-10-27 17:18）**：「后勤的页线框按你推荐来」—— 分页切法 A 左列折叠，v4.64 已按此落地，不改。
