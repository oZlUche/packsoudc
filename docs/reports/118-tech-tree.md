# 118 · 方案：局外科技树 —— 左边自下而上点亮的树，右边名称 / 效果 / 费用面板

> 架构设计线程，2026-10-03。作者原话：「关于未来的拓展，我想到的是其他局外科技，以科技树形式逐个点亮。设想的界面：左侧是树状的各个节点从下往上点亮，右侧是带有说明的面板，从上到下分别是节点名称、节点效果、激活节点费用」。
> 本文只做方案，不实施。数值全部是占位，作者随时改 JSON。

## 一、现状（已核实）

110 落地的局外科技已经是通用框架：`TechDef { id, display_name, order, effect: TechEffect, tiers: [TechTier{funds, items}] }`，状态在 `MetaState.tech_levels / tech_deposits`，逻辑在 `TechService`（level / next_tier / needed / submit / deposit / ready / upgrade / heal），效果构件登记在 `RunRegistry.TECH_EFFECTS`（现在只有 `warehouse_rows`）。基地「科技」页是**一列卡片**（每项科技一张：等级、钱、材料已交 / 需要、【升级】）+ 左边仓库格子 + 上交区（双击 / 拖进去上交，上交即消耗）。

一局的局外加成已有现成通路：`RunBuffDef`（`scope = META`，`effects` 是 `RunEffect` 构件：体力上限、开局钱、多搜几次、商店折扣、幸运、侦察、免罚败仗、基线属性……）→ `MetaState.active_buffs` → `RunState.start(..., p_meta_buffs)` → `RunState.buff_context()` 算出 `RunContext`，各系统读自己那一项。现在 `active_buffs` 只由基地右栏一列**开发用开关**切（架构文档 8.2 写的「占位：将来任务、局外科技」）—— 科技树正是它等的那个来源。

所以这次要加的是三样：**树的结构**（前置、位置）、**树的界面**、**几种新的科技效果**。框架不动。

## 二、数据：`TechDef` 加三个字段

| 字段 | 含义 |
|---|---|
| `requires: Array[StringName]` | 前置科技 id；**每一项都至少 1 级**才能点本节点（待定 1）。空 = 根节点 |
| `column: int` | 树上的列（0 起，从左往右）。同一列按深度从下往上排 |
| `description: String` | 面板「效果」区的一句总述（占位符照 112，不写数字 —— 数字由各级 `effect.describe()` 生成） |

深度不写：导入时按前置算（根 0，其余 = 前置里最深的 + 1），导入器拦：前置不存在、成环、同列同深度撞位。`order` 保留给同列同深度时的左右（撞位时只警告，不拦）。

多级科技（仓库扩建 6 级）在树上是**一个节点**，写 `Lv 2 / 6`；单级科技写「点亮 / 未点亮」（待定 3）。

## 三、效果：`TechEffect` 加两种构件

| 构件 | 字段 | apply（升到第 k 级） | heal（读档） | 面板那句 |
|---|---|---|---|---|
| `tech_run_buff` | `buffs: Array[StringName]`（下标 k−1 = 第 k 级给的 `RunBuffDef`，**替换**上一级的那条） | 从 `meta.tech_buffs` 里删 `buffs[k−2]`、加 `buffs[k−1]` | `tech_buffs` 里只留 `buffs[level−1]` | 那条 buff 的 `summary()`（`RunEffect.describe` 拼的，数字跟字段走） |
| `tech_safe_size` | `cols: int`, `rows: int`（每级加几列几行） | `meta.safe_bonus += (cols, rows)` | `safe_bonus = (cols, rows) × level` | `+1 列` / `+1 行` |

