## 096（作者定）：标签与伤害类型是内容（名字 / 说明多语言）；挑出生点的遮罩；开局预设套；毒药瓶不耗耐力；搜索遭遇打赢先看战利品
extends RefCounted

const GAME := "res://ui/game/game.tscn"
## 与 Support.paths("096") 是同一组路径（flow / cleanup 按前缀算）
const SAVE := "user://test_096_run.json"
const META := "user://test_096_meta.json"
const SETTINGS := "user://test_096_settings.json"
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func run_tag_data(t: TestCase) -> void:
	t.begin("096 · 标签是内容：data/tags 装回 TagRegistry；名字 / 说明按语言；没登记的原词；faith:<id> 写成「信仰：神名」；标签词条")
	TagRegistry.reset()
	t.check(TagRegistry.ids().size() >= 39, "装回了 %d 个标签" % TagRegistry.ids().size())
	t.check(TagRegistry.has(&"weapon") and TagRegistry.has(&"metal") and TagRegistry.has(&"rapid"), "武器 / 金属 / 快攻都登记了")
	t.eq(TagRegistry.name_of(&"weapon"), "武器", "中文名")
	t.eq(TagRegistry.name_of(&"weapon", "en"), "Weapon", "英文名")
	t.check(TagRegistry.describe(&"weapon") != "" and TagRegistry.describe(&"weapon", "en") != TagRegistry.describe(&"weapon"), "两种语言的说明")
	t.eq(TagRegistry.name_of(&"zz_nobody"), "zz_nobody", "没登记的原词")
	t.eq(TagRegistry.describe(&"zz_nobody"), "", "没登记的没说明")
	t.eq(Glossary.tag_name(&"metal"), "金属", "Glossary.tag_name 走数据")
	t.check(Glossary.tag_name(&"faith:brute").begins_with("信仰：") and Glossary.tag_name(&"faith:brute").contains("蛮神"), "信仰对象标签：%s" % Glossary.tag_name(&"faith:brute"))
	# 107（作者定）：武器、近战这类一看就懂的标签 tip 关了 —— 不出词条，但说明文字照在
	var terms := Glossary.tag_terms([&"weapon", &"zz_nobody", &"metal"])
	t.check(terms.has("金属") and not terms.has("武器") and terms.size() == 1, "只有 tip 开着的标签成词条：%s" % str(terms.keys()))
	t.check(TagRegistry.describe(&"weapon") != "" and not TagRegistry.tip_of(&"weapon"), "武器的说明文字保留，只是不弹")
	t.check(TagRegistry.tip_of(&"metal"), "金属写了哪位神看重它，照弹")
	t.check(not TagRegistry.tip_of(&"zz_nobody"), "没登记的标签没有词条")
	var saved := UiText.lang
	UiText.lang = "en"
	t.eq(Glossary.tag_name(&"metal"), "Metal", "英文模式：Metal")
	t.check(Glossary.tag_name(&"faith:brute").begins_with("Faith:"), "英文模式的信仰标签：%s" % Glossary.tag_name(&"faith:brute"))
	t.eq(Glossary.stat_name(&"damage"), "Damage", "属性名也有英文")
	t.eq(Glossary.stat_name(&"zz_stat"), "zz_stat", "没登记的属性原词")
	UiText.lang = saved
	t.eq(Glossary.stat_name(&"damage"), "伤害", "中文模式：伤害")
	# Names.description_of
	var def := TagDef.new()
	def.description = "甲"
	def.descriptions = {"en": "A"}
	t.eq(Names.description_of(def), "甲", "说明：当前语言（中文）")
	t.eq(Names.description_of(def, "en"), "A", "说明：英文")
	t.eq(Names.description_of(def, "fr"), "甲", "没写的语言回落")
	t.eq(Names.description_of(null), "", "null 空")


