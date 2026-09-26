## 一局的壳（M5，架构文档 7 节）：开局、走、战利品进暂存区、买东西、战败与撤离、存档往返、读档之后接着走一样。
extends RefCounted

const KIT: Array[StringName] = [&"bag_leather", &"bag_leather", &"rifle", &"pistol", &"armor", &"medkit"]
const SAVE_PATH := "user://test_run_state.json"


class Content:
	extends RefCounted
	var items: ItemDatabase
	var enemies: EnemyDatabase
	var sets: SetDatabase
	var chapter: ChapterDef


static func _content() -> Content:
	var c := Content.new()
	c.items = ItemDatabase.new()
	c.items.load_dir()
	c.enemies = EnemyDatabase.new()
	c.enemies.load_all()
	c.sets = SetDatabase.new()
	c.sets.load_dir()
	c.chapter = load(ContentPaths.asset_file("chapters", "chapter_01"))
	return c


static func _start(c: Content, seed: int, kit: Array[StringName] = KIT) -> RunState:
	var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit)
	if s != null:
		s.player_baseline = CombatantBaseline.with_hp(10000.0)   # 测试里不想输的时候
	return s


## 当前点旁边第一个还没用过的某类型点，-1 = 没有
static func _neighbor_of_type(s: RunState, type: StringName) -> int:
	for id in s.travel.available_moves():
		var n := s.map.get_node(id)
		if n.type == type and not n.is_visited():
			return id
	return -1


## 找一个出生点旁边就有战斗点的种子并开局
static func _start_with_battle_next(c: Content, kit: Array[StringName] = KIT) -> RunState:
	for seed in range(1, 60):
		var s := _start(c, seed, kit)
		if s == null:
			continue
		for entry in s.map.entry_ids:
			for nid in s.map.neighbors(entry):
				if s.map.get_node(nid).type == &"battle":
					s.pick_spawn(entry)
					return s
	return null


## 语义签名：不含 uid（读档后新建的 uid 从存档里最大的接着编，和没存过的不一样，但那不是状态）
static func _signature(s: RunState) -> String:
	var nodes := {}
	for id in s.map.node_ids():
		var n := s.map.get_node(id)
		nodes[str(id)] = {"type": String(n.type), "state": n.state, "content": n.content}
	var storage: Array = []
	for inst in s.storage.items():
		storage.append(String((inst as ItemInstance).def.id))
	storage.sort()
	var board: Array = []
	for inst in s.board.items():
		board.append([String((inst as ItemInstance).def.id), (inst as ItemInstance).origin.x, (inst as ItemInstance).origin.y])
	board.sort()
	return JSON.stringify({
		"phase": s.phase, "end": String(s.end_reason), "nodes": nodes, "travel": s.travel.to_dict(),
		"vitality": s.vitality.to_dict(), "wallet": s.wallet.to_dict(), "storage": storage, "board": board,
		"rng": s.rng.to_dict(), "searches": s.events.searches_closed,
		"pending": s.pending_loot.item_count() if s.pending_loot != null else -1,
	})


