## 143（作者定）：装备改成异形格子（护手、锤头、弓把、肩甲、裙摆……），主数值按格数等比加；皮背包 3×3，开局都放得下
extends RefCounted

## 改过的那几件：id → [原格数, 原主数值]（每格的强度不变：新值 = 原值 × 新格数 ÷ 原格数，四舍五入）
const BEFORE := {
	&"shortsword": [2, 5], &"cleaver": [2, 5], &"bloodletter": [2, 6], &"scimitar": [3, 7], &"festering_blade": [3, 9],
	&"longsword": [3, 12], &"mithril_sword": [3, 16], &"tibia_violence": [4, 15], &"warhammer": [3, 30],
	&"shortbow": [3, 6], &"longbow": [4, 8], &"blessed_longbow": [4, 10],
	&"leather_armor": [4, 20], &"plate_cuirass": [9, 45], &"blessed_shield": [4, 6],
}
## 作者（2026-10-12）把这两件改成了笔直的长条（1×3、1×4）：仍守「每格强度不变」，但不再要求是异形
const STRAIGHT := [&"shortsword", &"longsword"]
const MAIN_STATS := [&"damage", &"max_armor", &"block"]


static func run_scaled_by_cells(t: TestCase) -> void:
	t.begin("143 · 改过的装备：不再是长方形，主数值 ÷ 格数和原来一样（四舍五入以内）")
	var c := TestSupport.load_content()
	for id in BEFORE:
		var def := c.items.get_def(id)
		t.check(def != null, "%s 在库里" % id)
		if def == null:
			continue
		var box := def.shape.size_rotated(0)
		var cells := def.cell_count()
		if not STRAIGHT.has(id):
			t.check(cells < box.x * box.y, "%s 是异形（%d 格，外框 %d×%d）" % [Names.of(def), cells, box.x, box.y])
		var stat := &""
		for k in MAIN_STATS:
			if def.combat.base_stats.has(k):
				stat = k
				break
		var was: Array = BEFORE[id]
		var want := floori(float(was[1]) * cells / float(was[0]) + 0.5)
		t.eq(int(def.combat.base_stats[stat]), want, "%s 的%s：%d × %d / %d" % [Names.of(def), Glossary.stat_name(stat), was[1], cells, was[0]])


static func run_kits_fit(t: TestCase) -> void:
	t.begin("143 · 皮背包 3×3；两个皮背包的开局预设全部放得下（没有落到地上的）")
	var c := TestSupport.load_content()
	var bag := c.items.get_def(&"bag_leather")
	t.eq(bag.cell_count(), 9, "皮背包 9 格")
	for l in GameFlow.load_loadouts():
		var kit: Array[StringName] = []
		var has_bag := false
		for id in (l as LoadoutDef).items:
			kit.append(StringName(id))
			var d := c.items.get_def(StringName(id))
			if d != null and d.is_bag:
				has_bag = true
		if not has_bag:
			kit.push_front(&"bag_leather")
			kit.push_front(&"bag_leather")
		var s := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets, kit)
		t.check(s != null and s.storage.items().is_empty(), "%s：全进了包（地上 %d 件）" % [l.id, s.storage.items().size() if s != null else -1])
