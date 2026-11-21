extends SceneTree
## 游戏测试 v6.75（报告 350）：参数 <outdir> <seed>
## 新档拒教程 → 测试辅助：三份开放单办理、其余剧情记办成、三方声望到 25、三份许可单办成 → sync（第一次贴栏）
## → 真点「委托」「常规」看栏 → 真点【接下】三张（第四张应灰）→ 存档回主菜单再继续（栏不变）
## → 一局一局测试辅助撤离（共 4 局），每局回营记：到期撤下、补位、栏上没接的 ≥ 2、手头不动
## → 第一局后真点【放弃】一张（不回栏、不扣声望），接下一张交货单，测试辅助放材料，真点【办理】
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
	print("B675 " + s)


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


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 40000:
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
			var bk := _flow.meta.commissions
			for id in [&"legion_forge_token", &"society_first_survey", &"greylamp_check_scale"]:
				_flow.report_commission(id)
			L("办完开放单：%s；栏 %s" % [_reps(), _board()])
			for d in Commissions.defs():
				if not Commissions.is_story(d) or String(d.id).ends_with("_permit") or bk.is_done(d.id): continue
				if not bk.taken().has(d.id): Commissions.take(bk, d)
				Commissions._complete(_flow.meta, d, _flow.items)
			L("其余剧情记办成后：%s；栏 %s" % [_reps(), _board()])
			for f in Commissions.factions():
				if bk.rep_of(f.id) < 25: bk.rep[String(f.id)] = 25
			L("三方声望补到 25：%s；常规开放 %s；栏 %s" % [_reps(), str(Commissions.factions().map(func(f): return Commissions.regular_open(bk, f))), _board()])
			for f in Commissions.factions():
				if f.permit == &"": continue
				var d := Commissions.def(f.permit)
				if not bk.taken().has(d.id): Commissions.take(bk, d)
				Commissions._complete(_flow.meta, d, _flow.items)
			_flow.sync_commissions(); _flow.save_meta()
			L("三份许可单办成、sync 后：%s；常规开放 %s" % [_reps(), str(Commissions.factions().map(func(f): return Commissions.regular_open(bk, f)))])
			L("　　%s" % _board())
			_tab("commissions"); _wait = 20; _st = 3
		3:
			_click(_named("Sub_regular")); _wait = 20; _st = 4
		4:
			L("真点「常规」：%s" % _labels_under(_panel()).left(1500))
			L("　　排版：%s" % _overflow(_panel()))
			L("　　托盘：%s" % _trays())
			shot("board_first")
			_st = 5
		5:
			var hand := _flow.meta.commissions.taken().filter(func(id): return NoticeBoard.is_note(id)).size()
			var takes := _all_named("Take_note_*")
			if hand >= 3:
				var dis := takes.map(func(b): return "%s 灰 %s「%s」" % [b.name, str((b as BaseButton).disabled), (b as Control).tooltip_text])
				L("手头满 3：剩下的【接下】%s" % str(dis))
				L("　　%s" % _board())
				L("　　页上：%s" % _labels_under(_panel()).left(1500))
				L("　　排版：%s" % _overflow(_panel()))
				L("　　托盘：%s" % _trays())
				shot("hand_full")
				_snap = _snapshot()
				_flow.save_meta(); _flow.to_main_menu(); _wait = 30; _st = 7
				return false
			if takes.is_empty(): L("没有【接下】可点"); _st = 7; return false
			var b: Control = takes[0]
			L("真点 %s（%s）" % [b.name, _note_line(String(b.name).trim_prefix("Take_"))])
			_click(b); _wait = 25
		7:
			_flow.continue_game(); _wait = 40; _st = 8
		8:
			if scr != GameFlow.Screen.META: return false
			L("回主菜单再继续：栏 %s" % ("不变" if _snapshot() == _snap else "变了：" + _board()))
			_st = 20
		# ---------- 一局一局 ----------
		20:
			if _runs >= 4: _st = 60; return false
			_snap = _board()
			var ch := _flow.chapter_of(&"free_mode")
			_flow.begin_direct(ch, seed_ + _runs); _wait = 30; _st = 21
		21:
			if scr == GameFlow.Screen.EVENT and bool(_flow.last_payload.get("briefing", false)):
				_flow.close_briefing(); _wait = 10; return false
			if _flow.run == null: return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				for n in root.find_children("*", "", true, false):
					if n.has_method("pick_spawn"):
						n.pick_spawn(_flow.run.map.entry_ids[0]); break
				_wait = 20; return false
			if scr != GameFlow.Screen.MAP: return false
			L("第 %d 局（种子 %d）进图，测试辅助撤离：%s" % [_runs + 1, seed_ + _runs, str(_flow.run.force_extract())])
			_flow._flush(); _wait = 60; _st = 22
		22:
			if scr != GameFlow.Screen.RESULT: return false
			_flow.finish_result(); _wait = 40; _st = 23
		23:
			if scr != GameFlow.Screen.META: return false
			_runs += 1
			L("第 %d 局回营前：%s" % [_runs, _snap])
			L("　　回营后：%s" % _board())
			if _runs == 1: _st = 30
			elif _runs == 2 and _handin != "": _st = 50
			else: _st = 20
		# ---------- 放弃一张、接一张交货单并办理 ----------
		30:
			_tab("commissions"); _wait = 20; _st = 31
		31:
			_click(_named("Sub_regular")); _wait = 20; _st = 32
		32:
			L("第一局回营的常规页：%s" % _labels_under(_panel()).left(1500))
			L("　　排版：%s" % _overflow(_panel()))
			shot("after_run1")
			var ab := _all_named("Abandon_note_*")
			if ab.is_empty(): L("没有【放弃】"); _st = 34; return false
			var b: Control = ab[0]
			for x in ab:
				var nid := String(x.name).trim_prefix("Abandon_")
				if String((_flow.meta.commissions.notes.get(nid, {}) as Dictionary).get("goal", "")) != "hand_in": b = x; break
			_rep_before = _flow.meta.commissions.rep.duplicate()
			_handin = String(b.name).trim_prefix("Abandon_")
			L("真点 %s（%s）" % [b.name, _note_line(_handin)])
			_click(b); _wait = 25; _st = 33
		33:
			var bk := _flow.meta.commissions
			L("　　放弃后：纸条还在簿里 %s；在钉位 %s；声望 %s（之前 %s）" % [str(bk.notes.has(_handin)), str(bk.pins.has(_handin)), str(bk.rep), str(_rep_before)])
			L("　　%s" % _board())
			_handin = ""
			_st = 34
		34:
			var bk := _flow.meta.commissions
			var cand := ""
			for nid in NoticeBoard.posted(bk):
				if String((bk.notes[nid] as Dictionary).get("goal", "")) == "hand_in": cand = nid; break
			if cand == "":
				for id in bk.taken():
					if NoticeBoard.is_note(id) and String((bk.notes[String(id)] as Dictionary).get("goal", "")) == "hand_in": cand = String(id); break
				if cand == "": L("栏上和手头都没有交货单"); _st = 20; return false
				_handin = cand; _st = 36; return false
			var tb := _named("Take_" + cand)
			if tb == null: L("找不到 Take_%s" % cand); _st = 20; return false
			L("真点 %s（%s）" % [tb.name, _note_line(cand)])
			_handin = cand
			_click(tb); _wait = 25; _st = 36
		36:
			var ids := _fits(_handin)
			var n := int((_flow.meta.commissions.notes[_handin] as Dictionary).get("count", 1))
			if ids.is_empty(): L("没有合格的材料"); _st = 20; return false
			for i in n: _put(String(ids[0]))
			_ms()._refresh(); _flow.meta.changed.emit()
			L("测试辅助：仓库放 %d 件 %s（合格的有 %s）" % [n, ids[0], str(ids.slice(0, 6))])
			_click(_named("Sub_story")); _wait = 10; _st = 37
		37:
			_click(_named("Sub_regular")); _wait = 20; _st = 38
		38:
			var rb := _named("Report_" + _handin)
			_rep_before = {"funds": _flow.meta.funds, "rep": _flow.meta.commissions.rep.duplicate()}
			L("交货单页：%s" % _labels_under(_named("Card_" + _handin)))
			if rb == null: L("没有【办理】"); _st = 20; return false
			shot("handin_before")
			_click(rb); _wait = 30; _st = 39
		39:
			var bk := _flow.meta.commissions
			L("　　真点【办理】后：状态 %s；金币 %d → %d；声望 %s → %s；回执末条 %s" % [bk.state_of(StringName(_handin)), int(_rep_before["funds"]), _flow.meta.funds,
				str(_rep_before["rep"]), str(bk.rep), str(bk.receipts.slice(0, 1))])
			L("　　回执文字：%s" % CommissionPanelScript.receipt_text(bk.receipts[0]) if not bk.receipts.is_empty() else "（无回执）")
			L("　　%s" % _board())
			L("　　排版：%s" % _overflow(_panel()))
			shot("handin_after")
			_st = 20
		50:
			var bk := _flow.meta.commissions
			L("办成那张下一局结算后：簿里还有 %s；回执文字 %s" % [str(bk.notes.has(_handin)), str(bk.receipts.slice(0, 3).map(func(r): return CommissionPanelScript.receipt_text(r)))])
			_st = 20
		60:
			_tab("commissions"); _wait = 20; _st = 61
		61:
			_click(_named("Sub_regular")); _wait = 20; _st = 62
		62:
			L("四局后的常规页：%s" % _labels_under(_panel()).left(1500))
			L("　　排版：%s" % _overflow(_panel()))
			shot("after_run4")
			_st = 99
		_:
			quit(0); return true
	return false


const CommissionPanelScript := preload("res://ui/game/commission_panel.gd")


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


## C 托盘：手头木牌字、三只托盘、纸条在不在托盘里、空钉位几个
func _trays() -> String:
	var o := []
	var plank := _named("HandPlank")
	var hand := _named("Hand")
	o.append("木牌「%s」%s" % [(hand as Label).text if hand != null else "-", "字在牌里" if plank != null and hand != null and plank.get_global_rect().grow(1).encloses(hand.get_global_rect()) else "字出牌/没牌"])
	for i in 3:
		var t := _named("Tray_%d" % i)
		if t == null: o.append("托盘 %d 没有" % i); continue
		var cards := t.find_children("Card_*", "Control", true, false)
		if cards.is_empty(): o.append("托盘 %d 空 %s" % [i, str(t.get_global_rect().size)]); continue
		var c := cards[0] as Control
		o.append("托盘 %d：%s 在盘里 %s" % [i, String(c.name).trim_prefix("Card_"), str(t.get_global_rect().grow(1).encloses(c.get_global_rect()))])
	o.append("空钉位 %d" % _all_named("EmptyPin_*").size())
	return "；".join(o)
