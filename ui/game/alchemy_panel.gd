## 354：后勤「炼金」页（[Alchemy]）。作者 2026-11-21 选 C 炼成阵、尘图标 A（UI设计，`assets/ui/alchemy/layout.json`）：
## 顶上一块小木牌写现有的尘；地上一个炼成阵，三角的三个角各放一件勾了的素材（多于三件轮流叠到三个角上，角下 ×n）；
## 阵心是要得的尘（叠在光晕上，没勾时不画）；下面一张纸条：「→ 尘 +N」、「卖掉 金币 N · 折损 N%」、【一键炼金】【炼化】（两步确认）。
## 右边仓库进勾选模式（[method rule]）。不垫粗布，墙透出来；版面按中列宽等比缩（同苗圃页）。
## 第七节（作者 2026-11-21 11:39）：仓库里每一件都勾得上（锁定的除外）；勾了剧情独有 / 委托要交的，纸条上红字写「拿不回来」，第一下【炼化】再说一遍。
## 尘牌下面一行筛选（标签 + 稀有度，和仓库页筛选牌是同一个筛选）；【一键炼金】= 勾上合筛选的、跳过锁定 / 收藏 / 独有 / 委托 / 出征携带（[method Alchemy.auto_picks]），
## 纸条写跳过几件；没选标签或一件可炼都没有时暗着
extends VBoxContainer

signal changed()
## 有话要说（炼了多少；不能炼的原因）
signal said(text: String, warn: bool)

const ART := "alchemy/"
const CONFIRM_SEC := 2.0
## 版面（layout.json，中列宽 392）
const W := 392.0
const TOP_Y := 24.0
const CIRCLE := 340.0
const CIRCLE_CY := 330.0
const RADIUS := 136.0
const ANGLES: Array[float] = [-90.0, 30.0, 150.0]
const NODE := 76.0
const ITEM := 60.0
const PEEK := 6.0
const GLOW := 128.0
const CENTER_DUST := 70.0
const SLIP_Y := 590.0
const SLIP_H := 260.0
## 第七节：筛选那一行
const FILTER_GAP := 8.0
const TAG_W := 160.0
const RARITY_W := 138.0
const FILTER_H := 34.0
const NOTE_FONT := 15
## 358（UI设计 A，作者选定）：拿不回来那件的角套红圈；纸条上的警告带
const RING := 96.0
const BAND_INSET := 22.0
const BAND_ICON := 26.0
const BAND_BAR := 4.0
const BAND_BG := Color(0.604, 0.184, 0.133, 0.08)
const H := SLIP_Y + SLIP_H + 20.0
const LIGHT := Color("f1e3c2")
const LOSS_RED := Color("9a2f22")

var flow: GameFlow = null
var shelf: WarehousePages = null
var go_btn: Button = null
var auto_btn: Button = null
var tag_pick: OptionButton = null
var rarity_pick: OptionButton = null
var _danger: Label = null
var _band: Control = null
var _band_icon: TextureRect = null
var _slip: PanelContainer = null
var _skip: Label = null
var confirm_left := 0.0
var _frame: Control = null
var _stage: Control = null
var _have: Label = null
var _nodes: Array[Control] = []
var _center: Control = null
var _gain: Label = null
var _funds: CoinLabel = null
var _loss: Label = null


func setup(p_flow: GameFlow, p_shelf: WarehousePages) -> void:
	flow = p_flow
	shelf = p_shelf
	name = "AlchemyPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_frame = Control.new()
	_frame.name = "StageFrame"
	_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.custom_minimum_size = Vector2(0, H)
	scroll.add_child(_frame)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.size = Vector2(W, H)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.set_tone(_stage, UiTheme.TONE_DARK)
	_frame.add_child(_stage)
	_frame.resized.connect(_fit)
	_build()
	shelf.selection_changed.connect(refresh)
	shelf.filter_changed.connect(refresh)
	flow.meta.warehouse.changed.connect(_refresh_tags)
	visibility_changed.connect(_reset_confirm)
	_refresh_tags()
	refresh()


