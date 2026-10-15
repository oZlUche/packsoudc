## 手绘地图的网格脚本：文本 ⇄ [MapGraph]（架构文档 5.4.1）。
##
## 格式只在这里定义一次，[method parse] 与 [method render] 共用同一张符号表。
## **往返不掉字**是它的验收标准：`render(parse(text)) == text`，解析才算没丢信息。
##
## 行列只表示「谁和谁相连、谁排在谁前面」，不表示距离 —— 点画在哪儿是布局的事（5.9）。
class_name MapGridText
extends RefCounted

## 解析出来的图用这个 layout_kind。与生成器 id 同名，编辑器靠它找到校验者与布局
const LAYOUT_KIND := &"grid_script"

## 符号 → 类型。**字母就是类型**（节点类型表，5.4）
const SYMBOL_TYPES := {
	"A": &"battle", "E": &"elite", "Q": &"event", "?": &"random", "V": &"search",
	"S": &"shop", "R": &"rest", "X": &"extract", "B": &"core",
	"P": &"spawn",      # 出生点。符号是解析器先占的位，等作者在表里定
	"K": &"safe",       # 092：保险箱
	"C": &"chest",      # 154：宝箱
	"F": &"forge",      # 175：铸炉
	"1": &"random",     # v0 遗留的缺省点，按 ? 处理（作者的图里还在用）
}

const EMPTY := "."
const ARC := "-"
const SPOKE := "|"
const END_MARK := "0"
const JUNCTION := &"junction"

## 上一次 parse 的出错说明；成功则为空
static var last_error: String = ""


#region 解析
static func parse(text: String) -> MapGraph:
	last_error = ""
	var sections := _split_sections(text)
	if sections.is_empty():
		last_error = "没有 [map] 段头（没有段头的 v0 老格式已不再支持）"
		return null
	var rows: Array = sections["map"]
	if rows.is_empty():
		last_error = "没有地图内容"
		return null
	var danger_rows: Array = sections["danger"]

	var g := MapGraph.new()
	g.layout_kind = LAYOUT_KIND
	var ring_rows := (rows.size() + 1) / 2
	var widths: Array = []
	for line in rows:
		widths.append((line as String).length())

	# --- 第一遍：节点与岔路口，按阅读顺序编号 ---
	var stop_at := {}           # "row:col" -> id（row 是文本行号）
	var zero_cols: Array = []   # 每个环行的行末占位列，没有则 -1
	var next_id := 1
	for ri in ring_rows:
		var y := ri * 2
		var line: String = rows[y]
		zero_cols.append(-1)
		for x in line.length():
			var ch := line[x]
			if ch == END_MARK:
				zero_cols[ri] = x
				continue
			var type := _type_of(ch)
			var is_junction := ch == ARC and (_cell(rows, y - 1, x) == SPOKE or _cell(rows, y + 1, x) == SPOKE)
			if type == &"" and not is_junction:
				continue
			var n := MapNode.new()
			n.id = next_id
			next_id += 1
			n.type = JUNCTION if is_junction else type
			n.tier = ri
			n.erosion_band = ri
			n.content_seed = hash("grid:%d:%d" % [y, x])
			n.danger = _danger_at(danger_rows, y, x)
			n.layout = {"row": ri, "col": x}
			if not is_junction and ch != symbol_of(type):
				n.layout["symbol"] = ch     # 同一种类型的另一种写法（v0 遗留的 1），导出时照原样写回
			g.add_node(n)
			stop_at["%d:%d" % [y, x]] = n.id
			if n.type == &"core":
				g.goal_ids.append(n.id)

	# --- 第二遍：同环的弧 ---
	for ri in ring_rows:
		var y := ri * 2
		var line: String = rows[y]
		var stops: Array[int] = []      # 这一行的列，升序
		for x in line.length():
			if stop_at.has("%d:%d" % [y, x]):
				stops.append(x)
		for i in range(1, stops.size()):
			var left: int = stop_at["%d:%d" % [y, stops[i - 1]]]
			var right: int = stop_at["%d:%d" % [y, stops[i]]]
			# 岔路口自己就是一格 -，所以它和紧挨着的点之间不需要再隔一格 -
			var touching := stops[i] - stops[i - 1] == 1 and (
				g.get_node(left).type == JUNCTION or g.get_node(right).type == JUNCTION)
			if touching or _all_arc(line, stops[i - 1] + 1, stops[i]):
				g.connect_nodes(left, right, &"tangential")
		# 行末占位的左边是 - → 首尾相连成闭环
		var zero: int = zero_cols[ri]
		if zero >= 0 and stops.size() >= 2 and _all_arc(line, stops[-1] + 1, zero):
			var e := g.connect_nodes(stop_at["%d:%d" % [y, stops[-1]]], stop_at["%d:%d" % [y, stops[0]]],
				&"tangential")
			if e != null:
				e.layout = {"wrap": true}

	# --- 第三遍：异环的路。连续的 | 是一条跨环的边 ---
	for y in range(1, rows.size(), 2):
		var line: String = rows[y]
		for x in line.length():
			if line[x] != SPOKE or _cell(rows, y - 1, x) == SPOKE:
				continue        # 不是 |，或者它是上面那条的延续
			var bottom := y
			while _cell(rows, bottom + 1, x) == SPOKE and _cell(rows, bottom + 2, x) == SPOKE:
				bottom += 2
			var a: int = stop_at.get("%d:%d" % [y - 1, x], -1)
			var b: int = stop_at.get("%d:%d" % [bottom + 1, x], -1)
			if a < 0 or b < 0:
				last_error = "第 %d 行第 %d 列的 | 有一头没接在点或弧上" % [y + 1, x + 1]
				return null
			var e := g.connect_nodes(a, b, &"radial")
			var span := (bottom - y) / 2 + 1
			if e != null and span > 1:
				e.layout = {"span": span}

	# --- 画不出来的边（随机生成的图导出时才会有）---
	for link in sections["links"]:
		var ends := (link as String).split("~")
		if ends.size() != 2:
			continue
		var a: int = stop_at.get(_link_key(ends[0]), -1)
		var b: int = stop_at.get(_link_key(ends[1]), -1)
		if a >= 0 and b >= 0 and g.edge_between(a, b) == null:
			var same_row: bool = g.get_node(a).layout["row"] == g.get_node(b).layout["row"]
			g.connect_nodes(a, b, &"tangential" if same_row else &"radial")

	_assign_zones(g)
	_assign_entries(g)
	g.layout_meta = {
		"rows": ring_rows, "zero_cols": zero_cols, "line_widths": widths,
		"zone_rules": ZoneRules.new().to_dict(),
	}
	if not danger_rows.is_empty():
		# 底色刷在 - 上没有意义，但要原样写得回去
		g.layout_meta["danger_rows"] = danger_rows
	return g


