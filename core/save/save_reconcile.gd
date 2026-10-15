## 173 §3.2：内容对账层 —— 版本链（[MetaMigrations] / [RunMigrations]）管「格式变了」，这里管「格式没变、内容变了」：
## 道具删了、改了名、`state` 键改了名。在版本链之后、`from_dict` 之前，仍在字典层做。
##
## 每件道具字典（`{uid, def, rot, origin, seq, state}`）按 **真名 → [constant IdAliases.ITEMS] → [constant IdAliases.RETIRED_ITEMS]** 查：
## 改过名的把 `def` 写成新名；退役的按表折钱 / 换件 / 丢掉；哪都查不到的默认折钱（待定 1 A）。折钱、丢掉的把 `def` 清空 ——
## 原地留着空壳是为了不打乱和道具一一对应的落点数组（地上的 `spots`），容器读到空 `def` 不告警地跳过。
## 每一件都记进 [SaveReport]。原位放不下的（形状 / 尺寸变了）不归这里，归各容器的 `from_dict` 返回的 homeless 与持有方安置
class_name SaveReconcile
extends RefCounted


## 局外档里归玩家的道具在哪：仓库、带回来的背包
const META_ROOTS := [["warehouse"], ["board"]]
## 一局档里归玩家的道具在哪：棋盘、地上、各点留着的地、保险箱、待拾取 / 搜索收获。
## 敌人的棋盘、节点内容不在这里 —— 那是内容，不是玩家的东西，查不到定义由内容那一侧跳过（[EnemyKit]）
const RUN_ROOTS := [["board"], ["storage"], ["modules", "node_storage"], ["modules", "safe"], ["pending_loot"], ["events", "search_haul"]]

## 作废的一局能捞回仓库的地方（待定 2 A）：棋盘、地上、保险箱
const SALVAGE_ROOTS := [["board"], ["storage"], ["modules", "safe", "inventory"]]


## 对账一份存档字典里 [param roots] 下的道具（原地改）。返回折了多少钱 —— 调用方加进 funds / 钱包
static func items(d: Dictionary, db: ItemDatabase, report: SaveReport = null, roots: Array = META_ROOTS) -> int:
	if db == null:
		return 0
	var total := 0
	for path in roots:
		total += _walk(_dig(d, path), db, report, ".".join(path))
	return total


## 局外档：对账并把折的钱加进 `funds`
static func meta(d: Dictionary, db: ItemDatabase, report: SaveReport = null) -> int:
	var refund := items(d, db, report, META_ROOTS)
	if refund > 0:
		d["funds"] = int(d.get("funds", 0)) + refund
	return refund


## 一局档：对账并把折的钱加进钱包
static func run(d: Dictionary, db: ItemDatabase, report: SaveReport = null) -> int:
	var refund := items(d, db, report, RUN_ROOTS)
	if refund > 0:
		var w: Dictionary = d.get("wallet", {}) if d.get("wallet", {}) is Dictionary else {}
		w["balance"] = int(w.get("balance", 0)) + refund
		d["wallet"] = w
	return refund


## 待定 2 A：作废的一局里能捞回仓库的道具字典 —— 棋盘、地上（暂存区）、保险箱。对账过的、`def` 非空的才算；
## 进不进仓库（[method MetaState.keeps]）由放的那一方判断
static func salvageable(d: Dictionary) -> Array:
	var out: Array = []
	for path in SALVAGE_ROOTS:
		var src: Variant = _dig(d, path)
		if src is Dictionary:
			for raw in (src as Dictionary).get("items", []):
				if is_item(raw) and String((raw as Dictionary).get("def", "")) != "":
					out.append((raw as Dictionary).duplicate(true))
	return out


## 长得像一件道具的存档字典
static func is_item(v: Variant) -> bool:
	return v is Dictionary and (v as Dictionary).has("def") and (v as Dictionary).has("uid") and (v as Dictionary).has("origin")


## 一件道具字典对账（原地改）。返回折的钱。两张表可以换（测试验三种处置与键改名）
static func item(raw: Dictionary, db: ItemDatabase, report: SaveReport = null, from: String = "",
		retired_items: Dictionary = IdAliases.RETIRED_ITEMS, state_keys: Dictionary = IdAliases.STATE_KEYS) -> int:
	_rename_state_keys(raw, state_keys)
	var id := StringName(String(raw.get("def", "")))
	if id == &"" or db.has_exact(id):
		_check_enchant(raw, id, report, from)
		return 0
	var alias := IdAliases.item(id)
	if alias != id and db.has_exact(alias):
		raw["def"] = String(alias)     # 改过名：写成新名，之后读、存都是新名
		_check_enchant(raw, alias, report, from)
		return 0
	var retired: Dictionary = retired_items.get(id, {})
	var to := StringName(String(retired.get("replace", "")))
	if to != &"" and db.has_exact(to):
		raw["def"] = String(to)
		if report != null:
			report.replace(id, to, from)
		return 0
	raw["def"] = ""
	if bool(retired.get("drop", false)):
		if report != null:
			report.drop(id, from)
		return 0
	var value := maxi(0, int(retired.get("value", 0)))     # 待定 1 A：折钱；没登记的按 0，但照样报告
	if report != null:
		report.refund(id, value, from)
	return value


## 175 第三批：附魔里引用的表行查不到了（铸炉映射表删了行）→ 摘掉附魔、报告一行。铸牌也一样（变成一枚没有附魔的牌，悬浮窗写「已失效」）
static func _check_enchant(raw: Dictionary, id: StringName, report: SaveReport, from: String) -> void:
	var state: Variant = raw.get("state", null)
	if not (state is Dictionary) or not (state as Dictionary).has(Forge.KEY):
		return
	var ench: Variant = (state as Dictionary)[Forge.KEY]
	var why := Forge.problem(ench) if ench is Dictionary else "附魔不是字典"
	if why == "":
		return
	(state as Dictionary).erase(Forge.KEY)
	if report != null:
		report.unenchant(id, why, from)


static func _walk(node: Variant, db: ItemDatabase, report: SaveReport, from: String) -> int:
	var total := 0
	if node is Array:
		for v in node:
			total += _walk(v, db, report, from)
	elif is_item(node):
		total += item(node as Dictionary, db, report, from)
	elif node is Dictionary:
		for key in node:
			total += _walk((node as Dictionary)[key], db, report, from)
	return total


static func _rename_state_keys(raw: Dictionary, state_keys: Dictionary) -> void:
	var state: Variant = raw.get("state", null)
	if not (state is Dictionary) or state_keys.is_empty():
		return
	for old in state_keys:
		var new_key: String = String(state_keys[old])
		if (state as Dictionary).has(String(old)) and not (state as Dictionary).has(new_key):
			(state as Dictionary)[new_key] = (state as Dictionary)[String(old)]
			(state as Dictionary).erase(String(old))


static func _dig(d: Dictionary, path: Array) -> Variant:
	var cur: Variant = d
	for k in path:
		if not (cur is Dictionary):
			return null
		cur = (cur as Dictionary).get(k, null)
	return cur
