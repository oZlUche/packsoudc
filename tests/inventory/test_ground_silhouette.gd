## 198（作者 2026-10-19）：掉在地上的道具按轮廓碰撞，不按格子的包围盒。没图时轮廓 = 格子外形，有图按透明通道
extends RefCounted

const G := preload("res://tests/inventory/test_ground.gd")
const B := preload("res://tests/inventory/test_ground_bump_180.gd")
const CELL := InventoryView.CELL


static func _diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])


static func _floor_y() -> float:
	return G.SCREEN.y * (1.0 - ItemStash.SPOT_MARGIN)


static func run_sat_slanted(t: TestCase) -> void:
	t.begin("198 · 分离轴：两块斜放的凸块沿斜边的法线分开，深度对；顺序反过来方向也反；分开的深度 0")
	var a := [_diamond(Vector2.ZERO, 50.0)]
	var b := [_diamond(Vector2.ZERO, 50.0)]
	var hit := ItemSilhouette.separate(a, Vector2.ZERO, b, Vector2(30, 30))
	var n: Vector2 = hit["n"]
	t.check(n.is_equal_approx(Vector2(1, 1).normalized()), "斜着分开：n = %s" % n)
	t.check(absf(float(hit["depth"]) - 20.0 * sqrt(2.0)) < 0.01, "深度 20√2（%.3f）" % float(hit["depth"]))
	var back := ItemSilhouette.separate(b, Vector2(30, 30), a, Vector2.ZERO)
	t.check((back["n"] as Vector2).is_equal_approx(-n), "反过来方向也反")
	t.eq(float(ItemSilhouette.separate(a, Vector2.ZERO, b, Vector2(60, 60))["depth"]), 0.0, "包围盒相交、轮廓不相交：深度 0")
	t.eq(float(ItemSilhouette.separate(a, Vector2.ZERO, b, Vector2(200, 0))["depth"]), 0.0, "离得远：深度 0")


static func run_rect_same_as_180(t: TestCase) -> void:
	t.begin("198 · 矩形件和 180 的包围盒解算完全一样：重叠少的轴、深度、方向（中心重合按先后）")
	var rng := RandomNumberGenerator.new()
	rng.seed = 198
	var bad := 0
	for i in 300:
		var ra := Rect2(Vector2(rng.randi_range(0, 4), rng.randi_range(0, 4)) * 30.0, Vector2(rng.randi_range(1, 3), rng.randi_range(1, 3)) * CELL)
		var rb := Rect2(Vector2(rng.randi_range(0, 4), rng.randi_range(0, 4)) * 30.0, Vector2(rng.randi_range(1, 3), rng.randi_range(1, 3)) * CELL)
		var tie := 1.0 if i % 2 == 0 else -1.0
		var o := Vector2(minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x), minf(ra.end.y, rb.end.y) - maxf(ra.position.y, rb.position.y))
		var want_depth := 0.0
		var want_n := Vector2.ZERO
		if o.x > 0.0 and o.y > 0.0:
			var d := rb.get_center() - ra.get_center()
			if o.x <= o.y:
				want_n = Vector2(signf(d.x) if absf(d.x) > 0.01 else tie, 0.0)
				want_depth = o.x
			else:
				want_n = Vector2(0.0, signf(d.y) if absf(d.y) > 0.01 else tie)
				want_depth = o.y
		var got := ItemSilhouette.separate([ItemSilhouette.rect_poly(Rect2(Vector2.ZERO, ra.size))], ra.position,
			[ItemSilhouette.rect_poly(Rect2(Vector2.ZERO, rb.size))], rb.position, tie)
		if absf(float(got["depth"]) - want_depth) > 0.001 or (want_depth > 0.0 and not (got["n"] as Vector2).is_equal_approx(want_n)):
			bad += 1
	t.eq(bad, 0, "300 对随机矩形全部一致")


static func run_cells_outline(t: TestCase) -> void:
	t.begin("198 · 没图：轮廓 = 格子外形（外轮廓沿格边、凸块是整格矩形、面积 = 格数、重心 = 占格中心平均、没有位图）")
	ItemSilhouette.clear()
	var ell := G._def(&"t_ell", ["1.", "11"])
	var sil := ItemSilhouette.of(ell, 0)
	t.is_null(sil["mask"], "没图：没有位图")
	var outline: Array = sil["outline"]
	t.eq(outline.size(), 1, "一圈外轮廓")
	var pts := {}
	for p in (outline[0] as PackedVector2Array):
		pts[p] = true
	var want := [Vector2(0, 0), Vector2(60, 0), Vector2(60, 60), Vector2(120, 60), Vector2(120, 120), Vector2(0, 120)]
	var same := pts.size() == want.size()
	for p in want:
		same = same and pts.has(p)
	t.check(same, "L 的外轮廓六个角：%s" % [outline[0]])
	var parts: Array = sil["parts"]
	t.eq(parts.size(), 2, "两块凸块")
	var area := 0.0
	for poly in parts:
		area += absf(ItemSilhouette._area(poly))
	t.eq(area, 3.0 * CELL * CELL, "凸块面积 = 3 格")
	t.eq(sil["bounds"], Rect2(Vector2.ZERO, Vector2(2, 2) * CELL), "包围盒 = 格子包围盒")
	t.eq(ItemSilhouette.centroid(ell, 1), ell.shape.center_of_mass(1) * CELL, "重心 = 占格中心平均")
	var slab := G._def(&"t_slab2", ["111", "111"])
	t.eq((ItemSilhouette.of(slab, 1)["parts"] as Array).size(), 1, "矩形件：一块")
	t.eq(ItemSilhouette.of(slab, 1)["bounds"], Rect2(Vector2.ZERO, Vector2(2, 3) * CELL), "转过来的包围盒")
	var ring := G._def(&"t_ring", ["111", "1.1", "111"])
	t.eq((ItemSilhouette.of(ring, 0)["outline"] as Array).size(), 1, "中间有洞的：只要外圈")
	var many := G._def(&"t_comb", ["1.1.1.1", "1111111", "1.1.1.1"])
	t.eq((ItemSilhouette.of(many, 0)["parts"] as Array).size(), 1, "凸块多于 6：退成一块凸包")


