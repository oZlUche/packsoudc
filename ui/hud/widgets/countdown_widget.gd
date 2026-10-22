## 150：倒计时「剩 / 总」。这一章没有倒计时就不显示。地图上那个撤离点的关闭标记仍由地图屏画。
##
## 190（189 作者 2026-10-18 定案：倒计时换成刻在槽底的半圆日规，去掉数字，停上去弹悬浮窗）：
## 栏上只画一枚刻在槽底的半圆日规（[constant SIZE]，轴心 / 半径 / 各阶染色读 `hud/dial/dial.json`），不写字：
## 走过的扇面淡淡染色 → 表盘刻线（`face`）→ 深色刻凿的影子绕轴心转到当前时刻（`shadow_<阶段>`）→ 轴心（`hub`）。
## 停上去弹悬浮窗：「倒计时」/「倒计时还剩 N（共 M）」/「最近的撤离点倒计时剩 N 时关闭」，开着时走一步字跟着变（193 补充一：钟的数不说「步」）。
## 小档按 0.5 缩。缺任何一张图 → 退回原来的一行字「倒计时 N / M」+ 随剩余变色的边框
##
## 235：栏是石刻皮时，日晷是栏皮正中那块下半圆底座（刻度在图里，[code]hud_bar[/code] 画）；这件在栏里就只画走过的扇面、指针、轴心，
## 落在底座的轴心上（`topbar.json` 的 `dial`：180° 在左、90° 正下、0° 在右，y 朝下），停在晷面上开悬浮窗。拖出栏照旧是上面那枚小日规
extends HudWidget

const HudBarScript := preload("res://ui/hud/widgets/hud_bar.gd")
const SKIN := HudBarScript.SKIN

const DIAL_DIR := "hud/dial/"
## 画布大小（和表盘图一样）
const SIZE := Vector2(104, 52)
## 阶段：calm 剩余过半；half 不过半；low 不到四分之一或只剩五步以内
const CALM := &"calm"
const HALF := &"half"
const LOW := &"low"
const LOW_STEPS := 5
## 阶段 → 悬浮窗里数字用的字色样式
const STAGE_STYLE := {CALM: "val", HALF: "stamina", LOW: "hp"}

var _box: StyleBoxFlat
var _meta: Dictionary = {}
## 悬浮窗是不是这一件开的（开着时走一步只换字）
var _tip_open: bool = false


func _init() -> void:
	super()
	_meta = UiTheme.art_meta(DIAL_DIR + "dial")
	if has_dial():
		_text.visible = false
	else:
		_box = StyleBoxFlat.new()
		_box.bg_color = UiPalette.PANEL
		_box.border_color = UiPalette.STAMINA
		_box.set_border_width_all(2)
		_box.set_content_margin_all(6)
		add_theme_stylebox_override("panel", _box)     # 121 特例：边框色随倒计时实时改（见 _paint），得是这一块自己的底（从地图屏搬来，数量不增）；190：只在缺日规图时


func title() -> String:
	return "倒计时"


func watch() -> Array[Signal]:
	return [run.stepped, run.phase_changed] as Array[Signal]


## 日规的五张图都在
static func has_dial() -> bool:
	for n in ["face", "hub", "shadow_calm", "shadow_half", "shadow_low"]:
		if UiTheme.art_cached(DIAL_DIR + n) == null:
			return false
	return true


func _cd() -> CountdownModule:
	var cd := CountdownModule.of(run) if run != null else null
	return cd if cd != null and cd.has_countdown() else null


func text_of() -> String:
	var cd := _cd()
	if cd == null:
		return ""
	if has_dial():
		return UiText.t("hud.countdown")     # 只为显隐：栏上不写字
	var left := cd.left()
	var text := UiText.t("hud.countdown_line") % [left, cd.limit()]
	var closing := cd.closing_extract_id()
	if closing >= 0:
		var node := run.map.get_node(closing)
		text += UiText.t("hud.timed_extract") % [UiText.t("hud.timed_extract_closed") if cd.extract_closed(node) else (UiText.t("hud.timed_extract_closes") % PaidExtracts.closes_at(node))]     # 186：不写点号
	return text


## 现在在哪一阶（没有倒计时按 calm）
func stage() -> StringName:
	var cd := _cd()
	if cd == null:
		return CALM
	var left := cd.left()
	var ratio := float(left) / float(maxi(cd.limit(), 1))
	return LOW if (ratio <= 0.25 or left <= LOW_STEPS) else (HALF if ratio <= 0.5 else CALM)


## 现在该用的颜色（测试读它；缺图时的字与边框）
func color() -> Color:
	return {CALM: UiPalette.FG, HALF: UiPalette.STAMINA, LOW: UiPalette.HP}[stage()]


