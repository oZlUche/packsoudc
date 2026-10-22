## 150 补 1（作者定）：147 的腰带做成地图屏上的一件组件，随布局摆。
## 160（作者定）：腰带离开背包，只留这一处，默认在右下角；画成一排圆槽（[BeltSlots]）—— 一格一种随身技能、右下角写几个。
## 双击一个圆 = 用一个（走 [method GameFlow.use_belt]；用不了的原因在圆上方飘一行）。没有拖进拖出（随身技能不是道具）。
## 这一局没装腰带模块 = 空着（布局里写了也不报错，平时藏着）
extends HudWidget

var slots: BeltSlots = null


func title() -> String:
	return "腰带"


func setup(p_run: RunState, p_screen: Control) -> void:
	var belt := BeltModule.of(p_run)
	if slots == null and belt != null:
		_text.visible = false
		slots = BeltSlots.new()
		slots.font = p_screen.get("font") if p_screen != null else null
		slots.on_use = use
		add_child(slots)
		slots.bind(belt)
		belt.changed.connect(_sync_skin)
		_sync_skin()
	super.setup(p_run, p_screen)


## 232：弯皮带自己就是底 —— 不要 HUD 凹槽（栏里栏外都空底）；退回直圆槽时还给凹槽
func _sync_skin() -> void:
	var bent := slots != null and slots.curved()
	if bent and theme_type_variation != UiTheme.PANEL_BARE:
		theme_type_variation = UiTheme.PANEL_BARE
		UiTheme.apply_tone(self, UiTheme.PANEL_BARE)
	elif not bent and theme_type_variation == UiTheme.PANEL_BARE:
		theme_type_variation = UiTheme.PANEL_HUD
		UiTheme.apply_tone(self, UiTheme.PANEL_HUD)


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
	var name := Names.of(def) if def != null else String(skill_id)
	var flow: Variant = screen.get("flow") if screen != null else null
	var why: String = flow.use_belt(skill_id) if flow != null else run.hooks.belt_use(skill_id)
	if why == "" and screen != null and screen.has_method("say"):
		screen.call("say", UiText.t("hud.belt_used") % name)
	return why
