extends SceneTree
## 游戏测试 v8.85（PR #956）：技巧之神神殿可以解锁；改信后选牌窗标题「改信重选：还剩 N 次」。参数 <outdir>
## 新档拒教程 → 测试辅助：万神院到了、解锁蛮神 / 日神、办完 25、50 的委托（多一次机会）、声望 150 → 后勤万神院页：真点技巧之神【确认解锁】→
## 出征屏信仰条：技巧之神【奉祂】真点 → 开局：信物、开局质变只出技巧之神的牌 → 测试辅助升 6 级、挑牌 → 用这一局的背包模拟打一场（连击）→
## 神坛真点【改信】改奉日神 → 选牌窗标题逐批记 → 存档退出读回
const TAG := "CV956"
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
const GODS := ["brute", "sun", "nature", "skill", "hunt", "earth"]
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




func _hud() -> String:
	for n in root.find_children("*", "", true, false):
		var sc = n.get_script()
		if sc != null and String(sc.resource_path).ends_with("commissions_widget.gd"):
			var c := n as Control
			var r := c.get_global_rect() if c != null else Rect2()
			return "委托栏 %s（%d×%d）「%s」" % [str(r.position), int(r.size.x), int(r.size.y), n.text_of().replace("\n", " | ")]
	return "（委托栏不在）"


