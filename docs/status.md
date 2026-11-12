# 现状总览

> 2026-11-10 ｜ 代码 v5.47（PR #525；修云端测试报告的 G01～G03、Q01，报告 291）｜ 架构文档 v5.47 ｜ 引擎 Godot 4.7.1 ｜ 这是一份**活文档**：设计以 [architecture.md](architecture.md) 正文为准，每一步的记录在 [reports/](reports/README.md)
>
> 本次（阶段 A，[执行方案](plans/2026-11-09-claude-next-execution.md) §3）按代码与变更记录（现在在 [changelog.md](changelog.md)）v5.00～v5.46 重写；2026-10-06 那一版（架构 v2.48）的全文见 `git show b1c0f009:docs/status.md`。

## 一句话

单机 roguelite：异形格子背包 + 自动战斗 + 搜刮撤离。从主菜单到结算、仓库、再开局的循环早已闭合（M6，报告 055～057）；之后补齐了三张序章、两张正式地图（魔法废墟、机关沙漏）、信仰 / 技能 / 猎手 / 侵蚀、局外基地（仓库、科技、集市、铁匠铺）、英文界面、音效与大部分美术。2026-11 上旬完成的是**武器网状升级**（279 / 281：拼接、砧、品质、橙档只能升、八把红武的数据与独一闸）和**一批规则重做**（282～290：NPC、出征倾向删除、收费预设、配方悬浮窗、托付、文本普查、局内商店以物易物）。还没做的大头：**数值平衡**（工具和历史扫表都有，没有当前版本基线和真人数据）、**常规事件正文与配图**、**音乐**（`data/authoring/audio/music.json` 是 `{}`）、红武的独有机制与另三条来路。

## 系统现状

| 系统 | 现在是什么样 | 主要入口 | 来源 |
|---|---|---|---|
| 背包 | 棋盘 + 包体拼可用区，异形占格，可旋转；格子外整屏是「地上」，按点保留；腰带槽；Ctrl（Mac Cmd）整包拿 | `GridInventory`、`InventoryView`、`DragLayer` | 007、128、147、274（v5.04） |
| 战斗 | 编译背包 → 战斗单位，事件驱动模拟；标准轴、单一乘区、反应、加时与衰竭；战记（可读回放） | `BattleCompiler`（`core/battle/compiler.gd`）、`BattleSim`、`BattleNarrator` | 103～106、133、272（v5.00） |
| 武器体系 | 五类 × 白→橙，另有弓弩与法杖；**拼接**：白 + 白贴着出小锤徽、点锤合成绿；**砧**：上一把 + 一类材料升蓝 / 紫，+ 魔晶石升橙（橙只能升，不掉落）；**品质** 0～2（伤害 / 格挡 / 护甲每档 ×1.1、暴击 +5 点、层数与个数 +1，每下叠层照加）；极端武器两条线 6 把；弓弩装箭 | `Fusion`（`core/inventory/fusion.gd`）、`Anvil`（`core/run/anvil.gd`）、`BattleCompiler.quality_stats / quality_rules` | 279（v5.05～v5.17、v5.42、v5.43）、281（v5.18、v5.19） |
| 红武 | 刹那 / 断水 / 双生 / 贯日 / 崩山 / 坠星 / 破晓 / 寂灭 8 件：裸数据、定稿图、`unique`（不进随机池、不可卖、全局一件）；**独有机制未做**；BOSS / 猎手按概率持有并掉**劣化版** `<id>_lesser`；**寂灭**的来路已做完（法杖进出局计数 → 单元素试炼 → 神坛献祭）；破晓只有铁匠起点 | `RedSources`、`UniqueItems`、`JimiePath`（`core/run/`） | 281（v5.20～v5.27）、282（v5.29） |
| 休息点 | 营地屏；「铁炉」= 两栏屏 **砧 \| 铸炉**，每个休息点砧免费一次；神坛 | `ui/game/rest_camp_screen.gd`、`ui/game/anvil_column.gd`、`NodeEvents.hearth_open` | 286（v5.34） |
| 悬浮窗 | 道具说明 + 词条侧窗；「可升为」每个名字是配方词，停上去开配方子窗（出件整段、要哪类材料、在哪锤），可一路点到橙；耐力签列出消耗与回复来源；说明文字的数字读数据（288 普查 17 条已改） | `HoverTip`、`ItemTooltip`、`StaminaEstimate.breakdown`、`Glossary` | 286、288（v5.37）、289（v5.38） |
| 局内商店 | 商人一块 8 × 6 棋盘，`shop_stock` 10 件（+ 包 / 金银按概率）一次摆满、**不刷新**；拖过去 = 上桌（染待成交色），天秤左盘你拿的货的售价、右盘你给的东西的收购价（定价 × 0.3）+ 钱，右 ≥ 左才能「成交」；点自己钱袋补差、点商人钱袋找钱（不自动找零），商人钱袋 100 + 200 × 深度、一局不回填；离开各回各家；回购 = 本次卖出的挂原价；店主纸条层级已修 | `ShopSession`（`core/run/shop_session.gd`）、`ui/game/shop_screen.gd`、`ShopScale` | 290（v5.39～v5.41）、v5.46 |
| 撤离与托付 | 图上不再单放保险箱点；**免费、没关门**的撤离点确认框多一个【托付】（= 原保险箱屏，一局一块格子整局共用，交出的件拿不回，空格下回还能放）；付费出口不接，出口关了托付跟着关；老档 `safe` 点照旧能开 | `SafeModule`（`core/run/modules/safe_module.gd`）、`GameFlow.entrust_open` | 287（v5.35） |
| 开局预设 | 第二页中栏竖排挂牌：免费（强攻 / 坚守）→ 收费（游猎 / 枪盾 / 双刃，出发时按清单定价之和付钱、算带入预算）→ 高级（制式 / 精锐，出发时消耗一张对应的券）；序章只列免费；核心 BOSS 打赢必掉一张券（魔法废墟制式、机关沙漏精锐） | `GameFlow.presets / preset_price / begin`、`LoadoutDef.tier` | 285（v5.33、v5.44） |
| NPC | 局内商店店主（哈基姆）、散货摊主（德米特里）、铁匠（布伦努斯）；点头像出纸条，每人六句提示 + 通用三句（按键名走 `[key=…]` 引用）；铁匠铺 3 级后铁匠给【破晓的信物】，之后留白 | `NpcChatter`（`core/meta/npcs/npc_chatter.gd`）、`NpcBadge`、`InputKeys` | 282（v5.29、v5.32）、284（v5.36、v5.45） |
| 地图 | 魔法废墟：环形生成，三档规模；机关沙漏：分层格阵，一左一右两个出生点、核心在中轴、钟房在其下；每章自带材料节点（出征「倾向」已删）；高危区画成一片 | `RingMapGenerator`、`LatticeMapGenerator`、`DangerZones` | 078、278（v5.03）、281 §六（v5.26）、283（v5.28～v5.31） |
| 一局 | 体力、倒计时、负重、搜索揭示、猎手、侵蚀、信仰与信力、局内技能、事件层（条件 / 后果构件） | `RunState`、`GameFlow`、`NodeEvents`、`ErosionField`、`HunterDef` | 063、069～075、081、082、129 |
| 局外 | 三个存档位、仓库格子、图鉴、科技树（15 项）、集市（五个固定摊 + 散货摊）、铁匠铺、成就 | `MetaState`、`TechService`、`Market`、`Smithy`、`Achievements` | 089、118、252、262、270 |
| 平衡工具 | 流派木桩、扫表、单件台架、猎手胜率表、对局记录（玩家版也记）、导出平衡数据 zip | `tools/build_archetypes.gd`、`bench_matrix.gd`、`bench_battle.gd`、`bench_hunters.gd`、`build_dummies.gd`、`assumptions_report.gd` | 073、151、242（v4.23、v4.24）、279 台架 |
| 语言与音频 | 中英界面与内容名字；字号三档；界面音效（cue 表）；**配乐没有**（`play_music` 有，曲表空） | `UiText`、`Names`、`ui/audio.gd`、`data/authoring/audio/` | 204、221、258 |

