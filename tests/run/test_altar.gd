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
	t.begin("神坛 · 信仰级效果与那一次机会（093）：蛮神低血增伤 / 献祭生命上限 / 秒杀；日神附魔 + 祈祷非线性；自然回血 / 食物护甲 / 翻倍 / 加时回春；大地耐力 / 锻炼加行 / 踩点赐物 / 改造此点；献祭换信力、共享一次机会")
	var c = NodeScreens._content()
	var f := _flow(c)
	var run := f.begin(c.chapter, NodeScreens._kit(c), 4)
	if run == null:
		t.check(false, "开局")
		return
	f.pick_spawn(run.map.entry_ids[0])
	var sigil := Support.activate(run, &"charm_brute")
	t.check(sigil != null and run.active_faith() != null and run.active_faith().id == &"brute", "放上蛮神的护符：激活蛮神")
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
	t.eq(int(altar.rituals.get(AltarSacrificeHpPerk.KEY_BUFF, 0)), 1, "没挑（缺省）= 换「能力」（188 补充一）")
	var spec2 := run.compile_player()
	var hasted := false
	for it in spec2.items:
		if (it as CompiledItem).stats.has(BattleStats.HASTE) and (it as CompiledItem).stats.ensure(BattleStats.HASTE).percent > 0:
			hasted = true
	t.check(hasted, "道具急速 +5%")
	var dmg_mods := 0
	var hst_mods := 0
	var cin := CompileInput.new()
	(actions[0] as AltarSacrificeHpPerk).compile_into(cin, run.board, run)
	for m in cin.mods:
		if (m as StatModifier).stat == BattleStats.DAMAGE and (m as StatModifier).amount == 5.0:
			dmg_mods += 1
		if (m as StatModifier).stat == BattleStats.HASTE and (m as StatModifier).amount == 5.0:
			hst_mods += 1
	t.check(dmg_mods == 1 and hst_mods == 1, "「能力」：全体造成伤害 +5%、急速 +5%")
	t.check(not altar.is_open() and altar.used.has(altar.node), "特殊操作用掉了这一次机会：神坛关了")
	t.eq(altar.special(actions[0], run.current_node()), "", "再做不成")
	# 存档往返带着账
	var back := RunState.from_dict(run.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	var back_altar := AltarModule.of(back) if back != null else null
	t.check(back_altar != null and int(back_altar.rituals.get(AltarSacrificeHpPerk.KEY_BUFF, 0)) == 1 and float(back_altar.stat_bonus.get("max_hp", 0.0)) == -5.0 and back_altar.used.has(altar.node), "仪式的账、改过的基线、用过的点都跟存档（modules.altar）")
	# 188 补充一：也可以换信力
	altar.used.clear()
	altar.node = run.travel.current_id
	var pts0 := run.faith_power.points_of(&"brute")
	var fl := altar.special(actions[0], run.current_node(), AltarSacrificeHpPerk.FAITH)
	t.check(fl.contains("信力 +20"), "换信力：%s" % fl)
	t.eq(run.faith_power.points_of(&"brute"), pts0 + 20, "信力 +20")
	t.eq(run.effective_baseline().value_of(BattleStats.MAX_HP, 0.0), hp0 - 10.0, "两回都扣生命上限")
	t.eq(AltarSacrificeHpPerk.buff_times(run), 1, "换信力不叠「能力」")
	# 3 级：立即击败
	run.faith_power.add_points(&"brute", 100)
	t.eq(run.active_faith_tier(), 3, "Lv.3")
	var smite := altar.perk(&"smite")
	t.check(smite != null and smite.prebattle_actions(run, &"elite").size() == 2 and smite.prebattle_actions(run, &"battle").size() == 2 and smite.prebattle_actions(run, &"boss").is_empty(), "立即击败：普通与精英都能（耗体力 / 耗信力两个按钮），首领不能")
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
		t.check(not altar.is_open() and altar.used.has(altar.node), "反馈：献祭和特殊操作二选一 —— 献了就关")
	# 日神：附魔 + 祈祷
	var defs := FaithDef.load_all()
	var sun: FaithDef = defs[&"sun"]
	var ench: EnchantWeaponsPerk = null
	for p in sun.perks_at(1):
		if p is EnchantWeaponsPerk:
			ench = p
	t.check(ench != null, "日神 1 级有火焰附魔")
	# 105：祈祷攒的加成从「次数套公式填进 FireEnchant」变成标准轴 fire_damage 的层数（斐波那契）
	var pray: AltarPrayFirePerk = null
	for p in sun.perks_at(2):
		if p is AltarPrayFirePerk:
			pray = p
	t.not_null(pray, "日神 2 级有祈祷")
	t.eq(altar.axis_bonus.size(), 0, "没祈祷：一层都没有")
	var cumulative := 0
	for n in [1, 2, 3, 4, 5, 6]:
		cumulative += pray.gain_at(n)
	t.eq(cumulative, 20, "斐波那契：祈祷 6 次累计 20 层（1 / 2 / 4 / 7 / 12 / 20）")
	var weapons_before := 0
	for it in run.compile_player().items:
		var inst := run.board.get_item((it as CompiledItem).source_uid)
		if inst != null and inst.def.tags.has(&"weapon") and (it as CompiledItem).is_active():
			weapons_before += 1
	# 105：perk 不再自己改编译结果 —— 它往 CompileInput 放一条 ScopedMod，筛与挑都在编译器里
	var input := CompileInput.of(run.effective_baseline())
	ench.compile_into(input, run.board, run)
	var spec3 := BattleCompiler.compile(run.board, input)
	var enchanted := 0
	for it in spec3.items:
		for rule in (it as CompiledItem).rules:
			for e in (rule as AbilityRule).effects:
				if e is FireEnchant:
					enchanted += 1
	t.eq(enchanted, mini(3, weapons_before), "随机 3 把（不够就全部）武器各挂一条火焰附魔（%d 把武器）" % weapons_before)
	# 自然：回血 / 食物护甲 / 翻倍 / 加时回春
	var nature: FaithDef = defs[&"nature"]
	var ration := ItemInstance.create(run.items.get_def(&"ration"))
	run.storage.admit(ration)
	InventoryService.transfer_auto(run.storage, ration.uid, run.board)
	var plain4 := run.compile_player()
	var regen0 := plain4.baseline.total_of(BattleStats.REGEN_HP)
	var shield0 := plain4.baseline.total_of(BattleStats.MAX_ARMOR)
	var input4 := CompileInput.of(run.effective_baseline())
	for p in nature.perks_at(3):
		(p as FaithPerk).compile_into(input4, run.board, run)
	var spec4 := BattleCompiler.compile(run.board, input4)
	t.check(spec4.baseline.total_of(BattleStats.REGEN_HP) > regen0, "1 级：基线每秒回血 +")
	if run.board.has_item(ration.uid):
		t.check(spec4.baseline.total_of(BattleStats.MAX_ARMOR) > shield0, "3 级：棋盘上有口粮就有护甲")
	var regen_perk: OvertimeRegenPerk = null
	for p in nature.perks_at(5):
		if p is OvertimeRegenPerk:
			regen_perk = p
	t.check(regen_perk != null and regen_perk.stacks > 0, "5 级（103 改）：加时阶段回春，数值在 nature.json 里可调")
	# 两边都不出手、我方先掉一半血，打到第 40 秒：没有自然 5 级就停在一半，有就在加时开始后回满
	var hp_at_40 := func(blessed: bool) -> Array:
		var input_a := CompileInput.of(CombatantBaseline.with_hp(100.0))
		if blessed:
			regen_perk.compile_into(input_a, null, run)
		var a := BattleCompiler.compile(null, input_a)
		var b := BattleCompiler.compile_board(null, CombatantBaseline.with_hp(100.0))
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		var ctx := BattleContext.create(CombatantRuntime.from_spec(a, 0), CombatantRuntime.from_spec(b, 1), rng)
		ctx.overtime = OvertimeRules.new()
		ctx.sides[0].resources.change(BattleStats.RES_HP, -StatMath.from_float(50.0), BattleEvent.REASON_DAMAGE)
		var res := BattleSim.run_context(ctx, 40.0)
		return [ctx.sides[0].resources.current(BattleStats.RES_HP), res, ctx.sides[0].axis_stacks(StatAxes.REGEN_HP)]
	var plain: Array = hp_at_40.call(false)
	var blessed: Array = hp_at_40.call(true)
	t.eq(StatMath.to_int(plain[0]), 50, "没有自然 5 级：血停在一半")
	t.eq(StatMath.to_int(blessed[0]), 100, "自然 5 级：加时开始后回春，回满")
	t.eq(int(blessed[2]), regen_perk.stacks, "回血轴（内容层）+%d 层，一场只加一次（第 35 秒加时再叠也不重复）" % regen_perk.stacks)
	var first_regen := -1
	for e in (blessed[1] as BattleResult).log:
		if e.name == BattleEvent.AXIS_SHIFTED and e.side == 0 and e.get_name(&"axis") == StatAxes.REGEN_HP:
			first_regen = e.time
			break
	t.eq(first_regen, StatMath.from_float(30.0), "第 30 秒（加时开始）回春，记一条 axis_shifted（buff 栏画「回春」）")
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
		t.check(line2.contains("赐下") and run.storage.item_count() == st0 + 1 and (run.storage.items()[-1] as ItemInstance).def.tags.has(&"weapon"), "头一回踩战斗点：地上多一件武器（%s）" % line2)
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
	t.check(not shown.has("献祭或特殊操作，二选一") and labels.has("献祭或特殊操作，二选一"), "没信仰：神坛选项藏起来（%s）" % str(shown))
	flow.choose_event(0)
	NodeScreens._settle(flow)
	flow.to_main_menu()
	# 激活蛮神再来
	run = flow.begin(c.chapter, kit, int(found["seed"]))
	flow.pick_spawn(int(found["entry"]))
	var sigil := Support.activate(run, &"charm_brute")
	t.check(sigil != null and run.active_faith_id() == &"brute", "蛮神的护符上棋盘：蛮神")
	t.check(flow.step_to(int(found["next"])), "走上休息点")
	def = flow.last_payload.get("def", null)
	var at := -1
	for i in def.options.size():
		if (def.options[i] as EventOption).label.begins_with("献祭"):
			at = i
	t.check(at >= 0 and (def.options[at] as EventOption).locked_reason(run.events._event_ctx(run.current_node())) == "", "有信仰：神坛选项能选")
	var vit0 := run.vitality.current
	t.check(flow.choose_event(at), "选神坛")
	var g := 0
	while GameFlow.is_overlay(flow.screen) and flow.screen != GameFlow.Screen.ALTAR and g < 6:
		g += 1
		flow.resume()
	t.eq(flow.screen, GameFlow.Screen.ALTAR, "→ 神坛屏")
	t.eq(run.vitality.current, vit0, "反馈：神坛不占休息 —— 没顺带休息")
	t.check(not run.current_node().is_visited(), "休息那一份还留着：点没用完")
	var screen = game.overlay()
	t.check(screen != null and screen.has_method("put_on_table"), "叠层是神坛屏")
	if screen == null:
		game.queue_free()
		Support.cleanup("altar")
		return
	t.check(screen.head_text().contains("蛮神") and screen.head_text().contains("Lv.0"), "抬头：信仰与等级（%s）" % screen.head_text())
	t.check(screen._offer_btn.disabled and screen.preview_text().contains("拖上台"), "台上没东西：献祭灰着")
	var sword: ItemInstance = null
	var nope: ItemInstance = null
	for inst in run.board.items():
		if (inst as ItemInstance).def.tags.has(&"weapon") and sword == null:
			sword = inst
		elif not run.active_faith().accepts_offering((inst as ItemInstance).def) and nope == null:
			nope = inst
	t.check(sword != null, "棋盘上有武器")
	# 143：皮背包成了 3×3（9 格），对蛮神算「大块的东西」，能献 —— 这里换成一件蛮神不认的
	if nope != null:
		t.check(not screen.put_on_table(nope.uid), "「%s」不是蛮神认的祭品" % Names.of(nope.def))
	if sword != null:
		var val := run.active_faith().offering_value(sword.def)
		t.check(screen.put_on_table(sword.uid), "武器上台")
		t.check(not screen._offer_btn.disabled and screen.preview_text().contains("+%d" % val), "献祭亮了、预览 +%d（%s）" % [val, screen.preview_text()])
		var full: String = screen._offer_btn.text + ("\n" + String(screen._offer_btn.sub) if screen._offer_btn is ScrollKey else "")
		t.check(full.begins_with(UiText.t("altar.offer") + "\n") and full.contains("+%d" % val), "226 批三：预览写在「献祭」第二行（%s）" % full)
		var p0 := run.faith_power.points_of(&"brute")
		var got: Dictionary = screen.offer()
		t.eq(int(got["count"]), 1, "献了一件")
		t.eq(run.faith_power.points_of(&"brute"), p0 + val, "信力进账")
		t.check(not run.board.has_item(sword.uid) and screen._table.item_count() == 0, "祭品没了、台空了")
		t.check(not AltarModule.of(run).is_open() and screen._offer_btn.disabled, "反馈：献祭和特殊操作二选一 —— 献了神坛就关")
	t.check(game.escape(), "Esc 返回")
	# 196（待定 2 A）：神坛用了，休息那一份还在 —— 关掉神坛直接回营地（休息点的选项，没有神坛那一项了）
	t.eq(flow.screen, GameFlow.Screen.EVENT, "→ 回到营地（休息点的事件）")
	t.check(flow.can_reopen(), "站着还能再打开休息点")
	var here := run.current_node()
	var ectx := run.events._event_ctx(here)
	var open_labels: Array[String] = []
	for opt in (flow.last_payload.get("def", null) as EventDef).options:
		if (opt as EventOption).locked_reason(ectx) == "":
			open_labels.append((opt as EventOption).label)
	t.check(open_labels.any(func(l): return l.begins_with("回 ")) and not open_labels.any(func(l): return l.begins_with("献祭")), "能歇、神坛藏起来了（%s）" % str(open_labels))
	flow.choose_event(0)
	NodeScreens._settle(flow)
	t.check(here.is_visited(), "休息和神坛都用了：这个休息点才算用完")
	# 特殊操作那一半：换一个神坛机会（测试里直接重置）
	here.content.erase("used_altar")
	AltarModule.of(run).used.clear()
	AltarModule.of(run).node = here.id
	t.check(flow.can_reopen() and flow.reopen_node(), "重开神坛")
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
		t.check(int(flow._reopen_entry().get("screen", -1)) != GameFlow.Screen.ALTAR, "这个休息处不能再开神坛（还能重新打开的只有没铸过的铸炉，175 补充二）")
	game.queue_free()
	Support.cleanup("altar")
