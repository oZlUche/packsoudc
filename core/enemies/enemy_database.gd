## 按 id 索引所有 [EnemyDef] 与 [EnemyPool]。和 [ItemDatabase] 同一种做法：
## 不做 autoload，由持有方显式创建并传递。
class_name EnemyDatabase
extends RefCounted

const ENEMY_DIR := "res://data/enemies"
const POOL_DIR := "res://data/enemy_pools"

var _enemies: Dictionary = {}  # StringName -> EnemyDef
var _pools: Dictionary = {}    # StringName -> EnemyPool


## 两个目录都扫，返回登记的条数
func load_all() -> int:
	return load_dir(ENEMY_DIR) + load_dir(POOL_DIR)


func load_dir(dir_path: String) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("EnemyDatabase: 无法打开目录 %s" % dir_path)
		return 0
	var count := 0
	for file_name in dir.get_files():
		var name := file_name
		if name.ends_with(".remap"):
			name = name.trim_suffix(".remap")
		if not (name.ends_with(".tres") or name.ends_with(".res")):
			continue
		var res := ResourceLoader.load(dir_path.path_join(name))
		if res is EnemyDef:
			if register_enemy(res):
				count += 1
		elif res is EnemyPool:
			if register_pool(res):
				count += 1
		else:
			push_warning("EnemyDatabase: %s 不是 EnemyDef / EnemyPool，已跳过" % name)
	return count


func register_enemy(def: EnemyDef) -> bool:
	if def == null or not def.is_valid():
		push_warning("EnemyDatabase: 拒绝无效敌人 '%s'" % (def.id if def != null else &"<null>"))
		return false
	if _enemies.has(def.id):
		push_warning("EnemyDatabase: 敌人 id 重复 '%s'，保留先登记的那条" % def.id)
		return false
	_enemies[def.id] = def
	return true


func register_pool(pool: EnemyPool) -> bool:
	if pool == null or pool.id == &"":
		push_warning("EnemyDatabase: 拒绝没有 id 的敌人池")
		return false
	if _pools.has(pool.id):
		push_warning("EnemyDatabase: 敌人池 id 重复 '%s'，保留先登记的那条" % pool.id)
		return false
	_pools[pool.id] = pool
	return true


func enemy(id: StringName) -> EnemyDef:
	return _enemies.get(id, null)


func pool(id: StringName) -> EnemyPool:
	return _pools.get(id, null)


func enemy_ids() -> Array:
	return _enemies.keys()


func pool_ids() -> Array:
	return _pools.keys()


func clear() -> void:
	_enemies.clear()
	_pools.clear()
