extends SceneTree
## 游戏测试 v6.77–v6.78（报告 351）：参数 <outdir> <mode> [seed]
##   new：新档拒教程 → 基地看委托有几方、材料倾向开没开 → 真点出征，看开局屏只有三页 → 走到最近一处搜索点 → 测试辅助撤离 →
##        回基地看地图协会来没来、首单接没接 → 真点【办理】《把路画回来》→ 再出征，真点翻到第四页「本次准备」，记选项 / 压灰 / 悬浮原因 →
##        真点「矿物」→ 真点【出发】→ 局内看倾向 → 存档回主菜单再继续 → 走到一处普通搜索点搜一次
##   make：（在 v6.77 上跑）新档拒教程 → 直接开自由模式 → 走一步 → 回主菜单（留下 v6 局内存档）
##   old：（在 v6.78 上跑）主菜单「继续」读 v6 局内存档 → 记版本、倾向 → 走到一处普通搜索点搜一次
var out := ""
var mode := "new"
var seed_ := 41
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _shots := 0
var _target := -1
var _steps := 0
var _phase := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: mode = a[1]
	if a.size() > 2: seed_ = int(a[2])
	DirAccess.make_dir_recursive_absolute(out)
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func L(s: String) -> void:
	print("P678 " + s)


func shot(n: String) -> void:
	_shots += 1
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/prep_%s_%02d_%s.png" % [out, mode, _shots, n])


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


func _setup() -> Node:
	for n in root.find_children("*", "", true, false):
		if n.has_method("carry_in") and n.has_method("depart") and (n as Node).is_inside_tree(): return n
	return null


func _book() -> String:
	var b := _flow.meta.commissions
	return "列出的几方 %s；arrived %s；接着的 %s；倾向开 %s" % [str(Commissions.listed_factions().map(func(f): return Names.of(f))), str(b.arrived),
		str(b.taken()), str(_flow.bias_open())]


func _target_search() -> int:
	var r := _flow.run
	var best := -1
	var bd := 1 << 30
	for id in r.map.node_ids():
		var nd := r.map.get_node(id)
		if nd == null or nd.is_visited() or id == r.travel.current_id: continue
		if NodeEvents.effective_type(nd) != &"search": continue
		if not (r.events.search_kind_of(nd).get("tags", []) as Array).is_empty(): continue     # 材料点不算普通搜索点
		var d := _dist(r.travel.current_id, id)
		if d >= 0 and d < bd: bd = d; best = id
	return best


func _dist(a: int, b: int) -> int:
	var r := _flow.run
	var dist := {a: 0}
	var open := [a]
	while not open.is_empty():
		var u: int = open.pop_front()
		if u == b: return dist[u]
		for v in MapNavigator.available_moves(r.map, u):
			var nd := r.map.get_node(v)
			if nd != null and NodeEvents.effective_type(nd) in [&"core", &"boss"]: continue
			if not dist.has(v): dist[v] = dist[u] + 1; open.append(v)
	return -1


## 走向 [member _target]：到了（搜索屏）返回 true
func _walk_to_search() -> bool:
	var scr := _flow.screen
	var r := _flow.run
	if r.is_over() or scr == GameFlow.Screen.RESULT:
		L("走的路上这一局结束了（%s）" % String(r.end_reason)); return true
	if (scr == GameFlow.Screen.SEARCH or scr == GameFlow.Screen.EVENT) and r.travel.current_id == _target:
		return true
	if scr != GameFlow.Screen.MAP:
		_push_other(); _wait = 12; return false
	for c in root.find_children("*", "CoachOverlay", true, false):
		(c as CoachOverlay).next(); _wait = 5; return false
	if _ms().ground_warn_open():
		var g := _btn_has([UiText.t("map.ground_go")])
		if g != null: _click(g)
		_wait = 10; return false
	if r.travel.current_id == _target:
		return true
	_steps += 1
	if _steps > 150: L("走了 150 步还没到"); return true
	var hop := _next_hop(_target)
	if hop < 0: L("到 %d 没路" % _target); return true
	var v: MapView = _ms()._view
	var gp := v.get_global_transform() * v.to_screen(v.positions().get(hop, Vector2.ZERO))
	for n in root.find_children("*", "HoverTip", true, false): n.hide_tip()
	if Rect2(Vector2.ZERO, root.get_visible_rect().size).has_point(gp): _click_node(hop)
	else: _ms()._on_node_pressed(hop, MOUSE_BUTTON_LEFT, false)
	_wait = 15
	return false


