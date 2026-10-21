## 231：界面过渡的小工具 —— 淡、升、展旗、开卷、弹出、滑入。每个都先问 [param on]（宿主用 [method enabled] 算好传进来）：
## 关着就直接置终态、返回 null；开着返回 Tween 便于串接。
##
## 守则（作者 2026-10-21 要的过渡动画，231 §四）：
## 1. 一倍速下单步 ≤ 0.6 s、一串 ≤ 1.5 s；能点的东西出现就能点（展开中的旗除外）。
## 2. 回放相关的动效不改结果、不改时序：跳过 = 终态，倍速 = 时长除以倍速。
## 3. 设置 `ui_fades` 关 / [member GameDirector.fades_allowed] 关（测试、截图）→ 全部 0 秒直接终态。
## 4. 只动位移 / 透明 / 裁切 / 旋转 / 缩放；不做帧动画。
## 5. 古风：ease-out 为主、幅度小（位移 ≤ 24 px、缩放 ≤ 4%）、不弹跳（CUBIC，不用 BACK / ELASTIC）。
class_name UiMotion
extends RefCounted

## 展旗：裁切显出多久、末尾两下轻摆多久、摆几度
const UNFURL_SEC := 0.35
const SWAY_SEC := 0.25
const SWAY_DEG := 2.0
## 裁切显出：按控件自己的本地坐标裁（贴图的 UV 不一定铺满控件）。子节点不跟着裁
const CLIP_SHADER := """
shader_type canvas_item;
uniform float amount = 1.0;
uniform vec2 box = vec2(1.0);
uniform bool horizontal = false;
varying vec2 local;
void vertex() { local = VERTEX; }
void fragment() {
	if (horizontal ? abs(local.x - box.x * 0.5) > amount * box.x * 0.5 : local.y > amount * box.y) discard;
}
"""
static var _clip_shader: Shader = null


## 动不动：测试 / 截图开关与玩家设置都开着才动
static func enabled(settings: GameSettings) -> bool:
	return GameDirector.fades_allowed and (settings == null or settings.ui_fades)


static func _tween(c: Control) -> Tween:
	return c.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 透明度 from → to
static func fade(c: Control, on: bool, from: float, to: float, sec: float = 0.2) -> Tween:
	c.modulate.a = to
	if not on:
		return null
	c.modulate.a = from
	var tw := _tween(c)
	tw.tween_property(c, "modulate:a", to, sec)
	return tw


## 从下面 [param dy] 处升上来（同时淡入）。容器里的控件用它前先确认排版已定（位置是排好的那个）
static func rise(c: Control, on: bool, dy: float = 12.0, sec: float = 0.25) -> Tween:
	if not on:
		c.modulate.a = 1.0
		return null
	var end := c.position
	c.position = end + Vector2(0, dy)
	c.modulate.a = 0.0
	var tw := _tween(c).set_parallel()
	tw.tween_property(c, "position", end, sec)
	tw.tween_property(c, "modulate:a", 1.0, sec * 0.8)
	return tw


## 控件身上挂一块裁切材质（已有就用那块）；[param amount] 1 = 全显
static func _clip(c: Control, amount: float, horizontal: bool = false) -> ShaderMaterial:
	if _clip_shader == null:
		_clip_shader = Shader.new()
		_clip_shader.code = CLIP_SHADER
	var m := c.material as ShaderMaterial
	if m == null or m.shader != _clip_shader:
		m = ShaderMaterial.new()
		m.shader = _clip_shader
		c.material = m
	m.set_shader_parameter("box", c.size if c.size != Vector2.ZERO else c.get_combined_minimum_size())
	m.set_shader_parameter("horizontal", horizontal)
	m.set_shader_parameter("amount", amount)
	return m


## 裁切到头了就把材质摘掉（终态和没动过一样）
static func _unclip(c: Control) -> void:
	var m := c.material as ShaderMaterial
	if m != null and m.shader == _clip_shader:
		c.material = null


## 现在显出了几成（测试看）：没挂裁切 = 1
static func revealed(c: Control) -> float:
	var m := c.material as ShaderMaterial
	return float(m.get_shader_parameter("amount")) if m != null and m.shader == _clip_shader else 1.0


## 展旗：挂杆在上，旗面从上往下显出（裁切），末尾绕旗顶中点两下轻摆。展开中点不着
static func unfurl(c: Control, on: bool, sec: float = UNFURL_SEC, sway: bool = true) -> Tween:
	if not on:
		_unclip(c)
		c.rotation = 0.0
		return null
	var btn := c as BaseButton
	var was_disabled := btn.disabled if btn != null else false
	if btn != null:
		btn.disabled = true
	var clip := _clip(c, 0.0)
	c.pivot_offset = Vector2(c.size.x * 0.5, 0.0)
	var tw := _tween(c)
	tw.tween_property(clip, "shader_parameter/amount", 1.0, sec)
	tw.tween_callback(_unclip.bind(c))
	if sway:
		var r := deg_to_rad(SWAY_DEG)
		tw.tween_property(c, "rotation", r, SWAY_SEC * 0.3).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(c, "rotation", -r * 0.5, SWAY_SEC * 0.4).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(c, "rotation", 0.0, SWAY_SEC * 0.3).set_ease(Tween.EASE_IN_OUT)
	if btn != null:
		tw.tween_callback(func(): btn.disabled = was_disabled)
	return tw


## 收旗：展旗倒放（不摆）
static func furl(c: Control, on: bool, sec: float = 0.2) -> Tween:
	var clip := _clip(c, 1.0)
	if not on:
		clip.set_shader_parameter("amount", 0.0)
		return null
	var tw := _tween(c).set_ease(Tween.EASE_IN)
	tw.tween_property(clip, "shader_parameter/amount", 0.0, sec)
	return tw


## 开卷：从正中往左右两边显出（226 告示签那种横向卷轴）
static func unroll(c: Control, on: bool, sec: float = 0.25) -> Tween:
	if not on:
		_unclip(c)
		return null
	var clip := _clip(c, 0.0, true)
	var tw := _tween(c)
	tw.tween_property(clip, "shader_parameter/amount", 1.0, sec)
	tw.tween_callback(_unclip.bind(c))
	return tw


## 弹出：0.96 → 1 + 淡入（叠层窗、新点亮的东西）
static func pop(c: Control, on: bool, sec: float = 0.18) -> Tween:
	if not on:
		c.scale = Vector2.ONE
		c.modulate.a = 1.0
		return null
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * 0.96
	c.modulate.a = 0.0
	var tw := _tween(c).set_parallel()
	tw.tween_property(c, "scale", Vector2.ONE, sec)
	tw.tween_property(c, "modulate:a", 1.0, sec)
	return tw


## 滑入：从 [param dx] 处横着滑回原位 + 淡入（翻页方向随正负）
static func slide(c: Control, on: bool, dx: float = 24.0, sec: float = 0.2) -> Tween:
	if not on:
		c.modulate.a = 1.0
		return null
	var end := c.position
	c.position = end + Vector2(dx, 0)
	c.modulate.a = 0.0
	var tw := _tween(c).set_parallel()
	tw.tween_property(c, "position", end, sec)
	tw.tween_property(c, "modulate:a", 1.0, sec)
	return tw
