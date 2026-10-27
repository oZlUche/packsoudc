## 场景流里每一屏的底座（架构文档 8 节，M6）。
##
## 导演造它、给它 [member flow] 与字体、加进树、调 [method open]。屏只做两件事：把 flow 的状态画出来；
## 把玩家的动作转成 flow 的方法调用（1.2 命令进、信号出）。屏不认识导演 —— 需要导演做的事发信号。
##
## 全屏铺满；叠层（战斗、战利品……）在 [method _backdrop] 上再摆一块面板，底下的地图还在、镜头还在。
class_name GameScreen
extends Control

const InventoryPanelScript := preload("res://ui/game/inventory_panel.gd")

## 这一屏是 GameFlow.Screen 里的哪个，导演设
var screen: int = -1
var flow: GameFlow = null
var font: Font = null
## 091：底屏 / 叠层的整块底色（跟设置里的底色走）；换了底色 [method refresh_backdrop] 刷
var _bg_rect: ColorRect = null
## 盖住整屏的那一层拖拽（节点屏由 [method _mount_bag] 造；开局屏自己造一层盖在格子上）
var _drag: DragLayer = null
## 停在道具上的悬浮说明（节点屏由 [method _mount_bag] 造；地图屏的背包浮窗自己造）
var _tip: HoverTip = null
## 157：叠层的石板框（[method _centered_panel] 造）；底屏没有
var _overlay_frame: OverlayFrame = null
## 157 补充三：底屏的那一整块大石板（[method _slab_screen] 造）；叠层、基地、地图没有
var _screen_slab: PanelContainer = null
## 179：整屏一幅画时的内容区（[method _painted_screen] 造）；别的屏没有
var _painted: Control = null

## 226 批一：没有导演时这一屏自己挂的告示层（[method notice_layer]）
var _own_notices: NoticeLayer = null

## 157 补充三：底屏的大石板占屏幕多少（宽高各九成、居中，板外是纯色底）
const SLAB_SHARE := 0.9
## 叠层的暗罩（底下的地图压暗透出来，石板像浮在地图上）
const OVERLAY_SHADE := 0.6


func _ready() -> void:
	if font == null:
		font = UiPalette.cjk_font()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## 226 批一（作者「去掉所有界面里的裸露文字」）：这一屏的回话都走告示层 —— 导演盖在所有屏上的那层（[method NoticeLayer.current]），
## 没有导演（单测里单独造的屏）就在屏上自己挂一层
func notice_layer() -> NoticeLayer:
	var layer := NoticeLayer.current()
	if layer != null:
		return layer
	if not is_instance_valid(_own_notices) or _own_notices.get_parent() != self:
		_own_notices = NoticeLayer.new()
		_own_notices.z_index = 50
		add_child(_own_notices)
	return _own_notices


## 给玩家的一句（告示卷轴）
func say(text: String) -> void:
	notice_layer().push(text, false, notice_cap(), notice_beside(), notice_top())


## 要紧的一句（朱红卷、停得久）
func warn(text: String) -> void:
	notice_layer().push(text, true, notice_cap(), notice_beside(), notice_top())


## 这一屏告示最多叠几卷：帐篷（233）窗顶紧挨顶端栏，第二卷会压住布招牌 —— 只留一卷，新的顶掉旧的
func notice_cap() -> int:
	return 1 if _overlay_frame != null and (_overlay_frame.tent or _overlay_frame.stele) else NoticeLayer.MAX_LINES


## 告示卷从屏中线往右多远起排（0 = 居中）：神坛碑顶的神徽正在卷的位置上，卷挪到碑顶右边（同样只留一卷）
func notice_beside() -> float:
	return _overlay_frame.notice_beside() if _overlay_frame != null else 0.0


## 告示卷顶离屏顶多远（0 = 照 [constant NoticeLayer.TOP]）。235：地图屏让开顶端栏的日晷下凸（叠层屏的窗盖着日晷，照旧）
func notice_top() -> float:
	return 0.0


