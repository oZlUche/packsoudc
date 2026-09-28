## 局外 / 基地（M6，架构文档 8.2；058 第 4 / 7 条）：两个页签（088 作者定）—— **仓库**（格子、带回来还没清空的背包、局外 buff 与解锁、战绩、
## 最近几局）与**图鉴**（带出过的道具点亮、记累计件数，停上去看属性；特殊道具另列）。
## 带回来的背包没清空之前「再来一局」是灰的（作者：提示玩家清空背包再配置）。
extends GameScreen

const WarehousePanelScript := preload("res://ui/game/warehouse_panel.gd")
## 图鉴一行几个缩略图
const CODEX_COLS := 8

var _wh = null
var _new_run_btn: Button
var _hint: Label
var _buff_btns: Dictionary = {}
var _unlock_btns: Dictionary = {}
## 页签名 → 那一页的控件；`_tab_btns` 页签名 → 按钮
var _pages: Dictionary = {}
var _tab_btns: Dictionary = {}
var _tab: String = ""
## 图鉴页的缩略图与它的悬浮窗
var _codex_tiles: Array[CodexTile] = []
var _codex_tip: HoverTip = null
## 091：成就页的筛选（"all" / "done" / "todo"）、列表与现在列着的行
var _ach_filter: String = "all"
var _ach_filter_btns: Dictionary = {}
var _ach_list: VBoxContainer = null
var _ach_hint: Label = null
var _ach_rows: Array = []


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
	for pair in [["warehouse", "仓库"], ["codex", "图鉴"], ["achievements", "成就"]]:
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
		m.runs, m.extractions, m.deaths, m.score, m.best_value, m.funds, m.codex.size(), flow.items.ids(true).size()], 14, UiPalette.FG))
	var buttons := _hbox(8)
	_new_run_btn = _button("再来一局", flow.new_run, 16, UiPalette.Tier.PRIMARY)
	buttons.add_child(_new_run_btn)
	buttons.add_child(_button("回主菜单", flow.to_main_menu, 16, UiPalette.Tier.MINOR))
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
		var b := _button("%s　%s" % [def.display_name, def.summary()], func(): toggle_buff(bid), 13, UiPalette.Tier.MINOR)
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
			var ub := _button("%s　%s" % [uid, "、".join(names)], func(): toggle_unlock(key), 13, UiPalette.Tier.MINOR)
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

	# 图鉴页、成就页（091）
	_pages["codex"] = _build_codex(root)
	_pages["achievements"] = _build_achievements(root)
	show_tab(String(payload.get("tab", "warehouse")))
	_refresh()


#region 成就页（091，作者定）
## 成就页：每枚一行 —— 名字、解锁途径、进度、完成给什么；「全部 / 已解锁 / 未解锁」切
func _build_achievements(root: Control) -> Control:
	var page := _vbox(8)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	var head := _hbox(8)
	page.add_child(head)
	head.add_child(_label("成就　完成了给解锁（道具 / 地图 / 难度）；途径写在每一条上", 15, UiPalette.DIM))
	for pair in [["all", "全部"], ["done", "已解锁"], ["todo", "未解锁"]]:
		var key: String = pair[0]
		var b := _button(pair[1], func(): show_achievement_filter(key), 13, UiPalette.Tier.MINOR)
		b.toggle_mode = true
		_ach_filter_btns[key] = b
		head.add_child(b)
	_ach_hint = _label("", 12, UiPalette.STAMINA)
	page.add_child(_ach_hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 300
	page.add_child(scroll)
	_ach_list = _vbox(8)
	_ach_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_ach_list)
	show_achievement_filter("all")
	return page


## 切「全部 / 已解锁 / 未解锁」（"all" / "done" / "todo"）并重列
func show_achievement_filter(key: String) -> void:
	if not _ach_filter_btns.has(key):
		key = "all"
	_ach_filter = key
	for k in _ach_filter_btns:
		(_ach_filter_btns[k] as Button).set_pressed_no_signal(k == key)
	_fill_achievements()


func achievement_filter() -> String:
	return _ach_filter


## 现在列着的：[{id, done}]（测试看）
func achievement_rows() -> Array:
	return _ach_rows.duplicate()


func _fill_achievements() -> void:
	if _ach_list == null:
		return
	for c in _ach_list.get_children():
		_ach_list.remove_child(c)
		c.queue_free()
	_ach_rows.clear()
	var m := flow.meta
	var total := flow.achievement_defs.size()
	var done_n := 0
	for def in flow.achievement_defs:
		if m.has_achievement(def.id):
			done_n += 1
	if _ach_hint != null:
		_ach_hint.text = ("全部解锁开着：成就不计　" if flow.settings != null and flow.settings.unlock_all else "") + "完成 %d / %d" % [done_n, total]
	if total == 0:
		_ach_list.add_child(_label("（没有成就的内容：data/authoring/achievements/）", 12, UiPalette.DIM))
		return
	for def in flow.achievement_defs:
		var done := m.has_achievement(def.id)
		if _ach_filter == "done" and not done or _ach_filter == "todo" and done:
			continue
		_ach_rows.append({"id": def.id, "done": done})
		_ach_list.add_child(_achievement_row(def, done))
	if _ach_rows.is_empty():
		_ach_list.add_child(_label("（这一栏空着）", 12, UiPalette.DIM))


