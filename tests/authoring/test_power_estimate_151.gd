## 151（作者定，五项待定按推荐）：战斗力估算 P = (B + Σ V × T × C × K × L) × W —— 单调性、符号规矩、系数表、推荐稀有度与价值、
## 现有武器的推荐和实际差不超过一档（差两档的在 [constant KNOWN_OFF] 里列着，等作者决定改数还是改表）、导入提醒、编辑器面板与新建武器
extends RefCounted

## 现有武器里推荐稀有度和实际差两档以上的。155 改了估算器（直伤乘耐力可持续系数、武器预算加一格把手、
## 可叠层 DoT 按一场的一半算）、删了冲锋枪与狙击枪、涂毒匕首提到史诗之后，原来的五件都回到一档以内；
## 155 补（作者定）把耐力折扣改成「耐力上限 + 一场的回复」之后，现有武器没有一件耗得完，剩下两件只是单看偏弱（估低两档）。
## 作者定了改数还是接受之后从这里删掉
const KNOWN_OFF := ["festering_blade", "longbow", "mithril_sword"]     # 175：溃烂之刃的桥收进菌血，只剩出手盖血印，估出来低两档
const ITEMS := "res://data/items"
const TMP := "user://test_power_weights_151.json"


## 一件测试用的武器：damage 点、冷却 cd 秒、占 cells 格（一条横排）
static func _weapon(damage: float, cd: float, cells: int = 4) -> ItemDef:
	var def := ItemDef.new()
	def.id = &"test_151"
	def.tags = [&"weapon"] as Array[StringName]
	def.shape = ItemShape.from_bits("1".repeat(cells))
	def.combat = CombatProfile.new()
	def.combat.base_stats = {"damage": damage}
	def.combat.rules.append(_rule(OnSchedule.new(), cd, [DealDamage.new()]))
	return def


static func _rule(trigger: Trigger, cd: float, effects: Array, costs: Array = []) -> AbilityRule:
	var r := AbilityRule.new()
	r.trigger = trigger
	var c := CooldownCadence.new()
	c.seconds = cd
	r.cadence = c
	for e in effects:
		r.effects.append(e)
	for k in costs:
		r.costs.append(k)
	return r


static func _hurt_self(amount: float) -> ChangeResource:
	var e := ChangeResource.new()
	e.target = CombatEffect.Target.SELF
	e.resource_key = BattleStats.RES_HP
	e.amount = -amount
	return e


static func _fire(amount: float) -> DealDamage:
	var e := DealDamage.new()
	e.damage_stat = &""
	e.amount = amount
	return e


## 没登记估值的效果（估算器记零、标未估）
class NoValue:
	extends CombatEffect
	func apply(_ctx: RuleContext) -> void:
		pass