道具说明、预设说明、NPC 与常规事件正文由作者写（v5.02 起道具 `description` 一律留空，267 件全空）。

## 代码地图（`b1c0f009`，`git ls-files` 计）

967 个 `.gd`（不含 `addons/`）：`core` 470 个 / 约 5.4 万行，`ui` 170 个 / 约 5.1 万行，`tests` 298 个 / 约 6.2 万行，`tools` 29 个。

| 目录 | 管什么 | 入口类（举例） |
|---|---|---|
| `core/inventory` | 容器、形状、道具定义与实例、拼接、耐久 / 品质 | `GridInventory`、`ItemDef`、`ItemInstance`、`ItemDatabase`、`Fusion`、`WearProfile` |
| `core/battle`（+ damage / effects / reactions / cadences） | 编译、标准轴、模拟、伤害、反应、战记、耐力估算、战斗存档 | `BattleCompiler`、`BattleSim`、`StatAxes`、`BattleNarrator`、`StaminaEstimate`、`BattleArchive` |
| `core/effects`、`core/sets`、`core/loot` | 效果树根、套装（暂无内容）、掉落 | `Effect`、`SetTracker`、`DropRule` |
| `core/authoring` | 内容管线、一致性检查、台架 | `ContentImporter`、`ContentCheck`、`ContentPaths`、`PowerBench` |
| `core/map`（+ generators） | 地图数据层、环形 / 格阵生成器、导航 | `MapGraph`、`RingMapGenerator`、`LatticeMapGenerator` |
| `core/enemies` | 敌人池、档位、组装 | `EnemyPool`、`EnemyPlacer` |
| `core/run`（+ modules / events / faith / hunters / erosion / calibration / skills …） | 一局的全部：场景流、旅程、商店、砧、托付、红武来路、猎手、侵蚀、信仰、校准记录 | `GameFlow`、`RunState`、`ShopSession`、`Anvil`、`SafeModule`、`JimiePath`、`RedSources`、`CalibrationRecorder`、`DataExport` |
| `core/meta`（+ npcs / techs） | 局外：仓库、科技、集市、铁匠铺、成就、NPC 闲聊、存档迁移 | `MetaState`、`MetaMigrations`、`TechService`、`Market`、`Smithy`、`NpcChatter` |
| `core/forge` | 铸炉（附魔） | `Forge` |
| `core/save`、`core/settings` | 原子写与对账；设置、存档位 | `AtomicFile`、`SaveReconcile`、`GameSettings`、`SaveSlots` |
| `core/text`、`core/audio` | 多语言、占位符、词条、百科；音效 cue 表 | `UiText`、`Names`、`TextTemplate`、`Glossary`、`Encyclopedia` |
| `ui/game` | 正式游戏主场景（导演 + 各屏） | `GameDirector`、`shop_screen`、`rest_camp_screen`、`result_screen`、`event_screen`…… |
| `ui/inventory`、`ui/widgets`、`ui/map`、`ui/battle`、`ui/hud` | 背包视图与悬浮窗、通用控件（天秤、钱袋、NPC 头像、教练遮罩）、地图画法、战斗视图、顶栏 | `HoverTip`、`ItemTooltip`、`ShopScale`、`NpcBadge`、`DangerZones` |
| `ui`（其余） | 启动选择器与各编辑器（道具 / 事件 / 地图 / buff / 套装 / 标签 / 构件 / 铸炉）、`UiMotion`、`InputKeys` | `launcher`、`content_editor`…… |
| `tools` | 测试、警告、存档检查、导入 / 归一化、平衡工具、截图、字体 | `test.sh`、`warnings.sh`、`check_saves.sh`、`bench_*`、`build_*` |
| `tests` | 294 个套件，按层分目录（authoring / battle / content / enemies / inventory / loot / map / meta / run / settings / tools / ui） | `run_tests.gd`、`test_layering.gd` |

