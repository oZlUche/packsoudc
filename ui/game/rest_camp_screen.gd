## 196（作者定稿「甲 · 夜晚营地」）：休息点整屏是一片营地。事件 [member EventDef.scene] 是 `rest_camp` 的用这一屏（[method GameDirector.script_for]）。
##
## 选项不改数据结构：一个选项是哪件造物看它的后果（[method piece_of]）—— 只有 proceed = 篝火，pass_time + proceed = 帐篷，
## open_altar = 祭坛，open_forge = 铁炉，没有后果 = 路标（继续赶路）。点造物 = 选那一项；对不上的选项退回屏下方一排按钮。
## 条件没过的造物**不藏**，换成用过的图、不能点（营地忽略 `hide_when_locked`）；悬停脚下亮铜圈、悬浮窗写名字与效果（锁住写原因）。
## 歇完不跳屏（[member GameFlow.camp_rest]）：营地重开，篝火熄、脚下冒一行「体力 +N」。摆位与切图在 `assets/ui/rest/`（layout.json）。
extends GameScreen

const ART_DIR := "res://assets/ui/rest/"
const LAYOUT_PATH := ART_DIR + "layout.json"
## 没配营地底图的章节用这一张（和宝箱皮肤的默认一样）
const DEFAULT_BG := &"ruins"
## 「体力 +N」那一行多久淡掉（待定 4 A：3 秒）
const NOTE_SEC := 3.0
## 徽章画多大（待定 1 A：@2x 那张画 64，不放大糊）
const MEDAL_SIZE := 64.0
## 196 补充一：事件有正文才出的字板 —— 左上角、宽、字号；收起后那枚卷轴多大
const BOARD_AT := Vector2(36, 36)
const BOARD_WIDTH := 520.0
const BOARD_FONT := 17
const SCROLL_SIZE := 56.0
## 196 补充一：字板收起了的休息点（点 id → true；同一个点里营地重画不弹回来）
static var _board_folded: Dictionary = {}

## 造物 → [未用的图, 用过的图, 名字]
const PIECES := {
	&"fire": ["fire_lit", "fire_out", "篝火"],
	&"tent": ["tent", "tent_used", "帐篷"],
	&"altar": ["altar", "altar_used", "祭坛"],
	&"forge": ["forge_lit", "forge_cold", "铁炉"],
	&"sign": ["sign", "sign", "继续赶路"],
}
## 造物集合 → 摆位（layout.json 的 variants）；不在表里的落 `full`
const VARIANTS := [
	[[&"fire", &"sign"], &"tutorial_fire"],
	[[&"fire", &"sign", &"tent"], &"tutorial_fire_tent"],
	[[&"altar", &"fire", &"sign", &"tent"], &"tutorial_fire_tent_altar"],
]

var _node: MapNode = null
var _def: EventDef = null
var _payload: Dictionary = {}
## 两份都用完了：没有待选的事件，只剩路标（和还没铸过的铁炉）
var _done := false
var _layout: Dictionary = {}
var _scene: CampScene = null
## 造物 id → [CampPiece]
var _pieces: Dictionary = {}
## 对不上造物的选项按钮
var _extra_btns: Array[Button] = []
var _note: Control = null
var _note_text := ""
var _bag: Control = null
var _bag_panel: Control = null
## 196 补充一：正文字板与收起后的卷轴（没正文都是 null）
var _board: Control = null
var _board_text: RichTextLabel = null
var _scroll: Control = null


func open(payload: Dictionary) -> void:
	_payload = payload
	_node = payload.get("node", null)
	_done = bool(payload.get("done", false))
	var def = payload.get("def", payload.get("camp", null))
	_def = def if def is EventDef else null
	_layout = layout()
	_backdrop(Color("07090d"))
	var bg := TextureRect.new()
	bg.texture = EventImage.load_texture(background_path(flow.run.chapter.chest_skin if flow.run != null and flow.run.chapter != null else DEFAULT_BG))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	set_meta(&"tone", UiTheme.TONE_DARK)     # 夜晚底图：字一律浅色
	_scene = CampScene.new()
	_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scene.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scene)
	_build_pieces()
	_build_footer()
	_build_board()
	_tip = HoverTip.new()
	add_child(_tip)
	if not resized.is_connected(_place):     # 收起背包时原地重画（_reopen），别连两次
		resized.connect(_place)
	_place()
	_show_rest_note()


