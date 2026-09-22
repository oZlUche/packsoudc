## 同心环布局：第 r 环画在第 r 圈上，槽位按角度均分。
##
## [b]这是最朴素的一版[/b]：角度 = 槽位 / 槽位数。相邻两环槽位数不同，
## 所以径向边并不严格垂直于切线 —— 那要靠调整每个点的角度去解（5.9），是 M3-6 的事。
## 编辑器要的只是「看得清、点得准」，这一版够用。
class_name RingMapLayout
extends MapLayout

const MARGIN := 60.0
## 相邻两环之间隔多远（像素）。**固定的**：不管几环，环与环之间就是这么宽 ——
## 六环的图画布就比四环大一圈，而不是六环挤在四环的地方
const RING_STEP := 110.0


func canvas_size(graph: MapGraph) -> Vector2:
	var side := 2.0 * (float(ring_count_of(graph)) * RING_STEP + MARGIN)
	return Vector2(side, side)


static func ring_count_of(graph: MapGraph) -> int:
	return int(graph.layout_meta.get("ring_count", 0))


## 第 r 环的槽位数。JSON 读回来的字典键是字符串，两种都认。
static func slots_of(graph: MapGraph, r: int) -> int:
	var table: Dictionary = graph.layout_meta.get("ring_slots", {})
	return int(table.get(r, table.get(str(r), 0)))


func positions(graph: MapGraph, rect: Rect2) -> Dictionary:
	var out := {}
	for id in graph.node_ids():
		var lay := graph.get_node(id).layout
		out[id] = _slot_pos(graph, rect, int(lay.get("ring", 0)), int(lay.get("order", 0)))
	return out


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
		for slot in slots_of(graph, r):
			if taken.has("%d:%d" % [r, slot]):
				continue
			out.append({
				"pos": _slot_pos(graph, rect, r, slot),
				"layout": {"ring": r, "order": slot, "kind": kinds.get(r, "")},
				"tier": count - r,
				"erosion_band": count - r,
			})
	return out


func edge_kind(graph: MapGraph, a: int, b: int) -> StringName:
	var ra := int(graph.get_node(a).layout.get("ring", 0))
	var rb := int(graph.get_node(b).layout.get("ring", 0))
	return &"tangential" if ra == rb else &"radial"


func draw_backdrop(canvas: CanvasItem, graph: MapGraph, rect: Rect2) -> void:
	var count := ring_count_of(graph)
	for r in range(1, count + 1):
		canvas.draw_arc(rect.get_center(), _radius(rect, count, r), 0.0, TAU, 96,
			UiPalette.LINE, 1.0, true)


func _slot_pos(graph: MapGraph, rect: Rect2, r: int, slot: int) -> Vector2:
	if r <= 0:
		return rect.get_center()
	var slots := maxi(1, slots_of(graph, r))
	var angle := TAU * float(slot) / float(slots) - PI / 2.0
	return rect.get_center() + Vector2.from_angle(angle) * _radius(rect, ring_count_of(graph), r)


static func _radius(_rect: Rect2, _count: int, r: int) -> float:
	return RING_STEP * float(r)
