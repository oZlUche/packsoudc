## 物品的统一画法。网格内的物品与拖拽中的残影共用它，
## 否则两套绘制迟早会在圆角、描边、配色上走样。
class_name ItemPainter
extends RefCounted

## 作者定（087）：颜色代表稀有度，从低到高 白、绿、蓝、紫、金、红
const RARITY_COLORS: Array[Color] = [
	Color("d8dce3"),  # 0 普通　白
	Color("5fa85f"),  # 1 优良　绿
	Color("4a86c8"),  # 2 稀有　蓝
	Color("b06ccf"),  # 3 史诗　紫
	Color("e0b040"),  # 4 传说　金
	Color("d9453f"),  # 5 神话　红
]


## 201：道具图（`assets/items/<id>.png`，60 px / 格；`@2x/<id>.png`，160 px / 格）。画布 = 形状 rot 0 的包围盒，格外透明
const ART_DIR := "res://assets/items/"
const ART_MANIFEST := "res://assets/items/manifest.json"
## 图的一格多少像素；格子画得比它大（仓库最大 80）就取 @2x
const ART_CELL := 60.0
## 205：赐福版的信仰印记（`marks/<faith>.png` 24 px，`marks/@2x/` 64 px）；没有退回 HUD 的徽记（166）
const MARK_DIR := "res://assets/items/marks/"
const MARK_FALLBACK_DIR := "res://assets/ui/faith/"
## 印记边长与内缩（按一格的比例）
const MARK_SIZE := 0.4
const MARK_INSET := 0.06

## 路径 → 贴图（没有的也记 null，别每帧探文件）
static var _art: Dictionary = {}
static var _listed: Dictionary = {}
## 208：清单的 `variants`：id → {变体名: true}
static var _variants: Dictionary = {}
static var _manifest_read := false

## 208：剩余次数角标 —— 点径、点距、内缩（按一格的比例）；暗点的颜色
const CHARGE_DOT := 0.1
const CHARGE_GAP := 0.14
const CHARGE_INSET := 0.08
const CHARGE_DIM := Color(1, 1, 1, 0.3)


## 201：道具图包到了没有 = 清单在不在
static func art_available() -> bool:
	return FileAccess.file_exists(ART_MANIFEST)


## 201：清单里的 id（测试与 [method art_of] 用）
static func art_ids() -> Dictionary:
	if not _manifest_read:
		_manifest_read = true
		_listed = {}
		_variants = {}
		if art_available():
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART_MANIFEST))
			if data is Dictionary:
				for id in (data as Dictionary).get("items", []):
					_listed[StringName(String(id))] = true
				var vs: Variant = (data as Dictionary).get("variants", {})
				if vs is Dictionary:
					for id in vs:
						var names := {}
						for v in (vs[id] if vs[id] is Array else []):
							names[StringName(String(v))] = true
						_variants[StringName(String(id))] = names
	return _listed


## 208：清单里的变体（id → {变体名: true}；测试与 [method art_of] 用）
static func art_variants() -> Dictionary:
	art_ids()
	return _variants


## 208：这一件现在该用哪张变体图 —— 耐久没满：`c<档>`（246：[method WearProfile.art_variant]）；207 生长到了第几阶：`s<阶>`；两样都有耐久优先；都没有空。
## 变体图有没有画是 [method art_of] 的事，这里只按状态说名字
static func variant_of(inst: ItemInstance) -> StringName:
	if inst == null or inst.def == null:
		return &""
	if inst.def.wear != null and inst.charges() < inst.def.wear.max_charges:
		return StringName("c%d" % inst.def.wear.art_variant(inst.charges()))     # 246：次数多于图的张数时折算
	var stage := GrowthProfile.stage_of(inst)
	if stage > 0:
		return StringName("s%d" % stage)
	return &""


## 208：[param variant] 这张变体图在清单里的文件名（`<id>@<变体>`）—— 先找自己的，赐福版再找原件的；没有返回空
static func variant_file(def: ItemDef, variant: StringName) -> String:
	if def == null or variant == &"":
		return ""
	for id in [def.id, def.blessed_of if def.is_blessed() else &""]:
		if id != &"" and (art_variants().get(id, {}) as Dictionary).has(variant):
			return "%s@%s" % [id, variant]
	return ""


