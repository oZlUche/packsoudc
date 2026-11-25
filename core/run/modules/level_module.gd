## 372（作者定）：局内成长 —— 经验值、等级、每级三选一的牌。规矩与牌池在 [LevelRules]（`base_rules/level.json`）。
##
## - **经验值**只涨不花（原来的信力，作者 22:02 改名）。通用来源在这里接：打赢战斗（普通 / 精英 / 猎手 / 首领各给各的，秒杀不算打了一场）、
##   第一次到达更深一环、神坛祷告（[method pray]）；神坛献祭由 [AltarModule] 记、各位神的事由 [FaithPower] 记，都经 [method gain]。
##   所有途径都乘难度系数（[method LevelRules.mult]）。
## - **等级**按累计经验值算（[method LevelRules.level_of]），封顶 30。每升一级欠一次选牌。
## - **质变位**（388，作者 11-24）：进入对局时先欠一次，之后 6 / 12 / 18 / 24 / 30 级各欠一次（排在这一级的普通选牌后面），所有神通用。
##   奉的神有质变牌就从这位神的质变牌里出（拿过一张后它的升级版进池）；【无信者】和还没写牌的神改为多选一张通用牌（初值）。
## - **普通选牌**奉神时从通用牌 + 这位神的基础牌一个池子里加权抽，至少一张是神的（作者 11-22）；无信者全是通用牌。
## - **选牌**：回到地图时界面按 [method pending] 弹出，三张一起出（[method offer]），挑一张（[method pick]）。同一张可以重复拿，拿几次就叠几层；
##   「拿过就不再出」的（元素回响本体）拿过就换成两张后续牌。**刷新**（三张一起换）、**删除**（这一局不再出，空位当场补一张）的次数
##   由局外科技给（[member RunContext.level_rerolls] / [member RunContext.level_removals]），一局用完为止。
## - 出牌用这一局的种子派生（第几次抽 = [member draws]），抽出来的那三张进存档：读档回来还是这三张，刷新出的下一批也由种子定，读档刷不了牌。
## - 拿到的牌是一局的 buff（[method defs]，[method RunState.active_buff_defs] 并进去）：战斗属性、按件修饰、负重、休息都走原来那条路。
##   体力上限当场加（开局才算一次的那个数）；「下一次搜索多翻一件」攒着、下一个搜索点用掉；元素回响按拿过几张现拼一条战斗规则。
##
## 出牌条件：after（拿过某张才出）、excludes（互斥）、when（满足条件才入池，各位神的代码用 [method register_when] 登记）、upgrade_of（升级版）
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
## 396 献祭换来的质变还欠几次（记在 [member god_state]）
const SACRIFICE_DUE := "sacrifice_due"

## 经验值、等级、待选的牌、选了牌 —— 有变化就发（界面重画）
signal level_changed()
## 升了一级（一次升几级发几次）
signal leveled(level: int)
## 挑了一张牌
signal picked(card_id: StringName)

## 累计经验值（乘过难度系数；小数照留，界面取整）
var xp: float = 0.0
## 已经选过几次普通牌（每升一级一次）
var picks_done: int = 0
## 388：已经用掉几个质变位（开局 + 6 / 12 / … 级）
var qual_done: int = 0
## 已经结算到第几级
var level_seen: int = 1
## 拿过的牌：id → 几张
var taken: Dictionary = {}
## 这一局删掉的牌（不再出）
var removed: Array[String] = []
## 现在摆着的三张（空 = 没在选，或者还没抽）
var offer_ids: Array[String] = []
## 388：摆着的这一批是不是质变位的
var offer_qual := false
## 一共抽过几次（种子的一部分）
var draws: int = 0
var rerolls_used: int = 0
## 396：【跳过】用了几次；上一次跳过了，下一次摆牌多一张（用掉就清）
var skips_used: int = 0
var skip_bonus: int = 0
var removals_used: int = 0
## 到过的最深一环（-1 = 还没记开局那一环）
var depth_reached: int = -1
## 攒着的「下一次搜索多翻一件」
var pending_searches: int = 0
## 388：神的牌在一局里要记的数（神罚用掉几次这类），进存档
var god_state: Dictionary = {}
## 每一笔经验值：{step, source, gained, total, level}
var history: Array[Dictionary] = []

