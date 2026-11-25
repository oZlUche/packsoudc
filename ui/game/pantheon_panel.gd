## 报告 377（作者 2026-11-22 22:53 改）：万神院的神龛一排，两种用法 ——
## - [constant PICK]：出征第一屏信仰横条展开后的内容（383：不再是【开始探索】时跳出的弹窗；万神院到了营地才有这一条）。第一项是【无信者】（不奉神，只是一个选项），
##   再按档位列六位神；没解锁的神写「？？？？」、不露神像，点不了。点一位就是这一局奉祂（[signal picked]）。
## - [constant VIEW]：营地后勤里的万神院页（396，作者 11-25 19:25）：六座神殿，没解锁的是黑色剪影、名字「？？？？」，悬浮窗写一句神的样子；
##   手里有解锁机会时点一座选中，底下深石板右边【确认解锁】（[method confirm]）。牌表没写好的神选中了也解锁不了，左边写「神殿尚未落成」。
## 排版按作者定稿（11-25 23:08 / 23:18）的 UI设计 s396 规格：顶上浅石牌、六座一排、底下深石板「还可以拜访 N 次神殿」。
extends VBoxContainer

signal picked(faith_id: StringName)
## 396：营地页解锁了一座神殿（营地刷新红点）
signal unlocked()

const CP := preload("res://ui/game/commission_panel.gd")
const INK := Color("2e2219")
const SHRINE_W := 150.0
const SHRINE_H := 200.0
## 396 定稿：营地那一页的神殿（美术正式图 190 × 250，资源是 2 倍图）
const TEMPLE_W := 190.0
const TEMPLE_H := 250.0
const NAME_H := 34.0
## 神徽：32，嵌在山墙的圆槽里（图上坐标；确切数等美术给，空键是默认）
const MEDAL := 32.0
const MEDAL_AT := {&"": Vector2(95.0, 77.0)}
## 选中的光：3 像素描边 + 12 像素 #FFD776 发光
const HALO := Color("ffd776")
const NAME_INK := Color("3c3426")
const NAME_LOCKED := Color("8f866f")
const NAME_PICKED := Color("9b7630")
const BAR_INK := Color("e8dcc0")
const NOT_BUILT := Color("e8a08a")
const ICON := 72.0
const DIM := Color(1, 1, 1, 0.45)
const PICK := &"pick"
const VIEW := &"view"

var flow: GameFlow = null
var mode := VIEW
var _body: VBoxContainer = null
## 396：营地页上点中的那座（还没确认）
var selected: StringName = &""


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
		if not Pantheon.gods().has(selected) or flow.meta.temples.has(selected):
			selected = &""
	var row := UiTheme.hbox(14)
	row.name = "Shrines"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(row)
	if mode == PICK:
		row.add_child(_shrine(&""))
	for fid in Pantheon.gods(flow.faith_defs):
		row.add_child(_shrine(fid) if mode == PICK else _temple(fid))
	if mode == VIEW:
		_body.add_child(_unlock_bar())


## 顶上的牌：徽、名字、声望刻度（只在营地那一页）
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
	return p     # 396 样张：声望刻度只在委托簿的声望页


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
		p.tooltip_text = UiText.t("pantheon.locked") if Pantheon.temple_ready(fid) else UiText.t("pantheon.not_built")
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
		var b := UiTheme.make_stone_button(UiText.t("pantheon.choose") if open else UiText.t("pantheon.unknown"),
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


## 396 定稿（作者 11-25 23:08，UI设计 s396 规格）：营地页的一座神殿。解锁了 = 亮的石殿、山墙嵌神徽、写名字；
## 没解锁 = 黑色剪影、「？？？？」，悬浮窗「？？？？」加作者写的一句（没落成的多一行「神殿尚未落成」）；
## 选中 = 剪影外一圈黄铜光、名字换黄铜色。六座靠顶上的饰物区分（美术正式图 `pantheon/temple_<神>` 与剪影 `_sil`）。点一下选中（[method select]）
func _temple(fid: StringName) -> Control:
	var open := Pantheon.god_open(flow.meta, fid)
	var def := flow.faith_defs.get(fid, null) as FaithDef
	var b := Button.new()
	b.name = "Temple_" + String(fid)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(TEMPLE_W, TEMPLE_H + NAME_H)
	b.tooltip_text = temple_tip(fid)
	b.pressed.connect(select.bind(fid))
	var col := UiTheme.vbox(4)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var pic := TextureRect.new()
	pic.name = "Image"
	var look := "" if open else "_sil"     # 剪影是美术另画的一套，不把亮图压黑
	pic.set_meta(&"look", look)
	pic.texture = UiTheme.art_cached("pantheon/temple_%s%s" % [fid, look])
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(TEMPLE_W, TEMPLE_H)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fid == selected and not open:     # 选中：剪影外描一圈黄铜光
		var halo := Halo.new()
		halo.name = "Halo"
		halo.texture = pic.texture
		halo.set_anchors_preset(Control.PRESET_FULL_RECT)
		halo.show_behind_parent = true
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(halo)
	col.add_child(pic)
	if open:     # 山墙上嵌这位神的信仰徽记
		var medal := TextureRect.new()
		medal.name = "Medal"
		medal.texture = UiTheme.art_cached("faith/%s" % fid)
		medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		medal.size = Vector2(MEDAL, MEDAL)
		medal.position = (MEDAL_AT.get(fid, MEDAL_AT[&""]) as Vector2) - Vector2(MEDAL, MEDAL) * 0.5
		medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(medal)
	var ink := NAME_INK if open else (NAME_PICKED if fid == selected else NAME_LOCKED)
	var nm := UiTheme.make_label(Names.of(def) if open and def != null else UiText.t("pantheon.unknown"), 22, ink)
	nm.name = "Name"
	nm.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nm)
	return b


