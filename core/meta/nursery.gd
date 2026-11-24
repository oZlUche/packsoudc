## 342 B3：河滩垦户社的苗圃 —— 局外的几片地（[member MetaState.nursery]），后勤里播种、收获。
##
## 作者 2026-11-21 19:07：每片地是一块棋盘（[member fields]），作物照收成的形状一株一株摆进去，摆得下几株就种几株；
## 每种作物自己的成熟局数（[constant CROPS] 的 runs），每株各长各的（[member growth]）。以后田里还能摆增产、催熟相邻作物的特殊道具。
##
## - 一次有实际探索的正式出征结算推进一格（胜败都算，[method advance]，和这一局的其他结果同一次并入，按局号防重复）；
##   重载、没走出起点的空跑、教程局、试玩切片不推进。
## - 播种一次种一株（[method sow]），种苗按株扣（苦叶草一株一束干草药，别的垦户社给）。
## - 熟了留在地里；收获（[method harvest]）一次收这一片熟了的全部：仓库放得下才收，放不下整体退回，不多给也不吞。
## - 作物是初值：苦叶草一株收两束干草药，别的一株收一件收成（食材作物偶尔多收一件优良的）
class_name Nursery
extends RefCounted

## 几片：389 起按垦户社到了几个 `nursery_plot` 节点（10 / 50 / 100，[method plots_for]）。老档读回来至少一片
const PLOTS := 1
const MAX_PLOTS := 3
## 每片地多大
const FIELD := Vector2i(4, 4)
## 地的格子盘编号（第 i 片 = FIELD_ID + i）
const FIELD_ID := 110
## 作物 → {"product": 收什么（也是摆在地里的形状）, "yield": 一株收几件, "runs": 几局成熟, "seed": {道具 id: 一株扣几件}（播种时从仓库扣）}；
## 355：食材作物另带 "food": 类别（灰灯食堂开了才能种），"bonus": {"id": 少量额外收成, "chance": 一株多收一件的概率}
const CROPS := {
	&"bitter_leaf": {"product": &"dried_herbs", "yield": 2, "runs": 2, "seed": {&"dried_herbs": 1}},
	&"rope_hemp": {"product": &"rope_coil", "yield": 1, "runs": 3, "seed": {}},
	&"sour_wheat": {"product": &"sour_wheat", "yield": 1, "runs": 2, "seed": {}, "food": &"staple", "bonus": {"id": &"golden_wheat", "chance": 0.15}},
	&"black_bean": {"product": &"black_bean", "yield": 1, "runs": 3, "seed": {}, "food": &"staple"},
	&"mountain_yam": {"product": &"mountain_yam", "yield": 1, "runs": 3, "seed": {}, "food": &"staple", "bonus": {"id": &"jade_yam", "chance": 0.15}},
	&"rice_sack": {"product": &"rice_sack", "yield": 1, "runs": 4, "seed": {}, "food": &"staple"},
	&"big_pumpkin": {"product": &"big_pumpkin", "yield": 1, "runs": 5, "seed": {}, "food": &"staple"},
	&"coarse_wheat_bundle": {"product": &"coarse_wheat_bundle", "yield": 1, "runs": 4, "seed": {}, "food": &"staple", "bonus": {"id": &"golden_wheat", "chance": 0.25}},
	&"wild_scallion": {"product": &"wild_scallion", "yield": 1, "runs": 1, "seed": {}, "food": &"veg"},
	&"fragrant_root": {"product": &"fragrant_root", "yield": 1, "runs": 2, "seed": {}, "food": &"veg"},
	&"long_scallion": {"product": &"long_scallion", "yield": 1, "runs": 3, "seed": {}, "food": &"veg"},
	&"turnip": {"product": &"turnip", "yield": 1, "runs": 4, "seed": {}, "food": &"veg"},
	&"bitter_endive": {"product": &"bitter_endive", "yield": 1, "runs": 2, "seed": {}, "food": &"veg"},
	&"cabbage": {"product": &"cabbage", "yield": 1, "runs": 5, "seed": {}, "food": &"veg"},
	&"wild_berry": {"product": &"wild_berry", "yield": 1, "runs": 2, "seed": {}, "food": &"fruit"},
	&"mountain_pear": {"product": &"mountain_pear", "yield": 1, "runs": 3, "seed": {}, "food": &"fruit"},
	&"honeydew": {"product": &"honeydew", "yield": 1, "runs": 5, "seed": {}, "food": &"fruit"},
	&"red_berry_cluster": {"product": &"red_berry_cluster", "yield": 1, "runs": 3, "seed": {}, "food": &"fruit"},
	&"honey_pomelo": {"product": &"honey_pomelo", "yield": 1, "runs": 6, "seed": {}, "food": &"fruit"},
}
const ORDER: Array[StringName] = [&"bitter_leaf", &"rope_hemp",
	&"sour_wheat", &"black_bean", &"mountain_yam", &"rice_sack", &"big_pumpkin", &"coarse_wheat_bundle",
	&"wild_scallion", &"fragrant_root", &"long_scallion", &"turnip", &"bitter_endive", &"cabbage",
	&"wild_berry", &"mountain_pear", &"honeydew", &"red_berry_cluster", &"honey_pomelo"]
