## 角色技能接口（069 第 3 步，报告 072）：技能是一局规则的效果构件，编进 RunContext，猎手系统读它。
## 期望从数据推：角色文件里的技能往上下文加多少，就断言多少。
extends RefCounted

const SAVE := "user://test_skills_run.json"
const META := "user://test_skills_meta.json"


class Content:
	extends RefCounted
	var items: ItemDatabase
	var enemies: EnemyDatabase
	var sets: SetDatabase
	var chapter: ChapterDef
	var characters: Array[CharacterDef]
	var hunter_defs: Dictionary


static func _content() -> Content:
	var c := Content.new()
	c.items = ItemDatabase.new()
	c.items.load_dir()
	c.enemies = EnemyDatabase.new()
	c.enemies.load_all()
	c.sets = SetDatabase.new()
	c.sets.load_dir()
	c.chapter = load(ContentPaths.asset_file("chapters", "chapter_01"))
	c.characters = GameFlow.load_characters()
	c.hunter_defs = GameFlow.load_hunters()
	return c


static func _cleanup() -> void:
	for p in [SAVE, META]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## 有技能的第一个角色；没有返回 null
static func _skilled(c: Content) -> CharacterDef:
	for ch in c.characters:
		if not ch.skills.is_empty():
			return ch
	return null


## 角色的技能单独编出来的上下文（期望值）
static func _expected(ch: CharacterDef) -> RunContext:
	var ctx := RunContext.new()
	for e in ch.run_effects():
		e.modify(ctx)
	return ctx


static func _start(c: Content, ch: CharacterDef, diff: DifficultyDef = null, defs: Dictionary = {}) -> RunState:
	for seed in range(1, 40):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], ch, [], diff, defs)
		if s != null:
			s.pick_spawn(s.map.entry_ids[0])
			return s
	return null


static func run_pipeline_and_context(t: TestCase) -> void:
	t.begin("技能 · 是一局规则的效果构件：往返、校验、三个构件各加各的数、编进 RunContext")
	var c := _content()
	var ctx0 := RunContext.new()
	t.eq([ctx0.scout_range, ctx0.sense_mult, ctx0.flee_bonus], [0.0, 1.0, 0.0], "上下文默认：不侦察、感知 ×1、逃跑 +0")
	var sample := {"id": "probe", "starting_bags": ["bag_leather"],
		"skills": [{"type": "scout_range", "range": 3.0}, {"type": "stealth", "mult": 0.5}, {"type": "flee_bonus", "amount": 0.25}]}
	var report := ImportReport.new()
	var def := ContentImporter.import_character(sample, ContentImporter.Context.new(), report)
	t.check(report.ok(), "带技能的角色导入没有错：%s" % report.to_text())
	var text := ContentExporter.to_json(ContentExporter.export_character(def))
	var back := ContentImporter.import_character(JSON.parse_string(text), ContentImporter.Context.new(), ImportReport.new())
	t.eq(ContentExporter.to_json(ContentExporter.export_character(back)), text, "导出 → 导入 → 再导出逐字节相同")
	t.eq(back.skills.size(), 3, "三个技能")
	var ctx := _expected(back)
	t.eq([ctx.scout_range, ctx.sense_mult, ctx.flee_bonus], [3.0, 0.5, 0.25], "侦察 3、感知 ×0.5、逃跑 +0.25")
	t.check(back.skills_summary().contains("侦察") and back.skills_summary().contains("潜行") and back.skills_summary().contains("逃跑"), "summary：%s" % back.skills_summary())
	# 两个侦察取大、两个潜行相乘、两个逃跑相加
	var twice := CharacterDef.new()
	for e in back.skills:
		twice.skills.append(e)
		twice.skills.append(e)
	var ctx2 := _expected(twice)
	t.eq([ctx2.scout_range, ctx2.sense_mult, ctx2.flee_bonus], [3.0, 0.25, 0.5], "叠加规则：侦察取大、潜行相乘、逃跑相加")

	var combat_type: StringName = EffectRegistry.COMBAT_EFFECTS.keys()[0]
	var bad := ImportReport.new()
	ContentImporter.import_character({"id": "x", "starting_bags": ["bag_leather"], "skills": [{"type": String(combat_type)}]}, ContentImporter.Context.new(), bad)
	t.check(not bad.ok(), "战斗效果不能当技能（%s）" % combat_type)
	var bad2 := ImportReport.new()
	ContentImporter.import_character({"id": "x", "starting_bags": ["bag_leather"], "skills": [{"type": "no_such_skill"}]}, ContentImporter.Context.new(), bad2)
	t.check(not bad2.ok(), "认不得的技能报错")

	var ch := _skilled(c)
	t.not_null(ch, "作者数据里有一个带技能的角色")
	if ch == null:
		return
	var s := _start(c, ch)
	t.not_null(s, "按它开局")
	if s == null:
		return
	var want := _expected(ch)
	var got := s.buff_context()
	t.eq([got.scout_range, got.sense_mult, got.flee_bonus], [want.scout_range, want.sense_mult, want.flee_bonus], "一局的上下文里就是角色技能加的数")
	var plain := _start(c, c.characters[0] if c.characters[0].skills.is_empty() else null)
	if plain != null:
		var g0 := plain.buff_context()
		t.eq([g0.scout_range, g0.sense_mult, g0.flee_bonus], [0.0, 1.0, 0.0], "没技能的角色：默认")


