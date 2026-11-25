## 395（作者 11-25）：器官的特性 —— 写在器官这件食材上（[member ItemDef.eat_trait]），一处定义两条路共用：
## 下食堂的锅（这顿饭带着它，整局有效，不随饱腹失效）；拿了蛮神【啖肉吮血】在局里直接吃（[BruteRagePerk]）。
## 每件叠一次，好处坏处一起带，不设上限（食堂那条路只套食堂原有的防溢出上限）。
## 合计在这里算，开战时 [method apply] 编进玩家这一方；生命上限、每秒回复走基线（[method stat_bonus]）
class_name OrganTraits
extends RefCounted

## 特性的键（显示顺序）
const KEYS: Array[StringName] = [&"damage", &"haste", &"max_hp", &"regen_hp", &"scorch", &"chill", &"poison", &"taken"]
## 395 第六节（作者 11-25 19:02「三种腺体改成每次攻击对自己和敌人额外附加一层对应元素」）：这几个键是元素印的状态 id，
## 数 = 己方武器每出手一次给敌我各叠几层
const MARKS: Array[StringName] = [&"scorch", &"chill", &"poison"]
## 1 = 越大越好，-1 = 越小越好（受到的伤害）
const GOOD := {&"damage": 1, &"haste": 1, &"max_hp": 1, &"regen_hp": 1, &"scorch": 1, &"chill": 1, &"poison": 1, &"taken": -1}


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


## 开战编进玩家这一方：造成的伤害、急速整单位乘算；受到的伤害进单位；
## 腺体的元素印挂一条单位规则（己方武器每出手一次，敌我各叠几层）
static func apply(input: CompileInput, run: RunState) -> void:
	apply_values(input, totals(run))


static func apply_values(input: CompileInput, t: Dictionary) -> void:
	if t.is_empty():
		return
	if float(t.get(&"damage", 0.0)) != 0.0:
		input.mods.append(StatModifier.make(BattleStats.DAMAGE, StatModifier.Mode.MULT, float(t[&"damage"])))
	if float(t.get(&"haste", 0.0)) != 0.0:
		input.mods.append(StatModifier.make(BattleStats.HASTE, StatModifier.Mode.MULT, float(t[&"haste"])))
	input.taken_pct += float(t.get(&"taken", 0.0))
	for id in MARKS:
		var n := roundi(float(t.get(id, 0.0)))
		var mark: BuffDef = ContentLibrary.buffs().get(id, null)
		if n <= 0 or mark == null:
			continue
		var ap := ApplyStatus.new()
		ap.target = CombatEffect.Target.BOTH     # 敌我各叠
		ap.buff = mark
		ap.stacks = n
		input.rules.append(_on_attack([ap] as Array[CombatEffect]))


## 己方武器每出手一次
static func _on_attack(effects: Array[CombatEffect]) -> AbilityRule:
	var trig := OnItemFired.new()
	trig.same_side = true
	trig.source_tags = [&"weapon"] as Array[StringName]
	var r := AbilityRule.new()
	r.trigger = trig
	r.cadence = Always.new()
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
		var signed := ("+" if v > 0.0 and not MARKS.has(k) else "") + TextTemplate.num(v)     # 元素印写层数，不带号
		var one := UiText.t("trait." + String(k)) % signed
		if v * float(GOOD[k]) > 0.0:
			good.append(one)
		else:
			bad.append(one)
	return good + bad


## 一行写完（「，」隔开）
static func line(values: Dictionary) -> String:
	return UiText.t("trait.sep").join(lines(values))
