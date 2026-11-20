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
	print("A670 " + s)


func shot(n: String) -> void:
	_shots += 1
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/alt_%02d_%s.png" % [out, _shots, n])


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
			_flow.meta.funds = 2000
			if _flow.meta.commissions.get("gated") == true:
				_flow.meta.commissions.gated = false
				L("测试辅助：v6.72 起新档设施要剧情开放，这里记成不门控")
			_put("copper_ore", 2); _put("seasoned_timber", 1); _put("tanned_leather", 2); _put("beast_tail", 1)
			_put("bone_charm_bits", 1); _put("steel_ingot", 1); _put("dense_basalt", 1)
			_ms()._refresh()
			L("测试辅助：金币 2000；仓库放 铜矿石 ×2、风干木料、熟皮革 ×2、兽尾、碎骨串、钢锭、致密玄武岩；铁匠铺等级 %d" % Smithy.level(_flow.meta))
			var t := _btn_has([UiText.t("meta.tab_logistics")])
			_click(t); _wait = 20; _st = 3
		3:
			var sk: Button = _ms().sub_tab_buttons("logistics").get("smithy")
			_click(sk); _wait = 25; _st = 4
		4:
			var sp = _smithy()
			L("铁匠铺：%s" % ("开着" if sp != null else "没开"))
			if sp == null: quit(1); return true
			_smith = [&"smith_copper_ingot", &"smith_round_shield", &"smith_leather_armor", &"smith_bloodletter"]
			_si = 0
			_st = 5
		5:
			if _si >= _smith.size():
				_st = 9; return false
			var sp = _smithy()
			var id: StringName = _smith[_si]
			var r := SmithRecipeDef.find(_flow.smith_recipes, id)
			var gk = sp.group_key(r.group)
			if gk != null and sp.selected_group() != r.group:
				_click(gk); _wait = 15; return false
			var c = sp.cell(id)
			if c == null: L("%s：这一类里没有这一格" % id); _si += 1; return false
			if sp.opened() != id:
				_click(c); _wait = 15; _st = 6; return false
			_st = 6
		6:
			var sp = _smithy()
			var id: StringName = _smith[_si]
			var sc = sp.recipe_scroll()
			L("%s：打造界面「%s」；素材 %s；工钱 %d；能打吗「%s」" % [id, sc.title(), str(sc.material_lines()), sc.wage(), Smithy.can_forge(_flow.meta, SmithRecipeDef.find(_flow.smith_recipes, id), _flow.items)])
			shot("smith_%s" % String(id).trim_prefix("smith_"))
			var fk: Button = sc.forge_key
			if fk == null or not fk.is_visible_in_tree():
				L("　　没有【打造】键"); _si += 1; _st = 5; return false
			L("　　点【%s】（灰 %s）；之前金币 %d" % [fk.text, str(fk.disabled), _flow.meta.funds])
			_click(fk); _wait = 20; _st = 7
		7:
			var id: StringName = _smith[_si]
			var r := SmithRecipeDef.find(_flow.smith_recipes, id)
			L("　　打完：仓库里 %s %d 件；金币 %d；剩 铜矿石 %d 铜锭 %d 风干木料 %d 熟皮革 %d 兽尾 %d 碎骨串 %d 钢锭 %d 致密玄武岩 %d" % [String(r.output), _wh(String(r.output)), _flow.meta.funds,
				_wh("copper_ore"), _wh("copper_ingot"), _wh("seasoned_timber"), _wh("tanned_leather"), _wh("beast_tail"), _wh("bone_charm_bits"), _wh("steel_ingot"), _wh("dense_basalt")])
			_si += 1; _st = 5
		9:
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
			for id in [&"knife", &"bone_greatsword", &"battle_axe", &"bone_spear"]:
				var d := _flow.items.get_def(id)
				if d != null: r.board.try_add(ItemInstance.create(d, 0))
			_flow._flush()
			for id in r.map.node_ids():
				if String(r.map.get_node(id).content.get("event", "")) == "faith_call": _target = id
			var pred := ""
			if _target >= 0:
				var near := (r.events.def_by_id(&"faith_call").options[0] as EventOption)
				for o in near.outcomes:
					if o is NextEventRandom:
						var ctx := r.events._event_ctx(r.map.get_node(_target))
						(o as NextEventRandom).apply(ctx)
						pred = String(ctx.next_event)
			L("进图：种子 %d（局 %d）；祭坛在点 %d；按这一点的随机数靠近会到 %s；现在在 %d" % [seed_, r.run_seed, _target, pred, r.travel.current_id])
			L("　　测试辅助：棋盘放小刀、骨大剑、战斧、骨矛防路上打输")
			if _target < 0: quit(1); return true
			if want != "" and pred != "faith_call_" + want and _tries < 15:
				_tries += 1
				L("　　要看 %s：测试辅助直接撤离这一局，换下一个种子 %d" % [want, seed_ + 1])
				seed_ += 1
				_flow.run.force_extract(); _flow._flush(); _wait = 60; _st = 30
				return false
			_steps = 0; _st = 12
		12:
			if not _walk(): return false
			_ev_page("走到祭坛")
			shot("altar_faith_call")
			var b := _btn_has(["靠近", "Go closer"])
			if b == null: L("没有【靠近】"); quit(1); return true
			_click(b); _wait = 30; _st = 13
		13:
			var ev: EventDef = _flow.run.events.pending_event()
			if _flow.screen != GameFlow.Screen.EVENT or ev == null: L("靠近后不在事件屏：%s" % GameFlow.Screen.keys()[_flow.screen]); quit(1); return true
			_god = String(ev.id).trim_prefix("faith_call_")
			_ev_page("真点【靠近】后")
			shot("altar_god_%s" % _god)
			var b := _btn_has(["拿起护符", "Take the charm"])
			if b == null: L("没有【拿起护符】"); quit(1); return true
			_click(b); _wait = 30; _st = 14
		14:
			var ov = _game.overlay()
			if ov == null: ov = _game.base()
			if _flow.screen == GameFlow.Screen.EVENT:
				_tk += 1
				if _tk > 4: L("点【继续】四回还在事件屏"); quit(1); return true
				var bag_open: bool = ov.get("_bag") != null
				L("拿起后的结果页（第 %d 回）：字 %s；背包浮窗 %s；护符 %s" % [_tk, _labels_under(ov).left(300), "开着" if bag_open else "关着", _charm_where()])
				shot("altar_after_take_%d" % _tk)
				if bag_open:
					var mb: Control = null
					for n in root.find_children("*", "BaseButton", true, false):
						if (n as Control).is_visible_in_tree() and (n as Control).tooltip_text == UiText.t("bag.minimize"): mb = n
					L("　　真点背包的收起钮：%s" % ("找到" if mb != null else "没找到，改调 toggle_bag()"))
					if mb != null: _click(mb)
					else: ov.toggle_bag()
					_wait = 20; return false
				var c := _btn_has([UiText.t("menu.continue")])
				if c != null: L("　　真点【继续】"); _click(c); _wait = 25; return false
			var r := _flow.run
			var where := []
			for pair in [[r.board, "背包"], [r.storage, "地上"]]:
				for it in pair[0].items():
					if String((it as ItemInstance).def.id).begins_with("charm_"): where.append("%s（%s，%s）" % [Names.of((it as ItemInstance).def), String((it as ItemInstance).def.id), pair[1]])
			L("真点【拿起护符】后：屏 %s；护符 %s" % [GameFlow.Screen.keys()[_flow.screen], str(where)])
			shot("altar_done")
			_st = 15
		30:
			_flow.to_main_menu(); _wait = 30; _st = 31
		31:
			_flow.continue_game(); _wait = 40; _st = 32
		32:
			if _flow.screen != GameFlow.Screen.META: return false
			_st = 9
		_:
			quit(0); return true
	return false
