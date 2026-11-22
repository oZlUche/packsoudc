## 报告 377：后勤「万神院」页 —— 出征前选这一局奉哪位神。占位排版（等 UI设计 的样张）：
## 顶上一块牌（阵营徽、名字、信赖菱点）；下面一排神龛（第一座是【以人为本】，再按档位列六位神）：
## 能选的亮、没到档位的压暗（悬停写第几档开），选中的描边；点一座就是「下一局奉祂」，再点一次回到以人为本。
extends VBoxContainer

signal changed()
## 有话要说（选不了的原因）：[param warn] = 是不是要紧的
signal said(text: String, warn: bool)

const CP := preload("res://ui/game/commission_panel.gd")
const INK := Color("2e2219")
const INK_DIM := Color("5a4a3a")
const SHRINE_W := 150.0
const SHRINE_H := 210.0
const ICON := 72.0
const DIM := Color(1, 1, 1, 0.35)

var flow: GameFlow = null
var _body: VBoxContainer = null


func setup(p_flow: GameFlow) -> void:
	flow = p_flow
	name = "PantheonPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := UiTheme.margins(MarginContainer.new(), 16, 12, 16, 12)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(pad)
	_body = UiTheme.vbox(18)
	_body.name = "Stage"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.set_tone(_body, UiTheme.TONE_DARK)
	pad.add_child(_body)
	refresh()


func refresh() -> void:
	if _body == null or flow == null or flow.meta == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_body.add_child(_head())
	var row := HFlowContainer.new()
	row.name = "Shrines"
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 14)
	row.add_theme_constant_override("v_separation", 14)
	_body.add_child(row)
	row.add_child(_shrine(&""))
	for fid in Pantheon.gods(flow.faith_defs):
		row.add_child(_shrine(fid))


## 顶上的牌：徽、名字、信赖档
func _head() -> Control:
	var p := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 14, 8, 14, 8)
	UiTheme.set_tone(p, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	p.name = "Head"
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := UiTheme.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(row)
	row.add_child(CP.emblem(Pantheon.FACTION, 48))
	var f := Pantheon.faction()
	var title := UiTheme.make_label(Names.of(f) if f != null else UiText.t("pantheon.title"), 22, INK)
	title.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	row.add_child(title)
	var pips := CP.pips(maxi(0, Pantheon.tier(flow.meta)))
	pips.tooltip_text = UiText.t("commission.tier_%d" % maxi(0, Pantheon.tier(flow.meta)))
	row.add_child(pips)
	return p


## 一座神龛（[param fid] 空 = 以人为本）
func _shrine(fid: StringName) -> Control:
	var open := fid == &"" or Pantheon.god_open(flow.meta, fid)
	var chosen := Pantheon.choice(flow.meta) == fid
	var def := flow.faith_defs.get(fid, null) as FaithDef
	var p := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 10, 10, 10, 8)
	UiTheme.set_tone(p, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	p.name = "Shrine_" + (String(fid) if fid != &"" else "none")
	p.custom_minimum_size = Vector2(SHRINE_W, SHRINE_H)
	if not open:
		p.modulate = DIM
		p.tooltip_text = UiText.t("pantheon.locked") % (Pantheon.god_tier(fid) + 1)
	elif def != null:
		p.tooltip_text = Names.description_of(def)
	var col := UiTheme.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(col)
	var pic := TextureRect.new()
	pic.texture = UiTheme.art_cached("faith/%s" % fid) if fid != &"" else UiTheme.art_cached("commission/emblem_%s" % Pantheon.FACTION)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(ICON, ICON)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(pic)
	var nm := UiTheme.make_label(Names.of(def) if def != null else UiText.t("pantheon.humanist"), 18, INK)
	nm.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(nm)
	var b := UiTheme.make_home_button(UiText.t("pantheon.chosen" if chosen else "pantheon.choose"), func(): choose(fid), true, Vector2(110, 34), 16)
	b.name = "Choose_" + (String(fid) if fid != &"" else "none")
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.disabled = not open or chosen
	UiTheme.mark(b, chosen)
	col.add_child(b)
	return p


## 选下一局奉谁（空 = 以人为本）。返回选没选上
func choose(fid: StringName) -> bool:
	var ok := flow.choose_god(fid)
	if not ok:
		said.emit(UiText.t("pantheon.why_locked"), true)
	refresh()
	changed.emit()
	return ok
