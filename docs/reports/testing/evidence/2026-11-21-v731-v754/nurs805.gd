extends SceneTree
## 游戏测试 v7.42 + v7.51（PR #795、#805，报告 375、376）：苗圃食材作物、4×4 棋盘、按形状摆、各自成熟、第二 / 三片、食材仓库炼金、老档一畦变一片。参数 <outdir>
## 新档拒教程 → 测试辅助：垦户社《第一片地》办成 → 真点「苗圃」：食堂没开只有药材 → 测试辅助开食堂 → 真点【种下】酸麦 ×3、山薯 ×2、蜜柚 → 【选中】野莓再点空格 →
## 种满再点（放不下）→ 悬停一株 → 测试辅助推进 2 局 →「可收获」→ 真点【收获】（只收熟的）→ 声望到信赖 / 签约代言 → 回主菜单再继续：几片 →
## 测试辅助开炼金 → 筛「食材」→【一键炼金】→【炼化】两下 → 回主菜单，把局外存档的苗圃改成老格式（plots）→ 继续：老畦摆进对应那片
const TAG := "N805"
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

var _dust0 := 0
var _sowq: Array = []


func _np() -> Node:
	return _ms().nursery_panel()


func _sub(key: String) -> void:
	_tab("logistics")
	if _ms()._sub_btns.has(key): _click(_ms()._sub_btns[key])
	else: L("后勤没有「%s」小键：%s" % [key, str(_ms()._sub_btns.keys())])


