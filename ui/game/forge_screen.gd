## 铸炉屏（175 第三批，作者定；补充二：铸炉在休息点里，从休息屏的「铸炉」一栏或站在休息点上「重新打开」进来）。上面三个凹槽【时机】【效果】【数值】，任意道具都能进任意槽（一槽一件），
## 三槽都填了「铸」才亮；预览写将要铸出的那一枚（名字与那一句附魔）。194 §2：每槽下面三行小字，放进一件立刻写它在这个槽里贡献什么；
## 两槽满时灰字按空槽的 default 行试算一枚。194 §1：入口是休息点事件的「铸炉」选项（和神坛并列），不再挂在休息屏里。铸完三件消失、出牌槽出现一枚铸牌，铸炉熄掉。
## 「返回」= 接着看排着的、没有就回地图：槽里的东西先回背包，出牌槽里没拿走的铸牌也放回背包（放不下到地上）。没铸过还能再来
## 196 §5（美术定稿「乙 炉台版」，作者 2026-10-19）：不再是石板叠层，是「走到铁炉前」的整屏近景 —— 底图 cover 铺满（铸过换冷炉），
## 三槽、出牌槽、槽下小字、背包、「将铸出」几行、说明石板都按 `assets/ui/forge/layout.json` 摆（底图像素，跟底图同一个缩放与偏移）；
## 【时机】【效果】【数值】【出牌】和「铸炉」画在底图里，代码不写。「铸」= 风箱把手上的牌子（可铸 / 没放满 / 铸过 三张图），「返回」= 左下路标
extends GameScreen

const SLOT_SIZE := Vector2i(4, 4)
## 194 §2：槽下小字的字号
const SUMMARY_SIZE := 13
const ART_DIR := "res://assets/ui/forge/"
const LAYOUT_PATH := ART_DIR + "layout.json"
## 说明石板：字号、板面离石板外框的边（底图像素）
const SLATE_SIZE := 15
## 把手 / 路标悬停时提亮
const HOVER_LIFT := 1.12
const SLATE_INSET := Vector2(28, 36)

var _node: MapNode = null
## 时机、效果、数值三个槽
var _slots: Array[GridInventory] = []
var _slot_views: Array[InventoryView] = []
var _out: GridInventory = null
var _out_view: InventoryView = null
var _preview: Label
## 194 §2：每槽下面的三行小字（时机、效果、数值）
var _summaries: Array[RichTextLabel] = []
## 194 §2：两槽满时按空槽 default 行试算的那一句
var _guess: Label
var _line: Label
## 风箱把手（三张图跟着状态换）
var _forge_btn: TextureButton
var _back_btn: TextureButton
var _inv: InventoryPanelScript = null
var _layout: Dictionary = {}
var _bg: TextureRect
## 摆在底图上的几块（底图像素的矩形 → 屏上）：Control → Rect2
var _spots: Dictionary = {}
var _slate: Label
var _text_box: VBoxContainer
var _bag_host: Control
## 槽与出牌槽的宿主（视图在里面居中）
var _slot_hosts: Array[Control] = []
var _out_host: Control


