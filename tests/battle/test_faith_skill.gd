## 信仰重构 C（交接方案 §6.5）：技巧之神「巧劲」—— 换类出手攒层、同类不攒、开战一层；一阶起打出去用掉、加伤、两层穿透；
## 二阶格挡算防御动作；三阶「防御 → 攻击 → 另一类攻击」追加一下（一场一次）。连带出手不算原始动作。
extends RefCounted

const Comp := preload("res://tests/battle/test_compiler.gd")
const FX := preload("res://tests/battle/test_effect_system.gd")
const ID := SkillMomentum.BUFF_ID


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


static func _perk() -> SkillMomentumPerk:
	return SkillMomentumPerk.new()


## 一块棋盘：[param kinds] 每项一件武器（`melee` / `ranged`），伤害 10，冷却依次 1.0、1.3……；[param shield] 再放一面格挡 5 的盾
static func _board(kinds: Array, shield: bool = false) -> GridInventory:
	var b := GridInventory.new(Vector2i(8, 4), 1, false)
	var x := 0
	for i in kinds.size():
		var w := Comp._weapon("t_w%d" % i, ["1"], 10.0, 1.0 + 0.3 * i, ["weapon", String(kinds[i])])
		b.place(ItemInstance.create(w), Vector2i(x, 0), 0)
		x += 2
	if shield:
		var s := Comp._item("t_shield", ["1"], ["shield"])
		var c := CombatProfile.new()
		c.base_stats = {"block": 5.0}
		s.combat = c
		b.place(ItemInstance.create(s), Vector2i(x, 0), 0)
	return b


static func _me(board: GridInventory, tier: int) -> CombatantSpec:
	var rules: Array[AbilityRule] = []
	if tier >= 0:
		rules.append(_perk().rule_at(tier))
	return BattleCompiler.compile_board(board, CombatantBaseline.with_hp(5000.0), [] as Array[StatModifier], rules)


## 会打人的对手（一把 1 秒一下、伤害 8 的武器）
static func _foe() -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	b.place(ItemInstance.create(Comp._weapon("t_foe", ["1"], 8.0, 1.0, ["weapon", "melee"])), Vector2i(0, 0), 0)
	return BattleCompiler.compile_board(b, CombatantBaseline.with_hp(5000.0))


static func _count(res: BattleResult, name: StringName, side: int, pred: Callable = Callable()) -> int:
	var n := 0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == name and e.side == side and (not pred.is_valid() or bool(pred.call(e))):
			n += 1
	return n


static func _dealt(res: BattleResult) -> int:
	var n := 0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 1:
			n += maxi(0, e.get_int(&"amount"))
	return n


static func run_categories(t: TestCase) -> void:
	t.begin("信仰重构 C · 巧劲：动作类别按标签（法杖 = 施法、远程、近战；不是武器 = 空）")
	t.eq(SkillMomentum.category_of([&"weapon", &"melee"] as Array[StringName]), SkillMomentum.MELEE, "近战")
	t.eq(SkillMomentum.category_of([&"weapon", &"ranged"] as Array[StringName]), SkillMomentum.RANGED, "远程")
	t.eq(SkillMomentum.category_of([&"weapon", &"melee", &"staff"] as Array[StringName]), SkillMomentum.SPELL, "法杖算施法（优先）")
	t.eq(SkillMomentum.category_of([&"shield"] as Array[StringName]), &"", "盾不出手：空（二阶起靠格挡计）")
	t.check(SkillMomentum.buff_def() != null, "巧劲有 buff 定义（data/buffs/skill_momentum）")


