## 132（作者定）：规则构件第二批 —— 来源标签筛、状态掉光时、涨过阈值 / 回满、只在暴击时、加时开始时、受益格挂规则、
## 资源 / 轴条件与轴消耗、取反、按生命比例的伤害、按目标层数乘、按伤害比例回复、清光全部减益、改伤害类型、导入器的警告与校验
extends RefCounted

const H := preload("res://tests/battle/test_effect_system.gd")


static func _start(ctx: BattleContext) -> void:
	ctx.emit(BattleEvent.BATTLE_START, -1, {})
	ctx.drain()


static func _hp(ctx: BattleContext, side: int) -> int:
	return StatMath.to_int(ctx.sides[side].resources.current(BattleStats.RES_HP))


static func _buff(id: String, debuff: bool = false, system: bool = false) -> BuffDef:
	var b := BuffDef.new()
	b.id = StringName(id)
	b.display_name = id
	b.is_debuff = debuff
	b.system = system
	return b


static func _apply(def: BuffDef, stacks: int = 1, target: int = CombatEffect.Target.OPPONENT) -> ApplyStatus:
	var e := ApplyStatus.new()
	e.buff = def
	e.stacks = stacks
	e.target = target
	return e


static func _mark() -> ApplyStatus:
	return _apply(_buff("mark"), 1, CombatEffect.Target.SELF)


static func _opener(effects: Array, costs: Array = []) -> AbilityRule:
	return H._rule(OnBattleStart.new(), Always.new(), effects, costs)


static func _flat(amount: float, target: int = CombatEffect.Target.OPPONENT) -> DealDamage:
	var e := DealDamage.new()
	e.damage_stat = &""
	e.amount = amount
	e.target = target
	return e


static func _change(amount: float) -> ChangeResource:
	var e := ChangeResource.new()
	e.amount = amount
	return e


static func _ctx(side0: Array, side1: Array = [], hp0: float = 100.0, hp1: float = 100.0) -> BattleContext:
	return H._battle(H._spec(hp0, [H._compiled(1, "a", {}, side0)]), H._spec(hp1, [H._compiled(2, "b", {}, side1)]))


static func _marks(ctx: BattleContext, side: int = 0) -> int:
	return ctx.sides[side].stacks_of(&"mark")