func _search_line() -> String:
	var r := _flow.run
	var ss: SearchSession = r.events.current_search
	if ss == null: return "（没有开着的搜索会话，屏 %s）" % GameFlow.Screen.keys()[_flow.screen]
	var items := []
	if ss.haul_box != null:
		for it in ss.haul_box.items():
			var d := (it as ItemInstance).def
			items.append("%s%s" % [Names.of(d), "（材料 %s）" % str(d.tags.filter(func(t): return t in [&"mineral", &"plant", &"crafted", &"beast_part", &"crystal", &"magic"])) if SearchSession.is_material(d) else ""])
	return "搜索会话：only_tags %s；倾向标签 %s ×%s；已翻出 %d 件：%s" % [str(ss.only_tags), str(ss.bias_tags), str(ss.bias_mult), items.size(), "、".join(items)]


func _go_setup() -> void:
	var ex = _ms()._tab_btns.get("expedition")
	if ex != null: _click(ex)


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
			if mode == "old":
				L("主菜单「继续」：%s" % str(_flow.continue_game())); _wait = 40; _st = 60; return false
			_flow.start_new_game(); _st = 1
		1:
			var b = _game.base()
			if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open():
				b.decline_tutorial(); _wait = 30; _st = 2
			elif _f > 240:
				_flow.decline_tutorial(); _wait = 30; _st = 2
		2:
			if scr != GameFlow.Screen.META: return false
			if mode == "make":
				_flow.begin_direct(_flow.chapter_of(&"free_mode"), seed_); _wait = 30; _st = 50; return false
			L("进基地：%s" % _book())
			_go_setup(); _wait = 20; _st = 3
		3:
			var sb: Button = _ms().get("_new_run_btn")
			if sb != null: _click(sb)
			_wait = 40; _st = 4
		# ---------- 开局屏：真点翻页 ----------
		4:
			if scr == GameFlow.Screen.EVENT and bool(_flow.last_payload.get("briefing", false)):
				_flow.close_briefing(); _wait = 10; return false
			if scr == GameFlow.Screen.MAP:
				_st = 10; return false
			if scr != GameFlow.Screen.SETUP: return false
			var sp := _setup()
			if sp == null: return false
			var pg: int = sp.page()
			var eb: Button = sp.get("_enter_btn")
			if _phase == 0 and pg == 0:
				L("开局屏（第一趟）：最后一页是第 %d 页；页标题「%s」" % [sp.last_page() + 1, str(sp.get("_title").text)])
			if pg == 2 and sp.needs_spawn():
				sp.pick_spawn(sp._preview.entry_ids()[0]); _wait = 20; return false
			if pg == 3 and not _prep_seen:
				_prep_seen = true
				var bb: Dictionary = sp.bias_buttons()
				var o := []
				for k in bb:
					var b: Button = bb[k]
					o.append("[%s%s%s]" % [b.text, "（灰：%s）" % b.tooltip_text if b.disabled else "", "（按下）" if b.button_pressed else ""])
				L("第四页「%s」：章节 %s；%s；【%s】" % [str(sp.get("_title").text), String(sp.chapter().id), " ".join(o), eb.text])
				var opts := []
				for c in _flow.available_chapters():
					opts.append("%s：%s" % [String(c.id), str(_flow.bias_options(c).map(func(x): return "%s%s" % [String(x["id"]) if String(x["id"]) != "" else "无", "×" + String(x["why"]) if String(x["why"]) != "" else ""]))])
				L("　　各章的选项：%s" % "；".join(opts))
				L("　　排版：%s" % _overflow(sp))
				shot("prep_page")
				var mb: Button = bb.get(&"mineral")
				if mb != null and not mb.disabled:
					_click(mb); _wait = 15; _st = 5; return false
			_click(eb); _wait = 25
		5:
			var sp := _setup()
			L("真点「矿物」：选中 %s；出发交的 %s" % [String(sp.bias_id), String(sp.chosen_bias())])
			for n in root.find_children("*", "HoverTip", true, false): n.hide_tip()
			shot("prep_mineral")
			_click(sp.get("_enter_btn")); _wait = 30; _st = 4
		# ---------- 局内 ----------
		10:
			if scr != GameFlow.Screen.MAP: return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				_ms().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			var r := _flow.run
			for id in [&"knife", &"bone_greatsword", &"battle_axe", &"bone_spear", &"round_shield"]:
				var d := _flow.items.get_def(id)
				if d != null: r.board.try_add(ItemInstance.create(d, 0))
			_flow._flush()
			L("进图（第 %d 趟）：章节 %s；局内倾向「%s」；events 倾向「%s」" % [_phase + 1, String(r.chapter.id), String(r.material_bias), String(r.events.material_bias)])
			if _phase == 1:
				_flow.to_main_menu(); _wait = 30; _st = 30; return false
			_target = _target_search(); _steps = 0
			L("　　去最近的普通搜索点 %d" % _target)
			_st = 11
		11:
			if not _walk_to_search(): return false
			if scr == GameFlow.Screen.EVENT and _flow.run.events.current_search == null and _evtries < 3:
				_evtries += 1
				L("到了 %d 先是事件屏：键 %s" % [_target, _list_buttons()])
				var sb := _btn_has(["搜", "Search"])
				if sb != null: _click(sb)
				_wait = 30; return false
			if scr == GameFlow.Screen.SEARCH and _swait < 4:
				_swait += 1; _wait = 60; return false
			_evtries = 0; _swait = 0
			L("到了 %d（屏 %s）：%s" % [_target, GameFlow.Screen.keys()[scr], _search_line()])
			if _phase == 0:
				_flow.run.force_extract(); _flow._flush(); _wait = 60; _st = 12
			else:
				shot("search_biased"); _st = 99
		12:
			if scr == GameFlow.Screen.SEARCH or scr == GameFlow.Screen.LOOT or scr == GameFlow.Screen.EVENT: _push_other(); _wait = 10; return false
			if scr != GameFlow.Screen.RESULT: return false
			L("结算：走了 %d 步；正式探索 %s" % [_flow.result.steps, str(_flow.formal_run())])
			_flow.finish_result(); _wait = 40; _st = 13
		13:
			if scr != GameFlow.Screen.META: return false
			L("回基地：%s" % _book())
			_ms()._tab_btns["commissions"].pressed.emit(); _wait = 20; _st = 14
		14:
			_click(_named("Sub_story")); _wait = 20; _st = 15
		15:
			var fk := _btn_has([Names.of(Commissions.faction(&"cartographers"))])
			L("剧情页的阵营键：地图协会 %s" % ("在" if fk != null else "不在"))
			if fk != null: _click(fk)
			_wait = 20; _st = 16
		16:
			var p = _ms().commission_panel()
			L("地图协会剧情页：%s" % _labels_under(p).left(900))
			L("　　排版：%s" % _overflow(p))
			shot("cartographers_story")
			var rb := _named("Report_cartographers_redraw")
			if rb == null: L("没有《把路画回来》的【办理】"); _st = 99; return false
			_click(rb); _wait = 30; _st = 17
		17:
			L("真点【办理】后：%s；声望 %d；告示 %s" % [_book(), _flow.meta.commissions.rep_of(&"cartographers"), str(NoticeLayer.history().slice(0, 2).map(func(x): return x.get("text", "")))])
			shot("after_redraw")
			_phase = 1; _prep_seen = false
			_go_setup(); _wait = 20; _st = 3
		30:
			_flow.continue_game(); _wait = 40; _st = 31
		31:
			if scr != GameFlow.Screen.MAP: return false
			L("存档回主菜单再继续：局内倾向「%s」；events 倾向「%s」；局内存档版本 %d" % [String(_flow.run.material_bias), String(_flow.run.events.material_bias), RunState.SAVE_VERSION])
			_target = _target_search(); _steps = 0
			L("　　去最近的普通搜索点 %d" % _target)
			_st = 11
		# ---------- make：留下 v6 局内存档 ----------
		50:
			if scr == GameFlow.Screen.EVENT and bool(_flow.last_payload.get("briefing", false)):
				_flow.close_briefing(); _wait = 10; return false
			if scr != GameFlow.Screen.MAP: return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				_ms().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			L("（旧版）进图：局内存档版本 %d；当前点 %d" % [RunState.SAVE_VERSION, _flow.run.travel.current_id])
			_flow.save_run() if _flow.has_method("save_run") else null
			_flow.to_main_menu(); _wait = 40; _st = 51
		51:
			L("（旧版）回主菜单；能继续 %s" % str(_flow.has_method("can_continue") and _flow.can_continue()))
			_st = 99
		# ---------- old：读 v6 局内存档 ----------
		60:
			if scr != GameFlow.Screen.MAP:
				if _f % 200 == 0: L("（等地图：屏 %s）" % GameFlow.Screen.keys()[scr])
				if _f > 3000: L("读档后没进地图（屏 %s）" % GameFlow.Screen.keys()[scr]); quit(1); return true
				return false
			L("读进 v6 局内存档：屏 %s；章节 %s；当前点 %d；局内倾向「%s」；events 倾向「%s」" % [GameFlow.Screen.keys()[scr], String(_flow.run.chapter.id), _flow.run.travel.current_id,
				String(_flow.run.material_bias), String(_flow.run.events.material_bias)])
			var nn = _flow.meta.get("nursery")
			L("　　局外存档（v6.71 写的 v5）读进来：现在版本 %d；苗圃 %s；委托簿 arrived %s" % [MetaState.SAVE_VERSION, str(nn.to_dict()) if nn != null else "（没有这一项）", str(_flow.meta.commissions.arrived)])
			shot("old_run_loaded")
			_phase = 2
			_target = _target_search(); _steps = 0
			L("　　去最近的普通搜索点 %d" % _target)
			_st = 11
		_:
			quit(0); return true
	return false


