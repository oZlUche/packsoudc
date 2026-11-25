## 388 第 2 批：日神【日月】—— 开战白昼，白昼、黑夜各 6 秒轮着来；白昼造成伤害 +15%，黑夜急速 +15%；
## 日神的牌在战斗里的那一半（日蚀 / 月蚀 / 残阳 / 斜月、日光浴 / 月光浴、大日炎炎 / 微月澹澹、日出、黎明、黄昏、日落当息、夜幕、谦卑、永日、永夜、星移斗转）
extends RefCounted

const Comp := preload("res://tests/battle/test_compiler.gd")
const FX := preload("res://tests/battle/test_effect_system.gd")


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


static func _s(sec: float) -> int:
	return StatMath.from_float(sec)


## 带日月的我（[param tune] 改效果上的数，拿牌就是改这些）
static func _me(tune: Dictionary = {}, cd: float = 1.0, hp: float = 1000.0) -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	b.place(ItemInstance.create(Comp._weapon("t_blade", ["1"], 10.0, cd, ["weapon", "melee"])), Vector2i(0, 0), 0)
	var rule := SunCyclePerk.new().rule_for(null)
	var e := rule.effects[0] as SunCycle
	for k in tune:
		e.set(k, tune[k])
	var rules: Array[AbilityRule] = [rule]
	return BattleCompiler.compile_board(b, CombatantBaseline.with_hp(hp), [] as Array[StatModifier], rules)


static func _hitter(dmg: float, cd: float = 1.0) -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	b.place(ItemInstance.create(Comp._weapon("t_foe", ["1"], dmg, cd, ["weapon", "melee"])), Vector2i(0, 0), 0)
	return BattleCompiler.compile_board(b, CombatantBaseline.with_hp(50000.0))


static func _mech(res: BattleResult, key: String) -> Array:
	var out: Array = []
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.EFFECT_RESOLVED and String(e.payload.get("effect", "")) == SkillMomentum.MECHANIC and String(e.payload.get("key", "")) == key:
			out.append(e)
	return out


## [param side] 身上 [param id] 加层 / 掉层的时刻（秒）
static func _status_times(res: BattleResult, id: StringName, up: bool, side: int = 0) -> Array[float]:
	var out: Array[float] = []
	var ev := BattleEvent.STATUS_STACKED if up else BattleEvent.STATUS_UNSTACKED
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == ev and e.side == side and e.get_name(&"buff") == id and (e.get_int(&"delta") > 0) == up:
			out.append(StatMath.to_float(e.time))
	return out


## 我方打出去的直接伤害：[时刻（秒）, 量]
static func _hits(res: BattleResult) -> Array:
	var out: Array = []
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 1 and e.get_int(&"source_side", -1) == 0 and e.get_int(&"uid") != 0:
			out.append([StatMath.to_float(e.time), e.get_int(&"amount")])
	return out


static func _taken(res: BattleResult) -> int:
	var n := 0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 0 and e.get_int(&"source_side", -1) == 1:
			n += maxi(0, e.get_int(&"amount"))
	return n


static func _fired(res: BattleResult) -> Array[float]:
	var out: Array[float] = []
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.ITEM_FIRED and e.side == 0:
			out.append(StatMath.to_float(e.time))
	return out