static func run_notch_fits(t: TestCase) -> void:
	t.begin("198 · L 的缺角里放一件 1 × 1：贴着不算重叠、不弹；从上面掉下来落进缺角（落在 L 的下一行上）")
	ItemInstance.reset_uid_counter()
	var ell := G._def(&"t_ell", ["1.", "11"])
	var one := G._def(&"t_one", ["1"])
	var stash := ItemStash.new(2, 0)
	var ground := B._ground(stash)
	var floor_y := _floor_y()
	var at := Vector2(600.0, floor_y - 2 * CELL)
	var l := B._put(stash, ell, at / G.SCREEN)
	var s := B._put(stash, one, (at + Vector2(CELL, 0)) / G.SCREEN)
	ground._scan()
	t.check(ground.item_rect(l.uid).intersects(ground.item_rect(s.uid)), "包围盒是相交的（以前会弹开）")
	t.check(ground.overlapping_pairs().is_empty() and not ground.is_bumping(), "按轮廓：不相交、不弹")
	stash.remove(s.uid)
	ground._scan()
	var c := ItemInstance.create(one)
	stash.insert(c, -1, Vector2(0.1, 0.1))
	stash.landing_from[c.uid] = ground.global_position + Vector2(at.x + CELL + 0.0, 100.0)
	ground._scan()
	ground.advance_landing(ground.landing_sec(c.uid) + 0.01)
	var r := ground.item_rect(c.uid)
	t.check(absf(r.end.y - (floor_y - CELL)) < 0.5, "落在 L 的下一行上（底 %.1f）" % r.end.y)
	t.check(ground.overlapping_pairs().is_empty() and not ground.is_bumping(), "落进缺角：不相交、不弹")
	stash.remove(l.uid)
	ground._scan()
	t.check(ground.is_landing(c.uid), "L 拿走了：接着掉")
	ground.free()


static func run_rest_on_support(t: TestCase) -> void:
	t.begin("198 · 落稳朝向按轮廓：重心在支撑面上方（T 横杠朝下、长条躺平、方块不转）；有稳的就不选不稳的")
	ItemSilhouette.clear()
	var tee := G._def(&"t_tee", ["111", ".1.", ".1."])
	var r_tee := ItemSilhouette.rest_rotation(tee, 0)
	var sil := ItemSilhouette.of(tee, r_tee)
	var sup := ItemSilhouette.support_span(sil)
	var c: Vector2 = sil["centroid"]
	t.check(c.x >= sup.x and c.x <= sup.y, "T：重心 x %.1f 在支撑 %s 上" % [c.x, sup])
	t.eq(sup, Vector2(0, 3 * CELL), "T 横杠朝下（支撑是整条横杠）")
	var bar := G._def(&"t_bar", ["1", "1", "1"])
	t.eq(bar.shape.size_rotated(ItemSilhouette.rest_rotation(bar, 0)), Vector2i(3, 1), "长条躺平")
	var sq := G._def(&"t_sq", ["11", "11"])
	t.eq(ItemSilhouette.rest_rotation(sq, 2), 2, "方块不转")
	# 每种形状：四个朝向里有稳的，选中的就一定稳
	var shapes := [["1.", "11"], ["11", "1.", "1."], ["111", "1.."], [".11", "11."], ["1.1", "111"], ["11.", ".1.", ".11"], ["1..", "111", "..1"]]
	var bad := []
	for rows in shapes:
		var d := G._def(&"t_any", rows)
		var any_stable := false
		for rot in 4:
			any_stable = any_stable or _stable(ItemSilhouette.of(d, rot))
		for rot in 4:
			if any_stable and not _stable(ItemSilhouette.of(d, ItemSilhouette.rest_rotation(d, rot))):
				bad.append([rows, rot])
	t.eq(bad, [], "有稳的朝向就落成稳的")
	# 以前（只看重心高度）会立成重心悬空的那种：一级台阶，矮的那头宽
	var step := G._def(&"t_step", ["1..", "111", "..1"])
	var old := step.shape.rest_rotation(0)
	var now := ItemSilhouette.rest_rotation(step, 0)
	t.check(_stable(ItemSilhouette.of(step, now)), "Z 形：落成稳的（以前 %d 稳不稳：%s，现在 %d）" % [old, _stable(ItemSilhouette.of(step, old)), now])


