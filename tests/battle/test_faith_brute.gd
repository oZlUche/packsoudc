## 388 第 1 批：蛮神【怒气】—— 按掉的血积、每一笔各自计时（396：不封顶、本身不加伤害）；蛮神的牌在战斗里的那一半
## （破甲、困兽、怒意延绵、痛觉残留、以血还血、恨意、血甲、余怒、嗜血、怒火中烧）；低血打赢记进战斗账
extends RefCounted

const Comp := preload("res://tests/battle/test_compiler.gd")
const FX := preload("res://tests/battle/test_effect_system.gd")
const Pipe := preload("res://tests/battle/test_damage_pipeline.gd")
const ID := BruteRage.BUFF_ID


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## 带怒气的我（[param tune] 改效果上的数，拿牌就是改这些）；[param rage] 假 = 不奉神
static func _me(tune: Dictionary = {}, hp: float = 1000.0, rage: bool = true) -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	b.place(ItemInstance.create(Comp._weapon("t_club", ["1"], 10.0, 2.0, ["weapon", "melee"])), Vector2i(0, 0), 0)
	var rules: Array[AbilityRule] = []
	if rage:
		var rule := BruteRagePerk.new().rule_for(null)
		var e := rule.effects[0] as BruteRage
		for k in tune:
			e.set(k, tune[k])
		rules.append(rule)
	return BattleCompiler.compile_board(b, CombatantBaseline.with_hp(hp), [] as Array[StatModifier], rules)


static func _hitter(dmg: float, cd: float = 1.0, applies: StringName = &"") -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	var w := Comp._weapon("t_foe", ["1"], dmg, cd, ["weapon", "melee"])
	if applies != &"":
		var a := ElementApply.new()
		a.buff = load(ContentPaths.asset_file("buffs", String(applies))) as BuffDef
		a.stacks = 1
		w.applies = [a] as Array[ElementApply]
	b.place(ItemInstance.create(w), Vector2i(0, 0), 0)
	return BattleCompiler.compile_board(b, CombatantBaseline.with_hp(50000.0))


static func _mech(res: BattleResult, key: String) -> Array:
	var out: Array = []
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.EFFECT_RESOLVED and String(e.payload.get("effect", "")) == SkillMomentum.MECHANIC and String(e.payload.get("key", "")) == key:
			out.append(e)
	return out


## [加上去的总层数, 最高几层]
static func _gained(res: BattleResult) -> Array:
	var n := 0
	var top := 0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.STATUS_STACKED and e.side == 0 and e.get_name(&"buff") == ID and e.get_int(&"delta") > 0:
			n += e.get_int(&"delta")
			top = maxi(top, e.get_int(&"stacks"))
	return [n, top]


## 怒气层数往下掉的时刻（秒）
static func _drops(res: BattleResult) -> Array[float]:
	var out: Array[float] = []
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.STATUS_UNSTACKED and e.side == 0 and e.get_name(&"buff") == ID:
			out.append(StatMath.to_float(e.time))
	return out


static func _lost(res: BattleResult) -> float:
	var n := 0.0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 0 and e.get_int(&"source_side", -1) == 1:
			n += StatMath.to_float(maxi(0, e.get_int(&"amount")))
	return n


static func _dealt(res: BattleResult) -> float:
	var n := 0.0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 1 and e.get_int(&"source_side", -1) == 0:
			n += StatMath.to_float(maxi(0, e.get_int(&"amount")))
	return n


