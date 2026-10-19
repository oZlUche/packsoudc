## 198：地上的东西按「轮廓」碰撞，不按格子的包围盒（作者 2026-10-19：「掉落在地上时，道具的体积碰撞要去计算道具本身的贴图而不是格子」）。
##
## 每个 [ItemDef] × 朝向一份：像素坐标（一格 [constant InventoryView.CELL]），原点 = 这个朝向格子包围盒的左上角。
## 内容是一组凸块（最多 [constant MAX_PARTS] 块，多了退成一块凸包）+ 外轮廓（画描边、算支撑）+ 透明通道的位图（点选；没图 null）。
## 来源：[method ItemPainter.art_available] 为真且这件有图 → 图的透明通道；没图 → 占格的外形（凸块 = 合并后的整格矩形，没有斜切的假边）。
## 只在画面层（[GroundLayer]）用，不进存档、不进规则（3.4）；棋盘、残影、合成、负重照旧按格子
class_name ItemSilhouette
extends RefCounted

## 凸块最多几块，多了退成一块凸包
const MAX_PARTS := 6
## 透明通道：不透明度到这个算实心；实心区往外长几像素（细长的刀刃最少 4 像素厚，不会从缝里滑过去）；外轮廓的简化容差
const ALPHA_CUT := 0.5
const GROW := 2
const TRACE_EPSILON := 2.0
## 支撑面：离最低点这么近（像素）的轮廓顶点都算着地
const SUPPORT_TOL := 2.0
## 198 补充一：接触点 —— 离最深处这么近（像素）的顶点算同一条边 / 同一个角
const FEATURE_TOL := 1.0
## 198 补充二：落稳朝向 —— 重心高度差这么多像素以内算并列
const REST_TIE := 2.0

## 「格子外形 / 图」+ 朝向 → 轮廓（第一次用到时算，之后查表）
static var _cache: Dictionary = {}


## 一件在朝向 [param rot] 的轮廓：{parts: 凸块, outline: 外轮廓（几圈）, mask: 位图或 null, bounds: 凸块的包围盒, centroid: 面积重心}
static func of(def: ItemDef, rot: int) -> Dictionary:
	rot = posmod(rot, 4)
	if def == null or def.shape == null:
		return _empty()
	var img := _art_image(def) if ItemPainter.art_available() else null
	if img != null:
		var akey := "art|%s|%d" % [def.id, rot]
		if not _cache.has(akey):
			var span := def.shape.size_rotated(0) * int(InventoryView.CELL)
			_cache[akey] = from_image(img, rot, span)
		return _cache[akey]
	var key := "cells|%s|%d" % [def.shape.to_bits(rot), rot]
	if not _cache.has(key):
		_cache[key] = from_cells(def.shape.cells_rotated(rot))
	return _cache[key]


## 清掉缓存（换图包时）
static func clear() -> void:
	_cache.clear()


## 这个朝向的面积重心（像素，从包围盒左上角量）。没图时就是占格中心的平均 × 一格
static func centroid(def: ItemDef, rot: int) -> Vector2:
	return of(def, rot)["centroid"]


## 198 阶段二（201 接道具图）：这件的图，没有 → null（按格子外形）
static func _art_image(def: ItemDef) -> Image:
	var tex := ItemPainter.art_of(def)     # 201：60 px / 格那一套，画布 = 包围盒 × 60
	return tex.get_image() if tex != null else null


static func _empty() -> Dictionary:
	var parts: Array[PackedVector2Array] = []
	var outline: Array[PackedVector2Array] = []
	return {"parts": parts, "outline": outline, "mask": null, "bounds": Rect2(), "centroid": Vector2.ZERO}


