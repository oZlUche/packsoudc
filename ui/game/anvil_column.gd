## 279 起的砧；286 §2.2：休息点点「铁炉」进一块两栏屏 砧 | 铸炉，这块是左栏（铸炉屏左上，压在炉子那块底图上，不要新图 —— 待定 2 A）。
## 一行横排：武器槽、材料槽、出件槽，下面锤键；右边一张便条。顶上一行「砧」+ 状态（免费一次 / 这处的砧用过了）。
## 只放了武器：便条列出它能升成的每一把（名字按稀有度上色 + 要哪类材料，待定 17 A）；没有升级配方 → 「这把没有可升的」；
## 两件都放了、配不上：材料槽红框 + 便条头一句「要【金属】≥ 绿」（这把能配的第一类）；配得上：出件槽浮出结果件的淡影，砧下面并排两块信息窗（298 [UpgradeCompare]：现在这把 | 锤完那把）。
## 每个休息点免费锤一次（[method GameFlow.anvil_strike]）。离开铁炉时槽里的东西回背包（放不下到地上）
class_name AnvilColumn
extends Control

const WIDTH := 848.0
const HEIGHT := 244.0
const CELL := 32.0
const WEAPON_SLOT := Vector2i(4, 4)
const MATERIAL_SLOT := Vector2i(3, 3)
const OUT_SLOT := Vector2i(4, 4)
const GAP := 16.0
## 顶上一行「砧」+ 状态占的高（槽框往外伸一圈，也算在里面）
const HEAD_H := 44.0
## 槽框往外伸的那一圈：槽往里让开
const FRAME_IN := 12.0
## 279 定稿 A 铁砧：圆锤键（88，图 anvil/hammer_<off|ready|hover|pressed|used>，2 倍图），放在材料槽和出件槽中间
const KEY_SIDE := 88.0
const KEY_ART := "anvil/hammer_"
## 空槽里淡刻的形（2 倍图）：武器槽一把剑 112、材料槽一块矿石 80
const GLYPH_WEAPON := "anvil/glyph_weapon"
const GLYPH_MATERIAL := "anvil/glyph_material"
## 三个槽那一排的宽；便条从这往右
const ROW_W := 544.0
const TITLE_FONT := 18
const STATUS_FONT := 14
const NOTE_FONT := 14
const NOTE_PAD := 14
const NOTE_PAD_TOP := 22
const NOTE_PAD_BOTTOM := 10
const GHOST := Color(1, 1, 1, 0.45)
## 材料配不上：材料槽外一圈红
const WARN_RING := 3.0
## 298：两块信息窗的上沿 = 槽框下沿再往下这么多（压住砧板下边那一截，少盖铸炉槽上的签）
const COMPARE_GAP := 4.0

var flow: GameFlow = null
var node: MapNode = null
var weapon_slot: GridInventory = null
var material_slot: GridInventory = null
var out: GridInventory = null
var _ghost: GridInventory = null
var _weapon_view: InventoryView = null
var _material_view: InventoryView = null
var _out_view: InventoryView = null
var _ghost_view: InventoryView = null
var strike_key: TextureButton = null
var _glyph_weapon: TextureRect = null
var _glyph_material: TextureRect = null
var _status: Label = null
var _warn: ReferenceRect = null
var _note: RichTextLabel = null
var _font: Font = null
## 298：配得上时并排的两块信息窗（现在这把 | 锤完那把），挂在砧下面
var compare: UpgradeCompare = null


