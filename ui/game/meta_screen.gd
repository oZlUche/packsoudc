## 局外 / 基地（M6，架构文档 8.2；058 第 4 / 7 条）：两个页签（088 作者定）—— **仓库**（格子、带回来还没清空的背包、局外 buff 与解锁、战绩、
## 最近几局）与**图鉴**（带出过的道具点亮、记累计件数，停上去看属性；特殊道具另列）。
## 带回来的背包没清空之前「再来一局」是灰的（作者：提示玩家清空背包再配置）。
extends GameScreen

const WarehousePanelScript := preload("res://ui/game/warehouse_panel.gd")
## 图鉴棋盘一行几格
const CODEX_COLS := 12

var _wh = null
var _new_run_btn: Button
var _hint: Label
var _buff_btns: Dictionary = {}
var _unlock_btns: Dictionary = {}
## 页签名 → 那一页的控件；`_tab_btns` 页签名 → 按钮
var _pages: Dictionary = {}
var _tab_btns: Dictionary = {}
var _tab: String = ""
## 图鉴页：点亮的道具摆在这块只读棋盘上（停上去就有悬浮窗），没点亮的列在下面
var _codex_board: GridInventory = null
var _codex_view: InventoryView = null


func open(payload: Dictionary) -> void:
	var m := flow.meta
	_backdrop()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var root := _vbox(10)
	margin.add_child(root)

	# 头：标题、页签、这一局、战绩、按钮
	var head := _hbox(16)
	root.add_child(head)
	head.add_child(_label("基地", 26, UiPalette.FG))
	for pair in [["warehouse", "仓库"], ["codex", "图鉴"]]:
		var key: String = pair[0]
		var b := _button(pair[1], func(): show_tab(key), 16)
		b.toggle_mode = true
		_tab_btns[key] = b
		head.add_child(b)
	var just: RunResult = payload.get("result", null)
	if just != null:
		root.add_child(_wrapped("刚才这一局：%s" % ("撤离，背出来 %d 件、值 %d 币、带出 %d 币" % [just.carried.size(), just.value, just.balance]
			if just.is_extracted() else "战败，什么都没带出来"), 13, UiPalette.HEAL if just.is_extracted() else UiPalette.HP, 700))
	root.add_child(_label("%d 局　撤离 %d　战败 %d　累计价值 %d　单局最高 %d　钱 %d　图鉴 %d / %d" % [
		m.runs, m.extractions, m.deaths, m.score, m.best_value, m.funds, m.codex.size(), flow.items.ids().size()], 14, UiPalette.FG))
	var buttons := _hbox(8)
	_new_run_btn = _button("再来一局", flow.new_run, 16)
	buttons.add_child(_new_run_btn)
	buttons.add_child(_button("回主菜单", flow.to_main_menu, 16))
	_hint = _label("", 12, UiPalette.STAMINA)
	buttons.add_child(_hint)
	root.add_child(buttons)

	# 仓库页
	var row := _hbox(28)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	_pages["warehouse"] = row
	var left := _vbox(8)
	row.add_child(left)
	left.add_child(_label("仓库　拖进格子里就留下；带回来的背包先清空", 15, UiPalette.DIM))
	_wh = WarehousePanelScript.new()
	_wh.setup(flow, font)
	_wh.changed.connect(_refresh)
	left.add_child(_wh)

	var right := _vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(_label("局外 buff　占位：开关列表，将来由任务、局外科技决定", 15, UiPalette.DIM))
	var ids_b: Array = flow.buff_defs.keys()
	ids_b.sort()
	var any_meta := false
	for id in ids_b:
		var def: RunBuffDef = flow.buff_defs[id]
		if not def.is_meta():
			continue
		any_meta = true
		var bid: StringName = id
		var b := _button("%s　%s" % [def.display_name, def.summary()], func(): toggle_buff(bid), 13)
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.set_pressed_no_signal(m.active_buffs.has(bid))
		_buff_btns[bid] = b
		right.add_child(b)
	if not any_meta:
		right.add_child(_label("（没有局外 buff 的内容）", 12, UiPalette.DIM))
	# 局外解锁（069，占位开关）：难度定义里要求的解锁 id 各一个开关；085：章节通关给的解锁也列（关掉 = 教程重新顶上）
	var unlock_ids: Array[StringName] = []
	for d in flow.difficulties:
		if d.requires_unlock != &"" and not unlock_ids.has(d.requires_unlock):
			unlock_ids.append(d.requires_unlock)
	for c in flow.chapters:
		if c.grants_unlock != &"" and not unlock_ids.has(c.grants_unlock):
			unlock_ids.append(c.grants_unlock)
	if not unlock_ids.is_empty():
		right.add_child(_label("局外解锁　占位：开关列表，将来由成长系统决定", 15, UiPalette.DIM))
		for uid in unlock_ids:
			var names: Array[String] = []
			for d in flow.difficulties:
				if d.requires_unlock == uid:
					names.append("难度：" + d.display_name)
			for c in flow.chapters:
				if c.grants_unlock == uid:
					names.append("通关：" + c.display_name)
				elif c.requires_unlock == uid:
					names.append("开放：" + c.display_name)
			var key: StringName = uid
			var ub := _button("%s　%s" % [uid, "、".join(names)], func(): toggle_unlock(key), 13)
			ub.toggle_mode = true
			ub.alignment = HORIZONTAL_ALIGNMENT_LEFT
			ub.set_pressed_no_signal(m.has_unlock(key))
			_unlock_btns[key] = ub
			right.add_child(ub)
	right.add_child(_label("最近几局", 15, UiPalette.DIM))
	var log := _log_box(13)
	for h in m.history:
		var extracted := String(h.get("outcome", "")) == "extracted"
		log.append_text("[color=#%s]%s[/color]　种子 %d　行动点 %d　打赢 %d　%s\n" % [
			(UiPalette.HEAL if extracted else UiPalette.HP).to_html(false), "撤离" if extracted else "战败",
			int(h.get("seed", 0)), int(h.get("steps", 0)), int(h.get("battles_won", 0)),
			"%d 件、值 %d 币、带出 %d 币" % [(h.get("items", []) as Array).size(), int(h.get("value", 0)), int(h.get("balance", 0))] if extracted else ""])
	if m.history.is_empty():
		log.append_text("[color=#8b93a1]还没有打过[/color]")
	right.add_child(log)

	# 图鉴页
	_pages["codex"] = _build_codex(root)
	show_tab(String(payload.get("tab", "warehouse")))
	_refresh()


