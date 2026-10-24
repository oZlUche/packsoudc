## 场景流（M6-1，架构文档 8 节）：开局装备走管线、结算与局外、状态机的屏序列、导演真的换屏。
## 期望从数据推：装备清单里有几个包、棋盘上就有几个包；结算的价值是棋盘上每件 ItemValue 之和。
extends RefCounted

const GAME := "res://ui/game/game.tscn"
## 与 Support.paths("flow") 是同一组路径（flow / cleanup 按前缀算）
const SAVE := "user://test_flow_run.json"
const META := "user://test_flow_meta.json"
const Support := preload("res://tests/run/flow_support.gd")


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["loadouts"])


static func _loadout(c: TestSupport.Content, id: StringName) -> LoadoutDef:
	for l in c.loadouts:
		if l.id == id:
			return l
	return c.loadouts[0] if not c.loadouts.is_empty() else null


## 找一个种子：某个出生点旁边就有某类型的点。返回 {seed, entry, next}，找不到空字典
static func _seed_with(c: TestSupport.Content, type: StringName, kit: Array[StringName] = [] as Array[StringName]) -> Dictionary:
	for seed in range(1, 80):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit)
		if s == null:
			continue
		for entry in s.map.entry_ids:
			for nid in s.map.neighbors(entry):
				if s.map.get_node(nid).type == type:
					return {"seed": seed, "entry": entry, "next": nid}
	return {}


## 把叠层都看完：战斗 / 事件 / 休息按继续，战利品全拿，搜索与商店离开。返回看过的屏
static func _settle_overlays(f: GameFlow) -> Array[int]:
	var seen: Array[int] = []
	var guard := 0
	while GameFlow.is_overlay(f.screen) and guard < 30:
		guard += 1
		seen.append(f.screen)
		match f.screen:
			GameFlow.Screen.PREBATTLE:
				f.start_battle()
			GameFlow.Screen.LOOT:
				f.take_all_loot()
			GameFlow.Screen.SEARCH:
				f.run.events.current_search.leave()
			GameFlow.Screen.SHOP:
				f.run.events.current_shop.leave()
			_:
				f.resume()
	return seen


static func _sum_value(container) -> int:
	var v := 0
	for inst in container.items():
		v += ItemValue.of((inst as ItemInstance).def)
	return v


#region 开局装备
static func run_loadout_pipeline(t: TestCase) -> void:
	t.begin("开局装备 · 走内容管线：往返、校验、作者文件、开局按清单发")

	var c := _content()
	var ctx := ContentImporter.Context.new()
	for id in c.items.ids():
		ctx.register_item(c.items.get_def(id))

	# 往返
	var sample := LoadoutDef.new()
	sample.id = &"t_kit"
	sample.display_name = "测试"
	sample.items = [&"bag_leather", &"shortsword"] as Array[StringName]
	var text := ContentExporter.to_json(ContentExporter.export_loadout(sample))
	var report := ImportReport.new()
	var back := ContentImporter.import_loadout(JSON.parse_string(text), ctx, report)
	t.check(report.ok(), "导得回来：%s" % report.to_text())
	t.eq(back.items, sample.items, "清单原样")
	t.eq(ContentExporter.to_json(ContentExporter.export_loadout(back)), text, "再导出一次，文本逐字节相同")

	# 校验比引擎严格
	var bad := ImportReport.new()
	ContentImporter.import_loadout({"id": "x", "items": []}, ctx, bad)
	t.check(not bad.ok(), "空清单不行")
	bad = ImportReport.new()
	ContentImporter.import_loadout({"id": "x", "items": ["bag_leather", "no_such_item"]}, ctx, bad)
	t.check(not bad.ok() and bad.to_text().contains("no_such_item"), "不存在的道具不行，报出名字")
	bad = ImportReport.new()
	ContentImporter.import_loadout({"id": "x", "items": ["shortsword", "knife"]}, ctx, bad)
	t.check(not bad.ok() and bad.to_text().contains("包"), "没有包不行：棋盘上只有包里的东西参战")
	bad = ImportReport.new()
	ContentImporter.import_loadout({"id": "x", "items": ["shortsword", "knife"]}, ContentImporter.Context.new(), bad)
	t.check(bad.ok(), "单独导一份（上下文里没有道具）时对着道具查的两条跳过")

	# 作者文件：导得进、是不动点、资产在、每份至少一个包
	var dir: String = ContentPaths.KINDS["loadouts"][0]
	var d := DirAccess.open(dir)
	t.not_null(d, "有 %s" % dir)
	var files := 0
	if d != null:
		for f in d.get_files():
			if not f.ends_with(".json"):
				continue
			files += 1
			var id := f.get_basename()
			var raw := FileAccess.get_file_as_string(dir + "/" + f)
			var r := ImportReport.new()
			var res := ContentImporter.import_loadout(JSON.parse_string(raw), ctx, r)
			t.check(r.ok(), "%s 导得进：%s" % [f, r.to_text()])
			t.eq(ContentExporter.to_json(ContentExporter.export_loadout(res)), raw, "%s 是往返不动点（tools/normalize_content.gd）" % f)
			t.check(ResourceLoader.exists(ContentPaths.asset_file("loadouts", id)), "%s 的资产在" % id)
	t.check(files >= 2, "至少两套开局装备可挑（实际 %d）" % files)
	t.eq(c.loadouts.size(), files, "GameFlow.load_loadouts 装回全部 %d 份" % files)

	# 开局按清单发：清单里几个包棋盘上就几个包；其余不在棋盘就在地上
	for l in c.loadouts:
		var s := RunState.start(c.chapter, 3, c.items, c.enemies, c.sets, l.items)
		t.not_null(s, "%s 开得了局" % l.id)
		if s == null:
			continue
		var bags := 0
		var rest := 0
		for id in l.items:
			if c.items.get_def(id).is_bag:
				bags += 1
			else:
				rest += 1
		t.eq(s.board.bags().size(), bags, "%s：清单里 %d 个包，棋盘上 %d 个" % [l.id, bags, s.board.bags().size()])
		t.eq(s.board.item_count() - bags + s.storage.item_count(), rest, "%s：其余 %d 件不在棋盘就在地上" % [l.id, rest])
