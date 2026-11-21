extends SceneTree
## 游戏测试 v6.94（PR #743）：法杖的晶石格按稀有度收原晶。参数 <outdir> [seed]
## 新档拒教程 → 测试辅助：铁匠铺升 3 级、点满杖艺、放料（雾晶 ×2、棱晶 ×2、紫晶柱、木料、银锭、秘银锭、木棍、铁木枝）、碎晶 3 件、补钱 →
## 后勤 → 铁匠铺：真点法杖类，看三张法杖配方写的料 → 真点打法师杖、魔导杖、大魔导杖 → 看料扣对没有 →
## 后勤 → 集市：悬停仓库里的碎晶，看卖价 → 真点【出售】
var out := ""
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
var _q: Array = [
	[&"smith_mage_staff", ["silver_ingot", "wooden_stick", "mist_crystal", "mist_crystal"], "正好两块雾晶（旁边放着四种火焰 / 清明魔晶石）"],
	[&"smith_magus_staff", ["ironwood_branch", "mithril_ingot", "prism_crystal", "prism_crystal"], "正好两块棱晶"],
	[&"smith_grand_magus_staff", ["mithril_ingot", "mithril_ingot", "hardwood_plank", "hardwood_plank", "amethyst_pillar"], "正好一根紫晶柱"],
	[&"smith_mage_staff", ["silver_ingot", "wooden_stick", "mist_crystal", "smoky_crystal", "amethyst_pillar"], "雾晶、烟晶、紫晶柱各一（看先用哪两块）"],
	[&"smith_magus_staff", ["ironwood_branch", "mithril_ingot", "mist_crystal", "prism_crystal"], "一块雾晶一块棱晶（雾晶不够格）"],
	[&"smith_grand_magus_staff", ["mithril_ingot", "mithril_ingot", "hardwood_plank", "hardwood_plank", "jimie_core_fire"], "没有紫晶柱，只有一颗独一的火之核（看会不会被吃掉）"],
]
var _case: Array = []
var _cur := &""
var _before := {}
var _funds0 := 0
var _shard := -1
var _tip_btn: Button


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: seed_ = int(a[1])
	DirAccess.make_dir_recursive_absolute(out)
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func L(s: String) -> void:
	print("S694 " + s)


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


func _gems() -> Array:
	return _flow.meta.warehouse.items().filter(func(i): return String((i as ItemInstance).def.material) == "gem").map(func(i): return String((i as ItemInstance).def.id))