static func run_timeline(t: TestCase) -> void:
	t.begin("388 · 日月的时间轴：开战白昼，6 秒换边（半开区间）；一边是 0 就一直是另一边；日蚀 / 月蚀、残阳 / 斜月「同时视为」")
	var e := SunCycle.new()
	t.check(bool(e.phase_at(0)["day"]), "开战是白昼")
	t.check(bool(e.phase_at(_s(5.99))["day"]), "5.99 秒还是白昼")
	t.check(not bool(e.phase_at(_s(6.0))["day"]), "第 6 秒整：黑夜")
	t.check(bool(e.phase_at(_s(12.0))["day"]), "第 12 秒整：又是白昼")
	t.eq(int(e.phase_at(_s(13.0))["index"]), 2, "第三个阶段")
	t.eq(e.states_at(_s(1.0)), Vector2i(1, 0), "白昼只算白昼")
	t.eq(e.next_boundary(_s(5.5)), _s(6.0), "下一个结算点：阶段结束")
	t.eq(e.next_boundary(_s(4.2)), _s(5.0), "下一个结算点：下一整秒")
	var nonight := SunCycle.new()
	nonight.night_sec = 0.0
	t.check(bool(nonight.phase_at(_s(100.0))["day"]) and int(nonight.phase_at(_s(100.0))["end"]) == -1, "黑夜 0 秒：一直白昼")
	var noday := SunCycle.new()
	noday.day_sec = 0.0
	t.eq(noday.states_at(_s(3.0)), Vector2i(0, 1), "白昼 0 秒：一直黑夜")
	var ecl := SunCycle.new()
	ecl.eclipse_sun = true
	t.eq(ecl.states_at(_s(1.0)), Vector2i(1, 1), "日蚀：白昼也算黑夜")
	t.eq(ecl.states_at(_s(7.0)), Vector2i(0, 1), "日蚀：黑夜不算白昼")
	var lun := SunCycle.new()
	lun.eclipse_moon = true
	t.eq(lun.states_at(_s(7.0)), Vector2i(1, 1), "月蚀：黑夜也算白昼")
	var dusk := SunCycle.new()
	dusk.dusk_sec = 1.0
	t.eq(dusk.states_at(_s(6.5)), Vector2i(1, 1), "残阳：进黑夜的头 1 秒也算白昼")
	t.eq(dusk.states_at(_s(7.0)), Vector2i(0, 1), "残阳：1 秒后只算黑夜")
	t.eq(dusk.next_boundary(_s(6.2)), _s(7.0), "残阳的尾巴结束也是结算点")
	var dawn := SunCycle.new()
	dawn.dawn_sec = 2.0
	t.eq(dawn.states_at(_s(0.5)), Vector2i(1, 0), "斜月：开战那段白昼不算（不是从黑夜进来的）")
	t.eq(dawn.states_at(_s(13.0)), Vector2i(1, 1), "斜月：进白昼的头 2 秒也算黑夜")
	t.eq(dawn.night_ends(_s(6.0), _s(60.0)), _s(14.0), "黑夜连着斜月：到第 14 秒才不算黑夜")


static func run_core(t: TestCase) -> void:
	t.begin("388 · 日月核心：身上挂【白昼】/【黑夜】跟着换；白昼伤害 +15%；每换一次边写一次战记（经验值按它给）")
	var r := BattleSim.run(_me(), FX._spec(50000.0, []), _rng(1), 13.0)
	t.eq(_status_times(r, SunCycle.DAY, true), [0.0, 12.0] as Array[float], "【白昼】：开战、第 12 秒挂上")
	t.eq(_status_times(r, SunCycle.NIGHT, true), [6.0] as Array[float], "【黑夜】：第 6 秒挂上")
	t.eq(_status_times(r, SunCycle.DAY, false), [6.0] as Array[float], "【白昼】第 6 秒摘掉")
	t.eq(_mech(r, "sun_window").size(), 2, "13 秒里换了两次边（6、12）")
	var day_hit := 0
	var night_hit := 0
	for h in _hits(r):
		if float(h[0]) < 6.0 and day_hit == 0:
			day_hit = int(h[1])
		elif float(h[0]) > 6.5 and float(h[0]) < 12.0 and night_hit == 0:
			night_hit = int(h[1])
	t.check(day_hit > 0 and night_hit > 0, "白昼、黑夜都打中了")
	t.eq(day_hit, StatMath.mul(night_hit, StatMath.from_percent(115)), "白昼这一下 = 黑夜的 115%%（%d / %d）" % [day_hit, night_hit])
	var night := _fired(r).filter(func(x): return x >= 6.0 and x < 12.0).size()
	var day := _fired(r).filter(func(x): return x < 6.0).size()
	t.check(night >= day, "黑夜急速：出手不比白昼少（%d / %d）" % [night, day])
	var again := BattleSim.run(_me(), FX._spec(50000.0, []), _rng(1), 13.0)
	t.eq(again.log.size(), r.log.size(), "同种子同结果")


