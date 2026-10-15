## 175 第一批：元素印与反应表 —— 命中盖印、施加中毒 / 流血即盖印、物理不盖；十对反应各一例；同元素加深不反应；燃血治疗为零；
## 反应不连锁；导入器的校验。175 补充一（作者伪代码）：印可叠层（灼 / 寒 / 麻上限十层）；取层数最多的异色印、N = max、已有印扣光、
## 新印不叠；凝毒 / 电解是产物（N 层凝毒不可清除、N 层剧毒）；菌血按恢复量叠中毒；中毒每层 1 点
extends RefCounted

const H := preload("res://tests/battle/test_effect_system.gd")
const S := preload("res://tests/battle/test_status_synergy.gd")


static func _b(id: String) -> BuffDef:
	return ContentLibrary.buffs().get(StringName(id), null)


static func _hit(type: StringName, amount: float) -> DealDamage:
	return S._flat(amount, type)


static func _apply(id: String, stacks: int = 1) -> ApplyStatus:
	return S._apply(_b(id), stacks)


static func _heal_opp(amount: float) -> ChangeResource:
	var e := ChangeResource.new()
	e.target = CombatEffect.Target.OPPONENT
	e.resource_key = BattleStats.RES_HP
	e.amount = amount
	return e


static func _cleanse(id: String) -> RemoveStatus:
	var e := RemoveStatus.new()
	e.target = CombatEffect.Target.OPPONENT
	e.buff_id = StringName(id)
	e.stacks = 0
	return e


static func _cleanse_all() -> RemoveStatus:
	var e := RemoveStatus.new()
	e.target = CombatEffect.Target.OPPONENT
	e.all_debuffs = true
	return e


## 开战那一刻依次跑 [param effects]（打对手）的一场；[param side1_stats] 是对手那件的属性
static func _run(effects: Array, side1_stats: Dictionary = {}) -> BattleContext:
	var ctx := H._battle(H._spec(100.0, [H._compiled(1, "a", {}, [S._opener(effects)])]),
		H._spec(100.0, [H._compiled(2, "b", side1_stats, [])]))
	S._start(ctx)
	return ctx


static func _reactions(ctx: BattleContext) -> Array[StringName]:
	return ReactionResolver.reactions_in(ctx.log)


static func run_marks(t: TestCase) -> void:
	t.begin("175 · 印：火 / 冰 / 雷命中盖灼 / 寒 / 麻（一下一层），施加中毒 / 流血就是盖印，物理不盖；印可叠层、永续，灼 / 寒 / 麻至多十层")
	t.eq(DamageTypes.get_def(DamageTypes.FIRE).mark, &"scorch", "火焰盖灼")
	t.eq(DamageTypes.get_def(DamageTypes.ICE).mark, &"chill", "冰霜盖寒")
	t.eq(DamageTypes.get_def(DamageTypes.LIGHTNING).mark, &"numb", "闪电盖麻")
	t.eq(DamageTypes.get_def(DamageTypes.PHYSICAL).mark, &"", "物理不盖")
	t.eq(DamageTypes.get_def(DamageTypes.POISON).mark, &"", "中毒伤害不盖（毒印是状态本身，否则每跳一次多一层）")
	t.eq(DamageTypes.get_def(DamageTypes.FIRE).mark_stacks, 1, "一下盖一层（补 3 A）")
	for id in ["scorch", "chill", "numb"]:
		var b := _b(id)
		t.not_null(b, "有印 %s" % id)
		if b != null:
			t.check(b.is_stackable() and b.is_permanent() and b.is_debuff and b.stack_cap == 10, "%s 可叠、永续、减益、至多十层（补 2 B）" % id)
	t.eq(_b("poison").element, &"poison", "中毒是毒印")
	t.eq(_b("virulent").element, &"poison", "剧毒也是毒印")
	t.eq(_b("bleed").element, &"bleed", "流血是血印")

	var ctx := _run([_hit(DamageTypes.FIRE, 1.0)])
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 1, "火伤之后身上一层灼")
	t.check(_reactions(ctx).is_empty(), "一种元素不反应")
	H._advance_to(ctx, 6.0)
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 1, "灼永续，不再四秒消失")

	ctx = _run([_hit(DamageTypes.PHYSICAL, 1.0)])
	t.check(ctx.sides[1].buffs.is_empty(), "物理不盖印")

	ctx = _run([_hit(DamageTypes.FIRE, 1.0), _hit(DamageTypes.FIRE, 1.0), _hit(DamageTypes.FIRE, 1.0)])
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 3, "同元素再碰：灼加层")
	t.check(_reactions(ctx).is_empty(), "同元素不反应")
	var many: Array = []
	for i in 12:
		many.append(_hit(DamageTypes.FIRE, 1.0))
	ctx = _run(many)
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 10, "十二下火：灼封顶十层")
	ctx = _run([_apply("poison", 2), _apply("poison", 3)])
	t.eq(ctx.sides[1].stacks_of(&"poison"), 5, "中毒再碰就是加层")
	t.check(_reactions(ctx).is_empty(), "毒碰毒不反应")


