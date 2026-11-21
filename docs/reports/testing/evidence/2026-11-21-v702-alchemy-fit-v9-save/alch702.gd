extends SceneTree
## 游戏测试 v6.97（PR #746，报告 358）：所有道具都能炼、一键炼金。参数 <outdir> new|old
## （在 alch691.gd 上改：放料一步换成第七节的检查）
## new：新档拒教程 → 测试辅助办完开放单和协会剧情、声望补到信赖 → 存档回主菜单再继续 → 后勤「炼金」键出没出、真点看说明板 →
##      委托页真点【接下】【办理】《万物可分》→ 真点「炼金」→ 测试辅助放料 → 右边仓库真点勾几件（含不能炼的）→ 看预览 → 真点【炼化】两下 →
##      看尘、仓库 → 测试辅助打一把配方看「打造过」→ 存档回主菜单再继续看尘和记录还在
## old：v6.85 写的局外存档（v7）读进来，看尘 0、记录空、仓库和设施照旧
## v8：tests/fixtures/meta_v8.json 当 1 号档读进来 → 升 v9、图鉴亮的战锤记打造过 → 测试辅助开炼金 → 真点铁匠铺战锤看能用尘补、真点料格补、真点【打造】
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
var _picks: Array = []
var _before := {}
var _dust0 := 0
var _tip_btn: Button
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
	print("A702 " + s)


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


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 9000:
		L("超时 st %d" % _st); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	var scr := _flow.screen
	if mode == "v8":
		_v8(scr)
		return false
	if mode == "old":
		match _st:
			0:
				if _f < 60: return false
				L("主菜单：有存档 %s" % str(_flow.has_save() if _flow.has_method("has_save") else "-"))
				_flow.continue_game(); _wait = 40; _st = 1
			1:
				if scr != GameFlow.Screen.META:
					if _f > 3000: L("读档后没回基地：屏 %d" % scr); _st = 99
					return false
				L("v6.85 的存档读进来：%s" % _state())
				_tab("logistics"); _wait = 20; _st = 2
			2:
				L("　　后勤小键 %s" % _subs())
				shot("old_logistics")
				_flow.save_meta(); _st = 99
			_:
				quit(0); return true
		return false
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
			L("新档：%s；后勤小键 %s" % [_state(), _subs()])
			var bk := _flow.meta.commissions
			for id in [&"legion_forge_token", &"society_first_survey", &"greylamp_check_scale"]: _flow.report_commission(id)
			for id in [&"society_identify_ore", &"society_copy_recipe"]:
				var d := Commissions.def(id)
				if not bk.taken().has(id): Commissions.take(bk, d, &"smith_shortsword", [&"smith_shortsword"])
				Commissions._complete(_flow.meta, d, _flow.items)
			var cd := Commissions.def(&"society_alchemy")
			var need := Commissions.required_tier(cd)
			while Alchemy.tier(_flow.meta) < need and bk.rep_of(&"society") < 1000: bk.rep["society"] = bk.rep_of(&"society") + 1
			var pd := Commissions.def(&"society_permit")
			if not bk.taken().has(pd.id): Commissions.take(bk, pd)
			Commissions._complete(_flow.meta, pd, _flow.items)
			_flow.sync_commissions(); _flow.save_meta()
			L("测试辅助：协会剧情和许可单记办成，声望补到《万物可分》要的 %d 档：%s；《万物可分》%s「%s」" % [need, _state(), bk.state_of(&"society_alchemy"), Commissions.why_not(bk, cd)])
			_flow.to_main_menu(); _wait = 30; _st = 3
		3:
			_flow.continue_game(); _wait = 40; _st = 4
		4:
			if scr != GameFlow.Screen.META: return false
			L("存档回主菜单再继续：%s" % _state())
			_tab("logistics"); _wait = 20; _st = 5
		5:
			L("真点「后勤」：小键 %s" % _subs())
			if not _ms()._sub_btns.has("alchemy"): L("没有「炼金」键"); _st = 99; return false
			_click(_ms()._sub_btns["alchemy"]); _wait = 20; _st = 6
		6:
			var lp = _ms().locked_page()
			L("真点「炼金」（没办《万物可分》）：说明板 %s：%s" % ["看得见" if lp != null and lp.is_visible_in_tree() else "看不见", _labels_under(lp) if lp != null else "-"])
			L("　　排版：%s" % _overflow(lp))
			shot("alchemy_locked")
			_tab("commissions"); _wait = 20; _st = 7
		7:
			_click(_named("Sub_story")); _wait = 20; _st = 8
		8:
			var tk := _named("Take_society_alchemy")
			L("剧情页《万物可分》：%s；【接下】%s" % [_labels_under(_named("Card_society_alchemy")), "灰" if tk != null and (tk as BaseButton).disabled else ("有" if tk != null else "没有")])
			if tk == null or (tk as BaseButton).disabled: _st = 9; return false
			_click(tk); _wait = 25; _st = 9
		9:
			var rp := _named("Report_society_alchemy")
			L("《万物可分》%s；【办理】%s" % [_flow.meta.commissions.state_of(&"society_alchemy"), "有" if rp != null else "没有"])
			if rp == null: _st = 99; return false
			_click(rp); _wait = 25; _st = 10
		10:
			L("真点【办理】后：%s；告示 %s" % [_state(), str(NoticeLayer.history().slice(0, 2).map(func(x): return x.get("text", "")))])
			for id in ["crystal_shards", "crystal_shards", "crystal_shards", "mist_crystal", "mist_crystal", "hardwood_plank", "knife", "quartz_cluster", "jimie_core_fire", "pale_shard", "pale_shard"]: _put(id)
			var shards := _flow.meta.warehouse.items().filter(func(i): return String((i as ItemInstance).def.id) == "crystal_shards")
			(shards[0] as ItemInstance).set_locked(true)
			if not _flow.meta.is_favorite(&"mist_crystal"): _flow.meta.toggle_favorite(&"mist_crystal")
			_flow.meta.last_carry = [{"id": "crystal_shards", "origin": [0, 0], "rot": 0}]
			_flow.meta.changed.emit()
			L("测试辅助放料：碎晶 ×3（锁一件、出征携带记一件）、雾晶 ×2（收藏）、硬木板、匕首、清明魔晶石、火之核（独一）、灰白色的金属碎片 ×2（宝物）")
			_tab("logistics"); _wait = 20; _st = 11
		11:
			_click(_ms()._sub_btns["alchemy"]); _wait = 25; _st = 12
		12:
			L("真点「炼金」：页上 %s；勾选模式 %s；【一键炼金】灰 %s「%s」" % [_labels_under(_ap()), str(_ms().alchemy_mode()), str((_named("AlchemyAuto") as BaseButton).disabled), (_named("AlchemyAuto") as Control).tooltip_text])
			L("　　排版：%s" % _overflow(_ap()))
			shot("alchemy_open")
			_picks = []
			var locked_uid := -1
			for i in _flow.meta.warehouse.items():
				var it := i as ItemInstance
				if String(it.def.id) == "crystal_shards" and it.is_locked_by_player(): locked_uid = it.uid
			for want in ["knife", "quartz_cluster", "jimie_core_fire", "pale_shard", "pale_shard"]:
				for i in _flow.meta.warehouse.items():
					var it := i as ItemInstance
					if String(it.def.id) == want and not _picks.has(it.uid): _picks.append(it.uid); break
			_picks.append(locked_uid)
			_st = 13
		13:
			if _picks.is_empty(): _wait = 15; _st = 14; return false
			var uid: int = _picks.pop_front()
			var r := _wh_rect(uid)
			var it := _flow.meta.warehouse.get_item(uid)
			if r.size == Vector2.ZERO: L("　　%s 在仓库页上找不到位置" % it.def.id); return false
			_mouse_at(r.get_center(), MOUSE_BUTTON_LEFT)
			L("　　真点仓库里的 %s%s → 勾上 %s；告示 %s" % [Names.of(it.def), "（锁着）" if it.is_locked_by_player() else "", "?", str(NoticeLayer.history().slice(0, 1).map(func(x): return x.get("text", "")))])
			_wait = 12
		14:
			var ap = _ap()
			var p: Dictionary = ap.preview()
			L("手动勾完：勾了 %s；预览 %s；页上 %s" % [str(_ms()._shelf.selected.keys().map(func(u): return String(_flow.meta.warehouse.get_item(int(u)).def.id))), str(p), _labels_under(ap)])
			L("　　红字「%s」；红圈 %d 个" % [(_named("Danger") as Label).text if _named("Danger") != null else "（没有红字）", _all_named("GuardRing").size()])
			L("　　排版：%s" % _overflow(ap))
			shot("manual_picked")
			_before = _inv(); _dust0 = _flow.meta.dust
			_click(_named("AlchemyGo")); _wait = 15; _st = 15
		15:
			L("真点【炼化】第一下：键上「%s」；尘 %d；告示 %s" % [(_named("AlchemyGo") as Button).text, _flow.meta.dust, str(NoticeLayer.history().slice(0, 1).map(func(x): return x.get("text", "")))])
			shot("manual_confirm")
			_click(_named("AlchemyGo")); _wait = 25; _st = 16
		16:
			L("再点一下：尘 %d → %d；仓库 %s" % [_dust0, _flow.meta.dust, _diff(_before, _inv())])
			var tp := _named("AlchemyTag") as OptionButton
			var idx := -1
			for i in tp.item_count:
				if not tp.is_item_separator(i) and String(tp.get_item_metadata(i)) == "material": idx = i
			L("筛选下拉 %d 项；真选「%s」" % [tp.item_count, tp.get_item_text(idx) if idx >= 0 else "-"])
			tp.select(idx); tp.item_selected.emit(idx)
			_wait = 20; _st = 40
		40:
			var ap = _ap()
			L("选了标签：一键计划 %s；【一键炼金】灰 %s" % [str(ap.auto_plan()), str((_named("AlchemyAuto") as BaseButton).disabled)])
			_click(_named("AlchemyAuto")); _wait = 20; _st = 41
		41:
			var ap = _ap()
			L("真点【一键炼金】：勾了 %s；预览 %s；页上 %s" % [str(_ms()._shelf.selected.keys().map(func(u): return String(_flow.meta.warehouse.get_item(int(u)).def.id))), str(ap.preview()), _labels_under(ap)])
			L("　　排版：%s" % _overflow(ap))
			shot("auto_picked")
			_before = _inv(); _dust0 = _flow.meta.dust
			_click(_named("AlchemyGo")); _wait = 15; _st = 42
		42:
			_click(_named("AlchemyGo")); _wait = 25; _st = 43
		43:
			L("真点【炼化】两下：尘 %d → %d；仓库 %s；留下的碎晶 %d 件、雾晶 %d 件" % [_dust0, _flow.meta.dust, _diff(_before, _inv()), _wh("crystal_shards"), _wh("mist_crystal")])
			shot("auto_done")
			_flow.meta.funds += 1000
			var r := SmithRecipeDef.find(_flow.smith_recipes, &"smith_shortsword")
			for key in r.inputs:
				for _i in int(r.inputs[key]): _put(String(key))
			L("测试辅助补料，打一把制式短剑：「%s」；%s" % [_flow.forge(&"smith_shortsword"), _state()])
			_flow.to_main_menu(); _wait = 30; _st = 17
		17:
			_flow.continue_game(); _wait = 40; _st = 18
		18:
			if scr != GameFlow.Screen.META: return false
			L("存档回主菜单再继续：%s" % _state())
			_st = 99
		_:
			quit(0); return true
	return false


