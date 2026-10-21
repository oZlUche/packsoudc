## 主菜单（M6）：继续（有存档才显示）、读取存档（有任何一位有存档才显示）、新的游戏（= 开一份新存档）、仓库、开发工具、退出（089 作者定的顺序）。
## 085：多了一个「语言」按钮 —— 切 [GameSettings.language] 并存盘，[UiText.lang] 跟着改，菜单原地重建。
## 197（作者定稿）：不再是屏心一块石板 —— 整屏三张画轮换带慢镜头（[MenuBackdrop]）；补充三 §14（作者草图）：游戏名居中在上方天空，
## 菜单是左下角几行描边字，从底往上堆：主档（继续 / 新的游戏）、次档（读取存档 / 仓库与战绩 / 百科 / 设置）、最底下一行小字（语言 / 开发工具 / 退出）。
## 不用木牌、不加暗纱（左下角的安静由画自己负责）；战绩行拿掉（在仓库与战绩页），备份 / 对账提示是右下角小字。
## 补充二 §12：游戏名做成字标图（`menu/title`）—— 图在就用图，不在退回描边粗体的文字标题（[method UiTheme.make_hero_title]）。
## 尺寸都按 1080 高写，随屏高等比缩放（游戏名照比例，菜单最小缩到 [constant MIN_SCALE]）
extends GameScreen

signal dev_tools_requested

## 设计稿按这个屏高写
const DESIGN_HEIGHT := 1080.0
## 菜单最小缩到这么多（1280 × 720）
const MIN_SCALE := 0.75
## 游戏名（文字退路）的上沿；字标图的宽（美术 720 × 200 的画布放大 1.55 倍）与上沿 —— 都居中
const TITLE_TOP := 90.0
const ART_LOGO := "menu/title"
const LOGO_WIDTH := 1116.0
const LOGO_TOP := 90.0
## 菜单的左边线（字的左沿；行前菱形画在字左边的缩进里）、最底下一行离屏底
const LEFT := 96.0
const BOTTOM := 72.0
## 行距：主档 / 次档；档与档之间：主次、次末
const PRIMARY_GAP := 10
const SECONDARY_GAP := 8
const PRIMARY_TO_SECONDARY := 18
const SECONDARY_TO_FOOT := 24
## 右下提示离屏边、字号
const NOTICE_MARGIN := 48.0
const NOTICE_SIZE := 13

## 菜单第一次打开（刚从启动屏过来）：第一张画从启动屏那档暗亮起来；之后回菜单直接开镜头
static var _shown_once := false

var _continue_btn: Button = null
## 221 G：「新的游戏」下面那行「跳过序章」—— 点一次只是武装（字换成确认句），[constant SKIP_ARM_SEC] 秒内再点才开
var _skip_btn: Button = null
var _skip_armed := false
const SKIP_ARM_SEC := 4.0
var _scenery: MenuBackdrop = null
## 游戏名：字标图（[TextureRect]）或文字（[Label]）
var _title: Control = null
## 左下角整块（主档、次档、最底下一行），从底往上堆
var _column: VBoxContainer = null
var _primary: VBoxContainer = null
var _secondary: VBoxContainer = null
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
	_column = _vbox(0)
	_column.name = "MenuColumn"
	area.add_child(_column)
	_primary = _vbox(PRIMARY_GAP)
	_column.add_child(_primary)
	_continue_btn = null
	if flow.profile_exists():
		_continue_btn = _line(_primary, UiText.t("menu.continue"), func(): flow.continue_game(), UiTheme.MENU_PRIMARY_SIZE)
	_line(_primary, UiText.t("menu.new_run"), func(): flow.start_new_game(), UiTheme.MENU_PRIMARY_SIZE)
	_skip_armed = false
	_skip_btn = _line(_primary, UiText.t("menu.skip_prologue"), skip_prologue) if not flow.tutorial_chapters().is_empty() else null
	_column.add_child(_spacer(PRIMARY_TO_SECONDARY))
	_secondary = _vbox(SECONDARY_GAP)
	_column.add_child(_secondary)
	if flow.slots != null and flow.slots.any():
		_line(_secondary, UiText.t("menu.load"), flow.show_slots)
	_line(_secondary, UiText.t("menu.meta"), flow.show_meta)
	_line(_secondary, UiText.t("menu.encyclopedia"), func(): flow.show_encyclopedia())     # 114
	_line(_secondary, UiText.t("menu.settings"), flow.show_settings)
	_column.add_child(_spacer(SECONDARY_TO_FOOT))

	_foot = _hbox(10)
	_foot.name = "MenuFoot"
	var indent := MarginContainer.new()     # 和上面几行字同一条左边线（它们左边留着菱形的缩进）
	UiTheme.margins(indent, UiTheme.MENU_LINE_INDENT, 0, 0, 0)
	indent.add_child(_foot)
	_column.add_child(indent)
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


