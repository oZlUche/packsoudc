## 372：升级选牌 —— 地图屏上叠一层（不是单独一屏）：三张牌挑一张，下面「刷新」「删除」两个键写着还剩几次。
## 挑完还有待选（一次升了几级、以人为本多给的一次）就接着出下一批；都挑完自己收起。
## 牌面是占位画法（深色分区 + 类别、名字、效果、已有几张），样张定了换
class_name LevelPickPanel
extends VBoxContainer

signal done()

const CARD_W := 220.0
const CARD_H := 240.0

var level: LevelModule = null
## 点了「删除」，等玩家点一张
var removing := false

var _title: Label
var _cards: HBoxContainer
var _reroll: Button
var _remove: Button
var _note: Label


func _init(p_level: LevelModule) -> void:
	level = p_level
	add_theme_constant_override("separation", 14)
	_title = UiTheme.make_label("", 22)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_note = UiTheme.make_label("", 15, UiPalette.DIM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_note)
	_cards = UiTheme.hbox(16)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_cards)
	var keys := UiTheme.hbox(16)
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(keys)
	_reroll = UiTheme.make_button("", reroll)
	_reroll.name = "Reroll"
	keys.add_child(_reroll)
	_remove = UiTheme.make_button("", toggle_remove)
	_remove.name = "Remove"
	keys.add_child(_remove)
	rebuild()


func rebuild() -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	if level == null or level.pending() <= 0:
		return
	_title.text = UiText.t("level.title") % level.level()
	var left := level.pending()
	var notes: Array[String] = []
	if left > 1:
		notes.append(UiText.t("level.left") % left)
	if level.is_humanist() and level.bonus_picks > 0 and left <= level.bonus_picks:
		notes.append(UiText.t("level.extra"))
	if removing:
		notes.append(UiText.t("level.remove_tip"))
	_note.text = UiText.t("tip.gap").join(notes)
	_note.visible = not notes.is_empty()
	var ids := level.offer()
	for i in ids.size():
		_cards.add_child(_card(i, ids[i]))
	_reroll.text = UiText.t("level.reroll") % level.rerolls_left()
	_reroll.disabled = level.rerolls_left() <= 0
	_reroll.tooltip_text = UiText.t("level.reroll_tip") if level.rerolls_left() > 0 else UiText.t("level.none_left")
	_remove.text = UiText.t("level.remove") % level.removals_left()
	_remove.disabled = level.removals_left() <= 0
	_remove.tooltip_text = UiText.t("level.remove_tip") if level.removals_left() > 0 else UiText.t("level.none_left")
	UiTheme.mark(_remove, removing)


func _card(i: int, cid: StringName) -> Control:
	var btn := Button.new()
	btn.name = "Card%d" % i
	btn.custom_minimum_size = Vector2(CARD_W, CARD_H)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(choose.bind(i))
	var face := UiTheme.panel(PanelContainer.new(), 14, UiTheme.PANEL_DARK)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(face)
	var col := UiTheme.vbox(10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(col)
	var kind := UiTheme.make_label(UiText.t("level.kind_" + String(level.rules().kind_of(cid))), 14, UiPalette.DIM)
	col.add_child(kind)
	var def: RunBuffDef = level.run_state().buff_defs.get(cid, null) if level.run_state() != null else null
	var title := UiTheme.make_label(Names.of(def) if def != null else String(cid), 22)
	col.add_child(title)
	var body := UiTheme.rich_block(CARD_W - 28, 16, Glossary.bonus_numbers(level.card_text(cid)))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(body)
	var have := level.count_of(cid)
	if have > 0:
		col.add_child(UiTheme.make_label(UiText.t("level.have") % have, 14, UiPalette.DIM))
	for c in col.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return btn


## 点第 [param i] 张：删除模式下删掉它，否则拿它
func choose(i: int) -> void:
	if level == null:
		return
	if removing:
		removing = false
		level.remove(i)
	else:
		level.pick(i)
	_after()


func reroll() -> void:
	if level != null and level.reroll():
		removing = false
		_after()


func toggle_remove() -> void:
	if level == null or level.removals_left() <= 0:
		return
	removing = not removing
	rebuild()


func _after() -> void:
	if level.pending() <= 0:
		done.emit()
		return
	rebuild()


## 测试读：现在摆着的几张
func offered() -> Array[StringName]:
	return level.offer() if level != null else ([] as Array[StringName])
