## 作者 2026-11-27（「交金属道具的委托怎么点一下就完成了？不该让我选择上交哪些吗？」）：营地交货由玩家自己挑 ——
## 【交货】弹石刻交货窗，格子区摆仓库里这一步收的（没锁的，价值低的在前）；点格选上 / 取消，最多选到还差的件数；
## 【交货】只交选中的，【填满】按价值最低补满
extends RefCounted

const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const T110 := preload("res://tests/meta/test_tech.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "hand_in_pick"
const ID := &"legion_check_materials"


static func _open(book: CommissionBook) -> void:
	book.entries[String(&"legion_forge_token")] = {"state": CommissionBook.DONE, "stage": 0, "progress": 0, "keys": [], "times": 1, "pick": "", "seq": 0}
	book.rep["legion"] = 10


static func run_pick(t: TestCase) -> void:
	t.begin("交货自选 · 逻辑：能挑的按价值从低到高；给了 uids 只交那几件（不合格、锁着的、超出还差的不交）；空 uids 照默认交价值最低的")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode")
	var f := Support.flow(c, PREFIX)
	var book := f.meta.commissions
	_open(book)
	f.sync_commissions()
	var d := Commissions.def(ID)
	t.eq(book.state_of(ID), CommissionBook.TAKEN, "《查验材料》接上")
	var gold := T110._add(f.meta, c.items, &"copper_ingot")
	var ore := T110._add(f.meta, c.items, &"iron_ore")
	var mith := T110._add(f.meta, c.items, &"mithril_ingot")
	var bandage := T110._add(f.meta, c.items, &"bandage")
	var locked := T110._add(f.meta, c.items, &"iron_ore")
	locked.set_locked(true)
	var ch := Commissions.hand_in_choices(f.meta, d, 0)
	t.check(not ch.has(bandage) and not ch.has(locked), "不合格的、锁着的不列")
	t.check(ch.has(gold) and ch.has(ore) and ch.has(mith), "三件金属都列出来")
	var sorted := true
	for i in range(1, ch.size()):
		sorted = sorted and ItemValue.of_instance(ch[i - 1]) <= ItemValue.of_instance(ch[i])
	t.check(sorted, "价值低的在前")
	t.eq(Commissions.hand_in_need(f.meta, d, 0), 3, "还差三件")
	var r := f.report_commission(ID, [mith.uid, bandage.uid, locked.uid])
	t.eq(int(r.get("handed", 0)), 1, "只交了挑的那件秘银（绷带、锁着的不交）")
	t.check(f.meta.warehouse.get_item(mith.uid) == null and f.meta.warehouse.get_item(gold.uid) != null and f.meta.warehouse.get_item(ore.uid) != null, "没挑的留在仓库")
	t.eq(Commissions.hand_in_need(f.meta, d, 0), 2, "还差两件")
	t.check(not bool(f.report_commission(ID, [bandage.uid])["ok"]), "挑的全不合格：什么都不交")
	var cheap := Commissions.hand_in_picks(f.meta, d, 0)
	t.eq(cheap.size(), 2, "默认挑法补满还差的")
	r = f.report_commission(ID)
	t.check(bool(r["done"]) and book.is_done(ID), "空 uids 照默认交，交够办成")
	Support.cleanup(PREFIX)


static func frame_window(t: TestCase, root: Window) -> void:
	t.begin("交货自选 · 交货窗：点【交货】弹石刻窗（格子区 + 已选几件）；没选【交货】灰着；点格选上、满了不再加、再点取消；【填满】补满；交选中的")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	_open(f.meta.commissions)
	f.sync_commissions()
	var a := T110._add(f.meta, f.items, &"iron_ore")
	var b := T110._add(f.meta, f.items, &"copper_ingot")
	var g := T110._add(f.meta, f.items, &"nail_keg")
	var m := T110._add(f.meta, f.items, &"mithril_ingot")
	var s: Control = W178._screen(f, root)
	s.show_tab("commissions")
	var p = s.commission_panel()
	p.show_faction(&"legion")
	var key := p.find_child("Report_" + String(ID), true, false) as Button
	t.not_null(key, "卡上有【交货】")
	if key == null:
		s.queue_free()
		W178._cleanup()
		return
	key.pressed.emit()
	var w: Control = s.arrival()
	t.check(w != null and w.name == "HandInNotice" and w.find_child("HandInShelf", true, false) != null, "弹出交货窗，有格子区")
	t.eq(f.meta.warehouse.items().size(), 4, "只弹窗，仓库一件没动")
	t.check(w.find_child("Pick_%d" % m.uid, true, false) != null and w.find_child("Pick_%d" % g.uid, true, false) != null, "贵的也列出来让玩家挑")
	t.check((w.find_child("Key_0", true, false) as Button).disabled, "没选：【交货】灰着")
	s.toggle_hand_in(m.uid)
	s.toggle_hand_in(g.uid)
	s.toggle_hand_in(a.uid)
	s.toggle_hand_in(b.uid)
	w = s.arrival()
	t.check((w.find_child("Pick_%d" % m.uid, true, false) as RecipeCell).selected and not (w.find_child("Pick_%d" % b.uid, true, false) as RecipeCell).selected, "选满三件，第四件点不上")
	t.check((w.find_child("Key_1", true, false) as Button).disabled, "选满了：【填满】灰着")
	s.toggle_hand_in(m.uid)
	s.toggle_hand_in(g.uid)
	w = s.arrival()
	t.check(not (w.find_child("Pick_%d" % m.uid, true, false) as RecipeCell).selected, "再点取消")
	s.fill_hand_in()
	w = s.arrival()
	t.check((w.find_child("Pick_%d" % b.uid, true, false) as RecipeCell).selected, "【填满】按价值最低补上")
	s.close_hand_in()
	s.show_hand_in(ID)
	s.toggle_hand_in(a.uid)
	s.toggle_hand_in(m.uid)
	s.toggle_hand_in(g.uid)
	var r: Dictionary = s.confirm_hand_in()
	t.eq(int(r.get("handed", 0)), 3, "交了选中的三件")
	t.check(f.meta.warehouse.get_item(m.uid) == null and f.meta.warehouse.get_item(b.uid) != null, "交的是挑的秘银，没挑的铜锭留着")
	t.check(s.arrival() == null or s.arrival().name != "HandInNotice", "交完关窗")
	t.check(f.meta.commissions.is_done(ID), "交够办成")
	s.queue_free()
	W178._cleanup()


## 一张不要科技的测试配方：点名一块硬木板 + 一格两件金属
static func _recipe() -> SmithRecipeDef:
	var r := SmithRecipeDef.new()
	r.id = &"test_pick_blade"
	r.output = &"shortsword"
	r.inputs = {&"hardwood_plank": 1}
	r.material_slots = [{"material": "metal", "min": 0, "count": 2}]
	r.funds = 10
	return r


static func run_forge_pick(t: TestCase) -> void:
	t.begin("打造自选料（作者 11-27 答 77「要」）· 逻辑：每一行能挑的价值低的在前；挑的件数不对、跨行重复、不合格都不让打；照挑的扣，没挑的留着；【填满】每行按价值最低补满")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode")
	var f := Support.flow(c, PREFIX)
	f.meta.funds = 1000
	var r := _recipe()
	var plank := T110._add(f.meta, c.items, &"hardwood_plank")
	var ore := T110._add(f.meta, c.items, &"iron_ore")
	var cu := T110._add(f.meta, c.items, &"copper_ingot")
	var mith := T110._add(f.meta, c.items, &"mithril_ingot")
	t.eq(Smithy.line_keys(r), ["hardwood_plank", "slot:0"] as Array[String], "两行：点名的在前、材料格在后")
	t.eq(Smithy.line_need(r, "slot:0"), 2, "金属格要两件")
	var ch := Smithy.line_choices(f.meta, r, "slot:0")
	t.check(ch.size() == 3 and not ch.has(plank), "金属格列三件金属，不列木板")
	t.check(ItemValue.of_instance(ch[0]) <= ItemValue.of_instance(ch[2]), "价值低的在前")
	t.check(not Smithy.picks_ok(f.meta, r, {"hardwood_plank": [plank.uid], "slot:0": [mith.uid]}), "少挑一件：不行")
	t.check(not Smithy.picks_ok(f.meta, r, {"hardwood_plank": [plank.uid], "slot:0": [mith.uid, plank.uid]}), "木板顶金属格：不行")
	t.check(not Smithy.picks_ok(f.meta, r, {"hardwood_plank": [plank.uid], "slot:0": [mith.uid, mith.uid]}), "同一件挑两次：不行")
	var filled := Smithy.fill_picks(f.meta, r, {"slot:0": [mith.uid]})
	t.check((filled["hardwood_plank"] as Array) == [plank.uid] and (filled["slot:0"] as Array).size() == 2 and (filled["slot:0"] as Array).has(mith.uid), "【填满】挑了的留着、补满")
	var picks := {"hardwood_plank": [plank.uid], "slot:0": [mith.uid, cu.uid]}
	t.check(Smithy.picks_ok(f.meta, r, picks), "挑够了：行")
	var made := Smithy.forge(f.meta, r, c.items, {}, picks)
	t.not_null(made, "打了")
	t.check(f.meta.warehouse.get_item(mith.uid) == null and f.meta.warehouse.get_item(cu.uid) == null and f.meta.warehouse.get_item(ore.uid) != null, "扣的是挑的秘银、铜锭，铁矿石留着")
	Support.cleanup(PREFIX)


static func frame_forge_window(t: TestCase, root: Window) -> void:
	t.begin("打造自选料 · 选料窗：点【打造】不直接打、弹石刻窗（每样料一行格子区）；没挑够【打造】灰着；别的行挑走的压灰；【填满】补满后能打，扣的是挑的")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	f.meta.tech_levels = {"bargain": 1, "warehouse": 1, "safe_box": 1, "pack": 1, "market": 0, "smithy": 0}
	f.derive_techs()
	f.smith_recipes = SmithRecipeDef.load_all()
	f.meta.funds = 1000
	var plank := T110._add(f.meta, f.items, &"hardwood_plank")
	var a := T110._add(f.meta, f.items, &"iron_ore")
	var b := T110._add(f.meta, f.items, &"iron_ore")
	var c := T110._add(f.meta, f.items, &"iron_ore")
	var s: Control = W178._screen(f, root)
	s.show_tab("smithy")
	var p = s.smithy_panel()
	var key: Button = p.forge_button(&"smith_shortsword")
	t.check(key != null and not key.disabled, "料齐：打造键亮")
	key.pressed.emit()
	var w: Control = s.arrival()
	t.check(w != null and w.name == "ForgePickNotice", "点【打造】弹选料窗")
	t.check(w != null and w.find_child("Tray_hardwood_plank", true, false) != null and w.find_child("Tray_iron_ore", true, false) != null, "每样料一行")
	t.eq(f.meta.warehouse.items().size(), 4, "只弹窗，仓库一件没动")
	t.check((w.find_child("Key_0", true, false) as Button).disabled, "没挑：【打造】灰着")
	s.toggle_forge_pick("iron_ore", c.uid)
	s.toggle_forge_pick("iron_ore", b.uid)
	s.toggle_forge_pick("iron_ore", a.uid)
	w = s.arrival()
	t.check(not (w.find_child("Pick_%d" % a.uid, true, false) as RecipeCell).selected, "满两件，第三件点不上")
	s.fill_forge_pick()
	w = s.arrival()
	t.check(not (w.find_child("Key_0", true, false) as Button).disabled, "【填满】补上木板：【打造】亮")
	t.eq(s.confirm_forge_pick(), "", "打了")
	t.check(f.meta.warehouse.get_item(a.uid) != null and f.meta.warehouse.get_item(b.uid) == null and f.meta.warehouse.get_item(c.uid) == null and f.meta.warehouse.get_item(plank.uid) == null, "扣的是挑的两块铁矿石和木板，没挑的那块留着")
	t.check(s.arrival() == null or s.arrival().name != "ForgePickNotice", "打完关窗")
	s.queue_free()
	W178._cleanup()