## 236 第三项：这一屏（叠层）自己铺满整屏、把底下的地图完全挡住（铸炉、营地、宝箱）—— 导演等它完全显出来就把底屏藏起来、停掉。
## 透出地图的叠层（铜面板的战前 / 战斗 / 搜索、事件书、帐篷、石碑、石板窗……）保持 false
func covers_base() -> bool:
	return false


## 236 第三项：上面压着一层透出这一屏的叠层（导演设）。地图屏借它隔帧重绘
func set_overlaid(_on: bool) -> void:
	pass


## 第一次显示。[param payload] 是 flow 给的（战斗结果、会话……）
func open(_payload: Dictionary) -> void:
	pass


## 叠层撤掉、又回到这一屏时刷一下（只有地图会这样）
func refresh() -> void:
	pass


## 090（作者定）：Esc 的通用「返回」。导演按了 Esc 先问最上面的叠层、没叠层问底屏；返回接不接。
## 叠层：搜索 / 商店 / 战利品收起回地图（最小化），事件屏关背包、结果页继续；底屏：地图关对话框 / 背包，开局 / 基地 / 设置 / 读取存档回主菜单。
## 默认不接（战前准备与等着选的事件必须处理，主菜单没有可回的）
func escape() -> bool:
	return false


## 134（作者定）：没有面板接的时候，地上的一件被双击了 —— 有背包按钮的屏「进包 + 打开背包」（放不下就只开背包）。
## 导演只在没有面板接地上（[method GroundLayer.top_drag] 为空）时转给最上面那一屏。返回接没接；默认不接（没有背包按钮的屏）
func ground_double_clicked(_uid: int) -> bool:
	return false


## 134：「进包 + 打开背包」的那一套，有背包浮窗的屏（地图、事件）共用：先试着进棋盘，**无论成败都打开背包**；
## 放不下就让面板提示一句。[param open_bag] 打开背包并返回那块 [InventoryPanel]
func _ground_to_bag(uid: int, open_bag: Callable) -> bool:
	var run := flow.run if flow != null else null
	if run == null or run.storage == null or run.board == null:
		return false
	var inst := run.storage.get_item(uid)
	if inst == null:
		return false
	var moved := InventoryService.transfer_auto(run.storage, uid, run.board)
	var panel = open_bag.call()
	if not moved and panel != null and panel.has_method("say_no_room"):
		panel.say_no_room(inst)
	return true


## 节点屏（神坛 / 保险箱 / 容器 / 商店）右边的背包一次装好：面板（棋盘 + 地上）、盖住整屏的拖拽层、停在道具上的悬浮窗。
## [param other] 是左边对面的那块视图（祭品台 / 保险箱 / 容器 / 出售区）：登记到拖拽层、由悬浮窗盯着；
## [param hint_sink] 接面板的提示（`func(text: String)`）；[param quick_target] 是棋盘上双击的去处（商店没有）。
## 加进树的顺序就是 z 序：面板进 [param row] → 拖拽层 → 悬浮窗，拖拽层要在面板之后加才盖得住。
## 各屏自己的规矩（`drop_filter`、`can_show`……）回来之后接到 [member _drag] / [member _tip] 上。
## 227：棋盘套 [param frame] 外框（[method BoardFrame.wrap]，[param dark] 是铜面板 / 夜里那套深色框）；空串 = 屏自己摆框（搜刮屏）
func _mount_bag(row: Control, other: ContainerView, hint_sink: Callable, quick_target: ItemContainer = null, frame: String = "player", dark: bool = false) -> InventoryPanelScript:
	var inv := InventoryPanelScript.new()
	_drag = DragLayer.new()
	_drag.label_font = font
	inv.setup(flow.run, font, _drag)
	if frame != "":
		BoardFrame.wrap(inv.board_view, frame, dark)
		if not dark:
			BoardFrame.brown(inv.board_view)     # 作者 10-27：局内玩家棋盘统一棕底
		inv.hold_nine()     # 255 补充一：面板按九格定宽（搜刮屏自己摆框、自己留位）
	inv.quick_target = quick_target
	inv.hint_sink = hint_sink
	row.add_child(inv)
	_drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_drag)
	_drag.register_view(other)
	_tip = HoverTip.new()
	add_child(_tip)
	_tip.watch(other)
	return inv