static func run_table(t: TestCase) -> void:
	t.begin("175 · 反应表：十对、名字定稿、id 按元素顺序拼")
	var names := {"fire_poison": "爆燃", "fire_ice": "淬裂", "fire_lightning": "过载", "fire_bleed": "燃血", "ice_lightning": "超导",
		"ice_poison": "凝毒", "ice_bleed": "冻疮", "lightning_poison": "电解", "lightning_bleed": "激荡", "poison_bleed": "菌血"}
	var all := ReactionResolver.all()
	t.eq(all.size(), 10, "十对反应")
	for def in all:
		t.eq(def.display_name, String(names.get(String(def.id), "?")), "%s 的名字" % def.id)
	t.eq(String(all[0].id), "fire_ice", "按元素顺序排：火冰在前")
	t.eq(ReactionResolver.find(&"poison", &"fire").display_name, "爆燃", "不分先后")
	t.eq(ReactionResolver.pair_key(&"bleed", &"ice"), "ice_bleed", "键按元素顺序")
	t.eq(ReactionResolver.pair_key(&"fire", &"fire"), "", "同元素没有键")


static func run_fire(t: TestCase) -> void:
	t.begin("175 · 火系反应：爆燃按层数火伤再盖灼、淬裂护甲清零、过载下一下翻倍、燃血治疗无效")
	# 爆燃：三层中毒 + 一下火 1 → 3 × 3 = 9 火伤，中毒清空，再盖灼
	var ctx := _run([_apply("poison", 3), _hit(DamageTypes.FIRE, 1.0)])
	t.eq(_reactions(ctx), [&"fire_poison"] as Array[StringName], "引发爆燃")
	t.eq(ctx.sides[1].stacks_of(&"poison"), 0, "中毒被吃掉")
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 1, "再盖上灼")
	t.eq(S._hp(ctx, 1), 90, "已有多：N = max(3, 1) = 3，火 1 + 3 × 3 = 9")
	# 反过来：先有一层灼、再施加两层中毒 —— N = max(1, 2) = 2，中毒不叠上去
	ctx = _run([_hit(DamageTypes.FIRE, 1.0), _apply("poison", 2)])
	t.eq(_reactions(ctx), [&"fire_poison"] as Array[StringName], "先灼后毒也是爆燃")
	t.eq(S._hp(ctx, 1), 93, "新来多：N = max(1, 2) = 2，火 1 + 2 × 3 = 6")
	t.eq(ctx.sides[1].stacks_of(&"poison"), 0, "新来的中毒整份进了反应，不叠")
	# 相等：两层灼 + 两层中毒 → N = 2
	ctx = _run([_hit(DamageTypes.FIRE, 1.0), _hit(DamageTypes.FIRE, 1.0), _apply("poison", 2)])
	t.eq(S._hp(ctx, 1), 92, "相等：N = 2，火 1 + 1 + 2 × 3 = 6")

	# 淬裂：先寒、再火 → 护甲清零 + 8 点
	ctx = _run([_hit(DamageTypes.ICE, 1.0), _hit(DamageTypes.FIRE, 5.0)], {"max_armor": 30})
	t.eq(_reactions(ctx), [&"fire_ice"] as Array[StringName], "引发淬裂")
	t.eq(ctx.sides[1].resources.current(BattleStats.RES_ARMOR), 0, "护甲清零")
	t.eq(S._hp(ctx, 1), 92, "前两下被护甲吃掉，淬裂的 8 点见血")
	t.eq(ctx.sides[1].stacks_of(&"chill") + ctx.sides[1].stacks_of(&"scorch"), 0, "两印都消耗（火这一下的灼不盖）")

	# 过载：火 → 雷 → 自己下一下翻倍，用掉就没
	ctx = _run([_hit(DamageTypes.FIRE, 1.0), _hit(DamageTypes.LIGHTNING, 1.0), _hit(DamageTypes.PHYSICAL, 10.0), _hit(DamageTypes.PHYSICAL, 10.0)])
	t.eq(_reactions(ctx), [&"fire_lightning"] as Array[StringName], "引发过载")
	t.eq(S._hp(ctx, 1), 100 - 1 - 1 - 20 - 10, "过载后第一下 20，第二下照常 10")
	t.eq(ctx.sides[0].stacks_of(&"overload"), 0, "过载用掉了")

	# 燃血：流血 → 火 → 治疗无效 + 6 点火伤；反应里的这下火伤不盖灼（反应不连锁）
	ctx = _run([_apply("bleed", 2), _hit(DamageTypes.FIRE, 1.0), _heal_opp(20.0)])
	t.eq(_reactions(ctx), [&"fire_bleed"] as Array[StringName], "引发燃血")
	t.eq(ctx.sides[1].stacks_of(&"bleed"), 0, "流血被吃掉")
	t.eq(ctx.sides[1].stacks_of(&"scorched_blood"), 1, "对手燃血")
	t.eq(S._hp(ctx, 1), 93, "火 1 + 燃血 6；之后的治疗 20 为零")
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 0, "反应里的火伤不盖灼（本次结算内不盖新印）")
	H._advance_to(ctx, 5.1)
	t.eq(ctx.sides[1].stacks_of(&"scorched_blood"), 0, "几秒后燃血消失")