func _achievement_row(def: AchievementDef, done: bool) -> Control:
	var m := flow.meta
	var panel := _panel(10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := _vbox(4)
	panel.add_child(col)
	var secret := def.hidden and not done
	var head := _hbox(12)
	col.add_child(head)
	head.add_child(_label(("？？？" if secret else Names.of(def)), 16, UiPalette.HEAL if done else UiPalette.FG))
	var status := ""
	if done:
		var t := m.achievement_time(def.id)
		status = "✓ 已完成" + ("　%s" % Time.get_date_string_from_unix_time(t) if t > 0 else "")
	elif secret:
		status = "未完成"
	else:
		status = "未完成　进度 %s" % def.progress_text(m)
	head.add_child(_label(status, 13, UiPalette.HEAL if done else UiPalette.DIM))
	col.add_child(_wrapped("途径：" + ("？？？" if secret else def.description), 13, UiPalette.FG, 700))
	var opens: Array[String] = []
	for g in def.grants:
		opens.append_array(flow.unlock_names(g))
		if flow.unlock_names(g).is_empty():
			opens.append("解锁 %s" % g)
	col.add_child(_wrapped("解锁：" + ("、".join(opens) if not opens.is_empty() else "无（只是一枚徽章）"), 12, UiPalette.DIM, 700))
	return panel
#endregion


## 088 / 089：图鉴页 —— 跟棋盘的格子无关：所有能获得的道具按稀有度排成**缩略图网格**（每行 CODEX_COLS 个，能上下滚），
## 带出过的亮着（右上角写累计件数），没获得的灰的；停在一格上开悬浮窗看属性。特殊道具另起一段
func _build_codex(root: Control) -> Control:
	var m := flow.meta
	var page := _vbox(8)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	var ids: Array = flow.items.ids(true)     # 091：锁着的也列（灰的，写着怎么解锁）
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var da := flow.items.get_def(a)
		var db := flow.items.get_def(b)
		return da.rarity < db.rarity if da.rarity != db.rarity else String(a) < String(b))
	var lit_n := 0
	for id in ids:
		if m.codex_lit(id):
			lit_n += 1
	page.add_child(_label("图鉴　带出过的点亮（%d / %d），右上角是累计件数；停在一格上看属性" % [lit_n, ids.size()], 15, UiPalette.DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 300
	page.add_child(scroll)
	var inner := _vbox(10)
	scroll.add_child(inner)
	var grid := GridContainer.new()
	grid.columns = CODEX_COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	inner.add_child(grid)
	_codex_tiles.clear()
	for id in ids:
		var def := flow.items.get_def(id)
		var tile := CodexTile.new(def, m.codex_lit(id), m.codex_count(id), font)
		tile.hovered.connect(_on_tile_hovered)
		tile.unhovered.connect(func(_t: CodexTile): _codex_tip.hide_tip())
		grid.add_child(tile)
		_codex_tiles.append(tile)
	# 特殊道具（088）：不进背包、不能生成，拿到过的点亮
	var keeps: Array = flow.items.keepsake_ids()
	if not keeps.is_empty():
		keeps.sort()
		inner.add_child(_label("特殊道具　不占背包，代表一种能力", 14, UiPalette.DIM))
		var kgrid := GridContainer.new()
		kgrid.columns = CODEX_COLS
		kgrid.add_theme_constant_override("h_separation", 8)
		inner.add_child(kgrid)
		for id in keeps:
			var def := flow.items.get_def(id)
			var tile := CodexTile.new(def, m.has_keepsake(id), 0, font)
			tile.hovered.connect(_on_tile_hovered)
			tile.unhovered.connect(func(_t: CodexTile): _codex_tip.hide_tip())
			kgrid.add_child(tile)
			_codex_tiles.append(tile)
	_codex_tip = HoverTip.new(font)
	add_child(_codex_tip)
	return page


## 停在一格上：点亮的开完整的道具说明；没获得的只写名字与「未获得」
func _on_tile_hovered(tile: CodexTile) -> void:
	if _codex_tip == null or tile.def == null:
		return
	var at := tile.global_position + Vector2(tile.size.x, 0)
	if tile.lit:
		var full := ItemTooltip.describe_full(ItemInstance.create(tile.def, 0))
		_codex_tip.show_text(String(full["text"]), at, null, full["terms"])
	elif tile.def.requires_unlock != &"" and not flow.unlocked(tile.def.requires_unlock):
		# 091：锁着的写怎么解锁（哪一枚成就）
		var ach := flow.achievement_granting(tile.def.requires_unlock)
		var how := "完成成就「%s」：%s" % [Names.of(ach), ach.description] if ach != null else "解锁 %s" % tile.def.requires_unlock
		_codex_tip.show_text("[b]%s[/b]\n[color=#8b93a1]未解锁：%s[/color]" % [Names.of(tile.def), how], at)
	else:
		_codex_tip.show_text("[b]%s[/b]\n[color=#8b93a1]未获得：撤离成功时背包里的会点亮[/color]" % Names.of(tile.def), at)


func codex_tiles() -> Array[CodexTile]:
	return _codex_tiles


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


## 090：Esc = 返回上一级 —— 在图鉴页先回仓库页，仓库页再回主菜单
func escape() -> bool:
	if _tab != "warehouse":
		show_tab("warehouse")
		return true
	flow.to_main_menu()
	return true



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
	# 090：带回来的没清不再拦，只提示（开局屏里进暂存区，出发就没了）
	_hint.text = why if why != "" else flow.pending_hint()