func open(payload: Dictionary) -> void:
	_node = payload.get("node", null)
	_layout = layout()
	_backdrop(Color("07090d"))
	_bg = TextureRect.new()
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE     # 跟各块同一个变换（见 _place）
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	set_meta(&"tone", UiTheme.TONE_DARK)     # 夜里的炉台：字一律浅色

	var slot_rects: Array = _layout.get("slots", [])
	var caption_rects: Array = _layout.get("captions", [])
	for i in ForgeTable.SLOTS.size():
		var host := _host(_rect(slot_rects[i] if i < slot_rects.size() else {}))
		var g := GridInventory.new(SLOT_SIZE, 0, false)
		var v := InventoryView.new()
		v.label_font = font
		v.inventory = g
		v.show_adjacency = false
		host.add_child(v)
		_reserve_ground(host)
		_slot_hosts.append(host)
		var sum := UiTheme.rich_block(float(SLOT_SIZE.x * InventoryView.CELL), SUMMARY_SIZE)
		add_child(sum)
		_spots[sum] = _rect(caption_rects[i] if i < caption_rects.size() else {})
		_reserve_ground(sum)     # 小字写长了会越过石带：地上的东西别压着它
		_summaries.append(sum)
		_slots.append(g)
		_slot_views.append(v)
	_out_host = _host(_rect(_layout.get("output", {})))
	_out = GridInventory.new(Vector2i(1, 1), 0, false)
	_out_view = InventoryView.new()
	_out_view.label_font = font
	_out_view.inventory = _out
	_out_view.show_adjacency = false
	_out_host.add_child(_out_view)
	_reserve_ground(_out_host)

	_slate = _wrapped(UiText.t("forge.description"), SLATE_SIZE, UiPalette.FG, 400)
	add_child(_slate)
	_spots[_slate] = _rect(_layout.get("slate", {}))
	_text_box = _vbox(2)
	add_child(_text_box)
	_spots[_text_box] = _rect(_layout.get("text", {}))
	_preview = _label("", 13, UiPalette.STAMINA)
	_text_box.add_child(_preview)
	_guess = _label("", 12, UiPalette.DIM)
	_text_box.add_child(_guess)
	_line = _label("", 13, UiPalette.HEAL)
	_text_box.add_child(_line)

	_forge_btn = _piece_button("handle", UiText.t("forge.forge_btn"), forge)
	_forge_btn.disabled = true
	_back_btn = _piece_button("sign", UiText.t("setup.back"), to_map)
	_back_btn.tooltip_text = UiText.t("forge.back_tip")

	_bag_host = _host(_rect(_layout.get("bag", {})))
	_reserve_ground(_bag_host)
	_inv = _mount_bag(_bag_host, _slot_views[0], func(text: String): _line.text = text, null)     # 棋盘上双击 → 第一个空槽（见 put_in）
	move_child(_drag, -1)
	move_child(_tip, -1)
	for i in _slot_views.size():
		if i > 0:
			_drag.register_view(_slot_views[i])
			_tip.watch(_slot_views[i])
		var idx := i
		_slot_views[i].item_double_clicked.connect(func(_v: ContainerView, uid: int): take_back(idx, uid))
	_drag.register_view(_out_view)
	_tip.watch(_out_view)
	_out_view.item_double_clicked.connect(func(_v: ContainerView, _uid: int): take_token())
	for v in _slot_views:
		_tip_double(v, "act.take_back")     # 230
	_tip_double(_out_view, "act.take")
	_tip_quick(_inv, "act.to_forge")
	_drag.drop_filter = func(inst: ItemInstance, target: ItemContainer) -> bool:
		if target == _out:
			return _out.has_item(inst.uid)     # 出牌槽只出不进
		var i := _slots.find(target)
		if i < 0:
			return true
		if not _forge_open() or Forge.is_token(inst) or inst.is_locked_by_player():     # 230：锁住的不进铸炉
			return false
		var g := _slots[i]
		return g.item_count() == 0 or (g.item_count() == 1 and g.has_item(inst.uid))     # 一槽一件
	for g in _slots:
		g.changed.connect(_refresh)
	_out.changed.connect(_refresh)
	if not resized.is_connected(_place):
		resized.connect(_place)
	_refresh()
	_place()


## layout.json（底图尺寸、各块的矩形、切图的尺寸与原点）；读不出给空字典
static func layout() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	return parsed if parsed is Dictionary else {}


static func _rect(d: Dictionary) -> Rect2:
	return Rect2(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("w", 0)), float(d.get("h", 0)))


## 一块空的宿主，按底图上的矩形摆
func _host(r: Rect2) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	_spots[c] = r
	return c


