## 一局的模块 = [RunState] 的扩展点（101 第 0 刀，作者定：「流程控制器要能扩展、能加东西」）：
##
## **加一种玩法不用改 RunState** —— 一个 [RunModule] 子类，写进章节清单（或难度清单、或跑起来临时装），
## 开局自己接线、存档存自己那份、读档拿回同一份字典。重复装是幂等的。
## 保险箱（[SafeModule]）是第一个搬出来的样板：状态、存档、「走开就关上」的接线全在它自己身上。
extends RefCounted


## 测试用的假模块：记下自己被装了几次、装的时候一局是什么样
class FakeModule:
	extends RunModule

	var installs: int = 0
	var steps: int = 0
	var saw_map: bool = false
	var restored: Dictionary = {}
	var input_seen: Dictionary = {}

	func id() -> StringName:
		return &"fake_test"

	func describe() -> String:
		return "测试用的假模块"

	func install(run: RunState) -> void:
		installs += 1
		saw_map = run.map != null and run.travel != null and run.events != null
		input_seen = run.module_input(id())
		if not run.leaving.is_connected(_on_leaving):
			run.leaving.connect(_on_leaving)

	func to_dict() -> Dictionary:
		return {"steps": steps}

	func restore(d: Dictionary) -> void:
		restored = d.duplicate(true)
		steps = int(d.get("steps", 0))

	func _on_leaving(_node_id: int) -> void:
		steps += 1


static func _content() -> Dictionary:
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	return {"items": items, "enemies": enemies, "sets": sets,
		"chapter": load(ContentPaths.asset_file("chapters", "free_mode")) as ChapterDef}


static func run_install_and_save(t: TestCase) -> void:
	t.begin("101 第 0 刀 · 章节清单里的模块：开局装上（骨架都造好了）、订阅到生命周期信号、存进 modules[id]、读档拿回同一份")
	var c := _content()
	var chapter := (c["chapter"] as ChapterDef).duplicate(true) as ChapterDef     # 不动真内容
	var fake := FakeModule.new()
	var mods: Array[RunModule] = [fake, SafeModule.new()]
	chapter.modules = mods
	var run: RunState = null
	for seed in range(1, 40):
		run = RunState.start(chapter, seed, c["items"], c["enemies"], c["sets"], [] as Array[StringName], {},
			[] as Array[StringName], null, [], null, {}, &"", {&"fake_test": {"hello": 1}})
		if run != null:
			break
	if run == null:
		t.check(false, "开不出一局")
		return
	run.pick_spawn(run.map.entry_ids[0])
	t.eq(fake.installs, 1, "装了一次")
	t.check(fake.saw_map, "装的时候地图、旅程、节点事件都造好了（能接信号）")
	t.eq(fake.input_seen, {"hello": 1}, "拿到了外面给它的运行时输入（module_inputs）")
	t.check(run.module(&"fake_test") == fake, "module(id) 取得到")
	t.check(run.module(&"根本没装") == null, "没装的返回 null")
	t.check(run.module_lines().has("测试用的假模块"), "describe() 进规则卡：%s" % str(run.module_lines()))
	t.check(SafeModule.of(run) != null, "同一份清单里的保险箱也装上了")

	# 生命周期：走一步 → leaving 发出来，模块自己记账
	var moves := run.travel.available_moves()
	if not moves.is_empty() and run.step_to(moves[0]):
		t.eq(fake.steps, 1, "走一步：模块收到 leaving")

	# 再装一次是幂等的（读档路径会这么做）
	run.install_modules()
	t.eq(fake.installs, 2, "再 install 一次（幂等，不换对象）")
	t.check(run.module(&"fake_test") == fake, "还是同一个对象")
	t.eq(fake.steps, 1, "信号没接第二遍（不会重复记账）")

	# 存档：自己那份在 modules[id] 下
	var saved := run.to_dict()
	t.eq(int(saved["version"]), RunState.SAVE_VERSION, "版本是当前版本")
	var mod_saved: Dictionary = saved["modules"]
	t.eq(int((mod_saved["fake_test"] as Dictionary)["steps"]), fake.steps, "模块的状态存在 modules[id] 下")
	t.check(mod_saved.has("safe"), "保险箱也有自己那份")
	t.check(not saved.has("safe") and not saved.has("safe_locked"), "顶层不再有 safe / safe_locked（v2）")

	# 读档：restore 拿到同一份字典，然后 install
	var chapter_back := chapter.duplicate(true) as ChapterDef
	var fake_back := FakeModule.new()
	var mods_back: Array[RunModule] = [fake_back, SafeModule.new()]
	chapter_back.modules = mods_back
	var back := RunState.from_dict(saved, chapter_back, c["items"], c["enemies"], c["sets"])
	t.not_null(back, "读得回来")
	if back == null:
		return
	t.eq(fake_back.restored, {"steps": fake.steps}, "restore 收到的就是存下去那一份")
	t.eq(fake_back.steps, fake.steps, "状态接上了")
	t.eq(fake_back.installs, 1, "读档也装了一次")
	t.check(back.module(&"fake_test") == fake_back, "读回来的一局里是新那个对象")


