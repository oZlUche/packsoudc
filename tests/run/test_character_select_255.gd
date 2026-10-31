## 255（作者 2026-10-26 定）：角色的短板（每人一条，和技能同一套构件）、随身之物（开局钉在棋盘上：自带底板、拿不下、丢不掉、不进仓库）、
## 棋盘缺格（透空、框沿轮廓走）；选角色屏三栏定宽、面板方块一行、技能 / 随身之物 / 短板同一种行、右栏题字 / 图例 / 首次赠包小签
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"


## 一个带缺格、随身之物与短板的探针角色（照着 [param base] 抄）：7 × 7，四角与正中缺格，木棍横钉在第一行
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
	var flaw := PassiveSkill.new()     # 补充三：短板选填，探针带一条看那一行
	flaw.id = &"probe_flaw"
	flaw.display_name = "探针短板"
	ch.flaw = flaw
	return ch


static func _pinned(board: GridInventory) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	for inst in board.items():
		if (inst as ItemInstance).is_pinned():
			out.append(inst)
	return out


## 补充三（作者 2026-10-26 13:59「我并不认为给每个角色设计短板是必须的……短板是用于改变游玩决策的设定，不要盲目的添加」）：
## 三人的短板撤掉；短板选填，有的照旧编进规则、排在技能之后
static func run_flaws(t: TestCase) -> void:
	t.begin("255 补充三：初始三人没有短板（开局不挂任何短板状态）；短板选填，有的照旧编进战斗规则、排在最后")
	var c := CS._content()
	for id in [&"marcus", &"andreus", &"brutus"]:
		var ch := CS._character(c, id)
		t.is_null(ch.flaw, "%s 没有短板" % id)
		t.check(ch.flaw_entry().is_empty(), "%s：卡上没有短板那一行" % id)
		t.eq(ch.traits().size(), ch.skills.size(), "%s：特性只有技能" % id)
		var s := CS._start(c, ch)
		var me := s.compile_player()
		var node := CS._battle_node(s)
		var enemy := EnemyKit.spec_of(node.content, c.enemies, s.pool, c.items)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var result := BattleSim.run(me, enemy, rng, 30.0)
		var gone := 0
		for e in result.log:
			var be := e as BattleEvent
			if be.name == BattleEvent.STATUS_STACKED and be.side == 0 and String(be.payload.get("buff", "")) in ["unschooled", "thin_build", "short_wind"]:
				gone += 1
		t.eq(gone, 0, "%s：开战不挂任何短板状态" % id)
		var skill_rules := 0
		for sk in ch.skills:
			skill_rules += (sk as RunSkill).rules.size()
		t.eq(ch.combat_rules().size(), skill_rules, "%s：战斗规则只来自技能" % id)
	for gone in ["unschooled", "thin_build", "short_wind"]:
		t.check(not ResourceLoader.exists("res://data/buffs/%s.tres" % gone), "撤掉的短板状态 %s 不在了" % gone)
		t.check(not ResourceLoader.exists("res://assets/ui/effects/%s.png" % gone), "它的效果栏图标也撤了")
	# 选填的短板：有就照旧排在技能之后、编进战斗规则
	var probe := CS._character(c, &"andreus").duplicate(true) as CharacterDef
	var flaw := PassiveSkill.new()
	flaw.id = &"probe_flaw"
	flaw.display_name = "探针短板"
	probe.flaw = flaw
	t.eq(probe.traits().back(), flaw, "有短板：特性里排最后")
	t.eq(String(probe.flaw_entry()["name"]), "探针短板", "卡上那一行写它的名")


