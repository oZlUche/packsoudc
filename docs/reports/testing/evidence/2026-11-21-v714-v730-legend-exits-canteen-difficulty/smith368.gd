extends SceneTree
## 游戏测试 报告 368（PR #774）：魔晶石退出配方，金武改晶石素材 + 腺体；腺体不能用尘补。参数 <outdir> [seed]（在 dust693.gd 上改配方队列）
## 新档拒教程 → 测试辅助开炼金、铁匠铺 3 级、点科技、给尘和钱 → 三张配方各走一遍：
## 没打造过：打开看有没有尘标记，测试辅助硬要用尘补（应被拒）→ 测试辅助放真料、真点【打造】→ 再打开（仓库没料）：
## 看哪几项能补 → 真点能补的那几格 → 看「有+补 / 要」、尘数 → 测试辅助硬补不能补的格（应被拒）→ 放上不能补的那件 → 真点【打造】→ 看扣了几点尘
var out := ""
var mode := "new"
var seed_ := 31
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _shots := 0
var _runs := 0
var _snap := ""
var _rep_before := {}
var _handin := ""
var _before := {}
var _dust0 := 0
var _tip_btn: Button
var _picks: Array = []
var _q: Array = [&"forge_flame_meteor_maul", &"smith_mithril_sword", &"forge_thunder_siege_spear"]
var _cur := &""
var _r: SmithRecipeDef
var _keys: Array = []


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: mode = a[1]
	DirAccess.make_dir_recursive_absolute(out)
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func L(s: String) -> void:
	print("D368 " + s)


func shot(n: String) -> void:
	_shots += 1
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/board_%02d_%s.png" % [out, _shots, n])


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


func _all_named(pat: String) -> Array:
	var o := []
	for n in root.find_children(pat, "Control", true, false):
		if (n as Control).is_visible_in_tree(): o.append(n)
	return o


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


func _panel() -> Node:
	return _ms().commission_panel() if _ms() != null and _ms().has_method("commission_panel") else null


func _reps() -> String:
	var b := _flow.meta.commissions
	var o := []
	for f in Commissions.factions():
		o.append("%s %d" % [Names.of(f), b.rep_of(f.id)])
	return "、".join(o)


func _note_line(nid: String) -> String:
	var b := _flow.meta.commissions
	var n: Dictionary = b.notes.get(nid, {})
	var d := Commissions.def(StringName(nid))
	return "%s「%s」%s×%d 档%d 酬%d 剩%s 局 %s" % [nid, Names.of(d) if d != null else "?", String(n.get("faction", "")), int(n.get("count", 0)),
		int(n.get("band", 0)), int(n.get("funds", 0)), str(n.get("left", "-")), b.state_of(StringName(nid))]


func _board() -> String:
	var b := _flow.meta.commissions
	var pins := []
	for nid in b.pins:
		pins.append("·" if String(nid) == "" else String(nid))
	var hand := b.taken().filter(func(id): return NoticeBoard.is_note(id)).map(func(id): return _note_line(String(id)))
	var posted := NoticeBoard.posted(b).map(func(id): return _note_line(id))
	return "局数 %d；钉位 %s；栏上没接 %d：%s；手头 %d：%s" % [_flow.meta.runs, " ".join(pins), posted.size(), "；".join(posted), hand.size(), "；".join(hand)]


func _snapshot() -> String:
	var b := _flow.meta.commissions
	return JSON.stringify([b.pins, b.notes, b.taken()])


func _tab(key: String) -> void:
	_click(_ms()._tab_btns[key])


func _put(id: String) -> void:
	var d := _flow.items.get_def(StringName(id))
	if d == null: L("没有道具 %s" % id); return
	var it := ItemInstance.create(d, 0)
	it.uid = _flow.meta.allocate_uid()
	_flow.meta.warehouse.try_add(it)


func _fits(nid: String) -> Array:
	var d := Commissions.def(StringName(nid))
	var st: CommissionStage = d.stages[0]
	var ids := _flow.items.ids().filter(func(id): return Commissions.hand_in_fits(st, _flow.items.get_def(id)))
	ids.sort_custom(func(a, b): return _flow.items.get_def(a).rarity < _flow.items.get_def(b).rarity)
	return ids


func _wh(id: String) -> int:
	return _flow.meta.warehouse.items().filter(func(i): return String((i as ItemInstance).def.id) == id).size()


