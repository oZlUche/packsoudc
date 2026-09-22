## 地图规模模板（架构文档 5.4.3）：一种规模的图**最多能要什么**。
##
## 出发点数量、高危区数量、高危区规模都可以由作者或玩家挑，但各有上限，上限随规模变。
## 这些上限放在数据里：加一种规模是加一条记录，不是改生成器。
class_name MapScaleProfile
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

## 这种规模覆盖的环数 [min, max]
@export var rings: Vector2i = Vector2i(4, 5)
## 出发点数量 [min, max]
@export var entries: Vector2i = Vector2i(2, 3)
## 高危区数量 [min, max]。min 是必须有的，多出来的长不出来就算了
@export var zones: Vector2i = Vector2i(1, 1)
## 每条路线上最多岔出几片高危区
@export var zones_per_route: int = 1
## 高危区软上限（长到几个点就停）的可选范围 [min, max]。不指定时用 max
@export var zone_size: Vector2i = Vector2i(3, 4)
## 相邻路线之间换乘几次 [min, max]。图越大换乘机会越多
@export var pivots: Vector2i = Vector2i(1, 1)
## 整张图的节点数（含核心）[min, max]。建环时按它缩放每环的槽位数 ——
## 环数定了之后按半径算出来的密度对中型图太密（6 环 64 个点），作者要 45～50
@export var nodes: Vector2i = Vector2i(0, 0)
## 撤离点两两之间的最短路至少几步。挨得太近的两个出口等于一个
@export var extract_gap: int = 4
## true = 数值还没定，只是占个位。界面上会标出来
@export var placeholder: bool = false


func covers(ring_count: int) -> bool:
	return ring_count >= rings.x and ring_count <= rings.y


static func make(
	id_: StringName, name_: String, rings_: Vector2i, entries_: Vector2i,
	zones_: Vector2i, zone_size_: Vector2i, pivots_: Vector2i,
	nodes_: Vector2i, extract_gap_: int, placeholder_: bool = false
) -> MapScaleProfile:
	var p := MapScaleProfile.new()
	p.id = id_
	p.display_name = name_
	p.rings = rings_
	p.entries = entries_
	p.zones = zones_
	p.zone_size = zone_size_
	p.pivots = pivots_
	p.nodes = nodes_
	p.extract_gap = extract_gap_
	p.placeholder = placeholder_
	return p


## 开箱的三档。小、中是作者给的；大图「出发点也不同，具体留空」—— 先占位。
static func defaults() -> Array[MapScaleProfile]:
	return [
		make(&"small", "小型（4~5 环）", Vector2i(4, 5), Vector2i(2, 3), Vector2i(1, 1), Vector2i(3, 4), Vector2i(1, 1),
			Vector2i(28, 38), 4),
		make(&"medium", "中型（6~8 环）", Vector2i(6, 8), Vector2i(3, 4), Vector2i(1, 3), Vector2i(3, 6), Vector2i(1, 2),
			Vector2i(45, 50), 4),
		# 12 环 × 最少 6 个槽位就是 72 个点，节点数的下限不能比这低；
		# 出发点 × 间隔也得放得进最外环（大图最外环也就十来个槽位）
		# 出发点先占 3：12 环的图最外环 38 个槽位只放 9 个点，4 条路线挤不开
		make(&"large", "大型（占位）", Vector2i(9, 12), Vector2i(3, 3), Vector2i(1, 4), Vector2i(3, 9), Vector2i(2, 3),
			Vector2i(72, 90), 5, true),
	] as Array[MapScaleProfile]
