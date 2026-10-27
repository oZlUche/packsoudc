## 260 军功碑（作者 14:13 选 B，「最后对局不再显示」）：基地家页的战绩。碑额刻最佳一局（单局价值大数 + 两行小字），
## 四枚军功牌竖排在左、次数与名目在右（撤离 / 击败核心 / 打赢按次数分五阶，阈值在 [member MetaRules.medal_tiers]；战败不分阶），
## 碑脚铭文带一行累计账（局数 · 总分 · 图鉴 · 金币）。
## 件和摆位照 UI替换美术 的 art/ui/stele260/out/layout.json（都相对碑身左上）；碑的图在 `ui/records/`，没到就画石色占位；
## 圆牌的图（美术设计 records260）没到用 256 的军团圆牌 `legion_phalera@sN` 占位。字全由代码写，浅底墨字，大数朱红
class_name RecordsStele
extends Control

const ART := "records/"
## 碑身左上在本控件里的位置（左边碑座伸出 26，上面山墙伸出 78）
const ORIGIN := Vector2(26, 78)
const FOOTPRINT := Vector2(492, 840)
const BODY := Vector2(440, 700)
const GABLE_AT := Vector2(58, -78)
const LAUREL_AT := Vector2(188, -62)
const BASE_AT := Vector2(-26, 696)
const TABLET := Rect2(24, 28, 392, 150)
const MEDAL_AT := Vector2(36, 200)
const MEDAL := 88.0
const ROW_STEP := 104.0
const SOCKET_PAD := 8.0
const RULE_AT := Vector2(143, 189)
const BAND := Rect2(24, 620, 392, 56)
const TEXT_X := 144.0
## 字区右边留白（碑身内框）
const TEXT_RIGHT := 24.0
const BAND_PAD := 12.0
const BEST_SIZE := 44
const LINE1_SIZE := 17
const LINE2_SIZE := 14
const NUM_SIZE := 32
const LABEL_SIZE := 18
const LEDGER_SIZE := 15
const MIN_SIZE := 10
const INK := Color("2e2219")
const BROWN := Color("5a4433")
const VERM := Color("a3301f")
const LIT := Color("f1ece2")
## 缺图时的石色
const STONE := Color("ddd6c8")
const STONE_DARK := Color("a8a091")
## 军功牌：[图名, MetaState 字段, 名目文本键]；战败不分阶
const ROWS := [["escape", "extractions", "records.medal_extract"], ["core", "boss_kills", "records.medal_core"],
	["win", "battles_won", "records.medal_wins"], ["defeat", "deaths", "records.medal_deaths"]]
const TIERS := ["bronze", "silver", "gold", "gilded", "laurel"]

var _best: CoinLabel
var _funds: CoinLabel
var _lines := ["", ""]
## 每行 {count, tier（0 = 还没到铜）, next（下一阶门槛，-1 = 到顶或不分阶）, kind, label}
var _rows: Array[Dictionary] = []
var _ledger := ""
var _ledger_size := LEDGER_SIZE
var _has_best := false
static var _placeholders: Dictionary = {}


func setup(flow: GameFlow) -> void:
	var m := flow.meta
	custom_minimum_size = FOOTPRINT
	mouse_filter = Control.MOUSE_FILTER_PASS     # 圆牌那几行悬停说下一阶还差几次
	_has_best = m.best_value > 0
	_lines = best_lines(flow)
	var tiers: Dictionary = m.rules.medal_tiers if m.rules != null else {}
	_rows.clear()
	for spec in ROWS:
		var count := int(m.get(spec[1]))
		var steps: Array = tiers.get(spec[1], [])
		var tier := tier_of(count, steps)
		_rows.append({"kind": spec[0], "count": count, "tier": tier, "next": int(steps[tier]) if tier < steps.size() else -1,
			"label": UiText.t(spec[2]) + ((" · " + tier_name(tier)) if tier > 0 else "")})
	_ledger = UiText.t("records.ledger") % [m.runs, m.score, m.codex.size(), flow.items.ids(true).size()]
	_best = CoinLabel.make(m.best_value, UiTheme.sz(BEST_SIZE), VERM)
	_best.visible = _has_best
	add_child(_best)
	_funds = CoinLabel.make(m.funds, UiTheme.sz(LEDGER_SIZE), INK)
	add_child(_funds)
	_fit_ledger()
	resized.connect(_place)
	_place()