数据管线：`data/authoring/<种类>/*.json`（人写）→ `tools/import_content.gd` → `data/<种类>/*.tres`，两边都进 git；`ContentPaths.ORDER` 共 34 种（`core/authoring/content_paths.gd:137`），`sets` 只走编辑器（`EDITOR_ONLY_KINDS`）。`tools/test.sh` 每次跑 `check_content.gd` 守 JSON ⇄ `.tres` 一致。

## 内容统计

**口径**：`b1c0f009` 下 `data/authoring/<种类>/*.json` 的**文件数**（python 直接数，没跑 Godot）。这是作者文件数，**不是玩家能拿到的内容数**；下表单列了封存 / 独一 / 只能锻造等不进随机池的件。

| 种类 | 文件数 | 说明 |
|---|---|---|
| 道具 `items` | 267 | 武器 120、包 15；独一 `unique` 13（8 把红武 + 4 颗元素之核 + 破晓的信物）、劣化版 `lesser` 8、只能锻造 `forged_only` 18（橙档）、极端 `extreme` 6、券 2、随身之物 `keepsake` 2、铸牌 `token` 1、招牌 `signature` 1、成就解锁 3；**封存 `sealed` 0 件**（旧版的 15 件现代道具已不在作者数据里）；赐福版运行时派生，不在作者文件里（`blessed_of` 0 份）。按 `ItemDatabase.ids()` 的排除规则估，能进随机候选的约 **219** 件（还要再过各池的标签与稀有度上限） |
| 拼接配方 `recipes`（310 起全部贴着点锤） | 23 | 另有铁匠铺 / 砧配方 `smith_recipes` 116 |
| 敌人 `enemies` | 33 | 敌人池 3（standard_ruins / clockwork / hunters）、猎手 2 |
| 事件 `events` | 61 | 序章教程 37（序章一 11、序章二 14、序章三 12）；其余 24（默认事件、搜索收尾、信仰召唤 5、寂灭 2、钟房、军团交代等）；**有配图的只有 2 个**（`briefing_legion`、`event_jimie_god`） |
| 章节 `chapters` | 5 | 序章三张 + 魔法废墟（`free_mode`）+ 机关沙漏 |
| 角色 `characters` | 3 | 安德烈乌斯 / 布鲁图斯 / 马库斯 |
| 难度 `difficulties` | 4 | 普通 + 进阶 Ⅰ～Ⅲ |
| NPC `npcs` | 4 | 三位 NPC + `common`（通用三句） |
| 开局装备与预设 `loadouts` | 10 | 开局装备 3（标准 / 拾荒者 / 打手）+ 预设 7（免费 2、收费 3、高级 2） |
| 其余 | — | 成就 7（1 个隐藏：`fallen_thrice`）、科技 15、百科 57、局内 buff 22、buff 14、标签 49、伤害类型 8、信仰 7（`church` 自述占位）、反应 10、集市摊位 6、构件 18、随身技能 2、铸炉 3、宝箱皮肤 5、教练 5、音频 2（`music.json` = `{}`）、手绘地图 1 份 `.txt` |

**测试 / 开发数据**：所有作者文件的文件名与 id 里没有 test / dev / debug / demo / sample / dummy / tmp；顶层没有 `hidden` / `dev` / `test` / `sealed` 开关，只有成就 `fallen_thrice` 是 `hidden: true`（隐藏成就，属正式内容）。旧版记作「测试用」的两个局内 buff（`marked` / `weakened`）现在被事件与节点规则引用（`node_rules.gd:52` 逃跑失败给 `weakened`），按正式内容计。

## 测试

**本次全量结果**：39,276 项断言 / 294 个套件通过，401,292 ms（整个 test.sh 含导入与两项检查 438 s），EXIT=0；0 条 `SCRIPT ERROR`，0 条未登记的 `ERROR:` —— v5.47 改动之上、2026-11-10，Godot 4.7.1 无头（[报告 291](reports/291-plan-1109-batch1-fixes.md)，日志摘要 `reports/testing/evidence/2026-11-10-fixes/suite-summary.log`）

**最近一次有记录的全量（历史，不是本次运行）**：39,269 项断言 / 294 个套件通过，956,726 ms，EXIT=0；967 个脚本加载、34 种内容一致 —— 代码 `0a91d60d`（v5.46），2026-11-10 云端调试，Godot 4.7.1、软件渲染（[testing/2026-11-10-cloud-debug-0a91d60d.md](reports/testing/2026-11-10-cloud-debug-0a91d60d.md)，日志 `reports/testing/evidence/2026-11-10-debug/suite-summary.log:53`）。同一份报告指出：EXIT=0 不等于日志干净（见待办 Q01）。

| 命令 | 做什么 |
|---|---|
| `bash tools/test.sh` | 先 `--import` 重建类缓存 → 全部套件 → `check_scripts.gd` 全项目加载 → `check_content.gd` 内容一致；日志里有 `SCRIPT ERROR`、或有没登记在 `tools/expected_errors.txt` 的 `ERROR:` 都判失败（后者 v5.47 起）；末行 `EXIT=…` |
| `bash tools/test.sh <词>` | 只跑路径或用例标题含这个词的套件（如 `safe`、`shop_barter`、`presets_285`） |
| `bash tools/warnings.sh [out.jsonl]` | 收全项目 GDScript 静态警告 |
| `bash tools/check_saves.sh [目录]` | 只读检查存档（读档 + 内容对账），不写文件 |
| `RECORD_GOLDEN=1 bash tools/test.sh 金样` | 有意改数值后重录编译金样（`tests/fixtures/compile_golden/`），录完照样报红 |