static func run_hunters_read_it(t: TestCase) -> void:
	t.begin("技能 · 猎手系统读上下文：侦察看见隐形的、潜行缩短感知、逃跑加成进成功率")
	var c := _content()
	var ch := _skilled(c)
	var hid: Array = c.hunter_defs.keys()
	hid.sort()
	if ch == null or hid.is_empty():
		t.check(false, "缺角色或猎手")
		return
	var want := _expected(ch)
	# 一个隐形猎手的副本，感知 4、逃跑 0.9
	var defs := {}
	var hdef: HunterDef = (c.hunter_defs[hid[0]] as HunterDef).duplicate(true)
	hdef.visibility = HunterDef.Visibility.HIDDEN
	hdef.sense_range = 4.0
	hdef.flee_chance = 0.9
	hdef.flee_cooldown = 3
	defs[hdef.id] = hdef
	var diff := DifficultyDef.new()
	diff.id = &"probe"
	var m := HunterMechanic.new()
	m.hunter_ids = [hdef.id] as Array[StringName]
	m.spawn_min_distance = 0.0
	diff.mechanics.append(m)
	var s := _start(c, ch, diff, defs)
	t.not_null(s, "开局")
	if s == null:
		return
	s.step_to(s.travel.available_moves()[0])
	var sys := s.hunters
	var h: Hunter = sys.alive()[0]
	t.eq(sys.sense_range(h), hdef.sense_range * want.sense_mult, "感知距离 = 定义 × 潜行倍率（%.2f）" % want.sense_mult)
	# 侦察：把它放到侦察距离内 → 隐形的也看得见；放远 → 看不见
	var near := -1
	var far := -1
	for id in s.map.node_ids():
		var d := sys.metric.distance(id, s.travel.current_id)
		if id != s.travel.current_id and d <= want.scout_range and near < 0:
			near = id
		if d > want.scout_range and far < 0:
			far = id
	if want.scout_range > 0.0 and near >= 0:
		h.node_id = near
		t.check(sys.visible_hunters().has(h), "隐形猎手在侦察距离（%.0f）内看得见" % want.scout_range)
	if far >= 0:
		h.node_id = far
		t.check(not sys.visible_hunters().has(h), "侦察距离外看不见")
	# 逃跑：0.9 + 加成 ≥ 1 → 必逃掉
	h.node_id = s.travel.current_id
	h.cooldown = 0
	t.check(sys.check_engagement(), "遭遇")
	var ev := s.events.pending_event()
	var chance := clampf(hdef.flee_chance + want.flee_bonus, 0.0, 1.0)
	t.check(ev.options.size() == 2 and ev.options[1].label.contains("%.0f%%" % (chance * 100.0)), "逃跑选项写着加成后的几率：%s" % ev.options[1].label)
	var fights: Array = []
	s.events.battle_finished.connect(func(_n: MapNode, _r: BattleResult, _w: bool): fights.append(true))
	t.check(s.events.choose(1), "选逃跑")
	if chance >= 1.0:
		t.eq(fights.size(), 0, "成功率封顶 1：必逃掉")
		t.eq(h.cooldown, hdef.flee_cooldown, "它歇 %d 步" % hdef.flee_cooldown)
	else:
		t.check(true, "（加成没到 1，随机）")

	# 读档：持有方按 id 找回角色，技能还在上下文里
	_cleanup()
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f.chapters = [c.chapter] as Array[ChapterDef]
	f.characters = c.characters
	f.save_path = SAVE
	f.meta_path = META
	var run: RunState = null
	for seed in range(1, 40):
		run = f.begin(c.chapter, null, seed, [] as Array[int], ch, [])
		if run != null:
			break
	if run != null:
		f.pick_spawn(run.map.entry_ids[0])
		t.check(f.save(), "存档")
		var f2 := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
		f2.chapters = [c.chapter] as Array[ChapterDef]
		f2.characters = c.characters
		f2.save_path = SAVE
		f2.meta_path = META
		t.check(f2.continue_run(), "读档")
		t.eq(f2.run.character, ch, "找回了角色定义")
		var g := f2.run.buff_context()
		t.eq([g.scout_range, g.sense_mult, g.flee_bonus], [want.scout_range, want.sense_mult, want.flee_bonus], "读档后技能还在上下文里")
	_cleanup()