var _prep_seen := false
var _evtries := 0
var _swait := 0


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


func _buttons() -> Array:
	var o := []
	for n in root.find_children("*", "BaseButton", true, false):
		if (n as Control).is_visible_in_tree(): o.append(n)
	return o


func _btn_text(b: BaseButton) -> String:
	if b is Button: return (b as Button).text.strip_edges().replace("\n", " ")
	return ""


func _btn_has(subs: Array) -> BaseButton:
	for b in _buttons():
		var t := _btn_text(b)
		for s in subs:
			if t != "" and t.contains(String(s)): return b
	return null


func _list_buttons() -> String:
	var o := []
	for b in _buttons():
		var t := _btn_text(b)
		if t != "": o.append("[%s%s]" % [t, "（灰）" if (b as BaseButton).disabled else ""])
	return " ".join(o)


func _labels_under(n: Node) -> String:
	var o := []
	for l in n.find_children("*", "", true, false):
		if not (l is Label or l is RichTextLabel) or not (l as Control).is_visible_in_tree(): continue
		var t: String = (l as RichTextLabel).get_parsed_text() if l is RichTextLabel else (l as Label).text
		if t.strip_edges() != "": o.append(t.strip_edges().replace("\n", " "))
	return " / ".join(o)


func _ms() -> Node:
	return _game.base()


