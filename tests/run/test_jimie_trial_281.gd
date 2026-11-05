## 281 寂灭的路（二）：开局带全黑法杖 —— 图上一个事件点换成单元素试炼；敌人只受那一种伤害；打赢给元素之核
extends RefCounted

const H := preload("res://tests/battle/test_effect_system.gd")
const P := preload("res://tests/battle/test_damage_pipeline.gd")


static func _run(chapter := "free_mode", runs := 50, seed_value := 7) -> RunState:
	var c := TestSupport.load_content(chapter, ["buffs"])
	var layout := [{"id": "war_pack", "origin": [0, 0], "rot": 0}, {"id": "magic_staff", "origin": [0, 0], "rot": 0, "state": {ItemInstance.RUNS_KEY: runs}}]
	var run := RunState.start(c.chapter, seed_value, c.items, c.enemies, c.sets, [] as Array[StringName], c.buffs, [] as Array[StringName], null, layout)
	run.meta = MetaState.new()
	return run


static func _foe(only: StringName, stats: Dictionary = {}, before: AbilityRule = null) -> CombatantSpec:
	var s := P._defender(stats, before)
	s.only_damage_type = only
	return s


static func _hit_once(attacker: CombatantSpec, foe: CombatantSpec) -> BattleContext:
	var ctx := H._battle(attacker, foe)
	P._run(ctx)
	return ctx


static func run_gate(t: TestCase) -> void:
	t.begin("281 · 试炼的敌人只受一种伤害：别的类型、真实伤害都减 100%；不对的那一下不扣护甲；改成对的类型照样吃")
	DamageTypes.reset_to_builtins()
	t.eq(P._hp(_hit_once(P._attacker(20.0, DamageTypes.FIRE), _foe(DamageTypes.FIRE)), 1), 80, "火：照常 20")
	t.eq(P._hp(_hit_once(P._attacker(20.0), _foe(DamageTypes.FIRE)), 1), 100, "物理：0")
	t.eq(P._hp(_hit_once(P._attacker(20.0, DamageTypes.LIGHTNING), _foe(DamageTypes.FIRE)), 1), 100, "雷：0")
	t.eq(P._hp(_hit_once(P._attacker(20.0, DamageTypes.BLEED), _foe(DamageTypes.FIRE)), 1), 100, "流血（真实）：0")
	var pure := P._attacker(20.0, DamageTypes.FIRE)
	((pure.items[0] as CompiledItem).rules[0].effects[0] as DealDamage).pure = true
	t.eq(P._hp(_hit_once(pure, _foe(DamageTypes.FIRE)), 1), 100, "火的真实伤害：也是 0")
	var armored := _hit_once(P._attacker(20.0), _foe(DamageTypes.FIRE, {"max_armor": 30.0}))
	t.eq(P._shield(armored, 1), 30, "物理：护甲不动")
	var conv := ConvertDamageType.new()
	conv.to = DamageTypes.FIRE
	t.eq(P._hp(_hit_once(P._attacker(20.0), _foe(DamageTypes.FIRE, {}, P._before_rule(conv))), 1), 80, "物理改成火：吃")
	t.eq(P._hp(_hit_once(P._attacker(20.0), P._defender()), 1), 80, "不是试炼：物理照常")


