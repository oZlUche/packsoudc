## 372（作者定）：局内成长 —— 经验值、等级、每级三选一的牌。规矩与牌池在 [LevelRules]（`base_rules/level.json`）。
##
## - **经验值**只涨不花（原来的信力，作者 22:02 改名）。通用来源在这里接：打赢战斗（普通 / 精英 / 猎手 / 首领各给各的，秒杀不算打了一场）、
##   第一次到达更深一环、神坛祷告（[method pray]）；神坛献祭由 [AltarModule] 记、各位神的事由 [FaithPower] 记，都经 [method gain]。
##   所有途径都乘难度系数（[method LevelRules.mult]）。
## - **等级**按累计经验值算（[method LevelRules.level_of]），封顶 30。每升一级欠一次选牌；**不奉神（【以人为本】）的人逢 5 级多欠一次**
##   （到那一级时看有效信仰，记在 [member bonus_picks]）。
## - **选牌**：回到地图时界面按 [method pending] 弹出，三张一起出（[method offer]），挑一张（[method pick]）。同一张可以重复拿，拿几次就叠几层；
##   「拿过就不再出」的（元素回响本体）拿过就换成两张后续牌。**刷新**（三张一起换）、**删除**（这一局不再出，空位当场补一张）的次数
##   由局外科技给（[member RunContext.level_rerolls] / [member RunContext.level_removals]），一局用完为止。
## - 出牌用这一局的种子派生（第几次抽 = [member draws]），抽出来的那三张进存档：读档回来还是这三张，刷新出的下一批也由种子定，读档刷不了牌。
## - 拿到的牌是一局的 buff（[method defs]，[method RunState.active_buff_defs] 并进去）：战斗属性、按件修饰、负重、休息都走原来那条路。
##   体力上限当场加（开局才算一次的那个数）；「下一次搜索多翻一件」攒着、下一个搜索点用掉；元素回响按拿过几张现拼一条战斗规则。
##
## 第一批（报告 372 §六）：只有通用池，奉不奉神三张都是通用牌；神的牌池、逢 5 级的质变三选一在第二批
class_name LevelModule
extends RunModule

const ID := &"level"
## 经验值的来源（记进 [member history]，结算与开发模式的 CSV 读）
const SRC_BATTLE := &"battle"
const SRC_DEPTH := &"depth"
const SRC_OFFERING := &"offering"
const SRC_PRAYER := &"prayer"
const SRC_FAITH := &"faith"
const SRC_EVENT := &"event"
## 元素回响拼出来的那份 buff 的 id（不进内容表，界面按它认）
const ECHO_BUFF := &"card_element_echo"

## 经验值、等级、待选的牌、选了牌 —— 有变化就发（界面重画）
signal level_changed()
## 升了一级（一次升几级发几次）
signal leveled(level: int)
## 挑了一张牌
signal picked(card_id: StringName)

## 累计经验值（乘过难度系数；小数照留，界面取整）
var xp: float = 0.0
## 已经选过几次牌
var picks_done: int = 0
## 【以人为本】逢 5 级多欠的那几次
var bonus_picks: int = 0
## 哪几级给过以人为本的那一次（升序；[member bonus_picks] = 它的长度）。判断「这一张是不是多给的那次」用它
var bonus_levels: Array[int] = []
## 已经结算到第几级（多欠的那一次只在跨过那一级时给一回）
var level_seen: int = 1
## 拿过的牌：id → 几张
var taken: Dictionary = {}
## 这一局删掉的牌（不再出）
var removed: Array[String] = []
## 现在摆着的三张（空 = 没在选，或者还没抽）
var offer_ids: Array[String] = []
## 一共抽过几次（种子的一部分）
var draws: int = 0
var rerolls_used: int = 0
var removals_used: int = 0
## 到过的最深一环（-1 = 还没记开局那一环）
var depth_reached: int = -1
## 攒着的「下一次搜索多翻一件」
var pending_searches: int = 0
## 每一笔经验值：{step, source, gained, total, level}
var history: Array[Dictionary] = []

var _echo: RunBuffDef = null
var _echo_key := ""


static func of(run: RunState) -> LevelModule:
	return run.module(ID) as LevelModule if run != null else null


func id() -> StringName:
	return ID


func run_state() -> RunState:
	return _run


