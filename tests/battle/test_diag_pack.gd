## 平衡检测方案（2026-11-10）§5：战斗诊断包 —— 普通武器、状态伤害、信仰、局外加成、品质与耐久（晶石）、特殊角色各一场，
## 抓包 → 存盘 → 读回 → 重跑，胜方、时长、逐条事件、最终资源都一样；抓的是深拷贝；坏包、缺规则、构建对不上有明确结论；
## 正式一局开着诊断打一场会落一份包，重跑不动存档
extends RefCounted

const DIR := "user://test_diag_packs"


static func _cleanup() -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(DIR.path_join(f))
	DirAccess.remove_absolute(DIR)


static func _items() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	r.randi()     # 先抽一下：开打前随机数已经走过几步（只记种子不够）
	return r


static func _board(ids: Array, size: Vector2i, db: ItemDatabase) -> GridInventory:
	var typed: Array[StringName] = []
	for i in ids:
		typed.append(StringName(i))
	return LootPacker.board_of(typed, size, db)


static func _foe(db: ItemDatabase) -> CombatantSpec:
	return BattleCompiler.compile_board(_board(["knife", "salve"], Vector2i(4, 4), db), CombatantBaseline.with_hp(120.0))


## 六类场景：[名字, 我方, 对方]
static func _scenarios(db: ItemDatabase) -> Array:
	var out: Array = []
	out.append(["普通武器", BattleCompiler.compile_board(_board(["longsword", "shortsword"], Vector2i(5, 5), db), CombatantBaseline.with_hp(100.0)), _foe(db)])
	out.append(["状态伤害", BattleCompiler.compile_board(_board(["poisoned_knife", "bloodletter"], Vector2i(5, 5), db), CombatantBaseline.with_hp(100.0)), _foe(db)])
	var faith := CompileInput.of(CombatantBaseline.with_hp(100.0))
	faith.faith_tiers = {&"faith:brute": 3}
	out.append(["信仰", BattleCompiler.compile(_board(["charm_brute", "battle_axe"], Vector2i(5, 5), db), faith), _foe(db)])
	var meta := CompileInput.of(CombatantBaseline.with_hp(100.0))
	meta.mods.append(StatModifier.make(&"damage", StatModifier.Mode.MULT, 20.0))
	meta.axes[&"attack_speed"] = 1
	out.append(["局外加成", BattleCompiler.compile(_board(["longsword"], Vector2i(5, 5), db), meta), _foe(db)])
	var staff := _board(["magic_staff", "fire_crystal"], Vector2i(6, 6), db)
	for inst in staff.items():
		(inst as ItemInstance).set_quality(2)
	out.append(["品质与耐久", BattleCompiler.compile_board(staff, CombatantBaseline.with_hp(100.0)), _foe(db)])
	var hero := CompileInput.of(CombatantBaseline.with_hp(60.0))
	hero.keep_undying(3.0)
	hero.immune_buffs.append(&"poison")
	out.append(["特殊角色", BattleCompiler.compile(_board(["twin_blades"], Vector2i(5, 5), db), hero),
		BattleCompiler.compile_board(_board(["poisoned_knife", "longsword"], Vector2i(5, 5), db), CombatantBaseline.with_hp(150.0))])
	return out


static func run_roundtrip(t: TestCase) -> void:
	t.begin("诊断包：六类场景存盘读回重跑都一样")
	_cleanup()
	var db := _items()
	var i := 0
	for sc in _scenarios(db):
		i += 1
		var name := String(sc[0])
		var rng := _rng(900 + i)
		var pack := BattleDiagPack.capture(sc[1], sc[2], rng, 30.0, null, {"battle_id": "test:%d" % i})
		var result := BattleSim.run(sc[1], sc[2], rng, 30.0, null)
		pack.expected = BattleDiagPack.summary(result)
		t.check(int(pack.expected["events"]) > 3, "%s：打出了事件（%d 条）" % [name, pack.expected["events"]])
		var path := BattleDiagnostics.write(pack, "case_%d" % i, DIR)
		t.check(path != "", "%s：写得出来（%.1f ms，%d 字节）" % [name, BattleDiagnostics.last_ms, BattleDiagnostics.last_bytes])
		var back := BattleDiagnostics.load_pack(path)
		t.not_null(back, "%s：读得回来" % name)
		if back == null:
			continue
		t.eq(back.problems(), [] as Array[String], "%s：包完整" % name)
		var diff := BattleDiagPack.compare(back.expected, BattleDiagPack.summary(back.rerun()))
		t.eq(diff, {}, "%s：重跑逐条一致" % name)
	_cleanup()


