## 章节定义走内容管线（架构文档 10，M3-5）。
##
## 这是对「导入器不认识具体类型」的**第一次真实检验**：此前它只喂过道具、增益、套装
## 三种同源的东西。章节配置结构完全不同（嵌套的 Resource、枚举、Vector2、字典里套数组），
## 喂得进去、往返不掉字，才算证明了那条性质。
extends RefCounted


static func _ctx() -> ContentImporter.Context:
	return ContentImporter.Context.new()


static func _sample() -> ChapterDef:
	var c := ChapterDef.new()
	c.id = &"t_chapter"
	c.display_name = "测试章"
	c.map_source = MapSource.new()
	c.map_source.generator_id = &"ring"
	c.map_source.generator_config = RingMapConfig.sample(6)
	return c


static func run_round_trip(t: TestCase) -> void:
	t.begin("章节管线 · 导出再导入，逐字节一致")

	var chapter := _sample()
	var dumped := ContentExporter.export_chapter(chapter)
	t.eq(String(dumped.get("id", "")), "t_chapter", "id 导出了")
	var ms: Dictionary = dumped.get("map_source", {})
	t.check(ms.has("generator_config"), "嵌套的 Resource 导出了")
	var cfg_json: Dictionary = ms["generator_config"]
	t.eq(String(cfg_json.get("type", "")), "RingMapConfig",
		"字段声明成 Resource 的，导出时带 type —— 不然导入器不知道该造哪个类")
	t.check(cfg_json.has("rings") and (cfg_json["rings"] as Array).size() == 6, "环的数组导出了")
	t.check(cfg_json.has("routes"), "路线风格导出了")
	var route0: Dictionary = (cfg_json["routes"] as Array)[0]
	t.check(route0.has("risk_band") and (route0["risk_band"] as Array).size() == 2, "Vector2 导成 [x, y]")

	# 过一遍 JSON 文本：整数会变浮点、StringName 变字符串 —— 往返得扛得住
	var text := ContentExporter.to_json(dumped)
	var parsed: Dictionary = JSON.parse_string(text)
	var report := ImportReport.new()
	var back := ContentImporter.import_chapter(parsed, _ctx(), report)
	t.check(report.ok(), "导得回来：%s" % report.to_text())
	if back == null:
		return
	t.eq(back.id, &"t_chapter", "id 是 StringName")
	t.check(back.map_source != null and back.map_source.generator_config is RingMapConfig,
		"generator_config 造成了 RingMapConfig")
	var cfg: RingMapConfig = back.map_source.generator_config
	t.eq(cfg.ring_count(), 6, "六个环")
	t.eq(cfg.routes.size(), 3, "三种路线风格")
	t.eq(cfg.routes[0].risk_band, chapter.map_source.generator_config.routes[0].risk_band, "Vector2 读回来一样")
	t.eq(cfg.rings[0].quota, chapter.map_source.generator_config.rings[0].quota,
		"字典里套数组的配额读回来一样（整数没变成浮点）")
	t.eq(cfg.zone_spec != null, true, "高危区配置在")
	t.eq(cfg.scales.size(), 3, "三档规模模板")
	t.eq(ContentExporter.to_json(ContentExporter.export_chapter(back)), text,
		"**再导出一次，文本逐字节相同**")


static func run_generates(t: TestCase) -> void:
	t.begin("章节管线 · 导入的章节能直接生成同一张图")

	var chapter := _sample()
	var text := ContentExporter.to_json(ContentExporter.export_chapter(chapter))
	var report := ImportReport.new()
	var back := ContentImporter.import_chapter(JSON.parse_string(text), _ctx(), report)
	t.check(report.ok(), "导得回来")
	if back == null:
		return
	var a := chapter.map_source.resolve(42)
	var b := back.map_source.resolve(42)
	t.not_null(b, "导入的章节生成得出图")
	if a != null and b != null:
		t.eq(JSON.stringify(b.to_dict()), JSON.stringify(a.to_dict()),
			"同一个对局种子，导入前后生成的是同一张图 —— 配置一个字段都没丢")