func _inv() -> Dictionary:
	var o := {}
	for i in _flow.meta.warehouse.items():
		var k := String((i as ItemInstance).def.id)
		o[k] = int(o.get(k, 0)) + 1
	return o


func _diff(a: Dictionary, b: Dictionary) -> String:
	var o := []
	var keys := a.keys()
	for k in b.keys(): if not keys.has(k): keys.append(k)
	for k in keys:
		var d := int(b.get(k, 0)) - int(a.get(k, 0))
		if d != 0: o.append("%s %+d" % [Names.of(_flow.items.get_def(StringName(k))), d])
	return "、".join(o)


func _sp() -> Node:
	return _ms().smithy_panel()


func _tip_text() -> String:
	var o := []
	for n in root.find_children("*", "", true, false):
		if n is HoverTip:
			for l in n.find_children("*", "", true, false):
				if (l is Label or l is RichTextLabel or l is Button) and (l as Control).is_visible_in_tree():
					var t: String = (l as RichTextLabel).get_parsed_text() if l is RichTextLabel else ((l as Button).text if l is Button else (l as Label).text)
					if t.strip_edges() != "": o.append(("[%s]" if l is Button else "%s") % t.strip_edges().replace("\n", " "))
	return " / ".join(o) if not o.is_empty() else "（没有悬浮窗）"


func _tip_button(prefix: String) -> Button:
	for n in root.find_children("*", "", true, false):
		if n is HoverTip:
			for bt in n.find_children("*", "Button", true, false):
				if (bt as Control).is_visible_in_tree() and (bt as Button).text.begins_with(prefix): return bt
	return null


func _wh_rect(uid: int) -> Rect2:
	for n in root.find_children("*", "", true, false):
		if n is ContainerView and (n as Control).is_visible_in_tree():
			var cv := n as ContainerView
			var ct = cv.container()
			if ct != null and ct.has_method("get_item") and ct.get_item(uid) != null:
				var r := cv.item_rect(uid)
				if r.size != Vector2.ZERO: return Rect2(cv.get_global_rect().position + r.position, r.size)
	return Rect2()


func _ap() -> Node:
	return _ms().alchemy_panel()


func _subs() -> String:
	var o := []
	for k in _ms()._sub_btns:
		var b := _ms()._sub_btns[k] as Control
		if b != null and b.is_visible_in_tree(): o.append(k)
	return str(o)


func _state() -> String:
	var m := _flow.meta
	return "尘 %d；打造过 %s；仓库 %d 件；金币 %d；局数 %d；协会声望 %d（%d 档）；炼金列出 %s、开 %s；铁匠铺开 %s；集市开 %s" % [m.dust, str(m.forged_recipes), m.warehouse.item_count(), m.funds, m.runs,
		m.commissions.rep_of(&"society"), Alchemy.tier(m), str(_flow.alchemy_listed()), str(_flow.alchemy_open()), str(_flow.facility_open(&"smithy")), str(_flow.facility_open(&"market"))]


func _cheapest(slot: Dictionary) -> StringName:
	var best := &""
	var bv := -1
	for id in _flow.items.ids(true):
		var d := _flow.items.get_def(id)
		if d == null or d.is_unique() or not SmithRecipeDef.slot_fits(slot, d): continue
		if bv < 0 or ItemValue.of(d) < bv: bv = ItemValue.of(d); best = id
	return best


func _clear_mats() -> void:
	var ids := []
	for key in _r.inputs: ids.append(String(key))
	for i in _flow.meta.warehouse.items():
		var it := i as ItemInstance
		var hit := ids.has(String(it.def.id))
		for s in _r.slots(): if SmithRecipeDef.slot_fits(s, it.def): hit = true
		if hit: _flow.meta.warehouse.remove(it.uid)


func _put_real(skip_key: String = "") -> String:
	var o := []
	for key in _r.inputs:
		if String(key) == skip_key: continue
		for _i in int(_r.inputs[key]): _put(String(key))
		o.append("%s×%d" % [key, int(_r.inputs[key])])
	var slots := _r.slots()
	for i in slots.size():
		if Smithy.SLOT_KEY % i == skip_key: continue
		var id := _cheapest(slots[i])
		for _i in int(slots[i]["count"]): _put(String(id))
		o.append("%s→%s×%d" % [Smithy.SLOT_KEY % i, id, int(slots[i]["count"])])
	return "、".join(o)