static func _stable(sil: Dictionary) -> bool:
	var sup := ItemSilhouette.support_span(sil)
	var c: Vector2 = sil["centroid"]
	return c.x >= sup.x - 0.01 and c.x <= sup.y + 0.01


static func run_concave_settle(t: TestCase) -> void:
	t.begin("198 · L、T、长条、方块压成一堆：按轮廓弹开，收尾后两两不相交、都在屏内；落点照旧是归一化的 [x, y]（斜着的多一项）")
	ItemInstance.reset_uid_counter()
	var defs := [G._def(&"t_ell", ["1.", "11"]), G._def(&"t_tee", ["111", ".1."]), G._def(&"t_bar", ["111"]), G._def(&"t_sq", ["11", "11"])]
	var stash := ItemStash.new(2, 0)
	var sz := Vector2(1200, 700)
	var ground := B._ground(stash, sz)
	for i in 12:
		B._put(stash, defs[i % defs.size()], Vector2(0.45, 0.6) + Vector2(i * 7.0, 0.0) / sz)
	ground._scan()
	t.check(ground.is_bumping(), "压成一堆：弹开")
	ground.settle_bumps()
	t.check(ground.overlapping_pairs().is_empty(), "两两不相交（%s）" % [ground.overlapping_pairs()])
	var inside := true
	for inst in stash.items():
		var r := ground.item_rect((inst as ItemInstance).uid)
		inside = inside and r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= sz.x + 0.01 and r.end.y <= sz.y + 0.01
	t.check(inside, "都在屏内")
	var saved := stash.to_dict()
	var ok := (saved["spots"] as Array).size() == stash.item_count()
	for p in (saved["spots"] as Array):
		ok = ok and p is Array and (p as Array).size() in [2, 3] and float(p[0]) >= 0.0 and float(p[0]) <= 1.0 and float(p[1]) >= 0.0 and float(p[1]) <= 1.0
	t.check(ok, "存档 spots 仍是每件一个 [x, y]（0 ～ 1；198 补充一：斜着的多一项斜度）")
	ground.free()


static func run_alpha_outline(t: TestCase) -> void:
	t.begin("198 · 有图：透明通道 → 位图（往外长 2 像素）→ 外轮廓 → 凸块；透明的角点不着；转 90° 跟着转")
	var img := Image.create(120, 60, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	for x in 24:
		for y in 24:
			if x + y < 24:
				img.set_pixel(x, y, Color(0, 0, 0, 0))     # 左上角切掉一个三角
	var png := img.save_png_to_buffer()
	var loaded := Image.new()
	loaded.load_png_from_buffer(png)
	var sil := ItemSilhouette.from_image(loaded, 0)
	var mask: BitMap = sil["mask"]
	t.check(mask != null, "有位图")
	t.check(not mask.get_bitv(Vector2i(3, 3)), "透明的角：点不着")
	t.check(mask.get_bitv(Vector2i(60, 30)) and mask.get_bitv(Vector2i(119, 0)), "实心处点得着")
	var outline: PackedVector2Array = (sil["outline"] as Array)[0]
	t.check(not outline.has(Vector2.ZERO), "外轮廓绕开了切掉的角")
	var box: Rect2 = sil["bounds"]
	t.check(Rect2(Vector2.ZERO, Vector2(120, 60)).grow(0.01).encloses(box), "凸块不超出画布（%s）" % box)
	var parts: Array = sil["parts"]
	t.check(parts.size() >= 1 and parts.size() <= ItemSilhouette.MAX_PARTS, "凸块 %d 块（≤ 6）" % parts.size())
	var corner := ItemSilhouette.separate(parts, Vector2.ZERO, [ItemSilhouette.rect_poly(Rect2(0, 0, 6, 6))], Vector2.ZERO)
	t.eq(float(corner["depth"]), 0.0, "切掉的角里放一块小方块：不碰")
	var c: Vector2 = sil["centroid"]
	t.check(c.x > 60.0 and c.y > 30.0, "重心往实心那边偏（%s）" % c)
	var turned := ItemSilhouette.from_image(loaded, 1)
	var tm: BitMap = turned["mask"]
	t.eq(tm.get_size(), Vector2i(60, 120), "转 90°：画布竖过来")
	t.check(not tm.get_bitv(Vector2i(57, 2)) and tm.get_bitv(Vector2i(2, 2)), "切掉的角转到右上")
	var big := ItemSilhouette.from_image(loaded, 0, Vector2i(240, 120))
	t.eq((big["mask"] as BitMap).get_size(), Vector2i(240, 120), "按格子画布缩放")
