## 全局倒计时与带入预算（092 / 094 的规则；101 之后是一局的模块 [CountdownModule]）：一局总共这么多行动点，
## 归零 = 行动失败；过半关掉离出生点最近的免费撤离点；从仓库带进来的东西超出预算就按「每超多少价值 −1 步」换倒计时。
##
## 用例从 `test_author_092.gd` / `test_author_094.gd` 搬过来（102 第 A-4 条），断言一条没改。
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func run_countdown(t: TestCase) -> void:
	t.begin("倒计时 · 一局的行动点（092）：按地图规模（小 36 / 中 60 / 大 90），每走一步 -1；过半关掉离出生点最近的免费撤离点；归零 = 行动失败（time_out），保险箱里的照样带出；序章没有倒计时")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	t.eq(c.chapter.step_limit, 36, "第一章兜底 36（占位）；小图 36、中图 60、大图 90 写在规模档里")
	var f := Support.flow(c, "countdown")
	var run := f.begin(c.chapter, kit, 7)
	if run == null:
		t.check(false, "开局")
		return
	f.pick_spawn(run.map.entry_ids[0])
	var cd := CountdownModule.of(run)     # 101：倒计时是一局的模块
	t.not_null(cd, "默认清单里有倒计时")
	var limit := cd.limit()
	t.check(cd.has_countdown() and [36, 60, 90].has(limit) and cd.left() == limit, "开局倒计时 = 这个规模档的数（%d）" % limit)
	var closing := cd.closing_extract_id()
	t.check(closing >= 0, "标了一个会关的撤离点（%d）" % closing)
	if closing >= 0:
		var node := run.map.get_node(closing)
		t.check(node.type == &"extract" and PaidExtracts.fee_of(node) == 0, "是免费撤离点")
		t.eq(PaidExtracts.closes_at(node), limit / 2, "倒计时剩一半时关")
		t.check(not cd.extract_closed(node), "开局没关")
		# 离出生点最近：没有别的免费撤离点比它更近
		var best := 1 << 30
		var mine := 1 << 30
		for entry in run.map.entry_ids:
			var dist := MapNavigator.distance_map(run.map, entry)
			for id in run.map.node_ids():
				var n := run.map.get_node(id)
				if n.type == &"extract" and PaidExtracts.fee_of(n) == 0 and dist.has(id):
					best = mini(best, int(dist[id]))
					if id == closing:
						mine = mini(mine, int(dist[id]))
		t.eq(mine, best, "是离出生点最近的那个")
	var first := run.travel.available_moves()[0]
	t.check(f.step_to(first), "走一步")
	NodeScreens._settle(f)
	t.eq(cd.left(), limit - run.travel.clock.total, "倒计时 = 上限 − 花掉的行动点")
	t.check(cd.left() <= limit - 1, "走一步至少 -1")
	if closing >= 0:
		run.travel.clock.total = limit - limit / 2
		t.check(cd.extract_closed(run.map.get_node(closing)), "剩一半：关了")
		run.travel.clock.total = limit - limit / 2 - 1
		t.check(not cd.extract_closed(run.map.get_node(closing)), "剩一半 + 1：还开着")
	# 放一件进保险箱，再让倒计时归零
	var board_item: ItemInstance = null
	for inst in run.board.items():
		if not (inst as ItemInstance).def.is_bag:
			board_item = inst
			break
	if board_item != null:
		t.check(InventoryService.transfer_auto(run.board, board_item.uid, SafeModule.of(run).inventory), "一件进了保险箱")
	run.travel.clock.total = limit - 1
	var moves := run.travel.available_moves()
	t.check(not moves.is_empty() and f.step_to(moves[0]), "最后一步")
	t.check(run.is_over() and run.phase == RunState.Phase.DEFEATED and run.end_reason == &"time_out", "归零：行动失败（time_out）")
	t.eq(cd.left(), 0, "剩 0")
	var g := 0
	while GameFlow.is_overlay(f.screen) and g < 10:
		g += 1
		f.resume()
	t.eq(f.screen, GameFlow.Screen.RESULT, "→ 结算")
	var r: RunResult = f.result
	t.check(r != null and not r.is_extracted() and r.reason == &"time_out", "结算：战败、原因 time_out")
	if board_item != null:
		t.check(r != null and r.safe_items.size() == 1 and r.safe_layout.size() == 1, "保险箱里那件在账上")
		t.eq(int(f.last_absorbed.get("safe", 0)), 1, "进了局外（safe 计 1）")
		t.check(f.meta.board != null and f.meta.board.item_count() == 1, "战败也有带回来的棋盘：就是保险箱那件")
		t.check(int(f.meta.codex.get(String(board_item.def.id), 0)) >= 1, "图鉴记了")
	t.eq(f.meta.deaths, 1, "记一败")
	# 倒计时和地图规模正相关：小图 36、中图 60（过半 30）
	var small := RunState.start(c.chapter, 3, c.items, c.enemies, c.sets, kit.items, {}, [] as Array[StringName], null, [], null, {}, &"small")
	if small != null:
		t.eq(CountdownModule.of(small).limit(), 36, "小型图倒计时 36")
	var mid := RunState.start(c.chapter, 3, c.items, c.enemies, c.sets, kit.items, {}, [] as Array[StringName], null, [], null, {}, &"medium")
	if mid != null:
		t.eq(CountdownModule.of(mid).limit(), 60, "中型图倒计时 60")
		var mc := CountdownModule.of(mid).closing_extract_id()
		t.check(mc >= 0 and PaidExtracts.closes_at(mid.map.get_node(mc)) == 30, "中型图的撤离点剩 30 时关")
	else:
		t.check(true, "（中型图这个种子生成不出，跳过）")
	# 序章：没有倒计时、没有保险箱
	var p := RunState.start(c.prologue, 1, c.items, c.enemies, c.sets, [] as Array[StringName])
	if p != null:
		var pcd := CountdownModule.of(p)
		t.check(not pcd.has_countdown() and pcd.left() == -1 and pcd.closing_extract_id() == -1, "序章装了倒计时模块但这一章没有倒计时：不关撤离点")
		t.check(Support.safe_node(p) == null, "序章没有保险箱")
	Support.cleanup("countdown")