static func run_core(t: TestCase) -> void:
	t.begin("388 · 怒气核心：每失去 1% 最大生命一层、不封顶（396）；每一笔各自 4 秒后散掉；怒气本身不加伤害（396）；不再用掉；木桩不打人就没有")
	var r := BattleSim.run(_me(), _hitter(30.0), _rng(1), 12.0)
	var g := _gained(r)
	t.check(int(g[0]) > 0, "挨打积了怒气（%d 层）" % int(g[0]))
	t.check(int(g[0]) <= floori(_lost(r) / 10.0), "积的层数不超过掉的血 / 1%%（%d ≤ %d）" % [int(g[0]), floori(_lost(r) / 10.0)])
	t.check(not _mech(r, "brute_strike").is_empty(), "积怒气写进战记（经验值按它给）")
	var big := BattleSim.run(_me(), _hitter(200.0), _rng(1), 12.0)
	t.check(int(_gained(big)[1]) > 30, "挨得重：不封顶（最多 %d 层）" % int(_gained(big)[1]))
	var calm := BattleSim.run(_me(), FX._spec(5000.0, []), _rng(1), 12.0)
	t.eq(int(_gained(calm)[0]), 0, "对手不打人：没有怒气")
	# 单独计时：对手 6 秒一下，第一下 6 秒挨，10 秒左右散
	var slow := BattleSim.run(_me(), _hitter(50.0, 6.0), _rng(2), 11.0)
	var drops := _drops(slow)
	t.check(not drops.is_empty() and drops[0] >= 10.0 and drops[0] <= 10.3, "挨了一下，4 秒后散（第一次往下掉在 %s 秒）" % str(drops.slice(0, 1)))
	# 两笔各走各的：3 秒一下，第二笔还在的时候第一笔先散
	var two := BattleSim.run(_me(), _hitter(50.0, 3.0), _rng(2), 8.0)
	var d2 := _drops(two)
	t.check(not d2.is_empty() and d2[0] >= 7.0 and d2[0] <= 7.3, "第一笔 3 秒挨、7 秒散（%s）" % str(d2.slice(0, 1)))
	var left := -1
	for raw in two.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.STATUS_UNSTACKED and e.side == 0 and e.get_name(&"buff") == ID:
			left = e.get_int(&"stacks")
			break
	t.check(left > 0, "第一笔散了，第二笔还在（剩 %d 层）" % left)
	# 怒气本身不加伤害；急躁 / 破甲给的每层加伤才加
	var plain := BattleSim.run(_me({}, 1000.0, false), _hitter(30.0), _rng(1), 12.0)
	t.check(is_equal_approx(_dealt(r), _dealt(plain)), "核心不加伤害：%.0f = %.0f" % [_dealt(r), _dealt(plain)])
	var hot := BattleSim.run(_me({"damage_per": 2.0}), _hitter(30.0), _rng(1), 12.0)
	t.check(_dealt(hot) > _dealt(plain), "每层 +2%% 伤害：%.0f > %.0f" % [_dealt(hot), _dealt(plain)])
	var again := BattleSim.run(_me(), _hitter(30.0), _rng(1), 12.0)
	t.eq(again.log.size(), r.log.size(), "同种子同结果")


