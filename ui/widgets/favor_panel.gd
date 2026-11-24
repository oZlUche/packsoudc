## 380 / 382 / 388（作者定 A：加神恩区）：状态界面右边一栏「神恩」—— 奉神时才出现。
##
## 从上往下：神像行（徽记、神名、核心机制一句话）；「质变 N」和拿到的质变牌（按拿的先后，56 一格、四格一行，升级过的角上一个「+」，
## 作者 11-22 22:53：不画空槽、不写上限）；「神的牌」和拿到的这位神的基础牌（40 一格、八格一行，角上金色层数）。
## 底是深石板（报告 385）；停在一格上开悬浮窗：牌名和效果。数据读 [method LevelModule.quals] / [method LevelModule.god_cards]
class_name FavorPanel
extends Control

const W := 300.0
const PAD := 14.0
const EMBLEM := 44.0
const QUAL := 56.0
const QUAL_COLS := 4
const CARD := 40.0
const CARD_COLS := 6
const GAP := 8.0
const HEAD_PX := 13
const NAME_PX := 18
const LINE_PX := 12
const BADGE := 16.0

## 悬浮窗（宿主给；没有就不开）
var tip: HoverTip = null
var level: LevelModule = null
var faith: FaithDef = null
## 每一格：{rect, id, count, qual, upgraded}
var _slots: Array[Dictionary] = []
var _quals_top := 0.0
var _cards_top := 0.0
var _core_lines: Array[String] = []
var _hover := -1


