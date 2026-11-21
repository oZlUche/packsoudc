extends SceneTree
## 游戏测试 v7.35（PR #788）：委托改成「办成后点【完成】才结案」。参数 <outdir>
## 新档拒教程 → 委托页剧情：看各卡的键 → 真点《领炉牌》【完成】（营地报到：当场结案、跳铁匠铺）→ 《把路画回来》【完成】跳出征页 →
## 《第一畦》【完成】跳苗圃 → 《试种》【前往】跳苗圃 → 《照抄》【前往】跳铁匠铺 → 《查验材料》【交货】先交 1 件（不结案）再交够（直接结案）→
## 测试辅助：《清路》在局里打够 3 场 → 卡上只有【完成】、没有【放弃】、声望没到 → 真点【完成】领 → 告示栏纸条接一张、记办成 → 手头托盘还占着 → 【完成】腾出
const TAG := "M788"
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

var _rep0 := 0


func _card_keys(id: String) -> String:
	var card := _named("Card_" + id)
	var keys := []
	for pre in ["Finish_", "GoTo_", "Report_", "Abandon_", "Take_"]:
		if _named(pre + id) != null: keys.append(pre.trim_suffix("_"))
	return "《%s》%s；键 %s" % [id, _labels_under(card).left(160) if card != null else "（卡不在页上）", str(keys)]


