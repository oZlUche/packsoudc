extends SceneTree
## 游戏测试 v6.58（阵营与委托 W1，报告 337）：报告 335 第四节的循环，真鼠标走。参数：<outdir>
## 第一局：拒教程 → 基地「委托」页真点接《两条回路》《无人署名的信》→ 出征 → 走到免费撤离点 → 真点「把信交给接应员」「查验这处出口」
##   → 存档回主菜单真点「继续」→ 看选项不再出现 →「再看看」→ 走开再回来 → 测试辅助败退 → 结算屏 → 委托簿
## 第二局：只带《两条回路》→ 同一免费撤离点看能不能再查验（不点）→ 走到付费撤离点真点查验 → 撤离 → 结算屏 → 委托簿 → 回主菜单再读
## 每到撤离点都列一遍可点的键，看有没有【托付】
var out := ""
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _shots := 0
var _run_no := 1
var _target := -1
var _free_id := -1
var _paid_id := -1
var _leave_from := -1
var _steps := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func L(s: String) -> void:
	print("C658 " + s)


func shot(n: String) -> void:
	_shots += 1
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/%02d_%s.png" % [out, _shots, n])


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
	_mouse_at(b.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)


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


func _btn_named(nm: String) -> BaseButton:
	for b in _buttons():
		if (b as Node).name == nm: return b
	return null


func _list_buttons() -> String:
	var o := []
	for b in _buttons():
		var t := _btn_text(b)
		if t != "": o.append("[%s%s]" % [t, "（灰）" if (b as BaseButton).disabled else ""])
	return " ".join(o)


func _ms() -> Node:
	return _game.base()


func _hud_text() -> String:
	for n in root.find_children("*", "", true, false):
		if n is HudWidget and String(n.get_script().resource_path).ends_with("commissions_widget.gd"):
			return "%s（显示 %s）" % [(n as HudWidget).text_of().replace("\n", " | "), str((n as Control).is_visible_in_tree())]
	return "（没有委托小牌）"


func _book() -> String:
	var b := _flow.meta.commissions
	var o := []
	for id in ["legion_two_routes", "greylamp_unsigned_letter", "society_copy_recipe"]:
		var e := b.entry(StringName(id))
		if not e.is_empty(): o.append("%s：%s 第 %d 步 进度 %d keys %d" % [id, b.state_of(StringName(id)), int(e.get("stage", 0)), int(e.get("progress", 0)), (e.get("keys", []) as Array).size()])
	return "声望 %s；%s；回执 %s" % [str(b.rep), "；".join(o), str(b.receipts.map(func(r): return "%s/%s" % [r.get("id"), r.get("kind")]))]


func _mod_rows() -> int:
	var m := CommissionModule.of(_flow.run) if _flow.run != null else null
	return m.rows.size() if m != null else -1


func _result_comm() -> String:
	for n in root.find_children("Commissions", "PanelContainer", true, false):
		return "显示 %s：%s" % [str((n as Control).is_visible_in_tree()), _labels_under_all(n)]
	return "（结算屏没有委托段）"


func _labels_under_all(n: Node) -> String:
	var o := []
	for l in n.find_children("*", "Label", true, false):
		if (l as Label).text.strip_edges() != "": o.append((l as Label).text.strip_edges().replace("\n", " "))
	return " / ".join(o)


func _labels_under(n: Node) -> String:
	var o := []
	for l in n.find_children("*", "Label", true, false):
		if (l as Control).is_visible_in_tree() and (l as Label).text.strip_edges() != "": o.append((l as Label).text.strip_edges().replace("\n", " "))
	return " / ".join(o)


func _click_node(id: int) -> void:
	var v: MapView = _ms()._view
	var gp := v.get_global_transform() * v.to_screen(v.positions().get(id, Vector2.ZERO))
	_mouse_at(gp, MOUSE_BUTTON_LEFT)


## 从现在的点到 [param to] 的下一步（避开战斗 / 精英：权重高）
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


