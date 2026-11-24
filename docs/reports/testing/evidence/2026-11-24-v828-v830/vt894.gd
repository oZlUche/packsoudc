extends SceneTree
## 游戏测试 v8.27（PR #894）：体力多排 —— 顶端栏的体力心每排 10 颗，三排起缩小、总高不过两排。参数 <outdir>
## 新档拒教程 → 真点【开始探索】出发 → 地图上测试辅助把体力上限设成 10 / 11 / 20 / 21 / 25 / 30 / 40 / 60（当前 = 上限 - 3），
## 每档记行列、心大小、体力格和顶端栏的框、最后一颗心在不在框里、和旁边金币格叠不叠，截图 → 60 颗时扣 1 点体力看劈心动画落点 → 打开背包（状态界面）看体力那一行
const TAG := "VT894"
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



const NS := [10, 11, 20, 21, 25, 30, 40, 60]
var _ni := 0


func _vw() -> Control:
	return _game.base().hud().widgets.get(&"vitality", null)


func _r(r: Rect2) -> String:
	return "(%d,%d %dx%d)" % [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]


func _vit_line() -> String:
	var w := _vw()
	if w == null: return "（没有体力格）"
	var host = _game.base().hud()
	var bar: Control = host.widgets.get(&"hud_bar", null)
	var wal: Control = host.widgets.get(&"wallet", null)
	var g: Vector2i = w.call("grid")
	var wr := w.get_global_rect()
	var n: int = _flow.run.vitality.maximum
	var inside := true
	for i in n:
		var hr: Rect2 = w.call("heart_rect", i)
		if not wr.grow(0.5).encloses(hr): inside = false
	var br := bar.get_global_rect() if bar != null else Rect2()
	var hit := wal != null and wal.visible and wal.get_global_rect().intersects(wr)
	return "上限 %d 当前 %d：%d 行 × %d 列，心 %.1f（原大 %.1f），体力格 %s，顶端栏 %s，心都在格里 %s，体力格在栏里 %s，压到金币格 %s，提示「%s」" % [n, _flow.run.vitality.current, g.y, g.x, float(w.call("cell_size")), float(w.call("heart_size")), _r(wr), _r(br), str(inside), str(br.grow(0.5).encloses(wr)), str(hit), w.tooltip_text]


func _process(_d: float) -> bool:
	_f += 1
	if _f % 250 == 0: print("%s ♥ f %d st %d 屏 %d wait %d" % [TAG, _f, _st, _flow.screen if _flow != null else -1, _wait])
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 12000:
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
			_tab("expedition"); _wait = 30; _st = 4
		4:
			_start_click(); _wait = 40; _st = 5
		5:
			if scr == GameFlow.Screen.META:
				_start_click(); _wait = 40; return false
			if scr == GameFlow.Screen.SETUP:
				_setup_go(); _wait = 20; return false
			if not _settle(): _wait = 10; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				_game.base().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			L("出发，地图上：%s" % _vit_line())
			_hover_at(Vector2(900, 700)); _st = 10
		10:
			if _ni >= NS.size(): _st = 20; return false
			var n: int = NS[_ni]
			var v = _flow.run.vitality
			v.set_max(n)
			v.current = n
			v.spend(3)
			_wait = 20; _st = 11
		11:
			L(_vit_line())
			shot("max%d" % NS[_ni])
			_ni += 1; _st = 10
		20:
			_flow.run.vitality.spend(1, &"test")
			L("测试辅助扣 1 点体力：%s" % _vit_line())
			_wait = 6; _st = 21
		21:
			var hb: Array = root.find_children("*", "HeartBreak", true, false)
			var w := _vw()
			var i: int = _flow.run.vitality.current
			L("劈心动画 %d 个；该落的那颗（第 %d 颗）框 %s" % [hb.size(), i + 1, _r(w.call("heart_rect", i))])
			if not hb.is_empty(): L("　　动画节点框 %s" % _r((hb[0] as Control).get_global_rect()) if hb[0] is Control else "　　动画节点 %s" % str(hb[0]))
			shot("heart_break")
			_wait = 90; _st = 22
		22:
			_game.base().toggle_bag(); _wait = 40; _st = 23
		23:
			var t := _labels_under(root)
			var at := t.find("体力")
			if at < 0: at = t.find("Vitality")
			L("背包（状态界面）开着；体力那一段：%s" % (t.substr(maxi(0, at - 20), 120) if at >= 0 else "（没找到体力字样）"))
			L("　　顶端栏 %s" % _vit_line())
			shot("status")
			_st = 99
		99:
			L("完 err=0"); quit(0); return true
	return false
