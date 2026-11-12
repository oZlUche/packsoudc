## 312（赐福异体参与合成，方案 docs/plans/2026-11-12-blessed-fusion-review-actions.md §1–§5、§8）：
## 配方按原件配；一件赐福出同一位神的赐福成品，同神不叠；两把武器分属两位神 = 禁忌待办（不出合成键、不扣物、不记）；
## 别的异神按当前信仰 / 定价 / 神 id 择神，左右交换不变；成品没那位神的赐福版回落普通并提示；认识按原件家族
extends RefCounted

const InvPanel := preload("res://ui/game/inventory_panel.gd")


static func _run() -> RunState:
	var c := TestSupport.load_content()
	var s := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets)
	s.meta = MetaState.new()
	s.faith_defs = FaithDef.load_all()
	CraftingModule.of(s).recipes = RecipeDef.load_all()
	s.board = GridInventory.new(Vector2i(6, 4), 1, false)
	return s


static func _put(s: RunState, id: StringName, at: Vector2i) -> ItemInstance:
	var inst := ItemInstance.create(s.items.get_def(id), 0)
	return inst if s.board.place(inst, at, 0) else null


static func _res(s: RunState, a: StringName, b: StringName, active: StringName = &"") -> Dictionary:
	var faiths: Array = s.faith_defs.keys()
	Ids.sort(faiths)
	return FusionResolve.resolve(CraftingModule.of(s).recipes, s.items.get_def(a), s.items.get_def(b), s.items, faiths, active)


static func run_resolve(t: TestCase) -> void:
	t.begin("312 · 解析：普通 / 一件赐福 / 同神不叠 / 两把武器异神 = 禁忌待办 / 缺赐福版回落 / 神查不到 = 数据不对")
	var s := _run()
	var r := _res(s, &"knife", &"knife")
	t.check(r["status"] == FusionResolve.READY and r["output_id"] == &"twin_blades" and r["kind"] == FusionResolve.NORMAL, "两把普通：双刀")
	r = _res(s, &"knife_brute", &"knife")
	t.check(r["output_id"] == &"twin_blades_brute" and r["kind"] == FusionResolve.SINGLE and r["selected_faith"] == &"brute", "一把蛮神匕首：蛮神双刀")
	t.eq(_res(s, &"knife", &"knife_brute")["output_id"], &"twin_blades_brute", "左右换了一样")
	r = _res(s, &"knife_brute", &"knife_brute")
	t.check(r["output_id"] == &"twin_blades_brute" and (r["source_faiths"] as Array).size() == 1 and (r["warnings"] as Array).is_empty(), "两把蛮神：一份蛮神双刀，不叠")
	for pair in [[&"knife_brute", &"knife_sun"], [&"knife_sun", &"knife_brute"]]:
		r = _res(s, pair[0], pair[1], &"brute")
		t.check(r["status"] == FusionResolve.UNAVAILABLE and r["kind"] == FusionResolve.FORBIDDEN and r["output_id"] == &"", "%s + %s：禁忌待办，没有成品（当前信仰是其中一位也不抹掉另一位）" % pair)
	r = _res(s, &"shortbow", &"antler_nature")
	t.check(r["status"] == FusionResolve.READY and r["output_id"] == &"horn_bow" and (r["warnings"] as Array).has(FusionResolve.BLESSING_LOST), "角弓没有自然神版：普通角弓 + 不保留赐福")
	var bad := FusionResolve.resolve(CraftingModule.of(s).recipes, s.items.get_def(&"knife_brute"), s.items.get_def(&"knife"), s.items, [], &"")
	t.check(bad["status"] == FusionResolve.INVALID and bad["reason"] == "faith_unknown", "神表里查不到来源神：数据不对，不当普通吞掉")
	t.check(_res(s, &"knife", &"smoked_fish").is_empty(), "没配方：空")


static func run_pick(t: TestCase) -> void:
	t.begin("312 · 非武器异神择神：当前信仰在两位之中优先；第三位神 / 不信 = 定价高的那件；左右交换不变")
	var s := _run()
	var cleaver := s.items.get_def(&"cleaver_brute")
	var fang := s.items.get_def(&"beast_fang_nature")
	t.check(cleaver != null and fang != null, "蛮神切肉刀、自然神兽牙都在")
	if cleaver == null or fang == null:
		return
	var by_value: StringName = &"brute" if ItemValue.of(cleaver) > ItemValue.of(fang) else (&"nature" if ItemValue.of(fang) > ItemValue.of(cleaver) else &"brute")
	for active in [&"", &"earth"]:
		var r := _res(s, &"cleaver_brute", &"beast_fang_nature", active)
		var r2 := _res(s, &"beast_fang_nature", &"cleaver_brute", active)
		t.check(r["kind"] == FusionResolve.CONFLICT and r["selected_faith"] == by_value, "当前信仰「%s」：按定价选 %s" % [active, by_value])
		t.eq(r2["selected_faith"], r["selected_faith"], "左右换了一样")
		t.check((r["warnings"] as Array).has(FusionResolve.FAITH_DROPPED), "提示另一份不叠加")
	var rb := _res(s, &"beast_fang_nature", &"cleaver_brute", &"brute")
	t.check(rb["selected_faith"] == &"brute" and rb["output_id"] == &"bloodletter_brute" and rb["dropped_faith"] == &"nature", "信蛮神：蛮神放血刀，自然那份不叠")
	var rn := _res(s, &"cleaver_brute", &"beast_fang_nature", &"nature")
	t.check(rn["selected_faith"] == &"nature" and rn["output_id"] == &"bloodletter" and (rn["warnings"] as Array).has(FusionResolve.BLESSING_LOST), "信自然神：放血刀没有自然版 → 普通放血刀 + 两句提示")