- 引擎：要 **4.7.1**；4.6.3 进地图会报类型错误（同上报告「环境与覆盖」）。`GODOT` 没设时 `test.sh` 先在 PATH 里找，最后才退到作者 Windows 路径。
- 日志默认写 `${TMPDIR:-/tmp}/godot_tests.log` 等固定文件名：**两个 Godot 同时跑会互相覆盖**，要么串行，要么各设 `TMPDIR`（执行方案 §4）；手工 / 自动测试各用独立的 `XDG_DATA_HOME`，不碰真实存档。
- 套件自动发现（`tests/**/test_*.gd`，除 `test_case.gd`）；`tests/test_layering.gd` 守依赖方向（`core/` 不许出现 `ui/` 的类名）。
- 耗时：云端软件渲染约 16 分钟（956,726 ms，上面那次）；2026-10-06 版写的 60～180 秒是 108 个套件时的数，已不适用。

## 当前待办

代码入口的行号按 `b1c0f009`。2026-11-10 测试报告的 G01、G02、G03、Q01 已在 v5.47 修掉（[报告 291](reports/291-plan-1109-batch1-fixes.md)），不再列；G02 的计分口径作者 2026-11-10 09:08 定「保留」（数到过的点）；G04 的开场白分支 v5.48 已接上，第一句待作者定稿（A5）。

### 可直接执行

| # | 事项 | 来源 | 代码入口 | 依赖 | 验收 |
|---|---|---|---|---|---|
| B1 | 阶段 B 近期功能回归矩阵（商店 290、托付 287、预设 285、配方与砧 286、NPC 与说明 284 / 288 / 289），含金钱 / 券 / 物品守恒，以及中英 × 默认 / 大字号、三张序章、两张正式地图的手工走查（v5.47 只跑了全量与定点测试，见报告 291 §六） | 执行方案 §4 | 方案 §4 回归矩阵列的测试与实现（`tests/run/test_shop_barter_290.gd`、`tests/run/test_safe.gd`、`tests/ui/test_presets_285.gd`、`tests/ui/test_recipe_tip_286.gd` 等） | 无 | 方案 §4 验收：全量通过、无 `SCRIPT ERROR`、警告无新增、记录命令 / 退出码 / 数量 / 耗时 |
| Q02 | 退出时 ObjectDB / 资源 / RID 泄漏告警分类治理 | 测试 2026-11-10 Q02（P3） | `tests/run_tests.gd`、各套件清理；`tools/check_content.gd` 退出 | Q01 之后；不与别的 Godot 运行并发 | 把告警按「测试没清理 / 静态缓存 / 循环引用」分类计数，修掉测试那一类并给前后数；**不**据此宣称玩家每局泄漏。理由：纯工程，不涉及玩法与文字 |
| U3 | 长篇交代 / 事件正文溢出时给「下方还有内容」的视觉提示（渐隐或箭头，不加字） | 测试 2026-11-10 体验建议 3 | `ui/game/event_screen.gd` | 无 | 英文大字号首次自由模式交代：有溢出时显示、滚到底消失；`Got it` 照旧随时可点。理由：只加图形提示、不改流程，符合「图像能说明的不加文字」 |
| U4 / D0 | 统一引擎版本与启动入口：`run_game.sh` 像 `test.sh` 一样先找 PATH，并检查引擎版本是 4.7.x | 测试 2026-11-10 体验建议 4；执行方案 §6 | `tools/run_game.sh:6`、`tools/test.sh:12-21` | 无 | Linux 上不设 `GODOT` 能启动；版本不符时明确报错。理由：工具脚本，不涉及玩法 |
| U5 | 深面板上 `styles.hp` / `styles.danger` 对比度 4.40 → ≥ 4.50 | 测试 2026-11-10 体验建议 5 | `data/authoring/ui/text_colors.json`、`tools/text_color_check.gd` | 无 | `text_color_check` 过 4.50；色相不变、只调明度，前后色值与截图交 UI设计 过目。理由：工具目标明确、改动极小，可逆 |
| C1～C4 | 阶段 C 平衡基线：**v5.48 已交**（[报告 292](reports/292-plan-1109-stage-c-balance-baseline.md)：两池扫表、猎手、武器估算对实测、9 条建议，没改数；顺带修了连锁触发截断）。下一步等作者对报告 292 §八的建议表态，再按定下的改数 | 执行方案 §5 | `docs/reports/balance/2026-11-10-*.md` | 作者表态 | 改数前后用同一份输入 `docs/reports/balance/inputs/2026-11-10-archetypes.json` 对照 |
| P-A | 平衡检测方案 2026-11-10 批次 A：数据契约、审计、诊断包与复现。**v5.49 已交**（[报告 293](reports/293-balance-diagnostics-batch-a.md)） | 平衡检测方案 §4～§5 | `core/run/calibration/data_audit.gd`、`core/battle/battle_diag_pack.gd`、`tools/audit_balance_data.gd`、`tools/reproduce_battle.gd` | — | 已验收 |
| P-B | 平衡检测方案 2026-11-10 批次 B：逐场指标与统计库、扫表实验目录（覆盖 / 真实节点频率 / 假节点，失败也记一行）、猎手同格式、参考配装检测。**v5.50 已交**（[报告 294](reports/294-balance-diagnostics-batch-b.md)）；没做：失误类型场景清单、留出种子集、耐力阻塞 | 平衡检测方案 §6～§7 | `core/run/calibration/balance_experiment.gd`、`balance_statistics.gd`、`battle_metrics.gd`、`scenario_check.gd`、`tools/check_balance_scenarios.gd` | — | 已验收 |
| P-C | 平衡检测方案 2026-11-10 批次 C：观看时间线（模拟时长和实际观看分开记）、战斗体验报告五节、单因素配对与连带变化、9 个人工验证场景与问题清单。**v5.51 已交**（[报告 295](reports/295-balance-diagnostics-batch-c.md)）；没做：屏上显示字段的记录、耐力停火事件；真人验证待回答 | 平衡检测方案 §8 | `core/run/calibration/viewing_session.gd`、`battle_experience.gd`、`battle_factor.gd`、`feel_scenarios.gd`、`tools/battle_experience_report.gd`、`tools/make_feel_scenarios.gd`；`ui/game/battle_screen.gd` 只记事件 | P-B | 工具已验收；真人验证未做 |
| P-D | 扫表默认木桩表换新（作者 11-10 21:38 选「换新」）。**v5.53 已交**（[报告 297](reports/297-archetypes-baseline-refresh.md)）；旧表冻结在 `docs/reports/balance/inputs/2026-10-26-archetypes-v454.json`，以后又回到只追加 | 报告 294 §3.5 | `data/authoring/calibration/archetypes.json` | — | 已验收 |
| D2 | 阶段 D：构建可追溯标识。**v5.49 已做工具侧**（`BuildInfo` + `tools/stamp_build.sh`，诊断包和记录行带 `build`，报告 293）；玩家包要带上需作者在导出设置的非资源文件里加 `build_id.txt` 并在导出前跑 `stamp_build.sh` | 执行方案 §6 第 1 条；平衡检测方案 §4.1 | `core/run/calibration/build_info.gd`、本地 `export_presets.cfg` | 作者改导出设置 | 玩家包导出的记录能对上具体提交 |
| D3 | 阶段 D：玩家错误日志是否落盘、怎么找、是否随「导出平衡数据」带走 | 执行方案 §6 第 2 条 | `core/run/calibration/data_export.gd`、`core/battle/battle_archive.gd`、`project.godot`（日志设置） | 无 | 写清现状；缺的话复用现有导出补一项，不另起日志系统 |
| E1 | 阶段 E：常规事件薄弱度 / 重复度盘点，挑 5～8 个候选（只列条件、后果、位置、数值影响，**不写正文**） | 执行方案 §7；238 | `data/authoring/events/`（非教程 24 个） | 阶段 B、C 结果 | 盘点表交作者；正文见 A10 |
| E2 | 阶段 E：音乐需求表（主菜单 / 地图 / 战斗 / 结算：循环、切换、授权来源栏） | 执行方案 §7 | `ui/audio.gd`（`play_music`）、`data/authoring/audio/music.json`（`{}`） | 无 | 需求表按实际场景列；风格与曲子见 A8 / M2 |
| E3 | 阶段 E：事件配图盘点（可共用的场景图、尺寸、缺口） | 执行方案 §7 | `ui/game/event_image.gd`、`assets/events/`（只有 1 张）、`data/authoring/events/*.json` 的 `image` | 无 | 61 个事件里 2 个有图；列出缺口与可复用的现成图 |
| W1 | 寂灭献祭条件的唯一性漏洞：`JimiePath.sacrifice_ready(board, meta)` 只看棋盘与局外，本局地上 / 暂存已有一把寂灭时仍判可献（`tools/verify_weapon_web.gd` 第四项复现；冰 / 毒之核暂无来源，玩家目前走不到）；另补 304 §八列出的测试缺口 | 报告 304 §五.3、§八 | `core/run/jimie_path.gd:96-102`、`core/run/unique_items.gd` | 无（作者已定「同名一件」） | `verify_weapon_web.gd` 全部符合；新增回归测试 |

