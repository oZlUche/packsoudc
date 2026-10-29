## 264 §二（作者 16:43「按推荐来」= 线框 1-A）：基地「出征」页碑右边那一列 —— 「上回出征」木牌（角色肖像小框 + 名、地图 · 规模、难度）、
## 「军需」木牌（每局开局随身带的技能圆槽 + 数量角标、科技给的局外加成小牌；都没有写「尚无」）、右下【开始探索】主档木牌（原左下「再来一局」）。
## 木牌先垫羊皮纸占位（浅底墨字），定稿 UI替换美术 出；不做「沿用上回直接出发」（待定 2）
class_name ExpeditionBoard
extends VBoxContainer

const WIDTH := 560.0
const LAST_H := 200.0
const SUPPLY_H := 260.0
const START := Vector2(360, 96)
const START_FONT := 30
const PORTRAIT := 72
const NAME_FONT := 22
const LINE_FONT := 17
const SLOT := 56.0
const BADGE_FONT := 14
const INK_SLOT := Color("5a4433")
const PAD := 24

var flow: GameFlow = null
var start_btn: Button = null
var last_plate: PanelContainer = null
var supply_plate: PanelContainer = null
## 「上回出征」三行写的字（测试看）；没出征过是空
var _last_lines: Array[String] = []
## 军需：[[随身技能 id, 个数], …] 与局外加成 id
var _belt: Array = []
var _buffs: Array[StringName] = []


func setup(p_flow: GameFlow) -> ExpeditionBoard:
	flow = p_flow
	add_theme_constant_override("separation", 30)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	last_plate = _plate(LAST_H, "meta.last_expedition")
	_fill_last(last_plate.get_child(0).get_child(0))
	supply_plate = _plate(SUPPLY_H, "meta.supplies")
	supply_plate.tooltip_text = UiText.t("meta.supplies_tip")
	supply_plate.mouse_filter = Control.MOUSE_FILTER_PASS
	_fill_supplies(supply_plate.get_child(0).get_child(0))
	start_btn = UiTheme.make_home_button(UiText.t("meta.new_run"), flow.new_run, true, START, START_FONT)
	start_btn.name = "StartButton"
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_child(start_btn)
	return self


func _plate(h: float, title_key: String) -> PanelContainer:
	var p := UiTheme.panel(PanelContainer.new(), 14, UiTheme.PANEL_PARCHMENT)
	p.custom_minimum_size = Vector2(WIDTH, h)
	add_child(p)
	var pad := MarginContainer.new()     # 纸边不齐：字离边 24
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, PAD)
	p.add_child(pad)
	var col := UiTheme.vbox(10)
	pad.add_child(col)
	col.add_child(HeaderTag.new(UiText.t(title_key)))
	return p


## 上回出征：开局屏出发时记下的角色（[member MetaState.last_character]）与图 / 规模 / 难度旗标（开局屏照这些预选）
func _fill_last(col: VBoxContainer) -> void:
	var m := flow.meta
	var ch := flow.character_of(m.last_character) if m.last_character != &"" else null
	var chapter := _last_chapter()
	if ch == null and chapter == null:
		col.add_child(_line(UiText.t("meta.none_yet")))
		return
	if ch != null:
		var row := UiTheme.hbox(14)
		col.add_child(row)
		row.add_child(PortraitSlot.new(PORTRAIT, Nameplate.character_face(ch.id)))
		var name := UiTheme.make_label(Names.of(ch), NAME_FONT, UiTheme.INK)
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name)
		_last_lines.append(name.text)
	if chapter != null:
		var map := Names.of(chapter) if chapter.display_name != "" else String(chapter.id)
		var scale := _last_scale(chapter)
		var where := map + (UiText.t("setup.sep") + scale if scale != "" else "")
		col.add_child(_line(where))
		_last_lines.append(where)
	var diff := _last_difficulty()
	if diff != null:
		var text := Names.of(diff)     # 难度名自己带级（「进阶一」）
		col.add_child(_line(text))
		_last_lines.append(text)


