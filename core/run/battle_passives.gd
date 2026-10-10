## 一局里玩家这场吃着的「常驻」加成（103 第 6 条）→ [PassiveNote] 列表，开战编译时挂到 [member CombatantSpec.passives]。
##
## 作者定的准则：栏里只放**通用 buff —— 作用对象是角色本身**。所以收：作用于角色本身的信仰级效果（[method FaithPerk.battle_note]）、
## 已激活的套装档位（施加到全部参战道具）、局外 / 一局 buff 的战斗加成、技能 / 难度 / 神坛改的基础属性。
## 105 也收：神坛攒的标准轴层数（祈祷的「炽烈」）—— 它种在系统层，战斗里不发 AXIS_SHIFTED，来源只能在这里说。
## 不收：信物自己的按阶加成（faith_bonuses 只作用于那一件）、包体与邻接（只作用于被圈住的几件，画在棋盘格子上）、
## 只作用于某类道具的信仰效果（附魔几把武器、食物翻倍）。
## 只读 RunState，不改任何东西
class_name BattlePassives
extends RefCounted


static func of(run: RunState) -> Array[PassiveNote]:
	var out: Array[PassiveNote] = []
	if run == null:
		return out
	# --- 信仰：作用于角色本身的信仰级效果，层数 = 达到的阶 ---
	var faith := run.active_faith()
	var tier := run.active_faith_tier()
	if faith != null and tier >= 1:
		var lines: Array[String] = []
		var altar := AltarModule.of(run)
		for p in (altar.perks() if altar != null else [] as Array[FaithPerk]):
			var d := (p as FaithPerk).battle_note(run)
			if d != "":
				lines.append(d)
		if not lines.is_empty():
			out.append(PassiveNote.make(StringName("faith:" + String(faith.id)), "信仰：%s" % Names.of(faith), tier, [], "\n".join(lines)))
	# --- 套装：层数 = 激活的档位数 ---
	var tracker := run.tracker
	if tracker != null:
		for set_id in tracker.tracked_ids():
			var tiers := tracker.active_tiers(set_id)
			if tiers.is_empty():
				continue
			var def := tracker.db.get_def(set_id) if tracker.db != null else null
			var mods: Array = []
			var rules: Array[String] = []
			for t in tiers:
				mods.append_array((t as SetTier).mods)
				for r in (t as SetTier).rules:
					rules.append(Glossary.rule_text(r as AbilityRule))
			var name := Names.of(def) if def != null and Names.of(def) != "" else String(set_id)
			out.append(PassiveNote.make(StringName("set:" + String(set_id)), "%s %d 件" % [name, tracker.count_of(set_id)],
				tiers.size(), mods, "\n".join(rules)))
	# --- 局外 / 一局 buff：有战斗加成的才算 ---
	for d in run.active_buff_defs():
		var buff := d as RunBuffDef
		if buff == null or (buff.mods.is_empty() and buff.rules.is_empty()):
			continue
		var rules2: Array[String] = []
		for r in buff.rules:
			rules2.append(Glossary.rule_text(r as AbilityRule))
		out.append(PassiveNote.make(StringName("run_buff:" + String(buff.id)), Names.of(buff) if Names.of(buff) != "" else String(buff.id),
			1, buff.mods, "\n".join(rules2)))
	# --- 技能 / 难度 / 神坛改的基础属性 ---
	var bonus := run.buff_context().stat_bonus.duplicate()
	var mult: Dictionary = run.buff_context().stat_mult     # 149：科技的百分比
	var altar_bonus: Dictionary = AltarModule.of(run).stat_bonus if AltarModule.of(run) != null else {}
	for k in altar_bonus:
		bonus[k] = float(bonus.get(k, 0.0)) + float(altar_bonus[k])
	if not bonus.is_empty() or not mult.is_empty():
		var mods2: Array = []
		var mkeys := mult.keys()
		mkeys.sort()
		for k in mkeys:
			if float(mult[k]) != 0.0:
				mods2.append(StatModifier.make(StringName(String(k)), StatModifier.Mode.MULT, float(mult[k])))
		var keys := bonus.keys()
		keys.sort()
		for k in keys:
			if float(bonus[k]) == 0.0:
				continue
			var m := StatModifier.new()
			m.stat = StringName(String(k))
			m.amount = float(bonus[k])
			mods2.append(m)
		if not mods2.is_empty():
			out.append(PassiveNote.make(&"base_bonus", "基础属性加成", 1, mods2, "技能、难度、神坛改的基础属性"))
	# --- 105：神坛攒的标准轴层数（祈祷的「炽烈」）。层数种在系统层，战斗里不会发 AXIS_SHIFTED，
	# 所以来源靠这一格说清楚；轴格本身按 103 的规矩由面板画 ---
	var axes: Dictionary = AltarModule.of(run).axes() if AltarModule.of(run) != null else {}
	for axis in StatAxes.ORDER:
		var stacks := int(axes.get(axis, 0))
		if stacks == 0:
			continue
		out.append(PassiveNote.make(StringName("axis:" + String(axis)), StatAxes.name_of(axis, stacks), absi(stacks), [],
			StatAxes.describe(axis, 0, stacks)))
	# --- 129：负重减益（层数 = 级数）。说清楚为什么出手慢了、耐力少了 ---
	var enc_level := run.encumbrance_level()
	if run.encumbrance != null and enc_level > 0:
		out.append(PassiveNote.make(&"encumbrance", "负重：%s" % run.encumbrance.name_of(enc_level), enc_level, [],
			"负重 %d / %d：%s" % [run.carry_weight(), run.carry_capacity(), run.encumbrance.effect_text(enc_level)]))
	return out