#endregion


#region 结算与局外
static func run_result_and_meta(t: TestCase) -> void:
	t.begin("结算与局外 · 撤离带出棋盘上的、战败全失；仓库、账、存档往返")

	var c := _content()
	var kit := _loadout(c, &"standard")
	var s := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets, kit.items)
	s.pick_spawn(s.map.entry_ids[0])
	t.is_null(RunResult.settle(s), "没结束算不出账")

	# 撤离：棋盘上的全部（含包）按价值计；地上的只提一句
	s.phase = RunState.Phase.EXTRACTED
	s.end_reason = &"extract"
	var r := RunResult.settle(s)
	t.not_null(r, "结束了就有账")
	t.check(r.is_extracted(), "撤离")
	t.eq(r.carried.size(), s.board.item_count(), "背出去的 = 棋盘上的全部（含包）")
	t.eq(r.value, _sum_value(s.board), "价值 = 每件 ItemValue 之和")
	t.check(not ("left_behind" in r), "224：地上的撤离时就没了，不记账")
	t.eq(r.balance, s.wallet.balance, "钱")
	t.eq((r.to_dict()["items"] as Array).size(), r.carried.size(), "历史只写 id")

	var kept := 0
	var racked := 0
	for inst in r.carried:
		if MetaState.keeps(inst.def):
			kept += 1
		elif BagRack.holds(inst.def):
			racked += 1
	var m := MetaState.new()
	var got := m.absorb(r)
	t.eq(int(got["items"]), kept + racked, "带回来 %d 件 + %d 个包（225：包也带回）" % [kept, racked])
	t.check(m.has_pending_board() and m.board.item_count() == kept + racked, "棋盘原样带回来等着置入")
	t.eq(m.warehouse.item_count(), 0, "仓库没自动进")
	t.eq(int(m.store_all()["moved"]), kept + racked, "一键置入全进了（默认仓库够大）")
	t.eq(m.warehouse.item_count(), kept, "仓库里就是这些")
	t.eq(m.rack.item_count(), racked, "225：包进了包架")
	t.eq(m.funds, r.balance, "钱带出来了")
	t.eq(m.score, r.value, "累计价值")
	t.eq(m.best_value, r.value, "单局最高")
	t.eq([m.runs, m.extractions, m.deaths], [1, 1, 0], "一局、一撤、零败")
	t.eq(m.history.size(), 1, "记了一条")

	# 战败：什么都没有
	var s2 := RunState.start(c.chapter, 6, c.items, c.enemies, c.sets, kit.items)
	s2.pick_spawn(s2.map.entry_ids[0])
	s2.phase = RunState.Phase.DEFEATED
	s2.end_reason = &"vitality_depleted"
	var r2 := RunResult.settle(s2)
	t.check(not r2.is_extracted() and r2.carried.is_empty() and r2.value == 0 and r2.balance == 0, "战败：没有背出去的、没有价值、没有钱")
	var before := m.warehouse.item_count()
	m.absorb(r2)
	t.eq(m.warehouse.item_count(), before, "仓库没变")
	t.eq([m.runs, m.extractions, m.deaths], [2, 1, 1], "两局、一撤、一败")

	# 第二次撤离的 uid 与第一次撞号（每局从 1 重编）：仓库重新编号，一件不丢
	var s3 := RunState.start(c.chapter, 7, c.items, c.enemies, c.sets, kit.items)
	s3.phase = RunState.Phase.EXTRACTED
	s3.end_reason = &"extract"
	var r3 := RunResult.settle(s3)
	var got3 := m.absorb(r3)
	m.store_all()
	t.eq(m.warehouse.item_count() + m.rack.item_count(), before + racked + int(got3["items"]), "撞号的也全进了仓库（包进包架）")
	var uids := {}
	for inst in m.warehouse.items():
		uids[(inst as ItemInstance).uid] = true
	t.eq(uids.size(), m.warehouse.item_count(), "仓库里 uid 两两不同")

	# 存档往返
	var text := MetaSave.to_text(m)
	var back := MetaSave.from_text(text, c.items)
	t.not_null(back, "读得回来")
	t.eq(MetaSave.to_text(back), text, "再存逐字节相同")
	t.eq(back.warehouse.item_count(), m.warehouse.item_count(), "仓库件数一样")
	t.eq([back.funds, back.score, back.runs, back.deaths, back.history.size()], [m.funds, m.score, m.runs, m.deaths, m.history.size()], "账一样")
	t.is_null(MetaSave.from_text("{\"version\": 99}", c.items), "版本不对 → null")
	t.is_null(MetaSave.from_text("nope", c.items), "坏文件 → null")
	t.eq(MetaSave.write(m, META), OK, "真写 user://")
	t.check(MetaSave.exists(META), "文件在")
	t.eq(MetaSave.read(c.items, META).warehouse.item_count(), m.warehouse.item_count(), "读回来一样")
	MetaSave.remove(META)
	t.check(not MetaSave.exists(META), "删掉了")
