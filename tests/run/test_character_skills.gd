## 局内技能（作者定，报告 082；接 072 的被动接口）：技能是构件 —— 被动常驻（一局规则的效果，编进 RunContext）+ 可选的主动一击
## （地图上用，次数与冷却记账，「突击」立旗等下一场战斗，「躲避」让猎手够不着）；免罚的败仗只对节点敌人；基线加成盖到基线上；
## 三个作者定的角色（安德烈乌斯 / 布鲁图斯 / 马库斯）走管线。期望从数据推：角色文件里写多少就断言多少。
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


static func _character(c: Content, id: StringName) -> CharacterDef:
	for ch in c.characters:
		if ch.id == id:
			return ch
	return null


## 角色的技能单独编出来的上下文（期望值）
static func _expected(ch: CharacterDef) -> RunContext:
	var ctx := RunContext.new()
	for e in ch.run_effects():
		e.modify(ctx)
	return ctx


static func _start(c: Content, ch: CharacterDef, diff: DifficultyDef = null, defs: Dictionary = {}) -> RunState:
	for seed in range(1, 60):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], ch, [], diff, defs)
		if s != null:
			s.pick_spawn(s.map.entry_ids[0])
			return s
	return null


## 图上一个带敌人的点
static func _battle_node(s: RunState) -> MapNode:
	for id in s.map.node_ids():
		var n := s.map.get_node(id)
		if n.type == &"battle" and EnemyKit.has_enemy(n.content):
			return n
	return null


static func run_pipeline(t: TestCase) -> void:
	t.begin("技能 · 构件走管线：被动 + 主动，往返，校验；被动编进 RunContext")
	var sample := {"id": "probe", "starting_bags": ["bag_leather"], "skills": [
		{"type": "passive", "id": "eyes", "display_name": "眼力", "passive": [{"type": "scout_range", "range": 3.0}, {"type": "stealth", "mult": 0.5}, {"type": "flee_bonus", "amount": 0.25}]},
		{"type": "assault", "id": "assault", "display_name": "突击", "uses": 1, "cooldown_steps": 2, "hp_fraction": 0.3},
		{"type": "evade", "id": "evade", "display_name": "躲避", "steps": 2, "passive": [{"type": "free_losses", "amount": 1}, {"type": "stat_bonus", "stat": "max_hp", "amount": 20.0}]}]}
	var report := ImportReport.new()
	var def := ContentImporter.import_character(sample, ContentImporter.Context.new(), report)
	t.check(report.ok(), "带技能的角色导入没有错：%s" % report.to_text())
	var text := ContentExporter.to_json(ContentExporter.export_character(def))
	var back := ContentImporter.import_character(JSON.parse_string(text), ContentImporter.Context.new(), ImportReport.new())
	t.eq(ContentExporter.to_json(ContentExporter.export_character(back)), text, "导出 → 导入 → 再导出逐字节相同")
	t.eq(back.skills.size(), 3, "三个技能")
	t.eq(back.active_skills().size(), 2, "两个有主动一击（突击、躲避），眼力是被动")
	var ctx := _expected(back)
	t.eq([ctx.scout_range, ctx.sense_mult, ctx.flee_bonus, ctx.free_losses, float(ctx.stat_bonus.get(&"max_hp", 0.0))], [3.0, 0.5, 0.25, 1, 20.0], "被动全编进上下文")
	t.check(back.skills_summary().contains("眼力") and back.skills_summary().contains("突击") and back.skills_summary().contains("30%"), "summary：%s" % back.skills_summary())
	t.eq((back.skills[1] as RunSkill).uses, 1, "次数是字段")

	var combat_type: StringName = EffectRegistry.COMBAT_EFFECTS.keys()[0]
	var bads := [
		{"why": "战斗效果不能当被动", "skills": [{"type": "passive", "id": "x", "passive": [{"type": String(combat_type)}]}]},
		{"why": "认不得的技能", "skills": [{"type": "no_such_skill", "id": "x"}]},
		{"why": "技能没有 id", "skills": [{"type": "passive"}]},
		{"why": "技能 id 重复", "skills": [{"type": "passive", "id": "a"}, {"type": "assault", "id": "a"}]},
		{"why": "突击比例 0", "skills": [{"type": "assault", "id": "a", "hp_fraction": 0.0}]},
		{"why": "躲避 0 步", "skills": [{"type": "evade", "id": "e", "steps": 0}]},
		{"why": "次数 -2", "skills": [{"type": "assault", "id": "a", "uses": -2}]},
	]
	for bad in bads:
		var r := ImportReport.new()
		ContentImporter.import_character({"id": "x", "starting_bags": ["bag_leather"], "skills": bad["skills"]}, ContentImporter.Context.new(), r)
		t.check(not r.ok(), "拦下：%s" % bad["why"])


