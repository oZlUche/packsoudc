## 对手名牌上的能力简报。聚焦或点按查看完整列表，关闭后焦点回到简报。
extends Button

var traits: Array[String] = []
var sheet: PopupPanel
var body: RichTextLabel
var _close: Button


func _init() -> void:
	flat = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_theme_font_size_override("font_size", UiTheme.sz(16))
	for ink in ["font_color", "font_hover_color", "font_focus_color"]:
		add_theme_color_override(ink, Color("ffdf9b"))
	pressed.connect(open)
	resized.connect(_fit_summary)


func display(lines: Array[String]) -> void:
	traits = lines
	visible = not lines.is_empty()
	if not visible:
		if sheet != null:
			sheet.hide()
		return
	_fit_summary()
	tooltip_text = "\n".join(lines)
	if sheet != null and sheet.visible:
		body.text = "\n".join(lines)


## 缩短首项时保留最后的余项数，长英文名也能知道还有几条可读。
func _fit_summary() -> void:
	if traits.is_empty():
		return
	var lead := traits[0].get_slice(UiText.t("strip.special_sep"), 0)
	var tail := UiText.t("pre.trait_more") % (traits.size() - 1) if traits.size() > 1 else ""
	tail += "  →"
	var role := UiText.t("screen.enemy") + " · "
	var font := get_theme_font("font")
	var px := get_theme_font_size("font_size")
	var room := size.x - get_theme_stylebox("normal").get_minimum_size().x - 4
	if room > 0 and font.get_string_size(role + lead + tail, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > room:
		role = ""
		var cut := lead.length()
		while cut > 0 and font.get_string_size(lead + tail, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > room:
			cut -= 1
			lead = lead.left(cut) + "…"
	text = role + lead + tail


func open() -> void:
	if traits.is_empty():
		return
	if sheet == null:
		sheet = PopupPanel.new()
		sheet.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		add_child(sheet)
		var card := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_SUMMARY_NOTE, 26, 29, 26, 18)
		UiTheme.apply_tone(card, UiTheme.PANEL_SUMMARY_NOTE)
		sheet.add_child(card)
		var column := UiTheme.vbox(10)
		card.add_child(column)
		column.add_child(UiTheme.make_label(UiText.t("strip.special"), 24, UiTheme.INK))
		body = UiTheme.rich_block(0, 18)
		body.bbcode_enabled = false
		body.fit_content = false
		body.scroll_active = true
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(body)
		_close = ScrollKey.short(UiText.t("meta.close"), sheet.hide)
		_close.size_flags_horizontal = Control.SIZE_SHRINK_END
		column.add_child(_close)
		sheet.popup_hide.connect(grab_focus)
	body.text = "\n".join(traits)
	var room := get_viewport_rect().size * 0.74
	sheet.popup_centered(Vector2i(room.min(Vector2(520, 300))))
	_close.grab_focus()