func _init() -> void:
	custom_minimum_size = Vector2(W, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UiTheme.set_tone(self, UiTheme.TONE_DARK)
	mouse_exited.connect(_unhover)


## 按这一局重算（开窗、拿了牌、改信都叫它）。奉的神没有 = 藏起来
func refresh(run: RunState) -> void:
	level = LevelModule.of(run)
	faith = run.active_faith() if run != null else null
	visible = faith != null and level != null
	_slots.clear()
	_core_lines.clear()
	if not visible:
		return
	var regular := UiPalette.cjk_font()
	var y := PAD + EMBLEM + 6.0
	var core := faith.core_text()
	if core != "":
		_core_lines = CharacterCard.wrap_lines(core, regular, LINE_PX, W - PAD * 2.0, 3)
		y += _core_lines.size() * (LINE_PX + 4.0) + 4.0
	_quals_top = y + 6.0
	y = _quals_top + 20.0
	var qs := level.quals()
	for i in qs.size():
		var q: Dictionary = qs[i]
		var at := Vector2(PAD + (i % QUAL_COLS) * (QUAL + GAP), y + floorf(float(i) / QUAL_COLS) * (QUAL + GAP))
		_slots.append({"rect": Rect2(at, Vector2(QUAL, QUAL)), "id": q["shown"], "count": 1, "qual": true, "upgraded": q["upgraded"]})
	var qual_rows := ceili(float(qs.size()) / QUAL_COLS)
	if qual_rows > 0:
		y += qual_rows * (QUAL + GAP)
	else:
		y += 22.0     # 「还没有质变牌」一行
	var cs := level.god_cards()
	_cards_top = y + 6.0
	y = _cards_top + 20.0
	for i in cs.size():
		var c: Dictionary = cs[i]
		var at := Vector2(PAD + (i % CARD_COLS) * (CARD + GAP), y + floorf(float(i) / CARD_COLS) * (CARD + GAP))
		_slots.append({"rect": Rect2(at, Vector2(CARD, CARD)), "id": c["id"], "count": int(c["count"]), "qual": false, "upgraded": false})
	y += ceili(float(cs.size()) / CARD_COLS) * (CARD + GAP)
	custom_minimum_size = Vector2(W, maxf(y + PAD, size.y))
	queue_redraw()


## 测试看：几格（质变 + 神的牌）
func slot_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for s in _slots:
		out.append(StringName(s["id"]))
	return out


func slot_rect(i: int) -> Rect2:
	return _slots[i]["rect"] if i >= 0 and i < _slots.size() else Rect2()


## 第 i 格的悬浮窗：牌名、效果
func tip_text(i: int) -> String:
	if i < 0 or i >= _slots.size() or level == null:
		return ""
	var cid := StringName(_slots[i]["id"])
	var def: RunBuffDef = level.run_state().buff_defs.get(cid, null)
	var head := Names.of(def) if def != null else String(cid)
	if int(_slots[i]["count"]) > 1:
		head += "  ×%d" % int(_slots[i]["count"])
	return head + "\n" + Glossary.bonus_numbers(level.card_text(cid))


func slot_at(local: Vector2) -> int:
	for i in _slots.size():
		if (_slots[i]["rect"] as Rect2).has_point(local):
			return i
	return -1


func _draw() -> void:
	var slate := UiTheme.art_box(UiTheme.ART_STONE_SLATE)
	if slate != null:
		draw_style_box(slate, Rect2(Vector2.ZERO, size))
	if faith == null or level == null:
		return
	var regular := UiPalette.cjk_font()
	var bold := UiPalette.cjk_font_bold()
	var fg := UiPalette.FG
	var dim := Color(fg, 0.7)
	# 神像行
	var emblem := UiTheme.art_cached("faith/" + String(faith.id))
	if emblem != null:
		draw_texture_rect(emblem, Rect2(PAD, PAD, EMBLEM, EMBLEM), false)
	draw_arc(Vector2(PAD, PAD) + Vector2.ONE * EMBLEM * 0.5, EMBLEM * 0.5 + 1.0, 0.0, TAU, 40, UiTheme.STONE_BRASS, 1.5, true)
	draw_string(bold, Vector2(PAD + EMBLEM + 10.0, PAD + EMBLEM * 0.5 + NAME_PX * 0.35), Names.of(faith), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_PX, fg)
	var y := PAD + EMBLEM + 6.0
	for line in _core_lines:
		y += LINE_PX + 4.0
		draw_string(regular, Vector2(PAD, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_PX, dim)
	# 质变
	var nq := level.quals().size()
	_head(UiText.t("favor.quals") % nq, _quals_top, bold)
	if nq == 0:
		draw_string(regular, Vector2(PAD, _quals_top + 36.0), UiText.t("favor.none"), HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_PX, dim)
	if not level.god_cards().is_empty():
		_head(UiText.t("favor.cards"), _cards_top, bold)
	for i in _slots.size():
		_draw_slot(i, bold)


func _head(text: String, top: float, f: Font) -> void:
	draw_string(f, Vector2(PAD, top + 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, HEAD_PX, Color(UiPalette.FG, 0.7))
	draw_line(Vector2(PAD, top + 18.5), Vector2(W - PAD, top + 18.5), Color(UiTheme.STONE_BRASS, 0.5), 1.0)


func _draw_slot(i: int, f: Font) -> void:
	var s: Dictionary = _slots[i]
	var r: Rect2 = s["rect"]
	var well := UiTheme.art_box(UiTheme.ART_HUD_WELL)
	if well != null:
		draw_style_box(well, r)
	if i == _hover:
		draw_rect(r.grow(-2.0), Color(1, 1, 1, 0.18))
	draw_rect(r, UiTheme.STONE_BRASS, false, 1.0)
	var tex := LevelPickPanel.card_icon(level, StringName(s["id"]))
	if tex != null:
		var side := r.size.x * 0.72
		draw_texture_rect(tex, Rect2(r.get_center() - Vector2.ONE * side * 0.5, Vector2.ONE * side), false, UiTheme.STONE_INK)
	var corner := r.position + Vector2(r.size.x - 3.0, 3.0)
	if bool(s["upgraded"]):
		_badge(corner, "+", f)
	elif int(s["count"]) > 1:
		_badge(corner, str(int(s["count"])), f)


## 角上一枚黄铜小圆，写层数或「+」
func _badge(center: Vector2, text: String, f: Font) -> void:
	draw_circle(center, BADGE * 0.5, UiTheme.STONE_BRASS)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(f, center + Vector2(-w * 0.5, 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiTheme.STONE_INK)


func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm == null:
		return
	var at := slot_at(mm.position)
	if at == _hover:
		return
	_hover = at
	queue_redraw()
	if tip == null:
		return
	if at < 0:
		tip.release()
	else:
		tip.show_text(tip_text(at), global_position + Vector2(size.x + 8.0, mm.position.y))


func _unhover() -> void:
	_hover = -1
	queue_redraw()
	if tip != null:
		tip.release()
