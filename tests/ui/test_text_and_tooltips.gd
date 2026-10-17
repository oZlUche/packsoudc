## 084 第二轮（作者六条 + 道具悬浮窗）：文本占位符与样式码；节点浮窗的类别、模板来源与开关；道具说明的内容；
## 敌人也背包（组装先摆包、道具全在包里、预览重建 requires_bag）；只掉身上有的；抓起最后一件时容器不算空；悬浮窗控件。
extends RefCounted


static func _content() -> TestSupport.Content:
	return TestSupport.load_content()


static func run_text_template(t: TestCase) -> void:
	t.begin("084 · 文本占位符：{key} 按上下文替换、不认识的原样保留；样式码翻成 BBCode；plain 剥掉样式；context_for 给出角色 / 章节 / 点 / 对手的键")
	var ctx := {"char_name": "布鲁图斯", "money": 12}
	t.eq(TextTemplate.render("{char_name}有 {money} 币", ctx), "布鲁图斯有 12 币", "占位符替换")
	t.eq(TextTemplate.render("{nope} 还在", ctx), "{nope} 还在", "不认识的键原样保留")
	# 101 第 5 刀：文本层只产出带颜色**名**的样式码，换成真颜色是界面的事（UiPalette.resolve_styles）
	t.eq(TextTemplate.render("{c:hp}血{/c}{b}粗{/b}{i}斜{/i}", {}), "[color=@hp]血[/color][b]粗[/b][i]斜[/i]", "样式码 → 带颜色名的 BBCode")
	t.eq(UiPalette.resolve_styles("[color=@hp]血[/color]"), "[color=#%s]血[/color]" % UiPalette.HP.to_html(false), "界面查表换成真颜色")
	t.eq(UiPalette.resolve_styles("[color=@nope]x[/color]"), "[color=@nope]x[/color]", "名字对不上的原样留着（一眼看得见，也不会崩）")
	t.eq(UiPalette.resolve_styles("没有样式码"), "没有样式码", "没样式码的原样返回")
	for name in TextTemplate.STYLE_NAMES:
		t.check(UiPalette.STYLE_COLORS.has(name), "认得的颜色名 %s 在调色板里有颜色" % name)
	t.eq(TextTemplate.render("{c:#ff8800}x{/c}", {}), "[color=#ff8800]x[/color]", "十六进制颜色也行")
	t.eq(TextTemplate.render("{c:nothing}x{/c}", {}), "{c:nothing}x[/color]", "不认识的颜色名原样保留")
	t.eq(TextTemplate.render("没闭合的 {", {}), "没闭合的 {", "没闭合的花括号不崩")
	t.eq(TextTemplate.plain("{c:hp}{char_name}{/c}", ctx), "布鲁图斯", "plain 剥掉样式只留文字")
	var c := _content()
	var s := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets)
	if s == null:
		t.check(false, "开不了局")
		return
	s.pick_spawn(s.map.entry_ids[0])
	var battle: MapNode = null
	for id in s.map.node_ids():
		if EnemyKit.has_enemy(s.map.get_node(id).content):
			battle = s.map.get_node(id)
			break
	var got := TextTemplate.context_for(s, battle)
	t.eq(String(got["chapter_name"]), c.chapter.display_name, "章节名")
	t.eq(String(got["char_name"]), "你", "没角色时叫「你」")
	t.check(int(got["vitality"]) == s.vitality.current and int(got["money"]) == s.wallet.balance, "体力与钱")
	if battle != null:
		t.check(got.has("enemy_name") and got.has("battle_data") and int(got["enemy_hp"]) > 0, "有敌人的点给出对手的键（%s）" % got.get("battle_data", ""))
		t.eq(int(got["node_id"]), battle.id, "点 id")
	t.eq(String(TextTemplate.context_for(s, null, {"enemy_name": "X"})["enemy_name"]), "X", "extra 覆盖")


