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


func _ready() -> void:
	if font == null:
		font = UiPalette.cjk_font()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


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
## 各屏自己的规矩（`drop_filter`、`can_show`……）回来之后接到 [member _drag] / [member _tip] 上
func _mount_bag(row: Control, other: ContainerView, hint_sink: Callable, quick_target: ItemContainer = null) -> InventoryPanelScript:
	var inv := InventoryPanelScript.new()
	_drag = DragLayer.new()
	_drag.label_font = font
	inv.setup(flow.run, font, _drag)
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


## 「先试棋盘、放不下再到地上」（神坛退回祭品、保险箱取出、容器里双击共用）：返回落点 "board" / "storage"，都放不下 ""。
## 提示语各屏按返回值自己写
func _take_to_player(from: ItemContainer, uid: int) -> String:
	if InventoryService.transfer_auto(from, uid, flow.run.board):
		return "board"
	if InventoryService.transfer_auto(from, uid, flow.run.storage):
		return "storage"
	return ""


## 对手叫什么（战前准备、战斗回放共用）：从这一场的敌人内容（点里的，或搜索遭遇现造的）查定义，「名字（N 档）」；查不到就「敌人」
func _enemy_name(content: Dictionary) -> String:
	var def := flow.enemies.enemy(StringName(String(content.get("enemy", "")))) if not content.is_empty() else null
	if def == null:
		return "敌人"
	return "%s（%d 档）" % [Names.of(def), int(content.get("strength", 0))]


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


## 整屏的底色（底屏用）。不传颜色 = 设置里挑的底色（[method UiPalette.bg]）
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


## 居中的一块面板（叠层用）：半透明压暗底下的地图，面板放中间
func _centered_panel(min_size: Vector2, margin: int = 16) -> PanelContainer:
	_shade(0.82)
	var center := _full_center()
	add_child(center)
	var p := _panel(margin)
	p.custom_minimum_size = min_size
	center.add_child(p)
	return p


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