static func run_cards(t: TestCase) -> void:
	t.begin("388 · 蛮神的牌（战斗）：上限（数据留着）、困兽、怒意延绵、痛觉残留、以血还血、恨意、血甲、余怒、嗜血、怒火中烧")
	var capped := BattleSim.run(_me({"cap": 40}), _hitter(200.0), _rng(1), 12.0)
	t.eq(int(_gained(capped)[1]), 40, "上限那一格还认（填 40 就封 40）")
	# 困兽（396）：每失去 1% 生命，伤害、急速各 +几成；层数 = 失去了百分之几
	var low0 := BattleSim.run(_me({}, 1000.0), _hitter(30.0), _rng(4), 12.0)
	var low1 := BattleSim.run(_me({"cornered_per": 1.0}, 1000.0), _hitter(30.0), _rng(4), 12.0)
	var top := 0
	var end_hp := -1
	for raw in low1.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.STATUS_STACKED and e.side == 0 and e.get_name(&"buff") == BruteRage.CORNERED_ID:
			top = maxi(top, e.get_int(&"stacks"))
		if e.name == BattleEvent.RESOURCE_CHANGED and e.side == 0 and String(e.payload.get("key", "")) == "hp":
			end_hp = e.get_int(&"current")
	var lost_pct := 100 - roundi(StatMath.to_float(end_hp) / 10.0)
	t.check(top > 0 and absi(top - lost_pct) <= 1, "困兽层数跟着失去的百分比（%d 层，失去 %d%%）" % [top, lost_pct])
	t.check(_dealt(low1) > _dealt(low0), "困兽：掉了血打得更痛（%.0f > %.0f）" % [_dealt(low1), _dealt(low0)])
	# 怒意延绵（396）：持续时间减半，每挨一下全部重新计时
	var keep := BattleSim.run(_me({"duration_sec": 2.0, "refresh_on_hit": true}), _hitter(20.0, 1.5), _rng(3), 10.0)
	t.check(_drops(keep).is_empty(), "1.5 秒挨一下、怒气 2 秒：一直重置，不散")
	var gone := BattleSim.run(_me({"duration_sec": 2.0}), _hitter(20.0, 1.5), _rng(3), 10.0)
	t.check(not _drops(gone).is_empty(), "不重置：照样到点散")
	var irate := BattleSim.run(_me({"gain_bonus": 20}), _hitter(30.0), _rng(1), 12.0)
	t.check(int(_gained(irate)[0]) > int(_gained(BattleSim.run(_me(), _hitter(30.0), _rng(1), 12.0))[0]), "易怒症：积得多")
	# 痛觉残留：挨的一下有一半挪走，之后按真实伤害慢慢扣，扣的那几下也积怒气
	var pain := BattleSim.run(_me({"defer_percent": 50, "defer_sec": 5}), _hitter(30.0, 6.0), _rng(5), 12.0)
	var deferred := 0
	var ticks := 0
	for raw in pain.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 0:
			deferred += e.get_int(&"deferred")
			if e.get_bool(&"pure"):
				ticks += 1
	t.check(deferred > 0, "挨的那一下挪走了一部分")
	t.check(ticks >= 5, "之后每秒扣一下（%d 下）" % ticks)
	var lost_all := 0.0
	for raw in pain.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 0:
			lost_all += StatMath.to_float(maxi(0, e.get_int(&"amount")))
	t.check(int(_gained(pain)[0]) >= floori(lost_all / 10.0) - 1, "慢慢扣的那份也积怒气（%d 层，掉了 %.0f）" % [int(_gained(pain)[0]), lost_all])
	# 396：灼伤这类持续伤害不再积怒气（拿了痛觉残留也不积）
	var dot := BattleSim.run(_me({"defer_percent": 50, "cap": 0}), _hitter(0.0, 1.0, &"poison"), _rng(5), 8.0)
	t.eq(int(_gained(dot)[0]), 0, "只挨中毒跳伤害：没有怒气")
	# 以血还血：每 5 层（测试放低）一把武器立即出手
	var blood := BattleSim.run(_me({"strike_every": 5}), _hitter(30.0), _rng(6), 10.0)
	var free := 0
	for raw in blood.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.ITEM_FIRED and e.side == 0 and e.get_bool(&"free"):
			free += 1
	t.check(free > 0 and free == _mech(blood, "brute_blood_for_blood").size(), "以血还血：武器立即出手 %d 次" % free)
	# 恨意：对手的武器挂中毒，每挂一次 +1 层（不计上限那一格还认）
	var hate := BattleSim.run(_me({"hate": 1, "cap": 1}), _hitter(1.0, 1.0, &"poison"), _rng(7), 6.0)
	t.check(int(_gained(hate)[1]) > 1, "恨意：不计上限，超过 1 层（%d）" % int(_gained(hate)[1]))
	# 血甲：挨打 3 秒后给护甲
	var armor := BattleSim.run(_me({"armor_window": 3.0, "armor_cd": 10.0, "armor_percent": 50}), _hitter(30.0), _rng(8), 8.0)
	t.check(_mech(armor, "brute_blood_armor").size() == 1, "血甲：8 秒里给了一次（冷却 10 秒）")
	var gave := false
	for raw in armor.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.RESOURCE_CHANGED and e.side == 0 and String(e.payload.get("key", "")) == "armor" and e.get_int(&"delta") > 0:
			gave = true
	t.check(gave, "护甲涨了")
	# 余怒：散掉再给一笔
	var linger := BattleSim.run(_me({"linger_percent": 50.0}), _hitter(50.0, 6.0), _rng(9), 11.0)
	t.check(int(_gained(linger)[0]) > int(_gained(BattleSim.run(_me(), _hitter(50.0, 6.0), _rng(9), 11.0))[0]), "余怒：散掉后又给了一笔")
	# 嗜血：打出去的回血
	var steal := BattleSim.run(_me({"lifesteal_percent": 50.0}), _hitter(30.0), _rng(1), 12.0)
	var heals := 0
	for raw in steal.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.RESOURCE_CHANGED and e.side == 0 and String(e.payload.get("key", "")) == "hp" and e.get_int(&"delta") > 0:
			heals += 1
	t.check(heals > 0, "嗜血：回了血（%d 次）" % heals)
	# 怒火中烧：每 10 层附 1 层灼伤
	var burn := BattleSim.run(_me({"scorch_every": 10, "scorch_stacks": 1}), _hitter(100.0), _rng(1), 8.0)
	var scorched := false
	for raw in burn.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.STATUS_STACKED and e.side == 1 and e.get_name(&"buff") == BruteRage.SCORCH:
			scorched = true
	t.check(scorched, "怒火中烧：对手挂上了灼伤")


