extends SceneTree
## 游戏测试 v6.82：《照抄也要做得出》先接单、后凑料。参数 <outdir> [seed]
## 新档拒教程 → 测试辅助办完三份开放单 → 委托页真点「剧情」→ 看卡：配方下拉列哪些、【接下】灰不灰 →
## 真选一张现在打不出的配方 → 真点【接下】→ 卡上写照哪张、还差什么 → 测试辅助补料补钱，照这张打一次 → 回委托页看办成
var out := ""
var seed_ := 31
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _shots := 0
var _runs := 0
var _snap := ""
var _rep_before := {}
var _handin := ""
var _rid := &""
const COPY := &"society_copy_recipe"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: seed_ = int(a[1])
	DirAccess.make_dir_recursive_absolute(out)
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func L(s: String) -> void:
	print("C682 " + s)


func shot(n: String) -> void:
	_shots += 1
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/board_%02d_%s.png" % [out, _shots, n])


func _mouse_at(p_canvas: Vector2, button: int) -> void:
	var c := root.get_final_transform() * p_canvas
	Input.warp_mouse(c)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = down
		e.position = c
		e.global_position = c
		Input.parse_input_event(e)


func _click(b: Control) -> void:
	var p := b.get_parent()
	while p != null:
		if p is ScrollContainer:
			(p as ScrollContainer).ensure_control_visible(b)
			break
		p = p.get_parent()
	_mouse_at(b.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)


func _named(nm: String) -> Control:
	for n in root.find_children(nm, "Control", true, false):
		if (n as Control).is_visible_in_tree(): return n
	return null


func _all_named(pat: String) -> Array:
	var o := []
	for n in root.find_children(pat, "Control", true, false):
		if (n as Control).is_visible_in_tree(): o.append(n)
	return o


func _labels_under(n: Node) -> String:
	if n == null: return "（无）"
	var o := []
	for l in n.find_children("*", "", true, false):
		if not (l is Label or l is RichTextLabel or l is Button) or not (l as Control).is_visible_in_tree(): continue
		var t: String = (l as RichTextLabel).get_parsed_text() if l is RichTextLabel else ((l as Button).text if l is Button else (l as Label).text)
		if t.strip_edges() != "": o.append(("[%s]" if l is Button else "%s") % t.strip_edges().replace("\n", " "))
	return " / ".join(o)


func _ms() -> Node:
	return _game.base()


func _panel() -> Node:
	return _ms().commission_panel() if _ms() != null and _ms().has_method("commission_panel") else null


func _reps() -> String:
	var b := _flow.meta.commissions
	var o := []
	for f in Commissions.factions():
		o.append("%s %d" % [Names.of(f), b.rep_of(f.id)])
	return "、".join(o)


func _note_line(nid: String) -> String:
	var b := _flow.meta.commissions
	var n: Dictionary = b.notes.get(nid, {})
	var d := Commissions.def(StringName(nid))
	return "%s「%s」%s×%d 档%d 酬%d 剩%s 局 %s" % [nid, Names.of(d) if d != null else "?", String(n.get("faction", "")), int(n.get("count", 0)),
		int(n.get("band", 0)), int(n.get("funds", 0)), str(n.get("left", "-")), b.state_of(StringName(nid))]


func _board() -> String:
	var b := _flow.meta.commissions
	var pins := []
	for nid in b.pins:
		pins.append("·" if String(nid) == "" else String(nid))
	var hand := b.taken().filter(func(id): return NoticeBoard.is_note(id)).map(func(id): return _note_line(String(id)))
	var posted := NoticeBoard.posted(b).map(func(id): return _note_line(id))
	return "局数 %d；钉位 %s；栏上没接 %d：%s；手头 %d：%s" % [_flow.meta.runs, " ".join(pins), posted.size(), "；".join(posted), hand.size(), "；".join(hand)]


func _snapshot() -> String:
	var b := _flow.meta.commissions
	return JSON.stringify([b.pins, b.notes, b.taken()])


func _tab(key: String) -> void:
	_click(_ms()._tab_btns[key])


func _put(id: String) -> void:
	var d := _flow.items.get_def(StringName(id))
	if d == null: L("没有道具 %s" % id); return
	var it := ItemInstance.create(d, 0)
	it.uid = _flow.meta.allocate_uid()
	_flow.meta.warehouse.try_add(it)


func _fits(nid: String) -> Array:
	var d := Commissions.def(StringName(nid))
	var st: CommissionStage = d.stages[0]
	var ids := _flow.items.ids().filter(func(id): return Commissions.hand_in_fits(st, _flow.items.get_def(id)))
	ids.sort_custom(func(a, b): return _flow.items.get_def(a).rarity < _flow.items.get_def(b).rarity)
	return ids