func _find_extracts() -> void:
	var r := _flow.run
	var ids := []
	for id in r.map.node_ids():
		ids.append(id)
	_free_id = -1; _paid_id = -1
	var desc := []
	for id in ids:
		var nd := r.map.get_node(id)
		if nd == null or NodeEvents.effective_type(nd) != &"extract": continue
		var fee := PaidExtracts.fee_of(nd)
		desc.append("%d（费 %d）" % [id, fee])
		if fee <= 0 and _free_id < 0: _free_id = id
		if fee > 0 and _paid_id < 0: _paid_id = id
	L("撤离点：%s；现在在 %d" % [", ".join(desc), r.travel.current_id])


## 不是要看的屏：照常推过去（战斗跳到底）
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


## 走向 [member _target]。到了（且是撤离点事件屏）返回 true
func _walk() -> bool:
	var scr := _flow.screen
	var r := _flow.run
	if r.is_over(): L("走的路上这一局结束了（%s，%s；屏 %s）" % [RunState.Phase.keys()[r.phase], String(r.end_reason), GameFlow.Screen.keys()[scr]]); quit(1); return false
	if scr == GameFlow.Screen.EVENT and r.events.pending_event() != null and r.events.pending_node() != null and r.events.pending_node().id == _target and String(r.events.pending_event().id) == "extract_default":
		return true
	if scr != GameFlow.Screen.MAP:
		_push_other(); _wait = 12; return false
	for c in root.find_children("*", "CoachOverlay", true, false):
		(c as CoachOverlay).next(); _wait = 5; return false
	var ms := _ms()
	if ms.ground_warn_open():
		var g := _btn_has([UiText.t("map.ground_go")])
		if g != null: _click(g)
		_wait = 10; return false
	_steps += 1
	if _steps > 120: L("走了 120 步还没到"); quit(1); return false
	if r.travel.current_id == _target:
		# 已经在撤离点上（事件关了）：点自己那一格再开
		_click_node(_target); _wait = 15; return false
	var hop := _next_hop(_target)
	if _steps == 10:
		var v: MapView = _ms()._view
		var gp := v.get_global_transform() * v.to_screen(v.positions().get(hop, Vector2.ZERO))
		var hc := root.gui_get_hovered_control()
		L("（卡住：点 %d 在画布 %s；鼠标下的控件 %s（%s）%s）" % [hop, str(gp), str(hc), hc.get_path() if hc != null else "", str(hc.get_global_rect()) if hc != null else ""])
		for n in root.find_children("*", "", true, false):
			if n is HudWidget and String(n.get_script().resource_path).ends_with("commissions_widget.gd"): L("　　委托小牌范围 %s" % str((n as Control).get_global_rect()))
		shot("stuck")
	if _steps % 20 == 0: L("（走：在 %d → %d，下一步 %d，可走 %s）" % [r.travel.current_id, _target, hop, str(r.travel.available_moves())])
	if hop < 0: L("到 %d 没路" % _target); quit(1); return false
	var v: MapView = _ms()._view
	var gp := v.get_global_transform() * v.to_screen(v.positions().get(hop, Vector2.ZERO))
	for n in root.find_children("*", "HoverTip", true, false): n.hide_tip()
	if Rect2(Vector2.ZERO, root.get_visible_rect().size).has_point(gp): _click_node(hop)
	else:
		if not _off.has(hop): L("（节点 %d 在屏幕外 %s：改直接调 _on_node_pressed）" % [hop, str(gp)]); _off[hop] = true
		_ms()._on_node_pressed(hop, MOUSE_BUTTON_LEFT, false)
	_wait = 15
	return false
var _off := {}


func _ev_state(tag: String) -> void:
	var r := _flow.run
	L("%s：屏 %s；事件 %s；键 %s" % [tag, GameFlow.Screen.keys()[_flow.screen], String(r.events.pending_event().id) if r.events.pending_event() != null else "无", _list_buttons()])
	var fee := []
	for l in root.find_children("*", "", true, false):
		if (l is Label or l is RichTextLabel) and (l as Control).is_visible_in_tree():
			var t: String = (l as RichTextLabel).get_parsed_text() if l is RichTextLabel else (l as Label).text
			for line in t.split("\n"):
				if line.contains("费用") or line.contains("Fee") or line.contains("能出去") or line.contains("A way out"): fee.append(line.strip_edges())
	L("　　正文：%s" % " | ".join(fee))
	L("　　小牌「%s」；本局记账 %d 条；托付键 %s" % [_hud_text(), _mod_rows(), "在" if _btn_has([UiText.t("map.entrust")]) != null else "不在"])


