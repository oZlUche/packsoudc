## 166（作者定）：顶端栏 —— 横贯顶部的一条底（主题变体 [constant UiTheme.PANEL_HUD_BAR]：美术的大理石九宫格，没图是半透明深底）。
## 它本身不写字：栏里摆什么由布局里锚在 `bar_left / bar_center / bar_right` 的条目决定（[HudHost] 排），
## 所以「摆读数」时照样能把东西拖进拖出、换槽，栏自己也能藏。大小由宿主定（整屏宽 × 栏高）；宿主把它排成第一个子节点，垫在栏里的组件下面
##
## 190（189 作者定案「乙」）：板上铺一条贯通的浅槽（`hud/groove` 九宫格，两端铜包角不拉伸，左右各留 [constant GROOVE_SIDE]），
## 栏里的件坐在槽底上；相邻两件之间一枚铜点（`hud/dot`，位置由宿主排完给 [method set_dots]）。没有槽图就不画，栏里的件退回各自的凹槽
extends HudWidget

const GROOVE_ART := "hud/groove"
const DOT_ART := "hud/dot"
## 槽图的原始高（`band` 按栏高等比缩）
const GROOVE_H := 88.0
const GROOVE_SIDE := 14.0

## 铜点的中心（栏的坐标）
var _dots: Array[Vector2] = []
var _groove_box: StyleBoxTexture = null


func _init() -> void:
	super()
	theme_type_variation = UiTheme.PANEL_HUD_BAR
	UiTheme.apply_tone(self, UiTheme.PANEL_HUD_BAR)     # 大理石是浅底：栏里直接挂的字跟着换墨色
	groovable = false
	_text.visible = false


func title() -> String:
	return "顶端栏"


func text_of() -> String:
	return "顶端栏"     # 只要这一局在就显示


func _sync_visible() -> void:
	visible = editing or (shown and run != null)


## 宿主按整屏宽摆它：最小尺寸不参与（不然一排读数会被它撑开）
func _get_minimum_size() -> Vector2:
	return Vector2.ZERO


## 有没有槽图
static func has_groove() -> bool:
	return UiTheme.art_cached(GROOVE_ART) != null


## 槽身的竖向范围（栏的坐标，按栏高 / [param bar_h] 等比缩）；`groove.json` 没写 `band` 按整高
static func band(bar_h: float) -> Vector2:
	var b: Array = UiTheme.art_meta(GROOVE_ART).get("band", [0, GROOVE_H])
	var k := bar_h / GROOVE_H if bar_h > 0.0 else 1.0
	return Vector2(float(b[0]) * k, float(b[1]) * k)


## 槽画在哪（栏的坐标）
func groove_rect() -> Rect2:
	return Rect2(GROOVE_SIDE, 0.0, maxf(0.0, size.x - GROOVE_SIDE * 2.0), size.y)


## 宿主排完给：铜点的中心
func set_dots(points: Array[Vector2]) -> void:
	_dots = points
	queue_redraw()


func dots() -> Array[Vector2]:
	return _dots


func _groove() -> StyleBoxTexture:
	var tex := UiTheme.art_cached(GROOVE_ART)
	if tex == null:
		return null
	if _groove_box == null or _groove_box.texture != tex:
		var m: Array = UiTheme.art_meta(GROOVE_ART).get("margin", [0, 0, 0, 0])
		_groove_box = StyleBoxTexture.new()
		_groove_box.texture = tex
		_groove_box.texture_margin_left = float(m[0])
		_groove_box.texture_margin_top = float(m[1])
		_groove_box.texture_margin_right = float(m[2])
		_groove_box.texture_margin_bottom = float(m[3])
	return _groove_box


## 板（面板底）先画，槽与铜点画在板上、栏里的件下面
func _draw() -> void:
	var box := _groove()
	if box != null:
		draw_style_box(box, groove_rect())
		var dot := UiTheme.art_cached(DOT_ART)
		if dot != null:
			for p in _dots:
				draw_texture(dot, (p - dot.get_size() * 0.5).round())
	super()
