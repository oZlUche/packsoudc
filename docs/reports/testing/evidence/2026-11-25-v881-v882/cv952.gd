extends SceneTree
## 游戏测试 v8.81（PR #952，报告 396 第五节 / 391 第五节）：万神院节点第二版。参数 <outdir>
## 新档拒教程 → 测试辅助：万神院到了、解锁蛮神 / 日神 / 自然、声望 150 → 声望页节点文字 → 委托簿剧情页接 100 / 125 / 150 三份新委托（真点）→
## 出征奉蛮神 → 测试辅助加经验、挑完蛮神牌 → 开神坛：【改信】一行、下拉、悬浮窗 → 献祭一件（100 的委托记一处）→ 真点【改信】改奉日神 →
## 信物、神徽、牌、等级 → 改过以后灰着 → 重选的牌只出日神的 → 存档退出读回 → 测试辅助撤离 → 三份委托的进度
const TAG := "CV952"
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
const NEW := ["pantheon_temple_100", "pantheon_temple_125", "pantheon_temple_150"]
var _ti := 0
var _lv0 := 0


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


func _sp() -> Node:
	var sp: Node = null
	for n in root.find_children("*", "", true, false):
		if n.has_method("step_difficulty") and n.has_method("depart"): sp = n
	return sp


func _bp() -> LevelPickPanel:
	var b = _game.base()
	return b.get("_level_pick_panel") if b != null else null


func _alt() -> Node:
	for n in [_game.overlay(), _game.base()]:
		if n != null and n.has_method("convert_to"): return n
	return null


func _lv() -> LevelModule:
	return LevelModule.of(_flow.run)


func _god_cards() -> String:
	var o := []
	for k in _lv().taken.keys():
		if String(k).begins_with("god_"): o.append("%s×%d" % [String(k), int(_lv().taken[k])])
	return "神牌 %d 种 %s" % [o.size(), str(o)]


func _charms() -> String:
	var o := []
	for i in _flow.run.board.items():
		var it := i as ItemInstance
		if Pantheon.is_charm(it.def): o.append("%s@%s" % [String(it.def.id), str(it.origin)])
	return str(o)


func _conv_line() -> String:
	var a := _alt()
	if a == null: return "（神坛屏不在）"
	var b := a.find_child("Convert", true, false) as Button
	var p := a.find_child("ConvertPick", true, false) as OptionButton
	var items := []
	if p != null:
		for i in p.item_count: items.append(p.get_item_text(i))
	return "【%s】%s，悬浮「%s」；下拉 %s%s" % [b.text if b != null else "-", "（不在）" if b == null else ("灰" if b.disabled else "亮"), b.tooltip_text.left(80) if b != null else "-",
		str(items) if p != null else "（无）", "（灰）" if p != null and p.disabled else ""]


func _comm_line() -> String:
	var bk := _flow.meta.commissions
	var o := []
	for id in NEW:
		var d := Commissions.def(StringName(id))
		var e := bk.entry(StringName(id))
		o.append("%s《%s》%s 能交 %s" % [id.trim_prefix("pantheon_temple_"), Names.of(d), str(e).left(120), str(Commissions.can_report(bk, d, _flow.meta))])
	return "；".join(o)