## layout.json（造物尺寸、原点、各档摆位）；读不出给空字典
static func layout() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	return parsed if parsed is Dictionary else {}


## 这一章的营地底图：跟宝箱皮肤同名（`bg_<id>.png`），没有就用遗迹
static func background_path(skin: StringName) -> String:
	var path := ART_DIR + "bg_%s.png" % skin
	return path if ResourceLoader.exists(path) or FileAccess.file_exists(path) else ART_DIR + "bg_%s.png" % DEFAULT_BG


## 一个选项画成哪件造物（看后果）；对不上返回空
static func piece_of(opt: EventOption) -> StringName:
	if opt == null:
		return &""
	if opt.outcomes.is_empty():
		return &"sign"
	var has := func(cls) -> bool: return opt.outcomes.any(func(o): return is_instance_of(o, cls))
	if has.call(OpenAltar):
		return &"altar"
	if has.call(OpenForge):
		return &"forge"
	if has.call(Proceed):
		return &"tent" if has.call(PassTime) else &"fire"
	return &""


## 按事件里能对上的造物挑摆位（新手教程三档；其余 `full`）
static func variant_for(pieces: Array) -> StringName:
	var sorted := pieces.map(func(p): return String(p))
	sorted.sort()
	for row in VARIANTS:
		var want: Array = (row[0] as Array).map(func(p): return String(p))
		if sorted == want:
			return row[1]
	return &"full"


#region 造物
func _build_pieces() -> void:
	_pieces.clear()
	_extra_btns.clear()
	if _def == null:
		return
	var by_piece := {}     # 造物 → 选项序号（同一件只认第一个）
	for i in _def.options.size():
		var p := piece_of(_def.options[i] as EventOption)
		if p != &"" and not by_piece.has(p):
			by_piece[p] = i
	if _done and not by_piece.has(&"sign"):
		by_piece[&"sign"] = -1
	var variant := variant_for(by_piece.keys())
	var spots: Dictionary = ((_layout.get("variants", {}) as Dictionary).get(String(variant), {}) as Dictionary)
	var ctx := TextTemplate.context_for(flow.run, _node, {})
	var order: Array = by_piece.keys().filter(func(p): return spots.has(String(p)))
	order.sort_custom(func(a, b): return float((spots[String(a)] as Array)[1]) < float((spots[String(b)] as Array)[1]))     # 远的先画、近的压上去
	for p in order:
		var i := int(by_piece[p])
		var piece := CampPiece.new()
		piece.id = p
		piece.index = i
		piece.spot = Vector2(float((spots[String(p)] as Array)[0]), float((spots[String(p)] as Array)[1]))
		var names: Array = PIECES[p]
		piece.tex_on = String(names[0])
		piece.tex_off = String(names[1])
		piece.display_name = String(names[2])
		var state := _state(i, p)
		piece.enabled = bool(state["ok"])
		var opt := _def.options[i] as EventOption if i >= 0 else null
		piece.effect = TextTemplate.plain(opt.label_for(), TextTemplate.option_context(ctx, opt)) if opt != null else "离开营地"
		piece.why = String(state["why"])
		piece.pieces = _layout.get("pieces", {})
		if p == &"altar" and flow.run != null and flow.run.active_faith_id() != &"":
			piece.medal = "rest/medal/%s" % flow.run.active_faith_id()     # 当前神明的徽章；没信仰不画
		piece.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseMotion and _tip != null:
				_tip.follow(get_global_mouse_position()))
		piece.hovered_changed.connect(_on_piece_hovered.bind(piece))
		piece.pressed.connect(func(): click(p))
		_pieces[p] = piece
		_scene.add_child(piece)
	_scene.fire_lit = _pieces.has(&"fire") and (_pieces[&"fire"] as CampPiece).enabled
	_scene.fire_spot = (_pieces[&"fire"] as CampPiece).spot if _pieces.has(&"fire") else Vector2.ZERO
	_scene.pieces = _layout.get("pieces", {})
	for i in _def.options.size():
		if not _pieces.values().any(func(pc): return (pc as CampPiece).index == i):
			_extra_option(i, ctx)


## 选项 [param i] 现在能不能选（两份用完的那一屏：只有路标和没铸过的铁炉）
func _state(i: int, p: StringName) -> Dictionary:
	if _done:
		if p == &"sign":
			return {"ok": true, "why": ""}
		if p == &"forge" and _node != null and not NodeEvents.forge_used(_node):
			return {"ok": true, "why": ""}
		return {"ok": false, "why": "这一份用过了"}
	return flow.run.events.option_state(i) if flow.run != null else {"ok": false, "why": ""}


