## 游戏测试 v6.35～v6.42（报告 321～326 统一教程）：参数 <outdir> <模式>
##   skip：新档「新的游戏」→ 开场一问【不需要】→ 基地 → 主菜单「继续」→「开始探索」
##   mid ：新档 →【需要】→ 测试手段直接记成撤离 → 结算「继续」→ 基地出征页「跳过剩余教程」确认页（接着学 / 跳过）
##   mid2：同 mid，但先回主菜单「继续」再跳过
##   base：skip 之后看基地四个页签、集市货单、买料打造、科技
##   tour：同 mid，结算回基地后走基地导览（入库动作步、第 2 步收起、回主菜单再进基地重放、看完）
## 日志行以「TU」开头
extends CliTool

var out := "/tmp/claude-0/tut635"
var d: GameDirector = null
var f := 0
var step := 0
var lines: Array[String] = []
var mode := "skip"
var _rc := 0
var _bd := 0
var _bs := 0
var _tu := 0
var _tpass := 1
var _tseen := false
var _twait := 0


func run() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1 and not a[1].begins_with("--"): mode = a[1]
	DirAccess.make_dir_recursive_absolute(out)
	GameDirector.fades_allowed = false
	d = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(d)
	current_scene = d


func L(s: String) -> void:
	print("TU " + s)
	lines.append(s)


func shot(n: String) -> void:
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png("%s/%02d_%s.png" % [out, step, n])


func click(b: Control) -> void:
	var c := root.get_final_transform() * (b.get_global_rect().get_center())
	Input.warp_mouse(c)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = c
		e.global_position = c
		Input.parse_input_event(e)


