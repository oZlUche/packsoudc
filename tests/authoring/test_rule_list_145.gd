## 145（作者定）：编辑器里规则表一行一条（四列列表），双击弹浮窗，触发 / 消耗 / 效果分页签。
## 没有弹窗层的表单（裸建的）还是内联卡片。
extends RefCounted


static func _rule(trigger: Trigger, cadence: Cadence, effects: Array) -> AbilityRule:
	var r := AbilityRule.new()
	r.trigger = trigger
	r.cadence = cadence
	for e in effects:
		r.effects.append(e)
	return r


static func _profile() -> CombatProfile:
	var p := CombatProfile.new()
	var cd := CooldownCadence.new()
	cd.seconds = 2.0
	p.rules.append(_rule(OnSchedule.new(), cd, [DealDamage.new()]))
	var chance := ChanceCondition.new()
	chance.percent = 25
	var r2 := _rule(OnBattleStart.new(), Always.new(), [DealDamage.new()])
	r2.costs.append(chance)
	p.rules.append(r2)
	p.rules.append(AbilityRule.new())     # 空规则：不合法
	return p


static func _button(form: Node, text: String) -> Button:
	for n in form.find_children("*", "Button", true, false):
		if (n as Button).text == text:
			return n
	return null


static func frame_run_rule_list(t: TestCase, root: Window) -> void:
	t.begin("145 · 规则表是列表，双击弹窗分页签")

	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(layer)
	var p := _profile()
	var form := PropertyForm.create(p, null)
	form.popup_layer = layer
	var changes := [0]
	form.changed.connect(func(): changes[0] += 1)
	root.add_child(form)

	# --- 列表：行数 = 规则数，三列文案与 Glossary 一致，不合法的带「！」---
	var tree := form.rule_list("rules")
	t.not_null(tree, "规则表渲染成列表")
	if tree == null:
		form.queue_free()
		layer.queue_free()
		return
	t.eq(tree.columns, 4, "四列：#、时机、消耗、效果")
	var rows := tree.get_root().get_children()
	t.eq(rows.size(), 3, "一条规则一行")
	t.eq(rows[0].get_text(0), "1", "第一行序号 1")
	t.eq(rows[0].get_text(1), Glossary.timing_text(p.rules[0]), "时机列")
	t.eq(rows[0].get_text(1), "每 2.0 秒", "自发 + 冷却只写每 N 秒")
	t.eq(rows[1].get_text(2), Glossary.costs_text(p.rules[1]), "消耗列")
	t.check(rows[1].get_text(2) != "", "有几率条件的那条消耗列不空")
	t.eq(rows[0].get_text(3), Glossary.effects_text(p.rules[0].effects), "效果列")
	t.eq(rows[0].get_tooltip_text(1), Glossary.rule_text(p.rules[0]), "悬浮是完整的一句")
	t.eq(rows[2].get_text(0), "！3", "不合法的规则序号前带「！」")
	t.check(form.find_children("*", "PropertyForm", true, false).is_empty(), "规则不再内联铺开（没有子表单）")

	# --- 没选中时复制 / 删除 / 编辑不能点 ---
	t.check(_button(form, "删除").disabled and _button(form, "编辑").disabled, "没选中时按钮禁用")
	rows[0].select(0)
	t.check(not _button(form, "编辑").disabled, "选中之后能点")

	# --- 双击打开浮窗：三个页签，名字带条数 ---
	tree.item_activated.emit()
	var win: RuleWindow = null
	for c in layer.get_children():
		if c is RuleWindow:
			win = c
	t.not_null(win, "双击弹出规则浮窗")
	if win == null:
		form.queue_free()
		layer.queue_free()
		return
	t.eq(win.rule, p.rules[0], "浮窗改的就是这条规则本身")
	t.eq(win.tab_title(0), "触发", "第一页：触发")
	t.eq(win.tab_title(1), "消耗（0）", "第二页：消耗带条数")
	t.eq(win.tab_title(2), "效果（1）", "第三页：效果带条数")
	t.eq(win.preview_text(), Glossary.rule_text(p.rules[0]), "顶上一行是这条规则的预览")
	t.eq(win.tab_form(0).row_visible("trigger"), true, "触发页有扳机")
	t.eq(win.tab_form(0).row_visible("cadence"), true, "触发页有节奏")
	t.check(not win.tab_form(0).row_visible("effects"), "触发页没有效果")
	t.check(win.tab_form(2).row_visible("effects") and not win.tab_form(2).row_visible("trigger"), "效果页只有效果")
	t.eq(layer.mouse_filter, Control.MOUSE_FILTER_STOP, "浮窗开着时弹窗层接住点外面")

	# --- 在浮窗里加一个效果：原规则多一项、上级表单发了 changed、列表那行跟着变 ---
	var before: int = changes[0]
	var eff_form := win.tab_form(2)
	var add := _button(eff_form, "+ 添加")
	t.not_null(add, "效果页有「添加」")
	if add != null:
		add.pressed.emit()
	t.eq(p.rules[0].effects.size(), 2, "规则对象的效果多了一项（即改即生效）")
	t.check(changes[0] > before, "上级表单发了 changed（编辑器据此刷新 JSON 与校验）")
	t.eq(win.tab_title(2), "效果（2）", "页签条数跟着变")
	t.eq(form.rule_list("rules").get_root().get_child(0).get_text(3), Glossary.effects_text(p.rules[0].effects), "列表那一行的效果列跟着变")

	# --- 再开另一条：复用同一块浮窗 ---
	rows = form.rule_list("rules").get_root().get_children()
	rows[1].select(0)
	_button(form, "编辑").pressed.emit()
	var wins := layer.get_children().filter(func(c): return c is RuleWindow and not c.is_queued_for_deletion())
	t.eq(wins.size(), 1, "同一时间只有一块浮窗")
	t.eq(win.rule, p.rules[1], "换成了第二条")
	t.check(win.implied_text() == "", "这条的扳机不隐含消耗")
	win.close()
	t.eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE, "关掉之后弹窗层不挡鼠标")

	# --- 新建 / 复制 / 删除 / 上下移改的是原数组 ---
	var first := p.rules[0]
	_button(form, "新建").pressed.emit()
	t.eq(p.rules.size(), 4, "新建追加一条")
	t.check(not p.rules[3].is_valid(), "新建的是空规则（不替作者猜扳机）")
	var opened: RuleWindow = null
	for c in layer.get_children():
		if c is RuleWindow and not c.is_queued_for_deletion():
			opened = c
	t.check(opened != null and opened.rule == p.rules[3], "新建之后直接弹窗打开它")
	if opened != null:
		opened.close()
	form.rule_list("rules").get_root().get_child(0).select(0)
	_button(form, "复制").pressed.emit()
	t.eq(p.rules.size(), 5, "复制插在后面")
	t.check(p.rules[1] != first and p.rules[1].effects.size() == first.effects.size(), "复制出来的是另一份")
	t.check(p.rules[1].effects[0] != first.effects[0], "连效果也是另一份（深拷贝）")
	t.eq(form.rule_list("rules").get_selected().get_index(), 1, "选中复制出来的那条")
	_button(form, "删除").pressed.emit()
	t.eq(p.rules.size(), 4, "删掉了")
	t.eq(p.rules[0], first, "删的是复制出来的那条")
	form.rule_list("rules").get_root().get_child(0).select(0)
	_button(form, "下移").pressed.emit()
	t.eq(p.rules[1], first, "下移一格")
	_button(form, "上移").pressed.emit()
	t.eq(p.rules[0], first, "上移回来")

	form.queue_free()

	# --- 没有弹窗层的表单还是内联卡片 ---
	var bare := PropertyForm.create(_profile(), null)
	root.add_child(bare)
	t.eq(bare.rule_list("rules"), null, "没有弹窗层：不出列表")
	t.check(not bare.find_children("*", "PropertyForm", true, false).is_empty(), "规则照旧内联成卡片")
	bare.queue_free()
	layer.queue_free()


## 编辑器里：道具表单的规则表是列表，换一件道具时开着的浮窗关掉
static func frame_run_editor_rule_list(t: TestCase, root: Window) -> void:
	t.begin("145 · 道具编辑器里的规则列表")
	var ed = load("res://ui/editor/content_editor.tscn").instantiate()
	root.add_child(ed)
	ed._open("shortsword")
	var forms: Array = ed._form_host.find_children("*", "PropertyForm", true, false)
	var tree: Tree = null
	for f in forms:
		if f.rule_list("rules") != null:
			tree = f.rule_list("rules")
	t.not_null(tree, "制式短剑的战斗档案里规则是列表")
	if tree != null:
		t.eq(tree.get_root().get_child_count(), ed._def.combat.rules.size(), "行数 = 规则数")
		tree.get_root().get_child(0).select(0)
		tree.item_activated.emit()
		t.eq(ed._popup_layer.get_children().filter(func(c): return c is RuleWindow).size(), 1, "双击弹窗")
		ed._open("cleaver")
		t.check(ed._popup_layer.get_children().all(func(c): return c.is_queued_for_deletion()), "换一件道具，浮窗关掉")
	ed.queue_free()