static func run_triggers(t: TestCase) -> void:
	t.begin("132 · 时机：来源标签筛、状态掉光时、涨过阈值 / 回满、只在暴击时、加时开始时")

	# --- source_tags：只听带 ranged 的件出手 ---
	var bow := H._compiled(1, "bow", {})
	bow.tags = [&"weapon", &"ranged"] as Array[StringName]
	var knife := H._compiled(2, "knife", {})
	knife.tags = [&"weapon", &"melee"] as Array[StringName]
	var tr := OnItemFired.new()
	tr.source_tags = [&"ranged"] as Array[StringName]
	var quiver := H._compiled(3, "quiver", {}, [H._rule(tr, Always.new(), [_mark()])])
	var ctx := H._battle(H._spec(100.0, [bow, knife, quiver]), H._spec(100.0, []))
	ctx.emit(BattleEvent.ITEM_FIRED, 0, {"uid": 2})
	ctx.drain()
	t.eq(_marks(ctx), 0, "近战出手：不听")
	ctx.emit(BattleEvent.ITEM_FIRED, 0, {"uid": 1})
	ctx.drain()
	t.eq(_marks(ctx), 1, "远程出手：听")
	t.eq(ctx.sides[0].tags_of(1), [&"weapon", &"ranged"] as Array[StringName], "编译结果的标签进了运行时")

	# --- on_status_removed：只在掉光那一次 ---
	var x := _buff("x")
	var gone := OnStatusRemoved.new()
	gone.buff_id = &"x"
	var rm1 := RemoveStatus.new()
	rm1.buff_id = &"x"
	rm1.stacks = 1
	var rm_all := RemoveStatus.new()
	rm_all.buff_id = &"x"
	rm_all.stacks = 0
	ctx = _ctx([_opener([_apply(x, 3, CombatEffect.Target.SELF), rm1]), H._rule(gone, Always.new(), [_mark()])])
	_start(ctx)
	t.eq(_marks(ctx), 0, "三层掉一层：不算掉光")
	ctx = _ctx([_opener([_apply(x, 3, CombatEffect.Target.SELF), rm1, rm_all]), H._rule(gone, Always.new(), [_mark()])])
	_start(ctx)
	t.eq(_marks(ctx), 1, "再清光：触发一次")
	var gone_opp := OnStatusRemoved.new()
	gone_opp.buff_id = &"x"
	gone_opp.on_self = false
	ctx = _ctx([H._rule(gone_opp, Always.new(), [_mark()])], [_opener([_apply(x, 1, CombatEffect.Target.SELF), rm_all])])
	_start(ctx)
	t.eq(_marks(ctx), 1, "on_self = false：对手身上掉光也听得见")

	# --- on_resource_below.direction / full ---
	var above := OnResourceBelow.new()
	above.direction = OnResourceBelow.Direction.ABOVE
	above.percent = 80
	ctx = _ctx([_opener([_change(-60.0)]), H._rule(above, Always.new(), [_mark()])])
	_start(ctx)
	t.eq(_marks(ctx), 0, "掉到 40：不在 80% 以上")
	ctx = _ctx([_opener([_change(-60.0), _change(50.0)]), H._rule(above, Always.new(), [_mark()])])
	_start(ctx)
	t.eq(_hp(ctx, 0), 90, "回到 90")
	t.check(_marks(ctx) > 0, "涨过 80%：触发（状态型：这一刻之后的每次变动都按当前值求值）")
	var full := OnResourceBelow.new()
	full.direction = OnResourceBelow.Direction.ABOVE
	full.full = true
	ctx = _ctx([_opener([_change(-60.0), _change(50.0)]), H._rule(full, Always.new(), [_mark()])])
	_start(ctx)
	t.eq(_marks(ctx), 0, "90 不算回满")
	ctx = _ctx([_opener([_change(-60.0), _change(60.0)]), H._rule(full, Always.new(), [_mark()])])
	_start(ctx)
	t.check(_marks(ctx) > 0, "回满：触发")
	var below := OnResourceBelow.new()
	t.eq(below.direction, OnResourceBelow.Direction.BELOW, "默认还是降到以下，旧内容不变")

	# --- on_damage.crit_only ---
	var crit_hit := OnDamage.new()
	crit_hit.direction = DamageTrigger.Direction.DEALT
	crit_hit.crit_only = true
	var sure := H._compiled(1, "axe", {"damage": 10, "crit_chance": 1.0}, [_opener([DealDamage.new()]), H._rule(crit_hit, Always.new(), [_mark()])])
	ctx = H._battle(H._spec(100.0, [sure]), H._spec(100.0, []))
	_start(ctx)
	t.eq(_marks(ctx), 1, "必暴击的一下：触发")
	var never := H._compiled(1, "axe", {"damage": 10, "crit_chance": 0.0}, [_opener([DealDamage.new()]), H._rule(crit_hit, Always.new(), [_mark()])])
	ctx = H._battle(H._spec(100.0, [never]), H._spec(100.0, []))
	_start(ctx)
	t.check(_hp(ctx, 1) < 100, "打中了")
	t.eq(_marks(ctx), 0, "不暴击：不触发")

	# --- on_overtime：只认第一次 ---
	ctx = _ctx([H._rule(OnOvertime.new(), Always.new(), [_mark()])])
	ctx.emit(BattleEvent.OVERTIME_STACKED, -1, {"count": 1, "percent": 5})
	ctx.drain()
	ctx.emit(BattleEvent.OVERTIME_STACKED, -1, {"count": 2, "percent": 5})
	ctx.drain()
	t.eq(_marks(ctx), 1, "加时开始触发一次，后面的叠层不再触发")


