## 224（作者定）：结算第一页的账单 —— 十一行 + 合计（作者 16:00 去掉了表头；补充二 击败的敌人 / 精英 / 首领分三行），两栏：项目 | 数量（补充三，作者 2026-10-22 12:45：经验列去掉、合计改「总分」，以后有对应系统再把分数转成经验）。
## 底是 `result/ledger_stele`（美术设计定稿甲：半透明的大理石光影与刻线，直接画在结算页的石板上，不另垫底）；字和数由这里写：
## 标签思源宋体 22，数量 Cinzel Bold 24 右对齐（「27 件 · 保险箱 2 件」里的汉字落到思源宋体），最高稀有度写稀有度名、用稀有度色，
## 合计行标签粗体 26、数 Cinzel 38 朱红。补充二：整页放大 1.2 倍；236 第五项 起图是 1× 的（922 × 634，2× 那张白占显存），按 [constant ART_SIZE] 画。规格见 `art/ui/ledger/out/v2/layout.json`。
##
## 逐行显出：进屏 [constant FIRST_DELAY] 秒后第一行，之后每 [constant ROW_GAP] 秒一行，数字 [constant ROLL_SEC] 秒里从零滚到实值；
## 点一下或按任意键剩下的全显、数字直接到位。全显那一刻发 [signal revealed]（结算屏这时才让「继续」可点）。重看结算同一套，不记「看过」
class_name LedgerView
extends Control

signal revealed

## 账面（字和线落的那块）；图比它大，左上差 [constant ART_ORIGIN]
const LEDGER_SIZE := Vector2(864, 576)
const ROW_H := 48.0
## 碑板图里明细行那一段（合计那条横带之上）：账面 y 0..[constant ROWS_H]，正好 [constant VISIBLE_ROWS] 行。
## 作者 11-27：明细行多了（372 等级行等）行高不变，这一段只露 11 行，滚轮一格翻一行；合计固定在底下那条横带上
const ROWS_H := 528.0
const VISIBLE_ROWS := 11
## 滚动条：明细区右边框里一道细槽（账面 x），只在行数多于 [constant VISIBLE_ROWS] 时画
const SCROLL_X := 855.0
const SCROLL_W := 4.0
const SCROLL_PAD := 6.0
const ART := "result/ledger_stele"
const ART_ORIGIN := Vector2(-29, -29)
## 图按这个（1x）大小画
const ART_SIZE := Vector2(922, 634)
const LABEL_X := 22.0
const NUMBER_RIGHT := 845.0
const FIRST_DELAY := 0.4
const ROW_GAP := 0.35
const ROLL_SEC := 0.3
## 甲 碑板的字色（tone light）
const INK_NUM := Color("16110d")
const INK_LABEL := Color("2e2219")
const INK_DIM := Color("68655f")
const INK_TOTAL := Color("8c2b22")
## 269：总分的明细小字（思源宋体 14 灰墨），写在总分行里、离总分的数这么远
const PARTS_PX := 14
const PARTS_GAP := 24.0

## 每行 {"key", "label", "fmt", "values": Array[int], "text"（不滚的行直接写）, "color", "rarity": bool, "total": bool}
var _rows: Array[Dictionary] = []
var _t := 0.0
var _all := false
## 明细区往下翻了几行（整行翻，碑板上刻好的格线永远对得上）
var _scroll := 0
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
	_scroll = 0
	_all = _rows.is_empty()
	set_process(not _all)
	queue_redraw()


