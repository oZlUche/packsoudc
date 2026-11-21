## 336 W1（阵营与委托，报告 335 第五节）：基地「委托」页。
## 342 B2：上面三颗子页键 —— 剧情 / 常规 / 声望，默认剧情，记住上次看的（当前那颗钉金钉）。
## - 剧情：三方的剧情单一起钉在板上，一排三张（够格就自动接上、常驻到办成；营地当场那一步卡上有【办理】），下面回执；
## - 常规：手头的纸条、告示栏上没接的纸条（报告 350）；没开的那方一张短纸条写差什么；
## - 声望：每方一张 —— 纹章、档名、五颗菱点、到下一档的细条，下面这一方管的设施（开了点过去，没开点到那份剧情）。
##
## 任务卡：纹章、名字、替谁办、做什么、在哪完成、报酬（金币图 + 声望）、状态与进度；钉子用这一方的颜色。
## 美术（UI设计，作者 2026-11-20 选 A 告示板，`assets/ui/commission/`）：深木板 + 毛边羊皮纸条 + 图钉、纹章、菱点、锁、沙漏
extends VBoxContainer

signal changed()
## 342 B2：声望页上点了一个已开放的设施（`smithy` / `tech` / `market`）
signal facility_requested(facility: StringName)
## 342 B2：【办理】办成了一份（[method Commissions.credit] 的结果，`got` 里有声望与开放的设施）
signal reported(got: Dictionary)

const KEY_SIZE := Vector2(182, 46)
const KEY_FONT := 18
const KEYS_GAP := 20.0
const CARD_W := 640.0
## 剧情一排三张的宽
const STORY_W := 370.0
## 剩几局时沙漏那句标红
const RED := Color("9a2f22")
const ART := "commission/"
const PAD_X := 26
const PAD_Y := 14
const INK := Color("2e2219")
const INK_DIM := Color("5a4a3a")
## 深木板上的浅字（UI设计 v6.77 复看）
const LIGHT := Color("f1e3c2")
## 钉子：图 18×22，钉子中心落在纸上沿往下 PIN_DIP 处，盖住纸边
const PIN_SIZE := Vector2(18, 22)
const PIN_DIP := 8.0
## 报告 350 C 托盘：告示栏三列；空钉位格子高；托盘高、间距、九宫格边（左、上、右、下，下沿是托盘口）
const BOARD_COLS := 3
const EMPTY_PIN_H := 120.0
const TRAY_H := 150.0
const TRAY_GAP := 16
const TRAY_EDGES := [12, 12, 12, 18]
## 回执最多列几条
const RECEIPTS_SHOWN := 6
## 342 B2：三个子页（键、字表键）
const SUBS := [["story", "commission.sub_story"], ["regular", "commission.sub_regular"], ["reputation", "commission.sub_reputation"]]
## 设施 → 字表键
const FACILITY_TEXT := {&"smithy": "smithy.title", &"tech": "meta.tab_tech", &"market": "market.title", &"bias": "bias.title", &"nursery": "nursery.title", &"alchemy": "alchemy.title", &"canteen": "canteen.title"}

## 上次看的子页（这一趟游戏里记着）
static var last_sub := "story"

var flow: GameFlow = null
var _keys: VBoxContainer = null
var _cards: VBoxContainer = null
var _key_btns: Dictionary = {}
var _sub_btns: Dictionary = {}
var _sub_pins: Dictionary = {}
var _faction: StringName = &""
var _sub := "story"
## 委托 id → 选中的配方（配方实验）
var _picks: Dictionary = {}