func _pick_all() -> bool:
	for c in root.find_children("*", "CoachOverlay", true, false): (c as CoachOverlay).next(); _wait = 15; return false
	var p := _bp()
	if p != null and p.is_visible_in_tree():
		var ids: Array = p.offered()
		var at := 0
		for i in ids.size():
			if String(ids[i]).begins_with("god_"): at = i; break
		set_meta("picked", (get_meta("picked", []) as Array) + [String(ids[at])])
		_click(p._cards.get_child(at) as Control); _wait = 25; return false
	return _lv().pending() <= 0


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 30000:
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
			var m := _flow.meta
			m.commissions.arrived[String(Pantheon.FACTION)] = 1
			for g in [&"brute", &"sun", &"nature"]:
				if not m.temples.has(g): m.temples.append(g)
			var f := Pantheon.faction()
			for r in [49, 50]:
				m.commissions.rep[String(Pantheon.FACTION)] = r
				var a := Pantheon.access(m)
				L("声望 %d：改信 %s、能改成 %s、经验加成 %s；挣到解锁机会 %d" % [r, str(a["convert"]), str(a["temples"]), str(a["xp_bonus"]), Pantheon.chances_earned(m)])
			_assist_done([], Pantheon.FACTION, 150)
			L("测试辅助：万神院到了、解锁 %s、声望 %d；挣到解锁机会 %d、剩 %d" % [str(m.temples), m.commissions.rep_of(Pantheon.FACTION), Pantheon.chances_earned(m), Pantheon.chances(m)])
			for n in Commissions.nodes_of(f):
				if int(n["rep"]) in [50, 100, 125, 150]: L("　　节点 %d：%s" % [int(n["rep"]), Commissions.node_text(n, _flow.faith_defs, m.commissions, f)])
			_tab("commissions"); _wait = 40; _st = 4
		4:
			var cp = _ms().commission_panel()
			if cp == null: _wait = 20; return false
			if cp.sub() != "reputation": cp.show_sub("reputation"); _wait = 25; return false
			L("声望页：排版 %s" % _overflow(cp))
			shot("rep_page")
			cp.show_sub("story"); _wait = 25; _st = 5
		5:
			var cp = _ms().commission_panel()
			var keys := []
			for b in cp.find_children("Take_*", "", true, false):
				if String(b.name).contains("pantheon"): keys.append("%s「%s」%s" % [String(b.name).trim_prefix("Take_"), (b as Button).text, "（灰）" if (b as Button).disabled else ""])
			L("剧情页万神院的键：%s；排版 %s" % [str(keys), _overflow(cp)])
			if _ti == 0: shot("story_page")
			if _ti >= NEW.size():
				L("接完：%s" % _comm_line()); L("　　已接 %s" % str(_flow.meta.commissions.taken())); shot("story_taken")
				_tab("expedition"); _wait = 30; _st = 6; return false
			var id: String = NEW[_ti]
			var tb := cp.find_child("Take_" + id, true, false) as Button
			if tb == null or not tb.is_visible_in_tree():
				L("《%s》的【接】不在页上（why_not「%s」）" % [id, Commissions.why_not(_flow.meta.commissions, Commissions.def(StringName(id)))])
				if tb != null: cp.find_children("*", "ScrollContainer", true, false).map(func(s): (s as ScrollContainer).ensure_control_visible(tb))
				if tb == null or int(get_meta("tw%d" % _ti, 0)) > 2: _ti += 1; return false
				set_meta("tw%d" % _ti, int(get_meta("tw%d" % _ti, 0)) + 1); _wait = 10; return false
			L("真点《%s》的【%s】（%s）" % [Names.of(Commissions.def(StringName(id))), tb.text, "灰" if tb.disabled else "亮"])
			if tb.disabled: L("　　why_not「%s」" % Commissions.why_not(_flow.meta.commissions, Commissions.def(StringName(id))))
			_click(tb); _ti += 1; _wait = 30
		6:
			if scr == GameFlow.Screen.META: _start_click(); _wait = 40; return false
			if scr != GameFlow.Screen.SETUP: _wait = 20; return false
			var sp := _sp()
			if sp.god_book() != null: sp.close_god_book(); _wait = 20; return false
			var gc = sp.god_coach()
			if gc != null: gc.next(); _wait = 15; return false
			L("出征屏奉蛮神：%s" % str(sp.choose_god(&"brute"))); _wait = 20; _st = 7
		7:
			if scr == GameFlow.Screen.SETUP:
				var sp := _sp()
				if sp.needs_spawn(): sp.pick_spawn(sp._preview.entry_ids()[0]); _wait = 20; return false
				if not sp.next_page(): sp.depart()
				_wait = 20; return false
			if not _settle(): _wait = 10; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN: _game.base().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			var r := _flow.run
			L("开局：奉「%s」；改信 %s、能改成 %s、改过 %s；经验加成 %s；信物 %s" % [String(r.selected_faith), str(r.faith_convert), str(r.faith_temples), str(r.faith_converted), str(r.faith_xp_bonus), _charms()])
			_lv().gain(float(_lv().rules().total_for(6)), LevelModule.SRC_EVENT, "test")
			L("测试辅助加经验：Lv.%d 欠选 %d" % [_lv().level(), _lv().pending()])
			_wait = 40; _st = 8
		8:
			if not _pick_all(): return false
			_lv0 = _lv().level()
			L("挑完（尽量挑神牌）：Lv.%d、经验 %s；%s；通用牌 %d 种" % [_lv().level(), str(snappedf(_lv().xp, 0.1)), _god_cards(), _lv().taken.keys().filter(func(k): return not String(k).begins_with("god_")).size()])
			_flow.run.events.altar_opened.emit(_flow.run.current_node()); L("　　神坛开着 %s；屏 %d" % [str(AltarModule.of(_flow.run).is_open()), _flow.screen]); _wait = 20; _st = 9
		9:
			for c in root.find_children("*", "CoachOverlay", true, false): (c as CoachOverlay).next(); _wait = 15; return false
			var a := _alt()
			if a == null: set_meta("aw", int(get_meta("aw", 0)) + 1); _wait = 20; _flow.resume(); if int(get_meta("aw", 0)) > 20: L("神坛屏没开（屏 %d）" % scr); _st = 40
			if a == null: return false
			L("神坛屏：%s；改信一行 %s；排版 %s" % [a.head_text(), _conv_line(), _overflow(a)])
			var cb := a.find_child("Convert", true, false) as Control
			if cb != null: _hover_at(cb.get_global_rect().get_center())
			_wait = 50; _st = 10
		10:
			shot("altar_convert_row")
			var a := _alt()
			var p := a.find_child("ConvertPick", true, false) as OptionButton
			if p != null: _click(p); _wait = 20
			_st = 11
		11:
			shot("altar_pick_open")
			var a := _alt()
			var p := a.find_child("ConvertPick", true, false) as OptionButton
			if p != null:
				var pp := p.get_popup()
				if pp.visible: pp.hide()
				var opts: Array = p.get_meta("options")
				p.select(opts.find(&"sun"))
				L("下拉选「%s」" % p.get_item_text(p.selected))
			# 先献祭一件（100 的委托：一座神坛记一处）
			var cand: ItemInstance = null
			for i in _flow.run.board.items():
				var it := i as ItemInstance
				if not Pantheon.is_charm(it.def): cand = it
			if cand != null:
				L("台上放 %s：%s" % [String(cand.def.id), str(a.put_on_table(cand.uid))])
				var res: Dictionary = a.offer()
				L("献祭：%s；带着的委托 %s" % [str(res).left(160), _comm_line()])
			_wait = 30; _st = 12
		12:
			var a := _alt()
			L("献祭以后：%s" % _conv_line())
			set_meta("used0", str(AltarModule.of(_flow.run).used))
			_click(a.find_child("Convert", true, false) as Control); _wait = 40; _st = 13
		13:
			var a := _alt()
			var r := _flow.run
			L("真点【改信】：奉「%s」（有效 %s）、改过 %s；信物 %s；Lv.%d（改前 %d）、欠选 %d；%s；神坛机会 %s → %s" % [String(r.selected_faith), String(r.active_faith_id()), str(r.faith_converted), _charms(), _lv().level(), _lv0, _lv().pending(), _god_cards(), get_meta("used0"), str(AltarModule.of(r).used)])
			if a != null:
				var fr = a.overlay_frame() if a.has_method("overlay_frame") else null
				L("　　神坛屏：%s；神徽 %s；改信一行 %s；排版 %s" % [a.head_text(), (fr.emblem.resource_path if fr != null and fr.emblem != null else "-"), _conv_line(), _overflow(a)])
			shot("after_convert")
			_wait = 20; _st = 14
		14:
			var a := _alt()
			if a != null: a.to_map(); _wait = 40; return false
			_st = 15
		15:
			for c in root.find_children("*", "CoachOverlay", true, false): (c as CoachOverlay).next(); _wait = 15; return false
			var p := _bp()
			if p != null and p.is_visible_in_tree():
				var ids: Array = p.offered()
				var gods := ids.filter(func(x): return String(x).begins_with("god_"))
				L("重选的一批：%s（神牌 %s）；质变 %s；排版 %s" % [str(ids), str(gods), str(_lv().current_pick().get("qual", false)), _overflow(p)])
				if int(get_meta("shot15", 0)) == 0: shot("repick"); set_meta("shot15", 1)
				var at := 0
				for i in ids.size():
					if String(ids[i]).begins_with("god_"): at = i; break
				_click(p._cards.get_child(at) as Control); _wait = 25; return false
			if _lv().pending() > 0: _wait = 20; set_meta("pw", int(get_meta("pw", 0)) + 1); if int(get_meta("pw", 0)) < 15: return false
			L("重选挑完：Lv.%d；%s；欠选 %d" % [_lv().level(), _god_cards(), _lv().pending()])
			_flow.save_and_quit(); _wait = 60; _st = 16
		16:
			_flow.continue_game(); _wait = 80; _st = 17
		17:
			if not _settle(): _wait = 10; return false
			var r := _flow.run
			L("存档退出再继续：奉「%s」、改过 %s；信物 %s；Lv.%d；%s" % [String(r.selected_faith), str(r.faith_converted), _charms(), _lv().level(), _god_cards()])
			r.events.altar_opened.emit(r.current_node()); _flow.resume(); _wait = 40; _st = 18
		18:
			var a := _alt()
			L("再开神坛：%s" % _conv_line())
			if a != null: a.to_map()
			_wait = 30; _st = 19
		19:
			if not _settle(): _wait = 10; return false
			_flow.run.force_extract(); _flow.resume(); _wait = 40; _st = 20
		20:
			if scr == GameFlow.Screen.RESULT:
				L("撤离结算屏：%s" % _labels_under(_game.base()).left(300))
				_game.base().proceed(); _wait = 60; return false
			if scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.MAP: _settle(); _wait = 10; return false
			if scr != GameFlow.Screen.META: _wait = 20; return false
			L("回营地：%s" % _comm_line())
			_tab("commissions"); _wait = 40; _st = 21
		21:
			var cp = _ms().commission_panel()
			if cp == null: _wait = 20; return false
			cp.show_sub("story"); _wait = 25; _st = 22
		22:
			var cp = _ms().commission_panel()
			var o := []
			for id in NEW:
				var card: Node = cp.find_child("*" + id + "*", true, false)
				o.append(id.trim_prefix("pantheon_temple_") + "：" + _labels_under(card).left(140))
			L("剧情页三份委托：%s" % "；".join(o))
			shot("story_after_run")
			_st = 40
		40:
			L("完 err=0"); quit(0); return true
		99:
			L("完 err=1"); quit(1); return true
	return false