## 230：这块视图上的悬浮窗按钮只有一颗「双击做的那件事」（取回、拾取……），点了走同一条双击的路
func _tip_double(view: ContainerView, label_key: String) -> void:
	view.actions_for = func(uid: int) -> Array:
		return [ItemActions.make(&"quick", UiText.t(label_key), func(): view.item_double_clicked.emit(view, uid))]


## 230：棋盘上「双击做的那件事」那颗按钮换个名字（放进保险箱、放上祭品台……）；[param ok] = `func(inst) -> String` 不让放的原因，空串 = 能放
func _tip_quick(inv: InventoryPanelScript, label_key: String, ok: Callable = Callable()) -> void:
	inv.quick_action = func(inst: ItemInstance) -> ItemActions.Action:
		var a := ItemActions.make(&"quick", UiText.t(label_key), func(): inv.quick_move(inv.board_view, inst.uid))
		var why: String = ok.call(inst) if ok.is_valid() else ""
		return ItemActions.disable(a, why) if why != "" else a


## 「先试棋盘、放不下再到地上」（神坛退回祭品、保险箱取出、容器里双击共用）：返回落点 "board" / "storage"，都放不下 ""。
## 提示语各屏按返回值自己写
func _take_to_player(from: ItemContainer, uid: int) -> String:
	if InventoryService.transfer_auto(from, uid, flow.run.board):
		return "board"
	if InventoryService.transfer_auto(from, uid, flow.run.storage):
		return "storage"
	return ""


## 对手叫什么（战前准备、战斗回放共用）：从这一场的敌人内容（点里的，或搜索遭遇现造的）查定义；查不到就「敌人」。档位是内部数，不写
func _enemy_name(content: Dictionary) -> String:
	var def := flow.enemies.enemy(StringName(String(content.get("enemy", "")))) if not content.is_empty() else null
	if def == null:
		return UiText.t("screen.enemy")
	return Names.of(def)


## 157：对手的名牌（战前准备、战斗回放共用）：名字、肖像（有图才画）
func _enemy_plate(content: Dictionary, portrait_side: int = Nameplate.PORTRAIT_SIZE) -> Nameplate:
	var id := StringName(String(content.get("enemy", ""))) if not content.is_empty() else &""
	var def := flow.enemies.enemy(id) if id != &"" else null
	if def == null:
		return Nameplate.new().setup(UiText.t("screen.enemy"), "", null, portrait_side)
	return Nameplate.new().setup(Names.of(def), "", Nameplate.enemy_face(id), portrait_side)


## 157：自己的名牌：角色名（没选角色写「我」）、肖像（有图才画）
func _player_plate(portrait_side: int = Nameplate.PORTRAIT_SIZE) -> Nameplate:
	var ch := flow.run.character if flow.run != null else null
	if ch == null:
		return Nameplate.new().setup(UiText.t("battle.me"), "", null, portrait_side)
	return Nameplate.new().setup(Names.of(ch), UiText.t("battle.side_mine"), Nameplate.character_face(ch.id), portrait_side)


#region 控件（造控件的活在 [UiTheme] 里，这里只留给子类的短名字）
func _label(text: String, font_size: int, color: Color) -> Label:
	return UiTheme.make_label(text, font_size, color)


## 会折行的说明文字（[method UiTheme.make_wrapped]：必须给最小宽度）
func _wrapped(text: String, font_size: int, color: Color, width: float) -> Label:
	return UiTheme.make_wrapped(text, font_size, color, width)


