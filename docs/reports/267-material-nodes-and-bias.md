# 方案：材料定向实施篇 —— B 环产物表 + C 材料节点四种 + A 出征页倾向（267）

> 266 讨论稿作者 2026-10-29 16:49 认可推荐：B + C + A 一单、四种节点、倾向按三系。本篇是实施规格，直接派执行；图标走美术设计出样、作者看一眼。

## 〇 一句话

搜索 / 宝箱 / 事件掷道具时，权重多乘两层：**这一点所在的环的产物表**（B）和**这一局的出征倾向**（A）；每环再把 1～2 个搜索点改成**材料节点**（矿脉 / 林地 / 遗骸 / 符文堆），只出那一类材料、地图上有自己的图标（C）。节点总数、259 的权重、校验规则一个不动。

## 一、材料怎么分类

现有标签够用三系（`nature` / `crafted` / `magic`），但分不出「矿」和「木」—— 铁矿石、橡木、蜂蜡都是 `nature`。加两个标签（`data/authoring/tags/`，中英名照 250 的格式）：

| 新标签 | 名 | 贴在（现有 76 种材料里） |
|---|---|---|
| `mineral` | 【矿物】Mineral | copper_ore、iron_ore、silver_ore、flint、raw_salt、gravestone_shard、gold_nugget、silver_nugget（金银块已是 bullion，再贴一枚） |
| `plant` | 【草木】Plant | oak_log、wooden_stick、ironwood_branch、pine_resin、beeswax、honey_jar、dried_herbs、mint_bundle、datura_flower |

`beast_part`【兽部件】、`crystal`【魔晶】、`crafted`【工艺】已有。以后新材料贴对标签就自动进对的节点 —— 这正是作者问的「材料越来越多之后」。

四种材料节点 → 标签：

| 节点 | id | 只出带这些标签的 | 图标（美术设计出样） | 节点色（搜索黄的四个变体） |
|---|---|---|---|---|
| 矿脉 | `mine` | `mineral`、`bullion` | 镐 + 矿石 | 赭 `c48a3a` |
| 林地 | `grove` | `plant`、`beast_part` | 树 + 兽牙 | 橄榄 `9aa63c` |
| 遗骸 | `remains` | `crafted`（material / supply 那些；武器防具不算，见 2.3） | 倒塌的柱 + 陶罐 | 灰褐 `a8906a` |
| 符文堆 | `runes` | `crystal`、`magic` | 符文石 | 紫金 `b58ad0` |

## 二、三层权重（B、A、C）

### 2.1 `SearchSession.draw_items` 多一个参数

`draw_items(rules, items, depth, danger, rng, rarity_cap, floor, produce: Dictionary = {}, bias: Dictionary = {}, only_tags: Array = [])`：

- 每个候选的权重 = `rarity_weight(...)` × **`produce` 命中的最大倍率**（命中多个标签取最大，不连乘）× **`bias` 命中的倍率**；
- `only_tags` 非空 = 候选先过滤成「带任一 only 标签、且是材料类（`material` / `crystal` / `reagent` / `bullion` 任一）」，这是 C；过滤后为空就退回全池（别让节点空手）。
- 三个调用处（搜索 `node_events` 903 / 1030、事件 `_event` 1124、`give_random_item`）与宝箱（`ChestPlacer` / 开箱那条）都传 `_produce_of(node)`、`run.bias_table()`、`_only_of(node)`；`give_random_item` 没节点就空字典。

### 2.2 B：环的产物表

`RingSpec.produce: Dictionary`（标签 → 倍率），写进 `free_mode.json` 的 rings：

| 环 | produce |
|---|---|
| outskirts | `{"plant": 2.0, "beast_part": 1.5, "mineral": 1.2}` |
| ruins | `{"crafted": 2.0, "mineral": 1.5}` |
| depths / core_ring / inner | `{"crystal": 2.0, "magic": 2.0, "mineral": 1.2}` |

生成时 `RingTypeAssigner` 把所在环的 `produce` 写进 `MapNode.produce`（**新字段**，`to_dict` / `from_dict` 带上；老存档没有 = 空字典 = 不加权）。高危区不另加表（`danger_gain` 已把稀有度往上推）。手绘图（`data/maps/*.json`）没写就是空。

