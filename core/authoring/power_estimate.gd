## 151（作者定，五项待定按推荐）：编辑器里的「当前战斗力」—— 一件道具单看值多少，给推荐稀有度与推荐价值。
##
## [codeblock]
## P = (B + Σ_规则 Σ_效果 V × T × C × K × L) × W
## B  直接伤害 DPS：自发规则（按冷却出手）里打对手的那一下 × 频率（含暴击期望）× 耐力可持续系数
##    （155 补，作者定：min(1, (耐力上限 + 回复 × 一场时长) ÷ (自发规则每秒耗的耐力 × 一场时长))，[method PowerWeights.stamina_sustain]）
## V  效果触发一次值多少，带符号（[method CombatEffect.estimated_value]）：打对手、给自己增益为正，伤自己、给对手增益为负
## T  一秒触发几次（[method AbilityRule.estimated_rate]）
## C  消耗能付几成、K 条件满足几成（[method Cost.estimated_factor]）、L 重复触发的折扣（[method CombatEffect.estimated_cap]）
##    —— 全在零到一之间，只缩不翻号：负面效果永远是减项，条件再苛刻也只是减得少
## W  负重折扣 max(下限, 1 − 重量 ÷ 负重基准)
## [endcodeblock]
##
## 推荐稀有度看预算比 r = P ÷ (每格基准 × (格数 + 把手格)) 落在哪一档（155：加一格把手）；推荐价值 = 那一档的每格价 × 格数 × 档内位置。
## 推荐给武器和护具（带 armor / shield 标签，作者定：非武器的护甲、减伤也算价值）—— 护具自带的护甲上限、格挡按 D 进 P：
## P = (B + D + Σ …) × W，D = 护甲上限 × 每点折算 + 格挡 × 每点折算（[member PowerWeights.armor_per_point]）。别的非武器只看分数
## 只是提示与推荐：流派件单看偏弱是故意的，联动价值不进这个数。系数全在 [PowerWeights]（作者改表不改码）。
## 纯函数：只看 [ItemDef]，不碰运行时
class_name PowerEstimate
extends RefCounted

## 一次估算的全部明细（编辑器逐行列、测试逐项查）
class Breakdown:
	extends RefCounted
	## 直接伤害 DPS（基础 B）与出手频率
	var base: float = 0.0
	## 155：耐力可持续系数（B 已经乘过）：自发规则每秒耗的耐力超过回复时打折
	var sustain: float = 1.0
	## 自带的护甲 / 减伤（D）：基础属性里的护甲上限与格挡折成的每秒伤害
	var defense: float = 0.0
	## 护具（armor / shield 标签）：和武器一样给推荐
	var is_gear: bool = false
	var hz: float = 0.0
	## 每条规则一行：{index, text, rate (T), cost (C), cond (K), cap (L，效果的加权平均), effects: [{type, text, value (V), cap, unestimated}], value（这一行的贡献）}
	var rules: Array[Dictionary] = []
	## 估不出来的效果类型（记零）
	var unestimated: Array[String] = []
	var sum: float = 0.0
	var weight: int = 0
	var weight_factor: float = 1.0
	var power: float = 0.0
	var cells: int = 0
	## 默认战斗力 = 每格基准 × (格数 + 把手格)；把手格只算武器
	var default_power: float = 0.0
	## 预算比
	var ratio: float = 0.0
	var is_weapon: bool = false
	## 推荐稀有度（不是武器也不是护具 −1：只看分数）与推荐价值（同上 0）
	var rarity: int = -1
	var value: int = 0


## 估一件。[param weights] 不给就读系数表；[param buffs] 是 id → [BuffDef]（清除 / 转化按 id 查；给不了就按查不到算）
static func estimate(def: ItemDef, weights: PowerWeights = null, buffs: Dictionary = {}) -> Breakdown:
	var w := weights if weights != null else PowerWeights.load_from()
	var out := Breakdown.new()
	if def == null:
		return out
	out.cells = maxi(1, def.cell_count())
	out.is_weapon = def.tags.has(&"weapon")
	out.is_gear = not out.is_weapon and (def.tags.has(&"armor") or def.tags.has(&"shield"))
	out.default_power = w.default_power(out.cells, out.is_weapon)     # 155：把手格只算武器
	var stats := StatSet.new()
	var rules: Array[AbilityRule] = []
	if def.combat != null:
		def.combat.seed_stats(stats)
		rules = def.combat.rules
	# 基础：自发规则里打对手的直接伤害，乘耐力可持续系数（155）
	var stamina_need := 0.0
	for r in rules:
		if not _is_base_rule(r):
			continue
		var hz := r.cadence.estimated_hz(stats)
		for k in r.effective_costs():
			if k is ResourceCost:
				stamina_need += (k as ResourceCost).stamina_per_use(stats) * hz
		var hits := false
		for e in r.effects:
			if _is_base_effect(e):
				out.base += hz * (e as DealDamage).estimated_damage(stats)
				hits = true
		if hits:
			out.hz += hz
	out.sustain = w.stamina_sustain(stamina_need)
	out.base *= out.sustain
	out.defense = defense_of(stats, w)
	var ctx := PowerContext.new()
	ctx.weights = w
	ctx.stats = stats
	ctx.own_dps = out.base
	ctx.own_hz = out.hz
	ctx.buffs = buffs
	# 本件自己施加 buff 的频率（门槛扳机按它算）：只数自发规则
	for r in rules:
		if not _is_base_rule(r):
			continue
		var hz := r.cadence.estimated_hz(stats)
		for e in r.effects:
			if e is ApplyStatus and (e as ApplyStatus).buff != null:
				var a := e as ApplyStatus
				var key := ("self:" if a.target == CombatEffect.Target.SELF else "opp:") + String(a.buff.id)
				ctx.applied_rate[key] = float(ctx.applied_rate.get(key, 0.0)) + hz * a.stacks
	for i in rules.size():
		var line := _rule_line(rules[i], i, ctx, out)
		if not line.is_empty():
			out.rules.append(line)
			out.sum += float(line["value"])
	out.weight = ItemWeight.of(def)
	out.weight_factor = maxf(w.weight_floor, 1.0 - out.weight / maxf(1.0, w.weight_base))
	out.power = (out.base + out.defense + out.sum) * out.weight_factor
	out.ratio = out.power / out.default_power if out.default_power > 0.0 else 0.0
	if out.is_weapon or out.is_gear:
		out.rarity = rarity_for(out.ratio, w)
		out.value = value_for(out.rarity, out.ratio, out.cells, w)
	return out