var _echo: RunBuffDef = null
var _echo_key := ""
## 388：「满足条件才入池」的条件：key → func(run) -> bool（各位神装上时登记，不进存档）
var _when: Dictionary = {}


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


## 388：登记一个「满足条件才入池」的条件（牌表的 `when`）。[param check] 是 func(run: RunState) -> bool
func register_when(key: StringName, check: Callable) -> void:
	_when[String(key)] = check


func _when_met(key: String) -> bool:
	if key == "":
		return true
	var c: Callable = _when.get(key, Callable())
	if not c.is_valid():
		return GodWhen.met(StringName(key), self)     # 388：各位神写死在代码里的条件（日神：黑夜 / 白昼时长到 0）
	return bool(c.call(_run))


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


## 难度系数（这一局的难度档）；377：万神院三档起，奉着神的时候再乘 1 + [member RunState.faith_xp_bonus]（无信者不加）
func mult() -> float:
	var tier := _run.difficulty.level if _run != null and _run.difficulty != null else 0
	var m := rules().mult(tier)
	if _run != null and _run.faith_xp_bonus > 0.0 and not _humanist():
		m *= 1.0 + _run.faith_xp_bonus
	return m


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
	var cm := CommissionModule.of(_run)
	if cm != null and not _humanist():
		cm.on_faith_level(lv)     # 377：万神院的「修行」
	leveled.emit(lv)


## 【无信者】：此刻没有有效信仰
func _humanist() -> bool:
	return _run == null or _run.active_faith_id() == &""


func is_humanist() -> bool:
	return _humanist()
#endregion


#region 选牌
## 还欠几次选牌（普通 + 质变位）
func pending() -> int:
	return _regular_left() + _qual_left() + (1 if NatureCyclePerk.choice_due(self) else 0)


## 388 自然之神【初种】：选牌窗正摆着「继续培育 / 采摘」
func seed_offer() -> bool:
	return bool(god_state.get(NatureCyclePerk.SEED_OFFER, false)) and not offer_ids.is_empty()


func _regular_left() -> int:
	return maxi(0, level() - 1 - picks_done)


## 388：下一个质变位是第几个（开局那位算第 0 个）。章节关了开局选牌（教程）就从第 1 个算起
func _slot_index() -> int:
	return qual_done + (1 if opening_skipped() else 0)


## 388（架构设计初值）：这一章不弹开局那次质变选牌（[member ChapterDef.opening_qual_pick]，教程章节关）
func opening_skipped() -> bool:
	return rules().qual_opening and _run != null and _run.chapter != null and not _run.chapter.opening_qual_pick


func _qual_left() -> int:
	return maxi(0, rules().qual_slots_at(level()) - _slot_index()) + sacrifice_due()


## 396 蛮神【献祭】换来的、还没选的质变（排在最前，不占 6 / 12 / … 级的质变位）
func sacrifice_due() -> int:
	return int(god_state.get(SACRIFICE_DUE, 0))


## 选牌按级排队：每级一次普通牌，逢质变位的那一级紧跟着一次质变（开局那次在最前）。返回现在这一张：
## {level: 第几级的, qual: 是不是质变位, generic: 质变位但没有质变牌池（多选一张通用牌）}；不欠选牌 = {}
func current_pick() -> Dictionary:
	if pending() <= 0:
		return {}
	if seed_offer() or (offer_ids.is_empty() and NatureCyclePerk.choice_due(self)):
		return {"level": level(), "qual": false, "seed": true}
	var qual := _next_is_qual()
	var lv := (level() if sacrifice_due() > 0 else rules().qual_level_of(_slot_index())) if qual else picks_done + 2
	return {"level": lv, "qual": qual, "generic": qual and not has_qual_pool()}


## 下一张是不是质变位：两种都欠时，按级数先后（同一级普通牌在前）
func _next_is_qual() -> bool:
	if not offer_ids.is_empty():
		return offer_qual     # 已经摆出来的那一批不变
	if _qual_left() <= 0:
		return false
	if sacrifice_due() > 0:
		return true
	if _regular_left() <= 0:
		return true
	return rules().qual_level_of(_slot_index()) < picks_done + 2