func rules() -> LevelRules:
	return LevelRules.load_rules()


func install(run: RunState) -> void:
	if run == null:
		return
	_run = run
	run.hooks.register(&"level_pray", pray)
	run.hooks.register(&"level_prayers_left", prayers_left)
	run.hooks.register(&"level_gain", func(n: int) -> int: return roundi(gain(float(n), SRC_EVENT)))
	if run.events != null:
		if not run.events.battle_finished.is_connected(_on_battle):
			run.events.battle_finished.connect(_on_battle)
		if not run.events.search_opened.is_connected(_on_search_opened):
			run.events.search_opened.connect(_on_search_opened)
	if run.travel != null and not run.travel.moved.is_connected(_on_moved):
		run.travel.moved.connect(_on_moved)
	if depth_reached < 0:
		var here := run.current_node() if run.map != null and run.travel != null else null
		depth_reached = here.tier if here != null else 0


#region 经验值与等级
func level() -> int:
	return rules().level_of(xp)


## 这一级已经攒了几点、升下一级一共要几点；满级 [总, 0]
func progress() -> Vector2i:
	var r := rules()
	var lv := level()
	if lv >= r.level_cap:
		return Vector2i(int(xp), 0)
	return Vector2i(int(xp + 0.0001) - r.total_for(lv), r.cost_at(lv))


## 难度系数（这一局的难度档）
func mult() -> float:
	var tier := _run.difficulty.level if _run != null and _run.difficulty != null else 0
	return rules().mult(tier)


## 加经验值：[param raw] 是没乘难度系数的数。返回实际加了多少（乘过的）
func gain(raw: float, source: StringName, detail: String = "") -> float:
	if raw <= 0.0:
		return 0.0
	var got := raw * mult()
	var before := level()
	xp += got
	var step := 0
	if _run != null and _run.travel != null and _run.travel.clock != null:
		step = _run.travel.clock.total
	history.append({"step": step, "source": String(source) + (":" + detail if detail != "" else ""),
		"gained": snappedf(got, 0.01), "total": snappedf(xp, 0.01), "level": level()})
	var after := level()
	for lv in range(before + 1, after + 1):
		_on_level(lv)
	level_changed.emit()
	return got


func _on_level(lv: int) -> void:
	if lv <= level_seen:
		return
	level_seen = lv
	var every := rules().extra_pick_every
	if every > 0 and lv % every == 0 and _humanist():
		bonus_levels.append(lv)
		bonus_picks = bonus_levels.size()     # 【以人为本】：这一级连选两次
	leveled.emit(lv)


## 【以人为本】：此刻没有有效信仰
func _humanist() -> bool:
	return _run == null or _run.active_faith_id() == &""


func is_humanist() -> bool:
	return _humanist()
#endregion


#region 选牌
## 还欠几次选牌
func pending() -> int:
	return maxi(0, level() - 1 + bonus_picks - picks_done)


## 选牌按级排队：每级一次，以人为本的那一级紧跟着多一次。返回现在这一张是第几级的、是不是多给的那次
## （{level, extra}；不欠选牌 = {}）
func current_pick() -> Dictionary:
	if pending() <= 0:
		return {}
	var n := 0
	for lv in range(2, level() + 1):
		var times := 1 + bonus_levels.count(lv)
		for k in times:
			if n == picks_done:
				return {"level": lv, "extra": k > 0}
			n += 1
	return {"level": level(), "extra": false}


func rerolls_left() -> int:
	var ctx := _run.buff_context() if _run != null else RunContext.new()
	return maxi(0, ctx.level_rerolls - rerolls_used)


func removals_left() -> int:
	var ctx := _run.buff_context() if _run != null else RunContext.new()
	return maxi(0, ctx.level_removals - removals_used)


## 现在摆着的三张（欠着选牌又还没抽就现抽）。不欠 = 空
func offer() -> Array[StringName]:
	if pending() <= 0:
		if not offer_ids.is_empty():
			offer_ids.clear()
		return [] as Array[StringName]
	if offer_ids.is_empty():
		offer_ids = _draw(rules().choices, [])
	var out: Array[StringName] = []
	for s in offer_ids:
		out.append(StringName(s))
	return out