## 对不上造物的选项（以后作者加的别的后果）：屏下方一排普通按钮，不丢功能
func _extra_option(i: int, ctx: Dictionary) -> void:
	var opt := _def.options[i] as EventOption
	var state := _state(i, &"")
	var b := _button(TextTemplate.plain(opt.label_for(), TextTemplate.option_context(ctx, opt)), func(): choose(i), 14, UiPalette.Tier.SECONDARY)
	b.disabled = not bool(state["ok"])
	_extra_btns.append(b)


func _build_footer() -> void:
	var row := _hbox(8)
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	row.position = Vector2(24, -64)
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(row)
	if flow.run != null:
		row.add_child(_button("整理背包（B）", toggle_bag, 13, UiPalette.Tier.MINOR))     # 和事件屏一样能整理背包
	for b in _extra_btns:
		row.add_child(b)


## 底图 cover 的缩放与偏移重算，造物跟着摆（窗口改大小时也走这里）
func _place() -> void:
	var scene_size := _scene_size()
	var s := maxf(size.x / scene_size.x, size.y / scene_size.y)
	var offset := (size - scene_size * s) * 0.5
	_scene.scale_factor = s
	_scene.offset = offset
	for p in _pieces:
		(_pieces[p] as CampPiece).layout_at(s, offset)
	_scene.queue_redraw()
	if _note != null and _pieces.has(&"fire"):
		_place_note()


func _scene_size() -> Vector2:
	var wh: Array = _layout.get("scene", [1920, 1200])
	return Vector2(float(wh[0]), float(wh[1]))


func _on_piece_hovered(on: bool, piece: CampPiece) -> void:
	if not on:
		_tip.release()
		return
	var second := piece.effect if piece.enabled else (piece.why if piece.why != "" else "用不了")
	_tip.show_text("[b]%s[/b]\n%s" % [piece.display_name, second], get_global_mouse_position())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _tip != null:
		_tip.follow(get_global_mouse_position())
#endregion


#region 正文字板（196 补充一）
## 事件写了正文（教程的神坛教献祭）就在左上角出一块深底字板；标题不显示。右上「×」收起成一枚卷轴，再点展开
func _build_board() -> void:
	if _def == null or _def.text_for().strip_edges() == "":
		return
	var ctx := TextTemplate.context_for(flow.run, _node, {})
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.PANEL_TOOLTIP
	panel.position = BOARD_AT
	panel.set_meta(&"tone", UiTheme.TONE_DARK)
	var col := _vbox(4)
	panel.add_child(col)
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.tooltip_text = "收起"
	close.pressed.connect(fold_board.bind(true))
	close_row.add_child(close)
	col.add_child(close_row)
	_board_text = UiTheme.rich_block(BOARD_WIDTH, BOARD_FONT, TextTemplate.render(_def.text_for(), ctx))
	col.add_child(_board_text)
	add_child(panel)
	_board = panel
	var scroll := TextureButton.new()
	scroll.texture_normal = UiTheme.art_cached("setup/summary_note")
	scroll.ignore_texture_size = true
	scroll.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	scroll.custom_minimum_size = Vector2.ONE * SCROLL_SIZE
	scroll.size = Vector2.ONE * SCROLL_SIZE
	scroll.position = BOARD_AT
	scroll.tooltip_text = "展开"
	scroll.pressed.connect(fold_board.bind(false))
	add_child(scroll)
	_scroll = scroll
	_apply_fold()


## 收起 / 展开字板（记在这个休息点上）
func fold_board(folded: bool) -> void:
	if _node != null:
		if folded:
			_board_folded[_node.id] = true
		else:
			_board_folded.erase(_node.id)
	_apply_fold()


func _apply_fold() -> void:
	if _board == null:
		return
	var folded := _node != null and _board_folded.has(_node.id)
	_board.visible = not folded
	_scroll.visible = folded


## 字板上的字（测试看；没字板是空串）
func board_text() -> String:
	return Glossary.strip_bbcode(_board_text.text) if _board_text != null else ""


func board_shown() -> bool:
	return _board != null and _board.visible
#endregion


