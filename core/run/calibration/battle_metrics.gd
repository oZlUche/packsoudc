## 平衡检测方案（2026-11-10）§6.2：一场战斗的逐场指标。纯计算，只读 [BattleResult] 的日志与终局快照；扫表、猎手、真人日志都用它。
##
## 量不出来的项写 null（不写 0）：没挨过打就没有「第一次受伤时刻」，没有生命变化事件就没有最低血量；生命上限被压到 0 是倒下，记 0。
## 伤害按真正扣血的那条事件归属（`damage` 事件，被取消的不算），只看事件里写的来源，不顺着触发链往回加；
## 分三类：`true`（真实伤害）、`direct`（直接伤害）、`indirect`（持续伤害、反伤等非直接的）；来源 uid 是 0 的记到 `unknown`。
## 「平局」和「超时」分开：时限到了还都活着是超时，同一刻一起倒下是平局
class_name BattleMetrics
extends RefCounted

const WIN := "win"
const LOSS := "loss"
const DRAW := "draw"
const TIMEOUT := "timeout"
## 低于最大生命的这一成算低血
const LOW_HP := 0.3


## 一场 → 一行指标。我方 = 0 号。[param limit_sec] 是这场的时限（分平局和超时）。
## 给了双方的 [param specs] 时，按道具的伤害用「道具 id」作键（同一种有几件时接 #2、#3），不用每次编译都会变的 uid
static func of(result: BattleResult, limit_sec: float, specs: Array = []) -> Dictionary:
	var dur := result.duration_sec()
	var out := {"outcome": outcome_of(result, limit_sec), "duration": dur}
	out["hp_end"] = [hp_ratio(result, 0), hp_ratio(result, 1)]
	var fires := [{}, {}]
	var first_damage: Array = [null, null]     # 这一方第一次真打出伤害的时刻
	var damage := [{"direct": 0.0, "indirect": 0.0, "true": 0.0, "unknown": 0.0}, {"direct": 0.0, "indirect": 0.0, "true": 0.0, "unknown": 0.0}]
	var by_item := [{}, {}]
	var min_hp: Array = [null, null]
	var first_low: Array = [null, null]
	var low_since: Array = [null, null]
	var low_time := [0.0, 0.0]
	for e in result.log:
		var t := StatMath.to_float(e.time)
		match e.name:
			BattleEvent.ITEM_FIRED:
				if e.side == 0 or e.side == 1:
					var uid := e.get_int(&"uid")
					fires[e.side][uid] = int(fires[e.side].get(uid, 0)) + 1
			BattleEvent.DAMAGE:
				if e.payload.get("cancelled", false):
					continue
				var amount := StatMath.to_float(absi(e.get_int(&"amount")))
				if amount <= 0.0:
					continue
				var src := int(e.payload.get("source_side", -1))
				if src != 0 and src != 1:
					continue
				if first_damage[src] == null:
					first_damage[src] = t
				var uid := e.get_int(&"uid")
				var kind := "unknown" if uid == 0 else ("true" if e.payload.get("pure", false) else ("direct" if e.payload.get("direct", false) else "indirect"))
				damage[src][kind] = float(damage[src][kind]) + amount
				if uid != 0:
					by_item[src][uid] = float(by_item[src].get(uid, 0.0)) + amount
			BattleEvent.RESOURCE_CHANGED:
				if String(e.payload.get("key", "")) != "hp" or (e.side != 0 and e.side != 1):
					continue
				var mx := float(e.payload.get("max", 0))
				var r := float(e.payload.get("current", 0)) / mx if mx > 0.0 else 0.0     # 上限被压到 0（衰竭）：一点血都没有
				min_hp[e.side] = r if min_hp[e.side] == null else minf(float(min_hp[e.side]), r)
				if r < LOW_HP:
					if first_low[e.side] == null:
						first_low[e.side] = t
					if low_since[e.side] == null:
						low_since[e.side] = t
				elif low_since[e.side] != null:
					low_time[e.side] += t - float(low_since[e.side])
					low_since[e.side] = null
	for s in 2:
		if low_since[s] != null:
			low_time[s] += dur - float(low_since[s])
	out["fires"] = [_sum(fires[0]), _sum(fires[1])]
	out["items_fired"] = [fires[0].size(), fires[1].size()]
	out["first_damage"] = first_damage
	out["damage"] = damage
	out["damage_by_item"] = [_keyed(by_item[0], _names(specs, 0)), _keyed(by_item[1], _names(specs, 1))]
	out["min_hp"] = min_hp
	out["first_low_hp"] = first_low
	out["low_hp_time"] = low_time
	return out


## 胜 / 负 / 平 / 超时
static func outcome_of(result: BattleResult, limit_sec: float) -> String:
	if result.winner == 0:
		return WIN
	if result.winner == 1:
		return LOSS
	return TIMEOUT if result.duration_sec() >= limit_sec - 0.001 else DRAW


## 打完时 [param side] 剩的生命比例（0～1）；终局快照里没有返回 null。上限被压到 0（衰竭）算 0：倒下了，不是量不出来
static func hp_ratio(result: BattleResult, side: int) -> Variant:
	var sides: Array = result.final.get("sides", [])
	if side >= sides.size():
		return null
	var res: Dictionary = (sides[side] as Dictionary).get("resources", {})
	var hp: Array = res.get(BattleStats.RES_HP, res.get("hp", []))
	if hp.size() < 2:
		return null
	return float(hp[0]) / float(hp[1]) if float(hp[1]) > 0.0 else 0.0


static func _sum(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n


## uid 键转成字符串（JSON 的键只能是字符串，统一了好比对）；[param names] 里有的换成道具 id
static func _keyed(d: Dictionary, names: Dictionary = {}) -> Dictionary:
	var out := {}
	for k in d:
		out[String(names.get(k, str(k)))] = d[k]
	return out


## uid → 道具 id（同一种第二件起接 #序号）
static func _names(specs: Array, side: int) -> Dictionary:
	var out := {}
	if side >= specs.size() or not (specs[side] is CombatantSpec):
		return out
	var seen := {}
	for it in (specs[side] as CombatantSpec).items:
		var id := String(it.def_id)
		seen[id] = int(seen.get(id, 0)) + 1
		out[it.source_uid] = id if int(seen[id]) == 1 else "%s#%d" % [id, seen[id]]
	return out