## 一座神殿的悬浮窗：解锁了只写那一句；没解锁第一行「？？？？」、第二行那一句，没落成再加「神殿尚未落成」
func temple_tip(fid: StringName) -> String:
	if Pantheon.god_open(flow.meta, fid):
		return Pantheon.blurb(fid)
	var lines := PackedStringArray([UiText.t("pantheon.unknown")])
	if Pantheon.blurb(fid) != "":
		lines.append(Pantheon.blurb(fid))
	if not Pantheon.temple_ready(fid):
		lines.append(UiText.t("pantheon.not_built"))
	return "\n".join(lines)


## 396 定稿：底下的深石板 —— 左边「还可以拜访 N 次神殿」（作者 11-25 23:18；N 金色大字，是手里的解锁机会数），
## 右边【确认解锁】；选中没落成的神殿时键灰着、键左边写「神殿尚未落成」
func _unlock_bar() -> Control:
	var p := PanelContainer.new()
	p.name = "UnlockBar"
	UiTheme.stone(p, UiTheme.ART_STONE_SLATE)
	p.custom_minimum_size = Vector2(940, 96)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := UiTheme.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(row)
	var parts := UiText.t("pantheon.visits").split("%d")
	var n := Pantheon.chances(flow.meta)
	for i in parts.size():
		if parts[i].strip_edges() != "":
			row.add_child(UiTheme.fixed_color(UiTheme.make_label(parts[i].strip_edges(), 20, UiTheme.STONE_GOLD), BAR_INK))
		if i == 0:
			var num := UiTheme.fixed_color(UiTheme.make_display(str(n), 40), UiTheme.STONE_GOLD)
			num.name = "Chances"
			row.add_child(num)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	if selected != &"" and not Pantheon.temple_ready(selected):
		var nb := UiTheme.fixed_color(UiTheme.make_label(UiText.t("pantheon.not_built"), 20, NOT_BUILT), NOT_BUILT)
		nb.name = "NotBuilt"
		row.add_child(nb)
	var b := UiTheme.make_stone_button(UiText.t("pantheon.unlock"), confirm, true, Vector2(200, 64), 22)
	b.name = "Unlock"
	b.disabled = selected == &"" or not Pantheon.can_unlock(flow.meta, selected)
	b.tooltip_text = "" if not b.disabled or selected != &"" else (UiText.t("pantheon.pick_temple") if n > 0 else UiText.t("pantheon.no_chance"))
	row.add_child(b)
	return p


## 396：点一座神殿（解锁了的点了不选中）
func select(fid: StringName) -> void:
	if mode != VIEW:
		return
	selected = &"" if flow.meta.temples.has(fid) or selected == fid else fid
	refresh()


## 396【确认解锁】。返回解锁成了没有
func confirm() -> bool:
	if mode != VIEW or selected == &"" or not Pantheon.unlock(flow.meta, selected):
		return false
	selected = &""
	flow.save()
	refresh()
	unlocked.emit()
	return true


## 选神界面：这一局奉 [param fid]（空 = 无信者）。返回选没选上
func choose(fid: StringName) -> bool:
	if mode != PICK or not flow.choose_god(fid):
		return false
	refresh()
	picked.emit(fid)
	return true


## 选中的剪影外那圈光：同一张剪影图压成黄铜色，四周错开画几圈（近处实、远处淡）
class Halo extends Control:
	const SHADER := "shader_type canvas_item;\nvarying float v_a;\nuniform vec4 tint : source_color;\nvoid vertex() { v_a = COLOR.a; }\nvoid fragment() { COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * v_a); }"
	var texture: Texture2D = null

	func _ready() -> void:
		var sh := Shader.new()
		sh.code = SHADER
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter(&"tint", HALO)
		material = m

	func _draw() -> void:
		if texture == null:
			return
		for ring in [[3.0, 1.0], [6.0, 0.45], [9.0, 0.25], [12.0, 0.12]]:
			var r: float = ring[0]
			var c := Color(HALO, float(ring[1]))
			for k in 16:
				var a := TAU * float(k) / 16.0
				draw_texture_rect(texture, Rect2(Vector2(cos(a), sin(a)) * r, size), false, c)
