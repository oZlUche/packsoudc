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
## 215：每半边从外层往颈部每层收几格（居中、两半对称；收到线段的跨度为止）。0 = 每层满宽
@export var taper: int = 0
@export var entry_count: int = 2

@export_group("对侧")
## 对侧那一列放几个撤离点（匀着放）。这张图的终点就是它们
@export var exit_count: int = 2
## 对侧正中放一个核心（BOSS）。不是必须的，默认没有；放了它会顶掉撞在正中的那个撤离点
@export var with_core: bool = false

## 281 §六（作者 2026-11-05 12:36）：一左一右各一个出生点（玩家挑），撤离点在所挑那一头的对侧；tier 与危险两头浅、中间深
@export var two_sided: bool = false
## 281 §六：核心放在颈部正中（中轴，挂在线段上），不在对侧
@export var axis_core: bool = false
## 281 §六：中轴上核心下方另加一个钟房（事件点，只从下面那条线段进，和核心不相连）
@export var clock_room: bool = false
const CLOCK_ROOM_EVENT := &"event_clock_room"

@export_group("规模")
## 281 §六：三档规模（小 / 中 / 大）。空 = 只有配置本身这一档
@export var scales: Array[HourglassScale] = []

@export_group("边")
## 层与层之间的路最多斜几格
@export var forward_reach: int = 1
## 同层隔几个空格还连
@export var lateral_span: int = 1
@export var forward_break_chance: float = 0.3
@export var lateral_break_chance: float = 0.35

@export_group("材料")
## 283（267 B / C 搬到沙漏）：两半各自的产物表（标签 → 倍率）与材料节点（种类 → 个数）。两半一样，左右对称
@export var side_produce: Dictionary = {}
@export var side_material_nodes: Dictionary = {}
## 颈部的产物表与材料节点
@export var neck_produce: Dictionary = {}
@export var neck_material_nodes: Dictionary = {}

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


## 283：材料节点一共几个（两半各一份 + 颈部）
func material_node_count() -> int:
	var n := 0
	for k in side_material_nodes:
		n += 2 * int(side_material_nodes[k])
	for k in neck_material_nodes:
		n += int(neck_material_nodes[k])
	return n


## 283：三段（左半、颈部、右半）的层号范围与产物 / 材料节点，交给格阵形状
func segments() -> Array[Dictionary]:
	var last := row_count() - 1
	return [
		{"from": 0, "to": half_rows - 1, "produce": side_produce, "material_nodes": side_material_nodes},
		{"from": half_rows, "to": half_rows + neck_rows - 1, "produce": neck_produce, "material_nodes": neck_material_nodes},
		{"from": last - half_rows + 1, "to": last, "produce": side_produce, "material_nodes": side_material_nodes},
	] as Array[Dictionary]


## 颈部正中那一层（中轴）
func axis_row() -> int:
	@warning_ignore("integer_division")
	return half_rows + neck_rows / 2


## 中轴的列：宽度正中
func axis_col() -> int:
	@warning_ignore("integer_division")
	return (width - 1) / 2


func scale_by_id(id: StringName) -> HourglassScale:
	for p in scales:
		if p != null and p.id == id:
			return p
	return null


## 换一档规模：层数、宽度、覆盖要求按这一档（[param _rings] 是环形配置的参数，这里不用）
func apply_scale(id: StringName, _rings: int = 0) -> void:
	var p := scale_by_id(id)
	if p == null:
		return
	half_rows = p.half_rows
	width = p.width
	if not p.coverage.is_empty() and rules != null:
		rules = rules.duplicate(true)
		for k in p.coverage:
			rules.coverage[k] = p.coverage[k]


## 线段的格：给了就用给的，没给在宽度里匀着放
func lane_cols() -> Array[int]:
	if not neck_cols.is_empty():
		var out: Array[int] = []
		out.assign(neck_cols)
		return out
	return _spread(maxi(1, neck_lanes), 1)


## 215：半边第 k 层（0 = 最外层，half_rows − 1 = 紧挨颈部）的格：宽 max(线段跨度, width − taper × k)，
## 居中偏移 (width − 宽) / 2（和塔一样，偶差偏左）。出口半边对称取
func half_cols(k: int) -> Array[int]:
	var lanes := lane_cols()
	var span: int = (int(lanes.max()) - int(lanes.min()) + 1) if not lanes.is_empty() else 1
	var w := clampi(width - maxi(0, taper) * k, mini(span, width), width)
	@warning_ignore("integer_division")
	var offset := (width - w) / 2
	var out: Array[int] = []
	for x in w:
		out.append(offset + x)
	return out


## 对侧撤离点的格：在宽度里匀着放
func exit_cols() -> Array[int]:
	return _spread(maxi(1, exit_count), 0)


## 在 0～width-1 里匀着放 n 个。margin = 1 时两端各空一格（线段不贴边）
func _spread(n: int, margin: int) -> Array[int]:
	var out: Array[int] = []
	if n == 1:
		@warning_ignore("integer_division")
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
