## 按 id 索引所有 [ItemDef]，供存档反序列化与掉落抽取使用。
##
## 刻意不做成 autoload：核心逻辑层保持无全局状态，由持有方（RunState、测试）
## 显式创建并传递。
class_name ItemDatabase
extends RefCounted

const DEFAULT_DIR := "res://data/items"

var _defs: Dictionary = {}  # StringName -> ItemDef


## 扫描目录加载全部定义，返回成功登记的条数。
##
## 导出后 .tres 可能被转成 .res 或带上 .remap 后缀，这里一并处理。
func load_dir(dir_path: String = DEFAULT_DIR) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("ItemDatabase: 无法打开目录 %s" % dir_path)
		return 0
	var count := 0
	for file_name in dir.get_files():
		var name := file_name
		if name.ends_with(".remap"):
			name = name.trim_suffix(".remap")
		if not (name.ends_with(".tres") or name.ends_with(".res")):
			continue
		var res := ResourceLoader.load(dir_path.path_join(name))
		if res is ItemDef:
			if register(res):
				count += 1
		else:
			push_warning("ItemDatabase: %s 不是 ItemDef，已跳过" % name)
	return count


## 登记一条定义。id 为空、形状非法或 id 重复时拒绝并返回 false。
func register(def: ItemDef) -> bool:
	if def == null or not def.is_valid():
		push_warning("ItemDatabase: 拒绝无效定义 '%s'" % (def.id if def != null else &"<null>"))
		return false
	if _defs.has(def.id):
		push_warning("ItemDatabase: id 重复 '%s'，保留先登记的那条" % def.id)
		return false
	_defs[def.id] = def
	return true


func get_def(id: StringName) -> ItemDef:
	return _defs.get(id, null)


func has_def(id: StringName) -> bool:
	return _defs.has(id)


func ids() -> Array:
	return _defs.keys()


func size() -> int:
	return _defs.size()


func clear() -> void:
	_defs.clear()
