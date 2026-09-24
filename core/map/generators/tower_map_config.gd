## 塔形（8-2，报告 078；作者第二轮定义）：等腰三角形，底层最宽、一层层向上收窄到塔尖；出生在底层，终点在塔尖。
## **横向的层，登上一层就不能向下**：同层可以自由横着走，层与层之间的路只许向上（作者定的塔的规则，默认开着；
## `one_way` 关掉就是一座能上下的塔）。数值全是占位。
class_name TowerMapConfig
extends Resource

@export_group("形状")
## 底层几列
@export var base_width: int = 7
## 每上一层，两边各收几列（等腰：每层窄 2 × 它）
@export var shrink_per_row: int = 1
## 几层。0 = 收窄到 1 列为止
@export var floors: int = 0
## 每层填几成格子（底层、塔尖全填）
@export var fill: float = 0.8
@export var entry_count: int = 2

@export_group("边")
@export var forward_reach: int = 1
@export var lateral_span: int = 1
@export var forward_break_chance: float = 0.3
@export var lateral_break_chance: float = 0.35

@export_group("不回头")
## 登上一层就不能向下：层与层之间的路只许向上走，同层照旧自由横着走。塔的定义，默认开着
@export var one_way: bool = true
## 从第几层起单向（0 = 出生那层）
@export var one_way_from_floor: int = 0

@export_group("分档")
@export var erosion_reversed: bool = false
@export var danger_by_row: Array[int] = []

@export_group("类型")
@export var rules: LatticeTypeRules = null


## 每层的宽度，底层在前
func widths() -> Array[int]:
	var out: Array[int] = []
	var w := base_width
	var count := 0
	while w >= 1 and (floors <= 0 or count < floors):
		out.append(w)
		count += 1
		w -= 2 * maxi(0, shrink_per_row)
		if shrink_per_row <= 0 and floors <= 0:
			break     # 不收窄又不限层数：只一层，形状说不通，交给 problem() 报
	while floors > 0 and out.size() < floors:
		out.append(1)
	return out


func row_count() -> int:
	return widths().size()


## 中途撤离点默认落在正中那一层
func default_extract_rows() -> Array[int]:
	return [row_count() / 2] as Array[int]


static func sample() -> TowerMapConfig:
	var cfg := TowerMapConfig.new()
	cfg.rules = LatticeTypeRules.new()
	cfg.rules.extract_rows = cfg.default_extract_rows()
	cfg.rules.extract_count = Vector2i(1, 1)
	cfg.rules.extract_min_distance = 3
	return cfg
