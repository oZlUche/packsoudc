## 152（作者定）：buff 每层带几层标准轴 ——「每层血怒 = 一层【强攻】+ 一层【加速】」，不再直接写 +3% 伤害、+3% 攻速。
##
## 层数跟着 buff 走（叠层多、掉层少、没了就没），和道具 shift_axis 给的层直接相抵；导入器认轴、对落在轴上的 mods 提醒；
## 词条、预估 DPS、战斗力估算都算上；buff 编辑器里「每层带的标准轴」一栏、轴字段是下拉
extends RefCounted

const SCENE := "res://ui/buff_editor/buff_editor.tscn"


## 只有一件道具的假人：那件道具伤害 10、急速 0
static func _dummy() -> CombatantRuntime:
	var item := CompiledItem.new()
	item.source_uid = 7
	item.def_id = &"dummy_weapon"
	item.stats = StatSet.new()
	item.stats.ensure(BattleStats.DAMAGE).base = StatMath.from_float(10.0)
	var spec := CombatantSpec.new()
	spec.baseline = StatSet.new()
	spec.add(item)
	return CombatantRuntime.from_spec(spec, 0)


static func _rage(stackable: bool = true) -> BuffDef:
	var def := BuffDef.new()
	def.id = &"t_rage_152"
	def.stackable = stackable
	def.axes.append(BuffAxis.make(StatAxes.DAMAGE_DEALT, 1))
	def.axes.append(BuffAxis.make(StatAxes.ATTACK_SPEED, 1))
	return def


static func run_runtime(t: TestCase) -> void:
	t.begin("152 · 结算：每层 buff 带的轴并进合计，跟着层数走，没了就没了，和别的来源相抵")
	var rt := _dummy()
	var dmg0 := rt.item_stat(7, BattleStats.DAMAGE)
	var rage := _rage()
	rt.apply_buff(rage, 2)
	t.eq(rt.axis_carried(StatAxes.DAMAGE_DEALT), 2, "两层 buff → 带两层强攻")
	t.eq(rt.axis_total(StatAxes.ATTACK_SPEED), 2, "加速的合计也是 2")
	t.eq(rt.axis_stacks(StatAxes.DAMAGE_DEALT), 0, "不记在内容层（不是另外施加的层）")
	var want := StatMath.mul(dmg0, StatAxes.factor(StatAxes.DAMAGE_DEALT, 2))
	t.eq(rt.item_stat(7, BattleStats.DAMAGE), want, "道具伤害 × (1 + 2 × 3%%)：%.2f" % StatMath.to_float(want))

	rt.shift_axis(StatAxes.DAMAGE_DEALT, -3)
	t.eq(rt.axis_total(StatAxes.DAMAGE_DEALT), -1, "被加 3 层虚弱：2 − 3 = −1，直接相抵")
	rt.shift_axis(StatAxes.DAMAGE_DEALT, 3)

	rt.remove_buff_stacks(rage.id, 1)
	t.eq(rt.axis_total(StatAxes.DAMAGE_DEALT), 1, "掉一层 buff → 少一层强攻")
	rt.remove_buff_stacks(rage.id, 1)
	t.eq(rt.axis_total(StatAxes.DAMAGE_DEALT), 0, "buff 没了 → 带的层也没了")
	t.eq(rt.item_stat(7, BattleStats.DAMAGE), dmg0, "伤害回到原样")

	# 会过期的那种：到期一起走
	var timed := _rage(false)
	timed.duration_sec = 1.0
	rt.apply_buff(timed, 1, 0)
	t.eq(rt.axis_total(StatAxes.ATTACK_SPEED), 1, "限时 buff 在：加速 1 层")
	rt.expire_buffs(StatMath.from_float(2.0))
	t.eq(rt.axis_total(StatAxes.ATTACK_SPEED), 0, "到期一起走")


static func run_content(t: TestCase) -> void:
	t.begin("152 · 内容：血怒每层带一层强攻、一层加速；词条写着")
	var rage: BuffDef = ContentLibrary.buffs().get(&"blood_rage", null)
	t.check(rage != null and rage.mods.is_empty(), "血怒不再写 mods")
	if rage != null:
		t.eq(rage.axis_stacks_per(StatAxes.DAMAGE_DEALT), 1, "每层一层强攻")
		t.eq(rage.axis_stacks_per(StatAxes.ATTACK_SPEED), 1, "每层一层加速")
		var text := Glossary.describe_buff(rage)
		t.check(text.contains("【强攻】1 层（造成的伤害 +3%）") and text.contains("【加速】1 层（攻速 +3%）"), "词条：%s" % text)
	var mark := BuffDef.new()
	mark.id = &"t_mark"
	mark.axes.append(BuffAxis.make(StatAxes.ARMOR, -3))
	t.check(Glossary.describe_buff(mark).contains("【破绽】3 层（防护 −3）"), "负层用反名、折成多少写清：%s" % Glossary.describe_buff(mark))


