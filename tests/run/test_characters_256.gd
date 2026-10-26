## 256（作者 2026-10-26 15:06 / 15:19）：布鲁图斯照旧（容错）；马库斯的军功牌（打赢记军功、五阶、牌边的武器加成、圈变大）；
## 安德烈乌斯：体力 3、9 × 6、负重 64；偷袭（战前屏的键，敌人开战失去三成生命，休息点补一次）；求饶（会扣体力的一场打输了，
## 天平上拿金币和道具抵，核心点与搜索遭遇不给，猎手给）。期望从内容推：角色与道具文件里写多少就断言多少。
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const CS := preload("res://tests/run/test_character_skills.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "256"


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["loadouts", "events", "characters", "hunter_defs"])


## 按角色开一局（GameFlow 那条路：offer_ransom 开着），站上出生点
static func _flow(c: TestSupport.Content, id: StringName, prefix: String = PREFIX) -> GameFlow:
	var f := Support.flow(c, prefix, 0.0)
	var ch := CS._character(c, id)
	for seed in range(1, 60):
		if f.begin(c.chapter, null, seed, [] as Array[int], ch, []) != null:
			f.pick_spawn(f.run.map.entry_ids[0])
			return f
	return null


## 玩家一定打输（空棋盘、没有生命）
static func _always_lose(run: RunState) -> void:
	run.hooks.register(&"player_spec", func() -> CombatantSpec: return BattleCompiler.compile_board(null))


## 把这个点排成等着开打的一场
static func _pend(run: RunState, node: MapNode, type: String = "battle") -> void:
	run.events.pending_battle = {"node": node.id, "type": type, "content": node.content.duplicate(true), "kind": "node"}


static func _price(run: RunState, node: MapNode) -> int:
	var reward := run.economy.battle_reward(int(node.content.get("strength", 0)), float(run.events._depths.get(node.id, 0.0)), run.events.difficulty)
	return roundi(float(reward) * run.buff_context().ransom_mult)


static func _phalera(run: RunState) -> ItemInstance:
	for inst in run.board.items():
		if (inst as ItemInstance).def.id == &"legion_phalera":
			return inst
	return null


## 编译出来的这一件的某项属性（浮点）
static func _stat_of(run: RunState, uid: int, key: StringName) -> float:
	for it in run.compile_player().items:
		if (it as CompiledItem).source_uid == uid:
			return StatMath.to_float((it as CompiledItem).stats.total_of(key))
	return -1.0


static func run_panels(t: TestCase) -> void:
	t.begin("256 · 面板：安德烈乌斯体力 3、耐力 45、9 × 6、负重 64（生命 45、回气 4、带钱 120 不动）；布鲁图斯、马库斯的面板不动")
	var c := _content()
	var a := CS._character(c, &"andreus")
	t.eq(a.vitality_max, 3, "安德烈乌斯体力 3")
	t.eq(a.board_size, Vector2i(9, 6), "棋盘 9 × 6")
	t.eq(a.weight_capacity, 64, "负重 64")
	t.eq(a.baseline().value_of(&"max_stamina"), 45.0, "耐力 45")
	t.eq(a.baseline().value_of(&"max_hp"), 45.0, "生命 45")
	t.eq(a.starting_funds, 120, "带钱 120")
	t.check(not a.skills.any(func(s: RunSkill) -> bool: return s is SlipSkill), "脱身删了")
	var b := CS._character(c, &"brutus")
	t.eq([b.vitality_max, b.board_size, b.weight_capacity], [7, Vector2i(9, 6), 56], "布鲁图斯不动")
	t.check(Names.description_of(b).contains("棋盘最宽之一"), "布鲁图斯：「棋盘最宽之一」")
	var m := CS._character(c, &"marcus")
	t.eq(m.skills.map(func(s: RunSkill) -> StringName: return s.id), [&"drill"], "马库斯只留操练")
	t.eq(m.fixed_items.size(), 1, "马库斯带一件随身之物")
	t.eq([m.fixed_items[0].id, m.fixed_items[0].origin], [&"legion_phalera", Vector2i(3, 2)], "军功牌钉在 (3, 2)")


