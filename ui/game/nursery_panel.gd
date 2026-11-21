## 342 B3：后勤「苗圃」页（[Nursery]）。作者 2026-11-21 选 B 花槽（UI设计，`assets/ui/nursery/layout.json`）：
## 墙上一块木架，木架上一只木花槽，作物往上长，插一块小木牌写名字、每局一个圆点；
## 空地时花槽里只画虚线轮廓，木架下钉两张作物纸条（垦户社图钉）：熟了的样子、种苗 → 收成、几局、【种下】；
## 长着时木架下一只空basket，收成淡着写在basket下；熟了作物发光、收成放进basket、出【收获】（仓库放不下就留在地里）。
## 不垫羊皮纸大面板：墙（以后是野外农田背景）直接透出来
extends VBoxContainer

signal changed()
## 有话要说（收不了、种不了的原因；收了什么）：[param warn] = 是不是要紧的
signal said(text: String, warn: bool)

const CP := preload("res://ui/game/commission_panel.gd")
const ART := "nursery/"
const INK := Color("2e2219")
const INK_DIM := Color("5a4a3a")
## 背景上的浅字
const LIGHT := Color("f1e3c2")
## 版面（layout.json，内容区宽 598）；整幅往下挪 [constant OY]，让长高的作物不顶出页面
const W := 598.0
const OY := 60.0
const SHELF := Rect2(14, 440, 570, 64)
const SHELF_EDGES := [90, 4, 90, 4]
const PLANTER := Rect2(54, 290, 490, 150)
const PLANTER_EDGES := [40, 8, 40, 8]
const PLANT := 370.0
const PLANT_X := 299.0
const TAG := Vector2(112, 64)
const TAG_EDGES := [10, 10, 10, 10]
const BASKET := Vector2(260, 170)
## 木架下面那一块多高（纸条 / basket + 收成 + 【收获】）
const BELOW_H := 290.0
const SLIP_W := 250.0
const SLIP_GAP := 24.0
const ICON := 30.0
## 整幅高（设计尺寸）
const H := OY + 504.0 + BELOW_H
## 熟了的作物缩一点（顶端不贴到页面上沿）
const RIPE_SCALE := 0.9

var flow: GameFlow = null
var _stage: Control = null
var _frame: Control = null


func setup(p_flow: GameFlow) -> void:
	flow = p_flow
	name = "NurseryPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_frame = Control.new()     # 中列多宽就按多宽缩（不撑宽中列，右边仓库不被挤出屏）
	_frame.name = "StageFrame"
	_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.custom_minimum_size = Vector2(0, H)
	scroll.add_child(_frame)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.size = Vector2(W, H)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.set_tone(_stage, UiTheme.TONE_DARK)
	_frame.add_child(_stage)
	_frame.resized.connect(_fit)
	refresh()


## 版面按中列宽等比缩（最大 1 倍），横向居中
func _fit() -> void:
	var k := clampf(_frame.size.x / W, 0.3, 1.0) if _frame.size.x > 0.0 else 1.0
	_stage.scale = Vector2(k, k)
	_stage.position = Vector2((_frame.size.x - W * k) * 0.5, 0.0)
	_frame.custom_minimum_size.y = H * k


func refresh() -> void:
	if _stage == null or flow == null or flow.meta == null:
		return
	for c in _stage.get_children():
		_stage.remove_child(c)
		c.queue_free()
	_build_plot(0)     # 现在一畦（第二畦留到 100 档）


## 作物名
static func crop_name(crop: StringName) -> String:
	return UiText.t("nursery.crop_" + String(crop))