static func run_ice(t: TestCase) -> void:
	t.begin("175 · 冰系反应：超导易伤、凝毒产出 N 层不可清除的凝毒、冻疮减速")
	# 超导：寒 → 雷 → 受到的最终伤害 +20%
	var ctx := _run([_hit(DamageTypes.ICE, 1.0), _hit(DamageTypes.LIGHTNING, 1.0), _hit(DamageTypes.PHYSICAL, 10.0)])
	t.eq(_reactions(ctx), [&"ice_lightning"] as Array[StringName], "引发超导")
	t.eq(S._hp(ctx, 1), 100 - 1 - 1 - 12, "超导后 10 打成 12")

	# 凝毒（补 4 A，产物式）：两层中毒 → 冰 → 两层凝毒；中毒、寒都没留；凝毒清不掉、每层每秒 1 点、只有反应吃得掉
	ctx = _run([_apply("poison", 2), _hit(DamageTypes.ICE, 1.0), _cleanse("congeal"), _cleanse_all()])
	t.eq(_reactions(ctx), [&"ice_poison"] as Array[StringName], "引发凝毒")
	t.eq(ctx.sides[1].stacks_of(&"poison"), 0, "中毒被吃掉")
	t.eq(ctx.sides[1].stacks_of(&"chill"), 0, "寒印不叠（整份进了反应）")
	t.eq(ctx.sides[1].stacks_of(&"congeal"), 2, "产出 N = 2 层凝毒，解毒与清除全部减益都清不掉")
	t.check(_b("congeal").uncleansable and _b("congeal").element == &"poison", "凝毒：不可清除、毒印")
	var hp0 := S._hp(ctx, 1)
	H._advance_to(ctx, 3.05)
	t.eq(S._hp(ctx, 1), hp0 - 6, "三秒：每层每秒 1 点 × 2 层 × 3")
	t.eq(ctx.sides[1].stacks_of(&"congeal"), 2, "不衰减")
	var rc := RuleContext.create(ctx, ctx.sides[0], RuleRuntime.create(null, 1, null, 0))
	_hit(DamageTypes.FIRE, 1.0).apply(rc)
	t.eq(ReactionResolver.reactions_in(ctx.log).has(&"fire_poison"), true, "凝毒是毒印：再挨火就爆燃")
	t.eq(ctx.sides[1].stacks_of(&"congeal"), 0, "反应吃得掉凝毒")

	# 冻疮：流血 → 冰 → 出手间隔拉长（减速十层）
	ctx = _run([_apply("bleed"), _hit(DamageTypes.ICE, 1.0)])
	t.eq(_reactions(ctx), [&"ice_bleed"] as Array[StringName], "引发冻疮")
	t.eq(ctx.sides[1].axis_total(StatAxes.ATTACK_SPEED), -10, "对手减速十层")


