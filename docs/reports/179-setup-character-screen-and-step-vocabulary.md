# 179 · 选角色屏重排（三栏等距、图标牌、技能名描边、大厅背景）；「行动点」一词退役，倒计时只按「步」说

> 作者 2026-10-16 17:33（附选角色屏截图）：「将这个界面改成右侧棋盘右对齐，中间角色的说明字体放大，增加一个背景板，设计一个排版给我看」；18:57 看过第一版样稿后：「中栏可以更大，尽量保证和棋盘列之间不留太多空隙，或者至少让左中右三个界面之间的距离同等。负重上限、棋盘、开局金币统一用图标替换且更显眼。整体背景做一个和类似选人的大厅或者操场。角色说明删掉。技能名称用不同的颜色加粗和/或描边展示，且字体放大。技能说明只留对功能描述的部分，且尽量用书面标准用语（头一回输给节点敌人→首次战败于敌人时）。另外我看到行动点机制还在，这没有意义，已经有倒计时机制了，删掉它。棋盘下方不需要显示有哪些背包，这是无用信息。必要的部分让美术线程合作」。
> 2026-10-17 07:51 补一句：「【被动】这两个字也可以去掉」（已并入 §2.3 第 4 条与样稿）。
> 样稿（第二版，按 18:57 的意见改好）：https://claude.ai/artifact/H48xiaZYqKDMEzW86AF8sZ 。性质：界面 · 实施 + 文案 + 一处机制词汇清理。待定按推荐。关联 161（开局三页）、157 补充三（整块石板）、170（提示框图标）、150（HUD 组件）、092（倒计时）、136（熟门熟路）、177（结算屏）。

## 1. 现状

`ui/game/setup_screen.gd` 第一页 `_build_character_page`：一行三栏，间距 36；左栏 260（「角色」+ 角色按钮），中栏 `_card` 固定 420（名牌、13 号灰字说明、生命 / 耐力 / 体力方块行、「一块 10 点」提示、`caps_text` 一行「负重上限 40　棋盘 7 × 6　开局钱 120」、`skill_lines()` 每条 13 号一行），右栏 `_preview_host` 紧跟中栏（`SIZE_SHRINK_BEGIN`，不贴右缘），棋盘下面一行「背包：皮革包 × 2」。三页都坐在 157 补充三的整块石板上（`_slab_screen`），板外纯色底。

「行动点」：游戏里**只有一个计时器**。`ActionClock`（`MapTravel.clock`）数的是走步花掉的代价（边的 `action_cost`，通常 1；传送按 `portal_cost`；寸步难行 ×2；扎营 / 等人原地耗），倒计时 = `step_limit − clock.total`（092，`CountdownModule.left()`），侵蚀和猎手也按这个计数推进。所谓「行动点」只是这个计数的**叫法**，不是另一套机制。它出现在玩家眼前的地方：开局屏熟门熟路一行、结算屏「行动点 N」一行（177 第一步也沿用）、基地战绩「行动点 N」、地图屏预览「→ 休息区　花 1 行动点」、事件屏「耗了 N 个行动点」与代价图标「耗行动点」、寸步难行的词条、八页帮助、HUD 的「行动点」组件（150，默认藏着但布局里还有），以及负重第三级的描述「走一步花 2 倍行动点」。

## 2. 选角色屏排版（样稿第二版）

### 2.1 三栏

| 栏 | 宽 | 做法 |
|---|---|---|
| 左 | 260 | 不变 |
| 中 | 撑满（1600 宽下 = 776） | `_card.size_flags_horizontal = SIZE_EXPAND_FILL`，去掉 `custom_minimum_size.x = 420`；折行宽按实际宽度减内边距 |
| 右 | 420（7 格 × 60；按角色棋盘宽算） | 贴行的右端：`_preview_host.size_flags_horizontal = SIZE_SHRINK_END`；列内左对齐 |

三栏间距一律 36（`_hbox(36)` 已是）。每栏各坐一块**凹槽式底板**：比背景更暗的板身、细黄铜边、内阴影；按 157 补充三是「同一块板上的凹槽」（`panel_inset` 那种），不是第二块石板。内边距：左 14 / 10，中 24 / 30 / 28，右 10。

