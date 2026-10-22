## 166（作者定）：顶端栏 —— 横贯顶部的一条底。它本身不写字：栏里摆什么由布局里锚在 `bar_left / bar_center / bar_right` 的条目决定（[HudHost] 排），
## 所以「摆读数」时照样能把东西拖进拖出、换槽，栏自己也能藏。大小由宿主定（整屏宽 × 栏高）；宿主把它排成第一个子节点，垫在栏里的组件下面
##
## 235（作者 2026-10-22「按推荐来」）：石刻栏皮 —— 浅色石刻一整条，图与数值在 `hud/topbar/`（`topbar.json`）：
## 中间平铺段从日晷底座左右两边往外铺、只铺在两头之间；正中下半圆日晷底座（刻度在图里，扇面 / 指针 / 轴心归倒计时那件画，
## 底座下凸压在地图上、不占布局高度）；两头最后盖上去。两头是真按钮（[IconButton] 三态，热区是那块凸起的石块）：
## 左 = 本局菜单（等同 Esc），右 = 背包（右槽的小背包钮并进来了）。按下发 [signal end_pressed]，接到所在屏的 `hud_end(side)`。
## 两头不进 150 的布局（不能拖、不能藏）。缺皮退回主题变体的底（`slab_bar` 石板），两头照样在、写字
## 作者 10-22 13:31「两头的浮雕和下方边缘重合了，扩张顶端栏的下缘」：石面 86 → 100，回纹带挪到 y 87～95 整条贯通；
## 两头石块与读数仍在 y 8～78（[method band_margins] 按石块上下沿算，不按石面居中）
extends HudWidget

## 两头按下：[constant LEFT] / [constant RIGHT]
signal end_pressed(side: StringName)

const SKIN := "hud/topbar/"
const LEFT := &"left"
const RIGHT := &"right"

## side → 那一头的按钮
var _ends: Dictionary = {}
var _meta: Dictionary = {}


func _init() -> void:
	super()
	theme_type_variation = UiTheme.PANEL_HUD_BAR
	UiTheme.apply_tone(self, UiTheme.PANEL_HUD_BAR)
	_text.visible = false
	_meta = skin()
	# 两头放在一块不排版的底上（栏是 PanelContainer，直接挂的子节点会被撑满）
	var box := Control.new()
	box.name = "Ends"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	resized.connect(_place_ends)     # 按栏宽摆（底空着，那块底和栏一样大；不等容器排）
	var bag := UiText.t("map.bag") + UiText.t("ui.hotkey") % "B" + "\n" + UiText.t("map.bag_hint")
	var menu := UiText.t("map.menu_end") + UiText.t("ui.hotkey") % "Esc" + "\n" + UiText.t("map.menu_end_hint")
	for side in [LEFT, RIGHT]:
		var b := IconButton.make_art(UiTheme.asset_root + SKIN, "end_" + String(side), UiText.t("map.menu_end" if side == LEFT else "map.bag"),
			menu if side == LEFT else bag, func(): end_pressed.emit(side))
		b.name = "End_" + String(side)
		var hit: Array = (_meta.get("ends", {}) as Dictionary).get("hit_" + String(side), [])
		if hit.size() == 4 and b.has_art():
			b.hit_rect = Rect2(float(hit[0]), float(hit[1]), float(hit[2]) - float(hit[0]), float(hit[3]) - float(hit[1]))
		box.add_child(b)
		_ends[side] = b


func title() -> String:
	return "顶端栏"


func text_of() -> String:
	return "顶端栏"     # 只要这一局在就显示


## 两头接到所在屏（地图屏：左 = 暂停菜单，右 = 背包）
func setup(p_run: RunState, p_screen: Control) -> void:
	super(p_run, p_screen)
	if p_screen != null and p_screen.has_method("hud_end") and not end_pressed.is_connected(p_screen.hud_end):
		end_pressed.connect(p_screen.hud_end)


func _sync_visible() -> void:
	visible = editing or (shown and run != null)