static func run_validation(t: TestCase) -> void:
	t.begin("章节管线 · 比引擎严格")

	var base := ContentExporter.export_chapter(_sample())

	var no_id := base.duplicate(true)
	no_id.erase("id")
	var r := ImportReport.new()
	ContentImporter.import_chapter(no_id, _ctx(), r)
	t.check(not r.ok(), "没有 id → 错")

	var no_source := base.duplicate(true)
	no_source.erase("map_source")
	r = ImportReport.new()
	ContentImporter.import_chapter(no_source, _ctx(), r)
	t.check(not r.ok(), "没有 map_source → 错")

	var bad_gen := base.duplicate(true)
	(bad_gen["map_source"] as Dictionary)["generator_id"] = "no_such_generator"
	r = ImportReport.new()
	ContentImporter.import_chapter(bad_gen, _ctx(), r)
	t.check(not r.ok(), "没登记的生成器 → 错")
	t.check(r.to_text().contains("no_such_generator"), "报错说得出是哪个名字")

	var bad_type := base.duplicate(true)
	((bad_type["map_source"] as Dictionary)["generator_config"] as Dictionary)["type"] = "ItemDef"
	r = ImportReport.new()
	ContentImporter.import_chapter(bad_type, _ctx(), r)
	t.check(not r.ok(), "generator_config 造成了别的类 → 错")

	var typo := base.duplicate(true)
	((typo["map_source"] as Dictionary)["generator_config"] as Dictionary)["entry_cont"] = 3
	r = ImportReport.new()
	ContentImporter.import_chapter(typo, _ctx(), r)
	t.check(not r.ok(), "打错字段名 → 错，不是静默当默认值")

	var preset := base.duplicate(true)
	(preset["map_source"] as Dictionary)["mode"] = "PRESET"
	(preset["map_source"] as Dictionary)["preset_path"] = "res://data/maps/none.json"
	r = ImportReport.new()
	ContentImporter.import_chapter(preset, _ctx(), r)
	t.check(not r.ok(), "载入预设但文件不在 → 错")

	# 枚举按名字写
	var by_name := base.duplicate(true)
	(by_name["map_source"] as Dictionary)["mode"] = "RANDOM"
	r = ImportReport.new()
	var ok := ContentImporter.import_chapter(by_name, _ctx(), r)
	t.check(r.ok() and ok.map_source.mode == MapSource.Mode.RANDOM, "枚举按名字写得进")


static func run_authoring_file(t: TestCase) -> void:
	t.begin("章节管线 · 仓库里的第一章导得进、与资产一致")

	var path := ContentPaths.authoring_file("chapters", "free_mode")
	t.check(FileAccess.file_exists(path), "有 %s" % path)
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	var r := ImportReport.new()
	var chapter := ContentImporter.import_chapter(JSON.parse_string(text), _ctx(), r)
	t.check(r.ok(), "导得进：%s" % r.to_text())
	if chapter == null:
		return
	t.eq(ContentExporter.to_json(ContentExporter.export_chapter(chapter)), text,
		"仓库里的作者数据就是导出器的格式，往返逐字节相同")

	var asset := ContentPaths.asset_file("chapters", "free_mode")
	t.check(ResourceLoader.exists(asset), "有导入产出的 %s" % asset)
	if ResourceLoader.exists(asset):
		var loaded: ChapterDef = load(asset)
		t.check(loaded != null and loaded.map_source != null, "资产读得出来")
		if loaded != null:
			# .tres 存字典时会重排键的顺序，所以比的是导出的字典，不是文本
			t.eq(ContentExporter.export_chapter(loaded), ContentExporter.export_chapter(chapter),
				"资产与作者数据一致 —— 改了 JSON 忘了导入，这条会红")
			var g := loaded.map_source.resolve(1)
			t.not_null(g, "第一章生成得出图")
