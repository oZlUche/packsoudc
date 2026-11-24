## 报告 377（作者 2026-11-22 22:53 改）：万神院的神龛一排，两种用法 ——
## - [constant PICK]：出征第一屏信仰横条展开后的内容（383：不再是【开始探索】时跳出的弹窗；万神院到了营地才有这一条）。第一项是【无信者】（不奉神，只是一个选项），
##   再按档位列六位神；没解锁的神写「？？？？」、不露神像，点不了。点一位就是这一局奉祂（[signal picked]）。
## - [constant VIEW]：营地后勤里的万神院页，只看：已解锁的神、没解锁的「？？？？」与第几档开（初值，不是作者裁定）。
## 占位排版，等 UI设计 的样张 B（大理石）。
extends VBoxContainer

signal picked(faith_id: StringName)

const CP := preload("res://ui/game/commission_panel.gd")
const INK := Color("2e2219")
const SHRINE_W := 150.0
const SHRINE_H := 200.0
const ICON := 72.0
const DIM := Color(1, 1, 1, 0.45)
const PICK := &"pick"
const VIEW := &"view"

var flow: GameFlow = null
var mode := VIEW
var _body: VBoxContainer = null


func setup(p_flow: GameFlow, p_mode: StringName = VIEW) -> void:
	flow = p_flow
	mode = p_mode
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
	if mode == VIEW:
		_body.add_child(_head())
	var row := UiTheme.hbox(14)
	row.name = "Shrines"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(row)
	if mode == PICK:
		row.add_child(_shrine(&""))
	for fid in Pantheon.gods(flow.faith_defs):
		row.add_child(_shrine(fid))


## 顶上的牌：徽、名字、信赖档（只在营地那一页）
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
	var lv := maxi(0, Pantheon.tier(flow.meta))
	var pips := CP.pips(lv)
	pips.tooltip_text = UiText.t("commission.tier_%d" % lv)
	row.add_child(pips)
	return p


## 一座神龛（[param fid] 空 = 无信者，只在选神界面）
func _shrine(fid: StringName) -> Control:
	var open := fid == &"" or Pantheon.god_open(flow.meta, fid)
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
	pic.name = "Image"
	if open:
		pic.texture = UiTheme.art_cached("faith/%s" % fid) if fid != &"" else null
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(ICON, ICON)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(pic)
	var text := UiText.t("pantheon.unknown")
	if fid == &"":
		text = UiText.t("pantheon.humanist")
	elif open:
		text = Names.of(def) if def != null else String(fid)
	var nm := UiTheme.make_label(text, 18, INK)
	nm.name = "Name"
	nm.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(nm)
	if mode == PICK:
		var b := UiTheme.make_stone_button(UiText.t("pantheon.choose") if open else UiText.t("pantheon.tier_short") % (Pantheon.god_tier(fid) + 1),
			func(): choose(fid), true, Vector2(110, 34), 16)
		b.name = "Choose_" + (String(fid) if fid != &"" else "none")
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var chosen := open and fid == Pantheon.choice(flow.meta)     # 383：这一局奉着的那位（默认沿用上回）
		if chosen:
			b.text = UiText.t("pantheon.chosen")
			p.theme_type_variation = UiTheme.PANEL_HOME_PLAQUE_SMALL
		b.disabled = not open or chosen
		col.add_child(b)
	return p


## 选神界面：这一局奉 [param fid]（空 = 无信者）。返回选没选上
func choose(fid: StringName) -> bool:
	if mode != PICK or not flow.choose_god(fid):
		return false
	refresh()
	picked.emit(fid)
	return true
