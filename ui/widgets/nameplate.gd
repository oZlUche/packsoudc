## 名牌（157）：一块名牌底（[constant UiTheme.PANEL_NAMEPLATE]，美术的铜名牌，2026-10-17 前是切角石碑）—— 左边肖像位（64×64）、中间名字（大）与副行、右边徽记位（32×32）。
## 战前准备与战斗回放共用，两屏的位置一致。
##
## 157 补充二（作者定：没图也先留框）：肖像位**永远在**，框永远画，图来了填进去 —— `assets/portraits/enemies/<敌人 id>.png`、
## `assets/portraits/characters/<角色 id>.png`；没图是占位剪影（[PortraitSlot]）。徽记位也先画框，阵营数据有了再填
class_name Nameplate
extends PanelContainer

const PORTRAIT_SIZE := 64
const BADGE_SIZE := 32
const NAME_SIZE := 20

## 肖像目录（测试指到别处）
static var portrait_root := "res://assets/portraits/"

## 有肖像时的那块图；没图 null（肖像位 [member portrait_slot] 照样在）
var portrait: TextureRect = null
var portrait_slot: PortraitSlot = null
var badge_slot: PortraitSlot = null
var name_label: Label
var sub_label: Label
var _row: HBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.panel(self, -1, UiTheme.PANEL_NAMEPLATE)
	if UiTheme.tone_of(UiTheme.PANEL_NAMEPLATE) == UiTheme.TONE_DARK:
		theme = UiTheme.bright_text_theme()     # 铜名牌是深底，常放在浅色石板框里：不继承外面的墨字
	_row = UiTheme.hbox(12)
	add_child(_row)


## 填上名字、副行、肖像（[param face] 为 null = 占位剪影）。重复调会换掉原来的
func setup(display_name: String, sub: String, face: Texture2D = null) -> Nameplate:
	UiTheme.clear_children(_row)
	portrait_slot = PortraitSlot.new(PORTRAIT_SIZE, face, true)
	portrait = portrait_slot.picture
	_row.add_child(portrait_slot)
	var col := UiTheme.vbox(2)
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
