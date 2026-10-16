## 175 补 5.5：对阵面板效果栏的图标 —— 按格子 id 的约定取图，内容数据不记路径。
## 白色单色线稿按 [method tint_of] 着色；保底的中毒 / 流血整张换成彩色成品（`<id>_guard.png`，不着色）。
## 取不到图返回 null，[CombatantPanel] 照旧画名字的第一个字 —— 缺图不报错，图标可以分批到
class_name EffectIcons
extends RefCounted

## 图标目录（`<buff id>.png`、`axis_<轴>_pos/neg.png`、`system_overtime.png`、`system_block.png`）。测试指到别处走首字退路
static var art_dir := "res://assets/ui/effects/"
## 作者 10-15：按 28×28 显示（源图 56，高分屏 2 倍），不画方格底和外框
const SIZE := 28.0
## 反应产物没有自己的元素，按美术定的色系：燃血跟灼伤，菌血、剧毒跟中毒
const PRODUCT_STYLES := {&"scorched_blood": "scorch", &"fungal_blood": "poison", &"virulent": "poison"}

static var _cache: Dictionary = {}


## 这一格的图（[param stacks] 是轴格的带符号层数，分正负两张；[param guard] > 0 时先找 `<id>_guard.png`）；没有返回 null。
## 被动条目永远没有图
static func of(chip_id: String, stacks: int = 0, guard: int = 0) -> Texture2D:
	var name := file_of(chip_id, stacks)
	if name == "":
		return null
	if guard > 0:
		var g := _load(name + "_guard")
		if g != null:
			return g
	return _load(name)


## 这一格有保底时用不用彩色成品（成品不着色）
static func is_guard_art(chip_id: String, stacks: int, guard: int) -> bool:
	var name := file_of(chip_id, stacks)
	return guard > 0 and name != "" and _load(name + "_guard") != null


## 格子 id → 文件名（不带扩展名）；被动条目空
static func file_of(chip_id: String, stacks: int = 0) -> String:
	if chip_id.begins_with(CombatantPanel.PASSIVE_PREFIX) or chip_id == "":
		return ""
	if chip_id.begins_with(CombatantPanel.AXIS_PREFIX):
		return "axis_%s_%s" % [CombatantPanel.axis_of(chip_id), "neg" if stacks < 0 else "pos"]
	if chip_id.begins_with("system:"):
		return "system_" + chip_id.substr("system:".length())
	return chip_id


## 单色图的颜色：元素状态与反应产物用补 5.4 的关键词色，其余按组（0 系统 / 1 减益 / 2 增益）
static func tint_of(chip_id: String, def: BuffDef, group: int) -> Color:
	var style := ""
	if PRODUCT_STYLES.has(StringName(chip_id)):
		style = PRODUCT_STYLES[StringName(chip_id)]
	elif def != null and Glossary.status_style(def) != "term":
		style = Glossary.status_style(def)
	if style != "":
		return UiPalette.style_color(style)
	if group == 0:
		return CombatantPanel.SYSTEM_COLOR
	return UiPalette.HP if group == 1 else UiPalette.ARMOR


static func _load(name: String) -> Texture2D:
	var path := art_dir.path_join(name + ".png")
	if not _cache.has(path):
		_cache[path] = HudIcon.load_art(path)
	return _cache[path]


## 测试换了 [member art_dir] 后清缓存
static func clear_cache() -> void:
	_cache.clear()