static func run_authored_characters(t: TestCase) -> void:
	t.begin("技能 · 作者定的三个角色：安德烈乌斯（躲避、免罚一败）、布鲁图斯（坚韧：生命 / 耐力 / 体力更高）、马库斯（突击）；被动进上下文、基线加成盖到基线上")
	var c := _content()
	for id in [&"andreus", &"brutus", &"marcus"]:
		t.not_null(_character(c, id), "有角色 %s" % id)
	var brutus := _character(c, &"brutus")
	var andreus := _character(c, &"andreus")
	var marcus := _character(c, &"marcus")
	if brutus == null or andreus == null or marcus == null:
		return
	t.check(andreus.active_skills().size() >= 1 and andreus.active_skills()[0] is EvadeSkill, "安德烈乌斯有躲避")
	t.check(_expected(andreus).free_losses >= 1, "安德烈乌斯免罚至少一败")
	t.check(marcus.active_skills().size() >= 1 and marcus.active_skills()[0] is AssaultSkill, "马库斯有突击")
	t.check(brutus.active_skills().is_empty() and not brutus.skills.is_empty(), "布鲁图斯只有被动")
	var want := _expected(brutus)
	t.check(float(want.stat_bonus.get(&"max_hp", 0.0)) > 0.0 and want.vitality_max_bonus > 0, "坚韧：生命与体力都有加成")
	for raw in [andreus, brutus, marcus]:
		var ch := raw as CharacterDef
		var s := _start(c, ch)
		t.not_null(s, "按 %s 开局" % ch.id)
		if s == null:
			continue
		var w := _expected(ch)
		var got := s.buff_context()
		t.eq(got.snapshot(), w.snapshot(), "%s：一局的上下文 = 技能的被动" % ch.id)
		t.eq(s.vitality.maximum, ch.vitality_max + w.vitality_max_bonus, "%s：体力上限 = 角色 + 被动" % ch.id)
		var base := ch.baseline()
		var eff := s.effective_baseline()
		for key in base.base_stats:
			var k := StringName(String(key))
			t.eq(eff.value_of(k), base.value_of(k) + float(w.stat_bonus.get(k, 0.0)), "%s：基线 %s = 角色 + 加成" % [ch.id, k])
		var spec := s.compile_player()
		t.eq(spec.max_hp_int(), int(eff.value_of(&"max_hp")) + _board_hp(spec), "%s：编译出来的生命按加成后的基线" % ch.id)
		t.check(s.skills != null and s.skills.active_skills().size() == ch.active_skills().size(), "%s：技能账里的主动技能与角色一致" % ch.id)


## 棋盘上道具自带的生命（开局包里可能有）
static func _board_hp(spec: CombatantSpec) -> int:
	var hp := 0
	for it in spec.items:
		hp += StatMath.to_int((it as CompiledItem).stats.total_of(BattleStats.MAX_HP))
	return hp


