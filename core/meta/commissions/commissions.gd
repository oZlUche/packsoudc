## 336（阵营与委托 W0，报告 335）：委托与声望的规则 —— 纯逻辑，状态在 [CommissionBook]（局外存档），定义在 [CommissionDef] / [FactionDef]。
##
## 规则（方案「接取、交付与声望」，数值是候选）：
## - 342 B2：每方五档，门槛 0 / 10 / 25 / 50 / 100（初识 / 熟面 / 受托 / 信赖 / 代言）；代言另要做完这一方的结案（[member CommissionBook.signed]）。
## - 剧情（不是模板的委托）：够格就自动接上（[method auto_take]），常驻到办成，不占位、不能暂缓或放弃；办成开放写在 [member CommissionDef.opens] 的设施。
## - 常规（模板）：同时最多接 [constant SLOTS] 份；暂缓不占位，进度保留；放弃清掉进度，可以重接。模板最多把一方推到 [constant TEMPLATE_CAP] 点。
## - 正常战败不扣声望。现场交付的步骤失败也算；带回的步骤只在撤离成功（或写明托付算数时托付成功）才算（[method merge_run]）。
## - 同一委托、同一步、同一处（节点 id / 实例 uid）只记一次（去重键），读档重进、反复进同一节点不重复记账。
class_name Commissions
extends RefCounted

## 342 B2：手头（接下的常规纸条）最多几份（报告 341 第 3.1 节）
const SLOTS := 3
## 342 B2：常规纸条最多把一方推到多少声望（信赖；代言要靠结案）
const TEMPLATE_CAP := 50
## 声望五档
const TIERS := 5
## 342 B2：能由剧情开放的基地设施
const FACILITIES: Array[StringName] = [&"smithy", &"tech", &"market"]
## 342 B3：后来几方剧情开的功能（材料倾向、种地）—— 老档也要办成才开（不像 [constant FACILITIES] 那样老档照开）
const FEATURES: Array[StringName] = [&"bias", &"nursery"]
## 342 B3：阵营什么时候来营地（[member FactionDef.arrives]）：教程后第一次正式探索结算时
const ARRIVES_FIRST_RUN := &"first_run"
## 去重键：委托 id | 第几步 | 那一处
const KEY_FMT := "%s|%d|%s"

## 目标种类 → 允许的完成地点（[member CommissionStage.where]）。按批次加，每种对应一个真实事件（报告 335 第三节）
const GOALS := {
	&"inspect_extracts": [CommissionStage.FIELD],     # 撤离点上的「查验」：不同的撤离点 N 处
	&"smith_forge": [CommissionStage.CAMP],     # 接单后在铁匠铺真的打一次（接单时选的那张配方）
	&"deliver_letter": [CommissionStage.FIELD],     # 撤离点上的「交信」：把任务信交出去
	&"camp_report": [CommissionStage.CAMP],     # 342 B2：营地里找对应的人办一次（委托页卡上的【办理】）
	&"hand_in": [CommissionStage.CAMP],     # 342 B2：营地交货 —— 仓库里合格的几件（`params` 的 material / min，或 id），可以分批
	&"defeat_enemies": [CommissionStage.FIELD],     # 342 B2：打赢 N 场（`params.kind` = normal 只认普通敌人；`params.enemy` 认一种）
	&"visit_nodes": [CommissionStage.FIELD],     # 342 B2：到访 N 处（`params.type` = 节点类型），同一局同一处只记一次
}
## 342 B2：营地当场能办的目标（卡上有【办理】）
const CAMP_GOALS: Array[StringName] = [&"camp_report", &"hand_in"]
## 342 B2：常规委托从第几档开（受托），还要办完这一方的许可单（[member FactionDef.permit]）
const REGULAR_TIER := 2

