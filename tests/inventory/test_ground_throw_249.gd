## 249（作者 2026-10-24）：丢到地上的东西带着手上的速度飞出去（受密度影响）—— 拖拽层记松手前的鼠标、算速度 × 密度因子；
## 够快的起手就是 198 解算里醒着的刚体（重力、撞墙、滑行都交给它），太慢的、没手上速度的（右键放地上）照旧竖直掉
extends RefCounted

const G := preload("res://tests/inventory/test_ground.gd")
const B := preload("res://tests/inventory/test_ground_bump_180.gd")
const T198 := preload("res://tests/inventory/test_ground_tilt_198.gd")
const CELL := InventoryView.CELL


static func _def(id: StringName, rows: Array, weight: int) -> ItemDef:
	var d := G._def(id, rows)
	d.weight = weight
	return d


## 从 [param top_left]（本控件内像素）甩出去，速度 [param vel]（像素 / 秒，已乘密度因子）
static func _throw(stash: ItemStash, ground: GroundLayer, def: ItemDef, top_left: Vector2, vel: Vector2) -> ItemInstance:
	var inst := ItemInstance.create(def)
	stash.insert(inst, -1, Vector2(0.1, 0.1))
	stash.landing_from[inst.uid] = ground.global_position + top_left
	if vel != Vector2.ZERO:
		stash.landing_vel[inst.uid] = vel
	ground._scan()
	return inst


static func run_throw_flies(t: TestCase) -> void:
	t.begin("249 §三：向右甩 1 屏高 / 秒 —— 不走竖直掉、起手就在解算里；停下时在松手点右边、躺在地上；第一次撞地响一声")
	ItemInstance.reset_uid_counter()
	var stash := ItemStash.new(2, 0)
	var ground := B._ground(stash)
	var h := G.SCREEN.y
	var cues: Array = []
	ground.thrown_landed.connect(func(uid: int): cues.append(uid))
	var start := Vector2(300.0, 200.0)
	var box := _throw(stash, ground, _def(&"t_box", ["11", "11"], 4), start, Vector2(h, 0.0))
	t.check(not ground.is_landing(box.uid), "不进竖直掉")
	t.check(ground.is_bumping(), "起手就在解算里")
	t.check(ground.item_rect(box.uid).position.is_equal_approx(start), "从松手点起飞（%s）" % str(ground.item_rect(box.uid).position))
	T198._run(ground)
	var r := ground.item_rect(box.uid)
	t.check(r.position.x > start.x + CELL, "停在松手点右边（%.0f → %.0f）" % [start.x, r.position.x])
	t.check(absf(ground.item_bounds(box.uid).end.y - T198._floor_y()) < 2.0, "躺在地上")
	t.eq(cues, [box.uid], "第一次撞地响一声，之后的小碰不响")
	t.check(stash.landing_vel.is_empty(), "速度读完即删")
	ground.free()


static func run_density(t: TestCase) -> void:
	t.begin("249 §三：受密度影响 —— 手一样快，每格重 4 的比每格重 1 的飞得近；因子 = 1 / (1 + 密度 / 2)，包 = 1")
	var light := _def(&"t_wood", ["11"], 2)
	var heavy := _def(&"t_iron", ["11"], 8)
	t.check(is_equal_approx(GroundLayer.throw_factor(light), 1.0 / 1.5), "每格 1：× 0.67")
	t.check(is_equal_approx(GroundLayer.throw_factor(heavy), 1.0 / 3.0), "每格 4：× 0.33")
	var bag := G._def(&"t_bag", ["11"])
	bag.is_bag = true
	t.check(is_equal_approx(GroundLayer.throw_factor(bag), 1.0), "包重 0：× 1")
	var travel := {}
	for def in [light, heavy]:
		ItemInstance.reset_uid_counter()
		var stash := ItemStash.new(2, 0)
		var ground := B._ground(stash)
		var start := Vector2(200.0, 300.0)
		var hand := Vector2(G.SCREEN.y * 1.2, -G.SCREEN.y * 0.3)
		var inst := _throw(stash, ground, def, start, hand * GroundLayer.throw_factor(def))
		T198._run(ground)
		travel[def.id] = ground.item_rect(inst.uid).position.x - start.x
		ground.free()
	t.check(float(travel[&"t_iron"]) < float(travel[&"t_wood"]), "重的飞得近（木 %.0f / 铁 %.0f 像素）" % [travel[&"t_wood"], travel[&"t_iron"]])


