## 255（作者 2026-10-26 定）：角色的短板（每人一条，和技能同一套构件）、随身之物（开局钉在棋盘上：自带底板、拿不下、丢不掉、不进仓库）、
## 棋盘缺格（透空、框沿轮廓走）；选角色屏三栏定宽、面板方块一行、技能 / 随身之物 / 短板同一种行、右栏题字 / 图例 / 首次赠包小签
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"


## 一个带缺格与随身之物的探针角色（照着 [param base] 抄）：7 × 7，四角与正中缺格，木棍横钉在第一行
static func _probe(base: CharacterDef) -> CharacterDef:
	var ch := base.duplicate(true) as CharacterDef
	ch.id = &"probe_255"
	ch.board_size = Vector2i(7, 7)
	ch.board_mask = [Vector2i(0, 0), Vector2i(6, 0), Vector2i(0, 6), Vector2i(6, 6), Vector2i(3, 3)] as Array[Vector2i]
	var fi := FixedItem.new()
	fi.id = &"wooden_stick"
	fi.origin = Vector2i(2, 0)
	fi.rot = 1
	ch.fixed_items = [fi] as Array[FixedItem]
	return ch


static func _pinned(board: GridInventory) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	for inst in board.items():
		if (inst as ItemInstance).is_pinned():
			out.append(inst)
	return out


static func run_flaws(t: TestCase) -> void:
	t.begin("255 §3.1：三人各一条短板（马库斯不懂药 / 安德烈乌斯身子薄 / 布鲁图斯回气慢），编进战斗规则、排在技能之后；开战时挂上对应的状态")
	var c := CS._content()
	var want := {&"marcus": [&"unschooled", "不懂药"], &"andreus": [&"thin_build", "身子薄"], &"brutus": [&"short_wind", "回气慢"]}
	for id in want:
		var ch := CS._character(c, id)
		t.not_null(ch.flaw, "%s 有短板" % id)
		if ch.flaw == null:
			continue
		t.eq(ch.flaw.id, want[id][0], "%s 的短板 id" % id)
		t.eq(String(ch.flaw_entry()["name"]), want[id][1], "%s 的短板名" % id)
		t.check(not ch.flaw.is_active(), "%s：短板是被动" % id)
		t.check(ch.combat_rules().size() > 0 and ch.combat_rules().back() == ch.flaw.rules[0], "%s：短板的规则编进战斗规则、排在最后" % id)
		t.check(not ch.skill_entries().any(func(e: Dictionary) -> bool: return String(e["name"]) == want[id][1]), "%s：技能那几条里不列短板" % id)
		var s := CS._start(c, ch)
		var me := s.compile_player()
		var node := CS._battle_node(s)
		var enemy := EnemyKit.spec_of(node.content, c.enemies, s.pool, c.items)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var result := BattleSim.run(me, enemy, rng, 30.0)
		var applied := 0
		for e in result.log:
			var be := e as BattleEvent
			if be.name == BattleEvent.STATUS_STACKED and be.side == 0 and String(be.payload.get("buff", "")) == String(want[id][0]):
				applied += 1
		t.eq(applied, 1, "%s：开战挂上「%s」一次" % [id, want[id][1]])


