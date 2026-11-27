extends SceneTree
## 测试 v9.40（PR #1013）：委托交货、铁匠铺打造自己挑道具。真点格子 / 键。参数 <outdir> <lang>
const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const T110 := preload("res://tests/meta/test_tech.gd")
var out := ""
var _s: Control
var _f := 0
var _q: Array = []
var _wait := 0
var _bad := 0
var _n := 0


func L(s: String) -> void:
	print("HF1013 " + s)


func shot(name_: String) -> void:
	_n += 1
	root.get_texture().get_image().save_png("%s/hf1013_%02d_%s.png" % [out, _n, name_])


func _click(c: Control) -> void:
	var p: Vector2 = root.get_final_transform() * (c.global_position + c.size * 0.5)
	var m := InputEventMouseMotion.new(); m.position = p; m.global_position = p
	root.push_input(m)
	for down in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT; b.pressed = down; b.position = p; b.global_position = p
		root.push_input(b)


func _names(arr: Array) -> String:
	return str(arr.map(func(it): return "%s#%d=%d" % [Names.of(it.def), it.uid, ItemValue.of_instance(it)]))


func _wh_ids() -> Array:
	var a := []
	for it in _s.flow.meta.warehouse.items(): a.append((it as ItemInstance).uid)
	return a


func _key(i: int) -> Button:
	return _s._arrival.find_child("Key_%d" % i, true, false) as Button if _s._arrival != null else null


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "/tmp"
	UiText.lang = a[1] if a.size() > 1 else "zh"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	var f := W178._flow()
	var book := f.meta.commissions
	book.entries["legion_forge_token"] = {"state": CommissionBook.DONE, "stage": 0, "progress": 0, "keys": [], "times": 1, "pick": "", "seq": 0}
	book.rep["legion"] = 10
	f.sync_commissions()
	f.meta.tech_levels = {"bargain": 1, "warehouse": 1, "safe_box": 1, "pack": 1, "market": 0, "smithy": 0}
	f.derive_techs()
	f.smith_recipes = SmithRecipeDef.load_all()
	f.meta.funds = 1000
	for id in [&"iron_ore", &"iron_ore", &"copper_ingot", &"nail_keg", &"mithril_ingot", &"copper_ore", &"hardwood_plank", &"hardwood_plank", &"iron_ore", &"iron_ore", &"iron_ore", &"iron_ore"]:
		T110._add(f.meta, f.items, id)
	# 锁一件铁矿石：不该出现在可选里
	for it in f.meta.warehouse.items():
		if (it as ItemInstance).def.id == &"iron_ore": (it as ItemInstance).set_locked(true); set_meta("locked", (it as ItemInstance).uid); break
	_s = W178._screen(f, root)
	_s.show_tab("commissions")
	_s.commission_panel().show_faction(&"legion")
	var d := Commissions.def(&"legion_check_materials")
	var st := Commissions.current_stage(f.meta.commissions, &"legion_check_materials")
	var ch := Commissions.hand_in_choices(f.meta, d, st)
	L("交货：要 %d 件；可选 %s；锁定的 #%d 在可选里 %s" % [Commissions.hand_in_need(f.meta, d, st), _names(ch), get_meta("locked"), str(ch.any(func(i): return i.uid == get_meta("locked")))])
	set_meta("ch", ch)
	var rb := _s.commission_panel().find_child("Report_legion_check_materials", true, false) as Button
	_q = [
		[func(): _click(rb), 20],
		[func():
			L("交货窗：%s；【交货】灰 %s；【填满】灰 %s；格子 %d" % [str(_s._arrival != null and String(_s._arrival.name).begins_with("HandInNotice")), str(_key(0).disabled), str(_key(1).disabled), _s._arrival.find_children("Pick_*", "", true, false).size()])
			if not _key(0).disabled: _bad += 1; L("BAD 一件没选时【交货】亮着")
			shot("hand_in_empty")
			var big: ItemInstance = (get_meta("ch") as Array).back()
			set_meta("big", big.uid)
			_click(_s._arrival.find_child("Pick_%d" % big.uid, true, false)), 10],
		[func():
			L("点最贵的一件 #%d：已选 %s；【交货】灰 %s" % [get_meta("big"), str(_s._hand_sel), str(_key(0).disabled)])
			_click(_s._arrival.find_child("Pick_%d" % get_meta("big"), true, false)), 10],
		[func():
			L("再点一次取消：已选 %s" % str(_s._hand_sel))
			if not _s._hand_sel.is_empty(): _bad += 1
			_click(_s._arrival.find_child("Pick_%d" % get_meta("big"), true, false)), 10],
		[func():
			shot("hand_in_one")
			set_meta("before", _wh_ids())
			_click(_key(0)), 15],
		[func():
			var gone := (get_meta("before") as Array).filter(func(u): return not _wh_ids().has(u))
			var e: Dictionary = _s.flow.meta.commissions.entry(&"legion_check_materials")
			L("交了 1 件：仓库少了 %s（应为 #%d）；委托进度 %s 状态 %s" % [str(gone), get_meta("big"), str(e.get("progress")), str(e.get("state"))])
			if gone != [get_meta("big")]: _bad += 1; L("BAD 交掉的不是选中的那件")
			shot("after_hand_in")
			L("　　交货后弹出的窗：%s；键 %s" % [_s._arrival.name if _s._arrival != null else "-", str(_s._arrival.find_children("Key_*", "Button", true, false).map(func(b): return b.text)) if _s._arrival != null else "-"])
			if _s._arrival != null and not String(_s._arrival.name).begins_with("HandInNotice"): _click(_key(0))
			, 15],
		[func():
			L("　　点掉后窗：%s" % (_s._arrival.name if _s._arrival != null else "-"))
			var rb2 := _s.commission_panel().find_child("Report_legion_check_materials", true, false) as Button
			if rb2 != null and rb2.visible: _click(rb2)
			else: L("（委托已办完或没有【交货】键）"), 15],
		[func():
			if _s._arrival != null and String(_s._arrival.name).begins_with("HandInNotice"):
				_click(_key(1))
			, 10],
		[func():
			if _s._arrival != null and String(_s._arrival.name).begins_with("HandInNotice"):
				var d2 := Commissions.def(&"legion_check_materials")
				var ch2 := Commissions.hand_in_choices(_s.flow.meta, d2, Commissions.current_stage(_s.flow.meta.commissions, &"legion_check_materials"))
				L("第二次开窗点【填满】：已选 %s；可选 %s（价值低的在前，填满该挑前面的）" % [str(_s._hand_sel), _names(ch2)])
				shot("hand_in_filled")
				_click(_key(2))
			, 10],
		[func():
			L("【取消】后窗 %s" % ("关了" if _s._arrival == null else "还开着 " + String(_s._arrival.name)))
			_s.show_tab("smithy"), 15],
		[func():
			_click(_s.smithy_panel().forge_button(&"smith_shortsword")), 20],
		[func():
			var r := SmithRecipeDef.find(_s.flow.smith_recipes, &"smith_shortsword")
			var lines := Smithy.line_keys(r)
			var txt := []
			for k in lines:
				txt.append("%s 要 %d 可选 %s" % [k, Smithy.line_need(r, k, _s._smithy.dust_choice()), _names(Smithy.line_choices(_s.flow.meta, r, k))])
			L("打造短剑选料窗 %s：%s；【打造】灰 %s" % [str(_s._arrival != null and String(_s._arrival.name).begins_with("ForgePickNotice")), " | ".join(txt), str(_key(0).disabled)])
			if not _key(0).disabled: _bad += 1; L("BAD 没挑料时【打造】亮着")
			shot("forge_empty")
			# 在第一行点一格，看别的行同一件是否压灰
			var k0: String = lines[0]
			var c0: Array = Smithy.line_choices(_s.flow.meta, r, k0)
			set_meta("k0", k0); set_meta("u0", c0[0].uid)
			_click(_s._arrival.find_child("Tray_" + k0.replace(":", "_"), true, false).find_child("Pick_%d" % c0[0].uid, true, false)), 10],
		[func():
			var dim := []
			for c in _s._arrival.find_children("Pick_%d" % get_meta("u0"), "", true, false):
				dim.append("%s lit=%s sel=%s" % [c.get_parent().get_parent().name if c.get_parent() != null else "?", str(c.lit), str(c.selected)])
			L("第一行点 #%d：挑了 %s；同一件在各行 %s" % [get_meta("u0"), str(_s._forge_sel), str(dim)])
			_click(_key(1)), 10],
		[func():
			L("【填满】：%s；【打造】灰 %s" % [str(_s._forge_sel), str(_key(0).disabled)])
			shot("forge_filled")
			set_meta("pick", _s._forge_sel.duplicate(true))
			set_meta("before", _wh_ids())
			_click(_key(0)), 15],
		[func():
			var picked := []
			for k in get_meta("pick"): picked += get_meta("pick")[k]
			var gone := (get_meta("before") as Array).filter(func(u): return not _wh_ids().has(u))
			var newi := _wh_ids().filter(func(u): return not (get_meta("before") as Array).has(u))
			picked.sort(); gone.sort()
			L("打了：仓库少了 %s，挑的 %s，一致 %s；多了 %s" % [str(gone), str(picked), str(gone == picked), str(newi.map(func(u): return Names.of(_s.flow.meta.warehouse.get_item(u).def)))])
			if gone != picked: _bad += 1
			L("锁定的 #%d 还在 %s" % [get_meta("locked"), str(_wh_ids().has(get_meta("locked")))])
			shot("after_forge"), 5],
		[func(): L("完 bad=%d" % _bad); W178._cleanup(); quit(0), 1],
	]


func _process(_d: float) -> bool:
	_f += 1
	if _f < 20: return false
	if _f > 3000: L("超时"); quit(1); return true
	if _wait > 0: _wait -= 1; return false
	if _q.is_empty(): return false
	var a: Array = _q.pop_front()
	(a[0] as Callable).call()
	_wait = int(a[1])
	return false
