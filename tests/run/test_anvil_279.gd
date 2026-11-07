## 279 第五步：休息点的砧 —— 武器 + 一类材料配上升级配方就能锤；材料高几档出件就几档品质；每座砧免费一次；
## 营地的砧（286 起）= 「铁炉」两栏屏的左栏（两个槽、锤键、出件槽、便条）；道具悬浮窗多一行「可升为」
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const F175 := preload("res://tests/run/test_forge_175.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func _inst(db: ItemDatabase, id: StringName) -> ItemInstance:
	return ItemInstance.create(db.get_def(id), 0)


static func run_logic(t: TestCase) -> void:
	t.begin("279 第五步 · 砧的配方：一把武器能升成哪几张；材料配得上才出件；品质按材料高出的档数，和原件取较高")
	var c = NodeScreens._content()
	var db: ItemDatabase = c.items
	var pool := SmithRecipeDef.load_all()
	var ups := Anvil.upgrades_for(db.get_def(&"broadsword"), pool)
	var ids := ups.map(func(r: SmithRecipeDef) -> StringName: return r.id)
	t.check(ids.has(&"anvil_bone_broadsword") and ids.has(&"anvil_steel_broadsword") and ids.has(&"anvil_ironwood_broadsword"), "阔剑：骨 / 钢 / 铁木三张（%s）" % [ids])
	t.check(String(ids[0]) <= String(ids[ids.size() - 1]), "按 id 排")
	t.eq(Anvil.upgrades_for(db.get_def(&"beast_claw"), pool).size(), 0, "材料本身升不了")
	t.eq(Anvil.recipe_for(db.get_def(&"broadsword"), db.get_def(&"antler"), pool).id, &"anvil_bone_broadsword", "鹿角（骨、绿）配上骨柄那张")
	ItemInstance.reset_uid_counter()
	var sword := _inst(db, &"broadsword")
	var made := Anvil.result(sword, _inst(db, &"beast_claw"), pool, db)
	t.check(made != null and made.def.id == &"bone_broadsword" and made.quality() == 1, "兽爪（蓝）比要求高一档：出 1 档骨柄阔剑")
	t.eq(Anvil.result(sword, _inst(db, &"antler"), pool, db).quality(), 0, "正好够：0 档")
	sword.set_quality(2)
	t.eq(Anvil.result(sword, _inst(db, &"beast_claw"), pool, db).quality(), 2, "原件 2 档：取较高")
	t.check(Anvil.result(_inst(db, &"broadsword"), _inst(db, &"broadsword"), pool, db) == null, "不是材料：配不上")


static func run_strike(t: TestCase) -> void:
	t.begin("279 第五步 · 在休息点锤：两件从原处拿走、出件带品质、这座砧用掉；再锤不行；锁着的不让锤")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, "anvil279")
	f.smith_recipes = SmithRecipeDef.load_all()
	var node := F175._rest_next_to_spawn(f, c, kit)
	t.check(node != null and f.step_to(node.id), "走上休息点")
	if node == null:
		Support.cleanup("anvil279")
		return
	t.check(f.anvil_open(node), "砧开着")
	var held := GridInventory.new(Vector2i(8, 8), 0, false)
	var sword := _inst(f.items, &"broadsword")
	var claw := _inst(f.items, &"beast_claw")
	held.try_add(sword, true)
	held.try_add(claw, true)
	claw.set_locked(true)
	t.check(f.anvil_strike(node, sword, held, claw, held) == null and held.item_count() == 2 and f.anvil_open(node), "材料锁着：不锤、什么也不动")
	claw.set_locked(false)
	var made := f.anvil_strike(node, sword, held, claw, held)
	t.check(made != null and made.def.id == &"bone_broadsword" and made.quality() == 1, "出 1 档骨柄阔剑")
	t.eq(held.item_count(), 0, "两件都拿走了")
	t.check(Anvil.used(node) and not f.anvil_open(node), "这座砧用掉了")
	var again := f.anvil_strike(node, _inst(f.items, &"broadsword"), null, _inst(f.items, &"antler"), null)
	t.check(again == null, "再锤不行")
	t.check(f.meta.codex_lit(&"bone_broadsword"), "图鉴点亮")
	Support.cleanup("anvil279")


static func run_tooltip(t: TestCase) -> void:
	t.begin("279 第五步 · 道具悬浮窗：能上砧的武器多一行「可升为」，列出每一把；不能升的没有这一行")
	var c = NodeScreens._content()
	var db: ItemDatabase = c.items
	var text := Glossary.strip_bbcode(ItemTooltip.describe(_inst(db, &"broadsword")))
	t.check(text.contains(UiText.t("tip.upgrades_to").split("%")[0]) and text.contains(Names.of(db.get_def(&"bone_broadsword"))), "阔剑：可升为…骨柄阔剑（%s）" % text.replace("\n", " | "))
	var claw := Glossary.strip_bbcode(ItemTooltip.describe(_inst(db, &"beast_claw")))
	t.check(not claw.contains(UiText.t("tip.upgrades_to").split("%")[0]), "材料没有这一行")