## 355：作物分几栏（后勤页一栏一排纸条）：药材（原来那两种）、主食、蔬菜、水果
const GROUP_HERB := &"herb"
const GROUPS: Array[StringName] = [&"herb", &"staple", &"veg", &"fruit"]
## 种不了 / 收不了的原因（字表键 `nursery.why_<原因>`）
const WHY_ROOM := "room"
const WHY_SEED := "seed"
const WHY_UNRIPE := "unripe"
const WHY_FULL := "full"
const WHY_UNKNOWN := "unknown"
## 355：食材作物要灰灯食堂开了才种
const WHY_CANTEEN := "canteen"

## 每片地一块棋盘：种下的每一株是一件收成道具（照它的形状占格）
var fields: Array[GridInventory] = []
## 每株长到哪：uid → {"crop": 作物, "left": 还差几局}
var growth: Dictionary = {}
## 最后推进过的那一局（[member RunResult.run_id]），同一局不推进两次
var last_run := ""
## 播种、收获的流水号（委托的去重键、额外收成的随机数用）
var seq := 0
## 老档（一畦一种）读回来还没摆进棋盘的：[{"field", "crop", "left"}]，[method adopt_legacy] 摆
var _legacy: Array[Dictionary] = []


func _init() -> void:
	while fields.size() < PLOTS:
		fields.append(_field(fields.size()))


static func _field(i: int) -> GridInventory:
	return GridInventory.new(FIELD, FIELD_ID + i, false)


func field(i: int) -> GridInventory:
	return fields[i] if i >= 0 and i < fields.size() else null


## 389：垦户社现在该有几片（到了几个 `nursery_plot` 节点，至少 [constant PLOTS]、最多 [constant MAX_PLOTS]）
static func plots_for(book: CommissionBook) -> int:
	var n := Commissions.reached_with(book, Commissions.faction(&"growers"), &"nursery_plot").size()
	return clampi(n, PLOTS, MAX_PLOTS)


## 355：补到 [param want] 片（只加不减）。返回加了没有
func fit(want: int) -> bool:
	var grew := false
	while fields.size() < mini(want, MAX_PLOTS):
		fields.append(_field(fields.size()))
		grew = true
	return grew


## 355：作物在哪一栏
static func group_of(crop: StringName) -> StringName:
	return StringName(String((CROPS.get(crop, {}) as Dictionary).get("food", GROUP_HERB)))


