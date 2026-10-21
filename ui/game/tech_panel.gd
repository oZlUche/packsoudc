## 基地的「科技」页（110；118 作者定「树 + 说明板」；229 作者定：右半边仓库收起、整页一张树，左树右板）：
## [codeblock]
## 左：树区 —— 一整张绷开的羊皮（`tech/tech_tree_hide`，原大 936 × 700，放不下等比缩），科技树（TechTreeView）放在羊皮的双线框里；
##     深度 0 在最下面、往上点亮；每列顶上一枚段头签。点一个节点，右边的说明板切到它
## 右：说明板，一整条羊皮纸（226 §1.4）——  名牌：名称 + Lv n / m（单级写已点亮 / 未点亮）
##                                         效果：一句总述；「现在：……」「下一级：……」
##                                         账目行：钱 需要｜持有；材料每种一行 名称｜已交 / 需要｜拥有 n｜【交 k】；锁住的写「需要先点亮：……」；满级写「已满级」
##                                         【点亮】/【升级】
## [endcodeblock]
## 229：上交区删了 —— 材料行的【交 k】（138）是唯一的上交路，**上交即消耗**（交了不能退）；钱在按按钮时一次扣，
## 前置点亮、材料交齐且钱够按钮才亮。逻辑全在 [TechService]。
extends MarginContainer

signal changed()

const PANEL_WIDTH := 320.0
## 说明板里正文的宽（纸的左右内边距让掉）
const TEXT_WIDTH := PANEL_WIDTH - 48.0
## 账目行三栏的宽：数（右对齐）、拥有
const NUM_W := 64.0
const OWN_W := 72.0

var _flow: GameFlow = null
var _meta: MetaState = null
var _font: Font
var _tree: TechTreeView
var _area: TreeArea
var _plate: PanelContainer
var _name: Label
var _level: Label
var _effect: VBoxContainer
var _cost: VBoxContainer
var _action: Button
## 226 批一：最近一句回话（回话本身走告示卷轴；测试读 [method line_text]）
var _last_said := ""
var _selected: StringName = &""
## 材料行的【交 k】按钮：道具 id（字符串）→ Button（138；只有选中节点、前置满足、拥有且还差的才有）
var _submit_buttons: Dictionary = {}


func setup(flow: GameFlow, font: Font) -> void:
	_flow = flow
	_meta = flow.meta
	_font = font
	_build()
	_meta.changed.connect(_refresh)
	var first := _default_selection()
	if first != &"":
		select(first)
	_refresh()


func _build() -> void:
	var row := UiTheme.hbox(12)
	add_child(row)

	_area = TreeArea.new()
	_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_area)
	_tree = TechTreeView.new()
	_area.holder.add_child(_tree)
	_tree.setup(_meta, _flow.tech_defs, _font)
	_tree.selected.connect(_on_tree_selected)

	var board := UiTheme.panel(PanelContainer.new(), 24, UiTheme.PANEL_PARCHMENT)
	board.custom_minimum_size.x = PANEL_WIDTH
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(board)
	var col := UiTheme.vbox(10)
	board.add_child(col)
	# 226 §2.7：名称 + 等级进名牌（铜名牌，深底浅字）
	_plate = UiTheme.panel(PanelContainer.new(), 14, UiTheme.PANEL_NAMEPLATE)
	if UiTheme.tone_of(UiTheme.PANEL_NAMEPLATE) == UiTheme.TONE_DARK:
		_plate.theme = UiTheme.bright_text_theme()     # 铜名牌深底：不继承纸上的墨字
	col.add_child(_plate)
	var plate_col := UiTheme.vbox(2)
	_plate.add_child(plate_col)
	_name = UiTheme.make_label("", 20, UiPalette.FG)
	plate_col.add_child(_name)
	_level = UiTheme.make_label("", 13, UiPalette.DIM)
	plate_col.add_child(_level)
	_effect = UiTheme.vbox(4)
	col.add_child(_effect)
	_cost = UiTheme.vbox(2)
	col.add_child(_cost)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	_action = Button.new()
	UiPalette.style_button(_action, UiPalette.Tier.PRIMARY, UiPalette.button_font_size(14, UiPalette.Tier.PRIMARY))
	_action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_action.pressed.connect(func(): upgrade(_selected))
	col.add_child(_action)


#region 公开动作
## 选中一个节点（右板切到它）。没有这项返回 false
func select(id: StringName) -> bool:
	if _flow.tech_of(id) == null:
		return false
	if _tree.selected_id() != id:
		return _tree.select(id)     # 树会发 selected，回到 _on_tree_selected
	_selected = id
	_refresh()
	return true


func selected() -> StringName:
	return _selected


## 138：把仓库里这种材料交 k 件给**选中的节点**（材料行的【交 k】）。逐件走 submit_tech；返回交了几件
func submit_many(item_id: StringName, k: int) -> int:
	var def := _flow.tech_of(_selected)
	if def == null or not TechService.prereqs_met(_meta, def):
		return 0
	var uids: Array[int] = []
	for inst in _meta.warehouse.items():
		var it := inst as ItemInstance
		if uids.size() < k and it.def != null and it.def.id == item_id:
			uids.append(it.uid)
	var done := 0
	for uid in uids:
		if _flow.submit_tech(def.id, uid):
			done += 1
	if done > 0:
		var item_def := _flow.items.get_def(item_id) if _flow.items != null else null
		_say(UiText.t("tech.handed_in_many") % [done, Names.of(item_def) if item_def != null else String(item_id)])
		changed.emit()
		_refresh()
	return done