func _sub(key: String) -> void:
	_click(_ms()._sub_btns[key])


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
			for g in [&"brute", &"sun"]:
				if not m.temples.has(g): m.temples.append(g)
			_assist_done(["pantheon_temple_25", "pantheon_temple_50"], Pantheon.FACTION, 150)
			L("测试辅助：万神院到了、解锁 %s、声望 %d；挣到 %d 次、剩 %d 次；技巧之神 temple_ready %s、can_unlock %s" % [str(m.temples), m.commissions.rep_of(Pantheon.FACTION), Pantheon.chances_earned(m), Pantheon.chances(m), str(Pantheon.temple_ready(&"skill")), str(Pantheon.can_unlock(m, &"skill"))])
			_tab("logistics"); _wait = 30; _st = 4
		4:
			for n in root.find_children("*", "", true, false):
				if n.has_method("acknowledge") and (n as CanvasItem).is_visible_in_tree() and String(n.name).to_lower().contains("arriv"): n.acknowledge()
			_sub("pantheon"); _wait = 30; _st = 5
		5:
			var page: Control = _ms().pantheon_panel()
			if page == null or not page.is_visible_in_tree():
				set_meta("pw", int(get_meta("pw", 0)) + 1); _wait = 20
				if int(get_meta("pw", 0)) > 6: L("万神院页没打开：%s" % _labels_under(_game.overlay() if _game.overlay() != null else _game.base()).left(200)); shot("no_page"); _st = 99
				return false
			L("万神院页：%s；排版 %s" % [_temples_line(), _overflow(page)])
			var t := _named("Temple_skill") as Control
			if t != null: _hover_at(t.get_global_rect().get_center())
			_wait = 50; _st = 6
		6:
			L("悬停技巧之神：悬浮「%s」" % (_named("Temple_skill") as Control).tooltip_text)
			shot("temples_before")
			_click(_named("Temple_skill")); _wait = 20; _st = 7
		7:
			L("点技巧之神：%s" % _temples_line())
			shot("skill_selected")
			_click(_named("Unlock")); _wait = 30; _st = 8
		8:
			var m := _flow.meta
			L("真点【确认解锁】：%s；解锁了 %s、剩 %d 次" % [_temples_line(), str(m.temples), Pantheon.chances(m)])
			shot("skill_unlocked")
			_tab("expedition"); _wait = 30; _st = 9
		9:
			if scr == GameFlow.Screen.META: _start_click(); _wait = 40; return false
			if scr != GameFlow.Screen.SETUP: _wait = 20; return false
			var sp := _sp()
			if sp.god_book() != null: sp.close_god_book(); _wait = 20; return false
			var gc = sp.god_coach()
			if gc != null: gc.next(); _wait = 15; return false
			var fp = sp.faith_panel()
			if fp == null or not (fp as Control).is_visible_in_tree():
				set_meta("fw", int(get_meta("fw", 0)) + 1)
				if int(get_meta("fw", 0)) > 3: L("信仰条没展开，直接 choose_god(skill) = %s" % str(sp.choose_god(&"skill"))); _st = 10; return false
				for b in sp.find_children("*", "Button", true, false):
					if String(b.name).to_lower().contains("faith") and (b as Button).is_visible_in_tree(): _click(b); break
				_wait = 25; return false
			var keys := []
			for b in (fp as Node).find_children("Choose_*", "Button", true, false):
				keys.append("%s「%s」%s" % [String(b.name).trim_prefix("Choose_"), (b as Button).text, "（灰）" if (b as Button).disabled else ""])
			var sh := (fp as Node).find_child("Shrine_skill", true, false) as Control
			L("出征屏信仰条：键 %s；技巧之神悬浮「%s」；排版 %s" % [str(keys), sh.tooltip_text.left(80) if sh != null else "-", _overflow(fp)])
			shot("god_pick")
			_click(_named("Choose_skill")); _wait = 40; _st = 10
		10:
			if scr == GameFlow.Screen.SETUP:
				if not get_meta("faithlog", false):
					set_meta("faithlog", true)
					var sp := _sp()
					if sp.has_method("chosen_faith"): L("出征屏：这一局奉「%s」；信仰条写「%s」" % [String(sp.chosen_faith()), sp.faith_head_text()])
					shot("setup_skill")
				var sp := _sp()
				if sp.needs_spawn(): sp.pick_spawn(sp._preview.entry_ids()[0]); _wait = 20; return false
				if not sp.next_page(): sp.depart()
				_wait = 20; return false
			if not _settle(): _wait = 10; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN: _game.base().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			var r := _flow.run
			L("开局：奉「%s」（有效 %s）；信物 %s；改信 %s、能改成 %s" % [String(r.selected_faith), String(r.active_faith_id()), _charms(), str(r.faith_convert), str(r.faith_temples)])
			_wait = 30; _st = 11
		11:
			for c in root.find_children("*", "CoachOverlay", true, false): (c as CoachOverlay).next(); _wait = 15; return false
			var p := _bp()
			if p != null and p.is_visible_in_tree():
				L("开局选牌窗：标题「%s」；%s；排版 %s" % [p._title.text if p._title.visible else "（不显示）", str(p.offered()), _overflow(p)])
				shot("opening_qual")
			_lv().gain(float(_lv().rules().total_for(6)), LevelModule.SRC_EVENT, "test")
			L("测试辅助加经验：Lv.%d 欠选 %d" % [_lv().level(), _lv().pending()])
			_wait = 30; _st = 12
		12:
			if not _pick_all(): return false
			_lv0 = _lv().level()
			L("挑完：Lv.%d；%s；挑的 %s" % [_lv().level(), _god_cards(), str(get_meta("picked", []))])
			var me := _flow.run.compile_player()
			var foe := BattleCompiler.compile(GridInventory.new(Vector2i(4, 4)), CompileInput.new())
			foe.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(99999.0)); foe.max_hp = foe.baseline.total_of(BattleStats.MAX_HP)
			var rng := RandomNumberGenerator.new(); rng.seed = 956
			var br := BattleSim.run(me, foe, rng, 20.0)
			var mx := {}; var fired := 0
			for e in br.log:
				if e.side != 0: continue
				if e.name == BattleEvent.ITEM_FIRED: fired += 1
				if e.name == BattleEvent.STATUS_STACKED:
					var b := String(e.payload.get("buff", ""))
					if b.begins_with("skill_"): mx[b] = maxi(int(mx.get(b, 0)), e.get_int(&"stacks"))
			L("地图上 %s" % _hud()); shot("map_hud")
			L("用这一局的背包模拟打 20 秒（对手不还手）：背包 %s；角色 %s；出手 %d；技巧之神状态最多 %s" % [str(_ids(_flow.run.board)), str(_flow.run.get("character_id")), fired, str(mx)])
			_flow.run.events.altar_opened.emit(_flow.run.current_node()); _flow.resume(); _wait = 30; _st = 13
		13:
			for c in root.find_children("*", "CoachOverlay", true, false): (c as CoachOverlay).next(); _wait = 15; return false
			var a := _alt()
			if a == null: set_meta("aw", int(get_meta("aw", 0)) + 1); _wait = 20; _flow.resume(); if int(get_meta("aw", 0)) > 20: L("神坛屏没开（屏 %d）" % scr); _st = 40
			if a == null: return false
			L("神坛屏：%s；改信一行 %s；排版 %s" % [a.head_text(), _conv_line(), _overflow(a)])
			var pan := a.find_children("*", "PanelContainer", true, false)
			L("　　开着神坛时 %s；神坛窗最左 x=%d" % [_hud(), int((pan[0] as Control).get_global_rect().position.x) if not pan.is_empty() else -1])
			shot("altar_hud")
			var p := a.find_child("ConvertPick", true, false) as OptionButton
			if p != null:
				var opts: Array = p.get_meta("options")
				p.select(opts.find(&"sun"))
			_click(a.find_child("Convert", true, false) as Control); _wait = 40; _st = 14
		14:
			var r := _flow.run
			L("真点【改信】：奉「%s」；信物 %s；Lv.%d（改前 %d）；欠选 %d、改信重选剩 %d；%s" % [String(r.selected_faith), _charms(), _lv().level(), _lv0, _lv().pending(), _lv().repicks_left(), _god_cards()])
			var a := _alt()
			if a != null: a.to_map()
			_wait = 40; _st = 15
		15:
			for c in root.find_children("*", "CoachOverlay", true, false): (c as CoachOverlay).next(); _wait = 15; return false
			var p := _bp()
			if p != null and p.is_visible_in_tree():
				var ids: Array = p.offered()
				var n := int(get_meta("batch", 0)) + 1; set_meta("batch", n)
				L("第 %d 批：标题「%s」（显示 %s）；repicks_left %d、欠选 %d；%s；质变 %s；排版 %s" % [n, p._title.text, str(p._title.visible), _lv().repicks_left(), _lv().pending(), str(ids), str(_lv().current_pick().get("qual", false)), _overflow(p)])
				if n == 1 or n == 3 or _lv().pending() == 1: shot("repick_%d" % n)
				var at := 0
				for i in ids.size():
					if String(ids[i]).begins_with("god_"): at = i; break
				_click(p._cards.get_child(at) as Control); _wait = 25; return false
			if _lv().pending() > 0: _wait = 20; set_meta("pw2", int(get_meta("pw2", 0)) + 1); if int(get_meta("pw2", 0)) < 15: return false
			L("重选挑完：Lv.%d；%s；欠选 %d、改信重选剩 %d" % [_lv().level(), _god_cards(), _lv().pending(), _lv().repicks_left()])
			_lv().gain(float(_lv().rules().total_for(7) - _lv().xp) + 1.0, LevelModule.SRC_EVENT, "test")
			_wait = 30; _st = 16
		16:
			for c in root.find_children("*", "CoachOverlay", true, false): (c as CoachOverlay).next(); _wait = 15; return false
			var p := _bp()
			if p != null and p.is_visible_in_tree():
				L("改信以后再升一级（Lv.%d）：标题「%s」（显示 %s）；%s" % [_lv().level(), p._title.text, str(p._title.visible), str(p.offered())])
				shot("normal_after")
				_click(p._cards.get_child(0) as Control); _wait = 25; return false
			_flow.save_and_quit(); _wait = 60; _st = 17
		17:
			_flow.continue_game(); _wait = 80; _st = 18
		18:
			if not _settle(): _wait = 10; return false
			var r := _flow.run
			L("存档退出再继续：奉「%s」、改过 %s；信物 %s；Lv.%d；%s；改信重选剩 %d" % [String(r.selected_faith), str(r.faith_converted), _charms(), _lv().level(), _god_cards(), _lv().repicks_left()])
			_st = 40
		40:
			L("完 err=0"); quit(0); return true
		99:
			L("完 err=1"); quit(1); return true
	return false