static func run_assault_and_free_loss(t: TestCase) -> void:
	t.begin("技能 · 突击：用了立旗、下一场战斗对方先少三成血、旗子撤、次数与冷却记账；免罚的败仗只对节点敌人，配额用完照扣")
	var c := _content()
	var marcus := _character(c, &"marcus")
	var s := _start(c, marcus)
	if s == null:
		t.check(false, "开不了局")
		return
	var skill := s.skills.active_skills()[0] as AssaultSkill
	var uses0 := s.skills.uses_of(skill.id)
	t.eq(s.skills.can_use(skill.id), "", "能用")
	t.eq(s.use_skill(skill.id), "", "用了")
	t.check(s.skills.is_armed(skill.id), "立了旗")
	t.eq(s.skills.uses_of(skill.id), uses0 - 1 if uses0 > 0 else -1, "次数少一")
	t.eq(s.skills.cooldown_of(skill.id), skill.cooldown_steps, "冷却 = 字段")
	t.ne(s.skills.can_use(skill.id), "", "已准备 / 冷却中不能再用：%s" % s.skills.can_use(skill.id))
	var node := _battle_node(s)
	t.not_null(node, "图上有带敌人的点")
	if node == null:
		return
	var plain := EnemyKit.spec_of(node.content, c.enemies, s.pool, c.items)
	s.events.fight_content(node, &"battle", node.content)
	var fought: CombatantSpec = s.events.last_battle["enemy"]
	t.eq(fought.max_hp, maxi(1, int(roundf(float(plain.max_hp) * (1.0 - skill.hp_fraction)))), "对方的生命上限先扣了 %.0f%%" % (skill.hp_fraction * 100.0))
	t.check(not s.skills.is_armed(skill.id), "打完旗子撤了")
	s.events.fight_content(node, &"battle", node.content)
	t.eq((s.events.last_battle["enemy"] as CombatantSpec).max_hp, plain.max_hp, "再打一场：没旗子，原样")
	# 冷却按步减
	var cd := s.skills.cooldown_of(skill.id)
	if cd > 0 and s.phase == RunState.Phase.ON_MAP and not s.travel.available_moves().is_empty():
		s.step_to(s.travel.available_moves()[0])
		t.eq(s.skills.cooldown_of(skill.id), cd - 1, "走一步冷却少一")
	# 次数用完
	s.skills.cooldowns[String(skill.id)] = 0
	s.skills.uses_left[String(skill.id)] = 0
	t.check(s.skills.can_use(skill.id).contains("用完"), "次数 0：用完了")

	# 免罚的败仗：安德烈乌斯，玩家用一个打不赢的单位
	var andreus := _character(c, &"andreus")
	var s2 := _start(c, andreus)
	if s2 == null:
		t.check(false, "开不了局")
		return
	var quota := s2.buff_context().free_losses
	s2.hooks.register(&"player_spec", func() -> CombatantSpec: return BattleCompiler.compile_board(null))
	var node2 := _battle_node(s2)
	var cost := s2.node_rules.loss_cost_of(&"battle")
	var v0 := s2.vitality.current
	# 猎手那一类不免罚
	var won := s2.events.fight_content(node2, HunterSystem.TYPE, node2.content)
	t.check(not won, "没打赢")
	t.eq(s2.vitality.current, v0 - s2.node_rules.loss_cost_of(HunterSystem.TYPE), "输给猎手照扣（配额不动）")
	t.eq(s2.events.losses_forgiven, 0, "配额没用")
	v0 = s2.vitality.current
	for i in quota:
		s2.events.fight_content(node2, &"battle", node2.content)
		t.eq(s2.vitality.current, v0, "第 %d 次输给节点敌人不扣体力" % (i + 1))
	t.eq(s2.events.losses_forgiven, quota, "免了 %d 次" % quota)
	s2.events.fight_content(node2, &"battle", node2.content)
	t.eq(s2.vitality.current, v0 - cost, "配额用完：照扣 %d" % cost)