## 影子此刻的角度（度）：180 = 左端（刚开始），0 = 右端（走完），影子从左往右扫
func angle() -> float:
	var cd := _cd()
	if cd == null:
		return 180.0
	var used := 1.0 - clampf(float(cd.left()) / float(maxi(cd.limit(), 1)), 0.0, 1.0)
	return 180.0 - 180.0 * used


func _scale() -> float:
	return 0.5 if tier == Tier.SMALL else 1.0


func _pivot() -> Vector2:
	var p: Array = _meta.get("pivot", [52, 46])
	return Vector2(float(p[0]), float(p[1]))


func _paint() -> void:
	if _box == null:
		return
	var col := color()
	_text.add_theme_color_override("font_color", col)     # 121 特例：颜色随剩余回合实时变，不是固定样式（从地图屏搬来，数量不增）
	_box.border_color = col


func set_tier(t: Tier) -> void:
	super(t)
	_sync_size()


func _bar_changed() -> void:
	_sync_size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_sync_size()


## 日规的大小：画布 × 档位，外加底的内边距（拖出栏时自带凹槽）。235：在石刻栏里没有底、只占晷面那么宽（画在栏皮的晷面上）
func _sync_size() -> void:
	if not has_dial():
		return
	var want := UiTheme.PANEL_BARE if _skin_bar() != null else UiTheme.PANEL_HUD
	if theme_type_variation != want:
		theme_type_variation = want
		UiTheme.apply_tone(self, want)
	if want == UiTheme.PANEL_BARE:
		custom_minimum_size = Vector2(float(_dial().get("face_radius", 102)) * 2.0, 0.0)
		return
	var box := get_theme_stylebox("panel")
	custom_minimum_size = SIZE * _scale() + (box.get_minimum_size() if box != null else Vector2.ZERO)


## 235：在石刻栏里时那条栏（不在栏里 / 栏藏着 / 没有石刻皮 = null）
func _skin_bar() -> HudWidget:
	if not in_bar or not (host is HudHost) or not HudBarScript.has_skin():
		return null
	var bar := (host as HudHost).widget(&"hud_bar")
	return bar if bar != null and bar.visible else null


func _dial() -> Dictionary:
	return HudBarScript.skin().get("dial", {})


## 235：栏皮晷面的轴心（这一件的坐标）
func _skin_pivot(bar: HudWidget) -> Vector2:
	return bar.global_position + bar.call("dial_pivot") - global_position


## 235：在石刻栏里时教程指整块晷面（下半圆的包围盒）
func focus_rect() -> Rect2:
	var bar := _skin_bar()
	if bar == null:
		return super()
	var r := float(_dial().get("face_radius", 102))
	var p := global_position + _skin_pivot(bar)
	return Rect2(p.x - r, p.y, r * 2.0, r)


## 235：在石刻栏里时，晷面那个下半圆都算停在这一件上
func _has_point(point: Vector2) -> bool:
	var bar := _skin_bar()
	if bar == null:
		return Rect2(Vector2.ZERO, size).has_point(point)
	var d := point - _skin_pivot(bar)
	return d.y >= -float(_dial().get("pivot", [0, 6])[1]) and d.length() <= float(_dial().get("face_radius", 102))


func refresh() -> void:
	super()
	if _tip_open:
		var tip := _tip()
		if tip != null:
			tip.update_status(tip_parts())


func _draw() -> void:
	super()
	if not has_dial() or _cd() == null:
		return
	var bar := _skin_bar()
	if bar != null:
		_draw_on_bar(_skin_pivot(bar))
		return
	var s := _scale()
	var origin := ((size - SIZE * s) * 0.5).round()
	var pivot := _pivot()
	var radius := float(_meta.get("radius", 40))
	var st := stage()
	var a := angle()
	# 1. 走过的扇面：从左端扫到现在，淡淡染色
	if a < 180.0:
		var stages: Dictionary = _meta.get("stages", {})
		var wash := Color(String((stages.get(String(st), {}) as Dictionary).get("wash", "#6b6255")))
		wash.a = float(_meta.get("wash_opacity", 0.16))
		var pts := PackedVector2Array([origin + pivot * s])
		var steps := maxi(2, int((180.0 - a) / 4.0) + 1)
		for i in steps + 1:
			var deg := lerpf(180.0, a, float(i) / float(steps))
			pts.append(origin + (pivot + Vector2(cos(deg_to_rad(deg)), -sin(deg_to_rad(deg))) * radius) * s)
		draw_colored_polygon(pts, wash)
	# 2. 表盘刻线
	draw_texture_rect(UiTheme.art_cached(DIAL_DIR + "face"), Rect2(origin, SIZE * s), false)
	# 3. 影子：图朝正上（90°），绕轴心转到当前角度（Godot 的 y 朝下，正角顺时针）
	draw_set_transform(origin + pivot * s, deg_to_rad(90.0 - a), Vector2(s, s))
	draw_texture_rect(UiTheme.art_cached(DIAL_DIR + "shadow_" + String(st)), Rect2(-pivot, SIZE), false)
	draw_set_transform(Vector2.ZERO)
	# 4. 轴心
	draw_texture_rect(UiTheme.art_cached(DIAL_DIR + "hub"), Rect2(origin, SIZE * s), false)