static func run_lightning(t: TestCase) -> void:
	t.begin("175 · 雷系与毒血：电解产出 N 层剧毒、激荡下一次攻击必暴击、菌血按恢复量叠中毒")
	# 电解：三层中毒 → 雷 → 三层剧毒，麻不留
	var ctx := _run([_apply("poison", 3), _hit(DamageTypes.LIGHTNING, 1.0)])
	t.eq(_reactions(ctx), [&"lightning_poison"] as Array[StringName], "引发电解")
	t.eq(ctx.sides[1].stacks_of(&"poison"), 0, "中毒没了")
	t.eq(ctx.sides[1].stacks_of(&"virulent"), 3, "换成三层剧毒")
	t.eq(ctx.sides[1].stacks_of(&"numb"), 0, "麻被吃掉")

	# 激荡：流血 → 雷 → 下一次武器出手必暴击（这一下自己排在队里的出手事件不算「下一次」）
	var weapon := H._rule(OnSchedule.new(), H._cooldown(1.0), [DealDamage.new()])
	var w := H._compiled(1, "w", {"damage": 10}, [S._opener([_apply("bleed"), _hit(DamageTypes.LIGHTNING, 1.0)]), weapon])
	w.tags = [&"weapon"] as Array[StringName]
	ctx = H._battle(H._spec(100.0, [w]), H._spec(100.0, [H._compiled(2, "b", {}, [])]))
	S._start(ctx)
	t.eq(_reactions(ctx), [&"lightning_bleed"] as Array[StringName], "引发激荡")
	t.eq(ctx.sides[0].stacks_of(&"surge"), 1, "自己挂着激荡")
	H._advance_to(ctx, 1.05)
	var crits := 0
	for e in ctx.log:
		if e.name == BattleEvent.DAMAGE and e.get_int(&"amount") > 0 and e.get_bool(&"crit"):
			crits += 1
	t.eq(crits, 1, "下一次攻击暴击了")
	t.eq(ctx.sides[0].stacks_of(&"surge"), 0, "激荡用掉了")
	H._advance_to(ctx, 2.05)
	crits = 0
	for e in ctx.log:
		if e.name == BattleEvent.DAMAGE and e.get_int(&"amount") > 0 and e.get_bool(&"crit"):
			crits += 1
	t.eq(crits, 1, "再下一次不再必暴（默认暴击率 0）")

	# 菌血（补充一）：先打掉 20，中毒 → 流血 → 治疗 10 照常回 10，回了 10 点就叠 10 层中毒
	ctx = _run([_hit(DamageTypes.PHYSICAL, 20.0), _apply("poison"), _apply("bleed"), _heal_opp(10.0)])
	t.eq(_reactions(ctx), [&"poison_bleed"] as Array[StringName], "引发菌血")
	t.eq(ctx.sides[1].stacks_of(&"bleed"), 0, "新来的流血不叠")
	t.eq(S._hp(ctx, 1), 90, "恢复照常：80 + 10")
	t.eq(ctx.sides[1].stacks_of(&"poison"), 10, "回了 10 点：叠 10 层中毒")
	t.eq(_b("fungal_blood").heal_cut, 0, "菌血不再截治疗")
	H._advance_to(ctx, 2.05)
	t.eq(S._hp(ctx, 1), 70, "中毒每层每秒 1 点：两秒 −20")


