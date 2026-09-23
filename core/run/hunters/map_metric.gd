## 猎手用的距离度量（069 第七节第 1 条：作者要按绝对距离算，数字全不写死）。
##
## 两种：`steps` = 图上的步数（core 自带，BFS）；`absolute` = 布局坐标的直线距离，单位是「一环的间距」——
## 坐标由持有方注入（地图屏从 MapView 的坐标算出来除以环距），core 不认识布局。没注入坐标时退回步数。
## 感知距离、开打距离、领地半径、生成距离都用它比，所以一份猎手配置换度量不用改数（步数与环距同量级）。
class_name MapMetric
extends RefCounted

const STEPS := &"steps"
const ABSOLUTE := &"absolute"

var mode: StringName = STEPS
## 节点 id → 归一化坐标（absolute 用）
var positions: Dictionary = {}
var _graph: MapGraph = null
var _cache: Dictionary = {}     # from id → distance_map


func _init(p_graph: MapGraph = null, p_mode: StringName = STEPS) -> void:
	_graph = p_graph
	mode = p_mode


func set_positions(p: Dictionary) -> void:
	positions = p


func distance(a: int, b: int) -> float:
	if a == b:
		return 0.0
	if mode == ABSOLUTE and positions.has(a) and positions.has(b):
		return (Vector2(positions[a]) - Vector2(positions[b])).length()
	return float(steps(a, b))


## 图上的步数；到不了 = 一个很大的数
func steps(a: int, b: int) -> int:
	if _graph == null:
		return 1 << 20
	if not _cache.has(a):
		_cache[a] = MapNavigator.distance_map(_graph, a)
	var d: Dictionary = _cache[a]
	return int(d[b]) if d.has(b) else (1 << 20)


func invalidate() -> void:
	_cache.clear()
