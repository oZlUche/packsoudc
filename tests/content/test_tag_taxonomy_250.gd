## 250（作者 2026-10-24 14:42 定稿）：标签整理 —— 四个给玩家看的轴（类别恰好一个 / 属性 / 本源 / 归属）+ 内部轴；
## 材质不再是标签（`ItemDef.material` 字段）；现代道具全删；带 `faith:<神>` 的就是信物；悬浮窗每轴最多列一个
extends RefCounted

const RETIRED_TAGS: Array[StringName] = [&"gear", &"gear_plug", &"tool", &"bow", &"gun", &"sigil", &"faith", &"faith_anchor", &"relic",
	&"trophy", &"blessed", &"enchanted", &"node_tooltips", &"metal", &"wood", &"leather", &"cloth", &"bone", &"stone", &"gem", &"clay",
	&"flesh", &"herb"]
const MODERN: Array[StringName] = [&"armor", &"high_tier_armor", &"armor_plate", &"battery", &"core", &"crowbar", &"drone", &"mag",
	&"medkit", &"pistol", &"rifle", &"shotgun", &"stim"]


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func run_axes(t: TestCase) -> void:
	t.begin("250：每件恰好一个类别（包、铸牌免）；武器恰好一个射程；素材有本源与材质；退掉的标签没人带")
	var db := _db()
	var bad_kind: Array[String] = []
	var bad_range: Array[String] = []
	var bad_material: Array[String] = []
	var retired: Array[String] = []
	for id in db.all_ids():
		var d := db.get_def(id)
		if d.is_blessed():
			continue
		var kinds := d.tags.filter(func(tg: StringName) -> bool: return TagRegistry.category_of(tg) == TagRegistry.KIND)
		if not d.is_bag and not d.is_token() and kinds.size() != 1:
			bad_kind.append("%s %s" % [id, kinds])
		if d.tags.has(&"weapon") and int(d.tags.has(&"melee")) + int(d.tags.has(&"ranged")) != 1:
			bad_range.append(String(id))
		if d.tags.has(&"material"):
			var sources := d.tags.filter(func(tg: StringName) -> bool: return TagRegistry.category_of(tg) == "source")
			if sources.size() != 1 or d.material == "":
				bad_material.append(String(id))
		for tg in d.tags:
			if RETIRED_TAGS.has(tg):
				retired.append("%s:%s" % [id, tg])
		if d.material != "" and not ItemMaterials.IDS.has(StringName(d.material)):
			bad_material.append("%s(%s)" % [id, d.material])
	t.eq(bad_kind, [] as Array[String], "类别恰好一个")
	t.eq(bad_range, [] as Array[String], "武器恰好一个 melee / ranged")
	t.eq(bad_material, [] as Array[String], "素材有一个本源、填了材质；材质都在十个里")
	t.eq(retired, [] as Array[String], "退掉的标签没人带")
	for tg in RETIRED_TAGS:
		t.check(TagRegistry.get_def(tg) == null, "标签表里没有 %s" % tg)
	t.eq(TagRegistry.category_of(&"trinket"), TagRegistry.KIND, "新增「饰物」是类别")
	t.eq(TagRegistry.name_of(&"material"), "素材", "material 改名「素材」")
	t.check(TagRegistry.is_internal(&"melee") and TagRegistry.is_internal(&"part") and TagRegistry.is_internal(&"bullion") and TagRegistry.is_internal(&"sealed"), "射程、零件、金银、封存降内部")
	t.eq(TagRegistry.category_of(&"beast_part"), "affiliation", "兽材归归属轴")
	t.eq(TagRegistry.category_of(&"faith:brute"), "affiliation", "神的标签归归属轴")


static func run_modern_gone(t: TestCase) -> void:
	t.begin("250 §6.3：十三件现代道具全删、进改名表折钱；棉甲是防具")
	var db := _db()
	for id in MODERN:
		t.check(not db.all_ids().has(id), "%s 不在库" % id)
		t.check(IdAliases.RETIRED_ITEMS.has(id), "%s 在 RETIRED_ITEMS" % id)
	var gamb := db.get_def(&"gambeson")
	t.check(gamb != null and gamb.tags.has(&"armor") and gamb.display_name == "棉甲", "gambeson 改成防具「棉甲」")


