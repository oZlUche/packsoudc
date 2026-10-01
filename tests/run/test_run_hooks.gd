## 一局的能力表 [RunHooks]（101 第 3 刀）：原来 [NodeEvents] 与 [EventContext] 各挂十几个裸 `Callable`，
## 现在收成带类型的方法 + 一张名字登记表。守三件事：
##
## - **没人接也能跑**：默认那一份每条都有确定的默认值（沙盒、测试、没装那个模块的一局都靠它）。
## - **名字写错当场报错**：`register` 只认 [constant RunHooks.NAMES] 里的名字 —— 这正是裸字段抓不到的那类错。
## - **该接的都接上了**：骨架接自己的几条，模块与机制在 `install` 里接自己的；`NodeEvents` 不认识任何模块。
extends RefCounted

const Support := preload("res://tests/support.gd")


static func _content() -> Dictionary:
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	return {"items": items, "enemies": enemies, "sets": sets,
		"chapter": load(ContentPaths.asset_file("chapters", "chapter_01")) as ChapterDef}


static func run_defaults(t: TestCase) -> void:
	t.begin("能力表 · 没人接时的默认值（101 第 3 刀）：每条都有确定的答案，所以沙盒与测试不接也能跑")
	var hooks := RunHooks.new()
	for name in RunHooks.NAMES:
		t.check(hooks.has_method(String(name)), "每个登记的名字都有同名的带类型方法：%s" % name)
		t.check(not hooks.has(name), "默认没人接：%s" % name)
	t.check(hooks.safe_open(), "没装保险箱模块：保险箱点照旧能开（老路）")
	t.eq(hooks.bracket(), -1, "没有猎手机制：段位 -1")
	t.eq(hooks.faith_tier(), -1, "没激活信仰：-1 阶")
	t.eq(hooks.active_faith_id(), &"", "没激活信仰：id 空")
	t.is_null(hooks.player_spec(), "没人编译玩家：null（节点事件据此不开打）")
	t.is_null(hooks.loot_context(), "没人给掉落上下文：null（节点事件自己造一个只带难度的）")
	t.is_null(hooks.run_context(), "没人给一局的规则：null（节点事件用默认的）")
	t.check(not hooks.request_extract(), "没人接撤离：撤不了")
	t.check(not hooks.relocate(MoveIntent.teleport(0, 1, 0)), "没人接传送：节点事件自己交给旅程")
	t.check(not hooks.grant_map_buff(&"hardy") and not hooks.remove_map_buff(&"hardy") and not hooks.has_map_buff(&"hardy"),
		"没装 buff 模块：给不了、去不掉、也查不到地图 buff")
	t.check(not hooks.has_buff_tag(&"marked"), "没有 buff 标签")
	t.check(not hooks.fight_hunter(null, 0, null) and not hooks.flee_hunter(null, 0, null), "没有猎手：迎战 / 逃跑都不会发生")
	var ids: Array[StringName] = [&"shortsword"]
	t.eq(hooks.bless_substitute(ids, 1.0, 1.0, null), ids, "没装神坛模块：掉落原样，不换成赐福版")
	hooks.before_battle(null, null, &"battle")
	t.check(true, "没人接 before_battle：调了也不炸")


static func run_register(t: TestCase) -> void:
	t.begin("能力表 · 接与不接：名字只认登记过的（写错当场报错、不会默默不生效）；接上一个无效的 Callable = 取消")
	var hooks := RunHooks.new()
	hooks.register(&"safe_open", func() -> bool: return false)
	t.check(hooks.has(&"safe_open") and not hooks.safe_open(), "接上了：保险箱说不能开")
	hooks.register(&"safe_open", Callable())
	t.check(not hooks.has(&"safe_open") and hooks.safe_open(), "接一个无效的 = 取消，回到默认值")
	hooks.register(&"saef_open", func() -> bool: return false)     # 故意写错（会打一条 push_error）
	t.check(not hooks.has(&"saef_open"), "名字不在登记表里：没接上")
	t.check(hooks.safe_open(), "写错名字不会误接到别条上")
	# 带参数的那几条，参数原样传过去
	var seen: Array = []
	hooks.register(&"grant_map_buff", func(id: StringName) -> bool:
		seen.append(id)
		return true)
	t.check(hooks.grant_map_buff(&"hardy") and seen == [&"hardy"], "参数原样传给接的人")
	hooks.register(&"bless_substitute", func(ids: Array, a: float, b: float, _rng: RandomNumberGenerator) -> Array:
		return [a, b] + ids)
	t.eq(hooks.bless_substitute([&"x"], 0.25, 0.5, null), [0.25, 0.5, &"x"], "四个参数都到了")


