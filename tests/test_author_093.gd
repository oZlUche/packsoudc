## 信仰流派（093，作者表 + 拍板）：四位神的文件、体积档与献祭规矩、6 种按量累计的行为、战斗账汇总、信仰级效果的各个落点、神坛（献祭 / 特殊操作共享一次机会）
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const SAVE := "user://test_093_run.json"
const META := "user://test_093_meta.json"
const SETTINGS := "user://test_093_settings.json"
const NodeScreens := preload("res://tests/test_node_screens.gd")


static func _cleanup() -> void:
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


static func _flow(c) -> GameFlow:
	var f: GameFlow = NodeScreens._flow(c, 10000.0)
	f.save_path = SAVE
	f.meta_path = META
	f.settings_path = SETTINGS
	f.faith_defs = FaithDef.load_all()
	return f


## 把一件信仰道具放上棋盘（激活那个信仰）
static func _activate(run: RunState, item_id: StringName) -> ItemInstance:
	var def := run.items.get_def(item_id)
	if def == null:
		return null
	var inst := ItemInstance.create(def)
	if run.board.try_add(inst, true):
		return inst
	run.storage.admit(inst)
	return null


static func _event(name: StringName, side: int, payload: Dictionary) -> BattleEvent:
	var e := BattleEvent.new()
	e.name = name
	e.side = side
	e.payload = payload
	return e


static func run_faith_files(t: TestCase) -> void:
	t.begin("093 · 信仰文件：蛮神 / 日神 / 自然 / 大地各一份（旧的暴力 / 太阳与火合并改名），阈值、行为、献祭规矩、各级效果都从数据来；体积五档；力量的符号归蛮神")
	var defs := FaithDef.load_all()
	for id in [&"brute", &"sun", &"nature", &"earth", &"hunt", &"skill", &"war", &"church"]:
		t.check(defs.has(id), "有 %s" % id)
	t.check(not defs.has(&"violence") and not defs.has(&"sunfire"), "暴力之神 / 太阳与火之神合并进蛮神 / 日神")
	var brute: FaithDef = defs.get(&"brute", null)
	if brute == null:
		return
	t.eq(brute.thresholds, [30, 100, 200, 400] as Array[int], "蛮神阈值 30 / 100 / 200 / 400（表）")
	t.eq(brute.deeds.size(), 2, "两条增长方式")
	t.eq(brute.offerings.size(), 4, "四条献祭规矩")
	t.eq(brute.perks.size(), 3, "三条效果（4 级「不死 10 秒」还没做）")
	var db := ItemDatabase.new()
	db.load_dir()
	t.eq(db.get_def(&"strength_sigil").faith_tag(), &"faith:brute", "力量的符号归蛮神")
	# 体积
	t.eq(ItemVolume.grade(db.get_def(&"knife")), ItemVolume.Grade.TINY, "匕首 1 格：极小")
	t.eq(ItemVolume.grade(db.get_def(&"shortsword")), ItemVolume.Grade.SMALL, "短剑 2 格：小")
	t.eq(ItemVolume.grade(db.get_def(&"core")), ItemVolume.Grade.MEDIUM, "能量核心 5 格：中")
	t.eq(ItemVolume.grade(db.get_def(&"plate_cuirass")), ItemVolume.Grade.LARGE, "板甲 9 格：大")
	t.eq(ItemVolume.grade_of_cells(13), ItemVolume.Grade.HUGE, "13 格：极大")
	# 献祭规矩：一件满足几条算几次；2^稀有度 × 倍率
	var sword := db.get_def(&"shortsword")     # 稀有度 1、武器、金属、2 格
	t.eq(brute.offering_value(sword), 6, "蛮神：短剑只算「武器」一条 → 2 × 3 = 6")
	t.check(not brute.accepts_offering(db.get_def(&"ration")), "口粮不是蛮神的祭品")
	var sun: FaithDef = defs[&"sun"]
	t.eq(sun.offering_value(sword), 4, "日神：短剑算「金属」→ 2 × 2 = 4（体积是小不是中）")
	t.eq(sun.offering_value(db.get_def(&"core")), 16, "日神：能量核心稀有度 3、体积正好为中、不是金属 → 只算一条：2^3 × 2 = 16")
	var earth: FaithDef = defs[&"earth"]
	t.eq(earth.offering_value(db.get_def(&"plate_cuirass")), 2 * 9, "大地：板甲稀有度 1 × 9 格 = 18")
	t.eq(earth.offering_value(sword), 0, "大地不收小东西")
	var nature: FaithDef = defs[&"nature"]
	t.eq(nature.offering_value(db.get_def(&"ration")), 2 + 2, "自然：口粮既是自然又是食物 → 两条各 1 × 2")
	t.check(sun.accepts_offering(db.get_def(&"mana_crystal")), "日神收宝石")