static func run_formula(t: TestCase) -> void:
	t.begin("151 · 公式：伤害加 → 加；伤自己 → 减；五成几率 → 该项减半且符号不变；加重量 → 减；没登记的效果记零并标未估")
	var w := PowerWeights.new()
	var base := PowerEstimate.estimate(_weapon(10.0, 2.0), w)
	t.check(absf(base.base - 10.0 / 2.0 * 1.05) < 0.01, "基础 = 伤害 ÷ 冷却 × 暴击期望（%.2f）" % base.base)
	t.check(base.rules.is_empty(), "只有那一下：没有别的规则行")
	t.check(PowerEstimate.estimate(_weapon(14.0, 2.0), w).power > base.power, "伤害加 → 战斗力加")
	t.check(PowerEstimate.estimate(_weapon(10.0, 1.5), w).power > base.power, "冷却短 → 战斗力加")

	var hurt := _weapon(10.0, 2.0)
	hurt.combat.rules.append(_rule(OnSchedule.new(), 1.0, [_hurt_self(2.0)]))
	var h := PowerEstimate.estimate(hurt, w)
	t.check(h.power < base.power, "加一条伤自己的规则 → 战斗力减（%.2f < %.2f）" % [h.power, base.power])
	t.check(float(h.rules[0]["value"]) < 0.0, "那一行是负的")

	# 探的那条用受击扳机（每秒挨一下 → T = 1）：按冷却打对手的那一下会并进基础 B，不单列一行
	var chance := ChanceCondition.new()
	chance.percent = 50
	for pair in [[_fire(4.0), "打对手"], [_hurt_self(2.0), "伤自己"]]:
		var plain := _weapon(10.0, 2.0)
		plain.combat.rules.append(_rule(OnDamage.new(), 1.0, [pair[0]]))
		var half := _weapon(10.0, 2.0)
		half.combat.rules.append(_rule(OnDamage.new(), 1.0, [pair[0]], [chance]))
		var a := float(PowerEstimate.estimate(plain, w).rules[0]["value"])
		var b := float(PowerEstimate.estimate(half, w).rules[0]["value"])
		t.check(absf(b - a / 2.0) < 0.001 and signf(a) == signf(b), "%s：五成几率 → 减半（%.2f → %.2f），符号不变" % [pair[1], a, b])
		t.eq(float(PowerEstimate.estimate(half, w).rules[0]["cond"]), 0.5, "%s：K = 0.5" % pair[1])

	var heavy := _weapon(10.0, 2.0)
	heavy.weight = 24
	var hv := PowerEstimate.estimate(heavy, w)
	t.check(hv.power < base.power and absf(hv.weight_factor - 0.5) > 0.0, "加重量 → 战斗力减（× %.2f）" % hv.weight_factor)
	heavy.weight = 480
	t.eq(PowerEstimate.estimate(heavy, w).weight_factor, w.weight_floor, "再重也不低于下限")

	var odd := _weapon(10.0, 2.0)
	odd.combat.rules.append(_rule(OnSchedule.new(), 1.0, [NoValue.new()]))
	var o := PowerEstimate.estimate(odd, w)
	t.check(not o.unestimated.is_empty(), "没登记的效果：标未估（%s）" % [o.unestimated])
	t.check(absf(o.power - base.power) < 0.001, "并记零")

	# 带冷却的耐力消耗：回复跟不上就只算能持续的那几成
	var thirsty := _weapon(10.0, 2.0)
	var cost := ResourceCost.new()
	cost.amount = 40.0
	thirsty.combat.rules.append(_rule(OnDamage.new(), 1.0, [_fire(5.0)], [cost]))
	var th := PowerEstimate.estimate(thirsty, w)
	t.check(absf(float(th.rules[0]["cost"]) - w.stamina_sustain(40.0)) < 0.001, "耐力：(上限 + 回复 × 一场) ÷ (每次 × 频率 × 一场)（155 补；%.2f）" % th.rules[0]["cost"])
	t.check(float(th.rules[0]["cost"]) < 1.0, "一秒耗 40 还是撑不住")

	# 流血：一层每秒伤挂着的那一边一点 —— 给对手为正、给自己为负
	var bleed: BuffDef = ContentLibrary.buffs().get(&"bleed", null)
	if bleed != null:
		var give := ApplyStatus.new()
		give.buff = bleed
		var to_foe := _weapon(10.0, 2.0)
		to_foe.combat.rules[0].effects.append(give)
		var line := PowerEstimate.estimate(to_foe, w).rules
		t.check(not line.is_empty() and float(line[0]["value"]) > 0.0, "给对手上流血：正")
		var self_give := ApplyStatus.new()
		self_give.buff = bleed
		self_give.target = CombatEffect.Target.SELF
		var to_me := _weapon(10.0, 2.0)
		to_me.combat.rules[0].effects.append(self_give)
		t.check(float(PowerEstimate.estimate(to_me, w).rules[0]["value"]) < 0.0, "给自己上流血：负")


static func run_recommend(t: TestCase) -> void:
	t.begin("151 · 推荐：预算比定档、价值按档内位置取整到 5；默认那一套出生就约等于默认战斗力；非武器（护具除外）只给分数")
	var w := PowerWeights.new()
	t.eq(PowerEstimate.rarity_for(0.5, w), 0, "低于第一档阈值：普通")
	t.eq(PowerEstimate.rarity_for(w.tiers[1], w), 2, "正好在阈值上算上一档")
	t.eq(PowerEstimate.rarity_for(99.0, w), 4, "其余传说（神话不推荐）")
	for tier in 5:
		var v := PowerEstimate.value_for(tier, w.tiers[mini(tier, 3)] - 0.01, 4, w)
		var unit := ItemValue.BASE_PER_CELL[tier] * 4
		t.check(v % 5 == 0 and v >= 5, "第 %d 档价值取整到 5（%d）" % [tier, v])
		t.check(v >= roundi(unit * w.value_band[0]) - 5 and v <= roundi(unit * (w.value_band[0] + w.value_band[1])) + 5, "第 %d 档价值在区间里（%d，每格价 × 格数 = %d）" % [tier, v, unit])
	for cells in [1, 3, 6]:
		var d := PowerEstimate.default_weapon(cells, w)
		var def := _weapon(float(d["damage"]), float(d["cooldown"]), cells)
		var e := PowerEstimate.estimate(def, w)
		t.check(absf(e.power / e.default_power - 1.0) < 0.15, "%d 格：默认那一套的战斗力 %.1f ≈ 默认 %.1f" % [cells, e.power, e.default_power])
	var armor := _weapon(10.0, 2.0)
	armor.tags = [&"tool"] as Array[StringName]
	var a := PowerEstimate.estimate(armor, w)
	t.check(a.rarity == -1 and a.value == 0 and a.power > 0.0, "非武器（也不是护具）：有分数，不推荐稀有度")


