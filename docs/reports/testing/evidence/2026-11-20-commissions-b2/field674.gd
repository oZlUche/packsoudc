extends SceneTree
## 游戏测试 v6.70（报告 346）：参数 <outdir> <seed>
## 一、铁匠铺（基地，真鼠标）：测试辅助往仓库放素材 → 后勤 → 铁匠铺 → 冶炼铜锭（铜矿石 ×2）→ 圆盾（铜锭 + 风干木料）
##   → 皮甲（熟皮革 ×2 + 兽尾）→ 放血刀（碎骨串 + 钢锭 + 致密玄武岩）；每张先记打造界面的素材行，再点【打造】
## 二、无名的祭坛（真鼠标）：拒教程的新档，指定种子出征 → 走到「无名的祭坛」→ 真点【靠近】→ 看是哪位神、正文 → 真点【拿起护符】
var out := ""
var seed_ := 1
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _shots := 0
var _target := -1
var _steps := 0
var _smith: Array = []
var _si := 0
var _god := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: seed_ = int(a[1])
	if a.size() > 2: want = a[2]
	DirAccess.make_dir_recursive_absolute(out)
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func L(s: String) -> void:
	print("F674 " + s)


func shot(n: String) -> void:
	_shots += 1
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/field_%02d_%s.png" % [out, _shots, n])


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


var _off := {}


## 走向 [member _target]；到了（祭坛事件屏）返回 true
func _walk() -> bool:
	var scr := _flow.screen
	var r := _flow.run
	if r.is_over(): L("走的路上这一局结束了"); quit(1); return false
	if scr == GameFlow.Screen.EVENT and r.events.pending_event() != null and r.events.pending_node() != null and r.events.pending_node().id == _target and String(r.events.pending_event().id) == "faith_call":
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
	var hop := _next_hop(_target)
	if hop < 0: L("到 %d 没路" % _target); quit(1); return false
	var v: MapView = _ms()._view
	var gp := v.get_global_transform() * v.to_screen(v.positions().get(hop, Vector2.ZERO))
	for n in root.find_children("*", "HoverTip", true, false): n.hide_tip()
	if Rect2(Vector2.ZERO, root.get_visible_rect().size).has_point(gp): _click_node(hop)
	else:
		if not _off.has(hop): L("（节点 %d 在屏幕外：改直接调 _on_node_pressed）" % hop); _off[hop] = true
		_ms()._on_node_pressed(hop, MOUSE_BUTTON_LEFT, false)
	_wait = 15
	return false


func _ev_page(tag: String) -> void:
	var r := _flow.run
	var ev: EventDef = r.events.pending_event()
	var ov = _game.overlay()
	if ov == null: ov = _game.base()
	L("%s：事件 %s；标题「%s」；正文「%s」（%d 字）" % [tag, String(ev.id) if ev != null else "无", ev.title if ev != null else "", ev.text if ev != null else "", ev.text.length() if ev != null else 0])
	L("　　键 %s" % _list_buttons())
	L("　　页上的字：%s" % _labels_under(ov).left(600))


var _tk := 0
var want := ""
var _tries := 0


func _charm_where() -> String:
	var r := _flow.run
	var where := []
	for pair in [[r.board, "背包"], [r.storage, "地上"]]:
		for it in pair[0].items():
			if String((it as ItemInstance).def.id).begins_with("charm_"): where.append("%s（%s，%s）" % [Names.of((it as ItemInstance).def), String((it as ItemInstance).def.id), pair[1]])
	return str(where)


func _smithy() -> Control:
	for n in root.find_children("*", "", true, false):
		if n is Control and n.get_script() != null and String(n.get_script().resource_path).ends_with("smithy_panel.gd") and (n as Control).is_visible_in_tree(): return n
	return null


## ===== v6.74 局内目标：击败敌人、到访节点 =====
## 新档拒教程 → 测试辅助：三份开放单办理、五份基础剧情记办成（留《清出一条路》）→ 接上《协会登记证》《灰灯会牌》
## → 真点出征 → 依次走到 2 处搜索点、2 处休息点、3 场普通战斗 → 测试辅助撤离 → 结算 → 回基地看委托簿
var _plan: Array = []
var _pi := 0


func _book_line() -> String:
	var b = _flow.meta.commissions
	var o := []
	for id in ["legion_clear_road", "legion_permit", "society_permit", "greylamp_permit"]:
		var e: Dictionary = b.entry(StringName(id))
		o.append("%s %s 进度 %s" % [id, b.state_of(StringName(id)), str(e.get("progress", "-"))])
	var reps := []
	for f in Commissions.factions():
		reps.append("%s %d" % [String(f.id), b.rep_of(f.id)])
	return "%s；声望 %s" % ["；".join(o), "、".join(reps)]


func _mod_line() -> String:
	var m := CommissionModule.of(_flow.run) if _flow.run != null else null
	if m == null: return "（本局没有委托模块）"
	return "tracked %s；本局记账 %s" % [str(m.tracked.map(func(t): return "%s 第%d步 done %s" % [t.get("id"), int(t.get("stage", 0)), str(t.get("done", 0))])), str(m.rows)]


