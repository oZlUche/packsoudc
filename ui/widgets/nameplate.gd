## 名牌（157）：一条横条 —— 左边肖像（64×64）、中间名字（大）与副行。战前准备与战斗回放共用，两屏的位置一致。
##
## 肖像：`assets/portraits/enemies/<敌人 id>.png`、`assets/portraits/characters/<角色 id>.png`，**没图不画槽**（条变短，不留空洞）。
## 徽记槽先不画：敌人定义里没有阵营字段，等阵营落成数据再说
class_name Nameplate
extends MarginContainer

const PORTRAIT_SIZE := 64
const NAME_SIZE := 20

## 肖像目录（测试指到别处）
static var portrait_root := "res://assets/portraits/"

## 有肖像时的那块图；没图 null
var portrait: TextureRect = null
var name_label: Label
var sub_label: Label
var _row: HBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = UiTheme.hbox(10)
	add_child(_row)


## 填上名字、副行、肖像（[param face] 为 null = 不画肖像槽）。重复调会换掉原来的
func setup(display_name: String, sub: String, face: Texture2D = null) -> Nameplate:
	UiTheme.clear_children(_row)
	portrait = null
	if face != null:
		portrait = TextureRect.new()
		portrait.texture = face
		portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_row.add_child(portrait)
	var col := UiTheme.vbox(2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_child(col)
	name_label = UiTheme.make_label(display_name, NAME_SIZE)
	col.add_child(name_label)
	sub_label = UiTheme.make_label(sub, 13, UiPalette.DIM)
	sub_label.visible = sub != ""
	col.add_child(sub_label)
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