## 碑额两行小字：章节 · 结局 · 角色 / 第几局 · 几步 · 赢几场。老存档只有数没有那一局的记录：一行「最佳一局」；一局都没撤离过：一行「还没有」
static func best_lines(flow: GameFlow) -> Array:
	var m := flow.meta
	if m.best_value <= 0:
		return [UiText.t("records.no_best"), ""]
	var b := m.best_run
	if b.is_empty():
		return [UiText.t("records.best"), ""]
	var parts: Array[String] = []
	var ch := flow.chapter_of(StringName(String(b.get("chapter", ""))))
	if ch != null:
		parts.append(Names.of(ch))
	parts.append(UiText.t("records.outcome_" + ("extracted" if String(b.get("outcome", "")) == "extracted" else "defeated")))
	var who := flow.character_of(StringName(String(b.get("character", ""))))
	if who != null:
		parts.append(Names.of(who))
	return [" · ".join(parts), UiText.t("records.best_tally") % [int(b.get("run_no", 0)), int(b.get("steps", 0)), int(b.get("battles_won", 0))]]


## 次数到了第几阶：0 = 还没到第一档，[param steps] 是五档门槛（升序）
static func tier_of(count: int, steps: Array) -> int:
	var tier := 0
	for s in steps:
		if count >= int(s):
			tier += 1
	return tier


static func tier_name(tier: int) -> String:
	return UiText.t("records.tier_" + TIERS[clampi(tier - 1, 0, TIERS.size() - 1)])


## 第 [param i] 行的数据（测试看）
func row(i: int) -> Dictionary:
	return _rows[i]


func lines() -> Array:
	return _lines


func ledger() -> String:
	return _ledger


func ledger_size() -> int:
	return _ledger_size


## 碑脚一行（字 + 金币）放不下铭文带就缩字，最小 [constant MIN_SIZE]
func _fit_ledger() -> void:
	var f := UiPalette.cjk_font()
	_ledger_size = UiTheme.sz(LEDGER_SIZE)
	while _ledger_size > MIN_SIZE and ledger_width(f, _ledger_size) > BAND.size.x - 2.0 * BAND_PAD:
		_ledger_size -= 1
	_funds.font_size = _ledger_size