static func run_rules(t: TestCase) -> void:
	t.begin("175 补充一 · 伪代码：取层数最多的异色印（并列按火冰雷毒血）、同色的不算；N = max；已有印扣光、新印不叠；反应不连锁")
	# 三色同在（直接挂上去，不经反应）：来雷 → 取层数最多的寒（5）→ 超导，灼与流血不动
	var ctx := _run([])
	var foe := ctx.sides[1]
	foe.apply_buff(_b("scorch"), 2, ctx.now)
	foe.apply_buff(_b("chill"), 5, ctx.now)
	foe.apply_buff(_b("bleed"), 3, ctx.now)
	var rc := RuleContext.create(ctx, ctx.sides[0], RuleRuntime.create(null, 1, null, 0))
	_hit(DamageTypes.LIGHTNING, 1.0).apply(rc)
	t.eq(_reactions(ctx), [&"ice_lightning"] as Array[StringName], "取层数最多的寒 → 超导")
	t.eq([foe.stacks_of(&"chill"), foe.stacks_of(&"scorch"), foe.stacks_of(&"bleed"), foe.stacks_of(&"numb")], [0, 2, 3, 0], "寒扣光、灼和流血不动、麻不叠")
	# 并列：灼 3、流血 3，来毒 → 按顺序取火 → 爆燃 N = 3
	ctx = _run([])
	foe = ctx.sides[1]
	foe.apply_buff(_b("scorch"), 3, ctx.now)
	foe.apply_buff(_b("bleed"), 3, ctx.now)
	rc = RuleContext.create(ctx, ctx.sides[0], RuleRuntime.create(null, 1, null, 0))
	_apply("poison").apply(rc)
	t.eq(_reactions(ctx), [&"fire_poison"] as Array[StringName], "并列取火（火冰雷毒血的顺序）")
	t.eq(S._hp(ctx, 1), 91, "N = max(3, 1) = 3：3 × 3 = 9")
	t.eq(foe.stacks_of(&"bleed"), 3, "流血不动")
	# 同色不算：灼 3 + 中毒 1，来火 → 异色只有中毒 → 爆燃 N = 1；原来的灼留着、再加反应盖的一层
	ctx = _run([])
	foe = ctx.sides[1]
	foe.apply_buff(_b("scorch"), 3, ctx.now)
	foe.apply_buff(_b("poison"), 1, ctx.now)
	rc = RuleContext.create(ctx, ctx.sides[0], RuleRuntime.create(null, 1, null, 0))
	_hit(DamageTypes.FIRE, 1.0).apply(rc)
	t.eq(_reactions(ctx), [&"fire_poison"] as Array[StringName], "同色的灼不算，和中毒反应")
	t.eq(foe.stacks_of(&"scorch"), 4, "灼 3 留着 + 爆燃盖的 1")
	# 电解（补 4 A）：先麻后毒 → N = max(1, 2) = 2 层剧毒
	ctx = _run([_hit(DamageTypes.LIGHTNING, 1.0), _apply("poison", 2)])
	t.eq([ctx.sides[1].stacks_of(&"virulent"), ctx.sides[1].stacks_of(&"poison"), ctx.sides[1].stacks_of(&"numb")], [2, 0, 0], "先麻后毒：两层剧毒，中毒不叠、麻扣光")
	# 反应不连锁：爆燃里的火伤与灼都在反应结算内
	ctx = _run([_apply("poison", 2), _apply("bleed")])
	t.eq(_reactions(ctx), [&"poison_bleed"] as Array[StringName], "毒 + 血 = 菌血")
	ctx = _run([_apply("poison", 1), _hit(DamageTypes.FIRE, 1.0), _hit(DamageTypes.FIRE, 1.0)])
	t.eq(_reactions(ctx).size(), 1, "爆燃之后对手只剩灼，再一下火只是加深")
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 2, "爆燃盖的一层 + 再一下火的一层")
	# 出生晚于事件：施加 buff 的那一刻已经排在队里的出手事件，它的规则听不见
	var rt := RuleRuntime.new()
	rt.born = 5
	var e := BattleEvent.make(BattleEvent.ITEM_FIRED, 0, 0, {})
	e.seq = 4
	t.check(rt.born > e.seq, "规则出生（5）晚于事件（4）：派发跳过")
	t.eq(BattleEvent.make(BattleEvent.ITEM_FIRED, 0, 0, {}).seq, BattleEvent.NO_SEQ, "手搓的事件谁都听得见")


