## 批量跑环形生成器，看成功率与重试次数的分布。
##
##     godot --headless --path . --script res://tools/map_stats.gd -- [种子数=64] [环数...=4 5 6]
##
## 重试次数一高，说明配置与校验在打架 —— 该改配置，不是调高上限。
## `failure_tally` 汇总会指出是哪条规则在咬。
extends CliTool


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
	finish(0)


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
