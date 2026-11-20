extends SceneTree
## 游戏测试 v6.71（报告 347）：参数 <outdir>
## 一、仓库：测试辅助放雾晶、烟晶、棱晶、紫晶柱各一件 → 真点「仓库」页签 → 鼠标逐件悬停，记悬浮窗的字、截图
## 二、铁匠铺法杖线（真鼠标点格、点【打造】）：测试辅助把铁匠铺升到 3 级、法杖工艺点到 3 级、给金币；
##   每一步只往仓库补一样东西，再看打造界面的素材行和能不能打：
##   法师杖：火焰晶石 ×2 + 银锭 + 木棍（没有晶 ≥优良）→ 加碎晶 → 加雾晶 → 打
##   魔导杖：火焰魔晶石 + 铁木枝 + 秘银锭 + 烟晶（优良，不够稀有）→ 加棱晶 → 打
##   大魔导杖：火焰魔晶核 + 秘银锭 ×2 + 硬木板 ×2 + 棱晶（稀有，不够史诗）→ 加紫晶柱 → 打
var out := ""
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _shots := 0
var _plan: Array = []
var _pi := 0
var _hov: Array = []
var _hi := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func L(s: String) -> void:
	print("S671 " + s)


func shot(n: String) -> void:
	_shots += 1
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/staff_%02d_%s.png" % [out, _shots, n])


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
	_mouse_at(b.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)


func _btn_has(subs: Array) -> BaseButton:
	for n in root.find_children("*", "BaseButton", true, false):
		if not (n as Control).is_visible_in_tree() or not (n is Button): continue
		var t := (n as Button).text.strip_edges()
		for s in subs:
			if t != "" and t.contains(String(s)): return n
	return null


func _ms() -> Node:
	return _game.base()


func _wh(id: String) -> int:
	var n := 0
	for it in _flow.meta.warehouse.items():
		if String((it as ItemInstance).def.id) == id: n += 1
	return n


func _put(id: String, k: int = 1) -> int:
	var d := _flow.items.get_def(StringName(id))
	var uid := -1
	for i in k:
		var it := ItemInstance.create(d, 0)
		it.uid = _flow.meta.allocate_uid()
		if _flow.meta.warehouse.try_add(it): uid = it.uid
	return uid


func _smithy() -> Control:
	for n in root.find_children("*", "", true, false):
		if n is Control and n.get_script() != null and String(n.get_script().resource_path).ends_with("smithy_panel.gd") and (n as Control).is_visible_in_tree(): return n
	return null


func _tip_text() -> String:
	var o := []
	for n in root.find_children("*", "", true, false):
		if n is HoverTip:
			for l in n.find_children("*", "", true, false):
				if (l is Label or l is RichTextLabel) and (l as Control).is_visible_in_tree():
					var t: String = (l as RichTextLabel).get_parsed_text() if l is RichTextLabel else (l as Label).text
					if t.strip_edges() != "": o.append(t.strip_edges().replace("\n", " ⏎ "))
	return " | ".join(o) if not o.is_empty() else "（没有悬浮窗）"