### 2.3 C：材料节点

- `RingSpec.material_nodes: Dictionary`（kind → 个数）：outskirts `{"grove": 1, "mine": 1}`、ruins `{"remains": 1, "mine": 1}`、depths `{"runes": 1}`、core_ring / inner `{"runes": 1}`（小图 slots 少的环按实际搜索点数封顶）。
- `NodeRules.search_kinds: Dictionary`（kind → `{tags, other_share}`），`node_rules/standard.json`：四条如 §一，`other_share` 0.25 = 每次掷有四分之一从普通池抽（免得三件全是矿石太死板；作者要纯的就改 0）。`remains` 的 tags 只写 `crafted`，再靠 2.1 的「材料类」过滤把武器防具挡在外面。
- 分配：`_assign_by_weights` 与 `_enforce_quota` 之后、`_enforce_coverage` 之前加 `_assign_material_kinds()`：每环在**已是 `search`、不在 `_fixed`、不是喘气处**的节点里随机挑 `material_nodes` 要的个数，`node.content["search_kind"] = kind`；节点类型仍是 `search`（259 的 no_adjacent、配额、路线校准都不用改），只是搜的池不同。挑不够就有几个算几个。随机点揭成搜索（`effective_type`）不带 kind。
- `SearchSession`：`only_tags` 从 `node.content.search_kind` 查 `search_kinds`；`other_share` 在 `draw_items` 里按件掷。
- 校验不加条（kind 是内容不是拓扑）。

### 2.4 A：出征倾向

- `RunState.material_bias: StringName`（`&""` / `nature` / `crafted` / `magic`），存档；`bias_table()` → 选中的系 `{tag: 2.5}`，另两系 `{tag: 0.6}`（只碰这三个标签；非材料道具不受影响）。
- 出征页（264）「军需」木牌下面加一块**「倾向」木牌** 560 × 90：四颗 120 × 56 木牌键 无 / 自然 / 工艺 / 魔法（toggle，选中的按下），悬浮窗写「这一系材料出得更多（×2.5），另两系少一些（×0.6）」；选的存 `MetaState.flag("last_bias")`，开局时写进 `RunState`。开局屏不加东西。
- 地图：左下图例（`legend_widget`）顶上一行「倾向：自然」（没选不显示）。

## 三、地图上看得见

- **节点图标**：`MapNodeStyle.of(type, kind)` —— 搜索点带 kind 时用 `assets/nodes/search_<kind>.png` 与 §一的色；缺图退回画字 矿 / 林 / 遗 / 符。`MapView._draw_node` 改传 `n.content.get("search_kind")`。
- **图例**：`legend_widget.types()` 把四种 kind 当成独立行（图上有才列），短名 矿脉 / 林地 / 遗骸 / 符文堆（`NodeText` 加四条）。
- **悬浮句**：`node.hint.search_mine` 等四条（「这里的矿脉还没挖净，翻出来的多半是矿石和金属。」…），再加一句产物句 `node.hint.produce`「这一带多翻出【%s】」（按 `MapNode.produce` 里倍率最高的标签名，倍率 > 1 才说），拼在搜索 / 宝箱点的悬浮句后面。
- **搜索屏**：标题牌照旧「搜索」，副题（226 的段头签）写节点种类名。
- 图例多一段「产物」：外 / 中 / 内三行各写 produce 里 ≥ 1.5 的标签名（文字，不要新图）。

## 四、改动清单（执行）

1. 标签 `mineral`、`plant` + 17 种材料贴标签（§一）；`check_content` 过。
2. `SearchSession.draw_items` 三个新参数（2.1）；四个调用处 + 宝箱传参；`SearchSession` 读 kind。
3. `RingSpec.produce` / `material_nodes`；`MapNode.produce` 存读；`RingTypeAssigner._assign_material_kinds`；`free_mode.json` 数据；`NodeRules.search_kinds` + `standard.json`（prologue 不加，教程不要）。
4. `RunState.material_bias` + 存读 + `bias_table()`；出征页「倾向」木牌（264 那单一起做）；`MetaState.flag last_bias`。
5. `MapNodeStyle` kind 分支、`MapView`、`legend_widget`（kind 行 + 倾向行 + 产物段）、`NodeText` 四名、悬浮句五条中英、搜索屏副题。
6. `tools/map_stats`：每图材料节点数、按 kind；96 种子跑一遍附在落地记录。
7. 图标四枚 `assets/nodes/search_<kind>.png`（白线稿，同 155 规格）：美术设计 A（题材两样东西）/ B（一枚一个场景），**作者 16:59 选 B**（矿洞口 / 两棵松 / 断柱 + 倒柱头 / 三块立石），定稿 `art/nodes/v267/out/`（64 + @2x 128）已交执行。