static func run_wired_in_a_run(t: TestCase) -> void:
	t.begin("能力表 · 一局里谁接了什么（101 第 3 刀）：骨架接自己的几条，模块与机制在 install 里接自己的；节点事件只认这张表")
	var c := _content()
	var run: RunState = null
	for seed in range(1, 40):
		run = RunState.start(c["chapter"], seed, c["items"], c["enemies"], c["sets"])
		if run != null:
			break
	if run == null:
		t.check(false, "开局")
		return
	t.check(run.events != null and run.events.hooks == run.hooks, "节点事件用的就是这一局的那张表（同一个对象）")
	for name in [&"player_spec", &"loot_context", &"run_context", &"has_buff_tag", &"bracket", &"relocate", &"request_extract",
			&"faith_tier", &"active_faith_id", &"before_battle"]:
		t.check(run.hooks.has(name), "骨架接了 %s" % name)
	for pair in [[&"safe_open", "保险箱"], [&"grant_map_buff", "一局的 buff"], [&"remove_map_buff", "一局的 buff"],
			[&"has_map_buff", "一局的 buff"], [&"bless_substitute", "神坛"]]:
		t.check(run.hooks.has(pair[0] as StringName), "%s 模块接了 %s" % [pair[1], pair[0]])
	t.not_null(run.hooks.player_spec(), "问得出玩家的战斗单位")
	t.not_null(run.hooks.loot_context(), "问得出掉落上下文")
	t.not_null(run.hooks.run_context(), "问得出一局的规则")
	t.check(run.hooks.safe_open(), "开局保险箱没锁：能开")
	# 事件的条件与后果也只认这张表（EventContext.hooks）
	var ctx := EventContext.new()
	t.eq(ctx.bracket_now(), -1, "空上下文：段位 -1")
	t.eq(ctx.faith_tier_now(), -1, "空上下文：没信仰")
	t.eq(ctx.active_faith_id(), &"", "空上下文：没激活信仰")
	t.check(not ctx.tag_present(&"marked") and not ctx.buff_present(&"hardy"), "空上下文：标签与 buff 都查不到")
	ctx.hooks = run.hooks
	t.eq(ctx.faith_tier_now(), run.active_faith_tier(), "接上一局的表：信仰阶和一局一致")
	# 裸 Callable 字段真的没了（防回头：加回一个字段，两边各接一份，就又分叉了）
	var gone := [&"player_spec", &"loot_context", &"run_context", &"safe_open", &"faith_tier", &"active_faith_id",
		&"bless_substitute", &"grant_map_buff", &"remove_map_buff", &"has_map_buff", &"has_buff_tag",
		&"fight_hunter", &"flee_hunter", &"bracket_of", &"request_extract", &"relocate", &"before_battle"]
	var ev_props: Array[StringName] = []
	for p in run.events.get_property_list():
		ev_props.append(StringName(String(p["name"])))
	for name in gone:
		t.check(not ev_props.has(name), "NodeEvents 上没有裸 Callable 字段 %s 了" % name)
	var ctx_props: Array[StringName] = []
	for p in ctx.get_property_list():
		ctx_props.append(StringName(String(p["name"])))
	for name in [&"grant_map_buff", &"remove_map_buff", &"has_map_buff", &"has_buff_tag", &"faith_tier", &"active_faith", &"bracket"]:
		t.check(not ctx_props.has(name), "EventContext 上没有裸 Callable 字段 %s 了" % name)