#endregion


#region 状态机
static func run_flow_screens(t: TestCase) -> void:
	t.begin("场景流 · 主菜单 → 开局 → 地图 → 打一场（回放 → 战利品）→ 地图；存档回主菜单再继续")

	var c := _content()
	var f := Support.flow(c, "flow")
	var seen: Array = []
	f.screen_changed.connect(func(s: int, _p: Dictionary): seen.append(s))
	f.to_main_menu()
	t.eq(f.screen, GameFlow.Screen.MAIN_MENU, "开在主菜单")
	t.check(not f.has_save(), "还没有存档")
	f.new_run()
	t.eq(f.screen, GameFlow.Screen.SETUP, "新的一局 → 开局屏")

	var kit := _loadout(c, &"standard")
	var found := _seed_with(c, &"battle", kit.items)
	t.check(not found.is_empty(), "找得到出生点旁边就是战斗点的种子")
	if found.is_empty():
		return
	var run := f.begin(c.chapter, kit, int(found["seed"]))
	t.not_null(run, "开局")
	t.eq(f.screen, GameFlow.Screen.MAP, "→ 地图")
	t.check(f.run == run, "这一局挂到流程上了")
	t.eq(run.phase, RunState.Phase.PICK_SPAWN, "先挑出生点")
	t.check(f.pick_spawn(int(found["entry"])), "挑出生点")
	t.check(not f.extract(), "不在撤离点上撤不了")

	t.check(f.step_to(int(found["next"])), "走上战斗点")
	t.eq(f.screen, GameFlow.Screen.PREBATTLE, "先到战前准备屏（084）")
	t.check(not f.run.events.pending_battle.is_empty() and int(f.run.events.pending_battle["node"]) == int(found["next"]), "等着开打的就是这个点")
	t.check(not f.step_to(int(found["entry"])), "没开战走不了")
	t.check(f.start_battle(), "开战")
	t.eq(f.screen, GameFlow.Screen.BATTLE, "再看回放")
	var p := f.last_payload
	t.check(p.get("result", null) is BattleResult and bool(p.get("won", false)), "回放带着结果，赢了（血 10000）")
	t.check(p.get("player", null) is CombatantSpec and p.get("enemy", null) is CombatantSpec, "双方的战斗单位都在（回放要按 uid 查名字）")
	t.check((p.get("enemy_content", {}) as Dictionary).has("enemy"), "对手的内容在（叫什么、几档）")
	t.eq(int(run.tally["battles_won"]), 1, "计了一场胜")
	f.resume()
	if run.pending_loot != null:
		t.eq(f.screen, GameFlow.Screen.LOOT, "有掉落 → 战利品屏")
		var n := f.take_all_loot()
		t.check(n > 0 and run.pending_loot == null, "全拿了 %d 件" % n)
	t.eq(f.screen, GameFlow.Screen.MAP, "看完回地图")
	t.check(run.map.get_node(int(found["next"])).is_visited(), "战斗点用过了")

	# 存档回主菜单，再继续
	var at := run.travel.current_id
	t.check(f.save_and_quit(), "存档回主菜单")
	t.eq(f.screen, GameFlow.Screen.MAIN_MENU, "在主菜单")
	t.is_null(f.run, "手里没有局了")
	t.check(f.has_save(), "有存档")
	t.check(f.continue_run(), "继续上次")
	t.eq(f.screen, GameFlow.Screen.MAP, "→ 地图")
	t.eq(f.run.travel.current_id, at, "还站在原地")
	t.eq(int(f.run.tally["battles_won"]), 1, "计数跟着存档")
	# 224：账单的新计数 —— 赢了按点类型记精英 / 首领；搜索点同一个点只算一次；都跟着存档
	t.eq([int(f.run.tally.get("elite_won", -1)), int(f.run.tally.get("boss_won", -1))], [0, 0], "普通战斗不算精英 / 首领")
	f.run.events.last_battle = {"type": "elite"}
	f.run._tally_battle(true)
	f.run.events.last_battle = {"type": "core"}
	f.run._tally_battle(true)
	f.run._tally_battle(false)
	t.eq([int(f.run.tally["battles_won"]), int(f.run.tally["elite_won"]), int(f.run.tally["boss_won"]), int(f.run.tally["battles_lost"])], [3, 1, 1, 1], "精英、首领各记一笔（输了不算）")
	var spot := f.run.map.get_node(at)
	f.run._tally_search(spot)
	f.run._tally_search(spot)
	t.eq(int(f.run.tally["searches"]), 1, "同一个搜索点只算一次")
	t.check(f.save_and_quit() and f.continue_run(), "再存一次读回来")
	t.eq([int(f.run.tally["elite_won"]), int(f.run.tally["searches"])], [1, 1], "新计数跟着存档")
	f.run._tally_search(f.run.map.get_node(at))
	t.eq(int(f.run.tally["searches"]), 1, "读档后还记得翻过哪些点")
	t.check(seen.has(GameFlow.Screen.SETUP) and seen.has(GameFlow.Screen.BATTLE), "屏的切换都发了信号")
	Support.cleanup("flow")


