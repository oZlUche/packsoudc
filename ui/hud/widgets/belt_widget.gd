## 地图上的随身技能腰带。铜扣标示占用格数，展开可检查空槽。
## 已装技能常显，由 BeltSlots 提供悬停说明与双击使用。
## 位置及显隐由 HudHost 的布局控制。
extends HudWidget

var slots: BeltSlots = null
var _clasp: Button
var _expanded := false


func title() -> String:
	return "腰带"


func setup(p_run: RunState, p_screen: Control) -> void:
	var belt := BeltModule.of(p_run)
	if slots == null and belt != null:
		_text.hide()
		theme_type_variation = UiTheme.PANEL_BARE
		UiTheme.apply_tone(self, UiTheme.PANEL_BARE)
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 3)
		add_child(column)
		slots = BeltSlots.new()
		slots.field_mode = true
		slots.font = p_screen.get("font") if p_screen != null else null
		slots.on_use = use
		slots.size_flags_horizontal = Control.SIZE_SHRINK_END
		column.add_child(slots)
		slots.bind(belt)
		_clasp = Button.new()
		_clasp.icon = preload("res://assets/ui/belt/field_clasp.svg")
		_clasp.size_flags_horizontal = Control.SIZE_SHRINK_END
		_clasp.custom_minimum_size = Vector2(0, 34)
		_clasp.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_clasp.toggle_mode = true
		if slots.font != null:
			_clasp.add_theme_font_override("font", slots.font)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("332e28") if state == "normal" else Color("504537")
			style.border_color = Color("998358") if state == "normal" else Color("cfb47c")
			style.set_border_width_all(1)
			style.set_corner_radius_all(3)
			style.content_margin_left = 9
			style.content_margin_right = 9
			style.content_margin_top = 2
			style.content_margin_bottom = 2
			_clasp.add_theme_stylebox_override(state, style)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			_clasp.add_theme_color_override(state, Color("f2e3c6"))
		column.add_child(_clasp)
		_clasp.toggled.connect(_toggle)
		minimum_size_changed.connect(reset_size, CONNECT_DEFERRED)
	super.setup(p_run, p_screen)


func _toggle(on: bool) -> void:
	_expanded = on
	slots.reveal_empty(on)
	_paint()


func _paint() -> void:
	if slots == null:
		return
	_clasp.add_theme_font_size_override("font_size", UiTheme.sz(15))
	var occupied := slots.module.stacks.size()
	slots.visible = _expanded or occupied > 0
	_clasp.text = "%s  %d/%d  %s" % [UiText.t("hud.belt"), occupied, slots.slot_count(), "▼" if _expanded else "▲"]
	_clasp.tooltip_text = UiText.t("hud.belt_fold" if _expanded else "hud.belt_unfold")


func set_editing(on: bool) -> void:
	if slots != null:
		slots.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
		_clasp.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
		_clasp.focus_mode = Control.FOCUS_NONE if on else Control.FOCUS_ALL
	super.set_editing(on)


func watch() -> Array[Signal]:
	var belt := BeltModule.of(run)
	return [belt.changed] as Array[Signal] if belt != null else [] as Array[Signal]


func _idle_mouse_filter() -> Control.MouseFilter:
	return Control.MOUSE_FILTER_PASS     # 圆槽自己接双击与悬停


func has_content() -> bool:
	return slots != null


func text_of() -> String:
	return UiText.t("hud.belt") if slots != null else ""


## 用一个随身技能。返回用不了的原因（空串 = 用了）
func use(skill_id: StringName) -> String:
	var def := BeltSkillDef.find(skill_id)
	var name_ := Names.of(def) if def != null else String(skill_id)
	var flow: Variant = screen.get("flow") if screen != null else null
	var why: String = flow.use_belt(skill_id) if flow != null else run.hooks.belt_use(skill_id)
	if why == "" and screen != null and screen.has_method("say"):
		screen.call("say", UiText.t("hud.belt_used") % name_)
	return why