## 事件结果页（只有【继续】）：记下页上的字，点继续。点了返回 true
func _ev_continue() -> bool:
	if _flow.screen != GameFlow.Screen.EVENT or _btn_has(["撤离", "Extract"]) != null: return false
	var c := _btn_has([UiText.t("menu.continue")])
	if c == null: return false
	var ov = _game.overlay()
	if ov == null: ov = _game.base()
	L("　　结果页的字：%s" % _labels_under(ov))
	_click(c); _wait = 25
	return true


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 30000:
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
			L("基地：委托簿可见 %s；教程全通 %s" % [str(_flow.commissions_visible()), str(_flow.tutorials_done())])
			var t := _btn_has([UiText.t("meta.tab_commissions")])
			L("左列页签：%s" % _list_buttons())
			if t == null: L("没有「委托」页签"); quit(1); return true
			_click(t); _wait = 20; _st = 3
		3:
			var p = _ms().commission_panel()
			L("真点「委托」页签：面板 %s，当前一方 %s" % [str(p != null and (p as Control).is_visible_in_tree()), String(p.faction()) if p != null else "-"])
			L("　　页里的字：%s" % _labels_under(p))
			shot("book_legion")
			var take := _btn_named("Take_legion_two_routes")
			L("　　《两条回路》接下键 %s" % ("在" if take != null else "不在"))
			if take != null: _click(take)
			_wait = 20; _st = 4
		4:
			L("真点接下《两条回路》：%s" % _book())
			shot("book_legion_taken")
			var gl := _btn_has([Names.of(Commissions.faction(&"greylamp"))])
			if gl != null: _click(gl)
			_wait = 20; _st = 5
		5:
			var p = _ms().commission_panel()
			L("真点灰灯：当前一方 %s；%s" % [String(p.faction()), _labels_under(p)])
			var take := _btn_named("Take_greylamp_unsigned_letter")
			if take != null: _click(take)
			_wait = 20; _st = 6
		6:
			L("真点接下《无人署名的信》：%s" % _book())
			shot("book_greylamp_taken")
			var so := _btn_has([Names.of(Commissions.faction(&"society"))])
			if so != null: _click(so)
			_wait = 20; _st = 7
		7:
			var p = _ms().commission_panel()
			var take := _btn_named("Take_society_copy_recipe")
			var pick := _btn_named("Pick_society_copy_recipe")
			L("考据所：接下键 %s（灰 %s，提示「%s」）；配方下拉 %s（灰 %s，提示「%s」）" % [str(take != null), str(take.disabled) if take else "-", take.tooltip_text if take else "", str(pick != null), str(pick.disabled) if pick else "-", pick.tooltip_text if pick else ""])
			shot("book_society")
			var ex := _btn_has([UiText.t("meta.tab_expedition")])
			if ex != null: _click(ex)
			_wait = 20; _st = 8
		8:
			var sb: Button = _ms().get("_new_run_btn")
			L("出征页：出发键 %s" % ("「%s」" % sb.text.strip_edges() if sb != null else "没有"))
			if sb != null: _click(sb)
			_wait = 40; _st = 9
		9:
			if _f % 300 == 0: L("（等进图：屏 %s）" % GameFlow.Screen.keys()[scr])
			if scr == GameFlow.Screen.SETUP:
				var sp: Node = null
				for n in root.find_children("*", "", true, false):
					if n.has_method("carry_in") and n.has_method("depart"): sp = n
				var eb = sp.get("_enter_btn") if sp != null else null
				if sp != null and sp.needs_spawn():
					var eid: int = sp._preview.entry_ids()[0]
					L("开局屏要挑出生点：测试辅助 pick_spawn(%d) → %s" % [eid, str(sp.pick_spawn(eid))])
					_wait = 20; return false
				if sp != null and sp.can_depart() != "" and _f % 300 < 40: L("开局屏出发不了：%s" % sp.can_depart())
				if eb != null and (eb as Button).is_visible_in_tree():
					if _f % 300 < 40: L("开局屏：点「%s」" % (eb as Button).text)
					_click(eb)
				elif sp != null: sp.depart()
				_wait = 30; return false
			if scr == GameFlow.Screen.EVENT and bool(_flow.last_payload.get("briefing", false)):
				_flow.close_briefing(); _wait = 10; return false
			if scr != GameFlow.Screen.MAP: return false
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next(); _wait = 5; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				_ms().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			var r := _flow.run
			for id in [&"knife", &"round_shield", &"bone_greatsword", &"battle_axe", &"bone_spear"]:
				var d := _flow.items.get_def(id)
				if d != null: r.board.try_add(ItemInstance.create(d, 0))
			_flow._flush()
			var letters := []
			for c in [r.board, r.storage]:
				for it in c.items():
					if (it as ItemInstance).def.id == &"commission_letter": letters.append("%s#%d（在%s）" % [Names.of((it as ItemInstance).def), (it as ItemInstance).uid, "背包" if c == r.board else "地上"])
			L("第 %d 局进图：章 %s；任务信 %s；小牌「%s」" % [_run_no, String(r.chapter.id), str(letters), _hud_text()])
			L("　　测试辅助：放 knife、round_shield、骨大剑、战斧、骨矛防路上打输（棋盘 %d 件）" % r.board.items().size())
			shot("run%d_map" % _run_no)
			_find_extracts()
			_target = _free_id if _run_no == 1 else _free_id
			_steps = 0
			_st = 10 if _run_no == 1 else 40
		# ---------- 第一局 ----------
		10:
			if not _walk(): return false
			_ev_state("到免费撤离点 %d" % _target)
			shot("free_extract_event")
			var b := _btn_has(["把信交给接应员", "Hand the letter"])
			if b == null: L("没有交信键"); quit(1); return true
			_click(b); _wait = 30; _st = 11
		11:
			if _ev_continue(): return false
			_ev_state("真点交信后")
			var h := NoticeLayer.history()
			L("　　告示：%s" % str(h.slice(0, 3).map(func(x): return x.get("text", ""))))
			var b := _btn_has(["查验这处出口", "Inspect this exit"])
			if b == null: L("没有查验键"); quit(1); return true
			_click(b); _wait = 30; _st = 12
		12:
			if _ev_continue(): return false
			_ev_state("真点查验后")
			var h := NoticeLayer.history()
			L("　　告示：%s" % str(h.slice(0, 3).map(func(x): return x.get("text", ""))))
			shot("after_deliver_inspect")
			L("存档：%s；回主菜单" % str(_flow.save()))
			_flow.to_main_menu(); _wait = 40; _st = 13
		13:
			var c := _btn_has([UiText.t("menu.continue")])
			L("主菜单「继续」键 %s" % ("在" if c != null else "不在"))
			if c != null: _click(c)
			else: _flow.continue_game()
			_wait = 60; _st = 14
		14:
			if scr == GameFlow.Screen.MAP:
				for c in root.find_children("*", "CoachOverlay", true, false):
					(c as CoachOverlay).next(); _wait = 5; return false
			_ev_state("读档回来")
			shot("after_reload")
			var b := _btn_has([UiText.t("map.entrust")])
			L("撤离点事件「托付」键 %s" % ("在" if b != null else "不在"))
			if b != null:
				_click(b); _wait = 30; _st = 30
			else:
				b = _btn_has(["再看看", "Not yet"])
				if b != null: _click(b)
				_wait = 30; _st = 15
		30:
			L("真点托付：屏 %s；键 %s" % [GameFlow.Screen.keys()[scr], _list_buttons()])
			shot("safe_screen")
			var ss: Node = null
			for n in root.find_children("*", "", true, false):
				if n.has_method("put_in") and n.has_method("safe_view"): ss = n
			if ss != null:
				var kn := -1
				for it in _flow.run.board.items():
					if (it as ItemInstance).def.id == &"knife": kn = (it as ItemInstance).uid
				L("测试辅助：把匕首放进托付格 → %s" % str(ss.put_in(kn)))
			_wait = 20; _st = 31
		31:
			shot("safe_with_knife")
			var b := _btn_has([UiText.t("safe.close")])
			L("托付屏关闭键 %s" % ("在" if b != null else "不在"))
			if b != null: _click(b)
			_wait = 30; _st = 32
		32:
			if scr != GameFlow.Screen.MAP: L("关托付屏后屏 %s" % GameFlow.Screen.keys()[scr]); _push_other(); _wait = 20; return false
			var sm := SafeModule.of(_flow.run)
			L("关托付屏回地图：在 %d；托付交出 %s；本局记账 %d" % [_flow.run.travel.current_id, str(sm.sealed if sm != null else "-"), _mod_rows()])
			_click_node(_flow.run.travel.current_id); _wait = 30; _st = 33
		33:
			if _ev_continue(): return false
			if scr != GameFlow.Screen.EVENT: L("站着点节点没弹事件（屏 %s）" % GameFlow.Screen.keys()[scr]); _st = 15; return false
			_ev_state("站着点节点再弹")
			shot("extract_again")
			var b := _btn_has(["再看看", "Not yet"])
			if b != null: _click(b)
			_wait = 30; _st = 15
		15:
			if scr != GameFlow.Screen.MAP: _push_other(); _wait = 10; return false
			L("「再看看」回地图：在 %d；托付键 %s；地图上的键 %s" % [_flow.run.travel.current_id, "在" if _btn_has([UiText.t("map.entrust")]) != null else "不在", _list_buttons()])
			shot("map_at_extract")
			# 走开一格
			var moves: Array = _flow.run.travel.available_moves()
			_leave_from = _flow.run.travel.current_id
			var to := -1
			for m in moves:
				var nd := _flow.run.map.get_node(m)
				if nd != null and nd.is_visited(): to = m; break
			if to < 0 and not moves.is_empty(): to = moves[0]
			_click_node(to); _wait = 20; _st = 16
		16:
			if _ms().ground_warn_open():
				var g := _btn_has([UiText.t("map.ground_go")]); if g != null: _click(g)
				_wait = 10; return false
			if scr != GameFlow.Screen.MAP: _push_other(); _wait = 12; return false
			L("走开到 %d，再回 %d" % [_flow.run.travel.current_id, _leave_from])
			_target = _leave_from; _steps = 0; _st = 17
		17:
			if not _walk(): return false
			_ev_state("重进同一撤离点")
			shot("reenter_extract")
			L("测试辅助：这一局败退（fail countdown）")
			var b := _btn_has(["再看看", "Not yet"])
			if b != null: _click(b)
			_wait = 20; _st = 18
		18:
			if scr != GameFlow.Screen.MAP: _push_other(); _wait = 10; return false
			L("败退前：本局记账 %d 条；局外 %s" % [_mod_rows(), _book()])
			_flow.run.fail(&"countdown"); _flow._flush(); _wait = 400; _st = 19
		19:
			L("结算屏 %s：%s" % [GameFlow.Screen.keys()[scr], str(_flow.last_commissions.get("credited", "?"))])
			var ov = _game.overlay()
			L("　　结算屏的字：%s" % (_labels_under(ov) if ov != null else _labels_under(root)))
			L("　　结算屏委托段：%s" % _result_comm())
			L("　　局外 %s" % _book())
			shot("run1_result")
			_st = 20; _wait = 10
		20:
			var b := _btn_has([UiText.t("menu.continue")])
			if b == null:
				for x in _buttons():
					if x is Button and not (x as Button).disabled and (x as Button).text.strip_edges() != "": b = x
			L("结算屏可点：%s" % _list_buttons())
			if b != null: _click(b)
			_wait = 40; _st = 21
		21:
			if scr == GameFlow.Screen.RESULT:
				var b := _btn_has([UiText.t("menu.continue")])
				if b != null: _click(b)
				else: _flow.resume()
				_wait = 40; return false
			if scr != GameFlow.Screen.META: return false
			var t := _btn_has([UiText.t("meta.tab_commissions")])
			if t != null: _click(t)
			_wait = 20; _st = 22
		22:
			var p = _ms().commission_panel()
			L("回营委托簿（军团）：%s" % _labels_under(p))
			shot("book_after_run1_legion")
			var gl := _btn_has([Names.of(Commissions.faction(&"greylamp"))])
			if gl != null: _click(gl)
			_wait = 20; _st = 23
		23:
			var p = _ms().commission_panel()
			L("回营委托簿（灰灯）：%s" % _labels_under(p))
			shot("book_after_run1_greylamp")
			L("局外：%s；金币 %d" % [_book(), _flow.meta.funds])
			_flow.to_main_menu(); _wait = 30; _st = 24
		24:
			var c := _btn_has([UiText.t("menu.continue")])
			if c != null: _click(c)
			else: _flow.continue_game()
			_wait = 60; _st = 25
		25:
			L("回主菜单再读：屏 %s；%s" % [GameFlow.Screen.keys()[scr], _book()])
			var ex := _btn_has([UiText.t("meta.tab_expedition")])
			if ex != null: _click(ex)
			_wait = 20; _run_no = 2; _st = 8
		# ---------- 第二局 ----------
		40:
			if not _walk(): return false
			_ev_state("第二局到同一免费撤离点 %d" % _target)
			shot("run2_free_extract")
			_target = _paid_id
			if _paid_id < 0: L("没有付费撤离点"); quit(1); return true
			var b := _btn_has(["再看看", "Not yet"])
			if b != null: _click(b)
			_steps = 0; _wait = 20; _st = 41
		41:
			if not _walk(): return false
			_ev_state("第二局到付费撤离点 %d" % _target)
			shot("run2_paid_extract")
			var b := _btn_has(["查验这处出口", "Inspect this exit"])
			if b == null: L("付费撤离点没有查验键"); _st = 43; return false
			_click(b); _wait = 30; _st = 42
		42:
			if _ev_continue(): return false
			_ev_state("付费点真点查验后")
			var h := NoticeLayer.history()
			L("　　告示：%s" % str(h.slice(0, 3).map(func(x): return x.get("text", ""))))
			shot("run2_after_inspect")
			_st = 43
		43:
			if _ev_continue(): return false
			L("付费点不撤（身上钱可能不够），「再看看」走回免费撤离点 %d 撤离" % _free_id)
			var b0 := _btn_has(["再看看", "Not yet"])
			if b0 != null: _click(b0)
			_target = _free_id; _steps = 0; _wait = 20; _st = 50
		50:
			if not _walk(): return false
			_ev_state("回到免费撤离点")
			var b := _btn_has(["撤离", "Extract"])
			L("真点撤离（费 %d）" % PaidExtracts.fee_of(_flow.run.map.get_node(_target)))
			if b != null: _click(b)
			_wait = 60; _st = 44
		44:
			if scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.MAP:
				L("撤离没成（屏 %s；%s），测试辅助 force_extract" % [GameFlow.Screen.keys()[scr], _list_buttons()])
				_flow.run.force_extract(); _flow._flush(); _wait = 400; _st = 45; return false
			_wait = 400; _st = 45
		45:
			L("第二局结算屏 %s；last_commissions %s" % [GameFlow.Screen.keys()[scr], str(_flow.last_commissions.get("credited", "?"))])
			var ov = _game.overlay()
			L("　　结算屏的字：%s" % (_labels_under(ov) if ov != null else _labels_under(root)))
			L("　　结算屏委托段：%s" % _result_comm())
			L("　　局外 %s" % _book())
			shot("run2_result")
			_wait = 10; _st = 46
		46:
			if scr == GameFlow.Screen.RESULT:
				var b := _btn_has([UiText.t("menu.continue")])
				if b != null: _click(b)
				else: _flow.resume()
				_wait = 40; return false
			if scr != GameFlow.Screen.META: return false
			var t := _btn_has([UiText.t("meta.tab_commissions")])
			if t != null: _click(t)
			_wait = 20; _st = 47
		47:
			var p = _ms().commission_panel()
			L("第二局后委托簿（军团）：%s" % _labels_under(p))
			shot("book_after_run2")
			_flow.to_main_menu(); _wait = 30; _st = 48
		48:
			_flow.continue_game(); _wait = 60; _st = 49
		49:
			L("再读：%s" % _book())
			L("走查完")
			quit(0); return true
	return false
