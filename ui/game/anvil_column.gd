## 279 §四.3（UI替换美术 17:20 的摆法，架构设计同意）：营地的砧 = 背包窗右栏（272 宽）换成砧 —— 武器槽、材料槽，锤键，出件槽，下面一张便条。
## 只放了武器：便条列出它能升成的每一把（名字按稀有度上色 + 要哪类材料 + 新加的那一句，待定 17 A）；
## 两件都放了：出件槽浮出结果件的淡影，便条换成结果件的完整说明（补充二 §五：和包里看到的一样，按材料算好品质）。
## 每个休息点免费锤一次（[method GameFlow.anvil_strike]）。关窗时槽里的东西回背包（放不下到地上）。
## 样式是占位：深色底 + 素框 + 便条，等作者从 UI替换美术 的 A / B / C 里挑定再换图
class_name AnvilColumn
extends Control

const WIDTH := 272.0
const HEIGHT := 540.0
const CELL := 32.0
const WEAPON_SLOT := Vector2i(4, 4)
const MATERIAL_SLOT := Vector2i(3, 3)
const OUT_SLOT := Vector2i(4, 4)
const GAP := 16.0
const KEY_H := 44.0
const NOTE_FONT := 14
const GHOST := Color(1, 1, 1, 0.45)

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
	weapon_slot = _grid(WEAPON_SLOT, func(d: ItemDef) -> bool: return d != null and d.tags.has(&"weapon"))
	material_slot = _grid(MATERIAL_SLOT, func(d: ItemDef) -> bool: return d != null and d.tags.has(&"material"))
	out = _grid(OUT_SLOT, Callable())
	_ghost = _grid(OUT_SLOT, Callable())
	var row_h := float(WEAPON_SLOT.y) * CELL
	_weapon_view = _view(weapon_slot, Vector2(0, 0))
	_material_view = _view(material_slot, Vector2(float(WEAPON_SLOT.x) * CELL + GAP, (row_h - float(MATERIAL_SLOT.y) * CELL) * 0.5))
	strike_key = ScrollKey.short(UiText.t("anvil.strike"), strike)
	strike_key.position = Vector2(0, row_h + GAP)
	strike_key.custom_minimum_size = Vector2(WIDTH, KEY_H)
	strike_key.size = strike_key.custom_minimum_size
	add_child(strike_key)
	var out_at := Vector2((WIDTH - float(OUT_SLOT.x) * CELL) * 0.5, row_h + GAP * 2.0 + KEY_H)
	_out_view = _view(out, out_at)
	_ghost_view = _view(_ghost, out_at)
	_ghost_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_view.modulate = GHOST
	var note_top := out_at.y + float(OUT_SLOT.y) * CELL + GAP
	var paper := UiTheme.panel(PanelContainer.new(), 8, UiTheme.PANEL_SUMMARY_NOTE)
	paper.name = "AnvilNote"
	paper.position = Vector2(0, note_top)
	paper.custom_minimum_size = Vector2(WIDTH, HEIGHT - note_top)
	paper.size = paper.custom_minimum_size
	add_child(paper)
	_note = UiTheme.rich_block(WIDTH - 16.0, NOTE_FONT)
	_note.fit_content = false
	_note.scroll_active = true
	_note.custom_minimum_size.y = HEIGHT - note_top - 16.0
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


## 关窗：三个槽里的东西回背包（放不下到地上）
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


func _refresh() -> void:
	if _note == null:
		return
	_ghost.clear()
	var lines: Array[String] = []
	var open := flow != null and flow.anvil_open(node)
	var w := weapon()
	var made := preview()
	if made != null and out.item_count() == 0:
		if not _ghost.place(made, Vector2i.ZERO, 0):
			_ghost.try_add(made, true)
		lines.append(ItemTooltip.describe(made))
	elif w != null and out.item_count() == 0:
		var ups := Anvil.upgrades_for(w.def, flow.smith_recipes if flow != null else [])
		if ups.is_empty():
			lines.append(UiText.t("anvil.no_upgrade"))
		for r in ups:
			lines.append(upgrade_line(r, flow.items))
	if not open and out.item_count() == 0:
		lines.append("[color=@dim]%s[/color]" % UiText.t("anvil.used"))
	_note.text = UiPalette.resolve_styles("\n".join(PackedStringArray(lines)))
	_ghost_view.visible = out.item_count() == 0
	strike_key.disabled = not open or made == null or out.item_count() > 0


## 待定 17 A：一张升级配方写一行 ——「名字（稀有度色）· 要【材料类】（档起）」
static func upgrade_line(r: SmithRecipeDef, items: ItemDatabase) -> String:
	var d := items.get_def(r.output) if items != null else null
	if d == null:
		return ""
	var mats: Array[String] = []
	for m in r.material_inputs:
		mats.append(UiText.t("anvil.needs") % [ItemMaterials.name_of(StringName(String(m))), ItemTooltip.rarity_name(int(r.material_inputs[m]))])
	return "[color=@rarity%d]%s[/color]　%s" % [d.rarity, Names.of(d), UiText.t("tip.sep").join(PackedStringArray(mats))]
