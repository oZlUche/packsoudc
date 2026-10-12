## 宝箱节点（154，作者定）：类型登记、生成时定稀有度、长按开锁的状态机、开锁后只搜一次的会话、没开锁走开不算用过、
## 存档中途读回、开锁画面（占位绘制）按住走满弹出搜索界面。
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func run_types(t: TestCase) -> void:
	t.begin("宝箱 · 类型登记（154）：类型表、样式、地图文字 C、浮窗类别、名字、随机点能揭出、字段标签、内容种类")
	t.check(MapNodeTypes.has(&"chest"), "类型表里有 chest")
	t.eq(MapNodeStyle.of(&"chest")["label"], "宝箱", "样式的名字")
	t.eq(MapGridText.SYMBOL_TYPES.get("C", &""), &"chest", "地图文字里 C = 宝箱")
	t.eq(NodeText.label_of(&"chest"), "宝箱", "节点名字")
	t.check(NodeTooltip.DEFAULTS.has("chest"), "浮窗有默认文字")
	t.check(NodeRules.RANDOM_ALLOWED.has(&"chest"), "随机点能揭出宝箱（待定 4 = A）")
	t.check(ContentPaths.KINDS.has("chest_skins") and ContentPaths.ORDER.has("chest_skins"), "内容种类 chest_skins")
	t.check(ContentPaths.ORDER.find("chest_skins") < ContentPaths.ORDER.find("chapters"), "皮肤先于章节导入（章节按 id 引用）")
	var skin := ContentPaths.load_asset("chest_skins", "ruins")
	t.check(skin is ChestSkinDef and (skin as ChestSkinDef).display_name == "废墟", "废墟皮肤导进来了")
	t.eq(FieldText.LABELS.get("hold_seconds"), "开锁要按几秒", "字段标签")
	t.eq(FieldText.LABELS.get("ChestSkinDef.closed"), "闭箱图（按稀有度）", "按类的字段标签")
	t.eq(FieldText.CLASS_LABELS.get("ChestRules"), "宝箱规则", "类名标签")
	t.eq(ChapterDef.new().chest_skin, &"ruins", "章节默认废墟皮肤")


static func run_rules(t: TestCase) -> void:
	t.begin("宝箱 · 规则（154）：按档位的稀有度权重生效、高危区加一档、按住秒数随稀有度变长、出件与下限（宝箱稀有度 − 1，前两档 0）")
	var r := ChestRules.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 154
	var max0 := 0
	var min2 := 5
	var min_danger := 5
	for i in 600:
		max0 = maxi(max0, r.roll_rarity(0, 0, rng))
		min2 = mini(min2, r.roll_rarity(2, 0, rng))
		min_danger = mini(min_danger, r.roll_rarity(2, 2, rng))
	t.check(max0 <= 2, "档位 0 最多到 2（%d）" % max0)
	t.check(min2 >= 1, "档位 2 不出 0（%d）" % min2)
	t.check(min_danger >= 2, "高危区再加一档（%d）" % min_danger)
	t.eq(r.roll_rarity(9, 0, rng) >= 1, true, "超出表长按最后一行")
	for k in 5:
		t.check(r.hold_time(k + 1) > r.hold_time(k), "稀有度 %d 比 %d 按得久" % [k + 1, k])
	t.eq(r.hold_time(99), r.hold_time(5), "超出按最后一项")
	t.eq(r.hold_time(0), 1.0, "普通一秒（155）")
	t.eq(r.hold_time(5), 3.0, "神话三秒：最长不超过三秒（155，作者定）")
	t.eq([r.floor_of(0), r.floor_of(1), r.floor_of(2), r.floor_of(5)], [0, 0, 1, 4], "下限 = 稀有度 − 1，前两档 0")
	t.eq(r.item_range(0), Vector2i(2, 3), "普通箱 2～3 件")