static func run_slow_and_none(t: TestCase) -> void:
	t.begin("249 §三：慢的（< THROW_MIN）和没手上速度的（右键放地上、双击）照旧竖直掉")
	ItemInstance.reset_uid_counter()
	var stash := ItemStash.new(2, 0)
	var ground := B._ground(stash)
	var slow := _throw(stash, ground, _def(&"t_a", ["1"], 1), Vector2(400.0, 100.0), Vector2(G.SCREEN.y * (GroundLayer.THROW_MIN * 0.5), 0.0))
	t.check(ground.is_landing(slow.uid), "太慢：竖直掉")
	var none := _throw(stash, ground, _def(&"t_b", ["1"], 1), Vector2(900.0, 100.0), Vector2.ZERO)
	t.check(ground.is_landing(none.uid), "没速度：竖直掉")
	ground.advance_landing(0.2)
	t.check(ground.landing_speed(none.uid) > 0.0, "落的速度是竖直的重力速度")
	T198._run(ground)
	t.check(absf(ground.item_rect(slow.uid).position.x - 400.0) < CELL and absf(ground.item_rect(none.uid).position.x - 900.0) < CELL, "x 不变（竖直掉）")
	ground.free()


static func run_edge(t: TestCase) -> void:
	t.begin("249 §三：朝屏边狠甩（封顶 THROW_VMAX）—— 停在屏内、躺在地上")
	ItemInstance.reset_uid_counter()
	var stash := ItemStash.new(2, 0)
	var ground := B._ground(stash)
	var inst := _throw(stash, ground, _def(&"t_rod", ["111"], 3), Vector2(1400.0, 300.0), Vector2(G.SCREEN.y * 5.0, -G.SCREEN.y))
	T198._run(ground)
	var r := ground.item_bounds(inst.uid)
	t.check(r.position.x >= -0.5 and r.end.x <= G.SCREEN.x + 0.5, "在屏内（%s）" % str(r))
	t.check(absf(r.end.y - T198._floor_y()) < 2.0, "躺在地上")
	ground.free()


static func run_release_velocity(t: TestCase) -> void:
	t.begin("249 §三：拖拽层算手上的速度 —— 最近 90 ms 里最早那个样本到松手点；停住了再放手 = 零；拖出棋盘松手写 landing_vel（× 密度因子）")
	ItemInstance.reset_uid_counter()
	var drag := DragLayer.new()
	drag.record_motion(Vector2(0, 0), 10.00)
	drag.record_motion(Vector2(50, 0), 10.03)
	drag.record_motion(Vector2(100, 0), 10.06)
	var v := drag.release_velocity(Vector2(150, 0), 10.09)
	t.check(v.is_equal_approx(Vector2(150.0 / 0.09, 0.0)), "匀速向右：%s 像素 / 秒" % str(v))
	t.eq(drag.release_velocity(Vector2(150, 0), 10.5), Vector2.ZERO, "停住 0.4 秒才放手：零")
	for i in 20:
		drag.record_motion(Vector2(i, 0), 20.0 + i * 0.001)
	t.eq(drag._motion.size(), GroundLayer.THROW_SAMPLES, "最多留 %d 个样本" % GroundLayer.THROW_SAMPLES)
	drag.free()
	# 拖出棋盘松手：写 landing_vel
	var gun := _def(&"t_gun", ["1"], 1)
	var board := GridInventory.new(Vector2i(4, 4), 1)
	var stash := ItemStash.new(2, 0)
	var rig := G._rig(stash, board)
	var view: InventoryView = rig["view"]
	var d2: DragLayer = rig["drag"]
	var a := ItemInstance.create(gun)
	board.place(a, Vector2i(0, 0), 0)
	view.grab_requested.emit(view, a.uid, Vector2(24, 24))
	var now := Time.get_ticks_usec() / 1000000.0
	var release := Vector2(0.5, 0.5) * G.SCREEN
	d2.record_motion(release - Vector2(60, 0), now - 0.05)
	t.check(d2.drop_at(release), "放到棋盘外")
	var lv: Vector2 = stash.landing_vel.get(a.uid, Vector2.ZERO)
	t.check(lv.x > 0.0 and absf(lv.y) < 0.001, "写了向右的速度（%s）" % str(lv))
	t.check(lv.x < 60.0 / 0.05 * GroundLayer.throw_factor(gun) * 1.01, "乘了密度因子")
	G._free(rig)
