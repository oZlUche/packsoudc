## 主菜单（M6）：继续（有存档才显示）、读取存档（有任何一位有存档才显示）、新的游戏（= 开一份新存档）、仓库、开发工具、退出（089 作者定的顺序）。
## 085：多了一个「语言」按钮 —— 切 [GameSettings.language] 并存盘，[UiText.lang] 跟着改，菜单原地重建。
## 197 补充一（作者定稿）：不再是屏心一块石板 —— 整屏三张画轮换带慢镜头（[MenuBackdrop]），左上描边粗体游戏名，
## 左 1/3 一道暗纱上挂一列木牌（主档琥珀木：继续 / 新的游戏；次档：读取存档 / 仓库与战绩 / 百科 / 设置），
## 末档（语言 / 开发工具 / 退出）是左下一行小字；战绩行拿掉（在仓库与战绩页），备份 / 对账提示是右下角小字。
## 补充二 §12：游戏名做成字标图（`menu/title`，2×）—— 图在就用图，不在退回描边粗体的文字标题（[method UiTheme.make_hero_title]）。
## 尺寸都按 1080 高写，随屏高等比缩放（游戏名照比例，按钮列最小缩到 [constant MIN_SCALE]）
extends GameScreen

signal dev_tools_requested

## 设计稿按这个屏高写
const DESIGN_HEIGHT := 1080.0
## 按钮列最窄缩到这么多（1280 × 720）
const MIN_SCALE := 0.75
## 游戏名与按钮列的左边线、游戏名上沿、按钮列上沿
const LEFT := 96.0
const TITLE_TOP := 96.0
## 补充二 §12：字标图（1080 高时宽 720、上沿 72）
const ART_LOGO := "menu/title"
const LOGO_WIDTH := 720.0
const LOGO_TOP := 72.0
const COLUMN_TOP := 240.0
## 木牌大小（主档 / 次档）、牌间距、主次两档之间
const PRIMARY_SIZE := Vector2(360, 72)
const SECONDARY_SIZE := Vector2(300, 52)
const GAP := 14
## 左边暗纱的宽、中间最深处
const VEIL_WIDTH := 640.0
const VEIL_ALPHA := 0.55
## 左下小字、右下提示离屏边
const FOOT_MARGIN := 48.0
const NOTICE_SIZE := 13

## 菜单第一次打开（刚从启动屏过来）：第一张画从启动屏那档暗亮起来；之后回菜单直接开镜头
static var _shown_once := false

var _continue_btn: Button = null
var _scenery: MenuBackdrop = null
var _veil: TextureRect = null
## 游戏名：字标图（[TextureRect]）或文字（[Label]）
var _title: Control = null
var _column: VBoxContainer = null
var _foot: HBoxContainer = null
var _notices: VBoxContainer = null