static func run_import(t: TestCase) -> void:
	t.begin("152 · 导入：axes 往返；没有的轴报错；落在轴上的 mods 提醒改写成 axes；轴表达不了的不提醒")
	var ctx := ContentImporter.Context.new()
	var r := ImportReport.new()
	var def := ContentImporter.import_buff({"id": "t_rage", "stackable": false, "duration_sec": 5.0,
		"axes": [{"axis": "damage_dealt", "stacks": 1}, {"axis": "attack_speed", "stacks": 2}]}, ctx, r)
	t.check(r.ok() and r.warnings.is_empty(), "正常的 axes 不报错不提醒：%s" % r.to_text())
	t.eq(def.axis_stacks_per(StatAxes.ATTACK_SPEED), 2, "读进来了")
	var out := ContentExporter.export_buff(def)
	t.check(out.has("axes") and (out["axes"] as Array).size() == 2, "导出带着 axes：%s" % str(out.get("axes")))
	var back := ContentImporter.import_buff(out, ContentImporter.Context.new(), ImportReport.new())
	t.eq(back.axis_stacks_per(StatAxes.DAMAGE_DEALT), 1, "往返一致")

	var bad := ImportReport.new()
	ContentImporter.import_buff({"id": "t_bad", "axes": [{"axis": "nope", "stacks": 1}]}, ContentImporter.Context.new(), bad)
	t.check(not bad.ok() and bad.to_text().contains("nope"), "没有的轴：报错（%s）" % bad.to_text())

	var old := ImportReport.new()
	ContentImporter.import_buff({"id": "t_old", "stackable": false, "duration_sec": 5.0,
		"mods": [{"mode": "MULT", "amount": 3.0}, {"stat": "haste", "mode": "MULT", "amount": 3.0}]}, ContentImporter.Context.new(), old)
	t.check(old.ok() and old.warnings.size() == 2 and old.to_text().contains("axes"), "伤害 / 攻速写在 mods 里：两条提醒（%s）" % old.to_text())
	var shield := ImportReport.new()
	ContentImporter.import_buff({"id": "t_sh", "mods": [{"stat": "max_shield", "amount": 5.0}]}, ContentImporter.Context.new(), shield)
	t.check(shield.warnings.is_empty(), "护盾上限没有轴：不提醒")


static func run_estimates(t: TestCase) -> void:
	t.begin("152 · 预估：开战血怒带的轴算进预估 DPS；战斗力估算给带轴的 buff 正值")
	var spec := CombatantSpec.new()
	spec.baseline = StatSet.new()
	var item := CompiledItem.new()
	item.source_uid = 1
	item.stats = StatSet.new()
	item.stats.ensure(BattleStats.DAMAGE).base = StatMath.from_float(10.0)
	var rule := AbilityRule.new()
	rule.trigger = OnBattleStart.new()
	var ap := ApplyStatus.new()
	ap.target = CombatEffect.Target.SELF
	ap.buff = _rage()
	ap.stacks = 2
	rule.effects.append(ap)
	item.rules.append(rule)
	spec.add(item)
	t.eq(int(spec.opening_axes().get(StatAxes.DAMAGE_DEALT, 0)), 2, "开战两层 → 两层强攻")
	var boosted := spec.stats_with_opening(item).total_of(BattleStats.DAMAGE)
	t.eq(boosted, StatMath.mul(StatMath.from_float(10.0), StatAxes.factor(StatAxes.DAMAGE_DEALT, 2)), "预估用的伤害乘上了轴")

	var w := PowerWeights.new()
	var ctx := PowerContext.new()
	ctx.weights = w
	ctx.own_dps = 10.0
	ctx.own_hz = 1.0
	t.check(_rage().value_per_sec(ctx) > 0.0, "带强攻 + 加速的 buff 每秒值为正（%.3f）" % _rage().value_per_sec(ctx))


static func frame_editor(t: TestCase, root: Window) -> void:
	t.begin("152 · buff 编辑器：有「每层带的标准轴」一栏、轴字段是下拉、摘要写出来、灰字说清一层折多少")
	var before := UiText.lang
	UiText.lang = "zh"
	var ed: Node = load(SCENE).instantiate()
	root.add_child(ed)
	ed._new_buff()
	var d: BuffDef = ed.def()
	d.axes.append(BuffAxis.make(StatAxes.DAMAGE_DEALT, 1))
	d.axes.append(BuffAxis.make(StatAxes.ATTACK_SPEED, 1))
	ed._rebuild_form()
	ed._refresh()
	t.check(ed.summary_text().contains("【强攻】1 层") and ed.summary_text().contains("【加速】1 层"), "摘要：%s" % ed.summary_text())
	t.check(ed._json.text.contains("\"axes\"") and ed._json.text.contains("attack_speed"), "JSON 预览写着 axes")
	t.check(ed._validate().ok(), "导入器放行")
	var labels := _texts(ed._form_host)
	t.check(labels.has("每层带的标准轴（2）"), "表单里有「每层带的标准轴」一栏，两行")
	var picked := false
	for s in labels:
		if String(s).begins_with("强攻 / 虚弱"):
			picked = true
	t.check(picked, "轴字段是下拉，显示正名 / 反名")
	t.check(BuffAxis.make(StatAxes.ATTACK_SPEED, 1).editor_hint().contains("攻速"), "灰字：%s" % BuffAxis.make(StatAxes.ATTACK_SPEED, 1).editor_hint())
	t.eq(PropertyForm.axis_label("armor"), "格挡 / 破绽 (armor)", "下拉的显示名")
	ed.queue_free()
	UiText.lang = before


## 一棵控件树里的所有文字（标签、按钮、下拉当前项）
static func _texts(node: Node) -> Array:
	var out: Array = []
	if node is Label:
		out.append((node as Label).text)
	elif node is OptionButton:
		out.append((node as OptionButton).text)
	elif node is Button:
		out.append((node as Button).text)
	for c in node.get_children():
		out.append_array(_texts(c))
	return out