static func run_flow_search_and_shop(t: TestCase) -> void:
	t.begin("场景流 · 搜索点与商店是叠层，会话结束流程自己往下走")

	var c := _content()
	var kit := _loadout(c, &"standard")
	for type in [&"search", &"shop"]:
		var found := _seed_with(c, type, kit.items)
		t.check(not found.is_empty(), "找得到出生点旁边就是%s的种子" % MapNodeStyle.of(type)["label"])
		if found.is_empty():
			continue
		var f := Support.flow(c, "flow")
		f.begin(c.chapter, kit, int(found["seed"]))
		f.pick_spawn(int(found["entry"]))
		f.step_to(int(found["next"]))
		var want := GameFlow.Screen.SEARCH if type == &"search" else GameFlow.Screen.SHOP
		t.eq(f.screen, want, "踩上去 → 叠层")
		var session = f.last_payload.get("session", null)
		t.not_null(session, "带着会话")
		if type == &"search":
			t.check(not f.run.map.get_node(int(found["next"])).is_visited(), "搜着的时候点还没用过")
			(session as SearchSession).search()
			# 搜一次可能遭遇 → 会话结束 → 回放；也可能没事 → 还在搜
			if f.screen == GameFlow.Screen.SEARCH:
				(session as SearchSession).leave()
		else:
			(session as ShopSession).leave()
		var seen := _settle_overlays(f)
		t.eq(f.screen, GameFlow.Screen.MAP, "会话结束后流程自己回到地图（经过 %s）" % str(seen))
		t.check(f.run.map.get_node(int(found["next"])).is_visited(), "点用过了")


static func run_flow_defeat(t: TestCase) -> void:
	t.begin("场景流 · 打输战败：回放 → 结算（战败）→ 局外记一败，存档删掉")

	var c := _content()
	var found := _seed_with(c, &"battle")
	if found.is_empty():
		t.check(false, "找不到种子")
		return
	var f := Support.flow(c, "flow", 1.0)
	var empty := LoadoutDef.new()      # 空手：肯定输
	f.begin(c.chapter, empty, int(found["seed"]))
	f.pick_spawn(int(found["entry"]))
	f.run.vitality.spend(f.run.vitality.current - 1, &"test")
	t.check(f.save(), "先存一份")
	t.check(f.step_to(int(found["next"])), "走上战斗点")
	t.eq(f.screen, GameFlow.Screen.PREBATTLE, "先到战前准备屏")
	t.check(f.start_battle(), "开战")
	t.eq(f.screen, GameFlow.Screen.BATTLE, "那一场的回放还给看")
	t.check(not bool(f.last_payload.get("won", true)), "输了")
	t.check(f.run.is_over(), "一局结束了")
	f.resume()
	t.eq(f.screen, GameFlow.Screen.RESULT, "→ 结算")
	t.not_null(f.result, "结算过了")
	var r: RunResult = f.last_payload.get("result", null)
	t.check(r != null and not r.is_extracted() and r.battles_lost == 1, "战败的账：输了一场")
	t.check(not f.pick_spawn(int(found["entry"])) and not f.step_to(int(found["entry"])), "结束了走不了")
	f.finish_result()
	t.eq(f.screen, GameFlow.Screen.META, "→ 局外")
	t.eq([f.meta.runs, f.meta.deaths, f.meta.warehouse.item_count()], [1, 1, 0], "局外记了一败，仓库空")
	t.check(MetaSave.exists(META), "局外存了")
	t.check(not f.has_save(), "这一局的存档删掉了")
	f.finish_result()
	t.eq(f.meta.runs, 1, "再按一次不会记两遍")
	f.to_main_menu()
	t.eq(f.screen, GameFlow.Screen.MAIN_MENU, "回主菜单")
	Support.cleanup("flow")


