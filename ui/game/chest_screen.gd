## 宝箱屏（154，作者定）：叠在地图上的一层，整屏背景随地图（章节的宝箱皮肤），中央一只放在地上的宝箱。
##
## 「点击宝箱开锁」：在宝箱上按下鼠标左键（或按住确认键，动作 `confirm`，默认空格 / 回车）—— 锁孔处出现开锁动画、锁孔外一圈环形进度条顺时针走；
## 按着的时候播「尝试开锁」，松手按二倍速回退（[LockHold]）。走满了环消失、宝箱打开，然后弹出搜索界面（[method GameFlow.open_chest]）。
## 越好的宝箱按得越久（[member ChestRules.hold_seconds]）。没开锁就走（Esc / 回地图）点不算用过。
## 154 补充一（作者定）：鼠标按着移出宝箱不算松手，只有松开才算。
##
## 美术还在画：皮肤里缺的图一律画占位（深底、方块宝箱随稀有度换色、圆锁孔），交互照样跑。不新增主题覆写，图形全在画布上。
extends GameScreen

## 宝箱打开之后（开箱序列帧播完，或没有序列帧时一开就算）停多久再弹搜索界面（秒）。
## 作者定（154）：开了的箱子里面一片漆黑，不显示里面的东西，停顿片刻再弹搜索界面
const OPEN_PAUSE_SECONDS := 0.45
## 没有闭箱图时占位宝箱的大小
const PLACEHOLDER_SIZE := Vector2(280, 220)

const TEXT_IDLE := "点击宝箱开锁"
const TEXT_TRYING := "尝试开锁"

var node: MapNode = null
var rarity: int = 0
var skin: ChestSkinDef = null
var hold: LockHold = null
## 中央画宝箱的那块画布
var view: ChestView = null
## 宝箱下面那一行字
var hint: Label = null
## 锁开了、开箱动画在播
var opening: bool = false
## 已经交给流程开搜索了（只交一次）
var _handed: bool = false
var _open_time: float = 0.0
## 谁按着：鼠标、确认键（两个都松了才算松手）
var _by_mouse: bool = false
var _by_key: bool = false
var _unlock_strip: FrameStrip = null
var _trying_strip: FrameStrip = null
var _open_strip: FrameStrip = null
var _closed_tex: Texture2D = null
var _open_tex: Texture2D = null


func open(payload: Dictionary) -> void:
	node = payload.get("node", null)
	if node == null and flow != null and flow.run != null:
		node = flow.run.current_node()
	rarity = ChestPlacer.rarity_of(node)
	skin = _load_skin(ChestPlacer.skin_of(node))
	var seconds := 1.0
	var decay := 2.0
	if flow != null and flow.run != null:
		seconds = flow.run.events.chest_hold_seconds(node)
		decay = flow.run.events.chest_rules().release_decay
	hold = LockHold.new(seconds, decay)
	_closed_tex = EventImage.load_texture(skin.closed_for(rarity))
	_open_tex = EventImage.load_texture(skin.open_for(rarity))
	_unlock_strip = FrameStrip.from_paths(skin.unlock_frames, skin.unlock_fps)
	_trying_strip = FrameStrip.from_paths(skin.trying_frames, skin.trying_fps)
	_open_strip = FrameStrip.from_paths(skin.open_frames, skin.open_fps, true)

	_backdrop(Color("0d0f12"))     # 叠层挡住底下的地图；有背景图就盖在上面
	var bg_tex := EventImage.load_texture(skin.background)
	if bg_tex != null:
		var bg := TextureRect.new()
		bg.texture = bg_tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

	var center := _full_center()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := _vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	var title := _label("%s宝箱" % ItemTooltip.rarity_name(rarity), 16, ItemPainter.RARITY_COLORS[rarity])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	view = ChestView.new()
	view.screen = self
	view.custom_minimum_size = _closed_tex.get_size() if _closed_tex != null else PLACEHOLDER_SIZE
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(view)
	hint = UiTheme.make_display(TEXT_IDLE, 28)     # 168：说明字是马善政
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

	var back := _button("回地图", leave, 13, UiPalette.Tier.MINOR)
	back.focus_mode = Control.FOCUS_NONE     # 确认键是开锁键，别让按钮抢走
	back.tooltip_text = "没开锁就走：这个点不算用过，站着或回来还能再开（Esc）"
	add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)


