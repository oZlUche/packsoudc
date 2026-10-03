## 局外 / 基地（M6，架构文档 8.2；058 第 4 / 7 条）：两个页签（088 作者定）—— **仓库**（格子、带回来还没清空的背包、局外 buff 与解锁、战绩、
## 最近几局）与**图鉴**（带出过的道具点亮、记累计件数，停上去看属性；特殊道具另列）。
## 带回来的背包没清空之前「再来一局」是灰的（作者：提示玩家清空背包再配置）。
extends GameScreen

const WarehousePanelScript := preload("res://ui/game/warehouse_panel.gd")
const TechPanelScript := preload("res://ui/game/tech_panel.gd")
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
## 095：异体弹窗
var _variants_popup: Control = null
var _variant_tiles: Array[CodexTile] = []
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
	for pair in [["warehouse", "仓库"], ["codex", "图鉴"], ["achievements", "成就"], ["sell", "出售"], ["tech", "科技"]]:
		var key: String = pair[0]
		var b := _button(pair[1], func(): show_tab(key), 16)
		b.toggle_mode = true
		_tab_btns[key] = b
		head.add_child(b)
	var just: RunResult = payload.get("result", null)
	if just != null:
		root.add_child(_wrapped("刚才这一局：%s" % ("撤离，背出来 %d 件、值 %d 币、带出 %d 币" % [just.carried.size(), just.value, just.balance]
			if just.is_extracted() else ("战败，保险箱里的 %d 件带出来了" % just.safe_items.size() if not just.safe_items.is_empty() else "战败，什么都没带出来")), 13, UiPalette.HEAL if just.is_extracted() else UiPalette.HP, 700))
	# 092：离开结算屏时暂存区一键出售了 —— 提示一句
	var sold: Dictionary = payload.get("stash_sold", {})
	if int(sold.get("count", 0)) > 0:
		root.add_child(_wrapped("上一局暂存区里没背出来的 %d 件已一键出售，得 %d 币。" % [int(sold["count"]), int(sold["funds"])], 13, UiPalette.STAMINA, 700))
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
	_pages["sell"] = _build_sell(root)
	_pages["tech"] = _build_tech(root)     # 110：局外科技（仓库扩建）与上交
	show_tab(String(payload.get("tab", "warehouse")))
	_refresh()


#region 科技（110）
var _tech = null


func _build_tech(root: Control) -> Control:
	_tech = TechPanelScript.new()
	_tech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tech.setup(flow, font)
	_tech.changed.connect(_refresh)
	root.add_child(_tech)
	return _tech


## 科技页（测试看）
func tech_panel():
	return _tech
#endregion


#region 出售（091，作者定：基地内商店）
## 「白色 / 绿色及以下 / … / 全部」→ 稀有度上限（-1 = 全部）
const SELL_FILTERS := [["白色", 0], ["绿色及以下", 1], ["蓝色及以下", 2], ["紫色及以下", 3], ["金色及以下", 4], ["全部", -1]]
var _sell_filter: int = 0
var _sell_pick: OptionButton = null
var _sell_preview: Label = null
var _sell_line: Label = null
var _sell_view: InventoryView = null


## 基地商店：卖掉仓库里的东西 —— 双击一件卖一件，或按稀有度一键卖。得的钱进局外的钱（作者：暂无出售效果，先攒着）
func _build_sell(root: Control) -> Control:
	var page := _vbox(8)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	page.add_child(_label("出售　双击仓库里的一件卖掉；或选一档稀有度一键卖。回定价的 %d%%，钱进局外（现在还没处花）" % int(round(flow.sell_ratio() * 100)), 15, UiPalette.DIM))
	var row := _hbox(10)
	page.add_child(row)
	row.add_child(_label("一键出售", 13, UiPalette.DIM))
	_sell_pick = OptionButton.new()
	_sell_pick.add_theme_font_override("font", font)
	for i in SELL_FILTERS.size():
		_sell_pick.add_item(String(SELL_FILTERS[i][0]), i)
	_sell_pick.item_selected.connect(set_sell_filter)
	row.add_child(_sell_pick)
	_sell_preview = _label("", 13, UiPalette.FG)
	row.add_child(_sell_preview)
	row.add_child(_button("一键出售", func(): sell_filtered(), 13, UiPalette.Tier.PRIMARY))
	_sell_line = _label("", 13, UiPalette.STAMINA)
	page.add_child(_sell_line)
	_sell_view = InventoryView.new()
	_sell_view.label_font = font
	_sell_view.inventory = flow.meta.warehouse
	_sell_view.show_adjacency = false
	_sell_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_sell_view.item_double_clicked.connect(func(_v: ContainerView, uid: int): sell(uid))
	page.add_child(ScrollBox.wrap(_sell_view))     # 110：竖向滚动
	flow.meta.warehouse.changed.connect(_refresh_sell)
	set_sell_filter(0)
	return page


## 选一档（SELL_FILTERS 的下标）
func set_sell_filter(i: int) -> void:
	_sell_filter = clampi(i, 0, SELL_FILTERS.size() - 1)
	if _sell_pick != null:
		_sell_pick.select(_sell_filter)
	_refresh_sell()


func sell_filter_max() -> int:
	return int(SELL_FILTERS[_sell_filter][1])


