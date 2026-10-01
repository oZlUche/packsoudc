## 地图数据层（架构文档 5.2，M3-1）：MapNode / MapEdge / MapGraph。
##
## 这一层只有三件事要守：**存取不丢字**、**邻接关系对称**、**不认识任何地图形状**。
## 第三件最容易在不知不觉中坏掉，所以写成会红的检查而不是注释。
extends RefCounted


static func run_remove_node(t: TestCase) -> void:
	t.begin("MapGraph · 删点")

	var g := MapGraph.new()
	for id in [1, 2, 3]:
		var n := MapNode.new()
		n.id = id
		n.type = &"battle"
		g.add_node(n)
	g.connect_nodes(1, 2)
	g.connect_nodes(2, 3)
	g.entry_ids = [2] as Array[int]
	g.goal_ids = [2, 3] as Array[int]
	g.zones[1] = {"node_ids": [2] as Array[int], "gate_ids": [2] as Array[int]}
	g.routes = [{"entry_id": 2, "node_ids": [2, 3]}] as Array[Dictionary]

	t.eq(g.next_free_id(), 4, "下一个空闲 id")
	t.check(g.remove_node(2), "删得掉")
	t.check(not g.remove_node(2), "删第二次返回 false")
	t.eq(g.edges.size(), 0, "挨着它的路一并没了")
	t.eq(g.neighbors(1).size(), 0, "邻接索引也跟着作废重建")
	t.check(not g.entry_ids.has(2) and not g.goal_ids.has(2), "出生点与终点里的登记清掉了")
	t.check(not g.zones.has(1), "区里最后一个点没了，区也没了")
	t.eq(g.routes.size(), 1, "路线不动 —— 怎么接是作者的决定，让校验去说它断了")
	t.eq(g.next_free_id(), 2, "空出来的 id 可以再用")

const SOURCES := [
	"res://core/map/map_graph.gd",
	"res://core/map/map_node.gd",
	"res://core/map/map_edge.gd",
]

## 形状相关的词。它们只许出现在生成器与布局策略里，数据层一个都不许有 ——
## 出现了，就是在给第二章（另一种地图形态）挖坑。
const FORBIDDEN := ["ring", "angle", "radius", "floor"]


static func _node(id: int, type: String, tier: int = 0) -> MapNode:
	var n := MapNode.new()
	n.id = id
	n.type = StringName(type)
	n.tier = tier
	return n


## 三个点一条线再加一条单向的回头路：1 — 2 — 3，3 → 1
static func _tiny() -> MapGraph:
	var g := MapGraph.new()
	g.layout_kind = &"test"
	g.layout_meta = {"levels": 2, "note": "x"}
	# 故意乱序加入：导出顺序不该取决于加入顺序
	g.add_node(_node(3, "core", 2))
	g.add_node(_node(1, "battle", 0))
	g.add_node(_node(2, "search", 1))
	g.connect_nodes(1, 2, &"a", 1)
	g.connect_nodes(2, 3, &"b", 2)
	var back := MapEdge.new()
	back.from_id = 3
	back.to_id = 1
	back.directed = true
	back.kind = &"oneway"
	back.layout = {"span": 2}
	g.add_edge(back)

	var n1 := g.get_node(1)
	n1.danger = 1
	n1.zone = 7
	n1.erosion_band = 4
	n1.content_seed = 12345
	n1.content = {"enemy_id": "rat", "count": 2}
	n1.layout = {"level": 0, "order": 3}
	g.get_node(2).state = MapNode.State.VISITED

	g.entry_ids = [1] as Array[int]
	g.goal_ids = [3] as Array[int]
	g.zones = {7: {"node_ids": [1], "gate_ids": [1]}}
	g.routes = [{
		"entry_id": 1, "style": "search", "node_ids": [1, 2, 3],
		"ends_at": "core", "risk": 0.5, "reward": 1.25,
	}] as Array[Dictionary]
	return g


static func run(t: TestCase) -> void:
	t.begin("地图数据层 · 构建与邻接")

	var g := _tiny()
	t.eq(g.node_count(), 3, "三个点")
	t.eq(g.node_ids(), [1, 2, 3] as Array[int], "node_ids 升序，与加入顺序无关")
	t.eq(g.edges.size(), 3, "三条路")

	# --- 拒绝坏数据 ---
	t.check(not g.add_node(_node(1, "dup")), "id 重复的点被拒绝")
	t.is_null(g.connect_nodes(1, 99), "一端不存在的路被拒绝")
	t.is_null(g.connect_nodes(2, 2), "自己连自己被拒绝")
	t.eq(g.edges.size(), 3, "被拒绝的都没留下痕迹")

	# --- 无向路：邻接对称 ---
	t.eq(g.neighbors(2), [1, 3] as Array[int], "2 的邻居是 1 和 3")
	for a in g.node_ids():
		for b in g.neighbors(a):
			var e := g.edge_between(a, b)
			if e != null and not e.directed:
				t.check(g.neighbors(b).has(a), "无向路 %d—%d：b 是 a 的邻居则 a 也是 b 的" % [a, b])

	# --- 单向路：只能顺着走 ---
	t.check(g.neighbors(3).has(1), "3 → 1 顺着走得通")
	t.check(not g.neighbors(1).has(3), "1 到不了 3：那条路是单向的")
	t.eq(g.edges_of(1).size(), 2, "edges_of 不论方向：1 挨着两条路（含那条走不通的）")
	t.check(not g.edge_between(1, 3).passable_from(1), "走不走得通另问 passable_from")

	# --- 加边之后索引要跟上 ---
	g.connect_nodes(1, 3, &"c")
	t.check(g.neighbors(1).has(3), "新加的路立刻算数 —— 邻接索引没有拿旧的糊弄")


