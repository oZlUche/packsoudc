## 231：开战的双剑铜章（作者 2026-10-21 19:12：「战前中央的圆形纹章下移，里面的两把交叉的剑开始互相攻击，最终左边或者右边胜利」）。
## 三层贴图同一 132 画布对位（UI替换美术 art/ui/anim231，19:31）：盘 `bronze/medal_plate`、左剑 `medal_sword_left`（自己，剑柄在左下）、
## 右剑 `medal_sword_right`（对手），剑自带暗影；剑尖金光 `tip_glint`（横的，不随剑转）；火星、反应晕圈代码画。姿态只是表现，不碰回放：[member rate] = 回放倍速（时长除以它，≥ 4 只闪不挥）；[method set_final] 不演直接摆终态
class_name DuelMedal
extends Control

const SIDE := 132.0
const ART := ["bronze/medal_sword_left", "bronze/medal_sword_right"]
const DISC_ART := "bronze/medal_plate"
const GLINT_ART := "bronze/tip_glint"
## 原图（拆层前的整枚），层图缺时整枚画它、不动
const WHOLE_ART := "bronze/medal_swords"
## 两把剑转动的支点（握把中点，132 画布里）与剑尖（anim231 layout.json）
const GRIP := [Vector2(46.0, 85.45), Vector2(82.0, 85.45)]
const TIP := [Vector2(93.57, 28.76), Vector2(34.43, 28.76)]
## 两剑交点（火星从这儿迸）
const CROSS := Vector2(64.5, 61)
## 守姿（作者 2026-10-22 08:13：「两把剑彼此之间要拉开距离然后接近，距离要长到足够分开（不接触）」）：
## 回放开始时两把剑各自往外让开、立得更直，彼此不碰；出手时从守姿冲到对面劈下，再退回守姿
const GUARD_DEG := 30.0
const GUARD_OFF := Vector2(-22, 0)
const SPREAD_SEC := 0.3
## 劈（作者 2026-10-21 22:24：角度到 45–60°、距离再大，先往后上方提起再劈下）：
## 提起 —— 从守姿再往背离对面的方向转、往后上方提；劈下 —— 转过头、冲到对面（从守姿算一共走 42 px）；退回守姿。各段多久（一倍速，合计 0.22 s）
const WINDUP_DEG := 30.0
const WINDUP_LIFT := Vector2(-8, -10)
const STRIKE_DEG := 45.0
const STRIKE_PUSH := Vector2(20, 4)
const WINDUP_SEC := 0.07
const CHOP_SEC := 0.05
const RECOVER_SEC := 0.1
## 挨打：后仰多少、多久；剑身白闪
const RECOIL_DEG := 18.0
const RECOIL_SEC := 0.08
## 分胜负：赢的竖起来（剑尖朝正上，静止时偏 40°）、输的垂下去
const RAISE_DEG := 40.0
const DROP_DEG := 52.0
const DROP_FALL := 10.0
const FINAL_SEC := 0.4
const GLINT_SEC := 0.3
const SPARK_SEC := 0.3
const REACT_SEC := 0.3
const GREY := Color(0.58, 0.58, 0.6, 0.9)

## 回放倍速（宿主跟着回放改）
var rate := 1.0
## 每把剑：转角（弧度，正 = 顺时针）、位移、白闪（0..1）、褪灰（0..1）
var _rot := [0.0, 0.0]
var _off := [Vector2.ZERO, Vector2.ZERO]
var _flash := [0.0, 0.0]
var _grey := [0.0, 0.0]
var _tweens: Array = [null, null]
## 火星（0..1 进度，< 0 = 没有）、金光（哪一方、0..1）、反应晕圈
var _spark := -1.0
var _spark_seed := 0
var _glint_side := -1
var _glint := -1.0
var _ring := -1.0
var _ring_color := Color.WHITE
## 终局：-2 = 还没分，-1 = 平局，0 / 1 = 谁赢
var _winner := -2
## 拉开了没有（拉开后两把剑的「原位」是守姿，不再交叉）
var _spread := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * SIDE
	size = Vector2.ONE * SIDE
	pivot_offset = size * 0.5


## 拆层图都在不在（不在就画整枚、不动）
static func has_layers() -> bool:
	return UiTheme.art_cached(DISC_ART) != null and UiTheme.art_cached(ART[0]) != null and UiTheme.art_cached(ART[1]) != null