static func run_damage_type_data(t: TestCase) -> void:
	t.begin("096 · 伤害类型是内容：data/damage_types 覆盖内置；名字按语言；性质以数据为准；deal_damage 的说明用名字")
	DamageTypes.reset_to_builtins()
	t.eq(DamageTypes.ids().size(), 6, "六种")
	t.eq(DamageTypes.name_of(DamageTypes.FIRE), "火焰", "火焰")
	t.eq(DamageTypes.name_of(DamageTypes.FIRE, "en"), "Fire", "Fire")
	t.eq(DamageTypes.name_of(&"zz_type"), "zz_type", "没登记的原词")
	t.check(DamageTypes.describe(DamageTypes.POISON) != "", "中毒有说明")
	var poison := DamageTypes.get_def(DamageTypes.POISON)
	t.check(not poison.shield_absorbable and not poison.provokes, "中毒的两个性质来自数据（106 删了护甲列：防护按来源算）")
	t.check(poison.display_names.has("en"), "数据里的定义（带英文名），不是内置的")
	t.eq(Glossary.damage_type_name(&"bleed"), "流血", "Glossary 走数据")
	var dd := DealDamage.new()
	dd.damage_type = &"fire"
	t.eq(dd.describe(), "造成 火焰 伤害", "效果说明用名字")
	var saved := UiText.lang
	UiText.lang = "en"
	t.eq(Glossary.damage_type_name(&"bleed"), "Bleed", "英文模式")
	UiText.lang = saved


static func run_import_tags_and_presets(t: TestCase) -> void:
	t.begin("096 · 导入器：标签定义要 id 与名字；道具带没登记的标签只警告；伤害类型定义；预设套不用带包、非预设仍要")
	var ctx := ContentImporter.Context.new()
	var report := ImportReport.new()
	var tag := ContentImporter.import_tag({"id": "weapon", "display_name": "武器", "display_names": {"en": "Weapon"}, "description": "x"}, ctx, report)
	ContentImporter.import_tag({"id": "faith", "display_name": "信仰"}, ctx, report)
	t.check(report.ok() and tag.id == &"weapon" and ctx.tags.has(&"weapon"), "标签导入、登记进上下文")
	var dumped := ContentExporter.export_tag(tag)
	t.check(dumped.get("display_name") == "武器" and (dumped.get("display_names") as Dictionary).get("en") == "Weapon", "导出往返")
	var bad := ImportReport.new()
	ContentImporter.import_tag({"id": "", "display_name": ""}, ctx, bad)
	t.eq(bad.errors.size(), 2, "没 id、没名字各一条错误")
	var bad2 := ImportReport.new()
	ContentImporter.import_tag({"id": "faith:x", "display_name": "x"}, ctx, bad2)
	t.check(not bad2.ok(), "带冒号的 id 拦住")
	var r2 := ImportReport.new()
	ContentImporter.import_item({"id": "probe", "display_name": "探", "shape": ["1"], "tags": ["weapon", "zz_unknown", "faith", "faith:brute"],
		"combat": {"rules": [{"trigger": {"type": "on_schedule"}, "cadence": {"type": "cooldown", "seconds": 1.0}, "effects": [{"type": "deal_damage"}]}]}}, ctx, r2)
	t.check(r2.ok(), "没登记的标签不是错误：%s" % r2.to_text())
	t.eq(r2.warnings.size(), 1, "只对 zz_unknown 警告一次（faith:<id> 不算）：%s" % r2.to_text())
	var r3 := ImportReport.new()
	var dt := ContentImporter.import_damage_type({"id": "acid", "display_name": "酸", "shield_absorbable": false, "provokes": false}, ctx, r3)
	t.check(r3.ok() and dt.id == &"acid" and not dt.shield_absorbable and not dt.provokes, "伤害类型导入")
	var r4 := ImportReport.new()
	ContentImporter.import_damage_type({"id": "acid", "display_name": ""}, ctx, r4)
	t.check(not r4.ok(), "没名字拦住")
	# 预设套
	var c := NodeScreens._content()
	for id in c.items.all_ids():
		ctx.register_item(c.items.get_def(id))
	var r5 := ImportReport.new()
	var pre := ContentImporter.import_loadout({"id": "p", "display_name": "p", "items": ["knife"], "preset": true}, ctx, r5)
	t.check(r5.ok() and pre.preset, "预设套不带包也行")
	var r6 := ImportReport.new()
	ContentImporter.import_loadout({"id": "q", "display_name": "q", "items": ["knife"]}, ctx, r6)
	t.check(not r6.ok(), "非预设没有包：错误")