## 短板用过的三种打折还在构件里（以后给确实改变决策的角色用）：只截某类道具的治疗、护甲上限按比例、耐力低时耐力回复减半
static func run_flaw_mechanics(t: TestCase) -> void:
	t.begin("255 §3.1：三种打折构件 —— 只截【药剂】的治疗（别的照常）、护甲上限乘 0.8、耐力低于两成时每秒回复减半")
	var spec := CombatantSpec.new()
	var base := StatSet.new()
	base.ensure(&"max_stamina").base = StatMath.from_float(50.0)
	base.ensure(&"regen_stamina").base = StatMath.from_float(4.0)
	base.ensure(&"max_armor").base = StatMath.from_float(50.0)
	spec.baseline = base
	spec.max_hp = StatMath.from_float(100.0)
	var rt := CombatantRuntime.from_spec(spec, 0)
	rt.resources.change(&"hp", -StatMath.from_float(60.0), BattleEvent.REASON_COST)
	var ctx := ContentImporter.Context.new()
	var unschooled := ContentImporter.import_buff({"id": "probe_heal_cut", "display_name": "截药", "is_debuff": true, "heal_cut": 50, "heal_cut_tags": ["remedy"]}, ctx, ImportReport.new())
	var thin := ContentImporter.import_buff({"id": "probe_thin", "display_name": "薄甲", "is_debuff": true, "mods": [{"stat": "max_armor", "mode": "MULT", "amount": -20.0}]}, ctx, ImportReport.new())
	var wind := ContentImporter.import_buff({"id": "probe_wind", "display_name": "喘", "is_debuff": true, "regen_cut": {"stamina": 50}, "regen_cut_below": 20}, ctx, ImportReport.new())
	rt.apply_buff(unschooled)
	var tags: Array[StringName] = [&"remedy"]
	t.eq(rt.heal(null, StatMath.from_float(20.0), BattleEvent.REASON_HEAL, tags), StatMath.from_float(10.0), "【药剂】的 20 点只回 10")
	t.eq(rt.heal(null, StatMath.from_float(20.0)), StatMath.from_float(20.0), "别的治疗照常 20")
	t.eq(rt.heal_kept(), StatMath.ONE, "每秒回血不截（只截某类道具的不碰回血）")
	var before := rt.resources.maximum(&"armor")
	t.eq(before, StatMath.from_float(50.0), "护甲上限 50")
	rt.apply_buff(thin)
	t.eq(rt.stat(&"max_armor"), StatMath.from_float(40.0), "护甲上限 50 × 0.8 = 40")
	rt.apply_buff(wind)
	t.eq(rt.regen_kept(&"stamina"), StatMath.ONE, "耐力满着：耐力回复不打折")
	rt.resources.change(&"stamina", -StatMath.from_float(45.0), BattleEvent.REASON_COST)
	t.eq(rt.regen_kept(&"stamina"), StatMath.from_float(0.5), "耐力 5 / 50（一成）：耐力回复减半")
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
	t.begin("255 §3：导入器 —— 短板选填（补充三）、棋盘最宽九格、缺格在盘内不重复、随身之物找得到 / 不是包 / 在盘内 / 不压缺格 / 不重叠")
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
	var no_flaw := ok.duplicate(true)
	no_flaw.erase("flaw")
	var rn := ImportReport.new()
	t.is_null(ContentImporter.import_character(no_flaw, ctx, rn).flaw, "没写短板 = 没有")
	t.check(rn.ok(), "补充三：没短板也合法：%s" % rn.to_text())
	t.eq(def.board_mask.size(), 2, "缺格读进来")
	t.eq(def.fixed_items.size(), 1, "随身之物读进来")
	t.eq(def.fixed_items[0].origin if not def.fixed_items.is_empty() else Vector2i.ZERO, Vector2i(2, 0), "原位")
	var text := ContentExporter.to_json(ContentExporter.export_character(def))
	var again := ContentImporter.import_character(JSON.parse_string(text), ctx, ImportReport.new())
	t.eq(ContentExporter.to_json(ContentExporter.export_character(again)), text, "导出 → 导入 → 再导出逐字节相同")
	var bads := {
		"棋盘十格宽": {"board_size": [10, 6]},
		"缺格出界": {"board_mask": [[7, 0]]},
		"缺格重复": {"board_mask": [[1, 1], [1, 1]]},
		"随身之物找不到": {"fixed_items": [{"id": "no_such", "origin": [0, 1]}]},
		"随身之物是包": {"fixed_items": [{"id": "bag_leather", "origin": [1, 1]}]},
		"缺格对角相连": {"board_mask": [[1, 1], [2, 2]]},
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


static func run_contour(t: TestCase) -> void:
	t.begin("255 §3.3：缺格棋盘的框按拼件规则拼（美术 11:21）—— 直边 → 凹角 → 凸角，格 60、框厚 20")
	var all := func(_c: Vector2i) -> bool: return true
	var names := func(ps: Array[Dictionary]) -> Array: return ps.map(func(p: Dictionary) -> String: return String(p["name"]))
	var plain: Array = names.call(BoardContour.pieces(Vector2i(2, 2), all))
	t.eq(plain.filter(func(n: String) -> bool: return n.begins_with("edge")).size(), 8, "2 × 2 整块：八段直边")
	t.eq(plain.filter(func(n: String) -> bool: return n.begins_with("outer")).size(), 4, "四个凸角")
	t.check(not plain.any(func(n: String) -> bool: return n.begins_with("inner")), "没有凹角")
	t.eq(BoardContour.pieces(Vector2i(2, 2), all).back()["rect"], Rect2(120, 120, 20, 20), "右下凸角贴在 (120, 120)")
	var mask := {Vector2i(0, 0): true, Vector2i(6, 0): true, Vector2i(0, 6): true, Vector2i(6, 6): true, Vector2i(3, 3): true}
	var usable := func(c: Vector2i) -> bool: return not mask.has(c)
	var ps := BoardContour.pieces(Vector2i(7, 7), usable)
	var probe: Array = names.call(ps)
	t.eq(probe.filter(func(n: String) -> bool: return n.begins_with("inner")).size(), 8, "四角缺格各一个凹角、正中的洞四个")
	t.check(probe.has("inner_tl") and probe.has("inner_br"), "凹角按缺格相对顶点的方向取名")
	var order: Array = probe.map(func(n: String) -> int: return BoardContour.ORDER.find(n.get_slice("_", 0)))
	var sorted := order.duplicate()
	sorted.sort()
	t.eq(order, sorted, "顺序：直边 → 凹角 → 凸角")
	t.check(ps.any(func(p: Dictionary) -> bool: return p["name"] == "inner_tl" and p["rect"] == Rect2(40, 40, 20, 20)), "左上缺格的凹角在顶点 (60, 60) 的左上")
	t.check(BoardContour.pinch_points(Vector2i(7, 7), usable).is_empty(), "探针形状拼得出")
	t.eq(BoardContour.pinch_points(Vector2i(3, 3), func(c: Vector2i) -> bool: return c != Vector2i(1, 1) and c != Vector2i(2, 2)), [Vector2i(2, 2)] as Array[Vector2i], "对角相连的顶点挑出来")


## 还没出图标的技能（先画通用纹样占位）；256 的偷袭 / 求饶 15:49 定稿换上了
const ART_PENDING := []


## 美术 2026-10-26 11:54 定稿换上：三人看得见的技能（主动的藏着）各有自己的图标、短板章是裂纹、随身钉、首次赠包签、缺格框十二块拼件都在
static func run_art(t: TestCase) -> void:
	t.begin("255 补充一：选角色屏换上美术定稿 —— 技能图标、短板裂纹章、随身钉（大小两版）、首次赠包签、缺格框十二块拼件")
	var c := CS._content()
	for id in [&"marcus", &"andreus", &"brutus"]:
		var ch := CS._character(c, id)
		for sk in ch.skills:
			if sk.shown_to_player() and not ART_PENDING.has(sk.id):
				t.check(EntryIcon.has_own_art(sk), "%s 的技能 %s 有自己的图标" % [id, sk.id])
	var flaw := EntryIcon.flaw()
	t.not_null(flaw.texture, "短板章用裂纹图")
	flaw.free()
	for n in ["tip/pin_badge", "tip/pin_badge_2x"]:
		t.not_null(UiTheme.art_cached(n), "随身钉 %s" % n)
	var tag := GiftTag.make("首次选他：x")
	t.check(tag.has_art(), "首次赠包签用定稿九宫格")
	tag.free()
	for k in ["t", "r", "b", "l"]:
		t.not_null(UiTheme.art_cached(BoardFrame.MASK_DIR + "edge_" + k), "直边 edge_%s" % k)
	for k in ["tl", "tr", "bl", "br"]:
		t.not_null(UiTheme.art_cached(BoardFrame.MASK_DIR + "inner_" + k), "凹角 inner_%s" % k)
		t.not_null(UiTheme.art_cached(BoardFrame.MASK_DIR + "outer_" + k), "凸角 outer_%s" % k)


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
		rects.append(setup._grooves.map(func(g: Control) -> Rect2: return g.get_global_rect()))     # 补充一（游戏测试 v4.48）：高也算
		var frame: Control = setup._preview_view.get_parent()
		var col: Control = setup._grooves[2]
		var left_pad: float = frame.global_position.x - col.global_position.x
		var right_pad: float = col.global_position.x + col.size.x - (frame.global_position.x + frame.size.x)
		t.check(absf(left_pad - right_pad) <= 1.0, "%s（%d 格）：棋盘在右栏里居中（左 %.0f / 右 %.0f）" % [ch.id, ch.board_size.x, left_pad, right_pad])
		t.eq((setup._stat_plate as StatSealPlate).captions(), ["生命", "耐力", "耐力回复", "体力"], "%s：铭牌里四格属性" % ch.id)
		var entries: Array = setup._entries
		var pins := ch.fixed_items.size()     # 256：马库斯带军功牌
		t.eq(entries.size(), ch.skill_entries().size() + pins, "%s：技能 %d 条 + 随身之物 %d 行，没有短板那一行（补充三）" % [ch.id, ch.skill_entries().size(), pins])
		if not entries.is_empty():     # 256：布鲁图斯没有技能，卡上只有面板与首次赠包
			var skill_name := (entries[0] as Control).get_meta(&"name_label") as Label
			t.eq(skill_name.get_theme_color("font_color"), UiTheme.SKILL_NAME_INK, "选人页 B：浅底上技能名朱褐")
		t.check(entries.all(func(e: Control) -> bool: return e.get_child(0) is EntryIcon), "每行左端一个图标槽")
		if pins == 0 and ch.board_mask.is_empty():
			t.check(not "_board_title" in setup, "%s：作者 10-31 棋盘下面不写尺寸" % ch.id)
			t.eq(setup._legend.size(), 0, "%s：没有缺格 / 随身之物不出图例" % ch.id)
		else:
			t.check(setup._legend.size() > 0, "%s：有随身之物出图例" % ch.id)
	t.check(widths.size() >= 2, "比过不止一种宽的棋盘：%s" % [widths.keys()])
	for i in range(1, rects.size()):
		t.eq(rects[i], rects[0], "三栏的位置与宽度换角色一个像素不动（第 %d 个）" % (i + 1))
	# 补充一（游戏测试 v4.49）：英文的名牌说明与技能句更长 —— 换成英文，三栏也一个像素不动
	UiText.lang = "en"
	for i in flow.characters.size():
		setup.choose_character(i)
		_lay_out(game)
		t.eq(setup._grooves.map(func(g: Control) -> Rect2: return g.get_global_rect()), rects[0], "英文：%s 的三栏和中文一样大" % setup.character().id)
	UiText.lang = "zh"
	setup.choose_character(flow.characters.size() - 1)
	_lay_out(game)
	# 首次赠包：这一回第一次选的人亮着；换个存档再进来（已送过）就没有
	t.not_null(setup._gift_tag, "首次赠包小签：第一次选他时亮着")
	t.check(setup._gift_tag != null and (setup._gift_tag.get_child(0) as Label).text.begins_with("首次选他："), "写「首次选他：…进包架」")
	var two: CharacterDef = null
	for gch in flow.characters:
		if gch.starting_bags.size() >= 2 and gch.starting_bags[0] != gch.starting_bags[1]:
			two = gch
	if two != null:     # 补充一（游戏测试 v4.48）：几只包是「和」，不是「或」
		t.check(setup.first_gift_text(two).contains("、"), "两种包用顿号连：%s" % setup.first_gift_text(two))
		UiText.lang = "en"
		var en: String = setup.first_gift_text(two)
		UiText.lang = "zh"
		t.check(not en.contains(" or ") and en.contains(", "), "英文用逗号连，不写 or：%s" % en)
	# 带缺格与随身之物的探针
	var probe := _probe(setup.character())
	setup._characters.append(probe)
	setup.choose_character(setup._characters.size() - 1)
	_lay_out(game)
	var entries2: Array = setup._entries
	t.eq(entries2.size(), probe.skill_entries().size() + 2, "技能 + 随身之物 + 短板")
	var last: Label = (entries2.back() as Control).get_meta(&"name_label")
	t.eq(last.text, "探针短板", "有短板的角色：短板永远最后")
	t.eq(last.get_theme_color("font_color"), UiTheme.FLAW_NAME_INK, "短板名铁灰")
	var pin_row: Control = entries2[entries2.size() - 2]
	t.check((pin_row.get_child(0) as EntryIcon).kind == EntryIcon.ITEM, "随身之物那行的图标是道具本体")
	var pin_texts: Array = pin_row.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	t.eq(pin_texts.back(), "随身：拿不下、丢不掉", "末尾灰小字（先功效后不可移动，作者 11:00）")
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


## 补充二（架构设计 12:45）：开局第二页改两栏 —— 包架在棋盘板里棋盘正下方，带入现金钉在仓库框底部靠右，地上是仓库的一页；
## 1600 × 1000 下右沿不出 1564，七格 / 九格换人两块板一个像素不动
static func frame_kit_page(t: TestCase, root: Window) -> void:
	t.begin("255 补充二：开局第二页两栏（棋盘板 + 仓库框），1600 × 1000 不出框，七格 / 九格换人两块板不动")
	Support.cleanup("kit255")
	var p := Support.paths("kit255")
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	game.size = Vector2(1600, 1000)
	var flow: GameFlow = game.flow
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	var shots := {}
	for id in [&"andreus", &"brutus"]:
		for i in setup._characters.size():
			if setup._characters[i].id == id:
				setup.choose_character(i)
		setup.show_page(1)
		_lay_out(game)
		var board_panel: Control = setup._rack_box.get_parent().get_parent()
		var ware: Control = setup._warehouse_box
		t.check(board_panel is PanelContainer and board_panel.is_ancestor_of(setup._board_host), "%s：包架和棋盘在同一块棋盘板里" % id)
		t.check(setup._rack_box.global_position.y > setup._board_host.global_position.y + setup._board_host.size.y - 1.0, "%s：包架在棋盘正下方" % id)
		t.eq(setup._rack_view.columns, 9, "包架横排九格一行")
		t.check(ware.is_ancestor_of(setup.find_child("CashNote", true, false)), "%s：带入现金钉在仓库框里" % id)
		var right_edge: float = ware.global_position.x + ware.size.x - game.global_position.x
		t.check(right_edge <= 1564.0, "%s：仓库框右沿 %.0f ≤ 1564" % [id, right_edge])
		var bottom: float = maxf(board_panel.get_global_rect().end.y, ware.get_global_rect().end.y) - game.global_position.y
		t.check(bottom <= 1000.0, "%s：两块板底沿 %.0f 不出屏" % [id, bottom])
		shots[id] = [board_panel.get_global_rect(), ware.get_global_rect()]
	t.eq(shots[&"andreus"], shots[&"brutus"], "七格 / 九格换人：棋盘板、仓库框一个像素不动")
	game.queue_free()
	Support.cleanup("kit255")