static func run_node_tooltip(t: TestCase) -> void:
	t.begin("084 · 节点浮窗：类别（战斗 / 用过 / 搜索 / 事件……）、模板三级来源（节点 > 章节自定义 > 内置）、战斗点画对手棋盘、章节开关默认关")
	var c := _content()
	t.check(not c.chapter.node_tooltips, "第一章默认关（第二章开放）")
	var s := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets)
	if s == null:
		return
	s.pick_spawn(s.map.entry_ids[0])
	var by_type := {}
	for id in s.map.node_ids():
		var n := s.map.get_node(id)
		if not by_type.has(n.type) and not n.is_visited():
			by_type[n.type] = n
	if by_type.has(&"battle"):
		var b: MapNode = by_type[&"battle"]
		t.eq(NodeTooltip.category_of(b), "battle", "战斗点归 battle")
		t.check(NodeTooltip.shows_board(b), "战斗点画对手的棋盘")
		var text := NodeTooltip.text_for(s, c.chapter, b)
		t.check(not text.contains("{") and text.contains("生命") and not text.contains("DPS"), "默认模板渲染出了敌人数据（%s）" % text)
	if by_type.has(&"search"):
		t.check(NodeTooltip.text_for(s, c.chapter, by_type[&"search"]).begins_with("这里有值得搜索的东西"), "搜索点：值得搜索，但……")
	if by_type.has(&"event"):
		t.check(NodeTooltip.text_for(s, c.chapter, by_type[&"event"]).contains("可能会发生什么"), "事件点：可能会发生什么")
	var spawn := s.current_node()
	t.eq(NodeTooltip.category_of(spawn), "spawn", "出生点不算「用过」")
	var used := MapNode.new()
	used.id = 999
	used.type = &"battle"
	used.state = MapNode.State.VISITED
	t.eq(NodeTooltip.category_of(used), "visited", "用过的战斗点归 visited")
	t.check(NodeTooltip.text_for(s, c.chapter, used).contains("已经没东西了"), "用过：已经没东西了")
	t.check(not NodeTooltip.shows_board(used), "用过的不画棋盘")
	# 自定义模板
	var ch := ChapterDef.new()
	ch.tooltip_mode = "custom"
	ch.tooltip_texts = {"visited": "空了：{node_type}"}
	t.eq(NodeTooltip.text_for(s, ch, used), "空了：战斗", "章节自定义模板 + 占位符")
	ch.tooltip_mode = "default"
	t.check(NodeTooltip.text_for(s, ch, used).contains("已经没东西了"), "切回 default 就用内置的")
	used.content["tooltip"] = "这个点专有的话 {node_id}"
	t.eq(NodeTooltip.text_for(s, ch, used), "这个点专有的话 999", "节点内容的 tooltip 优先")


static func run_item_tooltip(t: TestCase) -> void:
	t.begin("084 · 道具说明：名（按稀有度上色）、稀有度、标签、效果；武器写「每 X 秒造成 Y 点伤害」（170：不写冷却与 DPS）；槽的说明；包的说明；在棋盘上按棋盘编译")
	var c := _content()
	var knife := ItemInstance.create(c.items.get_def(&"knife"))
	var text := ItemTooltip.describe(knife)
	t.check(text.contains("[color=@rarity%d]匕首" % knife.def.rarity), "名字按稀有度上色（颜色名，按底取版）")
	t.check(text.contains(ItemTooltip.rarity_name(knife.def.rarity)), "写了稀有度")
	t.check(text.contains("武器") and not text.contains("weapon"), "写了标签（096：按数据里的名字，不是原词）")
	t.check(not text.contains("快攻"), "快攻是内部标签，不写（107 后续）")
	t.check(Glossary.strip_bbcode(text).contains("秒造成") and not text.contains("冷却") and not text.contains("DPS"), "武器：每 X 秒造成 Y 点伤害，不写冷却与 DPS（%s）" % text.replace("\n", " | "))
	var compiled := ItemTooltip.compiled_for(knife, null)
	t.check(compiled != null and compiled.estimated_dps() > 0.0, "单独编译得出 DPS")
	var gamb := ItemInstance.create(c.items.get_def(&"gambeson"))
	var gtext := ItemTooltip.describe(gamb)
	t.check(not gtext.contains("DPS"), "非武器不写 DPS")
	t.check(gtext.contains("term:增益槽") or gtext.contains("term:受益槽"), "有邻接标记的写槽的句子（行首格位图标，%s）" % gtext.replace("\n", " | "))
	var bag := ItemInstance.create(c.items.get_def(&"bag_leather"))
	t.check(ItemTooltip.describe(bag).contains("包："), "包写包的说明")
	# 在棋盘上：按棋盘编译（有邻接加成时 DPS 会变）
	var board := GridInventory.new(Vector2i(6, 4), 1, true)
	board.try_add(ItemInstance.create(c.items.get_def(&"bag_leather")), true)
	var k2 := ItemInstance.create(c.items.get_def(&"knife"))
	t.check(board.try_add(k2, true), "刀放进包里")
	var on_board := ItemTooltip.compiled_for(k2, board)
	t.check(on_board != null and on_board.source_uid == k2.uid, "棋盘上的按棋盘编译，拿到的是它自己")