static func run_weights(t: TestCase) -> void:
	t.begin("151 · 系数表：仓库那份读得进；缺项用默认；认不出的键、形状不对的报；没有文件全默认")
	var problems: Array[String] = []
	var real := PowerWeights.load_from(PowerWeights.PATH, problems)
	t.check(problems.is_empty(), "仓库里那份没问题（%s）" % ", ".join(problems))
	t.check(FileAccess.file_exists(PowerWeights.PATH), "仓库里有 power_weights.json")
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(JSON.stringify({"_说明": "注释键不算", "per_cell_dps": 3, "nope": 1, "tiers": [1, 2], "heal_weight": "x"}))
	f.close()
	var bad: Array[String] = []
	var w := PowerWeights.load_from(TMP, bad)
	t.eq(w.per_cell_dps, 3.0, "写了的项生效")
	t.eq(w.horizon_sec, float(PowerWeights.DEFAULTS["horizon_sec"]), "缺的项用默认")
	t.eq(w.tiers.size(), 4, "形状不对的不用")
	var text := "\n".join(bad)
	for frag in ["没有这个系数 'nope'", "'tiers' 得是 4 个数", "'heal_weight' 得是数"]:
		t.check(text.contains(frag), "报：" + frag)
	t.check(not text.contains("_说明"), "注释键不报")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	t.eq(PowerWeights.load_from("user://no_such_151.json").to_dict(), PowerWeights.new().to_dict(), "没有文件：全默认")


static func run_existing(t: TestCase) -> void:
	t.begin("151 · 现有武器：都估得出来、没有未估；推荐稀有度和实际差不超过一档（差两档的列在 KNOWN_OFF 里等作者定）；所有道具都不出 NaN")
	var w := PowerWeights.load_from()
	var buffs := ContentLibrary.buffs()
	var off: Array[String] = []
	var weapons := 0
	for file in DirAccess.get_files_at(ITEMS):
		if not file.ends_with(".tres"):
			continue
		var def := load(ITEMS + "/" + file) as ItemDef
		if def == null:
			continue
		var e := PowerEstimate.estimate(def, w, buffs)
		t.check(not is_nan(e.power) and not is_inf(e.power), "%s：战斗力是个数（%.1f）" % [def.id, e.power])
		if not def.tags.has(&"weapon") or def.combat == null or def.blessed_of != &"":
			continue
		weapons += 1
		t.check(e.unestimated.is_empty(), "%s：没有未估的效果（%s）" % [def.id, e.unestimated])
		if absi(e.rarity - def.rarity) >= 2:
			off.append(String(def.id))
	t.check(weapons >= 10, "量了 %d 件武器" % weapons)
	off.sort()
	t.eq(off, KNOWN_OFF, "差两档以上的就是名单上那几件（%s）" % ", ".join(off))


static func run_bench_and_import(t: TestCase) -> void:
	t.begin("151 · 跑分表能生成（实测 > 0）；导入：武器稀有度和推荐差两档以上提醒、差一档不提醒")
	var w := PowerWeights.new()
	var a := _weapon(10.0, 2.0)
	var b := _weapon(6.0, 1.0)
	b.id = &"test_151_b"
	var rows := PowerBench.single_table([a, b] as Array[ItemDef], w, {}, 1)
	t.eq(rows.size(), 2, "单件表两行")
	t.check(float((rows[0]["measured"] as Array)[1]) > 0.0, "实测打得出伤害（%.1f）" % (rows[0]["measured"] as Array)[1])
	t.check(PowerBench.single_text(rows).contains("test_151_b"), "表里有字")
	var sets := PowerBench.set_table([a, b] as Array[ItemDef], [&"weapon"] as Array[StringName], w, 1)
	t.eq(sets.size(), 2, "组合表：同一标签两件各一行")

	var data := {"id": "test_151_import", "display_name": "测", "shape": ["1111"], "tags": ["weapon"], "rarity": 4,
		"combat": {"base_stats": {"damage": 8}, "rules": [{"trigger": {"type": "on_schedule"}, "cadence": {"type": "cooldown", "seconds": 2.0},
			"effects": [{"type": "deal_damage"}]}]}}
	var report := ImportReport.new()
	ContentImporter.import_item(data, ContentImporter.Context.new(), report)
	t.check(report.to_text().contains("差两档以上"), "传说档的弱武器：提醒（%s）" % report.to_text())
	data["rarity"] = 0
	var ok := ImportReport.new()
	ContentImporter.import_item(data, ContentImporter.Context.new(), ok)
	t.check(not ok.to_text().contains("差两档以上"), "普通档：不提醒")


