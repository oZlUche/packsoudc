## 负重统计模拟（只读游戏代码，不改规则）：用真实的 GameFlow / RunState 跑自由模式多局，
## 一个「不看负重、只看价值」的机器人逐点搜刮，记下每局撤离前的负重 / 上限。
##
##   godot --headless --path . --script res://tools/sim/encumbrance_sim.gd -- <每组局数> <输出 jsonl>
##
## 机器人：
## - 路线：从出生点起，每次去最近的没去过的「有东西」的点（搜索 / 战斗 / 精英 / 宝箱 / 事件 / 随机），
##   倒计时剩的步数只够走到最近的撤离点（按当前的行动点倍率算）时转去撤离。
## - 战斗：玩家血量设成 10000（必赢），只看搜刮，不看打不打得过。
## - 搜索：能搜就搜满；事件：在能选的选项里随机挑。商店 / 休息 / 保险箱 / 神坛直接离开。
## - 拿东西：按「价值 / 格」从高到低往棋盘放；包有空位就拿；放不下时拿棋盘上价值 / 格最低的一两件换（换完更值钱才换）。
##   约束：武器至多 3 件（多了只换更值钱的武器）；防御道具（盾 / 防具）不足 2 件时优先拿，且不会被换到少于 2 件。
extends SceneTree

const FS = preload("res://tests/run/flow_support.gd")
const INTERESTING := [&"search", &"battle", &"elite", &"chest", &"event", &"random"]

var rng := RandomNumberGenerator.new()
var c: TestSupport.Content
var out_file: FileAccess
var want_extract := false
## greedy = 放得下就拿；picky = 白色（稀有度 0）的不拿（包、防御道具除外）
var policy := "greedy"
var last_snap := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var per_group := int(args[0]) if args.size() > 0 else 5
	var out_path := String(args[1]) if args.size() > 1 else "user://enc_sim.jsonl"
	var scales: Array = (String(args[2]) if args.size() > 2 else "small,medium").split(",")
	var policies: Array = (String(args[3]) if args.size() > 3 else "greedy,picky").split(",")
	c = TestSupport.load_content("free_mode", ["buffs", "events", "faiths", "recipes", "loadouts", "characters",
		"hunter_defs", "difficulties", "meta_rules"])
	out_file = FileAccess.open(out_path, FileAccess.WRITE)
	var loadout: LoadoutDef = null
	for l in c.loadouts:
		if l.id == &"standard":
			loadout = l
	for pol in policies:
		policy = pol
		for si in scales.size():
			for ci in c.characters.size():
				var ch: CharacterDef = c.characters[ci]
				if not [&"andreus", &"marcus", &"brutus"].has(ch.id):
					continue
				for i in per_group:
					var seed := 1000 + i * 7919 + si * 101 + ci * 13     # 两种拿法用同一组种子，好对照
					rng.seed = seed * 31 + 7
					var rec := _one_run(StringName(scales[si]), ch, loadout, seed)
					rec["policy"] = policy
					out_file.store_line(JSON.stringify(rec))
					out_file.flush()
					print("[sim] %s %s %s #%d -> %s/%s lv%d" % [policy, scales[si], ch.id, i, rec.get("weight"), rec.get("capacity"), rec.get("level")])
	out_file.close()
	quit(0)


func _one_run(scale: StringName, ch: CharacterDef, loadout: LoadoutDef, seed: int) -> Dictionary:
	var f := FS.flow(c, "encsim", 10000.0)
	var run := f.begin(c.chapter, loadout, seed, [] as Array[int], ch, [], null, scale)
	if run == null:
		return {"error": "no run", "scale": String(scale), "char": String(ch.id), "seed": seed}
	if run.travel.current_id < 0:
		var entries: Array = run.map.entry_ids
		f.pick_spawn(entries[rng.randi_range(0, entries.size() - 1)])
		_settle(f)
	var visited := {}
	var steps := 0
	var peak := 0.0
	var level_steps := [0, 0, 0, 0]
	var nodes_by_type := {}
	var guard := 0
	var extracted := false
	var snap := {}
	var why := "guard"
	want_extract = false
	last_snap = {}
	while not run.is_over() and guard < 400:
		guard += 1
		visited[run.travel.current_id] = true
		var cap := run.carry_capacity()
		var ratio := float(run.carry_weight()) / float(cap) if cap > 0 else 0.0
		peak = maxf(peak, ratio)
		var lv := run.encumbrance_level()
		level_steps[lv] += 1
		var cd := CountdownModule.of(run)
		var left := cd.left() if cd != null else 999
		var here := run.current_node()
		var ext := _nearest_extract(run)
		var mult := maxi(1, run.travel.action_cost_mult)
		var ext_cost := int(ext["dist"]) * mult if not ext.is_empty() else 999
		var target := -1
		if not ext.is_empty() and (want_extract or left <= ext_cost + 2 * mult):
			want_extract = true
			target = int(ext["id"])
		else:
			target = _nearest_target(run, visited)
			if target < 0 and not ext.is_empty():
				want_extract = true
				target = int(ext["id"])
		if target < 0:
			why = "no_target"
			break
		if target == run.travel.current_id:
			snap = _snapshot(run)
			extracted = f.extract()
			why = "extract_here"
			break
		var dist := MapNavigator.distance_map(run.map, target)
		var best := -1
		for nb in run.travel.available_moves():
			if dist.has(nb) and (best < 0 or int(dist[nb]) < int(dist[best])):
				best = nb
		if best < 0 or not f.step_to(best):
			why = "step_refused:%d screen%d" % [best, f.screen]
			break
		steps += 1
		var t := String(NodeEvents.effective_type(run.current_node())) if run.current_node() != null else ""
		if not visited.has(best):
			nodes_by_type[t] = int(nodes_by_type.get(t, 0)) + 1
		_settle(f)
	if run.phase == RunState.Phase.EXTRACTED:
		extracted = true
	if snap.is_empty():
		snap = last_snap if not last_snap.is_empty() else _snapshot(run)
	snap["scale"] = String(scale)
	snap["char"] = String(ch.id)
	snap["seed"] = seed
	snap["steps"] = steps
	snap["why"] = why if not run.is_over() else "over:%d" % run.phase
	snap["left"] = CountdownModule.of(run).left() if CountdownModule.of(run) != null else -1
	snap["extracted"] = extracted
	snap["peak_ratio"] = peak
	snap["level_steps"] = level_steps
	snap["nodes"] = nodes_by_type
	FS.cleanup("encsim")
	return snap