static func frame_camp_anvil(t: TestCase, root: Window) -> void:
	t.begin("286 §2.2 · 营地的砧挪进「铁炉」：营地没有占位键「砧」；点铁炉进两栏屏，左栏是砧 —— 状态句、配不上红框一句、锤完灰；返回槽里的回背包；两栏都用过开不了")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	Support.cleanup("anvil279_ui")
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = String(Support.paths("anvil279_ui")["run"])
	game.meta_path = String(Support.paths("anvil279_ui")["meta"])
	game.settings_path = String(Support.paths("anvil279_ui")["settings"])
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	var node := F175._rest_next_to_spawn(flow, c, kit)
	t.check(node != null and flow.step_to(node.id), "走上休息点")
	t.eq(NodeEvents.effective_type(node), &"rest", "休息点的类型是 rest（resolved_type 不翻）")
	var camp = game.overlay()
	t.check(camp != null and camp.has_method("piece") and not camp.has_method("anvil_key"), "营地屏，没有占位键「砧」")
	var keys := 0
	if camp != null:
		for b in (camp as Node).find_children("*", "Button", true, false):
			keys += 1 if (b as Button).text == UiText.t("camp.anvil") else 0
	t.eq(keys, 0, "屏上没有写着「砧」的键")
	t.check(camp != null and camp.has_method("click") and camp.click(&"forge"), "点铁炉")
	var screen = game.overlay()
	if screen == null or not screen.has_method("anvil"):
		t.check(false, "进了铁炉两栏屏")
		game.queue_free()
		Support.cleanup("anvil279_ui")
		return
	var col: AnvilColumn = screen.anvil()
	t.check(col != null and col.is_visible_in_tree(), "左栏是砧")
	t.check(col.get_global_rect().intersection(screen.spot_rect("bag")).get_area() == 0.0 and Rect2(Vector2.ZERO, screen.size).encloses(col.get_global_rect()), "砧不压背包、不出屏（%s）" % col.get_global_rect())
	for i in 3:
		t.check(col.get_global_rect().intersection(screen.slot_view(i).get_global_rect()).get_area() == 0.0, "砧不压铸炉的槽 %d" % i)
	t.eq(col.status_text(), UiText.t("anvil.free"), "状态：免费一次")
	var before := flow.run.board.item_count()
	t.check(col.strike_key is TextureButton and (col.strike_key as TextureButton).texture_normal != null, "定稿 A：锤键是圆的图键")
	t.check(col._glyph_weapon.visible and col._glyph_material.visible, "空槽：淡刻剑和矿石")
	var sword := _inst(flow.items, &"broadsword")
	t.check(col.weapon_slot.try_add(sword, true), "武器槽放阔剑")
	t.check(not col._glyph_weapon.visible and col._glyph_material.visible, "武器槽有东西：剑形藏起来")
	t.check(not col.weapon_slot.accepts(flow.items.get_def(&"beast_claw")), "武器槽不收材料")
	var note := col.note_text()
	t.check(note.contains(Names.of(flow.items.get_def(&"bone_broadsword"))) and note.contains(ItemMaterials.name_of(&"bone")), "便条：列出骨柄阔剑、要骨（%s）" % note.replace("\n", " | "))
	t.check(col.strike_key.disabled and not col.material_warned(), "只有武器：锤键灰、不红")
	var hide := _inst(flow.items, &"beast_hide")
	t.check(col.material_slot.try_add(hide, true), "材料槽放兽皮（皮，配不上）")
	t.check(col.material_warned(), "配不上：材料槽红框")
	t.check(col.note_text().begins_with(Glossary.strip_bbcode(UiPalette.toned(AnvilColumn.need_line(Anvil.upgrades_for(sword.def, flow.smith_recipes)[0]), UiTheme.TONE_LIGHT))), "便条头一句：要【骨】≥ 绿（%s）" % col.note_text().get_slice("\n", 0))
	t.check(col.strike_key.disabled, "配不上：锤键灰")
	col.material_slot.remove(hide.uid)
	t.check(col.material_slot.try_add(_inst(flow.items, &"beast_claw"), true), "换成兽爪")
	t.check(not col.material_warned(), "配上了：红框收")
	t.check(col.preview() != null and col.preview().quality() == 1, "预览 1 档")
	t.check(col._note.text.contains(ItemTooltip.QUALITY_BADGE), "便条换成出件的说明（带金菱）")
	t.check(not col.strike_key.disabled, "两件配上：锤键亮")
	var made := col.strike()
	t.check(made != null and col.out.has_item(made.uid), "锤：出件进出件槽")
	t.check(col.weapon_slot.item_count() == 0 and col.material_slot.item_count() == 0, "两件消耗")
	t.check(col.strike_key.disabled, "出件槽有东西：锤键灰")
	t.eq(col.status_text(), UiText.t("anvil.used"), "状态：这处的砧用过了")
	t.eq((col.strike_key as TextureButton).texture_disabled, UiTheme.art_cached(AnvilColumn.KEY_ART + "used"), "用过了：锤换冷的")
	t.check(col.weapon_slot.try_add(_inst(flow.items, &"broadsword"), true) and col.strike_key.disabled, "再放一把：锤键还是灰（这座砧用过了）")
	t.check(screen.to_map(), "返回")
	t.check(flow.run.board.has_item(made.uid) or flow.run.storage.has_item(made.uid), "出件回了背包（或地上）")
	t.check(flow.run.board.item_count() >= before, "背包没少东西")
	t.check(flow.open_forge(node), "铸炉没铸过：铁炉还能进")
	var again = game.overlay()
	t.check(again != null and again.has_method("anvil") and again.anvil().status_text() == UiText.t("anvil.used"), "砧那栏写着用过了")
	if again != null and again.has_method("anvil"):
		var stick := _inst(flow.items, &"salve")
		t.check(not again.anvil().weapon_slot.accepts(stick.def), "伤药进不了武器槽")
		again.to_map()
	NodeEvents.use_forge(node)
	t.check(not flow.open_forge(node), "两栏都用过：开不了")
	game.queue_free()
	Support.cleanup("anvil279_ui")


