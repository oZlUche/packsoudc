extends SceneTree
## 游戏测试 v8.55（PR #926）：常规委托去掉声望上限 50。参数 <outdir>
## 新档拒教程 → 测试辅助：灰灯到营地、剧情办到开常规、声望设 45、告示栏贴满 → 常规页真点【接下】→ 测试辅助记满进度 →
## 真点【完成】，记声望；一直做到过 100 → 看节点、食堂锅和仓库、可领赠礼 → 声望页真点【赠礼】【领取】→ 存档里的声望
const TAG := "CM926"
var _id: StringName = &""
var _rep0 := 0
var _rounds := 0
var _after100 := 0
var _shot50 := false
var _shot100 := false
var _funds0 := 0
var out := ""
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _shots := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func L(s: String) -> void:
	print(TAG + " " + s)


func shot(n: String) -> void:
	_shots += 1
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/%s_%02d_%s.png" % [out, TAG.to_lower(), _shots, n])


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


func _hover_at(p_canvas: Vector2) -> void:
	var c := root.get_final_transform() * p_canvas
	Input.warp_mouse(c)
	var e := InputEventMouseMotion.new()
	e.position = c
	e.global_position = c
	Input.parse_input_event(e)


func _click(b: Control) -> void:
	if b == null: L("（要点的键不在）"); return
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


func _tab(key: String) -> void:
	_click(_ms()._tab_btns[key])


func _put(id: String, grid = null) -> ItemInstance:
	var d := _flow.items.get_def(StringName(id))
	if d == null: L("（道具库没有 %s）" % id); return null
	var inst := ItemInstance.create(d, 0)
	inst.uid = _flow.meta.allocate_uid()
	var g = grid if grid != null else _flow.meta.warehouse
	if g is Canteen: (g as Canteen).stash(inst)
	else: g.try_add(inst)
	return inst


func _ids(g) -> Array:
	return g.items().map(func(i): return String((i as ItemInstance).def.id))


## 新档、拒教程，到营地返回 true
func _boot() -> bool:
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
			if _flow.screen == GameFlow.Screen.META: return true
	return false


