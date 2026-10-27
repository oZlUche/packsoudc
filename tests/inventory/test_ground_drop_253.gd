## 253（作者 2026-10-25「1. 道具的碰撞要无视左下角和右下角的UI组件，直接掉落在前面 2. 道具拿出棋盘外时有时候会吸附在背包界面的边缘，尤其是上缘 3. 道具拿出时有时候会卡住不动」）：
## 只有顶端栏占地；登记面板不当桌面 / 墙（掉过去、落稳后才推开）；光标出棋盘半格以上就是地上；半空不冻住、甩出去撞屏边不粘
extends RefCounted

const G := preload("res://tests/inventory/test_ground.gd")
const B := preload("res://tests/inventory/test_ground_bump_180.gd")
const D := preload("res://tests/inventory/test_drag_layer.gd")
const W := preload("res://tests/inventory/test_ground_throw_249.gd")
const Top := preload("res://tests/ui/test_topbar_235.gd")
const CELL := InventoryView.CELL


static func frame_hud_corners(t: TestCase, root: Window) -> void:
	t.begin("253 §1.1 / 作者 10-27「界面和道具彻底分离成两层」：开一局的 HUD —— 没有一块组件占地（地层根本没有登记面板这回事）")
	var keep := GroundLayer.current()
	var ground := GroundLayer.new()
	ground.size = G.SCREEN
	root.add_child(ground)
	GroundLayer.set_current(ground)
	var screen := Control.new()
	screen.size = G.SCREEN
	root.add_child(screen)
	var got := Top._host(root, screen)
	GroundLayer.set_current(keep)
	if got.is_empty():
		t.check(false, "开不了局")
		return
	var host: HudHost = got[0]
	t.check(host.widgets.size() > 1, "场上不止顶端栏（%s）" % str(host.widgets.keys()))
	t.check(host.widget(&"hud_bar") != null, "顶端栏在场")
	t.eq(ground.has_method(&"reserve"), false, "地层没有登记面板的口子：界面不占地")
	host.free()
	screen.free()
	ground.free()


static func frame_panel_not_a_shelf(t: TestCase, root: Window) -> void:
	t.begin("253 §1.2 / 作者 10-27 两层：松手点在背包窗正上方 —— 掉过窗面落到屏幕底，不停在上沿；松手点压在窗上的也原地竖直掉，不推开（盖在窗前面）")
	ItemInstance.reset_uid_counter()
	var stash := ItemStash.new(2, 0)
	var ground := B._ground(stash)
	var host := Control.new()
	host.size = G.SCREEN
	root.add_child(host)
	host.add_child(ground)
	var panel := Control.new()
	panel.position = Vector2(500, 300)
	panel.size = Vector2(500, 300)
	host.add_child(panel)
	var floor_y := G.SCREEN.y * (1.0 - ItemStash.SPOT_MARGIN)
	var box := G._def(&"t_box253", ["11"])
	var a := ItemInstance.create(box)
	stash.insert(a, -1, Vector2(0.1, 0.1))
	stash.landing_from[a.uid] = Vector2(700, 150)
	var on := ItemInstance.create(box)
	stash.insert(on, -1, Vector2(0.1, 0.1))
	stash.landing_from[on.uid] = Vector2(560, 400)     # 压在窗上
	ground._scan()
	ground.advance_landing(5.0)
	ground.settle_bumps()
	var ra := ground.item_rect(a.uid)
	t.check(absf(ra.end.y - floor_y) < 0.5 and absf(ra.position.x - 700.0) < 0.5, "掉过窗面落到屏幕底（%s）" % ra)
	t.eq(ground.supports_of(a.uid).has("panel"), false, "托着谁里不再有面板")
	var ro := ground.item_rect(on.uid)
	t.check(absf(ro.end.y - floor_y) < 0.5 and absf(ro.position.x - 560.0) < 0.5, "压在窗上松手：原地竖直掉到地上，不往窗外推（%s）" % ro)
	host.free()


