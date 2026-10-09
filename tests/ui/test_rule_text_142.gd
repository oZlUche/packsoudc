## 142（作者定）：规则行全部由字段生成 —— 扳机、条件 / 消耗、效果各自 describe()，不写死时机名；道具里不出现英文 id
extends RefCounted


static func _lines(def: ItemDef) -> String:
	var bits: Array[String] = []
	if def.combat != null:
		for r in def.combat.rules:
			bits.append(Glossary.rule_text(r, true))
	return " / ".join(bits)


static func run_six_items(t: TestCase) -> void:
	t.begin("142 · 六件流血 / 中毒道具：谁施加、施加给谁、几层、方向、条件都写出来")
	var c := TestSupport.load_content()
	var want := {
		&"bloodhound_sigil": "[你给对手施加流血时] 强攻 1 层",
		&"bloodlust_bracer": "[你给对手施加流血时] 获得嗜血",
		&"festering_blade": "[每 1.4 秒] 造成物理伤害，施加流血 / [你给对手施加流血时] 施加中毒",
		&"bloodletter": "[每 1.1 秒] 造成物理伤害，施加流血 / [对手的流血达到 6 层时] 对手每层流血造成 3 点物理伤害，清掉对手全部流血",
		&"wound_salt": "[造成物理伤害前] 若对手有流血，伤害 +20%",
		&"viper_gland": "[你给对手施加中毒时] 中毒转为剧毒",
	}
	for id in want:
		var def := c.items.get_def(id)
		t.check(def != null, "%s 在库里" % id)
		if def != null:
			t.eq(_lines(def), want[id], "%s 的规则行" % Names.of(def))


static func run_triggers_from_fields(t: TestCase) -> void:
	t.begin("142 · 扳机按字段说：状态施加 / 掉光 / 层数、伤害方向与类型、资源、出手")
	var a := OnStatusApplied.new()
	a.buff_id = &"poison"
	t.eq(a.describe(), "你给对手施加中毒时", "默认：你施加给对手")
	a.on_self = true
	a.by_self = false
	t.eq(a.describe(), "你被施加中毒时", "自己身上、不认施加者")
	a.on_self = false
	t.eq(a.describe(), "对手被施加中毒时", "对手身上、不认施加者")
	var r := OnStatusRemoved.new()
	r.buff_id = &"bleed"
	t.eq(r.describe(), "你的流血掉光时", "掉光：默认自己")
	var s := OnStacksAtLeast.new()
	s.buff_id = &"bleed"
	s.stacks = 4
	s.on_self = false
	s.consume = true
	t.eq(s.describe(), "对手的流血达到 4 层时（消耗这 4 层）", "层数够：谁的、几层、消不消耗")
	var b := OnBeforeDamage.new()
	t.eq(b.describe(), "受到攻击前", "受伤前：类型留空 = 攻击")
	b.direction = DamageTrigger.Direction.DEALT
	b.damage_type = &"physical"
	t.eq(b.describe(), "造成物理伤害前", "造成伤害前：方向和类型从字段来")
	var d := OnDamage.new()
	d.min_amount = 5.0
	t.eq(d.describe(), "受到攻击时（单次至少 5 点）", "受伤时：门槛写出来")
	d.min_amount = 0.0
	d.crit_only = true
	t.eq(d.describe(), "受到暴击时", "只认暴击")
	var low := OnResourceBelow.new()
	t.eq(low.describe(), "你的生命低于 30% 时", "资源低于")
	low.full = true
	low.direction = OnResourceBelow.Direction.ABOVE
	t.eq(low.describe(), "你的生命回满时", "回满")
	var f := OnItemFired.new()
	t.eq(f.describe(), "你的其他道具出手时", "出手：默认自己这边的其他道具")
	f.same_side = false
	t.eq(f.describe(), "对手出手时", "听对手")
	f.same_side = true
	f.source = OnItemFired.Source.LINKED
	t.eq(f.describe(), "相连的道具出手时", "只听连结的")
	t.eq(OnBattleStart.new().describe(), "开战时", "开战")


static func run_costs_from_fields(t: TestCase) -> void:
	t.begin("142 · 条件 / 消耗按字段说，扣层不重复写；耐力在悬浮窗另写时不重复")
	var sc := StatusCondition.new()
	sc.buff_id = &"bleed"
	t.eq(sc.describe(), "若对手有流血", "状态条件")
	sc.stacks = 3
	t.eq(sc.describe(), "若对手流血至少 3 层", "至少几层")
	sc.stacks = 1
	sc.negate = true
	t.eq(sc.describe(), "若对手没有流血", "取反")
	var st := StatusStackCost.new()
	st.buff_id = &"poison"
	st.stacks = 2
	t.eq(st.describe(), "消耗你 2 层中毒", "扣层")
	var ch := ChanceCondition.new()
	ch.percent = 30
	t.eq(ch.describe(), "30% 几率", "几率")
	var u := UsesCost.new()
	t.eq(u.describe(), "每场最多 1 次", "次数")
	var rc := ResourceCost.new()
	rc.amount = 5.0
	t.eq(rc.describe(), "消耗 5 耐力", "资源消耗")
	var rule := AbilityRule.new()
	rule.trigger = OnSchedule.new()
	var cd := CooldownCadence.new()
	cd.seconds = 1.0
	rule.cadence = cd
	rule.costs = [rc, ch] as Array[Cost]
	var dmg := DealDamage.new()
	rule.effects = [dmg] as Array[CombatEffect]
	t.eq(Glossary.rule_text(rule), "[每 1.0 秒] 消耗 5 耐力，30% 几率，造成物理伤害", "规则行：频率、条件、效果")
	t.eq(Glossary.rule_text(rule, true), "[每 1.0 秒] 30% 几率，造成物理伤害", "悬浮窗另写耐力：不重复")
	var sa := OnStacksAtLeast.new()
	sa.buff_id = &"bleed"
	sa.consume = true
	rule.trigger = sa
	rule.costs = [] as Array[Cost]
	t.eq(Glossary.rule_text(rule), "[你的流血达到 3 层时（消耗这 3 层）] 每 1.0 秒最多一次，造成物理伤害", "扳机隐含的扣层不再当条件写一遍；非自发的冷却写成「最多一次」")


static func run_no_ids_in_items(t: TestCase) -> void:
	t.begin("142 · 所有道具的规则行（自己的、信力加成、给邻居附加的）里没有英文 id")
	var c := TestSupport.load_content()
	var ascii := RegEx.create_from_string("[A-Za-z_]{3,}")
	var bad: Array[String] = []
	for id in c.items.all_ids():
		var def := c.items.get_def(id)
		var rules: Array = []
		if def.combat != null:
			rules.append_array(def.combat.rules)
		for fb in def.faith_bonuses:
			if fb != null:
				rules.append_array(fb.rules)
		if def.adjacency != null:
			rules.append_array(def.adjacency.grant_rules)
		for r in rules:
			var line := Glossary.rule_text(r as AbilityRule)
			if ascii.search(line) != null:
				bad.append("%s：%s" % [def.id, line])
	t.check(bad.is_empty(), "没有英文 id：%s" % "；".join(bad))
