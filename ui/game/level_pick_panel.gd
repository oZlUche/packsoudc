## 372：升级选牌 —— 地图屏上叠一层（不是单独一屏）：三张牌挑一张，下面「刷新」「删除」两个键写着还剩几次。
## 挑完还有待选（一次升了几级、以人为本多给的一次）就接着出下一批；都挑完自己收起。
## 牌面是作者定的 A 羊皮纸（`assets/ui/level/`）：上沿正中压一条类别缎带，圆章里放牌的图标，下面牌名、效果，底部写拿了是第几层
class_name LevelPickPanel
extends VBoxContainer

signal done()

const CARD_W := 220.0
const CARD_H := 240.0
const ART_CARD := "level/card_parchment"
const ART_MEDALLION := "level/medallion"
## 缎带 72 × 24，往上探出牌面 12
const RIBBON := Vector2(72, 24)
const RIBBON_OUT := 12.0
const MEDALLION := 72.0
const MEDALLION_TOP := 28.0
const ICON := 50.0
const LAYER_BOTTOM := 12.0
const LAYER_INK := Color("7a5a30")
const KEY_SIZE := Vector2(120, 40)
const KEY_LINE := Color("b89a6a")
const KEY_HOVER := Color("7a5a30")

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
	_reroll = _key(reroll)
	_reroll.name = "Reroll"
	keys.add_child(_reroll)
	_remove = _key(toggle_remove)
	_remove.name = "Remove"
	keys.add_child(_remove)
	rebuild()


func rebuild() -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	if level == null or level.pending() <= 0:
		return
	var cur := level.current_pick()
	_title.text = UiText.t("level.pick_of") % int(cur.get("level", level.level()))
	_title.visible = level.pending() > 1 or bool(cur.get("extra", false))     # 窗的标题条写着升到几级；只欠一次时不重复写
	var left := level.pending()
	var notes: Array[String] = []
	if left > 1:
		notes.append(UiText.t("level.left") % left)
	if bool(cur.get("extra", false)):
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
	_remove.add_theme_color_override("font_color", UiTheme.INK if removing else UiTheme.INK_SOFT)


func _card(i: int, cid: StringName) -> Control:
	var btn := Button.new()
	btn.name = "Card%d" % i
	btn.custom_minimum_size = Vector2(CARD_W, CARD_H)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(choose.bind(i))
	var face := PanelContainer.new()
	face.name = "Face"
	UiTheme.box_panel(face, UiTheme.art_box(ART_CARD))
	UiTheme.set_tone(face, UiTheme.TONE_LIGHT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(face)
	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(inner)
	# 圆章（图标放在里面）
	var medal := TextureRect.new()
	medal.name = "Medallion"
	medal.texture = UiTheme.art_cached(ART_MEDALLION)
	medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medal.position = Vector2((CARD_W - MEDALLION) / 2.0, MEDALLION_TOP)
	medal.size = Vector2.ONE * MEDALLION
	btn.add_child(medal)
	var tex := _icon_of(cid)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = UiTheme.INK
		icon.position = Vector2.ONE * (MEDALLION - ICON) / 2.0
		icon.size = Vector2.ONE * ICON
		medal.add_child(icon)
	# 牌名、效果
	var col := UiTheme.vbox(6)
	col.position = Vector2(14, MEDALLION_TOP + MEDALLION + 8)
	col.size = Vector2(CARD_W - 28, 0)
	btn.add_child(col)
	UiTheme.set_tone(col, UiTheme.TONE_LIGHT)
	var def: RunBuffDef = level.run_state().buff_defs.get(cid, null) if level.run_state() != null else null
	var title := UiTheme.make_display(Names.of(def) if def != null else String(cid), 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var body := UiTheme.rich_block(CARD_W - 28, 15, "[center]%s[/center]" % Glossary.bonus_numbers(level.card_text(cid)))
	col.add_child(body)
	# 底部：拿了是第几层
	var layer := UiTheme.make_label(UiText.t("level.layer") % (level.count_of(cid) + 1), 13, LAYER_INK)
	layer.name = "Layer"
	layer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.position = Vector2(0, CARD_H - LAYER_BOTTOM - 18)
	layer.size = Vector2(CARD_W, 18)
	btn.add_child(layer)
	# 类别缎带：压在上沿正中，往上探出
	var kind := String(level.rules().kind_of(cid))
	var ribbon := PanelContainer.new()
	ribbon.name = "Ribbon"
	UiTheme.box_panel(ribbon, UiTheme.art_box("level/ribbon_" + _ribbon_of(kind)))
	ribbon.position = Vector2((CARD_W - RIBBON.x) / 2.0, -RIBBON_OUT)
	ribbon.custom_minimum_size = RIBBON
	ribbon.size = RIBBON
	var tag := UiTheme.make_label(UiText.t("level.kind_" + kind), 14, Color.WHITE)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if tag.has_meta(&"dark_color"):
		tag.remove_meta(&"dark_color")     # 缎带是深底：白字，不跟选牌窗的浅底换墨色
	tag.add_theme_color_override("font_color", Color.WHITE)
	ribbon.add_child(tag)
	btn.add_child(ribbon)
	for c in [medal, col, layer, ribbon, tag, title, body]:
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return btn


## 类别 → 缎带图（属性 / 武器 / 探索）
static func _ribbon_of(kind: String) -> String:
	match kind:
		"weapon":
			return "weapon"
		"explore":
			return "explore"
	return "attr"


## 牌的图标：先用它第一条属性加成的那根轴的图（`effects/axis_<stat>_pos`）；没有就空着，圆章照画
static func _icon_of_def(def: RunBuffDef) -> Texture2D:
	if def == null:
		return null
	for e in def.effects:
		if e is StatBonus:
			var path := "effects/axis_%s_pos" % String((e as StatBonus).stat)
			if UiTheme.has_art(path):
				return UiTheme.art_cached(path)
	return null


func _icon_of(cid: StringName) -> Texture2D:
	return _icon_of_def(level.run_state().buff_defs.get(cid, null) if level.run_state() != null else null)


## 平的浅底按钮（作者 21:17：刷新、删除两个键用平的浅底）
func _key(handler: Callable) -> Button:
	var b := UiTheme.flat_key("", UiTheme.PAPER, KEY_LINE, KEY_HOVER, UiTheme.INK, KEY_SIZE, 15)
	var off := StyleBoxFlat.new()
	off.bg_color = UiTheme.PAPER.darkened(0.12)
	off.border_color = KEY_LINE
	off.set_border_width_all(1)
	off.set_corner_radius_all(3)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_color_override("font_disabled_color", UiTheme.INK_SOFT)
	b.pressed.connect(handler)
	return b


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