#region 来源
## 占格（已按朝向转好、左上角在 (0, 0)）→ 轮廓：外轮廓沿格边走一圈；凸块 = 一行行的连续格合并成的矩形
static func from_cells(cells: Array[Vector2i]) -> Dictionary:
	var out := _empty()
	if cells.is_empty():
		return out
	var cell := InventoryView.CELL
	var parts: Array[PackedVector2Array] = []
	for r in _cell_rects(cells):
		parts.append(_rect_poly(Rect2(Vector2(r.position) * cell, Vector2(r.size) * cell)))
	var outline := _trace_cells(cells)
	if parts.size() > MAX_PARTS:
		parts = [_hull(outline)]
	out["parts"] = parts
	out["outline"] = outline
	out["bounds"] = bounds_of(parts)
	var sum := Vector2.ZERO
	for c in cells:
		sum += Vector2(c) + Vector2(0.5, 0.5)
	out["centroid"] = sum / cells.size() * cell
	return out


## 图（朝向 0 的画布；[param canvas] 给了就先缩放到它）→ 转到朝向 [param rot] → 透明通道的位图 → 往外长 [constant GROW] →
## 面积最大的一圈外轮廓 → 凸分解（多于 [constant MAX_PARTS] 块退成凸包）
static func from_image(src: Image, rot: int, canvas: Vector2i = Vector2i.ZERO) -> Dictionary:
	var out := _empty()
	if src == null or src.is_empty():
		return out
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if canvas.x > 0 and canvas.y > 0 and img.get_size() != canvas:
		img.resize(canvas.x, canvas.y, Image.INTERPOLATE_BILINEAR)
	for i in posmod(rot, 4):
		img.rotate_90(CLOCKWISE)
	var whole := Rect2i(Vector2i.ZERO, img.get_size())
	var mask := BitMap.new()
	mask.create_from_image_alpha(img, ALPHA_CUT)
	mask.grow_mask(GROW, whole)
	var best := PackedVector2Array()
	var best_area := 0.0
	for poly in mask.opaque_to_polygons(whole, TRACE_EPSILON):
		var a := absf(_area(poly))
		if a > best_area:
			best_area = a
			best = poly
	if best.size() < 3:
		return out
	var parts: Array[PackedVector2Array] = []
	parts.assign(Geometry2D.decompose_polygon_in_convex(best))
	if parts.is_empty() or parts.size() > MAX_PARTS:
		parts = [_hull([best])]
	var outline: Array[PackedVector2Array] = [best]
	out["parts"] = parts
	out["outline"] = outline
	out["mask"] = mask
	out["bounds"] = bounds_of(parts)
	out["centroid"] = _poly_centroid(best)
	return out


## 一行行的连续格，上下两行同起同止的接成一块：每块是一个整格矩形（格单位）
static func _cell_rects(cells: Array[Vector2i]) -> Array[Rect2i]:
	var rows := {}
	for c in cells:
		if not rows.has(c.y):
			rows[c.y] = []
		(rows[c.y] as Array).append(c.x)
	var ys := rows.keys()
	ys.sort()
	var done: Array[Rect2i] = []
	var open := {}     # Vector2i(x0, x1) → 还在往下长的那块
	for y in ys:
		var xs: Array = rows[y]
		xs.sort()
		var runs: Array[Vector2i] = []
		var start: int = xs[0]
		var prev: int = xs[0]
		for i in range(1, xs.size()):
			if xs[i] != prev + 1:
				runs.append(Vector2i(start, prev + 1))
				start = xs[i]
			prev = xs[i]
		runs.append(Vector2i(start, prev + 1))
		var next_open := {}
		for run in runs:
			var r: Rect2i
			if open.has(run) and (open[run] as Rect2i).end.y == y:
				r = open[run]
				r.size.y += 1
				open.erase(run)
			else:
				r = Rect2i(run.x, y, run.y - run.x, 1)
			next_open[run] = r
		for k in open:
			done.append(open[k])
		open = next_open
	for k in open:
		done.append(open[k])
	return done


