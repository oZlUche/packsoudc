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


#region 控件
func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


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
	b.add_theme_font_override("font", font)
	UiPalette.style_button(b, tier, UiPalette.button_font_size(font_size, tier))
	b.pressed.connect(handler)
	return b


## 整屏的底色（底屏用）
func _backdrop(color: Color = UiPalette.BG) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = color
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP     # 叠层要挡住底下的地图，不然点穿了就走了一步
	add_child(bg)
	return bg


## 一块带边框的面板
func _panel(margin: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.PANEL
	style.border_color = UiPalette.LINE
	style.set_border_width_all(1)
	style.set_content_margin_all(margin)
	p.add_theme_stylebox_override("panel", style)
	return p


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
	log.add_theme_font_override("normal_font", font)
	log.add_theme_font_size_override("normal_font_size", font_size)
	return log


## 一件道具的一行说明：名字（按稀有度上色）、几格、值多少
func _item_line(def: ItemDef) -> String:
	if def == null:
		return "?"
	var cells := def.shape.cell_count() if def.shape != null else 0
	return "[color=#%s]%s[/color]  %d 格  %d 币" % [ItemPainter.rarity_color(def).to_html(false), def.display_name, cells, ItemValue.of(def)]
#endregion
