## 生成示例形状与物品资产。
##
##     "E:/Godot/..._console.exe" --headless --path . --script res://tools/gen_sample_items.gd
##
## 手写 .tres 太容易出错（尤其 Array[Vector2i] 的字面量格式，写错时 Godot 往往
## 静默留空而不报错），所以用 ResourceSaver 生成。
## 这些是开发期占位内容，正式内容确定后可以直接在编辑器里改这些 .tres。
extends CliTool

const ITEM_DIR := ContentPaths.ITEMS

const ITEMS: Array[Dictionary] = [
	# —— 包体：棋盘上的可用区来自它们 ——
	{"id": "bag_small", "name": "小背包", "bits": "11\n11", "rarity": 0, "bag": true},
	{"id": "bag_leather", "name": "皮革包", "bits": "11\n11\n11", "rarity": 1, "bag": true},
	{"id": "bag_long", "name": "长条包", "bits": "1111", "rarity": 1, "bag": true},
	{
		"id": "belt_potion",
		"name": "药水带",
		"bits": "1\n1\n1",
		"rarity": 2,
		"bag": true,
		"accept": ["consumable"],
	},
	# —— 普通物品 ——
	{"id": "knife", "name": "匕首", "bits": "1", "rarity": 0, "tags": ["weapon"]},
	{"id": "ration", "name": "口粮", "bits": "1", "rarity": 0, "tags": ["consumable"]},
	{"id": "mag", "name": "弹匣", "bits": "1", "rarity": 0, "tags": ["ammo"]},
	{"id": "battery", "name": "电池", "bits": "1", "rarity": 0, "tags": ["part"]},
	{"id": "pistol", "name": "手枪", "bits": "11", "rarity": 1, "tags": ["weapon"]},
	{"id": "medkit", "name": "医疗包", "bits": "11\n11", "rarity": 1, "tags": ["consumable"]},
	{"id": "stim", "name": "兴奋剂", "bits": "1", "rarity": 2, "tags": ["consumable"]},
	{"id": "rifle", "name": "步枪", "bits": "1\n1\n1", "rarity": 2, "tags": ["weapon"]},
	{"id": "crowbar", "name": "撬棍", "bits": "11\n10", "rarity": 1, "tags": ["tool"]},
	{"id": "drone", "name": "无人机", "bits": "111\n010", "rarity": 2, "tags": ["tool"]},
	{"id": "sniper", "name": "狙击枪", "bits": "1\n1\n1\n1", "rarity": 3, "tags": ["weapon"]},
	{"id": "armor", "name": "防弹衣", "bits": "111\n111", "rarity": 2, "tags": ["gear"]},
	{"id": "core", "name": "能量核心", "bits": "010\n111\n010", "rarity": 3, "tags": ["part"]},
]


func run() -> void:
	if _blocked_by_authoring():
		finish(1)
		return
	_ensure_dir(ITEM_DIR)

	var count := 0
	for row in ITEMS:
		var id: String = row["id"]

		# 形状内嵌在物品资产里，不再单独存一份。
		# 曾经 data/shapes/*.tres 是外链的，但导入器产出的资产一律内嵌，
		# 那个目录于是没人读了，已删。
		var def := ItemDef.new()
		def.id = StringName(id)
		def.display_name = row["name"]
		def.shape = ItemShape.from_bits(row["bits"])
		def.rarity = row.get("rarity", 0)
		def.is_bag = row.get("bag", false)
		def.tags = _string_names(row.get("tags", []))
		def.bag_accept_tags = _string_names(row.get("accept", []))

		var item_path := "%s/%s.tres" % [ITEM_DIR, id]
		if ResourceSaver.save(def, item_path) != OK:
			push_error("保存物品失败: " + item_path)
			finish(1)
			return
		count += 1

	print("已生成 %d 个物品定义" % count)
	finish(0)


func _string_names(values: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for v in values:
		out.append(StringName(v))
	return out


func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)

## 内容管线落地之后，这个脚本就成了危险品：它按代码里写死的表重写资产，
## 会把作者在编辑器里配的东西**整个冲掉**，而且不声不响。
##
## 所以先拦一道：作者数据目录一旦有内容，就拒绝运行。
## 真要重新 bootstrap，先把 data/authoring/items 清空（那才是内容的正本）。
func _blocked_by_authoring() -> bool:
	var dir := DirAccess.open(ContentPaths.AUTHORING_ITEMS)
	if dir == null:
		return false
	for f in dir.get_files():
		if f.ends_with(".json"):
			print("")
			print("拒绝运行：%s 下已经有作者数据了。" % ContentPaths.AUTHORING_ITEMS)
			print("这个脚本会按代码里写死的表重写资产，把编辑器里配的内容冲掉。")
			print("正常流程是改 JSON（或用编辑器）再跑 tools/import_content.gd。")
			return true
	return false