static func run_round_trip(t: TestCase) -> void:
	t.begin("地图数据层 · 存取不丢字")

	var g := _tiny()
	var first := g.to_dict()
	var again := MapGraph.from_dict(first).to_dict()
	t.eq(again, first, "to_dict → from_dict → to_dict 逐字段相同")

	# 真正的存档要过一遍 JSON：整数会变成浮点，键会变成字符串
	var text := JSON.stringify(first)
	var parsed = JSON.parse_string(text)
	var from_json := MapGraph.from_dict(parsed)
	t.eq(JSON.stringify(from_json.to_dict()), text, "**过一遍 JSON 之后导出的字节不变**")

	# 逐项看几个最容易丢的
	var n1 := from_json.get_node(1)
	t.eq(n1.type, &"battle", "类型")
	t.eq(n1.danger, 1, "危险等级")
	t.eq(n1.zone, 7, "区域编号")
	t.eq(n1.erosion_band, 4, "侵蚀分档")
	t.eq(n1.content_seed, 12345, "内容种子")
	t.eq(n1.content, {"enemy_id": "rat", "count": 2}, "节点内容 —— 敌人在地图上看得见，所以它得跟着图存")
	t.eq(typeof(n1.layout["order"]), TYPE_INT, "自由字典里的整数读回来仍是整数，不是 3.0")
	t.eq(from_json.get_node(2).state, MapNode.State.VISITED, "走没走过")
	t.eq(from_json.zones, {7: {"node_ids": [1], "gate_ids": [1]}}, "区域表（键还原成整数）")
	t.eq(from_json.routes.size(), 1, "路线")
	t.eq(from_json.routes[0]["node_ids"], [1, 2, 3], "路线经过的点")
	t.eq(from_json.routes[0]["reward"], 1.25, "真正的小数不被误伤")
	t.eq(from_json.entry_ids, [1] as Array[int], "出生点")
	t.eq(from_json.goal_ids, [3] as Array[int], "终点")
	var oneway := from_json.edge_between(3, 1)
	t.check(oneway != null and oneway.directed, "单向路还是单向")
	t.eq(oneway.layout, {"span": 2}, "边的布局载荷")
	t.eq(from_json.edge_between(2, 3).action_cost, 2, "行动消耗")

	# 两端对不上的路读进来要丢掉，而不是留一条悬空的
	var broken := first.duplicate(true)
	(broken["edges"] as Array).append({"from": 1, "to": 404})
	t.eq(MapGraph.from_dict(broken).edges.size(), 3, "两端对不上的路被丢弃")

	# 确定性：同一张图，换个加入顺序，导出的字节一样
	var other := MapGraph.new()
	other.layout_kind = g.layout_kind
	other.layout_meta = g.layout_meta.duplicate(true)
	for id in [2, 1, 3]:
		other.add_node(MapNode.from_dict(g.get_node(id).to_dict()))
	for e in g.edges:
		other.add_edge(MapEdge.from_dict(e.to_dict()))
	other.entry_ids = g.entry_ids.duplicate()
	other.goal_ids = g.goal_ids.duplicate()
	other.zones = g.zones.duplicate(true)
	other.routes = g.routes.duplicate(true)
	t.eq(JSON.stringify(other.to_dict()), text, "节点换个加入顺序，导出的字节不变")


static func run_topology_agnostic(t: TestCase) -> void:
	t.begin("地图数据层 · 不认识任何地图形状")

	# --- 属性名 ---
	for obj in [MapGraph.new(), MapNode.new(), MapEdge.new()]:
		for p in (obj as Object).get_property_list():
			var name := String(p["name"]).to_lower()
			for word in FORBIDDEN:
				t.check(not name.contains(word),
					"%s 的属性 %s 里不该有「%s」—— 形状相关的东西只许放进 layout 字典"
						% [obj.get_script().resource_path.get_file(), p["name"], word])

	# --- 源码：连注释里都不许有 ---
	# 注释里出现，说明写的人脑子里已经在按某种形状想了，下一步就是写进代码
	var re := RegEx.new()
	re.compile("(?i)\\b(%s)\\b" % "|".join(FORBIDDEN))
	for path in SOURCES:
		var src := FileAccess.get_file_as_string(path)
		t.check(src != "", "读得到 %s" % path)
		var hits: Array[String] = []
		var line_no := 0
		for line in src.split("\n"):
			line_no += 1
			var m := re.search(line)
			if m != null:
				hits.append("%d: %s" % [line_no, line.strip_edges()])
		t.check(hits.is_empty(),
			"%s 里出现了形状相关的词：\n    %s" % [path.get_file(), "\n    ".join(hits)])

	# --- tier 与 erosion_band 是两个字段 ---
	var names: Array[String] = []
	for p in MapNode.new().get_property_list():
		names.append(String(p["name"]))
	t.check(names.has("tier") and names.has("erosion_band"),
		"tier 与 erosion_band 各自独立 —— 第一章里数值相等也不合并，侵蚀方向未必永远等于难度方向")
