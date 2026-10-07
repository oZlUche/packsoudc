## 场景流里每一屏的底座（架构文档 8 节，M6）。
##
## 导演造它、给它 [member flow] 与字体、加进树、调 [method open]。屏只做两件事：把 flow 的状态画出来；
## 把玩家的动作转成 flow 的方法调用（1.2 命令进、信号出）。屏不认识导演 —— 需要导演做的事发信号。
##
## 全屏铺满；叠层（战斗、战利品……）在 [method _backdrop] 上再摆一块面板，底下的地图还在、镜头还在。
class_name GameScreen
extends Control

## 这一屏是 GameFlow.Screen 里的哪个，导演设
var screen: int = -1
var flow: GameFlow = null
var font: Font = null
## 091：底屏 / 叠层的整块底色（跟设置里的底色走）；换了底色 [method refresh_backdrop] 刷
var _bg_rect: ColorRect = null


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


#region 控件
func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	return UiTheme.label(l, font_size, color)     # 121：字体在主题里，颜色先选变体


## 会折行的说明文字。必须给最小宽度：中文没有词边界，容器算出的最小宽度是一个字
func _wrapped(text: String, font_size: int, color: Color, width: float) -> Label:
	var l := _label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## 090（作者定）：按钮按重要性分三档（[enum UiPalette.Tier]），字号是 [param font_size] 的 300% / 200% / 150%，颜色也各不同。
## 不写档就是次要（200%）；各屏自己说哪个是主动作、哪个是辅助
func _button(text: String, handler: Callable, font_size: int = 14, tier: int = UiPalette.Tier.SECONDARY) -> Button:
	var b := Button.new()
	b.text = text
	UiPalette.style_button(b, tier, UiPalette.button_font_size(font_size, tier))
	b.pressed.connect(handler)
	return b


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


## 居中的一块面板（叠层用）：半透明压暗底下的地图，面板放中间
func _centered_panel(min_size: Vector2, margin: int = 16) -> PanelContainer:
	_backdrop(Color(0.04, 0.05, 0.07, 0.82))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := _panel(margin)
	p.custom_minimum_size = min_size
	center.add_child(p)
	return p


func _vbox(separation: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


func _hbox(separation: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


func _log_box(font_size: int = 12) -> RichTextLabel:
	var log := RichTextLabel.new()
	log.bbcode_enabled = true
	log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log.scroll_following = true
	return UiTheme.rich(log, font_size)


## 一件道具的一行说明：名字（按稀有度上色）、几格、值多少
func _item_line(def: ItemDef) -> String:
	if def == null:
		return "?"
	var cells := def.shape.cell_count() if def.shape != null else 0
	return "[color=#%s]%s[/color]  %d 格  %d 币" % [ItemPainter.rarity_color(def).to_html(false), def.display_name, cells, ItemValue.of(def)]
#endregion
