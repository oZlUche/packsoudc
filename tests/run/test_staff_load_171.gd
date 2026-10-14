## 171 §4（作者定）：法杖的晶石座是**装载槽**，和受益槽分开 —— 魔晶石只认装载槽；一颗晶石只给一把法杖（后放的那把），
## 同一把的几个装载槽被同一颗占住只算一份；被抢走的那把装载槽按空算。悬浮窗：装了几颗写几行（空槽不写），晶石自己写装在哪。
extends RefCounted


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _damage(spec: CombatantSpec, uid: int) -> float:
	return StatMath.to_float(spec.item_of(uid).stats.total_of(&"damage"))


## 两把法杖竖着放在第 0 列与第 3 列（装载槽：头顶那格的左右），火焰晶石横放在 (1, 0)：压着左杖的 (1, 0) 与右杖的 (2, 0)
static func _two_staves(db: ItemDatabase) -> Dictionary:
	ItemInstance.reset_uid_counter()
	var g := GridInventory.new(Vector2i(5, 3), 1, false)
	var a := ItemInstance.create(db.get_def(&"magic_staff"))
	g.place(a, Vector2i(0, 0), 0)
	var b := ItemInstance.create(db.get_def(&"magic_staff"))
	g.place(b, Vector2i(3, 0), 0)
	var c := ItemInstance.create(db.get_def(&"fire_crystal"))
	g.place(c, Vector2i(1, 0), 0)
	return {"board": g, "a": a, "b": b, "crystal": c}


static func run_staff_data(t: TestCase) -> void:
	t.begin("171 · 数据：魔法杖的晶石座是装载槽（没有受益槽）；默认只装魔晶石；老 JSON 里法杖的受益格导入时迁成装载格（待定 4 A）")
	var db := _db()
	var staff := db.get_def(&"magic_staff")
	t.eq(staff.adjacency.load_cells.size(), 2, "两个装载槽")
	t.check(staff.adjacency.receive_cells.is_empty(), "没有受益槽")
	t.eq(staff.adjacency.load_tags(), [&"crystal"] as Array[StringName], "默认只装魔晶石")
	var old := {"id": "old_staff", "display_name": "旧杖", "shape": ["1", "1", "1"], "tags": ["weapon", "melee", "staff", "magic"],
		"adjacency": {"receive_cells": [[-1, 0], [1, 0]], "receive_filter": ["crystal"]}}
	var report := ImportReport.new()
	var def := ContentImporter.import_item(old, ContentImporter.Context.new(), report)
	t.eq(def.adjacency.load_cells, [Vector2i(-1, 0), Vector2i(1, 0)] as Array[Vector2i], "受益格迁成装载格")
	t.check(def.adjacency.receive_cells.is_empty(), "受益格清空")
	t.check(report.to_text().contains("迁成了装载格"), "提醒重存一次")


static func run_one_staff_per_crystal(t: TestCase) -> void:
	t.begin("171 · 编译：晶石压着两把法杖的装载槽 → 只给后放的那把（再把另一把重新落下就换它）；被抢的那把按空")
	var db := _db()
	var base := float(db.get_def(&"magic_staff").combat.base_stats["damage"])
	var plus := (db.get_def(&"fire_crystal").adjacency.feed_mods[0] as StatModifier).amount
	var s := _two_staves(db)
	var g: GridInventory = s["board"]
	t.eq(BattleCompiler.load_claimants(g, s["crystal"].uid), [s["a"].uid, s["b"].uid] as Array[int], "两把都压着它")
	var spec := BattleCompiler.compile_board(g)
	t.eq(int(spec.loads.get(s["crystal"].uid, -1)), s["b"].uid, "给后放的右杖")
	t.eq(_damage(spec, s["b"].uid), base + plus, "右杖 +%s" % plus)
	t.eq(_damage(spec, s["a"].uid), base, "左杖按空")
	t.eq(spec.item_of(s["a"].uid).attached.size(), 0, "左杖没挂供给规则")
	t.eq(spec.fed_uids, [s["crystal"].uid] as Array[int], "晶石只记一次 fed")
	g.reseat(s["a"].uid)     # 左杖重新落下 = 后来者
	var again := BattleCompiler.compile_board(g)
	t.eq(int(again.loads.get(s["crystal"].uid, -1)), s["a"].uid, "左杖成了后放的：换给它")
	t.eq(_damage(again, s["a"].uid), base + plus, "左杖 +%s" % plus)
	t.eq(_damage(again, s["b"].uid), base, "右杖按空")