## 这一局奉的神（无信者 &""）
func god() -> StringName:
	return _run.active_faith_id() if _run != null else &""


## 388：奉的神此刻有没有能出的质变牌（没写牌、都拿完了 = 质变位改为多选一张通用牌）
func has_qual_pool() -> bool:
	if god() == &"":
		return false
	var r := rules()
	for cid in r.card_ids():
		if r.is_qual(cid) and eligible(cid):
			return true
	return false


## 这一次摆几张：质变位的开局那一次，万神院五档多一张（[member RunState.opening_extra_choice]）
func _choices_for(qual: bool) -> int:
	var n := rules().choices + skip_bonus
	if qual and _slot_index() == 0 and rules().qual_opening and _run != null and _run.opening_extra_choice:
		n += 1
	return n


func rerolls_left() -> int:
	var ctx := _run.buff_context() if _run != null else RunContext.new()
	return maxi(0, ctx.level_rerolls + (_run.faith_rerolls if _run != null else 0) - rerolls_used)


## 396：这一局一共能【跳过】几次（万神院给的；0 = 没开，界面不摆这个键）
func skips_total() -> int:
	return _run.faith_skips if _run != null else 0


func skips_left() -> int:
	return maxi(0, skips_total() - skips_used)


func removals_left() -> int:
	var ctx := _run.buff_context() if _run != null else RunContext.new()
	return maxi(0, ctx.level_removals - removals_used)


## 现在摆着的三张（欠着选牌又还没抽就现抽）。不欠 = 空
func offer() -> Array[StringName]:
	if pending() <= 0:
		if not offer_ids.is_empty():
			offer_ids.clear()
		return [] as Array[StringName]
	if offer_ids.is_empty() and NatureCyclePerk.choice_due(self):
		offer_qual = false
		offer_ids = [String(NatureCyclePerk.SEED_KEEP), String(NatureCyclePerk.SEED_PICK)] as Array[String]     # 初种长到一阶：两张选一
		god_state[NatureCyclePerk.SEED_OFFER] = true
	if offer_ids.is_empty():
		god_state.erase(NatureCyclePerk.SEED_OFFER)
		offer_qual = _next_is_qual()
		offer_ids = _draw(_choices_for(offer_qual), [], offer_qual)
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
	if seed_offer():
		god_state.erase(NatureCyclePerk.SEED_OFFER)
		offer_ids.clear()
		NatureCyclePerk.seed_choose(self, cid == NatureCyclePerk.SEED_KEEP)
		picked.emit(cid)
		level_changed.emit()
		return cid
	taken[String(cid)] = count_of(cid) + 1
	skip_bonus = 0     # 396：跳过多出的那一张只管这一批
	if offer_qual and sacrifice_due() > 0:
		god_state[SACRIFICE_DUE] = sacrifice_due() - 1
	elif offer_qual:
		qual_done += 1
	else:
		picks_done += 1
	offer_ids.clear()
	offer_qual = false
	_apply_now(cid)
	picked.emit(cid)
	level_changed.emit()
	return cid


## 396【跳过】：这一次不选（这一级照样算选过），下一次摆牌多一张。次数不够、正摆着【初种】返回 false
func skip() -> bool:
	var cards := offer()
	if cards.is_empty() or skips_left() <= 0 or seed_offer():
		return false
	skips_used += 1
	if offer_qual and sacrifice_due() > 0:
		god_state[SACRIFICE_DUE] = sacrifice_due() - 1     # 跳过献祭换来的那次质变：这次就算用掉了
	elif offer_qual:
		qual_done += 1
	else:
		picks_done += 1
	offer_ids.clear()
	offer_qual = false
	skip_bonus = 1
	level_changed.emit()
	return true


## 刷新：三张一起换一批（尽量不和这三张重样）。次数不够返回 false
func reroll() -> bool:
	var cards := offer()
	if cards.is_empty() or rerolls_left() <= 0 or seed_offer():
		return false
	rerolls_used += 1
	var avoid: Array[String] = offer_ids.duplicate()
	offer_ids = _draw(offer_ids.size(), avoid, offer_qual)
	level_changed.emit()
	return true