### 2.2 背景

开局三页**不再用整块石板**（`_slab_screen`），改成整屏一幅「选人大厅 / 操场」的画（1920 × 1200 cover，tone dark，`assets/ui/setup/bg_hall.png` + json），三页共用；标题行仍在左上角 36 / 36，白字带阴影。画由 美术设计 出（§5）；画没到之前先用纯色底，不挡落地。

### 2.3 中栏内容（自上而下）

1. 名牌：不变（名字 24、头像 72）。
2. 生命 / 耐力 / 体力方块行：标签 15 → 17，「每秒回 N」12 → 14，方块尺寸不变；「一块 10 点」提示 11 → 12 灰。
3. **三块图标牌**（替换 `caps_text` 那一行）：等宽横排，每块 = 图标 40 + 数字 28 粗体 + 说明 13 灰：秤砣「负重上限」、棋盘格「棋盘 7 × 6」、金币「开局金币」。秤砣与金币沿用 170 的 `assets/ui/tip/weight.png / coin.png`（要 40 px 版，§5），棋盘图标新画。`caps_text` 里另两项（最多带 N 件、稀有度不超过 N）只有有值时才出现，仍按文字补在牌下面一行（现状三人都没有）。
4. **技能**：每条两行——第一行只有技能名 **22 号粗体、亮黄铜色（`UiPalette.BTN_PRIMARY_HOVER` 一档）、黑描边**（`UiTheme.OUTLINE_SIZE / OUTLINE_COLOR`，170 已有），**不写「被动」**（作者 2026-10-17 07:51：「【被动】这两个字也可以去掉」；`skill_lines()` 的「被动：」前缀这一屏不用）；第二行说明 17 号正文色，行高 1.5。主动技能照 166 补充一仍藏着（`RunSkills.ACTIVE_HIDDEN`）。
5. **角色说明删掉**（`Names.description_of(ch)` 不再放在这一屏；字段本身留着给图鉴 / 帮助，待定 2）。

### 2.4 右栏

「棋盘　7 × 6 格」+ 棋盘预览；**删掉「背包：皮革包 × 2」一行**（`bags_text` 这一屏不再用；第二页的装备行还用得着的话留着）。

### 2.5 技能说明改书面功能句

规则：只写功能，不写来历、口语、比喻；主语省略；条件用「……时」；数字仍走 `{占位}`。`CharacterDef._skill_line` 的格式改成「名 + 换行 + 说明」由界面排（主动技能的次数 / 冷却仍附在说明末尾）。

| 角色 | 技能 | 现文案 | 改后 |
|---|---|---|---|
| 安德烈乌斯 | 熟门熟路 | 奴隶探索者月月进来，路都认得：每走 {travel_discount_every} 步，下一步不花行动点。 | 每走 {travel_discount_every} 步，下一步不计入倒计时。 |
| | 溜得掉 | 猎手更难发现你，从猎手面前逃跑更容易；头一回输给节点敌人不扣体力。 | 猎手更难发现你，从猎手面前逃跑更容易；首次战败于敌人时不扣体力。 |
| | 脱身（藏） | 开战前溜走：这一场不打、不扣体力、也没有战利品，点算用过（核心点溜不掉）；猎手面前用，必定逃掉。 | 开战前脱离：不战斗、不扣体力、无战利品，该点视为已用（核心点不可用）；对猎手使用必定逃脱。 |
| 布鲁图斯 | 野地里长大 | 休息时多回 {rest_bonus_amount} 点体力；侵蚀扣体力时少扣 {erosion_resist_amount} 点。 | 休息时额外恢复 {rest_bonus_amount} 点体力；侵蚀扣除体力时减少 {erosion_resist_amount} 点。 |
| | 坚韧 | 战斗里生命掉到三成以下时，立刻得到一层护甲（每场一次）。 | 战斗中生命低于三成时，立即获得一层护甲（每场一次）。 |
| | 咬牙（藏） | 在地图上咬咬牙，恢复 {amount} 点体力。 | 在地图上恢复 {amount} 点体力。 |
| 马库斯 | 军功 | 收获换军功：打赢的钱多四分之一。 | 战斗胜利所得金币增加四分之一。 |
| | 操练 | 耐力掉到两成以下时，立刻回 {change_resource_amount} 点耐力（每场一次）。 | 耐力低于两成时，立即恢复 {change_resource_amount} 点耐力（每场一次）。 |
| | 突击（藏） | 下次进入战斗，先扣掉对方三成生命。 | 下次战斗开始时，先扣除敌方三成生命。 |