static func run_flaw_mechanics(t: TestCase) -> void:
	t.begin("255 §3.1：三种打折 —— 只截【药剂】的治疗（别的照常）、护甲上限乘 0.8、耐力低于两成时每秒回复减半")
	var spec := CombatantSpec.new()
	var base := StatSet.new()
	base.ensure(&"max_stamina").base = StatMath.from_float(50.0)
	base.ensure(&"regen_stamina").base = StatMath.from_float(4.0)
	base.ensure(&"max_armor").base = StatMath.from_float(50.0)
	spec.baseline = base
	spec.max_hp = StatMath.from_float(100.0)
	var rt := CombatantRuntime.from_spec(spec, 0)
	rt.resources.change(&"hp", -StatMath.from_float(60.0), BattleEvent.REASON_COST)
	var unschooled := load("res://data/buffs/unschooled.tres") as BuffDef
	var thin := load("res://data/buffs/thin_build.tres") as BuffDef
	var wind := load("res://data/buffs/short_wind.tres") as BuffDef
	rt.apply_buff(unschooled)
	var tags: Array[StringName] = [&"remedy"]
	t.eq(rt.heal(null, StatMath.from_float(20.0), BattleEvent.REASON_HEAL, tags), StatMath.from_float(10.0), "【药剂】的 20 点只回 10")
	t.eq(rt.heal(null, StatMath.from_float(20.0)), StatMath.from_float(20.0), "别的治疗照常 20")
	t.eq(rt.heal_kept(), StatMath.ONE, "每秒回血不截（只截某类道具的不碰回血）")
	var before := rt.resources.maximum(&"armor")
	t.eq(before, StatMath.from_float(50.0), "护甲上限 50")
	rt.apply_buff(thin)
	t.eq(rt.stat(&"max_armor"), StatMath.from_float(40.0), "身子薄：护甲上限 50 × 0.8 = 40")
	rt.apply_buff(wind)
	t.eq(rt.regen_kept(&"stamina"), StatMath.ONE, "耐力满着：回气不打折")
	rt.resources.change(&"stamina", -StatMath.from_float(45.0), BattleEvent.REASON_COST)
	t.eq(rt.regen_kept(&"stamina"), StatMath.from_float(0.5), "耐力 5 / 50（一成）：回气减半")
	t.eq(rt.regen_kept(&"hp"), StatMath.ONE, "别的资源不打折")
	t.check(Glossary.buff_effect_lines(unschooled).any(func(l: String) -> bool: return l.contains("药剂") and l.contains("50%")), "说明：%s" % [Glossary.buff_effect_lines(unschooled)])
	t.check(Glossary.buff_effect_lines(wind).any(func(l: String) -> bool: return l.contains("耐力低于 20%")), "说明：%s" % [Glossary.buff_effect_lines(wind)])


static func run_fixed_items_and_mask(t: TestCase) -> void:
	t.begin("255 §3.2 / §3.3：随身之物开局钉上（自带底板、拿不下、包压不上去、跟着这一局的存档走、开局屏摆盘不记它）；缺格不能用；撤离不带回")
	var c := CS._content()
	var ch := _probe(CS._character(c, &"marcus"))
	var board := GridInventory.new(ch.board_size, RunState.BOARD_ID, true)
	var pins := ch.shape_board(board, c.items)
	t.eq(pins.size(), 1, "钉上一件")
	var stick := pins[0]
	t.check(stick.is_pinned() and board.is_locked(stick.uid), "随身之物：钉着、锁着（不看扎根开关）")
	t.check(board.is_covered(Vector2i(2, 0)) and board.is_covered(Vector2i(3, 0)) and not board.is_covered(Vector2i(4, 0)), "它占的格自带底板（算被覆盖）")
	t.check(board.is_blocked(Vector2i(3, 3)) and not board.is_covered(Vector2i(3, 3)), "缺格不能用")
	t.eq(board.blocked_count(), 5, "五个缺格")
	var bag := ItemInstance.create(c.items.get_def(&"bag_leather"), 0)
	t.check(not board.place(bag, Vector2i(2, 0), 0), "包盖不到随身之物上")
	t.check(not board.place(ItemInstance.create(c.items.get_def(&"bag_leather"), 0), Vector2i(2, 2), 0), "包也盖不到缺格上")
	t.check(board.try_add(bag, true), "包绕开它们摆得下")
	t.eq(InventoryService.transfer_auto(board, stick.uid, GridInventory.new(Vector2i(5, 5))), false, "搬不走")
	t.eq(DragLayer.refused_notice(board, stick.uid), UiText.t("notice.pinned"), "按住它：「它是你的随身之物，拿不下来」")
	var acts: Array = ItemActions.pinned_guard(stick, [ItemActions.make(&"x", "x", func(): pass), ItemActions.bench(stick, board)])
	t.check(acts.all(func(a: ItemActions.Action) -> bool: return not a.enabled and a.reason == "随身之物"), "悬浮窗的按钮全灰，理由「随身之物」")
	t.check(not (load("res://ui/game/inventory_panel.gd")).can_bench(stick), "不能标不参战")
	var back := GridInventory.from_dict(board.to_dict(), c.items)
	t.eq(_pinned(back).size(), 1, "存档读回来还钉着（自带底板，不要包）")
	t.check(not RunState.layout_of(board).any(func(r: Dictionary) -> bool: return String(r["id"]) == "wooden_stick"), "开局屏摆盘不记它（角色开局自己钉）")
	t.check(ItemTooltip.describe(stick, board).contains(UiText.t("tip.pinned")), "悬浮窗最后一行灰小字")
	# 开局：钉在原位；撤离：不带回、不进仓库 / 图鉴
	var s := CS._start(c, ch)
	t.not_null(s, "开得了局")
	if s == null:
		return
	var run_pins := _pinned(s.board)
	t.eq(run_pins.size(), 1, "开局就钉在棋盘上")
	t.eq(run_pins[0].origin if not run_pins.is_empty() else Vector2i(-1, -1), Vector2i(2, 0), "原位")
	t.check(s.board.is_blocked(Vector2i(3, 3)), "开局的棋盘有缺格")
	s.phase = RunState.Phase.EXTRACTED
	var r := RunResult.settle(s)
	t.check(not r.carried.any(func(i: ItemInstance) -> bool: return i.is_pinned()), "撤离：随身之物不算带回")
	var m := MetaState.new()
	m.absorb(r)
	t.eq(int(m.codex.get("wooden_stick", 0)), 0, "不进图鉴")
	t.check(m.board == null or not m.board.items().any(func(i: ItemInstance) -> bool: return i.def.id == &"wooden_stick"), "不进带回来的棋盘")