static func run_flow_extract(t: TestCase) -> void:
	t.begin("场景流 · 走到最近的免费撤离点撤离：结算（撤离）→ 仓库进了棋盘上的东西")

	var c := _content()
	var kit := _loadout(c, &"scavenger")
	var f := Support.flow(c, "flow")
	var run: RunState = null
	var target := -1
	for seed in range(1, 40):
		run = f.begin(c.chapter, kit, seed)
		if run == null:
			continue
		var entry: int = run.map.entry_ids[0]
		f.pick_spawn(entry)
		var dist := MapNavigator.distance_map(run.map, entry)
		var best := 999
		for id in run.map.node_ids():
			var n := run.map.get_node(id)
			if n.type == &"extract" and PaidExtracts.fee_of(n) == 0 and dist.has(id) and int(dist[id]) < best:
				best = int(dist[id])
				target = id
		if target >= 0:
			break
	t.check(run != null and target >= 0, "找得到一张图，出生点能走到免费撤离点 %d" % target)
	if run == null or target < 0:
		return
	var to_target := MapNavigator.distance_map(run.map, target)
	var guard := 0
	while run.travel.current_id != target and not run.is_over() and guard < 60:
		guard += 1
		var next := -1
		for id in run.travel.available_moves():
			if to_target.has(id) and (next < 0 or int(to_target[id]) < int(to_target[next])):
				next = id
		t.check(f.step_to(next), "走向 %d（第 %d 步）" % [next, guard])
		_settle_overlays(f)
	t.eq(run.travel.current_id, target, "站在撤离点上")
	t.eq(f.screen, GameFlow.Screen.MAP, "在地图上")
	var board_items := run.board.item_count()
	var board_value := _sum_value(run.board)
	t.check(f.extract(), "撤离")
	t.eq(f.screen, GameFlow.Screen.RESULT, "→ 结算")
	var r: RunResult = f.last_payload.get("result", null)
	t.check(r != null and r.is_extracted(), "撤离的账")
	t.eq(r.carried.size(), board_items, "背出去的 = 棋盘上的 %d 件" % board_items)
	t.eq(r.value, board_value, "价值对")
	t.eq(r.battles_won, int(run.tally["battles_won"]), "打赢的场数跟着计数")
	var kept := 0
	var racked := 0
	for inst in r.carried:
		if MetaState.keeps(inst.def):
			kept += 1
		elif BagRack.holds(inst.def):
			racked += 1
	t.check(f.meta.has_pending_board() and f.meta.board.item_count() == kept + racked, "棋盘原样带回来了（%d 件 + %d 个包）" % [kept, racked])
	f.finish_result()
	t.eq(f.screen, GameFlow.Screen.META, "→ 局外")
	t.eq(int(f.store_all()["moved"]), kept + racked, "一键置入")
	t.eq(f.meta.warehouse.item_count(), kept, "仓库里就是棋盘上的那些")
	t.eq(f.meta.funds, r.balance, "钱带出来了")
	t.eq(MetaSave.read(c.items, META).warehouse.item_count(), kept, "局外存了，读回来一样")
	Support.cleanup("flow")
#endregion


