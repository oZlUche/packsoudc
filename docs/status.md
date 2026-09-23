# 现状总览

> 2026-09-23 ｜ `main`（M6 之后，058 / 059 实施中）｜ 架构文档 v1.62 ｜ 这是一份**活文档**：每完成一个里程碑更新一次，历史看 `docs/reports/`

## 一句话

背包、战斗、内容管线、地图、节点内容、一局的状态与存档都已落地并有测试；**正式游戏能从主菜单一条线玩到结算与仓库**
（M6：开局挑装备、从仓库带 → 地图 → 战利品一件一件亮出来拖走 → 撤离确认 → 结算 → 仓库 → 再来一局，循环闭合）。
还没有的是侵蚀（第 7 阶段）、内容扩充（第 8 阶段）、局外成长的内容（仓库怎么花）。

## 里程碑

| 里程碑 | 状态 | 报告 | 一句话 |
|---|---|---|---|
| M1 网格背包 | 完成 | 001～007、024、025、028 | 棋盘 + 包体、异形占格（0/1 矩阵）、暂存区是列表、顶替式放置、包可旋转 |
| M2 自动战斗 | 完成 | 008～022 | 编译（背包 → 战斗单位）、效果树（时机 / 频率 / 消耗 / 效果四层）、事件驱动模拟、伤害管线、增益、战斗回放 |
| 内容管线 | 完成 | 023、026、043 | JSON ⇄ .tres，导入器不认识具体效果（反射 + 注册表），校验比引擎严格，可视化编辑器 |
| 套装与跨域效果 | 完成 | 019、020 | 激活在背包层，一棵效果树按作用域分支 |
| M3 地图 | 完成 | 027（规划）、029～044、052、053 | 拓扑无关数据层、环形生成器（骨架先行、路线风格、高危区、换乘、撤离环间）、手绘网格脚本、类型分配、角度求解布局、地图编辑器、行动计数与单步移动 |
| M4 节点内容 | 完成 | 045（规划）～050 | 敌人池（档位 / 流派 / 组装）、掉落（每件各掷 / 珍宝）、随机点与搜索点、节点事件接线、经济（进账 / 商店 / 付费撤离点）、探索度 |
| M5 运行状态与存档 | 完成 | 051 | `RunState` 装壳、`RunRNG`、`RunSave`，读档之后接着走和没存过一样 |
| M6 场景流 | 完成 | 055（规划 + M6-1）、056、057 | 纯逻辑状态机 `GameFlow` + 导演与十一屏（主场景换成正式游戏）；开局装备走管线；结算 `RunResult`、局外 `MetaState` / `MetaSave`；`LootView` 渐进揭示、亮出来的直接拖到棋盘、搜索点逐次装；仓库带进下一局（死了就没了）；撤离确认 |
| 作者提议 058 / 059 | **进行中** | 058、059（提议）、060～063 | 1 暂存区按点清空 ✅（060）→ 2 仓库格子化、结算置入、图鉴 ✅（061）→ 3 buff 骨架 ✅（062）→ 4 事件层与容器屏合一 ✅（063）→ 5 开局预选与角色 → 6 搜索揭示 → 7 外框（可选） |
| 事件编辑器 | 完成 | 064 | 写文字、导入配图、拼选项（条件 / 后果下拉来自注册表）、预览照事件屏画、挂进节点规则；存盘 = JSON + .tres；按性价比做在项目里而不是独立 exe |
| 第 7 阶段 侵蚀 | 未开始 | — | `ErosionField` / `ErosionSchedule`，钩子与顺序已在 `MapTravel` 里定死 |
| 第 8 阶段 内容扩充 | 未开始 | — | 道具、敌人、事件、新章节地图形态、扩展移动机制 |

## 代码地图（230 个脚本，core 约 1.5 万行）

