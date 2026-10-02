## 信仰流派（093，作者表 + 拍板）：四位神的文件、体积档与献祭规矩、6 种按量累计的行为、战斗账汇总、信仰级效果的各个落点、神坛（献祭 / 特殊操作共享一次机会）
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const SAVE := "user://test_093_run.json"
const META := "user://test_093_meta.json"
const SETTINGS := "user://test_093_settings.json"
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")


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
	for id in [&"brute", &"sun", &"nature", &"earth", &"hunt", &"skill", &"church"]:
		t.check(defs.has(id), "有 %s" % id)
	t.check(not defs.has(&"war"), "战争之神删了（104）")
	t.check(not defs.has(&"violence") and not defs.has(&"sunfire"), "暴力之神 / 太阳与火之神合并进蛮神 / 日神")
	var brute: FaithDef = defs.get(&"brute", null)
	if brute == null:
		return
	t.eq(brute.thresholds, [30, 100, 200, 400] as Array[int], "蛮神阈值 30 / 100 / 200 / 400（表）")
	t.eq(brute.deeds.size(), 2, "两条增长方式")
	t.eq(brute.offerings.size(), 4, "四条献祭规矩")
	t.eq(brute.perks.size(), 5, "五条效果（含 4 级「不死 10 秒」与 1 级「祈求赐福」）")
	var db := ItemDatabase.new()
	db.load_dir()
	t.eq(db.get_def(&"strength_sigil").faith_tag(), &"faith:brute", "力量的符号归蛮神")
	# 体积
	t.eq(ItemVolume.grade(db.get_def(&"knife")), ItemVolume.Grade.TINY, "匕首 1 格：极小")
	t.eq(ItemVolume.grade(db.get_def(&"shortsword")), ItemVolume.Grade.SMALL, "短剑 2 格：小")
	t.eq(ItemVolume.grade(db.get_def(&"core")), ItemVolume.Grade.MEDIUM, "能量核心 5 格：中")
	t.eq(ItemVolume.grade(db.get_def(&"plate_cuirass")), ItemVolume.Grade.LARGE, "板甲 9 格：大")
	t.eq(ItemVolume.grade_of_cells(13), ItemVolume.Grade.HUGE, "13 格：极大")
	# 献祭规矩：一件满足几条算几次；2^稀有度 × 倍率（104：倍率照神明总表）
	var sword := db.get_def(&"shortsword")     # 稀有度 1、武器、金属、2 格
	t.eq(brute.offering_value(sword), 4, "蛮神：短剑只算「武器」一条 → 2 × 2 = 4")
	t.check(not brute.accepts_offering(db.get_def(&"ration")), "口粮不是蛮神的祭品")
	var sun: FaithDef = defs[&"sun"]
	t.eq(sun.offering_value(sword), 10, "日神：短剑算「金属」→ 2 × 5 = 10（体积是小不是中）")
	t.eq(sun.offering_value(db.get_def(&"core")), 40, "日神：能量核心稀有度 3、体积正好为中、不是金属 → 只算一条：2^3 × 5 = 40")
	var earth: FaithDef = defs[&"earth"]
	t.eq(earth.offering_value(db.get_def(&"plate_cuirass")), 2 * 5 * 9, "大地：板甲 2^1 × 5 × 9 格 = 90")
	t.eq(earth.offering_value(sword), 0, "大地不收小东西")
	var nature: FaithDef = defs[&"nature"]
	t.eq(nature.offering_value(db.get_def(&"ration")), 5 + 5, "自然：口粮既是自然又是食物 → 两条各 1 × 5")
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



