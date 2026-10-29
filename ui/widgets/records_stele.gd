## 260 军功碑（作者 14:13 选 B；16:37 定稿 B 弧顶碑）：基地家页的战绩。补充一（作者 16:38）：碑额只刻仓库总价值（罗马数字，千位上画横线），
## 军功牌竖排在左、次数与单位在右（撤离 / 击败核心 / 打赢按次数分五阶，阈值在 [member MetaRules.medal_tiers]；阶由圆牌的图说，碑面不写阶名），
## 碑脚铭文带一行累计账（局数 · 总分 · 图鉴 · 金币）。
## 件和摆位照 UI替换美术 的 art/ui/stele260/out/layout.json（都相对碑身左上）；碑的图在 `ui/records/`，没到就画石色占位；
## 圆牌的图（美术设计 records260）没到用 256 的军团圆牌 `legion_phalera@sN` 占位。字全由代码写，浅底墨字，碑额的数朱红
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
## 260 补充二（作者 16:43「战败去掉」）：三枚一列，整块（2 × 104 + 88 = 296 高）在碑额底（178）与碑脚带顶（620）之间竖向居中
const MEDAL_AT := Vector2(36, 251)
const MEDAL := 88.0
const ROW_STEP := 104.0
const SOCKET_PAD := 8.0
const RULE_AT := Vector2(143, 240)
const BAND := Rect2(24, 620, 392, 56)
const TEXT_X := 144.0
## 字区右边留白（碑身内框）
const TEXT_RIGHT := 24.0
const BAND_PAD := 12.0
## 260 补充一（UI替换美术 16:41 写法）：碑额一行 = 金币 + 6 + 数，朱红粗衬线最大 50 号，整行宽过 330 就缩；金币不跟字缩，固定 52（补充三）。
## 补充五（作者 10-29 09:03「改成保留小数点后两位，比如15.43k，2.34m，3.1b」，取代补充三、四的罗马数字）：数写成 k / m / b / t 带两位小数，
## 基线 = 碑额顶 + 75 + 字号 × 0.375，金币中心对准字身中线（基线 − 字号 × 0.375）。
## 补充六（作者 10-29 16:11「用罗马数字实现……点击数字可以切换显示……阿拉伯数字时的单位(K/M/B)要大写」）：默认罗马数字两段（[method roman_parts]），
## 段间空 字号 × 0.12，每段上面画自己的横线（照补充四：第一道离字头 max(3, 字号 × 0.1)、粗 max(2, 字号 × 0.06)、往上每道再空 max(2, 字号 × 0.05)），
## 字和第一段的横线整块竖向居中：基线 = 碑额顶 + 75 + (字号 × 0.75 + 第一段横线总高) / 2；点碑额换成阿拉伯写法（[method compact]，单位大写），记在设置里
const WORTH_SIZE := 50
const WORTH_COIN := 52
const WORTH_ROOM := 330.0
const WORTH_GAP := 6.0
const WORTH_BASE := 75.0
const CAP_AT := 0.75
const OVERLINE_K := 0.06
const OVERLINE_GAP := 0.1
const OVERLINE_STEP := 0.05
const PART_GAP := 0.12
## 碑额数的单位：万亿 T、十亿 B、百万 M、千 K
const UNITS := [[1000000000000, "T"], [1000000000, "B"], [1000000, "M"], [1000, "K"]]
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
## 军功牌：[图名, MetaState 字段, 名目文本键]；战败不上碑（deaths 数据留给成就、对局记录）
const ROWS := [["escape", "extractions", "records.medal_extract"], ["core", "boss_kills", "records.medal_core"],
	["win", "battles_won", "records.medal_wins"]]
const TIERS := ["bronze", "silver", "gold", "gilded", "laurel"]

var _funds: CoinLabel
## 碑额：仓库总价值（整数）；写法跟设置（[member GameSettings.stele_roman]），没设置时默认罗马
var _worth := 0
var _roman := true
var _flow: GameFlow = null
## 每行 {count, tier（0 = 还没到铜）, next（下一阶门槛，-1 = 到顶或不分阶）, kind, label}
var _rows: Array[Dictionary] = []
var _ledger := ""
var _ledger_size := LEDGER_SIZE
static var _placeholders: Dictionary = {}