## 221 G：「跳过序章」—— 第一次点只换字等确认，再点一次才开新存档（跳过在这份存档里收不回来）。返回开没开
func skip_prologue() -> bool:
	if _skip_btn == null:
		return false
	if not _skip_armed:
		_skip_armed = true
		_skip_btn.text = UiText.t("menu.skip_prologue_confirm")
		if is_inside_tree():
			get_tree().create_timer(SKIP_ARM_SEC).timeout.connect(disarm_skip)
		return false
	_skip_armed = false
	flow.start_new_game_skipping()
	return true


## 几秒没再点：字换回来
func disarm_skip() -> void:
	if not is_instance_valid(_skip_btn):
		return
	_skip_armed = false
	_skip_btn.text = UiText.t("menu.skip_prologue")


func skip_button() -> Button:
	return _skip_btn


## 一行字挂进 [param box]
func _line(box: VBoxContainer, text: String, handler: Callable, font_size: int = UiTheme.MENU_SECONDARY_SIZE) -> Button:
	var b := UiTheme.make_menu_line(text, font_size, handler)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(b)
	return b


## 档与档之间的空（VBox 两侧的间距是 0，空多高就隔多远）
static func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 这一屏比设计稿的缩放（游戏名按它）
func ui_scale() -> float:
	return (size.y if size.y > 0.0 else DESIGN_HEIGHT) / DESIGN_HEIGHT


## 菜单的缩放：同 [method ui_scale]，但不小于 [constant MIN_SCALE]
func column_scale() -> float:
	return maxf(ui_scale(), MIN_SCALE)


func _layout() -> void:
	if _column == null:
		return
	var s := ui_scale()
	var c := column_scale()
	var h := size.y if size.y > 0.0 else DESIGN_HEIGHT
	var w := size.x if size.x > 0.0 else DESIGN_HEIGHT * 1.6
	if _title is TextureRect:
		var tex := (_title as TextureRect).texture
		var wide := LOGO_WIDTH * s
		_title.size = Vector2(wide, wide * tex.get_height() / maxf(tex.get_width(), 1.0))
		_title.position = Vector2((w - wide) * 0.5, LOGO_TOP * s)
	else:
		var label := _title as Label
		UiTheme.set_hero_size(label, int(round(UiTheme.HERO_TITLE_SIZE * s)))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(0, TITLE_TOP * s)
		label.size = Vector2(w, 0)
	# 菜单从底往上堆：字的左沿对齐 LEFT（行前留给菱形的缩进挂在线左边），最底下一行离屏底 BOTTOM
	_column.scale = Vector2.ONE * c
	_column.reset_size()
	_column.position = Vector2((LEFT - UiTheme.MENU_LINE_INDENT) * c, h - (BOTTOM + _column.size.y) * c)
	_notices.reset_size()
	_notices.position = Vector2(w - NOTICE_MARGIN * c - _notices.size.x, h - NOTICE_MARGIN * c - _notices.size.y)


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


## 主档 / 次档那几行（测试看）
func lines() -> Array[Button]:
	var out: Array[Button] = []
	for box in [_primary, _secondary]:
		for n in box.get_children():
			if n is Button:
				out.append(n)
	return out


func foot() -> HBoxContainer:
	return _foot


func notices() -> VBoxContainer:
	return _notices
#endregion
