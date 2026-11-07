## 279 起的砧；286 §2.2：休息点点「铁炉」进一块两栏屏 砧 | 铸炉，这块是左栏（铸炉屏左上，压在炉子那块底图上，不要新图 —— 待定 2 A）。
## 一行横排：武器槽、材料槽、出件槽，下面锤键；右边一张便条。顶上一行「砧」+ 状态（免费一次 / 这处的砧用过了）。
## 只放了武器：便条列出它能升成的每一把（名字按稀有度上色 + 要哪类材料，待定 17 A）；没有升级配方 → 「这把没有可升的」；
## 两件都放了、配不上：材料槽红框 + 便条头一句「要【金属】≥ 绿」（这把能配的第一类）；配得上：出件槽浮出结果件的淡影，便条换成结果件的完整说明。
## 每个休息点免费锤一次（[method GameFlow.anvil_strike]）。离开铁炉时槽里的东西回背包（放不下到地上）
class_name AnvilColumn
extends Control

const WIDTH := 780.0
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
const KEY_H := 44.0
## 三个槽那一排的宽；便条从这往右
const ROW_W := 476.0
const TITLE_FONT := 18
const STATUS_FONT := 14
const NOTE_FONT := 14
const NOTE_PAD := 14
const NOTE_PAD_TOP := 22
const NOTE_PAD_BOTTOM := 10
const GHOST := Color(1, 1, 1, 0.45)
## 材料配不上：材料槽外一圈红
const WARN_RING := 3.0

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
var strike_key: Button = null
var _status: Label = null
var _warn: ReferenceRect = null
var _note: RichTextLabel = null
var _font: Font = null


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
	_weapon_view = _view(weapon_slot, Vector2(FRAME_IN, HEAD_H))
	var mat_at := Vector2(FRAME_IN + float(WEAPON_SLOT.x) * CELL + GAP + FRAME_IN * 2.0, HEAD_H + (row_h - float(MATERIAL_SLOT.y) * CELL) * 0.5)
	_material_view = _view(material_slot, mat_at)
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
	var out_at := Vector2(ROW_W - FRAME_IN - float(OUT_SLOT.x) * CELL, HEAD_H)
	_out_view = _view(out, out_at)
	_ghost_view = _view(_ghost, out_at)
	_ghost_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_view.modulate = GHOST
	strike_key = ScrollKey.short(UiText.t("anvil.strike"), strike)
	strike_key.position = Vector2(0, HEAD_H + row_h + FRAME_IN + GAP * 0.5)
	strike_key.custom_minimum_size = Vector2(ROW_W, KEY_H)
	strike_key.size = strike_key.custom_minimum_size
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
	var v := InventoryView.new()
	v.label_font = _font
	v.inventory = g
	v.cell_px = CELL
	v.show_adjacency = false
	host.add_child(v)
	var f := BoardFrame.wrap(v, "plain", true)
	f.position = -Vector2.ONE * f.inset()
	return v


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
		if not _ghost.place(made, Vector2i.ZERO, 0):
			_ghost.try_add(made, true)
		lines.append(ItemTooltip.describe(made))
	elif w != null and out.item_count() == 0:
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
	return "[color=@rarity%d]%s[/color]　%s" % [d.rarity, Names.of(d), UiText.t("tip.sep").join(PackedStringArray(mats))]