## 090（作者定）：按钮按重要性分三档（[enum UiPalette.Tier]），字号是 [param font_size] 的 300% / 200% / 150%，颜色也各不同。
## 不写档就是次要（200%）；各屏自己说哪个是主动作、哪个是辅助
func _button(text: String, handler: Callable, font_size: int = 14, tier: int = UiPalette.Tier.SECONDARY) -> Button:
	return UiTheme.make_button(text, handler, tier, font_size)


## 整屏的底色（底屏用）。不传颜色 = 设置里挑的底色（[method UiPalette.bg]）。
## 157 补充三：只是纯色暗底，不再铺石砖墙；底屏的内容放进 [method _slab_screen] 那块石板
func _backdrop(color: Color = Color(0, 0, 0, 0)) -> ColorRect:
	var bg := ColorRect.new()
	var themed := color.a <= 0.0
	bg.color = UiPalette.bg() if themed else color
	if themed:
		_bg_rect = bg
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP     # 叠层要挡住底下的地图，不然点穿了就走了一步
	add_child(bg)
	return bg


## 091：设置里换了底色，这一屏立刻跟着变
func refresh_backdrop() -> void:
	if _bg_rect != null:
		_bg_rect.color = UiPalette.bg()


## 157 补充三（作者定：每个界面在一块完整的石板上显示）：底屏的一整块大石板 —— 屏幕九成宽高、居中，板外是纯色底（[method _backdrop]）。
## 返回板里的内容区（一块铺满板内边距的空控件）：各屏照旧往里放铺满的居中 / 边距容器。
## [param edge_art] = 板边换一张（224 补充二：结算屏用没有标题刻线的 `slab_edge_plain`），内容区边距照旧按主题的石板
func _slab_screen(min_size: Vector2 = Vector2.ZERO, edge_art: String = "") -> Control:
	var slab := UiTheme.slab(PanelContainer.new(), edge_art)
	slab.name = "ScreenSlab"
	var side := (1.0 - SLAB_SHARE) * 0.5
	slab.anchor_left = side
	slab.anchor_top = side
	slab.anchor_right = 1.0 - side
	slab.anchor_bottom = 1.0 - side
	slab.custom_minimum_size = min_size
	add_child(slab)
	_screen_slab = slab
	# 内容区和板同锚点、按板的内边距缩进；不放进板（容器）里 —— 那样要等下一帧排版才有大小，钉在角上的按钮第一帧会跑到屏外
	var area := Control.new()
	area.name = "SlabContent"
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.anchor_left = side
	area.anchor_top = side
	area.anchor_right = 1.0 - side
	area.anchor_bottom = 1.0 - side
	var box := UiTheme.current().get_stylebox("panel", UiTheme.PANEL_OVERLAY)
	area.offset_left = box.get_margin(SIDE_LEFT)
	area.offset_top = box.get_margin(SIDE_TOP)
	area.offset_right = -box.get_margin(SIDE_RIGHT)
	area.offset_bottom = -box.get_margin(SIDE_BOTTOM)
	UiTheme.apply_tone(area, UiTheme.PANEL_OVERLAY)     # 板上的字按石板的深浅（浅板墨字）
	add_child(area)
	return area


## 179：开局屏不用石板 —— 整屏一幅画（[param art_name]，没图就是纯色底），内容区铺满全屏；先调 [method _backdrop]
func _painted_screen(art_name: String) -> Control:
	_painted = Control.new()
	_painted.name = "PaintedContent"
	_painted.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painted.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_painted)
	_repaint(art_name)
	return _painted