#region 动作（回放事件驱动）
## [param side] 那一方出手：那把剑朝对面劈一下
func strike(side: int) -> void:
	if not _live(side) or rate >= 4.0:
		return
	var dir := 1.0 if side == 0 else -1.0
	var mirror := Vector2(dir, 1.0)
	var rest := _rest_rot(side)
	var home := _rest_off(side)
	var up := rest + deg_to_rad(-WINDUP_DEG) * dir
	var lift := home + WINDUP_LIFT * mirror
	var down := deg_to_rad(STRIKE_DEG) * dir
	var tw := _fresh(side)
	tw.set_parallel()
	tw.tween_method(_set_rot.bind(side), _rot[side], up, WINDUP_SEC / rate)
	tw.tween_method(_set_off.bind(side), _off[side], lift, WINDUP_SEC / rate)
	tw.chain().set_parallel()
	tw.tween_method(_set_rot.bind(side), up, down, CHOP_SEC / rate).set_ease(Tween.EASE_IN)
	tw.tween_method(_set_off.bind(side), lift, STRIKE_PUSH * mirror, CHOP_SEC / rate).set_ease(Tween.EASE_IN)
	tw.chain().set_parallel()
	tw.tween_method(_set_rot.bind(side), down, rest, RECOVER_SEC / rate)
	tw.tween_method(_set_off.bind(side), STRIKE_PUSH * mirror, home, RECOVER_SEC / rate)


## 回放开始：两把剑从交叉的样子拉开到守姿（彼此不碰）。[param animate] false = 直接摆好
func spread(animate: bool = true) -> void:
	if _spread or _winner != -2:
		return
	_spread = true
	for s in 2:
		if not animate:
			_rot[s] = _rest_rot(s)
			_off[s] = _rest_off(s)
			continue
		var tw := _fresh(s).set_parallel()
		tw.tween_method(_set_rot.bind(s), _rot[s], _rest_rot(s), SPREAD_SEC)
		tw.tween_method(_set_off.bind(s), _off[s], _rest_off(s), SPREAD_SEC)
	queue_redraw()


func is_spread() -> bool:
	return _spread


## 这把剑歇着时的转角 / 位移：拉开了是守姿，没拉开是原图交叉的样子
func _rest_rot(side: int) -> float:
	return deg_to_rad(-GUARD_DEG) * (1.0 if side == 0 else -1.0) if _spread else 0.0


func _rest_off(side: int) -> Vector2:
	return GUARD_OFF * Vector2(1.0 if side == 0 else -1.0, 1.0) if _spread else Vector2.ZERO


## [param side] 那一方挨了打：那把剑后仰一下、剑身白闪；[param big] 交点迸火星
func hit(side: int, big: bool = false) -> void:
	if not _live(side):
		return
	_flash[side] = 1.0
	var sec := RECOIL_SEC / maxf(rate, 1.0)
	var tw := _fresh(side)
	tw.tween_method(_set_flash.bind(side), 1.0, 0.0, sec)
	if rate < 4.0:
		var back := _rest_rot(side) + deg_to_rad(-RECOIL_DEG) * (1.0 if side == 0 else -1.0)
		tw.parallel().tween_method(_set_rot.bind(side), _rot[side], back, sec * 0.4)
		tw.tween_method(_set_rot.bind(side), back, _rest_rot(side), sec * 0.6)
		_set_off(_rest_off(side), side)
	if big:
		_spark_seed += 1
		create_tween().tween_method(_set_spark, 0.0, 1.0, SPARK_SEC / maxf(rate, 1.0))


## 元素反应：盘沿按元素色晕一圈
func react(color: Color) -> void:
	if _winner != -2:
		return
	_ring_color = color
	create_tween().tween_method(_set_ring, 0.0, 1.0, REACT_SEC / maxf(rate, 1.0))


## 分胜负：[param winner] 0 = 左（自己）赢、1 = 右赢、-1 = 平局（两把都垂下）。
## [param animate] false = 不演，直接摆终态（跳过、拖到头、过场关着）
func set_final(winner: int, animate: bool = true) -> Tween:
	_winner = winner
	for s in 2:
		if _tweens[s] != null:
			(_tweens[s] as Tween).kill()
			_tweens[s] = null
		_flash[s] = 0.0
	_spark = -1.0
	_ring = -1.0
	var goals := []
	for s in 2:
		var dir := 1.0 if s == 0 else -1.0
		if s == winner:
			goals.append([deg_to_rad(-RAISE_DEG) * dir, Vector2(0, -4), 0.0])
		else:
			goals.append([deg_to_rad(DROP_DEG) * dir, Vector2(0, DROP_FALL), 1.0])
	if not animate:
		for s in 2:
			_rot[s] = goals[s][0]
			_off[s] = goals[s][1]
			_grey[s] = goals[s][2]
		queue_redraw()
		return null
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_parallel()
	for s in 2:
		tw.tween_method(_set_rot.bind(s), _rot[s], goals[s][0], FINAL_SEC)
		tw.tween_method(_set_off.bind(s), _off[s], goals[s][1], FINAL_SEC)
		tw.tween_method(_set_grey.bind(s), _grey[s], goals[s][2], FINAL_SEC)
	if winner >= 0:
		_glint_side = winner
		tw.chain().tween_method(_set_glint, 0.0, 1.0, GLINT_SEC)
		tw.chain().tween_callback(_set_glint.bind(-1.0))
	return tw


