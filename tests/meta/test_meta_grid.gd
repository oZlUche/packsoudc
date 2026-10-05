## 局外格子化（058 第 4 / 6 / 7 条，报告 061）：仓库是格子、大小是规则里的数；撤离棋盘原样带回、一键置入放不下就停；
## 图鉴累计件数、点亮一次；带回来的没清空开不了新局；存档 v2 往返。
extends RefCounted

const SAVE := "user://test_meta_grid_run.json"
const META := "user://test_meta_grid_meta.json"


class Content:
	extends RefCounted
	var items: ItemDatabase
	var enemies: EnemyDatabase
	var sets: SetDatabase
	var chapter: ChapterDef
	var loadouts: Array[LoadoutDef]
	var rules: MetaRules


static func _content() -> Content:
	var c := Content.new()
	c.items = ItemDatabase.new()
	c.items.load_dir()
	c.enemies = EnemyDatabase.new()
	c.enemies.load_all()
	c.sets = SetDatabase.new()
	c.sets.load_dir()
	c.chapter = load(ContentPaths.asset_file("chapters", "free_mode"))
	c.loadouts = GameFlow.load_loadouts()
	c.rules = GameFlow.load_meta_rules()
	return c


static func _kit(c: Content) -> LoadoutDef:
	for l in c.loadouts:
		if l.id == &"standard":
			return l
	return c.loadouts[0]


static func _flow(c: Content, rules: MetaRules = null) -> GameFlow:
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new(rules if rules != null else c.rules))
	f.meta_rules = rules if rules != null else c.rules
	f.chapters = [c.chapter] as Array[ChapterDef]
	f.loadouts = c.loadouts
	f.save_path = SAVE
	f.meta_path = META
	f.player_baseline = CombatantBaseline.with_hp(10000.0)
	return f


## 一局直接算撤离
static func _extracted(c: Content, seed: int, kit: LoadoutDef) -> RunState:
	var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit.items)
	s.pick_spawn(s.map.entry_ids[0])
	s.phase = RunState.Phase.EXTRACTED
	s.end_reason = &"extract"
	return s


static func _tiny_rules(size: Vector2i) -> MetaRules:
	var r := MetaRules.new()
	r.id = &"t_tiny"
	r.warehouse_size = size
	return r


static func run_rules_pipeline(t: TestCase) -> void:
	t.begin("局外规则 · 走管线：往返、校验、作者文件、资产、GameFlow 取得到")

	var r := MetaRules.new()
	r.id = &"t_meta"
	r.warehouse_size = Vector2i(7, 5)
	var text := ContentExporter.to_json(ContentExporter.export_meta_rules(r))
	var report := ImportReport.new()
	var back := ContentImporter.import_meta_rules(JSON.parse_string(text), ContentImporter.Context.new(), report)
	t.check(report.ok(), "导得回来：%s" % report.to_text())
	t.eq(back.warehouse_size, Vector2i(7, 5), "仓库大小原样")
	t.eq(ContentExporter.to_json(ContentExporter.export_meta_rules(back)), text, "再导出逐字节相同")
	var bad := ImportReport.new()
	ContentImporter.import_meta_rules({"id": "x", "warehouse_size": [0, 3]}, ContentImporter.Context.new(), bad)
	t.check(not bad.ok(), "仓库至少 1×1")

	var dir: String = ContentPaths.KINDS["meta_rules"][0]
	var d := DirAccess.open(dir)
	t.not_null(d, "有 %s" % dir)
	var files := 0
	if d != null:
		for f in d.get_files():
			if not f.ends_with(".json"):
				continue
			files += 1
			var raw := FileAccess.get_file_as_string(dir + "/" + f)
			var rep := ImportReport.new()
			var res := ContentImporter.import_meta_rules(JSON.parse_string(raw), ContentImporter.Context.new(), rep)
			t.check(rep.ok(), "%s 导得进" % f)
			t.eq(ContentExporter.to_json(ContentExporter.export_meta_rules(res)), raw, "%s 是往返不动点" % f)
			t.check(ResourceLoader.exists(ContentPaths.asset_file("meta_rules", f.get_basename())), "%s 的资产在" % f)
	t.check(files >= 1, "至少一份局外规则")
	var loaded := GameFlow.load_meta_rules()
	t.check(loaded != null and loaded.warehouse_size.x > 0, "GameFlow.load_meta_rules 取得到 standard")
	t.eq(MetaState.new(loaded).warehouse.size, loaded.warehouse_size, "仓库大小按规则")
	t.eq(MetaState.new().warehouse.size, MetaRules.DEFAULT_SIZE, "没有规则用默认")


