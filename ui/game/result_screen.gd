## 结算（M6，架构文档 8 节 / 8.2；058 第 7 条）：撤离了棋盘原样带回来，在这里拖或一键置入仓库；战败什么都没有。
## 账（图鉴、价值、钱）在进这一屏之前就记好了（`GameFlow` 一局结束时 absorb）；「继续」去局外。
extends GameScreen

const WarehousePanelScript := preload("res://ui/game/warehouse_panel.gd")

var _wh = null
var _safe_view: InventoryView = null
var _stash_line: Label = null


func open(payload: Dictionary) -> void:
	var r: RunResult = payload.get("result", flow.result)
	_backdrop()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var col := _vbox(10)
	margin.add_child(col)
	if r == null:
		col.add_child(_label("没有可结算的一局", 18, UiPalette.FG))
		col.add_child(_button("回主菜单", flow.to_main_menu, 14))
		return
	var extracted := r.is_extracted()
	col.add_child(_label("撤离成功" if extracted else "战败", 28, UiPalette.HEAL if extracted else UiPalette.HP))
	col.add_child(_label("%s　种子 %d　%s" % [r.chapter_name, r.run_seed, _reason_text(r.reason)], 13, UiPalette.DIM))
	col.add_child(_label("行动点 %d　踩过 %d 个点　打赢 %d 场　打输 %d 场" % [r.steps, r.visited, r.battles_won, r.battles_lost], 14, UiPalette.FG))
	# 104：信力节奏的量尺（数值都是占位，作者打几局对着这一行调表）；开发版可以导 CSV
	if r.faith_pace != "":
		var pace_row := _hbox(12)
		pace_row.add_child(_label(r.faith_pace, 13, UiPalette.DIM))
		if OS.is_debug_build():
			var pace_note := _label("", 12, UiPalette.DIM)
			var export_csv := func():
				var path := r.export_faith_csv()
				pace_note.text = ("已写到 " + ProjectSettings.globalize_path(path)) if path != "" else "没写成"
			pace_row.add_child(_button("导出信力 CSV", export_csv, 12, UiPalette.Tier.MINOR))
			pace_row.add_child(pace_note)
		col.add_child(pace_row)
	if extracted:
		col.add_child(_label("背出来 %d 件、值 %d 币、带出 %d 币；图鉴新点亮 %d 条" % [
			r.carried.size(), r.value, r.balance, int(flow.last_absorbed.get("lit", 0))], 13, UiPalette.DIM))
		# 092（作者定）：暂存区里没背出来的，离开这一屏时一键出售 —— 先说清楚
		var sale := flow.stash_sale_preview()
		if r.left_behind > 0:
			_stash_line = _wrapped("暂存区里还有 %d 件（值 %d 币）没背出来：离开这一屏时会一键出售，得 %d 币（按基地出售比例）。" % [r.left_behind, r.left_value, int(sale["funds"])], 13, UiPalette.STAMINA, 700)
			col.add_child(_stash_line)
	else:
		col.add_child(_wrapped("背包、暂存区、钱，全都留在了里面。" + ("保险箱里的 %d 件带出来了。" % r.safe_items.size() if not r.safe_items.is_empty() else ""), 14, UiPalette.FG, 600))
	# 092：保险箱单独一格（放进去的视为已带出，战败也在）
	if not r.safe_items.is_empty():
		var safe_row := _hbox(16)
		var safe_col := _vbox(4)
		safe_col.add_child(_label("保险箱带出 %d 件、值 %d 币" % [r.safe_items.size(), r.safe_value], 13, UiPalette.HEAL))
		_safe_view = InventoryView.new()
		_safe_view.label_font = font
		_safe_view.inventory = _safe_display(r)
		_safe_view.show_adjacency = false
		_safe_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		safe_col.add_child(_safe_view)
		safe_row.add_child(safe_col)
		col.add_child(safe_row)
	if extracted or flow.meta.has_pending_board():
		col.add_child(HSeparator.new())
		_wh = WarehousePanelScript.new()
		_wh.setup(flow, font)
		col.add_child(_wh)
	var next := flow.next_chapter()
	if next != null:
		col.add_child(_wrapped("带回来的东西会进仓库。序章一张接一张：下面直接进「%s」。" % next.display_name, 13, UiPalette.DIM, 600))
		col.add_child(_button("进入下一张：%s" % next.display_name, proceed, 16, UiPalette.Tier.PRIMARY))
	else:
		col.add_child(_button("继续", proceed, 16, UiPalette.Tier.PRIMARY))


## 092：结算屏上画的保险箱：按 RunResult 记下的布局重摆一份只看的（实例已经进了局外，这里另造）
static func _safe_display(r: RunResult) -> GridInventory:
	var grid := GridInventory.new(r.safe_size, 0, false)
	for entry in r.safe_layout:
		var inst := ItemInstance.create(entry["def"], int(entry["rotation"]))
		if not grid.place(inst, entry["origin"], int(entry["rotation"])):
			grid.try_add(inst, true)
	return grid


## 结算屏上的保险箱格子（测试直接读）
func safe_view() -> InventoryView:
	return _safe_view


## 一键置入（测试直接调）
func store_all() -> Dictionary:
	return _wh.store_all() if _wh != null else {"moved": 0, "left": 0, "stuck": ""}


## 「继续」：有下一张教学图就直接进（085），否则去局外
func proceed() -> void:
	if flow.next_chapter() != null:
		flow.start_next_chapter()
	else:
		flow.finish_result()


func _reason_text(reason: StringName) -> String:
	match reason:
		&"extract":
			return "从撤离点出来"
		&"vitality_depleted":
			return "体力耗尽"
		&"boss_lost":
			return "核心一战失利"
		&"fatal_loss":
			return "输了一场不能输的仗"
		&"boss":
			return "击败了核心的 BOSS，直接撤离"
		&"time_out":
			return "倒计时归零：行动失败"
	return String(reason)
