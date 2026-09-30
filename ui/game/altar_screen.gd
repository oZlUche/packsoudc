## 神坛屏（093，作者定）：休息处的「神坛」选项打开（只在激活了信仰时才有）。
##
## 上面一眼看到当前信仰、等级与信力；中间是祭品台（把道具拖上来；至少满足一条献祭规矩的才收），
## 「献祭」按钮在台上有东西时亮起并预览信力增长与等级变化，常规献祭没有次数限制；
## 到了等级解锁的特殊操作在右边一列按钮，**和常规献祭共享这一次机会**：做了特殊操作这个休息处的神坛就关了。
## 「返回」= 回地图；站在这个点上、没用过特殊操作就还能再开。
extends GameScreen

const InventoryPanelScript := preload("res://ui/game/inventory_panel.gd")
const TABLE_ID := 4

var _node: MapNode = null
var _table: GridInventory = null
var _table_view: InventoryView
var _drag: DragLayer
var _head: Label
var _preview: Label
var _line: Label
var _offer_btn: Button
var _action_btns: Array = []
var _actions_box: VBoxContainer = null
var _actions_tier: int = -99
var _inv: Control = null


func open(payload: Dictionary) -> void:
	_node = payload.get("node", null)
	var run := flow.run
	var def := run.active_faith()
	var panel := _centered_panel(Vector2(0, 0))
	var col := _vbox(10)
	panel.add_child(col)
	_head = _label("", 20, UiPalette.FG)
	col.add_child(_head)
	col.add_child(_wrapped("神坛：把道具拖到祭品台上献祭换信力（至少满足一条献祭规矩的才收，一件满足几条算几次）。常规献祭不限次数；特殊操作和献祭共享这一次机会，做了神坛就关了。" +
		(("\n献祭品：" + def.offerings_summary()) if def != null and not def.offerings.is_empty() else ""), 12, UiPalette.DIM, 900))
	var row := _hbox(24)
	col.add_child(row)

	var left := _vbox(8)
	row.add_child(left)
	left.add_child(_label("祭品台", 14, UiPalette.FG))
	_table = GridInventory.new(Vector2i(4, 4), TABLE_ID, false)
	_table_view = InventoryView.new()
	_table_view.label_font = font
	_table_view.inventory = _table
	_table_view.show_adjacency = false
	_table_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(_table_view)
	_preview = _label("", 13, UiPalette.STAMINA)
	left.add_child(_preview)
	var buttons := _hbox(8)
	_offer_btn = _button("献祭", offer, 14, UiPalette.Tier.PRIMARY)
	_offer_btn.disabled = true
	buttons.add_child(_offer_btn)
	var back := _button("返回", to_map, 13)
	back.tooltip_text = "回到地图；站在这个点上、没用过特殊操作还能再来（Esc）"
	buttons.add_child(back)
	left.add_child(buttons)
	_line = _label("", 13, UiPalette.HEAL)
	left.add_child(_line)
	# 特殊操作（按等级刷；献祭升了级当场多出来）
	_actions_box = _vbox(6)
	left.add_child(_actions_box)

	var inv := InventoryPanelScript.new()
	_drag = DragLayer.new()
	_drag.label_font = font
	inv.setup(run, font, _drag)
	inv.quick_target = _table     # 棋盘上双击 → 祭品台
	inv.hint_sink = func(text: String): _line.text = text
	_inv = inv
	row.add_child(inv)
	_table_view.item_double_clicked.connect(func(_v: ContainerView, uid: int): take_back(uid))
	_drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_drag)
	_drag.register_view(_table_view)
	_drag.drop_filter = func(inst: ItemInstance, target: ItemContainer) -> bool:
		if target != _table:
			return true
		var d := flow.run.active_faith()
		return d != null and d.accepts_offering(inst.def) and run.altar_open()
	var tip := HoverTip.new(font)
	add_child(tip)
	tip.watch(_table_view)
	_table.changed.connect(_refresh)
	run.faith_power.changed.connect(func(_id: StringName, _p: int, _t: int): _refresh())
	_refresh()


#region 公开动作
## 祭品台上的东西回棋盘（放不下进暂存区）
func take_back(uid: int) -> bool:
	var inst := _table.get_item(uid)
	if inst == null:
		return false
	if InventoryService.transfer_auto(_table, uid, flow.run.board):
		return true
	return InventoryService.transfer_auto(_table, uid, flow.run.storage)


## 把棋盘 / 暂存区里的一件放上祭品台（不能献的不收）。测试直接调
func put_on_table(uid: int) -> bool:
	var run := flow.run
	var def := run.active_faith()
	var from: ItemContainer = run.board if run.board.has_item(uid) else (run.storage if run.storage.has_item(uid) else null)
	if from == null or def == null or not run.altar_open():
		return false
	var inst := from.get_item(uid)
	if inst == null or not def.accepts_offering(inst.def):
		_line.text = "「%s」不是%s认的祭品" % [Names.of(inst.def) if inst != null else "?", Names.of(def)]
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
	if insts.is_empty() or not flow.run.altar_open():
		return {"points": 0, "count": 0}
	var got := flow.run.offer(insts, _node)
	if int(got["count"]) > 0:
		for inst in insts:
			_table.remove((inst as ItemInstance).uid)
		flow.save()
		_line.text = "、".join(got["log"])
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
	var line := flow.run.altar_special(perk, _node, option)
	if line != "":
		_line.text = line
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
	return _preview.text if _preview != null else ""
#endregion


## 特殊操作那一列：到了等级的才有按钮；等级变了重画
func _rebuild_actions() -> void:
	var run := flow.run
	for ch in _actions_box.get_children():
		ch.queue_free()
	_action_btns.clear()
	var actions := run.altar_actions()
	if actions.is_empty():
		return
	_actions_box.add_child(HSeparator.new())
	_actions_box.add_child(_label("特殊操作（做一次就关神坛）", 14, UiPalette.FG))
	for p in actions:
		var perk := p as FaithPerk
		var arow := _hbox(6)
		var b := _button(perk.altar_label(), func(): special(perk), 13)
		var why := perk.altar_available(run, _node)
		b.disabled = why != "" or not run.altar_open()
		b.tooltip_text = why if why != "" else perk.describe()
		arow.add_child(b)
		if not perk.altar_options().is_empty():
			var pick := OptionButton.new()
			pick.add_theme_font_override("font", font)
			for i in perk.altar_options().size():
				var t: StringName = perk.altar_options()[i]
				pick.add_item(String(MapNodeStyle.of(t)["label"]) if MapNodeTypes.has(t) else String(t), i)
			pick.set_meta("options", perk.altar_options())
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
		_head.text = "神坛　没有激活的信仰"
		_offer_btn.disabled = true
		return
	_head.text = "神坛　%s　%s" % [Names.of(def), run.faith_power.line()]
	var p := preview()
	var open := run.altar_open()
	_offer_btn.disabled = int(p["points"]) <= 0 or not open
	if not open:
		_preview.text = "这个休息处的神坛已经用过特殊操作，关了"
	elif int(p["count"]) == 0:
		_preview.text = "把祭品拖上台来"
	else:
		_preview.text = "献祭 %d 件：信力 +%d（Lv.%d → Lv.%d）" % [int(p["count"]), int(p["points"]), int(p["tier_before"]), int(p["tier_after"])]
	for b in _action_btns:
		(b as Button).disabled = (b as Button).disabled or not open