static func run_importer(t: TestCase) -> void:
	t.begin("255 §3：导入器 —— 短板必填、棋盘最宽九格、缺格在盘内不重复、随身之物找得到 / 不是包 / 在盘内 / 不压缺格 / 不重叠")
	var c := CS._content()
	var ctx := ContentImporter.Context.new()
	for id in c.items.ids():
		ctx.items[id] = c.items.get_def(id)
	var flaw := {"type": "passive", "id": "f", "display_name": "f"}
	var ok := {"id": "p", "starting_bags": ["bag_leather"], "board_size": [7, 7], "flaw": flaw,
		"board_mask": [[0, 0], [3, 3]], "fixed_items": [{"id": "wooden_stick", "origin": [2, 0], "rot": 1}]}
	var r := ImportReport.new()
	var def := ContentImporter.import_character(ok, ctx, r)
	t.check(r.ok(), "合法：%s" % r.to_text())
	t.eq(def.board_mask.size(), 2, "缺格读进来")
	t.eq(def.fixed_items.size(), 1, "随身之物读进来")
	t.eq(def.fixed_items[0].origin if not def.fixed_items.is_empty() else Vector2i.ZERO, Vector2i(2, 0), "原位")
	var text := ContentExporter.to_json(ContentExporter.export_character(def))
	var again := ContentImporter.import_character(JSON.parse_string(text), ctx, ImportReport.new())
	t.eq(ContentExporter.to_json(ContentExporter.export_character(again)), text, "导出 → 导入 → 再导出逐字节相同")
	var bads := {
		"没短板": {"flaw": null},
		"棋盘十格宽": {"board_size": [10, 6]},
		"缺格出界": {"board_mask": [[7, 0]]},
		"缺格重复": {"board_mask": [[1, 1], [1, 1]]},
		"随身之物找不到": {"fixed_items": [{"id": "no_such", "origin": [0, 1]}]},
		"随身之物是包": {"fixed_items": [{"id": "bag_leather", "origin": [1, 1]}]},
		"随身之物出界": {"fixed_items": [{"id": "wooden_stick", "origin": [6, 1], "rot": 1}]},
		"随身之物压缺格": {"fixed_items": [{"id": "wooden_stick", "origin": [0, 0], "rot": 1}]},
		"两件重叠": {"fixed_items": [{"id": "wooden_stick", "origin": [2, 1], "rot": 1}, {"id": "wooden_stick", "origin": [3, 1], "rot": 1}]},
	}
	for why in bads:
		var d := ok.duplicate(true)
		for k in bads[why]:
			if bads[why][k] == null:
				d.erase(k)
			else:
				d[k] = bads[why][k]
		var rr := ImportReport.new()
		ContentImporter.import_character(d, ctx, rr)
		t.check(not rr.ok(), "拦下：%s" % why)


static func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