## 账单的十一行 + 合计（战败同一张：带出的东西只有保险箱那半句，最高稀有度按保险箱算，钱与总价值是零）
static func rows_for(r: RunResult, lit: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if r == null:
		return out
	if r.score_parts.is_empty():
		r.compute_score(lit)     # 269：没经过 settle / absorb 的（测试、重看）补算一次
	var extracted := r.is_extracted()
	out.append(_num_row("visited", [r.visited]))
	out.append(_num_row("steps", [r.steps]))
	out.append(_num_row("defeated", [maxi(0, r.battles_won - r.elite_won - r.boss_won)]))     # 补充二：普通敌人，精英、首领各一行
	out.append(_num_row("elite", [r.elite_won]))
	out.append(_num_row("boss", [r.boss_won]))
	out.append(_num_row("lost", [r.battles_lost]))
	out.append(_num_row("search_craft", [r.searches, r.crafts], "ledger.dot"))
	out.append(_num_row("lit", [lit]))
	if r.run_level > 1:
		out.append(_num_row("level", [r.run_level]))     # 372：这一局到了几级（1 级不写，老账单行数不变）
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
	var total := _num_row("total", [r.score])     # 269：总分 = （战利 + 战绩 + 探索）× 难度（[ScoreRules]）
	total["total"] = true
	total["color"] = INK_TOTAL
	total["parts"] = score_parts_text(r)
	out.append(total)
	return out


## 269：总分下面那行小字「战利 N · 战绩 N · 探索 N」（非普通难度再加「 · 难度 ×1.25」）
static func score_parts_text(r: RunResult) -> String:
	var p := r.score_parts
	var text := UiText.t("ledger.score_parts") % [int(p.get("loot", 0)), int(p.get("battle", 0)), int(p.get("explore", 0))]
	if int(p.get("growth", 0)) > 0:
		text += UiText.t("ledger.score_growth") % int(p["growth"])     # 372
	var mult := float(p.get("mult", 1.0))
	if mult != 1.0:
		text += UiText.t("ledger.score_mult") % String.num(mult, 2).rstrip("0").rstrip(".")
	return text


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
	_scroll = max_scroll()     # 作者 11-27：内容超出时最后停在底部（点一下跳过也一样）
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
	follow_newest()
	queue_redraw()
	if _t >= FIRST_DELAY + (_rows.size() - 1) * ROW_GAP + ROLL_SEC:
		reveal_all()


## 点一下 / 按任意键：全显（这一下不再往下传 —— 不会顺手点到别的）；明细区上滚轮：翻行（逐行显出时滚轮也算「点一下」）
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var mb := event as InputEventMouseButton
	if _all:
		if mb != null and mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN) \
				and Rect2(Vector2.ZERO, Vector2(LEDGER_SIZE.x, ROWS_H)).has_point(get_local_mouse_position()):
			if scroll_by(-1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1):
				get_viewport().set_input_as_handled()
		return
	var hit := mb != null and mb.pressed \
		or event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if hit:
		reveal_all()
		get_viewport().set_input_as_handled()


## 明细行（不含合计）有几行
func detail_count() -> int:
	return maxi(0, _rows.size() - 1)


## 逐行显出时跟着最新显出的那行往下翻（作者 11-27：每出一行新的就自动滚），全显之后玩家自己滚
func follow_newest() -> void:
	if _all:
		return
	var newest := -1
	for i in detail_count():
		if _shown(i):
			newest = i
	_scroll = clampi(newest - VISIBLE_ROWS + 1, 0, max_scroll())


## 最多能往下翻几行
func max_scroll() -> int:
	return maxi(0, detail_count() - VISIBLE_ROWS)


func scroll_rows() -> int:
	return _scroll


## 往下翻 [param d] 行（负数往上）；真翻动了返回 true
func scroll_by(d: int) -> bool:
	var to := clampi(_scroll + d, 0, max_scroll())
	if to == _scroll:
		return false
	_scroll = to
	queue_redraw()
	return true


func _draw() -> void:
	var tex := UiTheme.art_cached(ART)
	if tex != null:
		draw_texture_rect(tex, Rect2(ART_ORIGIN, ART_SIZE), false)
	for i in _rows.size():
		if not _shown(i):
			continue
		var row := _rows[i]
		var total := bool(row.get("total", false))
		var slot := i - _scroll
		if not total and (slot < 0 or slot >= VISIBLE_ROWS):
			continue
		var y := ROWS_H if total else slot * ROW_H     # 合计总在那条横带上
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
		var parts := String(row.get("parts", ""))
		if parts != "" and _progress(i) >= 1.0:     # 269：总分行里、数的左边一行小字（数滚到位才写；账单框下沿紧贴，放不下另起一行）
			var pw := _body_font.get_string_size(parts, HORIZONTAL_ALIGNMENT_LEFT, -1, PARTS_PX).x
			draw_string(_body_font, Vector2(NUMBER_RIGHT - w - PARTS_GAP - pw, y + 33), parts, HORIZONTAL_ALIGNMENT_LEFT, -1, PARTS_PX, INK_DIM)
	_draw_scrollbar()


## 行数多于 11 才画：一道浅槽 + 墨色滑块，滑块长短 = 露出的比例、位置 = 翻到哪
func _draw_scrollbar() -> void:
	var n := detail_count()
	if n <= VISIBLE_ROWS:
		return
	var track := Rect2(SCROLL_X, SCROLL_PAD, SCROLL_W, ROWS_H - 2.0 * SCROLL_PAD)
	draw_rect(track, Color(INK_DIM, 0.25))
	var h := track.size.y * VISIBLE_ROWS / n
	var y := track.position.y + (track.size.y - h) * _scroll / maxf(1.0, max_scroll())
	draw_rect(Rect2(SCROLL_X, y, SCROLL_W, h), Color(INK_LABEL, 0.75))