## 风箱把手 / 路标：切图按钮，原点对齐 layout 里那一点；[param text] 只给读屏和测试看
func _piece_button(which: String, text: String, handler: Callable) -> TextureButton:
	var b := TextureButton.new()
	b.name = text
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func(): handler.call())
	b.mouse_entered.connect(func(): b.modulate = Color(HOVER_LIFT, HOVER_LIFT, HOVER_LIFT) if not b.disabled else Color.WHITE)     # 悬停提亮一点
	b.mouse_exited.connect(func(): b.modulate = Color.WHITE)
	b.set_meta(&"piece", which)
	if which == "sign":
		b.texture_normal = UiTheme.art_cached(UiTheme.lang_art("forge/sign_back"))     # 221：英文版 BACK
	add_child(b)
	return b


## 底图的缩放与偏移重算，各块跟着摆（窗口改大小时也走这里）。按宽铺满、竖直居中：比 16 : 10 宽的屏裁掉上下的天和地，
## 比它窄的（4 : 3）上下留暗边 —— 左边的路标、右边的背包都贴着画边，cover 一裁就出屏了
func _place() -> void:
	var wh: Array = _layout.get("scene", [1920, 1200])
	var scene := Vector2(float(wh[0]), float(wh[1]))
	var s := size.x / scene.x
	var offset := (size - scene * s) * 0.5
	_bg.position = offset
	_bg.size = scene * s
	for c in _spots:
		var r: Rect2 = _spots[c]
		var ctl := c as Control
		ctl.position = offset + r.position * s
		if ctl is Label:
			ctl.custom_minimum_size.x = r.size.x * s
			ctl.size = Vector2(r.size.x * s, 0)
		elif ctl is RichTextLabel:
			ctl.custom_minimum_size.x = r.size.x * s
			ctl.size.x = r.size.x * s
		else:
			ctl.size = r.size * s
	for i in _slot_hosts.size():
		_slot_views[i].position = ((_slot_hosts[i].size - _slot_views[i].size) * 0.5).floor()     # 格子 60 像素不缩放，在槽口里居中
	_out_view.position = ((_out_host.size - _out_view.size) * 0.5).floor()
	_slate.position += SLATE_INSET * s     # 板面在框里面
	_slate.custom_minimum_size.x = maxf(0.0, _slate.custom_minimum_size.x - SLATE_INSET.x * 2.0 * s)
	_slate.size.x = _slate.custom_minimum_size.x
	_place_piece(_forge_btn, "handle", s, offset)
	_place_piece(_back_btn, "sign", s, offset)


func _place_piece(b: TextureButton, which: String, s: float, offset: Vector2) -> void:
	var at: Array = (_layout.get(which, {}) as Dictionary).get("pos", [0, 0])
	var key := "sign_back" if which == "sign" else "handle_ready"
	var meta: Dictionary = (_layout.get("pieces", {}) as Dictionary).get(key, {})
	var sz: Array = meta.get("size", [0, 0])
	var org: Array = meta.get("origin", [0, 0])
	b.position = offset + (Vector2(float(at[0]), float(at[1])) - Vector2(float(org[0]), float(org[1]))) * s
	b.size = Vector2(float(sz[0]), float(sz[1])) * s


#region 公开动作
## 把棋盘 / 地上的一件放进第 [param slot] 个槽（0 时机、1 效果、2 数值）；槽里有东西、铸过了不收。测试直接调
func put_in(slot: int, uid: int) -> bool:
	var from := flow.run.holder_of(uid)
	if from == null or slot < 0 or slot >= _slots.size() or not _forge_open() or _slots[slot].item_count() > 0:
		return false
	var inst := from.get_item(uid)
	if inst == null or Forge.is_token(inst) or inst.is_locked_by_player():
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
		_line.text = UiText.t("forge.failed")
		return null
	if not _out.try_add(token):
		flow.run.storage.admit(token)
	_line.text = UiText.t("forge.done") % Names.of_item(token)
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


## 194 §2：第 [param i] 个槽下面的三行（去掉标记）
func summary_text(i: int) -> String:
	return Glossary.strip_bbcode(_summaries[i].text) if i >= 0 and i < _summaries.size() else ""


## 194 §2：两槽满时的试算句；别的时候空
func guess_text() -> String:
	return _guess.text if _guess != null else ""


