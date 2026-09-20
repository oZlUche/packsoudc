## 生成示例形状与物品资产。
##
##     "E:/Godot/..._console.exe" --headless --path . --script res://tools/gen_sample_items.gd
##
## 手写 .tres 太容易出错（尤其 Array[Vector2i] 的字面量格式），所以用 ResourceSaver 生成。
## 这些是开发期占位内容，正式内容确定后可以直接在编辑器里改这些 .tres。
extends SceneTree

const SHAPE_DIR := "res://data/shapes"
const ITEM_DIR := "res://data/items"

# id, 显示名, 形状 ascii, 稀有度, 标签
const ITEMS: Array = [
	["mag", "弹匣", ["#"], 0, ["ammo"]],
	["battery", "电池", ["#"], 0, ["part"]],
	["pistol", "手枪", ["##"], 1, ["weapon"]],
	["medkit", "医疗包", ["##", "##"], 1, ["consumable"]],
	["rifle", "步枪", ["#", "#", "#"], 2, ["weapon"]],
	["crowbar", "撬棍", ["##", "#."], 1, ["tool"]],
	["drone", "无人机", ["###", ".#."], 2, ["tool"]],
	["sniper", "狙击枪", ["#", "#", "#", "#"], 3, ["weapon"]],
	["armor", "防弹衣", ["###", "###"], 2, ["gear"]],
	["core", "能量核心", [".#.", "###", ".#."], 3, ["part"]],
]


func _initialize() -> void:
	_ensure_dir(SHAPE_DIR)
	_ensure_dir(ITEM_DIR)

	var shapes := 0
	var items := 0
	for row in ITEMS:
		var id: String = row[0]
		var shape := ItemShape.from_ascii(row[2])
		var shape_path := "%s/%s.tres" % [SHAPE_DIR, id]
		if ResourceSaver.save(shape, shape_path) != OK:
			push_error("保存形状失败: " + shape_path)
			quit(1)
			return
		shapes += 1

		var def := ItemDef.new()
		def.id = StringName(id)
		def.display_name = row[1]
		def.shape = load(shape_path)
		def.rarity = row[3]
		var tags: Array[StringName] = []
		for tag in row[4]:
			tags.append(StringName(tag))
		def.tags = tags

		var item_path := "%s/%s.tres" % [ITEM_DIR, id]
		if ResourceSaver.save(def, item_path) != OK:
			push_error("保存物品失败: " + item_path)
			quit(1)
			return
		items += 1

	print("已生成 %d 个形状、%d 个物品定义" % [shapes, items])
	quit(0)


func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