func _mat_slots() -> Array:
	var o := []
	for n in _sp().recipe_scroll().find_children("*", "", true, false):
		if n is Control and (n as Control).is_visible_in_tree() and ("on_toggle" in n) and String(n.get("key")) != "":
			o.append(n)
	return o


func _lines() -> String:
	return "能补 %s" % str(_sp().dust_lines(_r, Smithy.have(_flow.meta, _r)))


func _v8(scr) -> void:
	match _st:
		0:
			if _f < 60: return
			_flow.continue_game(); _wait = 40; _st = 1
		1:
			if scr != GameFlow.Screen.META:
				if _f > 3000: L("读档后没回基地：屏 %d" % scr); _st = 99
				return
			var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://slots/1/meta.json"))
			L("v8 样本读进来：%s；图鉴 %s；战锤打造过 %s；皮甲打造过 %s；盘上存档 version %s" % [_state(), str(_flow.meta.codex), str(_flow.meta.has_forged(&"smith_warhammer")), str(_flow.meta.has_forged(&"smith_leather_armor")), str(raw.get("version", "?")) if raw != null else "?"])
			for c in _flow.tutorial_chapters(): _flow.meta.grant_unlock(c.hidden_by_unlock)
			L("测试辅助：样本没过教程，记教程章过了；委托簿露 %s" % str(_flow.commissions_visible()))
			var bk := _flow.meta.commissions
			for id in [&"legion_forge_token", &"society_first_survey", &"greylamp_check_scale"]: _flow.report_commission(id)
			for id in [&"society_identify_ore", &"society_copy_recipe"]:
				var d := Commissions.def(id)
				if bk.state_of(id) == &"done" or String(bk.state_of(id)) == "done": continue
				if not bk.taken().has(id): Commissions.take(bk, d, &"smith_shortsword", [&"smith_shortsword"])
				Commissions._complete(_flow.meta, d, _flow.items)
			var cd := Commissions.def(&"society_alchemy")
			while Alchemy.tier(_flow.meta) < Commissions.required_tier(cd) and bk.rep_of(&"society") < 1000: bk.rep["society"] = bk.rep_of(&"society") + 1
			for id in [&"society_permit", &"society_alchemy"]:
				var d := Commissions.def(id)
				if not bk.taken().has(id): Commissions.take(bk, d)
				Commissions._complete(_flow.meta, d, _flow.items)
			_flow.meta.dust += 500
			_flow.sync_commissions(); _flow.save_meta()
			var raw2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://slots/1/meta.json"))
			L("测试辅助：开放单、协会剧情、《万物可分》记办成，尘 +500：%s；存盘后 version %s、forged_recipes %s" % [_state(), str(raw2.get("version", "?")), str(raw2.get("forged_recipes", "?"))])
			_tab("logistics"); _wait = 20; _st = 2
		2:
			L("后勤小键 %s" % _subs())
			_click(_ms()._sub_btns["smithy"]); _wait = 20; _st = 3
		3:
			_r = SmithRecipeDef.find(_flow.smith_recipes, &"smith_warhammer")
			L("战锤：料 %s；会打 %s；铺子 %d 级 / 配方要 %d 级" % [str(_r.inputs), str(Smithy.knows(_flow.meta, _r)), Smithy.level(_flow.meta), _r.level])
			_click(_sp().group_key(String(_r.group))); _wait = 20; _st = 4
		4:
			if _sp().opened() != _r.id: _click(_sp().cell(_r.id)); _wait = 20
			_st = 5
		5:
			L("真点战锤（仓库没料）：%s；%s；可点料格 %s" % [_labels_under(_sp().recipe_scroll()).left(300), _lines(), str(_mat_slots().map(func(n): return String(n.get("key"))))])
			L("　　排版：%s" % _overflow(_sp().recipe_scroll()))
			shot("v8_warhammer_open")
			_keys = _mat_slots().map(func(n): return String(n.get("key")))
			_st = 6
		6:
			if _keys.is_empty(): _wait = 10; _st = 7; return
			var k: String = _keys.pop_front()
			for c in _mat_slots():
				if String(c.get("key")) == k: _click(c); L("　　真点料格 %s" % k)
			_wait = 15
		7:
			var fb = _sp().forge_button(_r.id)
			L("点完：用尘 %s；页上 %s；【打造】灰 %s" % [str(_sp().dust_choice()), _labels_under(_sp().recipe_scroll()).left(300), str((fb as BaseButton).disabled)])
			L("　　排版：%s" % _overflow(_sp().recipe_scroll()))
			shot("v8_warhammer_dust")
			_before = _inv(); _dust0 = _flow.meta.dust
			_click(fb); _wait = 25; _st = 8
		8:
			L("真点【打造】：仓库 %s；尘 %d → %d；告示 %s" % [_diff(_before, _inv()), _dust0, _flow.meta.dust, str(NoticeLayer.history().slice(0, 1).map(func(x): return x.get("text", "")))])
			var other := SmithRecipeDef.find(_flow.smith_recipes, &"smith_shortsword")
			L("对照：图鉴没亮的制式短剑 打造过 %s；dust_open %s" % [str(_flow.meta.has_forged(&"smith_shortsword")), str(Alchemy.dust_open(_flow.meta, other))])
			_st = 99
		_:
			quit(0)


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