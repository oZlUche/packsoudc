## 按 id 索引所有 [ItemDef]，供存档反序列化与掉落抽取使用。
##
## 刻意不做成 autoload：核心逻辑层保持无全局状态，由持有方（RunState、测试）
## 显式创建并传递。
class_name ItemDatabase
extends RefCounted

const DEFAULT_DIR := "res://data/items"

var _defs: Dictionary = {}  # StringName -> ItemDef
## 091：现在锁着的道具（`requires_unlock` 还没解锁）。[GameFlow] 开局前按局外算好设进来；没设 = 都没锁（测试、沙盒照旧）
var _locked: Dictionary = {}


## 091：设一批锁着的道具 id（[method ids] 不再给它们）
func set_locked(ids: Array) -> void:
	_locked.clear()
	for id in ids:
		_locked[StringName(String(id))] = true


func is_locked(id: StringName) -> bool:
	return _locked.has(id)


## 091：带解锁要求的道具（不管解没解锁）
func gated_ids() -> Array:
	var out: Array = []
	for id in _defs:
		if (_defs[id] as ItemDef).requires_unlock != &"":
			out.append(id)
	return out


## 扫描目录加载全部定义，返回成功登记的条数。
##
## 导出后 .tres 可能被转成 .res 或带上 .remap 后缀，这里一并处理。
## 095：加载完按信仰的赐福模板派生赐福版（测试想要干净的库可以关）
static var derive_blessings: bool = true
const BlessingsScript := preload("res://core/run/faith/blessings.gd")
const FaithDefScript := preload("res://core/run/faith/faith_def.gd")


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
	if derive_blessings:
		count += BlessingsScript.derive_all(self, FaithDefScript.load_all())     # 095：按信仰的赐福模板派生赐福版
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


## 098：找不到就问一次改名表（[IdAliases]）—— 老存档里写的是旧 id，内容改了名不该让仓库里的东西悄悄消失
func get_def(id: StringName) -> ItemDef:
	var d: ItemDef = _defs.get(id, null)
	if d != null:
		return d
	var alias := IdAliases.item(id)
	return _defs.get(alias, null) if alias != id else null


func has_def(id: StringName) -> bool:
	return _defs.has(id) or _defs.has(IdAliases.item(id))


## 能用的道具：**封存的不在里面**（[constant ItemDef.SEALED]）。搜索、掉落、商店、敌人装备、图鉴、编辑器都从这里拿候选 ——
## 封存只在这一处拦，别处不必各查一遍。要全部（导出、存档校对）用 [method all_ids]。
## 091：锁着的（成就还没解锁）也不给；图鉴要连锁着的一起列，传 [param include_locked]
func ids(include_locked: bool = false) -> Array:
	var out: Array = []
	for id in _defs:
		var d := _defs[id] as ItemDef
		if d.is_sealed() or d.is_keepsake() or d.is_blessed():     # 088：特殊道具也不能生成；095：赐福版只从赐福来
			continue
		if not include_locked and _locked.has(id):
			continue
		out.append(id)
	return out


## 095：派生出来的赐福版（不进生成池，只从赐福来）
func blessed_ids() -> Array:
	var out: Array = []
	for id in _defs:
		if (_defs[id] as ItemDef).is_blessed():
			out.append(id)
	return out


## 095：这件的全部异体（原件 + 各神的赐福版），按 id 升序；传赐福版进来也认原件
func variants_of(base_id: StringName) -> Array:
	var root := base_id
	var d := get_def(base_id)
	if d != null and d.is_blessed():
		root = d.blessed_of
	var out: Array = []
	for id in _defs:
		var def := _defs[id] as ItemDef
		if id == root or (def.is_blessed() and def.blessed_of == root):
			out.append(id)
	Ids.sort(out)     # 按文本排，不是 StringName 的指针序（见 [Ids]）
	return out


## 088：特殊道具（不进背包、不能生成，只在图鉴里点亮）
func keepsake_ids() -> Array:
	var out: Array = []
	for id in _defs:
		if (_defs[id] as ItemDef).is_keepsake():
			out.append(id)
	return out


## 全部，含封存的
func all_ids() -> Array:
	return _defs.keys()


## 封存的那些
func sealed_ids() -> Array:
	var out: Array = []
	for id in _defs:
		if (_defs[id] as ItemDef).is_sealed():
			out.append(id)
	return out


func size() -> int:
	return _defs.size()


func clear() -> void:
	_defs.clear()
