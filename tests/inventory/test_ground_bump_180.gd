## 180 §2.2（作者 2026-10-17 09:05 / 09:26）：棋盘外地上的道具不重叠，相遇半弹性弹开；墙与地面吸收大部分弹力，后续弹起很快衰减
extends RefCounted

const G := preload("res://tests/inventory/test_ground.gd")


static func _ground(stash: ItemStash, sz: Vector2 = G.SCREEN) -> GroundLayer:
	var ground := GroundLayer.new()
	ground.fills_screen = true
	ground.size = sz
	ground.stash = stash
	ground._sync_norms()
	return ground


## 放一件、不播落地（「本来就在」）
static func _put(stash: ItemStash, def: ItemDef, spot: Vector2) -> ItemInstance:
	var inst := ItemInstance.create(def)
	stash.insert(inst, -1, spot)
	stash.landing_from[inst.uid] = false
	return inst


static func run_overlap_bounces_apart(t: TestCase) -> void:
	t.begin("180 · 两件压在一起：沿重叠少的那条轴弹开、重的挪得少；很快贴住，终点写回落点；之后两两不相交")
	ItemInstance.reset_uid_counter()
	var light := G._def(&"t_light", ["11"])
	light.weight = 1
	var heavy := G._def(&"t_heavy", ["11"])
	heavy.weight = 4
	var stash := ItemStash.new(2, 0)
	var ground := _ground(stash)
	var a := _put(stash, light, Vector2(0.5, 0.5))
	var b := _put(stash, heavy, Vector2(0.5, 0.5) + Vector2(90.0, 0.0) / G.SCREEN)
	ground._scan()
	t.check(ground.is_bumping(), "压着就开始弹开")
	var a0 := ground.item_rect(a.uid).position
	var b0 := ground.item_rect(b.uid).position
	var gap0 := ground.overlapping_pairs().size()
	t.eq(gap0, 1, "起手一对相交")
	var sec := 0.0
	while ground.is_bumping() and sec < 2.0:
		ground.advance_bumps(1.0 / 60.0)
		sec += 1.0 / 60.0
	t.check(not ground.is_bumping(), "弹完了")
	t.check(sec < GroundLayer.BUMP_MAX_SEC, "没拖到兜底就贴住了（%.2f 秒）" % sec)
	t.check(ground.overlapping_pairs().is_empty(), "不再相交")
	var a1 := ground.item_rect(a.uid).position
	var b1 := ground.item_rect(b.uid).position
	t.check(absf(a1.y - a0.y) < 0.01 and absf(b1.y - b0.y) < 0.01, "横向压着就横向分开（竖直不动）")
	t.check(a1.x < a0.x and b1.x > b0.x, "各往各的一边")
	t.check(absf(b1.x - b0.x) < absf(a1.x - a0.x), "重的挪得少（轻 %.1f / 重 %.1f 像素）" % [absf(a1.x - a0.x), absf(b1.x - b0.x)])
	t.check(b1.x - (a1.x + 2 * InventoryView.CELL) < 2.0 * InventoryView.CELL, "一次分开就贴住，不会弹出老远（间隙 %.1f）" % (b1.x - a1.x - 2 * InventoryView.CELL))
	t.check(stash.spot_of(a.uid).is_equal_approx(ground.to_spot(a1)) and stash.spot_of(b.uid).is_equal_approx(ground.to_spot(b1)), "终点写回落点")
	ground._scan()
	t.check(not ground.is_bumping(), "写回之后再看：不再弹")
	ground.free()


