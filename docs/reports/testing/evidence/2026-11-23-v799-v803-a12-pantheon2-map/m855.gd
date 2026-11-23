extends SceneTree
## 游戏测试 v8.02（PR #855）、v8.03（PR #856）：A12 守卫小旗、守卫到首领的红虚线、地图放大；顶端栏满载（30 级、金币五位数）。参数 <outdir>
## 新档拒教程 → 测试辅助解锁进阶一到十二 → 开局屏 step_difficulty 到 12 → 进地图 → 四种窗口大小各截一张：
## 记守卫点、首领点、旗子矩形；节点圆之间、旗子和别的节点圆有没有重叠；节点有没有落在地图视口外（开局视图、fit 之后）→
## 测试辅助：经验加到 30 级、钱包 99999 → 截顶端栏、查溢出
const TAG := "M855"
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

const SIZES := [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080)]
var _si := 0
var _sp: Node = null


func _mv() -> MapView:
	for n in root.find_children("*", "MapView", true, false):
		if (n as Control).is_visible_in_tree(): return n
	return null


func _hud() -> Control:
	for n in root.find_children("*", "Control", true, false):
		var s = n.get_script()
		if s != null and String(s.resource_path).ends_with("hud_host.gd") and (n as Control).is_visible_in_tree(): return n
	return null


func _check(tagname: String) -> void:
	var mv := _mv()
	if mv == null: L("（没找到地图）"); return
	var pos: Dictionary = mv.positions()
	var xf := mv.get_global_transform()
	var r := MapView.NODE_RADIUS * xf.get_scale().x
	var view := mv.get_global_rect()
	var pts := {}
	for id in pos: pts[int(id)] = xf * mv.to_screen(pos[id])
	var close := []
	var ids := pts.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var dd: float = (pts[ids[i]] as Vector2).distance_to(pts[ids[j]])
			if dd < 2.0 * r: close.append("%d-%d %.0f" % [ids[i], ids[j], dd])
	var out := []
	for id in pts:
		if not view.grow(-r).has_point(pts[id]): out.append(id)
	var flags := []
	var flag_hits := []
	for pair in mv.guard_pairs():
		for k in 2:
			var nid := int(pair[k])
			if not pts.has(nid): continue
			var foot: Vector2 = mv.to_screen(pos[nid]) + Vector2(1.0, -1.0).normalized() * MapView.NODE_RADIUS
			var art := MapView.guard_flag_art(String(pair[2]))
			var meta := UiTheme.art_meta(art)
			var tex := UiTheme.art_cached(art)
			var sz: Array = meta.get("size", [tex.get_width() if tex != null else 0, tex.get_height() if tex != null else 0])
			var fr := mv.pawn_rect(foot, float(sz[1]), 1.0, art)
			var gr := Rect2(xf * fr.position, fr.size * xf.get_scale())
			flags.append("%d %s" % [nid, str(gr).replace("(", "").replace(")", "")])
			for oid in pts:
				if int(oid) == nid: continue
				var p: Vector2 = pts[oid]
				var cx := clampf(p.x, gr.position.x, gr.end.x)
				var cy := clampf(p.y, gr.position.y, gr.end.y)
				if Vector2(cx, cy).distance_to(p) < r: flag_hits.append("旗@%d 压到节点 %d" % [nid, oid])
			if not view.encloses(gr): flag_hits.append("旗@%d 出了地图视口" % nid)
	L("%s：窗口 %s、地图视口 %s、缩放 %.2f、节点 %d 个、屏上半径 %.1f；守卫对 %s；旗 %s；节点圆重叠 %s；视口外节点 %d 个 %s；旗的问题 %s" % [tagname, str(DisplayServer.window_get_size()), str(view.size), mv.zoom, pts.size(), r, str(mv.guard_pairs()), str(flags), str(close), out.size(), str(out).left(120), str(flag_hits)])


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
			for d in GameFlow.load_difficulties():
				if (d as DifficultyDef).requires_unlock != &"": _flow.meta.grant_unlock((d as DifficultyDef).requires_unlock)
			_flow.save_meta()
			L("测试辅助：解锁进阶一到十二")
			_tab("expedition"); _wait = 30; _st = 4
		4:
			if scr == GameFlow.Screen.META:
				var sb: Button = _ms().get("_new_run_btn")
				if sb != null: sb.pressed.emit()
				_wait = 40; return false
			if scr != GameFlow.Screen.SETUP: return false
			for n in root.find_children("*", "", true, false):
				if n.has_method("step_difficulty") and n.has_method("depart"): _sp = n
			set_meta("steps", 0); _st = 5
		5:
			if int(get_meta("steps")) < 14:
				_sp.step_difficulty(1); set_meta("steps", int(get_meta("steps")) + 1); _wait = 3; return false
			L("开局屏难度：%s" % str(_sp.difficulty_index))
			_st = 6
		6:
			if scr == GameFlow.Screen.SETUP:
				if _sp.needs_spawn(): _sp.pick_spawn(_sp._preview.entry_ids()[0]); _wait = 15; return false
				if not _sp.next_page(): _sp.depart()
				_wait = 20; return false
			if scr == GameFlow.Screen.EVENT:
				if bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing()
				else:
					var top = _game.overlay() if _game.overlay() != null else _game.base()
					if top != null and top.has_method("proceed"): top.proceed()
					else: _flow.resume()
				_wait = 10; return false
			if scr != GameFlow.Screen.MAP: return false
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next(); _wait = 10; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				_game.base().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			L("进地图：难度 %d" % (_flow.run.difficulty.level if _flow.run.difficulty != null else -1))
			_st = 7
		7:
			if _si >= SIZES.size(): _st = 9; return false
			DisplayServer.window_set_size(SIZES[_si]); _wait = 60; _st = 8
		8:
			_check("%dx%d 开局视图" % [SIZES[_si].x, SIZES[_si].y])
			shot("map_%dx%d" % [SIZES[_si].x, SIZES[_si].y])
			_mv().fit(); _wait = 30; _st = 81
		81:
			_check("%dx%d fit 之后" % [SIZES[_si].x, SIZES[_si].y])
			shot("map_fit_%dx%d" % [SIZES[_si].x, SIZES[_si].y])
			_si += 1; _st = 7
		9:
			DisplayServer.window_set_size(Vector2i(1600, 900)); _wait = 40; _st = 10
		10:
			var m := LevelModule.of(_flow.run)
			m.gain(float(m.rules().total_for(30) + 5), LevelModule.SRC_EVENT, "test")
			_flow.run.wallet.earn(99999 - _flow.run.wallet.balance)
			L("测试辅助：经验加到 Lv.%d（欠选 %d）、钱包 %d" % [m.level(), m.pending(), _flow.run.wallet.balance])
			_wait = 40; _st = 11
		11:
			var ev := InputEventKey.new(); ev.keycode = KEY_ESCAPE; ev.pressed = true
			root.push_input(ev)
			var ev2 := InputEventKey.new(); ev2.keycode = KEY_ESCAPE; ev2.pressed = false
			root.push_input(ev2)
			_wait = 30; _st = 12
		12:
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next(); _wait = 10; return false
			if _named("LevelPick") != null:
				var ev := InputEventKey.new(); ev.keycode = KEY_ESCAPE; ev.pressed = true
				root.push_input(ev); _wait = 20; return false
			var h := _hud()
			L("顶端栏满载：%s" % (_labels_under(h).replace("\n", " / ").left(400) if h != null else "（没找到 hud）"))
			L("　　排版：%s" % _overflow(h))
			shot("topbar_full")
			_st = 99
		_:
			quit(0); return true
	return false