static func run_undying(t: TestCase) -> void:
	t.begin("093 · 蛮神 4 级「不死 10 秒」：血归零不倒、进坚持期（回放里有 undying 一条）、期间耐力花了就补、伤害照记；到期血还是 0 才发 DIED；被治回来就活；一场只一次；没这条的照旧当场倒下")
	var a := BattleCompiler.compile(null, CombatantBaseline.with_hp(10.0))
	a.flags["undying_sec"] = 10.0
	var b := BattleCompiler.compile(null, CombatantBaseline.with_hp(10.0))
	var ra := CombatantRuntime.from_spec(a, 0)
	var rb := CombatantRuntime.from_spec(b, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var ctx := BattleContext.create(ra, rb, rng)
	t.eq(ra.undying_sec, StatMath.from_float(10.0), "从 flags 读进单位")
	ctx.now = StatMath.from_float(2.0)
	# 打到 0
	DamageResolver.resolve(ctx, DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(50.0), ra, 1, 0))
	t.eq(ra.resources.current(BattleStats.RES_HP), 0, "血归零")
	t.check(ra.is_alive() and ra.undying_active() and not ra.dead, "没倒：进坚持期")
	t.eq(ra.undying_until, StatMath.from_float(12.0), "到 12.0 秒为止")
	var died := 0
	var undying_notes := 0
	var dmg_after := 0
	for e in ctx.log:
		var ev := e as BattleEvent
		if ev.name == BattleEvent.DIED and ev.side == 0:
			died += 1
		if ev.name == BattleEvent.EFFECT_RESOLVED and ev.side == 0 and String(ev.payload.get("effect", "")) == "undying":
			undying_notes += 1
	t.eq(died, 0, "没发 DIED")
	t.eq(undying_notes, 1, "回放里有一条「不死」")
	# 期间再挨打：伤害照记、还是不倒
	var log_before := ctx.log.size()
	DamageResolver.resolve(ctx, DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(7.0), ra, 1, 0))
	for i in range(log_before, ctx.log.size()):
		var ev := ctx.log[i] as BattleEvent
		if ev.name == BattleEvent.DAMAGE and ev.side == 0 and int(ev.payload.get("amount", 0)) > 0:
			dmg_after += 1
	t.check(dmg_after == 1 and ra.is_alive(), "坚持期里挨打：伤害事件照发、还活着")
	# 耐力无限：花掉立刻补回
	if ra.resources.maximum(BattleStats.RES_STAMINA) > 0:
		var full := ra.resources.maximum(BattleStats.RES_STAMINA)
		ra.resources.change(BattleStats.RES_STAMINA, -mini(3, full), BattleEvent.REASON_COST)
		t.eq(ra.resources.current(BattleStats.RES_STAMINA), full, "耐力花了就补满")
	t.eq(ra.next_expiry(), ra.undying_until, "到期时刻算进「下一个要醒的时刻」")
	# 没到期不倒；到期血还是 0 就真倒
	t.check(not ra.settle_undying(StatMath.from_float(11.9)), "11.9 秒：还没到")
	t.check(ra.settle_undying(StatMath.from_float(12.0)) and ra.dead and not ra.is_alive(), "12.0 秒：真倒下")
	t.check(not ra.mark_dead(), "死了不再发第二次")
	# 被治回来的：到期活着
	var c2 := BattleCompiler.compile(null, CombatantBaseline.with_hp(10.0))
	c2.flags["undying_sec"] = 10.0
	var rc := CombatantRuntime.from_spec(c2, 0)
	var ctx2 := BattleContext.create(rc, CombatantRuntime.from_spec(b, 1), rng)
	DamageResolver.resolve(ctx2, DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(50.0), rc, 1, 0))
	t.check(rc.undying_active(), "进坚持期")
	rc.resources.change(BattleStats.RES_HP, StatMath.from_float(4.0), BattleEvent.REASON_HEAL)
	t.check(not rc.settle_undying(StatMath.from_float(10.0)) and rc.is_alive() and not rc.undying_active(), "到期时血 > 0：活着、坚持期结束")
	DamageResolver.resolve(ctx2, DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(50.0), rc, 1, 0))
	t.check(rc.dead and not rc.is_alive(), "再归零：一场只一次，当场倒下")
	# 没这条的照旧
	var plain := CombatantRuntime.from_spec(b, 0)
	var ctx3 := BattleContext.create(plain, CombatantRuntime.from_spec(b, 1), rng)
	DamageResolver.resolve(ctx3, DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(50.0), plain, 1, 0))
	t.check(plain.dead and not plain.is_alive(), "没有不死：当场倒下")
	# 整场：蛮神 4 级的效果从信仰文件来，编译出来的单位带旗子
	var defs := FaithDef.load_all()
	var brute: FaithDef = defs[&"brute"]
	var und: FaithPerk = null
	for p in brute.perks_at(4):
		if p is UndyingPerk:
			und = p
	t.check(und != null and brute.perks_at(3).find(und) < 0, "4 级才有「不死」")
	var spec := BattleCompiler.compile(null, CombatantBaseline.with_hp(10.0))
	und.modify_spec(spec, null, null)
	t.eq(float(spec.flags.get("undying_sec", 0.0)), 10.0, "编译后的单位带 undying_sec = 10")


