## 278（作者 2026-11-04 选 A）：节点图的高危区画成一片地 —— 红晕底 + 暗红虚线界，中危琥珀、淡一档。
##
## 形状全按屏幕像素算（节点按固定屏幕大小画）：区内每点一个圆、每条边一根长条、相邻三点的 Delaunay 三角
## （三角里不能有区外点、最长边不超过中位数 1.9 倍），并起来后外扩 12 内收 12 磨圆，再沿法线抖 ±2.2。
## 挨着的同级区合成一块。纯函数，[MapView] 按 graph.version / 缩放 / 平移 / 尺寸缓存结果，不在每帧合并。
class_name DangerZones
extends RefCounted

const ROUND := 12.0     # 外扩再内收的距离（磨圆）
const WOBBLE := 2.2     # 外缘沿法线抖的幅度
const WOBBLE_STEP := 7.0
const CLEAR := 10.0     # 离区外点至少留「节点半径 + 这么多」
const MIN_PAD := 15.0     # 点圈半径至少「节点半径 + 这么多」
const MIN_KEEP := 8.0     # 被区外点挤到最小也留「节点半径 + 这么多」
const RADIUS_OF_MEDIAN := 0.3
const CAPSULE := 0.85
const TRI_MAX_OF_MEDIAN := 1.9

## A 红晕虚线
const FILL_ALPHA := 0.17
const INNER_INSET := 7.0
const INNER_ALPHA := 0.06
const EDGE_ALPHA := 0.9
const EDGE_WIDTH := 2.6
const DASH := 11.0
const GAP := 6.0
const MID_FACTOR := 0.55     # 中危：不透明度 × 这个
const TINT_HIGH := Color(0.70, 0.18, 0.12)
const EDGE_HIGH := Color(0.55, 0.11, 0.07)
const TINT_MID := Color(0.78, 0.45, 0.12)
const EDGE_MID := Color(0.62, 0.34, 0.06)
const DARK_TINT_LIFT := 0.25     # 深色底图：底色提亮
const DARK_EDGE_LIFT := 0.45     # 深色底图：界线提亮


## 分组：有 graph.zones 就按它分（都算 2 级）；没有就按 danger 找同级相连的点。→ [{ids: Array[int], level: int}]
static func groups(graph: MapGraph) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if graph == null:
		return out
	if not graph.zones.is_empty():
		var zids: Array = graph.zones.keys()
		zids.sort()
		for zid in zids:
			var ids: Array[int] = []
			for id in graph.zones[zid].get("node_ids", []):
				ids.append(int(id))
			if not ids.is_empty():
				out.append({"ids": ids, "level": 2})
		return out
	var seen := {}
	for id in graph.node_ids():
		var lv := graph.get_node(id).danger
		if seen.has(id) or lv < 1:
			continue
		var comp: Array[int] = []
		var stack: Array[int] = [id]
		seen[id] = true
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			comp.append(cur)
			for o in graph.neighbors(cur):
				if not seen.has(o) and graph.get_node(o).danger == lv:
					seen[o] = true
					stack.append(o)
		comp.sort()
		out.append({"ids": comp, "level": mini(lv, 2)})
	return out


## 区内三点之间要填的三角：Delaunay 三角里最长边不超过 [param max_len]、里面没有 [param others] 的点。逆时针
static func triangles(pts: PackedVector2Array, others: PackedVector2Array, max_len: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if pts.size() < 3:
		return out
	var tri := Geometry2D.triangulate_delaunay(pts)
	for t in range(0, tri.size(), 3):
		var a := pts[tri[t]]
		var b := pts[tri[t + 1]]
		var c := pts[tri[t + 2]]
		if maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a))) > max_len:
			continue
		var blocked := false
		for o in others:
			if Geometry2D.point_is_inside_triangle(o, a, b, c):
				blocked = true
				break
		if blocked:
			continue
		var poly := PackedVector2Array([a, b, c])
		out.append(poly if not Geometry2D.is_polygon_clockwise(poly) else PackedVector2Array([a, c, b]))
	return out