static func run_safe_module(t: TestCase) -> void:
	t.begin("101 第 1 刀 · 保险箱搬成模块：RunState 不再认识它；走开就关上；存档在 modules.safe 下；没装 = 没有保险箱")
	var c := _content()
	var run: RunState = null
	for seed in range(1, 40):
		run = RunState.start(c["chapter"], seed, c["items"], c["enemies"], c["sets"])
		if run != null:
			break
	if run == null:
		t.check(false, "开不出一局")
		return
	run.pick_spawn(run.map.entry_ids[0])
	var safe := SafeModule.of(run)
	t.not_null(safe, "默认清单（RunModules.standard）里有保险箱")
	if safe == null:
		return
	t.eq(safe.inventory.id, SafeModule.CONTAINER_ID, "容器 id 还是 092 那个 3（存档按它认）")
	t.check(safe.is_open(), "一开始能开")
	t.check(not safe.lock(), "空着关不算关")
	# 放一件进去再走一步：走开 = 关上
	var item: ItemInstance = null
	for inst in run.board.items():
		if not (inst as ItemInstance).def.is_bag:
			item = inst
			break
	if item != null and InventoryService.transfer_auto(run.board, item.uid, safe.inventory):
		var closed_count := [0]
		safe.closed.connect(func(n: int): closed_count[0] = n)
		var moves := run.travel.available_moves()
		if not moves.is_empty() and run.step_to(moves[0]):
			t.check(safe.locked and not safe.is_open(), "走开了：锁上")
			t.eq(closed_count[0], 1, "发了 closed（界面写那一句）")
		t.check(not safe.lock(), "锁过不重复")

	# 章节列了别的模块 = 这一局没有保险箱：取它的人都得受得住 null
	var chapter2 := (c["chapter"] as ChapterDef).duplicate(true) as ChapterDef
	var only_fake: Array[RunModule] = [FakeModule.new()]
	chapter2.modules = only_fake
	var run2: RunState = null
	for seed in range(1, 40):
		run2 = RunState.start(chapter2, seed, c["items"], c["enemies"], c["sets"])
		if run2 != null:
			break
	if run2 != null:
		t.is_null(SafeModule.of(run2), "没列保险箱 = 这一局没有")
		var r := RunResult.settle(run2)
		t.check(r == null or r.safe_items.is_empty(), "结算也不认为有保险箱里的东西")


