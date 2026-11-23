## 342 B3 第一步：地图协会 —— 教程后第一次正式探索结算时来营地，首单《把路画回来》营地一步办完、+10、开材料倾向；
## 《两条回路》改给地图协会；三份后续剧情到 25。材料倾向只在普通搜索、只在材料类里重分权重（每档稀有度的和不变），
## 跟这一局的存档走（局内存档 v7）；383 起材料倾向在开局第三屏地图列表下面，倾向开了才有
extends RefCounted

const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const CS := preload("res://tests/run/test_character_setup.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "carto_342b3"
const REDRAW := &"cartographers_redraw"


static func _done(book: CommissionBook, ids: Array) -> void:
	for id in ids:
		book.entries[String(id)] = {"state": CommissionBook.DONE, "stage": 0, "progress": 0, "keys": [], "times": 1, "pick": "", "seq": 0}


static func run_content(t: TestCase) -> void:
	t.begin("342 B3 · 地图协会：首单开材料倾向、+10、营地一步；《两条回路》+ 两份新剧情到 25，许可单要前两份")
	var f := Commissions.faction(&"cartographers")
	t.not_null(f, "有地图协会")
	if f == null:
		return
	t.eq(f.arrives, Commissions.ARRIVES_FIRST_RUN, "第一次正式探索结算时来")
	t.eq(Commissions.opener_of(&"bias").id, REDRAW, "材料倾向由《把路画回来》开")
	var d := Commissions.def(REDRAW)
	t.eq([d.reputation, d.stages[0].goal, d.stages[0].where], [10, &"camp_report", CommissionStage.CAMP], "首单 +10，营地办理")
	var chain := Commissions.of_faction(&"cartographers")
	var total := 0
	for c in chain:
		total += Commissions.reputation_of(c)
	t.eq(total, 25, "四份加起来 25")
	t.eq(chain.map(func(c: CommissionDef) -> String: return String(c.id)), ["cartographers_redraw", "legion_two_routes", "cartographers_verify_vein", "cartographers_permit"], "顺序")
	t.eq(Commissions.def(&"cartographers_permit").requires, [&"legion_two_routes", &"cartographers_verify_vein"] as Array[StringName], "许可单要两份后续")
	t.eq(f.permit, &"cartographers_permit", "许可单")
	t.check(Commissions.of_faction(&"legion").all(func(c: CommissionDef) -> bool: return c.id != &"legion_two_routes"), "后勤部队不再有《两条回路》")


static func run_arrival(t: TestCase) -> void:
	t.begin("342 B3 · 来营地：教程章、没走出起点的不算；第一次正式探索结算后列出来、首单自动接上、办理后开倾向")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode")
	var f := Support.flow(c, PREFIX)
	var book := f.meta.commissions
	t.check(not Commissions.listed_factions().any(func(x: FactionDef) -> bool: return x.id == &"cartographers"), "一开始不列")
	f.sync_commissions()
	t.eq(book.state_of(REDRAW), "", "还没来：首单接不上")
	t.check(not f.bias_open(), "倾向没开")
	var s := f.begin_direct(c.chapter, 11)
	t.not_null(s, "开局")
	if s == null:
		Support.cleanup(PREFIX)
		return
	s.fail(&"time_out")     # 没走出起点就败退
	f._settle_run()
	t.check(not book.arrived.has("cartographers"), "空跑：不来")
	f.result = null
	f._settled = false
	var s2 := f.begin_direct(c.chapter, 12)
	if s2.phase == RunState.Phase.PICK_SPAWN:
		f.pick_spawn(s2.map.entry_ids[0])
	var moves := s2.travel.available_moves()
	t.check(not moves.is_empty() and s2.travel.step_to(moves[0]), "走了一步")
	s2.fail(&"time_out")
	f._settle_run()
	t.eq(int(book.arrived.get("cartographers", -1)), f.meta.runs, "走过一步再败退：来了，记第几局")
	t.check(Commissions.listed_factions().any(func(x: FactionDef) -> bool: return x.id == &"cartographers"), "列出来了")
	f.sync_commissions()
	t.eq(book.state_of(REDRAW), CommissionBook.TAKEN, "首单自动接上")
	t.eq(book.state_of(&"legion_two_routes"), "", "后续要熟面")
	var got := f.report_commission(REDRAW)
	t.check(bool(got["done"]), "营地办理：办成")
	t.eq(book.rep_of(&"cartographers"), 10, "+10 到熟面")
	t.check(f.bias_open(), "材料倾向开了")
	t.eq(book.state_of(&"legion_two_routes"), CommissionBook.TAKEN, "熟面：《两条回路》自动接上")
	t.eq(book.state_of(&"cartographers_verify_vein"), CommissionBook.TAKEN, "《核实矿脉》自动接上")
	var back := MetaState.from_dict(f.meta.to_dict(), c.items, GameFlow.load_meta_rules())
	t.check(back != null and back.commissions.arrived == book.arrived, "存档往返：到的那一局还在")
	Support.cleanup(PREFIX)


static func run_old_save(t: TestCase) -> void:
	t.begin("342 B3 · 老档：设施照开，但材料倾向也要办成首单；切片没有倾向")
	var f := W178._flow()
	t.check(f.facility_open(&"smithy"), "老档铁匠铺照开")
	t.check(not f.facility_open(&"bias"), "老档倾向没开")
	f.meta.commissions.grants["bias"] = true
	t.check(f.facility_open(&"bias"), "办成后开")
	f.profile = SliceProfile.SLICE
	t.check(not f.facility_open(&"bias"), "切片没有")
	W178._cleanup()


static func _material_sums(cands: Array[StringName], w: Array[float], items: ItemDatabase) -> Dictionary:
	var out := {}
	for j in cands.size():
		var d := items.get_def(cands[j])
		if SearchSession.is_material(d):
			out[d.rarity] = float(out.get(d.rarity, 0.0)) + w[j]
	return out


static func run_weights(t: TestCase) -> void:
	t.begin("342 B3 · 倾向的权重：目标系相对乘 1.5；每档稀有度的材料总和、非材料的权重都不变；材料点不受影响")
	var items := ItemDatabase.new()
	items.load_dir()
	var c := TestSupport.load_content("free_mode")
	var rules: SearchRules = (ContentPaths.load_asset("node_rules", String(c.chapter.node_rules)) as NodeRules).search
	var cands := SearchSession.candidates(rules, items)
	var base: Array[float] = []
	for id in cands:
		base.append(rules.rarity_weight(items.get_def(id).rarity, 0.5, 0))
	var w: Array[float] = base.duplicate()
	MaterialBias.apply(cands, w, items, MaterialBias.tags_of(&"mineral"), MaterialBias.MULT)
	var a := _material_sums(cands, base, items)
	var b := _material_sums(cands, w, items)
	var same := true
	for r in a:
		same = same and is_equal_approx(float(a[r]), float(b[r]))
	t.check(same, "每档稀有度的材料总权重不变")
	var ratio_ok := true
	var non_mat_ok := true
	var hit := -1
	var miss := -1
	for j in cands.size():
		var d := items.get_def(cands[j])
		if not SearchSession.is_material(d):
			non_mat_ok = non_mat_ok and is_equal_approx(base[j], w[j])
		elif d.rarity == 1:
			if MaterialBias.is_target(d, &"mineral") and hit < 0:
				hit = j
			elif not MaterialBias.is_target(d, &"mineral") and miss < 0:
				miss = j
	t.check(non_mat_ok, "非材料不动")
	t.check(hit >= 0 and miss >= 0, "同一档里有矿物也有别的材料")
	if hit >= 0 and miss >= 0:
		ratio_ok = is_equal_approx((w[hit] / w[miss]) / (base[hit] / base[miss]), MaterialBias.MULT)
	t.check(ratio_ok, "矿物相对别的材料 ×1.5")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var r1 := SearchSession.draw_items(rules, items, 0.5, 0, rng, -1, [] as Array[int], {}, [&"plant"], 0.25, MaterialBias.tags_of(&"mineral"), 1.5)
	rng.seed = 5
	var r2 := SearchSession.draw_items(rules, items, 0.5, 0, rng, -1, [] as Array[int], {}, [&"plant"], 0.25)
	t.eq(r1, r2, "材料点（只出一类）：倾向不起作用")
	t.eq(MaterialBias.why_not(&"mineral", rules, items), "", "自由模式：矿物能选")
	t.eq(MaterialBias.why_not(&"magic", rules, items), "", "晶石能选（魔晶石 + 碎晶 + 新晶石）")
	t.eq(MaterialBias.why_not(&"mineral", null, items), MaterialBias.WHY_EMPTY, "没有规则：不能选")


static func run_run_save(t: TestCase) -> void:
	t.begin("342 B3 / 383 第七节 · 出征：倾向没开出生点不带偏向；开了每个出生点各偏一系（同图各不相同、按种子定），挑了哪个就偏哪个；存档往返，v6 档迁上来 = 无倾向")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode")
	var f := Support.flow(c, PREFIX)
	var ch := f.characters_for(c.chapter)
	var s := f.begin(c.chapter, null, 3, [] as Array[int], ch[0] if not ch.is_empty() else null, [], null, &"", 0, -1)
	t.check(s != null and s.spawn_bias.is_empty() and s.material_bias == MaterialBias.NONE, "倾向没开：出生点不带偏向、无倾向")
	f.run = null
	f.meta.commissions.grants["bias"] = true
	s = f.begin(c.chapter, null, 4, [] as Array[int], ch[0] if not ch.is_empty() else null, [], null, &"", 0, -1)
	if s == null:
		t.check(false, "开得了局")
		Support.cleanup(PREFIX)
		return
	var entries: Array = s.map.entry_ids.duplicate()
	var dirs: Array = s.spawn_bias.values()
	t.eq(s.spawn_bias.size(), entries.size(), "每个出生点都带一种偏向（不留空的）")
	var uniq := {}
	for d in dirs:
		uniq[d] = true
	t.eq(uniq.size(), mini(entries.size(), f.spawn_dirs(c.chapter).size()), "同一张图上各不相同")
	t.check(dirs.all(func(d) -> bool: return f.spawn_dirs(c.chapter).has(d)), "只从这一章能选的方向里出")
	t.eq(f.spawn_biases(c.chapter, entries, 4), s.spawn_bias, "按种子定：开局屏预览算出来的一样")
	var other := MaterialBias.spawn_biases(f.spawn_dirs(c.chapter), entries, 5)
	t.check(other.size() == entries.size(), "换个种子也都带")
	t.eq(MaterialBias.spawn_biases([&"mineral"], [7], 1), {7: &"mineral"}, "只有一个出生点也带一种")
	var pick := int(entries[0])
	t.check(s.pick_spawn(pick), "挑第一个出生点")
	t.eq(s.material_bias, s.spawn_bias[pick], "这一局偏它那一系")
	t.eq(s.events.material_bias, s.material_bias, "交给了节点事件")
	var back := RunState.from_dict(s.to_dict(), c.chapter, c.items, c.enemies)
	t.check(back != null and back.material_bias == s.material_bias and back.events.material_bias == s.material_bias, "存档往返")
	t.check(back != null and back.spawn_bias == s.spawn_bias, "出生点偏向也存着")
	var old := s.to_dict()
	old["version"] = 6
	old.erase("material_bias")
	var up := RunMigrations.upgrade(old)
	t.eq([int(up["version"]), String(up["material_bias"])], [RunState.SAVE_VERSION, ""], "v6 → v7：无倾向")
	Support.cleanup(PREFIX)


static func run_vein_goal(t: TestCase) -> void:
	t.begin("342 B3 · 《核实矿脉》：只认矿点（到访目标的 search_kind）")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode")
	var f := Support.flow(c, PREFIX)
	var book := f.meta.commissions
	book.arrived["cartographers"] = 1
	_done(book, [REDRAW])
	book.rep["cartographers"] = 10
	f.sync_commissions()
	var s := f.begin_direct(c.chapter, 21)
	var mod := CommissionModule.of(s)
	var mine: MapNode = null
	var plain: MapNode = null
	for nid in s.map.node_ids():
		var n := s.map.get_node(nid)
		if String(n.content.get("search_kind", "")) == "mine":
			mine = n
		elif n.type == &"search" and plain == null:
			plain = n
	t.check(mine != null and plain != null, "图上有矿点也有普通搜索点")
	if mine != null and plain != null:
		t.check(mod.on_visit(plain).filter(func(r: Dictionary) -> bool: return String(r["id"]) == "cartographers_verify_vein").is_empty(), "普通搜索点不算")
		t.check(not mod.on_visit(mine).filter(func(r: Dictionary) -> bool: return String(r["id"]) == "cartographers_verify_vein").is_empty(), "矿点算")
	Support.cleanup(PREFIX)


static func frame_prep_page(t: TestCase, root: Window) -> void:
	t.begin("342 B3 / 383 第七节 · 第三屏没有方向那一块；开了以后预览上每个出生点挂一种偏向，挑了哪个出征就偏哪个；提示窗写「出生点 · 偏X」")
	Support.cleanup("char")
	var game = load(CS.GAME).instantiate()
	game.save_path = CS.SAVE
	game.meta_path = CS.META
	root.add_child(game)
	var flow: GameFlow = game.flow
	Support.pass_tutorials(flow)
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	t.eq(setup.last_page(), 2, "第三页就是最后一页")
	var at := -1
	for i in setup._chapters.size():
		if setup._chapters[i].id == &"free_mode":
			at = i
	t.check(at >= 0, "列着自由模式")
	if at < 0:
		game.queue_free()
		Support.cleanup("char")
		return
	setup.show_page(2)
	setup.choose_chapter(at)
	setup._sync_preview()
	t.check(setup.find_child("BiasBlock", true, false) == null, "第三屏没有方向那一块")
	t.check(setup.spawn_biases().is_empty() and setup.preview().biases.is_empty(), "倾向没开：出生点不带偏向")
	flow.meta.commissions.grants["bias"] = true
	setup._preview_key = ""     # 同一张图重算（倾向刚开）
	setup._sync_preview()
	var entries: Array = setup.preview().entry_ids()
	var sb: Dictionary = setup.spawn_biases()
	t.check(not entries.is_empty() and entries.all(func(e) -> bool: return sb.has(e)), "预览上每个出生点都带偏向（%d 个）" % entries.size())
	t.eq(setup.preview().biases, sb, "预览画着这些偏向")
	t.check(setup.find_child("BiasBlock", true, false) == null, "开了也没有单独的方向组件")
	if entries.is_empty():
		game.queue_free()
		Support.cleanup("char")
		return
	var pick := int(entries[-1])
	setup.pick_spawn(pick)
	var want: StringName = sb[pick]
	t.eq(setup.chosen_bias(), want, "挑了这个出生点 = 偏它那一系")
	t.check(setup.hint_card().find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text.contains(UiText.t("bias.dir_" + String(want)))) \
		or setup.hint_card().find_children("*", "RichTextLabel", true, false).any(func(l: RichTextLabel) -> bool: return l.text.contains(UiText.t("bias.dir_" + String(want)))), "提示窗写了偏向")
	t.check(Support.depart(setup), "出发")
	t.eq(flow.run.material_bias if flow.run != null else &"?", want, "这一局就是这个方向")
	t.eq(flow.meta.flag(&"last_bias"), 0, "「上回的选择」不再记材料倾向")
	game.queue_free()
	Support.cleanup("char")
