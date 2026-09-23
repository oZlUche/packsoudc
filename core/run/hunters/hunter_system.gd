## 猎手系统（069 伪 PVP，报告 071）：一局里所有猎手的回合、领地、感知、开打、战败后果、存档。
##
## 由 [HunterMechanic]（难度清单里的一个机制）装进一局：`run.hunters`。玩家每走一步（[RunState.step_to] 末尾）它动一回合：
## 该出现的出现（默认在离玩家最远的点）→ 每个活着的猎手按行动逻辑走几小步（只在自己领地里、不进别人的领地）→
## 进了感知范围提示一次 → 距离 ≤ 开打距离就**开打前先过事件屏**（迎战 / 逃跑），走的是事件层那条路（`NodeEvents.pending` + 合成的 [EventDef]）。
## 迎战：按当时的探索度现造敌人（和随机点同一条路），打赢猎手死、掉落率乘 `drop_mult`；打输按定义里的后果构件依次执行。
## 逃跑：按成功率掷，逃掉猎手歇几步，没逃掉扣体力然后照打。
##
## 随机数走 `RunRNG` 的 `hunters` 流，读档接着走和没存过一样。本类不认识具体的行动逻辑与后果 —— 它们是构件。
class_name HunterSystem
extends RefCounted

signal spawned(h: Hunter)
signal moved(h: Hunter, from_id: int, to_id: int)
## 玩家进了它的感知范围（进入那一刻一次）
signal sensed(h: Hunter)
signal encounter(h: Hunter)
signal hunter_defeated(h: Hunter)
signal fled(h: Hunter, escaped: bool)
signal player_expelled(to_id: int)
signal changed()

const STREAM := &"hunters"
const ENCOUNTER_PREFIX := "hunter_encounter:"
const TYPE := &"hunter"

var run: RunState = null
var config: HunterMechanic = null
## id → HunterDef（持有方给）
var defs: Dictionary = {}
var metric: MapMetric = null
var hunters: Array[Hunter] = []
var has_spawned: bool = false
var _next_uid: int = 1


func setup(p_run: RunState, p_config: HunterMechanic, p_defs: Dictionary) -> void:
	run = p_run
	config = p_config
	defs = p_defs
	metric = MapMetric.new(run.map, config.metric if config != null else MapMetric.STEPS)
	if run.events != null:
		run.events.fight_hunter = fight
		run.events.flee_hunter = flee
		for id in defs:
			_encounter_def(defs[id])


#region 查询
func rng() -> RandomNumberGenerator:
	return run.rng.next(STREAM)


func step_count() -> int:
	return run.travel.clock.total if run.travel != null and run.travel.clock != null else 0


func player_node() -> int:
	return run.travel.current_id if run.travel != null else -1


func def_of(h: Hunter) -> HunterDef:
	return defs.get(h.def_id, null)


func by_uid(uid: int) -> Hunter:
	for h in hunters:
		if h.uid == uid:
			return h
	return null


func alive() -> Array[Hunter]:
	var out: Array[Hunter] = []
	for h in hunters:
		if h.alive:
			out.append(h)
	return out


func distance_to_player(h: Hunter) -> float:
	return metric.distance(h.node_id, player_node()) if player_node() >= 0 else INF


## 感知距离：定义里的数 × 上下文的倍率（角色技能、buff）
func sense_range(h: Hunter) -> float:
	var def := def_of(h)
	return (def.sense_range if def != null else 0.0) * run.buff_context().sense_mult


func senses_player(h: Hunter) -> bool:
	return distance_to_player(h) <= sense_range(h)