static func run_build_and_spend(t: TestCase) -> void:
	t.begin("信仰重构 C · 巧劲：换类攒、同类不攒、开战一层；基础只攒不加伤，一阶起用掉加伤")
	var mixed := _board(["melee", "ranged"])
	var same := _board(["melee", "melee"])
	var foe := FX._spec(5000.0, [])
	var base := BattleSim.run(_me(mixed, -1), foe, _rng(1), 10.0)
	var r0 := BattleSim.run(_me(mixed, 0), FX._spec(5000.0, []), _rng(1), 10.0)
	var gained := func(e: BattleEvent) -> bool: return e.get_name(&"buff") == ID and e.get_int(&"delta") > 0 and e.time > 0
	var opened := func(e: BattleEvent) -> bool: return e.get_name(&"buff") == ID and e.time == 0
	t.eq(_count(r0, BattleEvent.STATUS_STACKED, 0, opened), 1, "开战送一层")
	t.check(_count(r0, BattleEvent.STATUS_STACKED, 0, gained) > 0, "近战 + 远程交替：攒到了巧劲（%d 次）" % _count(r0, BattleEvent.STATUS_STACKED, 0, gained))
	t.check(_count(r0, BattleEvent.STATUS_UNSTACKED, 0, func(e: BattleEvent) -> bool: return e.get_name(&"buff") == ID) > 0, "武器打出去就用掉")
	t.eq(_dealt(r0), _dealt(base), "基础阶只攒不加伤：伤害和不奉神一样（%d）" % _dealt(base))
	var rs := BattleSim.run(_me(same, 0), FX._spec(5000.0, []), _rng(1), 10.0)
	t.eq(_count(rs, BattleEvent.STATUS_STACKED, 0, gained), 0, "两把近战：同类不攒")
	var r1 := BattleSim.run(_me(mixed, 1), FX._spec(5000.0, []), _rng(1), 10.0)
	t.check(_dealt(r1) > _dealt(base), "一阶：用掉巧劲加伤（%d > %d）" % [_dealt(r1), _dealt(base)])
	var again := BattleSim.run(_me(mixed, 1), FX._spec(5000.0, []), _rng(1), 10.0)
	t.eq(_dealt(again), _dealt(r1), "同种子同结果（不读墙上时钟）")
	var cap := _perk().cap
	var top := 0
	for raw in r1.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.STATUS_STACKED and e.get_name(&"buff") == ID:
			top = maxi(top, e.get_int(&"stacks"))
	t.check(top <= cap, "层数不超过上限 %d（最多到 %d）" % [cap, top])


static func run_defense_and_combo(t: TestCase) -> void:
	t.begin("信仰重构 C · 巧劲：二阶格挡算防御动作；三阶「防御 → 攻击 → 另一类攻击」追加一下，一场一次")
	var board := _board(["melee", "ranged"], true)
	var combo := func(e: BattleEvent) -> bool: return String(e.payload.get("effect", "")) == SkillMomentum.MECHANIC and String(e.payload.get("key", "")) == "skill_combo"
	var r1 := BattleSim.run(_me(board, 1), _foe(), _rng(3), 15.0)
	var r2 := BattleSim.run(_me(board, 2), _foe(), _rng(3), 15.0)
	var gained := func(e: BattleEvent) -> bool: return e.get_name(&"buff") == ID and e.get_int(&"delta") > 0 and e.time > 0
	t.check(_count(r2, BattleEvent.STATUS_STACKED, 0, gained) >= _count(r1, BattleEvent.STATUS_STACKED, 0, gained), "二阶：格挡也是动作，攒得不少于一阶（%d ≥ %d）" % [_count(r2, BattleEvent.STATUS_STACKED, 0, gained), _count(r1, BattleEvent.STATUS_STACKED, 0, gained)])
	t.eq(_count(r2, BattleEvent.EFFECT_RESOLVED, 0, combo), 0, "二阶没有连携")
	var r3 := BattleSim.run(_me(board, 3), _foe(), _rng(3), 15.0)
	t.eq(_count(r3, BattleEvent.EFFECT_RESOLVED, 0, combo), 1, "三阶：连携一场一次")
	var summary := RunState.battle_summary(r3, true, board)
	t.check(int((summary["mechanic"] as Dictionary).get("skill_combo", 0)) == 1 and int((summary["mechanic"] as Dictionary).get(String(ID), 0)) > 0, "战斗账记下机制次数（给信力行为用）：%s" % summary["mechanic"])
	var deed := MechanicDeed.new()
	deed.key = ID
	deed.at_least = 1
	deed.amount = 2
	t.eq(deed.gain(&"battle", summary), 2, "攒到巧劲：+2")
	deed.at_least = 9999
	t.eq(deed.gain(&"battle", summary), 0, "没到次数：0")
