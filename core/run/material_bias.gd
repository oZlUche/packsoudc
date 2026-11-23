## 342 B3：地图协会的材料倾向 —— 这一局普通搜索抽到材料时，那一系的材料更容易出。
## 383 第七节（作者 2026-11-23 19:02 选 B）：不再单独选，跟着出生点走 —— 每个出生点带一种偏向（[method spawn_biases]），挑了哪个出生点就是哪一系。
##
## 只在普通搜索里、只在材料类之内重分权重（[method apply]）：目标系乘 [constant MULT]，其他保持 1，
## 再按稀有度逐档缩放回原来的总权重 —— 材料总出现率、每档稀有度的份额、件数都不变。
## 材料节点、敌人、首领保底、宝箱、商店、事件奖励不走这条路。
## 倍率先用 1.5（配对试验 [MaterialBiasTrial] 出数据后由作者定）
class_name MaterialBias
extends RefCounted

const NONE := &""
## 方向 → 认哪些标签（[method SearchSession.in_kind]）
const DIRECTIONS := {
	&"mineral": [&"mineral"],
	&"plant": [&"plant"],
	&"crafted": [&"crafted"],
	&"beast": [&"beast_part"],
	&"magic": [&"crystal", &"magic"],
}
## 选项的先后（无倾向在最前）
const ORDER: Array[StringName] = [NONE, &"mineral", &"plant", &"crafted", &"beast", &"magic"]
const MULT := 1.5
## 不能选的原因（字表键 `bias.why_<原因>`）
const WHY_EMPTY := "empty"
const WHY_ALL := "all"


static func tags_of(dir: StringName) -> Array:
	return DIRECTIONS.get(dir, [])


static func is_target(d: ItemDef, dir: StringName) -> bool:
	return dir != NONE and SearchSession.in_kind(d, tags_of(dir))


## 按方向重分权重（原地改 [param weights]）：材料类里目标系乘 [param mult]，再逐档稀有度缩放回原来的和
static func apply(cands: Array[StringName], weights: Array[float], items: ItemDatabase, tags: Array, mult: float) -> void:
	if tags.is_empty() or is_equal_approx(mult, 1.0) or items == null:
		return
	var before := {}
	var after := {}
	var scaled: Array[float] = weights.duplicate()
	for j in cands.size():
		var d := items.get_def(cands[j])
		if d == null or not SearchSession.is_material(d):
			continue
		before[d.rarity] = float(before.get(d.rarity, 0.0)) + weights[j]
		if SearchSession.in_kind(d, tags):
			scaled[j] = weights[j] * mult
		after[d.rarity] = float(after.get(d.rarity, 0.0)) + scaled[j]
	for j in cands.size():
		var d := items.get_def(cands[j])
		if d == null or not SearchSession.is_material(d):
			continue
		var a := float(after.get(d.rarity, 0.0))
		if a > 0.0:
			weights[j] = scaled[j] * float(before[d.rarity]) / a


## 这一章能不能选 [param dir]：空串 = 能；否则是原因（这一章普通搜索里没有这一系的材料、或材料全是这一系）
static func why_not(dir: StringName, rules: SearchRules, items: ItemDatabase) -> String:
	if dir == NONE:
		return ""
	if rules == null or items == null:
		return WHY_EMPTY
	var hit := 0
	var miss := 0
	for id in SearchSession.candidates(rules, items):
		var d := items.get_def(id)
		if not SearchSession.is_material(d):
			continue
		if is_target(d, dir):
			hit += 1
		else:
			miss += 1
	if hit == 0:
		return WHY_EMPTY
	return WHY_ALL if miss == 0 else ""


## 383：给一张图的出生点各配一种偏向（[param dirs] 是这一章能选的方向，不含无倾向）。按种子定、同一张图上各不相同；
## 出生点比方向多时才会重复。返回 {出生点 id: 方向}；[param dirs] 空 = 空
static func spawn_biases(dirs: Array, entry_ids: Array, p_seed: int) -> Dictionary:
	var out := {}
	if dirs.is_empty() or entry_ids.is_empty():
		return out
	var ids: Array = entry_ids.duplicate()
	ids.sort()
	var pool: Array = dirs.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:spawn_bias" % p_seed)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for k in ids.size():
		out[int(ids[k])] = StringName(String(pool[k % pool.size()]))
	return out
