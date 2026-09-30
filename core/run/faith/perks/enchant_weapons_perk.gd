## 日神 1 / 3 级（093）：开战时 [member count] 把武器（0 = 全部）火焰附魔 —— 每出手附带火焰伤害 max(固定值, 武器伤害 × 百分比)；
## 祈祷（AltarPrayFirePerk）攒的次数按 [member pray_percent] × n^[member pray_curve] 抬火焰伤害（非线性）。
## [member stamina_cost_percent] 非 0 时顺带改武器的耐力消耗（3 级：-20）
class_name EnchantWeaponsPerk
extends FaithPerk

@export var count: int = 3
@export var fixed: float = 3.0
@export var percent: int = 30
@export var pray_percent: float = 10.0
@export var pray_curve: float = 0.7
@export var stamina_cost_percent: int = 0


func fire_bonus(run: RunState) -> int:
	var n := int(run.faith_rituals.get("pray_fire", 0)) if run != null else 0
	return roundi(pray_percent * pow(float(n), pray_curve)) if n > 0 else 0


func modify_spec(spec: CombatantSpec, board: GridInventory, run: RunState) -> void:
	var weapons: Array[CompiledItem] = []
	for it in spec.items:
		var item := it as CompiledItem
		var inst := board.get_item(item.source_uid) if board != null else null
		if inst != null and inst.def != null and inst.def.tags.has(&"weapon") and item.is_active():
			weapons.append(item)
	if weapons.is_empty():
		return
	var picked := weapons
	if count > 0 and weapons.size() > count:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:enchant:%d" % [run.run_seed if run != null else 0, run.travel.clock.total if run != null and run.travel != null else 0])
		picked = []
		var pool := weapons.duplicate()
		for i in count:
			var k := rng.randi_range(0, pool.size() - 1)
			picked.append(pool[k])
			pool.remove_at(k)
	var bonus := fire_bonus(run)
	for item in picked:
		var rule := AbilityRule.new()
		var trig := EffectRegistry.instantiate(&"trigger", &"on_item_fired")
		if trig != null:
			trig.set("include_self", true)
			trig.set("source_uids", [item.source_uid] as Array[int])
		rule.trigger = trig
		rule.cadence = EffectRegistry.instantiate(&"cadence", &"always")
		var eff := FireEnchant.new()
		eff.fixed = fixed
		eff.percent = percent
		eff.bonus_percent = bonus
		rule.effects.append(eff)
		item.rules.append(rule)
		if stamina_cost_percent != 0:
			var m := StatModifier.new()
			m.stat = BattleStats.STAMINA_COST
			m.mult_category = StatMath.Buff.EMPOWER
			m.mult_percent = stamina_cost_percent
			m.apply_to(item.stats, 1)


func describe() -> String:
	if note != "":
		return note
	return "开战时%s火焰附魔（每击 max(%.0f, %d%% 武器伤害) 火焰）%s" % ["全部武器" if count <= 0 else "随机 %d 把武器" % count, fixed, percent, ("，武器耐力消耗 %d%%" % stamina_cost_percent) if stamina_cost_percent != 0 else ""]