## 每轮打完把这一轮剩下的料收走（四颗火焰 / 清明魔晶石和碎晶留着）
func _clear_case() -> void:
	var keep := ["fire_crystal_low", "fire_crystal", "fire_crystal_high", "quartz_cluster", "crystal_shards"]
	var left := []
	for i in _flow.meta.warehouse.items():
		var it := i as ItemInstance
		if (_case[1] as Array).has(String(it.def.id)) and not keep.has(String(it.def.id)):
			left.append(String(it.def.id)); _flow.meta.warehouse.remove(it.uid)
	if not left.is_empty(): L("　　收走这一轮没用上的：%s" % str(left))
	_flow.meta.changed.emit()


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


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 8000:
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
			var sd := _flow.items.get_def(&"crystal_shards")
			L("碎晶：稀有度 %d；基础价 %d；卖价 %d（比例 %.2f）" % [sd.rarity, ItemValue.of(sd), MetaState.sell_price_of(ItemInstance.create(sd, 0), _flow.sell_ratio()), _flow.sell_ratio()])
			for id in [&"smith_magic_staff", &"smith_mage_staff", &"smith_magus_staff", &"smith_grand_magus_staff"]:
				var r := SmithRecipeDef.find(_flow.smith_recipes, id)
				L("配方 %s：料 %s；自选格 %s；工钱 %d；铁匠铺 %d 级；%s %d 级" % [id, str(r.inputs), str(r.slots()), r.funds, r.level, r.tech, r.tech_level])
			for id in [&"legion_forge_token", &"society_first_survey", &"greylamp_check_scale"]: _flow.report_commission(id)
			_flow.sync_commissions()
			L("测试辅助办完三份开放单：铁匠铺开 %s；集市开 %s" % [str(_flow.facility_open(&"smithy")), str(_flow.facility_open(&"market"))])
			_flow.meta.facility_levels[Smithy.ID] = 3
			_flow.meta.tech_levels["staffcraft"] = 3
			_flow.meta.funds += 2000
			for id in ["fire_crystal_low", "fire_crystal", "fire_crystal_high", "quartz_cluster", "crystal_shards"]:
				_put(id)
			var woods := []
			_flow.meta.changed.emit(); _flow.save_meta()
			L("测试辅助：铁匠铺 3 级、杖艺 3 级、加 2000 金币、放料（木料 %s）；金币 %d" % [str(woods.slice(0, 2)), _flow.meta.funds])
			_tab("logistics"); _wait = 20; _st = 3
		3:
			_click(_ms()._sub_btns["smithy"]); _wait = 20; _st = 4
		4:
			var k = _sp().group_key("staff")
			if k == null: L("没有法杖类键"); _st = 99; return false
			_click(k); _wait = 20; _st = 5
		5:
			if _q.is_empty(): _st = 99; return false
			_case = _q.pop_front()
			_cur = _case[0]
			for id in _case[1]: _put(String(id))
			_flow.meta.changed.emit()
			L("=== %s：%s；仓库里的晶石 %s" % [_cur, _case[2], str(_gems())])
			if _sp().opened() == _cur: _st = 6; _wait = 15; return false
			var c = _sp().cell(_cur)
			if c == null: L("没有 %s 这一格（大类 %s；格 %s；杖艺 %d 级；铁匠铺 %d 级）" % [_cur, _sp().selected_group(), str(_sp()._cells.keys()), TechService.level(_flow.meta, &"staffcraft"), Smithy.level(_flow.meta)]); return false
			_click(c); _wait = 20; _st = 6
		6:
			var sc = _sp().recipe_scroll()
			var fb = _sp().forge_button(_cur)
			L("真点 %s：打造界面 %s" % [_cur, _labels_under(sc).left(600)])
			L("　　【打造】灰 %s「%s」；能打「%s」；排版：%s" % [str((fb as BaseButton).disabled) if fb != null else "-", fb.tooltip_text if fb != null else "", Smithy.can_forge(_flow.meta, SmithRecipeDef.find(_flow.smith_recipes, _cur), _flow.items), _overflow(sc)])
			shot("recipe_" + String(_cur).trim_prefix("smith_"))
			var r := SmithRecipeDef.find(_flow.smith_recipes, _cur)
			L("　　会用哪几件：%s" % str(Smithy.slot_picks(_flow.meta, r).map(func(a): return (a as Array).map(func(i): return "%s(%d)" % [(i as ItemInstance).def.id, (i as ItemInstance).def.rarity]))))
			_before = _inv(); _funds0 = _flow.meta.funds
			if fb == null or (fb as BaseButton).disabled:
				_clear_case(); _st = 5; return false
			_click(fb); _wait = 25; _st = 7
		7:
			L("　　真点【打造】后：仓库 %s；金币 %d → %d（%+d）" % [_diff(_before, _inv()), _funds0, _flow.meta.funds, _flow.meta.funds - _funds0])
			_clear_case(); _st = 5
		20:
			shot("smithy_after")
			_tab("warehouse"); _wait = 30; _st = 21
		21:
			for i in _flow.meta.warehouse.items():
				if String((i as ItemInstance).def.id) == "crystal_shards": _shard = (i as ItemInstance).uid; break
			var r := _wh_rect(_shard)
			L("仓库页：碎晶 %d 件，第一件在 %s" % [_wh("crystal_shards"), str(r)])
			if r.size == Vector2.ZERO:
				for n in root.find_children("*", "", true, false):
					if n is ContainerView and (n as Control).is_visible_in_tree(): L("　　看得见的容器视图 %s %s：%s" % [n.name, n.get_class(), str((n as ContainerView).container())])
				shot("market_no_rect"); _st = 99; return false
			_hover_at(r.get_center()); _wait = 60; _st = 22
		22:
			L("悬停碎晶：%s" % _tip_text())
			shot("shard_hover")
			var sb := _tip_button(UiText.t("act.sell"))
			if sb == null or sb.text.begins_with(UiText.t("act.sell_same").split("%")[0]):
				for n in root.find_children("*", "Button", true, false):
					if (n as Control).is_visible_in_tree() and (n as Button).text == UiText.t("act.sell"): sb = n; break
			_before = _inv(); _funds0 = _flow.meta.funds
			if sb == null: L("悬浮窗里没有【出售】"); _st = 99; return false
			L("真点【%s】（先挪鼠标过去）" % sb.text)
			_tip_btn = sb
			_hover_at(sb.get_global_rect().get_center()); _wait = 15; _st = 30
		30:
			if is_instance_valid(_tip_btn) and _tip_btn.is_visible_in_tree():
				_click(_tip_btn); L("　　点第一下：键上写「%s」" % _tip_btn.text)
			else: L("　　鼠标挪过去后悬浮窗收了"); _st = 23; return false
			_wait = 15; _st = 31
		31:
			L("　　第一下后：金币 %d；键上「%s」" % [_flow.meta.funds, _tip_btn.text if is_instance_valid(_tip_btn) else "-"])
			if is_instance_valid(_tip_btn) and _tip_btn.is_visible_in_tree(): _click(_tip_btn); L("　　点第二下")
			_wait = 25; _st = 23
		23:
			L("卖后：仓库 %s；金币 %d → %d（%+d）" % [_diff(_before, _inv()), _funds0, _flow.meta.funds, _flow.meta.funds - _funds0])
			shot("shard_sold")
			_st = 99
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