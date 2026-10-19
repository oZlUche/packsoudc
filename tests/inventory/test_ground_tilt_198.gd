## 198 补充一（作者 2026-10-19 选「自由角度」）：地上的东西可以斜着躺 —— 掉在堆上会翻、会靠、会滑到停；捡起来还是四向之一
extends RefCounted

const G := preload("res://tests/inventory/test_ground.gd")
const B := preload("res://tests/inventory/test_ground_bump_180.gd")
const CELL := InventoryView.CELL
const DT := 1.0 / 60.0


static func _floor_y() -> float:
	return G.SCREEN.y * (1.0 - ItemStash.SPOT_MARGIN)


## 一件从 [param top_left]（本控件内像素，包围盒左上角）掉下来
static func _drop(stash: ItemStash, ground: GroundLayer, def: ItemDef, top_left: Vector2, rot: int = 0) -> ItemInstance:
	var inst := ItemInstance.create(def, rot)
	stash.insert(inst, -1, Vector2(0.1, 0.1))
	stash.landing_from[inst.uid] = ground.global_position + top_left
	ground._scan()
	return inst


## 摆在地上（包围盒左上角 x，底贴地），不播落地
static func _on_floor(stash: ItemStash, def: ItemDef, x: float, rot: int = 0) -> ItemInstance:
	var inst := ItemInstance.create(def, rot)
	var span := Vector2(def.shape.size_rotated(rot)) * CELL
	stash.insert(inst, -1, Vector2(x, _floor_y() - span.y) / G.SCREEN)
	stash.landing_from[inst.uid] = false
	return inst


## 推时间直到都落稳、都睡着（或到 [param max_sec]）；返回用了多久
static func _run(ground: GroundLayer, max_sec: float = 8.0) -> float:
	var sec := 0.0
	while (ground.is_bumping() or not ground.landing_uids().is_empty()) and sec < max_sec:
		ground.advance_landing(DT)
		ground.advance_bumps(DT)
		sec += DT
	return sec