## 玩家现在看得见的：一直可见的、进了 near_range 的、进了侦察距离的（上下文的 scout_range）
func visible_hunters() -> Array[Hunter]:
	var out: Array[Hunter] = []
	var scout := run.buff_context().scout_range
	for h in alive():
		var def := def_of(h)
		if def == null:
			continue
		var d := distance_to_player(h)
		match def.visibility:
			HunterDef.Visibility.VISIBLE:
				out.append(h)
			HunterDef.Visibility.NEAR:
				if d <= maxf(def.near_range, scout):
					out.append(h)
			_:
				if scout > 0.0 and d <= scout:
					out.append(h)
	return out


func closest_to_player(options: Array[int], fallback: int) -> int:
	var best := fallback
	var best_d := metric.distance(fallback, player_node())
	for id in options:
		var d := metric.distance(id, player_node())
		if d < best_d:
			best = id
			best_d = d
	return best


func farthest_from_player(options: Array[int], fallback: int) -> int:
	var best := fallback
	var best_d := metric.distance(fallback, player_node())
	for id in options:
		var d := metric.distance(id, player_node())
		if d > best_d:
			best = id
			best_d = d
	return best


func random_of(options: Array[int]) -> int:
	return options[rng().randi_range(0, options.size() - 1)] if not options.is_empty() else -1


## 能走的相邻点：自己领地里的（领地空 = 整张图）、不是别人领地里的、没被别的猎手站着的
func allowed_moves(h: Hunter) -> Array[int]:
	var out: Array[int] = []
	for id in run.map.neighbors(h.node_id):
		if not h.territory.is_empty() and not h.territory.has(id):
			continue
		var blocked := false
		for other in alive():
			if other == h:
				continue
			if other.node_id == id or (not other.territory.is_empty() and other.territory.has(id)):
				blocked = true
				break
		if not blocked:
			out.append(id)
	return out
#endregion


#region 回合
## 玩家走完一步：出现、移动、感知、开打
func on_player_step() -> void:
	if run == null or run.is_over() or player_node() < 0:
		return
	if not has_spawned and step_count() >= (config.spawn_after_steps if config != null else 0):
		spawn()
	for h in alive():
		if h.cooldown > 0:
			h.cooldown -= 1
			continue
		_move(h)
	_update_sense()
	check_engagement()
	changed.emit()


## 出现：数量按地图规模，位置默认离玩家（和已出现的猎手）最远、且离玩家至少 spawn_min_distance
func spawn() -> void:
	has_spawned = true
	if config == null or config.hunter_ids.is_empty() or defs.is_empty():
		return
	var count := config.count_for(run.scale_id())
	var taken: Array[int] = [player_node()]
	for i in count:
		var def: HunterDef = defs.get(config.hunter_ids[i % config.hunter_ids.size()], null)
		if def == null:
			continue
		var home := _farthest_node(taken, config.spawn_min_distance)
		if home < 0:
			break
		var h := Hunter.new()
		h.uid = _next_uid
		_next_uid += 1
		h.def_id = def.id
		h.node_id = home
		h.home_id = home
		h.territory = _territory_around(home, def.territory_radius)
		hunters.append(h)
		taken.append(home)
		spawned.emit(h)


## 离 [param taken] 里每个点都最远的点（比较的是到它们的最小距离），且离玩家至少 [param min_from_player]；没有满足的就放宽
func _farthest_node(taken: Array[int], min_from_player: float) -> int:
	var best := -1
	var best_d := -1.0
	var relaxed := -1
	var relaxed_d := -1.0
	for id in run.map.node_ids():
		if taken.has(id):
			continue
		var d := INF
		for t in taken:
			d = minf(d, metric.distance(id, t))
		if d > relaxed_d:
			relaxed = id
			relaxed_d = d
		if metric.distance(id, player_node()) >= min_from_player and d > best_d:
			best = id
			best_d = d
	return best if best >= 0 else relaxed


func _territory_around(home: int, radius: float) -> Array[int]:
	var out: Array[int] = []
	if radius <= 0.0:
		return out
	for id in run.map.node_ids():
		if metric.distance(home, id) <= radius:
			out.append(id)
	return out