static func run_start(t: TestCase) -> void:
	t.begin("一局 · 开局：图、敌人、付费撤离点、棋盘、暂存区、钱、体力都齐了")

	var c := _content()
	var s := _start(c, 1)
	t.not_null(s, "开得了局")
	if s == null:
		return
	t.eq(s.phase, RunState.Phase.PICK_SPAWN, "先挑出生点")
	t.check(s.map != null and s.map.node_count() > 0, "有图")
	var with_enemy := 0
	var paid := 0
	for id in s.map.node_ids():
		var n := s.map.get_node(id)
		if EnemyKit.has_enemy(n.content):
			with_enemy += 1
		if PaidExtracts.fee_of(n) > 0:
			paid += 1
	t.check(with_enemy > 0, "敌人放好了（%d 个）" % with_enemy)
	t.eq(paid, s.economy.paid_extracts, "付费撤离点标好了")
	t.eq(s.wallet.balance, s.economy.starting_balance, "开局的钱来自经济规则")
	t.check(s.vitality.is_full(), "体力满的")
	t.check(s.board.requires_bag, "作战棋盘是棋盘模式（只有包里的东西参战）")
	var bags := 0
	for inst in s.board.items():
		if (inst as ItemInstance).def.is_bag:
			bags += 1
	t.eq(bags, 2, "两个包放上了棋盘")
	var non_bag_kit := 0
	for id in KIT:
		if not c.items.get_def(id).is_bag:
			non_bag_kit += 1
	t.eq(s.board.item_count() - bags + s.storage.item_count(), non_bag_kit, "其余的东西不在棋盘就在暂存区，一件不少")
	var me := s.compile_player()
	t.check(me.rough_dps() > 0.0, "玩家编译出来会打（%.1f DPS）" % me.rough_dps())
	t.check(s.tracker != null, "套装追踪器绑在棋盘上")
	t.check(not s.pick_spawn(-5), "不是出生点挑不了")
	t.check(not s.step_to(s.map.entry_ids[0]), "没开局走不了")
	t.check(s.pick_spawn(s.map.entry_ids[0]), "挑出生点")
	t.eq(s.phase, RunState.Phase.ON_MAP, "在图上了")
	t.check(not s.pick_spawn(s.map.entry_ids[0]), "开局之后不能再挑")
	t.check(RunState.start(c.chapter, 1, c.items, c.enemies, null) != null, "没有套装库也能开局")


static func run_loot_and_shop(t: TestCase) -> void:
	t.begin("一局 · 战利品进待拾取再进暂存区；买的东西直接进暂存区；掉落合并不丢")

	var c := _content()
	var s := _start_with_battle_next(c)
	t.not_null(s, "找到了出生点旁边有战斗点的种子")
	if s == null:
		return
	var pending: Array = []
	s.loot_pending.connect(func(box: GridInventory): pending.append(box))
	var battle := _neighbor_of_type(s, &"battle")
	var cash := s.wallet.balance
	t.check(s.step_to(battle), "走上战斗点")
	t.check(s.map.get_node(battle).is_visited(), "打完点用过了")
	t.check(s.wallet.balance > cash, "一万血两把枪：赢了，进账")
	if s.pending_loot == null:
		t.check(true, "这一场什么都没掉（掉落是概率）")
	else:
		t.eq(pending.size(), 1, "发了 loot_pending")
		var before := s.storage.item_count()
		var n := s.pending_loot.item_count()
		var first: int = (s.pending_loot.items()[0] as ItemInstance).uid
		t.check(s.take_loot(first), "拿一件")
		t.eq(s.storage.item_count(), before + 1, "进了暂存区")
		if n > 1:
			t.eq(s.take_all_loot(), n - 1, "剩下的全拿")
		t.check(s.pending_loot == null, "拿完待拾取清空")
		t.eq(s.storage.item_count(), before + n, "一件不少")
	t.check(not s.take_loot(1) and s.take_all_loot() == 0, "没有待拾取时拿不到东西")

	# 待拾取还没处理又来一份：合并
	var box_a := GridInventory.new(Vector2i(4, 4), 0, false)
	box_a.try_add(ItemInstance.create(c.items.get_def(&"ration"), 0), true)
	var box_b := GridInventory.new(Vector2i(4, 4), 0, false)
	box_b.try_add(ItemInstance.create(c.items.get_def(&"stim"), 0), true)
	s._offer_loot(box_a)
	s._offer_loot(box_b)
	t.eq(s.pending_loot.item_count(), 2, "两份并成一份")
	s.discard_loot()
	t.check(s.pending_loot == null, "丢掉")

	# 商店：直接把商店点当事件处理（不用走过去）
	var shop_id := -1
	for id in s.map.node_ids():
		if s.map.get_node(id).type == &"shop":
			shop_id = id
			break
	if shop_id >= 0:
		var before := s.storage.item_count() + s.board.item_count()
		s.wallet.earn(10000, &"test")
		s.events.handle(s.map.get_node(shop_id))
		var session := s.events.current_shop
		t.not_null(session, "店开了")
		if session != null:
			t.not_null(session.buy(session.available()[0]), "买一件")
			t.eq(s.storage.item_count() + s.board.item_count(), before + 1, "买的东西进了包（放不下进暂存区，087）")
			s.close_sessions()
			t.check(s.events.current_shop == null, "关门")

	# 暂存区 ↔ 棋盘
	if s.storage.item_count() > 0:
		var uid: int = (s.storage.items()[0] as ItemInstance).uid
		var on_board := s.board.item_count()
		if s.equip(uid):
			t.eq(s.board.item_count(), on_board + 1, "暂存区 → 棋盘")
			t.check(s.unequip(uid), "棋盘 → 暂存区")
			t.eq(s.board.item_count(), on_board, "回来了")


