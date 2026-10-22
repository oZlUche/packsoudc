## 241（作者 10-22）：进阶一拆成三级，每级只管一样、只写一行 —— Ⅰ 体力上限 −1、Ⅱ 加侵蚀、Ⅲ 再加猎手；
## 一局只挂一个难度，所以每级的数据带齐到自己为止；Ⅰ 由成就「满载而归」解锁，Ⅱ、Ⅲ 各由在上一级撤离一次解锁
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func _by_id(list: Array, id: StringName) -> DifficultyDef:
	for d in list:
		if (d as DifficultyDef).id == id:
			return d
	return null


static func _kinds(d: DifficultyDef) -> Array:
	var out: Array = []
	for m in d.mechanics:
		out.append("erosion" if m is ErosionMechanic else ("hunters" if m is HunterMechanic else "?"))
	return out


static func run_ladder_data(t: TestCase) -> void:
	t.begin("241 · 三级的数据：一级一样东西、机制带齐到本级、数值不改；解锁链 Ⅰ → Ⅱ → Ⅲ")
	var all := GameFlow.load_difficulties()
	var one := _by_id(all, &"ascension_1")
	var two := _by_id(all, &"ascension_2")
	var three := _by_id(all, &"ascension_3")
	t.check(one != null and two != null and three != null, "三级都在")
	if one == null or two == null or three == null:
		return
	t.eq([one.level, two.level, three.level], [1, 2, 3], "档位 1 / 2 / 3")
	t.eq([_kinds(one), _kinds(two), _kinds(three)], [[], ["erosion"], ["erosion", "hunters"]], "Ⅰ 无机制、Ⅱ 侵蚀、Ⅲ 侵蚀 + 猎手")
	for d: DifficultyDef in [one, two, three]:
		var fx: Array[RunEffect] = d.run_effects()
		t.check(fx.size() == 1 and fx[0] is VitalityMaxBonus and (fx[0] as VitalityMaxBonus).amount == -1, "%s：体力上限 −1" % d.id)
		t.check(not d.challenge.contains("；") and d.challenge.length() <= 10, "%s：中文一行（%s）" % [d.id, d.challenge])
		t.check(String(d.challenges.get("en", "")) != "", "%s：有英文" % d.id)
	t.eq([one.requires_unlock, two.requires_unlock, three.requires_unlock], [&"ascension_1", &"ascension_2", &"ascension_3"], "各要各的解锁")
	t.eq([one.grants_unlock, two.grants_unlock, three.grants_unlock], [&"ascension_2", &"ascension_3", &""], "Ⅰ 发 Ⅱ、Ⅱ 发 Ⅲ、Ⅲ 不发")
	t.eq(three.hunter_bracket_steps(), [0, 5, 10, 20] as Array[int], "猎手段位表原数")
	var em := two.mechanics[0] as ErosionMechanic
	t.eq(em.effects.size(), 3, "侵蚀三条原样")


static func frame_rows_fit_one_line(t: TestCase, root: Window) -> void:
	t.begin("241 · 纸卷上三级各占一行（中英都不折行）")
	var all := GameFlow.load_difficulties()
	var was := UiText.lang
	for lang in ["zh", "en"]:
		UiText.lang = lang
		var scroll := ChallengeScroll.new()
		root.add_child(scroll)
		var lines: Array = []
		for id in [&"ascension_1", &"ascension_2", &"ascension_3"]:
			var d := _by_id(all, id)
			if d != null:
				lines.append([d.level, Names.pick(d.challenges, d.challenge)])
		scroll.set_lines(lines, false)
		for row in scroll.rows():
			t.eq(float(row["h"]), ChallengeScroll.ROW_MIN_H, "%s：%s 一行高" % [lang, row["text"]])
		root.remove_child(scroll)
		scroll.free()
	UiText.lang = was


static func frame_extract_unlocks_next(t: TestCase, root: Window) -> void:
	t.begin("241 · 在 Ⅰ 撤离 → 开 Ⅱ；在 Ⅱ 撤离 → 开 Ⅲ；死了不开")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var all := GameFlow.load_difficulties()
	for pair in [[&"ascension_1", &"ascension_2"], [&"ascension_2", &"ascension_3"]]:
		var f := Support.flow(c, "ladder241")
		f.difficulties = all
		f.meta.grant_unlock(StringName(pair[0]))
		var d := _by_id(all, StringName(pair[0]))
		var run := f.begin(c.chapter, kit, 5, [] as Array[int], null, [], d)
		t.check(run != null and run.difficulty == d, "%s 开局" % pair[0])
		if run == null:
			continue
		f.pick_spawn(run.map.entry_ids[0])
		var near := MapNavigator.nearest_of_type(run.map, run.travel.current_id, &"extract")
		var there := int(near["id"]) >= 0 and Support.walk_to(f, int(near["id"]), GameFlow.Screen.EVENT)
		t.check(there and not run.is_over(), "%s：走到撤离点" % pair[0])
		t.check(not f.meta.has_unlock(StringName(pair[1])), "撤离前没有 %s" % pair[1])
		if there and not run.is_over():
			t.check(f.extract(), "撤离")
			t.check(f.meta.has_unlock(StringName(pair[1])), "%s 撤离 → 开了 %s" % [pair[0], pair[1]])
		Support.cleanup("ladder241")
