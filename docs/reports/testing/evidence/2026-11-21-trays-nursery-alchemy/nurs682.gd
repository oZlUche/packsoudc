extends SceneTree
## 游戏测试 v6.80（报告 353）：参数 <outdir> [seed]
## 新档拒教程 → 一局正式探索（走到最近的普通搜索点，测试辅助撤离）→ 回基地看垦户社来没来、后勤有没有「苗圃」小键 →
## 真点「苗圃」看说明板 → 委托页真点【办理】《第一畦》→ 真点「苗圃」→ 苦叶草没种苗时灰着、真点【种下】绳麻 →
## 空跑一局（没走出起点）看不推进 → 正式一局推进 1 格，测试辅助同一局再结算一次看不推第二次 → 存档回主菜单再继续 →
## 再两局正式 → 后勤页签挂「可收获」→ 测试辅助塞满仓库，真点【收获】（应整体退回）→ 腾一格再真点【收获】→ 入库、清畦、《收获》记上 →
## 测试辅助放一束干草药，真点【种下】苦叶草（扣种）
var out := ""
var seed_ := 51
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _shots := 0
var _target := -1
var _steps := 0
var _phase := 0
var mode := "nursery"
var _ret := 0
var _empty := false
var _runs := 0
var _filler: Array = []


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: seed_ = int(a[1])
	DirAccess.make_dir_recursive_absolute(out)
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func _plot() -> String:
	var n := _flow.meta.nursery
	return "畦 %s；last_run「%s」；seq %d；熟了 %d 畦；可收获标记 %s" % [str(n.plots), n.last_run, n.seq, n.ripe_count(), str(_flow.nursery_ripe())]


func _growers() -> String:
	var b := _flow.meta.commissions
	var o := []
	for id in ["growers_first_bed", "growers_trial_sow", "growers_first_harvest", "growers_permit"]:
		o.append("%s %s %s" % [id, b.state_of(StringName(id)), str(b.entry(StringName(id)).get("progress", "-"))])
	return "垦户社声望 %d；%s" % [b.rep_of(&"growers"), "；".join(o)]


func _put(id: String) -> ItemInstance:
	var d := _flow.items.get_def(StringName(id))
	var it := ItemInstance.create(d, 0)
	it.uid = _flow.meta.allocate_uid()
	return it if _flow.meta.warehouse.try_add(it) else null


## 一局：[member _empty] = 空跑（不走出起点）；回基地后到 [member _ret]
func _run_step(scr: int) -> bool:
	match _st:
		200:
			_flow.begin_direct(_flow.chapter_of(&"free_mode"), seed_ + _runs); _runs += 1; _wait = 30; _st = 201
		201:
			if scr == GameFlow.Screen.EVENT and bool(_flow.last_payload.get("briefing", false)):
				_flow.close_briefing(); _wait = 10; return true
			if scr != GameFlow.Screen.MAP: return true
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				_ms().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return true
			var r := _flow.run
			for id in [&"knife", &"bone_greatsword", &"battle_axe", &"bone_spear", &"round_shield"]:
				var d := _flow.items.get_def(id)
				if d != null: r.board.try_add(ItemInstance.create(d, 0))
			_flow._flush()
			if _empty:
				_flow.run.force_extract(); _flow._flush(); _wait = 60; _st = 203; return true
			_target = _target_search(); _steps = 0; _st = 202
		202:
			if not _walk_to_search(): return true
			_flow.run.force_extract(); _flow._flush(); _wait = 60; _st = 203
		203:
			if scr == GameFlow.Screen.SEARCH or scr == GameFlow.Screen.LOOT or scr == GameFlow.Screen.EVENT: _push_other(); _wait = 10; return true
			if scr != GameFlow.Screen.RESULT: return true
			_last_run_id = _flow.result.run_id
			L("　　这一局：%s；走了 %d 步；正式探索 %s；run_id %s" % ["空跑" if _empty else "正式", _flow.result.steps, str(_flow.formal_run()), _last_run_id])
			_flow.finish_result(); _wait = 40; _st = 204
		204:
			if scr != GameFlow.Screen.META: return true
			_st = _ret
		_:
			return false
	return true


var _last_run_id := ""