func _snapshot(run: RunState) -> Dictionary:
	var weapons := 0
	var defense := 0
	var precious := 0
	var precious_ids := []
	var bags := 0
	var by_tag := {}
	var items := []
	for inst in run.board.items():
		var d: ItemDef = (inst as ItemInstance).def
		var w := ItemWeight.of(d)
		items.append([String(d.id), w, d.rarity, d.cell_count(), d.is_bag, Array(d.tags).map(func(x): return String(x)), ItemValue.of(d)])
		if d.is_bag:
			bags += 1
			by_tag["bag"] = int(by_tag.get("bag", 0)) + w
			continue
		if d.tags.has(&"weapon"):
			weapons += 1
		if d.tags.has(&"shield") or d.tags.has(&"armor"):
			defense += 1
		if d.rarity >= 2:
			precious += 1
		var k := "other"
		for tag in [&"weapon", &"shield", &"armor", &"material", &"treasure", &"remedy", &"food"]:
			if d.tags.has(tag):
				k = String(tag)
				break
		by_tag[k] = int(by_tag.get(k, 0)) + w
	var cap := run.carry_capacity()
	return {"weight": run.carry_weight(), "capacity": cap, "ratio": float(run.carry_weight()) / float(cap) if cap > 0 else 0.0,
		"level": run.encumbrance_level(), "weapons": weapons, "defense": defense, "precious": precious, "bags": bags,
		"usable_cells": run.board.usable_cell_count(), "free_cells": run.board.free_cell_count(),
		"by_kind": by_tag, "items": items}


#region 走
func _nearest_target(run: RunState, visited: Dictionary) -> int:
	var dist := MapNavigator.distance_map(run.map, run.travel.current_id)
	var best := -1
	var best_d := 1 << 30
	for id in dist.keys():
		if visited.has(id) or id == run.travel.current_id:
			continue
		var node := run.map.get_node(id)
		if node == null or not INTERESTING.has(NodeEvents.effective_type(node)):
			continue
		var d := int(dist[id]) * 100 + rng.randi_range(0, 99)
		if d < best_d:
			best_d = d
			best = id
	return best


func _nearest_target_cost(run: RunState, visited: Dictionary) -> int:
	var t := _nearest_target(run, visited)
	if t < 0:
		return 999
	var dist := MapNavigator.distance_map(run.map, run.travel.current_id)
	return int(dist.get(t, 999)) * maxi(1, run.travel.action_cost_mult)


func _nearest_extract(run: RunState) -> Dictionary:
	var dist := MapNavigator.distance_map(run.map, run.travel.current_id)
	var cd := CountdownModule.of(run)
	var best := {}
	for id in dist.keys():
		var node := run.map.get_node(id)
		if node == null or NodeEvents.effective_type(node) != &"extract":
			continue
		if cd != null and cd.extract_closed(node):
			continue
		var fee := run.events.extract_fee(node)
		if fee > 0 and run.wallet != null and run.wallet.balance < fee:
			continue
		if best.is_empty() or int(dist[id]) < int(best["dist"]):
			best = {"id": id, "dist": int(dist[id])}
	return best
#endregion


#region 叠层
func _settle(f: GameFlow) -> void:
	var guard := 0
	while f.run != null and not f.run.is_over() and GameFlow.is_overlay(f.screen) and guard < 60:
		guard += 1
		_settle_one(f)