func _mat_slots() -> Array:
	var o := []
	for n in _sp().recipe_scroll().find_children("*", "", true, false):
		if n is Control and (n as Control).is_visible_in_tree() and ("on_toggle" in n) and String(n.get("key")) != "":
			o.append(n)
	return o


func _scroll_text() -> String:
	return _labels_under(_sp().recipe_scroll())


func _lines() -> String:
	var got := Smithy.have(_flow.meta, _r)
	var d: Dictionary = _sp().dust_lines(_r, got)
	return "能补 %s（不能补的：%s）" % [str(d), str(_nodust())]


func _nodust() -> Array:
	var o := []
	for key in _r.inputs:
		if Alchemy.line_cost(_r, String(key), _flow.items) < 0: o.append(String(key))
	for i in _r.slots().size():
		if Alchemy.line_cost(_r, Smithy.SLOT_KEY % i, _flow.items) < 0: o.append("%s(%s≥%d)" % [Smithy.SLOT_KEY % i, _r.slots()[i]["material"], int(_r.slots()[i]["min"])])
	return o


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 12000:
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
			var bk := _flow.meta.commissions
			for id in [&"legion_forge_token", &"society_first_survey", &"greylamp_check_scale"]: _flow.report_commission(id)
			for id in [&"society_identify_ore", &"society_copy_recipe"]:
				var d := Commissions.def(id)
				if not bk.taken().has(id): Commissions.take(bk, d, &"smith_shortsword", [&"smith_shortsword"])
				Commissions._complete(_flow.meta, d, _flow.items)
			var cd := Commissions.def(&"society_alchemy")
			while Alchemy.tier(_flow.meta) < Commissions.required_tier(cd) and bk.rep_of(&"society") < 1000: bk.rep["society"] = bk.rep_of(&"society") + 1
			for id in [&"society_permit", &"society_alchemy"]:
				var d := Commissions.def(id)
				if not bk.taken().has(id): Commissions.take(bk, d)
				Commissions._complete(_flow.meta, d, _flow.items)
			_flow.meta.facility_levels[Smithy.ID] = 3
			for r in _flow.smith_recipes:
				var rr := r as SmithRecipeDef
				if rr.tech != &"": _flow.meta.tech_levels[String(rr.tech)] = maxi(int(_flow.meta.tech_levels.get(String(rr.tech), 0)), rr.tech_level)
			_flow.meta.funds += 20000
			_flow.meta.dust = 3000
			_flow.sync_commissions(); _flow.save_meta()
			L("测试辅助：炼金开 %s；铁匠铺 3 级、配方要的科技点满；金币 %d；尘 %d；打造过 %s" % [str(_flow.alchemy_open()), _flow.meta.funds, _flow.meta.dust, str(_flow.meta.forged_recipes)])
			_flow.to_main_menu(); _wait = 30; _st = 3
		3:
			_flow.continue_game(); _wait = 40; _st = 4
		4:
			if scr != GameFlow.Screen.META: return false
			_tab("logistics"); _wait = 20; _st = 5
		5:
			_click(_ms()._sub_btns["smithy"]); _wait = 20; _st = 10
		10:
			if _q.is_empty(): _st = 99; return false
			_cur = _q.pop_front(); _r = SmithRecipeDef.find(_flow.smith_recipes, _cur)
			L("=== %s：料 %s；格 %s；打造过 %s" % [_cur, str(_r.inputs), str(_r.slots()), str(_flow.meta.has_forged(_cur))])
			_clear_mats(); _flow.meta.changed.emit()
			_click(_sp().group_key(String(_r.group))); _wait = 20; _st = 11
		11:
			if _sp().opened() != _cur: _click(_sp().cell(_cur)); _wait = 20
			_st = 12
		12:
			L("没打造过、仓库没料：%s；%s；页上尘数牌 %s「%s」" % [_scroll_text().left(300), _lines(), str(_named("DustHave") != null), (_named("DustHave").find_children("*", "Label", true, false)[0] as Label).text if _named("DustHave") != null else "-"])
			L("　　可点的料格 %d 个" % _mat_slots().size())
			for cid in ["fire_crystal", "fire_crystal_high"]: _put(cid)
			var got := Smithy.have(_flow.meta, _r)
			L("　　测试辅助放进魔晶石 fire_crystal、fire_crystal_high：这张认到的 %s（晶石素材格该还是 0）" % str(got))
			for i in _flow.meta.warehouse.items():
				if String((i as ItemInstance).def.id).begins_with("fire_crystal"): _flow.meta.warehouse.remove((i as ItemInstance).uid)
			var k0: String = String(_r.inputs.keys()[0]) if not _r.inputs.is_empty() else Smithy.SLOT_KEY % (_r.slots().size() - 1)
			L("　　测试辅助硬用尘补 %s：「%s」；尘 %d" % [k0, _flow.forge(_cur, {k0: 1}), _flow.meta.dust])
			shot(String(_cur) + "_unforged")
			L("　　测试辅助放真料：%s" % _put_real())
			_flow.meta.changed.emit(); _wait = 15; _st = 13
		13:
			var fb = _sp().forge_button(_cur)
			_before = _inv(); _dust0 = _flow.meta.dust
			L("　　【打造】灰 %s；真点" % str((fb as BaseButton).disabled))
			_click(fb); _wait = 25; _st = 14
		14:
			L("　　打完：仓库 %s；尘 %d → %d；打造过 %s" % [_diff(_before, _inv()), _dust0, _flow.meta.dust, str(_flow.meta.has_forged(_cur))])
			_clear_mats(); _flow.meta.changed.emit(); _wait = 15; _st = 15
		15:
			if _sp().opened() != _cur: _click(_sp().cell(_cur)); _wait = 20; return false
			L("打造过、仓库没料：%s；%s" % [_scroll_text().left(300), _lines()])
			_keys = _mat_slots().map(func(n): return String(n.get("key")))
			L("　　可点的料格 %s" % str(_keys))
			_st = 16
		16:
			if _keys.is_empty(): _wait = 10; _st = 17; return false
			var k: String = _keys.pop_front()
			var n: Control = null
			for c in _mat_slots(): if String(c.get("key")) == k: n = c
			L("　　真点料格 %s%s" % [k, "" if n != null else "（找不到）"])
			if n != null: _click(n)
			_wait = 15
		17:
			var fb = _sp().forge_button(_cur)
			L("点完：用尘 %s；页上 %s；【打造】灰 %s；能打「%s」" % [str(_sp().dust_choice()), _scroll_text().left(300), str((fb as BaseButton).disabled), Smithy.can_forge(_flow.meta, _r, _flow.items, _sp().dust_choice())])
			L("　　排版：%s" % _overflow(_sp().recipe_scroll()))
			shot(String(_cur) + "_dust")
			var bad := _nodust()
			if not bad.is_empty():
				var key := String(bad[0]).get_slice("(", 0)
				var tryd: Dictionary = _sp().dust_choice().duplicate(); tryd[key] = 1
				L("　　测试辅助硬补不能补的 %s：「%s」" % [key, _flow.forge(_cur, tryd)])
				for k in bad:
					var kk := String(k).get_slice("(", 0)
					if kk.begins_with("slot:"):
						var s: Dictionary = _r.slots()[int(kk.substr(5))]
						var id := _cheapest(s)
						for _i in int(s["count"]): _put(String(id))
						L("　　测试辅助放不能补的那格真料 %s×%d（%s）" % [id, int(s["count"]), Names.of(_flow.items.get_def(id))])
					else:
						for _i in int(_r.inputs.get(kk, _r.inputs.get(StringName(kk), 0))): _put(kk)
				_flow.meta.changed.emit()
			_wait = 15; _st = 18
		18:
			var fb = _sp().forge_button(_cur)
			var want := Alchemy.dust_cost(_r, _flow.items, _sp().dust_choice())
			_before = _inv(); _dust0 = _flow.meta.dust
			L("真点【打造】前：用尘 %s，应扣 %d；【打造】灰 %s" % [str(_sp().dust_choice()), want, str((fb as BaseButton).disabled)])
			_snap = str(want)
			_click(fb); _wait = 25; _st = 19
		19:
			L("　　打完：仓库 %s；尘 %d → %d（扣 %d，应扣 %s）；告示 %s" % [_diff(_before, _inv()), _dust0, _flow.meta.dust, _dust0 - _flow.meta.dust, _snap, str(NoticeLayer.history().slice(0, 1).map(func(x): return x.get("text", "")))])
			_st = 10
		_:
			quit(0); return true
	return false


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