static func run_deep_copy_and_compare(t: TestCase) -> void:
	t.begin("诊断包：抓的是深拷贝；比对报第一处不同")
	var db := _items()
	var me := BattleCompiler.compile_board(_board(["longsword"], Vector2i(5, 5), db), CombatantBaseline.with_hp(100.0))
	var foe := _foe(db)
	var rng := _rng(5)
	var pack := BattleDiagPack.capture(me, foe, rng, 30.0, null)
	pack.expected = BattleDiagPack.summary(BattleSim.run(me, foe, rng, 30.0, null))
	me.max_hp = StatMath.from_float(1.0)     # 抓完再改原来的
	me.items[0].stats.set_base(&"damage", 0)
	t.eq(BattleDiagPack.compare(pack.expected, BattleDiagPack.summary(pack.rerun())), {}, "改原来的 spec 不影响包")
	var want := pack.expected.duplicate(true)
	var lines: Array = want["lines"]
	lines[2] = "x"
	var diff := BattleDiagPack.compare(want, BattleDiagPack.summary(pack.rerun()))
	t.eq(diff.get("field"), "event", "事件不同")
	t.eq(diff.get("index"), 2, "报第 2 条")
	want["winner"] = 9
	t.eq(BattleDiagPack.compare(want, pack.expected).get("field"), "winner", "胜方不同先报胜方")
	pack.rules.append(null)
	t.check(not pack.problems().is_empty(), "规则表有空位：不完整")
	pack.format = 99
	t.check(pack.problems()[0].begins_with("format"), "格式不认得")


static func run_bad_files(t: TestCase) -> void:
	t.begin("诊断包：不存在、滚动清理与固定导出")
	_cleanup()
	t.is_null(BattleDiagnostics.load_pack(DIR.path_join("none" + BattleDiagPack.EXT)), "不存在：null")
	var db := _items()
	var me := BattleCompiler.compile_board(_board(["knife"], Vector2i(4, 4), db), CombatantBaseline.with_hp(50.0))
	for k in 4:
		var pack := BattleDiagPack.capture(me, _foe(db), _rng(k), 10.0, null)
		BattleDiagnostics.write(pack, "2026%02d" % k, DIR, 3)
	t.eq(BattleDiagnostics.list(DIR).size(), 3, "只留最近 3 份")
	t.eq(BattleDiagnostics.list(DIR)[0], "202601" + BattleDiagPack.EXT, "删的是最旧的")
	var pinned_dir := DIR.path_join("pinned")
	var pinned := BattleDiagnostics.pin(DIR.path_join(BattleDiagnostics.list(DIR)[0]), pinned_dir)
	t.check(pinned != "" and FileAccess.file_exists(pinned), "固定导出复制了一份")
	BattleDiagnostics.prune(DIR, 0)
	t.check(FileAccess.file_exists(pinned), "清理不动固定导出的")
	DirAccess.remove_absolute(pinned)
	DirAccess.remove_absolute(pinned_dir)
	_cleanup()


static func run_real_run_capture(t: TestCase) -> void:
	t.begin("诊断包：正式一局开着诊断打一场，落一份包，重跑一致、不动存档")
	_cleanup()
	var db := _items()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	var s: RunState = null
	for seed_ in range(1, 60):
		s = RunState.start(chapter, seed_, db, enemies, sets)
		if s != null:
			s.pick_spawn(s.map.entry_ids[0])
			break
	if s == null:
		t.check(false, "开不了局")
		return
	var node: MapNode = null
	for id in s.map.node_ids():
		var n := s.map.get_node(id)
		if n.type == &"battle" and EnemyKit.has_enemy(n.content):
			node = n
			break
	if node == null:
		t.check(false, "图上没有带敌人的点")
		return
	t.check(s.run_id.begins_with("run-"), "开局就有局标识")
	BattleDiagnostics.enabled = true
	BattleDiagnostics.target_dir = DIR
	s.events.trace_info = {"run_id": s.run_id, "chapter": String(chapter.id)}
	var won := s.events.fight_content(node, &"battle", node.content, null, 0)
	BattleDiagnostics.enabled = null
	BattleDiagnostics.target_dir = BattleDiagnostics.DIR
	s.events.trace_info = {}
	var files := BattleDiagnostics.list(DIR)
	t.eq(files.size(), 1, "落了一份包")
	if files.is_empty():
		return
	var pack := BattleDiagnostics.load_pack(DIR.path_join(files[0]))
	t.not_null(pack, "读得回来")
	if pack == null:
		return
	t.eq(int(pack.expected["winner"]) == 0, won, "包里记的胜负和这场一样")
	t.check(String(pack.meta.get("battle_id", "")).begins_with(s.run_id + ":"), "战斗标识 = 局标识 + 种子")
	t.eq(pack.meta.get("source", ""), ExperimentManifest.TEST, "来源是 test")
	var saved := JSON.stringify(s.to_dict(), "", true)
	t.eq(BattleDiagPack.compare(pack.expected, BattleDiagPack.summary(pack.rerun())), {}, "重跑一致")
	t.eq(JSON.stringify(s.to_dict(), "", true), saved, "重跑不动这一局")
	var d := s.to_dict()
	t.eq(String(d.get("run_id", "")), s.run_id, "局标识进存档")
	_cleanup()