## 换整屏那幅画（作者 2026-10-17：开局三页各一张）。图的深浅（图旁 json）记在内容区上、里面按底取色的字重算；
## 没图 = 纯色底、深。返回现在的深浅（直接写在画上的标题按它挂字色）
func _repaint(art_name: String) -> StringName:
	if _painted == null:
		return UiTheme.TONE_DARK
	var dressed := false
	if _bg_rect != null:
		var old := _bg_rect.get_node_or_null(^"PaintedBackdrop")
		if old != null:
			old.free()
		dressed = UiTheme.dress_backdrop(_bg_rect, art_name, "PaintedBackdrop") != null
	var tone := UiTheme.art_tone(art_name) if dressed else UiTheme.TONE_DARK
	_painted.set_meta(&"tone", tone)
	UiTheme.refresh_tones(_painted)
	return tone


## 157 补充三：底屏的大石板（测试看）；没有 null
func screen_slab() -> PanelContainer:
	return _screen_slab


## 一块带边框的面板。128：它占着地上的地方 —— 地上的东西被它盖住就推到最近的空处
func _panel(margin: int = 16) -> PanelContainer:
	var p := UiTheme.panel(PanelContainer.new(), margin)     # 121：主题的 PanelDark 变体
	_reserve_ground(p)
	return p


## 128：登记一块占着地上的面板（关了自动撤销）。没有地层（局外、测试）什么也不做
func _reserve_ground(c: Control) -> void:
	var g := GroundLayer.current()
	if g != null:
		g.reserve(c)


## 半透明遮罩（对话框 / 背包浮窗 / 暂停菜单的底）：压暗底下、挡住鼠标，关掉就 free 它。
## 透明度各处略有不同（0.7 / 0.72 / 0.82），原样传；[param centered] 为真时遮罩里再放一个铺满的 [CenterContainer]
## （`shade.get_child(0)`），对话框面板放进去就居中
func _shade(alpha: float = 0.7, centered: bool = false) -> ColorRect:
	var shade := _backdrop(Color(0.04, 0.05, 0.07, alpha))
	if centered:
		shade.add_child(_full_center())
	return shade


## 作者 2026-10-13（地图上的规则卡、暂停、撤离确认没了底，透出地图）：底屏自己弹的小窗也是一块完整石板（[OverlayFrame]），
## 不再用凹槽（PanelDark 157 补充三起是板里的分区，自己没有不透明的底）。标题写进标题条；各屏往 [member OverlayFrame.content] 里加
func _modal_panel(title: String, margin: int = 16) -> OverlayFrame:
	var frame := OverlayFrame.new(margin)
	frame.set_title(title)
	_reserve_ground(frame)
	return frame


## 居中的一块面板（叠层用）：半透明压暗底下的地图，石板框放中间（157：[OverlayFrame]，标题写进 [method _frame_title]）。
## 返回框的内容区，各屏往里加东西；128：框占着地上的地方
## [param skin]：[constant OverlayFrame.SKIN_SLAB] / 铜 / 书 / 帐篷（233）
func _centered_panel(min_size: Vector2, margin: int = 16, skin: StringName = OverlayFrame.SKIN_SLAB) -> Container:
	_shade(OVERLAY_SHADE)     # 157 补充三：地图压暗透出来，石板浮在上面
	var center := _full_center()
	center.offset_top = HudHost.bar_height_in(get_tree()) if is_inside_tree() else 0.0     # 复测 v3.79：面板在顶端栏下面居中，不压住红心和金币
	add_child(center)
	_overlay_frame = OverlayFrame.new(margin, skin)
	_overlay_frame.custom_minimum_size = min_size
	_reserve_ground(_overlay_frame)
	center.add_child(_overlay_frame)
	center.offset_bottom = -_overlay_frame.outset_bottom()     # 神坛石碑：石基伸出窗底 56，居中时让出来
	if _overlay_frame.outset_top() > 0.0:     # 233：帐篷尖顶伸出窗顶 56 —— 窗离顶端栏不够就整块往下挪，尖顶不被盖住
		var fit := _make_room_above.bind(center)     # 方法 Callable：屏先被释放时，延后那一下自己作废（lambda 会留个悬空的 self）
		resized.connect(fit)
		_overlay_frame.minimum_size_changed.connect(fit)
		fit.call_deferred()
	return _overlay_frame.content


