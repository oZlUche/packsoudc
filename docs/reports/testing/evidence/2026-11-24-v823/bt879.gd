extends SceneTree
## 游戏测试 v8.23（PR #879）：基地各页换成石刻面板 —— 逐页截图 + 排版溢出检查。参数 <outdir>
## 新档拒教程 → 测试辅助：各方到营地、开种地 / 炼金 / 食堂（含两份配方、补食材）、万神院到来 → 真点【开始探索】走一局，走一步后 force_extract → 结算【继续】回营地（基地页重建、「上回出征」有内容）→
## 真点各页签和后勤 / 书架小键，逐页记字、查溢出、截图
const TAG := "BT879"
const D383 := preload("res://tests/ui/test_departure_383.gd")
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

var _pages := []
var _pi := 0


func _settle() -> bool:
	var scr := _flow.screen
	if scr == GameFlow.Screen.EVENT:
		if bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing()
		else:
			var top = _game.overlay() if _game.overlay() != null else _game.base()
			if top != null and top.has_method("choose_event"): top.choose_event(0)
			elif top != null and top.has_method("proceed"): top.proceed()
			else: _flow.resume()
		return false
	if scr != GameFlow.Screen.MAP: return false
	for c in root.find_children("*", "CoachOverlay", true, false):
		(c as CoachOverlay).next(); return false
	return true


func _start_click() -> void:
	var sb: Button = _ms().get("_new_run_btn")
	if sb != null and sb.is_visible_in_tree(): _click(sb)
	elif sb != null: sb.pressed.emit()


func _setup_go() -> void:
	var sp: Node = null
	for n in root.find_children("*", "", true, false):
		if n.has_method("step_difficulty") and n.has_method("depart"): sp = n
	if sp == null: return
	var gb = sp.god_book() if sp.has_method("god_book") else null
	if gb != null: sp.close_god_book(); return
	for c in root.find_children("*", "CoachOverlay", true, false):
		(c as CoachOverlay).next(); return
	if sp.needs_spawn(): sp.pick_spawn(sp._preview.entry_ids()[0]); return
	if not sp.next_page(): sp.depart()


func _assist() -> void:
	var bk := _flow.meta.commissions
	for f in Commissions.factions():
		bk.arrived[String(f.id)] = 0
	for id in Commissions.FEATURES:
		bk.grants[String(id)] = true
	D383._two_menus(_flow)
	for id in ["mountain_yam", "fowl_leg", "sour_wheat"]:
		_put(id, _flow.meta.canteen.store)
	_flow.meta.funds += 500
	_flow.sync_commissions(); _flow.save_meta(); _flow.meta.changed.emit()
	L("测试辅助：各方到营地 %s；开了 %s；食堂配方 %d 份；金币 %d" % [str(bk.arrived.keys()), str(bk.grants.keys()), _flow.meta.canteen.menus.size(), _flow.meta.funds])


func _visit(p: Array) -> void:
	var kind: String = p[0]
	var key: String = p[1]
	match kind:
		"tab": _tab(key)
		"sub":
			if not _ms()._sub_btns.has(key): L("后勤没有「%s」小键：%s" % [key, str(_ms()._sub_btns.keys())]); return
			_click(_ms()._sub_btns[key])
		"shelf":
			var sb: Dictionary = _ms().sub_tab_buttons("shelf")
			if not sb.has(key): L("书架没有「%s」小键：%s" % [key, str(sb.keys())]); return
			_ms().close_shelf()     # 上一扇窗开着时先关上（窗盖住小键，点下去只会关窗）
			_click(sb[key])


func _process(_d: float) -> bool:
	_f += 1
	if _f % 250 == 0: print("%s ♥ f %d st %d 屏 %d wait %d" % [TAG, _f, _st, _flow.screen if _flow != null else -1, _wait])
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 14000:
		L("超时 st %d 屏 %d" % [_st, _flow.screen]); shot("timeout"); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	var scr := _flow.screen
	if _st < 3:
		if _boot(): _st = 3
		return false
	match _st:
		3:
			_assist()
			_tab("expedition"); _wait = 30; _st = 4
		4:
			_start_click(); _wait = 40; _st = 5
		5:
			if scr == GameFlow.Screen.META:
				var gp = _ms().god_pick() if _ms().has_method("god_pick") else null
				if gp != null: L("（出了选神界面）"); _st = 99; return false
				_start_click(); _wait = 40; return false
			if scr == GameFlow.Screen.SETUP:
				_setup_go(); _wait = 20; return false
			if not _settle(): _wait = 10; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				_game.base().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			var moves: Array = _flow.run.travel.available_moves()
			var pick := int(moves[0])
			for mv in moves:
				var tt := NodeEvents.effective_type(_flow.run.map.get_node(int(mv)))
				if not (tt in [&"battle", &"elite", &"core"]): pick = int(mv); break
			_flow.step_to(pick); _wait = 60; _st = 6
		6:
			if (scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.MAP) and not _settle(): _wait = 10; return false
			_flow.run.force_extract(); _flow.resume()
			L("走了一局：走一步后测试辅助 force_extract")
			_wait = 40; _st = 7
		7:
			if scr == GameFlow.Screen.RESULT:
				_game.base().proceed(); _wait = 60; _st = 8; return false
			if scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.MAP: _settle(); _wait = 10
		8:
			if scr != GameFlow.Screen.META: return false
			var arr: Control = _ms().arrival()
			if arr != null:
				for b in arr.find_children("*", "Button", true, false):
					if (b as Button).is_visible_in_tree(): _click(b); break
				_wait = 30; return false
			L("回营地。后勤小键 %s；书架小键 %s" % [str(_ms()._sub_btns.keys()), str(_ms().sub_tab_buttons("shelf").keys())])
			_pages = [["tab", "expedition"], ["tab", "warehouse"], ["tab", "tech"], ["tab", "commissions"], ["tab", "logistics"],
				["sub", "market"], ["sub", "smithy"], ["sub", "nursery"], ["sub", "alchemy"], ["sub", "canteen"], ["sub", "pantheon"],
				["tab", "shelf"], ["shelf", "codex"], ["shelf", "records"], ["shelf", "keepsakes"], ["shelf", "achievements"]]
			_pi = 0; _st = 10
		10:
			if _pi >= _pages.size(): _st = 99; return false
			_visit(_pages[_pi]); _wait = 30; _st = 12
		12:
			_hover_at(Vector2(4, 1196)); _wait = 20; _st = 11     # 鼠标挪开，截图不带悬停说明
		11:
			var p: Array = _pages[_pi]
			var nm := "%s_%s" % [p[0], p[1]]
			if p[1] == "records": L("　　对局记录窗：%s" % ("开着" if _ms().records_window() != null and _ms().records_window().is_visible_in_tree() else "没开"))
			L("【%s】排版：%s" % [nm, _overflow(_ms())])
			L("　　字：%s" % _labels_under(_ms()).left(500))
			shot(nm)
			_pi += 1; _st = 10
		99:
			L("完 err=0"); quit(0); return true
	return false
