## 366：伤害扳机的「只认格挡挡下的」—— 伤害事件 block > 0 且是直接攻击才算；第一批护甲和盾入库
extends RefCounted

const H := preload("res://tests/battle/test_effect_system.gd")


static func _ctx(side: int) -> RuleContext:
	var ctx := RuleContext.new()
	ctx.owner = CombatantRuntime.from_spec(H._spec(100.0, []), side)
	return ctx


static func _hit(side: int, block: int, direct: bool) -> BattleEvent:
	return BattleEvent.make(BattleEvent.DAMAGE, 0, side, {
		"type": "physical", "block": block, "direct": direct, "amount": 5, "provokes": true, "source_side": 1 - side,
	})


static func run_blocked_only(t: TestCase) -> void:
	t.begin("366 · blocked_only：格挡减掉至少 1 点的直接攻击才触发")
	var trig := OnDamage.new()
	trig.blocked_only = true
	var ctx := _ctx(0)
	t.check(trig.matches(ctx, _hit(0, 3, true)), "挡下 3 点的直接攻击：触发")
	t.check(not trig.matches(ctx, _hit(0, 0, true)), "没挡下：不触发")
	t.check(not trig.matches(ctx, _hit(0, 3, false)), "非直接伤害：不触发")
	t.check(not trig.matches(ctx, _hit(1, 3, true)), "挨打的是对面：不触发")
	t.eq(trig.describe(), UiText.t("trig.blocked"), "说明句：格挡挡下攻击时")


static func run_batch_one_items(t: TestCase) -> void:
	t.begin("366 · 第一批护甲 4 件、盾 4 件入库，说明留空")
	var ids := {
		"chain_mail": [2, "max_armor", 140], "studded_leather": [2, "max_armor", 90],
		"knight_plate": [3, "max_armor", 265], "dragonscale_armor": [3, "max_armor", 195],
		"steel_round_shield": [2, "block", 7], "kite_shield": [2, "block", 9],
		"legion_tower_shield": [3, "block", 12], "riposte_buckler": [3, "block", 4],
	}
	for id in ids:
		var def := load("res://data/items/%s.tres" % id) as ItemDef
		t.check(def != null, "%s 存在" % id)
		if def == null:
			continue
		var want: Array = ids[id]
		t.eq(def.rarity, int(want[0]), "%s 稀有度" % id)
		t.eq(float(def.combat.base_stats.get(want[1], 0.0)), float(want[2]), "%s %s" % [id, want[1]])
		t.eq(String(def.descriptions.get("en", "")), "", "%s 说明留空" % id)
	var buckler := load("res://data/items/riposte_buckler.tres") as ItemDef
	var rule: AbilityRule = buckler.combat.rules[0]
	t.check(rule.trigger is OnDamage and (rule.trigger as OnDamage).blocked_only, "反击小盾：格挡挡下攻击时")


static func run_guard_link_items(t: TestCase) -> void:
	t.begin("366 · 守卫联动道具与失效版：贵重品，不进随机来源，没有战斗效果，说明留空")
	for id in ["spare_mainspring", "rally_horn", "beast_king_pact"]:
		for v in [id, id + "_spent"]:
			var def := load("res://data/items/%s.tres" % v) as ItemDef
			t.check(def != null, "%s 存在" % v)
			if def == null:
				continue
			t.check(def.has_tag(ItemDef.NO_RANDOM_SOURCE), "%s 不进随机来源" % v)
			t.check(def.has_tag(&"valuable"), "%s 是贵重品" % v)
			t.check(def.combat == null or def.combat.rules.is_empty(), "%s 不带战斗规则（增援由难度那边的钩子做）" % v)
			t.eq(String(def.descriptions.get("en", "")), "", "%s 说明留空" % v)
		var base := load("res://data/items/%s.tres" % id) as ItemDef
		var spent := load("res://data/items/%s_spent.tres" % id) as ItemDef
		if base != null and spent != null:
			t.eq(ItemValue.of(spent), roundi(ItemValue.of(base) / 2.0), "%s 失效版按本体一半定价（作者 11-23）" % id)