| 目录 | 管什么 | 入口类 |
|---|---|---|
| `core/inventory` | 容器、形状、道具定义与实例、搬运 | `GridInventory`、`ItemStash`、`ItemDef`、`ItemInstance`、`InventoryService`、`ItemValue` |
| `core/battle`（+ damage / triggers / cadences / costs / effects） | 编译、属性、规则、模拟、伤害、增益 | `BattleCompiler`、`BattleSim`、`EffectRegistry`、`CombatantBaseline` |
| `core/effects`、`core/sets`、`core/loot/effects` | 效果树的根、套装、战利品效果 | `Effect`、`SetTracker`、`LootEffect` |
| `core/authoring` | 内容管线 | `ContentImporter` / `ContentExporter` / `ContentSchema` / `ContentPaths` |
| `core/map`（+ generators） | 数据层、生成器、校验、导航、文本往返、预设 | `MapGraph`、`MapGenerator`、`RingMapGenerator`、`RingTypeAssigner`、`MapNavigator`、`MapGridText` |
| `core/enemies` | 敌人池、档位、组装、预览编译 | `EnemyPool`、`EnemyPlacer`、`EnemyKit` |
| `core/loot` | 掉落规则与掷骰、修正来源接缝、装箱 | `DropRule`、`DropResolver`、`DropBonusSource`、`LootPacker` |
| `core/run`（+ effects、events） | 一局：旅程、体力、钱、节点事件、搜索 / 商店会话、规则、状态与存档；场景流状态机、开局装备、结算；buff（局外 / 一局）与一局规则的构件；事件层（事件、选项、条件与后果构件、铺放） | `RunState`、`RunSave`、`MapTravel`、`NodeEvents`、`Vitality`、`Wallet`、`GameFlow`、`LoadoutDef`、`RunResult`、`RunBuffDef`、`RunBuffs`、`RunContext`、`EventDef`、`EventPlacer` |
| `core/meta` | 跨局：仓库格子（大小是 `MetaRules`）、带回来的棋盘与一键置入、图鉴、钱、战绩、保留规则（`absorb()` 一处）、存档 v2 | `MetaState`、`MetaSave`、`MetaRules` |
| `core/settings` | 玩家设置（暂存区提醒档位），`user://settings.json` | `GameSettings`（挑要提的在 `core/run/storage_warning.gd`） |
| `ui/game` | 正式游戏（主场景）：导演 + 屏的底座 + 各屏（事件屏先过、容器屏战利品 / 搜索合一）+ 背包整理面板 + 仓库面板 + 渐进揭示的战利品视图 | `GameDirector`、`GameScreen`、`LootView`、`map_screen`、`event_screen`、`container_screen`…… |
| `ui`（其余） | 六个沙盒 / 编辑器 + 启动选择器（开发期入口） | `launcher`、`inventory_sandbox`、`battle_sandbox`、`content_editor`、`event_editor`、`map_sandbox`、`map_editor` |
| `tools` | 命令行：导入 / 导出 / 归一化内容、脚本检查、批量统计、样例生成、截图 | `import_content`、`normalize_content`、`check_scripts`、`map_stats` |
| `tests` | 44 个套件，`tools/test.sh` 一键跑 | `run_tests` |

## 数据与内容管线

`data/authoring/<kind>/*.json`（人写，进 git）→ `tools/import_content.gd` → `data/<kind>/*.tres`（引擎读，也进 git）。
种类与导入顺序：`buffs → sets → run_buffs → items → loadouts → events → enemies → enemy_pools → drop_rules → node_rules → economy_rules → meta_rules → chapters`（后者按 id 引用前者）。
`tools/normalize_content.gd` 把作者数据重写成导出器的格式（仓库里的 JSON 是往返不动点，测试逐字节比）。

现有内容：22 件道具（三个流派标签 `burst` / `rapid` / `bleed`）、3 套开局装备（标准 / 拾荒者 / 打手）、6 种敌人、1 个敌人池、
掉落 / 节点 / 经济 / 局外规则各 1 份、4 个测试用的 buff（坚韧 / 幸运 / 被盯上了 / 虚弱）、6 个占位事件（搜索点默认、上锁的箱子、陌生人、熟面孔、歇脚处、动静）、第一章 1 份、手绘地图 2 份。
**数值全是占位**（见下）。