func setup(p_flow: GameFlow) -> void:
	flow = p_flow
	name = "CommissionPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var board := MarginContainer.new()     # 深木板垫底，内容叠在上面（121 棘轮：边距用空块）
	board.name = "Board"
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.set_tone(board, UiTheme.TONE_DARK)
	add_child(board)
	var wood := UiTheme.art(ART + "board_dark")
	if wood != null:
		board.add_child(UiTheme.nine_rect(wood, 14))
	var outer := UiTheme.hbox(0)
	board.add_child(outer)
	outer.add_child(_gap(Vector2(18, 0)))
	var inner := UiTheme.vbox(10)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(inner)
	outer.add_child(_gap(Vector2(18, 0)))
	inner.add_child(_gap(Vector2(0, 6)))
	var subs := UiTheme.hbox(10)
	inner.add_child(subs)
	for pair in SUBS:
		var key: String = pair[0]
		var b := UiTheme.make_home_button(UiText.t(pair[1]), func(): show_sub(key), false, KEY_SIZE, KEY_FONT)
		b.toggle_mode = true
		b.name = "Sub_" + key
		_sub_btns[key] = b
		var tag := _pinned(b, "pin_empty")
		_sub_pins[key] = tag.pin
		subs.add_child(tag)
	_keys = UiTheme.vbox(8)     # 342 B2 A 告示板：阵营列表去掉，留一个空列给旧引用
	_keys.visible = false
	inner.add_child(_keys)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(scroll)
	inner.add_child(_gap(Vector2(0, 10)))
	_cards = UiTheme.vbox(12)
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards)
	var listed := Commissions.listed_factions()
	_faction = listed[0].id if not listed.is_empty() else &""
	_sub = last_sub if _sub_btns.has(last_sub) else "story"
	flow.meta.changed.connect(rebuild)
	rebuild()


static func _gap(sz: Vector2) -> Control:
	var g := Control.new()
	g.custom_minimum_size = sz
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