static func run_no_upgrade(t: TestCase) -> void:
	t.begin("286 §2.2 · 砧：没有升级配方的武器写「这把没有可升的」")
	var c = NodeScreens._content()
	var db: ItemDatabase = c.items
	var pool := SmithRecipeDef.load_all()
	var col := AnvilColumn.new()
	var flow := GameFlow.new()
	flow.smith_recipes = pool
	flow.items = db
	col.setup(flow, null, null, null, null)
	var none: ItemDef = null
	for id in db.ids():
		var d := db.get_def(id)
		if d != null and d.tags.has(&"weapon") and Anvil.upgrades_for(d, pool).is_empty() and col.weapon_slot.try_add(ItemInstance.create(d, 0), true):
			none = d
			break
	t.not_null(none, "有一把没升级配方、放得进武器槽的武器")
	if none == null:
		col.free()
		return
	t.eq(col.note_text(), UiText.t("anvil.no_upgrade"), "便条：这把没有可升的")
	t.eq(col.status_text(), UiText.t("anvil.used"), "没有休息点：当用过（灰）")
	col.free()


static func run_orange(t: TestCase) -> void:
	t.begin("279 第二批 · 升橙：魔晶石当材料（同一族、紫起），出件只能锻造 —— 生成池里没有、图鉴照列；便条写魔晶石的名字")
	var c = NodeScreens._content()
	var db: ItemDatabase = c.items
	var pool := SmithRecipeDef.load_all()
	var spike := _inst(db, &"bloodbone_spike")
	var fang := Anvil.result(spike, _inst(db, &"fire_crystal"), pool, db)
	t.check(fang != null and fang.def.id == &"flame_fang" and fang.quality() == 0, "噬血骨刺 + 火焰魔晶石：焰牙，0 档")
	t.eq(Anvil.result(spike, _inst(db, &"fire_crystal_high"), pool, db).quality(), 1, "火焰魔晶核高一档：1 档")
	t.check(Anvil.result(spike, _inst(db, &"fire_crystal_low"), pool, db) == null, "火焰晶石（蓝）不够档")
	t.eq(Anvil.result(spike, _inst(db, &"ice_crystal"), pool, db).def.id, &"frost_fang", "冰晶：霜牙")
	t.check(Anvil.result(spike, _inst(db, &"beast_claw"), pool, db) == null, "骨材升不了橙")
	t.check(db.get_def(&"flame_fang").is_forged_only() and not db.ids().has(&"flame_fang") and db.ids(true).has(&"flame_fang"), "焰牙：生成池里没有，图鉴照列")
	t.check(db.ids().has(&"bloodbone_spike"), "紫的照常能掉")
	var r := Anvil.recipe_for(db.get_def(&"bloodbone_spike"), db.get_def(&"fire_crystal"), pool)
	t.check(AnvilColumn.upgrade_line(r, db).contains(Names.of(db.get_def(&"fire_crystal"))), "便条：要一件火焰魔晶石（%s）" % AnvilColumn.upgrade_line(r, db))
