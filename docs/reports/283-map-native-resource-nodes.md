# 283 出征页「倾向」删除，改为每张地图自带自己的自然资源节点（267 A 作废）

> 作者 2026-11-05 12:42（架构设计线程）：「出征界面的倾向删除，改为不同地图自带不同的自然资源节点」。直接指派：待定按推荐派执行。

## 〇 一句话

267 的三层里 **A（出征页选倾向，选中一系 ×2.5、另两系 ×0.6）整层删掉**；材料的「定向」只靠 **C 材料节点**（矿脉 / 林地 / 遗骸 / 符文堆）和 **B 环的产物表**，而且每一章在自己的章节配置里写**自己有哪几种**材料节点、各几个——地图就是倾向。机关沙漏现在一个材料节点都没有，这次补上。

## 一、现状（读码）

- A 的落点：`GameFlow.BIAS_FLAG`（局外旗标 `last_bias`）、`ui/widgets/expedition_board.gd` 的三选（182 / 215 / 221 行）、`RunState.material_bias` + `bias_table()`、`SearchSession.bias_table` / `BIAS_SOURCES`、`EventContext.material_bias`、`give_random_item` 的 bias 参数、`legend_widget.gd` 的「倾向」一行、`hud.bias` 文案、存档字段。
- C / B 的落点：`RingSpec.produce` / `material_nodes`（每环）→ `ring_type_assigner` 把普通搜索点换成材料节点；只有 `RingMapConfig` 有，`HourglassMapConfig`（机关沙漏）没有产物表也没有材料节点。
- 魔法废墟现有配置：外郊 grove 1（plant 2 / beast_part 1.5 / mineral 1.2）；废墟 mine 1 + remains 1（crafted 2 / mineral 1.5）；深处、核环、内环各有自己的表。

## 二、做法

1. **删 A**：上面列的每一处都去掉；`expedition_board` 的三选块删除、布局回收；存档读到 `material_bias` 忽略（旧档兼容，不迁移）。掷物权重 = 稀有度权重 × 产物表命中的最大倍率（× C 的过滤），两层。
2. **地图自带**：材料节点的种类和个数本来就在章节配置的每环里（魔法废墟已是）；补 `HourglassMapConfig` 的 `produce` / `material_nodes`（按**行段**配：左半、颈部、右半各一份，等价于环），机关沙漏填：左右两半 `mine` 1 + `remains` 1（produce crafted 2 / mineral 1.5，机关与铜），颈部 `runes` 1（crystal 2）；不放 grove（机关图没有林地）。以后每章新建时必须写自己的材料节点（校验：**章节配置里材料节点总数 ≥ 2**，否则警告）。
3. **看得见**：出征页第三页的预览和 182 的节点提示已经画材料节点图标（267 §三），玩家选图时就看得到这张图出什么——这就是「地图自带」的全部提示，不另加字。
4. 文案：`hud.bias` 删；帮助页「材料」那段去掉倾向句。

## 三、改动清单（执行）

1. 删 A（§二 1），`tests/` 里 267 A 的用例删、B / C 的保留。
2. `HourglassMapConfig` + 生成器：`produce` / `material_nodes` 按行段；机关沙漏配置按 §二 2 填；`tools/map_stats` 机关沙漏也统计材料节点。
3. 校验：每章材料节点总数 ≥ 2。
4. 复测 96 种子的材料节点数附落地记录。

## 四、待定（没回音按推荐）

| # | 事 | 推荐 |
|---|---|---|
| 1 | 机关沙漏的节点配比 | 两半各 mine 1 + remains 1，颈部 runes 1，不放 grove |
| 2 | 旧档的 `material_bias` | 读到就忽略，不迁移 |
| 3 | 校验下限 | 每章 ≥ 2 个材料节点 |

## 五、落地记录

| 时间 | 事 | 出处 |
|---|---|---|
| 2026-11-05 12:42 | 作者原话见顶部；写成本篇，待定按推荐派执行 | 架构设计线程 |
