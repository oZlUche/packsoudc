extends SceneTree
## 游戏测试 v8.74（PR #945，报告 396 第三节）：万神院神殿自选解锁。参数 <outdir>
## 新档拒教程 → 真走三局（每局走一步、测试辅助撤离）→ 万神院到来 → 后勤红点 → 万神院页：剪影、逐座悬停、点没落成的、点蛮神【确认解锁】→ 红点、解锁次数 →
## 测试辅助声望补到 150 → 解锁次数、再真点解锁日神、自然 → 出征选神界面（只有解锁的能奉）→ 奉蛮神开局 → 测试辅助加经验 → 选牌窗【重选】【跳过】真点 → 存档退出读回
const TAG := "PA945"
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
var _hi := 0
const GODS := ["brute", "sun", "nature", "skill", "hunt", "earth"]


func _sub(key: String) -> void:
	_click(_ms()._sub_btns[key])


func _dot(b: Control) -> String:
	if b == null: return "-"
	var d := b.get_node_or_null("RedDot") as RedDot
	return "无" if d == null or not d.visible else str(d.count)


func _pline() -> String:
	var m := _flow.meta
	return "到了 %s、声望 %d、挣到 %d 次、解锁了 %s、还剩 %d 次、能奉 %s；红点 后勤 %s 万神院 %s" % [str(Pantheon.arrived(m)), m.commissions.rep_of(Pantheon.FACTION), Pantheon.chances_earned(m), str(m.temples), Pantheon.chances(m),
		str(GODS.filter(func(x): return Pantheon.god_open(m, StringName(x)))), _dot(_ms()._tab_btns.get("logistics", null)), _dot(_ms()._sub_btns.get("pantheon", null))]


func _page() -> Control:
	return _ms().pantheon_panel()


func _temples_line() -> String:
	var o := []
	for g in GODS:
		var t := _named("Temple_" + g) as Button
		if t == null: o.append("%s 不在" % g); continue
		var img := t.find_child("Image", true, false) as TextureRect
		var nm := t.find_child("Name", true, false) as Label
		o.append("%s「%s」%s" % [g, nm.text if nm != null else "?", "剪影" if img != null and img.modulate.r < 0.5 else "亮"])
	var u := _named("Unlock") as Button
	var ch := _named("Chances") as Label
	return "%s；底栏「%s」【%s】%s" % [" ".join(o), ch.text if ch != null else "-", u.text if u != null else "-", "灰" if u == null or u.disabled else "亮"]


func _tip_visible() -> String:
	var o := []
	for w in root.find_children("*", "Window", true, false):
		if (w as Window).visible and w != root:
			o.append(_labels_under(w).left(200))
	for n in root.find_children("*", "PanelContainer", true, false):
		if String(n.name).to_lower().contains("tip") and (n as Control).is_visible_in_tree(): o.append(_labels_under(n).left(200))
	return str(o)


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


func _setup_go() -> bool:
	if _flow.screen != GameFlow.Screen.SETUP: return false
	var sp: Node = null
	for n in root.find_children("*", "", true, false):
		if n.has_method("step_difficulty") and n.has_method("depart"): sp = n
	if sp == null: return false
	if sp.needs_spawn(): sp.pick_spawn(sp._preview.entry_ids()[0]); return false
	if not sp.next_page(): sp.depart()
	return false


func _bp() -> LevelPickPanel:
	var b = _game.base()
	return b.get("_level_pick_panel") if b != null else null


func _keys_line(p: LevelPickPanel) -> String:
	var o := []
	for nm in ["Reroll", "Remove", "Skip"]:
		var b := p.find_child(nm, true, false) as Button
		o.append("%s「%s」%s%s" % [nm, b.text if b != null else "-", "" if b != null and b.visible else "（不显示）", "（灰）" if b != null and b.disabled else ""])
	return " ".join(o)


