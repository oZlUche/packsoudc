extends SceneTree
## 游戏测试 v6.72（报告 348）：参数 <outdir> <new|old>
##   new：新档 → 拒教程（教程记走完）→ 进基地看落在哪、三处设施关没关 → 真点「科技」看说明板、真点它的直达键 →
##        真点「后勤」看集市 / 铁匠铺 → 回委托页剧情，三份【办理】逐个真点，每次记声望、设施、告示 → 声望 / 常规子页 →
##        科技、集市、铁匠铺真点进去 → 存档回主菜单再继续
##   old：读 v6.71 做的旧档（存档 v5）→ 记版本、折算后的声望和档、迁移记录、设施、金币 / 科技 / 仓库 → 委托页三子页 →
##        真点一份引导单的【办理】看声望 +10、不重发历史奖励 → 存档回主菜单再继续
var out := ""
var mode := "new"
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _shots := 0
var _reports: Array = []
var _ri := 0


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
	print("G672 " + s)


func shot(n: String) -> void:
	_shots += 1
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/%s_%02d_%s.png" % [out, mode, _shots, n])


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


func _click(b: Control) -> void:
	_mouse_at(b.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)


func _named(nm: String) -> Control:
	for n in root.find_children(nm, "Control", true, false):
		if (n as Control).is_visible_in_tree(): return n
	return null


func _btn_has(subs: Array) -> BaseButton:
	for n in root.find_children("*", "BaseButton", true, false):
		if not (n as Control).is_visible_in_tree() or not (n is Button): continue
		var t := (n as Button).text.strip_edges()
		for s in subs:
			if t != "" and t.contains(String(s)): return n
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


func _panel() -> Node:
	return _ms().commission_panel() if _ms() != null and _ms().has_method("commission_panel") else null


func _state() -> String:
	var b := _flow.meta.commissions
	var reps := []
	for f in Commissions.factions():
		reps.append("%s %d（第 %d 档）" % [Names.of(f), b.rep_of(f.id), Commissions.tier_of(b, f)])
	var fac := []
	for k in Commissions.FACILITIES:
		fac.append("%s %s" % [k, "开" if _flow.facility_open(k) else "关"])
	return "声望 %s；设施 %s；gated %s；grants %s；接着的 %s" % ["、".join(reps), "、".join(fac), str(b.gated), str(b.grants.keys()), str(b.taken())]


func _tab(key: String) -> void:
	_click(_ms()._tab_btns[key])