static func run_two_slots_one_share(t: TestCase) -> void:
	t.begin("171 · 一颗晶石占了同一把法杖的两个装载槽：只算一份")
	var db := _db()
	var staff_def := db.get_def(&"magic_staff").duplicate(true) as ItemDef
	staff_def.id = &"probe_staff"
	staff_def.adjacency.load_cells = [Vector2i(1, 0), Vector2i(1, 1)] as Array[Vector2i]     # 右边上下两格
	ItemInstance.reset_uid_counter()
	var g := GridInventory.new(Vector2i(4, 3), 1, false)
	var staff := ItemInstance.create(staff_def)
	g.place(staff, Vector2i(0, 0), 0)
	var crystal := ItemInstance.create(db.get_def(&"fire_crystal"))
	t.check(g.place(crystal, Vector2i(1, 0), 1), "晶石竖着放进右边两格")
	var spec := BattleCompiler.compile_board(g)
	var base := float(staff_def.combat.base_stats["damage"])
	var plus := (crystal.def.adjacency.feed_mods[0] as StatModifier).amount
	t.eq(_damage(spec, staff.uid), base + plus, "一份（不按格数乘）")
	t.eq(spec.item_of(staff.uid).attached.size(), 1, "一条供给规则")


static func run_tooltip_lines(t: TestCase) -> void:
	t.begin("171 · 悬浮窗：法杖装了几颗写几行（空槽不写），一行写晶石名、每 X 秒 Y 火焰伤害、剩 N 次；晶石写装在哪 / 被抢 / 闲置")
	var db := _db()
	var s := _two_staves(db)
	var g: GridInventory = s["board"]
	var b_text := Glossary.strip_bbcode(ItemTooltip.describe(s["b"], g))
	var a_text := Glossary.strip_bbcode(ItemTooltip.describe(s["a"], g))
	var name := Names.of_item(s["crystal"])
	t.check(b_text.contains(name) and b_text.contains("火焰伤害") and b_text.contains("剩 %d 次" % (s["crystal"] as ItemInstance).charges()), "右杖：一行装载（%s）" % b_text)
	t.check(not a_text.contains(name), "左杖：被抢走的那颗不写（空槽不显示）")
	var lone := ItemInstance.create(db.get_def(&"magic_staff"))
	var lone_full := ItemTooltip.describe_full(lone)
	t.check(not String(lone_full["body"]).contains("term:装载槽"), "没装晶石的法杖：没有装载行")
	var crystal_text := Glossary.strip_bbcode(ItemTooltip.describe(s["crystal"], g))
	t.check(crystal_text.contains("装在：%s" % Names.of_item(s["b"])), "晶石：装在右杖")
	t.check(crystal_text.contains("另一把法杖的装载槽也压着它"), "晶石：另一把也压着（后放的优先）")
	var idle := ItemInstance.create(db.get_def(&"ice_crystal"))
	g.place(idle, Vector2i(1, 2), 0)
	t.check(Glossary.strip_bbcode(ItemTooltip.describe(idle, g)).contains("闲置"), "没放在装载槽上：闲置")
	# 两颗：右杖两边各一颗 → 两行
	var second := ItemInstance.create(db.get_def(&"lightning_crystal"))
	g.remove(s["a"].uid)
	t.check(g.place(second, Vector2i(4, 0), 1) or g.place(second, Vector2i(4, 0), 0), "右杖右边再放一颗")
	var body := String(ItemTooltip.describe_full(s["b"], g)["body"])
	t.eq(body.count("term:装载槽"), 2 if g.has_item(second.uid) else 1, "装了几颗写几行")