## 测试辅助：把 [param ids] 这几份委托直接记办成（前置一并办），声望补到 [param rep]
func _assist_done(ids: Array, faction: StringName = &"", rep: int = 0) -> void:
	var bk := _flow.meta.commissions
	for id in ids:
		var d := Commissions.def(StringName(id))
		if d == null or bk.state_of(d.id) == CommissionBook.DONE: continue
		if not bk.taken().has(d.id) and bk.state_of(d.id) != CommissionBook.READY: Commissions.take(bk, d)
		Commissions._complete(_flow.meta, d, _flow.items)
	if faction != &"":
		while bk.rep_of(faction) < rep: bk.rep[String(faction)] = bk.rep_of(faction) + 1
	_flow.sync_commissions(); _flow.save_meta(); _flow.meta.changed.emit()


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
			bad.append("「%s」出 %s 框" % [t, p.name])
		elif l is Label and (l as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and (l as Label).text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and c.get_minimum_size().x > c.size.x + 1:
			bad.append("「%s」比自己的框宽（%d > %d）" % [t, int(c.get_minimum_size().x), int(c.size.x)])
	return "查了 %d 处，%s" % [n_checked, "没有溢出" if bad.is_empty() else "溢出 %d：%s" % [bad.size(), "；".join(bad.slice(0, 6))]]

const F := &"greylamp"
const STORY := ["greylamp_check_scale", "greylamp_unsigned_letter", "greylamp_check_medkits", "greylamp_permit", "greylamp_canteen"]


func _bk() -> CommissionBook:
	return _flow.meta.commissions


func _nodes_line() -> String:
	var f := Commissions.faction(F)
	var got := []
	for n in Commissions.nodes_of(f):
		got.append("%s@%d%s" % [String(n.get("id", "?")), int(n.get("rep", 0)), "✓" if Commissions.reached(_bk(), f, n) else "✗"])
	return " ".join(got)


func _cp() -> Control:
	return _ms().commission_panel()


func _btn(name_: String) -> Button:
	var cp := _cp()
	if cp == null: return null
	var n := cp.find_child(name_, true, false)
	return n as Button if n is Button and (n as Button).is_visible_in_tree() else null


func _first_take() -> Button:
	for b in _cp().find_children("Take_*", "", true, false):
		if b is Button and (b as Button).is_visible_in_tree() and not (b as Button).disabled: return b
	return null


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 12000:
		L("超时 st %d 屏 %d" % [_st, _flow.screen]); shot("timeout"); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	if _st < 3:
		if _boot(): _st = 3
		return false
	match _st:
		3:
			var bk := _bk()
			for f in Commissions.factions(): bk.arrived[String(f.id)] = 0
			_assist_done(STORY)
			L("测试辅助：灰灯剧情办到《%s》，声望 %d；常规开了：%s" % [STORY[-1], bk.rep_of(F), str(Commissions.regular_open(bk, Commissions.faction(F)))])
			bk.rep[String(F)] = 45
			var n := NoticeBoard.first_fill(_flow.meta)
			_flow.sync_commissions(); _flow.save_meta(); _flow.meta.changed.emit()
			L("测试辅助：声望设成 45；告示栏贴了 %d 张；节点 %s" % [n, _nodes_line()])
			L("　　食堂：%s；可领赠礼 %d（每 %d 声望一份）" % [str(Canteen.sizes(_flow.meta)), Commissions.gifts_due(_flow.meta, Commissions.faction(F)), Commissions.gift_every(Commissions.faction(F))])
			_tab("commissions"); _wait = 40; _st = 4
		4:
			var cp := _cp()
			if cp.sub() != "regular": cp.show_sub("regular"); _wait = 20; return false
			if NoticeBoard.posted(_bk()).is_empty():
				var r := RandomNumberGenerator.new(); r.seed = _rounds
				var k := 0
				while k < 4 and NoticeBoard._post(_bk(), r): k += 1
				L("　　（栏上空了，测试辅助补贴 %d 张）" % k)
				cp.rebuild(); _wait = 20; return false
			var tb := _first_take()
			if tb == null: L("常规页没有能点的【接下】：%s" % _labels_under(cp).left(600)); shot("no_take"); _st = 20; return false
			_id = StringName(String(tb.name).trim_prefix("Take_"))
			var d := Commissions.def(_id)
			_rep0 = _bk().rep_of(F)
			if _rounds == 0:
				L("常规页：%s；排版 %s" % [_labels_under(cp).left(500), _overflow(cp)])
				shot("regular")
			L("第 %d 份：%s（%s，给声望 %d）真点【%s】" % [_rounds + 1, Names.of(d), String(d.faction), Commissions.reputation_of(d), tb.text])
			_click(tb); _wait = 25; _st = 5
		5:
			var d := Commissions.def(_id)
			var st0 := _bk().state_of(_id)
			if st0 != CommissionBook.TAKEN: L("　　没接上：状态「%s」" % st0); shot("take_fail"); _st = 20; return false
			var i := 0
			while _bk().state_of(_id) == CommissionBook.TAKEN and i < 50:
				Commissions.credit(_flow.meta, d, Commissions.current_stage(_bk(), _id), "k%d" % i, _flow.items); i += 1
			_flow.save_meta(); _flow.meta.changed.emit(); _cp().rebuild()
			_wait = 20; _st = 6
		6:
			var d := Commissions.def(_id)
			if _bk().is_done(_id) or _bk().state_of(_id) == CommissionBook.DONE or _bk().state_of(_id) == "":
				L("　　测试辅助记满进度：交货那步直接结案")
			else:
				var fb := _btn("Finish_" + String(_id))
				if fb == null: L("　　办成了但卡上没有【完成】：状态「%s」" % _bk().state_of(_id)); shot("no_finish"); _st = 20; return false
				var sc: Node = fb.get_parent()
				while sc != null and not (sc is ScrollContainer): sc = sc.get_parent()
				var vis := root.get_visible_rect().encloses(fb.get_global_rect())
				if sc != null:
					var scr_ := sc as ScrollContainer
					var vb := scr_.get_v_scroll_bar()
					L("　　【完成】键 %s；滚动框 %s；滚到 %d / %d；键在框里：%s" % [str(fb.get_global_rect()), str(scr_.get_global_rect()), scr_.scroll_vertical, int(vb.max_value - vb.page), str(scr_.get_global_rect().encloses(fb.get_global_rect()))])
				if sc != null and not (sc as ScrollContainer).get_global_rect().encloses(fb.get_global_rect()):
					var vb2 := (sc as ScrollContainer).get_v_scroll_bar()
					(sc as ScrollContainer).scroll_vertical = int(vb2.max_value); _wait = 10; _st = 61; return false
				L("　　测试辅助记满进度 → 卡上出【%s】，真点" % fb.text)
				_click(fb); _wait = 25; _st = 7; return false
			_st = 7
		61:
			var fb := _btn("Finish_" + String(_id))
			var sc2: Node = fb.get_parent()
			while sc2 != null and not (sc2 is ScrollContainer): sc2 = sc2.get_parent()
			L("　　测试辅助记满进度 → 卡上出【%s】，滚到底再真点（滚到 %d，键在框里：%s）" % [fb.text, (sc2 as ScrollContainer).scroll_vertical, str((sc2 as ScrollContainer).get_global_rect().encloses(fb.get_global_rect()))])
			_click(fb); _wait = 25; _st = 7
		7:
			var rep := _bk().rep_of(F)
			if _bk().state_of(_id) == CommissionBook.READY: L("　　点了【完成】没结案（状态还是办成了）"); shot("finish_missed")
			L("　　声望 %d → %d（+%d）；赠礼可领 %d；节点 %s" % [_rep0, rep, rep - _rep0, Commissions.gifts_due(_flow.meta, Commissions.faction(F)), _nodes_line()])
			var crossed := Commissions.crossed(Commissions.faction(F), _rep0, rep)
			if not crossed.is_empty():
				var ids := []
				for n in crossed: ids.append("%s@%d" % [String(n.get("id", "")), int(n.get("rep", 0))])
				L("　　跨过节点 %s；食堂 %s" % [str(ids), str(Canteen.sizes(_flow.meta))])
			_rounds += 1
			if rep > 50 and not _shot50: _shot50 = true; shot("past50")
			if rep >= 100:
				if not _shot100: _shot100 = true; shot("past100")
				_after100 += 1
			if rep >= 53 and rep < 90:
				_bk().rep[String(F)] = 97; _flow.save_meta(); _flow.meta.changed.emit()
				L("测试辅助：声望 %d → 97（跳过中间，接着真做）" % rep)
			if _after100 >= 2 or _rounds >= 40: _st = 10
			else: _st = 4
		10:
			var f := Commissions.faction(F)
			L("做了 %d 份：声望 %d；节点 %s" % [_rounds, _bk().rep_of(F), _nodes_line()])
			L("　　食堂：%s；可领赠礼 %d；合计 %d；离下一个节点 %d" % [str(Canteen.sizes(_flow.meta)), Commissions.gifts_due(_flow.meta, f), Commissions.gifts_due_total(_flow.meta), Commissions.rep_to_next(_bk(), f)])
			L("　　节点通知 %d 条：%s" % [_bk().node_news.size(), str(_bk().node_news).left(400)])
			_cp().show_sub("reputation"); _wait = 25; _st = 11
		11:
			var cp := _cp()
			var row := cp.find_child("Rep_" + String(F), true, false)
			L("声望页灰灯一行：%s；排版 %s" % [_labels_under(row).left(400) if row != null else "-", _overflow(cp)])
			shot("reputation")
			var gk := _btn("Gift_" + String(F))
			if gk == null or gk.disabled: L("　　【赠礼】键 %s" % ("没找到" if gk == null else "灰着")); _st = 20; return false
			L("　　【赠礼】键亮着；悬浮：%s" % gk.tooltip_text.replace("\n", " / "))
			_click(gk); _wait = 30; _st = 12
		12:
			var claim: Button = null
			for bb in root.find_children("*", "Button", true, false):
				var x := bb as Button
				if x.is_visible_in_tree() and x.text in ["领取", "Claim"]: claim = x
			if claim == null: L("　　点了【赠礼】没看到【领取】"); shot("no_claim"); _st = 20; return false
			shot("gift_window")
			_funds0 = _flow.meta.funds
			var due0 := Commissions.gifts_due(_flow.meta, Commissions.faction(F))
			_click(claim); _wait = 30; _st = 13
			L("　　真点【领取】（领前可领 %d）" % due0)
		13:
			L("　　领后：金币 %d → %d；领过 %s；还可领 %d" % [_funds0, _flow.meta.funds, str(_bk().gifts_claimed), Commissions.gifts_due(_flow.meta, Commissions.faction(F))])
			for bb in root.find_children("*", "Button", true, false):
				if (bb as Button).is_visible_in_tree() and (bb as Button).text in ["领取", "Claim"]: _ms().close_gift(); break
			_flow.save_meta(); _wait = 20; _st = 20
		20:
			var p := OS.get_user_data_dir() + "/slots/1/meta.json"
			var txt := FileAccess.get_file_as_string(p)
			var j = JSON.parse_string(txt)
			var rep_saved = "?"
			if j is Dictionary:
				var c = j.get("commissions", {})
				if c is Dictionary and c.get("rep", null) is Dictionary: rep_saved = str(c["rep"].get(String(F), "?"))
			L("存档里灰灯声望：%s" % rep_saved)
			_st = 99
		99:
			L("完 err=0"); quit(0); return true
	return false
