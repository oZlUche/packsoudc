## 神坛屏（093，作者定）：休息处的「神坛」选项打开（只在激活了信仰时才有）。
##
## 上面一眼看到当前信仰、等级与信力；中间是祭品台（把道具拖上来；至少满足一条献祭规矩的才收），
## 「献祭」按钮在台上有东西时亮起并预览信力增长与等级变化；
## 到了等级解锁的特殊操作在右边一列按钮。反馈：**献祭和特殊操作二选一**，做了哪个这个休息处的神坛都关了；
## 神坛和休息是两份独立的机会，互不占用。「返回」= 回地图；没用过就还能再开。
extends GameScreen

const TABLE_ID := 4

var _node: MapNode = null
var _table: GridInventory = null
var _table_view: InventoryView
var _head: Label
var _preview := ""
var _offer_btn: Button
var _action_btns: Array = []
var _actions_box: VBoxContainer = null
var _actions_tier: int = -99
var _inv: InventoryPanelScript = null


func open(payload: Dictionary) -> void:
	_node = payload.get("node", null)
	var run := flow.run
	var def := run.active_faith()
	var panel := _centered_panel(Vector2(0, 0))
	var col := _vbox(10)
	panel.add_child(col)
	_head = _frame_title("")     # 157：标题在石板框的标题条上
	# 226 批二：顶上的说明删了，献祭品与规矩进「献祭」的悬浮窗
	var row := _hbox(24)
	col.add_child(row)

	var left := _vbox(8)
	row.add_child(left)
	left.add_child(HeaderTag.new(UiText.t("altar.table")))     # 226 批二：段头签
	_table = GridInventory.new(Vector2i(4, 4), TABLE_ID, false)
	_table_view = InventoryView.new()
	_table_view.label_font = font
	_table_view.inventory = _table
	_table_view.show_adjacency = false
	_table_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(_table_view)
	BoardFrame.wrap(_table_view)     # 227：素框 + 格缝
	# 226 批三：预览行并进「献祭」按钮第二行；「把祭品拖上台来」空态不写（preview_text 仍读得到）
	var buttons := _hbox(8)
	_offer_btn = ScrollKey.primary(UiText.t("altar.offer"), offer, true)     # 乙 石刻：主键压蜡封，预览是第二行小字
	_offer_btn.disabled = true
	_offer_btn.tooltip_text = UiText.t("altar.intro") + ((UiText.t("altar.offerings") % def.offerings_summary()) if def != null and not def.offerings.is_empty() else "")
	buttons.add_child(_offer_btn)
	var back := ScrollKey.make(UiText.t("setup.back"), to_map)
	back.tooltip_text = UiText.t("altar.back_tip")
	buttons.add_child(back)
	left.add_child(buttons)
	# 特殊操作（按等级刷；献祭升了级当场多出来）
	_actions_box = _vbox(6)
	left.add_child(_actions_box)

	_inv = _mount_bag(row, _table_view, Callable(), _table)     # 棋盘上双击 → 祭品台；226 批一：回话走告示层
	_table_view.item_double_clicked.connect(func(_v: ContainerView, uid: int): take_back(uid))
	_tip_double(_table_view, "act.take_back")     # 230
	_tip_quick(_inv, "act.offer", func(inst: ItemInstance) -> String:
		var d := flow.run.active_faith()
		return "" if d == null or d.accepts_offering(inst.def) else UiText.t("altar.rejected") % [Names.of(inst.def), Names.of(d)])
	_drag.drop_filter = func(inst: ItemInstance, target: ItemContainer) -> bool:
		if target != _table:
			return true
		var d := flow.run.active_faith()
		return d != null and d.accepts_offering(inst.def) and _altar_open() and not inst.is_locked_by_player()     # 230：锁住的不献
	_table.changed.connect(_refresh)
	run.faith_power.changed.connect(func(_id: StringName, _p: int, _t: int): _refresh())
	_refresh()


#region 公开动作
## 祭品台上的东西回棋盘（放不下到地上）
func take_back(uid: int) -> bool:
	var inst := _table.get_item(uid)
	if inst == null:
		return false
	return _take_to_player(_table, uid) != ""


## 把棋盘 / 地上的一件放上祭品台（不能献的不收）。测试直接调
func put_on_table(uid: int) -> bool:
	var run := flow.run
	var def := run.active_faith()
	var from := run.holder_of(uid)
	if from == null or def == null or not _altar_open():
		return false
	var inst := from.get_item(uid)
	if inst != null and inst.is_locked_by_player():
		say(UiText.t("item.locked_no") % Names.of(inst.def))     # 230
		return false
	if inst == null or not def.accepts_offering(inst.def):
		say(UiText.t("altar.rejected") % [Names.of(inst.def) if inst != null else "?", Names.of(def)])
		return false
	return InventoryService.transfer_auto(from, uid, _table)


## 台上献祭的预览：{"points", "tier_after"}
func preview() -> Dictionary:
	var run := flow.run
	var def := run.active_faith()
	var out := {"points": 0, "tier_before": run.active_faith_tier(), "tier_after": run.active_faith_tier(), "count": _table.item_count()}
	if def == null:
		return out
	for inst in _table.items():
		out["points"] = int(out["points"]) + def.offering_value((inst as ItemInstance).def)
	out["tier_after"] = def.tier_of(run.faith_power.points_of(def.id) + int(out["points"]))
	return out


