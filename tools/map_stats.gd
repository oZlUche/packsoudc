## 批量跑环形生成器，看成功率与重试次数的分布。
##
##     godot --headless --path . --script res://tools/map_stats.gd -- [种子数=64] [环数...=4 5 6]
##
## 重试次数一高，说明配置与校验在打架 —— 该改配置，不是调高上限。
## `failure_tally` 汇总会指出是哪条规则在咬。
## 259：最后再拿魔法废墟（free_mode）三档各跑一遍，看「路旁一步」各类点、休息—休息边
## 267：同一遍再数材料节点 —— 每张图几个、按种类分
extends CliTool

const SIDE_TYPES := ["battle", "elite", "search", "chest", "random", "event", "shop", "rest"]


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 64
	var rings: Array[int] = []
	for i in range(1, args.size()):
		rings.append(int(args[i]))
	if rings.is_empty():
		rings = [4, 5, 6] as Array[int]

	print("环数 | 成功 | 平均尝试 | 最多 | 有高危区 | 失败规则（累计）")
	for ring_count in rings:
		var cfg := RingMapConfig.sample(ring_count)
		var made := 0
		var total := 0
		var worst := 0
		var zoned := 0
		var tally := {}
		var graphs: Array = []
		for s in seeds:
			var gen := RingMapGenerator.new()
			var g := gen.generate(cfg, s)
			total += gen.attempts_used
			worst = maxi(worst, gen.attempts_used)
			for rule in gen.failure_tally:
				tally[rule] = int(tally.get(rule, 0)) + int(gen.failure_tally[rule])
			if g != null:
				made += 1
				graphs.append(g)
				if not g.zones.is_empty():
					zoned += 1
		print("%4d | %d/%d | %8.2f | %4d | %8d | %s"
			% [ring_count, made, seeds, float(total) / float(seeds), worst, zoned, str(tally)])
		_route_table(cfg, graphs)
	var ch: ChapterDef = RunSave.load_chapter(&"free_mode")
	if ch != null and ch.map_source != null and ch.map_source.generator_config is RingMapConfig:
		for pair in [[&"small", 4], [&"small", 5], [&"medium", 6]]:
			var cfg: RingMapConfig = (ch.map_source.generator_config as RingMapConfig).duplicate(true)
			cfg.apply_scale(pair[0], pair[1])
			_side_table(cfg, seeds, "free_mode %s %d 环" % [pair[0], pair[1]])
	finish(0)


## 259：每种风格的路线「旁边一步」（不在任何路线上的邻点）各类点每条平均几个；全图休息个数、休息—休息边每张几条
func _side_table(cfg: RingMapConfig, seeds: int, label: String) -> void:
	var made := 0
	var rest := 0
	var rr := 0
	var side := {}
	var count := {}
	var kinds := {}
	var search := 0
	for s in seeds:
		var g := RingMapGenerator.new().generate(cfg, s)
		if g == null:
			continue
		made += 1
		for id in g.node_ids():
			var k := String(g.get_node(id).content.get("search_kind", ""))
			if k != "":
				kinds[k] = int(kinds.get(k, 0)) + 1
			if g.get_node(id).type == &"search":
				search += 1
		for e in g.edges:
			if g.get_node(e.from_id).type == &"rest" and g.get_node(e.to_id).type == &"rest":
				rr += 1
		var on_route := {}
		for r in g.routes:
			for id in (r["node_ids"] as Array):
				on_route[int(id)] = true
		for id in g.node_ids():
			if g.get_node(id).type == &"rest":
				rest += 1
		for r in g.routes:
			var st := String(r.get("style", "?"))
			count[st] = int(count.get(st, 0)) + 1
			if not side.has(st):
				side[st] = {}
			var seen := {}
			for id in (r["node_ids"] as Array):
				for nb in g.neighbors(int(id)):
					if on_route.has(nb) or seen.has(nb):
						continue
					seen[nb] = true
					var t := String(g.get_node(nb).type)
					side[st][t] = int(side[st].get(t, 0)) + 1
	if made == 0:
		return
	print("== %s：%d/%d 张；休息 %.1f/张，休息—休息边 %.2f/张" % [label, made, seeds, float(rest) / made, float(rr) / made])
	var kind_parts: Array[String] = []
	var kind_total := 0
	var kind_ids: Array = kinds.keys()
	kind_ids.sort()
	for k in kind_ids:
		kind_total += int(kinds[k])
		kind_parts.append("%s %.2f" % [k, float(kinds[k]) / made])
	print("       材料节点 %.2f/张（搜索点 %.2f/张）：%s" % [float(kind_total) / made, float(search) / made, ", ".join(kind_parts)])
	var styles: Array = side.keys()
	styles.sort()
	for st in styles:
		var parts: Array[String] = []
		for t in SIDE_TYPES:
			var v := float(side[st].get(t, 0)) / float(count[st])
			if v >= 0.05:
				parts.append("%s %.1f" % [t, v])
		print("       %-8s 路旁一步每条：%s" % [st, ", ".join(parts)])