## 占格的外轮廓（像素）：每格没有邻居的那条边按顺时针（实心在右手边）连起来，去掉共线点；只留外圈（洞不要）
static func _trace_cells(cells: Array[Vector2i]) -> Array[PackedVector2Array]:
	var occupied := {}
	for c in cells:
		occupied[c] = true
	var edges := {}     # 起点 → [终点…]
	var sides := [[Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 1)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 1)], [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, 0)]]
	for c in cells:
		for s in sides:
			if occupied.has(c + (s[0] as Vector2i)):
				continue
			var a: Vector2i = c + (s[1] as Vector2i)
			if not edges.has(a):
				edges[a] = []
			(edges[a] as Array).append(c + (s[2] as Vector2i))
	var loops: Array[PackedVector2Array] = []
	while not edges.is_empty():
		var first: Vector2i = edges.keys()[0]
		var pts: Array[Vector2i] = [first]
		var at := first
		var dir := Vector2i.ZERO
		while true:
			var outs: Array = edges[at]
			var pick := 0
			if outs.size() > 1 and dir != Vector2i.ZERO:
				var best := -INF
				for i in outs.size():
					var d: Vector2i = (outs[i] as Vector2i) - at
					var turn := float(dir.x * d.y - dir.y * d.x)     # 屏幕坐标里 > 0 = 右转：斜着相碰的两格各走各的圈
					if turn > best:
						best = turn
						pick = i
			var to: Vector2i = outs[pick]
			outs.remove_at(pick)
			if outs.is_empty():
				edges.erase(at)
			dir = to - at
			at = to
			if at == first:
				break
			pts.append(at)
		var poly := PackedVector2Array()
		var n := pts.size()
		for i in n:
			var p := pts[(i - 1 + n) % n]
			var q := pts[i]
			var r := pts[(i + 1) % n]
			if (q - p).x * (r - q).y - (q - p).y * (r - q).x != 0:
				poly.append(Vector2(q) * InventoryView.CELL)
		if poly.size() >= 3 and _area(poly) > 0.0:
			loops.append(poly)
	return loops
#endregion


#region 几何
## 一组凸块的包围盒
static func bounds_of(parts: Array) -> Rect2:
	var have := false
	var r := Rect2()
	for poly in parts:
		for p in (poly as PackedVector2Array):
			if not have:
				r = Rect2(p, Vector2.ZERO)
				have = true
			else:
				r = r.expand(p)
	return r


## 一块矩形当一个凸块（面板、测试）
static func rect_poly(r: Rect2) -> PackedVector2Array:
	return _rect_poly(r)


static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## 有向面积（屏幕坐标里顺时针为正）
static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


static func _poly_centroid(poly: PackedVector2Array) -> Vector2:
	var a := _area(poly)
	if absf(a) < 0.0001:
		var sum := Vector2.ZERO
		for p in poly:
			sum += p
		return sum / maxf(1.0, poly.size())
	var c := Vector2.ZERO
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		c += (p + q) * (p.x * q.y - q.x * p.y)
	return c / (6.0 * a)