## 235：画在栏皮的晷面上 —— 走过的扇面（180° 扫到现在）→ 指针（图朝正下，绕轴心转 a − 90°）→ 轴心
func _draw_on_bar(pivot: Vector2) -> void:
	var d := _dial()
	var radius := float(d.get("radius", 94))
	var st := stage()
	var a := angle()
	if a < 180.0:
		var wash := Color(String(((d.get("stages", {}) as Dictionary).get(String(st), {}) as Dictionary).get("wash", "#6b6255")))
		wash.a = float(d.get("wash_opacity", 0.16))
		var pts := PackedVector2Array([pivot])
		var steps := maxi(2, int((180.0 - a) / 4.0) + 1)
		for i in steps + 1:
			var deg := deg_to_rad(lerpf(180.0, a, float(i) / float(steps)))
			pts.append(pivot + Vector2(cos(deg), sin(deg)) * radius)
		draw_colored_polygon(pts, wash)
	var hand_meta: Dictionary = d.get("hand", {})
	var hand := UiTheme.art_cached(SKIN + String((hand_meta.get("files", {}) as Dictionary).get(String(st), "dial_hand_" + String(st))))
	if hand != null:
		var hp: Array = hand_meta.get("pivot", [12, 8])
		draw_set_transform(pivot, deg_to_rad(a - 90.0))
		draw_texture(hand, -Vector2(float(hp[0]), float(hp[1])))
		draw_set_transform(Vector2.ZERO)
	var hub := UiTheme.art_cached(SKIN + "dial_hub")
	if hub != null:
		draw_texture(hub, (pivot - hub.get_size() * 0.5).round())


## 235：指针此刻指向哪（这一件的坐标；测试读）。不在石刻栏里 = 空
func hand_tip() -> Vector2:
	var bar := _skin_bar()
	if bar == null:
		return Vector2.INF
	var a := deg_to_rad(angle())
	return _skin_pivot(bar) + Vector2(cos(a), sin(a)) * float(_dial().get("radius", 94))


#region 悬浮窗
## 悬浮窗的名字行与两行字（[method HoverTip.show_status] 的参数）；没有倒计时是空字典
func tip_parts() -> Dictionary:
	var cd := _cd()
	if cd == null:
		return {}
	var p := TextTemplate.STYLE_PREFIX
	var num := "[color=%s%s]%%d[/color]" % [p, STAGE_STYLE[stage()]]
	var left := cd.left()
	var lines: Array[String] = []
	lines.append(UiText.t("hud.countdown_left") % [num % left, p, cd.limit()])
	var closing := cd.closing_extract_id()
	if closing >= 0:
		var node := run.map.get_node(closing)
		if cd.extract_closed(node):
			lines.append(UiText.t("hud.nearest_closed") % p)
		else:
			lines.append(UiText.t("hud.nearest_closes") % (num % PaidExtracts.closes_at(node)))
	return {
		"head": Glossary.tip_head(UiText.t("hud.countdown"), p + "tip_fg"),
		"body": "[font_size=%d][color=%stip_fg]%s[/color][/font_size]" % [Glossary.BODY_SIZE, p, "\n".join(lines)],
	}


## 测试读：悬浮窗里的字（去掉标记）
func tip_plain() -> String:
	var parts := tip_parts()
	return "" if parts.is_empty() else Glossary.strip_bbcode(String(parts["head"]) + "\n" + String(parts["body"]))


func _tip() -> HoverTip:
	return screen.get("_tip") if screen != null else null


func _idle_mouse_filter() -> Control.MouseFilter:
	return Control.MOUSE_FILTER_STOP


func open_tip() -> void:
	var tip := _tip()
	var parts := tip_parts()
	if tip == null or parts.is_empty() or editing:
		return
	var bar := _skin_bar()
	var at := global_position + Vector2(0, size.y)
	if bar != null:     # 235：晷面底下
		var r := float(_dial().get("face_radius", 102))
		at = global_position + _skin_pivot(bar) + Vector2(-r, r + 6.0)
	tip.show_status(parts, at)
	_tip_open = true


func close_tip() -> void:
	_tip_open = false
	var tip := _tip()
	if tip != null:
		tip.release()


func _ready() -> void:
	mouse_filter = _idle_mouse_filter()
	mouse_entered.connect(open_tip)
	mouse_exited.connect(close_tip)
#endregion