## 194 §2：两槽满、一槽空时按空槽的 default 行试算的附魔；别的时候空
func guess() -> Dictionary:
	var defs: Array = []
	var filled := 0
	for g in _slots:
		var inst: ItemInstance = g.items()[0] if g.item_count() == 1 else null
		defs.append(inst.def if inst != null else null)
		filled += 1 if inst != null else 0
	if filled != _slots.size() - 1:
		return {}
	return Forge.forge(defs[0], defs[1], defs[2], true)


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
	for i in _slots.size():
		var inst: ItemInstance = _slots[i].items()[0] if _slots[i].item_count() == 1 else null
		var lines := Forge.slot_summary(ForgeTable.SLOTS[i], inst.def) if inst != null else ([] as Array[String])
		UiTheme.set_rich(_summaries[i], _summary_bbcode(lines))
	var ench := preview()
	_forge_btn.disabled = ench.is_empty() or not open
	_forge_btn.texture_normal = UiTheme.art_cached(UiTheme.lang_art("forge/handle_ready"))     # 221：把手与底图上的铭牌画着字，英文版另一套
	_forge_btn.texture_disabled = UiTheme.art_cached(UiTheme.lang_art("forge/handle_%s" % ("idle" if open else "off")))
	_bg.texture = UiTheme.art_cached(UiTheme.lang_art("forge/bg_%s" % ("lit" if open else "cold")))     # 铸过：炉熄
	var g := guess() if open else {}
	_guess.text = "" if g.is_empty() else UiText.t("forge.guess") % [Forge.prefix(g), Glossary.strip_bbcode(Forge.sentence(g))]
	_guess.visible = _guess.text != ""     # 空着不占一行
	if not open:
		_forge_btn.tooltip_text = UiText.t("forge.used")
		_preview.text = UiText.t("forge.used") if _out.item_count() == 0 else UiText.t("forge.ready")
	elif ench.is_empty():
		var missing: Array[String] = []
		for i in _slots.size():
			if _slots[i].item_count() == 0:
				missing.append(UiText.t("forge.slot_bracket") % Forge.slot_name(ForgeTable.SLOTS[i]))
		_preview.text = UiText.t("forge.missing") % UiText.t("forge.missing_sep").join(missing)
		_forge_btn.tooltip_text = _preview.text
	else:
		_preview.text = UiText.t("forge.preview") % [Forge.prefix(ench), Glossary.strip_bbcode(Forge.sentence(ench))]
		_forge_btn.tooltip_text = UiText.t("forge.forge_btn")


## 风箱把手现在是哪一张（ready / idle / off；测试看）
func handle_state() -> StringName:
	if not _forge_open():
		return &"off"
	return &"idle" if _forge_btn.disabled else &"ready"


## 底图现在是哪一张（lit / cold；测试看）
func backdrop_state() -> StringName:
	return &"lit" if _forge_open() else &"cold"


## 摆在底图上的一块现在在屏上的矩形（测试看）：slot0..2 / output / bag / text / slate / handle / sign
func spot_rect(which: String) -> Rect2:
	match which:
		"output":
			return _out_host.get_rect()
		"bag":
			return _bag_host.get_rect()
		"text":
			return _text_box.get_rect()
		"slate":
			return _slate.get_rect()
		"handle":
			return _forge_btn.get_rect()
		"sign":
			return _back_btn.get_rect()
	if which.begins_with("slot"):
		return _slot_hosts[int(which.substr(4))].get_rect()
	return Rect2()


func slot_view(i: int) -> InventoryView:
	return _slot_views[i]


## 194 §2：三行小字 —— 字走 dim、数字走 val
static func _summary_bbcode(lines: Array[String]) -> String:
	var p := TextTemplate.STYLE_PREFIX
	var re := RegEx.create_from_string("(×?\\d+(?:\\.\\d+)?)")
	var out: Array[String] = []
	for line in lines:
		out.append("[color=%sdim]%s[/color]" % [p, re.sub(line, "[color=%sval]$1[/color]" % p, true)])
	return "\n".join(out)