static func run_conditions(t: TestCase) -> void:
	t.begin("132 · 条件：资源 / 轴条件不扣、轴消耗可透支、三个条件型都能取反")
	var hi := ResourceCondition.new()
	hi.min_percent = 50
	var ctx := _ctx([_opener([_mark()], [hi])])
	_start(ctx)
	t.eq(_marks(ctx), 1, "满血 ≥ 50%：放行")
	t.eq(_hp(ctx, 0), 100, "不扣资源")
	var hi_not := ResourceCondition.new()
	hi_not.min_percent = 50
	hi_not.negate = true
	ctx = _ctx([_opener([_mark()], [hi_not])])
	_start(ctx)
	t.eq(_marks(ctx), 0, "取反：满血时不放行")
	var low := ResourceCondition.new()
	low.max_percent = 30
	low.on_self = false
	ctx = _ctx([_opener([_flat(80.0)]), _opener([_mark()], [low])])
	_start(ctx)
	t.eq(_marks(ctx), 1, "对手 20% ≤ 30%：放行")
	t.check(not ResourceCondition.new().has_bounds(), "一个界都没填：has_bounds 为假（导入器拦）")

	var haste := ShiftAxis.new()
	haste.axis = StatAxes.ATTACK_SPEED
	haste.delta = 3
	var need3 := AxisCondition.new()
	need3.axis = StatAxes.ATTACK_SPEED
	need3.stacks = 3
	var slow := AxisCondition.new()
	slow.axis = StatAxes.ATTACK_SPEED
	slow.stacks = -1
	ctx = _ctx([_opener([haste]), _opener([_mark()], [need3]), _opener([_mark()], [slow])])
	_start(ctx)
	t.eq(_marks(ctx), 1, "三层加速：≥ 3 放行；要减速的不放行")
	t.eq(ctx.sides[0].axis_total(StatAxes.ATTACK_SPEED), 3, "轴条件不扣层")

	var pay := AxisCost.new()
	pay.axis = StatAxes.ATTACK_SPEED
	pay.stacks = 5
	ctx = _ctx([_opener([haste]), _opener([_mark()], [pay])])
	_start(ctx)
	t.eq(_marks(ctx), 1, "轴消耗：不查够不够")
	t.eq(ctx.sides[0].axis_total(StatAxes.ATTACK_SPEED), -2, "3 − 5 = −2（透支成减速）")

	var bleed := _buff("bleed")
	var none := StatusCondition.new()
	none.buff_id = &"bleed"
	none.negate = true
	ctx = _ctx([_opener([_mark()], [none])])
	_start(ctx)
	t.eq(_marks(ctx), 1, "对手没有流血：取反放行")
	ctx = _ctx([_opener([_apply(bleed)]), H._rule(_listen_bleed(), Always.new(), [_mark()], [none])])
	_start(ctx)
	t.eq(_marks(ctx), 0, "对手有流血：取反不放行")


static func _listen_bleed() -> OnStatusApplied:
	var tr := OnStatusApplied.new()
	tr.buff_id = &"bleed"
	return tr


static func run_effects(t: TestCase) -> void:
	t.begin("132 · 效果：按生命比例与固定相加、按目标层数乘、按伤害比例回复、清光全部减益、改伤害类型")
	var exe := _flat(5.0)
	exe.percent_of = &"max_hp"
	exe.percent = 10
	var ctx := _ctx([_opener([exe])], [], 100.0, 200.0)
	_start(ctx)
	t.eq(_hp(ctx, 1), 175, "5 + 200 × 10% = 25")

	var miss := DealDamage.new()
	miss.damage_stat = &""
	miss.percent_of = &"missing_hp"
	miss.percent = 50
	ctx = _ctx([_opener([_flat(40.0)]), _opener([miss])])
	_start(ctx)
	t.eq(_hp(ctx, 1), 40, "先掉 40，再打已损生命的一半 20")

	var x := _buff("x", true)
	var per := _flat(2.0)
	per.per_target_stack = &"x"
	ctx = _ctx([_opener([_apply(x, 3), per])])
	_start(ctx)
	t.eq(_hp(ctx, 1), 94, "对手三层：2 × 3 = 6")
	ctx = _ctx([_opener([per])])
	_start(ctx)
	t.eq(_hp(ctx, 1), 100, "零层：不打")

	var leech := ChangeResource.new()
	leech.amount = 0.0
	leech.percent_of_damage = 50
	var dealt := OnDamage.new()
	dealt.direction = DamageTrigger.Direction.DEALT
	ctx = _ctx([_opener([_change(-40.0), _flat(20.0)]), H._rule(dealt, Always.new(), [leech])])
	_start(ctx)
	t.eq(_hp(ctx, 1), 80, "打出 20")
	t.eq(_hp(ctx, 0), 70, "回这一下的一半 10（60 → 70）")
	ctx = _ctx([_opener([_change(-40.0)]), _opener([leech])])
	_start(ctx)
	t.eq(_hp(ctx, 0), 60, "不在受伤后：没有那一包，什么都不回")

	var purge := RemoveStatus.new()
	purge.target = CombatEffect.Target.OPPONENT
	purge.all_debuffs = true
	ctx = _ctx([_opener([_apply(_buff("weak", true)), _apply(_buff("rage")), _apply(_buff("decay", true, true)), purge])])
	_start(ctx)
	t.eq(ctx.sides[1].stacks_of(&"weak"), 0, "减益清掉")
	t.eq(ctx.sides[1].stacks_of(&"rage"), 1, "增益不动")
	t.eq(ctx.sides[1].stacks_of(&"decay"), 1, "系统 buff 不清")
	var strip := RemoveStatus.new()
	strip.target = CombatEffect.Target.OPPONENT
	strip.all_buffs = true
	ctx = _ctx([_opener([_apply(_buff("weak", true)), _apply(_buff("rage")), strip])])
	_start(ctx)
	t.eq(ctx.sides[1].stacks_of(&"rage"), 0, "all_buffs：增益清掉")
	t.eq(ctx.sides[1].stacks_of(&"weak"), 1, "减益不动")

	var to_fire := ConvertDamageType.new()
	to_fire.to = DamageTypes.FIRE
	var taken := OnBeforeDamage.new()
	taken.direction = DamageTrigger.Direction.TAKEN
	var knife := H._compiled(1, "knife", {"damage": 10, "crit_chance": 0.0}, [_opener([DealDamage.new()])])
	ctx = H._battle(H._spec(100.0, [knife]), H._spec(100.0, [H._compiled(2, "ward", {}, [H._rule(taken, Always.new(), [to_fire])])]))
	_start(ctx)
	var hits := ctx.log.filter(func(e): return (e as BattleEvent).name == BattleEvent.DAMAGE)
	t.eq(hits.size(), 1, "一包伤害")
	t.eq((hits[0] as BattleEvent).get_name(&"type"), DamageTypes.FIRE, "换成了火焰")
	t.check((hits[0] as BattleEvent).get_bool(&"direct"), "直接伤害的旗不变")