func _field(i: int) -> String:
	var n: Nursery = _flow.meta.nursery
	var g := n.field(i)
	if g == null: return "（没有第 %d 片）" % (i + 1)
	var o := []
	var used := 0
	for it in g.items():
		var u := (it as ItemInstance).uid
		used += (it as ItemInstance).def.cells_rotated((it as ItemInstance).rotation).size()
		o.append("%s@%s 差 %d%s" % [String(n.crop_of(u)), str((it as ItemInstance).get("position")), n.left_of(u), "（熟）" if n.unit_ripe(u) else ""])
	return "第 %d 片 %s：%d 株、占 %d / 16 格 [%s]" % [i + 1, str(g.size), o.size(), used, "，".join(o)]


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 16000:
		L("超时 st %d 屏 %d" % [_st, _flow.screen]); shot("timeout"); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	var bk: CommissionBook = _flow.meta.commissions if _flow.meta != null else null
	if _st < 3:
		if _boot(): _st = 3
		return false
	match _st:
		3:
			Commissions.arrive(bk, 1)
			_assist_done(["growers_trial_sow", "growers_first_bed"], &"growers", 10)
			L("测试辅助：《试种》《第一片地》办成（名字 %s）；苗圃开 %s；食堂开 %s；%d 片" % [Names.of(Commissions.def(&"growers_first_bed")) if Commissions.def(&"growers_first_bed") != null else "-", str(_flow.facility_open(&"nursery")), str(_flow.canteen_open()), _flow.meta.nursery.fields.size()])
			L("　　后勤小键（没重进营地）%s" % str(_ms()._sub_btns.keys()))
			_flow.to_main_menu(); _wait = 30; _st = 301
		301:
			_flow.continue_game(); _wait = 40; _st = 302
		302:
			if _flow.screen != GameFlow.Screen.META: return false
			L("回主菜单再继续：后勤小键 %s" % str(_ms()._sub_btns.keys()))
			_sub("nursery"); _wait = 25; _st = 4
		4:
			L("真点「苗圃」（食堂没开）：栏 %s；栏键 %s；页上 %s" % [str(_np().groups()), "有" if _named("GroupTabs") != null else "没有", _labels_under(_np()).left(300)])
			L("　　排版：%s" % _overflow(_np()))
			shot("nursery_herb_only")
			_assist_done(["greylamp_check_scale", "greylamp_unsigned_letter", "greylamp_check_medkits", "greylamp_permit", "greylamp_canteen"], &"greylamp", 25)
			L("测试辅助：灰灯食堂开 %s" % str(_flow.canteen_open()))
			_tab("expedition"); _wait = 15; _st = 5
		5:
			_sub("nursery"); _wait = 25; _st = 6
		6:
			L("食堂开了再进苗圃：栏 %s" % str(_np().groups()))
			_sowq = [["staple", "sour_wheat"], ["staple", "sour_wheat"], ["staple", "sour_wheat"], ["staple", "mountain_yam"], ["staple", "mountain_yam"], ["fruit", "honey_pomelo"]]
			_st = 7
		7:
			if _sowq.is_empty(): _st = 9; return false
			var q: Array = _sowq.front()
			var gb := _named("Group_" + String(q[0]))
			if gb != null: _click(gb)
			_wait = 12; _st = 80
		80:
			var q: Array = _sowq.front()
			if _np().group != StringName(q[0]):
				L("　　点栏键「%s」没切过去（现在 %s，键 %s）：直接切" % [q[0], String(_np().group), str(_named("Group_" + String(q[0])) != null)])
				_np().show_group(StringName(q[0]))
			_wait = 10; _st = 8
		8:
			var q: Array = _sowq.pop_front()
			var b := _named("Sow_0_" + String(q[1]))
			if b == null: L("纸条上没有 %s 的【种下】" % q[1])
			else: _click(b)
			set_meta("last", q[1]); _wait = 15; _st = 81
		81:
			L("　　真点【种下】%s：%s" % [get_meta("last"), _field(0)])
			_st = 7
		9:
			L("种了六株：%s" % _field(0))
			L("　　排版：%s" % _overflow(_np()))
			shot("sowed_six")
			_np().show_group(&"fruit")
			_wait = 12; _st = 91
		91:
			_click(_named("Pick_wild_berry"))
			_wait = 12; _st = 10
		10:
			var g := _flow.meta.nursery.field(0)
			var free := Vector2i(-1, -1)
			for y in 4:
				for x in 4:
					if free.x < 0 and g.cell_uid(Vector2i(x, y)) == GridInventory.EMPTY_UID: free = Vector2i(x, y)
			var fv: InventoryView = _np().field_view
			L("真点野莓【选中】：提示 %s；空格 %s" % [_labels_under(_named("PlaceHint")), str(free)])
			if free.x >= 0: _mouse_at(fv.global_position + fv.cell_origin_px(free) + Vector2(fv.cell_px, fv.cell_px) * 0.5, MOUSE_BUTTON_LEFT)
			set_meta("free", free); _wait = 15; _st = 11
		11:
			L("点空格 %s 种野莓：%s" % [str(get_meta("free")), _field(0)])
			shot("picked_berry")
			_st = 12
		12:
			var before := _flow.meta.nursery.plants(0).size()
			var why: String = _np().sow(0, &"wild_berry")
			if why == "" and _flow.meta.nursery.plants(0).size() > before and before < 16: _wait = 5; return false
			L("一直种野莓到放不下：最后一次原因「%s」；%s；告示 %s" % [why, _field(0), str(NoticeLayer.history().slice(0, 1).map(func(x): return x.get("text", "")))])
			shot("full")
			var fv: InventoryView = _np().field_view
			var it: ItemInstance = _flow.meta.nursery.plants(0)[0]
			var r: Rect2 = fv.item_rect(it.uid)
			_hover_at(fv.global_position + r.get_center())
			_wait = 100; _st = 13
		13:
			L("悬停 %s 那株：tooltip「%s」" % [String(_flow.meta.nursery.crop_of(_flow.meta.nursery.plants(0)[0].uid)), _named("Growth").tooltip_text if _named("Growth") != null else "-"])
			_hover_at(Vector2(-10, -10))
			for r in ["walk1", "walk2"]: Nursery.advance(_flow.meta, r)
			_flow.save_meta(); _flow.meta.changed.emit()
			L("测试辅助：推进 2 局：%s；可收获 %s" % [_field(0), str(_flow.nursery_ripe())])
			_tab("expedition"); _wait = 15; _st = 14
		14:
			_sub("nursery"); _wait = 25; _st = 15
		15:
			var hb := _named("Harvest_0") as Button
			var allh := []
			for n in root.find_children("Harvest_*", "Button", true, false): allh.append("%s 见 %s 灰 %s 删 %s" % [n.name, str(n.is_visible_in_tree()), str((n as Button).disabled), str(n.is_queued_for_deletion())])
			L("　　诊断：ripe_units(0) %d；全部收获键 %s；面板 %s" % [_flow.meta.nursery.ripe_units(0).size(), str(allh), str(_ms()._nursery)])
			_ms()._nursery.refresh()
			var hb2 := _named("Harvest_0") as Button
			L("　　手动 refresh 后：【收获】%s" % ("灰" if hb2 != null and hb2.disabled else "亮"))
			L("片键 %s；【收获】%s、悬停「%s」" % [_labels_under(_named("PlotTabs")), "灰" if hb != null and hb.disabled else "亮", hb.tooltip_text if hb != null else "-"])
			shot("ripe")
			set_meta("store0", _ids(_flow.meta.canteen.store))
			set_meta("wh0", _ids(_flow.meta.warehouse).size())
			_click(hb); _wait = 20; _st = 16
		16:
			var cnt := {}
			for s in _ids(_flow.meta.canteen.store): cnt[s] = int(cnt.get(s, 0)) + 1
			L("真点【收获】：%s；食材仓库 %s → %s；主仓库件数 %d → %d" % [_field(0), str(get_meta("store0")), str(cnt), int(get_meta("wh0")), _ids(_flow.meta.warehouse).size()])
			shot("harvested")
			while bk.rep_of(&"growers") < 50: bk.rep["growers"] = bk.rep_of(&"growers") + 1
			L("测试辅助：垦户社声望 50（档 %d）：sync → %s；%d 片" % [Commissions.tier_of(bk, Commissions.faction(&"growers")), str(_flow.sync_nursery()), _flow.meta.nursery.fields.size()])
			while bk.rep_of(&"growers") < 100: bk.rep["growers"] = bk.rep_of(&"growers") + 1
			bk.signed["growers"] = true
			_flow.save_meta()
			L("　　声望 100、签约代言（档 %d）：回主菜单再继续" % Commissions.tier_of(bk, Commissions.faction(&"growers")))
			_flow.to_main_menu(); _wait = 30; _st = 17
		17:
			_flow.continue_game(); _wait = 40; _st = 18
		18:
			if _flow.screen != GameFlow.Screen.META: return false
			L("继续游戏后：%d 片；%s" % [_flow.meta.nursery.fields.size(), _field(0)])
			_sub("nursery"); _wait = 25; _st = 19
		19:
			L("片键：%s；PlotTabs 节点 %d 个（不论见否）" % [_labels_under(_named("PlotTabs")), root.find_children("PlotTabs", "", true, false).size()])
			if _named("Plot_2") == null:
				_ms()._nursery.refresh()
				L("　　手动 refresh 后片键：%s" % _labels_under(_named("PlotTabs")))
			_click(_named("Plot_2")); _wait = 20; _st = 20
		20:
			_click(_named("Group_veg")); _wait = 12; _st = 21
		21:
			_click(_named("Sow_2_long_scallion")); _wait = 15; _st = 22
		22:
			L("第三片种长葱（1×3）：%s" % _field(2))
			shot("plot3")
			_assist_done(["society_first_survey", "society_copy_recipe", "society_identify_ore", "society_permit", "society_alchemy"], &"society", 50)
			_dust0 = _flow.meta.dust
			L("测试辅助：炼金开 %s；尘 %d；食材仓库 %d 件" % [str(_flow.facility_open(&"alchemy")), _dust0, _flow.meta.canteen.store.item_count()])
			_flow.save_meta(); _flow.to_main_menu(); _wait = 30; _st = 221
		221:
			_flow.continue_game(); _wait = 40; _st = 222
		222:
			if _flow.screen != GameFlow.Screen.META: return false
			_sub("alchemy"); _wait = 25; _st = 23
		23:
			var ap = _ms().alchemy_panel()
			var tp: OptionButton = ap.tag_pick
			var opts := []
			var pick := -1
			for i in tp.item_count:
				opts.append(tp.get_item_text(i))
				if tp.get_item_text(i).contains("食材") or tp.get_item_text(i).to_lower().contains("ingredient"): pick = i
			L("真点「炼金」：标签筛选 %s" % str(opts))
			if pick < 0: L("筛选里没有「食材」"); _st = 26; return false
			tp.select(pick); tp.item_selected.emit(pick)
			_wait = 15; _st = 24
		24:
			var ap = _ms().alchemy_panel()
			L("筛「食材」：一键范围 %d 件；计划勾 %d 件、跳过 %s" % [ap.auto_pool().size(), (ap.auto_plan().get("uids", []) as Array).size(), str(ap.auto_plan().get("skipped", 0))])
			_click(_named("AlchemyAuto")); _wait = 15; _st = 25
		25:
			var ap = _ms().alchemy_panel()
			L("真点【一键炼金】：勾上 %d 件；纸条 %s" % [ap.shelf.selected.size(), _labels_under(_named("Slip")).left(200)])
			shot("alchemy_pick")
			set_meta("store1", _flow.meta.canteen.store.item_count())
			_click(_named("AlchemyGo")); _wait = 10; _st = 251
		251:
			_click(_named("AlchemyGo")); _wait = 25; _st = 252
		252:
			L("真点【炼化】两下：食材仓库 %d → %d 件；尘 %d → %d；告示 %s" % [int(get_meta("store1")), _flow.meta.canteen.store.item_count(), _dust0, _flow.meta.dust, str(NoticeLayer.history().slice(0, 1).map(func(x): return x.get("text", "")))])
			shot("alchemy_done")
			_st = 26
		26:
			_flow.to_main_menu(); _wait = 30; _st = 27
		27:
			var mp := _flow.meta_path
			var d = JSON.parse_string(FileAccess.get_file_as_string(mp))
			if not (d is Dictionary): L("局外存档 %s 读不成 JSON" % mp); _st = 99; return false
			var holder: Dictionary = d
			if not holder.has("nursery") and holder.has("meta") and holder["meta"] is Dictionary: holder = holder["meta"]
			L("局外存档 %s：苗圃键 %s" % [mp, str((holder.get("nursery", {}) as Dictionary).keys())])
			holder["nursery"] = {"plots": [{"crop": "rope_hemp", "left": 1}, {"crop": "honey_pomelo", "left": 2}, {"crop": "retired_crop", "left": 1}], "last_run": "", "seq": 9}
			var fa := FileAccess.open(mp, FileAccess.WRITE)
			fa.store_string(JSON.stringify(d)); fa.close()
			L("测试辅助（模拟 v7.50 以前的老档）：苗圃写成三畦：绳麻差 1、蜜柚差 2、一种认不得的作物")
			_flow.continue_game(); _wait = 40; _st = 28
		28:
			if _flow.screen != GameFlow.Screen.META: return false
			L("读老档：%d 片；%s；%s；%s；还等着摆 %d" % [_flow.meta.nursery.fields.size(), _field(0), _field(1), _field(2), _flow.meta.nursery.legacy_count()])
			_sub("nursery"); _wait = 25; _st = 29
		29:
			L("老档苗圃页：%s" % _labels_under(_np()).left(300))
			shot("legacy")
			_st = 99
		_:
			quit(0); return true
	return false