#region 导演
static func frame_director(t: TestCase, root: Window) -> void:
	t.begin("导演 · 真的换屏：主菜单 → 开局 → 地图 → 战斗叠层 → 地图；存档回主菜单再继续")

	var c := _content()
	var kit := _loadout(c, &"standard")
	var found := _seed_with(c, &"battle", kit.items)
	var game = load(GAME).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	root.add_child(game)
	var flow: GameFlow = game.flow
	t.not_null(flow, "导演持有 flow")
	t.check(game.base() != null and game.base().screen == GameFlow.Screen.MAIN_MENU, "开在主菜单")
	t.is_null(game.overlay(), "没有叠层")
	t.check(flow.chapters.size() >= 1 and flow.loadouts.size() >= 2, "装回了章节与开局装备")

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
	if found.is_empty():
		t.check(false, "找不到种子")
		game.queue_free()
		return
	setup.choose_scale(&"")     # 180：种子是按章节默认配置找的（开局屏默认第一档规模）
	setup.set_run_seed(int(found["seed"]))
	# 067：开局屏按角色开（初始包 + 从仓库拖），不再挑装备；新的局外把第一套发进了仓库，全带上。地图只看种子，不看带了什么
	for inst in flow.meta.warehouse.items().duplicate():
		setup.carry_in((inst as ItemInstance).uid)
	t.check(setup.carried().size() > 0, "从仓库带上了第一套")
	t.check(Support.depart(setup), "出发")
	var map = game.base()
	t.eq(map.screen, GameFlow.Screen.MAP, "→ 地图")
	t.check(map.pick_spawn(int(found["entry"])), "挑出生点")
	map.toggle_bag()
	t.check(map.bag_open(), "背包叠在地图上")
	map.toggle_bag()
	t.check(not map.bag_open(), "收起了")
	t.check(map.step(int(found["next"])), "走上战斗点")
	t.check(game.overlay() != null and game.overlay().screen == GameFlow.Screen.PREBATTLE, "战前准备屏叠上来了（084）")
	t.check(game.overlay().enemy_view() != null and game.overlay().enemy_view().inventory != null, "画着对手的棋盘")
	t.check(game.overlay().start_battle(), "开战")
	t.check(game.overlay() != null and game.overlay().screen == GameFlow.Screen.BATTLE, "战斗回放叠上来了")
	t.eq(game.base(), map, "地图还在底下")
	game.overlay().proceed()
	if game.overlay() != null and game.overlay().screen == GameFlow.Screen.LOOT:
		var loot = game.overlay()
		t.check(loot.loot_view().unrevealed_count() > 0, "战利品屏一开始是剪影")
		loot.skip_reveal()
		t.eq(loot.loot_view().unrevealed_count(), 0, "快速搜索全亮")
		loot.take_all()
		loot.to_map()     # 084：拿完不自动关，手动关
	t.is_null(game.overlay(), "看完了叠层撤掉")
	t.eq(game.base(), map, "还是那张地图")
	flow.save_and_quit()
	t.check(game.base().screen == GameFlow.Screen.MAIN_MENU and game.base() != map, "存档回主菜单")
	t.check(flow.continue_run(), "继续上次")
	t.eq(game.base().screen, GameFlow.Screen.MAP, "→ 地图")

	# M6-3：走到最近的免费撤离点，先确认再撤；地上有东西就提一句遗落
	map = game.base()
	t.check(not map.extract(), "不在撤离点上按撤离没反应")
	var run: RunState = flow.run
	var target := _nearest_free_extract(run)
	t.check(target >= 0, "有免费撤离点可走")
	_director_walk(game, run, target)
	t.eq(run.travel.current_id, target, "站在撤离点上")
	var left := run.storage.item_count()
	t.check(map.extract(), "按撤离 → 先问一句")
	t.check(map.confirm_open(), "确认面板开着")
	map.cancel_extract()
	t.check(not map.confirm_open(), "再想想：面板关了，人还在")
	t.eq(flow.screen, GameFlow.Screen.MAP, "没撤")
	t.eq(run.travel.current_id, target, "还站在撤离点上")
	t.check(map.extract(), "再按一次撤离")
	var ledger := map._confirm.find_child("ExtractLedger", true, false) as LedgerRows
	var row_labels: Array = ledger.rows().map(func(r: Dictionary) -> String: return String(r["label"])) if ledger != null else []
	t.check(row_labels.has(UiText.t("map.row_carried")) and row_labels.has(UiText.t("map.row_coins")), "226 批三：撤离确认是账目行（%s）" % [row_labels])
	t.check(map.confirm_extract(), "确定撤离")
	t.eq(game.base().screen, GameFlow.Screen.RESULT, "→ 结算")
	var result: RunResult = flow.result
	t.check(result != null and result.is_extracted() and result.carried.size() > 0, "撤离了（地上的 %d 件不记账，224）" % left)
	t.check(flow.meta.has_pending_board(), "结算屏上带回来的棋盘等着置入")
	game.base().to_step(2)     # 177：第 1 步看账，第 2 步才置入仓库
	var stored: Dictionary = game.base().store_all()
	t.check(int(stored["moved"]) > 0 and not flow.meta.has_pending_board(), "结算屏一键置入 %d 件" % stored["moved"])
	var wh = game.base().get("_wh")
	t.check(wh._board_box.visible and wh._board_view != null and flow.meta.board != null and flow.meta.board.item_count() == 0,
		"作者 2026-10-13：一键置入后左边的棋盘还在（空的），仓库不跳位")
	game.base().proceed()
	t.eq(game.base().screen, GameFlow.Screen.META, "→ 局外")
	t.eq(flow.meta.board, null, "离开结算屏：空棋盘丢了")
	t.eq(flow.meta.warehouse.item_count() + flow.meta.rack.item_count(), int(stored["moved"]), "仓库 + 包架里就是背出去的（225：包进包架）")
	flow.to_main_menu()
	game.queue_free()
	Support.cleanup("flow")


static func _nearest_free_extract(run: RunState) -> int:
	var dist := MapNavigator.distance_map(run.map, run.travel.current_id)
	var best := 999
	var target := -1
	for id in run.map.node_ids():
		var n := run.map.get_node(id)
		if n.type == &"extract" and PaidExtracts.fee_of(n) == 0 and dist.has(id) and int(dist[id]) < best:
			best = int(dist[id])
			target = id
	return target


