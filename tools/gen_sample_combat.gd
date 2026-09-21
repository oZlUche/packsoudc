## 给示例物品补上战斗数据（占位数值，取自 docs/item-roster.md）。
##
##     "E:/Godot/..._console.exe" --headless --path . --script res://tools/gen_sample_combat.gd
##
## [b]这是过渡方案。[/b] 正式做法是第 10 节的导入器：作者写 JSON，导入器产出 .tres。
## 在导入器落地之前，先用代码给几件道具配上数值，好让沙盒里能看见真的战斗 ——
## 没有这一步，血条和伤害数字都没有东西可显示。
##
## 只动 combat 与 adjacency 两个字段，形状、标签、稀有度沿用 gen_sample_items 的产物。
extends SceneTree

const ITEM_DIR := "res://data/items"

const B := StatMath.Buff


func _initialize() -> void:
	var count := 0
	for id in _combat_ids():
		var path := "%s/%s.tres" % [ITEM_DIR, id]
		var def: ItemDef = load(path)
		if def == null:
			push_warning("跳过不存在的物品：" + path)
			continue
		_configure(def)
		if ResourceSaver.save(def, path) != OK:
			push_error("保存失败: " + path)
			quit(1)
			return
		count += 1

	print("已为 %d 件物品写入战斗数据" % count)
	quit(0)


static func _combat_ids() -> Array:
	return [
		"knife", "pistol", "rifle", "sniper", "crowbar",
		"medkit", "stim", "armor", "ration",
		"mag", "battery", "core", "drone",
	]


#region 构造 helper
static func _profile(stats: Dictionary, rules: Array = []) -> CombatProfile:
	var c := CombatProfile.new()
	c.base_stats = stats
	var typed: Array[AbilityRule] = []
	for r in rules:
		typed.append(r)
	c.rules = typed
	return c


static func _rule(trigger: Trigger, cadence: Cadence, effects: Array, costs: Array = []) -> AbilityRule:
	var r := AbilityRule.new()
	r.trigger = trigger
	r.cadence = cadence
	var te: Array[CombatEffect] = []
	for e in effects:
		te.append(e)
	r.effects = te
	var tc: Array[Cost] = []
	for c in costs:
		tc.append(c)
	r.costs = tc
	return r


static func _cooldown(seconds: float) -> CooldownCadence:
	var c := CooldownCadence.new()
	c.seconds = seconds
	return c


static func _cost(key: StringName, amount: float) -> ResourceCost:
	var c := ResourceCost.new()
	c.resource_key = key
	c.amount = amount
	return c


static func _hit(type: StringName = DamageTypes.PHYSICAL) -> DealDamage:
	var e := DealDamage.new()
	e.damage_type = type
	return e


## 自发出手的武器：按冷却打一下，消耗某种资源
static func _weapon_rule(
	cd: float, cost_key: StringName, cost_amount: float, extra: Array = []
) -> AbilityRule:
	var effects: Array = [_hit()]
	effects.append_array(extra)
	return _rule(OnSchedule.new(), _cooldown(cd), effects, [_cost(cost_key, cost_amount)])


static func _mod(stat: StringName, category: int, percent: int) -> StatModifier:
	var m := StatModifier.new()
	m.stat = stat
	m.mult_category = category
	m.mult_percent = percent
	return m


static func _buff(id: String, display: String, duration: float, max_stacks: int) -> BuffDef:
	var b := BuffDef.new()
	b.id = StringName(id)
	b.display_name = display
	b.duration_sec = duration
	b.max_stacks = max_stacks
	return b
#endregion


static func _configure(def: ItemDef) -> void:
	match String(def.id):
		"knife":
			# 流血：挂在受害者身上，规则在受害者的 runtime 上跑，所以目标是自己。
			# 伤害类型是 bleed —— 持续伤害不招致反伤。
			var bleed := _buff("bleed", "流血", 6.0, 5)
			var tick := _hit(DamageTypes.BLEED)
			tick.target = CombatEffect.Target.SELF
			tick.damage_stat = &""
			tick.amount = 1.0
			tick.per_stack = true
			bleed.rules = [_rule(OnSchedule.new(), _cooldown(1.0), [tick])] as Array[AbilityRule]

			var apply := ApplyStatus.new()
			apply.buff = bleed
			apply.stacks = 1
			def.combat = _profile({"damage": 3.0}, [_weapon_rule(0.6, BattleStats.RES_STAMINA, 3.0, [apply])])

		"pistol":
			def.combat = _profile({"damage": 6.0}, [_weapon_rule(1.2, BattleStats.RES_STAMINA, 6.0)])

		"rifle":
			def.combat = _profile({"damage": 8.0}, [_weapon_rule(0.8, BattleStats.RES_STAMINA, 5.0)])

		"sniper":
			# 标记：降低对手护甲，让后续伤害更疼
			var marked := _buff("marked", "标记", 8.0, 1)
			marked.is_debuff = true
			marked.mods = [_mod(BattleStats.ARMOR, B.EMPOWER, 0)] as Array[StatModifier]
			marked.mods[0].flat = -3.0
			var mark := ApplyStatus.new()
			mark.buff = marked
			def.combat = _profile({"damage": 30.0}, [_weapon_rule(3.0, BattleStats.RES_STAMINA, 18.0, [mark])])
			# 受益：架在下方的支撑物上
			var ap := AdjacencyProfile.new()
			ap.receive_cells = [Vector2i(0, 4)]
			ap.receive_filter = [&"part"] as Array[StringName]
			ap.receive_mods = [_mod(BattleStats.DAMAGE, B.SHARP, 25)]
			def.adjacency = ap

		"crowbar":
			def.combat = _profile({"damage": 14.0}, [_weapon_rule(2.0, BattleStats.RES_STAMINA, 12.0)])

		"medkit":
			# 跌破 40% 时回一口，全场一次 —— 没有 uses(1) 就会变成无限奶
			var heal := ChangeResource.new()
			heal.resource_key = BattleStats.RES_HP
			heal.amount = 35.0
			var low := OnResourceBelow.new()
			low.resource_key = BattleStats.RES_HP
			low.percent = 40
			var once := UsesCost.new()
			once.max_uses = 1
			def.combat = _profile({}, [_rule(low, Always.new(), [heal], [once])])

		"stim":
			var rush := _buff("adrenaline", "肾上腺素", 10.0, 3)
			rush.mods = [_mod(BattleStats.HASTE, B.HASTE, 12)] as Array[StatModifier]
			var dose := ApplyStatus.new()
			dose.target = CombatEffect.Target.SELF
			dose.buff = rush
			dose.stacks = 3
			def.combat = _profile({}, [_rule(OnBattleStart.new(), Always.new(), [dose])])

		"armor":
			def.combat = _profile({"armor": 5.0, "max_hp": 20.0})

		"ration":
			# 口粮既加上限也加回速 —— 「能打多久」和「多久缓过来」是两件事
			def.combat = _profile({"max_stamina": 40.0, "regen_stamina": 2.0})

		"mag":
			# 增益：上下相邻的武器各得一份
			var ap2 := AdjacencyProfile.new()
			ap2.grant_cells = [Vector2i(0, -1), Vector2i(0, 1)]
			ap2.grant_filter = [&"weapon"] as Array[StringName]
			ap2.grant_mods = [_mod(BattleStats.DAMAGE, B.SHARP, 20)]
			def.adjacency = ap2

		"battery":
			def.combat = _profile({"max_power": 20.0})

		"core":
			def.combat = _profile({"max_power": 60.0})

		"drone":
			def.combat = _profile({"damage": 6.0}, [_weapon_rule(2.5, &"power", 10.0)])