static func run_end(t: TestCase) -> void:
	t.begin("一局 · 结束：体力归零战败；撤离点上撤离，付费的先付钱")

	var c := _content()
	var s := _start_with_battle_next(c, [] as Array[StringName])
	t.not_null(s, "空手开局")
	if s == null:
		return
	s.player_baseline = CombatantBaseline.with_hp(1.0)
	var phases: Array = []
	s.phase_changed.connect(func(p: int, why: StringName): phases.append([p, why]))
	s.vitality.spend(s.vitality.current - 1, &"test")
	var battle := _neighbor_of_type(s, &"battle")
	t.check(s.step_to(battle), "空手一血走上战斗点")
	t.eq(s.phase, RunState.Phase.DEFEATED, "输了、体力归零 → 战败")
	t.eq(s.end_reason, &"vitality_depleted", "原因")
	t.check(s.is_over(), "结束了")
	t.check(not s.step_to(s.travel.current_id), "结束了走不了")
	t.eq(phases[phases.size() - 1], [RunState.Phase.DEFEATED, &"vitality_depleted"], "发了 phase_changed")

	# 撤离：把人放到撤离点上（测试用的传送）
	var s2 := _start(c, 3)
	s2.pick_spawn(s2.map.entry_ids[0])
	var free_extract := -1
	var paid_extract := -1
	for id in s2.map.node_ids():
		var n := s2.map.get_node(id)
		if n.type == &"extract":
			if PaidExtracts.fee_of(n) > 0:
				paid_extract = id
			else:
				free_extract = id
	t.check(not s2.try_extract(), "不在撤离点上撤不了")
	if free_extract >= 0:
		s2.travel.start_at(free_extract)
		t.check(s2.try_extract(), "免费撤离点：撤了")
		t.eq(s2.phase, RunState.Phase.EXTRACTED, "阶段：撤离")
	var s3 := _start(c, 3)
	s3.pick_spawn(s3.map.entry_ids[0])
	if paid_extract >= 0:
		s3.travel.start_at(paid_extract)
		s3.wallet.spend(s3.wallet.balance, &"test")
		t.check(not s3.try_extract(), "付费撤离点没钱撤不了")
		t.eq(s3.phase, RunState.Phase.ON_MAP, "还在图上")
		s3.wallet.earn(s3.economy.extract_fee, &"test")
		t.check(s3.try_extract(), "钱够了撤")
		t.eq(s3.wallet.balance, 0, "付了费")
		t.eq(s3.phase, RunState.Phase.EXTRACTED, "阶段：撤离")


