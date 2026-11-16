## 319 D 批：见识阶梯与机制科技的校准台 —— 不开界面，直接拿 [RunState] 按几种玩法整局走（同一张种子表配对比较），
## 记每局的分数、分项、档位、见识，以及机制科技的额外奖励、换货用了没有。只出表，不改数。
##
## 玩法（[constant STRATEGIES]）：
## - rush：出生点直接去最近能用的撤离点（出生即撤的下限）；
## - tier1：一路清最近的点，估计撤离能到第一档（[member ScoreRules.insight_ladder] 第一档）就去撤离；
## - explore：一路清最近的点，体力剩三分之一或走满步数才去撤离（认真探索）；
## - explore_all：同 explore，但不看体力（挑战到底，会更常战败）。
##
## 机器人很笨：事件选第一个能选的、搜到搜不了、待拾取全拿（棋盘放不下的丢掉、地上的往棋盘上装）、不买东西、不合成、不求饶。
## 所以分数是「同样笨的玩家」之间的比较，不是真实玩家的分数；用来比档位门槛、比科技开没开，不用来定绝对值
class_name InsightBench
extends RefCounted

const STRATEGIES := ["rush", "tier1", "explore", "explore_all"]
## 一局最多走几步（防止机器人卡死在图上）
const MAX_STEPS := 120
const MAX_ACTIONS := 80
## explore：体力剩这么多（比例）就去撤离
const LOW_VITALITY := 0.34

## 机制树满树的局外 buff（每个节点最高级那份）
const FULL_MECH := [&"tech_pack_3", &"tech_thorough_search_2", &"tech_scouting_1", &"tech_bargain_1", &"tech_shop_refresh_1",
	&"tech_elite_bounty_1", &"tech_boss_bounty_1"]


## 整局走一遍。[param cfg]：{chapter, character, preset, difficulty, scale, seed, strategy, techs: Array[StringName]}。
## 返回一行：{seed, strategy, difficulty, techs, outcome, steps, actions, score, loot, battle, explore, lit, insight, insight_veteran,
## bounty, refresh_used, battles, elites, bosses, searches}
static func play(ctx: Dictionary, cfg: Dictionary) -> Dictionary:
	var ch := ContentPaths.load_asset("chapters", String(cfg.get("chapter", "free_mode"))) as ChapterDef
	var who := ContentPaths.load_asset("characters", String(cfg.get("character", "andreus"))) as CharacterDef
	var preset := ContentPaths.load_asset("loadouts", String(cfg.get("preset", "preset_offense"))) as LoadoutDef
	var diff := ContentPaths.load_asset("difficulties", String(cfg.get("difficulty", "normal"))) as DifficultyDef
	var kit: Array[StringName] = []
	if preset != null:
		kit.assign(preset.items)
	var techs: Array[StringName] = []
	techs.assign(cfg.get("techs", []))
	var s := RunState.start(ch, int(cfg.get("seed", 1)), ctx["items"], ctx["enemies"], ctx["sets"], kit, ctx["buffs"], techs, who, [],
		diff, ctx["hunters"], StringName(String(cfg.get("scale", ""))))
	var row := {"seed": int(cfg.get("seed", 1)), "strategy": String(cfg.get("strategy", "explore")), "difficulty": String(cfg.get("difficulty", "normal")),
		"techs": "full" if not techs.is_empty() else "none"}
	if s == null:
		row["outcome"] = "start_failed"
		return row
	s.event_defs = ctx["events"]
	if s.travel.current_id < 0 and not s.map.entry_ids.is_empty():
		s.pick_spawn(s.map.entry_ids[0])
	var stat := {"actions": 0, "bounty": 0, "refresh": 0}
	_settle(s, stat)
	var strategy := String(row["strategy"])
	var rules := ScoreRules.load_rules()
	var steps := 0
	var leaving := strategy == "rush"
	var guard := 0
	while not s.is_over() and steps < MAX_STEPS and guard < MAX_STEPS * 4:
		guard += 1
		if not leaving and _should_leave(s, strategy, rules):
			leaving = true
		var target := _nearest_exit(s) if leaving else _nearest_unvisited(s)
		if target < 0:
			if leaving:
				break     # 撤不了（都关了 / 付不起）：只能等结束
			leaving = true
			continue
		if target == s.travel.current_id:
			if not leaving:     # 站着的这个点内容没用完（出生点、没歇的休息点）：不算目标
				_skip[s.get_instance_id()] = _skip.get(s.get_instance_id(), []) + [target]
				continue
			if s.try_extract():
				break
			_closed_exits[s.get_instance_id()] = _closed_exits.get(s.get_instance_id(), []) + [target]
			continue
		var path := _path(s, s.travel.current_id, target)
		if path.is_empty() or not s.step_to(path[0]):
			_skip[s.get_instance_id()] = _skip.get(s.get_instance_id(), []) + [target]
			continue
		steps += 1
		if OS.has_environment("IB_TRACE"):
			print("  步 %d → %d（%s）体力 %d/%d" % [steps, path[0], s.map.get_node(path[0]).type, s.vitality.current, s.vitality.maximum])
		_settle(s, stat)
	var r := RunResult.settle(s) if s.is_over() else RunResult.estimate(s, false)     # 走不动了（撤离点都关了 / 卡住）：按倒下算
	var lit := _distinct_ids(s) if r.is_extracted() else 0
	var total := r.compute_score(lit, rules)
	var veteran := r.compute_score(0, rules)
	row.merge({"outcome": String(r.outcome) if s.is_over() else "stuck", "steps": steps, "actions": int(stat["actions"]), "score": total,
		"score_veteran": veteran, "lit": lit, "insight": rules.insight_for(total), "insight_veteran": rules.insight_for(veteran),
		"battles": r.battles_won, "elites": r.elite_won, "bosses": r.boss_won, "searches": r.searches,
		"bounty": _bounty_count(s), "refresh_used": int(stat["refresh"])})
	_closed_exits.erase(s.get_instance_id())
	_skip.erase(s.get_instance_id())
	s.dispose()
	return row