static func run_tooltip_tags(t: TestCase) -> void:
	t.begin("096 · 道具悬浮窗：标签按名字写、标签的说明进词条侧窗；包的准入标签也按名字")
	var c := NodeScreens._content()
	var knife := ItemInstance.create(c.items.get_def(&"knife"))
	var full := ItemTooltip.describe_full(knife)
	var text := Glossary.strip_bbcode(String(full["text"]))
	t.check(text.contains("标签：武器、近战、金属"), "标签一行照样列出名字（107：不弹词条不等于不显示；快攻是内部标签不列）：%s" % text.split("\n")[1] if text.split("\n").size() > 1 else text)
	var names: Array[String] = []
	for term in full["terms"]:
		names.append(String((term as Dictionary)["name"]))
	t.check(names.has("金属") and not names.has("武器") and not names.has("近战"), "107：只有 tip 开着的标签成词条：%s" % str(names))


static func run_faith_bonus_lit(t: TestCase) -> void:
	t.begin("096（作者定）· 悬浮窗的信仰加成词条：局里生效的白、没生效的灰（没激活 / 阶不够 / 别的神）；局外原色；信仰道具那行写现在的状态")
	var c := NodeScreens._content()
	var bow := c.items.get_def(&"blessed_longbow")
	var sigil := c.items.get_def(&"strength_sigil")
	if bow == null or sigil == null or bow.faith_bonuses.is_empty():
		t.check(false, "缺道具")
		return
	var saved := ItemTooltip.faith_probe
	ItemTooltip.faith_probe = Callable()
	var plain := ItemTooltip.describe(ItemInstance.create(bow))
	t.check(plain.contains("信力") and not plain.contains("[color=#%s]信力" % ItemTooltip.DIM_HEX) and not plain.contains("现在"), "局外：原色，不写状态")
	t.check(not plain.contains("休眠"), "107：道具悬浮窗里不再出现「休眠」字样")
	var b0 := bow.faith_bonuses[0] as FaithBonus
	t.check(not ItemTooltip.bonus_lit(bow, b0, {}), "没状态 = 不亮")
	t.check(not ItemTooltip.bonus_lit(bow, b0, {"active": &"brute", "tier": 5, "points": 999}), "别的神激活：不亮")
	t.check(not ItemTooltip.bonus_lit(bow, b0, {"active": &"hunt", "tier": 0, "points": 0}), "自己的神但阶不够：不亮")
	t.check(ItemTooltip.bonus_lit(bow, b0, {"active": &"hunt", "tier": b0.tier, "points": 0}), "自己的神、阶够：亮")
	ItemTooltip.faith_probe = func() -> Dictionary: return {"active": &"brute", "tier": 2, "points": 120}
	var dim := "[color=#%s]" % ItemTooltip.DIM_HEX
	var fg := "[color=#%s]" % UiPalette.FG.to_html(false)
	var dormant := ItemTooltip.describe(ItemInstance.create(bow))
	t.eq(dormant.count(dim), plain.count(dim) + bow.faith_bonuses.size(), "别的神激活：每条加成多一段灰")
	# 107（作者定）：不再写「现在休眠」—— 状态就是颜色
	t.check(not Glossary.strip_bbcode(dormant).contains("休眠"), "别的神激活：不写「休眠」两个字，灰色就是状态")
	t.check(not ItemTooltip.faith_lit(bow, ItemTooltip.faith_status()), "狩猎的弓在蛮神激活时不亮")
	var sig_text := ItemTooltip.describe(ItemInstance.create(sigil))
	t.check(ItemTooltip.faith_lit(sigil, ItemTooltip.faith_status()), "蛮神的符号在蛮神激活时亮（107：不再写「已激活（Lv.2）」，亮色就是状态）")
	t.check(not Glossary.strip_bbcode(sig_text).contains("已激活"), "状态尾巴去掉了")
	var lit_n := 0
	for fb in sigil.faith_bonuses:
		if ItemTooltip.bonus_lit(sigil, fb, ItemTooltip.faith_status()):
			lit_n += 1
	t.check(lit_n > 0 and sig_text.count(fg) >= lit_n, "生效的加成是白的（%d 条）" % lit_n)
	ItemTooltip.faith_probe = func() -> Dictionary: return {"active": &"", "tier": -1, "points": 0}
	var none := ItemTooltip.describe(ItemInstance.create(bow))
	t.check(not Glossary.strip_bbcode(none).contains("还没激活") and none.count(dim) == plain.count(dim) + bow.faith_bonuses.size(), "107：没激活也只是灰，不写「还没激活」")
	ItemTooltip.faith_probe = saved