func _card() -> Control:
	return _named("Card_society_copy_recipe")


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 8000:
		L("超时 st %d" % _st); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	var scr := _flow.screen
	match _st:
		0:
			if _f < 60: return false
			_flow.start_new_game(); _st = 1
		1:
			var b = _game.base()
			if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open():
				b.decline_tutorial(); _wait = 30; _st = 2
			elif _f > 240:
				_flow.decline_tutorial(); _wait = 30; _st = 2
		2:
			if scr != GameFlow.Screen.META: return false
			L("新档：仓库 %d 件；金币 %d；学会的可选配方 %s" % [_flow.meta.warehouse.item_count(), _flow.meta.funds, str(_flow.commission_picks())])
			for id in [&"legion_forge_token", &"society_first_survey", &"greylamp_check_scale"]:
				_flow.report_commission(id)
			_flow.sync_commissions(); _flow.save_meta()
			L("测试辅助办完三份开放单：《照抄》%s，没选配方时 why_not「%s」" % [_flow.meta.commissions.state_of(COPY), Commissions.why_not(_flow.meta.commissions, Commissions.def(COPY), &"", _flow.commission_picks())])
			_tab("commissions"); _wait = 20; _st = 3
		3:
			_click(_named("Sub_story")); _wait = 20; _st = 4
		4:
			var c := _card()
			if c == null: L("剧情页上没有《照抄》的卡：%s" % _labels_under(_panel()).left(800)); shot("no_card"); _st = 99; return false
			var opt := _named("Pick_society_copy_recipe") as OptionButton
			var items := []
			if opt != null:
				for i in opt.item_count: items.append(opt.get_item_text(i) + ("（灰）" if opt.is_item_disabled(i) else ""))
			var tk := _named("Take_society_copy_recipe")
			L("真点「剧情」：卡上 %s" % _labels_under(c))
			L("　　配方下拉 %s：%s；【接下】灰 %s「%s」" % ["灰" if opt != null and opt.disabled else "可选", str(items), str((tk as BaseButton).disabled) if tk != null else "-", tk.tooltip_text if tk != null else ""])
			L("　　排版：%s" % _overflow(_panel()))
			shot("copy_card")
			# 选一张只要固定素材、现在打不出的
			var pick_i := -1
			if opt != null:
				for i in range(1, opt.item_count):
					var r := SmithRecipeDef.find(_flow.smith_recipes, StringName(String(opt.get_item_metadata(i))))
					if r != null and r.slots().is_empty() and Smithy.can_forge(_flow.meta, r, _flow.items) != "":
						pick_i = i; break
			if pick_i < 0: L("下拉里没有现在打不出、只要固定素材的配方"); _st = 99; return false
			_rid = StringName(String(opt.get_item_metadata(pick_i)))
			L("真选第 %d 项「%s」（%s）：现在打不出「%s」" % [pick_i, opt.get_item_text(pick_i), _rid, Smithy.can_forge(_flow.meta, SmithRecipeDef.find(_flow.smith_recipes, _rid), _flow.items)])
			opt.select(pick_i); opt.item_selected.emit(pick_i)
			_wait = 20; _st = 5
		5:
			var tk := _named("Take_society_copy_recipe")
			L("选好后【接下】灰 %s「%s」" % [str((tk as BaseButton).disabled) if tk != null else "-", tk.tooltip_text if tk != null else ""])
			if tk == null or (tk as BaseButton).disabled: shot("take_grey"); _st = 99; return false
			_click(tk); _wait = 25; _st = 6
		6:
			var bk := _flow.meta.commissions
			L("真点【接下】后：《照抄》%s；记下的配方「%s」" % [bk.state_of(COPY), String(bk.entry(COPY).get("pick", ""))])
			var pf := _named("PickFor")
			L("　　卡上：%s" % _labels_under(_card()))
			L("　　照配方一行：「%s」" % ((pf as Label).text if pf != null else "（没有）"))
			L("　　排版：%s" % _overflow(_panel()))
			shot("copy_taken")
			var r := SmithRecipeDef.find(_flow.smith_recipes, _rid)
			_flow.meta.funds += 100000
			for key in r.inputs:
				for _i in int(r.inputs[key]): _put(String(key))
			_flow.meta.changed.emit()
			L("测试辅助补料补钱：现在打得出「%s」" % Smithy.can_forge(_flow.meta, r, _flow.items))
			_wait = 20; _st = 7
		7:
			var pf := _named("PickFor")
			L("补齐后卡上照配方一行：「%s」" % ((pf as Label).text if pf != null else "（没有）"))
			var why := _flow.forge(_rid)
			L("测试辅助照这张打一次：「%s」；《照抄》%s" % [why, _flow.meta.commissions.state_of(COPY)])
			_flow.meta.changed.emit()
			_wait = 20; _st = 8
		8:
			L("回委托页：%s" % _labels_under(_panel()).left(800))
			shot("copy_after_forge")
			_st = 99
		_:
			quit(0); return true
	return false


## 排版溢出：可见的字落在它最近的 PanelContainer 外，或者不换行的字比自己的框宽
func _overflow(top: Node) -> String:
	if top == null: return "（无）"
	var bad := []
	var n_checked := 0
	for l in top.find_children("*", "", true, false):
		if not (l is Label or l is Button or l is RichTextLabel) or not (l as Control).is_visible_in_tree(): continue
		var c := l as Control
		n_checked += 1
		var r := c.get_global_rect()
		var p := c.get_parent()
		while p != null and not (p is PanelContainer): p = p.get_parent()
		var t: String = (l as RichTextLabel).get_parsed_text() if l is RichTextLabel else ((l as Button).text if l is Button else (l as Label).text)
		t = t.strip_edges().replace("\n", " ").left(24)
		if p != null and p != c and not (p as Control).get_global_rect().grow(2).encloses(r):
			bad.append("「%s」出 %s 框（字 %s，框 %s）" % [t, p.name, str(r), str((p as Control).get_global_rect())])
		elif l is Label and (l as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and (l as Label).text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and c.get_minimum_size().x > c.size.x + 1:
			bad.append("「%s」比自己的框宽（%d > %d）" % [t, int(c.get_minimum_size().x), int(c.size.x)])
	return "查 %d 处，溢出 %d：%s" % [n_checked, bad.size(), "；".join(bad.slice(0, 8))]