static func run_faith_call(t: TestCase) -> void:
	t.begin("093 · 触发信仰：四枚护符（1 格、珍宝 + 信仰标签 + 流派标签；大地的是 1 格的包、局外也留）；事件链「祭坛 → 靠近 → 随机一位神 → 拿 / 不拿」；成组限量：每张图恰好一个、偏前期")
	var db := ItemDatabase.new()
	db.load_dir()
	var extra := {"brute": "bone", "sun": "fire", "nature": "nature", "earth": ""}
	for fid in ["brute", "sun", "nature", "earth"]:
		var d := db.get_def(StringName("charm_" + fid))
		t.check(d != null, "有 charm_%s" % fid)
		if d == null:
			continue
		t.check(ItemVolume.cells_of(d) == 1 and d.tags.has(&"treasure") and d.faith_tag() == StringName("faith:" + fid), "%s：1 格、珍宝、归 %s" % [d.display_name, fid])
		if String(extra[fid]) != "":
			t.check(d.tags.has(StringName(extra[fid])), "带流派标签 %s" % extra[fid])
		t.check(d.combat == null and d.faith_bonuses.is_empty(), "没有别的效果")
		t.eq(d.is_bag, fid == "earth", "只有大地的是包")
	t.check(MetaState.keeps(db.get_def(&"charm_earth")) and not MetaState.keeps(db.get_def(&"bag_small")), "大地的护符虽是包也留在局外；普通包不留")
	# 事件链
	var events := GameFlow.load_events()
	var root: EventDef = events.get(&"faith_call", null)
	t.check(root != null and root.options.size() == 2, "「触发信仰」：靠近 / 离开")
	if root != null:
		var near := root.options[0] as EventOption
		var rnd: NextEventRandom = null
		for o in near.outcomes:
			if o is NextEventRandom:
				rnd = o
		t.check(rnd != null and rnd.events.size() == 4, "靠近 → 从四位神里随机接一个")
		var ctx := EventContext.new()
		ctx.rng = RandomNumberGenerator.new()
		ctx.rng.seed = 11
		rnd.apply(ctx)
		var first := ctx.next_event
		ctx.rng.seed = 11
		ctx.next_event = &""
		rnd.apply(ctx)
		t.check(String(first).begins_with("faith_call_") and ctx.next_event == first, "同一个随机数同一位神（%s）" % first)
	for fid in ["brute", "sun", "nature", "earth"]:
		var ev: EventDef = events.get(StringName("faith_call_" + fid), null)
		t.check(ev != null and ev.options.size() == 2, "有 faith_call_%s：拿 / 不拿" % fid)
		if ev != null:
			var gives := false
			for o in (ev.options[0] as EventOption).outcomes:
				if o is GiveItem and (o as GiveItem).item == StringName("charm_" + fid):
					gives = true
			t.check(gives and (ev.options[1] as EventOption).outcomes.is_empty(), "第一项给护符，第二项空手走")
	# 成组限量的放置
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var depth_sum := 0.0
	var maps := 0
	for seed in range(1, 9):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit.items)
		if s == null:
			continue
		var event_nodes := 0
		var calls: Array[int] = []
		for id in s.map.node_ids():
			var n := s.map.get_node(id)
			if n.type == &"event":
				event_nodes += 1
			if String(n.content.get("event", "")) == "faith_call":
				calls.append(id)
		if event_nodes == 0:
			continue
		maps += 1
		t.eq(calls.size(), 1, "种子 %d：恰好一个「触发信仰」" % seed)
		if calls.size() == 1:
			var n := s.map.get_node(calls[0])
			t.check(n.type == &"event" and String(n.content.get("event_group", "")) == "faith_call", "落在事件点上、记着组名")
			depth_sum += float(EnemyPlacer.depths_of(s.map).get(calls[0], 0.0))
	if maps > 0:
		t.check(depth_sum / float(maps) < 0.5, "偏前期：平均深度 %.2f < 0.5" % (depth_sum / float(maps)))
	# 走一遍：靠近 → 某位神 → 拿 → 护符进暂存区 → 放上棋盘激活那位神
	var f := _flow(c)
	var run := f.begin(c.chapter, kit, 2)
	if run == null:
		t.check(false, "开局")
		return
	f.pick_spawn(run.map.entry_ids[0])
	var call_node: MapNode = null
	for id in run.map.node_ids():
		if String(run.map.get_node(id).content.get("event", "")) == "faith_call":
			call_node = run.map.get_node(id)
	if call_node == null:
		t.check(true, "（这张图没有事件点，跳过走一遍）")
		_cleanup()
		return
	run.events.handle(call_node)
	t.check(run.events.pending_event() != null and run.events.pending_event().id == &"faith_call", "踩上：「触发信仰」")
	t.check(f.choose_event(0), "靠近")
	var god_ev := run.events.pending_event()
	t.check(god_ev != null and String(god_ev.id).begins_with("faith_call_"), "→ 某位神的事件（%s）" % (god_ev.id if god_ev != null else "?"))
	if god_ev != null:
		var fid := String(god_ev.id).trim_prefix("faith_call_")
		var before := run.storage.item_count()
		t.check(f.choose_event(0), "拿护符")
		var charm: ItemInstance = null
		for inst in run.storage.items():
			if String((inst as ItemInstance).def.id) == "charm_" + fid:
				charm = inst
		t.check(run.storage.item_count() == before + 1 and charm != null, "护符进了暂存区")
		if charm != null:
			t.check(InventoryService.transfer_auto(run.storage, charm.uid, run.board), "放上棋盘")
			t.eq(String(run.active_faith_id()), fid, "激活了那位神")
			if fid == "earth":
				t.check(run.board.acts_as_bag(charm.def), "大地的护符在棋盘上是个包")
	NodeScreens._settle(f)
	_cleanup()
