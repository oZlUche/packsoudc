## 255（美术设计 11:21 拼件规则，`art/ui/board/out/mask/layout_mask.json`）：有缺格的棋盘框沿轮廓拼 ——
## 直边 `edge_t/r/b/l`（60 × 20）、凸角 `outer_*`、凹角 `inner_*`（20 × 20）。单位是 1x 像素，格 [constant CELL]，框厚 [constant THICK]；
## 界面按自己的格边长缩放。导入器也用 [method pinch_points] 拦「只有两个对角格可用」的顶点（拼不出框）
class_name BoardContour
extends RefCounted

const CELL := 60.0
const THICK := 20.0
## 绘制顺序：格底（界面自己画）→ 直边 → 凹角 → 凸角
const ORDER := ["edge", "inner", "outer"]


## 这块棋盘要摆的拼件，按 [constant ORDER] 排好：`[{"name": "edge_t", "rect": Rect2}, …]`，rect 以棋盘左上角为原点（框在负坐标那边）。
## [param usable] = `func(c: Vector2i) -> bool`，只问盘内的格
static func pieces(size: Vector2i, usable: Callable) -> Array[Dictionary]:
	var ok := func(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y and bool(usable.call(c))
	var t := THICK
	var edges: Array[Dictionary] = []
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			if not ok.call(c):
				continue
			var p := Vector2(c) * CELL
			if not ok.call(c + Vector2i.UP):
				edges.append(_piece("edge_t", Rect2(p + Vector2(0, -t), Vector2(CELL, t))))
			if not ok.call(c + Vector2i.RIGHT):
				edges.append(_piece("edge_r", Rect2(p + Vector2(CELL, 0), Vector2(t, CELL))))
			if not ok.call(c + Vector2i.DOWN):
				edges.append(_piece("edge_b", Rect2(p + Vector2(0, CELL), Vector2(CELL, t))))
			if not ok.call(c + Vector2i.LEFT):
				edges.append(_piece("edge_l", Rect2(p + Vector2(-t, 0), Vector2(t, CELL))))
	var inners: Array[Dictionary] = []
	var outers: Array[Dictionary] = []
	# 顶点 v 四周的格：左上、右上、左下、右下；对应的角名与那一角的拼件左上偏移
	var around := {"tl": Vector2i(-1, -1), "tr": Vector2i(0, -1), "bl": Vector2i(-1, 0), "br": Vector2i(0, 0)}
	var opposite := {"tl": "br", "tr": "bl", "bl": "tr", "br": "tl"}
	for vy in size.y + 1:
		for vx in size.x + 1:
			var v := Vector2i(vx, vy)
			var on: Array[String] = []
			for k in around:
				if ok.call(v + around[k]):
					on.append(k)
			if on.size() == 1 or (on.size() == 2 and opposite[on[0]] == on[1]):
				for k in on:     # 对角两格当两个凸角（导入器拦掉这种形状）
					outers.append(_piece("outer_" + opposite[k], _corner(v, opposite[k])))
			elif on.size() == 3:
				for k in around:
					if not on.has(k):
						inners.append(_piece("inner_" + k, _corner(v, k)))
	var out: Array[Dictionary] = []
	out.append_array(edges)
	out.append_array(inners)
	out.append_array(outers)
	return out


## 只有两个对角格可用的顶点（拼不出框）
static func pinch_points(size: Vector2i, usable: Callable) -> Array[Vector2i]:
	var ok := func(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y and bool(usable.call(c))
	var out: Array[Vector2i] = []
	for vy in range(1, size.y):
		for vx in range(1, size.x):
			var v := Vector2i(vx, vy)
			var tl: bool = ok.call(v + Vector2i(-1, -1))
			var tr: bool = ok.call(v + Vector2i(0, -1))
			var bl: bool = ok.call(v + Vector2i(-1, 0))
			var br: bool = ok.call(v)
			if tl == br and tr == bl and tl != tr:
				out.append(v)
	return out


## 顶点 [param v] 的 [param k] 那一角里的一块 T × T
static func _corner(v: Vector2i, k: String) -> Rect2:
	var p := Vector2(v) * CELL
	var t := THICK
	var dx := -t if k.ends_with("l") else 0.0
	var dy := -t if k.begins_with("t") else 0.0
	return Rect2(p + Vector2(dx, dy), Vector2(t, t))


static func _piece(name: String, rect: Rect2) -> Dictionary:
	return {"name": name, "rect": rect}