static func _load_skin(id: StringName) -> ChestSkinDef:
	var res := ContentPaths.load_asset("chest_skins", String(id)) if id != &"" else null
	if res == null and id != &"ruins":
		res = ContentPaths.load_asset("chest_skins", "ruins")
	return res as ChestSkinDef if res is ChestSkinDef else ChestSkinDef.new()


#region 公开动作（测试直接调）
## 按下（鼠标在宝箱上按下 / 确认键按下）
func press(by_key: bool = false) -> bool:
	if hold == null or opening:
		return false
	if by_key:
		_by_key = true
	else:
		_by_mouse = true
	if hold.press():
		_unlock_strip.reset()
		_trying_strip.reset()
	_refresh_hint()
	return true


## 松手（两路都松了才真松）
func release(by_key: bool = false) -> bool:
	if hold == null:
		return false
	if by_key:
		_by_key = false
	else:
		_by_mouse = false
	if _by_key or _by_mouse:
		return false
	var changed := hold.release()
	_refresh_hint()
	return changed


## 推进 [param delta] 秒（`_process` 每帧调；测试一步推完）
func step(delta: float) -> void:
	if hold == null or _handed:
		return
	if opening:
		_open_time += delta
		_open_strip.advance(delta)
		var done := _open_time >= _open_strip.duration() + OPEN_PAUSE_SECONDS     # 没有序列帧时 duration 为 0
		if done:
			_hand_over()
		view.queue_redraw()
		return
	if hold.is_holding():
		_unlock_strip.advance(delta)
		_trying_strip.advance(delta)
	if hold.advance(delta):
		opening = true
		_by_mouse = false
		_by_key = false
		_open_strip.reset()
	_refresh_hint()
	view.queue_redraw()


## 没开锁就走（回退中也能走；按着的时候不走）
func leave() -> bool:
	if hold == null or not hold.can_leave() or opening:
		return false
	return flow.leave_chest()
#endregion


func _hand_over() -> void:
	_handed = true
	flow.open_chest(node)


func _refresh_hint() -> void:
	if hint == null:
		return
	if opening or hold.is_unlocked():
		hint.text = ""
	elif hold.is_holding():
		hint.text = TEXT_TRYING
	else:
		hint.text = TEXT_IDLE


func _process(delta: float) -> void:
	step(delta)


func _input(event: InputEvent) -> void:
	if hold == null or _handed:
		return
	var key := event as InputEventKey
	if key != null and not key.echo and key.is_action(InputKeys.CONFIRM):     # 154 补充一：确认键（可改键）
		if key.pressed:
			press(true)
		else:
			release(true)
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _by_mouse:
		release()     # 松在哪儿都算松手；按着移出宝箱不算（154 补充一）


## 090：Esc —— 按着先松手；没按着就回地图
func escape() -> bool:
	if hold == null:
		return false
	if hold.is_holding():
		_by_mouse = false
		_by_key = false
		hold.release()
		_refresh_hint()
		return true
	leave()
	return true