static func run_poison_vial(t: TestCase) -> void:
	t.begin("096 · 毒药瓶不是武器：下毒不耗耐力")
	var c := NodeScreens._content()
	var vial := c.items.get_def(&"poison_vial")
	t.check(vial != null and vial.combat != null and not vial.combat.rules.is_empty(), "毒药瓶有规则")
	if vial == null or vial.combat == null:
		return
	for r in vial.combat.rules:
		t.check((r as AbilityRule).costs.is_empty(), "规则没有消耗")
	t.check(not vial.tags.has(&"weapon"), "不是武器")
	var inst := ItemInstance.create(vial)
	var text := ItemTooltip.describe(inst)
	t.check(not text.contains("耗耐力"), "悬浮窗不写耗耐力")


static func run_search_encounter_won_sees_loot(t: TestCase) -> void:
	t.begin("096（作者反馈）· 搜索遭遇打赢：回放 → 战利品 → 再回到「再搜 / 走」的事件屏（不是先回事件）")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var found: Dictionary = NodeScreens._seed_with(c, &"search", kit.items)
	if found.is_empty():
		t.check(false, "找不到带搜索点的种子")
		return
	var f := Support.flow(c, "096", 100000.0)
	var run := f.begin(c.chapter, kit, int(found["seed"]))
	if run == null:
		t.check(false, "开局")
		return
	f.pick_spawn(int(found["entry"]))
	var rules: NodeRules = run.events.rules.duplicate(true)
	rules.search.encounter_curve.clear()
	rules.search.encounter_curve.append(1.0)
	run.events.rules = rules
	t.check(f.step_to(int(found["next"])), "走上搜索点")
	var labels: Array = NodeScreens._labels(f.last_payload.get("def", null))
	t.check(f.choose_event(maxi(labels.find("搜索"), 0)), "选「搜索」")
	var session: SearchSession = run.events.current_search
	if session == null or session.encounter.is_empty():
		t.check(false, "没遭遇")
		Support.cleanup("096")
		return
	t.eq(f.screen, GameFlow.Screen.EVENT, "→「有人来了」")
	t.check(f.choose_event(0), "迎战")
	t.eq(f.screen, GameFlow.Screen.PREBATTLE, "→ 战前准备")
	t.check(f.start_battle(), "开战")
	t.eq(f.screen, GameFlow.Screen.BATTLE, "→ 回放")
	t.check(bool(f.last_payload.get("won", false)), "赢了（十万血）")
	var had_loot := run.pending_loot != null
	f.resume()
	if had_loot:
		t.eq(f.screen, GameFlow.Screen.LOOT, "回放之后先看战利品（不是直接回事件）")
		t.check(f.hide_overlay(), "没拿完也能直接关掉战利品屏")
		t.check(f.screen == GameFlow.Screen.EVENT or f.screen == GameFlow.Screen.SEARCH, "关掉后回到「再搜 / 走」（%d）" % f.screen)
		# 作者反馈（2026-10-07）：没拿的不再挂成待拾取，道具并进搜索的收获箱、包掉在地上（tests/ui/test_node_screens.gd 细查）
		t.check(run.pending_loot == null, "没拿的并进了搜索的收获箱 / 地上，不再单挂一份待拾取")
	else:
		t.check(true, "（这一场没掉东西，直接看下一屏）")
	t.check(f.screen == GameFlow.Screen.EVENT or f.screen == GameFlow.Screen.SEARCH, "然后回到搜索的事件屏 / 搜索屏（%d）" % f.screen)
	t.check(run.events.current_search == session and session.active, "会话还开着，能再搜")
	Support.cleanup("096")