static func run_enemy_bags(t: TestCase) -> void:
	t.begin("084 · 敌人也背包：组装先摆档位表的包、道具全在包里、包不计件数；预览重建 requires_bag；老内容（没包）照旧")
	var c := _content()
	if c.pool == null:
		t.check(false, "没有池")
		return
	for tier in c.pool.tiers:
		t.check(not (tier as StrengthTier).bags.is_empty(), "档位 %d 配了包" % (tier as StrengthTier).strength)
	var def := c.enemies.enemy(&"raider")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var built := EnemyPlacer.build_content(def, c.pool, c.items, 1, rng)
	var content: Dictionary = built["content"]
	var board := EnemyKit.board_of(content, c.items)
	t.check(board.requires_bag, "棋盘 requires_bag")
	var bags := 0
	for inst in board.items():
		if (inst as ItemInstance).def.is_bag:
			bags += 1
	t.eq(bags, c.pool.tier_of(1).bags.size(), "背着档位表说的包")
	var goods := 0
	for inst in board.items():
		var it := inst as ItemInstance
		if not it.def.is_bag:
			goods += 1
			var covered := true
			for cell in it.cells():
				if board.bag_at(cell) == GridInventory.EMPTY_UID:
					covered = false
			t.check(covered, "%s 的每一格都在包上（可以跨两个包）" % it.def.display_name)
	t.eq(board.item_count(), (content["items"] as Array).size(), "重建出全部件数")
	t.check(goods >= 1, "包里有东西（%d 件）" % goods)
	var spec := EnemyKit.spec_of(content, c.enemies, c.pool, c.items)
	t.check(spec != null and spec.items.size() == goods, "编译出的参战件数 = 包里的件数（包不参战）")
	# 老内容
	var legacy := {"enemy": "raider", "strength": 0, "board": [4, 3], "items": [{"id": "knife", "at": [0, 0], "rot": 0}]}
	var lb := EnemyKit.board_of(legacy, c.items)
	t.check(not lb.requires_bag and lb.item_count() == 1, "没有包的老内容直接摆")