## 宿主按整屏宽摆它：最小尺寸不参与（不然一排读数会被它撑开）
func _get_minimum_size() -> Vector2:
	return Vector2.ZERO


#region 皮
## `topbar.json`（没有 = 空）
static func skin() -> Dictionary:
	return UiTheme.art_meta(SKIN + "topbar")


## 石刻皮的图在不在（平铺段与日晷底座）
static func has_skin() -> bool:
	return UiTheme.art_cached(SKIN + "bar_tile") != null and UiTheme.art_cached(SKIN + "dial_base") != null


## 石面多高（栏在布局里占的高；投影与日晷下凸不算）
static func design_height() -> float:
	return float(skin().get("design_height", 100))


## 栏里的组左右各让多宽：石块外沿 + 间隙（左 88 + 12，右 104 − 16 + 12）
static func side_inset() -> float:
	var m := skin()
	var ends: Dictionary = m.get("ends", {})
	var w := float(ends.get("width", 104))
	var gap := float(m.get("gap", 12))
	var hl: Array = ends.get("hit_left", [8, 8, 88, 78])
	var hr: Array = ends.get("hit_right", [16, 8, 96, 78])
	return maxf(float(hl[2]) + gap, w - float(hr[0]) + gap)


## 栏里的组竖向居中的那一段的上、下留白（石块的上下沿）
static func band_margins() -> Vector2:
	var hl: Array = (skin().get("ends", {}) as Dictionary).get("hit_left", [8, 8, 88, 78])
	return Vector2(float(hl[1]), design_height() - float(hl[3]))


## 日晷底座下凸的石面下沿（栏的坐标；下面还有一截投影）。告示卷排在它下面
static func dial_bottom() -> float:
	return float((skin().get("dial", {}) as Dictionary).get("bottom", 124))


## 日晷轴心（栏的坐标）
func dial_pivot() -> Vector2:
	var d: Dictionary = _meta.get("dial", {})
	var p: Array = d.get("pivot", [151, 6])
	return Vector2(roundf(size.x * 0.5) - float(d.get("center_x", 151)) + float(p[0]), float(p[1]))


## 日晷的数（`topbar.json` 的 `dial`）
func dial_meta() -> Dictionary:
	return _meta.get("dial", {})
#endregion


## 那一头的按钮（测试与教程挖洞用）
func end_button(side: StringName) -> IconButton:
	return _ends.get(side, null)


## 那一头能点的那块（屏幕坐标；教程挖洞）
func end_rect(side: StringName) -> Rect2:
	var b := end_button(side)
	if b == null or not b.is_visible_in_tree():
		return Rect2()
	var r := b.get_global_rect()
	return Rect2(r.position + b.hit_rect.position, b.hit_rect.size) if b.hit_rect.has_area() else r


func _place_ends() -> void:
	var w := size.x
	for side in _ends:
		var b := _ends[side] as IconButton
		b.size = b.get_combined_minimum_size()
		b.position = Vector2(0.0 if side == LEFT else w - b.size.x, 0.0)


## 平铺段（从日晷两边往外、只铺在两头之间）→ 日晷底座；两头是子节点，画在上面
func _draw() -> void:
	var tile := UiTheme.art_cached(SKIN + "bar_tile")
	var dial := UiTheme.art_cached(SKIN + "dial_base")
	if tile != null and dial != null:
		var ew := float((_meta.get("ends", {}) as Dictionary).get("width", 104))
		var tw := tile.get_width()
		var th := tile.get_height()
		var dx := roundf(size.x * 0.5) - float(dial_meta().get("center_x", 151))
		var x := dx + dial.get_width()
		while x < size.x - ew:
			var w := minf(tw, size.x - ew - x)
			draw_texture_rect_region(tile, Rect2(x, 0, w, th), Rect2(0, 0, w, th))
			x += tw
		x = dx
		while x > ew:
			var w := minf(tw, x - ew)
			draw_texture_rect_region(tile, Rect2(x - w, 0, w, th), Rect2(tw - w, 0, w, th))
			x -= tw
		draw_texture(dial, Vector2(dx, 0))
	super()