func _story() -> void:
	_tab("commissions")


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 14000:
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
			L("测试辅助：几方按第一局结算到营地：%s" % str(Commissions.arrive(bk, 1)))
			_flow.sync_commissions(); _flow.save_meta(); _flow.meta.changed.emit()
			_story(); _wait = 20; _st = 4
		4:
			_click(_named("Sub_story")); _wait = 20; _st = 5
		5:
			L("剧情页：页上 %s" % _labels_under(_ms()).left(500))
			for id in ["legion_forge_token", "society_first_survey", "growers_first_bed", "cartographers_redraw", "greylamp_check_scale"]: L("　　" + _card_keys(id))
			L("　　排版：%s" % _overflow(_ms()))
			shot("story_fresh")
			_rep0 = bk.rep_of(&"legion")
			_click(_named("Finish_legion_forge_token")); _wait = 25; _st = 6
		6:
			L("真点《领炉牌》【完成】：状态 %s；军团声望 %d → %d；铁匠铺开 %s；现在的页 %s；告示 %s" % [bk.state_of(&"legion_forge_token"), _rep0, bk.rep_of(&"legion"), str(_flow.facility_open(&"smithy")), _ms().page(), str(NoticeLayer.history().slice(0, 2).map(func(x): return x.get("text", "")))])
			shot("after_forge_token")
			_story(); _wait = 20; _st = 7
		7:
			_click(_named("Sub_story")); _wait = 15; _st = 8
		8:
			_click(_named("Finish_cartographers_redraw")); _wait = 25; _st = 9
		9:
			L("真点《把路画回来》【完成】：状态 %s；现在的页 %s（应是出征页）" % [bk.state_of(&"cartographers_redraw"), _ms().page()])
			shot("after_redraw")
			_story(); _wait = 20; _st = 10
		10:
			_click(_named("Sub_story")); _wait = 15; _st = 11
		11:
			_click(_named("Finish_growers_first_bed")); _wait = 25; _st = 12
		12:
			L("真点《第一畦》【完成】：状态 %s；现在的页 %s（应是苗圃）" % [bk.state_of(&"growers_first_bed"), _ms().page()])
			shot("after_first_bed")
			_click(_named("Finish_society_first_survey")) if _named("Finish_society_first_survey") != null else null
			_story(); _wait = 20; _st = 13
		13:
			_click(_named("Sub_story")); _wait = 15; _st = 14
		14:
			if _named("Finish_society_first_survey") != null: _click(_named("Finish_society_first_survey")); _wait = 25; _st = 15; return false
			_st = 15
		15:
			L("《第一次勘测》：状态 %s；页 %s" % [bk.state_of(&"society_first_survey"), _ms().page()])
			_story(); _wait = 20; _st = 16
		16:
			_click(_named("Sub_story")); _wait = 20; _st = 17
		17:
			for id in ["growers_trial_sow", "society_copy_recipe", "society_identify_ore", "legion_check_materials", "legion_clear_road"]: L("　　" + _card_keys(id) + "；状态 " + bk.state_of(StringName(id)))
			L("　　排版：%s" % _overflow(_ms()))
			shot("story_second")
			var picks := _flow.commission_picks()
			L("测试辅助：《照抄》选第一张配方 %s 接下：%s" % [str(picks.slice(0, 1)), _flow.take_commission(&"society_copy_recipe", picks[0] if not picks.is_empty() else &"")])
			_click(_named("GoTo_growers_trial_sow")); _wait = 25; _st = 18
		18:
			L("真点《试种》【前往】：页 %s（应是苗圃）；状态 %s" % [_ms().page(), bk.state_of(&"growers_trial_sow")])
			shot("goto_nursery")
			_story(); _wait = 20; _st = 19
		19:
			_click(_named("Sub_story")); _wait = 15; _st = 20
		20:
			_click(_named("GoTo_society_copy_recipe")); _wait = 25; _st = 21
		21:
			L("真点《照抄》【前往】：页 %s（应是铁匠铺）" % _ms().page())
			shot("goto_smithy")
			var wh0 := _ids(_flow.meta.warehouse)
			L("主仓库现在 %s" % str(wh0))
			_put("iron_ore")
			_flow.meta.changed.emit()
			L("测试辅助：主仓库放 1 块铁矿石；《查验材料》会交的 %s" % str(Commissions.hand_in_picks(_flow.meta, Commissions.def(&"legion_check_materials"), 0).map(func(i): return String(i.def.id))))
			_story(); _wait = 20; _st = 22
		22:
			_click(_named("Sub_story")); _wait = 15; _st = 23
		23:
			L("　　" + _card_keys("legion_check_materials"))
			_rep0 = bk.rep_of(&"legion")
			_click(_named("Report_legion_check_materials")); _wait = 25; _st = 24
		24:
			L("真点【交货】（仓库里合格的 1 件）：状态 %s；进度 %s；声望 %d → %d；主仓库 %s" % [bk.state_of(&"legion_check_materials"), str(bk.entry(&"legion_check_materials").get("progress", 0)), _rep0, bk.rep_of(&"legion"), str(_ids(_flow.meta.warehouse))])
			L("　　" + _card_keys("legion_check_materials"))
			shot("hand_in_partial")
			_put("iron_ore"); _put("iron_ore"); _put("iron_ore")
			_flow.meta.changed.emit()
			_story(); _wait = 20; _st = 25
		25:
			_click(_named("Sub_story")); _wait = 15; _st = 26
		26:
			_click(_named("Report_legion_check_materials")); _wait = 25; _st = 27
		27:
			L("再放 3 块、真点【交货】：状态 %s（应直接结案）；声望 %d → %d；主仓库铁矿石还剩 %d 块；卡 %s" % [bk.state_of(&"legion_check_materials"), _rep0, bk.rep_of(&"legion"), _ids(_flow.meta.warehouse).count("iron_ore"), "还在" if _named("Card_legion_check_materials") != null else "不在页上了"])
			shot("hand_in_done")
			var d := Commissions.def(&"legion_clear_road")
			if bk.state_of(d.id) != CommissionBook.TAKEN: L("《清路》没接上：%s" % bk.state_of(d.id))
			var r := {}
			for k in 3: r = Commissions.credit(_flow.meta, d, 0, "walk:%d" % k, _flow.items)
			_flow.sync_commissions(); _flow.save_meta(); _flow.meta.changed.emit()
			L("测试辅助：《清路》局里打赢 3 场：最后一次 %s；状态 %s；声望 %d" % [str(r), bk.state_of(d.id), bk.rep_of(&"legion")])
			_rep0 = bk.rep_of(&"legion")
			_story(); _wait = 20; _st = 28
		28:
			_click(_named("Sub_story")); _wait = 15; _st = 29
		29:
			L("办成了等点：" + _card_keys("legion_clear_road"))
			shot("ready_card")
			_click(_named("Finish_legion_clear_road")); _wait = 25; _st = 30
		30:
			L("真点《清路》【完成】：状态 %s；声望 %d → %d；页 %s；告示 %s" % [bk.state_of(&"legion_clear_road"), _rep0, bk.rep_of(&"legion"), _ms().page(), str(NoticeLayer.history().slice(0, 2).map(func(x): return x.get("text", "")))])
			_assist_done(["legion_permit"], &"legion", 0)
			var n := NoticeBoard.first_fill(_flow.meta)
			_flow.save_meta(); _flow.meta.changed.emit()
			L("测试辅助：军团开放单记办成；告示栏首贴 %d 张；栏上 %s" % [n, str(NoticeBoard.posted(bk))])
			_story(); _wait = 20; _st = 31
		31:
			var sub := _named("Sub_regular")
			if sub == null: L("没有「告示栏」小键；页上 %s" % _labels_under(_ms()).left(300)); _st = 99; return false
			_click(sub); _wait = 20; _st = 32
		32:
			var posted := NoticeBoard.posted(bk)
			L("告示栏：%s" % _labels_under(_ms()).left(400))
			shot("board")
			if posted.is_empty(): _st = 99; return false
			var id: String = posted[0]
			for pid in posted:
				var pd := Commissions.def(StringName(pid))
				if pd != null and pd.stages[0].goal != &"hand_in": id = pid; break
			var tk := _named("Take_" + id)
			L("接第一张 %s：键 %s" % [id, "有" if tk != null else "没有（直接调 take）"])
			if tk != null: _click(tk)
			else: _ms()._commissions.take(StringName(id))
			set_meta("note", id); _wait = 25; _st = 33
		33:
			var id := String(get_meta("note"))
			var d := Commissions.def(StringName(id))
			L("接了：状态 %s；手头 %s" % [bk.state_of(StringName(id)), str(bk.in_hand())])
			var s := Commissions.current_stage(bk, StringName(id))
			var r := {}
			for k in maxi(1, d.stages[s].count): r = Commissions.credit(_flow.meta, d, s, "walk:%d" % k, _flow.items)
			_flow.sync_commissions(); _flow.save_meta(); _flow.meta.changed.emit()
			L("测试辅助：纸条那一步做够：%s；状态 %s；手头 %s" % [str(r), bk.state_of(StringName(id)), str(bk.in_hand())])
			_rep0 = bk.rep_of(d.faction)
			_story(); _wait = 20; _st = 34
		34:
			_click(_named("Sub_regular")); _wait = 20; _st = 35
		35:
			var id := String(get_meta("note"))
			L("办成后手头托盘：%s；键 %s" % [_labels_under(_named("HandPlank")).left(300), str(["Finish_", "Abandon_"].filter(func(p): return _named(p + id) != null))])
			shot("note_ready")
			_click(_named("Finish_" + id)); _wait = 25; _st = 36
		36:
			var id := String(get_meta("note"))
			L("真点纸条【完成】：状态 %s；声望 %d → %d；手头 %s；托盘 %s" % [bk.state_of(StringName(id)), _rep0, bk.rep_of(Commissions.def(StringName(id)).faction), str(bk.in_hand()), _labels_under(_named("HandPlank")).left(200)])
			shot("note_done")
			_st = 99
		_:
			quit(0); return true
	return false