func _move(h: Hunter) -> void:
	var def := def_of(h)
	if def == null or h.guarding:
		return
	for i in maxi(0, def.speed):
		var options := allowed_moves(h)
		var next := def.behavior.next_node(h, self, options) if def.behavior != null else h.node_id
		if next == h.node_id or not options.has(next):
			break
		var from := h.node_id
		h.node_id = next
		moved.emit(h, from, next)


func _update_sense() -> void:
	for h in alive():
		var now := senses_player(h)
		if now and not h.sensed:
			sensed.emit(h)
		h.sensed = now


## 有猎手够得着玩家就开打前过事件屏。玩家正忙（等着选的事件、开着的会话）时不打扰，等空了再问（[RunState.poke_hunters]）
func check_engagement() -> bool:
	if run == null or run.is_over() or run.events == null or player_node() < 0:
		return false
	if not run.events.pending.is_empty() or run.events.current_search != null or run.events.current_shop != null:
		return false
	for h in alive():
		var def := def_of(h)
		if def == null or h.cooldown > 0:
			continue
		if distance_to_player(h) <= def.engage_range:
			_engage(h, def)
			return true
	return false


func _engage(h: Hunter, def: HunterDef) -> void:
	var node := run.current_node()
	var ev := _encounter_def(def)
	run.events.pending = {"node": node.id, "event": String(ev.id), "type": String(TYPE), "hunter": h.uid}
	run.events.event_pending.emit(node, ev)
	encounter.emit(h)


## 开打前的事件屏：迎战 / 逃跑（逃不掉的猎手没有第二项）。合成一次、登记在 NodeEvents.extra_defs 里（跟着 id 存档也找得回来）
func _encounter_def(def: HunterDef) -> EventDef:
	var id := StringName(ENCOUNTER_PREFIX + String(def.id))
	if run.events.extra_defs.has(id):
		return run.events.extra_defs[id]
	var ev := EventDef.new()
	ev.id = id
	ev.title = def.display_name if def.display_name != "" else String(def.id)
	ev.text = def.description if def.description != "" else "它盯上了你。"
	var fight_opt := EventOption.new()
	fight_opt.label = "迎战"
	fight_opt.outcomes.append(HunterFight.new())
	ev.options.append(fight_opt)
	if def.can_flee():
		var flee_opt := EventOption.new()
		flee_opt.label = "逃跑（%.0f%%）" % (clampf(def.flee_chance + run.buff_context().flee_bonus, 0.0, 1.0) * 100.0)
		flee_opt.outcomes.append(HunterFlee.new())
		ev.options.append(flee_opt)
	run.events.extra_defs[id] = ev
	return ev
#endregion


#region 开打与后果
## 迎战：按当时的探索度现造敌人、打一场。返回赢没赢
func fight(node: MapNode, uid: int, _ctx: EventContext) -> bool:
	var h := by_uid(uid)
	var def := def_of(h) if h != null else null
	if h == null or def == null:
		return false
	var content := build_content(h, node)
	if content.is_empty():
		return false
	run.events.last_handled_id = node.id
	var loot_ctx := run._loot_context()
	loot_ctx.drop_mult *= def.drop_mult
	var won := run.events.fight_content(node, TYPE, content, loot_ctx)
	if won:
		h.alive = false
		hunter_defeated.emit(h)
	else:
		for o in def.loss_outcomes:
			if run.is_over():
				break
			var outcome := o as HunterLossOutcome
			if outcome != null:
				outcome.apply(h, self)
	changed.emit()
	return won


