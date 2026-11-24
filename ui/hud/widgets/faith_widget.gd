## 150：信仰 + 阶（087 / 082；372 起经验值在等级管上）；停上去开悬浮窗（具体效果、经验值怎么涨），用所在屏的那个悬浮窗。
## 166（作者定）：有信仰时画这个信仰的徽记（`assets/ui/faith/<id>.png`，32 px）+ 阶的小字；**没信仰时留一个空槽**（固定宽、不写字）。
## 缺图时退回原来那行字（「信仰：暴力之神　…」）
## 信仰重构 A：三态 —— 不奉神（空槽）/ 联系正常（徽记 + 阶）/ 联系中断（选的那位神的徽记压暗 + 「联系中断」，悬浮窗写原因）
## 382 / 385 / 388：徽记右边一排神恩小图标 —— 拿到的质变牌按先后排，30 一格，超过 9 个写「+N」；停在一枚上看那张牌
extends HudWidget

const FAVOR := 30.0
const FAVOR_MAX := 9

const ICON := 32.0
const ART_DIR := "res://assets/ui/faith/"

var icon: HudIcon
## 388：神恩小图标那一排
var favor: Control
var _favor_ids: Array[StringName] = []
var _favor_hover := -1


func _init() -> void:
	super()
	icon = HudIcon.make(ICON)
	_prepend_icon(icon)
	favor = Control.new()
	favor.name = "Favor"
	favor.mouse_filter = Control.MOUSE_FILTER_STOP
	favor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	favor.draw.connect(_draw_favor)
	favor.gui_input.connect(_favor_input)
	favor.mouse_exited.connect(func():
		_favor_hover = -1
		var tip: HoverTip = screen.get("_tip") if screen != null else null
		if tip != null:
			tip.release())
	_text.get_parent().add_child(favor)


func title() -> String:
	return "信仰"


func watch() -> Array[Signal]:
	var out: Array[Signal] = [run.faith_changed]
	if run.faith_power != null:
		out.append(run.faith_power.changed)
	var lv := LevelModule.of(run)
	if lv != null:
		out.append(lv.level_changed)     # 388：拿了质变牌，小图标跟着
	return out


## 选了神但联系中断
func _broken() -> bool:
	return run != null and run.selected_faith != &"" and run.active_faith_id() == &""


## 这个信仰的徽记；没有图 null
static func art_of(faith_id: StringName) -> Texture2D:
	return HudIcon.load_art(ART_DIR + String(faith_id) + ".png") if faith_id != &"" else null


func text_of() -> String:
	if _broken():
		return UiText.t("faith.broken")
	var id_ := run.active_faith_id()
	if id_ == &"":
		return ""     # 没信仰：空槽
	var line := run.faith_power.line() if run.faith_power != null else ""
	if art_of(id_) == null:
		return run.faith_line() + (UiText.t("tip.gap") + line if line != "" else "")
	var def := run.active_faith()
	if def == null or run.faith_power == null:
		return ""
	return text_at(run.faith_power.points_of(id_))


## 231 补充二：滚数（有徽记那种写法才滚）
func roll_value() -> int:
	var id_ := run.active_faith_id()
	if id_ == &"" or art_of(id_) == null or run.active_faith() == null or run.faith_power == null:
		return -1
	return run.faith_power.points_of(id_)


## 372：只写阶（经验值和等级在顶端栏下面那根管子上）
func text_at(p: int) -> String:
	var def := run.active_faith()
	if def == null:
		return text_of()
	return UiText.t("hud.faith_level") % def.tier_of(p)


func _paint() -> void:
	icon.texture = art_of(run.selected_faith) if run != null else null
	icon.visible = icon.texture != null or run == null or run.selected_faith == &""     # 缺图退回文字时不占那一格
	icon.modulate = Color(1, 1, 1, 0.4) if _broken() else Color.WHITE
	_sync_empty()
	_sync_favor()


## 388：拿到的质变牌（联系正常才画）
func favor_ids() -> Array[StringName]:
	return _favor_ids


func _sync_favor() -> void:
	_favor_ids.clear()
	var lv := LevelModule.of(run) if run != null else null
	if lv != null and run.active_faith_id() != &"":
		for q in lv.quals():
			_favor_ids.append(StringName(q["shown"]))
	var n := mini(_favor_ids.size(), FAVOR_MAX)
	var w := n * FAVOR + (FAVOR if _favor_ids.size() > FAVOR_MAX else 0.0)
	favor.custom_minimum_size = Vector2(w, FAVOR if n > 0 else 0.0)
	favor.visible = n > 0
	favor.queue_redraw()


## 超过 [constant FAVOR_MAX] 个时最后一格写「+N」
func favor_more_text() -> String:
	return "+%d" % (_favor_ids.size() - FAVOR_MAX) if _favor_ids.size() > FAVOR_MAX else ""


func _draw_favor() -> void:
	var lv := LevelModule.of(run) if run != null else null
	if lv == null:
		return
	for i in mini(_favor_ids.size(), FAVOR_MAX):
		var r := Rect2(Vector2(i * FAVOR, 0), Vector2(FAVOR, FAVOR)).grow(-2.0)
		favor.draw_rect(r, UiTheme.STONE_BRASS, false, 1.0)
		var tex := LevelPickPanel.card_icon(lv, _favor_ids[i])
		if tex != null:
			favor.draw_texture_rect(tex, r.grow(-3.0), false, UiTheme.STONE_INK)
	var more := favor_more_text()
	if more != "":
		var f := UiPalette.cjk_font_bold()
		var x := FAVOR_MAX * FAVOR
		var w := f.get_string_size(more, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		favor.draw_string(f, Vector2(x + (FAVOR - w) * 0.5, FAVOR * 0.5 + 5.0), more, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.STONE_INK)


func _favor_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm == null or editing:
		return
	var i := int(mm.position.x / FAVOR)
	if i >= mini(_favor_ids.size(), FAVOR_MAX):
		i = -1
	if i == _favor_hover:
		return
	_favor_hover = i
	var tip: HoverTip = screen.get("_tip") if screen != null else null
	var lv := LevelModule.of(run) if run != null else null
	if tip == null or lv == null:
		return
	if i < 0:
		tip.release()
		return
	var def: RunBuffDef = run.buff_defs.get(_favor_ids[i], null)
	tip.show_text((Names.of(def) if def != null else String(_favor_ids[i])) + "\n" + Glossary.bonus_numbers(lv.card_text(_favor_ids[i])),
		favor.global_position + Vector2(i * FAVOR, FAVOR + 6.0))


## 没信仰：位置留着，底也不画（真的空着；摆读数时照常画出来好拖）
func _sync_empty() -> void:
	self_modulate.a = 0.0 if not editing and run != null and run.selected_faith == &"" else 1.0


## 没信仰也占着位置（一个空槽），不藏
func _sync_visible() -> void:
	visible = editing or (shown and run != null)


func _idle_mouse_filter() -> Control.MouseFilter:
	return Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_filter = _idle_mouse_filter()
	mouse_entered.connect(func():
		var tip: HoverTip = screen.get("_tip") if screen != null else null
		if tip != null and run != null and not editing:
			tip.show_faith(FaithTooltip.describe_full(run.selected_faith_def(), run.faith_power, run.board, run.items, run.faith_connection()), global_position + Vector2(0, size.y)))     # 188
	mouse_exited.connect(func():
		var tip: HoverTip = screen.get("_tip") if screen != null else null
		if tip != null:
			tip.release())     # 作者 2026-10-17：钉住了就留着
