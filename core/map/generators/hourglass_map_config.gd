## 沙漏形（8-2，报告 078）：上下两块对称的长方形，中间收紧成几条**平行线段**（默认两条）。
## 出生在下面那块的底层，终点在上面那块的顶层正中；线段是必经的咽喉。
## 数值全是占位，结构才要紧：每半几层、几列、颈部几层几条线，都是这里的字段。
class_name HourglassMapConfig
extends Resource

@export_group("形状")
## 每半边几列
@export var width: int = 5
## 每半边几层
@export var half_rows: int = 3
## 颈部几层（平行线段的长度）
@export var neck_rows: int = 2
## 几条平行线段
@export var neck_lanes: int = 2
## 线段落在哪几列。空 = 在宽度里匀着放（两条 → 对称的两列）
@export var neck_cols: Array[int] = []
## 半边的每层填几成格子（第 0 层、最后一层、颈部全填）
@export var fill: float = 0.75
@export var entry_count: int = 2

@export_group("边")
## 层与层之间的路最多斜几列
@export var forward_reach: int = 1
## 同层隔几个空格还连
@export var lateral_span: int = 1
@export var forward_break_chance: float = 0.3
@export var lateral_break_chance: float = 0.35

@export_group("分档")
## 侵蚀从终点那头开始（默认从出生那头）
@export var erosion_reversed: bool = false
## 每层的危险等级（空 = 全 0；短了按最后一项）
@export var danger_by_row: Array[int] = []

@export_group("类型")
@export var rules: LatticeTypeRules = null


func row_count() -> int:
	return half_rows * 2 + neck_rows


## 线段的列：给了就用给的，没给在宽度里匀着放
func lane_cols() -> Array[int]:
	if not neck_cols.is_empty():
		var out: Array[int] = []
		out.assign(neck_cols)
		return out
	var out2: Array[int] = []
	for i in maxi(1, neck_lanes):
		out2.append(clampi(roundi(float(i + 1) * float(width - 1) / float(neck_lanes + 1)), 0, width - 1))
	return out2


## 颈部两头那两层：中途撤离点默认落在这里（咽喉前后各一个出口）
func default_extract_rows() -> Array[int]:
	return [half_rows - 1, half_rows + neck_rows] as Array[int]


static func sample() -> HourglassMapConfig:
	var cfg := HourglassMapConfig.new()
	cfg.rules = LatticeTypeRules.new()
	cfg.rules.extract_rows = cfg.default_extract_rows()
	cfg.rules.extract_count = Vector2i(1, 2)
	cfg.rules.extract_min_distance = 3
	return cfg