## 一片区的零件（圆、长条、三角）。[param sp] = 区内点 id → 屏幕坐标；[param others] = 区外点的屏幕坐标；[param edges] = [[a, b], …]
static func pieces(sp: Dictionary, others: PackedVector2Array, edges: Array, node_r: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if sp.is_empty():
		return out
	var lens: Array[float] = []
	var inner: Array = []
	for e in edges:
		if sp.has(e[0]) and sp.has(e[1]):
			inner.append(e)
			lens.append((sp[e[0]] as Vector2).distance_to(sp[e[1]]))
	lens.sort()
	var base_r := node_r + MIN_PAD
	var med: float = lens[lens.size() >> 1] if not lens.is_empty() else 4.0 * base_r
	var want := maxf(base_r, med * RADIUS_OF_MEDIAN)
	var rad := {}
	for id in sp:
		var p: Vector2 = sp[id]
		var lim := want
		for o in others:
			lim = minf(lim, o.distance_to(p) - node_r - CLEAR)
		rad[id] = maxf(lim, node_r + MIN_KEEP)
		out.append(_circle(p, rad[id]))
	for e in inner:
		out.append(_capsule(sp[e[0]], sp[e[1]], minf(rad[e[0]], rad[e[1]]) * CAPSULE))
	var pts := PackedVector2Array()
	for id in sp:
		pts.append(sp[id])
	out.append_array(triangles(pts, others, med * TRI_MAX_OF_MEDIAN))
	return out


## 整张图的区块：→ [{level, poly（磨圆、抖过的外缘）, inner: Array[PackedVector2Array]（内收一圈）, ids}]
## [param screen] = 点 id → 屏幕坐标（只给画得出来的点）；挨着的同级区合成一块
static func shapes(graph: MapGraph, screen: Dictionary, node_r: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var edges: Array = []
	if graph == null:
		return out
	for e in graph.edges:
		edges.append([e.from_id, e.to_id])
	var by_level := {1: [], 2: []}
	var ids_of := {1: [], 2: []}
	for g in groups(graph):
		var sp := {}
		for id in g["ids"]:
			if screen.has(id):
				sp[id] = screen[id]
		if sp.is_empty():
			continue
		var others := PackedVector2Array()
		for id in screen:
			if not sp.has(id):
				others.append(screen[id])
		var lv := int(g["level"])
		(by_level[lv] as Array).append_array(pieces(sp, others, edges, node_r))
		(ids_of[lv] as Array).append_array(sp.keys())
	var n := 0
	for lv in [1, 2]:
		for shp in union(by_level[lv]):
			n += 1
			var poly := dedupe(wobble(smooth(shp), WOBBLE, float(n) * 1.7))
			var inner: Array[PackedVector2Array] = []
			for ip in Geometry2D.offset_polygon(poly, -INNER_INSET, Geometry2D.JOIN_ROUND):
				if not Geometry2D.is_polygon_clockwise(ip):
					inner.append(ip)
			out.append({"level": lv, "poly": poly, "inner": inner, "ids": _ids_inside(poly, screen, ids_of[lv])})
	return out


## 一堆多边形并起来（只留外缘；并不上的各自成块）
static func union(polys: Array) -> Array[PackedVector2Array]:
	var acc: Array[PackedVector2Array] = []
	for p in polys:
		var cur: PackedVector2Array = p
		var rest: Array[PackedVector2Array] = []
		for q in acc:
			var outer: Array = Geometry2D.merge_polygons(cur, q).filter(func(x: PackedVector2Array) -> bool: return not Geometry2D.is_polygon_clockwise(x))
			if outer.size() == 1:
				cur = outer[0]
			else:
				rest.append(q)
		rest.append(cur)
		acc = rest
	return acc


## 外扩再内收，把并出来的尖角磨圆
static func smooth(poly: PackedVector2Array) -> PackedVector2Array:
	var grown := Geometry2D.offset_polygon(poly, ROUND, Geometry2D.JOIN_ROUND)
	if grown.is_empty():
		return poly
	var back := Geometry2D.offset_polygon(grown[0], -ROUND, Geometry2D.JOIN_ROUND)
	return back[0] if not back.is_empty() else poly


## 外缘每 7 px 取一点，沿法线按两条 sin 波挪 ±[param amp]（手绘感），首尾接上
static func wobble(poly: PackedVector2Array, amp: float, phase: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var total := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var seg_len := a.distance_to(b)
		var steps := maxi(1, int(seg_len / WOBBLE_STEP))
		var nrm := (b - a).normalized().orthogonal()
		for k in steps:
			var t := float(k) / steps
			var s := total + seg_len * t
			out.append(a.lerp(b, t) + nrm * amp * (0.6 * sin(s * 0.045 + phase) + 0.4 * sin(s * 0.13 + phase * 2.1)))
		total += seg_len
	return out


## 去掉和上一个点挨得太近的点（首尾那对也算）—— 缩到整张图时磨圆抖过的外缘会有相邻的几乎重合的点，
## 引擎的三角剖分就失败了、底色画不出来（UI设计 v5.03 核对：free_mode 种子 7 全图）
const MIN_GAP := 0.05


static func dedupe(poly: PackedVector2Array, gap: float = MIN_GAP) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > gap:
			out.append(p)
	while out.size() > 3 and out[0].distance_to(out[out.size() - 1]) <= gap:
		out.remove_at(out.size() - 1)
	return out


## 画一块（A 红晕虚线）。[param fade] 乘到不透明度上（地图展开动画），[param light] = 浅色底图
static func draw_shape(ci: CanvasItem, shape: Dictionary, light: bool, fade: float = 1.0) -> void:
	var mid := int(shape["level"]) < 2
	var k := (MID_FACTOR if mid else 1.0) * fade
	var tint := TINT_MID if mid else TINT_HIGH
	var edge := EDGE_MID if mid else EDGE_HIGH
	if not light:
		tint = tint.lightened(DARK_TINT_LIFT)
		edge = edge.lightened(DARK_EDGE_LIFT)
	var poly: PackedVector2Array = shape["poly"]
	if poly.size() < 3 or k <= 0.0:
		return
	if fillable(poly):
		ci.draw_colored_polygon(poly, Color(tint, FILL_ALPHA * k))
	for ip in shape["inner"]:
		if fillable(ip):
			ci.draw_colored_polygon(ip, Color(tint, INNER_ALPHA * k))
	dashed_loop(ci, poly, Color(edge, EDGE_ALPHA * k), EDGE_WIDTH, DASH, GAP)


## 剖得开才填：偶尔有自相交或退化的一块（测试 v5.49：引擎报 triangulation failed），那一块只画虚线边
static func fillable(poly: PackedVector2Array) -> bool:
	return poly.size() >= 3 and not Geometry2D.triangulate_polygon(poly).is_empty()


## 闭合虚线：实 [param dash] / 空 [param gap]，跨顶点连续计长
static func dashed_loop(ci: CanvasItem, poly: PackedVector2Array, col: Color, width: float, dash: float, gap: float) -> void:
	var on := true
	var left := dash
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var seg_len := a.distance_to(b)
		var t := 0.0
		while t < seg_len:
			var step := minf(left, seg_len - t)
			if on:
				ci.draw_line(a.lerp(b, t / seg_len), a.lerp(b, (t + step) / seg_len), col, width, true)
			t += step
			left -= step
			if left <= 0.0:
				on = not on
				left = dash if on else gap


static func _circle(c: Vector2, r: float, seg: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		pts.append(c + Vector2.from_angle(TAU * i / seg) * r)
	return pts


static func _capsule(a: Vector2, b: Vector2, r: float) -> PackedVector2Array:
	var d := (b - a).normalized()
	var nrm := Vector2(-d.y, d.x) * r
	var poly := PackedVector2Array([a + nrm, b + nrm, b - nrm, a - nrm])
	return poly if not Geometry2D.is_polygon_clockwise(poly) else PackedVector2Array([a - nrm, b - nrm, b + nrm, a + nrm])


static func _ids_inside(poly: PackedVector2Array, screen: Dictionary, ids: Array) -> Array[int]:
	var out: Array[int] = []
	for id in ids:
		if Geometry2D.is_point_in_polygon(screen[id], poly):
			out.append(int(id))
	out.sort()
	return out