## 088：图鉴页 —— 点亮的道具摆在一块只读棋盘上（按稀有度、再按 id），停上去就有悬浮窗；没点亮的按稀有度列成灰字；特殊道具另列
func _build_codex(root: Control) -> Control:
	var m := flow.meta
	var page := _vbox(8)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	var ids: Array = flow.items.ids()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var da := flow.items.get_def(a)
		var db := flow.items.get_def(b)
		return da.rarity < db.rarity if da.rarity != db.rarity else String(a) < String(b))
	var lit: Array = []
	var dark: Array = []
	for id in ids:
		if m.codex_lit(id):
			lit.append(id)
		else:
			dark.append(id)
	page.add_child(_label("图鉴　带出过的点亮（%d / %d），记累计件数；停在道具上看属性" % [lit.size(), ids.size()], 15, UiPalette.DIM))
	# 点亮的摆进棋盘：宽 CODEX_COLS，行数按需要长
	var rows := 1
	_codex_board = null
	while _codex_board == null and rows <= 40:
		var board := GridInventory.new(Vector2i(CODEX_COLS, rows), 0, false)
		var ok := true
		for id in lit:
			if not board.try_add(ItemInstance.create(flow.items.get_def(id), 0), true):
				ok = false
				break
		if ok:
			_codex_board = board
		else:
			rows += 1
	if _codex_board == null:
		_codex_board = GridInventory.new(Vector2i(CODEX_COLS, 1), 0, false)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 240
	page.add_child(scroll)
	var inner := _vbox(8)
	scroll.add_child(inner)
	_codex_view = InventoryView.new()
	_codex_view.label_font = font
	_codex_view.show_adjacency = false
	_codex_view.inventory = _codex_board
	_codex_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_codex_view.badges = _codex_badges()
	inner.add_child(_codex_view)
	if lit.is_empty():
		inner.add_child(_label("还没有带出过任何东西：撤离成功时背包里的都会点亮", 13, UiPalette.DIM))
	var dark_box := _log_box(13)
	dark_box.fit_content = true
	dark_box.scroll_active = false
	dark_box.append_text("[color=#8b93a1]没点亮的（%d）：[/color]" % dark.size())
	for id in dark:
		dark_box.append_text("[color=#4a515e]%s[/color]　" % Names.of(flow.items.get_def(id)))
	inner.add_child(dark_box)
	# 特殊道具（088）：不进背包、不能生成，拿到过的点亮
	var keeps: Array = flow.items.keepsake_ids()
	if not keeps.is_empty():
		keeps.sort()
		var kbox := _log_box(13)
		kbox.fit_content = true
		kbox.scroll_active = false
		kbox.append_text("[color=#8b93a1]特殊道具（不占背包，代表一种能力）：[/color]\n")
		for id in keeps:
			var def := flow.items.get_def(id)
			if m.has_keepsake(id):
				kbox.append_text("[color=#%s]%s[/color]　✓　%s\n" % [ItemPainter.rarity_color(def).to_html(false), Names.of(def), def.description])
			else:
				kbox.append_text("[color=#4a515e]%s[/color]\n" % Names.of(def))
		inner.add_child(kbox)
	return page


## 图鉴棋盘上每件角标写累计件数
func _codex_badges() -> Dictionary:
	var marks := {}
	if _codex_board == null:
		return marks
	for inst in _codex_board.items():
		var item := inst as ItemInstance
		var n := flow.meta.codex_count(item.def.id)
		if n > 1:
			marks[item.uid] = "×%d" % n
	return marks


## 切页签："warehouse" / "codex"
func show_tab(name: String) -> void:
	if not _pages.has(name):
		name = "warehouse"
	_tab = name
	for key in _pages:
		(_pages[key] as Control).visible = key == name
		if _tab_btns.has(key):
			(_tab_btns[key] as Button).set_pressed_no_signal(key == name)


func tab() -> String:
	return _tab


func codex_board() -> GridInventory:
	return _codex_board


func store_all() -> Dictionary:
	return _wh.store_all()


func discard_board() -> void:
	_wh.discard_board()


func toggle_buff(id: StringName) -> bool:
	var on := flow.toggle_meta_buff(id)
	if _buff_btns.has(id):
		(_buff_btns[id] as Button).set_pressed_no_signal(on)
	return on


func toggle_unlock(id: StringName) -> bool:
	var on := flow.toggle_unlock(id)
	if _unlock_btns.has(id):
		(_unlock_btns[id] as Button).set_pressed_no_signal(on)
	return on


func _refresh() -> void:
	var why := flow.can_begin()
	_new_run_btn.disabled = why != ""
	_hint.text = why