## 一种作物的一行说明：种苗成本 → 收什么 × 几，几局（悬停字用）
func crop_text(crop: StringName) -> String:
	var spec: Dictionary = Nursery.CROPS.get(crop, {})
	var product := _def(StringName(spec.get("product", &"")))
	var seed_parts: Array[String] = []
	var seed_: Dictionary = spec.get("seed", {})
	for id in seed_:
		var d := _def(StringName(id))
		seed_parts.append("%s ×%d" % [Names.of(d) if d != null else String(id), int(seed_[id])])
	var cost := UiText.t("nursery.seed_free") if seed_parts.is_empty() else ", ".join(seed_parts)
	return UiText.t("nursery.crop_line") % [cost, Names.of(product) if product != null else "?", int(spec.get("count", 0)), int(spec.get("runs", 0))]


## 长到哪一步：0 种子 1 芽 2 苗 3 熟（-1 = 空地）
func stage_of(i: int) -> int:
	var plot := flow.meta.nursery.plot(i)
	var crop := StringName(String(plot.get("crop", "")))
	if crop == &"":
		return -1
	if flow.meta.nursery.is_ripe(i):
		return 3
	var runs := maxi(1, int((Nursery.CROPS.get(crop, {}) as Dictionary).get("runs", 1)))
	var done := runs - int(plot.get("left", runs))
	return clampi(floori(done * 3.0 / runs), 0, 2)


func _def(id: StringName) -> ItemDef:
	return flow.items.get_def(id) if flow.items != null and id != &"" else null