func setup(p_flow: GameFlow, p_node: MapNode, font: Font, drag: DragLayer, tip: HoverTip) -> AnvilColumn:
	flow = p_flow
	node = p_node
	_font = font
	name = "AnvilColumn"
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	UiTheme.set_tone(self, UiTheme.TONE_DARK)
	var head := UiTheme.hbox(12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.size = Vector2(WIDTH, HEAD_H - 8.0)
	add_child(head)
	var title := UiTheme.make_label(UiText.t("camp.anvil"), TITLE_FONT, UiPalette.FG)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title)
	_status = UiTheme.make_label("", STATUS_FONT, UiPalette.FG)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_status)
	weapon_slot = _grid(WEAPON_SLOT, func(d: ItemDef) -> bool: return d != null and d.tags.has(&"weapon"))
	material_slot = _grid(MATERIAL_SLOT, func(d: ItemDef) -> bool: return d != null and (d.tags.has(&"material") or d.tags.has(&"crystal")))     # 第二批：魔晶石升橙
	out = _grid(OUT_SLOT, Callable())
	_ghost = _grid(OUT_SLOT, Callable())
	var row_h := float(WEAPON_SLOT.y) * CELL
	var row_y := HEAD_H + (HEIGHT - HEAD_H - row_h - FRAME_IN) * 0.5     # 一排槽在便条那么高的地方上下居中
	_weapon_view = _view(weapon_slot, Vector2(FRAME_IN, row_y))
	_glyph_weapon = _glyph(GLYPH_WEAPON, Rect2(Vector2(FRAME_IN, row_y), Vector2(WEAPON_SLOT) * CELL))
	var mat_at := Vector2(FRAME_IN + float(WEAPON_SLOT.x) * CELL + GAP + FRAME_IN * 2.0, row_y + (row_h - float(MATERIAL_SLOT.y) * CELL) * 0.5)
	_material_view = _view(material_slot, mat_at)
	_glyph_material = _glyph(GLYPH_MATERIAL, Rect2(mat_at, Vector2(MATERIAL_SLOT) * CELL))
	_warn = ReferenceRect.new()
	_warn.name = "MaterialWarn"
	_warn.editor_only = false
	_warn.border_color = UiPalette.HP
	_warn.border_width = WARN_RING
	_warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warn.position = mat_at - Vector2.ONE * (WARN_RING + 4.0)
	_warn.size = Vector2(MATERIAL_SLOT) * CELL + Vector2.ONE * 2.0 * (WARN_RING + 4.0)
	_warn.visible = false
	add_child(_warn)
	var out_at := Vector2(ROW_W - FRAME_IN - float(OUT_SLOT.x) * CELL, row_y)
	_out_view = _view(out, out_at)
	_ghost_view = _view(_ghost, out_at)
	_ghost_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_view.modulate = GHOST
	strike_key = _hammer_key()
	strike_key.name = "StrikeKey"
	var key_x := (mat_at.x + float(MATERIAL_SLOT.x) * CELL + FRAME_IN + out_at.x - FRAME_IN) * 0.5
	strike_key.size = Vector2.ONE * KEY_SIDE
	strike_key.position = Vector2(key_x, row_y + row_h * 0.5) - strike_key.size * 0.5
	add_child(strike_key)
	# 便条是浅底；上边多留一点，不压名字
	var note_x := ROW_W + GAP
	var paper := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_SUMMARY_NOTE, NOTE_PAD, NOTE_PAD_TOP, NOTE_PAD, NOTE_PAD_BOTTOM)
	paper.name = "AnvilNote"
	paper.position = Vector2(note_x, HEAD_H - FRAME_IN)
	paper.custom_minimum_size = Vector2(WIDTH - note_x, HEIGHT - HEAD_H + FRAME_IN)
	paper.size = paper.custom_minimum_size
	add_child(paper)
	_note = UiTheme.rich_block(WIDTH - note_x - 2.0 * float(NOTE_PAD), NOTE_FONT)
	_note.fit_content = false
	_note.scroll_active = true
	_note.custom_minimum_size.y = HEIGHT - HEAD_H + FRAME_IN - float(NOTE_PAD_TOP + NOTE_PAD_BOTTOM)
	paper.add_child(_note)
	compare = UpgradeCompare.new()
	compare.tip = tip
	compare.anchors = func() -> Array: return [_weapon_view, _material_view, strike_key, _out_view, _ghost_view]     # 指针在砧面上才显示（UI设计 复核 11-11）
	compare.position = Vector2(0.0, row_y + row_h + FRAME_IN + COMPARE_GAP)
	add_child(compare)
	for v in [_weapon_view, _material_view, _out_view]:     # 300 §2.4：槽里、出件双击 / 右键 = 取回背包（放不下到地上）
		var view := v as InventoryView
		view.item_double_clicked.connect(func(_v: ContainerView, uid: int): take_back(view.inventory, uid))
		view.actions_for = func(uid: int) -> Array:
			return [ItemActions.make(&"quick", UiText.t("act.take" if view == _out_view else "act.take_back"), func(): take_back(view.inventory, uid))]
	if tip != null:     # 两窗显示时砧上三个槽不弹自己的悬浮窗：两扇说的是同一把（UI设计 复核 v5.71）
		var slots: Array[ContainerView] = [_weapon_view, _material_view, _out_view]
		var prev := tip.hover_quiet
		tip.hover_quiet = func(v: ContainerView, uid: int) -> bool:     # 只管停留弹窗；右键 / 双击取回照旧（不用 can_show：那会连右键一起拦掉）
			return (compare.visible and v in slots) or (prev.is_valid() and bool(prev.call(v, uid)))
		compare.visibility_changed.connect(func():
			if compare.visible and tip.showing_for() in slots and not tip.is_pinned():
				tip.hide_tip())
	for v in [_weapon_view, _material_view, _out_view]:
		if drag != null:
			drag.register_view(v)
		if tip != null:
			tip.watch(v)
	if drag != null:
		var prior := drag.drop_filter
		drag.drop_filter = func(inst: ItemInstance, target: ItemContainer) -> bool:
			if target == out:
				return out.has_item(inst.uid)     # 出件槽只出不进
			if target == weapon_slot or target == material_slot:
				var g := target as GridInventory
				if inst.is_locked_by_player() or not g.accepts(inst.def):
					return false
				return g.item_count() == 0 or (g.item_count() == 1 and g.has_item(inst.uid))     # 一槽一件
			return not prior.is_valid() or bool(prior.call(inst, target))
	for g in [weapon_slot, material_slot, out]:
		(g as GridInventory).changed.connect(_refresh)
	_refresh()
	return self