## 删除第 [param i] 张：这一局不再出，空位当场补一张（这一级照常选）。次数不够返回 false
func remove(i: int) -> bool:
	var cards := offer()
	if i < 0 or i >= cards.size() or removals_left() <= 0 or seed_offer():
		return false
	removals_used += 1
	var gone := offer_ids[i]
	removed.append(gone)
	var keep: Array[String] = offer_ids.duplicate()
	keep.remove_at(i)
	var fill := _draw(1, keep, offer_qual)
	if fill.is_empty() or keep.has(fill[0]):     # 池里没别的了：空着，不和留下的重样
		offer_ids.remove_at(i)
	else:
		offer_ids[i] = fill[0]
	level_changed.emit()
	return true


func count_of(card_id: StringName) -> int:
	return int(taken.get(String(card_id), 0))


## 388：拿到的质变牌，按拿的先后：[{id: 原牌, upgraded: 拿了升级版没有, shown: 显示哪一张（升级了就是升级版）}]。神恩区、顶端栏小图标读它
func quals() -> Array[Dictionary]:
	var r := rules()
	var out: Array[Dictionary] = []
	for k in taken:
		var cid := StringName(String(k))
		if not r.is_qual(cid) or String(r.card(cid).get("upgrade_of", "")) != "":
			continue
		var up := _upgrade_of(cid)
		var has_up := up != &"" and count_of(up) > 0
		if cid == NatureCyclePerk.SEED:     # 初种按长到第几阶显示
			var shown := NatureCyclePerk.seed_shown(self)
			out.append({"id": cid, "upgraded": shown != cid, "shown": shown})
			continue
		out.append({"id": cid, "upgraded": has_up, "shown": up if has_up else cid})
	return out


## 质变牌 [param cid] 的升级版（没有 &""）
func _upgrade_of(cid: StringName) -> StringName:
	var r := rules()
	for other in r.card_ids():
		if String(r.card(other).get("upgrade_of", "")) == String(cid):
			return other
	return &""


## 388：拿到的神的基础牌（每张一格、写层数），按拿的先后：[{id, count}]
func god_cards() -> Array[Dictionary]:
	var r := rules()
	var out: Array[Dictionary] = []
	for k in taken:
		var cid := StringName(String(k))
		if r.god_of(cid) != &"" and not r.is_qual(cid):
			out.append({"id": cid, "count": count_of(cid)})
	return out


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
	if row.is_empty() or removed.has(String(card_id)) or bool(row.get("hidden", false)):
		return false     # hidden：不进牌池（初种的后几阶、继续培育 / 采摘）
	if _run != null and not _run.buff_defs.is_empty() and not _run.buff_defs.has(card_id):
		return false
	if (bool(row.get("once", false)) or r.is_qual(card_id)) and count_of(card_id) > 0:
		return false
	var g := r.god_of(card_id)
	if g != &"" and g != god():
		return false
	var after := String(row.get("after", ""))
	if after != "" and count_of(StringName(after)) <= 0:
		return false
	var up := String(row.get("upgrade_of", ""))
	if up != "" and count_of(StringName(up)) <= 0:
		return false
	for x in row.get("excludes", []):
		if count_of(StringName(String(x))) > 0:
			return false
	if _removed_by_taken(card_id):
		return false     # 388：拿了某张就让这张不再出（永日不落 / 永夜难明 → 日长夜短、长夜促昼）
	var solo := solo_card()
	if solo != &"" and r.is_qual(card_id):
		return false     # 388：永日 / 永夜的升级版：别的质变牌失效、也拿不到
	if not _when_met(String(row.get("when", ""))):
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


