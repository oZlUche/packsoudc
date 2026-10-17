## 进阶难度骨架（069 第 1 步，报告 070）：`DifficultyDef` 走管线、`RunMechanic` 构件装进一局、数值修饰走 RunContext、
## 局外解锁决定能不能选、跟着存档、读档重新接上。期望从数据推：作者文件里写了 -1 就该 -1。
extends RefCounted

const GAME := "res://ui/game/game.tscn"
## 与 Support.paths("difficulty") 是同一组路径（flow / cleanup 按前缀算）
const SAVE := "user://test_difficulty_run.json"
const META := "user://test_difficulty_meta.json"
const Support := preload("res://tests/run/flow_support.gd")


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["difficulties"])


## 第一个要解锁的难度；没有返回 null
static func _locked(c: TestSupport.Content) -> DifficultyDef:
	for d in c.difficulties:
		if d.requires_unlock != &"":
			return d
	return null


## 一档难度对体力上限加的数（从定义里算，不写死）
static func _vitality_bonus(def: DifficultyDef) -> int:
	var ctx := RunContext.new()
	for e in def.run_effects():
		e.modify(ctx)
	return ctx.vitality_max_bonus


static func _has_mechanic(def: DifficultyDef, type_name: StringName) -> bool:
	for m in def.mechanics:
		if ContentSchema.registry_name_of(m) == type_name:
			return true
	return false


static func _import(data: Dictionary) -> ImportReport:
	var r := ImportReport.new()
	ContentImporter.import_difficulty(data, ContentImporter.Context.new(), r)
	return r


static func run_pipeline(t: TestCase) -> void:
	t.begin("难度 · 走内容管线：往返、机制构件按注册表造、校验、作者文件、按档位排")
	var sample := {"id": "probe", "display_name": "探针", "level": 2, "requires_unlock": "probe_unlock",
		"mechanics": [{"type": "erosion", "first_at_action": 2, "interval_actions": 3}],
		"effects": [{"type": "vitality_max_bonus", "amount": -2}]}
	var report := ImportReport.new()
	var def := ContentImporter.import_difficulty(sample, ContentImporter.Context.new(), report)
	t.check(report.ok(), "合法的难度导入没有错：%s" % report.to_text())
	var text := ContentExporter.to_json(ContentExporter.export_difficulty(def))
	var back := ContentImporter.import_difficulty(JSON.parse_string(text), ContentImporter.Context.new(), ImportReport.new())
	t.eq(ContentExporter.to_json(ContentExporter.export_difficulty(back)), text, "导出 → 导入 → 再导出逐字节相同")
	t.eq(back.mechanics.size(), 1, "机制在")
	t.check(back.mechanics[0] is ErosionMechanic, "按注册表造出了侵蚀机制")
	t.eq([(back.mechanics[0] as ErosionMechanic).first_at_action, (back.mechanics[0] as ErosionMechanic).interval_actions], [2, 3], "机制的参数在")
	t.eq(_vitality_bonus(back), -2, "数值修饰在（RunContext 里体力上限 -2）")
	t.eq(back.requires_unlock, &"probe_unlock", "解锁要求在")
	t.check(back.summary().contains("侵蚀") and back.summary().contains("体力上限"), "summary 把机制与修饰连起来：%s" % back.summary())
	t.eq(DifficultyDef.new().summary(), "没有额外机制", "空清单的 summary")

	t.check(not _import({"id": "x", "level": -1}).ok(), "档位为负报错")
	t.check(not _import({"id": "", "level": 0}).ok(), "没有 id 报错")
	t.check(not _import({"id": "x", "mechanics": [{"type": "no_such_mechanic"}]}).ok(), "认不得的机制报错（注册表拒绝）")
	var combat_type: StringName = EffectRegistry.COMBAT_EFFECTS.keys()[0]
	t.check(not _import({"id": "x", "effects": [{"type": String(combat_type)}]}).ok(), "战斗效果不能放进难度的 effects（%s）" % combat_type)
	t.check(_import({"id": "x"}).ok(), "什么都不带 = 普通，合法")

	# 作者文件：不动点、资产在、装回来按档位排
	var dir: String = ContentPaths.KINDS["difficulties"][0]
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
			var res := ContentImporter.import_difficulty(JSON.parse_string(raw), ContentImporter.Context.new(), r)
			t.check(r.ok(), "%s 导入没有错：%s" % [f, r.to_text()])
			t.eq(ContentExporter.to_json(ContentExporter.export_difficulty(res)), raw, "%s 是往返不动点" % f)
			t.check(ResourceLoader.exists(ContentPaths.asset_file("difficulties", id)), "%s 的资产在" % id)
	t.check(files >= 2, "至少两档（普通 + 一档进阶占位）")
	var c := _content()
	t.eq(c.difficulties.size(), files, "load_difficulties 装回全部 %d 份" % files)
	for i in range(1, c.difficulties.size()):
		t.check(c.difficulties[i - 1].level <= c.difficulties[i].level, "按档位排：%s ≤ %s" % [c.difficulties[i - 1].id, c.difficulties[i].id])
	t.check(c.difficulties[0].level == 0 and c.difficulties[0].requires_unlock == &"", "第一档是普通、不用解锁")
	t.not_null(_locked(c), "有一档要解锁的（占位进阶）")