## 挑第 [param i] 张。返回挑中的 id（挑不了 = 空）
func pick(i: int) -> StringName:
	var cards := offer()
	if i < 0 or i >= cards.size():
		return &""
	var cid := cards[i]
	taken[String(cid)] = count_of(cid) + 1
	picks_done += 1
	offer_ids.clear()
	_apply_now(cid)
	picked.emit(cid)
	level_changed.emit()
	return cid


## 刷新：三张一起换一批（尽量不和这三张重样）。次数不够返回 false
func reroll() -> bool:
	var cards := offer()
	if cards.is_empty() or rerolls_left() <= 0:
		return false
	rerolls_used += 1
	var avoid: Array[String] = offer_ids.duplicate()
	offer_ids = _draw(rules().choices, avoid)
	level_changed.emit()
	return true


## 删除第 [param i] 张：这一局不再出，空位当场补一张（这一级照常选）。次数不够返回 false
func remove(i: int) -> bool:
	var cards := offer()
	if i < 0 or i >= cards.size() or removals_left() <= 0:
		return false
	removals_used += 1
	var gone := offer_ids[i]
	removed.append(gone)
	var keep: Array[String] = offer_ids.duplicate()
	keep.remove_at(i)
	var fill := _draw(1, keep)
	if fill.is_empty() or keep.has(fill[0]):     # 池里没别的了：空着，不和留下的重样
		offer_ids.remove_at(i)
	else:
		offer_ids[i] = fill[0]
	level_changed.emit()
	return true


func count_of(card_id: StringName) -> int:
	return int(taken.get(String(card_id), 0))


## 拿过的牌（按拿的张数从多到少，同样多按 id）：[{id, count}]
func taken_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in taken:
		out.append({"id": StringName(String(k)), "count": int(taken[k])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["count"]) > int(b["count"]) if int(a["count"]) != int(b["count"]) else String(a["id"]) < String(b["id"]))
	return out


## 这张牌现在能不能出（不管抽没抽到）
func eligible(card_id: StringName) -> bool:
	var r := rules()
	var row := r.card(card_id)
	if row.is_empty() or removed.has(String(card_id)):
		return false
	if _run != null and not _run.buff_defs.is_empty() and not _run.buff_defs.has(card_id):
		return false
	if bool(row.get("once", false)) and count_of(card_id) > 0:
		return false
	var after := String(row.get("after", ""))
	if after != "" and count_of(StringName(after)) <= 0:
		return false
	if String(row.get("echo", "")) == String(LevelRules.ECHO_FASTER) and echo_seconds() <= r.echo_min_seconds:
		return false     # 间隔到下限了，再出就是白拿
	return _requires_met(StringName(String(row.get("requires", ""))))


func _requires_met(req: StringName) -> bool:
	if req == &"" or _run == null or _run.board == null:
		return true
	for raw in _run.board.items():
		var inst := raw as ItemInstance
		if inst == null or inst.def == null:
			continue
		match req:
			LevelRules.REQ_WEAPON:
				if inst.def.has_tag(&"weapon"):
					return true
			LevelRules.REQ_ELEMENT:
				if not inst.def.applies.is_empty() or inst.def.has_tag(&"staff"):
					return true
			_:
				if inst.def.has_tag(req):
					return true
	return false


## 抽 [param n] 张不重样的（不抽 [param avoid] 里的；能出的不够就有几张给几张，避开的也拿来补）
func _draw(n: int, avoid: Array[String]) -> Array[String]:
	var r := rules()
	var pool: Array[String] = []
	var spare: Array[String] = []
	for cid in r.card_ids():
		if not eligible(cid):
			continue
		if avoid.has(String(cid)):
			spare.append(String(cid))
		else:
			pool.append(String(cid))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:level_cards:%d" % [_run.run_seed if _run != null else 0, draws])
	draws += 1
	var out: Array[String] = []
	for src in [pool, spare]:
		var left: Array[String] = (src as Array[String]).duplicate()
		while out.size() < n and not left.is_empty():
			var total := 0.0
			for cid in left:
				total += maxf(0.0, r.weight_of(StringName(cid)))
			var roll := rng.randf() * total
			var at := left.size() - 1
			for j in left.size():
				roll -= maxf(0.0, r.weight_of(StringName(left[j])))
				if roll < 0.0:
					at = j
					break
			out.append(left[at])
			left.remove_at(at)
	return out