## 材料行的【交 k】按钮（测试看）；没有 null
func submit_button(item_id: StringName) -> Button:
	return _submit_buttons.get(String(item_id), null)


func upgrade(id: StringName) -> bool:
	var ok := _flow.upgrade_tech(id)
	if ok:
		var def := _flow.tech_of(id)
		_say(UiText.t("tech.lit_up") % Names.of(def) if def.max_level() <= 1 else UiText.t("tech.leveled_up") % [Names.of(def), TechService.level(_meta, id)])
		changed.emit()
	return ok


## 【点亮 / 升级】按钮 —— 只有选中的那个节点有（测试看）；不是选中的 null
func upgrade_button(id: StringName) -> Button:
	return _action if id == _selected and _action.visible else null


## 右板三区的文字（测试看）：{name（名牌：名称　等级）, effect, cost（账目行一行一行，栏间全角空格）}
func panel_texts() -> Dictionary:
	var name := UiText.t("tech.name_level") % [_name.text, _level.text] if _name.text != "" else ""
	return {"name": name, "effect": _texts_of(_effect), "cost": _texts_of(_cost)}


func tree() -> TechTreeView:
	return _tree


## 树区（测试看：羊皮底纸、树放在双线框里）
func tree_area() -> TreeArea:
	return _area


## 名牌（测试看）
func nameplate() -> PanelContainer:
	return _plate


func line_text() -> String:
	return _last_said


## 226 批一：回话 —— 告示卷轴（本地那行纸上的字删了）
func _say(text: String) -> void:
	_last_said = text
	NoticeLayer.post(self, text)
#endregion


## 一开始选谁：第一个能点的（前置满足、没满级）；都不能就第一个
func _default_selection() -> StringName:
	for def in _flow.tech_defs:
		if TechService.prereqs_met(_meta, def) and TechService.next_tier(_meta, def) != null:
			return def.id
	return _flow.tech_defs[0].id if not _flow.tech_defs.is_empty() else &""


func _on_tree_selected(id: StringName) -> void:
	_selected = id
	_last_said = ""
	_refresh()


func _refresh() -> void:
	if _tree == null:
		return
	_tree.rebuild()     # 等级变了节点样子跟着变；选中的那圈边 rebuild 时照旧画
	UiTheme.clear_children(_effect)
	UiTheme.clear_children(_cost)
	_submit_buttons.clear()
	var def := _flow.tech_of(_selected)
	_plate.visible = def != null     # 226：没选中时空态整块不画
	if def == null:
		_name.text = ""
		_level.text = ""
		_action.visible = false
		return
	var lv := TechService.level(_meta, def.id)
	var tier := TechService.next_tier(_meta, def)
	_name.text = Names.of(def)
	_level.text = TechTreeView.level_text(_meta, def)

	# 效果：一句总述 + 现在 / 下一级
	var desc := Names.description_of(def)
	if desc.strip_edges() != "":
		_effect.add_child(UiTheme.make_wrapped(TextTemplate.plain(desc, {}), 15, UiPalette.FG, TEXT_WIDTH))
	if def.effect != null:
		if lv >= 1:
			_effect.add_child(UiTheme.make_wrapped(UiText.t("tech.now") % def.effect.describe_level(lv, _flow.buff_defs), 14, UiPalette.HEAL, TEXT_WIDTH))
		if tier != null:
			_effect.add_child(UiTheme.make_wrapped(UiText.t("tech.next") % def.effect.describe_level(lv + 1, _flow.buff_defs), 14, UiPalette.FG, TEXT_WIDTH))

	# 费用：账目行
	if tier == null:
		_cost.add_child(UiTheme.make_label(UiText.t("tech.maxed"), 15, UiPalette.HEAL))
		_action.visible = false
		return
	var missing := TechService.missing_prereqs(_meta, def, _flow.tech_defs)
	if not missing.is_empty():
		var names: Array[String] = []
		for m in missing:
			names.append(Names.of(m))
		_cost.add_child(UiTheme.make_wrapped(UiText.t("tech.needs_prereq") % UiText.t("hud.buff_sep").join(names), 14, UiPalette.DIM, TEXT_WIDTH))
	_cost.add_child(_rule())
	var rich := _meta.funds >= tier.funds
	_cost.add_child(_ledger_row(UiText.t("tech.funds"), str(tier.funds), UiText.t("tech.owned") % _meta.funds, rich,
		UiText.t("tech.funds_tip") % [tier.funds, _meta.funds]))
	var keys: Array = tier.items.keys()
	keys.sort()
	var owned := _owned_counts()
	var open := missing.is_empty()
	for key in keys:
		var id := StringName(String(key))
		var need := int(tier.items[key])
		var have := TechService.deposited(_meta, def.id, id)
		var item_def := _flow.items.get_def(id) if _flow.items != null else null
		var name := Names.of(item_def) if item_def != null else String(key)
		var own := int(owned.get(String(key), 0))
		var row := _ledger_row(name + (UiText.t("tech.material_done") if have >= need else ""), "%d / %d" % [have, need],
			UiText.t("tech.owned") % own, have >= need, UiText.t("tech.material_tip") % [name, have, need])
		var k := mini(maxi(0, need - have), own)
		if open and k > 0:
			var btn := Button.new()
			btn.text = UiText.t("tech.submit_k") % k
			UiPalette.style_button(btn, UiPalette.Tier.SECONDARY, UiPalette.button_font_size(13, UiPalette.Tier.SECONDARY))
			btn.pressed.connect(submit_many.bind(id, k))
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(btn)
			_submit_buttons[String(key)] = btn
		_cost.add_child(row)
	_action.visible = true
	_action.text = UiText.t("tech.light_up") if def.max_level() <= 1 else UiText.t("tech.upgrade")     # 单级「点亮」、多级「升级」
	_action.disabled = not TechService.ready(_meta, def)