func _wh(id: String) -> int:
	var n := 0
	for it in _flow.meta.warehouse.items():
		if String((it as ItemInstance).def.id) == id: n += 1
	return n


func _put(id: String, k: int) -> void:
	var d := _flow.items.get_def(StringName(id))
	for i in k:
		var it := ItemInstance.create(d, 0)
		it.uid = _flow.meta.allocate_uid()
		_flow.meta.warehouse.try_add(it)


func _click_node(id: int) -> void:
	var v: MapView = _ms()._view
	var gp := v.get_global_transform() * v.to_screen(v.positions().get(id, Vector2.ZERO))
	_mouse_at(gp, MOUSE_BUTTON_LEFT)


func _next_hop(to: int) -> int:
	var r := _flow.run
	var start: int = r.travel.current_id
	var dist := {start: 0}
	var prev := {}
	var open := [start]
	while not open.is_empty():
		open.sort_custom(func(a, b): return dist[a] < dist[b])
		var u: int = open.pop_front()
		if u == to: break
		for v in MapNavigator.available_moves(r.map, u):
			var nd := r.map.get_node(v)
			var w := 1
			if nd != null and nd.type in [&"battle", &"elite"] and not nd.is_visited(): w = 12
			if nd != null and nd.type in [&"core", &"boss"]: w = 200
			if nd != null and nd.type == &"extract" and v != to: w = 30
			if not dist.has(v) or dist[u] + w < dist[v]:
				dist[v] = dist[u] + w; prev[v] = u
				if not open.has(v): open.append(v)
	if not prev.has(to): return -1
	var c := to
	while prev.get(c, -1) != start: c = prev[c]
	return c


func _push_other() -> void:
	var scr := _flow.screen
	var r := _flow.run
	match scr:
		GameFlow.Screen.EVENT:
			if bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing()
			else:
				var ev: EventDef = r.events.pending_event()
				if ev == null: _flow.resume()
				else:
					var ctx = r.events._event_ctx(r.events.pending_node())
					var pick := -1
					for i in ev.options.size():
						if (ev.options[i] as EventOption).locked_reason(ctx) == "":
							var lb := String((ev.options[i] as EventOption).label)
							if pick < 0: pick = i
							if lb.contains("离开") or lb.contains("算了") or lb.contains("再看看"): pick = i; break
					_flow.choose_event(maxi(pick, 0))
		GameFlow.Screen.SEARCH: _flow.close_search()
		GameFlow.Screen.LOOT: _flow.take_all_loot(); _flow.resume()
		GameFlow.Screen.ALTAR: _flow.close_altar()
		GameFlow.Screen.RANSOM: _flow.refuse_ransom()
		GameFlow.Screen.PREBATTLE:
			var pre = _game.overlay()
			if pre != null and pre.has_method("start_battle"): pre.start_battle()
			else: _flow.start_battle()
		GameFlow.Screen.BATTLE:
			var bs = _game.overlay()
			if bs != null and bs.has_method("view") and bs.view() != null: bs.view().skip_to_end()
			if bs != null and bs.has_method("verdict_shown") and bs.verdict_shown(): bs.proceed()
		_:
			_flow.resume()




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