- `MetaState` 加 `tech_buffs: Array[StringName]`（科技给的局外 buff，和开发开关的 `active_buffs` 分开记，开关那一栏仍只管它自己）与 `safe_bonus: Vector2i`。都是有默认值的新字段，**不升存档版本**（098 的规矩）。
- `GameFlow` 开局把 `meta.active_buffs + meta.tech_buffs` 一起传给 `RunState.start`；`safe_size()` 加上 `meta.safe_bonus`。
- 导入器：`tech_run_buff.buffs` 长度必须等于 `tiers` 长度、每个 id 存在且 `scope = META`。
- 为什么走 `RunBuffDef` 而不是给科技自己一套效果：十种 `RunEffect` 构件、`RunContext`、各系统的读法、`summary()` 文字全是现成的；科技只需要说「第 k 级 = 这条 buff」。将来「局外任务奖励」也能走同一条路。

## 四、界面：科技页重做成「左树右板」

`ui/game/tech_panel.gd` 换成两栏（仓库格子搬到右板下面的上交区旁，见 4.3）：

### 4.1 左：`TechTreeView`（`ui/game/tech_tree_view.gd`）

- 节点按 `column` 横排、深度竖排，**深度 0 在最下面**，往上长；节点间距固定，总高超过就套 `ScrollContainer`（和 110 的仓库滚动一样）。
- 每个节点一块 160 × 60 的面板：名字 + 「Lv n / m」或「已点亮 / 未点亮」。三种样子：**已点亮**（主按钮橙色底 `UiPalette.BTN_PRIMARY`、白字）、**可点亮**（前置全满足、未满级：深底亮边 `BTN_SECONDARY_EDGE`，边框慢闪一下吸引注意）、**锁住**（`DIM` 字、无边）。选中的节点加一圈 `FG` 边。
- 节点之间按 `requires` 画线（`_draw`，从前置的顶边中点到本节点的底边中点）：两端都点亮了线是橙色，否则 `LINE` 色。
- 点一个节点 → 右板切到它；双击不做事（上交才双击，见 4.3）。

### 4.2 右：说明面板，从上到下

1. **名称**：`Names.of(def)`　`Lv n / m`（单级写「未点亮」/「已点亮」）
2. **效果**：`description` 一句（过 `TextTemplate`）；下面两行「现在：第 n 级的 `describe()`」「下一级：第 n+1 级的 `describe()`」（满级只有「现在」）。`tech_run_buff` 的 `describe()` 就是那条 buff 的 `summary()`。
3. **激活 / 升级费用**：「钱　需要 x / 持有 y」（够了绿、不够灰，和现在的卡一样）；材料每种一行「名字　已交 a / 需要 b ✓」；锁住的节点在这一区写「需要先点亮：前置名 ×n」（名字按 `Names.of`）；满级写「已满级」。
4. **按钮**：单级「点亮」、多级「升级」，`TechService.ready` 且前置满足才亮。

### 4.3 上交区与仓库

右板底下留上交区（110 那块自由格子）+ 一个「仓库」折叠面板（原来的左栏仓库格子，默认收起，点开才占地方）。**上交只给当前选中的节点**：双击仓库里的一件或拖进上交区 → `TechService.deposit(meta, 选中的 def, …)`；不是它下一级要的就提示「「X」不是它下一级要的」（110 的 `_taker` 「谁要就给谁」改掉，树上一次只看一个节点，歧义没了）。没选节点时上交区灰着。

### 4.4 `TechService` 加两个方法

`prereqs_met(meta, def, defs) -> bool`、`missing_prereqs(meta, def, defs) -> Array[TechDef]`；`ready()` 多一个条件。`upgrade()` 不变。

## 五、首批树（内容占位，三列各三到四个节点）