static func frame_editor(t: TestCase, root: Window) -> void:
	t.begin("151 · 编辑器：右栏战斗力面板跟着表单变；新建武器画完形状预填一套能打的；「采用」写回稀有度与价值")
	var ed = load("res://ui/editor/content_editor.tscn").instantiate()
	root.add_child(ed)
	ed.new_weapon()
	t.check(ed._def.tags.has(&"weapon") and ed._def.combat == null, "新建武器：带 weapon 标签，还没有战斗数据（等画形状）")
	ed._shape.set_from(ItemShape.from_bits("11\n11"), null)
	ed._refresh()
	t.not_null(ed._def.combat, "画完形状：预填了")
	if ed._def.combat == null:
		ed.queue_free()
		return
	var d := PowerEstimate.default_weapon(4, ed._weights())
	t.eq(int(ed._def.combat.base_stats["damage"]), int(d["damage"]), "伤害按默认战斗力反算")
	var est: PowerEstimate.Breakdown = ed.power_estimate()
	t.check(est != null and absf(est.power / est.default_power - 1.0) < 0.15, "一出生战斗力 ≈ 默认（%.1f / %.1f）" % [est.power, est.default_power])
	t.check(ed._power.text().contains("战斗力"), "面板上写着战斗力")
	var before: float = est.power
	ed._def.combat.base_stats["damage"] = int(d["damage"]) * 2
	ed._refresh()
	t.check(ed.power_estimate().power > before, "改攻击力：战斗力跟着变")
	var rec: int = ed.power_estimate().rarity
	ed.adopt_power()
	t.eq(ed._def.rarity, rec, "采用：稀有度写进去了")
	t.eq(ed._def.value, ed.power_estimate().value, "采用：价值写进去了")
	ed._on_discard()
	ed.queue_free()


static func run_gear(t: TestCase) -> void:
	t.begin("151 补充（作者定）：非武器自带的护甲 / 减伤算进战斗力与价值；护具（armor / shield 标签）也给推荐，别的非武器只看分数")
	var w := PowerWeights.new()
	var vest := ItemDef.new()
	vest.id = &"test_vest"
	vest.tags = [&"gear", &"armor"] as Array[StringName]
	vest.shape = ItemShape.from_bits("111111")
	vest.combat = CombatProfile.new()
	vest.combat.base_stats = {"max_armor": 30.0}
	var e := PowerEstimate.estimate(vest, w)
	t.eq(e.defense, 30.0 * w.armor_per_point, "护甲上限 30 × 每点折算")
	t.check(e.power > 0.0 and e.is_gear and e.rarity >= 0 and e.value > 0, "护具给推荐：%s 价值 %d" % [e.rarity, e.value])
	vest.combat.base_stats = {"max_armor": 60.0}
	t.check(PowerEstimate.estimate(vest, w).power > e.power, "护甲多 → 战斗力高")
	var shield := ItemDef.new()
	shield.id = &"test_shield"
	shield.tags = [&"shield"] as Array[StringName]
	shield.shape = ItemShape.from_bits("11111")
	shield.combat = CombatProfile.new()
	shield.combat.base_stats = {"block": 5.0}
	t.eq(PowerEstimate.estimate(shield, w).defense, 5.0 * w.block_per_point, "格挡 5 × 每点折算")
	var trinket := ItemDef.new()
	trinket.id = &"test_trinket"
	trinket.shape = ItemShape.from_bits("1")
	trinket.combat = CombatProfile.new()
	trinket.combat.base_stats = {"max_armor": 10.0}
	var tr := PowerEstimate.estimate(trinket, w)
	t.check(tr.defense > 0.0 and tr.rarity == -1 and tr.value == 0, "别的非武器：护甲照样算进分数，但不给推荐")
	# 现有的皮甲、圆盾和实际差不超过一档（系数按它们定的；格挡方案 153 落地后再调）
	for id in ["leather_armor", "round_shield"]:
		var def := load("%s/%s.tres" % [ITEMS, id]) as ItemDef
		if def != null:
			var g := PowerEstimate.estimate(def, w)
			t.check(absi(g.rarity - def.rarity) <= 1, "%s：推荐 %d、实际 %d（预算比 %.2f）" % [id, g.rarity, def.rarity, g.ratio])


