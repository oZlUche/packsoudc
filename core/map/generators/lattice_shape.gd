## 一种格阵形态的描述（第 8 阶段 8-2，报告 078）：几层、每层哪些格子能放点、哪几层是「只许直上」的平行线段。
##
## 沙漏（[HourglassMapGenerator]）与塔（[TowerMapGenerator]）都是**分层的格阵**：从出生的那一层一层层走向终点那一层，
## 每层若干格。它们的差别只在形状 —— 每层有哪些格、哪几层不许横着走。所以形状单独描述，铺点、连边、断边、
## 定类型、校验都在 [LatticeMapGenerator] 里只写一遍。**本类不是内容**：它由配置算出来，不进管线。
class_name LatticeShape
extends RefCounted

## 写进图的 layout_kind（= 生成器 id，编辑器靠它找校验者与布局）
var kind: StringName = &""
## 总列数（最宽的那一层）。格子的 col 都是这个坐标系里的绝对列，布局按它画
var cols: int = 0
## 每层一条：{"cols": Array[int] 能放点的列, "lateral": bool 同层能不能连, "straight": bool 只许直上直下, "fill": float 填几成}
var rows: Array[Dictionary] = []
## 终点在最后一层的哪一列
var goal_col: int = 0
var entry_count: int = 1
## 层与层之间的边最多斜几列
var forward_reach: int = 1
## 同层隔几个空格还连
var lateral_span: int = 1
var forward_break_chance: float = 0.3
var lateral_break_chance: float = 0.35
## 层与层之间的路只许向上走（塔的「不回头」）。从第几层起单向
var one_way: bool = false
var one_way_from_row: int = 0
## 侵蚀从终点那头开始（默认从出生那头）
var erosion_reversed: bool = false
## 每层的危险等级（空 = 全 0；短了按最后一项）
var danger_by_row: Array[int] = []
var rules: LatticeTypeRules = null


func add_row(p_cols: Array[int], lateral: bool = true, straight: bool = false, fill: float = 1.0) -> void:
	rows.append({"cols": p_cols, "lateral": lateral, "straight": straight, "fill": fill})


func row_count() -> int:
	return rows.size()


func is_straight(r: int) -> bool:
	return r >= 0 and r < rows.size() and bool(rows[r]["straight"])


func allows_lateral(r: int) -> bool:
	return r >= 0 and r < rows.size() and bool(rows[r]["lateral"])


func danger_of(r: int) -> int:
	if danger_by_row.is_empty():
		return 0
	return int(danger_by_row[mini(r, danger_by_row.size() - 1)])


## 一句话说明形状对不对。空串 = 对
func problem() -> String:
	if kind == &"":
		return "没有 kind"
	if rows.size() < 2:
		return "至少两层"
	for r in rows.size():
		if (rows[r]["cols"] as Array).is_empty():
			return "第 %d 层一个格子都没有" % r
	if not (rows[rows.size() - 1]["cols"] as Array).has(goal_col):
		return "终点的列 %d 不在最后一层的格子里" % goal_col
	if entry_count < 1 or entry_count > (rows[0]["cols"] as Array).size():
		return "出生点数 %d 放不进第 0 层的 %d 个格子" % [entry_count, (rows[0]["cols"] as Array).size()]
	if forward_reach < 0 or lateral_span < 0:
		return "reach / span 不能是负的"
	return ""
