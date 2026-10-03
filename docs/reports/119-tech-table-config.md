# 119 方案：科技树写成配置表 —— `docs/techs.xlsx` 生成科技 JSON；亮不亮由另一张表（存档进度）决定

> 架构 · 提议（2026-10-03）。作者：「关于科技树的配置，希望写成配置表，是否点亮则通过读取另一张表来决定」。
> 接 118（已落地：十节点三列、左树右板、`tech_run_buff` / `tech_safe_size`）。本篇只改**数据怎么来**，不改树的玩法与界面。
> 配套交付：`docs/techs.xlsx` 已按落地的十节点二十六级生成好（本篇随附），执行时直接用。

## 一、现状（已核实）

- 科技现在是 **一个节点一份 JSON**：`data/authoring/techs/<id>.json`（`id / display_name / display_names / order / requires / column / description / effect / tiers`），`tech_run_buff` 节点再带 **每级一份** `data/authoring/run_buffs/tech_<id>_<级>.json`（scope META，一个 `effects[0]`）。十个节点 = 10 + 18 = 28 份文件；改一个数要翻两处。
- 亮不亮已经和定义分开：`MetaState.tech_levels`（id → 级）和 `tech_deposits` 记在存档（v3）里，`TechService.level / prereqs_met / ready` 只读它们；`TechTreeView` 读定义画树、读存档决定亮 / 可点 / 锁。**所以「另一张表」现在就存在，只是它叫存档**。
- 仓库里已有「表是唯一来源」的先例：`docs/gods.xlsx` → `tools/gods_xlsx_to_json.gd`（全有或全无）→ `GodsTable.check()` 在 `tools/check_content.gd` 里跑，表与 JSON 对不上 `tools/test.sh` 当场红；`XlsxReader` 只读值。照搬即可。

## 二、配置表 `docs/techs.xlsx`（唯一来源）

三张工作表，表头那一行当键（和 `GodsTable._table` 一样）：

### 「节点」—— 一行一个科技

| 列 | 落到 | 说明 |
|---|---|---|
| id | 文件名 + `id` | 英文小写下划线，唯一 |
| 名称 / 英文名 | `display_name` / `display_names.en` | |
| 列 | `column` | 0 起 |
| 排序 | `order` | 可空 = 0 |
| 前置 | `requires` | 多个用「、」分开；空 = 根节点。深度仍按前置算，不进表 |
| 说明 | `description` | 右板总述，不写数字 |
| 效果构件 | `effect.type` | `RunRegistry.TECH_EFFECTS` 里的键 |
| 构件参数（JSON） | `effect` 其余字段 | `tech_safe_size` → `{"cols": 0, "rows": 1}`；`tech_run_buff` → `{"effect": "<RUN_EFFECTS 键>"}`（见下） |
| 每级说明模板 | 生成的 run_buff 的 `description` | 只 `tech_run_buff` 用；占位符照 `docs/text-placeholders.md` |

### 「等级」—— 一行一级

| 列 | 落到 | 说明 |
|---|---|---|
| 科技 id | 归哪个节点 | 一个科技有几行就有几级；级号从 1 起连续 |
| 级 | `tiers` 下标 + 1 | |
| 钱 | `tiers[k].funds` | 整数 |
| 材料 | `tiers[k].items` | `steel_ingot: 2；rivet_box: 1`（「；」并列，同献祭条件的写法）；空 = 不要 |
| 效果参数（JSON） | 生成的 `run_buffs/tech_<id>_<级>.json` 的 `effects[0]` 其余字段 | 只 `tech_run_buff` 用，如 `{"amount": 3}`；空 = 全默认 |

### 「说明」—— 人话，怎么读怎么改（已写在表里）

**`tech_run_buff` 的两层**：节点行定「哪种一局效果」（`{"effect": "luck_bonus"}`）和说明模板，等级行只填参数。工具按级生成 `run_buffs/tech_<id>_<级>.json`：`{"id": "tech_luck_3", "display_name": "幸运（科技）", "description": <模板>, "scope": "META", "effects": [{"type": "luck_bonus", "amount": 3}]}`，并把 `effect.buffs = ["tech_luck_1", …]` 写进节点 JSON —— 作者再不用碰 run_buff 文件。

和神明总表的一处不同：**科技 JSON 全量由表生成**（表里有的字段就是 JSON 的全部字段），不像信仰那样「只盖机器读的列、其余保留」—— 科技没有表外字段。表里没有的科技 → 删 JSON（含它的 `tech_*` run_buff）；JSON 里有、表里没有 → check 报不一致。

## 三、另一张表：进度表 = 存档

