## 320（十档进阶 A10）：猎手追击加速在真实地图上多拦了几次。同一批种子、同一张图，开 / 不开追击各走一遍，
## 只走路和猎手回合（不触发点上的事、不扣时间以外的东西）：撞上一次按逃掉算（猎手歇几步），记接战次数。
## 两种走法：route = 不看猎手，一个接一个去最近的没去过的点；evade = 看得见全部猎手，挑离猎手最远的一步（同样远再朝目标走）。
## evade 的接战就是「躲也躲不开」的上界。只出表，不改数。
##
##     godot --headless --path . --script res://tools/bench_hunter_chase.gd -- [--seeds=40] [--scales=small,medium,large] [--base=ascension_9] [--chase=ascension_10] [--pcts=10,20] [--window=0]
extends CliTool


func run() -> void:
	var opts: Dictionary = split_args(OS.get_cmdline_user_args())["opts"]
	var seeds := int(opts.get("seeds", "40"))
	var scales := String(opts.get("scales", "small,medium,large")).split(",")
	var base := ContentPaths.load_asset("difficulties", String(opts.get("base", "ascension_9"))) as DifficultyDef
	var chase := ContentPaths.load_asset("difficulties", String(opts.get("chase", "ascension_10"))) as DifficultyDef
	var window := int(opts.get("window", str(chase.hunter_chase_window)))
	var pcts: Array[int] = [0, chase.hunter_chase_percent]
	for p in String(opts.get("pcts", "")).split(",", false):
		if not pcts.has(int(p)):
			pcts.append(int(p))
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", String(opts.get("chapter", "free_mode"))))
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var defs := HunterSystem.load_all()
	var head := "| 规模 | 走法 | 追击 | 有接战的局 | 每局接战 | 连着两步被拦 | 第一次接战（步） | 猎手原有移动 | 追击多走 | 多走 / 原有 |\n|---|---|---|---|---|---|---|---|---|---|"
	print(head)
	var md := head + "\n"
	for scale in scales:
		for policy in ["route", "evade"]:
			for pct in pcts:
				var agg := {"runs": 0, "hit": 0, "enc": 0, "back": 0, "first": 0, "first_n": 0, "moved": 0, "chased": 0}
				for i in seeds:
					var diff := base.duplicate(true) as DifficultyDef
					diff.hunter_chase_percent = pct
					diff.hunter_chase_window = window
					var r := _one(chapter, items, enemies, defs, diff, StringName(scale), 1000 + i * 7919, policy)
					if r.is_empty():
						continue
					agg["runs"] += 1
					agg["enc"] += int(r["enc"])
					agg["hit"] += 1 if int(r["enc"]) > 0 else 0
					agg["back"] += int(r["back"])
					agg["moved"] += int(r["moved"])
					agg["chased"] += int(r["chased"])
					if int(r["first"]) >= 0:
						agg["first"] += int(r["first"])
						agg["first_n"] += 1
				var n := maxi(1, int(agg["runs"]))
				var row := "| %s | %s | %d%% | %d / %d | %.2f | %d | %s | %.1f | %.1f | %.1f%% |\n" % [scale, policy, pct, agg["hit"], agg["runs"],
					float(agg["enc"]) / n, agg["back"], "%.1f" % (float(agg["first"]) / agg["first_n"]) if int(agg["first_n"]) > 0 else "—",
					float(agg["moved"]) / n, float(agg["chased"]) / n, 100.0 * float(agg["chased"]) / maxf(1.0, float(agg["moved"]))]
				print(row)     # 一行一行出（大图慢，跑到一半也看得到）
				md += row + "\n"
	finish(0 if md != "" else 1)


## 一局：走满这张图的步数上限（倒计时），返回 {enc, back, first, moved, chased}
func _one(chapter: ChapterDef, items: ItemDatabase, enemies: EnemyDatabase, defs: Dictionary, diff: DifficultyDef, scale: StringName, p_seed: int, policy: String) -> Dictionary:
	var rs := RunState.start(chapter, p_seed, items, enemies, null, [] as Array[StringName], {}, [] as Array[StringName], null, [], diff, defs, scale)
	if rs == null or rs.hunters == null:
		return {}
	rs.pick_spawn(rs.map.entry_ids[0])
	var cd := CountdownModule.of(rs)
	var limit := cd.left() if cd != null else 40
	var sys := rs.hunters
	var visited := {rs.travel.current_id: true}
	var enc_steps: Array[int] = []
	for step in range(1, limit + 1):
		var next := _pick(rs, visited, policy)
		if next < 0:
			break
		rs.travel.current_id = next
		rs.travel.clock.total += 1
		visited[next] = true
		sys.on_player_step()
		var uid := int(rs.events.pending.get("hunter", -1))
		if uid >= 0:
			enc_steps.append(step)
			var h := sys.by_uid(uid)
			if h != null:
				h.cooldown = maxi(0, sys.def_of(h).flee_cooldown)     # 按逃掉算
			rs.events.pending.clear()
	var moved := 0
	var chased := 0
	for h in sys.hunters:
		moved += h.moved
		chased += h.chased
	var back := 0
	for i in range(1, enc_steps.size()):
		if enc_steps[i] - enc_steps[i - 1] == 1:
			back += 1
	rs.dispose()
	return {"enc": enc_steps.size(), "back": back, "first": enc_steps[0] if not enc_steps.is_empty() else -1, "moved": moved, "chased": chased}


## 下一步：route 朝最近的没去过的点；evade 先看离猎手多远（离最近的猎手越远越好，够远就不管），再朝目标
func _pick(rs: RunState, visited: Dictionary, policy: String) -> int:
	var moves := rs.travel.available_moves()
	if moves.is_empty():
		return -1
	var here := MapNavigator.distance_map(rs.map, rs.travel.current_id)
	var target := -1
	for id in here.keys():
		if not visited.has(id) and (target < 0 or int(here[id]) < int(here[target]) or (int(here[id]) == int(here[target]) and id < target)):
			target = id
	var to_target := MapNavigator.distance_map(rs.map, target) if target >= 0 else {}
	var best := -1
	var best_score := -INF
	for m in moves:
		var score := -float(to_target.get(m, 99))
		if policy == "evade" and rs.hunters != null:
			var near := INF
			for h in rs.hunters.alive():
				near = minf(near, rs.hunters.metric.distance(h.node_id, m))
			score += minf(near, 4.0) * 100.0
		if score > best_score:
			best_score = score
			best = m
	return best
