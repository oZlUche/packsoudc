## 342 B3：河滩垦户社的苗圃 —— 局外的几畦地（[member MetaState.nursery]），后勤里播种、收获。
##
## - 一次有实际探索的正式出征结算推进一格（胜败都算，[method advance]，和这一局的其他结果同一次并入，按局号防重复）；
##   重载、没走出起点的空跑、教程局、试玩切片不推进。
## - 成熟了留在地里；仓库放得下才收（[method harvest]）：扣种、入库、清畦一次做完，放不下整体退回，不多给也不吞。
## - 作物（[constant CROPS]）是初值：苦叶草用一束干草药留种、两局收两束；绳麻的种苗垦户社给、三局收一卷麻绳
class_name Nursery
extends RefCounted

## 几畦：垦户社熟面开一畦；355：信赖开第二畦、代言开第三畦（[method plots_for]）。老档读回来至少一畦
const PLOTS := 1
const MAX_PLOTS := 3
## 第几档开到几畦：[熟面及以下, 信赖, 代言]
const PLOT_TIERS: Array[int] = [3, 4]
## 作物 → {"product": 收什么, "count": 几件, "runs": 几局成熟, "seed": {道具 id: 件数}（播种时从仓库扣）}；
## 355：食材作物另带 "food": 类别（灰灯食堂开了才能种），"bonus": {"id": 少量额外收成, "chance": 每件的概率}
const CROPS := {
	&"bitter_leaf": {"product": &"dried_herbs", "count": 2, "runs": 2, "seed": {&"dried_herbs": 1}},
	&"rope_hemp": {"product": &"rope_coil", "count": 1, "runs": 3, "seed": {}},
	&"sour_wheat": {"product": &"sour_wheat", "count": 4, "runs": 2, "seed": {}, "food": &"staple", "bonus": {"id": &"golden_wheat", "chance": 0.15}},
	&"black_bean": {"product": &"black_bean", "count": 4, "runs": 2, "seed": {}, "food": &"staple"},
	&"mountain_yam": {"product": &"mountain_yam", "count": 3, "runs": 2, "seed": {}, "food": &"staple", "bonus": {"id": &"jade_yam", "chance": 0.15}},
	&"rice_sack": {"product": &"rice_sack", "count": 3, "runs": 2, "seed": {}, "food": &"staple"},
	&"big_pumpkin": {"product": &"big_pumpkin", "count": 2, "runs": 3, "seed": {}, "food": &"staple"},
	&"coarse_wheat_bundle": {"product": &"coarse_wheat_bundle", "count": 2, "runs": 3, "seed": {}, "food": &"staple", "bonus": {"id": &"golden_wheat", "chance": 0.25}},
	&"wild_scallion": {"product": &"wild_scallion", "count": 4, "runs": 2, "seed": {}, "food": &"veg"},
	&"fragrant_root": {"product": &"fragrant_root", "count": 3, "runs": 2, "seed": {}, "food": &"veg"},
	&"long_scallion": {"product": &"long_scallion", "count": 3, "runs": 3, "seed": {}, "food": &"veg"},
	&"turnip": {"product": &"turnip", "count": 2, "runs": 3, "seed": {}, "food": &"veg"},
	&"bitter_endive": {"product": &"bitter_endive", "count": 3, "runs": 2, "seed": {}, "food": &"veg"},
	&"cabbage": {"product": &"cabbage", "count": 2, "runs": 3, "seed": {}, "food": &"veg"},
	&"wild_berry": {"product": &"wild_berry", "count": 4, "runs": 2, "seed": {}, "food": &"fruit"},
	&"mountain_pear": {"product": &"mountain_pear", "count": 3, "runs": 2, "seed": {}, "food": &"fruit"},
	&"honeydew": {"product": &"honeydew", "count": 2, "runs": 3, "seed": {}, "food": &"fruit"},
	&"red_berry_cluster": {"product": &"red_berry_cluster", "count": 3, "runs": 2, "seed": {}, "food": &"fruit"},
	&"honey_pomelo": {"product": &"honey_pomelo", "count": 2, "runs": 3, "seed": {}, "food": &"fruit"},
}
const ORDER: Array[StringName] = [&"bitter_leaf", &"rope_hemp",
	&"sour_wheat", &"black_bean", &"mountain_yam", &"rice_sack", &"big_pumpkin", &"coarse_wheat_bundle",
	&"wild_scallion", &"fragrant_root", &"long_scallion", &"turnip", &"bitter_endive", &"cabbage",
	&"wild_berry", &"mountain_pear", &"honeydew", &"red_berry_cluster", &"honey_pomelo"]
## 355：作物分几栏（后勤页一栏一排纸条）：药材（原来那两种）、主食、蔬菜、水果
const GROUP_HERB := &"herb"
const GROUPS: Array[StringName] = [&"herb", &"staple", &"veg", &"fruit"]
## 种不了 / 收不了的原因（字表键 `nursery.why_<原因>`）
const WHY_BUSY := "busy"
const WHY_SEED := "seed"
const WHY_UNRIPE := "unripe"
const WHY_FULL := "full"
const WHY_UNKNOWN := "unknown"
## 355：食材作物要灰灯食堂开了才种
const WHY_CANTEEN := "canteen"

## 每畦：{"crop": 作物（空 = 空地）, "sown_run": 播种时是第几局, "left": 还差几局}
var plots: Array[Dictionary] = []
## 最后推进过的那一局（[member RunResult.run_id]），同一局不推进两次
var last_run := ""
## 播种、收获的流水号（委托的去重键用）
var seq := 0