func _last_chapter() -> ChapterDef:
	var at := flow.meta.flag(&"last_map") - 1
	if at < 0:
		return null
	for c in flow.chapters:
		if c.order == at:
			return c
	return null


func _last_scale(c: ChapterDef) -> String:
	var at := flow.meta.flag(&"last_scale") - 1
	var opts: Array[Dictionary] = c.map_source.scale_options() if c.map_source != null else [] as Array[Dictionary]
	return String(opts[at]["display_name"]) if at >= 0 and at < opts.size() else ""


func _last_difficulty() -> DifficultyDef:
	var level := flow.meta.flag(&"last_difficulty")
	for d in flow.difficulties:
		if d.level == level:
			return d
	return null


## 军需：一行随身技能圆槽（科技每局发的，[member MetaState.belt_grants]），一行局外加成小牌（[method GameFlow.meta_buffs]）
func _fill_supplies(col: VBoxContainer) -> void:
	var grants: Dictionary = flow.meta.belt_grants
	var ids := grants.keys()
	ids.sort()
	for id in ids:
		if int(grants[id]) > 0:
			_belt.append([StringName(String(id)), int(grants[id])])
	_buffs = flow.meta_buffs()
	if _belt.is_empty() and _buffs.is_empty():
		col.add_child(_line(UiText.t("meta.none_yet")))
		return
	if not _belt.is_empty():
		var row := UiTheme.hbox(12)
		col.add_child(row)
		for pair in _belt:
			row.add_child(BeltSlot.new(BeltSkillDef.find(pair[0]), int(pair[1])))
	if not _buffs.is_empty():
		var flow_row := HFlowContainer.new()
		flow_row.add_theme_constant_override("h_separation", 8)
		flow_row.add_theme_constant_override("v_separation", 8)
		col.add_child(flow_row)
		for id in _buffs:
			var def: RunBuffDef = flow.buff_defs.get(id, null)
			var tag := HeaderTag.new(Names.of(def) if def != null else String(id))
			tag.tooltip_text = Names.description_of(def) if def != null else ""
			tag.mouse_filter = Control.MOUSE_FILTER_PASS
			flow_row.add_child(tag)


func _line(text: String) -> Label:
	return UiTheme.make_label(text, LINE_FONT, UiTheme.INK)


func last_lines() -> Array[String]:
	return _last_lines


func belt_supplies() -> Array:
	return _belt


func buff_supplies() -> Array[StringName]:
	return _buffs


## 随身技能圆槽：一圈深色槽、技能图标、右下角数量（字画在槽上，不是散字）；悬停写技能名
class BeltSlot extends Control:
	var def: BeltSkillDef = null
	var count := 0
	var _icon: Texture2D = null

	func _init(p_def: BeltSkillDef, p_count: int) -> void:
		def = p_def
		count = p_count
		_icon = def.icon() if def != null else null     # 留住引用（184）
		custom_minimum_size = Vector2.ONE * SLOT
		tooltip_text = Names.of(def) if def != null else ""
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, INK_SLOT)
		draw_circle(c, r - 3.0, Color("e9dcc0"))
		if _icon != null:
			var s := (r - 6.0) * 2.0
			draw_texture_rect(_icon, Rect2(c - Vector2.ONE * s * 0.5, Vector2.ONE * s), false)
		var font := UiPalette.cjk_font_bold()
		var px := UiTheme.sz(BADGE_FONT)
		var text := "×%d" % count     # 右下角一枚小签：深底浅字
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var tag := Rect2(size.x - w - 8.0, size.y - px - 4.0, w + 8.0, px + 4.0)
		draw_rect(tag, INK_SLOT)
		draw_string(font, Vector2(tag.position.x + 4.0, tag.end.y - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("f1ece2"))
