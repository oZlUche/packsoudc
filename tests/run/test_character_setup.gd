## 开局预选与角色（058 第 2 条，报告 067）：`CharacterDef` 走管线、按角色开局、开局屏摆好的棋盘原样进一局、第一套发进仓库、
## 从仓库往包里拖 = 带入、包进不了仓库、上限是字段。
## 期望从数据推：角色文件说几个包、体力几点，就断言几个几点。
extends RefCounted

const GAME := "res://ui/game/game.tscn"
## 与 Support.paths("char") 是同一组路径（flow / cleanup 按前缀算）
const SAVE := "user://test_char_run.json"
const META := "user://test_char_meta.json"
const Support := preload("res://tests/run/flow_support.gd")


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["loadouts", "characters", "meta_rules"])


static func _ctx(c: TestSupport.Content) -> ContentImporter.Context:
	var ctx := ContentImporter.Context.new()
	for id in c.items.ids():
		ctx.register_item(c.items.get_def(id))
	for l in c.loadouts:
		ctx.register_loadout(l)
	return ctx


static func _import(data: Dictionary, ctx: ContentImporter.Context) -> ImportReport:
	var r := ImportReport.new()
	ContentImporter.import_character(data, ctx, r)
	return r


## 一套开局装备里、局外收的（非包）道具
static func _kept_of(c: TestSupport.Content, kit: LoadoutDef) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	if kit == null:
		return out
	for id in kit.items:
		var def := c.items.get_def(id)
		if MetaState.keeps(def):
			out.append(def)
	return out


static func _bags_on(board: GridInventory) -> int:
	var n := 0
	for inst in board.items():
		if (inst as ItemInstance).def.is_bag:
			n += 1
	return n


static func run_character_pipeline(t: TestCase) -> void:
	t.begin("角色 · 走内容管线：往返、校验、作者文件、基线与上限")
	var c := _content()
	var ctx := _ctx(c)
	var sample := {"id": "probe", "display_name": "探针", "base_stats": {"max_hp": 42}, "vitality_max": 7,
		"board_size": [5, 4], "starting_bags": ["bag_leather"], "carry_max_items": 2, "carry_rarity_cap": 1}
	var report := ImportReport.new()
	var def := ContentImporter.import_character(sample, ctx, report)
	t.check(report.ok(), "合法的角色导入没有错：%s" % report.to_text())
	var text := ContentExporter.to_json(ContentExporter.export_character(def))
	var back := ContentImporter.import_character(JSON.parse_string(text), ctx, ImportReport.new())
	t.eq(ContentExporter.to_json(ContentExporter.export_character(back)), text, "导出 → 导入 → 再导出逐字节相同")
	t.eq(back.board_size, Vector2i(5, 4), "棋盘尺寸在")
	t.eq(back.vitality_max, 7, "体力上限在")
	t.eq(back.baseline().value_of(&"max_hp"), 42.0, "基线：覆盖项盖上去")
	t.eq(back.baseline().value_of(&"max_stamina"), float(CombatantBaseline.DEFAULT_STATS["max_stamina"]), "没写的沿用默认")
	t.eq(ctx.characters.has(&"probe"), true, "登记进了上下文")

	t.check(not _import({"id": "x", "starting_bags": []}, ctx).ok(), "没有初始包报错")
	t.check(not _import({"id": "x", "starting_bags": ["pistol"]}, ctx).ok(), "初始包不是包报错")
	t.check(not _import({"id": "x", "starting_bags": ["no_such_bag"]}, ctx).ok(), "找不到的包报错")
	t.check(_import({"id": "x", "starting_bags": ["no_such_bag"]}, ContentImporter.Context.new()).ok(), "单独导（上下文空）不对着道具查")
	t.check(not _import({"id": "x", "starting_bags": ["bag_leather"], "board_size": [0, 3]}, ctx).ok(), "棋盘 0 宽报错")
	t.check(not _import({"id": "x", "starting_bags": ["bag_leather"], "vitality_max": 0}, ctx).ok(), "体力上限 0 报错")
	t.check(not _import({"id": "x", "starting_bags": ["bag_leather"], "carry_max_items": -2}, ctx).ok(), "上限 -2 报错（只有 -1 = 不限）")
	t.check(not _import({"id": "", "starting_bags": ["bag_leather"]}, ctx).ok(), "没有 id 报错")

	# 上限是字段，默认不限
	var free := CharacterDef.new()
	var three: Array = [c.items.get_def(&"medkit"), c.items.get_def(&"medkit"), c.items.get_def(&"rifle")]
	t.eq(free.carry_problem(three), "", "默认不限：三件随便带")
	t.ne(back.carry_problem(three), "", "最多 2 件：三件带不了")
	var rare := c.items.get_def(&"rifle")
	t.check(rare != null and rare.rarity > 1, "步枪的稀有度高于 1（数据）")
	t.ne(back.carry_problem([rare]), "", "稀有度上限 1：步枪带不了")
	t.eq(back.carry_problem([c.items.get_def(&"medkit")]), "", "医疗包（稀有度 %d）带得了" % c.items.get_def(&"medkit").rarity)

	# 作者文件是往返不动点、资产在、装得回来
	var dir: String = ContentPaths.KINDS["characters"][0]
	var files := 0
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			if not f.ends_with(".json"):
				continue
			files += 1
			var id := f.get_basename()
			var raw := FileAccess.get_file_as_string(dir + "/" + f)
			var r := ImportReport.new()
			var res := ContentImporter.import_character(JSON.parse_string(raw), ctx, r)
			t.check(r.ok(), "%s 导入没有错：%s" % [f, r.to_text()])
			t.eq(ContentExporter.to_json(ContentExporter.export_character(res)), raw, "%s 是往返不动点" % f)
			t.check(ResourceLoader.exists(ContentPaths.asset_file("characters", id)), "%s 的资产在" % id)
	t.check(files >= 1, "至少一个角色文件（占位 default）")
	t.eq(c.characters.size(), files, "GameFlow.load_characters 装回全部 %d 份" % files)

	# 局外规则的 first_kit 对着开局装备查
	var bad := ImportReport.new()
	ContentImporter.import_meta_rules({"id": "x", "first_kit": "no_such_kit"}, ctx, bad)
	t.check(not bad.ok(), "first_kit 引用不存在的装备报错")
	var lone := ImportReport.new()
	ContentImporter.import_meta_rules({"id": "x", "first_kit": "no_such_kit"}, ContentImporter.Context.new(), lone)
	t.check(lone.ok(), "单独导不查")
	t.check(c.meta_rules != null and c.meta_rules.first_kit != &"", "作者数据里配了第一套（占位）")


