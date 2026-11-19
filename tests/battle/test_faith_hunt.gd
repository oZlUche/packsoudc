## 信仰重构 C（交接方案 §6.6）：狩猎之神「拆解」—— 推荐标记按对手的本事；武器打中攒点（每秒最多一点）；
## 3 点第一档（没到一阶只有一半）、二阶 6 点第二档；削弱只在这一场；三阶拆完第二档打赢掉落偏向兽材。
extends RefCounted

const Comp := preload("res://tests/battle/test_compiler.gd")
const FX := preload("res://tests/battle/test_effect_system.gd")
const ID := HuntDismantle.BUFF_ID


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


static func _me(tier: int, cd: float = 0.5) -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	b.place(ItemInstance.create(Comp._weapon("t_bow", ["1"], 10.0, cd, ["weapon", "ranged"])), Vector2i(0, 0), 0)
	var rules: Array[AbilityRule] = []
	if tier >= 0:
		rules.append(HuntDismantlePerk.new().rule_at(tier))
	return BattleCompiler.compile_board(b, CombatantBaseline.with_hp(5000.0), [] as Array[StatModifier], rules)


## 会打人的对手（一把 1 秒一下的武器）
static func _hitter() -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	b.place(ItemInstance.create(Comp._weapon("t_foe", ["1"], 4.0, 1.0, ["weapon", "melee"])), Vector2i(0, 0), 0)
	return BattleCompiler.compile_board(b, CombatantBaseline.with_hp(5000.0))


static func _events(res: BattleResult, key: String) -> Array:
	var out: Array = []
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.EFFECT_RESOLVED and String(e.payload.get("effect", "")) == SkillMomentum.MECHANIC and String(e.payload.get("key", "")) == key:
			out.append(e)
	return out


static func _axis(res: BattleResult, axis: StringName) -> int:
	var n := 0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.AXIS_SHIFTED and e.side == 1 and e.get_name(&"axis") == axis:
			n += e.get_int(&"delta")
	return n


static func run_marks(t: TestCase) -> void:
	t.begin("信仰重构 C · 拆解：推荐标记（会打人 → 攻击节奏；木桩 → 暴露）；开战写进战记")
	var r := BattleSim.run(_me(1), _hitter(), _rng(1), 8.0)
	var marks := _events(r, "hunt_mark")
	t.eq(marks.size(), 1, "开战挑一次标记")
	t.eq(String((marks[0] as BattleEvent).payload.get("arg", "")) if not marks.is_empty() else "", "hunt.mark_tempo", "会出手的对手：攻击节奏")
	var dummy := BattleSim.run(_me(1), FX._spec(5000.0, []), _rng(1), 8.0)
	var m2 := _events(dummy, "hunt_mark")
	t.eq(String((m2[0] as BattleEvent).payload.get("arg", "")) if not m2.is_empty() else "", "hunt.mark_exposed", "什么本事都没有的木桩：暴露（不会没得选）")
	t.check(not UiText.t("log.hunt_mark").is_empty() and UiText.t("hunt.mark_tempo") != "hunt.mark_tempo", "战记那句与标记名都在字表里")


static func run_points_and_stages(t: TestCase) -> void:
	t.begin("信仰重构 C · 拆解：每半秒最多一点；一阶 3 点第一档 −10%；二阶 6 点第二档到 −20%；没到一阶只有一半")
	var fast := BattleSim.run(_me(1, 0.25), _hitter(), _rng(2), 10.0)
	var stacked := 0
	var last_at := -999999
	var too_close := false
	for raw in fast.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.STATUS_STACKED and e.side == 1 and e.get_name(&"buff") == ID and e.get_int(&"delta") > 0:
			stacked += 1
			if e.time - last_at < StatMath.from_float(0.5):
				too_close = true
			last_at = e.time
	t.check(stacked > 0 and not too_close, "四分之一秒一下的弓：点数照样每半秒最多一点（%d 点，E 批从每秒缩短）" % stacked)
	t.eq(_events(fast, "hunt_stage1").size(), 1, "一阶：到第一档一次")
	t.eq(_events(fast, "hunt_stage2").size(), 0, "一阶没有第二档")
	var step := int(StatAxes.info(StatAxes.ATTACK_SPEED)["step"])
	t.eq(_axis(fast, StatAxes.ATTACK_SPEED), -roundi(10.0 / step), "攻击节奏 −10%%：减速 %d 层" % roundi(10.0 / step))
	var two := BattleSim.run(_me(2, 0.25), _hitter(), _rng(2), 10.0)
	t.eq(_events(two, "hunt_stage2").size(), 1, "二阶：到第二档")
	t.eq(_axis(two, StatAxes.ATTACK_SPEED), -roundi(20.0 / step), "第二档总计 −20%：多出来的那截才落")
	var zero := BattleSim.run(_me(0, 0.25), _hitter(), _rng(2), 10.0)
	t.eq(_axis(zero, StatAxes.ATTACK_SPEED), -maxi(1, roundi(5.0 / step)), "没到一阶：第一档只有一半")
	var again := BattleSim.run(_me(2, 0.25), _hitter(), _rng(2), 10.0)
	t.eq(again.log.size(), two.log.size(), "同种子同结果")


static func run_loot_tier3(t: TestCase) -> void:
	t.begin("信仰重构 C · 拆解三阶：拆完第二档并打赢，掉落偏向兽材 / 素材；没拆完不偏")
	var p := HuntDismantlePerk.new()
	p.part = 3
	var ctx := LootContext.new()
	p.modify_loot(ctx, &"battle")
	t.check(ctx.category_bias.is_empty(), "没拆完第二档：不偏")
	ctx.battle_notes = {"hunt_stage2": 1}
	p.modify_loot(ctx, &"battle")
	t.check(int(ctx.category_bias.get(&"beast_part", 0)) > 0 and int(ctx.category_bias.get(&"material", 0)) > 0, "拆完了：兽材与素材加权（%s）" % ctx.category_bias)
	var base := HuntDismantlePerk.new()
	var c2 := LootContext.new()
	c2.battle_notes = {"hunt_stage2": 1}
	base.modify_loot(c2, &"battle")
	t.check(c2.category_bias.is_empty(), "只有三阶那一条改掉落")