static func run_wall_absorbs(t: TestCase) -> void:
	t.begin("180 · 墙与地面吸收弹力：撞墙 e = 0.15、反弹封顶 LAND_VMAX 的一半再乘 0.3；两次撞墙太近就贴住；推不出屏")
	ItemInstance.reset_uid_counter()
	var d := G._def(&"t_box", ["1"])
	var stash := ItemStash.new(2, 0)
	var ground := _ground(stash)
	var a := _put(stash, d, Vector2(0.0, 0.5))
	var b := _put(stash, d, Vector2(20.0, 0.0) / G.SCREEN + Vector2(0.0, 0.5))
	ground._scan()
	t.check(ground.is_bumping(), "贴着左墙的两件压着")
	var cap := GroundLayer.BUMP_WALL_VCAP * GroundLayer.LAND_VMAX * G.SCREEN.y * GroundLayer.BUMP_AFTER_WALL
	var worst := 0.0
	var hits := 0
	var out := 0
	for i in 240:
		if not ground.is_bumping():
			break
		ground.advance_bumps(GroundLayer.BUMP_STEP)
		if ground._bodies.has(a.uid):
			var body: Dictionary = ground._bodies[a.uid]
			if (body["pos"] as Vector2).x <= 0.0 and float(body["last"]) == ground._bump_t:
				hits += 1
				worst = maxf(worst, absf((body["vel"] as Vector2).x))
		if ground.item_rect(a.uid).position.x < 0.0:
			out += 1
	t.eq(out, 0, "每一步都没出屏")
	t.check(hits >= 1, "撞到了左墙（%d 次）" % hits)
	t.check(worst <= cap + 0.01, "撞墙后弹回的速度 %.1f ≤ %.1f 像素 / 秒" % [worst, cap])
	t.check(not ground.is_bumping() and ground.overlapping_pairs().is_empty(), "弹完、不相交")
	t.check(ground.item_rect(a.uid).position.x >= 0.0 and ground.item_rect(b.uid).end.x <= G.SCREEN.x, "都在屏内")
	ground.free()


static func run_landing_on_top_bounces(t: TestCase) -> void:
	t.begin("180 · 掉下来落在别人身上：落稳之后弹开；正在落的不算相交、不被撞")
	ItemInstance.reset_uid_counter()
	var d := G._def(&"t_slab", ["111"])
	var stash := ItemStash.new(2, 0)
	var ground := _ground(stash)
	var floor_y := G.SCREEN.y * (1.0 - ItemStash.SPOT_MARGIN) - InventoryView.CELL
	var a := _put(stash, d, Vector2(800.0, floor_y) / G.SCREEN)
	ground._scan()
	t.check(not ground.is_bumping(), "一件：没有可弹的")
	var b := ItemInstance.create(d)
	stash.insert(b, -1, Vector2(0.1, 0.1))
	stash.landing_from[b.uid] = ground.global_position + Vector2(830.0, 200.0)
	ground._scan()
	t.check(ground.is_landing(b.uid), "第二件在落")
	t.check(ground.overlapping_pairs().is_empty() and not ground.is_bumping(), "落的途中不算相交")
	ground.advance_landing(ground.landing_sec(b.uid) + 0.01)
	t.check(not ground.is_landing(b.uid), "落稳了")
	t.check(ground.is_bumping(), "落在第一件上：开始弹开")
	ground.settle_bumps()
	t.check(ground.overlapping_pairs().is_empty(), "弹开了")
	t.check(ground.item_rect(a.uid).end.y <= G.SCREEN.y * (1.0 - ItemStash.SPOT_MARGIN) + 0.01 and ground.item_rect(b.uid).end.y <= G.SCREEN.y * (1.0 - ItemStash.SPOT_MARGIN) + 0.01, "没被压进地面")
	ground.free()


static func run_crowded_falls_back(t: TestCase) -> void:
	t.begin("180 · 地上挤：一堆压在同一处 —— 弹完还相交的退回网格扫出的空处；最后两两不相交、都在屏内；读档后的重叠也弹开")
	ItemInstance.reset_uid_counter()
	var d := G._def(&"t_crate", ["11", "11"])
	var stash := ItemStash.new(2, 0)
	var sz := Vector2(900, 500)
	var ground := _ground(stash, sz)
	for i in 20:
		_put(stash, d, Vector2(0.4, 0.5))
	ground._scan()
	t.check(ground.is_bumping(), "压成一堆：弹开")
	ground.settle_bumps()
	t.check(ground.overlapping_pairs().is_empty(), "两两不相交（%s）" % [ground.overlapping_pairs()])
	var inside := true
	for inst in stash.items():
		var r := ground.item_rect((inst as ItemInstance).uid)
		inside = inside and r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= sz.x + 0.01 and r.end.y <= sz.y + 0.01
	t.check(inside, "都在屏内")
	ground.free()

	# 读档：旧档里的落点压着 —— 接上这片地就弹开
	var saved := ItemStash.new(3, 0)
	var x := ItemInstance.create(d)
	var y := ItemInstance.create(d)
	saved.insert(x, -1, Vector2(0.3, 0.3))
	saved.insert(y, -1, Vector2(0.3, 0.3))
	var g2 := _ground(saved)
	t.check(g2.landing_uids().is_empty(), "读档的不播落地")
	t.check(g2.is_bumping(), "但压着的弹开")
	g2.settle_bumps()
	t.check(g2.overlapping_pairs().is_empty(), "弹开了")
	g2.free()