## 226 §1.5 账目行：名称（左）｜数（右对齐，数字字体）｜拥有 n；行下一道淡墨线。[param done] = 这一项够了（数写成绿）
func _ledger_row(label: String, number: String, own: String, done: bool, tip: String) -> HBoxContainer:
	var row := UiTheme.hbox(8)
	row.tooltip_text = tip
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var l := UiTheme.make_label(label, 15, UiPalette.FG)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	row.add_child(l)
	var n := Label.new()
	n.text = number
	var ls := LabelSettings.new()     # 账单那套数字：Cinzel Bold（缺的字落到思源宋体 Bold）
	ls.font = UiPalette.numeral_font()
	ls.font_size = 17
	ls.font_color = UiPalette.HEAL.darkened(0.35) if done else UiTheme.INK
	n.label_settings = ls
	n.custom_minimum_size.x = NUM_W
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(n)
	var o := UiTheme.make_label(own, 13, UiPalette.DIM)
	o.custom_minimum_size.x = OWN_W
	o.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(o)
	row.draw.connect(func(): row.draw_line(Vector2(0, row.size.y + 1), Vector2(row.size.x, row.size.y + 1), Color(UiTheme.INK, 0.25), 1.0))     # 行下一道淡墨线
	return row


## 一道淡墨线（账目表头的上沿）
func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(UiTheme.INK, 0.35)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## 仓库里每种道具几件：道具 id（字符串）→ 件数（仓库只有局外物品、一件一个）
func _owned_counts() -> Dictionary:
	var out := {}
	for inst in _meta.warehouse.items():
		var it := inst as ItemInstance
		if it.def != null:
			out[String(it.def.id)] = int(out.get(String(it.def.id), 0)) + 1
	return out


static func _texts_of(box: Container) -> String:
	var parts: Array[String] = []
	for c in box.get_children():
		if c is Label:
			parts.append((c as Label).text)
		elif c is HBoxContainer:     # 账目行：名称 / 数 / 拥有 n
			var row: Array[String] = []
			for l in c.get_children():
				if l is Label:
					row.append((l as Label).text)
			parts.append("　".join(row))
	return "\n".join(parts)


## 229 树区：羊皮底纸（固定背景，原大 936 × 700，放不下等比缩、居中）+ 一个滚动窗口，铺在羊皮的双线框里（离图边 `content_inset`）；
## 树在窗口里居中，比窗口高才滚
class TreeArea:
	extends Control

	const PAPER := "tech/tech_tree_hide"
	const PAPER_SIZE := Vector2(936, 700)
	const INSET := 72.0
	## 最小：原大的九成
	const MIN_SCALE := 0.9

	var paper: TextureRect
	var scroll: ScrollContainer
	## 树放进它（居中）
	var holder: CenterContainer
	var _inset := INSET

	func _init() -> void:
		custom_minimum_size = PAPER_SIZE * MIN_SCALE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inset = float(UiTheme.art_meta(PAPER).get("content_inset", INSET))
		paper = TextureRect.new()
		paper.texture = UiTheme.art(PAPER)
		paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(paper)
		scroll = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		add_child(scroll)
		holder = CenterContainer.new()
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(holder)
		UiTheme.set_tone(self, UiTheme.TONE_LIGHT)
		resized.connect(_arrange)

	## 底纸在本控件里的框（等比、不放大）
	func paper_rect() -> Rect2:
		var k := minf(1.0, minf(size.x / PAPER_SIZE.x, size.y / PAPER_SIZE.y))
		var s := PAPER_SIZE * k
		return Rect2(((size - s) * 0.5).floor(), s.floor())

	## 双线框（树能占的地方）
	func inner_rect() -> Rect2:
		var r := paper_rect()
		var k := r.size.x / PAPER_SIZE.x
		return r.grow(-_inset * k)

	func _arrange() -> void:
		var r := paper_rect()
		paper.position = r.position
		paper.size = r.size
		var inner := inner_rect()
		scroll.position = inner.position
		scroll.size = inner.size