### 需要作者决定

| # | 事项 | 来源 | 代码入口 | 依赖 | 验收（作者给了什么才算定） |
|---|---|---|---|---|---|
| A1 | 刹那 / 断水来路：是否开做；§四.6 剩下的问题 —— 刹那的沙漏碎片是否必出、断水 50 次后打捞是否必触发、寂灭是否只算出过手的局（现在按「带进带出」算） | 281 §四.3、§四.6；作者 2026-11-05 11:37「先记录」、12:33 / 12:36 部分答复（提示不加、河边不标、清仓只清三碎片与沙子、钟房在中轴、机关沙漏三档已做 v5.26） | 参照 `core/run/jimie_path.gd`；`core/run/red_sources.gd`；`data/authoring/items/chana.json`、`duanshui.json`；`data/authoring/events/event_clock_room.json`（正文空） | 事件正文与动画由作者 / 美术给 | 作者说「开做」并答完上面三问 |
| A2 | 八把红武的独有机制（时间凝滞、断绝回复等八条）是否照 281 §四.2 落地 | 281 §四.2；v5.20 落地时「机制空，等作者点头」 | `data/authoring/items/{chana,duanshui,shuangsheng,guanri,bengshan,zhuixing,poxiao,jimie}.json`、`core/battle/effects/` | 无 | 作者对每条点头或改写 |
| A3 | 破晓任务链（拿到信物之后）—— **报告里故意留白，不得自行补规则** | 281 §四.3 破晓行；282 §二.3；作者 2026-11-05 12:42；`/mnt/project-files/reference/待做-系统.md` 第 4～5 行（文件存在） | `data/authoring/npcs/blacksmith.json`、`data/authoring/items/poxiao_token.json` | 作者点名时出方案 | 作者给出后续流程 |
| A4 | 新角色方向（12 个草案里挑哪几个） | 254（头脑风暴，待作者挑方向） | `core/run/character_def.gd`、`data/authoring/characters/` | 无 | 作者挑定后每个角色一篇方案 |
| A5 | 跳过教程分支的开场白第一句：作者 2026-11-10 09:08 选「单独开头」，v5.48 已接上分支，第一句暂用草案「听说你在别处走过几趟。」/ "Word is you've made a few trips elsewhere." | 测试 2026-11-10 G04；报告 291 §四、292 §二 | `data/authoring/events/briefing_legion_skipped.json` | 文案由作者写（中英） | 作者定稿第一句 |
| A6 | 教程遮罩加「点击任意处继续」、进度与跳过入口 | 测试 2026-11-10 体验建议 1 | `ui/widgets/coach_overlay.gd`、`data/authoring/coach/` | 提示文字由作者定；跳过会改教程流程 | 作者选做哪几样。理由：动教程流程与文字，不能直接做 |
| A7 | 平衡目标带：普通敌人约七成、精英约五成只是**建议**（猎手五成是 073 作者定） | 242 §3.3；执行方案 §5 | `tools/bench_matrix.gd`（只打印不改数） | C3 结果 | 作者定每类对手的目标带，或说明按建议 |
| A8 | 音乐风格 | `data/authoring/audio/music.json` = `{}`（已核）；238；执行方案 §7 | `ui/audio.gd`（`play_music`，曲表空） | E2 需求表 | 作者定风格与来源，素材见 M2 |
| A9 | 无配图事件的左页：补图，还是缺图时正文加宽 | 测试 2026-11-10 体验建议 2；065（作者定的两栏、左整块是图） | `ui/game/event_screen.gd`、`ui/game/event_image.gd` | 选「补图」则转 M3 | 作者二选一。理由：动的是作者定过的版式 |
| A10 | 常规事件正文（中英）与选项 | 238（常规事件正文一句话）；执行方案 §7 | `data/authoring/events/` | E1 盘点 | 作者写或认可每条正文 |
| A11 | 对外版本 `0.1.0` / `0.1.0.0` 与开发号 v5.46 是否有意分离 | 执行方案 §6；242 §十 | `project.godot:14`、`export_presets.cfg:33,75` | 无 | 作者一句；在定之前不改对外版本 |
| A12 | 额外战斗效果：无敌 / 吸血 / 荆棘（已定要做，动手前先出方案）；眩晕、命中等候选 | `/mnt/project-files/reference/待做-战斗效果.md`（文件存在）；执行方案 §7 | `core/battle/buff_def.gd`、`core/battle/effects/` | 先交架构设计出报告 | 作者对方案点头 |
| A13 | 大型地图（9 环以上）的第二道撤离环间等规模参数仍是占位 | 053；`core/map/generators/map_scale_profile.gd:31,92` | `data/authoring/chapters/free_mode.json:367`（`placeholder: true`） | 无 | 作者给大型图规则 |
| A14 | 武器合成 / 铸造升级改革方向：保留哪些拼接、哪些升级改拼接、哪些直接获取，18 把 `forged_only` 金档以后从哪里来；红武能否出售、地上 / 托付里的算不算遗失；配方发现与图鉴的跨局范围与旧档继承；局内砧不看铁匠铺级数是否有意；破晓信物能否重拿、冰 / 毒之核来源；锁定件能否被拼掉。**只交了调查，改革未开始** | [报告 304](reports/304-weapon-fusion-forge-survey.md) §十；`plans/2026-11-11-weapon-fusion-reform-investigation.md` | `core/inventory/fusion.gd`、`core/run/anvil.gd`、`core/meta/smithy.gd`、`core/run/unique_items.gd`、`core/run/jimie_path.gd` | 无 | 作者逐条表态后再出改革方案 |