static func run_start_with_character(t: TestCase) -> void:
	t.begin("角色 · 按角色开局：棋盘、体力、基线、初始包；开局屏摆好的棋盘原样进一局")
	var c := _content()
	if c.characters.is_empty():
		t.check(false, "没有角色定义")
		return
	var ch := c.characters[0]
	var run: RunState = null
	var seed := 1
	while run == null and seed < 30:
		run = RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], ch)
		seed += 1
	t.not_null(run, "开得了局")
	if run == null:
		return
	t.eq(run.board.size, ch.board_size, "棋盘尺寸按角色")
	t.eq(run.vitality.maximum, ch.vitality_max, "体力上限按角色")
	t.eq(run.character_id, ch.id, "记了角色 id")
	t.eq(run.player_baseline.value_of(&"max_hp"), ch.baseline().value_of(&"max_hp"), "基线按角色")
	t.eq(_bags_on(run.board), ch.starting_bags.size(), "初始包都在棋盘上（%d 个）" % ch.starting_bags.size())
	t.eq(run.board.item_count(), ch.starting_bags.size(), "只有包，没有别的")

	# 开局屏摆好的棋盘：包 + 一件从仓库拖来的，位置原样进一局
	var staged := GridInventory.new(ch.board_size, RunState.BOARD_ID, true)
	for id in ch.starting_bags:
		staged.try_add(ItemInstance.create(c.items.get_def(id), 0), true)
	var medkit := ItemInstance.create(c.items.get_def(&"medkit"), 0)
	t.check(staged.try_add(medkit, true), "医疗包放进了初始包")
	var layout := RunState.layout_of(staged)
	t.eq(layout.size(), ch.starting_bags.size() + 1, "layout 一件一行")
	t.eq(String(layout[0]["id"]), String(ch.starting_bags[0]), "包排在前面")
	var run2 := RunState.start(c.chapter, seed - 1, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], ch, layout)
	t.not_null(run2, "带着 layout 开局")
	if run2 != null:
		t.eq(RunState.layout_of(run2.board), layout, "一局里的棋盘和开局屏摆的逐件相同（定义、落点、朝向）")
		t.eq(run2.storage.item_count(), 0, "没有东西掉到地上")
		t.eq(run2.board.item_count(), layout.size(), "件数一样")
		# 存档带着角色
		var d := run2.to_dict()
		t.eq(String(d["character"]), String(ch.id), "存档里有角色 id")
		var back := RunState.from_dict(d, c.chapter, c.items, c.enemies, c.sets)
		t.eq(back.character_id, ch.id, "读回来还是那个角色")
		t.eq(back.board.size, ch.board_size, "棋盘尺寸跟着存档")

	# 没给角色 = 老路：占位的尺寸与体力
	var legacy := RunState.start(c.chapter, seed - 1, c.items, c.enemies, c.sets, c.loadouts[0].items)
	t.eq(legacy.board.size, RunState.BOARD_SIZE, "老路棋盘是占位尺寸")
	t.eq(legacy.vitality.maximum, Vitality.PLACEHOLDER_MAX, "老路体力是占位上限")
	t.eq(legacy.character_id, &"", "老路没有角色")