## 不能接的原因（字表键 `commission.why_<原因>`）
const WHY_HIDDEN := "hidden"
const WHY_DONE := "done"
const WHY_TAKEN := "taken"
const WHY_SLOTS := "slots"
const WHY_TIER := "tier"
const WHY_REQUIRES := "requires"
const WHY_MUTEX := "mutex"
const WHY_PICK := "pick"

static var _factions: Array[FactionDef] = []
static var _defs: Array[CommissionDef] = []
## 342 B2：现在用着的委托簿（告示栏的纸条按它查，[method def]）。建簿、读档时设
static var active: CommissionBook = null


#region 定义
static func factions() -> Array[FactionDef]:
	if _factions.is_empty():
		_factions.assign(ContentPaths.load_typed(ContentPaths.FACTIONS, FactionDef))
		_factions.sort_custom(func(a: FactionDef, b: FactionDef) -> bool: return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
	return _factions


## 委托簿里列出来的几方（342 B3：还没来营地的不列，[method present]）
static func listed_factions() -> Array[FactionDef]:
	return factions().filter(func(f: FactionDef) -> bool: return f.listed and present(active, f))


## 342 B3：这一方到营地了没有（一开始就在的、或已经按 [member FactionDef.arrives] 来了）
static func present(book: CommissionBook, f: FactionDef) -> bool:
	return f != null and (f.arrives == &"" or (book != null and book.arrived.has(String(f.id))))


## 342 B3：一次正式探索结算完 —— 约好这时来的几方到营地（记第几局到的）。返回这回来了哪几方
static func arrive(book: CommissionBook, run_no: int) -> Array[StringName]:
	var out: Array[StringName] = []
	if book == null:
		return out
	for f in factions():
		if f.listed and f.arrives == ARRIVES_FIRST_RUN and not book.arrived.has(String(f.id)):
			book.arrived[String(f.id)] = run_no
			out.append(f.id)
	return out


## 342 B3：剧情能开的全部（设施 + 功能）
static func opens_known(id: StringName) -> bool:
	return FACILITIES.has(id) or FEATURES.has(id)


static func faction(id: StringName) -> FactionDef:
	for f in factions():
		if f.id == id:
			return f
	return null


static func defs() -> Array[CommissionDef]:
	if _defs.is_empty():
		_defs.assign(ContentPaths.load_typed(ContentPaths.COMMISSIONS, CommissionDef))
		_defs.sort_custom(func(a: CommissionDef, b: CommissionDef) -> bool: return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
	return _defs


static func def(id: StringName) -> CommissionDef:
	for d in defs():
		if d.id == id:
			return d
	if NoticeBoard.is_note(id) and active != null and active.notes.has(String(id)):     # 342 B2：告示栏的纸条
		return NoticeBoard.def_of(String(id), active.notes[String(id)])
	return null


## 这一方的委托，按 order
static func of_faction(id: StringName, pool: Array = []) -> Array[CommissionDef]:
	var out: Array[CommissionDef] = []
	for d in (pool if not pool.is_empty() else defs()):
		if (d as CommissionDef).faction == id:
			out.append(d)
	return out
#endregion


#region 档位与声望
## 档位的默认声望：入门 1、调查 2、结案 3、模板 1
static func default_reputation(tier: StringName) -> int:
	match tier:
		CommissionDef.INQUIRY:
			return 2
		CommissionDef.FINALE:
			return 3
	return 1


static func reputation_of(d: CommissionDef) -> int:
	return d.reputation if d.reputation > 0 else default_reputation(d.tier)


## 接这一档要几级（0 陌生、1 熟面、2 受托）
static func required_tier(d: CommissionDef) -> int:
	if d.min_tier >= 0:
		return d.min_tier
	match d.tier:
		CommissionDef.INQUIRY:
			return 1
		CommissionDef.FINALE:
			return 2
	return 0


## 这一方现在几档（0..4）。到了代言门槛但没署名结案，停在信赖
static func tier_of(book: CommissionBook, f: FactionDef) -> int:
	if f == null:
		return 0
	var r := book.rep_of(f.id) if book != null else 0
	var lv := 0
	for i in f.thresholds.size():
		if r >= f.thresholds[i]:
			lv = i
	if lv >= TIERS - 1 and not (book != null and book.signed.has(String(f.id))):
		lv = TIERS - 2
	return lv


## 342 B2：剧情委托（不是模板）
static func is_story(d: CommissionDef) -> bool:
	return d != null and d.tier != CommissionDef.TEMPLATE


## 342 B2：开 [param facility] 的那份剧情（没有 = null）
static func opener_of(facility: StringName) -> CommissionDef:
	for d in defs():
		if d.opens == facility:
			return d
	return null


## 下一级还差几点（满级 = 0）
static func rep_to_next(book: CommissionBook, f: FactionDef) -> int:
	var lv := tier_of(book, f)
	if f == null or lv + 1 >= f.thresholds.size():
		return 0
	return maxi(0, f.thresholds[lv + 1] - book.rep_of(f.id))
#endregion


#region 接取
## 能不能接：空串 = 能；否则是原因（[constant WHY_HIDDEN] 这些）。[param pick] = 接单时要选的（配方 id），[param picks] = 现在能选的
static func why_not(book: CommissionBook, d: CommissionDef, pick: StringName = &"", picks: Array = []) -> String:
	var f := faction(d.faction) if d != null else null
	if d == null or f == null or not f.listed or not present(book, f):
		return WHY_HIDDEN
	var st := book.state_of(d.id)
	if st == CommissionBook.TAKEN:
		return WHY_TAKEN
	if NoticeBoard.is_note(d.id) and not book.pins.has(String(d.id)):     # 342 B2：纸条只能从栏上接
		return WHY_HIDDEN
	if book.is_done(d.id) and d.tier != CommissionDef.TEMPLATE:
		return WHY_DONE
	if d.mutex != &"" and book.mutex.has(String(d.mutex)):
		return WHY_MUTEX
	if tier_of(book, f) < required_tier(d):
		return WHY_TIER
	for r in d.requires:
		if not book.is_done(r):
			return WHY_REQUIRES
	if not is_story(d) and _taken_regular(book) >= SLOTS:
		return WHY_SLOTS
	if needs_pick(d) and st != CommissionBook.PAUSED and (pick == &"" or not picks.has(pick)):
		return WHY_PICK
	return ""


static func _taken_regular(book: CommissionBook) -> int:
	return book.taken().filter(func(id: StringName) -> bool: return not is_story(def(id))).size()


## 342 B2：够格的剧情自动接上（暂缓过的接着做；要先选配方的留给玩家点）。返回这回接上的 id
static func auto_take(book: CommissionBook) -> Array[StringName]:
	var out: Array[StringName] = []
	for d in defs():
		if not is_story(d) or needs_pick(d) or book.state_of(d.id) == CommissionBook.TAKEN:
			continue
		if take(book, d):
			out.append(d.id)
	return out


## 342 B2：营地「办理」—— 停在 `camp_report` 那一步就记一次；停在 `hand_in` 就把仓库里合格的交上去（够几件交几件）。
## 返回 [method credit] 的结果（交货另有 `handed` = 交了几件）
static func report(meta: MetaState, d: CommissionDef, items: ItemDatabase = null) -> Dictionary:
	var s := current_stage(meta.commissions, d.id) if meta != null and d != null else -1
	if s < 0 or s >= d.stages.size() or not CAMP_GOALS.has(d.stages[s].goal):
		return {"ok": false, "step": false, "done": false}
	if d.stages[s].goal == &"hand_in":
		return _hand_in(meta, d, s, items)
	return credit(meta, d, s, "camp", items)


## 342 B2：现在停在营地能办的那一步（交货要仓库里至少有一件合格的，所以要 [param meta]）
static func can_report(book: CommissionBook, d: CommissionDef, meta: MetaState = null) -> bool:
	var s := current_stage(book, d.id) if d != null else -1
	if s < 0 or s >= d.stages.size() or not CAMP_GOALS.has(d.stages[s].goal):
		return false
	return d.stages[s].goal != &"hand_in" or not hand_in_picks(meta, d, s).is_empty()


## 342 B2：这一步能收这件吗（任务物不收）
static func hand_in_fits(stage: CommissionStage, item: ItemDef) -> bool:
	if stage == null or item == null or item.tags.has(&"commission"):
		return false
	var want := String(stage.params.get("id", ""))
	if want != "":
		return String(item.id) == want
	return SmithRecipeDef.slot_fits({"material": String(stage.params.get("material", "")), "min": int(stage.params.get("min", 0))}, item)


## 342 B2：交货会交仓库里哪几件：合格、没锁的，稀有度低的先交，最多交到这一步还差的件数
static func hand_in_picks(meta: MetaState, d: CommissionDef, stage: int) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	if meta == null or meta.warehouse == null or d == null or stage < 0 or stage >= d.stages.size():
		return out
	var st := d.stages[stage]
	for inst in meta.warehouse.items():
		var it := inst as ItemInstance
		if not it.is_locked_by_player() and hand_in_fits(st, it.def):
			out.append(it)
	out.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool: return a.def.rarity < b.def.rarity)
	var need := maxi(1, st.count) - int(meta.commissions.entry(d.id).get("progress", 0))
	return out.slice(0, maxi(0, need))


static func _hand_in(meta: MetaState, d: CommissionDef, stage: int, items: ItemDatabase) -> Dictionary:
	var out := {"ok": false, "step": false, "done": false, "handed": 0}
	for it in hand_in_picks(meta, d, stage):
		if meta.warehouse.remove(it.uid) == null:
			continue
		var r := credit(meta, d, stage, "uid:%d" % it.uid, items)
		if not bool(r["ok"]):
			continue
		out["ok"] = true
		out["handed"] = int(out["handed"]) + 1
		out["step"] = bool(out["step"]) or bool(r["step"])
		if bool(r["done"]):
			out["done"] = true
			out["got"] = r["got"]
	return out


## 342 B2：这一方的常规委托开了没有：到受托，且办完了这一方的许可单
static func regular_open(book: CommissionBook, f: FactionDef) -> bool:
	return f != null and tier_of(book, f) >= REGULAR_TIER and (f.permit == &"" or book.is_done(f.permit))


## 接单时要不要先选一样（配方实验）
static func needs_pick(d: CommissionDef) -> bool:
	return d != null and d.stages.any(func(s: CommissionStage) -> bool: return s.goal == &"smith_forge")


## 接下（暂缓过的接着做，进度照旧）。返回接成没有
static func take(book: CommissionBook, d: CommissionDef, pick: StringName = &"", picks: Array = []) -> bool:
	if why_not(book, d, pick, picks) != "":
		return false
	var e: Dictionary = book.entry(d.id).duplicate(true)
	if String(e.get("state", "")) != CommissionBook.PAUSED:
		e["stage"] = 0
		e["progress"] = 0
		e["keys"] = []
		e["pick"] = String(pick)
	e["state"] = CommissionBook.TAKEN
	e["times"] = int(e.get("times", 0))
	e["seq"] = _next_seq(book)
	book.entries[String(d.id)] = e
	NoticeBoard.on_taken(book, d.id)
	return true


static func _next_seq(book: CommissionBook) -> int:
	var n := 0
	for k in book.entries:
		n = maxi(n, int((book.entries[k] as Dictionary).get("seq", 0)))
	return n + 1


## 暂缓：不占位，进度保留
static func pause(book: CommissionBook, id: StringName) -> bool:
	if book.state_of(id) != CommissionBook.TAKEN or is_story(def(id)) or NoticeBoard.is_note(id):     # 342 B2：剧情常驻、纸条全带进局，都不暂缓
		return false
	book.entries[String(id)]["state"] = CommissionBook.PAUSED
	return true


## 放弃：进度清掉（完成过几次留着），可以重接
static func abandon(book: CommissionBook, id: StringName) -> bool:
	var st := book.state_of(id)
	if (st != CommissionBook.TAKEN and st != CommissionBook.PAUSED) or is_story(def(id)):     # 342 B2：剧情不放弃
		return false
	if NoticeBoard.is_note(id):     # 342 B2：放弃的纸条不回栏上
		NoticeBoard.discard(book, id)
		return true
	var times := int(book.entry(id).get("times", 0))
	if times > 0:
		book.entries[String(id)] = {"state": CommissionBook.DONE, "stage": 0, "progress": 0, "keys": [], "times": times, "pick": "", "seq": 0}
	else:
		book.entries.erase(String(id))
	return true
#endregion


#region 记账
## 这份委托现在在第几步（没在做 = -1）
static func current_stage(book: CommissionBook, id: StringName) -> int:
	return int(book.entry(id).get("stage", 0)) if book.state_of(id) == CommissionBook.TAKEN else -1


## 记一次进度：只认正在做、正停在 [param stage] 这一步的；同一个 [param key] 只记一次。
## 这一步做够了进下一步，最后一步做完就结案（[method _complete]）。返回 {"ok": 记上没有, "step": 进了下一步, "done": 结案, "got": 结案发的}
static func credit(meta: MetaState, d: CommissionDef, stage: int, key: String, items: ItemDatabase = null) -> Dictionary:
	var out := {"ok": false, "step": false, "done": false}
	if meta == null or d == null:
		return out
	var book := meta.commissions
	if current_stage(book, d.id) != stage or stage < 0 or stage >= d.stages.size():
		return out
	var e: Dictionary = book.entries[String(d.id)]
	var k := KEY_FMT % [d.id, stage, key]
	if (e["keys"] as Array).has(k):
		return out
	(e["keys"] as Array).append(k)
	e["progress"] = int(e["progress"]) + 1
	out["ok"] = true
	if int(e["progress"]) < maxi(1, d.stages[stage].count):
		return out
	e["progress"] = 0
	e["stage"] = stage + 1
	out["step"] = true
	if int(e["stage"]) < d.stages.size():
		book.add_receipt({"id": String(d.id), "kind": "step", "stage": stage, "run": meta.runs})
		return out
	out["done"] = true
	out["got"] = _complete(meta, d, items)
	return out


## 结案：声望（模板封顶熟面）、署名、互斥、酬金，写回执。返回发了什么 {"rep", "funds", "items"}
static func _complete(meta: MetaState, d: CommissionDef, items: ItemDatabase) -> Dictionary:
	var book := meta.commissions
	var fid := String(d.faction)
	var gain := reputation_of(d)
	if d.tier == CommissionDef.TEMPLATE:
		gain = clampi(TEMPLATE_CAP - book.rep_of(d.faction), 0, gain)
	book.rep[fid] = book.rep_of(d.faction) + gain
	if d.tier == CommissionDef.FINALE:
		book.signed[fid] = true
	if d.mutex != &"":
		book.mutex[String(d.mutex)] = String(d.id)
	if d.opens != &"":
		book.grants[String(d.opens)] = true
	var times := int(book.entry(d.id).get("times", 0)) + 1
	book.entries[String(d.id)] = {"state": CommissionBook.DONE, "stage": 0, "progress": 0, "keys": [], "times": times, "pick": "", "seq": 0}
	var got := {"rep": gain, "funds": maxi(0, d.funds), "items": 0, "faction": fid, "opens": String(d.opens)}
	meta.funds += maxi(0, d.funds)
	if not d.items.is_empty() and items != null:
		var gifts: Array = []
		for id in d.items:
			for _i in maxi(0, int(d.items[id])):
				var item := items.get_def(StringName(String(id)))
				if item != null:
					gifts.append(item)
		got["items"] = int(meta.grant_lossless(gifts)["stored"])
	var rc := {"id": String(d.id), "kind": "done", "stage": d.stages.size() - 1, "run": meta.runs}
	if NoticeBoard.is_note(d.id):     # 342 B2：纸条下一局结算时清掉，回执自己记名字
		rc["name"] = Names.of(d)
		(book.notes[String(d.id)] as Dictionary)["done_run"] = meta.runs
	book.add_receipt(rc)
	return got


## 一局结束：把这一局记下的进度并进局外（和 [method MetaState.absorb] 同一次结算，重复结算由 `settled_runs` 挡掉）。
## [param rows] 每条 {"id": 委托 id, "stage": 第几步, "key": 那一处, "via": "self" / "entrust"}；
## [param extracted] = 本人撤离成功，[param entrusted] = 这一局托付交出去过（托付成功）。
## 现场交付的照记；带回的看撤离 / 托付，没带回写一条「重做」回执。返回 {"credited": 记上几条, "redo": 要重做几条}
static func merge_run(meta: MetaState, rows: Array, extracted: bool, entrusted: bool, items: ItemDatabase = null) -> Dictionary:
	var out := {"credited": 0, "redo": 0}
	if meta == null:
		return out
	for raw in rows:
		if not (raw is Dictionary):
			continue
		var row := raw as Dictionary
		var d := def(StringName(String(row.get("id", ""))))
		var stage := int(row.get("stage", -1))
		if d == null or stage < 0 or stage >= d.stages.size():
			continue
		var s := d.stages[stage]
		var counts := s.where == CommissionStage.FIELD
		if s.where == CommissionStage.CARRY:
			counts = extracted or (String(row.get("via", "self")) == "entrust" and s.entrust_ok and entrusted)
		if not counts:
			if current_stage(meta.commissions, d.id) == stage:
				meta.commissions.add_receipt({"id": String(d.id), "kind": "redo", "stage": stage, "run": meta.runs})
				out["redo"] = int(out["redo"]) + 1
			continue
		if bool(credit(meta, d, stage, String(row.get("key", "")), items)["ok"]):
			out["credited"] = int(out["credited"]) + 1
	return out
#endregion


#region 校验（导入之后整批查：前置与互斥要对着全部委托）
## 全部委托一起查：前置得是同一方、存在、不成环；结案的前置要齐（这一方的调查都列上）。返回问题清单（空 = 没问题）
static func validate_all(pool: Array, faction_pool: Array) -> Array[String]:
	var problems: Array[String] = []
	var by_id := {}
	for d in pool:
		by_id[(d as CommissionDef).id] = d
	var fids := faction_pool.map(func(f: FactionDef) -> StringName: return f.id)
	for d: CommissionDef in pool:
		if not fids.has(d.faction):
			problems.append("%s：找不到阵营 %s" % [d.id, d.faction])
		for r in d.requires:
			if not by_id.has(r):
				problems.append("%s：前置 %s 不存在" % [d.id, r])
			elif (by_id[r] as CommissionDef).faction != d.faction:
				problems.append("%s：前置 %s 不是同一方" % [d.id, r])
		if _cycles(d.id, by_id, {}):
			problems.append("%s：前置成环" % d.id)
	for f: FactionDef in faction_pool:     # 342 B2：许可单得是这一方的剧情
		if f.permit != &"" and (not by_id.has(f.permit) or (by_id[f.permit] as CommissionDef).faction != f.id or not is_story(by_id[f.permit])):
			problems.append("%s：许可单 %s 不是这一方的剧情" % [f.id, f.permit])
	return problems


static func _cycles(id: StringName, by_id: Dictionary, path: Dictionary) -> bool:
	if path.has(id):
		return true
	if not by_id.has(id):
		return false
	path[id] = true
	for r in (by_id[id] as CommissionDef).requires:
		if _cycles(r, by_id, path):
			return true
	path.erase(id)
	return false
#endregion
