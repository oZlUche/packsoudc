extends SceneTree
## 游戏测试 v8.32（PR #902，报告 388 第 1 批蛮神）：参数 <outdir>
## 第 1 局（新档拒教程、无信者、自由模式第一次进图）：看先弹开局质变、选完才放地图讲解 → 撤离
## 测试辅助：万神院到来、五档 → 第 2 局奉蛮神：开局质变四选一（应只有蛮神的质变牌），选【神罚】→ 升到 30 级，逐批记下摆出的牌（按优先表挑），事后核对出牌条件 →
## 神恩栏、顶端栏小图标 → 走到相邻战斗点，战前屏看【神罚】键、真点
const TAG := "GC902"
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

var _k := 0
var _chose := false
var _seq := []
var _clicked := false
var _coach_steps := 0
var _hp0 := 0


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
	if _k == 1 and sp.faith_panel() != null and String(_flow.meta.selected_faith if "selected_faith" in _flow.meta else "") != "sun" and not _chose:
		_chose = true
		L("开局屏奉蛮神：%s" % str(sp.choose_god(&"brute"))); return
	if sp.needs_spawn(): sp.pick_spawn(sp._preview.entry_ids()[0]); return
	if not sp.next_page(): sp.depart()



func _bp() -> LevelPickPanel:
	var b = _game.base()
	return b.get("_level_pick_panel") if b != null else null


func _lv() -> LevelModule:
	return LevelModule.of(_flow.run)


func _cards_line(p: LevelPickPanel) -> String:
	var ids: Array = p.offered()
	return "%d 张 %s" % [ids.size(), str(ids)]


func _bag() -> Node:
	for n in root.find_children("*", "BagWindow", true, false):
		if (n as Control).is_visible_in_tree(): return n
	return null


func _faith_w() -> Control:
	return _game.base().hud().widgets.get(&"faith", null)


