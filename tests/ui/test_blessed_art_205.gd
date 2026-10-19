## 205（作者 2026-10-19「这种被赐福的亚种道具还缺少贴图」，待定按推荐）：派生的赐福版不单画，退回原件的图；
## 清单里有自己的 id 仍优先；画完图在脚印最右下那一格盖信仰印记（不随朝向转），印记没有 marks/ 退回 HUD 徽记
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")


static func _blessed(c) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for id in c.items.all_ids():
		var d: ItemDef = c.items.get_def(id)
		if d != null and d.is_blessed():
			out.append(d)
	return out


static func run_falls_back_to_base(t: TestCase) -> void:
	t.begin("205 · ① 派生的赐福版用原件的图（同一张贴图）；faith_of 认出是哪位神；手写的赐福件不算赐福版")
	var c = NodeScreens._content()
	var all := _blessed(c)
	t.check(all.size() > 0, "有派生的赐福版（%d 件）" % all.size())
	if not ItemPainter.art_available():
		return
	var wrong: Array[String] = []
	var faith_wrong: Array[String] = []
	for d in all:
		var base: ItemDef = c.items.get_def(d.blessed_of)
		if not ItemPainter.art_ids().has(d.blessed_of):
			continue
		if ItemPainter.art_id_of(d) != d.blessed_of or ItemPainter.art_of(d) == null or ItemPainter.art_of(d) != ItemPainter.art_of(base):
			wrong.append(String(d.id))
		if ItemPainter.art_of(d, 80.0) != ItemPainter.art_of(base, 80.0):
			wrong.append("%s@2x" % d.id)
		var f := ItemPainter.faith_of(d)
		if f == &"" or Blessings.variant_id(d.blessed_of, f) != d.id:
			faith_wrong.append(String(d.id))
	t.check(wrong.is_empty(), "赐福版与原件同一张图（%s）" % [wrong])
	t.check(faith_wrong.is_empty(), "id = 原件_神，faith_of 拆得回来（%s）" % [faith_wrong])
	for id in [&"blessed_longbow", &"blessed_shield"]:
		var d: ItemDef = c.items.get_def(id)
		if d != null:
			t.eq(ItemPainter.faith_of(d), &"", "%s 是手写的：不盖印" % id)
			t.eq(ItemPainter.art_id_of(d), id if ItemPainter.art_ids().has(id) else &"", "%s 用自己的图" % id)
	var knife: ItemDef = c.items.get_def(&"knife")
	t.eq(ItemPainter.faith_of(knife), &"", "原件：不盖印")
	t.eq(ItemPainter.art_id_of(knife), &"knife", "原件：自己的图")
	t.eq(ItemPainter.art_id_of(null), &"", "空定义：空")


static func run_own_art_wins(t: TestCase) -> void:
	t.begin("205 · ② 清单里有同名的 原件_神 就用它自己的；清掉缓存回到原件")
	var c = NodeScreens._content()
	var all := _blessed(c)
	if all.is_empty() or not ItemPainter.art_available():
		return
	var d: ItemDef = all[0]
	ItemPainter.art_ids()[d.id] = true     # 临时清单：假装美术单画了这一件
	t.eq(ItemPainter.art_id_of(d), d.id, "%s 自己在清单里：用自己的" % d.id)
	ItemPainter.clear_art_cache()
	t.eq(ItemPainter.art_id_of(d), d.blessed_of, "清掉缓存：回到原件 %s" % d.blessed_of)


static func run_mark_texture(t: TestCase) -> void:
	t.begin("205 · ③ 印记贴图：有 marks/ 取它（格子大于 60 取 @2x），没有退回 HUD 徽记；有缓存；没神 null")
	t.check(ItemPainter.mark_of(&"") == null, "没神：null")
	t.check(ItemPainter.mark_of(&"no_such_god") == null, "不认识的神：null")
	for f: String in ["brute", "church", "earth", "hunt", "nature", "skill", "sun"]:
		var own := ItemPainter.MARK_DIR + f + ".png"
		var own2 := ItemPainter.MARK_DIR + "@2x/" + f + ".png"
		var hud := ItemPainter.MARK_FALLBACK_DIR + f + ".png"
		var m := ItemPainter.mark_of(StringName(f))
		t.check(m != null, "%s 有印记" % f)
		if m == null:
			continue
		var want := own if ResourceLoader.exists(own) or FileAccess.file_exists(own) else hud
		t.eq(m.resource_path, want, "%s 1x 来自 %s" % [f, want])
		var want2 := own2 if ResourceLoader.exists(own2) or FileAccess.file_exists(own2) else hud
		t.eq(ItemPainter.mark_of(StringName(f), 80.0).resource_path, want2, "%s 格子 80 来自 %s" % [f, want2])
		t.check(ItemPainter.mark_of(StringName(f)) == m, "%s 同一张（缓存）" % f)
		if want == own:
			t.eq(m.get_size(), Vector2(24, 24), "%s 印记 24 px" % f)
		if want2 == own2:
			t.eq(ItemPainter.mark_of(StringName(f), 80.0).get_size(), Vector2(64, 64), "%s 印记 @2x 64 px" % f)


static func run_codex_variants(t: TestCase) -> void:
	t.begin("205 · ④ 图鉴异体页：原件有图的，每个异体都有图且盖印（赐福版）")
	var c = NodeScreens._content()
	if not ItemPainter.art_available():
		return
	var missing: Array[String] = []
	var unmarked: Array[String] = []
	var bases := 0
	for id in ItemPainter.art_ids():
		var vs: Array = c.items.variants_of(id)
		if vs.size() < 2:
			continue
		bases += 1
		for vid in vs:
			var v: ItemDef = c.items.get_def(vid)
			if ItemPainter.art_of(v) == null:
				missing.append(String(vid))
			if v.is_blessed() and ItemPainter.mark_of(ItemPainter.faith_of(v)) == null:
				unmarked.append(String(vid))
	t.check(bases > 0, "%d 件原件有赐福版" % bases)
	t.check(missing.is_empty(), "异体都有图（%s）" % [missing])
	t.check(unmarked.is_empty(), "赐福版都有印记（%s）" % [unmarked])


static func run_mark_rect(t: TestCase) -> void:
	t.begin("205 · ⑤ 印记落点：L 形四个朝向都在脚印最右下那一格的右下角（不是包围盒角），0.4 格、内缩 0.06 格")
	var d := ItemDef.new()
	d.shape = ItemShape.from_ascii(["10", "10", "11"])
	var anchor := Vector2(10, 20)
	var cell := 60.0
	var expect: Array[Vector2i] = [Vector2i(1, 2), Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 1)]
	for k in 4:
		var r := ItemPainter.mark_rect(d, k, anchor, cell)
		var corner := anchor + Vector2(expect[k] + Vector2i.ONE) * cell - Vector2.ONE * cell * ItemPainter.MARK_INSET
		t.check(r.end.is_equal_approx(corner), "rot%d 落在 %s 格右下（%s）" % [k, expect[k], r])
		t.check(r.size.is_equal_approx(Vector2(24, 24)), "rot%d 边长 24" % k)
		t.check(Rect2(anchor + Vector2(expect[k]) * cell, Vector2(cell, cell)).encloses(r), "rot%d 整枚在那一格里" % k)
		t.check(d.shape.cells_rotated(k).has(expect[k]), "rot%d 那一格是脚印的" % k)
	t.check(not d.shape.cells_rotated(1).has(Vector2i(2, 1)), "rot1 包围盒右下角是空格：不落在那儿")
