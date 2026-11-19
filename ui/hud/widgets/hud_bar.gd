## 166（作者定）：顶端栏 —— 横贯顶部的一条底。它本身不写字：栏里摆什么由布局里锚在 `bar_left / bar_center / bar_right` 的条目决定（[HudHost] 排），
## 所以「摆读数」时照样能把东西拖进拖出、换槽，栏自己也能藏。大小由宿主定（整屏宽 × 栏高）；宿主把它排成第一个子节点，垫在栏里的组件下面
##
## 顶栏沿用两端三态按钮与原有热区；中段为深色珐琅量尺，浅色凹槽承载资源。
## 完整日晷由倒计时组件绘制，收在顶栏以内；当组件挪动或隐藏时，晷面跟随它。
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
		if hit.size() == 4:
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


## 默认居中布局的日晷轴心（栏的坐标）
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


## 深色珐琅横梁把浅色资源凹槽与两端的金属操作钮分开。
func _draw() -> void:
	var tile := UiTheme.art_cached(SKIN + "bar_tile")
	if tile != null:
		var tw := tile.get_width()
		var th := tile.get_height()
		var x := 0.0
		while x < size.x:
			var width := minf(tw, size.x - x)
			draw_texture_rect_region(tile, Rect2(x, 0, width, th), Rect2(0, 0, width, th))
			x += width
	var inset := float((_meta.get("ends", {}) as Dictionary).get("width", 104))
	var width := maxf(0, size.x - inset * 2)
	var extra := maxf(0, size.y - design_height())
	if width > 0:
		draw_rect(Rect2(inset, 2, width, 82 + extra), Color("263b3d"))
		draw_rect(Rect2(inset, 4, width, 1), Color("a58b5f"))
		draw_rect(Rect2(inset, 6, width, 1), Color("536050"))
		# 横穿金属面的细划线与分度刻痕，在状态与动作之间留出安静的读数区。
		var y := 43.0 + extra * 0.5
		draw_line(Vector2(inset, y), Vector2(size.x - inset, y), Color("43524a"), 1.0)
		for x in range(int(inset) + 15, floori(size.x - inset), 28):
			draw_line(Vector2(x, y - 2), Vector2(x, y + 2), Color("637062"), 1.0)
		draw_rect(Rect2(inset, 79 + extra, width, 1), Color("768171"))
		draw_rect(Rect2(inset, 82 + extra, width, 2), Color("a48d64"))
	super()