## 一张小图（找不到就是空块，尺寸照留）
static func _pic(name_: String, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiTheme.art(ART + name_)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func emblem(faction_id: StringName, side: float) -> TextureRect:
	var r := _pic("emblem_" + String(faction_id), Vector2(side, side))
	r.name = "Emblem"
	return r


## 五颗菱点：亮几颗 = 第几档（初识 1 … 代言 5）
static func pips(lv: int) -> HBoxContainer:
	var row := UiTheme.hbox(2)
	row.name = "Pips"
	for i in Commissions.TIERS:
		row.add_child(_pic("pip_on" if i <= lv else "pip_off", Vector2(16, 16)))
	return row


## 钉在纸条上沿正中：钉子盖住纸边（纸条名字照旧，测试按它找）
static func _pinned(paper: Control, pin: String) -> PinBox:
	var v := PinBox.new()
	v.name = "Pinned_" + String(paper.name)
	v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(paper)
	v.pin = _pic(pin, PIN_SIZE)
	v.add_child(v.pin)
	return v


## 纸条在下、钉子叠在纸上沿正中（钉子最后加，画在纸上面）
class PinBox extends Container:
	var pin: TextureRect = null

	func _top() -> float:
		return maxf(0.0, PIN_SIZE.y * 0.5 - PIN_DIP)

	func _paper() -> Control:
		for c in get_children():
			if c != pin and c is Control and (c as Control).visible:
				return c as Control
		return null

	func _get_minimum_size() -> Vector2:
		var p := _paper()
		var m := p.get_combined_minimum_size() if p != null else Vector2.ZERO
		return Vector2(maxf(m.x, PIN_SIZE.x), m.y + _top())

	func _notification(what: int) -> void:
		if what != NOTIFICATION_SORT_CHILDREN:
			return
		var top := _top()
		var p := _paper()
		if p != null:
			fit_child_in_rect(p, Rect2(0, top, size.x, size.y - top))
		if pin != null:
			fit_child_in_rect(pin, Rect2((size.x - PIN_SIZE.x) * 0.5, top + PIN_DIP - PIN_SIZE.y * 0.5, PIN_SIZE.x, PIN_SIZE.y))


func show_faction(id: StringName) -> void:
	_faction = id
	rebuild()


func faction() -> StringName:
	return _faction


## 342 B2：切子页（"story" / "regular" / "reputation"）
func show_sub(key: String) -> void:
	if not _sub_btns.has(key):
		return
	_sub = key
	last_sub = key
	rebuild()


func sub() -> String:
	return _sub


## 342 B2：直接翻到某一方的剧情（声望页、没开放设施的说明板上的键）
func show_story(faction_id: StringName) -> void:
	_faction = faction_id
	show_sub("story")


func rebuild() -> void:
	if _cards == null or not is_instance_valid(_cards):
		return
	for k in _sub_btns:
		(_sub_btns[k] as Button).set_pressed_no_signal(k == _sub)
		(_sub_pins[k] as TextureRect).texture = UiTheme.art(ART + ("pin_gold" if k == _sub else "pin_empty"))
	for k in _key_btns:
		(_key_btns[k] as Button).set_pressed_no_signal(k == _faction)
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	match _sub:
		"regular":
			_build_regular()
		"reputation":
			_build_reputation()
		_:
			_build_story()


func _build_story() -> void:
	var grid := GridContainer.new()     # 三方的剧情单一起钉在板上，一排三张
	grid.name = "StoryGrid"
	grid.columns = 3
	_cards.add_child(grid)
	for f in Commissions.listed_factions():
		for d in Commissions.of_faction(f.id):
			if Commissions.is_story(d) and shown(d) and not (flow.meta.commissions.is_done(d.id) and flow.meta.commissions.state_of(d.id) != CommissionBook.TAKEN):
				grid.add_child(_card(d, STORY_W))
	var rc := _receipts()
	if rc != null:
		_cards.add_child(rc)


## 剧情卡露不露：接着的、办成过的、现在就能接的（要先选配方的那种）才露；还够不着的不露
func shown(d: CommissionDef) -> bool:
	var book := flow.meta.commissions
	var st := book.state_of(d.id)
	if st != "" or book.is_done(d.id):
		return true
	var why := Commissions.why_not(book, d)
	return why == "" or why == Commissions.WHY_PICK


## 报告 350 常规页（作者 2026-11-21 选 C 托盘）：上面告示栏 6 个钉位排两行三列（空钉位只留钉孔）；
## 下面一块浅木牌「手头 n / 3」，牌下横排三只木托盘，手头的纸条放进托盘
func _build_regular() -> void:
	var book := flow.meta.commissions
	var pins := GridContainer.new()
	pins.name = "BoardRow"
	pins.columns = BOARD_COLS
	_cards.add_child(pins)
	for f in Commissions.listed_factions():
		if Commissions.regular_open(book, f):
			continue
		var p := _paper(STORY_W)     # 没开的那方：纹章、名字、锁、差什么、五菱点
		p.name = "Regular_" + String(f.id)
		var col := UiTheme.vbox(4)
		p.add_child(col)
		var top := UiTheme.hbox(8)
		top.add_child(emblem(f.id, 40))
		var title := UiTheme.make_label(Names.of(f), 20, INK)
		title.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
		top.add_child(title)
		col.add_child(top)
		var lock_row := UiTheme.hbox(6)
		lock_row.add_child(_pic("lock", Vector2(20, 20)))
		var permit := Commissions.def(f.permit)
		lock_row.add_child(UiTheme.make_wrapped(UiText.t("commission.regular_locked") % [f.thresholds[Commissions.REGULAR_TIER], Names.of(permit) if permit != null else "—"],
			16, INK_DIM, STORY_W - 2.0 * PAD_X - 26.0))
		col.add_child(lock_row)
		col.add_child(pips(Commissions.tier_of(book, f)))
		pins.add_child(_pinned(p, "pin_empty"))
	var notes := NoticeBoard.posted(book)
	for nid in notes:     # 栏上没接的纸条
		var d := Commissions.def(StringName(nid))
		if d != null:
			pins.add_child(_card(d, STORY_W))
	var k := 0
	while pins.get_child_count() < NoticeBoard.PINS:     # 空钉位：只一个钉孔
		var hole := _pic("pin_empty", PIN_SIZE)
		var cell := CenterContainer.new()
		cell.name = "EmptyPin_%d" % k
		cell.use_top_left = false
		cell.custom_minimum_size = Vector2(STORY_W, EMPTY_PIN_H)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(hole)
		pins.add_child(cell)
		k += 1
	if notes.is_empty() and not NoticeBoard.open_factions(book).is_empty():
		_cards.add_child(UiTheme.make_label(UiText.t("commission.regular_soon"), 16, LIGHT))
	var hand := book.taken().filter(func(id: StringName) -> bool: return NoticeBoard.is_note(id))
	var plank := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_HOME_PLAQUE_SMALL, 28, 10, 28, 10)
	plank.name = "HandPlank"
	plank.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiTheme.set_tone(plank, UiTheme.TONE_LIGHT)
	var head := UiTheme.make_label(UiText.t("commission.hand") % [hand.size(), Commissions.SLOTS], 18, INK)
	head.name = "Hand"
	plank.add_child(head)
	_cards.add_child(plank)
	var trays := UiTheme.hbox(TRAY_GAP)
	trays.name = "HandRow"
	_cards.add_child(trays)
	for i in Commissions.SLOTS:
		var d: CommissionDef = Commissions.def(hand[i]) if i < hand.size() else null
		trays.add_child(_tray(i, d))


