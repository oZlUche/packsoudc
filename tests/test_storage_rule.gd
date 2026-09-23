## 暂存区按点清空（3.4 / 058 第 3 条）：走出发生过事的点，暂存区里的东西留在那里；出生点、只是路过的点不清；
## 提醒按设置档位；设置存读。
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const SAVE := "user://test_storage_run.json"
const META := "user://test_storage_meta.json"
const SETTINGS := "user://test_storage_settings.json"


class Content:
	extends RefCounted
	var items: ItemDatabase
	var enemies: EnemyDatabase
	var sets: SetDatabase
	var chapter: ChapterDef
	var loadouts: Array[LoadoutDef]


static func _content() -> Content:
	var c := Content.new()
	c.items = ItemDatabase.new()
	c.items.load_dir()
	c.enemies = EnemyDatabase.new()
	c.enemies.load_all()
	c.sets = SetDatabase.new()
	c.sets.load_dir()
	c.chapter = load(ContentPaths.asset_file("chapters", "chapter_01"))
	c.loadouts = GameFlow.load_loadouts()
	return c


static func _flow(c: Content) -> GameFlow:
	_cleanup()
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f.chapters = [c.chapter] as Array[ChapterDef]
	f.loadouts = c.loadouts
	f.save_path = SAVE
	f.meta_path = META
	f.settings_path = SETTINGS
	f.player_baseline = CombatantBaseline.with_hp(10000.0)
	return f


static func _cleanup() -> void:
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


## 出生点旁边就有某类型点的种子：{seed, entry, next}
static func _seed_with(c: Content, type: StringName, kit: Array[StringName]) -> Dictionary:
	for seed in range(1, 80):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit)
		if s == null:
			continue
		for entry in s.map.entry_ids:
			for nid in s.map.neighbors(entry):
				if s.map.get_node(nid).type == type:
					return {"seed": seed, "entry": entry, "next": nid}
	return {}


static func _settle(f: GameFlow) -> void:
	var guard := 0
	while GameFlow.is_overlay(f.screen) and guard < 30:
		guard += 1
		match f.screen:
			GameFlow.Screen.LOOT:
				f.take_all_loot()
			GameFlow.Screen.SEARCH:
				f.run.events.current_search.leave()
			GameFlow.Screen.SHOP:
				f.run.events.current_shop.leave()
			_:
				f.resume()


static func _kit(c: Content) -> LoadoutDef:
	for l in c.loadouts:
		if l.id == &"standard":
			return l
	return c.loadouts[0]


