## 按 id 索引所有 [ItemSetDef]。与 [ItemDatabase] 同一模式：不做 autoload，
## 由持有方显式创建并传递，核心逻辑层保持无全局状态。
class_name SetDatabase
extends RefCounted

const DEFAULT_DIR := "res://data/sets"

var _defs: Dictionary = {}  # StringName -> ItemSetDef


func load_dir(dir_path: String = DEFAULT_DIR) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var count := 0
	for file_name in dir.get_files():
		var name := file_name
		if name.ends_with(".remap"):
			name = name.trim_suffix(".remap")
		if not (name.ends_with(".tres") or name.ends_with(".res")):
			continue
		var res := ResourceLoader.load(dir_path.path_join(name))
		if res is ItemSetDef and register(res):
			count += 1
	return count


func register(def: ItemSetDef) -> bool:
	if def == null or not def.is_valid():
		push_warning("SetDatabase: 拒绝无效套装定义")
		return false
	if _defs.has(def.id):
		push_warning("SetDatabase: id 重复 '%s'，保留先登记的那条" % def.id)
		return false
	_defs[def.id] = def
	return true


func get_def(id: StringName) -> ItemSetDef:
	return _defs.get(id, null)


func ids() -> Array:
	var k := _defs.keys()
	k.sort()
	return k


func size() -> int:
	return _defs.size()