三人的 `description`（角色说明）这一屏不显示，文案不动。

## 3. 「行动点」一词退役

作者的话是「删掉它」。机制上没有可删的第二套系统（§1）：删掉 `ActionClock` 就没有倒计时、侵蚀、猎手的推进。能删、也该删的是**这个词和它的独立展示**：玩家眼里只有「倒计时」和「步」，走一步就是一步，特殊代价一律说成「计 N 步」。

### 3.1 词汇表

| 现在 | 改后 | 在哪 |
|---|---|---|
| 行动点 N（结算屏、基地战绩） | 走了 N 步 | `result_screen.gd` 86（177 第一步同一行）、`meta_screen.gd` 269 |
| → 休息区　花 1 行动点 | → 休息区（代价 1 不写）；代价 >1：→ 传送　计 2 步 | `map_screen.gd` 602 |
| 耗了 N 个行动点 / 原地耗了 N 个行动点 | 耗了 N 步 / 原地耗了 N 步 | `event_screen.gd` 105、`map_screen.gd` 371 |
| 代价图标「耗行动点」 | 「耗步」 | `event_cost_icons.gd` 15 |
| 耗 N 个行动点（`PassTime.describe`） | 耗 N 步 | `core/run/events/outcomes/pass_time.gd` |
| 走一步花 2 倍行动点 | 走一步计两步 | `encumbrance_rules.gd` 77、词条「寸步难行」（`glossary.gd` 36） |
| 每走 N 步，下一步不花行动点 | 每走 N 步，下一步不计入倒计时 | `travel_discount.gd describe`、角色 json |
| 倒计时 N / M（HUD） | 不变（已是「步」的语义）；撤离点「剩 N 步关闭」不变 | `countdown_widget.gd` |
| 调试台「行动点 N」开场白 | 「第 N 步」 | `map_screen.gd` 495 |
| 帮助页八处（`countdown_and_closing / map_and_steps / teleport / vitality / characters / encumbrance / erosion / rest_point`） | 按上表改写：「有倒计时的图只能走这么多步：走一条路按它写的步数减……」「传送点……计的是这条路自己写的步数，通常比一步多」「侵蚀从第几步起……」 | `data/authoring/help_pages/*.json` |
| HUD「行动点」组件 | **删除**：`hud_widgets.gd` 登记表去掉 `action_points`、`action_points_widget.gd` 删、`hud_layout.gd` 默认布局与 `HIDDEN_BY_DEFAULT` 去掉，`VERSION` +1（旧布局文件作废回默认） | `ui/hud/` |

代码里的 `ActionClock / action_cost / portal_cost / action_cost_mult` 等标识符**不改名**（内部词，改名只会制造一轮无意义的 diff；architecture.md 的术语注一句「行动点 = 步，玩家面前只说步」即可）。`docs/architecture.md` 2447 一带的表加一行说明。

### 3.2 不动的机制（待定 3）

边的代价、传送代价、寸步难行 ×2、扎营耗时都照旧，只是改口叫「计 N 步」。若作者要的是「每步都只算一步」，那是另一刀（传送、负重第三级、扎营都要重新给惩罚），不在这份里。

## 4. 测试

- `tests/ui/test_setup_pages_161.gd`：第一页不再有说明标签与「背包：」行；`_card` 横向 EXPAND_FILL；`_preview_host` SHRINK_END；三块图标牌各有数字；技能名节点字号 22 且带描边，文本里没有「被动」。
- 文案扫描：`core / ui / data` 的玩家可见字符串里不再出现「行动点」（白名单：architecture.md、docs/reports、代码注释）。
- `tests/ui/test_hud_150.gd`：登记表无 `action_points`，默认布局不含它；旧版本布局文件被弃用回默认。
- 帮助页、词条、角色 json 改了字，`python3 tools/font_charset.py && tools/subset_fonts.sh`（168）跟着跑；`bash tools/snapshot_content.sh`（173）如果角色 json 的快照纳入了说明字段。