### 缺素材或真人数据

| # | 事项 | 来源 | 代码入口 | 缺什么 | 验收 |
|---|---|---|---|---|---|
| M1 | 真实木桩与按真人数据复测 | 242 §四、§九；执行方案 §5 | `tools/build_dummies.gd` → `data/authoring/calibration/dummies.json`（**不存在**）；快照在作者机器 `user://calibration/snapshots.jsonl` / `runs.jsonl` | 作者实玩的校准快照（`/mnt/project-files/calibration` 不存在） | 按构建版本筛选的快照生成木桩并复测；没有时只交采集清单与复测命令，不把脚本撤离率当真人撤离率 |
| M2 | 配乐素材 | 同 A8 | `data/authoring/audio/music.json` | 曲子与授权 | 曲表填上、`play_music` 在各场景切换 |
| M3 | 常规事件配图（22 个非教程事件无图） | E3；238 | `assets/events/`、`data/authoring/events/*.json` 的 `image` | 场景图 | 盘点表里的缺口逐项有图 |
| M4 | 界面过渡第二、三批（叠层弹出、搜索格翻亮、墨迹换屏等） | 231 §三（第一批已落地，见下表） | `ui/ui_motion.gd`（`pop` 等已写好、没有调用方） | 界面动画线程的样稿与数值（231 §七） | 每处按样稿落地，`ui_fades` 关掉时不放 |
| M5 | 玩家包冒烟（启动、存读档、一局结算） | 执行方案 §6 第 3 条 | `export_presets.cfg`、`tools/export.bat` | 导出模板与 Windows 环境（本环境未核实是否有） | 记录引擎 / 模板版本与实际结果；缺环境时记具体错误与未验证范围 |
| M6 | 敌人棋盘外框 / 铭牌按种类与强度区分 | `/mnt/project-files/reference/待做-界面.md`（文件存在，2026-10-21） | `ui/game/battle_screen.gd`、`assets/ui/board/` | 美术 | 每类一套外框与铭牌 |

### 核过、不列入待办