func _process(_d: float) -> bool:
	_f += 1
	if _f % 250 == 0: print("%s ♥ f %d st %d 屏 %d wait %d" % [TAG, _f, _st, _flow.screen if _flow != null else -1, _wait])
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 20000:
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
			if scr == GameFlow.Screen.EVENT: _settle(); _wait = 10; return false
			if scr != GameFlow.Screen.MAP: return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				_game.base().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			_wait = 30; _st = 30
		30:
			for c in root.find_children("*", "CoachOverlay", true, false):
				if _coach_steps == 0: shot("k%d_coach" % (_k + 1))
				L("　　选牌前的教练层第 %d 步：%s（选牌窗 %s）" % [_coach_steps + 1, _labels_under(c).left(80), "开着" if _bp() != null else "没开"])
				_coach_steps += 1; (c as CoachOverlay).next(); _wait = 10; return false
			var p := _bp()
			L("　　章节 %s" % String(_flow.run.chapter.id))
			var lv := _lv()
			L("第 %d 局进地图：奉「%s」，%d 级，欠选牌 %d，选牌窗 %s，教练层走了 %d 步" % [_k + 1, String(_flow.run.active_faith_id()), lv.level(), lv.pending(), "开着" if p != null else "没开", _coach_steps])
			if p == null: _st = 33; return false
			L("　　现在这张 %s；窗里的字：%s" % [str(lv.current_pick()), _labels_under(p).left(400)])
			L("　　摆出 %s；换牌 %d、剔牌 %d；排版：%s" % [_cards_line(p), lv.rerolls_left(), lv.removals_left(), _overflow(p.get_parent())])
			shot("k%d_opening" % (_k + 1))
			var first: Array = p.offered()
			var at := maxi(0, first.find(&"god_brute_smite"))
			_click(p._cards.get_child(at) as Control); _wait = 40; _st = 40
		40:
			var cs: Array = root.find_children("*", "CoachOverlay", true, false)
			if not cs.is_empty():
				if _coach_steps < 100: shot("k%d_coach_after_pick" % (_k + 1)); _coach_steps = 100
				L("　　选完以后的教练层：%s（选牌窗 %s）" % [_labels_under(cs[0]).left(80), "开着" if _bp() != null else "没开"])
				(cs[0] as CoachOverlay).next(); _wait = 10; return false
			L("　　选完以后教练层都走完了")
			_st = 31
		31:
			var lv := _lv()
			L("真点第一张后：欠选牌 %d，质变 %s，拿过 %s，选牌窗 %s" % [lv.pending(), str(lv.quals()), str(lv.taken), "开着" if _bp() != null else "收了"])
			var got := lv.gain(1000000.0, LevelModule.SRC_EVENT)
			L("测试辅助加经验值 %.0f：%d 级，欠选牌 %d" % [got, lv.level(), lv.pending()])
			L("　　体力 %d / %d（下面遇到【耐行】就选它）" % [_flow.run.vitality.current, _flow.run.vitality.maximum])
			_seq = []; _wait = 20; _st = 32
		32:
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next(); _wait = 10; return false
			var lv := _lv()
			if lv.pending() <= 0:
				L("选完：%s" % " ".join(_seq))
				L("　　质变 %s；拿过 %d 种；【耐行】%d 张，体力 %d / %d" % [str(lv.quals()), lv.taken.size(), lv.count_of(&"card_vitality"), _flow.run.vitality.current, _flow.run.vitality.maximum])
				_st = 33; return false
			var p := _bp()
			if p == null:
				_game.base().show_level_pick(); _wait = 10; return false
			var cur := lv.current_pick()
			var ids: Array = p.offered()
			var n: int = ids.size()
			_seq.append("%d%s×%d" % [int(cur.get("level", 0)), ("Q" + ("通" if bool(cur.get("generic", false)) else "")) if bool(cur.get("qual", false)) else "", n])
			L("BATCH lv=%d qual=%s taken_before=%s offered=%s" % [int(cur.get("level", 0)), str(bool(cur.get("qual", false))), JSON.stringify(lv.taken.keys()), JSON.stringify(ids)])
			if bool(cur.get("qual", false)) and int(cur.get("level", 0)) == 6:
				L("6 级质变位：窗里的字 %s；排版 %s" % [_labels_under(p).left(300), _overflow(p.get_parent())])
				shot("k%d_qual6" % (_k + 1))
			var pick := 0
			var best := 99
			var pri := ["god_brute_deathfight", "god_brute_cornered", "god_brute_smite_up", "god_brute_undying", "god_brute_cornered_more", "god_brute_smite_more", "god_brute_deathfight_up", "god_brute_cap", "god_brute_damage"]
			for i in ids.size():
				var r := pri.find(String(ids[i]))
				if r < 0 and String(ids[i]).begins_with("god_brute"): r = 50
				if r >= 0 and r < best: best = r; pick = i
			L("PICK %s" % String(ids[pick]))
			p.choose(pick); _wait = 4
		33:
			_hover_at(Vector2(900, 700))
			var fw := _faith_w()
			L("顶端栏信仰徽记：%s；质变小图标 %s，多出来的「%s」" % [("在" if fw != null and fw.visible else "不在"), str(fw.call("favor_ids")) if fw != null else "-", fw.call("favor_more_text") if fw != null else "-"])
			shot("k%d_topbar" % (_k + 1))
			_game.base().toggle_bag(); _wait = 40; _st = 34
		34:
			var bw = _bag()
			if bw == null: L("（背包没开）"); _st = 35; return false
			var fv: FavorPanel = bw.favor
			L("背包（状态界面）：神恩栏 %s；栏里 %s；窗宽 %.0f；排版 %s" % [str(fv.visible), str(fv.slot_ids()), bw.window_size().x, _overflow(bw)])
			if fv.visible:
				for i in fv.slot_ids().size(): L("　　第 %d 格悬浮：%s" % [i + 1, fv.tip_text(i).replace("\n", " / ").left(160)])
			shot("k%d_status" % (_k + 1))
			_game.base().toggle_bag(); _wait = 20; _st = 35
		35:
			if _k == 1: _st = 50; return false
			_flow.run.force_extract(); _flow.resume(); _wait = 40; _st = 36
		36:
			if scr == GameFlow.Screen.RESULT:
				_game.base().proceed(); _wait = 60; _st = 37; return false
			if scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.MAP: _settle(); _wait = 10
		37:
			if scr != GameFlow.Screen.META: return false
			var arr: Control = _ms().arrival()
			if arr != null:
				for b in arr.find_children("*", "Button", true, false):
					if (b as Button).is_visible_in_tree(): _click(b); break
				_wait = 30; return false
			var bk := _flow.meta.commissions
			bk.arrived[String(Pantheon.FACTION)] = 0
			bk.rep[String(Pantheon.FACTION)] = 100
			bk.signed[String(Pantheon.FACTION)] = 1     # 五档要签过约
			_flow.sync_commissions(); _flow.save_meta(); _flow.meta.changed.emit()
			L("测试辅助：万神院到来、声望 %d；开局多一张 %s" % [Pantheon.rep(_flow.meta), str(Pantheon.access(_flow.meta).get("opening_extra", false))])
			_k = 1; _coach_steps = 0; _wait = 20; _st = 3
		50:
			var moves: Array = _flow.run.travel.available_moves()
			var pick := -1
			for mv in moves:
				if NodeEvents.effective_type(_flow.run.map.get_node(int(mv))) == &"battle": pick = int(mv); break
			if pick < 0: L("相邻没有普通战斗点：%s" % str(moves.map(func(m): return String(NodeEvents.effective_type(_flow.run.map.get_node(int(m))))))); _st = 99; return false
			L("走到相邻的普通战斗点 %d" % pick)
			_flow.step_to(pick); _wait = 60; _st = 51
		51:
			if scr != GameFlow.Screen.PREBATTLE:
				if scr == GameFlow.Screen.EVENT: _settle(); _wait = 10; return false
				L("（没进战前屏，屏 %d）" % scr); _st = 99; return false
			var sb: Button = null
			var keys := []
			for n in root.find_children("*", "Button", true, false):
				var bb := n as Button
				if not bb.is_visible_in_tree(): continue
				keys.append("[%s%s]" % [bb.text, "（灰）" if bb.disabled else ""])
				if bb.has_meta("perk_option"): sb = bb
			L("战前屏的键：%s" % " ".join(keys))
			if sb != null: L("　　神罚键「%s」悬浮：%s" % [sb.text, sb.tooltip_text.replace("\n", " / ").left(200)])
			shot("prebattle")
			if sb == null or sb.disabled: _st = 99; return false
			_hp0 = _flow.run.vitality.current
			_click(sb); _wait = 120; _st = 52
		52:
			L("点了神罚：屏 %d，体力 %d → %d" % [scr, _hp0, _flow.run.vitality.current])
			shot("after_smite")
			_st = 99
		99:
			L("完 err=0"); quit(0); return true
	return false
