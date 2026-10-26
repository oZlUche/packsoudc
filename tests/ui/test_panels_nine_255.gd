## 255 补充一（作者 2026-10-26 10:51「所有面板的尺寸不变，不应棋盘大小而变化，改成最宽 9 格，低于九格时增加内距」）：
## 七格的安德烈乌斯和九格的布鲁图斯各开一遍 —— 背包窗、搜刮屏、战前屏、商店 / 保险箱、基地仓库页的面板位置与尺寸一个像素不动，棋盘在九格的位子里居中
extends RefCounted

const Support := preload("res://tests/run/flow_support.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const NARROW := &"andreus"
const WIDE := &"brutus"


static func _flow(prefix: String, ch_id: StringName) -> GameFlow:
	var c := TestSupport.load_content("free_mode", ["loadouts", "events", "characters"])
	var f := Support.flow(c, prefix)
	var ch: CharacterDef = null
	for d in c.characters:
		if d.id == ch_id:
			ch = d
	f.begin(c.chapter, NodeScreens._kit(c), 1, [] as Array[int], ch)
	f.pick_spawn(f.run.map.entry_ids[0])
	return f


## 容器的排布是延迟的，同一帧里手动排两遍
static func _lay_out(n: Node) -> void:
	for i in 2:
		_sort(n)


static func _sort(n: Node) -> void:
	if n is Container:
		n.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_sort(c)


## 屏上看得见的面板（皮 / 九宫格 / 九格位子 / 数值栏）的矩形，以屏左上为原点；九格位子里面（棋盘和贴着它的框）不算
static func _panels(screen: Control, skip: Array = []) -> Dictionary:
	var out := {}
	for n in screen.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or skip.has(c) or not (c is PanelContainer or c is NinePatchRect or c is BoardNine or c is StatsStrip):
			continue
		var inside := false
		var p := c.get_parent()
		while p != null and p != screen:
			if p is BoardNine or skip.has(p):
				inside = true
				break
			p = p.get_parent()
		if inside:
			continue
		var r := c.get_global_rect()
		out[_key(screen, c)] = Rect2(r.position - screen.global_position, r.size)
	return out


## 稳定的键：一路的「类名#序号」（自动起的节点名每次不同）
static func _key(screen: Node, c: Node) -> String:
	var bits: Array[String] = []
	var n := c
	while n != null and n != screen:
		bits.push_front("%s#%d" % [n.get_class() if n.get_script() == null or (n.get_script() as Script).get_global_name() == &"" else String((n.get_script() as Script).get_global_name()), n.get_index()])
		n = n.get_parent()
	return "/".join(bits)


static func _same(t: TestCase, what: String, a: Dictionary, b: Dictionary) -> void:
	var diff: Array[String] = []
	for k in a:
		if not b.has(k):
			diff.append("%s 只在七格那边" % k)
		elif not (a[k] as Rect2).is_equal_approx(b[k]):
			diff.append("%s %s → %s" % [k, a[k], b[k]])
	for k in b:
		if not a.has(k):
			diff.append("%s 只在九格那边" % k)
	t.check(diff.is_empty() and not a.is_empty(), "%s：七格 / 九格换人，%d 块面板一个像素不动%s" % [what, a.size(), ("（" + "；".join(diff) + "）") if not diff.is_empty() else ""])


## 九格位子里的棋盘水平居中
static func _centred(t: TestCase, what: String, nine: BoardNine) -> void:
	t.not_null(nine, "%s：棋盘坐在九格位子里" % what)
	if nine == null:
		return
	var c := nine.get_child(0) as Control
	var left := c.position.x
	var right := nine.size.x - c.position.x - c.size.x
	t.check(absf(left - right) <= 1.0, "%s：棋盘在九格位子里居中（左 %.0f / 右 %.0f）" % [what, left, right])
	t.eq(nine.size.x, CharacterDef.BOARD_MAX_W * nine.view.cell_px + 2.0 * nine.pad, "%s：位子九格宽 + 框两边" % what)


static func frame_node_screens(t: TestCase, root: Window) -> void:
	t.begin("255 补充一：节点屏（商店 / 保险箱）、搜刮屏、背包窗、战前屏 —— 七格 / 九格两个角色的面板一个像素不动，棋盘在九格位子里居中")
	var shots := {}
	for ch_id in [NARROW, WIDE]:
		var f := _flow("nine255_" + String(ch_id), ch_id)
		var got := {}
		# 商店（_mount_bag 那一路：皮带框套好再坐进九格位子）
		var shop = load("res://ui/game/shop_screen.gd").new()
		shop.flow = f
		shop.font = UiPalette.cjk_font()
		shop.screen = GameFlow.Screen.SHOP
		root.add_child(shop)
		shop.open({})
		_lay_out(shop)
		got["shop"] = _panels(shop)
		_centred(t, "商店 " + String(ch_id), shop._inv.nine)
		shop.queue_free()
		# 搜刮屏：自己摆框，背包那块位子按九格
		var box := LootPacker.board_of([&"knife"] as Array[StringName], Vector2i(6, 4), f.run.items)
		var loot = load("res://ui/game/container_screen.gd").new()
		loot.flow = f
		loot.font = UiPalette.cjk_font()
		loot.screen = GameFlow.Screen.LOOT
		root.add_child(loot)
		loot.open({"container": box})
		_lay_out(loot)
		loot._layout()
		got["loot"] = _panels(loot, [loot._player_frame, loot._inv])
		var frame: Rect2 = (loot._player_frame as Control).get_rect()
		var slot_w: float = CharacterDef.BOARD_MAX_W * loot._inv.board_view.cell_px
		var strip: Rect2 = loot._strip.get_rect()
		t.check(absf(frame.get_center().x - (strip.position.x + slot_w * 0.5)) <= 1.0, "搜刮屏 %s：棋盘框在九格位子（数值栏那么宽）里居中" % ch_id)
		loot.queue_free()
		# 背包窗
		var win := BagWindow.new()
		root.add_child(win)
		win.setup_bag(f.run, UiPalette.cjk_font(), func(): pass)
		_lay_out(win)
		got["bag"] = {"window": win.window_size(), "nameplate": win.nameplate.position, "card": win.card.position, "close": win.close_button.position,
			"frame_mid": win.frame.position.x + win.frame.size.x * 0.5}
		win.queue_free()
		shots[ch_id] = got
		Support.cleanup("nine255_" + String(ch_id))
	var a: Dictionary = shots[NARROW]
	var b: Dictionary = shots[WIDE]
	_same(t, "商店", a["shop"], b["shop"])
	_same(t, "搜刮屏", a["loot"], b["loot"])
	t.eq(a["bag"], b["bag"], "背包窗：窗大小、名牌、角色卡、收起钮、棋盘框的中线都不动")


static func frame_prebattle(t: TestCase, root: Window) -> void:
	t.begin("255 补充一：战前屏 —— 自己那列（名牌、九格位子、数值栏）七格 / 九格一个像素不动")
	var shots := {}
	for ch_id in [NARROW, WIDE]:
		var f := _flow("nine255p_" + String(ch_id), ch_id)
		var run := f.run
		var dist := MapNavigator.distance_map(run.map, run.travel.current_id)
		var target := -1
		for nid in dist:
			if run.map.get_node(int(nid)).type in [&"battle", &"elite"] and int(nid) != run.travel.current_id and (target < 0 or int(dist[nid]) < int(dist[target])):
				target = int(nid)
		t.check(target >= 0 and Support.walk_to(f, target, GameFlow.Screen.PREBATTLE) and f.screen == GameFlow.Screen.PREBATTLE, "%s：走到战前屏" % ch_id)
		var pre = load("res://ui/game/prebattle_screen.gd").new()
		pre.flow = f
		pre.font = UiPalette.cjk_font()
		pre.screen = GameFlow.Screen.PREBATTLE
		root.add_child(pre)
		pre.open(f.last_payload)
		_lay_out(pre)
		shots[ch_id] = {"nine": pre._inv.nine.get_global_rect() if pre._inv != null and pre._inv.nine != null else Rect2(),
			"strip": pre._player_strip.get_global_rect() if pre._player_strip != null else Rect2(),
			"right": pre._right.get_global_rect() if pre._right != null else Rect2()}
		if pre._inv != null:
			_centred(t, "战前屏 " + String(ch_id), pre._inv.nine)
		pre.queue_free()
		Support.cleanup("nine255p_" + String(ch_id))
	t.eq(shots[NARROW], shots[WIDE], "战前屏：九格位子、数值栏、自己那列不动")


static func frame_warehouse(t: TestCase, root: Window) -> void:
	t.begin("255 补充一：基地仓库页 —— 带回来的棋盘七格 / 九格，位子、格子边长、右边仓库一个像素不动")
	var shots := {}
	for cols in [7, 9]:
		var db := ItemDatabase.new()
		db.load_dir()
		var f := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new(), MetaState.new(GameFlow.load_meta_rules()))
		f.meta_path = "user://test_nine255_meta.json"
		f.settings_path = "user://test_nine255_settings.json"
		f.tech_defs = GameFlow.load_techs()
		f.meta.board = GridInventory.new(Vector2i(cols, 6), MetaState.BOARD_ID, false)
		var screen = load("res://ui/game/meta_screen.gd").new()
		screen.flow = f
		screen.font = UiPalette.cjk_font()
		screen.screen = GameFlow.Screen.META
		root.add_child(screen)
		screen.size = Vector2(1600, 1000)
		screen.open({"tab": "warehouse"})
		_lay_out(screen)
		var nines: Array = screen.find_children("*", "BoardNine", true, false)
		t.eq(nines.size(), 1, "%d 格：带回来的棋盘坐在九格位子里" % cols)
		if nines.size() == 1:
			_centred(t, "仓库页 %d 格" % cols, nines[0])
			shots[cols] = {"nine": (nines[0] as Control).get_global_rect(), "cell": (nines[0] as BoardNine).view.cell_px}
		screen.queue_free()
		MetaSave.remove(f.meta_path)
		GameSettings.remove(f.settings_path)
	t.eq(shots.get(7), shots.get(9), "九格位子与格子边长不随带回来的棋盘宽窄变")
