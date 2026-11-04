## 272 战记：手搓一段事件 → 行文（被挡括号、暴击、治疗、施加、持续伤害、反转治疗、分组交替、法杖带晶石名）；
## 英文版不含中文；回放拖到一半，栏里的行数 = 到那一刻的行数
extends RefCounted

const ONE := StatMath.ONE


static func _poison() -> BuffDef:
	var def := BuffDef.new()
	def.id = &"poison"
	def.display_name = "中毒"
	def.display_names = {"en": "Poison"}
	def.is_debuff = true
	def.element = &"poison"
	var r := AbilityRule.new()
	var dd := DealDamage.new()
	dd.target = DealDamage.Target.SELF
	dd.damage_type = &"poison"
	r.effects.append(dd)
	def.rules.append(r)
	return def


static func _ev(n: StringName, t: float, side: int, p: Dictionary = {}) -> BattleEvent:
	return BattleEvent.make(n, StatMath.from_float(t), side, p)


static func _hit(t: float, victim: int, src: int, uid: int, raw: int, amount: int, extra: Dictionary = {}) -> BattleEvent:
	var p := {"type": "physical", "raw": raw * ONE, "absorbed": 0, "block": 0, "amount": amount * ONE, "source_side": src, "uid": uid, "crit": false, "direct": true}
	p.merge(extra, true)
	return _ev(BattleEvent.DAMAGE, t, victim, p)


static func _result() -> BattleResult:
	var r := BattleResult.new()
	r.buffs = {&"poison": _poison()}
	r.winner = 0
	r.duration = StatMath.from_float(6.0)
	r.log = [
		_ev(BattleEvent.BATTLE_START, 0.0, -1),
		_ev(BattleEvent.ITEM_FIRED, 1.0, 0, {"uid": 3}),
		_hit(1.0, 1, 0, 3, 8, 8),     # 0：我 短剑 8
		_ev(BattleEvent.ITEM_FIRED, 1.0, 1, {"uid": 9}),
		_hit(1.0, 0, 1, 9, 10, 7, {"absorbed": 3 * ONE}),     # 1：护甲挡 3
		_ev(BattleEvent.STATUS_STACKED, 1.0, 0, {"buff": "poison", "delta": 2, "stacks": 2}),     # 同一组第二行
		_ev(BattleEvent.ITEM_FIRED, 2.0, 0, {"uid": 3}),
		_hit(2.0, 1, 0, 3, 12, 6, {"absorbed": 2 * ONE, "block": 4 * ONE, "crit": true}),     # 2：暴击、拆开
		_hit(3.0, 0, 0, 0, 2, 2, {"type": "poison", "direct": false}),     # 3：持续伤害（中毒）
		_hit(3.0, 1, 1, 0, 1, 1, {"type": "fire", "direct": false}),     # 4：推断不出
		_ev(BattleEvent.ITEM_FIRED, 4.0, 0, {"uid": 4}),
		_ev(BattleEvent.RESOURCE_CHANGED, 4.0, 0, {"key": "hp", "delta": 5 * ONE, "reason": "heal", "current": 20 * ONE, "max": 30 * ONE}),     # 5：伤药
		_ev(BattleEvent.RESOURCE_CHANGED, 4.0, 0, {"key": "stamina", "delta": -1 * ONE, "reason": "cost", "current": 1, "max": 1}),     # 不写
		_ev(BattleEvent.ITEM_FIRED, 4.5, 1, {"uid": 9}),
		_ev(BattleEvent.RESOURCE_CHANGED, 4.5, 0, {"key": "hp", "delta": 4 * ONE, "reason": "heal", "current": 24 * ONE, "max": 30 * ONE}),     # 反转连带的，不写
		_hit(4.5, 0, 1, 9, 4, -4),     # 6：反而治疗
		_ev(BattleEvent.ITEM_FIRED, 5.0, 0, {"uid": 7, "step": 1, "steps": 2, "next": 0}),
		_hit(5.0, 1, 0, 7, 9, 9, {"type": "fire"}),     # 7：法杖·第二颗
		_ev(BattleEvent.STATUS_UNSTACKED, 5.5, 0, {"buff": "poison", "delta": -2, "stacks": 0}),     # 8：消失
		_ev(BattleEvent.DIED, 6.0, 1),     # 9
		_ev(BattleEvent.BATTLE_END, 6.0, -1, {"winner": 0}),
	] as Array[BattleEvent]
	return r


static func _lines(r: BattleResult) -> Array[Dictionary]:
	return BattleNarrator.lines(r, ["阿丽", "坑蝰"], [{3: "短剑", 4: "伤药", 7: "魔法杖", 11: "火晶石", 12: "冰晶石"}, {9: "毒牙"}], [{7: [11, 12]}, {}])