| 事项 | 结论 | 证据 |
|---|---|---|
| 279 定调 ②（品质对每下叠层加不加层） | **已定**：作者 2026-11-05 08:11 选「照加」，v5.12 的每下判别已去掉 | 281 §二；architecture v5.18（PR #465） |
| 288 第 8 条（灼伤 / 燃血的火焰跳会点亮「受伤时」） | **已按推荐落地**：只改帮助页文字，代码行为不变；只有作者想让 buff 伤害一律不触发时才重开 | 288 §三 待定 1、§五 v5.37（PR #511） |
| 284 NPC 名字与台词、285 券图、286、287、289、290 | 全部已落地 | v5.45（PR #521）、v5.44（PR #520）、v5.34、v5.35、v5.38、v5.39～v5.41 |
| 旧版「下一步」（059 顺序、069 八步、第 8 阶段 8-1～8-4 起步） | 全部完成，挪进下面「历史」 | 060～068、070～075、076～082 |

### 索引里状态过期的行

`docs/reports/README.md` 下列行的状态仍写「待执行 / 执行中」，实际已落地（本次不改索引，只登记）：

| 报告 | 索引写的 | 实际 | 证据 |
|---|---|---|---|
| 098 存档迁移链 | 待执行 | 已落地 | architecture v2.08；`core/meta/meta_migrations.gd`、`core/run/run_migrations.gd` |
| 099 背包里切信仰 | 待执行 | 已落地 | architecture v2.08 |
| 100 内容管线收口 | 待执行 | 已落地 | architecture v2.09；`core/authoring/content_check.gd`、`tools/check_content.gd`、`ContentPaths.EDITOR_ONLY_KINDS` |
| 101 RunState / GameFlow 拆分 | 待执行 | 已落地 | architecture v2.15～v2.19；`core/run/run_hooks.gd`、`core/meta/achievements.gd`、`tests/test_layering.gd` |
| 102 测试归位与 test.sh | 待执行 | 已落地 | architecture v2.14；`tests/` 分层目录、`tools/test.sh`、`tools/class_cache.gd` |
| 103 战斗规则七条 | 待执行 | 已落地 | architecture v2.11（设计）、v2.22 / v2.73（轴表扩充）；`core/battle/stat_axes.gd`、`battle_sim.gd:33` 加时。另：architecture §4.3 小标题（第 768 行）仍写「待实现」，也过期 |
| 104 神明总表落地 | 待执行 | 已落地 | architecture v2.12 |
| 105 信仰效果进编译器 | 待执行 | 已落地 | architecture v2.20、v2.21；`core/battle/compile_input.gd` |
| 106 标准轴补三条 + 护盾外框 | 待执行 | 已落地 | architecture v2.22 |
| 108 武器附加效果统一接口 | 执行中 | 已落地 | architecture v2.26；`BattleCompiler._attach`（`core/battle/compiler.gd:299`） |
| 109 第五条 FIRE → ELEMENT | 执行中 | 已落地，后又被 133 单一乘区整体取代 | architecture v2.26、v2.48 |
| 231 界面过渡动画 | 已派执行（批一） | 第一批已落地；第二、三批未落地（转 M4） | PR #342（`git log`）：`ui/ui_motion.gd`、`ui/widgets/duel_medal.gd`、`tests/ui/test_ui_motion_231.gd`；补充二 v3.85；`UiMotion.pop` 无调用方 |
| 246 补充三（三场一级、满 27 次） | 派执行中 | 已落地 | architecture v4.30 |

## 占位数值核实

按 [执行方案](plans/2026-11-09-claude-next-execution.md) §3 第 5 条。「仍是占位」= 作者没定、也没经过台架；「已校准但待真人验证」= 架构设计按台架定过数，没有真人数据；「已有定案」= 作者明确定的（或明确认可推荐）。