static func run_first_kit_and_flow(t: TestCase) -> void:
	t.begin("角色 · 第一套发进仓库；从仓库拖上棋盘再出发 = 带入并存 meta；读档找回基线")
	var c := _content()
	if c.characters.is_empty() or c.meta_rules == null:
		t.check(false, "没有角色或局外规则")
		return
	var ch := c.characters[0]
	var f := Support.flow(c, "char", 0.0, c.meta_rules)
	var kit := f.loadout_of(c.meta_rules.first_kit)
	var kept := _kept_of(c, kit)
	t.check(kit != null and not kept.is_empty(), "第一套 '%s' 存在且有非包道具" % c.meta_rules.first_kit)
	t.eq(f.meta.warehouse.item_count(), 0, "仓库一开始是空的")
	f.new_run()
	t.eq(f.meta.warehouse.item_count(), kept.size(), "开局屏打开时把第一套的非包道具发进了仓库（%d 件）" % kept.size())
	var bags_in_warehouse := 0
	for inst in f.meta.warehouse.items():
		if (inst as ItemInstance).def.is_bag:
			bags_in_warehouse += 1
	t.eq(bags_in_warehouse, 0, "包没发进仓库（局外不收包）")
	t.check(FileAccess.file_exists(META), "发完就存了 meta")
	f.to_main_menu()
	f.new_run()
	t.eq(f.meta.warehouse.item_count(), kept.size(), "仓库不空就不再发")
	var quiet := MetaRules.new()
	quiet.id = &"quiet"
	var f0 := Support.flow(c, "char", 0.0, quiet)
	f0.new_run()
	t.eq(f0.meta.warehouse.item_count(), 0, "first_kit 空 = 不发")

	# 从仓库拖上棋盘再出发
	f = Support.flow(c, "char", 0.0, c.meta_rules)
	f.new_run()
	var first := f.meta.warehouse.items()[0] as ItemInstance
	var staged := GridInventory.new(ch.board_size, RunState.BOARD_ID, true)
	for id in ch.starting_bags:
		var bag := ItemInstance.create(c.items.get_def(id), 0)
		bag.uid = f.meta.allocate_uid()
		staged.try_add(bag, true)
	t.check(InventoryService.transfer_auto(f.meta.warehouse, first.uid, staged), "从仓库挪到了棋盘（拖拽做的就是这个）")
	t.eq(f.meta.warehouse.item_count(), kept.size() - 1, "仓库少了一件")
	var run: RunState = null
	var seed := 1
	while run == null and seed < 30:
		run = f.begin(c.chapter, null, seed, [] as Array[int], ch, RunState.layout_of(staged))
		seed += 1
	t.not_null(run, "出发")
	if run == null:
		return
	t.eq(f.screen, GameFlow.Screen.MAP, "→ 地图")
	var found := false
	for inst in run.board.items():
		if (inst as ItemInstance).def.id == first.def.id and (inst as ItemInstance).origin == first.origin:
			found = true
	t.check(found, "带的那件在一局的棋盘上、位置和开局屏摆的一样")
	t.eq(run.player_baseline.value_of(&"max_hp"), ch.baseline().value_of(&"max_hp"), "基线按角色")
	var on_disk := MetaSave.read(c.items, META, c.meta_rules)
	t.eq(on_disk.warehouse.item_count(), kept.size() - 1, "出发那一刻存了 meta：仓库里没有它了")

	# 存档、换个持有方读回来：角色 id 在，基线从定义表找回
	run.phase = RunState.Phase.ON_MAP
	t.check(f.save(), "存档")
	var f2 := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new(c.meta_rules))
	f2.chapters = [c.chapter] as Array[ChapterDef]
	f2.characters = c.characters
	f2.save_path = SAVE
	f2.meta_path = META
	t.check(f2.continue_run(), "读档")
	t.eq(f2.run.character_id, ch.id, "读回来还是那个角色")
	t.eq(f2.run.player_baseline.value_of(&"max_hp"), ch.baseline().value_of(&"max_hp"), "基线从定义表找回（存档只写 id）")
	Support.cleanup("char")