## 233：窗居中后离顶端栏的空隙不到皮要的上伸量就把居中区往下让（居中区下移 d，窗只下移 d / 2）；底下伸出去的那截（碑的石基）先扣掉
func _make_room_above(center: Control) -> void:
	if _overlay_frame == null or not is_instance_valid(center):
		return
	var bar := HudHost.bar_height_in(get_tree()) if is_inside_tree() else 0.0
	var gap := (size.y - bar - _overlay_frame.outset_bottom() - _overlay_frame.get_combined_minimum_size().y) * 0.5
	center.offset_top = bar + 2.0 * maxf(0.0, _overlay_frame.outset_top() - gap)


## 233：窗顶离顶端栏底边多远（测试看；帐篷要 ≥ 尖顶高）
func overlay_top_gap() -> float:
	if _overlay_frame == null:
		return 0.0
	var bar := HudHost.bar_height_in(get_tree()) if is_inside_tree() else 0.0
	return _overlay_frame.get_global_rect().position.y - get_global_rect().position.y - bar


## 铜面板三屏（战前准备 / 战斗 / 战利品，UI替换美术 甲 铜战板）：同 [method _centered_panel]，框换铜面板、没有标题条
func _bronze_panel(min_size: Vector2, margin: int = -1) -> Container:
	return _centered_panel(min_size, margin, OverlayFrame.SKIN_BRONZE)


## 作者 2026-10-21：战前 / 战斗两块铜面板一样大 —— 两屏都撑到「见过的两边内容里大的那个」（窗口尺寸变了重新记）
static var _duel_min := Vector2.ZERO
static var _duel_view := Vector2.ZERO


## 按上面那条定本屏铜框的最小尺寸；[param other] 是垫在底下的另一块（开战过场时传战前那块），一起撑齐
func _fit_duel_panel(other: Control = null) -> void:
	if _overlay_frame == null:
		return
	var view := get_viewport_rect().size if is_inside_tree() else Vector2.ZERO
	if view != _duel_view:
		_duel_view = view
		_duel_min = Vector2.ZERO
	_overlay_frame.custom_minimum_size = Vector2.ZERO
	_duel_min = _duel_min.max(_overlay_frame.get_combined_minimum_size())
	if other != null:
		_duel_min = _duel_min.max(other.get_combined_minimum_size())
		other.custom_minimum_size = _duel_min
	_overlay_frame.custom_minimum_size = _duel_min


## 157：叠层的标题写进石板框的标题条（原来各屏自己在内容里摆的那一行）；返回那个标签，之后改字直接改它
## 226 批二：只有叠层能写标题（没有石板框时造一个不挂树的孤儿标签那条退路删了）
func _frame_title(text: String) -> Label:
	assert(_overlay_frame != null, "_frame_title 要先 _centered_panel")
	return _overlay_frame.set_title(text)


## 157：石板框（测试看）；底屏 null
func overlay_frame() -> OverlayFrame:
	return _overlay_frame


## 铺满宿主的居中容器
static func _full_center() -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return center


func _vbox(separation: int = 8) -> VBoxContainer:
	return UiTheme.vbox(separation)


func _hbox(separation: int = 8) -> HBoxContainer:
	return UiTheme.hbox(separation)


func _log_box(font_size: int = 12) -> RichTextLabel:
	var log := RichTextLabel.new()
	log.bbcode_enabled = true
	log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log.scroll_following = true
	return UiTheme.rich(log, font_size)


## 原地重建这一屏：清空全部子节点，再按 [param payload] 重新 [method open]（切了语言、收起背包、删了存档之后重画）
func _reopen(payload: Dictionary = {}) -> void:
	UiTheme.clear_children(self)
	open(payload)
#endregion