## 205：这件用哪张图的 id —— 清单里有自己的 → 自己；赐福版且清单里有原件 → 原件；都没有 → 空
static func art_id_of(def: ItemDef) -> StringName:
	if def == null:
		return &""
	if art_ids().has(def.id):
		return def.id
	if def.is_blessed() and art_ids().has(def.blessed_of):
		return def.blessed_of
	return &""


## 201：这件的图（没有 → null）。[param cell_px] 是画的时候一格多大：大于 [constant ART_CELL] 取 @2x。
## 208：[param variant] 非空且清单里有这张变体就取它（`<id>@<变体>.png`），没有回落本图
static func art_of(def: ItemDef, cell_px: float = ART_CELL, variant: StringName = &"") -> Texture2D:
	var id := art_id_of(def)
	if def == null or def.shape == null or id == &"":
		return null
	var file := variant_file(def, variant)
	return _cached(ART_DIR + ("@2x/" if cell_px > ART_CELL else "") + (file if file != "" else String(id)) + ".png")


static func _cached(path: String) -> Texture2D:
	if not _art.has(path):
		_art[path] = EventImage.load_texture(path)
	return _art[path]


## 205：赐福版是哪位神的（id = 原件_神）；不是赐福版 → 空
static func faith_of(def: ItemDef) -> StringName:
	if def == null or not def.is_blessed():
		return &""
	return StringName(String(def.id).trim_prefix(String(def.blessed_of) + "_"))


## 205：信仰印记的贴图：有 `marks/` 取它（格子大于 [constant ART_CELL] 取 @2x），没有退回 HUD 徽记；都没有 null
static func mark_of(faith_id: StringName, cell_px: float = ART_CELL) -> Texture2D:
	if faith_id == &"":
		return null
	var name := String(faith_id) + ".png"
	var tex := _cached(MARK_DIR + ("@2x/" if cell_px > ART_CELL else "") + name)
	return tex if tex != null else _cached(MARK_FALLBACK_DIR + name)


## 205：印记落在哪 —— 当前朝向脚印里最靠右下的那一格（y 最大、再 x 最大）的右下角，内缩一点；不随朝向转
static func mark_rect(def: ItemDef, rot: int, anchor: Vector2, cell: float) -> Rect2:
	var best := Vector2i(-1, -1)
	for c in def.shape.cells_rotated(rot):
		if c.y > best.y or (c.y == best.y and c.x > best.x):
			best = c
	var side := cell * MARK_SIZE
	var corner := anchor + Vector2(best + Vector2i.ONE) * cell - Vector2.ONE * cell * MARK_INSET
	return Rect2(corner - Vector2(side, side), Vector2(side, side))


## 201：按格子对位画道具图 —— 图只画 rot 0 一张，k 个朝向 = 整张绕左上角顺时针转 k × 90° 再平移回来，
## 和 [method ItemShape.cells_rotated] 同一套变换，每格的那块图永远跟着那一格（推导见报告 201 §2.2）。
## [param anchor] 是转好朝向后 (0, 0) 格的左上角；[param base] 是调用方当前的画布变换（地面落地动画），相乘不覆盖。
## 没图返回 false，调用方照旧画色块 + 名字
static func draw_art(
	canvas: CanvasItem,
	def: ItemDef,
	rot: int,
	anchor: Vector2,
	cell: float,
	modulate: Color = Color.WHITE,
	base: Transform2D = Transform2D.IDENTITY,
	variant: StringName = &""
) -> bool:
	var tex := art_of(def, cell, variant)
	if tex == null:
		return false
	canvas.draw_set_transform_matrix(base * art_transform(def, rot, anchor, cell))
	canvas.draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(def.shape.size_rotated(0)) * cell), false, modulate)
	canvas.draw_set_transform_matrix(base)
	var mark := mark_of(faith_of(def), cell)     # 205：赐福版盖信仰印记（画完图再盖，永远正着）
	if mark != null:
		canvas.draw_texture_rect(mark, mark_rect(def, rot, anchor, cell), false, modulate)
	return true