func _pic(file: String, rect: Rect2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiTheme.art(ART + file)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = rect.position
	r.size = rect.size
	r.custom_minimum_size = rect.size
	return r


func _nine(file: String, rect: Rect2, edges: Array) -> Control:
	var tex := UiTheme.art(ART + file)
	var n: Control = UiTheme.nine_rect(tex, edges) if tex != null else Control.new()
	n.position = rect.position
	n.size = rect.size
	return n


func _item_icon(id: StringName, side: float) -> TextureRect:
	var r := TextureRect.new()
	var d := _def(id)
	r.texture = ShelfView.item_art(d) if d != null else null
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(side, side)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.tooltip_text = Names.of(d) if d != null else ""
	return r


## 背景上的字（浅墨）：UI设计 的版面就是写在墙上，不垫底
func _wall_label(text: String, sz: int) -> Label:
	var l := UiTheme.make_label(text, sz, LIGHT)
	l.set_meta(&"exempt_bare_text", true)
	return l


func _build_plot(i: int) -> void:
	var st := stage_of(i)
	var crop := StringName(String(flow.meta.nursery.plot(i).get("crop", "")))
	var planter := PLANTER
	planter.position.y += OY
	var side := PLANT * (RIPE_SCALE if st == 3 else 1.0)
	var plant := Rect2(PLANT_X - side * 0.5, planter.position.y - 2.0 - side, side, side)
	if st == 3:
		var glow := _pic("ripe_glow", plant)
		glow.name = "RipeGlow"
		_stage.add_child(glow)
	if st < 0:
		var outline := DashedDome.new()
		outline.name = "EmptyOutline"
		outline.position = Vector2(PLANT_X - 75.0, planter.position.y - 132.0)
		outline.size = Vector2(150, 124)
		_stage.add_child(outline)
	else:
		var p := _pic("plant_%s_%d" % [String(crop), st], plant)
		p.name = "Plant"
		_stage.add_child(p)
	if st == 3:
		for s in [[Vector2(PLANT_X + 95, plant.position.y + 40), 22.0], [Vector2(PLANT_X - 105, plant.position.y + 110), 16.0], [Vector2(PLANT_X + 70, plant.position.y + 170), 14.0]]:
			var sp := _pic("sparkle", Rect2(s[0], Vector2(s[1], s[1])))
			sp.name = "Sparkle"
			_stage.add_child(sp)
	var shelf := SHELF
	shelf.position.y += OY
	_stage.add_child(_nine("planter", planter, PLANTER_EDGES))
	_stage.add_child(_nine("shelf", shelf, SHELF_EDGES))
	if st >= 0:
		_add_tag(i, crop, planter)
	var below := Rect2(0, shelf.end.y, W, BELOW_H)
	if st < 0:
		_add_slips(i, below)
	else:
		_add_basket(i, crop, st == 3, below)


## 插在花槽右上的小木牌：作物名 + 每局一个圆点（走过的亮）
func _add_tag(i: int, crop: StringName, planter: Rect2) -> void:
	var at := Vector2(planter.end.x - 124.0, planter.position.y - 92.0)
	var stake := _pic("stake", Rect2(at + Vector2(TAG.x * 0.5 - 5.0, TAG.y - 14.0), Vector2(10, 62)))
	_stage.add_child(stake)
	var tag := _nine("tag", Rect2(at, TAG), TAG_EDGES)
	tag.name = "Tag"
	tag.pivot_offset = TAG * 0.5
	tag.rotation = deg_to_rad(3.0)
	tag.set_meta(&"exempt_bare_text", true)     # 木牌图就是字的底
	_stage.add_child(tag)
	var col := UiTheme.vbox(2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tag.add_child(col)
	var name_l := UiTheme.make_label(crop_name(crop), 19, INK)
	name_l.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_l)
	var plot := flow.meta.nursery.plot(i)
	var runs := maxi(1, int((Nursery.CROPS.get(crop, {}) as Dictionary).get("runs", 1)))
	var done := runs if flow.meta.nursery.is_ripe(i) else runs - int(plot.get("left", runs))
	var pips := UiTheme.hbox(4)
	pips.name = "Pips"
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in runs:
		var pip := TextureRect.new()
		pip.texture = UiTheme.art(ART + ("pip_grow_on" if k < done else "pip_grow_off"))
		pip.custom_minimum_size = Vector2(18, 18)
		pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	col.add_child(pips)
	tag.tooltip_text = UiText.t("nursery.left") % int(plot.get("left", 0)) if not flow.meta.nursery.is_ripe(i) else UiText.t("nursery.ripe")
	tag.mouse_filter = Control.MOUSE_FILTER_PASS


## 空地：木架下钉两张作物纸条
func _add_slips(i: int, below: Rect2) -> void:
	var row := UiTheme.hbox(int(SLIP_GAP))
	row.name = "Slips"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = below.position + Vector2(0, 26)
	row.size = Vector2(W, below.size.y - 26)
	_stage.add_child(row)
	for c in Nursery.ORDER:
		row.add_child(_slip(i, c))


func _slip(i: int, crop: StringName) -> Control:
	var spec: Dictionary = Nursery.CROPS.get(crop, {})
	var p := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 16, 12, 16, 12)
	UiTheme.set_tone(p, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	p.name = "Slip_" + String(crop)
	p.custom_minimum_size.x = SLIP_W
	p.tooltip_text = crop_text(crop)
	var col := UiTheme.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(col)
	var pic := TextureRect.new()
	pic.texture = UiTheme.art(ART + "plant_%s_3" % String(crop))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(110, 110)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pic)
	var title := UiTheme.make_label(crop_name(crop), 20, INK)
	title.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var trade := UiTheme.hbox(6)     # 种苗 ×1 → 收成 ×N
	trade.alignment = BoxContainer.ALIGNMENT_CENTER
	var seed_: Dictionary = spec.get("seed", {})
	if seed_.is_empty():
		trade.add_child(CP.emblem(&"growers", ICON))
		trade.add_child(UiTheme.make_label(UiText.t("nursery.gift"), 16, INK))
	else:
		for id in seed_:
			trade.add_child(_item_icon(StringName(id), ICON))
			trade.add_child(UiTheme.make_label("×%d" % int(seed_[id]), 16, INK))
	trade.add_child(UiTheme.make_label("→", 16, INK_DIM))
	trade.add_child(_item_icon(StringName(spec.get("product", &"")), ICON))
	trade.add_child(UiTheme.make_label("×%d" % int(spec.get("count", 0)), 16, INK))
	col.add_child(trade)
	var runs := UiTheme.hbox(4)
	runs.alignment = BoxContainer.ALIGNMENT_CENTER
	runs.add_child(CP._pic("hourglass", Vector2(16, 20)))
	runs.add_child(UiTheme.make_label(UiText.t("nursery.runs") % int(spec.get("runs", 0)), 16, INK))
	col.add_child(runs)
	var b := UiTheme.make_home_button(UiText.t("nursery.sow"), func(): sow(i, crop), true, Vector2(110, 40), 18)
	b.name = "Sow_%d_%s" % [i, String(crop)]
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var why := Nursery.why_not_sow(flow.meta, i, crop)
	b.disabled = why != ""
	if why != "":
		b.tooltip_text = UiText.t("nursery.why_" + why)
	col.add_child(b)
	return CP._pinned(p, "pin_growers")