## 版面按中列宽等比缩（最大 1 倍），横向居中
func _fit() -> void:
	var k := clampf(_frame.size.x / W, 0.3, 1.0) if _frame.size.x > 0.0 else 1.0
	_stage.scale = Vector2(k, k)
	_stage.position = Vector2((_frame.size.x - W * k) * 0.5, 0.0)
	_frame.custom_minimum_size.y = H * k


func _build() -> void:
	var plaque := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 18, 6, 18, 6)     # 顶上一小块：现有的尘
	plaque.name = "Have"
	UiTheme.set_tone(plaque, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	var head := UiTheme.hbox(8)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(dust_icon(42.0))
	_have = UiTheme.make_label("", 30, UiTheme.INK)
	_have.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	head.add_child(_have)
	plaque.add_child(head)
	plaque.tooltip_text = UiText.t("alchemy.dust")
	plaque.mouse_filter = Control.MOUSE_FILTER_PASS
	_stage.add_child(plaque)
	plaque.resized.connect(func(): plaque.position = Vector2((W - plaque.size.x) * 0.5, TOP_Y))
	var filters := UiTheme.hbox(8)     # 第七节：筛选（和仓库页筛选牌同一个）；358 A：尘牌正下方两块浅色木签下拉
	filters.name = "Filter"
	filters.alignment = BoxContainer.ALIGNMENT_CENTER
	filters.size = Vector2(W, FILTER_H)
	UiTheme.set_tone(filters, UiTheme.TONE_LIGHT)
	plaque.resized.connect(func(): filters.position = Vector2(0, TOP_Y + plaque.size.y + FILTER_GAP))
	tag_pick = OptionButton.new()
	tag_pick.name = "AlchemyTag"
	tag_pick.custom_minimum_size = Vector2(TAG_W, FILTER_H)
	tag_pick.item_selected.connect(func(i: int): shelf.set_filter(StringName(String(tag_pick.get_item_metadata(i))), shelf.filter_rarity))
	UiTheme.dress_wood_option(tag_pick, 16)
	filters.add_child(tag_pick)
	rarity_pick = OptionButton.new()
	rarity_pick.name = "AlchemyRarity"
	rarity_pick.custom_minimum_size = Vector2(RARITY_W, FILTER_H)
	WarehouseTools.fill_rarities(rarity_pick)
	rarity_pick.item_selected.connect(func(i: int): shelf.set_filter(shelf.filter_tag, int(WarehouseTools.RARITIES[i][1])))
	UiTheme.dress_wood_option(rarity_pick, 16)
	filters.add_child(rarity_pick)
	_stage.add_child(filters)
	var c := Vector2(W * 0.5, CIRCLE_CY)
	_stage.add_child(_pic("circle", Rect2(c - Vector2(CIRCLE, CIRCLE) * 0.5, Vector2(CIRCLE, CIRCLE))))
	for a in ANGLES:
		var at := c + Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a))) * RADIUS
		var n := Control.new()
		n.name = "Node%d" % _nodes.size()
		n.position = at - Vector2(NODE, NODE) * 0.5
		n.size = Vector2(NODE, NODE)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.add_child(_pic("node", Rect2(Vector2.ZERO, Vector2(NODE, NODE))))
		_stage.add_child(n)
		_nodes.append(n)
	_center = Control.new()
	_center.name = "Center"
	_center.position = c - Vector2(GLOW, GLOW) * 0.5
	_center.size = Vector2(GLOW, GLOW)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(_pic("center_glow", Rect2(Vector2.ZERO, Vector2(GLOW, GLOW))))
	var cd := dust_icon(CENTER_DUST)
	cd.position = Vector2(GLOW - CENTER_DUST, GLOW - CENTER_DUST) * 0.5
	cd.size = Vector2(CENTER_DUST, CENTER_DUST)
	_center.add_child(cd)
	_stage.add_child(_center)
	var slip := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 20, 16, 20, 16)     # 纸条
	slip.name = "Slip"
	UiTheme.set_tone(slip, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	slip.position = Vector2(20, SLIP_Y)
	slip.custom_minimum_size.x = W - 40.0
	_stage.add_child(slip)
	_slip = slip
	var col := UiTheme.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	slip.add_child(col)
	var gain := UiTheme.hbox(8)
	gain.name = "Gain"
	gain.alignment = BoxContainer.ALIGNMENT_CENTER
	gain.add_child(UiTheme.make_label("→", 28, UiTheme.INK_SOFT))
	gain.add_child(dust_icon(44.0))
	_gain = UiTheme.make_label("", 32, UiTheme.INK)
	_gain.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	gain.add_child(_gain)
	col.add_child(gain)
	var line2 := UiTheme.hbox(6)
	line2.alignment = BoxContainer.ALIGNMENT_CENTER
	line2.add_child(UiTheme.make_label(UiText.t("alchemy.or_sell"), 18, UiTheme.INK_SOFT))
	_funds = CoinLabel.make(0, UiTheme.sz(18), UiTheme.INK_SOFT)
	_funds.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line2.add_child(_funds)
	line2.add_child(UiTheme.make_label("·", 18, UiTheme.INK_SOFT))
	_loss = UiTheme.make_label("", 18, LOSS_RED)
	_loss.name = "Loss"
	_loss.mouse_filter = Control.MOUSE_FILTER_PASS
	line2.add_child(_loss)
	col.add_child(line2)
	col.add_child(_build_band())
	_skip = UiTheme.make_label("", NOTE_FONT, UiTheme.INK_SOFT)
	_skip.name = "Skipped"
	_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_skip)
	var row := UiTheme.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	auto_btn = UiTheme.make_home_button(UiText.t("alchemy.auto"), one_click, false, Vector2(132, 48), 18)
	auto_btn.name = "AlchemyAuto"
	auto_btn.tooltip_text = UiText.t("alchemy.auto_tip")
	row.add_child(auto_btn)
	go_btn = UiTheme.make_home_button(UiText.t("alchemy.go"), press_go, true, Vector2(140, 52), 20)
	go_btn.name = "AlchemyGo"
	row.add_child(go_btn)
	col.add_child(row)