func _notices() -> String:
	return str(NoticeLayer.history().slice(0, 2).map(func(x): return x.get("text", "")))


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 30000:
		L("超时 st %d" % _st); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	match _st:
		0:
			if _f < 60: return false
			if mode == "old":
				L("主菜单「继续」：%s" % str(_flow.continue_game()))
				_wait = 40; _st = 2
			else:
				_flow.start_new_game(); _st = 1
		1:
			var b = _game.base()
			if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open():
				b.decline_tutorial(); _wait = 40; _st = 2
			elif _f > 240:
				_flow.decline_tutorial(); _wait = 40; _st = 2
		2:
			if _flow.screen != GameFlow.Screen.META: return false
			var m := _flow.meta
			L("进基地：教程全通 %s；委托可见 %s；落在 %s；委托子页 %s" % [str(_flow.tutorials_done()), str(_flow.commissions_visible()), _ms().tab(), _panel().sub() if _panel() != null else "-"])
			L("　　%s" % _state())
			if mode == "old":
				L("　　存档版本 %s；迁移记录 %s；金币 %d；科技 %s；铁匠铺 %d 级；仓库 %d 件" % [str(MetaState.SAVE_VERSION), str(m.migration_log), m.funds, str(m.tech_levels), Smithy.level(m), m.warehouse.item_count()])
				L("　　回执 %s；《两条回路》%s" % [str(m.commissions.receipts), str(m.commissions.entry(&"legion_two_routes"))])
			L("　　左列页签 %s" % str(_ms()._tab_btns.keys().map(func(k): return (_ms()._tab_btns[k] as Button).text)))
			shot("enter_base")
			_tab("commissions"); _wait = 20; _st = 3
		3:
			var p = _panel()
			_click(_named("Sub_story")); _wait = 20; _st = 4
		4:
			var p = _panel()
			L("委托页·剧情：%s" % _labels_under(p).left(900))
			_reports = []
			for n in p.find_children("Report_*", "BaseButton", true, false):
				if (n as Control).is_visible_in_tree(): _reports.append(String(n.name))
			L("　　【办理】键（这一方）：%s" % str(_reports))
			_reports = ["Report_legion_forge_token", "Report_society_first_survey", "Report_greylamp_check_scale"]
			L("　　排版：%s" % _overflow(_panel()))
			shot("story")
			if mode == "new":
				_tab("tech"); _wait = 20; _st = 5
			else:
				_st = 8
		5:
			var lp = _ms().locked_page()
			L("真点「科技」：落在 %s；说明板 %s：%s" % [_ms().tab(), "看得见" if lp != null and lp.is_visible_in_tree() else "看不见", _labels_under(lp)])
			L("　　右列仓库 %s" % ("露着" if _ms()._right != null and _ms()._right.is_visible_in_tree() else "收起"))
			L("　　排版：%s" % _overflow(_ms().locked_page()))
			shot("tech_locked")
			var go := _named("LockedGo")
			if go == null: L("　　没有直达键"); _st = 6; return false
			_click(go); _wait = 20; _st = 6
		6:
			L("真点说明板直达键：落在 %s；委托子页 %s" % [_ms().tab(), _panel().sub()])
			shot("locked_go")
			_tab("logistics"); _wait = 20; _st = 7
		7:
			var lp = _ms().locked_page()
			L("真点「后勤」（%s）：说明板 %s：%s" % [_ms()._sub, "看得见" if lp != null and lp.is_visible_in_tree() else "看不见", _labels_under(lp)])
			L("　　右列仓库 %s" % ("露着" if _ms()._right != null and _ms()._right.is_visible_in_tree() else "收起"))
			L("　　排版：%s" % _overflow(_ms().locked_page()))
			shot("logistics_locked")
			var other: String = "smithy" if _ms()._sub == "market" else "market"
			_click(_ms().sub_tab_buttons("logistics")[other]); _wait = 20; _st = 70
		70:
			var lp = _ms().locked_page()
			L("真点小键「%s」：说明板 %s：%s" % [_ms()._sub, "看得见" if lp != null and lp.is_visible_in_tree() else "看不见", _labels_under(lp)])
			L("　　右列仓库 %s" % ("露着" if _ms()._right != null and _ms()._right.is_visible_in_tree() else "收起"))
			shot("logistics_locked_2")
			_tab("commissions"); _wait = 20; _st = 71
		71:
			_click(_named("Sub_story")); _wait = 20; _st = 8
		8:
			if _ri >= _reports.size() or (mode == "old" and _ri >= 1):
				_st = 40 if mode == "new" else 10; return false
			if _fk_done != _ri:
				_fk_done = _ri
				var fk := _fac_key(String(_reports[_ri]).trim_prefix("Report_"))
				if fk != null: _click(fk); _wait = 20; return false
			var b := _named(_reports[_ri])
			if b == null: L("%s 找不到" % _reports[_ri]); _ri += 1; return false
			L("真点 %s【%s】" % [_reports[_ri], (b as Button).text if b is Button else ""])
			_click(b); _wait = 30; _st = 9
		9:
			L("　　之后：%s；告示 %s；回执 %d 条" % [_state(), _notices(), _flow.meta.commissions.receipts.size()])
			shot("after_%s" % _reports[_ri])
			_ri += 1; _st = 8
		10:
			L("剧情页最后：%s" % _labels_under(_panel()).left(600))
			_click(_named("Sub_regular")); _wait = 20; _st = 11
		11:
			L("委托页·常规：%s" % _labels_under(_panel()).left(700))
			L("　　排版：%s" % _overflow(_panel()))
			shot("regular")
			_click(_named("Sub_reputation")); _wait = 20; _st = 12
		12:
			L("委托页·声望：%s" % _labels_under(_panel()).left(900))
			L("　　排版：%s" % _overflow(_panel()))
			shot("reputation")
			_tab("tech"); _wait = 25; _st = 13
		13:
			var lp = _ms().locked_page()
			L("真点「科技」：落在 %s；科技页 %s；说明板 %s" % [_ms().tab(), "看得见" if _ms().tech_panel() != null and _ms().tech_panel().is_visible_in_tree() else "看不见", "看得见" if lp != null and lp.is_visible_in_tree() else "看不见"])
			shot("tech_open")
			_tab("logistics"); _wait = 25; _st = 14
		14:
			var lp = _ms().locked_page()
			L("真点「后勤」（%s）：说明板 %s" % [_ms()._sub, "看得见" if lp != null and lp.is_visible_in_tree() else "看不见"])
			shot("logistics_open")
			var other: String = "smithy" if _ms()._sub == "market" else "market"
			_click(_ms().sub_tab_buttons("logistics")[other]); _wait = 25; _st = 15
		15:
			var lp = _ms().locked_page()
			L("真点小键「%s」：说明板 %s" % [_ms()._sub, "看得见" if lp != null and lp.is_visible_in_tree() else "看不见"])
			shot("logistics_open_2")
			_flow.save_meta(); _flow.to_main_menu(); _wait = 30; _st = 16
		16:
			_flow.continue_game(); _wait = 40; _st = 17
		17:
			if _flow.screen != GameFlow.Screen.META: return false
			L("回主菜单再继续：落在 %s；%s" % [_ms().tab(), _state()])
			shot("reenter")
			_st = 99
		# ---------- v6.74：营地交货（真点【办理】）----------
		40:
			L("开放单办完后的剧情页：%s" % _labels_under(_panel()).left(1200))
			L("　　排版：%s" % _overflow(_panel()))
			shot("story_after_openers")
			_dl = [
				["society_identify_ore", ["mist_crystal"], "仓库只有一块雾晶（要两块）"],
				["society_identify_ore", ["prism_crystal", "crystal_shards"], "再放棱晶、碎晶（应先交便宜的碎晶）"],
				["legion_check_materials", ["copper_ore", "copper_ore", "copper_ore", "battle_axe"], "三块铜矿石 + 一把战斧（武器不该收）"],
				["greylamp_check_medkits", ["dried_herbs", "bitter_root"], "两件草药"],
			]
			_di = 0; _st = 41
		41:
			if _di >= _dl.size():
				_st = 10; return false
			var it: Array = _dl[_di]
			for id in it[1]: _put(String(id))
			_ms()._refresh(); _flow.meta.changed.emit()
			_click(_named("Sub_regular")); _wait = 10; _st = 42
		42:
			_click(_named("Sub_story")); _wait = 20; _st = 420
		420:
			var fk := _fac_key(String(_dl[_di][0]))
			if fk != null: _click(fk)
			_wait = 20; _st = 43
		43:
			var it: Array = _dl[_di]
			var b := _named("Report_" + String(it[0]))
			L("交货 %s：%s；【办理】%s；进度 %s" % [it[0], it[2], "在" if b != null else "不在", str(_flow.meta.commissions.entry(StringName(it[0])))])
			if b == null: _di += 1; _st = 41; return false
			_click(b); _wait = 30; _st = 44
		44:
			var it: Array = _dl[_di]
			var left := []
			for id in ["mist_crystal", "prism_crystal", "crystal_shards", "copper_ore", "battle_axe", "dried_herbs", "bitter_root"]:
				left.append("%s %d" % [id, _wh(id)])
			L("　　真点后：%s 状态 %s 进度 %s；仓库剩 %s；告示 %s" % [it[0], _flow.meta.commissions.state_of(StringName(it[0])), str(_flow.meta.commissions.entry(StringName(it[0])).get("progress", "-")), "、".join(left), _notices()])
			L("　　%s" % _state())
			shot("handin_%d_%s" % [_di, it[0]])
			_di += 1; _st = 41
		_:
			quit(0); return true
	return false


var _dl: Array = []
var _fk_done := -1


func _fac_key(cid: String) -> BaseButton:
	var d := Commissions.def(StringName(cid))
	if d == null: return null
	return _btn_has([Names.of(Commissions.faction(d.faction))])
var _di := 0


func _put(id: String) -> void:
	var d := _flow.items.get_def(StringName(id))
	if d == null: L("没有道具 %s" % id); return
	var it := ItemInstance.create(d, 0)
	it.uid = _flow.meta.allocate_uid()
	_flow.meta.warehouse.try_add(it)


func _wh(id: String) -> int:
	var n := 0
	for it in _flow.meta.warehouse.items():
		if String((it as ItemInstance).def.id) == id: n += 1
	return n


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