## 5. 给美术设计的清单

1. **背景画**「选人大厅 / 操场」：1920 × 1200 cover，`tone: "dark"`，三页开局屏共用；主体留在画面上下两端和两侧，中段（三栏所在）可以暗一些；交付 `art/ui/setup/bg_hall.png` + json。
2. **三个 40 px 图标**：秤砣（负重）、棋盘格（棋盘）、金币（开局金币）；前两个可从 170 的 `weight / coin` 放大重出；深底上用。交付 `art/ui/setup/icons/`。
3. 技能名的黄铜色 + 黑描边不需要新图，字体本身来做；若美术想给技能名加一条下划纹样，作为可选件另交。

## 6. 待定（默认按推荐）

1. 背景画三页共用（A，推荐）还是只第一页（B）。
2. 角色 `description` 字段：A 保留（图鉴 / 帮助还用得着，推荐）；B 连字段一起删。
3. 行动点：A 只退词、机制不动（推荐，§3）；B 所有代价扁平成 1 步（另开方案）。
4. 图标牌的数字字体：A 正文粗体 28（推荐）；B 用 `display_font`（马善政）。

## 7. 改动范围

`ui/game/setup_screen.gd`（第一页布局、底板、图标牌、技能两行）、`ui/game/game_screen.gd`（开局屏背景走画不走石板，或新 `_painted_screen`）、`core/run/character_def.gd`（`_skill_line` 拆名 / 说明）、三个角色 json、`core/run/effects/travel_discount.gd`、`core/run/events/outcomes/pass_time.gd`、`core/run/encumbrance_rules.gd`、`core/text/glossary.gd`、`ui/game/{result_screen,meta_screen,map_screen,event_screen,event_cost_icons}.gd`、`ui/hud/{hud_widgets,hud_layout}.gd` + 删 `widgets/action_points_widget.gd`、`data/authoring/help_pages/*.json` 八页、字体子集、`docs/architecture.md` 术语注。

## 落地记录（v3.15，待定 1–4 全按推荐）

