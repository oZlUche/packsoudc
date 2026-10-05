## 124（作者定）：常用道具的上位版本 —— 口粮 / 纱布 / 伤药 / 解毒包各三阶，一件低阶 + 一件材料合成高阶
extends RefCounted

## 每条阶梯：[一阶, 二阶, 三阶]
const LADDERS := [
	[&"ration", &"salted_meat", &"field_rations"],
	[&"bandage", &"bandage_roll", &"styptic_dressing"],
	[&"salve", &"strong_salve", &"healing_draught"],
	[&"antidote_kit", &"antidote_satchel", &"panacea"],
]
## 产物 → [低阶, 材料]
const RECIPES := {
	&"salted_meat": [&"ration", &"raw_salt"], &"field_rations": [&"salted_meat", &"beeswax"],
	&"bandage_roll": [&"bandage", &"linen_bolt"], &"styptic_dressing": [&"bandage_roll", &"dried_herbs"],
	&"strong_salve": [&"salve", &"beeswax"], &"healing_draught": [&"strong_salve", &"quartz_cluster"],
	&"antidote_satchel": [&"antidote_kit", &"dried_herbs"], &"panacea": [&"antidote_satchel", &"styptic_dressing"],
}


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


## 一件道具的「强度」：被动加成之和 + 每条规则的回复量 / 清层数 / 次数（只用来比大小）
static func _power(def: ItemDef) -> float:
	var p := 0.0
	for k in def.combat.base_stats:
		p += float(def.combat.base_stats[k])
	for r in def.combat.rules:
		for e in r.effects:
			if e is ChangeResource:
				p += (e as ChangeResource).amount
			elif e is RemoveStatus:
				p += 10.0 * float((e as RemoveStatus).stacks)
		for c in r.costs:
			if c is UsesCost:
				p += 10.0 * float((c as UsesCost).max_uses)
	return p


static func run(t: TestCase) -> void:
	var db := _db()
	t.begin("124 · 八件新道具都在库里：阶梯稀有度递增、三阶竖两格、价值走公式、标签同一阶梯不变")
	for ladder in LADDERS:
		var base := db.get_def(ladder[0])
		for i in 3:
			var d := db.get_def(ladder[i])
			t.not_null(d, "%s 在库里" % ladder[i])
			if d == null:
				continue
			t.check(d.combat != null, "%s：有战斗档" % d.id)
			t.eq(d.value, 0 if i > 0 else d.value, "%s：价值不手填" % d.id)
			if i > 0:
				var prev := db.get_def(ladder[i - 1])
				t.check(d.rarity > prev.rarity, "%s 比 %s 稀有" % [d.id, prev.id])
				t.check(_power(d) > _power(prev), "%s 比 %s 强（%.0f > %.0f）" % [d.id, prev.id, _power(d), _power(prev)])
				for tag in base.tags:
					t.check(d.tags.has(tag), "%s：带一阶的标签 %s" % [d.id, tag])
				t.check(Names.of(d, "en") != String(d.id), "%s：有英文名" % d.id)
			t.eq(d.shape.cell_count(), 2 if i == 2 else 1, "%s：%d 格" % [d.id, 2 if i == 2 else 1])

	t.begin("124 · 八条配方：一件低阶 + 一件材料（万灵药是两条阶梯的汇合：解毒药囊 + 止血敷料）")
	var recipes := GameFlow.load_recipes()
	for out in RECIPES:
		var pair: Array = RECIPES[out]
		var r := RecipeDef.find(recipes, pair[0], pair[1])
		t.not_null(r, "%s + %s 有配方" % pair)
		if r != null:
			t.eq(r.output, out, "→ %s" % out)
		t.not_null(db.get_def(pair[1]), "%s 在库里" % pair[1])

	t.begin("124 · 说明文字不写数字（TextLint）")
	for out in RECIPES:
		var text := FileAccess.get_file_as_string(ContentPaths.authoring_file("items", String(out)))
		var json := JSON.new()
		t.eq(json.parse(text), OK, "%s 能解析" % out)
		t.eq(TextLint.scan(json.data).size(), 0, "%s：说明里没有裸数字" % out)

	t.begin("124 · 百科「合成」页带上腌肉干与绷带卷")
	var page: Resource = load(ContentPaths.asset_file("help_pages", "crafting"))
	var see: Array = page.get("see_items")
	t.check(see.has(&"salted_meat") and see.has(&"bandage_roll"), "相关道具里有")

	t.begin("124 · 一局里：粗盐块压到口粮上 → 腌肉干")
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	var kit: Array[StringName] = [&"bag_leather", &"bag_leather", &"ration"]
	var run := RunState.start(chapter, 3, db, enemies, sets, kit)
	var cm := CraftingModule.of(run)
	t.not_null(cm, "有合成模块")
	if cm == null:
		return
	cm.recipes = recipes
	var ration: ItemInstance = null
	for inst in run.board.items():
		if (inst as ItemInstance).def.id == &"ration":
			ration = inst
	t.not_null(ration, "开局背包里有口粮")
	if ration == null:
		return
	var r := cm.craft(ItemInstance.create(db.get_def(&"raw_salt")), ration.uid)
	t.check(bool(r["ok"]), "合成了")
	t.eq(String(r["output"]), "salted_meat", "产物是腌肉干")