static func run_clear_on_leave(t: TestCase) -> void:
	t.begin("暂存区 · 走出发生过事的点才清；出生点、路过的点不清；走不成不清；存档带着")

	var c := _content()
	var kit := _kit(c)
	var found := _seed_with(c, &"battle", kit.items)
	if found.is_empty():
		t.check(false, "找不到种子")
		return
	var f := _flow(c)
	var run := f.begin(c.chapter, kit, int(found["seed"]))
	var entry := int(found["entry"])
	var next := int(found["next"])
	f.pick_spawn(entry)
	var def := c.items.get_def(&"ration")
	run.storage.clear()
	run.storage.admit(ItemInstance.create(def))
	t.check(not run.will_clear_storage(), "出生点上没发生过事，走了不清")
	var dropped: Array = []
	run.storage_dropped.connect(func(id: int, items: Array): dropped.append([id, items.size()]))

	t.check(f.step_to(next), "走上战斗点")
	t.eq(run.storage.item_count(), 1, "离开出生点没清")
	_settle(f)
	t.eq(run.events.last_handled_id, next, "战斗点是「发生过事的点」")
	t.check(run.will_clear_storage(), "打过了、暂存区有东西：走了会清")
	t.check(f.step_to(entry), "走回出生点")
	_settle(f)
	t.eq(run.storage.item_count(), 0, "离开战斗点：暂存区清空")
	t.check(dropped.size() == 1 and int(dropped[0][0]) == next and int(dropped[0][1]) >= 1, "发了 storage_dropped，点对、件数对（%s）" % str(dropped))
	t.eq(run.events.last_handled_id, -1, "离开之后不再算发生过事的点")

	# 路过：用过的点上放东西，穿行来回都不清
	run.storage.admit(ItemInstance.create(def))
	t.check(not run.will_clear_storage(), "出生点上这一次也没发生事")
	t.check(f.step_to(next), "穿行到用过的战斗点")
	t.eq(run.storage.item_count(), 1, "离开出生点不清")
	t.check(not run.will_clear_storage(), "用过的战斗点这次没发生事，走了也不清")
	t.check(f.step_to(entry), "走回来")
	t.eq(run.storage.item_count(), 1, "穿行不清")

	# 走不成不清
	t.check(not f.step_to(99999), "走不到的走不了")
	t.eq(run.storage.item_count(), 1, "走不成不清")

	# 存档带着「发生过事的点」：走到另一个没用过的点，存、读，读回来的也知道走了要清
	var fresh := -1
	for id in run.travel.available_moves():
		var n := run.map.get_node(id)
		if not n.is_visited() and n.type in [&"battle", &"search", &"shop", &"rest", &"event"]:
			fresh = id
			break
	if fresh >= 0:
		t.check(f.step_to(fresh), "走到一个没用过的点 %d" % fresh)
		_settle(f)
		if run.storage.item_count() == 0:
			run.storage.admit(ItemInstance.create(def))
		var before := run.will_clear_storage()
		t.check(before, "在发生过事的点上、暂存区有东西")
		t.eq(RunSave.write(run, SAVE), OK, "存")
		var back := RunSave.read(c.items, c.enemies, c.sets, SAVE)
		t.not_null(back, "读回来")
		t.eq(back.events.last_handled_id, run.events.last_handled_id, "「发生过事的点」跟着存档")
		t.eq(back.will_clear_storage(), before, "读回来的也知道走了要清")
	_cleanup()


static func run_warning_tiers(t: TestCase) -> void:
	t.begin("暂存区提醒 · 四个档位：有就提 / 稀有度 / 价值 / 从不")

	var c := _content()
	var by_rarity := {}
	for id in c.items.ids():
		var d := c.items.get_def(id)
		if not d.is_bag and not by_rarity.has(d.rarity):
			by_rarity[d.rarity] = d
	t.check(by_rarity.size() >= 3, "道具库里至少三档稀有度（实际 %d）" % by_rarity.size())
	var items: Array = []
	for r in by_rarity:
		items.append(ItemInstance.create(by_rarity[r]))
	var s := GameSettings.new()
	s.storage_warn_mode = &"any"
	t.eq(StorageWarning.at_risk(items, s).size(), items.size(), "有就提：全部")
	s.storage_warn_mode = &"never"
	t.check(StorageWarning.at_risk(items, s).is_empty() and not StorageWarning.should_warn(items, s), "从不：一件都不提")
	s.storage_warn_mode = &"rarity"
	s.storage_warn_rarity = 2
	var expect_r := 0
	for inst in items:
		if (inst as ItemInstance).def.rarity >= 2:
			expect_r += 1
	t.eq(StorageWarning.at_risk(items, s).size(), expect_r, "稀有度 ≥ 2：%d 件" % expect_r)
	s.storage_warn_mode = &"value"
	s.storage_warn_value = 60
	var expect_v := 0
	for inst in items:
		if ItemValue.of((inst as ItemInstance).def) >= 60:
			expect_v += 1
	t.eq(StorageWarning.at_risk(items, s).size(), expect_v, "价值 ≥ 60：%d 件" % expect_v)
	t.check(StorageWarning.describe(items).contains("%d 件" % items.size()), "一句话里有件数")
	t.eq(StorageWarning.at_risk([], s).size(), 0, "空的不提")
	t.eq(StorageWarning.at_risk(items, null).size(), items.size(), "没给设置按默认（有就提）")