static func run_plant(t: TestCase) -> void:
	t.begin("281 · 开局：全黑法杖 + 配了元素的图 + 那颗核哪儿都没有 → 恰好一个事件点换成试炼（最高档、输了不掉体力、只受该元素）")
	var run := _run()
	var id := JimiePath.plant(run)
	t.check(id >= 0, "魔法废墟：埋了")
	if id < 0:
		return
	var node := run.map.get_node(id)
	t.eq(node.type, &"event", "是事件点")
	t.eq(String(node.content["event"]), String(JimiePath.EVENT), "事件换成试炼")
	var ev: EventDef = EventPlacer.load_all().get(JimiePath.EVENT, null)
	t.check(ev != null and ev.title != "", "事件有标题（不显示 id）")
	var tiers := run.pool.strengths()
	t.eq(int(node.content.get("strength", -1)), tiers[tiers.size() - 1], "最高档")
	t.eq(run.events.loss_cost_for(&"battle", node.content), 0, "输了不掉体力")
	t.eq(String(node.content[JimiePath.ONLY_KEY]), "fire", "魔法废墟 = 火")
	t.eq(String(node.content[JimiePath.REWARD_KEY]), "jimie_core_fire", "打赢给火之核")
	var spec := EnemyKit.spec_of(node.content, run.enemies, run.pool, run.items)
	t.eq(spec.only_damage_type, DamageTypes.FIRE, "编译出来只受火")
	var trials := 0
	for nid in run.map.node_ids():
		if String(run.map.get_node(nid).content.get("event", "")) == String(JimiePath.EVENT):
			trials += 1
	t.eq(trials, 1, "只有一个")
	t.eq(JimiePath.plant(_run()), id, "同一个种子同一个点")

	var hg := _run("clockwork_hourglass")
	var hid := JimiePath.plant(hg)
	t.check(hid >= 0 and String(hg.map.get_node(hid).content[JimiePath.ONLY_KEY]) == "lightning", "机关沙漏 = 雷")
	t.eq(JimiePath.plant(_run("free_mode", 49)), -1, "49 次的法杖：不埋")
	t.eq(JimiePath.plant(_run("prologue_3")), -1, "没配元素的图：不埋")
	var owned := _run()
	owned.meta.warehouse.try_add(ItemInstance.create(owned.items.get_def(&"jimie_core_fire")), true)
	t.eq(JimiePath.plant(owned), -1, "仓库里有火之核：不埋")


static func run_reward(t: TestCase) -> void:
	t.begin("281 · 元素之核：1×1、独一、不能卖、不进随机池；试炼打赢了进尸体，已经有了就不给")
	var run := _run()
	for el in JimiePath.CORES:
		var d := run.items.get_def(JimiePath.CORES[el])
		t.check(d != null and d.is_unique() and d.cell_count() == 1 and d.tags.has(&"material"), "%s：1×1 独一的材料" % el)
		if d == null:
			continue
		t.check(not run.items.ids().has(d.id), "%s：不进随机池" % el)
		var meta := MetaState.new()
		var inst := ItemInstance.create(d)
		meta.warehouse.try_add(inst, true)
		t.eq(meta.sell_item(inst.uid), -1, "%s：不能卖" % el)
	var id := JimiePath.plant(run)
	if id < 0:
		t.check(false, "没埋上")
		return
	var content: Dictionary = run.map.get_node(id).content
	var rolled := {"dropped": [] as Array[StringName], "treasure": [] as Array[StringName]}
	t.check(JimiePath.reward(content, run, rolled), "打赢了：给")
	t.check(DropResolver.corpse_of(content, rolled, run.items).items().any(func(i: ItemInstance) -> bool: return i.def.id == &"jimie_core_fire"), "进了尸体")
	run.meta.warehouse.try_add(ItemInstance.create(run.items.get_def(&"jimie_core_fire")), true)
	var again := {"dropped": [] as Array[StringName], "treasure": [] as Array[StringName]}
	t.check(not JimiePath.reward(content, run, again), "已经有了：不给")
	t.check(not JimiePath.reward({}, run, again), "不是试炼：不给")


static func run_log(t: TestCase) -> void:
	t.begin("281 · 战记：被化解的持续伤害一跳和直击同一个说法（「被化解」），不写 0 伤害")
	const N := preload("res://tests/battle/test_battle_narrator_272.gd")
	var r := BattleResult.new()
	r.winner = 0
	r.duration = StatMath.from_float(2.0)
	r.log = [
		N._ev(BattleEvent.BATTLE_START, 0.0, -1),
		N._hit(1.0, 1, 1, 0, 3, 0, {"type": "bleed", "pure": true, "cancelled": true, "direct": false}),
		N._ev(BattleEvent.BATTLE_END, 2.0, -1, {"winner": 0}),
	]
	var text := "\n".join(BattleNarrator.lines(r, ["A", "B"], [{}, {}], [{}, {}]).map(func(l): return BattleNarrator.plain(l)))
	t.check(text.contains("化解") and not text.contains("受到 0"), "写化解（%s）" % text.replace("\n", " / "))