## 五、测试

- `test_draw_items_267`：produce 倍率取最大不连乘；bias 三系对 / 非材料不变；only_tags 过滤 + 空池退回；other_share 0 时全是该类。
- `test_ring_assigner_267`：96 种子每环材料节点数 = 配置（搜索点够时）；节点类型仍 search；259 的统计（搜索数、休息数、相邻）不变。
- `test_map_node_267`：produce / search_kind 存读；老存档缺字段 = 空。
- `test_run_state_267`：bias 存读；出征页四键切换写 flag；开局带进 RunState。
- `test_legend_267`：有矿脉的图列「矿脉」行、倾向行；悬浮句含产物句。
- 截图：地图（四种节点都在的种子）、图例、出征页倾向牌，中英，交 游戏测试（新）。

## 六、待定（没回音按推荐）

1. `other_share`：**0.25**（推荐）/ 0（纯）。
2. 倾向倍率：**×2.5 / ×0.6**（推荐）/ 更猛 ×4 / ×0.4。
3. 教程章节：**不加**（推荐）/ 加。

## 七、落地记录（2026-10-29，执行 v4.76，PR #381，main 1927531）

全套 34543 项通过。待定三条都按推荐：`other_share` 0.25、倾向 ×2.5 / ×0.6、序章不加材料节点。

与本文的三处偏差，都收下：

1. **金银块不贴【矿物】**。244 补充一 的测试只许金银块带「贵重品」「金银」两枚标签，且金银本来就不从搜索点出；矿脉的 `bullion` 标签照留。于是新标签覆盖 **矿物 6 种 + 草木 9 种 = 15 种**（§一表里 `mineral` 行少 gold_nugget / silver_nugget 两项）。
2. **材料节点分配放在所有改类型步骤之后**（不是 §四.4 写的 quota 后、coverage 前），随机数另派生一条流。好处：同种子的地图与节点类型，和没有材料节点时逐点相同，259 的节点统计一字不变。
3. **`RingMapConfig._build_rings` 换规模重建环时按环种类带上 `produce` / `material_nodes`**，不然开局页选了规模就把表丢了。

另两处实现细节：产物倍率对所有道具生效（§二 B 原文如此）；倾向只碰材料类（§二 A）。

96 种子统计（`/mnt/project-files/art/nodes/v267/landed/map_stats_96seeds.txt`，休息与休息—休息边与 259 落地值相同）：

| 规模 | 搜索点 / 张 | 材料节点 / 张 | 林地 | 矿脉 | 遗骸 | 符文堆 |
|---|---|---|---|---|---|---|
| small 4 环 | 5.02 | 3.57 | 0.69 | 1.25 | 0.71 | 0.93 |
| small 5 环 | 8.06 | 5.09 | 0.83 | 1.81 | 0.84 | 1.60 |
| medium 6 环 | 10.57 | 5.68 | 0.73 | 1.59 | 0.89 | 2.47 |

内环搜索点本来就少，材料节点「挑不够有几个算几个」，所以 medium 的符文堆是 2.47 而非配额 3。截图（中英出征页、地图、悬浮句、矿脉搜索屏）同目录。同 PR 顺带：265 复测两处字、集市底图换柱脚埋土版。

**复测小修（v4.78，PR #383）**：材料节点的悬浮句不再接环的产物句 —— 外环矿脉原来会读成「多半是矿石……这一带多翻出【草木】」，与 §三「拼在搜索 / 宝箱点后面」略有出入，只对材料节点跳过，普通搜索 / 宝箱点照拼；英文图例「Mid」。另记一条未改：测试与 UI 线都提到家里木牌小键按下样式对比度低（倾向键与后勤子键共用一套），等作者定。