static func run_155(t: TestCase) -> void:
	t.begin("155 · 估算器三处修正：直伤乘耐力可持续系数、武器预算加一格把手（护具不加）、可叠层 DoT 一层按一场的一半；删掉冲锋枪与狙击枪，涂毒匕首是史诗")
	var w := PowerWeights.new()
	t.eq(w.handle_cells, 1.0, "把手格默认 1")
	t.eq(w.fight_sec, 12.0, "一场默认 12 秒")
	# a：耐力
	var free := _weapon(10.0, 1.0, 4)
	var e_free := PowerEstimate.estimate(free, w)
	t.eq(e_free.sustain, 1.0, "不耗耐力：不打折")
	var hungry := _weapon(10.0, 1.0, 4)
	var cost := ResourceCost.new()
	cost.amount = 16.0
	hungry.combat.rules[0].costs.append(cost)
	var e_hungry := PowerEstimate.estimate(hungry, w)
	var expect := (w.stamina_max + w.stamina_regen * w.fight_sec) / (16.0 * w.fight_sec)
	t.check(absf(e_hungry.sustain - expect) < 0.001, "155 补：一秒耗 16，一场能花「上限 50 + 回 4 × 12 秒」= 98，要 192：撑得住 %.2f（%.2f）" % [expect, e_hungry.sustain])
	t.check(absf(e_hungry.base - e_free.base * expect) < 0.001, "直伤 B 跟着打折")
	cost.amount = 8.0
	t.eq(PowerEstimate.estimate(hungry, w).sustain, 1.0, "一秒耗 8：一场 96 < 98，撑得住，不打折（只看回复会打对折）")
	t.eq(w.stamina_max, 50.0, "基础耐力上限 50（和 CombatantBaseline 一样）")
	t.eq(w.stamina_max, float(CombatantBaseline.DEFAULT_STATS["max_stamina"]), "和基线对得上")
	# b：把手
	t.eq(PowerEstimate.estimate(_weapon(2.0, 1.0, 1), w).default_power, 4.0, "一格武器的预算 = 2 ×（1 + 1）")
	t.eq(w.default_power(3, false), 6.0, "护具不加把手")
	var plate := ItemDef.new()
	plate.tags = [&"armor"] as Array[StringName]
	plate.shape = ItemShape.from_bits("1111")
	t.eq(PowerEstimate.estimate(plate, w).default_power, 8.0, "护具的预算照旧按格数")
	t.eq(int(PowerEstimate.default_weapon(1, w)["damage"]), roundi(w.default_power(1) * w.default_cooldown), "新建武器预填伤害按同一公式")
	# c：叠层视野
	t.eq(w.expected_duration(0.0, true, true), 6.0, "可叠层：一层平均待一场的一半")
	t.eq(w.expected_duration(0.0, true, false), w.horizon_sec * w.persist_share, "不可叠层的永续照旧")
	t.eq(w.expected_duration(5.0, false, false), 5.0, "限时照旧")
	# 内容
	var db := ItemDatabase.new()
	db.load_dir()
	t.check(db.get_def(&"smg") == null and db.get_def(&"sniper") == null, "冲锋枪、狙击枪删了（作者定：废弃道具）")
	t.eq(db.get_def(&"poisoned_knife").rarity, 3, "涂毒匕首提到史诗（155 待定 3）")
	var inv := GridInventory.new(Vector2i(4, 4))
	inv.try_add(ItemInstance.create(db.get_def(&"shortsword")), true)
	var saved := inv.to_dict()
	var ghost := ((saved["items"] as Array)[0] as Dictionary).duplicate(true)
	ghost["def"] = "sniper"
	ghost["uid"] = int(ghost["uid"]) + 1000
	ghost["origin"] = [3, 0]
	(saved["items"] as Array).append(ghost)
	var back := GridInventory.from_dict(saved, db)
	t.eq(back.item_count(), 1, "老存档里的狙击枪读回来丢掉，别的照旧")