## 一只木托盘（九宫格，下沿是托盘口）；有纸条就放进去，空的只画托盘
func _tray(i: int, d: CommissionDef) -> Control:
	var tray := MarginContainer.new()
	tray.name = "Tray_%d" % i
	tray.custom_minimum_size = Vector2(STORY_W, TRAY_H)
	UiTheme.set_tone(tray, UiTheme.TONE_DARK)
	var art := UiTheme.art(ART + "hand_tray")
	if art != null:
		tray.add_child(UiTheme.nine_rect(art, TRAY_EDGES))
	if d == null:
		return tray
	var v := UiTheme.vbox(0)
	tray.add_child(v)
	v.add_child(_gap(Vector2(0, TRAY_EDGES[1])))
	var h := UiTheme.hbox(0)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	h.add_child(_gap(Vector2(TRAY_EDGES[0], 0)))
	var slip := _slip(d, STORY_W - TRAY_EDGES[0] - TRAY_EDGES[2])
	slip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(slip)
	h.add_child(_gap(Vector2(TRAY_EDGES[2], 0)))
	v.add_child(_gap(Vector2(0, TRAY_EDGES[3])))
	return tray


## 托盘里的纸条：纹章、名字；要做的事 + 进度方框；金币、声望、【交货】/【放弃】
func _slip(d: CommissionDef, w: float) -> PanelContainer:
	var book := flow.meta.commissions
	var p := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 16, 10, 16, 10)
	UiTheme.set_tone(p, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	p.name = "Card_" + String(d.id)
	var col := UiTheme.vbox(4)
	p.add_child(col)
	var top := UiTheme.hbox(8)
	top.add_child(emblem(d.faction, 32))
	var title := UiTheme.make_label(Names.of(d), 18, INK)
	title.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	top.add_child(title)
	col.add_child(top)
	var s := Commissions.current_stage(book, d.id)
	var need := maxi(1, d.stages[s].count) if s >= 0 and s < d.stages.size() else 1
	var got := int(book.entry(d.id).get("progress", 0))
	var task := UiTheme.hbox(8)
	task.add_child(UiTheme.make_wrapped(task_text(d), 16, INK, w - 32.0 - Ticks.side_for(need)))
	if need <= Ticks.MAX_BOXES:
		task.add_child(Ticks.make(got, need))
	else:
		task.add_child(UiTheme.make_label(UiText.t("commission.progress") % [got, need], 16, INK))
	col.add_child(task)
	var row := UiTheme.hbox(10)
	col.add_child(row)
	if d.funds > 0:
		row.add_child(CoinLabel.make(d.funds, 16, INK))
	row.add_child(UiTheme.make_label(UiText.t("commission.reward_rep") % Commissions.reputation_of(d), 16, INK))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fill)
	if Commissions.can_report(book, d, flow.meta):
		var rb := ScrollKey.make(UiText.t("commission.report"), func(): report(d.id))
		rb.name = "Report_" + String(d.id)
		row.add_child(rb)
	var ab := ScrollKey.make(UiText.t("commission.abandon"), func(): _do(flow.abandon_commission(d.id)))
	ab.name = "Abandon_" + String(d.id)
	row.add_child(ab)
	return p