## 沙盒与工具

**主场景是正式游戏** `ui/game/game.tscn`：主菜单（新的一局 / 继续上次 / 仓库与战绩 / 设置 / 开发工具）→ 开局（挑章、挑装备、从仓库带、种子）→ 地图（B 开背包、走出发生过事的点前提醒暂存区、撤离点上撤离、存档并回主菜单）
⇄ 叠层（战斗回放、战利品、搜索、商店、事件、休息）→ 结算 → 仓库与战绩。F1 回启动选择器。
启动选择器（开发期入口）：正式游戏、背包沙盒、战斗沙盒、道具编辑器、事件编辑器（写文字、导入配图、拼选项、挂进节点规则）、地图沙盒（`RunState` 的一层皮）、地图编辑器（随机生成或手绘，改完存回章节）。
命令行：`bash tools/test.sh`（全套测试，先 `--import` 重建类缓存）、`import_content`、`normalize_content`、`check_scripts`、`map_stats`、
`capture_scene`（截图；`DEMO_SCREEN=setup / map / bag / battle / loot / search / result / meta` 把正式游戏推到那一屏）。

## 测试

43 个套件、7001 项断言，机器空闲时 70～90 秒（开着别的 Godot 编辑器会到 4 分钟，超时放到 480 秒）。
期望从数据推，不写死；统计类断言用千次抽样留容差；沙盒有帧测试。

## 占位数值清单（作者定数时改这些文件）

| 文件 | 占位的数 |
|---|---|
| `data/authoring/enemies/*.json` | 六种敌人的血、护甲、本色档位、招牌 |
| `data/authoring/enemy_pools/standard_ruins.json` | 条目权重与出现条件、档位表（件数 / 棋盘 / 倍率 / 稀有度上限）、档位规则（深度 / 危险 / 类型 / 难度 / 规模 / 探索度）、组装规则 |
| `data/authoring/drop_rules/standard.json` | 按稀有度的掉落率、难度 / 幸运每级加多少、珍宝概率与两档权重 |
| `data/authoring/node_rules/standard.json` | 随机点权重、搜索（次数 / 遭遇曲线 / 件数 / 稀有度权重 / 深度与危险增益）、输了扣几点、休息回几点、事件结果权重、战斗时限 |
| `data/authoring/economy_rules/standard.json` | 开局钱、奖励公式系数、商店格数 / 权重 / 价格倍数 / 刷新费、付费撤离点个数与费用（50） |
| `data/authoring/chapters/chapter_01.json` | 地图配置（环、路线风格、规模模板、高危区、类型风险收益、覆盖……）、难度 |
| `data/authoring/items/*.json` | 道具数值、稀有度、价值 |
| `data/authoring/loadouts/*.json` | 三套开局装备的清单与说明 |
| `data/authoring/meta_rules/standard.json` | 仓库大小 10×8（局外成长改它） |
| `data/authoring/run_buffs/*.json` | 四个测试用的 buff 的数（体力 +1、幸运 +1、虚弱 5 步 −10%） |
| `data/authoring/events/*.json`、`node_rules/standard.json` 的 `events_by_type` | 六个占位事件的文字、选项、数；哪种点配哪些事件、权重（用事件编辑器写，064）|
| `core/meta/meta_state.gd` `absorb()` / `keeps()` | 撤离后的保留规则（棋盘带回、图鉴每件计一次、钱带出；战败全失）；什么能存进局外（现在：不是包） |
| `core/battle/combatant_baseline.gd`、`core/run/vitality.gd`、`core/run/run_state.gd`、`ui/game/game_director.gd` | 生命 25 / 耐力 50（正式游戏里玩家 60）、体力上限 5、棋盘 8×6 —— 等角色系统 |
| `core/inventory/item_value.gd` | 稀有度每格价 |

## 留给作者定的