static func run_ambush(t: TestCase) -> void:
	t.begin("256 · 偷袭：战前屏按了 = 用掉一次 + 开打，敌人生命上限是原来的七成；没有冷却；休息点补一次、补不过上限；核心点也能用")
	var c := _content()
	var f := _flow(c, &"andreus")
	if f == null:
		t.check(false, "开不了局")
		return
	var run := f.run
	var amb := f.prebattle_skill() as AssaultSkill
	t.not_null(amb, "战前屏有键的技能：偷袭")
	if amb == null:
		return
	t.check(amb.shown_to_player(), "藏着的主动（166）对它不生效")
	t.eq([amb.uses, amb.cooldown_steps, amb.rest_recharge], [2, 0, 1], "次数 2、没有冷却、休息补 1")
	var node := CS._battle_node(run)
	var plain := EnemyKit.spec_of(node.content, c.enemies, run.pool, c.items)
	t.eq(f.ambush_battle(), UiText.t("pre.no_battle"), "没有等着开打的一场：按不了")
	_pend(run, node)
	t.eq(f.ambush_battle(), "", "偷袭开打")
	var fought: CombatantSpec = run.events.last_battle["enemy"]
	t.eq(fought.max_hp, maxi(1, int(roundf(float(plain.max_hp) * 0.7))), "敌人生命上限 = 七成")
	t.eq(run.skills.uses_of(amb.id), 1, "次数 2 → 1")
	t.eq(run.skills.cooldown_of(amb.id), 0, "没有冷却")
	t.eq(f.screen, GameFlow.Screen.BATTLE, "→ 回放")
	Support.settle(f)
	run.events.rested.emit(node, 0)
	t.eq(run.skills.uses_of(amb.id), 2, "休息点补一次")
	run.events.rested.emit(node, 0)
	t.eq(run.skills.uses_of(amb.id), 2, "补不过上限")
	if run.is_over():
		return
	_pend(run, node, "core")
	t.eq(f.ambush_battle(), "", "核心点也能偷袭")
	t.eq(run.skills.uses_of(amb.id), 1, "用掉一次")
	Support.cleanup(PREFIX)


