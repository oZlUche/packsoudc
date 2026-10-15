## 铸炉屏（175 第三批，作者定；补充二：铸炉在休息点里，从休息屏的「铸炉」一栏或站在休息点上「重新打开」进来）。上面三个凹槽【时机】【效果】【数值】，任意道具都能进任意槽（一槽一件），
## 三槽都填了「铸」才亮；预览写将要铸出的那一枚（名字与那一句附魔）。铸完三件消失、出牌槽出现一枚铸牌，铸炉熄掉。
## 「返回」= 接着看排着的、没有就回地图：槽里的东西先回背包，出牌槽里没拿走的铸牌也放回背包（放不下到地上）。没铸过还能再来
extends GameScreen

const SLOT_SIZE := Vector2i(4, 4)

var _node: MapNode = null
## 时机、效果、数值三个槽
var _slots: Array[GridInventory] = []
var _slot_views: Array[InventoryView] = []
var _out: GridInventory = null
var _out_view: InventoryView = null
var _head: Label
var _preview: Label
var _line: Label
var _forge_btn: Button
var _inv: Control = null


func open(payload: Dictionary) -> void:
	_node = payload.get("node", null)
	var panel := _centered_panel(Vector2(0, 0))
	var col := _vbox(10)
	panel.add_child(col)
	_head = _frame_title("铸炉")     # 157：标题在石板框的标题条上
	col.add_child(_wrapped("把三件道具分别放进【时机】【效果】【数值】三个槽：时机槽定什么时候、效果槽定做什么、数值槽定多大，各按道具的材质、用途、稀有度查表。三槽都放了才能铸；铸成一枚铸牌，拖到武器上就是附魔（永久，后来者覆盖前者）。铸炉用一次就熄。", 12, UiPalette.DIM, 900))
	var row := _hbox(24)
	col.add_child(row)

	var left := _vbox(8)
	row.add_child(left)
	var slots_row := _hbox(12)
	left.add_child(slots_row)
	for slot in ForgeTable.SLOTS:
		var box := _vbox(4)
		box.add_child(_label("【%s】" % Forge.slot_name(slot), 14, UiPalette.FG))
		var g := GridInventory.new(SLOT_SIZE, 0, false)
		var v := InventoryView.new()
		v.label_font = font
		v.inventory = g
		v.show_adjacency = false
		v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		box.add_child(v)
		slots_row.add_child(box)
		_slots.append(g)
		_slot_views.append(v)
	var out_row := _hbox(12)
	left.add_child(out_row)
	out_row.add_child(_label("出牌", 14, UiPalette.FG))
	_out = GridInventory.new(Vector2i(1, 1), 0, false)
	_out_view = InventoryView.new()
	_out_view.label_font = font
	_out_view.inventory = _out
	_out_view.show_adjacency = false
	_out_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	out_row.add_child(_out_view)
	_preview = _label("", 13, UiPalette.STAMINA)
	left.add_child(_preview)
	var buttons := _hbox(8)
	_forge_btn = _button("铸", forge, 14, UiPalette.Tier.PRIMARY)
	_forge_btn.disabled = true
	buttons.add_child(_forge_btn)
	var back := _button("返回", to_map, 13)
	back.tooltip_text = "离开铸炉；没铸过站在这个休息点上还能再开（Esc）"
	buttons.add_child(back)
	left.add_child(buttons)
	_line = _label("", 13, UiPalette.HEAL)
	left.add_child(_line)

	_inv = _mount_bag(row, _slot_views[0], func(text: String): _line.text = text, null)     # 棋盘上双击 → 第一个空槽（见 put_in）
	for i in _slot_views.size():
		if i > 0:
			_drag.register_view(_slot_views[i])
			_tip.watch(_slot_views[i])
		var idx := i
		_slot_views[i].item_double_clicked.connect(func(_v: ContainerView, uid: int): take_back(idx, uid))
	_drag.register_view(_out_view)
	_tip.watch(_out_view)
	_out_view.item_double_clicked.connect(func(_v: ContainerView, _uid: int): take_token())
	_drag.drop_filter = func(inst: ItemInstance, target: ItemContainer) -> bool:
		if target == _out:
			return _out.has_item(inst.uid)     # 出牌槽只出不进
		var i := _slots.find(target)
		if i < 0:
			return true
		if not _forge_open() or Forge.is_token(inst):
			return false
		var g := _slots[i]
		return g.item_count() == 0 or (g.item_count() == 1 and g.has_item(inst.uid))     # 一槽一件
	for g in _slots:
		g.changed.connect(_refresh)
	_out.changed.connect(_refresh)
	_refresh()