- **背景与底板**：开局三页不再调 `_slab_screen`，改 `GameScreen._painted_screen(UiTheme.ART_SETUP_BG)`：`_backdrop` 的纯色底上按 `UiTheme.dress_backdrop` 铺 `assets/ui/setup/bg_hall.png`（没图什么也不加，`dress_home_backdrop` 也改走它）；内容区铺满全屏、深底白字。新面板变体 `PANEL_GROOVE`（登记在 `PANEL_TONES` 深、`PANEL_ART` → `setup/groove`；没图是平面底 `#14161c`、细黄铜边 `#5a4522`、往下投影）。标题白字加阴影。
- **第一页**：左 260、中 `SIZE_EXPAND_FILL`、右 `SIZE_SHRINK_END`，三栏间距 36，内边距按 §2.1。**和方案不同**：右栏宽按**这个角色**的棋盘宽（列数 × 60 + 两边 10）算，所以换角色时中栏跟着变宽 / 变窄（安德烈乌斯 7 列时中栏约 750，布鲁图斯 9 列时约 630）；三栏间距始终 36。
- **图标牌**：新 `CapTile`（`ui/game/cap_tile.gd`）：图标 40、数字 28 粗体、说明 13 灰，等宽横排。图标先找 `assets/ui/setup/icons/<weight|board|coin>.png`；没有时秤砣、金币借 170 的 `tip/weight.png / coin.png`，棋盘画一个占位格子。**补（同日 19:10 美术定稿）**：三个图标进了 `assets/ui/setup/icons/weight|board|coin.png`（取美术的 `@2x` 80 px 版、按 40 显示，彩色成品不调色），借用图与占位不再用到；背景画还在等作者选，没接。带入上限（最多带 N 件、稀有度不超过 N）有才在牌下写一行（`carry_caps_text`）。`caps_text`、`bags_text` 没人用了，删掉。
- **技能**：`CharacterDef.skill_entries()` 给「被动 / 主动」、名字、说明（主动的次数 / 冷却附在说明末尾）；`skill_lines()` 留着（同一套说明）。名字 22 号思源宋体 Bold、`BTN_PRIMARY_HOVER`、黑描边（描边宽 `OUTLINE_SIZE × 2`，22 号字上 2 太细）；说明 17、行距半个字高。生命 / 耐力 / 体力标签 17、「每秒回」14、提示 12。这些字样与牌底都是主题变体（`LABEL_SKILL_NAME / LABEL_SKILL_TEXT / LABEL_CAP_VALUE / LABEL_SCREEN_TITLE`、`PANEL_CAP_TILE`，`UiTheme.make_variant_label`、`panel_margins`），屏幕脚本里不加 `add_theme_*`（121 棘轮）。
- **第二 / 三页**：内容整页坐一块凹槽板（板按内容高，不压到右下角按钮）；页里排法不动。
- **退词**（§3.1 全表）：结算屏与基地战绩「走了 N 步」；地图预览代价 1 不写、别的「计 N 步」，熟门熟路那一步写「（熟门熟路：这一步不计）」；地图开场白「已走 N 步」（方案写「第 N 步」，开局是 0，读成「第 0 步」别扭）；事件屏「耗了 N 步」、地图「原地耗了 N 步」、`PassTime.describe`「耗 N 步」、代价图标「耗步」；寸步难行词条「计两步」、`EncumbranceRules.describe`「走一步计 N 步」；`TravelDiscount`「不计入倒计时」；`CountdownModule`、`ErosionMechanic` 的描述、`MapTravel` 的校验句按步；作者编辑器的表头（`field_text`）「步数」「全局倒计时（步）」；帮助八页与休息点「扎营」选项改写。HUD：`action_points` 从登记表、默认布局与 `HIDDEN_BY_DEFAULT` 去掉，部件脚本删除，`HudLayout.VERSION` 5 → 6。
- **测试**：新 `tests/ui/test_setup_179.gd`（三块板与变体、中栏撑满、棋盘栏贴右且按棋盘宽、三块牌的数与说明、技能名 22 / 描边 / 颜色、不放角色说明与「背包：」、不在石板上；`skill_entries` 的书面句；扫 `core / ui` 脚本的字符串字面量与 `data` 下 json / tres，没有「行动点」）；`test_hud_150` 去掉行动点断言、版本 6、版本 5 的布局文件回默认；`test_screens_157` 代价提示改「耗步」。角色 / 帮助 / 事件的 json 改完重新导入（只留这几份 `.tres`，导入顺带改动的别的资源还原）。字体子集不用重切：新字只有注释里的「厅」，换了说法。
- **截图**：`/mnt/project-files/screenshots/179/`：`p1_andreus / p1_brutus / p1_marcus`、`p2`、`p3`，对照 `before_*`。背景画与三个图标等美术设计交付，到了直接放进 `assets/ui/setup/`（`bg_hall.png` + json、`icons/weight|board|coin.png`）就生效，不用改代码。

### 补（2026-10-17，v3.17）：白天大厅背景、技能行去掉「被动」

- **背景画到了**：作者 07:50 定白天版选人大厅，`assets/ui/setup/bg_hall.png` + json（`stretch: cover`、`tone: light`）。原先「内容区深底白字」的假设不成立了：`GameScreen._painted_screen` 的内容区按背景图 json 记深浅（`UiTheme.art_tone`，没图仍是深）；直接写在背景上的标题挂墨字（`UiTheme.set_tone(_title, …)`，浅底小主题里给 `LABEL_SCREEN_TITLE` 墨色、去掉黑影）；右下角那行提示是语义色标签，进树按浅底取暗版。三栏凹槽板自带深底，墨字主题只挂在标题上、不挂内容区，所以板里的字照旧浅色。
- **「被动」不上屏**（作者 07:51）：技能行第一行只剩名字；`skill_entries()` 的 `kind` 留着（以后主动技能放出来再说）。
- 测试：`test_setup_179` 加背景画在、浅底、标题墨字无黑影、凹槽板仍深底浅字、这一屏没有「被动」。截图 `/mnt/project-files/screenshots/setup_hall/page1|2|3.png`。