static func frame_select_screen(t: TestCase, root: Window) -> void:
	t.begin("255 §2：选角色屏 —— 三栏定宽（换 7 / 8 / 9 格的角色一个像素不动）、棋盘居中；面板方块一行；技能 → 随身之物 → 短板同一种行；题字 / 图例 / 首次赠包小签；卡装得下")
	Support.cleanup("setup255")
	var p := Support.paths("setup255")
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	_lay_out(game)
	var rects: Array = []
	var widths := {}
	for i in flow.characters.size():
		setup.choose_character(i)
		_lay_out(game)
		var ch: CharacterDef = setup.character()
		widths[ch.board_size.x] = true
		rects.append(setup._grooves.map(func(g: Control) -> Rect2: return Rect2(g.global_position, Vector2(g.size.x, 0))))
		var frame: Control = setup._preview_view.get_parent()
		var col: Control = setup._grooves[2]
		var left_pad: float = frame.global_position.x - col.global_position.x
		var right_pad: float = col.global_position.x + col.size.x - (frame.global_position.x + frame.size.x)
		t.check(absf(left_pad - right_pad) <= 1.0, "%s（%d 格）：棋盘在右栏里居中（左 %.0f / 右 %.0f）" % [ch.id, ch.board_size.x, left_pad, right_pad])
		t.eq((setup._stat_plaques as Array).map(func(sp: StatPlaque) -> String: return sp.caption), ["生命", "耐力", "回气", "体力"], "%s：面板方块一行四块" % ch.id)
		var entries: Array = setup._entries
		t.eq(entries.size(), ch.skill_entries().size() + 1, "%s：技能 %d 条 + 短板一条" % [ch.id, ch.skill_entries().size()])
		var last: Label = (entries.back() as Control).get_meta(&"name_label")
		t.eq(last.text, String(ch.flaw_entry()["name"]), "%s：短板永远最后" % ch.id)
		t.eq(last.theme_type_variation, UiTheme.LABEL_FLAW_NAME, "短板名铁灰")
		t.eq(((entries[0] as Control).get_meta(&"name_label") as Label).theme_type_variation, UiTheme.LABEL_SKILL_NAME, "技能名亮黄铜")
		t.check(entries.all(func(e: Control) -> bool: return e.get_child(0) is EntryIcon), "每行左端一个图标槽")
		t.eq(setup._board_title.text, "棋盘 %d × %d 格" % [ch.board_size.x, ch.board_size.y], "%s：题字（没缺格没随身之物只写尺寸）" % ch.id)
		t.eq(setup._legend.size(), 0, "%s：没有缺格 / 随身之物不出图例" % ch.id)
	t.check(widths.size() >= 2, "比过不止一种宽的棋盘：%s" % [widths.keys()])
	for i in range(1, rects.size()):
		t.eq(rects[i], rects[0], "三栏的位置与宽度换角色一个像素不动（第 %d 个）" % (i + 1))
	# 首次赠包：这一回第一次选的人亮着；换个存档再进来（已送过）就没有
	t.not_null(setup._gift_tag, "首次赠包小签：第一次选他时亮着")
	t.check(setup._gift_tag != null and (setup._gift_tag.get_child(0) as Label).text.begins_with("首次选他："), "写「首次选他：…进包架」")
	# 带缺格与随身之物的探针
	var probe := _probe(setup.character())
	setup._characters.append(probe)
	setup.choose_character(setup._characters.size() - 1)
	_lay_out(game)
	var entries2: Array = setup._entries
	t.eq(entries2.size(), probe.skill_entries().size() + 2, "技能 + 随身之物 + 短板")
	var pin_row: Control = entries2[entries2.size() - 2]
	t.check((pin_row.get_child(0) as EntryIcon).kind == EntryIcon.ITEM, "随身之物那行的图标是道具本体")
	var pin_texts: Array = pin_row.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	t.eq(pin_texts.back(), "随身：拿不下、丢不掉", "末尾灰小字（先功效后不可移动，作者 11:00）")
	t.eq(setup._board_title.text, "棋盘 7 × 7 格　可用 %d 格" % (49 - 5 - 2), "题字带可用格数")
	t.eq(setup._legend.size(), 2, "图例：不可用格、随身之物")
	t.check(setup._preview_view.get_parent() is BoardFrame and (setup._preview_view.get_parent() as BoardFrame).contour != null, "有缺格：框沿轮廓走")
	t.eq(setup._preview_view.inventory.bags().size(), 0, "预览只画形状不画包")
	t.eq(_pinned(setup.board).size(), 1, "第二页的棋盘上也钉着随身之物")
	t.check(not setup.carried().any(func(i: ItemInstance) -> bool: return i.is_pinned()), "它不算带入")
	# 卡装得下：中栏的板子底边不压到右下角那两颗石键上沿
	var mid: Control = setup._grooves[1]
	var bottom := mid.global_position.y + mid.size.y
	var vh := float(ProjectSettings.get_setting("display/window/size/viewport_height", 1000))
	t.check(bottom <= vh - setup.PAGE_MARGIN, "三样全有的卡装得下（底边 %.0f ≤ %.0f）" % [bottom, vh - setup.PAGE_MARGIN])
	game.queue_free()
	Support.cleanup("setup255")


## 容器的排布是延迟的，同一帧里手动排两遍（从外到里；第二遍吃到第一遍定下的最小尺寸）
static func _lay_out(n: Node) -> void:
	_sort(n)
	_sort(n)


static func _sort(n: Node) -> void:
	if n is Container:
		n.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_sort(c)