static func run_deeds_and_summary(t: TestCase) -> void:
	t.begin("093 · 六种按量累计的行为 + 一场战斗的账汇总（造成 / 受到按类型、回血、每件出手几次）")
	var d := DamageDeed.new()
	d.multiplier = 0.2
	d.cap = 30
	t.eq(d.gain(&"battle", {"dealt": {"physical": 100.0}, "taken": {"fire": 20.0}}), 24, "(100 + 20) × 0.2 = 24")
	t.eq(d.gain(&"battle", {"dealt": {"physical": 1000.0}, "taken": {}}), 30, "一场上限 30")
	t.eq(d.gain(&"travel", {}), 0, "别的事不认")
	var fire := DamageDeed.new()
	fire.damage_type = &"fire"
	fire.count_taken = false
	t.eq(fire.gain(&"battle", {"dealt": {"physical": 100.0, "fire": 15.0}, "taken": {"fire": 50.0}}), 15, "只认造成的火焰伤害")
	var v := VitalityLostDeed.new()
	t.eq(v.gain(&"vitality_change", {"delta": -1}), 50, "掉 1 体力 +50")
	t.eq(v.gain(&"vitality_change", {"delta": 2}), 0, "回体力不算")
	var cyc := ItemCycleDeed.new()
	cyc.amount = 2
	cyc.cap = 30
	t.eq(cyc.gain(&"battle", {"fired_total": 7}), 14, "7 次成功出手 × 2")
	t.eq(cyc.gain(&"battle", {"fired_total": 70}), 30, "上限")
	var h := HealDeed.new()
	t.eq(h.gain(&"battle", {"healed": 37.4}), 37, "回血 37.4 → 37")
	var it := ItemTriggeredDeed.new()
	it.tag = &"nature"
	it.amount = 3
	t.eq(it.gain(&"battle", {"fired_items": [{"tags": ["weapon", "nature"], "cells": 4, "count": 5}, {"tags": ["weapon"], "cells": 2, "count": 9}]}), 15, "只算带 nature 的那件：5 × 3")
	var mid := ItemTriggeredDeed.new()
	mid.min_cells = 5
	mid.amount = 8
	t.eq(mid.gain(&"battle", {"fired_items": [{"tags": [], "cells": 4, "count": 5}, {"tags": [], "cells": 6, "count": 2}]}), 16, "只算 5 格以上的：2 × 8")
	var en := EnterNodeDeed.new()
	t.eq(en.gain(&"travel", {"first_visit": true, "node_type": "junction"}), 20, "头一回踩岔路 +20")
	t.eq(en.gain(&"travel", {"first_visit": true, "node_type": "battle"}), 0, "头一回踩战斗点不算")
	t.eq(en.gain(&"travel", {"first_visit": false, "node_type": "battle"}), 1, "再踩用过的点 +1")
	# 账汇总
	var r := BattleResult.new()
	r.log = [
		_event(BattleEvent.DAMAGE, 1, {"type": "physical", "amount": StatMath.from_float(12.0)}),
		_event(BattleEvent.DAMAGE, 1, {"type": "fire", "amount": StatMath.from_float(3.0)}),
		_event(BattleEvent.DAMAGE, 0, {"type": "physical", "amount": StatMath.from_float(7.5)}),
		_event(BattleEvent.RESOURCE_CHANGED, 0, {"key": "hp", "delta": StatMath.from_float(4.0), "reason": "heal"}),
		_event(BattleEvent.RESOURCE_CHANGED, 0, {"key": "hp", "delta": StatMath.from_float(-4.0), "reason": "damage"}),
		_event(BattleEvent.RESOURCE_CHANGED, 1, {"key": "hp", "delta": StatMath.from_float(9.0), "reason": "heal"}),
		_event(BattleEvent.ITEM_FIRED, 0, {"uid": 5}),
		_event(BattleEvent.ITEM_FIRED, 0, {"uid": 5}),
		_event(BattleEvent.ITEM_FIRED, 1, {"uid": 77}),
	]
	var board := GridInventory.new(Vector2i(4, 4), 1, false)
	var db := ItemDatabase.new()
	db.load_dir()
	var bow := ItemInstance.create(db.get_def(&"longbow"))
	bow.uid = 5
	board.place(bow, Vector2i.ZERO)
	var s := RunState.battle_summary(r, true, board)
	t.check(bool(s["won"]), "赢了")
	t.eq(float((s["dealt"] as Dictionary).get("physical", 0.0)), 12.0, "造成：物理 12")
	t.eq(float((s["dealt"] as Dictionary).get("fire", 0.0)), 3.0, "造成：火焰 3")
	t.eq(float((s["taken"] as Dictionary).get("physical", 0.0)), 7.5, "受到：物理 7.5")
	t.eq(float(s["healed"]), 4.0, "我方回血 4（敌方的、扣血的不算）")
	t.eq(int(s["fired_total"]), 2, "我方出手 2 次（敌方的不算）")
	var fi: Array = s["fired_items"]
	t.check(fi.size() == 1 and int(fi[0]["count"]) == 2 and (fi[0]["tags"] as Array).has("nature") and int(fi[0]["cells"]) == 4, "出手的那件：长弓，带 nature，4 格，2 次")


