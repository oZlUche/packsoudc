## 395（作者 11-25）：器官的特性 —— 写在器官这件食材上（[member ItemDef.eat_trait]），一处定义两条路共用：
## 下食堂的锅（这顿饭带着它，整局有效，不随饱腹失效）；拿了蛮神【啖肉吮血】在局里直接吃（[BruteRagePerk]）。
## 每件叠一次，好处坏处一起带，不设上限（食堂那条路只套食堂原有的防溢出上限）。
## 合计在这里算，开战时 [method apply] 编进玩家这一方；生命上限、每秒回复走基线（[method stat_bonus]）
class_name OrganTraits
extends RefCounted

## 特性的键（显示顺序）
const KEYS: Array[StringName] = [&"damage", &"haste", &"max_hp", &"regen_hp", &"regen_stamina", &"fire_hit", &"poison_chance", &"heal", &"taken"]
## 1 = 越大越好，-1 = 越小越好（受到的伤害）
const GOOD := {&"damage": 1, &"haste": 1, &"max_hp": 1, &"regen_hp": 1, &"regen_stamina": 1, &"fire_hit": 1, &"poison_chance": 1, &"heal": 1, &"taken": -1}
const POISON := &"poison"


static func is_organ(def: ItemDef) -> bool:
	return def != null and not def.eat_trait.is_empty()


## 一批器官 {道具 id: 件数} 的合计 {键: 数}
static func sum_of(eaten: Dictionary, items: ItemDatabase) -> Dictionary:
	var out := {}
	if items == null:
		return out
	var ids: Array = eaten.keys()
	ids.sort()
	for id in ids:
		var def := items.get_def(StringName(String(id)))
		if not is_organ(def):
			continue
		var n := float(eaten[id])
		for k in def.eat_trait:
			var key := StringName(String(k))
			out[key] = float(out.get(key, 0.0)) + float(def.eat_trait[k]) * n
	return out


## 这一局身上的合计：蛮神直接吃的 + 这一局那顿饭里的
static func totals(run: RunState) -> Dictionary:
	var out := BruteRagePerk.organ_totals(run)
	var meal := MealModule.of(run)
	if meal != null:
		var m := meal.traits()
		for k in m:
			var key := StringName(String(k))
			out[key] = float(out.get(key, 0.0)) + float(m[k])
	return out


## 生命上限、每秒回复（并进 [method RunState.god_stat_bonus]，基线加算）
static func stat_bonus(run: RunState) -> Dictionary:
	var t := totals(run)
	var out := {}
	if float(t.get(&"max_hp", 0.0)) != 0.0:
		out[BattleStats.MAX_HP] = float(t[&"max_hp"])
	if float(t.get(&"regen_hp", 0.0)) != 0.0:
		out[BattleStats.REGEN_HP] = float(t[&"regen_hp"])
	return out


## 开战编进玩家这一方：造成的伤害、急速整单位乘算；耐力回复基线乘算；受到的伤害、受到的治疗进单位；
## 每次攻击（己方武器出手）的火焰伤害、施加中毒的几率挂一条单位规则
static func apply(input: CompileInput, run: RunState) -> void:
	apply_values(input, totals(run))


static func apply_values(input: CompileInput, t: Dictionary) -> void:
	if t.is_empty():
		return
	if float(t.get(&"damage", 0.0)) != 0.0:
		input.mods.append(StatModifier.make(BattleStats.DAMAGE, StatModifier.Mode.MULT, float(t[&"damage"])))
	if float(t.get(&"haste", 0.0)) != 0.0:
		input.mods.append(StatModifier.make(BattleStats.HASTE, StatModifier.Mode.MULT, float(t[&"haste"])))
	if float(t.get(&"regen_stamina", 0.0)) != 0.0:
		input.baseline_mods.append(StatModifier.make(BattleStats.REGEN_STAMINA, StatModifier.Mode.MULT, float(t[&"regen_stamina"])))
	input.taken_pct += float(t.get(&"taken", 0.0))
	input.heal_pct += float(t.get(&"heal", 0.0))
	var fire := float(t.get(&"fire_hit", 0.0))
	if fire > 0.0:
		var dmg := DealDamage.new()
		dmg.damage_type = DamageTypes.FIRE
		dmg.damage_stat = &""
		dmg.amount = fire
		input.rules.append(_on_attack([dmg] as Array[CombatEffect], 100))
	var chance := roundi(float(t.get(&"poison_chance", 0.0)))
	var poison: BuffDef = ContentLibrary.buffs().get(POISON, null)
	if chance > 0 and poison != null:
		var ap := ApplyStatus.new()
		ap.target = CombatEffect.Target.OPPONENT
		ap.buff = poison
		ap.stacks = 1
		input.rules.append(_on_attack([ap] as Array[CombatEffect], mini(100, chance)))


## 己方武器每出手一次（[param percent] < 100 时按几率）
static func _on_attack(effects: Array[CombatEffect], percent: int) -> AbilityRule:
	var trig := OnItemFired.new()
	trig.same_side = true
	trig.source_tags = [&"weapon"] as Array[StringName]
	var r := AbilityRule.new()
	r.trigger = trig
	r.cadence = Always.new()
	if percent < 100:
		var c := ChanceCondition.new()
		c.percent = percent
		r.costs.append(c)
	for e in effects:
		r.effects.append(e)
	return r


## 一组特性写成一条一条，好处在前、坏处在后（[param values] 是 {键: 数}）
static func lines(values: Dictionary) -> Array[String]:
	var good: Array[String] = []
	var bad: Array[String] = []
	for k in KEYS:
		var v := float(values.get(k, values.get(String(k), 0.0)))
		if v == 0.0:
			continue
		var one := UiText.t("trait." + String(k)) % (("+" if v > 0.0 else "") + TextTemplate.num(v))
		if v * float(GOOD[k]) > 0.0:
			good.append(one)
		else:
			bad.append(one)
	return good + bad


## 一行写完（「，」隔开）
static func line(values: Dictionary) -> String:
	return UiText.t("trait.sep").join(lines(values))