## 隔着导演走：每一步把叠上来的屏按它们自己的按钮看完
static func _director_walk(game, run: RunState, target: int) -> void:
	var to_target := MapNavigator.distance_map(run.map, target)
	var guard := 0
	while run.travel.current_id != target and not run.is_over() and guard < 60:
		guard += 1
		var next := -1
		for id in run.travel.available_moves():
			if to_target.has(id) and (next < 0 or int(to_target[id]) < int(to_target[next])):
				next = id
		if next < 0 or not game.base().step(next):
			return
		var inner := 0
		while game.overlay() != null and inner < 20:
			inner += 1
			var ov = game.overlay()
			match ov.screen:
				GameFlow.Screen.PREBATTLE:
					ov.start_battle()
				GameFlow.Screen.LOOT:
					ov.take_all()
					ov.to_map()     # 084：拿完不自动关，手动关
				GameFlow.Screen.SEARCH, GameFlow.Screen.SHOP:
					ov.leave()
				GameFlow.Screen.EVENT:
					# 085：撤离点也有对话了，这里要验右栏的确认面板，选「再看看」
					var def := run.events.pending_event()
					if def != null and def.id == &"extract_default" and def.options.size() > 1:
						ov.choose(1)
					else:
						ov.proceed()
				_:
					ov.proceed()
#endregion


#region M6-3 仓库带进一局
static func run_warehouse_to_run(t: TestCase) -> void:
	t.begin("场景流 · 从仓库带东西进一局：从仓库拿走、立刻存 meta；撤离了回来")

	var c := _content()
	var f := Support.flow(c, "flow")
	var kit := _loadout(c, &"standard")
	# 先攒一个仓库：一局撤离
	var first := f.begin(c.chapter, kit, 11)
	first.phase = RunState.Phase.EXTRACTED
	first.end_reason = &"extract"
	f.resume()
	f.finish_result()
	f.store_all()
	var stock := f.meta.warehouse.item_count()
	t.check(stock > 0, "仓库里有 %d 件" % stock)
	var pick := f.meta.warehouse.items()[0] as ItemInstance
	var pick_def := pick.def.id
	var pick_uid := pick.uid

	var second := f.begin(c.chapter, kit, 12, [pick_uid] as Array[int])
	t.not_null(second, "带着仓库的东西开局")
	t.eq(f.meta.warehouse.item_count(), stock - 1, "仓库少了那一件")
	t.is_null(f.meta.warehouse.get_item(pick_uid), "那个 uid 不在仓库了")
	t.eq(MetaSave.read(c.items, META).warehouse.item_count(), stock - 1, "meta 立刻存了：重开游戏也拿不回来")
	var have := 0
	for inst in second.board.items():
		if (inst as ItemInstance).def.id == pick_def:
			have += 1
	for inst in second.storage.items():
		if (inst as ItemInstance).def.id == pick_def:
			have += 1
	var in_kit := kit.items.count(pick_def)
	t.eq(have, in_kit + 1, "这一局里多了一件 %s（装备清单里 %d 件 + 仓库 1 件）" % [pick_def, in_kit])
	t.check(f.begin(c.chapter, kit, 13, [999999] as Array[int]) != null and f.meta.warehouse.item_count() == stock - 1, "不存在的 uid 忽略，仓库不动")

	# 死了就没了；撤离了回来
	var third := f.begin(c.chapter, kit, 14, [ (f.meta.warehouse.items()[0] as ItemInstance).uid ] as Array[int])
	t.eq(f.meta.warehouse.item_count(), stock - 2, "又带走一件")
	third.phase = RunState.Phase.DEFEATED
	third.end_reason = &"vitality_depleted"
	f.resume()
	f.finish_result()
	t.eq(f.meta.warehouse.item_count(), stock - 2, "战败：带出去的没回来")
	var fourth := f.begin(c.chapter, kit, 15, [ (f.meta.warehouse.items()[0] as ItemInstance).uid ] as Array[int])
	var board_n := 0
	for inst in fourth.board.items():
		if MetaState.keeps((inst as ItemInstance).def):
			board_n += 1
	fourth.phase = RunState.Phase.EXTRACTED
	fourth.end_reason = &"extract"
	f.resume()
	f.finish_result()
	f.store_all()
	t.eq(f.meta.warehouse.item_count(), stock - 3 + board_n, "撤离：棋盘上的非包道具置入后全回仓库")
	Support.cleanup("flow")
#endregion