static func frame_property_form_pickers(t: TestCase, root: Window) -> void:
	t.begin("096 · 编辑器：标签数组旁的「加标签…」下拉（登记过 / 用过的标签，带中文名）；伤害类型字段下拉；指向标签的字段下拉")
	var saved := UiText.lang
	UiText.lang = "zh"
	var known := PropertyForm.known_tags()
	t.check(known.has("weapon") and known.has("rapid") and known.has("gear_plug"), "已知标签含登记的与内容里用过的（%d 个）" % known.size())
	t.check(not known.any(func(k: String) -> bool: return k.begins_with("faith:")), "faith:<id> 不列")
	t.eq(PropertyForm.tag_label("weapon"), "武器 (weapon)", "标签的显示文字")
	t.eq(PropertyForm.tag_label("zz_x"), "zz_x", "没登记的原词")
	t.eq(PropertyForm.damage_type_label("fire"), "火焰 (fire)", "伤害类型的显示文字")
	var def := ItemDef.new()
	def.id = &"probe"
	def.shape = ItemShape.new()
	def.tags = [&"weapon"] as Array[StringName]
	var form := PropertyForm.create(def, UiPalette.cjk_font())
	root.add_child(form)
	var found_pickers: Array = []     # lambda 里改数组（按引用）
	var walker := func(node: Node, f: Callable) -> void:
		for ch in node.get_children():
			if ch is Control and (ch as Control).has_meta("tag_options"):
				found_pickers.append(ch)
			f.call(ch, f)
	walker.call(form, walker)
	t.check(not found_pickers.is_empty(), "tags 字段旁有「加标签…」")
	var picker: Control = found_pickers[0] if not found_pickers.is_empty() else null
	if picker != null:
		var ob: OptionButton = picker.get_meta("tag_options")
		t.eq(ob.item_count, known.size() + 1, "下拉 = 已知标签 + 第一项提示")
		var at := known.find("metal")
		ob.item_selected.emit(at + 1)
		t.check(def.tags.has(&"metal") and def.tags.has(&"weapon"), "选一个就追加：%s" % str(def.tags))
		ob.item_selected.emit(known.find("weapon") + 1)
		t.eq(def.tags.size(), 2, "已有的不重复加")
		t.check((picker.get_meta("tag_edit") as LineEdit).text.contains("metal"), "那一行文字跟着更新")
	form.queue_free()
	# 伤害类型字段
	var dd := DealDamage.new()
	var form2 := PropertyForm.create(dd, UiPalette.cjk_font())
	root.add_child(form2)
	var pickers: Array = []
	var walker2 := func(node: Node, f: Callable) -> void:
		for ch in node.get_children():
			if ch is Control and (ch as Control).has_meta("stat_options"):
				pickers.append(ch)
			f.call(ch, f)
	walker2.call(form2, walker2)
	var found_dt := false
	for p in pickers:
		var ob2: OptionButton = (p as Control).get_meta("stat_options")
		for i in ob2.item_count:
			if ob2.get_item_text(i) == "火焰 (fire)":
				found_dt = true
	t.check(found_dt, "damage_type 的下拉里有「火焰 (fire)」（%d 个选择器）" % pickers.size())
	form2.queue_free()
	UiText.lang = saved