## 358 A：警告带 —— 左右各缩 [constant BAND_INSET]；左边红竖线、淡红底（[Band] 自己画）；里面小图 + 粗体红名字 + 红字「炼了拿不回来」
func _build_band() -> Control:
	var row := UiTheme.hbox(0)
	row.name = "DangerRow"
	var pad_l := Control.new()
	pad_l.custom_minimum_size.x = BAND_INSET
	row.add_child(pad_l)
	var band := Band.new()
	band.name = "Band"
	band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(band)
	var pad_r := Control.new()
	pad_r.custom_minimum_size.x = BAND_INSET
	row.add_child(pad_r)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(BAND_BAR + 4.0, BAND_ICON + 12.0)
	band.add_child(gap)
	_band_icon = TextureRect.new()
	_band_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_band_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_band_icon.custom_minimum_size = Vector2(BAND_ICON, BAND_ICON)
	_band_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	band.add_child(_band_icon)
	_danger = UiTheme.make_label("", NOTE_FONT, LOSS_RED)
	_danger.name = "Danger"
	_danger.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	var words := HFlowContainer.new()     # 名字后面跟「炼了拿不回来」；放不下整句挪到下一行，不从字中间断
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	band.add_child(words)
	_danger.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_child(_danger)
	var tail := UiTheme.make_label(UiText.t("alchemy.guard_tail"), NOTE_FONT - 1, LOSS_RED)
	tail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_child(tail)
	var end := Control.new()
	end.custom_minimum_size.x = 4.0
	band.add_child(end)
	_band = row
	return row


## 警告带的底：淡红底 + 左边红竖线
class Band extends HBoxContainer:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), BAND_BG)
		draw_rect(Rect2(Vector2.ZERO, Vector2(BAND_BAR, size.y)), LOSS_RED)