static func run_material_field(t: TestCase) -> void:
	t.begin("250 §6.2：材质是字段 —— 重量、音效、铸炉、包的准入都照认")
	var db := _db()
	var ore := db.get_def(&"iron_ore")
	t.eq(ore.material, "metal", "铁矿石的材质是金属")
	t.check(ore.has_tag(&"metal") and not ore.tags.has(&"metal"), "has_tag 认材质，标签里没有")
	t.eq(ItemWeight.formula(ore), ore.cell_count() * ItemWeight.PER_CELL_METAL, "金属每格 3 重")
	t.eq(SfxMaterial.of(ore), SfxMaterial.METAL, "金属声")
	var pouch := db.get_def(&"herb_pouch")
	var herbs := db.get_def(&"dried_herbs")
	var grid := GridInventory.new()
	t.check(pouch.bag_accept_tags.has(&"herb") and grid._bag_accepts(pouch, herbs), "药草囊照收草药")
	var forge := load(ContentPaths.asset_file("forge", "effect")) as ForgeTable
	t.eq(forge.by_material(ore).key, &"metal", "铸炉按材质字段落金属行")
	t.eq(TagRegistry.name_of(&"herb"), "草药", "包的准入里写的材质有名字")
	var spy := db.get_def(&"spyglass")
	t.check(spy.keepsake_abilities.has(&"node_tooltips") and not spy.tags.has(&"node_tooltips"), "望远镜的能力写在 keepsake_abilities")


static func run_anchor(t: TestCase) -> void:
	t.begin("250 §6.2：带 faith:<神> 的就是信物（派生赐福版除外）；faith / faith_anchor 标签没了")
	var db := _db()
	for id in [&"charm_brute", &"tibia_violence", &"thorn_seed", &"blessed_longbow"]:
		var d := db.get_def(id)
		t.check(d != null and d.is_anchor(), "%s 是信物" % id)
	var knife := db.get_def(&"knife")
	t.check(not knife.is_anchor() and not knife.has_faith(), "匕首不归神")
	var faiths := FaithDef.load_all()
	Blessings.derive_all(db, faiths)
	var blessed := db.get_def(Blessings.variant_id(&"knife", &"brute"))
	t.check(blessed != null and blessed.has_faith() and blessed.is_blessed() and not blessed.is_anchor(), "赐福版带神的标签，但不是信物")
	t.check(blessed != null and not blessed.tags.has(&"faith") and not blessed.tags.has(&"blessed"), "赐福版不再挂 faith / blessed 标签")


static func run_tooltip_one_per_axis(t: TestCase) -> void:
	t.begin("250 §6.1：悬浮窗标签行 —— 类别 → 属性 → 本源 → 归属，每轴最多一个，内部不列")
	t.eq(TagRegistry.first_per_category([&"weapon", &"melee", &"bleed", &"poison", &"barbarian"]), [&"weapon", &"bleed", &"barbarian"], "溃烂之刃式：只列流血")
	t.eq(TagRegistry.first_per_category([&"material", &"nature"]), [&"material", &"nature"], "铁矿：素材 · 自然")
	t.eq(TagRegistry.first_per_category([&"trinket", &"treasure", &"faith:brute"]), [&"trinket", &"faith:brute"], "蛮神护符：饰物 · 蛮神")
	t.eq(TagRegistry.first_per_category([&"material", &"nature", &"beast_part", &"faith:hunt"]), [&"material", &"nature", &"faith:hunt"], "归属有神先列神")
	var db := _db()
	var fest := ItemInstance.create(db.get_def(&"festering_blade"))
	var text := ItemTooltip.describe(fest)
	t.check(text.contains("tags/bleed.png") or text.contains("流血"), "溃烂之刃列流血")
	t.check(not text.contains("tags/poison.png"), "毒不再列（属性轴只一个）")