static func frame_spawn_mask_and_presets(t: TestCase, root: Window) -> void:
	t.begin("096 · 开局屏预设套（两套：强攻 / 坚守；不算带入、拖不进仓库、出发带着走）；地图屏挑出生点的遮罩（只有出生点点得中，挑完撤掉）")
	Support.cleanup("096")
	var game = load(GAME).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	game.settings_path = SETTINGS
	root.add_child(game)
	var flow: GameFlow = game.flow
	if flow.characters.is_empty() or flow.chapters.is_empty():
		t.check(false, "没有角色或章节")
		game.queue_free()
		return
	var sets: Array[LoadoutDef] = flow.presets()
	t.eq(sets.size(), 2, "两套预设")
	t.check(flow.default_loadout() != null and not flow.default_loadout().preset, "老路 / 第一套用的是非预设")
	var offense: LoadoutDef = null
	var defense: LoadoutDef = null
	for s in sets:
		if s.id == &"preset_offense":
			offense = s
		elif s.id == &"preset_defense":
			defense = s
	t.check(offense != null and defense != null, "强攻 + 坚守")
	t.eq(Names.of(offense, "en"), "Assault", "英文名")
	t.check(Names.description_of(defense) != "", "有说明")
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)
	t.eq(setup.screen, GameFlow.Screen.SETUP, "→ 开局屏")
	t.eq(setup.preset_index, -1, "默认不带预设")
	t.eq(setup.preset_items().size(), 0, "棋盘上没有预设的东西")
	var n: int = flow.meta.warehouse.item_count()
	var oi := sets.find(offense)
	setup.choose_preset(oi)
	t.eq(setup.preset_items().size(), offense.items.size(), "强攻的 %d 件都放进了初始包" % offense.items.size())
	t.eq(setup.carried().size(), 0, "预设的不算带入")
	t.eq(setup.carry_value(), 0, "不占预算")
	t.eq(flow.meta.warehouse.item_count(), n, "仓库一件没少")
	var pre_uid: int = setup.preset_items()[0].uid
	t.check(not setup.carry_out(pre_uid), "预设的放不回仓库")
	t.check(not setup._allow_drop(setup.preset_items()[0], flow.meta.warehouse), "拖去仓库也不行")
	t.check(setup._allow_drop(setup.preset_items()[0], setup.board), "在棋盘上挪可以")
	t.check(setup._readout.get_parsed_text().contains("预设套"), "读数里写着预设套")
	# 强攻 DPS > 坚守；坚守护甲 > 强攻
	var ch: CharacterDef = setup.character()
	var dps_off: float = BattleCompiler.compile_board(setup.board, ch.baseline(), [] as Array[StatModifier], [] as Array[AbilityRule], {}).rough_dps()
	var armor_off := _armor_on(setup.board)
	setup.choose_preset(sets.find(defense))
	t.eq(setup.preset_items().size(), defense.items.size(), "换成坚守：%d 件都放进去了" % defense.items.size())
	t.check(not setup.board.items().any(func(i) -> bool: return (i as ItemInstance).def.id == &"longsword"), "强攻的长剑拿掉了")
	var dps_def: float = BattleCompiler.compile_board(setup.board, ch.baseline(), [] as Array[StatModifier], [] as Array[AbilityRule], {}).rough_dps()
	var armor_def := _armor_on(setup.board)
	t.check(dps_off > dps_def, "强攻 DPS %.1f > 坚守 %.1f" % [dps_off, dps_def])
	t.check(armor_def > armor_off, "坚守护甲 %d > 强攻 %d" % [armor_def, armor_off])
	# 带一件仓库的：预算只算它
	if n > 0:
		var first := flow.meta.warehouse.items()[0] as ItemInstance
		if setup.carry_in(first.uid):
			t.eq(setup.carried().size(), 1, "带了一件仓库的")
			t.eq(setup.carry_value(), ItemValue.of(first.def), "预算只算仓库的那件")
	setup.choose_preset(-1)
	t.eq(setup.preset_items().size(), 0, "不带：预设的都拿掉")
	t.check(setup.carried().size() <= 1, "带上的仓库件还在")
	setup.choose_preset(sets.find(defense))
	setup.choose_character(setup.character_index)     # 换角色也跟着
	t.eq(setup.preset_items().size(), defense.items.size(), "重摆棋盘后预设套还在")
	setup.set_run_seed(7)
	t.check(setup.depart(), "出发")
	var run: RunState = flow.run
	t.check(run.board.items().any(func(i) -> bool: return (i as ItemInstance).def.id == &"round_shield"), "一局的棋盘上有坚守的圆盾")
	# 遮罩
	var map = game.base()
	t.eq(map.screen, GameFlow.Screen.MAP, "→ 地图屏")
	var view: MapView = map._view
	if run.phase == RunState.Phase.PICK_SPAWN:
		t.check(view.spawn_mask, "挑出生点阶段：遮罩开着")
		var pos: Dictionary = view.positions()
		var entry: int = run.map.entry_ids[0]
		var other := -1
		for id in pos:
			if not run.map.entry_ids.has(int(id)):
				other = int(id)
				break
		t.eq(view.node_at(pos[entry]), entry, "出生点点得中")
		if other >= 0:
			t.eq(view.node_at(pos[other]), -1, "别的点点不中")
		t.check(map.pick_spawn(entry), "挑出生点")
		t.check(not view.spawn_mask, "挑完遮罩撤掉")
		if other >= 0:
			t.eq(view.node_at(pos[other]), other, "别的点又点得中了")
	else:
		t.check(not view.spawn_mask, "章节自动站好：没有遮罩")
	# 反馈：进点后节点浮窗一直挂着 —— 悬停相邻的点出浮窗，走过去之后浮窗收起
	flow.settings.node_tooltips_preview = true
	var target := -1
	for id in view.reachable:
		if int(id) != run.travel.current_id:
			target = int(id)
			break
	if target >= 0:
		view._hover_id = target
		view.node_hovered.emit(target)
		t.check(map.tooltip_text() != "", "悬停相邻的点：浮窗出来了")
		map.step(target)
		t.eq(map.tooltip_text(), "", "走过去之后浮窗收起")
		t.eq(view._hover_id, -1, "悬停清掉：鼠标回到这个点会重新出浮窗")
	game.queue_free()
	Support.cleanup("096")