| 列 | 节点（级数） | 效果构件 | 前置 | 费用（占位） |
|---|---|---|---|---|
| 0 后勤 | **仓库扩建**（6） | `warehouse_rows`（已有） | — | 110 的那张表 |
| 0 后勤 | **保险箱扩格**（2） | `tech_safe_size`：+1 列 / +1 行 | 仓库扩建 | 300 / 600 + 建材 |
| 0 后勤 | **行囊**（3） | `tech_run_buff`：开局钱 +50 / +100 / +150（`starting_funds_bonus`） | 保险箱扩格 | 400 / 800 / 1200 |
| 1 体魄 | **耐久**（3） | 体力上限 +1 / +2 / +3（`vitality_max_bonus`） | — | 200 / 500 / 900 |
| 1 体魄 | **不屈**（1） | 输给节点敌人头一次不扣体力（`free_losses` 1） | 耐久 | 800 + 建材 |
| 1 体魄 | **筋骨**（3） | 开局生命 +5 / +10 / +15（`stat_bonus max_hp`） | 耐久 | 300 / 700 / 1200 |
| 2 探索 | **细搜**（2） | 每个搜索点多搜 1 / 2 次（`extra_searches`） | — | 250 / 700 |
| 2 探索 | **幸运**（3） | 幸运 +1 / +2 / +3（`luck_bonus`） | 细搜 | 400 / 800 / 1300 + 建材 |
| 2 探索 | **讨价**（2） | 商店九五折 / 九折（`shop_price_mult`） | 细搜 | 500 / 1000 |
| 2 探索 | **侦察**（1） | 隐形的猎手在一定距离内可见（`scout_range`） | 幸运、讨价 | 1500 + 建材 |

每个 `tech_run_buff` 的每一级一份 `RunBuffDef`（`data/authoring/run_buffs/tech_<id>_<k>.json`，`scope: META`，`description` 用占位符），约二十份小文件；它们会出现在基地右栏的开发开关里（因为 `is_meta()`），那一栏加个「科技给的」分组标题就好（待定 5）。

建材沿用 110 的三种（`supply`），数量照 110 的梯度。

## 六、改动点

| 层 | 改 |
|---|---|
| `core/meta` | `TechDef` 三个字段；`TechEffect` 两个子类 + 注册表两行；`MetaState.tech_buffs / safe_bonus`（含 to_dict / from_dict，默认值不升版本）；`TechService.prereqs_met / missing_prereqs / depth_of`，`ready` 加前置 |
| `core/run` | `GameFlow`：开局合并 `tech_buffs`、`safe_size()` 加 `safe_bonus` |
| 导入器 | 前置存在 / 无环 / 撞位；`tech_run_buff` 的 buff 数与 scope |
| `ui/game` | `tech_tree_view.gd`（新）；`tech_panel.gd` 重做成左树右板 + 底部上交区 / 折叠仓库；基地右栏开关加分组标题 |
| 内容 | 9 份新 `techs/*.json`、`warehouse.json` 加 `column: 0`、约二十份 `run_buffs/tech_*.json` |
| 测试 | `tests/meta/test_tech_tree.gd`：深度计算、成环报错、前置不满足 `ready` 为假、升级后 `tech_buffs` 替换上一级、开局 `RunContext` 读到科技加成、`safe_size` 加成、读档 `heal` 修 `tech_buffs` 与 `safe_bonus`；`tests/ui/test_tech_panel.gd`（110 的）改：选中节点后上交只记给它、锁住节点按钮灰、面板三区文字 |
| 文档 | 架构文档 8.2 那段改「科技树」，版本记录一条；`docs/status.md` 科技一行 |

## 七、待定（按推荐即执行）

| # | 事 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 前置「满足」的定义 | 至少 1 级 / 满级 | **至少 1 级**（满级才开下一个，六级仓库会把后勤列堵死） |
| 2 | 树的位置 | 作者写列、深度按前置算 / 坐标全手写 | **列手写、深度算**（加节点不用挪别人） |
| 3 | 多级科技在树上 | 一个节点写 Lv / 每级一个节点 | **一个节点**（六级仓库拆六格太长） |
| 4 | 首批内容 | 三列十个节点（占位数值） / 只做框架 + 仓库扩建一个节点 | **三列十个**（树只有一个节点看不出是树；数值作者改 JSON） |
| 5 | 基地右栏的局外 buff 开关 | 留作开发工具、加「科技给的」分组 / 删掉 | **留 + 分组**（测数值时直接开关很方便） |