static func run_cards(t: TestCase) -> void:
	t.begin("388 · 日神的牌（战斗里）：日光浴 / 月光浴、大日炎炎 / 微月澹澹、日出、黎明、黄昏、夜幕、谦卑、永日、永夜")
	# 日光浴：白昼每秒 +1 层【日光】，黑夜每秒掉 1 层
	var bath := BattleSim.run(_me({"sun_light": 1}), FX._spec(50000.0, []), _rng(2), 9.0)
	t.eq(_status_times(bath, SunCycle.SUN_LIGHT, true).size(), 6, "白昼 6 秒：6 层【日光】")
	t.eq(_status_times(bath, SunCycle.SUN_LIGHT, false).size(), 3, "黑夜 3 秒：掉 3 层")
	var moon := BattleSim.run(_me({"moon_light": 2}), FX._spec(50000.0, []), _rng(2), 9.0)
	t.eq(_status_times(moon, SunCycle.MOON_LIGHT, true).size(), 3, "月光浴：只在黑夜的每一秒加")
	# 大日炎炎：白昼每秒给敌人【灼伤】
	var blaze := BattleSim.run(_me({"burn": 1}), FX._spec(50000.0, []), _rng(3), 8.0)
	t.eq(_status_times(blaze, SunCycle.SCORCH, true, 1).size(), 6, "大日炎炎：白昼每秒给敌人一层【灼伤】")
	var frost := BattleSim.run(_me({"frost": 1}), FX._spec(50000.0, []), _rng(3), 8.0)
	t.eq(_status_times(frost, SunCycle.CHILL, true, 1).size(), 2, "微月澹澹：黑夜每秒给敌人【寒冷】")
	# 夜幕：黑夜受到的伤害少
	var plain := _taken(BattleSim.run(_me({"day_sec": 0.0}), _hitter(20.0), _rng(4), 6.0))
	var veil := _taken(BattleSim.run(_me({"day_sec": 0.0, "veil": 50.0}), _hitter(20.0), _rng(4), 6.0))
	t.check(plain > 0 and veil * 2 <= plain + 10, "夜幕 50%%：一直黑夜时受到的少一半（%d / %d）" % [veil, plain])
	var humble := _taken(BattleSim.run(_me({"day_sec": 0.0, "humble": 20.0}), _hitter(20.0), _rng(4), 6.0))
	t.check(humble < plain, "谦卑：受到的也少（%d / %d）" % [humble, plain])
	# 黄昏：进黑夜回耐力；日落当息：黑夜回血、武器停表
	var rest := BattleSim.run(_me({"rest_heal": 1.0}), _hitter(5.0), _rng(5), 12.0)
	var inside := _fired(rest).filter(func(x): return x > 6.0 and x < 12.0)
	t.eq(inside.size(), 0, "日落当息：黑夜里不出手（停表）")
	t.check(_fired(rest).filter(func(x): return x < 6.0).size() > 0, "白昼照常出手")
	# 永日不落：白昼伤害、急速再 +%，每秒双方各一层灼伤
	var eternal := BattleSim.run(_me({"night_sec": 0.0, "eternal_day": 25.0, "eternal_day_scorch": 1}), FX._spec(50000.0, []), _rng(6), 4.0)
	t.eq(_status_times(eternal, SunCycle.ETERNAL, true).size(), 1, "永日：身上挂【永恒】")
	t.eq(_status_times(eternal, SunCycle.SCORCH, true, 0).size(), _status_times(eternal, SunCycle.SCORCH, true, 1).size(), "永日的代价：双方每秒同样一层灼伤")
	var night_forever := BattleSim.run(_me({"day_sec": 0.0, "eternal_night": 25.0}), FX._spec(50000.0, []), _rng(6), 4.0)
	t.eq(_status_times(night_forever, SunCycle.ETERNAL, true, 1).size(), 1, "永夜：【永恒】挂在敌人身上（减伤害、急速）")


static func run_shift(t: TestCase) -> void:
	t.begin("388 · 星移斗转：每换一次边 +1 层（加成都 +1%），开战带上这一局之前攒的层数")
	var r := BattleSim.run(_me({"shift_on": true, "shift_start": 3}), FX._spec(50000.0, []), _rng(7), 13.0)
	var ups := _status_times(r, SunCycle.SHIFT, true)
	t.eq(ups.size(), 3, "开战一次（带 3 层）+ 两次换边")
	t.check(not ups.is_empty() and ups[0] == 0.0, "开战就带着")
	var plain := BattleSim.run(_me(), FX._spec(50000.0, []), _rng(7), 13.0)
	t.eq(_status_times(plain, SunCycle.SHIFT, true).size(), 0, "没拿：不挂")


