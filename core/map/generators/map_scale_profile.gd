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
## 环数 → 整张图的节点数（含核心）[min, max]。键是环数（字符串，过 JSON 会变成字符串）。
## **是范围不是定数**：每一局在范围里抽一个总数，各环按配置里的基准比例分。
## 范围对着槽位数定，让填充率落在六到七成：太满没有空白区，太空路线找不到落点
@export var nodes_by_rings: Dictionary = {}
## 撤离点两两之间的最短路至少几步。挨得太近的两个出口等于一个
@export var extract_gap: int = 4
## 撤离环间有几道。1 = 正中间的那一两环（小、中型）；2 = 大型的两道，**还没定，占位**
@export var extract_bands: int = 1
## 喘气处放在路线的几分之几处（0～1，按路线上的步数，不看环）。类型 → 位置。
## 中型：休息区 1/3、商店 2/3；小型两个都在一半，位置撞上就挨着放
@export var haven_at: Dictionary = {"rest": 1.0 / 3.0, "shop": 2.0 / 3.0}
## true = 数值还没定，只是占个位。界面上会标出来
@export var placeholder: bool = false
## 092（作者定）：这个规模的全局倒计时（行动点）—— 倒计时和地图规模正相关，每档自己写；0 = 用章节的 step_limit
@export var step_limit: int = 0
## 094：这个规模的带入预算（价值）；0 = 用章节的 carry_budget
@export var carry_budget: int = 0


func covers(ring_count: int) -> bool:
	return ring_count >= rings.x and ring_count <= rings.y


## 这个环数的图该有几个点 [min, max]（含核心）。没写就是 (0, 0) = 不管
func node_range(ring_count: int) -> Vector2i:
	var lim = nodes_by_rings.get(str(ring_count), nodes_by_rings.get(ring_count, null))
	if lim == null or (lim as Array).size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(lim[0]), int(lim[1]))


static func make(
	id_: StringName, name_: String, rings_: Vector2i, entries_: Vector2i,
	zones_: Vector2i, zone_size_: Vector2i, pivots_: Vector2i,
	nodes_: Dictionary, extract_gap_: int, haven_at_: Dictionary,
	extract_bands_: int = 1, placeholder_: bool = false
) -> MapScaleProfile:
	var p := MapScaleProfile.new()
	p.id = id_
	# 104 第十节：环数只写一处 —— 标签里的「4~5 环」按 rings 拼（占位的不写）
	p.display_name = name_ if placeholder_ else "%s（%d~%d 环）" % [name_, rings_.x, rings_.y]
	p.rings = rings_
	p.entries = entries_
	p.zones = zones_
	p.zone_size = zone_size_
	p.pivots = pivots_
	p.nodes_by_rings = nodes_
	p.extract_gap = extract_gap_
	p.haven_at = haven_at_
	p.extract_bands = extract_bands_
	p.placeholder = placeholder_
	return p


## 开箱的三档。小、中是作者给的；大图「出发点也不同，具体留空」—— 先占位。
## 小型的撤离间距 3：撤离环间离核心前一环（去撤离点的路线在那里收尾）只有一两环，间距 4 把整条环间都排除了
##
## 节点数对着槽位数定（中环加 3 个槽位之后：4 环 40、5 环 53、6 环 75、7 环 94、8 环 122），
## 让填充率落在六到七成。作者给的是 4 环 25～30、5 环 35～40；往上按同样的比例推
static func defaults() -> Array[MapScaleProfile]:
	return [
		make(&"small", "小型", Vector2i(4, 5), Vector2i(2, 3), Vector2i(1, 1), Vector2i(3, 4), Vector2i(1, 1),
			{"4": [25, 30], "5": [35, 40]}, 3, {"rest": 0.5, "shop": 0.5}),
		make(&"medium", "中型", Vector2i(6, 8), Vector2i(3, 4), Vector2i(1, 3), Vector2i(3, 6), Vector2i(1, 2),
			{"6": [45, 50], "7": [58, 66], "8": [74, 84]}, 4, {"rest": 1.0 / 3.0, "shop": 2.0 / 3.0}),
		# 出发点先占 3：12 环的图最外环 38 个槽位只放 9 个点，4 条路线挤不开。
		# 节点数按六成填充推；两道撤离环间还没定
		make(&"large", "大型（占位）", Vector2i(9, 12), Vector2i(3, 3), Vector2i(1, 4), Vector2i(3, 9), Vector2i(2, 3),
			{"9": [86, 100], "10": [105, 122], "11": [124, 144], "12": [149, 174]}, 5,
			{"rest": 1.0 / 3.0, "shop": 2.0 / 3.0}, 2, true),
	] as Array[MapScaleProfile]