func _grid(cells: Vector2i, filter: Callable) -> GridInventory:
	var g := GridInventory.new(cells, 0, false)
	g.accept_filter = filter
	return g


func _view(g: GridInventory, at: Vector2) -> InventoryView:
	var host := Control.new()
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(host)
	var v := InventoryView.make(g, _font)
	v.cell_px = CELL
	host.add_child(v)
	var f := BoardFrame.wrap(v, "anvil")
	f.position = -Vector2.ONE * f.inset()
	return v


## 圆锤键（不写字）
func _hammer_key() -> TextureButton:
	var k := TextureButton.new()
	k.ignore_texture_size = true
	k.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	k.texture_normal = UiTheme.art_cached(KEY_ART + "ready")
	k.texture_hover = UiTheme.art_cached(KEY_ART + "hover")
	k.texture_pressed = UiTheme.art_cached(KEY_ART + "pressed")
	k.texture_disabled = UiTheme.art_cached(KEY_ART + "off")
	k.pressed.connect(strike)
	return k


## 空槽里淡刻的形：压在槽上、不吃鼠标，槽里有东西就藏起来
func _glyph(art: String, slot: Rect2) -> TextureRect:
	var t := UiTheme.picture(UiTheme.art_cached(art), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	var side := t.texture.get_size() * 0.5 if t.texture != null else Vector2.ZERO
	t.size = side
	t.position = slot.get_center() - side * 0.5
	add_child(t)
	return t


func weapon() -> ItemInstance:
	return weapon_slot.items()[0] as ItemInstance if weapon_slot.item_count() == 1 else null


func material() -> ItemInstance:
	return material_slot.items()[0] as ItemInstance if material_slot.item_count() == 1 else null


## 两件都放了、配得上：锤下去会出的那一件（不在任何容器里）；否则 null
func preview() -> ItemInstance:
	if flow == null:
		return null
	return Anvil.result(weapon(), material(), flow.smith_recipes, flow.items)


## 锤键：两件消耗、出件进出件槽（放不下到地上）、这座砧用掉。没锤成返回 null
func strike() -> ItemInstance:
	if flow == null or out.item_count() > 0:
		return null
	var w := weapon()
	var m := material()
	var made := flow.anvil_strike(node, w, weapon_slot, m, material_slot)
	if made == null:
		return null
	if not out.try_add(made, true) and flow.run != null:
		flow.run.storage.admit(made)
	_refresh()
	return made


## 300 §2.4：包里的这件双击 / 右键先试砧 —— 砧没用过、出件槽空着：有升级配方的武器进空的武器槽，材料进空的材料槽；砧不收 = null
func quick_slot(inst: ItemInstance) -> GridInventory:
	if inst == null or flow == null or not flow.anvil_open(node) or out.item_count() > 0 or inst.is_locked_by_player():
		return null
	if weapon_slot.item_count() == 0 and weapon_slot.accepts(inst.def) and not Anvil.upgrades_for(inst.def, flow.smith_recipes).is_empty():
		return weapon_slot
	if material_slot.item_count() == 0 and material_slot.accepts(inst.def):
		return material_slot
	return null


## 300 §2.4：槽里 / 出件的一件回背包，放不下到地上
func take_back(g: GridInventory, uid: int) -> bool:
	if flow == null or flow.run == null or g == null or not g.has_item(uid):
		return false
	if InventoryService.transfer_auto(g, uid, flow.run.board):
		return true
	return InventoryService.transfer_auto(g, uid, flow.run.storage)


## 离开：三个槽里的东西回背包（放不下到地上）
func release() -> void:
	if flow == null or flow.run == null:
		return
	for g in [weapon_slot, material_slot, out]:
		for inst in (g as GridInventory).items().duplicate():
			var it := inst as ItemInstance
			if InventoryService.transfer_auto(g, it.uid, flow.run.board):
				continue
			(g as GridInventory).remove(it.uid)
			flow.run.storage.admit(it)


## 便条上的几行（测试看）
func note_text() -> String:
	return Glossary.strip_bbcode(_note.text) if _note != null else ""


## 顶上那句状态（测试看）
func status_text() -> String:
	return _status.text if _status != null else ""


## 材料槽红框亮着没（两件都放了、配不上）
func material_warned() -> bool:
	return _warn != null and _warn.visible


func _refresh() -> void:
	if _note == null:
		return
	_ghost.clear()
	var lines: Array[String] = []
	var open := flow != null and flow.anvil_open(node)
	var w := weapon()
	var made := preview()
	var ups := Anvil.upgrades_for(w.def, flow.smith_recipes if flow != null else []) if w != null else ([] as Array[SmithRecipeDef])
	var mismatch := w != null and material() != null and made == null and not ups.is_empty() and out.item_count() == 0
	if made != null and out.item_count() == 0:
		var r := Anvil.recipe_for(w.def, material().def, flow.smith_recipes)
		var known := r != null and known_upgrade(r)     # 305：没锤过、也不认识出件 —— 不画出件、右窗打问号
		if known and not _ghost.place(made, Vector2i.ZERO, 0):
			_ghost.try_add(made, true)
		compare.show_pair(w, made, false, not known)     # 298：出件简述换成两窗并排；便条照旧列这把能升成的
	else:
		compare.clear()
	if w != null and out.item_count() == 0:
		if ups.is_empty():
			lines.append(UiText.t("anvil.no_upgrade"))
		if mismatch:
			lines.append("[color=@danger]%s[/color]" % need_line(ups[0]))
		for r in ups:
			lines.append(upgrade_line(r, flow.items))
	_note.text = UiPalette.toned("\n".join(PackedStringArray(lines)), UiTheme.TONE_LIGHT)     # 便条是浅底：字色取浅底版
	_warn.visible = mismatch
	_status.text = UiText.t("anvil.free") if open else UiText.t("anvil.used")
	UiTheme.label(_status, STATUS_FONT, UiPalette.FG if open else UiPalette.DIM)     # 用过了：灰
	_ghost_view.visible = out.item_count() == 0
	strike_key.disabled = not open or made == null or out.item_count() > 0
	strike_key.texture_disabled = UiTheme.art_cached(KEY_ART + ("off" if open else "used"))     # 用过了：冷
	_glyph_weapon.visible = weapon_slot.item_count() == 0
	_glyph_material.visible = material_slot.item_count() == 0


## 286：配不上时的那一句 ——「要【金属】≥ 绿」（这张配方头一类材料）
static func need_line(r: SmithRecipeDef) -> String:
	for m in r.material_inputs:
		return UiText.t("anvil.need") % ItemTooltip.recipe_material(r, String(m))
	return ""


## 待定 17 A：一张升级配方写一行 ——「名字（稀有度色）· 要【材料类】（档起）」
static func upgrade_line(r: SmithRecipeDef, items: ItemDatabase) -> String:
	var d := items.get_def(r.output) if items != null else null
	if d == null:
		return ""
	var mats: Array[String] = []
	for m in r.material_inputs:
		mats.append(UiText.t("anvil.needs") % [r.material_name(String(m), items), ItemTooltip.rarity_name(int(r.material_inputs[m]))])
	var shown := "[color=@rarity%d]%s[/color]" % [d.rarity, Names.of(d)] if known_upgrade(r) else UiText.t("fuse.unknown")     # 305
	return "%s　%s" % [shown, UiText.t("tip.sep").join(PackedStringArray(mats))]


## 305（方案 §6.2）：玩家知道这张升级出什么吗 —— 自己锤过，或认识出件
static func known_upgrade(r: SmithRecipeDef) -> bool:
	return ItemTooltip.recipe_known(r.id) or ItemTooltip.item_known(r.output)