static func run_placement(t: TestCase) -> void:
	t.begin("宝箱 · 生成（154）：自由模式的图上有宝箱点，每个都定好了稀有度（0～5）与皮肤；同一张图每次一样；已经定了的不动")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var chests := 0
	for seed in range(1, 13):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit.items)
		if s == null:
			continue
		var again := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit.items)
		for id in s.map.node_ids():
			var node := s.map.get_node(id)
			if node.type != &"chest":
				continue
			chests += 1
			var chest := ChestPlacer.chest_of(node)
			t.check(chest.has("rarity") and int(chest["rarity"]) >= 0 and int(chest["rarity"]) <= 5, "种子 %d 点 %d：稀有度 %s" % [seed, id, str(chest.get("rarity"))])
			t.eq(ChestPlacer.skin_of(node), &"ruins", "皮肤跟章节")
			t.check(not ChestPlacer.is_opened(node), "还没开")
			if again != null:
				t.eq(ChestPlacer.rarity_of(again.map.get_node(id)), ChestPlacer.rarity_of(node), "同一张图每次一样")
	t.check(chests > 0, "十二张图里有宝箱点（%d 个）" % chests)
	var n := MapNode.new()
	n.type = &"chest"
	n.content[ChestPlacer.KEY] = {"rarity": 4, "skin": "ruins"}
	t.check(not ChestPlacer.roll_one(n, null, &"ruins"), "已经定了的不动")
	t.eq(ChestPlacer.rarity_of(n), 4, "稀有度还是 4")
	var blank := MapNode.new()
	blank.type = &"chest"
	t.check(ChestPlacer.roll_one(blank, null, &""), "没规则也能定（默认规则）")
	t.eq(ChestPlacer.skin_of(blank), &"ruins", "没皮肤按废墟")


static func run_lock_hold(t: TestCase) -> void:
	t.begin("宝箱 · 长按开锁（154）：按住走、松手二倍速回退、再按接着走、走满只发一次、按着不能走开")
	var h := LockHold.new(2.0, 2.0)
	var fired := [0]
	h.unlocked.connect(func(): fired[0] += 1)
	t.check(h.can_leave(), "没按能走")
	t.check(h.press() and h.is_holding(), "按下")
	t.check(not h.press(), "再按不重复")
	t.check(not h.can_leave(), "按着不能走")
	h.advance(1.0)
	t.check(absf(h.progress - 0.5) < 0.0001, "按 1 秒走一半")
	t.check(h.release() and h.state == LockHold.State.RELEASING, "松手回退")
	t.check(h.can_leave(), "回退中能走")
	h.advance(0.25)
	t.check(absf(h.progress - 0.25) < 0.0001, "二倍速回退：0.25 秒退 0.25")
	h.press()
	h.advance(0.5)
	t.check(absf(h.progress - 0.5) < 0.0001, "再按接着走")
	h.release()
	h.advance(5.0)
	t.eq(h.progress, 0.0, "退到底")
	t.eq(h.state, LockHold.State.IDLE, "回到没按")
	h.press()
	t.check(not h.advance(1.9), "没满")
	t.check(h.advance(0.2), "走满")
	t.check(h.is_unlocked() and h.progress == 1.0, "开了")
	t.check(not h.advance(1.0) and not h.press() and not h.release(), "开了之后什么都不理")
	t.eq(fired[0], 1, "只发一次")
	var snap := LockHold.new(1.0, 0.0)
	snap.press()
	snap.advance(0.5)
	snap.release()
	t.check(snap.progress == 0.0 and snap.state == LockHold.State.IDLE, "回退倍速 0：一松手立刻归零")


## 出生点旁边就有宝箱点的种子；找不到就把出生点旁边的一个点改成宝箱（权重 1 的类型不一定挨着出生点）
static func _chest_next_to_spawn(f: GameFlow, c, kit: LoadoutDef) -> MapNode:
	var found: Dictionary = NodeScreens._seed_with(c, &"chest", kit.items)
	var seed := int(found.get("seed", 1))
	var run := f.begin(c.chapter, kit, seed)
	if run == null:
		return null
	var entry := int(found.get("entry", run.map.entry_ids[0]))
	f.pick_spawn(entry)
	if found.has("next"):
		return run.map.get_node(int(found["next"]))
	for nid in run.map.neighbors(entry):
		var node := run.map.get_node(nid)
		if node.type in [&"battle", &"event", &"search"]:
			node.type = &"chest"
			for key in node.content.keys():
				node.content.erase(key)
			return node
	return null