func _item_global_rect(uid: int) -> Rect2:
	for n in root.find_children("*", "", true, false):
		if n is ContainerView and (n as Control).is_visible_in_tree():
			var cv := n as ContainerView
			var cont = cv.container()
			if cont != null and cont.has_method("get_item") and cont.get_item(uid) != null:
				var r := cv.item_rect(uid)
				if r.size != Vector2.ZERO: return Rect2(cv.get_global_rect().position + r.position, r.size)
	return Rect2()


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
			_flow.start_new_game(); _st = 1
		1:
			var b = _game.base()
			if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open():
				b.decline_tutorial(); _wait = 30; _st = 2
			elif _f > 240:
				_flow.decline_tutorial(); _wait = 30; _st = 2
		2:
			if _flow.screen != GameFlow.Screen.META: return false
			_hov = []
			if _flow.meta.commissions.get("gated") != null and _flow.meta.commissions.gated:
				_flow.meta.commissions.gated = false
				L("测试辅助：v6.72 起新档的铁匠铺要剧情开放，这里直接记成不门控")
			for id in ["mist_crystal", "smoky_crystal", "prism_crystal", "amethyst_pillar"]:
				_hov.append([id, _put(id)])
			_ms()._refresh()
			L("测试辅助：仓库放雾晶、烟晶、棱晶、紫晶柱各一件")
			_click(_btn_has([UiText.t("meta.tab_warehouse")])); _wait = 25; _st = 3
		3:
			if _hi >= _hov.size():
				shot("warehouse_crystals"); _st = 5; return false
			var r := _item_global_rect(int(_hov[_hi][1]))
			if r.size == Vector2.ZERO: L("%s：仓库里找不到画的位置" % _hov[_hi][0]); _hi += 1; return false
			_hover_at(Vector2(5, 5)); _wait = 15; _st = 30
		30:
			var r := _item_global_rect(int(_hov[_hi][1]))
			_hover_at(r.get_center()); _wait = 40; _st = 4
		4:
			var id: String = _hov[_hi][0]
			var d := _flow.items.get_def(StringName(id))
			L("悬停 %s（%s，%d 格，%s）：%s" % [Names.of(d), id, ItemVolume.cells_of(d), "说明空" if d.description == "" else "说明「%s」" % d.description, _tip_text()])
			shot("hover_%s" % id)
			_hi += 1; _st = 3
		5:
			_hover_at(Vector2(5, 5))
			var m := _flow.meta
			m.facility_levels[Smithy.ID] = 3
			m.tech_levels[&"staffcraft"] = 3
			m.funds = 5000
			for id in ["mist_crystal", "smoky_crystal", "prism_crystal", "amethyst_pillar"]:
				for it in m.warehouse.items():
					if String((it as ItemInstance).def.id) == id: m.warehouse.remove((it as ItemInstance).uid); break
			L("测试辅助：铁匠铺 %d 级；法杖工艺 %d 级；金币 5000；仓库里的晶石先拿走" % [Smithy.level(m), TechService.level(m, &"staffcraft")])
			_put("fire_crystal_low", 2); _put("silver_ingot"); _put("wooden_stick")
			_plan = [
				[&"smith_mage_staff", "", "火焰晶石 ×2 + 银锭 + 木棍"],
				[&"smith_mage_staff", "crystal_shards", "加碎晶"],
				[&"smith_mage_staff", "mist_crystal", "加雾晶", true],
				[&"smith_magus_staff", "fire_crystal,ironwood_branch,mithril_ingot,smoky_crystal", "火焰魔晶石 + 铁木枝 + 秘银锭 + 烟晶"],
				[&"smith_magus_staff", "prism_crystal", "加棱晶", true],
				[&"smith_grand_magus_staff", "fire_crystal_high,mithril_ingot,mithril_ingot,hardwood_plank,hardwood_plank,prism_crystal", "火焰魔晶核 + 秘银锭 ×2 + 硬木板 ×2 + 棱晶"],
				[&"smith_grand_magus_staff", "amethyst_pillar", "加紫晶柱", true],
			]
			_ms()._refresh()
			_click(_btn_has([UiText.t("meta.tab_logistics")])); _wait = 20; _st = 6
		6:
			_click(_ms().sub_tab_buttons("logistics").get("smithy")); _wait = 25; _st = 7
		7:
			if _pi >= _plan.size():
				_st = 99; return false
			var p: Array = _plan[_pi]
			for id in String(p[1]).split(",", false): _put(id)
			var sp = _smithy()
			if sp == null: L("铁匠铺没开"); quit(1); return true
			sp.rebuild()
			var r := SmithRecipeDef.find(_flow.smith_recipes, p[0])
			var gk = sp.group_key(r.group)
			if gk != null and sp.selected_group() != r.group:
				_click(gk); _wait = 15; return false
			if sp.opened() != p[0]:
				_click(sp.cell(p[0])); _wait = 20
			_st = 8
		8:
			var p: Array = _plan[_pi]
			var sp = _smithy()
			if sp.opened() != p[0]:
				_click(sp.cell(p[0])); _wait = 20; return false
			var sc = sp.recipe_scroll()
			var fk: Button = sc.forge_key
			L("%s（%s）：素材 %s；能打吗「%s」；【打造】灰 %s" % [String(p[0]).trim_prefix("smith_"), p[2], str(sc.material_lines()), Smithy.can_forge(_flow.meta, SmithRecipeDef.find(_flow.smith_recipes, p[0]), _flow.items), str(fk.disabled)])
			shot("%s_%d" % [String(p[0]).trim_prefix("smith_"), _pi])
			if p.size() > 3 and p[3]:
				L("　　真点【%s】；之前金币 %d" % [fk.text, _flow.meta.funds])
				_click(fk); _wait = 25; _st = 9
			else:
				_pi += 1; _st = 7
		9:
			var p: Array = _plan[_pi]
			var r := SmithRecipeDef.find(_flow.smith_recipes, p[0])
			var left := []
			for id in ["fire_crystal_low", "crystal_shards", "mist_crystal", "smoky_crystal", "prism_crystal", "amethyst_pillar", "hardwood_plank", "mithril_ingot"]:
				left.append("%s %d" % [Names.of(_flow.items.get_def(StringName(id))), _wh(id)])
			L("　　打完：仓库里 %s %d 件；金币 %d；剩 %s" % [Names.of(_flow.items.get_def(r.output)), _wh(String(r.output)), _flow.meta.funds, "、".join(left)])
			_pi += 1; _st = 7
		_:
			quit(0); return true
	return false
