## 342 B2（报告 341 第三、十一节）：常规委托的告示栏 —— 钉位、到期、回营补位，纸条按阵营的数量模板现掷。
##
## - 栏上 [constant PINS] 个钉位；第一次有一方开放常规（[method Commissions.regular_open]）时贴 [constant FIRST_FILL] 张。
## - 没接的纸条贴出时带 [constant LIFE] 局；每结算一局减 1，到 0 撤下。接下之后不再到期，进「手头」（[constant Commissions.SLOTS] 份）。
## - 每局回营：先扣时限，再给每个空钉位掷一次（[constant REFILL_CHANCE]），补完栏上没接的少于 [constant FLOOR] 张就补到够。
## - 抽什么：开放了常规的几方轮着来（优先栏上还没有的那方）；目标取自这一方的 [member FactionDef.regular]，
##   再掷短 / 常规 / 长单（[constant BANDS]），数量在那一档里掷。酬金 = 件数 × 单份酬值 × 档系数（[constant BAND_MULT]），声望按这一方的 [member FactionDef.note_rep]（389 第八节）。
## - 全用「市场种子 + 第几局」定死：读档重进刷不出别的。
## 纸条存在 [member CommissionBook.notes]（id → 纸条），[method Commissions.def] 认它（[method def_of]）。
class_name NoticeBoard
extends RefCounted

const PINS := 6
const FIRST_FILL := 4
const LIFE := 3
const REFILL_CHANCE := 0.5
const FLOOR := 2
## 目标种类 → 三档的数量区间（短单 / 常规单 / 长单）
const BANDS := {
	&"defeat_enemies": [[1, 2], [3, 4], [5, 6]],
	&"hand_in": [[1, 2], [3, 5], [6, 8]],
	&"visit_nodes": [[1, 1], [2, 2], [3, 4]],
	&"altar_offer": [[1, 1], [2, 2], [3, 3]],     # 377：万神院
	&"faith_levels": [[3, 4], [5, 7], [8, 10]],
}
const BAND_MULT := [1.0, 1.05, 1.10]
## 纸条 id 的前缀
const PREFIX := "note_"


## 纸条 → 委托定义（模板、一步、营地或现场按目标定）
static func def_of(id: String, note: Dictionary) -> CommissionDef:
	var d := CommissionDef.new()
	d.id = StringName(id)
	d.faction = StringName(String(note.get("faction", "")))
	d.tier = CommissionDef.TEMPLATE
	d.min_rep = 0
	var f := Commissions.faction(d.faction)
	d.reputation = maxi(1, f.note_rep) if f != null else 1
	d.funds = int(note.get("funds", 0))
	var band := clampi(int(note.get("band", 0)), 0, 2)
	var nm := Names.pick(note.get("names", {}) if note.get("names", null) is Dictionary else {}, String(note.get("name", "")))
	d.display_name = UiText.t("commission.band_%d" % band) + " · " + nm
	var st := CommissionStage.new()
	st.goal = StringName(String(note.get("goal", "")))
	st.count = maxi(1, int(note.get("count", 1)))
	st.params = (note.get("params", {}) as Dictionary).duplicate(true) if note.get("params", null) is Dictionary else {}
	st.where = (Commissions.GOALS.get(st.goal, [CommissionStage.FIELD]) as Array)[0]
	st.text = Names.pick(note.get("texts", {}) if note.get("texts", null) is Dictionary else {}, String(note.get("text", ""))).replace("{n}", str(st.count))
	d.stages = [st] as Array[CommissionStage]
	return d


static func is_note(id: StringName) -> bool:
	return String(id).begins_with(PREFIX)


## 栏上没接的纸条 id（按钉位）
static func posted(book: CommissionBook) -> Array[String]:
	var out: Array[String] = []
	for nid in book.pins:
		if String(nid) != "" and book.state_of(StringName(String(nid))) == "":
			out.append(String(nid))
	return out


## 能贴纸条的几方
static func open_factions(book: CommissionBook) -> Array[FactionDef]:
	return Commissions.listed_factions().filter(func(f: FactionDef) -> bool: return Commissions.regular_open(book, f) and not f.regular.is_empty())


