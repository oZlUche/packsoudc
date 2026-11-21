## 342 B3：后勤「苗圃」页（[Nursery]）—— 每畦一张羊皮纸条：空地列能种的作物（种苗成本、收什么、几局成熟），
## 长着的写还差几局，熟了有【收获】（仓库放不下就留在地里）。
## 占位排版（浅底墨字，[constant UiTheme.PANEL_PARCHMENT]），样张请 UI设计 出
extends VBoxContainer

signal changed()
## 有话要说（收不了、种不了的原因；收了什么）：[param warn] = 是不是要紧的
signal said(text: String, warn: bool)

const CARD_W := 640.0
const PAD_X := 26
const PAD_Y := 14
const INK := Color("2e2219")
const INK_DIM := Color("5a4a3a")

var flow: GameFlow = null
var _cards: VBoxContainer = null


func setup(p_flow: GameFlow) -> void:
	flow = p_flow
	name = "NurseryPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards = UiTheme.vbox(14)
	add_child(_cards)
	refresh()


func refresh() -> void:
	if _cards == null or flow == null or flow.meta == null:
		return
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	for i in flow.meta.nursery.plots.size():
		_cards.add_child(_plot_card(i))


## 作物名
static func crop_name(crop: StringName) -> String:
	return UiText.t("nursery.crop_" + String(crop))


## 一种作物的一行说明：种苗成本 → 收什么 × 几，几局
func crop_text(crop: StringName) -> String:
	var spec: Dictionary = Nursery.CROPS.get(crop, {})
	var product := flow.items.get_def(StringName(spec.get("product", &""))) if flow.items != null else null
	var seed_parts: Array[String] = []
	var seed_: Dictionary = spec.get("seed", {})
	for id in seed_:
		var d := flow.items.get_def(StringName(id)) if flow.items != null else null
		seed_parts.append("%s ×%d" % [Names.of(d) if d != null else String(id), int(seed_[id])])
	var cost := UiText.t("nursery.seed_free") if seed_parts.is_empty() else ", ".join(seed_parts)
	return UiText.t("nursery.crop_line") % [cost, Names.of(product) if product != null else "?", int(spec.get("count", 0)), int(spec.get("runs", 0))]


func _plot_card(i: int) -> PanelContainer:
	var p := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, PAD_X, PAD_Y, PAD_X, PAD_Y)
	UiTheme.set_tone(p, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	p.custom_minimum_size.x = CARD_W
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.name = "Plot_%d" % i
	var col := UiTheme.vbox(8)
	p.add_child(col)
	var plot := flow.meta.nursery.plot(i)
	var crop := StringName(String(plot.get("crop", "")))
	if crop == &"":
		col.add_child(UiTheme.make_label(UiText.t("nursery.empty"), 20, INK))
		for c in Nursery.ORDER:
			var row := UiTheme.hbox(12)
			col.add_child(row)
			row.add_child(UiTheme.make_wrapped("%s：%s" % [crop_name(c), crop_text(c)], 16, INK, CARD_W - 2.0 * PAD_X - 140.0))
			var cc := c
			var b := ScrollKey.make(UiText.t("nursery.sow"), func(): sow(i, cc))
			b.name = "Sow_%d_%s" % [i, String(c)]
			var why := Nursery.why_not_sow(flow.meta, i, c)
			b.disabled = why != ""
			if why != "":
				b.tooltip_text = UiText.t("nursery.why_" + why)
			row.add_child(b)
		return p
	col.add_child(UiTheme.make_label(crop_name(crop), 20, INK))
	if flow.meta.nursery.is_ripe(i):
		var b := ScrollKey.make(UiText.t("nursery.harvest"), func(): harvest(i))
		b.name = "Harvest_%d" % i
		col.add_child(b)
	else:
		col.add_child(UiTheme.make_label(UiText.t("nursery.left") % int(plot.get("left", 0)), 16, INK_DIM))
	return p


func sow(i: int, crop: StringName) -> String:
	var why := flow.sow_crop(i, crop)
	if why != "":
		said.emit(UiText.t("nursery.why_" + why), true)
	refresh()
	changed.emit()
	return why


func harvest(i: int) -> Dictionary:
	var got := flow.harvest_crop(i)
	if String(got["why"]) != "":
		said.emit(UiText.t("nursery.why_" + String(got["why"])), true)
	refresh()
	changed.emit()
	return got