「是否点亮」**不进配置表**，由第二张表决定，这张表就是存档里的 `tech_levels`（id → 当前级）：

- 配置表回答「树长什么样、每级要什么」；进度表回答「这个玩家点到哪了」。两张表只靠 id 对上，`TechService` 与 `TechTreeView` 已经是这么读的，**不用改逻辑**。
- 配置表改了（删节点、减级数），`TechService.heal` 已经会把进度表里对不上的条目修掉（110）。
- 要让**测试 / 调试**时手改进度表：开发区（`meta_screen` 右列，非导出包）加一块「科技等级」，每个节点一个数字框，改了直接写 `tech_levels` 并重算 `tech_buffs / safe_bonus`（走 `TechService.heal` 同一条路）。不另做文件，存档就是那张表。
- 不推荐做成「初始点亮表」（新档默认亮哪些）：现在没有这个需求，要用时在节点表加一列「初始级」即可，不必另开一张表。

## 四、工具与检查

| 文件 | 做什么 |
|---|---|
| `core/authoring/techs_table.gd`（`TechsTable`） | 照 `GodsTable`：`PATH = "res://docs/techs.xlsx"`；`fields(sheets, problems)` 读三张表 → id → {节点字段, tiers, run_buffs}；`generate(fields)` → {路径: JSON 字典}（节点 + run_buff）；`check()` → 问题清单（表里每个节点都有 JSON、JSON 里的科技都在表里、`tech_*` run_buff 与表一致、按表生成的和磁盘上的一致） |
| `tools/techs_xlsx_to_json.gd` | 照 `gods_xlsx_to_json.gd`：读表 → 全有或全无地写 `data/authoring/techs/*.json` 与 `data/authoring/run_buffs/tech_*.json`，删表里没有的；提示接着跑 `import_content.gd` |
| `tools/check_content.gd` | `problems.append_array(TechsTable.check())` 一行 |
| `tests/meta/test_techs_table.gd` | 表读得出十节点二十六级；生成的 JSON 与仓库现有的一致（deep compare）；坏表（级号断档、前置不存在、构件未注册、材料不是道具 id、`JSON` 格解析不了、同 id 两行）每种各一例进 problems 且一份都不写 |
| `docs/techs.md` | 工具顺手生成的只读镜像（节点表 + 等级表两张 Markdown 表，表头一行写「源是 xlsx」），省得再手写一份像 `docs/gods.md` 那样会落后的 |

表里的校验（进 `problems`，任何一处有错一份都不写）：id 唯一且合法；前置都在表里、无环（复用 `TechService.cycle_members`）；效果构件在 `TECH_EFFECTS`、`tech_run_buff` 的 `effect` 在 `RUN_EFFECTS`；每级连续从 1 起、钱为非负整数；材料是 `items` 里的 id、数量正整数；JSON 格能解析成字典；`tech_run_buff` 节点必须有说明模板，模板过 `TextLint`。

## 五、改动点

| 文件 | 改动 |
|---|---|
| `docs/techs.xlsx` | **已随本篇生成**（节点 10 行、等级 26 行，和落地 JSON 一一对应）；执行线程跑一遍工具应当零改动 |
| `core/authoring/techs_table.gd` 新 | 读表 / 生成 / 对照 |
| `tools/techs_xlsx_to_json.gd` 新 | 写回 |
| `tools/check_content.gd` | 加一行对照 |
| `tests/meta/test_techs_table.gd` 新 | 见上 |
| `ui/game/meta_screen.gd` | 开发区「科技等级」数字框（非导出包） |
| `docs/techs.md` 新、`docs/reports/README.md`、`CLAUDE.md`（改科技先改表） | 文档 |

不改：`TechDef / TechTier / TechEffect / TechService / TechTreeView`、存档格式。

## 六、待定（按推荐即执行）

| # | 问题 | 推荐 |
|---|---|---|
| 1 | 「另一张表」是存档进度表，还是再做一张设计期的「初始点亮表」 | **存档**（§三）；开发区加手改进度的数字框代替文件 |
| 2 | 科技 JSON 是全量生成还是像信仰那样只盖机器读的列 | **全量生成**，表是唯一来源；表里没有的科技连 run_buff 一起删 |
| 3 | `tech_run_buff` 每级的 run_buff 要不要留手写口子 | **不留**，全部由表生成；要特殊效果就加构件 |
| 4 | 镜像 `docs/techs.md` 要不要 | **要**，工具生成，不手写 |
| 5 | 格式 xlsx 还是 csv | **xlsx**，和神明总表一致，`XlsxReader` 现成 |