func _walk2() -> bool:
	var scr := _flow.screen
	var r := _flow.run
	if r.is_over() or scr == GameFlow.Screen.RESULT:
		L("走的路上这一局结束了（%s，%s）：%s" % [RunState.Phase.keys()[r.phase], String(r.end_reason), _mod_line()])
		_st = 21; return false
	if scr != GameFlow.Screen.MAP:
		_push_other(); _wait = 12; return false
	for c in root.find_children("*", "CoachOverlay", true, false):
		(c as CoachOverlay).next(); _wait = 5; return false
	if _ms().ground_warn_open():
		var g := _btn_has([UiText.t("map.ground_go")])
		if g != null: _click(g)
		_wait = 10; return false
	if r.travel.current_id == _target: return true
	_steps += 1
	if _steps > 150: L("走了 150 步还没到"); quit(1); return false
	var hop := _next_hop(_target)
	if hop < 0: L("到 %d 没路" % _target); return true
	var v: MapView = _ms()._view
	var gp := v.get_global_transform() * v.to_screen(v.positions().get(hop, Vector2.ZERO))
	for n in root.find_children("*", "HoverTip", true, false): n.hide_tip()
	if Rect2(Vector2.ZERO, root.get_visible_rect().size).has_point(gp): _click_node(hop)
	else: _ms()._on_node_pressed(hop, MOUSE_BUTTON_LEFT, false)
	_wait = 15
	return false


func _pick_targets() -> void:
	var r := _flow.run
	var want := {&"search": 2, &"rest": 2, &"battle": 3}
	var got := {}
	var used := {}
	var cur: int = r.travel.current_id
	var types := {}
	for id in r.map.node_ids():
		var tt := String(NodeEvents.effective_type(r.map.get_node(id)))
		types[tt] = int(types.get(tt, 0)) + 1
	L("这张图的点：%s" % str(types))
	_plan = []
	for k in 7:
		var best := -1
		var bd := 1 << 30
		for id in r.map.node_ids():
			var nd := r.map.get_node(id)
			if nd == null or used.has(id) or nd.is_visited() or id == cur: continue
			var t := NodeEvents.effective_type(nd)
			if not want.has(t) or int(got.get(t, 0)) >= int(want[t]): continue
			var d := _dist(cur, id)
			if d >= 0 and d < bd: bd = d; best = id
		if best < 0: break
		var bt := NodeEvents.effective_type(r.map.get_node(best))
		got[bt] = int(got.get(bt, 0)) + 1
		used[best] = true
		_plan.append(best)
	L("目标顺序：%s" % str(_plan.map(func(id): return "%d(%s)" % [id, String(NodeEvents.effective_type(r.map.get_node(id)))])))


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
			for id in [&"legion_forge_token", &"society_first_survey", &"greylamp_check_scale"]:
				_flow.report_commission(id)
			for id in [&"legion_check_materials", &"society_copy_recipe", &"society_identify_ore", &"greylamp_unsigned_letter", &"greylamp_check_medkits"]:
				var d := Commissions.def(id)
				if not _flow.meta.commissions.taken().has(id): Commissions.take(_flow.meta.commissions, d)
				Commissions._complete(_flow.meta, d, _flow.items)
			_flow.sync_commissions(); _flow.save_meta()
			L("测试辅助：三份开放单办理、五份基础剧情记办成；接着的 %s" % str(_flow.meta.commissions.taken()))
			L("　　%s" % _book_line())
			_flow.next_run_seed = seed_
			var ex := _btn_has([UiText.t("meta.tab_expedition")])
			if ex != null: _click(ex)
			_wait = 20; _st = 10
		10:
			var sb: Button = _ms().get("_new_run_btn")
			if sb != null: _click(sb)
			_wait = 40; _st = 11
		11:
			if scr == GameFlow.Screen.SETUP:
				var sp: Node = null
				for n in root.find_children("*", "", true, false):
					if n.has_method("carry_in") and n.has_method("depart"): sp = n
				var eb = sp.get("_enter_btn") if sp != null else null
				if sp != null and sp.needs_spawn():
					sp.pick_spawn(sp._preview.entry_ids()[0]); _wait = 20; return false
				if eb != null and (eb as Button).is_visible_in_tree(): _click(eb)
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
			for id in [&"knife", &"bone_greatsword", &"battle_axe", &"bone_spear", &"round_shield"]:
				var d := _flow.items.get_def(id)
				if d != null: r.board.try_add(ItemInstance.create(d, 0))
			_flow._flush()
			L("进图：种子 %d；%s" % [seed_, _mod_line()])
			L("　　测试辅助：棋盘放小刀、骨大剑、战斧、骨矛、圆盾防打输")
			shot("map_start")
			_pick_targets(); _pi = 0; _st = 12
		12:
			if _pi >= _plan.size():
				_st = 20; return false
			_target = _plan[_pi]; _steps = 0; _st = 13
		13:
			if not _walk2(): return false
			if _st != 13: return false
			var nd := _flow.run.map.get_node(_target)
			L("到 %d（%s）：%s" % [_target, String(NodeEvents.effective_type(nd)), _mod_line()])
			if _pi == 1 or _pi == 3 or _pi == _plan.size() - 1: shot("at_%d" % _pi)
			_pi += 1; _st = 12
		20:
			L("走完，测试辅助撤离：%s" % str(_flow.run.force_extract()))
			_flow._flush(); _wait = 80; _st = 21
		21:
			if scr == GameFlow.Screen.RESULT:
				var ov = _game.overlay()
				if ov == null: ov = _game.base()
				var lines := []
				for n in root.find_children("Commissions", "PanelContainer", true, false):
					lines.append(_labels_under(n))
				L("结算屏委托段：%s" % str(lines))
				shot("result")
				_flow.to_main_menu(); _wait = 30; _st = 22
			elif _f % 200 == 0: L("（等结算：屏 %s）" % GameFlow.Screen.keys()[scr])
		22:
			_flow.continue_game(); _wait = 40; _st = 23
		23:
			if scr != GameFlow.Screen.META: return false
			L("回基地：%s" % _book_line())
			L("　　接着的 %s；回执最后三条 %s" % [str(_flow.meta.commissions.taken()), str(_flow.meta.commissions.receipts.slice(-3))])
			_st = 99
		_:
			quit(0); return true
	return false