## 按 `[段名]` 切段。内容必须写在某个段头之下：段头之前就有内容（没有 `[map]` 的 v0 老格式）返回空字典
static func _split_sections(text: String) -> Dictionary:
	var out := {"map": [], "danger": [], "links": []}
	var current := ""
	for raw in text.split("\n"):
		var line := raw.trim_suffix("\r")
		if line.begins_with("[") and line.ends_with("]"):
			current = line.substr(1, line.length() - 2)
			if not out.has(current):
				out[current] = []
			continue
		if line.strip_edges() == "":
			continue
		if current == "":
			return {}
		(out[current] as Array).append(line)
	return out


static func _type_of(ch: String) -> StringName:
	return SYMBOL_TYPES.get(ch, &"")


static func _danger_at(danger_rows: Array, y: int, x: int) -> int:
	if y >= danger_rows.size() or x >= (danger_rows[y] as String).length():
		return 0
	var d: String = (danger_rows[y] as String)[x]
	return int(d) if d.is_valid_int() else 0


static func _cell(rows: Array, y: int, x: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= (rows[y] as String).length():
		return ""
	return (rows[y] as String)[x]


## [from, to) 之间至少一格，且全是 -
static func _all_arc(line: String, from: int, to: int) -> bool:
	if to <= from:
		return false
	for x in range(from, to):
		if line[x] != ARC:
			return false
	return true


static func _link_key(coord: String) -> String:
	var rc := coord.strip_edges().split(",")
	return "%d:%d" % [int(rc[0]) * 2, int(rc[1])] if rc.size() == 2 else ""


## 同一危险等级、相连的一片节点是一个区域。
static func _assign_zones(g: MapGraph) -> void:
	var zone_id := 0
	for id in g.node_ids():
		var n := g.get_node(id)
		if n.danger <= 0 or n.zone != 0:
			continue
		zone_id += 1
		var members: Array[int] = []
		var queue: Array[int] = [id]
		n.zone = zone_id
		while not queue.is_empty():
			var cur: int = queue.pop_front()
			members.append(cur)
			for other in g.neighbors(cur):
				var o := g.get_node(other)
				if o.zone == 0 and o.danger == n.danger:
					o.zone = zone_id
					queue.append(other)
		members.sort()
		g.zones[zone_id] = {"node_ids": members, "gate_ids": ZoneRules.gate_ids(g, members)}


## 出生点：画了 P 就是 P；一个都没画，就按最外环上每一段弧的第一个点（占位规则）。
static func _assign_entries(g: MapGraph) -> void:
	for id in g.node_ids():
		if g.get_node(id).type == &"spawn":
			g.entry_ids.append(id)
	if not g.entry_ids.is_empty():
		return
	var outer: Array[int] = []
	for id in g.node_ids():
		if int(g.get_node(id).layout["row"]) == 0:
			outer.append(id)
	var seen := {}
	for id in outer:        # node_ids 升序 = 列升序
		if seen.has(id) or g.get_node(id).type == JUNCTION:
			continue
		g.entry_ids.append(id)
		var queue: Array[int] = [id]
		seen[id] = true
		while not queue.is_empty():
			var cur: int = queue.pop_front()
			for other in g.neighbors(cur):
				if outer.has(other) and not seen.has(other):
					seen[other] = true
					queue.append(other)
#endregion


#region 导出
static func symbol_of(type: StringName) -> String:
	for s in SYMBOL_TYPES:
		if SYMBOL_TYPES[s] == type and s != "1":
			return s
	return "?"


## 把一张图写成网格脚本。
##
## 解析出来的图原样写回（逐字节）。别的形态的图（同心环）先排进行列再写：
## 画不成 `-` 与 `|` 的边 —— 两端不同列的径向边 —— 列在 `[links]` 段里，一条也不丢。
static func render(g: MapGraph) -> String:
	var cells := _cells_of(g)
	if cells.is_empty():
		return ""
	var place: Dictionary = cells["place"]     # id -> Vector2i(col, ring_row)
	var ring_rows: int = cells["rows"]
	var zero_cols: Array = cells["zero_cols"]

	var grid: Array = []        # 每行一个 Array[String]
	for _y in ring_rows * 2 - 1:
		grid.append([])
	var links: Array[String] = []

	for id in g.node_ids():
		var n := g.get_node(id)
		var p: Vector2i = place[id]
		var ch := ARC if n.type == JUNCTION else String(n.layout.get("symbol", symbol_of(n.type)))
		_put(grid, p.y * 2, p.x, ch)
	for ri in ring_rows:
		if int(zero_cols[ri]) >= 0:
			_put(grid, ri * 2, int(zero_cols[ri]), END_MARK)

	for e in g.edges:
		var a: Vector2i = place[e.from_id]
		var b: Vector2i = place[e.to_id]
		if a.y == b.y:
			if _is_wrap(place, e, a, b) and int(zero_cols[a.y]) >= 0:
				for x in range(maxi(a.x, b.x) + 1, int(zero_cols[a.y])):
					_put(grid, a.y * 2, x, ARC)
			elif _clear_between(g, place, e):
				for x in range(mini(a.x, b.x) + 1, maxi(a.x, b.x)):
					_put(grid, a.y * 2, x, ARC)
			else:
				links.append(_link_text(a, b))
		elif a.x == b.x:
			for y in range(mini(a.y, b.y) * 2 + 1, maxi(a.y, b.y) * 2):
				_put(grid, y, a.x, SPOKE)
		else:
			links.append(_link_text(a, b))

	var widths: Array = g.layout_meta.get("line_widths", [])
	var map_lines: Array[String] = []
	var width := 0
	for row in grid:
		width = maxi(width, (row as Array).size())
	for y in grid.size():
		map_lines.append(_line(grid[y], int(widths[y]) if y < widths.size() else width))

	var out := "[map]\n" + "\n".join(map_lines) + "\n\n[danger]\n" \
		+ "\n".join(_danger_lines(g, place, map_lines)) + "\n"
	if not links.is_empty():
		links.sort()
		out += "\n[links]\n" + "\n".join(links) + "\n"
	return out


## 每个点排在第几行第几列。解析出来的图自己带着；同心环的图按槽位比例排。
static func _cells_of(g: MapGraph) -> Dictionary:
	var place := {}
	if g.layout_kind == LAYOUT_KIND:
		for id in g.node_ids():
			var lay := g.get_node(id).layout
			place[id] = Vector2i(int(lay["col"]), int(lay["row"]))
		return {
			"place": place, "rows": int(g.layout_meta.get("rows", 0)),
			"zero_cols": g.layout_meta.get("zero_cols", []),
		}
	if not g.layout_meta.has("ring_count"):
		return {}
	var count := int(g.layout_meta["ring_count"])
	var most := 1
	for r in range(1, count + 1):
		most = maxi(most, RingSpec.slots_of(g, r, 1))
	var zero_cols: Array = []
	for r in range(count, 0, -1):
		zero_cols.append(most * 2)
	zero_cols.append(-1)        # 核心那一行
	for id in g.node_ids():
		var lay := g.get_node(id).layout
		var r := int(lay.get("ring", 0))
		if r <= 0:
			place[id] = Vector2i(most, count)
			continue
		var slots := maxi(1, RingSpec.slots_of(g, r, 1))
		# 每个槽位至少隔两列，中间才塞得下一个 -
		place[id] = Vector2i(roundi(float(int(lay["order"])) * float(most * 2) / float(slots)), count - r)
	return {"place": place, "rows": count + 1, "zero_cols": zero_cols}


## 首尾相连的那条弧：解析出来的图上有标记；别的形态的图上，就是「连着这一行最左与最右两个点、
## 而中间还隔着别的点」的那条 —— 它不可能是从中间画过去的。
static func _is_wrap(place: Dictionary, e: MapEdge, a: Vector2i, b: Vector2i) -> bool:
	if bool(e.layout.get("wrap", false)):
		return true
	var lo := mini(a.x, b.x)
	var hi := maxi(a.x, b.x)
	var between := false
	for id in place:
		var p: Vector2i = place[id]
		if p.y != a.y:
			continue
		if p.x < lo or p.x > hi:
			return false
		if p.x > lo and p.x < hi:
			between = true
	return between


static func _clear_between(g: MapGraph, place: Dictionary, e: MapEdge) -> bool:
	var a: Vector2i = place[e.from_id]
	var b: Vector2i = place[e.to_id]
	if absi(a.x - b.x) < 2:
		# 挨着的两格之间塞不下 -。除非其中一个是岔路口：它自己就是那一格 -
		return g.get_node(e.from_id).type == JUNCTION or g.get_node(e.to_id).type == JUNCTION
	for id in place:
		var p: Vector2i = place[id]
		if p.y == a.y and p.x > mini(a.x, b.x) and p.x < maxi(a.x, b.x):
			return false
	return true


static func _link_text(a: Vector2i, b: Vector2i) -> String:
	var first := a if (a.y < b.y or (a.y == b.y and a.x <= b.x)) else b
	var second := b if first == a else a
	return "%d,%d~%d,%d" % [first.y, first.x, second.y, second.x]


static func _put(grid: Array, y: int, x: int, ch: String) -> void:
	var row: Array = grid[y]
	while row.size() <= x:
		row.append(EMPTY)
	row[x] = ch


static func _line(row: Array, width: int) -> String:
	var s := "".join(PackedStringArray(row))
	while s.length() < width:
		s += EMPTY
	return s


## 危险层。节点那一格以节点为准；别的格子有原稿就照原稿，没有就把同一片里相邻的点之间刷满。
static func _danger_lines(g: MapGraph, place: Dictionary, map_lines: Array[String]) -> Array[String]:
	var stored: Array = g.layout_meta.get("danger_rows", [])
	var grid: Array = []
	for y in map_lines.size():
		var row: Array = []
		for x in map_lines[y].length():
			var keep := EMPTY
			if y < stored.size() and x < (stored[y] as String).length():
				keep = (stored[y] as String)[x]
			row.append(keep)
		grid.append(row)
	for id in g.node_ids():
		var n := g.get_node(id)
		var p: Vector2i = place[id]
		_put(grid, p.y * 2, p.x, str(n.danger) if n.danger > 0 else EMPTY)
	if stored.is_empty():
		for e in g.edges:
			var a: Vector2i = place[e.from_id]
			var b: Vector2i = place[e.to_id]
			var na := g.get_node(e.from_id)
			var nb := g.get_node(e.to_id)
			if a.y != b.y or na.danger <= 0 or na.zone != nb.zone or bool(e.layout.get("wrap", false)):
				continue
			for x in range(mini(a.x, b.x) + 1, maxi(a.x, b.x)):
				if map_lines[a.y * 2][x] == ARC:
					_put(grid, a.y * 2, x, str(na.danger))
	var out: Array[String] = []
	for y in grid.size():
		out.append(_line(grid[y], map_lines[y].length()))
	return out
#endregion