static func _armor_on(board: GridInventory) -> int:
	var total := 0
	for inst in board.items():
		var d := (inst as ItemInstance).def
		if d.combat != null and d.combat.base_stats.has("armor"):
			total += int(d.combat.base_stats["armor"])
	return total


static func run_search_encounter_save_roundtrip(t: TestCase) -> void:
	t.begin("审查 B1 · 搜索遇敌存读档：遇敌事件的旗子与遭遇内容跟着走、搜到的收获进待拾取；战前准备屏的战败代价（无代价 0）不变回默认")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var found: Dictionary = NodeScreens._seed_with(c, &"search", kit.items)
	if found.is_empty():
		t.check(false, "找不到带搜索点的种子")
		return
	var f := Support.flow(c, "096", 100000.0)
	var run := f.begin(c.chapter, kit, int(found["seed"]))
	if run == null:
		t.check(false, "开局")
		return
	f.pick_spawn(int(found["entry"]))
	var rules: NodeRules = run.events.rules.duplicate(true)
	rules.search.encounter_curve.clear()
	rules.search.encounter_curve.append(1.0)
	run.events.rules = rules
	t.check(f.step_to(int(found["next"])), "走上搜索点")
	var labels: Array = NodeScreens._labels(f.last_payload.get("def", null))
	t.check(f.choose_event(maxi(labels.find("搜索"), 0)), "选「搜索」")
	var session: SearchSession = run.events.current_search
	if session == null or session.encounter.is_empty() or not bool(run.events.pending.get("search_encounter", false)):
		t.check(false, "没停在遇敌事件上")
		Support.cleanup("096")
		return
	var enc: Dictionary = session.encounter.duplicate(true)
	var haul_n := session.haul().item_count()
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())), c.chapter, c.items, c.enemies, c.sets)
	t.not_null(back, "读得回来")
	if back == null:
		Support.cleanup("096")
		return
	t.check(bool(back.events.pending.get("search_encounter", false)), "遇敌事件的旗子还在")
	t.eq(JSON.stringify(back.events.pending.get("encounter", {})), JSON.stringify(JSON.parse_string(JSON.stringify(enc))), "遭遇内容还在")
	if haul_n > 0:
		t.check(back.pending_loot != null and back.pending_loot.item_count() == haul_n, "搜到的 %d 件进了待拾取" % haul_n)
	else:
		t.check(true, "（这次没搜到东西）")
	# 战前准备屏：搜索遇敌是无代价（0），读档不能变回默认
	back.events.pending_battle = {"node": back.events.pending_node().id if back.events.pending_node() != null else 0, "type": "search",
		"content": enc, "kind": "search", "loss_cost": 0}
	var back2 := RunState.from_dict(JSON.parse_string(JSON.stringify(back.to_dict())), c.chapter, c.items, c.enemies, c.sets)
	t.eq(int(back2.events.pending_battle.get("loss_cost", -99)), 0, "战前准备屏的代价 0 跟着存档")
	# 再搜 / 走的旗子
	back2.events.pending["search_stage"] = true
	var back3 := RunState.from_dict(JSON.parse_string(JSON.stringify(back2.to_dict())), c.chapter, c.items, c.enemies, c.sets)
	t.check(bool(back3.events.pending.get("search_stage", false)), "「再搜 / 走」的旗子跟着存档")
	Support.cleanup("096")
