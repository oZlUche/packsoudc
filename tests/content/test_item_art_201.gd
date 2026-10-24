## 201（作者 2026-10-19：「记得让道具贴图和格子位置对应」）：道具图的画布就是形状 rot 0 的包围盒，一格 60 px（@2x 160 px），
## 格外透明；四个朝向用同一张图转，和 ItemShape 的顺时针旋转同一套变换 —— 每格那块图永远跟着那一格
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
## 抗锯齿的容差：格外 alpha 不超过它
const ALPHA_TOL := 8
const CELL_1X := 60
const CELL_2X := 160


static func _pngs(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == "png":
			out.append(f.get_basename())
	out.sort()
	return out


static func _image(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img != null and not img.is_empty():
		img.convert(Image.FORMAT_RGBA8)
	return img


## 这一格里最浓的 alpha（0–255）
static func _max_alpha(img: Image, c: Vector2i, cell: int) -> int:
	var region := img.get_region(Rect2i(c * cell, Vector2i(cell, cell)))
	if region.get_used_rect().size == Vector2i.ZERO:
		return 0
	var best := 0
	for y in cell:
		for x in cell:
			best = maxi(best, region.get_pixel(x, y).a8)
	return best


static func run_manifest(t: TestCase) -> void:
	t.begin("201 · 清单 ↔ 图：清单里每件有定义、两套图都在；目录里的每张图都在清单里；有没有图 = 清单在不在")
	t.eq(ItemPainter.art_available(), FileAccess.file_exists(ItemPainter.ART_MANIFEST), "art_available = 清单在不在")
	if not ItemPainter.art_available():
		return
	var c = NodeScreens._content()
	var listed := ItemPainter.art_ids()
	t.check(not listed.is_empty(), "清单有 %d 件" % listed.size())
	var no_def: Array[String] = []
	for id in listed:
		if c.items.get_def(id) == null:
			no_def.append(String(id))
	t.check(no_def.is_empty(), "清单里的都有道具定义（%s）" % [no_def])
	for sub in ["", "@2x/"]:
		var files := _pngs(ItemPainter.ART_DIR + sub)
		var extra: Array[String] = []
		for f in files:
			if f.contains("@"):     # 208：变体图归 variants 管
				if not (ItemPainter.art_variants().get(StringName(f.get_slice("@", 0)), {}) as Dictionary).has(StringName(f.get_slice("@", 1))):
					extra.append(f)
			elif not listed.has(StringName(f)):
				extra.append(f)
		var missing: Array[String] = []
		for id in listed:
			if not files.has(String(id)):
				missing.append(String(id))
		t.check(extra.is_empty() and missing.is_empty(), "assets/items/%s 与清单对得上（多：%s 缺：%s）" % [sub, extra, missing])


static func run_variants(t: TestCase) -> void:
	t.begin("208 · 实例变体图：variants 的 id 有定义、本图在清单里；每张 <id>@<变体> 两套都在，尺寸 = 本图")
	if not ItemPainter.art_available():
		return
	var c = NodeScreens._content()
	var bad: Array[String] = []
	for id in ItemPainter.art_variants():
		if c.items.get_def(id) == null or not ItemPainter.art_ids().has(id):
			bad.append("%s 没有定义或本图" % id)
			continue
		for v in ItemPainter.art_variants()[id]:
			if not String(v).is_valid_identifier() or String(v).contains("."):
				bad.append("%s@%s 变体名" % [id, v])
			for pair in [["", CELL_1X], ["@2x/", CELL_2X]]:
				var base := _image(ItemPainter.ART_DIR + String(pair[0]) + String(id) + ".png")
				var img := _image(ItemPainter.ART_DIR + String(pair[0]) + "%s@%s.png" % [id, v])
				if img == null or base == null or img.get_size() != base.get_size():
					bad.append("%s%s@%s 尺寸 %s ≠ 本图" % [pair[0], id, v, img.get_size() if img != null else "无"])
	t.check(bad.is_empty(), "变体图都对（%s）" % [bad])


static func run_canvas(t: TestCase) -> void:
	t.begin("201 · 画布 = 包围盒 × 60（@2x × 160）；形状没占的格全透明（alpha ≤ %d）" % ALPHA_TOL)
	if not ItemPainter.art_available():
		return
	var c = NodeScreens._content()
	var bad_size: Array[String] = []
	var bleed: Array[String] = []
	for id in ItemPainter.art_ids():
		var def: ItemDef = c.items.get_def(id)
		if def == null:
			continue
		var box := def.shape.size_rotated(0)
		var occupied := {}
		for cell in def.shape.cells_rotated(0):
			occupied[cell] = true
		for pair in [["", CELL_1X], ["@2x/", CELL_2X]]:
			var img := _image(ItemPainter.ART_DIR + String(pair[0]) + String(id) + ".png")
			var px: int = pair[1]
			if img == null or img.get_size() != box * px:
				bad_size.append("%s%s %s ≠ %s" % [pair[0], id, img.get_size() if img != null else "无", box * px])
				continue
			for y in box.y:
				for x in box.x:
					var cc := Vector2i(x, y)
					if not occupied.has(cc) and _max_alpha(img, cc, px) > ALPHA_TOL:
						bleed.append("%s%s@%s" % [pair[0], id, cc])
	t.check(bad_size.is_empty(), "尺寸都对（%s）" % [bad_size])
	t.check(bleed.is_empty(), "格外不落墨（%s）" % [bleed])


## 一格按 [method ItemShape] 的约定转：顺时针 (x, y) → (−y, x) 一步，最后整体平移到 min = (0, 0)
static func _turn(cells: Array[Vector2i], k: int) -> Dictionary:
	var out := {}
	var lo := Vector2i(1 << 20, 1 << 20)
	var moved := {}
	for c in cells:
		var p := c
		for i in k:
			p = Vector2i(-p.y, p.x)
		moved[c] = p
		lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
	for c in cells:
		out[c] = (moved[c] as Vector2i) - lo
	return out


static func run_rotation(t: TestCase) -> void:
	t.begin("201 · 旋转对位：画图的变换把 rot 0 每格的中心送到 cells_rotated(k) 里同一格；图 rotate_90 k 次后有墨的格 = 占格")
	var c = NodeScreens._content()
	var cell := 60.0
	var anchor := Vector2(7, 11)
	var wrong: Array[String] = []
	for id in [&"antler", &"longbow", &"scimitar", &"knife", &"festering_blade"]:
		var def: ItemDef = c.items.get_def(id)
		if def == null:
			continue
		var base := def.shape.cells_rotated(0)
		for k in 4:
			var xf := ItemPainter.art_transform(def, k, anchor, cell)
			var turned := _turn(base, k)
			var landed := {}
			for b in base:
				var at := xf * ((Vector2(b) + Vector2(0.5, 0.5)) * cell)
				var want := anchor + (Vector2(turned[b]) + Vector2(0.5, 0.5)) * cell
				if not at.is_equal_approx(want):
					wrong.append("%s rot%d 格 %s → %s（应 %s）" % [id, k, b, at, want])
				landed[turned[b]] = true
			var expect := {}
			for e in def.shape.cells_rotated(k):
				expect[e] = true
			if landed.keys().size() != expect.size() or not landed.keys().all(func(x): return expect.has(x)):
				wrong.append("%s rot%d 格集合 ≠ cells_rotated" % [id, k])
	t.check(wrong.is_empty(), "五件 × 四个朝向都对位（%s）" % [wrong])
	if not ItemPainter.art_available():
		return
	# 图本身：转 k 次后哪几格有墨
	var ink_wrong: Array[String] = []
	for id in [&"antler", &"longbow"]:
		if not ItemPainter.art_ids().has(id):
			continue
		var def: ItemDef = c.items.get_def(id)
		var img := _image(ItemPainter.ART_DIR + String(id) + ".png")
		for k in 4:
			var r := img.duplicate() as Image
			for i in k:
				r.rotate_90(CLOCKWISE)
			var box := def.shape.size_rotated(k)
			var inked := {}
			for y in box.y:
				for x in box.x:
					if _max_alpha(r, Vector2i(x, y), CELL_1X) > ALPHA_TOL:
						inked[Vector2i(x, y)] = true
			var expect := {}
			for e in def.shape.cells_rotated(k):
				expect[e] = true
			if inked.size() != expect.size() or not inked.keys().all(func(x): return expect.has(x)):
				ink_wrong.append("%s rot%d 有墨 %s ≠ 占格 %s" % [id, k, inked.keys(), expect.keys()])
	t.check(ink_wrong.is_empty(), "鹿角、长弓的图转四个朝向，有墨的格都等于占格（%s）" % [ink_wrong])


static func run_draw(t: TestCase) -> void:
	t.begin("201 · 有图画图、没图回落色块：art_of 有缓存，cell > 60 取 @2x；没在清单里的返回 null")
	var c = NodeScreens._content()
	t.check(ItemPainter.art_of(null) == null, "空定义：null")
	if not ItemPainter.art_available():
		return
	var knife: ItemDef = c.items.get_def(&"knife")
	var a := ItemPainter.art_of(knife)
	t.check(a != null and a.get_size() == Vector2(knife.shape.size_rotated(0) * CELL_1X), "匕首 60 px / 格")
	t.check(ItemPainter.art_of(knife) == a, "同一张（缓存）")
	var b := ItemPainter.art_of(knife, 80.0)
	t.check(b != null and b.get_size() == Vector2(knife.shape.size_rotated(0) * CELL_2X), "格子 80：取 @2x")
	var none: ItemDef = null
	for id in c.items.ids():
		if not ItemPainter.art_ids().has(id):
			none = c.items.get_def(id)
			break
	if none != null:
		t.check(ItemPainter.art_of(none) == null, "%s 还没图：null，照旧画色块" % none.id)
	t.check(ItemSilhouette._art_image(knife) != null, "198 阶段二：有图的道具按图取轮廓")
