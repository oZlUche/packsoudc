## 151 §4：校表用的「估算 vs 实测」。把武器单独放到一个打不死的木桩战里（对手按三档 DPS 回打），量实际每秒打出多少伤害，
## 和 [PowerEstimate] 估的战斗力并排；另一张表是参考套组（同一流派标签的几件）的整套实测减去去掉某件后的实测 = 那件的组合贡献。
## 比值偏得多的那一类效果 → 改 `power_weights.json` 里对应的系数，不改公式结构。只给工具与测试用，不进游戏
class_name PowerBench
extends RefCounted

## 对手 DPS 三档（× 系数表的 opponent_dps）
const OPPONENT_TIERS: Array[float] = [0.5, 1.0, 2.0]
## 两边都打不死（量的是一段时间里的输出，不是胜负）
const UNDYING_HP := 100000.0


## 这几件一起放在玩家那边（不摆棋盘：邻接、连结不算），对手按 [param opponent_dps] 回打，打 [param seconds] 秒，平均每秒打出多少
static func measure(defs: Array[ItemDef], opponent_dps: float, seconds: float, seeds: int = 3, w: PowerWeights = null) -> float:
	var ww := w if w != null else PowerWeights.load_from()
	var total := 0.0
	for s in seeds:
		var me := _spec(defs)
		var foe := _dummy(opponent_dps, ww.hit_rate)
		var rng := RandomNumberGenerator.new()
		rng.seed = 151 + s
		var result := BattleSim.run(me, foe, rng, seconds)
		var dealt := 0
		for ev in result.log:
			if ev.name == BattleEvent.DAMAGE and ev.side == 1:
				dealt += absi(ev.get_int(&"amount")) + absi(ev.get_int(&"absorbed"))
		total += StatMath.to_float(dealt) / maxf(0.01, result.duration_sec())
	return total / maxi(1, seeds)


## 单件表：每件 {id, cells, rarity, power, ratio, measured: [三档], vs: 实测（中档）÷ 估算}
static func single_table(defs: Array[ItemDef], w: PowerWeights = null, buffs: Dictionary = {}, seeds: int = 3) -> Array[Dictionary]:
	var ww := w if w != null else PowerWeights.load_from()
	var rows: Array[Dictionary] = []
	for def in defs:
		var est := PowerEstimate.estimate(def, ww, buffs)
		var measured: Array[float] = []
		for k in OPPONENT_TIERS:
			measured.append(measure([def] as Array[ItemDef], ww.opponent_dps * k, ww.horizon_sec, seeds, ww))
		rows.append({"id": String(def.id), "cells": est.cells, "rarity": def.rarity, "suggest": est.rarity, "power": est.power,
			"ratio": est.ratio, "measured": measured, "vs": measured[1] / est.power if est.power > 0.0 else 0.0})
	return rows


## 组合表：按流派标签分组（至少两件），每件 {tag, id, alone, contribution = 整套 − 去掉它, synergy = 贡献 − 单独}（中档对手）
static func set_table(defs: Array[ItemDef], tags: Array[StringName], w: PowerWeights = null, seeds: int = 3) -> Array[Dictionary]:
	var ww := w if w != null else PowerWeights.load_from()
	var rows: Array[Dictionary] = []
	for tag in tags:
		var group: Array[ItemDef] = []
		for d in defs:
			if d.tags.has(tag):
				group.append(d)
		if group.size() < 2:
			continue
		var full := measure(group, ww.opponent_dps, ww.horizon_sec, seeds, ww)
		for i in group.size():
			var rest := group.duplicate()
			rest.remove_at(i)
			var alone := measure([group[i]] as Array[ItemDef], ww.opponent_dps, ww.horizon_sec, seeds, ww)
			var contribution := full - measure(rest, ww.opponent_dps, ww.horizon_sec, seeds, ww)
			rows.append({"tag": String(tag), "id": String(group[i].id), "alone": alone, "contribution": contribution, "synergy": contribution - alone})
	return rows


static func single_text(rows: Array[Dictionary]) -> String:
	var lines: Array[String] = ["id\t格\t稀有度\t推荐\t估算\t预算比\t实测(弱/中/强)\t实测÷估算"]
	for r in rows:
		var m: Array = r["measured"]
		lines.append("%s\t%d\t%d\t%d\t%.1f\t%.2f\t%.1f/%.1f/%.1f\t%.2f" % [r["id"], r["cells"], r["rarity"], r["suggest"], r["power"], r["ratio"], m[0], m[1], m[2], r["vs"]])
	return "\n".join(lines)


static func set_text(rows: Array[Dictionary]) -> String:
	var lines: Array[String] = ["流派\tid\t单独\t组合贡献\t联动"]
	for r in rows:
		lines.append("%s\t%s\t%.1f\t%.1f\t%+.1f" % [r["tag"], r["id"], r["alone"], r["contribution"], r["synergy"]])
	return "\n".join(lines)


static func _spec(defs: Array[ItemDef]) -> CombatantSpec:
	var spec := CombatantSpec.new()
	spec.baseline = StatSet.new()
	CombatantBaseline.with_hp(UNDYING_HP).seed_stats(spec.baseline)
	spec.max_hp = StatMath.from_float(UNDYING_HP)
	for i in defs.size():
		var def := defs[i]
		if def == null or def.combat == null:
			continue
		var it := CompiledItem.new()
		it.source_uid = i + 1
		it.def_id = def.id
		it.tags = def.tags
		it.stats = StatSet.new()
		def.combat.seed_stats(it.stats)
		it.rules = def.combat.rules
		spec.add(it)
	return spec


## 打不死、按固定频率回打的木桩
static func _dummy(dps: float, hit_rate: float) -> CombatantSpec:
	var spec := CombatantSpec.new()
	spec.baseline = StatSet.new()
	CombatantBaseline.with_hp(UNDYING_HP).seed_stats(spec.baseline)
	spec.max_hp = StatMath.from_float(UNDYING_HP)
	var it := CompiledItem.new()
	it.source_uid = 1
	it.def_id = &"power_bench_dummy"
	it.stats = StatSet.new()
	var rule := AbilityRule.new()
	rule.trigger = OnSchedule.new()
	var cd := CooldownCadence.new()
	cd.seconds = 1.0 / maxf(0.01, hit_rate)
	rule.cadence = cd
	var hit := DealDamage.new()
	hit.damage_stat = &""
	hit.amount = dps / maxf(0.01, hit_rate)
	rule.effects.append(hit)
	it.rules.append(rule)
	spec.add(it)
	return spec