static func run_ransom(t: TestCase) -> void:
	t.begin("256 · 求饶：普通 / 精英 / 猎手打输 → 开价 = 打赢的钱 × 倍数、不扣体力；成交扣钱与道具、体力不动；不求饶照扣、归零战败；核心点与搜索遭遇没有天平；别的角色没有")
	var c := _content()
	var f := _flow(c, &"andreus")
	if f == null:
		t.check(false, "开不了局")
		return
	var run := f.run
	_always_lose(run)
	run.wallet.earn(2000)
	var node := CS._battle_node(run)
	var v0 := run.vitality.current
	t.eq(run.buff_context().ransom_mult, 3.0, "倍数 3")
	_pend(run, node)
	t.check(f.start_battle(), "开战")
	t.eq(run.vitality.current, v0, "输了：体力先不扣")
	t.eq(int(run.events.pending_ransom.get("price", -1)), _price(run, node), "开价 = 打赢的钱 × 3（%d）" % _price(run, node))
	t.check(_price(run, node) > 0, "开价大于 0")
	t.eq(f.screen, GameFlow.Screen.BATTLE, "先看回放")
	f.resume()
	t.eq(f.screen, GameFlow.Screen.RANSOM, "回放之后 → 天平")
	t.check(not f.hide_overlay(), "天平收不起来")
	t.check(not f.step_to(run.travel.available_moves()[0]) if not run.travel.available_moves().is_empty() else true, "天平上走不了")
	var price := int(run.events.pending_ransom["price"])
	t.ne(f.pay_ransom(price - 1), "", "不够开价：成不了")
	t.ne(f.pay_ransom(run.wallet.balance + 1), "", "钱包不够：成不了")
	# 一件道具 + 金币凑够
	var def := c.items.get_def(&"knife")
	var knife := ItemInstance.create(def)
	var worth := run.events.ransom_value_of(knife)
	t.eq(worth, ShopSession.sell_price_for(def, knife, run.economy, run.buff_context().shop_price_mult), "道具按局内出售价算重量（%d）" % worth)
	var m0 := run.wallet.balance
	t.eq(f.pay_ransom(price - worth, [knife]), "", "金币 + 道具 ≥ 开价：成交")
	t.eq(run.wallet.balance, m0 - (price - worth), "钱包扣了放上去的金币")
	t.eq(run.vitality.current, v0, "体力不动")
	t.check(run.events.pending_ransom.is_empty(), "开价清了")
	t.ne(f.screen, GameFlow.Screen.RANSOM, "离开天平")
	Support.settle(f)
	# 精英：不求饶 → 照扣
	_pend(run, node, "elite")
	f.start_battle()
	t.check(not run.events.pending_ransom.is_empty(), "精英打输也开价")
	var cost := int(run.events.pending_ransom["cost"])
	t.check(f.refuse_ransom(), "不求饶")
	t.eq(run.vitality.current, v0 - cost, "照扣 %d 点体力" % cost)
	Support.settle(f)
	# 猎手：给（作者只排除了 BOSS 和搜索遭遇）
	run.vitality.restore(run.vitality.maximum, &"probe")
	var v1 := run.vitality.current
	run.events.fight_content(node, HunterSystem.TYPE, node.content)
	t.check(not run.events.pending_ransom.is_empty(), "猎手打输也开价")
	t.eq(run.vitality.current, v1, "体力先不扣")
	t.check(f.pay_ransom(int(run.events.pending_ransom["price"])) == "", "付钱了结")
	Support.settle(f)
	# 搜索遭遇：无代价，不出天平
	run.events.fight_content(node, &"search", node.content, null, 0)
	t.check(run.events.pending_ransom.is_empty(), "搜索遭遇没有天平")
	run.events.fight_content(node, &"search", node.content, null, 1)
	t.check(run.events.pending_ransom.is_empty(), "搜索遭遇就算写了代价也不给求饶")
	t.eq(run.vitality.current, v1 - 1, "照扣")
	# 不求饶扣到底：战败
	while run.vitality.current > 1:
		run.vitality.spend(1, &"probe")
	_pend(run, node)
	f.start_battle()
	t.check(not run.is_over(), "开价时还没输掉这一局")
	f.refuse_ransom()
	t.check(run.is_over(), "不求饶、体力归零：战败")
	Support.settle(f)     # 回放看完
	t.eq(f.screen, GameFlow.Screen.RESULT, "→ 结算")
	# 核心点：BOSS 输了必死，没有天平
	var g := _flow(c, &"andreus", "256b")
	_always_lose(g.run)
	g.run.wallet.earn(2000)
	_pend(g.run, CS._battle_node(g.run), "core")
	g.start_battle()
	t.check(g.run.events.pending_ransom.is_empty() and g.run.is_over(), "核心点：没有天平、直接战败")
	# 别的角色：没有天平，照扣
	for id in [&"brutus", &"marcus"]:
		var h := _flow(c, id, "256c")
		_always_lose(h.run)
		var hv := h.run.vitality.current
		_pend(h.run, CS._battle_node(h.run))
		h.start_battle()
		t.check(h.run.events.pending_ransom.is_empty(), "%s 打输没有天平" % id)
		t.check(h.run.vitality.current < hv, "%s 照扣体力" % id)
	for p in [PREFIX, "256b", "256c"]:
		Support.cleanup(p)


static func run_ransom_save(t: TestCase) -> void:
	t.begin("256 · 求饶跟着存档：天平上存档退出，读回来还停在天平上、开价一样；读回来的也能成交")
	var c := _content()
	var f := _flow(c, &"andreus")
	if f == null:
		t.check(false, "开不了局")
		return
	_always_lose(f.run)
	f.run.wallet.earn(2000)
	_pend(f.run, CS._battle_node(f.run))
	f.start_battle()
	var pending := f.run.events.pending_ransom.duplicate(true)
	t.check(not pending.is_empty(), "开了价")
	t.check(f.save(), "存档")
	var f2 := Support.flow(c, PREFIX, 0.0, null, true)
	t.check(f2.continue_run(), "读档")
	t.eq(f2.screen, GameFlow.Screen.RANSOM, "读回来停在天平上")
	var back: Dictionary = f2.run.events.pending_ransom
	t.eq([back.get("node"), back.get("type"), back.get("cost"), back.get("price"), back.get("content", {}).get("enemy")],
		[pending["node"], pending["type"], pending["cost"], pending["price"], pending["content"]["enemy"]], "开价原样")
	var v := f2.run.vitality.current
	t.eq(f2.pay_ransom(int(pending["price"])), "", "成交")
	t.eq(f2.run.vitality.current, v, "体力不动")
	Support.cleanup(PREFIX)


