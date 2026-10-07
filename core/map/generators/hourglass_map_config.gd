## 沙漏形（8-2，报告 078；作者第二轮定义）：**横置**，像蝴蝶结 —— 左右两块对称的长方形，中间收紧成几条平行线段（默认两条）。
## 出生在左边那块的最左一列，**撤离点在对侧（最右一列）**，核心（BOSS）不是必须的（默认没有）；中途没有撤离点。
## 数值全是占位，结构才要紧：每半几层几列、颈部几层几条线、对侧几个撤离点，都是这里的字段。
## 「层」在数据里还是 row（离出生那一侧几步），画的时候横着排。
class_name HourglassMapConfig
extends Resource

@export_group("形状")
## 每半边几格宽（横置之后是竖着的那个方向）
@export var width: int = 5
## 每半边几层（从出生那侧往对侧数）
@export var half_rows: int = 3
## 颈部几层（平行线段的长度）
@export var neck_rows: int = 2
## 几条平行线段
@export var neck_lanes: int = 2
## 线段落在哪几格。空 = 在宽度里匀着放（两条 → 对称的两格）
@export var neck_cols: Array[int] = []
## 半边的每层填几成格子（第 0 层、最后一层、颈部及其两头全填）
@export var fill: float = 0.75
@export var entry_count: int = 2

@export_group("对侧")
## 对侧那一列放几个撤离点（匀着放）。这张图的终点就是它们
@export var exit_count: int = 2
## 对侧正中放一个核心（BOSS）。不是必须的，默认没有；放了它会顶掉撞在正中的那个撤离点
@export var with_core: bool = false

@export_group("边")
## 层与层之间的路最多斜几格
@export var forward_reach: int = 1
## 同层隔几个空格还连
@export var lateral_span: int = 1
@export var forward_break_chance: float = 0.3
@export var lateral_break_chance: float = 0.35

@export_group("分档")
## 侵蚀从对侧开始（默认从出生那侧）
@export var erosion_reversed: bool = false
## 每层的危险等级（空 = 全 0；短了按最后一项）
@export var danger_by_row: Array[int] = []

@export_group("类型")
## 类型规则。中途撤离点默认没有（extract_rows 空）：撤离点都在对侧
@export var rules: LatticeTypeRules = null


func row_count() -> int:
	return half_rows * 2 + neck_rows


## 线段的格：给了就用给的，没给在宽度里匀着放
func lane_cols() -> Array[int]:
	if not neck_cols.is_empty():
		var out: Array[int] = []
		out.assign(neck_cols)
		return out
	return _spread(maxi(1, neck_lanes), 1)


## 对侧撤离点的格：在宽度里匀着放
func exit_cols() -> Array[int]:
	return _spread(maxi(1, exit_count), 0)


## 在 0～width-1 里匀着放 n 个。margin = 1 时两端各空一格（线段不贴边）
func _spread(n: int, margin: int) -> Array[int]:
	var out: Array[int] = []
	if n == 1:
		out.append((width - 1) / 2)
		return out
	var lo := margin
	var hi := width - 1 - margin
	if hi < lo:
		lo = 0
		hi = width - 1
	for i in n:
		var c := clampi(roundi(float(lo) + float(i) * float(hi - lo) / float(n - 1)), 0, width - 1)
		if not out.has(c):
			out.append(c)
	return out


static func sample() -> HourglassMapConfig:
	var cfg := HourglassMapConfig.new()
	cfg.rules = LatticeTypeRules.new()
	cfg.rules.extract_rows = [] as Array[int]     # 撤离点都在对侧
	cfg.rules.extract_count = Vector2i(0, 0)
	cfg.rules.extract_min_distance = 3
	return cfg
