## 224（作者定）：结算第一页的账单 —— 十一行 + 合计（作者 16:00 去掉了表头；补充二 击败的敌人 / 精英 / 首领分三行），三栏：项目 | 数量 | 经验（经验先占位写「—」）。
## 底是 `result/ledger_stele`（美术设计定稿甲：半透明的大理石光影与刻线，直接画在结算页的石板上，不另垫底）；字和数由这里写：
## 标签思源宋体 22，数量 Cinzel Bold 24 右对齐（「27 件 · 保险箱 2 件」里的汉字落到思源宋体），最高稀有度写稀有度名、用稀有度色，
## 合计行标签粗体 26、数 Cinzel 38 朱红。补充二：整页放大 1.2 倍，图是 2 倍分辨率、按 [constant ART_SIZE] 缩着画。规格见 `art/ui/ledger/out/v2/layout.json`。
##
## 逐行显出：进屏 [constant FIRST_DELAY] 秒后第一行，之后每 [constant ROW_GAP] 秒一行，数字 [constant ROLL_SEC] 秒里从零滚到实值；
## 点一下或按任意键剩下的全显、数字直接到位。全显那一刻发 [signal revealed]（结算屏这时才让「继续」可点）。重看结算同一套，不记「看过」
class_name LedgerView
extends Control

signal revealed

## 账面（字和线落的那块）；图比它大，左上差 [constant ART_ORIGIN]
const LEDGER_SIZE := Vector2(864, 576)
const ROW_H := 48.0
const ART := "result/ledger_stele"
const ART_ORIGIN := Vector2(-29, -29)
## 图按这个（1x）大小画（文件是 2 倍分辨率）
const ART_SIZE := Vector2(922, 634)
const LABEL_X := 22.0
const NUMBER_RIGHT := 701.0
const XP_RIGHT := 845.0
const FIRST_DELAY := 0.4
const ROW_GAP := 0.35
const ROLL_SEC := 0.3
## 甲 碑板的字色（tone light）
const INK_NUM := Color("16110d")
const INK_LABEL := Color("2e2219")
const INK_DIM := Color("68655f")
const INK_TOTAL := Color("8c2b22")

## 每行 {"key", "label", "fmt", "values": Array[int], "text"（不滚的行直接写）, "color", "rarity": bool, "total": bool}
var _rows: Array[Dictionary] = []
var _t := 0.0
var _all := false
var _num_font: Font
var _body_font: Font
var _bold_font: Font


func _init() -> void:
	custom_minimum_size = LEDGER_SIZE
	size = LEDGER_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_font = UiPalette.cjk_font()
	_bold_font = UiPalette.cjk_font_bold()
	_num_font = UiPalette.numeral_font()


## 按一局的账摆十二行（十一行 + 合计）。[param lit] = 这一局图鉴新点亮几件（`GameFlow.last_absorbed`）
func setup(r: RunResult, lit: int) -> void:
	_rows = rows_for(r, lit)
	_t = 0.0
	_all = _rows.is_empty()
	set_process(not _all)
	queue_redraw()