static func run_evade(t: TestCase) -> void:
	t.begin("技能 · 躲避：用了之后猎手够不着，走够步数才又够得着")
	var c := _content()
	var andreus := _character(c, &"andreus")
	var hid: Array = c.hunter_defs.keys()
	hid.sort()
	if andreus == null or hid.is_empty():
		t.check(false, "缺角色或猎手")
		return
	var defs := {}
	var hdef: HunterDef = (c.hunter_defs[hid[0]] as HunterDef).duplicate(true)
	hdef.engage_range = 0.0
	hdef.speed = 0
	defs[hdef.id] = hdef
	var diff := DifficultyDef.new()
	diff.id = &"probe"
	var m := HunterMechanic.new()
	m.hunter_ids = [hdef.id] as Array[StringName]
	m.spawn_min_distance = 0.0
	diff.mechanics.append(m)
	var s := _start(c, andreus, diff, defs)
	if s == null:
		t.check(false, "开不了局")
		return
	s.step_to(s.travel.available_moves()[0])
	var sys := s.hunters
	var h: Hunter = sys.alive()[0]
	var evade := s.skills.active_skills()[0] as EvadeSkill
	s.events.pending = {}
	t.eq(s.use_skill(evade.id), "", "用了躲避")
	t.eq(s.skills.evade_left, evade.steps, "躲 %d 步" % evade.steps)
	h.node_id = s.travel.current_id
	h.cooldown = 0
	t.check(not sys.check_engagement(), "躲避中：猎手在脚下也不开打")
	t.check(s.events.pending.is_empty(), "没有排上迎战屏")
	var walked := 0
	while s.skills.evading() and s.phase == RunState.Phase.ON_MAP and not s.travel.available_moves().is_empty():
		s.step_to(s.travel.available_moves()[0])
		walked += 1
		if walked > evade.steps + 1:
			break
	t.eq(walked, evade.steps, "走了 %d 步躲避才过去" % evade.steps)
	if s.phase == RunState.Phase.ON_MAP:
		s.events.pending = {}
		h.node_id = s.travel.current_id
		h.cooldown = 0
		h.alive = true
		t.check(sys.check_engagement(), "躲避过了：又够得着")


static func run_save_load(t: TestCase) -> void:
	t.begin("技能 · 存档：次数、冷却、立的旗、躲避、免罚次数都跟着走；读档由持有方按 id 接回角色")
	var c := _content()
	var marcus := _character(c, &"marcus")
	_cleanup()
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f.chapters = [c.chapter] as Array[ChapterDef]
	f.characters = c.characters
	f.save_path = SAVE
	f.meta_path = META
	var run: RunState = null
	for seed in range(1, 60):
		run = f.begin(c.chapter, null, seed, [] as Array[int], marcus, [])
		if run != null:
			break
	if run == null:
		t.check(false, "开不了局")
		return
	f.pick_spawn(run.map.entry_ids[0])
	var skill := run.skills.active_skills()[0] as RunSkill
	t.eq(f.use_skill(skill.id), "", "用了")
	run.skills.evade_left = 2
	run.events.losses_forgiven = 1
	var before := run.skills.to_dict()
	t.check(f.save(), "存档")
	var f2 := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f2.chapters = [c.chapter] as Array[ChapterDef]
	f2.characters = c.characters
	f2.save_path = SAVE
	f2.meta_path = META
	t.check(f2.continue_run(), "读档")
	t.eq(f2.run.character, marcus, "找回了角色定义")
	t.eq(f2.run.skills.to_dict(), before, "技能的账原样")
	t.check(f2.run.skills.is_armed(skill.id), "旗子还立着")
	t.eq(f2.run.events.losses_forgiven, 1, "免罚次数还在")
	t.eq(f2.run.skills.can_use(skill.id), run.skills.can_use(skill.id), "能不能用的判断一致")
	_cleanup()