## 终局分了没有（测试看）：-2 = 没分
func winner() -> int:
	return _winner


## 某把剑现在的姿态（测试看）：转角（度）、位移、褪灰
func pose(side: int) -> Dictionary:
	return {"deg": rad_to_deg(_rot[side]), "offset": _off[side], "grey": _grey[side]}
#endregion


func _live(side: int) -> bool:
	return side >= 0 and side < 2 and _winner == -2 and is_visible_in_tree()


## 这把剑上一个动作没做完就打断（新的一下顶掉旧的，和 157 的反馈一个规矩）
func _fresh(side: int) -> Tween:
	if _tweens[side] != null:
		(_tweens[side] as Tween).kill()
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tweens[side] = tw
	return tw


func _set_rot(v: float, side: int) -> void:
	_rot[side] = v
	queue_redraw()


func _set_off(v: Vector2, side: int) -> void:
	_off[side] = v
	queue_redraw()


func _set_flash(v: float, side: int) -> void:
	_flash[side] = v
	queue_redraw()


func _set_grey(v: float, side: int) -> void:
	_grey[side] = v
	queue_redraw()


func _set_spark(v: float) -> void:
	_spark = v if v < 1.0 else -1.0
	queue_redraw()


func _set_glint(v: float) -> void:
	_glint = v if v < 1.0 else -1.0
	queue_redraw()


func _set_ring(v: float) -> void:
	_ring = v if v < 1.0 else -1.0
	queue_redraw()


func _draw() -> void:
	var k := size.x / SIDE
	if not has_layers():
		var whole := UiTheme.art_cached(WHOLE_ART)
		if whole != null:
			draw_texture_rect(whole, Rect2(Vector2.ZERO, size), false)
		return
	draw_texture_rect(UiTheme.art_cached(DISC_ART), Rect2(Vector2.ZERO, size), false)
	if _ring >= 0.0:
		var c := _ring_color
		c.a = 0.8 * (1.0 - _ring)
		draw_arc(size * 0.5, (52.0 + 6.0 * _ring) * k, 0.0, TAU, 48, c, 4.0 * k, true)
	# 赢的那把压在上面；没分时左剑在上（和原图一样：盘、右剑、左剑）
	var order := [1, 0] if _winner != 1 else [0, 1]
	for s in order:
		_draw_sword(s, k)
	if _spark >= 0.0:
		_draw_sparks(k)
	if _glint >= 0.0 and _glint_side >= 0:
		_draw_glint(k)


## 剑尖金光：横的一道，中心从护手沿剑身扫到剑尖（剑转过之后的位置），中途最亮
func _draw_glint(k: float) -> void:
	var tex := UiTheme.art_cached(GLINT_ART)
	if tex == null:
		return
	var xf := _sword_xform(_glint_side, k)
	var grip: Vector2 = GRIP[_glint_side]
	var tip: Vector2 = TIP[_glint_side]
	var at := (xf * (grip * k)).lerp(xf * (tip * k), 0.2 + 0.8 * _glint)
	var ts := tex.get_size() * k
	draw_texture_rect(tex, Rect2(at - ts * 0.5, ts), false, Color(1, 1, 1, sin(_glint * PI)))


func _sword_xform(s: int, k: float) -> Transform2D:
	var grip: Vector2 = GRIP[s] * k
	return Transform2D(_rot[s], grip + _off[s] * k) * Transform2D(0.0, -grip)


func _draw_sword(s: int, k: float) -> void:
	var tex := UiTheme.art_cached(ART[s])
	draw_set_transform_matrix(_sword_xform(s, k))
	var tint := Color.WHITE.lerp(GREY, _grey[s])
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false, tint)
	if _flash[s] > 0.0:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false, Color(1.6, 1.6, 1.6, _flash[s] * 0.7))
	draw_set_transform_matrix(Transform2D.IDENTITY)


## 六粒小菱形火星从交点往外迸，越飞越暗
func _draw_sparks(k: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _spark_seed
	var c0 := Color("f6d98a")
	for i in 6:
		var ang := TAU * i / 6.0 + rng.randf_range(-0.4, 0.4)
		var dist := (6.0 + 22.0 * _spark) * rng.randf_range(0.8, 1.2) * k
		var p := CROSS * k + Vector2.from_angle(ang) * dist
		var r := 2.6 * (1.0 - _spark * 0.6) * k
		var c := c0
		c.a = 1.0 - _spark
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 1.4), p + Vector2(r, 0), p + Vector2(0, r * 1.4), p + Vector2(-r, 0)]), c)