static func run_settings_round_trip(t: TestCase) -> void:
	t.begin("设置 · 默认值、往返、坏值回默认、文件读写")

	var s := GameSettings.new()
	t.eq(s.storage_warn_mode, &"any", "默认有就提")
	s.storage_warn_mode = &"value"
	s.storage_warn_value = 250
	var back := GameSettings.from_dict(s.to_dict())
	t.eq([back.storage_warn_mode, back.storage_warn_rarity, back.storage_warn_value], [&"value", 2, 250], "往返")
	t.eq(GameSettings.from_dict({"version": 1, "storage_warn_mode": "nope"}).storage_warn_mode, &"any", "不认识的档位回默认")
	t.eq(GameSettings.from_dict({"version": 99, "storage_warn_mode": "never"}).storage_warn_mode, &"any", "版本不对回默认")
	GameSettings.remove(SETTINGS)
	t.eq(GameSettings.load_from(SETTINGS).storage_warn_mode, &"any", "没有文件就是默认")
	t.eq(s.save_to(SETTINGS), OK, "写文件")
	t.eq(GameSettings.load_from(SETTINGS).storage_warn_value, 250, "读回来")
	GameSettings.remove(SETTINGS)


static func frame_map_prompt(t: TestCase, root: Window) -> void:
	t.begin("地图屏 · 离开发生过事的点前先问一句；档位「从不」就直接走")

	var c := _content()
	var kit := _kit(c)
	var found := _seed_with(c, &"battle", kit.items)
	if found.is_empty():
		t.check(false, "找不到种子")
		return
	_cleanup()
	var game = load(GAME).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	game.settings_path = SETTINGS
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.new_run()
	var setup = game.base()
	for i in flow.loadouts.size():
		if flow.loadouts[i].id == kit.id:
			setup.choose_loadout(i)
	setup.set_run_seed(int(found["seed"]))
	t.check(setup.depart(), "出发")
	var map = game.base()
	var run: RunState = flow.run
	map.pick_spawn(int(found["entry"]))
	t.check(map.step(int(found["next"])), "走上战斗点")
	var guard := 0
	while game.overlay() != null and guard < 10:
		guard += 1
		var ov = game.overlay()
		match ov.screen:
			GameFlow.Screen.LOOT:
				ov.take_all()
			_:
				ov.proceed()
	if run.storage.item_count() == 0:
		run.storage.admit(ItemInstance.create(c.items.get_def(&"ration")))
	t.check(run.will_clear_storage(), "在战斗点上、暂存区有东西")
	var to: int = run.travel.available_moves()[0]
	t.check(map.step(to), "按走")
	t.check(map.step_confirm_open(), "先问一句")
	t.eq(run.travel.current_id, int(found["next"]), "人还没动")
	map.cancel_step()
	t.check(not map.step_confirm_open() and run.travel.current_id == int(found["next"]), "取消：面板关了、人没动")
	map.step(to)
	t.check(map.confirm_step(), "照走")
	t.eq(run.travel.current_id, to, "走了")
	t.eq(run.storage.item_count(), 0, "暂存区清了")
	guard = 0
	while game.overlay() != null and guard < 10:
		guard += 1
		var ov2 = game.overlay()
		match ov2.screen:
			GameFlow.Screen.LOOT:
				ov2.take_all()
			GameFlow.Screen.SEARCH, GameFlow.Screen.SHOP:
				ov2.leave()
			_:
				ov2.proceed()
	# 「从不」：不问
	flow.settings.storage_warn_mode = &"never"
	if run.will_clear_storage() or run.events.last_handled_id == run.travel.current_id:
		if run.storage.item_count() == 0:
			run.storage.admit(ItemInstance.create(c.items.get_def(&"ration")))
		var to2: int = run.travel.available_moves()[0]
		map.step(to2)
		t.check(not map.step_confirm_open(), "档位「从不」：不问直接走")
	flow.to_main_menu()
	game.queue_free()
	_cleanup()
