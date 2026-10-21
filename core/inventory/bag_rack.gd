## 225 补充一 / 补充二（作者 2026-10-21 18:27 定「包架列表」）：局外的**包架** —— 包是装备不是货，不占仓库格。
##
## 一个列表（[ItemStash]），只收「包」（带信仰的护符除外，它是珍宝、照旧进仓库，见 [method MetaState.keeps]）。
## 同一种包叠在一格里显示（[BagRackView] 画 ×n），存档只记「包 id → 这几只的 uid」（[method to_save]）。
## 撤离带回来的包在置入时进来；开局第二页从这里拖包上棋盘
class_name BagRack
extends ItemStash


## 这件东西进不进包架：是包、又不是仓库收的那种（信仰护符）
static func holds(def: ItemDef) -> bool:
	return def != null and def.is_bag and not MetaState.keeps(def)


func accepts(def: ItemDef) -> bool:
	return holds(def)


## 包架上不画落点（[ItemStash] 的落点只给地上用）
func next_free_spot(_inst: ItemInstance) -> Vector2:
	return NO_SPOT


## 有哪几种包，按第一只进来的先后
func kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for inst in _list:
		if not out.has(inst.def.id):
			out.append(inst.def.id)
	return out


func count_of(id: StringName) -> int:
	var n := 0
	for inst in _list:
		if inst.def.id == id:
			n += 1
	return n


## 这种包的第一只（拖、卖、自动摆上棋盘都拿它）；没有 null
func first_of(id: StringName) -> ItemInstance:
	for inst in _list:
		if inst.def.id == id:
			return inst
	return null


## 各种包几只：包 id（字符串）→ 只数，按 [method kinds] 的顺序
func counts() -> Dictionary:
	var out := {}
	for id in kinds():
		out[String(id)] = count_of(id)
	return out


## 存档：包 id（字符串）→ 这几只的 uid（按 [method kinds] 的顺序）。只记 id 与 uid —— 读回来逐字节一样（uid 不重编，局外号段不往前跳）
func to_save() -> Dictionary:
	var out := {}
	for inst in _list:
		var key := String(inst.def.id)
		if not out.has(key):
			out[key] = []
		(out[key] as Array).append(inst.uid)
	return out


## 读档：[method to_save] 的样子（某种包写成只数也认，这时 uid 问 [param next_uid]（`func() -> int`））。
## 内容里已经没有的 id（删了的包）跳过并记进 [param lost]（字符串 id）
static func from_save(d: Dictionary, db: ItemDatabase, next_uid: Callable, p_id: int = 0, lost: Array = []) -> BagRack:
	var rack := BagRack.new(p_id)
	for key in d:
		var def := db.get_def(StringName(String(key))) if db != null else null
		if def == null or not holds(def):
			lost.append(String(key))
			continue
		var uids: Array = d[key] if d[key] is Array else []
		var n := uids.size() if d[key] is Array else maxi(0, int(d[key]))
		for i in n:
			var inst := ItemInstance.create(def, 0)
			inst.uid = int(uids[i]) if i < uids.size() else int(next_uid.call())
			rack.insert(inst)
	return rack