static func run_start_and_save(t: TestCase) -> void:
	t.begin("难度 · 按难度开局：机制装进一局、数值修饰生效、id 跟着存档；没有难度 = 什么都不装")
	var c := _content()
	var hard := _locked(c)
	if hard == null:
		t.check(false, "没有进阶难度的内容")
		return
	var run: RunState = null
	var seed := 1
	while run == null and seed < 30:
		run = RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], null, [], hard)
		seed += 1
	t.not_null(run, "开得了局")
	if run == null:
		return
	t.eq(run.difficulty_id, hard.id, "记了难度 id")
	t.eq(run.vitality.maximum, Vitality.PLACEHOLDER_MAX + _vitality_bonus(hard), "体力上限 = 占位 + 难度的修饰（%+d）" % _vitality_bonus(hard))
	t.eq(run.mechanic_tags.has(&"erosion"), _has_mechanic(hard, &"erosion"), "侵蚀机制装了就留记号（占位）")
	t.check(run.travel.erosion is ErosionField, "侵蚀本体装到了 travel.erosion（075）")
	var d := run.to_dict()
	t.eq(String(d["difficulty"]), String(hard.id), "存档里有难度 id")
	var back := RunState.from_dict(d, c.chapter, c.items, c.enemies, c.sets)
	t.eq(back.difficulty_id, hard.id, "读回来 id 在")
	t.is_null(back.difficulty, "定义要持有方按 id 找回")
	t.check(back.mechanic_tags.is_empty(), "读回来还没装机制（持有方 _adopt 时装）")
	back.difficulty = hard
	back.install_modules()
	back.install_modules()
	t.check(back.mechanic_tags.has(&"erosion") or not _has_mechanic(hard, &"erosion"), "找回定义装上了；装两次幂等")

	var plain := RunState.start(c.chapter, seed - 1, c.items, c.enemies, c.sets)
	t.eq(plain.difficulty_id, &"", "没给难度：没有 id")
	t.check(plain.mechanic_tags.is_empty(), "什么都不装")
	t.eq(plain.vitality.maximum, Vitality.PLACEHOLDER_MAX, "体力上限照旧")