static func run_fuse(t: TestCase) -> void:
	t.begin("312 · 合成：赐福匕首 + 毒药出赐福涂毒匕首，记原配方一次、认识真成品；禁忌待办不扣不记；确认后结果变了不合")
	var s := _run()
	var crafting := CraftingModule.of(s)
	var k := _put(s, &"knife_brute", Vector2i(0, 0))
	var v := _put(s, &"poison_vial", Vector2i(1, 0))
	var pairs := crafting.fusion_pairs()
	t.check(pairs.size() == 1 and pairs[0]["output"] == &"poisoned_knife_brute" and pairs[0]["status"] == FusionResolve.READY, "出锤，成品是赐福涂毒匕首")
	var miss := crafting.fuse(k.uid, v.uid, &"poisoned_knife")
	t.check(not bool(miss["ok"]) and bool(miss.get("changed", false)), "确认窗上显示的和现在不一样：不合，要重开")
	t.check(s.board.has_item(k.uid) and s.board.has_item(v.uid), "两件还在")
	var d := crafting.fuse(k.uid, v.uid, &"poisoned_knife_brute")
	t.check(bool(d["ok"]) and d["output"] == "poisoned_knife_brute" and d["recipe"] == "poisoned_knife", "合了：回执是真成品、原配方")
	t.check(s.knows_recipe(&"poisoned_knife") and s.lore.has_met(&"poisoned_knife_brute"), "记原配方、认识真成品")
	t.eq(s.lore.recipes.size(), 1, "只记一次")
	s.board.clear()
	var a := _put(s, &"knife_brute", Vector2i(0, 0))
	var b := _put(s, &"knife_sun", Vector2i(1, 0))
	var fp := crafting.fusion_pairs()
	t.check(fp.size() == 1 and fp[0]["status"] == FusionResolve.UNAVAILABLE, "两把异神匕首：照样出锤（点开只说一句）")
	t.check(not bool(crafting.fuse(a.uid, b.uid)["ok"]), "点合也不合")
	t.check(s.board.has_item(a.uid) and s.board.has_item(b.uid), "不扣物")
	t.check(not s.knows_recipe(&"fuse_twin_blades"), "不记配方")


static func run_family(t: TestCase) -> void:
	t.begin("312 · 认识按原件家族：认识普通件 = 认识它的赐福版，反过来也一样；图鉴不动")
	var s := _run()
	t.check(not s.has_met(&"knife_brute"), "开局：不认识")
	s.lore.meet(&"knife")
	t.check(s.has_met(&"knife_brute") and s.has_met(&"knife_sun"), "认识匕首：也认识赐福匕首")
	s.meta.lore.meet(&"poisoned_knife_brute")
	t.check(s.has_met(&"poisoned_knife"), "局外只见过赐福涂毒匕首：也认识普通的")
	t.check(not s.lore.has_met(&"knife_brute"), "存下的还是真 id，没补写")
	t.eq(CraftingModule.of(s).known_level(s.items.get_def(&"knife_sun"), s.items.get_def(&"poison_vial")), 1, "赐福匕首 + 毒药：认识成品（按家族）")
	var saved := ItemTooltip.recipe_probe
	ItemTooltip.recipe_probe = func(_id: StringName) -> bool: return true
	t.check(ItemTooltip.fusions_line(s.items.get_def(&"knife_brute")).contains("poisoned_knife"), "赐福匕首的悬浮窗列原件的配方")
	ItemTooltip.recipe_probe = saved


static func frame_note(t: TestCase, root: Window) -> void:
	t.begin("312 · 确认窗：禁忌待办只写「两位神的赐福互不相容」、没有合成键；缺赐福版写「不会保留赐福」；择神写保留谁")
	var s := _run()
	var panel: Control = InvPanel.new()
	panel.setup(s, null)
	root.add_child(panel)
	var a := _put(s, &"knife_brute", Vector2i(0, 0))
	var b := _put(s, &"knife_sun", Vector2i(1, 0))
	t.check(bool(panel.call("ask_fuse", a.uid, b.uid)), "开了窗")
	var note: FuseNote = panel.get("fuse_note")
	t.check(note.go_key == null and note.cancel_key != null, "没有合成键，只有取消")
	t.check(note.loss_label != null and note.loss_label.text == UiText.t("fuse.forbidden"), "只写一句：%s" % (note.loss_label.text if note.loss_label != null else ""))
	note.close()
	s.board.clear()
	var bow := _put(s, &"shortbow", Vector2i(0, 0))
	var horn := _put(s, &"antler_nature", Vector2i(2, 0))
	if bow != null and horn != null and bool(panel.call("ask_fuse", bow.uid, horn.uid)):
		t.check(note.go_key != null and note.loss_label != null and note.loss_label.text.contains(UiText.t("fuse.blessing_lost")), "缺赐福版：有合成键，写不会保留赐福")
		note.close()
	else:
		t.check(false, "短弓 + 自然鹿角摆得上、开得了窗")
	s.board.clear()
	var c := _put(s, &"cleaver_brute", Vector2i(0, 0))
	var f := _put(s, &"beast_fang_nature", Vector2i(2, 0))
	if c != null and f != null and bool(panel.call("ask_fuse", c.uid, f.uid)):
		var res := CraftingModule.of(s).resolve(c.def, f.def)
		var keep := Names.of(s.faith_defs[res["selected_faith"]])
		t.check(note.loss_label != null and note.loss_label.text.contains(keep), "择神：写保留%s" % keep)
		note.close()
	else:
		t.check(false, "切肉刀 + 兽牙摆得上、开得了窗")
	panel.queue_free()