static func run_import(t: TestCase) -> void:
	t.begin("175 · 导入器：反应得两种不同的元素、id 按元素顺序拼、得有效果")
	var ok := {"id": "fire_poison", "display_name": "爆燃", "elements": ["fire", "poison"],
		"effects": [{"type": "apply_status", "buff": "scorch"}]}
	var r := ImportReport.new()
	ContentImporter.import_reaction(ok, ContentLibrary.context(), r)
	t.check(r.ok(), "正常的能导（%s）" % r.to_text())
	var cases := [
		[{"id": "fire_fire", "display_name": "x", "elements": ["fire", "fire"], "effects": ok["effects"]}, "得不同"],
		[{"id": "fire_wind", "display_name": "x", "elements": ["fire", "wind"], "effects": ok["effects"]}, "不认识的元素"],
		[{"id": "poison_fire", "display_name": "x", "elements": ["poison", "fire"], "effects": ok["effects"]}, "fire_poison"],
		[{"id": "fire_poison", "display_name": "x", "elements": ["fire", "poison"], "effects": []}, "得有效果"],
	]
	for c in cases:
		var rr := ImportReport.new()
		ContentImporter.import_reaction(c[0], ContentLibrary.context(), rr)
		t.check(not rr.ok() and rr.to_text().contains(String(c[1])), "拦下：%s（%s）" % [c[1], rr.to_text()])


static func run_heal(t: TestCase) -> void:
	t.begin("175 · 治疗入口：燃血期间每秒回血也停、反转成的治疗也被截")
	var regen := H._compiled(2, "b", {"regen_hp": 2}, [])
	var ctx := H._battle(H._spec(100.0, [H._compiled(1, "a", {}, [S._opener([_hit(DamageTypes.PHYSICAL, 30.0), _apply("bleed"), _hit(DamageTypes.FIRE, 1.0)])])]),
		H._spec(100.0, [regen]))
	S._start(ctx)
	var hp0 := S._hp(ctx, 1)
	H._advance_to(ctx, 4.0)
	ctx.sides[1].settle_regen(ctx.now)
	t.eq(S._hp(ctx, 1), hp0, "燃血期间不回血")
	H._advance_to(ctx, 7.0)
	ctx.sides[1].settle_regen(ctx.now)
	t.eq(S._hp(ctx, 1), hp0 + 4, "燃血 5 秒到期后只补到期之后那 2 秒（不把燃血那段补回来）")