## 逃跑：掷成功率。逃掉它歇几步；没逃掉扣体力，调用方接着开打。返回逃没逃掉
func flee(_node: MapNode, uid: int, ctx: EventContext) -> bool:
	var h := by_uid(uid)
	var def := def_of(h) if h != null else null
	if h == null or def == null:
		return false
	var chance := clampf(def.flee_chance + run.buff_context().flee_bonus, 0.0, 1.0)
	var escaped := rng().randf() < chance
	if escaped:
		h.cooldown = maxi(0, def.flee_cooldown)
		ctx.log.append("你甩开了它。")
	else:
		ctx.log.append("没甩开。")
		if def.flee_fail_vitality > 0:
			spend_vitality(def.flee_fail_vitality)
			ctx.spent += def.flee_fail_vitality
	fled.emit(h, escaped)
	changed.emit()
	return escaped


## 猎手的敌人内容：从它指定的池（或这一章的池）按强度规则现造，探索度就是现在的
func build_content(h: Hunter, node: MapNode) -> Dictionary:
	var def := def_of(h)
	var pool: EnemyPool = run.pool_by_id(def.enemy_pool) if def != null and def.enemy_pool != &"" else run.pool
	if def == null or pool == null or run.enemies == null or run.items == null:
		return {}
	var view := MapNode.from_dict(node.to_dict())
	view.type = &"battle"
	var depth := float(EnemyPlacer.depths_of(run.map).get(node.id, 0.0))
	var rule: StrengthRule = def.strength_rule if def.strength_rule != null else pool.strength_rule
	var raw := rule.wanted(view, depth, run.chapter.difficulty, run.scale_id(), run.events.exploration()) if rule != null else 0
	var wanted := pool.clamp_strength(raw)
	var r := rng()
	var entry := EnemyPlacer.pick(pool, run.enemies, view, wanted, r)
	if entry == null:
		return {}
	var built := EnemyPlacer.build_content(run.enemies.enemy(entry.enemy), pool, run.items, wanted, r)
	return built.get("content", {})     # build_content 的回报是 {content, dropped}，和 NodeEvents._enemy_for 一样只取内容


func spend_vitality(amount: int) -> void:
	if run.vitality == null or amount <= 0:
		return
	run.vitality.spend(amount, TYPE)
	if run.vitality.is_depleted():
		run.events.defeated.emit(TYPE)


func kill_player() -> void:
	run.events.defeated.emit(TYPE)


func remove(h: Hunter) -> void:
	h.alive = false


func retreat(h: Hunter, steps: int, cooldown: int) -> void:
	for i in maxi(0, steps):
		var options := allowed_moves(h)
		if options.is_empty():
			break
		var next := farthest_from_player(options, h.node_id)
		if next == h.node_id:
			break
		var from := h.node_id
		h.node_id = next
		moved.emit(h, from, next)
	h.cooldown = maxi(h.cooldown, cooldown)


## 把玩家赶回上一个点（不花行动点、不触发那个点的事）
func expel_player() -> void:
	var hist := run.travel.history
	if hist.size() < 2:
		return
	var to := hist[hist.size() - 2]
	run.travel.current_id = to
	hist.append(to)
	player_expelled.emit(to)
#endregion


#region 存档
func to_dict() -> Dictionary:
	var list: Array = []
	for h in hunters:
		list.append(h.to_dict())
	return {"spawned": has_spawned, "next_uid": _next_uid, "hunters": list}


func restore(d: Dictionary) -> void:
	has_spawned = bool(d.get("spawned", false))
	_next_uid = int(d.get("next_uid", 1))
	hunters.clear()
	for row in d.get("hunters", []):
		if row is Dictionary:
			hunters.append(Hunter.from_dict(row))
#endregion


## 全部猎手定义（id → HunterDef）
static func load_all() -> Dictionary:
	var out := {}
	var dir := DirAccess.open(ContentPaths.HUNTERS)
	if dir == null:
		return out
	var names: Array[String] = []
	for f in dir.get_files():
		var n := f.trim_suffix(".remap")
		if n.ends_with(".tres") or n.ends_with(".res"):
			names.append(n)
	names.sort()
	for n in names:
		var res := load(ContentPaths.HUNTERS + "/" + n)
		if res is HunterDef:
			out[(res as HunterDef).id] = res
	return out