static func run_flow_unlock(t: TestCase) -> void:
	t.begin("难度 · 局外解锁决定能不能选：没解锁不列也开不了；解锁开关跟着 meta 存；读档找回定义并重新接上")
	var c := _content()
	var hard := _locked(c)
	if hard == null:
		t.check(false, "没有进阶难度的内容")
		return
	var f := Support.flow(c, "difficulty", 0.0)
	var avail := f.available_difficulties()
	t.check(not avail.has(hard), "没解锁：进阶不在能选的里")
	t.check(avail.size() >= 1 and avail[0].requires_unlock == &"", "普通一直能选")
	t.is_null(f.begin(c.chapter, null, 1, [] as Array[int], null, [], hard), "没解锁开不了（兜底）")
	t.check(f.toggle_unlock(hard.requires_unlock), "解锁开关：开")
	t.check(f.meta.has_unlock(hard.requires_unlock), "meta 记了")
	t.check(f.available_difficulties().has(hard), "解锁了就能选")
	t.check(MetaSave.read(c.items, META).has_unlock(hard.requires_unlock), "解锁跟着 meta 存了")
	var run: RunState = null
	var seed := 1
	while run == null and seed < 30:
		run = f.begin(c.chapter, null, seed, [] as Array[int], null, [], hard)
		seed += 1
	t.not_null(run, "按进阶开局")
	if run == null:
		return
	t.eq(run.difficulty_id, hard.id, "一局记着难度")
	run.phase = RunState.Phase.ON_MAP
	t.check(f.save(), "存档")
	var f2 := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f2.chapters = [c.chapter] as Array[ChapterDef]
	f2.difficulties = c.difficulties
	f2.save_path = SAVE
	f2.meta_path = META
	t.check(f2.continue_run(), "读档")
	t.eq(f2.run.difficulty, hard, "读档找回了定义")
	t.eq(f2.run.mechanic_tags.has(&"erosion"), _has_mechanic(hard, &"erosion"), "机制重新接上了")
	t.check(not f.toggle_unlock(hard.requires_unlock), "解锁开关：关")
	t.check(not f.available_difficulties().has(hard), "关了又不能选")
	Support.cleanup("difficulty")


static func frame_run_screens(t: TestCase, root: Window) -> void:
	t.begin("难度 · 开局屏只列能选的、挑了就按它开；局外屏有解锁开关")
	Support.cleanup("difficulty")
	var game = load(GAME).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	root.add_child(game)
	var flow: GameFlow = game.flow
	var hard: DifficultyDef = null
	for d in flow.difficulties:
		if d.requires_unlock != &"":
			hard = d
	if hard == null or flow.chapters.is_empty():
		t.check(false, "没有进阶难度或章节")
		game.queue_free()
		return
	# 083：这些测试要的是第一章（环形图）；序章通关才列它 —— 先把章节许诺的解锁都给上，再挑第一章
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)
	t.eq(setup._difficulty_num.text, "0", "当前难度 0（180：数字 + 加减键）")
	t.check(setup._plus_btn.disabled and setup._minus_btn.disabled, "只有普通一档：加减都灰")
	t.check(not flow.available_difficulties().has(hard), "新的局外：进阶没解锁，不列")
	t.check(setup.difficulty() != null and setup.difficulty().requires_unlock == &"", "默认选的是普通")

	flow.to_main_menu()
	flow.show_meta()
	var meta_screen = game.base()
	t.eq(meta_screen.screen, GameFlow.Screen.META, "→ 局外屏")
	t.check(meta_screen._unlock_btns.has(hard.requires_unlock), "局外屏有这个解锁的开关")
	t.check(meta_screen.toggle_unlock(hard.requires_unlock), "解锁")
	flow.new_run()
	setup = game.base()
	for gi2 in setup._chapters.size():
		if setup._chapters[gi2].id == &"free_mode":
			setup.choose_chapter(gi2)
	t.check(not setup._plus_btn.disabled, "解锁后能往上加一档")
	var idx := flow.available_difficulties().find(hard)
	t.check(idx >= 0, "进阶在能选的里")
	setup.choose_difficulty(idx)
	t.eq(setup.difficulty(), hard, "挑了进阶")
	t.eq(setup._difficulty_num.text, str(hard.level), "数字跟着变")
	t.check(hard.challenge != "" and setup._challenge.text.contains(hard.challenge), "红字列出这一级的挑战：%s" % setup._challenge.text)
	t.check(setup._plus_btn.disabled and not setup._minus_btn.disabled, "到顶：加灰、减亮")
	var went := false
	for seed in range(1, 30):
		setup.choose_scale(&"")     # 180：种子是按章节默认配置找的（开局屏默认第一档规模）
		setup.set_run_seed(seed)
		if setup.depart():
			went = true
			break
	t.check(went, "出发")
	if went:
		t.eq(flow.run.difficulty_id, hard.id, "一局记着进阶")
		t.eq(flow.run.vitality.maximum, (flow.characters[0].vitality_max if not flow.characters.is_empty() else Vitality.PLACEHOLDER_MAX) + _vitality_bonus(hard),
			"体力上限 = 角色的 + 难度的修饰")
	game.queue_free()
	Support.cleanup("difficulty")