static func run_save(t: TestCase) -> void:
	t.begin("一局 · 存档：往返一致、版本号、读档之后接着走和没存过一样")

	var c := _content()
	var s := _start_with_battle_next(c)
	if s == null:
		t.check(false, "开不了局")
		return
	# 走一步，再存
	var battle := _neighbor_of_type(s, &"battle")
	s.step_to(battle)
	if s.pending_loot != null:
		s.take_loot((s.pending_loot.items()[0] as ItemInstance).uid)   # 留一部分在待拾取里，存档得带上
	var text := RunSave.to_text(s)
	var d: Dictionary = JSON.parse_string(text)
	t.eq(int(d["version"]), RunState.SAVE_VERSION, "带版本号")
	t.eq(String(d["chapter"]), String(c.chapter.id), "章节只写 id")
	var back := RunSave.from_text(text, c.items, c.enemies, c.sets)
	t.not_null(back, "读得回来")
	if back == null:
		return
	t.eq(_signature(back), _signature(s), "语义签名一致：图、内容、旅程、体力、钱、棋盘、暂存区、待拾取、随机流")
	t.eq(RunSave.to_text(back), text, "再存一次逐字节相同")
	t.eq(back.phase, RunState.Phase.ON_MAP, "阶段接着")
	t.check(back.events != null and back.events.travel == back.travel, "节点事件重新接上了旅程")
	t.eq(back.compile_player().rough_dps(), s.compile_player().rough_dps(), "读档后玩家编译出来一样")

	# 读档之后接着走：和没存过的那份走同样的路，结果一样
	var steps := 0
	while steps < 6 and not s.is_over():
		var moves := s.travel.available_moves()
		var moves_b := back.travel.available_moves()
		t.eq(moves_b, moves, "第 %d 步：能走的地方一样" % steps)
		if moves.is_empty():
			break
		s.step_to(moves[0])
		back.step_to(moves_b[0])
		s.close_sessions()
		back.close_sessions()
		s.take_all_loot()
		back.take_all_loot()
		steps += 1
	t.eq(_signature(back), _signature(s), "走了 %d 步之后语义签名仍一致" % steps)

	# 版本不对不猜
	var wrong := text.replace("\"version\": %d" % RunState.SAVE_VERSION, "\"version\": 99")
	t.check(RunSave.from_text(wrong, c.items, c.enemies, c.sets) == null, "不认识的版本 → null")
	t.check(RunSave.from_text("not json", c.items, c.enemies, c.sets) == null, "坏文件 → null")
	var no_chapter := text.replace("\"chapter\": \"%s\"" % c.chapter.id, "\"chapter\": \"no_such\"")
	t.check(RunSave.from_text(no_chapter, c.items, c.enemies, c.sets) == null, "章节不在 → null")

	# 真写文件
	t.eq(RunSave.write(s, SAVE_PATH), OK, "写进 user://")
	t.check(RunSave.exists(SAVE_PATH), "文件在")
	var from_file := RunSave.read(c.items, c.enemies, c.sets, SAVE_PATH)
	t.check(from_file != null and _signature(from_file) == _signature(s), "从文件读回来一样")
	RunSave.remove(SAVE_PATH)
	t.check(not RunSave.exists(SAVE_PATH), "删掉了")
	t.check(RunSave.read(c.items, c.enemies, c.sets, SAVE_PATH) == null, "没文件读到 null")

	# 开着店存档：视为离开了那个点
	var shop_id := -1
	for id in s.map.node_ids():
		if s.map.get_node(id).type == &"shop":
			shop_id = id
			break
	if shop_id >= 0 and not s.is_over():
		s.events.handle(s.map.get_node(shop_id))
		t.not_null(s.events.current_shop, "店开着")
		var again := RunSave.from_text(RunSave.to_text(s), c.items, c.enemies, c.sets)
		t.check(again != null and again.events.current_shop == null, "读档回来店关了")
		if again != null:
			t.eq(again.map.get_node(shop_id).content.get("shop", {}), s.map.get_node(shop_id).content.get("shop", {}), "货架进度跟着图存")


static func run_rng(t: TestCase) -> void:
	t.begin("一局 · 分流随机源：按流独立、按序号可复现、序号跟着存档")

	var a := RunRNG.new(7)
	var b := RunRNG.new(7)
	t.eq(a.next(&"loot").randi(), b.next(&"loot").randi(), "同种子同流第 0 次一样")
	t.eq(a.next(&"loot").randi(), b.next(&"loot").randi(), "第 1 次也一样")
	t.eq(a.index_of(&"loot"), 2, "抽了两次")
	var c := RunRNG.new(7)
	c.next(&"battle")
	c.next(&"battle")
	t.eq(c.next(&"loot").randi(), RunRNG.new(7).next(&"loot").randi(), "别的流抽过多少次不影响这个流")
	t.ne(RunRNG.new(7).next(&"loot").randi(), RunRNG.new(8).next(&"loot").randi(), "种子不同不一样")
	var back := RunRNG.from_dict(a.to_dict())
	t.eq(back.index_of(&"loot"), 2, "序号跟着存档")
	t.eq(back.next(&"loot").randi(), b.next(&"loot").randi(), "读档后接着抽的和没存过一样")
