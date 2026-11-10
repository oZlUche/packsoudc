## 256（安德烈乌斯「求饶」）：天平窗的整块舞台（作者 2026-10-26 15:49 定稿，青铜那一稿）—— 四层图：
## 底座（立柱、标题牌、差额牌、下面的石台，`ransom/ransom_base` 1000 × 724，非矩形）、横梁（绕自己正中转，正中对齐底座的 pivot）、
## 左右两只盘（不转只平移，盘层的 hook 点挂在梁的钩上：钩 = pivot + rot(倾角)·(±arm, hook_dy)）。坐标与各控件的位置都在
## `ransom/ransom_layout.json`。左盘上方的托盘棋盘、右盘下的开价小牌跟着盘走：屏往 [member tray_slot] 里放托盘，开价由这里画（金币 + 数）。
## 托盘坐在左盘的两根矮柱上，柱间是放上左盘的金币（[member coins]，按 `coin_pile` 一摞摞堆，刚好够开价时和右盘那摞一样多）。
## 差额牌上写「还差 N」/「够了」。字都落在石牌 / 石台上（226：不裸字）。没有图时（美术目录缺）按同一套坐标画占位
class_name BalanceScale
extends PanScale

const LAYOUT := "ransom/ransom_layout"
const BASE_ART := "ransom/ransom_base"
const BEAM_ART := "ransom/ransom_beam"
const PAN_LEFT_ART := "ransom/ransom_pan_left"
const PAN_RIGHT_ART := "ransom/ransom_pan_right"
## 左盘上的一枚金币（36 × 9，一摞摞往上叠）
const COIN_ART := "ransom/ransom_coin"
const FONT_SIZE := 20
const PLATE_FONT := 18
const INK := Color("2e2219")
## 石台底下那行小字（浅底：淡墨）
const INK_SOFT := Color("605a50")
## 缺图时的占位色
const BRONZE := Color("8a6a3a")
const PLATE := Color("e4ded2")

## 左盘的重量 / 右盘的开价
var left := 0:
	set(v):
		left = v
		_relayout()
var right := 0:
	set(v):
		right = v
		_relayout()
## 左盘上的金币（只算钱，托盘上的东西另算）：盘里看得见这些钱（游戏测试 10-26）
var coins := 0:
	set(v):
		coins = v
		queue_redraw()

## 托盘棋盘的位置（左盘的 tray_rect，跟着盘走）：屏把托盘放进来，底边坐在盘沿上
var tray_slot: VBoxContainer = null


func _init() -> void:
	_lay = layout()
	custom_minimum_size = _v(_lay["base_size"])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_slot = VBoxContainer.new()
	tray_slot.alignment = BoxContainer.ALIGNMENT_END
	tray_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray_slot)
	_relayout()


## 版式：美术的 json；没有就用同形状的一份（尺寸与美术稿一样，测试与占位都按它摆）
static func layout() -> Dictionary:
	var d := UiTheme.art_meta(LAYOUT)
	if not d.is_empty():
		return d
	return {"base_size": [1000, 724], "pivot": [500, 110], "arm": 330, "hook_dy": 18, "max_tilt_deg": 8, "beam_size": [760, 64],
		"pan_size": [340, 362], "hook_in_pan": [170, 8], "tray_rect": [20, 52, 320, 220], "price_rect": [112, 320, 228, 354],
		"coin_pile": {"cols": [80, 116, 152, 188, 224, 260], "base_y": 252, "step": 7.2, "full": [3, 4, 4, 4, 4, 3], "max": 4,
			"order": [[2, 0], [3, 0], [2, 1], [3, 1], [2, 2], [3, 2], [2, 3], [3, 3], [1, 0], [4, 0], [1, 1], [4, 1], [1, 2], [4, 2], [1, 3], [4, 3],
				[0, 0], [5, 0], [0, 1], [5, 1], [0, 2], [5, 2], [0, 3], [5, 3]]},
		"controls": {"title": [404, 26, 596, 62], "status": [424, 200, 576, 236], "subtitle": [250, 576, 750, 604],
			"stepper": [86, 620, 366, 686], "deal": [606, 626, 756, 678], "refuse": [780, 626, 930, 678], "hint": [300, 690, 700, 712]}}


## 横梁斜几度（正 = 左盘低）：差额占开价的比例，夹在 ±max_tilt_deg
func tilt_degrees() -> float:
	if left == right:
		return 0.0
	var k := float(left - right) / float(maxi(1, right))
	return clampf(k, -1.0, 1.0) * float(_lay.get("max_tilt_deg", 8))


## 差额牌上的字
func plate_text() -> String:
	return UiText.t("ransom.enough") if left >= right else UiText.t("ransom.short_by") % (right - left)