static func run_receive_rules(t: TestCase) -> void:
	t.begin("132 · 受益格挂规则：每点亮一格挂一份、以本件为来源、来源记邻居")
	var db := ItemDatabase.new()
	db.load_dir()
	var rule := {"trigger": {"type": "on_battle_start"}, "cadence": {"type": "always"},
		"effects": [{"type": "change_resource", "resource_key": "stamina", "amount": 1.0}]}
	var report := ImportReport.new()
	var holder_def := ContentImporter.import_item({"id": "t_totem", "shape": ["1"], "tags": ["part"],
		"adjacency": {"receive_cells": [[-1, 0], [1, 0], [0, 1]], "receive_filter": ["weapon"], "receive_rules": [rule]}},
		ContentImporter.Context.new(), report)
	t.check(report.ok(), "任意时机的受益规则导入无错（%s）" % report.to_text())
	t.check(holder_def.adjacency.has_receive(), "只有规则没有加成也算有受益")

	ItemInstance.reset_uid_counter()
	var g := GridInventory.new(Vector2i(4, 3), 1, false)
	var totem := ItemInstance.create(holder_def)
	t.check(g.place(totem, Vector2i(1, 0), 0), "图腾放下")
	# 小刀的形状不归这里管：只要压在图腾的受益格上
	var on_totem := func(inst: ItemInstance) -> bool: return TestSupport.lights(totem, inst)
	var k1 := TestSupport.put_where(g, db.get_def(&"knife"), on_totem)
	var k2 := TestSupport.put_where(g, db.get_def(&"knife"), on_totem)
	t.check(k1 != null and k2 != null, "两把小刀都挨着图腾")
	if k1 == null or k2 == null:
		return
	var spec := BattleCompiler.compile_board(g)
	var item := spec.item_of(totem.uid)
	t.eq(item.attached.size(), 2, "点亮两格：挂两份")
	t.eq(item.attached[0]["origin"], &"knife", "来源记邻居")
	t.check(item.rules[int(item.attached[0]["rule_index"])].trigger is OnBattleStart, "时机原样（不是只听出手）")
	t.check(spec.item_of(k1.uid).attached.is_empty(), "规则挂在本件身上，不挂邻居")

	var bad := ImportReport.new()
	var costly := rule.duplicate(true)
	costly["costs"] = [{"type": "chance", "percent": 50}]
	ContentImporter.import_item({"id": "t_totem2", "shape": ["1"],
		"adjacency": {"receive_cells": [[1, 0]], "receive_rules": [costly]}}, ContentImporter.Context.new(), bad)
	t.check(not bad.ok() and bad.to_text().contains("不能有消耗"), "受益规则也不许 costs（%s）" % bad.to_text())


static func _import(rule: Dictionary, tags: Array = ["part"]) -> ImportReport:
	var r := ImportReport.new()
	ContentImporter.import_item({"id": "t_x", "shape": ["1"], "tags": tags, "combat": {"rules": [rule]}}, ContentImporter.Context.new(), r)
	return r


