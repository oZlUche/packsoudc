## 名牌（157）：一块名牌底（[constant UiTheme.PANEL_NAMEPLATE]，美术的铜名牌，2026-10-17 前是切角石碑）—— 左边肖像位（214：96×96，原 64）、中间名字（大）与副行、右边徽记位（32×32）。
## 战前准备与战斗回放共用，两屏的位置一致。
##
## 157 补充二（作者定：没图也先留框）：肖像位**永远在**，框永远画，图来了填进去 —— `assets/portraits/enemies/<敌人 id>.png`、
## `assets/portraits/characters/<角色 id>.png`；没图是占位剪影（[PortraitSlot]）。徽记位也先画框，阵营数据有了再填
class_name Nameplate
extends PanelContainer

## 214（作者 2026-10-20 按推荐）：64 看不清五官，96 是下限；铭牌高跟着 +32，宽与字不动
const PORTRAIT_SIZE := 96
## 战前准备屏、战斗回放的名牌（复测 v3.79：面板要放进顶端栏下面那块，名牌矮一截）
const COMPACT_PORTRAIT := 72
const BADGE_SIZE := 32
const NAME_SIZE := 20
## 说明那一句的字号（小档）
const BLURB_SIZE := 13

## 肖像目录（测试指到别处）
static var portrait_root := "res://assets/portraits/"

## 有肖像时的那块图；没图 null（肖像位 [member portrait_slot] 照样在）
var portrait: TextureRect = null
var portrait_slot: PortraitSlot = null
var badge_slot: PortraitSlot = null
var name_label: Label
var sub_label: Label
## 255：名牌里的一句说明（[method set_blurb] 加上的；没加 null）
var blurb_label: Label = null
var _col: VBoxContainer = null
var _row: HBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.panel(self, -1, UiTheme.PANEL_NAMEPLATE)
	if UiTheme.tone_of(UiTheme.PANEL_NAMEPLATE) == UiTheme.TONE_DARK:
		theme = UiTheme.bright_text_theme()     # 铜名牌是深底，常放在浅色石板框里：不继承外面的墨字
	_row = UiTheme.hbox(12)
	add_child(_row)


## 填上名字、副行、肖像（[param face] 为 null = 占位剪影）；[param portrait_side] 肖像边长（255：0 = 不要肖像位 —— 选角色屏左边已经有 160 的大头像）。重复调会换掉原来的
func setup(display_name: String, sub: String, face: Texture2D = null, portrait_side: int = PORTRAIT_SIZE) -> Nameplate:
	UiTheme.clear_children(_row)
	portrait_slot = null
	portrait = null
	blurb_label = null
	if portrait_side > 0:
		portrait_slot = PortraitSlot.new(portrait_side, face, true)
		portrait = portrait_slot.picture
		_row.add_child(portrait_slot)
	var col := UiTheme.vbox(2)
	_col = col
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(col)
	name_label = UiTheme.make_label(display_name, NAME_SIZE)
	col.add_child(name_label)
	sub_label = UiTheme.make_label(sub, 13, UiPalette.DIM)
	sub_label.visible = sub != ""
	col.add_child(sub_label)
	badge_slot = PortraitSlot.new(BADGE_SIZE, null, false)
	badge_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(badge_slot)
	return self


## 255：名字放大到 [param font_size]（选角色屏 24）
func set_name_size(font_size: int) -> Nameplate:
	name_label.add_theme_font_size_override("font_size", UiTheme.sz(font_size))     # 258：按字号档
	return self


## 255：名字与副行下面加一句说明（13 号、折行，[param width] 是最小宽度）
func set_blurb(text: String, width: float) -> Nameplate:
	if text == "" or _col == null:
		return self
	blurb_label = UiTheme.make_wrapped(text, BLURB_SIZE, UiPalette.FG, width)
	_col.add_child(blurb_label)
	return self


## 敌人的肖像（没图 null）
static func enemy_face(enemy_id: StringName) -> Texture2D:
	return _face("enemies", enemy_id)


## 角色的肖像（没图 null）
static func character_face(character_id: StringName) -> Texture2D:
	return _face("characters", character_id)


static func _face(kind: String, id: StringName) -> Texture2D:
	if String(id) == "":
		return null
	var path := portrait_root.path_join(kind).path_join(String(id) + ".png")
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	return EventImage.load_texture(path)
