## 336 W1（阵营与委托，报告 335 第五节）：基地「委托」页 —— 左列各方的键（首版三方），右边这一方的任务卡与回执。
##
## 任务卡五栏：替谁办、做什么、在哪完成（营地当场 / 局内现场 / 要带回）、报酬（金币图 + 声望）、状态与进度；
## 键：接下 / 暂缓 / 接着做 / 放弃。配方实验接单前要选一张「现在能打」的铁匠配方。
## 占位美术：卡和回执都是羊皮纸条（浅底墨字，[constant UiTheme.PANEL_PARCHMENT]），样张由 UI设计 出
extends HBoxContainer

signal changed()

const KEY_SIZE := Vector2(260, 48)
const KEY_FONT := 18
const KEYS_GAP := 20.0
const CARD_W := 640.0
const PAD_X := 26
const PAD_Y := 14
const INK := Color("2e2219")
const INK_DIM := Color("5a4a3a")
## 回执最多列几条
const RECEIPTS_SHOWN := 6

var flow: GameFlow = null
var _keys: VBoxContainer = null
var _cards: VBoxContainer = null
var _key_btns: Dictionary = {}
var _faction: StringName = &""
## 委托 id → 选中的配方（配方实验）
var _picks: Dictionary = {}


func setup(p_flow: GameFlow) -> void:
	flow = p_flow
	name = "CommissionPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keys = UiTheme.vbox(8)
	add_child(_keys)
	for f in Commissions.listed_factions():
		var fid := f.id
		var b := UiTheme.make_home_button(Names.of(f), func(): show_faction(fid), false, KEY_SIZE, KEY_FONT)
		b.toggle_mode = true
		_key_btns[fid] = b
		_keys.add_child(b)
	var gap := Control.new()     # 键列和卡之间留空（121 棘轮：不贴样式）
	gap.custom_minimum_size.x = KEYS_GAP
	add_child(gap)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_cards = UiTheme.vbox(12)
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards)
	var listed := Commissions.listed_factions()
	_faction = listed[0].id if not listed.is_empty() else &""
	flow.meta.changed.connect(rebuild)
	rebuild()


func show_faction(id: StringName) -> void:
	_faction = id
	rebuild()


func faction() -> StringName:
	return _faction


func rebuild() -> void:
	if _cards == null or not is_instance_valid(_cards):
		return
	for k in _key_btns:
		(_key_btns[k] as Button).set_pressed_no_signal(k == _faction)
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	var f := Commissions.faction(_faction)
	if f == null:
		return
	_cards.add_child(_head(f))
	for d in Commissions.of_faction(_faction):
		if Commissions.why_not(flow.meta.commissions, d) == Commissions.WHY_HIDDEN:
			continue
		_cards.add_child(_card(d))
	var rc := _receipts()
	if rc != null:
		_cards.add_child(rc)


func _paper() -> PanelContainer:
	var p := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, PAD_X, PAD_Y, PAD_X, PAD_Y)
	UiTheme.set_tone(p, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	p.custom_minimum_size.x = CARD_W
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p


## 这一方的牌头：名字、几级、声望（离下一级还差几点）
func _head(f: FactionDef) -> PanelContainer:
	var p := _paper()
	p.name = "FactionHead"
	var col := UiTheme.vbox(4)
	p.add_child(col)
	var book := flow.meta.commissions
	var lv := Commissions.tier_of(book, f)
	var title := UiTheme.make_label("%s · %s" % [Names.of(f), UiText.t("commission.tier_%d" % lv)], 22, INK)
	title.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	col.add_child(title)
	var gap := Commissions.rep_to_next(book, f)
	col.add_child(UiTheme.make_label(UiText.t("commission.rep_next") % [book.rep_of(f.id), gap] if gap > 0 else UiText.t("commission.rep") % book.rep_of(f.id), 16, INK_DIM))
	return p


func _row(col: VBoxContainer, label_key: String, text: String) -> void:
	if text == "":
		return
	col.add_child(UiTheme.make_wrapped("%s：%s" % [UiText.t(label_key), text], 16, INK, CARD_W - 2.0 * PAD_X))


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


## 一张任务卡
func _card(d: CommissionDef) -> PanelContainer:
	var book := flow.meta.commissions
	var p := _paper()
	p.name = "Card_" + String(d.id)
	var col := UiTheme.vbox(6)
	p.add_child(col)
	var title := UiTheme.make_label(Names.of(d), 20, INK)
	title.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	col.add_child(title)
	var quote := Names.pick(d.quotes, d.quote)
	if quote != "":
		col.add_child(UiTheme.make_wrapped("「%s」" % quote, 16, INK_DIM, CARD_W - 2.0 * PAD_X))
	_row(col, "commission.client", Names.pick(d.clients, d.client))
	_row(col, "commission.task", task_text(d))
	_row(col, "commission.where", where_text(d))
	var reward := UiTheme.hbox(10)
	reward.add_child(UiTheme.make_label(UiText.t("commission.reward") + "：", 16, INK))
	if d.funds > 0:
		reward.add_child(CoinLabel.make(d.funds, 16, INK))
	reward.add_child(UiTheme.make_label(UiText.t("commission.reward_rep") % Commissions.reputation_of(d), 16, INK))
	col.add_child(reward)
	var st := book.state_of(d.id)
	var keys := UiTheme.hbox(12)
	col.add_child(keys)
	match st:
		CommissionBook.TAKEN:
			var s := Commissions.current_stage(book, d.id)
			var need := maxi(1, d.stages[s].count) if s >= 0 and s < d.stages.size() else 1
			keys.add_child(UiTheme.make_label("%s　%s" % [UiText.t("commission.state_taken"), UiText.t("commission.progress") % [int(book.entry(d.id).get("progress", 0)), need]], 16, INK))
			keys.add_child(ScrollKey.make(UiText.t("commission.pause"), func(): _do(flow.pause_commission(d.id))))
			keys.add_child(ScrollKey.make(UiText.t("commission.abandon"), func(): _do(flow.abandon_commission(d.id))))
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
	return p


func _add_take(row: HBoxContainer, d: CommissionDef, text: String) -> void:
	var pick := StringName(String(_picks.get(d.id, "")))
	var why := Commissions.why_not(flow.meta.commissions, d, pick, flow.commission_picks())
	var b := ScrollKey.make(text, func(): take(d.id))
	b.name = "Take_" + String(d.id)
	b.disabled = why != ""
	if why != "":
		b.tooltip_text = UiText.t("commission.why_" + why)
	row.add_child(b)


## 配方实验：现在能打的铁匠配方下拉（没有就灰着写原因）
func _add_pick(row: HBoxContainer, d: CommissionDef) -> void:
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
	return UiText.t("commission.rcpt_" + String(r.get("kind", "done"))) % Names.of(d)