static func run_phalera(t: TestCase) -> void:
	t.begin("256 · 军功牌：打赢记军功（普通 1、精英 3、核心 5；输了不记）；铜 0 / 银 3 / 金 8 / 鎏金 15 / 桂冠 25；牌边的武器加伤害 / 急速、减耐力消耗；圈 4 → 8 → 12 格；一局内（存档带着、新开一局从铜起）")
	var c := _content()
	var f := _flow(c, &"marcus")
	if f == null:
		t.check(false, "开不了局")
		return
	var run := f.run
	var pin := _phalera(run)
	t.not_null(pin, "棋盘上钉着军功牌")
	if pin == null:
		return
	t.check(pin.is_pinned() and pin.origin == Vector2i(3, 2), "钉在 (3, 2)")
	t.check(not c.items.ids().has(&"legion_phalera") and c.items.all_ids().has(&"legion_phalera"), "随身之物：搜索 / 掉落 / 商店 / 图鉴都不出")
	t.not_null(HonorModule.of(run), "装了军功模块")
	t.eq([GrowthProfile.honor_of(pin), GrowthProfile.stage_of(pin)], [0, 0], "开局：铜、0 点")
	# 牌边上（上方）、斜角、隔一格各一把刀
	for inst in run.board.items().duplicate():
		if not (inst as ItemInstance).is_pinned():
			run.board.remove((inst as ItemInstance).uid)
	# 刀是 1×2：正上方竖放（贴牌）、左上竖放（只斜角挨着）、右边隔一格横放；刀要包，军功牌钉着不用
	for at in [Vector2i(2, 0), Vector2i(5, 2)]:
		t.check(run.board.place(ItemInstance.create(c.items.get_def(&"bag_small")), at, 0), "小包放在 %s" % at)
	var knives := {}
	for spot in [[Vector2i(3, 0), 0], [Vector2i(2, 0), 0], [Vector2i(5, 2), 1]]:
		var k := ItemInstance.create(c.items.get_def(&"knife"))
		t.check(run.board.place(k, spot[0], spot[1]), "刀放在 %s" % spot[0])
		knives[spot[0]] = k.uid
	var base_dmg := {}
	for at in knives:
		base_dmg[at] = _stat_of(run, knives[at], BattleStats.DAMAGE)
	var base_haste := _stat_of(run, knives[Vector2i(3, 0)], BattleStats.HASTE)
	var node := CS._battle_node(run)
	var win := func(type: String, won: bool = true) -> void:
		run.events.last_battle = {"type": type}
		run.events.battle_finished.emit(node, null, won)
	win.call("battle", false)
	t.eq(GrowthProfile.honor_of(pin), 0, "输了不记")
	win.call("battle")
	t.eq(GrowthProfile.honor_of(pin), 1, "普通一场 +1")
	t.eq(_stat_of(run, knives[Vector2i(3, 0)], BattleStats.DAMAGE), base_dmg[Vector2i(3, 0)], "铜：牌边没有加成")
	win.call("elite")
	t.eq([GrowthProfile.honor_of(pin), GrowthProfile.stage_of(pin)], [4, 1], "精英 +3 → 4 点：银")
	var up: float = _stat_of(run, knives[Vector2i(3, 0)], BattleStats.DAMAGE)
	t.check(absf(up - base_dmg[Vector2i(3, 0)] * 1.05) < 0.02, "银：上方的刀伤害 +5%%（%.2f → %.2f）" % [base_dmg[Vector2i(3, 0)], up])
	t.check(_stat_of(run, knives[Vector2i(3, 0)], BattleStats.HASTE) > base_haste, "急速也加了")
	t.eq(_stat_of(run, knives[Vector2i(2, 0)], BattleStats.DAMAGE), base_dmg[Vector2i(2, 0)], "银：斜角不在圈里（四格）")
	t.eq(GrowthProfile.adjacency_of(pin).grant_cells.size(), 4, "银：四格")
	t.check(Names.of_item(pin).begins_with("银"), "名字带前缀：%s" % Names.of_item(pin))
	win.call("core")
	t.eq([GrowthProfile.honor_of(pin), GrowthProfile.stage_of(pin)], [9, 2], "核心 +5 → 9 点：金")
	t.eq(GrowthProfile.adjacency_of(pin).grant_cells.size(), 8, "金：八格")
	t.check(_stat_of(run, knives[Vector2i(2, 0)], BattleStats.DAMAGE) > base_dmg[Vector2i(2, 0)], "金：斜角的刀也加了")
	t.eq(_stat_of(run, knives[Vector2i(5, 2)], BattleStats.DAMAGE), base_dmg[Vector2i(5, 2)], "金：隔一格的还不在圈里")
	var lines := ItemTooltip.honor_lines(pin)
	t.check(lines[0].contains("9") and lines[0].contains("15"), "悬浮窗：军功 9 / 15（%s）" % lines[0])
	t.eq(lines.size(), 1 + 1 + pin.def.growth.stages.size(), "从铜到桂冠每阶一行")
	win.call("core")
	win.call("battle")
	t.eq([GrowthProfile.honor_of(pin), GrowthProfile.stage_of(pin)], [15, 3], "15 点：鎏金")
	t.eq(GrowthProfile.adjacency_of(pin).grant_cells.size(), 12, "鎏金：十二格")
	t.check(_stat_of(run, knives[Vector2i(5, 2)], BattleStats.DAMAGE) > base_dmg[Vector2i(5, 2)], "鎏金：隔一格的刀也加了")
	for i in 2:
		win.call("core")
	t.eq(GrowthProfile.stage_of(pin), 4, "25 点：桂冠（满阶）")
	t.check(absf(_stat_of(run, knives[Vector2i(3, 0)], BattleStats.DAMAGE) - base_dmg[Vector2i(3, 0)] * 1.2) < 0.02, "桂冠：伤害 +20%")
	win.call("core")
	t.eq(GrowthProfile.stage_of(pin), 4, "满阶不再升，点照记")
	t.eq(GrowthProfile.honor_of(pin), 30, "30 点")
	# 走步不长（不是自然系的生长）
	var before := pin.state.duplicate()
	var growth := GrowthModule.of(run)
	if growth != null:
		t.check(not growth.growing().has(pin), "倒计时走步不长军功牌")
	t.eq(pin.state, before, "状态没被动过")
	# 存档带着
	t.check(f.save(), "存档")
	var f2 := Support.flow(c, PREFIX, 0.0, null, true)
	t.check(f2.continue_run(), "读档")
	var pin2 := _phalera(f2.run)
	t.eq([GrowthProfile.honor_of(pin2), GrowthProfile.stage_of(pin2)], [30, 4], "读回来：30 点、桂冠")
	# 新开一局：从铜起
	var f3 := _flow(c, &"marcus", "256d")
	var pin3 := _phalera(f3.run)
	t.eq([GrowthProfile.honor_of(pin3), GrowthProfile.stage_of(pin3)], [0, 0], "新开一局：铜、0 点（不进局外）")
	Support.cleanup(PREFIX)
	Support.cleanup("256d")