func ledger_width(f: Font, px: int) -> float:
	var probe := CoinLabel.make(_funds.amount, px, INK)
	var w := f.get_string_size(_ledger, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + probe.get_combined_minimum_size().x
	probe.free()
	return w


## 一行字放不下 [param width] 就缩字号，最小 [constant MIN_SIZE]
static func fit_size(f: Font, text: String, base: int, width: float) -> int:
	var px := base
	while px > MIN_SIZE and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		px -= 1
	return px


func _place() -> void:
	var o := ORIGIN
	var bs := _best.get_combined_minimum_size()
	_best.position = o + Vector2(TABLET.position.x + (TABLET.size.x - bs.x) * 0.5, TABLET.position.y + 76.0 - bs.y * 0.5 - UiTheme.sz(BEST_SIZE) * 0.3)
	_best.size = bs
	var f := UiPalette.cjk_font()
	var fw := _funds.get_combined_minimum_size()
	var total := f.get_string_size(_ledger, HORIZONTAL_ALIGNMENT_LEFT, -1, _ledger_size).x + fw.x
	var x0 := o.x + BAND.position.x + (BAND.size.x - total) * 0.5
	_funds.position = Vector2(x0 + total - fw.x, o.y + BAND.position.y + (BAND.size.y - fw.y) * 0.5)
	_funds.size = fw
	queue_redraw()


## 第 [param i] 行（圆牌 + 字）在本控件里的矩形
func row_rect(i: int) -> Rect2:
	var top := ORIGIN + MEDAL_AT + Vector2(0, ROW_STEP * i)
	return Rect2(top, Vector2(BODY.x - MEDAL_AT.x - TEXT_RIGHT, MEDAL))


## 碑额、四行、碑脚在本控件里的矩形（测试查都在碑身里）
func tablet_rect() -> Rect2:
	return Rect2(ORIGIN + TABLET.position, TABLET.size)


func band_rect() -> Rect2:
	return Rect2(ORIGIN + BAND.position, BAND.size)


func _get_tooltip(at: Vector2) -> String:
	for i in _rows.size():
		if not row_rect(i).has_point(at) or String(_rows[i]["kind"]) == "defeat":
			continue
		var next := int(_rows[i]["next"])
		if next < 0:
			return UiText.t("records.top_tier")
		return UiText.t("records.next_tier") % [tier_name(int(_rows[i]["tier"]) + 1), next - int(_rows[i]["count"])]
	return ""


func _tex(name: String) -> Texture2D:
	return UiTheme.art_cached(ART + name)


## 圆牌的图：美术设计的定稿（`records/record_<种>_<阶>`、没到第一阶 `_locked`、战败 `record_defeat`）；没到用军团圆牌占位
func medal_texture(i: int) -> Texture2D:
	var r: Dictionary = _rows[i]
	var kind := String(r["kind"])
	var tier := int(r["tier"])
	var name := "record_defeat" if kind == "defeat" else ("record_%s_%s" % [kind, TIERS[tier - 1]] if tier > 0 else "record_%s_locked" % kind)
	var t := _tex(name)
	if t != null:
		return t
	var path := "res://assets/items/legion_phalera%s.png" % ("@s%d" % mini(tier, 4) if tier > 0 else "")
	if not _placeholders.has(path):
		_placeholders[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null     # 在 _draw 里画，得留住引用（184）
	return _placeholders[path]


func _draw() -> void:
	var o := ORIGIN
	_piece("stele_base", o + BASE_AT, Rect2(o + Vector2(-20, BODY.y - 4), Vector2(BODY.x + 40, 40)))
	_piece("stele_body", o, Rect2(o, BODY))
	_piece("stele_tablet", o + TABLET.position, Rect2(o + TABLET.position, TABLET.size), true)
	for i in _rows.size():
		var mp := o + MEDAL_AT + Vector2(0, ROW_STEP * i)
		var socket := _tex("stele_socket")
		if socket != null:
			draw_texture(socket, mp - Vector2.ONE * SOCKET_PAD)
		else:
			draw_circle(mp + Vector2.ONE * MEDAL * 0.5, MEDAL * 0.5 + SOCKET_PAD * 0.5, STONE_DARK)
		var mt := medal_texture(i)
		if mt != null:
			var locked := int(_rows[i]["tier"]) == 0 and String(_rows[i]["kind"]) != "defeat" and _tex("record_%s_locked" % _rows[i]["kind"]) == null
			draw_texture_rect(mt, Rect2(mp, Vector2.ONE * MEDAL), false, Color(1, 1, 1, 0.45) if locked else Color.WHITE)
		if i > 0:
			var rule := _tex("stele_rule")
			if rule != null:
				draw_texture(rule, o + RULE_AT + Vector2(0, ROW_STEP * i))
			else:
				draw_line(o + RULE_AT + Vector2(0, ROW_STEP * i + 2), o + RULE_AT + Vector2(258, ROW_STEP * i + 2), STONE_DARK, 1.0)
	_piece("stele_band", o + BAND.position, Rect2(o + BAND.position, BAND.size), true)
	var gable := _tex("stele_gable")
	if gable != null:
		draw_texture(gable, o + GABLE_AT)
	else:
		var pts := PackedVector2Array()
		for k in 17:
			var a := PI + PI * k / 16.0
			pts.append(o + Vector2(BODY.x * 0.5, 2) + Vector2(cos(a) * 160.0, sin(a) * 70.0))
		draw_colored_polygon(pts, STONE)
	if _has_best:
		var laurel := _tex("stele_laurel")
		if laurel != null:
			draw_texture(laurel, o + LAUREL_AT)
	var f := UiPalette.cjk_font()
	var fb := UiPalette.cjk_font_bold()
	var cx := o.x + TABLET.position.x + TABLET.size.x * 0.5
	var inner := TABLET.size.x - 2.0 * BAND_PAD
	var l1_y := TABLET.position.y + (110.0 if _has_best else 80.0)
	_carved(f, Vector2(cx, o.y + l1_y), _lines[0], fit_size(f, _lines[0], UiTheme.sz(LINE1_SIZE), inner), INK, true)
	if String(_lines[1]) != "":
		_carved(f, Vector2(cx, o.y + TABLET.position.y + 136), _lines[1], fit_size(f, _lines[1], UiTheme.sz(LINE2_SIZE), inner), BROWN, true)
	for i in _rows.size():
		var top := o.y + MEDAL_AT.y + ROW_STEP * i
		var num := "%d" % int(_rows[i]["count"])
		var ns := UiTheme.sz(NUM_SIZE)
		_carved(fb, Vector2(o.x + TEXT_X, top + 56), num, ns, INK)
		var nw := fb.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
		var room := BODY.x - TEXT_RIGHT - TEXT_X - nw - 10.0
		var label := String(_rows[i]["label"])
		_carved(f, Vector2(o.x + TEXT_X + nw + 10, top + 54), label, fit_size(f, label, UiTheme.sz(LABEL_SIZE), room), INK)
	var total := f.get_string_size(_ledger, HORIZONTAL_ALIGNMENT_LEFT, -1, _ledger_size).x + _funds.size.x
	var x0 := o.x + BAND.position.x + (BAND.size.x - total) * 0.5
	_carved(f, Vector2(x0, o.y + BAND.position.y + BAND.size.y * 0.5 + _ledger_size * 0.35), _ledger, _ledger_size, INK)


## 一件碑的图；缺图在 [param fallback] 上画石色块（[param sunk] = 凹框：深一点的边）
func _piece(name: String, at: Vector2, fallback: Rect2, sunk := false) -> void:
	var t := _tex(name)
	if t != null:
		draw_texture(t, at)
		return
	draw_rect(fallback, STONE.darkened(0.06) if sunk else STONE)
	draw_rect(fallback, STONE_DARK, false, 2.0)


## 刻字：字下一道亮边
func _carved(f: Font, at: Vector2, s: String, fs: int, col: Color, centered := false) -> void:
	var p := at
	if centered:
		p.x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5
	draw_string(f, p + Vector2(0, 1.2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, LIT)
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