static func _rng(meta: MetaState, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([meta.market_seed, meta.runs, "board", salt])
	return r


static func _ensure_pins(book: CommissionBook) -> void:
	while book.pins.size() < PINS:
		book.pins.append("")


## 第一次有一方开放：贴满 [constant FIRST_FILL] 张。返回贴了几张
static func first_fill(meta: MetaState) -> int:
	var book := meta.commissions
	if book.board_init or open_factions(book).is_empty():
		return 0
	book.board_init = true
	_ensure_pins(book)
	var rng := _rng(meta, "first")
	var n := 0
	for _i in FIRST_FILL:
		if _post(book, rng):
			n += 1
	return n


## 一局结算后：扣时限、撤下到期的、补位、保底。返回 {"expired": 撤下几张, "posted": 补了几张}
static func refresh(meta: MetaState) -> Dictionary:
	var out := {"expired": 0, "posted": 0}
	var book := meta.commissions
	for nid in book.notes.keys():     # 上一局以前办成的纸条清掉（这一局办成的留给结算屏写名字）
		var done_run := int((book.notes[nid] as Dictionary).get("done_run", -1))
		if done_run >= 0 and done_run < meta.runs:
			discard(book, StringName(String(nid)))
	if not book.board_init:
		out["posted"] = first_fill(meta)
		return out
	_ensure_pins(book)
	for i in book.pins.size():
		var nid := String(book.pins[i])
		if nid == "" or book.state_of(StringName(nid)) != "":
			continue
		var note: Dictionary = book.notes.get(nid, {})
		note["left"] = int(note.get("left", LIFE)) - 1
		if int(note["left"]) <= 0:
			book.notes.erase(nid)
			book.pins[i] = ""
			out["expired"] = int(out["expired"]) + 1
	var rng := _rng(meta, "refill")
	for i in book.pins.size():
		if String(book.pins[i]) == "" and rng.randf() < REFILL_CHANCE and _post(book, rng):
			out["posted"] = int(out["posted"]) + 1
	while posted(book).size() < FLOOR and book.pins.has("") and _post(book, rng):
		out["posted"] = int(out["posted"]) + 1
	return out


## 贴一张到第一个空钉位。没有空位、没有能贴的阵营 / 目标 = false
static func _post(book: CommissionBook, rng: RandomNumberGenerator) -> bool:
	var slot := book.pins.find("")
	var factions := open_factions(book)
	if slot < 0 or factions.is_empty():
		return false
	var on_board := {}
	for nid in book.pins:
		if String(nid) != "":
			on_board[String((book.notes.get(String(nid), {}) as Dictionary).get("faction", ""))] = true
	var fresh := factions.filter(func(x: FactionDef) -> bool: return not on_board.has(String(x.id)))
	var pool: Array = fresh if not fresh.is_empty() else factions
	var f: FactionDef = pool[rng.randi_range(0, pool.size() - 1)]
	for _try in 6:
		var tpl: Dictionary = f.regular[rng.randi_range(0, f.regular.size() - 1)]
		var goal := StringName(String(tpl.get("goal", "")))
		if not BANDS.has(goal):
			continue
		var band := rng.randi_range(0, 2)
		var span: Array = BANDS[goal][band]
		var count := rng.randi_range(int(span[0]), int(span[1]))
		var note := {"faction": String(f.id), "goal": String(goal), "params": (tpl.get("params", {}) as Dictionary).duplicate(true),
			"count": count, "band": band, "left": LIFE, "name": String(tpl.get("name", "")), "text": String(tpl.get("text", "")),
			"names": (tpl.get("names", {}) as Dictionary).duplicate(), "texts": (tpl.get("texts", {}) as Dictionary).duplicate(),
			"funds": int(round(count * int(tpl.get("u", 10)) * float(BAND_MULT[band])))}
		if _dupe(book, note):
			continue
		book.note_seq += 1
		var nid := PREFIX + str(book.note_seq)
		book.notes[nid] = note
		book.pins[slot] = nid
		return true
	return false


## 同一方、同一目标、同样件数的已经在栏上或手头
static func _dupe(book: CommissionBook, note: Dictionary) -> bool:
	for k in book.notes:
		var o: Dictionary = book.notes[k]
		if o.has("done_run"):
			continue
		if String(o.get("faction", "")) == String(note["faction"]) and String(o.get("goal", "")) == String(note["goal"]) \
				and JSON.stringify(o.get("params", {})) == JSON.stringify(note["params"]) and int(o.get("count", 0)) == int(note["count"]):
			return true
	return false


## 接下：纸条从钉位挪到手头（钉位空出来）
static func on_taken(book: CommissionBook, id: StringName) -> void:
	var i := book.pins.find(String(id))
	if i >= 0:
		book.pins[i] = ""


## 办成或放弃：纸条用掉（放弃的不回栏上）
static func discard(book: CommissionBook, id: StringName) -> void:
	book.notes.erase(String(id))
	book.entries.erase(String(id))
	var i := book.pins.find(String(id))
	if i >= 0:
		book.pins[i] = ""