## 进度方框：做到几个就勾几个（墨线小方框，勾用朱褐）
class Ticks extends Control:
	const MAX_BOXES := 6
	const SIDE := 13.0
	const GAP := 4.0
	var got := 0
	var need := 1

	static func side_for(n: int) -> float:
		return mini(n, MAX_BOXES) * (SIDE + GAP)

	static func make(p_got: int, p_need: int) -> Ticks:
		var t := Ticks.new()
		t.name = "Ticks"
		t.got = p_got
		t.need = p_need
		t.custom_minimum_size = Vector2(side_for(p_need), SIDE + 4.0)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t

	func _draw() -> void:
		for i in need:
			var r := Rect2(i * (SIDE + GAP), 2.0, SIDE, SIDE)
			draw_rect(r, INK, false, 1.5)
			if i < got:
				var a := r.position + Vector2(2.5, SIDE * 0.55)
				var b := r.position + Vector2(SIDE * 0.42, SIDE - 2.5)
				var c := r.position + Vector2(SIDE - 2.0, 2.5)
				draw_polyline(PackedVector2Array([a, b, c]), RED, 2.0)


func _build_reputation() -> void:
	var flow_row := HFlowContainer.new()
	flow_row.name = "RepRow"
	_cards.add_child(flow_row)
	for f in Commissions.listed_factions():
		var p := _head(f)
		p.name = "Rep_" + String(f.id)
		var col := p.get_child(0) as VBoxContainer
		col.add_child(HSeparator.new())
		var facs: Array = f.facilities.keys()
		facs.sort()
		for fac in facs:
			var key := StringName(String(fac))
			var row := UiTheme.hbox(8)
			col.add_child(row)
			var fname := UiText.t(String(FACILITY_TEXT.get(key, String(key))))
			if flow.facility_open(key):
				row.add_child(UiTheme.make_label(UiText.t("commission.facility_open") % fname, 16, INK))
				var b := ScrollKey.make(UiText.t("commission.go_facility"), func(): facility_requested.emit(key))
				b.name = "Go_" + String(key)
				row.add_child(b)
			else:
				row.add_child(_pic("lock", Vector2(20, 20)))
				var d := Commissions.def(StringName(String(f.facilities[fac])))
				row.add_child(UiTheme.make_wrapped(UiText.t("commission.facility_locked") % [fname, Names.of(d) if d != null else ""], 16, INK_DIM, STORY_W - 2.0 * PAD_X - 140.0))
				var fid := f.id
				var b := ScrollKey.make(UiText.t("commission.go_story"), func(): show_story(fid))
				b.name = "Story_" + String(key)
				row.add_child(b)
		flow_row.add_child(_pinned(p, "pin_" + String(f.id)))