## 355：这一栏的作物（按 [constant ORDER]）
static func crops_in(group: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for c in ORDER:
		if group_of(c) == group:
			out.append(c)
	return out


#region 一株
func crop_of(uid: int) -> StringName:
	return StringName(String((growth.get(uid, {}) as Dictionary).get("crop", "")))


## 还差几局（不是地里的 = -1）
func left_of(uid: int) -> int:
	return int((growth.get(uid, {}) as Dictionary).get("left", -1))


func unit_ripe(uid: int) -> bool:
	return growth.has(uid) and left_of(uid) <= 0


## 第 [param i] 片熟了的那几株
func ripe_units(i: int) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	var g := field(i)
	if g == null:
		return out
	for inst in g.items():
		if unit_ripe((inst as ItemInstance).uid):
			out.append(inst)
	return out


## 第 [param i] 片有熟了的
func is_ripe(i: int) -> bool:
	return not ripe_units(i).is_empty()


## 熟了的一共几株
func ripe_count() -> int:
	var n := 0
	for i in fields.size():
		n += ripe_units(i).size()
	return n


## 第 [param i] 片种着的那几株
func plants(i: int) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	var g := field(i)
	if g != null:
		for inst in g.items():
			out.append(inst as ItemInstance)
	return out


## 第 [param i] 片一株也没种
func is_empty(i: int) -> bool:
	var g := field(i)
	return g == null or g.item_count() == 0
#endregion


## 仓库里能当种苗的那几件（没锁的）；不够 = 空
static func seed_picks(meta: MetaState, crop: StringName) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	var need: Dictionary = (CROPS.get(crop, {}) as Dictionary).get("seed", {})
	for id in need:
		var got: Array[ItemInstance] = []
		for inst in meta.warehouse.items():
			var it := inst as ItemInstance
			if it.def != null and it.def.id == StringName(id) and not it.is_locked_by_player():
				got.append(it)
		if got.size() < int(need[id]):
			return [] as Array[ItemInstance]
		out.append_array(got.slice(0, int(need[id])))
	return out


## 一株摆在哪：[param at] 给了（不是 -1）就那里、那个朝向；否则第一个摆得下的地方。摆不下 = {"found": false}
static func spot(g: GridInventory, def: ItemDef, at: Vector2i = Vector2i(-1, -1), rot: int = 0) -> Dictionary:
	if g == null or def == null:
		return {"found": false}
	if at.x >= 0:
		return {"found": g.can_place_def(def, at, rot), "origin": at, "rotation": rot}
	return g.find_first_fit(def, true)


## 能不能在第 [param i] 片种一株 [param crop]（[param at] 见 [method spot]）：空串 = 能
static func why_not_sow(meta: MetaState, i: int, crop: StringName, items: ItemDatabase = null, at: Vector2i = Vector2i(-1, -1), rot: int = 0) -> String:
	if meta == null or not CROPS.has(crop):
		return WHY_UNKNOWN
	var g := meta.nursery.field(i)
	if g == null:
		return WHY_UNKNOWN
	if (CROPS[crop] as Dictionary).has("food") and not meta.canteen_open():
		return WHY_CANTEEN
	var def := _product(crop, items)
	if def == null:
		return WHY_UNKNOWN
	if not bool(spot(g, def, at, rot)["found"]):
		return WHY_ROOM
	var need: Dictionary = CROPS[crop]["seed"]
	if not need.is_empty() and seed_picks(meta, crop).is_empty():
		return WHY_SEED
	return ""


static func _product(crop: StringName, items: ItemDatabase) -> ItemDef:
	var id := StringName((CROPS.get(crop, {}) as Dictionary).get("product", &""))
	if id == &"":
		return null
	if items != null:
		return items.get_def(id)
	return ContentPaths.load_asset("items", String(id)) as ItemDef


## 播种一株：扣种苗、摆进地里、记下还差几局。返回原因（空 = 种上了）
static func sow(meta: MetaState, i: int, crop: StringName, items: ItemDatabase = null, at: Vector2i = Vector2i(-1, -1), rot: int = 0) -> String:
	var why := why_not_sow(meta, i, crop, items, at, rot)
	if why != "":
		return why
	var def := _product(crop, items)
	var g := meta.nursery.field(i)
	var where := spot(g, def, at, rot)
	for it in seed_picks(meta, crop):
		meta.warehouse.remove(it.uid)
	var inst := ItemInstance.create(def, int(where["rotation"]))
	inst.uid = meta.allocate_uid()
	g.place(inst, where["origin"], int(where["rotation"]))
	var n := meta.nursery
	n.growth[inst.uid] = {"crop": String(crop), "left": int(CROPS[crop]["runs"])}
	n.seq += 1
	meta.changed.emit()
	return ""


## 一局正式探索结算完：每株还没熟的近一格。同一局（[param run_id]）只推进一次。返回这回推进了没有
static func advance(meta: MetaState, run_id: String) -> bool:
	if meta == null or run_id == "" or meta.nursery.last_run == run_id:
		return false
	var n := meta.nursery
	n.last_run = run_id
	for uid in n.growth:
		var g: Dictionary = n.growth[uid]
		if int(g["left"]) > 0:
			g["left"] = int(g["left"]) - 1
	return true


## 收获第 [param i] 片熟了的全部：都放进仓库才算，放不下整体退回、地里照旧。
## 返回 {"why": 原因（空 = 收了）, "crop": 收的第一种作物, "crops": {作物: 几株}, "items": 几件}
static func harvest(meta: MetaState, i: int, items: ItemDatabase) -> Dictionary:
	var out := {"why": "", "crop": "", "crops": {}, "items": 0}
	if meta == null or items == null or meta.nursery.field(i) == null:
		out["why"] = WHY_UNKNOWN
		return out
	var n := meta.nursery
	var ripe := n.ripe_units(i)
	if ripe.is_empty():
		out["why"] = WHY_UNRIPE
		return out
	var rng := RandomNumberGenerator.new()     # 355：少量额外收成，按流水号定（同一档读回来收一样多）
	rng.seed = hash([n.seq, i, "bonus"])
	var defs: Array[ItemDef] = []
	var crops := {}
	var first := ""
	for unit in ripe:
		var crop := n.crop_of(unit.uid)
		if first == "":
			first = String(crop)
		var spec: Dictionary = CROPS.get(crop, {})
		crops[String(crop)] = int(crops.get(String(crop), 0)) + 1
		for _k in int(spec.get("yield", 1)):
			defs.append(unit.def)
		var bonus: Dictionary = spec.get("bonus", {})
		var bd := items.get_def(StringName(bonus.get("id", &""))) if not bonus.is_empty() else null
		if bd != null and rng.randf() < float(bonus.get("chance", 0.0)):
			defs.append(bd)
	var added: Array[ItemInstance] = []
	for d in defs:
		var inst := ItemInstance.create(d, 0)
		inst.uid = meta.allocate_uid()
		if not meta.stash_item(inst):     # 355：食材先进食材仓库
			for a in added:
				if meta.canteen.store.has_item(a.uid):
					meta.canteen.store.remove(a.uid)
				else:
					meta.warehouse.remove(a.uid)
			out["why"] = WHY_FULL
			return out
		added.append(inst)
	var g := n.field(i)
	for unit in ripe:
		g.remove(unit.uid)
		n.growth.erase(unit.uid)
	n.seq += 1
	out["crop"] = first
	out["crops"] = crops
	out["items"] = added.size()
	meta.changed.emit()
	return out


#region 存档
func to_dict() -> Dictionary:
	var fs: Array = []
	for g in fields:
		fs.append(g.to_dict())
	var gr := {}
	for uid in growth:
		gr[str(uid)] = (growth[uid] as Dictionary).duplicate()
	return {"fields": fs, "growth": gr, "last_run": last_run, "seq": seq}


## 读回来。老档（`plots`：一畦一种）记下来，等 [method adopt_legacy] 每畦摆一株进对应的那片地
static func from_dict(d: Variant, items: ItemDatabase = null) -> Nursery:
	var n := Nursery.new()
	if not (d is Dictionary):
		return n
	var src := d as Dictionary
	var raw_fields: Variant = src.get("fields", null)
	if raw_fields is Array and items != null:
		n.fields.clear()
		for k in mini((raw_fields as Array).size(), MAX_PLOTS):
			var raw_g: Variant = (raw_fields as Array)[k]
			var g := GridInventory.from_dict(raw_g as Dictionary, items) if raw_g is Dictionary else _field(k)
			g.id = FIELD_ID + k
			n.fields.append(g)
		if n.fields.is_empty():
			n.fields.append(_field(0))
		var gr: Dictionary = src.get("growth", {}) if src.get("growth", null) is Dictionary else {}
		for g in n.fields:
			for inst in g.items():
				var it := inst as ItemInstance
				var e: Variant = gr.get(str(it.uid), null)
				var crop := StringName(String((e as Dictionary).get("crop", ""))) if e is Dictionary else &""
				if crop == &"" or not CROPS.has(crop):
					g.remove(it.uid)     # 认不得的作物（退役了）当空地
					continue
				n.growth[it.uid] = {"crop": String(crop), "left": maxi(0, int((e as Dictionary).get("left", 0)))}
	var raw: Array = src.get("plots", []) if src.get("plots", null) is Array else []
	while n.fields.size() < mini(raw.size(), MAX_PLOTS):
		n.fields.append(_field(n.fields.size()))
	for k in mini(raw.size(), MAX_PLOTS):
		if raw[k] is Dictionary:
			var crop := String(raw[k].get("crop", ""))
			if crop != "" and CROPS.has(StringName(crop)):
				n._legacy.append({"field": k, "crop": crop, "left": maxi(0, int(raw[k].get("left", 0)))})
	n.last_run = String(src.get("last_run", ""))
	n.seq = int(src.get("seq", 0))
	return n


## 老档那几畦：每畦种着的摆一株进对应那片地，还差几局照旧（读档时 [MetaState] 定好 uid 起点之后调）
func adopt_legacy(meta: MetaState, items: ItemDatabase) -> void:
	for e in _legacy:
		var g := field(int(e["field"]))
		var def := _product(StringName(String(e["crop"])), items)
		var where := spot(g, def)
		if g == null or not bool(where["found"]):
			continue
		var inst := ItemInstance.create(def, int(where["rotation"]))
		inst.uid = meta.allocate_uid()
		g.place(inst, where["origin"], int(where["rotation"]))
		growth[inst.uid] = {"crop": String(e["crop"]), "left": int(e["left"])}
	_legacy.clear()


## 老档读回来还有几畦等着摆（测试用）
func legacy_count() -> int:
	return _legacy.size()
#endregion