static var _closed_exits := {}
static var _skip := {}


## 撤离了的话图鉴新点亮几件：棋盘上不同的道具 id 数（新档：都算新点亮；老玩家看 score_veteran）
static func _distinct_ids(s: RunState) -> int:
	var ids := {}
	for v in s.board.items():
		ids[(v as ItemInstance).def.id] = true
	return ids.size()


## 这一局科技额外掉了几件（[member RunState.tally] 的 bounty）
static func _bounty_count(s: RunState) -> int:
	return int(s.tally.get("bounty", 0))


## 现在走是不是该去撤离了
static func _should_leave(s: RunState, strategy: String, rules: ScoreRules) -> bool:
	match strategy:
		"rush":
			return true
		"tier1":
			return RunResult.estimate(s).compute_score(_distinct_ids(s), rules) >= rules.insight_ladder[0] or _low(s)
		"explore":
			return _low(s)
	return false


static func _low(s: RunState) -> bool:
	return s.vitality != null and float(s.vitality.current) <= float(s.vitality.maximum) * LOW_VITALITY


## 最近的没去过的点（撤离点除外）；没有了返回 -1
static func _nearest_unvisited(s: RunState) -> int:
	var skip: Array = _skip.get(s.get_instance_id(), [])
	var dist := MapNavigator.distance_map(s.map, s.travel.current_id)
	var best := -1
	for id in s.map.node_ids():
		var n := s.map.get_node(id)
		if n.is_visited() or n.type == &"extract" or skip.has(id) or not dist.has(id):
			continue
		if best < 0 or int(dist[id]) < int(dist[best]) or (int(dist[id]) == int(dist[best]) and id < best):
			best = id
	return best


## 最近的还能撤的撤离点（关了的、付不起的跳过）
static func _nearest_exit(s: RunState) -> int:
	var closed: Array = _closed_exits.get(s.get_instance_id(), [])
	var dist := MapNavigator.distance_map(s.map, s.travel.current_id)
	var cd := CountdownModule.of(s)
	var best := -1
	for id in s.map.node_ids():
		var n := s.map.get_node(id)
		if NodeEvents.effective_type(n) != &"extract" or closed.has(id) or not dist.has(id):
			continue
		if cd != null and cd.extract_closed(n):
			continue
		if s.events.extract_fee(n) > s.wallet.balance:
			continue
		if best < 0 or int(dist[id]) < int(dist[best]) or (int(dist[id]) == int(dist[best]) and id < best):
			best = id
	return best


## 把眼下能处理的都处理掉（同 [SliceAudit] 的做法）：搜到底、事件选第一个能选的（撤离点上不选撤离）、开打、商店能换货就换一次再走、
## 待拾取全拿、地上的往棋盘上装
static func _settle(s: RunState, stat: Dictionary) -> void:
	for _k in MAX_ACTIONS:
		if s.is_over():
			return
		var ev := s.events
		if ev.current_search != null and ev.current_search.active:
			if ev.current_search.can_search():
				ev.current_search.search()
			else:
				ev.pause_search()
		elif ev.pending_event() != null:
			var picked := -1
			for i in ev.pending_event().options.size():
				if bool(ev.option_state(i)["ok"]):
					picked = i
					break
			if picked < 0 or not ev.choose(picked):
				return
		elif ev.pending_battle_node() != null:
			if not ev.start_pending_battle():
				return
		elif not ev.pending_ransom.is_empty():
			ev.refuse_ransom()
		elif ev.current_shop != null and ev.current_shop.active:
			if ev.current_shop.refresh():
				stat["refresh"] = int(stat["refresh"]) + 1
			ev.current_shop.leave()
		elif s.pending_loot != null:
			s.take_all_loot()
			if s.pending_loot != null:
				s.discard_loot()
		else:
			for inst in s.storage.items().duplicate():
				s.equip((inst as ItemInstance).uid)
			return
		stat["actions"] = int(stat["actions"]) + 1