## 账单的十一行 + 合计（战败同一张：带出的东西只有保险箱那半句，最高稀有度按保险箱算，钱与总价值是零）
static func rows_for(r: RunResult, lit: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if r == null:
		return out
	var extracted := r.is_extracted()
	out.append(_num_row("visited", [r.visited]))
	out.append(_num_row("steps", [r.steps]))
	out.append(_num_row("defeated", [maxi(0, r.battles_won - r.elite_won - r.boss_won)]))     # 补充二：普通敌人，精英、首领各一行
	out.append(_num_row("elite", [r.elite_won]))
	out.append(_num_row("boss", [r.boss_won]))
	out.append(_num_row("lost", [r.battles_lost]))
	out.append(_num_row("search_craft", [r.searches, r.crafts], "ledger.dot"))
	out.append(_num_row("lit", [lit]))
	var carried := r.carried.size() if extracted else 0
	var safe := r.safe_items.size()
	if extracted and safe > 0:
		out.append(_num_row("carried", [carried, safe], UiText.key_for("ledger.items_safe", carried)))
	elif not extracted and safe > 0:
		out.append(_num_row("carried", [safe], "ledger.safe_only"))
	else:
		out.append(_num_row("carried", [carried], UiText.key_for("ledger.items", carried)))
	var best := -1
	var brought: Array = r.safe_items.duplicate()
	if extracted:
		brought.append_array(r.carried)
	for inst in brought:
		if inst != null and inst.def != null:
			best = maxi(best, inst.def.rarity)
	var rarity := {"key": "rarity", "label": UiText.t("ledger.rarity"), "values": [], "rarity": best >= 0,
		"text": ItemTooltip.rarity_name(best) if best >= 0 else UiText.t("ledger.none"),
		"color": UiPalette.rarity_color(best, UiTheme.TONE_LIGHT) if best >= 0 else INK_DIM}
	out.append(rarity)
	out.append(_num_row("coins", [r.balance]))
	var total := _num_row("total", [r.value + r.safe_value])
	total["total"] = true
	total["color"] = INK_TOTAL
	out.append(total)
	return out


static func _num_row(key: String, values: Array, fmt_key: String = "") -> Dictionary:
	return {"key": key, "label": UiText.t("ledger." + key), "fmt": UiText.t(fmt_key) if fmt_key != "" else "%d",
		"values": values, "color": INK_NUM, "rarity": false, "total": false}


## 一行此刻写什么：滚到 [param p]（0..1）那一刻的数
static func text_at(row: Dictionary, p: float = 1.0) -> String:
	var values: Array = row.get("values", [])
	if values.is_empty():
		return String(row.get("text", ""))
	var now: Array = []
	for v in values:
		now.append(int(v) if p >= 1.0 else roundi(float(v) * clampf(p, 0.0, 1.0)))
	return String(row["fmt"]) % now


#region 测试与结算屏读
## 每行 {"key", "label", "text"（到位的数）, "shown"}
func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in _rows.size():
		out.append({"key": _rows[i]["key"], "label": _rows[i]["label"], "text": text_at(_rows[i]), "shown": _shown(i)})
	return out


## 行名 → 到位的数（177 的 [method ResultScreen.numbers] 照旧读它）
func numbers() -> Dictionary:
	var out := {}
	for row in _rows:
		out[String(row["label"])] = text_at(row)
	return out


func is_revealed() -> bool:
	return _all


## 剩下的行全显、数字到位
func reveal_all() -> void:
	if _all:
		return
	_all = true
	set_process(false)
	queue_redraw()
	revealed.emit()
#endregion


func _shown(i: int) -> bool:
	return _all or _t >= FIRST_DELAY + i * ROW_GAP


func _progress(i: int) -> float:
	return 1.0 if _all else clampf((_t - FIRST_DELAY - i * ROW_GAP) / ROLL_SEC, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= FIRST_DELAY + (_rows.size() - 1) * ROW_GAP + ROLL_SEC:
		reveal_all()


## 点一下 / 按任意键：全显（这一下不再往下传 —— 不会顺手点到别的）
func _input(event: InputEvent) -> void:
	if _all or not is_visible_in_tree():
		return
	var hit := event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
		or event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if hit:
		reveal_all()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var tex := UiTheme.art_cached(ART)
	if tex != null:
		draw_texture_rect(tex, Rect2(ART_ORIGIN, ART_SIZE), false)
	for i in _rows.size():
		if not _shown(i):
			continue
		var row := _rows[i]
		var y := i * ROW_H
		var total := bool(row.get("total", false))
		var label := String(row["label"])
		if total:
			draw_string(_bold_font, Vector2(LABEL_X, y + 35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK_LABEL)
		else:
			draw_string(_body_font, Vector2(LABEL_X, y + 32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK_LABEL)
		var text := text_at(row, _progress(i))
		var font := _bold_font if bool(row.get("rarity", false)) or (row.get("values", []) as Array).is_empty() else _num_font
		var px := 38 if total else (22 if font == _bold_font else 24)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(font, Vector2(NUMBER_RIGHT - w, y + (40 if total else (32 if font == _bold_font else 34))), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, row["color"])
		var xp := UiText.t("ledger.xp_total") if total else UiText.t("ledger.none")
		var xp_px := 18 if total else 19
		var xw := _body_font.get_string_size(xp, HORIZONTAL_ALIGNMENT_LEFT, -1, xp_px).x
		draw_string(_body_font, Vector2(XP_RIGHT - xw, y + (33 if total else 32)), xp, HORIZONTAL_ALIGNMENT_LEFT, -1, xp_px, INK_DIM)