static func run_carry_budget(t: TestCase) -> void:
	t.begin("倒计时 · 带入预算换步数（094）：小 600 / 中 900 / 大 1200（章节兜底 600）；超出每 50 价值倒计时 −1，至少留 1；关闭的撤离点按罚后的一半；存档带着带入价值；开局屏的读数一行；序章没有预算")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	t.eq(CountdownModule.budget_for(c.chapter, &"small"), 600, "小图预算 600")
	t.eq(CountdownModule.budget_for(c.chapter, &"medium"), 900, "中图 900")
	t.eq(CountdownModule.budget_for(c.chapter, &"large"), 1200, "大图 1200")
	t.eq(CountdownModule.budget_for(c.chapter, &""), CountdownModule.budget_for(c.chapter, CountdownModule.scale_profile_of(c.chapter, &"").id), "默认规模 = 章节配置里默认那一档")
	t.eq(CountdownModule.budget_for(c.prologue, &""), 0, "序章没有预算")
	t.eq(CountdownModule.over_for(c.chapter, &"small", 420), 0, "420 没超")
	t.eq(CountdownModule.over_for(c.chapter, &"small", 750), 150, "750 超 150")
	t.eq(CountdownModule.penalty_for(c.chapter, &"small", 750), 3, "超 150 → −3 步")
	t.eq(CountdownModule.penalty_for(c.chapter, &"small", 649), 0, "超 49 不够一档：不罚")
	t.eq(CountdownModule.limit_for(c.chapter, &"small", 750), 33, "小图 36 − 3 = 33")
	t.eq(CountdownModule.limit_for(c.chapter, &"small", 600 + 50 * 100), 1, "罚到底至少留 1")
	t.eq(CountdownModule.limit_for(c.prologue, &"", 99999), 0, "序章没倒计时：还是 0")
	# 一局：带入价值进开局，倒计时与关闭的撤离点按罚后的算
	# 101：带入价值是倒计时模块的运行时输入
	var s := RunState.start(c.chapter, 3, c.items, c.enemies, c.sets, kit.items, {}, [] as Array[StringName], null, [], null, {}, &"small", {CountdownModule.ID: {"carry_value": 750}})
	if s == null:
		t.check(true, "（这个种子生成不出小图，跳过）")
	else:
		var cd := CountdownModule.of(s)
		t.eq(cd.carry_value, 750, "记着带入 750")
		t.eq(cd.budget(), 600, "预算 600")
		t.eq(cd.penalty_steps(), 3, "罚 3 步")
		t.eq(cd.limit(), 33, "倒计时 33")
		s.pick_spawn(s.map.entry_ids[0])
		t.eq(cd.left(), 33, "开局剩 33")
		var closing := cd.closing_extract_id()
		if closing >= 0:
			t.eq(PaidExtracts.closes_at(s.map.get_node(closing)), 16, "关闭的撤离点按 33 / 2 = 16")
		var back := RunState.from_dict(s.to_dict(), c.chapter, c.items, c.enemies, c.sets)
		t.check(back != null and CountdownModule.of(back).carry_value == 750 and CountdownModule.of(back).limit() == 33, "存档往返：带入价值与倒计时都在（modules.countdown）")
	var plain := RunState.start(c.chapter, 3, c.items, c.enemies, c.sets, kit.items, {}, [] as Array[StringName], null, [], null, {}, &"small")
	if plain != null:
		t.check(CountdownModule.of(plain).carry_value == 0 and CountdownModule.of(plain).limit() == 36, "不带：不罚")
	# GameFlow.begin：按 uid 从仓库带的自动算价值
	Support.cleanup("countdown")
	var f: GameFlow = Support.flow(c, "countdown")
	f.save_path = String(Support.paths("countdown")["run"])
	f.meta_path = String(Support.paths("countdown")["meta"])
	f.settings_path = String(Support.paths("countdown")["settings"])
	var defs_added: Array = []
	var total := 0
	for id in [&"plate_cuirass", &"longsword", &"rifle"]:
		var d: ItemDef = c.items.get_def(id)
		if d == null:
			continue
		var inst := ItemInstance.create(d)
		if f.meta.warehouse.try_add(inst, true):
			defs_added.append(inst.uid)
			total += ItemValue.of(d)
	var uids: Array[int] = []
	for u in defs_added:
		uids.append(int(u))
	var run := f.begin(c.chapter, kit, 5, uids, null, [], null, &"small")
	t.check(run != null, "开局")
	if run != null:
		t.eq(CountdownModule.of(run).carry_value, total, "从仓库按 uid 带的：价值自动算（%d）" % total)
		t.eq(CountdownModule.of(run).limit(), CountdownModule.limit_for(c.chapter, &"small", total), "倒计时按它罚")
	# 开局屏那一行
	var SetupScript = load("res://ui/game/setup_screen.gd")
	t.check(String(SetupScript.carry_text(c.chapter, &"small", 420)).contains("带入预算　420 / 600") and not String(SetupScript.carry_text(c.chapter, &"small", 420)).contains("超出"), "没超：绿字「带入预算 420 / 600」（180：不写「已带」）")
	var over_text: String = SetupScript.carry_text(c.chapter, &"small", 750)
	t.check(over_text.contains("超出 150") and over_text.contains("倒计时 −3") and over_text.contains("36 → 33"), "超了：说清超多少、扣几步（%s）" % over_text)
	t.eq(String(SetupScript.carry_text(c.prologue, &"", 999)), "", "序章没有预算：不显示")
	Support.cleanup("countdown")