func _process(_d: float) -> bool:
	_f += 1
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
			L("新档进营地：%s" % _pline())
			_tab("expedition"); _wait = 30; _st = 4
		4:
			if scr == GameFlow.Screen.META:
				_start_click(); _wait = 40; _st = 5
		5:
			if scr == GameFlow.Screen.META:
				if _ms().god_pick() != null: L("（第 %d 局）出了选神界面" % (_k + 1)); _st = 99; return false
				_start_click(); _wait = 40; return false
			if scr == GameFlow.Screen.SETUP: _setup_go(); _wait = 20; return false
			if not _settle(): _wait = 10; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN: _game.base().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			var moves: Array = _flow.run.travel.available_moves()
			var pick := int(moves[0])
			for mv in moves:
				if not (NodeEvents.effective_type(_flow.run.map.get_node(int(mv))) in [&"battle", &"elite", &"core"]): pick = int(mv); break
			_flow.step_to(pick); _wait = 60; _st = 6
		6:
			if (scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.MAP) and not _settle(): _wait = 10; return false
			_flow.run.force_extract(); _flow.resume(); _wait = 40; _st = 7
		7:
			if scr == GameFlow.Screen.RESULT:
				_k += 1
				L("第 %d 局：走一步后测试辅助撤离；成功撤离 %d 局" % [_k, _flow.meta.commissions.formal_extractions])
				_game.base().proceed(); _wait = 60; _st = 8
				return false
			if scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.MAP: _settle(); _wait = 10
		8:
			if scr != GameFlow.Screen.META: return false
			if _k < 3: _tab("expedition"); _wait = 30; _st = 4; return false
			_wait = 60; _st = 9
		9:
			var arr: Control = _ms().arrival()
			L("第 3 局后回营地：到来通知 %s；%s" % [("「%s」" % _labels_under(arr).left(200)) if arr != null else "没有", _pline()])
			shot("arrival")
			if arr == null: _st = 11; return false
			var ok: Button = null
			for b in arr.find_children("*", "Button", true, false):
				if (b as Button).is_visible_in_tree(): ok = b
			_click(ok); _wait = 30; _st = 10
		10:
			L("点了【%s】：%s" % ["知道了", _pline()])
			shot("camp_dot")
			_tab("logistics"); _wait = 25; _st = 11
		11:
			if not _ms()._sub_btns.has("pantheon"): L("后勤没有万神院小键：%s" % str(_ms()._sub_btns.keys())); _st = 99; return false
			L("后勤页：%s" % _pline())
			_sub("pantheon"); _wait = 30; _st = 12
		12:
			var p := _page()
			L("万神院页：%s" % _labels_under(p).left(500))
			L("　　神殿：%s" % _temples_line())
			L("　　排版：%s" % _overflow(p))
			shot("pantheon_page")
			_hi = 0; _st = 13
		13:
			if _hi >= GODS.size(): _hover_at(Vector2(5, 5)); _wait = 20; _st = 14; return false
			var t := _named("Temple_" + GODS[_hi]) as Button
			_hover_at(t.get_global_rect().get_center()); _wait = 70; _st = 131
		131:
			var t := _named("Temple_" + GODS[_hi]) as Button
			L("　　悬停 %s：tooltip_text「%s」；屏上的悬浮 %s" % [GODS[_hi], t.tooltip_text.replace("\n", " / "), _tip_visible()])
			if _hi in [0, 4]: shot("hover_" + GODS[_hi])
			_hi += 1; _st = 13
		14:
			_click(_named("Temple_hunt")); _wait = 20; _st = 15
		15:
			L("点狩猎（没落成）：%s" % _temples_line())
			shot("pick_hunt")
			_click(_named("Unlock")); _wait = 20; _st = 16
		16:
			L("　　灰着的【确认解锁】也点一下：%s" % _pline())
			_click(_named("Temple_brute")); _wait = 20; _st = 17
		17:
			L("点蛮神：%s" % _temples_line())
			shot("pick_brute")
			_click(_named("Unlock")); _wait = 30; _st = 18
		18:
			L("真点【确认解锁】：%s" % _pline())
			L("　　神殿：%s；排版 %s" % [_temples_line(), _overflow(_page())])
			shot("after_unlock")
			_assist_done([], Pantheon.FACTION, 150)
			_ms()._refresh(); _wait = 30; _st = 19
		19:
			L("测试辅助：声望补到 150：%s" % _pline())
			L("　　神殿：%s" % _temples_line())
			_click(_named("Temple_sun")); _wait = 20; _st = 20
		20:
			_click(_named("Unlock")); _wait = 30; _st = 21
		21:
			L("真点日神【确认解锁】：%s" % _pline())
			_click(_named("Temple_nature")); _wait = 20; _st = 22
		22:
			_click(_named("Unlock")); _wait = 30; _st = 23
		23:
			L("真点自然【确认解锁】：%s" % _pline())
			L("　　神殿：%s；排版 %s" % [_temples_line(), _overflow(_page())])
			shot("after_three")
			_click(_named("Temple_skill")); _wait = 20; _st = 24
		24:
			L("点技巧（没落成）：%s" % _temples_line())
			_tab("expedition"); _wait = 30; _st = 25
		25:
			if scr == GameFlow.Screen.META: _start_click(); _wait = 40
			_st = 26
		26:
			if scr != GameFlow.Screen.SETUP: _wait = 20; return false
			var sp: Node = null
			for n in root.find_children("*", "", true, false):
				if n.has_method("step_difficulty") and n.has_method("depart"): sp = n
			if sp.god_book() != null: L("出征屏先翻开了百科页"); sp.close_god_book(); _wait = 20; return false
			var gc = sp.god_coach()
			if gc != null: gc.next(); _wait = 15; return false
			var fp = sp.faith_panel()
			if fp == null or not (fp as Control).is_visible_in_tree():
				set_meta("fw", int(get_meta("fw", 0)) + 1)
				if int(get_meta("fw", 0)) > 3: L("出征屏信仰条没展开，直接 choose_god"); L("　　choose_god(brute) = %s" % str(sp.choose_god(&"brute"))); _st = 27; return false
				for b in sp.find_children("*", "Button", true, false):
					if String(b.name).to_lower().contains("faith") and (b as Button).is_visible_in_tree(): _click(b); break
				_wait = 25; return false
			var keys := []
			for b in (fp as Node).find_children("Choose_*", "Button", true, false):
				keys.append("%s「%s」%s" % [String(b.name).trim_prefix("Choose_"), (b as Button).text, "（灰）" if (b as Button).disabled else ""])
			var tips := []
			for g in GODS:
				var sh := (fp as Node).find_child("Shrine_" + g, true, false) as Control
				if sh != null: tips.append("%s「%s」" % [g, sh.tooltip_text.left(40)])
			L("出征屏信仰条：键 %s；悬浮 %s；排版 %s" % [str(keys), str(tips), _overflow(fp)])
			shot("god_pick")
			_click(_named("Choose_brute")); _wait = 40; _st = 27
		27:
			if scr == GameFlow.Screen.META: _wait = 20; return false
			if scr == GameFlow.Screen.SETUP:
				if not get_meta("faithlog", false):
					set_meta("faithlog", true)
					for n in root.find_children("*", "", true, false):
						if n.has_method("chosen_faith"): L("出征屏：这一局奉「%s」；信仰条写「%s」" % [String(n.chosen_faith()), n.faith_head_text()])
				_setup_go(); _wait = 20; return false
			if not _settle(): _wait = 10; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN: _game.base().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			var r := _flow.run
			L("奉「%s」开局：万神院给的重选 %d、跳过 %d；科技给的重选 %d" % [String(r.selected_faith), r.faith_rerolls, r.faith_skips, r.buff_context().level_rerolls])
			var lv := LevelModule.of(r)
			lv.gain(float(lv.rules().total_for(5)), LevelModule.SRC_EVENT, "test")
			L("测试辅助加经验：Lv.%d 欠选 %d" % [lv.level(), lv.pending()])
			_wait = 40; _st = 28
		28:
			for c in root.find_children("*", "CoachOverlay", true, false): (c as CoachOverlay).next(); _wait = 15; return false
			var p := _bp()
			if p == null or not p.is_visible_in_tree(): _wait = 20; set_meta("w", int(get_meta("w", 0)) + 1); if int(get_meta("w", 0)) > 30: L("选牌窗没开"); _st = 40
			if p == null or not p.is_visible_in_tree(): return false
			var lv := LevelModule.of(_flow.run)
			L("选牌窗：%s；键 %s；排版 %s" % [_cards_line(p), _keys_line(p), _overflow(p)])
			shot("pick_keys")
			if lv.current_pick().get("qual", false) or lv.seed_offer():
				L("　　这一批是质变 / 初种，先挑第一张"); _click(p._cards.get_child(0) as Control); _wait = 30; return false
			set_meta("before", str(p.offered()))
			_click(p.find_child("Skip", true, false) as Control); _wait = 30; _st = 29
		29:
			var p := _bp(); var lv := LevelModule.of(_flow.run)
			if p == null: L("跳过以后选牌窗收了：欠选 %d" % lv.pending()); _st = 40; return false
			L("真点【跳过】：跳过前 %s → 现在 %s；跳过用了 %d、还剩 %d；欠选 %d；提示「%s」；键 %s" % [get_meta("before"), _cards_line(p), lv.skips_used, lv.skips_left(), lv.pending(), p._note.text, _keys_line(p)])
			shot("after_skip")
			set_meta("before", str(p.offered()))
			_click(p.find_child("Reroll", true, false) as Control); _wait = 30; _st = 30
		30:
			var p := _bp(); var lv := LevelModule.of(_flow.run)
			L("真点【重选】：%s → %s；重选还剩 %d；键 %s" % [get_meta("before"), _cards_line(p), lv.rerolls_left(), _keys_line(p)])
			_click(p._cards.get_child(0) as Control); _wait = 30; _st = 31
		31:
			var p := _bp(); var lv := LevelModule.of(_flow.run)
			L("挑了第一张：拿过 %s；下一批 %s；欠选 %d；跳过加成 %d" % [str(lv.taken.keys()), _cards_line(p) if p != null and p.is_visible_in_tree() else "（窗收了）", lv.pending(), 0])     # v8.93：跳过不再多一张，skip_bonus 已删
			_flow.save_and_quit(); _wait = 60; _st = 32
		32:
			_flow.continue_game(); _wait = 80; _st = 33
		33:
			var lv := LevelModule.of(_flow.run)
			L("存档退出再继续：跳过用了 %d、还剩 %d；重选还剩 %d；解锁的神殿 %s" % [lv.skips_used, lv.skips_left(), lv.rerolls_left(), str(_flow.meta.temples)])
			_st = 40
		40:
			L("完 err=0"); quit(0); return true
		99:
			L("完 err=1"); quit(1); return true
	return false


func _cards_line(p: LevelPickPanel) -> String:
	var ids: Array = p.offered()
	return "%d 张 %s" % [ids.size(), str(ids)]