## 按「献祭」：台上的全部销毁换信力
func offer() -> Dictionary:
	var insts: Array = _table.items().duplicate()
	if insts.is_empty() or not _altar_open():
		return {"points": 0, "count": 0}
	var altar := AltarModule.of(flow.run)
	var got: Dictionary = altar.offer(insts, _node) if altar != null else {"points": 0, "count": 0}
	if int(got["count"]) > 0:
		for inst in insts:
			_table.remove((inst as ItemInstance).uid)
		flow.save()
		say(UiText.t("setup.list_sep").join(got["log"]))
	_refresh()
	return got


## 做一个特殊操作（挑了选项的按下拉里的）
func special(perk: FaithPerk) -> String:
	var option: StringName = &""
	for b in _action_btns:
		if (b as Button).has_meta("pick") and (b as Button).text == perk.altar_label():
			var pick: OptionButton = (b as Button).get_meta("pick")
			var opts: Array = pick.get_meta("options")
			if pick.get_selected() >= 0 and pick.get_selected() < opts.size():
				option = opts[pick.get_selected()]
	# 台上还有东西先退回去，别把人家的东西吞了
	for inst in _table.items().duplicate():
		take_back((inst as ItemInstance).uid)
	var line := AltarModule.of(flow.run).special(perk, _node, option) if AltarModule.of(flow.run) != null else ""
	if line != "":
		say(line)
		flow.save()
		flow.close_altar()
	return line


## 返回：台上的东西先回背包
func to_map() -> bool:
	for inst in _table.items().duplicate():
		take_back((inst as ItemInstance).uid)
	flow.close_altar()
	return true


func escape() -> bool:
	return to_map()


func head_text() -> String:
	return _head.text if _head != null else ""


func preview_text() -> String:
	return _preview
#endregion


## 特殊操作那一列：到了等级的才有按钮；等级变了重画
func _rebuild_actions() -> void:
	var run := flow.run
	UiTheme.clear_children(_actions_box)
	_action_btns.clear()
	var actions := (AltarModule.of(run).actions() if AltarModule.of(run) != null else [])
	if actions.is_empty():
		return
	_actions_box.add_child(HSeparator.new())
	for p in actions:
		var perk := p as FaithPerk
		var arow := _hbox(6)
		var b := StoneChip.make(perk.altar_label(), func(): special(perk))     # 乙 石刻：特殊操作是石签（不切换，点了就做）
		b.toggle_mode = false
		var why := perk.altar_available(run, _node)
		b.disabled = why != "" or not _altar_open()
		b.tooltip_text = why if why != "" else perk.describe() + "\n" + UiText.t("altar.actions")     # 226 批二：「特殊操作（二选一……）」那行删了，括号里的话进按钮悬浮窗
		arow.add_child(b)
		if not perk.altar_options().is_empty():
			var pick := OptionButton.new()
			for i in perk.altar_options().size():
				var t: StringName = perk.altar_options()[i]
				var label := perk.altar_option_label(t)     # 188 补充一：效果自己给字（蛮神献祭的二选一）
				if label == "":
					label = String(MapNodeStyle.of(t)["label"]) if MapNodeTypes.has(t) else String(t)
				pick.add_item(label, i)
			pick.set_meta("options", perk.altar_options())
			UiTheme.dress_chip_option(pick)
			arow.add_child(pick)
			b.set_meta("pick", pick)
		_action_btns.append(b)
		_actions_box.add_child(arow)


func _refresh() -> void:
	var run := flow.run
	var def := run.active_faith()
	if _actions_box != null and run.active_faith_tier() != _actions_tier:
		_actions_tier = run.active_faith_tier()
		_rebuild_actions()
	if def == null:
		_head.text = UiText.t("altar.no_faith")
		_offer_btn.disabled = true
		return
	_head.text = UiText.t("altar.head") % [Names.of(def), run.faith_power.line()]
	var p := preview()
	var open := _altar_open()
	_offer_btn.disabled = int(p["points"]) <= 0 or not open
	var line := ""
	if not open:
		_preview = UiText.t("altar.used")
		line = UiText.t("altar.used_short")
	elif int(p["count"]) == 0:
		_preview = UiText.t("altar.drag_hint")
	else:
		_preview = UiText.tn("altar.preview", int(p["count"])) % [int(p["count"]), int(p["points"]), int(p["tier_before"]), int(p["tier_after"])]
		line = UiText.tn("altar.offer_line", int(p["count"])) % [int(p["count"]), int(p["points"]), int(p["tier_before"]), int(p["tier_after"])]
	ScrollKey.show_sub(_offer_btn, UiText.t("altar.offer"), line)
	for b in _action_btns:
		(b as Button).disabled = (b as Button).disabled or not open


## 101：神坛是一局的模块（没装 = 这一局没有神坛）
func _altar_open() -> bool:
	var altar := AltarModule.of(flow.run)
	return altar != null and altar.is_open()