static func run_ledger(t: TestCase) -> void:
	t.begin("388 · 日神的经验值：换边每次 +2、最多 4；三阶 42 / 117 / 217")
	var def := load("res://data/faiths/sun.tres") as FaithDef
	var sum := func(mech: Dictionary, won: bool) -> int:
		var n := 0
		for d in def.deeds:
			n += (d as FaithDeed).gain(&"battle", {"won": won, "mechanic": mech, "dealt": {}, "taken": {}, "fired_items": []})
		return n
	t.eq(sum.call({"sun_window": 1}, true), 2, "换一次边：+2")
	t.eq(sum.call({"sun_window": 5}, true), 4, "五次：封顶 4")
	t.eq(sum.call({"sun_window": 2}, false), 4, "输了保留已经做到的")
	t.eq(def.thresholds, [42, 117, 217] as Array[int], "三阶 = 升 5 / 10 / 15 级的经验值")


static func run_clock(t: TestCase) -> void:
	t.begin("388 日月盘（UI 定稿）：开战记下时间轴参数，回放按它还原各段、离换边几秒；两边都算的几秒单成一段；另一边 0 秒 = 不会变；色带只画到游标")
	var r := BattleSim.run(_me(), FX._spec(50000.0, []), _rng(1), 13.0)
	var c := SunCycle.clock_of(r)
	t.check(c != null and is_equal_approx(c.day_sec, 6.0) and is_equal_approx(c.night_sec, 6.0), "日志里还原出白昼 6、黑夜 6")
	var segs := c.segments(13.0)
	t.eq(segs.size(), 3, "13 秒：白昼、黑夜、白昼三段")
	t.check(bool(segs[0][2]) and not bool(segs[0][3]) and is_equal_approx(float(segs[0][1]), 6.0), "第一段白昼到第 6 秒")
	var cap := c.horizon(13.0)
	var all := c.segments(cap)
	var s := SunCycle.clock_at(all, 4.5, cap)
	t.check(bool(s["day"]) and is_equal_approx(float(s["left"]), 1.5) and is_equal_approx(float(s["span"]), 6.0), "第 4.5 秒：白昼还有 1.5 秒（%s）" % str(s))
	t.check(is_equal_approx(float(SunCycle.clock_at(all, 12.5, cap)["left"]), 5.5), "第 12.5 秒：最后一段也算得出离换边几秒")
	# 日蚀：白昼那几秒两边都算
	var ec := SunCycle.clock_of(BattleSim.run(_me({"eclipse_sun": true}), FX._spec(50000.0, []), _rng(1), 8.0))
	var es := ec.segments(8.0)
	t.check(bool(es[0][2]) and bool(es[0][3]), "日蚀：开头那段两边都算")
	# 永昼：黑夜 0 秒 → 不会变
	var et := SunCycle.clock_of(BattleSim.run(_me({"night_sec": 0.0}), FX._spec(50000.0, []), _rng(1), 8.0))
	var ecap := et.horizon(8.0)
	t.eq(float(SunCycle.clock_at(et.segments(ecap), 3.0, ecap)["left"]), -1.0, "永昼：写 ∞")
	# 回放：日月盘有、【白昼】【黑夜】不进栏；色带跟着游标
	var dial := SunDial.new()
	dial.load_result(r)
	t.check(dial.visible, "奉日神：日月盘显示")
	dial.now = 7.0
	var tip := dial.tip_parts()
	t.check(String(tip.get("head", "")).contains("5.0"), "悬浮窗第一行写还有几秒（%s）" % String(tip.get("head", "")))
	t.check(String(tip.get("body", "")).contains("15"), "第二行写这一边的加成")
	dial.free()
	var plain := SunDial.new()
	plain.load_result(BattleSim.run(FX._spec(500.0, []), FX._spec(500.0, []), _rng(2), 3.0))
	t.check(not plain.visible, "没奉日神：不显示")
	plain.free()
	var line := ReplayTimeline.new()
	line.load_result(r)
	t.eq(line.sun_segments.size(), 3, "回放条下的色带三段")
	t.check(line.custom_minimum_size.y > ReplayTimeline.HEIGHT, "有色带时回放条高一截")
	line.free()
	var panel := CombatantPanel.new()
	panel.hidden_ids = [String(SunCycle.DAY)] as Array[String]
	panel.set_stacks(String(SunCycle.DAY), 1)
	panel.set_stacks(String(SunCycle.SUN_LIGHT), 1)
	t.check(not panel.stacks().has(String(SunCycle.DAY)) and panel.stacks().has(String(SunCycle.SUN_LIGHT)), "【白昼】不进栏、【日光】照挂")
	panel.free()
