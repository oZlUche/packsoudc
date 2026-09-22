## 同心环布局：第 r 环画在第 r 圈上，角度由 [RingAngleSolver] 解 ——
## 径向边垂直于切线，切向边是弧。圈上的位置 = 槽位 / 槽位数，只用来定最外环和插值。
class_name RingMapLayout
extends RingLayoutBase


static func ring_count_of(graph: MapGraph) -> int:
	return int(graph.layout_meta.get("ring_count", 0))


## 第 r 环的槽位数。JSON 读回来的字典键是字符串，两种都认。
static func slots_of(graph: MapGraph, r: int) -> int:
	var table: Dictionary = graph.layout_meta.get("ring_slots", {})
	return int(table.get(r, table.get(str(r), 0)))


func level_count(graph: MapGraph) -> int:
	return ring_count_of(graph)


func levels_of(graph: MapGraph) -> Dictionary:
	var out := {}
	for id in graph.node_ids():
		out[id] = int(graph.get_node(id).layout.get("ring", 0))
	return out


func fractions_of(graph: MapGraph) -> Dictionary:
	var out := {}
	for id in graph.node_ids():
		var lay := graph.get_node(id).layout
		var r := int(lay.get("ring", 0))
		out[id] = float(int(lay.get("order", 0))) / float(maxi(1, slots_of(graph, r))) if r > 0 else 0.0
	return out


## 空位画在槽位的名义角度上（求解只管有点的地方）。
func free_slots(graph: MapGraph, rect: Rect2) -> Array[Dictionary]:
	var taken := {}
	var kinds := {}
	for id in graph.node_ids():
		var lay := graph.get_node(id).layout
		taken["%d:%d" % [int(lay.get("ring", 0)), int(lay.get("order", 0))]] = true
		kinds[int(lay.get("ring", 0))] = String(lay.get("kind", ""))
	var count := ring_count_of(graph)
	var out: Array[Dictionary] = []
	for r in range(1, count + 1):
		var slots := maxi(1, slots_of(graph, r))
		for slot in slots:
			if taken.has("%d:%d" % [r, slot]):
				continue
			out.append({
				"pos": polar(rect, r, TAU * float(slot) / float(slots) - PI / 2.0),
				"layout": {"ring": r, "order": slot, "kind": kinds.get(r, "")},
				"tier": count - r,
				"erosion_band": count - r,
			})
	return out
