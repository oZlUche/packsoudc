## 312（赐福异体参与合成，方案 docs/plans/2026-11-12-blessed-fusion-review-actions.md §1、§2、§8）：两件实际的道具合成什么 —— 唯一的解析入口。
## 配方仍按两件**原件** id 匹配（赐福版用 [member ItemDef.blessed_of] 找回原件），不复制配方；成品取同一位神既有的赐福版
## （[method Blessings.variant_of]），不叠加输入的信仰加成、不现造模板。预览、合成、小锤都走这里。纯函数：道具库、神表、当前信仰显式传进来
class_name FusionResolve
extends RefCounted

const READY := "ready"
## 禁忌待办：两把武器分属两位神（§1、§8.1）—— 不出合成按钮、不扣物、不记知识
const UNAVAILABLE := "unavailable"
## 数据不对：成品不在库里、赐福版查不到来源神
const INVALID := "invalid"

const NORMAL := "normal"
const SINGLE := "single_faith"
const CONFLICT := "conflicting_faith"
const FORBIDDEN := "forbidden_pending"

## 选定那位神没有这件成品的赐福版：出普通成品
const BLESSING_LOST := "blessing_lost"
## 非武器异神：保留一位，另一位那份不叠加
const FAITH_DROPPED := "faith_dropped"


## 这件的原件 id（不是赐福版就是自己）
static func base_of(def: ItemDef) -> StringName:
	if def == null:
		return &""
	return def.blessed_of if def.is_blessed() else def.id


## 这件的原件家族（原件 + 每位神的赐福版 id，不查库里有没有）：认识按家族算（方案 §4）
static func family(db: ItemDatabase, id: StringName, faith_ids: Array) -> Array[StringName]:
	var root := id
	var d := db.get_def(id) if db != null else null
	if d != null and d.is_blessed():
		root = d.blessed_of
	var out: Array[StringName] = [root]
	for f in faith_ids:
		var v := Blessings.variant_id(root, StringName(String(f)))
		if v != id and not out.has(v):
			out.append(v)
	if not out.has(id):
		out.append(id)
	return out


## 赐福版的来源神：按神表找「原件 + 神 = 这件」的那位；不是赐福版 = 空；查不到 = `?`
static func faith_of(def: ItemDef, faith_ids: Array) -> StringName:
	if def == null or not def.is_blessed():
		return &""
	for f in faith_ids:
		if Blessings.variant_id(def.blessed_of, StringName(String(f))) == def.id:
			return StringName(String(f))
	return &"?"


## 解析。没有配方 = 空字典；否则
## `{"recipe_id", "base_output_id", "status": READY / UNAVAILABLE / INVALID, "output_id"（只有 READY 有）, "kind",
##  "selected_faith", "source_faiths": 排好去重, "dropped_faith", "warnings": [BLESSING_LOST / FAITH_DROPPED], "reason"}`
static func resolve(recipes: Array, a: ItemDef, b: ItemDef, db: ItemDatabase, faith_ids: Array, active_faith: StringName = &"") -> Dictionary:
	if a == null or b == null:
		return {}
	var r := RecipeDef.find(recipes, base_of(a), base_of(b))
	if r == null:
		return {}
	var out := {"recipe_id": r.id, "base_output_id": r.output, "status": READY, "output_id": &"", "kind": NORMAL,
		"selected_faith": &"", "source_faiths": [] as Array[StringName], "dropped_faith": &"", "warnings": [] as Array[String], "reason": ""}
	if db == null or db.get_def(r.output) == null:
		out["status"] = INVALID
		out["reason"] = "output_missing"
		return out
	var fa := faith_of(a, faith_ids)
	var fb := faith_of(b, faith_ids)
	if fa == &"?" or fb == &"?":
		out["status"] = INVALID
		out["reason"] = "faith_unknown"
		return out
	var sources: Array[StringName] = []
	for f in [fa, fb]:
		if f != &"" and not sources.has(f):
			sources.append(f)
	Ids.sort(sources)
	out["source_faiths"] = sources
	if sources.is_empty():
		out["output_id"] = r.output
		return out
	var pick: StringName = sources[0]
	if sources.size() == 1:
		out["kind"] = SINGLE
	else:
		if a.tags.has(&"weapon") and b.tags.has(&"weapon"):
			out["status"] = UNAVAILABLE
			out["kind"] = FORBIDDEN
			out["reason"] = "forbidden_pending"
			return out
		out["kind"] = CONFLICT
		pick = _pick(a, fa, b, fb, active_faith)
		out["dropped_faith"] = fb if pick == fa else fa
		(out["warnings"] as Array).append(FAITH_DROPPED)
	out["selected_faith"] = pick
	var v := Blessings.variant_of(db, r.output, pick)
	if v != null:
		out["output_id"] = v.id
	else:
		out["output_id"] = r.output
		(out["warnings"] as Array).append(BLESSING_LOST)
	return out


## 非武器异神择神（§1）：当前信仰在两位之中优先；否则定价高的那件；再相等按神 id 文本。不看报价、位置、uid、拖动方向
static func _pick(a: ItemDef, fa: StringName, b: ItemDef, fb: StringName, active_faith: StringName) -> StringName:
	if active_faith != &"" and (active_faith == fa or active_faith == fb):
		return active_faith
	var va := ItemValue.of(a)
	var vb := ItemValue.of(b)
	if va != vb:
		return fa if va > vb else fb
	return fa if String(fa) < String(fb) else fb