## 中央的宝箱：有图画图，没图画占位；锁孔处的开锁动画与进度环
class ChestView extends Control:
	var screen: Node = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	## 宝箱的矩形（本地坐标）：就是这块画布
	func chest_rect() -> Rect2:
		return Rect2(Vector2.ZERO, size)

	## 锁孔（本地坐标）：皮肤给了按皮肤；占位时在箱体中下
	func lock_point() -> Vector2:
		var s: ChestSkinDef = screen.skin
		if screen._closed_tex != null and s != null and s.lock_offset != Vector2.ZERO:
			return s.lock_offset
		return Vector2(size.x * 0.5, size.y * 0.58)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and chest_rect().has_point(mb.position):
			screen.press()
			accept_event()

	func _draw() -> void:
		var hold: LockHold = screen.hold
		if hold == null:
			return
		var opened: bool = screen.opening
		var shake := Vector2.ZERO
		var trying: FrameStrip = screen._trying_strip
		if hold.is_holding() and trying.is_empty():
			# 「尝试开锁」占位：箱子轻轻抖
			var t := Time.get_ticks_msec() / 1000.0
			shake = Vector2(sin(t * 38.0), cos(t * 31.0)) * 1.6
		draw_set_transform(shake)
		if opened:
			_draw_opened()
		elif screen._closed_tex != null:
			draw_texture_rect(screen._closed_tex, chest_rect(), false)
		else:
			_draw_placeholder()
		draw_set_transform(Vector2.ZERO)
		if opened:
			return
		var s: ChestSkinDef = screen.skin
		var lock := lock_point()
		if hold.is_holding() and not trying.is_empty():
			_draw_centered(trying.frame(), size * 0.5)
		if hold.is_holding() or hold.progress > 0.0:
			var unlock: FrameStrip = screen._unlock_strip
			if hold.is_holding():
				if not unlock.is_empty():
					_draw_centered(unlock.frame(), lock)
				else:
					# 「开锁」占位：锁孔里一根拨片来回转
					var a := sin(Time.get_ticks_msec() / 1000.0 * 9.0) * 0.6 - PI * 0.5
					draw_line(lock, lock + Vector2.from_angle(a) * 18.0, Color("e8e2d0"), 2.0)
			UiDraw.ring(self, lock, s.ring_radius, hold.progress, Color(0, 0, 0, 0.55), Color("ffd23f"), s.ring_width, s.ring_width + 2.0, 64)

	func _draw_centered(tex: Texture2D, at: Vector2) -> void:
		if tex != null:
			draw_texture(tex, at - tex.get_size() * 0.5)

	## 占位宝箱：地上的影子、箱体、箱盖、包边随稀有度换色、锁片和圆锁孔
	func _draw_placeholder() -> void:
		var r: int = screen.rarity
		var trim: Color = ItemPainter.RARITY_COLORS[r]
		var wood := Color("5a3b22").lerp(Color("2e2a3a"), r / 5.0 * 0.6)
		var w := size.x
		var h := size.y
		_draw_shadow()
		var body := Rect2(w * 0.1, h * 0.42, w * 0.8, h * 0.46)
		var lid := Rect2(w * 0.08, h * 0.16, w * 0.84, h * 0.28)
		draw_rect(body, wood, true)
		draw_rect(lid, wood.lightened(0.08), true)
		for rect in [body, lid]:
			draw_rect(rect, trim.darkened(0.25), false, 3.0)
		# 竖向包边：越稀有越多道
		var bands := 2 + floori(r / 2.0)
		for i in bands:
			var x := w * 0.1 + w * 0.8 * (i + 1) / (bands + 1)
			draw_rect(Rect2(x - 4.0, lid.position.y, 8.0, body.end.y - lid.position.y), trim.darkened(0.15), true)
		var lock := lock_point()
		draw_rect(Rect2(lock - Vector2(16, 18), Vector2(32, 38)), trim.lightened(0.15), true)
		draw_circle(lock, 6.0, Color("0b0b0d"))
		draw_rect(Rect2(lock + Vector2(-2, 2), Vector2(4, 10)), Color("0b0b0d"), true)

	func _draw_shadow() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.9)
		draw_set_transform(c, 0.0, Vector2(1.0, 0.18))
		draw_circle(Vector2.ZERO, size.x * 0.46, Color(0, 0, 0, 0.45))
		draw_set_transform(Vector2.ZERO)

	## 开箱：有开箱序列帧播帧；没有就用开箱图；再没有画占位（掀起的盖子、箱口一片漆黑 —— 作者定：不显示里面的东西，也不透光）
	func _draw_opened() -> void:
		var strip: FrameStrip = screen._open_strip
		if not strip.is_empty():
			draw_texture_rect(strip.frame(), chest_rect(), false)
			return
		if screen._open_tex != null:
			draw_texture_rect(screen._open_tex, chest_rect(), false)
			return
		var r: int = screen.rarity
		var trim: Color = ItemPainter.RARITY_COLORS[r]
		var wood := Color("5a3b22").lerp(Color("2e2a3a"), r / 5.0 * 0.6)
		var w := size.x
		var h := size.y
		_draw_shadow()
		var lid := Rect2(w * 0.08, h * 0.04, w * 0.84, h * 0.2)     # 掀起来立在后面的盖子
		var mouth := Rect2(w * 0.1, h * 0.24, w * 0.8, h * 0.18)     # 箱口：一片漆黑
		var body := Rect2(w * 0.1, h * 0.42, w * 0.8, h * 0.46)
		draw_rect(lid, wood.darkened(0.15), true)
		draw_rect(lid, trim.darkened(0.25), false, 3.0)
		draw_rect(mouth, Color.BLACK, true)
		draw_rect(body, wood, true)
		draw_rect(body, trim.darkened(0.25), false, 3.0)