static func run_drops_only_carried(t: TestCase) -> void:
	t.begin("084 · 敌人不能掉没有的东西：guaranteed_drops 只认身上有的；标准掉落规则珍宝概率 0")
	var c := _content()
	var rule: DropRule = load(ContentPaths.asset_file("drop_rules", "standard"))
	t.eq(rule.treasure_chance, 0.0, "标准规则不掉珍宝")
	var content := {"enemy": "raider", "strength": 0, "board": [4, 3],
		"items": [{"id": "bag_small", "at": [0, 0], "rot": 0}, {"id": "knife", "at": [0, 0], "rot": 0}],
		"guaranteed_drops": ["knife", "round_shield"]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var ctx := LootContext.new()
	var rolled := DropResolver.roll(content, rule, ctx, c.items, rng)
	var dropped: Array = rolled["dropped"]
	t.check(dropped.has(&"knife"), "身上有的必掉")
	t.check(not dropped.has(&"round_shield"), "身上没有的不掉")
	for id in dropped:
		t.check(DropResolver.carried_ids(content).has(id), "掉的 %s 都是身上有的" % id)


static func run_drag_last_item(t: TestCase) -> void:
	t.begin("084 · 抓起最后一件时容器发 changed，那一刻 is_dragging() 已经是真（容器屏靠它不关屏）")
	ItemInstance.reset_uid_counter()
	var d := ItemDef.new()
	d.id = &"t_one"
	d.display_name = "one"
	d.shape = ItemShape.from_ascii(["1"])
	var box := GridInventory.new(Vector2i(3, 3), 1)
	var a := ItemInstance.create(d)
	box.place(a, Vector2i(0, 0), 0)
	var view := InventoryView.new()
	view.inventory = box
	view.size = Vector2(box.size) * InventoryView.CELL
	var drag := DragLayer.new()
	drag.register_view(view)
	var seen: Array = []
	box.changed.connect(func(): seen.append([box.item_count(), drag.is_dragging()]))
	view.grab_requested.emit(view, a.uid, Vector2(24, 24))
	t.check(drag.is_dragging(), "抓起来了")
	t.check(not seen.is_empty() and int(seen[0][0]) == 0 and bool(seen[0][1]), "容器空了那一刻正在拖（%s）" % str(seen))
	drag.cancel()
	t.check(box.has_item(a.uid), "取消退回")


static func frame_hover_tip(t: TestCase, root: Window) -> void:
	t.begin("084 · 悬浮窗控件：鼠标在视图里动到一件道具上就显示它的说明，移到空格 / 出视图就藏；can_show 能拦")
	var c := _content()
	var host := Control.new()
	host.size = Vector2(800, 600)
	root.add_child(host)
	var board := GridInventory.new(Vector2i(4, 3), 1)
	var knife := ItemInstance.create(c.items.get_def(&"knife"))
	board.place(knife, Vector2i(0, 0), 0)
	var view := InventoryView.new()
	view.inventory = board
	view.position = Vector2(20, 20)
	view.size = Vector2(board.size) * InventoryView.CELL
	host.add_child(view)
	var tip := HoverTip.new()
	host.add_child(tip)
	tip.watch(view)
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(24, 24)
	view.gui_input.emit(mm)
	t.check(tip.is_showing() and tip.text().contains("匕首"), "停在刀上：显示刀的说明")
	var mm2 := InputEventMouseMotion.new()
	mm2.position = Vector2(150, 120)
	view.gui_input.emit(mm2)
	t.check(tip.is_showing(), "170：刚移到空格还在（宽限 %.2f 秒，好让鼠标移进悬浮窗）" % HoverTip.GRACE_SEC)
	tip.tick(HoverTip.GRACE_SEC + 0.01, Vector2(790, 590))
	t.check(not tip.is_showing(), "移到空格、宽限过了没进窗：藏起来")
	tip.can_show = func(_v: ContainerView, _uid: int) -> bool: return false
	view.gui_input.emit(mm)
	t.check(not tip.is_showing(), "can_show 说不行就不显示")
	tip.can_show = Callable()
	view.gui_input.emit(mm)
	t.check(tip.is_showing(), "放开就又显示")
	view.mouse_exited.emit()
	tip.tick(HoverTip.GRACE_SEC + 0.01, Vector2(790, 590))
	t.check(not tip.is_showing(), "出了视图（宽限过了）：藏起来")
	tip.show_text("地图上的点", Vector2(100, 100))
	t.check(tip.is_showing() and tip.text() == "地图上的点", "直接给文字也行")
	host.queue_free()

	# 090 → 170：侧窗取消，词条在钉住后开子窗 —— 子窗贴主窗右边，右边放不下换下面，都夹在屏幕里、不压主窗
	var narrow := Control.new()
	narrow.size = Vector2(200, 600)
	root.add_child(narrow)
	var tip2 := HoverTip.new()
	narrow.add_child(tip2)
	var terms := {"格挡": {"name": "格挡", "text": "只有盾牌给格挡。"}}
	var vw := root.get_visible_rect().size.x
	for at in [Vector2(20, 20), Vector2(vw - 20, 20)]:
		tip2.show_text("[b]盾[/b]\n[url=term:格挡][u]格挡[/u][/url] 4", at, null, terms)
		tip2.pin(tip2._panel)
		var child = tip2.open_child(tip2._panel, "term:格挡")
		t.not_null(child, "钉住后开得出子窗")
		if child == null:
			continue
		var pr := Rect2(tip2._panel.position, tip2._panel.size)
		var cr := Rect2(child.position, child.size)
		t.check(not pr.intersects(cr.grow(-0.5)), "子窗不压主窗（鼠标在 %s）" % str(at))
		t.check(pr.position.x >= 0 and cr.position.x >= 0 and cr.end.x <= vw + 0.5, "都在屏幕里")
		tip2.hide_tip()
	t.check(not tip2.is_showing() and tip2.windows().is_empty(), "收起来整串都关")
	narrow.queue_free()

	# 反馈（悬浮窗下方大段空白）：先显示长文 + 对手棋盘，再换成一行短字 —— 旧棋盘当场摘掉、排版后缩回内容高度
	var host3 := Control.new()
	host3.size = Vector2(800, 600)
	root.add_child(host3)
	var tip3 := HoverTip.new()
	host3.add_child(tip3)
	var bv := InventoryView.new()
	bv.inventory = board
	tip3.show_text("[b]长[/b]\n第二行\n第三行\n第四行\n第五行", Vector2(50, 50), bv)
	var tall := tip3._panel.size.y
	tip3.show_text("一行", Vector2(50, 50))
	t.check(bv.get_parent() == null, "换内容时旧的下挂棋盘当场从列里摘掉（不等帧末）")
	tip3._refit()
	var want := tip3._panel.get_combined_minimum_size().y
	t.check(tip3._panel.size.y <= want + 0.5, "排版后主窗高度 = 内容高度（%.0f ≤ %.0f），不留空白" % [tip3._panel.size.y, want])
	t.check(tip3._panel.size.y < tall, "比长文 + 棋盘那次矮（%.0f < %.0f）" % [tip3._panel.size.y, tall])
	host3.queue_free()


static func run_min_drops(t: TestCase) -> void:
	t.begin("084 · 至少掉 min_drops 件身上有的（数据，标准规则 1）：概率全 0 也掉、只掉身上的；包必掉（bags_always_drop）且不占保底名额；开关关了包照掷")
	var c := _content()
	var std: DropRule = load(ContentPaths.asset_file("drop_rules", "standard"))
	t.eq(std.min_drops, 1, "标准规则至少掉一件")
	t.check(std.bags_always_drop, "标准规则：包必掉")
	var rule := DropRule.new()
	rule.base_chance = [0.0, 0.0, 0.0, 0.0, 0.0] as Array[float]
	rule.treasure_chance = 0.0
	rule.min_drops = 1
	var content := {"enemy": "raider", "strength": 0, "board": [4, 3],
		"items": [{"id": "bag_small", "at": [0, 0], "rot": 0}, {"id": "knife", "at": [0, 0], "rot": 0}, {"id": "salve", "at": [1, 0], "rot": 0}]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 20:
		var got: Array = DropResolver.roll(content, rule, LootContext.new(), c.items, rng)["dropped"]
		var non_bag := 0
		for id in got:
			t.check(DropResolver.carried_ids(content).has(id), "第 %d 次：%s 是身上的" % [i, id])
			if not c.items.get_def(id).is_bag:
				non_bag += 1
		t.check(got.has(&"bag_small"), "第 %d 次：包必掉" % i)
		t.eq(non_bag, 1, "第 %d 次：包之外正好保底一件（%s）" % [i, str(got)])
	rule.min_drops = 2
	var two: Array = DropResolver.roll(content, rule, LootContext.new(), c.items, rng)["dropped"]
	t.eq(two.size(), 3, "保底改成 2：包 + 两件（保底数是数据，不写死）")
	rule.min_drops = 5
	var all: Array = DropResolver.roll(content, rule, LootContext.new(), c.items, rng)["dropped"]
	t.eq(all.size(), 3, "身上就三件就掉光，不多造")
	rule.min_drops = 0
	var only_bag: Array = DropResolver.roll(content, rule, LootContext.new(), c.items, rng)["dropped"]
	t.check(only_bag.size() == 1 and only_bag[0] == &"bag_small", "不保底：只有包必掉")
	rule.bags_always_drop = false
	t.eq((DropResolver.roll(content, rule, LootContext.new(), c.items, rng)["dropped"] as Array).size(), 0, "包的开关关了：概率全 0 就一件不掉")


static func run_stamina_estimate(t: TestCase) -> void:
	t.begin("084 · 耐力消耗评估：每秒消耗 = Σ 频率 × 消耗，回复来自基线；空棋盘「低」；比值分档")
	var c := _content()
	var board := GridInventory.new(Vector2i(6, 4), 1, true)
	var empty := StaminaEstimate.of(BattleCompiler.compile_board(board))
	t.check(float(empty["cost"]) == 0.0 and String(empty["rating"]) == "低", "空棋盘：不花、评「低」")
	t.eq(float(empty["regen"]), CombatantBaseline.DEFAULT_STATS["regen_stamina"], "回复来自基线")
	var with_ration := GridInventory.new(Vector2i(6, 4), 1, true)
	with_ration.try_add(ItemInstance.create(c.items.get_def(&"bag_leather")), true)
	with_ration.try_add(ItemInstance.create(c.items.get_def(&"ration")), true)
	var spec_r := BattleCompiler.compile_board(with_ration)
	var ration_regen := float(c.items.get_def(&"ration").combat.base_stats.get("regen_stamina", 0))
	t.eq(float(StaminaEstimate.of(spec_r)["regen"]), float(CombatantBaseline.DEFAULT_STATS["regen_stamina"]) + ration_regen, "口粮的回复算进去了（作者反馈）")
	var rt := CombatantRuntime.from_spec(spec_r, 0)
	t.eq(StatMath.to_float(rt.stat(BattleStats.REGEN_STAMINA)), float(CombatantBaseline.DEFAULT_STATS["regen_stamina"]) + ration_regen, "运行时的单位回复也是这个数（战斗里真生效）")
	t.check(StaminaEstimate.describe(spec_r).contains("耐力上限"), "悬浮窗写了上限")
	board.try_add(ItemInstance.create(c.items.get_def(&"bag_leather")), true)
	var knife := ItemInstance.create(c.items.get_def(&"knife"))
	board.try_add(knife, true)
	var spec := BattleCompiler.compile_board(board)
	var e := StaminaEstimate.of(spec)
	var rule := knife.def.combat.rules[0] as AbilityRule
	var hz := rule.cadence.estimated_hz(spec.item_of(knife.uid).stats)
	var amount := (rule.costs[0] as ResourceCost).amount
	t.check(absf(float(e["cost"]) - hz * amount) < 0.001, "一把刀：每秒消耗 = 频率 %.2f × 消耗 %.1f = %.2f" % [hz, amount, float(e["cost"])])
	t.check(["低", "中", "高", "极高"].has(String(e["rating"])), "评级是四档之一（%s）" % e["rating"])
	t.eq(StaminaEstimate.rating_of(0.1), "低", "0.1 低")
	t.eq(StaminaEstimate.rating_of(0.8), "中", "0.8 中")
	t.eq(StaminaEstimate.rating_of(1.2), "高", "1.2 高")
	t.eq(StaminaEstimate.rating_of(3.0), "极高", "3.0 极高")
	t.check(StaminaEstimate.describe(spec).contains("每秒平均消耗"), "悬浮窗的文字")


static func run_settings_and_double_click(t: TestCase) -> void:
	t.begin("084 · 设置「拿走最后一件后自动关闭」默认关、存读带着；双击视图发 item_double_clicked 而不是抓")
	var s := GameSettings.new()
	t.check(not s.loot_auto_close, "默认不自动关")
	t.check(not s.node_tooltips_preview, "节点浮窗预览默认关")
	s.loot_auto_close = true
	s.node_tooltips_preview = true
	var back := GameSettings.from_dict(s.to_dict())
	t.check(back.loot_auto_close and back.node_tooltips_preview, "存读带着")
	var c0 := _content()
	var f := GameFlow.new(c0.items, c0.enemies, c0.sets, MetaState.new())
	f.chapters = [c0.chapter] as Array[ChapterDef]
	f.save_path = "user://test_084c_run.json"
	f.meta_path = "user://test_084c_meta.json"
	var run := f.begin(c0.chapter, null, 5)
	if run != null:
		t.check(not f.tooltips_enabled(), "第一章没开：浮窗关")
		f.settings.node_tooltips_preview = true
		t.check(f.tooltips_enabled(), "预览开了：不管章节")
	RunSave.remove("user://test_084c_run.json")
	MetaSave.remove("user://test_084c_meta.json")
	ItemInstance.reset_uid_counter()
	var d := ItemDef.new()
	d.id = &"t_dbl"
	d.display_name = "dbl"
	d.shape = ItemShape.from_ascii(["1"])
	var box := GridInventory.new(Vector2i(3, 3), 1)
	var a := ItemInstance.create(d)
	box.place(a, Vector2i(0, 0), 0)
	var view := InventoryView.new()
	view.inventory = box
	view.size = Vector2(box.size) * InventoryView.CELL
	var grabs: Array = []
	var dbls: Array = []
	view.grab_requested.connect(func(_v: ContainerView, uid: int, _p: Vector2): grabs.append(uid))
	view.item_double_clicked.connect(func(_v: ContainerView, uid: int): dbls.append(uid))
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.double_click = true
	mb.position = Vector2(24, 24)
	view._gui_input(mb)
	t.check(dbls == [a.uid] and grabs.is_empty(), "双击：发 item_double_clicked，不抓")
	mb.double_click = false
	view._gui_input(mb)
	t.check(grabs == [a.uid], "单击：抓")
	var stash := ItemStash.new(2, 0)
	stash.admit(ItemInstance.create(d))
	var sv := GroundLayer.new()     # 128：地上
	sv.stash = stash
	sv.size = Vector2(1600, 900)
	var sdbl: Array = []
	sv.item_double_clicked.connect(func(_v: ContainerView, uid: int): sdbl.append(uid))
	var mb2 := InputEventMouseButton.new()
	mb2.button_index = MOUSE_BUTTON_LEFT
	mb2.pressed = true
	mb2.double_click = true
	mb2.position = sv.item_rect((stash.items()[0] as ItemInstance).uid).position + Vector2(10, 10)
	sv._gui_input(mb2)
	t.eq(sdbl.size(), 1, "地上列表双击也发")


static func frame_loot_manual_close(t: TestCase, root: Window) -> void:
	t.begin("084 · 战利品屏：拿完不自动关（手动关才丢）；双击容器里的进背包、双击棋盘上的回容器且不变成未知；设置开了才自动关；胜负回放完才显示")
	var c := _content()
	var loadouts := GameFlow.load_loadouts()
	var kit: LoadoutDef = null
	for l in loadouts:
		if l.id == &"standard":
			kit = l
	var found := {}
	for seed in range(1, 80):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit.items)
		if s == null:
			continue
		for entry in s.map.entry_ids:
			for nid in s.map.neighbors(entry):
				if s.map.get_node(nid).type == &"battle":
					found = {"seed": seed, "entry": entry, "next": nid}
		if not found.is_empty():
			break
	if found.is_empty():
		t.check(false, "找不到种子")
		return
	var scene := load("res://ui/game/game.tscn") as PackedScene
	var game = scene.instantiate()
	game.save_path = "user://test_084b_run.json"
	game.meta_path = "user://test_084b_meta.json"
	game.settings_path = "user://test_084b_settings.json"
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	flow.settings = GameSettings.new()
	flow.begin(c.chapter, kit, int(found["seed"]))
	var map = game.base()
	map.pick_spawn(int(found["entry"]))
	map.step(int(found["next"]))
	if game.overlay() == null or game.overlay().screen != GameFlow.Screen.PREBATTLE:
		t.check(false, "没到战前准备屏")
		game.queue_free()
		return
	game.overlay().start_battle()
	var battle = game.overlay()
	t.check(battle != null and battle.screen == GameFlow.Screen.BATTLE and not battle.verdict_shown(), "回放屏一开始不写胜负")
	battle._on_finished()
	t.check(battle.verdict_shown(), "回放完了才写胜负")
	battle.proceed()
	var loot = game.overlay()
	if loot == null or loot.screen != GameFlow.Screen.LOOT:
		t.check(true, "（这一场没掉东西：跳过战利品屏那一段）")
		flow.to_main_menu()
		game.queue_free()
		return
	var run: RunState = flow.run
	loot.skip_reveal()
	var first: ItemInstance = run.pending_loot.items()[0]
	var went: String = loot.quick_take(first.uid)
	t.check(went == "board" or went == "storage", "双击容器里的：进了背包或地上（%s）" % went)
	t.check(not run.pending_loot.has_item(first.uid), "离开了容器")
	# 棋盘上的双击回容器：不能变成未知
	var back_uid := -1
	for inst in run.board.items():
		if not (inst as ItemInstance).def.is_bag:
			back_uid = (inst as ItemInstance).uid
			break
	if back_uid >= 0:
		var moved: bool = loot._inv.quick_move(loot._inv.board_view, back_uid)
		if moved and run.pending_loot.has_item(back_uid):
			t.check(not loot.loot_view().is_locked(back_uid), "放回容器的自己的东西不是「未知」")
			loot.quick_take(back_uid)
	loot.take_all()
	t.check(run.pending_loot != null and run.pending_loot.item_count() == 0, "拿完了：容器空着")
	t.check(game.overlay() == loot, "默认不自动关")
	t.check(loot.to_map(), "手动关")
	t.check(game.overlay() == null and run.pending_loot == null, "关了才丢掉空容器、回地图")
	flow.settings.loot_auto_close = true
	t.check(flow.settings.loot_auto_close, "开了自动关（下一份战利品才用得上）")
	flow.to_main_menu()
	game.queue_free()
	RunSave.remove("user://test_084b_run.json")
	MetaSave.remove("user://test_084b_meta.json")
	GameSettings.remove("user://test_084b_settings.json")


## 反馈 bug：地图上悬停节点，下方两行说明文字随节点变长，把中间一列撑宽、地图视图被挤窄后重新居中，
## 地图一位移鼠标就脱离节点、文字清空又缩回去，再悬停又触发 —— 闪烁。这两行的文字再长也不许影响布局宽度
static func frame_map_hover_line_does_not_resize(t: TestCase, root: Window) -> void:
	t.begin("地图 · 悬停说明行（反馈 bug）：文字再长也不撑宽所在的列，地图视图尺寸不随悬停变化")
	var NodeScreens := preload("res://tests/ui/test_node_screens.gd")
	var Support := preload("res://tests/run/flow_support.gd")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	Support.cleanup("maphover")
	var game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	game.save_path = String(Support.paths("maphover")["run"])
	game.meta_path = String(Support.paths("maphover")["meta"])
	game.settings_path = String(Support.paths("maphover")["settings"])
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	flow.begin(c.chapter, kit, 1)
	var screen = game.base()
	t.check(screen != null and screen.get("_enemy_line") != null, "进了地图屏")
	if screen != null and screen.get("_enemy_line") != null:
		var long_text := "很长的一行说明".repeat(60)
		for l in [screen._enemy_line, screen._preview]:
			(l as Label).text = long_text
			t.check((l as Label).get_combined_minimum_size().x <= 1.0, "超长文字也不抬高最小宽度（%s）" % str((l as Label).get_combined_minimum_size()))
	game.queue_free()
	Support.cleanup("maphover")
