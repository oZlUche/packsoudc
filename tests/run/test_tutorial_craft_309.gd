## 报告 309（v5.85 体验整改 E01）：序章的教学供给不换成赐福版；守卫门口的退路按「凑不凑得齐配方」判，不再说「没有匕首」
extends RefCounted


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("prologue", ["events", "node_rules"])


static func _put(s: RunState, c: TestSupport.Content, id: StringName, locked: bool = false) -> ItemInstance:
	var inst := ItemInstance.create(c.items.get_def(id), 0)
	s.storage.admit(inst)
	if locked:
		inst.set_locked(true)
	return inst


static func run_guaranteed_drop_stays_plain(t: TestCase) -> void:
	t.begin("309 · 序章第一战必掉的匕首不被换成赐福版（赐福概率拉到 1 也一样）；不是必掉的照旧换")
	var c := _content()
	var s := RunState.start(c.chapter, 71888, c.items, c.enemies, c.sets)
	t.not_null(s, "序章开得出来")
	if s == null:
		return
	t.check(s.hooks.has(&"bless_substitute"), "序章装着赐福替代（祭坛模块）")
	s.faith_defs = FaithDef.load_all()     # 正式开局由 GameFlow 填
	var rule := s.events.drop_rule.duplicate() as DropRule
	rule.bless_chance = 1.0
	rule.bless_chance_active = 1.0
	s.events.drop_rule = rule
	var node := MapNode.new()
	node.content = {"guaranteed_drops": ["knife"]}
	node.content_seed = 3
	var rolled := {"dropped": [&"knife"] as Array[StringName]}
	s.events._bless_rolled(node, rolled)
	t.eq(rolled["dropped"], [&"knife"] as Array[StringName], "必掉的匕首原样")
	var free := MapNode.new()
	free.content_seed = 3
	var rolled2 := {"dropped": [&"knife"] as Array[StringName]}
	s.events._bless_rolled(free, rolled2)
	t.check((rolled2["dropped"] as Array)[0] != &"knife", "随机掉的匕首照旧换成赐福版：%s" % [rolled2["dropped"]])
	s.dispose()


static func run_recipe_ready(t: TestCase) -> void:
	t.begin("309 / 312 · recipe_ready：匕首（普通或赐福）+ 毒药就算凑齐、锁着的不算；守卫的退路只在凑不齐、也没有成品（含赐福版）时出现")
	var c := _content()
	var s := RunState.start(c.chapter, 71888, c.items, c.enemies, c.sets)
	if s == null:
		return
	for inst in s.board.items().duplicate():
		s.board.remove((inst as ItemInstance).uid)
	for inst in s.storage.items().duplicate():
		s.storage.remove((inst as ItemInstance).uid)
	var ctx := EventContext.new()
	ctx.board = s.board
	ctx.storage = s.storage
	var cond := RecipeReady.new()
	cond.recipe = &"poisoned_knife"
	t.not_null(c.items.get_def(&"knife_brute"), "库里有赐福匕首 knife_brute")
	var kb := _put(s, c, &"knife_brute", true)
	_put(s, c, &"poison_vial")
	t.check(not cond.check(ctx), "赐福匕首锁着：凑不齐")
	kb.set_locked(false)
	t.check(cond.check(ctx), "312：赐福匕首 + 毒药：凑齐了（按原件认）")
	s.storage.remove(kb.uid)
	var k := _put(s, c, &"knife", true)
	t.check(not cond.check(ctx), "普通匕首锁着：凑不齐")
	k.set_locked(false)
	t.check(cond.check(ctx), "普通匕首 + 毒药：凑齐了")
	var def: EventDef = c.events.get(&"tut_elite", null)
	t.not_null(def, "守卫事件在")
	if def == null:
		return
	var back := def.options[1] as EventOption
	t.check(not back.label.contains("{item:knife}"), "退路不再说「没有匕首」")
	t.eq(back.locked_reason(ctx) != "", true, "凑得齐时退路藏着（要先合成）")
	s.storage.remove(k.uid)
	t.eq(back.locked_reason(ctx), "", "只有毒药时退路出现")
	_put(s, c, &"poisoned_knife_brute")
	t.check(back.locked_reason(ctx) != "", "312：有赐福成品时退路藏着，走正门")
	t.eq((def.options[0] as EventOption).locked_reason(ctx), "", "赐福成品：正门开着")
	s.dispose()