func setup(flow: GameFlow) -> void:
	var m := flow.meta
	custom_minimum_size = FOOTPRINT
	mouse_filter = Control.MOUSE_FILTER_PASS     # 圆牌那几行悬停说下一阶还差几次
	_worth = m.warehouse_value()
	_flow = flow
	_roman = flow.settings.stele_roman if flow.settings != null else true
	var tiers: Dictionary = m.rules.medal_tiers if m.rules != null else {}
	_rows.clear()
	for spec in ROWS:
		var count := int(m.get(spec[1]))
		var steps: Array = tiers.get(spec[1], [])
		var tier := tier_of(count, steps)
		_rows.append({"kind": spec[0], "count": count, "tier": tier, "next": int(steps[tier]) if tier < steps.size() else -1,
			"label": UiText.t(UiText.key_for(spec[2], count))})
	_ledger = UiText.t(UiText.key_for("records.ledger", m.runs)) % [m.runs, m.score, m.codex.size(), flow.items.ids(true).size()]
	_funds = CoinLabel.make(m.funds, UiTheme.sz(LEDGER_SIZE), INK)
	add_child(_funds)
	_fit_ledger()
	resized.connect(_place)
	_place()


## 碑额的阿拉伯写法（补充五；补充六单位大写）：1000 以下写整数；千起 K、百万起 M、十亿起 B、万亿起 T，两位小数用整数算、向下截（999999 → 999.99K，不进位），
## 末尾的 0 去掉（3100000000 → 3.1B、3000 → 3K）；0 写「—」。准数在悬停里
static func compact(v: int) -> String:
	if v <= 0:
		return "—"
	for unit in UNITS:
		var div := int(unit[0])
		if v >= div:
			var hundredths := v / div * 100 + v % div * 100 / div     # 先除后乘，大数不溢出
			var text := "%d.%02d" % [hundredths / 100, hundredths % 100]
			return text.rstrip("0").rstrip(".") + String(unit[1])
	return str(v)


## 罗马数字（I V X L C D M）；0 及以下空串
static func roman(n: int) -> String:
	var out := ""
	for pair in [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]:
		while n >= int(pair[0]):
			out += String(pair[1])
			n -= int(pair[0])
	return out


## 碑额的罗马写法（补充六）拆成段：[[罗马数字, 横线道数], …]。1000 以下一段不画线；千起两段 —— 最高一段（1–999）画 k 道（千 1、百万 2……），
## 下一段取前两位（个位截成 0，向下截）画 k − 1 道，截完是 0 就不写。5414 → [["V", 1], ["CDX", 0]]、2345678 → [["II", 2], ["CCCXL", 1]]；0 写「—」
static func roman_parts(v: int) -> Array:
	if v <= 0:
		return [["—", 0]]
	var div := 1
	var k := 0
	while v / div >= 1000:     # 先除再比，int 上限也不溢出
		div *= 1000
		k += 1
	var out := [[roman(v / div), k]]
	if k > 0:
		var next := v / (div / 1000) % 1000 / 10 * 10
		if next > 0:
			out.append([roman(next), k - 1])
	return out


## 碑额现在写的段：罗马两段，或阿拉伯一段（不画线）
func parts() -> Array:
	return roman_parts(_worth) if _roman else [[compact(_worth), 0]]


func roman_on() -> bool:
	return _roman


## 点碑额：罗马 ↔ 阿拉伯，记进设置并存盘
func toggle_numerals() -> void:
	_roman = not _roman
	if _flow != null and _flow.settings != null:
		_flow.settings.stele_roman = _roman
		_flow.save_settings()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and tablet_rect().has_point(mb.position):
		toggle_numerals()
		accept_event()


## 碑额刻的数（测试看）：段间一个空格；罗马每个字母后面跟横线道数个组合上横线（碑面上横线是画的）
func worth_text() -> String:
	var out: PackedStringArray = []
	for part in parts():
		var seg := ""
		for ch in String(part[0]):
			seg += ch + "\u0305".repeat(int(part[1]))
		out.append(seg)
	return " ".join(out)


func worth() -> int:
	return _worth


## 次数到了第几阶：0 = 还没到第一档，[param steps] 是五档门槛（升序）
static func tier_of(count: int, steps: Array) -> int:
	var tier := 0
	for s in steps:
		if count >= int(s):
			tier += 1
	return tier


## 第 [param i] 行的数据（测试看）
func row(i: int) -> Dictionary:
	return _rows[i]


func row_count() -> int:
	return _rows.size()


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
	if tablet_rect().has_point(at):
		return UiText.t("records.vault_worth") % _worth + "\n" + UiText.t("records.numeral_toggle")     # 悬浮写准数 + 点击换写法
	for i in _rows.size():
		if not row_rect(i).has_point(at):
			continue
		var next := int(_rows[i]["next"])
		if next < 0:
			return UiText.t("records.top_tier")
		return UiText.t("records.next_tier") % (next - int(_rows[i]["count"]))
	return ""