## 拿牌那一下就要算的：体力上限（开局算一次的数）、攒「下一次搜索」
func _apply_now(cid: StringName) -> void:
	var row := rules().card(cid)
	if String(row.get("oneshot", "")) == String(LevelRules.ONESHOT_SEARCH):
		pending_searches += 1
	var def: RunBuffDef = _run.buff_defs.get(cid, null) if _run != null else null
	if def == null or _run.vitality == null:
		return
	for e in def.effects:
		if e is VitalityMaxBonus:
			var add := (e as VitalityMaxBonus).amount
			if add > 0:
				_run.vitality.set_max(_run.vitality.maximum + add, &"level_card")
#endregion


#region 牌的效果
## 拿到的牌合起来的 buff（一张一份，拿几张给几份；元素回响拼成一份；一次性的不算）
func defs() -> Array:
	var out: Array = []
	if _run == null:
		return out
	var r := rules()
	for cid in r.card_ids():
		var n := count_of(cid)
		if n <= 0:
			continue
		var row := r.card(cid)
		if String(row.get("echo", "")) != "" or String(row.get("oneshot", "")) != "":
			continue
		var def: RunBuffDef = _run.buff_defs.get(cid, null)
		if def == null:
			continue
		for _i in n:
			out.append(def)
	var echo := echo_def()
	if echo != null:
		out.append(echo)
	return out


## 牌面上的那一行：普通牌照 buff 的效果说明；元素回响和一次性的牌效果在这里拼，文案写在代码里
func card_text(card_id: StringName) -> String:
	var r := rules()
	var row := r.card(card_id)
	match String(row.get("echo", "")):
		"body":
			return UiText.t("level.echo_body") % [echo_stacks(), echo_seconds()]
		"faster":
			return UiText.t("level.echo_faster") % [r.echo_min_seconds, echo_seconds()]
		"stacks":
			return UiText.t("level.echo_stacks") % echo_stacks()
	if String(row.get("oneshot", "")) == String(LevelRules.ONESHOT_SEARCH):
		return UiText.t("level.next_search")
	var def: RunBuffDef = _run.buff_defs.get(card_id, null) if _run != null else null
	return def.summary() if def != null else ""


## 元素回响现在每几秒一次
func echo_seconds() -> int:
	var r := rules()
	return maxi(r.echo_min_seconds, r.echo_seconds - _echo_count(LevelRules.ECHO_FASTER))


## 元素回响现在多几层
func echo_stacks() -> int:
	return 1 + _echo_count(LevelRules.ECHO_STACKS)


func _echo_count(kind: StringName) -> int:
	var r := rules()
	var n := 0
	for cid in r.card_ids():
		if String(r.card(cid).get("echo", "")) == String(kind):
			n += count_of(cid)
	return n


## 元素回响拼成的那份 buff（没拿本体 = null）：「每 N 秒，下一次施加的元素印多 M 层」
func echo_def() -> RunBuffDef:
	if _echo_count(LevelRules.ECHO_BODY) <= 0:
		return null
	var key := "%d:%d" % [echo_seconds(), echo_stacks()]
	if _echo != null and _echo_key == key:
		return _echo
	var trig := OnStatusApplied.new()
	trig.on_self = false
	trig.by_self = true
	var cad := CooldownCadence.new()
	cad.seconds = float(echo_seconds())
	cad.use_haste = false
	var eff := EchoStatus.new()
	eff.stacks = echo_stacks()
	var rule := AbilityRule.new()
	rule.trigger = trig
	rule.cadence = cad
	rule.effects.append(eff)
	var def := RunBuffDef.new()
	def.id = ECHO_BUFF
	var src: RunBuffDef = _run.buff_defs.get(ECHO_BUFF, null) if _run != null else null
	if src != null:
		def.display_name = src.display_name
		def.display_names = src.display_names.duplicate()
	def.rules.append(rule)
	_echo = def
	_echo_key = key
	return def
#endregion


#region 神坛祷告
## 这座神坛还能祷告几次
func prayers_left(node: MapNode) -> int:
	if node == null:
		return 0
	return maxi(0, rules().prayers_per_altar - int(node.content.get("altar_prayers", 0)))