static func _hull(loops: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for poly in loops:
		pts.append_array(poly as PackedVector2Array)
	var h := Geometry2D.convex_hull(pts)
	if h.size() > 1 and h[0] == h[h.size() - 1]:
		h.remove_at(h.size() - 1)
	return h


static func _project(poly: PackedVector2Array, off: Vector2, axis: Vector2) -> Vector2:
	var lo := INF
	var hi := -INF
	for p in poly:
		var d := (p + off).dot(axis)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return Vector2(lo, hi)


## 分离轴（SAT）：两件（凸块 [param a_parts] 摆在 [param a_pos]、[param b_parts] 摆在 [param b_pos]）压进去多深、往哪分开。
## 每一对凸块拿两块所有边的法线当轴，投影重叠最小的轴 = 这一对的分开方向；所有块对里取压得最深的那一对。
## 返回 {n: 单位向量（b 该往 n、a 往 −n 走）, depth: 像素（不相交 = 0）}。重叠一样少的轴取更横的那根（矩形件和 180 一样先横向分开）；
## 两块的中心在这根轴上重合时 n 的方向取 [param tie]（+1 = 轴的正向）
static func separate(a_parts: Array, a_pos: Vector2, b_parts: Array, b_pos: Vector2, tie: float = 1.0) -> Dictionary:
	var best_depth := 0.0
	var best_n := Vector2.ZERO
	for pa in a_parts:
		var ra := bounds_of([pa])
		ra.position += a_pos
		for pb in b_parts:
			var rb := bounds_of([pb])
			rb.position += b_pos
			if ra.position.x >= rb.end.x or rb.position.x >= ra.end.x or ra.position.y >= rb.end.y or rb.position.y >= ra.end.y:
				continue     # 粗筛：包围盒都不相交
			var hit := _sat(pa, a_pos, pb, b_pos)
			if float(hit["depth"]) <= best_depth:
				continue
			var n: Vector2 = hit["n"]
			if n.x < -0.000001 or (absf(n.x) <= 0.000001 and n.y < 0.0):
				n = -n
			var d := (rb.get_center() - ra.get_center()).dot(n)
			n *= signf(d) if absf(d) > 0.01 else signf(tie)
			best_depth = hit["depth"]
			best_n = n
	return {"n": best_n, "depth": best_depth}


static func _sat(pa: PackedVector2Array, a_pos: Vector2, pb: PackedVector2Array, b_pos: Vector2) -> Dictionary:
	var depth := INF
	var n := Vector2.ZERO
	for poly in [pa, pb]:
		var m: int = (poly as PackedVector2Array).size()
		for i in m:
			var e: Vector2 = poly[(i + 1) % m] - poly[i]
			if e.length_squared() < 0.000001:
				continue
			var axis := Vector2(-e.y, e.x).normalized()
			var ia := _project(pa, a_pos, axis)
			var ib := _project(pb, b_pos, axis)
			var o := minf(ia.y, ib.y) - maxf(ia.x, ib.x)
			if o <= 0.0:
				return {"n": Vector2.ZERO, "depth": 0.0}
			if o < depth - 0.0001 or (absf(o - depth) <= 0.0001 and absf(axis.x) > absf(n.x) + 0.0001):
				depth = o
				n = axis
	return {"n": n, "depth": depth if depth != INF else 0.0}


## 竖直投射：a 往下（+y）还能掉多远就碰到 b（像素；碰不到 INF）。a 的每个顶点对 b 的边、b 的每个顶点对 a 的边量竖直距离，取最小的那个不为负的
## （−0.5 以内算贴着）。横向重叠不到 [param x_eps] 的块对不算（并排贴着的不是支撑），起手就压着的块对不算
static func drop_gap(a_parts: Array, a_pos: Vector2, b_parts: Array, b_pos: Vector2, x_eps: float = 0.0) -> float:
	var best := INF
	for pa in a_parts:
		var ra := bounds_of([pa])
		ra.position += a_pos
		for pb in b_parts:
			var rb := bounds_of([pb])
			rb.position += b_pos
			if ra.position.x >= rb.end.x - x_eps or ra.end.x <= rb.position.x + x_eps:
				continue
			if rb.end.y < ra.position.y - 0.5:
				continue     # 整块在上面
			if float(_sat(pa, a_pos, pb, b_pos)["depth"]) > 0.5:
				continue
			best = minf(best, _cast(pa, a_pos, pb, b_pos, 1.0))
			best = minf(best, _cast(pb, b_pos, pa, a_pos, -1.0))
	return best


## [param from] 的每个顶点竖直碰到 [param onto] 的边的距离（[param down] = 1：from 往下走；−1：onto 往下走、量的是反方向）
static func _cast(from: PackedVector2Array, from_pos: Vector2, onto: PackedVector2Array, onto_pos: Vector2, down: float) -> float:
	var best := INF
	var m := onto.size()
	for v in from:
		var p := v + from_pos
		for i in m:
			var e0 := onto[i] + onto_pos
			var e1 := onto[(i + 1) % m] + onto_pos
			var dx := e1.x - e0.x
			if absf(dx) < 0.000001:
				continue
			var t := (p.x - e0.x) / dx
			if t < 0.0 or t > 1.0:
				continue
			var d := (e0.y + (e1.y - e0.y) * t - p.y) * down
			if d >= -0.5:
				best = minf(best, d)
	return best
#endregion


#region 斜着（198 补充一）
## 一份轮廓（[method of] 给的）绕它的重心转 [param ang]（弧度，顺时针为正）：{parts, outline, bounds, centroid}，原点不变（仍从不斜时包围盒的左上角量）。
## 位图不转 —— 点选把点反着转回去查（[method GroundLayer.uid_at_local]）
static func tilted(sil: Dictionary, ang: float) -> Dictionary:
	if is_zero_approx(ang):
		return sil
	var c: Vector2 = sil["centroid"]
	var parts: Array[PackedVector2Array] = []
	for poly in (sil["parts"] as Array):
		parts.append(turn(poly, c, ang))
	var outline: Array[PackedVector2Array] = []
	for poly in (sil["outline"] as Array):
		outline.append(turn(poly, c, ang))
	return {"parts": parts, "outline": outline, "mask": sil["mask"], "bounds": bounds_of(parts), "centroid": c}


## 一圈点绕 [param pivot] 转 [param ang]，再挪 [param off]
static func turn(poly: PackedVector2Array, pivot: Vector2, ang: float, off: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(poly.size())
	if ang == 0.0:
		for i in poly.size():
			out[i] = poly[i] + off     # 不斜：原样挪（不绕重心来回算，免得 −0.000001 这种出界）
		return out
	var cs := cos(ang)
	var sn := sin(ang)
	for i in poly.size():
		var d := poly[i] - pivot
		out[i] = pivot + off + Vector2(d.x * cs - d.y * sn, d.x * sn + d.y * cs)
	return out


## 两块凸块（都已摆到同一坐标系）的接触：分离轴给方向与深度，再取接触点。
## 返回 {n: 单位向量（a → b）, depth: 压进去多深（隔开的为负）, points: 1～2 个接触点}；隔得比 [param touch] 还远 → 空字典。
## 接触点：两块各取沿 n 最深、离最深不到 [constant FEATURE_TOL] 的那几个顶点（一条边或一个角），两段沿切线的区间取交，交出一段就取两头、一个点就取那点
## （平底边压着平面要两个点才不摇，198 §7.4）
static func contact(pa: PackedVector2Array, pb: PackedVector2Array, touch: float = 0.0) -> Dictionary:
	var depth := INF
	var n := Vector2.ZERO
	for poly in [pa, pb]:
		var m: int = (poly as PackedVector2Array).size()
		for i in m:
			var e: Vector2 = poly[(i + 1) % m] - poly[i]
			if e.length_squared() < 0.000001:
				continue
			var axis := Vector2(-e.y, e.x).normalized()
			var ia := _project(pa, Vector2.ZERO, axis)
			var ib := _project(pb, Vector2.ZERO, axis)
			var o := minf(ia.y, ib.y) - maxf(ia.x, ib.x)
			if o <= -touch:
				return {}
			if o < depth - 0.0001 or (absf(o - depth) <= 0.0001 and absf(axis.x) > absf(n.x) + 0.0001):
				depth = o
				n = axis
	if depth == INF:
		return {}
	var ia := _project(pa, Vector2.ZERO, n)
	var ib := _project(pb, Vector2.ZERO, n)
	if ia.x + ia.y > ib.x + ib.y:
		n = -n
		ia = Vector2(-ia.y, -ia.x)
		ib = Vector2(-ib.y, -ib.x)
	var tan := Vector2(-n.y, n.x)
	var fa := _feature(pa, n, ia.y, tan)
	var fb := _feature(pb, -n, -ib.x, tan)
	var lo := maxf(fa.x, fb.x)
	var hi := minf(fa.y, fb.y)
	var s := (ia.y + ib.x) * 0.5
	var points := PackedVector2Array()
	if hi - lo < 1.0:
		points.append(n * s + tan * ((lo + hi) * 0.5))
	else:
		points.append(n * s + tan * lo)
		points.append(n * s + tan * hi)
	return {"n": n, "depth": depth, "points": points}


## 一块沿 [param dir] 最远（离 [param far] 不到 [constant FEATURE_TOL]）的那几个顶点在切线 [param tan] 上占的区间
static func _feature(poly: PackedVector2Array, dir: Vector2, far: float, tan: Vector2) -> Vector2:
	var lo := INF
	var hi := -INF
	for p in poly:
		if p.dot(dir) >= far - FEATURE_TOL:
			var t := p.dot(tan)
			lo = minf(lo, t)
			hi = maxf(hi, t)
	return Vector2(lo, hi)
#endregion


#region 落稳朝向
## 落在地上会躺成哪个朝向（四选一，162 补充二的规则按轮廓算）：重心 = 轮廓的面积重心，支撑面 = 轮廓最低一段的横向区间；
## 重心不在支撑面上方的朝向不稳。198 补充二：先挑重心最低的（离底边的像素，最低的最稳 —— 长条一律躺平，站不稳的歪几度由解算接着），
## 差 [constant REST_TIE] 像素以内算并列，并列才挑稳的，再并列取更宽的，再并列留在 [param current]
static func rest_rotation(def: ItemDef, current: int) -> int:
	if def == null or def.shape == null:
		return posmod(current, 4)
	var best := -1
	var best_stable := false
	var best_d := 0.0
	var best_w := 0.0
	for i in 4:
		var rot := posmod(current + i, 4)
		var sil := of(def, rot)
		var box: Rect2 = sil["bounds"]
		if box.size.y <= 0.0:
			continue
		var c: Vector2 = sil["centroid"]
		var sup := support_span(sil)
		var stable := c.x >= sup.x - 0.01 and c.x <= sup.y + 0.01
		var d := box.end.y - c.y
		var w := box.size.x
		var better := best < 0
		if not better and absf(d - best_d) > REST_TIE:
			better = d < best_d
		elif not better and stable != best_stable:
			better = stable
		elif not better:
			better = w > best_w + 0.0001
		if better:
			best = rot
			best_stable = stable
			best_d = d
			best_w = w
	return best if best >= 0 else posmod(current, 4)


## 着地的那一段（像素，x 从 .x 到 .y）：外轮廓里离最低点 [constant SUPPORT_TOL] 以内的顶点
static func support_span(sil: Dictionary) -> Vector2:
	var box: Rect2 = sil["bounds"]
	var lo := INF
	var hi := -INF
	for poly in (sil["outline"] as Array):
		for p in (poly as PackedVector2Array):
			if p.y >= box.end.y - SUPPORT_TOL:
				lo = minf(lo, p.x)
				hi = maxf(hi, p.x)
	if lo == INF:
		return Vector2(box.position.x, box.end.x)
	return Vector2(lo, hi)
#endregion


## 点选：[param local]（从包围盒左上角量的像素）点在实心上没有。有图看透明通道；没图看格子
static func hit(def: ItemDef, rot: int, local: Vector2) -> bool:
	var sil := of(def, rot)
	var mask: BitMap = sil["mask"]
	if mask != null:
		var p := Vector2i(local.floor())
		var sz := mask.get_size()
		return p.x >= 0 and p.y >= 0 and p.x < sz.x and p.y < sz.y and mask.get_bitv(p)
	if local.x < 0.0 or local.y < 0.0 or def == null:
		return false
	return def.cells_rotated(rot).has(Vector2i((local / InventoryView.CELL).floor()))