## 抽 [param n] 张不重样的（不抽 [param avoid] 里的；能出的不够就有几张给几张，避开的也拿来补）。
## [param qual] 质变位：奉的神有质变牌就只从它的质变牌里抽，否则当普通选牌（只出通用牌）。
## 普通选牌奉神时通用牌 + 这位神的基础牌一个池子，抽出来一张神的都没有就把最后一张换成神的（保底一张，作者 11-22）
func _draw(n: int, avoid: Array[String], qual: bool = false) -> Array[String]:
	var r := rules()
	var use_quals := qual and has_qual_pool()
	var generic_only := qual and not use_quals
	if use_quals and forced_next() != &"":
		draws += 1
		return [String(forced_next())] as Array[String]     # 388：只有那一张
	var pool: Array[String] = []
	var spare: Array[String] = []
	var gods: Array[String] = []
	for cid in r.card_ids():
		if not eligible(cid) or r.is_qual(cid) != use_quals:
			continue
		var godly := r.god_of(cid) != &""
		if generic_only and godly:
			continue
		if avoid.has(String(cid)):
			spare.append(String(cid))
		else:
			pool.append(String(cid))
			if godly:
				gods.append(String(cid))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:level_cards:%d" % [_run.run_seed if _run != null else 0, draws])
	draws += 1
	var out: Array[String] = []
	for src in [pool, spare]:
		var left: Array[String] = (src as Array[String]).duplicate()
		while out.size() < n and not left.is_empty():
			var at := _weighted(left, rng)
			out.append(left[at])
			left.remove_at(at)
	if not use_quals and not generic_only and not gods.is_empty() and not out.is_empty() and not out.any(func(c: String) -> bool: return gods.has(c)):
		var left_gods: Array[String] = gods.filter(func(c: String) -> bool: return not out.has(c))
		if not left_gods.is_empty():
			out[out.size() - 1] = left_gods[_weighted(left_gods, rng)]
	return out


## 按权重挑一张的下标
func _weighted(left: Array[String], rng: RandomNumberGenerator) -> int:
	var r := rules()
	var total := 0.0
	for cid in left:
		total += maxf(0.0, r.weight_of(StringName(cid)))
	var roll := rng.randf() * total
	for j in left.size():
		roll -= maxf(0.0, r.weight_of(StringName(left[j])))
		if roll < 0.0:
			return j
	return left.size() - 1


## 拿牌那一下就要算的：体力上限（开局算一次的数）、攒「下一次搜索」
func _apply_now(cid: StringName) -> void:
	var row := rules().card(cid)
	if String(row.get("oneshot", "")) == String(LevelRules.ONESHOT_SEARCH):
		pending_searches += 1
	if String(row.get("oneshot", "")) == String(LevelRules.ONESHOT_MIRACLE):
		god_state["miracle_last"] = Miracle.apply(_run)     # 388 日神【奇迹】
	if String(row.get("oneshot", "")) == String(LevelRules.ONESHOT_SACRIFICE):
		BruteRagePerk.sacrifice(self, cid)     # 396 蛮神【献祭】
	if god() == &"nature":
		NatureCyclePerk.on_pick(self, cid)     # 388 自然：坚韧、感知、培育、动物交谈升级
	var def: RunBuffDef = _run.buff_defs.get(cid, null) if _run != null else null
	if def == null or _run.vitality == null:
		return
	for e in def.effects:
		if e is VitalityMaxBonus:
			var add := (e as VitalityMaxBonus).amount
			if add > 0:
				_run.vitality.set_max(_run.vitality.maximum + add, &"level_card", false)     # 作者 11-24：空的体力容器，不回体力
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
	var gc := god_card_of(card_def(card_id))
	if gc != null:
		return gc.fill(UiText.t("gcard." + String(card_id)))     # 一张的数（基础牌拿几张由层数角标写）
	return def.summary() if def != null else ""


## 388：[param def] 带的神的牌的数（没有 = null）
static func god_card_of(def: RunBuffDef) -> GodCard:
	if def == null:
		return null
	for e in def.effects:
		if e is GodCard:
			return e as GodCard
	return null


## 388：拿了 [param card_id] 的话，它的数 [param key] 一共是多少（基础牌拿几张乘几）；没拿 = [param fallback]
func god_value(card_id: StringName, key: String, fallback: float = 0.0) -> float:
	var n := count_of(card_id)
	if n <= 0 or _run == null:
		return fallback
	var gc := god_card_of(card_def(card_id))
	if gc == null or not gc.values.has(key):
		return fallback
	return float(gc.values[key]) * n


## 388：牌 [param card_id] 上写的数 [param key]（不管拿没拿、不乘张数）；没写 = [param fallback]
func card_value(card_id: StringName, key: String, fallback: float = 0.0) -> float:
	var gc := god_card_of(card_def(card_id))
	if gc == null or not gc.values.has(key):
		return fallback
	return float(gc.values[key])