#region 歇完冒字
## 刚在这个点歇过（[member GameFlow.camp_rest]）：篝火脚下冒一行「体力 +N，现在 x / y」，3 秒淡掉；读了就清
func _show_rest_note() -> void:
	if flow.camp_rest.is_empty() or _node == null or int(flow.camp_rest.get("node", -1)) != _node.id:
		return
	var n := int(flow.camp_rest.get("restored", 0))
	flow.camp_rest = {}
	var v := flow.run.vitality
	_note_text = "体力 +%d，现在 %d / %d" % [n, v.current, v.maximum]
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.06, 0.08, 0.85)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(8)
	panel.add_theme_stylebox_override(&"panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta(&"tone", UiTheme.TONE_DARK)
	panel.add_child(UiTheme.rich_block(0, 15, "[color=@tip_fg]%s[/color]" % _note_text))
	(panel.get_child(0) as RichTextLabel).autowrap_mode = TextServer.AUTOWRAP_OFF
	(panel.get_child(0) as RichTextLabel).mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_note = panel
	_place_note.call_deferred()
	var tw := panel.create_tween()
	tw.tween_interval(NOTE_SEC * 0.6)
	tw.tween_property(panel, "modulate:a", 0.0, NOTE_SEC * 0.4)


func _place_note() -> void:
	if _note == null or not is_instance_valid(_note):
		return
	var at := _scene.to_screen(_pieces[&"fire"].spot) if _pieces.has(&"fire") else size * 0.5
	_note.reset_size()
	_note.position = at + Vector2(-_note.size.x * 0.5, 12.0)


## 刚冒出来的那一行（测试看；没冒是空串）
func rest_note() -> String:
	return _note_text
#endregion


#region 公开动作
## 点一件造物。路标 = 继续赶路；两份用完的那一屏路标回地图、铁炉照开。点不动返回 false
func click(p: StringName) -> bool:
	var piece: CampPiece = _pieces.get(p, null)
	if piece == null or not piece.enabled:
		return false
	_tip.hide_tip()
	if _done:
		if p == &"forge":
			return flow.open_forge(_node)
		flow.resume()
		return true
	return choose(piece.index)


## 通用的「往下走」（和事件屏一样）：有待选的营地选第一个能选的；两份用完的那一屏 = 点路标
func proceed() -> void:
	if not _done and _def != null and flow.run != null and flow.run.events.pending_event() == _def:
		for i in _def.options.size():
			if bool(flow.run.events.option_state(i)["ok"]):
				choose(i)
				return
		return
	flow.resume()


## 选第 i 项（数字键、对不上造物的按钮也走这里）
func choose(i: int) -> bool:
	return flow.choose_event(i)


## 造物（测试看）
func piece(p: StringName) -> CampPiece:
	return _pieces.get(p, null)


func pieces() -> Array:
	return _pieces.keys()


func variant() -> StringName:
	return variant_for(_pieces.keys())


func extra_buttons() -> Array[Button]:
	return _extra_btns


func is_options_page() -> bool:
	return true


func toggle_bag() -> void:
	if _bag != null:
		_bag.hide()
		_bag.queue_free()
		_bag = null
		_reopen(_payload)     # 收起时重画（条件可能因为整理过了而满足）
		return
	if flow.run == null:
		return
	_tip.hide_tip()
	_bag = _shade(0.7)
	var win := BagWindow.new()
	_bag.add_child(win)
	_bag_panel = win.setup_bag(flow.run, font, toggle_bag)


func bag_open() -> bool:
	return _bag != null


func bag_panel() -> Control:
	return _bag_panel if _bag != null and is_instance_valid(_bag_panel) else null


func ground_double_clicked(uid: int) -> bool:
	if _bag != null:
		return false
	return _ground_to_bag(uid, func():
		if _bag == null:
			toggle_bag()
		return bag_panel())


## Esc：开着背包就关背包，否则 = 点路标（继续赶路）
func escape() -> bool:
	if _bag != null:
		toggle_bag()
		return true
	return click(&"sign")


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_B:
		toggle_bag()
		get_viewport().set_input_as_handled()
	elif _bag == null and not _done and _def != null and key.keycode >= KEY_1 and key.keycode <= KEY_9:
		choose(int(key.keycode - KEY_1))     # 数字键按选项序
		get_viewport().set_input_as_handled()
#endregion


## 营地底层：底图之上、造物之下画篝火的暖光（只在篝火没用时）；造物是它的子节点
class CampScene extends Control:
	var scale_factor := 1.0
	var offset := Vector2.ZERO
	var fire_lit := false
	var fire_spot := Vector2.ZERO
	var pieces: Dictionary = {}

	## 场景坐标（1920×1200）→ 屏上
	func to_screen(p: Vector2) -> Vector2:
		return offset + p * scale_factor

	func _draw() -> void:
		if not fire_lit:
			return
		var tex := UiTheme.art_cached("rest/fire_light")
		var meta: Dictionary = pieces.get("fire_light", {})
		if tex == null or meta.is_empty():
			return
		var sz := Vector2(float(meta["size"][0]), float(meta["size"][1])) * scale_factor
		var org := Vector2(float(meta["origin"][0]), float(meta["origin"][1])) * scale_factor
		draw_texture_rect(tex, Rect2(to_screen(fire_spot) - org, sz), false)


## 一件造物：按图的不透明处接鼠标（透明处点穿到底图）；悬停脚下亮铜圈；用过 / 锁住画另一张、不能点
class CampPiece extends Control:
	signal hovered_changed(on: bool)
	signal pressed

	var id: StringName = &""
	var index := -1
	## 落地中心（场景坐标）
	var spot := Vector2.ZERO
	var tex_on := ""
	var tex_off := ""
	var display_name := ""
	## 悬浮窗第二行：当前效果 / 锁住的原因
	var effect := ""
	var why := ""
	var enabled := true
	## 祭坛顶上的徽章（没信仰空）
	var medal := ""
	var pieces: Dictionary = {}
	var hovered := false
	var _scale := 1.0
	## 图名 → BitMap（alpha 判定，同一张图只做一次）
	static var _masks: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func():
			hovered = true
			queue_redraw()
			hovered_changed.emit(true))
		mouse_exited.connect(func():
			hovered = false
			queue_redraw()
			hovered_changed.emit(false))

	func texture_name() -> String:
		return tex_on if enabled else tex_off

	func _meta(name: String) -> Dictionary:
		return pieces.get(name, {})

	func _origin(name: String) -> Vector2:
		var o: Array = _meta(name).get("origin", [0, 0])
		return Vector2(float(o[0]), float(o[1]))

	func _size_of(name: String) -> Vector2:
		var o: Array = _meta(name).get("size", [0, 0])
		return Vector2(float(o[0]), float(o[1]))

	## 按营地的缩放摆到屏上：控件盖住这张图（原点对齐落地中心）
	func layout_at(s: float, offset: Vector2) -> void:
		_scale = s
		var name := texture_name()
		position = offset + (spot - _origin(name)) * s
		size = _size_of(name) * s
		queue_redraw()

	func _draw() -> void:
		var name := texture_name()
		var org := _origin(name) * _scale
		if hovered and enabled:
			var ring := UiTheme.art_cached("rest/hover_ring")
			if ring != null:
				draw_texture_rect(ring, Rect2(org - _origin("hover_ring") * _scale, _size_of("hover_ring") * _scale), false)
		var tex := UiTheme.art_cached("rest/" + name)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
		if medal != "":
			var m := UiTheme.art_cached(medal)
			if m != null:
				var mo: Dictionary = pieces.get("_altar_medal", {})
				var off: Array = mo.get("offset", [0, -235])
				var side := MEDAL_SIZE * _scale
				var c := org + Vector2(float(off[0]), float(off[1])) * _scale
				draw_texture_rect(m, Rect2(c - Vector2.ONE * side * 0.5, Vector2.ONE * side), false)

	## 只在图不透明的地方算点中
	func _has_point(p: Vector2) -> bool:
		if not Rect2(Vector2.ZERO, size).has_point(p) or _scale <= 0.0:
			return false
		var mask := _mask(texture_name())
		if mask == null:
			return true
		var px := Vector2i(p / _scale)
		var ms := mask.get_size()
		if px.x < 0 or px.y < 0 or px.x >= ms.x or px.y >= ms.y:
			return false
		return mask.get_bitv(px)

	static func _mask(name: String) -> BitMap:
		if _masks.has(name):
			return _masks[name]
		var tex := UiTheme.art_cached("rest/" + name)
		var bm: BitMap = null
		if tex != null:
			var img := tex.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				bm = BitMap.new()
				bm.create_from_image_alpha(img, 0.1)
		_masks[name] = bm
		return bm

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and enabled:
			accept_event()
			pressed.emit()