static func run_perks_and_altar_logic(t: TestCase) -> void:
	t.begin("093 · 信仰级效果与神坛（逻辑）：蛮神低血增伤 / 献祭生命上限 / 秒杀；日神附魔 + 祈祷非线性；自然回血 / 食物护盾 / 翻倍 / 平局算胜；大地耐力 / 锻炼加行 / 踩点赐物 / 改造此点；献祭换信力、共享一次机会")
	var c = NodeScreens._content()
	var f := _flow(c)
	var run := f.begin(c.chapter, NodeScreens._kit(c), 4)
	if run == null:
		t.check(false, "开局")
		return
	f.pick_spawn(run.map.entry_ids[0])
	var sigil := _activate(run, &"strength_sigil")
	t.check(sigil != null and run.active_faith() != null and run.active_faith().id == &"brute", "放上力量的符号：激活蛮神")
	t.eq(run.active_faith_tier(), 0, "0 级")
	t.check(run.faith_perks().is_empty(), "0 级没有效果")
	# 战斗的账喂进去
	var got := run.faith_power.credit(&"battle", {"won": true, "dealt": {"physical": 60.0}, "taken": {"physical": 60.0}})
	t.eq(got, 24, "一场 120 伤害 × 0.2 = 24 信力")
	t.eq(run.faith_power.credit(&"vitality_change", {"delta": -1}), 50, "掉 1 体力 +50")
	t.eq(run.active_faith_tier(), 1, "74 点：Lv.1")
	t.check(run.faith_power.line().begins_with("蛮神 Lv.1"), "HUD 一句：%s" % run.faith_power.line())
	t.check(run.faith_perk(&"low_hp_empower") != null, "1 级：低血增伤生效")
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
	var actions := run.altar_actions()
	t.check(actions.size() == 1 and actions[0] is AltarSacrificeHpPerk, "神坛多一个特殊操作：献祭生命上限")
	t.check(not run.altar_open(), "没站在开着的神坛上：不能做")
	run.altar_node = run.travel.current_id     # 假装神坛在脚下开着
	t.check(run.altar_open(), "神坛开着")
	var hp0 := run.effective_baseline().value_of(BattleStats.MAX_HP, 0.0)
	var line := run.altar_special(actions[0], run.current_node())
	t.check(line.contains("献祭了 5 点生命上限"), "做了：%s" % line)
	t.eq(run.effective_baseline().value_of(BattleStats.MAX_HP, 0.0), hp0 - 5.0, "基线生命 −5")
	t.eq(run.effective_baseline().value_of(BattleStats.MAX_STAMINA, 0.0), 10.0 + (run.player_baseline.value_of(BattleStats.MAX_STAMINA, 0.0) if run.player_baseline != null else 0.0), "耐力上限 +10")
	var spec2 := run.compile_player()
	var hasted := false
	for it in spec2.items:
		if (it as CompiledItem).stats.has(BattleStats.HASTE) and (it as CompiledItem).stats.ensure(BattleStats.HASTE).mult_of(StatMath.Buff.HASTE) > 0:
			hasted = true
	t.check(hasted, "道具急速 +5%")
	t.check(not run.altar_open() and run.altar_used.has(run.altar_node), "特殊操作用掉了这一次机会：神坛关了")
	t.eq(run.altar_special(actions[0], run.current_node()), "", "再做不成")
	# 存档往返带着账
	var back := RunState.from_dict(run.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	t.check(back != null and int(back.faith_rituals.get("sacrifice_hp", 0)) == 1 and float(back.faith_stat_bonus.get("max_hp", 0.0)) == -5.0 and back.altar_used.has(run.altar_node), "faith_rituals / faith_stat_bonus / altar_used 跟存档")
	# 3 级：秒杀
	run.faith_power.add_points(&"brute", 100)
	t.eq(run.active_faith_tier(), 3, "Lv.3")
	var smite := run.faith_perk(&"smite")
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
		run.altar_used.clear()
		run.altar_node = run.travel.current_id
		var res := f.offer([sword], run.current_node())
		t.eq(int(res["count"]), 1, "献祭了一件")
		t.eq(run.faith_power.points_of(&"brute"), p0 + val, "信力 +%d（2^稀有度 × 3）" % val)
		t.check(not run.board.has_item(sword.uid) and not run.storage.has_item(sword.uid), "祭品没了")
		t.check(run.altar_open(), "常规献祭不占那一次机会")
	# 日神：附魔 + 祈祷
	var defs := FaithDef.load_all()
	var sun: FaithDef = defs[&"sun"]
	var ench: EnchantWeaponsPerk = null
	for p in sun.perks_at(1):
		if p is EnchantWeaponsPerk:
			ench = p
	t.check(ench != null and ench.fire_bonus(run) == 0, "没祈祷：火焰加成 0")
	run.faith_rituals["pray_fire"] = 1
	t.eq(ench.fire_bonus(run), 10, "祈祷 1 次：+10%")
	run.faith_rituals["pray_fire"] = 4
	t.eq(ench.fire_bonus(run), roundi(10.0 * pow(4.0, 0.7)), "4 次：10 × 4^0.7 ≈ 26%（非线性）")
	run.faith_rituals.erase("pray_fire")
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
	_cleanup()


static func frame_altar_screen(t: TestCase, root: Window) -> void:
	t.begin("093 · 神坛屏：休息点只在激活信仰时有「神坛」选项；进去看得到信仰等级与信力；祭品台只收祭品、「献祭」亮起并预览；献祭进账；不激活信仰没有这一项")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var found: Dictionary = NodeScreens._seed_with(c, &"rest", kit.items)
	if found.is_empty():
		t.check(false, "找不到出生点旁有休息点的种子")
		return
	_cleanup()
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	game.settings_path = SETTINGS
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
	var sigil := _activate(run, &"strength_sigil")
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
		_cleanup()
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
		t.check(run.altar_open(), "常规献祭不关神坛")
	t.check(game.escape(), "Esc 返回")
	t.eq(flow.screen, GameFlow.Screen.MAP, "→ 地图")
	t.check(flow.can_reopen() and flow.reopen_node(), "站着还能再开神坛")
	t.eq(flow.screen, GameFlow.Screen.ALTAR, "→ 神坛屏")
	# 升到 2 级：特殊操作出现；做了就关
	run.faith_power.add_points(&"brute", 100)
	screen = game.overlay()
	t.check(screen != null and screen._action_btns.size() == 1, "Lv.2：特殊操作按钮随等级刷出来（不用重开）")
	if screen != null and screen._action_btns.size() == 1:
		var line: String = screen.special(run.altar_actions()[0])
		t.check(line.contains("献祭了"), "做了特殊操作：%s" % line)
		t.check(flow.screen == GameFlow.Screen.MAP and not run.altar_open(), "神坛关了、回地图")
		t.check(not flow.can_reopen(), "这个休息处不能再开神坛")
	game.queue_free()
	_cleanup()