## 388：牌的那份 buff —— 这一局的表里没有（测试拼的内容）就按 id 去内容里找
func card_def(card_id: StringName) -> RunBuffDef:
	var def: RunBuffDef = _run.buff_defs.get(card_id, null) if _run != null else null
	if def == null:
		var path := ContentPaths.asset_file("run_buffs", String(card_id))
		def = load(path) as RunBuffDef if ResourceLoader.exists(path) else null
	return def


## 388：拿了没有（拿了「独占」的质变牌后，别的质变牌算没拿）
func has_card(card_id: StringName) -> bool:
	if count_of(card_id) <= 0:
		return false
	var solo := solo_card()
	if solo == &"" or not rules().is_qual(card_id):
		return true
	return card_id == solo or String(rules().card(solo).get("upgrade_of", "")) == String(card_id)


## 388：拿了的「独占」牌（牌表 `solo`）；没有 = 空
func solo_card() -> StringName:
	var r := rules()
	for k in taken:
		if bool(r.card(StringName(k)).get("solo", false)):
			return StringName(k)
	return &""


func _removed_by_taken(card_id: StringName) -> bool:
	var r := rules()
	for k in taken:
		if (r.card(StringName(k)).get("removes", []) as Array).has(String(card_id)):
			return true
	return false


## 388：拿了「下一张质变牌必定是它的升级」（牌表 `forces_next`）、升级还没拿 → 那张升级；没有 = 空
func forced_next() -> StringName:
	var r := rules()
	for k in taken:
		if bool(r.card(StringName(k)).get("forces_next", false)):
			var up := _upgrade_of(StringName(k))
			if up != &"" and count_of(up) <= 0:
				return up
	return &""


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
	if node == null or (_run != null and not _run.faith_enabled):     # 377：万神院来之前休息点没有神坛
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
	if _r != null and has_card(&"god_sun_shift"):
		var shifts := 0
		for raw in _r.log:
			var e := raw as BattleEvent
			if e.name == BattleEvent.EFFECT_RESOLVED and e.side == 0 and String(e.payload.get("key", "")) == "sun_window":
				shifts += 1
		god_state["sun_shifts"] = int(god_state.get("sun_shifts", 0)) + shifts     # 388 星移斗转：一局里留着
	if _r != null and god() == &"nature":
		NatureCyclePerk.settle(self, _r)     # 388 生长 / 丰饶升级
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
	return {"xp": xp, "picks_done": picks_done, "qual_done": qual_done, "level_seen": level_seen,
		"taken": taken.duplicate(), "removed": removed.duplicate(), "offer": offer_ids.duplicate(), "offer_qual": offer_qual, "draws": draws,
		"rerolls_used": rerolls_used, "removals_used": removals_used, "skips_used": skips_used, "skip_bonus": skip_bonus, "depth_reached": depth_reached,
		"pending_searches": pending_searches, "history": history.duplicate(true), "god_state": god_state.duplicate(true)}


func restore(d: Dictionary) -> void:
	xp = maxf(0.0, float(d.get("xp", 0.0)))
	picks_done = maxi(0, int(d.get("picks_done", 0)))
	qual_done = maxi(0, int(d.get("qual_done", 0)))
	god_state = (d.get("god_state", {}) as Dictionary).duplicate(true) if d.get("god_state", {}) is Dictionary else {}
	if not d.has("qual_done"):     # 388 之前的档：无信者逢 5 级多选的那几次记在 picks_done 里，挪成用掉的质变位
		var bonus := maxi(int(d.get("bonus_picks", 0)), (d.get("bonus_levels", []) as Array).size())
		bonus = mini(bonus, picks_done)
		picks_done -= bonus
		qual_done = bonus
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
	offer_qual = bool(d.get("offer_qual", false))
	draws = maxi(0, int(d.get("draws", 0)))
	rerolls_used = maxi(0, int(d.get("rerolls_used", 0)))
	skips_used = maxi(0, int(d.get("skips_used", 0)))     # 396
	skip_bonus = clampi(int(d.get("skip_bonus", 0)), 0, 1)
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