static func run_lines(t: TestCase) -> void:
	t.begin("272 §2.1：每类事件一行人话（中文）")
	UiText.lang = "zh"
	var ls := _lines(_result())
	var p: Array[String] = []
	for l in ls:
		p.append(BattleNarrator.plain(l))
	t.eq(p.size(), 12, "十一行事件 + 末行战报：%s" % "\n".join(p))
	if p.size() < 12:
		return
	t.eq(p[0], "1.0s  阿丽使用短剑造成了 8 物理伤害", "没被挡")
	t.eq(p[1], "1.0s  坑蝰使用毒牙造成了 10 物理伤害（被抵挡了 3 伤害，最终伤害为 7）", "被护甲挡")
	t.eq(p[2], "1.0s  　　又给阿丽施加了 2 层【中毒】（共 2 层）", "同一次出手第二行：缩进、省主语")
	t.eq(p[3], "2.0s  暴击！阿丽使用短剑造成了 12 物理伤害（被抵挡了 6 伤害：护甲 2、格挡 4，最终伤害为 6）", "暴击 + 护甲格挡拆开")
	t.eq(p[4], "3.0s  阿丽因【中毒】受到 2 毒素伤害", "持续伤害：按身上最近叠的状态推断")
	t.check(p[5].contains("因【持续效果】受到 1 "), "推断不出：持续效果（%s）" % p[5])
	t.eq(p[6], "4.0s  阿丽使用伤药恢复了 5 生命", "治疗；耐力消耗不写")
	t.eq(p[7], "4.5s  坑蝰使用毒牙的一下反而治疗了 4", "反转成治疗：只写一行")
	t.eq(p[8], "5.0s  阿丽使用魔法杖·冰晶石造成了 9 火焰伤害", "法杖写成「法杖·这一下读的晶石」")
	t.eq(p[9], "5.5s  阿丽身上的【中毒】消失了", "状态消失")
	t.eq(p[10], "6.0s  坑蝰倒下了", "倒下")
	t.check(p[11].contains("阿丽造成 24") and int(ls[11]["at"]) == _result().log.size(), "末行战报，挂在日志末尾（%s）" % p[11])


static func run_groups(t: TestCase) -> void:
	t.begin("272 §2.2：一次出手一组，相邻组两种墨交替；数字与属性词用属性色")
	UiText.lang = "zh"
	var ls := _lines(_result())
	if ls.size() < 12:
		t.check(false, "行数不够")
		return
	t.eq(ls[1]["group"], ls[2]["group"], "打中又施加：同一组")
	var gs: Array = []
	for l in ls:
		if gs.is_empty() or gs.back() != l["group"]:
			gs.append(l["group"])
	var ok := true
	for i in gs.size():
		ok = ok and int(gs[i]) == i
	t.check(ok, "组号挨个往上：%s" % str(gs))
	for l in ls:
		var want := "[color=@log_a]" if int(l["group"]) % 2 == 0 else "[color=@log_b]"
		t.check(String(l["text"]).contains(want), "第 %d 组用 %s" % [l["group"], want])
	t.check(String(ls[0]["text"]).contains("[color=@dmg_physical]8[/color]"), "数字用伤害类型色")
	t.check(String(ls[3]["text"]).contains("[color=@crit]12[/color]"), "暴击数字用暴击色")
	t.check(String(ls[6]["text"]).contains("[color=@heal]5[/color]"), "治疗数字用治疗色")
	var dark := UiPalette.resolve_styles(String(ls[0]["text"]), UiTheme.TONE_DARK)
	t.check(not dark.contains("@"), "界面换色后不剩颜色名：%s" % dark)


static func run_english(t: TestCase) -> void:
	t.begin("272：英文版每行都不含中文")
	UiText.lang = "en"
	var r := _result()
	var ls := BattleNarrator.lines(r, ["Ari", "Viper"], [{3: "Shortsword", 4: "Salve", 7: "Staff", 11: "Fire Crystal", 12: "Ice Crystal"}, {9: "Fang"}], [{7: [11, 12]}, {}])
	var rx := RegEx.create_from_string("[\\x{3000}-\\x{303f}\\x{4e00}-\\x{9fff}\\x{ff00}-\\x{ffef}]")
	var bad: Array[String] = []
	for l in ls:
		var s := BattleNarrator.plain(l)
		if rx.search(s) != null:
			bad.append(s)
	UiText.lang = "zh"
	t.eq(bad, [] as Array[String], "没有中文")
	t.eq(ls.size(), 12, "行数和中文一样")


static func frame_view(t: TestCase, root: Window) -> void:
	t.begin("272 §2.3：回放逐条贴、拖到一半重写到游标、跳过全文")
	UiText.lang = "zh"
	var view := BattleView.new()
	view.bronze = true
	root.add_child(view)
	var r := _result()
	view.play(r, ["阿丽", "坑蝰"])
	view.set_item_names(0, {3: "短剑", 4: "伤药", 7: "魔法杖"})
	view.set_item_names(1, {9: "毒牙"})
	t.eq(view.log_shown(), 0, "开场：空")
	view.seek(2.5)
	var want := 0
	for l in view.log_lines():
		if float(l["time"]) <= StatMath.from_float(2.5):
			want += 1
	t.eq(view.log_shown(), want, "拖到 2.5 秒：%d 行" % want)
	t.eq(view.ticker().get_paragraph_count() - 1, want, "栏里也是这么多行")
	view.skip_to_end()
	t.eq(view.log_shown(), view.log_lines().size(), "跳过：全文（含末行战报）")
	view.seek(1.0)
	t.eq(view.log_shown(), 3, "再拖回 1 秒：清空重写到那一刻")
	view.queue_free()