## 朝向 [param rot]、不斜时包围盒左上角在 [param pos]、斜 [param ang] 的外轮廓顶点
static func _outline(def: ItemDef, rot: int, pos: Vector2, ang: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for poly in (ItemSilhouette.tilted(ItemSilhouette.of(def, rot), ang)["outline"] as Array):
		out.append_array(ItemSilhouette.turn(poly, Vector2.ZERO, 0.0, pos))
	return out


## 画面上的外轮廓顶点（本控件内像素）
static func _outline_world(ground: GroundLayer, uid: int) -> PackedVector2Array:
	var inst := ground.stash.get_item(uid)
	var sil := ItemSilhouette.tilted(ItemSilhouette.of(inst.def, inst.rotation), ground.tilt_of(uid))
	var out := PackedVector2Array()
	for poly in (sil["outline"] as Array):
		out.append_array(ItemSilhouette.turn(poly, Vector2.ZERO, 0.0, ground.item_rect(uid).position))
	return out


static func _same_points(a: PackedVector2Array, b: PackedVector2Array, tol: float) -> bool:
	if a.size() != b.size():
		return false
	for p in a:
		var found := false
		for q in b:
			if p.distance_to(q) <= tol:
				found = true
				break
		if not found:
			return false
	return true


## 画面上转了多少（度）：四向换了几下 × 90 + 斜度
static func _visual_deg(inst: ItemInstance, rot0: int, ground: GroundLayer) -> float:
	return wrapf(posmod(inst.rotation - rot0, 4) * 90.0 + rad_to_deg(ground.tilt_of(inst.uid)), -180.0, 180.0)


static func run_flat_floor(t: TestCase) -> void:
	t.begin("198 补充一 · 平地：长条、方块、L 落在平地上和以前一样横平竖直（斜度 0），落稳就不再动（不进解算）")
	ItemInstance.reset_uid_counter()
	var stash := ItemStash.new(2, 0)
	var ground := B._ground(stash)
	var defs := [G._def(&"t_bar", ["1", "1", "1", "1"]), G._def(&"t_sq", ["11", "11"]), G._def(&"t_ell", ["1.", "11"])]
	var ok := true
	for i in defs.size():
		var inst := _drop(stash, ground, defs[i], Vector2(200.0 + i * 400.0, 100.0))
		ground.advance_landing(ground.landing_sec(inst.uid) + 0.01)
		ok = ok and not ground.is_bumping() and ground.tilt_of(inst.uid) == 0.0 and ground.is_stable(inst.uid)
		ok = ok and absf(ground.item_rect(inst.uid).end.y - _floor_y()) < 0.5
	t.check(ok, "三件都落平、斜度 0、站得住、不进解算")
	var saved := stash.to_dict()
	var two := true
	for p in (saved["spots"] as Array):
		two = two and (p as Array).size() == 2
	t.check(two, "没斜的存档照旧是 [x, y]")
	ground.free()


static func run_tee_tips_off(t: TestCase) -> void:
	t.begin("198 补充一 · 翻：T（横杠朝下）落在 L 竖着那一格的顶上、重心在外面 —— 不悬着，翻下来；停下时站得住、不与 L 相交")
	ItemInstance.reset_uid_counter()
	var stash := ItemStash.new(2, 0)
	var ground := B._ground(stash)
	var ell := _on_floor(stash, G._def(&"t_ell", ["1.", "1.", "11"]), 600.0)
	ground._scan()
	var tee_def := G._def(&"t_tee", [".1.", ".1.", "111"])
	var tee := _drop(stash, ground, tee_def, Vector2(620.0, 200.0))
	t.eq(tee.rotation, 0, "落稳朝向：横杠朝下")
	ground.advance_landing(ground.landing_sec(tee.uid) + 0.001)
	t.check(absf(ground.item_rect(tee.uid).end.y - ground.item_rect(ell.uid).position.y) < 0.5, "先落在 L 的顶上")
	t.check(not ground.is_stable(tee.uid), "重心不在那一格上方：站不住")
	t.check(ground.is_bumping(), "站不住的进解算")
	_run(ground)
	t.check(not ground.is_bumping() and ground.landing_uids().is_empty(), "停了")
	var moved := tee.rotation != 0 or ground.tilt_of(tee.uid) != 0.0 or ground.item_rect(tee.uid).end.y > ground.item_rect(ell.uid).position.y + 1.0
	t.check(moved, "翻了（朝向 %d、斜 %.1f°、底 %.1f）" % [tee.rotation, rad_to_deg(ground.tilt_of(tee.uid)), ground.item_rect(tee.uid).end.y])
	t.check(ground.is_stable(tee.uid), "停下时重心在支撑上方")
	t.check(ground.overlapping_pairs().is_empty(), "不与 L 相交")
	ground.free()


static func run_bar_leans(t: TestCase) -> void:
	t.begin("198 补充一 · 靠：1 × 4 长条一半搭在 2 × 2 方块上 —— 一头落地斜靠在方块沿上（10°～80°），两处接触，1.5 秒内睡着")
	ItemInstance.reset_uid_counter()
	var stash := ItemStash.new(2, 0)
	var ground := B._ground(stash)
	var block := _on_floor(stash, G._def(&"t_block", ["11", "11"]), 600.0)
	ground._scan()
	var bar := _drop(stash, ground, G._def(&"t_bar", ["1111"]), Vector2(660.0, 300.0))
	var rot0 := bar.rotation
	ground.advance_landing(ground.landing_sec(bar.uid) + 0.001)
	t.check(ground.is_bumping(), "重心伸出方块沿：进解算")
	var sec := 0.0
	while ground.is_bumping() and sec < 3.0:
		ground.advance_bumps(DT)
		sec += DT
	t.check(sec < GroundLayer.BUMP_MAX_SEC, "%.2f 秒就睡着了（< %.1f）" % [sec, GroundLayer.BUMP_MAX_SEC])
	t.check(ground.landing_uids().is_empty(), "没悬着再掉")
	var deg := absf(_visual_deg(bar, rot0, ground))
	t.check(deg >= 10.0 and deg <= 80.0, "斜靠 %.1f°" % deg)
	var sup := ground.supports_of(bar.uid)
	t.check(bool(sup["floor"]) and int(sup["item"]) == block.uid, "两处接触：地面 + 方块（%s）" % [sup])
	t.check(ground.overlapping_pairs().is_empty(), "不相交")
	var before := ground.item_rect(bar.uid)
	var tilt := ground.tilt_of(bar.uid)
	ground._scan()
	_run(ground, 1.0)
	t.check(ground.item_rect(bar.uid) == before and ground.tilt_of(bar.uid) == tilt, "落稳后一帧都不再动")
	ground.free()


static func run_normalize(t: TestCase) -> void:
	t.begin("198 补充一 · 归一化：斜过 45° 的换成相邻的四向，画面上的轮廓一个像素不跳；竖着的长条推倒了捡起来就是横的")
	ItemInstance.reset_uid_counter()
	var stash := ItemStash.new(2, 0)
	var ground := B._ground(stash)
	var bar_def := G._def(&"t_pole", ["1", "1", "1", "1"])
	var bad := []
	for case in [[bar_def, 0, 60.0], [bar_def, 1, -70.0], [G._def(&"t_ell", ["1.", "11"]), 1, 135.0], [G._def(&"t_tee", ["111", ".1."]), 3, 44.0], [bar_def, 2, -46.0], [bar_def, 0, 45.0]]:
		var def: ItemDef = case[0]
		var rot0: int = case[1]
		var ang := deg_to_rad(float(case[2]))
		var pos := Vector2(300.0, 200.0)
		var pose := GroundLayer.normalize_pose(def, rot0, pos, ang)
		var before := _outline(def, rot0, pos, ang)
		var after := _outline(def, int(pose["rot"]), pose["pos"], float(pose["tilt"]))
		var tilt := rad_to_deg(float(pose["tilt"]))
		if not _same_points(before, after, 0.5) or tilt > 45.01 or tilt <= -45.01:
			bad.append([case[2], pose])
		if (absf(float(case[2])) > 45.0) == (int(pose["rot"]) == rot0):
			bad.append(["换向不对", case[2], pose])
	t.eq(bad, [], "60°、−70°、135°、44°、−46°、45°：轮廓不跳、斜度落在 (−45°, 45°]、过了 45° 才换向")
	ground.free()

	# 真推一下：竖着的长条斜 25° 站在地上 —— 倒成横的
	ItemInstance.reset_uid_counter()
	var stash2 := ItemStash.new(2, 0)
	var g2 := B._ground(stash2)
	var pole := _on_floor(stash2, bar_def, 700.0)
	t.eq(pole.def.shape.size_rotated(pole.rotation), Vector2i(1, 4), "竖着")
	g2._scan()
	g2._store(pole.uid, g2.item_rect(pole.uid).position, deg_to_rad(25.0))
	g2.wake_bumps([pole.uid])
	t.check(g2.is_bumping(), "斜着站不住：进解算")
	_run(g2)
	t.eq(pole.def.shape.size_rotated(pole.rotation), Vector2i(4, 1), "倒成横的（朝向 %d，斜 %.1f°）" % [pole.rotation, rad_to_deg(g2.tilt_of(pole.uid))])
	t.check(absf(rad_to_deg(g2.tilt_of(pole.uid))) <= 45.0, "斜度在 ±45° 内")
	g2.free()


static func run_save_tilt(t: TestCase) -> void:
	t.begin("198 补充一 · 存档：斜着的落点多一项斜度（度，一位小数），读回来一样；老档 [x, y] 读出 0；按点暂存也带着")
	ItemInstance.reset_uid_counter()
	var lib := ItemDatabase.new()
	var d := G._def(&"t_bar", ["111"])
	lib.register(d)
	var stash := ItemStash.new(2, 0)
	var a := ItemInstance.create(d)
	var b := ItemInstance.create(d)
	stash.insert(a, -1, Vector2(0.2, 0.5))
	stash.insert(b, -1, Vector2(0.6, 0.5))
	stash.set_tilt(a.uid, deg_to_rad(23.46))
	var saved := stash.to_dict()
	var spots: Array = saved["spots"]
	t.eq((spots[0] as Array).size(), 3, "斜着的：[x, y, 斜度]")
	t.eq(float(spots[0][2]), 23.5, "斜度存成一位小数的度")
	t.eq((spots[1] as Array).size(), 2, "没斜的：[x, y]")
	var back := ItemStash.from_dict(JSON.parse_string(JSON.stringify(saved)), lib)
	var items := back.items()
	t.check(absf(back.tilt_of((items[0] as ItemInstance).uid) - deg_to_rad(23.5)) < 0.0001, "读回来斜度一样")
	t.eq(back.tilt_of((items[1] as ItemInstance).uid), 0.0, "没斜的读回 0")
	t.eq(ItemStash.read_tilt([0.1, 0.2]), 0.0, "老格式没有第三项：0")
	t.eq(ItemStash.read_spot([0.1, 0.2, 30.0]), Vector2(0.1, 0.2), "新格式的落点照旧读前两项")
	back.remove((items[0] as ItemInstance).uid)
	t.check(not back.tilts.has((items[0] as ItemInstance).uid), "拿走即丢斜度")

	var ns := NodeStorageModule.new()
	ns.nodes[4] = [a]
	ns.spots[4] = {a.uid: Vector2(0.2, 0.5)}
	ns.tilts[4] = {a.uid: deg_to_rad(23.5)}
	var ns2 := NodeStorageModule.new()
	ns2._load(JSON.parse_string(JSON.stringify(ns.to_dict())), lib)
	var kept: ItemInstance = (ns2.nodes[4] as Array)[0]
	t.check(absf(float((ns2.tilts[4] as Dictionary)[kept.uid]) - deg_to_rad(23.5)) < 0.0001, "按点暂存的斜度跟存档")


static func run_pick_tilted(t: TestCase) -> void:
	t.begin("198 补充一 · 点选：斜 30° 的件 —— 转后按新位置点得中，转前点得中、转后已经转开的点不着")
	ItemInstance.reset_uid_counter()
	var stash := ItemStash.new(2, 0)
	var ground := B._ground(stash)
	var it := B._put(stash, G._def(&"t_slab", ["11"]), Vector2(0.3, 0.4))
	var at := ground.item_rect(it.uid).position
	var corner := at + Vector2(110, 5)
	t.eq(ground.uid_at_local(corner), it.uid, "不斜时右上角点得中")
	var pivot := at + ItemSilhouette.centroid(it.def, it.rotation)
	ground._store(it.uid, at, deg_to_rad(30.0))
	var at2 := ground.item_rect(it.uid).position
	var pivot2 := at2 + ItemSilhouette.centroid(it.def, it.rotation)
	t.check(pivot2.distance_to(pivot) < 0.01, "绕重心转：重心不动")
	t.eq(ground.uid_at_local(corner), -1, "转开了：旧的右上角点不着")
	t.eq(ground.uid_at_local(pivot + Vector2(40, 0).rotated(deg_to_rad(30.0))), it.uid, "转后右半截按新位置点得中")
	t.eq(ground.grab_cell_at(it.uid, pivot + Vector2(40, 0).rotated(deg_to_rad(30.0))), Vector2i(1, 0), "抓的是右边那一格")
	var box := ground.item_bounds(it.uid)
	t.check(box.size.y > ground.item_rect(it.uid).size.y + 10.0, "斜着的包围盒更高（%s）" % box)
	ground.free()


static func run_grab_drops_tilt(t: TestCase) -> void:
	t.begin("198 补充一 · 捡起：从斜着的件拿起 —— 拖拽层是四向之一、残影不斜；斜度丢掉；取消就原样放回（还斜着）")
	ItemInstance.reset_uid_counter()
	var board := GridInventory.new(Vector2i(6, 6), 1)
	var stash := ItemStash.new(2, 0)
	var rig := G._rig(stash, board)
	var ground: GroundLayer = rig["ground"]
	var drag: DragLayer = rig["drag"]
	var it := _on_floor(stash, G._def(&"t_slab", ["111"]), 800.0, 1)
	ground._scan()
	ground._store(it.uid, ground.item_rect(it.uid).position, deg_to_rad(-25.0))
	var at := ground.item_rect(it.uid).position + ItemSilhouette.centroid(it.def, it.rotation)
	ground.grab_requested.emit(ground, it.uid, at)
	t.check(drag.is_dragging(), "拿起来了")
	t.eq(drag._rot, 1, "拖拽层的朝向就是四向里的那一个")
	t.check(not stash.tilts.has(it.uid), "斜度丢掉")
	drag.cancel()
	t.check(stash.has_item(it.uid) and absf(stash.tilt_of(it.uid) - deg_to_rad(-25.0)) < 0.0001, "取消：原样放回还斜着")
	G._free(rig)


static func run_pile_no_overlap(t: TestCase) -> void:
	t.begin("198 补充一 · 不重叠：随机 20 件从空中落成一堆（10 个种子）—— 都停下后两两不相交、都在屏内")
	var shapes := [["1"], ["11"], ["111"], ["1111"], ["11", "11"], ["1.", "11"], ["111", ".1."], ["11", "1.", "1."], [".11", "11."]]
	var bad := []
	for seed in 10:
		ItemInstance.reset_uid_counter()
		var rng := RandomNumberGenerator.new()
		rng.seed = 1980 + seed
		var stash := ItemStash.new(2, 0)
		var ground := B._ground(stash)
		for i in 20:
			var rows: Array = shapes[rng.randi_range(0, shapes.size() - 1)]
			var d := G._def(StringName("t_p%d" % i), rows)
			d.weight = rng.randi_range(1, 4)
			_drop(stash, ground, d, Vector2(rng.randf_range(500.0, 900.0), rng.randf_range(0.0, 200.0)), rng.randi_range(0, 3))
		_run(ground, 30.0)
		var pairs := ground.overlapping_pairs()
		var inside := true
		for inst in stash.items():
			var r := ground.item_bounds((inst as ItemInstance).uid)
			inside = inside and r.position.x >= -0.5 and r.position.y >= -0.5 and r.end.x <= G.SCREEN.x + 0.5 and r.end.y <= G.SCREEN.y + 0.5
		if not pairs.is_empty() or not inside or ground.is_bumping() or not ground.landing_uids().is_empty():
			bad.append([seed, pairs, inside])
		ground.free()
	t.eq(bad, [], "10 个种子都不相交、都在屏内、都停了")


static func run_time_limit(t: TestCase) -> void:
	t.begin("198 补充一 · 时限：一团东西压在一起 —— 一件最多醒着 %.1f 秒就冻住，不会无限跑" % GroundLayer.BUMP_MAX_SEC)
	ItemInstance.reset_uid_counter()
	var stash := ItemStash.new(2, 0)
	var ground := B._ground(stash, Vector2(900, 500))
	for i in 16:
		B._put(stash, G._def(&"t_crate", ["11", "11"]), Vector2(0.4, 0.4))
	ground._scan()
	t.check(ground.is_bumping(), "压成一团：解算")
	var longest := 0.0
	var steps := 0
	while ground.is_bumping() and steps < 2000:
		ground.advance_bumps(GroundLayer.BUMP_STEP)
		for b in ground._bodies.values():
			longest = maxf(longest, float(b["age"]))
		steps += 1
	t.check(longest <= GroundLayer.BUMP_MAX_SEC + GroundLayer.BUMP_STEP, "一件最长醒着 %.2f 秒" % longest)
	t.check(steps * GroundLayer.BUMP_STEP <= GroundLayer.BUMP_RUN_MAX_SEC + GroundLayer.BUMP_STEP, "一整轮 %.2f 秒" % (steps * GroundLayer.BUMP_STEP))
	t.check(not ground.is_bumping(), "停了")
	t.check(ground.overlapping_pairs().is_empty(), "还压着的退回空处")
	ground.free()


static func run_real_pile(t: TestCase) -> void:
	t.begin("198 补充一 · 真道具图：20 件一起从空中落成一堆（3 个种子）—— 不会落了翻、翻了落个没完，停下后两两不相交、都在屏内")
	var db := ItemDatabase.new()
	db.load_dir()
	var ids := [&"oak_log", &"armor", &"round_shield", &"rifle", &"warhammer", &"longsword", &"knife", &"bag_long", &"honey_jar", &"tower_shield",
		&"shortbow", &"crowbar", &"plate_cuirass", &"cleaver", &"nail_keg", &"magic_staff", &"pistol", &"rope_coil", &"scimitar", &"medkit"]
	var bad := []
	for seed in 3:
		ItemInstance.reset_uid_counter()
		var rng := RandomNumberGenerator.new()
		rng.seed = 1990 + seed
		var stash := ItemStash.new(2, 0)
		var ground := B._ground(stash, Vector2(1600, 1000))
		for id in ids:
			var def := db.get_def(id)
			_drop(stash, ground, def, Vector2(rng.randf_range(500.0, 1000.0), rng.randf_range(0.0, 250.0)), ItemSilhouette.rest_rotation(def, 0))
		var sec := _run(ground, 30.0)
		var pairs := ground.overlapping_pairs()
		var inside := true
		for inst in stash.items():
			var r := ground.item_bounds((inst as ItemInstance).uid)
			var sb: Rect2 = ItemSilhouette.tilted(ItemSilhouette.of(inst.def, inst.rotation), ground.tilt_of(inst.uid))["bounds"]
			var box := Rect2(ground.item_rect(inst.uid).position + sb.position, sb.size)
			inside = inside and box.position.x >= -0.5 and box.position.y >= -0.5 and box.end.x <= 1600.5 and box.end.y <= 1000.5
		if not pairs.is_empty() or not inside or sec >= 20.0:
			bad.append([seed, pairs, inside, snappedf(sec, 0.1)])
		ground.free()
	t.eq(bad, [], "3 个种子都在 20 秒内停稳、不相交、轮廓都在屏内")


static func run_sword_lies_flat(t: TestCase) -> void:
	t.begin("198 补充二 · 长的躺平：长剑（有图）四个朝向起手都落成横躺，斜不过 15°，1.5 秒内睡着")
	var db := ItemDatabase.new()
	db.load_dir()
	var def := db.get_def(&"longsword")
	var bad := []
	for rot in 4:
		ItemInstance.reset_uid_counter()
		var stash := ItemStash.new(2, 0)
		var ground := B._ground(stash)
		var inst := _drop(stash, ground, def, Vector2(600.0, 200.0), rot)
		ground.advance_landing(ground.landing_sec(inst.uid) + 0.001)
		var sec := 0.0
		while ground.is_bumping() and sec < 3.0:
			ground.advance_bumps(DT)
			sec += DT
		var span := GroundLayer.span_px(inst, inst.rotation)
		var tilt := rad_to_deg(ground.tilt_of(inst.uid))
		if span.x <= span.y or absf(tilt) >= 15.0 or sec > GroundLayer.BUMP_MAX_SEC + DT:
			bad.append([rot, inst.rotation, snappedf(tilt, 0.1), snappedf(sec, 0.01)])
		ground.free()
	t.eq(bad, [], "四个朝向都横躺、斜不过 15°、及时睡着")