来自各报告「没做的 / 留给作者」：

- **地图**（053 的设想，未采纳）：高危区改成路线铺完再岔（三）+ 搜索路线在撤离环间横着走一段弧后在共用撤离点结束、商店挪到出口之后（二）；回头环路（一）可不做。作者已回应「三 + 二」，等一句「做」。大型图（9 环以上）的两道撤离环间没定。
- **节点内容**：珍宝道具本身（用 `treasure` 标签占位，现在一件都没有，定义了之后 046 的一条断言会红提醒改回正面）；遭遇后打赢了能不能接着搜（现在不能）；商店能不能回头（现在走了算用过）；卖东西给商店（没做）；六个事件的文字与图像是占位，商店 / 休息点还没配事件；`random` 节点符号 `P` / `X` 在表里的定名。
- **作者五条提议**（[058](reports/058-author-five-proposals.md)，已整理评估、未实施）：节点外框；开局预选（角色占位 + 带入限制 3×3 / 3 件 / 稀有度上限，建议建 `CharacterDef`）；
  暂存区在离开发生过事的点时清空 + 分层提示（15 节第 7 项作者已定案）；仓库格子化（随局外成长）+ 图鉴（累计件数）；结算屏保留棋盘 + 一键置入；带入的限制就是初始包的空间、包只出不进；搜索揭示按稀有度计时、未搜的只能在容器内挪位。第三轮又加了事件层与两种 buff（[059](reports/059-event-layer-and-buffs-proposal.md)）；顺序：暂存区 → 仓库与结算与图鉴 → buff 骨架 → 事件层 → 开局预选 → 搜索揭示 → 外框，
  058 与 059 的问题已全部有答案（战斗事件暂不绕开但结构开放、事件生成时定进节点但可被覆盖、局外选项先是开关列表、地图 buff 时限是字段），**按 059 第四节的顺序实施中**。
- **局外**（M6）：钱要不要带出去（现在带）；局外货币怎么花（058 的图鉴 + 制作是一个答案）、卖掉仓库里的东西、局外成长（15 节第 4 项）；常规事件的内容与事件屏的文字（占位）；
  揭示间隔 0.3 秒是常量占位（角色「搜索速度」等角色系统）；玩家基线生命 60 是占位。
- **架构文档 15 节**：侵蚀损失的形式、节点事件的额外行动消耗（现在一律只按边的 `action_cost`）、撤离后的保留规则（现在的假设见上）、棋盘尺寸与开局可用格、合成配方、暂存区清空时机、角色基线、元素性质。

## 分支与工作目录

- `main`（远端同步）包含全部工作：M1～M6、探索度、作者七条与设想（052 / 053）。
- `author-seven-map-rules`、`m4-enemy-pool`、`m6-scene-flow` 已并入 `main`，可以删。
- `G:\oziuc\背包搜打撤-m4` 是一个 worktree（M4～M6 在这里做，与 `main` 同一提交），可以 `git worktree remove` 掉。
- `G:\oziuc\背包搜打撤` 主目录：`git checkout main && git pull` 即可拿到全部。

## 下一步

作者已拍板，按 059 第四节的顺序做：~~暂存区（离开发生过事的点时清）~~ 完成（060）→ ~~仓库格子化、`MetaRules`、结算屏一键置入、图鉴~~ 完成（061）→ ~~buff 骨架~~ 完成（062）→ ~~事件层与容器屏合一~~ 完成（063）→ **开局预选与 `CharacterDef`** → 搜索揭示 → 节点外框（可选）。
之后按实施顺序是**第 7 阶段侵蚀**（架构文档 5.7）：`ErosionField` / `ErosionSchedule`，钩子与顺序已在 `MapTravel.erosion`；浅层扣体力、深层损坏背包物品（按价值，6.4），
数值走章节配置。再之后是第 8 阶段内容扩充（道具、敌人、事件、新章节地图形态、扩展移动机制）。053 的设想（三 + 二）仍等作者一句「做」。