## 201：rot 0 的图（左上角在原点、一格 [param cell] 像素）→ 画布：转 k × 90° 顺时针，左上角挪到 anchor + 偏移
## (0, 0) / (H, 0) / (W, H) / (0, W) 格（W、H = rot 0 的包围盒）
static func art_transform(def: ItemDef, rot: int, anchor: Vector2, cell: float) -> Transform2D:
	var size := Vector2(def.shape.size_rotated(0))
	var k := posmod(rot, 4)
	var off: Vector2 = [Vector2.ZERO, Vector2(size.y, 0.0), size, Vector2(0.0, size.x)][k]
	return Transform2D(k * PI * 0.5, anchor + off * cell)


## 208：剩余次数角标 —— 耐久没满、又没有这一档的变体图时，在当前朝向脚印最靠左下的那一格（y 最大、再 x 最小）
## 画 max 个小点，亮的 = 剩的（稀有度色），暗的 = 用掉的。和 205 的信仰印记（右下）错开。画了返回 true
static func draw_charges(canvas: CanvasItem, inst: ItemInstance, rot: int, anchor: Vector2, cell: float, modulate: Color = Color.WHITE) -> bool:
	var dots := charge_dots(inst, rot, anchor, cell)
	if dots.is_empty():
		return false
	var lit := rarity_color(inst.def, inst.rarity()) * modulate
	var dim := CHARGE_DIM * modulate
	for d in dots:
		canvas.draw_circle(d["at"], cell * CHARGE_DOT * 0.5, lit if bool(d["lit"]) else dim)
	return true


## 208：角标的那几个点 [{at: 圆心, lit: 亮不亮}]；不该画（没耐久、满的、有这一档的变体图）返回空
static func charge_dots(inst: ItemInstance, rot: int, anchor: Vector2, cell: float) -> Array:
	var out: Array = []
	if inst == null or inst.def == null or inst.def.wear == null or inst.def.shape == null:
		return out
	var full := inst.def.wear.max_charges
	var left := inst.charges()
	if left >= full or variant_file(inst.def, variant_of(inst)) != "":
		return out
	var best := Vector2i(1 << 20, -1)
	for c in inst.def.shape.cells_rotated(rot):
		if c.y > best.y or (c.y == best.y and c.x < best.x):
			best = c
	var r := cell * CHARGE_DOT * 0.5
	var start := anchor + Vector2(best.x, best.y + 1) * cell + Vector2(cell * CHARGE_INSET + r, -cell * CHARGE_INSET - r)
	# 246 乙：一个点 = 一档（满 27、三次一档 → 九个点），档里还剩次数就亮
	var band := maxi(1, inst.def.wear.charge_band)
	var dots := ceili(float(full) / band)
	var lit := ceili(float(left) / band)
	# 246：九个点一格宽的件一排放不下 —— 按件的宽度折成几排，往上叠
	var width := float(inst.def.shape.size_rotated(rot).x)
	var per_row := maxi(1, 1 + floori((width - 2.0 * CHARGE_INSET - CHARGE_DOT) / CHARGE_GAP))
	for i in dots:
		out.append({"at": start + Vector2((i % per_row) * cell * CHARGE_GAP, -(i / per_row) * cell * CHARGE_GAP), "lit": i < lit})
	return out


## 230：玩家锁住的道具 —— 当前朝向脚印最靠左上的那一格（y 最小、再 x 最小）左上角往里 8% 一枚小锁（`tip/lock_badge`），
## 边长 16 × 格 / 60；格子比 60 大时用 2 倍图缩。没锁不画；画了返回 true
static func draw_lock(canvas: CanvasItem, inst: ItemInstance, rot: int, anchor: Vector2, cell: float, modulate: Color = Color.WHITE) -> bool:
	var r := lock_rect(inst, rot, anchor, cell)
	if r.size == Vector2.ZERO:
		return false
	var tex := UiTheme.art_cached("tip/lock_badge_2x" if cell > InventoryView.CELL else "tip/lock_badge")
	if tex == null:
		canvas.draw_rect(r, Color("d4a84f") * modulate)
		return true
	canvas.draw_texture_rect(tex, r, false, modulate)
	return true