static func run_validation(t: TestCase) -> void:
	t.begin("132 · 导入器：三条「配了也没用」的警告与各构件的校验；新构件登记在册")
	for kt in [[&"trigger", &"on_status_removed"], [&"trigger", &"on_overtime"], [&"cost", &"resource_condition"],
			[&"cost", &"axis_condition"], [&"cost", &"axis_cost"], [&"effect", &"convert_damage_type"]]:
		t.check(EffectRegistry.has_type(kt[0], kt[1]), "登记了 %s" % kt[1])
		t.check(FieldText.TYPE_LABELS.has(String(kt[1])), "%s 有中文标签" % kt[1])

	var start := {"type": "on_battle_start"}
	var always := {"type": "always"}
	var r := _import({"trigger": start, "cadence": always, "effects": [{"type": "modify_damage", "percent": 10}]})
	t.check(r.ok() and r.to_text().contains("只在受伤前阶段有效"), "改伤害包的效果不在受伤前：警告（%s）" % r.to_text())
	r = _import({"trigger": start, "cadence": always, "effects": [{"type": "deal_damage", "amount": 3.0, "damage_stat": "", "per_stack": true}]})
	t.check(r.ok() and r.to_text().contains("per_stack"), "道具规则写 per_stack：警告（%s）" % r.to_text())
	r = _import({"trigger": {"type": "on_status_applied", "buff_id": "x"}, "cadence": always,
		"effects": [{"type": "deal_damage", "amount": 3.0, "damage_stat": "", "per_stack": true}]})
	t.check(r.ok() and not r.to_text().contains("per_stack"), "「施加时」读得到层数：不警告")
	r = _import({"trigger": {"type": "on_schedule"}, "cadence": always, "effects": [{"type": "deal_damage"}]}, ["weapon"])
	t.check(r.ok() and r.to_text().contains("自发配「每次都行」"), "自发配 always：警告（%s）" % r.to_text())
	r = _import({"trigger": start, "cadence": always, "effects": [{"type": "change_resource", "amount": 0.0, "percent_of_damage": 50}]})
	t.check(r.ok() and r.to_text().contains("按伤害比例回复"), "按伤害比例回复不在受伤后：警告")
	r = _import({"trigger": {"type": "on_damage", "direction": "TAKEN", "crit_only": true}, "cadence": always, "effects": [{"type": "change_resource"}]})
	t.check(r.ok() and r.to_text().contains("只在暴击时"), "暴击配受到：警告")

	r = _import({"trigger": start, "cadence": always, "effects": [{"type": "deal_damage", "percent_of": "max_hp"}]})
	t.check(not r.ok(), "比例伤害没填比例：拦（%s）" % r.to_text())
	r = _import({"trigger": start, "cadence": always, "costs": [{"type": "resource_condition"}], "effects": [{"type": "change_resource"}]})
	t.check(not r.ok() and r.to_text().contains("一个界都没填"), "资源条件没界：拦")
	r = _import({"trigger": start, "cadence": always, "costs": [{"type": "axis_condition", "axis": "nope"}], "effects": [{"type": "change_resource"}]})
	t.check(not r.ok() and r.to_text().contains("没有这条标准轴"), "轴不存在：拦")
	var before := {"type": "on_before_damage"}
	r = _import({"trigger": before, "cadence": always, "effects": [{"type": "convert_damage_type", "to": "poison"}]})
	t.check(not r.ok() and r.to_text().contains("只由 buff 造成"), "改成毒：拦")
	r = _import({"trigger": before, "cadence": always, "effects": [{"type": "convert_damage_type", "to": "nope"}]})
	t.check(not r.ok(), "改成不存在的类型：拦")
	r = _import({"trigger": before, "cadence": always, "effects": [{"type": "convert_damage_type", "to": "fire"}]})
	t.check(r.ok() and r.warnings.is_empty(), "改成火焰、在受伤前：干净（%s）" % r.to_text())

	var letter = JSON.parse_string(FileAccess.get_file_as_string("res://data/authoring/items/bloodletter.json"))
	var lr := ImportReport.new()
	var ldef := ContentImporter.import_item(letter, ContentImporter.Context.new(), lr)
	t.check(lr.ok(), "放血刀导入无错")
	var dd := (ldef.combat.rules[1] as AbilityRule).effects[0] as DealDamage
	t.eq(dd.per_target_stack, &"bleed", "放血刀改成按目标流血层数")
	t.eq(dd.amount, 3.0, "每层 3 点")
