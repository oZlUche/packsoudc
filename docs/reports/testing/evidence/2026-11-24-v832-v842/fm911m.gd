extends SceneTree
## 游戏测试 v8.40（PR #911，报告 389 / 391）：阵营声望节点 —— 老存档迁移。参数 <outdir> <mode>
## make（在 v8.40 以前的版本跑）：新档拒教程 → 测试辅助：各方到营地、声望设成几档不同的数（有的签约有的没签）、下一局奉狩猎之神、奉过狩猎之神 → 存档退出
## check（v8.40）：主菜单【继续】进基地 → 记声望、到了哪些节点、万神院各神能不能选、下一局奉谁 → 委托页真点接一份 → 出征页开局屏看信仰条
const TAG := "FM911M"
var _n0 := 0
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

var _mode := ""
const REP := {"legion": 100, "greylamp": 100, "society": 55, "pantheon": 30, "growers": 12, "cartographers": 25, "hunters": 0, "envoy": 50}
const SIGNED := ["greylamp", "envoy"]
const GODS := ["brute", "nature", "sun", "skill", "hunt", "earth", "church"]


func _old_line() -> String:
	var bk := _flow.meta.commissions
	var o := []
	for f in Commissions.factions():
		var t = Commissions.tier_of(bk, f)
		o.append("%s 声望 %d 档 %s" % [String(f.id), bk.rep_of(f.id), str(t)])
	return "；".join(o)


func _new_line() -> String:
	return ""


func _gods_line() -> String:
	var o := []
	for g in GODS:
		var gid := StringName(g)
		o.append("%s %s" % [g, ("能选" if Pantheon.god_open(_flow.meta, gid) else "不能")])
	return "，".join(o)


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		var a := OS.get_cmdline_user_args()
		_mode = a[1] if a.size() > 1 else "check"
		return false
	if _f > 8000:
		L("超时 st %d 屏 %d" % [_st, _flow.screen]); shot("timeout"); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	var scr := _flow.screen
	if _mode == "make":
		if _st < 3:
			if _boot(): _st = 3
			return false
		match _st:
			3:
				var bk := _flow.meta.commissions
				for f in Commissions.factions(): bk.arrived[String(f.id)] = 0
				for k in REP: bk.rep[k] = REP[k]
				for k in SIGNED: bk.signed[k] = 1
				_flow.meta.pantheon_choice = &"hunt"
				if not _flow.meta.gods_worshipped.has(&"hunt"): _flow.meta.gods_worshipped.append(&"hunt")
				_flow.sync_commissions(); _flow.save_meta(); _flow.meta.changed.emit()
				L("老版本：%s" % _old_line())
				L("　　万神院：%s；下一局奉「%s」；奉过 %s；access %s" % [_gods_line(), String(_flow.meta.pantheon_choice), str(_flow.meta.gods_worshipped), str(Pantheon.access(_flow.meta))])
				L("　　已接 %s" % str(bk.taken()))
				_wait = 30; _st = 99
			99:
				L("完 err=0"); quit(0); return true
		return false
	match _st:
		0:
			if _f < 90: return false
			L("主菜单【继续】：%s" % str(_flow.continue_game())); _wait = 90; _st = 1
		1:
			if scr != GameFlow.Screen.META: L("（没进基地，屏 %d）" % scr); _st = 99; return false
			var arr: Control = _ms().arrival()
			if arr != null:
				L("营地弹了通知：%s" % _labels_under(arr).left(200)); shot("notice")
				for b in arr.find_children("*", "Button", true, false):
					if (b as Button).is_visible_in_tree(): _click(b); break
				_wait = 30; return false
			L("读进来：\n　　%s" % _new_line())
			L("　　万神院：%s；下一局奉「%s」；奉过 %s；access %s" % [_gods_line(), String(Pantheon.choice(_flow.meta)), str(_flow.meta.gods_worshipped), str(Pantheon.access(_flow.meta))])
			L("　　已接 %s" % str(_flow.meta.commissions.taken()))
			_tab("commissions"); _wait = 40; _st = 2
		2:
			var cp: Control = _ms().commission_panel()
			L("委托页：%s" % _labels_under(cp).left(900))
			L("　　排版：%s" % _overflow(cp))
			shot("commissions")
			var take: Button = null
			for b in cp.find_children("*", "Button", true, false):
				var bb := b as Button
				if bb.is_visible_in_tree() and not bb.disabled and (bb.text.contains("接") or bb.text.to_lower().contains("accept") or bb.text.to_lower().contains("take")): take = bb; break
			if take == null: L("　　没找到能点的接取键"); _st = 4; return false
			_n0 = _flow.meta.commissions.taken().size()
			L("　　真点【%s】" % take.text); _click(take); _wait = 30; _st = 3
		3:
			L("　　接了以后：已接 %d → %d：%s" % [_n0, _flow.meta.commissions.taken().size(), str(_flow.meta.commissions.taken())])
			shot("after_take")
			_st = 4
		4:
			_tab("logistics"); _wait = 25; _st = 5
		5:
			if _ms()._sub_btns.has("pantheon"): _click(_ms()._sub_btns["pantheon"]); _wait = 30; _st = 6
			else: L("后勤没有万神院"); _st = 7
		6:
			var p = _ms().pantheon_panel()
			L("万神院页：%s；排版 %s" % [_labels_under(p).left(500), _overflow(p)])
			shot("pantheon")
			_st = 7
		7:
			_tab("expedition"); _wait = 30; _st = 8
		8:
			var sb: Button = _ms().get("_new_run_btn")
			sb.pressed.emit(); _wait = 60; _st = 9
		9:
			if scr != GameFlow.Screen.SETUP: L("（没进开局屏，屏 %d）" % scr); _st = 99; return false
			var sp: Node = null
			for n in root.find_children("*", "", true, false):
				if n.has_method("step_difficulty") and n.has_method("depart"): sp = n; break
			if sp.god_book() != null: sp.close_god_book(); _wait = 20; return false
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next(); _wait = 10; return false
			sp.open_bar(sp.BAR_FAITH); _wait = 20; _st = 10
		10:
			var sp: Node = null
			for n in root.find_children("*", "", true, false):
				if n.has_method("step_difficulty") and n.has_method("depart"): sp = n; break
			if sp.god_book() != null: sp.close_god_book(); _wait = 20; return false
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next(); _wait = 10; return false
			L("开局屏信仰条：头上「%s」；展开：%s" % [sp.faith_head_text() if sp.has_method("faith_head_text") else "-", _labels_under(sp.faith_panel()).left(400)])
			L("　　真点狩猎之神（老档信过、现在是占位）：%s；下一局奉「%s」" % [str(sp.choose_god(&"hunt")), String(Pantheon.choice(_flow.meta))])
			L("　　真点自然之神（声望 30 ≥ 10）：%s；下一局奉「%s」" % [str(sp.choose_god(&"nature")), String(Pantheon.choice(_flow.meta))])
			shot("faith_bar")
			_st = 99
		99:
			L("完 err=0"); quit(0); return true
	return false
