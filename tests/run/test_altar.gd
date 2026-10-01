## 神坛与信仰级效果（093 / 095 的规则；101 之后是一局的模块 [AltarModule]）：献祭换信力、每个点一次特殊操作、
## 阶到了的 [FaithPerk] 在各个落点生效。
##
## 用例从 `test_author_093.gd` 搬过来（102 第 A-4 条：谁改到哪个模块就顺手把用例搬到模块文件），断言一条没改。
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


## 这一层的套件要信仰定义表（神坛要知道献祭给谁）
static func _flow(c) -> GameFlow:
	var f := Support.flow(c, "altar")
	f.faith_defs = FaithDef.load_all()
	return f


static func run_perks_and_altar_logic(t: TestCase) -> void:
	t.begin("神坛 · 信仰级效果与那一次机会（093）：蛮神低血增伤 / 献祭生命上限 / 秒杀；日神附魔 + 祈祷非线性；自然回血 / 食物护盾 / 翻倍 / 平局算胜；大地耐力 / 锻炼加行 / 踩点赐物 / 改造此点；献祭换信力、共享一次机会")
	var c = NodeScreens._content()
	var f := _flow(c)
	var run := f.begin(c.chapter, NodeScreens._kit(c), 4)
	if run == null:
		t.check(false, "开局")
		return
	f.pick_spawn(run.map.entry_ids[0])
	var sigil := Support.activate(run, &"strength_sigil")
	t.check(sigil != null and run.active_faith() != null and run.active_faith().id == &"brute", "放上力量的符号：激活蛮神")
	t.eq(run.active_faith_tier(), 0, "0 级")
	var altar := AltarModule.of(run)     # 101：神坛与信仰级效果是一局的模块
	t.not_null(altar, "默认清单里有神坛")
	t.check(altar.perks().is_empty(), "0 级没有效果")
	# 战斗的账喂进去
	var got := run.faith_power.credit(&"battle", {"won": true, "dealt": {"physical": 60.0}, "taken": {"physical": 60.0}})
	t.eq(got, 24, "一场 120 伤害 × 0.2 = 24 信力")
	t.eq(run.faith_power.credit(&"vitality_change", {"delta": -1}), 50, "掉 1 体力 +50")
	t.eq(run.active_faith_tier(), 1, "74 点：Lv.1")
	t.check(run.faith_power.line().begins_with("蛮神 Lv.1"), "HUD 一句：%s" % run.faith_power.line())
	t.check(altar.perk(&"low_hp_empower") != null, "1 级：低血增伤生效")
	var spec := run.compile_player()
	var has_rule := false
	for rule in spec.set_rules:
		for e in (rule as AbilityRule).effects:
			if e is LowHpEmpower:
				has_rule = true
	t.check(has_rule, "编译出来的玩家带着「造成伤害前 · 低血增伤」规则")
	# 2 级：神坛献祭生命上限
	run.faith_power.add_points(&"brute", 30)
	t.eq(run.active_faith_tier(), 2, "104 点：Lv.2")
	var actions: Array[FaithPerk] = []
	for p in altar.actions():
		if p is AltarSacrificeHpPerk:
			actions.append(p)
	t.check(actions.size() == 1, "神坛多一个特殊操作：献祭生命上限（祈求赐福 1 级就有）")
	t.check(not altar.is_open(), "没站在开着的神坛上：不能做")
	altar.node = run.travel.current_id     # 假装神坛在脚下开着
	t.check(altar.is_open(), "神坛开着")
	var hp0 := run.effective_baseline().value_of(BattleStats.MAX_HP, 0.0)
	var line := altar.special(actions[0], run.current_node())
	t.check(line.contains("献祭了 5 点生命上限"), "做了：%s" % line)
	t.eq(run.effective_baseline().value_of(BattleStats.MAX_HP, 0.0), hp0 - 5.0, "基线生命 −5")
	t.eq(run.effective_baseline().value_of(BattleStats.MAX_STAMINA, 0.0), 10.0 + (run.player_baseline.value_of(BattleStats.MAX_STAMINA, 0.0) if run.player_baseline != null else 0.0), "耐力上限 +10")
	var spec2 := run.compile_player()
	var hasted := false
	for it in spec2.items:
		if (it as CompiledItem).stats.has(BattleStats.HASTE) and (it as CompiledItem).stats.ensure(BattleStats.HASTE).mult_of(StatMath.Buff.HASTE) > 0:
			hasted = true
	t.check(hasted, "道具急速 +5%")
	t.check(not altar.is_open() and altar.used.has(altar.node), "特殊操作用掉了这一次机会：神坛关了")
	t.eq(altar.special(actions[0], run.current_node()), "", "再做不成")
	# 存档往返带着账
	var back := RunState.from_dict(run.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	var back_altar := AltarModule.of(back) if back != null else null
	t.check(back_altar != null and int(back_altar.rituals.get("sacrifice_hp", 0)) == 1 and float(back_altar.stat_bonus.get("max_hp", 0.0)) == -5.0 and back_altar.used.has(altar.node), "仪式的账、改过的基线、用过的点都跟存档（modules.altar）")
	# 3 级：秒杀
	run.faith_power.add_points(&"brute", 100)
	t.eq(run.active_faith_tier(), 3, "Lv.3")
	var smite := altar.perk(&"smite")
	t.check(smite != null and smite.prebattle_label(run, &"elite") != "" and smite.prebattle_label(run, &"battle") == "", "秒杀只对精英")
	# 献祭（GameFlow.offer：从棋盘上拿走、换信力）
	var sword: ItemInstance = null
	for inst in run.board.items():
		if (inst as ItemInstance).def.tags.has(&"weapon"):
			sword = inst
			break
	if sword != null:
		var p0 := run.faith_power.points_of(&"brute")
		var val := run.active_faith().offering_value(sword.def)
		altar.used.clear()
		altar.node = run.travel.current_id
		var res := f.offer([sword], run.current_node())
		t.eq(int(res["count"]), 1, "献祭了一件")
		t.eq(run.faith_power.points_of(&"brute"), p0 + val, "信力 +%d（2^稀有度 × 3）" % val)
		t.check(not run.board.has_item(sword.uid) and not run.storage.has_item(sword.uid), "祭品没了")
		t.check(altar.is_open(), "常规献祭不占那一次机会")
	# 日神：附魔 + 祈祷
	var defs := FaithDef.load_all()
	var sun: FaithDef = defs[&"sun"]
	var ench: EnchantWeaponsPerk = null
	for p in sun.perks_at(1):
		if p is EnchantWeaponsPerk:
			ench = p
	t.check(ench != null and ench.fire_bonus(run) == 0, "没祈祷：火焰加成 0")
	altar.rituals["pray_fire"] = 1
	t.eq(ench.fire_bonus(run), 10, "祈祷 1 次：+10%")
	altar.rituals["pray_fire"] = 4
	t.eq(ench.fire_bonus(run), roundi(10.0 * pow(4.0, 0.7)), "4 次：10 × 4^0.7 ≈ 26%（非线性）")
	altar.rituals.erase("pray_fire")
	var spec3 := run.compile_player()
	var weapons_before := 0
	for it in spec3.items:
		var inst := run.board.get_item((it as CompiledItem).source_uid)
		if inst != null and inst.def.tags.has(&"weapon") and (it as CompiledItem).is_active():
			weapons_before += 1
	ench.modify_spec(spec3, run.board, run)
	var enchanted := 0
	for it in spec3.items:
		for rule in (it as CompiledItem).rules:
			for e in (rule as AbilityRule).effects:
				if e is FireEnchant:
					enchanted += 1
	t.eq(enchanted, mini(3, weapons_before), "随机 3 把（不够就全部）武器各挂一条火焰附魔（%d 把武器）" % weapons_before)
	# 自然：回血 / 食物护盾 / 翻倍 / 平局算胜
	var nature: FaithDef = defs[&"nature"]
	var ration := ItemInstance.create(run.items.get_def(&"ration"))
	run.storage.admit(ration)
	InventoryService.transfer_auto(run.storage, ration.uid, run.board)
	var spec4 := run.compile_player()
	var regen0 := spec4.baseline.total_of(BattleStats.REGEN_HP)
	var shield0 := spec4.baseline.total_of(BattleStats.MAX_SHIELD)
	for p in nature.perks_at(3):
		(p as FaithPerk).modify_spec(spec4, run.board, run)
	t.check(spec4.baseline.total_of(BattleStats.REGEN_HP) > regen0, "1 级：基线每秒回血 +")
	if run.board.has_item(ration.uid):
		t.check(spec4.baseline.total_of(BattleStats.MAX_SHIELD) > shield0, "3 级：棋盘上有口粮就有护盾")
	var draw_perk: FaithPerk = null
	for p in nature.perks_at(5):
		if p is DrawIsWinPerk:
			draw_perk = p
	t.check(draw_perk != null, "5 级：平局算胜")
	var a := BattleCompiler.compile(null, CombatantBaseline.with_hp(10.0))
	var b := BattleCompiler.compile(null, CombatantBaseline.with_hp(10.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var plain := BattleSim.run(a, b, rng, 1.0)
	t.check(plain.is_draw(), "谁都不出手：平局")
	draw_perk.modify_spec(a, null, run)
	var blessed := BattleSim.run(a, b, rng, 1.0)
	t.eq(blessed.winner, 0, "自然 5 级：平局判我方赢")
	# 大地：耐力 / 锻炼 / 赐物 / 改造
	var earth: FaithDef = defs[&"earth"]
	var rows0 := run.board.size.y
	var count0 := run.board.item_count()
	var train: FaithPerk = null
	var gift: FaithPerk = null
	var reshape: FaithPerk = null
	for p in earth.perks_at(4):
		if p is AltarTrainBoardPerk:
			train = p
		elif p is GiftOnEnterPerk:
			gift = p
		elif p is AltarReshapeNodePerk:
			reshape = p
	t.check(train != null and gift != null and reshape != null, "2 / 3 / 4 级效果都在")
	t.check(train.altar_apply(run, run.current_node()) != "", "锻炼")
	t.check(run.board.size.y == rows0 + 1 and run.board.item_count() == count0, "棋盘多一行，东西原地不动")
	var battle_node: MapNode = null
	var rest_node: MapNode = null
	for id in run.map.node_ids():
		var n := run.map.get_node(id)
		if n.type == &"battle" and battle_node == null:
			battle_node = n
		if n.type == &"rest" and rest_node == null:
			rest_node = n
	if battle_node != null:
		var st0 := run.storage.item_count()
		var line2 := gift.on_node_entered(run, battle_node, true)
		t.check(line2.contains("赐下") and run.storage.item_count() == st0 + 1 and (run.storage.items()[-1] as ItemInstance).def.tags.has(&"weapon"), "头一回踩战斗点：暂存区多一件武器（%s）" % line2)
		t.eq(gift.on_node_entered(run, battle_node, false), "", "再踩不给")
	if rest_node != null:
		rest_node.state = MapNode.State.VISITED
		t.eq(reshape.altar_options(), [&"battle", &"elite", &"search", &"event", &"shop"] as Array[StringName], "改造可挑的类型（核心 / 撤离除外）")
		t.check(reshape.altar_apply(run, rest_node, &"shop") != "", "改成商店")
		t.check(NodeEvents.effective_type(rest_node) == &"shop" and not rest_node.is_visited(), "这个点从此算商店、当没踩过")
		t.check(String(rest_node.content.get("event", "")) != "rest_default", "旧的休息事件清掉了")
		t.eq(reshape.altar_apply(run, rest_node, &"core"), "", "不能改成核心")
	Support.cleanup("altar")


static func frame_altar_screen(t: TestCase, root: Window) -> void:
	t.begin("神坛 · 屏（093）：休息点只在激活信仰时有「神坛」选项；进去看得到信仰等级与信力；祭品台只收祭品、「献祭」亮起并预览；献祭进账；不激活信仰没有这一项")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var found: Dictionary = NodeScreens._seed_with(c, &"rest", kit.items)
	if found.is_empty():
		t.check(false, "找不到出生点旁有休息点的种子")
		return
	Support.cleanup("altar")
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = String(Support.paths("altar")["run"])
	game.meta_path = String(Support.paths("altar")["meta"])
	game.settings_path = String(Support.paths("altar")["settings"])
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	# 先不激活信仰：休息点没有「神坛」
	var run := flow.begin(c.chapter, kit, int(found["seed"]))
	flow.pick_spawn(int(found["entry"]))
	t.check(flow.step_to(int(found["next"])), "走上休息点")
	t.eq(flow.screen, GameFlow.Screen.EVENT, "休息点的事件")
	var def: EventDef = flow.last_payload.get("def", null)
	var labels: Array = NodeScreens._labels(def)
	var shown: Array[String] = []
	for i in def.options.size():
		var opt := def.options[i] as EventOption
		if opt.locked_reason(run.events._event_ctx(run.current_node())) == "" or not opt.hide_when_locked:
			shown.append(opt.label)
	t.check(not shown.has("神坛（献祭 / 特殊操作）") and labels.has("神坛（献祭 / 特殊操作）"), "没信仰：神坛选项藏起来（%s）" % str(shown))
	flow.choose_event(0)
	NodeScreens._settle(flow)
	flow.to_main_menu()
	# 激活蛮神再来
	run = flow.begin(c.chapter, kit, int(found["seed"]))
	flow.pick_spawn(int(found["entry"]))
	var sigil := Support.activate(run, &"strength_sigil")
	t.check(sigil != null and run.active_faith_id() == &"brute", "力量的符号上棋盘：蛮神")
	t.check(flow.step_to(int(found["next"])), "走上休息点")
	def = flow.last_payload.get("def", null)
	var at := -1
	for i in def.options.size():
		if (def.options[i] as EventOption).label.begins_with("神坛"):
			at = i
	t.check(at >= 0 and (def.options[at] as EventOption).locked_reason(run.events._event_ctx(run.current_node())) == "", "有信仰：神坛选项能选")
	var vit0 := run.vitality.current
	t.check(flow.choose_event(at), "选神坛")
	var g := 0
	while GameFlow.is_overlay(flow.screen) and flow.screen != GameFlow.Screen.ALTAR and g < 6:
		g += 1
		flow.resume()
	t.eq(flow.screen, GameFlow.Screen.ALTAR, "→ 神坛屏（休息也照休）")
	t.check(run.vitality.current >= vit0, "休息回了体力（或已满）")
	var screen = game.overlay()
	t.check(screen != null and screen.has_method("put_on_table"), "叠层是神坛屏")
	if screen == null:
		game.queue_free()
		Support.cleanup("altar")
		return
	t.check(screen.head_text().contains("蛮神") and screen.head_text().contains("Lv.0"), "抬头：信仰与等级（%s）" % screen.head_text())
	t.check(screen._offer_btn.disabled and screen.preview_text().contains("拖上台"), "台上没东西：献祭灰着")
	var sword: ItemInstance = null
	var bag: ItemInstance = null
	for inst in run.board.items():
		if (inst as ItemInstance).def.is_bag:
			bag = inst
		elif (inst as ItemInstance).def.tags.has(&"weapon") and sword == null:
			sword = inst
	t.check(sword != null, "棋盘上有武器")
	if bag != null:
		t.check(not screen.put_on_table(bag.uid), "包不是祭品")
	if sword != null:
		var val := run.active_faith().offering_value(sword.def)
		t.check(screen.put_on_table(sword.uid), "武器上台")
		t.check(not screen._offer_btn.disabled and screen.preview_text().contains("+%d" % val), "献祭亮了、预览 +%d（%s）" % [val, screen.preview_text()])
		var p0 := run.faith_power.points_of(&"brute")
		var got: Dictionary = screen.offer()
		t.eq(int(got["count"]), 1, "献了一件")
		t.eq(run.faith_power.points_of(&"brute"), p0 + val, "信力进账")
		t.check(not run.board.has_item(sword.uid) and screen._table.item_count() == 0, "祭品没了、台空了")
		t.check(AltarModule.of(run).is_open(), "常规献祭不关神坛")
	t.check(game.escape(), "Esc 返回")
	t.eq(flow.screen, GameFlow.Screen.MAP, "→ 地图")
	t.check(flow.can_reopen() and flow.reopen_node(), "站着还能再开神坛")
	t.eq(flow.screen, GameFlow.Screen.ALTAR, "→ 神坛屏")
	# 升到 2 级：特殊操作出现；做了就关
	run.faith_power.add_points(&"brute", 100)
	screen = game.overlay()
	t.check(screen != null and screen._action_btns.size() == 2, "Lv.2：特殊操作按钮随等级刷出来（祈求赐福 + 献祭生命上限，不用重开）")
	if screen != null and screen._action_btns.size() == 2:
		var hp_perk: FaithPerk = null
		for p in AltarModule.of(run).actions():
			if p is AltarSacrificeHpPerk:
				hp_perk = p
		var line: String = screen.special(hp_perk)
		t.check(line.contains("献祭了"), "做了特殊操作：%s" % line)
		t.check(flow.screen == GameFlow.Screen.MAP and not AltarModule.of(run).is_open(), "神坛关了、回地图")
		t.check(not flow.can_reopen(), "这个休息处不能再开神坛")
	game.queue_free()
	Support.cleanup("altar")