func open(_payload: Dictionary) -> void:
	UiText.apply(flow.settings)
	UiPalette.apply(flow.settings)
	_backdrop()
	_scenery = MenuBackdrop.new()
	add_child(_scenery)
	var brighten := not _shown_once
	_scenery.start(UiTheme.ART_MENU_BGS, brighten)
	_shown_once = true
	_veil = _make_veil()
	add_child(_veil)
	var area := Control.new()
	area.name = "MenuContent"
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.set_tone(area, UiTheme.art_tone(UiTheme.ART_MENU_BGS[0]))     # 三张都是暗画：亮字
	add_child(area)

	var logo := UiTheme.art_cached(ART_LOGO)
	if logo != null:
		var pic := TextureRect.new()
		pic.name = "MenuLogo"
		pic.texture = logo
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title = pic
		if brighten:     # 启动屏把字标压暗到 40 %：跟着画一起亮起来
			pic.modulate = Color(MenuBackdrop.BOOT_DIM, MenuBackdrop.BOOT_DIM, MenuBackdrop.BOOT_DIM)
	else:
		_title = UiTheme.make_hero_title("背包搜打撤")
	area.add_child(_title)
	if brighten and _title is TextureRect:
		create_tween().tween_property(_title, "modulate", Color.WHITE, MenuBackdrop.BRIGHTEN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 089（作者定）：第一项「继续」（当前位有存档才显示）；「读取存档」（有任何一位有存档才显示）；「新的游戏」= 开一份新存档。只写这几个词，不写章名
	_column = _vbox(GAP)
	_column.name = "MenuColumn"
	area.add_child(_column)
	_continue_btn = null
	if flow.profile_exists():
		_continue_btn = _plank(UiText.t("menu.continue"), func(): flow.continue_game(), true)
	_plank(UiText.t("menu.new_run"), func(): flow.start_new_game(), true)
	_column.add_child(Control.new())     # 主次两档之间：两份间距
	if flow.slots != null and flow.slots.any():
		_plank(UiText.t("menu.load"), flow.show_slots)
	_plank(UiText.t("menu.meta"), flow.show_meta)
	_plank(UiText.t("menu.encyclopedia"), func(): flow.show_encyclopedia())     # 114
	_plank(UiText.t("menu.settings"), flow.show_settings)

	_foot = _hbox(10)
	_foot.name = "MenuFoot"
	area.add_child(_foot)
	var links: Array[Button] = [UiTheme.make_menu_link(UiText.t("menu.lang_short"), toggle_language)]
	if GameSettings.dev_build():     # 作者 2026-10-17：开发工具只在开发环境
		links.append(UiTheme.make_menu_link(UiText.t("menu.dev_tools"), func(): dev_tools_requested.emit()))
	links.append(UiTheme.make_menu_link(UiText.t("menu.quit"), func(): get_tree().quit()))
	for i in links.size():
		if i > 0:
			_foot.add_child(_label("·", UiTheme.MENU_FOOT_SIZE, UiPalette.DIM))
		_foot.add_child(links[i])

	# 098：这个存档位读不回来、已备份的那一句；173：读档时对账 / 挪位 / 打捞过 —— 右下角小字，没有不占位
	_notices = _vbox(4)
	_notices.name = "MenuNotices"
	area.add_child(_notices)
	for text in [flow.backup_notice(), flow.repair_notice()]:
		if text != "":
			var l := _label(text, NOTICE_SIZE, UiPalette.STAMINA)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_notices.add_child(l)
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	_layout()


## 一块木牌挂进按钮列
func _plank(text: String, handler: Callable, primary: bool = false) -> Button:
	var b := UiTheme.make_menu_button(text, handler, primary)
	b.custom_minimum_size = PRIMARY_SIZE if primary else SECONDARY_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_column.add_child(b)
	return b


## 左 1/3 那道竖向暗纱：横着黑 0 → 55 % → 0
static func _make_veil() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, VEIL_ALPHA), Color(0, 0, 0, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 4
	var veil := TextureRect.new()
	veil.name = "MenuVeil"
	veil.texture = tex
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return veil


## 这一屏比设计稿的缩放（游戏名按它）
func ui_scale() -> float:
	return (size.y if size.y > 0.0 else DESIGN_HEIGHT) / DESIGN_HEIGHT


## 按钮列的缩放：同 [method ui_scale]，但不小于 [constant MIN_SCALE]
func column_scale() -> float:
	return maxf(ui_scale(), MIN_SCALE)


func _layout() -> void:
	if _column == null:
		return
	var s := ui_scale()
	var c := column_scale()
	var h := size.y if size.y > 0.0 else DESIGN_HEIGHT
	var w := size.x if size.x > 0.0 else DESIGN_HEIGHT * 1.6
	_veil.position = Vector2.ZERO
	_veil.size = Vector2(VEIL_WIDTH * c, h)
	if _title is TextureRect:
		var tex := (_title as TextureRect).texture
		var wide := LOGO_WIDTH * s
		_title.size = Vector2(wide, wide * tex.get_height() / maxf(tex.get_width(), 1.0))
		_title.position = Vector2(LEFT * c, LOGO_TOP * s)
	else:
		UiTheme.set_hero_size(_title as Label, int(round(UiTheme.HERO_TITLE_SIZE * s)))
		_title.position = Vector2(LEFT * c, TITLE_TOP * s)
	_column.scale = Vector2.ONE * c
	_column.position = Vector2(LEFT * c, COLUMN_TOP * c)
	_column.reset_size()
	_foot.scale = Vector2.ONE * c
	_foot.reset_size()
	_foot.position = Vector2(LEFT * c, h - FOOT_MARGIN * c - _foot.size.y * c)
	_notices.reset_size()
	_notices.position = Vector2(w - FOOT_MARGIN * c - _notices.size.x, h - FOOT_MARGIN * c - _notices.size.y)


## 切到下一种界面语言：写进设置并存盘，然后把菜单原地重建（按钮文字立刻换）
func toggle_language() -> void:
	if flow.settings == null:
		flow.settings = GameSettings.new()
	flow.settings.language = UiText.next_lang(flow.settings.language)
	flow.save_settings()
	_reopen()


#region 测试看
func scenery() -> MenuBackdrop:
	return _scenery


func title_node() -> Control:
	return _title


func column() -> VBoxContainer:
	return _column


func foot() -> HBoxContainer:
	return _foot


func notices() -> VBoxContainer:
	return _notices
#endregion