static func run_sunder(t: TestCase) -> void:
	t.begin("388 · 破甲：对护甲多扣几成、扣完剩下的按原比例落血（对出手方有利）；升级版无视几成减伤")
	var ctx := FX._battle(Pipe._attacker(10.0), Pipe._defender({"max_armor": 10.0}))
	Pipe._start(ctx)
	var p := DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(10.0), ctx.sides[1], 0, 0, true)
	p.armor_bonus = 100
	DamageResolver.resolve(ctx, p)
	t.eq(Pipe._shield(ctx, 1), 0, "护甲按 20 扣：10 点全扣光")
	t.eq(Pipe._hp(ctx, 1), 95, "护甲折回原值是 5，剩下 5 落血")
	var ctx2 := FX._battle(Pipe._attacker(10.0), Pipe._defender({"max_armor": 10.0}))
	Pipe._start(ctx2)
	DamageResolver.resolve(ctx2, DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(10.0), ctx2.sides[1], 0, 0, true))
	t.eq(Pipe._hp(ctx2, 1), 100, "没有破甲：护甲全吃掉")
	var ctx3 := FX._battle(Pipe._attacker(10.0), Pipe._defender())
	Pipe._start(ctx3)
	ctx3.sides[1].shift_axis(StatAxes.DAMAGE_TAKEN, -10)     # 坚韧 10 层 = 减伤 50%
	var p3 := DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(20.0), ctx3.sides[1], 0, 0, true)
	p3.ignore_reduction = 50
	DamageResolver.resolve(ctx3, p3)
	t.eq(Pipe._hp(ctx3, 1), 85, "减伤 50% 无视一半：只减 25%，20 打成 15")


static func run_ledger(t: TestCase) -> void:
	t.begin("信仰重构 D · 蛮神的战斗账：低血打赢记一笔、没打赢不记；反击 2 + 低血 2（372：打赢那一份改成通用经验值）")
	var r := BattleResult.new()
	var hp := BattleEvent.make(BattleEvent.RESOURCE_CHANGED, 100, 0, {"key": "hp", "delta": -10, "reason": "damage", "current": StatMath.from_float(20.0), "max": StatMath.from_float(100.0)})
	var strike := BattleEvent.make(BattleEvent.EFFECT_RESOLVED, 50, 0, {"effect": SkillMomentum.MECHANIC, "key": "brute_strike", "count": 3})
	r.log = [strike, hp]
	var won := RunState.battle_summary(r, true, null)
	t.eq(int((won["mechanic"] as Dictionary).get("low_hp_won", 0)), 1, "打赢时 20% 生命：低血打赢")
	t.eq(int((RunState.battle_summary(r, false, null)["mechanic"] as Dictionary).get("low_hp_won", 0)), 0, "输了不算")
	var def := load("res://data/faiths/brute.tres") as FaithDef
	var sum := 0
	for d in def.deeds:
		sum += (d as FaithDeed).gain(&"battle", won)
	t.eq(sum, 4, "反击 2 + 低血打赢 2 = 每场上限 4")
	t.eq(def.thresholds, [42, 117, 217] as Array[int], "三阶 42 / 117 / 217")


static func run_switches(t: TestCase) -> void:
	t.begin("388 · 作者待定的三处做成开关（牌的 values 里写 1 打开）：破甲升级算不算格挡、恨意升级算不算减半、不灭按层平摊还是整段")
	# 破甲升级：无视减伤也算格挡
	for on in [false, true]:
		var ctx := FX._battle(Pipe._attacker(10.0), Pipe._defender({"block": 10.0}))
		Pipe._start(ctx)
		var p := DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(20.0), ctx.sides[1], 0, 0, true)
		p.ignore_reduction = 50
		p.ignore_block = on
		DamageResolver.resolve(ctx, p)
		t.eq(Pipe._hp(ctx, 1), 85 if on else 90, "格挡 10、无视 50%%：%s" % ("开：只挡 5" if on else "关（默认）：照挡 10"))
	# 恨意升级：寒冷减半也给一层
	var off := int(_gained(BattleSim.run(_me({"hate": 2, "cap": 1}, 1000.0), _hitter(1.0, 1.0, &"chill"), _rng(8), 8.0))[0])
	var on2 := int(_gained(BattleSim.run(_me({"hate": 2, "cap": 1, "hate_halving": true}, 1000.0), _hitter(1.0, 1.0, &"chill"), _rng(8), 8.0))[0])
	t.check(on2 > off, "开：我方出手让寒冷减半时多一层（%d > %d）" % [on2, off])
	# 不灭：整段
	var rule := BruteRagePerk.new().rule_for(null)
	var e := rule.effects[0] as BruteRage
	e.regen_step = 5
	e.regen_step_amount = 1.0
	t.eq(e.rage_def().mods.filter(func(m): return (m as StatModifier).stat == BattleStats.REGEN_HP).size(), 1, "整段也挂生命回复那一条")
