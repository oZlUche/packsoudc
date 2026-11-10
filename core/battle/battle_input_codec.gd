## 平衡检测方案（2026-11-10）§5.1：[CombatantSpec] 和普通值之间来回换，给战斗诊断包（[BattleDiagPack]）用。
##
## 只编结算内核读的东西：生命、属性（基础 / 加算 / 乘算三份）、规则、标签、连结、装载、轴层数、免疫、只吃哪种伤害、坚持秒数、套装规则。
## 回放用的棋盘与常驻格说明（[member CombatantSpec.board]、[member CombatantSpec.passives]）不编：结算内核不读。
## 规则是资源（[AbilityRule] 及其触发、频率、效果子资源）：编的时候按实例去重、深拷贝内置的子资源，放进 [param rules] 那张表，
## 物品只记下标；外部资源文件（buff 定义等）照旧按路径引用 —— 换了构建、那份文件改了，复现就该对不上，这是想要的
class_name BattleInputCodec
extends RefCounted

const FORMAT := 1


## 编一方。[param rules] 是两方共用的规则表（会往里加）；[param index] 是规则实例 → 下标（去重用，会往里加）
static func encode(spec: CombatantSpec, rules: Array[AbilityRule], index: Dictionary) -> Dictionary:
	var items: Array = []
	for it in spec.items:
		items.append({
			"uid": it.source_uid, "def_id": it.def_id, "tags": it.tags.duplicate(), "stats": stats_to(it.stats),
			"rules": _rule_ids(it.rules, rules, index), "linked": it.linked_uids.duplicate(), "attached": it.attached.duplicate(true),
			"loaded": it.loaded.duplicate(true), "power_mult": it.power_mult,
		})
	return {
		"format": FORMAT, "max_hp": spec.max_hp, "undying_sec": spec.undying_sec, "immune_buffs": spec.immune_buffs.duplicate(),
		"only_damage_type": spec.only_damage_type, "axes": spec.axes.duplicate(true),
		"baseline": (stats_to(spec.baseline) as Variant) if spec.baseline != null else null,
		"items": items, "set_rules": _rule_ids(spec.set_rules, rules, index),
		"fed_uids": spec.fed_uids.duplicate(), "loads": spec.loads.duplicate(true),
	}


## 解一方。[param rules] 是编的时候那张规则表
static func decode(d: Dictionary, rules: Array[AbilityRule]) -> CombatantSpec:
	var spec := CombatantSpec.new()
	spec.max_hp = int(d.get("max_hp", 0))
	spec.undying_sec = float(d.get("undying_sec", 0.0))
	for b in d.get("immune_buffs", []):
		spec.immune_buffs.append(StringName(b))
	spec.only_damage_type = StringName(d.get("only_damage_type", &""))
	spec.axes = (d.get("axes", {}) as Dictionary).duplicate(true)
	var base: Variant = d.get("baseline", null)
	spec.baseline = stats_from(base) if base is Dictionary else null
	for e in d.get("items", []):
		var row := e as Dictionary
		var it := CompiledItem.new()
		it.source_uid = int(row.get("uid", 0))
		it.def_id = StringName(row.get("def_id", &""))
		for t in row.get("tags", []):
			it.tags.append(StringName(t))
		it.stats = stats_from(row.get("stats", {}))
		it.rules = _rules_at(row.get("rules", []), rules)
		for u in row.get("linked", []):
			it.linked_uids.append(int(u))
		for a in row.get("attached", []):
			it.attached.append((a as Dictionary).duplicate(true))
		for l in row.get("loaded", []):
			it.loaded.append((l as Dictionary).duplicate(true))
		it.power_mult = int(row.get("power_mult", StatMath.ONE))
		spec.add(it)
	spec.set_rules = _rules_at(d.get("set_rules", []), rules)
	for u in d.get("fed_uids", []):
		spec.fed_uids.append(int(u))
	spec.loads = (d.get("loads", {}) as Dictionary).duplicate(true)
	return spec


## 属性 → {键: [基础, 加算, 乘算]}（都是定点整数）
static func stats_to(s: StatSet) -> Dictionary:
	var out := {}
	if s == null:
		return out
	for key in s.keys():
		var v := s.ensure(key)
		out[key] = [v.base, v.flat, v.percent]
	return out


static func stats_from(d: Dictionary) -> StatSet:
	var s := StatSet.new()
	for key in d:
		var a: Array = d[key]
		var v := s.ensure(StringName(key))
		v.base = int(a[0])
		v.flat = int(a[1])
		v.percent = int(a[2])
	return s


## 一串规则 → 下标；第一次见的规则深拷贝进表（内置子资源一起拷，外部文件照旧引用）
static func _rule_ids(list: Array[AbilityRule], rules: Array[AbilityRule], index: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for r in list:
		var key := r.get_instance_id()
		if not index.has(key):
			index[key] = rules.size()
			rules.append(r.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as AbilityRule)
		out.append(int(index[key]))
	return out


static func _rules_at(ids: Array, rules: Array[AbilityRule]) -> Array[AbilityRule]:
	var out: Array[AbilityRule] = []
	for i in ids:
		var k := int(i)
		if k >= 0 and k < rules.size() and rules[k] != null:
			out.append(rules[k])
	return out