static func dust_icon(side: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiTheme.art(ART + "dust")
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(side, side)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.tooltip_text = UiText.t("alchemy.dust")
	return r


func _pic(file: String, rect: Rect2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiTheme.art(ART + file)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = rect.position
	r.size = rect.size
	return r


## 勾选模式里能勾哪件（[method WarehousePages.set_select_mode] 的规矩）：第七节起锁定的以外都能
static func rule() -> Callable:
	return func(it: ItemInstance) -> bool: return Alchemy.can_dissolve(it)


## 第七节：一键炼金看的范围 = 仓库里合筛选的
func auto_pool() -> Array:
	return flow.meta.warehouse.items().filter(func(it) -> bool: return shelf.matches(it as ItemInstance))


## 第七节：一键炼金会勾哪些、跳过几件（[method Alchemy.auto_picks]）；没选标签 = 不圈范围，什么都不勾
func auto_plan() -> Dictionary:
	if shelf.filter_tag == &"":
		return {"uids": [], "skipped": 0, "why": {}}
	return Alchemy.auto_picks(flow.meta, auto_pool())


## 勾着的正好是一键炼金那一批
func auto_selected(plan: Dictionary = {}) -> bool:
	var p := plan if not plan.is_empty() else auto_plan()
	var uids: Array = p["uids"]
	return not uids.is_empty() and uids.size() == shelf.selected.size() and uids.all(func(u) -> bool: return shelf.selected.has(int(u)))


## 【一键炼金】：勾上这一批（预览在纸条上，再按【炼化】）；已经勾着这一批再点 = 全不选
func one_click() -> void:
	var plan := auto_plan()
	if auto_selected(plan):
		shelf.clear_selection()
	else:
		shelf.select_only(plan["uids"])


func _refresh_tags() -> void:
	if tag_pick == null or flow == null or flow.meta == null:
		return
	WarehouseTools.fill_tags(tag_pick, flow.meta.sell_tags())
	WarehouseTools.sync_picks(shelf, tag_pick, rarity_pick)


## 【炼化】：第一下变「再点一次」，再点才炼。返回 {"count", "dust"}（只点了第一下 = 空）
func press_go() -> Dictionary:
	if shelf.selected.is_empty():
		return {}
	if confirm_left <= 0.0:
		confirm_left = CONFIRM_SEC
		go_btn.text = UiText.t("act.confirm")
		var risky := Alchemy.guarded_of(flow.meta, shelf.selected.keys())
		if not risky.is_empty():
			said.emit(_danger_text(risky), true)     # 第七节：危险确认 —— 第一下再说一遍拿不回来
		return {}
	_reset_confirm()
	var got := flow.dissolve_items(shelf.selected.keys())
	shelf.clear_selection()
	if int(got["count"]) > 0:
		said.emit(UiText.t("alchemy.done") % [int(got["count"]), int(got["dust"])], false)
	refresh()
	changed.emit()
	return got


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if confirm_left <= 0.0:
		return
	confirm_left -= delta
	if confirm_left <= 0.0:
		_reset_confirm()


func _reset_confirm() -> void:
	confirm_left = 0.0
	if go_btn != null:
		go_btn.text = UiText.t("alchemy.go")


func preview() -> Dictionary:
	return flow.alchemy_preview(shelf.selected.keys())


## 勾了的几件按勾的先后轮流分到三个角：角号 → [ItemInstance]（后勾的在后）
func corners() -> Array:
	var out: Array = [[], [], []]
	var k := 0
	for uid in shelf.selected:
		var it := flow.meta.warehouse.get_item(int(uid))
		if it == null:
			continue
		(out[k % 3] as Array).append(it)
		k += 1
	return out


func refresh() -> void:
	if flow == null or flow.meta == null or _have == null:
		return
	_have.text = str(flow.meta.dust)
	var groups := corners()
	var hand_in := Alchemy.hand_in_uids(flow.meta)
	for i in _nodes.size():
		_fill_node(_nodes[i], groups[i] as Array, hand_in)
	var p := preview()
	_center.visible = int(p["count"]) > 0
	_gain.text = "+%d" % int(p["dust"])
	_funds.amount = int(p["funds"])
	_loss.text = UiText.t("alchemy.loss") % roundi(Alchemy.loss(flow.meta) * 100.0)
	_loss.tooltip_text = UiText.t("alchemy.loss_tip")
	var risky := Alchemy.guarded_of(flow.meta, shelf.selected.keys())
	_danger.text = _danger_names(risky)
	_band_icon.texture = ShelfView.item_art((risky[0] as ItemInstance).def) if not risky.is_empty() else null
	_band.visible = not risky.is_empty()
	var plan := auto_plan()
	var on := auto_selected(plan)
	auto_btn.text = UiText.t("sell.select_none" if on else "alchemy.auto")
	auto_btn.disabled = not on and (plan["uids"] as Array).is_empty()
	_skip.text = UiText.t("alchemy.skipped") % int(plan["skipped"]) if int(plan["skipped"]) > 0 else ""
	_skip.visible = _skip.text != ""
	WarehouseTools.sync_picks(shelf, tag_pick, rarity_pick)
	go_btn.disabled = shelf.selected.is_empty()
	if go_btn.disabled:
		_reset_confirm()
	_slip.size = Vector2(W - 40.0, 0.0)     # 纸条照内容收高


## 一个角：最新的一件在最上，前面的往左上各错 [constant PEEK]（最多画三件）；两件以上角下写 ×n。
## 358 A：其中有一件拿不回来，角上（底图之上、道具之下）套红圈
func _fill_node(n: Control, items: Array, hand_in: Dictionary = {}) -> void:
	for c in n.get_children().slice(1):
		n.remove_child(c)
		c.queue_free()
	if items.any(func(it) -> bool: return Alchemy.guarded(flow.meta, it as ItemInstance, null, hand_in)):
		var ring := _pic("guard_ring", Rect2(Vector2(NODE - RING, NODE - RING) * 0.5, Vector2(RING, RING)))
		ring.name = "GuardRing"
		n.add_child(ring)
	var shown := items.slice(maxi(0, items.size() - 3))
	for j in shown.size():
		var it := shown[j] as ItemInstance
		var back := shown.size() - 1 - j
		var r := TextureRect.new()
		r.texture = ShelfView.item_art(it.def)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.position = Vector2(NODE - ITEM, NODE - ITEM) * 0.5 - Vector2(PEEK, PEEK) * back
		r.size = Vector2(ITEM, ITEM)
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		r.tooltip_text = "%s · %d" % [Names.of(it.def), Alchemy.dust_value_of(it)]
		if back > 0:
			r.modulate = Color(0.8, 0.8, 0.8)
		n.add_child(r)
	if items.size() >= 2:
		var l := UiTheme.make_label("×%d" % items.size(), 16, LIGHT)
		l.name = "Count"
		l.set_meta(&"exempt_bare_text", true)     # 写在墙上的小字（版面如此）
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(0, NODE + 2.0)
		l.size = Vector2(NODE, 20)
		n.add_child(l)


## 「A ×2、B、C 等 N 件 炼了拿不回来」（同名的合成一条）
static func _danger_text(risky: Array) -> String:
	if risky.is_empty():
		return ""
	return UiText.t("alchemy.guard") % _danger_names(risky)


## 「A ×2、B、C 等 N 件」
static func _danger_names(risky: Array) -> String:
	if risky.is_empty():
		return ""
	var order: Array[String] = []     # 同名的合成「名字 ×n」
	var count := {}
	for it in risky:
		var n := Names.of((it as ItemInstance).def)
		if not count.has(n):
			order.append(n)
		count[n] = int(count.get(n, 0)) + 1
	var names := PackedStringArray()
	for i in mini(3, order.size()):
		names.append(order[i] + (" ×%d" % int(count[order[i]]) if int(count[order[i]]) > 1 else ""))
	var who := UiText.t("tip.list_sep").join(names)
	if order.size() > 3:
		who += UiText.t("alchemy.guard_more") % risky.size()
	return who