func _button(text: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree() and b.text.strip_edges() == text:
			return b
	return null


func _btn_in(n: Node, key: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text == UiText.t(key) and (b as Button).is_visible_in_tree():
			return b
	return null


func _ids(list: Array) -> Array:
	return list.map(func(c): return String(c.id))


func _labels(n: Node) -> String:
	var t := []
	for l in n.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and (l as Label).text != "": t.append((l as Label).text)
	return " / ".join(t)


func _eb() -> Node:
	for n in root.find_children("*", "", true, false):
		if n is ExpeditionBoard and (n as Control).is_visible_in_tree(): return n
	return null


func _state(tag: String) -> void:
	var fl: GameFlow = d.flow
	var ruins := fl.chapter_of(&"slice_ruins")
	var tgt := fl.new_run_target()
	L("%s：档案 %s；屏 %s；局 %s；能列 %s；出战开 %s；切片地图 %s；场次 %d；解锁 %s；钱 %d；仓库 %d 件 %s；账本 %s" % [tag, String(fl.profile), GameFlow.Screen.keys()[fl.screen],
		String(fl.run.chapter.id) if fl.run != null else "无", str(_ids(fl.available_chapters())), String(tgt.id) if tgt != null else "开局屏",
		("「%s」" % fl.start_refusal(ruins, [], null)) if ruins != null else "无此章", fl.meta.runs, str(fl.meta.unlocks), fl.meta.funds,
		fl.meta.warehouse.item_count(), str(fl.meta.warehouse.items().map(func(i): return String(i.def.id))), str(fl.meta.tutorial_ledger)])


func _mid() -> bool:
	return mode.begins_with("mid") or mode == "tour"


func tick(_dt: float) -> bool:
	f += 1
	if f < 60 or f % 30 != 0:
		return false
	var fl: GameFlow = d.flow
	match step:
		0:
			_state("开机")
			shot("menu")
			var b := _button(UiText.t("menu.new_run"))
			L("主菜单「%s」：%s" % [UiText.t("menu.new_run"), "找到" if b != null else "没找到"])
			if b != null: click(b)
		1:
			_state("按新的游戏后")
			shot("after_new_game")
		2:
			if _mid():
				L("开场一问选【需要】（accept_tutorial），测试手段直接记成撤离（force_extract）")
				fl.accept_tutorial()
				fl.run.force_extract()
				fl._flush()
			else:
				L("开场一问选【不需要】（decline_tutorial）")
				fl.decline_tutorial()
		3:
			if _mid() and fl.screen == GameFlow.Screen.RESULT and _rc < 120:
				var rb = d.base()
				if rb.continue_button() != null and rb.continue_button().disabled and _rc < 15:
					_rc += 1
					return false
				if _rc < 100:
					_rc = 100
					var tr := root.find_children("TutorialReward", "", true, false)
					var txt := ""
					if not tr.is_empty():
						for l in (tr[0] as Node).find_children("*", "Label", true, false): txt += (l as Label).text + " / "
						txt += "图 %d 张" % (tr[0] as Node).find_children("*", "TextureRect", true, false).size()
					L("结算屏：「继续」键 %s；教程奖励小纸 %s" % ["有" if rb.continue_button() != null else "没有", "没有" if tr.is_empty() else "看得见 %s：%s" % [str((tr[0] as Control).is_visible_in_tree()), txt]])
					shot("result_paper")
				_rc += 1
				var ok: bool = rb.confirm_key(false)
				L("按结算「继续」第 %d 下：%s；屏 %s" % [_rc, str(ok), GameFlow.Screen.keys()[fl.screen]])
				return false
			if mode == "tour" and _tu < 99:
				_tour642()
				return false
			if mode == "base" and _bs < 6:
				_base640()
				return false
			if mode == "mid" and _bd < 5:
				_board638()
				return false
			_state("跳过以后" if not _mid() else "结算看完以后")
			if mode == "mid2":
				fl.to_main_menu()
				step += 1
				return false
			L("跳过前清单 skip_preview：%s" % str(fl.skip_preview()))
			var f0: int = fl.meta.funds
			var n0: int = fl.meta.warehouse.item_count()
			fl.skip_prologue()
			L("再跳过一次（skip_prologue）：钱 %d → %d；仓库 %d → %d 件" % [f0, fl.meta.funds, n0, fl.meta.warehouse.item_count()])
			if not _mid():
				fl.skip_prologue()
				L("第三次：钱 %d；仓库 %d 件" % [fl.meta.funds, fl.meta.warehouse.item_count()])
			L("仓库：%s" % str(fl.meta.warehouse.items().map(func(i): return String(i.def.id))))
			shot("base_after_skip")
			fl.to_main_menu()
		4:
			var b := _button(UiText.t("menu.continue"))
			L("回主菜单：「%s」%s" % [UiText.t("menu.continue"), "找到" if b != null else "没找到"])
			shot("menu_again")
			if b != null: click(b)
		5:
			if mode == "mid2" and _bd < 5:
				_board638()
				return false
			_state("按继续后")
			shot("after_continue")
			var eb := _eb()
			L("出征页木牌：%s" % ("没有" if eb == null else "「%s」" % (eb.start_btn as Button).text))
			if eb != null: click(eb.start_btn)
		6:
			_state("按开始探索后")
			shot("after_set_out")
		_:
			var fw := FileAccess.open("%s/log.txt" % out, FileAccess.WRITE)
			fw.store_string("\n".join(lines) + "\n")
			fw = null
			finish(0)
			return false
	step += 1
	return false


#region D1（v6.38）出征页教程木牌、跳过确认页
func _board638() -> void:
	var fl: GameFlow = d.flow
	var ms = d.base()
	var eb := _eb()
	match _bd:
		0:
			if eb == null:
				var tb := _button(UiText.t("meta.tab_expedition"))
				L("D638 进基地停在别的页签；点「%s」页签：%s" % [UiText.t("meta.tab_expedition"), "找到" if tb != null else "没找到"])
				if tb != null: click(tb)
				return
			L("D638 出征页木牌：「%s」" % _labels(eb))
			shot("board")
			var sb := eb.find_child("SkipTutorial", true, false)
			L("D638 「%s」键：%s；钱 %d" % [UiText.t("meta.tutorial_skip"), "找到" if sb != null else "没找到", fl.meta.funds])
			if sb != null: click(sb)
		1:
			var sk: Node = null
			for n in root.find_children("SkipTutorial", "", true, false):
				if not (n is Button): sk = n
			L("D638 确认页：开着 %s；内容「%s」" % [str(ms.skip_tutorial_open()), _labels(sk) if sk != null else "?"])
			shot("skip_confirm")
			var no := _button(UiText.t("skip_tut.no"))
			L("D638 「%s」：%s" % [UiText.t("skip_tut.no"), "找到" if no != null else "没找到"])
			if no != null: click(no)
		2:
			L("D638 按接着学后：确认页开着 %s；屏 %s；钱 %d；解锁 %s" % [str(ms.skip_tutorial_open()), GameFlow.Screen.keys()[fl.screen], fl.meta.funds, str(fl.meta.unlocks)])
			var sb := eb.find_child("SkipTutorial", true, false) if eb != null else null
			if sb != null: click(sb)
		3:
			var yes := _button(UiText.t("skip_tut.yes"))
			L("D638 再开确认页 %s，「%s」：%s" % [str(ms.skip_tutorial_open()), UiText.t("skip_tut.yes"), "找到" if yes != null else "没找到"])
			if yes != null: click(yes)
		4:
			L("D638 按跳过后：确认页开着 %s；屏 %s；钱 %d；仓库 %d 件 %s；解锁 %s；木牌「%s」" % [str(ms.skip_tutorial_open()), GameFlow.Screen.keys()[fl.screen], fl.meta.funds, fl.meta.warehouse.item_count(), str(fl.meta.warehouse.items().map(func(i): return String(i.def.id))), str(fl.meta.unlocks), _labels(eb) if eb != null else "没有"])
			shot("after_skip_board")
	_bd += 1
#endregion


#region D2（v6.40 / v6.41）切片基地
func _base640() -> void:
	var fl: GameFlow = d.flow
	var ms = d.base()
	match _bs:
		0:
			var tabs := []
			for k in ["meta.tab_expedition", "meta.tab_warehouse", "meta.tab_logistics", "meta.tab_shelf"]:
				tabs.append("%s%s" % [UiText.t(k), "✓" if _button(UiText.t(k)) != null else "✗"])
			L("D640 基地页签：%s" % str(tabs))
			var lv := Market.level(fl.meta)
			L("D640 集市级数 %d；规矩 allowed_ids %s" % [lv, str(fl.market().allowed_ids)])
			for st in Market.stalls():
				L("D640 摊 %s：能卖 %s" % [String(st.id), str(Market.catalogue(fl.market(), fl.items, st, maxi(lv, 1)))])
			L("D640 货架现货：%s" % str(fl.meta.market_stock.map(func(e): return String(e["id"]))))
			L("D640 铁匠配方：%s" % str(fl.smith_recipes.map(func(r): return String(r.id))))
			L("D640 科技：%s" % str(fl.tech_defs.map(func(t): return "%s(%s)" % [String(t.id), String(t.tree)])))
			L("D640 见识 %d" % fl.meta.insight)
			var lv2 := maxi(lv, 1)
			for r in fl.smith_recipes:
				var buys := []
				for mid in r.inputs.keys():
					for k in int(r.inputs[mid]):
						var got := "无摊"
						for st in Market.stalls():
							if Market.catalogue(fl.market(), fl.items, st, lv2).has(StringName(mid)):
								var why := fl.buy_listed(st.id, StringName(mid))
								got = "%s:%s" % [String(st.id), "买到" if why == "" else why]
								break
						buys.append("%s→%s" % [String(mid), got])
				var fw := fl.forge(r.id)
				L("D641 配方 %s：买料 %s；打造 %s；钱 %d" % [String(r.id), str(buys), "成" if fw == "" else fw, fl.meta.funds])
			ms.show_tab("logistics")
		1:
			shot("logistics")
		2:
			ms.show_tab("shelf")
		3:
			shot("shelf")
			ms.show_tab("tech")
		4:
			shot("tech")
			var tp = ms.tech_panel()
			if tp != null:
				var ids := []
				for t in TechDef.TREES:
					tp.show_tree(t)
					ids.append("%s:%s" % [String(t), str(tp.tree().defs.map(func(x): return String(x.id)))])
				L("D640 科技页：%s" % str(ids))
		5:
			ms.show_tab("expedition")
	_bs += 1
#endregion


#region D3（v6.42）基地导览
func _tour642() -> void:
	var fl: GameFlow = d.flow
	var ms = d.base()
	var t: CoachOverlay = ms.tour() if ms != null and ms.has_method("tour") else null
	if _tu == 50:     # 收起后：回主菜单再「继续」进基地
		fl.to_main_menu()
		_tu = 51
		return
	if _tu == 51:
		fl.continue_game()
		L("T642 回主菜单再按继续：屏 %s" % GameFlow.Screen.keys()[fl.screen])
		_tu = 0
		_tpass = 2
		_tseen = false
		_twait = 0
		return
	if t == null:
		_twait += 1
		if not _tseen and _twait < 8:
			return
		L("T642 第 %d 回：导览%s；coach_seen 有 base_tour %s；仓库 %d 件；待入库 %s" % [_tpass, "没出现" if not _tseen else "收掉了", str(fl.meta.coach_seen.has("base_tour")), fl.meta.warehouse.item_count(), str(fl.meta.has_pending_board())])
		shot("tour_end_%d" % _tpass)
		_tu = 50 if (_tpass == 1 and _tseen) else 99
		return
	if not _tseen:
		_tseen = true
		L("T642 第 %d 回导览出现：%d 步 %s" % [_tpass, t.steps.size(), str(t.steps.map(func(x): return String(x.get("target", ""))))])
	var tgt := String(t.steps[t.index].get("target", "")) if t.index >= 0 and t.index < t.steps.size() else "?"
	L("T642 第 %d/%d 步 [%s] 等动作 %s：%s" % [t.index + 1, t.steps.size(), tgt, str(t.waiting()), t.line_text()])
	shot("tour_%d_%d_%s" % [_tpass, t.index + 1, tgt])
	if t.waiting():
		var sb := _button(UiText.t("wh.store_all"))
		L("T642 动作步：点【%s】%s" % [UiText.t("wh.store_all"), "找到" if sb != null else "没找到"])
		if sb != null: click(sb)
		return
	if _tpass == 1 and t.index == 1:
		var hb := _btn_in(t, "coach.hide")
		L("T642 第 2 步按【收起】：%s" % ("找到" if hb != null else "没找到"))
		if hb != null: click(hb)
		return
	var ok := _btn_in(t, "coach.ok")
	if ok != null: click(ok)
#endregion
