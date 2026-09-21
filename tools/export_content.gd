## 把现有 .tres 倒成作者数据 JSON（架构文档 10.1）。
##
##     "E:/Godot/..._console.exe" --headless --path . --script res://tools/export_content.gd
##
## **一次性迁移用**，也可以在手改过 .tres 之后重新倒一遍。
## 日常流程是反过来的：改 JSON，跑 import_content。
extends SceneTree

const ITEM_DIR := "res://data/items"
const OUT_DIR := "res://data/authoring/items"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var db := ItemDatabase.new()
	if db.load_dir() == 0:
		push_error("没有加载到任何物品定义")
		quit(1)
		return

	var count := 0
	for id in db.ids():
		var def := db.get_def(id)
		if def == null:
			continue
		var data := ContentExporter.export_item(def)
		var path := "%s/%s.json" % [OUT_DIR, id]
		if ContentExporter.save(data, path) != OK:
			push_error("写入失败: " + path)
			quit(1)
			return
		count += 1

	print("已导出 %d 份作者数据到 %s" % [count, OUT_DIR])
	quit(0)