## 左盘画几枚金币：ceil(刚好够时的枚数 × 金币 / 开价)，放了钱就至少 1 枚，封顶 order 的长度（每摞堆满）
func pile_count() -> int:
	return _pile(coins, right)


## 右盘开价小牌（舞台坐标）
func price_rect() -> Rect2:
	var r := _rect(_lay["price_rect"])
	return Rect2(pan_origins()[1] + r.position, r.size)


func _relayout() -> void:
	if tray_slot != null and not _lay.is_empty():
		var r := _rect(_lay["tray_rect"])
		tray_slot.position = pan_origins()[0] + r.position
		tray_slot.size = r.size
	queue_redraw()


func _draw() -> void:
	var pans := pan_origins()
	_draw_layer(BASE_ART, Vector2.ZERO, _v(_lay["base_size"]))
	# 横梁：绕自己正中转，正中在 pivot
	var beam_size := _v(_lay["beam_size"])
	draw_set_transform(_v(_lay["pivot"]), deg_to_rad(-tilt_degrees()))
	_draw_layer(BEAM_ART, -beam_size * 0.5, beam_size)
	draw_set_transform(Vector2.ZERO)
	var pan_size := _v(_lay["pan_size"])
	_draw_layer(PAN_LEFT_ART, pans[0], pan_size)
	_draw_layer(PAN_RIGHT_ART, pans[1], pan_size)
	_draw_coin_pile(pans[0])
	_draw_coin_amount(price_rect(), right)
	_draw_centered(control_rect("status"), plate_text(), PLATE_FONT)


## 一层图；缺图画个占位（底座只画立柱和石台，梁一根线，盘一只碗）
func _draw_layer(art: String, at: Vector2, size_px: Vector2) -> void:
	var tex := UiTheme.art_cached(art)
	if tex != null:
		draw_texture_rect(tex, Rect2(at, size_px), false)
		return
	match art:
		BASE_ART:
			var pivot := _v(_lay["pivot"])
			draw_rect(Rect2(pivot.x - 18, pivot.y, 36, 450), PLATE)
			draw_rect(Rect2(40, 568, size_px.x - 80, 152), PLATE)
			for k in ["title", "status"]:
				draw_rect(control_rect(k), PLATE)
				draw_rect(control_rect(k), INK, false, 2.0)
		BEAM_ART:
			draw_rect(Rect2(at + Vector2(0, size_px.y * 0.4), Vector2(size_px.x, size_px.y * 0.2)), BRONZE)
		_:
			var rim := at + Vector2(0, 250)
			draw_rect(Rect2(rim, Vector2(size_px.x, 50)), BRONZE)
			draw_rect(Rect2(at + _rect(_lay["price_rect"]).position, _rect(_lay["price_rect"]).size), PLATE)


## 左盘柱间的金币：按 order 的先后落（同一摞总是先底下后上面），每枚坐在盘沿上方第几层
func _draw_coin_pile(origin: Vector2) -> void:
	var tex := UiTheme.art_cached(COIN_ART)
	for r in coin_rects():
		var at := Rect2(origin + (r as Rect2).position, (r as Rect2).size)
		if tex != null:
			draw_texture_rect(tex, at, false)
		else:
			draw_rect(at, CoinLabel.FALLBACK_FILL)


## 现在画的每枚金币（盘层坐标，[method pile_count] 枚，按落下的先后）
func coin_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var n := pile_count()
	if n == 0:
		return out
	var pile: Dictionary = _lay["coin_pile"]
	var step := float(pile["step"])
	var tex := UiTheme.art_cached(COIN_ART)
	var cs := tex.get_size() if tex != null else Vector2(36, 9)
	for k in n:
		var cell: Array = pile["order"][k]
		out.append(Rect2(Vector2(float(pile["cols"][int(cell[0])]) - cs.x * 0.5, float(pile["base_y"]) - (int(cell[1]) + 1) * step - (cs.y - step) * 0.5), cs))
	return out


## 小牌上的「金币 + 数」（钱 = 金币图标 + 数）
func _draw_coin_amount(r: Rect2, amount: int) -> void:
	var fs := UiTheme.sz(FONT_SIZE)     # 258：按字号档
	var f := UiPalette.cjk_font_bold()
	var text := "%d" % amount
	var side := roundf(fs * CoinLabel.COIN_SCALE)
	var w := side + CoinLabel.GAP + f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var mid := r.get_center()
	var at := Vector2(mid.x - w * 0.5, mid.y - side * 0.5)
	CoinLabel.draw_coin(self, Rect2(at, Vector2(side, side)))
	draw_string(f, Vector2(at.x + side + CoinLabel.GAP, mid.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)


func _draw_centered(r: Rect2, text: String, font_size: int) -> void:
	var f := UiPalette.cjk_font_bold()
	draw_string(f, Vector2(r.position.x, r.get_center().y + (f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5),
		text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, font_size, INK)