static func run_open(t: TestCase) -> void:
	t.begin("宝箱 · 开锁后（154）：踩上去是宝箱屏、没开锁走开点不算用过、站着能再开；开了是只搜一次的会话（不遭遇、能出珍宝、每件不低于下限），关掉才算用过；开过的不能再开；存档中途读回收获进待拾取")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, "chest")
	var node := _chest_next_to_spawn(f, c, kit)
	t.check(node != null, "出生点旁边有宝箱点")
	if node == null:
		Support.cleanup("chest")
		return
	var run := f.run
	t.check(f.step_to(node.id), "走上宝箱点")
	t.eq(f.screen, GameFlow.Screen.CHEST, "→ 宝箱屏")
	t.check(not node.is_visited() and not ChestPlacer.is_opened(node), "没开锁：点不算用过")
	t.check(f.leave_chest(), "不开就走")
	t.eq(f.screen, GameFlow.Screen.MAP, "→ 地图")
	t.check(not node.is_visited(), "点还没用过")
	t.check(f.can_reopen() and f.reopen_node(), "站着能再开")
	t.eq(f.screen, GameFlow.Screen.CHEST, "→ 宝箱屏")
	var rarity := ChestPlacer.rarity_of(node)
	var cr := run.events.chest_rules()
	t.eq(run.events.chest_hold_seconds(node), cr.hold_time(rarity), "按住秒数按稀有度")
	var steps_before := run.travel.history.size()
	var orig_excl := run.node_rules.search.exclude_tags.duplicate()
	var orig_max := run.node_rules.search.max_searches
	t.check(f.open_chest(node), "锁开了")
	t.eq(f.screen, GameFlow.Screen.SEARCH, "→ 搜索屏")
	var session := run.events.current_search
	t.check(session != null and session.node == node, "开了这个点的会话")
	if session == null:
		Support.cleanup("chest")
		return
	t.eq(session.searches_done, 1, "已经搜了一次")
	t.check(not session.can_search(), "不能再搜")
	t.check(session.encounter.is_empty(), "不遭遇")
	t.check(not session.rules.exclude_tags.has(&"treasure"), "能出珍宝")
	t.eq(run.node_rules.search.exclude_tags, orig_excl, "原搜索规则的排除标签没被改")
	t.eq(run.node_rules.search.max_searches, orig_max, "原搜索规则的次数没被改")
	var span := cr.item_range(rarity)
	var haul := session.haul()
	var count := haul.item_count() if haul != null else 0
	t.check(count >= 1 and count <= span.y, "出件在范围内（%d，%s）" % [count, str(span)])
	var floor_r := cr.floor_of(rarity)
	var low := 99
	if haul != null:
		for inst in haul.items():
			low = mini(low, (inst as ItemInstance).def.rarity)
	t.check(count == 0 or low >= floor_r, "每件不低于下限 %d（最低 %d）" % [floor_r, low])
	t.check(ChestPlacer.is_opened(node), "记了开过")
	t.eq(run.travel.history.size(), steps_before, "开锁不走步")
	t.check(not f.open_chest(node), "开着会话不能再开")

	# 存档中途读回：会话不进存档，收获进待拾取；点还是开过的宝箱
	var back := RunState.from_dict(run.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	t.check(back != null, "读得回来")
	if back != null:
		var bn := back.map.get_node(node.id)
		t.check(ChestPlacer.is_opened(bn) and ChestPlacer.rarity_of(bn) == rarity, "读回：开过、稀有度照旧")
		t.check(back.events.current_search == null, "读回：会话不在")
		t.check(count == 0 or (back.pending_loot != null and back.pending_loot.item_count() == count), "读回：收获进待拾取")
		t.check(not back.events.open_chest(bn), "读回：开过的不能再开")

	t.check(run.events.pause_search(), "关搜索屏")
	t.check(node.is_visited(), "关了才算用过")
	t.check(run.events.current_search == null, "会话结束")
	Support.settle(f)
	t.eq(f.screen, GameFlow.Screen.MAP, "→ 地图")
	t.check(not f.open_chest(node), "用过的不能再开")
	Support.cleanup("chest")


static func _key(code: Key, pressed: bool) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = pressed
	return k


static func run_key_bindings(t: TestCase) -> void:
	t.begin("宝箱 · 确认键与改键（154 补充一）：默认回车 / 小键盘回车 / 空格是确认、Esc 是取消；设置里改过的键启动时盖上去，整组替换；存取往返、坏数据扔掉")
	InputKeys.apply(null)
	t.check(InputMap.has_action(InputKeys.CONFIRM) and InputMap.has_action(InputKeys.CANCEL), "两个动作都定义了")
	for code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		t.check(_key(code, true).is_action(InputKeys.CONFIRM), "默认确认键 %s" % OS.get_keycode_string(code))
	t.check(_key(KEY_ESCAPE, true).is_action(InputKeys.CANCEL), "默认取消键 Esc")
	var s := GameSettings.new()
	t.eq(s.key_bindings, {}, "默认没改过")
	s.key_bindings = {"confirm": [KEY_F, "G"]}
	InputKeys.apply(s)
	t.check(_key(KEY_F, true).is_action(InputKeys.CONFIRM) and _key(KEY_G, true).is_action(InputKeys.CONFIRM), "改成 F、G（键名也认）")
	t.check(not _key(KEY_ENTER, true).is_action(InputKeys.CONFIRM), "整组替换：回车不再是确认")
	t.check(_key(KEY_ESCAPE, true).is_action(InputKeys.CANCEL), "没改的动作留默认")
	var back := GameSettings.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	t.eq(back.key_bindings, {"confirm": [int(KEY_F), int(KEY_G)]}, "存取往返（键名读成键码）")
	var bad := GameSettings.from_dict({"version": GameSettings.SAVE_VERSION, "key_bindings": {"confirm": ["没有这个键"], "cancel": 3, "": [KEY_A]}})
	t.eq(bad.key_bindings, {}, "坏数据全扔")
	t.eq(GameSettings.from_dict({"version": GameSettings.SAVE_VERSION, "key_bindings": "x"}).key_bindings, {}, "不是字典也不报错")
	InputKeys.apply(null)
	t.check(_key(KEY_ENTER, true).is_action(InputKeys.CONFIRM) and not _key(KEY_F, true).is_action(InputKeys.CONFIRM), "回到默认")


static func frame_chest_screen(t: TestCase, root: Window) -> void:
	t.begin("宝箱 · 屏（154）：占位画得出来；按下「尝试开锁」、松手回退、Esc 按着先松手；按满开箱后弹出搜索界面")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	Support.cleanup("chest_ui")
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = String(Support.paths("chest_ui")["run"])
	game.meta_path = String(Support.paths("chest_ui")["meta"])
	game.settings_path = String(Support.paths("chest_ui")["settings"])
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	var node := _chest_next_to_spawn(flow, c, kit)
	t.check(node != null and flow.step_to(node.id), "走上宝箱点")
	t.eq(flow.screen, GameFlow.Screen.CHEST, "→ 宝箱屏")
	var screen = game.overlay()
	t.check(screen != null and screen.has_method("press") and screen.view != null, "叠层是宝箱屏")
	if screen == null or not screen.has_method("press"):
		game.queue_free()
		Support.cleanup("chest_ui")
		return
	t.eq(screen.hint.text, "点击宝箱开锁", "没按：点击宝箱开锁")
	var hold: LockHold = screen.hold
	t.eq(hold.hold_seconds, flow.run.events.chest_hold_seconds(node), "按住秒数按稀有度")
	t.check(screen.press(), "按下")
	t.eq(screen.hint.text, "尝试开锁", "按着：尝试开锁")
	screen.step(hold.hold_seconds * 0.5)
	t.check(absf(hold.progress - 0.5) < 0.01, "走了一半")
	screen.view.queue_redraw()
	var away := InputEventMouseMotion.new()
	away.position = Vector2(-500, -500)
	away.global_position = Vector2(-500, -500)
	screen._input(away)
	screen.step(0.01)
	t.check(hold.is_holding() and hold.progress > 0.5, "按着移出宝箱不算松手，接着走（154 补充一）")
	t.check(not screen.leave(), "按着不能走")
	t.check(screen.escape() and not hold.is_holding(), "Esc 按着先松手")
	t.eq(flow.screen, GameFlow.Screen.CHEST, "还在宝箱屏")
	screen.step(hold.hold_seconds * 0.1)
	t.check(hold.progress < 0.5 and hold.progress > 0.0, "回退中")
	screen._input(_key(KEY_ENTER, true))
	t.check(hold.is_holding(), "按住确认键（回车）= 按下（154 补充一）")
	screen._input(_key(KEY_ENTER, false))
	t.check(not hold.is_holding(), "松开确认键 = 松手")
	screen._input(_key(KEY_A, true))
	t.check(not hold.is_holding(), "别的键不算")
	screen._input(_key(KEY_SPACE, true))
	t.check(screen.press() and hold.is_holding(), "确认键（空格）、鼠标一起按")
	screen._input(_key(KEY_SPACE, false))
	t.check(hold.is_holding(), "只松确认键还按着")
	screen.step(hold.hold_seconds * 2.0)
	t.check(hold.is_unlocked() and screen.opening, "走满：开箱动画")
	t.eq(screen.hint.text, "", "字没了")
	t.eq(flow.screen, GameFlow.Screen.CHEST, "开箱动画播完才弹搜索")
	screen.step(screen.OPEN_PAUSE_SECONDS * 0.5)
	t.eq(flow.screen, GameFlow.Screen.CHEST, "开了先停一会儿（箱内漆黑），再弹搜索")
	screen.step(1.0)
	t.eq(flow.screen, GameFlow.Screen.SEARCH, "→ 搜索屏")
	t.check(ChestPlacer.is_opened(node), "开过了")
	game.queue_free()
	Support.cleanup("chest_ui")
