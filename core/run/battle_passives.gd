## 一局里玩家这场吃着的「常驻」加成（103 第 6 条）→ [PassiveNote] 列表，开战编译时挂到 [member CombatantSpec.passives]。
##
## 作者定的准则只有一条：**影响战斗的就显示**。所以收：信仰（阶 + 信仰级效果）、已激活的套装档位、
## 局外 / 一局 buff 的战斗加成、技能 / 难度 / 神坛改的基础属性。包体与邻接不收（画在棋盘格子上）。
## 只读 RunState，不改任何东西
class_name BattlePassives
extends RefCounted


static func of(run: RunState) -> Array[PassiveNote]:
	var out: Array[PassiveNote] = []
	if run == null:
		return out
	# --- 信仰：层数 = 达到的阶 ---
	var faith := run.active_faith()
	var tier := run.active_faith_tier()
	if faith != null and tier >= 1:
		var lines: Array[String] = []
		for p in run.faith_perks():
			var d := (p as FaithPerk).describe()
			if d != "":
				lines.append(d)
		out.append(PassiveNote.make(StringName("faith:" + String(faith.id)), "信仰：%s" % Names.of(faith), tier, [],
			"\n".join(lines) if not lines.is_empty() else "信仰道具按阶解锁的功能"))
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
	for k in run.faith_stat_bonus:
		bonus[k] = float(bonus.get(k, 0.0)) + float(run.faith_stat_bonus[k])
	if not bonus.is_empty():
		var mods2: Array = []
		var keys := bonus.keys()
		keys.sort()
		for k in keys:
			if float(bonus[k]) == 0.0:
				continue
			var m := StatModifier.new()
			m.stat = StringName(String(k))
			m.flat = float(bonus[k])
			mods2.append(m)
		if not mods2.is_empty():
			out.append(PassiveNote.make(&"base_bonus", "基础属性加成", 1, mods2, "技能、难度、神坛改的基础属性"))
	return out