## 小锁画在哪（没锁 / 没形状给空矩形）
static func lock_rect(inst: ItemInstance, rot: int, anchor: Vector2, cell: float) -> Rect2:
	if inst == null or inst.def == null or inst.def.shape == null or not inst.is_locked_by_player():
		return Rect2()
	var best := Vector2i(1 << 20, 1 << 20)
	for c in inst.def.shape.cells_rotated(rot):
		if c.y < best.y or (c.y == best.y and c.x < best.x):
			best = c
	var side := LOCK_SIDE * cell / InventoryView.CELL
	return Rect2(anchor + Vector2(best) * cell + Vector2.ONE * cell * LOCK_INSET, Vector2(side, side))


const LOCK_SIDE := 16.0
const LOCK_INSET := 0.08


## 测试用：清掉缓存（换了 [constant ART_MANIFEST] 的内容之后）
static func clear_art_cache() -> void:
	_art.clear()
	_listed.clear()
	_variants.clear()
	_manifest_read = false


## 物品主色（087 作者定）：**整格的底色就是稀有度的颜色**，不靠边框。往面板色压一点，字才看得清；描边同色稍亮。
## 三个配色函数的 [param rarity]：-1 = 定义的稀有度；画一件实例时传 [method ItemInstance.rarity]（246：碎了的低两档）
static func body_color(def: ItemDef, rarity: int = -1) -> Color:
	if def == null:
		return Color("555a63")
	return rarity_color(def, rarity).lerp(Color("171a20"), 0.28)


## 名字的颜色：底色亮（白 / 金）就用深字，别的用浅字
static func label_color(def: ItemDef, rarity: int = -1) -> Color:
	var b := body_color(def, rarity)
	return Color("14161b") if b.get_luminance() > 0.5 else Color("e6e9ef")


static func rarity_color(def: ItemDef, rarity: int = -1) -> Color:
	if def == null:
		return RARITY_COLORS[0]
	return RARITY_COLORS[clampi(def.rarity if rarity < 0 else rarity, 0, RARITY_COLORS.size() - 1)]


## 画一件物品。
##
## [param cells] 为占格集合，[param anchor] 是 (0,0) 格在画布上的左上角像素坐标。
## 只在轮廓边上描线 —— 逐格描边会让 L 形看起来像散落的方块，而不是一件物品。
static func draw_item(
	canvas: CanvasItem,
	cells: Array[Vector2i],
	anchor: Vector2,
	cell: float,
	body: Color,
	edge: Color
) -> void:
	if cells.is_empty():
		return
	var occupied := {}
	for c in cells:
		occupied[c] = true

	# 先铺满整体，格与格之间不留缝，视觉上才是一件东西
	for c in cells:
		var p := anchor + Vector2(c) * cell
		canvas.draw_rect(Rect2(p, Vector2(cell, cell)), body, true)

	# 只描外轮廓，并向内缩 1px：
	# 描在格线正中时，相邻两件物品的边会叠成一条，看不出是两件
	const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	const INSET := 1.5
	for c in cells:
		var p := anchor + Vector2(c) * cell
		for d in DIRS:
			if occupied.has(c + d):
				continue
			var a: Vector2
			var b: Vector2
			match d:
				Vector2i.UP:
					a = p + Vector2(0, INSET)
					b = p + Vector2(cell, INSET)
				Vector2i.DOWN:
					a = p + Vector2(0, cell - INSET)
					b = p + Vector2(cell, cell - INSET)
				Vector2i.LEFT:
					a = p + Vector2(INSET, 0)
					b = p + Vector2(INSET, cell)
				_:
					a = p + Vector2(cell - INSET, 0)
					b = p + Vector2(cell - INSET, cell)
			canvas.draw_line(a, b, edge, 2.0)


## 在物品包围盒内居中写一行字。
static func draw_label(
	canvas: CanvasItem,
	cells: Array[Vector2i],
	anchor: Vector2,
	cell: float,
	text: String,
	font: Font,
	font_size: int,
	color: Color
) -> void:
	if cells.is_empty() or font == null or text.is_empty():
		return
	var mx := Vector2i.ZERO
	for c in cells:
		mx.x = maxi(mx.x, c.x)
		mx.y = maxi(mx.y, c.y)
	var box := Vector2(mx.x + 1, mx.y + 1) * cell
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := anchor + (box - text_size) * 0.5 + Vector2(0, text_size.y * 0.78)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