## 从 [param from] 到 [param to] 的路：走过的点代价 1，没打过的战斗点（普通 / 精英 / BOSS）代价 10 —— 撤离路上能绕就绕
static func _path(s: RunState, from: int, to: int) -> Array[int]:
	var g := s.map
	var cost := {from: 0}
	var prev := {from: -1}
	var open: Array[int] = [from]
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if int(cost[open[i]]) < int(cost[open[bi]]) or (int(cost[open[i]]) == int(cost[open[bi]]) and open[i] < open[bi]):
				bi = i
		var here: int = open[bi]
		open.remove_at(bi)
		if here == to:
			break
		for nb in g.neighbors(here):
			var n := g.get_node(int(nb))
			var step := 10 if n != null and not n.is_visited() and int(nb) != to and NodeEvents.effective_type(n) in [&"battle", &"elite", &"core"] else 1
			var c := int(cost[here]) + step
			if not cost.has(int(nb)) or c < int(cost[int(nb)]):
				cost[int(nb)] = c
				prev[int(nb)] = here
				if not open.has(int(nb)):
					open.append(int(nb))
	var out: Array[int] = []
	if not prev.has(to):
		return out
	var at := to
	while at != from:
		out.push_front(at)
		at = int(prev[at])
	return out


## 内容（一次装好，各局共用）
static func content() -> Dictionary:
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	return {"items": items, "enemies": enemies, "sets": sets, "buffs": RunBuffs.load_all(), "events": EventPlacer.load_all(),
		"hunters": HunterSystem.load_all()}


## 汇总：按 (strategy, difficulty, techs) 分组，各组 0 / 1 / 2 / 3 点的局数、平均分、撤离率、平均步数、每步见识
static func summarize(rows: Array) -> Array[Dictionary]:
	var groups := {}
	for row in rows:
		var key := "%s|%s|%s" % [row["strategy"], row["difficulty"], row["techs"]]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(row)
	var keys := groups.keys()
	keys.sort()
	var out: Array[Dictionary] = []
	for key in keys:
		var g: Array = groups[key]
		var parts := String(key).split("|")
		var pts := [0, 0, 0, 0]
		var vet := [0, 0, 0, 0]
		var score := 0.0
		var won := 0
		var steps := 0.0
		var actions := 0.0
		var insight := 0.0
		var bounty := 0.0
		for row in g:
			pts[clampi(int(row.get("insight", 0)), 0, 3)] += 1
			vet[clampi(int(row.get("insight_veteran", 0)), 0, 3)] += 1
			score += float(row.get("score", 0))
			won += 1 if String(row.get("outcome", "")) == "extracted" else 0
			steps += float(row.get("steps", 0))
			actions += float(row.get("actions", 0)) + float(row.get("steps", 0))
			insight += float(row.get("insight", 0))
			bounty += float(row.get("bounty", 0))
		var n := float(g.size())
		out.append({"strategy": parts[0], "difficulty": parts[1], "techs": parts[2], "n": g.size(), "points": pts, "points_veteran": vet,
			"score": score / n, "extract_rate": won / n, "steps": steps / n, "insight": insight / n,
			"insight_per_100_actions": 100.0 * insight / maxf(1.0, actions), "bounty": bounty / n})
	return out


static func markdown(summary: Array[Dictionary], header: Array[String]) -> String:
	var lines: Array[String] = []
	lines.append_array(header)
	lines.append("")
	lines.append("| 玩法 | 难度 | 科技 | 局数 | 撤离率 | 平均分 | 0 / 1 / 2 / 3 点（新档） | 0 / 1 / 2 / 3 点（老玩家） | 平均见识 | 每百次操作见识 | 平均步数 | 额外奖励（件 / 局） |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
	for g in summary:
		lines.append("| %s | %s | %s | %d | %.0f%% | %.0f | %s | %s | %.2f | %.2f | %.1f | %.2f |" % [g["strategy"], g["difficulty"], g["techs"], g["n"],
			100.0 * float(g["extract_rate"]), g["score"], " / ".join(PackedStringArray((g["points"] as Array).map(func(x): return str(x)))),
			" / ".join(PackedStringArray((g["points_veteran"] as Array).map(func(x): return str(x)))), g["insight"], g["insight_per_100_actions"],
			g["steps"], g["bounty"]])
	return "\n".join(lines) + "\n"