## 祷告一次（行动点由事件的 `pass_time` 扣）：给经验值，返回加了多少（乘过的，取整）
func pray(node: MapNode) -> int:
	if prayers_left(node) <= 0:
		return 0
	node.content["altar_prayers"] = int(node.content.get("altar_prayers", 0)) + 1
	return roundi(gain(rules().prayer, SRC_PRAYER))


## 神坛献祭的经验值：每座神坛最多 [member LevelRules.offering_cap] 点（没乘系数的数）。返回乘过之后加了多少
func offer_at(node: MapNode, raw: int) -> float:
	var room := rules().offering_cap
	if node != null:
		room -= int(node.content.get("altar_offered", 0))
	var got := mini(raw, maxi(0, room))
	if got <= 0:
		return 0.0
	if node != null:
		node.content["altar_offered"] = int(node.content.get("altar_offered", 0)) + got
	return gain(got, SRC_OFFERING)
#endregion


func _on_battle(_n: MapNode, _r: BattleResult, won: bool) -> void:
	if not won or _run == null or _run.events == null:
		return
	var last: Dictionary = _run.events.last_battle
	if bool(last.get("smite", false)):
		return     # 秒杀不算打了一场
	var kind := StringName(String(last.get("type", "battle")))
	gain(rules().battle_xp(kind), SRC_BATTLE, String(kind))


func _on_moved(intent: MoveIntent, _first: bool) -> void:
	if _run == null or _run.map == null or not _run.map.has_node(intent.to_id):
		return
	var tier := _run.map.get_node(intent.to_id).tier
	if tier > depth_reached:
		var rings := tier - maxi(0, depth_reached)
		depth_reached = tier
		gain(rules().depth * rings, SRC_DEPTH)


func _on_search_opened(_n: MapNode, session: SearchSession) -> void:
	if session != null and pending_searches > 0:
		session.extra_searches += pending_searches
		pending_searches = 0
		level_changed.emit()


func to_dict() -> Dictionary:
	return {"xp": xp, "picks_done": picks_done, "bonus_picks": bonus_picks, "bonus_levels": bonus_levels.duplicate(), "level_seen": level_seen,
		"taken": taken.duplicate(), "removed": removed.duplicate(), "offer": offer_ids.duplicate(), "draws": draws,
		"rerolls_used": rerolls_used, "removals_used": removals_used, "depth_reached": depth_reached,
		"pending_searches": pending_searches, "history": history.duplicate(true)}


func restore(d: Dictionary) -> void:
	xp = maxf(0.0, float(d.get("xp", 0.0)))
	picks_done = maxi(0, int(d.get("picks_done", 0)))
	bonus_picks = maxi(0, int(d.get("bonus_picks", 0)))
	bonus_levels.clear()
	for v in d.get("bonus_levels", []):
		bonus_levels.append(int(v))
	if bonus_levels.size() < bonus_picks:     # 早一点的档只记了次数：按逢 n 级补上是哪几级
		var every := maxi(1, rules().extra_pick_every)
		bonus_levels.clear()
		for k in bonus_picks:
			bonus_levels.append(every * (k + 1))
	bonus_picks = bonus_levels.size()
	level_seen = maxi(1, int(d.get("level_seen", rules().level_of(xp))))
	taken.clear()
	var t: Variant = d.get("taken", {})
	if t is Dictionary:
		for k in t:
			if int(t[k]) > 0:
				taken[String(k)] = int(t[k])
	removed.clear()
	for s in d.get("removed", []):
		removed.append(String(s))
	offer_ids.clear()
	for s in d.get("offer", []):
		offer_ids.append(String(s))
	draws = maxi(0, int(d.get("draws", 0)))
	rerolls_used = maxi(0, int(d.get("rerolls_used", 0)))
	removals_used = maxi(0, int(d.get("removals_used", 0)))
	depth_reached = int(d.get("depth_reached", -1))
	pending_searches = maxi(0, int(d.get("pending_searches", 0)))
	history.clear()
	for e in d.get("history", []):
		if e is Dictionary:
			var row := e as Dictionary
			history.append({"step": int(row.get("step", 0)), "source": String(row.get("source", "")),
				"gained": float(row.get("gained", 0.0)), "total": float(row.get("total", 0.0)), "level": int(row.get("level", 1))})     # 读回来的整数是浮点：按原样的类型存回去


func dispose() -> void:
	_echo = null
	super()