static func run_registry_and_content(t: TestCase) -> void:
	t.begin("101 第 0 刀 · 注册表与内容：模块是构件（按 type 名造），章节 JSON 能列；难度机制走同一张表")
	t.check(RunRegistry.TABLES.has(&"run_module"), "注册表有 run_module 这张表")
	t.check(RunRegistry.has_type(&"run_module", &"safe"), "保险箱登记了")
	for type_name in [&"erosion", &"hunters"]:
		t.check(RunRegistry.has_type(&"run_module", type_name), "%s（069 的机制）在同一张表里" % type_name)
		t.check(RunRegistry.has_type(&"run_mechanic", type_name), "旧键名还认得 %s（别名）" % type_name)
	var made := RunRegistry.instantiate(&"run_module", &"safe")
	t.check(made is SafeModule and (made as SafeModule).id() == SafeModule.ID, "造得出来、id 对")
	t.check(ContentSchema.ABSTRACT_ROOTS.has(&"RunModule"), "导入器认得 Array[RunModule]（抽象基类 → 表）")
	# 章节 JSON 里列一条就能导进来
	var ctx := ContentImporter.Context.new()
	var report := ImportReport.new()
	# 拿真章节导出来的那份当底子（map_source 这种子对象的形状以导出器为准）
	var data := ContentExporter.export_chapter(_content()["chapter"] as ChapterDef)
	data["id"] = "test_modules_chapter"
	data["modules"] = [{"type": "safe", "size": [4, 4]}]
	var ch := ContentImporter.import_chapter(data, ctx, report)
	t.check(ch != null and report.ok(), "章节带 modules 导得进来：%s" % report.to_text())
	if ch != null and not ch.modules.is_empty():
		var sm := ch.modules[0] as SafeModule
		t.check(sm != null and sm.size == Vector2i(4, 4), "参数（几格）按反射填进去了")
	# 往返：导出再导入一致
	if ch != null:
		var dumped := ContentExporter.export_chapter(ch)
		t.check((dumped.get("modules", []) as Array).size() == 1, "导出带着 modules")
		var again := ContentImporter.import_chapter(dumped, ContentImporter.Context.new(), ImportReport.new())
		t.check(again != null and again.modules.size() == 1, "往返回来还在")


static func run_module_roster(t: TestCase) -> void:
	t.begin("101 第 1 刀 · 六个子系统都搬成了模块：默认清单里各一个、各自登记在注册表里有中文名、各自存一份在 modules[id] 下")
	var ids: Array[StringName] = [SafeModule.ID, NodeStorageModule.ID, CraftingModule.ID, BuffModule.ID, AltarModule.ID, CountdownModule.ID]
	var c := _content()
	var run: RunState = null
	for seed in range(1, 40):
		run = RunState.start(c["chapter"], seed, c["items"], c["enemies"], c["sets"])
		if run != null:
			break
	if run == null:
		t.check(false, "开不出一局")
		return
	run.pick_spawn(run.map.entry_ids[0])
	var saved: Dictionary = run.to_dict()["modules"]
	for mid in ids:
		t.check(run.module(mid) != null, "默认清单里有 %s" % mid)
		t.check(RunRegistry.has_type(&"run_module", mid), "%s 登记在 run_module 表里" % mid)
		t.check(FieldText.TYPE_LABELS.has(String(mid)), "%s 在编辑器里有中文名" % mid)
		t.check(saved.has(String(mid)), "%s 在存档的 modules 下有自己那一份" % mid)
	t.eq(run.module_lines().size(), ids.size(), "规则卡上每个模块一句")
	# 顶层不再有任何一个子系统的键（都在 modules 下了）
	var top: Dictionary = run.to_dict()
	for key in ["safe", "safe_locked", "node_storages", "carry_in_value", "faith_rituals", "faith_stat_bonus", "altar_used"]:
		t.check(not top.has(key), "顶层不再有 %s" % key)
	t.check(not (top["buffs"] as Dictionary).has("map"), "一局里拿到的 buff 也不在 buffs.map 下了")
	# 读档：六个模块都把自己那份拿回去
	var back := RunState.from_dict(top, c["chapter"] as ChapterDef, c["items"], c["enemies"], c["sets"])
	t.not_null(back, "读得回来")
	if back != null:
		for mid in ids:
			t.check(back.module(mid) != null, "读回来的一局里也有 %s" % mid)