static func run_absorb_board_codex(t: TestCase) -> void:
	t.begin("局外 · 撤离棋盘原样带回（包只计图鉴）；一键置入放不下就停；图鉴累计、点亮一次；存档 v2 往返")

	var c := _content()
	var kit := _kit(c)
	var s := _extracted(c, 21, kit)
	var r := RunResult.settle(s)
	var expected := {}     # 非包：uid → origin
	var bags := 0
	for inst in s.board.items():
		var item := inst as ItemInstance
		if item.def.is_bag:
			bags += 1
		else:
			expected[String(item.def.id) + "@" + str(item.origin)] = true
	t.check(bags >= 1 and expected.size() >= 1, "棋盘上有 %d 个包、%d 件东西" % [bags, expected.size()])

	var m := MetaState.new(_tiny_rules(Vector2i(2, 2)))
	var got := m.absorb(r)
	t.check(m.has_pending_board(), "撤离之后带回来的棋盘等着清")
	t.eq(int(got["items"]), expected.size(), "带回 %d 件非包道具" % expected.size())
	t.eq(m.board.size, s.board.size, "带回来的棋盘和原来一样大")
	t.check(not m.board.requires_bag, "不要求包：所有格子默认可用（包换成默认背景）")
	t.eq(m.board.bags().size(), 0, "包没带回来")
	var at_place := 0
	for inst in m.board.items():
		var item := inst as ItemInstance
		if expected.has(String(item.def.id) + "@" + str(item.origin)):
			at_place += 1
	t.eq(at_place, expected.size(), "每件都在原来的位置上")
	t.eq(m.warehouse.item_count(), 0, "仓库还是空的：没自动进")
	# 图鉴：每件各计一次（含包）、点亮只算一次
	var per_id := {}
	for inst in r.carried:
		var key := String(inst.def.id)
		per_id[key] = int(per_id.get(key, 0)) + 1
	for key in per_id:
		t.eq(m.codex_count(StringName(key)), int(per_id[key]), "图鉴 %s 计 %d 件" % [key, per_id[key]])
	t.eq(int(got["lit"]), per_id.size(), "新点亮 %d 条" % per_id.size())
	t.check(m.codex_lit(&"bag_leather"), "包也点亮图鉴")

	# 一键置入：2×2 的仓库放不下，停在那一件
	var stored := m.store_all()
	t.check(int(stored["moved"]) >= 0 and int(stored["left"]) > 0 and String(stored["stuck"]) != "", "放不下就停：放进 %d、卡在「%s」、剩 %d" % [stored["moved"], stored["stuck"], stored["left"]])
	t.eq(m.warehouse.item_count(), int(stored["moved"]), "仓库里就是放进去的那几件")
	t.check(m.has_pending_board(), "带回来的棋盘还没清空")

	# 第二局撤离：图鉴累加、不再算点亮；带回来的并进去一件不丢
	var s2 := _extracted(c, 22, kit)
	var before := m.board.item_count()
	var got2 := m.absorb(RunResult.settle(s2))
	t.eq(int(got2["lit"]), 0, "同样的东西第二次不算点亮")
	for key in per_id:
		t.eq(m.codex_count(StringName(key)), int(per_id[key]) * 2, "图鉴 %s 累计到 %d" % [key, int(per_id[key]) * 2])
	t.eq(m.board.item_count(), before + int(got2["items"]), "上一次没清完的并进来，一件不丢")

	# 大仓库：全放进去，棋盘清空；uid 两两不同
	var big := MetaState.new(_tiny_rules(Vector2i(12, 12)))
	big.absorb(RunResult.settle(_extracted(c, 23, kit)))
	var n := big.board.item_count()
	var all := big.store_all()
	t.eq(int(all["moved"]), n, "全放进去")
	t.check(not big.has_pending_board() and big.board == null, "棋盘清空了")
	var uids := {}
	for inst in big.warehouse.items():
		uids[(inst as ItemInstance).uid] = true
	t.eq(uids.size(), big.warehouse.item_count(), "仓库里 uid 两两不同")
	big.absorb(RunResult.settle(_extracted(c, 24, kit)))
	big.discard_board()
	t.check(not big.has_pending_board(), "不要了：清掉")

	# 存档 v2 往返
	var text := MetaSave.to_text(m)
	var back := MetaSave.from_text(text, c.items, m.rules)
	t.not_null(back, "读得回来")
	t.eq(MetaSave.to_text(back), text, "再存逐字节相同")
	t.eq(back.warehouse.item_count(), m.warehouse.item_count(), "仓库件数一样")
	t.eq(back.board.item_count(), m.board.item_count(), "带回来的棋盘也在")
	t.eq(back.codex, m.codex, "图鉴一样")
	# 098：v1 现在走迁移链升上来（v1 → v2 是恒等），不再作废；升不上去的版本才是 null
	t.not_null(MetaSave.from_text("{\"version\": 1}", c.items), "旧版（v1）经迁移链读得回来")
	t.is_null(MetaSave.from_text("{\"version\": 0}", c.items), "链上没有这一级（v0）→ null")


static func run_flow_gate(t: TestCase) -> void:
	t.begin("场景流 · 一局结束就记账、存 meta；带回来的棋盘没清空也能开新局（090）；一键置入后能开")

	var c := _content()
	var kit := _kit(c)
	var f := _flow(c)
	var run := f.begin(c.chapter, kit, 31)
	run.phase = RunState.Phase.EXTRACTED
	run.end_reason = &"extract"
	f.resume()
	t.eq(f.screen, GameFlow.Screen.RESULT, "→ 结算")
	t.eq(f.meta.runs, 1, "进结算屏之前账已经记了")
	t.check(f.meta.has_pending_board(), "带回来的棋盘等着")
	t.check(MetaSave.exists(META), "meta 已经存了")
	t.eq(f.can_begin(), "", "090：没清空也能开新局（开局屏把带回来的收到地上，出发就没了）")
	f.finish_result()
	t.eq(f.screen, GameFlow.Screen.META, "→ 局外")
	t.eq(f.meta.runs, 1, "没记两遍")
	var stored := f.store_all()
	t.check(int(stored["moved"]) > 0, "一键置入 %d 件" % stored["moved"])
	t.check(not f.meta.has_pending_board(), "清空了")
	t.eq(f.can_begin(), "", "能开新局了")
	t.eq(MetaSave.read(c.items, META, c.rules).warehouse.item_count(), f.meta.warehouse.item_count(), "置入之后存了")
	t.not_null(f.begin(c.chapter, kit, 33), "开局")
	RunSave.remove(SAVE)
	MetaSave.remove(META)