## 每种风格的路线：风险分、收益分、相对档位、性价比离散、类型构成；覆盖的最远步数。
## 档位落不进区间是「尽力而为」没尽到，不算失败 —— 这张表就是看它尽到几成。
func _route_table(cfg: RingMapConfig, graphs: Array) -> void:
	if graphs.is_empty():
		return
	var by_style := {}
	var spread_sum := 0.0
	var spread_max := 0.0
	var in_band := 0
	var routes_total := 0
	var worst_cover := {}
	for g in graphs:
		var bands := RingTypeAssigner.route_bands(g, cfg)
		spread_sum += bands["ev_spread"]
		spread_max = maxf(spread_max, bands["ev_spread"])
		for i in g.routes.size():
			var r: Dictionary = g.routes[i]
			var style := String(r["style"])
			if not by_style.has(style):
				by_style[style] = {"n": 0, "risk": 0.0, "reward": 0.0, "comp": {}}
			var s: Dictionary = by_style[style]
			s["n"] += 1
			s["risk"] += float(r.get("risk_x100", 0)) / 100.0
			s["reward"] += float(r.get("reward_x100", 0)) / 100.0
			for id in r["node_ids"]:
				var t := String(g.get_node(id).type)
				s["comp"][t] = int(s["comp"].get(t, 0)) + 1
			var rs := cfg.style_by_id(StringName(style))
			routes_total += 1
			if rs != null:
				var rel: Dictionary = bands["rel"][i]
				var risk_ok: bool = rel["risk"] >= rs.risk_band.x and rel["risk"] <= rs.risk_band.y
				var reward_ok: bool = rel["reward"] >= rs.reward_band.x and rel["reward"] <= rs.reward_band.y
				if risk_ok and reward_ok:
					in_band += 1
		for t in cfg.coverage:
			var dist := MapNavigator.distances_to_type(g, t)
			var outer := cfg.ring_count()
			for id in g.node_ids():
				var n: MapNode = g.get_node(id)
				if n.danger <= cfg.no_haven_in_danger_above:
					worst_cover[t] = maxi(int(worst_cover.get(t, 0)), int(dist.get(id, 99)))
	print("       路线落进自己档位：%d/%d　性价比离散 平均 %.2f 最大 %.2f（容差 %.2f）　覆盖最远：%s"
		% [in_band, routes_total, spread_sum / graphs.size(), spread_max, cfg.ev_tolerance, str(worst_cover)])
	var styles: Array = by_style.keys()
	styles.sort()
	for style in styles:
		var s: Dictionary = by_style[style]
		var comp: Dictionary = s["comp"]
		var parts: Array[String] = []
		var keys: Array = comp.keys()
		keys.sort_custom(func(a, b): return comp[a] > comp[b])
		for k in keys:
			parts.append("%s %.1f" % [k, float(comp[k]) / float(s["n"])])
		print("       %-8s 风险 %5.2f  收益 %5.2f  比 %.2f  每条平均：%s"
			% [style, s["risk"] / s["n"], s["reward"] / s["n"],
				(s["reward"] / s["n"]) / maxf(s["risk"] / s["n"], 0.01), ", ".join(parts)])