#region 公开动作
## 把棋盘 / 地上的一件放进第 [param slot] 个槽（0 时机、1 效果、2 数值）；槽里有东西、铸过了不收。测试直接调
func put_in(slot: int, uid: int) -> bool:
	var from := flow.run.holder_of(uid)
	if from == null or slot < 0 or slot >= _slots.size() or not _forge_open() or _slots[slot].item_count() > 0:
		return false
	var inst := from.get_item(uid)
	if inst == null or Forge.is_token(inst):
		return false
	return InventoryService.transfer_auto(from, uid, _slots[slot])


## 槽里的东西回棋盘（放不下到地上）
func take_back(slot: int, uid: int) -> bool:
	if slot < 0 or slot >= _slots.size() or _slots[slot].get_item(uid) == null:
		return false
	return _take_to_player(_slots[slot], uid) != ""


## 出牌槽里的铸牌拿回背包
func take_token() -> bool:
	for inst in _out.items().duplicate():
		if _take_to_player(_out, (inst as ItemInstance).uid) == "":
			return false
	return true


## 三槽里的三件（没放满返回空）
func picked() -> Array:
	var out: Array = []
	for g in _slots:
		if g.item_count() != 1:
			return []
		out.append(g.items()[0])
	return out


## 将要铸出的那一枚的附魔（没放满 = 空）
func preview() -> Dictionary:
	var p := picked()
	if p.is_empty():
		return {}
	return Forge.forge((p[0] as ItemInstance).def, (p[1] as ItemInstance).def, (p[2] as ItemInstance).def)


## 按「铸」：三件消失、出牌槽里一枚铸牌、铸炉熄掉。返回铸牌（没铸成 null）
func forge() -> ItemInstance:
	var p := picked()
	if p.is_empty() or not _forge_open():
		return null
	var token := flow.forge_token(_node, p[0], p[1], p[2], [_slots[0], _slots[1], _slots[2]])
	if token == null:
		_line.text = "铸不出来（铸炉映射表缺了）"
		return null
	if not _out.try_add(token):
		flow.run.storage.admit(token)
	_line.text = "铸成：%s —— 拖到武器上就是附魔" % Names.of_item(token)
	_refresh()
	return token


## 返回：槽里的东西、没拿走的铸牌先回背包
func to_map() -> bool:
	for i in _slots.size():
		for inst in _slots[i].items().duplicate():
			take_back(i, (inst as ItemInstance).uid)
	take_token()
	return flow.leave_forge()


func escape() -> bool:
	return to_map()


func preview_text() -> String:
	return _preview.text if _preview != null else ""


func slot(i: int) -> GridInventory:
	return _slots[i]


func output() -> GridInventory:
	return _out
#endregion


func _forge_open() -> bool:
	return _node != null and not NodeEvents.forge_used(_node)


func _refresh() -> void:
	var open := _forge_open()
	var empty: GridInventory = null     # 棋盘上双击 → 第一个空槽
	for g in _slots:
		if g.item_count() == 0 and empty == null:
			empty = g
	if _inv != null:
		_inv.set("quick_target", empty if open else null)
	var ench := preview()
	_forge_btn.disabled = ench.is_empty() or not open
	if not open:
		_head.text = "铸炉（已熄）"
		_preview.text = "这座铸炉已经用过了" if _out.item_count() == 0 else "铸好了：把铸牌拖回背包，或拖到武器上附魔"
	elif ench.is_empty():
		_head.text = "铸炉"
		var missing: Array[String] = []
		for i in _slots.size():
			if _slots[i].item_count() == 0:
				missing.append("【%s】" % Forge.slot_name(ForgeTable.SLOTS[i]))
		_preview.text = "还差：%s" % "".join(missing)
	else:
		_head.text = "铸炉"
		_preview.text = "将铸出：铸牌 · %s —— %s" % [Forge.prefix(ench), Glossary.strip_bbcode(Forge.sentence(ench))]