## v6.84 两处：右列仓库在不在屏里；作物顶端离苗圃页（Stage）上沿多远
func _fit() -> String:
	var vr := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var o := []
	var rt = _ms()._right
	if rt != null and (rt as Control).is_visible_in_tree():
		var r := (rt as Control).get_global_rect()
		o.append("右列 %s 在屏里 %s" % [str(r), str(vr.grow(1).encloses(r))])
		for n in (rt as Node).find_children("*", "ContainerView", true, false):
			if (n as Control).is_visible_in_tree():
				var g := (n as Control).get_global_rect()
				o.append("仓库格 %s 在屏里 %s" % [str(g), str(vr.grow(1).encloses(g))])
	else: o.append("右列收起")
	var np = _ms().nursery_panel()
	if np != null:
		var pr := (np as Control).get_global_rect()
		var st := (np as Node).find_child("Stage", true, false) as Control
		o.append("苗圃页 %s；Stage %s" % [str(pr), str(st.get_global_rect()) if st != null else "-"])
		for pl in (np as Node).find_children("Plant", "Control", true, false):
			if (pl as Control).is_visible_in_tree():
				var g := (pl as Control).get_global_rect()
				o.append("作物 %s 顶离页上沿 %d、离屏上沿 %d" % [str(g), int(g.position.y - pr.position.y), int(g.position.y)])
	return "；".join(o)


## 键上的「可收获」小图：有没有、看不看得见、在不在键里
func _mk(b) -> String:
	var m := (b as Node).get_node_or_null("RipeMark") as TextureRect
	if m == null: return "［无小图］"
	var br := (b as Control).get_global_rect()
	var mr := m.get_global_rect()
	return "［小图 %s，%s，在键里 %s］" % ["显示" if m.is_visible_in_tree() else "隐藏", str(mr), str(br.encloses(mr))]
func L(s: String) -> void:
	print("N682 " + s)