## 道具自带的护甲 / 减伤（D）：基础属性里的护甲上限、格挡 × 每点折算
static func defense_of(stats: StatSet, w: PowerWeights) -> float:
	var shield := StatMath.to_float(stats.total_of(BattleStats.MAX_ARMOR)) if stats.has(BattleStats.MAX_ARMOR) else 0.0
	var armor := StatMath.to_float(stats.total_of(BattleStats.BLOCK)) if stats.has(BattleStats.BLOCK) else 0.0
	return shield * w.armor_per_point + armor * w.block_per_point


static func _is_base_rule(r: AbilityRule) -> bool:
	return r != null and r.trigger != null and r.cadence != null and r.trigger.is_self_driven()


static func _is_base_effect(e: CombatEffect) -> bool:
	return e is DealDamage and (e as DealDamage).target == CombatEffect.Target.OPPONENT


## 一条规则的那一行（只有基础那一下的规则返回空：它已经在 B 里了）
static func _rule_line(r: AbilityRule, index: int, ctx: PowerContext, out: Breakdown) -> Dictionary:
	if r == null or r.trigger == null:
		return {}
	var base_rule := _is_base_rule(r)
	var c := ctx.with_stacks(r.trigger.estimated_stacks())
	c.incoming = not (r.trigger is DamageTrigger and (r.trigger as DamageTrigger).direction == DamageTrigger.Direction.DEALT) \
		and not (r.trigger is OnItemFired)
	var rate := r.estimated_rate(c)
	var effects: Array[Dictionary] = []
	var raw := 0.0
	var capped := 0.0
	for e in r.effects:
		if base_rule and _is_base_effect(e):
			continue
		var type := RegistryLookup.class_of(e) if e != null else "?"
		var v := (e as CombatEffect).estimated_value(c) if e != null else NAN
		var unknown := is_nan(v)
		if unknown:
			v = 0.0
			if not out.unestimated.has(type):
				out.unestimated.append(type)
		var cap := clampf((e as CombatEffect).estimated_cap(c, rate), 0.0, 1.0) if e != null else 1.0
		effects.append({"type": type, "text": (e as CombatEffect).describe() if e != null else "", "value": v, "cap": cap, "unestimated": unknown})
		raw += v
		capped += v * cap
	if effects.is_empty():
		return {}
	var cost := r.estimated_factor(c, rate, false)
	var cond := r.estimated_factor(c, rate, true)
	return {
		"index": index, "text": Glossary.rule_text(r) if r.is_valid() else "", "rate": rate, "cost": cost, "cond": cond,
		"cap": capped / raw if absf(raw) > 0.0001 else 1.0, "effects": effects, "value": capped * rate * cost * cond,
	}


## 预算比落在哪一档：低于第 i 个阈值 = 第 i 档，其余传说（神话不推荐）
static func rarity_for(ratio: float, w: PowerWeights) -> int:
	for i in w.tiers.size():
		if ratio < w.tiers[i]:
			return i
	return w.tiers.size()


## 推荐价值 = 那一档的每格价 × 格数 × (band[0] + band[1] × 档内位置)，四舍五入到 5 的倍数（至少 5）
static func value_for(tier: int, ratio: float, cells: int, w: PowerWeights) -> int:
	var t := clampi(tier, 0, ItemValue.BASE_PER_CELL.size() - 1)
	var lo := 0.0 if t == 0 else w.tiers[t - 1]
	var hi := w.tiers[t] if t < w.tiers.size() else lo * 1.5
	var pos := clampf((ratio - lo) / (hi - lo), 0.0, 1.0) if hi > lo else 0.5
	var raw := ItemValue.BASE_PER_CELL[t] * cells * (w.value_band[0] + w.value_band[1] * pos)
	return maxi(5, roundi(raw / 5.0) * 5)


## 新建武器画完形状时预填的那一套（待定 3）：默认冷却、伤害按默认战斗力反算、耐力按格数
static func default_weapon(cells: int, w: PowerWeights = null) -> Dictionary:
	var ww := w if w != null else PowerWeights.load_from()
	var p0 := ww.default_power(cells)
	return {
		"damage": maxi(1, roundi(p0 * ww.default_cooldown)),
		"cooldown": ww.default_cooldown,
		"stamina": roundf(ww.stamina_per_cell * maxi(1, cells)),
	}