| 数 | 现值 | 位置 | 分类 | 依据 |
|---|---|---|---|---|
| 目标胜率：普通 / 精英 | 约七成 / 约五成 | 242 §3.3 | 仍是占位（建议） | 242 §3.3「目标带的具体数留作者定」 |
| 目标胜率：猎手 | 五成 | 242 §3.3 | 已有定案 | 073 作者定 |
| 战斗力估算系数 | 全表 | `data/authoring/balance/power_weights.json` | 仍是占位 | 文件 `_说明`「全是占位」；242 §九 建议先改锤 / 秘银 / 毒刀 |
| 武器伤害带（白 ≤ 8 / 绿 10～12 / 蓝 14～17 / 紫 20～24） | 按带落数 | `data/authoring/items/` | 已校准但待真人验证 | 279 §八 架构设计定调；v5.12～v5.16 台架（`reports/balance/2026-11-04-w279.md`） |
| 橙带 | 48～56 | 同上 | 已校准但待真人验证 | 作者 08:11「大幅提升」；281 §三、v5.18 台架 |
| 红武裸数 DPS | 180～220 | 8 件红武 | 已校准但待真人验证（机制未做） | 281 §八 09:05 架构设计定；v5.20 |
| 品质每档（×1.1、暴击 +5 点、个数 +1、上限 2、取较高、卖价不涨） | 同左 | `BattleCompiler.quality_stats` | 已有定案 | 279 待定 12～16：作者 2026-11-04 17:00「可以」；每下叠层照加 = 作者 08:11 |
| 法杖威力系数 | 1 / 1.15 / 1.3 / 1.45（大法师杖装晶后进橙带） | 法杖 `combat.power_mult` | 已校准但待真人验证 | 273；281 §八 09:05 |
| 劣化版持有 / 掉落概率 | 持有 1% ×（1 + 进阶级），上限 5%；掉落 20% + 10% × 进阶级 | `core/run/red_sources.gd` | 仍是占位（按推荐落地） | 281 §七 待定 7（没回音按推荐）；作者只定了「极低概率」 |
| 寂灭计数 | 10 次变色、50 次全黑 | `core/run/jimie_path.gd` | 已有定案 | 作者 2026-11-05 10:47 原文 |
| 刹那 / 断水的次数（50 次经过、30 胜、三次抉择） | 未实装 | — | 已有定案（未实装） | 作者 11:37 原文 |
| 收费预设价格 | 清单定价之和 × 集市倍数 | `GameFlow.preset_price`；倍数 `MarketRules.price_mult` 默认 1.0 | 规则已有定案；集市倍数仍是占位 | 285 待定 5（按推荐）；`data/authoring/base_rules/market.json` 名字自带「（占位）」 |
| 局内商店：10 件、包 30%、金银 35%、商人钱袋 100 + 200 × 深度、收购价 × 0.3 | 同左 | `core/run/economy_rules.gd:26-42`、`economy_rules/standard.json` | 仍是占位（按推荐落地，未经平衡） | 290 待定 1～10 全按推荐；`economy_rules/standard.json` 名为「标准经济（占位）」 |
| 付费撤离点费用 | 50 | `core/run/economy_rules.gd:56` | 仍是占位 | 同文件第 4、55 行注释「作者给的占位」 |
| 托付格子 | 3 × 3（科技可扩） | `core/meta/meta_rules.gd:20` `safe_size` | 仍是占位 | 092；287 只改概念不改数 |
| 全局倒计时 | 魔法废墟 36 / 60 / 90；机关沙漏 24 / 40 / 60 | `chapters/free_mode.json`、`clockwork_hourglass.json` | 仍是占位 | 092（占位）；281 §八 13:08 执行定的沙漏三档 |
| 大型图规模参数 | `placeholder: true` | `chapters/free_mode.json:367`、`map_scale_profile.gd:31,92` | 仍是占位 | 053（作者「具体留空」） |
| 稀有度每格价 | 表 | `core/inventory/item_value.gd:12` | 仍是占位 | 文件注释「占位数值」 |
| 仓库大小 | 10 × 8（科技加行） | `core/meta/meta_rules.gd:12` | 仍是占位 | 文件注释 |
| 基地出售回定价几成 | 0.5 | `core/meta/meta_rules.gd:18` | 已有定案 | 091 作者定 |
| 魔晶石耐久 | 满 27 次、三场一级 | 魔晶石道具 `wear` | 已有定案 | 246 补充三，作者 10:37 选定；v4.30 |
| 掉落 / 携带 / 节点规则 / 敌人池整份 | 全表 | `drop_rules/standard.json`、`carry_rules/standard.json`、`node_rules/standard.json`、`enemy_pools/standard_ruins.json`、`hunters.json` | 仍是占位（档位武器上限等少数字段经台架调过） | 各文件 `display_name` 自带「（占位）」；279 v5.12～v5.14 只动了 `weapon_rarity_cap` / `weapon_no_true_damage` |
| 常规事件结果权重 | item / restore / story | `core/run/node_rules.gd:11,32` | 仍是占位 | 文件注释 |

## 已实现、暂无内容的字段（140 登记，本次复核）

| 什么 | 2026-11-10 复核 |
|---|---|
| 套装（`core/sets`、`set_editor`、`ItemDef.set_id`） | 仍无内容：`data/sets/` 为空，道具没有 `set_id` |
| 道具跨域效果 `ItemDef.effects` | 仍无内容（道具 JSON 顶层没有 `effects` 键） |
| 包体加成 `bag_mods` | **已有内容**：8 件道具在用 |
| 敌人 `loadout` | **已有内容**：10 个敌人在用 |
| 非矩形容器 `GridInventory.set_blocked` | **已在用**：`core/run/character_def.gd:105` |
| `EnemyPoolEntry.min_danger` | **已在用**：`enemy_pools/clockwork.json` 3 处 |
| `HunterMechanic.count_by_scale` | 仍没填（四份难度都没有） |
| `DropRule.treasure_modified` | 仍没填（两份掉落规则都没有） |

## 历史

| 阶段 | 报告 | 架构版本 | 一句话 |
|---|---|---|---|
| M1～M6 | 001～057 | — | 背包、战斗、内容管线、地图、节点内容、存档、场景流；循环闭合 |
| 作者提议 058 / 059 | 060～068 | — | 地上按点清、仓库格子化与图鉴、buff 骨架、事件层、开局预选、搜索揭示（外框可选，没做） |
| 069 难度与猎手 / 第 7 阶段侵蚀 | 070～075 | — | 难度是机制清单、猎手、角色技能、校准工具、侵蚀 |
| 第 8 阶段内容扩充（进行中） | 076～ | — | 传送点、事件构件、格阵模板、世界观与信仰体系、局内技能 |
| 三张序章 | 083、085、113、114 | — | 序章之后只有自由模式（现为魔法废墟 / 机关沙漏） |
| 架构体检 | 097～109 | v2.07～v2.26 | 存档迁移、内容管线收口、RunState 拆分、测试归位、战斗规则、信仰进编译器 |
| 界面与美术大改 | 约 170～271 | v3.00～v4.98 | 悬浮窗定稿、开局 / 基地 / 结算重做、英文、音效、字号三档、集市、后勤 |
| 平衡方法 | 151、242 | v4.23、v4.24 | 木桩 + 扫表 + 对局记录；首跑结论见 242 §九（历史结论，不代表当前版本） |
| 武器网与红武 | 272～281 | v5.00～v5.27 | 战记、法杖系数、拼接 / 砧 / 品质、紫橙、极端武器、红武数据与寂灭来路 |
| 近期规则重做 | 282～290 | v5.28～v5.46 | NPC、材料节点、收费预设、配方悬浮窗与营地砧、托付、文本普查、耐力来源、局内商店 |
| 完成度评估 | 238 | v4.16 时 | 历史评估：机制 9.5、内容 5、数值 2……（数量已过时，不直接照搬） |

旧版「留给作者定的」长清单与「分支与工作目录」（Windows 路径、`m4-enemy-pool` 等）已过时，见 `git show b1c0f009:docs/status.md`；仍未定的几条已并入上面「需要作者决定」。
