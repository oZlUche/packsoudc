extends SceneTree
## 测试 v9.41（PR #1016）：苗圃整屏背景、没有【选中】、种不了写原因、【种下】真点。参数 <outdir> <lang>
const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const Support := preload("res://tests/run/flow_support.gd")
var out := ""
var _s: Control
var _f := 0
var _n := 0
var _bad := 0
var _q: Array = []
var _wait := 0


func L(s: String) -> void:
	print("NS1016 " + s)


func shot(name_: String) -> void:
	_n += 1
	root.get_texture().get_image().save_png("%s/ns1016_%02d_%s.png" % [out, _n, name_])


func _click(c: Control) -> void:
	var p: Vector2 = root.get_final_transform() * (c.global_position + c.size * 0.5)
	var m := InputEventMouseMotion.new(); m.position = p; m.global_position = p
	root.push_input(m)
	for down in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT; b.pressed = down; b.position = p; b.global_position = p
		root.push_input(b)


func _slips() -> String:
	var p = _s.nursery_panel()
	var o := []
	for b in p.find_children("Sow_*", "", true, false):
		var crop := String(b.name).split("_", true, 2)[2]
		var why := p.find_child("Why_" + crop, true, false) as Label
		o.append("%s：【%s】%s%s" % [p.crop_name(StringName(crop)), b.text, "灰" if b.disabled else "亮", ("，原因「%s」" % why.text) if why != null else ""])
	return "；".join(o)


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "/tmp"
	UiText.lang = a[1] if a.size() > 1 else "zh"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	Support.pass_tutorials(f)
	f.meta.commissions.arrived["growers"] = 1
	f.sync_commissions()
	f.report_commission(&"growers_first_bed")
	_s = W178._screen(f, root)
	_s.show_tab("nursery")
	var dis := func():
		if _s._arrival != null:
			L("先点掉弹窗：%s" % _s._arrival.name)
			var k = _s._arrival.find_child("Key_0", true, false)
			if k != null: _click(k)
	_q = [[dis, 20], [dis, 20], [dis, 20],
		[func():
			if _s._arrival != null:
				L("先点掉弹窗：%s" % _s._arrival.name)
				var k = _s._arrival.find_child("Key_0", true, false)
				if k != null: _click(k)
			, 20],
		[func():
			var p = _s.nursery_panel()
			L("背景 %s；苗圃页在 %s；【选中】键 %d 个；纸条：%s" % [_s.backdrop_name(), str(p.is_visible_in_tree()), p.find_children("Pick_*", "", true, false).size(), _slips()])
			if _s.backdrop_name() != "nursery/scene": _bad += 1
			if p.find_children("Pick_*", "", true, false).size() > 0: _bad += 1
			shot("nursery_empty")
			var go: Button = null
			for b in p.find_children("Sow_*", "", true, false):
				if go == null and not b.disabled: go = b
			set_meta("crop", String(go.name).split("_", true, 2)[2] if go != null else "")
			if go != null: _click(go), 20],
		[func():
			var p = _s.nursery_panel()
			var n: Nursery = _s.flow.meta.nursery
			L("点【种下】%s：地里 %d 株；%s" % [get_meta("crop"), n.plants(0).size(), _slips()])
			if n.plants(0).is_empty(): _bad += 1; L("BAD 点了没种上")
			shot("after_sow")
			# 放一束干草药束进仓库：苦叶草该能种
			var d: ItemDef = _s.flow.items.get_def(&"dried_herbs")
			if d == null:
				for id in ["herb_bundle", "dry_herb_bundle"]: if d == null: d = _s.flow.items.get_def(StringName(id))
			L("干草药束 id %s" % (String(d.id) if d != null else "找不到"))
			if d != null:
				_s.flow.meta.warehouse.try_add(ItemInstance.create(d, _s.flow.meta.allocate_uid()), true)
				_s.flow.meta.changed.emit()
				p.refresh(), 20],
		[func():
			L("仓库有一束干草药束后：%s" % _slips())
			shot("with_herb_bundle"), 5],
		[func(): L("完 bad=%d" % _bad); W178._cleanup(); quit(0), 1],
	]


func _process(_d: float) -> bool:
	_f += 1
	if _f < 30: return false
	if _f > 3000: L("超时"); quit(1); return true
	if _wait > 0: _wait -= 1; return false
	if _q.is_empty(): return false
	var a: Array = _q.pop_front()
	(a[0] as Callable).call()
	_wait = int(a[1])
	return false