static func frame_run_setup_screen(t: TestCase, root: Window) -> void:
	t.begin("开局屏 · 角色、初始包、从仓库带（进 / 出 / 上限 / 包不能进仓库）、出发、取消")
	Support.cleanup("char")
	var game = load(GAME).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	root.add_child(game)
	var flow: GameFlow = game.flow
	if flow.characters.is_empty() or flow.chapters.is_empty():
		t.check(false, "没有角色或章节")
		game.queue_free()
		return
	var ch: CharacterDef = flow.characters[0]
	# 083：这些测试要的是第一章（环形图）；序章通关才列它 —— 先把章节许诺的解锁都给上，再挑第一章
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)
	t.eq(setup.screen, GameFlow.Screen.SETUP, "→ 开局屏")
	# 反馈（紧急）：左列比窗口还高，列尾的「出发」被挤出屏幕，开局没有入口 —— 「进入」钉在右下角，窗口再矮也在屏内
	var enter: Button = setup._enter_btn
	t.eq(setup.page(), 0, "161：先是第一页（选角色）")
	t.check(enter != null and enter.text == "继续" and enter.visible, "有「继续」按钮")
	if enter != null:
		var vp := Rect2(Vector2.ZERO, setup.get_viewport_rect().size)
		var rect := Rect2(enter.global_position, enter.size)
		t.check(vp.encloses(rect), "「进入」整块在屏内（%s / %s）" % [str(rect), str(vp)])
		t.check(rect.position.x > vp.size.x * 0.5 and rect.position.y > vp.size.y * 0.5, "在右下角")
	t.not_null(setup.board, "有这个角色的棋盘")
	t.eq(setup.board.size, ch.board_size, "尺寸按角色")
	t.eq(_bags_on(setup.board), ch.starting_bags.size(), "初始包摆好了")
	var n: int = flow.meta.warehouse.item_count()
	t.check(n > 0, "新的局外：第一套发进了仓库（%d 件）" % n)

	var first := flow.meta.warehouse.items()[0] as ItemInstance
	var name := first.def.display_name
	t.check(setup.carry_in(first.uid), "带上一件")
	t.eq(flow.meta.warehouse.item_count(), n - 1, "仓库少了一件")
	t.eq(setup.carried().size(), 1, "带了一件")
	# 180（作者定）：棋盘下的读数只留负重与带入预算两行 —— 不列带了什么、不写「已带」「带上」
	var readout: String = setup._readout.get_parsed_text()
	t.check(not readout.contains(name) and not readout.contains("已带") and not readout.contains("带上"), "读数不列道具、不写已带 / 带上（%s）" % readout)
	t.check(readout.contains("带入预算") and readout.get_slice_count("\n") <= 2, "读数至多两行：负重、带入预算（%s）" % readout)
	t.check(setup.carry_out(first.uid), "放回去")
	t.eq(flow.meta.warehouse.item_count(), n, "仓库又是 %d 件" % n)
	t.check(setup.carry_in(first.uid), "再带上")

	# 包进不了仓库：规则只写在 MetaState.keeps 一处，仓库的格子接着它
	var bag_uid := -1
	for inst in setup.board.items():
		if (inst as ItemInstance).def.is_bag:
			bag_uid = (inst as ItemInstance).uid
	t.check(bag_uid >= 0, "棋盘上有包")
	t.check(not flow.meta.warehouse.accepts(setup.board.get_item(bag_uid).def), "仓库的格子不收包")
	t.check(not InventoryService.transfer_auto(setup.board, bag_uid, flow.meta.warehouse), "把包挪去仓库挪不动（拖过去会弹回来）")
	t.check(not setup.carry_out(bag_uid), "carry_out 也不放包")
	t.eq(_bags_on(setup.board), ch.starting_bags.size(), "包一个没少")

	# 上限是字段：临时把件数上限调成 0，出发被拦
	var cap := ch.carry_max_items
	ch.carry_max_items = 0
	t.ne(setup.can_depart(), "", "件数上限 0：带了一件就走不了")
	t.check(not setup.depart(), "出发被拦")
	t.ne(setup._status.text, "", "说了原因")
	ch.carry_max_items = cap
	t.eq(setup.can_depart(), "", "上限放回不限：能走")

	# 换角色（还是它）：带上的先回仓库，棋盘重摆
	setup.choose_character(0)
	t.eq(flow.meta.warehouse.item_count(), n, "换角色前带上的放回了仓库")
	t.eq(setup.carried().size(), 0, "新棋盘上没带东西")
	t.check(setup.carry_in(first.uid), "再带上")
	var origin: Vector2i = setup.board.get_item(first.uid).origin

	# 出发：带的那件按原位进一局，仓库存了
	var went := false
	for seed in range(1, 30):
		setup.choose_scale(&"")     # 180：种子是按章节默认配置找的（开局屏默认第一档规模）
		setup.set_run_seed(seed)
		if Support.depart(setup):
			went = true
			break
	t.check(went, "出发")
	if went:
		t.eq(game.base().screen, GameFlow.Screen.MAP, "→ 地图")
		var run: RunState = flow.run
		t.eq(run.character_id, ch.id, "一局记着角色")
		t.eq(run.vitality.maximum, ch.vitality_max, "体力上限按角色")
		var found := false
		for inst in run.board.items():
			if (inst as ItemInstance).def.id == first.def.id and (inst as ItemInstance).origin == origin:
				found = true
		t.check(found, "带的那件在一局的棋盘上、位置原样")
		t.eq(MetaSave.read(flow.items, META, flow.meta_rules).warehouse.item_count(), n - 1, "meta 存了：仓库里没有它了")

	# 取消：带上的放回仓库、回主菜单
	flow.to_main_menu()
	flow.new_run()
	var setup2 = game.base()
	var m: int = flow.meta.warehouse.item_count()
	t.eq(m, n - 1, "仓库不空，没再发第一套")
	if m > 0:
		var any := flow.meta.warehouse.items()[0] as ItemInstance
		t.check(setup2.carry_in(any.uid), "带上一件")
		t.eq(flow.meta.warehouse.item_count(), m - 1, "仓库少一件")
		setup2.cancel()
		t.eq(game.base().screen, GameFlow.Screen.MAIN_MENU, "→ 主菜单")
		t.eq(flow.meta.warehouse.item_count(), m, "带上的放回了仓库")
		t.eq(MetaSave.read(flow.items, META, flow.meta_rules).warehouse.item_count(), m, "meta 存的也是放回之后的")

	game.queue_free()
	Support.cleanup("char")