static func frame_prebattle_ambush(t: TestCase, root: Window) -> void:
	t.begin("256 · 战前屏的偷袭键：安德烈乌斯才有，写剩几次；按下直接开打；用完了灰着")
	var c := _content()
	var p := Support.paths("256f")
	Support.cleanup("256f")
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	var ch := c.chapter.duplicate() as ChapterDef
	ch.coaches = {}
	flow.chapters = [ch] as Array[ChapterDef]
	var andreus := CS._character(c, &"andreus")
	var started := false
	for seed in range(1, 60):
		if flow.begin(ch, null, seed, [] as Array[int], andreus) != null:
			started = true
			break
	if not started:
		t.check(false, "开不了局")
		game.free()
		return
	flow.pick_spawn(flow.run.map.entry_ids[0])
	var node := CS._battle_node(flow.run)
	_pend(flow.run, node)
	flow.resume()
	var pre = game.overlay()
	t.check(pre != null and pre.screen == GameFlow.Screen.PREBATTLE, "到了战前准备")
	if pre == null or pre.screen != GameFlow.Screen.PREBATTLE:
		game.free()
		return
	var key: Button = pre.ambush_button()
	t.not_null(key, "有偷袭键")
	t.check(key != null and key.text.contains("偷袭") and key.text.contains("剩 2 次"), "键上写名字和剩几次：%s" % (key.text if key != null else ""))
	t.check(key != null and not key.disabled, "能按")
	pre.ambush()
	t.eq(flow.screen, GameFlow.Screen.BATTLE, "按下直接开打")
	t.eq(flow.run.skills.uses_of(&"ambush"), 1, "用掉一次")
	game.free()
	Support.cleanup("256f")


