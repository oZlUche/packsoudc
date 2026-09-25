## 084 第二轮（作者六条 + 道具悬浮窗）：文本占位符与样式码；节点浮窗的类别、模板来源与开关；道具说明的内容；
## 敌人也背包（组装先摆包、道具全在包里、预览重建 requires_bag）；只掉身上有的；抓起最后一件时容器不算空；悬浮窗控件。
extends RefCounted


class Content:
	extends RefCounted
	var items: ItemDatabase
	var enemies: EnemyDatabase
	var sets: SetDatabase
	var chapter: ChapterDef
	var pool: EnemyPool


static func _content() -> Content:
	var c := Content.new()
	c.items = ItemDatabase.new()
	c.items.load_dir()
	c.enemies = EnemyDatabase.new()
	c.enemies.load_all()
	c.sets = SetDatabase.new()
	c.sets.load_dir()
	c.chapter = load(ContentPaths.asset_file("chapters", "chapter_01"))
	c.pool = c.enemies.pool(c.chapter.enemy_pool)
	return c


static func run_text_template(t: TestCase) -> void:
	t.begin("084 · 文本占位符：{key} 按上下文替换、不认识的原样保留；样式码翻成 BBCode；plain 剥掉样式；context_for 给出角色 / 章节 / 点 / 对手的键")
	var ctx := {"char_name": "布鲁图斯", "money": 12}
	t.eq(TextTemplate.render("{char_name}有 {money} 币", ctx), "布鲁图斯有 12 币", "占位符替换")
	t.eq(TextTemplate.render("{nope} 还在", ctx), "{nope} 还在", "不认识的键原样保留")
	t.eq(TextTemplate.render("{c:hp}血{/c}{b}粗{/b}{i}斜{/i}", {}), "[color=#%s]血[/color][b]粗[/b][i]斜[/i]" % UiPalette.HP.to_html(false), "样式码 → BBCode")
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
		t.check(not text.contains("{") and text.contains("DPS"), "默认模板渲染出了敌人数据（%s）" % text)
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
	t.begin("084 · 道具说明：名（按稀有度上色）、稀有度、标签、效果；武器有冷却与 DPS，非武器没有 DPS；槽的说明；包的说明；在棋盘上按棋盘编译")
	var c := _content()
	var knife := ItemInstance.create(c.items.get_def(&"knife"))
	var text := ItemTooltip.describe(knife)
	t.check(text.contains("匕首") and text.contains(ItemPainter.rarity_color(knife.def).to_html(false)), "名字按稀有度上色")
	t.check(text.contains(ItemTooltip.rarity_name(knife.def.rarity)), "写了稀有度")
	t.check(text.contains("weapon") and text.contains("bleed"), "写了标签")
	t.check(text.contains("冷却") and text.contains("DPS"), "武器：冷却与 DPS（%s）" % text.replace("\n", " | "))
	var compiled := ItemTooltip.compiled_for(knife, null)
	t.check(compiled != null and compiled.estimated_dps() > 0.0, "单独编译得出 DPS")
	var gamb := ItemInstance.create(c.items.get_def(&"gambeson"))
	var gtext := ItemTooltip.describe(gamb)
	t.check(not gtext.contains("DPS"), "非武器不写 DPS")
	t.check(gtext.contains("槽"), "有邻接标记的写槽的说明（%s）" % gtext.replace("\n", " | "))
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
	d.shape = ItemShape.from_ascii(["#"])
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
	t.check(not tip.is_showing(), "移到空格：藏起来")
	tip.can_show = func(_v: ContainerView, _uid: int) -> bool: return false
	view.gui_input.emit(mm)
	t.check(not tip.is_showing(), "can_show 说不行就不显示")
	tip.can_show = Callable()
	view.gui_input.emit(mm)
	t.check(tip.is_showing(), "放开就又显示")
	view.mouse_exited.emit()
	t.check(not tip.is_showing(), "出了视图：藏起来")
	tip.show_text("地图上的点", Vector2(100, 100))
	t.check(tip.is_showing() and tip.text() == "地图上的点", "直接给文字也行")
	host.queue_free()