func _settle_one(f: GameFlow) -> void:
	var run := f.run
	match f.screen:
		GameFlow.Screen.PREBATTLE:
			# 必赢：只看搜刮。秒杀 = 按赢了收尾（掉落、进账照旧）
			if run.events.smite_pending_battle():
				f._flush()
			else:
				f.start_battle()
		GameFlow.Screen.LOOT:
			if run.pending_loot != null:
				_pick(run, run.pending_loot)
			f.discard_loot()
		GameFlow.Screen.SEARCH:
			var s := run.events.current_search
			if s != null:
				_pick(run, s.haul())
			if not f.close_search():
				f.resume()
		GameFlow.Screen.CHEST:
			if not f.open_chest():
				f.leave_chest()
		GameFlow.Screen.SHOP:
			if run.events.current_shop != null:
				run.events.current_shop.leave()
			f.resume()
		GameFlow.Screen.SAFE:
			f.close_safe()
		GameFlow.Screen.ALTAR:
			f.close_altar()
		GameFlow.Screen.EVENT:
			var def := run.events.pending_event()
			if def == null:
				f.resume()
				return
			var ok: Array[int] = []
			for i in def.options.size():
				if bool(run.events.option_state(i).get("ok", false)):
					ok.append(i)
			var sid := String(def.id)
			var pick := 0
			if sid.begins_with("extract"):
				if want_extract:
					last_snap = _snapshot(run)
				pick = 0 if want_extract else (1 if def.options.size() > 1 else 0)
			elif sid.begins_with("search_") or ok.is_empty():
				pick = 0 if (ok.is_empty() or ok.has(0)) else ok[0]
			else:
				pick = ok[rng.randi_range(0, ok.size() - 1)]
			if not f.choose_event(pick):
				if not f.hide_overlay():
					f.resume()
		_:
			if not f.hide_overlay():
				f.resume()
#endregion


#region 拿东西
static func _density(d: ItemDef) -> float:
	return float(ItemValue.of(d)) / float(maxi(1, d.cell_count()))


static func _is_def(d: ItemDef) -> bool:
	return d.tags.has(&"shield") or d.tags.has(&"armor")


func _count(run: RunState, pred: Callable) -> int:
	var n := 0
	for inst in run.board.items():
		if not (inst as ItemInstance).def.is_bag and pred.call((inst as ItemInstance).def):
			n += 1
	return n


func _pick(run: RunState, src: ItemContainer) -> void:
	if src == null:
		return
	var cands: Array = src.items().duplicate()
	var defs_now := _count(run, _is_def)
	cands.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		var ka := (1e9 if a.def.is_bag else 0.0) + (1e6 if (_is_def(a.def) and defs_now < 2) else 0.0) + _density(a.def)
		var kb := (1e9 if b.def.is_bag else 0.0) + (1e6 if (_is_def(b.def) and defs_now < 2) else 0.0) + _density(b.def)
		return ka > kb)
	for inst in cands:
		var it := inst as ItemInstance
		if not src.has_item(it.uid):
			continue
		var d := it.def
		if policy == "picky" and d.rarity <= 0 and not d.is_bag and not (_is_def(d) and _count(run, _is_def) < 2):
			continue
		if d.tags.has(&"weapon") and _count(run, func(x: ItemDef) -> bool: return x.tags.has(&"weapon")) >= 3:
			var worst := _worst(run, func(x: ItemDef) -> bool: return x.tags.has(&"weapon"))
			if worst == null or ItemValue.of(worst.def) >= ItemValue.of(d):
				continue
			run.board.remove(worst.uid)
			run.storage.admit(worst)
		if InventoryService.transfer_auto(src, it.uid, run.board):
			continue
		if d.is_bag:
			continue
		_try_swap(run, src, it)


## 棋盘上价值 / 格最低、可以换掉的一件（不是包、不让防御道具少于 2 件）
func _worst(run: RunState, pred: Callable = Callable()) -> ItemInstance:
	var defs := _count(run, _is_def)
	var worst: ItemInstance = null
	for inst in run.board.items():
		var it := inst as ItemInstance
		if it.def.is_bag or it.def.is_keepsake() or it.def.is_sealed():
			continue
		if pred.is_valid() and not pred.call(it.def):
			continue
		if _is_def(it.def) and defs <= 2:
			continue
		if worst == null or _density(it.def) < _density(worst.def):
			worst = it
	return worst


func _try_swap(run: RunState, src: ItemContainer, it: ItemInstance) -> void:
	var removed: Array[ItemInstance] = []
	var gain := float(ItemValue.of(it.def))
	for k in 3:
		var worst := _worst(run)
		if worst == null or _density(worst.def) >= _density(it.def):
			break
		var lost := 0.0
		for r in removed:
			lost += ItemValue.of(r.def)
		if lost + ItemValue.of(worst.def) >= gain:
			break
		run.board.remove(worst.uid)
		run.storage.admit(worst)
		removed.append(worst)
		if InventoryService.transfer_auto(src, it.uid, run.board):
			return
	for r in removed:
		InventoryService.transfer_auto(run.storage, r.uid, run.board)
#endregion
