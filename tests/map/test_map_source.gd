## 地图来源（随机 / 预设）与预设文件的存取（架构文档 5.3.1）。
extends RefCounted

const TMP := "user://test_map_preset.json"


static func _sample_graph() -> MapGraph:
	return RingMapGenerator.new().generate(RingMapConfig.sample(4), 21)


static func run_preset_roundtrip(t: TestCase) -> void:
	t.begin("预设地图 · 存了再读，一个字不差")

	var g := _sample_graph()
	t.not_null(g, "先有一张图")
	t.eq(MapPreset.save(g, TMP), OK, "存得下")
	var back := MapPreset.load_graph(TMP)
	t.not_null(back, "读得回")
	if back != null:
		t.eq(JSON.stringify(back.to_dict()), JSON.stringify(g.to_dict()),
			"读回来的图与存进去的逐字节相同")
		# 环形图的校验读得懂读回来的图（JSON 的字典键是字符串，槽位表要两种都认）
		var v := MapValidation.new()
		RingMapGenerator.new().validate(back, v)
		t.check(v.ok(), "读回来的图过得了环形图自己的校验：%s" % v.to_text())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


static func run_random_mode(t: TestCase) -> void:
	t.begin("地图来源 · 随机生成")

	var src := MapSource.new()
	src.mode = MapSource.Mode.RANDOM
	src.generator_id = &"ring"
	src.generator_config = RingMapConfig.sample(4)
	var a := src.resolve(5)
	var b := src.resolve(5)
	t.not_null(a, "生成得出来")
	t.eq(JSON.stringify(b.to_dict()), JSON.stringify(a.to_dict()), "同一个对局种子，同一张图")
	t.ne(JSON.stringify(src.resolve(6).to_dict()), JSON.stringify(a.to_dict()), "换个种子就换一张")

	src.generator_id = &"no_such_generator"
	t.is_null(src.resolve(5), "没登记的生成器 → null")
	t.check(src.last_error != "", "而且说得出原因：%s" % src.last_error)


static func run_preset_mode(t: TestCase) -> void:
	t.begin("地图来源 · 载入预设")

	var g := _sample_graph()
	MapPreset.save(g, TMP)

	var src := MapSource.new()
	src.mode = MapSource.Mode.PRESET
	src.preset_path = TMP

	# 地形定死，内容种子按对局重掷
	src.reroll_content_seeds = true
	var a := src.resolve(100)
	var b := src.resolve(200)
	t.not_null(a, "载得进来")
	t.eq(a.node_ids(), g.node_ids(), "点还是那些点")
	t.eq(a.edges.size(), g.edges.size(), "路还是那些路")
	var differs := false
	for id in a.node_ids():
		if a.get_node(id).content_seed != b.get_node(id).content_seed:
			differs = true
	t.check(differs, "两局的内容种子不一样 —— 同一张图，每次刷出来的东西不同")
	t.eq(JSON.stringify(src.resolve(100).to_dict()), JSON.stringify(a.to_dict()),
		"同一个对局种子则完全相同")

	src.reroll_content_seeds = false
	t.eq(JSON.stringify(src.resolve(100).to_dict()), JSON.stringify(g.to_dict()),
		"关掉重掷 → 连内容也原样照搬")

	# 一张走不通的图不许当预设用
	var broken := MapGraph.from_dict(g.to_dict())
	for e in broken.edges_of(broken.entry_ids[0]):
		broken.remove_edge(e)
	MapPreset.save(broken, TMP)
	t.is_null(src.resolve(1), "出生点被孤立的图 → 拒绝载入")
	t.check(src.last_error.contains("校验"), "原因指向校验：%s" % src.last_error.left(60))

	src.preset_path = "user://definitely_not_here.json"
	t.is_null(src.resolve(1), "文件不在 → null")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