## 卖掉仓库里的一件；返回得了多少（没这件 -1）
func sell(uid: int) -> int:
	var inst := flow.meta.warehouse.get_item(uid)
	var name := Names.of(inst.def) if inst != null else ""
	var got := flow.sell_item(uid)
	if got >= 0 and _sell_line != null:
		_sell_line.text = "卖掉「%s」，得 %d 币；现在有 %d 币" % [name, got, flow.meta.funds]
	return got


## 按当前那一档一键卖；返回 {"count", "funds"}
func sell_filtered() -> Dictionary:
	var got := flow.sell_where(sell_filter_max())
	if _sell_line != null:
		_sell_line.text = "卖掉 %d 件，得 %d 币；现在有 %d 币" % [int(got["count"]), int(got["funds"]), flow.meta.funds] if int(got["count"]) > 0 else "这一档没有可卖的"
	return got


func sell_preview_text() -> String:
	return _sell_preview.text if _sell_preview != null else ""


func _refresh_sell() -> void:
	if _sell_preview == null:
		return
	var p := flow.meta.sell_preview(sell_filter_max(), flow.sell_ratio())
	_sell_preview.text = "会卖 %d 件，得 %d 币" % [int(p["count"]), int(p["funds"])]
#endregion


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
	col.add_child(_wrapped("途径：" + ("？？？" if secret else Names.description_of(def)), 13, UiPalette.FG, 700))
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
	# 095（作者定）：派生的赐福版并进原件那一格（ids() 本来就不列赐福版），格子叠影 + 角标，点开弹异体列表
	var lit_n := 0
	var total_n := 0
	for id in ids:
		for vid in flow.items.variants_of(id):
			total_n += 1
			if m.codex_lit(vid):
				lit_n += 1
	page.add_child(_label("图鉴　带出过的点亮（%d / %d，含赐福版），右上角是累计件数；停在一格上看属性，叠着的格子点开看异体" % [lit_n, total_n], 15, UiPalette.DIM))
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
		var tile := _codex_tile_for(def)
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


## 095：一件（含它的异体）的格子：原件在前、各神的赐福版按 id 排；任一点亮格子就亮
func _codex_tile_for(def: ItemDef) -> CodexTile:
	var m := flow.meta
	var variants: Array[ItemDef] = [def]
	for vid in flow.items.variants_of(def.id):
		if vid != def.id:
			variants.append(flow.items.get_def(vid))
	var any_lit := false
	var tile := CodexTile.new(def, m.codex_lit(def.id), m.codex_count(def.id), font)
	for v in variants:
		var on := m.codex_lit(v.id)
		any_lit = any_lit or on
		tile.variant_lit.append(on)
		tile.variant_counts.append(m.codex_count(v.id))
	tile.variants = variants
	tile.lit = any_lit
	tile.hovered.connect(_on_tile_hovered)
	tile.unhovered.connect(func(_t: CodexTile): _codex_tip.hide_tip())
	tile.pressed.connect(func(t: CodexTile): show_variants(t))
	return tile


## 095：点开一格：有异体就弹出列表（原件、蛮神版、日神版……各一小格，点亮的亮着），再点关闭 / 别处关掉
func show_variants(tile: CodexTile) -> void:
	close_variants()
	if tile == null or tile.variant_count() == 0:
		return
	var box := _panel(10)
	box.name = "VariantsPopup"
	var col := _vbox(6)
	box.add_child(col)
	col.add_child(_label("%s　的异体（%d / %d 点亮）" % [Names.of(tile.def), tile.variants_lit(), tile.variants.size()], 14, UiPalette.FG))
	var row := _hbox(8)
	col.add_child(row)
	_variant_tiles.clear()
	for i in tile.variants.size():
		var v: ItemDef = tile.variants[i]
		var vt := CodexTile.new(v, tile.variant_lit[i] if i < tile.variant_lit.size() else false, tile.variant_counts[i] if i < tile.variant_counts.size() else 0, font)
		vt.hovered.connect(_on_tile_hovered)
		vt.unhovered.connect(func(_t: CodexTile): _codex_tip.hide_tip())
		var cell := _vbox(2)
		cell.add_child(_label(_variant_kind(v), 11, UiPalette.DIM))
		cell.add_child(vt)
		row.add_child(cell)
		_variant_tiles.append(vt)
	col.add_child(_button("关闭", close_variants, 12, UiPalette.Tier.MINOR))
	add_child(box)
	box.position = (tile.global_position + Vector2(0, tile.size.y + 6)).clamp(Vector2.ZERO, get_viewport_rect().size - Vector2(400, 200))
	_variants_popup = box


func close_variants() -> void:
	if _variants_popup != null:
		_variants_popup.queue_free()
		_variants_popup = null
	_variant_tiles.clear()


func variants_open() -> bool:
	return _variants_popup != null


func variant_tiles() -> Array[CodexTile]:
	return _variant_tiles


## 「原件」/「蛮神版」……
func _variant_kind(def: ItemDef) -> String:
	if def == null or not def.is_blessed():
		return "原件"
	var fid := FaithDef.id_of_tag(def.faith_tag())
	var fd: FaithDef = flow.faith_defs.get(fid, null) if flow.faith_defs != null else null
	return "%s版" % (Names.of(fd) if fd != null else String(fid))


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
		var how := "完成成就「%s」：%s" % [Names.of(ach), Names.description_of(ach)] if ach != null else "解锁 %s" % tile.def.requires_unlock
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