static func frame_ransom_screen(t: TestCase, root: Window) -> void:
	t.begin("256 · 天平窗：托盘（有框有格）+ 金币步进件 + 天平；左 ≥ 右「成交」才亮；托盘上的东西按出售价加重；锁着的放不上；不求饶东西回包里")
	var c := _content()
	var p := Support.paths("256g")
	Support.cleanup("256g")
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	var ch := c.chapter.duplicate() as ChapterDef
	ch.coaches = {}
	flow.chapters = [ch] as Array[ChapterDef]
	var andreus := CS._character(c, &"andreus")
	for seed in range(1, 60):
		if flow.begin(ch, null, seed, [] as Array[int], andreus) != null:
			break
	flow.pick_spawn(flow.run.map.entry_ids[0])
	var run := flow.run
	_always_lose(run)
	run.wallet.earn(1000)
	_pend(run, CS._battle_node(run))
	flow.start_battle()
	flow.resume()
	var scr = game.overlay()
	t.check(scr != null and scr.screen == GameFlow.Screen.RANSOM, "回放之后是天平窗")
	if scr == null or scr.screen != GameFlow.Screen.RANSOM:
		game.free()
		return
	t.not_null(scr.tray(), "有托盘")
	t.check(BoardFrame.framed(scr._tray_view), "托盘有框")
	var price: int = scr.price()
	t.eq(scr.scale_widget().right, price, "右盘 = 开价")
	t.check(scr.pay_button().disabled, "什么都没放：成交灰着")
	t.eq(scr.scale_widget().plate_text(), "还差 %d" % price, "梁上写还差多少")
	# 放一件道具
	var knife := ItemInstance.create(c.items.get_def(&"knife"))
	run.board.try_add(knife, true)
	t.check(scr.offer(knife.uid), "刀放上托盘")
	var worth := run.events.ransom_value_of(knife)
	t.eq(scr.weight(), worth, "左盘 = 刀的出售价 %d" % worth)
	var locked := ItemInstance.create(c.items.get_def(&"knife"))
	run.board.try_add(locked, true)
	locked.set_locked(true)
	if locked.is_locked_by_player():
		t.check(not scr.offer(locked.uid), "锁着的放不上")
	scr.set_coins(price)
	t.eq(scr.coins, price, "金币 %d" % price)
	t.check(not scr.pay_button().disabled, "够了：成交亮了")
	t.eq(scr.scale_widget().plate_text(), "够了", "梁上写够了")
	t.check(scr.scale_widget().tilt_degrees() > 0.0, "左重：左盘低")
	scr.set_coins(0)
	t.check(scr.pay_button().disabled == (worth < price), "金币拿回来：按刀够不够")
	# 不求饶：刀回包里
	var v := run.vitality.current
	scr.refuse()
	t.check(run.board.has_item(knife.uid) or run.storage.has_item(knife.uid), "不求饶：托盘上的刀回来了")
	t.eq(run.vitality.current, v - 1, "扣了体力")
	game.free()
	Support.cleanup("256g")