#region M6-2 搜刮界面
static func run_seen_loot(t: TestCase) -> void:
	t.begin("场景流 · 搜索屏里亮过的，到了战利品屏不再重新揭示")

	var c := _content()
	var kit := _loadout(c, &"standard")
	var found := _seed_with(c, &"search", kit.items)
	if found.is_empty():
		t.check(false, "找不到种子")
		return
	var f := Support.flow(c, "flow")
	f.begin(c.chapter, kit, int(found["seed"]))
	f.pick_spawn(int(found["entry"]))
	f.step_to(int(found["next"]))
	t.eq(f.screen, GameFlow.Screen.SEARCH, "在搜")
	var session: SearchSession = f.last_payload.get("session", null)
	var guard := 0
	while f.screen == GameFlow.Screen.SEARCH and session.can_search() and session.found.is_empty() and guard < 5:
		guard += 1
		session.search()
	t.check(f.seen_loot.is_empty(), "还在搜的时候 flow 什么都没记")
	var had := session.haul_box.item_count()
	if f.screen == GameFlow.Screen.SEARCH:
		session.leave()
	_settle_overlays_until_loot(f)
	t.check(f.screen != GameFlow.Screen.LOOT and f.run.pending_loot == null, "作者 2026-10-16：离开搜索不弹战利品屏（收获 %d 件）" % had)


## 把回放 / 事件 / 休息看完，停在战利品屏或地图
static func _settle_overlays_until_loot(f: GameFlow) -> void:
	var guard := 0
	while GameFlow.is_overlay(f.screen) and f.screen != GameFlow.Screen.LOOT and guard < 10:
		guard += 1
		match f.screen:
			GameFlow.Screen.PREBATTLE:
				f.start_battle()
			GameFlow.Screen.SEARCH:
				f.run.events.current_search.leave()
			GameFlow.Screen.SHOP:
				f.run.events.current_shop.leave()
			_:
				f.resume()


static func frame_loot_view(t: TestCase, root: Window) -> void:
	t.begin("渐进揭示 · 正在搜的锁住、别的没亮的能抓；按栏位顺序亮；快速搜索推到终点；见过的不再走时间线")

	var c := _content()
	var box := LootPacker.board_of([&"healing_draught", &"knife", &"round_shield"] as Array[StringName], Vector2i(6, 4), c.items)
	t.eq(box.item_count(), 3, "三件摆进容器")
	var view := LootView.new()
	view.inventory = box
	root.add_child(view)
	var grabs: Array = []
	view.grab_requested.connect(func(_v: ContainerView, uid: int, _p: Vector2): grabs.append(uid))
	var revealed: Array = []
	view.item_revealed.connect(func(uid: int): revealed.append(uid))
	var finished: Array = []
	view.reveal_finished.connect(func(): finished.append(true))

	t.eq(view.unrevealed_count(), 3, "一开始一件都没亮")
	var first := box.get_item(view._unrevealed_in_slot_order()[0]) as ItemInstance
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = view.cell_origin_px(first.origin) + Vector2(InventoryView.CELL, InventoryView.CELL) * 0.5
	view._gui_input(press)
	t.eq(grabs, [first.uid], "没在搜的时候没亮的也能抓（068：未搜的可以拖，只能在容器里挪）")
	grabs.clear()

	view.start_reveal()
	t.check(view.is_revealing(), "时间线在跑")
	t.eq(view.current_uid(), first.uid, "正在搜的是栏位顺序第一件")
	view._gui_input(press)
	t.check(grabs.is_empty(), "正在搜的那件锁住，抓不起来")
	t.eq(view.unrevealed_count(), 3, "刚启动还没亮")
	view.skip()
	t.eq(view.unrevealed_count(), 0, "快速搜索：全亮")
	t.eq(revealed.size(), 3, "每件发了一次 item_revealed")
	t.eq(finished.size(), 1, "发了一次 reveal_finished")
	# 栏位顺序：先上后下、先左后右
	var ordered := true
	for i in range(1, revealed.size()):
		var a := box.get_item(int(revealed[i - 1]))
		var b := box.get_item(int(revealed[i]))
		if a.origin.y > b.origin.y or (a.origin.y == b.origin.y and a.origin.x > b.origin.x):
			ordered = false
	t.check(ordered, "亮的顺序是栏位顺序")
	view._gui_input(press)
	t.eq(grabs, [first.uid], "亮了就能抓")

	# 见过的不再走时间线
	var view2 := LootView.new()
	var box2 := LootPacker.board_of([&"healing_draught", &"knife", &"round_shield"] as Array[StringName], Vector2i(6, 4), c.items)
	view2.inventory = box2
	root.add_child(view2)
	var seen := (box2.items()[0] as ItemInstance).uid
	view2.mark_revealed([seen])
	t.eq(view2.unrevealed_count(), 2, "标了一件见过，还剩两件没亮")
	view2.start_reveal()
	view2.skip()
	t.eq(view2.unrevealed_count(), 0, "剩下两件亮完")
	var view3 := LootView.new()
	view3.inventory = GridInventory.new(Vector2i(2, 2), 0, false)
	root.add_child(view3)
	var fin3: Array = []
	view3.reveal_finished.connect(func(): fin3.append(true))
	view3.start_reveal()
	t.eq(fin3.size(), 1, "空容器直接算亮完")
	view.queue_free()
	view2.queue_free()
	view3.queue_free()
#endregion