## 长着 / 熟了：木架下一只basket；收成写在basket下（长着淡、熟了亮），熟了收成放进basket、出【收获】
func _add_basket(i: int, crop: StringName, ripe: bool, below: Rect2) -> void:
	var spec: Dictionary = Nursery.CROPS.get(crop, {})
	var product := StringName(spec.get("product", &""))
	var top := below.position.y + 34.0
	var basket := Rect2(Vector2((W - BASKET.x) * 0.5, top), BASKET)
	if ripe:
		var got := _item_icon(product, 80)
		got.name = "Harvested"
		got.position = Vector2(W * 0.5 - 40.0, top - 22.0)
		got.size = Vector2(80, 80)
		_stage.add_child(got)
	var bk := _pic("basket", basket)
	bk.name = "Basket"
	_stage.add_child(bk)
	var yield_row := UiTheme.hbox(6)
	yield_row.name = "Yield"
	yield_row.alignment = BoxContainer.ALIGNMENT_CENTER
	yield_row.position = Vector2(0, basket.end.y + 4.0)
	yield_row.size = Vector2(W, ICON)
	yield_row.add_child(_item_icon(product, ICON))
	yield_row.add_child(_wall_label("×%d" % int(spec.get("count", 0)), 18))
	if not ripe:
		yield_row.modulate.a = 0.6
	_stage.add_child(yield_row)
	if ripe:
		var b := UiTheme.make_home_button(UiText.t("nursery.harvest"), func(): harvest(i), true, Vector2(150, 44), 20)
		b.name = "Harvest_%d" % i
		b.position = Vector2((W - 150.0) * 0.5, basket.end.y + ICON + 14.0)
		_stage.add_child(b)


func sow(i: int, crop: StringName) -> String:
	var why := flow.sow_crop(i, crop)
	if why != "":
		said.emit(UiText.t("nursery.why_" + why), true)
	refresh()
	changed.emit()
	return why


func harvest(i: int) -> Dictionary:
	var got := flow.harvest_crop(i)
	if String(got["why"]) != "":
		said.emit(UiText.t("nursery.why_" + String(got["why"])), true)
	refresh()
	changed.emit()
	return got


## 空地：花槽上一圈虚线圆顶（以后长东西的地方）
class DashedDome extends Control:
	const DASH := 6.0
	const COLOR := Color(0.95, 0.89, 0.76, 0.55)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := size.x * 0.5
		var c := Vector2(r, r)
		var pts := PackedVector2Array()
		pts.append(Vector2(0, size.y))
		pts.append(Vector2(0, r))
		var n := 24
		for k in n + 1:
			var a := PI + PI * float(k) / float(n)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		pts.append(Vector2(size.x, size.y))
		for k in pts.size() - 1:
			_dashed(pts[k], pts[k + 1])

	func _dashed(a: Vector2, b: Vector2) -> void:
		var span := a.distance_to(b)
		var d := (b - a) / maxf(span, 0.001)
		var t := 0.0
		while t < span:
			draw_line(a + d * t, a + d * minf(t + DASH, span), COLOR, 2.0)
			t += DASH * 2.0