static func run_snap_back_half_cell(t: TestCase) -> void:
	t.begin("253 §1.3：抓着 1×3 长条上端往上拖出棋盘 —— 光标出上沿 0.4 格仍落回棋盘（吸进第一行），0.6 格就是地上（哪怕整块还有一半多压着棋盘）")
	ItemInstance.reset_uid_counter()
	var bar := D._def("bar253", ["1", "1", "1"])
	var inv := GridInventory.new(Vector2i(6, 6), 1)
	var view := D._view(inv, Vector2(100, 200))
	var drag := DragLayer.new()
	drag.register_view(view)
	var a := ItemInstance.create(bar)
	inv.place(a, Vector2i(2, 0), 0)
	drag._on_grab_requested(view, a.uid, Vector2(0.5, 0.5) * CELL)     # 抓最上面那格
	t.check(drag.is_dragging(), "抓起来了")
	var x := view.position.x + 2.5 * CELL
	t.check(drag.view_at(Vector2(x, view.position.y - 0.4 * CELL)) == view, "出上沿 0.4 格：仍是棋盘")
	t.eq(drag.target_origin(view, Vector2(x, view.position.y - 0.4 * CELL)).y, 0, "吸进第一行")
	t.check(drag.view_at(Vector2(x, view.position.y - 0.6 * CELL)) == null, "出上沿 0.6 格：地上（整块还有 1.9 格压着棋盘也不算）")
	drag.cancel()
	drag.free()
	view.free()


static func run_airborne_never_sleeps(t: TestCase) -> void:
	t.begin("253 §1.4：甩上去在半空里的不计醒着的时长、不冻住（以前满 %.1f 秒就冻在半空）；落地后照常静下来" % GroundLayer.BUMP_MAX_SEC)
	ItemInstance.reset_uid_counter()
	var stash := ItemStash.new(2, 0)
	var ground := B._ground(stash)
	var h := G.SCREEN.y
	var floor_y := h * (1.0 - ItemStash.SPOT_MARGIN)
	var inst := W._throw(stash, ground, W._def(&"t_up253", ["1"], 1), Vector2(800, floor_y - CELL - 2.0), Vector2(0.0, -GroundLayer.THROW_VMAX * h))
	t.check(ground.is_bumping(), "甩出去了")
	var y0 := ground.item_rect(inst.uid).position.y
	var sec := 0.0
	while sec < 1.4:
		ground.advance_bumps(GroundLayer.BUMP_STEP)
		sec += GroundLayer.BUMP_STEP
	var b: Dictionary = ground._bodies.get(inst.uid, {})
	t.check(not b.is_empty() and not bool(b["asleep"]), "1.4 秒还醒着")
	t.check(not b.is_empty() and float(b["age"]) < 0.05, "半空不计醒着的时长（%s）" % str(b.get("age", -1)))
	t.check(ground.item_rect(inst.uid).position.y < y0 - 10.0, "还在半空，位置在变")
	ground.settle_bumps()
	t.check(absf(ground.item_rect(inst.uid).end.y - floor_y) < 1.0, "落地静下来（%s）" % ground.item_rect(inst.uid))


static func run_thrown_wall_not_sticky(t: TestCase) -> void:
	t.begin("253 §1.4：甩出去还没落地的撞屏边 —— 只按 e_wall 反弹，不夹 0.25 屏高、不再乘 0.3（以前撞一下就像粘住了）")
	ItemInstance.reset_uid_counter()
	var stash := ItemStash.new(2, 0)
	var ground := B._ground(stash)
	var h := G.SCREEN.y
	var v := GroundLayer.THROW_VMAX * h
	var inst := W._throw(stash, ground, W._def(&"t_side253", ["1"], 1), Vector2(G.SCREEN.x - CELL - 60.0, 150.0), Vector2(v, 0.0))
	var bounced := 0.0
	var sec := 0.0
	while sec < 0.5 and bounced == 0.0:
		ground.advance_bumps(GroundLayer.BUMP_STEP)
		sec += GroundLayer.BUMP_STEP
		var b: Dictionary = ground._bodies.get(inst.uid, {})
		if not b.is_empty() and (b["vel"] as Vector2).x < 0.0:
			bounced = -(b["vel"] as Vector2).x
	t.check(bounced > 0.0, "撞了右边弹回来")
	t.check(bounced > 0.5 * GroundLayer.BUMP_E_WALL * v, "弹回的速度按 e_wall（%.0f，迎面 %.0f）" % [bounced, v])
	ground.free()