func _init() -> void:
	while plots.size() < PLOTS:
		plots.append(_empty())


## 355：垦户社第 [param tier] 档有几畦
static func plots_for(tier: int) -> int:
	var n := PLOTS
	for t in PLOT_TIERS:
		if tier >= t:
			n += 1
	return mini(n, MAX_PLOTS)


## 355：按档补地（只加不减）。返回加了没有
func fit(tier: int) -> bool:
	var want := plots_for(tier)
	var grew := false
	while plots.size() < want:
		plots.append(_empty())
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


static func _empty() -> Dictionary:
	return {"crop": "", "sown_run": 0, "left": 0}


func plot(i: int) -> Dictionary:
	return plots[i] if i >= 0 and i < plots.size() else {}


func is_ripe(i: int) -> bool:
	var p := plot(i)
	return String(p.get("crop", "")) != "" and int(p.get("left", 0)) <= 0


## 有几畦可以收
func ripe_count() -> int:
	var n := 0
	for i in plots.size():
		if is_ripe(i):
			n += 1
	return n


## 仓库里能当种苗的那几件（没锁的、便宜的先用）；不够 = 空
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


## 能不能在第 [param i] 畦种 [param crop]：空串 = 能
static func why_not_sow(meta: MetaState, i: int, crop: StringName) -> String:
	if meta == null or not CROPS.has(crop):
		return WHY_UNKNOWN
	var p := meta.nursery.plot(i)
	if p.is_empty():
		return WHY_UNKNOWN
	if String(p["crop"]) != "":
		return WHY_BUSY
	if (CROPS[crop] as Dictionary).has("food") and not meta.canteen_open():
		return WHY_CANTEEN
	var need: Dictionary = CROPS[crop]["seed"]
	if not need.is_empty() and seed_picks(meta, crop).is_empty():
		return WHY_SEED
	return ""


## 播种：扣种苗、记下第几局种的。返回原因（空 = 种上了）
static func sow(meta: MetaState, i: int, crop: StringName) -> String:
	var why := why_not_sow(meta, i, crop)
	if why != "":
		return why
	for it in seed_picks(meta, crop):
		meta.warehouse.remove(it.uid)
	var n := meta.nursery
	n.plots[i] = {"crop": String(crop), "sown_run": meta.runs, "left": int(CROPS[crop]["runs"])}
	n.seq += 1
	meta.changed.emit()
	return ""


## 一局正式探索结算完：每畦还没熟的近一格。同一局（[param run_id]）只推进一次。返回这回推进了没有
static func advance(meta: MetaState, run_id: String) -> bool:
	if meta == null or run_id == "" or meta.nursery.last_run == run_id:
		return false
	var n := meta.nursery
	n.last_run = run_id
	for p in n.plots:
		if String(p["crop"]) != "" and int(p["left"]) > 0:
			p["left"] = int(p["left"]) - 1
	return true


## 收获第 [param i] 畦：全部放进仓库才算，放不下整体退回、地里照旧。返回 {"why": 原因（空 = 收了）, "crop", "items": 几件}
static func harvest(meta: MetaState, i: int, items: ItemDatabase) -> Dictionary:
	var out := {"why": "", "crop": "", "items": 0}
	if meta == null or items == null or meta.nursery.plot(i).is_empty():
		out["why"] = WHY_UNKNOWN
		return out
	if not meta.nursery.is_ripe(i):
		out["why"] = WHY_UNRIPE
		return out
	var crop := StringName(String(meta.nursery.plots[i]["crop"]))
	var spec: Dictionary = CROPS.get(crop, {})
	var def := items.get_def(StringName(spec.get("product", &"")))
	if def == null:
		out["why"] = WHY_UNKNOWN
		return out
	var added: Array[ItemInstance] = []
	var defs: Array[ItemDef] = []
	for _k in int(spec["count"]):
		defs.append(def)
	var bonus: Dictionary = spec.get("bonus", {})
	if not bonus.is_empty() and items.get_def(StringName(bonus.get("id", &""))) != null:
		var rng := RandomNumberGenerator.new()     # 355：少量额外收成，按流水号定（同一档读回来收一样多）
		rng.seed = hash([meta.nursery.seq, i, String(crop), "bonus"])
		for _k in int(spec["count"]):
			if rng.randf() < float(bonus.get("chance", 0.0)):
				defs.append(items.get_def(StringName(bonus["id"])))
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
	meta.nursery.plots[i] = _empty()
	meta.nursery.seq += 1
	out["crop"] = String(crop)
	out["items"] = added.size()
	meta.changed.emit()
	return out


func to_dict() -> Dictionary:
	return {"plots": plots.duplicate(true), "last_run": last_run, "seq": seq}


static func from_dict(d: Variant) -> Nursery:
	var n := Nursery.new()
	if not (d is Dictionary):
		return n
	var src := d as Dictionary
	var raw: Array = src.get("plots", []) if src.get("plots", null) is Array else []
	while n.plots.size() < mini(raw.size(), MAX_PLOTS):
		n.plots.append(_empty())
	for i in mini(raw.size(), MAX_PLOTS):
		if raw[i] is Dictionary:
			var crop := String(raw[i].get("crop", ""))
			if crop != "" and not CROPS.has(StringName(crop)):
				crop = ""     # 认不得的作物（退役了）当空地
			n.plots[i] = {"crop": crop, "sown_run": int(raw[i].get("sown_run", 0)), "left": maxi(0, int(raw[i].get("left", 0))) if crop != "" else 0}
	n.last_run = String(src.get("last_run", ""))
	n.seq = int(src.get("seq", 0))
	return n