## 090（作者定）：开局屏的地上 —— 上一局带回来、还没置入的东西进这一屏时挪到地上；拖上包 = 带上、拖进仓库 = 置入、
## 换角色回地上；回主菜单原样放回带回来的棋盘（视为没发生过移动）；出发则留在地上的没了。仓库的东西进不了地上
static func frame_setup_stash(t: TestCase, root: Window) -> void:
	t.begin("开局屏 · 地上（090）：带回来的到地上、带上 / 置入 / 留着、换角色回地上、回主菜单原样放回、出发就没了")
	Support.cleanup("char")
	var game = load(GAME).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	root.add_child(game)
	var flow: GameFlow = game.flow
	if flow.characters.is_empty() or flow.chapters.is_empty():
		t.check(false, "没有角色或章节")
		game.queue_free()
		return
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.meta.grant([flow.items.get_def(&"medkit")])
	var n: int = flow.meta.warehouse.item_count()
	t.check(n >= 1, "仓库里有东西（%d 件）" % n)
	var wh_uid: int = (flow.meta.warehouse.items()[0] as ItemInstance).uid
	# 上一局带回来的棋盘：三件非包
	var back := GridInventory.new(RunState.BOARD_SIZE, MetaState.BOARD_ID, false)
	var uids: Array[int] = []
	var origins: Dictionary = {}
	for id in [&"medkit", &"medkit", &"rifle"]:
		var inst := ItemInstance.create(flow.items.get_def(id), 0)
		inst.uid = flow.meta.allocate_uid()
		t.check(back.try_add(inst, true), "%s 摆上带回来的棋盘" % id)
		uids.append(inst.uid)
		origins[inst.uid] = inst.origin
	flow.meta.board = back
	t.check(flow.meta.has_pending_board(), "带回来的棋盘等着")
	t.ne(flow.pending_hint(), "", "局外屏有一句提示")
	flow.new_run()
	var setup = game.base()
	t.eq(setup.screen, GameFlow.Screen.SETUP, "→ 开局屏")
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)
	t.eq(setup.stash.item_count(), 3, "三件都到了地上")
	t.check(not flow.meta.has_pending_board(), "带回来的棋盘空了（东西挪到了地上）")
	t.eq(flow.meta.warehouse.item_count(), n, "仓库没动")
	t.check(setup._stash_box.visible, "地上那一栏显示着")
	t.check(setup._stash_title.text.contains("3"), "标题写着件数：%s" % setup._stash_title.text)

	# 落点规则：仓库的东西进不了地上（会丢）；地上的能回地上、能进仓库、能上棋盘
	var filt: Callable = setup._drag.drop_filter
	t.check(not bool(filt.call(flow.meta.warehouse.get_item(wh_uid), setup.stash)), "仓库的东西拖不到地上")
	t.check(bool(filt.call(setup.stash.get_item(uids[0]), setup.stash)), "地上的能放回地上")
	t.check(bool(filt.call(setup.stash.get_item(uids[0]), flow.meta.warehouse)), "地上的能进仓库")
	t.check(bool(filt.call(setup.stash.get_item(uids[0]), setup.board)), "地上的能上棋盘")

	# 带上 / 置入 / 留着
	t.check(setup.carry_in(uids[0]), "地上的一件带上包")
	t.eq(setup.carried().size(), 1, "带了一件")
	t.check(setup.store(uids[1]), "地上的一件收进仓库")
	t.eq(flow.meta.warehouse.item_count(), n + 1, "仓库多了一件")
	t.eq(setup.stash.item_count(), 1, "地上剩一件")
	t.check(not setup.store(wh_uid), "仓库的东西不归 store 管")

	# 换角色：从地上带上的回地上（不是仓库）
	setup.choose_character(0)
	t.eq(setup.stash.item_count(), 2, "换角色：从地上带上的回了地上")
	t.eq(flow.meta.warehouse.item_count(), n + 1, "仓库没多")
	t.check(setup.carry_in(uids[0]), "再带上")
	t.check(setup.carry_in(wh_uid), "仓库的也带上一件")

	# 回主菜单：视为没发生过移动 —— 带回来的两件按原位回带回来的棋盘；仓库来的回仓库；已经收进仓库的留在仓库
	setup.cancel()
	t.eq(game.base().screen, GameFlow.Screen.MAIN_MENU, "→ 主菜单")
	t.check(flow.meta.has_pending_board() and flow.meta.board.item_count() == 2, "带回来的棋盘又是两件")
	for uid in [uids[0], uids[2]]:
		var it: ItemInstance = flow.meta.board.get_item(uid) if flow.meta.board != null else null
		t.check(it != null and it.origin == origins[uid], "uid %d 回到原位 %s" % [uid, origins[uid]])
	t.is_null(flow.meta.board.get_item(uids[1]), "收进仓库的那件没回棋盘")
	t.eq(flow.meta.warehouse.item_count(), n + 1, "仓库：原来的 + 收进的那件")
	t.check(MetaSave.read(flow.items, META, flow.meta_rules).has_pending_board(), "存盘里带回来的棋盘还在")

	# 再进开局屏：一件带上、一件留着，出发 —— 留着的没了
	flow.new_run()
	setup = game.base()
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)
	t.eq(setup.stash.item_count(), 2, "又到了地上")
	t.check(setup.carry_in(uids[0]), "带上一件")
	var went := false
	for seed in range(1, 30):
		setup.choose_scale(&"")     # 180：种子是按章节默认配置找的（开局屏默认第一档规模）
		setup.set_run_seed(seed)
		if Support.depart(setup):
			went = true
			break
	t.check(went, "出发")
	if went:
		t.eq(game.base().screen, GameFlow.Screen.MAP, "→ 地图")
		var found := 0
		for inst in flow.run.board.items():
			if (inst as ItemInstance).def.id == &"medkit":
				found += 1
		t.check(found >= 1, "带上的那件进了一局")
		t.check(flow.meta.board == null, "留在地上的没了：带回来的棋盘清了")
		t.eq(setup.stash.item_count(), 0, "地上清空")
		t.eq(flow.meta.warehouse.item_count(), n + 1, "仓库没被动")
		t.check(not MetaSave.read(flow.items, META, flow.meta_rules).has_pending_board(), "存盘里也清了")
	game.queue_free()
	Support.cleanup("char")