func _tex(name: String) -> Texture2D:
	return UiTheme.art_cached(ART + name)


## 圆牌的图：美术设计的定稿（`records/record_<种>_<阶>`、没到第一阶 `_locked`）；没到用军团圆牌占位
func medal_texture(i: int) -> Texture2D:
	var r: Dictionary = _rows[i]
	var kind := String(r["kind"])
	var tier := int(r["tier"])
	var name := "record_%s_%s" % [kind, TIERS[tier - 1]] if tier > 0 else "record_%s_locked" % kind
	var t := _tex(name)
	if t != null:
		return t
	var path := "res://assets/items/legion_phalera%s.png" % ("@s%d" % mini(tier - 1, 4) if tier > 1 else "")     # 本图铜色，@s1 银、@s2 金
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
			var locked := int(_rows[i]["tier"]) == 0 and _tex("record_%s_locked" % _rows[i]["kind"]) == null
			draw_texture_rect(mt, Rect2(mp, Vector2.ONE * MEDAL), false, Color(1, 1, 1, 0.45) if locked else Color.WHITE)
		if i > 0:
			var rule := _tex("stele_rule")
			if rule != null:
				draw_texture(rule, o + RULE_AT + Vector2(0, ROW_STEP * i))
			else:
				draw_rect(Rect2(o + RULE_AT + Vector2(0, ROW_STEP * i + 1), Vector2(258, 2)), STONE_DARK)     # 2 像素高：1600 逻辑缩到 1280 时 1 像素的线会被吞掉一道
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
	var laurel := _tex("stele_laurel")
	if laurel != null:
		draw_texture(laurel, o + LAUREL_AT)
	var f := UiPalette.cjk_font()
	var fb := UiPalette.cjk_font_bold()
	_draw_tablet(f, fb)
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


## 碑额：金币 + 数一行（罗马写法每段上面画自己的横线），整行水平居中、字和第一段的横线整块竖向居中；放不下缩字
func _draw_tablet(_f: Font, fb: Font) -> void:
	var o := ORIGIN
	var segs := parts()
	var px := worth_size(fb)
	var coin := float(UiTheme.sz(WORTH_COIN))
	var x := o.x + TABLET.position.x + (TABLET.size.x - worth_width(fb, segs, px)) * 0.5
	var base_y := o.y + TABLET.position.y + WORTH_BASE + (px * CAP_AT + overline_stack(px, int(segs[0][1]))) * 0.5
	var icon := CoinLabel.coin_icon(int(coin))
	var coin_top := base_y - px * CAP_AT * 0.5 - coin * 0.5
	if icon != null:
		draw_texture_rect(icon, Rect2(x, coin_top, coin, coin), false)
	else:
		draw_circle(Vector2(x + coin * 0.5, coin_top + coin * 0.5), coin * 0.5, CoinLabel.FALLBACK_FILL)
	var tx := x + coin + WORTH_GAP
	var th := maxf(2.0, px * OVERLINE_K)
	var step := maxf(2.0, px * OVERLINE_STEP)
	for seg in segs:
		var text := String(seg[0])
		var tw := fb.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		_carved(fb, Vector2(tx, base_y), text, px, VERM)
		var y := base_y - px * CAP_AT - maxf(3.0, px * OVERLINE_GAP) - th
		for i in int(seg[1]):
			draw_rect(Rect2(tx, y + 1.2, tw, th), LIT)
			draw_rect(Rect2(tx, y, tw, th), VERM)
			y -= th + step
		tx += tw + px * PART_GAP


## k 道横线（连第一道离字头的缝）一共多高；0 道 0
static func overline_stack(px: int, k: int) -> float:
	if k <= 0:
		return 0.0
	return maxf(3.0, px * OVERLINE_GAP) + k * maxf(2.0, px * OVERLINE_K) + (k - 1) * maxf(2.0, px * OVERLINE_STEP)


## 碑额数的字号：最大 [constant WORTH_SIZE]，金币 + 各段 + 段间空整行超过 [constant WORTH_ROOM] 就缩
func worth_size(fb: Font) -> int:
	var segs := parts()
	var px := UiTheme.sz(WORTH_SIZE)
	while px > MIN_SIZE and worth_width(fb, segs, px) > WORTH_ROOM:
		px -= 1
	return px


## 金币 + 空 + 各段字宽 + 段间空（[param segs] 是 [method parts] 那样的段）
static func worth_width(fb: Font, segs: Array, px: int) -> float:
	var w := UiTheme.sz(WORTH_COIN) + WORTH_GAP + px * PART_GAP * maxi(segs.size() - 1, 0)
	for seg in segs:
		w += fb.get_string_size(String(seg[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	return w


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
