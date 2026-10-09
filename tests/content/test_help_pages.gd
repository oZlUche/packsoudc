## 125（作者定）：百科机制页首批全文 —— 六个分类四十六页（含 114 的「合成」），order 连续、相关能跳、目录有序、搜得到
extends RefCounted

const EXPECTED := {
	"flow": ["map_and_steps", "search_point", "battle_and_prebattle", "staging_zone", "extraction_and_defeat", "vitality", "settlement_and_warehouse", "characters"],
	"bag": ["drag_and_rotate", "bags", "quick_place", "tidy", "crafting", "grant_receive_slots", "anchor_and_right_click", "encumbrance"],
	"combat": ["auto_battle", "direct_damage_and_armor", "shield", "buffs_and_stacks", "stamina_and_cooldown", "haste", "multipliers"],
	"faith": ["anchor_activation", "faith_power_and_tiers", "altar_offering", "special_rites", "switch_and_dormant",
		"god_brute", "god_sun", "god_nature", "god_earth", "god_skill", "god_hunt"],
	"map": ["node_types", "random_node", "shop", "rest_point", "safe_box", "countdown_and_closing", "hunters", "erosion", "teleport"],
	"meta": ["warehouse", "tech_tree", "codex", "achievements", "save_slots"],
}


static func run(t: TestCase) -> void:
	var help := GameFlow.load_help_pages()
	var db := ItemDatabase.new()
	db.load_dir()
	var book := Encyclopedia.build(help, db)
	var by_id := {}
	for h in help:
		by_id[String((h as HelpPageDef).id)] = h

	t.begin("125 · 机制页齐全（136：四十八页），分类对得上")
	var total := 0
	for cat in EXPECTED:
		total += (EXPECTED[cat] as Array).size()
		for id in EXPECTED[cat]:
			t.check(by_id.has(id), "%s 在" % id)
			if by_id.has(id):
				t.eq(String((by_id[id] as HelpPageDef).category), cat, "%s 在 %s 分类" % [id, cat])
	t.eq(total, 48, "清单四十八页（129 加了「负重」、136 加了「三个角色」）")
	t.eq(help.size(), 48, "库里四十八页")

	t.begin("125 · 每个分类的 order 从零连续、不撞位，目录按 order 排")
	var toc := book.toc()
	for cat in EXPECTED:
		var orders: Array[int] = []
		for id in EXPECTED[cat]:
			if by_id.has(id):
				orders.append((by_id[id] as HelpPageDef).order)
		orders.sort()
		var want: Array[int] = []
		for i in orders.size():
			want.append(i)
		t.eq(orders, want, "%s：order 连续" % cat)
		var listed: Array = []
		for sec in toc:
			if String(sec["category"]) == cat:
				listed = sec["groups"][0]["ids"]
		t.eq(listed, EXPECTED[cat], "%s：目录顺序" % cat)
	var cats: Array[String] = []
	for sec in toc:
		cats.append(String(sec["category"]))
	t.eq(cats.slice(0, HelpPageDef.CATEGORIES.size()), Array(HelpPageDef.CATEGORIES, TYPE_STRING, "", null), "机制页分类按清单顺序排在前面")

	t.begin("125 · related 都能跳（页 id 或词条名），see_items 都在库里，正文无裸数字")
	for h in help:
		var def := h as HelpPageDef
		for r in def.related:
			t.check(book.has_page(r) or book.page_for(r) != "" or book.has_page("term:" + r), "%s 的相关「%s」能跳" % [def.id, r])
		for item_id in def.see_items:
			t.not_null(db.get_def(item_id), "%s 的相关道具 %s 在库里" % [def.id, item_id])
		t.eq(TextLint.scan({"text": def.text}).size(), 0, "%s：正文没有裸数字" % def.id)
		t.check(not def.text.contains("<!--") and not def.text.contains("待核"), "%s：没有待核注释" % def.id)

	t.begin("125 · 搜索：「护盾」命中护盾页与词条页；「地上」命中地上页")
	var hits := book.search("护盾", {"_items": db})
	t.check(hits.has("shield"), "护盾页")
	t.check(hits.has("term:护盾"), "护盾词条")
	t.check(book.search("地上", {"_items": db}).has("staging_zone"), "地上页")


static func run_single_bucket_wording(t: TestCase) -> void:
	t.begin("审查 D1 · 战斗页跟 133 单一乘区一致：不再写「四类乘区」「同区相加、跨区相乘」")
	var by_id := {}
	for h in GameFlow.load_help_pages():
		by_id[String((h as HelpPageDef).id)] = h
	for id in ["multipliers", "haste", "direct_damage_and_armor"]:
		var page: HelpPageDef = by_id.get(id, null)
		t.not_null(page, "%s 在" % id)
		if page == null:
			continue
		var text := String(page.text)
		for stale in ["四类", "物理增伤", "元素增伤", "跨区", "不同乘区", "自己的乘区"]:
			t.check(not text.contains(stale), "%s 不再写「%s」" % [id, stale])
	var m: HelpPageDef = by_id.get("multipliers", null)
	if m != null:
		t.check(String(m.text).contains("只有一个乘区") and String(m.text).contains("先相加"), "乘区页写的是一个乘区、乘算先相加")