func shot(n: String) -> void:
	_shots += 1
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/nursery_%02d_%s.png" % [out, _shots, n])


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


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 60000:
		L("超时 st %d" % _st); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	var scr := _flow.screen
	if _st >= 200 and _st < 300:
		_run_step(scr); return false
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
			L("新档进基地：后勤小键 %s；苗圃开 %s；局外存档版本 %d；%s" % [str(_ms()._sub_btns.keys()), str(_flow.facility_open(&"nursery")), MetaState.SAVE_VERSION, _plot()])
			_empty = false; _ret = 3; _st = 200
		3:
			L("第一局正式探索回营：%s；后勤小键 %s；%s" % [_book(), str(_ms()._sub_btns.keys()), _growers()])
			_click(_ms()._tab_btns["logistics"]); _wait = 20; _st = 4
		4:
			var nb = _ms()._sub_btns.get("nursery")
			if nb == null: L("没有「苗圃」小键"); _st = 99; return false
			_click(nb); _wait = 20; _st = 5
		5:
			var lp = _ms().locked_page()
			L("真点「苗圃」（没办《第一畦》）：落在 %s；说明板 %s：%s" % [_ms()._sub, "看得见" if lp != null and lp.is_visible_in_tree() else "看不见", _labels_under(lp) if lp != null else ""])
			L("　　排版：%s" % _overflow(lp))
			shot("nursery_locked")
			_ms()._tab_btns["commissions"].pressed.emit(); _wait = 20; _st = 6
		6:
			_click(_named("Sub_story")); _wait = 20; _st = 7
		7:
			var fk := _btn_has([Names.of(Commissions.faction(&"growers"))])
			if fk != null: _click(fk)
			_wait = 20; _st = 8
		8:
			var rb := _named("Report_growers_first_bed")
			if rb == null: L("没有《第一畦》的【办理】"); _st = 99; return false
			_click(rb); _wait = 30; _st = 9
		9:
			L("真点【办理】《第一畦》后：苗圃开 %s；%s；告示 %s" % [str(_flow.facility_open(&"nursery")), _growers(), str(NoticeLayer.history().slice(0, 2).map(func(x): return x.get("text", "")))])
			_click(_ms()._tab_btns["logistics"]); _wait = 20; _st = 10
		10:
			_click(_ms()._sub_btns["nursery"]); _wait = 20; _st = 11
		11:
			var np = _ms().nursery_panel()
			L("苗圃页：%s" % _labels_under(np))
			L("　　右列仓库 %s；排版：%s" % ["露着" if _ms()._right != null and _ms()._right.is_visible_in_tree() else "收起", _overflow(np)])
			L("　　版面：%s" % _fit())
			var bl := _named("Sow_0_bitter_leaf")
			L("　　【种下】苦叶草：灰 %s「%s」（仓库干草药 %d）" % [str((bl as BaseButton).disabled) if bl != null else "-", bl.tooltip_text if bl != null else "", _wh("dried_herbs")])
			shot("nursery_empty")
			var rh := _named("Sow_0_rope_hemp")
			if rh == null: L("没有绳麻的【种下】"); _st = 99; return false
			_click(rh); _wait = 25; _st = 12
		12:
			L("真点【种下】绳麻：%s；%s" % [_plot(), _growers()])
			L("　　苗圃页：%s" % _labels_under(_ms().nursery_panel()))
			L("　　版面（nursery_sown）：%s" % _fit())
			shot("nursery_sown")
			_empty = true; _ret = 13; _st = 200
		13:
			L("空跑一局后：%s" % _plot())
			_empty = false; _ret = 14; _st = 200
		14:
			L("正式一局后：%s" % _plot())
			L("　　测试辅助：同一局 %s 再推进一次 → %s；%s" % [_last_run_id, str(Nursery.advance(_flow.meta, _last_run_id)), _plot()])
			_flow.save_meta(); _flow.to_main_menu(); _wait = 30; _st = 15
		15:
			_flow.continue_game(); _wait = 40; _st = 16
		16:
			if scr != GameFlow.Screen.META: return false
			L("存档回主菜单再继续：%s" % _plot())
			_empty = false; _ret = 17; _st = 200
		17:
			L("正式第二局后：%s；后勤页签「%s」%s" % [_plot(), (_ms()._tab_btns["logistics"] as Button).text, _mk(_ms()._tab_btns["logistics"])])
			_empty = false; _ret = 18; _st = 200
		18:
			L("正式第三局后：%s；后勤页签「%s」%s；悬浮「%s」" % [_plot(), (_ms()._tab_btns["logistics"] as Button).text, _mk(_ms()._tab_btns["logistics"]), (_ms()._tab_btns["logistics"] as Button).tooltip_text])
			_click(_ms()._tab_btns["logistics"]); _wait = 20; _st = 19
		19:
			_click(_ms()._sub_btns["nursery"]); _wait = 20; _st = 20
		20:
			L("熟了的苗圃页：%s；小键「%s」%s 悬浮「%s」" % [_labels_under(_ms().nursery_panel()), (_ms()._sub_btns["nursery"] as Button).text, _mk(_ms()._sub_btns["nursery"]), (_ms()._sub_btns["nursery"] as Button).tooltip_text])
			L("　　排版：%s；左列小键排版：%s" % [_overflow(_ms().nursery_panel()), _overflow(_ms()._sub_btns["nursery"].get_parent())])
			L("　　版面：%s" % _fit())
			shot("nursery_ripe")
			var before := _flow.meta.warehouse.item_count()
			_filler = []
			for k in 400:
				var it := _put("dried_herbs")
				if it == null: break
				_filler.append(it.uid)
			_full_count = _flow.meta.warehouse.item_count()
			L("测试辅助：仓库塞干草药 %d 束直到放不下（%d → %d 件）" % [_filler.size(), before, _full_count])
			_flow.meta.changed.emit()
			_wait = 10; _st = 21
		21:
			var hb := _named("Harvest_0")
			if hb == null: L("没有【收获】"); _st = 99; return false
			_click(hb); _wait = 25; _st = 22
		22:
			L("仓库满时真点【收获】：仓库 %d 件（之前 %d）；麻绳卷 %d；%s；告示 %s" % [_flow.meta.warehouse.item_count(), _full_count, _wh("rope_coil"), _plot(), str(NoticeLayer.history().slice(0, 1).map(func(x): return x.get("text", "")))])
			L("　　版面（harvest_full）：%s" % _fit())
			shot("harvest_full")
			for uid in _filler.slice(0, 3): _flow.meta.warehouse.remove(uid)
			_flow.meta.changed.emit()
			L("测试辅助：拿掉 3 束干草药")
			_wait = 10; _st = 23
		23:
			_click(_named("Harvest_0")); _wait = 25; _st = 24
		24:
			L("再真点【收获】：麻绳卷 %d；%s；%s；后勤页签「%s」%s；小键%s；排版：%s" % [_wh("rope_coil"), _plot(), _growers(), (_ms()._tab_btns["logistics"] as Button).text, _mk(_ms()._tab_btns["logistics"]), _mk(_ms()._sub_btns["nursery"]), _overflow(_ms().nursery_panel())])
			L("　　版面（harvested）：%s" % _fit())
			shot("harvested")
			for uid in _filler: _flow.meta.warehouse.remove(uid)
			_put("dried_herbs")
			_flow.meta.changed.emit()
			L("测试辅助：清掉塞的干草药，放一束（仓库干草药 %d）" % _wh("dried_herbs"))
			_wait = 10; _st = 25
		25:
			var bl := _named("Sow_0_bitter_leaf")
			L("【种下】苦叶草：灰 %s" % (str((bl as BaseButton).disabled) if bl != null else "-"))
			if bl != null: _click(bl)
			_wait = 25; _st = 26
		26:
			L("真点【种下】苦叶草后：仓库干草药 %d；%s；%s；排版：%s" % [_wh("dried_herbs"), _plot(), _growers(), _overflow(_ms().nursery_panel())])
			L("　　版面（bitter_sown）：%s" % _fit())
			shot("bitter_sown")
			_st = 99
		_:
			quit(0); return true
	return false


var _full_count := 0