func _paper(w: float = CARD_W) -> PanelContainer:
	var p := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, PAD_X, PAD_Y, PAD_X, PAD_Y)
	UiTheme.set_tone(p, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	p.custom_minimum_size.x = w
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p


## 这一方的牌头：纹章 72、名字、档名 + 五菱点、到下一档的细条（悬停写累计和还差几点）
func _head(f: FactionDef) -> PanelContainer:
	var p := _paper(STORY_W)
	p.name = "FactionHead"
	var col := UiTheme.vbox(6)
	p.add_child(col)
	var book := flow.meta.commissions
	var lv := Commissions.tier_of(book, f)
	var top := UiTheme.hbox(12)
	col.add_child(top)
	top.add_child(emblem(f.id, 72))
	var right := UiTheme.vbox(4)
	top.add_child(right)
	var title := UiTheme.make_label(Names.of(f), 22, INK)
	title.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	right.add_child(title)
	var tier := UiTheme.hbox(8)
	tier.add_child(UiTheme.make_label(UiText.t("commission.tier_%d" % lv), 16, INK))
	tier.add_child(pips(lv))
	right.add_child(tier)
	var gap := Commissions.rep_to_next(book, f)
	var lo := f.thresholds[lv] if lv < f.thresholds.size() else 0
	var hi := f.thresholds[lv + 1] if lv + 1 < f.thresholds.size() else lo
	var bar := ColorRect.new()     # 到下一档的细条：底 + 进度
	bar.name = "RepBar"
	bar.color = Color(INK_DIM, 0.25)
	bar.custom_minimum_size = Vector2(STORY_W - 2.0 * PAD_X - 90.0, 6)
	bar.tooltip_text = UiText.t("commission.rep_next") % [book.rep_of(f.id), gap] if gap > 0 else UiText.t("commission.rep") % book.rep_of(f.id)
	var fill := ColorRect.new()
	fill.color = INK
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.custom_minimum_size = Vector2(bar.custom_minimum_size.x * (1.0 if hi <= lo else clampf(float(book.rep_of(f.id) - lo) / float(hi - lo), 0.0, 1.0)), 6)
	bar.add_child(fill)
	right.add_child(bar)
	return p


func _row(col: VBoxContainer, label_key: String, text: String, w: float = CARD_W) -> void:
	if text == "":
		return
	col.add_child(UiTheme.make_wrapped("%s：%s" % [UiText.t(label_key), text], 16, INK, w - 2.0 * PAD_X))


static func where_text(d: CommissionDef) -> String:
	var parts: PackedStringArray = []
	for s in d.stages:
		var t := UiText.t("commission.where_" + String(s.where))
		if not parts.has(t):
			parts.append(t)
	return "；".join(parts)


static func task_text(d: CommissionDef) -> String:
	var parts: PackedStringArray = []
	for s in d.stages:
		parts.append(Names.pick(s.texts, s.text))
	return "；".join(parts)


## 一张任务卡（钉着这一方颜色的钉子）
func _card(d: CommissionDef, w: float = CARD_W) -> Control:
	var book := flow.meta.commissions
	var p := _paper(w)
	p.name = "Card_" + String(d.id)
	var col := UiTheme.vbox(6)
	p.add_child(col)
	var top := UiTheme.hbox(8)
	top.add_child(emblem(d.faction, 40))
	var title := UiTheme.make_wrapped(Names.of(d), 20, INK, w - 2.0 * PAD_X - 48.0)
	title.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	top.add_child(title)
	col.add_child(top)
	var quote := Names.pick(d.quotes, d.quote)
	if quote != "":
		col.add_child(UiTheme.make_wrapped("「%s」" % quote, 16, INK_DIM, w - 2.0 * PAD_X))
	var note := NoticeBoard.is_note(d.id)     # 报告 350 C：栏上的纸条只写做什么、金币和声望
	if note:
		col.add_child(UiTheme.make_wrapped(task_text(d), 16, INK, w - 2.0 * PAD_X))
	else:
		_row(col, "commission.client", Names.pick(d.clients, d.client), w)
		_row(col, "commission.task", task_text(d), w)
		_row(col, "commission.where", where_text(d), w)
	var reward := UiTheme.hbox(10)
	if not note:
		reward.add_child(UiTheme.make_label(UiText.t("commission.reward") + "：", 16, INK))
	if d.funds > 0:
		reward.add_child(CoinLabel.make(d.funds, 16, INK))
	reward.add_child(UiTheme.make_label(UiText.t("commission.reward_rep") % Commissions.reputation_of(d), 16, INK))
	col.add_child(reward)
	var st := book.state_of(d.id)
	var keys := HFlowContainer.new()
	col.add_child(keys)
	match st:
		CommissionBook.TAKEN:
			if Commissions.needs_pick(d):     # 作者 2026-11-21 选 A：接下以后写明照哪张配方、现在还差什么
				_pick_line(col, d, w)
			var s := Commissions.current_stage(book, d.id)
			var need := maxi(1, d.stages[s].count) if s >= 0 and s < d.stages.size() else 1
			if need > 1 or not Commissions.can_report(book, d, flow.meta):
				keys.add_child(UiTheme.make_label("%s　%s" % [UiText.t("commission.state_taken"), UiText.t("commission.progress") % [int(book.entry(d.id).get("progress", 0)), need]], 16, INK))
			if Commissions.can_report(book, d, flow.meta):     # 342 B2：营地当场办一次 / 交货
				var rb := ScrollKey.make(UiText.t("commission.report"), func(): report(d.id))
				rb.name = "Report_" + String(d.id)
				keys.add_child(rb)
			if not Commissions.is_story(d):     # 342 B2：剧情常驻，不暂缓、不放弃；纸条全带进局，不暂缓
				if not NoticeBoard.is_note(d.id):
					keys.add_child(ScrollKey.make(UiText.t("commission.pause"), func(): _do(flow.pause_commission(d.id))))
				var ab := ScrollKey.make(UiText.t("commission.abandon"), func(): _do(flow.abandon_commission(d.id)))
				ab.name = "Abandon_" + String(d.id)
				keys.add_child(ab)
		CommissionBook.PAUSED:
			keys.add_child(UiTheme.make_label(UiText.t("commission.state_paused"), 16, INK))
			_add_take(keys, d, UiText.t("commission.resume"))
			keys.add_child(ScrollKey.make(UiText.t("commission.abandon"), func(): _do(flow.abandon_commission(d.id))))
		_:
			if book.is_done(d.id) and d.tier != CommissionDef.TEMPLATE:
				keys.add_child(UiTheme.make_label(UiText.t("commission.state_done"), 16, INK))
			else:
				if Commissions.needs_pick(d):
					_add_pick(keys, d)
				_add_take(keys, d, UiText.t("commission.take"))
				if NoticeBoard.is_note(d.id):     # 沙漏 + 还剩几局，剩 1 局标红
					var left := int((book.notes.get(String(d.id), {}) as Dictionary).get("left", 0))
					var lrow := UiTheme.hbox(4)
					lrow.name = "Left"
					lrow.add_child(_pic("hourglass", Vector2(16, 20)))
					lrow.add_child(UiTheme.make_label(UiText.t("commission.left") % left, 16, INK_DIM))
					if left <= 1:
						lrow.modulate = RED
					keys.add_child(lrow)
	return _pinned(p, "pin_" + String(d.faction))


func _add_take(row: Container, d: CommissionDef, text: String) -> void:
	var pick := StringName(String(_picks.get(d.id, "")))
	var why := Commissions.why_not(flow.meta.commissions, d, pick, flow.commission_picks())
	var b := ScrollKey.make(text, func(): take(d.id))
	b.name = "Take_" + String(d.id)
	b.disabled = why != ""
	if why != "":
		b.tooltip_text = UiText.t("commission.why_" + why)
	row.add_child(b)


## 配方实验接下以后：照哪张配方；现在打不出就写差什么（素材不够、钱不够……）
func _pick_line(col: VBoxContainer, d: CommissionDef, w: float) -> void:
	var r := SmithRecipeDef.find(flow.smith_recipes, StringName(String(flow.meta.commissions.entry(d.id).get("pick", ""))))
	if r == null:
		return
	var out := flow.items.get_def(r.output) if flow.items != null else null
	var line := UiText.t("commission.pick_for") % (Names.of(out) if out != null else String(r.id))
	var why := Smithy.can_forge(flow.meta, r, flow.items)
	if why != "":
		line += "　" + why
	var l := UiTheme.make_wrapped(line, 16, INK_DIM, w - 2.0 * PAD_X)
	l.name = "PickFor"
	col.add_child(l)


## 配方实验：学会了的铁匠配方下拉（没有就灰着写原因）
func _add_pick(row: Container, d: CommissionDef) -> void:
	var picks := flow.commission_picks()
	var opt := OptionButton.new()
	opt.name = "Pick_" + String(d.id)
	opt.add_item(UiText.t("commission.pick"))
	opt.set_item_disabled(0, true)
	for i in picks.size():
		var r := SmithRecipeDef.find(flow.smith_recipes, picks[i])
		opt.add_item(Names.of(flow.items.get_def(r.output)) if r != null and flow.items.get_def(r.output) != null else String(picks[i]))
		opt.set_item_metadata(i + 1, String(picks[i]))
	var cur := String(_picks.get(d.id, ""))
	opt.select(0)
	for i in range(1, opt.item_count):
		if String(opt.get_item_metadata(i)) == cur:
			opt.select(i)
	opt.disabled = picks.is_empty()
	if picks.is_empty():
		opt.tooltip_text = UiText.t("commission.no_pick")
	opt.item_selected.connect(func(i: int):
		_picks[d.id] = String(opt.get_item_metadata(i)) if i > 0 else ""
		rebuild())
	row.add_child(opt)


## 接下（配方实验用选中的那张）。返回空串 = 接了
func take(id: StringName) -> String:
	var why := flow.take_commission(id, StringName(String(_picks.get(id, ""))))
	if why == "":
		_picks.erase(id)
		changed.emit()
	rebuild()
	return why


## 342 B2：【办理】（营地当场那一步）。返回 [method GameFlow.report_commission] 的结果
func report(id: StringName) -> Dictionary:
	var got := flow.report_commission(id)
	if bool(got.get("ok", false)):
		changed.emit()
		reported.emit(got)
	rebuild()
	return got


## 测试 / 键用：选一张配方
func set_pick(id: StringName, recipe: StringName) -> void:
	_picks[id] = String(recipe)
	rebuild()


func _do(ok: bool) -> void:
	if ok:
		changed.emit()
	rebuild()


## 回执：这一方最近几条（谁收到了什么、哪一步要重做）
func _receipts() -> PanelContainer:
	var rows: Array = []
	for r in flow.meta.commissions.receipts:
		var d := Commissions.def(StringName(String(r.get("id", ""))))
		if d != null and d.faction == _faction:
			rows.append(receipt_text(r))
		if rows.size() >= RECEIPTS_SHOWN:
			break
	if rows.is_empty():
		return null
	var p := _paper()
	p.name = "Receipts"
	var col := UiTheme.vbox(4)
	p.add_child(col)
	var head := UiTheme.make_label(UiText.t("commission.receipts"), 18, INK)
	head.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	col.add_child(head)
	for t in rows:
		col.add_child(UiTheme.make_wrapped(String(t), 15, INK_DIM, CARD_W - 2.0 * PAD_X))
	return p


static func receipt_text(r: Dictionary) -> String:
	var d := Commissions.def(StringName(String(r.get("id", ""))))
	return UiText.t("commission.rcpt_" + String(r.get("kind", "done"))) % (Names.of(d) if d != null else String(r.get("name", "")))
