# 现状总览

> 2026-09-23 ｜ `main` @ `e0241c8` ｜ 架构文档 v1.51 ｜ 这是一份**活文档**：每完成一个里程碑更新一次，历史看 `docs/reports/`

## 一句话

背包、战斗、内容管线、地图、节点内容、一局的状态与存档都已落地并有测试；在地图沙盒里能从挑出生点玩到撤离或战败。
**还没有的是把这些串成游戏的场景流（M6）**，以及侵蚀（第 7 阶段）与局外成长。

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
| M6 场景流 | **未开始** | — | `GameDirector` 状态机、主菜单 → 开局选装备 → 地图 ⇄ 战斗 / 搜刮 / 商店 / 事件 / 休息 → 撤离 / 战败结算 → 局外成长 |
| 第 7 阶段 侵蚀 | 未开始 | — | `ErosionField` / `ErosionSchedule`，钩子与顺序已在 `MapTravel` 里定死 |
| 第 8 阶段 内容扩充 | 未开始 | — | 道具、敌人、事件、新章节地图形态、扩展移动机制 |

## 代码地图（210 个脚本，core 约 1.4 万行）

| 目录 | 管什么 | 入口类 |
|---|---|---|
| `core/inventory` | 容器、形状、道具定义与实例、搬运 | `GridInventory`、`ItemStash`、`ItemDef`、`ItemInstance`、`InventoryService`、`ItemValue` |
| `core/battle`（+ damage / triggers / cadences / costs / effects） | 编译、属性、规则、模拟、伤害、增益 | `BattleCompiler`、`BattleSim`、`EffectRegistry`、`CombatantBaseline` |
| `core/effects`、`core/sets`、`core/loot/effects` | 效果树的根、套装、战利品效果 | `Effect`、`SetTracker`、`LootEffect` |
| `core/authoring` | 内容管线 | `ContentImporter` / `ContentExporter` / `ContentSchema` / `ContentPaths` |
| `core/map`（+ generators） | 数据层、生成器、校验、导航、文本往返、预设 | `MapGraph`、`MapGenerator`、`RingMapGenerator`、`RingTypeAssigner`、`MapNavigator`、`MapGridText` |
| `core/enemies` | 敌人池、档位、组装、预览编译 | `EnemyPool`、`EnemyPlacer`、`EnemyKit` |
| `core/loot` | 掉落规则与掷骰、修正来源接缝、装箱 | `DropRule`、`DropResolver`、`DropBonusSource`、`LootPacker` |
| `core/run` | 一局：旅程、体力、钱、节点事件、搜索 / 商店会话、规则、状态与存档 | `RunState`、`RunSave`、`MapTravel`、`NodeEvents`、`Vitality`、`Wallet` |
| `ui` | 五个沙盒 / 编辑器 + 启动选择器 | `launcher`、`inventory_sandbox`、`battle_sandbox`、`content_editor`、`map_sandbox`、`map_editor` |
| `tools` | 命令行：导入 / 导出 / 归一化内容、脚本检查、批量统计、样例生成、截图 | `import_content`、`normalize_content`、`check_scripts`、`map_stats` |
| `tests` | 38 个套件，`tools/test.sh` 一键跑 | `run_tests` |

## 数据与内容管线

`data/authoring/<kind>/*.json`（人写，进 git）→ `tools/import_content.gd` → `data/<kind>/*.tres`（引擎读，也进 git）。
种类与导入顺序：`buffs → sets → items → enemies → enemy_pools → drop_rules → node_rules → economy_rules → chapters`（后者按 id 引用前者）。
`tools/normalize_content.gd` 把作者数据重写成导出器的格式（仓库里的 JSON 是往返不动点，测试逐字节比）。

现有内容：22 件道具（三个流派标签 `burst` / `rapid` / `bleed`）、6 种敌人、1 个敌人池、掉落 / 节点 / 经济规则各 1 份、第一章 1 份、手绘地图 2 份。
**数值全是占位**（见下）。

## 沙盒与工具

启动选择器五个入口：背包沙盒、战斗沙盒、道具编辑器、地图沙盒（M5 之后是 `RunState` 的一层皮：挑出生点、看敌人、打、掉、搜、买、休息、存档 / 读档、撤离）、地图编辑器（随机生成或手绘，改完存回章节）。
命令行：`bash tools/test.sh`（全套测试，先 `--import` 重建类缓存）、`import_content`、`normalize_content`、`check_scripts`、`map_stats`。

## 测试

38 个套件、6406 项断言，机器空闲时 70～90 秒（开着别的 Godot 编辑器会到 4 分钟，超时放到 480 秒）。
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
| `core/battle/combatant_baseline.gd`、`core/run/vitality.gd`、`core/run/run_state.gd` | 生命 25 / 耐力 50、体力上限 5、棋盘 8×6 —— 等角色系统 |
| `core/inventory/item_value.gd` | 稀有度每格价 |

## 留给作者定的

来自各报告「没做的 / 留给作者」：

- **地图**（053 的设想，未采纳）：高危区改成路线铺完再岔（三）+ 搜索路线在撤离环间横着走一段弧后在共用撤离点结束、商店挪到出口之后（二）；回头环路（一）可不做。作者已回应「三 + 二」，等一句「做」。大型图（9 环以上）的两道撤离环间没定。
- **节点内容**：珍宝道具本身（用 `treasure` 标签占位，现在一件都没有，定义了之后 046 的一条断言会红提醒改回正面）；幸运值从哪来；局外 / 地图 buff 对掉落的内容；遭遇后打赢了能不能接着搜（现在不能）；商店能不能回头（现在走了算用过）；卖东西给商店（没做）；常规事件只有三种占位结果；`random` 节点符号 `P` / `X` 在表里的定名。
- **架构文档 15 节**：侵蚀损失的形式、节点事件的额外行动消耗（现在一律只按边的 `action_cost`）、撤离后的保留规则、棋盘尺寸与开局可用格、合成配方、暂存区清空时机、角色基线、元素性质。

## 分支与工作目录

- `main`（远端同步）包含全部工作：M1～M5、探索度、作者七条与设想（052 / 053）。
- `author-seven-map-rules` 已并入 `main`，可以删。
- `G:\oziuc\背包搜打撤-m4` 是一个 worktree（分支 `m4-enemy-pool`，与 `main` 同一提交），M4 起在这里做，可以 `git worktree remove` 掉。
- `G:\oziuc\背包搜打撤` 主目录停在 `author-seven-map-rules`：`git checkout main && git pull` 即可拿到全部。

## 下一步

按实施顺序是 **M6 场景流**（架构文档 8 节）：`GameDirector` 显式状态机持有 `RunState`；`add_child` / `queue_free` 手动管场景，
不用 `change_scene_to_file`（要在地图上叠战斗与搜刮）；主菜单 → 开局选装备 → 地图 → 战斗回放 / 搜刮界面（6.2 渐进揭示）/ 商店 / 事件 / 休息
→ 撤离结算（背出去的按价值计分）/ 战败结算 → 局外成长（15 节第 4 项）。M5 留好的接缝：`RunState.pending_loot`、`try_extract`、`phase_changed`、`NodeEvents` 的信号。
之后是第 7 阶段侵蚀（`MapTravel.erosion` 钩子已在），再是内容扩充。
